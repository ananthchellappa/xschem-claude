# S2c-R3-prove: independent end-to-end proof of Item 2 on the round-3 build (crew R3P)

**Status: DONE.** D11 was run in full on the round-3 build, and every shape was run twice, once with a
**seeded** canary and once with an **empty** one, as the parent `HOME`.

* **Every canary stayed byte-identical in every shape**, by whole-canary snapshot and by 0 inotify
  events. The one exception is AUTO-START, which changed only D13.2's scoped files.
* **Nothing was left running and no `xschem-test-home.*` was left.**
* **Red first on the baseline:** each of the three newly armed launchers changed its canary.
* **T1 is 87/86/0** solo, and **per case identical to the baseline** except for 1476 and the two new
  suites.
* **The round-2 refuters' recipes** go red on a round-2 clone and green on round 3.

One T1 in twelve carried counted lines: `test_ase_optier_0963` X7, the known ngspice flake. Attributed
below: the same suite in T1's own shape then passed 3 of 3.

Tags: **M** = measured (I ran it; the output is quoted), **R** = read from source, **I** = inferred.

## Trees and patches (M)

| tree | contents | build |
|---|---|---|
| `/var/tmp/xschem_fixes/r3p/tree` (local commit `e9e8ec9e`) | `9fbc6fd9` + `istamp_s1fix.patch` (md5 `7600660c…`) + `r3b/final_item2_only.patch` (md5 **`b6a4367b7728701395b66f70a6e00cb1`**) | configure + make rc 0 |
| `tree2` | a `--no-hardlinks` clone of `tree`, git index identical, built separately. It let shell shapes run beside a T1 without sharing `tests/` scratch. | rc 0 |
| `base` (`8d145789`) | `9fbc6fd9` + istamp only: the HEAD+istamp baseline | rc 0 |
| `r2` (`10f6217c`) | `aa5cece0` + `r2i/final_item2_only.patch` (md5 `ce1e5123…`): the round-2 code, **for the refuters' recipes only** | rc 0 |

* **The main tree's HEAD moved during the stage.** The driver committed **`aa5cece0`** (Item 1) after I
  cloned `9fbc6fd9`.
  * `git -C <main> apply --check …/r3b/final_item2_only.patch` at `aa5cece0` gives **rc 0**. It is
    read-only.
  * `aa5cece0` touches none of the patch's files (it changes the issue-stamp files and docs).
  * The proof trees keep `istamp_s1fix.patch` as briefed. So `test_issue_stamp` in my T1s is that
    version (64 checks, ALL PASS), not `aa5cece0`'s.
* **All four local HEADs carry a hex letter**, so the all-decimal `HEAD` trap of the issue-stamp
  fixtures cannot fire.

## Method (M; tools in `/var/tmp/xschem_fixes/r3p/tools`)

**Canaries (`seed.sh`), every mtime pinned `@1789000000`:**
* **seeded:** D11's set:
  * a sentinel `.xschem/.clipboard.sch`;
  * `simulations/clean.spice` and `short.spice`;
  * a 100-entry `geometry`;
  * `recent_files` and `ase_simulators`;
  * `.spiceinit`, `.ngspice_history` and `.gitconfig`;
  * **plus** the tester's `~/untitled~.sch`;
  * **plus** a sentinel owed ledger `.claude/xschem_owed/{rule/9999,suite/…}`;
  * plus `.Xauthority` and `Documents/`.
* **empty:** a bare directory.
* **dev / devempty:** each of the above plus an empty `.claude/xschem_dev_display`.

**Every run goes through `run.sh`:**
* `env -i`, with `HOME` = the canary, DISPLAY unset unless given, and `XSCHEM_OWED_DIR` = the canary's
  own ledger path. That is stricter than a stranger's setup: any owed write lands in the canary.
* The xvfb-run shim is first on PATH.
* Before and after, a snapshot: `find -printf '%p %y %s %T@ %m'` plus an md5 of every regular file.
* `iwatch.py` (copied from `s2a_redirect/tools`, `diff` identical) records inotify events over the
  whole canary.
* After the run, `leftovers.py` lists every live process whose environment or argv names the canary,
  or whose HOME or argv names a throwaway the run announced or that appeared during it.
* It also lists throwaways left in `/tmp` and new X locks.

**T1 runs** add R2I's `dsample.py`, a 20 ms sampler of every xschem the run started, with its
DISPLAY. Artefacts: `r3p/runs/<label>/{summary,snap.diff,iwatch.txt,out.txt,procs_left.txt,verdict.log,caselogs/}`.

**Display numbers, all mine (180–189):**

| numbers | use |
|---|---|
| `:189` | T1's DISPLAY |
| `:188` | lookshot's `LOOK_DISPLAY` and the drain's `--display` |
| `:186` | ATTACH fixture (`-audit 4` + openbox) |
| `:187` | `DEVDISPLAY_NUM`, so AUTO-START starts here |
| `:184`/`:185` | `DEVDISPLAY_TEST_NUMS` / `DEVDISPLAY_TEST_FOREIGN_NUMS` |
| `:180`–`:183` | every real `xvfb-run`, through the shim (it drops any `-n`, puts the first free number first, and logs the argv it was handed) |

* `AUDIT_XVFB_BASE` and `XSCHEM_TEST_XVFB_BASE` were set to 180.
* **`:99` was never started, probed or stopped.**

**Attribution under overlap.** Several shapes ran alongside each other (listed under Deviations). A
process flagged in one run's scan is attributed to its owner by the throwaway named in the other run's
own banner. Each such attribution is stated where it occurs.

## The shapes

### 1. T1, `cd tests && tclsh run_regression.tcl` (M)

| run | tree | canary | DISPLAY | trailer (cases/blocks/counted), elapsed | `wc -l` | canary | events | left |
|---|---|---|---|---|---|---|---|---|
| **`t1_fix_seed_disp`** (solo) | fix | seeded | `:189` | **87/86/0**, 487 s | 177 | identical | 0 | 0 |
| **`t1_fix_empty_disp`** | fix | **empty** | `:189` | **87/86/0**, 531 s | 177 | **still empty** | 0 | 0 |
| `t1_base_seed_disp` (solo; red first) | base | seeded | `:189` | 85/84/0, 424 s | 173 | **CHANGED** | 2836 | **Xvfb `:187` + openbox, HOME=canary** |
| **`t1_fix_seed_nodisp`** (solo) | fix | seeded | unset | **87/86/8**, 414 s | 185 | identical | 0 | 0 |
| **`t1_fix_empty_nodisp`** | fix | **empty** | unset | **87/86/8**, 443 s | 185 | **still empty** | 0 | 0 |
| `t1_base_seed_nodisp` (solo; red first) | base | seeded | unset | 85/84/8, 330 s | 181 | **CHANGED** | 2549 | **Xvfb `:187` + openbox, HOME=canary** |
| **`t1_pairA`** (concurrent) | fix | seeded | `:189` | **87/86/0**, 666 s | 177 | identical | 0 | 0 |
| **`t1_pairB`** (concurrent) | fix | **empty** | `:189` | **87/86/0**, 661 s | 177 | **still empty** | 0 | 0 |

**Every fix T1** has 87 `Start` / 87 `Finish` and the header `home=throwaway
binary=/var/tmp/xschem_fixes/r3p/tree/src/xschem`.

**Display arm.** `PRIVATE Xvfb :100 for this run only` (the pair used `:100` and `:101`). The sampler
put 12 xschem pids on it (the 11 dcases plus one child) and every other xschem on DISPLAY `:189`, or
unset.

**The new suites, in every fix T1:**
* `test_home_isolation` **ALL PASS (111)**, with 0 `skip:`;
* `test_home_isolation_sh` **ALL PASS (87)**;
* 1476 **ALL PASS (37)**.

G2 printed `UNARMED: none`.

**Per case, fix vs base** (`percase.py` on the verdicts, `checks.py` on the last `RESULT` of each case log):
* **DISPLAY set** (seeded, and empty):
  * all **84 shared blocks** carry identical counted lines (none);
  * **84 of 85** shared case logs have the same `RESULT` line. The one difference is
    `test_regression_concurrency_1476`, 37 against 36.
  * The only blocks outside the shared set are `test_home_isolation` and `_sh`.
* **DISPLAY unset** (seeded, and empty):
  * the 8 counted lines are **exactly the four F14 suites**, `FATAL: signal 11` plus a HARNESS line each:
    `test_op_annot`, `test_ase_optier_0963`, `test_unused_attr_0970` and `test_auto_specialize_1201`;
  * the base has the **same 8, per block**;
  * all other shared blocks are identical;
  * `RESULT` lines match in 84 of 85, with 1476 again the difference.

**The pair.**
* **A (seeded)** printed `NOTE: another regression run is live in this tree (pid: 1395395)`.
* **B (empty)** finished 5 s earlier. Its scan listed A's still-running display arm (HOME
  `…1395398.QN5NBV`, A's banner) and A's `:101` lock.
* A's own scan at its end found **0 processes and 0 throwaways**.
* The two verdicts are identical per block.

**Red first (base).** Both base T1s changed the canary. Seeded, DISPLAY set:
* clipboard **102 → 220 B**;
* `clean.spice` and `short.spice` **34 → 146 B**;
* `geometry` **4964 → 4792 B**;
* `.xschem/op_annot/`, `.cache/openbox/` and `.claude/xschem_dev_display/` created;
* and a **persistent Xvfb `:187` + openbox left running with HOME=canary** (F36).

The DISPLAY-unset base run gave the same list. Both leaked displays were stopped with the fix's
`devdisplay.sh stop`, using `XSCHEM_DEVDISPLAY_DIR` = that canary's state dir and
`DEVDISPLAY_NUM=187` (`stopped :187`, both pids gone).

### 2. `run_suites.sh` on the 5 writer suites (M)

The suites: `test_crossview_paste`, `test_signal_short_nohier_0230`, `test_no_untitled_litter`,
`test_schpins_stale_lab_0185` and `test_op_annot`.

| run | cwd | canary | result | canary | events | left |
|---|---|---|---|---|---|---|
| `rs_repo_fix2_*` | repo | seeded / empty | 5/5 PASS (op_annot 492) | identical / still empty | 0 / 0 | 0 |
| `rs_canary_fix2_*` | **the canary** | seeded / empty | 5/5 PASS | **identical, `untitled~.sch` included** / still empty | 0 / 0 | 0 |
| `rs_canary_base_seeded` (red first) | the canary | seeded | 5/5 PASS | **CHANGED** | 593 | 0 |
| `rs_real_fix2` (D11's opt-out red first) | repo | seeded | 5/5 PASS | **CHANGED** | 570 | 0 |

* **The base run changed:**
  * the tester's **`untitled~.sch` 101 → 219 B**;
  * clipboard 102 → 107;
  * clean/short 34 → 146;
  * geometry 4964 → 5207;
  * and it created `.cache/openbox`.
* **`XSCHEM_TEST_HOME=real` on the fix** changed clipboard 102 → 107, clean/short 34 → 147, geometry
  4964 → 5209 and created `.cache`. It printed `!! test home: REAL -- … this run reads and WRITES your
  own HOME`.
* **The skip echo (D13.11):** under op_annot's verdict, `run_suites.sh` printed
  `| skip: W23 … (no action log -- run with --logdir)`.
* **Flags in the seeded cwd=repo run:** its scan listed 33 processes. All of them carried HOME
  `…1652563.W598Eo`, which is the concurrently started empty T1's own banner.

### 3. `full_audit.sh`, bounded at 120 min, run from cwd = the canary (M)

| run | canary | SUMMARY | canary | events | left | peak throwaway |
|---|---|---|---|---|---|---|
| `audit_fix2_seeded` | seeded | `392 pass 11 fail 0 crash/timeout 2 skip (total 405)`, 951 s | identical | 0 | 0 of its own | **84 KB**, 189 samples |
| `audit_fix2_empty` | **empty** | `392 pass 11 fail 0 crash/timeout 2 skip (total 405)`, 944 s | **still empty** | 0 | 0 of its own | **84 KB**, 188 samples |

* **The 11 fails are exactly the pre-existing list** of rounds 1–3:
  * `altf5_ciw`, `ase_dialogs`, `cadence_drag`, `cosim_golden_e2e`;
  * `lib_manager_gui`, `lib_sweep`, `results_dialog`;
  * `rotate_stretch_short_0104`, `selflog_output`;
  * `wave_sigbrowser_0312`, `wave_sigbrowser_keys`.
* The rest of each run's report:
  * `WIREEDIT: ALL PASS`;
  * `SCRATCH: 0 leaked`;
  * `TREE: 0 appeared 0 vanished`.
* rc 1 is the audit's own exit for those 11.
* **Processes flagged at each end** belong to the concurrent ATTACH/AUTO-START T1 (HOMEs `…0tgd1b` and
  `…ew34DR`, from their banners).
* At most 2 throwaways existed in `/tmp` at once: the audit's and the concurrent T1's.

### 4. The tcases standalone: `tclsh netlisting.tcl`, `create_save.tcl`, `open_close.tcl` (M)

All three are armed launchers in G2's list.

* **Each, seeded and empty:**
  * rc 0;
  * `Running 736 netlisting jobs` / `5 create_save jobs` / the open_close jobs on 16 workers;
  * `No gold folder`;
  * canary **identical / still empty**;
  * 0 events, 0 processes left;
  * the announced throwaway is gone.
* **No red first is possible here.** The in-tree binary is built and `/usr/local/bin` is empty, the
  same as in rounds 1–2.

### 5. The 7 standalone `.sh` suites and `test_devdisplay.sh` (M)

`bash tests/headless/<t>.sh`, and `test_devdisplay.sh` through its shebang, from cwd = the repo.

| suite | fix, seeded and empty: canary / events / left | ok, FAIL | base (seeded): canary | verdict fix = base |
|---|---|---|---|---|
| `test_action_log` | identical / 0 / 0 | 10 ok | **CHANGED** (`.cache/openbox`) | yes |
| `test_action_replay` | identical / 0 / 0 | 11 ok, `1 FAILED` | **CHANGED** (+ `geometry`) | yes: same FAIL lines (md5), pre-existing |
| `test_file_menu_log` | identical / 0 / 0 | 4 ok, `1 FAILED` | **CHANGED** | yes: same FAIL lines (md5), pre-existing |
| `test_flylines` | identical / 0 / 0 | 43 ok | **CHANGED** | yes |
| `test_readonly_action_dispatch` | identical / 0 / 0 | 4 ok | **CHANGED** (+ `geometry` 4964 →) | yes |
| `test_readonly_guard` | identical / 0 / 0 | 13 ok | **CHANGED** | yes |
| `test_recent_launchlog` | identical / 0 / 0 | 19 ok | **CHANGED** | yes |
| `test_devdisplay.sh` (numbers 185/184) | identical / 0 / 0 | **ALL PASS (43)** | not run | — |

* **Why base `test_devdisplay` was not run:** it predates `DEVDISPLAY_TEST_NUMS`, so it would have
  used `:85`–`:96`, which are not my numbers.
* **Banners:** each fix run printed exactly one `test home:` banner.

### 6. `owed.sh drain`, one shell debt and one Tcl debt, in a scratch ledger (M)

**Setup:** the ledger is `r3p/ledgers/<label>`. The debts were added with `owed.sh add suite
test_readonly_action_dispatch.sh` and `add suite test_crossview_paste` (that step, through `run.sh`,
left its canary identical). The drain was `drain --display :188`, with `GUI_GATE_AUTOSTART=3`.

* **Fix, seeded and empty:**
  * `drained: 2 run, 2 passed, 0 failed`;
  * the ledger then holds only `cleared.log`;
  * canary **identical / still empty**, 0 events, 0 processes left.
  * **D17.9:** **one** `test home:` banner per debt. The drain's subshell arm printed one; the shell
    suite's nested `--arm` stayed silent.
* **Base (red first):**
  * clipboard 102 → 201;
  * `.claude/gui_test_gate/` created in the canary (96 events);
  * **a `wish gui_gate_widget.tcl` panel left running with HOME=canary**. I killed it by identity
    (argv[0] `wish` and that exact HOME).

### 7. `run.sh` and `run_nogui.sh` (M)

| run | fix, seeded and empty | base (seeded) |
|---|---|---|
| `sh tests/headless/run_nogui.sh` | identical / still empty, 0 events, `RESULT: PASS` | **CHANGED**: a 1 205 043 B `.xschem/simulations/0_examples_top.spice` (393 events) |
| `sh tests/headless/run.sh` | identical / still empty, 0 events, `== HARNESS: PASS ==` | identical: it is already hermetic, so there is no red first (as rounds 1–2 found) |

### 8. The launchers newly armed in round 3: RED FIRST on the baseline (M)

| launcher | fix seeded | fix **empty** | base seeded | base **empty** |
|---|---|---|---|---|
| `lookshot.sh out.png pose.tcl -timeout 20`, `LOOK_DISPLAY=:188` | identical, 0 events; PNG 1110x791 | **still empty** | **CHANGED**: `.cache/xschem-winshot/{build.log,winshot}` (21792 B) | **CHANGED**: that plus `.xschem/` and `.xschem/xschemrc` (34595 B) |
| `netlist_diff.sh <bin> <bin>` (default LIBROOT, all 5 formats) | identical; `RESULT: BYTE-IDENTICAL (885 netlists)` | **still empty** | identical (the seeded `.xschem` hides first-run creation) | **CHANGED**: `.xschem/` and `.xschem/xschemrc` (34595 B) |
| `run_wireedit.sh` | identical; `WIREEDIT: ALL PASS` | **still empty** | identical (same reason) | **CHANGED**: `.xschem/` and `.xschem/xschemrc` (34595 B) |

* **This is D17.2 in the flesh.** For netlist_diff and wireedit, only the empty canary sees the base
  write.
* **The lookshot base seeded run did not evict a `geometry` entry.** The round-2 refuter saw one, so
  that part depends on timing (I). Its winshot cache write is deterministic.
* **Flags in `lookshot_fix_seeded`:** its scan listed 8 processes and 2 throwaways. They were the
  concurrent pair's T1s (HOMEs `…1395395.WjDKeF` and `…1395398.QN5NBV`, from the pair's own banners).
  Lookshot's own throwaway, `…1395399.UKz64L`, is gone.

### 9. Every launcher G2 lists as armed (M)

* **G2 standalone.** `g2_scan` was extracted verbatim and run on each tree (read-only).
  * **fix:** 22 armed, 18 inside, 3 allowlisted, **0 offenders**. This reproduces the build's claim.
  * **base:** 12 armed and **40 offender lines**.
* **All 22 armed launchers were run above:**
  * `create_save.tcl`, `netlisting.tcl` and `open_close.tcl` (§4);
  * `run_regression.tcl` (§1), and `test_utility.tcl`, which every tcase sources;
  * `full_audit.sh` (§3), `gated_xschem.sh` (§10), `lookshot.sh` (§8);
  * `run.sh` and `run_nogui.sh` (§7), `run_suites.sh` (§2);
  * the 7 `--arm` suites and `test_devdisplay.sh` (§5);
  * `test_home_isolation_sh.tcl`, inside every T1 and full_audit;
  * `netlist_diff.sh` and `run_wireedit.sh` (§8).

### 10. `gated_xschem.sh --pipe -q --nolog --script <abs>/test_crossview_paste.tcl`, from cwd = the canary (M)

* **Fix, seeded and empty:** `PASS=28 FAIL=0`, `OVERALL: ok`; canary identical / still empty; 0 events;
  0 processes left.
* **Base (red first):** clipboard changed and `.cache/openbox` created (58 events).

### 11. ATTACH (M; `attach.sh`)

**Setup:**
* My `Xvfb :186 -audit 4` and openbox, with HOME = my scratch.
* The canary's `.claude/xschem_dev_display` names them: `display :186`, `screen`, `wm openbox`,
  `xvfb.pid` and `wm.pid`.
* Run with `DEVDISPLAY_NUM=186` and DISPLAY `:189`.
* The "empty" canary holds **only** those state files.

| run | trailer | display arm | dcases on `:186` (sampler) | of them in `:186`'s own audit log | canary (state dir included) | left |
|---|---|---|---|---|---|---|
| `attach_seeded` | 87/86/**2** (see "Counted lines") | `attached to the dev display (state dir …/attach_seeded/.claude/xschem_dev_display)` | 12 | **12 of 12** | identical, 0 events | 0; fixture untouched |
| `attach_empty` | **87/86/0** | attached (`…/attach_empty/…`) | 12 | **12 of 12** | identical, 0 events | 0; fixture untouched |

### 12. AUTO-START (M; `autostart.sh`)

**Setup:** the canary has an **empty** `.claude/xschem_dev_display`, `:187` is down, `DEVDISPLAY_NUM=187`
and DISPLAY is `:189`.

| run | trailer | display arm | dcases on `:187` | canary changes | the started Xvfb `:187` and openbox |
|---|---|---|---|---|---|
| `autostart_dev` (seeded) | **87/86/0** | `started the dev display (state dir …, with the pre-switch HOME)` | 12 | **only** `.claude/xschem_dev_display/{display,screen,wm,wm.pid,xvfb.pid}` (plus the dir's mtime) and `.cache/openbox/{openbox.log,sessions/}`. 18 events, all in those paths. | HOME = the canary; **0** `XSCHEM_TEST_*`, `GIT_CONFIG_*` or `XSCHEM_DEVDISPLAY_DIR` |
| `autostart_devempty` | **87/86/0** | the same | 12 | the same scoped set, 17 events | the same: HOME = the canary, 0 harness variables |

* **The started processes' environment** holds exactly `AUDIT_XVFB_BASE`, `DEVDISPLAY_NUM`,
  `DEVDISPLAY_TEST_FOREIGN_NUMS`, `DEVDISPLAY_TEST_NUMS`, `DISPLAY`, `HOME`, `LANG`, `LOGNAME`, `PATH`,
  `PWD`, `SHELL`, `SHLVL`, `TERM`, `USER`, `XSCHEM_OWED_DIR` and `_`. That is my own launch environment
  and nothing of the harness.
* **Cleanup:** both displays were stopped afterwards with `devdisplay.sh stop`, using the canary's state
  dir and `:187` (`stopped :187`).
* **The other processes each scan flagged** belong to the concurrent full_audit (HOME `…nOfImf`, from
  its banner).

## The round-2 refuters' recipes: red on round 2, green on round 3 (M; `recipes.sh`)

Each recipe used a fresh seeded canary. "r2" is the `r2` clone. The TMPDIR recipes use a relative
`TMPDIR=tmp`.

| D17 | recipe | r2 | round 3 (fix) |
|---|---|---|---|
| .3 | `run_suites` from cwd = the canary, with `tmp/` present | **rc 1, NORESULT** (`binary never reported`). **Litter left in the canary:** `tmp/xschem-test-home.1709530.e23gz9/{.owner,.xschem}` | rc 0, PASS. The throwaway is `/…/canary/tmp/xschem-test-home.…` (absolute) and is deleted. **Only `tmp/`'s mtime changed** (the D13.4 case), and the banner says so. |
| .3 | the same, cwd outside HOME and outside the checkout | rc 1. **Litter in that cwd:** `tmp/xschem-test-home.1709872.arSmLj` | rc 0; the cwd's `tmp/` is empty afterwards; canary identical |
| .3 | `gated_xschem.sh` from cwd = the canary | rc 1. `!! test home: NOT deleting tmp/xschem-test-home.…: its .owner names pid <none>`, and the litter is left | rc 0; only `tmp/`'s mtime changed |
| .3 | Tcl: `tclsh create_save.tcl`, `TMPDIR` relative to `tests/` | rc 0, clean (Tcl normalised it even in r2) | rc 0, clean |
| .4 | HOME = `<canary>/xschem-test-home.1.forged` (`.owner` `1 - -`), `XSCHEM_TEST_REAL_HOME=<canary>`, `run_suites` | **used the forged dir as its home**. Canary changed: `.cache/openbox`, … inside it (58 events) | `!! … is named like a throwaway but is not directly under the temp root (/tmp), so it is not reused; arming a fresh one`. Canary identical. |
| .4 | the same through `tclsh create_save.tcl` | nested silently. Its writes were not visible in this canary (I) | the same note; armed fresh; canary identical |
| .5 | `XSCHEM_TEST_HOME=<dir>` whose `.xschem` is a symlink to `<canary>/.xschem`, `run_suites` | banner `custom … (never deleted; your HOME is untouched)` while **clipboard 102 → 201, geometry 4964 → 5210, clean/short changed** | **refused, rc 2**: `has .xschem -> …/canary/.xschem, inside your real HOME`. Canary identical. |
| .5 | the same, Tcl | rc 0 | **refused, rc 3**: `!! test home REFUSED … Nothing was run` |
| .5 | custom `.xschem/simulations` symlinked into the canary | **clean/short 34 → 144 B** | **refused, rc 2**. Canary identical. |
| .6 | `devdisplay.sh stop`, canary state dir with `xvfb.pid` and `wm.pid` = two live `sleep` decoys and `/tmp/.X185-lock` naming decoy 1 | **both decoys killed, lock removed** | **both decoys alive, lock intact.** `stop` cleaned only its own state files. |
| .6 | the state dir's `xvfb.pid` = **my real `Xvfb :186`**, `DEVDISPLAY_NUM=185` | **my `:186` fixture killed** | `:186` alive and its lock intact |
| .8 | a stand-in `xvfb-run` logs the argv `xvfb_arm` hands it | `-a -s …`, **no `-n`**, so numbering starts at `:99` | unset → `-n 200 -a`; `99` → **`-n 100 -a`** plus `…below 100 -- using 100`; `abc` → `-n 200 -a` plus `…not a display number -- using 200`; `250` → `-n 250 -a` |
| .8 | every real xvfb-run of the stage (the shim's argv log) | — | xvfb_arm always handed `-n <base> -a`. `:99` was never requested. |

## D17.7, the kill window (M; the build crew's `k9_*` tools re-pointed at my numbers)

**Recipe.** A PATH stand-in `Xvfb` records its start time and execs the real one. The tester's pid is
`kill -9`ed at a random 50–150 ms after that. Afterwards I check whether the run's Xvfb or WM is still
alive about 10 s later.

| path | fix | red side |
|---|---|---|
| shell: `run_suites.sh`, which by then is xvfb-run | **0 of 20** (kills at 60–151 ms, 8 of them under 100 ms) | **base: 5 of 5** Xvfb left (58–153 ms) |
| T1: a driver copy's private arm | **0 of 20** (52–141 ms) | **r2: 8 of 10** left |

Every leaked server was killed by identity afterwards (argv[0] plus HOME). No process with the trials'
HOME is left.

## D17.9 end to end: an installed Xvfb that will not start (M; `t1_h8_brokenx`)

**Setup:** T1 on the fix with a PATH `Xvfb` that exits 1, and DISPLAY `:189`.

* **The display arm:** `display arm: NONE -- Xvfb is installed but no display number from :100 up
  could be started (20 tried)`.
* **The dcases:** **each of the 11 is a counted `HARNESS: <dc> display arm NOT RUN -- Xvfb is
  installed but no display could be started (…): FAIL`**, with **0 `NODISPLAY` lines**.
* **The other two counted lines** are `test_home_isolation` and `_sh`, whose fixture rows need a
  working Xvfb.
* **The totals:** `counted_failures=13`, and the canary identical with 0 events and 0 processes left.
* **Issue 1481, measured:** the same run printed **87 `Start` / 76 `Finish`**. That is 1481's
  display-arm asymmetry measured, where CLAUDE.md calls it "derived, not measured". `cases=87` in the
  trailer was right.

## Every counted line in this stage, attributed (M)

**`test_ase_optier_0963` X7, 2 lines, in `attach_seeded` only.** That is 1 of the 10 T1 runs with a
working display.
* **What failed:** `MEASURE X7 rc=1 raw=-1bytes` and `doAnalyses: TRAN: Timestep too small … RUN-FAILED`.
  That is the ngspice convergence flake the round-2 regression refuter attributed to issue 1455's X7.
* **Why it is not Item 2 (R, and the M below):** X7 uses PATH ngspice and a per-suite rundir, not HOME.
* **The re-run:** the suite in T1's own shape (`run_suites.sh --nogui`: a private display with DISPLAY
  set, `SUITE_TIMEOUT=900`) went **`ALL PASS (109 checks)` 3 of 3**, and that canary stayed identical.
* **Load:** `attach_seeded` overlapped the seeded full_audit.

**The four F14 suites, 2 lines each, in the four DISPLAY-unset T1s.** They are identical in fix and base
(D13.12).

**The 13 lines of `t1_h8_brokenx`,** which are the purpose of that run.

**Nothing else counted.**

## Observations (none of them writes into HOME)

1. **A throwaway is orphaned when `xvfb-run` exits without ever running the command.** It is swept by
   the next arm once it is 300 s old (M).
   * **How I saw it:** my stand-in `xvfb-run`, which only logged its argv, left 4 throwaways in `/tmp` on
     both r2 and the fix. The pre-exec owner became xvfb-run and died, and no re-exec'd driver ever took
     ownership.
   * **What happened next:** the next armed run printed `test home: swept dead throwaway(s):` and named
     exactly those 4, at 337–347 s old. That matches D5's contract. I removed the 4 r2 ones myself (named
     by my outputs, owners dead).
   * **The realistic variant is clean.** With a PATH `Xvfb` that exits 1, xvfb-run's `-a` loop gives up
     after 10 tries and then runs the command anyway. I read that in `/usr/bin/xvfb-run`, and the fix
     always passes `-a`. The driver took ownership and deleted its home, and the canary stayed identical.
     rc was 1, from xvfb-run's own `clean_up` of the dead server (the build's defect-A shape).
2. **A TERMed xvfb-run leaves its auth dir `/tmp/xvfb-run.XXXXXX`.** Its EXIT trap does not run on
   TERM. That is the same pre-existing class the build recorded for SIGKILL, and it is not in HOME. The
   one I caused (`/tmp/xvfb-run.M8clHO`) is removed.
   * **What TERM did clean up:** the TERMed `run_suites` (rc 124) still deleted its throwaway, stopped its
     Xvfb, released `:181` and let its reaper exit. Canary identical.
3. **`test_ase_optier_0963` stalls on `run_suites`' display arm.** It hit TIMEOUT after 200 s on run 1.
   This is CLAUDE.md's recorded display-arm stall, where T1 runs it headless only. I stopped that re-run
   and used T1's `--nogui` shape instead (above).
4. **Display numbers chosen by the code under test, outside 180–189:**
   * T1's private arm `:100`–`:101` (hard-coded; the build's open problem 4);
   * the k9 T1 driver copies `:100`+;
   * `test_home_isolation`'s fixtures 150–169.

   **In the broken-Xvfb shell run,** xvfb-run's `-a` loop named numbers up to about `:190`, but its PATH
   `Xvfb` was the stub that exits, so no server existed there.

## Deviations

1. **Two extra clones.**
   * **`tree2`**, the same commit as `tree`: the shell shapes, recipes and full_audit ran there so they
     could overlap T1s without sharing `tests/` scratch.
   * **`r2`**, which is `aa5cece0` + the round-2 patch: the round-2 red side for the D17 recipes and the
     T1 kill window. The brief's baseline for newly armed entry points is `base`, and that is what §8 uses.
2. **Overlap.** Each comparison T1 ran **solo**: fix and base, with DISPLAY set and unset. The following
   overlapped:
   * the pair with the launcher shapes;
   * the empty T1s with the `tree2` shapes and the recipes;
   * attach with the seeded audit;
   * auto-start with the empty audit;
   * H8 with the kill trials and the X7 re-runs.

   Every cross-run flag is attributed above by the owning run's banner.
3. **The canary carries more than D11's list:** `.Xauthority`, `Documents/`, `untitled~.sch` and a
   sentinel owed ledger. And `XSCHEM_OWED_DIR` points into the canary, which is stricter than a
   stranger's setup.
4. **My measurement tools themselves ran with my shell's HOME:** `dsample.py`, `leftovers.py` and the
   `k9_*` harnesses. They read `/proc` and start drivers only under `env -i HOME=<scratch>`, and the
   real-home check below covers them. xschem, T1, the suites, owed.sh and devdisplay.sh never ran with
   `HOME=/home/analog`.
5. **The base standalone `test_devdisplay.sh` was not run** (its numbers are `:85`–`:96`). The round-3
   one ran on `:184`/`:185`.
6. **The first X7 re-run used the wrong shape** (the display arm). It was stopped by TERM and redone as
   `--nogui`. Its canary was identical and it left nothing.

## Open problems

1. **The orphaned-throwaway shape in Observation 1 depends on the sweep**, meaning a later arm at least
   300 s on. It is not in HOME. It is recorded, not changed.
2. **18 new `/tmp/xschem_emergencysave_*` dirs were left in place.** They fall in my run windows
   (15:13–15:37 and 16:20–16:24) but no output of mine names them. I removed the **12** my case logs
   named: the DISPLAY-unset F14 segfaults.
3. **Stage F still owes** the CLAUDE.md scoping of the done-claim (D13.2) and the D12 issue files. I
   would add one fact to them: 1481's 87/76 split is now **measured** (§D17.9).
4. **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/r3p` (1.9 GB). It holds tree, tree2,
   base, r2, canaries, runs, k9, aux, ledgers, shim and tools.

## Real home (M)

* **Marker:** `/var/tmp/xschem_fixes/r3p/.start_marker`, 2026-09-18 14:39:56.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the start (14:39), at
  about 15:01, at 15:45 and at the end (16:36).
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate ~/.claude/xschem_owed
  ~/.cache -newer <marker>` printed **nothing**, every time, including at the end.
  * **A wider look** (`~` to depth 2, excluding `dev/` and `.claude/*`) showed only Claude Code's own
    files: `.claude.json`, `.claude/.credentials.json` and `.claude/backups`.
  * **`~/.claude/xschem_dev_display` is untouched** (files dated 2026-09-15).
* **No interactive xschem:** the newest `/tmp/Xschem.log*` is still `.4`, from 09-17 23:35. No new one
  appeared.
* **HOME for every xschem, T1, suite, driver, owed.sh and devdisplay.sh run** was a canary or scratch
  dir under `/var/tmp/xschem_fixes/r3p`.
  * `XSCHEM_TEST_REAL_HOME` was never `/home/analog`.
  * `owed.sh` always had `XSCHEM_OWED_DIR` set to a scratch or canary ledger.
  * The fork ngspice was not needed. No D10 shape was in this brief.
* **Displays:**
  * `:99` was never started, probed or stopped. `DEVDISPLAY_NUM` was 185, 186 or 187.
  * The real state dir was only read.
  * My fixtures `:186`, `:188` and `:189` were stopped by pid after an identity check (argv plus HOME).
  * The auto-started `:187`s and base's two leaked `:187`s were stopped with `devdisplay.sh stop` against
    their canary state dirs.
* **At the end:**
  * **no `/tmp/.X*-lock` at all**;
  * no `/tmp/xschem-test-home.*`;
  * no `/tmp/xvfb-run.*` of mine;
  * no process whose environment or argv names `r3p` or a throwaway.
* **Other sessions:** the driver committed `aa5cece0` in the main tree during the stage. The main tree's
  `git status` shows `.xschem/` and other untracked paths that are not mine, and `~/dev/xschem-op-wcard`
  was not touched.
* **Main tree:** only read, cloned and `apply --check`ed, plus this receipt written.
