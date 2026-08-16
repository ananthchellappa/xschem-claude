# 0267 — the `pre_merge_modified` latch is consumed at an arbitrarily later ESC, so edits made while a paste is still pending are marked clean

Status: **FIXED 2026-08-08** on `open_pdk`, alongside issue **0265** but **not** as a byproduct of
it — see *Why it did not fall out* below. `xctx->modify_seq` / `xctx->merge_modify_seq`
(`src/xschem.h`), bumped in `set_modify()` (`src/actions.c`), latched at the bottom of `merge_file()`
(`src/paste.c`), read by `abort_pending_merge()` (`src/callback.c`). Tests: rows **E4 bare** /
**E4 nested** / **E4 control** of `tests/headless/test_paste_modify_flag_0244.tcl`; sabotage **S9**
(restore the pre-0267 condition) reddens exactly the two `MODIFIED` rows and nothing else.
Originally measured on the post-0244 tree. **Medium**: it is a *survivor* of the pre-fix
behaviour, not a regression (before issue 0244 that same ESC wrote `modified = 0` unconditionally,
i.e. in every case this issue describes and in many more), but it is the last hole in 0244's
guarantee and it is worth closing with the same fix as **0265**.
Area: `src/paste.c` (the latch in `merge_file()`) vs `src/callback.c` (the two `STARTMERGE` arms
that consume it)
Tests: **section E4** of `tests/headless/test_paste_modify_flag_0244.tcl`. Was: none — A5/A6 pin
that the latch is re-taken per merge, but model no edit *between* the arm and the ESC.
Found: 2026-08-08, by the adversarial review of the issue **0244** fix.
Related: **0244** (introduced the latch), **0265** (the root cause: nothing bounds a pending
`STARTMERGE`'s lifetime).

## What it is

`xctx->pre_merge_modified` is written once, at the arm, and describes the document **before** the
paste. `abort_operation()` restores it at ESC. That is exactly right when the ESC is the next thing
that happens — which is what a paste normally is, since the paste rides the cursor.

But `STARTMERGE` has an unbounded lifetime (issue **0265**), so an arbitrary amount of real editing
can happen while a paste is still pending. The ESC then deletes only the paste and restores a flag
value that predates everything else the user did.

## Measured, 2026-08-08

```
clean doc on disk                       wires=2 inst=1 texts=0 ui=0   modified=0
xschem merge src.sch                    wires=3 inst=2          ui=296 modified=1
xschem move_objects abort               wires=3 inst=2          ui=264 modified=1
xschem wire 2000 2000 2100 2000
xschem text 3000 3000 0 0 {IMPORTANT NOTE} {} 0.4 0
                                        wires=4 inst=2 texts=1  ui=264 modified=1
xschem abort_operation                  wires=3 inst=1 texts=1  ui=0   modified=0
                                        ^ the paste is correctly removed, the new wire and the new
                                          text are still there -- and the buffer says "saved"
```

The reviewer's stated door (a click-without-drag release reaching the bare arm) does **not** exist
in the GUI: `move.c`'s zero-delta early return is gated on `xctx->drag_elements`, and
`callback.c`'s Button1Press zeroes that before `end_place_move_copy_zoom()` commits the paste. The
defect does not need it — the same lie comes out of the *nested* arm with `STARTMOVE` still set. The
demonstrated exposure is the `xschem` subcommand surface (menus, keybindings, user scripts, action-log
replay), which is not gated.

## Fix direction

Do **not** add a second latch. The honest fix is to stop the pending merge from outliving the
gesture at all — issue **0265**'s `leave_merge_for()` — after which "the ESC that consumes the latch"
is always the ESC that immediately follows the arm and the value is never stale.

If a belt is wanted before 0265 lands: latch the undo pointer beside the flag and refuse to restore
when anything else pushed undo in between. That is fragile (not every mutation pushes undo, and the
merge and the teardown each push one of their own), which is why it is the fallback and not the
plan.

---

# THE FIX (2026-08-08)

## Why it did not fall out of 0265, which is the interesting part

Issue 0265's session plan predicted this issue would close as a byproduct: *"with the pending merge
torn down at the next gesture, the `pre_merge_modified` latch is always consumed by the ESC that
immediately follows its own arm, so it can never describe a document several edits stale."*

**Measured after 0265's Part A landed and before anything else was changed: unchanged.**
`wires=3 texts=1 modified=0`, exactly the pre-fix numbers.

The prediction is true for *arming* gestures and false for the surface this issue actually measured.
0265 gates 23 arms — every placement arm and every wire/line draw arm — but the repro above edits
with `xschem wire 2000 2000 2100 2000` and `xschem text …`, which are **pure-commit forms**. Those
are ratified as **never gated** (`doc/claude/suggestions/plan_modal_gesture_exclusion.md` landmine 2:
they are the replay and test seams; gating them would break action-log replay). They arm nothing, so
"whatever you just pressed is what you meant" has no subject — and they are exactly what the menus,
keybindings and user scripts reach. A pending paste can therefore still outlive arbitrary real
editing, and the latch is still stale at the ESC.

0265 does **narrow** the exposure: every path that arms a competing gesture now consumes the pending
merge immediately. What is left is the commit-form surface, and that needed its own mechanism.

## The mechanism

Not a second latch of the flag — the issue's own fix direction rules that out, correctly. Not the
undo-pointer belt it sketched as a fallback either: the issue calls that fragile because not every
mutation pushes undo and the merge and its teardown each push one of their own, and it is right.

Instead, **the latch is made self-invalidating** by pairing it with a sequence:

1. `unsigned int xctx->modify_seq` (`xschem.h`) — bumped by `set_modify()` (`actions.c`) on every
   *declaration* of dirtiness (`mod == 1 || mod == 3`, skipped when `readonly` suppresses the flag).
   Not a change counter and not user-visible.
2. `unsigned int xctx->merge_modify_seq` — latched at the **bottom** of `merge_file()`, after that
   function's own unconditional `set_modify(1)`, so it records "nobody has claimed a modification
   since this paste armed".
3. `abort_pending_merge()` reads `modify_seq` into a local **before** its own `delete()` dirties the
   buffer, and restores the flag only while that local still equals `merge_modify_seq`:
   `if(!xctx->pre_merge_modified && seq == xctx->merge_modify_seq) set_modify(0);`

It tracks exactly the thing the flag tracks, which is why it is not fragile the way the undo pointer
would be. The bump is on every declaration and **not** on the 0→1 transition on purpose: after a
paste the flag is already 1, so a transition counter would see nothing — the exact case this issue
is about. Mismatch fails conservative: the buffer stays **dirty**, which costs a redundant save
prompt and never loses work.

## Measured

```
                                     pre-fix        post-fix
clean doc on disk                    modified 0     0
xschem merge src.sch                          1     1
xschem move_objects abort                     1     1     (the BARE arm)
xschem wire 2000 2000 2100 2000
xschem text 3000 3000 0 0 {..} .. 0           1     1
xschem abort_operation                        0     1     <-- the fix
   wires 3, texts 1: the paste is correctly removed, the new wire and the new text survive
```

Both `abort_operation()` arms are covered: the **bare** arm (reached via
`xschem move_objects abort`, `ui_state == 264`) and the **nested** one (`ui_state == 296`, no
`move_objects abort` needed — the reviewer's click-without-drag door was never required for this
defect).

## The over-correction guard

The obvious way to get E4 green is to stop clearing the flag at all, which would redden nothing in
this issue's rows and quietly break issue 0244's whole point. `0265 E4 control` is the witness: a
clean document, a paste, the gesture's **own** machinery (`move_objects step`, `select_all` —
neither is an edit), then ESC, must still come back **clean**. It does, because neither of those
calls `set_modify(1)`. Sections A2, B, C-control and D8-clean of the same file are the older
versions of the same control and all stayed green.

