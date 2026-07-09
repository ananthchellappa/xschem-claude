# Cadence stretch/move keyboard verbs (`cadence_compat=1`)

## Status
IMPLEMENTED. Branch `fluid-editing`. Written + built 2026-07-09. UNCOMMITTED.
Closes gap #2 of `doc/claude/FAQ.md` Q28.
Test: `tests/headless/test_cadence_stretch_move.tcl` — 13/13 PASS under X,
sabotage-verified (A1b flips when the connected net-grab is neutered; B1b flips when
`stretch_move` is forced 0). Pre-existing, unrelated: `test_cadence_drag.tcl` has 2
failures on this branch HEAD (nand2 detached-drag wire assertions) independent of this
change (confirmed by stashing the C edits).

One edit beyond the original plan was needed — the cadence deselect-others on release
(`callback.c:6310`) had to be guarded against an in-flight move; see Implementation §5.

## Motivation

With the Cadence profile loaded (`src/cadence_style_rc`, which sets `cadence_compat 1`
+ `fluid_editing 1`, leaves `enable_stretch 0`), the **mouse** already matches Virtuoso:

| Gesture | Effect | Site |
|---|---|---|
| plain LMB-drag | connected move — wires follow/reroute | `callback.c:6085-6088` |
| Ctrl+LMB-drag | detached move — wires left behind | `callback.c:6082-6083` |
| Shift+LMB-drag | copy | `callback.c:6081` |

But the **keyboard** verbs do not. `cadence_compat` never touches the `m`/`M` handlers
(`callback.c:4715-4802` contain no `cadence_compat` reference), so under the Cadence profile:

- plain `m` → **disconnected** move (because `enable_stretch=0`): the opposite of Virtuoso,
  where schematic `m` = Stretch.
- `Shift+M` → **kissing-connect** move (`connect_by_kissing=2`, `callback.c:4777`), not the
  rigid disconnected Move that Virtuoso `Shift+m` performs.

So a Cadence user pressing `m` for a connectivity-preserving move gets a disconnected one,
and has no keyboard verb that behaves like Virtuoso Stretch (they must reach for Ctrl+`m`,
which is undiscoverable and undocumented as such).

## Target behavior (applies ONLY when `cadence_compat=1`)

### `m` = STRETCH (connectivity-preserving)
- **noun-verb** (something already selected): immediately picks up the selection so it follows
  the cursor with **wires staying connected and rerouting** (fluid); the next Button1 click
  sets the destination and drops.
- **verb-noun** (nothing selected): prompt `"Stretch: click an object to move it (wires stay
  connected)"`; the next canvas click **selects** the object under the cursor **and** starts
  the connected move in one gesture; a further click drops.

### `Shift+M` = MOVE (rigid / disconnected)
- Exactly today's plain-`m`-under-cadence behavior: moves the selected objects only; attached
  wires stay put (connections break / dangle). No kissing, no attached-net grab.
- Same noun-verb / verb-noun duality, prompt `"Move: click an object to move it
  (disconnected)"`.

This makes the keyboard consistent with the mouse: keyboard `m` ≙ plain LMB-drag (connected),
keyboard `Shift+M` ≙ Ctrl+LMB-drag (disconnected).

### Non-goals / unchanged
- `cadence_compat=0` (default, non-Cadence): **zero change** — all new logic is gated behind
  `if(cadence_compat)`. Plain `m` stays `enable_stretch`-driven, `Shift+M` stays kissing.
- `Ctrl+m`, `Alt+m`, `Ctrl+M`: left as-is (under cadence they become partly redundant with the
  new plain `m`; harmless, may be simplified later).
- Copy (`c`), rotate/flip: out of scope. Connected rotate/flip is FAQ Q28 gap #1, a separate
  work item.

## "Connected" definition — reuse the cadence plain-drag path verbatim

The connected `m` must behave identically to the Cadence plain LMB drag so the two entry
points can never diverge:

```c
xctx->connect_by_kissing = 2;   /* armed BEFORE select_attached_nets (through-run tap skip, Q27) */
select_attached_nets();         /* grabs attached wires; sets stretch_select -> fluid reroute */
xctx->mx_double_save = xctx->mousex_snap;
xctx->my_double_save = xctx->mousey_snap;
move_objects(START,0,0,0);
```

Ordering is load-bearing: `connect_by_kissing` armed first so `select_attached_nets`'
`wire_through_tap_arm` predicate (see `doc/claude/specs/` wire-split note / FAQ Q27) can skip a
through-run arm and let a kiss stub replace it. `fluid_editing=1` then does the live reroute
because `select_attached_nets` sets `xctx->stretch_select` (`select.c:1589`).

**Decision — include kissing:** the connected `m` includes `connect_by_kissing=2` (create a new
wire when a moved pin lands on another wire/pin), matching the cadence drag exactly. Alternative
(pure reroute of existing nets, no new-connection kissing) is rejected for consistency with the
mouse; revisit only if users report unwanted auto-stubbing.

## "Disconnected" definition

```c
xctx->mx_double_save = xctx->mousex_snap;
xctx->my_double_save = xctx->mousey_snap;
move_objects(START,0,0,0);      /* no connect_by_kissing, no select_attached_nets */
```

## Implementation

### 1. New verb-noun sub-state bit — `src/xschem.h`
The verb-noun pickup path (`check_menu_start_commands`) must know whether a pending move is
connected or disconnected. Add a companion bit in the `ui_state2` block (`xschem.h:264-278`,
next free value after `MENUSTARTDESEL 4096U`):

```c
#define MENUSTARTSTRETCH 8192U  /* pending MENUSTARTMOVE is a connected stretch (cadence 'm') */
```

Invariant: `MENUSTARTSTRETCH` is only ever set **together with** `MENUSTARTMOVE`. So the existing
`MENUSTARTMOVE` membership in the readonly-backstop / auto-clear mask (`callback.c:2116-2122`)
and the `ui_state2 = 0` resets already cover it; no mask edit is strictly required, but adding
`MENUSTARTSTRETCH` to that mask for clarity is fine.

### 2. `case 'm'` (plain, `rstate==0`) — `src/callback.c:4720`
Inside the existing `if(rstate==0 && !(ui_state & (STARTMOVE|STARTCOPY)))` block, keep the
`waves_selected` early-out, then branch on cadence:

```c
if(waves_selected(...)) { waves_callback(...); break; }
if(readonly_block()) break;
if(cadence_compat) {
  /* Cadence 'm' = STRETCH (connected). */
  rebuild_selected_array();
  if(xctx->lastsel > 0) {                 /* noun-verb: pick up now */
    xctx->connect_by_kissing = 2;
    select_attached_nets();
    xctx->mx_double_save = xctx->mousex_snap;
    xctx->my_double_save = xctx->mousey_snap;
    move_objects(START,0,0,0);
  } else {                                /* verb-noun: arm connected pickup */
    xctx->ui_state |= MENUSTART;
    xctx->ui_state2 = MENUSTARTMOVE | MENUSTARTSTRETCH;
    statusmsg("Stretch: click an object to move it (wires stay connected)", 1);
  }
  break;                                  /* do NOT fall into the enable_stretch path */
}
/* ...existing non-cadence plain-m logic unchanged... */
```

### 3. `case 'M'` (`rstate==0`) — `src/callback.c:4775`
Prepend a cadence branch before the existing kissing logic:

```c
if((rstate == 0) && !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
  if(readonly_block()) break;
  if(cadence_compat) {
    /* Cadence Shift+M = MOVE (rigid / disconnected). */
    rebuild_selected_array();
    if(xctx->lastsel > 0) {
      xctx->mx_double_save = xctx->mousex_snap;
      xctx->my_double_save = xctx->mousey_snap;
      move_objects(START,0,0,0);          /* no kissing, no attached nets */
    } else {
      xctx->ui_state |= MENUSTART;
      xctx->ui_state2 = MENUSTARTMOVE;     /* plain (disconnected) verb-noun */
      statusmsg("Move: click an object to move it (disconnected)", 1);
    }
    break;
  }
  /* ...existing non-cadence kissing logic unchanged... */
}
```

### 4. Verb-noun pickup — `check_menu_start_commands`, `src/callback.c:2133`
The `MENUSTARTMOVE` branch selects the object under the click then starts the move. Make it
honor the stretch bit:

```c
else if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTMOVE)) {
  int stretch_move = (xctx->ui_state2 & MENUSTARTSTRETCH) ? 1 : 0;
  rebuild_selected_array();
  if(xctx->lastsel == 0) {
    select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
    rebuild_selected_array();
  }
  if(xctx->lastsel == 0) {                 /* clicked empty space: cancel cleanly */
    xctx->ui_state &= ~MENUSTART;
    xctx->ui_state2 = 0;
    return 1;
  }
  xctx->mx_double_save = xctx->mousex_snap;
  xctx->my_double_save = xctx->mousey_snap;
  if(stretch_move) {                        /* connected */
    xctx->connect_by_kissing = 2;
    select_attached_nets();
  }
  move_objects(START,0,0,0);
  return 1;
}
```

(The empty-click cancel guard is new; today the branch would call `move_objects(START)` on an
empty selection. Confirm current behavior and keep or add the guard as needed.)

### 5. Guard the cadence deselect-others on release — `src/callback.c:6310`
`cadence_compat` collapses a multi-selection to the clicked item on a no-drag Button1
release (`lastsel != 1 && state == Button1Mask && !mouse_moved`). A verb-noun `m` pickup
starts a *connected* move whose selection now includes the grabbed attached nets
(`lastsel > 1`), and the pickup click has no motion — so this collapse would fire and drop
the nets mid-gesture. Add an in-flight guard:

```c
else if(cadence_compat && xctx->lastsel != 1 && state == Button1Mask && !xctx->mouse_moved &&
        !(xctx->ui_state & (STARTMOVE | STARTCOPY))) {
```

(Not needed before this feature because the old cadence verb-noun `m` left `lastsel == 1`;
only the connected pickup makes it > 1. A drag already has `mouse_moved == 1`, so this
branch never fired for drags either way.)

## Edge cases

1. **Verb-noun click on empty canvas** → nothing selected → cancel the armed move, clear
   `MENUSTART`/`ui_state2` (guard above).
2. **`persistent_command=1`** (set by the Cadence profile): `callback.c:2094` only clears the
   `MENUSTART` bit when `persistent_command` is *false*, so under cadence the bit persists.
   Verify the stretch/move pickup consumes and clears `ui_state2` so a stale `MENUSTARTSTRETCH`
   never leaks into the next armed command. If move already relies on `move_objects(END)` to
   reset, confirm `ui_state2` is zeroed there or clear it explicitly at pickup.
3. **Read-only** schematic: `readonly_block()` guards at arm time; the `check_menu_start_commands`
   backstop (`callback.c:2116`) also refuses. Unchanged.
4. **Waveform/graph under cursor** on plain `m`: the `waves_selected` early-out must stay ahead
   of the cadence branch (measurement tooltip, `callback.c:4721`). `Shift+M` has no waves path
   today; leave as-is.
5. **`cadence_compat=0`**: none of the above executes; regression suite must show no diff.

## Testing (`tests/headless/`)

New `test_cadence_stretch_move.tcl`, patterned on `test_fluid_editing.tcl`. Fixture: an
instance with a wire attached to one pin and the other end anchored elsewhere. Drive the verbs
via `xschem callback` KeyPress events (keysym 109 `m`, 77 `M`) or the equivalent
`move_objects`/menustart path, then a Button1 click for pickup/destination. Assert on wire
endpoint coordinates and net connectivity (netlist or `xschem get`):

- **A. cadence on, noun-verb `m`**: pre-select wired instance → `m` → move → click. Wire stays
  connected to the pin at its new location (reroute), net name preserved.
- **B. cadence on, verb-noun `m`**: nothing selected → `m` → click instance → move → click.
  Same connected result as A.
- **C. cadence on, `Shift+M`**: wired instance → move → drop. Instance moved, wire endpoints
  unchanged → pin now disconnected (dangling), matching the old plain-`m` disconnected move.
- **D. cadence OFF (regression)**: plain `m` still disconnected; `Shift+M` still kissing —
  byte-identical to pre-change.
- **E. verb-noun `m` on empty canvas**: no crash, command cancels, selection empty.

Sabotage check (per `green-but-hollow`): temporarily invert the `stretch_move` flag and confirm
test A/B flip to disconnected — proves the assertion actually exercises the new path.

## Files touched
- `src/xschem.h` — `MENUSTARTSTRETCH 8192U` define.
- `src/callback.c` — `case 'm'` cadence branch, `case 'M'` cadence branch,
  `check_menu_start_commands` `MENUSTARTMOVE` stretch-aware pickup + empty-click cancel,
  and the `cadence_compat` deselect-others in-flight guard (§5).
- `tests/headless/test_cadence_stretch_move.tcl` — new (13 checks, X-gated, sabotage-verified).
- `doc/claude/FAQ.md` — Q28 gap #2 marked addressed.

## Follow-ups / not done
- Not valgrind-checked yet.
- Not registered in the regression `cases.txt`/`hcases` list (X-only test; run manually
  under a display, like `test_cadence_drag.tcl`).
- `Ctrl+m` / `Alt+m` / `Ctrl+M` under cadence are now partly redundant with plain `m`;
  left unchanged, may be simplified later.
