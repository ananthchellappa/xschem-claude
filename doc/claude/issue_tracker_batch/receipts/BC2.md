# BC2 — the formatter that ate `scope=`, two wrong `open=` counts, and a deletion that never happened

**Status:** DONE

**Tree state:** started at **`794f93cb`**, measured the tree at **`d09ebece`** (which is the
revision every citation below and in the spec names), finished at **`72e2c85b`**. ⚠ **HEAD
moved twice while this task ran** (`794f93cb` → `d09ebece` → `72e2c85b`). Nothing needed
re-citing: `d09ebece` resolves (`git cat-file -e d09ebece^{commit}`), so every coordinate I
wrote is recoverable forever. That is BC1's requirement-4 dissolution demonstrated a third
time, on a third crew, by accident.

**Files touched (3, all tracked, none of them an issue file):**
* `tests/headless/issue_stamp.tcl` — the `format_stamp` fix, a scope-carrying selftest
  fixture, a derived fixture count, one misattributed comment corrected
* `tests/headless/test_issue_stamp.tcl` — three new rows (`S15b`, `S15c`, `B4`), all
  observed RED before they were green
* `doc/claude/specs/issue_stamp.md` — two `open=` counts, the §4 deletion sentence, the §3
  rule-4 misattribution, and the `scope=` vs `super=` rule the driver asked for

**Suites run:** `test_issue_stamp` only, on the `tclsh` arm and the
`./src/xschem --nogui --pipe -q --script` arm, plus `issue_stamp.tcl gate` on both.
**T1 was NOT run** (the driver runs it at the gate). **The checker was NOT registered in
T1's `hcases`** — `/usr/bin/grep -c issue_stamp tests/run_regression.tcl` → **0**, left to
the driver per D13. Every command carried a `timeout`. `./src/xschem` always by explicit
path, never a bare `xschem` (0924). `/usr/bin/grep` throughout.

---

## 1. Checker and suite, before and after — the hard constraint (D9)

**The gate is GREEN at its default setting on both arms, which is D9.**

| arm | | BEFORE (`794f93cb`) | AFTER |
|---|---|---|---|
| `tclsh` | gate | `self-test PASSED (16 parser cases)` · `ISSUE-STAMP: ok (0 problems)` · rc 0 | `self-test PASSED (17 parser cases)` · `ISSUE-STAMP: ok (0 problems)` · rc 0 |
| `tclsh` | suite | `RESULT: ALL PASS (40 checks)` · `OVERALL: ok` · rc 0 | **`RESULT: ALL PASS (43 checks)` · `OVERALL: ok` · rc 0** |
| `xschem --nogui` | gate | *(not run by D1; run here)* | `ISSUE-STAMP: ok (0 problems)` · rc 0 |
| `xschem --nogui` | suite | `RESULT: ALL PASS (40 checks)` · `OVERALL: ok` · rc 0 | **`RESULT: ALL PASS (43 checks)` · `OVERALL: ok` · rc 0** |

40 → 43 checks is the three new rows. 16 → 17 parser cases is the new selftest fixture, and
**that number is now derived from the fixtures rather than typed** (§5c).

Both arms were re-run a second time *after* the last two comment-only edits landed, because
those edits arrived after the first green and a green that does not cover the final bytes is
not evidence. Same result on all four.

---

## 2. Defect 1 — `istamp::format_stamp` silently dropped `scope=`

### What it did wrong

`format_stamp` wrote the fields by iterating a **hard-coded key list**:

```tcl
foreach k {claim tree stamped fix open super by} {
```

`scope` is absent from it, while `parse_stamp` accepts `scope=` and `ok_key` contains it.
So the **writer's vocabulary had silently diverged from the reader's**, and every round-trip
through the formatter deleted the one field that records a defect closed on **one route** and
live on another. That is the `STALE-OPEN` direction — the one the spec calls the dangerous
one — and it is the field standing between **0216** and being closed wrongly.

**Why nothing caught it for a day:** the selftest's round-trip fixture carried only the five
*required* keys and asserted only that the result **parsed**. A round-trip fixture whose
**input lacks a field cannot detect a formatter that drops it.** Vacuous green, inside the
machinery built to treat vacuous greens, for the second time after BC1's row `B1`.

### The fix

Key list now `{claim tree stamped fix open super scope by}`, ordered to match the spec's own
field table (§2), under a comment saying why the list must never drift from `ok_key` again.

### RED first — observed, on real data, and it named the file

The driver's note sized the blast radius as **one file**, so I built the corpus row against
**0216's actual on-disk stamp** rather than a synthetic one. Three rows and the gate's own
self-test went red before a line of `format_stamp` was touched.

**RED — `tclsh` arm, gate** (the checker refusing to issue a verdict at all, which is the
designed behaviour):

```
!! SELF-TEST FAILED -- no verdict reported.
  round-trip LOST OR CHANGED a field: wrote {by D1 claim partial fix taken open 1 scope ase-rerun-path stamped 2026-09-17 super 0655 tree 61af3692}, read back {by D1 claim partial fix taken open 1 stamped 2026-09-17 super 0655 tree 61af3692} via **STAMP:** `v1 claim=partial tree=61af3692 stamped=2026-09-17 fix=taken open=1 super=0655 by=D1`
shell rc=1
```

**RED — suite, identical on BOTH arms:**

```
      got:  0
      want: 1
S15b the formatter EMITS scope= -- it used to drop the field silently : FAIL
      got:  1 0
      want: 1 1
S15c a round-trip carrying EVERY optional field loses nothing : FAIL
      got:  0216:scope
      want:
B4 every stamp in the real corpus round-trips through the formatter with no field lost : FAIL
      got:  1
      want: 0
D9b the self-test is a precondition of any verdict, not a separate command : FAIL
RESULT: 4 FAILED (39 passed)
OVERALL: notok
suite rc=1
```

`B4`'s `got: 0216:scope` is the whole finding in six characters: **the real corpus, the real
file, the lost key, by name.**

**GREEN after the fix — identical on BOTH arms:**

```
ok:   S15b the formatter EMITS scope= -- it used to drop the field silently
ok:   S15c a round-trip carrying EVERY optional field loses nothing
ok:   B4 every stamp in the real corpus round-trips through the formatter with no field lost
ok:   D9b the self-test is a precondition of any verdict, not a separate command
RESULT: ALL PASS (43 checks)
OVERALL: ok
suite rc=0
```

### The three new rows, and why each is shaped as it is

* **`S15b`** — the formatter *emits* `scope=`. The narrow, direct assertion.
* **`S15c`** — a round-trip carrying **every** optional field, asserted as a **whole dict**
  rather than as `ok`. This generalises past `scope`: a key added to the grammar and
  forgotten in the formatter reddens here. Compared through a new `istamp::dict_canon`
  helper so the row asks *"did a field go missing?"* and **not** *"did anyone reorder the
  key list?"* — an over-firing row on a 1047-file corpus is worse than no row, because it
  gets the checker disabled (D9).
* **`B4`** — the **real corpus**, every stamped file, parse → format → parse, reporting the
  lost key by issue number. `format_stamp` is the *writer*: if it cannot reproduce what is
  already on disk, then any future `restamp` helper corrupts the corpus silently. Field-wise
  and canonicalised, for the same anti-overshoot reason.

The same scope-carrying round-trip was added to `istamp::selftest`, because `gate` self-tests
**before** it reports anything — so the checker now refuses to issue a verdict if the writer
and reader have drifted, rather than emitting a confident green over corrupted data.

### ⚠ Does the fix change how the ten committed stamps round-trip? **No. Measured.**

The brief required me to say so rather than rewrite anything. Every one of D1's ten committed
stamps survives the **fixed** formatter **byte-for-byte**:

```
$ tclsh <scratch>/roundtrip.tcl
0056 BYTE-IDENTICAL   0216 BYTE-IDENTICAL   0249 BYTE-IDENTICAL   0442 BYTE-IDENTICAL
0650 BYTE-IDENTICAL   0891 BYTE-IDENTICAL   0905 BYTE-IDENTICAL   1219 BYTE-IDENTICAL
1438 BYTE-IDENTICAL   1458 BYTE-IDENTICAL
byte-identical=10  differs=0
```

Placing `scope` between `super` and `by` is what makes this true: 0216 carries a scope and no
super, 0650 a super and no scope, and no stamped file carries both. **No stamp was edited and
none needed to be.**

---

## 3. Defect 2 — two wrong `open=` counts in spec §8

Both re-derived here from the tree and from each file's own list. **I did not inherit D1's
numbers**; both happen to agree with D1, and both disagree with the spec.

### 0442 → `open=1`, not `open=0`

0442's "Still open" section carries **three** items. Two are fixed:

| item | verdict | command, and what it showed at `d09ebece` |
|---|---|---|
| 1. the four unfiltered netlister drop classes | **FIXED** | `/usr/bin/grep -n "proc op_annot::_netlisted" src/op_annot.tcl` → `2879:proc op_annot::_netlisted {i idx {block {}}}`. The body consults the **deck index** (`dict get $idx elems`), not symbol attributes; `spice_sym_def` / `default_schematic` / `spice_stop` appear in `src/op_annot.tcl` **only inside comments** documenting what the oracle does. The seven-class truth table is in the file. Fixed by 0442's own unnumbered alternative — *derive the device set FROM `xschem netlist` output* |
| 2. `_netlisted` hardcodes the SPICE class; `skip_instance()` branches on `netlist_type` | **OPEN** | `/usr/bin/grep -n "_force_netlist_env\|netlist_type" src/op_annot.tcl` → `2562:proc op_annot::_force_netlist_env`, `2567:  catch {xschem set netlist_type spice}`. Not fixed — **converted into a declared constraint.** The comment at `:2548` states the reason outright |
| 3. the `spiceprefix=X` card prefix | **FIXED** | `/usr/bin/grep -n spiceprefix src/op_annot.tcl` → `2850:  if {[catch {xschem translate $instname {@spiceprefix@name}} e]}`, under a comment at `:2841` reading *"⚠ `xschem translate`, NEVER `getprop instance <n> spiceprefix`"* |

**One of three stands ⇒ `open=1`.**

### 0650 → `open=5`, not `open=1`

`open=` is defined by the spec as *"how many items **the file itself says** are still
outstanding"*, so the file's own closing list plus each child's own header is the correct
source — and I checked the one child whose claim could make the count **too small**.

0650's closing section names six follow-ups. Command:
`for f in 0654 0655 0658 0659 0660 0661; do head -12 doc/claude/issues/${f}-*.md; done`

| child | its own header says | |
|---|---|---|
| 0654 | `Status: OPEN (measured, accepted as the fallback sink anyway…)` | open |
| 0655 | `Status: OPEN (deferred out of issue 0650 deliberately)` | open — **the titular one** |
| 0658 | `Status: **FIXED 2026-08-24**` | **not** open |
| 0659 | `Status: OPEN (measured, NOT fixed)` | open |
| 0660 | `Status: OPEN (measured, NOT fixed)` | open |
| 0661 | `Status: OPEN (measured, NOT fixed)` | open |

**Five of six ⇒ `open=5`.** `open=1` counted the titular half alone and rounded four live
follow-ups away.

**0658 was additionally checked against the tree, because a wrongly-FIXED child is the one
error that would make this count too small** — the dangerous direction. `proc ase::echo` at
`src/ase.tcl:314` now delegates to `::xschem::notify_safe` inside a `catch` that falls back to
stderr and returns 0, under a comment block naming *"0658 D9"* and *"CLOSED by issue 0663"*.
The tree agrees with the header. **Not open.**

Two lighter tree confirmations, in the other direction: `/usr/bin/grep -c ciw_echo
src/ase_window.tcl` → **1** against **114** `ase::echo` references — 0655's subject is
substantially live; and 0659/0660/0661 all read `NOT fixed` in their own voice.

---

## 4. Defect 3 — spec §4 misstated a deletion

§4's `fix=` worked example read:

```
op_annot::_netlisted {i}   ;# the shape 0442 prescribed, and the tree deleted
```

**`proc op_annot::_netlisted` is live**, at `src/op_annot.tcl:2879`, signature
`{i idx {block {}}}`. What the tree deleted is its **shape** — the one-argument probe that
mirrored symbol attributes. Corrected to:

```
op_annot::_netlisted {i}   ;# the ONE-ARGUMENT symbol-attribute probe 0442
                           ;# prescribed. The SHAPE is gone; the proc is not.
```

…plus a ⚠ block explaining why the word matters: `fix=superseded` exists precisely for the
case where **the name survived and the option did not**, and a reader who checks *"the tree
deleted `foo`"* against a live symbol stops believing the document.

**A second wrong sentence sat directly beneath it** and is corrected in the same block:
*"the file's own header records why the prescribed shape was abandoned."* 0442's header
records no such thing — it reads `STATUS: **OPEN.**`. What records why is the **unnumbered
alternative at the end of its own fix section**, which is exactly why `super=self` is right
for that file.

---

## 5. Departures from the brief, each stated at the moment of making it

**(a) The `scope=` vs `super=` rule in spec §2 — asked for by the driver mid-task.**
D1 stamped 0216 with `scope=` and 0650 with `super=`; the spec did not say which applies
when. **I agree with D1's choice and wrote the rule that makes it principled**, as a new §2
subsection: the test is *"is there somewhere else to look?"* — `super=` names a successor
that **carries the remainder** (0650 → 0655, a file that exists), `scope=` names a route the
claim does not cover **and which nothing else carries** (0216's ASE re-run path has no issue
of its own; verified — 0216 names no successor). They are independent, not alternatives, and
a file may carry both.

**(b) Two misattributed citations corrected, beyond the three assigned.** D1's finding F4
measured that *"a hand-maintained mirror of another module's rules is wrong by
construction…"* is attributed to **0442's own header** and is not in 0442 at all. I
re-measured: `/usr/bin/grep -c 'hand-maintained mirror'` over 0442 → **0**; the only copies
in the tree are `src/op_annot.tcl:2321` and the checker's own comment. **Both sites were
wrong and both are fixed** — spec §3 rule 4, and `tests/headless/issue_stamp.tcl`'s `gate`
comment. Leaving a knowingly-invented citation inside a spec *about invented citations*, while
editing the paragraph beside it, was not defensible.

**(c) `selftest_case_names` no longer hand-counts.** It returned a literal `lrepeat 16 x`
with the arithmetic `5 good + 10 bad + 1 round-trip` in a comment beside it — **a
hand-maintained mirror of a number living somewhere else**, inside the checker built to treat
that defect, which would have gone stale the moment anyone added a fixture. It is now derived
from the fixtures actually executed. It printed `17 parser cases` after my fixture landed with
no edit from me, which is the point.

Each of (a), (b) and (c) is one to three lines and any of them can be reverted alone.

---

## 6. Things in the brief, the spec or a driver message that are wrong

**The driver's ledger stands at twenty. These are candidates 21 and 22; the second is mine.**

### 21 — "`scope=` appears exactly ONCE in the whole 1047-file corpus" is false as stated

The driver's mid-task note sized my first defect with that sentence. Measured at `d09ebece`:

```
$ /usr/bin/grep -rn "scope=" doc/claude/issues/*.md
0216-…:3:**STAMP:** `v1 … scope=ase-rerun-path by=D1`
0307-…:65:PROBE-5 entry: model='dcell' … scope='TOP.dcell'
0307-…:74:PROBE-5 entry: model='cnt8'  … scope='TOP.cnt8'
```

**Three hits, not one.** The driver's *conclusion* is correct — exactly one **stamp** carries
a scope, and the blast radius really was one file — but the stated measurement is a grep over
prose, and two of its hits are ngspice PROBE log lines quoted inside an issue. **A grep over
the corpus is not a census of stamps**, which is the same lesson as `pgrep -af` answering four
hits for one run and `grep -lieE` answering 1050 for 1047: *match by identity, not by
pattern.* The checker already does it right — `find_stamp` is anchored, and `B4` iterates
parsed stamps. Low consequence here; recorded because the batch's own subject is a plausible
number produced by a command that did not do what was meant.

### 22 — **mine.** I wrote "the table below has been corrected to match" and did not correct the table

Editing spec §8, I added a ⚠ block stating both counts had been fixed **and the two table
rows still read `open=0` and `open=1`.** I caught it only by grepping the rows back out of the
file afterwards, instead of trusting my own edit. **A document asserting a correction it did
not make** is this batch's disease with my name on it — and it is the precise shape of D2's
warrant (510 files whose header disagrees with their body, because someone appended a
correction without touching the thing it corrected). Both rows are now fixed and **read back
from the artefact**, not asserted:

```
$ /usr/bin/grep -n "^| \*\*0442\*\*\|^| \*\*0650\*\*" doc/claude/specs/issue_stamp.md
443:| **0442** | … fix=superseded open=1 super=self by=A2 … | **`open=1`, corrected from `open=0`** …
450:| **0650** | … fix=taken open=5 super=0655 by=D0 …      | **`open=5`, corrected from `open=1`** …
```

CLAUDE.md's own arithmetic paragraph records being wrong three times, *the third time in the
correction itself*. This is that, in a different file, the same evening. **Take the number
from the artefact — including when you are the one who just wrote it.**

### Smaller, recorded not fixed

* **Spec §8's header was stale.** It read *"proposed, not applied … adopting them is stage
  `D1`'s call"*, and D1 applied all ten hours earlier. Corrected to say they were applied, and
  that the applied stamps carry `tree=61af3692 by=D1` rather than the proposed `tree=8608c7ef`
  values the rows still show.
* **0442 contains a rotted coordinate for the very claim I was verifying.** Its item 2 cites
  `netlist.c:1247-1257` for `skip_instance()`'s `netlist_type` branch; `src/op_annot.tcl:2320`
  cites `netlist.c:1277` for the same code. **Not fixed — issue files were out of bounds for
  me.** Worth noting that the spec's own worked example of citation rot contains citation rot.
* **`tests/headless/issue_stamp_baseline.txt` is now TRACKED** (`git ls-files
  --error-unmatch` succeeds), so D1's finding **F3** is resolved. No action needed.

---

## 7. Claims checked vs taken on trust

**Re-measured, not inherited:** both `open=` counts, item by item, against the tree and
against each child's own header; `_netlisted`'s live signature and deck-index body;
`_force_netlist_env` forcing `netlist_type spice`; `_element` building the identity from
`xschem translate {@spiceprefix@name}`; 0658's fix in `ase::echo`; `ciw_echo` = 1 against 114
`ase::echo` refs in `ase_window.tcl`; the "hand-maintained mirror" sentence's real home and
its absence from 0442; that 0216 names no successor; the `scope=` corpus census; that
`d09ebece` resolves; that the ten committed stamps round-trip byte-identically; every
before/after number in §1, from the run output rather than from arithmetic.

**Taken on trust (said so rather than guessed):** the driver's per-field verification of the
ten stamps (line 3, `v1`, `tree=61af3692` resolving, the `claim=`/`fix=` distributions) — I
re-derived only the round-trip property, not the whole table; D1's verdicts on the files I had
no reason to open (0891, 0905, 1219, 1438, 1458); A1–A4's per-file sample verdicts; that
0654/0659/0660/0661's OPEN headers are true of the tree — I read their headers and 0650's own
list, and checked only 0658 against the code, because that is the only one whose being wrong
would make `open=` **too small**.

---

## 8. Left dirty

Nothing committed. **Three modified tracked files and this receipt:**

```
 M doc/claude/specs/issue_stamp.md
 M tests/headless/issue_stamp.tcl
 M tests/headless/test_issue_stamp.tcl
?? doc/claude/issue_tracker_batch/receipts/BC2.md
```

`git diff --stat`: **3 files changed, 253 insertions(+), 22 deletions(-)**. The 22 deletions
are entirely replaced comment and prose lines; **no issue file was opened for writing** —
`git status --short doc/claude/issues/` is empty, and D1's ten stamps are untouched.

**No number was minted; `NUMBERING.md` is untouched.** `tests/headless/owed.sh` and
`~/.claude/xschem_owed/` were **not read or written**. The checker is **not** registered in
T1's `hcases`. Scratch drivers (`gate_drv.tcl`, `roundtrip.tcl`) live in the session
scratchpad, outside the repo; the suite sweeps its own fixtures from `tests/headless/.scratch/`.

Pre-existing untracked dirt, unchanged by me: `.xschem/`, `doc/claude/rdw_lists_batch/`,
`doc/claude/rdw_sim_batch/`, `sky130A/.../debug_st1/`.

## 9. Owed to the user

**Nothing.** Every decision here is internal engineering — a key list in a formatter, what a
test row asserts, how a spec words a rule about its own fields. None of it reaches a person
using XSCHEM, so per the standing rule none is a ruling and none was filed as one. Nothing was
converted, cleared or added to any ledger.

Three decisions are recorded as **mine**, with the evidence, so the driver can overturn any of
them in one line: the `scope=`/`super=` rule endorsing D1's stamping choice (§5a); correcting
two misattributed citations beyond the three assigned (§5b); and deriving the selftest fixture
count instead of hand-writing it (§5c).
