# Issue 0001 — WSLg display wedge blocks the display-dependent GUI smokes

**Opened:** 2026-06-10
**Status:** OPEN — WSL restart fixed window MAPPING but not keyboard FOCUS (see
2026-06-10 post-restart update); user reports interactive breakage on our branches
but not upstream → code regression back in question; PC reboot pending, then a
controlled re-test with the confounds below removed
**Affects:** verification of `refactor/dispatcher-decomposition` batch 1 (`7ba05ba2`);
any future work relying on `event generate` / window-mapped smokes
**Severity:** originally judged environment-only; scope widened — see update

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

---

## Update 2026-06-10 — after the WSL restart: mapping fixed, FOCUS still broken

The `wsl --shutdown` restart fixed the original symptom but exposed a second,
subtler one in the same environment layer.

### What now works
- `.drw` maps and is viewable again (`winfo ismapped .drw` = 1, was 0).
- Direct `xschem callback` key dispatch works (Shift+Z via callback zooms).
- Engine harness 6/6 PASS; every callback-driven smoke layer healthy.
- A bare `wish` control (no xschem code): `focus -force` sticks, synthesized
  KeyPress fires — so the basic Tk/XWayland path is not uniformly broken.

### What still fails, and the smoking gun
The 5 display-dependent smokes fail with the same no-effect signature
(`ratio key=1`). Probe: 10 iterations of `focus -force .drw; update;
event generate <KeyPress-Z> -state 1` inside a running xschem — **`[focus]`
returned EMPTY all 10 times** and the key never had an effect. Tk silently
drops key events when the application holds no X input focus; under
XWayland, `XSetInputFocus` (what `focus -force` issues) is not reliably
honored — the Wayland compositor decides who has the keyboard. An identical
probe passed in one run and failed in the next with no code change →
focus granting to unattended X11 windows is NONDETERMINISTIC post-restart.

Two refinements to the diagnostic recipe:
- "gedit works" is NOT a valid control — gedit is Wayland-native and bypasses
  XWayland entirely; xschem is pure Xlib. Use `wish` or another X11 app.
- Add `[focus]` to the probe: empty ⇒ environment, before suspecting code.
  Wheel/button events deliver to the TARGET window and keep working;
  key events deliver to the FOCUS window and fail — that asymmetry
  (test_graph_context wheel partially works, all key smokes fail) is the
  focus-starvation fingerprint.

### New user data — code regression back in question
User reports (interactive use, same WSLg session):
- xschem built from the ORIGINAL AUTHOR'S repo, using cadence_style_rc:
  everything behaves as expected, all shortcuts work.
- Our `refactor/dispatcher-decomposition` AND `feature/action-registry`
  checkouts: "messed up" / broken "in terms of what one sees".

Taken at face value this implicates the Phase-3 era code (both branches share
it; their only code delta is batch 1 itself, `7ba05ba2` — the rest is docs).
BUT two confounds invalidate the A/B as run:

1. **Stale binary.** The branch switch to feature/action-registry happened at
   15:43; `src/xschem` was built at 14:58 — the "feature/action-registry"
   test actually ran the dispatcher-decomposition build. `make` after every
   switch; verify with `ls -la src/xschem` vs source mtimes.
2. **The rc files are NOT the same file.** Our repo's `src/cadence_style_rc`
   carries uncommitted appended `xschem bind wheel ...` lines; upstream's
   copy does not. `xschem bind` in ANY startup rc throws
   `invalid command name "xschem"` (rc files source at xinit.c ~2742, the
   `xschem` Tcl command is created at ~2845) and aborts the rest of whatever
   sourced it. If interactive launches source the repo-local copy, the A/B
   compared different rc content as well as different code. The supported
   file-remap path is `~/.xschem/mousebindings.csv` (d4b mechanism).
   Checked: `~/.xschem` currently has NO csv overrides, and nothing in this
   environment sources cadence_style_rc — but the user's interactive launch
   recipe may differ and must be pinned down.

### Revised next actions
1. PC reboot (user, in progress) — may also clear the focus nondeterminism.
2. Controlled interactive A/B with confounds removed: pristine
   `src/cadence_style_rc` (`git checkout -- src/cadence_style_rc`; move the
   wanted wheel remaps to `~/.xschem/mousebindings.csv`), rebuild per branch,
   then compare upstream vs `003d0d2d` (feature/action-registry tip) vs
   `7ba05ba2`+ (batch 1). Record the PRECISE interactive symptom — rendering?
   which shortcuts? error popups at startup?
3. Rerun the full suite. Consider hardening the smokes: retry until `[focus]`
   is non-empty before driving keys, and fail loudly with "no X focus —
   environment" instead of misleading effect failures.
4. If interactive breakage survives step 2 on our branches with green smokes,
   bisect feature/action-registry INTERACTIVELY — the smokes evidently do not
   cover whatever "what one sees" means, so capture it as a new test once
   identified.
