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

Status re-read from each child's own header, 2026-09-17 (`61af3692`). **Re-read them
rather than trusting this column** — it is a snapshot, and the umbrella is what people
read to pick work.

| # | Gap | Sev | Status at `61af3692` |
|---|---|---|---|
| 0061 | Non-File menubar items (Edit/View/Tools/Symbol/Highlight/Sim/Properties) not logged | HIGH | **OPEN** — largely fixed by successive C-core self-log passes |
| 0062 | Toolbar + recent-component bar buttons not logged | HIGH | **OPEN** — partially fixed (toolbar EditUndo/EditRedo/Cut/Delete) |
| 0063 | Property-edit dialogs (editprop.c) commit silently | HIGH | **✅ REPLAYABLE 2026-07-15 (atom 10)** — no longer marker-only |
| 0064 | Library Manager mutations (git/create/rename/delete/copy) not logged | MED | **FIXED 2026-07-14 (atom 7)** |
| 0065 | Net-hilight-style editor commit not logged | LOW | **FIXED 2026-07-14 (atom 8); residual CLOSED atom 15 — FULLY CLOSED** |
| 0066 | `xschem set` config/display + change-layer/header not logged | MED | **RESOLVED 2026-07-02** |
| 0067 | Raw Tk key/mouse binds bypass registry logger | MED | **RESOLVED 2026-07-02** |
| 0068 | Un-migrated legacy-`switch` keyboard edits not logged | MED | **FIXED** — sweep deliverable, commit `682e63ac` |
| 0069 | Gesture drops recorded as non-replayable `#` markers | MED | **OPEN** — paste/merge drop FIXED 2026-07-14 (atom 9) |
| 0070 | Command output/results not logged to CIW + file (user requirement) | HIGH | **PARTIALLY IMPLEMENTED** |

**Still open: 0061, 0062, 0069, 0070.** Six of the ten are done.

## 4. Pre-existing related issues (not re-filed)

- **0003** — stdin REPL + TCP server command channels not logged. **CLOSED 2026-07-14
  (atom 6)** — both channels record with the `ciw_exec` pattern.
- **0004** — TCP command server has no authentication (security, same channel). **OPEN.**
- **0005** — replayable click-select / shape control-point need stable object
  referents. **OPEN — DEFERRED by design.**
- **0055** — Library Manager *locate* logged the bare command. **FIXED.**

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
- **Test:** `tests/headless/test_selflog_output.tcl` (in `full_audit.sh`; **79 checks at
  `61af3692`** — it was 11 when this line was written).

**Next mutators to convert — FIVE OF SIX ARE DONE (re-measured 2026-09-17, `61af3692`).**
The conversion ran through the `perform_action` boundary: `run_core()` applies the
effect, `core_log_action()` is the single log site (per-verb arms for the pivot verbs,
a default `xschem %s` form for the rest). Landed: the **flip/rotate/flipv** family
(arg-carrying pivot arms, atoms 7-8); **`trim_wires` / `break_wires` / `align`**;
**`setprop` / property-dialog commits** (0063, atom 10); **`change_layer` /
`change_elem_order`** (0066); and the **symbol generators** (`make_symbol()` self-logs
at its core, covering menu, toolbar, script and the inline `a` key).
**Outstanding: only the toolbar/menu migration (0061/0062)** — and the prediction in the
original paragraph held, in that the cores self-logging is what made most of it
redundant.

## 5. Coverage that already works (for contrast)

File menu, bound-key registry actions, drag-gesture ENDs (wire/line/rect/arc/
polygon/move/copy/pan/zoom_box/place-symbol/place-text), context-menu picks,
`create_instance`, `saveas`, `load`/`load_new_window`, `exit`, and the Phase-3
mints (scroll/pan/snap/toggles/polygon).
