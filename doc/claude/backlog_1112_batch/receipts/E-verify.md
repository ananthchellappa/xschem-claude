# Stage E verify receipt: the launchers step aside

Verifier crew, 2026-11-12. Base `6ac33dd2b`, reviewing the implementer's uncommitted change
(`receipts/E-launchers.md`). Every command ran with `unset DISPLAY` or under `env -i`. I used
only my own fixture dev display, on `:265`, with its state dir in the session scratchpad and
stopped with `devdisplay.sh stop`. Besides that I used private Xvfbs from `:285`, the suite's
fixtures from `XSCHEM_T1DA_BASE=262`, and test_devdisplay's own fixtures at 276-279/290. I
never attached or probed `:99`, and I ran no T1.

## Verdict

Stage E delivers what it set out to do. I found **two demonstrated defects and one unfenced
rule**. All three are now fixed and fenced, red first, and the fixes are uncommitted.

## Defects found and fixed

**1. A hanging ask hung the launcher with no bound.** `_xvfb_dev_display_held` ran the helper
with no timeout. It runs before any suite's `SUITE_TIMEOUT`/`AUDIT_TIMEOUT` exists, and a
`/proc` read can block on a D-state process.
- Measured: with a `tclsh` that never returns first on PATH, `run_suites.sh` printed **no
  `display arm` line at all**. It was killed by my outer `timeout 60` (rc 124 at 60 s).
- Fix (`xvfb_arm.sh`, `_xvfb_dev_display_held`): the ask now runs under `timeout -k 2
  "$XVFB_ARM_ASK_TIMEOUT"` (default 20 s, documented in INTERFACE). rc 124 prints `asking who
  holds the dev display :N failed (rc=124: timed out after Ns)` and goes private. If there is
  no `timeout` binary, it falls back to the old unbounded call.
- New row **TL10**.

**2. Stepping aside could land on the user's screen.** With no `xvfb-run`, the spawn path
falls back to the **inherited `DISPLAY`**. HEAD attached the dev display in that case. Stage E
made two new ways to reach the fallback: `auto` with a holder, and `AUDIT_DISPLAY=private`.
- Measured: `display arm: xvfb-run NOT FOUND -> falling back to inherited
  DISPLAY=:USERSCREEN`, on both of those paths.
- Fix (`xvfb_arm`): a local `_xvfb_aside` is set when the dev display was up but not used, or
  when the arm was told `private`. With it set and no `xvfb-run`, the arm unsets `DISPLAY` and
  says so (`... the dev display is not ours to use -> DISPLAY unset; GUI legs will
  self-skip`).
- The old fallback is unchanged when no dev display is up. That case is pre-existing and out
  of scope.
- With the dev display idle and no `xvfb-run`, the launcher still attaches (measured).
- New row **TL11**.

**3. The `AUDIT_DISPLAY=dev` holder rule was asserted by no row.** The receipt names it as a
new rule, but its S4 sabotages the launcher's own `dev` handling, not the detector's.
- My sabotage V2 dropped `dev` from the detector's accept list (`[list {} auto dev ":$num"]`).
  The suite stayed **`ALL PASS (25 checks)`**.
- Fix: **TL5** gains a leg. A `run_suites.sh` holder with `AUDIT_DISPLAY=dev` must be named,
  and the asker must go private. The row is renamed
  `TL5-a-nested-launcher-on-an-attached-arm-or-one-told-dev-is-a-holder`.
- With V2 in place: `1 FAILED (24 passed)`, TL5 red (`named {}, arm {attached :262}`).

**Red first.** Each sabotage was planted by copy, then restored with `cp`, and `cmp` proved
every restore.
- The implementer's `xvfb_arm.sh` against the new rows: **`2 FAILED (23 passed)`**, with
  TL10 (`rc=124 after 120072ms`, no ask-failed line) and TL11 (`saw :263` on both legs).
- The first attempt, without `SUITE_TIMEOUT=500`, ended as a whole-suite `TIMEOUT`. That run
  was the hang itself. Its orphaned fixture Xvfb `:262` and a TD11 child were mine, and I
  killed them by pid. I removed `.scratch/_t1da_404063` and `_psvalid_413645`.
- With the fixes: **`ALL PASS (25 checks)`**, twice.

## Attacks that did not refute the change

Hand runs used the real `run_suites.sh` against fixture `:265` with a stand-in `XSCHEM`.
- **No regression for a solo user.** With `:265` idle, `auto` attaches. With no `xvfb-run`
  and the display idle, it also attaches.
- **A holder.** An xschem-comm holder with `DISPLAY=:265` sends the launcher private, and the
  notice names exactly that pid.
- **A launcher that went private does not hold the display.** The re-exec chain is
  `xvfb-run` (comm `xvfb-run`), then `--reap` (comm `bash`, but no launcher-named argument),
  then the re-exec'd `run_suites.sh` (`XSCHEM_XVFB_ARM=1 DISPLAY=:285`). None of these is
  counted. A second launcher started while A was private on `:285` **attached**.
- **Self, parent and nested launchers.** `$$` is the launcher's pid both when `xvfb_arm.sh`
  is sourced and in the `--arm` entry, and `$(...)`/`timeout` keep the helper a descendant of
  it. Nested launchers inherit `XSCHEM_XVFB_ARM=1` and never ask. TL7 discriminates the
  ancestor skip.
- **"About to attach but not exported yet" is not a false negative.** `/proc` environ is
  exec-time, and an in-process attach never re-execs, so a deciding launcher or an attached
  one is counted by the state-dir rule. A T1 that attached is counted the same way. A T1 that
  went private is excluded by its Xvfb tag.
- **T1 parity.** I diffed against `git show HEAD:tests/run_regression.tcl`. The four procs
  moved verbatim except for the three declared rule changes plus the `me` parameter. T1's
  verdict changes in exactly these cases, each of which removes a false holder or adds `dev`:
  1. A re-exec'd private launcher, or a nested launcher under a `none` parent: HEAD counted
     it, wrongly; now it is not counted.
  2. A holder whose state dir is found through `XSCHEM_TEST_REAL_HOME`.
  3. `AUDIT_DISPLAY=dev`.

  The notice text is unchanged (`t1_dev_display_who`). Receipt sabotage **S1 reproduced**:
  `2 FAILED` (TD5, TL4).
- **Copy sites.** Every suite that runs a driver copy also copies the helper:
  `test_t1_display_arm`, `test_home_isolation`, and `test_regression_concurrency_1476` (f4,
  v5). The other `run_regression.tcl` readers only scan its text.
- **CLAUDE.md.** Both new bullets are short and true. The issue-1488 sentence ("`AUDIT_DISPLAY=private`
  takes that arm with `:99` up") is now true, because `private` spawns. I updated the
  display-arm bullet for the two fixes (rows `TL1`–`TL11`). I also corrected the helper
  header's "Row TL7" to TL8, the row that actually asserts one implementation.

## Suites (counted arm, `AUDIT_DISPLAY=none run_suites.sh --nogui`)

| suite | result |
|---|---|
| test_t1_display_arm | ALL PASS (25), up from 23 |
| test_regression_concurrency_1476 | ALL PASS (46) |
| test_audit_classifier | ALL PASS (75) |
| test_home_isolation_sh | ALL PASS (90) |
| test_devdisplay.sh (`DEVDISPLAY_TEST_NUMS="276 277 278 279"`, `AUDIT_XVFB_BASE=290`) | ALL PASS (53) |
| test_home_isolation | 1 FAILED (119): G2 only |

The G2 red is the known one: all five UNARMED paths are under the untracked
`doc/claude/rl_telescopic_amp/`.

After the runs: no Xvfb of mine is left, `.scratch/` is empty, and there are no `untitled*`
files.

## Observations, not fixed

- **Launchers that start together all step aside.** When several start at the same moment,
  each sees the others mid-decision and every one goes private, though nobody is on the
  display (measured with 3 launchers). That errs safe, and T1 has the same race.
- **The notice names each such peer twice.** Its `$(...)` subshell has the same comm/cmdline
  as the launcher, so it is listed alongside it (4 pids for 2 peers). This is cosmetic, and
  fixing it would change the shared detector's output for T1 too.
- **`--root $$` stays unfenced.** It is equivalent to the default at decision time, and I
  agree with the receipt's declaration.
- **The two knobs treat an unrecognised value differently.** `AUDIT_DISPLAY` treats one as an
  explicit display name, where `T1_DISPLAY` treats one as `private`. This is pre-existing and
  is the documented "explicit wins".
- **TL8 does not pin the `timeout` call site.** Its call-site regexp matches the no-`timeout`
  fallback line, so a change to the line that actually runs would go unseen. TL10 covers that
  line's behaviour.

## Nothing for the user to rule on

This is harness-internal.
