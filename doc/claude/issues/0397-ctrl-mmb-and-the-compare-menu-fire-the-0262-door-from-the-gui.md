# 0397 — the 0262 door IS GUI-reachable: Ctrl+Button2 and the Compare-schematics menu item both fire the bare `unselect_all` verb while a placement preview is live

Status: **OPEN — measured, not fixed.** Filed by the item-D8 scout of the 2026-08-11 unattended
backlog run, 2026-08-11, at `2f866dec`. Number claimed as a stub before the work; this file is the
full measurement, **no fix proposed**.
**Major/terminal**: the end state is the issue-0123/0262 dead canvas — click-select and
`wire_label_try_commit()` both refuse for the rest of the session, and ESC cannot repair it — plus a
committed, netlist-visible `lab_pin` that silently renames the net it sits on.
Area: `src/xschem.tcl:11130-11135` (`addpin::cycle_type`'s fallback branch),
`src/xschem.tcl:15166-15170` (the Hilight ▸ *Compare schematics* checkbutton body) vs
`src/scheduler.c:13311-13317` (the `unselect_all` verb) and `src/select.c:1256-1259`.
Related: **0262** (the door itself — this issue falsifies its "not reachable from the GUI" premise
and therefore its option 3), **0242** (the door census), **0358** (`save`, the other class-D door),
**0123**, **0241**, `WIRING.md` §8 class **D**.

## What issue 0262 claims, and what is actually true

0262 says, in *Why 0242 did not fix it*:

> It is not reachable from the GUI: no key, menu item or toolbar button issues the bare verb while
> a preview is live.

**Measured false, on two independent routes.** (`doc/claude/FAQ.md:191` already says so in passing —
"reachable after a property edit or from Compare Schematics" — but 0262 itself was never corrected
and still carries the premise its option 3 depends on. Neither route had been measured.)

### Route 1 — Ctrl+Button2, the default `edit.cycle_pin_type` chord

`src/callback.c:5598` registers the action `edit.cycle_pin_type` → Tcl proc `addpin::cycle_type`,
"Default chord Ctrl+Button2 (seeded in init_input_bindings, mirrored in mousebindings.csv)".

`addpin::cycle_type` (`src/xschem.tcl:11118-11136`) re-arms the preview **only** when the *Add-Pin*
form is the owner:

```tcl
if {[info commands winfo] ne {} && [winfo exists .addpin] && [addpin::placing]} { … return }
# placed-pin fallback …
if {[catch {xschem set_pin_type -cycle} n] || $n == 0} {
  catch {
    xschem unselect_all                      ;# <-- the 0262 door
    xschem select_at [xschem get mousex_snap] [xschem get mousey_snap]
    xschem set_pin_type -cycle
  }
}
```

The guard tests `.addpin`. A live **Add-Wire-Label** preview belongs to `.addlabel`, so `.addpin`
does not exist, the guard is false, and the fallback runs the bare verb on a live preview.

Measured under a real X display (`GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog --script …`,
so the `winfo` terms are all live):

```
addlabel::open ->    .addlabel exists=1  .addpin exists=0
armed         : ui=16424 sp=1 bit=1 orphans=1
after Ctrl+MMB: ui=8     sp=1 bit=0 orphans=1     <-- terminal desync
after esc3    : ui=0     sp=1 bit=0 orphans=1     <-- ESC cannot repair
```

with the C tripwire firing exactly once in between:

```
placement_preview: sympin_preview=1 outlived START_SYMPIN at xschem() entry
(ui_state=0 wirelabel_preview=1 instances=1) -- issue 0242: …
```

Headless (`--nogui`) reproduces the identical numbers by the identical branch, because
`info commands winfo` is empty there too.

### Route 2 — the *Compare schematics* menu checkbutton

`src/xschem.tcl:15166-15170`, the Hilight menu:

```tcl
$topwin.menubar.hilight add checkbutton … -label {Compare schematics} \
 -command { xschem unselect_all
            xschem redraw } -variable compare_sch
```

A **menu item** whose whole body is the bare verb. Measured (headless, same fixture):

```
armed2       : ui=16424 sp=1 bit=1 orphans=1
after Compare: ui=0     sp=1 bit=0 orphans=1
```

### Other bare-verb sites reachable without typing a script

Not individually measured here, listed so a fixer does not re-derive them:
`traversal` (`xschem.tcl:3574`), `descend_hierarchy` (`:3863`), `schematic_in_new_window`
(`:5748`), `hi_descend_current` (`:6026`), the hi-descend new-window arm (`:6051`),
`slickprop::restore_selection` (`src/property_form.tcl:834` — the Property-form *Cancel* path,
which is 0262's own "worst case: a helper proc that deselects mid-form"), plus
`utils/{cadence_nav,toggle_pins_netlabels,apply_hilight,select_same_cell,find_helper}.tcl`,
`sky130A/sky130_procs.tcl:101` and `ihp-sg13g2/sg13g2_procs.tcl:353`.

## Mechanism (unchanged from 0262 — this issue only supplies the missing reachability)

`unselect_all()` (`src/select.c:1256-1259`) zeroes `xctx->ui_state` wholesale whenever anything is
selected, and a live placement preview is always selected. `START_SYMPIN|STARTMOVE` go without
`abort_placement_preview()` (`src/callback.c:702`) ever running; `sympin_preview` /
`wirelabel_preview` are plain `Xschem_ctx` fields, not `ui_state` bits, so they survive, and the
preview instance was never `delete()`d. With `sympin_preview` stuck at 1 the Button-1
select/grab block (`src/callback.c:8656-8657`, guarded `!xctx->sympin_preview`) refuses every
press and `wire_label_try_commit()` (`src/callback.c:3429`, guarded on `START_SYMPIN`) refuses
every drop; `abort_placement_preview()` is gated on the bit that is gone, so ESC cannot repair it.

## Why this is filed separately from 0262 rather than as an edit to it

0262 is an open **decision** (item D8 of this run), and its option 3 ("do nothing, keep the report")
is explicitly conditioned on the verb being "genuinely unreachable while armed in practice". That
condition is now measured false, so the decision needs this as an independent, dated measurement it
can cite rather than as a silently rewritten premise. The *fallback branch itself* is also arguably
a defect in its own right, independent of whatever 0262 decides: it click-selects under the pointer
while a placement preview is live, which is exactly what `callback.c:8656-8657` refuses to do on a
real Button-1 press.

## Repro

`/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_D8/gui_reach_x.tcl` (scratch, not
committed). Reproduce with:

```tcl
xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
addlabel::open
set ::label_new_name FOO
xschem add_wire_label -place        ;# ui=16424 sp=1
addpin::cycle_type                  ;# the default Ctrl+Button2 action
xschem abort_operation ; xschem abort_operation ; xschem abort_operation
;# sympin_preview is still 1, START_SYMPIN is 0, one orphan lab_pin renames the net
```

## Update 2026-08-11 — how 0262 was decided, and what is left of this issue

**Both routes are now NON-TERMINAL, and both are asserted.** Issue **0262** was decided the same day
(item D8 of this run) and this measurement is what decided it: with the "not reachable from the GUI"
premise measured false, 0262's option 3 (stay report-only) fell, and the ratified answer is a
**repairing** `check_placement_preview_invariant()` — `repair_orphan_placement_preview()`
(`src/callback.c`) clears `sympin_preview`, `wirelabel_preview` and the `preview_sel` stamp at the
next `xschem()` / `callback()` entry, posts one held status line, and **deletes nothing**.

Measured after the fix, both routes:

* **Route 1** (`addpin::cycle_type`, the Ctrl+Button2 body) — doors rows **F9**: `sp=0`,
  `desync=0`, `orphans=1`. Also re-measured under a real display
  (`GUI_GATE=0 xvfb-run -a`): `ARM ui=16424 sp=1` → door → repair → `ui=8 sp=0 psel=0 inst=1`, then
  re-arm and `xschem add_wire_label -drop 50 0` **returns 1**. The canvas takes clicks again.
* **Route 2** (the Compare-schematics `-command` body) — doors row **F10**: `sp=0`, `desync=0`.

`tests/headless/test_placement_preview_doors.tcl` section F now pins both (177 → 206 checks).

### What is still open here — the routes themselves were not touched

1. **The orphan and the net rename remain.** That is 0262 decision **D3**, deliberate: the repair
   deletes nothing. On a clean saved buffer the mutation is additionally invisible to the modify
   flag — issue **0398**.
2. **`addpin::cycle_type`'s fallback branch is still arguably a defect in its own right**, exactly
   as this issue's *Why this is filed separately* section says: it runs `xschem unselect_all` and
   then **click-selects under the pointer while a placement preview is live**, which is precisely
   what `callback.c`'s Button-1 select/grab block refuses to do on a real press. The guard tests
   `[winfo exists .addpin]`; the honest guard is "is any placement preview live", i.e.
   `xschem get sympin_preview` — which, note, now self-repairs when read (issue **0399** part 1), so
   a fix must ask before the door opens, not after.
3. **The Compare-schematics menu body** is a bare housekeeping deselect in a menu item; it was never
   reviewed against the gesture rules and is untouched.
4. **The other bare-verb sites listed above** (`traversal`, `descend_hierarchy`,
   `schematic_in_new_window`, `hi_descend_current`, `slickprop::restore_selection`, the `utils/` and
   PDK procs) were never individually measured. After 0262 none of them can be *terminal*, so the
   priority is lower — but each is still a way to abandon a placement without saying so.
