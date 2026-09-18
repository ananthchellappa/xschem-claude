# S2c-R2-R2I: integrate round 2 (crew R2I) — the integration half

**Status: DONE.** The two round-2 patches merged with no conflict, and the two helpers now
implement **one** contract, D13 included. Section L of `test_home_isolation.tcl` is green against
the integrated shell helper, with five new rows locking what D13 made common and was not yet
locked. Three defects (A, B, D below) were found **by the proof** and are fixed here. Each was measured red first.
**The end-to-end proof, shape by shape, is in `S2c-R2-I.md`.**

Tags: **M** measured (ran it; output quoted), **R** read from source, **I** inferred.

## Deliverables

| file | md5 | what it is |
|---|---|---|
| `/var/tmp/xschem_fixes/r2i/r2.patch` | `d93723d36919616a90f96e5d230624a4` | Incremental on `r1base`: R2T + R2S + this stage. 14 files, +2491/−239. No new files. |
| `/var/tmp/xschem_fixes/r2i/final_item2_only.patch` | `ce1e512325a91e3f058f00abc1a259d1` | **The full Item-2 diff** against the clone's original HEAD, without the two issue-stamp files. 25 files, +5806/−54. |

* **Check against the main tree** (read-only): `git -C /home/analog/dev/xschem-claude apply --check
  /var/tmp/xschem_fixes/r2i/final_item2_only.patch` gave **rc 0** (M).
* **Base.** The main tree's HEAD was **`616110a6`** at clone time (D14, which touches only
  `DECISIONS.md` and the two issue-stamp files), not `733e03ad`. So the clone's original HEAD, and the
  base of `final_item2_only.patch`, is `616110a6` (M: `git show --stat 616110a6`).
  * Main has since moved to **`52453f1e`** (D15, D16: docs only). None of the 25 files differ across
    any of these commits.
  * `apply --check` was re-run at `52453f1e`: **rc 0**.
* **Local commits in `/var/tmp/xschem_fixes/r2i/tree`:**
  * `r1base` (`05881657`) = `616110a6` + `istamp_s1fix.patch` + `s2c_I/final_item2_only.patch`;
  * `r2applied` = R2T and R2S applied;
  * `r2i_1` … `r2i_4` = this stage's four steps. `r2i_4` (`a64dca23`) is final.

## Merge (M)

* `git apply --3way` of `r2t/r2.patch` (md5 `f0a2c22d…`), then `r2s/r2.patch` (md5 `ca20322b…`), on
  `r1base` gave **"Applied patch … cleanly" for all 13 files**. The two patches touch disjoint files, so
  there was nothing to resolve.
* `./configure && make` gave rc 0.
* On that tree as merged, before any change of mine:
  * `test_home_isolation` ALL PASS (98);
  * `test_home_isolation_sh` ALL PASS (82);
  * `test_regression_concurrency_1476` ALL PASS (37).
* R2T's open problem 1 (row S1's label ending in `FAIL`) was **already fixed** in R2S's final patch:
  0 counted shapes in all three suites' output (M).

## Is it ONE contract? (R, then locked by rows)

`t1_arm_home` / `test_utility.tcl` and `test_home_arm` / `test_home.sh` were read side by side against D13.

**Agreed as delivered, and already locked:**
* `.owner` format (L6);
* the dead rule, including the `boot_id -` + other-pidns = foreign reading both crews chose (L7, F6);
* `.keep` at arm (L8);
* the symlink-to-real-HOME refusal (L9);
* kill identity through `.xvfb.pid` (L10);
* the TMPDIR banner (L11);
* the `XSCHEM_TEST_PRE_ENV` encoding and inheritance (L12a/b).

**Disagreed, or agreed but unlocked. Aligned here, one row each:**

| # | what | as delivered | now | row |
|---|---|---|---|---|
| 1 | **Nesting rule** (R2T deviation 2) | Tcl nests only under an owner **alive by D13.6**. The shell nested on the **bare pid**. | Shell `_th_owner_alive`: its boot_id not known-different, its pidns not known-different, its pid alive. **Tcl's rule adopted**, because the sweep may delete a home whose owner is from another boot or pidns, so reusing it is unsafe. | **L13** |
| 2 | **`.owner` first field** | Tcl: `^[1-9][0-9]{0,9}$`, else fall back to the name's pid. Shell: any digit string. So `0<pid>` or 11 digits was judged **dead** by the shell and the home of a live owner was swept, while Tcl kept it. | Shell uses Tcl's test. | **L14** |
| 3 | **Custom-home banner** (open problem in both receipts) | `custom <dir> (never deleted; your HOME is untouched)` even when the dir is inside the real HOME. | Both say `(never deleted; it is inside your HOME, so this run writes there)` in that case. This is D13.4's rule applied to the one other mode it covers. | **L11b** |
| 4 | **WM kill identity** | Both sweeps read `.xvfb/wm.pid` + `.xvfb/wm` by identity. Only F1c locked it, and only for Tcl. | Handed to both sweeps. | **L10b** |
| 5 | **D13.5, two more shapes** | Both agreed, but nothing locked them. | A symlink **into** a throwaway is refused by both. A HOME that is itself a symlink to the real home, with `XSCHEM_TEST_HOME=<its physical path>`, is refused by both. | **L9** (2 entries added) |

**R2S open problem 3b is checked and needs no change.** The Tcl suite's children all run under
`env -i` (`kid`, `rundrv`), so there is no scrub list to extend. The shell suite's scrub list already
names `XSCHEM_TEST_PRE_ENV` and `XSCHEM_TEST_HOME_WRAPPED` (R: its line 89).

**Left different on purpose, as round 1 documented:**
* the refusal rc (3 in Tcl, 2 in the shell);
* the routine stream (stdout in Tcl, stderr in the shell);
* HOME unset (Tcl arms with the passwd home; the shell refuses);
* the nested banner (the shell repeats it);
* real mode (only the shell exports `XSCHEM_TEST_REAL_HOME` and `XSCHEM_TEST_PRE_ENV`).

## Defects the proof found, fixed here (each red first, M)

**A. T1's private display arm could take a server it does not own**, a race between two
concurrent runs. This is round-1 D8 code. It was **found while attributing shape 10's one red**:
* 1 of the 28 concurrent standalone `test_home_isolation` runs went red on H6:
  `before the kill: {xvfb 1 wm 0 reaper 1}`.
* **That red itself turned out to be D below**, which reproduced with A already fixed. But reading
  the arm for it exposed A in the same code, and A is measured on its own.
* **Cause.** `t1_private_xvfb` treats "`devdisplay.sh status` passes" as "our server is up". That
  status asks two separate questions: is the recorded pid alive and named `Xvfb :N`, and does
  *something* answer on `:N`.
* **When two runs pick the same free number in the same instant**, the server that loses the lock
  **does not exit at once**. So both runs got "yes" to both questions, and both took the winner's
  display.
* **Replica** (`r2i/race/arm.tcl`: the up-check's logic on `:181`–`:184`, two copies started at the
  same millisecond):
  * both claimed `:181` in **3 of 30 pairs**;
  * the loser's Xvfb was **still alive 1.5 s later**, with the lock naming the other pid.
* **With the identity check in the replica: 0 of 30.** The race happened 3 times and was detected 3
  times (`LOST :181 …, trying next`).
* **In the real arm** (driver copies started three at a time, D's repro below), the fixed arm printed
  `went to a concurrent run` for **7 of 60** copies on each of r2i_3 and r2i_4. Each one moved to the
  next number, and every copy ended on a display of its own.
* **Fix** (`run_regression.tcl` `t1_private_xvfb`): "up" also requires `/tmp/.X<n>-lock` to name the pid
  we started. This is D13.14's identity rule. Otherwise the arm prints `display arm: :N went to a
  concurrent run …`, stops its own server and tries the next number.
* **Row H7** forces the race deterministically: the first `Xvfb` the arm starts launches a real server
  on the same number as another pid, and then stays alive, as a slow loser does.
  * **Red on the unfixed arm** (sabotage SI9): `the arm said :100 … the case saw DISPLAY=:100`, which
    is the number it lost.
  * **Green on the fix:** `:101`.

**B. `test_scratch_home_note` row C4 was red on every `full_audit.sh`** after D13.11 landed.
* It is not in T1, so neither crew ran it. Shape 3 did: `SUMMARY: 391 pass 12 fail`, where round 1 had
  11.
* C4 extracts every `grep -E` from `run_suites.sh` and requires that none matches the note and skip
  lines. D13.11 added `grep -E '^skip:'`, whose whole job is to echo exactly those lines under the
  verdict.
* **Fix:**
  * C4 sets that one ERE aside by name.
  * A new row, **C5**, requires the echo to exist and to match exactly the `skip:` lines.
* **Result:**
  * r2i_1: `1 FAILED (19 passed)`;
  * fix: `ALL PASS (21 checks)`;
  * sabotage SI10 (the echo removed): C5 red.

**C. Integration items 1–5 above**, each red first on the half as delivered (the table below).

**D. T1's private arm sometimes ran WM-less: openbox died at startup.**
* This was H6's other red: in the batch's pairs and in a sabotage run on r2i_3, which already had fix
  A, it read `{xvfb 1 wm 0 reaper 1}`.
* Reproduced with real driver copies (`r2i/wmrace/one.sh`, three started together).
  * openbox's own log in the failing home said **`Failed to open the display from the DISPLAY
    environment variable`**.
  * Its Xvfb was alive, and on its own number.
* **Cause (I, from the measurements):**
  * An X server resets when its last client disconnects.
  * The arm's up-check (`devdisplay.sh status`: xdpyinfo, xprop, xlsclients) and the WM's claim wait
    (xprop every 100 ms) are clients that come and go **before openbox has connected**.
  * So openbox can arrive in the middle of a reset.
* **Measured:**

  | how | without `-noreset` | with `-noreset` |
  |---|---|---|
  | probe of that exact client sequence (`wmrace/probe2.sh`) | **12 of 360** openbox deaths | **0 of 360** |
  | real driver copies | **2 of 60** | **0 of 60** |

  * The same 60+60 driver copies also hit fix A's race **7 times each**, which shows how often
    simultaneous starts share a number.
* **The shell private arm does not have it:** `xvfb_arm.sh --arm`, 0 of 240 (`wmrace/armprobe.sh`,
  M). xvfb-run starts no probe client before the WM, so it is left unchanged.
* **Fix:** T1's private Xvfb starts with `-noreset`. The persistent dev display never resets either,
  because its openbox stays connected.
* **Row H6b** checks the private server's own argv. It is red on sabotage SI11.

## Red first for every guard added here (M; `r2i/tools/sab.py`, one edit at a time, md5-restored)

| id | sabotage | red rows |
|---|---|---|
| SI0 | a comment (control) | **none**: ALL PASS (102) |
| SI1 | shell nesting back to the bare pid (R2S as delivered) | **L13** |
| SI2 | shell `.owner` parse back to any digits (R2S as delivered) | **L14** |
| SI3 | shell custom banner as delivered | **L11b** |
| SI4 | Tcl custom banner as delivered | **L11b** |
| SI5 | shell WM kill by name only | **L10b** |
| SI6 | shell custom-dir check on the given spelling only | **L9** |
| SI7 | Tcl `t1_home_has_throwaway` without the resolved spelling | **L9** |
| SI8 | Tcl nesting by bare pid | **B3, L13** |
| SI9 | T1 private arm without the lock-identity check | **H7** |
| SI10 | `run_suites.sh` without the `^skip:` echo (on `test_scratch_home_note`) | **C5** |
| SI11 | T1's private Xvfb without `-noreset` | **H6b** |

Final suite counts (M, r2i_4):
* `test_home_isolation`: 98 → **104** (L10b, L11b, L13, L14, H6b, H7);
* `test_home_isolation_sh`: **82**;
* `1476`: **37**;
* `test_scratch_home_note`: 20 → **21**.

**The crews' own matrices, re-run on the integrated code** (details in `S2c-R2-I.md`):
* R2T: 16 of 16 red on target;
* R2S: 30 of 30 red on target, and the control green.

## Deviations

1. **Base `616110a6`, not `733e03ad`** (see above).
2. **The nesting rule** was decided for Tcl's reading (R2T deviation 2), and the shell was aligned.
   The other contract points beyond D13's text are kept as the crews built them:
   * the `boot_id -` + other-pidns = foreign reading;
   * `XSCHEM_TEST_PRE_ENV`;
   * `XSCHEM_TEST_HOME_WRAPPED`;
   * `--wm-launch-own` / `--reap`.

   Each is locked by a row or by the shell suite.
3. **The custom-home banner**: D13.4 names only TMPDIR; I applied its rule to custom mode too. Both
   crews listed that as open.
4. **Defects A, B and D are fixes outside D13's list.** All three were found by this stage's proof. A is
   the D13.14 class in round-1 code, and D is a round-1 D8 flake.
   * `devdisplay.sh start` has D's shape too: it probes, then starts openbox. It is not in this batch's
     diff and is not changed; it is listed as an open problem in `S2c-R2-I.md`.
5. **Not changed:** `xvfb-run -a` numbers from `:99` (R2S open problem 1). See the open problems in
   `S2c-R2-I.md`.
