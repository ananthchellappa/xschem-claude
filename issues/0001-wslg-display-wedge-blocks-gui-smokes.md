# Issue 0001 — WSLg display wedge blocks the display-dependent GUI smokes

**Opened:** 2026-06-10
**Status:** OPEN — waiting on a WSL restart (user action), then a full-suite rerun
**Affects:** verification of `refactor/dispatcher-decomposition` batch 1 (`7ba05ba2`);
any future work relying on `event generate` / window-mapped smokes
**Severity:** environment only — no code defect identified

## Summary

Mid-session the WSLg X compositor degraded: xschem's drawing window no longer maps
(`winfo ismapped .drw` = 0, `winfo viewable` = 0, `focus -force .drw` refused —
focus stays on `.`). Tk silently drops synthesized KeyPress events delivered to an
unmapped window, so every smoke that drives keys via `event generate` fails with
"no effect" symptoms, and the graph-fixture tests hang at startup.

## Observed failures (all reproduce IDENTICALLY at clean HEAD `003d0d2d`)

| Test | Symptom |
|---|---|
| `test_accelerators` | 4 FAILED — zoom/undo "ratio key=1" (key press has no effect) |
| `test_remap` | 3 FAILED — same no-effect pattern |
| `test_key_graph_context` | HANGS, zero output (killed by timeout) |
| `test_graph_context` | 1 FAILED |
| `dump_file_menu` | HANGS, zero output |

Unaffected (all PASS on the new code): engine harness 6/6, `test_keybindings_help`,
`test_mouse_bindings`, `test_gesture_bindings`, `test_binding_precedence`,
`test_bindings_file` — i.e. everything driven through `xschem callback`, which
bypasses X event delivery entirely.

## Evidence the code is exonerated

- Stash-bisected both ways: with the batch-1 change stashed (clean HEAD — the state
  that was fully green earlier the same day), the same five tests fail/hang the same
  way; with it restored, the same five and only those.
- Direct probe (`/tmp/probe_keys.tcl` pattern): `event generate .drw <Shift-Key-Z>`
  leaves zoom unchanged while `xschem callback .drw 2 100 100 90 0 0 0` zooms —
  same binding row serves both, so the binding table and dispatch are healthy;
  only Tk→X event delivery is broken.
- The first symptom (a hung `test_key_graph_context` in a background suite run at
  14:44) predates any process kills — the kills were cleanup, not cause.

## Diagnostic recipe (for recurrence)

1. Effects fire via direct `xschem callback` but not via `event generate`? →
   display problem, not code.
2. Confirm with `winfo ismapped .drw` (expect 1 on a healthy display).
3. Stash the suspect change and rerun at clean HEAD before touching code.

Recorded as a themed lesson in `claude_suggs/lessons_learnt_action_registry.md`
(§13, environment gotchas).

## Fix / next action

1. Restart WSL from Windows PowerShell: `wsl --shutdown`, then reopen the distro
   (kills the Claude session; all work is committed).
2. Rerun the FULL suite on `refactor/dispatcher-decomposition`
   (`tests/headless/run.sh` + the 11 smokes).
3. Only after a fully green run, close this issue and proceed to dispatcher
   decomposition batch 2 (letters d+; recipe in
   `claude_suggs/plan_dispatcher_decomp_batch1.md`).

## Context

Batch 1 (scheduler letters a–c extracted verbatim into `xschem_cmds_a/b/c`) is
committed with this caveat documented in the commit message and the plan doc's
verification record. The five blocked smokes are the only outstanding verification.
