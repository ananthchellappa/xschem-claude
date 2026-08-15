# WSLg display-health probe — `tests/headless/wslg_health.sh`

Status: SHIPPED v2.1 (2026-08-11), **standalone only — not yet wired into the
harness** (see "What remains", below).
v1 was the five checks. **v2 is v1 plus obedience: the probe answers the
GUI-test control panel's Pause and Stop before it maps anything** — v1 did not,
and that is why v1 was stopped mid-verification (see "The button", below).
**v2.1 is the review round on that obedience**: v2 consulted the panel *once,
before a loop that maps up to three windows*, so a button pressed at window 1
was answered with two more windows and a health verdict (rulings 10–12).
Files: `tests/headless/wslg_health.sh`, self-test
`tests/headless/test_wslg_health.sh` (152 checks with a display, 135 without;
band `DH01`–`DH67`, measured free by grepping `tests/headless/*.tcl` and `*.sh`
— `HW` and `WH` are both taken, `DH` was not).
Issue: `doc/claude/issues/0310-a-revived-wslg-display-is-a-640x480-stub-that-parks-windows-offscreen.md`.
Related: `doc/claude/specs/gui_test_gate.md` (the panel this display kills — and
the button this probe now answers).

## The question it answers

**Is this X display healthy enough for GUI test results to mean anything?**

Not "is the server up". After a WSLg Xwayland abort the display can come back as
a **640x480 stub** whose window manager parks every new top-level at absolute
**-32768**. It answers `xdpyinfo`. Clients connect. `wish` starts and maps
windows. Every liveness check in this harness reads green — and GUI suites then
run blind, producing numbers that look completely ordinary. That already cost
Batch F a whole item: an entire `full_audit` ran to completion against a stub and
its diff was meaningless.

**Liveness is not visibility.** That distinction is the whole point of the
script, and it is why check 5 exists.

## The five checks

| # | check | how | verdict? |
|---|-------|-----|----------|
| 1 | the server answers at all | `xdpyinfo`, under a timeout | yes — but nowhere near sufficient |
| 2 | root geometry is not a stub | `xwininfo -root`, against a **floor** | yes |
| 3 | nothing parked at the sentinel | `xwininfo -root -tree`, **two samples**, matched on magnitude | yes |
| 4 | server uptime | `stat /tmp/.X11-unix/X<n>` (recreated on every respawn) | **no — information** |
| 5 | **functional placement probe** | map a real Tk window, compare where it landed against where it asked to go | yes, and it is the decisive one |
| + | `Fatal server error` count in `/mnt/wslg/stderr.log` | `grep -c` | **no — information** |

Measured on the healthy server (2026-08-11): root `5120x1440`, zero `-327xx`
coordinates, probe `want +200+200 got +206+227 screen 5120x1440`.
Measured on the stub (2026-08-10, issue 0310): root `640x480`, tree lines at
`+-32768+-32768`, probe `+-32730+-32709` with `screen 640x480`.

## The button (v2) — check 5 paints on the user's screen, so it obeys Pause

Check 5 maps a **real top-level on the user's desktop**. The one invariant the
whole GUI-test gate exists to protect is that *anything which paints on that
screen answers that button*. v1 of this script did not consult the panel at all
— the brief that produced it said explicitly that it should not depend on the
gate — and under the sabotage harness that meant dozens of little probe windows
flashing past. The user pressed **Pause**, and nothing stopped. That design
fault was retracted and this section is the replacement.

Before it maps anything, the probe **reads** `$GUI_GATE_DIR/control` (default
`~/.claude/gui_test_gate/control`):

| control | what the probe does |
|---------|---------------------|
| `STOP` | maps nothing, prints `VERDICT: STOPPED`, exits **4** |
| `PAUSE` | holds, polling, up to a **bounded overall wait** (`WSLG_HEALTH_GATE_WAIT`, default 300 s); if still paused at the bound it maps nothing, prints `VERDICT: DEFERRED`, exits **5**. A Resume during the hold lets it run |
| `RUN`, missing file, unreadable, anything else | proceeds. **Fails open**, exactly like the rest of the gate |

It is consulted once before any X call at all (so a `STOP` costs nothing and
never touches the display), and then **again before EVERY probe attempt** — the
probe is best-of-3, so the statement that maps a window runs up to three times.
Those later consults are the load-bearing ones: without them, a Pause pressed
while `xdpyinfo` and the two `xwininfo` calls are running, or pressed the moment
the first probe window appears, is followed by a window on the screen of a user
who just asked for no windows. All consults share one deadline, so consulting
repeatedly cannot multiply the bound. Evidence: DH59/DH60 (the shim presses the
button from inside the `xwininfo -root -tree` call, i.e. after the first
consult) and DH62/DH63 (the shim presses it from inside `wish`, i.e. between two
probe attempts), versus DH61/DH64 (nobody presses anything: the probe maps as
usual, and takes all three attempts when the placement keeps failing).

## Rulings (decided by the crew; no human was available to ask)

1. **The geometry check is a FLOOR (1024x768), not an equality test against
   640x480.** The stub size is not a magic constant, and this machine's real root
   legitimately alternates between 5120x1440 and 2560x1440 as monitors come and
   go. A resize is not a fault. Evidence: both real sizes are pinned green in
   DH03/DH04 and 640x480 red in DH02.
2. **The placement check is a TOLERANCE (64 px), not an equality test.** The
   measured healthy result is `want +200+200 -> got +206+227`: a window-manager
   decoration offset of (6, 27) is CORRECT and must never be flagged. The stub
   misses by ~32900 px, which no tolerance worth the name could swallow.
   Evidence: DH12 (green at 6,27) and DH11 (red at -32730,-32709).
3. **Uptime and the Fatal-server-error count are INFORMATION, never a gate.** A
   server that restarted seconds ago is not broken — it just explains vanished
   windows, dead panels and any suite that ran across it. A rising fatal count
   predicts more panel deaths without making the results in hand wrong. So they
   print as `[info]` and cannot change the verdict (DH24).
4. **A fourth exit code, UNKNOWN (3), was added** beyond the healthy / stub /
   no-display three. When a required tool is missing, or a check cannot be read,
   the honest answer is neither "healthy" (a silent downgrade is precisely what
   this script exists to prevent) nor "stub" (calling a toolless box broken is a
   lie). `wh_decide` therefore returns 3 when nothing is faulty but something is
   unjudgeable — notably when the decisive probe did not run (DH16, DH19e).
5. **"Absent" and "wedged" are told apart by the SOCKET, not by the timeout.**
   Against a display with no listener at all, Xlib falls back to TCP and retries
   SYNs for minutes (269 s measured while building the gate's v6 revive), so
   `timeout xdpyinfo :77` expires exactly like a hung server would. Reporting an
   unused display number as a fault would be the worst false alarm this script
   could raise. So: local socket missing → **NODISPLAY (2)**; socket present and
   the server does not answer within the timeout → **UNHEALTHY (1), "wedged"**;
   no local socket to inspect (a remote display) and a timeout → **UNKNOWN (3)**,
   because from there the two are genuinely indistinguishable. Evidence:
   DH32 / DH33.
6. **v2: "not measured" gets codes of its own — STOPPED (4) and DEFERRED (5) —
   and is never folded into UNHEALTHY (1).** "I did not look" is not "the display
   is broken", and a caller that could not tell those apart from healthy would be
   back to guessing, which is the entire disease. A preflight that reads
   `DEFERRED` should say so and carry on (or ask the user to press Resume); one
   that read it as `UNHEALTHY` would abort the audit and blame the desktop.
   Evidence: DH50, DH51, DH57 (all four codes observed distinct in one run).
7. **v2: the gate is obeyed by READING ONE FILE, never by sourcing
   `gui_gate.sh`.** This probe is meant to become a preflight *inside*
   `gate_start`; sourcing the gate from something the gate calls is a circular
   dependency waiting to bite, and it would drag `_gate_*` state, traps and a
   `wish` dependency into a script whose whole value is being dependency-free. A
   plain read of one small word is the whole mechanism. It is also **read-only**:
   the control dir belongs to the user and the panel, and the probe writes
   nothing there ever (DH58 pins names, sizes and mtimes unchanged).
8. **v2: `GUI_GATE=0` does NOT exempt the probe from Pause/Stop.** That variable
   means "do not stop to ask permission" — it is about the *asking*. `PAUSE` and
   `STOP` are not questions; they are a standing order from a user who is at the
   keyboard and has already pressed a button. Honouring the gate only when the
   gate is enabled would hand every future agent a one-word way to flash windows
   at a user who has asked for none. Evidence: DH56.
9. **v2: the PAUSE hold is BOUNDED, and the bound reports DEFERRED rather than
   proceeding.** A Pause pressed and then forgotten must not hang a suite for the
   rest of the day; equally, timing out must not be a licence to map the window
   after all, or the bound would just be a slow way of ignoring the button.
   Evidence: DH51 (bounded, exit 5, `wish` never called) and sabotage 8 (bound
   removed → the run hangs into the harness's own 60 s limit).
10. **v2.1: the consult belongs INSIDE the retry loop, not before it.** The probe
    is best-of-3 (ruling: a WM hiccup must not be reported as a stub), so "before
    it maps anything" has to mean *before each of the three*, not before the
    first. Measured on the delivered v2: with the button pressed the instant
    probe window 1 appeared, the probe mapped **two more windows** and then
    reported a health verdict (exit 1) instead of STOPPED/DEFERRED — and it did
    so hardest on the very display the script exists to detect, because a stub
    misplaces *every* attempt and therefore always takes all three. One consult
    per window, sharing one deadline. Evidence: DH62/DH63 (exactly one `wish`
    call, exit 4/5) against DH64 (nobody pressing → all three attempts taken).
11. **v2.1: "there is no server there" is decided BEFORE the panel is consulted.**
    A hold is a promise about the user's *screen*; a display number with nothing
    behind it has no screen, nothing to map and nothing to see, so holding for it
    is an invented hold. Measured on the delivered v2, whose consult came first:
    `wslg_health.sh :9` on an unused display sat on a forgotten PAUSE for the
    full bound and then reported DEFERRED — and, inside the self-test, dragged
    two checks about sockets and log files red whenever the panel was paused. The
    `$DISPLAY`-unset and no-socket NODISPLAY exits therefore both precede the
    first consult; every consult that can still be reached is one where a window
    really would follow. Evidence: DH67.
12. **v2.1: a malformed tunable is never reported as a broken display.**
    `WSLG_HEALTH_GATE_WAIT=2.5` used to abort bash in `$(( ))` *while holding*:
    no VERDICT line at all and exit 1, which every caller reads as "stub display,
    GUI results are meaningless" — a hold reported as a broken display, the exact
    confusion codes 4 and 5 exist to prevent (and an easy typo, since the poll
    interval beside it documents fractions). A fractional bound is truncated, a
    nonsensical one falls back to the 300 s default, and either way the
    substitution is announced on stderr rather than silently obeyed. Evidence:
    DH65 (2.5 → DEFERRED, exit 5) and DH66 (`soon` → still holding at 5 s, with
    the warning printed).

## Exit codes

| code | meaning |
|------|---------|
| 0 | HEALTHY — the display is real and places windows where it is asked to |
| 1 | UNHEALTHY — stub display / windows parked off-screen / a wedged server. Results taken here measure a different machine; re-run after `wsl --shutdown` |
| 2 | NODISPLAY — `$DISPLAY` unset, or no X server there. **The legitimate headless case, not a fault** |
| 3 | UNKNOWN — could not judge (tool missing, unreadable check, probe did not run) |
| 4 | STOPPED — the control panel is set to STOP. **Nothing mapped, NOT measured** |
| 5 | DEFERRED — the panel is PAUSED and stayed paused past the bound. **Nothing mapped, NOT measured** |
| 64 | usage error (EX_USAGE). Deliberately **not** 2: a caller that read a typo as "this box is headless, carry on" would get exactly the silent wrong all-clear this script exists to kill (DH35) |

Output is a **one-line verdict** with the details underneath; `-q` prints the
verdict alone. `$DISPLAY` is honoured and an explicit display argument overrides
it.

## Contract

* **Every X call is under a `timeout`.** A wedged server makes clients block
  forever — which is one of the conditions being detected — and a probe that
  hangs on a hung display is useless.
* **It answers Pause and Stop before it maps anything** (see "The button").
* It **starts nothing, kills nothing**, and is safe to run while suites are in
  flight. It never *writes* into `~/.claude/gui_test_gate/` (asserted: DH34,
  DH58) and never sources the gate.
* Dependencies are only what this harness already uses: `xdpyinfo`, `xwininfo`,
  `wish`, `stat`, coreutils.
* Its output never contains `RESULT: SKIP`, `skipped: no X` or
  `SKIP: no X connection` — `full_audit.sh:128` scores a whole FILE on those
  substrings and would silently discard every check that ran in it (DH31, and
  DH57 for the two new hold verdicts).

## How it is proved without a stub

Xwayland cannot be crashed to order, and a test may not try: killing the
compositor takes down the user's desktop and every X client, which is the exact
failure the harness exists to prevent. So the **judgement is factored away from
the measuring**: `wh_check_geometry`, `wh_check_sentinel`, `wh_check_placement`
and `wh_decide` are pure functions over values, and the main entry point is
guarded by `[ "${BASH_SOURCE[0]}" = "$0" ]` so that **sourcing the script defines
the judgement and runs nothing**. `test_wslg_health.sh` sources it and drives the
decision with the values **recorded from the real 2026-08-10 failure**, never
invented ones. A second arm runs the whole script end to end under a PATH shim of
fake `xdpyinfo`/`xwininfo`/`wish` emitting those same recorded values, which is
what ties the numbers the script *reports* to what X actually *said*.

That guard is load-bearing in a way that is easy to get wrong: an unguarded
script ends `wh_main "$@"; exit $?`, and a sourced `exit` kills the CALLER — the
first version of DH01 was destroyed by its own sabotage, printing no banner and
exiting 0. The check now sources inside a command substitution (a subshell) and
asserts the source produced **no output**, which the probe's verdict line would
violate.

**ONE WINDOW, NOT A DOZEN (v2), AND IT IS COUNTED (v2.1).** The same PATH shim
is what keeps the test off the user's screen: the fake `wish` maps nothing, so
the DECISION, E2E and GATE arms cost zero windows however many times they run.
Only the LIVE arm maps anything, and it is derived from a **single** probe run
(v1 started four, each retrying up to three times). The shim's `wish` also
**counts its calls**, which is what makes "it obeyed the button" evidence rather
than a verdict word: a probe that obeys Pause calls `wish` exactly **zero**
times.

v2 claimed one window per run and shipped **three**: the live arm's, plus a bare
`"$PROBE"` in DH31 and a `HOME="$fakehome" "$PROBE"` in DH34. The last was the
worst — with `$HOME` redirected the probe resolved its control file to a gate dir
that did not exist, failed open, and mapped a window on the user's display
whatever the real panel said: one **ungated** window per run of the file whose
whole subject is that windows are gated. Both now run behind `$NOWIN`, a shim
that fakes **only** `wish` (so `xdpyinfo`/`xwininfo` still answer from the real
display) and maps nothing.

**How the count is verified, rather than asserted:** put a `wish` LOGGER at the
*back* of `$PATH` — the test prepends its own shim dirs, so a launch that reaches
the logger is one no shim intercepted, i.e. a real window. Measured that way:
**1 real launch per live run** (2 when the WM hiccups and the probe retries;
before v2.1, 3 plus their retries). A run with a standing `PAUSE` maps **0**.

### Sabotage table (each restored from a byte-exact backup, re-run green)

Run with `DISPLAY` unset, so the sabotage round itself maps no windows at all
(115 of the 130 checks are display-independent).

| # | sabotage | checks that went red |
|---|----------|----------------------|
| 1 | floor raised to 8192x4096 (a healthy display must read STUB) | **22**: DH03, DH04, DH05, DH18 x3, DH19e, DH19f, DH41 x3, DH25, DH42, DH44, DH45, DH52, DH53, DH54, DH54b, DH55, DH57, DH61 |
| 2 | the sentinel match neutered (`if (0)` in `wh_sentinel_ids`) | **11**: DH08 x2, DH10d, DH10f, DH17, DH19c, DH40 x2, DH42 x2, DH44 |
| 3 | the placement comparison neutered (`if false`) | **5**: DH11, DH15, DH17, DH19a, DH40 |
| 4 | the `timeout` dropped from the `xdpyinfo` call | **3**: DH33 x3 — the run hit the test's own 25 s outer limit (rc 124) instead of the 2 s inner one |
| 5 | **the probe ignores PAUSE** | **9**: DH51 x4 (incl. "wish was never called"), DH52, DH57, DH59 x3 |
| 6 | **the second consult removed** (panel read only at startup) | **5**: DH59 x3, DH60 x2 — DH50/DH51 stay green, which is the point |
| 7 | **STOP not obeyed** (`wh_gate_state` maps STOP to RUN) | **8**: DH50 x3, DH56 x2, DH57, DH60 x2 |
| 8 | **the PAUSE bound removed** (deadline `now + 100000`) | **6**: DH51 x4 and DH59 x2 — the held run hung into the harness's own 60 s limit and came back rc 124 instead of 5. (DH51's "nothing was mapped" stayed *green*: the probe was killed before it could reach `wish`, which is exactly why the bound is a separate ruling from the obedience.) |

Three v1 rounds, **re-run against the v2 file rather than taken on trust**:

| # | sabotage | checks that went red |
|---|----------|----------------------|
| 9 | the entry-point guard removed | **2**: DH01 x2, and the run stops there (`checks=2`) — the guard check doing its job |
| 10 | the usage error made to `return 2` | **1**: DH35 |
| 11 | the socket discriminator removed | **1**: DH32 |

**v2.1 rounds** (the review's confirmed findings, each broken and restored from a
byte-exact backup; rounds 12–17 ran with `DISPLAY` unset and mapped nothing,
18–19 are live and mapped one window each):

| # | sabotage | checks that went red |
|---|----------|----------------------|
| 12 | **the consult moved back OUTSIDE the retry loop** (v2's arrangement) | **5**: DH62 x3, DH63 x2 — *3* `wish` calls and exit 1 instead of 1 call and exit 4/5. DH50/DH51/DH59/DH60 all stayed **green**, which is why DH62/DH63 had to exist |
| 13 | the `WSLG_HEALTH_GATE_WAIT` validation removed | **5**: DH65 x3 (bash arithmetic syntax error, no VERDICT, exit 1), DH66 x2 |
| 14 | the no-socket NODISPLAY exit moved back BEHIND the consult | **3**: DH67 x3 — a display with no server held the full 30 s bound and reported DEFERRED |
| 15 | `wh_gate_state` writes a file into the gate dir it read | **2**: DH58, DH34b (the user's real gate dir was never in reach: the sabotage was scoped to `/tmp/*`, verified afterwards) |
| 16 | `wh_gate_state` creates the gate dir it did not find | **1**: DH34 |
| 17 | the gate dir stops following `$HOME` | **2**: DH34c x2 |
| 18 | **the panel shields removed** from the four non-panel invocations, run under a standing PAUSE | **3**: DH28, DH43 x2 — the exact fail set the reviewer measured. DH26/DH31 stayed green *because* of ruling 11 (their `:9`/`:77` runs now exit NODISPLAY before any consult) |
| 19 | **`PROBE_TCL` echoes the REQUEST back as the measurement** (`got +$wx+$wy`) | **1**: DH22d — the fabrication that survived all 130 of v2's checks |
| 20 | a live-arm check (DH24) quietly deleted from the test | **1**: DH29 (`got 9 want 10`) |

### The measurement has an INDEPENDENT witness (v2.1)

Everything else about placement compares the probe's own two numbers against each
other or against the request, so a `PROBE_TCL` that dropped `winfo rootx/rooty`
and echoed the **requested** position back as the measured one passed all 130 of
v2's checks (`got == want` satisfies the tracking check by construction). **DH22d**
closes that: while the probe holds its window up, the test reads the position from
the *shell* side with a *different tool* — `xwininfo -root -tree`, whose last field
is the window's absolute position — and requires the number the probe printed to
match a number it did not produce. Measured: tree `160x60+38+59  +443+338` against
a reported `got +443+338` for a request of `+437+311`, i.e. the same (6, 27)
decoration offset in both.

Two traps in that witness, both measured and both handled by keeping the **last
settled** reading: a window appears in the tree at the WM's pre-placement frame
(`+-32730+-32709`, byte-identical to the recorded stub value) before it lands, and
the probe may **retry**, so the first settled window is not necessarily the one it
reports (measured: attempt 1 at `+6+27`, attempt 2 at `+443+338`).

**DH29 counts the live arm's checks** (10 in the measuring branch, 0 in the
partial-run branch). In v2, DH22b was asserted only inside `if verdict = HEALTHY`
and the other branch counted nothing, so a probe reporting a hardcoded wrong
position produced `fails=0` with one check fewer and no red anywhere: a shrinking
check count with nobody watching it is how a suite goes hollow.

### What the test does NOT claim

The LIVE arm checks the SCRIPT, not the MACHINE: it asserts the output shape, the
verdict/exit-code agreement and that the Tk probe really ran — so it stays green
whether the display is healthy or a stub (on a stub, DH22b asserts that the
verdict names the check behind it, rather than asserting a tracking that a stub
must not show). Making it fail on a stub would conflate
"this code is correct" with "this desktop is currently fine", and the script's own
verdict is the machine report. Run `tests/headless/wslg_health.sh` for that.

Likewise, if the user presses Pause *while the test is running*, the live arm
reports a **partial run** (`info DH22-DH27 not asserted`) instead of asserting a
measurement that was deliberately never taken. That is the gate working. In v2
that was true of the live arm **only**: measured with a standing PAUSE, the file
came back `fails=3` with an unrelated fail set (DH28, DH43 x2) and nine checks
silently gone, and the live arm itself was SIGKILLed by its own `timeout 90`
before the 300 s bound, so it printed no verdict at all and went red too. v2.1
shields every invocation that is *not* about the panel with a private empty gate
dir, and gives the live arm a bound (20 s) smaller than its own timeout.
Measured on the fixed file, whole run under a standing PAUSE: `fails=0
checks=142`, live arm `VERDICT: DEFERRED`, **zero** windows mapped.

## What remains (NOT done here)

This item shipped the **standalone script and its test only**. Still open, and
the substance of 0310's proposed fix:

* **`gate_start` / `_gate_ensure_widget` preflight** — log `panel launched onto a
  stub display` instead of a healthy-looking launch. v2's read-only,
  no-sourcing rule (ruling 7) exists precisely so this is safe to do from inside
  the gate.
* **`full_audit.sh` preflight** — abort with a distinct `ENVBAD` status, printed
  once and loudly. Not `SKIP` (scored file-wide and silently discarded) and not
  `FAIL` (reads as a code regression). It must also handle exit **4/5**: a probe
  the user stopped or paused is *not* an ENVBAD verdict and must not abort the
  run on the display's behalf.
* Issue 0310 stays **OPEN** until both are wired.

**A hazard for whoever wires it in:** the functional probe maps a real top-level
for ~0.3 s. As a manual command that is harmless, but inside `gate_pause_point`
or between tests it could take focus from an xschem window a test is driving with
`event generate` — the same trap that made the v6 reborn panel deliberately
SILENT. Wire it into `gate_start`/`full_audit` preflight (once, before the run),
never into a per-test pause point.
