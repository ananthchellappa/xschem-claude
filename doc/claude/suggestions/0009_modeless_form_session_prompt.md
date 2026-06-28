# Next-session prompt — Issue 0009: make the property form fully modeless (M2)

*Self-contained brief. Read the full issue first: `doc/claude/issues/0009-property-form-not-fully-modeless-blocks-schematic.md`. This is the "M2" follow-on to the M1 modeless-selection work on branch `slick-property-forms`.*

## The task

While the slick instance property form (`slickprop::edit_form`, `src/property_form.tcl`) is open, the schematic accepts only **selection** (Shift-click, via M1) and **zoom** — every other command is blocked, and the form holds window focus. Make it **fully modeless** (Cadence-style): the schematic window can be activated and run **all** bound commands while the form floats, stays consistent with the live selection, and no longer captures focus.

## Verified root cause (don't re-derive — confirm still true, then build)

1. **The `semaphore >= 2` input lock is the real blocker.** `edit_form` raises the editor semaphore on open (`property_form.tcl` ~`:878` `xschem set semaphore +1`, restored ~`:1053`). The C input dispatcher drops almost everything at that level: `if(xctx->semaphore >= 2) return 0;`/`break;` — see `callback.c:1866`, `:1891`, `:3306`, and the per-chord guards from `:3469` on. **Zoom** isn't gated (view op); **selection** is the lone M1 carve-out (`::slickprop_form_open` lets selection through at `semaphore>=2` and fires `slickprop::on_selection_changed`). That's exactly "only zoom + Shift-select work."
2. **Focus/stacking (secondary):** `edit_form` does `wm transient .dialog [xschem get topwindow]` (~`:887`); no hard Tk `grab`. `tkwait window .dialog` (~`:1050`) blocks the *calling* proc but the event loop still runs (that's how M1 selection reaches the canvas).

**The crux (D1):** the semaphore is *overloaded* — it means BOTH "a gesture is mid-flight" (a legitimate re-entrancy guard that MUST stay) AND "a modal-ish dialog is open" (the part to relax). The first job is to **audit every `semaphore >= 2` guard** and classify each: in-gesture (keep) vs form-open (relax). That audit decides whether M2 is a small change or a semaphore split. Grep: `grep -nE 'semaphore *>= *2' callback.c scheduler.c actions.c`.

## Design decisions to settle, then STOP for ratification (project recipe: characterize → decision doc → STOP → RED-first)

- **D1 — relax the form's lock without dropping the in-gesture guard.** Likely separate the two meanings (e.g. a distinct `form_open` flag already exists — `::slickprop_form_open` / `tclgetboolvar` — vs the gesture semaphore). Option: don't bump the gated semaphore for `edit_form` at all; instead gate only the truly-conflicting ops, or let the dispatcher consult `form_open` to allow canvas actions. Write `doc/claude/code_analysis/modeless_form_M2_decision.md` with the guard-by-guard audit + the chosen split.
- **D2 — consistency under live edits.** The form references the edited instance by **stable id** (`nav(disp_id)`). Moving/rotating it is fine (id survives). Deleting/replacing it must make Apply/OK no-op gracefully (id stops resolving) — verify the stable-id apply already does this and harden. Selection change already re-targets the form (M1 `on_selection_changed`); extend to the edited-object-vanishes case.
- **D3 — focus/window behaviour.** Make the form a normal toplevel (relax/drop `wm transient`) so the schematic title bar can activate it, but keep the form from getting lost behind. X11 WM behaviour varies — test on the actual WM.
- **D4 — Apply-to-live-selection.** Confirm Apply/OK/Next/Prev behave when the selection changed out from under the form (the "Apply to" scope already keys off the live selection via M1).

## Hard-won environment rules (carried from this branch)

- Run everything from `src/`: `cd .../src && ./xschem`. A Bash `cd` drift gives `./xschem` → exit 127; always `cd .../src &&` per command.
- Headless test harness: `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/property_form/wrap.tcl` → `/tmp/sh_pf_test.log` (PASS/FAIL per check, final `DONE`). For non-suite smokes use `./xschem --pipe -q --script <file>` (the bare `-q --script` form can hang into the GUI loop if the script doesn't `exit`).
- **WSLg makes scripted GUI interaction flaky** (event-generate smokes, focus, window activation) — modeless/focus behaviour is heavily WM-dependent, so the real gate here is a **manual eyeball pass on the actual display**, not headless asserts. PF42 (highlight) is an intermittently-flaky main-window-dependent test; ignore a lone PF42 fail.
- The property-form suite is `tests/property_form/{wrap,body}.tcl` (currently 220 checks). Add M2 checks where headlessly assertable (e.g. semaphore state while form open; `xschem objects -selected` re-targeting; Apply no-ops on a deleted id). `check`/`xcheck` helpers; watch the Tcl gotcha `proc f {a b}{` needs a space before `{`.
- `xschem get/set semaphore` exist (scheduler) — use them to assert the lock state in tests.

## Key references (verified this session)

- Form: `src/property_form.tcl` — `slickprop::edit_form` (semaphore bump, `wm transient`, `tkwait`), `on_selection_changed`, `adopt_selection`, `nav(disp_id)`, `maybe_apply_then` (the Apply/Discard/Cancel prompt).
- Input dispatcher + guards: `src/callback.c` (`semaphore >= 2` sites above; `dispatch_input_action`/`handle_key_press`/button handlers).
- M1 design doc: `doc/claude/code_analysis/modeless_property_form_decision.md`.
- Issue: `doc/claude/issues/0009-property-form-not-fully-modeless-blocks-schematic.md`.
- Memory: [[slick-property-forms]] (M1 = modeless selection, the carve-out this extends).

## Definition of done

Form open ⇒ clicking the schematic activates it and **all** bound commands work (not just zoom/selection); form stays open + consistent; deleting the edited object doesn't crash or mis-apply (Apply/OK no-op on a vanished id); form no longer captures focus; M1 selection re-targeting preserved; **no regression to the genuine in-gesture re-entrancy guards**. Eyeball pass recorded in the issue → RESOLVED.

## First move

Run the guard audit (`grep -nE 'semaphore *>= *2' callback.c scheduler.c actions.c`), classify each site (in-gesture vs form-open), write the D1 decision doc, and STOP for ratification before touching the dispatcher.
