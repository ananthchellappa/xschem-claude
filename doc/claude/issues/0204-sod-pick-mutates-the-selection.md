# 0204 — the Ctrl-4 pick SELECTS what it clicks, so `e` afterwards descends into a net label

Status: **OPEN**. Filed 2026-08-01 from a user report, while confirming
[0201](0201-no-command-suspend-resume-contract.md) end to end.
**Established by reading — the failure itself is NOT yet measured.** Every claim below
carries a file:line; the first job of the fixing session is to reproduce it (see
"Reproduce this first").
Area: `src/ase_window.tcl` (`ase::ui::sod_click` 1801-1885, `ase::ui::sod_net_at`
1782-1793), `src/scheduler.c` (`select_at` 10158-10190, `selected_set` 10304-10314),
`src/xschem.tcl` (`hi_descend_dialog` 6012-6016, `hi_descend_target_inst` 5661-5676).
Tests: none yet. Guarding tests that any fix must keep green:
`tests/headless/test_ase_unnamed_net.tcl`, `test_ase_bus_bits_0159.tcl`,
`test_ase_locked_wire_pick_0160.tcl`, `test_ase_hier_pick_0161.tcl`, `test_ase_plot.tcl`.
Related: [0200](0200-descend-has-no-verb-noun-pick.md) (established the read-only
coordinate probe this needs, and the "a pick is not a selection" principle),
[0201](0201-no-command-suspend-resume-contract.md) (this defect partially defeats the user
story 0200+0201 just delivered), [0203](0203-stale-sel_array-descends-a-deselected-instance.md)
(the other half of "what does *selected* mean here"), 0154 / 0159 / 0160 (the `sod_click`
lineage whose contracts constrain the fix).
Specs: `doc/claude/specs/ase_l.md`, `doc/claude/specs/select_at.md`,
`doc/claude/specs/hi_descend.md`.

## Report

> My CTRL-4 to enter command mode to select-signals-to-plot lets me click on netlabels and
> wires, but allows those to get selected. So, when I then press e key to descend, it
> thinks there's already an instance selected.

Plus the design constraint, explicit:

> The command that CTRL-4 invokes should be orthogonal to waveform viewer code.

## The defect

`sod_click` classifies a mode click by calling the **mutating** coordinate pick:

```tcl
# src/ase_window.tcl:1823
set hit [xschem select_at $x $y]
```

and `select_at` is mutating by construction — it is the deliberate opposite of a probe
(`doc/claude/specs/select_at.md`):

```c
/* src/scheduler.c:10174-10179 */
if(!add) unselect_all(1);
select_at_suppress_log = 1;
s = select_object(x, y, SELECTED, 0, NULL);
select_at_suppress_log = 0;
rebuild_selected_array();
if(draw && has_x) draw_selection(xctx->gc[SELLAYER], 0);
```

So every Direct-Plot click leaves its target **selected**. Then `E`:

```tcl
# src/xschem.tcl:6012-6016
if {$instname eq {}} {
  if {[llength [xschem selected_set]] == 0} { return [hi_descend_pick_arm] }
  set instname [hi_descend_target_inst {}]      ;# -> [lindex $sel 0]
  if {$instname eq {}} { return 0 }
}
```

A non-empty `selected_set` means "noun-verb": the verb-noun pick is never armed, and the
descend targets whatever the plot click happened to leave behind.

### A prediction the fixing session must check first

`xschem selected_set` with no argument reports **ELEMENT only**:

```c
/* src/scheduler.c:10307 */
int what = ELEMENT;
```

If that is the whole story, the two halves of the report behave differently:

| clicked | selected by `select_at` | in `selected_set`? | `E` afterwards |
|---|---|---|---|
| **net label / pin / vsource** (these are *instances*) | yes | **yes** | takes noun-verb and descends into the label's symbol — the reported bug |
| **bare wire** | yes (as a `WIRE`) | no (filtered out) | *should* still arm the pick correctly |

The user reports both. So either the wire half misbehaves for a different reason, or the
visible leftover selection on a wire is being read as the same fault. **Measure before
fixing** — the answer changes whether this is one defect or two.

## Why the obvious fix is wrong

Three things depend on `select_at`'s side effect, each installed on purpose:

**1. The unnamed-net fallback reads the selection.** `sod_net_at` resolves a `#netN` wire
by asking what is selected:

```tcl
# src/ase_window.tcl:1787-1789
if {[lindex $hit 0] ne {wire}} { return {} }
catch {set rows [xschem nets -selected]}
if {[llength $rows] != 1} { return {} }
```

and its own comment says so: *"The fallback reads the selection `select_at` already made."*
Deleting the `select_at` call silently breaks issue 0154's auto-named-net picking. The
WIRE-only restriction is load-bearing too (comment 1770-1777): on a device body
`nets -selected` reports every net the device touches, so an `llength` test alone would
misclassify a non-source device click as a voltage pick.

**2. The selection is the click feedback**, and it logs. Comment at `ase_window.tcl:1800`:
*"select_at doubles as the Cadence-like click feedback and logs its own replayable
action-log line."* In `plot` flavour `dp_hilight` also paints the schematic (issue 0153),
so there may be redundant feedback there — but `outputs` flavour (`sod_queue`) has no such
paint, and that difference has to be checked rather than assumed.

**3. Issue 0160 deliberately did NOT override the lock here.** From the comment at
`ase_window.tcl:1812-1819`: *"Selection IS the lock, so making a locked wire selectable
would make it deletable. A read-only probe must resolve the net WITHOUT selecting the
object, which is precisely what falling through to sod_net_at does."* 0160 already
identified the right shape and applied it to one path only.

## The two ways out

### Option A — transient select (Tcl only, small, low risk)
Save the selection before `select_at`, restore it after classification. There is an exact
in-tree precedent, `net_hilight_mode_click` (`src/callback.c`), which is a persistent click
mode that must not disturb the selection either:

```c
unselect_all(0);
select_object(xctx->mousex, xctx->mousey, SELECTED, 0, &sel);
rebuild_selected_array();
...
unselect_all(0);                  /* transient: leave nothing selected */
```

Keeps `nets -selected` working untouched. Does **not** remove the entanglement: the
mutating call, its undo/action-log line and its `draw_selection` flicker all remain, and
the locked-wire asymmetry from 0160 stays.

### Option B — a read-only net probe (recommended; matches 0200 and the user's constraint)
Issue 0200 already established this exact move for instances: `find_closest_instance()` in
`src/findnet.c` plus `xschem instance_at <x> <y>` (`scheduler.c:5809`), the read-only twin
of `select_at`. Do the same for nets — a coordinate-addressed **`xschem net_at <x> <y>`**
(and, if classification needs it, an `xschem object_at <x> <y>` returning the same
`{type index}` shape `select_at` returns, without mutating) — and drop `select_at` from
`sod_click` entirely.

That satisfies the user's orthogonality constraint properly: the Ctrl-4 pick becomes a
read-only probe plus a queue, with no selection semantics and no waveform-viewer coupling
in the picking path at all. It also closes 0160's locked-wire asymmetry for free, because a
probe has no reason to respect a lock that exists to gate *edits*.

Recommendation: **B**, falling back to **A** if B does not fit one session. They are not
exclusive — A is a safe intermediate commit.

## Merge note

`src/ase_window.tcl` is owned by the `fluid-editing` branch, which is actively working on
the waveform viewer. Keep Tcl edits confined to the bodies of `sod_click` and `sod_net_at`;
put anything new in C (`findnet.c` / `scheduler.c`) or a new file. Do not touch
`src/wave_viewer.tcl` — the point of this issue is to *reduce* that coupling, not add to it.

## Reproduce this first

Not yet run. Under the GUI test gate (`tests/headless/run_suites.sh` or
`gated_xschem.sh`, never a bare loop), with a schematic that has a net label and a wire:

```tcl
ase::ui::select_on_design K {save 0 plot 1} plot 0
# real Tk events, so the seized <ButtonPress-1> is genuinely exercised:
event generate .drw <ButtonPress-1>   -x <px> -y <py>
event generate .drw <ButtonRelease-1> -x <px> -y <py>
puts "selected_set=[xschem selected_set] lastsel=[xschem get lastsel]"
event generate .drw <Key-e>
puts "pick armed = [expr {([xschem get ui_state]&65536)&&([xschem get ui_state2]&32768)}]"
```

`tests/headless/test_cmdmode_descend_0201.tcl` is the closest working template — it arms a
real SOD mode with `do_raise 0` (no ASE session window needed), stubs `dp_finish`, and
drives real `<Key-e>` / `<ButtonPress-1>` events. Copy its prologue.

## Cross-references

* `doc/claude/specs/select_at.md` — the mutating coordinate pick, and why it is mutating.
* `doc/claude/issues/0200-descend-has-no-verb-noun-pick.md` — `find_closest_instance` /
  `xschem instance_at`, the read-only twin Option B copies, and D1 "the pick must not touch
  the selection".
* `doc/claude/issues/0160-ase-locked-wire-unpickable.md` — "selection IS the lock", and the
  half-applied read-only-probe idea.
* `doc/claude/specs/ase_l.md` — Select-On-Design scope.
