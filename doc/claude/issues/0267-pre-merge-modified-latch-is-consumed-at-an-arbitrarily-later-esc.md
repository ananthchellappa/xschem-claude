# 0267 — the `pre_merge_modified` latch is consumed at an arbitrarily later ESC, so edits made while a paste is still pending are marked clean

Status: **OPEN** — measured on the post-0244 tree. **Medium**: it is a *survivor* of the pre-fix
behaviour, not a regression (before issue 0244 that same ESC wrote `modified = 0` unconditionally,
i.e. in every case this issue describes and in many more), but it is the last hole in 0244's
guarantee and it is worth closing with the same fix as **0265**.
Area: `src/paste.c` (the latch in `merge_file()`) vs `src/callback.c` (the two `STARTMERGE` arms
that consume it)
Tests: none. `tests/headless/test_paste_modify_flag_0244.tcl` section A5/A6 pins that the latch is
re-taken per merge; it does not model an edit *between* the arm and the ESC.
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
