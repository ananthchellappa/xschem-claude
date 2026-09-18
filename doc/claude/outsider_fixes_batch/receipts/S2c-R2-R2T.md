# S2c-R2-T: the Tcl half of D13 (crew R2T)

**Status: DONE.** Every D13 item assigned to the Tcl side is implemented and has a row that
went red first. T1 measured **87/86/0** on the integrated tree, with DISPLAY set to my private
Xvfb and a seeded canary as the parent HOME, and the canary stayed **byte-identical**.

There are two conditions on that result:
* Eight section-L rows (and, as a consequence, L2c/L2d) go green only once the **shell half** lands.
* One label in the shell crew's suite (`test_home_isolation_sh`, row S1) ends in `FAIL`, so T1
  counts it as a failure. See open problem 1.

Tags: **M** = measured (ran it; the numbers are quoted), **R** = read from source,
**I** = inferred.

## Deliverable

| item | value |
|---|---|
| incremental patch | `/var/tmp/xschem_fixes/r2t/r2.patch`, md5 `f0a2c22d9300354d074a43d715f214ba` |
| base | local commit `r1base` (`3d3d4c53`, tagged `r1base` in the clone) = `733e03ad` + `istamp_s1fix.patch` + `s2c_I/final_item2_only.patch` |
| files | `tests/test_utility.tcl` (+351/−63), `tests/run_regression.tcl` (+98/−2), `tests/headless/test_home_isolation.tcl` (+639/−37). Total: 3 files, +1088/−102 |
| unchanged | `tests/headless/test_regression_concurrency_1476.tcl`. No row needed to change: it stays at 37 checks, green (M) |
| apply check | `git apply --check` on a fresh clone at `r1base`: OK (M). The shell crew's patch touches disjoint files, and the two apply together (see `integ2` below) (M) |

`test_home_isolation` goes from **76 to 98 checks**.

## What was built, by D13 item (R: the code; the proof is under "Red first" and "Measured")

**D13.4, the banner when TMPDIR is inside the real HOME.**
* The line now reads: `test home: throwaway <TH> (your ~/.xschem is untouched; the throwaway
  lives under your HOME because TMPDIR does; XSCHEM_TEST_HOME=real to opt out)`.
* The loud `!! test home: note:` line stays.
* I took the wording **verbatim from the shell crew's in-progress `test_home.sh`**, so the two
  match. Row L11 locks that they do.
* The check is made on fully resolved paths.

**D13.5, `XSCHEM_TEST_HOME=<dir>` fully resolved.**
* New helper: `t1_home_resolve`. It resolves a child of the path, so the last component gets
  resolved too.
* A custom home that resolves to the real HOME (also resolved) is refused with rc 3. That covers
  a symlink, a symlink to a symlink, and a HOME that is itself a symlink.
* `t1_home_has_throwaway` also checks the resolved spelling.
* **A defect of the same class, found here and fixed (M).** On the round-1 build, a
  **symlinked TMPDIR** made *every* Tcl arm refuse, and it **leaked the directory it had just
  made**. The mktemp result was normalized and resolved, but the root was not. On macOS `/tmp`
  is itself a symlink, so this hits every such box. `t1_home_root` now resolves fully (row A5).

**D13.6, `.owner` = `<pid> <boot_id> <pidns>`.**
* New helpers: `t1_home_boot_id`, `t1_home_pidns` (reads `/proc/self/ns/pid`), `t1_home_read_owner`
  and `t1_home_owner_state`.
* **The rule, in order:**
  1. Boot IDs known on both sides and different: **dead**.
  2. Otherwise, pidns known on both sides and different: **foreign**. A foreign entry is swept
     only after 7 days.
  3. Otherwise the old rule applies (the pid's liveness decides), and our own pid counts as alive.
* A dead entry is still swept only after 300 s. A bare pid (the round-1 format) reads as `<pid> - -`.
* **One deliberate reading, recorded in the code:** `boot_id -` together with a pidns known to
  differ counts as **foreign**, not "old rule".
  * The shell crew wrote it that way.
  * The literal reading lets a host judge a container's pid by the host's `/proc`, which is the
    defect D13.6 exists to remove.
  * Row L7 holds the two sweeps to one answer on it (deviation 1).
* **The nesting test uses the same rule** (`t1_home_live_throwaway`). A HOME whose owner is alive
  only by its bare pid (another boot, or another pidns) is armed fresh, not reused. Row B3 covers
  this (deviation 2).
* The owner's own delete now requires `.owner` to equal exactly its own three fields.

**D13.7, kill only what can be identified.**
* New helpers: `t1_home_pid_home` and `t1_home_pid_is`.
* A recorded Xvfb or WM is killed only if its argv[0] name matches **and** the HOME in
  `/proc/<pid>/environ` is exactly the dead throwaway. "Exactly" means the same string, or the
  same fully resolved directory.
* So that T1's own display always satisfies this, **the private Xvfb is started with
  `env HOME=<run dir>`**. The WM already was. Without that, a private display under
  `XSCHEM_TEST_HOME=real`, custom or nested could never be identified, and would leak. Row H4
  now checks the server is stopped, and sabotage S15 shows that check going red.
* The panel rule is unchanged.

**D13.9, `.keep` at arm time.**
* New helpers: `t1_home_keep_asked` and `t1_home_keep_now`, called when the throwaway is
  created and when a run dir is created.
* The release still re-asserts the marker and prints the "kept" line.

**D13.10, `binary=`.**
* New helper: `t1_binary_path`, which does `auto_execok`, then `file normalize`, and falls back
  to `unresolved:<word>`.
* The result still passes through `t1_hdr_word`.

**D13.14, identity, not number.**
* H1b now compares the **content** of `/tmp/.X<n>-lock` with the pid it started. It also checks
  that no reaper for that home remains.
* The suite's fixture numbers (150–159) are now **reserved** with an `O_EXCL` file
  (`/tmp/xschem-homeiso-fixture.<n>`) naming the pid. A stale one (dead owner, older than 120 s)
  is taken over. `cleanup_started` releases them.
  * Why: two simultaneous runs used to be able to pick the same "free" number for H2 or H3.

**D13.15, a reaper for T1's private Xvfb and openbox.**
* New in `run_regression.tcl`: `t1_reaper_sh` and `t1_private_reaper`.
* It starts as soon as the server answers, and records itself in `.xvfb/reaper.pid`. It runs
  under `env -i PATH=…` (no HOME, no harness variables) and `setsid` where available.
* Every 5 s it compares the owner's **pid and start time** (`/proc/<pid>/stat` field 22).
* **A zombie owner counts as dead.** Measured: without this, the reaper waited on a `kill -9`'d,
  not-yet-reaped owner for more than 20 s (sabotage S9).
* When the owner is gone, it stops the WM (read from the record at reap time) and the server,
  using the D13.7 identity rule. It removes a lock only if that lock names the server. Then it
  exits.
* It also exits by itself as soon as the server is gone.
* The owner's own `t1_home_kill_xvfb` kills the reaper first, using the marker and the exact run
  dir on its command line.

**D13.16, the pre-switch environment is a snapshot.**
* `t1_arm_home` snapshots `array get ::env` before touching anything.
* `t1_home_preswitch_env` now returns `env -i` plus the whole cleaned snapshot, not `env HOME=…`
  layered over the current environment.
* `t1_home_clean_env` does the cleaning:
  * strips every `XSCHEM_TEST_*`;
  * puts back the XDG originals, and unsets any XDG variable that points into a throwaway;
  * removes this checkout's `safe.directory` entry from `GIT_CONFIG_*` and renumbers the rest;
  * drops `XSCHEM_DEVDISPLAY_DIR`, `GUI_GATE_DIR` and `XAUTHORITY` when they name a throwaway or
    just spell the default that `HOME=<real>` gives anyway. So a carried value the tester never
    set is gone, and a value they did set is kept (row A3e).
* **Shared with the shell. This goes beyond the D13 text; I adopted the shell crew's contract
  as I found it in their tree.**
  * The outermost arm exports `XSCHEM_TEST_PRE_ENV`: base64 of the NUL-separated `NAME=VALUE`
    list, `XSCHEM_TEST_*` removed, capped at 64 KiB.
  * An enclosed arm keeps an inherited snapshot.
  * A nested Tcl run starts its long-lived processes from it.
  * Rows L12a and L12b lock the encoding in both directions (deviation 3).
* The owner's release restores HOME and XDG from **this process's** own snapshot.

**D13.17.** `t1_hdr_word` maps `T1-RUN-` to `T1_RUN_`, after the whitespace mapping.

## Rows (test_home_isolation.tcl)

* **New rows:**
  * A3e, A4, A5
  * B3
  * D4, D5
  * E2c
  * F1c, F6
  * F7, which runs a live arm inside `bwrap --unshare-pid`
  * H1f, H2b, H5
  * H6, which kills a driver copy with `kill -9` inside the display arm
  * L6, L7, L8, L9, L10, L11, L12a, L12b
* **Changed rows:**
  * A1b: the three-field owner.
  * A3c, B1d and L2b: they now measure the *effective* environment of
    `exec {*}[t1_home_preswitch_env] env`, not the prefix's spelling.
  * F1b: the stand-in Xvfb now runs with HOME equal to the dead home.
  * H1b: identity (see D13.14).
  * H1e: the hostile binary is now a real executable. Its name contains a space, two newlines,
    `T1-RUN-END cases=87 blocks=86`, `FATAL` and a trailing `FAIL`.
  * H2: it now runs openbox too.
  * H4: the private Xvfb must be stopped.
* **Section L for the shell half.** L6–L12 are written against the **contract**:
  * L6 checks the `.owner` format.
  * L7 hands F6's 13-entry dead-rule matrix to the shell sweep.
  * L8 checks `.keep` at arm time.
  * L9 checks the symlink refusal, plus a symlink to a custom directory.
  * L10 checks kill identity through `.xvfb.pid`.
  * L11 checks the banner.
  * L12 checks the snapshot crossing.

  **Against the round-1 `test_home.sh`, these are red by construction: L2c, L2d, L6, L7, L8,
  L10, L11 and L12b** (M: `runs/dev6_hi`, 8 FAILED, all of them these rows). **Against the shell
  crew's in-progress tree, they are all green** (next section).

  ⚠ **The two halves must land together.** L7 measured the round-1 shell sweep reading a
  three-field Tcl `.owner` as garbage digits. It **swept a LIVE owner's home** (row SameLive:
  "swept, required kept"). A new Tcl beside an old `test_home.sh` is a real hazard, not just a
  red row.

## Red first (M)

**On the round-1 code.**
* `/var/tmp/xschem_fixes/r2t/r1` is the built tree with round-1 `test_utility.tcl` and
  `run_regression.tcl`, and the **new** suite file.
* Result: `RESULT: 25 FAILED (73 passed)`. The red rows: A1b, A3e, A4, A5, B1d, B3, D4, E2c, F1c,
  F6, F7, H1e, H1f, H2b, H5, H6, L2b, L6, L7, L8, L9, L10, L11, L12a, L12b (`runs/redfirst_r1_final`).
* The round-1 refuters' recipes, replayed as rows:

| recipe | round-1 build | fixed build |
|---|---|---|
| D4: a symlink to the real HOME | accepted as custom, and wrote into it | refused |
| F7 (bwrap): the owner's namespace pid is dead on the host | swept a live run | kept |
| F1c: the foreign Xvfb and openbox | killed | left alive |
| E2c: the killed KEEP run | swept | kept |
| H5 | `binary=xschem` | the stub's full path |
| H6 | the Xvfb outlived the kill by more than 20 s, with no reaper | stopped |
| H2b | Xvfb and openbox carried `XSCHEM_TEST_REAL_HOME`, `XSCHEM_DEVDISPLAY_DIR` and `GIT_CONFIG_*` | nothing from the harness |

* D5 (the non-vacuity half) is green on both builds, by design.

**Sabotages on the final code** (`tools/sab.py`, run in `integ`, where everything is green). Each
sabotage was applied alone, and the file was restored and checked by md5. **All 16 went red on
their target rows:**

| sabotage | what it breaks | rows that went red |
|---|---|---|
| S1 | `env`, not `env -i` | A3e, B1d, H2b, L2b, L12b |
| S2 | no foreign state | B3, F6, F7, L7 |
| S3 | no boot rule | B3, F6, L7 |
| S4 | kill by name only | F1c, L10 |
| S5 | no `.keep` at arm | E2c, L8 |
| S6 | bare `binary=` | H5 |
| S7 | no `T1-RUN-` map | H1e, H1f |
| S8 | no reaper | H6 |
| S9 | reaper blind to a zombie owner | H6 |
| S10 | `resolve` equals `normalize` | A5, D4, L9 |
| S11 | old banner | A4, L11 |
| S12 | snapshot not exported | L12a |
| S13 | inherited snapshot ignored | L12b |
| S14 | bare-pid `.owner` | A1b, L6, F7, plus 11 rows the owner re-check makes leak |
| S15 | Xvfb without `HOME=<run dir>` | H4 |
| S16 | nesting by bare pid | B3 |

**D13.14 red first is NOT reproduced by me.** In my 14 pairs, no run re-took a number the other
had just freed (all 28 H1b details say `a lock on :10x present=0`). So the old by-number check
would have stayed green there too. The red first for D13.14 is the regression refuter's
measurement on round 1: **1 red in 14 pairs**. The fix is by construction: a lock naming another
pid is not ours (R).

## Measured

**Suites.**

| where | test_home_isolation | 1476 | test_home_isolation_sh |
|---|---|---|---|
| `tree` (this patch alone) | 8 FAILED (89 passed): exactly the shell-half rows | ALL PASS (37) | ALL PASS (53), unaffected by the Tcl change |
| `integ2` (`tree` plus the shell crew's in-progress diff at 07:44, md5 `ca926fd6…`) | **ALL PASS (98)** | not run | **ALL PASS (80)** |

**14 concurrent standalone pairs (D13.14).**
* Where they ran: in `integ`, which is `tree` plus the shell crew's snapshot at 07:15, md5
  `b517edc7…`, where the suite is ALL PASS.
* How: both runs of each pair were launched in the same second, each with its own canary.
* Result: **14 of 14 pairs, 28 of 28 runs, `ALL PASS (98 checks)`**. The pairs' H1 used :102 and
  :103 (`runs/pairsI.summary`).

**T1** (`tools/t1.sh`). Every run used:
* HOME = a freshly seeded D11 canary;
* `DISPLAY=:159`, my own Xvfb (HOME = a scratch dir);
* `DEVDISPLAY_NUM=158` and `XSCHEM_TEST_XVFB_BASE=153`;
* a snapshot of the canary with `find -printf` plus an md5 of every file, and `iwatch`
  throughout.

| run | tree | trailer | canary | leftovers | per-case attribution |
|---|---|---|---|---|---|
| `t1_integ` | integ | `cases=87 blocks=86 counted_failures=4` | identical / identical, **0 events** | 0 | (a) `test_ase_optier_0963` X1 and X2: ngspice `rc=1 raw=-1bytes NORAW`, the flake CLAUDE.md records. Rerun twice standalone: **ALL PASS (109)** both times. (b) `test_home_isolation_sh`: that snapshot predates the shell crew's update of their suite. |
| `t1_integ2` | integ2 | `87/86/1` | identical, 0 events | 0 | The only counted line is `test_home_isolation_sh`'s **`ok: S1 … -- on a PASS and on a FAIL`**. It is an *ok* row whose label ends in `FAIL`, so it is counted by the `FAIL$` shape (the 0689 class). Every other block is at 0. |
| **`t1_integ2b`** | integ2, with **only that label reworded, in my scratch copy** | **`T1-RUN-END … cases=87 blocks=86 counted_failures=0 elapsed=516s`** | **identical / identical, 0 events** | **0**, no new throwaway, no new lock | 87 Start and 87 Finish; `wc -l` = 177 = 2 + 86 + 86 + 3 NOGOLD. Header: `home=throwaway binary=/var/tmp/xschem_fixes/r2t/integ2/src/xschem`. Display arm: `PRIVATE Xvfb :100 … wm openbox`. Case logs: test_home_isolation 98, 1476 37, _sh 80, optier 109 (all ALL PASS). |

**`kill -9` of a real T1 inside the display arm (D13.15)** (`tools/t1kill.sh`, on `tree`, DISPLAY
unset).
* Setup: T1 reached `Start headless/test_op_annot.tcl (display arm)` on `PRIVATE Xvfb :100`.
  Its reaper was alive. The Xvfb (3254496) and openbox (3254622) were alive.
* The kill: `kill -9` of the T1 tclsh.
* Result: **the Xvfb and openbox were both gone after 2039 ms**, and the reaper had exited.
* 15 s later, **no process carried that run's HOME**: the display case's xschem died with its
  display.
* No `/tmp/.X100-lock` was left, and the canary was byte-identical.
* For comparison, H6 on driver copies over 35 runs: **4717–4920 ms**.
* On round 1 the refuter measured survival until an unrelated run swept **305 s** later.

**Pre-switch environment (D13.16)** (H2b, every green run).
* The persistent display was auto-started through a canary state dir on a **reserved fixture
  number** (DEVDISPLAY_NUM in 150–159).
* Its Xvfb and openbox carry HOME = the canary and **no `XSCHEM_TEST_*`, no `GIT_CONFIG_*` and no
  `XSCHEM_DEVDISPLAY_DIR`**.
* The same row on round 1 listed all five in both processes.

## Deviations

1. **D13.6: `boot_id -` together with a known, different pidns counts as foreign.** The text
   says "where a field is `-`, the old rule applies". I measured the shell crew's reading, which
   is this one, and chose to agree with it: the literal reading reintroduces the container
   sweep, and one contract across both languages beats two readings. Row L7 enforces agreement.
   **The driver may prefer the literal rule.** If so, change one line in each language and flip
   F6's `BootDashFn` row.
2. **Nesting uses the D13.6 state, not the bare pid** (row B3). The contract does not say which.
   The shell crew's in-progress `test_home.sh` still nests on the bare pid. The two differ only
   for a HOME that is a throwaway from another boot or another pidns. No L row forces the shell
   to follow, so the driver can decide.
3. **`XSCHEM_TEST_PRE_ENV` is a new cross-language variable.** D13 does not name it. It is the
   shell crew's encoding, adopted as found (their tree, 07:15). Rows L12a and L12b lock it.
4. **1476 is unchanged.** Nothing in D13 needed a row there. D13.17 and D13.10 are covered by
   H1e, H1f and H5.
5. **My measurement environment:**
   * A lowercase clone at `/var/tmp/xschem_fixes/r2t`.
   * `integ` and `integ2`, which carry the shell crew's **in-progress** diffs. They are
     measurement copies only; nothing from them is in my patch.
   * In `integ2` I reworded **one label in their file** for the `t1_integ2b` run, to show 87/86/0.
6. **Red first on the round-1 build ran with the new suite file** in `r1/`. That is the only way
   rows that did not exist can be shown red on it.

## Open problems

1. **Shell crew: `test_home_isolation_sh.tcl`, row S1 (their line 951).** The label ends in
   `-- on a PASS and on a FAIL`. It is an `ok:` line, and T1 counts it as a failure through the
   `FAIL$` shape (M: `t1_integ2`, `counted_failures=1`). Any rewording that does not end in
   `FAIL`, `GOLD?` or `RESULT?` fixes it; mine was `… (both verdicts)`.
2. **The two halves must land together.**
   * A new `t1_arm_home` beside the round-1 `test_home.sh` means the old shell sweep reads a
     three-field `.owner` as garbage, and **sweeps live homes** older than 300 s (M: L7 on
     `tree`).
   * L2c, L2d, L6, L7, L8, L10, L11 and L12b are red until the shell half lands.
3. **D13.14 was not reproduced by me.** I cite the refuter's 1 red in 14; my 28 runs had no
   number reuse.
4. **Leftovers from others, and from my earlier runs.**
   * `/tmp/.X160-lock` names a dead pid (2643128, created 07:41:29). It is not in any of my
     outputs and not on my numbers, so I left it.
   * `:161`, `:162` and `:166` are live and belong to the shell crew (`HOME` under `r2s`).
   * Two stale locks were my own: `.X100` (1971112) and `.X101` (2100373). They came from the H6
     red on round 1 and from sabotage S8, where the code under test left its Xvfb and my cleanup
     SIGKILLed it. I removed both by identity, and the H6 cleanup now removes a lock naming its
     server, re-run on round 1 with none left (M).
5. **14 `/tmp/xschem_emergencysave_*` dirs appeared after my start.**
   * The `passgate`, `uapass` and `aswv` ones at 08:05–08:07 match my `t1kill` run: DISPLAY was
     unset, which triggers the F14 segfaults (I).
   * The `fix_*` ones match `test_file_menu_log`, which is not mine (I).
   * I left all of them.
6. **Custom-mode banner.** A custom home *inside* the real HOME still says "your HOME is
   untouched". D13.4 covers only TMPDIR, so I did not change it. The shell says the same.

## Real home

* **Marker:** `/var/tmp/xschem_fixes/r2t/.marker_start`, 06:46:00.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the start,
  mid-stage and at the end.
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate
  ~/.claude/xschem_owed ~/.cache/openbox -newer <marker>` printed **nothing**, mid-stage and at
  the end.
* **No interactive session:** the newest `/tmp/Xschem.log*` is `.4`, from 09-17 23:35.
* **HOME for every run:** a canary or scratch dir under `/var/tmp/xschem_fixes/r2t`. Nothing ran
  with `HOME=/home/analog`, and `XSCHEM_TEST_REAL_HOME` was never set to it. No `owed.sh` was run.
* **Displays:**
  * Mine: `:157` (optier reruns), `:159` (T1's DISPLAY) and the suite fixtures `:150`–`:153`.
    All were started with `HOME=` a scratch dir and stopped by pid.
  * Started by the code under test: T1's private arm at `:100`–`:103`.
  * `DEVDISPLAY_NUM` was 158 on every driver run, and the suite pins its own fixture number.
    **`:99` was never started, probed or stopped.**
* **At the end:**
  * no process with HOME under `r2t`;
  * no `xschem-t1-reaper`;
  * no `/tmp/xschem-test-home.*`;
  * no `/tmp/xschem-homeiso-fixture.*`.
* **Main tree:** only read. `git status` shows the same entries as the start snapshot, plus this
  receipt. `~/dev/xschem-op-wcard` was not touched.
* **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/r2t` (2.3 GB). It holds:
  * `tree`, `r1`, `integ`, `integ2` and `applycheck`;
  * `runs/`, `tools/` and `canaries/`.
