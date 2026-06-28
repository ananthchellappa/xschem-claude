# Dispatcher decomposition — batch 2: scheduler letters d–g

**Status:** IMPLEMENTED + VERIFIED. **Branch:** `refactor/dispatcher-decomposition`.
**Method/recipe:** identical to batch 1 (`plan_dispatcher_decomp_batch1.md`).

## Scope

Letters **d** (debug…drc_check, 150 lines), **e** (edit…exit, 210), **f**
(fullscreen et al., 176), **g** (the big `get`/`getprop`/`get_additional_symbols`
group, 941) extracted verbatim from `xschem()` into
`static int xschem_cmds_{d,e,f,g}(Tcl_Interp*, int argc, const char *argv[], int *cmd_found)`.
1,477 lines move; each dispatcher case becomes the two-line
`retcode = xschem_cmds_X(...); break;`. The `retcode` epilogue and `not_avail`
file-static were already in place from batch 1.

## Locals (compiler-adjudicated)

- `e` declares `int i;` and `char name[1024];` (uses both).
- `g` declares `int i;` (used by the `get` enumerations).
- `d`, `f` declare none.

Interior `cmd_found` references (g's nested `default: cmd_found = 0;`) were
rewritten to `*cmd_found` along with the chain-terminal `else { *cmd_found = 0;}`.

## Verification

- **Verbatim proof**: a diff script reconstructs each letter's body from
  `HEAD:src/scheduler.c` (cut on the `case 'X': /*--*/` markers, drop the
  switch-level `break;`, apply `cmd_found`→`*cmd_found`) and compares to the new
  function body modulo the added local decls. d/e/f/g all VERBATIM (150/210/176/941).
- Build clean (no warnings). Engine harness 6/6. All 13 smokes PASS.
- **test_key_graph_context robustness fix (separate from the move)**: the test
  drives Shift+A, which toggles `netlist_show` via `view.toggle_show_netlist`,
  whose C impl calls the modal `alert_` (`tkwait window` — blocks with no user;
  auto-raise is focus-nondeterministic under WSLg, issue 0001). The test asserts
  only the toggled var, so `alert_` is now stubbed non-blocking at the top, the
  same pattern the test already uses for every other side-effectful proc. Proven
  not-a-regression: the hang reproduces identically at stashed clean HEAD and the
  full test passes once the modal is neutralized.

## Remaining

Letters h, i, l, m, n, o, p, r, s, t, u, v, w, x, z still inline in `xschem()`.
`s` (~1,180 lines) and the dialog-heavy groups are the next-largest targets.
