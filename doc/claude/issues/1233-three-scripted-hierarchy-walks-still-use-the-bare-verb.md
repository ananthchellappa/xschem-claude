# 1233 — Three scripted hierarchy walks still use the bare verb

**Status:** OPEN — number claimed by item S7's red phase.

After item S7, seven controls a person can press ask for the base-schematic
fallback. Five call sites deliberately do not:

* `src/xschem.tcl` `hier_traversal` and `descend_hierarchy` — reachable by no
  menu item, toolbar button, keybinding or `actions.csv` row.
* `src/wave_viewer.tcl:11104` — the waveform cross-probe.
* `sky130A/sky130_procs.tcl:174` and `ihp-sg13g2/sg13g2_procs.tcl:399` — the
  hierarchical `.save` deck builders.

The last three mean a subtree behind a `schematic` setting that names a file which
is not there is silently skipped. Opting them in needs a measurement nobody has
taken: every netlister resolves with inst=-1, so the raw file's node names may
already come from the cell's own sheet — in which case falling back is exactly
right, and if not it is a plausible wrong answer, which ruling D5-1 forbids.

Row E6 in `tests/headless/test_descend_doors_1228.tcl` asserts the five stay bare
**by count**, so a later crew cannot quietly opt one in without meeting this issue.
