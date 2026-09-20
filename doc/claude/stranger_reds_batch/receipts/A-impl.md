# Receipt — item A (issue 1485), IMPLEMENT

**Nine T1 suites read their corpus through `git ls-files` and used git's error text as
data. In a checkout with no `.git` — a GitHub "Download ZIP", a release tarball, a
`git archive` export — three of them DIED mid-run and six reported a false red.**

Measured red first, fixed, measured green. **All nine now pass in both stranger shapes
with the SAME check count as a full clone and ZERO `skip:` lines** — no coverage moved.

Crew: implementer, 2026-09-20. Tree at start: `bbc9de1a` (branch `fluid-editing`).

---

## 1. The conditions that were measured

| name | what it is |
|---|---|
| **clone** | `/home/analog/dev/xschem-claude`, the developer's own full clone — the regression baseline |
| **export** | `git archive --format=tar HEAD \| tar -x` into an empty directory, then `./configure && make -C src` |
| **nogit** | `git clone --no-hardlinks` of this repo, then `rm -rf .git`, then `./configure && make -C src` |
| **inner-repo** | the **export**, with a `git init`'d directory as its PARENT — `git ls-files` then exits **0** and lists **nothing** (§6) |

Every suite was run the way T1 runs an `hcase`, through the armed driver:

```sh
AUDIT_DISPLAY=none GUI_GATE=0 SUITE_TIMEOUT=900 \
  timeout 1000 <tree>/tests/headless/run_suites.sh --nogui <suite>
```

so each run got a throwaway HOME, no DISPLAY (GUI legs self-skip, as under `--nogui`),
a 900 s per-suite bound and a 1000 s outer one. `AUDIT_DISPLAY=none` rather than a
private Xvfb because the task forbids touching the dev display `:99` (which is up but
`stale` on this box).

**Both stranger trees were rebuilt from scratch** — `./configure` then
`timeout 900 make -C src -j8`, rc 0, `src/xschem` 1 688 064 bytes in each, byte-identical
in size to the clone's. No harness builds, so a stale binary would have given a plausible
run with wrong answers. The clone's binary was confirmed current (`make -C src`:
*Nothing to be done for 'all'*).

⚠ **The trees are NOT at the assigned scratch root, and that is deliberate.** The
assigned root is `…/scratchpad/stranger_reds/**A**`, and an uppercase letter in the
checkout path is **issue 1484**, which reds `test_ase_variant_1470` and
`test_ase_sp_1452` on its own. The first measurement was taken there and those two rows
were red for 1484's reason, not item A's (§7.1). The checkouts were therefore rebuilt
under the lowercase sibling `…/scratchpad/stranger_reds/a_trees/`; logs, scripts and
the sabotage backups stayed in `…/stranger_reds/A/`. Both were deleted (§8).

---

## 2. RED — before the fix

`export` and `nogit` produced **identical** verdicts, row for row. Clone counts are the
baseline column and match issue 1485's own full-clone control exactly.

| suite | clone (baseline) | export / nogit, BEFORE | the failing row(s) |
|---|---|---|---|
| `test_ase_core` | ALL PASS (675) | **DIED**, rc 10, after 461 `ok:` + 5 `FAIL:` | `CP1 CP2 CP3 CP4 CP7` fail, then `couldn't open "GIT-LS-FILES-FAILED"` at `test_ase_core.tcl` line 8084 |
| `test_ase_simcaps_0948` | ALL PASS (211) | 1 FAILED (210 passed) | `W6 … -> {0} (exp {1})` |
| `test_ase_options_1437` | ALL PASS (75) | 1 FAILED (74 passed) | `DL5 … -> {RAISED:fatal: not a git repository …}` |
| `test_ase_predeck_1439` | ALL PASS (78) | 1 FAILED (77 passed) | `RD10 … -> {RAISED:fatal: not a git repository …} (exp {5 0 5})` |
| `test_ase_sp_1452` | ALL PASS (58) | 1 FAILED (57 passed) | `SC1 … -> {0 {} 0 0 …} (exp {1 {} 0 0 …})` |
| `test_ase_trnoise_1466` | ALL PASS (80) | **DIED**, rc 0, after 58 `ok:` | `couldn't open "<repo>/fatal: not a git repository …"` at line 957 |
| `test_ase_trnoise_gui_1467` | ALL PASS (19) | 1 FAILED (18 passed) | `N0 … -> {RAISED:couldn't open "<repo>/fatal: not a git repository …"}` |
| `test_ase_variant_1470` | ALL PASS (76) | **DIED**, rc 0, after 75 `ok:` | `couldn't open "<repo>/fatal: not a git repository …"` at line 1078 |
| `test_ase_simwin_variant_1471` | ALL PASS (12) | 1 FAILED (11 passed) | `ST1 … -> {RAISED:dict element in quotes followed by ":" instead of space}` |

Three distinct ways the same error string was used as data: **as a file path** (the four
deaths / raises), **as an empty list** (`W6`, `SC1` — a row that silently measured
nothing and still printed `(exp {1})` as if it had), and **as a dict to parse**
(`ST1`, which is the error text reaching `ase::state_load`'s parser).

⚠ **A `RESULT:` line is not the same thing as a death.** `test_ase_trnoise_1466` and
`test_ase_variant_1470` died at **rc 0** with no verdict line at all; only
`run_suites.sh`'s `NORESULT | … (exit 0 — binary never reported)` arm named them. Under
T1 they would have been caught by `regression_case_failed`'s banner clause, not by the
exit code.

---

## 3. The fix

**One shared helper, not nine patches — because the shape really was shared**: all nine
sites asked the same question ("the `.state` files of this checkout") and git was only
the cheapest way to enumerate them. Nine ad-hoc `catch`es would have been nine places to
get rule 1 wrong again, and the two `catch {…} out; foreach [split $out]` sites in
`state_roundtrip.tcl` and `test_ase_simcaps_0948.tcl` were already near-copies of each
other. It is **not** a framework: two procs and a private walker, in the file every one
of the nine suites already sources.

`tests/headless/scratch.tcl` gains:

```tcl
test_corpus_files <repo> <pattern>
   -> dict  files   absolute paths, sorted
            source  git | fs
            reason  {} when source is git; a one-line human reason otherwise
test_corpus_note  <dict> ?<what>?     ;# prints the `note:` line when source is fs
```

The rules it enforces, in the order the driver set them:

1. **Never use git's output when git failed.** The measuring call is
   `exec {*}$pre git -C $repo ls-files -- $pattern 2>/dev/null` inside a `catch`; on a
   nonzero status the captured variable is **emptied** before anything reads it. git's
   stderr never reaches the answer. A *separate* second call with `2>@1` supplies human
   text for `reason` only — the shape `issue_stamp.tcl`'s `git_in` already uses.
   `2>/dev/null` on the measuring call also stops a git *warning* (Tcl's `exec` raises on
   any stderr output, even at exit 0) from being read as a failure.
2. **Fall back to the filesystem, do not skip.** Where git cannot answer, the same files
   are enumerated from disk, so **coverage in an export is unchanged**. Skipping would
   have made the stranger's run green by measuring less, which is the failure the issue
   exists to prevent. Measured: the fs-derived list in the export is **byte-identical, in
   the same order, to git's list in the clone** — 104 files, `diff` and `cmp` both silent
   (not merely the same count).
3. **`skip:` is still the answer for a row that genuinely needs git** (trackedness
   itself, a revision, a diff): it reads `source`/`reason` and prints its own line.
   **None of the nine rows needed it** — every one of them wanted a corpus, not a
   trackedness assertion.
4. **The run still says where its corpus came from.** `test_corpus_note` prints
   `note: the committed .state corpus listed from the filesystem, not git: no .git in
   <repo> … -- 104 file(s) found`, once per suite. It is a `note:` and not a `skip:`
   because nothing was skipped and no check was lost; calling it a skip would have been
   a lie in the other direction.

⚠ **§3 IS SUPERSEDED ON FOUR POINTS BY THE FIX ROUND BELOW, and rule 4 as written was
MEASURED FALSE.** The verifiers reproduced it: `run_suites.sh` prints only `^skip:` lines
under a verdict, so the `note:` never reached the command this project documents as the
armed spelling, and a green export run was indistinguishable from a green clone run.
It reaches it now, under the prefix `note: corpus-source --`. Also superseded: the dict
gains a `skipped` key and `reason` is no longer always `{}` on the git arm; the walk no
longer skips every dot-directory (it skips `.git` and `.scratch` by name) and can no longer
RAISE; and "git answered nothing" is no longer a fallback trigger — `__corpus_git_scope`
decides whether git was answering about THIS checkout at all. Read §3 as the design intent
and the fix round as the shipped behaviour.

Details that are load-bearing:

* `pattern` is matched with `string match` against the **repo-relative path**, so
  `*.state` matches at any depth exactly as git's pathspec does.
* The walk **skips every directory whose name begins with `.`** — `.git` itself, and
  also `tests/headless/.scratch`, where a suite's own throwaway `.state` files live and
  which git never listed either. It does not follow directory symlinks (`file type` does
  not follow the last component).
* The git call is bounded: `timeout 60` when coreutils' `timeout` is on `PATH`
  (resolved once with `auto_execok`), plain `git` when it is not. A suite's own watchdog
  cannot fire inside a blocking `exec` (`test_suite_watchdog_1403` row W13), and hard-coding
  the prefix would have made **every** call fail on a box without `timeout` and silently
  dropped a perfectly good checkout to the filesystem arm.
* Cost, measured: `git` arm **103 ms**, `fs` arm **163 ms** for the whole tree, once per
  suite. (Without the `timeout` prefix the git arm is 5 ms; the fork is the difference.)

### Files changed (7, all under `tests/headless/`)

| file | what changed |
|---|---|
| `tests/headless/scratch.tcl` | **+136** — `__corpus_git_pre`, `__corpus_walk`, `test_corpus_files`, `test_corpus_note`, and the header explaining the defect class |
| `tests/headless/state_roundtrip.tcl` | corpus line replaced; returns `source`/`reason` too. Serves **four** of the nine (`1466`, `1467`, `1470`, `1471`) |
| `tests/headless/test_ase_core.tcl` | `CPF` — the `GIT-LS-FILES-FAILED` sentinel is gone |
| `tests/headless/test_ase_simcaps_0948.tcl` | `W6`'s corpus (`W_OUT`/`W_REL` → `W_CORP`) |
| `tests/headless/test_ase_options_1437.tcl` | `DL5`'s corpus (bare `exec git ls-files` inside the `apply`) |
| `tests/headless/test_ase_predeck_1439.tcl` | `RD10`'s corpus (same shape) |
| `tests/headless/test_ase_sp_1452.tcl` | `SCF` — the `if {![catch …]}` arm that left it empty |

No product source changed. **This is a test-side fix and item A is a test-side item**:
the nine suites were asking git a question about a working tree, and the tree they were
handed had no git. Nothing in `src/` behaves differently in an export.

Not committed, per the brief.

---

## 4. GREEN — after the fix

| suite | clone | export | nogit | `skip:` lines |
|---|---|---|---|---|
| `test_ase_core` | ALL PASS (675) | **ALL PASS (675)** | **ALL PASS (675)** | 0 |
| `test_ase_simcaps_0948` | ALL PASS (211) | **ALL PASS (211)** | **ALL PASS (211)** | 0 |
| `test_ase_options_1437` | ALL PASS (75) | **ALL PASS (75)** | **ALL PASS (75)** | 0 |
| `test_ase_predeck_1439` | ALL PASS (78) | **ALL PASS (78)** | **ALL PASS (78)** | 0 |
| `test_ase_sp_1452` | ALL PASS (58) | **ALL PASS (58)** | **ALL PASS (58)** | 0 |
| `test_ase_trnoise_1466` | ALL PASS (80) | **ALL PASS (80)** | **ALL PASS (80)** | 0 |
| `test_ase_trnoise_gui_1467` | ALL PASS (19) | **ALL PASS (19)** | **ALL PASS (19)** | 0 |
| `test_ase_variant_1470` | ALL PASS (76) | **ALL PASS (76)** | **ALL PASS (76)** | 0 |
| `test_ase_simwin_variant_1471` | ALL PASS (12) | **ALL PASS (12)** | **ALL PASS (12)** | 0 |

**1284 checks in each of the three trees. Not one lost, not one skipped.** The clone
column is byte-for-byte the pre-fix baseline of §2, so there is no regression in the
developer's condition.

⚠ **Green for the right reason, proved separately.** A green export could also mean "git
somehow worked". Each of the nine was re-run in the export with its full output
captured, and each printed **exactly one** `note: … listed from the filesystem, not
git: no .git in <export> … -- 104 file(s) found`. The fallback fired in all nine and
found the full corpus in all nine. The clone prints no such line at all.

### Collateral, in the clone

Other consumers of `scratch.tcl` and the two T1 cases that police the harness itself:

| suite | result |
|---|---|
| `test_ase_campaign_1462` | ALL PASS (161) — mentions `state_roundtrip.tcl` in a comment only |
| `test_ase_converge_1459` | ALL PASS (76) |
| `test_home_isolation` | ALL PASS (116) — row **G2** enumerates every launcher in the repo; the new `auto_execok` in `scratch.tcl` does not trip it |
| `test_home_isolation_sh` | ALL PASS (90) |
| `test_suite_watchdog_1403` | ALL PASS (32) |
| `test_regression_concurrency_1476` | ALL PASS (37) |
| `test_issue_stamp` | ALL PASS (93) |

---

## 5. SABOTAGE — every new fallback proved able to fail

Both sabotages were applied to the **export tree's copy** of `scratch.tcl` (byte-identical
to the main tree's), never to the main tree. Restored by copy afterwards and **verified by
md5**: `58d49d4b91cda9550fda3f99f7c8b9b7` in export, nogit and main alike.

### S1 — the filesystem enumeration returns NOTHING

`__corpus_walk` given a bare `return` as its first statement.

| suite | verdict under S1 | row(s) that reddened |
|---|---|---|
| `test_ase_core` | 6 FAILED (669 passed) | `CP1 CP2 CP3 CP4 CP7 CP7c` |
| `test_ase_simcaps_0948` | 1 FAILED (210) | `W6` |
| `test_ase_options_1437` | 1 FAILED (74) | `DL5` |
| `test_ase_predeck_1439` | 1 FAILED (77) | `RD10` |
| `test_ase_sp_1452` | 1 FAILED (57) | `SC1` |
| `test_ase_trnoise_1466` | 1 FAILED (79) | `NC1` |
| `test_ase_trnoise_gui_1467` | 1 FAILED (18) | `NC1` |
| `test_ase_variant_1470` | 1 FAILED (75) | `ST1` |
| `test_ase_simwin_variant_1471` | 1 FAILED (11) | `ST1` |

**All nine red, every one by name.** Run twice: once against the first version of the
helper and again against the final bytes after the `timeout`/`auto_execok` change, with
identical results.

⚠ **And note what S1 shows about the fix beyond non-vacuity: nothing dies any more.**
Under the unfixed code an empty/bogus corpus killed three suites outright and cost
`test_ase_core` 209 of its 675 rows. Under S1 the corpus is just as empty and every suite
still runs to its banner, reports its named rows and keeps its full check count. The
failure became *diagnosable* as well as *visible* — `CP7c` in particular now reports
rather than raising.

### S2 — the filesystem enumeration loses exactly ONE file (104 → 103)

`set files [lrange $files 1 end]` after the walk.

| suite | verdict under S2 | row(s) |
|---|---|---|
| `test_ase_core` | 2 FAILED (673) | `CP1 CP7` |
| `test_ase_sp_1452` | 1 FAILED (57) | `SC1` |
| `test_ase_trnoise_1466` | 1 FAILED (79) | `NC1` |
| `test_ase_trnoise_gui_1467` | 1 FAILED (18) | `NC1` |
| `test_ase_variant_1470` | 1 FAILED (75) | `ST1` |
| `test_ase_simwin_variant_1471` | 1 FAILED (11) | `ST1` |
| `test_ase_simcaps_0948` | **ALL PASS (211)** | — |
| `test_ase_options_1437` | **ALL PASS (75)** | — |
| `test_ase_predeck_1439` | **ALL PASS (78)** | — |

Six of nine notice the loss of a single file. The three that do not are **honest**, not
blind: `W6` asks `>= 7` current-source sweeps, and `DL5`/`RD10` count benches carrying a
particular option — none of which the one dropped file (`gf180mcuD/…/test_nfet_TRAN`,
first in sort order) happens to affect. For those three, S1 is the binding sabotage and
it reds them. **Recorded rather than tuned**: a sabotage chosen so that all nine go red
would have said less than this split does.

---

## 6. A FOURTH STRANGER SHAPE, NOT IN THE ISSUE — and it is the silent one

An export unpacked **inside another git repository** (a `~/src` that is itself tracked, a
dotfiles repo, a workspace under version control). `git -C <export> ls-files` then exits
**0** and lists **nothing** — the export's files are tracked by neither repo.

Measured, with the **unfixed** files restored from `HEAD` into the nogit tree and a
`git init`'d parent above it:

| suite | base code, inner-repo shape | fixed code |
|---|---|---|
| `test_ase_core` | 6 FAILED (669) — `CP1 CP2 CP3 CP4 CP7 CP7c` | **ALL PASS (675)** |
| `test_ase_variant_1470` | 1 FAILED — `ST1 … -> {0 {} 0 0} (exp {104 {} 1 1})` | **ALL PASS (76)** |
| `test_ase_sp_1452` | 1 FAILED — `SC1` | **ALL PASS (58)** |

**This shape has no error text in it anywhere.** Nothing dies, nothing raises, no
`fatal:` string appears — the corpus is simply empty and the rows report `{0 …}`. It is
the same defect wearing its quietest face, and it is the reason `test_corpus_files`
treats *"git answered and answered nothing"* as a fallback trigger rather than as an
answer. Suggest adding it to issue 1485's description.

---

## 7. Found outside item A — filed here, not fixed

### 7.1 Issue **1484** reproduced, and it explains 1485's one open question

1485 records: *"an F21 verifier wrote that `test_ase_variant_1470` (`OT1`) and
`test_ase_sp_1452` (`SE1`) were already red in a fresh-HOME git clone. On this box both
passed in the full-clone control. The difference is UNKNOWN"*, and adds that 1484 *"may
be the explanation. That is INFERRED."*

**It is now measured, for both rows, by accident of this crew's assigned scratch path.**
The identical export, built twice from the same `HEAD`:

| export built at | `test_ase_variant_1470` | `test_ase_sp_1452` |
|---|---|---|
| `…/stranger_reds/**A**/export` (uppercase `A`) | `OT1` **FAIL** (+ the item-A death) | `SE1/apt` **FAIL**, `SE1/fork` **FAIL** → `3 FAILED (55 passed)` |
| `…/stranger_reds/a_trees/export` (all lowercase) | `OT1` **ok** | `SE1` **ok** → `1 FAILED (57 passed)` |

Same commit, same binary size, same fresh throwaway HOME, same `AUDIT_DISPLAY=none`, one
directory name apart. That is 1484, it accounts for exactly the two rows 1485 could not
explain, and it is **independent confirmation from a crew that was not looking for it**.
Belongs on item C. Suggest 1485's "did not reproduce" paragraph be amended to point at
it, and that 1484 be upgraded from INFERRED to MEASURED **for these two rows**
(the mechanism — the unquoted `wrs2p` path — is still not traced).

### 7.2 Two `ST1` rows expect the corpus to be **exactly** 104

`test_ase_variant_1470` and `test_ase_simwin_variant_1471` both assert
`{104 {} 1 1}`, where every sibling row in `test_ase_core` and `test_ase_sp_1452` uses
`>= 104` **on purpose** — `test_ase_core`'s own comment says *"Adding a bench is ordinary
work and must not red this suite"*. So committing a 105th bench reds those two rows and
nothing else, and in a git-less checkout the filesystem arm will also count a `.state`
file the user created themselves. **Not changed: out of item A's scope**, and no
regression either way (the same tree *died* before this fix). Worth a one-line decision
by the driver — `>= 104` would match the stated intent without weakening anything, since
`bad` must still be `{}`.

Note the developer's own clone already carries such a file — untracked:
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/tb_bandgap.state` (105 on
disk, 104 tracked). It is invisible today because the clone takes the git arm.

### 7.3 `test_ase_core`'s death was worth 209 rows

Under the unfixed code in an export, `test_ase_core` printed 461 `ok:` and 5 `FAIL:` and
then died — **466 of 675 rows**, so 209 rows never ran and the suite reported no verdict
at all. Not a separate defect (it is 1485's `GIT-LS-FILES-FAILED` sentinel), but it is
the largest single coverage loss in the issue and the table in 1485 records it only as
*"couldn't open …"*.

---

## 8. Scratch, and what was NOT done

**Peak scratch: 304 MB** (`du -sh` on `…/scratchpad/stranger_reds` with both built trees
and all logs present). The discarded uppercase-path pair was the same two trees and was
deleted **before** the lowercase pair was created, so the two never coexisted and 304 MB
is the peak. Deleted at the end of this receipt's work; `/tmp` returned to its prior
free space and no `xschem-test-home.*` survived any run.

* **T1 was not run.** T1's display arm attaches to — and, given
  `~/.claude/xschem_dev_display` exists, can auto-start — the dev display `:99`, which
  the task forbids this crew from touching. The gate is the driver's; this receipt
  supplies the nine suites' counts in the clone (§4) as the no-regression evidence.
* **Nothing was committed.** Seven modified files, `git status` otherwise unchanged from
  session start (the same four pre-existing untracked entries, no new litter — no
  `untitled~.sch` appeared, so issue 1486 did not fire on these runs).
* **`test_ase_campaign_1462` was not touched.** It names `state_roundtrip.tcl` in a
  comment only and is not among the nine; it is one of 1484's five.
* **The other corpus readers in the tree were left alone**, being outside item A:
  `test_annot_declutter_1244.tcl` describes a `git ls-files` scanner in a comment, and
  `test_home_isolation*.tcl`, `test_library_git*.tcl`, `test_lib_manager_*.tcl`,
  `test_ase_view.tcl`, `test_libmgr_mutation_log.tcl` and `test_audit_classifier.tcl`
  use git against repositories **they create themselves** in scratch, which exist in an
  export too. None of them appeared in 1485's table. ⚠ **That is a READ of the code, not
  a measurement** — only the nine were run in the stranger trees, so nothing here says
  the rest of T1 is green in an export. A full T1 in an export is the obvious next
  measurement and nobody has taken it.

---

# Receipt — item A (issue 1485), FIX ROUND

**The one fix round (PLAN.md criterion 5). Twelve verifier findings, all re-measured
before acting: 9 applied, 3 rejected (2 out of scope and filed for the driver).** The
per-finding disposition, with the measurements, is `A-verify.md`; this section records
what changed in the tree and the final numbers.

Fixer, 2026-09-20. Tree at start: `bbc9de1a` + the implement round's 7 uncommitted files.
**No product source changed.** Still test-side, still item A.

---

## F1. What the verifiers found that mattered

The implement round fixed the defect the issue describes and introduced, or left standing,
four things a stranger or a developer can still hit. All four were reproduced here first:

| # | condition | implement-round behaviour |
|---|---|---|
| 1 | the tester saves a variant of a shipped bench (104 → 105 on disk) | **4 rows red** — `test_ase_variant_1470` ST1, `test_ase_simwin_variant_1471` ST1, `test_ase_predeck_1439` RD10, `test_ase_options_1437` DL5. The same file in a clone is green, so the two conditions disagreed. |
| 2 | one directory anywhere in the tree the tester cannot read | **3 suites die with NO verdict** — `NORESULT` for `test_ase_core`, `test_ase_variant_1470`, `test_ase_sp_1452`. The exact failure shape item A exists to remove, reintroduced by the fix's own new code. |
| 3 | a checkout whose corpus has stopped being tracked (`git rm --cached -- '*.state'`) | **`ALL PASS (675/58/76/12/80)`** where the pre-item-A code gave **10 counted failures**. Every row whose name says "tracked" passing by measuring untracked files. |
| 4 | an export unpacked inside a repository that tracks PART of it | `source=git n=50` — **54 corpus files invisible, at exit 0, in silence**. |

Plus: the provenance `note:` never reached `run_suites.sh` (so a green export run read
exactly like a green clone run through the one command this project documents), the fs arm
answered **ZERO** for any dot-file pattern, and a symlinked directory was dropped without
saying so.

---

## F2. What changed

### `tests/headless/scratch.tcl` — the helper

**One new question, answered once per repo and cached: WHICH REPOSITORY IS GIT ANSWERING
ABOUT?**

```tcl
__corpus_git_scope $repo   ->  self | other | none
```

`git -C $repo rev-parse --show-toplevel`, compared to `$repo` by normalized name and then
by device+inode (git prints a physical path; `$repo` may reach the same directory through a
symlink). On any doubt it answers `other`/`none` and the filesystem arm runs — a wrong `fs`
costs a superset and a printed note, a wrong `git` costs a silently truncated corpus.

* **`self`** — `$repo` IS a checkout root. git's list is authoritative **including when it
  is empty**, which is condition 3: the rows red and the note says why, instead of the walk
  quietly supplying what the index no longer has.
* **`other`** — git works, but its toplevel is somebody else's: an export inside a tracked
  `~/src`, a dotfiles repo, or a `GIT_DIR`/`GIT_WORK_TREE` exported by a hook,
  `git bisect run` or `rebase --exec`. Filesystem arm. That is condition 4, **and** it
  subsumes the implement round's §6 shape, which no longer needs a special case.
* **`none`** — no `.git`, no git, or a refusal such as `fatal: detected dubious ownership`.
  Filesystem arm. The ZIP/tarball/`git archive` shape the item is about.

**The walk can no longer raise, and no longer lies by omission.** Both `glob` calls are
`catch`ed — `-nocomplain` suppresses "no matches", not "permission denied". A directory it
cannot read, and a directory symlink it will not follow, go into a `skipped` list the dict
carries and the note names. It also enumerates **dot entries** (`* .*`, minus `.` and
`..`), skipping only `.git` and `.scratch` by name, because Tcl's `glob *` never matches a
dot basename.

**`lsort -unique`** on both arms: an unmerged index prints a conflicted path once per stage,
and a corpus is a set.

**The note's prefix is now `note: corpus-source --`**, and it also speaks when git answered
for this checkout and listed nothing.

### `tests/headless/run_suites.sh` — the provenance reaches the driver

One `grep -E '^note: corpus-source'` beside the existing `^skip:` echo, with D13.11's own
argument applied to provenance, and the header updated. It is **not** a bare `^note:`:
`note:` is this repo's general diagnostic prefix and `test_ase_core` alone prints 17 of
them.

### Four rows became floors, with their shape halves left exact

| row | was | is | what still has to hold exactly |
|---|---|---|---|
| `test_ase_variant_1470` ST1 | `{104 {} 1 1}` | `{1 {} 1 1}` on `tracked >= 104` | `bad` empty, both controls |
| `test_ase_simwin_variant_1471` ST1 | `{104 {} 1 1}` | the same | the same |
| `test_ase_predeck_1439` RD10 | `{5 0 5}` | `{1 0 1}` on `n >= 5`, `valued == n` | `bare == 0`, and now EVERY bench renders the value, not just five |
| `test_ase_options_1437` DL5 | `{1 {acct list} 0}` | `{1 {acct list} 0}` on `files >= 1` | the option-name set, and `wn == 0` |

This is the idiom `test_ase_core` CP1/CP7 and `test_ase_trnoise_1466` NC1 already use on
purpose — CP1's own comment says *"Adding a bench is ordinary work and must not red this
suite"*. ⚠ **DL5 gives up one thing**: "exactly ONE bench with an inert option" became "at
least one", so a *second* bench carrying the same two inert rows no longer reds it. The
option names and the wnflag count carry the rest. Named rather than buried; the alternative
was to branch the row on `source`, which would make the developer's condition and the
stranger's measure different things.

### Files changed (10, all under `tests/headless/`)

| file | what changed |
|---|---|
| `scratch.tcl` | `__corpus_git_scope`, `__corpus_same_dir`, the catching/dot-aware/skip-counting `__corpus_walk`, `test_corpus_files` rebuilt on scope, `test_corpus_note` |
| `run_suites.sh` | echoes `^note: corpus-source` under each verdict |
| `state_roundtrip.tcl`, `test_ase_core.tcl`, `test_ase_simcaps_0948.tcl`, `test_ase_sp_1452.tcl` | unchanged by this round (the implement round's edits) |
| `test_ase_variant_1470.tcl`, `test_ase_simwin_variant_1471.tcl`, `test_ase_predeck_1439.tcl`, `test_ase_options_1437.tcl` | the four floors |

---

## F3. GREEN — the final measurements

Three trees, all rebuilt from scratch (`./configure`, `timeout 900 make -C src -j8`, rc 0,
`src/xschem` 1 688 064 bytes in each), plus the developer's own clone.

| suite | main clone | **export** | **nogit + 3 user benches** | throwaway clone (`.git`) |
|---|---|---|---|---|
| `test_ase_core` | ALL PASS (675) | **ALL PASS (675)** | **ALL PASS (675)** | ALL PASS (675) |
| `test_ase_simcaps_0948` | ALL PASS (211) | **ALL PASS (211)** | **ALL PASS (211)** | ALL PASS (211) |
| `test_ase_options_1437` | ALL PASS (75) | **ALL PASS (75)** | **ALL PASS (75)** | ALL PASS (75) |
| `test_ase_predeck_1439` | ALL PASS (78) | **ALL PASS (78)** | **ALL PASS (78)** | ALL PASS (78) |
| `test_ase_sp_1452` | ALL PASS (58) | **ALL PASS (58)** | **ALL PASS (58)** | ALL PASS (58) |
| `test_ase_trnoise_1466` | ALL PASS (80) | **ALL PASS (80)** | **ALL PASS (80)** | ALL PASS (80) |
| `test_ase_trnoise_gui_1467` | ALL PASS (19) | **ALL PASS (19)** | **ALL PASS (19)** | ALL PASS (19) |
| `test_ase_variant_1470` | ALL PASS (76) | **ALL PASS (76)** | **ALL PASS (76)** | ALL PASS (76) |
| `test_ase_simwin_variant_1471` | ALL PASS (12) | **ALL PASS (12)** | **ALL PASS (12)** | ALL PASS (12) |

**1284 checks in every column. Not one lost, not one skipped.** The `nogit` column carries
three benches the tester "saved" — the condition that reddened four rows before this round.

**Provenance, now visible through the armed driver**: 9 of 9 suites print exactly one
`note: corpus-source -- … no .git in <export> … -- 104 file(s) found` under their verdict
in the export; 0 of 9 in a clone.

### The other shapes, after

| shape | probe |
|---|---|
| export, no `.git` | `fs 104` |
| nogit + 3 user benches | `fs 107` |
| clone | `git 104` |
| clone, corpus untracked | **`git 0`** + note, and the 10 rows red |
| export inside a repo tracking nothing of it | `fs 104` |
| export inside a repo tracking PART of it | **`fs 104`** (was `git 50`) |
| clone, git refusing (dubious-ownership shim on PATH) | `fs 104`, reason names the refusal |
| export with one unreadable directory | `fs 104`, note: *1 directory not read or not followed* |
| export with a symlinked `tests/` | `fs 103`, note: *1 directory not read or not followed (tests)* |
| dot patterns, git vs fs | `*.yaml` 2/2 · `.github/*` 2/2 · `*.gitignore` 8/8 · `*.spiceinit` 5/5 (all were `n/0`) |

### Collateral, in the main clone

| suite | result |
|---|---|
| `test_home_isolation_sh` | ALL PASS (90) — row **S1** asserts the exact two lines after a `run_suites.sh` verdict; the new echo does not disturb it |
| `test_home_isolation` | ALL PASS (116) — row **G2** enumerates every launcher in the repo |
| `test_audit_classifier` | ALL PASS (75) — C44/K18 pin `run_suites.sh`'s other regexps |
| `test_ase_campaign_1462` | ALL PASS (161) |
| `test_suite_watchdog_1403` | ALL PASS (32) |
| `test_issue_stamp` | ALL PASS (93) |

---

## F4. SABOTAGE — re-run, because the walker was rewritten

All three applied to the **export tree's copy** of `scratch.tcl`, never to the main tree;
restored by copy and **verified by md5** (`0edf8925bebd13408f0fa9e8d9a45b4b`, identical in
the export and the main tree).

**S1 — the walk returns NOTHING** (a bare `return` as `__corpus_walk`'s first statement).
All nine red, every one by name, **nothing dies and no suite loses a check**:
`test_ase_core` 6 FAILED (669) `CP1 CP2 CP3 CP4 CP7 CP7c`; `test_ase_simcaps_0948` `W6`;
`test_ase_options_1437` `DL5`; `test_ase_predeck_1439` `RD10 -> {0 0 1} (exp {1 0 1})`;
`test_ase_sp_1452` `SC1`; `test_ase_trnoise_1466` / `_gui_1467` `NC1`;
`test_ase_variant_1470` / `test_ase_simwin_variant_1471` `ST1`. **The floors are not
vacuous** — RD10 and DL5 both red under S1.

**S2 — the walk loses exactly ONE file** (`set files [lrange $files 1 end]`). The same
6-of-9 split as the implement round, row for row: `test_ase_core` 2 FAILED (673) `CP1 CP7`;
`SC1`; `NC1` ×2; `ST1` ×2; and `test_ase_simcaps_0948` / `test_ase_options_1437` /
`test_ase_predeck_1439` honestly green, because the one dropped file affects none of their
claims. **The floors did not blunt S2**: `ST1` at 103 still reds.

**S3 (new) — `__corpus_git_scope` forced to answer `self`.** In the partial inner-repo
shape, `test_ase_core` 3 FAILED `CP1 CP4 CP7`, `test_ase_variant_1470` `ST1`,
`test_ase_sp_1452` `SC1` — the item-A shape exactly. With the check in place those rows
pass. The scope test is load-bearing, not decorative.

---

## F5. Scratch, and what was NOT done

**Peak scratch: 1010 MB** (`du -sh` on `…/scratchpad/stranger_reds` with all four built
trees — export, nogit, a throwaway clone with `.git`, and two copies used for the
inner-repo and symlink shapes — plus every log). Deleted at the end of this round.

⚠ **The trees are under `…/stranger_reds/a_fix/`, not the assigned `…/stranger_reds/A/`,
for the implement round's §1 reason**: an uppercase letter in the checkout path is issue
1484 and reds two rows on its own. Logs and scripts stayed under `A/`.

* **T1 was not run**, for the implement round's reason: T1's display arm can auto-start the
  dev display `:99`, which this crew is forbidden to touch. The gate is the driver's. The
  nine suites' counts in the main clone (F3) plus the six collateral T1 cases are the
  no-regression evidence.
* **Nothing was committed.** Ten modified files, no new untracked litter, no
  `untitled~.sch`.
* **`full_audit.sh` does not echo the note.** It is a second reader with its own EREs, and
  `test_audit_classifier` section K locks parts of it. One line of the same shape if the
  driver wants it. Left for the driver.
* **The provenance is not in the `RESULT:` banner**, which is where it would survive into
  `results.log`. Nine banner edits under a rule three readers police — a bigger change than
  this round should make, and adjacent to item E / issue 1487. Left for the driver.
* **Out of item A and filed, not fixed**: a checkout path containing a **space** reds 5
  suites and 71 rows, all simulator-invocation rows. Independently re-confirmed here for
  the uppercase variant (`SE1/apt`, `SE1/fork`, `OT1`), and **the mechanism is now
  located**: `ase::sp_export_lines` in `src/ase.tcl` builds `"wrs2p [s2p_file $state $idx]"`
  — an **unquoted path on an ngspice control line**. Issue **1484** / item C should be
  widened from "a capital letter" to that.
* **A read-only checkout** still dies in `test_scratch` and in `state_roundtrip.tcl`'s tmp
  file, both of which write inside the tree. The corpus helper itself is read-only-safe
  (104 against a `chmod -R a-w` tree). A separate item; a read-only tree cannot be built
  anyway.
