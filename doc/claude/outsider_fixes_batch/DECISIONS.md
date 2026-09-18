# Decisions — outsider fixes batch

## D1 — Item 1 fixes the checker; other git-dependent suites are recorded, not swept in

The audit's F21 says a `git archive` export turns about ten T1 cases red because several suites
read their corpus through git. Item 1 is **the driver's own regression** — the checker it
registered in T1 on 2026-09-17 — and it is fixed completely: folder name, shallow clone, no
`.git`. Any other suite F21 names is attributed in S1's receipt and recorded as follow-up, not
fixed here, unless it shares the checker's exact root cause. Mixing a regression fix with an
unrelated sweep makes the regression fix harder to verify and to revert.

## D2 — A throwaway home is the DEFAULT, with an explicit opt-out

Item 2's default must protect the person who does nothing special, because that is who the
audit measured losing data. A developer who needs a run against their real configuration (to
reproduce a bug that depends on it) gets an explicit environment opt-out, named and documented,
never the default. The opt-out's name and the mechanism are settled in S2b from S2a's map.

## D3 — Proved with a canary, never assumed

"The tests no longer touch your home" is exactly the kind of sentence this project has written
confidently and been wrong about. Item 2 is proved by running the documented commands with the
**parent's** `HOME` set to a seeded canary directory and showing the canary byte-identical
afterwards — and by showing the canary **does** change with the fix reverted (red-first).
