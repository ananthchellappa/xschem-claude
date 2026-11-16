# C verify: fences, registration and the small fixes (adversarial)

- **Date:** 2026-11-15
- **Verifies:** stage C, receipt `receipts/C-fences.md`, patch `receipts/C-combined.patch`
  (md5 `b36d19c97d5c15c2ae57a02463810edf`, checked before applying).
- **Trees:**
  - `~/gsv8` (15-character path): `e6b38ba83` + `C-combined.patch`, the two new suites
    intent-to-add. `git diff e6b38ba83 | md5sum` gives `b36d19c9…`, the patch's own md5.
    `./configure && make -C src`: the base's six `-Wdiscarded-qualifiers` warnings, no new one.
  - `~/gsv8s`: a copy of `~/gsv8` for the broken-on-purpose builds. Restored (all six edited
    sources `cmp`-identical to `~/gsv8`, `git diff` md5 `b36d19c9…` again), then deleted.
  - `~/gsv7c` (base `e6b38ba83`) and `~/gsv7` (A7, pre-C): binaries used read-only, with
    scripts and output in my scratch.
- **Displays:** Xvfb + openbox on `:330`, `:331`, `:332` only, started by me and killed by
  recorded pid after checking each cmdline (and each openbox's `DISPLAY`). Every xschem had
  an explicit `DISPLAY=:33x` under `env -u DISPLAY`, or no display. Every run had a throwaway
  HOME.

## Verdict

**SAFE WITH LIMITS.** I found no product defect in stage C. `window_snapshot` is memory-safe,
the `setprop text` fix is correct and changes nothing in Classic, Classic is pixel-identical
to base, and the registration delta re-derives exactly. The pixel suite is deterministic.

**The limit is HIGH, and it is about the fences, not the code.** The fences catch erase and
repair defects well. Four of my builds went red (V1a, V2, V3, V10), plus the half-fix V12.
But they do not fence the look the user approved. Seven of my broken builds change what the
user sees, by up to about 9000 px, and pass all three suites. Two of them bring back the
batch's own founding defects:
- the selection painted in the grid's grey again (V6);
- a box around every selected text, in Bright and in the default Bright with box (V7).

T1 would be green on either one. I recommend adding a few cheap rows before the commit (see
HIGH-1). Whether to commit without them is the driver's call.

## Findings

### HIGH-1: the look itself is unfenced (seven effective builds stay green)

Method: one edit per build to a pristine copy, `make -C src`, then plumbing (headless),
pixels and grid (`:331`). A separate probe (`eff_probe.tcl`) captured fixed poses from each
build. It compared them with the pristine build, to prove each edit changes the screen. The
probe had a FET, a `lab_pin` label, a wire and a floating text, posed with select-all, the
label alone, the text alone, a typed style, and a green `selection_color`.

| id | the edit | suites | it changes the screen (px vs pristine) |
|---|---|---|---|
| V6 | dark default selection colour `#ff8000` → `#4f4f4f`, the grid's grey (`build_colors()`) | **all green** | bright select-all 7220, brightbox 8471, halo 9377 |
| V7 | Bright and Bright with box paint a selected text as a **box**, not glyphs (`draw_temp_string_parts()`, glyph branch) | **all green** | bright select-all 8112, brightbox 7209, text alone 3405 |
| V8 | halo's band stroked with `gc_sel` (line width), so the own-colour re-stroke covers it (`sel_styled_draw()`) | **all green** | halo select-all 5202 |
| V16 | `selection_color` ignored, always the theme default | **all green** | green colour 8471 |
| V14 | Classic loses the box around a selected text (`draw_temp_string_parts()`, `SELP_TEXTBOX` when classic) | **all green** | classic select-all 2844, text alone 1058 |
| V1b | brightbox's box ignores `hover_inst_rect()`'s label case (always `xx1..yy2`) | **all green** | brightbox label 328 |
| V4 | `draw()` no longer calls `sel_style_sync()` | **all green** | a typed `set selection_style bright` + `xschem redraw` stays brightbox (1279 px) |

Why they pass:
- Every R row compares the window with a redraw, and a redraw paints the same wrong look.
- `B1`'s selection colour is read off the screen, then compared only with itself.
- `C1`–`C3` check Classic's colour and self-consistency, not its shapes.
- `B2` measures the box on the FET only.
- No row sets `selection_color`.
- Every look change goes through `build_colors`, which resolves the look by itself.

Suggested rows, each one or two checks on the existing fixture:
- **V6:** `selcol` (B1) equals the documented default (`#ff8000` dark) and differs from
  `$l2` (C1). The light scheme likewise, if it gets a pass.
- **V7:** in bright, the pixels a selection changes inside a floating text's region lie on
  that text's own glyphs (unselected capture). A box puts them on the background.
- **V8:** in halo, a selected wire changes pixels to the selection colour (the band). With
  V8 nothing changes.
- **V16:** set `selection_color #00ff00`, run `build_colors`, select: the top colour is `#00ff00`.
- **V1b:** run B2's comparison on `p1` as well as M1. The label is the one case where the
  hover geometry sharing matters.
- **V4:** `set ::selection_style bright; xschem redraw; look_now` is `bright`. That is FAQ
  Q94's own claim: "takes effect on the next redraw".
- **V14:** Classic with a floating text selected paints the four corners of its
  `text_bbox()`. Or say in the band C header that shapes are not fenced. The header
  currently says "a box per text", which no C row measures.

### MEDIUM-1: FAQ Q94's "takes effect on the next redraw" has no fence (V4 above)

The behaviour is right on this tree: the probe's pristine build reports `look=bright` after
a typed `set` and a plain `xschem redraw`. But nothing fails if `draw()`'s call goes away.
Plumbing `K1` covers `build_colors` and `change_linewidth` only. Listed separately because
it is a published user instruction.

### LOW

- **`window_snapshot pixels`: signed overflow.** `x1 = x0 + atoi(argv[6])` (and `y1`) can
  overflow `int`. `pixels 0 100 0 2147483647 1` returned an empty list (it wrapped). This is
  undefined behaviour in C, harmless in practice. A fix is to clamp `w`/`h` to the capture
  before adding, or to use `long`. `take { 1}` is also accepted, because `strtol` skips
  leading blanks. That is harmless.
- **Some R rows are weak, not vacuous.** r16–r20, r29 and r32 follow a command that itself
  ends in a full `draw()`, so they measure only that `draw()` plus its idle repair is
  idempotent. Under V10 (`take` reads the backing pixmap, which never holds the overlay),
  **all 164 R rows stayed green**. Only B1–B3, C1, H1×3 and O1 caught it, so the suite as
  a whole was red. An R-band leg that pixel-checks one known selection (for example r01
  against an unselected capture) would make the band self-sufficient.
- **Band C's header claims more than C1–C3 measure** ("grey strokes and a box per text").
  See V14.
- **`receipts/` hygiene, outside the patch.** `CREW_BRIEF.md` names a private path. (Driver:
  it is kept out of the commit.)

### INFO (pre-existing, not stage C)

- **`xschem setprop text` leaves residue on an UNSELECTED text at base too.** In
  `sp_residue.tcl`, base `e6b38ba83` Classic leaves residue on 25 of 70 unselected rows.
  Examples: a bold, centred text grown by a property edit leaves 170 px; a `font=Monospace`
  text sized up leaves 64 px. The counts are identical in every look on stage C. The GUI's
  Edit Properties ends in a full `draw()`, so only scripted edits show it.
- **V11** (halo's width left out of `sel_entry_fp()`'s pad) made no visible difference at
  band widths 3, 6, 12 or 20 on my fixture, with 0 residue after select-all, unselect-all
  and a partial deselect. Either the measured footprint already covers the band, or my
  fixture misses the case. I draw no conclusion.

## What I attacked

### 1. Fence strength: 13 builds broken on purpose, none of them the crew's K1–K15

| id | edit | red rows |
|---|---|---|
| V1a | box geometry from the symbol bbox including texts (`x1..y2`), not `hover_inst_rect()` | X 1: B2 |
| V1b | box ignores the label case of `hover_inst_rect()` | **none** (HIGH-1) |
| V2 | an instance deselect does not mark its footprint (`select_element()`) | X 16: r02 r11 r30 r40 in all four passes |
| V3 | menu values Bright ↔ Bright with box swapped | X 2: M1 M4 |
| V4 | `draw()` does not call `sel_style_sync()` | **none** |
| V6 | dark selection colour = grid grey | **none** |
| V7 | bright/brightbox text drawn as a box | **none** |
| V8 | halo band invisible | **none** |
| V10 | `take` captures the pixmap, not the window | X 8: B1 B2 B3 C1 H1×3 O1 (every R row green) |
| V11 | halo width out of the footprint pad | none, and no visible effect either (INFO) |
| V12 | `setprop text` without the OLD-footprint mark (A6's half; K12 removed the new one) | X 1: brightbox-w9 r24 |
| V14 | Classic without text boxes | **none** |
| V16 | `selection_color` ignored | **none** |

Baseline before and after: P `ALL PASS (28)`, X `ALL PASS (186)`, G `ALL PASS (10)`.

I found no vacuous comparisons of the other kinds the brief named:
- `take` refuses an unmapped window, and a failed `take` raises, which aborts the suite.
- `H0` guards `H1`/`H2` against an empty region.
- `B3` and `H1` carry `> 0` legs.
- The crew's K8 (H1 discriminates) and K12 hold.

### 2. `window_snapshot`

- **`--nogui`:** every subcommand, including `free`, is refused through
  `scheduler_needs_x_reject()` with one sentence, rc 1. No crash.
- **Bad arguments** (on `:332`): an empty call, an unknown subcommand, a missing slot,
  `-1`, `8`, `1x`, `{}` and `0x1` all give a clean error. So do diff/colors/pixels on empty
  slots, too few arguments, and captures of different sizes. A non-numeric
  `pixels 0 a b c d` gives an empty list. Negative `x`/`y` are clipped, and negative `w`/`h`
  give an empty list.
- **A window that cannot be read:**
  - partly off-screen (`900x700+1500+800`) and larger than the root (`2600x1500`):
    `XGetImage failed`, rc 1. The `BadMatch` is swallowed by xschem's own X error handler
    `err()`, so it does not abort.
  - iconified: `the window is not viewable`.
  - a second toplevel window as the current context: captured correctly.
- **valgrind** (`--leak-check=full`, `env` before `valgrind`): the whole probe, including
  200 take cycles over the 8 slots, then free, then 2 captures left at exit. **0 memory
  errors.** No loss record involves `XGetImage` or `win_snap_*`. The one definite leak is
  in libfontconfig. The "possibly lost" records under `xschem_cmds_w` are Tcl result
  objects, the usual Tcl-allocator pattern at an exit without `Tcl_Finalize`. Slots still
  filled at exit are reachable through the static array.
- **Size:** `colors` allocates `8·w·h` bytes, plus `16·n` for the counts. That is about
  16 MB at 1920×1080. Eight slots of a 4K window is about 265 MB. Acceptable for a test hook.
- **Recommendation: keep it in the product.** The styled overlay exists only on the window,
  so this is the only in-process way to read it. It reads only xschem's own window, writes
  no file, and its errors are clean. A script could already shell out to
  `import -window root`, so it adds no capability. Two optional changes: fix the `pixels`
  overflow, and list it with the other test hooks in the command reference.

### 3. The `setprop text` footprint fix

`sp_residue.tcl` ran on base, A7 and C. The fixture has 10 floating texts: rot 0/1/2/3,
flip, rot+flip, `font=Monospace`, bold centred, small (0.1) and a two-line rotated, flipped
text. Each text was edited seven ways: grow, shrink, back, size up, size down, a font
change through `allprops`, and restore. Each edit ran selected and unselected, in classic,
bright, brightbox w1, brightbox w9, halo and halo with `own` text. Each row is the window
against a redraw (`import` + `magick compare -metric AE`).
- **Classic: 140/140 rows identical to base, residue counts included.** The fix is gated on
  `sel_style_eff() != SEL_STYLE_CLASSIC`, and nothing in Classic changed.
- **No selection:** identical in every look, and equal to base Classic (the INFO above).
  The fix does not touch it.
- **Styled, selected, C against A7: 672 rows the same, 28 better (9361 px fewer), 0
  worse.** Every improvement is brightbox at width 9, across all the rotated, flipped,
  custom-font and multi-line texts. For example, `r2` grow goes 780 → 0, `r1f1` grow
  780 → 0, mono grow 614 → 0 and two-line grow 773 → 0. The few non-zero styled rows left
  are the same as A7, or are the base residue the unselected text shows too.

### 4. Registration (`derive.tcl`)

- **The lift:** all 16 top-level procs of `tests/run_regression.tcl`, lifted by discovery
  with `info complete`, not by name. `tests/banner_rule.tcl` sourced, and the three lists
  evaluated out of the file's own text. Base gives `tcases 3`, `hcases 137`, `dcases 60`,
  planned 201; C gives 3 / 138 / 62, **planned 204**.
- **The runs:** each case ran in its arm's exact T1 shape from `tests/`, with T1's timeout
  wrapper (`env -u DISPLAY … --nogui --pipe -q --script` for hcases;
  `--pipe -q --logdir <dir> --script` on `:331` for dcases). Each was scored with T1's
  HARNESS rule and the lifted `summarize_all`:

  | case | arm | rc | banner_complete | counted | skips | block lines | checks |
  |---|---|---|---|---|---|---|---|
  | `test_selection_look_plumbing` | hcases | 0 | 1 | 0 | 0 | 3 | 28 |
  | `test_selection_look_pixels` | dcases | 0 | 1 | 0 | 0 | 3 | 186 |
  | `test_grid_toggle_sel_gc` | dcases | 0 | 1 | 0 | 0 | 3 | 10 |
  | `test_op_annot` | hcases | 0 | 1 | 0 | 5 | 8 | 486 |
  | `test_op_annot` | dcases, `--logdir` | 0 | 1 | 0 | 0 | 3 | 494 |

- **Delta: `cases` +3, `blocks` +3, `counted_failures` +0, `skips` +0, `wc -l` +9, planned
  201 → 204.** This matches the crew on every term. `test_op_annot`'s blocks have the shape
  and check counts A7-verify measured at base (486 / 494, five `skip:` lines headless), so
  they move nothing.
- **Meta-fences, headless, `~/gsv8`:**
  - `test_registered_banner_1626` `ALL PASS (10)`;
  - `test_suite_watchdog_1403` `ALL PASS (40)`: W20h reads "all 60 of 157 registered cases
    that reach the event loop arm one". The pixel suite is in that population, since it
    issues `update` and `toplevel` and sources `scratch.tcl`;
  - `test_issue_stamp` `ALL PASS (102)`;
  - `test_home_isolation` `ALL PASS (120)`, which means G2 accepts the plumbing suite's child
    launcher.
- **`run_suites.sh` on `~/gsv8`:**
  - headless (`AUDIT_DISPLAY=none`): plumbing 28, op_annot 486 with its 5 skips, pixels and
    grid self-skipped;
  - `:330`: pixels 186, grid 10, op_annot 493, plumbing 28.

### 5. Determinism and runtime (pixel suite, T1's dcases shape, `:330`)

| run | result | wall |
|---|---|---|
| 5 clean runs | `ALL PASS (186)` each, verdict lines byte-identical across all five | 38.6, 39.0, 39.0, 39.0, 38.9 s |
| with a second xschem on the same display (redraw/zoom/select-all loop on `mos_power_ampli.sch`, clear of the canvas) + 2 CPU burners | `ALL PASS (186)` | 38.5 s |
| the same client + 24 CPU burners on 20 cores (load average 23) | `ALL PASS (186)` | 42.5 s |
| the client's window placed over the canvas, started 3 s before the suite | `ALL PASS (186)` (the suite's window maps later and sits above it) | 38.7 s |

No flake was seen. The other runtimes: plumbing 0.3 s, grid 0.2 s.

### 6. Identity: Classic against base

`classic_ident.tcl` ran on 4 example pages (`mos_power_ampli`, `cmos_inv`, `nand2`, `osc`),
copied to one fixed path because the title block prints the path. It used dark and light,
with 8 poses each: plain, select-all, unselect, two instances, hover, an `m` drag mid-move,
Escape, final. Base used its default (classic); C had `selection_style classic`.
- **64/64 captures identical** (`magick … rgb:- | md5sum`). The poses are not all the same
  picture: select-all differs from plain by 4421–23987 px, two instances by 110–2019 px.
- **Two poses are weak:** the mid-drag capture equals plain on 7 of 8 page/theme pairs, and
  hover adds 0–32 px. The setprop rows in item 3 add 140 more identical Classic rows.

### 7. Public-repo safety

I grepped the 3383 added lines of `C-combined.patch` for these terms:
- the premium feature names and the private repository;
- premium, paid, licen[cs]e and private;
- `/home/`, user and e-mail names, IP addresses, scratch and clone paths, `~/`;
- PDK and design-cell names: sky130, ihp, gf180, `tca_`, `zero_opamp`, bandgap, telescopic.

The only `.sch`/`.sym` names in it are `fix.sch`, `fix2.sch`, `grid.sch`, `zz_opc.sym`
and the stock `nmos4`, `res` and `lab_pin`. The three hits were ordinary English or a
public path: "a private copy", "a private collection", "paid for that", and
`~/.xschem/xschemrc`. The patch itself is clean. I did not open the user's design
directory. For the receipts directory, see LOW above.

## Coverage and what I did not do

- **Not run:** a full T1 (the driver gates), `:0`, or the user's screen. The light scheme
  appears only in the Classic identity check and `eff_probe` is dark-only.
- **Not tried:** a non-cairo build or Windows.
- **Gestures:** all of them synthesized.
- **A deviation:** I ran `test_home_isolation` once headless as a meta-fence check. By
  design its rows start fixture displays of their own, outside `:330`–`:339`, and stop
  them. No Xvfb of mine or of it was left afterwards (checked with `ps`).
- **C2's scope** (hidden floating text, the halo width `atoi`) was not examined.

## State left behind

- **Main tree:** only this receipt written. No commits, stashes or pushes anywhere.
  The user's design directory was not touched.
- **`~/gsv8`:** `e6b38ba83` + `C-combined.patch`, built, with the two new suites
  intent-to-add. No `*~.sch` or `untitled*` left in it.
- **`~/gsv8s`:** deleted, after its restore was verified (sources `cmp`-identical, diff md5
  `b36d19c9…`).
- **Displays:** `:330`–`:332` (3 Xvfb + 3 openbox) killed by recorded pid; no lock files
  left. I did not touch the other sessions' servers I saw (`:101`, `:310`–`:317`, `:320`).
- **`/tmp`:** 59 `xschem_emergencysave_*` directories appeared during the session: 55
  `bandgap`, 3 `untitled` and 1 `fix`. None is from my runs. Each of my runs exited normally
  and none printed `FATAL`. The `fix` one appeared while my loaded run was mid-way, and that
  run still exited 0, so it belongs to another session running the same suite. I left them.
- **Scratch** (`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/selCv/`,
  about 9 MB):
  - `derive.tcl` + `der_new/`;
  - `bop/breaks.py`, `bop/drive.sh`, `bop/eff.sh` + `bop/out/`, `eff/`;
  - `ws_probe.tcl` + `ws/` (including `vg_disp.txt`);
  - `sp_residue.tcl` + `sp/`, `classic_ident.tcl` + `ci/`;
  - `det.sh`, `load_client.tcl` + `det/`.

  Throwaway homes were removed.
