# Stage B verify receipt: T1 never waits for the dev display

Verifier crew, 2026-11-12. I reviewed the implementer's uncommitted change: `tests/run_regression.tcl`,
`CLAUDE.md`, and the new `tests/headless/test_t1_display_arm.tcl`. I ran no T1. Every display I
used was my own Xvfb `:275`, killed by pid afterwards, plus the suite's fixture displays
(`XSCHEM_T1DA_BASE=280`). I never touched `:99`. Every command ran with `unset DISPLAY`.

## Verdict

Stage B is delivered, with **one demonstrated defect, now fixed**. The fix is uncommitted.

## The defect I found and fixed (red first)

When the run takes no display arm at all, the hcases children were handed the dev display.

The trigger is `T1_DISPLAY=private`, or `auto` stepping aside for a holder, followed by a private
Xvfb that will not start. The arm then says `NONE`, `dd_env` is empty, and so is `dd_hcvars`. The
hcases children therefore inherit the carried state dir, which names the dev display. Their
`devdisplay.sh status` answers 0, and D1-D4, N2 and V26 would `devdisplay.sh exec` onto the very
display the run had refused or stepped aside from.

- **New row `TD12`** in `test_t1_display_arm.tcl`. It drives both ways in, with a stand-in `Xvfb`
  (`exit 1`) first on PATH.
  - **Red** on the implementer's driver: `1 FAILED (13 passed)`. Both drives showed the hcases
    stand-in at the fixture dev display's state dir with `DDSTATUS 0`.
- **The fix**, in `tests/run_regression.tcl` at `set dd_hcvars`. If there are dcases, no private
  `dd_env`, and the arm neither attached nor started the dev display, hcases get
  `XSCHEM_DEVDISPLAY_DIR=<cwd>/results/.no-display-arm`.
  - Only devdisplay.sh's `start` ever creates a state dir, so this path stays missing and the
    rows skip, as they did before stage B.
  - The fix does nothing on an attached gate or a private gate whose Xvfb came up. Those take
    exactly the implementer's path, which is why I did not run a full T1 for it.
  - **Green** after the fix: `ALL PASS (14 checks)`. Removing the fix is the red above.

## Attacks that did not refute the change

**Sabotages.** For each one I copied the file, planted the change, ran the suite, restored the file
with `cp` and confirmed the restore with `cmp`.
- A. The xschem holder is matched by a pattern over its command line instead of `environ`
  `DISPLAY`. Result: `3 FAILED` (TD2, TD10b, TD12).
- B. `run_suites.sh` is dropped from the comm list, so `auto` attaches despite a run_suites holder.
  Result: `1 FAILED` (TD4).
- The implementer's S1-S9 cover the other exclusions. The hcases hand-off has only one exec site:
  `xtcmd` is not hcases and never routes through devdisplay.

**Detector probes.** I lifted the four procs into a plain `tclsh` and pointed them at a fixture
state dir on `:290`.
- A **zombie** `xschem` with `DISPLAY=:290` is not counted, because a zombie's `environ` is empty.
- A `run_suites.sh --nogui` on **another state dir** is not counted.
- A run_suites with `AUDIT_DISPLAY=none` is not counted.
- A run_suites `--nogui` on the same state dir **is** counted. The implementer declared this.
- A dead pid is absent from `/proc`, so it is never counted.

**The implementer's saved verdicts** (`results.3369541.log` attached, `results.3395840.log` private,
both in the session scratchpad) read `198/197/0/10` each. Their `^skip:` lines are byte-identical,
so claim (2) holds.

**Leaks** after every run: no Xvfb other than `:99`, no reaper, no `/tmp/xschem-t1da-fixture.*`, no
`.scratch/_t1da_*`, no `untitled*`. The suite prints `OVERALL: ok (N checks)` on a pass.

**The user's screen.** Nothing in the change can reach `$DISPLAY`:
- the hcases exec is `env -u DISPLAY`;
- holders and drivers run under `env -i`;
- TD11 runs under `env -u DISPLAY`;
- display children are routed by `devdisplay.sh exec` to the fixture or private display.

**CLAUDE.md bullet:** short, and true, including after the TD12 fix.

## Suites run (all through run_suites.sh, counted arm, `AUDIT_DISPLAY=:275`)

| suite | result |
|---|---|
| test_t1_display_arm | 13 baseline, then 14 after the fix |
| test_regression_concurrency_1476 | 46 |
| test_scratch_home_note | 22 |
| test_suite_watchdog_1403 | 40 |
| test_results_freshness | 21 |
| test_registered_banner_1626 | 10 |
| test_op_annot | 486 |
| test_home_isolation | **1 FAILED (119)**: G2 |

The G2 red is **not stage B**. Its UNARMED scripts are all under the untracked
`doc/claude/rl_telescopic_amp/` (another session's files: `run_measures.py`, `dump.sh`, `run.sh`).
A clean gate clone will not have them, but the main tree's next hand-run will be red until that
directory is armed, allowlisted or committed elsewhere.

## Observations, not fixed

- **The descendant exclusion in `t1_dev_display_users` is unexercised.** Detection runs once,
  before the hcases loop, when T1 has no live children, and no row fences it. It is harmless.
- **A T1 is recognised by any argument whose tail is `run_regression.tcl`, not only its script
  argument.** So `tclsh foo.tcl tests/run_regression.tcl` counts as a T1. This errs toward going
  private.
- **The suite's driver copies start private Xvfbs from `:100`** (t1_private_xvfb's fixed base),
  outside the crews' 260-299 range. They are lock-safe against a concurrent real T1, but a crew
  running this suite does use `:100+`.
- **Process point for the driver: the implementer ran three full T1s.** One of them, pid 3369541,
  was attached to `:99`. CREW_BRIEF constraint 2 forbids both. The runs were in throwaway clones
  and produced the evidence above.

## Nothing for the user to rule on

This is harness-internal. Updating DECISIONS D3's missing-dir trick, now superseded by
`T1_DISPLAY=private`, is the driver's call.
