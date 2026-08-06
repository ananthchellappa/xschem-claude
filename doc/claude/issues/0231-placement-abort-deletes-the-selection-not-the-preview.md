# 0231 — a cancelled placement deletes **the selection**, not the preview: `Ctrl+A` while the Add-Label/Add-Pin form is armed wipes the whole schematic, and the dirty flag says it is clean

Status: **OPEN** — measured headless repro, fix sketched, not implemented. **Critical**: silent
whole-document loss on a two-gesture path that contains no `Delete` and, in the shortest route, no
`ESC` either.
Area: `src/callback.c` `abort_operation()`'s placement teardown (`:380-405`); `delete()` is
selection-scoped (`src/select.c:684,697`); the arm sites that establish the assumption
(`scheduler.c:1866-1874`, `:1748-1753`, `:8936-8940`, `callback.c:465-469`)
Tests: none yet — the RED-first set belongs in `tests/headless/test_add_wire_label.tcl` (82 today)
Found: 2026-08-06, by the adversarial review of issue **0230** (raised, then confirmed pre-existing
and out of that fix's scope)
Related: **0230** (parent; its "Pre-existing defects" list item 1), **0232** (the other half of the
same teardown's brokenness), **0234** (the merge arm's dirty-flag reset, which compounds this),
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

No `STARTWIRE` anywhere (`last_command=0`) — this is **not** issue 0230's wire clash.

**What survives: nothing.** With 8 objects selected, the saved `.sch` goes from
2×`N`, 2×`C`, `L`, `B`, `P`, `T` to the `v/G/K/V/S/F/E` header records alone. Wires, instances,
lines, boxes, polygons, arcs and texts all go.

**It is not a `Ctrl+A` bug, it is a "selection grew" bug** — `xschem select_dangling_nets` in place
of `select_all` wipes the document identically.

## Root cause

`src/callback.c:380-394`:

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
is plain over-deletion, not the 0123/0230 desync.

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
   save/restore idiom (that reset is issue **0234**; the two defects compound here).
5. **Optional belt, not a substitute:** make `select_all` decline (or first cancel the placement)
   while `ui_state & (START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT|STARTMERGE)`, gated at the command site
   (`scheduler.c:10682` / `callback.c:6089`) the way 0230 gated `add_wire_label`. It closes only the
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
- **0230's section-G checks pin the *effects*** — `test_add_wire_label.tcl:211/213/215`
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
instead of `select_all`. Sabotage: revert the narrowing → those checks and only those go red.
Note `rects`/`lines`/`polygons`/`arcs` have no `xschem get` counter, so quantify survival by
`xschem saveas` + diffing record lines.
