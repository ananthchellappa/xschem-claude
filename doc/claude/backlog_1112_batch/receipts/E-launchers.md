# Stage E receipt: run_suites.sh, full_audit.sh and gated_xschem.sh step aside too

Crew: stage E implementer, 2026-11-12. Base `6ac33dd2b` (HEAD). Uncommitted. Every command ran
with `unset DISPLAY`; the only displays used were fixture dev displays and private Xvfbs in
270-291 (mine, killed by pid or by `devdisplay.sh stop` on their fixture state dir) plus the
T1 driver copies' private Xvfbs from `:100` (stage B's fixed base, already declared by B-verify).
`:99` was never attached, run on or probed beyond a read of `/proc`. No T1 was run.

## 1. What changed

- **New `tests/headless/dev_display_users.tcl`.** It now holds the detector. `t1_proc_words`,
  `t1_proc_envget`, `t1_proc_stat` and `t1_dev_display_users` moved here **verbatim** from
  `tests/run_regression.tcl`, with three changes:
  - `t1_dev_display_users {num state {me {}}}`: an optional root pid. Its ancestors and
    descendants are never counted. The default is `[pid]`, which is what T1 had.
  - **New rule, launchers that have already chosen.** `xvfb_arm.sh` re-execs a launcher it
    sends private under `xvfb-run`, with `XSCHEM_XVFB_ARM=1` and the private `DISPLAY` in
    its exec-time environment. So for a `run_suites.sh`/`full_audit.sh` with
    `XSCHEM_XVFB_ARM=1`, the launcher is counted exactly when that `DISPLAY` is `:N`. That
    covers a nested launcher that inherited an attached arm. A launcher that went private, or
    was told `none`, is not counted. Without this rule, a run_suites.sh that had stepped aside
    would still have counted as a holder for its whole run, because its exec-time state dir
    and number still name the dev display.
  - `AUDIT_DISPLAY=dev` now counts as "on the dev display", alongside empty, `auto` and `:N`.
    `private` and `none` already did not count.
  - A peer's state dir falls back to `XSCHEM_TEST_REAL_HOME` before `HOME`. That is
    `xvfb_arm.sh`'s own rule.
  - Also new: `t1_dev_display_who`, the shared "pid P (comm: reason), ..." phrase.
  - A script entry: `tclsh dev_display_users.tcl [--root <pid>] <num> <state dir>` prints the
    holders on one line, or nothing. It exits 0, or 2 on a usage error (measured: `x y` gives
    rc 2 and a usage line).
- **`tests/run_regression.tcl`**: the four procs are deleted, and a short pointer is left in
  their place. `source [file join headless dev_display_users.tcl]` sits beside
  `source banner_rule.tcl`. The IN-USE notice uses `t1_dev_display_who`, so its text is
  unchanged.
- **`tests/headless/xvfb_arm.sh`** (the choke point for `run_suites.sh`, `full_audit.sh`,
  `gated_xschem.sh` and every `xvfb_arm.sh --arm` standalone suite):
  - New `_xvfb_dev_state` holds the state-dir rule that `_xvfb_dev_display` already used, now
    in one place.
  - New `_xvfb_dev_display_held <dpy>` runs the helper with `--root $$` under
    `env -u DISPLAY`. If there are holders, it prints `display arm: the dev display :N is IN
    USE by pid P (comm: reason), ... -- using a private Xvfb instead (AUDIT_DISPLAY=dev
    attaches anyway)`. If it cannot ask (no `tclsh`, helper missing, helper rc != 0), it
    answers "held" and says so. That is the direction that disturbs nobody.
  - The `auto|""` arm became `auto|""|dev|private`:
    - `private` prints `display arm: AUDIT_DISPLAY=private -- not attaching to the dev display`
      and spawns;
    - `dev` attaches whenever the dev display is up (the old behaviour);
    - `auto` attaches only if nobody holds it.
  - `none` and any explicit display are untouched, so they still win and ask nobody. The
    header's INTERFACE block documents all of this.
- **Knob decision (mine, documented):** `AUDIT_DISPLAY` takes `T1_DISPLAY`'s vocabulary. I did
  not add a third variable. It is the launchers' existing knob, its old values keep their
  meaning, and `dev`/`private` were never valid display names. `owed.sh drain` always passes an
  explicit display (default `:0`), so it is unaffected. `gated_xschem.sh` and the `--arm`
  suites inherit the change through `xvfb_arm`.
- **Copy sites** (they copy `run_regression.tcl` into a fixture dir, and it now sources a file
  under `headless/`): `test_t1_display_arm.tcl` `mkdrv`, `test_home_isolation.tcl` `mkfdir`,
  and `test_regression_concurrency_1476.tcl` (the f4 and v5 fixture dirs) now copy the helper
  too.
- **CLAUDE.md**:
  - "The display arm: Xvfb by default" gets one bullet: the `AUDIT_DISPLAY=auto|dev|private`
    vocabulary, that explicit wins, the cannot-ask fallback, and rows TL1-TL9.
  - "The persistent dev display" gets one bullet: launchers step aside by the shared detector.
  - The issue-1488 sentence now reads "`AUDIT_DISPLAY=private` takes that arm with `:99` up",
    replacing "no knob goes private while `:99` is up", which this change made false.

## 2. Fence: `tests/headless/test_t1_display_arm.tcl` (already in `hcases`), 14 to 23 checks

The new rows run the **real** launchers against the suite's existing fixture dev display. The
launchers' `XSCHEM` is a stand-in that logs the `DISPLAY` it was handed. The environment is
`env -i`, `AUDIT_XVFB_BASE` is the fixture number + 20, and `AUDIT_WM=none`.

| row | asserts |
|---|---|
| TD5 (widened) | two new decoys: a run_suites.sh already private (`XSCHEM_XVFB_ARM=1 DISPLAY=:other`) and one with `AUDIT_DISPLAY=private`. T1 still attaches |
| TL4 | the same 10 decoys, at the same moment: run_suites.sh and gated_xschem.sh attach, with no notice |
| TL1 | idle: run_suites.sh, full_audit.sh and gated_xschem.sh each attach (stand-in sees `:N`) |
| TL2 | an xschem with `DISPLAY=:N`: each of the three goes private and names exactly that pid |
| TL3 | **parity**: an xschem and a peer T1 alive together. A T1 copy and run_suites.sh name the same pid set. A run_suites.sh holder alone is named by full_audit.sh |
| TL5 | a nested launcher with `XSCHEM_XVFB_ARM=1 DISPLAY=:N` **is** a holder (the new rule's positive half) |
| TL6 | `AUDIT_DISPLAY=dev` attaches despite a holder; `=:other` is used verbatim with no notice; `=private` goes private and says why |
| TL7 | a launcher run under an ancestor named xschem with `DISPLAY=:N` attaches |
| TL8 | exactly one file under `tests/` defines `t1_dev_display_users` (`dev_display_users.tcl`). The driver sources it, and `xvfb_arm.sh` names and runs it |
| TL9 | an `xvfb_arm.sh` copy with no helper beside it goes private and says it could not ask |

### Red first (copy, plant, run, restore with `cp`, `cmp` proved every restore)

- **HEAD's `xvfb_arm.sh` and `run_regression.tcl`** (`git show HEAD:…`), with the new helper
  present: `7 FAILED (16 passed)`. The red rows are TD5, TL2, TL3, TL5, TL6, TL8 and TL9.
  TL1, TL4 and TL7 stay green, because they are the negative halves: HEAD attaches always.
- S1, the XSCHEM_XVFB_ARM rule removed from the helper: TD5 and TL4 red (`2 FAILED`). The
  shared helper reddens both callers' rows.
- S2, the rule skips every armed launcher, with no DISPLAY test: TL5 red.
- S4, `AUDIT_DISPLAY=dev` treated as `auto`: TL6 red.
- S5, cannot-ask returns "not held" (attach): TL9 red.

## 3. Runs

- `test_t1_display_arm`, hand run (armed HOME, `XSCHEM_T1DA_BASE=270`): `ALL PASS (23 checks)`.
  Through `AUDIT_DISPLAY=none run_suites.sh --nogui`: `PASS … ALL PASS (23 checks)`.
- Neighbour suites: section 5.
- Live detector, read-only, against the real state dir:
  `tclsh tests/headless/dev_display_users.tcl 99 ~/.claude/xschem_dev_display` printed
  nothing, rc 0. By then no T1 was live on `:99` and no xschem had `DISPLAY=:99` (checked by
  `ps` and `/proc/<pid>/environ`); the xschem-private run had finished. So the
  "real holder named" case was not measured live. The fixture rows cover it.
- Leaks: my manual fixture `:291` was stopped with `devdisplay.sh stop`, and `/proc/232757`
  is gone. After the suite runs, only `:99` and other sessions' servers remain.

## 4. Not done / declared

- **`--root $$` is unfenced.** Every row passes without it, because the launcher is the
  helper's ancestor anyway. It only matters for a launcher's own non-ancestor children, which
  do not exist when `xvfb_arm` decides. I kept it for exact parity with T1's
  `[pid]`-rooted call.
- The detector still sees `gated_xschem.sh` and `--arm` suites only through their `xschem`
  child, as in stage B.
- A `run_suites.sh --nogui` still attaches (and counts as a holder) when `:99` is up and
  free. I left this unchanged: CLAUDE.md records that `--nogui` attaches `:99`, and changing
  what `--nogui` attaches is a separate decision.
- `test_devdisplay.sh` uses display numbers 89-96 by default and `test_home_isolation` uses
  150-169. I ran the former with `DEVDISPLAY_TEST_NUMS=276..279`. The latter has no override,
  so it used its own 150+ fixtures (never `:99`).
- Nothing for the user to rule on: this is harness-internal.

## 5. Neighbour suite results (counted arm, `AUDIT_DISPLAY=none run_suites.sh --nogui`)

| suite | result |
|---|---|
| test_t1_display_arm | ALL PASS (23) |
| test_regression_concurrency_1476 | ALL PASS (46) (copy sites carry the helper) |
| test_scratch_home_note | ALL PASS (22) (`summarize_all` lift unaffected) |
| test_registered_banner_1626 | ALL PASS (10) |
| test_suite_watchdog_1403 | ALL PASS (40) |
| test_audit_classifier | ALL PASS (75) |
| test_home_isolation_sh | ALL PASS (90) (xvfb_arm W-rows, `--arm` paths) |
| test_home_isolation | **1 FAILED (119 passed): G2 only** |
| test_devdisplay.sh (bash, `DEVDISPLAY_TEST_NUMS=276..279`) | ALL PASS (53) (D5 attach, D6 fallback, D7 explicit) |

**The G2 red is not stage E.** It is the same red B-verify recorded. Every UNARMED entry is
under the untracked `doc/claude/rl_telescopic_amp/` (another session's `run_measures.py`,
`dump.sh` and `run.sh`). The new `dev_display_users.tcl` starts no xschem and is not listed.
A clean gate clone will not have that directory.

Note: test_devdisplay.sh's own D6 fallback took `:200`, its default `AUDIT_XVFB_BASE`. That is
outside the crews' 260-299 range. It is the suite's design, and I did not change it.
