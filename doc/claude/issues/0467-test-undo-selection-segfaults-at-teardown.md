# 0467 — `test_undo_selection` segfaults (signal 11) at teardown, after every one of its checks has passed

Status: **OPEN, measured, NOT fixed, NOT caused by S9b.**
Filed by the S9b crew (op-annotation, branch `annotate`); confirmed unchanged
after S9b landed.

Measured on the unpatched tree (`src/xschem` md5 `bd5381a3e9fd4c2835d23709bac0b7b8`,
no S9 code compiled in): `tests/headless/test_undo_selection.tcl` prints 20 `ok:`
lines and 0 `FAIL`, then dies with `FATAL: signal 11`, rc=1. Deterministic, 2/2
runs identical. It writes an emergency save to `/tmp` (not into the repo).

Why it is invisible: it crashes AFTER printing its `ok:` lines, and it is not in
the `tests/headless/run.sh` golden list, so neither T1 nor T2 counts it.

⚠ For the S9b Verify-A agent: this crash is expected to PERSIST. If it disappears
after S9b lands, that is itself a finding worth chasing, not a win.

## AFTER S9b (2026-08-20)

**BIT-IDENTICAL**: 20 `ok:`, 0 `FAIL`, then `FATAL: signal 11`, rc=1. The crash
neither appeared nor disappeared, which is the required outcome — S9b's four
invalidation hooks sit in `clear_drawing()`, `set_modify()`, `remove_symbols()`
and the raw mutators, all of which this suite exercises, so an unchanged
signature is evidence the hooks are inert on this path.

Still open. Nobody has diagnosed the teardown crash itself.
