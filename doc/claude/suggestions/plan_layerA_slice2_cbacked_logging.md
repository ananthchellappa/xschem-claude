# Plan — action-log Layer A slice 2: log C-backed dispatched actions

**Date:** 2026-06-11. **Branch:** `feature/action-logging`.
**Spec:** `doc/claude/specs/action_logging.md` §2 Layer A; checklist rows 22 (partial→), 24.
**Builds on:** slice 1 (`ec8de190`) which logs Tcl-backed actions at
`dispatch_input_action()`; C-backed actions (`d->fn`) still log nothing.

## The constraint that shapes the design

Spec §2 Layer A: "C-backed actions need the canonical command surfaced to C
from the single source (`actions.csv` col 6 / `ActionDef`) — **never
hand-written per call site**." So the command strings must flow FROM the csv
TO the C registry at runtime, not be retyped into `callback.c` (a second copy
would drift; d3's lesson: generate every view from the live source).

## Decisions (proposed, lock at implementation)

1. **Push, don't parse:** Tcl already parses the csv (`load_action_table`,
   `action_registry.tcl:59`). After it runs (and after the `xschem` command
   exists — same window where keybindings.csv replays, xschem.tcl post-
   `load_action_table`), Tcl iterates `action_table` and pushes each row's
   non-empty `command` into C via a new subcommand:
   `xschem set_action_log_cmd <id> <cmd>`. No csv parsing in C.
2. **Unknown ids are silently ignored** by the subcommand: the csv has ~132
   rows (menus, palette) but only ids present in the C `action_registry`
   (~40) can ever dispatch; menu-only ids are legitimate non-matches, not
   errors. Return 1/0 (stored / not) so a test can probe.
3. **Storage:** append `const char *log_cmd;` to `ActionDef`
   (callback.c:2327) and drop the registry array's `const` (it becomes
   write-once-at-startup). C89 partial initializers zero-fill the new field —
   zero diff to the existing 40 entries. Store via `my_strdup(_ALLOC_ID_, ...)`.
4. **Log after the fn runs and only if it handled the event:**
   ```c
   if(d->fn) {
     int ret = d->fn(e);
     if(ret && d->log_cmd) log_action("%s", d->log_cmd);
     return ret;
   }
   ```
   Mirrors slice 1's record-after-evaluation rule (C fns don't "fail" like
   Tcl, but ret==0 means "didn't handle" — nothing to replay).
5. **Empty-command ids stay SILENT this slice — no `#` markers.** Rationale:
   the empty-command C-backed ids are wheel/arrow-frequency view actions
   (scroll_*, pan_*) plus gesture-start/routing rows (zoom_rect — its effect
   is logged at the gesture END in Phase 2/Layer C; graph.forward — pure
   routing, fires for every event over a graph). Markers here would flood the
   log with non-replayable noise at wheel speed. Phase 3 mints
   `pan`/`scroll`/`snap` subcommands, turning most of these into real logged
   commands; the `#`-marker mechanism (spec row 16) lands where it is
   load-bearing — click-select, Layer B/C. Nothing special-cases in C: no
   pushed command ⇒ no log, automatically (zoom_rect and graph.forward have
   empty/no csv command, so they need no flag).

## Step 0 — equivalence audit (gates everything)

LESSON (memory, sem-gated batch 1): "a menu command looks like this key" is a
hypothesis — read the scheduler branch. Logging a csv command that does
something DIFFERENT from the dispatched C fn would make the log a lie. For
each C-backed id with a non-empty csv command, verify csv cmd ≡ act_* fn
behavior (params included) before allowing the push:

| id | csv command | verify against |
|---|---|---|
| view.zoom_in | `xschem zoom_in` | act_zoom_in → view_zoom(0.0); scheduler `zoom_in` (d4a already proved ≡: 0.0 defaults to CADZOOMSTEP, actions.c:3028) |
| view.zoom_out | `xschem zoom_out` | act_zoom_out vs scheduler `zoom_out` (same d4a argument — re-confirm) |
| view.zoom_full | `xschem zoom_full` | act_zoom_full vs scheduler `zoom_full` branch — check flags/center args |
| view.toggle_colorscheme | `xschem toggle_colorscheme` | act_toggle_colorscheme vs scheduler branch (incl. redraw + dark_colorscheme var sync) |
| prop.toggle_ignore_attribute_on_selected_instances | `xschem toggle_ignore` | act_toggle_ignore vs scheduler branch |
| sym.attach_net_labels_to_component_instance | `xschem attach_labels` | act_attach_labels vs scheduler branch — DIALOG suspicion: key path may prompt; verify same entry point |
| sym.make_schematic_and_symbol_from_selected_components | `xschem make_sch_from_sel` | act_make_sch_sym_from_sel vs scheduler `make_sch_from_sel` — NAME SMELL: csv says sch only, id says sch AND symbol; verify whether the scheduler cmd makes both |

Outcomes per id: (a) equivalent → push; (b) csv command wrong/different →
fix the CSV (it is the single source — menus improve too) only if the menu
behavior is also wrong, else leave both and DON'T push (document why); (c)
ambiguous → don't push, defer. The audit result table goes in the commit
message.

Empty-command C-backed ids (silent this slice): pan_l/r/u/d, scroll_u/d/l/r,
zoom_rect, graph.forward (no row), edit.toggle_stretch, view.snap_half,
view.snap_double, view.toggle_show_netlist, edit.toggle_orthogonal_wiring,
view.toggle_draw_pixmap. The six toggles LOOK mintable today (likely existing
`xschem` subcommands or trivial `xschem set` forms) — if the audit finds an
existing exact subcommand, adding it to the csv `command` column is in scope
(it is a data fix, and the menus gain the entry too); minting NEW subcommands
is not (Phase 3).

## Steps

1. Audit (step 0); record results.
2. `callback.c`: `log_cmd` field; drop registry `const`; dispatch change
   (decision 4); `set_input_binding`-style setter
   `set_action_log_cmd(id, cmd)` + registration in the scheduler s-block
   (`xschem set_action_log_cmd <id> <cmd>`, returns 1/0 per decision 2).
3. `xschem.tcl`: after `load_action_table` (next to the keybindings.csv
   replay), loop `action_table`, push non-empty commands. Guard with
   `info commands xschem` like the replay block does.
4. Tests — extend `tests/headless/test_action_log_dispatch.tcl`:
   - FLIP the slice-1 check "C-backed action adds no line (yet)" → wheel
     zoom-in now logs exactly `xschem zoom_in`.
   - Replay equivalence for one C-backed id: press F (view.zoom_full), note
     zoom; disturb the view (scroll); `source` the captured log into the SAME
     instance and assert zoom returns to the F value. (First real
     record→replay assertion — the row-50 acceptance smoke generalizes this.)
   - Arrow scroll (empty command) still adds no line.
   - `xschem set_action_log_cmd nonsense.id x` returns 0, sticks nothing.
   - Keep: Tcl-backed verbatim, # failed comment, idle-skip, source-ability.
5. Docs: checklist row 24 → yes, row 22 → "partial (empty-command ids silent
   until Phase 3 minting)"; spec §5 status line. Memory update.
6. Verify: rebuild; the extended dispatch smoke + test_nolog + test_ciw +
   test_action_log.sh + engine harness + full GUI sweep (all with the
   `--nolog` pattern). Commit.

## Explicitly out of scope (next atomic steps after this)

- Row 50 acceptance smoke (record → replay into a FRESH instance → diff
  state) — next after this slice; this slice's in-instance replay check is
  its seed.
- `#`-markers for no-Tcl-form actions (row 16) — with Layer B/C.
- Minting pan/scroll/snap subcommands (rows 29–31, Phase 3).
- Layer B (context menu, row 25), Layer C (gesture ENDs, rows 26–28).

## Risks

- A pushed command that is NOT equivalent silently corrupts the log's replay
  fidelity — that's why step 0 gates per-id and the dialog-suspect ids
  (attach_labels, make_sch_from_sel) default to "don't push" unless proven.
- `load_action_table` also runs for USER_CONF_DIR csv overrides? Check: if a
  user csv can override `command`, the pushed log command follows the user's
  csv — acceptable (their menus run the same command) but confirm the push
  happens after whichever csv wins.
- Registry de-consting: confirm nothing relied on the array being in rodata
  (it is file-static; only find_action_def touches it).
