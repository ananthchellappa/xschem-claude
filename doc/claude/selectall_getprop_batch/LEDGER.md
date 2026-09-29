# LEDGER — selectall_getprop_batch

One row per collected receipt. The driver writes this, not the crews.

Opened 2026-09-29 at `b89fddda`. T1 baseline `cases=107 blocks=106 counted_failures=0 skips=8`.

| stage | crew receipt | verified by driver | commit | T1 gate |
|---|---|---|---|---|
| R recon | `R-recon-A.md` + `R-recon-B.md` **dispatched** 2026-09-29 | — | (no code) | — |
| A Ctrl-A select all traces (1617) | _pending_ | — | — | — |
| B getprop arms (1618) | _pending_ | — | — | — |

## Collected notes

**Stage R dispatched as TWO crews**, one coherent task each, both read-only so they run
concurrently without conflict: crew A owns PLAN questions 1-6 (Ctrl-A), crew B owns 7-12
(`getprop`). Splitting it this way keeps the "one task per crew" rule while not serialising
two independent read-only surveys. Both were told explicitly which questions are NOT theirs.
