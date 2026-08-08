# 0242 — arming anything on top of a live placement preview orphans it: `sympin_preview` outlives `START_SYMPIN` and the canvas goes dead (closes issue 0123's open residual)

Status: **OPEN** — measured headless repro (4 keystrokes), 17 doors enumerated, fix sketched, not
implemented. **Critical**: 6 doors leave the terminal issue-0123 desync; all 9 defective doors
commit a net label the user never dropped, and the merge/paste doors then report the document
**clean**.
Area: `src/select.c:1066-1068` (`unselect_all()` zeroes `ui_state` wholesale) vs the placement
teardown that only exists inside `src/callback.c:383-400`
Tests: none yet. `xschem get sympin_preview` (`scheduler.c:4513`, added by 0240) makes the invariant
directly assertable; the fluid tripwire on stderr is a usable second oracle
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
