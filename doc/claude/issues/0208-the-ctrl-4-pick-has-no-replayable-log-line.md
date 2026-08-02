# 0208 — the Ctrl-4 pick has no REPLAYABLE action-log line, and the altitude is unresolved

Status: **OPEN**, and deliberately not started. Filed 2026-08-02 while fixing
[0207](0207-ase-ciw-messages-never-reach-the-log-file.md), which delivered the *other* half
(ASE's informational messages now reach the log as `#= ` / `#! ` comment lines). This issue
is 0204's "What is deliberately left undone" item 1, promoted to its own number so the
design question does not ride on an unrelated fix.
Area: `src/ase_window.tcl` (`ase::ui::sod_click`, `ase::ui::dp_queue`, `ase::ui::dp_finish`,
`ase::ui::select_on_design`, `ase::ui::sod_end`), `src/scheduler.c` (whatever subcommand a
replayable form would need), `src/util.c` (the absorb machinery).
Tests: none. `tests/headless/test_ase_log_seam_0207.tcl` leg **PS13** PINS THE ABSENCE — a
Ctrl-4 pick writes no `xschem …` line today, and that leg goes red the moment one appears.
Whoever takes this issue must update PS13 rather than delete it.
Related: [0204](0204-sod-pick-mutates-the-selection.md) (removed the pick's old
`xschem select_at x y` line, which was a lie once the pick stopped selecting),
[0207](0207-ase-ciw-messages-never-reach-the-log-file.md) D5 (this fork, stated),
[0201](0201-no-command-suspend-resume-contract.md) (suspend/resume, one of the two hazards),
[0206](0206-ase-plot-p4-direct-plot-click-queues-nothing.md).
Specs: `doc/claude/specs/action_logging.md` (source-ability), `action_log_absorb.md` (the
outcome-level doctrine), `select_at.md`, `ase_l.md`.

## The gap

`select_at` used to stash a replayable `xschem select_at x y` for every interactive click,
including a Ctrl-4 pick. 0204 stopped the pick from selecting at all — a pick is not a
selection — so that line became a record of something that no longer happens and was
removed. It was never a faithful record of the pick anyway: replaying it selected an object;
it did not queue a trace.

0207 then put the pick's *narration* into the log:

```
#= ase: Direct Plot — click wires/net labels for voltage traces, sources for current traces; ESC plots
#= ase: queued trace 'v(named)'
#= ase: Direct Plot — 1 trace(s) queued
```

That is a transcript, and it is what the user asked for. It is **not** replayable: `source`ing
the log re-runs nothing. A full-session replay still cannot reproduce a Direct Plot.

## The fork (0207 D5), and the recommendation

**Gesture-level** — log each click as `xschem ase_sod_click <key> <x> <y>` (plus entry and
ESC lines). Rejected. Two hazards kill it, and neither is hypothetical:

1. A **BUS** pick opens a modal bit-selection dialog (`ase::ui::bus_dialog_result`,
   `ase_window.tcl`). A logged click is not self-contained: replaying it stops on a modal
   waiting for a human. The absorb doctrine's own rule — log the effect, not the gesture —
   already forbids this shape.
2. The mode can be **suspended and resumed onto a different canvas** mid-sequence
   ([0201](0201-no-command-suspend-resume-contract.md): `sod_suspend` / `sod_release` hand
   the seized bindings back without finishing the command). A coordinate replayed against
   the wrong canvas silently picks the wrong net, or nothing. Coordinates only mean anything
   relative to a canvas the log does not identify.

**Outcome-level — recommended.** One self-contained line per Direct Plot, minted at the
`dp_finish` seam where the queue is already complete and coordinate-free:

```tcl
xschem ase_direct_plot <key> {v(named) i(v1) v(x1.minus)}
```

Why this one:

- **Coordinate-free**, so it survives both hazards above: a bus pick has already been
  expanded to its bits by the time it reaches the queue, and a suspend/resume that changes
  canvas changes nothing about the resulting expression list.
- It matches the **granularity decision** in `action_logging.md` §2 ("a multi-event gesture
  collapses to its single resulting command") and the `action_log_absorb.md` doctrine that
  produced `log_action_descend`'s `-inst` form for exactly this reason.
- It is the level at which the operation is **meaningful to replay**: the user's intent was
  "plot these three signals", not "click at (100,0)".
- `dp_finish` already receives `key`, `queue` and `qcolors`, so the line needs no new state
  capture — unlike the gesture form, which would need the canvas identity threaded through.

Accepted cost: an **aborted** pick sequence (ESC with an empty queue) leaves no trace, and
intermediate de-duplication ("already queued") is invisible. That is the same trade Layer C
made for gesture starts (Phase 3 slice D csv-`nolog`) and is consistent, not a new hole. The
0207 transcript comments still record the blow-by-blow for debugging.

## What has to be built

1. A real subcommand — `xschem ase_direct_plot <key> <list>` or a Tcl-side
   `ase::ui::direct_plot_queue` — that performs the plot from an expression list with no
   canvas and no mouse. Today `dp_finish` is the only path and it is reached only from
   `sod_end`.
2. Decide what `<key>` means on replay. A session key is `lib/cell/view`; the session must
   exist. A replay that loads a different design has nothing to bind to — an honest failure
   (`ase::echo` an error, do not throw) is probably right, but it is a decision.
3. `test_selflog_output.tcl` requires every logical line to be a `#` comment or start with
   `xschem ` — so the line must be an `xschem` subcommand, not a bare `ase::ui::…` proc call.
   **Blocked on [0209](0209-log-format-rule-and-practice-have-drifted.md)**: LibMgr, the
   waveform viewer and `xschem.tcl` already log bare namespaced proc calls at 32 sites and no
   test catches it, so whether `ase::ui::direct_plot …` is legal is exactly that issue's open
   decision. Stay inside the current rule if 0209 is still open when this is taken.
4. `test_selflog_grep_guard.tcl` forbids a `.tcl` file hand-logging a literal `xschem <verb>`
   for a verb whose C core self-logs, unless gated on `log_action -emitted`. A new
   Tcl-side log call must respect that.
5. Flip leg **PS13** in `tests/headless/test_ase_log_seam_0207.tcl` from "no replayable line"
   to "exactly this replayable line", and add a record→replay→diff leg in the shape of
   `tests/headless/test_action_replay.sh`.

## Do not confuse this with 0207

0207 is **closed by comments**. This issue is about **commands**. A `#=` line is invisible to
`source` by design — adding more of them can never deliver replay, and no amount of 0207
follow-up work moves this issue forward.
