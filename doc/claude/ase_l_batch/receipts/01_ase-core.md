# Receipt — item 01 ase-core

Verdict: **DONE** ([x] in PLAN.md ledger).
Commit: `20cc4df93efd81ab1f` — `feat(ase): ASE-L core — state I/O, ngspice
backend, deck render, batch run`. NOT pushed (batch policy).

## What landed

New pure-Tcl `src/ase.tcl` (387 lines, namespace `ase::`), proc-definitions-only
at source time (safe under `--nogui`):

- **State I/O** — `ase::state_default` (spec v1 schema), `ase::state_load`
  (merge over defaults, unknown keys PRESERVED), `ase::state_save`
  (canonical stable key order, list-quoted values, one `key value` per line;
  load→save round-trip is byte-stable for untouched files).
- **Backend registry** — `ase::register_backend` / `ase::backend_hook`
  proc-name indirection; v1 `ngspice` entry registered inside
  `ase::backend::ngspice` with `render_deck`, `run_cmd`, `log_file`,
  `result_probe` hooks. Seam honest: the only ngspice literals outside the
  backend namespace are the state-schema defaults.
- **Deck render** — `ase::backend::ngspice::render_deck <state> <netlistText>`:
  strips trailing `.end`, emits `.lib` (file+section), `.param` variables,
  `.options`, `.save` (save==1 outputs), one `.control` block with enabled
  analyses in fixed op/dc/ac/tran order plus a `print` per saved output for
  result probing, then `.end`. Only `enabled 1` analyses emit.
- **Netlist + run** — `ase::rundir` (state rundir normalized+mkdir, else
  `set_netlist_dir 0` fallback); `ase::netlist` (resolves design via
  `cellview_path`, decision-2 guard: current-schematic in place / headless
  load / clean error rather than clobbering an open GUI window);
  `ase::run <state> ?callback?` writes `<cell>_ase.spice` and batch-runs via
  the `execute` infra with status 0 (no `$terminal`, `2>@1`); completion
  callback flushes `execute(data,$id)` to `<rundir>/<cell>_ase.log` and runs
  `result_probe` into `ase::last_result`; `ase::wait <id>` vwait wrapper.
- **Wiring/ship** — sourced from `src/xschem.tcl` after save_as_form.tcl
  (library_manager.tcl precedent); shipped via `install_shares` in
  `src/Makefile.in` (the generated `src/Makefile` was NOT committed).

## Test

`tests/headless/test_ase_core.tcl` — **33 named checks**, auto-discovered by
`tests/headless/full_audit.sh` and listed in its `nogui_tests` set (which
structurally enforces the no-Tk constraint). Covers: state round-trip incl.
unknown-key preservation and byte-stability; golden literal deck for the nfet
state; real ngspice end-to-end on an embedded clean-nfet scratch
lib/cell/view fixture (no commands/corner instances) with Id parsed
`4.096837e-04` within rel tol 1e-3; run-dir defaulting; fake-backend
missing-binary and unknown-simulator clean-error paths; ngspice leg
`auto_execok`-guarded SKIP when absent. Extra check E1d (beyond the prompted
list, declared deviation): asserts the `ase::run` user callback fires.

## Sabotage table

| # | Sabotage | Target check | Result |
|---|----------|--------------|--------|
| S1 | render_deck: `.param` block moved before `.lib` | D1 golden deck for the nfet state | failed EXACTLY D1 (32/33 others green) |
| S2 | result_probe: ` = ` regexp changed to ` == ` | E1c parsed Id within 1e-3 of 4.096837e-04 | failed EXACTLY E1c |
| S3 | state_save: unknown (non-canonical) keys dropped | R3 saved file contains `custom_key {hello world}` | failed EXACTLY R3 |

Each reverted via targeted `git checkout -- <file>`; clean re-run 33/33.

## Audit / fix rounds

- Full `full_audit.sh`: `test_ase_core` PASS; fail list equals the PLAN.md
  baseline. Bonus: baseline-fail entries test_altf5_ciw,
  test_cadence_window_hop_log, test_palette happened to PASS this session.
- Two transient non-baseline entries in the long run
  (test_clone_canvas_bindings FAIL, test_close_window_force TIMEOUT) were
  WSLg display flakes (geom=1x1 mapping symptom); both PASSED on two isolated
  re-runs — unrelated to this change (ase.tcl defines procs only at source
  time).
- Verifier lenses (hygiene/tests/spec) returned no problems; **no fixer
  rounds were needed**.

## Outstanding problems

None — verified clean (empty outstanding-problems list at ledger time).

## Corrected/confirmed anchors worth keeping

- `spice_netlist.c:591` — confirmed: `.end` emitted last for top `.spice`
  netlists (basis of the strip-then-append deck render).
- `xschem.tcl:352` — `execute` infra entry used for batch run (status 0, no
  `$terminal`); log accumulates in `execute(data,$id)`.
- ase.tcl source site: `src/xschem.tcl` immediately after the
  `save_as_form.tcl` source line; ship listing: `install_shares` in
  `src/Makefile.in` (edit the .in — `src/Makefile` is generated, tmpasm).
- Item-02/03 contract reminder: `ase::open_state` does not exist yet; item 02
  introduces it (v0 textwindow) and item 03 replaces its body — the ase-core
  procs above (`state_load/state_save/netlist/run/wait/last_result`,
  `register_backend/backend_hook`) are the stable API surface items 02–04
  build on.

## Commit hygiene

Staged exactly: `src/ase.tcl`, `src/xschem.tcl`, `src/Makefile.in`,
`tests/headless/test_ase_core.tcl`, `tests/headless/full_audit.sh`
(verified against `git show --stat 20cc4df9`). No pre-batch dirty tracked
files, no generated Makefile, no scratch leftovers. Not pushed.
