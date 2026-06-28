# Data-driven snap / grid / highlight key actions; CTRL-G → toggle grid (user-bound)

Status: **implemented** (branch `fluid-editing`). Plan: `doc/claude/suggestions/plan_keybind_snap_grid_actions.md`.
Actions registered in `src/callback.c` (`view.snap_half`, `view.snap_double`,
`view.set_snap_value`, `hilight.send_to_waveform`, `view.toggle_draw_grid`); the `g`/`G`
snap defaults removed; dead `case 'g'`/`case '%'` deleted; `cadence_style_rc` binds CTRL-G →
grid (others commented); menu accelerators blanked. Tests: `tests/headless/test_keybind_snap_grid.tcl`.
Related: `src/callback.c` (action registry + `handle_key_press`), `src/action_registry.tcl`
(binding-file loader), `src/keybindings.csv` (shipped defaults), `src/cadence_style_rc`,
`src/xschem.tcl` (menus). FAQ background: `doc/claude/code_analysis/FAQ.md` Q17, Q1–Q4.

## 1. Goal

Every key→function mapping for the snap / grid / net-highlight operations must be
**data-driven and user-specified** — set from a Tcl command or a loadable script
(`xschem bind …` / `keybindings.csv` / an rc file), never hard-wired in a C `case` and **never
shipped as a built-in default**. Concretely:

- **No built-in default bindings.** All five operations — halve snap, double snap, set snap
  value, highlight-net-and-send-to-waveform, toggle grid — become **registered actions with
  NO default chord**. On a plain startup nothing in this family is bound. They stay reachable
  from the menus; every binding is the user's choice.
- **`cadence_style_rc` is where the user specifies them.** It carries an **active**
  `xschem bind key 103 ctrl canvas view.toggle_draw_grid` line — so under the user's config
  **CTRL-G toggles grid visibility** — plus **commented-out** examples for the other four
  (halve / double / set-snap / highlight) the user can enable by uncommenting.
- The dead hardcoded `case 'g'` and `case '%'` in `handle_key_press` are deleted, and the
  existing `g`/`G` snap **defaults** in `init_input_bindings()` are removed (no replacements).

Non-goal: introducing a way to register a brand-new *action* purely from Tcl. The action
*catalog* (the `ActionDef` table) stays in C — that is the function library. What must be
data-driven and user-specified is the *binding* (chord → action id), which the action registry
already makes so (`xschem bind`, `keybindings.csv`). See §6.

## 2. Mechanism recap (already in the tree)

Keys flow through `handle_key_press` (`callback.c`), which calls `dispatch_input_action()`
**first** (`callback.c:3601`) and returns early on a table match — so a table binding shadows
any hardcoded `case`. Bindings live in `input_bindings[]`, seeded by `init_input_bindings()`
and then overlaid at startup by `keybindings.csv` (share-dir first, `USER_CONF_DIR` wins —
`load_input_bindings`, `action_registry.tcl:232`); a user rc (`cadence_style_rc`) can also call
`xschem bind` directly. Each binding names an **action id** that must exist in the `ActionDef`
table (`callback.c:~2661`); an action is **C-backed** (`d->fn`) or **Tcl-backed** (`d->tcl`).
`xschem bind <device> <code> <mods> <ctx> <action_id> [idle]` sets a binding at runtime
(`action_cmd_bind`, `callback.c:3143`); for `key`, `<code>` is the **numeric X keysym**
(`g`=103, `G`=71, `%`=37, `s`=115), `<mods>` is `0|ctrl|alt|shift|super` joined by `+`.

## 3. Actions

| Action id | Backing | Behavior | Reached today by |
|---|---|---|---|
| `view.snap_half` | C `act_snap_half` (exists) | `view_snap_change(0)` | `g` |
| `view.snap_double` | C `act_snap_double` (exists) | `view_snap_change(1)` | `G` |
| `view.set_snap_value` | **NEW, Tcl** | `input_line "Enter snap value (float):" "xschem set cadsnap" $cadsnap` | hardcoded `Ctrl-g` |
| `hilight.send_to_waveform` | **NEW, C** `act_highlight_send_waveform` | the `case 'g'` `EQUAL_MODMASK` body (hilight net → Gaw/Bespice/graph), guarded `semaphore>=2` | hardcoded `Alt-g` |
| `view.toggle_draw_grid` | **NEW, Tcl** | `set draw_grid [expr {!$draw_grid}]; xschem redraw` | hardcoded `%` |

`view.set_snap_value` and `view.toggle_draw_grid` reuse the exact Tcl the menus already run
(`xschem.tcl:11491` and the "Draw grid" checkbutton `xschem.tcl:11341`), so no new C logic.
`hilight.send_to_waveform` is C because its body is non-trivial (sim-tool detection); it keeps
the `if(xctx->semaphore >= 2) return 0;` guard so it is correct under any binding (equivalently
it may be bound `idle`).

## 4. Default bindings: NONE

These five actions ship **unbound**. `init_input_bindings()` binds none of them:

- **removed:** the existing `key 103 0 canvas view.snap_half` and
  `key 71 0 canvas view.snap_double` defaults.
- **added:** nothing — not `Ctrl-G→grid`, not `%`, not snap, not highlight.

So on a plain startup (e.g. `minrc`, no `cadence_style_rc`) `xschem bindings dump` shows none
of the five. The **only** place a chord is attached is the user's config: `cadence_style_rc`
activates `CTRL-G → view.toggle_draw_grid` and comments the rest (§6).

`src/keybindings.csv` is regenerated from the live built-in table by `save_input_bindings_file`
(`action_registry.tcl:248`) so it stays in sync — it simply loses the two snap rows and gains
nothing. (User bindings live in the rc / a `USER_CONF_DIR` csv, not the shipped file.) The
binding-file smoke test diffs the shipped csv against the builtins.

## 5. Removals & menu fixups

- Delete `case 'g':` (whole) and `case '%':` from `handle_key_press` (`callback.c:3880`,
  `:4708`). Plain `g`/`G` were already migrated; the `Ctrl-g`/`Alt-g`/`%` logic now lives in
  actions.
- Menus keep all functions, but since nothing is bound by default their **static accelerator
  labels** must be blanked so they don't advertise a chord that isn't there:
  - "Half Snap Threshold" / "Double Snap Threshold" (`xschem.tcl:11346/11349`, accel `G` /
    `Shift-G`) → `-accelerator {}`.
  - "Draw grid" checkbutton (`xschem.tcl:11342`, accel `%`) → `-accelerator {}`.
- The cheat-sheet (`show_bindkeys`) is generated from the **live** table, so once
  `cadence_style_rc` binds `CTRL-G→grid` it shows up there automatically — no static label
  needed, and it never drifts.

## 6. cadence_style_rc — the user's bindings (one active, four commented)

Add a documented block. The grid line is **active**; the rest are templates:

```tcl
# --- snap / grid / highlight key actions ship UNBOUND; bind them here ----------
# Each operation is a registered action, also reachable from the menus. Map any
# action to any chord with `xschem bind key <keysym> <mods> canvas <action>`.
# Keysyms: g=103  G=71  %=37  s=115  (use `xev` for others); mods 0|ctrl|alt|shift|super.

# CTRL-G toggles grid visibility (active):
xschem bind key 103 ctrl canvas view.toggle_draw_grid

# Optional — uncomment to enable the others:
# xschem bind key 103 0   canvas view.snap_half              ;# halve snap    (old 'g')
# xschem bind key 71  0   canvas view.snap_double            ;# double snap   (old Shift-g)
# xschem bind key 103 alt canvas hilight.send_to_waveform idle ;# hilight→wave (old Alt-g)
# xschem bind key 115 alt canvas view.set_snap_value         ;# set-snap dialog (old Ctrl-g
#                                                            ;# is now grid; 115='s', pick any
#                                                            ;# unused chord)
# xschem bind key 37  0   canvas view.toggle_draw_grid       ;# also toggle grid with '%'
```

(Note the keysym-with-shift trap: Shift changes the produced keysym — Shift-g → `G`/71 — the
same gotcha as the `Ctrl-Shift-2` bindkey; the examples use the actual produced keysyms.)

## 7. Acceptance criteria

1. **Plain startup** (no `cadence_style_rc`, e.g. `minrc`): `xschem bindings dump` has NO row
   for `view.snap_half`, `view.snap_double`, `view.set_snap_value`, `hilight.send_to_waveform`,
   or `view.toggle_draw_grid`. Nothing in this family is bound.
2. After `xschem bind key 103 ctrl canvas view.toggle_draw_grid` (what `cadence_style_rc`
   does), firing **Ctrl-G** on the canvas flips the `draw_grid` Tcl var and redraws.
3. Every action is bindable from a Tcl command / loadable script: e.g.
   `xschem bind key 103 0 canvas view.snap_half` then firing **g** halves `cadsnap`;
   `xschem bind key 115 alt canvas view.set_snap_value` then **Alt-s** opens the snap dialog.
4. All five operations still reachable from their menu items.
5. `grep -nE "case '%'|case 'g'" src/callback.c` returns nothing in `handle_key_press`.
6. `src/keybindings.csv` regenerated (snap rows gone, nothing added); binding-file smoke test green.
7. Menu accelerator labels blanked (no stale `G`/`Shift-G`/`%` claims).
8. `cadence_style_rc` contains the **active** `view.toggle_draw_grid` Ctrl-G line plus the
   commented recipes for the other four.
