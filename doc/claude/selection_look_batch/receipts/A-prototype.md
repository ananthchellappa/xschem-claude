# Stage A receipt: `selection_style` prototype (classic | bright | halo, default halo)

Crew: stage-A implementer. Base: `e3c43487e`. Nothing is committed. The work is uncommitted
changes to six files in the working tree. Per PLAN.md, stage A must not be committed until the
user has looked at stage B.

## What the user should look at

All screenshots are in `/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selshot/A/`.

| file | what it shows |
|---|---|
| `composite_dark.png` | dark scheme. Columns: classic, bright, halo. Rows: M1 selected; M1 + wire + floating text; M1 + apply-scope outline |
| `composite_light.png` | the same grid on the light scheme |
| `composite_hilight_net.png` | the gate net highlighted (red), then M1 + wire + text selected over it. All three styles, both schemes |
| `composite_drag_fallback.png` | a held move rubber band, halo. Left: 300 selection entries (full halo). Right: 600 entries (the cheap fallback) |
| `colour_iter_dark_grid.png`, `colour_iter_dark_amber_vs_orange.png`, `colour_iter_light.png` | the colour and width candidates I rejected, next to the ones I chose |

The full-window shots behind the composites are in `final/` (`<style>_<scheme>_<case>.png`, plus
`base_<scheme>_<case>.png` from the unmodified binary). Comparison shots are in `erase3/` and
`canon/`. The amber-era first pass is in `v1_amber_superseded/`.

## What changed (files, symbols)

- **`src/xschem.h`**
  - `SEL_STYLE_CLASSIC/BRIGHT/HALO`.
  - The `SELP_*` pass bits. `SELP_CLASSIC` is exactly what upstream draws.
  - New `Xschem_ctx` fields: `gc_sel`, `gc_selhalo`, `sel_style`, `sel_halo_px`, `sel_erase_pad`, `sel_rgb[3]`.
  - Prototypes for every new symbol listed below.
- **`src/xinit.c`**
  - `create_gc` and `free_gc` own the two new GCs.
  - New `sel_style_sync()` resolves `selection_style` and `selection_halo_width` (0..20) and sets the GC line widths.
  - `build_colors` resolves `selection_color`:
    - empty means the theme default, orange `#ff8000` on dark and `#e05a00` on light;
    - a name that does not parse falls back to the default;
    - the non-unix branch now frees its `Tk_GetColor`.
  - `change_linewidth` re-syncs the GC widths.
  - `set_clip_mask` clips both new GCs.
- **`src/draw.c`**
  - `TILED_BY_COPY()` replaces the eight `(fix_broken_tiled_fill || !_unix) && gc == gctiled` sites. A styled erase always restores by pixmap copy.
  - `temp_gc_extra()` makes the THICK `drawtempline` widen the halo GC.
  - `MyXCopyAreaDouble` pads by `sel_erase_pad`.
  - `draw_string` now wraps `draw_string_cairo()`, which takes an explicit colour and a window/pixmap target.
  - New `sel_restore_box()`, `draw_temp_string_parts()` and `draw_temp_symbol_parts()`. The old `draw_temp_string` and `draw_temp_symbol` are wrappers that pass the classic parts, so classic callers are unchanged.
  - New `sel_footprint()` and `sel_fp_add()` record the union of the restores one styled erase makes.
  - `draw()` calls `sel_style_sync()`, so a style change takes effect on the next redraw.
- **`src/move.c`**
  - `draw_selection_impl` is split. `draw_sel_entry()` holds the old per-type body, gated by parts.
  - The own-colour helpers (`sel_own_hilight_color`, `sel_own_wire`, `sel_rect_out`, `sel_line_out`, `sel_own_flush`) re-stroke the object with the real primitives, on the window only.
  - `sel_styled_draw()` runs the passes in order: text-background restore, then halo band, then own colours, then pin marks, then glyphs.
  - `sel_styled_erase()` erases a superset of whatever `sel_styled_draw()` painted.
  - `SEL_FANCY_DRAG_MAX` (the drag threshold, see below).
  - `sel_style_eff()` returns classic when there is no X and no GCs, so `--nogui` is classic by construction.
  - `draw_sel_object(on, type, n, c, repair)`.
  - **`sel_collect()`** is factored out of `rebuild_selected_array()`, which now calls it. The order is unchanged.
  - **`sel_repair()`** handles one interactive select or deselect: it erases the object's footprint, then repaints the whole selection clipped to that footprint. The selection goes into a private array, so `xctx->sel_array` is never touched under a caller that may be iterating it.
- **`src/select.c`**
  - When the style is not classic, every select or deselect site routes through `draw_sel_object`. The `repair` argument is `!(fast & 1)`, i.e. the single interactive calls. `unselect_all` and the rubber-band loops pass 0.
  - `select_inside` and `select_touch` end with one full styled stroke, so a rubber band also ends canonical.
  - `select_pin` strokes its marker with `gc_sel`.
- **`src/xschem.tcl`**
  - New defaults: `set_ne selection_style halo`, `selection_color {}`, `selection_halo_width 3`.
  - New View menu cascade **Selection look** with the radio entries Classic, Bright and Halo. Each runs `xschem build_colors; xschem redraw`.
- No new C mirror of a Tcl variable is cached across calls. C reads the variables at `build_colors` and `draw` time (`sel_style_sync`), so there is no `MIRRORED IN TCL` pair to keep in sync.

## Decisions and why

1. **Classic is untouched code-path-wise.**
   - When the style is classic, every site takes its original branch.
   - `draw_temp_symbol` and `draw_temp_string` keep their signatures and pixels.
   - `compare_schematics` paints with `gc[PINLAYER]`, so it always gets classic shapes. The style applies only when the GC is `gc[SELLAYER]` or `gctiled`.
2. **Colour: orange, one hue in both themes.**
   - These were taken: white is the scope outline, yellow the hover dash, cyan/green/red the wires/symbols/pins.
   - I first shipped amber `#ffb000`. I measured it against the palette: amber is essentially hilight layer 21 (`#fdb200`) in *both* palettes. Inside a band it also separated the green symbol stroke less well than orange did (`colour_iter_dark_amber_vs_orange.png`).
   - Magenta collides with hilight layer 10. Blue is too dark on black.
   - On light, `#e05a00` keeps the `#229900` green core readable (`colour_iter_light.png`).
3. **Halo width 3.** At 2 the band read as an outline rather than a halo (`colour_iter_dark_grid.png`). The band is screen pixels, so it does not scale with zoom.
4. **Texts are glyphs in the selection colour, with no boxes (as ruled).**
   - Before each glyph pass, the text's bbox is restored from the pixmap. Without this, Cairo antialiasing thickens a glyph that is redrawn over itself, which happens on every hover and crosshair repair.
5. **The overlay is canonical, whatever the click order.** I found this by measurement, not by reasoning.
   - Before the fix, the halo picture depended on which object was clicked first: 89 px differed when case 2 was selected in another order. It also left a wrong band after deselecting one of two touching objects: 153 px. Bright did the same at 10 px.
   - The cause was that the newest object's band painted over the older object's pin square.
   - `sel_repair` restores the footprint and repaints the whole selection clipped to it. The result equals a full redraw.
   - **Second trap, found the same way:**
     - the primitives clip shapes to `xctx->area` and stroke the cut;
     - so making the area equal to the clip rectangle painted a false edge one pixel inside the footprint (the bright 10 px above);
     - the culling area is now wider than the X clip by more than the widest stroke.
6. **Drag fallback above 400 selection entries.**
   - A move or copy rubber band with more than 400 entries draws classic shapes and text boxes, in the selection colour. Measurements are below.
   - The static overlay never falls back.
   - A drag's entry count is fixed, so the look never switches mid-drag.

## Measurements (commands and results)

All display work was on my own Xvfb `:263` (1920x1080x24) with openbox. Every command was
prefixed `unset DISPLAY;`.
- Screenshots were taken with `tests/headless/lookshot.sh` and `LOOK_DISPLAY=:263`. The pose scripts are `selshot/A/pose.tcl` and `pose_drag.tcl`.
- Comparisons use `magick compare -metric AE` on the canvas crop `900x628+0+108`.

**Build:**
- `make -C src` shows only the six pre-existing const-qualifier warnings (actions.c, util.c, save.c, token.c×3), and the base build shows the same ones.
- I also compiled `draw.c`, `move.c`, `select.c` and `xinit.c` with `-std=c89 -pedantic -Wall -Wextra -Wdeclaration-after-statement`. After normalising line numbers, the warning set is identical to the base's for all four files. One new `-Wsign-compare`, on the wire `sel` ternary, was fixed with a cast.

**Classic is pixel-identical to upstream.**
- Method: my build against a pristine `e3c43487e` build in `~/gsl0`, same pose. This covers 6 shots: cases 1, 2, 3 on dark and light.
- Result: **AE = 0 on the whole window, all 6.**
- Non-vacuity: classic case 1 against an unselected canvas differs by 5873 px.

**Every incremental path ends equal to a full redraw.** Each row below is the canvas after the gesture, compared with the same pose plus `xschem redraw`. Results are for classic / bright / halo, on both schemes:

| case | gesture | AE |
|---|---|---|
| 2 | select M1, then the wire, then the text | 0 / 0 / 0 |
| R | the same set in another order | 0 / 0 / 0 |
| W | M1 + wire + text, then deselect the wire | **25** / 0 / 0 |
| B | rubber band around M1 + wire | 0 / 0 / 0 |
| BD | case 2, then a deselecting rubber band over the wire | 0 / 0 / 0 |
| 3 | M1 + apply-scope outline | 0 / 0 / 0 |
| N0 / N | highlighted net only; highlighted net + case 2 | 0 / 0 / 0 |

- Classic's 25 px in row W is **upstream's own artefact**: classic is byte-identical to base. I left it alone because classic must stay pixel-identical.
- Non-vacuity checks:
  - BD differs from case 2 (bright 336 px, halo 1002 px);
  - B differs from the unselected canvas (7165 px);
  - case 2 differs from unselected (classic 5160, bright 7080, halo 9302).

**Erase, drag and hover leave no residue.** Results for bright and halo, dark and light. The two hover rows (H, HH) were run on dark only:

| check | AE |
|---|---|
| E (select three objects, then `unselect_all`) against unselected | 0 |
| U (select, `move_objects` start + 3 steps, abort, `unselect_all`) against unselected | 0 |
| V (drag away and back to the anchor, held) against static case 2 | 0 (classic 0 too) |
| H (hover sweep across M1 and the text, then away, from world→screen-converted `<Motion>` events) against static M1 + text | 0 |
| HH (hover left on M1) against static M1 + text | 335 (the dashed hover outline: non-vacuity) |

**Detection record.**
- The order and deselect checks above were red on the first implementation: halo R 89 px, halo W 153 px; bright 10 px each on R, W and V.
- They went green only after `sel_repair` and the culling-area margin.
- So each check is known to detect its defect class.

**Drag timing.**
- Per-step cost is `move_objects step`, with a round trip (`winfo pointerxy .`) inside each step, so the X server's work is counted. Averaged over 30 steps.
- Set-up: a grid of nfet_01v8 instances, each with a gate wire. Entries = 2 × instances.
- Zooms: `full` = zoom_full over 1600 instances; `mid` ≈ 0.5 px/unit; `near` ≈ 1 px/unit.
- "fancy" is the full styled overlay; "fallback" is classic shapes in the selection colour. Bench script: `selshot/bench/bench.tcl`. Raw results: `fancy.txt`, `fancy_near.txt`, `fallback.txt`.

| zoom | entries | classic | bright fancy | halo fancy | halo fallback |
|---|---|---|---|---|---|
| full | 400 | 4.32 | 4.49 | 5.01 | 4.65 |
| full | 800 | 8.31 | 8.32 | 10.19 | 8.76 |
| full | 3200 | 2.78 | 2.96 | 9.91 | 2.71 |
| mid | 400 | 4.47 | 6.28 | 6.54 | 3.82 |
| mid | 800 | 8.33 | 12.21 | 12.65 | 7.71 |
| mid | 3200 | 3.88 | 8.82 | 10.85 | 3.97 |
| near | 400 | 1.98 | 2.86 | 3.20 | 2.04 |
| near | 3200 | 1.37 | 2.53 | 4.84 | 1.45 |

All figures are ms per step.
- Above 800 entries, the existing full-window-copy erase in `draw_selection_impl` takes over, which is why 3200 entries is cheaper than 800 for classic.
- Up to 400 entries, halo costs at most +2.7 ms per step over the fallback (mid zoom).
- At 800 entries the extra cost reaches +4.9 ms. At 3200 entries it reaches +7.2 ms (full zoom).
- So **`SEL_FANCY_DRAG_MAX` = 400**.
- Nothing exceeded a 16 ms frame on Xvfb.
- **Not measured: the user's real Windows X server over TCP.** It may be slower, which could argue for a lower threshold.

## Suites (check counts)

Run with `tests/headless/run_suites.sh`. The counted arm was `AUDIT_DISPLAY=:263 … --nogui`; the
display arm was `AUDIT_DISPLAY=:263 …`. Bare-word results mean the suite printed no count.

Display arm, all PASS:

| suite | result |
|---|---|
| `test_hover_highlight` | ALL PASS |
| `test_hover_selection_repair` | ALL PASS |
| `test_grid_toggle_sel_gc` | 5 |
| `test_cadence_q_scope` | 29 |
| `test_drag_keeps_selection` | 14 |
| `test_dblclick_connected_grow` | ALL PASS |
| `test_verb_noun_copy_move` | ALL PASS |
| `test_fluid_editing` | 28 |
| `test_select_same_net_by_label` | ALL PASS |
| `test_perform_action_apply_pin_prop` | ALL PASS |
| `test_toggle_case` | 13 |
| `test_select_inside_argc` | 8 |
| `test_wire_split` | sentinel |
| `test_label_ride` | 165 |
| `test_label_strand_oracle` | 32 |
| `test_check_and_save` | 21 |
| `test_sch_add_pin` | 25 |
| `test_add_wire_label` | 223 |
| `test_crossview_paste` | sentinel |
| `test_pin_type_edit` | sentinel |
| `test_instance_update` | 95 |
| `test_select_log_1620` | 34 |
| `test_descend_log_absorb` | 23 |

Counted arm, all PASS:

| suite | result |
|---|---|
| `test_perform_action_apply_pin_prop` | ALL PASS |
| `test_placement_wire_gate` | 187 |
| `test_toggle_case` | 12 |
| `test_select_inside_argc` | 8 |
| `test_wire_split` | sentinel |
| `test_label_ride` | 165 |
| `test_label_strand_oracle` | 32 |
| `test_check_and_save` | 15 |
| `test_sch_add_pin` | 34 |
| `test_add_wire_label` | 234 |
| `test_crossview_paste` | sentinel |
| `test_paste_modify_flag_0244` | 444 |
| `test_pin_type_edit` | sentinel |
| `test_instance_update` | 95 |
| `test_select_log_1620` | 31 |
| `test_shape_draw_gate` | 421 |
| `test_descend_log_absorb` | 23 |

The counted arm matters here because `sel_collect` now sits under every `rebuild_selected_array`.

Not green, and **identical on the base binary** (same arm, same display, failure lines byte-identical):
- `test_select_at`: 5 FAILED, starting at `action log open`.
- `test_cadence_drag`: 2 FAILED, "leaves wires behind".
- On the display arm, `test_paste_modify_flag_0244` and `test_shape_draw_gate` TIME OUT (200 s). Both say they are pure headless and pass on the counted arm.
- On `--nogui`, `test_hover_highlight`, `test_hover_selection_repair`, `test_select_at` and `test_cadence_drag` give NORESULT.

Self-skipped and so measured nothing:
- `test_expose_repaint`, on both arms. It is the only suite that reads window pixels.
- `test_placement_wire_gate`, on the display arm.
- The display-only suites, on the counted arm.

I did not run T1, per the brief.

## Could not do, or chose not to

- **Not fenced by any suite.** Stage C owns that. The pixel comparisons above are the evidence, and the pose scripts in `selshot/A/` are the shape a stage-C row could take.
- **`test_grid_toggle_sel_gc` now probes a GC the default look no longer strokes with.** Halo and bright use `gc_sel`/`gc_selhalo`, not `gc[SELLAYER]`. The row still guards `gc[2]` (the grid and classic), but its stated reason ("the selection highlight renders dashed") covers only classic now. That is a stage C decision.
- **Known limits, declared and not fixed:**
  - Dashed own lines get a solid band.
  - Graph and image rects get a band, but no own-colour re-stroke.
  - A highlighted symbol with a custom RGB colour is re-stroked with the nearest layer colour while selected.
  - A non-cairo build falls back to text boxes, not glyphs.
  - Crosshair lines crossing a selected text's bbox are wiped until the crosshair next moves (the bbox is restored from the pixmap).
  - Custom-width (bus) lines in a halo drag: not specifically measured.
  - `selection_color` changes reach other open windows only at their next `build_colors`. The style itself is resolved per window at every `draw()`.
  - `sel_repair` collects the selection in O(objects) per *interactive* click. Batch callers skip it. I did not time it separately.
- **Harness finding (not my scope; reporting it):**
  - `run_suites.sh` with an explicit `AUDIT_DISPLAY=:<private n>` (the brief's recipe) **does not force `GUI_GATE=0`**.
  - My counted-arm run at 00:40:42 launched the shared GUI-gate panel (`gui_gate_widget.tcl`, pid 84346) **onto my private `:263`**, where nobody can see it. `~/.claude/gui_test_gate/events.log` records `panel launched pid=84346`, and `widget.pid` pointed at it.
  - It also photobombed one batch of my `lookshot.sh` shots, because `winshot -name xschem` matched the panel. I re-shot that batch with `GUI_GATE=0` and kept none of the bad shots.
  - I killed that exact pid, then my Xvfb (15515) and openbox (15521). No `wish`, `xschem`, Xvfb or openbox of mine is left.
  - The next gated run will relaunch the panel on its own display.
  - The user's screen was never touched: every process carried `DISPLAY=:263`.
- `~/gsl0` (a short-path clone of `e3c43487e`, built) is left in place for stage B and C comparisons.

## Decisions that are the USER's (described, not taken)

1. **Default selection colour.**
   - Prototype: orange `#ff8000` on dark, `#e05a00` on light.
   - The trade-off is in `composite_hilight_net.png`. Orange separates best from the green symbol strokes, but it sits next to the **red** first hilight colour: a selected wire on a red-highlighted net reads as a red core in an orange band, which is weaker contrast.
   - Amber reverses that trade-off and duplicates hilight layer 21.
   - `selection_color` overrides it either way.
2. **Halo width 3 px.** A different default is a one-word change.
3. **The large-drag fallback look** (`composite_drag_fallback.png`). Above 400 entries, a drag shows classic boxes in orange instead of the halo. The alternatives are a higher threshold (slower drags), or a lighter halo for big drags (a band but no own re-stroke), which I have not built.
4. **Menu placement and wording.** View → "Selection look" → Classic / Bright / Halo.
5. **Text styling inside a halo selection.** The texts become selection-coloured glyphs as ruled, so the attribute texts (`nf=1`, `1 x W_N / L_N`) lose their own colours while selected. The alternative is own-colour glyphs with a band, which I did not build. The look is in the composites.
