# S2c-R2-S: the shell half of D13 (crew R2S)

**Status: DONE.** Every D13 item the shell owns is implemented. Each has a row in
`test_home_isolation_sh.tcl` that was measured RED on the round-1 build (`r1base`) or on a
sabotage, and GREEN on the fix. The ten documented entry points D13.1 names now leave a
seeded canary byte-identical. On `r1base` all but `run.sh` changed it. T1 is ZERO except one
row pair that waits on the Tcl crew's own D13.6 (below).

Tags: **M** measured (ran it; output quoted), **R** read from source, **I** inferred, **U** unknown.

## Deliverable

| item | value |
|---|---|
| patch | `/var/tmp/xschem_fixes/r2s/r2.patch`, md5 `ca20322b368e08af5644f4081ee69d77`, 2013 lines |
| base | **incremental on `r1base`** = `733e03ad` + `istamp_s1fix.patch` (md5 `7600660c…`) + `s2c_I/final_item2_only.patch` (md5 `3e25e4b6…`), committed in the clone as `ebd02b74`. `r1base` was only that commit's *message*, so I tagged it `r1base` for `git diff r1base` to work (M). |
| applies | `git apply --check r2.patch` on a separate `r1base` clone: rc 0 (M). `bash -n` on the 8 bash files and `sh -n` on `run.sh`/`run_nogui.sh`: clean (M). |
| files | 10, all modifications, no new files: `test_home.sh`, `xvfb_arm.sh`, `run_suites.sh`, `gated_xschem.sh`, `owed.sh`, `run.sh`, `run_nogui.sh`, `test_devdisplay.sh`, `gui_gate.sh`, `test_home_isolation_sh.tcl`. +1133 / −128. **None of the 7 standalone suites needed editing**: arming `xvfb_arm.sh --arm` was enough (M, below). |
| driver commit during the stage | main HEAD moved `733e03ad` → `616110a6` (D14, Item 1). It touches none of my 10 files (M: `git diff --name-only`). |

## What each D13 item became (R), its rows, and its proof (M)

`test_home_isolation_sh.tcl` went from 53 to **82 checks** (about 40 s, headless; display rows
use `XSCHEM_TEST_XVFB_BASE`, default 160).
* **Fixed tree:** `RESULT: ALL PASS (82 checks)`.
* **`r1base` scripts** (the new suite copied beside them): **22 FAILED (57 passed)**, measured
  when the suite had 79 rows.
* **Sabotage matrix:** 30 sabotages on a copy of `tests/`, each red on its target row(s), plus a
  green no-op control. Harness: `r2s/tools/sab.py`; list: `sabs.json`; logs:
  `runs/sab/matrix*.out`. Every file was md5-restored.

| D13 | what changed | rows | red on r1base (M) | sabotages → red rows (M) |
|---|---|---|---|---|
| **.1** `--arm` | `xvfb_arm.sh --arm` sources `test_home.sh` and arms **before** the display arm. On attach, none or explicit it runs the command as a **child** and exits with its status (an exec would skip the EXIT trap). On the private path it execs xvfb-run with the handoff to a new launcher, `--wm-launch-own`. That launcher takes ownership (it is xvfb-run's child), starts the WM, runs the POSIX suite as a child, and its trap deletes the home. | W3 (static), W4 (no spawn), W5 (through xvfb-run) | W3, W4, W5 | S01 → W3 W4 W5; S02 → W3 W4 (+cascade); S03 → W5 (+cascade) |
| **.1** `test_devdisplay.sh` | Arms directly at the top. Its own EXIT trap would *replace* the owner's, so the trap is now `_cleanup; _th_cleanup` on EXIT only. INT/TERM still run only `_cleanup`, because that trap carries on and must not carry on in a deleted HOME. | W3 | W3 | S04 → W3 |
| **.1** `owed.sh drain` | `OWED_DIR` is made absolute and `readonly` at startup, from the HOME drain started with. A shell debt runs as `( . test_home.sh && test_home_arm \|\| exit $?; … bash "$path"; exit $rc )`: armed in a subshell, so HOME never moves for the ledger owner. `.tcl` debts are unchanged (run_suites.sh arms). | W3, W8 | W3, W8 | S06 → W3 W8 |
| **.1** `run.sh`, `run_nogui.sh` | POSIX scripts re-exec once through a new executed entry, `bash test_home.sh --run sh "$0" "$@"`. It arms, runs the script as a **child** with `XSCHEM_TEST_HOME_WRAPPED=<its pid>`, and exits with its status. The guard is identity, not a flag: `[ "${XSCHEM_TEST_HOME_WRAPPED:-}" = "$PPID" ]`, then unset. | W3, W6, W7, E2 | W3, W6, W7, E2 | S05 → E2 W3; S07 → W6 (+cascade) |
| **.3** cwd | `run_suites.sh` resolves and **absolutises** relative suite paths (and a relative `$XSCHEM`), then `cd "$REPO"`. `gated_xschem.sh` rewrites to absolute every argument naming a path that **exists** relative to the caller's cwd, including the value of `--x=value`; args starting `-` are left alone. It then does `cd "$REPO"`. `--help` range made drift-proof: `2,/^set -u$/`. | C1, C2 | C1, C2 | S09, S10 → C1; S11, S12 → C2 |
| **.4** banner | When the throwaway is physically inside the real home, the line reads `test home: throwaway <TH> (your ~/.xschem is untouched; the throwaway lives under your HOME because TMPDIR does; XSCHEM_TEST_HOME=real to opt out)`. The `!! … note:` line stays. The nested banner uses the same rule. | B1 | B1 | S13 → B1 |
| **.5** symlink | Kept: the shell already refused a symlink to the real HOME (`cd … && pwd -P` resolves the last component). **Added:** a custom dir whose *resolved* path is a throwaway is refused too; round 1 checked only the given spelling. | O5 | O5, second half only (the first half was already green, as D13.5 says) | S14 → O5 (textual compare); S15 → O5 |
| **.6** `.owner` | Written as `<pid> <boot_id> <pidns>` (`_th_owner_line`). Every reader takes the **first field**; the round-1 reader stripped non-digits from the whole line. The dead rule is in `_th_owner_dead` (exact reading below). The 300 s age and `.keep` still apply first. | F11, G8–G12 | F11, G9, G11 | S16 → F11; S17 → G8; S18 → G9; S19 → G10 |
| **.7** sweep identity | `_th_is_proc <pid> <prog> [<home>]`: argv[0] basename AND `HOME` in `/proc/<pid>/environ` equal to the dead throwaway's path (textual or physical). The sweep now also kills a recorded WM (`.xvfb/wm.pid`, named by `.xvfb/wm`, the Tcl side's files). A lock is removed only if its **content** names the killed server (D13.14). | G5, G5b | G5, G5b | S21 → G5b; S22 → G5 |
| **.8** handoff | Adds `_th_runs_xvfb_run <h>`: argv[0] or argv[1] of `/proc/<h>/cmdline` is `xvfb-run` (it is run through `/bin/sh`). The check runs after the parent/grandparent test, so N8's wording is unchanged. The refusal names the cmdline. | N8b | N8b | S23 → N8b |
| **.9** `.keep` | Written at arm time when `XSCHEM_TEST_KEEP_HOME=1`. Cleanup only re-asserts it. | X6 | X6 | S24 → X6 |
| **.11** skip lines | After every verdict line (PASS, FAIL, SKIP, TIMEOUT, NORESULT) run_suites prints `^skip:` lines, indented `         \| `, after any FAIL/FATAL lines. | S1 | S1 | S25 → S1 |
| **.15** reaper | `_xvfb_wm_start` (both launchers) starts `setsid env -i PATH=… bash xvfb_arm.sh --reap P Pstart Q Qstart X N W Wname HOME`. It watches xvfb-run (P) and the command (Q) by **pid plus start time**, every 5 s. If P is gone it kills the WM and Xvfb (identity: argv[0], `:N` in argv, environ HOME). If only Q is gone it gives xvfb-run one more poll. It exits within 0.5 s once nothing is left. | X7, X7b, X8, Z2 | X7 | S26, S28 → X7; S27 → X8 |
| **.16** snapshot | The outermost arm (fresh, custom or real; **not** nested, handoff, or under an enclosing arm) exports `XSCHEM_TEST_PRE_ENV` = base64 of `env -0` minus `XSCHEM_TEST_*`, capped at 64 KiB. `_gate_panel_env` starts the **shared** panel with `env -i <snapshot> DISPLAY=<current>`. Scope and the bug it avoids are under deviations. | K5, K6 | K5 | S29 → K5 K6; S30 → K4 K5; S31 → K6 |

**The D13.6 dead rule as implemented** (R, `_th_owner_dead`). Missing fields read `-`, so a
round-1 one-field `.owner` is `<pid> - -`.
1. If both boot_ids are known and differ: **dead**.
2. Else, if both pidns are known and differ: dead only if the entry is **older than 7 days**.
3. Else, dead if the pid is not alive (the old rule).

A `-` in one field falls back to the old rule for *that* field only. So an unknown boot_id with
a known, different pidns still gets the 7-day protection. That is my reading of "where a field is
`-`, the old rule applies". It is the safe direction (a leftover survives), and **the Tcl side must
read it the same way**: this is the one edge where two literal readings differ.

## Canary proof (M; `r2s/tools/run.sh`)

Setup for every run:
* `env -i`, `DISPLAY` unset, `DEVDISPLAY_NUM=168`, `TMPDIR=r2s/tmp`.
* `xvfb-run` shimmed to `-n 160` (`r2s/shim`).
* A freshly seeded D11 canary per run: clipboard, clean.spice and short.spice, a 100-entry
  geometry, recent_files, ase_simulators, .spiceinit, .ngspice_history, .gitconfig, .Xauthority
  and Documents/, every mtime `@1789000000`.

Snapshots are `find -printf` plus an md5 of every file, before and after, with iwatch over the
whole canary.

| entry point | `r1base` (red first) | fix: canary / events / procs left / throwaway left | verdict r1base = fix |
|---|---|---|---|
| `sh test_action_log.sh` | `.cache/openbox` created | identical / 0 / 0 / 0 | ALL PASS, 10 rows |
| `sh test_action_replay.sh` | `.cache/openbox` + `geometry` rewritten | identical / 0 / 0 / 0 | 1 FAILED, 12 rows, same FAIL line (pre-existing) |
| `sh test_file_menu_log.sh` | `.cache/openbox` + `geometry` | identical / 0 / 0 / 0 | 1 FAILED, 6 rows, same FAIL lines (pre-existing, ~60 s) |
| `sh test_flylines.sh` | `.cache/openbox` | identical / 0 / 0 / 0 | ALL PASS, 43 |
| `sh test_readonly_action_dispatch.sh` | `.cache/openbox` + `geometry` | identical / 0 / 0 / 0 | PASS, 4 |
| `sh test_readonly_guard.sh` | `.cache/openbox` | identical / 0 / 0 / 0 | PASS, 13 |
| `sh test_recent_launchlog.sh` | `.cache/openbox` | identical / 0 / 0 / 0 | ALL PASS, 19 |
| `bash test_devdisplay.sh` | `.cache/openbox` + `geometry` | identical / 0 / 0 / 0 | ALL PASS (39) |
| `sh run_nogui.sh` | **1 205 036 B `.xschem/simulations/0_examples_top.spice`** | identical / 0 / 0 / 0 | PASS |
| `sh run.sh` | nothing (0 events): hermetic already, so **no red first exists** | identical / 0 / 0 / 0 | HARNESS: PASS |
| `owed.sh drain --display :166`, scratch `XSCHEM_OWED_DIR`, one `.sh` debt (`test_readonly_action_dispatch.sh`) | `geometry` 4964 → 4940 B | identical / 0 / 0 / 0; debt cleared, `cleared.log` in the scratch ledger | PASS |
| `run_suites.sh` × 5 writer suites (private arm) | red first = `XSCHEM_TEST_HOME=real`: canary changed, 251 events | identical / 0 / 0 / 0 | 4 PASS, `test_paste_modify_flag_0244` TIMEOUT on the GUI arm (same with real; round 1 recorded it too) |
| cwd = canary holding the tester's own `untitled~.sch`, `run_suites.sh test_signal_short_nohier_0230 test_crossview_paste` | `untitled~.sch` **deleted** | identical / 0 | 2/2 PASS |
| same, `gated_xschem.sh --pipe -q --nolog --script …0230.tcl` | `untitled~.sch` **overwritten** 96 → 219 B | identical / 0 | ALL PASS (11) |

**Verdict parity (M).** For all ten entry points the verdict, the row count and the md5 of the
FAIL-line set are identical on `r1base` and the fix. That was measured in batch `tree2`, after the
reaper fix below.

**`test_devdisplay.sh` never touched `:99` (M).** It used dev display `:96`, a foreign fixture from
85–88 and, for D6, `:162` through my shim. Its state dir is `$TMPDIR/devdisplay_test.*`. The string
`:99` appears 0 times in its output. Hazard: D6 reaches `xvfb-run -a`, which numbers from 99, so
**without a shim it takes `:99` whenever the dev display is down** (R; open problem 1).

**D13.15 at driver level (M; `tools/kill9.sh`, `kill9arm.sh`).** Wait for the handoff, then
`kill -9` the pid the tester launched (now `/bin/sh /usr/bin/xvfb-run …`):

| path | `r1base` | fix |
|---|---|---|
| `run_suites.sh` | Xvfb and openbox **alive at 30 s**. I killed them afterwards. | both gone in **2.15 s** |
| `sh test_file_menu_log.sh` (`--arm` path) | alive at 30 s | gone in **2.27 s**; the launcher's trap deleted the home |

**D13.8, the round-1 recipe verbatim (M; `tools/handoff_forge.sh`).**
* `r1base`: `child … .owner now=<child>` and `parent after child: HOME exists? NO`.
* fix: `ignoring XSCHEM_TEST_HOME_HANDOFF=… (pid … is not running xvfb-run …)`, `.owner now=<parent> <boot> <ns>` and `HOME exists? yes`. The parent deleted the home at its own exit (0 left).

## T1, with DISPLAY set to my own Xvfb (M)

Environment:
* `cd tests && tclsh run_regression.tcl`, HOME = a seeded canary.
* Its `.claude/xschem_dev_display` points at **my fixture `:166` + openbox**, with
  `DEVDISPLAY_NUM=166` and `DISPLAY=:166`.
* So the 11 dcases **attached** to `:166` (`display arm: attached to the dev display (state dir …/canaries/t1_tree/…)`)
  and T1 never used its hard-coded private range. No `:99` lock at any time.

| run | trailer | counted, per case |
|---|---|---|
| `t1_tree` | `T1-RUN-END … cases=87 blocks=86 counted_failures=2 elapsed=518s` | (a) `headless/test_home_isolation`: L2a/L2b, see below. (b) `headless/test_home_isolation_sh`: **my defect**. The *passing* row `ok: S1 … on a PASS and on a FAIL` ends in `FAIL`, a counted shape. Renamed; a scan of every row name now finds no trailing FAIL, GOLD? or RESULT? and no leading FATAL. |
| `t1_tree2` (final code) | `T1-RUN-END pid=3036603 cases=87 blocks=86 counted_failures=1 elapsed=571s`, 87 Start / 87 Finish | only `headless/test_home_isolation` (L2a/L2b). `test_home_isolation_sh`: `ALL PASS (82 checks)`. Every other case is at 0. |

Both T1 canaries, **including the attached state dir**, were byte-identical: 0 events, 0 procs
left, my TMPDIR empty afterwards.

**L2a/L2b are the integration point, not a regression (M).** They are `test_home_isolation.tcl`
at `r1base`, the Tcl crew's file:
* A shell-armed home is not nested for a Tcl child, because the r1base Tcl reader
  (`t1_home_read_int`) requires the whole `.owner` to be an integer, and D13.6 makes it three
  fields.
* Run standalone against my tree, that suite is `2 FAILED (74 passed)`: **only** L2a/L2b. The L1,
  L3, L4 and L5 crossings all pass.
* The Tcl crew's own live T1 already writes the same format: `/tmp/xschem-test-home.3155702.*`
  `.owner` = `3155702 76b8c064-… pid:[4026532221]`, owner `tclsh run_regression.tcl` in `r2t`.

So after integration L2a/L2b should be green (I).

## Four defects I made and caught before they left this stage (M)

1. **Reaper start time taken in a subshell.** `qs=$(_xvfb_stat_field "$BASHPID" 22)` expanded
   `$BASHPID` inside the `$(…)`, so the reaper recorded a dead subshell as its owner and killed
   every live private display about 10 s in.
   * No X row could see it: every one ended in under 5 s.
   * It surfaced as a new flake in `test_file_menu_log`: 2 of 4 fixed-tree runs showed an extra
     red and ended at 6 s instead of 60 s. Base showed 0 of 5.
   * Fixed (capture `me=$BASHPID` first). Row **X8** (a run longer than two polls keeps its
     display) is red on sabotage S27.
   * The pre-fix batch results were discarded and re-measured (`tree2`).
2. **D13.16 `env -i` for every gate dir outside HOME** (my first draft). The gate self-tests
   (`test_gui_gate_revive.sh`'s `in_gate`) set a temp `GUI_GATE_DIR`, a stub `wish` on `PATH` and
   `DISPLAY=:99`. Under an armed parent, `env -i` would drop the stub and start a **real `wish` at
   `:99`**.
   * Found by reading (R); it was never run.
   * Narrowed to the shared panel only. Row **K6** is red on the first-draft sabotage S31.
3. **`owed.sh` in a relocated copy.** `test_owed.sh` O14 drains through a copy of `owed.sh` with no
   `test_home.sh` beside it, so arming failed and 5 O14 checks went red (M).
   * `test_owed.sh` is not mine to edit, so the copy now runs the debt unarmed with a loud
     `!! owed WARNING: no test_home.sh beside this owed.sh …`. Row **W9**, red on S32.
   * `test_owed.sh` is back to `ALL PASS (365 checks, 1 skipped)`, the same as `r1base`.
4. **The S1 row name** ended in `FAIL` (T1 above).

## Deviations (each with the reason)

1. **New internal names; no contract name was renamed.**
   * `XSCHEM_TEST_PRE_ENV`: the D13.16 carrier. XSCHEM_TEST_* are stripped from it, so it never
     contains itself.
   * `XSCHEM_TEST_HOME_WRAPPED`: the `--run` loop guard.
   * `test_home.sh --run`: a POSIX entry.
   * `xvfb_arm.sh --wm-launch-own` and `--reap`.
   * The shell-local `_XVFB_LAUNCH`.
2. **D13.16 scope.** The snapshot is applied only to the **shared** panel: `GATE_DIR` physically
   equal to `$XSCHEM_TEST_REAL_HOME/.claude/gui_test_gate`, or equal to a `GUI_GATE_DIR` the tester
   set **before** arming (it is in the snapshot).
   * Any other gate dir outside HOME keeps round 1's environment exactly. Reason: defect 2 above.
   * In the shell, only the panel needs the snapshot. The shell never starts the persistent display
     (xvfb_arm only attaches), so that half of D13.16 is the Tcl side's.
3. **D13.6 `-` fields** are read field by field (above). Nesting still means ".owner's first field
   is a live pid" (D5); only the sweep uses the full dead rule.
4. **D13.15 reaper.** It watches both xvfb-run and the command.
   * If xvfb-run dies, it kills at once. When only the command dies, xvfb-run is left one poll to
     stop its own server; that avoids racing xvfb-run's `kill $XVFBPID`.
   * It starts under `env -i PATH=…`, so it carries no harness variables. As a consequence, a
     leftover scan by HOME cannot see it; row Z2 checks by cmdline instead.
   * The WM is now started with `env -u XSCHEM_TEST_HOME_HANDOFF`, so the handoff variable is never
     in the WM's environment.
5. **`owed.sh` fallback when `test_home.sh` is absent**: loud and unarmed rather than refused
   (defect 3). This departs from "never fall back". To make it refuse, `test_owed.sh` (unowned)
   must copy `test_home.sh` beside its stub.
6. **O5's second half** (a symlink resolving to a throwaway is refused) goes beyond D13.5's text.
   It follows the same logic as the real-HOME case.
7. **`gated_xschem.sh`** leaves unrewritten any argument naming a path that **does not yet exist**.
   Such an output path now resolves against the repo root. This is D13.3 as worded.
8. **`test_devdisplay.sh` trap**: EXIT runs `_cleanup; _th_cleanup`. INT/TERM stay `_cleanup` only.
9. **Measurement:**
   * T1 used an **attach** fixture on `:166` instead of T1's private range from `:100`, so nothing
     ran outside 160–169.
   * The suite's own display rows use their built-in 160+ numbers.
   * The sabotage matrix ran on a copy of `tests/` (`r2s/sab`, with `src` and `xschem_library`
     symlinked to the tree). Seven sabotages were re-run after the final sync.

## Open problems

1. **`xvfb-run -a` numbers from `:99`**: `xvfb_arm.sh`'s private path, and so `test_devdisplay.sh`
   D6. When the dev display is down, any armed shell run briefly takes `:99`, and a
   `devdisplay.sh start` in that window exits 4 (R).
   * Not changed: it is not in D13, and it would override every refuter's `-n` shim.
   * Suggested: `-n 100` before `-a` (xvfb-run searches from the last `-n` it has parsed), as D8
     does for T1.
2. **`test_devdisplay.sh` `_cleanup` removes `/tmp/.X$NUM-lock` by number** (D13.14 class,
   pre-existing, not changed).
3. **For the Tcl crew and integration:**
   * The Tcl `.owner` reader must take the first field (L2a/L2b).
   * `test_home_isolation.tcl`'s scrub list should add `XSCHEM_TEST_PRE_ENV` and
     `XSCHEM_TEST_HOME_WRAPPED`.
   * D13.7 means **the shell sweep kills a recorded Xvfb or WM only if its environ HOME is that
     throwaway**. A T1 private Xvfb started with any other HOME (for example from an on-demand run
     dir under real/custom HOME) will be *left* by the shell sweep (R/I).
4. **Custom mode** still says `(never deleted; your HOME is untouched)` even when the custom dir is
   inside the real home. D13.4 covers TMPDIR only.
5. **`wireedit/run_wireedit.sh`** (run by `full_audit.sh`) is not armed standalone. It is not in
   D13.1's list (R, not measured).
6. **Pre-existing reds, identical on `r1base` and the fix in this environment:**
   * `test_action_replay.sh` (1 FAILED);
   * `test_file_menu_log.sh` (1 FAILED, ~60 s);
   * `test_paste_modify_flag_0244` TIMEOUT on the GUI arm.
7. **Emergency-save dirs:** 14 `/tmp/xschem_emergencysave_*` are newer than my start marker.
   * 8 are `fix_*`, on a ~60 s cadence matching my `test_file_menu_log` runs (its `fix.sch`,
     killed by its own `timeout 60`).
   * 2 are `untitled_*`, at the times of my 0244 TIMEOUT runs.
   * INFERRED mine, but no output names them, so **all were left in place**.

## Real home (M)

* **Marker:** `/var/tmp/xschem_fixes/r2s/.start_marker`, 06:46:18.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave rc 0 at the start, mid-stage
  and at the end.
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate ~/.claude/xschem_owed ~/.cache/openbox -newer <marker>`
  printed nothing, mid-stage and at the end.
* **No interactive session:** the newest `/tmp/Xschem.log*` is `.4`, 09-17 23:35.
* **HOME for every run:** a canary or scratch dir under `/var/tmp/xschem_fixes/r2s`.
  * `XSCHEM_TEST_REAL_HOME` was never set to `/home/analog`.
  * Every `owed.sh` ran with `XSCHEM_OWED_DIR` set to a scratch ledger, or with a scratch HOME
    inside the suite.
* **`:99`:** never started, probed or stopped. `DEVDISPLAY_NUM` was 168 or 166 on every run.
* **Displays I started:**
  * fixtures `:167` (the drain) and `:166` (+openbox; T1 attach and drain);
  * the shim's `:160`–`:163`;
  * `test_devdisplay`'s own `:96` and `:85`–`:88`.
* **Teardown:** all stopped, by identity. Two stale locks (`:160`, `:161`) named Xvfbs *my*
  cleanup had SIGKILLed; they were removed after a content match. At the end: no `/tmp/.X16*-lock`,
  no process with a HOME under `r2s`, no `--reap` left, no throwaway in my TMPDIRs.
* **Not mine, left alone:**
  * `/tmp/xschem-test-home.2293885.*` and `.3155702.*` (the `r2t` crew's T1);
  * `.X100`, `.X101`, `.X152`, `.X157` and `.X159` locks seen mid-stage.
* **Main tree:** only read. The one write is this receipt; no git operation.
* **Not touched:** `~/dev/xschem-op-wcard`.

## Scratch for the driver

`/var/tmp/xschem_fixes/r2s` (936 MB): `tree` (the work clone, tag `r1base`), `base` (r1base,
built), `sab`, `tools/`, `runs/`, `canaries/`, `r2.patch`.
