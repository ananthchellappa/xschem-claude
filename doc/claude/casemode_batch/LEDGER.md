# Casemode batch ledger — branch `fluid-editing`, base HEAD `7924d0db`

Driver-mode unattended batch. **Not started.** Nothing is pushed.

Plan: `doc/claude/casemode_batch/PLAN.md` — read it first, including
§4 (three open decisions that must be answered before item 8) and §5 (holes).

State lives HERE, not in the driver's context. After a compaction, re-read this
file and continue from the first row that is not `[x]`/`[E]`/`[D]`/`[F]`.

Baseline audit: **not yet taken** — item 0 shoots it and records the filename
here. Every later audit is judged by DIFFING that file by test NAME and STATUS,
never by the red count.

Receipts: `doc/claude/casemode_batch/receipts/NN-<slug>.md` (120 lines max).

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending (pixels) ·
`[D]` deferred (needs a filed issue) · `[F]` failed (needs a filed issue).

| # | item | verdict | commit | checks | sabotages | files | eyeball | note |
|---|------|---------|--------|--------|-----------|-------|---------|------|
| 0 | setup: baseline audit + fixtures | | | | | | no | |
| 1 | `Raw.case_mode` + `read_dataset` gate + `raw read -case` | | | | | | no | |
| 2 | `get_raw_index` three-valued ladder + `i(v.x` fixup | | | | | | no | |
| 3 | `sim_case_mode` global + `auto` sniff | | | | | | no | |
| 4 | the four `hilight.c` senders (Ctrl-K path) | | | | | | no | |
| 5 | viewer Tcl matching + browser class/group scan | | | | | | no | |
| 6 | simulator profile registry model (pure Tcl) | | | | | | no | |
| 7 | the capability probe | | | | | | no | |
| 8 | profile-aware `run_cmd` + mode mismatch report | | | | | | no | |
| 9 | `sod_expr` stops folding + current arm + test flip | | | | | | no | |
| 10 | re-case pass + pre-flight refusal + empty-raw reject | | | | | | no | |
| 11 | `result_probe` `-nocase` | | | | | | no | |
| 12 | post-load current repair | | | | | | no | |
| 13 | `Setup > Simulator…` dialog | | | | | | YES | |
| 14 | netlister: fold-collision warning + `model_name()` key | | | | | | no | |
| 15 | docs | | | | | | no | |

## Fixtures committed at item 0

- `fixtures/tr_fold.raw` — tran, nets `In`/`MidNode`, source `Vs`, written by
  ver_50 under `-D casemode=fold`. Variables: `v(in) v(midnode) i(vs)`.
- `fixtures/tr_preserve.raw` — the same deck under `-D casemode=preserve`.
  Variables: `v(In) v(MidNode) i(Vs)`.

Both are 229-point binary raws, byte-comparable, and differ **only** in the
Variables section. They let items 1–5 be tested with no ngspice present at all.

## Environment

- Case-capable build: `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`
  (reports `ngspice-46+`). Private, absolute path — every test that needs it
  must **skip, not fail**, when absent (PLAN §5.9).
  **The build behind that path moved on 2026-08-13** — stamp
  `Thu Aug 13 22:49:54 UTC 2026`, carrying upstream `0056`/`0057`/`0058`/`0060`.
  It is no longer the build §0 was measured on; read **PLAN §0b** before
  trusting an F-row, and prefer `$curcasemode` over any behavioural assertion.
- Baseline ngspice: `/usr/local/bin/ngspice` (`ngspice-46`), folds always,
  accepts and ignores `-D casemode=…`, and has no `$curcasemode` — which is the
  capability probe.
- Reference: `references/casemode-distinguish-guide.md`. Its §9 probe and our
  own F5 deck are both superseded by `$curcasemode`.
- Upstream exchange: `doc/claude/ngspice_upstream/` — round 1 `FINDINGS.md`,
  their `feedback/ngspice_upstream/RESPONSE.md`, our `REPLY.md` (round 2, six
  new findings, four open questions), repro `repro2/run_round2.sh`.
