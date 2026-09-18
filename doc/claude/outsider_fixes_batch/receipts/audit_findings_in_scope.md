# Audit findings in scope for this batch

Extracted verbatim from the outsider-experience audit (47 agents, 2026-09-17/18). Each finding
is the merged statement plus every adversarial verifier vote, including corrections. Treat the
corrections as authoritative where they narrow a claim. Status tags: MEASURED/READ/INFERRED.

## FIX 1 -- the issue-stamp checker (and git-dependent suites)

### F23 [medium/FALSE_TEST_RESULT/MEASURED] -- T1 fails unless the checkout folder is named exactly `xschem-claude` (test_issue_stamp row S20)

**Who hits it:** Anyone who clones into another folder name (`git clone <url> xschem`, a second checkout, a CI workspace), and every ZIP download, which unpacks as xschem-claude-fluid-editing. A default `git clone` of github.com/ananthchellappa/xschem-claude passes by coincidence.

**What happens:** S20 checks that the issue-stamp checker finds the repo from its own location, by comparing the repo folder's basename with the literal `xschem-claude`. Any other name gives `RESULT: 1 FAILED (50 passed)`, rc 1, and 2 counted T1 failures against the ZERO baseline.

**Evidence:** MEASURED in clones named repo, clone, clone3, full, shallow and repo2, e.g. `got: 1 repo / want: 1 xschem-claude / S20 the repo is derived from the CHECKER's own location, not the caller's script : FAIL`. Code (verified): tests/headless/test_issue_stamp.tcl expects `{1 xschem-claude}` from `puts [file tail $istamp::repo]`.

**Known issue:** None found. Related to the all-decimal HEAD coin-flip in the same suite that CLAUDE.md documents.

**Verification:** REFUTED

- REFUTE: F23 corrected (medium, FALSE_TEST_RESULT, MEASURED): In any git clone of fluid-editing whose folder is not named exactly `xschem-claude`, T1 goes red. That covers `git clone <url> xschem`, a second clone or worktree, and a CI workspace named after the job; a default GitHub Actions checkout is named after the repo and passes. The cause is test_issue_stamp row S20, which compares `file tail $istamp::repo` with the literal `xschem-claude`: the suite reports `RESULT: 1 FAILED (50 passed)` with rc 1, and T1 counts 2 failures against its ZERO baseline (the S20 FAIL line and the HARNESS line). It is a false red, because the checker did find the right repo (rev_exists = 1). A default `git clone` from GitHub passes only because the folder name happens to match. A ZIP download is NOT an instance of this defect: with no .git, test_issue_stamp fails whatever the folder is called, including `xschem-claude`. S0, S15 and S15c FAIL on an unresolvable HEAD, then S20's driver script errors (`wrong # args: should be "istamp::rev_exists rev"`, Line No 436). The suite aborts mid-script with rc 0, leaves tests/headless/.scratch/drv_<pid>, and counts 4 failures. File that separately as "test_issue_stamp dies without .git".

### F24 [medium/FALSE_TEST_RESULT/MEASURED] -- In a shallow clone (depth 1, the CI checkout default), the issue-stamp gate goes red because stamped revisions are missing from history

**Who hits it:** Anyone who clones with --depth 1, including the default actions/checkout in CI, and runs T1 or test_issue_stamp.

**What happens:** Row D9 ("the gate is GREEN on the real corpus as it stands today") gets `got: 10 want: 0`: issues 0056, 0216, 0249, 0442, 0650, 0891, 0905, 1219, 1438 and 1458 report `tree=61af3692 does not resolve to a commit in this repo`. Shallow-clone T1: counted_failures=11 (8 segfaults, S20, D9, and the harness line). The ASE suites that use `git ls-files` work in a shallow clone.

**Evidence:** MEASURED: build shallow/tests/results.237853.log and logs/shallow_stamp_xschem.out. fresh_t1 ran a depth-1 clone named xschem-claude: `RESULT: 1 FAILED (50 passed)`, row D9. static: `D9 ... got: 10 want: 0 : FAIL`.

**Known issue:** None found (grep for shallow clone or --depth 1).

**Verification:** not independently verified

### F21 [high/FALSE_TEST_RESULT/MEASURED] -- A GitHub 'Download ZIP' (no .git) turns about 10 T1 cases red: suites read their corpus through git, and git's error text is used as a file path

**Who hits it:** Anyone who does what the user literally described: downloads the repo (GitHub Download ZIP, a release tarball, any `git archive` export) rather than cloning, builds it, and runs T1.

**What happens:** configure and make succeed. T1 then goes red in at least 10 cases that call `git ls-files` or `git rev-parse` and treat git's error output as data. test_ase_trnoise_1466 and test_ase_variant_1470 abort at load with `couldn't open ".../fatal: not a git repository ..."`. test_ase_core fails CP1-CP4 and CP7, then dies with `couldn't open "GIT-LS-FILES-FAILED"`. Also red: test_ase_options_1437 DL5 and test_ase_predeck_1439 RD10 (`RAISED:fatal: not a git repository`), test_ase_simcaps_0948 W6, test_ase_sp_1452 SC1, test_ase_trnoise_gui_1467 N0, and test_ase_simwin_variant_1471 ST1 (state_roundtrip.tcl parsing git's error text). test_issue_stamp fails S0/S15/S15c, then dies with `wrong # args: should be "istamp::rev_exists rev"`. Nothing says 'this needs a git checkout', and the run exits 0. The ZIP folder name also trips F23, and a long extract path can trip F26. Git calls in T1 suites are read-only, so a ZIP extracted inside some other repo would read that repo without modifying it.

**Evidence:** MEASURED, two full T1 runs in `git archive` exports: fresh_t1 `T1-RUN-END pid=500610 cases=85 blocks=84 counted_failures=34` (15 cases, including the 4 F14 segfaults, the N9 path row and the F25 race); build `counted_failures=32` (8 segfault + 24 git; build/export/tests/results.237807.log). Per-suite control (static): the same 5 suites in a git clone give ALL PASS (675/75/211/78/58 checks). Code: tests/headless/test_ase_simcaps_0948.tcl `if {[catch {exec git -C $repo ls-files -- *.state} W_OUT]} { set W_OUT {} }`; test_ase_core `set CPF {GIT-LS-FILES-FAILED}`. Non-T1 suites that git-init their own repos pass in the export.

**Known issue:** None found (grep for not a git repository, git archive, tarball, ZIP download).

**Verification:** CONFIRMED

- uphold: Refinement, not a refutation. A no-.git export (Download ZIP or git archive) builds cleanly, but all 10 named T1 cases fail under T1's own scoring, each through a git call that fails. Measured on a fresh-HOME setup, 8 of them go from green to red purely because .git is missing: trnoise_1466, simcaps_0948, options_1437, predeck_1439, trnoise_gui_1467, simwin_variant_1471, ase_core and issue_stamp (issue_stamp only for a checkout folder named xschem-claude, since S20 hard-codes that name, which is F23). variant_1470 (OT1) and sp_1452 (SE1/apt and SE1/fork2) were already red for reasons unrelated to git in a fresh-HOME git clone. In the export, git adds a load abort to variant_1470 and the SC1 failure to sp_1452. How each suite fails varies: state_roundtrip.tcl treats git's error text as a file path, test_ase_core uses the sentinel 'GIT-LS-FILES-FAILED' as a path, simcaps and sp read an empty corpus so their count checks fail, options and predeck raise the git error from inside the check, and issue_stamp ends up with an empty revision. Severity high, as a false red for everyone who downloads rather than clones.

- uphold: Confirmed, with two details sharpened. A GitHub "Download ZIP", a release tarball or a `git archive` export (anything without .git) builds cleanly. T1 in it then exits 0 with exactly 10 cases red and 24 counted failures, all caused by suites that list their corpus through `git ls-files` or `git rev-parse` and treat git's error text as data. Measured: counted_failures=33 over 85 cases. The other 9 failures come from create_save and 4 F14 segfaults.

The 10 cases: test_ase_core fails CP1, CP2, CP3, CP4 and CP7, then dies with `couldn't open "GIT-LS-FILES-FAILED"`. test_ase_options_1437 DL5 and test_ase_predeck_1439 RD10 fail with `RAISED:fatal: not a git repository`. test_ase_simcaps_0948 W6 fails as `{0}`, with the git error silently swallowed. test_ase_sp_1452 SC1 fails. test_ase_trnoise_gui_1467 N0 fails. test_ase_simwin_variant_1471 ST1 fails. test_ase_trnoise_1466 and test_ase_variant_1470 die late in the script, not at load: after 58 and 75 passing checks, at lines 957 and 1078, with `couldn't open "<repo>/fatal: not a git repository ..."`. Both exit 0 and are counted only because the completion banner is missing. test_issue_stamp fails S0, S15 and S15c, then dies at S20 with `wrong # args: should be "istamp::rev_exists rev"`.

In a git clone of the same commit, 9 of the 10 pass. test_issue_stamp still fails S20 there, but only because of the folder name (F23), not git. No suite checks for a checkout, and no doc states the requirement. git's own `not a git repository` text does show inside three of the failing rows. All git calls in these suites are read-only.

## FIX 2 -- tests touch the real HOME

### F6 [high/DESTROYS_USER_DATA/MEASURED] -- T1 and several suites overwrite the user's persistent xschem clipboard (~/.xschem/.clipboard.sch)

**Who hits it:** Every stranger who runs T1, full_audit.sh or these suites with their real HOME, headless or not. No driver redirects HOME: run_regression.tcl, run_suites.sh, full_audit.sh and xvfb_arm.sh have no HOME or USER_CONF_DIR override.

**What happens:** xschem keeps the Copy buffer across sessions in $USER_CONF_DIR/.clipboard.sch. clip_file is fixed in C at Tcl_AppInit, so a suite cannot redirect it. test_paste_modify_flag_0244, test_crossview_paste and test_shape_draw_gate (all T1 hcases), plus test_wave_markers, replace the user's last copy with test geometry, and the next Paste inserts test junk. test_schpins_stale_lab_0185 saves and restores an existing clipboard, but creates one where none existed.

**Evidence:** MEASURED (exist_t1): a seeded 1480 B clipboard (all of cmos_inv.sch, copied through the product, md5 00df822e…) became 220 B (md5 8e75f801…: `T {MERGEDTEXT} 800 800 ...`, `C {lab_pin.sym} 700 500 0 0 {name=m1 lab=MERGED}`) at 22:34:05.48, during test_paste_modify_flag_0244. MEASURED (ase_suites pass 4): a seeded `T {USER CLIPBOARD SENTINEL}` was replaced after each of the 4 suites. MEASURED per case (static): written by crossview_paste, paste_modify_flag_0244 and shape_draw_gate. Also measured in fresh-home T1 runs (fresh_t1, build) and in full_audit (harness). READ: src/xinit.c `my_snprintf(clip_file, S(clip_file), "%s/%s", user_conf_dir, ".clipboard.sch");`. test_paste_modify_flag_0244.tcl's own comment: "running this test OVERWRITES the developer's real ~/.xschem/.clipboard.sch. Unavoidable without launching under a redirected $HOME, which is a runner change".

**Known issue:** doc/claude/issues/0244 section 3 ("LOW — the clipboard is process-global and the test clobbers the developer's" clipboard; verified present). It names 0244, crossview_paste and paste_at_log, but not test_shape_draw_gate or test_wave_markers. No issue treats it as a hazard for strangers.

**Verification:** CONFIRMED

- uphold: F6 is confirmed as stated. Only the scope and a severity caveat need adding.

T1 overwrites the user's persistent xschem clipboard ($HOME/.xschem/.clipboard.sch) through three hcases: test_shape_draw_gate, test_crossview_paste and test_paste_modify_flag_0244. full_audit.sh overwrites it too, and so does any run of those suites. No driver redirects HOME, and clip_file is fixed in Tcl_AppInit, so it happens headless as well. The file is the same one an upstream xschem uses, so the stranger's next Paste in any xschem session inserts test geometry instead of what they copied.

MEASURED: a clipboard holding all of cmos_inv.sch (14 instances) pasted back as a single lab_pin plus one wire and one text.

The set of clobbering suites is larger than F6 lists. Also measured overwriting under full_audit's --logdir flags: test_wave_markers, test_save_reload_copy_selflog, test_selflog_grep_guard, test_actionlog_suppress_gate and test_placement_preview_doors. Unmeasured (they skip without Tk): test_paste_at_log and test_context_menu_log. test_schpins_stale_lab_0185 restores an existing clipboard but creates one where there was none.

Severity is high under the audit rubric because user data is changed. The caveat: the lost data is a copy buffer, not a design, and the pasted junk is visible. It is irrecoverable only when the copy came from a Cut whose source is gone. That is milder than the simulator-list class, and issue 0244 rates it LOW.

- uphold: Confirmed, with refinements:
- Any HOME-unredirected run writes $HOME/.xschem/.clipboard.sch, the same file an upstream xschem install uses: T1 (via test_shape_draw_gate, test_crossview_paste and test_paste_modify_flag_0244, all headless), full_audit.sh (by default every tests/headless/test_*.tcl, of which 14 call `xschem copy`/`cut`) and run_suites.sh on those suites. The user's next Ctrl+V or `xschem paste`, in a new or already-open session, inserts test content. After T1 that is 0244's `lab_pin name=m1 lab=MERGED`, a wire, a line and a MERGEDTEXT text.
- On the headless arm, test_wave_markers leaves an empty (header-only) clipboard rather than test geometry.
- test_schpins_stale_lab_0185 restores an existing clipboard and creates one where none existed.
- Severity: high under the rubric, since it changes the user's own persisted data, but the loss is limited to the copy buffer. It is permanent only when the buffer came from a Cut whose source was later saved. The pasted junk is visible, so no design is silently corrupted.

### F7 [high/CHANGES_USER_CONFIG/MEASURED] -- Test runs rewrite ~/.xschem/geometry and permanently evict the user's saved window positions

**Who hits it:** (a) Anyone who runs the documented T1 on a box with Xvfb installed and :99 free. T1 starts the display itself (F36), so its 11 display cases run with has_x=1. (b) Anyone who runs full_audit.sh or run_suites.sh, which use a private Xvfb but the real HOME. (c) Anyone who runs a GUI suite by hand on their desktop.

**What happens:** store_geom writes $USER_CONF_DIR/geometry on every GUI exit with no automation gate, and keeps only the 100 newest entries. Each test window therefore evicts one of the user's oldest entries. Measured through T1: 59 of 100 seeded entries evicted, replaced by test keys that include bare fixture names that can collide with the user's own (leaf.sch, mix.sch, nmpass.sch, bc_two.sch), shipped-example keys, and absolute paths into deleted scratch dirs. The untitled.sch entry was re-stamped. Measured through full_audit.sh: both of the user's 2 entries were lost, and the file held 101 lines of test paths. The headless (--nogui) arm wrote nothing to geometry.

**Evidence:** MEASURED (exist_t1): before=100, after=100, evicted=59, added=59. Deleted lines `myproj/cell_36.sch ...` through `myproj/cell_94.sch ...`; added lines include `bc_two.sch 1200x900+300+200 1789710014` and `/var/tmp/xschem_outsider_audit/exist_t1/clone/tests/headless/.scratch/_annot_stale_0684_341675/lib/mos.sch ...`. Writes per case: test_annot_stale_0684 16, test_op_annot 14, and 1 each for 5 more (home.writes.log). MEASURED (harness): `md5sum -c` gives `./.xschem/geometry: FAILED`; `grep -c stranger geometry` = 0 of 2; 101 lines (fa_seeded.out, SUMMARY 387 pass 13 fail). READ: src/xinit.c xwin_exit `if(has_x) tcleval("store_geom . [xschem get current_name]");`; src/xschem.tcl proc store_geom `if {$j >= 100} break   ;# cap the geometry history at the 100 most-recent files` (verified). INFERRED (ase_suites): 20 suites neither source scratch.tcl (whose __scratch_cleanup_all stubs store_geom) nor stub store_geom nor redirect USER_CONF_DIR. test_launch_context.tcl is "DELIBERATELY NON-HERMETIC".

**Known issue:** 1397 and 1458 (mechanism, measured on the developer's box with their own dev display). Not recorded: T1 starts the display itself, so a stranger gets this from the documented T1 command alone.

**Verification:** CONTESTED

- uphold: Refinement only; the claim is not refuted. Any GUI (has_x=1) suite run that uses the real HOME rewrites ~/.xschem/geometry. It writes on every GUI `xschem load` as well as on exit: 198 writes measured for test_op_annot alone. Three things follow:
1. Test keys are added: deleted scratch paths, shipped-example paths and bare fixture names.
2. Any user entry with the same key is overwritten with the test window's geometry.
3. Once the file passes the 100-entry cap this fork added, the user's oldest entries are evicted permanently: max(0, N + K − 100) of them, with K ≈ 49 for test_op_annot alone.

Headless (--nogui) runs write nothing. Who hits it:
- run_suites.sh and full_audit.sh with DISPLAY unset: MEASURED for run_suites.sh, READ for full_audit.sh.
- A documented T1 when Xvfb is installed and :99 is free: READ, not run, because T1 calls `devdisplay.sh start` itself.
- GUI suites run by hand: INFERRED.

The damage is lost or wrong remembered window positions. That counts as high under the rubric's "changes the user's own config" wording, but its practical effect is cosmetic. Separately, the same cap cuts an upstream-grown geometry file to 100 entries on the first plain GUI exit, with no tests involved.

- REFUTE: F7 [high by the rubric: user config entries are destroyed irrecoverably, though the practical effect is window size and position only; CHANGES_USER_CONFIG; MEASURED]: the documented T1 rewrites ~/.xschem/geometry, overwrites some of the user's saved window positions and, once the file is full, evicts others.

Who hits it:
(a) Anyone who runs `cd tests && tclsh run_regression.tcl` on a box with Xvfb installed and :99 free. T1 runs `devdisplay.sh start` itself, so its 11 display-arm cases run with has_x=1 under the real HOME.
(b) READ, not measured here: anyone who runs full_audit.sh or run_suites.sh. Both run GUI suites under the real HOME. If xvfb-run is missing, xvfb_arm.sh falls back to the inherited DISPLAY, so those suites also land on the user's real desktop, with or without Xvfb.
(c) Anyone who runs a GUI suite or an interactive xschem by hand.

Mechanism: store_geom (src/xschem.tcl) has no automation gate and keeps the 100 newest entries by timestamp. In T1 the writes come from the GUI `xschem load` path (scheduler.c: `if(has_x) tcleval("store_geom [xschem get topwindow] [xschem get current_name]")`) and from the window close/clear/destroy paths during each suite. They do not come from exit: scratch.tcl's wrapped `exit` stubs store_geom, and every display-arm suite sources scratch.tcl. The exit-time write in xwin_exit only reaches suites that do not source scratch.tcl, and bare sessions.

Every new test key pushes out the user's oldest entry once the file is at the 100-entry cap (evicted = max(0, N_user + new_keys - 100)). Keys that match bare fixture names are overwritten whatever the user's count.

Measured with 100 seeded entries:
- 57 user entries evicted, replaced by 57 test keys (bare fixture names, shipped-example keys, absolute paths into deleted scratch dirs).
- leaf.sch and mix.sch overwritten with the test geometry 1000x700+10+10.
- untitled.sch re-stamped.
- At least 92 writes, all from the display arm; the --nogui arms wrote none.

A user with fewer than about 40 entries loses none to a single T1 run, but still gets about 60 junk keys.

Side effect: T1 never stops the Xvfb and openbox it started.

### F8 [high/DESTROYS_USER_DATA/MEASURED] -- T1 writes clean.spice and short.spice into the user's default netlist folder, overwriting any same-named netlist of theirs

**Who hits it:** Every stranger who runs T1, full_audit.sh or test_signal_short_nohier_0230 with their real HOME. A user who already has ~/.xschem/simulations/clean.spice or short.spice loses it; everyone else gets two stray files.

**What happens:** The suite netlists two fixtures without redirecting netlist_dir, so both netlists land in $USER_CONF_DIR/simulations. These are the two files the developer found in their own ~/.xschem/simulations after T1. A user rc setting `netlist_dir` elsewhere did not redirect them, and the user's other netlists (cmos_inv.spice, mydesign.spice) were untouched.

**Evidence:** MEASURED (ase_suites pass 4): a pre-seeded user clean.spice (`* user netlist sentinel`) was replaced by `** sch_path: .../.scratch/_sigshort_0230_<pid>/clean.sch` / `**.subckt clean` / `R1 net1 net2 1k`. Created in every fresh-home T1 (fresh_t1, exist_t1, build) and in full_audit (harness). The suite run alone in an empty HOME created exactly these two files (fresh_t1). Code: tests/headless/test_signal_short_nohier_0230.tcl proc erc `eval [linsert $args 0 xschem netlist -erc -messages]`, and src/xschem.tcl `set_ne netlist_dir "$USER_CONF_DIR/simulations"`. Regraded from the investigators' LITTERS/medium: an overwrite of a user file was measured. It still needs a netlist with one of those two names.

**Known issue:** Not found in doc/claude/issues (grep for clean.spice/short.spice). The LEDGER notes agents overwriting ~/.xschem/simulations.

**Verification:** CONFIRMED

- uphold: I reproduced this myself, so it is MEASURED. I used my own fresh clone of fluid-editing at 5de2977d and built it with ./configure && make (rc 0). I ran the single suite the way T1 does: cwd tests/, in-tree binary, `../src/xschem --nogui --pipe -q --script headless/test_signal_short_nohier_0230.tcl`, with DISPLAY unset and HOME set to a scratch directory.

1. **Seeded home (homeA)**: I pre-seeded `~/.xschem/simulations/` with clean.spice (`* user netlist sentinel clean`), short.spice and cmos_inv.spice. The suite passed (ALL PASS, 11 checks, rc 0). Afterwards clean.spice and short.spice had been replaced in place by the fixtures' netlists, with no backup kept. cmos_inv.spice was untouched.

2. **Empty home (homeB)**: the only files created were `.xschem/xschemrc` and `.xschem/simulations/{clean,short}.spice`. The xschemrc is the stock template copy that any first xschem start makes, so it is not part of this defect. The finding's phrase "exactly these two files" is right if you set that template aside.

3. **Home with its own rc (homeC)**: I added `~/.xschem/xschemrc` with `set netlist_dir $env(HOME)/mynetlists`. The netlists still went to `~/.xschem/simulations`, and mynetlists stayed empty. The log shows only `Sourcing .../src/xschemrc init file`.

The mechanism is right, and one detail is sharper than the finding states: the in-tree binary never reads the user's ~/.xschem/xschemrc at all.
- In src/xinit.c `Tcl_AppInit`, running_in_src_dir is set to 1 when XSCHEM_SHAREDIR holds xschem.tcl, systemlib and xschem. That is always true for src/xschem.
- The user rc is sourced only inside `if(!running_in_src_dir) { ... look for (user_conf_dir)/xschemrc }`, so an in-tree run skips it.
- src/xschem.tcl then applies `set_ne netlist_dir "$USER_CONF_DIR/simulations"`. src/xschemrc has `# set netlist_dir ...` and `# set local_netlist_dir 1` commented out.
- In src/scheduler.c, the `netlist` branch calls `set_netlist_dir(0, NULL)` and, with no file name given, writes `$netlist_dir/<cell>.spice`.
- The suite's `proc erc` runs `eval [linsert $args 0 xschem netlist -erc -messages]` with no file name.
- The suite's cleanup `catch {file delete -force $dir}` removes only the .scratch fixture directory, not the netlists.

Scope is also right (READ, not run end to end by me):
- run_regression.tcl lists "headless/test_signal_short_nohier_0230" in hcases and runs it the way I did.
- full_audit.sh runs every tests/headless/test_*.tcl via `ls "$HERE"/test_*.tcl`.
- Neither run_regression.tcl, full_audit.sh, run_suites.sh nor xvfb_arm.sh redirects HOME or netlist_dir. The only HOME reference among them is xvfb_arm.sh's dev-display state file.

Not filed: no issue .md mentions clean.spice, short.spice or this suite's netlist output.

Severity: I tried to knock it down and could not under the stated rubric. A same-named file of the user's is silently replaced, and the user's own netlist_dir setting does not protect them. Two caveats, stated plainly:
- It happens only when the user has a cell named `clean` or `short` netlisted into that folder.
- A netlist there is normally a generated file that xschem rewrites on every Netlist press. Re-netlisting restores it, unless it was hand-edited or its schematic no longer exists. I did not measure whether a later Simulate without re-netlisting would run the wrong circuit (UNKNOWN).

For everyone else the effect is two stray files (medium, litter).

- uphold: Refinement, not a refutation. F8 is confirmed as stated (MEASURED), with these precisions:

- The in-tree binary that T1, full_audit.sh and the suite's own documented command all use never reads ~/.xschem/xschemrc (src/xinit.c, `if(!running_in_src_dir)`). So neither the user's netlist_dir nor their local_netlist_dir can redirect it, and clean.spice and short.spice always land in $HOME/.xschem/simulations.
- If the stranger points $XSCHEM at an installed binary, the user rc is read. The two netlists then land in the user's own configured netlist_dir, which could be a project directory. With local_netlist_dir set, they land harmlessly in the scratch dir instead. This part is READ/INFERRED, not measured.
- Severity: high by the rubric when a clean.spice or short.spice already exists. That file is a regenerable netlist, and xschem itself overwrites it on any netlist of a same-named cell. For everyone else the effect is two stray files, which is medium litter.

### F10 [high/CHANGES_USER_CONFIG/READ] -- If src/xschem is not built, T1 silently runs whatever `xschem` is on PATH against the user's real ~/.xschem

**Who hits it:** A stranger with upstream xschem installed who runs T1 before `make`, after `make clean`, or after a failed build.

**What happens:** test_utility.tcl starts from the bare name `xschem` and switches to the in-tree binary only if it is executable. run_regression.tcl never prints which binary ran. An upstream build that predates this fork's 0119 gate (no no_recent_files) is the route by which issue 0924 emptied File > Open Recent. full_audit.sh, by contrast, refuses with a FATAL. Not run: no upstream install exists on this box. Whether a current upstream still rewrites recent_files under --pipe is UNKNOWN. The product investigator measured that plain recent_files round trips between the fork and three upstream versions are lossless (F11).

**Evidence:** READ: tests/test_utility.tcl `set xschem_cmd "xschem"` ... `if {[file executable $_xs_tree]} { set xschem_cmd $_xs_tree }`. run_regression.tcl uses `$xschem_cmd` in the hcases, display-arm and xschemtest commands and never prints it. full_audit.sh: `FATAL: xschem binary not found/executable at: $XSCHEM`. Regraded from medium (all three investigators) to the rule's high for the damage class. The concrete change is not measured.

**Known issue:** 0147 (fallback order) and 0924 (a stock xschem emptied Open Recent; fixed only for this fork's binary). CLAUDE.md warns about it.

**Verification:** CONFIRMED

- uphold: I could not refute F10. I reproduced it with a real upstream xschem, one T1 case at a time, in my own clone with a scratch HOME and DISPLAY unset.

Setup:
- Built stock upstream xschem at f276d0cf. That is the last Stefan Schippers commit in this repo's history (2026-05-27, reports "XSCHEM V3.4.8RC").
- Installed it into a scratch prefix and put that prefix first on PATH.
- Left the fluid-editing clone unbuilt, so src/xschem is absent. That is the stranger's state before `make`. It is also the state after `make clean`: src/Makefile.in's `clean:` rule runs `rm -rf rawtovcd xschem *.o ...`.

What I confirmed:
1. Binary resolution (READ + MEASURED). tests/test_utility.tcl sets `set xschem_cmd "xschem"` and replaces it only if `[file executable $_xs_tree]`. With $XSCHEM unset it printed `xschem_cmd=<xschem>`, which resolved to the upstream binary on PATH.
2. No home redirection (READ). Neither run_regression.tcl nor test_utility.tcl sets HOME or USER_CONF_DIR, so every case runs against the user's own ~/.xschem.
3. Nothing names the binary (READ). run_regression.tcl prints only Start/Finish lines. summarize_all copies into results.log only lines matching FAIL$ / GOLD?$ / RESULT?$ / ^FATAL / ^(NOGOLD|NODISPLAY). The T1-RUN-BEGIN header has pid, script, start, planned_cases, verdict and canonical, but no binary.
4. The damage (MEASURED). I ran one real T1 case the way T1 runs it: `tclsh netlisting.tcl` with T1_LOG_TAG set. It ran 728 upstream spawns in 22 s, rc 0, and printed only "No gold folder" (NOGOLD, not counted). Afterwards the scratch ~/.xschem/recent_files had lost all 3 of the user's entries. It now held 10 test-library schematics (xTAG-*.sch, dti_*.sch, xschem_simulator/*.sch).
5. The headless cases do it too (MEASURED). I ran hilight_hier_oracle exactly as T1 builds it: `xschem --nogui --pipe -q --script hilight_hier_oracle.tcl`. It added tests/hilight_xwin_sync/parent.sch to the top of the same list.
6. This settles the finding's open UNKNOWN about current upstream. READ at f276d0cf:
   - src/xschem.tcl has 0 occurrences of no_recent_files/norecent.
   - `proc update_recent_file` always calls `write_recent_file`, which does `open $USER_CONF_DIR/recent_files w`.
   - src/xinit.c calls `update_recent_file` after every command-line file load, with no gate.
   So a 2026 upstream still overwrites the list under --nogui --pipe. The "route of issue 0924" wording holds in substance, but the mechanism here is different. 0924 was a spelling mismatch that emptied the list. Here the test loads push the user's entries out of the 10-slot list. The end result is the same: the user's entries are gone.
7. Contrast (READ). tests/headless/full_audit.sh and run_suites.sh default to `XSCHEM="${XSCHEM:-$REPO/src/xschem}"`. full_audit.sh refuses with `FATAL: xschem binary not found/executable at: $XSCHEM`.

Refinements. None changes the verdict or the high severity; they sharpen the wording.
(a) "Silently" is about the binary and the config damage, not the verdict. With upstream, T1 would be loudly red: hilight_hier_oracle printed 7 FAILs and test_ase_preflight exited rc 1 with `invalid command name "ase::preflight_idents"` failures. Nothing tells the stranger why. Some cases even "pass": test_fluid_editing printed `RESULT: SKIP (no X)` / `OVERALL: ok`.
(b) Only the per-case logs happen to reveal the binary, through upstream's `Using run time directory XSCHEM_SHAREDIR = <upstream prefix>` line. results.log does not.
(c) A worse aggravation, MEASURED in part: upstream does not know the fork's `--nogui` flag and prints `Unknown option: nogui`. Upstream's flag is `--no_x` (options.c). It is INFERRED, not measured (I ran with DISPLAY unset, per the rules), that on a stranger's normal desktop, with DISPLAY set, the upstream binary would map real windows for hcases and tcases and might write more of ~/.xschem.
(d) The consequence requires a PATH xschem with no recent-files gate. Every upstream I checked has none: 3.4.6 per issue 0924, and 3.4.8RC at f276d0cf here. A distro-packaged xschem is INFERRED to be the same.

Severity: high under the rubric, because it changes the user's own config. The change is now MEASURED: all of the user's Open Recent entries replaced after a single T1 case.

- uphold: If src/xschem does not exist (never built, after `make clean`, or after a failed build), `cd tests && tclsh run_regression.tcl` runs whatever `xschem` is on PATH, with the user's real HOME, and never says which binary ran.

No upstream xschem has this fork's no_recent_files gate (checked 2023-10, 2025-03 and 2026-05 V3.4.8RC). Upstream calls update_recent_file on every command-line or `xschem load` open, even under --nogui, and caps the list at 10.

So the run replaces the user's whole File > Open Recent list with test and scratch schematics. Measured: 10 of 10 user entries evicted, in a scratch HOME.

The verdict is a massive red (822 counted failures over 85 cases, rc 0). It reads like product failures and gives no hint that the wrong binary ran. The Open Recent damage itself is silent. Severity stays high: the run changes the user's own config (their Open Recent history, not their designs).

full_audit.sh and run_suites.sh refuse in the same situation with a FATAL. T1 is the only harness that falls back to PATH.

### F25 [medium/FALSE_TEST_RESULT/MEASURED] -- First run on a fresh account: parallel xschem starts race to create ~/.xschem, and the losers exit, giving a phantom create_save FATAL

**Who hits it:** A new user with no ~/.xschem on their first T1 run (create_save is T1's first case and runs 5 jobs on a 16-worker pool), and anyone who starts two xschem processes at once on first use.

**What happens:** Tcl_AppInit checks with stat() and then mkdir()s. A process that loses the race gets EEXIST, prints `Tcl_AppInit(): failure creating <home>/.xschem` and exits 1. In the ZIP-tree run create_save reported `FATAL: 1` for exactly this. The next run cannot reproduce it, because ~/.xschem now exists: a first-run-only flake that looks like a real failure.

**Evidence:** MEASURED: tests/create_save/results/0_examples_top_debug.txt (ZIP run) ends `Tcl_AppInit(): failure creating /var/tmp/xschem_outsider_audit/fresh_t1/home_zip/.xschem` / `tclexit() INVOKED`. 15 batches of 16 simultaneous starts on an empty HOME: 15 of 240 exited rc 1, all with `failure creating`. Code: src/xinit.c Tcl_AppInit `if(stat(user_conf_dir, &buf)) { if(!mkdir(user_conf_dir, 0700)) {...} else { fprintf(errfp, "Tcl_AppInit(): failure creating %s\n", user_conf_dir); Tcl_Exit(EXIT_FAILURE);` (upstream since 5e8df730, 2020).

**Known issue:** Not filed (grep for 'failure creating').

**Verification:** not independently verified

### F36 [medium/LITTERS/MEASURED] -- T1 silently starts a persistent Xvfb :99 plus openbox, never stops them, and creates ~/.claude/xschem_dev_display and ~/.cache/openbox in the user's HOME

**Who hits it:** Anyone with Xvfb installed who runs the documented T1 while :99 is free, including from a desktop terminal and including people who have never used Claude Code. A user or CI job that owns :99 instead gets F28.

**What happens:** The display arm runs `catch {exec $dd start 2>@1}` (devdisplay.sh) and discards the output, so T1's stdout never mentions it. cmd_start does `mkdir -p "$STATE_DIR"` (default $HOME/.claude/xschem_dev_display), launches `Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &` and openbox, and exits. The children are reparented to init and outlive T1 until reboot, because no code path calls `$dd stop`. Later full_audit/run_suites runs quietly attach to that display. If the user's own server on :99 takes more than 5 s to answer, cmd_start deletes its /tmp/.X99-lock and starts a competing Xvfb. `xvfb-run -a` in the audit drivers also starts numbering at 99, so the two paths collide. During this audit a peer investigator's T1 took the developer's :99 this way (the developer's own dev display had died at reboot), and that contaminated two other peers' display-arm results.

**Evidence:** MEASURED (exist_t1): `ps` 19 s after T1 ended showed `325098 ppid 843(/init) Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp` and `325152 ppid 843 openbox`, both with HOME=<scratch> in /proc/<pid>/environ. New files: .claude/xschem_dev_display/{display,screen,wm,wm.pid,xvfb.pid} and .cache/openbox/{openbox.log,sessions}. All 11 display cases ran: 0 NODISPLAY, 85/85 Start/Finish. Observed independently by harness via ps and /proc. READ: tests/run_regression.tcl `catch {exec $dd start 2>@1}` (verified; no `$dd stop`); tests/headless/devdisplay.sh `STATE_DIR="${XSCHEM_DEVDISPLAY_DIR:-$HOME/.claude/xschem_dev_display}"`; the lock deletion is guarded by `timeout 5 xdpyinfo`.

**Known issue:** 0891 (FIXED; its RULING records the auto-start, and its text says "nothing ever takes it down — the display is left up", verified). 0956 (OPEN: start deletes a slow server's lock). 1481 wrongly assumes a fresh box has no dev display. None of these frames it as a hazard for strangers.

**Verification:** not independently verified

### F39 [medium/LITTERS/MEASURED] -- T1 and the audit drivers leave other files in the user's HOME: a template xschemrc, an empty op_annot/, a stray probe .raw at $HOME's root, and openbox's cache

**Who hits it:** Every stranger who runs T1 or the drivers with their real HOME.

**What happens:** From an empty home, one T1 run created ~/.xschem/xschemrc (34595 B, a copy of src/xschemrc; upstream does this too), ~/.xschem/op_annot/ (empty; from test_ase_core, test_ase_optier_0963 and test_unused_attr_0970), and ~/.xschem/simulations/. Besides these, it created the clipboard (F6) and the netlists (F8). test_op_annot drops `opannot0812probe_<pid>.raw` at the root of $HOME, which stays behind if the run is killed. Every private-Xvfb run starts openbox with the user's HOME, creating ~/.cache/openbox/openbox.log and sessions/. A display-less T1 created no ~/.claude, ~/.config or ~/.cache.

**Evidence:** MEASURED: `find home -printf` after fresh_t1 run A (4 files and 3 dirs, 64K); identical listings in build's home_t1_shallow and home_t1_export; per-case scratch HOMEs (static): all 70 hcases create .xschem/xschemrc, and op_annot/ comes from the three named suites. harness: home*/.cache/openbox/openbox.log. READ: test_op_annot.tcl `set Z_HRAW  [file join $::env(HOME) $Z_HNAME]`.

**Known issue:** Same family as 1377, 1397/1458 and 0119. Not filed individually.

**Verification:** not independently verified

### F28 [medium/FALSE_TEST_RESULT/MEASURED] -- Without a working dev display, T1's 11 display cases verify nothing and are scored uncounted; with the 3 NOGOLD cases, 14 of 85 cases verify nothing and the failure reason is swallowed

**Who hits it:** Any stranger without Xvfb; anyone whose :99 is already taken (a CI job wrapping T1 in `xvfb-run`, whose SERVERNUM defaults to 99, or a display left behind by an earlier T1, see F36); and, for the NOGOLD part, everyone.

**What happens:** If `devdisplay.sh start` fails (`Xvfb not found`, exit 3, or `already served by an X server that is not ours`, exit 4), the `catch` discards the message. Each of the 11 dcases then gets `NODISPLAY: ... THIS ARM VERIFIED NOTHING` and `Total num fail: 0`, and `continue`s before its Finish line, so stdout shows 85 Start / 74 Finish. The NODISPLAY text tells the user to run `devdisplay.sh start`, which T1 has just tried and failed at. test_annot_show_menu runs only on this arm, so it goes entirely untested, as do the GUI halves of test_ase_simdlg_0937 and others. create_save, open_close and netlisting report NOGOLD: they produce 10 + 1894 + 1456 result files and verify none of them.

**Evidence:** MEASURED: fresh_t1 results.138854.log, `grep -c '^NODISPLAY'` = 11, `grep -c '^NOGOLD'` = 3, and t1.out has 85 Start / 74 Finish. build: 85/74 in t1_shallow.stdout and t1_export.stdout. harness: the build/export and build/shallow runs, with Xvfb on PATH, still recorded 11 NODISPLAY each because :99 was held by exist_t1's leftover Xvfb. Code: tests/run_regression.tcl `catch {exec $dd start 2>@1}` (verified), and the `!$dd_alive` branch writes `Total num fail: 0` then `continue`s.

**Known issue:** 1481 (Start/Finish asymmetry; CLAUDE.md says the 85/74 split has never been observed, and it was measured here), 0891 (NODISPLAY uncounted by design), 0147 (NOGOLD). Not recorded: the swallowed start error, and the foreign-:99 / CI xvfb-run route.

**Verification:** not independently verified

### F43 [low/LITTERS/MEASURED] -- T1 leaves 84-107 MB of gitignored output, crash corpses and untitled~.sch in the clone, all invisible to `git status`

**Who hits it:** Every stranger who runs T1 or suites in their clone. Suites run from another cwd drop untitled~.sch there instead.

**What happens:** `git status --porcelain` stays empty. With `--ignored`, T1 adds about 82 entries: about 70 per-case .log files, results.log, results.<pid>.log, open_close/ (56M), netlisting/ (12M), create_save/results/ (7.2M), and tests/headless/.scratch/ (4-9M, including corpses of the F14 crashes such as _unused_attr_0970_<pid>). Also tests/untitled~.sch, and tests/results/.actionlogs, which the display arm creates even when it runs nothing. 14 suites (9 in T1) drop a 165-byte untitled~.sch in the cwd, which is the repo root when they are run the documented way. .gitignore's `*~.sch` hides it. Issue-stamp runs leave .scratch/drv_<pid>/.

**Evidence:** MEASURED: fresh_t1 `git status --porcelain --ignored` diff post-build vs post-run plus `du -sh`; build tests/ grew from 22M to 107M; ase_suites per-suite snapshot diffs `> f 165 ... ./untitled~.sch` and `!! untitled~.sch`. run_regression.tcl `set dlogdir [file join [pwd] results .actionlogs]` / `file mkdir $dlogdir`, before the dd_alive check.

**Known issue:** 0060, 0609 and 1480 (untitled~ residue, OPEN); 0322 (headless test drops an untitled-n.sch in the repo root); 0148 (scratch corpses swept only on the next run after 300 s).

**Verification:** not independently verified
