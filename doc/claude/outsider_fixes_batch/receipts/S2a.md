# S2a: HOME map, redirect study, critic (workflow wf_704cbd18-d5d)

Verbatim crew outputs. The driver's design built from these is DECISIONS.md D4-D12. **Where DECISIONS and this file disagree, DECISIONS wins.**

# 1. Map

## map.recommended_design

Switch HOME for the whole driver process, near the top, through one helper per language. Carry a short, explicit list of harness paths computed from the real home before the switch.

WHERE
- Tcl: a proc t1_arm_home in tests/test_utility.tcl. run_regression.tcl already sources that file, and test_regression_concurrency_1476 already copies it into its staging dir (`foreach f {test_utility.tcl banner_rule.tcl cleanup_debug_file.awk}`). A new file would break those staged copies. run_regression.tcl calls it before the first exec, next to `set ::env(T1_LOG_TAG) [pid]`.
- Shell: tests/headless/test_home.sh, sourced by run_suites.sh, full_audit.sh and gated_xschem.sh BEFORE `. xvfb_arm.sh; xvfb_arm`. That way openbox on the private xvfb-run path, and the xvfb-run re-exec, both inherit the throwaway.
- Why process-wide and not a per-exec `env HOME=` prefix: it covers future exec sites and openbox. A per-exec prefix is one more thing every new call site must remember, which is the 1397 trap in another form.

STEPS
1. Nested or re-exec run: if XSCHEM_TEST_REAL_HOME is already set, reuse it. Do not create and do not clean. This covers the xvfb-run re-exec, 1476's copies of the driver, and owed.sh drain calling run_suites.sh.
2. Opt-out (D2). XSCHEM_TEST_HOME=real leaves HOME alone and prints a loud banner on every run. XSCHEM_TEST_HOME=<dir> uses that dir as HOME and never deletes it, for reproducing against a copy of a user config.
3. Carry, each only if it is not already set:
   - export XSCHEM_TEST_REAL_HOME=$HOME
   - XSCHEM_DEVDISPLAY_DIR=$REAL/.claude/xschem_dev_display (T1 display arm, xvfb_arm attach, gui_gate, spawn_reaper)
   - GUI_GATE_DIR=$REAL/.claude/gui_test_gate (one shared panel on explicit AUDIT_DISPLAY arms)
   - XAUTHORITY=$REAL/.Xauthority, only if that file exists
4. Create the throwaway with `mktemp -d ${TMPDIR:-/tmp}/xschem-test-home.<pid>.XXXXXX`. It must be outside the real HOME (or the canary proof fails) and outside the repo (or full_audit's tree delta and .gitignore get involved). The measured contents stay well under 1 MB, so the tmpfs is fine.
5. `mkdir -m 700 $TH/.xschem`. This is F25's cure: measured 11/320 failures down to 0/320.
6. Export HOME=$TH, XDG_CACHE_HOME=$TH/.cache, XDG_CONFIG_HOME=$TH/.config, XDG_DATA_HOME=$TH/.local/share and XDG_STATE_HOME=$TH/.local/state. Never unset HOME: xinit.c then falls back to getpwuid, which is the real home.
7. Print one line: `test home: throwaway <TH> (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)`. Add `home=` and `binary=$xschem_cmd` to T1-RUN-BEGIN; neither field can end in a counted shape.

CLEANUP
- Only the creator deletes. In Tcl that is the same pid, after the trailer. In shell it is `$$ == owner` or `$PPID == owner`, because xvfb-run exec'd from the owner and keeps its pid.
- XSCHEM_TEST_KEEP_HOME=1 keeps the dir and prints its path.
- At arm time, sweep `xschem-test-home.<pid>.*` whose pid is dead and which is older than 300 s, using the same contract as sweep_dead_run_dirs. This covers the 900 s timeout kills.

DISPLAY ARM (T1)
- Attach first, through the carried state dir. The developer's :99 was measured working through this on the fixture.
- Keep 0891's auto-start `$dd start` only when the carried state dir already EXISTS, meaning the tester has used the dev display before.
- Otherwise, and also when start fails (exit 4, a foreign :99, which is today's measured state), run the 11 display cases on a private Xvfb for this run only, started as xvfb_arm does, with openbox under the throwaway, and kill it at the end of T1.
- NODISPLAY only when there is no Xvfb at all.
- This removes F36 for strangers (no persistent Xvfb, no ~/.claude, no ~/.cache/openbox) and F28's swallowed foreign :99. The developer keeps the persistent :99.
- This departs from part of the recorded 0891 ruling ("goes on starting the persistent dev display"). That is the driver's call and belongs in DECISIONS.md.

GATE
- T1 needs nothing: it never sources gui_gate.sh, and devdisplay exec forces GUI_GATE=0.
- The shell drivers keep the real shared control dir through the carried GUI_GATE_DIR.

SUITE FIXES THAT GO WITH IT
- test_ase_converge_1459 ee_binaries and test_ase_sp_1452 se_binaries should locate the fork through `$::env(XSCHEM_TEST_REAL_HOME)`, falling back to HOME. This restores the 6 lost checks (measured 70 against 76).

F10
- The throwaway already contains a PATH binary's HOME writes.
- Also either refuse the PATH fallback, as run_suites.sh and full_audit.sh already do with a FATAL, unless XSCHEM is set explicitly, or at minimum name the binary in the header. Refusing changes CLAUDE.md's documented 0147 order, so it is the driver's call.

THE BARE COMMAND
- `./src/xschem --script tests/headless/<t>.tcl` is not reachable by any driver, and scratch.tcl cannot isolate it (measured).
- Document `HOME=$(mktemp -d) ./src/xschem ...`, or give the assistant a wrapper.
- A fork-only XSCHEM_USER_CONF_DIR env var was considered and rejected. It would not cover upstream PATH binaries (F10), openbox (F36/F39), ngspice's .spiceinit or git.

CANARY FOR S2c (D3)
- Seed the parent HOME with ~/.xschem (sentinel clipboard, simulations/clean.spice and short.spice sentinels, a geometry file with 100 entries, recent_files), plus ~/.spiceinit and ~/.gitconfig.
- Hash everything except the explicitly carved-out ~/.claude/xschem_dev_display, which is allowed to change only if it existed before.
- Red first: with XSCHEM_TEST_HOME=real, the clipboard, clean.spice and short.spice must change. They did in every equivalent run here.

## map.measurements

All of these ran in /var/tmp/xschem_fixes/s2a_map/clone, a clone of 4b9565ad built with ./configure and make (6 s, rc 0), with DISPLAY unset and HOME pointed at a scratch dir, unless a line says otherwise.

(1) devdisplay.sh status, read-only.
- Scratch HOME with no override: `state: foreign`, state dir inside the scratch home, rc 1.
- XSCHEM_DEVDISPLAY_DIR pointed at the real dir: also `state: foreign`. The real xvfb.pid is 1116, which has been dead since the 2026-09-17 20:17 boot.
- The process actually serving :99 is Xvfb pid 1209045, with openbox pid 1209133. ppid for both is init. They were started 2026-09-17 23:38:23 with HOME=/var/tmp/xschem_outsider_audit/verify_f6/home_t1. That is the audit's T1, a throwaway home that has since been deleted.
- CONSEQUENCE FOR THE DRIVER: your F-stage T1 will print 11 NODISPLAY lines, uncounted, whatever Item 2 does. Nobody can stop that display through devdisplay.sh. I did not touch it.

(2) F25, the race to create ~/.xschem, measured red first.
- 20 batches of 16 simultaneous `xschem --nogui --pipe -q` on an empty HOME: 11 of 320 exited 1 with `Tcl_AppInit(): failure creating <home>/.xschem`.
- With .xschem pre-created: 0 of 320.
- A HOME that does not exist: every start exits 1.
- In situ, create_save on a fresh empty HOME produced a counted FATAL in 2 of 6 runs. With .xschem pre-created: 0 of 5.

(3) Two small suites under an empty scratch HOME, run the way T1 runs them. test_signal_short_nohier_0230 and test_paste_modify_flag_0244 both finished OVERALL: ok. The home then held .xschem/{xschemrc, .clipboard.sch 220 B, simulations/clean.spice, simulations/short.spice}.

(4) Can scratch.tcl redirect writes? No, and this was measured red. With ::USER_CONF_DIR and ::netlist_dir redirected inside the suite, the netlist went to the redirect dir. But `xschem copy` overwrote the seeded HOME clipboard: md5 2f3f2beb… became 00df822e…, 1480 B.

(5) All 70 T1 hcases, headless, run sequentially exactly as T1 does:
- Empty throwaway: 3 min 54 s.
- Throwaway seeded with a copy of the real ~/.xschem plus a dev/ngspice symlink: 4 min 38 s.
- The verdicts were IDENTICAL.
- The same 5 suites are red in both, and none of them is caused by HOME. test_op_annot, test_ase_optier_0963, test_unused_attr_0970 and test_auto_specialize_1201 each die with `FATAL: signal 11`; these look like the audit's F14 segfaults. test_issue_stamp fails S20 because the clone folder is named 'clone' (F23).
- The only HOME-sensitive differences are coverage: test_ase_converge_1459 runs 70 checks empty against 76 seeded (`SKIPPED: EE fork leg`), and test_ase_sp_1452 runs 58 in both (its fork leg becomes fork2).
- On the seeded copy, the files changed were .clipboard.sch, simulations/clean.spice and simulations/short.spice. Files with the same names are in the real ~/.xschem.

(6) Display-arm override, shown on a private Xvfb :197 fixture. I never started, stopped or viewed the real :99.
- In the clone only, devdisplay.sh was guarded to refuse start, stop, restart and view (exit 97).
- A trimmed copy of the driver ran two display cases: test_ase_optsheet_1441 and test_annot_blank_cause_0909.
- Red: scratch HOME without the override gave 2 NODISPLAY lines and counted_failures=0.
- Green: scratch HOME with XSCHEM_DEVDISPLAY_DIR=<state dir> gave OVERALL: ok (89 and 27 checks). geometry (254 B) landed in the scratch HOME, and the state dir was only read.

(7) run_suites.sh test_ase_optsheet_1441 under a scratch HOME, private Xvfb arm: PASS. It wrote $HOME/.cache/openbox/{openbox.log,sessions}. With XDG_CACHE_HOME set outside HOME, openbox wrote there instead.

(8) X authority, on a private Xvfb :198 started with -auth. HOME=scratch without XAUTHORITY: cannot open, and xschem reports `Authorization required ... X server connection failed`. With XAUTHORITY pointing at the real cookie: it opens.

(9) ngspice-45.2 reads $HOME/.spiceinit: the echo in it printed with the file present and not without it. It writes nothing to HOME in batch mode. The real home has no .spiceinit.

(10) xschemtest.tcl under a scratch HOME: rc 0, wrote nothing.

The three golden cases (create_save, open_close, netlisting) wrote only .xschem/xschemrc to HOME. As the golden cases have no gold/ baseline, they report NOGOLD whatever HOME is. Not measured: full_audit.sh, an upstream PATH binary (none is installed), git safe.directory with mismatched ownership, and a full 85-case T1.

## map.risks

* Measured on this box today: :99 is held by the audit's orphaned Xvfb (pid 1209045) and openbox (pid 1209133), whose HOME was a now-deleted throwaway. The real state dir is stale (xvfb.pid 1116 is dead). So `devdisplay.sh status` says foreign, with or without XSCHEM_DEVDISPLAY_DIR, and the driver's T1 gate will print 11 uncounted NODISPLAY lines. T1 at zero will then say nothing about the display arm until someone deals with that orphan. Crews are barred from stopping :99, so that is the driver's decision.
* The carry list is the 1397 trap. Any harness path that defaults to $HOME/.claude/... and is not carried does not fail. It skips, or it spawns a second gate panel. Pin the list with a guard row that greps tests/ for `$HOME/.claude` defaults and asserts the helper exports an override for each one.
* HOME must exist and must be SET. A missing directory makes every xschem start exit 1 (measured). An unset HOME silently falls back to getpwuid, which is the real home (read in xinit.c).
* A fresh throwaway without a pre-created .xschem turns create_save into a counted FATAL flake on every run: 2 of 6 measured, 0 of 5 once .xschem was pre-created.
* XAUTHORITY: with HOME switched, a cookie-protected display cannot be opened (measured on :198). That covers explicit AUDIT_DISPLAY arms, the xvfb-run-missing fallback and strangers' Xorg desktops. It has to be carried.
* XDG_CACHE_HOME and XDG_CONFIG_HOME set outside HOME escape a HOME-only redirect. Measured for openbox; git and fontconfig are inferred. They must be pointed into the throwaway too.
* The HOME-derived fork ngspice path in test_ase_converge_1459 silently loses 6 checks (measured 76 to 70), still ALL PASS, because SKIPPED is not counted. test_ase_sp_1452 survives only through its hard-coded fork2.
* Inferred: dropping the global git config loses safe.directory. That is harmless here (same uid), but a stranger with a checkout owned by another uid would see git refuse, and the same suites F21 names would go red. GIT_CONFIG_GLOBAL is an optional carry.
* Cleanup ownership across the xvfb-run re-exec and nested drivers (1476's staged copies, owed.sh drain calling run_suites.sh). Only the creator may delete. A killed run leaves its throwaway behind, so the sweep is required.
* The Tcl helper must live in test_utility.tcl or be added to 1476's staging copy list. Otherwise the staged driver copies fail to source it. If the T1-RUN-BEGIN header gains fields, 1476's V rows need re-running.
* test_crossview_paste reads `$::env(HOME)/.xschem/.clipboard.sch`. HOME therefore has to be fixed when xschem launches. Any scheme that switches HOME inside a suite breaks it.
* The recommended display-arm fallback (a private Xvfb per run instead of auto-starting a persistent :99 for strangers) supersedes part of the recorded 0891 ruling, and must be recorded as a decision.
* Not caused by Item 2, but it will show up in S2c's stranger-shape runs: in a fresh clone, four T1 suites segfault (`FATAL: signal 11`) identically under empty and seeded HOMEs (op_annot, optier_0963, unused_attr_0970, auto_specialize_1201). test_issue_stamp S20 is red in any folder not named xschem-claude (F23, S1's item). Do not attribute these to the HOME change.
* Not measured: full_audit.sh under a throwaway, an upstream PATH binary under a throwaway (none installed, `command -v xschem` rc 1), and a full 85-case T1. S2c should take all three.
* Other Xvfb processes are live on :187, :188 and :189 with HOME=/var/tmp/xschem_fixes/s2a_redirect/xhome. They belong to another crew, not this one, and the driver's cleanup should account for them.

## map.real_home_check

- The manifest check `md5sum -c --quiet …/xschem_manifest_fixes.md5` passed (rc 0) before any work, again after the display demos, and again at the end.
- `find` for files newer than 2026-09-18 00:06 (this session's start) across ~/.xschem, ~/.claude/xschem_dev_display, ~/.claude/gui_test_gate and ~/.cache/openbox returned 0 files. Newest mtimes: the state dir 2026-09-15 08:09, the gate dir 2026-09-10 13:28, openbox.log 2026-09-17 06:48.
- The newest /tmp/Xschem.log.* is .4 at 23:35, before this session. My display runs used --logdir under the clone, so they wrote none.
- I never ran devdisplay.sh start, stop or view against :99. Only a guarded clone copy existed, and it refused them with exit 97. The :99 orphan (pid 1209045) is still running and untouched.
- My own Xvfb fixtures on :197 and :198 have been killed, and their locks are gone.
- The real ~/.xschem was only read, by `cp -a` into the seeded scratch home.
- Nothing was written in ~/dev/xschem-op-wcard. Nothing was committed.
- Scratch left for the driver to delete: /var/tmp/xschem_fixes/s2a_map (763 MB). It holds the clone with its guarded devdisplay.sh and tests/run_regression_s2a.tcl, the sweep logs in sweep_empty/ and sweep_seeded/, and the scratch homes.

## map.dependences

* {"where": "src/xinit.c Tcl_AppInit: `if ((home_buff = getenv(\"HOME\")) == NULL) { home_buff = getpwuid(getuid())->pw_dir; }` then `regsub {^~/} {%s} {%s/}` on USER_CONF_DIR, which config.h defines as `\"~/.xschem\"`", "what": "This is where the whole xschem config directory comes from. $HOME/.xschem is created with stat()+mkdir(0700), and mkdir is not -p. When the mkdir wins, the template xschemrc is copied in. On any mkdir failure it prints `Tcl_AppInit(): failure creating %s` and calls `Tcl_Exit(EXIT_FAILURE)`. If HOME is UNSET, the code falls back to the passwd home, which is the real one (READ).", "with_scratch_home": "MEASURED: every xschem config read and write moves into the throwaway. A HOME that does not exist makes every start exit 1 with `failure creating .../does_not_exist/.xschem`. With 16 parallel starts on an empty HOME, 11 of 320 exited 1 with `failure creating` (this is F25). With .xschem pre-created (mkdir -m 700), 0 of 320 failed and no template copy was made.", "must_see_real_home": false, "existing_override": "None for the config dir. --preinit runs after the dir is created. Pre-creating $HOME/.xschem is the only fix for the race. HOME must be SET to the throwaway, never unset."}
* {"where": "src/xinit.c Tcl_AppInit: `if(!clip_file[0]) { my_snprintf(clip_file, S(clip_file), \"%s/%s\", user_conf_dir, \".clipboard.sch\"); }` (sel_file likewise). Consumers: save.c `name = clip_file`, paste.c `name = clip_file`", "what": "The clipboard and selection file paths are C globals, fixed at startup. `xschem copy` and `cut` write $HOME/.xschem/.clipboard.sch (F6). No CLI option or scheduler verb sets them (READ: grep of options.c and scheduler.c finds nothing).", "with_scratch_home": "MEASURED: after test_paste_modify_flag_0244 and in the hcases sweep, the clipboard (220 B) lands in the throwaway. MEASURED red: a suite-level redirect (`set ::USER_CONF_DIR <scratch>`) did NOT move it. A seeded sentinel clipboard md5 2f3f2beb… became 00df822e… (cmos_inv, 1480 B) in HOME, and nothing appeared in the redirect dir.", "must_see_real_home": false, "existing_override": "none"}
* {"where": "src/xinit.c Tcl_AppInit: `if(!running_in_src_dir) { ... look for (user_conf_dir)/xschemrc }` and the in-tree `set XSCHEM_LIBRARY_PATH %s/xschem_library` built from user_conf_dir", "what": "The in-tree binary never sources ~/.xschem/xschemrc. An installed binary ($XSCHEM, or test_utility.tcl's PATH fallback) does. The in-tree library path starts with $HOME/.xschem/xschem_library, so a tester's personal library is searched first.", "with_scratch_home": "READ: no user rc and no personal library are read, so runs are hermetic.", "must_see_real_home": false, "existing_override": "XSCHEM (binary). No rc override is needed."}
* {"where": "Startup readers and writers under ::USER_CONF_DIR. Readers: ase::sim_conf_file (`file join $::USER_CONF_DIR ase_simulators`, read by sim_load_conf at startup; issue 1377), colors, simrc, recent_files, op_param_lists.conf, wviewer::rawhist_path (raw_history), library_defs personal library.defs, net_hilight_* sourced files. Writers: proc store_geom (`set geom_file $USER_CONF_DIR/geometry`, has_x only, F7), `set_ne netlist_dir \"$USER_CONF_DIR/simulations\"` (F8), op_annot::_oracle_dir (op_annot/), the ase_simulators autosave, write_recent_file (gated by no_recent_files under --nogui/--pipe)", "what": "xschem's Tcl side reads the tester's configuration into memory before the suite's first line runs, and writes geometry, netlists, op_annot/ and the registry back into the same directory.", "with_scratch_home": "MEASURED: all 70 T1 hcases gave IDENTICAL verdicts under an empty throwaway and under a throwaway seeded with a copy of the real ~/.xschem. The only differences were coverage (see the fork-ngspice row). After a full empty-home hcases sweep the home held .xschem/{xschemrc 34595 B, .clipboard.sch 220 B, simulations/clean.spice, simulations/short.spice, op_annot/}. On the seeded copy, the files changed were .clipboard.sch, simulations/clean.spice and simulations/short.spice. The REAL ~/.xschem holds files with those names, so a real-HOME T1 overwrites them. A display-arm case wrote .xschem/geometry (254 B) into the throwaway.", "must_see_real_home": false, "existing_override": "Per-suite only: scratch.tcl test_sim_registry_isolate (clears memory). Some suites point ::USER_CONF_DIR at scratch themselves (simreg_0931, simdlg_0937, recent_conf_compat_0924)."}
* {"where": "tests/run_regression.tcl, display arm in the top-level `if {!$a}` body: `catch {exec $dd start 2>@1}` / `catch {exec $dd status 2>@1} dd_st` / `set dd_alive [expr {[string match {*state:*alive*} $dd_st] ? 1 : 0}]` / `set dccmd [concat [list $dd exec] $t1_pre [list $xschem_cmd --pipe -q --logdir $dlogdir --script ${dc}.tcl]]`", "what": "T1 itself contains no HOME reference (READ: grep finds none in run_regression.tcl, test_utility.tcl or banner_rule.tcl). It reaches HOME only through devdisplay.sh's state dir, and through children that inherit the environment. This `start` is F36: when :99 is free it launches a persistent Xvfb and openbox and never stops them. No `$dd stop` exists.", "with_scratch_home": "MEASURED red: on a private Xvfb :197 fixture with a scratch HOME and no carry, both display-arm cases printed NODISPLAY with counted_failures=0. That is issue 1397's trap, reproduced. MEASURED green: the same run with XSCHEM_DEVDISPLAY_DIR set to the 'real' state dir ran both cases on the display (test_ase_optsheet_1441 OVERALL: ok, 89 checks; test_annot_blank_cause_0909 OVERALL: ok, 27 checks). Their geometry landed in the throwaway, and the state dir was only read. MEASURED on this box today: an uncarried `start` is exactly what left :99 held by Xvfb pid 1209045 and openbox pid 1209133. Both were started 2026-09-17 23:38 with HOME=/var/tmp/xschem_outsider_audit/verify_f6/home_t1, a deleted throwaway, so no state dir can ever identify or stop them.", "must_see_real_home": true, "existing_override": "XSCHEM_DEVDISPLAY_DIR (works, MEASURED). DEVDISPLAY_NUM."}
* {"where": "tests/headless/devdisplay.sh: top-level `STATE_DIR=\"${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}\"`; cmd_start: `mkdir -p \"$STATE_DIR\"`, then xvfb.pid, wm.pid, display, screen, wm, and `DISPLAY=\"$DPY\" \"$WM\" >/dev/null 2>&1 &`; cmd_exec: `DISPLAY=\"$DPY\" GUI_GATE=0 \"$@\"`", "what": "The dev-display identity record, plus the openbox that start launches. exec passes HOME through unchanged, so display-arm children inherit whatever HOME T1 has.", "with_scratch_home": "MEASURED with a scratch HOME and no override: `state: foreign`, with the state dir resolved inside the scratch home. MEASURED with the override pointing at the real dir: also `state: foreign`, because the real xvfb.pid is 1116, dead since the 2026-09-17 20:17 boot, and the audit's orphan serves :99. So the driver's own T1 gate will print 11 NODISPLAY today whatever Item 2 does.", "must_see_real_home": true, "existing_override": "XSCHEM_DEVDISPLAY_DIR, DEVDISPLAY_NUM, DEVDISPLAY_WM"}
* {"where": "tests/headless/xvfb_arm.sh _xvfb_dev_display: `local sf=\"${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}/display\"` plus `\"$dd\" status`; _xvfb_wm_launch: `\"$wm\" >/dev/null 2>&1 &` under `exec xvfb-run -a ...`", "what": "Decides whether run_suites.sh, full_audit.sh and gated_xschem.sh attach to :99 or spawn a private Xvfb. The private path starts openbox with the driver's inherited HOME/XDG, and openbox writes $XDG_CACHE_HOME/openbox, else $HOME/.cache/openbox (F36/F39).", "with_scratch_home": "MEASURED: with a scratch HOME and DISPLAY unset, run_suites.sh test_ase_optsheet_1441 took the private Xvfb and PASSed (89 checks). It wrote $HOME/.cache/openbox/{openbox.log,sessions} into the scratch home. MEASURED: with XDG_CACHE_HOME pointing outside HOME, openbox wrote there instead, so a HOME-only redirect leaks through XDG. HOME must be switched BEFORE xvfb_arm for openbox to see it.", "must_see_real_home": true, "existing_override": "XSCHEM_DEVDISPLAY_DIR (for attaching). AUDIT_DISPLAY / AUDIT_WM / AUDIT_SCREEN. XDG_CACHE_HOME (for openbox)."}
* {"where": "tests/headless/gui_gate.sh: top-level `GATE_DIR=\"${GUI_GATE_DIR:-$HOME/.claude/gui_test_gate}\"`; _gate_dev_display: `local f=\"${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}/display\"`; _gate_enabled; the wish panel", "what": "The shared Pause/Stop control dir, where one panel governs every session. It is live only when the gate is enabled: an explicit AUDIT_DISPLAY arm, or a bare gated_xschem.sh on a real DISPLAY. xvfb_arm forces GUI_GATE=0 on the attach and private arms. T1 never sources gui_gate.sh, and devdisplay exec sets GUI_GATE=0.", "with_scratch_home": "MEASURED: on the default arm under a scratch HOME no gate dir was created. READ/INFERRED: on an explicit arm, an uncarried GATE_DIR would be the throwaway. The real panel would then not govern the run, and _gate_ensure_widget would launch a second panel for the throwaway dir.", "must_see_real_home": true, "existing_override": "GUI_GATE_DIR, GUI_GATE=0"}
* {"where": "tests/headless/run_suites.sh, full_audit.sh, gated_xschem.sh (`XSCHEM=\"${XSCHEM:-$REPO/src/xschem}\"`, `tmpd=$(mktemp -d)`, `timeout \"$TIMEOUT\" \"$XSCHEM\" ...`; full_audit tree_delta_snapshot runs `git -C \"$root\" status --porcelain` in the driver); wireedit/run_wireedit.sh", "what": "None of these references HOME directly. They inherit it to every xschem child, and mktemp uses TMPDIR. Their HOME-derived state comes in only through xvfb_arm.sh and gui_gate.sh. full_audit's own git status reads the global git config (for example core.excludesFile).", "with_scratch_home": "MEASURED for run_suites.sh (PASS). full_audit was not run. INFERRED: its report-only TREE delta can change if the tester's global git excludes are dropped.", "must_see_real_home": false, "existing_override": "XSCHEM, AUDIT_*, SUITE_TIMEOUT / AUDIT_TIMEOUT"}
* {"where": "tests/test_utility.tcl top level: `set xschem_cmd \"xschem\"` ... `if {[file executable $_xs_tree]} { set xschem_cmd $_xs_tree }`", "what": "F10. With no $XSCHEM and no built src/xschem, T1 runs the PATH xschem. That binary is not running_in_src_dir, so it sources ~/.xschem/xschemrc, and upstream rewrites ~/.xschem/recent_files. T1-RUN-BEGIN never names the binary.", "with_scratch_home": "INFERRED (upstream derives its config dir from HOME the same way): the PATH binary's writes land in the throwaway, so the real Open Recent is safe, but the wrong binary still runs unnamed. Not measurable here: `command -v xschem` returns rc 1 and /usr/local/bin is empty.", "must_see_real_home": false, "existing_override": "XSCHEM"}
* {"where": "tests/headless/scratch.tcl: __scratch_cleanup_all `catch {proc ::store_geom {args} {}}`; test_sim_registry_isolate; test_scratch roots under tests/headless/.scratch or XSCHEM_TEST_SCRATCH", "what": "Reads no HOME. Could scratch.tcl redirect writes for the bare command? It runs after Tcl_AppInit and xschem.tcl. By then ~/.xschem has been created with its template, the user config has been read, and clip_file/sel_file are fixed in C.", "with_scratch_home": "MEASURED: a suite-level `set ::USER_CONF_DIR`/`::netlist_dir` redirect moved the netlist into the redirect, but the C clipboard still overwrote $HOME/.xschem/.clipboard.sch. READ: 19 of T1's 71 unique suite names do not source scratch.tcl (including test_crossview_paste, which writes the clipboard), and neither do the 3 golden cases or xschemtest.tcl. So scratch.tcl cannot provide isolation. HOME has to be set when xschem starts.", "must_see_real_home": false, "existing_override": "XSCHEM_TEST_SCRATCH (location of scratch dirs only)"}
* {"where": "tests/banner_rule.tcl", "what": "No HOME dependence (READ).", "with_scratch_home": "unaffected", "must_see_real_home": false, "existing_override": "n/a"}
* {"where": "tests/headless/owed.sh: `OWED_DIR=\"${XSCHEM_OWED_DIR:-$HOME/.claude/xschem_owed}\"`; drain runs `AUDIT_DISPLAY=\"$display\" \"$HERE/run_suites.sh\"`", "what": "The user's debt ledger. owed.sh CALLS a driver and is never called by one.", "with_scratch_home": "Unaffected as long as the HOME switch happens inside the driver: the ledger stays in the parent process's real HOME (READ).", "must_see_real_home": true, "existing_override": "XSCHEM_OWED_DIR"}
* {"where": "tests/headless/spawn_reaper.sh _reaper_devdisplays: `for f in \"${XSCHEM_DEVDISPLAY_DIR:-}/display\" \"$HOME/.claude/xschem_dev_display/display\"`", "what": "A guard that refuses to reap the dev display. It deliberately reads $HOME unconditionally. Only test_devdisplay.sh and test_gui_gate_*.sh use it; the three drivers never reach it.", "with_scratch_home": "READ: when XSCHEM_DEVDISPLAY_DIR is carried, the guard still sees :99. Without the carry, the $HOME half would go blind.", "must_see_real_home": true, "existing_override": "XSCHEM_DEVDISPLAY_DIR"}
* {"where": "ngspice, started by ASE suites (for example 1459, 1462, 1464, 1465, 1466, 1452, 1470); ase.tcl predeck_user_file enumerates `$::env(HOME)` for .spiceinit/spice.rc", "what": "ngspice reads $HOME/.spiceinit when the cwd has none, so a tester's init can change simulator results.", "with_scratch_home": "MEASURED on ngspice-45.2: an `echo` placed in HOME/.spiceinit printed with the file present and not without it. Nothing was written to HOME in batch mode. The real home has no ~/.spiceinit (MEASURED ls). So a throwaway HOME changes nothing on this box and makes a stranger's run hermetic.", "must_see_real_home": false, "existing_override": "SPICE_USERINIT_DIR; ngspice -n"}
* {"where": "test_ase_converge_1459 ee_binaries: `[list fork [file join $home dev ngspice build-ver_50 src ngspice]]` with `set home $::env(HOME)`; test_ase_sp_1452 se_binaries: the same, plus a hard-coded `fork2 /home/analog/dev/ngspice/build-ver_50/src/ngspice`", "what": "The fork ngspice binary is located through HOME, as a read-only binary path.", "with_scratch_home": "MEASURED: under a throwaway, converge_1459 drops from ALL PASS (76 checks) to ALL PASS (70 checks) with `SKIPPED: EE fork leg`. That coverage loss is silent, because summarize_all does not count SKIPPED. sp_1452 stays at 58: fork is skipped, and fork2 runs under the /fork2 labels.", "must_see_real_home": true, "existing_override": "ASE_CONV_NGSPICE, ASE_SP_NGSPICE (colon lists)"}
* {"where": "git read calls in T1 suites: `git ls-files` in test_ase_core, options_1437, predeck_1439, simcaps_0948, sp_1452 and state_roundtrip.tcl; `git rev-parse`/`git show` in test_issue_stamp and issue_stamp.tcl", "what": "git reads $HOME/.gitconfig and $XDG_CONFIG_HOME/git/config. The real ~/.gitconfig holds only user.name and user.email (READ). No T1 git call needs an identity or writes config.", "with_scratch_home": "MEASURED: every git-reading hcase is green under an empty HOME. INFERRED: a tester who relies on a global safe.directory, or other core.* settings, for a checkout owned by another uid (CI container, shared mount) would get `dubious ownership` and F21-style reds.", "must_see_real_home": false, "existing_override": "GIT_CONFIG_GLOBAL"}
* {"where": "Xlib authority lookup: $XAUTHORITY, else $HOME/.Xauthority", "what": "Needed for any display that requires a cookie: an explicit AUDIT_DISPLAY, the inherited DISPLAY fallback when xvfb-run is missing, or a stranger's Xorg desktop. xvfb-run exports its own XAUTHORITY. The :99 Xvfb has no -auth.", "with_scratch_home": "MEASURED on a private Xvfb :198 started with -auth: HOME=cookie-home opens it. HOME=scratch without XAUTHORITY gives CANNOT OPEN, and xschem says `Authorization required ... X server connection failed`. HOME=scratch with XAUTHORITY=<real cookie> opens it. This box has XAUTHORITY unset and no ~/.Xauthority, so it is unaffected here.", "must_see_real_home": true, "existing_override": "XAUTHORITY"}
* {"where": "openbox (devdisplay.sh cmd_start; xvfb_arm.sh _xvfb_wm_launch) and other XDG users (fontconfig, git)", "what": "Cache in $XDG_CACHE_HOME/openbox, else ~/.cache/openbox. Config in ~/.config/openbox (absent here).", "with_scratch_home": "MEASURED: with a throwaway HOME the cache lands in the throwaway. With XDG_CACHE_HOME set outside it, the cache lands there. No fontconfig cache was written by any display-arm run (MEASURED: none appeared in any scratch home).", "must_see_real_home": false, "existing_override": "XDG_CACHE_HOME / XDG_CONFIG_HOME"}
* {"where": "Suites that use $::env(HOME) directly: test_op_annot `set Z_HRAW [file join $::env(HOME) $Z_HNAME]` (T1); test_crossview_paste `set clip [file join $::env(HOME) .xschem .clipboard.sch]` (T1); in full_audit only: test_paste_at_log, test_perform_action_embed_rawfile, test_raw_read_dispatch, test_results_select", "what": "Probe files written at the root of HOME (F39). The crossview test reads the clipboard back through HOME, which only works if HOME is the same one xschem started with. Four suites (simreg_0931, simdlg_0937, predeck_1439, op_param_store_1245) set and restore ::env(HOME) themselves.", "with_scratch_home": "MEASURED: every one of these is green in the empty-home sweep, and none left a probe behind (the only leftovers are listed in the startup-writers row). Switching HOME inside a suite, after launch, would break crossview_paste, because C writes the clipboard to the launch HOME.", "must_see_real_home": false, "existing_override": "none"}
* {"where": "PDK access: test_sky130a/gf180mcud/ihp_sg13g2_libmgr and test_pdk_launcher; tools/launcher/pdk_launcher.tcl `set CONF [file join $::env(HOME) .xschem pdk_launcher.conf]`", "what": "The PDK suites read repo-relative workareas (sky130A/, gf180mcuD/, ihp-sg13g2/) whose library.defs contain no '~'. test_pdk_launcher sources the launcher with ::PDK_LAUNCHER_NO_UI, which returns before `load_conf`, so the conf is never read or written.", "with_scratch_home": "READ: nothing reaches a PDK through ~; unaffected.", "must_see_real_home": false, "existing_override": "n/a"}
* {"where": "tcases create_save / open_close / netlisting (xargs/sh jobs: `'$xschem_cmd' ... --nogui ...`, 16 workers), plus xschemtest.tcl", "what": "Parallel --nogui xschem starts inherit HOME. They write no geometry and no recents.", "with_scratch_home": "MEASURED on an empty throwaway: open_close and netlisting write only .xschem/xschemrc. create_save logged a counted `FATAL: 1` from `failure creating` (pcb_test1_debug.txt) in 2 of 6 runs; with .xschem pre-created, 0 of 5. xschemtest.tcl (as T1 runs it) wrote nothing and exited rc 0.", "must_see_real_home": false, "existing_override": "none"}

# 2. Redirect study

## redir.feasible

PARTIAL

## redir.mechanism

Three prototypes were built in scratch clones under /var/tmp/xschem_fixes/s2a_redirect/ (built from 4b9565ad). Diffs are in /var/tmp/xschem_fixes/s2a_redirect/patches/.

B, Tcl-only redirect in scratch.tcl (clonb, patches/B_scratch_redirect.diff): a new proc __scratch_isolate_conf runs at source time. It does `set d [test_scratch homeiso]`, `set ::USER_CONF_DIR $d`, and sets ::netlist_dir to $d/simulations when it still equals `[file join $real simulations]`. The opt-out placeholder is XSCHEM_TEST_REAL_HOME=1. It is not enough: the C clipboard is still written, and one suite breaks. The product's own proc schpins_to_sympins does `xschem copy` (C, writes the startup clip_file) and then `read_data_nonewline $USER_CONF_DIR/.clipboard.sch` (Tcl path). Split them and the feature reads an empty file while the real clipboard is clobbered. MEASURED: test_schpins_stale_lab_0185 went from ALL PASS (15) to 11 FAILED, and changed the real clipboard (92->224 B) where the baseline restored it.

C, B plus a C trace (clonc, patches/C_scratch_redirect_plus_c_trace.diff, about 20 lines in src/xinit.c): after clip_file is set, `Tcl_TraceVar(interp, \"USER_CONF_DIR\", TCL_GLOBAL_ONLY | TCL_TRACE_WRITES, user_conf_dir_trace, NULL)`. The callback copies the new value into user_conf_dir and rebuilds sel_file and clip_file. It catches every in-process write with 0 verdict changes. It misses child processes and HOME-root `~/` files. As a product change it also closes a latent split: an xschemrc that sets USER_CONF_DIR already leaves the C clipboard on ~/.xschem (INFERRED).

R, re-exec in scratch.tcl, no C change (clonr, patches/R_scratch_reexec.diff): proc __scratch_reexec_home runs right after __scratch_root, before the exit wrapper and the watchdog. It runs only if XSCHEM_TEST_HOME_ISOLATED is unset and `xschem` exists, and it needs /proc (Linux only). Steps:
1. Read argv from /proc/[pid]/cmdline.
2. Make <scratch>/_home_<pid>. The dead-pid sweep already matches that name.
3. Restore the LAUNCH environment from /proc/[pid]/environ. This is required: src/xschem.tcl `set env(LC_ALL) C` otherwise flips the child's system encoding to iso8859-1. MEASURED: without it, test_ase_core, test_ase_preflight, test_wave_casemode and test_rdw_window_1245 went red on non-ASCII.
4. Set HOME and the marker, stub store_geom, `wm withdraw .`.
5. `exec [info nameofexecutable] {*}args <@stdin >@stdout 2>@stderr`.
6. Map CHILDSTATUS/CHILDKILLED to the exit code (128+signal for a kill), delete the home, exit.
Descendants inherit the marker, so they do not re-exec.

Where each audit write is decided:
- WRITE time, redirectable: geometry, recent_files (also gated), raw_history, op_annot, ase_simulators, the Tcl clipboard procs (create_pins, schpins_to_sympins, add_lab_*), and netlists/.ase_probe through ::netlist_dir.
- STARTUP: clip_file, sel_file, user_conf_dir and home_dir (C globals in xinit.c Tcl_AppInit), the ::netlist_dir value, and the template xschemrc (created before any script runs).

My call for S2b, internal engineering: use a driver-level HOME for T1, run_suites and full_audit, since only that covers pre-script startup and non-scratch suites. Add R to scratch.tcl for the bare command. Move `source scratch.tcl` to the top of the 7 late suites. Give test_crossview_paste and test_geometry_sanity their own isolation. C is optional as a product fix, not needed for the tests once R exists.

## redir.covered

* NETLISTS ~/.xschem/simulations/{clean,short}.spice (F8) plus their transient temp files .clean_<pid>/.short_<pid>. The writers read Tcl netlist_dir when they write. C: spice_netlist.c and the other backends use `tclgetvar("netlist_dir")`; Tcl: proc set_netlist_dir `if {$netlist_dir eq {}} { set netlist_dir "$USER_CONF_DIR/simulations" }`. BUT ::netlist_dir itself is a STARTUP snapshot (src/xschem.tcl top level: `set_ne netlist_dir "$USER_CONF_DIR/simulations"`), so repointing USER_CONF_DIR alone does NOT move netlists. scratch.tcl also has to repoint ::netlist_dir while it still equals that default. READ; MEASURED caught by B, C and R (test_signal_short_nohier_0230: A CHANGED both files, B/C/R 0 events).
* simulations/.ase_probe/p<pid>_N/*: proc ase::cap_workdir `set base [set_netlist_dir 0]` then `file join $base .ase_probe`, so it follows ::netlist_dir at call time. READ. MEASURED: 12 suites write it transiently in A (e.g. test_ase_final, test_ase_preflight, test_ase_variant_1470, test_sim_run_profile, test_wave_viewer); 0 in B/C/R.
* op_annot/: proc op_annot::_oracle_dir `return [file join $::USER_CONF_DIR op_annot]` is resolved at call time. READ. MEASURED: 6 suites in A (test_ase_core, test_ase_final, test_ase_final_gf180, test_ase_optier_0963, test_unused_attr_0970, test_wave_viewer) write oracle decks there, and create the dir in an empty HOME. 0 in B/C/R.
* geometry (F7): proc store_geom `set geom_file $USER_CONF_DIR/geometry` is resolved at call time, and only runs with has_x. READ. MEASURED on the GUI arm (private Xvfb + openbox): GA test_op_annot made 198 close-writes (587 events) and the file changed 6730->6668 B; annot_stale_0684 65, annot_blank_cause_0909 16, annot_show_menu 6. GC and GR: 0 for every scratch-sourcing suite. The exit-time write is already stubbed by __scratch_cleanup_all `proc ::store_geom {args} {}`.
* recent_files: proc write_recent_file `open $USER_CONF_DIR/recent_files w` is resolved at call time and is also hard-gated (`if {[info exists update_recent_files] && !$update_recent_files} return`; xinit.c sets no_recent_files under --nogui/--pipe). READ. 0 events in every variant (MEASURED absence, never seen red here).
* raw_history: proc wviewer::rawhist_path `return [file join $::USER_CONF_DIR raw_history]`, commented 'Derived at CALL TIME, never cached'. READ. No suite in these runs wrote it (UNKNOWN red).
* ase_simulators: proc ase::sim_conf_file `return [file join $::USER_CONF_DIR ase_simulators]` is resolved at call time; it is written only through ase::sim_touch/ase::sim_write_conf. READ. MEASURED 0 writes in all variants, including a canary that carries a registered, selected ngspice (RA/RC/RR, 187 suites each).
* Clipboard (F6): ONLY with variant C (a C change) or R (re-exec), NOT with a Tcl-only redirect. MEASURED: clipboard writers were 6 of 187 suites under A, 6 under B, 2 under C (both through child xschem processes) and 0 under R.
* With R (the re-exec from scratch.tcl) everything after the parent's startup is covered: C-cached paths, child xschem processes, `~/`-relative HOME-root probe files, ngspice children. MEASURED 0 write events under the canary, beyond the parent's startup .selection.sch unlink, in 187/187 suites on each of three seeds (a developer copy, an empty HOME, and one with a registered simulator), and in 17 GUI-arm suites (11 T1 dcases, 11/11 same verdicts as baseline).

## redir.uncovered

* PRE-SCRIPT STARTUP (no scratch.tcl approach can reach it, R included). (a) Every xschem start deletes $HOME/.xschem/.selection.sch before the first script line. MEASURED in 402/402 suites and with a no-op script; `-d 1` shows `unselect_all(1): start` x5 at startup. The code is src/select.c unselect_all `my_snprintf(str, S(str), "%s/%s", user_conf_dir, ".selection.sch"); ... xunlink(str);` and uses the C global user_conf_dir, cached at startup. This matters to a user doing a cross-window copy while tests run (INFERRED low severity), and it means a canary seeded with .selection.sch can NEVER come back byte-identical from the bare command. (b) In a HOME with no .xschem, Tcl_AppInit creates .xschem/ and copies the 34595 B template xschemrc (`tclvareval("file copy {", srcfile, "} {", dstfile, "}", NULL)`). MEASURED in every FA/FB/FC/FR run. The F25 mkdir race lives in the same place.
* Clipboard under a Tcl-only redirect (variant B). C global clip_file is fixed in xinit.c Tcl_AppInit `if(!clip_file[0]) { my_snprintf(clip_file, S(clip_file), "%s/%s", user_conf_dir, ".clipboard.sch"); }`; its writer is save.c save_selection `name = clip_file;`; its reader is paste.c merge_file `name = clip_file;`. sel_file is fixed the same way. MEASURED: B still wrote the real clipboard in 6 suites.
* Child xschem processes that suites spawn inherit the process HOME, not the parent's Tcl vars. Examples: test_no_untitled_litter `exec timeout 60 $xschem --pipe -q --logdir ...` and test_wave_markers `exec [info nameofexecutable] --nogui --pipe -q ...`. MEASURED still writing the clipboard under C. Only R, or a driver-level HOME, reaches them.
* HOME-root probe files written on purpose through env(HOME) to test `~/` expansion, which C performs with the startup-cached home_dir (xinit.c `home_buff = getenv("HOME") ... my_strncpy(home_dir, home_buff, S(home_dir))`): test_raw_read_dispatch `set INJ_HRAW [file join $::env(HOME) $INJ_HNAME]` and rawdisp0816probe_<pid>.{log,sch}; test_results_select `set ab_dir [file join $env(HOME) .xschem_results_select_[pid]]`; test_op_annot `set Z_HRAW [file join $::env(HOME) $Z_HNAME]` (GUI arm); test_perform_action_embed_rawfile (READ). They are transient and survive only a kill. MEASURED caught by R, not by B or C. Setting ::env(HOME) in-process would split Tcl from C home_dir (INFERRED; the suite comment says 'the probe file can ONLY live directly under $HOME').
* The 215 of 402 test_*.tcl suites that do not source scratch.tcl, including 20 of T1's 70 hcases, 0 of 3 tcases, and xschemtest. MEASURED writers among them: test_crossview_paste (a T1 hcase; clipboard headless; clipboard + geometry on GUI, in all variants) and test_geometry_sanity (geometry, GUI). The remaining ~213 were measured headless only (no other writer found); on the GUI arm they are UNKNOWN.
* Late `source scratch.tcl`: coverage starts at that line. 7 suites act at top level before sourcing it: test_wave_sigsearch (inside `if {[info exists ::has_x] ...}` at line 2638, so the GUI arm only), test_add_wire_label@300, test_find_helper@323, test_perform_action_embed_rawfile@233, test_nh_editor_preview@65, test_sch_add_pin@67, test_annot_show_menu@306. That prelude runs unprotected in every variant, and under R it runs TWICE (MEASURED duplicate output: find_helper +123 lines, add_wire_label +88, sch_add_pin +16; verdicts unchanged).

## redir.measurements

Method. Each suite ran as the documented bare command `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl` from the tree root. DISPLAY was unset. HOME was a fresh copy of a seeded canary: a copy of the user's real ~/.xschem (27 files; the 139 MB raw replaced by a sentinel), plus a .selection.sch sentinel and a root sentinel. Each run had a timeout of 600 s. Evidence per run: (1) a before/after md5+mtime snapshot diff; (2) a recursive inotify recorder (python ctypes, since inotify-tools and strace are absent) that sees transient writes. Red-first: the same recorder shows the writes on the unredirected tree (A). Runners: /var/tmp/xschem_fixes/s2a_redirect/tools/{run_one.sh,run_one_gui.sh,snap.sh,sdiff.sh,iwatch.py}. Per-run data: runs/<variant>/<suite>/{out,events,home.diff}. Indexes: runs/<variant>.index.

Headless, developer canary. Suites that wrote under the canary during the run (beyond the universal startup unlink): A = 25 of 402 (net: 7 clipboard, 1 netlist pair), B = 9 of 187, C = 4 of 187, R = 0 of 187.
- A: clipboard 7 suites (crossview_paste, no_untitled_litter, paste_modify_flag_0244, placement_preview_doors, shape_draw_gate, wave_markers CHANGED; schpins_stale_lab_0185 TOUCHED/restored); .ase_probe 12; op_annot 6; netlists 1 (signal_short_nohier_0230); .selection.sch written by 2 (label_ride, wave_markers); HOME-root 2 (raw_read_dispatch, results_select).
- B: clipboard 6, .selection.sch 2, HOME-root 2.
- C: clipboard 2 (children of no_untitled_litter and wave_markers), HOME-root 2.
- R: none.

Fresh empty HOME (stranger). Left behind beyond .xschem/ + template xschemrc:
- FA: simulations/ 18 suites, op_annot/ 6, clipboard 7, netlists 1.
- FB: clipboard 6. FC: clipboard 2. FR: nothing.
- All four create .xschem/xschemrc at startup (MEASURED).

Canary with a registered and selected ngspice: A/C/R verdicts identical over 187 suites; R writes nothing.

Verdicts. B vs A: 1 change (schpins_stale_lab_0185). C vs A: 0. R vs A: 0 attributable. Two raw diffs were checked: test_no_untitled_litter is already red in A and flips between 2 and 3 FAILED run to run; raw_read_dispatch LM13 is cross-talk from untitled~.sch that parallel suites drop in the shared repo root, and it passed solo 3/3.

GUI arm (private Xvfb :187/:188/:189 + openbox, HOME=scratch, stopped afterwards; :99 never touched), 11 T1 dcases: GA/GC/GR verdicts identical. Geometry written in GA (op_annot 587 events), none in GC or GR. GC still left op_annot's HOME-root probe raw; GR left nothing. Four suites hang on this arm in ALL variants (rc 124, baseline, not redirect-related): test_wave_markers (stops after MF11a), test_placement_preview_doors, test_paste_modify_flag_0244, test_shape_draw_gate.

Cost of R: 15 serial runs took 7321 ms against 6416 ms, about 60 ms per suite.

Confound found and removed. A variant tree named `cloneB` turned 5 ASE suites red: sp_1452 SE1, campaign_1462, campaign_gui_1464, converge_1459 and variant_1470. The cause is the UPPERCASE letter in the checkout path, not the redirect. MEASURED for sp_1452: `clonB` gives 2 FAILED, `clone2` gives ALL PASS. For the other four, case and length were not separated. This is a stranger finding for the driver: ngspice appears to lowercase the unquoted `wrs2p <path>` (INFERRED). A throwaway HOME must therefore contain no uppercase letters.

Coverage counts: 187 of 402 test_*.tcl source scratch.tcl; T1 is 50/70 hcases, 11/11 dcases, 0/3 tcases.

## redir.risks

* B (Tcl-only redirect) is actively harmful: it splits the product's C clipboard path from its Tcl clipboard path. schpins_to_sympins then reads an empty file, test_schpins_stale_lab_0185 goes 15 PASS -> 11 FAILED, and the suite's backup/restore protects the wrong file. MEASURED. Do not ship B without C.
* R must hand the child the LAUNCH environment. src/xschem.tcl `set env(LC_ALL) C` is inherited otherwise and flips the child's Tcl encoding to iso8859-1. MEASURED: 4 suites red on non-ASCII until /proc/[pid]/environ was restored.
* R is Linux-only (/proc/[pid]/cmdline and /proc/[pid]/environ); elsewhere it falls through to no protection. It runs the suite prelude twice when `source scratch.tcl` is late (7 suites). A parent killed by an outer timeout leaves `_home_<pid>`; MEASURED 3 corpses, all from timeout kills, which the existing 300 s dead-pid sweep collects. A child segfault is still cleaned by the parent.
* R changes what a suite sees from HOME: the developer's registry, ~/.spiceinit, and fixtures read via env(HOME). Examples: test_vcd_read `$::env(HOME)/.xschem/simulations/counter.vcd`, test_ase_cosim, test_vcd_time_base. MEASURED no verdict change on this box (those fixtures are absent; the registry is empty or registered). On a developer box that has those fixtures, rows that use them would stop running (INFERRED).
* Uppercase letters in any path that ends up in an ngspice control line break ASE suites (MEASURED on sp_1452). The throwaway HOME, and any driver-level HOME, must be lowercase. B/C also lengthen netlist_dir to <repo>/tests/headless/.scratch/_homeiso_<pid>/simulations, and R lengthens HOME the same way; no length-induced red was observed at a 40-char tree root.
* C's trace makes the C paths follow EVERY later write of ::USER_CONF_DIR in the product. That is intended, but it is a product behaviour change. Two things break as a result. test_crossview_paste reads `[file join $::env(HOME) .xschem .clipboard.sch]` and test_paste_at_log computes the same path; under a C-style fix plus a redirect they would read a stale file (INFERRED; both are non-scratch today, so they are not redirected).
* Crash corpses: B/C leave `_homeiso_<pid>` behind whenever a suite segfaults (the F14 suites; MEASURED B 12, C 9). They are gitignored and swept after 300 s, like the existing scratch corpses.
* Any redirect must leave these alone, and all were MEASURED unchanged in C and R: the 38 scratch-sourcing suites that set ::USER_CONF_DIR themselves (for example test_ase_simreg_0931, test_ase_simdlg_0937, the nh_editor family, test_op_param_store_1245, test_lib_new_path_guards_0799), which override after sourcing; test_sim_registry_isolate (1377); test_suite_watchdog_1403 (W12a scratch cleanup); and test_scratch's pid-qualified names, since the new dirs use the `_<tag>_<pid>` shape the sweep already recognises.
* Side effects of this work, outside HOME. /tmp/xschem_emergencysave_* grew from about 125 to 220 during the sweeps: suites create them deliberately, and my timeout/killed runs added some. They are not attributable by name, so I left them. Killing my sweep's process group did NOT reach its `timeout` children, which run in their own process group; I killed those by pid, identified by HOME in /proc/<pid>/environ. No process of mine is left.

## redir.real_home_check

`md5sum -c --quiet .../scratchpad/xschem_manifest_fixes.md5` gave rc=0 before any work, after the build, after each sweep phase, and at the end (01:05). `find /home/analog/.xschem -newer <manifest>` printed nothing. The newest /tmp/Xschem.log* is Xschem.log.4 from 09-17 23:35, so no interactive session was started during this work. Every xschem, ngspice, Xvfb and openbox run used HOME under /var/tmp/xschem_fixes/s2a_redirect/. Headless runs had DISPLAY unset. GUI runs used only my private :187, :188 and :189, now stopped. :99, devdisplay.sh, ~/.claude/xschem_dev_display, ~/.claude/gui_test_gate and ~/dev/xschem-op-wcard were not touched. The real repo's working tree was only read and cloned from. Nothing was committed. The scratch dir is left for the driver: /var/tmp/xschem_fixes/s2a_redirect, 2.8 GB, containing clone (baseline), clonb (B), clonc (C), clonr (R), patches/, runs/, tools/, and seeds seed, seed_empty and seedreg.

# 3. Critic

## crit.missed

* CWD-RELATIVE WRITES ARE NOT MOVED BY A HOME SWITCH, and neither study scopes them. Two sources:
- The product's project tier: `conf_path project` is `[file join [pwd] .xschem op_param_lists.conf]` (READ). The comment in test_op_param_store_1245.tcl CT1..CT3 records a probe run with cwd=$HOME that 'wrote synthetic rows into /home/analog/.xschem/op_param_lists.conf'.
- Suites drop untitled~.sch into the cwd.
MEASURED: this repo's root already has an untracked `.xschem/op_param_lists.conf` (2026-09-09), and my own runs left `untitled~.sch` in my clone's root.
So a stranger who runs the bare command from $HOME (test_launch_context.tcl's header says '(any cwd)') writes their real home whatever HOME says. Also, the checkout itself normally sits UNDER the real HOME, so D3's 'touches nothing under the tester's real HOME' has to be defined as 'outside the checkout'. The canary should add a cwd=$HOME shape.
* THE DOCUMENTED SINGLE-CASE COMMAND STAYS UNPROTECTED. CLAUDE.md says 'To run one case, source its script directly (e.g. tclsh netlisting.tcl)'. create_save.tcl, open_close.tcl and netlisting.tcl all `source test_utility.tcl` (READ). But the design calls t1_arm_home only from run_regression.tcl. That is the exact command F10's verifier used to evict all of a user's Open Recent entries through a PATH upstream binary.
Arming at source time in test_utility.tcl, idempotent and aware of nesting, would cover it. Then every tclsh probe in 1476 that sources UTIL_PATH also arms (nested under T1, but self-owned when 1476 is run bare), so decide this on purpose rather than by omission.
* THE GATE DIR IS CARRIED UNCONDITIONALLY, AND ONE ARM CREATES IT IN A STRANGER'S REAL HOME. xvfb_arm's fallback when xvfb-run is missing (`display arm: xvfb-run NOT FOUND -> falling back to inherited DISPLAY`) exports XSCHEM_XVFB_ARM=1 but NOT GUI_GATE=0 (READ; only the attach and private arms force it). On a desktop without xvfb installed, run_suites.sh or full_audit.sh therefore has the gate live. With GUI_GATE_DIR carried to $REAL/.claude/gui_test_gate, gui_gate.sh `mkdir -p "$GATE_DIR"` creates ~/.claude/gui_test_gate in the stranger's real HOME and launches a panel.
The S2c canary (DISPLAY unset) never sees this, and its carve-out names only xschem_dev_display.
Fix: carry GUI_GATE_DIR only if that directory already exists, the same rule the design applies to the devdisplay auto-start. Otherwise let it resolve inside the throwaway.
* THE SILENT-COVERAGE FAMILY IS LARGER THAN 1459/1452.
- test_vcd_read (A rows), test_vcd_time_base and test_ase_cosim REF12 read `$::env(HOME)/.xschem/simulations/counter.vcd` and `tb_counter_wrapper_ase.raw`, and skip quietly when those files are absent (READ).
- test_launch_context.tcl is 'DELIBERATELY NON-HERMETIC': it exists to catch a poisoned real ~/.xschem/geometry (issue 0001). Under a throwaway, full_audit and run_suites turn it into a pass that checks nothing.
- The suites' own self-protection checks also stop checking anything, because they now guard the throwaway: sigbrowser_i1315's raw_history teardown row, and the backup/restore in 0244 and 0185.
None of these is in T1, and the fixtures are absent on this box (MEASURED ls), so this is a full_audit/run_suites and developer-box concern. Give launch_context a copy of the real config through XSCHEM_TEST_REAL_HOME, and make the fixture rows print SKIP with a reason instead of passing without output.
* NGSPICE DOES WRITE TO HOME, JUST NOT IN BATCH MODE. The map's 'nothing written to HOME' holds only for -b.
- MEASURED on /usr/bin/ngspice 45.2 with a scratch HOME: `ngspice -p` created $HOME/.ngspice_history. Plain piped stdin and -b did not.
- The REAL home holds a 353 KB ~/.ngspice_history, last written 2026-09-13. Its tail is `help tf / help pss / help sp / help nosuchverb`, which look like capability-probe commands.
- I found no product or test code that uses -p (sim_probe_argv builds `-b`), so its origin is UNKNOWN.
Seed ~/.ngspice_history in the D3 canary, and do not claim that ngspice leaves HOME alone.
* THE HARNESS USES $HOME AS ITS 'NEVER A TEMP DIR' REFERENCE, AND A /tmp THROWAWAY INVERTS THAT.
- spawn_reaper.sh reaper_init accepts only `/tmp/?*|/var/tmp/?*|$TMPDIR/?*` prefixes. test_gui_gate_batch.sh row R8 `( reaper_init "$HOME" )` asserts the refusal, so it goes red whenever HOME is a throwaway (READ; today's drivers never reach it, because run_suites.sh runs only .tcl files).
- More important: spawn_reaper's deliberately unconditional read of `$HOME/.claude/xschem_dev_display/display` is the guard designed to survive a redirected XSCHEM_DEVDISPLAY_DIR (test_devdisplay.sh exports one for its whole run). Under a switched HOME, that half goes blind and only provenance protects the real :99.
It should read `${XSCHEM_TEST_REAL_HOME:-$HOME}`, and the design's guard row that greps for `$HOME/.claude` defaults should cover this.
* THE CANARY METHOD (D3) HAS HOLES.
(a) An md5sum -c manifest cannot see NEW files, such as ~/.cache/openbox, ~/.claude/*, a HOME-root probe .raw, .xschem_results_select_<pid> or a new op_annot/. The batch's own 27-file manifest has this hole, and the map's find -newer check covered 4 directories, not HOME's root. Use a full `find -printf '%p %y %s %T@'` before/after (test_wslg_health.sh DH34b already does this).
(b) Before/after snapshots miss transients, such as HOME-root probes created and then deleted, which a kill leaves behind. Reuse the redirect study's iwatch.py.
(c) With the canary as the parent HOME, the carried state dir is the canary's, which does not exist, so the developer's attach path is never exercised. Add a variant seeded with a state dir that points at a fixture Xvfb on DEVDISPLAY_NUM (not :99), and assert that the dcases ran and the state dir stayed byte-identical.
(d) MEASURED trap: `touch -d '2026-09-18 01:10'` here produced a reference of 2026-09-17 18:10 -0700, 7 hours off, and `find -newer` then flagged the user's 23:35 interactive edits as new. Use `touch -d @<epoch>` or a marker touched at start. Also, HOME's root mtime moves on every atomic rewrite of Claude Code's .claude.json (MEASURED 01:15:01), which is noise for any check against the real home.
* THE DESIGN SHAPE WAS NEVER SWEPT. Both T1 sweeps used an EMPTY home (template xschemrc copied) or a SEEDED copy. Neither used the shape that would ship: a pre-created empty .xschem, no template xschemrc, XDG_* redirected.
My spot-check in that shape (MEASURED): 11 hcases were identical to a lowercase control, as ALL PASS with the same counts (preflight, core, sp_1452, campaign_1462, converge_1459, variant_1470, simcaps_0948, options_1437, meas_1443, events_1465, signal_short_nohier_0230). HOME-derived simulations/ and op_annot/ were exercised.
The same run used a MIXED-CASE HOME (`xschem-test-home.4242.QmZxKe_<suite>`). That refutes, for HOME, the redirect study's inferred rule that 'a throwaway HOME must contain no uppercase letters'. It matters because the map's `mktemp ... XXXXXX` yields uppercase about 96% of the time. The rule came from a CHECKOUT-path measurement and stays true only there. S2c still owes the full 85-case run in the shipped shape.

## crit.design_risks

* CLEANUP OWNERSHIP AND NESTED-RUN DETECTION ARE THE DANGEROUS LINES.
- The cleanup rule `$$ == owner or $PPID == owner` lets ANY direct child of the owner that sources the helper delete the live throwaway. None does today (READ: the three drivers never call each other), but the rule turns a harmless future `run_suites.sh` call from full_audit into every later xschem start exiting 1 with 'failure creating'.
- XSCHEM_TEST_REAL_HOME carries a path AND serves as the 'already nested' marker. Any process that inherits it is treated as nested and reuses the current HOME, which may already have been deleted.
- The two studies disagree on names. The map's marker is XSCHEM_TEST_REAL_HOME; R's is XSCHEM_TEST_HOME_ISOLATED; B's opt-out placeholder is `XSCHEM_TEST_REAL_HOME=1`. Merged loosely, `=1` reads as nested: HOME stays real and unprotected, and the carried paths become the relative `1/.claude/...`.
Require all of the following:
- Treat a run as nested only if HOME is an existing directory matching the throwaway pattern whose owner pid is alive.
- Give the xvfb-run re-exec an explicit cleaner token.
- rm only the exact path that was created, and refuse if it equals the real home or is not under the temp root.
- If mktemp fails, refuse; never fall back to the real HOME.
- Guard against an unset or empty HOME: Tcl `$::env(HOME)` throws, and xinit.c maps "" to a /.xschem that cannot be created.
* LONG-LIVED PROCESSES STARTED AFTER THE SWITCH INHERIT A HOME THAT WILL BE DELETED. The design keeps the `$dd start` auto-start whenever the carried state dir exists. That is the developer's normal state after a reboot: the state dir exists and :99 is free.
So T1 would launch the PERSISTENT Xvfb and openbox with HOME=throwaway and XDG_CACHE_HOME=throwaway/.cache, and delete that home when it finishes. That is exactly the shape of today's measured orphan (HOME=/var/tmp/.../home_t1, deleted). The only difference is that the state dir would now identify it.
`_gate_ensure_widget`'s `setsid wish` panel, shared and outliving the driver, has the same problem.
Start both with the environment from before the switch (`env HOME=$REAL` plus the original XDG_* values).
* EXPORTING XDG_* PROCESS-WIDE SPLITS EVERY PER-SUITE HOME SWITCH. These set HOME for children:
- test_recent_launchlog.sh, 12 children
- test_flylines.sh
- test_wslg_health.sh
- sim_probe, startup_guard_0663, wave_sigbrowser_i1315
- simreg, simdlg, predeck, op_param_store
Those children then get HOME=<the suite's fake> but XDG_*=<the driver's throwaway>. That is safe for the user, but it changes what those suites measure.
On this box every XDG_*_HOME is unset (MEASURED). So: repoint an XDG var only if it was already set, and otherwise leave it unset so it keeps following each HOME.
* THE NEW PRIVATE-XVFB FALLBACK FOR T1 NEEDS MORE CARE.
- 'Started as xvfb_arm does' means `xvfb-run -a`, which numbers from :99. That collides with devdisplay (F36/0956), and two concurrent T1s can race for one number. Use `Xvfb -displayfd`, or numbers of 100 and up.
- Record its pid in the throwaway so the sweep for dead owners can kill it. Otherwise a killed T1 leaks an Xvfb plus openbox, which is F36 again.
- Set DISPLAY per exec, not as ::env(DISPLAY). hcases spawn children without --nogui (test_no_untitled_litter).
- This turns today's 11 uncounted NODISPLAY lines into 11 counted runs on an arm this box has never gated. The baseline is ZERO, so it must be measured green before it lands.
* WHERE THE THROWAWAY LIVES. `${TMPDIR:-/tmp}` can sit inside the real HOME; a TMPDIR under $HOME is common on HPC. Check that the result is outside it.
On this box /tmp is a 7.7 GB RAM tmpfs, and ase::rundir falls back to `[set_netlist_dir 0]`, which is $HOME/.xschem/simulations. The real one holds a 139 MB raw, and full_audit is unmeasured.
The sweep must also filter by uid, not only by pattern.
* GIT SAFE.DIRECTORY. Rather than carrying GIT_CONFIG_GLOBAL, which imports the user's config and breaks hermeticity, pass `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=<repo root>`. That is command-scope config, so it is protected and trusted. It closes the other-uid CI case without importing anything. actions/checkout-style CI writes safe.directory into the global config (INFERRED).
* THE NEW HEADER FIELDS ARE USER-CONTROLLED. `home=` (through XSCHEM_TEST_HOME=<dir>) and `binary=` (through XSCHEM) take user-supplied values, so 1476 V4a's 'the sentinels can never match a counted shape' now depends on field order. Keep canonical= last, or sanitise the values.
* WHAT THE DONE-CRITERION CAN PROVE HERE. 'The developer keeps :99' can only be proved on a fixture display on this box. :99 is held by the audit's orphan (Xvfb 1209045, which I confirmed is still alive), and crews may not touch it. The F-stage gate will show the private fallback (or NODISPLAY), never an attach to :99, until the driver deals with that orphan.

## crit.verdict

The two studies hold up, and nothing I measured refutes the core design: switch HOME for the whole driver process, pre-create $HOME/.xschem, and carry the harness paths explicitly. I spot-checked the map's claims and they match the code: T1's driver files have no reference to HOME, the only C fallback that reads the passwd home is when HOME is unset, and the gate panel takes its dir from argv.

What they missed, in order of harm:
1. The cleanup and nesting rules as written can delete a live throwaway, or silently reuse the real or a deleted HOME. The marker names also disagree between the two studies, including XSCHEM_TEST_REAL_HOME=1 being B's opt-out.
2. Long-lived processes started after the switch inherit a HOME that gets deleted: the auto-started persistent :99 and openbox, and the shared gate panel. That recreates today's orphan shape.
3. The gate dir is carried unconditionally, and xvfb_arm's fallback when xvfb-run is missing leaves the gate live. Together they create ~/.claude/gui_test_gate in a stranger's real home.
4. `cd tests && tclsh netlisting.tcl` stays unprotected, and that is the command F10 was measured with.
5. Writes relative to the cwd (the op_param project tier, untitled~.sch) are not moved by HOME at all.
6. The D3 canary method cannot see new files, transients or the attach path. A wall-clock `touch -d` reference was 7 hours off here.
7. Silent coverage loss is wider than 1459/1452, and test_launch_context becomes a pass that checks nothing.
8. ngspice -p writes ~/.ngspice_history.

I also measured two things. In the design's actual shape (pre-created empty .xschem, no template xschemrc) with a MIXED-CASE HOME, 11 hcases were identical to a lowercase control. So mktemp's uppercase suffix is fine, and the redirect study's 'HOME must be lowercase' does not hold for HOME. The full 85-case run in the shipped shape is still owed by S2c.

Real home: `md5sum -c` returned rc=0 before and after. find -newer against a marker set at 01:05 found nothing new except HOME's root mtime, which is Claude Code's own .claude.json rewrite at 01:15:01. The newest /tmp/Xschem.log* is .4 from 23:35. I never touched :99, the devdisplay state dir or the gate dir. No processes are left, and nothing was committed.

My scratch is /var/tmp/xschem_fixes/s2a_critic (415 MB): a clone at 4b9565ad, built; run1.sh; results.txt; out/; homes/; ngh_* for the ngspice history test.

