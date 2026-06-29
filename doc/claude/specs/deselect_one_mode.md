# Deselect-one-at-a-time mode (bindable `d`)

> **STATUS: IMPLEMENTED 2026-06-28** (branch `fluid-editing`, not yet committed —
> awaiting manual GUI confirmation). RED-first; `tests/headless/test_deselect_mode.tcl`
> 18/18 (state + GUI behavioral under `DISPLAY=:0`); also verified under the user's
> cadence config (infix off, cadence_compat, `en_pin_select 1` — DESEL_MODE wins over
> the pin-select hook). Regressions: engine 6/6, drift-guard + all binding/menu/palette
> smokes green (`test_remap` is the known WSLg `event generate` flake — passes 3/3 on
> retry and at clean HEAD).

## 1. Motivation

`d` is currently **hardcoded** in the giant `handle_key_press` switch in
`src/callback.c` (`case 'd'`). It should be:

1. **Pulled out** of the switch into the data-driven action registry, so the
   operation is a first-class *action* the user can rebind to any key via
   `xschem bind` / the keybinding CSVs (same mechanism as every other migrated
   key — see `doc/claude/specs/keybind_snap_grid_actions.md` and the
   action-registry phase notes).
2. **Refined** into a persistent *deselect-one-object-at-a-time mode* (today the
   `d` behavior is a single-shot deselect: arm, click once, done).

The default chord stays **`d`** — but now as a *binding row*, not a `case` label.

## 2. Behavior (the user's spec, verbatim intent)

> If there are objects selected, when the user presses `d`, XSCHEM goes into
> deselect mode. Clicking on a **selected** object deselects it. Clicking on an
> **unselected** object does nothing. Clicking on **empty space** does nothing.
> Pressing **ESC** exits the deselect-one-at-a-time mode.

Concretely:

- **Entry** (`d`, or `xschem deselect_mode`): if at least one object is selected,
  enter the mode (a persistent `ui_state` bit) and show a statusbar / CIW prompt.
  If **nothing is selected**, it is a no-op (with a short hint) — matching
  "*if there are objects selected*".
- **Each click while in the mode** acts on the object under the cursor and
  **stays in the mode**:
  - on a **selected** object → deselect just that object;
  - on an **unselected** object → nothing;
  - on **empty space** → nothing.
- **ESC** exits the mode and **keeps whatever is still selected** (it does *not*
  clear the remaining selection — the whole point of the mode is to *refine* a
  selection). This differs deliberately from the net-(un)highlight pick modes,
  whose ESC falls through to `unselect_all`.

### 2.1 Why the click rules already "just work"

The single deselect primitive `unselect_at_mouse_pos()` calls
`select_object(mousex, mousey, /*select_mode=*/0, ...)`. With `select_mode==0`:

- `find_closest_obj()` only returns an object when the cursor is inside its bbox
  / pick band (`find_closest_element` uses `POINTINSIDE`; `find_closest_box`
  uses a `CADWIREMINDIST` threshold band). **Empty space → `sel.type==0` →
  no-op.**
- `select_object(..., 0, ...)` **deselects** the hit object. On an
  **already-unselected** object this is a no-op (it never *selects*); it can
  never add to the selection. **Unselected → no-op. Selected → deselected.**

So the mode needs **zero new hit-testing/selection logic** — only (a) a
persistent mode bit, (b) a click intercept that calls the existing primitive and
preserves the bit, and (c) an ESC exit that keeps the selection.

## 3. Design

Template: the existing interactive **net-(un)highlight** pick mode
(`NET_HILIGHT` / `NET_UNHILIGHT`, `callback.c`), which is a persistent click-loop
ui_state mode entered by a command and exited by ESC. We mirror it.

### 3.1 New ui_state bit

`xschem.h`: `#define DESEL_MODE 4194304U /* bit 22: deselect-one-at-a-time mode */`
(next free bit after `NET_UNHILIGHT` bit 21).

### 3.2 Mode entry — shared by the bound key and the subcommand

`callback.c`:

```c
void enter_deselect_mode(void)   /* non-static; prototype in xschem.h */
{
  rebuild_selected_array();
  if(xctx->lastsel <= 0) { /* nothing selected: no-op + hint */ return; }
  xctx->ui_state |= DESEL_MODE;
  /* statusbar + CIW prompt (has_x-guarded) */
}
```

- C-backed action `act_deselect_mode` → `enter_deselect_mode()`.
- Registry row: `{ "edit.deselect_mode", act_deselect_mode, NULL, "Deselect one object at a time (click; ESC to end)" }`.
- Non-mutating ⇒ **not** in `action_id_mutates` ⇒ works in read-only views too
  (deselecting changes no schematic content).

### 3.3 Click handling — persistent

`callback.c` `handle_button_press`, placed right after the `NET_HILIGHT /
NET_UNHILIGHT` intercept (i.e. *before* pin-select / persistent-wire /
normal-select), so the mode owns plain Button1 clicks:

```c
if(xctx->ui_state & DESEL_MODE) { deselect_mode_click(mx, my); return; }
```

```c
static void deselect_mode_click(int mx, int my)
{
  unsigned int mode = xctx->ui_state & DESEL_MODE;  /* preserve across the click */
  unselect_at_mouse_pos(mx, my);                    /* select_object(...,0,...) */
  xctx->ui_state |= mode;
}
```

### 3.4 ESC exit — keep the selection

`callback.c` `abort_operation`, as an early peer of the `NET_HILIGHT` statusbar
clear, **returning** before the generic `unselect_all`:

```c
if(xctx->ui_state & DESEL_MODE) {
  xctx->ui_state &= ~DESEL_MODE;
  /* clear the persistent statusbar prompt (has_x-guarded) */
  return;                       /* keep whatever is still selected */
}
```

### 3.5 Default binding (the "REAL default")

The real default for a key lives in the **C built-in binding table**
(`init_input_bindings` in `callback.c`) **and** the shipped **`src/keybindings.csv`**
(replayed at startup; the two MUST agree — `tests/headless/test_bindings_file.tcl`
diffs the shipped CSV against a fresh `save_input_bindings_file`). The CSV row is
the file/remap path; `actions.csv` carries the *metadata* (label/help) for menus,
the palette and the cheat-sheet.

- `init_input_bindings`: `set_input_binding_idle(DEV_KEY, 'd', 0, ACTX_CANVAS, "edit.deselect_mode");`
  - **idle-gated** (`idle_only`): the mode is not entered while a modal dialog is
    up (`semaphore>=2`). (Old `d` had no semaphore guard; entering a transient
    mode behind a blocking dialog made no sense, so this is an intentional, minor
    tightening.)
  - **canvas-only** (no `over_graph` row): `d` never forwarded to the waveform
    graph, so a pointer over a graph still enters deselect mode on the canvas.
- `src/keybindings.csv`: `key,100,0,canvas,edit.deselect_mode,1` (regenerated, so
  order/format match the table).
- `src/actions.csv`: `edit.deselect_mode,command,edit,Deselect one object at a time,d,xschem deselect_mode,,,Deselect one object at a time (click a selected object; ESC to end),1,1`
  (`idle=1`, `nolog=1`: mode entry is a UI affordance and its effect — the
  deselect clicks — is not action-logged, like manual selection; so suppress the
  entry log too, same justification as the gesture-START rows).

### 3.6 `xschem deselect_mode` subcommand

`scheduler.c` `xschem_cmds_d` (after `delete`): calls `enter_deselect_mode()`.
Gives headless testability + the `actions.csv` `command` for log-replay equiv.

### 3.7 Remove the old hardcoded path + now-dead `DESEL_CLICK`

- Delete the `rstate == 0` (deselect) branch of `case 'd'` in `handle_key_press`;
  keep the `rstate == ControlMask` (`delete_files`) branch.
- `DESEL_CLICK` (bit 18) was set **only** by that deleted branch. With it gone,
  `DESEL_CLICK` is write-never, so remove the dead reads too:
  - the `if(xctx->ui_state & DESEL_CLICK)` branch in `check_menu_start_commands`
    (the surviving `else` is the `D` *area*-deselect path → `DESEL_AREA`, which is
    preserved);
  - the `xctx->ui_state &= ~DESEL_CLICK;` clear in `handle_button_release`;
  - the `#define DESEL_CLICK` macro.
  (`MENUSTARTDESEL` and `DESEL_AREA` stay — still used by `case 'D'`,
  area-deselect, which is out of scope and unchanged.)

## 4. Behavior changes (call-outs)

- `d` is now a **persistent mode** for *all* interfaces (infix and non-infix),
  replacing the old infix "immediate single deselect at cursor" and non-infix
  "single-shot click deselect". This is the unification the request asks for.
- `d` at `semaphore>=2` is now a no-op (was: armed the old single-shot mode).
- ESC in deselect mode keeps the remaining selection (new mode; no prior behavior
  to preserve).

## 5. Tests (RED-first) — `tests/headless/test_deselect_mode.tcl`

State checks (always; work under `--nogui` too):

- **DM1** `edit.deselect_mode` is a registered, bindable action id.
- **DM2** a plain startup binds `key 100 0 canvas → edit.deselect_mode` (idle).
- **DM3** with a selection, `xschem deselect_mode` sets the `DESEL_MODE` bit
  (`[xschem get ui_state] & 4194304`).
- **DM4** with no selection, `xschem deselect_mode` is a no-op (bit stays clear).
- **DM5** source migration: `callback.c` no longer mentions `DESEL_CLICK`, and the
  `edit.deselect_mode` id is present.
- **DM6** `keybindings.csv` has the `d` row; `actions.csv` has the
  `edit.deselect_mode` row.

Behavioral checks (only when a GUI/`DISPLAY` is present — driven via focus-
independent `xschem callback`; computes screen coords from `instance_bbox` and
`(world+origin)/zoom`):

- **DM7** two instances placed + `select_all` (`lastsel==2`); fire key `d` →
  `DESEL_MODE` set, `lastsel` unchanged.
- **DM8** click instance A's center → `lastsel==1`, `DESEL_MODE` **still set**
  (persistence).
- **DM9** click empty space → `lastsel==1` (no-op), mode still set.
- **DM10** fire ESC → `DESEL_MODE` cleared, `lastsel==1` (remaining selection
  **kept**).

## 6. Out of scope

- `case 'D'` (Shift+D) area-deselect — unchanged.
- `Ctrl+d` (`delete_files`) — unchanged (stays in `case 'd'`).
- Multi-window animation, undo of selection, etc.
