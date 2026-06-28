# Dispatcher decomposition — batch 3: scheduler letters h–z (FINAL)

**Status:** IMPLEMENTED + VERIFIED. **Branch:** `refactor/dispatcher-decomposition`.
**Method/recipe:** identical to batches 1–2
(`plan_dispatcher_decomp_batch1.md`, `..batch2.md`).

## Scope — completes the decomposition

All remaining inline letters extracted verbatim from `xschem()` into
`static int xschem_cmds_{h,i,l,m,n,o,p,r,s,t,u,v,w,x,z}(...)`:

| letter | lines | notable commands |
|---|---|---|
| h | 142 | hilight family |
| i | 432 | instance ops, `instances`/`instance_*` getters |
| l | 474 | `load`, `line`, `logo`, library ops |
| m | 137 | `merge`, `move*` |
| n | 191 | `netlist`, `net_*`, `new_schematic` |
| o | 29  | `only_probes` etc. |
| p | 474 | `place_*`, `polygon`, `print*`, `push_undo` |
| r | 813 | `redraw`, `rect`, `reload`, `replace`, `rotate`, … |
| s | 1180| `save`, `select*`, `set*`, `simulate`, `search`, … (largest) |
| t | 304 | `translate`, `text`, `toolbar*`, `tcl*` |
| u | 124 | `undo`, `unhilight`, `unselect` |
| v | 10  | `view*` |
| w | 119 | `wire`, `windowid`, `what` |
| x | 9   | `xschem`-misc |
| z | 90  | `zoom*` |

~4,500 lines move; `xschem()` shrinks to a **99-line** pure dispatcher (22
`case 'X': retcode = xschem_cmds_X(...); break;` + epilogue). 22 helpers total.

## Locals (compiler-adjudicated)

Only `xschem_cmds_s` needed a function-scope `int i;` (its `save [fast]` arg
loop). Every other letter uses inner-block declarations exclusively — no
function-scope `i`/`name` required. `s` also carried one interior nested
`cmd_found` (a `default:` in a sub-switch) → rewritten to `*cmd_found` by the
mechanical pass.

**Dead-local cleanup:** with every letter extracted, the function-scope
`int i;` and `char name[1024];` at the top of `xschem()` became unused (the
debug block has its own inner `int i`). Both removed — the dispatcher no longer
needs scratch locals. This is the only non-mechanical edit and is a no-op
(provably dead; build clean with no unused-variable warning before or after).

## Verification

- **Verbatim proof**: reconstruction-diff of each letter's body from
  `HEAD:src/scheduler.c` (cut on `case 'X': /*--*/` markers, drop the
  switch-level `break;`, apply `cmd_found`→`*cmd_found`) vs the new function
  bodies modulo the one added `int i;`. All 15 letters byte-identical.
- Build clean (no errors, no new warnings). Engine harness 6/6. All 13 smokes PASS.
- `tests/run_regression.tcl` was attempted but fails before running anything
  with `Tcl_AppInit() err 4: cannot find /usr/local/share/xschem/xschem.tcl` —
  that harness invokes `xschem` from PATH, which resolves XSCHEM_SHAREDIR to the
  (absent) *installed* location; it needs `make install` or XSCHEM_SHAREDIR set.
  Pre-existing environment limitation, identical at any commit, unrelated to the
  refactor. The canonical `tests/headless/run.sh` harness (correct env, golden
  netlist comparison for create_save + 5 designs) is the netlisting signal and PASSES.

## Result

The dispatcher decomposition is COMPLETE: `xschem()` is a 99-line switch over 22
per-letter `xschem_cmds_*` functions, each a self-contained, greppable unit.
No behavior change across all three batches.
