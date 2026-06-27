# Decision doc — action-logging the property apply

*Status:* **IMPLEMENTED 2026-06-14** (apply: RED/GREEN; launch marker: §6, RED-first). Logged in
`slickprop::do_apply` via the `slickprop::log_apply` seam → `xschem log_action`;
gated on `$did`. Tests PF47a–e (suite 124). FAQ Q13 corrected to match the
form-layer placement. Out of scope: the legacy vim path; cross-session referents
(issue 0005).
Closes the coverage gap raised in [[FAQ]] Q13: property edits never reach the
action log. Builds on the action-logging work
([[action-logging]]) and the multi-instance apply
([[multi_instance_property_editing]]).

*Summary:* make an interactive property **Apply / OK** append its replayable
effect — `xschem apply_properties <scope> <displayed_id> <new> <old>` — to the
action log, so a session that edits properties produces a faithful, replayable
log. Log the **effect**, at the **interactive layer**, **only when something
changed**.

---

## 1. The one decision that matters: *where* to log  *(corrects FAQ Q13)*

FAQ Q13 sketched the fix as "one `log_action` in `apply_instance_properties()`
(the funnel)." **That placement is wrong**, and the reason is the load-bearing
lesson of the action-logging architecture (see the comment at `callback.c:1435`:
*"hooking move.c instead would double-log every replay"*).

The action log records actions at the **interactive layer**, never at the shared
engine function that the *replayable command reuses*. For the property apply:

| caller of the effect | path |
| --- | --- |
| the form's OK / Apply | `slickprop::do_apply` → `xschem apply_properties` → `apply_instance_properties()` |
| a CIW-typed command | CIW → `xschem apply_properties` → `apply_instance_properties()` |
| replay (sourcing the log) | `source` → `xschem apply_properties` → `apply_instance_properties()` |
| a script / keybinding | → `xschem apply_properties` → `apply_instance_properties()` |

All four converge on `apply_instance_properties()`. So a `log_action` *there*
fires for **every** caller — including the ones that must NOT be logged from the
engine:

- **the CIW already logs typed commands itself** (`log_action_noecho`, util.c) →
  engine logging would write the line **twice**;
- **replay must not re-record** (the established behavior: replaying
  `xschem move_objects` re-executes but does not re-log) → engine logging would
  make replay grow a fresh copy of every applied edit.

The **form** path, by contrast, is purely interactive: replay/CIW/scripts never
call `do_apply`. So logging in `do_apply` records exactly the interactive form
applies — once each — and leaves the command itself (`xschem apply_properties`,
the replay vehicle) unlogged, identical to how move/zoom log at the gesture layer
in `callback.c`, not in `move.c`.

> **Decision D1:** log in **`slickprop::do_apply`** (Tcl, the interactive layer),
> NOT in `apply_instance_properties()`. This is the same "log the gesture, not the
> engine the command reuses" invariant the rest of the log already follows.

(FAQ Q13's "fix" snippet will be corrected to point here.)

---

## 2. The rest of the decisions

- **D2 — what to log.** The replayable command itself:
  `xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop>`, built
  with Tcl **`[list …]`** so the four arguments are quoted to re-parse correctly
  when the log is sourced (more robust than the C `{%s}` convention for strings
  that may contain spaces/quotes/newlines). The logged line **is** the apply
  command — not a `log_action` wrapper — so replay runs the apply directly.
- **D3 — when to log.** Only when the apply actually changed something
  (`do_apply` already computes `$did` = `xschem apply_properties …` return). A
  no-op apply (OK with no edits) logs **nothing** — log effects, not intentions.
- **D4 — the Tcl→log bridge.** Reuse the existing **`xschem log_action [-noecho]
  text`** command (scheduler.c:3598) — it appends one line to `Xschem.log` and
  mirrors it to the CIW pane. **No new C is needed.** Plain `log_action` (with the
  CIW echo) so the user sees the applied edit in the log pane, consistent with
  other effect logs. (`xschem log_write` is a no-op debug stub — not this.)
  Wrap the call in a thin seam `slickprop::log_apply {line}` so it has one place
  to evolve and a clean spy point for tests.
- **D5 — referent stability (noted, not solved).** `displayed_id` is a
  **session-stable** id (issue 0005, "stable referents"). Same-session replay is
  exact; cross-session replay of a stale id is a **safe no-op** —
  `apply_instance_properties` resolves `inst_index_from_id(id) < 0` and returns 0
  without touching anything. So a stale line degrades gracefully (no crash, no
  wrong-object write). Cross-session durability is the separate 0005 work.
- **Scope of coverage.** Covers the slick form's **OK and Apply** (both go through
  `do_apply`). Does **not** cover the legacy/vim editor path (`'Q'` →
  `edit_property(1)` → `update_symbol` → `apply_symbol_prop`, which bypasses
  `apply_instance_properties` and has no stable-id command form). That path is
  deprecated; logging it is explicitly out of scope here and noted as a remaining
  gap.

---

## 3. No-double-log verification (the invariant, case by case)

| trigger | logs via | engine logs? | total lines |
| --- | --- | --- | --- |
| form OK / Apply (interactive) | `do_apply` → `log_apply` | no | **1** ✓ |
| CIW-typed `xschem apply_properties` | CIW (`log_action_noecho`) | no | **1** ✓ |
| replay (`source Xschem.log`) | — (not via form/CIW) | no | **0** ✓ (re-executes, matches move/zoom) |
| script / keybinding calling the command | — | no | **0** (same class as replay) |

The logged line is `xschem apply_properties …` (not `xschem log_action …`), so
sourcing the log re-applies the edit and does not re-log it.

---

## 4. Test plan (RED-first, headless, reliable)

Add to `tests/property_form/` (suite at 119; keep green). Drive a real form apply
(`pf_form_run`, as PF26/PF43 do) and **spy on the log seam**: redefine
`slickprop::log_apply` to capture its argument into a Tcl list (the same
seam-spy technique the suite uses for `tk_messageBox`). This tests the
*decision logic* (when to log + the exact replayable line); the file write itself
is the already-proven `xschem log_action` infra.

- **PF47 — OK with an edit logs exactly one apply line**, and the line is the
  replayable command naming the scope, the displayed stable id, and the new value
  (e.g. matches `xschem apply_properties current <id> *value=2k*`).
- **PF47 — a no-op OK (no edit) logs nothing** (the `$did` gate).
- **PF47 — the Apply button (`apply_now`) also logs** (it routes through
  `do_apply`).
- **PF47 — the line carries both new and old prop** (so replay can diff
  changed-fields-only, the apply contract).

**Sabotage after green:** drop the `$did` gate (always log) → the no-op test
reddens; log a constant/blank line → the content tests redden. Revert.

Integration note (manual / eyeball): with logging enabled (`--logdir` or an
interactive session), do a form apply and confirm the real `Xschem.log` gains the
`xschem apply_properties …` line and that sourcing the log re-applies it. Not a
suite assertion (the log path/enable depends on `has_x`/`--logdir`).

---

## 5. Implementation shape (on ratification — small)

- **Tcl (`property_form.tcl`):**
  - new seam `proc slickprop::log_apply {line} { catch {xschem log_action $line} }`;
  - in `do_apply`, after a successful apply (`$did`), call
    `slickprop::log_apply [list xschem apply_properties $::slickprop_apply_scope
    $nav(disp_id) $::tctx::retval $cur(orig)]`.
- **C:** none.
- **Docs:** correct FAQ Q13's "fix" snippet (engine → form); note the change in
  the action-logging spec/checklist if present on this branch.

---

## 6. Follow-on — logging the *launch* (the form opening) — IMPLEMENTED 2026-06-14

*Want:* also record that the user **opened** the Edit Properties form (not just
the apply). *Decision (ratified, now implemented):* log it as a **non-replayable
`#` marker**, not a replayable command. Shipped: `slickprop::log_event` seam +
the marker emit in `slickprop::edit_form`; tests PF48a–c (suite 127); FAQ Q13
updated. Sabotage-verified (drop the emit → PF48 reddens).

**Why a marker, not `xschem edit_prop`.** `edit_prop` opens a **modal**
(`edit_form` → `toplevel .dialog` + `tkwait`). A replayable `xschem edit_prop`
line would, on `source`, re-open the dialog and **block** (interactive) or **hang
on `tkwait`** (headless). And the launch is a pure *intention* with no state
change — the only effect (the apply) is already logged (§1–§5). So the launch is
recorded for **audit/readability only**, as a Tcl comment that `source` skips:

```
# xschem edit_prop current — Edit Properties form opened (non-replayable: modal)
```

**Where.** At **`slickprop::edit_form`** — the single point every launch route
converges on (`q` → `edit_property(0)` → `tcleval edit_prop`; the menu → Tcl
`edit_prop`; `xschem edit_prop [scope]` → `edit_property(0)` → all reach
`edit_form`). One marker per open, covering every entry. Logged at the
interactive layer (replay sources `apply_properties`, never `edit_prop`, so
`edit_form` is not re-entered on replay; and a `#` line is inert anyway).

**Seam + emit.** A generic `slickprop::log_event {line}` (= `catch {xschem
log_action $line}`, sibling of `log_apply`) emits the already-built marker; the
test spies on it. Marker built in `edit_form` from `::slickprop_apply_scope`.

**Replay-safety (the whole point).** Sourcing the log runs the `#` line as a
comment — no dialog, no hang — while the line still documents the exact launch
(and is one un-comment away from a manual re-launch).

**Test (RED-first).** Spy on `slickprop::log_event`; open the form via
`pf_form_run` and assert (read *after* the run, so it is robust to the
modal-build flake — the marker is emitted synchronously inside `edit_form`,
before `tkwait`): exactly one marker, and it is a `#` comment naming
`edit_prop` + the scope. Sabotage: drop the marker emit → the test reddens.
