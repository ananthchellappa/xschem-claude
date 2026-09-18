# S2c-I: integrate and prove Item 2 (crew I)

**Status: DONE.** The three Item 2 halves (T, S, U) are integrated into one tree, the two
helpers now implement **one** contract (locked by a new cross-language section), and every
D11 shape was run with a seeded canary as the parent HOME.

Every documented shape left the canary **byte-identical**, left no process and no throwaway
behind, and matched the unfixed baseline case by case. There is one exception, and it is not
a HOME write: with the cwd **set to** the canary, `run_suites.sh` leaves an `untitled~.sch`
there. That is D12's cwd-writes class (details under shape 5).

Tags: **M** measured (ran it; output quoted), **R** read from source, **I** inferred.

## Deliverable and apply recipe

| file | md5 | what it is |
|---|---|---|
| `/var/tmp/xschem_fixes/s2c_I/final.patch` | `7f07f0e3130bb2ed6a1429e893e5ccd7` | The full integrated diff against `HEAD` (`bc61cd05`): 23 files, +4506/−97. It **includes** the two issue-stamp files as they are in the main tree now (md5 `ab4e64ba…` and `8069a362…`, unchanged at the end of this stage). |
| `/var/tmp/xschem_fixes/s2c_I/final_item2_only.patch` | `3e25e4b641d846bba3a1e4905bcf20f4` | The same patch minus those two files: 21 files. |

**Recipe for the main tree as it stands.** Its two issue-stamp files are already at the
patch's post-image. Measured read-only in `/home/analog/dev/xschem-claude` at the end of the
stage; all three commands exited 0.

```sh
P=/var/tmp/xschem_fixes/s2c_I/final.patch
# 1. prove the issue-stamp files already equal the patch's post-image (reverse applies)
git apply --check -R --include='tests/headless/issue_stamp.tcl' --include='tests/headless/test_issue_stamp.tcl' "$P"
# 2. check, then apply, everything else
git apply --check --exclude='tests/headless/issue_stamp.tcl' --exclude='tests/headless/test_issue_stamp.tcl' "$P"
git apply         --exclude='tests/headless/issue_stamp.tcl' --exclude='tests/headless/test_issue_stamp.tcl' "$P"
# (equivalently: git apply /var/tmp/xschem_fixes/s2c_I/final_item2_only.patch)
```

A plain `git apply --check "$P"` on the main tree **fails** on the two issue-stamp files.
That is expected: their hunks are already applied. The same recipe was also verified on a
main-shaped clone (`/var/tmp/xschem_fixes/s2ci/applytest`) (M).

## Integration (M unless tagged)

* **HEAD** is `bc61cd05`, not `4b9565ad`, as all three crews also found.
* **Clone.** `/var/tmp/xschem_fixes/s2c_I/tree` was made with `--no-hardlinks`, then:
  * the main tree's working diff of the two issue-stamp files was applied
    (`issue_stamp_main.diff`, md5 `7600660c…`);
  * `git apply --3way` was run for T, S and U in that order.

  **There were no conflicts.** The three patches touch disjoint files, and git's only note
  was "Falling back to direct application" for the new-file hunks.
* **Registration.** `headless/test_home_isolation_sh` sits in `hcases` right after
  `headless/test_home_isolation`. The lists now read tcases 3, hcases 72, dcases 11, plus
  xschemtest: **87 cases**. The measured trailer says `cases=87 blocks=86`.
* **Build.** `./configure && make -j12` gave rc 0 in both the integration tree and the
  proof trees.

### Is it ONE contract? What was checked, and the small defects fixed here

I read `t1_arm_home` (Tcl) and `test_home_arm` (shell) side by side.

**What already matched:**
* the regex `^xschem-test-home\.([0-9]+)\.[A-Za-z0-9]+$`;
* the `.owner` format (a bare pid on one line);
* the nesting test, with all three conditions;
* the liveness test via `/proc`;
* the `XSCHEM_TEST_REAL_HOME` refusals;
* the carry table and its variable names, including `XSCHEM_TEST_PRE_XDG_*_HOME`;
* the git `safe.directory` value (both resolve to the physical repo root, so de-dup works
  across languages);
* the banner text;
* the sweep's uid, age and liveness rules.

**Fixed here, each a small alignment (listed again in deviations):**

1. **`.keep`** (T's open problem). The shell now writes `.keep` under
   `XSCHEM_TEST_KEEP_HOME=1`, and its sweep skips entries that have one, as the Tcl sweep
   does. Before this, a home kept by Tcl was swept 300 s later by any shell arm.
2. **`XSCHEM_TEST_HOME=<the real HOME>`.** The shell now **refuses** it (rc 2) with a
   pointer to `=real`, as Tcl does. It used to treat it as `real`. T's row D3 already locked
   the Tcl refusal.
3. **`XSCHEM_TEST_KEEP_HOME` accepts exactly `1`** in Tcl too, as D5 spells it. It used to
   accept any Tcl true value.
4. **`XSCHEM_TEST_HOME=real` is matched exactly** in Tcl. It used to be `-nocase`, so
   `REAL` meant real in Tcl and was refused in the shell. Now both refuse `REAL`.
5. **The "is it a throwaway" test checks every path component in Tcl**, through the new
   `t1_home_has_throwaway`, used for `XSCHEM_TEST_REAL_HOME`, for HOME, and for a custom
   directory. It used to check only the last component, so a real or custom home **inside**
   a throwaway was accepted by Tcl and refused by the shell.
6. **An empty `XSCHEM_DEVDISPLAY_DIR`, `GUI_GATE_DIR` or `XAUTHORITY` counts as unset** in
   Tcl, as the shell's `${VAR:-}` reads it. It used to be kept empty.
7. **The Tcl sweep now stops a gate panel left inside a dead home**
   (`t1_home_kill_panel_in`). It uses the shell's identity rule: `widget.pid` or
   `widget.launching`, plus a cmdline naming both `gui_gate_widget` and that exact dir. A
   shared panel is never touched. Without this, a T1 that swept a dead shell run's home
   would orphan its panel.
8. **The sweep age boundary** is `<=` in Tcl, so an entry is swept only when it is older
   than 300 s, as in the shell. It was a 1-second disagreement.
9. **A TMPDIR inside the real home now draws the same `!! test home: note:` line in Tcl** as
   in the shell. Tcl used to say nothing. Neither side refuses; that remains the driver's
   call.
10. **U's "armed" regex** in `scratch.tcl` and `test_launch_context.tcl` is now the contract
    regex. It was `…\..+$`. `scratch.tcl`'s comment names the other two spellings.
11. **`test_scratch_home_note.tcl` now prints `OVERALL: ok` / `OVERALL: notok`**. T measured
    that without it the suite is a counted HARNESS FAIL once registered. It is **not**
    registered, because the task fixes T1 at 87.
12. **G1's allowlist entry for `test_gui_gate_batch.sh` is dropped.** It matched nothing
    after U's patch. The row's detail now says `allowlist entries matching nothing here:
    none`.

**Left different on purpose, documented in `test_home.sh`'s header and in section L's comment:**
* **The refusal exit code** is 3 in Tcl and 2 in the shell. `run_suites.sh` already means
  "Stop pressed" by exit 3 (R: its header), and CLAUDE.md gives T1's rc 2 a retired meaning.
  One code for both would collide with one of them.
* **The routine lines' stream** is stdout in Tcl, where a golden case's stderr becomes an
  exec error, and stderr in the shell, like the display arm's lines.
* **HOME unset.** Tcl takes the passwd home as the real one and arms. The shell refuses.
  Both are safe.
* **A nested run.** The shell prints its banner line again; Tcl says nothing.
* **Real mode.** The shell exports `XSCHEM_TEST_REAL_HOME`; Tcl does not. Each child still
  ends in real mode.

### Section L: the cross-language lock (26 new rows in `test_home_isolation.tcl`, 50 → 76 checks)

* **L1a–L1m, L1y.** The same environment is handed to both helpers, which must give the
  same verdict: refused, fresh, same (nested or real), or custom. There are 13 input shapes
  plus one for an empty harness path.
* **L1z.** The canary is untouched, and only the planted homes remain.
* **L2a–L2e.** A home armed by the shell is nested for a **Tcl child** (a). One armed by
  Tcl is nested for a **shell child** (c). A shell home is nested for a shell child (e),
  which is the shape of `owed.sh`'s drain calling a driver.
  * No crossing stacks a second `safe.directory` entry (b, d).
  * The tester's XDG original survives the crossing (b, d).
  * The nested run never deletes, and the owner deletes once, at its own exit.
* **L3a–L3d.** A home kept by Tcl survives the shell sweep (a), and a home kept by the shell
  survives the Tcl sweep (b). `KEEP=yes` means nothing in both (c). A dead, unkept home is
  swept by both (d), which is the non-vacuity half.
* **L4.** The throwaway regex is one string in all four places that spell it.
* **L5.** Both sweeps stop a panel left in a dead home and leave a shared one alive.

**Red first (M, `sab/sabL.py`).** Each sabotage was applied alone; the file was restored
and checked by md5.

| id | sabotage | red rows |
|---|---|---|
| SL1 | Tcl `real` back to `-nocase` | L1h |
| SL2 | shell treats `=<real HOME>` as real | L1i |
| SL3 | Tcl throwaway check on the last component only | L1f, L1k |
| SL4 | shell sweep ignores `.keep` | L3a |
| SL5 | shell never writes `.keep` | L3b |
| SL6 | Tcl KEEP accepts any true value | L3c |
| SL7 | Tcl sweep without the panel kill | L5 |
| SL8 | shell writes `.owner` as `owner=<pid>` | L2a, L2b |
| SL9 | Tcl regex lowercase-only | L4, and 46 other rows |
| SL10 | shell `safe.directory` value with a trailing `/` | L2d |
| SL11 | Tcl keeps an empty `GUI_GATE_DIR` | L1y |

* **SL8** is the sharpest: shell-over-shell (L2e) stays **green**, because the shell strips
  non-digits from `.owner`. Only the crossing row sees it.
* **SL10 reddens L2d only.** L2b cannot see it by construction, because a **nested** Tcl run
  returns before the carry step and never compares `safe.directory`. That is R, and the
  expectation was corrected to match.

**Both crews' own matrices were re-run on the integrated code, retargeted, with anchors
updated where my alignments moved a line:**
* **T's 41 sabotages:** 40 went RED as expected, and S31 (the intended no-red control) went
  green (`sab/T/run.log`).
* **S's 26 sabotages:** 26 of 26 went RED (`sab/S/run.log`).
  * S23 made the suite die with a Tcl error at line 344 after N1–N3 and N8 had already gone
    red. It is still red.
* Every touched file was restored, checked by md5 (M).

**Neighbour suites, integrated tree, headless, scratch HOME (M):**

| suite | result |
|---|---|
| `test_home_isolation` | ALL PASS (76) |
| `test_home_isolation_sh` | ALL PASS (53) |
| `test_scratch_home_note` | ALL PASS (20) |
| `test_regression_concurrency_1476` | ALL PASS (37) |
| `test_audit_classifier` | ALL PASS (75) |
| `test_suite_watchdog_1403` | ALL PASS (32) |

## The D11 proof

**Setup.**
* **Where the proofs ran.** Proof trees are `/var/tmp/xschem_fixes/s2ci/tree`, which is
  `bc61cd05` plus `final.patch` and byte-equal to the integration tree (`cmp`), and
  `/var/tmp/xschem_fixes/s2ci/base`, which is `bc61cd05` plus the issue-stamp diff only (the
  unfixed baseline). Both sit under a **lowercase** path; see deviations for why (D12).
* **The canary.** Each shape had its own freshly seeded D11 canary (T's `seed_canary.sh`):
  * a sentinel `.clipboard.sch`;
  * `simulations/clean.spice` and `short.spice`;
  * a 100-entry `geometry`;
  * `recent_files` and `ase_simulators`;
  * `.spiceinit`, `.ngspice_history` and `.gitconfig`.
* **Before and after each run:**
  * `find -printf '%P %y %s %T@ %m'` plus an md5 of every regular file;
  * S2a's `iwatch.py` over the whole canary for the duration;
  * a pid-level sampler (`tools/dsample.py`, 20 ms) recording each xschem `--script`
    process's DISPLAY and HOME.
* **Leftovers:**
  * any process whose environment names the canary or `/tmp/xschem-test-home.*`;
  * new `/tmp/xschem-test-home.*` entries.
* **Environment for every run:**
  * `DISPLAY` unset;
  * `DEVDISPLAY_NUM=189`, or 188 for the base, so nothing ever probed `:99`, not even
    read-only;
  * `XSCHEM_TEST_XVFB_BASE=180`;
  * an `xvfb-run` PATH shim (`-n 184`) that keeps `xvfb-run -a` in my range.
* **Wrapper:** `/var/tmp/xschem_fixes/s2ci/tools/run.sh`. Every run's artefacts are in
  `/var/tmp/xschem_fixes/s2ci/runs/<label>/`.

| shape | run | rc | canary (find / md5) | iwatch events | throwaway left / procs left | verdict |
|---|---|---|---|---|---|---|
| **1** T1 | `s1_tree` | 0 | **identical / identical** | **0** | 0 / 0 | `cases=87 blocks=86 counted_failures=8`, `home=throwaway`; 87 Start / 87 Finish |
| 1 base | `s1_base` | 0 | CHANGED | 2567 | 0 / **2 (persistent Xvfb :188 + openbox, F36)** | `cases=85 blocks=84 counted_failures=8` |
| **1 red first** | `s1_real` (`XSCHEM_TEST_HOME=real`) | 0 | **CHANGED** | 2521 | 0 / 0 | 87/86/8, `home=real` |
| **2** run_suites ×5 | `s2_tree` | 0 | **identical / identical** | **0** | 0 / 0 | 5/5 PASS |
| 2 base | `s2_base` | 0 | CHANGED | 741 | 0 / 0\* | 5/5 PASS |
| **2 red first** | `s2_real` | 0 | **CHANGED** | 568 | 0 / 0 | 5/5 PASS, `!! test home: REAL` printed |
| **3** full_audit | `s3_tree`, 799 s | 1 | **identical / identical** | **0** | 0 / 0 | `SUMMARY: 392 pass 11 fail 0 crash/timeout 2 skip (total 405)` |
| 3 base | `s3_base`, 762 s | 1 | CHANGED | 5539 | 0 / 0\* | `SUMMARY: 389 pass 11 fail 0 crash/timeout 2 skip (total 402)` |
| **4** `tclsh netlisting.tcl` | `s4_tree` | 0 | **identical / identical** | **0** | 0 / 0 | 728 jobs, `No gold folder` |
| 4 base | `s4_base` | 0 | identical | 0 | 0 / 0 | (no red-first available; see below) |
| **5a** cwd=canary, `tclsh <abs>/tests/netlisting.tcl` | `s5a` | 1 | identical | 0 | 0 / 0 | refuses to run (see below) |
| **5b** cwd=canary, `tclsh <abs>/tests/run_regression.tcl` | `s5b` | 1 | identical | 0 | 0 / 0 | refuses to run |
| **5c** cwd=canary, `<abs>/run_suites.sh` ×5 | `s5c` | 0 | contents identical; **+ `untitled~.sch` in the root** | 18 (all `untitled~.sch`) | 0 / 0 | 5/5 PASS |
| **6** attach | `s6_attach` | 0 | **identical / identical, state dir included** | **0** | 0 / 0 | 87/86/8, `display arm: attached to the dev display` |

\* Each baseline's `procs left` column, measured at its end, listed the **concurrent** tree
run's live processes (s1_tree's netlisting case, and the tree audit's arm). They are not
leftovers. After every run had finished, the global check found **no** process carrying a
canary or a throwaway HOME, **no** `/tmp/xschem-test-home.*` and **no** `/tmp/.X1*-lock`
(M). Only `:99` (1209045/1209133) remains, and it was never touched.

**What each red-first run did to its canary (M, from `find.diff`):**
* **s2_real:** the clipboard went 98 B → 107 B (it now holds `clean.sch`'s netlist header),
  `geometry` went 4664 → 5087, `clean.spice` and `short.spice` went 30 → 146, and
  `.cache/openbox/` was created.
* **s1_real:** the clipboard went → 220, `geometry` → 4672, `clean.spice` and `short.spice`
  → 146, and `.xschem/op_annot/` was created. It created **no** `.cache/openbox` and no
  `.claude`: the Tcl private arm's WM runs under the run's own directory in every mode
  (T's H4).
* **The baselines** did the same, plus `.claude/xschem_dev_display/*`, which is the
  persistent `:188` left running. I stopped it with `devdisplay.sh stop` against the
  **base canary's** state dir.

### Per-case attribution (M, `tools/percase.py`; pid-normalised counted lines)

* **T1.** `s1_tree` against `s1_base`: **every shared case is identical.** Only the four
  F14 segfault suites count, 2 lines each:
  * `test_op_annot`
  * `test_ase_optier_0963`
  * `test_unused_attr_0970`
  * `test_auto_specialize_1201`

  Each counts `FATAL: signal 11` plus the HARNESS line. The two new suites are at **0**
  (`test_home_isolation` ALL PASS 76, `test_home_isolation_sh` ALL PASS 53). All 11
  `.disp.log` blocks are at `Total num fail: 0`. `s6_attach` and `s1_real` are identical to
  `s1_tree` per case.

  **In this lowercase path there is no D12 uppercase red.** The ASE suites are green in
  both trees.
* **full_audit.** All **402** shared cases have **identical verdicts**, tree against base.
  The tree's three extra suites PASS: `test_home_isolation`, `test_home_isolation_sh` and
  `test_scratch_home_note`. `test_launch_context`, which carries U's alignment, PASSes. The
  shared non-passes are pre-existing and the same on both sides:
  * `test_altf5_ciw`
  * `test_ase_dialogs`
  * `test_cadence_drag`
  * `test_cosim_golden_e2e`
  * `test_lib_manager_gui`
  * `test_lib_sweep`
  * `test_results_dialog`
  * `test_rotate_stretch_short_0104`
  * `test_selflog_output`
  * `test_wave_sigbrowser_0312`
  * `test_wave_sigbrowser_keys` (all FAIL)
  * `test_expose_repaint` and `test_window_report` (SKIP)
* **Peak throwaway during the tree audit:** **68 KB**, never more than **1** throwaway at a
  time, over 164 `du` samples taken 5 s apart (`runs/du3_tree.txt`).

### Shape 1 and 6: which display the 11 display cases ran on (M)

* **Shape 1.** The run said `display arm: PRIVATE Xvfb :100 for this run only (pid 531051,
  wm openbox)`. The sampler saw 10 of the 11 dcases' xschem with `DISPLAY=:100`.
  `test_annot_blank_cause_0909` finished between two 0.3 s samples of that first sampler;
  its `.disp.log` reads ALL PASS (27). The sampler was then rewritten to 20 ms, pid-level.
  The private Xvfb was gone after the run.
* **Shape 6.** The seeded state dir `c6_attach/.claude/xschem_dev_display` named **my
  fixture** `Xvfb :187 -audit 4` plus openbox. I started them by hand, with HOME a scratch
  directory, and never through `devdisplay.sh`.
  * The run said `display arm: attached to the dev display (state dir …/c6_attach/.claude/xschem_dev_display)`.
  * **For each of the 11 dcases**, the sampler recorded the xschem pid with `DISPLAY=:187`,
    and **that pid appears in the fixture server's own audit log** (`client … connected
    from local host ( … pid=<it> )`, 2 connections each).
  * The only other displays seen were `:100` and `:150`. They belong to `st1.tcl`, the
    stand-in case of T's H rows inside `test_home_isolation`, which are built-in fixtures.
  * The canary snapshot, **including the state dir**, was byte-identical, with 0 events. The
    fixture was stopped afterwards.

### Shape 4: no red first is available for `tclsh netlisting.tcl` (M)

With a built `src/xschem`, the **base**'s `tclsh netlisting.tcl` did not touch its canary
either (0 events). F10's damage needs **no** built binary and an **installed** xschem on
PATH. This box has none (`/usr/local/bin` is empty), so the harness can only resolve the
in-tree binary. Shape 4's pass is therefore "armed, and wrote nothing":
* the banner `test home: throwaway /tmp/xschem-test-home.227850.odZFsb …` printed;
* no throwaway was left.

### Shape 5: cwd = the canary (M)

* **5a/5b.** `tclsh <abs>/tests/netlisting.tcl` and `tclsh <abs>/tests/run_regression.tcl`
  both die at once with `couldn't read file "test_utility.tcl"`. They source it by a
  relative path, lines 23 and 419. They exit 1 and write nothing. This is pre-existing and
  unchanged by Item 2: only the documented `cd tests && …` form runs.
* **5c.** `run_suites.sh` by absolute path runs all five suites (PASS) under a throwaway,
  and the canary's **own files are byte-identical**. The canary **root gains
  `untitled~.sch`** (CREATE plus 9 MODIFY and 8 CLOSE_WRITE, left behind).
  * **Attribution:** I ran each suite alone from an empty scratch cwd. Only
    **`test_signal_short_nohier_0230`** leaves it.
  * This is D12's "suites write into the cwd" class (S measured the same), not a HOME
    write. It fails the literal pass condition for shape 5 and is listed as an open problem.

## Deviations

See the structured output for the full list. In short:
* HEAD was `bc61cd05`.
* The proof ran in a lowercase sibling.
* 12 integration alignments (above).
* The measurement knobs.
* One launch was botched and redone: base T1 was started with a relative HOME (my
  wrapper's bug). I killed it within about 6 minutes, removed the debris it made inside
  the **base** checkout (`base/tests/canaries/`), and re-ran with absolute paths. The real
  home was checked right after: unchanged.

## Real home (M)

* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the start
  (03:47), mid-stage and at the end.
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate -newer
  <marker 03:47:03>` printed **nothing** mid-stage and at the end. `~/.cache/openbox` printed
  nothing either.
* **No interactive session:** the newest `/tmp/Xschem.log*` is `.4`, from 09-17 23:35.
* **Every run** used a canary or scratch HOME under `/var/tmp/xschem_fixes/s2c_I` or `s2ci`,
  with `DISPLAY` unset.
* **Displays:**
  * My fixtures: `:186` (a 1 s audit-format probe), `:187` (attach) and `:188` (the base T1's
    own auto-start, stopped).
  * Driver arms: `:184`/`:185` (`xvfb-run` via the shim) and `:100` (T1's private arm,
    D8's hard-coded range).
  * Suites' built-in fixtures: `:150`, `:180`+.
* **`:99` and its orphans** were never started, stopped, viewed or probed.
* **Emergency-save dirs:** **16** new `/tmp/xschem_emergencysave_*` appeared, exactly 4
  per T1 run × 4 T1 runs, at 04:10–04:12, 04:25–04:27, 04:48–04:50 and 04:54–04:56. These
  match my runs' F14 segfaults (I), but I left them, as the rule requires.
* **Main tree:** only read, plus `git apply --check` (read-only). No commit, stash, reset or
  checkout. Its `git status` is unchanged (10 lines).
* **Not touched:** `~/dev/xschem-op-wcard`.
* **Scratch for the driver to delete:**
  * `/var/tmp/xschem_fixes/s2c_I` (418 MB: the integration tree, patches, `sab/`, logs);
  * `/var/tmp/xschem_fixes/s2ci` (1.4 GB: the tree, base and applytest clones, canaries,
    runs, tools).
