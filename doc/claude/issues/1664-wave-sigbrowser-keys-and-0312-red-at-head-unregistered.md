# 1664 — test_wave_sigbrowser_keys and test_wave_sigbrowser_0312 are red at HEAD, and no gate runs them

**STAMP:** `v1 claim=open tree=c240d0a65 stamped=2026-10-16 fix=none open=2 by=driver`

Found while gating the `e`-key fix (`c240d0a65`). Neither suite is registered in
`tests/run_regression.tcl` (`hcases` or `dcases`), so T1 reports green while both are red —
the issue 1655 shape (a fence nothing gates rots silently).

## Measured (2026-10-16, tree `c240d0a65`, `tests/headless/run_suites.sh [--nogui] <suite>`, dev display `:99` with openbox)

| suite | `--nogui` arm | display arm |
|---|---|---|
| `test_wave_sigbrowser_keys` | `1 FAILED (24 passed)`: **BK22** | `3 FAILED (46 passed)`: **BK22**, **BK29**, **BK31** |
| `test_wave_sigbrowser_0312` | `ALL PASS (20 checks)` | `2 FAILED (67 passed)`: **BF21a**, **BF24a** |

Row names as printed:

- BK22 *(SOURCE, C) the registry row is Tcl-backed with a NULL fn, and the …*
- BK29 *(X) the LIVE binding table carries the ctrl+alt row, still has no …*
- BK31 *(X, REMAPPABILITY) bound -> unbind removes the row and the table …*
- BF21a *wide: the bar really got the width, is FLAT — every child packed, none gridded, and the …*
- BF24a *widened again: back to FLAT, with BAR03's pack order restored*

`c240d0a65` changes only `wviewer::empty_strips_to_delete` (the `e` key), which none of these
rows exercise; the reds are not attributed to it, but that was not bisected either.

## Not done

1. **Cause not diagnosed** for either suite. Unknown whether each row or the product is the
   suspect, and which commit turned each red. Bisect each row before editing it.
2. **Registration.** Once green, register each suite in the list(s) its arms need, checking its
   epilogue against `banner_complete` in `tests/banner_rule.tcl` first (issue 1615), and derive
   the trailer delta before the gate.
