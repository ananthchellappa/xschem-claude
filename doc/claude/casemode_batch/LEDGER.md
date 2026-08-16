# Casemode batch ledger — branch `fluid-editing`, base HEAD `577ef5bc`

Driver-mode unattended batch. **Item 0 CLOSED. Items 0a–15 not started.**
Nothing is pushed.

State lives HERE, not in the driver's context. After a compaction, re-read this
file and continue from the first row that is not `[x]`/`[E]`/`[D]`/`[F]`.

## Read before touching anything

1. **`DECISIONS.md`** — the 13 decisions, settled with the user 2026-08-16.
   Authoritative. Four of them overturned the plan's recommendation.
2. **`DESIGN_REVISION.md`** — the read path is redesigned: the fold at
   `save.c:1008` is **deleted**, not gated, and the lookup becomes
   case-insensitive.
3. **`PLAN.md` §3b** — the authoritative item list. §3 and §4 are superseded and
   marked as such; §0b item 1 is marked WRONG in place.
4. `OPEN_QUESTIONS.md` — how each decision was posed, and the one option that
   was written backwards.

Receipts: `receipts/NN-<slug>.md` (120 lines max).

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending (pixels) ·
`[D]` deferred (needs a filed issue) · `[F]` failed (needs a filed issue).

## Baseline — the audit debt is PAID

**`doc/claude/merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`**
— **316 pass / 15 fail / 0 crash-timeout / 0 skip of 331**, taken at `577ef5bc`
on the dev display `:99`, committed.

The plan's "~80 min stash-diff pair still owed" is **discharged** — the merge-5
loose-ends batch shot this at current HEAD. Every later audit is judged by
DIFFING that file by test **NAME and STATUS**, never by the red count.

`doc/claude/batch_F/baseline_status.txt` (285/19/1) was shot with the pre-rework
scorer and is **VOID**. `batch_F/baseline_status_2026-08-15_postmerge5.txt`
(314/17) predates two harness fixes and is superseded by the file above.

## Items

| # | item | verdict | commit | checks | sabotages | files | eyeball | note |
|---|------|---------|--------|--------|-----------|-------|---------|------|
| 0 | setup: fixtures + docs + upstream exchange | `[x]` | `fc65f14a`, `2cbc999e` | – | – | 97 docs | no | fixtures + plan + rounds 1–3. Audit debt discharged above; base HEAD corrected from `7924d0db` |
| 0b | decisions + design revision + plan/ledger correction | `[x]` | `f7ab5f65` | – | – | 6 docs | no | docs-only, no build/suite owed. `DECISIONS.md`, `DESIGN_REVISION.md`, `OPEN_QUESTIONS.md`, PLAN §3b marked superseded in place |
| 0a | suite sweep for folded-name assertions | `[x]` | `f7ab5f65` | – | – | 1 doc | no | `receipts/00a-suite-sweep.md`: **zero rows expected to move**. Static sweep; 34 suites touch `raw read`/`raw list`, 2 tracked `.raw` fixtures, no test reads either. THIS IS ITEM 1's EXPECTED-DIFF CONTRACT |
| 1 | delete the fold + `Raw.case_sensitive` | | | | | | no | |
| 2 | one lookup ladder (+ absorbs the VCD sub-step) | | | | | | no | |
| 3 | four-source mode resolution | | | | | | no | |
| 4 | the four `hilight.c` senders (Ctrl-K path) | | | | | | no | |
| 5 | viewer Tcl + two-pane browser scan | | | | | | no | |
| 5b | **one lookup authority + lazy `ngspice_data`** (D3) | | | | | | no | new item; the "perfect" fix the user chose over three papering-over options |
| 6 | extend `sim()` / `simconf` / `simrc` | | | | | | no | replaces the plan's new `ase_simulators` file |
| 7 | the capability probe (+ hard timeout) | | | | | | no | |
| 8 | profile-aware `run_cmd` + mismatch policy | | | | | | no | `distinguish` mismatch REFUSES |
| 9 | `sod_expr` stops folding + current arm | | | | | | no | flips ~20 assertions; that breakage is the evidence |
| 10 | three defences: pre-flight + `$sim_status` + content | | | | | | no | pre-flight also OFFERS legacy corrections (D1) |
| 11 | `result_probe` `-nocase` | | | | | | no | |
| 12 | post-load current repair | | | | | | no | |
| 13 | simulator dialog (extends `simconf`) | | | | | | **YES** | only item with pixels; `owed.sh add look`, never "done on a green suite" |
| 14 | netlister collision warning + `model_name()` key | | | | | | no | fires only under `fold`/`preserve`; silent under `distinguish` |
| 15 | docs | | | | | | no | must name `v(all)` **and** `i(all)`; must record Xyce as unverified |

## Environment — re-verified 2026-08-16

- Case-capable build: `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`
  (`ngspice-46+`). **The build has now moved THREE times** during this batch:
  `2026-08-12` → `Thu Aug 13 22:49:54 UTC` → `Sat Aug 15 18:18:34 UTC` →
  **`Sun Aug 16 06:52:46 UTC 2026`**, the current stamp.
  It is the user's own fork (`/home/qflow/dev/ngspice_test`, branch `ver_50`,
  real ngspice as `upstream`), so it will keep moving.
  **Assert on `$curcasemode` and on measured output, never on "this build has
  fix X in it". Every test needing it must SKIP, not fail, when absent.**
- Baseline ngspice: `/usr/local/bin/ngspice` (`ngspice-46`). Folds always,
  accepts and **ignores** `-D casemode=…`, has no `$curcasemode` (replies
  `Error: curcasemode: no such variable.`) — which is the capability probe.
- Dev display `:99` alive (1920x1080x24, openbox); gate armed `forever`.
- **No round-4 upstream drop.** Latest is
  `feedback/ngspice_upstream/RESPONSE.md`, 2026-08-15 12:31. Check for a new one
  before items 3, 10 or 14 — last time, checking first deleted a whole planned
  migration pass.

## Re-verification at the current build stamp (2026-08-16)

`repro3/run_r3.sh`, `repro3/run_r3b.sh` and `repro2/run_round2.sh` all re-run.
**Every round-3 table holds.** One cell moved and one was reconciled:

- **Near-miss warning count in OUR shape is 1, not 2.** Receipt `00c` records
  `stderr=2`. Both scripts now measure `1`. Reconciled: round 2's `R4` used
  `ctl_fail.cir`, which carries a dot card **and** `.control run` — two analyses,
  hence two warnings. It is **once per analysis**, not a doubling bug.
- **`.save` of an absent node re-measured on today's build: ver_50 is IDENTICAL
  to stock** — rc=1, 12-variable constants raw, **zero** mentions of the bad
  token on either stream. Upstream has withdrawn that fix three times. This is
  why `DECISIONS.md` C3 rules differently from C1.

New measurements taken during the decision Q&A, not in any earlier receipt:

- **`~/.spiceinit` overrides `-D casemode=` too**, not only a `.spiceinit`
  beside the deck. Kills any "check next to the deck" shortcut.
- **The phantom has a current form: `i(all)`.** `op` + exactly one saved
  **current** on stock-46 gives `i(v1) i(all)`. Every earlier note records only
  `v(all)`. Fixed on ver_50 (`0064`) for both.
- **`tran`/`dc` are immune** — their sweep axis (`time`, `v-sweep`) already
  makes the vector count two. Only `op` has no axis.
- **The probe hangs without `quit`** — two minutes, measured. Item 7's timeout
  is not optional.

## Post-merge-5 line numbers (re-grepped; every plan citation was suspect)

| what | plan said | actual at `577ef5bc` |
|---|---|---|
| `strtolower(varname)` — the fold | `save.c:1008` | **`save.c:1008`** — unmoved |
| `get_raw_index` | `save.c:2251` | `save.c:2251` |
| the `i(v.x` fixup | `save.c:2263`/`2260` | **`save.c:2274`** |
| `read_dataset` | — | `save.c:782` |
| `Raw` struct | — | ends `xschem.h:1154` |
| ASE-L `run_cmd` (hardcoded `ngspice`) | `ase.tcl:3238` | `ase.tcl:3238` |
| `simconf` dialog | — | `xschem.tcl:3092` |
| backannotation's duplicate ladder | — | `xschem.tcl:2669`, `:2688`–`:2700`, `:2724` |

## Fixtures committed at item 0

- `fixtures/tr_fold.raw` — tran, nets `In`/`MidNode`, source `Vs`, written under
  `-D casemode=fold`. Variables: `v(in) v(midnode) i(vs)`.
- `fixtures/tr_preserve.raw` — same deck under `-D casemode=preserve`.
  Variables: `v(In) v(MidNode) i(Vs)`.

Both 229-point binary raws, byte-comparable, differing **only** in the Variables
section — so items 1–5 can be tested with no ngspice present at all.

**Trap:** `fixtures/tr_source.cir` uses `write tr_MODE.raw` inside `.control`,
which is **cwd-relative**. Running it with `-r /tmp/x.raw` silently writes
`tr_MODE.raw` into the caller's directory instead. Run it from a scratch dir.
