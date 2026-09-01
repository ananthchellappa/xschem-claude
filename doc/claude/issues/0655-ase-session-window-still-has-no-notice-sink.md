# 0655 — the ASE session window still has no notice sink

Status: OPEN (deferred out of issue 0650 deliberately)
Filed by: the 0650 crew, 2026-08-23.

## Measured

`grep -c ciw_echo src/ase_window.tcl` = 0, against 61 lines that reference
`ase::echo`. The window the user drives the simulation from — the one they are
looking at when they press Netlist and Run — receives NOTHING. Issue 0650's own
sink-candidate 1 (a segment in the `$top.status` bar at `src/ase_window.tcl:576-592`)
and candidate 2 (`ase::ui::log_widget` / `log_append`, `:3663`/`:3706`) both remain
unbuilt.

## Why 0650 did not close it

`ase::echo` — and therefore `xschem::notify` beneath it — carries only `(msg, tag)`.
There is no session target in the signature, so a per-session-window sink cannot be
reached from inside the generic channel. The state/key seam exists only UPSTREAM:
`ase::op_cards_nudge_key` builds `{lib cell view}` from a state dict, and
`ase::session_key` turns that into a token. Wiring a session sink therefore means
either adding a target argument to the channel, or wiring each session-aware call
site (starting at `ase::op_cards_capture`) rather than the generic proc — a
different and larger decision than 0650's.

## What 0650 shipped instead

`xschem::notify` (src/ciw.tcl) with four sinks: the CIW pane, the action log file,
a budgeted fallback into the drawing window's `.statusbar.12` when the CIW is not
visible, and an opt-in non-blocking `.xschem_notify` popup (`::notify_style popup`).
None of them is the ASE session window.

## The question for the user (0650 ledger row, part a)

Is the DRAWING window's statusbar the right can't-miss fallback, or should it be a
permanent notice segment in the ASE SESSION window? Ruling pending; nothing here is
discharged by a green suite.
