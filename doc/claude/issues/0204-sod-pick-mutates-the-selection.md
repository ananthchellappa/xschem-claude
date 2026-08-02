# 0204 — the Ctrl-4 pick SELECTED what it clicked, so `e` afterwards descended into a net label

Status: **RESOLVED** 2026-08-01. Filed the same day from a user report, while confirming
[0201](0201-no-command-suspend-resume-contract.md) end to end.
Filed by reading only; **now measured** — see "What Step 1 actually showed", which both
confirmed the mechanism and corrected one half of the report.
Area: `src/ase_window.tcl` (`ase::ui::sod_click`, `ase::ui::sod_net_at`),
`src/scheduler.c` (new `object_at`, new `net_name_at`).
Tests: `tests/headless/test_sod_pick_no_select_0204.tcl` (new, DISPLAY-gated, legs `SO*`);
`test_ase_locked_wire_pick_0160.tcl` LK7b inverted (see "The one contract that flipped").
Related: [0200](0200-descend-has-no-verb-noun-pick.md) (established the read-only coordinate
probe this copied, and the "a pick is not a selection" principle),
[0201](0201-no-command-suspend-resume-contract.md) (this defect partially defeated the user
story 0200+0201 delivered),
[0203](0203-stale-sel_array-descends-a-deselected-instance.md) (still open; see "What is
left"), 0154 / 0159 / 0160 / 0161 (the `sod_click` lineage whose contracts constrained the
fix).
Specs: `doc/claude/specs/select_at.md` (now carries the read-only-twin table),
`doc/claude/specs/ase_l.md`, `doc/claude/specs/hi_descend.md`.

## Report

> My CTRL-4 to enter command mode to select-signals-to-plot lets me click on netlabels and
> wires, but allows those to get selected. So, when I then press e key to descend, it
> thinks there's already an instance selected.

Plus the design constraint, explicit:

> The command that CTRL-4 invokes should be orthogonal to waveform viewer code.

## The defect

`sod_click` classified a mode click with the **mutating** coordinate pick:

```tcl
set hit [xschem select_at $x $y]
```

`select_at` is mutating by construction — it is the deliberate opposite of a probe
(`doc/claude/specs/select_at.md`): `unselect_all`, `select_object`,
`rebuild_selected_array`, `draw_selection`. So every Direct-Plot click left its target
selected. Then `E`:

```tcl
# src/xschem.tcl:6068-6078, hi_descend_dialog — verbatim
proc hi_descend_dialog {{instname {}}} {
  if {$instname eq {}} {
    if {[llength [xschem selected_set]] == 0} { return [hi_descend_pick_arm] }
    set instname [hi_descend_target_inst {}]
    if {$instname eq {}} { cmdmode::resume_all; return 0 }
  }
  ...
```

A non-empty `selected_set` means "noun-verb": the verb-noun pick was never armed, and the
descend targeted whatever the plot click had left behind.

## What Step 1 actually showed

Measured, not reasoned: `tests/headless/test_sod_pick_no_select_0204.tcl` against the
pre-fix binary, driving both a direct `sod_click` and a real `<ButtonPress-1>` +
`<Key-e>` through the seized canvas. 12 of the 34 legs the test had at that point were red.
(The test has since grown to 66 legs; sabotage **S1** below re-runs the pre-fix behaviour
against the finished test and reddens 15, which is where the resistor row of the table
below is measured from — the original 34-leg baseline did not yet press `E` after an R1
click.) The issue's prediction table was **right in every cell**:

| clicked | `selected_set` | `lastsel` | `E` afterwards |
|---|---|---|---|
| net label `l1` (an instance) | `{l1}` | 1 | armed = 0, **descended into `l1`** — the reported bug |
| vsource `V1` (an instance) | `{V1}` | 1 | armed = 0, **descended into `V1`** — same bug |
| resistor `R1` (queues *nothing*) | `{R1}` | 1 | armed = 0, descended into `R1` |
| bare named wire | `{}` | 1 | armed = 1, resolved nothing — **correct** |
| unnamed `#netN` wire | `{}` | 1 | armed = 1, resolved nothing — **correct** |

So this was **one defect, not two.** `xschem selected_set` filters to `ELEMENT`
(`scheduler.c`), so a selected WIRE is invisible to `hi_descend`'s gate. The user reported
both halves because both halves leave a *visible* leftover selection (`lastsel` 1 in every
row) — but only the instance half misroutes `E`. The wire half was a cosmetic complaint
about the same root cause, not a second mechanism.

Two things the issue did not predict, and the measurement added:

- **A click that queues nothing still poisons the selection.** Clicking a plain resistor
  in Ctrl-4 mode queues nothing and prints the v1-scope notice — and still left `R1`
  selected, so `E` descended into it. The residue does not require a successful pick.
- The failure reproduces identically through **real Tk events** (leg group `SO11`), so it
  is not an artifact of driving `sod_click` as a proc.

## The fix: Option B, the read-only twins

Taken as recommended. `sod_click` no longer mutates anything.

**`xschem object_at <x> <y>`** (`src/scheduler.c`, `xschem_cmds_o`) — the read-only twin of
`select_at`. Same `find_closest_obj` cascade, same `override_lock=0`, returns the same bare
`type index col id` row, or `""` on a miss. Selects nothing, draws nothing, logs nothing.
`col` is *reconstructed* rather than read out of `sel_array` (which a probe has no business
rebuilding): `rebuild_selected_array` (move.c) stores `WIRELAYER` for wires and instances
and `TEXTLAYER` for texts, and the four per-layer types already carry their layer out of
`find_closest_obj` — so the row is field-for-field identical to an `xschem selection` row
with no selection ever existing.

**`xschem net_name_at <x> <y>` / `-wire <index>`** (`src/scheduler.c`, `xschem_cmds_n`) — the
read-only replacement for `select_at` + `xschem nets -selected`. Returns the raw `.node`
token of a **wire** (`#` intact, original case), or `""`. Both halves of the idiom it
replaces are preserved inside it: `prepare_netlist_structs(0)` first, so it is cold-correct;
and the WIRE-only gate, which is the correctness argument, not a convenience (on a device
*body* `nets -selected` reports every net the device touches, and a two-pin device shorted
onto one net reports exactly one, so a count test alone misclassified a non-source device
body as a voltage pick — `test_ase_unnamed_net` AN7b, `test_ase_interact` I6).

`sod_net_at` calls the **index** form, feeding it the index from the `object_at` row it
already has. That is not tidiness: the coordinate form would run a *second, independent*
`find_closest_obj`, and `find_closest_text` expands floater text through Tcl on every pass,
so a floater whose expansion changed between the two passes could win the cascade the second
time and silently turn a resolved wire into `""`. One hit test per click, no divergence
possible. (Indices are safe across the prep — `prepare_netlist_structs` names nodes and
never stores, splits or trims wires; `.node` *pointers* are not, which is why the prep runs
before the pick and the token is read after.)

Then two lines in Tcl, both inside the bodies the merge note allows:

```tcl
  set hit [xschem object_at $x $y]                          ;# sod_click,  was: select_at
  catch {set name [xschem net_name_at -wire [lindex $hit 1]]}  ;# sod_net_at, was:
                                                               ;#   xschem nets -selected
```

`src/wave_viewer.tcl` was not touched. The picking path now has no selection semantics and
no waveform-viewer coupling at all, which is the user's orthogonality constraint met
properly rather than worked around.

### `net_at` was already taken

The issue proposed `xschem net_at <x> <y>`. That name already exists
(`src/scheduler.c`, `xschem_cmds_n`): a boolean **on-copper predicate**
(`point_on_wire_or_pin`) behind the Add-Wire-Label drop constraint, with committed tests
(`test_add_wire_label`) and a spec. The dispatcher is a `strcmp` chain, so the existing
branch matches first and a second `net_at` would be dead code. Hence `net_name_at`.

### Why both probes keep `override_lock=0`

A probe respecting a lock is *wrong on principle* — 0160's argument ("selection IS the
lock") was about making a locked object **selectable**, hence deletable, and that argument
does not reach a verb that selects nothing. `override_lock=1` is the defensible end state.

It is deliberately not done here, because it is not a refactor: it silently changes what
two things classify as. Sabotage S3 measured exactly that — flipping `object_at` to
`override_lock=1` makes a **locked voltage source queue `i(v9)`** where it previously
queued nothing (`test_ase_locked_wire_pick_0160` LK11, whose own comment says "pinned
rather than reasoned"). A locked unnamed wire changes the same way. That is a user-visible
behaviour decision and belongs in its own issue, not in the exhaust of this one.

## The one contract that flipped

`test_ase_locked_wire_pick_0160.tcl` **LK7b** asserted, of an *unlocked* wire, "…and IS
still selected, as before" — i.e. it pinned `select_at`'s side effect as intended
behaviour. That was the asymmetry 0160's own header describes: a locked wire resolves
without being selected (LK6), an unlocked one gets selected. The measurement above shows
that asymmetry *was* the bug. LK7b is now inverted to require the unlocked half to behave
like the locked half — same rule, both halves — with the reason written into the test.

Every other locked-object leg in that file (LK2, LK4-LK6, LK10-LK12) means exactly what it
meant before, because the probes kept `override_lock=0`.

## Sabotage table

Each sabotage was applied to the fixed tree, rebuilt, and run under the GUI gate. A leg
that stays green under sabotage is not testing anything.

| # | sabotage | legs that went RED | verdict |
|---|---|---|---|
| **S1** | `sod_click`: `object_at` → `select_at` (re-introduce the mutation) | `SO1b SO2a SO2b SO3b SO5b SO7b SO8a SO8b SO9c SO9d SO9e SO9f SO11c SO11d SO11e` (15 of 66) + `LK7b` | the whole defect is caught, in every click class and through real Tk events; matches the pre-fix baseline exactly |
| **S2** | `net_name_at` forced to return `""` (kill the 0154 fallback) | `SO5a SO14a SO14b SO14g SO14g2` + `AN1 AN2 AN3 AN4` + `HP15` | the fallback has teeth at both levels — through `sod_click` (SO5a) and on the C verb directly, in **both** its forms (SO14) — and the two pre-existing suites that ride it still guard it |
| **S3** | `object_at`: `override_lock` 0 → 1 | `LK11` (a locked vsource starts queueing `i(v9)`) | the `override_lock=0` choice is pinned, not assumed. Note `test_sod_pick_no_select_0204` stays ALL PASS here: it has no locked object, so LK11 is the only leg in the tree defending that decision — which is why [0205](0205-read-only-probes-still-honour-the-lock.md) has to rewrite it rather than route around it |

Notes on what did **not** move:
- S2 was expected (from the investigation) to redden `HP13` alongside `HP15`; only `HP15`
  did. `HP13` resolves through a different path and is not a fallback rider.
- S1 leaves `SO5a` green, correctly: S1 restores the *old working* selection-based fallback,
  so the unnamed net still resolves — it is the selection residue, not the resolution, that
  S1 re-breaks. The two sabotages are testing different halves and neither subsumes the other.

## Verification

New: `tests/headless/test_sod_pick_no_select_0204.tcl` — 66 checks, ALL PASS. DISPLAY-gated
(real `<Key-e>`), leg prefix `SO` (unused elsewhere in `tests/headless`). It builds its own
scratch fixture (named wire + `lab_pin`, unlabeled `#netN` wire, vsource, resistor), asserts
for every click class that `selected_set` is empty **and** `lastsel` is 0 **and** the trace
is still queued and still correctly named, then presses `E` with nothing in between and
requires the pick to arm. `SO12` guards the other direction: a selection the user made
*before* arming the mode still routes `E` noun-verb — the fix removes the pick's own
mutation, it does not make `E` blind to the user.

`SO13`/`SO14` pin the two new C commands **directly**, not through `sod_click`, so the
spec's "byte-identical to a `select_at` row" is a tested claim rather than a comment: for
each of six click points (label, named wire, unnamed wire, vsource, resistor, empty canvas)
`object_at` selects nothing, leaves `lastsel` 0, and returns a row **string-equal** to what
`select_at` returns at the same coordinate; and `net_name_at` returns the raw token on a
wire (`#` and case intact) and `""` on every instance body and on empty canvas.

Green, post-fix, under the gate — one 11-suite batch, 11/11:

```
test_sod_pick_no_select_0204   ALL PASS (66)      test_ase_interact           ALL PASS (63)
test_ase_unnamed_net           ALL PASS (28)      test_ase_hier_plot_0168     ALL PASS (31)
test_ase_bus_bits_0159         ALL PASS (39)      test_cmdmode_0201           ALL PASS (37)
test_ase_locked_wire_pick_0160 ALL PASS (16)      test_cmdmode_descend_0201   ALL PASS
test_ase_hier_pick_0161        ALL PASS (21)      test_verb_noun_descend_0200 ALL PASS
test_add_wire_label            ALL PASS (59)
test_select_at (--logdir)      ALL PASS           test_hi_descend             all checks passed
```

Three results that are NOT this change, each run to ground rather than waved off:

- **`test_ase_plot` P4/P6 fail — and fail identically without the fix.** Six legs
  (`P4 the wire click highlighted net D`, `P4 new graph traces are exactly v(d) + i(v1)`,
  `P6 …`) go red because the direct `sod_click $key 550 -330` in P4 queues nothing.
  Measured 0/4 with the fix, then the fix was **stashed, the tree rebuilt, and the baseline
  measured 0/2 with the same six leg names**. Pre-existing and environment-dependent (the
  same coordinate through `test_ase_interact` I3 queues `v(d)` correctly, and that suite is
  green). Filed as [0206](0206-ase-plot-p4-direct-plot-click-queues-nothing.md).
- `test_select_at` needs `--logdir`; under plain `--nolog` it reports 5 false failures
  ("action log open"). With `--logdir`: ALL PASS, i.e. `select_at` itself is untouched.
- `test_hi_descend` prints its own banner instead of `RESULT:`, so `run_suites.sh` scores it
  `NORESULT`. Run directly: all checks passed.
- `test_ase_interact` I2 (the real-gesture leg) failed once inside a 6-suite batch, then
  passed 3/3 standalone and in both later batches: flaky under window contention.

## What is deliberately left undone

1. **The Ctrl-4 pick no longer writes an action-log line.** `select_at` stashed a replayable
   `xschem select_at x y`. It logged a *selection that no longer happens*, so keeping it
   would have been a lie — and it never made the pick replayable anyway (replaying it
   re-selects an object; it does not re-enter Direct Plot, classify, or queue anything). ASE
   has no logging seam of its own, unlike the viewer's `wviewer::log_action`. An honest
   SOD-pick log line is separate work. Nothing tests this today.
2. **`outputs` flavour lost its only on-canvas click acknowledgement.** In `plot` flavour
   `dp_hilight` still paints the picked object in its future trace colour (0153), but
   `sod_queue` paints nothing — the selection highlight *was* the confirmation there. Its
   feedback is now the CIW echo and the Outputs pane (which usually sits behind the design
   window). Adding an outputs-flavour cue means touching `sod_queue`, i.e. outside the
   bodies this issue was allowed to edit.
3. **`override_lock=1` for the probes** — see above; changes LK11's behaviour, so it needs
   its own decision. Filed as
   [0205](0205-read-only-probes-still-honour-the-lock.md), with the S3 measurement.
4. **Entering Ctrl-4 no longer clears a pre-existing selection.** `select_at`'s
   `unselect_all` used to wipe it on the first click. Now a selection made before arming
   survives, and `SO12` pins that `E` still honours it (correct noun-verb). Whether *arming*
   the mode should clear the selection is a mode-entry question, and `select_on_design` is
   outside the edit region.
5. **0203 is still open**, and it is the other half of "what does *selected* mean here":
   `descend_schematic()` reads `sel_array[0]` with its `lastsel` guard commented out. Not
   reachable from `E` (which is `selected_set`-driven), but reachable from the toolbar Push
   button, Ctrl/Alt/Super-e, and any replayed action log. This fix removes the Ctrl-4 click
   as a *source* of that stale slot, but does not fix the reader.

Two hazards found during investigation, both pre-existing and inherited unchanged by
`object_at` (it uses the same `find_closest_obj` as `select_at`), recorded so they are not
rediscovered as regressions: `find_closest_obj`'s polygon leg tests bezier control points
against the **live mouse** rather than the passed coordinate, so a scripted probe can be
hijacked by a bezier polygon under the real pointer; and the wire pick radius is
zoom-dependent, so a coordinate probe's hit/miss is a function of the current view.

## Cross-references

* `doc/claude/specs/select_at.md` — the mutating pick, and the read-only-twin table.
* `doc/claude/issues/0200-descend-has-no-verb-noun-pick.md` — `find_closest_instance` /
  `xschem instance_at`, the twin this copied, and D1 "the pick must not touch the selection".
* `doc/claude/issues/0160-ase-locked-wire-unpickable.md` — "selection IS the lock", and the
  half-applied read-only-probe idea this finishes.
* `doc/claude/specs/ase_l.md` — Select-On-Design scope.
