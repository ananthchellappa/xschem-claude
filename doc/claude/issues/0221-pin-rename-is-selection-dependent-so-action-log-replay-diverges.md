# 0221 — the propagation makes `setprop instance … lab` selection-dependent, so action-log replay diverges

Status: **OPEN**
Severity: medium (replay differs from the recorded session, and it differs in *connectivity*)
Introduced by: `74ef1aed`, arrived on `fluid-editing` via merge 3 (`958ada03`).
Found by: the merge-3 interaction audit.

## Symptom

`xschem setprop instance <n> lab <v>` used to be a pure function of its arguments. It now
also reads the **selection**: `pin_rename_targets()` refuses with `PRR_SELECTED`
(`src/editprop.c:1020`) when a matching label is selected.

Selection changes are not always logged. So a recorded log can replay into a *different*
schematic:

- **At record time** a matching label was selected → propagation refused → only the pin
  became `B`, the label stayed `A`.
- **On replay** nothing is selected → the refusal does not fire → the label is renamed to `B`
  as well.

## A deterministic trigger

The obvious version — rubber-band a pin and its label together, press `q` — is
under-specified: `set_first_sel` stores only the **first** selected element
(`src/select.c:924-956`, set from `select_element` at `:1331`) and `edit_property` picks that
one (`src/editprop.c:1770`, `j = set_first_sel(0, -2, 0)`). With the label at the lower
instance index the generic instance form opens instead and the trigger misses.

Deterministic form:

1. Click the pin — logged as a `select_at` stash (`src/select.c:1671`), and it becomes
   `first_sel`.
2. **Shift+drag** an area band over the label — the additive area select at
   `src/callback.c:5793-5805` adds it **without** `unselect_all` and **without any log line**.
3. Press `q`, rename the pin to `B`, Apply → `schpin::apply` (`src/xschem.tcl:11085`) issues
   `xschem setprop instance $inst lab B`.

Record refuses (`PRR_SELECTED`). Replay against the same starting `.sch` with nothing
selected propagates.

## Why it matters here specifically

Action logging + replay is a `fluid-editing` feature (`doc/claude/specs/action_logging.md`);
`open_pdk` never had to consider it. The whole value of the log is that replay reproduces the
session. A command whose effect depends on unlogged state breaks that contract.

## Suggested fix

Either (a) make the `PRR_SELECTED` refusal not depend on selection — e.g. skip the *selected
label itself* rather than refusing the whole propagation, which is what the caller usually
wants; or (b) have the `setprop` arm log the selection state it observed, so replay can
reproduce it; or (c) suppress propagation entirely during replay, and document that a log
records the *effect*, not the gesture.

(a) changes the feature's all-or-nothing contract and needs a ruling — see
`doc/claude/specs/pin_rename_propagation.md`, which argues the all-or-nothing rule exists
because skipping just one label splits the net.
