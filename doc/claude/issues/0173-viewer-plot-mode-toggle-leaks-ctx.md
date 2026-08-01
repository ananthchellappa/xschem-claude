# 0173 — Ctrl-Shift-4 (viewer plot-mode toggle from the schematic) left the xschem CONTEXT on the viewer window

**Status: FIXED and CLOSED** (2026-07-29). `src/wave_viewer.tcl`, commit `e990738c`.
Tests: `tests/headless/test_wave_modes.tcl` M9 + MG17, `tests/headless/test_ase_plot.tcl`
P6b + one P9 leg. Review gate: PROCEED.

**Eyeballed by the reporter on the original repro — *"That bug is fixed. Eyeball
test pass"*.** That verdict is not a formality here, it is the only thing that
could close this issue: two of the three symptoms are pixels (a window title, a
crosshair that tracks or does not) and the third is which window a click lands
in. No suite in this tree can see any of them. What the 27 new checks prove is
that the CONTEXT and the TITLE are right at the instant of the gesture, with the
FocusIn repair paths held off — the mechanism, not the appearance.

## Symptoms as reported

Launch `src/xschem --script sky130A/cadence_style_rc --logdir /tmp`, open
`sky130A/.../tb_bandgap/schematic/tb_bandgap.sch`, open its `ngspice_state1`
state so a waveform viewer comes up (status bar `multi`, title
`Waveforms tb_bandgap (ngspice_state1)`). Then, **in the schematic window**,
press **Ctrl-Shift-4**:

1. The schematic window appears to **lose focus**.
2. The viewer's title becomes **`xschem [5] - untitled.sch (read-only)`**.
   Hovering the pointer over the viewer restores the correct title.
3. The **next click in the schematic selects a plot in the VIEWER**. Clicking
   away to another window and back restores normal behaviour.

The mode itself toggled correctly. This was never about the mode.

## One root cause, all three symptoms

`wviewer::status_refresh` read the snapped sample through `wviewer::in_ctx`,
and `in_ctx` was a **one-way** context switch:

```tcl
proc wviewer::in_ctx {token script} {          ;# BEFORE
  variable windows
  if {![dict exists $windows $token]} { return }
  xschem new_schematic switch [dict get $windows $token win_path]
  uplevel #0 $script
}
```

The chord path:

```
bind .drw <Control-Key-dollar>   src/cadence_style_rc:232   (the form that FIRES;
bind .drw <Control-Shift-Key-4>  src/cadence_style_rc:233    Shift-4 = `dollar` on US)
  -> ase::plot_mode_for_current invert          src/ase.tcl:925
     -> wviewer::set_plot_mode                  src/wave_viewer.tcl (item 10 PUSH)
        -> wviewer::status_refresh
           -> wviewer::in_ctx $token {xschem get graph_snap}
              -> xschem new_schematic switch <viewer .xN.drw>   ... and stayed there
```

### Why the title changed (symptom 2)

The C `switch_window()` (`src/xinit.c:1784`, always entered with `tcl_ctx == 1`
from Tcl — `scheduler.c:7709-7730`) ends in `set_modify(-1)`, and `set_modify`'s
`mod == -1` arm exists *only* to rewrite the window title
(`src/actions.c:241-266`):

```c
tclvareval("wm title ", top_path, " \"xschem", wn,
           " - [file tail [xschem get schname]]", ro, "\"", NULL);
```

The viewer's buffer genuinely IS a nameless read-only untitled schematic, so it
gets `xschem [N] - untitled.sch (read-only)` — verbatim what was reported. The
viewer's only repair is `bind $top <FocusIn> "+wviewer::retitle $token"`
(`wave_viewer.tcl:687`), which is exactly why **hovering fixed it**.

That title rewrite is `has_x`-gated, so it is **DISPLAY-arm-only** as a test
assertion (landmine 41's discipline).

### Why the click went to the viewer (symptom 3)

The current context was still the viewer's, so the next event dispatched through
`callback()` ran against the wrong `xctx`.

### Why the schematic seemed to lose focus (symptom 1) — MEASURED, and it is the SAME defect

**There is no `focus`, `raise`, `wm deiconify` or `raise_dialog` anywhere in the
Ctrl-Shift-4 chain.** Every reachable proc was read end to end: the bind,
`ase::plot_mode_for_current`, `ase::session_for_current`, `wviewer::plot_mode`,
`set_plot_mode`, `status_refresh`, `in_ctx`, the C `switch_window`, and its
`save_ctx` / `restore_ctx` / `housekeeping_ctx` / `reconfigure_layers_button` /
`set_modify(-1)` / `note_drw_front` tail. Not one moves Tk focus.

What the user saw was **the schematic canvas going inert**, which is
indistinguishable from lost focus:

- **Motion is dropped outright.** `handle_motion_notify` (`callback.c:5083-5093`)
  early-returns when the event's `win_path != xctx->current_win_path` and both
  sides are real windows. With `draw_crosshair 1` and `snap_cursor 1`
  (`cadence_style_rc:37,58`) the crosshair and snap cursor **freeze mid-canvas**,
  and hover outline / fly-lines die.
- **The status bar stops being written.** `update_statusbar()`
  (`callback.c:7805`, writes at `:7845-7868`) addresses
  `xctx->top_path.statusbar.*`, so every slot went to the viewer's statusbar —
  which `wviewer::open` has `pack forget`-ten. The schematic's statusbar froze at
  its last values.
- **Keys stopped doing anything.** `callback()` dispatches on the global `xctx`
  (`callback.c:8106-8110`), and `handle_window_switching` does not switch on
  KeyPress/ButtonPress (`callback.c:7903-7904`). The viewer buffer is
  `readonly 1`, so `begin_edit()` refused every edit (`actions.c:154-160`).

And the **recovery shape matches the report exactly**: with
`mouse_follows_focus` defaulting to 1 (`xschem.tcl:15365`),
`handle_window_switching` ignores FocusIn and only switches on **EnterNotify**
(`callback.c:7945-7951`) — so merely re-focusing does nothing; the pointer must
*leave and re-enter* the canvas. "Click away to another window and back" is that
re-enter.

Collateral from the same switch, worth knowing because the restore also undoes
it: `switch_window` calls `reconfigure_layers_button {}` with a literal empty
topwin (`xinit.c:1826`), recolouring the **root** window's Layers menu entry from
the viewer's `rectcolor`; and `housekeeping_ctx` writes a hardcoded
`.statusbar.7 configure -text $netlist_type` (`xschem.tcl:13674`), giving the
root window the viewer's netlist type.

## The fix

### D1 — both, in this order

**(a) `status_refresh` no longer switches at all.** It reads `graph_snap` only
when this viewer's context is *already* current:

```tcl
  set cur {}
  catch {set cur [xschem get current_win_path]}
  if {$cur ne {} && $cur eq [dict get $windows $token win_path]} {
    catch {set snap [xschem get graph_snap]}
  }
```

This is not a restriction, it is the correct test, and it loses **nothing**:

- `xschem get graph_snap` (`scheduler.c:3924-3934`) is a pure read of five
  `xctx` fields written by the C hover pump, and that pump **refuses to run for
  any window that is not the current context** (`callback.c:5083-5093`). The
  value is only ever fresh in the context that is already current.
- On the motion pump (`bind $wp <Motion> "+..."`, `wave_viewer.tcl:678`) the
  generic `<Motion>` C handler is in `keepseqs` and the `+` append runs **after**
  it, so the pump has already run in this context. The already-current test is
  the "pointer is here" test.
- On the schematic path the pointer has by definition *left* the viewer canvas,
  and LeaveNotify already calls `graph_snap_clear()` (`callback.c:8075-8083`) —
  so `graph_snap` was returning `""` there anyway. Measured before the fix: the
  status bar showed the plot mode and never a coordinate.

The MODE half needs no context: `wviewer::plot_mode` is a plain Tcl array read,
so the item-10 PUSH contract survives intact. Net effect: **the Ctrl-Shift-4 path
now performs zero context switches.**

**Measured on the fixed code** (live probe, viewer open as `.x1.drw`, schematic
`.drw` current, three identical rounds — so this is deterministic, not a lucky
sample):

```
t5 bare switch      -> reads: .x1.drw / .x1.drw / .x1.drw     (the one-way switch still is one)
t3 switch_ctx -> 1  ; after: .x1.drw                          (deliberate, unchanged)
t1 in_ctx saw {.x1.drw}; after: .drw                          (ran THERE, came back)
t4 in_ctx graph_snap -> {} ; after: .drw ; title={Waveforms test_nfet_final (ngspice_state1)}
t6 status_refresh          ; after: .drw ; title={Waveforms test_nfet_final (ngspice_state1)}
```

`t4` is the direct confirmation that D1(a) discards nothing: read from the
schematic side, `graph_snap` **is** `{}`.

**(b) `in_ctx` gains a verified save/restore + `retitle` regardless**, because
all five of its callers are refreshes and redraws.

### D2 — a refused restore is left refused

`wviewer::leave_ctx` verifies (landmine 17: `new_schematic switch` silently
no-ops while the current context's semaphore is raised — a restore that assumes
success is the same bug in reverse). On refusal it does **not** retry, loop, or
throw: every caller rides a keystroke or the motion pump, where a throw pops
Tk's `bgerror` modal. The refusal is counted in
`wviewer::ctx_restore_refused` for diagnosis.

### D3 — the restore re-asserts the VIEWER's title only

That is the window whose title `set_modify(-1)` corrupted. Switching **back**
also runs `set_modify(-1)`, but against the schematic's own buffer, which
produces the schematic's correct title — checked, nothing to repair on that
side.

### D4 — the fix is in `in_ctx`, not a new wrapper

Its name already promises "in that context", not "leave everything there". None
of its callers wants the context moved: `status_refresh` (which after this change
does not call it at all) and three `{xschem redraw}` wrappers —
`delete_all_markers`' repaint, `fit`'s tail, and the View-menu Redraw entry — plus the
`test_wave_grid.tcl:301` redraw leg.

### D5 — `readout_refresh` fixed here; the rest audited per site

`readout_refresh` genuinely *needs* the viewer's context (`xschem get
cursorN_x` and `interp_value`'s `xschem raw` reads are per-context), so unlike
`status_refresh` it cannot decline — it **borrows** via `enter_ctx`/`leave_ctx`
and gives the context back.

## The new seam

```tcl
wviewer::enter_ctx {token}          -> ticket {ok prev}
wviewer::leave_ctx {token ticket}   -> 1 restored / 0 refused
```

`prev` is `{}` whenever there is nothing to undo — either the viewer was already
current (so no switch happened and **no title was clobbered**) or the switch was
refused. That is what makes this bracket a no-op on every viewer-side caller:
"restore to where you found it" costs nothing when you were already there.

The family now reads:

| bracket | switches | verifies | restores ctx | re-asserts title |
|---|---|---|---|---|
| `switch_ctx` | yes | yes | no | no |
| `enter_ctx`/`leave_ctx` | yes | both ways | **yes** | **yes** |
| `with_edit` | via `switch_ctx` | yes | no (by design) | yes |
| `in_ctx` | via enter/leave | both ways | **yes** | **yes** |

## D5 audit — every `new_schematic switch` site, with a verdict

The distinction that decides each verdict: **0173 was a context move with no
corresponding window activation.** Every path that goes through
`wviewer::open` ends in `raise_activate_toplevel $top` + `focus $top`
(`wave_viewer.tcl:544` re-open arm, `:710` fresh arm) — on those paths the
leaked context and the visibly-active window AGREE, which is the Cadence
behaviour (plotting raises the viewer). That is `legitimate-terminal`, not a bug.

### Fixed in this change

| line | proc | verdict |
|---|---|---|
| `in_ctx` | `wviewer::in_ctx` | **LEAK — FIXED**: now enter/leave bracketed |
| `status_refresh` | `wviewer::status_refresh` | **LEAK — FIXED**: no longer switches at all (D1a) |
| `readout_refresh` | `wviewer::readout_refresh` | **LEAK — FIXED**: borrows and returns |

### Designed brackets — not sites to fix

| proc | verdict |
|---|---|
| `wviewer::switch_ctx` | **by design**: the verified one-way switch destructive callers gate on. Its `return 0` contract is what `with_edit` and the capture-then-mutate procs depend on. |
| `wviewer::leave_ctx` | the restore half itself |
| `wviewer::with_edit` | **legitimate-terminal**: rides `switch_ctx`, restores readonly + title but deliberately not the context. Its callers are viewer-side gestures that were already there, or plot paths that raise the viewer. |

### Viewer-gesture-side only — context is *supposed* to end up the viewer's

`viewport_rect`, the graph/trace hit-test helpers, `cursor_toggle`,
`graph_at_pointer`, `add_trace_dialog`, and the marker/strip drag seams. Every
one of them is reached from a binding on the viewer canvas `$wp` or from the
`WaveViewer` bindtag, and no viewer binding can fire on a schematic canvas
(verified: every viewer bind is on `$wp` or that bindtag, inserted only into the
viewer canvas's tags). **Verdict: legitimate-viewer-side.**

### Reachable from the schematic side, but terminal-by-design → follow-up, NOT fixed here

These all leave the context on the viewer *and* raise/focus the viewer in the
same gesture, so they do not reproduce 0173. Ranked by how much a future change
of that policy would matter:

| # | entry | chain | verdict |
|---|---|---|---|
| 1 | ASE-L **Netlist and Run** / `N&>` (`ase_window.tcl:463,545`) | `do_run` → `run_finished` → `after idle auto_plot_idle` → `auto_plot` → `wviewer::open`/`attach_raw`/`regenerate` | legitimate-terminal. Note `ase::netlist` (`ase.tcl:341-348`) *requires* the design current and `do_run` re-forces it (`:3520-3523`), so it self-heals where it matters. |
| 2 | **Ctrl-4** Direct Plot ESC (`cadence_style_rc:221`) | `sod_end` → `dp_finish` → `wviewer::open` → `attach_raw` → `regenerate` | legitimate-terminal (plot raises the viewer). Guarded by a new leg: the *arming* half must leave the context on the design. |
| 3 | **`~`** / Tools > Waveform Viewer (`ase_window.tcl:494,551`) | `open_viewer` → `wviewer::open` | legitimate-terminal |
| 4 | ASE-L **Run** / `>`, Results > **Direct Plot** | as 1 / 2 | legitimate-terminal |
| 5 | `E` hi_descend on an `ngspice_state` view (`xschem.tcl:5907`), Library Manager **Open** / **Open (read-only)** (`library_manager.tcl:118,136,137,183,184,199,200`), Session > **Load State**, fresh ASE-L construction | `ase::open_state` / `viewer_restore` → `wviewer::restore` → `regenerate` — all gated on the state carrying `viewer {open 1 ...}` | legitimate-terminal |
| 6 | CIW-typed `wviewer::…` with an explicit token (`ciw.tcl:247`) | → `regenerate` / `switch_ctx` | needs-followup, low value: with `{}` the token resolves through `current_token`, reads the schematic's context, and honestly refuses. |

**Verified negatives — do not re-hunt these.** The action registry cannot reach
either namespace (`actions.csv` / `keybindings.csv` / `mousebindings.csv` name no
`ase::` or `wviewer::` row, so `build_menu_from_table` and the command palette
are clean). No `.drw` bind outside `cadence_style_rc:221/232/233` reaches
`ase::`/`wviewer::`. `src/xschem.tcl` has no `~` button and no menu entry naming
`wviewer::`. `ase.tcl` touches `wviewer::` in exactly one proc
(`plot_mode_for_current`). Session > Save State, Outputs > Select On Design and
Session/WM Close perform no switch at all.

## Tests, and the hollowness they had to beat

`tests/headless/test_wave_modes.tcl` **MG10 was the green-but-hollow leg this
bug hid behind**: it already drove `ase::plot_mode_for_current invert` and
asserted the returned mode, and it never looked at the context or the title.

New legs:

- **M9** (headless, 3 checks) — the ticket shapes: an unknown token yields a
  refused ticket; a nothing-to-restore ticket makes `leave_ctx` a successful
  no-op; and that no-op does **not** retitle (a repair there would hide a real
  leak from MG17's spy).
- **MG17** (DISPLAY, 22 checks) — the chord from the schematic: context
  unchanged, viewer title unchanged, **`wviewer::retitle` never called**, mode
  really flipped, status bar pushed, exactly one log line. Then `in_ctx`,
  `readout_refresh`, a refused switch, and a refused restore.
- `test_ase_plot.tcl` **P6b** (4 checks) — the same borrow, in the suite that has
  **real raw data attached**, so `readout_refresh`'s per-context reads actually
  resolve. This is the leg that proves the borrow *handed the context over*, not
  merely that it put it back.
- `test_ase_plot.tcl` **P9** (1 check) — Ctrl-4 arming leaves the context on the
  design window.

**Two discipline points the legs encode:**

1. **No `update` between the toggle and the assertions**, and the omission is
   load-bearing. `bind $top <FocusIn> +wviewer::retitle` and the Tcl
   `switch_window` FocusIn handler both repair exactly this damage; an `update`
   would let a queued FocusIn run and the leg would pass on a *repaired* defect.
2. **The retitle spy and the title-string comparison are both required.**
   Sabotage (d) below proves it: with `in_ctx` restoring, reverting only
   `status_refresh` leaves the final title *correct*, so the string leg passes and
   only the spy catches it. Conversely, in full pre-0173 behaviour `retitle` is
   never called at all, so the spy passes and only the string catches it.

### Sabotage-verify (all run on the DISPLAY arm)

| sabotage | red legs | what it proves |
|---|---|---|
| (a) drop the restore in `leave_ctx` | **8** | the restore is what holds the context |
| (b) drop the `retitle` in `leave_ctx` | **4**, reporting `xschem [9] - untitled-1.sch (read-only)` | the title repair, and it reproduces the reported string |
| (c) make the restore unverified (assume the switch took) | **2** | landmine 17 in reverse is asserted, not assumed |
| (d) revert D1(a) only (`status_refresh` switches again) | **1** — the retitle spy | why the spy exists at all |
| (e) full pre-0173 behaviour | **11**, incl. `the chord LEFT THE CONTEXT ON THE SCHEMATIC -> {.x1.drw}` and the untitled title | the suite reproduces the user's bug |
| (f) **the real pre-fix `wave_viewer.tcl` from HEAD**, 10 consecutive runs | `test_ase_plot` P6b, **10/10, never once passing** | the strongest of the six: not a synthetic patch but the actual shipped code, and it reports the reported string verbatim — `{xschem [6] - untitled.sch (read-only)}` with the context left on `{.x1.drw}` |

## ⚠ `test_ase_plot` has a PRE-EXISTING WSLg gesture flake — do not read it as this change

The 10× DISPLAY soak of the two changed suites came back **18/20**. The single red
run was `test_ase_plot`, 8 legs, all cascading from the first:

```
FAIL: P8 first Direct Plot REAL ESC ended the mode -> {0} (exp {1})
```

Not this change, on three independent grounds:

1. **Mechanism.** That leg is the gate *before* `dp_finish`. `dp_gesture`
   (`test_ase_plot.tcl:241`) is a 200 × 50 ms loop doing `focus -force $cv` +
   a bare `event generate $cv <Key-Escape>`; returning 0 means the mode never
   ended, so `dp_finish` never ran, so **none of `in_ctx` / `readout_refresh` /
   `status_refresh` executed on that run**. The other 7 failures are
   "no viewer exists" fallout.
2. **Already recorded in-tree.** `doc/claude/ase_l_batch/receipts/17_dp-open-race.md`
   §3 has the verifier checking out the pre-item-17 baseline (`28dc858b`) and
   reproducing the same pattern, naming `P4 REAL ESC ended the mode -> {0}`
   explicitly: *"that P4/P6/ESC WSLg flakiness is PRE-EXISTING and NOT item 17's
   regression."* Same failure string, same family.
3. **Measured control.** 10 consecutive `test_ase_plot` runs on **HEAD's**
   `wave_viewer.tcl` (this change reverted, tests kept) produced one
   `NORESULT (exit 1 — binary never reported)` and one 6-failure run in the same
   P4 wire-click / ESC family — **2/10 runs with WSLg gesture trouble without this
   change at all**, versus 1/10 with it. The flake rate did not move.

A fourth data point arrived from the final verification pass: `test_ase_plot`
flaked once more, and the failure set was **byte-identical to the HEAD-code
control's** — the same six legs with the same values, starting at
`P4 the wire click highlighted net D -> {0}` and ending at
`P6 Direct-Plot graph untouched -> {i(v1)}`, with `p4hl={}`. The `sod_click`
landed on nothing, so only `i(v1)` was ever queued. **P6b passed in that run**,
i.e. the new legs hold up even in a flaked run. A re-run: 150/150.

Generalised: `test_ase_plot` drives real Tk gestures through WSLg, whose
synthetic-event delivery is asynchronous (`wslg-key-delivery-flakes`). Its
gesture legs flake at roughly 1-2 in 10 **and always have**. Judge it on whether
the failing leg is *upstream or downstream* of what you changed, and re-run before
attributing.

| suite | before | after |
|---|---|---|
| `test_wave_modes` DISPLAY | 385 | **410** |
| `test_wave_modes` `--nogui` | 134 | **137** |
| `test_ase_plot` DISPLAY | 145 | **150** |
| `test_ase_plot` `--nogui` | 30 | 30 (the new legs are DISPLAY-only) |

## See also

- `doc/claude/specs/waveform_viewer_modes.md` §9 — the Ctrl-Shift-4 contract
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 landmine 42 —
  the reusable half of this bug
- `doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md` —
  the other issue rooted in "the viewer buffer is an untitled schematic"
