# 0355 — test_placement_wire_gate hangs forever under any X display (place_text modal)

Status: FIXED 2026-08-09 — both halves (nogui_tests entry + the suite's own display guard).
See RESOLUTION at the end.
Area: `tests/headless/test_placement_wire_gate.tcl` (G4), `tests/headless/full_audit.sh`
(`nogui_tests`, :78)
Found: 2026-08-09, unattended backlog run
Related: 0351 (this suite is now a CI hard gate), 0353 (same suite, repo-root leak),
0350/0354 (the audit classifier — a TIMEOUT here is scored CRASH)

## Symptom (measured, twice)

`test_placement_wire_gate` is a 171-check tier suite and a CI hard gate. It completes in a
few seconds with `DISPLAY` unset and blocks **forever** with a display:

    # green, ~5s
    $ timeout 110 env -u DISPLAY ./src/xschem --pipe -q --nolog \
        --script tests/headless/test_placement_wire_gate.tcl
    RESULT: ALL PASS (171 checks)
    OVERALL: ok

    # real WSLg DISPLAY: killed at 120s, last line "ok: G3 live: statusbar says why"
    # xvfb (GUI_GATE=0 xvfb-run -a ...): same stall, still at 143 ok lines after 300s

## Cause (located, not proven by instrumentation)

The stall is between `test_placement_wire_gate.tcl:488` (last emitted check, G3) and G4 at
`:495`, i.e. inside

    nreset ; xschem wire gui ; catch {xschem place_text}

G4's own comment (`:491-494`) says the text **dialog** "needs a Tk toplevel, so headlessly
place_text() fails and no PLACE_TEXT arms" — the suite is written for the no-display case. With
a display the dialog is raised for real and there is no one to dismiss it, so `catch` never
returns.

Three of the four 2026-08 gate suites were put in full_audit's `nogui_tests`
(`full_audit.sh:78`: `test_placement_preview_doors`, `test_paste_modify_flag_0244`,
`test_shape_draw_gate`); `test_placement_wire_gate` was not, although its own header
(`:18-19`) prescribes `--nogui`. So full_audit runs it in the plain `--pipe -q --nolog` arm,
and the CI "Full headless audit (informational)" step — which runs under `xvfb-run` — must be
scoring it TIMEOUT on every run. That step is `|| true`, which is why nobody has seen it.

Not currently red in CI's hard gates: the "Headless gate" step (ci.yaml:47) runs with `DISPLAY`
unset, which is the passing configuration.

## Not investigated here

Whether the same G4 shape blocks any other suite that calls `place_text` / a modal dialog
without `--nogui`, and whether `xschem place_text` should refuse (rather than block) when no
one can answer the dialog — that would be an engine question, not a harness one.

---

# RESOLUTION — FIXED (2026-08-09, in the 0354 item)

Both halves landed, deliberately independent of each other.

**Half A, the harness** — `test_placement_wire_gate` added to `full_audit.sh`'s
`nogui_tests` (`:78`), joining the other three 2026-08 gate suites. Measured: `--nogui`
with `DISPLAY` unset gives `RESULT: ALL PASS (171 checks) / OVERALL: ok`, ec=0 — identical
to the plain arm, so CI's "Headless gate" does not move.

**Half B, the suite itself** — a column-0 early-out before its first check:

    if {[info commands winfo] ne {} && [winfo exists .]} {
      puts "RESULT: SKIP (needs --nogui: G4's place_text raises a modal nothing can dismiss -- issue 0355)"
      exit 0 }

## BEFORE / AFTER

BEFORE, measured twice: killed at 120s under real WSLg X (last line `ok: G3 live:
statusbar says why`), and still stalled at the same 143 ok-lines after 300s under
`GUI_GATE=0 xvfb-run -a`.

AFTER, verified under xvfb (never the user's display):

    $ GUI_GATE=0 xvfb-run -a ./src/xschem --pipe -q --nolog --script tests/headless/test_placement_wire_gate.tcl
    RESULT: SKIP (needs --nogui: G4's place_text raises a modal nothing can dismiss -- issue 0355)
    ec=0, elapsed 0s

## The guard is provably inert where it matters

Probed in all four configurations with a 3-line script, never the 171-check suite under a
real display: `info commands winfo` is `{}` under `--nogui`+DISPLAY-unset, under plain
`--pipe`+DISPLAY-unset, AND under `--nogui` beneath xvfb — that last one being the
informational-audit path where a false SKIP would have cost 171 checks. It is `winfo`
with `winfo exists .` == 1 only in plain-under-X, exactly where the hang was. The suite
still yields `RESULT: ALL PASS (171 checks)` in both headless arms.

## Decision

**R2 — both halves in one item.** REJECTED: the harness-only one-word fix — it leaves a
120s+ infinite hang live at `test_placement_wire_gate.tcl:495` for any human or agent who
runs the suite by hand under X, which is how this crew's scout lost two measurement
windows.

## Still open

Under a display, `run_suites.sh test_placement_wire_gate` now scores **FAIL** rather than
hanging (`run_suites.sh:105` treats `RESULT: SKIP` as a failure to deliver — ratified,
0350 D5). Better than a hang, but it is a new red row on that path and was not in the
plan's risk list.

Not investigated: whether the same G4 shape blocks any other suite that calls `place_text`
or a modal without `--nogui`, and whether `xschem place_text` should refuse rather than
block when no one can answer the dialog. That is an engine question, not a harness one.
