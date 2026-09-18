# S2c-S: the shell side of Item 2 (a throwaway HOME for run_suites / full_audit / gated_xschem)

Crew receipt, 2026-09-18. Work clone: `/var/tmp/xschem_fixes/s2c_S/tree`. Baseline clone:
`/var/tmp/xschem_fixes/s2c_S/base`, same shape without the S2c change. Nothing was committed,
and the main tree was only read and cloned.

**Starting point.** The task said HEAD was `4b9565ad`. It had moved to `bc61cd05`, the commit
that adds D4-D12, so S1's patch no longer applied as a whole: its DECISIONS.md hunk is
already committed. I applied only S1's two `tests/` files, with
`git apply --include='tests/*' s1_working.patch`.

## Deliverable

* The patch is `/var/tmp/xschem_fixes/s2c_S/final.patch`, md5
  `9c2c4b08a9bac058738f9ea45a2aeb33`: 7 files, +1243/-5.
* MEASURED: it applies cleanly to a bare `bc61cd05` checkout (`applytest/`,
  `git apply --check`, then `bash -n` on every `.sh` file). The two new files come out
  byte-identical to the tested tree.
* The new suite is **not registered** in `run_regression.tcl`. That is left to the
  integration crew.

| file | change |
|---|---|
| `tests/headless/test_home.sh` (new) | The helper. Contains `test_home_arm`, `test_home_handoff`, the owner's EXIT trap, the sweep and the carry. It is sourced, not executed (mode 644). |
| `run_suites.sh` | Adds `. "$HERE/test_home.sh"` and `test_home_arm \|\| exit $?` before `. xvfb_arm.sh`. Adds a note to the header. The `--help` line range moves from 2,36 to 2,42 because the header grew. `--help` arms nothing. |
| `full_audit.sh` | The same two lines, inside the existing `AUDIT_LIB_ONLY != 1` guard, so library mode arms nothing. |
| `gated_xschem.sh` | The same two lines, before `. xvfb_arm.sh`. |
| `xvfb_arm.sh` | Calls `test_home_handoff` on the line directly before `exec xvfb-run`. `_xvfb_wm_launch` exports `XSCHEM_XVFB_WM_PID`. The dev-display state read now falls back through `XSCHEM_TEST_REAL_HOME`. |
| `gui_gate.sh` | Adds `_gate_panel_env`: a **shared** panel is launched with `env HOME=$XSCHEM_TEST_REAL_HOME` plus the original XDG_* values, while a panel whose gate dir is under this run's HOME keeps the run's environment. The dev-display read falls back through `XSCHEM_TEST_REAL_HOME`. The `GATE_DIR` default deliberately does **not** fall back that way; a comment explains why. |
| `tests/headless/test_home_isolation_sh.tcl` (new) | A 53-row suite, about 17 s. Run it as `./src/xschem --nogui --pipe -q --nolog --script`. |

## D4-D7 as implemented (READ; each item is exercised by the rows named)

**D4: arm first.** All three drivers arm before sourcing `xvfb_arm.sh` (row W1 checks the line
order in each driver). HOME is switched for the whole driver process. openbox on the private
display arm and the xvfb-run re-exec both inherit the throwaway (X1-X4).

**D5: create, own, delete.**

* **Creation.**
  * The throwaway is created with `mktemp -d "${TMPDIR:-/tmp}/xschem-test-home.<pid>.XXXXXX"`.
  * The run is refused if mktemp fails (R3). It is also refused if the result equals HOME or
    the real HOME, or is an ancestor of either. R6 tests that refusal with a fake `mktemp`,
    because a real one cannot produce such a path.
  * `.owner` holds one line, the owner pid. `.xschem` is created with mode 700 (F3, F4).
* **Nested.** A run counts as nested only when all three conditions hold:
  * HOME is an existing directory named `xschem-test-home.<pid>.*`;
  * its `.owner` names a live pid;
  * `XSCHEM_TEST_REAL_HOME` is set.

  A nested run reuses HOME and never creates or deletes (N1-N3). A throwaway whose owner is
  dead is not nested (N6).
* **`XSCHEM_TEST_REAL_HOME`** is validated whenever it is set: it must be absolute, an
  existing directory, and contain no throwaway component. Otherwise the run is refused
  (R1: `1`, relative, missing, a throwaway, empty).
* **Only the owner deletes.** The delete happens in the EXIT trap, and only when all of these
  hold:
  * `$BASHPID` equals the recorded owner. It is `$BASHPID` and not `$$`, because a subshell
    shares `$$`.
  * `.owner` still names that pid at delete time (F9).
  * The path passes the re-check: its parent is physically the temp root, the name matches,
    same uid, not a symlink, and it is neither the real home nor an ancestor of it.
* **Handoff across the xvfb-run re-exec.**
  * `xvfb_arm` calls `test_home_handoff` directly before its exec. That exports
    `XSCHEM_TEST_HOME_HANDOFF=$BASHPID`, and only if this process owns a throwaway.
  * The re-exec'd driver takes ownership only if all of these hold: that pid is its parent or
    grandparent, the pid equals `.owner`, and HOME sits physically under `${TMPDIR:-/tmp}`.
    It then rewrites `.owner` (write to a temp file, then mv).
  * The variable is unset on every path, whether or not ownership is taken (X1, X2, N2b, N8,
    N10).
* **`XSCHEM_TEST_KEEP_HOME=1`** keeps the throwaway and prints its path (X5).
* **Sweep on a fresh arm** (G1-G7). It deletes `xschem-test-home.*` entries that meet all of
  these: same uid, a real directory and not a symlink, `.owner` pid dead (the pid in the name
  if `.owner` is missing), and directory mtime more than 300 s old. A live `Xvfb` named in
  `.xvfb.pid` is killed first. Nothing is swept when /proc is absent.

**D6: opt-out and banner.**

* `XSCHEM_TEST_HOME=real` leaves HOME alone and prints a loud `!! test home: REAL ...` banner
  on **every** run, including nested ones (O1, O2).
* `XSCHEM_TEST_HOME=<abs dir>` uses that directory as HOME and never deletes it (O3, O4). A
  relative or missing directory is refused (R5).
* The armed line is exactly
  `test home: throwaway <TH> (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)`
  (F2). It goes to stderr, as the drivers' display-arm lines already do.

**D7: carry.**

* Always carried: `XSCHEM_TEST_REAL_HOME` and `XSCHEM_DEVDISPLAY_DIR`.
* `GUI_GATE_DIR` is carried only if `$REAL/.claude/gui_test_gate` exists (F7, F8, K1-K3).
* `XAUTHORITY` is carried only if `$REAL/.Xauthority` exists.
* `XDG_{CACHE,CONFIG,DATA,STATE}_HOME` are repointed into the throwaway only if already set;
  unset ones stay unset (F7, F8).
* git `safe.directory` is passed as command-scope config (F6, F10).
* **The gate panel.** A shared panel gets the pre-switch environment (K4). A panel whose gate
  dir is inside the throwaway is killed by the owner before the delete (K2).
* **openbox** on the private arm runs under the throwaway. The owner kills it before the
  delete, but only if it is the owner's direct child with the right argv[0] (X4, X5).

**Bug found during the work.** At first, `$BASHPID` was read inside the `$(mktemp ...)`
command substitution. That names the subshell, so the directory's name disagreed with
`.owner` (MEASURED: `xschem-test-home.2633148.*` with `.owner` 2633144). The pid is now
captured before the substitution, and row F3 pins it.

## Red first: 26 sabotages, each one reddened its target rows (MEASURED)

Harness: `/var/tmp/xschem_fixes/s2c_S/sabotage.py`. It applies one edit to the tree, runs the
suite, restores the file and records the red rows. Outputs are in `sab/S*.out`. The clean
suite before and after the sweep: `RESULT: ALL PASS (53 checks)`.

| id | sabotage | red rows |
|---|---|---|
| S01 | run_suites.sh does not arm | W1, E1 |
| S02 | no handoff before `exec xvfb-run` | W2, X1, X3, X5 (+E1: the home that leaked stays in TMPDIR) |
| S03 | handoff exported at arm time | N1, N2, N2b, N3. N2b was vacuous in the first sweep and was rewritten to read the owner's own environment; re-run red. |
| S04 | no parent/grandparent check | N8 |
| S05 | nested without the liveness check | N6 |
| S06 | nested without requiring `XSCHEM_TEST_REAL_HOME` | N7 |
| S07 | `XSCHEM_TEST_REAL_HOME` not validated | R1 |
| S08 | mktemp failure returns 0 | R3 |
| S09 / S10 / S11 | sweep ignores liveness / age / `.xvfb.pid` | G3 / G2 (+G7, N6) / G5 |
| S12 | `GUI_GATE_DIR` carried unconditionally | F7, K1, K2, K3, K4 |
| S13 | private panel not killed | K2 |
| S14 | shared panel without the pre-switch env | K4 |
| S15 / S16 | WM not killed / WM pid not exported | X5 / X4, X5, Z1 (a fake WM leaked; it self-exited) |
| S17 | no `.xschem` | F4 |
| S18 | no opt-out banner | O2 |
| S19 | no `.owner` re-check at delete | F9 |
| S20 | unset XDG_* get set | F7, F8. The first attempt removed two lines and crashed the helper under `set -u`, so it went red for the wrong reason. It was replaced by a precise sabotage and re-run. |
| S21 | EXIT trap clobbers the status | F1, X3 |
| S22 | no refusal when the throwaway equals or is an ancestor of the real home | R6 |
| S23 | the nested branch installs the owner's trap | N1, N2, N3, N8 |
| S24 | custom mode deletes its dir | O4 |
| S25 | safe.directory stacked by a nested arm | F10 |
| S26 | handoff without the check that HOME is under the temp root | N10 |

## Canary proof, with the parent HOME seeded per D11 and DISPLAY unset (MEASURED)

**What the canary held.** `.xschem/` with a sentinel `.clipboard.sch`, `simulations/clean.spice`
and `short.spice`, a 100-entry `geometry`, `recent_files` and `ase_simulators`, plus
`.spiceinit`, `.ngspice_history` and `.gitconfig`.

**How it was checked.** `snap.sh` records `find -printf '%p %y %s %T@ %m'` plus an md5 of every
file, before and after. S2a's `iwatch.py` records transient writes. The events column below
excludes iwatch's own READY and STOPPED lines.

**Display numbers.** A PATH shim, `shim/xvfb-run`, runs `/usr/bin/xvfb-run -n <base> "$@"`.
This keeps `xvfb-run -a` inside my assigned 160-169 range. Everything else about the default
arm is real, including the re-exec and the handoff.

**Suites.** The five clipboard and netlist writers named in the task: test_crossview_paste,
test_signal_short_nohier_0230, test_no_untitled_litter, test_schpins_stale_lab_0185 and
test_paste_modify_flag_0244.

| run | canary | writes under it | leftover in TMPDIR | verdicts |
|---|---|---|---|---|
| **base** headless (`--nogui`, `AUDIT_DISPLAY=none`) | **CHANGED**: clipboard 86 B to 220 B; clean.spice and short.spice 28 B to 148 B | 114 | 0 | 4 PASS; no_untitled_litter FAIL (2 FAILED) |
| tree headless | byte-identical | 0 | 0 | the same |
| tree headless, `XSCHEM_TEST_HOME=real` (red first) | **CHANGED**: clipboard, clean.spice, short.spice | 113 | 0 | the same, and the banner printed |
| **base** default arm (private Xvfb and openbox) | **CHANGED**: new `.cache/openbox/{openbox.log,sessions}` (F36), clipboard, `geometry` (F7), clean.spice, short.spice | 307 | 0 | 4 PASS; 0244 TIMEOUT |
| tree default arm, final code, solo | byte-identical | 0 | 0 | 4 PASS; 0244 TIMEOUT (**identical to base**) |
| **base** `gated_xschem.sh --script test_crossview_paste.tcl` | **CHANGED**: new `.cache/openbox/*`, clipboard, geometry | 59 | 0 | OVERALL ok |
| tree `gated_xschem.sh`, the same command, final code | byte-identical | 0 | 0 | OVERALL ok |
| **base** `full_audit.sh` | **CHANGED**: new `.cache/openbox`, clipboard, geometry, new `op_annot/`, simulations | 5538 | 1\* | 382 pass, 17 fail, 1 crash, 2 skip (402) |
| tree `full_audit.sh`, default arm, 849 s | **byte-identical** | **0** | 1\* | 383 pass, 17 fail, 1 crash, 2 skip (403) |

\* The one leftover in TMPDIR is an empty `xschem_test_scratch/` directory, made by
`test_library_git*.tcl`. It is not HOME-related and appears in both clones.

**full_audit, read case by case.** The tree and the base audit ran concurrently, each with
its own canary and display. All 402 cases they share got **identical verdicts**. The only
difference is the new `test_home_isolation_sh`, which PASSed inside the audit.

The shared non-passes are:

* **FAIL:** test_altf5_ciw, test_ase_campaign_1462, test_ase_campaign_gui_1464,
  test_ase_converge_1459, test_ase_dialogs, test_ase_optier_0963, test_ase_sp_1452,
  test_ase_variant_1470, test_cadence_drag, test_cosim_golden_e2e, test_lib_manager_gui,
  test_lib_sweep, test_results_dialog, test_rotate_stretch_short_0104, test_selflog_output,
  test_wave_sigbrowser_0312, test_wave_sigbrowser_keys.
* **CRASH:** test_op_dump_altshow.
* **SKIP:** test_expose_repaint, test_window_report.

INFERRED: the ASE reds are the uppercase-letter-in-the-checkout-path trap recorded in D12,
since both clones sit under `s2c_S`.

**Throwaway size during the tree audit.** Peak 116 KB, never more than one throwaway at a time
(169 `du` samples, 5 s apart; a transient shorter than 5 s could be missed).

The audit's `TREE: 2 appeared 2 vanished` lines are my own `git add -N` of the two new files,
done during the run.

**Cross-talk caught and attributed.** Three measurements run concurrently **in the same
tree** turned `test_no_untitled_litter` red. Z1 saw an `untitled~.sch` "before" and none
"after", left by a concurrent `test_signal_short_nohier_0230`. Solo, it PASSes, the same as
base.

**cwd = the canary home** (D11 shape 5, using run_suites.sh). The canary contents stayed
identical, but its root mtime moved. iwatch names the cause: `test_signal_short_nohier_0230`
creates `untitled~.sch` **in the cwd**, and it survives until `test_paste_modify_flag_0244`
deletes it. This is D12's cwd-writes class. Unlike `full_audit.sh`, `run_suites.sh` does not
pin its cwd to the repo. Recorded, not fixed.

## Other suites that use the changed files: green and identical in both clones (MEASURED)

Each ran with its own scratch HOME and TMPDIR and DISPLAY unset. The results were the same in
the tree and in base:

* `test_audit_classifier`: ALL PASS (75 checks).
* `test_suite_watchdog_1403`: ALL PASS (32 checks).
* `test_owed.sh`: ALL PASS (365 checks, 1 skipped).
* `test_gui_gate_revive.sh`: `fails=0`. I ran a temporary copy with its stub
  `DISPLAY=:99` rewritten to the unserved `:169`, so nothing I launched named :99. The copy
  was deleted afterwards.
* `test_gui_gate_batch.sh`: `fails=0`. It took `:160`.

**Not run: `test_devdisplay.sh`.** It starts Xvfb on 85-96, outside my assigned range. READ:
my changes do not reach its rows. It sets `XSCHEM_DEVDISPLAY_DIR`, so the new fallback never
applies, and its `--arm` path never defines `test_home_handoff`.

**Under T1.** READ: every T1 case that mentions these files does so only in comments. T1
therefore reaches this patch only through the new suite, once the integration crew registers
it. I ran the suite as T1 will run it: nested in a live throwaway, with
`XSCHEM_TEST_REAL_HOME` set, `T1_LOG_TAG` set and `DISPLAY` inherited from a fixture Xvfb of
mine. MEASURED: `ALL PASS (53 checks)`; the outer throwaway was left alone and the simulated
real home stayed empty.

## Deviations (additions to D4-D7; no name in the contract was renamed)

1. **New internal names:**
   * `XSCHEM_TEST_PRE_XDG_{CACHE,CONFIG,DATA,STATE}_HOME` carry the pre-switch XDG values
     from `test_home.sh` to `gui_gate.sh`'s shared-panel launch.
   * `XSCHEM_XVFB_WM_PID` names openbox to its owner.

   D7 requires both behaviours but names no variable for either.
2. **git `safe.directory` is appended at `GIT_CONFIG_COUNT` and de-duplicated.** It is not
   skipped when `GIT_CONFIG_COUNT` is already set. This follows the Tcl crew's `t1_arm_home`,
   so both languages behave the same, and it keeps a tester's own command-scope config
   (F10). D7's "only if not already set" is read as "only if our entry is not already
   there".
3. **XDG values are repointed whenever set, including when set to empty,** as `t1_arm_home`
   does.
4. **A fresh arm refuses when HOME is itself a throwaway with no live owner and no
   `XSCHEM_TEST_REAL_HOME`** (N7). D5 says "anything short of all three is a fresh arm", but
   such an arm would have to export a throwaway as the real home, which D5's own validation
   then refuses in every child. `t1_arm_home` refuses the same case.
5. **Handoff:** besides parent/grandparent and `.owner`, I also require that HOME sits
   physically under `${TMPDIR:-/tmp}` (N10). Without it, the owner's "under the temp root"
   re-check was computed from HOME itself and could never fail.
6. **Custom-home edge cases:**
   * `XSCHEM_TEST_HOME=<dir>` that resolves to the real home is treated as `real`, with the
     banner.
   * A custom dir that names a throwaway is refused.
   * The custom line uses `t1_arm_home`'s wording:
     `test home: custom <dir> (never deleted; your HOME is untouched)`.
7. **The sweep also kills a private gate panel inside a dead throwaway.** It identifies the
   panel by a cmdline naming that exact gate dir. This extends D5's `.xvfb.pid` rule.
8. **A TMPDIR inside the real home produces a warning, not a refusal.** D5 refuses only
   "equal to or an ancestor of". The critic wanted "outside it"; DECISIONS wins, and this is
   left to the driver (open problem 2).
9. **Measurement method.** All default-arm measurements used a PATH shim for `xvfb-run`
   (`-n 160/163/166`) to stay inside my display range. The committed suite writes the same
   shim into its own scratch, with base `XSCHEM_TEST_XVFB_BASE`, default 160.

## Open problems

1. **The Tcl side keeps the pre-switch XDG values only in the Tcl array `t1_home(pre)`, which
   is not exported.** A shell driver nested under T1 therefore cannot launch a shared panel
   with T1's original XDG values. No such nesting exists today. Suggestion for integration:
   `t1_arm_home` exports the same `XSCHEM_TEST_PRE_XDG_*_HOME`. The banners also differ in
   stream: stdout on the Tcl side, stderr on the shell side.
2. **TMPDIR inside the real home** (deviation 8) needs a decision by the driver.
3. **The POSIX standalone `test_*.sh` suites re-exec through `xvfb_arm.sh --arm`** and are
   not armed by `test_home.sh`. D4 covers only the three drivers. Run bare, they still use
   the caller's HOME, although several set their own.
4. **`run_suites.sh` does not pin its cwd.** Measured above: `untitled~.sch` lands in
   whatever directory it is launched from (D12).
5. **Pre-existing and not caused by this change**, measured the same in both clones:
   * `test_gui_gate_revive.sh:503` (`sleep 300 & PENDW=$!`) leaks a `sleep 300`. I killed
     both instances.
   * `test_paste_modify_flag_0244` TIMEOUTs on the GUI arm.
   * `test_no_untitled_litter` FAILs headless (2 FAILED) but PASSes on the GUI arm.
   * The 20 shared full_audit non-passes listed above.
6. **Unattributable emergency-save dirs.** 44 `/tmp/xschem_emergencysave_*` directories
   appeared during this stage while the T crew's T1 runs were live. They cannot be
   attributed by name, so none was deleted.
7. **A loop of `gated_xschem.sh` calls now gets a fresh throwaway on every call.** No state
   persists between calls. This is intended per D4, but it is a behaviour change for anyone
   using it as a long-lived xschem.

## Real home

* Checked before, during and after, most recently at the end:
  `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0**.
* `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate -newer <start marker>`
  printed **nothing**. `~/.cache/openbox` had nothing newer either.
* The only newer entries at the home root were `~/.claude.json` and the root directory's
  own mtime (02:35:34). Those are Claude Code's own rewrite, the noise the critic recorded.
* The newest `/tmp/Xschem.log*` is `.4`, from 23:35 the previous day.

## Processes and displays

* All my fixtures used displays 160-168.
* **At the end:** no process with HOME under `s2c_S`, and no `/tmp/.X16*-lock`.
* **Left alone:**
  * The `/tmp/xschem-test-home.3506884.*` and `/tmp/xschem-test-home.3515464.*` directories,
    and Xvfb `:100`. All three belong to the T crew's live `tclsh run_regression.tcl`
    (`s2c_T`).
  * `:99` and its orphans.
* **Never touched:** `devdisplay.sh`, the real state and gate dirs, and `xschem-op-wcard`.

**My scratch, left for the driver to delete:** `/var/tmp/xschem_fixes/s2c_S`. It holds the
tree, base and applytest clones, `meas/`, `sab/`, `nb/`, and the scripts `measure.sh`,
`snap.sh`, `seed.sh`, `sabotage.py`, `neighbours.sh`, `leftovers.sh` and `dusample.sh`.
