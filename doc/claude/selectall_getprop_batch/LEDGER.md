# LEDGER — selectall_getprop_batch

One row per collected receipt. The driver writes this, not the crews.

Opened 2026-09-29 at `b89fddda`. T1 baseline `cases=107 blocks=106 counted_failures=0 skips=8`.

| stage | crew receipt | verified by driver | commit | T1 gate |
|---|---|---|---|---|
| R recon | `R-recon-A.md` + `R-recon-B.md` **collected** | driver re-ran crew B's central claim, all 4 outputs matched; crew A's refutation accepted on its measured `graph_flags`/`lastsel` evidence | `4f998799` (scaffolding) | n/a, no code |
| A Ctrl-A select all traces (1617) | impl **dispatched** | — | — | — |
| B getprop arms (1618) | `R-recon-B.md` **collected**; impl dispatched | driver re-ran the central claim; all four outputs matched | — | — |

## Collected notes

**Stage R dispatched as TWO crews**, one coherent task each, both read-only so they run
concurrently without conflict: crew A owns PLAN questions 1-6 (Ctrl-A), crew B owns 7-12
(`getprop`). Splitting it this way keeps the "one task per crew" rule while not serialising
two independent read-only surveys. Both were told explicitly which questions are NOT theirs.

### Stage R, collected 2026-09-29 — both crews refuted the driver

**Crew B (getprop).** Right about which arms exist, wrong about their behaviour, and there was
a larger correction underneath: the missing arms return `TCL_OK` with an EMPTY result, not an
error, because the `else if` chain in `xschem_cmds_g()` has no terminating `else`. Driver
re-ran it: `line`, `poly`, `arc` AND `zzz` all give `rc=0 result=||`. A red row shaped "errors
today, succeeds tomorrow" would have looked green on the broken tree. And `setprop` ALREADY has
line/arc/poly arms, so item 21 is an **asymmetry, not a hole** — Tcl can write a property onto a
line and cannot read it back. That round trip became the fence (D3, D4). Also corrected: seven
arms not nine, `text` is not token-only, `allprops` is setprop-only. Good news for once: the
fence home `test_getprop_index_bounds.tcl` is already in `hcases` and already prints
`OVERALL: ok`, so no case count moves.

**Crew A (Ctrl-A).** Refuted the driver's claim outright by measurement: Ctrl-A over a graph
does NOT reach `select_all()` — it **toggles cursor A**. So item 13 takes an OCCUPIED chord
rather than filling a gap (D7, D9; ruling filed as `rule/1617`). The driver's error came from
trusting a shipped comment that names the canvas meaning on the very line that diverts away
from it. Crew A also corrected three of the PLAN's named leads (`sel_waves` is a token not a
proc, `wviewer::model_sel` never touches a rect, `edit_wave_attributes` is the legend dialog),
reversed the PLAN's logging instruction (selection gestures are not logged — D11), and found
three traps the implementer would otherwise hit (D10).

**What this says about the batch's own method:** D2 put a recon stage first because the driver's
scouting had been refuted twice. It was refuted twice more. The recon stage paid for itself in
both stages before a line of code was written.
