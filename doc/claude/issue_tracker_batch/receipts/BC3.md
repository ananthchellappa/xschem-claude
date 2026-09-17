# BC3 — the unqualified sweep, fixed by identity; and the real cause of the F1 twelve

**Status:** DONE

**Tree state:** started at **`bb3eeb81`** (the revision my brief named), finished at
**`83656487`**. ⚠ **HEAD moved three times while this one task ran** — `bb3eeb81` →
`424d4fe9` → `0bc785c4` → `83656487` — and **that movement is not incidental: it is half
of this receipt.** The last of those three commits has an abbreviation that reddened
twelve rows of the suite I was sent to fix, and I spent the middle of the task proving it
was not my edit that did it. Every citation below is symbolic and reads at `83656487`
unless it names another revision.

**Files touched (1, tracked):** `tests/headless/test_issue_stamp.tcl`
— `git diff --stat`: **1 file changed, 265 insertions(+), 8 deletions(-)**.
**No issue file was opened for writing. No number minted. Nothing committed.**

**Suites run:** `test_issue_stamp` only, on both arms, six times (two pre-fix RED, two
post-fix, two post-comment-edit). **T1 was NOT run** — the brief forbade it and a
concurrent T1 is the collision under investigation. `ps -eo comm= | /usr/bin/grep -cw
tclsh` returned **0** before every run. Every command carried a `timeout`. `./src/xschem`
always by explicit path, never a bare `xschem` (0924). `/usr/bin/grep` throughout.

---

## 1. The fix

`tests/headless/test_issue_stamp.tcl` used to end with one unqualified delete:

```tcl
catch {file delete -force [file join [file dirname [file normalize [info script]]] .scratch]}
```

That removes the **entire shared scratch tree**. Creation was pid-qualified and correct
all along — `mkcorpus` builds `.scratch/istamp_[pid]_<tag>`, row `S20` builds
`.scratch/drv_[pid]` — so **only the sweep was qualified by POSITION** (the directory it
sat in) instead of by **IDENTITY** (the directories this process actually made). That is
`W12b` reproduced inside the file this batch built to enforce its own convention.

**The replacement copies `scratch.tcl` rather than inventing anything**, per the
coordinator's steer, and it is that file's own division of labour:

| mechanism | what it covers | precedent copied |
|---|---|---|
| `istamp_own` / `istamp_delete_own` | dirs **this process made**, deleted from a record taken at creation — identity, never a pattern | `scratch.tcl`'s `__scratch_dirs` / `__scratch_cleanup_all` |
| `istamp_sweep_corpses` | corpses of runs that were **killed**, on evidence only | `__scratch_sweep` and `run_regression.tcl`'s `t1_sweep_verdicts` |

`istamp_sweep_corpses` clears **four** guards before any delete, all four load-bearing:
the name must be this suite's own shape (`istamp_<pid>_<tag>` or `drv_<pid>`), the pid
must not be mine, the pid must be **dead on evidence** — `/proc` absent, never a bare
`kill -0`, which answers yes for a recycled pid — and the directory must clear a 300 s age
floor against pid reuse. **`.scratch` itself is never deleted.** The failure direction is
always *"a leftover survives"*, never *"a live run's state is deleted"*.

**Dead-pid sweeping was judged IN scope**, on the coordinator's reasoning that a correct
implementation already existed to copy. Without it, removing the old line would have
traded a destructive bug for a monotonic leak — issue 0148's class — since `mkcorpus`
creates fourteen directories a run and nothing else would ever reclaim them.

**Creation semantics are unchanged.** The only edits to the creators are additive: they
register what they make, and they take the root from `$::ISTAMP_SCRATCH_ROOT`, resolved
**once at top level** while `[info script]` still names this file — the discipline
`scratch.tcl` states for `__scratch_home`. The creators and the sweep must agree on the
root or the sweep looks in the wrong place and silently does nothing.

---

## 2. RED first — a real collision, observed, on both arms

Three sentinel directories were planted in `.scratch`: `_bc3_sentinel_<pid>`, plus
**replicas of the two real victims** — `_simcaps0948_999999` (the literal name
`test_ase_simcaps_0948` asks `test_scratch` for) and `_conc1476_2642112` (what `.scratch`
actually held, `test_regression_concurrency_1476` running inside a live T1).

**RED — `tclsh` arm, at `bb3eeb81`, pre-fix:**

```
=== BEFORE RUN: .scratch contents ===
_bc3_sentinel_2653258
_conc1476_2642112
_simcaps0948_999999
RESULT: ALL PASS (43 checks)
OVERALL: ok
suite rc=0
=== AFTER RUN: does .scratch still exist? ===
ls: cannot access 'tests/headless/.scratch/': No such file or directory
```

**RED — `./src/xschem --nogui --pipe -q --nolog --script` arm, byte-identical verdict:**

```
=== BEFORE RUN: .scratch contents ===
_bc3_sentinel_2653338
_conc1476_2642112
_simcaps0948_999999
RESULT: ALL PASS (43 checks)
OVERALL: ok
suite rc=0
=== AFTER RUN: does .scratch still exist? ===
ls: cannot access 'tests/headless/.scratch/': No such file or directory
```

**That is the whole defect in one screen: `ALL PASS`, `OVERALL: ok`, `rc 0` — while
destroying three other suites' live state and the shared root itself.** A green suite is
the reason nothing caught it for a day.

**GREEN — after the fix, both arms, sentinels planted identically:**

```
BEFORE: _bc3_sentinel_2654211 _conc1476_2642112 _simcaps0948_999999 istamp_1_foreignlive
suite rc=0
## issue-stamp checker, corpus issues, tree 83656487e
ok:   S0 the revision the fixtures are built from is itself a legal tree= token
ok:   W7 the scratch ROOT itself survives a sweep -- it is 192 files' namespace
RESULT: ALL PASS (51 checks)
OVERALL: ok
FAIL lines: 0
AFTER:  _bc3_sentinel_2654211 _conc1476_2642112 _simcaps0948_999999 istamp_1_foreignlive
own-pid leftovers: 0
```

**Every sentinel survives, on both arms.** `istamp_1_foreignlive` is the sharper one: it
sits *inside this suite's own namespace* but is owned by pid 1, so it tests the liveness
guard rather than the namespace guard.

**And the suite still cleans up after itself:** `own-pid leftovers: 0` on every run —
count of `istamp_*`/`drv_*` entries remaining, excluding the deliberate live-pid plant.
`.scratch` root survives every run and is empty once I removed my own fakes.

### The seven new rows

Added at the foot of the suite, each locking one guard, all run against a **fixture root,
never the real one**, so the suite cannot damage a concurrent run even while proving that
it does not:

* **W1** — cleanup deletes the directories this run **recorded**, and only those (a
  sibling that was never recorded is untouched).
* **W2** — whole-set assertion: the sweep removes **exactly** the dead pids'
  own-namespace dirs and nothing else.
* **W3** — **the sentinel, mechanised.** A LIVE pid's directory is never swept. pid 1 is
  alive on every Linux box there is.
* **W4** — **the measured victim.** `_simcaps0948_*` and `_conc1476_2642112` are
  invisible to the sweep, dead pid or not.
* **W5** — **non-vacuity.** W3 and W4 are "it survived" rows and a sweep that did nothing
  at all would pass both; W5 is the row that says the sweep works.
* **W6** — the age floor spares a dead pid's **fresh** directory (pid reuse).
* **W7** — **the headline.** The scratch ROOT survives. Deleting it was the old line's
  entire content.

---

## 3. ⚠ THE F1 TWELVE WERE NOT CAUSED BY `.scratch`. Driver error **23**.

**This is the most consequential thing in this receipt, and I nearly filed it as my own
regression.**

After the fix, both arms returned **`RESULT: 12 FAILED (38 passed)`** — 38 = 31 old rows
+ 7 new, i.e. **`12 FAILED (31 passed)` of the original 43: the driver's F1 signature
exactly.** My own pre-fix runs an hour earlier were `ALL PASS (43)` on both arms, so the
obvious reading was that my edit had broken twelve rows.

**It had not.** HEAD had moved under me to **`83656487`** — **eight decimal digits, no hex
letter a–f.** The grammar requires at least one:

```
tree=83656487 is not a revision (7-40 hex, at least one a-f)
```

That rule is **correct and must not be loosened**: it is row `S8`, and it exists because a
bare `[0-9a-f]{8,40}` matched `16091816`, the box's MemTotal in kB, and led a whole census
astray (driver error 5). But the suite derived its fixture revision from
`git rev-parse --short=8 HEAD` and interpolated it into every stamp — so on an all-decimal
HEAD **every fixture stamp stops parsing at once.**

**I predicted the fallout set from the source before looking at the log**, which is what
makes this a diagnosis rather than a coincidence: the rows that interpolate `$REV` *into a
parsed stamp* are S15, S15c, B3, G2, Q1, Q2, A2, A3, A4, N1, N2, N3 — **twelve**, and
exactly the twelve observed. Rows that use `$REV` without parsing it (`S15b` formats only;
`S17` only locates the line) pass, and they did.

**It is not rare.** Probability `(10/16)^8 = 2.3%`; measured over this branch's last 300
commits, **6 of 300 = 2%**.

**And the driver's own F1 run is explained.** Commit times place the driver's 13:41
hand-run between `11326086` (13:40:13) and `bb3eeb81` (13:45:07) — so HEAD was
**`11326086`**, which is all-decimal. Verified directly:

```
  tree=72e2c85b   parse_ok=1
  tree=ec2d2c2b   parse_ok=1
  tree=dfc3b5f7   parse_ok=1
  tree=11326086   parse_ok=0  tree=11326086 is not a revision (7-40 hex, at least one a-f)
  tree=bb3eeb81   parse_ok=1
  tree=83656487   parse_ok=0  tree=83656487 is not a revision (7-40 hex, at least one a-f)
```

**BC2 reported `ALL PASS` at `d09ebece`; the driver re-ran twenty minutes later at
`11326086` and got twelve failures. Nothing about the tree, the corpus or concurrency had
changed. Only the spelling of HEAD.**

⚠ **Both defects are real, and the diagnosis conflated them.** The `.scratch` defect is
genuine and independently proven above by sentinel. But it is **not** what turned those
twelve rows red, and the LEDGER's F1 section presents it as the cause — including the
sentence *"a concurrent `.scratch` user destroys its fixtures mid-run"*, which no suite in
this tree actually does: `__scratch_sweep` only touches `_<tag>_<pid>` names with dead
pids and would never match `istamp_*`. The three hypotheses F1 records as refuted were
refuted correctly; the fourth, adopted one was never tested against a revision.

**Fixed, in the suite, two ways.** `istamp_test_rev` lengthens the abbreviation until it
carries a hex letter — 8, 9, 10, 12, then the full 40-char object name as backstop; every
form names the same commit and `git show`/`cat-file` accept all of them. At this HEAD the
banner now reads `tree 83656487e`. And **new row `S0`** asserts that the revision the
fixtures are built from is itself a legal `tree=` token, so a recurrence is **one named
row** instead of twelve unrelated-looking ones and an evening of hypotheses.

⚠ **This was on the driver's critical path and is now off it.** `test_issue_stamp` **is**
registered in `hcases` in the working tree (`tests/run_regression.tcl`, uncommitted). A T1
run at the current HEAD would have carried **12 counted failures against a baseline of
ZERO** from this defect alone — with nothing wrong with the checker, the corpus or the
tree, and no concurrency anywhere near it.

---

## 4. Claims checked vs taken on trust

**Re-measured, not inherited:**

* the defect itself, by sentinel, on both arms, before and after;
* **192** files under `tests/` actually `source scratch.tcl` (187 `test_*.tcl` + 5
  helpers), by an anchored `^\s*source .*scratch\.tcl`. ⚠ The brief and the coordinator
  both say **191**, and a bare substring grep answers **194** — *including this file*,
  because my own comments now mention `scratch.tcl`. That is the `pgrep -af` self-match
  again, and it is why the shipped comment states the anchored number and names the trap;
* `test_ase_simcaps_0948` does `source scratch.tcl` then `set scratch [test_scratch
  simcaps0948]` — confirmed, so `_simcaps0948_<pid>` is the real victim's real name;
* the all-decimal SHA rate: **6 of the last 300 commits, 2%**;
* the commit timestamps placing the driver's F1 run at `11326086`;
* `istamp::rev_exists 83656487` returns **1** — the revision resolves fine; it is the
  *grammar*, not git, that rejects it. Worth stating, because "the SHA is bad" would be
  the wrong repair;
* every Tcl primitive the fix rests on, probed before use: `glob`'s `[0-9]` character
  class, the alternation regexp correctly rejecting `_simcaps0948_999` and `istamp_x_y`,
  `file delete -force` on a missing path being a silent no-op, `file mtime` readable.

**Taken on trust (said so rather than guessed):** the LEDGER's `counted_failures=55` and
the 42-from-`test_ase_simcaps_0948` attribution — I did not re-run T1 and could not, so
the figure in my code comment is the driver's; BC1/BC2/D1's per-file verdicts on the
corpus, which I had no reason to re-derive; that `_conc1476_2642112` was present at the
moment of the driver's run.

---

## 5. Corrections for the next crew

1. **`tests/headless/scratch.tcl` is exemplary and was never the problem.** The
   coordinator's mid-task correction is confirmed: `test_scratch` builds `_<tag>_<pid>`,
   fully pid-qualified, and `__scratch_sweep` is identity-guarded four ways. The single
   unqualified delete in the whole tree was `test_issue_stamp.tcl`'s last line.
2. **A T1 red in this suite is not evidence of a collision.** It is now at least as likely
   to be an all-decimal HEAD — 2% of commits — and `S0` is the row that tells you which.
3. **The brief's "191 suites"** is 192 files by anchored count; a substring count of 194
   now includes this file itself.
4. ⚠ **Do not "simplify" `S8` or the `tree=` grammar to make a red go away.** It is the
   mechanised form of driver error 5. The revision derivation is what bends; the rule does
   not.

---

## 6. Left dirty

Nothing committed. **One modified tracked file and this receipt:**

```
 M tests/headless/test_issue_stamp.tcl      <- BC3
 M tests/run_regression.tcl                 <- the driver's hcases registration, NOT mine
?? doc/claude/issue_tracker_batch/receipts/BC3.md
```

Pre-existing untracked dirt, unchanged by me: `.xschem/`, `doc/claude/rdw_lists_batch/`,
`doc/claude/rdw_sim_batch/`, `sky130A/.../debug_st1/`.

**Constraints honoured, each verified rather than asserted:**

* `~/.xschem/ase_simulators` md5 is **`13c5cec624b130f598db5779f7b2b8bf`**, unchanged —
  checked at the start and at the end. Nothing under `~/.xschem/` was written.
* `/tmp/xschem_emergencysave_*`: **49** before, **49** after. None deleted.
* `tests/headless/owed.sh` and `~/.claude/xschem_owed/` were **not read or written**.
* No issue file edited; `NUMBERING.md` untouched; no number minted.
* T1 not run. `tclsh` count was **0** before every run.
* Every sentinel and fake directory I planted in `.scratch` was removed afterwards; the
  root survives and is empty.

**Recommended to the driver, not done by me:** the all-decimal-revision defect (§3) is the
first thing in this batch that is a genuine, recurring, tree-wide fragility rather than a
one-file slip, and it has already cost one evening of misdiagnosis. If anything in this
batch earns a number, it is that — but minting one was out of my bounds.

## 7. Owed to the user

**Nothing.** Every decision here is internal engineering — how a test suite names its
scratch directories, which guards a sweep clears, how a fixture revision is derived. None
of it reaches a person using XSCHEM, so per the standing rule none is a ruling and none
was filed as one. Nothing was converted, cleared or added to any ledger.

Two decisions are recorded as **mine**, with the evidence, so the driver can overturn
either in one line: **including dead-pid sweeping** rather than shipping own-pid-only
cleanup (§1 — the alternative trades a destructive bug for a monotonic leak), and
**fixing the revision derivation and adding `S0`** (§3), which was outside my assigned
task but is the only way this suite could be green on both arms at the current HEAD.
