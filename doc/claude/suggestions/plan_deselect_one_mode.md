# Plan — Deselect-one-at-a-time mode (bindable `d`)

Spec: `doc/claude/specs/deselect_one_mode.md`. RED-first.

## Phase 0 — RED scaffold
- Write `tests/headless/test_deselect_mode.tcl` with checks DM1–DM10.
- Run it; observe RED (no action id, no `DESEL_MODE` bit, old code present).

## Phase 1 — bit + entry/exit/click engine (C)
`src/xschem.h`
- Add `#define DESEL_MODE 4194304U /* bit 22 */`.
- Add prototype `void enter_deselect_mode(void);`.

`src/callback.c`
- After `unselect_at_mouse_pos()` add `enter_deselect_mode()` and
  `static void deselect_mode_click(int,int)` (preserve the bit; call
  `unselect_at_mouse_pos`).
- `abort_operation`: early `DESEL_MODE` exit (clear bit + statusbar, return,
  keep selection) — peer of the `NET_HILIGHT` statusbar clear.
- `handle_button_press`: after the `NET_HILIGHT/NET_UNHILIGHT` Button1 intercept,
  add `if(ui_state & DESEL_MODE){ deselect_mode_click(mx,my); return; }`.

## Phase 2 — register the action + default binding (C)
`src/callback.c`
- `act_deselect_mode` (→ `enter_deselect_mode`) in the act_* block.
- `action_registry[]`: `{ "edit.deselect_mode", act_deselect_mode, NULL, "Deselect one object at a time (click; ESC to end)" }`.
- `init_input_bindings`: `set_input_binding_idle(DEV_KEY,'d',0,ACTX_CANVAS,"edit.deselect_mode");`
  (append near the end so the regenerated CSV diff is minimal).

## Phase 3 — subcommand (C)
`src/scheduler.c` `xschem_cmds_d` (after `delete`): `deselect_mode` → `enter_deselect_mode()`.

## Phase 4 — remove old hardcoded `d` + dead `DESEL_CLICK` (C)
`src/callback.c`
- `case 'd'`: delete the `rstate==0` branch; keep the `ControlMask` delete_files branch.
- `check_menu_start_commands`: collapse the `DESEL_CLICK` if/else to just the
  `DESEL_AREA` (area) path.
- `handle_button_release`: remove `xctx->ui_state &= ~DESEL_CLICK;`.
`src/xschem.h`
- Remove `#define DESEL_CLICK`.

## Phase 5 — CSV metadata + regenerate
- `src/actions.csv`: add the `edit.deselect_mode` row (idle=1, nolog=1).
- Build, then regenerate `src/keybindings.csv` via
  `save_input_bindings_file src/keybindings.csv {key}` (drift guard).

## Phase 6 — GREEN + regressions
- `make` in `src/`.
- `test_deselect_mode.tcl` all GREEN (state + GUI behavioral under DISPLAY=:0).
- `tests/headless/test_bindings_file.tcl` (CSV drift) GREEN.
- `tests/headless/test_keybind_snap_grid.tcl` (KB4 greps for `case 'g'` — make
  sure nothing collateral), engine `tests/headless/run.sh` 6/6.

## Phase 7 — docs / memory
- Update memory; cross-link `[[action-registry]]`, `[[pin-selection]]`.
- FAQ note for the rebindable `d` (optional).
