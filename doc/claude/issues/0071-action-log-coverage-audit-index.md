# Issue 0071 — action-log / CIW coverage audit: index and structural root cause

**Opened:** 2026-07-02
**Status:** OPEN — umbrella / tracking issue for the 2026-07-02 coverage audit.
**Severity:** N/A (index). Individual gaps carry their own severity.
**Branch:** `fluid-editing`.
**Source:** user-requested full audit of unlogged user interactions.
**Related:** [[action-logging]], [[ciw-feedback-channels]], spec
`doc/claude/specs/action_logging.md` + `action_logging_checklist.md`. Global
design write-up (problem + solution + Virtuoso parity):
`doc/claude/code_analysis/action_log_ciw_coverage_and_virtuoso_parity.md`.

---

## 1. Why this exists

A full audit of "which user interactions are NOT logged into the CIW / action
log" found that logging was deliberately installed at four **GUI edges** —
the File menu (`menu_action_logged`), bound-key `dispatch_input_action`
(Layer A), drag-gesture ENDs (Layer C), and the right-click context menu (Layer
B). Any interaction that reaches a mutating command through a **different** path
records nothing, because the C subcommands themselves are almost all silent (only
`create_instance`, `saveas`, `load`, `load_new_window`, `library_manager`, `exit`
self-log).

## 2. Structural root cause and the one-shot fix option

Because the mutating C subcommands do not self-log, coverage depends on wrapping
every entry point. The alternative that closes menus, toolbars, keys, and dialogs
**at once**: **make the mutating subcommands self-log in their C body**, guarded
against replay double-logging (the guard pattern is already established — e.g. the
slick property form logs from Tcl precisely because C `apply_instance_properties`
stays silent, and scheduler coordinate-form replay bypasses `new_*` so replays
never double-log). A self-log-at-core pass would need that guard generalized (a
"suppress logging during replay/programmatic call" flag) but would eliminate the
per-edge wrappers. Decision for the spec owner.

## 3. New issues filed by this audit

| # | Gap | Sev |
|---|---|---|
| 0061 | Non-File menubar items (Edit/View/Tools/Symbol/Highlight/Sim/Properties) not logged | HIGH |
| 0062 | Toolbar + recent-component bar buttons not logged | HIGH |
| 0063 | Property-edit dialogs (editprop.c) commit silently | HIGH |
| 0064 | Library Manager mutations (git/create/rename/delete/copy) not logged | MED |
| 0065 | Net-hilight-style editor commit not logged | LOW |
| 0066 | `xschem set` config/display + change-layer/header not logged | MED |
| 0067 | Raw Tk key/mouse binds bypass registry logger | MED |
| 0068 | Un-migrated legacy-`switch` keyboard edits not logged | MED |
| 0069 | Gesture drops recorded as non-replayable `#` markers | MED |
| 0070 | Command output/results not logged to CIW + file (user requirement) | HIGH |

## 4. Pre-existing related issues (not re-filed)

- **0003** — stdin REPL + TCP server command channels not logged.
- **0004** — TCP command server has no authentication (security, same channel).
- **0005** — replayable click-select / shape control-point need stable object
  referents (deferred by design).
- **0055** — Library Manager *locate* logged the bare command (FIXED).

## 4b. Implementation status (2026-07-02)

The self-log-at-core mechanism (D2) and the output stream (D1) are **built and
tested** as a first slice:

- **Plumbing** (`globals.c`/`util.c`/`util.h`/`scheduler.c`): `actionlog_cmd_logged`
  (core-self-log dedup), `actionlog_suppress_echo` (CIW-typed no-double-echo),
  `actionlog_suppress` (replay/bulk guard); `log_output()` + `xschem log_action
  -result|-error|-reset|-emitted|-suppressecho`.
- **Dedup wired** into every existing recorder so a self-logged command is written
  exactly once: `dispatch_input_action` (`callback.c`), `context_menu_action`
  (`callback.c`), `menu_action_logged` (`action_registry.tcl`), `ciw_exec`
  (`ciw.tcl`).
- **First mutators self-log at core:** `cut`, `delete`, `undo`, `redo`
  (`scheduler.c`). These are now recorded from **every** path — hand-written menu,
  toolbar, key, context menu — closing that slice of 0061/0062/0068.
- **Output (0070/D1):** CIW-typed and menu-pick results/errors now land in the file
  as `#=`/`#!` comments and in the CIW pane.
- **Test:** `tests/headless/test_selflog_output.tcl` (11 checks, in `full_audit.sh`).

**Next mutators to convert** (same one-line `log_action` + record-after-mutation
pattern): flip/rotate family, `trim_wires`/`break_wires`/`align`, `setprop`/
property-dialog commits (0063), `change_layer`/`change_elem_order` (0066), symbol
generators, then the toolbar/menu migration (0061/0062) becomes largely redundant
because the cores self-log.

## 5. Coverage that already works (for contrast)

File menu, bound-key registry actions, drag-gesture ENDs (wire/line/rect/arc/
polygon/move/copy/pan/zoom_box/place-symbol/place-text), context-menu picks,
`create_instance`, `saveas`, `load`/`load_new_window`, `exit`, and the Phase-3
mints (scroll/pan/snap/toggles/polygon).
