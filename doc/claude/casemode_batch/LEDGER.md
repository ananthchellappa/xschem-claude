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
| 1 | delete the fold + `Raw.case_sensitive` | `[x]` | `fbfc6395` | 81 | 33 | 7 code + spec | no | audit diff = **one added row** (`test_raw_case_mode PASS`), **zero movers** — 00a's contract met exactly. Review found 5 real bugs beyond scope, all fixed. Xyce **RULED: no fold**. Spec `specs/raw_case_mode.md` |
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

## The baseline ROLLED FORWARD at item 1 — read this before diffing an audit

Item 1 added one row to the audit (its own new suite `test_raw_case_mode`), so
every later item would otherwise re-explain the same added row forever. The
pipeline's baseline is therefore now

**`doc/claude/casemode_batch/audit_item01_closer_2026-08-16.txt`**
— **317 pass / 15 fail / 0 crash-timeout / 0 skip of 332**, at `fbfc6395`, on `:99`.

The roll is safe because item 1's closer audit was itself diffed against the
merge-5 baseline and **moved zero statuses** — it is that file plus one `PASS`.
Verified independently by the driver, by name and status: the entire diff is
`> test_raw_case_mode PASS`. Diffing each item against the immediately preceding
state is strictly *more* sensitive than diffing them all against a fixed older
file, not less.

**Counting trap in these audit files:** six lines read `FAIL     | key ...` and
are *within-file detail*, not test rows. A naive `grep -c '^FAIL'` returns 21 and
is wrong; the real figure is 15.

## Carry-forwards item 1 handed to later items

Item 1's receipt §5 ("what was NOT verified") is the source. These are **not**
item 1 defects; they are scope that lands elsewhere:

- **Item 2** — `src/vcd_read.c:139-141` now asserts the **opposite** of what the
  code does (the apology survived the fold's deletion). Item 2 already owns
  retiring it. Also: `raw case` on a **`table_read`** database was never driven
  (VCD and spice were), and no sweep exists of Tcl consumers of `xschem raw list`
  doing an exact lowercase comparison that could now miss.
- **Item 5b** — **a THIRD `ngspice_data` publisher exists, and it is in Tcl**:
  `ngspice::read_raw_dataset` (`ngspice_backannotate.tcl:24`). It is harmless
  today only because of its own `string tolower` at `:38`. Any 5b work that
  counts the publishers as "the two C sites" is already wrong. This refutes the
  item-1 verifier's "only C writes it".
- **Anyone touching `read_dataset`** — issue **`0316`** is open and was
  re-measured during item 1: a malformed raw header makes `read_dataset()` call
  `extra_rawfile(3, NULL, …)`, clearing **every** loaded database. Item 1's new
  `fopen` probe cannot close it.
- **Xyce is now RULED, not open** (`specs/raw_case_mode.md` §5): **no
  Xyce-specific fold.** Grounded in what is measurable here — no measured way to
  *identify* a Xyce raw exists (`Command:` is never parsed; `sim_is_xyce` regexps
  the configured simulator command, never the file), so a fold would gate a
  destructive transform on a heuristic. The spec records what would reopen it.
  **Item 15 must still record Xyce's behaviour as unverified.**

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
