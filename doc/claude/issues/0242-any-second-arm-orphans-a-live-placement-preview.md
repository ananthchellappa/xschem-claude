# 0242 — arming anything on top of a live placement preview orphans it: `sympin_preview` outlives `START_SYMPIN` and the canvas goes dead (closes issue 0123's open residual)

Status: **FIXED 2026-08-08** — all 9 defective doors gated, **plus 5 arms the census did not
contain** (found by the new tripwire, `place_net_label` among them — Alt+Shift+L / Ctrl+P /
Ctrl+Shift+P / `xschem net_label`), invariant made atomic at the three `-place` arms, C tripwire
added. Was: measured headless repro (4 keystrokes), 17 doors enumerated, fix sketched. **Critical**: 6 doors left the terminal issue-0123 desync; all 9 defective doors
committed a net label the user never dropped, and the merge/paste doors then reported the document
**clean** (that last half is issue **0244**, landing separately — see "What did NOT change").
Area: `src/select.c:1258` (`unselect_all()` zeroes `ui_state` wholesale) vs the placement teardown
that only existed inside `src/callback.c`'s `abort_operation()`
Tests: `tests/headless/test_placement_preview_doors.tcl` (115 checks, `--nogui`, registered in
`full_audit.sh`'s `nogui_tests`) — 30 of them RED on the pre-fix tree. `xschem get sympin_preview`
(added by 0240) makes the invariant directly assertable; the new C tripwire on stderr is the
second oracle.
Found: 2026-08-06, verifying issue **0240**'s out-of-scope list
Related: **0123** — this is that issue's *"desync ROOT open (no headless repro — needs GUI eyeball)"*
residual; the repro now exists, so 0123's blocker is gone. **0240** (parent; its pre-existing item
2), **0241** (the same teardown's other defect), **0244** (`set_modify(0)` — the `modified=0` half of
the damage here), **0122** E1/E2, `doc/claude/specs/add_wire_label.md` #8,
`doc/claude/specs/cadence_pin_name_text.md` #3, `WIRING.md` §8 class **D**.

## The invariant that is not enforced

0240 stated it and did not enforce it: **`xctx->sympin_preview` must never outlive
`START_SYMPIN`.** One function tears a placement preview down (`callback.c:383-400`); every other
actor that clears the trigger bits skips it.

## Repro — four keystrokes: `l`, a name, `Ctrl+V`

```tcl
set ::label_new_name FOO
proc st {t} { puts [format "  %-10s ui_state=%-6s inst=%-2s modified=%-2s sympin_preview=%s" \
  $t [xschem get ui_state] [xschem get instances] [xschem get modified] [xschem get sympin_preview]] }
xschem clear force; xschem wire 900 900 1000 900; xschem select_all; xschem copy  ;# fill clipboard

xschem clear force; xschem wire 0 0 100 0; xschem unselect_all
xschem add_wire_label -place    ;# `l` + a name -> label preview on the cursor
st armed
xschem paste                    ;# Ctrl+V -> merge_file(2) -> unselect_all(1)
st "after ^V"
puts "  -drop on copper -> [xschem add_wire_label -drop 50 0]"
xschem abort_operation ; st ESC
xschem abort_operation ; st ESC
puts "  leftover: [xschem getprop instance 0 cell::name] lab=[xschem getprop instance 0 lab] \
-> names net [xschem instance_net l1 p]"
```

```
BUG RUN
  armed      ui_state=16424  inst=1  modified=1  sympin_preview=1
  fluid_editing: fluid_gesture_arm() re-armed while a prior gesture was still armed -- it leaked
                 its snapshot (WIRING risk #11.10 mid-STARTMOVE abandon); recovering
  after ^V   ui_state=296    inst=1  modified=1  sympin_preview=1
  -drop on copper -> 0
  ESC        ui_state=0      inst=1  modified=0  sympin_preview=1
  ESC        ui_state=0      inst=1  modified=0  sympin_preview=1
  leftover: lab_pin.sym lab=FOO -> names net FOO
CLEAN CONTROL (identical, minus the `l`)
  clean      ui_state=0      inst=0  modified=1  sympin_preview=0
  after ^V   ui_state=296    inst=0  modified=1  sympin_preview=0
  ESC        ui_state=0      inst=0  modified=0  sympin_preview=0
```

`16424` = `SELECTION|STARTMOVE|START_SYMPIN`; `296` = `SELECTION|STARTMOVE|STARTMERGE` —
`START_SYMPIN` is already gone before ESC arrives. `instance_net l1 p` = `FOO` proves the orphan is
a **connected, netlist-visible** instance silently renaming the net, not a floating glyph. And
`modified` 1 → 0: the document declares itself clean while carrying that rename.

Not label-specific — the Add-Pin (`p`) preview breaks identically, leaving `ipin.sym lab=PIN1`.

## Door census (same arm, one door, then 3× ESC)

| door | ui/`sp` mid | `sp` after | orphan | verdict |
|---|---|---|---|---|
| *(none)* — baseline contract | 16424/1 | 0 | no | clean |
| `paste` (**Ctrl+V**) | 296/1 | **1** | **yes** | terminal desync + orphan |
| `merge` (**`b`**, clipboard merges) | 296/1 | **1** | **yes** | terminal desync + orphan |
| `redo` (**`U`**) | 8/1 | **1** | **yes** | terminal desync + orphan |
| `place_text` (**`T`**) | 0/1 | **1** | **yes** | terminal *on a cancelled dialog* |
| `add_image` (Tools ▸ Insert image) | 0/1 | **1** | **yes** | terminal *on a cancelled dialog* |
| `unselect_all` (script only) | 0/1 | **1** | **yes** | terminal desync + orphan |
| `add_graph` | 16424/1 | 0 | **yes** | orphan |
| `place_symbol` (toolbar / ctx-menu) | 8232/1 | 0 | **yes** | orphan |
| `netlist` | 0/0 | 0 | **yes** | orphan is netlisted |
| `select_all` | 16424/1 | 0 | — | **whole schematic deleted** → that is issue **0241** |
| `undo`, `load`, `clear` | 0/0 | 0 | no | clean |
| `cut` / `delete` | 16416/1 | 0 | no | clean, but the mid-state is a live gesture on a freed object |
| `wire gui` | 16425/1 | 0 | no | clean — that is issue **0243** |
| `descend` / `go_back` / `zoom_full` | 16424/1 | 0 | no | clean |
| `add_sch_pin -place` | 16424/1 | 0 | no | clean — the re-arm path tears down properly |

Honest caveat on two rows: under `--nogui` the `place_text` / `add_image` dialogs cannot open, so
the measured mid-state is `ui=0`. Under X a **cancelled** dialog gives exactly this terminal result
(the `unselect_all(1)` at `scheduler.c:8953` / `:1943` runs *before* the dialog); a **confirmed**
one arms `PLACE_TEXT`/`STARTMOVE`, so ESC's teardown does fire — orphan without the stuck flag.

Tab/window switch is **not** a door: `sympin_preview` lives in `Xschem_ctx` (`xschem.h:1529`), so
`new_schematic("switch")` saves and restores it alongside `ui_state`.

## Root cause

```c
src/select.c:1066-1068
  if((xctx->ui_state & SELECTION) || xctx->lastsel) {
    dbg(1, "unselect_all(%d): start\n", dr);
    xctx->ui_state = 0;
```

A live preview is *always* selected, so that one statement drops `START_SYMPIN | STARTMOVE` without
running the teardown. `sympin_preview` / `wirelabel_preview` are **not** part of `ui_state`
(`xschem.h:1529`, `:1535`), so they survive; the preview instance was never `delete()`d, so it
survives too — now a plain committed, unselected `lab_pin`/`ipin`.

Of 87 `unselect_all()` call sites, the reachable-while-armed ones are the doors: `merge_file()`
(`paste.c:547`), `place_text` (`scheduler.c:8953`), `add_graph` (`:1903`), `add_image` (`:1943` —
*before* `tk_getOpenFile`), and `pop_undo_keep_selection()` (`select.c:2409`, **unconditional**, so
`redo` is a door even with an empty redo stack). `place_symbol` reaches the same end state without
`unselect_all` — it just `|= PLACE_SYMBOL` over the preview (`scheduler.c:8940`).

**Why it is terminal**, by the two guards 0123 and 0240 installed:
- `callback.c:7877-7878` — the entire Button-1 click-select/grab block requires
  `!xctx->sympin_preview`. Stuck at 1 ⇒ no press can ever select, grab or complete anything.
- `callback.c:2843` — `wire_label_try_commit()` returns 0 when `START_SYMPIN` is gone, so `-drop`
  on copper refuses forever (measured).
- Even *before* the ESC it is dead: with `STARTMERGE` pending, `end_place_move_copy_zoom()`'s
  STARTMOVE arm (`:2927`) hits `if(xctx->wirelabel_preview) { wire_label_try_commit(); return 1; }`
  (`:2932-2935`), which refuses **and swallows the click** — so the pasted objects cannot be
  dropped either.

Class: `WIRING.md` §8 **D (decline residue)**, one level up from 0240 — the teardown is correct but
lives in exactly one function.

## Why issue 0240 does not cover it

0240 fix (A) only decides *whether control reaches* `callback.c:383`; it never changes *what `:383`
tests*. Measured at ESC time on the paste door with `ui_state == 296`:

```
STARTMOVE(32)                        = 1  -> callback.c:380 block ENTERED
START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT = 0  -> callback.c:383 FALSE, teardown :384-399 SKIPPED
STARTMERGE(256)                      = 1  -> callback.c:401 delete(1) on the MERGED selection only
```

The door cleared `START_SYMPIN` *before* ESC arrived. 0240 fix (B) is directional the other way — it
abandons a live wire draw when Add-Wire-Label is entered — and never touches `START_SYMPIN` or
`sympin_preview`.

## Fix sketch

Mirror 0240-B's shape. **Do not put the teardown inside `unselect_all()`** (87 call sites, several
inside netlisting and live fluid passes — 0123's own stated reason — and it would make a *deselect*
silently delete objects).

1. **Extract** `callback.c:383-400` into `int abort_placement_preview(void)`, sibling of
   `abort_wire_line_command()` (`callback.c:494`): `move_objects(ABORT)` if `STARTMOVE`,
   `delete(0)`, `set_modify(save)`, clear `START_SYMPIN` / `sympin_preview` / `wirelabel_preview`;
   return 1 if it did anything, plus a `statusmsg()`. `abort_operation()` calls it — zero behaviour
   delta there.
2. **Gate it on `(ui_state & START_SYMPIN) && sympin_preview`.** Load-bearing and empirical: the
   three `-place` re-arms deliberately call `unselect_all(1)` with `sympin_preview == 1`
   (`scheduler.c:1748`, `:1797`, `:1866`) but clear `START_SYMPIN` two lines earlier (`:1743`,
   `:1792`, `:1860`), so the helper no-ops there — while at **every** door `START_SYMPIN` is still
   set. Get this wrong and each form keystroke pushes a second undo baseline
   (`add_wire_label.md:124`).
3. **Call it at the arming sites**, before their `unselect_all`: `merge_file()` (`paste.c:547`),
   `place_text` (`scheduler.c:8953`), `place_symbol` (`:8914` branch), `add_graph` (`:1903`),
   `add_image` (`:1943`). For undo/redo call it in the **scheduler verbs**, not inside
   `pop_undo_keep_selection()` — it must run against a consistent object model, before the stack
   pointer moves.
4. **A tripwire, not an assert** (C89; `abort()` in a GUI app is not acceptable):
   `if(xctx->sympin_preview && !(xctx->ui_state & START_SYMPIN)) dbg(0, …)` / `fltrace(…)` at the
   entry of `callback()` and of `xschem()`, in the style of the existing witness at
   `callback.c:7859-7862`. That turns "how many doors are left" into an empirical question forever.

Fold in `callback.c:415`'s unconditional `set_modify(0)` (issue **0244**) — it produces the
`modified=0` half of the corruption here.

## Landmines

- **The one-baseline-per-gesture contract** is the sabotage target: drop the `START_SYMPIN` term in
  step 2 and the undo-depth checks in `test_add_wire_label.tcl` / `test_sch_add_pin.tcl` must go
  red, and only those.
- **`add_graph`'s undo depth will move — because a live bug is being removed.** 0240's comment at
  `callback.c:389-391` claims *"a live preview always has START_SYMPIN set, so a STALE
  sympin_preview cannot make an UNRELATED placement abort drop its undo snapshot"*. That premise is
  **false for `add_graph`**, which re-sets `START_SYMPIN` at `scheduler.c:1932` after its own
  `unselect_all(1)`: measured `before add_graph: sp=1 ui=16424` → `after: sp=1 ui=16424`, so `:393`
  evaluates to `delete(0)` and an aborted **graph** is removed with no undo baseline of its own.
- **`merge_file()` is on the action-log replay path** (`xschem paste x y … -file {f}`,
  `scheduler.c:8687`). The `START_SYMPIN` gate covers replay (no preview live), but run the
  replay/`log_action` tests explicitly — see the coordinate-form-bypass note at `scheduler.c:8648`.
- **Behaviour change needing the same ratification 0240-B got:** `Ctrl+V` during a live preview will
  *discard* the preview. 0240 scoped its policy call to Add-Wire-Label alone on purpose.
- **`cut`/`delete` leave a live gesture pointing at a freed object** (mid-state `ui=16416` with
  `inst=0`). It self-heals on ESC, so it is not this defect, but it is a dangling-gesture window
  worth a line in `WIRING.md` §11.
- Re-run green: `test_add_wire_label.tcl` (82), `test_sch_add_pin.tcl`, `test_label_ride.tcl` (157),
  `test_label_strand_oracle.tcl` (32), `test_wire_split.tcl` (119), `wireedit` (58/58),
  `headless/run.sh` (6/6), `run_regression.tcl` (same 3 pre-existing `test_ihp_sg13g2_libmgr`
  FAILs).
- **The visual half is not headless-testable** (`WIRING.md` §8 I/K) — expect the grey rubber ghost
  in the GUI and confirm by eye, as in 0240.

---

## What landed (2026-08-08)

The sketch above was written before **0241** and **0243 F2** landed. Those two already did step 1:
`abort_placement_preview()` exists (`callback.c`), scoped to the preview's stamped identity, and
`leave_placement_for()` (`callback.c`) is the ratified *door* wrapper around it — gate, teardown,
`statusmsg_hold()`. Step 2's gate is likewise already in place and is *broader* than the sketch
asked (`ui_state & (START_SYMPIN | PLACE_SYMBOL | PLACE_TEXT)`), which still satisfies the
load-bearing requirement: the three `-place` re-arms clear `START_SYMPIN` before their
`unselect_all(1)` and set neither `PLACE_` bit, so the helper no-ops there.

So this issue landed steps **3** and **4**, plus one thing the sketch did not anticipate.

### 1. Door calls (step 3) — `leave_placement_for()`, not a bare teardown

Using the ratified wrapper rather than calling `abort_placement_preview()` directly buys the
0248 status line, the `readonly` carve-out and the `gate_bypass` test seam for free, and keeps one
policy in one place. Its doc comment is generalized accordingly.

| site | file | why there |
|---|---|---|
| `merge_file()`, inside `if(fd)`, before `push_undo()` | `paste.c` | the ONE funnel behind `paste`, `merge`, Ctrl+V **and** the `-file` replay form. Inside `if(fd)` so a cancelled Merge dialog does not destroy the preview; before `push_undo()` so the merge's undo baseline is the schematic *without* the preview (otherwise undoing the paste resurrects it) |
| `place_symbol` | `scheduler.c` | reaches the orphan with no `unselect_all` at all — it ORs `PLACE_SYMBOL` over the live preview, so both placements share one `STARTMOVE` |
| `place_text` | `scheduler.c` | before the text dialog, so a **cancelled** dialog cannot leave the terminal state |
| `add_graph` | `scheduler.c` | also repairs the undo landmine below |
| `add_image` | `scheduler.c` | before the file chooser, same rule as the wire gate beside it |
| `undo` / `redo` verbs | `scheduler.c` (`perform_action`) | at the VERB, never inside `pop_undo_keep_selection()` — the teardown is a `delete()` and must run against a consistent object model, before the stack pointer moves |
| `place_net_label()` | `actions.c` | **a door the census did not contain** — see below |
| `start_place_symbol()` | `callback.c` | keyboard `I`/Insert + context-menu twin of the `place_symbol` verb |
| context-menu Insert text | `callback.c` | twin of the `place_text` verb |
| `t` key | `callback.c` | twin of the `place_text` verb |
| screen grab release | `draw.c` | arms `START_SYMPIN`+`STARTMOVE` like `add_image`; GUI-only, proved by code |

**The census was five arms short**, and the fix would have shipped that way if the tripwire had not
been built first. The doors were enumerated from the 17 verbs the issue measured; the *arms* are
the twelve `stamp_placement_preview()` sites (`ui_state |= START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT`),
four of which are the form re-arms that must NOT be gated and five of which had no gate. This is
0247's lesson repeating verbatim (`WIRING.md` §8 D): *enumerate the arms from the ui_state bits
they set, not from the verbs the bug report happened to name.*

The one that matters most is **`place_net_label()`** — Alt+Shift+L, Ctrl+P, Ctrl+Shift+P and the
scripted `xschem net_label 0|1|2|3`, four everyday keybindings on the same helper. Measured
`orphan=1` on every type before the gate, and it is *headlessly testable*, so it is now rows
B10–B13 of the test. It was found by the tripwire firing on a run that had nothing to do with it,
which is the entire argument for building the tripwire before declaring the census closed.

### 2. The tripwire (step 4)

`check_placement_preview_invariant()` (`callback.c`), called at the entry of `callback()` and of
`xschem()`. `dbg(0)`, so no `-d` flag is needed. It reports the **transition**, once per desync
episode, not the state — at `callback()` entry it runs on every motion event and a stuck flag
would otherwise emit thousands of identical lines.

### 3. The thing the sketch did not anticipate: the invariant was not testable

Sited as specified, the tripwire fired on **every healthy arm**. The three `-place` arms raise
`sympin_preview` *before* the preview exists and hold it across the whole arm — and
`place_symbol()` re-enters `xschem()` through its own `tcleval`s (`abs_sym_path`,
`is_xschem_file`, `tcl_hook2`). So `sympin_preview && !START_SYMPIN` — the exact desync
signature — was **also the normal mid-arm state**, and the re-arm window repeated it on every
keystroke.

Fix: make the pair atomic in all three arms (`add_symbol_pin`, `add_sch_pin`, `add_wire_label`) —
clear `sympin_preview` with `START_SYMPIN` at the re-arm, raise it with `START_SYMPIN` on the
success path, instead of before the object is placed. The undo contract is untouched: which branch
runs still decides whether a baseline is pushed, and that decision is read before either flag is
written.

Measured: a healthy 6-keystroke arm emitted **11** tripwire lines before this change and **0**
after. The whole 115-check suite now emits exactly **one** line — the door deliberately left
ungated (below).

### 4. Comment corrected (landmine)

0240's claim at the `delete(0)/delete(1)` discriminator — *"a live preview always has
`START_SYMPIN` set"* — was **false for `add_graph`**, which re-sets `START_SYMPIN` after its own
`unselect_all(1)`, so an aborted graph was removed with no undo baseline. The door call makes the
premise true rather than assumed; the comment now says so, and the conjunct stays as the local
guard for a future ungated arm. Side effect noted in the issue text: `add_graph`'s undo depth on
that path legitimately moves, because a live bug is being removed.

## Verification

Repro from §"Repro" above, re-measured on today's tree before the fix — byte-identical to the
2026-08-06 capture. After the fix:

```
BUG RUN
  armed      ui_state=16424  inst=1  modified=1  sympin_preview=1
  after ^V   ui_state=296    inst=0  modified=1  sympin_preview=0
  ESC        ui_state=0      inst=0  modified=0  sympin_preview=0
  leftover: none
```

Door census re-measured (17 verbs armed against a live label preview, then 3x ESC). 0241/0243 had
already closed `select_all`, `wire gui` and `cut`/`delete`; the 9 rows this issue names are all
clean now, with two documented exceptions:

| row | after | note |
|---|---|---|
| paste / merge / paste-replay / redo / undo / place_text / place_symbol / add_graph / add_image | `sp=0`, no orphan | fixed |
| `xschem unselect_all` (verb) | `sp=1`, orphan | **issue 0262** — deliberately not gated |
| `netlist` | `sp=0`, orphan | **issue 0263** — clears no gesture bits, so not a door |

### Sabotage results — two of the three predictions were wrong, honestly reported

- **"Drop the `START_SYMPIN` term and the undo-depth checks go red."** It does nothing. Once the
  flag pair is atomic, `sympin_preview` is never 1 without `START_SYMPIN`, so the conjunct in the
  `delete()` discriminator is provably redundant. Kept as defence in depth, not as a live guard.
- **"…the undo-depth checks in `test_add_wire_label.tcl` / `test_sch_add_pin.tcl`."** Those checks
  **do not exist**: neither file asserts undo depth (`grep`). The one-baseline-per-gesture contract
  was unasserted anywhere in the suite. Section C3b of the new test is that oracle.
- The sabotage that *does* bite — forcing the teardown to fire AT a `-place` re-arm, which is what
  step 2's gate really prevents — turns **exactly one** check red (`C3b undo 2 reaches PAST the
  gesture`) and nothing else. It needs **two** real edits and **two** undos: one undo cannot tell
  the cases apart, because every spurious per-keystroke baseline snapshots the same document.

Re-run green: `test_add_wire_label` (178), `test_sch_add_pin` (21), `test_label_ride` (157),
`test_label_strand_oracle` (32), `test_wire_split` (`OVERALL: ok`), `test_placement_wire_gate`,
the replay/log group, `wireedit`, `headless/run.sh`, `run_regression.tcl` (same pre-existing
`test_ihp_sg13g2_libmgr` FAILs).

## What did NOT change

- **Issue 0244** (`callback.c`'s unconditional `set_modify(0)` in the two `STARTMERGE` arms) is
  **not** folded in — user decision, 2026-08-08. It is independent: after this fix the paste door
  tears the preview down *before* `merge_file()` runs, so no orphan exists to be reported clean,
  and the `set_modify(0)` clobber survives only on 0244's own repro (dirty doc + plain paste + ESC,
  no preview). Different root cause (a missing pre-merge latch), different files, its own control
  matrix and its own user-visible change. The new test therefore does **not** assert `modified` on
  the merge doors.
- **The teardown is still not inside `unselect_all()`** — 87 C call sites and 817 scripted ones,
  several inside netlisting and live fluid passes, and it would make a *deselect* silently delete
  objects. Issue 0123's stated reason still holds.
- **The visual half is not headless-testable** (`WIRING.md` §8 I/K): the grey rubber ghost on each
  door needs a GUI eyeball, as 0240 did. Not yet done.
