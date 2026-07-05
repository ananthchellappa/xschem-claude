# Plan — widen net-highlight stripe-angle range from [0,45] to [-45,45]

**Date:** 2026-06-27  **Branch:** fluid-editing  **Spec:** doc/claude/specs/net_hilight_styles.md (§6, §5.1, column table — updated 2026-06-27)

## Why
The `stripe-angle-deg` style column was clamped to `[0,45]`, which only permits a tilt in **one**
direction — an oversight. Widen to `[-45,45]` so stripes can lean either way. `0` stays
perpendicular; sign picks the tilt direction; `|angle|` the amount. The render already shears by
`tan(angle)` (naturally signed), so the change is mostly clamp bounds + UI range + one render-coverage
fix + docs.

## Impact map (every site that bounds angle to 0..45)
- **Value acceptance** (BOTH needed end-to-end — the editor stores via Tcl, then the C side re-clamps on apply):
  - `src/xschem.tcl:535` — `net_hilight_style_norm` clamps `<0 → 0`.
  - `src/hilight.c:476-487` — C parse clamp `[0,45]` + warning text.
- **Render correctness** (the subtle one):
  - `src/draw.c:1541,1554` — `draw_hilight_wire_striped` uses **signed `shear`** for the coverage
    `cstart` and the band loop bound. That slack only covers a positive tilt; a negative shear leaves
    **triangular gaps at the wire ends**. Fix = `fabs(shear)` in those two bounds ONLY. The band-corner
    math (`pos ± shear`, draw.c:1559-1562) stays **signed** — that is what tilts the band.
  - `src/hilight.c:510,582` — two warnings gated on `angle > 0` (no-dash; non-cairo build) → `angle != 0`.
- **Editor UI:**
  - `src/xschem.tcl:923` — angle `scale -from 0 -to 45` → `-from -45 -to 45`.
  - `src/xschem.tcl:1121` — preview shear `angle > 0 ? … : 0` → `angle != 0 ? … : 0` (else negative renders flat).
- **Docs/comments:** spec (done 2026-06-27), `src/xschemrc:447`, `src/net_hilight_style_rc:16`,
  comments in `hilight.c:431`, `draw.c:1481-1491,1535`, `xschem.tcl:14428`.

## RED-first atomic steps
Each step: write/extend a failing test, make it pass with the minimal change, keep the rest of the
nh suite green. Commit per step (or in two commits: tests-green code, then docs).

1. **Spec + this plan** (no code). DONE.

2. **Tcl `net_hilight_style_norm` lower bound.**
   RED (new `tests/headless/test_nh_angle_range.tcl`, `--nogui`): `net_hilight_style_norm {0 4 1 {6 4} -30 0 none 0} 0`
   keeps angle `-30`; `… -50 …` → `-45`; `… 50 …` → `45`. (Pre-fix: `-30`→0, `-50`→0.)
   GREEN: `xschem.tcl:535` `elseif {$a < 0} {set a 0}` → `elseif {$a < -45} {set a -45}`.

3. **C parse clamp + `!=0` warnings.**
   RED (extend the test, GUI `DISPLAY=:0` — capture `hilight_style_warn` via a `ciw_echo` override):
   raw `set net_hilight_style {{0 4 1 {6 4} -30 0 none 0}}; xschem update_net_hilight_style` emits NO
   range warning; `-50` warns `out of range [-45,45], clamped to -45`. (Pre-fix: `-30` warns `[0,45]→0`.)
   GREEN: `hilight.c:476-487` (`ang < -45 || ang > 45`; `cl = ang < -45 ? -45 : 45`; message `[-45,45]`),
   `hilight.c:510` and `:582` (`angle > 0` → `angle != 0`), comment `:431`.

4. **C render: negative-shear coverage.**
   RED (PNG, GUI): render a thick (width≥8) striped wire at angle `-30` with `xschem print png` at a
   forced `net_hilight_test_now`; assert the highlight color reaches the wire's far-end region (the
   triangle a signed-slack bug would leave bare). Cross-check pixel-count(`-30`) == pixel-count(`+30`)
   (mirror symmetry; a gap makes `-30` fewer).
   GREEN: `draw.c:1541` `cstart` and `:1554` loop bound use `fabs(shear)`; update comments `:1481-1491,:1535`.

5. **Editor slider range + preview shear sign.**
   RED (GUI, extend `test_nh_editor_cells.tcl` or a new `test_nh_angle_editor.tcl`):
   `.nhse.tbl.sf.body.r0.c4 cget -from` == `-45`; focusing a row with angle `-30` makes `nhse_preview_paint`
   emit a `polygon` (sheared), not a flat `line`. (Pre-fix: `-from`==0; negative → flat line.)
   GREEN: `xschem.tcl:923` `-from -45`; `:1121` `$angle != 0`.

6. **Docs/config sync + acceptance.**
   Update `src/xschemrc:447`, `src/net_hilight_style_rc:16`, `xschem.tcl:14428` comment.
   Run the full nh suite (`test_nh_editor_*`, `test_nh_angle_range`) + core regression; update the
   `net-hilight-styles` memory; commit + push to `fluid-editing`.

## Test-design notes / gotchas (from the feature's history)
- GUI `--script` swallows stdout/stderr → write results to a file or use the suite's `check` harness.
- `net_hilight_style_norm` is pure Tcl → step 2 runs under `--nogui` (fast, no X).
- nh GUI tests MUST set `::USER_CONF_DIR` to a temp dir (opening the editor auto-writes the seen marker).
- Capture C warnings by overriding `ciw_echo` (the warning sink), not stdout.
- PNG determinism: warm up one `print png` (discards a 1-time init artifact), force time via
  `xschem net_hilight_test_now <ms>`; offset 0 frame must be byte-stable.
- The march/blink columns and the dash-period math are unaffected (sign of angle never enters them).
