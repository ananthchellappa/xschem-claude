# plan-closeout — PLAN.md marked as the plan *as written*, with every refuted claim corrected inline

**Status:** DONE

**Files touched:** `doc/claude/harness_concurrency_batch/PLAN.md` only. **`+263 / −0`** —
verified by `git diff --numstat`. **Not one original line was deleted or reworded**; every
correction is an addition. No other file in the repo was opened for writing.

**Rows added/changed:** none — documentation-only task. **No suite was run, no
`./src/xschem`, no `make`.** The suite slot was held by another crew for the batch's
closing T1 and was not touched.

---

## What the file now says

Nine correction blocks, all marked ⚠, all dated **2026-09-17**, each quoting the claim it
corrects:

| # | site | what was corrected |
|---|---|---|
| 1 | **new header block** | states plainly this is the plan *as written*, that it was substantially refuted, points at `LEDGER.md` for what happened and `DECISIONS.md` for why, and says the stage table stops at `E3` |
| 2 | **Subject** | *"four distinct ways"* is an **undercount** — 88 fixed-name files, 83 verdict inputs, face 4 reproduced one file upstream in `<hc>.log` |
| 3 | **"do not re-derive it"** heading | the heading is the batch's own cautionary tale — three crews re-derived and three found errors |
| 4 | **solo T1 baseline** | four of its five claims now wrong: 83/82 → 84/83 (**this batch caused it**), the counting rule holed by 1481 and by `wc -l`=171, "mtime moved" retired for the trailer, 410 s never re-measured, and *"any red after this batch is ours"* **false** |
| 5 | **face 4** | `:295`/`:381` rotted; quotes `:353-354` and `:693` from the working tree; **`results.log` may not be your answer** |
| 6 | **"The shape being built"** | the whole section is gone, both halves — scratch a measured no-op, verdict overturned by the user, refusal era datable to hours, plus the false premise the new shape was argued from |
| 7 | **"one crew at a time"** | R4: the stated basis (a 7.8 GB box) does not exist; the real basis held; **R4 relaxed on measurement** with two caveats |
| 8 | **stage table** | per-row corrections for `C1`, `V1`, `B1`; the second pass is missing entirely; six prescribed fixes would have changed working code |
| 9 | **"verified already fixed"** | 1332 contradicts this file's own stage E3; *"check before believing"* was the one instruction that aged well, vindicated twice |
| 10 | **issue number** | one number became six (1476–1481) |
| 11 | **new closing section** | the defect class the batch actually found: **a count is not an identity**, ×3, and why a set difference was insufficient for `/tmp` |
| 12 | **A1's corrections** | pointer note: this was crew #1, i.e. the plan was wrong before any code was written |

---

## Commands run

Read-only throughout; `/usr/bin/grep` never bare; every command under `timeout`.

```sh
timeout 30 ls -la .../harness_concurrency_batch/ .../receipts/
timeout 60 /usr/bin/grep -n -E '658|660|phantom|\.work' A1.md
timeout 60 /usr/bin/grep -n -E '435|436|771|375|44%|12%|10328|10350|dmesg|OOM' V4.md
timeout 60 /usr/bin/grep -n -E '88 fixed|83 are|verdict input|15\.35|16091816|64\.4|53\.7' R1-recon.md
timeout 60 /usr/bin/grep -n -E 'EMERGENCY SAVE DIR|identity|set difference|48|sibling|0 of 4' W12b.md
timeout 60 /usr/bin/grep -n -E 'T1_LOG_LOCK_WAIT|exit 2|refus|T1-RUN-BEGIN|T1-RUN-END|fconfigure|log_fn' tests/run_regression.tcl
timeout 60 git show -s --format='%h %ad %s' --date=short 43b40f04 32dff39a 5f7164d4 890cb5e5
timeout 20 /usr/bin/grep -A 14 'Corrections to .*PLAN' <every receipt>
timeout 30 /usr/bin/grep -n -E '1332|0642|0645|0994' E3.md ; ... C1.md
timeout 30 sed -n '671,690p' tests/run_regression.tcl
timeout 30 git status --short ; timeout 30 git diff --numstat -- .../PLAN.md
```

**Tree state for every citation in this receipt and in my edits (rule 10):**
`git status --short` returned **nothing** for `tests/run_regression.tcl`, so the working
tree I read **is** `873cce32` for that file. Line numbers below are quoted with their text.

---

## Measurements

| measurement | value | command |
|---|---|---|
| PLAN.md diff | **+263 / −0** | `git diff --numstat` |
| HEAD at time of work | `873cce32` | `git log -1 --format='%h %s'` |
| `run_regression.tcl` vs HEAD | **clean** (no `M` line) | `git status --short <file>` |
| issue files minted this batch | **6** (1476–1481) | `ls doc/claude/issues/ \| grep -E '^14(7[6-9]\|8[01])-'` |
| the 84th case | `"headless/test_regression_concurrency_1476"` at `run_regression.tcl:93` | `grep -n` |

---

## Claims checked vs taken on trust

Every bullet in my dispatch brief, marked against the record. **I verified each against
`DECISIONS.md`, `LEDGER.md` and the underlying receipt — none was inherited from the
driver's summary.**

| brief's claim | verdict | evidence |
|---|---|---|
| The shape changed completely; "second run waits" is gone; user rejected the framing with *"Why not make it fault-tolerant…"*; **both runs proceed, nobody waits, nobody is refused** | **CONFIRMED** | quote at `DECISIONS.md:119-121`; and in the tree, `run_regression.tcl:677`: `puts "  BOTH RUNS PROCEED. Nobody waits and nobody is refused (ruling R1)."` |
| The refusal era lasted **hours** — `43b40f04` introduced, `32dff39a` removed, same day | **CONFIRMED** | `git show -s --date=short`: both **2026-09-17** |
| Plan's stated minimum was a measured no-op — **658 against 660** | **CONFIRMED** | `A1.md:120-124`, the three-row table; independently in `DECISIONS.md:43-45` |
| Driver's premise false — **88 fixed-name files, 83 verdict inputs, the lock protected 1 of 88** | **CONFIRMED** | `R1-recon.md:146` (*"A full T1 run writes 88 fixed-name files under `tests/`"*), `:158` (*"The lock protects 1 of those 88 … 83 are verdict inputs"*) |
| R1/R2/R3 were filed as the user's and never were; user returned them; **R4 taken by the driver and relaxed on measurement** | **CONFIRMED** | `DECISIONS.md:103-124` (the user's quote verbatim), `:400` — *"✅ **R4 IS RELAXED, 2026-09-17.**"* |
| **Six** prescribed fixes would have changed working code — 0867, 0990, 0805, 0609, 1478, and one the driver wrote | **CONFIRMED** | `DECISIONS.md:524`, `LEDGER.md:325-327` |
| Concurrency **~44% faster** at full-T1 scale (435 s vs 771 s), not slower | **CONFIRMED** | `V4.md:278-283` — back-to-back **771 s**, concurrent **435 s / 436 s**, per-run cost ~12% |
| Memory pressure **nil** | **CONFIRMED** | `V4.md:307-308` — peak **10328 MiB** concurrent vs **10350 MiB** solo; swap 0; `dmesg` OOM kills 0 |
| The `~7.8 GB` box is **15.35 GiB** | **CONFIRMED** | `R1-recon.md:268` — `MemTotal 16091816 kB`, from `/proc/meminfo` |
| The OOM has **no receipt anywhere** | **CONFIRMED** | `V4.md:317,342`; `LEDGER.md:127-129` — the chain is assertions citing each other |
| **A count is not an identity**, three times; for `/tmp` even a set difference was insufficient — it took the child announcing its own path | **CONFIRMED** | `W12b.md:58-86` (why a set difference is not the fix), `:71` (`EMERGENCY SAVE DIR: %s`), `:346-349`; `DECISIONS.md:400-405` |

### Two refinements where the brief is right in substance but would mislead if requoted

1. ⚠ **"Nobody waits and nobody is refused" is the RUN-level truth, not a literal
   absence of waiting.** The lock was **not deleted** — it is *demoted* to bracketing
   **one file copy**, and `T1_LOG_LOCK_WAIT` still exists (default **60 s**) as the
   publish-lock knob at `run_regression.tcl:945`. What was deleted is **refusal and
   `exit 2`**. Anyone writing "the lock is gone" would be wrong in the same direction the
   batch has been wrong all night. I wrote the distinction into PLAN.md rather than
   repeating the brief's shorthand.
2. ⚠ **R4's relaxation is about the harness, not about this batch's dispatch queue.**
   `DECISIONS.md:400` relaxes R4; `LEDGER.md:82-83` still reads *"Only one crew may run
   suites at a time"*, and my own dispatch forbade suites because another crew held the
   slot. These do not contradict each other — the queue is a constraint on **this batch**,
   not the standing rule — but a reader meeting both would reasonably think one is stale.
   PLAN.md now says which is which.

### Taken on trust (not independently re-measured — I ran no suite)

Every *behavioural* number: the 407/432/757 pre-fix phantoms, V4's seven T1 runs, the
375 s solo, W12b's 48-corpse flood, R2-build's predictions. All are receipt-backed and
mutually consistent, and re-measuring any of them would have required the suite slot.

---

## Corrections to PLAN.md

That is the whole task; the twelve sites are tabulated above. **Two findings the driver's
brief did not have:**

1. ⚠ **PLAN.md contained an internal contradiction that no receipt ever flagged.** Its
   *"Verified already fixed, do not touch: **1332**"* stands twelve lines below its own
   stage row **E3 — "1332-residual"**. Both were written in the same document at the same
   time. E3 then found the residual live *and* found 1332's own `:258` citation wrong,
   repeated three times, pointing at nothing — while this PLAN's `:277,285` was correct.
   The lesson is sharper than "issue files rot": **a `Status: FIXED` banner is a claim
   about part of an issue, not about the issue**, and the plan believed the banner over
   its own stage table.
2. **The plan was right about two things and they deserve saying**, because a document
   this wrong is otherwise easy to dismiss wholesale: 0990's *"would have to run two
   regressions at once, which is expensive"* is **still refuted** (one case, ~70 s), and
   the pre-fix pair table (**407/432/757**) is the one measured block that survived
   everything — `DECISIONS.md` ⚖ R4 rests the entire serialisation rule on it after the
   RAM figure evaporated. I marked both as surviving rather than letting the corrections
   imply the file is uniformly unreliable.

---

## Left dirty

Measured with `timeout 30 git status --short` **after** this receipt was written, not
predicted from memory:

```
 M doc/claude/harness_concurrency_batch/PLAN.md                        (+263 / −0)
?? doc/claude/harness_concurrency_batch/receipts/plan-closeout.md      (this file)
?? .xschem/
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

Exactly **two** entries are mine: the modified `PLAN.md` and this new receipt. The other
four untracked entries are **pre-existing and not mine** — they are present in the
session's opening `git status` snapshot. **Nothing committed**, per rule 7.

⚠ **This block's first draft omitted the receipt itself**, because it was written before
the file existed and described a tree state I had measured three minutes earlier. Caught
by re-running `git status` instead of trusting the earlier reading — which is the batch's
own standing rule applied to the batch's own closing receipt. Recorded rather than
silently corrected, since a receipt that misstates the tree it leaves behind is precisely
the failure class this batch spent its tail documenting.

Not touched, as fenced: `DECISIONS.md`, `LEDGER.md`, `CREW_BRIEF.md`, `CLAUDE.md`, any
`tests/` file, any `src/` file, any issue file, any other receipt, `owed.sh`.

## Owed to the user

**None.** This task is internal documentation of a test harness — it reaches no person,
produces no pixels, and contains no unratified decision. Per the filter `DECISIONS.md`
records (*does this reach a person?*), filing a rule debt here would repeat the error the
user corrected when they returned R1/R2/R3. The owed ledger was not opened.
