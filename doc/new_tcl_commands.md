# New `xschem` Tcl commands in this fork

This document lists the `xschem` Tcl subcommands that exist in this fork
(`fluid-editing`) but not in the upstream XSCHEM version it branched from. It is a
reference for anyone scripting, testing, or automating this build.

**What "command" means here.** XSCHEM exposes nearly all functionality through a single
Tcl command, `xschem`, whose first argument selects a subcommand (e.g. `xschem load`,
`xschem netlist`). This document inventories the new *subcommands*.

**Baseline / method.** The list is the set difference between the `xschem` subcommands
present in `src/scheduler.c` on this branch and those present at the fork point (upstream
commit `f276d0cf`). It was produced with the same extraction the build uses to generate
`src/xschem_subcommands.txt` (`grep 'strcmp(argv[1], "…")'`). At the time of writing:
**220 subcommands upstream → 295 here — 75 new, 0 removed.**

**Scope.** Only top-level subcommands (`xschem <name> …`) are listed. Not included: new
targets of existing subcommands (e.g. additional `xschem get <target>` / `xschem set
<target>` keys), new object selectors (`@id`, `#index`), and new standalone Tcl procedures
defined in the `*.tcl` GUI/helper files — all of which also grew.

---

## A. Stable object handles & object-query API (17)

Every drawable object now carries a session-stable integer `id`. These commands resolve,
enumerate, and convert between an object's array index and its stable id.

| Command | Purpose |
|---|---|
| `object <type> <selector>` | Resolve one object by `@<id>`, `#<index>` / `#<layer>,<index>`, or (for instances) name; returns `{type index layer id name}`. |
| `objects [-type T] [-selected] [-layer L]` | Enumerate objects as a list of the same descriptor dicts. |
| `selection` | Enumerate the current selection. |
| `wire_id` / `wire_index` | Convert a wire's array index ↔ stable id. |
| `instance_id` / `instance_index` | Same, for instances. |
| `text_id` / `text_index` | Same, for text. |
| `rect_id` / `rect_index` | Same, for rectangles. |
| `line_id` / `line_index` | Same, for lines. |
| `poly_id` / `poly_index` | Same, for polygons. |
| `arc_id` / `arc_index` | Same, for arcs. |

## B. Replayable / scriptable interaction (3)

| Command | Purpose |
|---|---|
| `select_at <x> <y> [add] [nodraw]` | Select the closest object at a schematic coordinate — the replayable form of a mouse click (`add` = shift-click augment). |
| `hover` | Return the descriptor dict of the object currently under the cursor. |
| `deselect_mode` | Toggle a persistent click-to-deselect-one interaction mode. |

## C. Action logging & input bindings (6)

| Command | Purpose |
|---|---|
| `log_action` | Emit a line into the replayable action log. |
| `set_action_log_cmd` | Set the command string an action logs. |
| `set_action_nolog` | Mark an action as not logged. |
| `bind` / `unbind` | Add or remove a key/mouse input binding. |
| `bindings` | List current input bindings as `{device code mods ctx action_id}` rows. |

## D. Net highlighting — styles, scope, animation, cross-window sync (21)

| Command | Purpose |
|---|---|
| `net` / `nets` / `net_members` | Query a net by a durable anchor (`@wire <id>` / `@inst <id> <pin>`) or by name; list nets / a net's members. |
| `hilight_buried` | Highlight the cue for a net buried in an instance's subtree. |
| `highlight_objects` / `highlight_scope` | Apply-scope overlay for highlighted nets. |
| `hilight_net_interactive` / `unhilight_net_interactive` | Interactive net highlight / clear. |
| `incr_hilight_color` / `decr_hilight_color` | Cycle the highlight color. |
| `update_net_hilight_style` | Apply a net-highlight style (color/width/dash/blink/march). |
| `redraw_hilight_region` | Redraw the highlighted region. |
| `toggle_draw_pixmap` | Toggle pixmap-backed drawing (used by highlight animation). |
| `net_hilight_anim_update_all` | Advance the highlight animation across windows. |
| `net_hilight_march_offset` | Set the marching-ants offset. |
| `net_hilight_dump_pixmap` | Dump the highlight pixmap (diagnostics/tests). |
| `net_hilight_relay_enable` | Enable cross-window highlight relay. |
| `net_hilight_sync_suspend` / `net_hilight_sync_resume` | Suspend / resume cross-window highlight sync. |
| `net_hilight_sync_force_headless` | Force a headless sync (tests). |
| `net_hilight_test_now` | Trigger a highlight test tick. |

## E. Library manager — OpenAccess Library / Cell / View (7)

| Command | Purpose |
|---|---|
| `library` / `libraries` | Query a library / list libraries. |
| `library_manager` | Open / drive the Library Manager. |
| `lib_cells` | List cells in a library. |
| `cell_views` | List views of a cell. |
| `cellview_path` | Resolve the datafile path for a `lib/cell/view`. |
| `get_inst_lcv` | Get the library/cell/view of an instance. |

## F. Pins, wire-stubs & pin-name text (8)

| Command | Purpose |
|---|---|
| `add_pin_stubs` | Add `lab_pin` wire stubs out of a symbol's pins. |
| `apply_pin_prop` | Apply a per-pin property. |
| `pin_stub_targets` | Report candidate pins for stubbing. |
| `pin_stub_geom` | Query/compute stub geometry. |
| `pin_stub_sizing` | Query/set stub sizing. |
| `pin_names` | List a symbol's pin names. |
| `check_pin_names` | Validate pin names. |
| `inst_name_text` | Manage the instance-name text view. |

## G. Windows & tabs (2)

| Command | Purpose |
|---|---|
| `activate_window` | Activate (raise/focus) a specific editor window. |
| `windows` | List open windows. |

## H. Backup & undo (2)

| Command | Purpose |
|---|---|
| `backup` | Write a backup of the current schematic. |
| `load_backup` | Load from a backup file. |

## I. Properties & instance placement (3)

| Command | Purpose |
|---|---|
| `apply_properties` | Apply edits from the per-field property form. |
| `create_instance [{lib cell view [instname]}]` | Arm a live instance-placement preview (click to drop); self-logs. |
| `recompute_inst_bbox [inst]` | Refresh an instance's bounding box after `setprop -fast` edits (no undo/redraw). |

## J. View & wiring toggles (6)

| Command | Purpose |
|---|---|
| `pan up\|down\|left\|right` or `pan dx dy` | Pan the view (the `dx dy` form is the replay of a drag-pan). |
| `scroll` | Scroll the view. |
| `snap half\|double` | Halve or double the mouse snap factor. |
| `toggle_orthogonal_wiring` | Toggle orthogonal (manhattan) wire drawing. |
| `toggle_stretch` | Toggle stretch (rubber-band) mode. |
| `toggle_show_netlist` | Toggle showing the netlist window when netlisting. |

---

## Notes

- For the authoritative argument syntax of any subcommand, see its documentation comment
  above the corresponding branch in `src/scheduler.c` (search for `strcmp(argv[1],
  "<name>")`).
- Comparing against the *latest* upstream (`origin/master`) rather than the fork point may
  show a few of these as also present upstream, if upstream added an equivalent
  independently since the fork.
- Regenerate this comparison with:

  ```sh
  git show <upstream-ref>:src/scheduler.c \
    | grep -oE 'strcmp\(argv\[1\], *"[A-Za-z0-9_]+"' \
    | sed -E 's/.*"([^"]+)"/\1/' | sort -u > /tmp/upstream_cmds.txt
  grep -horE 'strcmp\(argv\[1\], *"[A-Za-z0-9_]+"' src/scheduler.c \
    | sed -E 's/.*"([^"]+)"/\1/' | sort -u > /tmp/here_cmds.txt
  comm -13 /tmp/upstream_cmds.txt /tmp/here_cmds.txt
  ```
