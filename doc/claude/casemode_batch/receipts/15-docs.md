# 15 — docs: make the documentation true, and the set navigable

**Casemode batch ITEM 15, the last one.** `PLAN.md` §3b item 15 · `DECISIONS.md` **C1** (the phantom is `v(all)` **and** `i(all)`) +
**Xyce stays UNVERIFIED**. Two of the four deliverables already existed (`simulator_profiles.md` §1–§17, `raw_case_mode.md` §1–§14),
so the work was: rewrite the one doc still describing a *plan*, give the two specs an entry point, write the FAQ answer, point at
the reference material — and **check the docs against the source instead of trusting them**. `af001a12`, unpushed.

## 1. Files changed — `git diff --numstat`, six tracked files, **+604 −193**

| file | ± | what |
|---|---|---|
| `code_analysis/ngspice_case_sensitivity.md` | +248 −180 | **Part 3 rewritten as what shipped**: the rule (§3.1), which doc answers which question (§3.2), a **22-row site map** of re-grepped `file:line` (§3.3), per-simulator behaviour (§3.4), the phantom (§3.5), Xyce (§3.6), the issues with `0502` pulled out as a security issue rather than buried (§3.7), the `references/` pointer + the **three places we deliberately diverge** from that guide (§3.8), eleven rows of what the 2026-08-12 proposal got wrong (§3.9). Parts 1–2 kept, banner-marked pre-batch |
| `specs/raw_case_mode.md` | +164 −6 | reader's map (§1–§15 → question → item); §4 given the **SUPERSEDED-by-§13** marker it never had; **new §15**, the phantom; §13.2's `ngspice::lookup` sentence corrected (§2.4) |
| `specs/simulator_profiles.md` | +76 −3 | reader's map (§1–§17 → question → item, the two mandatory facts, where the rulings live); **`82` → `97`** checks, counted from the file; item 9's carry-forward debt discharged in place (§2.5) |
| `FAQ.md` | +84 | **Q48**, newest on top: *"my net is `MidNode` but the viewer shows `v(midnode)`"* |
| `casemode_batch/DESIGN_REVISION.md` | +21 | §6's **overturned ruling** marked in place |
| `src/save.c` | +11 −4 | **comment only** — one paragraph asserted the opposite of the code |

Also committed: this receipt, `item15_{cite,doc_cite}_check.py`, three audits (`audit_item15_2026-08-18.txt`,
`_fixround_`, `_closer_`). Removed `src/save.c.stripped`, a dropping the verifier left in `src/`. No pre-dirty file was touched or staged.

## 2. Decisions, and the evidence for each

**2.1 C1 — the phantom is `v(all)` AND `i(all)`, re-measured rather than copied.** In `render_deck`'s shape (`.save` outside
`.control`, analysis as a control command, **bare** `write <abs path>`), `/usr/local/bin/ngspice` (46) vs `build-ver_50`: `op` + one
saved **voltage** → `v(in) v(all)`; `op` + one saved **current** → `i(v1) i(all)`; two signals clean; `tran` clean (its sweep axis
makes the count two); `ver_50` clean throughout; both columns carry the identical value. Ruled *leave it, document it, cite
upstream* — and **verified that is what shipped**: `grep -rn "v(all)" src/` is empty, so there is no filter to go stale. **New
`raw_case_mode.md` §15** records why a filter was refused (a real net may be called `all`; the column is *correct*; upstream fixed
it) and keeps `0073` separate; §3.5.

**2.2 Xyce stays UNVERIFIED, its two rulings kept CONSISTENT, not flattened.** No reader-side fold (`raw_case_mode.md` §5 — nothing
can identify a Xyce *file*: `Command:` is never parsed, `sim_is_xyce` reads the configured *command*) **and** an uppercase
**sender** fallback (§11 — a sender may trust configured identity where a reader cannot). §3.6 states both, and what reopens them:
one real Xyce raw.

**2.3 RULED: no committed headless suite asserts `file:line`.** One that did would redden on every unrelated line drift — this
item's own comment fix moved eight `save.c` citations — and teach people to ignore a red. Two **one-shot** checkers stand in beside
the batch's other repro tools: **D1** `item15_doc_cite_check.py`, asserting **from the doc's own §3.3 table**, and **D2**
`item15_cite_check.py`, explicit assertions against the tree plus absence and prose claims.

**2.4 Four doc surfaces asserted the OPPOSITE of the code** (item 2's `vcd_read.c:139` class), each corrected **in place**, nothing
renumbered: `src/save.c:1088` claimed `ngspice_data` keys are folded "via `ngspice_data_key()`" — item 5b deleted that helper *and*
`ngspice_data_publish()`, and the array became a lazy read-traced view through `get_raw_index_in()`; `raw_case_mode.md` §4 carried
no SUPERSEDED marker although §13 supersedes it; `DESIGN_REVISION.md` §6's ruling was overturned by D3 while §4/§8/§9/§10 carry
markers; and — **found by the closer, after the fix round** — §13.2 called `ngspice::lookup` "four lines, no ladder of its own" when
`src/xschem.tcl:3751` is seven body lines with the gated ladder §13.7b of *the same file* rules on. Corrected, and **D2 guards it**
(sabotages **S9a/S9b**).

**2.5 Item 9's carry-forward debt discharged in place, not evaporated.** `simulator_profiles.md` §13 owed
"`ngspice_case_sensitivity.md:62` still quotes the two-argument `sod_expr` call site — item 15 owns Part 3". Part 3 was rewritten
and Parts 1–2 now carry a banner saying their citations are the pre-batch tree's, so that quote is dated history; the live proc is
`ase::ui::sod_expr {kind token mode}` (`src/ase_window.tcl:961`, third argument **required**). Struck through, not deleted.

**2.6 Not re-opened, deliberately.** No `DECISIONS.md` ruling touched — §2.4's findings are documentation defects, not decisions.
`PLAN.md` §3/§4 left wrong with their existing markers, per instruction. `token.c`'s folds (`0500`) stay, named in the site map. One
FAQ overstatement softened: the `distinguish` refusal lands before the deck reaches the simulator, not "before generating anything"
— `ase::netlist` has already run.

## 3. Tests — NO new suite check, by ruling §2.3; §4's drives stand in

The suites owning the touched surfaces were re-run to show the comment-only C edit and its rebuild changed nothing; counts identical
to the receipts that own them:

```
PASS     | test_raw_case_mode           run 1/3  RESULT: ALL PASS (277 checks)
PASS     | test_ngspice_data_view       run 2/3  RESULT: ALL PASS (139 checks)
PASS     | test_backannotate_digital    run 3/3  RESULT: ALL PASS (81 checks)
RESULT: 3/3 runs passed
```

**AUDIT — EMPTY, as contracted.** `GUI_GATE=1 full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped →
`audit_item15_closer_2026-08-18.txt`: `SUMMARY: 330 pass  15 fail  0 crash/timeout  0 skip  (total 345)`. Diffed by test **NAME and
STATUS** against `audit_item13_closer_2026-08-18.txt` (330/15/0/0 of 345 at `e998e853`): **only-in-baseline NONE, only-in-mine NONE,
name-only-either-way NONE** — 345 rows both sides, and the 15 reds are the policy block's 15 names exactly. Rows matched as
`^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, never `grep -c '^FAIL'` (six within-file `FAIL | key …` lines are not rows). One
`TREEDEL`: the dropping removed above. The implementer's and fix round's audits, committed alongside, diff empty against the same
baseline.

## 4. Sabotage table — ten drives, each red then green

Every drive attacks the **documentation**, this item's whole payload; none claims anything about C behaviour. Restores are from
byte-exact backups (`md5sum` equal both sides), never `git checkout`. D1/D2 first pass · S1–S8 fix round · S9a/S9b closer.

| id | what was broken | red? | restored green? |
|---|---|---|---|
| **D1** | `§3.3 save.c:3334` → `:3300` | yes — `1 FAILED (29)` | yes |
| **D2** | a `v(all)` comment planted in `src/save.c` | yes — absence claim + shifted citations | yes |
| **S1** | `§3.3 spice_netlist.c:206` → `:999999`, invisible to old D1 | yes — `1 FAILED (44)`; **old D1: `ALL PASS`** | yes |
| **S2** | a **slash-chained** citation `` `:2748` `` → `` `:99999` `` | yes — `past EOF`; **old D1: `ALL PASS`** | yes |
| **S3** | D1's own **parser guard** (walk blinded to slash-chains) | yes — `parser saw 41 … contains 44 — 3 silently skipped` | yes |
| **S4** | `save.c:3334` → `:3344`, a drift inside the old `±12` window | yes — `none of [...] within +/-4`; **old D1: `ok`** | yes |
| **S5** | §3.1 `fourteen` → `ten` suites | yes — `3.1 says 'ten', git says 14` | yes |
| **S6** | map `eight` → `seven` crews | yes — `its table lists 8 distinct items [6..13]` | yes |
| **S7** | the `untracked` caveat re-added to the guide pointer | yes — `calls the guide untracked` | yes |
| **S8** | the `view_armed` gate deleted from `ngspice::lookup` | yes — `no longer has the gated fold fallback` | yes |
| **S9a** | §13.2's false "four lines, no ladder of its own" restored | yes — `1 FAILED (47 cites, 1 absence, 5 prose)` | yes, md5 `e4e777bd…` |
| **S9b** | `foreach` renamed inside `ngspice::lookup` (code side of S9a) | yes — *after* the claim was tightened | yes, md5 `5dcdd51e…` |

**S9b caught a defect in my own check**: it first tested `"foreach" not in body`, so `foreach_DISABLED` passed — a substring test
where a token test was needed. Tightened to `^\s*foreach\s+\w+\s+\[list\s`, then driven red and green. The fix round had likewise
tightened D1 to the `±4` it always advertised (docstring said 4, code used 12) and taught it slash-chains: **44 of 44** citations
checked, was **29 of 42**. `src/xschem.tcl` and `src/save.c` are `git`-clean of every sabotage.

## 5. What was NOT verified

- **The code half.** Nothing behavioural was built, so nothing new can be sabotaged. The `src/save.c` edit is a **comment** — read
  the diff — but it is C: rebuilt, suites at unchanged counts, audit diff empty. A verifier should confirm it is comment-only.
- **Prose.** No check says whether Q48 or the two reader's maps read well to a stranger. The four *countable* prose claims are
  machine-checked (S5–S8); the rest is judgement. **No `look` debt recorded** — the payload is a file a reader opens, not pixels.
- **Reviewer findings raised but not confirmed, left as they are:** §3.8's "always pass `-n`" paraphrase is sharper than the guide's
  own caveated text (the row now names that caveat, as far as prose can be pinned); and whether §3.9's `-nocase` measurement belongs
  in a spec — it now cites the ruling **and** the receipt that measured it.
- **Not asserted at all:** no Xyce here, so §3.6 records absence of evidence; upstream's `25e891ec3` / `0064` / `0073` are copied
  from their round-3 response, unverified against their tree; the checkers are one-shot tools that will drift red as unrelated
  commits move lines — evidence about these docs at this HEAD, not a standing guard.
- **Untouched, as instructed:** the **eight `look` debts and one `:0` suite debt** already open (items 5 ×2, 13 ×4, 14 ×2; ledger
  totals 5 suite / 15 look across all batches) — not discharged, not reworded. `LEDGER.md` is the driver's. `relaycheck.tcl` /
  `tr_MODE.raw` at the repo root remain pre-existing droppings.
