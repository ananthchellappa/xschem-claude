# 61b — ADVERSARIAL VERIFICATION of issue 1475 and the `PLAN.md` Stage 14 hunk

**Verifier, read-only.** I did not write the work below and set out to break it. **One file written:
this one.** No `git` write command, no build, no suite, **no ngspice of any kind**, nothing touched
under `src/`, `tests/`, `~/.xschem/` or `~/.claude/xschem_owed/`.

**Under verification**

| artefact | state |
|---|---|
| `doc/claude/issues/1475-pss-declared-everywhere-working-nowhere.md` | untracked, **282 lines** (`wc -l` — matches the crew's claim) |
| `doc/claude/ase_analyses_batch/PLAN.md` | **one hunk**, `@@ -3746,9 +3749,44 @@`, **+38 / −3**, file now **4636** lines (all four figures re-measured, all four match the crew's receipt) |

**Sources of truth used, and nothing else for measurements:** `evidence/pss-two-binaries.md`
**[2BIN]**, `evidence/pss-stage14.md` **[ARGC]**. For copy: `src/ase.tcl` and
`R9_COPY_REVIEW.md`. For provenance claims: `DECISIONS.md`. **No git history was consulted for
the commit table** — it was checked against [2BIN] only, as instructed.

---

## VERDICT TABLE

### A — the headline count (brief item 1)

| # | claim | verdict | checked against |
|---|---|---|---|
| A1 | *"Twenty 45.2 runs"* | **CONFIRMED** | [2BIN] main table has **24 rows**; 45.2 is `skipped` on exactly **4** (`harmonics 1`, `harmonics 0`, `steady_coeff 1e-6`, `eprvcd`). 24 − 4 = **20**. Counted row by row, not inferred |
| A2 | the breakdown **15 / 2 / 3 / 0** | **CONFIRMED** | I recounted the 45.2 verdict column independently: `not reached` on base, fguess 1G, fguess 200meg, fguess 8G, stabtime 0, points 8, points 2, points 0, harmonics 2, sc_iter 5, sc_iter 1, sc_iter 0, steady_coeff 1e-9, oscnode, no-uic = **15**. 15+2+3+0 = 20 ✓ |
| A3 | the two rc-1 aborts are *"the Van der Pol example; the five-argument card"* | **CONFIRMED** | [2BIN] rows 2 and 3: `Van der Pol, its own args` 45.2 rc **1**; `5 args 2G 10n bout 1024 10` 45.2 rc **1** |
| A4 | the three timeouts are *"`fguess 0` at 60 s, `sc_iter` 1023 and 1024 at 90 s"* | **CONFIRMED** | [2BIN]: `fguess 0` → ⚠ **124 at 60 s**; `sc_iter 1023` and `1024` → ⚠ **124 at 90 s** each. Exact |
| A5 | **zero** `Convergence reached` on 45.2 | **CONFIRMED** | no 45.2 cell in [2BIN] reads `reached`. Every one of the 15 verdict-bearing rows reads `not reached` |
| A6 | the crew receipt's *"only **fifteen** of the twenty produced a verdict"* | **CONFIRMED** | same count as A2. Both statements — "twenty runs, zero convergences" and "fifteen produced a verdict" — are **true as written**, and they are not in tension |
| A7 | **could the wording mislead on the denominator?** | **CONFIRMED — no** | §1 says *"Twenty 45.2 runs, **zero** `Convergence reached`"* and then puts the 15/2/3/0 split **directly beneath it, with `converged 0` as its own bold row**. A reader cannot take fifteen for the denominator: the table sums to twenty on the page. This is better than the evidence file, which states the headline as prose only |
| A8 | *"not on … `ring_osc_pss_ctrl.cir` … and not on any of **nineteen perturbations of it**"* | **PARTLY** | The decomposition does not survive counting. Of the twenty, one is the ring base and one is the **Van der Pol deck — a second shipped example, not a perturbation of the ring**; the remaining **18** are ring perturbations. So it is 1 + 1 + 18, not 1 + 19. ⚠ **Transcribed verbatim from [2BIN] line 16-18, so the issue is faithful and the evidence is the origin** — and the issue itself names Van der Pol as *"the second shipped example"* three sentences later, so it contradicts its own decomposition in the same section. Headline unaffected: the **twenty** and the **zero** are exact |

### B — the ~2.6 % figure (brief item 2)

| # | claim | verdict | checked against |
|---|---|---|---|
| B1 | *"about 2.6 % high"* | **CONFIRMED** | `3857280067 / 3.758894068e9 − 1 = 0.0261741877…` → **2.62 %** to three significant figures. *"About 2.6 %"* is honest: it rounds **toward the defendant** by 0.017 pp, i.e. it understates rather than inflates. `NUMBERING.md` and the `PLAN.md` block both say 2.6 % — consistent everywhere |
| B2 | 2.6 % is offered in §2 as **the** size of the silent wrong answer | **PARTLY — UNDER-CLAIM, and it is the most serious thing in this verification** | See *Under-claims* below. 2.6 % is the **base case only**. [2BIN]'s own table has 45.2 returning **`7999996571`** (fguess 8G) — **113 % high** — and **`7714556828`** (points 2) — **105 % high** — both at **rc 0 with both plots full**. §2 never says the error is unbounded |

### C — the upstream commit table (brief item 3), against [2BIN] only

| # | field | verdict |
|---|---|---|
| C1 | `8351188e6` / **2025-12-15** / *PSS: new breakpoint deletion, copied from dctran.c: no more endless loop. … PSSDEBUG flag added* | **CONFIRMED** — hash, date and subject character-identical to [2BIN] |
| C2 | `a2a22c0ce` / **2026-04-11** / *Improve PSS error messages* | **CONFIRMED** |
| C3 | `668329ca3` / **2026-04-20** / *PSS updates: Remove 1e6 factor … this will re-enable convergence* | **CONFIRMED** |
| C4 | `4614452f1` / **2026-04-21** / *Info message to stdout, not stderr* | **CONFIRMED** |
| C5 | `35b487108` / **2026-04-24** / *Use stderr or stdout adequately* | **CONFIRMED** |
| C6 | `5333bf658` / **2026-04-28** / *Use updated eng() to print frequency …* | **CONFIRMED** |
| C7 | the range and path set — `git log ngspice-45.2..ccebdf2a2` over `src/spicelib/analysis/{dcpss,pssinit,psssetp}.c` | **CONFIRMED** — identical, including the brace expansion |
| C8 | the *"in a release tag?"* column reading **no** six times | **CONFIRMED** — [2BIN]: *"`git tag --contains` is empty for every one of them"* |

**Six hashes, six dates, six subjects: not one character differs.** I did not run git, by instruction.

### D — the "in no release tag" claim (brief item 4)

| # | claim | verdict | checked against |
|---|---|---|---|
| D1 | *"`git tag --contains` is empty for every one of them"* | **CONFIRMED** | [2BIN] line 44, verbatim |
| D2 | `668329ca3` is *"an ancestor of **neither** `ngspice-46` (2026-03-29) **nor** `ngspice-45.2`"* | **CONFIRMED — and no stronger than the evidence** | [2BIN]: *"is **not** an ancestor of `ngspice-46` (2026-03-29) or `ngspice-45.2`"*. Same proposition, same date, same two tags. The issue adds no tag the evidence does not name |
| D3 | *"It **is** an ancestor of the fork's `ccebdf2a2` and of the stock-47 build's `c5cd68015`, but that stock build was a bare `configure` and has no PSS at all"* | **CONFIRMED** | [2BIN] lines 45-47, same two hashes, same caveat |
| D4 | *"every released ngspice that has PSS has the non-converging one"* | **CONFIRMED (note)** | [2BIN]: *"every released ngspice that has PSS … has PSS that does not converge **on its own example**"*. The issue drops the four-word qualifier. It is the same ancestry argument and I do not think a reader is misled, but the evidence's sentence is the more precise one and it was available at zero cost |

### E — the four-argument SIGSEGV (brief item 5), against [ARGC]

| # | claim | verdict |
|---|---|---|
| E1 | `pss 1meg 1m out 1024` (**4 args**) → **rc 139 on both binaries** | **CONFIRMED** — [ARGC] table row 1, both cells **rc 139** |
| E2 | *"printing only `Error: Strange behavior` first"* | **CONFIRMED** — [ARGC] line 30-31, verbatim |
| E3 | *"Five arguments or more survive"* | **CONFIRMED** — rows 5/6/7/8 args, `SURVIVED` **yes** on all four |
| E4 | the reproduced 5-row table (`rc 0`, `rc 0`/`rc 1`, `rc 0`, `rc 0`) | **CONFIRMED** — every cell matches [ARGC], including the fork's lone **rc 1** at six arguments |
| E5 | *"the one binary-to-binary difference at six arguments is the **analysis** aborting, not the process dying — `SURVIVED` printed on both"* | **CONFIRMED** — [ARGC] line 33-34 |
| E6 | the class comparison (starved `noise`/`tf`/`sens`; `pz`; `sp` with no port; no `$sim_status`, no guard, no `remzerovec`, no salvage; 1433's checkpoints run *in the deck*; `op` kept LAST by 0964) | **CONFIRMED** — [ARGC] §"Why this matters", all four named classes and all three bullets present with the same wording |
| E7 | the attribution paragraph (first probe ran three commands in one deck, read rc 139 as *"`pss` is broken"*; the real defect is **input validation on a short argument list**) | **CONFIRMED** — [ARGC] closing ⚠, faithfully compressed |

### F — the `oscnode` two-sentence finding (brief item 6)

| # | claim | verdict | checked against |
|---|---|---|---|
| F1 | the **0.46 %** figure | **CONFIRMED** | `3.7415e9` vs `3.7589e9` → **0.4629 %** against the larger, **0.4651 %** against the smaller. Either way **0.46 %** to two significant figures. Cross-check on [2BIN]'s own full-precision table cells (`3.741491780e9` vs `3.758894068e9`) gives **0.4630 %** — same answer |
| F2 | *"real nodes steer nothing"* (`bout`, `inv1`, `inv2` identical; `dcpss.c:126` assigns `oscnNode` and never reads it) | **CONFIRMED** | [2BIN] point 4, verbatim including the file:line |
| F3 | *"a name that is not a node **moves the answer**, because the parser inserts a new floating node"* | **CONFIRMED** | [2BIN] point 4, verbatim |
| F4 | **does the issue state only the first half anywhere?** | **CONFIRMED — no, in all three places** | Three occurrences, checked individually: the §6 **heading** (*"the finding is two sentences, and the first alone is misleading"*); the §6 **blockquote**, which carries both halves in one sentence joined by **but**; and the **closing table**, where the first half appears only as a *quotation of the stale `PLAN.md`* with the refutation in the adjacent cell. There is no bare half-statement in the file. ⚠ This is the one place the issue is **better** than its brief required |

### G — §9, what the user sees today (brief item 7) — the character-by-character pass

| # | claim | verdict | checked against |
|---|---|---|---|
| G1 | the citation **`src/ase.tcl:27342-27344`** | **CONFIRMED — exact** | `grep -n`: `pss [dict create \` is **27342**, `label pss  baseline 0  registered 1 \` is **27343**, `emit {{role probe tmpl {pss}}}]]` is **27344** |
| G2 | `label pss  baseline 0  registered 1` | **CONFIRMED — character-exact**, including the **two** spaces between each pair |
| G3 | `emit {{role probe tmpl {pss}}}` — *"a **probe-only** `emit` card"* | **CONFIRMED** | role is `probe`, not `analysis`. Compare the `sp` entry two lines above, which is `role analysis` |
| G4 | *"**no `fields` key**"* | **CONFIRMED** | the entry has exactly four keys: `label`, `baseline`, `registered`, `emit`. `sp` immediately above has `fields`, `results` and `plots`; `pss` has none of them |
| G5 | the quoted code block's fidelity | **CONFIRMED (note)** | Two cosmetic departures: the block is re-indented (6/8 spaces → 0/2) and the trailing `]]` is shown as `]`. The second bracket closes the **enclosing** `dict create`, not the `pss` entry, so trimming it arguably makes the quote more correct as a quote of *the entry*. No token, no key and no value differs |
| G6 | the grid cell is **`blocked`/`unrenderable`** | **CONFIRMED** | `ase::analysis_state` (`src/ase.tcl:10450`): `if {![ase::analysis_renderable …]} { return {state blocked reason unrenderable} }`, and the comment above it records *"four `ok/baseline` and seven `blocked/unrenderable`"* |
| G7 | **RATIFIED STRING 1** — *"ASE-L cannot set up pss yet, so it is listed but cannot be enabled."* | **CONFIRMED — CHARACTER-EXACT** | `ase::analysis_state_msg`, `unrenderable` arm, `src/ase.tcl:10512`: `return "ASE-L cannot set up $lbl yet, so it is listed but\` / ` cannot be enabled."`. Resolving the Tcl continuation (backslash + one leading space = one space) and `$lbl` = the entry's `label`, which is **`pss`**, gives the quoted sentence exactly. Case checked: **ASE-L** capitalised, sentence-final full stop present, no Oxford-comma or hyphen drift |
| G8 | **RATIFIED STRING 2** — *"This pss analysis is not one this simulator can set up."* | **CONFIRMED — CHARACTER-EXACT, and it is the post-§A6 literal, not the pre-§A6 one** | Composed from two procs, both read: `ase::analysis_refusal_frames` (`:5509-5512`) returns `status "This $type analysis $clause."`; `ase::analysis_emit_msg` (`:5474`, `unrenderable` arm at **`:5480`**) returns `is not one this simulator can set up`. Substituting `$type` = `pss` yields the quote **exactly**. ⚠ **The trap here is real and the crew did not fall into it**: the string says `this simulator`, **not** `this simulator backend` — §A6 changed it on 2026-09-16 and an issue written from the R9 document's ```text``` block instead of from the source would have shipped the dead wording |
| G9 | that string is ratified under ⚖ R9 as **`R9-065`** *(the dialog status line)* | **CONFIRMED** | `R9_COPY_REVIEW.md:1863` **R9-065** · refusal; *Where:* *"Choose Analyses dialog → **status line** (and the action log)"*. ⚠ The issue's parenthetical omits *"(and the action log)"* — an abbreviation, not an error |
| G10 | …and **`R9-160`** *(the Arguments column)* | **CONFIRMED** | `R9_COPY_REVIEW.md:3208` **R9-160** · refusal; *Where:* *"Analyses pane, **Arguments column** cell — an ENABLED row whose analysis type the backend cannot emit (**today `sp` and `pss`**, which are probe-only)"* — the entry names `pss` itself |
| G11 | *"**one literal behind both**"* | **CONFIRMED** | `R9-065`'s note: *"⚠ **One literal, two handles**: this clause and `R9-160` … are the *same* `ase::analysis_emit_msg` return, so the single edit moved both."* `R9-160`'s note says the same from the other side. Independently true in the source: one `switch` arm, two callers |
| G12 | the quoted sentence matches **R9-065's own rendering** | **CONFIRMED — character-exact** | `R9-065`'s note spells the framed result out: *"the framed sentence is now **"This pss analysis is not one this simulator can set up."**"* — the issue's quote is byte-for-byte this, `pss` included |
| G13 | *"it is **not being changed** by this ruling. Nothing in `src/` moves for issue 1475" * | **CONFIRMED** | no `src/` file is modified in this tree (`git status` shows only `doc/claude/…` and untracked dirs), and `LEDGER.md:46` records the same fact measured the same way |

### H — the refusal thresholds (brief item 8), against [2BIN] point 3

| # | claim | verdict |
|---|---|---|
| H1 | *"`PLAN.md` §14 says refuse `steady_coeff < 1e-6` — so **1e-6 is allowed**"* | **CONFIRMED** — `PLAN.md:3808` is exactly that row: `| steady_coeff < 1e-6 | 1e-9 gave a **false** Convergence reached **4.5 % wrong** |` |
| H2 | *"`steady_coeff = 1e-6` **did not finish in 60 s** (rc 124)"* on the fork | **CONFIRMED** — [2BIN] table: `steady_coeff 1e-6 (the plan's minimum)` → fork ⚠ **124 at 60 s**; restated in [2BIN] point 3 in words |
| H3 | *"a `fguess` 19× low *'converged — fine'*, so bias the default low"* is the plan's claim | **CONFIRMED** — `PLAN.md:3805`: `| fguess biased **high** | 2.1× high aborts; 19× low converged. **Bias the default low.** |` |
| H4 | *"`fguess 200meg` (19× low) **did not converge** — `Convergence not reached`, one relaunch"* | **CONFIRMED** — [2BIN] table: fork ⚠ **not reached**, **rel 1**, *(scratch build: reached)*. The issue's *"one relaunch"* is `rel 1` rendered into words, correctly |
| H5 | the refusals the fork **does** confirm: `harmonics < 2`, `fguess <= 0`, `steady_coeff` far below `5e-3` | **CONFIRMED** — [2BIN] point 3 lists exactly these three, in this order |
| H6 | *"1e-9 gives a **false** `Convergence reached` **4.5 % wrong**"* | **CONFIRMED** — [2BIN] table cell says *"reached … **false**, 4.5 % high"*. Arithmetic check on its own numbers: `3.929556013e9 / 3.758894068e9 − 1` = **4.54 %** ✓ |
| H7 | *"`harmonics 1` and `harmonics 0` both print `Convergence reached` **and then** hang (rc 124 at 10 s) or segfault (rc 139)"* | **CONFIRMED** — [2BIN] table: *"reached — printed BEFORE the hang"* / *"BEFORE the crash"*, with ⚠ **124 at 10 s** and ⚠ **139** |
| H8 | *"Treat the whole threshold table as a floor measured on one binary, not a validated range"* | **CONFIRMED** — [2BIN] point 3's closing clause, near-verbatim |

### I — the `PLAN.md` Stage 14 hunk (brief item 9)

| # | question | verdict | evidence |
|---|---|---|---|
| I1 | does the not-built block follow the plan's convention for withdrawn content? | **CONFIRMED** | The plan's precedent is `PLAN.md:4442`, the withdrawn `-b` refusal: **struck-through original** + ⚠ bold *"THIS REFUSAL IS WITHDRAWN — it was wrong"* + the old text retained + an explicit reason (*"kept visible rather than deleted, because the withdrawn sentence is quoted elsewhere in the batch"*). The Stage 14 block reproduces all four moves, and **names the precedent** (*"the same treatment the withdrawn `-b` refusal gets in *What this plan refuses*, and for the same reason"*). A second precedent at `:3228` (`~~and a Smith chart~~`) uses the same strikethrough idiom |
| I2 | does the stage body survive intact below it? | **CONFIRMED** | The diff deletes **exactly 3 lines** — the heading, a blank, and `**One commit. Ruling ⚖ R7. Last, deliberately.**` — and the third is re-added struck-through at the block's foot. From `:3787` to the Stage 15 heading at `:3859` the body is untouched: the APPENDIX pointer, the measured paragraph, the six-row refusal table, the three behaviours, *What you see*, *Files and procs*, *Suites that move*, *Re-measure on the dev display*, *Rulings in this stage*. **Nothing was deleted, per the brief** |
| I3 | does the block contradict anything in the retained body? | **CONFIRMED — no contradiction** | Everything the block calls false is flagged *as* the body's claim, not asserted against it, and the block's opening sentence quarantines the whole region (*"NOTHING BELOW THIS BLOCK WAS IMPLEMENTED"*) |
| I4 | the block's *"**Three** of its claims are now known FALSE … and issue 1475's last section names them"* | **PARTLY** | 1475's last section is a **four**-row table. The fourth row (*"a 3-stage ring in 0.91 s … both `Convergence reached`" is the **scratch build***) is named there and **not** in the plan's block, so *"names them"* points at a list one item longer than the count preceding it. Defensible reading — the fourth is *stale provenance* rather than a false claim — but the two documents put different numbers on the same pointer, and a reader who counts will notice |
| I5 | the block's cross-references: *"the ruling ledger's **R7** row and the sequencing table's row **15**"* | **CONFIRMED** | `PLAN.md:4228` is the R7 ruling-ledger row, still reading *"**Yes, last, explicitly experimental**"*; `PLAN.md:4518` is `| 15 | **14** | PSS, experimental, hard validator, stdout verdict | +300 | **R7** | new suite |`. Both exist, both still say *ship it*, and the block correctly warns a reader who meets either first |
| I6 | *"+38 / −3"*, *"file now 4636"*, *"one hunk"*, *"282 lines"* | **CONFIRMED** | `git diff --stat`: `38 insertions(+), 3 deletions(-)`; `wc -l`: 4636 and 282; one `@@` header. All four re-measured |

### J — claims supported by neither evidence file nor the source (brief item 10)

**My list, built independently. I did not start from the crew's §1.**

| # | claim | verdict | finding |
|---|---|---|---|
| J1 | §1: *"`pss` is `#ifdef`-gated behind **`WITH_PSS`**, and both binaries … answer `help pss` … **[2BIN]**"* | **REFUTED (the tag, not the fact)** | ⚠ **`WITH_PSS` appears nowhere in either evidence file.** I grepped both: [2BIN] says `--enable-pss` only; [ARGC] does not mention the gate at all. The macro name is true and traceable — `APPENDIX_ngspice_analyses.md:68/98/135`, `CREW_BRIEF.md:570`, `evidence/dotcards.md:1442`, `evidence/ase-deck.md:666` — but **none of those is a source this file is allowed to cite under [2BIN]**, and the sentence carries a [2BIN] tag covering both clauses. The second clause *is* [2BIN] (line 12, verbatim). **This is the only outright refutation in the pass, and it is a mis-tag of a true fact.** The crew's own unsourced list does **not** contain it |
| J2 | §9 in its entirety | **CONFIRMED as declared** | Opens *"⚠ Not from the evidence files — read from `src/ase.tcl`"*. Every claim under it verified in G1–G13. Matches the crew's (a) |
| J3 | §11 in its entirety | **CONFIRMED as declared** | Opens *"⚠ Not from the evidence files — this is the batch's ruling record and the user's own words."* I checked it against `DECISIONS.md:1360-1420` anyway: *"Option A, ship it, explicitly experimental"* ✓ verbatim; *"follow your recommendation"* ✓ verbatim; the four parts (**last** / **experimental** / **transient+FFT beside the answer** / **the `oscnode` sentence**) ✓ verbatim and in the same order; *"don't build it, write up the issue"* ✓ verbatim; *"I have never run PSS"* ✓ verbatim; *"carries the reversal at its head and keeps the 2026-09-13 answer in full beneath it"* ✓ — the divider is literally `#### ⬇ THE SUPERSEDED 2026-09-13 RULING, KEPT IN FULL`. Matches the crew's (b), and the crew's ⚠ that the user's two 2026-09-16 sentences rest on the driver's report alone is **correct and correctly flagged** |
| J4 | the 15/2/3/0 breakdown and *"about 2.6 %"* as derivations | **CONFIRMED as declared** | Both are the crew's arithmetic over [2BIN]; both re-derived above (A2, B1) and both correct. Matches the crew's (c) |
| J5 | *"the silent-wrong-answer class"*, §8's *"everyone or nobody"*, §10's reopening condition, §11's closing lesson | **CONFIRMED as framing** | All four are editorial; §10 explicitly labels itself *"a recommendation of this file, not a measurement"* and tags the fact underneath as [2BIN]. Matches the crew's (d) |
| J6 | §3's *"`PLAN.md` §14 and `APPENDIX` §2.12 **both** say scrape stdout"* | **CONFIRMED** | I read both rather than relaying: `PLAN.md:3813` *"The panel scrapes stdout for the verdict string."*; `APPENDIX_ngspice_analyses.md:1345` *"**A GUI must scrape stdout for these and must refuse to present a PSS result without one.**"* Matches the crew's (e) |
| J7 | the closing table's *"(`PLAN.md` §14, **twice**)"* attached to the quoted sentence | **PARTLY** | The quoted literal *"The panel scrapes **stdout** for the verdict string"* occurs **once** (`:3813`). The second stdout-scrape claim in §14 is differently worded — *Files and procs*: *"scrapes **ngspice's own stdout strings**"*. So *"§14 says it twice"* is true of the **claim** and false of the **quotation** the parenthetical is attached to |
| J8 | §12's preserved findings — plot literals, typenames, `pss3`/`pss4` after relaunch, `eprvcd` safe on the fork, **158 timestamps**, 45.2 not run by the standing rule | **CONFIRMED** | [2BIN] lines 84-86 and point 5 plus the `eprvcd` table row (*"VCD valid, 158 timestamps"*) and the Hygiene block (*"45.2 not run, by the rule against crashing the user's simulator"*). Every figure exact |
| J9 | §3's `builds.md` §1.7 cross-reference (*the `Shooting cycle iteration number:` line that was recorded as never printing does print on 45.2*) | **CONFIRMED** | [2BIN] lines 49-51, verbatim including the `|| rr: … || predsum: …` fragment. Sourced to [2BIN] rather than to `builds.md`, which is correct — [2BIN] is the file that measured it |
| J10 | the closing note that `APPENDIX` §2.12's gate row is stale and deliberately left | **CONFIRMED** | `APPENDIX_ngspice_analyses.md:1307` still reads *"**Absent in this build**; present in `/usr/bin/ngspice` 45.2"*, and `:283` records the 2026-09-10 `--enable-pss` rebuild that outdates it. The issue quotes the row correctly and says why it is left |

**Where my list differs from the crew's §1:** the crew found **nine** claim-groups; I agree with all
nine, and add **one they missed — J1, `WITH_PSS` tagged [2BIN]**. The crew's §1 opens with *"every
factual claim traced to one of the two evidence files, named inline"* and J1 is the counter-example.
I found nothing in their list that does not belong there.

---

## COUNT

| verdict | n |
|---|---|
| **CONFIRMED** | **44** |
| **PARTLY** | **4** (A8, B2, I4, J7) |
| **REFUTED** | **1** (J1) |
| total rows | **49** |

---

## UNDER-CLAIMS — where the issue is weaker than the evidence permits

**1. ⚠ THE SILENT WRONG ANSWER IS NOT BOUNDED AT 2.6 %, AND §2 LEAVES THE WORST CASE ON THE FLOOR.**
This is the most serious thing in this verification. §2 builds the whole *"silent-wrong-answer
class"* argument on one number — the base case's **2.6 %** — and a reader costing a future fix would
take that as the size of the problem. [2BIN]'s own table says otherwise, in cells the issue quotes
from elsewhere:

| [2BIN] case | 45.2 | true f0 (fork) | error | rc | plots |
|---|---|---|---|---|---|
| base | `3857280067` | `3.758894068e9` | **+2.6 %** | 0 | both full |
| `points 2` | `7714556828` | `3.758894068e9` | **+105 %** | 0 | both full |
| `fguess 8G` (2.1× high) | `7999996571` | — (**fork aborts, rc 1**) | **+113 %** vs base f0 | ⚠ **0** | *"not reached, both plots"* |

The `fguess 8G` row is the sharpest sentence available and the issue never writes it: **the fork
refuses the input outright (rc 1, `Error: Strange behavior`) exactly where 45.2 returns rc 0, both
plots full, and a fundamental frequency that is simply the user's own guess handed back.** That is
the same failure class §2 names, two orders of magnitude worse, and it makes the *"a user … has no
way to know it is not one"* argument far harder to wave through. **Recommend one sentence and the
three-row table above be added to §2.**

**2. §1's timeout row drops the contrast that makes it damning.** The issue records *"ran past the
timeout"*; [2BIN] point 4 records that 45.2 timed out *"on three inputs **the fork answers in under
a second**"* — `fguess 0` is a clean rc-1 abort in **0.11 s** on the fork, `sc_iter 1023`/`1024`
converge at iteration 3 in **0.71 s**. Those three fork timings appear nowhere in 1475 and are the
difference between *"slow"* and *"wedged on inputs that are not hard"*.

**3. §2 attributes the false-convergence failure to 45.2 alone.** [2BIN] shows **the fork** producing
a **false `Convergence reached` 4.5 % wrong** at `steady_coeff 1e-9`. The issue has the fact (§7) but
never connects it to §2's class, so the file reads as *"the released binary is the dangerous one"*
when the evidence says the silent-wrong-answer shape reaches the good build too, via a value the
plan's own table allows.

---

## INTERNAL CONTRADICTIONS between 1475, the `PLAN.md` block and receipt 61

**One, and it is minor: the three-versus-four count (I4).** The plan's block says *"Three of its
claims are now known FALSE … and issue 1475's last section names them"*; that section is a four-row
table. Receipt 61 §2 then says **seven**, over a wider scope (`PLAN.md` + `APPENDIX` + `DECISIONS.md`)
and correctly explains the widening. Three numbers, three scopes, one un-signposted pointer.

**Nothing else.** I checked the crew's receipt against the artefacts it describes and every
self-report holds: the diff stat, the line counts, the single hunk, the two `PLAN.md` rows it
declined to touch (`:4228`, `:4518` — both verified present and both still reading *ship it*), and
its claim to have touched nothing else. `LEDGER.md:44/46/47/48/51`, `DECISIONS.md:1360`, `:619`,
`:1379` and `NUMBERING.md:3449-3455` were all written by the driver and all agree with 1475 on the
ruling, the date, the issue number, the *"twenty cases, zero convergences"* headline and the
*"~2.6 %"* figure. `LEDGER.md:46` independently records that T1 was **not** re-run and states the
measured basis (`git diff --name-only HEAD` finds nothing outside `doc/claude/`) — which I
confirmed from `git status`: no file under `src/` or `tests/` is modified.

---

## THE SINGLE MOST SERIOUS THING

**The under-claim in §2.** Everything the issue asserts is true — forty-four rows confirmed, six
commit hashes and six dates character-perfect, two ratified strings character-perfect **including
the `this simulator` / `this simulator backend` trap that §A6 sprang the same day** — but the issue
argues its central point, the silent-wrong-answer class, at **2.6 %** when its own cited evidence
file contains a **113 %** error at rc 0 with both plots full, on an input the *good* binary refuses
outright. The defect is not a false claim; it is that the strongest available evidence for the
issue's own thesis is sitting unquoted in the file it cites.

**And to say it plainly, because an adversarial pass that finds nothing should say so rather than
manufacture something:** the arithmetic all checks, the counts all check, the hashes all check, the
ratified copy is exact to the character, the plan's hunk follows the plan's own convention for
withdrawn content, and the stage body survives intact. The one REFUTED row is a **[2BIN]** tag
covering a true fact that lives in a third file. This is accurate work.

---

## HYGIENE

* **One file written: this one.** No edit to the issue, the plan, the ledger, `DECISIONS.md`,
  `NUMBERING.md`, `R9_COPY_REVIEW.md` or anything under `src/`.
* **No ngspice, no simulation, no build, no test suite, no `tclsh`.** No process started, so none to
  reap. Every measurement above is arithmetic over text already on disk.
* **No `git` write command.** `git diff`, `git diff --stat` and `git status` only — read-only, and
  **no `git log`, `git tag` or `git merge-base` at all**: the commit table was checked against
  [2BIN] exclusively, as instructed.
* **`~/.xschem/` and `~/.claude/xschem_owed/` neither read nor written.** No `owed.sh`. Nothing
  filed and nothing cleared.
* **Nothing written to `/tmp`.**
