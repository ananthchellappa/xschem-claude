# 0241 — a cancelled placement deletes **the selection**, not the preview: `Ctrl+A` while the Add-Label/Add-Pin form is armed wipes the whole schematic, and the dirty flag says it is clean

Status: **FIXED 2026-08-08** (branch `open_pdk`). Was **critical**: silent whole-document loss on a
two-gesture path that contains no `Delete` and, in the shortest route, no `ESC` either.
Area: `abort_placement_preview()` (`src/callback.c`, factored out of `abort_operation()` by issue
0243 F2) and the three modeless-form RE-ARM drops (`src/scheduler.c`, `add_symbol_pin` /
`add_sch_pin` / `add_wire_label`); `delete()` is selection-scoped (`src/select.c` `delete()`); the
twelve arm sites that establish the assumption (`grep -n "ui_state |= START_SYMPIN\|ui_state |=
PLACE_SYMBOL\|ui_state |= PLACE_TEXT" src/*.c`)
Tests: `tests/headless/test_add_wire_label.tcl` section **H** (88 → **178** checks) and
`tests/headless/test_placement_wire_gate.tcl` **E7**, rewritten to assert the opposite of the
decline guard it used to pin (169 → **171**)
Found: 2026-08-06, by the adversarial review of issue **0240** (raised, then confirmed pre-existing
and out of that fix's scope)
Related: **0240** (parent; its "Pre-existing defects" list item 1), **0242** (the other half of the
same teardown's brokenness), **0244** (the merge arm's dirty-flag reset, which compounds this),
`doc/claude/specs/cadence_pin_name_text.md` item #3 (the `delete(0)` rule this must not break),
`WIRING.md` §8 class **D**.

## The defect in one line

The teardown deletes *whatever is selected*, on the assumption that the selection is exactly the
transient preview. Nothing enforces that assumption, and anything that grows the selection between
the arm and the cancel — `Ctrl+A` is the shortest — turns the cancel into a whole-document delete.

## Repro (headless, no X)

```tcl
set ::label_new_name FOO
proc doc {} {
  xschem clear force
  xschem wire 0 0 100 0
  xschem instance devices/lab_pin.sym 300 0 0 0 {name=p1 lab=AAA}
  xschem unselect_all
  xschem saveas /tmp/min.sch ; xschem load /tmp/min.sch   ;# so modified == 0
}
proc r {t} { puts "$t wires=[xschem get wires] inst=[xschem get instances] modified=[xschem get modified]" }

doc ; r "doc             "
xschem add_wire_label -place   ;# `l` -> preview armed (ui_state=16424, sympin_preview=1)
xschem select_all              ;# Ctrl+A
xschem abort_operation         ;# ESC  (or just close the form -- see below)
r "BUG  (Ctrl+A+ESC)"
xschem undo ; r "  after 1 undo"

doc ; xschem add_wire_label -place ; xschem abort_operation
r "CTRL (just ESC) "
```

```
doc                wires=1 inst=1 modified=0
BUG  (Ctrl+A+ESC)  wires=0 inst=0 modified=0      <-- whole schematic gone, still "unmodified"
  after 1 undo     wires=1 inst=1 modified=1
CTRL (just ESC)    wires=1 inst=1 modified=0      <-- correct: only the preview removed
```

No `STARTWIRE` anywhere (`last_command=0`) — this is **not** issue 0240's wire clash.

**What survives: nothing.** With 8 objects selected, the saved `.sch` goes from
2×`N`, 2×`C`, `L`, `B`, `P`, `T` to the `v/G/K/V/S/F/E` header records alone. Wires, instances,
lines, boxes, polygons, arcs and texts all go.

**It is not a `Ctrl+A` bug, it is a "selection grew" bug** — `xschem select_dangling_nets` in place
of `select_all` wipes the document identically.

**A fourth door, found while fixing this (2026-08-08) and not in the repro above: there need be no
cancel key at all.** The Add-Label / Add-Pin forms are modeless and re-issue `-place` on EVERY
keystroke; the re-arm drops the previous preview with its own `delete(0)` (`src/scheduler.c`, three
identical blocks). That delete was selection-scoped too, so *typing one more character in the Name
field* after a `Ctrl+A` took the drawing:

```
doc                    wires=2 inst=1 texts=1
arm, select_all, arm   wires=0 inst=1 texts=0   <-- only the freshly armed preview left
```

It is fixed by the same narrowing and pinned by section **H3**.

## Root cause

(ANCHOR CORRECTION, 2026-08-07: issue 0243 F2 moved this code out of `abort_operation()` into
`abort_placement_preview()`, which `abort_operation()` calls at its `STARTMOVE` branch and which
`leave_placement_for()` also calls. The `delete()` blamed below lives there now. Everything else in
this section stayed true.)

`src/callback.c`, `abort_placement_preview()` — before the fix:

```c
  if(xctx->ui_state & STARTMOVE)
  {
   move_objects(ABORT,0,0,0);
   if(xctx->ui_state & (START_SYMPIN | PLACE_SYMBOL | PLACE_TEXT)) {
     int save;
     save =  xctx->modified;
     delete((xctx->sympin_preview && (xctx->ui_state & START_SYMPIN)) ? 0 : 1/* to_push_undo */);
     set_modify(save); /* aborted placement: no change, so reset modify flag set by delete() */
```

`delete()` is selection-scoped (`select.c:684`, `:697` — `rebuild_selected_array()` then remove
every `SELECTED` object). The "selection == preview" invariant is established only at the *arm*,
where each site does `unselect_all(1)` and then selects exactly the preview
(`scheduler.c:1866-1874` Add-Wire-Label, `:1748-1753` Add-Pin, `:8936-8940` / `callback.c:465-469`
PLACE_SYMBOL, `:8956-8960` PLACE_TEXT). `select_all()` (`select.c:2284-2325`) is a pure selection
mutator with no gesture awareness: it never inspects `STARTMOVE`/`START_SYMPIN`, so after it the
invariant is simply false and `delete()` takes the document.

The state left behind is **consistent** (`START_SYMPIN` and `sympin_preview` both cleared) — this
is plain over-deletion, not the 0123/0240 desync.

Age: upstream and older than all preview work. `git log -S` puts the
`(START_SYMPIN | PLACE_SYMBOL | PLACE_TEXT)` widening at `8281c67a` (2021-11-04, *"aborting
operation during move will now delete placed objects"*), over an already-existing
`if(ui_state & START_SYMPIN) { delete(1); … }`. The `delete(0)` refinement is `93a54f76`.

## Why it is worse than "you can undo it"

`undo` *does* restore the simple case — the `-place` arm pushed a baseline
(`scheduler.c:1862`). The damage is elsewhere:

| door | after ESC | after one `undo` |
|---|---|---|
| label preview, no edits after the arm | `0/0` | full document back — **recovered** |
| edits made after the arm (the form is modeless) | `0/0` | one wire **lost for good**, and the never-dropped preview label `l1` comes back **as a committed object** (`delete(0)` pushes nothing, so the stack top is one edit stale) |
| `PLACE_SYMBOL` | `0/0` | document restored **containing the never-placed component** (`delete(1)` snapshotted the preview) |
| merge / paste (`Ctrl+V`) | `0/0`, `modified` forced to **0** by `callback.c:404` | restores **the merged state the ESC was cancelling** |

`redo` re-applies the wipe.

**And the dirty flag lies.** From a saved document: arm, `Ctrl+A`, ESC → `wires=0 inst=0
modified=0`, because `set_modify(save)` (`callback.c:394`) restores the *pre-delete* value on the
assumption that nothing but the preview went. The quit/close prompt is gated on exactly that flag
(`xschem.tcl:13664`, `if {[xschem get modified]} { … "has unsaved changes" }`), so an empty
schematic closes without a word, and `xschem reload force` succeeds with no prompt.

## GUI reachability — nothing guards any of it

- **Selection growers:** `Ctrl+A` on canvas (`callback.c:6088-6090`, no `ui_state` guard), Edit ▸
  Select all (`xschem.tcl:14682` → `scheduler.c:10682`), `select_dangling_nets`.
- **Cancel doors:** canvas ESC (`callback.c:7348`); **the form's own window-close button** —
  `addlabel::on_destroy` → `abort_if_placing` → `xschem abort_operation` (`xschem.tcl:11384`,
  `:11228`), and the `addpin::` (`:10881`) / `ciform::` (`create_instance.tcl:39`) twins; context
  menu abort (`callback.c:4395`); the cadence double-click teardown (`:8417`); the `.load` dialog
  Cancel (`xschem.tcl:7160`, `:7317`).

So **"open Add Wire Label, press `Ctrl+A`, close the form"** wipes the schematic — no `ESC`, no
`Delete` key, no confirmation, no dirty flag.

Control that bounds the scope: a plain `STARTMOVE` with no placement bit (`ui=40`) + `select_all` +
ESC leaves the document intact. The teardown only fires with
`START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT` (or `STARTMERGE`) co-set.

## Fix sketch

**Principle: delete the preview, not "whatever is selected."** Re-establish the invariant at the
delete rather than trusting it.

1. **Record the preview's identity at arm.** A durable handle next to `sympin_preview`
   (`xschem.h:1529`), keyed on `xInstance.id` — the session-stable handle documented at
   `xschem.h:907-912`, already used this way for selection-across-undo (`select.c:2335+`, issues
   0007/0095). Stamp it at every arm site; clear it wherever `sympin_preview` is cleared.
2. **Narrow before deleting.** Immediately before `callback.c:393`: `unselect_all(0)`, re-select
   only the recorded object, `rebuild_selected_array()`, then the existing `delete(...)` unchanged.
   The `delete(0)`-when-`sympin_preview` choice and the `save`/`set_modify(save)` pair both become
   *correct* once the scope is right.
3. **Backstop:** if the handle resolves to nothing, delete nothing and just clear the flags. A
   stray preview is cosmetic; a wiped schematic is not.
4. **Same treatment for the merge arms** (`callback.c:401-405`, `:413-416`) — narrow the
   `delete(1)` to what `merge_file()` pasted, and replace the unconditional `set_modify(0)` with the
   save/restore idiom (that reset is issue **0244**; the two defects compound here).
5. **Optional belt, not a substitute:** make `select_all` decline (or first cancel the placement)
   while `ui_state & (START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT|STARTMERGE)`, gated at the command site
   (`scheduler.c:10682` / `callback.c:6089`) the way 0240 gated `add_wire_label`. It closes only the
   `Ctrl+A` door — `select_dangling_nets` still reproduces — so ship it *with* 2, never instead.

## Landmines for whoever fixes it

- **The preview is not always one object.** An Add-Pin preview is a pin **rect plus its owned name
  text** (measured: `texts 0 → 1` at arm). Re-select the rect and let the existing cascade
  (`select.c:708-726`) pull the text; do not hand-pick it. A multi-instance placement
  (`xschem instance … n`) needs a set, not a scalar — a scalar silently under-deletes (the safe
  direction, but make it a conscious choice).
- **`to_push_undo` must not change.** `tests/pin_name_text.tcl` regression 11 (`:259`) is an
  explicit sabotage check on `delete(0)` vs `delete(1)`, and 11c (`:279`) guards the stale
  `sympin_preview` desync.
- **0240's section-G checks pin the *effects*** — `test_add_wire_label.tcl:211/213/215`
  (`sympin_preview` 0, preview instance deleted, `lastsel` 0). The narrowing must keep `:213`
  exactly; `:215` forces a deliberate decision about whether ESC keeps the user's *other*
  selection.
- **`escape_deselects` is already dead in this branch** — the STARTMOVE arm `return`s at
  `callback.c:406`, before `if(deselect) unselect_all(1);` at `:418` (measured: with
  `escape_deselects=1`, ESC leaves `ui=8 lastsel=1`). Not the defect, but it is why the
  post-teardown selection state is ad-hoc; anything touching the branch tail should settle it.
- **Do not gate `delete()` itself** on selection size — that is the ordinary user delete path.
- Other suites that would catch selection-semantics drift: `test_create_instance.tcl`,
  `test_add_pin_lib_symbol_view.tcl`, `test_drag_keeps_selection.tcl`, `test_verb_noun_copy_move.tcl`,
  `test_wire_stub_bindings.tcl`, `test_cmdmode_descend_0201.tcl`.

## Tests to add (RED-first)

New section in `test_add_wire_label.tcl`: after `-place` + `select_all` + `abort_operation`, assert
`wires`/`instances`/`texts` equal their pre-arm counts, no `lab_pin` named by `::label_new_name`
survives, `sympin_preview == 0`, and `modified` equals its pre-arm value. Repeat for
`add_symbol_pin -place`, `place_symbol`, `xschem merge <f>`, and once with `select_dangling_nets`
instead of `select_all`. Sabotage: revert the narrowing -> those checks and only those go red.
Note `rects`/`lines`/`polygons`/`arcs` have no `xschem get` counter, so quantify survival by
`xschem saveas` + diffing record lines.

---

# THE FIX (2026-08-08)

## What it does

**The teardown names what it is tearing down.** Every one of the twelve placement arms now stamps
the preview's identity, and both places that remove a preview with `delete()` re-select exactly
that stamp before deleting.

1. **`PlacePreview {unsigned short type; unsigned int id;}`** (`src/xschem.h`, next to `Selected`)
   and three fields on `Xschem_ctx` beside `sympin_preview`: `preview_sel` / `preview_sel_n` /
   `preview_sel_size`. Per-object **session-stable ids**, not array indexes — the forms are
   modeless, so arbitrary edits (and undos) can happen between the arm and the cancel, and indexes
   do not survive them. Every object type already carries such an id (`xWire`/`xLine`/`xRect`/
   `xPoly`/`xArc`/`xText`/`xInstance`), so the mechanism is general, not instance-only.
2. **`stamp_placement_preview()` / `select_placement_preview()` / `clear_placement_preview()`**
   (`src/select.c`, immediately after the selection-across-undo restore they are modelled on;
   prototypes in `xschem.h` beside `unselect_all`).
3. **The stamp is THE SELECTION AT THE ARM**, not a hand-picked object. That is precisely the set
   `move_objects(START)` grabs, which is what the cancel has always been trying to remove — and it
   is not always one object:
   - Add-Pin: a `PINLAYER` rect **plus** its owned name-view text (both `SELECTED` by `create_pin`);
   - a `type=scope` symbol: the instance **plus** its attached graph floater
     (`select_attached_floaters`);
   - the screen grab (`draw.c`) and `place_text()` (`t`, context-menu 6, `xschem place_text`)
     **never `unselect_all()` first**, so the user's pre-existing selection deliberately rides the
     cursor with the preview and is dropped with it.
   Stamping the selection therefore reproduces the old teardown *member for member* whenever
   nothing grew the selection afterwards, and fixes it when something did. It also means no arm
   site needed special-casing: one call, twelve sites.
4. **`abort_placement_preview()`** (`src/callback.c`) wraps its `delete()` in
   `if(select_placement_preview() > 0)`. The `delete(0)`/`delete(1)` discriminator, the
   `save`/`set_modify(save)` pair and the undo baseline are all **unchanged** — they become correct
   once the scope is right. **Backstop:** nothing resolves -> delete nothing, just clear the flags.
5. **The three modeless-form RE-ARM drops** (`src/scheduler.c`, `add_symbol_pin` / `add_sch_pin` /
   `add_wire_label`) get the identical narrowing. This is the door with no cancel key in it (see
   the fourth-door repro above) and it was **not** in the original sketch.
6. **The 0241 decline guard is gone** from `leave_placement_for()` (`src/callback.c`) — see below.
7. Cleared wherever a preview stops being live without a teardown: both commit paths
   (`wire_label_try_commit`, `end_place_move_copy_zoom`), both failed arms, and `clear_drawing()`
   (load / clear / new / undo reload — the next document restarts the id counters, so a surviving
   stamp could otherwise resolve onto an unrelated new object).

## What the guard removal buys

`leave_placement_for()` used to `return 0` while `xctx->lastsel > 1`, refusing to start a wire/line
draw with the statusbar line *"finish or ESC the pending placement first (a multiple selection is
live)"*. That guard existed **only** because of this issue (0243 F2's carve-out). It was the single
inconsistency left in the ratified modal-gesture rule — every other verb cancelled the pending
gesture, that one refused. It is deleted, and the function now always returns 1 (the `int` result
is kept so a future refusal needs no call-site churn).

## The decision that was NOT taken

Narrowing makes *"ESC removes the preview and keeps my selection"* newly possible. **It was not
taken.** `test_add_wire_label.tcl` G2 (`0240 ESC leaves nothing selected`) ratified `lastsel == 0`
on this path; changing it is a separate, user-facing decision, not something to let fall out of a
scoping fix. The cancel therefore **deselects** the user's other objects and **keeps** them, and
section H1 now pins that with its own check per verb rather than leaving it implicit.

## Defects the review of this fix found (both fixed before landing)

A 4-lens adversarial review of the diff (memory / completeness / behavioural-regression / C89)
raised 12 candidate defects; 9 were refuted, 3 confirmed — 2 of them the same one. Recorded here
because the first is the kind of mistake this shape of fix invites.

1. **HIGH — the narrowing WIDENED the delete for PARTIAL selections.** `delete()` removes an
   object only when `sel == SELECTED` exactly, but `rebuild_selected_array()` admits any non-zero
   `sel`, and a stretch box-select marks a wire/line `SELECTED1`/`SELECTED2` and a rect
   `SELECTED1..4` — a genuine user selection of one ENDPOINT that `delete()` is a provable no-op
   on. The first version of `stamp_placement_preview()` stamped every `sel_array` entry regardless
   of its `sel` VALUE, and `select_placement_preview()` re-selects with `SELECTED`, which
   **promoted** them. So the "narrowing" destroyed objects the un-narrowed code left standing —
   silently, because `set_modify(save)` then restored the clean flag. Measured on the first build:

   ```
   3 wires, stretch-selected at one endpoint each   wires=3 lastsel=3 ui=8
   net_label 0 (arms without unselecting)           wires=3 lastsel=3 ui=16424
   `w`  (leave_placement_for -> teardown)           wires=0 lastsel=0 ui=1   <-- all three gone
   ```

   Worse than the pre-fix state on that path, because the decline guard this fix removes refused in
   exactly the multi-selection state that then wiped the drawing on one keystroke. **Fix:** the
   stamp skips any object whose `sel != SELECTED`, so it names exactly the set `delete()` would
   have taken. Pinned by **H7**, whose first check is the control that the plain delete really is a
   no-op on that selection — without it H7 would prove nothing.

   Reachable from the three arms that deliberately keep the user's pre-existing selection (`t`,
   context-menu Insert text, screen grab) and from `place_net_label()`'s unconditional arm.

2. **LOW — a repaint hole on the backstop path.** `select_placement_preview()` drops the selection
   with `unselect_all(0)` (no erase) on the promise that `delete()`'s trailing `draw()` repaints —
   true only when it returns > 0. When the stamp resolves to nothing the caller skips `delete()`,
   and `abort_operation()`'s `STARTMOVE` arm returns before its own `draw()`, so the SELLAYER
   highlight of the just-deselected objects stayed painted until an unrelated redraw. Confirmed by
   the reviewer with pixel captures under X (0 changed pixels across the abort, 3756 across the
   following explicit redraw; the control case, where the delete does run, showed 5346 / 0).
   **Fix:** `abort_placement_preview()` calls `draw()` on the else branch, restoring exactly the
   repaint the unconditional `delete()` used to give. GUI-only, so it has no headless witness — the
   three `scheduler.c` re-arm drops were never affected, since each does `unselect_all(1)` a few
   lines later.

Refuted, for the record: `my_realloc` misuse (the wrapper handles NULL and preserves contents;
`preview_sel_size` is a high-water mark and can never be exceeded), a double-free across tabs
(`save_xctx` holds `Xschem_ctx *`, so each window frees its own once), the `ui_state` save/restore
resurrecting a dead bit, and every C89 complaint (the new code compiles clean under
`-std=c89 -pedantic -Wall -Wdeclaration-after-statement`).

## What is still wrong (NOT fixed here)

- ~~**The merge / paste arm still over-deletes.**~~ **CLOSED 2026-08-08 by issue 0244 part B**, with
  exactly the reuse this bullet predicted: `merge_file()` (`paste.c`) calls
  `stamp_placement_preview()` immediately before `ui_state |= STARTMERGE`, and **both**
  `abort_operation()` `STARTMERGE` arms wrap their `delete(1)` in
  `if(select_placement_preview() > 0)` — same backstop, same `else { draw(); }` repaint debt on the
  arm that returns early. The merge stamp shares the `preview_sel` slot; 0244 records why that is
  safe (and corrects the premise that a merge and a placement can never be co-armed — they can, and
  the co-armed stamp is a superset). Measured before it landed, on the 0241-fixed binary:

  ```
  doc                  wires=1 inst=1 modified=0 ui=0
  after merge          wires=2 inst=1 modified=1 ui=296   [SELECTION|STARTMOVE|STARTMERGE]
  merge+CtrlA+ESC      wires=0 inst=0 modified=0 ui=0     <-- wiped, and reported "clean"
  ```

  Now: the survivors survive and the flag stays dirty
  (`tests/headless/test_paste_modify_flag_0244.tcl` sections C and D).
- **Issue 0242** — the other actors that clear `START_SYMPIN`/`STARTMOVE` with no teardown at all
  (notably `unselect_all()` at `select.c`, i.e. paste/merge/redo/place_text/add_image) still orphan
  a preview. A stamp left behind by such an actor is inert (the placement bits are gone, so the
  teardown returns early) but the preview object is still stranded in the drawing.
- **The optional `select_all` belt (sketch item 5) was NOT shipped.** It closes only the `Ctrl+A`
  door — `select_dangling_nets` reproduces without it — so it was never a substitute for the
  narrowing, and with the narrowing in place it buys nothing. Section **H2** is the standing proof
  that the fix is not a `select_all` veto.
- **`place_net_label()` still arms unconditionally** (`actions.c`: `place_symbol()`'s return value
  is discarded), so an unresolvable label symbol arms `START_SYMPIN` with no preview. Behaviour is
  unchanged by this fix — the stamp then captures whatever was already selected, exactly as the old
  `delete()` would have taken it — but it is an 0242-family arm-with-no-preview and worth closing
  there.

## Tests

| file | before | after |
|---|---|---|
| `tests/headless/test_add_wire_label.tcl` | 88 | **178** (new section **H**) |
| `tests/headless/test_placement_wire_gate.tcl` | 169 | **171** (**E7** rewritten) |

Section **H** covers all four doors: H1 (ESC / form-close, per verb: `add_wire_label -place`,
`add_sch_pin -place`, `add_symbol_pin -place`, `place_symbol`, `net_label 0`), H2 (the grower is
`select_dangling_nets`, not `select_all`), H3 (the re-arm keystroke door), H4 (a wire verb on a
live preview + a grown selection — the ex-guard path), plus three CONTROLS: H5 (nothing but the
preview selected -> behaves exactly as it always did, the under-delete witness), H6 (a plain
`STARTMOVE` with no placement bit has no teardown and must delete nothing) and H7 (PARTIAL
stretch selections survive — see *Defects the review of this fix found*, below).

**Not hollow** (WIRING.md §10): the fixture holds 2 wires + 1 instance + 1 text + 1 line, i.e. one
object of every type the previews are made of, so `instances == 1` after cancelling an *instance*
preview and `texts == 1` after cancelling the rect+text Add-Pin preview can only pass if the
survivors really survived. `rects`/`lines`/`polygons`/`arcs` have no `xschem get` counter, so the
line's survival is proved by counting saved object-record lines (`rec0241`).

**E7** was **replaced, not deleted** — same constructor, opposite assertions (the draw arms, the
preview is torn down, *and the other selected objects survive*), plus a same-type survivor instance
so the last check is not vacuous.

### Sabotage runs (`.o` removed and the clean baseline re-run after every restore, WIRING.md §10)

| sabotage | red set | size |
|---|---|---|
| narrowing removed from `abort_placement_preview()` only (`if(1)`) | `H1`×20 (5 verbs × wires/instance/text/records), `H2`×3, `H4 wires survive`/`instance kept`/`text survives`, `E7 other objects survive`/`survivor instance kept` | 28 |
| narrowing removed from the three re-arm drops only (`if(1)`) | `H3 wires survive`, `H3 fixture inst kept`, `H3 text survives`, `H3 records survive` | 4 |
| `stamp_placement_preview()` records nothing (backstop swallows every teardown) | the UNDER-delete direction: `H5 control: preview removed`, `H5 control: nothing else lost`, `H1 * preview gone`, `H3 old preview gone`/`ESC clears it`, `H4 preview gone`, and the pre-existing 0240/0243 effect checks `0240 ESC deletes preview instance`, `D1`/`D2`/`D5`, `E1`, `G1` | 32 |
| the removed decline guard put back | `H4 proceeded`, `H4 draw armed`, `H4 preview gone`, `E7 proceeds: preview torn down`/`wire draw armed`/`wire mode owned`, `E7 survivor instance kept` | 7 |
| the partial-selection filter removed from `stamp_placement_preview()` | `H7 partial: wires survive`, `H7 partial: ESC keeps them` | 2 |

Run 5's red set is disjoint from all the others (no run touches `H7`, and `H7` appears in no other
red set), which is the point: it guards the OPPOSITE error from runs 1/2 — over-deletion caused by
the narrowing itself.

Run 1 and run 2 are disjoint, and both are disjoint from run 4 — the H4 checks split cleanly
between "did the other objects survive" (run 1) and "did the verb proceed at all" (run 4). Run 3 is
the deliberate mirror: it proves every survival predicate has a partner that fails when the delete
stops happening, so none of them is satisfiable by a teardown that simply does nothing. Its overlap
with the 0240/0243 sections is the evidence that those older checks pin the delete too.

### Green tiers after the fix

`test_placement_wire_gate` 171 · `test_add_wire_label` 178 · `test_sch_add_pin` 21 ·
`test_label_ride` 157 · `test_label_strand_oracle` 32 · `test_wire_split` 119 ·
`test_add_pin_lib_symbol_view` 12 · `tests/pin_name_text.tcl` ALL PASS (regression 11/11b/11c) ·
`wireedit/run_wireedit.sh` 58/58 · `headless/run.sh` 6 goldens ·
`test_statusmsg_hold_0248` 7 · `test_create_instance`, `test_wire_stub_bindings`,
`test_drag_keeps_selection` (14), `test_verb_noun_copy_move`, `test_cmdmode_descend_0201` ALL PASS ·
`cd tests && tclsh run_regression.tcl` -> the 3 pre-existing FAIL lines only
(`test_ihp_sg13g2_libmgr` expects 9 libs, the tree has 10 — **reproduced identically on a HEAD
binary built in a worktree**, so not ours).

Nine headless suites (`test_sch_add_pin`, `test_label_ride`, `test_label_strand_oracle`,
`test_wire_split`, `test_add_pin_lib_symbol_view`, `test_crossview_paste`, `test_pin_type_edit`,
`test_instance_update`, `test_find_helper`) were run against that same pre-change binary and diffed
line by line: **byte-identical output**. The five DISPLAY-gated selection-semantics suites the issue
named were run on both binaries too and report the identical result and counts. That identical
baseline is the evidence that nothing else moved.
