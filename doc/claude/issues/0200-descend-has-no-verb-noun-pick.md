# 0200 — descend has no verb-noun arm: `e` with nothing selected gives up instead of asking which instance

Status: **OPEN**. Filed 2026-08-01, from a user report. Confirmed by reading and by a
`--nogui` measurement; **not fixed**, no code changed.
Area: `src/xschem.tcl` (`hi_descend_target_inst` 5661, `hi_descend` 5919,
`hi_descend_dialog` 5964), `src/callback.c` (`case 'e'` 5812,
`check_menu_start_commands()` 3159), `src/xschem.h` (`ui_state2` sub-codes 264-295),
`src/findnet.c` (`find_closest_obj` 526), `src/scheduler.c` (the read-only probes 2453 /
5328 / 3533).
Tests: none yet.
Numbering: opened at 0200 (not 0188) deliberately — the `fluid-editing` agent owns the
0188-01xx range and this work must merge into it later.
Related: [0201](0201-no-command-suspend-resume-contract.md) (the resume half of the same
user story), [0202](0202-canvas-gesture-seize-has-no-stack.md) (the blocker that stops a
pick nesting inside an active pick mode),
[0203](0203-stale-sel_array-descends-a-deselected-instance.md) (the landmine any
"nothing is selected" test must dodge).
Specs: `doc/claude/specs/hi_descend.md`, `doc/claude/specs/rotate_keep_connected_stretch.md`,
`doc/claude/specs/cadence_stretch_move_keys.md`, `doc/claude/specs/deselect_one_mode.md`,
`doc/claude/specs/select_at.md`, `doc/claude/FAQ.md` Q14.

## Report

> Confirm that the "e" key to descend does not support verb-noun interface? Currently,
> user MUST first select an instance before pressing the "e" key to descend. So, we need
> to add verb-noun functionality.
>
> User must be able press "e" to execute the human-interface descend function, which will
> prompt her to pick an instance. When user picks an instance, the form will provide
> options to descend in a new tab, new window, etc.
>
> Importantly, choosing the instance to descend into in verb-noun mode is NOT the same as
> selecting an instance — which can modify the selection or select the instance. Here, we
> are just providing information to one command.

The resume half of that report (Ctrl-4, descend, continue the interrupted command) is
[0201](0201-no-command-suspend-resume-contract.md).

## Confirmed: there is no verb-noun arm anywhere in the chain

`e` does not reach C at all on a plain press. `set_bindings` installs a *more specific*
Tk binding on the canvas that pre-empts the generic `<KeyPress>`:

```tcl
# src/xschem.tcl:13962
if {$hi_descend_key ne {}} { bind $topwin <Key-$hi_descend_key> [hi_descend_keybind_script] }
# src/xschem.tcl:6061 — the script body
return {if {[expr {%s & 0x4c}]} {xschem callback %W %T %x %y %N 0 0 %s} else {hi_descend}; break}
```

so plain `e` → `hi_descend`; Ctrl/Alt/Super are forwarded verbatim to C. `src/callback.c:5812`
`case 'e'` still holds the old `descend_schematic(0, 1, 1, 1)` — unreachable from a canvas
keypress, still reachable from a scripted `xschem callback`.

Both Tcl entry points funnel through one resolver, and it has exactly two arms — an
explicit name, or a pre-existing selection:

```tcl
# src/xschem.tcl:5661
proc hi_descend_target_inst {inst} {
  if {$inst ne {}} { ... return $inst }
  set sel [xschem selected_set]
  if {[llength $sel] == 0} { ciw_echo "hi_descend: select an instance to descend into" error; return {} }
  return [lindex $sel 0]
}
```

`hi_descend` bails at 5943 before `hi_descend_do`; `hi_descend_dialog` bails at 5966
**before the toplevel is created** (5972) — the title, the view option-menu and the
iteration option-menu are all built from `instname`, so there is no dialog to open without
one. The C fallback bails too:

```c
/* src/actions.c:3521 */
rebuild_selected_array();
if(/* xctx->lastsel !=1 || */ xctx->sel_array[0].type!=ELEMENT) {
  dbg(1, "descend_schematic(): wrong selection\n");
  return 0;
}
```

Nothing in the chain arms a pick mode, records a pending verb, or waits for a click.

### Measured

`--nogui`, `src/xschem` built 2026-08-01 12:09, at `f166e592`:

```tcl
xschem load .../xschem_library/examples/0_examples_top.sch
xschem unselect_all
puts "selected_set=[xschem selected_set]"
puts "hi_descend bare: rc=[catch {hi_descend} r] res=$r currsch=[xschem get currsch]"
puts "target_inst: |[hi_descend_target_inst {}]|"
puts "descend: [xschem descend] currsch=[xschem get currsch]"
```

```
selected_set=
instances=147
hi_descend bare: rc=0 res=0 current=0_examples_top.sch currsch=0
target_inst: rc=0 res=||
descend with nothing selected: 0 currsch=0
```

147 instances on the canvas, and the verb declines to name any of them.

## Why this is a blocker, not a convenience

The motivating case is not "the user was lazy". During ASE Direct Plot
(`Ctrl-4` → `ase::direct_plot_for_current`, `src/cadence_style_rc:221`) the design canvas'
Button-1 is **seized**:

```tcl
# src/ase_window.tcl:1598-1602
bind $cv <ButtonPress-1>   "[list ase::ui::sod_click $key]; break"
bind $cv <ButtonRelease-1> {break}
bind $cv <Key-Escape>      "[list ase::ui::sod_end $key]; break"
```

Every Button-1 press queues a trace and `break`s before the generic
`<ButtonPress>` → `xschem callback` route. So while the mode is up **the user cannot
select an instance at all** — and `e` (not seized) reaches `hi_descend`, which then tells
her to select one. Descend is unreachable by construction. Verb-noun is the only door.

## Prior art in this repo — and where descend's pick must differ

Verb-noun is a ratified, shipped concept here (FAQ Q14; the four grammar flags
`intuitive_interface` / `infix_interface` / `persistent_command` / `cadence_compat`).
Three families already exist:

1. **One-shot arm, consumed at the next Button-1.** `MENUSTART` (`xschem.h:249`) plus a
   `ui_state2` sub-code, consumed by `check_menu_start_commands()` (`callback.c:3159`),
   cleared at release (`callback.c:7940`). `MENUSTARTMOVE` / `MENUSTARTCOPY` /
   `MENUSTARTSTRETCH` / `MENUSTARTROTATE` are exactly "a verb fired with an empty
   selection arms prompt-for-object".
2. **Persistent click loops.** `NET_HILIGHT` / `NET_UNHILIGHT` / `DESEL_MODE`
   (`xschem.h:254-256`), routed at `callback.c:7387/7396`, ESC exits.
3. **Tcl binding seize.** `ase::ui::select_on_design` (above), with verbatim restore in
   `sod_end` (`ase_window.tcl:1644`).

But every one of the family-1 arms **selects** the object it picks:

```c
/* src/callback.c:3204 — the MENUSTARTMOVE arm */
if(xctx->lastsel == 0) { select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL); rebuild_selected_array(); }
```

That is precisely what the user ruled out. So descend's pick is a **new fourth kind**:
resolve the object under the cursor, hand its identity to one command, leave `.sel` and
`sel_array` untouched.

The non-mutating primitive already exists in C —
`Selected find_closest_obj(double mx, double my, int override_lock)`
(`src/findnet.c:526`, declared `xschem.h:2199`), which writes nothing; `select_object()`
(`select.c:1599`) is merely its mutating wrapper, and `draw_hover` (`callback.c:2832`),
`draw_flylines` (`callback.c:2998`) and the double-click grow seed (`select.c:270`) are
existing read-only callers. What is missing is a **coordinate-addressed instance probe
reachable from Tcl**: `xschem closest_object` (`scheduler.c:2453`) takes no coordinates
(it reads the last mouse position), `xschem hover` (`scheduler.c:5328`) reports cached
hover state, `xschem flylines at x y` (`scheduler.c:3533`) is net-oriented, and
`xschem select_at` (`scheduler.c:10116`) is the *mutating* one.

## Decisions

### D1 — the pick must not touch the selection ✔ (user, explicit)
"Providing information to one command" ≠ selecting. Consequence: the
`MENUSTARTMOVE`/`MENUSTARTROTATE` arms cannot be copied verbatim; their
`select_object()` line is the whole difference.

### D2 — C `ui_state2` bit, or pure-Tcl binding seize? → **recommend C**, not decided
For C (a new `MENUSTARTDESCEND` sub-code): the status-bar prompt only survives if a C
`ui_state` mode bit is set — `update_statusbar()` blanks `.statusbar.10` on every event
when none is (`callback.c:8077-8093`), which is why ASE pays an 80 ms re-assert pump
(`ase_window.tcl:1550-1565`); ESC teardown is already routed (`abort_operation()`,
`callback.c:246`); the read-only backstop mask (`callback.c:3178`) is where a new mode
must be declared; and `xschem callback` makes it drivable in a DISPLAY-gated test the way
`test_verb_noun_copy_move.tcl` drives the others.
Against C: `callback.c` (12 touches) and `xschem.h` (20) are the two hottest files in
`fluid-editing`'s last 80 commits — merge-conflict risk is real. Mitigation: one new
`#define`, one arming site, one arm in `check_menu_start_commands()`, one line in the
read-only mask. Strictly additive, no rewrites of existing blocks.

### D3 — candidate feedback → reuse `draw_hover`, add no overlay
`draw_hover` (`callback.c:2817`) already outlines the object under the cursor read-only.
Anything new must repaint inside `draw_hover`'s erase block or it vanishes on the next
pointer motion (the issue-0011 class of bug).

### D4 — click on empty space → cancel the armed descend cleanly
Mirror `callback.c:3244-3252` (the armed-rotate cancel): clear `MENUSTART`, clear
`ui_state2`, return.

### D5 — noun-verb is unchanged
An instance already selected → today's path exactly, no pick step, no new prompt.

### D6 — the dialog cannot open from inside the click callback — OPEN
`hi_descend_dialog` is modal (`catch {grab $w}` + `tkwait window $w`,
`xschem.tcl:6039-6040`). Opening it from inside `callback()` pumps a nested event loop and
lands every subsequent event at `semaphore >= 2`, which gates hover, flylines, ESC-abort
and the chord dispatcher (`callback.c:2830 / 2991 / 6919 / 7325`). The pick arm should
therefore stash the picked instname and defer the dialog (`after idle`), not call it inline.

### D7 — whose selection gets clobbered downstream — OPEN
`hi_descend_current` (`xschem.tcl:5809`) and `hi_descend_newwin` (5836/5864) both do
`xschem unselect_all` + `xschem select instance $instname fast` to re-establish the
target. For `target=current` that is harmless (`descend_schematic` unselects anyway,
`actions.c:3665`). For `target=new_window` / `new_tab` the **parent context survives**, so
a verb-noun descend silently destroys whatever the user had selected there. Either
save/restore around the newwin arm, or thread the instance down without selecting.

### D8 — bussed instances keep the iteration menu
`hi_descend_iters` (5758) is name-driven; nothing changes.

## Direction (not decided)

1. `xschem instance_at <x> <y>` — a read-only `scheduler.c` probe over
   `find_closest_obj()`, returning the instance name (or `""`), selecting nothing. Gives
   the whole feature a headless-testable model layer.
2. `MENUSTARTDESCEND` in `xschem.h`, armed in the `hi_descend` path when the selection is
   empty, consumed in `check_menu_start_commands()` — the pick resolves the instance,
   clears the mode, and hands the name to Tcl.
3. `hi_descend_target_inst` grows a third arm: empty selection → arm the pick and return a
   sentinel that means *"not failed, ask again later"* rather than today's `{}` = error.
4. `hi_descend_dialog` is entered from the pick continuation with the instname already
   known — no change to its body.

## Tests (proposed leg IDs)

Headless (`--nogui`), the model layer: **VN1** `instance_at` hits an instance and returns
its name; **VN2** it selects nothing (`selected_set` empty, `lastsel` 0 before and after);
**VN3** empty space → `""`; **VN4** `hi_descend inst=<name>` still works unchanged.
DISPLAY-gated (`xschem callback`, self-skipping banner, the
`tests/headless/test_verb_noun_copy_move.tcl:41-48` coordinate idiom): **VN5** `e` with an
empty selection arms the mode (`ui_state` bit set) and does not descend; **VN6** the next
click descends into the clicked instance and leaves `selected_set` empty; **VN7** a click
on empty space cancels; **VN8** ESC cancels and restores the prior canvas state; **VN9**
`e` with an instance already selected takes the noun-verb path with no pick.
Every leg must be sabotage-verified (prove it can go red) per
`doc/claude/suggestions/green_but_hollow_tests.md`.

## What is NOT wrong here

- `hi_descend`'s view enumeration, the one-shot `hi_descend_view_path` override
  (`actions.c:3363`), and the destination arms all work; none of them needs to change.
- The `ngspice_state` → `ase::open_state` routing (`xschem.tcl:5899-5908`) is the only
  simulation-adjacent line in the whole `hi_descend` family and this work does not touch it.

## Cross-references

* `doc/claude/specs/hi_descend.md` — the shipped feature this extends (§2 claims "exactly
  one instance must be selected"; the code takes the first of several, `xschem.tcl:5669`).
* `doc/claude/specs/rotate_keep_connected_stretch.md` — `MENUSTARTROTATE`, the
  prompt-for-object precedent.
* `doc/claude/specs/deselect_one_mode.md` — the persistent pick-mode template (new bit,
  click intercept, ESC exit, `xschem <verb>` subcommand for headless testability).
* `doc/claude/specs/select_at.md` — the mutating coordinate pick, the thing this must not be.
* `doc/claude/FAQ.md` Q14 — "a unified command/point-entry kernel … is the single biggest gap".
