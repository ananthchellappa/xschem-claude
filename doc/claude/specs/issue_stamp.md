# The issue stamp — making a tracker file say what it was measured against

**Implementation** `tests/headless/issue_stamp.tcl` (checker),
`tests/headless/test_issue_stamp.tcl` (its red-first suite),
`tests/headless/issue_stamp_baseline.txt` (the grandfather set).
**Designed by** task `BC1` of the issue-tracker batch, 2026-09-17.
**Measured basis** `doc/claude/issue_tracker_batch/receipts/A1.md`–`A4.md`, a
pre-registered random sample of 40 of the 1047 numbered issue files.

---

## 1. The problem, as measured rather than as assumed

Four crews classified 40 files drawn at random with a recorded seed, committed to
`SAMPLE.txt` before anyone read one. The aggregate:

| verdict | count of 40 |
|---|---|
| `ROTTED-CITE` — cites a file/line/symbol that does not say what it claims | **27** |
| `STALE-FIXED` — says open, but the tree already fixed it | **7** |
| `BAD-FIX` — a stored fix that would not work or would break something | **1** |
| `STALE-OPEN` — says fixed, but the defect is live | **0** |

The batch was scoped around the last two. **The sample says the first one is the
disease**, and the shape is sharper than the count: *in every rotted citation the
named symbol still existed and still behaved as the file described. Only the
coordinates died.* Three independent measurements agree —

* bare `file:line` citations: **5 of 5 rotted** (A3);
* `file:line` **plus a named revision**: **4 of 4 reproduced** via
  `git show fadb226d:` (A3, issue 0818 — the only such file in the sample);
* citations by **symbol name only**: **3 of 3 held** (A3), and 2016 backticked
  `foo()` citations across 509 files are **98.4% still present** (driver).

**Coordinates rot. Identity holds.** Shipped source already knew this:
`src/op_annot.tcl`, in the comment above `_netlisted`, reads *"Cited by function
name, not by line number, on purpose: the line numbers this paragraph used to
carry moved by about eleven hundred lines and silently sent every later reader to
the wrong place."* So does the tracker: **issue 0229** is this defect's own
write-up, it prescribes *"cite symbols, not offsets"*, it ships a ready-made
pre-commit grep — and it is still OPEN, and has since rotted by exactly the
defect it files. The corpus diagnosed itself, prescribed the cure, and nobody
applied it. **This spec is that prescription with something mechanical behind
it.**

### Why a retrospective rot-checker is impossible

Three were tried and all three failed, each producing a plausible wrong number:

* *does the cited line exist?* — 3751 citations resolved, **PAST-EOF = 0**.
  Nothing points past an end of file; the rot always resolves to a real line
  whose text moved.
* *is the cited symbol still there?* — 98.4% are. Symbols do not rot.
* *does the quoted line match?* — a "nearest filename above" heuristic called 17
  of 20 rotted; **16 were SPICE decks and log excerpts** that happen to carry
  line numbers inside fenced blocks.

You cannot compute today what a sentence meant when it was written. You *can*
make every sentence written from now on say what it was measured against. That
is a ratchet, not an audit, and it is the whole of this design.

---

## 2. The stamp

One physical line, anchored at column 0, inside the first **12** lines of the
file:

```
**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`
```

### ⚠ One physical line is a measured requirement, not a style preference

The nearest thing the corpus already has is the prose that 1473/1477/1478/1479
open with — *"measured in the tree at `aa0e2213`"* — and a census of it **missed
all four**, because markdown hard-wraps the phrase across a newline and a
line-oriented grep cannot match it. The driver published *"only 1 file in 1047
states its tree"* having **read those four files in the same session**. A
convention a grep cannot see is a convention that does not exist. Never wrap a
stamp.

### The fields

| key | values | why it exists |
|---|---|---|
| `v1` | the schema version, always first | lets the shape change later without a silent misread |
| `claim=` | `open` `fixed` `partial` `latent` `duplicate` `wontfix` | **a one-bit status cannot express this corpus** — see below |
| `tree=` | a revision, 7–40 hex, **at least one `a`–`f`** | the load-bearing field; it is what makes every coordinate in the file recoverable |
| `stamped=` | `YYYY-MM-DD` | the age of the claim, readable without git |
| `fix=` | `none` `untried` `taken` `superseded` `partial` | **a stored fix is an unverified hypothesis until marked otherwise** |
| `open=` | a non-negative integer | how many items the file itself says are still outstanding |
| `super=` | *(optional; required when `fix=superseded` or `claim=duplicate`)* an issue number `NNNN`, a revision, or `self` | what replaced the prescribed shape |
| `scope=` | *(optional)* one token naming an arm, path or door | for the defect closed on **one route** and live on another |
| `by=` | *(optional)* who stamped it | a task id, so a stamp is attributable |

`scope=` exists because two measured files cannot be expressed without it, and
both would be closed **wrongly** by whoever tidies next — which is the
`STALE-OPEN` direction, the dangerous one:

* **0216** is fixed for the Location bar and for `wviewer::restore`, and **not**
  for the ASE re-run path — `wviewer::attach_raw`'s body has no `rawhist_push`,
  and `src/results.tcl` says so in its own voice: *"Converting that path is NOT
  this item."*
* **0650**'s general channel landed (`5dd68128`); its **titular** session-window
  sink did not, and 0655 carries the remainder as *"OPEN (deferred out of issue
  0650 deliberately)"*.

### Why three numbers and not one verdict

This is copied deliberately from `T1-RUN-END`, which states `cases=`, `blocks=`
and `counted_failures=` rather than a pass/fail word. A one-bit status **cannot
express the files that matter most**:

* **0905** needs four answers at once — its subject is genuinely fixed, its §1 is
  stale, its §2 is stale *and inverted* (it records as "considered and
  deliberately NOT taken" the exact shape the tree now runs), and its §3 is half
  done. A header forcing FIXED-or-OPEN rounds all four wrong.
* **0891** needs *"2 of 3 follow-ups landed"* → `claim=partial open=1`.
* **0890** and **1219** need *"claims latent, is actually live"* → `claim=latent`.
  This was the schema cell A3 found missing, and it is the direction a reader
  never re-checks, because a file admitting weakness reads as honest.

### ⚠ `tree=` is a statement about the PAST, and that is why it never rots

`tree=` does **not** mean "current". It means *"the claims in this file were last
checked against this revision"*. That sentence is true forever; it only becomes
**older**, which is information rather than error.

This is the single most important thing to understand before "improving" the
checker. A rule that required `tree=HEAD` would redden the entire corpus the
moment anybody committed — which is exactly how this batch's own `PLAN.md:3`
rotted **within the hour**, because the driver committed twice while crews were
reading it. Requirement "cheap to re-stamp" is met by **not needing to
re-stamp**: you stamp when you re-verify, and re-verifying is work you were
doing anyway.

*(Measured while this spec was being written: `HEAD` moved three times in one
task — `d64686a1` → `0e985165` → `01cef414`. Nothing already stamped broke.)*

### Supersession, and the rule that a stamp is the file's newest word

510 of 1047 files contain **both** fixed-words and open-words in their first ten
lines. That is not sloppiness: it is what a file looks like after somebody
appends a correction without touching the header, and **append-without-touching-
the-top is this corpus's default editing motion** (3 of A2's 10 carry their own
refutation 100+ lines below the wrong text; 0665 says OPEN on line 3 and FIXED on
line 59).

So the convention does not fight the habit. It adds one rule:

> **The stamp is the file's single newest word. Any prose that disagrees with it,
> above or below, is history.**

Keep appending corrections. Update the one line. Exactly one stamp per file —
two would be the both-words defect in miniature, and the checker refuses it.

---

## 3. The citation rule

1. **Cite by identity first.** `` `proc rdw::push` in `src/rdw.tcl` `` — never a
   bare `src/rdw.tcl:1885` on its own.
2. **A coordinate is legitimate inside a stamped file**, because `tree=`
   retro-qualifies every one of them at once. `src/scheduler.c:851` in a file
   stamped `tree=fadb226d` is recoverable forever by
   `git show fadb226d:src/scheduler.c`. That is measured: 0818 was the only
   sampled file that named a revision, and all four of its dead coordinates came
   back exactly.
3. **A count is prose; only a pointer is a citation.** Three of A1's ten state a
   number that was true when written and has since drifted — "11 checks" (80
   today), "12 call sites" (13), "~3500 mentions" (5210). *Ruled, by BC1, on A1's
   recommendation:* these are **not** defects and are **not** checked. The
   alternative is a checker that cries wolf over the entire corpus on day two,
   and a checker nobody believes is a checker nobody runs.
4. **Do not mirror another file's status — link to it.** An umbrella issue that
   restates its children's statuses is a hand-maintained mirror, and *"a
   hand-maintained mirror of another module's rules is wrong by construction and
   had already drifted twice"* — which is issue **0442**'s own header, written
   about code, and true verbatim of prose. Issue **0071** is the proof: its
   header is correct while its §3 lists 0063 as an unresolved HIGH (0063 reads
   `✅ REPLAYABLE`), its §4 calls 0003 "pre-existing" (0003 reads CLOSED), and
   its "next mutators" list of six is five done.

---

## 4. Marked fenced blocks

The info string after the language word takes the same `key=value` grammar.

### `quote=` — a block that claims to reproduce tree text

````
```c quote=fadb226d path=src/scheduler.c
regsub {^~/} {%s} {%s/}
```
````

The checker verifies the block against `git show fadb226d:src/scheduler.c`,
whitespace-normalised so re-indentation is not a failure.

**This is the class nothing else catches.** A stale line number *looks* stale the
moment you follow it. A stale quoted block still looks like valid C and reads as
authoritative. Issues **0296** and **0435** both quote C that no longer exists —
A1's phrase for 0435 is *"correct by reference, damaging by paste"* — and
**neither was scored `BAD-FIX`**, which means the count of dangerous stored fixes
in this tracker is an undercount.

### `fix=` — a prescription's state

````
```tcl fix=superseded
op_annot::_netlisted {i}   ;# the shape 0442 prescribed, and the tree deleted
```
````

**`fix=` exists because of 0442, the sharpest defect in the sample.** Its
numbered item 1 was *accurate when written*. The tree then fixed the defect by
the unnumbered alternative buried at the end of the same section, and the file's
own header records why the prescribed shape was abandoned. **Pasting item 1 today
re-introduces what was deliberately deleted.** No status field catches that — the
status was never wrong. Only *which option was taken* catches it. Note 0442 is
also why `super=` accepts `self`: what superseded item 1 was not another issue,
it was a paragraph in the same file.

### `assert=` — a claim about the tree that a machine can settle

````
```sh assert=absent pat=SABOTAGE path=src state=broken
grep -rn SABOTAGE src/      # the sabotage protocol says this must be empty
```
````

Vocabulary: `assert=absent|present`, `pat=` one whitespace-free token, `path=` a
repo-relative path, `state=holds|broken`. There is no shell and no
interpolation — a document that can run arbitrary commands when you validate it
is a document you cannot validate.

`state=` is the interesting half, and it is what makes the tracker close its own
issues:

* `state=holds` and the predicate is false → **the file's claim is stale**.
* `state=broken` and the predicate is true → **the defect appears fixed and
  nobody closed the issue.**

That second arm is the mechanical `STALE-FIXED` detector. 7 of 40 sampled files
report finished work as outstanding; one defect was filed **five times across
seven weeks and attempted zero times** (0384, 0867, 0955, 0905, 0990) because
each arrival read the previous filing and believed it. An issue whose defect is
greppable can now declare it, and the checker flags the file the day someone
fixes it — without anybody remembering the issue exists.

---

## 5. What the checker enforces

`tests/headless/issue_stamp.tcl`:

```sh
tclsh tests/headless/issue_stamp.tcl gate       # the verdict, exit 0 or 1
tclsh tests/headless/issue_stamp.tcl report     # advisory census, always exit 0
tclsh tests/headless/issue_stamp.tcl selftest   # the parser fixtures alone
tests/headless/run_suites.sh test_issue_stamp   # the full suite, gated
```

It needs no display, no simulator, no built binary and no T1 run. It runs under
plain `tclsh` **and** under `xschem --nogui --pipe -q --script`, so
`full_audit.sh` (which discovers `tests/headless/test_*.tcl` by `ls`) and
`run_suites.sh` both pick the suite up with no registration.

**Enforcement is forward only.**

* A file **carrying** a stamp is validated: grammar, closed vocabularies, `tree=`
  resolves, one stamp only, inside the header window, plus every marked block.
* A file **without** one is grandfathered **by number** in
  `issue_stamp_baseline.txt`. A numbered issue file whose number is *not* in that
  list and which carries no stamp is a failure.

So the unconverted set can shrink and never grow, and **the gate is green on the
corpus as it stands** — which is the hard constraint (`D9`): T1's baseline is
zero counted failures, a standing red is a defect rather than furniture, and a
checker that failed 1047 files on day one would be quietly disabled, which is
precisely how a cleanup rots.

### ⚠ The baseline is a list of numbers, not a count

A count-based non-regression gate passes when one grandfathered file is deleted
and one unstamped file is added — net zero, defect through. **Match by identity,
never by counting.** This is the harness batch's `W12b` lesson, and this batch
re-learned it twice in one evening: a `pgrep -af run_regression` that answered
four hits for one run *because the pattern matched the process typing it*, and a
`grep -lieE` that swallowed its own pattern and "measured" 1050 files in a corpus
of 1047.

### ⚠ A vacuous green is a broken checker wearing a pass

There are zero stamped files today, so every forward check has an empty input
set and would report success while doing nothing — the exact family that produced
**five** wrong driver measurements in one evening, every one a command returning a
plausible number without doing what was meant. So `gate` **self-tests against
known-answer fixtures first and reports nothing if it fails them**, and the suite
carries 34 checks of which 8 are red-observed. A green here means the parser was
exercised.

---

## 6. What this cannot see — stated, because an undocumented blind spot is worse than none

* **Prose below the fold is not validated.** The highest-consequence rot in the
  whole sample was 0071's child tables, and 0071's *header is correct*. Rule 4 of
  §3 (do not mirror; link) is the answer, and it is a convention, not a check:
  the `super=` coherence check can only compare two stamps, so it is blind until
  both files are stamped.
* **Cross-reference presence is not duplicate detection.** Issue 1458 names 1397
  in its own `Related:` line and duplicates it anyway.
* **Closure cannot be inferred from prose, and must be declared.** This is the
  best-measured rule in the spec, because the attempt was made and audited on the
  same day. The driver's `closescan.py` greps for *"fixes / closes / supersedes
  issue N"* and reported **7** issues closed-but-still-marked-open. Verified
  against the tree, **4 of the 7 were false** and the real class is **1 in 165**.
  The regex was blind three ways, none of which a pattern over English can fix:
  **negation** (*"FILED, **not** closed: issue 0516"* — the negation sits inside
  the pattern's own 40-character gap), **attribution** (*"CLOSED 2026-07-14
  (issue 0071 atom 6)"* closes 0003 and merely *credits* 0071), and
  **prescription** (*"…and fixes 0947 at the same time"* is an unimplemented
  option 3; a proposal is not an event). Acting on that table would have marked
  **two genuinely open defects closed, one carrying a live user ruling.**
  It also flagged **issue 0818 as claimed-closed by
  `tests/headless/issue_stamp.tcl`** — the file implementing this spec — from the
  sentence *"3 of 3 still **resolved**; and exactly one — **issue 0818** —"*. A
  citation *resolving* is not an issue being *resolved*, and a file written
  twenty minutes earlier silently moved a corpus-wide census. **That is why
  closure lives in `super=`, a declared field, and never in a regex over
  English**, and why `N1` locks it against a future improver.
* **Three independent sightings now say the truth is in the file, just not where
  anyone looks.** 0071's child tables; 1436's refutation living in
  `test_ase_dialogs.tcl` and 1395's in `src/ase_window.tcl`; and 0249's own
  `# RESOLUTION — FIXED` sitting **306 lines below** a header that still says
  OPEN.
* **A green T1 does not mean every suite arm is green.** Do not add a rule of the
  form *"no open issue may claim a red row while T1 is green"*: issue **1436**
  legitimately claims a red display-arm row, because `test_ase_dialogs` sits in
  `hcases` and **not** in `dcases`, so T1 never runs that arm. Such a rule would
  false-red the most careful file in the sample.

## 7. Designs considered and rejected

| shape | why not |
|---|---|
| `tree=` must equal `HEAD` | reddens the corpus on every commit; it *is* the `PLAN.md:3` defect, mechanised |
| a non-regression **count** of unstamped files | delete-one-add-one passes; identity, never counting |
| infer closure from *"fixes issue N"* prose | **4 of 7 flagged issues were false** when audited; blind to negation, attribution and prescription; and it false-positived on this spec's own implementation file within the hour |
| a self-test that asserts only a known **positive** | proves the check fires, never that it does not **over**-fire; that is exactly how the 4-of-7 above survived. Every check here carries a known negative too |
| validate only the first ten lines | scores 0071 — the worst file in the sample — green |
| check every `file:line` in `src/` and `tests/` | 937 across 27 `src/` files and 1190 in `tests/`; green-field rot, and reddening it on day one gets the checker disabled. **Report it; do not gate it.** |
| rewrite the 1047 files into a house style | not achievable by anyone, and it would become the seventh prescribed fix that damaged something |

## 8. Worked examples — proposed, not applied

These are what the stamp would say for real files. **No issue file was edited**;
adopting them is stage `D1`'s call.

| file | proposed stamp | what it fixes about today's header |
|---|---|---|
| **0442** | `` `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=superseded open=0 super=self by=A2` `` | says `STATUS: **OPEN.**` while the tree fixed it by 0442's own unnumbered alternative; `fix=superseded super=self` is what stops a reader pasting item 1 |
| **0891** | `` `v1 claim=partial tree=8608c7ef stamped=2026-09-17 fix=partial open=1 by=A3` `` | says three follow-ups are outstanding; **two landed**, one (drop `test_annot_stale_0684` from `dcases`) genuinely has not |
| **0905** | `` `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=superseded open=2 super=32dff39a by=A3` `` | closed against a design that lived hours; its §2 records as *deliberately rejected* the shape `32dff39a` shipped |
| **1219** | `` `v1 claim=latent tree=8608c7ef stamped=2026-09-17 fix=untried open=1 by=A3` `` + an `assert=absent pat=SABOTAGE path=src state=broken` block | its own numbers understate it (60 lines/28 files → **118/44**), and the `assert` block makes the tree close it automatically |
| **1438** | `` `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=taken open=0 super=1439 by=A4` `` | says *"Filed by the driver, not fixed"*; 1439 fixed it and 1439's header says so |
| **1458** | `` `v1 claim=duplicate tree=8608c7ef stamped=2026-09-17 fix=none open=0 super=1397 by=A4` `` | duplicates 1397 while citing it in `Related:` |
| **0216** | `` `v1 claim=partial tree=8608c7ef stamped=2026-09-17 fix=taken open=1 scope=ase-rerun-path by=D0` `` | fixed for the Location bar and `wviewer::restore`, **not** for the ASE re-run path; a binary schema closes it wrongly |
| **0650** | `` `v1 claim=partial tree=8608c7ef stamped=2026-09-17 fix=taken open=1 super=0655 by=D0` `` | the general channel landed at `5dd68128`; the **titular** session-window sink did not, and 0655 carries the remainder |
