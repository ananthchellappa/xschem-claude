# ⚖ R9 A11 NARROWED — the rule now governs the bracket, and the twice-wrong pair is right

**One task from the driver: restate §A11's placement rule in its narrowed form where the tree
states it, correct the two numbers that were never propagated, and prove the ratchet survives.**
Files touched, and nothing else: `src/ase.tcl`, `tests/headless/test_ase_core.tcl`, and this
receipt.

HEAD was `15486b86` at hand-over and is `15486b86` now. **No commit, no `git add`, no
stash/restore/checkout/clean/push.** `tests/run_regression.tcl` **NOT run** — the driver's, solo
(issue 0990). **Nothing was filed or cleared in the owed ledger**; debts are reported upward at the
end of this receipt, for the driver to file after a backup (issue 1400).

⚠ **`doc/claude/ase_analyses_batch/LEDGER.md` went modified DURING this task and is not mine.** My
opening `git status` carried only `R9_COPY_REVIEW.md` as modified; the ledger joined it mid-pass.
That is the driver collecting, and I never opened either file — both are md5-identical at my start
and at my end (`R9_COPY_REVIEW.md` `3382d977…`, unchanged throughout; `src/ase_window.tcl`
`559421793…`, untouched).

`~/.xschem/recent_files` is **untouched at 2026-09-13 18:53:01.297381420** (issue 0924 canary),
checked at the start and at the end. **`/usr/bin/ngspice` was never invoked**, no simulation was
run, no deck was written under `sky130A/`, and `ps -eo comm=` showed **zero `ngspice`** at every
check (`Xvfb` ×1, `openbox` ×1, `xschem` ×2, all predating this pass). Binary always by path,
always `--nolog`, never `--logdir`, never a bare `xschem`.

**104 of 104** tracked `.state` files round-trip byte-identically — `tracked 104`, `bad {}`,
**`control_disagrees 1`, `control_agrees 1`** — driven as the **proc** (`ase_state_roundtrip`),
never by running `state_roundtrip.tcl` as a script. Measured before the change, and again on the
restored tree as it hands over.

---

## ⚠ THE HEADLINE: THE NARROWING IS WORDING-ONLY, AND THE DIFF PROVES IT RATHER THAN ASSERTING IT

The driver's instruction was to stop and report if the narrowing turned out **not** to be
wording-only. It is wording-only, and the evidence is a counted diff partitioned by whether a
changed line is a comment:

| file | counted diff | **of which NON-COMMENT** |
|---|---|---|
| `src/ase.tcl` | **−14 / +23** | **−0 / +0** |
| `tests/headless/test_ase_core.tcl` | **−29 / +66** | **−3 / +3** |

**The entire non-comment change in the tree is three lines, and they are the `check` DESCRIPTION
string — not an assertion:**

```
was:  check "LB14 a rendered citation of the simulator's source is parenthesised and\
       sentence-final, the ten that are not are pinned by name so an eleventh reds,\
       and the classifier can tell the two apart" \
now:  check "LB14 a bracketed citation of the simulator's source closes the sentence,\
       the ten the rule does not govern are pinned by name so an eleventh reds, and\
       the classifier can tell the two apart" \
```

**Not one character of `lb14cite`, of `lb14bits`, or of either expected-value list moved.** The
asserted partition is byte-identical:

```
END : acct list node nomod nopage oldlimit opts
MID : debug defas itl1 itl2 itl4 klu_memgrow_factor newtrunc scale wnflag x11lineararcs
      plus END MID END {} for the kind and the three hand-made strings
```

**Why it could only be wording.** `lb14cite` classifies by **mechanism** — END for a citation
inside a bracket group whose `)` ends the sentence, MID for anything else. It never encoded the
old English *"always parenthesised, always sentence-final"*, so narrowing that English to *"where
ASE-L cites the simulator's source in a bracket, the bracket closes the sentence"* leaves it
nothing to change. What changed is the **status** of the ten: they were described as violations
the crew declined to tidy, and they are now **out of the rule's scope**. Both descriptions produce
the same MID list, which is why the ratchet is untouched — and I proved that by sabotage rather
than by argument (arms A1 and A2 below).

`test_ase_core` reads **ALL PASS (675)** on both arms before the change and **ALL PASS (675)** on
both arms after it.

---

## The two corrected numbers, and how I re-derived each

The driver required both to be measured independently and the disagreement reported rather than
written. **Both reproduce.** This pair has now been wrong twice, so each derivation is stated in
full.

### 393 — what a source grep answers

```
grep -oE '[A-Za-z0-9_/]+\.c:[0-9][0-9-]*' src/ase.tcl | wc -l   ->  393
```

That is `lb14cite`'s **own** citation pattern, counted as **matches**, on the finished tree. Two
neighbouring numbers are the reason the old sentence was unreproducible, and the new comment now
names the pattern and the file so a later reader lands on the same one:

| form | answer |
|---|---|
| **matches** of `[A-Za-z0-9_/]+\.c:[0-9][0-9-]*` in `src/ase.tcl` | **393** ← the number written |
| **lines** carrying that pattern (`grep -c`) | 378 |
| matches of a bare `.c:` with **no digit required** | 394 |

⚠ **The old sentence said "a source grep for `.c:`" and gave 247.** 247 is neither: it is the
number of option **rows**, which is correct as a row count and was simply attached to the wrong
noun. I confirmed the row count too — `llength [ase::sim_option_names ngspice]` = **247**, and all
**247** carry a `site` key.

### 18 — what a user can actually see

Re-derived **by rendering**, and deliberately **not** by calling `lb14cite`/`lb14bits`, so the
classifier under test was not reused as its own witness. I wrote a separate probe that composes
what `ase::ui::optsheet_detail` composes (`help`, then one of `inert`/`owner`/`clamp`/
`defect`+`caveat` as `ase::opt_offer` selects, then `results_why`, `gate_why`, `leak_why`), walks
`ase::meas_kind_order` for the measurement catalogue's `unsupported`, and counts a bit as carrying
a citation if the regex matches it at all — no END/MID logic:

```
CENSUS option_rows        247      CENSUS rows_with_site_key 247
CENSUS option_bits         17      CENSUS option_occurrences  20
CENSUS kind_bits            1      CENSUS kind_occurrences     1   (deriv)
CENSUS TOTAL_BITS          18      CENSUS TOTAL_OCCURRENCES   21
CENSUS distinct_options    17 : acct debug defas itl1 itl2 itl4 klu_memgrow_factor list
                                newtrunc node nomod nopage oldlimit opts scale wnflag x11lineararcs
```

**18 bits, over 17 options and one kind, in 21 occurrences.** Measured on the pristine tree before
any edit and again on the finished tree; identical both times. It agrees with receipt 57b's
independent count and with the driver's correction, and it is arithmetically consistent with the
8 + 10 = 18 partition `LB14` itself asserts — which is the check the original "17 over 16" failed.

**Neither number is copied from the review document or from the task brief.** Had either
disagreed I was to report and write nothing; neither did.

---

## ⚠ A THIRD SITE CARRIED THE SAME WRONG PAIR, IN `src/ase.tcl` — FOUND, FIXED, AND DECLARED

The brief named two comment sites in `test_ase_core.tcl`. A grep for the numbers rather than for
the file found a **third**, in `src/ase.tcl`, immediately above `variable sim_options`. It carried
**both** defects at once — the un-narrowed rule *and* the twice-wrong pair:

```
was:  # ⚠ ⚖ R9 A11 -- WHERE ASE-L CITES THE SIMULATOR'S SOURCE, THE CITATION IS
      # PARENTHESISED AND SENTENCE-FINAL. ...
      # ... a grep for `.c:` counts 247 rows that a user can never see. ...
      # ... that is 17 bits carrying a citation, over 16 options and one kind.
```

⚠ **This is a scope decision I made, and the driver can revert exactly two hunks if it disagrees.**
`src/ase.tcl` is not named in my brief. I fixed it because leaving it meant the narrowing shipped
half-done and the wrong pair survived a third round in the very file the option catalogue lives
in — which the brief calls the batch's worst outcome here. The change is **comment-only**
(`−0 / +0` non-comment), the comment sits at **namespace level** between `proc option_fallback`'s
closing brace and `variable sim_options`, so **no `info body` test can see it** (`LB11` and
`LB15` term 8 read proc bodies), and **nothing in `tests/` greps its text** — both checked, not
assumed. `test_ase_options_1437` and `test_ase_optsheet_1441`, the two suites that read the option
catalogue, are `ALL PASS (75)` and `ALL PASS (64)`.

I also propagated one further correction that was already in the document and never reached the
tree: *"nothing reads it"* → ***"no user-visible reader"***, since `test_ase_options_1437` reads
`site` at four places (57b, Attack 3a). Same defect class as the numbers — a correction the review
document made and the tree never heard about.

---

## What now states the rule, in the tree's own idiom

Five sites, all comments except the fourth's description string:

| # | file | site | now says |
|---|---|---|---|
| 1 | `test_ase_core.tcl` | file-header note (§LB14 paragraph) | *"where ASE-L cites the simulator's source **IN A BRACKET**, the bracket closes the sentence"*, plus the narrowing, plus 393/18 |
| 2 | `test_ase_core.tcl` | `## LB14 --` banner | `A BRACKETED CITATION CLOSES THE SENTENCE` |
| 3 | `test_ase_core.tcl` | the quoted ruling + survey + TERM 2 block | the narrowed rule set out as a block quote, why it was narrowed, **that the narrowing is wording-only and how that was checked**, and 393/18 |
| 4 | `test_ase_core.tcl` | the `check` description | *"a bracketed citation … closes the sentence, the ten **the rule does not govern** are pinned by name so an eleventh reds"* |
| 5 | `src/ase.tcl` | the catalogue preamble (two hunks) | the narrowed rule, the narrowing, and 393/18 |

**The "TERM 2 IS THE RATCHET" paragraph survives, adjusted exactly as asked** — it no longer calls
the ten untidied violations, it calls them out-of-scope, and it now says *why* pinning an
out-of-scope set is what makes the ratchet work:

> ⚠ TERM 2 IS THE RATCHET AND IS WHY THIS IS NOT A NAME DIFF. It pins the ten OUT-OF-SCOPE sites
> by name — the subject-form and em-dash citations the narrowed rule does not govern. Pinning a set
> the rule says nothing about is precisely what makes the ratchet work: an ELEVENTH mid-sentence
> citation reds this row, and so does quietly rewording one of the ten into compliance.

The original absolute wording is **kept as a quotation** at two sites (*"It was first written
'always parenthesised, always sentence-final'"*), so a later reader can see what was narrowed and
does not re-derive the ten.

### The golden question — asked, and the answer is that there is no golden

The brief warned the `check` description may be part of a golden. **It is not.**
`tests/headless/gold/` holds six files (`cmos_example.spice`, `dlatch.spice`, `flop.spice`,
`nand2.spice`, `state.txt`, `tb_test_evaluated_param.spice`) and **none mentions `LB14` or the
rule**. The one file in the tree carrying the old description is
`tests/headless/test_ase_core.log`, which `git ls-files` reports as **not known to git** — an
untracked run artefact, not a baseline. **No golden was updated, and none needed to be**; nothing
was "fixed" by reverting the wording.

---

## Sabotage — four valid arms, one INVALID arm reported, every guard a COUNTED DIFF

Each arm: plant through an **exact-once needle or abort** (`plant.py` exits 2 on a needle that does
not occur exactly once, exit 3 on a no-op replacement) → **diff against the finished snapshot and
require exactly the intended changed-line count** → run → restore by plain `cp` → prove the restore
by `cmp`. ⚠ **No md5 was used as a sabotage guard**; md5 and `cmp` appear only to prove restores.

⚠ **The red-extractor was fed the EMPTY case FIRST, before any arm planted**, and it is a positive
assertion (*"I saw a `RESULT:` line and it said ALL PASS"*), never *"I did not see FAIL"*:

```
empty      -> DIED(empty log)          failnoline  -> DIED(FAILED but no FAIL: lines)
whitespace -> DIED(no RESULT line)     allpass     -> ALLPASS(1)
noresult   -> DIED(no RESULT line)     red         -> REDS[LB14]
missingfile-> DIED(empty log)
```

**It never answers `(none)`.**

| | arm | counted diff | declared blast radius | measured | verdict |
|---|---|---|---|---|---|
| **A1** | an **ELEVENTH** mid-sentence citation planted in `oldlimit`'s `help` (an option currently in the **END** set) | 1 | core `LB14` alone | **`REDS[LB14]`**, 1 FAIL row; options_1437 `ALLPASS(75)` | **exactly that** |
| **A2** | one of the ten pinned MID options (`x11lineararcs`) quietly **reworded into compliance** | 1 | core `LB14` alone | **`REDS[LB14]`**, 1 FAIL row; options_1437 `ALLPASS(75)` | **exactly that** |
| **A3a** | *intended* always-`END` classifier | 1 | core `LB14` alone | **`ALL PASS (675)` — reddened NOTHING** | ⚠ **INVALID — see below** |
| **A3b** | a string citing **nothing** made to answer `END` | 1 | core `LB14` alone | **`REDS[LB14]`**, 1 FAIL row | **exactly that** |
| **A3c** | the **true** always-`END` classifier (replaces A3a) | 1 | core `LB14` alone | **`REDS[LB14]`**, 1 FAIL row | **exactly that** |

**No arm reddened a row it was not aiming at.** Every arm restored `cmp`-identical, and the
campaign ends on positive restored-tree rows: `test_ase_core` **ALL PASS (675)** on **both** arms,
`md5sum -c` **OK** for both sources.

### The ratchet, shown rather than claimed — A1 and A2 are the two that matter

**A1 is the ratchet.** `oldlimit` moves out of END and into MID, so the MID set grows from ten to
eleven — the thing that will actually happen next, an author adding a citation without a bracket:

```
actual {{acct list node nomod nopage opts} {debug defas itl1 itl2 itl4 klu_memgrow_factor
         newtrunc oldlimit scale wnflag x11lineararcs} END MID END {}}
exp    {{acct list node nomod nopage oldlimit opts} {debug defas itl1 itl2 itl4
         klu_memgrow_factor newtrunc scale wnflag x11lineararcs} END MID END {}}
```

**A2 is the other half, and it is the one the narrowing could plausibly have broken.** Since the
ten are now *out of scope*, a reader might expect the row to stop caring what happens to them. It
does not: rewording `x11lineararcs` into a compliant bracketed form moves it MID → END and reds the
row on **both** lists at once.

```
actual {{acct list node nomod nopage oldlimit opts x11lineararcs} {debug defas itl1 itl2 itl4
         klu_memgrow_factor newtrunc scale wnflag} END MID END {}}
```

**So the ratchet survives the narrowing in both directions**, which is what the driver required and
is the only part of this task that could have failed silently.

### ⚠ A3a WAS AN INVALID ARM, AND I AM REPORTING IT RATHER THAN THE ROW IT DID NOT REDDEN

A3a was declared as *"the classifier always answers `END`"*. I replaced `lb14cite`'s tail test

```tcl
    if {$tail eq {} || [string index $tail 0] eq {.}} { lappend out END } else { lappend out MID }
```

with a bare `lappend out END`. **It reddened nothing — `ALL PASS (675)`.** The mutation was not
what I said it was: `lb14cite` returns `MID` **earlier**, at `if {$open < 0} { lappend out MID ;
continue }`, for any citation with no enclosing bracket — which is **all ten** subject-form sites
**and** term 4's hand-made string `a limit lives at foo.c:12 and the sentence goes on`. My edit
could therefore only reach citations that are *already* bracketed, and the one such mid-sentence
case (`wnflag`'s `inpgmod.c:268`) belongs to an option that stays in MID anyway through its two
subject-form citations. Nothing moved.

⚠ **The counted-diff guard PASSED on A3a, and that is the lesson.** The guard proves *the edit
landed exactly where I aimed it*; it cannot prove *the mutation means what I claimed*. That is the
`CREW_BRIEF` rule — *"the md5 moved" is not "the md5 moved where I meant"* — one level up again: a
correctly-placed edit can still be the wrong experiment, and a green result then reads exactly like
a row that cannot discriminate. **The tell was that a positive control came back green**, which is
never a pass.

**A3c is the arm A3a was supposed to be**: `lappend out END ; continue` as the first statement of
the match loop, so every citation answers END unconditionally. It reds `LB14`, and **two** terms
catch it — term 2's MID list collapses to `{}`, and term 4 answers `END` where `MID` is required:

```
actual {{acct debug defas itl1 itl2 itl4 klu_memgrow_factor list newtrunc node nomod nopage
         oldlimit opts scale wnflag x11lineararcs} {} END END END {}}
exp    {{acct list node nomod nopage oldlimit opts} {debug defas … x11lineararcs} END MID END {}}
```

**A3b completes the classifier control**, and it is the term the brief singled out: forcing
`lb14cite` to answer `END` for a string containing no citation flips the final term from `{}` to
`END` (and balloons term 1 to every option in the catalogue). **So all three hand-made strings are
load-bearing** — the compliant one, the mid-sentence one, and the one citing nothing — and none of
them is decoration.

---

## Completeness, not row counts — checked by NAME and by BANNER, on both arms

A row count that lands on the expected value passes every check a row count can make, and this pass
was *expected* to leave the count still, which is the condition under which a truncation hides
best. So:

| suite | arm | last emitting row **by name** | `ok:` lines | terminal banner | `RESULT:` |
|---|---|---|---|---|---|
| `test_ase_core` (before) | nogui / disp | `MT10` / `MT10` | 675 / 675 | `OVERALL: ok` / `OVERALL: ok` | ALL PASS (675) |
| `test_ase_core` (after) | nogui / disp | **`MT10` / `MT10`** | **675 / 675** | **`OVERALL: ok` / `OVERALL: ok`** | **ALL PASS (675)** |
| `test_ase_core` (restored, campaign's last row) | nogui / disp | `MT10` / `MT10` | 675 / 675 | `OVERALL: ok` / `OVERALL: ok` | ALL PASS (675) |
| `test_ase_options_1437` | nogui | `PR4` | 75 | `OVERALL: ok` | ALL PASS (75) |
| `test_ase_optsheet_1441` | nogui | `HK5` | 64 | `OVERALL: ok` | ALL PASS (64) |

**I am saying explicitly that I checked the last row by name and the terminal banner on both arms**,
not merely the arithmetic. `test_ase_core`'s file-last `check` is `MT0`, a section guard inside
`if {[catch …]}` that emits **only on failure** — its absence is the signal, as 56b and 57
recorded; `MT10` is the last emitting row.

`disp` = `devdisplay.sh exec` on **`:99`** (Xvfb, **openbox (Openbox 3.6.1)**, `1920x1080x24`,
`devdisplay.sh status` = alive). The timeout prefix goes **inside** `devdisplay.sh exec` so
`cmd_exec` stays the parent and a stall cannot orphan an xschem on `:99`. Every command carried a
`timeout`; the campaign ran in the **foreground** under a bound and printed terminal sentinels
(`SABOTAGE DONE`, `CAMPAIGN FINISHED`). **No background command, no waiting loop, and I never
ended a turn waiting to be woken.** Every run ended in a named verdict — `ALLPASS`, `REDS[...]` or
`DIED(...)`; no `TIMEOUT` fired.

**Not tested against `/usr/bin/ngspice` (apt 45.2), deliberately.** Every change in this pass is a
comment plus one test description string; nothing ASE-L emits, reads back or offers moved — proved
by `−0 / +0` non-comment in `src/ase.tcl` and by 104/104 `.state` byte-identity. Per the
`CREW_BRIEF` carve-out for pure-Tcl rows that never start a simulator, I say that instead of
testing twice.

### The floor — unmoved, and the file now says why beside it

The count does **not** move (no row added, none removed), so no floor was raised and **none was
lowered**. Per the brief, `test_ase_core.tcl`'s floor block now carries a paragraph **beside the
floor** explaining the non-move, in that file's idiom — that A11's narrowing is wording-only, that
a still count is the correct outcome rather than a row that failed to arrive, and that *"a pass
that leaves the count still is the one where a truncation hides best"*, so it was checked by name
(`MT10` + `OVERALL`, both arms) as well as by number. It cites task 3's **C1** — the `#` inside a
`[list …]` that truncated a sibling suite 242 → 232 while still printing a plausible `RESULT:`
line.

---

## New copy — NONE minted, and that was the constraint

⚠ **I minted no handle and wrote no new user-facing sentence.** Every changed character is a **test
comment**, a **source comment**, or the `LB14` **check description** — none of which a user of
ASE-L ever sees. The narrowed rule's wording is **the user's own**, quoted verbatim from
`R9_COPY_REVIEW.md` §A11's `✅ NARROWED BY THE USER` block:

> **Where ASE-L cites the simulator's source *in a bracket*, the bracket closes the sentence.**

**No rendered ASE-L string was touched.** The ten mid-sentence citations are on screen exactly as
they were, which is the whole point of the narrowing; the seven moved ones are as receipt 57 left
them. `R9_COPY_REVIEW.md` is byte-identical at my start and my end — **the document already carries
the narrowing and the corrected 393/18**, which is why this task was tree-only.

---

## ⚠ What I refused to widen, and why

1. **I did not touch the ten mid-sentence citations.** That is the ruling: leave them. Moving any
   one rewrites a sentence, which is new copy and the user's.
2. **I did not extend §A11 to the `d_cosim` notice** (`spice_netlist.c:143-169`, bracketed and
   mid-sentence). It cites **xschem's own netlister**, not the simulator's source, and §A11's
   subject is the simulator's. It is bracketed, so unlike the ten it *would* fall under the
   narrowed rule the moment the rule's subject were widened — which makes it a **live** question
   rather than a dormant one, and a one-word change to the ruling that is the user's to make.
   **Still not extended. Still unhandled.** Reported by receipt 57, confirmed by 57b, and I am
   naming it a third time because the narrowing has changed its character.
3. **I did not adjust `R9_COPY_REVIEW.md`'s `✅ IMPLEMENTED` block**, which still describes the ten
   under the heading *"TEN WERE NOT MOVED, AND THEY ARE REPORTED RATHER THAN TIDIED"*. That is
   accurate history and the `✅ NARROWED` block above it supplies the current status, but the two
   read slightly against each other. **The driver's call**, since it is the user's document.
4. **I did not strengthen `LB14` to drive the real widget.** It still composes the detail bits
   itself, so a future surface that started rendering `site` would escape it — receipt 57's own
   declared weakness, unchanged and still real.

## Debts to report upward — nothing filed by me

* **`rule`** — the four rendered citations with **no `R9-` handle** (`niiter.c:38-39`,
  `cktsopt.c:111-113`, `subckt.c:592`/`inp.c:2689`, `inpgmod.c:268`/`inpcom.c:990`/`inp.c:2828`),
  plus the **`d_cosim` `spice_netlist.c:143-169`** site. Carried forward unchanged from receipts 57
  and 57b. The narrowing does not resolve them: the four are now explicitly out of scope, but they
  remain user-visible copy with nothing to rule on it.
* **`rule`** — whether §A11's subject extends to **xschem's own source**, which is what decides the
  `d_cosim` site. Sharpened by the narrowing, as item 2 above explains.
* **No `look` debt is created or discharged here.** Nothing this pass changes reaches a screen.

## Hygiene

* **Snapshots disarmed.** `pristine/` and `fin/` are moved to
  `…/scratchpad/a58/ARCHIVED_DO_NOT_RESTORE/`, and `plant.py`, `arm.sh` and `reds.sh` are renamed
  `.disarmed`, so a stale waiter cannot fire a restore over a later tree. **Campaign logs are
  kept** (26 files in `…/scratchpad/a58/logs/`) as this receipt's evidence, together with the
  needle/replacement pairs in `arms/`.
* **Processes matched by NAME** (`ps -eo comm=`), never `pgrep -f`, never `pkill`.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching
  anything.** Another crew is probably live in the tree, and `LEDGER.md` was already moving under
  me during this pass.
