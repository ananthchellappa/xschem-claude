# Ledger — headless crashes batch

| stage | item | crew | receipt | verdict | commit |
|---|---|---|---|---|---|
| setup | — | driver | PLAN.md | batch opened 2026-09-22 | `7e1e6a6f` |
| Map | A+B (1493, 0227/0834/0467) | workflow `headless-crashes-A-B` | pending | in flight | |

## Adjacent streams (D2) — not this batch's items, driven alongside it

These are recorded here because this was the live batch when the driver opened them, so
the record shows where the attention went. They have no batch directory of their own; the
issue files carry their full receipts.

| item | crew | what landed | T1 | commit |
|---|---|---|---|---|
| **1352** — `input_line`'s OK button ran what you typed as Tcl | input-line-inject-crew | `list`-quoted entry contents + an emptiness guard; `test_input_line_inject_1352` registered in **both** `hcases` and `dcases`, 7 checks headless / 34 on a display | `cases=90 blocks=89 counted_failures=0 skips=6`, `tests/results.2825611.log` | `2a22bfb7` |
| **1601** — a file NAME is a script in the Open and Insert preview bindings | driver (filing), fix crew in flight | filed from 1352's sibling survey; provenance measured — the shape is upstream by four years, one commit that touched it (`451a949c`) is ours | — | `f8647d8d`, `321f43c0` |
| **1600** — `test_ase_core`'s 5324-line unnamed file-scope `catch` | ase-core-catch-crew (own clone, `/var/tmp/x1600/tree`) | 15 named guards; worst single-raise span 5324 → 609 lines; 2 cascades found by the sabotage and hoisted out; the issue's own awk sweep returns zero on the file and 34 corpus-wide, from 35 | crew's clone at `e92a2abf`: `cases=88 blocks=87 counted_failures=0 skips=5` | `5a6da030` |
| **1600** follow-up — two holes the pass exposed | driver | item 3, the UNGUARDED stretches the sweep is blind to (319 of 675 rows, and a raise there yields no verdict at all); item 4, the denominator, with the obvious design rejected and the `else`-arm design recorded | — | `1c298398`, `06c6a6bc` |
| **combined gate** — 1352 + 1600 together | driver | a throwaway clone of `5a6da030` at `/var/tmp/xgate_5a6da030/tree`, built from scratch, `DISPLAY=:99` | **`T1-RUN-END pid=2983014 cases=90 blocks=89 counted_failures=0 skips=6 elapsed=553s`**, `tests/results.2983014.log`; 0 counted shapes by independent grep; 0 live-peer announcements, so it ran solo; all six `skip:` lines named — five `test_op_annot`, one the new suite's | — |
| **1600** next file — `test_ase_dialogs` (5699 lines, T1 case) | ase-dialogs-catch-crew (own clone, `/var/tmp/x1600d/tree`) | in flight | | |
| T1 baseline | driver | `CLAUDE.md` moved from 88/87/skips=5 to 90/89/skips=6 | read off `results.2825611.log` | `4a74bc24` |
| owed-queue triage | queue-triage-crew | 248 entries → 69 retired, 179 survivors collapsing to 2 framing questions, 19 decisions, 22 sittings; store byte-untouched | — | `e92a2abf` |

### What the 1352 receipt is worth reading for

Three things in it are method, not result, and the next crew should copy them:

1. **It named the rows that stayed green under sabotage** — `B7`, `B13a`, `B13b`, `B2`,
   `B12a`, `B12b`, `B14`, `B17a`, `S0`, `S3`, `S5` — so nobody counts them as coverage.
   They are guards on behaviour the defect did not break, and a receipt that omitted them
   would have read as eleven more discriminators than it has.
2. **It separated DRIVEN from REASONED** and put the reasoned list in writing: a hostile
   `$cmd`, Unicode, very long entry text, Windows, and the six C-side `{}` callers driven
   only by shape rather than through their own code paths.
3. **It stripped comments before grepping the product.** The fix's own comment quotes the
   defective line verbatim, so a raw-file structural row would have answered "still broken"
   for ever. Any structural row that greps a file its own fix documents needs this.

### One thing the 1352 crew flagged that the driver must not lose

`rule/1352` is **still open** and asks the user to choose between taking the one-line fix
tree-wide, surveying every caller first, or leaving it as an inherited sharp edge. The crew
did the survey **and** took the fix without that answer, which is the recommended shape
(`doc/claude/code_analysis/owed_queue_triage_2026-09-22.md`, D-1) — but the user is now
being asked to choose between options one of which has already shipped, and they have to be
told that when the question is put. A rule debt clears only when the user says so.

`rule/1601` was filed for the sibling sites and asks the same question about the same
published branch. **It rides with `rule/1352`; it is one conversation, not two.**
