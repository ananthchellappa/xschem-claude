# 1485 — nine T1 suites go red in a `git archive` export because they read their corpus through git

**STAMP:** `v1 claim=fixed tree=1f3f5287 stamped=2026-09-20 fix=taken open=3 by=A-docs`

**Status: FIXED 2026-09-20 in `1f3f5287`** (stranger-reds batch, item A: one implement
round, one adversarial verify, one fix round). The nine suites below are green in a
`git archive` export, in a `.git`-removed clone, in a throwaway clone and in the developer's
own clone, **1284 checks in every one and not a single `skip:`**. The measurements, the
sabotages and the four conditions the verifiers found are in
`doc/claude/stranger_reds_batch/receipts/A-impl.md` and `A-verify.md`; the resolution is the
section "What was done" below. `open=3` counts the list in "What is still open", which is
adjacent work rather than this defect.

**Filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D1 and D12 (outsider audit **F21**).
**Class** stranger-facing false red in T1. Nine suites, one shared shape. Everything below
this line is the file as filed, kept as the record of what was measured then.

---

## What happens

A GitHub "Download ZIP", a release tarball or a `git archive` export has no `.git`. It
builds cleanly, and T1 in it then reports suites red that are green in a clone. Each of
them lists or reads its corpus through `git ls-files` or `git rev-parse`, and then **uses
git's error text as data**: as a file path, as an empty list, or as a dict to parse.

The tenth red case in the audit's count, `test_issue_stamp`, was the batch's own
regression and is **fixed** (Item 1, `aa5cece0` / `d42fc517`). Per D1 none of the nine
below was touched: they share the checker's symptom, not its code.

## The nine, MEASURED by the S1 crew (`receipts/S1.md` §7)

Command: `cd <export>/tests && env -u DISPLAY HOME=<fresh scratch> timeout 1800 tclsh
run_regression.tcl`, at the 85-case tree. Final run `T1-RUN-END pid=2248951 cases=85
blocks=84 counted_failures=29`. The control re-ran each case exactly as T1 runs it, in a
**full clone**, each with its own fresh HOME.

| case | counted | failing line in the export | full-clone control |
|---|---|---|---|
| `test_ase_core` | 6 | `CP1`–`CP4` and `CP7` FAIL, then `couldn't open "GIT-LS-FILES-FAILED"` | `ALL PASS (675)` |
| `test_ase_simcaps_0948` | 2 | `W6 … -> {0} (exp {1}) : FAIL` (the corpus read swallowed to empty) | `ALL PASS (211)` |
| `test_ase_options_1437` | 2 | `DL5 … -> {RAISED:fatal: not a git repository …}` | `ALL PASS (75)` |
| `test_ase_predeck_1439` | 2 | `RD10 … -> {RAISED:fatal: not a git repository …} (exp {5 0 5})` | `ALL PASS (78)` |
| `test_ase_sp_1452` | 2 | `SC1 every tracked state file still round-trips … -> {0 {} 0 0 …}` | `ALL PASS (58)` |
| `test_ase_trnoise_1466` | 1 | died after 58 ok: `couldn't open "<export>/fatal: not a git repository …"` | `ALL PASS (80)` |
| `test_ase_trnoise_gui_1467` | 2 | `N0 … -> {RAISED:couldn't open "<export>/fatal: not a git repository …"}` | `ALL PASS (19)` |
| `test_ase_variant_1470` | 1 | died after 75 ok, the same `couldn't open "<export>/fatal: …"` | `ALL PASS (76)` |
| `test_ase_simwin_variant_1471` | 2 | `ST1 … -> {RAISED:dict element in quotes followed by ":" instead of space}` | `ALL PASS (12)` |

**20 counted lines in total.** The same run's other nine counted lines are not this
issue: eight are the four DISPLAY-unset segfaults (issue **1483**; the run had DISPLAY
unset), and one is `create_save`'s first-run `~/.xschem` mkdir race (audit F25), which the
throwaway HOME now pre-creates away (`7a46275f`).

Two causes in the table are READ from code, not traced. `test_ase_core` has
`set CPF {GIT-LS-FILES-FAILED}`, a sentinel that ends up used as a path, and
`test_ase_simcaps_0948` has `if {[catch {exec git -C $repo ls-files -- *.state} W_OUT]}
{ set W_OUT {} }`. For `test_ase_simwin_variant_1471` the cause (a state round-trip
parsing git's error text) is INFERRED from the audit.

**One audit claim did not reproduce:** an F21 verifier wrote that `test_ase_variant_1470`
(`OT1`) and `test_ase_sp_1452` (`SE1`) were already red in a fresh-HOME **git** clone. On
this box both passed in the full-clone control (76 and 58). The difference is UNKNOWN.
Note that `SE1` is also the row issue **1484** reddens in an uppercase path, which may be
the explanation. That is INFERRED.

> ✅ **RESOLVED 2026-09-20 — it is issue 1484, and it is now MEASURED for both rows.** Item
> A's implementer was assigned a scratch root with a capital `A` in it and reproduced
> exactly these two rows by accident; its fix round hit the same thing again. The identical
> export, built twice from the same `HEAD`, same binary, same fresh throwaway HOME, same
> `AUDIT_DISPLAY=none`, **one directory name apart**: at the uppercase path `OT1` **FAIL**
> and `SE1/apt` + `SE1/fork` **FAIL**; at the all-lowercase sibling `ALL PASS (76)` and
> `ALL PASS (58)`. **This file has no unknown left**, and 1484 carries the two rows as
> measured rather than inferred. `receipts/A-impl.md` §7.1 and `receipts/A-verify.md` R6.
> The wider finding — a path with a **space** reds 71 rows across five suites, and the
> unquoted `wrs2p` path is where it comes from — is issue **1490**.

## Fix direction

> ⚠ **SUPERSEDED — this is the shape that was proposed, not the shape that was taken.** The
> fix landed as a **shared helper that enumerates the same files from the filesystem**; its
> *skip* half was measured to be the wrong default, because a stranger's run would go green
> by measuring less. Read "What was done" in the resolution below before reusing any of this
> paragraph. The half that survived intact is its last two sentences: never feed an error
> string onward as data, and a skip must be by name and loud.

The remedy has already been built once, in `tests/headless/issue_stamp.tcl`: **classify
the history once** (`none` when there is no `.git`), and skip each corpus-dependent row
**by name**, with a `skip:` line saying why. Never feed an error string onward as data.
A shared helper (for example in `scratch.tcl`) that answers "the tracked files matching
`<glob>`, or a named reason there are none" would serve all nine. Every row that then
skips must be visible, which is issue **1487**'s point: today a skip never reaches the T1
verdict.

⚠ **A green export run is not the goal by itself.** Skipping must be by name and loud, or
this becomes a silent loss of coverage on exactly the shape a stranger runs.

## Evidence

`doc/claude/outsider_fixes_batch/receipts/S1.md` §7 (the table, the control and the sum),
`receipts/audit_findings_in_scope.md` (F21, its verifier's upholding).

---

# RESOLUTION — FIXED 2026-09-20, commit `1f3f5287`

Stranger-reds batch, item A: one implement round, one adversarial verify (two crews, 12
findings), one fix round. Receipts: `doc/claude/stranger_reds_batch/receipts/A-impl.md`
(implement and fix rounds) and `A-verify.md` (the 12 findings and their disposition).
Decisions: that batch's `DECISIONS.md` **D3** and **D4**.

## What was done

**A corpus list is an enumeration question, not a trackedness question.** All nine suites
were asking git the same thing — *"the `.state` files of this checkout"* — and git was only
the cheapest enumerator. So `tests/headless/scratch.tcl` gained one shared helper,
`test_corpus_files` (with `test_corpus_note`), which answers that question from git when git
is answering **about this checkout**, and from the filesystem otherwise, together with a
`source`, a human `reason` and a list of directories it could not read or follow.

Three things it does that the fix direction above did not anticipate, each of them a
verifier's measurement:

* **Skipping was rejected as the default** (the fix direction's *"skip each corpus-dependent
  row by name"*). A stranger's run would have gone green by measuring less — the failure
  this issue exists to prevent rather than a fix for it. Measured: the filesystem-derived
  list in an export is **byte-identical, in the same order**, to git's list in a clone (104
  files; `diff` and `cmp` both silent). A row that genuinely needs git still reads `source`
  and `reason` and prints its own `skip:` line; **none of the nine needed to**.
* **"Git answered nothing" is not "git cannot answer here."** Falling back on an empty list
  hid a real defect: in a clone where the corpus had stopped being tracked
  (`git rm --cached -- '*.state'`), all nine passed by measuring untracked files, where the
  pre-fix code gave **10 counted failures**. The helper now asks which repository git is
  answering about (`__corpus_git_scope`: `self` / `other` / `none`), which also catches an
  export unpacked inside somebody else's checkout — measured at **50 of 104 files, at exit
  0, in silence**.
* **A corpus read must never raise.** `glob -nocomplain` suppresses "no matches", not
  "permission denied", so one unreadable directory killed three suites outright — the very
  shape this issue is about, reintroduced by the fix's own new code. Both globs are caught
  now, and unreadable or symlinked directories are counted and named in the run's `note:`
  line.

Four rows that asserted **exactly 104** corpus files became floors (`>= 104`), with their
shape halves left exact: they went red the moment a tester saved a variant of a shipped
bench, which is ordinary first use of the branch. ⚠ One named, bounded loss:
`test_ase_options_1437` `DL5` no longer asserts *exactly one* bench carrying an inert
option, only *at least one*; the option-name set and the wnflag count still hold exactly.

`run_suites.sh` now echoes `^note: corpus-source` under each verdict, so provenance reaches
the command this project documents as the armed spelling. Before that, a green export run
was indistinguishable from a green clone run.

**No product source changed.** This is a test-side fix to a test-side defect: the nine
suites asked git a question about a working tree, and the tree they were handed had no git.

## The nine, green — measured in four trees

All rebuilt from scratch (`./configure`, `make -C src`, rc 0, `src/xschem` 1 688 064 bytes
in each), every suite run as T1 runs an `hcase`:
`AUDIT_DISPLAY=none GUI_GATE=0 SUITE_TIMEOUT=900 run_suites.sh --nogui <suite>`.

| suite | main clone | export (`git archive`, no `.git`) | `.git` removed, + 3 benches a tester saved | throwaway clone |
|---|---|---|---|---|
| `test_ase_core` | ALL PASS (675) | ALL PASS (675) | ALL PASS (675) | ALL PASS (675) |
| `test_ase_simcaps_0948` | ALL PASS (211) | ALL PASS (211) | ALL PASS (211) | ALL PASS (211) |
| `test_ase_options_1437` | ALL PASS (75) | ALL PASS (75) | ALL PASS (75) | ALL PASS (75) |
| `test_ase_predeck_1439` | ALL PASS (78) | ALL PASS (78) | ALL PASS (78) | ALL PASS (78) |
| `test_ase_sp_1452` | ALL PASS (58) | ALL PASS (58) | ALL PASS (58) | ALL PASS (58) |
| `test_ase_trnoise_1466` | ALL PASS (80) | ALL PASS (80) | ALL PASS (80) | ALL PASS (80) |
| `test_ase_trnoise_gui_1467` | ALL PASS (19) | ALL PASS (19) | ALL PASS (19) | ALL PASS (19) |
| `test_ase_variant_1470` | ALL PASS (76) | ALL PASS (76) | ALL PASS (76) | ALL PASS (76) |
| `test_ase_simwin_variant_1471` | ALL PASS (12) | ALL PASS (12) | ALL PASS (12) | ALL PASS (12) |

**1284 checks in every column, none lost and none skipped**, and the clone column is
byte-for-byte the pre-fix baseline — no regression in the developer's condition. Green for
the right reason, proved separately: each of the nine prints exactly one
`note: corpus-source -- … no .git in <export> … -- 104 file(s) found` in the export, and
none at all in a clone.

Other shapes, after: export inside a repo tracking part of it `fs 104` (was `git 50`);
clone with the corpus untracked `git 0` plus a loud note **and the 10 rows red**; git
refusing with a dubious-ownership shim `fs 104` with the refusal named; one unreadable
directory and one symlinked directory each counted and named. Dot-file patterns, which the
filesystem arm used to answer **zero** for, now agree with git exactly (`*.yaml` 2/2,
`.github/*` 2/2, `*.gitignore` 8/8, `*.spiceinit` 5/5).

Three sabotages prove the new code can fail: the walk returning **nothing** reds all nine by
name (and, unlike the unfixed code, nothing dies and no suite loses a check); the walk
losing **exactly one** file reds six of nine, the other three honestly unaffected; and
forcing the scope probe to answer `self` reproduces the item's own shape.

## A fourth stranger shape, not in the description above

An export unpacked **inside another git repository** — a `~/src` that is itself tracked, a
dotfiles repo, a workspace under version control. `git -C <export> ls-files` then exits **0**
and lists **nothing**: the export's files are tracked by neither repo. **There is no error
text anywhere in this shape** — nothing dies, nothing raises, no `fatal:` string appears, the
corpus is simply empty and the rows report `{0 …}`. It is the same defect wearing its
quietest face, it was measured red on the unfixed code (`test_ase_core` 6 FAILED,
`test_ase_variant_1470` `ST1`, `test_ase_sp_1452` `SC1`) and green after, and it is why the
helper asks *which repository* rather than *did git say anything*.

## What is still open (3)

1. **Provenance is not in the `RESULT:` banner**, only under `run_suites.sh`'s verdict, so
   it does not survive into `results.log`. Nine banner edits under a rule three readers
   police (`banner_complete`) — adjacent to issue **1487**.
2. **`full_audit.sh` does not echo the note either.** A second reader with its own EREs,
   parts of which `test_audit_classifier` section K locks. One line of the same shape.
3. **A full T1 in an export has never been run.** Only these nine suites were measured in
   the stranger trees; the claim that the rest of T1 is unaffected is a READ of the other
   corpus readers in the tree, not a measurement.
