# Item 03 — round 3, FINAL coverage round: the differential property oracle

Addendum to `receipts/03_receipt.md`. Batch `signal_browser_batch`, branch `fluid-editing`.
Date 2026-08-04. Executed under **DRIVER RULING 17** (PLAN.md §17), which withdrew the
acceptance criterion the previous two rounds were held to and replaced it. This is the
**last authorised round on item 3 coverage**; nothing here re-opens item 3's behaviour,
which was independently confirmed correct twice across ~46,000 differential comparisons.

Prior state: `afdd44a0` (the item) → `3258c372` (the ruling-16 fixup, behaviour CORRECT)
→ `1d9652ab` (round 2, GS17-GS21, 82 checks). All committed, none pushed.

---

## 1. What was actually wrong, and it was two things

**(1) The coverage was incomplete** — but that was never fixable by the method being used.
The mutation space of `^v\((.*)\)$` is unbounded; a character class can always be narrowed
by one more character, so "find a green mutation" always succeeds and a third round of
fixtures would have found an eighth hole. Ruling 17 is right that the criterion, not the
verifiers, was the defect.

**(2) The documentation asserted a completeness the code did not have.** Three specific
false claims, all shipped in `1d9652ab`:

| claim | where | why it was false |
|---|---|---|
| *"GS19 the capture takes ANY content — dots and brackets alike"* | check name, test file | The fixture `v(x1.x2.net_name[3])` pins exactly two characters. Five capture narrowings sailed past it (144-1,966 differing comparisons each). |
| *"Every one of its five parts now fails a named check when mutated"* | `1d9652ab` commit message | False for the capture group (any narrowing except dot/bracket) and for the paren literals (DELETION is caught, WIDENING is not — asymmetric with the `v` literal, where deletion, widening and case-folding all have checks). |
| the GS17-GS21 part→check map, presented as complete | test file comment block | Same two gaps, in the form a maintainer actually reads. |

This is the dangerous half. A maintainer reading *"the capture takes ANY content"* beside a
green 82-check suite would reasonably "tidy" `(.*)` into an explicit class and ship the
regression — which is precisely the mutation review had already measured as an on-screen
defect. **Either the coverage widens to match the claim or the claim narrows to match the
coverage, never neither.** Both were done: the oracle makes the strong claim TRUE, and
every claim the oracle does not support was narrowed in place.

## 2. What shipped

| | |
|---|---|
| commit | see §8 (a new FIXUP commit on top of `1d9652ab`, not an amend) |
| files | `tests/headless/test_wave_sigsearch.tcl` (+ the oracle, + the claim corrections), `src/xschem.tcl` (**COMMENT ONLY**, +13 lines, `git diff` confirms zero non-comment lines), this receipt |
| `src/wave_viewer.tcl` | **not touched.** Zero blast radius, as in every previous item-3 round. |
| checks | **82 → 88** (GSO01-GSO06) |
| runtime | **whole file 0.34 s**; the oracle itself **290 ms** of that (measured with `clock microseconds` around the matrix loop). It is re-run whole by every later item's verifier and costs them a third of a second. |

### The oracle

* **The frozen reference** is `gsl_frozen_ref` in the test file: the pre-item-3 body,
  copied verbatim from `git show afdd44a0^:src/xschem.tcl` (lines 4469-4486, whole proc).
  It carries a ⚠⚠ header saying it must never be edited to make a failing implementation
  pass, and naming that act for what it is — *deleting the test while leaving it green, on
  purpose* — so a reviewer reads any diff touching it as sabotage until proven otherwise.
* **The matrix**: 52 names × 94 patterns. Blobs are the 52 single-name blobs (so a failure
  names the exact signal), the whole set in one blob, and 2 ordering blobs (a single-name
  blob cannot see a sort or a sort/strip ORDER defect) — 55 blobs × 94 patterns × **both**
  `graph_sort` directions = **10,340 comparisons**, 1,054 of them differences, **0
  unexplained**.
  > ⚠ **Superseded numbers.** As first committed in `5f1de36a` this read 51 × 84 = 9,072.
  > The cleanup commit (§10) widened both axes — the punctuation sweep was missing three
  > characters, an alphanumeric sweep was added, and the leading-hyphen patterns that §5
  > had wrongly excluded were put in.
* **The name axis** carries every class ruling 17 named, because that is exactly how the
  seven holes stayed green: `v(a,b)` and `v(out,outb)` (ngspice DIFFERENTIAL voltage —
  an ordinary line in a real `.raw`), `v(vdd!)`, `v(net#1)`, `v(x-y)`, dotted hierarchical,
  bracketed bus, `i()`-wrapped, bare, `@m…[id]`, and empty. Plus five added by this round's
  own defeat attempts: `v()` (empty wrapper content), `v(a(b))` (a paren INSIDE), `(x)` (no
  `v`), `vx(y)` (`v` + non-paren + parens), `vv(a)` (doubled `v`), a name with a SPACE, a
  name with a TAB, a **punctuation sweep** `v(a b!"#$%&'*+,-./:;<=>?@[\]^_`{|}~)` (all 32
  ASCII punctuation characters) and an **alphanumeric sweep**
  `v(0123456789abc…xyzABC…XYZ)` (all 62).
  > ⚠ **Corrected.** `5f1de36a` shipped the punctuation sweep as
  > `v(a b!#$%&'*+,-./:;<=>?@[]^_{|}~)` — **missing `"`, `\` and backtick** — and no other
  > name carried them, so `[^"]*`, `[^\\]*` and ``[^`]*`` changed real behaviour and stayed
  > 88/88 green. The alphanumeric sweep did not exist at all, which left 40 further
  > narrowings (`[^q]*`, `[^Z]*`, `[^7]*` …) green. See §10.
* **The pattern axis**: anchored, unanchored, bracket/class, wildcard, quantifier,
  alternation, backreference, escape, case-varying, **leading-hyphen**, INVALID, and
  DIRECTOR forms.
* **The sanctioned-difference predicate is narrow, three conjuncts each**, not a broad
  "ignore anything that errors":
  * **(a) decision 4** — the LEGACY validity probe must reject the pattern **AND** the
    shipping body must return exactly `{}` **AND** the reference must have returned exactly
    its everything-answer. A mutation that turns a rejected pattern into a *partial* list
    is not class (a) and is reported.
  * **(b) ruling 16 delta 3** — the RAW pattern must be valid **AND** the WRAPPED pattern
    invalid **AND** the pattern must actually BE a director/embedded-option form **AND** the
    shipping body must return exactly `{}`.
  Exercised counts are printed every run: `a=864`, `b=190` (`a=848`, `b=188` before §10's
  axis widening).
* **On failure the check prints the repro**, not a count: `name={…} pat={…} graph_sort=… got={…} exp={…}`,
  up to 8 cases, and the first case is also the `got` of the GSO01 FAIL line itself.
* **GSO02-GSO06 stop the oracle passing vacuously**: the matrix ran whole and nothing was
  skipped; class (a) was actually exercised; class (b) was actually exercised; the frozen
  reference is still the legacy body and not a call to the shipping one (GSO05 pins the
  legacy *widening*, which the shipping body deliberately does not do — replace
  `gsl_frozen_ref` with a call to `graph_get_signal_list`, the cheapest way to make the
  oracle trivially green, and GSO05 fails instantly); and the required real-name classes
  are still present (GSO06 — a later "tidy" cannot quietly drop `v(a,b)`).

## 3. The seven round-2 holes, re-injected one at a time

Each was injected into `src/xschem.tcl` alone, `git diff --stat`-confirmed as a 1-line
change before the run, and reverted with `git checkout -- src/xschem.tcl` after (final
`git diff` empty, re-run green). **All seven now fail, every one of them on GSO01, and
every one as a SINGLE target (1 FAILED / 87 passed)** — the GS fixtures stay green under
them, exactly as round 2 measured, which is the cleanest possible demonstration that the
oracle and not the fixtures is carrying the coverage.

| # | mutation | unsanctioned diffs | the case GSO01 printed |
|---|---|---|---|
| H1 | capture `.*` → `[a-zA-Z0-9_.\[\]]*` | 788 / 9072 | `name={v(a,b)} pat={} got={v(a,b)} exp={a,b}` |
| H2 | capture `.*` → `[\w.\[\]]*` | 788 / 9072 | `name={v(a,b)} pat={} got={v(a,b)} exp={a,b}` |
| H3 | capture `.*` → `[^,]*` | 302 / 9072 | `name={v(a,b)} pat={} got={v(a,b)} exp={a,b}` |
| H4 | capture `.*` → `[^)]*` | 134 / 9072 | `name={v(a(b))} pat={} got={v(a(b))} exp={a(b)}` |
| H5 | capture `.*` → `.+` | 88 / 9072 | `name={v()} pat={} got={v()} exp={{}}` |
| H6 | `\(` widened to `.` | 124 / 9072 | `name={vx(y)} pat={} got={(y} exp={vx(y)}` |
| H7 | `v` → `v?` | 68 / 9072 | `name={(x)} pat={} got={x} exp={(x)}` |

## 4. Trying to defeat my OWN oracle — 24 further mutations

Round 4 of the same discipline, aimed at the parts of the proc the matrix might not reach.
Every one injected alone, diff-confirmed, reverted.

**Caught (21):** replacement `\1`→`&`; capture → non-capturing group; `v`→`[vV]`;
`regsub`→`regsub -nocase`; `\)` widened to `.`; drop `-case 1`; re-sort the STRIPPED list
(`-sort [expr {$graph_sort?1:-1}]`); restore the legacy err-widening; strip AFTER the match
(the pre-ruling-16 body); half-anchor the wrap `.*(?:$pat)`; drop the non-capturing group;
drop the leading `.*` of the wrap; split on whitespace not newlines; `lsort -dictionary`
→ `-ascii`; invert the sort mapping; `-syntax regexp` → `shell`; leading `^` dropped
(round 1's hole, re-checked); trailing `$` dropped (P2's hole, re-checked); and — found by
this round and **initially GREEN**, then closed by widening the name axis — `v`→`v+`,
capture → `[^ ]*`, capture → `[[:print:]]*`.

**The three that survive, and they survive on purpose** — each is provably
behaviour-PRESERVING, so a test that failed on them would be pinning the source text rather
than the behaviour:

| mutation | why it cannot change behaviour |
|---|---|
| `(.*)` → `(.*?)` | The regsub is anchored `^…$`, so the total match spans the whole name and the capture is the unique remainder. Lazy vs greedy cannot differ. Confirmed over all 9,072 comparisons. |
| `regsub` → `regsub -all` | Same anchors: at most one match exists, so `-all` has nothing extra to do. |
| drop the `$pattern ne {}` guard | `^(?:.*(?:).*)$` matches every name, exactly as `sig_match`'s empty-pattern short-circuit does. (The guard is kept because the short-circuit is `sig_match`'s DOCUMENTED contract — a style point, not a behaviour one.) |

**Three further honest limits of the oracle**, written into the test file so nobody
over-reads GSO01: it is blind by construction to a mutation that REMOVES a sanctioned
difference (that makes the shipping body *more* like the reference — GS08 and GS13 pin
those two and are not redundant); it is blind to genuinely behaviour-preserving mutations
(above); and it sees nothing outside `graph_get_signal_list` itself (`sig_match` has its
own group, SM01-SM27).

## 5. ~~Divergence — a THIRD difference class~~ — RETRACTED: it does not exist

**This section was WRONG as committed in `5f1de36a`, and being wrong cost the oracle an
entire pattern class. No driver decision is owed. Nothing here needed a ruling.**

What it claimed: `graph_get_signal_list`'s legacy validity probe is `regexp $pattern
{12345}` with **no `--`** (`afdd44a0^:src/xschem.tcl:4477`), so a pattern STARTING WITH `-`
is parsed there as a *switch*, the probe throws, and the legacy body widens to "show
everything" — a genuine third difference class, therefore leading-hyphen patterns were
**excluded from `GSO_PATS`** behind a ⚠ "DELIBERATE MATRIX BOUNDARY" block, and the driver
was offered a decision about it.

**The premise is false.** Re-measured independently on this machine (Tcl **8.6.14**):

| how the pattern reaches `regexp` | `-` `--` `-nocase` `-zz` `-line` `-all` `-x` `-expanded` `-a-` `-.*` |
|---|---|
| `regexp $p {12345}` — **through a variable**, which is how BOTH `gsl_frozen_ref` and the shipping body spell it | **err=0, result 0, every one** |
| `regexp -nocase {12345}` — the same word as a **literal** | error (`wrong # args`) |
| `regexp {*}$p {12345}` / `eval regexp …` — **re-dispatched at runtime** | error (`bad option "-zz"`) |

Switch parsing happens for a **literal** option word, or when the command is re-dispatched
by `eval` / `{*}` expansion — *not* for a pattern arriving through a variable in a compiled
proc. So the legacy probe never throws on a leading hyphen and never widens.

**Differential measurement**, verbatim frozen reference vs shipping body, blob
`"v(x-y)\nzz\nv(out)\n-lead\nv(-a-)"`, 10 leading-hyphen patterns × both sort directions =
**20 comparisons, ZERO differences**. Pattern `-` returns `{-lead -a- x-y}` from **both**
bodies — not "the whole list" from one and "hyphenated names" from the other.

**Fix applied (§10):** the ⚠ block and the exclusion are deleted and ten leading-hyphen
patterns (`-`, `--`, `-nocase`, `-all`, `-line`, `-zz`, `-x`, `-out`, `-.*`, `-a-`) are now
**in** `GSO_PATS`. This *adds* 1,080 comparisons of coverage the oracle had been forgoing,
all of them clean. `gso_sanctioned` is untouched and still recognises exactly the two
classes ruling 17 sanctions.

**Lesson, and it is the same one as §6:** this claim was reasoned about and written into a
⚠ block and a receipt, but never executed. One `catch` would have refuted it. The oracle
exists precisely because unmeasured claims about regex behaviour had already been wrong
twice — and the artifact built to cure that shipped a third.

## 6. The claim corrections

| what it said | what it says now |
|---|---|
| `GS19 the capture takes ANY content — dots and brackets alike` | `GS19 the capture takes a DOT and a BRACKET (ANY content: see GSO01)`, with a comment saying in as many words that the old name was a property claim one fixture cannot support, that five narrowings sailed past it, and that the ANY-content property is real and asserted by GSO01. |
| the GS17-GS21 block's map, presented as complete | The block now opens with a ⚠ *"WHAT THIS BLOCK IS AND IS NOT"*: it is a defect-NAMING aid, not a completeness proof; the earlier claim and the commit message that carried it are named as **FALSE**, with the seven measured counterexamples; the map's rows now say DELETE where they mean delete, and carry explicit **"NOT caught here"** lines for paren widening and for capture narrowings other than dot/bracket. Completeness is attributed to GSO01 and to nothing in the block. |
| `1d9652ab`'s commit message, *"Every one of its five parts now fails a named check when mutated"* | Cannot be rewritten (history). Corrected in three places that a reader actually reaches: the test-file block above, this receipt, and the body of the new commit, which names the claim and retracts it. |
| the file header's group list | GS row reworded (one NAMED check per part; *names* which part broke, does NOT prove coverage); a new GSO row describes the oracle, its size, its runtime and its two sanctioned classes. |
| `src/xschem.tcl`'s proc header, *"(e) and (f) are the ONLY two permitted on-screen differences"* | Unchanged and still true — now followed by a ⚠ saying that "only two" is **machine-checked, not asserted**, naming GSO01, and telling a future editor that GSO01 is not an obstacle to route around: a third sanctioned difference needs a driver ruling, and the frozen reference must not be edited to agree. |

## 7. Verification

* `./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl`
  → `RESULT: ALL PASS (88 checks)`, **0.34 s**, `GSORACLE: 10340 comparisons, 1054
  differences, all sanctioned (a=864, b=190), 0 unexplained.` (As `5f1de36a` shipped it:
  9,072 / 1,036 / a=848 / b=188 — see §10.)
* No droppings: `git status` shows only the two intended modified files.
* No `make` was run while any suite was running.

## 8. Audit — the clean 283 the batch was owed

**`tests/headless/full_audit.sh`, solo, gated, ran to completion: 283 tests — 260 PASS,
2 SKIP, 21 FAIL, in 17 minutes. ZERO `X connection to :0 broken`. Zero
`revive FAILED -- suite continues UNGATED`.** Three previous attempts were
X-contaminated, orphaned or paused; this one is a measurement.

**The GUI gate was obeyed, not worked around.** The panel was on **PAUSE** when this round
started and stayed paused for ~55 minutes while the human was away; an **orphaned audit from
the previous round** (pid 495942, stalled at `test_ihp_sg13g2_libmgr`) was blocked on the same
pause. `GUI_GATE=0` was never set, no control/allow file was hand-written, no bare loop was
used. The orphan could not be killed from this session, and running a second audit beside it
would have collided on the display and on the shared test scratch dirs, so this round **waited
for the orphan to finish and then started its own** through the gate (`gui_gate: approved batch
window open, starting 'full_audit: 283 tests' (no prompt)`). Its numbers were NOT adopted.

**The 21 fails:**

* **15 are HARD-baseline names** (2026-08-04 re-baseline): `test_ase_log_seam_0207`,
  `test_ase_window`, `test_cadence_drag`, `test_ciw`, `test_gf180mcud_libmgr`,
  `test_ihp_sg13g2_libmgr`, `test_lib_manager_gui`, `test_lib_manager_locate`,
  `test_lib_sweep`, `test_phase3_mints`, `test_reopen_readonly`,
  `test_rotate_stretch_short_0104`, `test_select_at`, `test_selflog_output`,
  `test_sky130a_libmgr`. The 16th, `test_fluid_editing`, **PASSED** — better than baseline,
  not worse.
* **6 are not on the hard list, and all 6 are cleared.** Each was re-run **3×** through the
  gated harness with the exact `full_audit` verdict rules:

| name | on the FLAKY list? | re-run 3× | verdict |
|---|---|---|---|
| `test_ase_unnamed_net` | yes (AN8) | 3/3 PASS | flake |
| `test_palette` | yes | 3/3 PASS | flake |
| `test_wave_hilight` | yes (WD2) | 3/3 PASS | flake |
| `test_wave_trace_menu` | no — but REMOVED from the baseline as the documented 4-in-10 TG9 root-coords flake; this failure is TG10, same family | 3/3 PASS | flake |
| `test_ase_plot` | no — but the documented WSLg gesture flake (P4/P6/P8) | 2/3 PASS | flake |
| `test_altf5_ciw` | **no, on neither list** | 3/3 FAIL | **ISOLATION-PROVED environmental**, see below |

**`test_altf5_ciw` — isolation-tested, not hand-waved.** It failed all three re-runs, so the
change was stashed (`git stash push -- src/xschem.tcl tests/headless/test_wave_sigsearch.tcl`)
and the test run **4× with this round's changes ABSENT: 2 PASS, 2 FAIL.** It is an
intermittent environmental failure of the synthetic-key/raise kind this box is known for
(`FAIL - Alt-F5 raises/opens the CIW` / `FAIL - rebound Alt-F5 raises CIW again` — key
delivery, the documented ~1-in-5 `event generate` flake). It also cannot mechanically be
this round's: the only tracked files touched are one test file that no other suite sources
and a Tcl COMMENT. **Nominated for the FLAKY list** so items 4+ do not spend an hour on it.

**Net: `nonBaselineFails: []`.**

**One honest disclosure about ordering.** The `src/xschem.tcl` comment block was written
BEFORE the audit, then silently reverted by a later mutation script's
`git checkout -- src/xschem.tcl` (the scripts revert the file wholesale after each injection),
and re-applied AFTER the audit — so the 283-test run saw `src/xschem.tcl` identical to
`1d9652ab`. That is immaterial: the re-applied change is 13 lines of Tcl **comment**, `git
diff` confirms zero non-comment lines, and the single test that exercises the proc it
documents (`test_wave_sigsearch`) was re-run under a real DISPLAY through the gated harness
on the FINAL tree → **PASS**, 0 X-deaths. It is written down rather than smoothed over
because a reader comparing timestamps would otherwise find it themselves.

## 9. Termination

Ruling 17 makes this the last coverage round on item 3. The oracle landed: it catches all
seven round-2 holes, 21 of the 24 further mutations tried against it, and the three it does
not catch are provably behaviour-preserving. **No further mutation-hunting on item 3 is
authorised, and none is needed** — the next reviewer's time is better spent on item 4.

---

## 10. The scoped cleanup — three proven defects IN the oracle (DRIVER RULING 18)

Ruling 18 authorised **exactly** this and bounded it: fix the three defects `5f1de36a`'s own
verify stage found in the artifact, then item 3 CLOSES regardless of outcome. This is
finishing round 3, not a fourth mutation-hunting round. **No new mutation hunt was run and
none is reported below as a finding.**

### Defect 1 — the axis was three characters short, and six comments said otherwise

The punctuation sweep shipped as `v(a b!#$%&'*+,-./:;<=>?@[]^_{|}~)`, missing `"`, `\` and
backtick; no other name in `GSO_NAMES` carried any of them. Three capture narrowings were
therefore behaviour-changing and **88/88 GREEN**. Re-injected after widening the axis:

| mutation of `regsub {^v\((.*)\)$}` | before | after |
|---|---|---|
| `(.*)` → `([^\\]*)` | GREEN 88/88 | **GSO01 FAIL**, 144 unsanctioned, repro printed |
| `(.*)` → `([^"]*)` | GREEN 88/88 | **GSO01 FAIL**, 144 unsanctioned, repro printed |
| ``(.*)`` → ``([^`]*)`` | GREEN 88/88 | **GSO01 FAIL**, 144 unsanctioned, repro printed |

The sweep is now `v(a b!"#$%&'*+,-./:;<=>?@[\]^_`{|}~)` — all 32 ASCII punctuation
characters — changed in both places it occurs (the `GSO_NAMES` axis and `GSO06`'s required
list), and **confirmed by running it**, not by reading it: the Tcl brace-quoted literal was
executed and its 32-character punctuation content asserted before it was pasted in.

**A DIVERGENCE FROM THE INSTRUCTION, DELIBERATE AND MEASURED.** Ruling 18 directed that the
true claim be written as *"any narrowing of the capture that excludes a printable ASCII
character fails GSO01"*. Rather than assert it, I **measured** it — swept all 95 printable
ASCII characters (0x20-0x7E) as `(.*)` → `([^c]*)`, one run each:

* with only the widened punctuation sweep: **55 caught, 40 GREEN.** Every one of the 40 was
  alphanumeric (`[^q]*`, `[^Z]*`, `[^7]*` …) — no wrapped name in the axis contained those
  characters. **The authorised claim would have been false as written.**
* ruling 17's own rule is *"either the coverage widens to match the claim or the claim
  narrows to match the coverage — never neither"*. I widened, since it is one line: added
  `v(0123456789abc…xyzABC…XYZ)`, all 62 alphanumerics.
* re-swept: **95/95 caught, 0 green.** The authorised claim is now TRUE **as measured**.

This is the only step beyond the literal instruction, and it exists so the sentence ruling
18 asked for could be written honestly. Cost: one name, +188 comparisons.

The six false claim sites are corrected and each now states the **bounded, measured** claim
plus a pointer to the residue:

| site | now reads |
|---|---|
| `test_wave_sigsearch.tcl:43-59` (header GSO row) | 52 × 94 = 10,340; "carries the coverage claim", bound stated as printable-ASCII, 95/95 measured |
| `:498` (GS17-GS21 block, bullet 2) | "COMPLETENESS IS PROVED BY" → "COVERAGE IS CARRIED BY"; bound + 95/95; explicit *do not restore the word "COMPLETE"* |
| `:530-533` (**the dangerous one**) | the sentence that green-lit *"tidy `(.*)` into an explicit class and ship the regression"* now states the printable-ASCII bound, names the residue, records that the old wording rested on a property the oracle did not have, and says **re-measure, do not reason** |
| `:607-614` (oracle rationale) | "EVERY behaviour-changing mutation" retired — an oracle is only as wide as its axes; a ⚠ says say "fails GSO01" only of things measured failing GSO01 |
| `:688` (name-axis sweep note) | both sweeps described, 95/95 recorded, ⚠ *do not clean up either name* with the exact history of what went green |
| `src/xschem.tcl:4524` (**COMMENT ONLY**) | 52 × 94 = 10,340; "ANY behaviour-changing edit" corrected to a bounded, measured guarantee + the residue |
| this receipt §2 | superseded numbers marked as such |

A **fourth entry** was added to the file's *"WHAT THIS ORACLE STILL CANNOT SEE"* list for the
honest residue: narrowings excluding only characters outside printable ASCII (the axis
carries exactly one non-printable, a TAB, which is what kills `[[:print:]]*`). It is
labelled the finite-axis regress ruling 17 **deliberately withdrew** — *not a bug, not work,
do not open a round to chase it* — with the one legitimate trigger to revisit named: a real
`.raw` observed emitting such a name.

### Defect 2 — a whole pattern class excluded on a false premise

See **§5**, retracted in full above, with my own independent re-measurement (Tcl 8.6.14; 20
differential comparisons; zero differences; literal-vs-variable switch-parsing table). The
⚠ "DELIBERATE MATRIX BOUNDARY" block and the exclusion are **deleted**, ten leading-hyphen
patterns are **in** the matrix (+1,080 comparisons, all clean), and the driver is owed **no
decision**. `gso_sanctioned` still recognises exactly two classes.

### Defect 3 — the anti-vacuity check defeated itself

`foreach gso_b [lrange $gso_bad 0 7]` reused `gso_b`, the class-(b) exercised counter, so on
any FAILING run the counter was clobbered with `name={…} pat={…} …` and GSO04's
`expr {$gso_b > 0}` resolved by **string** comparison to 1. Renamed to `gso_line`.

**Proved by injection, in four states** — a rename nobody tested is not a fix. The decisive
one is the middle pair: the director patterns were removed from `GSO_PATS` so class (b) is
genuinely exercised **zero** times, while a `(.*)` → `([^,]*)` capture narrowing keeps the
run failing.

| state | GSO01 | GSO04 | verdict |
|---|---|---|---|
| committed `gso_b`, mutation only | FAIL | `ok` | GSO02-GSO06 all "ok", as reported |
| committed `gso_b`, mutation + class (b) exercised **0** times | FAIL | **`ok`** | **VACUOUS — the defect, reproduced** |
| renamed `gso_line`, mutation + class (b) exercised **0** times | FAIL | **`FAIL {0} (exp {1})`** | **fix works** |
| renamed `gso_line`, mutation only (directors restored) | FAIL | `ok` | legitimately ok — counter really is 190 |

A ⚠ comment above the loop now records that the loop variable must not reuse a counter name,
with the measurement.

### What was run — and what this is NOT

* `./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl`
  → **`RESULT: ALL PASS (88 checks)`**, `GSORACLE: 10340 comparisons, 1054 differences, all
  sanctioned (a=864, b=190), 0 unexplained`, ~0.34 s.
* The wave/graph-related suites through the gated `run_suites.sh` under a real DISPLAY — see
  the run table in the report accompanying this commit.
* **This round is NOT a full 283-test audit and must not be read as one.** `5f1de36a`
  already carries the batch's clean 283 (§8), and this cleanup changes **no product logic**:
  the entire `src/` diff is Tcl **comment**, `git diff` confirms zero non-comment lines, and
  `src/wave_viewer.tcl` is untouched. Audit scope was set deliberately by ruling 18.
* Every sabotage was reverted with `git checkout -- src/xschem.tcl` and confirmed clean with
  `git diff --quiet` before the next measurement. The test file, which carried uncommitted
  work throughout, was never `git checkout`-ed — it was restored from a scratchpad copy.

### Termination

Item 3 is **CLOSED**. Ruling 18 closes it after this cleanup *regardless of outcome*, and
the outcome was: three defects fixed, each proved by injecting the mutation it exists to
catch, plus one measured widening so the authorised claim is true rather than merely
authorised. **No eighth green mutation is reported, because none was hunted.** The batch
proceeds to item 4.
