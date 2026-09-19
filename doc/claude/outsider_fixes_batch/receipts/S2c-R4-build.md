# S2c-R4-build: D20, round 4 of Item 2 (crew R4B)

**Status: DONE.** D20 items 1-6 are implemented. Each guard was measured red first, either:
* on the round-3 code (`r3base`) with the new tests, or with the round-3 refuters' own recipe; or
* under a named sabotage of the final code.

The three round-3 sabotages that stayed green now have deterministic rows, and each is red under its sabotage:
* S1 → D19
* S3 → D20
* S14 → H7b

T1 is **87/86/0** with DISPLAY on my private Xvfb and a seeded canary. The canary stayed byte-identical.

Item 7 (test_wave_markers) is recorded, not fixed, as D20 says. Issue 1488 already exists in the main tree.

Tags: **M** = measured (I ran it), **R** = read from source, **I** = inferred.

## Deliverables

| file | what | md5 |
|---|---|---|
| `/var/tmp/xschem_fixes/r4b/r4.patch` | incremental on `r3base` (= `334dc0d5` + r3b/final_item2_only.patch). 13 files, +1085/−241. No new files. | `90ee1877e69fa8b37ef37f7a509f2d84` |
| `/var/tmp/xschem_fixes/r4b/final_item2_only.patch` | cumulative from `r3base~1` = `334dc0d5`, Item-2 files only (rounds 3 and 4). 33 files, +7758/−144. | `003df5ced15c04a108e5d61a6e387e0a` |

**Patch sanity (M, all read-only):**
* The main tree's HEAD moved during the stage. It is now `32b6a9cd`, with round 3 committed as `7a46275f` and docs after it.
* For every one of the 13 files `r4.patch` touches, **both HEAD and the working copy are byte-identical to r3base** (md5 per file).
* `git -C /home/analog/dev/xschem-claude apply --check -R /var/tmp/xschem_fixes/r3b/final_item2_only.patch` → **rc 0**, so round 3 is present.
* `git -C /home/analog/dev/xschem-claude apply --check /var/tmp/xschem_fixes/r4b/r4.patch` → **rc 0**.
* `git apply --check final_item2_only.patch` on a clean `334dc0d5` checkout → **rc 0**.
* The same cumulative patch `--check -R` on main fails, as it should: round 4 is not there yet.

**How the driver moves main to round 4:** `git -C /home/analog/dev/xschem-claude apply /var/tmp/xschem_fixes/r4b/r4.patch`. That is the incremental patch, on top of the committed round 3. It touches no issue-stamp file and no doc except `xarm.sh`.

## What changed, by D20 item

### 1. `devdisplay.sh`: a WM is killed only by DISPLAY and HOME, and a dead `xvfb.pid` short-circuits
* **`_pid_of` now tests liveness.** A live, non-zombie process must run under the recorded pid. `_pid_rec` returns the raw record, and `status` keeps `stale` and prints the recorded number through it.
* **`stop` short-circuits.** Unless `xvfb.pid` names a live process that is `Xvfb :N` by argv[0], `stop` prints "not running (state cleaned)" and **kills nothing**. The reason: a WM or viewer dies with the display it serves.
* **New `_wm_is <pid> <server>`, which `_kill_wm` and `_wm_alive` use.** A WM matches only if all three hold:
  * argv[0] is the WM;
  * `/proc/<pid>/environ` has `DISPLAY=:N`;
  * its HOME equals the verified server's HOME, because one `start` launched both. (Deviation 1.)
* **Rows in `test_devdisplay.sh`:**

| row | what it covers |
|---|---|
| D19 | the S1 row: a decoy with argv[0] `perl` and the words `Xvfb :N` is spared, and so is a lock naming it |
| D20 | the S3 row: a recorded `Xvfb :N` decoy that the lock does not name. `status` must say `foreign`, `exec` must refuse (rc 6), and `stop` must leave the answering server and its lock alone |
| D21 | the refuter's recipe: a dead `xvfb.pid`, a live openbox decoy on another display, a live x11vnc decoy. Neither may be killed |
| D22 | `_wm_is` at the predicate: the real WM passes; another DISPLAY fails; another HOME fails; the right name, DISPLAY and HOME pass |

### 2. `spawn_reaper.sh reaper_sweep_orphan_runs` requires the recorded display
* The dir's display comes from `display`, or from `.reaper_display`. `test_devdisplay.sh` now writes `.reaper_display` at creation, so a run killed inside `start` still names its display.
* The display must match the process, according to its pidfile:
  * `xvfb.pid` and `vnc.pid`: an argv word `:N`;
  * `wm.pid`: `DISPLAY=:N` in its environ;
  * `f=prog`: either one.
* A dir with no display record kills nothing.
* **Rows in `test_devdisplay.sh`:**
  * D17 now sets a positive control: a dead dir's server and WM are reclaimed.
  * D17c: a server or WM on another display is spared.
  * D17d: a dir with no display record kills nothing.

### 3. The `winshot.sh` build cache moved into the checkout
* The cache is now `tests/headless/.winshot-cache/`, listed in `.gitignore`.
* It is built under a temporary name and moved into place, so two concurrent calls never exec a half-written binary.
* An unwritable cache falls back to a per-call `mktemp -d` under TMPDIR, which is removed afterwards.
* `XSCHEM_WINSHOT_CACHE` still overrides.
* `lookshot.sh`'s comment is updated.
* Row **W10** (in `_sh`).

### 4. Nesting applies D17.5's escape check, and D17.5 walks deeper
* **Nesting, in both languages.** A throwaway-shaped HOME whose `.xschem`, `.cache` or `.claude` leads into the real home is **not reused**. The run prints a `!! test home: note:` line and arms a fresh throwaway, as D17.4 does. (Deviation 4.)
* **What D17.5 checks now.** The walk covers:
  * `.xschem`, every entry in it, and its entries two levels down;
  * `.cache` and every entry in it;
  * `.claude` and every entry in it. (`.claude` is where the gate writes; this is an addition.)
* **Only symlinks are resolved.** An entry inside a real directory can leave it only through a link, so a large `simulations/` stays cheap.
* **The code:** `_th_custom_escapes` in the shell and `t1_home_custom_escapes` in Tcl, which share one rule.
* **Rows:**
  * L15 g–k: a `.cache` link, `simulations/{clean,short}.spice` links, a `.cache/openbox` link and a `.claude` link are all refused. A `.cache` linked outside the real home stays custom.
  * **L19:** the refuter's forgery, in `.xschem` and `.cache` variants, arms fresh in both languages. A probe write lands outside the canary. An honest throwaway is still nested.

### 5. T1's private arm: the reaper is forked before the server and finds it by tag
* **Order and tag.** `t1_private_xvfb` now builds a per-attempt tag, `t1.<pid>.<starttime>.<n>.<µs>`, and starts the reaper **before** it execs `Xvfb`. The server and the WM are exec'd with `XSCHEM_TEST_T1_XVFB_TAG=<tag>`. This mirrors the shell's `XSCHEM_TEST_XVFB_TAG`.
* **The reaper's three phases:**
  1. Wait, up to 10 s, for this attempt's recorded and tagged server, while watching the owner.
  2. Poll every `T1_XVFB_REAPER_POLL` seconds (default 5; valid range 1..3600).
  3. When the owner dies, kill every process carrying the tag: Xvfb, the WM, and an `env` stage, where the tag is an argv word. Rescan until two scans come back empty, then remove the lock by content.
* **Each reaper records itself in its own `.xvfb/reaper.<pid>.pid`.** `t1_home_reapers_of` replaces `t1_home_reaper_of`, and `t1_home_kill_xvfb` stops every reaper recorded that way.
* **Rows:**
  * **H6d:** the reaper's fork precedes the server's (pid order), and a T1 killed at the reaper's launch leaves nothing.
  * **H6e:** runs the reaper script itself, read out of `run_regression.tcl`. The owner dies before any `.xvfb.pid` exists. The tagged Xvfb and WM must be gone (they went in 101 ms), and an Xvfb carrying another tag must survive.
  * **H7b:** S14, made deterministic. H7 forces the lost race with a 60 s poll. Its display case lists the run's live reapers, and there must be exactly 1.

### 6. G2 covers the whole repository and recognises more launcher shapes
* **Scope.** G2 now scans every `.sh`, `.bash`, `.py` and `.tcl` file and every extensionless file with `#!` in the repository: **715 scripts** (M). It skips dot-dirs, `results*` and `gold`.
* **What it recognises:**
  * a path whose last component is `xschem`, spelled out or held in a variable (`"$BIN/xschem"`);
  * Tcl `[file join … xschem]`;
  * Python `os.path.join(…, "xschem")`;
  * `command -v`, `type -P`, `$(which …)`, `auto_execok` and `shutil.which`;
  * a bare Tcl `exec … xschem -…` and `open "|xschem`;
  * a Python argv or subprocess call that starts with `"xschem"`;
  * the Python arm, `"test_home.sh"), "--run"`.
* **Python triple-quoted text is prose.**
* **The allowlist** is keyed by repo-relative path. `*` means the whole file. An entry that matches nothing **fails the row**.
* **What a textual guard cannot see** is stated in the row: a name assembled from pieces, a path read at run time, `eval`/`exec {*}$cmd`, a renamed binary, an unscanned language, a dot-dir, and text a program later runs. **Row G2b** plants the refuter's three launchers plus the Tcl and Python bare forms and requires all 6 caught. It also plants 4 unseeable shapes and requires none of them caught.
* **`xarm.sh`** is **armed**:
  * `test_home_arm` runs first;
  * `one` goes through `gated_xschem.sh` and `suites` through `run_suites.sh`, as children in both modes;
  * no `exec`, no `xvfb-run -a` (which started at :99), no bare binary;
  * `raise_panel` (`pgrep -f` and an untracked `wish`) is removed, because the drivers' gate raises its own tracked panel.
* **`tools/migrate/test_ase_migrate.py`** was found by the widened scan and is **armed**: it re-execs once through `test_home.sh --run`.
* **Rows:**
  * W3b (text) and **W11 (behaviour)**. W11 runs both from an empty home, needs the banner, and needs the home to stay empty.
* **Final G2 (M):** 25 armed, 22 inside, 6 delegating only, 14 allowlist entries all used, **0 unarmed**. The entries and their reasons:
  * the 3 PDK `run.sh` and `tools/launcher/pdk_launcher.tcl`: product launchers, which run in the user's own HOME on purpose;
  * `pdk_launcher.sh`: an error message only;
  * `tools/migrate/ase_migrate.py`: a user tool whose `--verify` runs the user's own xschem;
  * `tools/migrate/build_ihp_sg13g2.sh`: `$SRC/xschem` is a PDK directory;
  * `doc/claude/batch_F/eyeball_fixtures.sh`: here-doc text written for a person;
  * `doc/claude/casemode_batch/repro3/run_r3b.sh`: a hard-coded `/home/qflow` binary from another machine, kept as evidence;
  * the two `item15_*cite_check.py` scripts: a checkout path on another machine;
  * the 3 pre-existing entries, now keyed by path.

## Measured on the final code (clone `/var/tmp/xschem_fixes/r4b/tree`)
**Environment for every run:**
* `env -i`, with HOME = a seeded or EMPTY D11 canary.
* A `find -printf` + md5 snapshot before and after, plus inotify and a leftover scan (`tools/run.sh`).
* `DEVDISPLAY_NUM=167`, `AUDIT_XVFB_BASE=160` and `XSCHEM_TEST_XVFB_BASE=160`. An xvfb-run shim forced `-n 160 -a` (82 calls, all base 160).

| run | result | canary |
|---|---|---|
| **T1**, `cd tests && tclsh run_regression.tcl`, DISPLAY = **my Xvfb :168**, seeded canary | `T1-RUN-END pid=1683042 cases=87 blocks=86 counted_failures=0 elapsed=535s`. 87 Start / 87 Finish, `wc -l` 177, header `home=throwaway binary=…/tree/src/xschem`. The display arm used `PRIVATE Xvfb :100 … wm openbox`. Inside T1: test_home_isolation **116**, `_sh` **90**, 1476 **37**, all ALL PASS | identical, 0 events, 0 procs left |
| `test_home_isolation` solo; and **4-way concurrent** | ALL PASS (116). 4-way: 4/4 ALL PASS (116), 0 skips | all identical |
| `test_home_isolation_sh` | ALL PASS (90) | identical |
| `test_devdisplay.sh` (numbers 166/165 and 164/163) with a **canary state dir** (`dev` canary, its `xschem_dev_display` naming a dead pid) | ALL PASS (**53**, up from 43) | identical, the state dir included |
| `test_regression_concurrency_1476` | ALL PASS (37) | identical |
| `tools/migrate/test_ase_migrate.py`, seeded and EMPTY | ALL PASS (151) both | identical / still empty |
| `lookshot.sh` on an EMPTY canary, LOOK_DISPLAY = my :169 | png written, rc 0 | still empty |
| `winshot.sh -root` on an EMPTY canary | png written; the binary is in `tests/headless/.winshot-cache` (ignored by git) | still empty |
| `xarm.sh one test_crossview_paste.tcl` on an EMPTY canary, DISPLAY :169, deadline passed | PASS=28 FAIL=0 | still empty, no panel |

## Red first (M)

**r3base code with the new tests** (`baset` = r3base + the three new test files):
* test_devdisplay: **5 FAILED** (48 passed): D17c, D17d, D21 ×2, D22.
* test_home_isolation: **5 FAILED** (111 passed):
  * G2 names `test_ase_migrate.py:959,996` and `xarm.sh:103`;
  * H6d reports `order=server-first`;
  * H6e: the tagged Xvfb was still alive after more than 12 s;
  * L15 (g, h, i, j): all accepted as custom;
  * L19: both languages reused the forged homes, and the probe wrote into the canary.
* test_home_isolation_sh: **3 FAILED**: W3b, W11 (no banners, and the home changed) and W10 (cache under HOME, not ignored by git; the unwritable-cache build failed with rc 5).
* G2b: the round-3 scanner, run over the G2b fixture, catches **0 of the 6** planted launchers. The new scanner catches 6 of 6 and 0 of the 4 unseeable shapes.

**The round-3 refuters' recipes, on r3base code against real processes of mine** (Xvfb :169 + openbox, HOME = r4b/xhome):
* `devdisplay.sh stop` with a state dir for :168 (dead `xvfb.pid`, `wm.pid` = my live openbox): base printed `stopped :168` and **killed my openbox**. Fix: `not running (state cleaned)`, both alive.
* A stale `devdisplay_test.r4bstale` (dead owner, display `:168`, naming my live Xvfb :169 and its openbox), then the full `test_devdisplay.sh` with TMPDIR = that dir's parent: base swept, and **both were dead afterwards**. Fix: **both alive**, and the suite still passed 53/53.
* A forged throwaway-shaped HOME directly under TMPDIR with `.xschem` → canary: base reused it in both languages. Fix: fresh arm and a `!! note`.
* On an EMPTY canary:
  * `winshot.sh`: base created `.cache/xschem-winshot/{build.log, winshot 21792 B}`.
  * `xarm.sh one`: base created `.claude/gui_test_gate/{control,req,status,widget.log,widget.pid}` and left a `wish` panel with HOME = canary. I killed it by pid, after checking its environ.
  * `test_ase_migrate.py`: base created `.xschem/op_annot/`.

**Sabotages on the final code** (copy `sab`, restored and diffed after each; `tools/sab.py`):

| id | sabotage | red rows |
|---|---|---|
| S1 | `_pid_is` back to "word anywhere" | D19 ×2 |
| S3 | `_ours` without the lock check | D20 ×2 |
| SD1 | stop without the dead-server short-circuit | D21 ×2. The WM decoy still survived through `_wm_is`; the viewer decoy died |
| SD2 | `_wm_is` checks the name only | D22 |
| SR | sweep without a display record or check | D17c, D17d |
| **S14** | `t1_private_reaper_stop` a no-op | **H7b** (2 reapers during the case) |
| ST | reaper forked after the server (round-3 order) | H6d (`server-first`) |
| STG | reaper ignores the tag | H6d, H6e |
| SN | nesting escape check off, both languages | L19 |
| SE | escape walk back to round 3 | L15, L19 |
| SG | G2 back to `tests/` only | G2 |
| SGV | G2 without the variable, PATH and Python forms | G2, G2b |
| SX | xarm unarmed | G2, W3b, W11 |
| SM | test_ase_migrate's re-exec behind `if False:` | **W11 only**: G2 and W3b are textual and stay green, which is the stated limit |
| SW | winshot back to `~/.cache` | W10 |

The first sabotage batch ran against an intermediate H7b. That version was fooled because T1 runs the same stand-in again for `xschemtest.tcl`. S14 was green then, and SN, SE, SG, SGV and SX also showed a spurious H7b red. The final H7b records only as the display case. All of those were re-run on the final tests: batch 2, `runs/sabrun2.log`.

## Deviations
1. **The HOME in D20.1's "(and HOME)"** is the WM's environ HOME compared with the **verified server's** HOME, not a new state record. Old state dirs keep working.
2. **`_pid_of` means "live"**, and `_pid_rec` is the raw record. `status` still reports `stale` for a record naming a dead pid.
3. **The sweep's display identity depends on the pidfile.** The server and the viewer are matched by argv word, since their environ DISPLAY is only their parent's. The WM is matched by environ. `test_devdisplay.sh` writes `.reaper_display`.
4. **Nesting "refused" means not reused, then a fresh arm with a note**, as D17.4 does. The run itself is not refused. The walk adds `.claude` beyond D20's `.cache` and depth 2, and it resolves symlinks only.
5. **Per-attempt reapers each have their own record file**, the `T1_XVFB_REAPER_POLL` knob is new, and `t1_home_reapers_of` replaces `t1_home_reaper_of`.
   * **Consequence:** the arm's teardown now stops a straggler reaper too. S14 is therefore invisible *after* a run, and H7b looks *during* it.
   * **H6d measures construction (pid order) and outcome, not the sub-millisecond window itself.** That window cannot be hit on purpose from outside; round 3 hit it 0 times in 111 trials. The order check is deterministic, and it is red on round 3.
6. **G2 changes:**
   * the allowlist is keyed by path, and `*` means the whole file;
   * an unused entry fails the row;
   * Python triple-quoted text is read as prose;
   * `tools/migrate/test_ase_migrate.py` was armed. D20 did not name it; the widened scan found it.
7. **`xarm.sh`'s gate panel launch was removed, not re-plumbed.** `gated_xschem.sh` and `run_suites.sh` raise the panel through `gate_start`. `XARM_SCREEN` went with `xvfb-run`; use `AUDIT_SCREEN`.
8. **Decoys are `perl -e 'sleep 300'` run under the impersonated name.** D17–D22 skip loudly where there is no perl. W10 skips where there is no `cc`, and W11 where there is no python3. H6e uses symlinks to perl named Xvfb/openbox, because the reaper scans `comm`.
9. **Display numbers.** Mine were :168 (T1's DISPLAY), :169 (fixtures, lookshot and xarm) and 150–169 through the suites' fixture range. :160+ was used through the shim, `DEVDISPLAY_NUM` 167, and `DEVDISPLAY_TEST_NUMS` 166/165 and 164/163. The code under test chose :100/:101 (T1's private arm) and the fake numbers :9166 and :1166+/:2166+/:3166+, which are argv words only. **:99 was never started, probed or stopped.**

## Open problems
1. **G2 is textual.** Its blind spots are listed in the row and measured by G2b. A disabled arm (SM) can only be caught by a behaviour row like W11. Only xarm and test_ase_migrate have one.
2. **`ase_migrate.py --verify`**, a user tool, still starts xschem in the user's HOME by design. It is allowlisted with that reason.
3. **The user's real state dir** names dead pids (1116 and 1135). `devdisplay.sh stop` against it now kills nothing and **cleans the state files**. That cleaning is pre-existing behaviour; the change is that no kill is attempted. (R)
4. **T1's private arm is still hard-coded to :100–:199.** This carries over from round 3.
5. **Attach to and auto-start of the user's real :99 through the real state dir** can still only be shown with the real HOME. It stays owed to the user, per D20.
6. **One `/tmp/xschem_emergencysave_untitled_agceacefge`** (20:15) falls inside my T1 window. None of my outputs names it, so I left it.
7. **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/r4b` (2.2 GB): tree, base, baset, sab, chk, canaries, runs, tools and aux.

## Real home (M)
* **Marker:** `/var/tmp/xschem_fixes/r4b/.start_marker`, 19:14:07.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the start, at mid-stage and at the end.
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate ~/.claude/xschem_owed ~/.cache -newer <marker>` printed **nothing**, at mid-stage and at the end.
* **No interactive xschem:** the newest `/tmp/Xschem.log*` is still `.4`.
* **HOME:** every run's HOME was a canary or scratch dir under r4b, and `XSCHEM_TEST_REAL_HOME` was never `/home/analog`. `XSCHEM_OWED_DIR` pointed into canaries.
* **Kills:** only by pid, after an environ-HOME check (my fixtures, my decoys, and base's leaked panel). No `pkill`.
* **Nothing left:** at the end there are no X locks, no processes naming r4b, no `/tmp/xschem-test-home.*` and no fixture reservations.
* **Main tree:** only read, and this receipt written. `~/dev/xschem-op-wcard` was not touched.
