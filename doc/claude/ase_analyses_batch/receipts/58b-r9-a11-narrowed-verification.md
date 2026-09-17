# 58b — ADVERSARIAL VERIFICATION of receipt 58 (⚖ R9 A11 narrowed)

Separate verifier. I did not do the work. Every number below was re-derived; nothing is
accepted from receipt 58. HEAD was `15486b86` at start and is `15486b86` now; `git status` is
byte-for-byte the state I was handed. **No commit, no `git add`, no stash/restore/checkout/clean/push.**
`tests/run_regression.tcl` **NOT run** (driver's, solo, issue 0990). **Nothing filed or cleared in
the owed ledger**; debts are reported upward at the end. `~/.xschem/recent_files` **untouched at
2026-09-13 18:53:01.297381420** at start and end. **`/usr/bin/ngspice` never invoked**, no deck, no
run under `sky130A/`; `ps -eo comm=` (by NAME, never `pgrep -f`) showed `Xvfb 1 / openbox 1 /
xschem 2` and **zero `ngspice`** throughout. Binary always by path, always `--nolog`, never a bare
`xschem`. `LEDGER.md` **not opened for writing**.

## VERDICT TABLE

| # | claim | verdict | what earned it |
|---|---|---|---|
| 1 | the narrowing is wording-only; `ase.tcl` −14/+23 (−0/+0 non-comment), `core` −29/+66 (−3/+3 non-comment), the whole non-comment change being the `LB14` check DESCRIPTION | **PARTLY** | headline **CONFIRMED**; **`core` is −28/+65, not −29/+66** |
| 2 | the asserted partition is byte-identical | **CONFIRMED** | `lb14cite`, `lb14bits`, accumulator and BOTH expected lists diff clean against HEAD |
| 3 | `test_ase_core` ALL PASS (675) on both arms, before and after | **CONFIRMED** | all four cells measured by me, by NAME (`MT10`) and BANNER (`OVERALL: ok`) |
| 4 | 393 (neighbours 378 / 394) | **CONFIRMED** | all three reproduce exactly |
| 5 | 18, re-derived by rendering, classifier not its own witness | **PARTLY** | **18 confirmed by two independent routes of mine**; but the probe's composer is a verbatim clone of `lb14bits` |
| 6 | the third site is comment-only, namespace-level, ungrepped | **CONFIRMED** | all three, plus a positive suite row |
| 7 | the ratchet survives in both directions (A1, A2) | **CONFIRMED** | both re-run by me; A2 reds `LB14` alone |
| 8 | A3a was INVALID, reddened nothing, and A3c is the arm it should have been | **CONFIRMED** | reproduced; **the stated cause measured, not argued** |
| 9 | housekeeping — floor, `.state` 104/`{}`/1/1, extractor, zero ngspice, HEAD, canary | **CONFIRMED** | every item re-measured |
| 10 | document consistency after the narrowing | **PARTLY — the crew UNDER-reported** | it flagged one contradiction; there are **four**, and one is a **third live instance of the twice-wrong count** |

---

## 1 — wording-only: CONFIRMED in substance, one count REFUTED

`git diff --numstat`, which I cross-checked against `grep -c '^-[^-]'` / `'^+[^+]'`:

| file | receipt 58 says | **measured** |
|---|---|---|
| `src/ase.tcl` | −14 / +23 | **−14 / +23** ✅ |
| `tests/headless/test_ase_core.tcl` | −29 / +66 | **−28 / +65** ❌ |

The crew's pair is exactly `grep -c '^-'` / `grep -c '^+'` on the diff, which counts the `---` and
`+++` **file headers** as changed lines. It used the header-free method for `ase.tcl` and the
header-inclusive method for the test, so the two rows of its own table were produced by two
different rules. Off by one in each direction, in the inflating direction. **Immaterial to the
headline, material to the discipline** — a counted diff is the guard this batch leans on, and a
guard computed two ways in one table is a guard nobody can re-derive.

**The partition itself is right.** Every one of `src/ase.tcl`'s 37 changed lines begins `  #`
→ **−0 / +0 non-comment**. `test_ase_core.tcl` has seven hunks; six are `#`/`##` comment blocks,
and the only non-comment hunk is `@@ -7144,3 +7181,3 @@` — **−3 / +3**, the `check` command's
**first argument**, its description string. The `[list …]` actual and `[list …]` expected that
follow it are untouched, so **no assertion moved**.

## 2 — the asserted partition is byte-identical: CONFIRMED

I extracted `proc lb14cite` through the final line of the `check`'s expected list from
`git show HEAD:tests/headless/test_ase_core.tcl` and from the worktree — 74 lines each. `diff`
reports **exactly three changed lines, all three inside the description string**. `proc lb14cite`,
`proc lb14bits`, the `foreach [ase::sim_option_names ngspice]` accumulator, and **both** expected
lists (`{acct list node nomod nopage oldlimit opts}` / the ten MID names / `END MID END {}`) are
byte-identical. Independently: no hunk in the diff contains `proc lb14`, `lappend out`, `LB14END`,
`LB14MID`, `acct list node` or `debug defas`.

## 3 — 675 on both arms, before AND after: CONFIRMED

The "before" state was produced by writing `git show HEAD:` content over both files, **verified at
HEAD by an empty `git diff --numstat`**, then restored by plain `cp` and proved by `cmp` +
`md5sum -c`.

| | arm | `RESULT:` | `ok:` lines | last emitting row **by name** | terminal banner |
|---|---|---|---|---|---|
| before | nogui | ALL PASS (675) | 675 | `MT10` | `OVERALL: ok` |
| before | disp `:99` | ALL PASS (675) | 675 | `MT10` | `OVERALL: ok` |
| after | nogui | ALL PASS (675) | 675 | `MT10` | `OVERALL: ok` |
| after | disp `:99` | ALL PASS (675) | 675 | `MT10` | `OVERALL: ok` |

0 `FAIL` lines in all four. `disp` = `devdisplay.sh exec` on `:99` (Xvfb, **openbox (Openbox)**,
`1920x1080x24`, `status` = alive), the `timeout` prefix **inside** `exec` so `cmd_exec` stays the
parent. Also green on the finished tree: `test_ase_options_1437` **ALL PASS (75)** (`PR4` last),
`test_ase_optsheet_1441` **ALL PASS (64)** (`HK5` last), `test_op_annot` **ALL PASS (485)**.

## 4 — 393: CONFIRMED, all three numbers

```
grep -oE '[A-Za-z0-9_/]+\.c:[0-9][0-9-]*' src/ase.tcl | wc -l   ->  393   ← the number written
grep -cE  '[A-Za-z0-9_/]+\.c:[0-9][0-9-]*' src/ase.tcl          ->  378   (lines)
grep -oE  '\.c:'                           src/ase.tcl | wc -l  ->  394   (bare, no digit)
```

`llength [ase::sim_option_names ngspice]` = **247**, and `dict exists … site` = **247** /
`ase::ui::optsheet_key … site` non-empty = **247**, so the crew's row-count claim also holds.

## 5 — 18: CONFIRMED twice; the independence claim PARTLY overstated

I wrote my own probe from **`ase::ui::optsheet_detail`'s body in `src/ase_window.tcl`**, with a
**branch-instrumented** classifier of my own, and deliberately composed **one bit more** than
`lb14bits` does (`ase::opt_default`, which `optsheet_detail` renders inside its `CHANGED from the
default …` string and `lb14bits` omits):

```
PROBE option_rows 247
PROBE option_bits 17  option_occurrences 20  distinct_options 17
PROBE kind_bits 1  kind_occurrences 1  kinds deriv
PROBE TOTAL_BITS 18  TOTAL_OCCURRENCES 21
PROBE END_options 7 : acct list node nomod nopage oldlimit opts
PROBE MID_options 10 : debug defas itl1 itl2 itl4 klu_memgrow_factor newtrunc scale wnflag x11lineararcs
PROBE compliant_bits 8   noncompliant_bits 10
```

**And a second route with no composer in it at all** — a per-CATALOGUE-KEY citation census over
the raw catalogue, which cannot inherit a composer's mistake:

| key | rows carrying a citation | occurrences | rendered? |
|---|---|---|---|
| `inert` | 11 | 11 | yes |
| `clamp` | 3 | 3 | yes |
| `caveat` | 2 | 5 | yes |
| `defect` | 1 | 1 | yes |
| `site` | 227 | 227 | **no** |

`11+3+2+1` = **17 rows / 20 occurrences**, plus the measurement catalogue's `deriv` = **18 bits /
21 occurrences**. Two routes, same pair. The arithmetic against `LB14`'s own lists closes:
**7 END options + 1 kind = 8 compliant, 10 MID options = 8 + 10 = 18.**

⚠ **The overstatement.** Receipt 58 says the probe was written *"deliberately not by calling
`lb14cite`/`lb14bits`"*. `census.tcl`'s `proc bits` is a **line-for-line clone of `lb14bits`** —
the same eight accessor calls in the same order; only the proc name and a header comment differ.
So the **classifier** genuinely was not its own witness (CONFIRMED, and that is the load-bearing
half, since `lb14cite` is what the row turns on), but the **composer** was reused verbatim, and
"not `lb14bits`" is not accurate. My key census supplies the independence that was claimed.

⚠ **The crew's declared weakness 4 is real but currently LATENT, and I can say so with a
measurement rather than a worry.** `optsheet_detail` renders exactly one catalogue-sourced bit
`lb14bits` does not compose (`default`), and **no `default` value carries a citation**; every
citation-bearing key that reaches a screen is one `lb14bits` composes. So there is **no blind spot
today**. The gap only opens if a future surface starts rendering `site` (227 citations) or a
citation lands in a rendered key nobody added to `lb14bits`. A cheap row would close it: assert
that *the set of catalogue keys carrying a citation is exactly `{inert clamp caveat defect site}`*
— it reds the day a citation appears in a rendered key `lb14bits` forgets. **Not implemented**:
that is new cover, not a claim under test.

## 6 — the third site (`src/ase.tcl`, above `variable sim_options`): CONFIRMED, all three

* **comment-only** — all 37 changed lines in the file begin `  #`; −0/+0 non-comment.
* **namespace level** — the block is lines 29586–29635, sitting between `proc option_fallback`'s
  closing brace (29584) and `variable sim_options` (29636), i.e. outside every proc body, so no
  `info body` can reach it. Belt and braces: `test_ase_optsheet_1441:811`, the one suite that does
  `info body` on that namespace's `option_fallback`, additionally strips comments through
  `s_nocomment`.
* **nothing greps its text** — no needle from the block (`BRACKET CLOSES THE SENTENCE`,
  `NARROWED BY THE USER`, `SURVEYED BY RENDERING`, `SEVEN WERE MOVED`, `THE SIX ARE ONE STRING`)
  appears anywhere under `tests/`. ⚠ **A comment that a test greps is not a comment for this
  purpose, and there IS a suite that reads `src/ase.tcl` as a FILE** — `test_op_annot.tcl`, via
  `V_A10_OTHER` and `N_ASE`/`opa_v_ngrep`. Its needles are annotation-mode sentence fragments with
  no vocabulary in common with the A11 block, and I did not settle it by argument: **`test_op_annot`
  is ALL PASS (485)** on the finished tree.

The widening was declared in advance and is exactly two hunks, so the driver can revert it as
offered. I agree with the crew's reasoning for taking it: leaving it would have left the
twice-wrong pair alive in the file the catalogue lives in.

## 7 — the ratchet, both directions: CONFIRMED by my own arms

Discipline: needle **extracted from the tree by line range** (never hand-transcribed), asserted to
occur **exactly once or abort**, replacement built by a substring surgery that must itself match
once, **counted diff against my own snapshot** (never md5, never `git diff` vs HEAD which also
carries the crew's change), the **other** file proved untouched by `cmp`, restore by plain `cp`
proved by `cmp`, and a trap that restores on any exit.

⚠ **The extractor was fed the empty case FIRST, before any arm**, and is a positive assertion
(*"I saw a `RESULT:` line and it said ALL PASS"*):

```
missing -> DIED(empty-or-missing log)      failnoline -> DIED(RESULT not ALL PASS but no FAIL: lines)
empty   -> DIED(empty-or-missing log)      red        -> REDS[LB14]
ws      -> DIED(no RESULT line)            allpass    -> ALLPASS(675)
noresult-> DIED(no RESULT line)
```

| arm | what | counted diff | declared blast radius | measured |
|---|---|---|---|---|
| **A1** | an **ELEVENTH** mid-sentence citation planted in `oldlimit`'s `help` (an END-set option) | 2 (intended 2) | core `LB14` alone | **`REDS[LB14]`**; `options_1437` `ALLPASS(75)` |
| **A2** | pinned MID `x11lineararcs` quietly **reworded compliant** | 2 (intended 2) | core `LB14` alone | **`REDS[LB14]`**; `options_1437` `ALLPASS(75)`, `optsheet_1441` `ALLPASS(64)` |
| **A3a** | tail-test-only always-`END` (the crew's invalid arm) | 6 (intended 6) | core `LB14` alone | **`ALLPASS(675)` — reddened NOTHING** |
| **A3c** | true always-`END` classifier | 1 (intended 1) | core `LB14` alone | **`REDS[LB14]`** |

**No arm reddened a row it was not aiming at.** Campaign ends on a positive restored-tree row:
`ALLPASS(675)` on **both** arms, `cmp` clean.

**A2 is the one that mattered and it holds.** The narrowing puts the ten *out of scope*, so the
plausible failure was that the row would stop caring what happens to them. It does not: rewording
`x11lineararcs` into a bracketed sentence-closing form moves it MID→END and reds `LB14` on both
lists at once.

```
actual {{acct list node nomod nopage oldlimit opts x11lineararcs} {debug defas itl1 itl2 itl4
         klu_memgrow_factor newtrunc scale wnflag} END MID END {}}
```

## 8 — A3a: the self-report is ACCURATE, not merely honest

I reproduced it: replacing `lb14cite`'s tail test with an unconditional `lappend out END`
(counted diff 6 = 5 out / 1 in) gives **`ALL PASS (675)`**. The green is real.

**And the stated cause is the real one — I measured it rather than accepting the reasoning.** My
branch-instrumented classifier reports, for every rendered citation, which exit `lb14cite` takes:

```
NOBRACKET 12    TAILDOT 7    TAILEMPTY 1    TAILMID 1
```

The **12 `NOBRACKET`** citations return MID at `if {$open < 0}` and **never reach the tail test** —
they are exactly the ten out-of-scope options' citations (`scale` and `wnflag` carry two and three
respectively). The **only** citation the A3a edit could possibly flip is the single `TAILMID`,
`wnflag/inpgmod.c:268` — and `wnflag` stays MID regardless, through `inpcom.c:990` and
`inp.c:2828`, both `NOBRACKET`. Term 4's hand-made string `a limit lives at foo.c:12 and the
sentence goes on` is `NOBRACKET` too, so the tail-only edit cannot move it either. **Nothing could
move; the green was forced.** That is precisely what receipt 58 says.

**A3c genuinely covers what A3a was for.** `lappend out END ; continue` as the first statement of
the match loop makes every citation answer END unconditionally, and **two** terms catch it — term
2's MID list collapses to `{}` and term 4 answers `END` where `MID` is required:

```
actual {{acct debug defas itl1 itl2 itl4 klu_memgrow_factor list newtrunc node nomod nopage
         oldlimit opts scale wnflag x11lineararcs} {} END END END {}}
```

The lesson the crew drew is the right one and worth keeping: **the counted-diff guard proves the
edit landed where you aimed it; it cannot prove the mutation means what you claimed.** A positive
control coming back green is never a pass.

## 9 — housekeeping: CONFIRMED

* **Floor unmoved at 675** — `# AND RAISED 673 -> 675.` untouched at `:261`, and the diff's
  `@@ -245,0 +251,10 @@` hunk adds a ten-line paragraph immediately above it explaining the
  non-move and citing task 3's **C1** (the `#` inside a `[list …]` that truncated a sibling suite
  242 → 232). Correct placement: beside the floor, in the file's idiom.
* **`.state`** — `tracked 104  bad {}  control_disagrees 1  control_agrees 1`, driven as the proc
  `ase_state_roundtrip`, measured by me twice (before my campaign and on the restored tree).
* **No golden** — `tests/headless/gold/` holds six files, none mentions `LB14` or the rule. The one
  file carrying the old description is `tests/headless/test_ase_core.log`, which `git ls-files`
  reports as **not known to git**. Confirmed untracked run artefact.
* **Hygiene** — `ARCHIVED_DO_NOT_RESTORE/{pristine,fin}` present; `plant.py`, `arm.sh`, `reds.sh`
  all `.disarmed`; **26** campaign logs and 10 needle/replacement files kept; no stale pristine
  `ase.tcl` under `/tmp` newer than 2026-09-14.
* **HEAD** `15486b86`, **`git status` unchanged**, both files `md5sum -c` OK against the state I was
  handed, `git diff --numstat` still `23 14` / `65 28`.

## 10 — document consistency: the crew UNDER-reported, and one of the misses is a NUMBER

The crew flagged one tension. There are **four**, and they are not all cosmetic.

### ⚠ (a) THE TWICE-WRONG COUNT IS STILL LIVE, A THIRD TIME — in the review document

**`R9_COPY_REVIEW.md:5914`** still reads:

> Of the **17** rendered citations the survey found, this was the only one already compliant

That is the **17** that §A11's own correction block at `:739-746` declares wrong — *"It read
'seventeen … 17 bits over 16 options' … both wrong"* — and which `:737` and the whole of this task
set to **18**. The crew grepped for the pair **by number in the tree** and found the third site in
`src/ase.tcl`, which is a real catch; it did not sweep the **document**, where a fourth instance
was sitting. The tree is now right and `R9_COPY_REVIEW.md` is not.

⚠ **The brief for this task named a third wrong value as the worst available outcome.** It did not
happen in the tree. It is still standing in the document, one screen away from the block that
corrects it. **For the driver: `R9_COPY_REVIEW.md` is the user's document, so I did not touch it.**

### (b) the invariant is stated two contradictory ways, 63 lines apart

| line | says |
|---|---|
| `:727` (NARROWED block) | *"So the invariant is **now true of every citation it claims to govern**"* |
| `:790` (IMPLEMENTED block) | *"So the invariant is true of **8 of the 18** citations a user can reach"* |

Under the narrowed rule the first is the current statement and the second describes the
pre-narrowing scope. Both read as present tense.

### (c) the heading the crew flagged — CONFIRMED as a real tension

`:763` *"TEN WERE NOT MOVED, AND THEY ARE REPORTED RATHER THAN TIDIED"*. "Reported rather than
tidied" is the pre-narrowing framing; they are now **out of scope**, which is a different claim,
and the `✅ NARROWED` block above says so.

### (d) lower severity, listed for completeness

* `:697-699` — *"A site already sitting mid-sentence is the rule's **first violation** and is **in
  scope**"*. Inside the quoted original ruling, so defensible as history, but nothing marks it
  superseded.
* `:4279` *"§A11 says **sentence**-final"* and `src/ase.tcl:29635` *"Sentence-final means the
  sentence it belongs to"* — both state the term without the bracket qualifier. Still true *of
  bracketed citations*, so not wrong, but they are statements of the rule the narrowing did not
  reach.
* **Pre-existing, not this task's**: `test_ase_core.tcl:7097` and `src/ase.tcl:29611` say every one
  of the 247 rows carries a `site` **file:line**. Measured: **20 rows carry a bare filename**
  (`acct`/`list`/`node`/`nomod`/`nopage`/`opts` → `cktsopt.c`, 13 more → `options.c`) and
  `nosavecurrents` carries `none`. 227 of 247 are `file:line` shaped. Untouched by this pass.

Everything else is consistent: `PLAN.md`, `DECISIONS.md`, `README.md` and `CREW_BRIEF.md` mention
`A11` nowhere, so there is no fourth statement of the rule to drift.

---

## What I could not assert, and what I tried first

Nothing in receipt 58 turned out to be unassertable. The one place the crew **under**-claimed is
covered above (§5): its "18" is sounder than it said, because the key census reaches it without any
composer at all — while its *independence* claim for `census.tcl` is looser than it said. I built
the cover for the first and refuted the second with the same probe.

## Debts to report upward — nothing filed or cleared by me

* **`rule`** — unchanged and carried forward from receipts 57, 57b and 58: the four rendered
  citations with **no `R9-` handle** (`niiter.c:38-39`, `cktsopt.c:111-113`,
  `subckt.c:592`/`inp.c:2689`, `inpgmod.c:268`/`inpcom.c:990`/`inp.c:2828`), plus the **`d_cosim`
  `spice_netlist.c:143-169`** site.
* **`rule`** — whether §A11's subject extends to **xschem's own source**, which decides `d_cosim`.
  I agree with receipt 58 that the narrowing **sharpens** this rather than resolving it: `d_cosim`
  is bracketed and mid-sentence, so unlike the ten it would fall **inside** the narrowed rule the
  moment the subject widened. Live, not dormant.
* **No `look` debt** — nothing in this pass reaches a screen.
* **For the driver, not a ledger debt:** `R9_COPY_REVIEW.md:5914`'s stale **17** (§10a above).
  It is the user's document; I did not edit it.
