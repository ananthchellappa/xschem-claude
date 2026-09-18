# S2c-T: the Tcl side of Item 2 (crew T)

**Status: DONE.** The contract is D4 to D8, as the Tcl half.
- **Deliverable:** `/var/tmp/xschem_fixes/s2c_T/final.patch`, md5 `48d9c5eda9b0447b314aa41570878457`.
  It applies cleanly with `git apply` on a clone that has only S1's `tests/*` hunks.
- **HEAD:** `bc61cd05`, not `4b9565ad`. S1's patch applies only with `--include='tests/*'`
  now, because its DECISIONS.md hunk no longer matches. S and U hit the same thing.

| file | change |
|---|---|
| `tests/test_utility.tcl` | +474 lines. Adds `t1_arm_home` and its helpers, which run when the file is sourced. |
| `tests/run_regression.tcl` | +210 lines. Adds the D8 display arm, the `home=` and `binary=` header fields, the owner's delete after the trailer, and registers the new suite. **T1 is now 86 cases.** |
| `tests/headless/test_regression_concurrency_1476.tcl` | +21 lines. Adds row **V4b**: `home=` and `binary=` come before `canonical=`, which stays last. The suite now has 37 checks. |
| `tests/headless/test_home_isolation.tcl` (new) | 50 rows. Takes about 9 s headless. |

Every claim below is tagged **M** (measured), **R** (read from source) or **I** (inferred).

## What was built

**`t1_arm_home` (D4).**
- It runs when `test_utility.tcl` is sourced. That covers `tclsh run_regression.tcl` and the
  documented `tclsh netlisting.tcl`.
- Calling it twice changes nothing (idempotent), and it knows when it is nested.
- It does nothing inside an xschem interpreter, which it detects as `info commands ::xschem`.
- **R:** nothing in the tree sources `test_utility.tcl` inside xschem. The only sourcers are
  `run_regression.tcl`, the three golden cases, and 1476's child tclsh probes and staged
  driver copies. So that guard is a promise about future callers. Row **K1** pins it on an
  emulated xschem interpreter.

**D5 rules, as implemented:**
- **Naming:** the throwaway is `mktemp -d ${TMPDIR:-/tmp}/xschem-test-home.<pid>.XXXXXX`.
- **The arm refuses** (exit 3, a loud stderr message, and never a fallback to the real HOME)
  in these cases:
  - mktemp fails, or its result equals the real home or is an ancestor of it;
  - `XSCHEM_TEST_REAL_HOME` is not an absolute, existing directory that is not itself a
    throwaway. `=1`, relative paths, missing paths and throwaway paths are all refused.
    It is never read as a flag.
- **`.owner` and `.xschem`:** `.owner` holds the owner's pid. `.xschem` is created with
  mode 700.
- **Nested** means all three conditions hold: HOME matches the throwaway pattern, its
  `.owner` names a live pid, and `XSCHEM_TEST_REAL_HOME` is set. A nested run reuses HOME
  silently. It never creates and never deletes.
- **The delete:** only the owner deletes (`t1_home_release`), and only the exact path it
  created. First it re-checks four things:
  - the path is directly under the temp root it was made in;
  - it matches the pattern;
  - its `.owner` still names this pid;
  - it is not the real home or an ancestor of it.

  `run_regression.tcl` calls this after the `T1-RUN-END` trailer and the publish step.
- **The sweep** runs at arm time. It removes an entry only if all of these hold: same uid, a
  real directory (never a symlink), the name matches, the owner is dead, and the entry is
  older than 300 s. It first kills a recorded `.xvfb.pid`, and the WM in `.xvfb/wm.pid`,
  but only while that pid is still running the program named in the record.

**D6, what the run says about itself:**
- `XSCHEM_TEST_HOME=real` prints a loud banner on every run.
- `XSCHEM_TEST_HOME=<dir>` uses that directory as HOME and never deletes it.
- A fresh throwaway prints one line:
  `test home: throwaway <TH> (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)`
- The header now reads:

  ```
  T1-RUN-BEGIN pid= script= start= planned_cases= verdict= home=<throwaway|real|custom> binary=<sanitised> canonical=results.log
  ```

**D7, what is carried from the real home.** Each variable is set only if it is not already
set:
- `XSCHEM_TEST_REAL_HOME`;
- `XSCHEM_DEVDISPLAY_DIR`;
- `GUI_GATE_DIR`, only if that directory exists;
- `XAUTHORITY`, only if the file exists;
- `XDG_*`, repointed into the throwaway only if already set. The original value is exported
  as `XSCHEM_TEST_PRE_XDG_*`, the name S chose.
- git `safe.directory`, appended as `GIT_CONFIG_KEY_n`/`VALUE_n` with `GIT_CONFIG_COUNT`
  raised by one, and never duplicated.

`t1_home_preswitch_env` returns `env HOME=<real> …` for long-lived processes. A nested run
answers with the real home too, not with its parent's throwaway.

**D8, T1's display arm:**
1. Attach through the carried state dir.
2. Auto-start the dev display only if the state dir exists, and then with the pre-switch
   environment.
3. Otherwise, or if that start fails, use a **private Xvfb** numbered from 100 up:
   - its pid is recorded before the wait, in `$run/.xvfb.pid`;
   - it is routed through `devdisplay.sh exec`, given a per-run state dir and number for
     each exec, so `DISPLAY` never enters `::env`;
   - it is killed when the arm is done, and again by the release.
4. NODISPLAY is reported only when no Xvfb is installed. An Xvfb that is installed but will
   not start is a **counted** `HARNESS … : FAIL`.
5. When `dcases` is empty, no display is started. 1476's staged copies need this: before
   the guard existed, they timed out (M).

## Measured

All T1 runs used a **seeded canary as the parent HOME** (D11 seed), `DISPLAY` unset, and
`DEVDISPLAY_NUM=158`.
- **Why 158:** so that nothing ever probed `:99`, not even with a read-only `status`. The
  shipped default would run `devdisplay.sh status` against `:99`.
- **Snapshots:** `find -printf '%P %y %s %T@ %m'` plus md5 of every file, before and after.
  Transient writes were recorded by `iwatch.py`, where `events=1` means only its `READY`
  line.

| run | tree | verdict trailer | canary | display arm |
|---|---|---|---|---|
| `base_t1` | unfixed, `s2c_T` path | cases=85 counted_failures=26 | **CHANGED**: clipboard, geometry, clean.spice and short.spice rewritten; created `.claude/xschem_dev_display/*`, `.cache/openbox`, `.xschem/op_annot`. **Left a persistent Xvfb :158 + openbox running (F36)**, which I stopped. | persistent :158 |
| `tree_t1` | fixed, `s2c_T` | cases=86 blocks=85 counted_failures=26 | byte-identical, events=1 | PRIVATE :100 |
| `tree_real_t1` (**red first**) | fixed, `XSCHEM_TEST_HOME=real` | counted_failures=26, `home=real` | **CHANGED**: clipboard, geometry, clean.spice, short.spice | PRIVATE :100 |
| `pair_t1` A/B | fixed, concurrent, 20 s stagger | both 86/85/26, both trailers | byte-identical, events=1 | :100 and :101 |
| `lc_base_t1` | unfixed, lowercase path | cases=85 counted_failures=**8** | CHANGED (as base_t1) | persistent :158 |
| `lc_tree_t1` | fixed, lowercase | cases=86 counted_failures=**8** | byte-identical, events=1 | PRIVATE :100, **11/11 dcases at 0** |
| `lc_attach_t1` | fixed; canary has a live state dir at fixture :157 | 86/85/8 | byte-identical **including the state dir**, events=1 | "attached to the dev display", 11/11 at 0 |
| `lc_pair_t1` A/B | fixed, concurrent, final code | both 86/85/8 | byte-identical, events=1 | :100 and :101, 11/11 each |
| `lc_combo_t1` | S1+T+S+U patches together, 88 cases (S and U suites registered in this clone only) | 88/87/**9** | byte-identical, events=1 | PRIVATE :100 |
| `lc_final_t1` | **byte-final code** (= final.patch) | 86/85/8, **86 Start / 86 Finish** | byte-identical, events=1 | PRIVATE :100 (pid 4124041, openbox), 11/11 at 0 |

**Attribution, per case, never by count (M).**
- **In `s2c_T` (26):** base and fixed are identical per case, and the failing lines are
  byte-identical after pid normalisation. The only extra case is `test_home_isolation`, at 0.
  - **8 of the 26** are the four F14 segfault suites (op_annot, optier_0963,
    unused_attr_0970, auto_specialize_1201).
  - **18 of the 26** are D12's recorded uppercase-path finding, reproduced in all five
    named suites: sp_1452, converge_1459, campaign_1462, campaign_gui_1464 (both arms) and
    variant_1470. **My assigned stage dir is `s2c_T`, with a capital T.**
- **In lowercase paths (8):** base and fixed are identical per case (the F14 four only), and
  every display case is green on the private arm.
  - **Why the lowercase runs exist:** the private arm could only be shown fully green there.
  - **The deviation:** I used a sibling dir, `/var/tmp/xschem_fixes/s2c_tlc`.
- **The combined tree's one extra failure** is U's suite (see open problem 1).

**Concurrency (M).**
- Two throwaways (`…3950193.ACZ4VR` and `…3958516.BUTKBu`) were both present in **66**
  samples, taken 5 s apart.
- Each run printed its own banner and its own private display. B also printed
  `NOTE: another regression run is live`.
- Neither run deleted the other's home. Each verdict's per-case result equals the solo
  run's.
- Afterwards there was no throwaway, no `/tmp/.X10[01]-lock`, and no process carrying
  either HOME.

**Kill test (M; run twice, the second time on final code).**
- **The kill:** T1 was killed with `kill -9` after `display arm: PRIVATE Xvfb :100` appeared.
  That left behind:
  - the home, with `.xvfb.pid`;
  - Xvfb :100 and openbox;
  - a display-arm xschem;
  - two `sleep 48.x` from an hcase. These are pre-existing and exit by themselves.
- **The sweep:** I backdated the home's mtime by 400 s with `touch -d @<epoch>` (the
  contract has no age knob, so none was added). The next arm printed
  `test home: swept 1 dead run(s)' throwaway home(s) … (xschem-test-home.4031408.m6EKAY)`.
  - The recorded Xvfb was gone, and openbox and the orphaned xschem went with it.
  - No process carried the dead HOME.
  - TMPDIR was empty after the follower, and the canary was byte-identical.
- **The two followers:** a full T1 the first time, which then ran green per case, and
  `tclsh netlisting.tcl` the second time.

**`tclsh netlisting.tcl` shape (D11 shape 4, M):** rc 0 and the banner printed. The canary
was byte-identical and no throwaway was left.

**Suites (M):**
- `test_home_isolation`: ALL PASS (50 checks) in `s2c_T`, in the lowercase clone (three runs
  in a row) and in the combined tree.
- `test_regression_concurrency_1476`: ALL PASS (37 checks), both standalone and inside T1.
  **1476 went red once during development:** its staged driver copies, with `dcases={}` and
  no `headless/devdisplay.sh`, timed out in my first private-arm loop. That is fixed and is
  the reason for rule 5 of D8 above.
- In the combined tree, S's `test_home_isolation_sh` gave ALL PASS (53) and U's
  `test_scratch_home_note` gave ALL PASS (20).

**Red first (M).** `sab/sabotage.py` applies each sabotage alone, runs the suite (plus 1476
for S34) and restores the file, which is checked by md5 before and after. All **41** entries
went red on the intended rows. The one exception is **S31**, a deliberate no-red control:
the release backstops the loop's teardown, and S31b removes both and goes red.
- **Examples:**
  - no source-time arm → A1a–A3d;
  - the owner never deletes → A2a, B1c, H1b;
  - nesting never detected → B1a, B1b;
  - the `XSCHEM_TEST_REAL_HOME` validation removed → C1–C4;
  - the absolute-path check removed → C2, using a relative path that exists;
  - mktemp failure falling back to the real HOME → J1, J2;
  - the uid, liveness, age, type, `.keep` and Xvfb-kill checks removed from the sweep → F5,
    F3, F2, F4, E2b and F1b;
  - the gate dir or the dev-display dir not carried → A3a/A1d and **G1**;
  - XDG set unconditionally → A3c;
  - no safe.directory → A3d. This row uses git's own `GIT_TEST_ASSUME_DIFFERENT_OWNER` and
    reproduces the refusal: without the carry, git refuses.
  - the private arm turned into NODISPLAY → H1a, H3;
  - the auto-start inheriting the throwaway HOME → H2, where the Xvfb's
    `/proc/<pid>/environ` HOME must be the canary;
  - no fallback after a failed start → H3;
  - `binary=` moved after `canonical=` → H1d and 1476's V4b;
  - no sanitising → H1e, where a hostile `XSCHEM` carries a space, a newline, `FATAL` and a
    trailing `FAIL`;
  - a nested run's pre-switch env being the parent's throwaway → B1d;
  - the private WM inheriting the real HOME → H4.
- **The G1 classifier** also went red in the combined tree when the spawn_reaper allowlist
  entry was removed: `offenders: spawn_reaper.sh:323`, which is U's `${HOME:-}` spelling.

## Deviations (no contract name was renamed)

1. **A fresh arm refuses when HOME is itself a throwaway and `XSCHEM_TEST_REAL_HOME` is
   unset.** D5 says "anything short of all three is a fresh arm", but that arm would have
   to export a throwaway as the real home, and D5's own validation would then refuse it in
   every child. S made the same call. The row is B2c.
2. **Only-the-owner-deletes has a second trigger.** The Tcl owner also releases through a
   wrapped `exit`. A single case (`tclsh netlisting.tcl`) has no trailer, and a T1 that dies
   of a Tcl error has no children left. `run_regression.tcl` still calls the release
   explicitly, after the trailer.
3. **`XSCHEM_TEST_KEEP_HOME` writes `.keep`, and the sweep skips any entry that has one.**
   The reason: a home kept for inspection that the next run deleted 300 s later would not
   have been kept. This narrows the sweep, so the failure direction stays "a leftover
   survives". The rows are E2a and E2b. It also accepts any Tcl true value; S accepts
   exactly `1`.
4. **How the private Xvfb is numbered and routed.** It uses `:N`, starting at 100, rather
   than `-displayfd`, because `devdisplay.sh`'s identity check needs `:N` in argv. It is
   routed through `$dd exec`, with a per-exec `XSCHEM_DEVDISPLAY_DIR=$run/.xvfb
   DEVDISPLAY_NUM=N`. That keeps row V57 of `test_op_annot.tcl`, whose launch line must say
   `$dd exec` (R, and green in every T1).
5. **The private arm starts a WM** (`DEVDISPLAY_WM`, default openbox), so it matches the dev
   display. The WM gets **the run's own directory as HOME in every mode**. Measured before
   this change: under `XSCHEM_TEST_HOME=real`, openbox wrote `~/.cache/openbox` into the
   real home. The row is H4.
6. **In nested, custom and real modes the private display is recorded in its own owned
   `xschem-test-home.<pid>.*` directory**, not in HOME. Otherwise real mode would write into
   the real home, and a nested T1 would collide with its parent's `.xvfb.pid`.
7. **`XSCHEM_TEST_HOME=<the real HOME>` is refused**, with a pointer to `=real`, which also
   warns. S instead treats it as `real`.
8. **The refusal exit code is 3**, while S uses 2. I kept 3 because CLAUDE.md assigns rc 2
   a retired meaning for T1.
9. **Banners go to stdout** (S uses stderr). Under T1, a golden case's stderr turns into an
   `exec` error.
10. **For measurement only:** `DEVDISPLAY_NUM=158` in every T1 run, and the lowercase
    sibling dir `/var/tmp/xschem_fixes/s2c_tlc`.

## Open problems

1. **U's `test_scratch_home_note` cannot be registered in T1 as it stands.** It prints
   `RESULT: ALL PASS (20 checks)` but no whole-line `OVERALL: ok`. In the combined tree
   that was **one counted `HARNESS … : FAIL`** (M, `lc_combo_t1`). The fix is to add the
   banner line.
2. **Registration of S's and U's suites** is the driver's call. They are not in my patch,
   because the files are not in this tree. Registered in the combined clone, T1 has
   **88 cases** and every other case is green (M).
3. **Where the two languages still disagree:**
   - `.keep`: the shell side neither writes nor honours it, so a kept Tcl home is swept by
     a shell arm.
   - the refusal code: 3 here, 2 in the shell;
   - `=<real HOME>`: refused here, treated as `real` in the shell;
   - the banner stream: stdout here, stderr in the shell;
   - the truth values accepted for `KEEP`.

   Each is a one-line alignment on one side.
4. **TMPDIR inside the real home is silently allowed**, following D5 literally. S prints a
   warning instead. S already lists this for the driver.
5. **G1's allowlist entry for `test_gui_gate_batch.sh` matches nothing once U's patch is
   in.** U reads the file through `XSCHEM_TEST_REAL_HOME`. The row reports unused entries
   and does not fail on them.
6. **In any checkout path with an uppercase letter, 18 extra counted failures appear** in
   the five D12 ASE suites. This was measured again here (M). The finding is recorded, not
   fixed.
7. **Sabotage runs S31b and S36 leaked Xvfb and openbox by construction**, because they
   remove the code that kills them. I killed them by pid after checking HOME. The suite now
   reaps any Xvfb or openbox whose HOME is inside its own scratch.
   - **A stale `/tmp/.X150-lock`** came from the suite's own TERM-then-KILL race. I removed
     it, the teardown is fixed, and three consecutive runs left no lock.

## Real home

- **The manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** at the
  start and at the end.
- **The find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate
  ~/.cache/openbox -newer <start marker 01:34:50>` printed **nothing**.
- **No interactive session:** the newest `/tmp/Xschem.log*` is `.4`, from 09-17 23:35.
- **Every xschem, tclsh, Xvfb and openbox run** used HOME = a canary or a scratch dir under
  `/var/tmp/xschem_fixes/s2c_T` or `s2c_tlc`, with DISPLAY unset.
- **Displays:**
  - I used `:100`–`:102` (T1's private arm), `:150`–`:151` (suite fixtures), `:157`
    (attach fixture) and `:158` (the unfixed base's own auto-start).
  - All of them are stopped, and no `/tmp/.X1*-lock` is left.
  - `:99` (1209045/1209133) was never started, stopped, viewed or probed by me.
- **One slip:** at 01:35 a mis-scoped `cd` put a clone (`base/`) and `build_base.log` into
  the **main tree** for about one minute. I checked that the clone's remote was the main
  tree, removed both paths exactly, and nothing else there was touched.
- **Left alone:** git in the main tree, `~/dev/xschem-op-wcard`, and the
  `/tmp/xschem_emergencysave_*` entries.
- **Scratch for the driver to delete:** `/var/tmp/xschem_fixes/s2c_T` (989 MB: tree, base,
  canaries, runs, sab, tools) and `/var/tmp/xschem_fixes/s2c_tlc` (1.5 GB: the lowercase
  tree, base and combo clones).
