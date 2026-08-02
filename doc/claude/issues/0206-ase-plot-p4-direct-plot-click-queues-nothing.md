# 0206 — `test_ase_plot` P4: the Direct-Plot wire click queues nothing (pre-existing)

Status: **OPEN**, not yet diagnosed. Filed 2026-08-01 while verifying
[0204](0204-sod-pick-mutates-the-selection.md); **not caused by it** — see "Proven
pre-existing".
Area: `tests/headless/test_ase_plot.tcl` P4/P6, and whatever they depend on in
`src/ase_window.tcl` (`ase::ui::sod_click` under the real Results ▸ Direct Plot entry) /
`src/wave_viewer.tcl`.
Tests: `tests/headless/test_ase_plot.tcl` (DISPLAY-gated, `::has_x`).

## Symptom

Six legs, deterministic, 4/4 runs:

```
FAIL: P4 the wire click highlighted net D -> {0} (exp {1})
FAIL: P4 ... in a plain LAYER color (negative hilight value) -> {0} (exp {1})
FAIL: P4 new graph traces are exactly v(d) + i(v1) -> {i(v1)} (exp {i(v1) v(d)})
FAIL: P4 v(d) trace color == the color painted on the wire
        -> {no wire highlight to compare against (p4hl={})}
FAIL: P4 the two picked traces have different colors -> {1} (exp {2})
FAIL: P6 Direct-Plot graph untouched (v(d) + i(v1)) -> {i(v1)} (exp {i(v1) v(d)})
```

All six are one fact: in P4, after arming the mode through the real menu entry
(`$top.mb.results invoke {Direct Plot}`), the **first** pick

```tcl
ase::ui::sod_click $key 550 -330                 ;# wire -> v(d)
```

queues nothing and paints nothing. The **second** pick in the same block
(`sod_click $key 600 -300`, the vsource) works — `i(v1)` is queued — so the mode is armed
and functional; it is specifically the wire/net leg of the first click that resolves to
nothing.

## Proven pre-existing

Measured on 2026-08-01 under the GUI gate, in this order:

1. With the 0204 fix applied: `run_suites.sh -n 4 test_ase_plot` → **0/4**, the same six
   legs each time.
2. `git stash push src/scheduler.c src/ase_window.tcl`, `make`, i.e. the tree exactly as of
   commit `1f9bae46` — `run_suites.sh -n 2 test_ase_plot` → **0/2**, the same six leg names,
   same values.

So the fix neither causes nor masks it. (An early post-fix batch did report
`test_ase_plot ALL PASS (150 checks)`; the failure appeared in later batches and then
reproduced on the untouched baseline, which is what makes it environment- or
state-dependent rather than flaky-random — it does not flip run to run within a session.)

## What it is not

- **Not the coordinate.** `tests/headless/test_ase_interact.tcl` I3 clicks the *same* net
  at the *same* point — `ase::ui::sod_click $key 550 -330` — asserts `v(d)` is queued, and
  that suite is green (63/63).
- **Not the read-only probes.** They are not in the baseline build that also fails.
- **Not the pick mode being unarmed.** P4's own `mode armed (ButtonPress-1 seized)` leg
  passes, and the second pick in the same block queues `i(v1)`.

## Where to look

The difference between the green I3 path and the red P4 path is **how the mode was armed**,
and therefore possibly the context the click runs in. P4 arms it through the real
`Results ▸ Direct Plot` menu entry; I3 arms it through `To Be Saved ▸ Select On Design`.

One tempting hypothesis has already been **ruled out**: that Direct Plot leaves the
*waveform viewer's* `Xschem_ctx` current, so the pick queries the wrong schematic.
`$top.mb.results invoke {Direct Plot}` → `ase::ui::direct_plot` (`ase_window.tcl:2036`) →
`select_on_design … plot 1` → `ase::ui::design_window` → `raise_design_editor` →
`raise_window_entry` (`ase_window.tcl:3307`), whose **first** statement is
`xschem new_schematic switch [lindex $e 0]` — it switches *to* the design. The test's own
later `xschem new_schematic switch $cv` is belt-and-braces, not evidence that the context
was wrong.

So the hypothesis has to be re-derived, and the cheap discriminating measurement is
unchanged: log `xschem get current_win_path`, `xschem get schname` and
`xschem object_at 550 -330` immediately before each `sod_click` in P4, and compare against
the same three in I3. That separates "wrong context" from "right context, wrong hit" from
"right hit, resolver fails".

Also worth ruling in/out: leftover on-disk ASE session or design-registry state from earlier
runs (the P4 path depends on a live session, and the failure appeared partway through a long
series of runs and then stuck rather than alternating), and whether the design landed in a
*different window* than `.drw` on the runs that fail — `raise_design_editor` opens one if the
design is not already up, and the test hard-codes `set cv .drw`.

## Cross-references

* `doc/claude/issues/0204-sod-pick-mutates-the-selection.md` — the verification run this was
  found in, and the baseline measurement.
* `doc/claude/issues/0201-no-command-suspend-resume-contract.md` — D2, "resume on the canvas
  that is current NOW", the nearest existing statement about which context a mode belongs to.
* `doc/claude/specs/ase_l.md` — Select-On-Design scope.
