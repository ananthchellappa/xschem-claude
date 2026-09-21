# D-impl — item D (issue 1489): the issue-stamp checker stops false-alarming on honest markdown

**Crew** D implementer. **Date** 2026-09-20. **Tree** `fluid-editing`, cloned at `a1314271`,
landed on `04844d23` (the three files are byte-identical between those two commits, checked with
`git diff --stat a1314271 04844d23 --` on them: empty).
**Scratch** `/var/tmp/xsr_d`, deleted; **peak 1.8 GB** (`w` 171 M + `b` 165 M + `cand` 165 M +
`s` 1.3 G, the six stranger shapes).
**Files changed, all in the main tree, nothing committed:**

| file | md5 before (`d42fc517`'s bytes) | md5 after |
|---|---|---|
| `tests/headless/issue_stamp.tcl` | `6d0592ad9dfcbefc24e17f1e5a97c202` | `8e8966382287e6e78cd71a083e76dc0d` |
| `tests/headless/test_issue_stamp.tcl` | `930eb4359ffda3528fa40cf086af884c` | `881a05c1c16e3594a77c5e7cf6ce2a0f` |
| `doc/claude/specs/issue_stamp.md` | `1d4f8efba7d66232e801ec2bb27339e7` | `91b4796a2edf0c83e3a6020306993bd5` |

`git diff --stat`: **1179 insertions, 121 deletions** over those three files. No other file in the
repository was written.

---

## 1. What landed, and what did not

### 1.1 The candidate patch already excluded both D21 exclusions

`doc/claude/outsider_fixes_batch/patches/1489-s1fix10-candidate.patch` applied clean (`patch -p1`,
three files, no fuzz). Contrary to what the task description assumed, **S1-fix10 had already
withdrawn the in-fence body exemption and the container-stripped scan** — it is the round that was
built *after* D21 said to withdraw them. Nothing had to be removed. Four independent checks that
they left nothing behind:

1. **Proc-level byte diff.** The four procs that would have to carry either mechanism are
   byte-identical to `d42fc517`'s: `stray_stamps` (23 lines), `stamp_shaped` (7), `md_strip` (4),
   `stray_cause` (7). `diff -u` on each pair is empty.
2. **Corpus-wide behavioural diff** (`/var/tmp/xsr_d/m/pdiff.tcl`, two `interp`s, one per
   checker, over every `NNNN-*.md`): **1060 files, 5046 fence lines, differences
   `find_blocks=0 stray_stamps=0 stray_attrs=0`** between `d42fc517` and the landed bytes.
   `stray_stamps` identical over the whole corpus is the direct statement that the exemption is
   absent.
3. **Suite rows Q19 and Q22**, which assert the documented limit (a stamp body inside a closed
   fence, and inside a blockquoted / nested-list / fence-in-a-fence container, is ONE named
   problem), **PASS on `d42fc517` and PASS on the landed bytes** — the only two of the eight new
   rows that are green on `d42fc517`. A row that is green on both is a row that measures no change.
4. **Gate-level**: fixture `b16_body_in_fence` (a `**STAMP:**` body inside a ```` ```text ````
   fence) is `1 problem(s)`, rc 1, on base and on fix alike.

### 1.2 What landed from D21's list

All five, **plus one repair** the list needs in order to be landable:

| D21 item | landed | note |
|---|---|---|
| a fence is marked only by a marking key (`quote assert path pat state`) | yes | `fence_marks` in `fence_info` |
| typo'd marking keys are named; case/spacing variants named once | yes, **widened** | see 1.3 |
| a backtick in a backtick fence's info string opens no fence | yes | `fence_scan`'s opener test |
| the `assert=` budget charges scanning time only; the gate's wall clock is its own named budget | yes | `scan_spent_us`, `gate_deadline`, `t_gate_total 600` |
| problem text is capped | yes | `clip`, `fence_bad_shown 5`, `cap_lines`/`problem_cap 2000` |

### 1.3 The repair, and why the patch could not land as it stood

**S1-fix10 was refuted on exactly one regression family, caused by the backtick-in-info-string rule
alone** (`receipts/S1_verify.md`, last section), which is why issue 1489 exists rather than a
commit. Reproduced here, red-first, as fixtures `f3b`, `f3c`, `f3d`:

* `d42fc517` treats a column-0 ```` ```make install``` fails ```` line as a fence opener, so a real
  ```` ```sh asert=absent pat=SABOTAGE path=src state=holds ```` fence below it is swallowed as
  text — and `stray_attrs` matches only `(quote|assert)[ \t]*=`, which no misspelling matches.
  **`ok (0 problems)`, rc 0, over a FALSE claim** (SABOTAGE is on 8 lines under `src`).
* The candidate reads that line correctly as inline code, and therefore pairs the bare ```` ``` ````
  that was meant to *close* a ```` ```sh `make` output ```` line as an **opener** — swallowing the
  fence below *that*. Same silence, one line down. Its own backtick-info line (`f3b`) goes the same
  way, and so does a lone `asert=absent` (`f3d`, item 1's own consequence).

The refuter named the cure in its own `class_B_followups` (*"stray_attrs could also match
misspelled marking keys … Either would restore d42's naming without undoing the CommonMark opener
rule"*), and observed that **each pairing rule has a hole on the side the other one closes**
(`z_r3_*` pass on `d42fc517`, `z_flip_*` pass on the candidate). So the fix is not to choose a
side. It is to stop asking the question:

> **`stray_attrs` now tests the key on the fence line's own info string, with nothing asked about
> the fences around it.** A word shaped `key=` whose key is one edit from `quote` or `assert` — a
> letter left out (`asert`), typed twice (`asssert`), typed wrong, typed the wrong way round
> (`qoute`), or a truncation or extension (`quot`, `quotes`, `assertion`) — is a named problem. It
> is silent only when a block the gate READ came from that very line, where `fence_info` names the
> word already, so it is named exactly **once**.

New code: `near_miss_key` (the predicate, **length-bounded before any loop runs** — D18-A),
`misspelled_mark` (the first such word in an info string), `attr_words` and `stray_why` (the two
existing message halves, factored out so both passes share one cause chain rather than a copy).

**Anti-overshoot, because one letter separates `assert=` from `asset=`.** The predicate's whole
neighbourhood was enumerated (285 near misses of `quote`, 335 of `assert`) and eyeballed for real
words: `asset`, `assent`, `assort`, `quota`, `quite`, `quoted`, `quotes`, `quoter`. Rather than an
exclusion list — which would be a fail-OPEN on a typo that happens to be a word — a misspelling
counts only where the fence is **visibly a block**: another key of the grammar in the same info
string, or the misspelled key's own value (`absent`/`present` for `assert=`, a revision token for
`quote=`). Measured silent afterwards: `js asset=x`, `sh quota=10 ulimit`, `text assent=y`,
`md quite=1`, `sh assort=z`, `c quoted=true`, `sh quotes=3`, `sh asert=x`, `c qoute=zzz`.
Measured named: `sh asert=absent`, `c qoute=d64686a1`, `js asset=absent`.
The residue (`asset=absent path=x` is named and must be renamed) is written into spec §6.

### 1.4 Deliberately NOT landed

* **The in-fence body exemption and the container-stripped scan** (D21): absent from the candidate,
  and proved absent four ways above.
* **Nothing else was touched.** No product code, no other suite, no other spec.

---

## 2. The four false alarms, before and after

Each is one throwaway corpus of one stamped issue file (`1601-case.md`, stamp
`` `v1 claim=open tree=a1314271 stamped=2026-09-20 fix=none open=1 by=impl-d` ``), run through
`issue_stamp.tcl gate <corpus> <empty-baseline>` on `d42fc517`'s bytes and on the landed bytes.

### Pair 1 — an mkdocs `title="…"` fence (`f1_title`)

```
```python title="example.py"
```

| | verdict |
|---|---|
| **base** | `1601:7: a marked fence the parser cannot read in full -- ` `` `title="example.py"` `` ` has a key the grammar does not know (known: quote path fix assert pat state) …` — **rc 1** |
| **fix** | `ok (0 problems)` — **rc 0** |

### Pair 2 — a build line, `cc=gcc` (`f2_cc`), and `prefix=/usr` (`f2b_prefix`)

| | `f2_cc` | `f2b_prefix` |
|---|---|---|
| **base** | rc 1, `` `cc=gcc` `` has a key the grammar does not know; `` `make` `` is not a key=value word | rc 1, three bad words |
| **fix** | `ok (0 problems)`, rc 0 | `ok (0 problems)`, rc 0 |

Control `f2c_fixlabel` (```` ```tcl fix=superseded ````) is green on both: `fix=` was already a
known key, so it never produced a bad word — it is now simply not read at all.

### Pair 3 — a typo'd marking key passing unnoticed

Three shapes, all carrying a **FALSE** assertion (`pat=SABOTAGE path=src state=holds`, 8 real hits)
or a **ROTTED** quote, so a silent pass is a claim about the tree that nothing checked:

| fixture | shape | base | candidate | **fix** |
|---|---|---|---|---|
| `f3a_typo_slack` | `asert=` under a column-0 ```` ```make install``` fails ```` line | **rc 0, `ok (0 problems)`** | rc 1 | rc 1 |
| `f3e_qoute_slack` | `qoute=` the same way | **rc 0, `ok (0 problems)`** | rc 1 | rc 1 |
| `f3c_typo_flip` | `asert=` under the bare ```` ``` ```` that closes a ```` ```sh `make` output ```` line | rc 1 | **rc 0, `ok (0 problems)`** | rc 1 |
| `f3b_typo_btinfo` | `asert=absent pat=` `` `SABOTAGE` `` (backtick in the info string) | rc 1 | **rc 0** | rc 1 |
| `f3d_typo_alone` | ```` ```sh asert=absent ```` alone | rc 1 | **rc 0** | rc 1 |

`fix` text for `f3c`: `1601:9: `asert=absent` on a fence, which is `assert=` misspelled, so the
parser does not read the block (inside another fenced block, where it is text, not a fence) -- it
is never evaluated, so a claim about the tree written there passes silently whether it holds or
not; write it as a closed, column-0 ``` fence in a stamped file`.

Matrix over the whole set (direct `stray_attrs` + `fence_info` calls,
`/var/tmp/xsr_d/m/probe.tcl`): **65 rows**, keys `assert asert assertion asserts assrt asssert
ASERT quote qoute quotes quot uqote` × contexts `plain slack flip unclosed tilde indented btinfo`.
**61 rows name the defect exactly once**; the 4 rows at 0 are the correctly-spelled `assert`/
`quote` in the two contexts where the gate reads and evaluates them. No row is ever named twice.

### Pair 4 — a backtick in an info string (`f4_btinfo_falsered`, `f4b_quote_falsered`)

An honest, closed, column-0 `assert=` (TRUE) and `quote=` (holds) fence, under a Slack-style
```` ```make install``` fails here, so: ```` line:

| | `f4` assert= | `f4b` quote= |
|---|---|---|
| **base** | rc 1, `an assert= the parser does not read (inside another fenced block, where it is text, not a fence) …` | rc 1, `a quote= the parser does not read (inside another fenced block …)` |
| **fix** | `ok (0 problems)`, rc 0 — the block is read and evaluated | `ok (0 problems)`, rc 0 — the quote is verified |

Controls `f4c_quote_ctl` / `f4d_assert_ctl` (the same fences with no Slack line above) are green on
both, so the Slack line alone made the base's red.

### Fifth item — the `assert=` budget charged the wrong thing

Corpus: one stamped file with **700 valid `quote=` blocks that all hold**, then one **TRUE**
`assert=absent pat=zz_nonexistent_symbol_qq path=src state=holds`. Nothing in it is wrong.

| | verdict | elapsed |
|---|---|---|
| **base** | `1601:2805: assertion could not be evaluated -- the search ran past the gate's total budget of 60 s for all the assert= scans of one run …` — **rc 1** | 74.39 s |
| **fix** | `ok (0 problems)` — **rc 0** | 74.70 s |

The base's 60 s "scan budget" was a wall clock started with the gate, so the git work of 700
quotes spent it; the landed bytes charge only scanning time (`scan_spent_us`) and give the gate's
wall clock its own named budget (`t_gate_total`, 600 s).

---

## 3. Fail-closed (D18 rule B) — every honest mistake is still RED

Eighteen fixtures, one stamped (or deliberately unstamped) issue file each, same corpus harness,
**run on `d42fc517` and on the landed bytes**. Every row is rc 1 on **both**, with the same problem
count — the fix removes no red.

| # | fixture | the defect | base | fix |
|---|---|---|---|---|
| 1 | `b01_bogus_tree` | `tree=deadbee0`, resolves to nothing | 1 problem, rc 1 | 1 problem, rc 1 |
| 2 | `b02_typo_tree` | `tree=a1314272`, one digit off a real revision | 1, rc 1 | 1, rc 1 |
| 3 | `b03_blob_tree` | `tree=85d1e64f`, a **blob** oid, not a commit | 1, rc 1 | 1, rc 1 |
| 4 | `b04_offhead_tree` | `tree=84ad8320`, a commit that exists and is **not an ancestor of HEAD** (an amended-away one) | 1, rc 1 | 1, rc 1 |
| 5 | `b05_rotted_quote` | `quote=a1314271` over text the file does not hold | 1, rc 1 | 1, rc 1 |
| 6 | `b06_false_assert` | `assert=absent pat=SABOTAGE path=src state=holds`, 8 real hits | 1, rc 1 | 1, rc 1 |
| 7 | `b06b_stale_fixed` | `state=broken` on an assertion that now HOLDS (the stale-fixed detector) | 1, rc 1 | 1, rc 1 |
| 8 | `b07_unstamped` | a new issue file with no `**STAMP:**`, not in the baseline | 1, rc 1 | 1, rc 1 |
| 9 | `b08_missing_key` | a stamp missing the required `open=` | 1, rc 1 | 1, rc 1 |
| 10 | `b09_bad_date` | `stamped=0000-00-00`, not a day on the calendar | 1, rc 1 | 1, rc 1 |
| 11 | `b10_decimal_tree` | `tree=13142710`, hex-shaped with no `a`–`f` | 1, rc 1 | 1, rc 1 |
| 12 | `b11_underscore_stamp` | `__STAMP:__`, a near-miss spelling | 2, rc 1 | 2, rc 1 |
| 13 | `b12_colonless` | `**STAMP**` with the colon lost | 2, rc 1 | 2, rc 1 |
| 14 | `b13_indented_quote` | a rotted `quote=` in a 2-space-indented fence | 1, rc 1 | 1, rc 1 |
| 15 | `b14_tilde_assert` | a false `assert=` in a `~~~` fence | 1, rc 1 | 1, rc 1 |
| 16 | `b15_unclosed_assert` | a false `assert=` in a fence the file never closes | 1, rc 1 | 1, rc 1 |
| 17 | `b16_body_in_fence` | a stamp body inside a ```` ```text ```` fence (**the D21 documented limit**) | 1, rc 1 | 1, rc 1 |
| 18 | `b17_multiword_pat` | `pat="static int"`, a multi-word pat on a marked fence | 1, rc 1 | 1, rc 1 |

Plus the five rows of §2 pair 3, which are **more** fail-closed than either predecessor, and
`f5_assert_alone` (a lone canonical `assert=absent`, no `pat=`/`path=`/`state=`): `an assert= block
needs pat=, path= and state=holds|broken`, rc 1 on both.

---

## 4. Strangers (D18 rule C) — every shape green, every skip named

Built from the landed bytes; each shape gets the landed `issue_stamp.tcl` copied in and is run with
`tclsh tests/headless/issue_stamp.tcl`. Skips are counted as `NOT VERIFIED` lines (27 per-revision
lines plus the verdict's own tail).

| shape | how it was built | history state | verdict | rc |
|---|---|---|---|---|
| renamed clone | `git clone w s/a-different-name` | `full` | `ok (0 problems)` | 0 |
| worktree | `git worktree add s/wt fluid-editing` | `full` | `ok (0 problems)` | 0 |
| shallow clone | `git clone --depth 1 file://w` | `shallow` — boundary `a1314271` | `ok (0 problems; 27 revision(s) NOT VERIFIED -- shallow: history absent)` | 0 |
| git-archive export | `git archive HEAD \| tar -x`, no `.git` | `none` | `ok (0 problems; 27 … NOT VERIFIED -- none: history absent)` | 0 |
| export inside another repo | that export copied into a `git init`+commit outer repo | `none` | `ok (0 problems; 27 … NOT VERIFIED -- none: history absent)` | 0 |
| unborn repository | that export + `git init`, nothing committed | `unborn` | `ok (0 problems; 27 … NOT VERIFIED -- unborn: no commits yet)` | 0 |

Every skipped revision is named individually by issue number and `tree=`, e.g.
`ISSUE-STAMP: NOT VERIFIED 1219: tree=61af3692 (shallow: beyond the depth?)`.

---

## 5. Suites, counts, and red-first

`tests/headless/run_suites.sh --nogui test_issue_stamp` (`AUDIT_DISPLAY=none`, throwaway HOME,
`SUITE_TIMEOUT=2400` — the suite builds ~20 git fixtures and runs for several minutes, well past
the 200 s default):

| tree | verdict |
|---|---|
| `d42fc517` (base) | `PASS | test_issue_stamp run 1/1 RESULT: ALL PASS (93 checks)` |
| **landed bytes** | `PASS | test_issue_stamp run 1/1 RESULT: ALL PASS (101 checks)` |

**0 `skip:` lines** in either. The 8 new rows are `Q18 Q19 Q20 Q21 Q22 Q23 Q24 Q25`; seven came
with the candidate patch, `Q25` is mine.

Checker self-test cases (`issue_stamp.tcl selftest`, the number the gate prints):
**87 → 122 (candidate) → 170 (landed)**. The 48 added here are the misspelled-marking-key matrix
(26 fence texts, counting `stray_attrs` **plus** every read block's bad words, so a row cannot pass
by one check silently taking over another's work) and `near_miss_key`'s own fixtures (22, including
a 200 000-character key that must answer 0 without entering a loop).

The checker on the **real corpus**, `tclsh tests/headless/issue_stamp.tcl`:
`self-test PASSED (170 parser cases)` / `history: full` / **`ISSUE-STAMP: ok (0 problems)`**, in
1.72 s against the base's 1.60 s, on the live main-tree corpus at `04844d23` (1061 issue files,
including 1496 which landed while this item was being measured).

### Red-first, by row

The same suite file run against three checkers:

| checker | verdict | rows that FAIL |
|---|---|---|
| `d42fc517` | `7 FAILED (94 passed)` | `Q14 Q18 Q20 Q21 Q23 Q24 Q25` |
| S1-fix10 candidate | `1 FAILED (100 passed)` | `Q25` |
| **landed bytes** | **`ALL PASS (101 checks)`** | — |

`Q19` and `Q22` pass on `d42fc517` too, which is the point of §1.1: they assert the *documented
limit*, and the limit is unchanged.

`Q25`'s own got/want, read off the logs — each entry is
`{problems for that file, of which the new check's}`:

```
d42fc517  got:  {0 0} {1 0} {1 0} {1 0} {1 0} {0 0} {1 0} {1 0} {1 0} {1 0} {1 0} {1 0}
candidate got:  {1 0} {0 0} {0 0} {0 0} {0 0} {1 0} {0 0} {0 0} {0 0} {0 0} {1 0} {1 0}
landed    got:  {1 0} {1 1} {1 1} {1 1} {1 1} {1 0} {0 0} {0 0} {0 0} {0 0} {1 0} {1 0}   (= want)
```

Read the first six columns as the defect shapes and the next four as the honest ones: `d42fc517` is
silent on its own two swallowed shapes (`{0 0}` at 9271, 9276) **and false-reds all four honest
word keys** (`{1 0}` at 9277–9280); the candidate fixes the honest four and goes silent on the four
shapes its opener rule swallows; the landed bytes name every defect exactly once and every honest
fence not at all.

---

## 6. Safety (D18 rule A) — no unbounded CPU from corpus text

The new code is the only place corpus text reaches a character loop, so it was measured directly
(Tcl 8.6.17):

| probe | time | answer |
|---|---|---|
| a 1 MB key word (`aaa…=absent`) on a marked fence | 63 ms | 0 problems |
| a 1 MB key word (`qqq…=d64686a1`) | 24 ms | 0 |
| 200 000 key-shaped words on one fence line | 744 ms | 1 |
| 200 000 plain words on one fence line | 150 ms | 0 |
| a 1 MB `pat=` value beside a misspelled key | 35 ms | 1 |
| 50 000 fence-shaped lines | 1063 ms | 50 000 |
| 200 000 `>` blockquote markers on a fence line | 2 ms | 1 |
| `near_miss_key` on a 1 MB word | 0 ms | 0 |
| `misspelled_mark` on a 1 MB info string | 2 ms | — |

`near_miss_key` answers **two integer comparisons** for any key outside 4 characters to the target's
length plus 3, *before* any loop: its interior loops are O(len) with an O(len) `string replace`
inside one, which would be quadratic in a word an issue file chooses. That bound is also the rule
(a near miss of a 5- or 6-letter key is 4 to 9 letters long) and is stated in the comment.

The 50 000-problem row is **not new**: `d42fc517` produces one problem per `quote=`/`assert=` fence
line the same way, and `cap_lines` bounds each line. One problem per fence line is the existing
contract.

---

## 7. Spec (`doc/claude/specs/issue_stamp.md`)

The candidate's own §4/§5/§6 rewrites landed with it. On top of those, three passages were written
for what this item adds:

* **§4**, two new paragraphs: *"A misspelled marking key is named wherever it sits, whatever the
  fences around it do"* (the two-sided pairing hole and the rule that closes it), and *"One letter
  separates `assert=` from `asset=`, so the fence must say what it is a second way"* (the
  block-attempt condition, with the named examples on each side).
* **§5**, the near-miss bullet extended: named by `fence_info` where the fence is read, by the
  stray-attribute check where it is not, so *wherever it sits, and never twice*.
* **§6**, the documented limits: the backtick bullet now says a *misspelled* key after a swallowing
  line is named too, and a new bullet states the residue — `asset=absent path=x` and
  `quota=d64686a1` are named as misspellings and cost the author a rename, while `asset=x` and
  `quota=10` alone are ordinary code samples. The D21 limit itself (**a stamp body outside the
  stamp line is named wherever it appears, fences included**, with its workaround: show the example
  outside `doc/claude/issues/`, or break the body) was already written by the candidate patch and
  is left as it stands; §5's stray-body bullet states it too.

---

## 8. What I did not fix, and what I found on the way

* **Not fixed, in scope but out of reach of a line scanner:** the D21 limit itself. A stamp-body
  example inside a fence in `doc/claude/issues/` is red. That is the decision, not a defect, and it
  is documented in §6 with the workaround.
* **Not fixed, recorded:** `misspelled_mark` guards near-misses of `quote` and `assert` only. A
  misspelled `path=`/`pat=`/`state=` is still named only where the fence is read — but such a fence
  carries no claim of its own, and a fence that *does* carry one is marked by the surviving key and
  read. No measurement here found a silent pass from it.
* **Not fixed, pre-existing, not filed** (it is the existing contract, stated in §6): a corpus with
  50 000 stray `assert=` fence lines produces 50 000 problems. Each line is capped; the count is
  not. `d42fc517` behaves identically.
* **Found outside the item, not fixed:** nothing. The three files this item owns are the only ones
  written.
* **A note for whoever runs this suite by hand:** `tests/headless/run_suites.sh` has a 200 s
  `SUITE_TIMEOUT` and `test_issue_stamp` runs for several minutes (it builds ~20 git fixtures,
  including clones and shallow clones). It needs `SUITE_TIMEOUT=<n>`; T1 gives it 900 s through
  `T1_CASE_TIMEOUT`, which is why T1 has never seen this. Not filed — it is a knob, not a defect.

## 9. Scratch and the user's state

`/var/tmp/xsr_d` deleted, peak **1.8 GB**. Nothing was written to the user's real HOME (every
`tclsh` run used `HOME=/var/tmp/xsr_d/home`; `run_suites.sh` armed its own throwaway and said so),
to `~/.claude/xschem_dev_display`, to `~/.claude/gui_test_gate`, to the dev display `:99`
(`AUDIT_DISPLAY=none` on every driver run), or to `~/dev/xschem-op-wcard`. Nothing was committed.
The one binary used was `/home/analog/dev/xschem-claude/src/xschem`, read-only, through `$XSCHEM`;
no bare `xschem` was invoked and every command carried a `timeout`.

---

# Fix round (2026-09-20) — the one round after the adversarial verify

Full record, with the measurements, in `receipts/D-verify.md`. This section is the delta to
the sections above, so that a reader of D-impl alone is not left with the numbers it retired.

**What changed in the three files** (md5 after this round: `issue_stamp.tcl`
`46f2715a56cb0ab3e08919c5a62e1f2a`, `test_issue_stamp.tcl` `90d3ea446a8cb0efa7dbab16dccf1737`,
`issue_stamp.md` `c72da7af4e2517a1b97823381a607c25`). No fourth file was written. Nothing
committed.

1. **`misspelled_mark` folds the VALUE as well as the key.** The key was folded and the value
   was not, so one capital letter silently disarmed the whole new check: ```` ```sh
   asert=Absent ````, ```` ```sh asert=PRESENT ```` and ```` ```text qoute=A1314271 ```` were
   `ok (0 problems)` on the bytes §1.3 describes, while `asert=absent` and `qoute=a1314271`
   were named — and `d42fc517` names all three. A fail-open, and the direction D18 rule B
   forbids. Two lines; five new `Q25` files (9283–9287) and six new checker self-test
   fixtures. **§1.3's "Measured named / Measured silent" lists are now case-insensitive**:
   `asset=Absent` and `quoted=DEADBEEF` join the named side (they are the case twins of shapes
   already there, and `d42fc517` names them too), while `asset=X` and `quoted=TRUE` stay
   silent.
2. **`gate_body` asks the wall clock BEFORE `fence_scan`/`stray_attrs`, not after.** §6's
   safety table measured the new code against pathological single lines and found it bounded;
   what it did not measure is the whole-corpus constant. The widened line loop costs ~0.28 s
   per MB against `d42fc517`'s 0.02, and both call sites sat above the only `gate_spent`
   check, so nothing but corpus size bounded it (D18 rule A). Measured on a 90 MB corpus with
   the budget at 2 s: **9.6 s before, 2.5 s after, same verdict and the same 16 named files.**
   The unstamped branch gets the same guard. `Q20`'s message is deliberately unchanged.
3. **The swallowed-fence diagnostic names both line numbers.** §2 pair 4 and §5's `Q24` are
   unchanged in verdict; what was missing was that *"inside another fenced block"* named the
   author's own honest fence and neither the opener that swallowed it nor the backtick-info
   line that made that an opener. `fence_scan` now records the latter (`swallow`) and
   `stray_attrs` walks the openers with a forward-only pointer. **Words only:** `landed` vs
   `fixed` over all 1061 issue files is **0 differences**.

**Two verifier findings were NOT turned into code, and both are now documented limits.**

* A **true** `assert=` written after a Slack-style ```` ```sh `make` output ```` line is RED
  where `d42fc517` was green. It stays red: markdown-it (commonmark, 3.0.0) renders that line
  as a paragraph and the ```` ``` ```` below it as a fence whose content is the block, so
  nothing evaluates the claim, and `d42fc517` itself names the same honest assertion in every
  *other* position it does not read (indented, `~~~`, never closed — measured, all three).
  Its green there came from a parse the reference rejects. Spec §6.
* An **unknown, non-near-miss** key on such a swallowed fence (`insert=absent pat=… path=…
  state=holds`) is silent where `d42fc517` named it. It stays silent: `d42fc517` named it only
  because it *read* that fence, and is silent on the identical text in all four other unread
  positions (measured). Naming it would mean naming every unknown word on every unread marked
  fence — the false-alarm class this item exists to close. Spec §6; row `Q26` pins both halves.

**The numbers in §5 that this round moves.** The suite is **102 checks** (`Q26` is new), not
101; the checker's self-test is **180 parser cases**, not 170; the real corpus is still
`ok (0 problems)`, rc 0. The stranger shapes report **29** skipped revisions, not 27 — the
corpus has gained stamped files since §4 was written, and the count is read off the run.
Everything in §3's fail-closed table was re-built and re-run, plus `f5_assert_alone` as a
nineteenth row: every row rc 1 on `d42fc517` and on the fixed bytes alike.

**Outside the item, reported not fixed:** `CREW_BRIEF.md` hands every item's crew the same
scratch root and tells each to delete it; a concurrent crew took that literally and removed
2.5 GB of live work. One sentence in the brief fixes it, and it is the driver's.
