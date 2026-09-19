# 1488 — `test_wave_markers` hangs when `run_suites.sh` attaches to a persistent dev display

**STAMP:** `v1 claim=open tree=7a46275f stamped=2026-09-18 fix=none open=1 by=F-docs`

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
