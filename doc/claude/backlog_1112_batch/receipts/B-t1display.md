# Stage B receipt: a T1 gate never waits for the dev display

Crew: stage B task crew, 2026-11-12. Base `5f88a7c65` (HEAD at start). Uncommitted. Changed files:
`tests/run_regression.tcl`, `tests/headless/test_t1_display_arm.tcl` (new, registered in
`hcases`), and one bullet in `CLAUDE.md` (Tests > Concurrent T1 runs). Nothing else touched.

## 1. What changed (tests/run_regression.tcl)

- **New procs** (above `t1_private_xvfb`): `t1_proc_words`, `t1_proc_envget`, `t1_proc_stat`,
  `t1_dev_display_users {num state}`. The detector reads `/proc/<pid>/comm`, `cmdline` and the
  exec-time `environ`. It never pattern-matches command lines. A process counts as a user only if it is:
  - comm `xschem` with `DISPLAY=:N` (or `:N.s`) in its environment, or
  - a T1 (comm `tclsh*`, an argument whose `file tail` is `run_regression.tcl`), or a
    `run_suites.sh` / `full_audit.sh` (by comm, or as the script argument of `sh`/`bash`/`dash`),
    whose effective dev display is ours. That means its `XSCHEM_DEVDISPLAY_DIR`, or failing
    that `$HOME/.claude/xschem_dev_display` (devdisplay.sh's own default), normalizes to our
    state dir, and its `DEVDISPLAY_NUM` (default 99) equals our number. These do not count:
    a T1 with `T1_DISPLAY=private`; a run_suites/full_audit with an `AUDIT_DISPLAY` naming
    another display; and a T1 that owns a live Xvfb tagged `XSCHEM_TEST_T1_XVFB_TAG=t1.<its pid>.`
    (meaning it already went private).
  - The detector never counts itself, its ancestors or its descendants.
- **`T1_DISPLAY=auto|dev|private`**, default `auto`. Any other value is read as `private` and
  the run says so.
  - `auto`: if the dev display is alive and the detector finds users, T1 prints
    `display arm: the dev display :N is IN USE by pid P (comm: reason), ... -- using a private
    Xvfb instead (T1_DISPLAY=dev attaches anyway)` and takes `t1_private_xvfb`. The auto-start
    step is skipped in that case.
  - `dev`: the old behaviour.
  - `private`: prints `display arm: T1_DISPLAY=private -- not attaching to the dev display`.
    It never runs `status` or `start` on the dev display.
- **The display-arm selection block moved from just before the `dcases` loop to just before the
  `hcases` loop**, so its choice reaches the hcases children too. The new `dd_hcvars` (the
  private arm's `XSCHEM_DEVDISPLAY_DIR=<private state dir> DEVDISPLAY_NUM=<n>`, or nothing when
  attached or display-less) goes into the hcases arm's existing `env -u DISPLAY …` call, so
  routing is unchanged and X1/X2 of `test_home_isolation` still read it as safe. On a private
  gate the private Xvfb therefore lives through the hcases loop as well (it used to start after
  it); it is still killed right after the dcases loop.
- The selection still runs only when `dcases` is non-empty, so 1476's staged copies are unchanged.

## 2. Why the three rows skipped, and why the fix is in the driver, not the suites

`test_ev_precision_bound_1606` (D1-D4), `test_typeless_symbol_1603` (N2) and `test_ps_valid_1350`
(V26) are **hcases** suites. Each sends one display child through `devdisplay.sh exec` (the only
router they have, which keeps them in hcases). Each checks `devdisplay.sh status` first because
that is the precondition for `exec` working: status says no, so exec would fail. devdisplay.sh
reads `XSCHEM_DEVDISPLAY_DIR`/`DEVDISPLAY_NUM`, and T1 handed the hcases children only the
carried dev-display state dir. A private-display gate therefore made them skip. The suites were
already correct. They follow whatever state dir they are given, and TD11 measures that on all
three. So the fix is for T1 to give them the private arm's state dir, and none of the three
suites was edited.

## 3. Fences: tests/headless/test_t1_display_arm.tcl (hcases, 13 checks)

Rows TD1-TD10 drive copies of the real driver (lists and binary injected at `foreach tc $tcases`,
the same method as `test_home_isolation`'s section H). Each copy points at a **fixture** dev
display: a real `devdisplay.sh start` in a fixture HOME on a reserved number (from 240;
`XSCHEM_T1DA_BASE` overrides, and I ran with 286 to stay inside my 260-299 allowance). The
holders are copies of real binaries renamed to the comm the detector keys on (tclsh copied as
`xschem`/`Xvfb`, dash copied as `xschem`; this box's `sleep` is a uutils multicall binary and
cannot be renamed). Holders are siblings of the driver copy.

| row | asserts |
|---|---|
| TD0 | fixture dev display is up |
| TD1 | idle: auto attaches, no IN-USE notice, dcase sees `:N` |
| TD10a | attached: the hcases child gets nothing new, and its `devdisplay.sh status` is 0 |
| TD2 | `xschem` with `DISPLAY=:N` -> private, notice names the pid |
| TD10b | private: the hcases child gets the private state dir + number, and status is 0 there |
| TD3 | peer T1 on the same state dir/number -> private, named |
| TD4 | `run_suites.sh` (by comm) and `sh full_audit.sh` (by argument) -> private, named |
| TD5 | 8 decoys alive at once -> still attaches (xschem on another display; `sleep` on :N; peer T1 on another state dir; peer T1 with T1_DISPLAY=private; peer T1 owning a tagged Xvfb; run_suites with another AUDIT_DISPLAY; `sh -c '... # run_regression.tcl run_suites.sh'`) |
| TD6 | driver run under an ancestor named `xschem` with `DISPLAY=:N` -> attaches (not itself) |
| TD7 | `T1_DISPLAY=dev` with an xschem holder -> attaches |
| TD8 | `T1_DISPLAY=private`, nobody there -> private, says why, hcases handed it |
| TD9 | `T1_DISPLAY=Dve` -> private, says so |
| TD11 | population (registered hcases whose `puts "skip: …"` cites `devdisplay.sh status`, derived; currently 3) run with only `XSCHEM_DEVDISPLAY_DIR`/`DEVDISPLAY_NUM` naming a live display, each child in a HOME of its own: none skips and all print `OVERALL: ok`. Control: the smallest member with a missing state dir skips |

The suite takes about 55 s, most of it TD11 (test_ps_valid_1350 alone is about 35 s). It ends
with `OVERALL: ok (N checks)` and has no lowercase `skip:` line except when Xvfb or fixture
numbers are missing.

### Red first and sabotages (copy, plant, run, restore with `cp`, `cmp` proved each restore)

- **HEAD's driver** (`git show HEAD:tests/run_regression.tcl`): `6 FAILED (7 passed)`. TD2, TD10b,
  TD3, TD4, TD8 and TD9 were red. TD1, TD10a, TD5, TD6, TD7 and TD11 were green; those are the
  negative halves.
- S1 no ancestor exclusion -> TD6 red.
- S2 no `T1_DISPLAY=private` peer exclusion -> TD5 red.
- S3 no tagged-Xvfb exclusion -> TD5 red.
- S4 no state-dir comparison -> TD5 red.
- S5 hcases hand-off removed (`{*}$dd_hcvars`) -> TD10b and TD8 red.
- S6 substring match instead of `file tail` for the shell-script argument -> TD4 and TD5 red.
- S7 no AUDIT_DISPLAY exclusion -> TD5 red.
- S8 DISPLAY comparison removed (any xschem counts) -> 7 red (TD1, TD10a, TD2-TD6). Every
  sibling run went private because of other sessions' headless xschems.
- S9 (suite side) `test_ev_precision_bound_1606`'s gate pinned to a missing state dir -> TD11
  red, naming `still-skipped={{D1 D2 D3 D4}}`.

## 4. Live-system measurements

- The detector on the real machine, run three times:
  - It saw the driver's own gc26 T1 (pid 2828742) when asked about **its** missing-dir state dir.
    It did not see that T1 for the real state dir, because the trick moves it off.
  - It saw another session's `~/gcp0` T1 (pid 2925786, launched with `HOME=/home/analog`, no
    override) as a user of the real dev display.
  - While that run was in its dcases phase, it also saw its xschem child (`DISPLAY=:99`).
  - After that run ended it returned empty. A 3-day-old `sleep infinity` with `DISPLAY=:99`
    (pid 3298771, parent `/init`) and the dev display's own openbox are correctly not counted.
- **End-to-end T1, case "in use"** (free: `~/gcp0`'s T1 was live on :99). Clone `~/gcB`, pid
  3098571. Output: `display arm: the dev display :99 is IN USE by pid 2925786 (tclsh: a T1 run on
  the dev display's state dir) -- using a private Xvfb instead …`, then `PRIVATE Xvfb :100`.
  - Trailer: `cases=198 blocks=197 counted_failures=27 skips=10 elapsed=1377s`.
  - **skips=10, against 13** in the driver's private-trick gate at gc26
    (`results.2828742.log`, 197/196/0/13). The difference is exactly the three
    `skip: V26`, `skip: N2` and `skip: D1 D2 D3 D4` lines (diff of the two verdicts' `^skip:`
    lines). Everything else is identical.
  - **The 27 counted failures are the clone's path, not this change.** `~/gcB` has an upper-case
    letter. Every red is an ASE path-advisory row (`RD8 … Upper case, spaces or symbols in the
    path: OP annotation takes the slower route`, and the OP-dump consequences of that in
    `test_ase_rundir_1704` ×2 arms, `test_ase_saved_results_1705` ×2, `test_ase_optexport`,
    `test_ase_variant_1470`, `test_ase_optier_0963` Z6), plus `test_wave_subwindows` SWA14 on
    the display arm (that one was mine; see below). The verdict is kept at
    /tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/results.3098571.log.
  - I deleted the clone and re-gated in an all-lowercase clone (`~/gcq7`; `~/gcb` already
    existed and belongs to someone else, so I left it alone). The same ASE rows are green there.
    **Lesson for the driver: a gate clone path must be lower case as well as short.**
- **End-to-end T1, final gates, clone `~/gcq7`** (all-lowercase path, commit `7d0b80497` plus
  this change; the clone was deleted afterwards). Two runs, launched about 30 s apart:
  - **idle** (detector empty at launch): pid 3369541, `display arm: attached to the dev display
    (state dir /home/analog/.claude/xschem_dev_display)`. Trailer
    `cases=198 blocks=197 counted_failures=0 skips=10 elapsed=1356s`, `wc -l` 595.
  - **in use**: pid 3395840, launched while 3369541 was live on :99, with a dummy holder (a tclsh
    copy named `xschem`, `DISPLAY=:99`, which never connects to the display). Output:
    `display arm: the dev display :99 is IN USE by pid 3369541 (tclsh: a T1 run on the dev
    display's state dir), pid 3395835 (xschem: an xschem with DISPLAY=:99) -- using a private
    Xvfb instead …`, then `PRIVATE Xvfb :100`. Trailer
    `cases=198 blocks=197 counted_failures=0 skips=10 elapsed=1342s`, `wc -l` 595.
  - **The two runs' `^skip:` lines are byte-identical.** So a private gate now skips exactly what
    a :99 gate skips. In the private run, `test_ps_valid_1350` (29 checks),
    `test_typeless_symbol_1603` (10) and `test_ev_precision_bound_1606` (73) ran their display
    rows. The old private-trick gate counts 28 / 9 / 68 for the same suites and skips=13.
  - `test_t1_display_arm`: `ALL PASS (13 checks)` in both. Every nonzero `Total num fail:` count
    is 0. The `another regression run is live` NOTE appeared only in the second run, as it should.
  - Verdicts saved: /tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/results.3369541.log
    and …/results.3395840.log.
- **An idle gate taken before the final fix was red, and the cause is worth knowing.** Pid 3221072
  in `~/gcq7`, attached to :99, came back `counted_failures=2`: `test_wave_subwindows` display arm,
  row **SWA14** (`{0 1 0 0 1}` against `{1 1 1 0 1}`). The `~/gcB` run had the same red. The row
  passes standalone. Reduced T1s (`T1_DISPLAY=private`, dcases = test_wave_subwindows only)
  isolated it:
  - hcases = test_t1_display_arm: red;
  - hcases = {}: green (544);
  - hcases = each of the three gated suites alone: green.
  
  The cause was TD11's children sharing the run's throwaway HOME while their display children ran
  on the WM-less fixture display. Giving each TD11 child its own HOME made the reduced T1 green,
  and the final full gates above are green. I did not isolate which file in HOME carries the
  effect. This is one observation each way, and it suggests a latent hazard: **cases in one T1
  share one throwaway HOME, so a case can change a later case's result through it.**
- The first version of the suite leaked two fixture Xvfbs (`:286`, `:287`) when a Tcl error ended
  it (an uncaught error exits 0 from `--nogui`). I killed both, after confirming by HOME that they
  were mine. The rows now run inside one catch: an error becomes a counted `FAIL: TD-ABORTED …`
  line and cleanup still runs. I proved this with a planted error: `1 FAILED (3 passed)`, with no
  Xvfb and no reservation file left behind.
- `run_suites.sh --nogui test_t1_display_arm` (armed): `PASS … ALL PASS (13 checks)`.

## 5. Not done / declared

- **Old-tree T1s can be miscounted in one direction.** A peer T1 from a tree without this change,
  launched with the real state dir, counts as a user for its whole run, including its hcases phase
  before it maps anything. A new-tree peer counts too until it has chosen. Two T1s starting in the
  same second can therefore both go private. All of these err to the side that disturbs nobody.
- `run_suites.sh`/`full_audit.sh` are counted even with `--nogui`, because CLAUDE.md records that
  `run_suites.sh --nogui` attaches :99. `gated_xschem.sh` and bare `devdisplay.sh exec` callers
  are seen only through their `xschem` child.
- `T1_DISPLAY=dev` falls back to private exactly as before if the dev display cannot be had
  (D8's fallback order). It forces "do not step aside", not "fail without :99".
- `run_suites.sh` itself was not changed. The three rows still skip under `run_suites.sh --nogui`
  when :99 is down; the stage was about T1's arm.
- DECISIONS D3's `XSCHEM_DEVDISPLAY_DIR=<missing dir>` trick still works and is now unnecessary:
  `T1_DISPLAY=private` is the first-class spelling. Updating D3 is the driver's call.
- No user ruling is needed. This is harness-internal.
