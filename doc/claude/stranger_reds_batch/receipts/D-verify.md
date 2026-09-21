# D-verify — item D (issue 1489): the two verifiers' findings, and what happened to each

**Crew** D fixer (the one fix round; PLAN.md criterion 5 — there is no round after this).
**Date** 2026-09-20. **Tree** `fluid-editing`, main tree at `04844d23` with item D's landed
changes in the working tree; measurements in a full clone at `/var/tmp/xsr_d2/w` (checked out
`04844d23`, `--shared`, so the parent's object store was never written).
**Scratch** `/var/tmp/xsr_d2`, deleted; **peak 1.1 GB** (the six stranger shapes, 909 MB, plus
the 166 MB clone; a 90 MB CPU bed deleted as soon as it was measured).

**Files changed, all in the main tree, nothing committed — the same three item D already owned:**

| file | md5 at `d42fc517` | md5 after item D | md5 after this fix round |
|---|---|---|---|
| `tests/headless/issue_stamp.tcl` | `6d0592ad9dfcbefc24e17f1e5a97c202` | `8e8966382287e6e78cd71a083e76dc0d` | `46f2715a56cb0ab3e08919c5a62e1f2a` |
| `tests/headless/test_issue_stamp.tcl` | `930eb4359ffda3528fa40cf086af884c` | `881a05c1c16e3594a77c5e7cf6ce2a0f` | `90d3ea446a8cb0efa7dbab16dccf1737` |
| `doc/claude/specs/issue_stamp.md` | `1d4f8efba7d66232e801ec2bb27339e7` | `91b4796a2edf0c83e3a6020306993bd5` | `c72da7af4e2517a1b97823381a607c25` |

`git status --porcelain` names no other modified file.

> **The landed bytes were reconstructed, not assumed.** Item D's changes are uncommitted, so
> "the code before this round" had to be rebuilt by inverting each of this round's edits in a
> script. The reconstruction hashes **`8e8966382287e6e78cd71a083e76dc0d`**, byte-identical to
> D-impl's recorded md5 — which is also the proof that this round changed *only* the five
> places it says it changed. `/var/tmp/xsr_d2/landed/issue_stamp.tcl` was that file, and every
> "landed" column below was measured against it.

---

## 0. The verdict on each of the seven findings

| # | finding | severity | verdict |
|---|---|---|---|
| 1 | the capitalised-value hole (`misspelled_mark`) | honest / should | **APPLIED** — the value is folded, §1 |
| 2 | a new false red on honest content (Slack shape) | safety / should | **REJECTED as a verdict change; the DIAGNOSTIC was fixed and the shape documented**, §2 |
| 3 | a new silence (an unknown key on a swallowed fence) | safety / should | **DOCUMENTED LIMIT**, §3 |
| 4 | `stray_attrs`' widened early-out is unbudgeted CPU | safety / should | **APPLIED** — the wall clock is asked before the scan, §4 |
| 5 | `asert=absnet` residue (documentation only) | honest / nit | **APPLIED** — one clause in spec §6, §5 |
| 6 | the near-miss/value split, for the record | safety / nit | **RECORDED HERE, not cited in the spec**, §5 |
| 7 | the batch brief hands every crew the same scratch root | safety / nit | **OUTSIDE THIS ITEM — reported to the driver**, §6 |

Everything below was measured in this round. Nothing is inherited from D-impl or from the
verifiers: the fail-closed table, the six stranger shapes and the corpus diff were all re-run.

---

## 1. APPLIED — the capitalised value (finding 1)

**The defect, red-first.** `misspelled_mark` folded the misspelled key (`string tolower $k`)
and compared its **value** as written, so one capital letter disarmed the whole check while
its lowercase twin was named. One stamped issue file per corpus, `issue_stamp.tcl gate
<corpus> <baseline>`, three checkers (`base` = `d42fc517`, `landed` = item D as it stood,
`fixed` = this round), counting problems for that file:

| fixture | fence | base | landed | fixed |
|---|---|---|---|---|
| `c1a` | ```` ```sh asert=Absent ```` | 1 | **0** | 1 |
| `c1b` | ```` ```sh asert=absent ```` (lowercase twin) | 1 | 1 | 1 |
| `c1c` | ```` ```sh asert=PRESENT ```` | 1 | **0** | 1 |
| `c1d` | ```` ```text qoute=A1314271 ```` | 1 | **0** | 1 |
| `c1e` | ```` ```text qoute=a1314271 ```` (lowercase twin) | 1 | 1 | 1 |
| `c1f` | ```` ```sh ASERT=absent ```` (the key half, already folded) | 0 | 1 | 1 |
| `c1g` | ```` ```js asset=Absent ```` (the §6 residue, capital) | 1 | **0** | 1 |
| `c1k` | ```` ```c quoted=DEADBEEF ```` (the §6 residue, capital) | 1 | **0** | 1 |
| `c1h` | ```` ```js asset=x ```` (anti-overshoot) | 1 | 0 | **0** |
| `c1i` | ```` ```sh quota=10 ulimit ```` (anti-overshoot) | 1 | 0 | **0** |
| `c1j` | ```` ```c quoted=TRUE ```` (anti-overshoot, capital) | 1 | 0 | **0** |
| `c4c` | ```` ```js asset=X ```` (anti-overshoot, capital) | 1 | 0 | **0** |

The three shapes in bold on the `landed` column are the hole: **silent on the landed bytes,
named by `d42fc517`, and named by their own lowercase twins.** The last four rows are the
anti-overshoot half, and they are unchanged: folding the value widens the check only to the
values the grammar itself uses (`absent`, `present`, a revision token), never to an arbitrary
one.

**Why it had to be closed rather than written down.** A check a capital letter turns off is a
fail-OPEN, which is the direction D18 rule B forbids outright ("near-miss spellings that an
honest author produces by accident … are named problems, never silent passes"). And it cannot
be stated as a rule anybody would believe: the two halves of one test disagreed about case.

**The fix** (`istamp::misspelled_mark`): `set lv [string tolower $val]`, then test `$lv`.
Two lines, plus the comment that records the measurement.

**It opens no new false-alarm surface.** Every shape it adds (`asset=Absent`,
`quoted=DEADBEEF`) is the case twin of a shape the landed bytes already name, and
`d42fc517` names all of them too (measured, the `base` column above). Over the real corpus it
changes nothing (§7).

**Rows:** `Q25` gains 9283 (`asert=Absent`), 9284 (`asert=PRESENT`), 9285 (`qoute=D64686A1`),
9286 (`asset=X`, must stay silent) and 9287 (`asset=Absent`, the residue in its capital
spelling). The checker's own self-test gains six `misspelled_mark` fixtures. **Red-first, by
row:** the new suite file run against the landed checker gives `Q25` `got {0 0} {0 0} {0 0}
{0 0} {0 0}` for those five where it wants `{1 1} {1 1} {1 1} {0 0} {1 1}` — `2 FAILED (100
passed)`. **Spec:** §4 gains *"Both halves of that test ignore case."*

---

## 2. REJECTED as a verdict change — the "new false red" (finding 2)

**What was measured.** A **true** `assert=absent pat=ZZZNOTTHERE path=src state=holds`, or a
holding `quote=`, written after a Slack-style ```` ```sh `make` output ```` line is green on
`d42fc517` and RED on the landed bytes. Reproduced (`c2_slack`): base 0 problems, landed 1,
fixed 1.

**Why it is not made green.** Three measurements, in order of weight.

1. **The reference parser agrees with the landed code, not with the author.** markdown-it
   (`markdown_it.MarkdownIt("commonmark")`, markdown-it-py **3.0.0**, present on this box) was
   asked directly for the token stream of `c2_slack`:

   ```
   paragraph_open   map=[2, 4]
   inline           map=[2, 4] content='```sh `make` output\ngcc -c real.c'
   fence            map=[4, 9] info='' content='\n```sh assert=absent pat=ZZZNOTTHERE path=src state=holds\nnothing here\n'
   ```

   The ```` ```sh `make` output ```` line is a **paragraph**; the bare ```` ``` ```` under it
   opens a fence; and the author's `assert=` line is that fence's **content** — literal text.
   In the rendered issue file nothing evaluates it. `c2_plain`, the same block with no Slack
   line above it, is a real `fence` with `info='sh assert=absent …'`.

2. **So a green there would be a claim passing unevaluated**, which is the one direction this
   checker may not fail in (D18 rule B). On the landed parser the block is genuinely not read;
   naming it is the existing rule ("an `assert=` the parser does not read is a named problem"),
   not a new one.

3. **`d42fc517` names the same honest assertion in every other position it does not read.**
   The Slack shape is the only one where its answer differs, and there its green came from a
   parse the reference rejects:

   | the same TRUE `assert=` written… | base | landed | fixed |
   |---|---|---|---|
   | in a plain column-0 fence (read and evaluated) | 0 | 0 | 0 |
   | indented two spaces | 1 | 1 | 1 |
   | in a `~~~` fence | 1 | 1 | 1 |
   | in a fence never closed | 1 | 1 | 1 |
   | **after a Slack-style backtick-info line** | **0** | 1 | 1 |

   Read the column, not the row: `d42fc517`'s own rule is *name it*, three times out of four.

**What WAS fixed: the diagnostic, which is the half the verifier was right about.** The
message named the author's own honest fence and then described the cause in the abstract, so
the two lines the author had to look at were the two lines it did not carry. Before and after,
on `c2_slack`:

```
landed  1601:11: an assert= the parser does not read (inside another fenced block, where it
        is text, not a fence) -- …
fixed   1601:11: an assert= the parser does not read (inside another fenced block, where it
        is text, not a fence -- the block was opened at line 9 by the ``` that looks like the
        closer of line 7, but line 7's info string holds a backtick, so markdown reads that
        line as inline code and it opened no fence at all) -- …
```

Mechanism, and it is deliberately **not** a new structural rule: `fence_scan` remembers a line
it rejected for holding a backtick in its info string until a fence opens or closes, and
records it against a **bare** ```` ``` ```` opener that follows one (`swallow`). `stray_attrs`
walks the openers with a forward-only pointer — a search per problem line would be quadratic in
a file of 50 000 fence lines, which D18-A does not allow corpus text to buy — and hands
`stray_why` the last opener before the line. The old wording *"inside another fenced block,
where it is text, not a fence"* is kept verbatim and appended to, so nothing that reads for it
(rows `Q3` and `Q10` do) changes.

**That it is words only, and not a verdict, is measured, not asserted.** Row `Q26`'s first four
wants — `1 0 0 1` — are already satisfied by the landed bytes; only its fifth element, the two
line numbers, fails there (`got {1 0 0}`, `want {1 1 1}`). And over the whole real corpus
`landed` and `fixed` differ in **nothing at all** (§7).

**Spec:** §6's backtick bullet now states the shape, the reference-parser evidence, the
`d42fc517` column above, and the workaround (write example output under a plain ```` ```text ````
fence).

---

## 3. DOCUMENTED LIMIT — the "new silence" (finding 3)

**What was measured.** A fence swallowed by the phantom opener whose only anomalous word is a
`key=value` whose key is neither of the grammar nor a near miss of `quote`/`assert` —
```` ```sh insert=absent pat=SABOTAGE path=src state=holds ```` — is silent on the landed
bytes, where `d42fc517` named it (`c3_slack`: base 1, landed 0, fixed 0).

**Why no rule was built for it.** The task's instruction was explicit: if a finding needs a
rule that settles nested-container ambiguity with a line scanner, do not build it (D21). This
one does not quite need that — but the code alternative is worse, and the verifier that filed
it said so itself: *"naming any unknown `key=` on an unread fence that also carries a block key
re-opens the false-alarm class this item exists to close, so I do not recommend it."* A fence
carrying `path=` and a shell word (```` ```sh path=/tmp ls ````) inside an example block is
exactly such a sample, and item D exists to stop naming those.

**And the measurement says `d42fc517` never had a rule here to regress against.** Its
`stray_attrs` matches only `(quote|assert)[ \t]*=`, so it names an unknown key **only** where
it happens to *read* the fence. The identical text in every other unread position is silent on
both checkers:

| the same `insert=absent pat=… path=… state=holds` written… | base | landed | fixed |
|---|---|---|---|
| in a plain column-0 fence (read) | 1 | 1 | 1 |
| indented two spaces | 0 | 0 | 0 |
| in a `~~~` fence | 0 | 0 | 0 |
| in a fence never closed | 0 | 0 | 0 |
| inside another fence | 0 | 0 | 0 |
| **after a Slack-style backtick-info line** | **1** | 0 | 0 |

So the landed silence makes the Slack context agree with `d42fc517`'s own answer in the four
other unread contexts; the outlier is the row where `d42fc517` read a line markdown-it says is
not a fence.

**Nothing evaluable is lost.** The key is not `assert=` or `quote=`, so no claim is
evaluated-and-passed either way — there is no claim. Every canonical or near-miss key in the
same position **is** named (`c1a`–`c1e`, `Q25` 9272/9273).

**Recorded in the spec**, §6's backtick bullet, as the second of that rule's two consequences,
with the table above in prose and the reason a code fix was refused. Row `Q26` (9292, 9293,
9294) pins it by measurement, so a future reader meets it as a decision and not as a fresh
defect.

---

## 4. APPLIED — the unbudgeted scan (finding 4)

**The defect.** `stray_attrs` enters its line loop for any file holding a fence run and any
`[A-Za-z]=` word, where `d42fc517` needed a literal `quote=`/`assert=`, and for every
fence-shaped line that did not become a block it splits the whole info string. The verifier
measured ~0.28 s per MB against base's 0.02. Both call sites sat **above** `gate_body`'s only
`gate_spent` check, so the one pass whose cost the corpus's own text sets was the one pass no
budget covered (D18 rule A).

**The fix.** `gate_body` asks the wall clock **before** `fence_scan`/`stray_attrs` instead of
after, and the unstamped branch gets the same guard with its own named problem. No new budget,
no new knob; the same fail-closed answer the `tree=` and `quote=` questions already give.

**Red-first and green-after, measured.** A corpus of 20 stamped files, each ~4.5 MB of
`~~~sh asert=z <1500 words>` fences (**90 MB**), driven through `istamp::gate` with
`istamp::t_gate_total` set:

| checker | budget | elapsed | problems |
|---|---|---|---|
| landed | 600 s | 9.5 s | 0 |
| landed | **2 s** | **9.6 s** | 16, all budget-named |
| fixed | 600 s | 9.8 s | 0 |
| fixed | **2 s** | **2.5 s** | 16, all budget-named |

Same verdict, same 16 named files; the landed bytes scanned every remaining file **in full**
before naming it, the fixed bytes do not. The budget now bounds the work, and the bound is the
gate's own.

**Not applied:** the second half of the verifier's suggestion, a length cap on the info string
handed to `misspelled_mark`. A cap would be a new way to disarm the check by padding — the same
shape as finding 1, which this round is closing — and the wall-clock guard is sufficient on its
own (the verifier said either would do). Row `Q20` still passes unchanged; its message is
deliberately untouched so the row's three globs keep matching.

**Spec:** §6's wall-clock bullet now says the budget is asked before the scan, with the
9.6 s → 2.5 s measurement.

---

## 5. The two nits

**Finding 5, `asert=absnet` (applied, documentation only).** A fence whose marking key **and**
value are both outside the grammar, with no other grammar key beside it, is silent where
`d42fc517` named it. Measured here: `c4a` ```` ```sh asert=absnet ```` — base 1, landed 0,
fixed 0; `c4b`, the same with `pat=SABOTAGE path=src state=holds` added — base 1, landed 1,
fixed 1, so any grammar key re-arms it. It carries no claim: nothing in it says `absent`,
`present` or a revision. Spec §6's near-miss bullet now states that boundary in the words a
reader will test with, and says adding a grammar key re-arms the check.

**Finding 6, the 7872-of-26880 split (recorded here, deliberately NOT put in the spec).** The
verifier's matrix measured that fraction of near-miss spellings going silent, all of them
without a second grammar key and without the key's own value. It is a true statement about a
matrix I did not rebuild, and a number in a spec that nobody re-measures is the defect this
project files issues about. The spec states the **rule** instead — both key and value outside
the grammar means silence — which is what a reader can test in one command, and §5 above shows
the test. The number is preserved here, attributed to the verifier who measured it.

---

## 6. Outside this item, reported and not fixed

`CREW_BRIEF.md` tells every item's crew to *"delete it when you are done"* about a scratch
root that all of them share. The verifier watched a concurrent crew take that literally and
remove six live directories (2.5 GB of another crew's work) out of `/var/tmp/xsr_d`. This
round was given its own root, `/var/tmp/xsr_d2`, so it never met the hazard — which is
precisely why the brief should say so: the fix is one sentence, *"delete `<root>/<your
item>`; the root is shared."* Not edited here (PLAN criterion 4: a finding outside the item is
written down, not fixed on the way past). **Driver: this is yours.**

---

## 7. The re-runs the fix round owes

### 7.1 The suite

`tests/headless/run_suites.sh --nogui test_issue_stamp`, `AUDIT_DISPLAY=none`,
`SUITE_TIMEOUT=2400` (the 200 s default is far short of this suite, which builds ~20 git
fixtures):

```
test home: throwaway /tmp/xschem-test-home.1180114.qTuFnn (your HOME is untouched; …)
display arm: none (DISPLAY unset; GUI legs will self-skip)
PASS     | test_issue_stamp             run 1/1  RESULT: ALL PASS (102 checks)
RESULT: 1/1 runs passed
```

**101 → 102 checks** (the new `Q26`). **0 `skip:` lines.** Checker self-test cases
**170 → 180** (six `misspelled_mark` case fixtures, four `fence_scan` `swallow` fixtures).

**Red-first for the whole round:** the new suite file against the reconstructed landed checker
is `RESULT: 2 FAILED (100 passed)` — `Q25` (the five case-fold files) and `Q26` (the two line
numbers). Against `d42fc517` item D already measured `7 FAILED`; that is unchanged.

### 7.2 The real corpus

`tclsh tests/headless/issue_stamp.tcl` in the main tree, 1061 issue files:

```
self-test PASSED (180 parser cases)
history: full -- a full clone: every stamped revision must resolve
ISSUE-STAMP: ok (0 problems)          rc 0
```

### 7.3 The behavioural diff against `d42fc517`, whole corpus

Two `interp`s per checker, every `NNNN-*.md` in `doc/claude/issues`, comparing five things per
file: the blocks `fence_scan` reads (line number, attrs, bad words), its `opened` map, and the
problem lists of `stray_stamps`, `stray_attrs` on the stamped path and `stray_attrs` on the
unstamped path.

| pair | files | differences |
|---|---|---|
| `d42fc517` vs **fixed** | 1061 | **1**, and it changes no verdict |
| item D's landed bytes vs **fixed** | 1061 | **0** |

The single difference is the `opened` map of `1489-…md` itself, at its own line 15 — a
three-space-indented four-backtick run whose info string holds backticks (the issue file quotes
```` ```python title="example.py" ```` inline). `d42fc517` read it as an opener that never
closed; the fixed checker, like markdown-it, reads it as no fence. **No block, no stray stamp
and no stray attribute differs anywhere in the corpus**, so no problem text differs — and the
gate verdicts agree outright: `d42fc517` on the real corpus is `ok (0 problems)`, the fixed
checker is `ok (0 problems)`.

**Every changed verdict, explained:** there are none on the real corpus. On fixtures, the
changed verdicts are exactly the twelve rows of §1 (the case fold), and they are explained
there; §2 and §3's rows are unchanged by this round (they are item D's, and they are explained
against `d42fc517` in those sections).

### 7.4 Fail-closed (D18 rule B) — every honest mistake still RED

Nineteen fixtures, one issue file each, run on `d42fc517` and on the fixed bytes. **Every row
is rc 1 on both, with the same problem count.** Re-built and re-run in this round; the
off-HEAD commit is a fresh `git commit-tree` in the clone (`6c493be1`), the blob is
`43168a49` (`HEAD:src/xschem.h`).

| # | fixture | the defect | base | fixed |
|---|---|---|---|---|
| 1 | `b01` | `tree=deadbee0`, resolves to nothing | 1, rc 1 | 1, rc 1 |
| 2 | `b02` | `tree=a1314272`, one digit off a real revision | 1, rc 1 | 1, rc 1 |
| 3 | `b03` | `tree=43168a49`, a **blob** oid, not a commit | 1, rc 1 | 1, rc 1 |
| 4 | `b04` | `tree=6c493be1`, a commit that exists and is **not an ancestor of HEAD** | 1, rc 1 | 1, rc 1 |
| 5 | `b05` | `quote=a1314271` over text the file never held | 1, rc 1 | 1, rc 1 |
| 6 | `b06` | `assert=absent pat=SABOTAGE path=src state=holds`, 8 real hits | 1, rc 1 | 1, rc 1 |
| 7 | `b06b` | `state=broken` on an assertion that now HOLDS (the stale-fixed detector) | 1, rc 1 | 1, rc 1 |
| 8 | `b07` | a new issue file with no `**STAMP:**`, not in the baseline | 1, rc 1 | 1, rc 1 |
| 9 | `b08` | a stamp missing the required `open=` | 1, rc 1 | 1, rc 1 |
| 10 | `b09` | `stamped=0000-00-00`, not a day on the calendar | 1, rc 1 | 1, rc 1 |
| 11 | `b10` | `tree=13142710`, hex-shaped with no `a`–`f` | 1, rc 1 | 1, rc 1 |
| 12 | `b11` | `__STAMP:__`, a near-miss spelling | 2, rc 1 | 2, rc 1 |
| 13 | `b12` | `**STAMP**` with the colon lost | 2, rc 1 | 2, rc 1 |
| 14 | `b13` | a rotted `quote=` in a two-space-indented fence | 1, rc 1 | 1, rc 1 |
| 15 | `b14` | a false `assert=` in a `~~~` fence | 1, rc 1 | 1, rc 1 |
| 16 | `b15` | a false `assert=` in a fence the file never closes | 1, rc 1 | 1, rc 1 |
| 17 | `b16` | a stamp **body** inside a ```` ```text ```` fence (**the D21 documented limit**) | 1, rc 1 | 1, rc 1 |
| 18 | `b17` | `pat="static int"`, a multi-word pat on a marked fence | 1, rc 1 | 1, rc 1 |
| 19 | `b18` | a lone canonical `assert=absent` with no `pat=`/`path=`/`state=` | 1, rc 1 | 1, rc 1 |

Messages spot-checked rather than only counted: `b03` *"names a blob in this repository, not a
commit"*; `b04` *"resolves in this checkout but is NOT in HEAD's history"*; `b06b` *"states
this assertion is BROKEN, but it now HOLDS"*; `b16` *"a line carrying a stamp's body … that is
not a **STAMP:** line the parser reads"*.

### 7.5 Strangers (D18 rule C) — every shape green, every skip named

Each shape built fresh in this round from `04844d23`, given the fixed `issue_stamp.tcl`, and
run with a bare `tclsh tests/headless/issue_stamp.tcl` under a throwaway `HOME` and a pinned
`GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`.

| shape | how it was built | history state | verdict | rc |
|---|---|---|---|---|
| renamed clone | `git clone <repo> s/a-different-name` | `full` | `ok (0 problems)` | 0 |
| worktree | `git worktree add --detach s/wt 04844d23` | `full` | `ok (0 problems)` | 0 |
| shallow clone | `git clone --depth 1 file://<repo>` | `shallow`, boundary `04844d23` | `ok (0 problems; 29 revision(s) NOT VERIFIED -- shallow: history absent)` | 0 |
| git-archive export | `git archive 04844d23 \| tar -x`, no `.git` | `none` | `ok (0 problems; 29 … NOT VERIFIED -- none: history absent)` | 0 |
| export inside another repo | that export copied into a `git init` + commit outer repo | `none` | `ok (0 problems; 29 … NOT VERIFIED -- none: history absent)` | 0 |
| unborn repository | that export + `git init`, nothing committed | `unborn` | `ok (0 problems; 29 … NOT VERIFIED -- unborn: no commits yet)` | 0 |

Every skipped revision is named individually, e.g. `ISSUE-STAMP: NOT VERIFIED 0056:
tree=61af3692 (shallow: beyond the depth?)`. **29, not D-impl's 27** — the corpus has gained
stamped files since; the count is read off the run, not carried forward.

---

## 8. Scratch and the user's state

`/var/tmp/xsr_d2` deleted, **peak 1.1 GB**. Nothing was written to the user's real HOME (every
`tclsh` ran with `HOME=/var/tmp/xsr_d2/home`; the one `run_suites.sh` run armed its own
throwaway and said so), to `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate` or
`~/.claude/xschem_owed`, to the dev display `:99` (`AUDIT_DISPLAY=none`), or to
`~/dev/xschem-op-wcard`. The clone was made `--shared`, so no object was ever written into the
main repository; the only git writes were the fixture commit-tree and the `git init` shapes
inside the scratch. No bare `xschem` was invoked, every command carried a `timeout`, and
`/usr/bin/grep` was used throughout. **Nothing was committed.**
