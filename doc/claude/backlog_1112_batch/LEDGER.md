# Backlog batch 2026-11-12 — LEDGER

Base: e615a1801 (fluid-editing). One row per stage when its receipt is collected.

| stage | item | crew receipt | verifier | T1 gate | commit |
|---|---|---|---|---|---|
| A | 1 seed steps aside | receipts/A-seed.md (3 passes: base, preview gap, verifier D1-D4) | receipts/A-verify.md: D1 blocked, fixed; re-verify clean, 4 warning-only misses + sabotage Y1 recorded | ~/gc26 results.2828742.log 197/0/skips=13 (private :100) | 5f88a7c65 |
| B | 3 T1 never waits for :99 | | | | |
| C | 4 more device limits | | | | |
| D | 2 dead-gated checks | | | | |
