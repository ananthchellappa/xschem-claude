# Menu inventory — draft action table

Extracted from `src/xschem.tcl` (`build_widgets`, lines ~10167–10871) by
`extract_menu.py`, a brace/bracket/quote-aware Tcl scanner (menu items are
multi-line statements with `-command {...}` bodies and `\` continuations, so
grep is insufficient).

## Artifacts

| File | Contents |
|---|---|
| `menu_items.csv` | one row per item: `menu,type,label,accel,var,command,line` |
| `menu_items.md` | the same, grouped by menu as readable tables |
| `extract_menu.py` | re-run: `python3 extract_menu.py ../../src/xschem.tcl .` |

## Totals

- **242 items** across **22 menus** — `command=160, checkbutton=46,
  radiobutton=15, cascade=21`.
- Excluding the 21 cascades (submenu holders), **221 real action items** — the
  number the refactor targets.
- **127 / 221** carry an `-accelerator` label (decorative; the real key handling
  is in `callback.c` + `key_binding`, which is the desync the action table fixes).
- **61** are toggles (check/radio bound to a `-variable`).

Largest menus: `edit` (23), `option` (22), `tools` (21), `simulation` (21),
`file` (21), `hilight` (18), `view` (17), `sym` (17).

## How cleanly each item maps to a future action registry

| Command shape | Count | Migration effort |
|---|---|---|
| direct single `xschem <subcmd>` (e.g. `xschem netlist -erc`) | 114 | trivial — drop straight into the table |
| single Tcl proc call (e.g. `simulate_from_button`) | 40 | trivial |
| inline multi-statement script (`if {...} {...} else {...}`) | 43 | **extract to a named proc first**, then reference it |
| empty (`-variable`-only toggle, or command bound elsewhere) | 24 | wire via the toggle/variable field |

So **~70% (154/221) are already clean one-liners** that map directly. The work
that matters is the **43 inline scripts**: lifting each into a named proc is the
right first cleanup, because it (a) gives every action a stable, testable name,
(b) shrinks `build_widgets`, and (c) makes the action table pure data.

## Recommended use

1. Treat `menu_items.csv` as the seed of `actions.tcl` — add an `id` column and a
   `help` column.
2. For the 43 inline-script rows, file a small task to extract each into a proc;
   replace the `command` field with the proc name.
3. Generate the menu, accelerator labels, and the "Show Keybindings" list from
   this table (see `../ui_refactor_first_move.txt`).

## Caveat

Covers the static menu built in `build_widgets`. Dynamically-built/context menus
(`context_menu`, `tab_context_menu`, `setup_recent_menu`, `reconfigure_layers_menu`)
add items at runtime and are **not** included — they should be folded into the
same registry in a later pass.
