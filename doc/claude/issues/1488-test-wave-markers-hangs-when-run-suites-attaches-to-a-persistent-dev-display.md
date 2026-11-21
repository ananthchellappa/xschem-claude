# 1488 — `test_wave_markers` hangs when `run_suites.sh` attaches to a persistent dev display

**STAMP:** `v1 claim=open tree=c84aee78 stamped=2026-09-20 fix=none open=2 by=stranger-reds`

**Status: OPEN — filed 2026-09-18** by the outsider-fixes batch, stage F (docs crew), from
`doc/claude/outsider_fixes_batch/DECISIONS.md` D20.7 ("recorded, not fixed … It goes into
CLAUDE.md"). **Pre-existing:** identical in the code before the batch. **Class** a suite
that stalls on one display arm. **Related:** **0826** (`test_wave_markers` `MX7b`/`MX7d`
go red when Tk key delivery stalls, a load-sensitive flake), **1403** (the bounds that
turn a stall into a named `TIMEOUT`).

---

## What happens

On the display arm, `run_suites.sh` (through `xvfb_arm.sh`) **attaches** to the
persistent dev display when one is up, and otherwise starts a private `xvfb-run`
display. `test_wave_markers` passes on the private one and **hangs on an attached one**.
The driver's bound then reports `TIMEOUT`.

MEASURED by the S2c round-3 safety refuter (`receipts/S2c_refute_r3.md`, the last
problems entry):

| tree | display | result |
|---|---|---|
| round-3 fix | fixture Xvfb `:196`, attached | `TIMEOUT` at 200 s, and again at 600 s |
| round-3 fix | `:197`, started by `devdisplay.sh`, attached | `TIMEOUT` at 300 s |
| base (before the batch) | fixture `:196`, attached | `TIMEOUT` at 200 s |
| base | `:197` via `devdisplay.sh`, attached | `TIMEOUT` at 300 s |
| both | `run_suites.sh`'s private `xvfb-run` display | `ALL PASS (983 checks)` |

**Consequence:** a developer whose `:99` is up, which CLAUDE.md tells them to keep up,
gets a `TIMEOUT` for this suite from the documented single-suite command. It is not
their change.

## An earlier sighting, not separated

The S2a redirect study ran the display-arm suites on Xvfb servers it had started itself
(`:187`–`:189`, with openbox, HOME in scratch) and saw **four** suites hang in every
variant, with rc 124 at baseline too (`receipts/S2a.md`, the "GUI arm" paragraph):
`test_wave_markers` (it stopped after row `MF11a`), `test_placement_preview_doors`,
`test_paste_modify_flag_0244` and `test_shape_draw_gate`. Whether the other three share
this cause, or hang on attached displays too, is **not established**.

## What is not known

* **What differs between the two displays.** Both are Xvfb, both run openbox, and
  `AUDIT_SCREEN` sets the same default screen. Candidates, all INFERRED: the X authority
  set up by `xvfb-run` (an `-auth` cookie) against an unauthenticated persistent server;
  state left on a long-lived server by earlier clients (focus, a leftover toplevel);
  timing.
* **Where it stops.** S2a saw it stop after `MF11a`. `MF11a` sets the buffer read-only and
  then presses a key that must be refused (READ). A refusal that raises a modal dialog
  nobody dismisses is the stall shape CLAUDE.md records for display arms, but that it is
  the cause here is INFERRED only.

## Fix direction

1. Reproduce with the watchdog's last-output clause
   (`XSCHEM_SUITE_WATCHDOG_MS` below the driver's bound). It names the row after which the
   suite stopped, which is the finding.
2. If it is a modal, make the refusal path non-blocking under test, or dismiss it
   deterministically, as `test_calc_skeleton` S12 forces its race. Do not rely on a
   display that happens not to raise it.
3. Then run the other three S2a suites on an attached display, to see whether this is one
   issue or four.

## Evidence

`doc/claude/outsider_fixes_batch/receipts/S2c_refute_r3.md` (problems:
"PRE-EXISTING, not a regression"), `receipts/S2a.md` ("GUI arm" paragraph),
`DECISIONS.md` D20.7.

---

## 2026-09-20 — a SECOND suite shows the same shape

MEASURED by the stranger-reds batch, item F's fix round
(`doc/claude/stranger_reds_batch/receipts/F-verify.md` §10), while verifying issue 1486 and
not looking for this: **`test_load_window_routing` returns `TIMEOUT … (after 200s)` from
`run_suites.sh` on the persistent dev display `:99`**, and reds four rows (`LR1b`, `LR5b`,
`LR5e`, `LR6`) on the `--nogui` arm.

**Pre-existing, proved rather than argued:** the crew checked out `src/actions.c`,
`src/save.c` and `src/xschem.h` at HEAD — i.e. with no product change of item F's at all —
rebuilt, and ran the same command: the **same four rows, same messages**. Sources restored
and rebuilt afterwards.

Recorded here rather than filed fresh, on that receipt's own recommendation. It bears
directly on this file's fix step 3 (*"run the other three S2a suites on an attached display,
to see whether this is one issue or four"*): whatever the mechanism is, it is **not** unique
to `test_wave_markers`, and a second name is the cheapest evidence anyone has added to that
question. `open=2` counts the two suites.

---

## 2026-11-19 — `test_wave_markers` also times out on a PRIVATE display now

The stamp line above is left as it was. This section records a measurement that
contradicts this file's table, whose last row says the suite passes on `run_suites.sh`'s
private `xvfb-run` display.

MEASURED by the verifier of the command-mode part of issue 1724's fourth repair, while
running that work's neighbours and not looking for this:

```
AUDIT_DISPLAY=private SUITE_TIMEOUT=300 tests/headless/run_suites.sh test_wave_markers
  -> TIMEOUT | test_wave_markers run 1/1 (after 300s)
```

Three runs, all on a private Xvfb with openbox, each ended by the driver's bound. Before
the stall the suite printed `FAIL:` rows in groups `MF9`, `MF2`, `MF10`, `MF8` and `MF7`
and `MARKER-TEST-STALL:` lines of its own (`MF9 control could not arm a marker drag (1)
after 3 tries`, `MF8 strip-0 empty pixel scan found nothing after 3 tries`, and the like),
and it then stopped after row `MF11a`, the row after which S2a saw it stop (above).

**It is not that work's.** One of the three runs was made with the `src/cmdmode.tcl` of
before that repair sourced over the tree's: the same red rows and the same `TIMEOUT`. The
suite references no `cmdmode` proc. The third review of issue 1724 noted the same reds on
a build of that branch's HEAD (`d36cb429e`); the verifier did not run a build of HEAD
itself.

**What this does to the file.**

* The table's last row (`both | private xvfb-run display | ALL PASS (983 checks)`) is the
  record of 2026-09-18. On this tree the private display does not pass either, so the
  "attached against private" split this issue is named for no longer separates the two
  arms, and the candidates under "What is not known" that rest on that split (the X
  authority, state left on a long-lived server) are weakened.
* New, and not explained: the `MF` rows that go red BEFORE the stall. They say no marker
  anchor was found by the suite's pixel scan and no marker drag could be armed. Whether
  that is the suite's scan or the viewer's drawing was not looked into.
* CLAUDE.md's sentence that the suite "passes on the private `xvfb-run` display" and that
  `AUDIT_DISPLAY=private` takes that arm is stale by this measurement.

**Not measured:** which commit the private display stopped passing at; whether the reds
before the stall and the stall share a cause; the dev display `:99` on this tree; the
other suites this file names.

Evidence (session scratch of 2026-11-19, not kept in the repository): the verifier's
`logs/suites2.log` and its three run logs of the suite.
