# F-impl — issue 1486: suites drop `untitled~.sch` into whatever directory they were run from

Implementer receipt. Tree: `fluid-editing`, HEAD `9fcf9177`. All measurements taken on a
binary rebuilt from the tree that produced them (`timeout 900 make -C src`).

---

## ⚠ ONE THING THE DRIVER MUST DO: REGISTER THE NEW T1 CASE

`tests/headless/test_untitled_autosave_1486.tcl` is **not registered**, because registering
it means editing `tests/run_regression.tcl` — which item E's crew was editing throughout
this round (measured: `M tests/run_regression.tcl` at 21:22, `M
tests/headless/test_regression_concurrency_1476.tcl` at 21:26, `receipts/E-impl.md`
appearing at the end). The brief said touch only my own files, so I did not.

One line, at `tests/run_regression.tcl:96` (the last `hcases` entry at this HEAD):

```tcl
                 "headless/test_home_isolation_sh" \
                 "headless/test_untitled_autosave_1486"]
```

That makes T1 **88 cases / 87 `Total num fail:` lines**. Until it is done, the fix is
green but ungated.

## ⚠ AND ONE THING NOBODY TOUCHED, AS INSTRUCTED

`.xschem/op_param_lists.conf` (the user's own Save) was **not read, written, moved or
deleted**. Verified at the end of the round: mtime **2026-09-09 09:58:51**, 2236 bytes,
md5 `aedef2a43789f827edd75934d703056e` — the same mtime issue 1486 records for it.
The fix deliberately does **not** move the cwd (see below), so
`op_param_lists::conf_path project`, which is `[file join [pwd] .xschem
op_param_lists.conf]`, still resolves exactly where it did. Issue 1486's open item 2 (a
driver run reading the tester's project tier) is therefore **unchanged, not fixed** — it
is a ruling, not a bug to sweep past.

---

## 1. The defect, measured before anything was changed

**Method.** All **405** `tests/headless/test_*.tcl`, each run in a private directory it
owned, with its own empty HOME, seeded with `untitled~.sch` (a canary) and
`untitled~.sym`, and afterwards checked for (a) a changed or deleted canary and (b) any
new file. Named outcomes only: `CLEAN` / `CANARY-*` / `LITTER[...]` / `TIMEOUT`.
Script `sweep.sh`, 6–8 way parallel, 120 s per suite.

```
405 suites          353 CLEAN
                     51 destroy a pre-existing untitled~.sch
                         34 OVERWRITE it      17 DELETE it
                      1 of those (test_add_pin_lib_symbol_view) takes untitled~.sym too
                      0 leave any OTHER file behind
                      1 TIMEOUT (test_ase_optier_0963, a 120 s artefact -- §6.4)
```

**So the untitled autosave is the whole of this class.** No suite in the corpus writes
anything else into its working directory. The 51 names are in
`/var/tmp/xsr_f/F/sweep_before.txt` (deleted with the scratch); the ones used as
fixtures below are `test_crossview_paste` and `test_descend_refusal_channel_0251`
(delete), `test_descend_inert_class` and `test_signal_short_nohier_0230` (overwrite).

**Two mechanisms, pinned by micro-probe** (three scripts, private cwd, seeded canary):

| child script | canary afterwards |
|---|---|
| nothing (`puts`, `exit`) | **untouched** |
| `xschem clear force` — no edit at all | **DELETED** |
| one `xschem instance` on the untitled buffer | **OVERWRITTEN**, 113 B, md5 `2dbeb0ea88ae0a73d6d34e6efc5463e3` |

The overwrite is `set_modify(1)` → `write_backup()`, deliberate (issue 0060). The
**delete is `clear_schematic()` → `remove_backup()`, and it is a product defect**: File >
New, with no edit anywhere, removes a `untitled~.sch` this session never wrote. That file
is a previous session's crash recovery — the very file `xschem_recover_backup()` exists
to offer back ("Unsaved changes from a previous session were found for: … Recover
them?"). The md5 above is byte-identical to the file issue 1480 §1 found in the repo root.

**⚠ AND THE ISSUE-0601 GUARD DOES NOT STOP THE DELETE.** `set ::autosave_backup 0`
returns early from `write_backup()` and has no effect on `remove_backup()`. Measured: of
the nine guarded suites, `test_instance_update`, `test_paste_modify_flag_0244`,
`test_placement_wire_gate` and `test_shape_draw_gate` all **DELETED** the seeded canary
while carrying the guard. `test_no_untitled_litter` cannot see this — every one of its
rows asks "did the suite leave anything behind", never "did a file that was already
there survive". Suppression was never the fix here, which is why the fix below is a
redirect and a product change rather than a blanket guard.

---

## 2. What changed

### 2a. Product: `clear_schematic()` must not delete a `~` this session never wrote

| file | change |
|---|---|
| `src/xschem.h` | new `int backup_written` in `Xschem_ctx`, beside `no_autosave` |
| `src/save.c` | `write_backup()` sets it after a successful write; `remove_backup()` clears it; `load_schematic()` clears it (a different buffer ⇒ we own nothing) |
| `src/actions.c` | `clear_schematic()`: `remove_backup();` → `if(xctx->backup_written) remove_backup();`, then clears the flag for the fresh buffer |

The spec-B8 invariant this call site exists for — *"a leftover ~ on the next open
unambiguously means a crash, not an intentional discard"* — is **strengthened**, not
weakened: an intentional discard can no longer leave a `~` that this session wrote, and
can no longer remove one that it did not. Row U3 holds the other direction so the fix
cannot degenerate into "never remove anything".

### 2b. Harness: the drivers redirect the autosave into a private directory

| file | change |
|---|---|
| `tests/headless/suite_cwd.sh` | **new**, 103 lines. A sourced library (it starts nothing, so G2's launcher census does not see it). `suite_cwd_arm <repo>` / `suite_cwd_for <tag>` / `suite_cwd_disarm`. |
| `tests/headless/run_suites.sh` | arms after the `cd "$REPO"`; a per-run `env "PWD=$_scwd"` on all three MODE arms; disarms after `gate_finish` and on the gate-stop exit |
| `tests/headless/full_audit.sh` | arms **after** the `AUDIT_LIB_ONLY` source-guard (library mode must create nothing); a per-test `env "PWD=$_scwd"` on all four exec sites; disarms after the loop, before the tree/scratch "after" snapshots |
| `tests/headless/gated_xschem.sh` | arms after its `cd "$REPO"`; `env "PWD=$_scwd"` on the one invocation; disarms on all three exits |

**Why `$PWD` and not the cwd.** xschem composes the untitled buffer's path from `$PWD`,
preferring it over `getcwd()` because it does not dereference symlinks
(`Tcl_AppInit`, and `load_schematic`'s no-file arm). Moving the **cwd** — 0609's stated
fix direction — is what D13.3 already half-did and it **breaks suites**: measured, with
every suite run from a private cwd, `test_reopen_readonly` dies at its line 20 with
`error copying "": no such file or directory` because it globs `[file join [pwd]
xschem_library …]`; its own header says *"cwd = repo root"*. Moving only `$PWD` leaves
`[pwd]` alone, because Tcl's `pwd` reads `getcwd()`. Measured directly:

```
TCL pwd=/home/analog/dev/xschem-claude          <- unchanged, fixtures still resolve
TCL env(PWD)=/var/tmp/xsr_f/F/pt/fake
XSCHEM schname=/var/tmp/xsr_f/F/pt/fake/untitled.sch   <- the buffer moved
XSCHEM current_dirname=/var/tmp/xsr_f/F/pt/fake
SUB: BASH PWD=/home/analog/dev/xschem-claude ; pwd=/home/analog/dev/xschem-claude
```

The last line matters: a **shell child re-derives `PWD` at startup**, so nothing
downstream is misled by the redirect.

The private directory is `tests/headless/.scratch/_suitecwd_<pid>/<tag>` — gitignored
(`.gitignore:85`), outside `full_audit.sh`'s `scratch_snapshot` globs, and named
`_<tag>_<pid>` so `scratch.tcl`'s dead-pid sweep collects it if a driver is killed before
it disarms. **One directory per run, not one per driver**: a leftover `untitled.sch`
would otherwise make the next suite's namer pick `untitled-1.sch`, i.e. make a verdict
depend on what ran before it. If the tree is read-only it falls back to `$TMPDIR`, and if
that fails it says so and runs with `$PWD` as it found it — this never stops a suite.

### 2c. The new T1 case

`tests/headless/test_untitled_autosave_1486.tcl`, 306 lines, **10 checks**:
`N0` presence · `U1` a clear with no edit leaves a foreign `untitled~.sch` byte-identical ·
`U2` an edit still WRITES it (issue 0060 not gutted) · `U3` a backup we DID write is still
dropped on discard (B8) · `U4` a loaded cell's foreign `cell~.sch` survives a later discard ·
`D2` positive control: the leaker run BARE does litter its cwd · `D1`/`D1b` the same suite
through `run_suites.sh` adds no `untitled*` to the checkout and leaves the caller's own file
alone · `D3` the run removed its private `$PWD` directory · `S1` source guard on the three
drivers.

Both `D1` and `D3` are **deltas, never existence tests** — `D1` because another suite (or
T1, whose cwd is `tests/`) may have littered before the row ran, which is the defect that
put `test_ase_core`'s C11 in 13 recorded red audits; `D3` because this suite is normally
run *through* `run_suites.sh` and that enclosing driver's own `_suitecwd_<pid>` is live
while the row executes. Both of those were found by the rows failing on the first run,
not by reasoning.

---

## 3. The same measurements after the fix

### 3a. Corpus, bare runs (the un-armed spelling)

| | before | after |
|---|---|---|
| suites destroying a seeded `untitled~.sch` | **51** | **38** |
| … by DELETING it | **17** | **3** |
| … by OVERWRITING it | 34 | 35 |
| suites destroying `untitled~.sym` | 1 | **0** |
| suites leaving any other file | 0 | 0 |

The three remaining deleters are **correct**: `test_backup_file` deletes its own at its
line 71 (`file delete -force $ubak`), and `test_instance_refusal` and `test_raw_case_mode`
write the backup themselves first. Measured, not argued — `./src/xschem -d 1` on
`test_instance_refusal` prints `write_backup(): wrote …/untitled~.sch` **ten or more
times** before the removal, so the file it removes is its own and the seed was already
lost to the first overwrite. (One suite moved from the delete column to the overwrite
column, which is why 34 → 35.)

### 3b. The drivers, red → green, one suite list run identically on both trees

Five suites in an order that leaves a writer immediately before the two suites whose own
rows assert a clean repo root — deleter first, so it cannot clean up after the writers.
`run_suites.sh --nogui test_crossview_paste test_descend_inert_class
test_signal_short_nohier_0230 test_ase_core test_op_dump_altshow`, launched from a
seeded directory of my own:

| | repo root `untitled*` after | repo-root listing | caller's canary | leftover `_suitecwd_*` | verdicts |
|---|---|---|---|---|---|
| `run_suites.sh` at HEAD | **`untitled~.sch`** | **changed** | intact | none | 5/5 PASS |
| `run_suites.sh` fixed | **(none)** | **unchanged** | intact | none | 5/5 PASS, same check counts (675 / 71 / 11) |

`full_audit.sh test_descend_inert_class test_op_dump_altshow`:

| | repo root after | the audit's own TREE arm said |
|---|---|---|
| at HEAD | **`untitled~.sch`** appeared | `TREE: 0 appeared` |
| fixed | nothing appeared | `TREE: 0 appeared` |

(That `0 appeared` on the unfixed run is issues 0353/0356 measured again: the tree arm is
`git status`, `*~.sch` is `.gitignore:75`. Not mine to fix; noted in §6.5.)

`gated_xschem.sh --nogui --pipe -q --nolog --script …/test_descend_inert_class.tcl`, run
from a directory of my own:

| | repo root after |
|---|---|
| at HEAD | **`untitled~.sch`** |
| fixed | nothing, listing byte-identical |

### 3c. The product, red → green (micro-probe, same three scripts as §1)

| child script | before | after |
|---|---|---|
| `xschem clear force`, no edit | canary **DELETED** | canary **survives byte-identical** |
| one `xschem instance` | canary overwritten, 113 B | unchanged (the buffer's own autosave — correct) |

---

## 4. No regression in the developer's condition

### 4a. Whole corpus, verdict by verdict

Three full 405-suite runs, the same verdict extractor on all three
(`^RESULT:|^OVERALL:|^PASS=|^SKIP: no X`):

| arm | binary | cwd | `$PWD` |
|---|---|---|---|
| **A** baseline | pre-fix | repo root | repo root |
| **B** | pre-fix | repo root | private |
| **C** | post-fix | private | private |

* **A vs B — the `$PWD` redirect: ONE difference in 405**, `test_ase_optier_0963`, and it
  is a timeout artefact, not the redirect: re-run alone with 400 s it is `RESULT: ALL
  PASS (109 checks)` in **both** arms, and the private-`$PWD` arm's directory was empty
  afterwards. So the redirect is inert across the entire corpus.
* **B vs C — the product change: TWO differences, neither attributable to it.**
  `test_ase_optier_0963` again (B timed out at 120 s, C passed at 200 s), and
  `test_regression_concurrency_1476` (17 → 24 FAILED) — which **item E's crew edited at
  21:26:38, between the two sweeps**, +186 lines (`git diff --stat`). My sweeps of it
  ran at 21:20 and 21:42. It fails in every arm because a bare run with an empty HOME is
  not the condition it is written for.
* 33 suites' autosave landed in the private `$PWD` directory in arm B, i.e. the redirect
  is doing the work rather than the write silently not happening.

### 4b. Suites run through the armed driver

On a private Xvfb `:171` that I started and killed myself (**the dev display `:99` was
never touched**; `~/.claude/xschem_dev_display` exists, so `AUDIT_DISPLAY` was always
either `none` or `:171`, never the default that would attach to `:99`):

```
PASS test_home_isolation_sh (90)      PASS test_home_isolation (116)   <- G2 launcher census: suite_cwd.sh is invisible to it,
PASS test_audit_classifier (75)       PASS test_backup_file                and C1/C2 (cwd = the repository root) still hold
PASS test_descend_untitled_preserve   PASS test_no_untitled_litter
PASS test_untitled_reuse (6)          PASS test_pristine_untitled_basename (2)
PASS test_untitled_name_dir_0323 (8)  PASS test_paste_modify_flag_0244 (444)
PASS test_placement_wire_gate (187)   PASS test_shape_draw_gate (421)
PASS test_instance_update (95)        PASS test_crossview_paste
PASS test_descend_inert_class         PASS test_reopen_readonly
PASS test_op_annot (485)              PASS test_annot_hier_0911 (15)
PASS test_descend_views               PASS test_descend_refusal_channel_0251
PASS test_add_pin_lib_symbol_view     PASS test_ase_core (675)
PASS test_op_dump_altshow (71)        PASS test_untitled_autosave_1486 (10)
full_audit.sh subset: SUMMARY 3 pass 0 fail 0 crash/timeout 0 skip; SCRATCH 0 leaked; TREE 0/0
run_suites.sh --help still prints the header and exits 0; an unknown option still exits 2
```

`test_home_isolation` (116 checks) and `test_home_isolation_sh` (90 checks) are the two
T1 cases most exposed to this change and both are green.

**T1 itself was NOT run, deliberately.** `tests/run_regression.tcl` and
`tests/headless/test_regression_concurrency_1476.tcl` carried item E's uncommitted
edits for the whole round, so a T1 number taken here would be a measurement of E's
in-flight tree, not of this change. The driver's gate run is the right place for it —
and see the registration note at the top, without which T1 does not cover this at all.

---

## 5. Sabotages — every new check shown failing

Nine, each reverted and rebuilt afterwards. The suite is `ALL PASS (10 checks)` before
and after each one.

| # | sabotage | rows that went red |
|---|---|---|
| 1 | `run_suites.sh`'s `nogui` arm loses its `env "PWD=$_scwd"` | **D1** (`new: …/untitled~.sch`) and **S1** |
| 2 | `run_suites.sh` loses the `suite_cwd_disarm` at the end | **D3** (`left: …/.scratch/_suitecwd_1722133`) |
| 3 | `full_audit.sh` loses its `suite_cwd_arm` call | **S1** (`full_audit.sh: no suite_cwd_arm call`) |
| 4 | `$leaker` points at a suite that does not litter (`test_accelerators`) | **D2**, and **D1 SKIPS** with `the D2 positive control did not fire` |
| 5 | `N0`'s driver list names a file that is not there | **N0** |
| 6 | `clear_schematic()` removes the backup unconditionally (the pre-fix product) | **U1** and **U4** (`now: <absent>`), U3 stays green |
| 7 | `clear_schematic()` never removes the backup at all (the over-correction) | **U3** (`exists: 1`) |
| 8 | `load_schematic()` no longer clears backup ownership | **U4** only; U1 stays green |
| 9 | `write_backup()` skips untitled buffers again (the issue-0060 regression) | **U2** (`8 bytes`) and **D2**, and D1 skips |

**Sabotage 3 was green on the first attempt and that is a finding.** `S1` originally
looked for `suite_cwd_arm` anywhere in the file, and `full_audit.sh:76` carries a comment
that says *"see the suite_cwd_arm below"* — so deleting the actual call left the row
green. `S1` now scans **non-comment lines only**, and the comment explaining why is in
the suite. `S1`'s invocation clause had the same disease in the other direction: a bare
`$XSCHEM` match named `case "$XSCHEM" in`, `[ ! -x "$XSCHEM" ]`, `$(dirname "$XSCHEM")`
and two FATAL messages as unprotected launches; it now requires `"$XSCHEM"` followed by a
flag or by `"$@"`.

Sabotages 2 and 3 also show the division of labour: `S1` is textual and only sees that a
call is *present*; `D3` measures that it actually *ran*. Neither alone is enough.

---

## 6. What I did NOT fix, and why

1. **T1's own cwd (`tests/run_regression.tcl`).** T1 runs its `hcases` with cwd = `tests/`
   and still writes `tests/untitled~.sch` on a green run (issue 1480 §3). The fix is the
   same three lines as the other drivers — source `suite_cwd.sh`, arm once, `env
   "PWD=$_scwd"` on the four `exec` sites, disarm — but that file was being edited by item
   E's crew all round, and the brief said to touch only my own files. **Filed here, not
   fixed.** Note `tests/untitled~.sch` was already present when I started and its mtime is
   now `2026-09-20 21:42:19` because one of my bare sweep runs rewrote it; I left the file
   in place rather than deleting evidence issue 1480 cites.
2. **The bare `./src/xschem --script <t>.tcl`, which D9 keeps un-armed on purpose.**
   After the fix, **38 of 405** suites still OVERWRITE a pre-existing `untitled~.sch` in
   whatever directory you type it from. That write cannot be fixed: the buffer really is
   `<cwd>/untitled.sch` and backing it up is what issue 0060 requires. The destructive
   half that *was* fixable — deleting a file we never wrote — is fixed, in the product, so
   it holds for the bare command too. The armed spelling remains
   `tests/headless/run_suites.sh [--nogui] <t>`.
   **`scratch.tcl` is not a way round this**: only **27 of the 51** offenders source it
   (measured), so arming there would close half a class and create a second rule.
3. **Issue 1486's open item 2**, the project tier. Untouched on purpose — see the top.
4. **`test_ase_optier_0963`'s 120 s headless budget.** Not a defect of mine; recorded so
   the next person does not read a 120 s timeout as a regression. Alone with 400 s it is
   `ALL PASS (109 checks)` on both trees.

**Found outside the item — for the driver to file:**

5. **`test_no_untitled_litter` reports FAIL, not skip, when `DISPLAY` is unset.** Rows
   **N3** (`test_undo_selection`) and **N5** (`test_perform_action_align`) spawn their
   children with `--pipe -q --logdir` (no `--nogui`), which needs X; with no display the
   children print no banner and the rows fail with `left={} child said: ` — a *litter*
   row reporting red for want of a display. Measured on one binary and one tree:
   `RESULT: ALL PASS` with `DISPLAY` set, `RESULT: 2 FAILED` with `env -u DISPLAY`. Same
   family as item B / issue 1483. It is not a T1 case, so T1's ZERO is unaffected.
6. **`test_reopen_readonly` cannot run from any cwd but the repository root**, and it
   fails *silently*: `Tcl_AppInit() error … error copying "": no such file or directory,
   Line No: 20`, **exit 0, no RESULT line** — so a driver would score it `NORESULT`, not
   FAIL. It should resolve its fixtures from `[info script]` like its neighbours.
   This is the single measured reason the fix moves `$PWD` and not the cwd.
7. **The issue-0601 guard's blind spot** (§1): `set ::autosave_backup 0` never stopped
   `remove_backup()`, and `test_no_untitled_litter` structurally cannot see a *pre-existing*
   file being destroyed — all its rows ask "did the suite leave anything behind". The
   product fix closes the delete; the guardian's blind spot stands, and it is the reason
   the new suite seeds a canary instead of checking for leftovers.
8. **`full_audit.sh`'s tree arm reported `TREE: 0 appeared` on a run that put
   `untitled~.sch` in the repository root** (§3b). Known — issues 0353/0356, `.gitignore:75`
   — re-measured here.
9. **Issue 0609's "80 of 116 suites" is now 51 of 405** on this tree by the sharper
   question (does a pre-existing file survive), and **0 of 405** leave anything that is not
   an `untitled~.*`. Worth folding into 0609 when it is next touched.

---

## 7. Files changed

```
 src/actions.c                  | 17 ++++++--     clear_schematic: guard remove_backup
 src/save.c                     | 11 ++++++     write_backup/remove_backup/load_schematic
 src/xschem.h                   |  5 +++++     Xschem_ctx.backup_written
 tests/headless/full_audit.sh   | 32 ++++++---
 tests/headless/gated_xschem.sh | 20 ++++---
 tests/headless/run_suites.sh   | 27 +++++----
 6 files changed, 96 insertions(+), 16 deletions(-)
 tests/headless/suite_cwd.sh                    NEW  103 lines
 tests/headless/test_untitled_autosave_1486.tcl NEW  306 lines
```

Nothing else in the tree was touched. `.xschem/op_param_lists.conf` verified untouched
(top of this receipt). `~`, `~/.claude`, the dev display `:99` and `~/dev/xschem-op-wcard`
were never written.

## 8. Scratch

`/var/tmp/xsr_f/F/` — **peak 32 MB** (three 405-suite sweep trees, each keeping one
output file and one working directory per suite, plus the driver before/after runs).
Deleted by me at the end of the round; `/var/tmp/xsr_f` itself was left alone, since
other crews share that root.

---

# FIX ROUND (2026-09-20) — corrections to this receipt

Written by the fixer after the adversarial verify. Full detail and every measurement:
`doc/claude/stranger_reds_batch/receipts/F-verify.md`. **The sections above are left as
they were written**, because they are a dated record of what was believed; the corrections
are here.

## §2a is wrong where it says the B8 invariant is "STRENGTHENED"

It is not. **B8 has two directions** — "a leftover `~` on the next open unambiguously means
a crash" is broken by *deleting* a `~` we did not write **and** by *leaving* one we did —
and the boolean broke the second while this receipt claimed to strengthen the first.

**MEASURED on two builds of the same tree** (private directory, `$PWD` and cwd both in it,
`foo.sch` a copy of `xschem_library/examples/0_examples_top.sch`):

```
xschem load foo.sch ; xschem instance .../lab_pin.sym ... ; xschem load foo.sch ; xschem clear force
```

| build | `C after clear: foo~ exists=` |
|---|---|
| pre-1486 (the one-line revert of `actions.c:6573`) | **0** |
| this receipt's fix (the boolean) | **1** ← the regression |
| the fix round (the path) | **0** |

`load_schematic()` cleared `backup_written`, so any load between the write and the discard
made xschem forget its own `~`, and the next open offered deliberately discarded edits back
as crash recovery. The suite was `ALL PASS (10 checks)` throughout: `U3` has no load at
all, `U4` has no *intervening* load, and `U4` is what motivated the unconditional clear.

**`int backup_written` is replaced by `char backup_owned[PATH_MAX]`, the path written.**
`write_backup()` stores it, `remove_backup()` clears it only when it unlinks that same path,
`load_schematic()` does **not** clear it, `clear_schematic()` calls the new
`drop_owned_backup()` and `go_back()`'s "No" arm the new `remove_backup_if_owned()`. New
rows **U5**, **U6**, **U6b**; the suite is `ALL PASS (13 checks)`.

## §1 and §3b: "no suite leaves anything else" is too broad

The sweep put each suite in a private **working directory**, and `backup_file_name()` puts
the `~` beside the **cell**, not in `$PWD` — so the sweep was structurally blind to a whole
second class and the `$PWD` redirect cannot reach it.

* **§1** should read: 405 suites, 51 destroy a seeded `untitled~.sch`, and **no suite leaves
  any other file IN ITS WORKING DIRECTORY**. It is *not* true that "the untitled autosave is
  the whole of this class": **nine suites write a `cellName~.sch` into the checkout**
  whatever `$PWD` says (named in `tests/headless/suite_cwd.sh`'s header). Re-measured in the
  fix round: with `tests/from_user/before_10~.sch` moved out of the tree, the **armed**
  `run_suites.sh --nogui test_fluid_bodyshove_guards_0132` put it back byte-identical. It is
  **not a regression** — identical on the pre-fix binary — and it belongs to issues 0609/1480.
* **§3b** should read: the repo-root listing is byte-identical **for the five-suite list
  measured**, not in general.

## §7: "`~` … never written" is too strong

`~/.cache/openbox/openbox.log` has mtime **2026-09-20 21:53:39**, inside this round, and it
is not the dev display's openbox (that one started 14:37:48 and is still running) — a
privately started Xvfb+openbox inheriting the real HOME rewrites that log on every start,
as CLAUDE.md records. The sentence should read: **no file under `~` other than
`~/.cache/openbox/openbox.log`, which any openbox start rewrites.** `~/.claude`, the dev
display `:99` and `~/dev/xschem-op-wcard` are unaffected, and
`.xschem/op_param_lists.conf` is re-verified untouched (same mtime, size and md5).

## Harness corrections made in the fix round

* `full_audit.sh`'s gate-stop exit and `gated_xschem.sh`'s "binary not executable" FATAL sat
  between the arm and the disarm with no disarm. The second is **measured** leaving
  `tests/headless/.scratch/_suitecwd_<pid>/` in the checkout. Both now disarm, and **S1
  requires a disarm on every `exit` between the arm and the standalone disarm**. A
  `trap … EXIT` was considered and **refused on measurement**: one EXIT trap per shell, and
  `test_home.sh` (throwaway HOME) and `gui_gate.sh` already contend for it.
* `suite_cwd_disarm` now **names anything that is not an `untitled*`** before removing the
  tree (`SUITECWD: …`), because neither driver's leak detector can see inside the private
  `$PWD`. Today it finds nothing, which is the point of measuring it.
* `SUITE_CWD_ROOT` is script-local: an exported value used to hijack the arm **and** defeat
  the cleanup (measured).
* S1's guards: the disarm pattern takes `;` and `)` terminators, and the invocation test is
  now by **command position** rather than by "followed by a flag", so `"$XSCHEM" "$f"` and an
  unquoted `$XSCHEM` are caught (both return 0 under the old pattern — measured).
* `go_back()`'s "No" arm (§6's blind spot, one call site on) is now **measured**, not read:
  with the issue-0601 guard on, it DELETED a seeded foreign `descend_child~.sch`. Fixed;
  rows U6/U6b.

## Still for the driver

1. **Register the case** — the note at the top of this receipt stands, and `hcases` now has
   more entries than it did, so take the last one from the file rather than from the line
   number quoted there.
2. **File the nine-suite `cellName~` class** against 0609/1480.
3. **`test_load_window_routing`** reds 4 rows under `--nogui` and **TIMEOUTs after 200 s on
   the persistent dev display**. Proved pre-existing by rebuilding `src/actions.c`,
   `src/save.c` and `src/xschem.h` at HEAD: the same four rows, same messages. The timeout is
   the shape issue **1488** already describes for `test_wave_markers`.
