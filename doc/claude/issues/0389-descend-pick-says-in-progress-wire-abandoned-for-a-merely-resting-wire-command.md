# 0389 — the descend-pick prompt says "in-progress wire abandoned" when no wire was in progress

Status: **OPEN** (measured, not fixed — the inaccurate wording is currently *pinned* by a test)
Found: 2026-08-10, crew item D6 adversary pass (`ATK-8`), after the 0257 fix landed.
Area: `xschem descend_pick` (`src/scheduler.c`) — the composed sentence; `abort_wire_line_command()`
(`src/callback.c`) returns one boolean for three distinct arms (a live rubber-band wire, a live
line, and a merely *resting* `last_command` under `persistent_command`).
Tests: `tests/headless/test_cmdmode_descend_0201.tcl` row **MS9b** asserts this exact string, so
fixing the wording is also a test change.
Related: **0257** (the fix that introduced the sentence), **0241** (a teardown must name what it is
tearing down — accurately).

## The defect

With `persistent_command=1` and a *resting* wire command (`ui_state = 0`, `last_command = 1`, no
rubber band on screen), arming the descend pick prints:

```
Descend: in-progress wire abandoned -- click the instance to descend into (ESC to cancel)
```

Nothing was in progress and nothing visible was abandoned; what the gate actually did was clear the
resting `last_command` so the press would not be swallowed into `start_wire()` (which is the real
and valuable half — see 0257 MS9). The message overstates it, and a user who was mid-thought about a
wire is told they lost one.

`descend_pick` cannot currently tell the difference: `abort_wire_line_command()` collapses "live
band", "live line" and "resting command" into a single `int`.

## Fix sketch

Give `abort_wire_line_command()` a name-returning form like the new `abort_click_mode()` — return
`"wire"` / `"line"` / `"resting wire command"` / NULL — and let each caller compose. That keeps the
0241 rule honest for every gate that uses it, not just this one. Then re-word MS9b to match, e.g.
`Descend: pending wire command cleared -- click the instance ...`.
