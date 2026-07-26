# Receipt — item 11 viewer-window (round-3, Waveform Viewer)

Verdict: **DONE** [x]. Commits (NOT pushed):
- `cd332719` feature — standalone waveform viewer window shell (6 files,
  +795/-9; amended once pre-report, see deviation f)
- `2c3ac80d` fixer round 1 — sweep cloned/user-rc canvas binds before
  installing the strip filters (2 files, +100/-19)
- `0a90b9db` fixer round 2 — strip the editor toolbar from the viewer
  window (2 files, +50/-2)

Outstanding problems: none (all 3 lenses clean after round 2). Working
tree clean at HEAD for all item files; no pre-batch dirty tracked file
staged in any of the three commits.

## What landed

Product `src/wave_viewer.tcl` (new, namespace `wviewer::`, TIP-278; final
anchors verified at 0a90b9db):
- `wviewer::open` (:142) — raise-or-open ONE viewer per ASE session token;
  real toplevel via `xschem load_new_window -window {}` (the xinit.c
  create_new_window path, spec D4) hosting an untitled canvas that holds
  ONLY wviewer-created graph rects. Headless (`--nogui`) it returns 0 —
  window shell is GUI-only, session bookkeeping untouched (documented in
  the proc).
- **No-save mechanism (D1)**: readonly-for-life untitled buffer with an
  `autosave_backup` bracket — the buffer is never offered for schematic
  save, Ctrl-W closes with zero dirty-save prompts.
- **Editing strip (D2)**: `strip_bindings` (:346) first SWEEPS every
  per-widget canvas bind outside a canonical-spelling keep-set
  (`<Expose> <Configure> <Visibility> <Enter> <Leave> <Motion> <Unmap>
  <MouseWheel> <Button> <ButtonRelease>`), then installs `key_filter`
  (:301) / `btn3_filter` (:322) as the ONLY key/button handlers: nav/zoom
  always; waveform keys `a b s m t A B` over-graph only; Ctrl-W = close;
  everything else silently swallowed. Btn3 over-graph only; double-clicks
  swallowed (D9); ESC forwarded, never closes the window (D10). Readonly
  is the backstop behind the filter. Per-window: other windows keep their
  full bind set (asserted). Fixer 2 adds `pack forget $top.toolbar` in
  open — per-window, deliberately NOT `toolbar_hide` (that flips the
  GLOBAL `toolbar_visible`).
- **Viewer menubar (D7)**: `build_menubar` (:366) — File (Close Ctrl-W),
  View (Fit/Zoom In/Out/Redraw), Graph + Cursors present but disabled
  `TODO(item12)`. `ase::theme` palette + named fonts throughout.
- **Title/number (D5/D6)**: `Waveforms <cell> (<view>)`, re-asserted after
  every readonly toggle (`with_edit` :230 tail) and on FocusIn; C-assigned
  window number via the notify_window_active precedent (receipts/03,05).
- **Sanity display leg**: `place_graph_rect` (:251) + `display_raw` (:261)
  create a `B 2 … flags=graph` rect with node/color attrs and `xschem raw
  read` a real raw file; `over_graph` (:279) tests the snapped pointer
  against wviewer-recorded graph-rect bboxes.

Backend `src/ase.tcl` (+40/-):
- New required backend hook `raw_file` (proc :704, hook list :189,
  ngspice registration :742) → `<rundir>/<cell>_ase.raw`.
- `render_deck` now emits `remzerovec` + `write <rawfile>` inside
  `.control` when >=1 analysis is enabled (:678-679). `remzerovec` is
  load-bearing: with `.options savecurrents` ngspice-42's `write` aborts
  SILENTLY on zero-length `@m...[ib]` vectors (probe-verified) — the D1
  golden deck carries both lines.

Ship wiring: `src/xschem.tcl:14110` source line; `src/Makefile.in:23`
tcl install list (edited the .in, not the generated Makefile).

NOT in scope (by design): traces/cursors/plumbing = items 12-13; Graph +
Cursors menus disabled until item 12. Zero C changes in the whole item.

## Tests

`tests/headless/test_wave_viewer.tcl` — final **68 checks GUI arm + 15
checks headless (`--nogui`) arm**, ALL PASS (58 GUI at cd332719, +5
fixer 1, +5 fixer 2):
- Headless V1-V6: raw artifact produced with sweep points from a
  test_nfet_final scratch state (dc sweep enabled via ase:: API), raw
  read + `raw points/vars` sane; **V6 = the prescribed embedded-graph
  regression leg**: shipped `xschem_library/examples/test_ne555.sch`
  loads readonly, keeps its layer-2 `flags=graph` rect(s), redraw rc 0.
- GUI G1-G9 (DISPLAY-guarded self-SKIP, send_key/send_return helpers per
  receipts/06): open from session token; viewer menubar not editor
  menubar; editing keys do nothing (readonly modal stub asserted UNHIT,
  instances stay 0); Ctrl-W closes w/o prompt; reopen raises same window;
  window number present; title exact after a with_edit cycle (G3); G1s
  (fixer 1) proves cloned user-rc `<Key-i>` + Windows-arm `<Alt-KeyPress>`
  cleared from the viewer canvas only + no stray sequence outside
  keep+filter set; G1t (fixer 2) proves toolbar widget exists but is not
  pack-managed/mapped, main-window toolbar packedness UNCHANGED; G9
  fresh-reopen window equally stripped. Permanent `kf_errs==0`
  "key_filter ran error-free" guard (deviation f).
- `tests/headless/test_ase_core.tcl` updated: D1 golden deck
  (remzerovec+write) + 1-line raw_file entry in the E2 fakesim
  registration (see deviation b). All six protected suites green:
  test_ase_core 66, test_ase_view 36, test_ase_window 154,
  test_ase_dialogs 133, test_ase_final 28, test_ase_interact 63.
- full_audit (implementer run): 189 pass / 18 fail / 1 timeout / 9 skip,
  WIREEDIT PASS; test_wave_viewer + all test_ase_* PASS inside the audit.
  Fails = baseline subset after rerun-first clearance: test_hover_highlight
  (known WSLg flake list); test_nh_anim_rearm and test_apply_hilight_log
  (TIMEOUT) both ALL-PASS on direct re-run (animation/display-stress
  flakes; the item touched no editor C code).

## Sabotage table (each post-commit, `git diff`-confirmed sabotage-only,
targeted `git checkout -- <file>` revert, clean re-run green)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | render_deck `write` emission deleted (src/ase.tcl) | test_wave_viewer V1 (2 checks) + V4 raw-artifact + V5 (5 checks) headless; test_ase_core "D1 golden deck" (1 FAILED/65); test_ase_final stayed ALL PASS | yes |
| S2 | key_filter allowlist neutered — `set fwd 0` -> 1, Ctrl-W branch kept (src/wave_viewer.tcl) | exactly G5 "no readonly modal (messageBox stub unhit)" (stub delta=2: Insert+w each popped the modal); "G5 instances still 0" stayed green as predicted (1 FAILED/57) | yes |
| S3 | retitle dropped from with_edit tail (src/wave_viewer.tcl) | exactly G3 "title STILL exact after a with_edit cycle" (clobbered to `xschem [4] - untitled.sch (read-only)`) (1 FAILED/57) | yes |
| S4 (fixer 1) | bind-sweep condition neutralized (src/wave_viewer.tcl) | exactly the 5 new-claim checks: G1s x3, G5 i-delivery timeout, G5 readonly-modal stub hit 200x (the reported symptom); 58 others pass | yes |

Fixer round 2 recorded no separate sabotage in its commit; its witness is
structural and mapping-independent (`pack info` throws on the viewer
toolbar while the widget exists, main-window packedness asserted
unchanged — the strip cannot be trivially green).

## Fix-round history (2 rounds, the RUNBOOK maximum — both product bugs)

1. **Round 1 → `2c3ac80d`** (bind sweep): cd332719's strip_bindings
   replaced only the generic `<KeyPress>`/`<KeyRelease>` (+enumerated)
   binds, but xinit.c create_new_window runs `clone_canvas_bindings .drw
   <viewer>.drw` BEFORE strip_bindings, so user-rc per-widget binds — the
   repo's shipping profile `cadence_style_rc:109 bind .drw <Key-i>
   {xschem create_instance; break}` — landed on the viewer canvas and,
   being more specific than the generic filter, fired INSTEAD of it:
   pressing `i` in the viewer popped the readonly_notice MODAL advertising
   an Edit menu the viewer does not have (same class latent: set_bindings'
   Windows-only per-widget Alt/Mod4 arms, replace_key remaps). Fix = sweep
   `bind $wp` against a canonical keep-set (no enumerated blocklist to rot),
   then install the filters. +5 GUI checks + S4.
2. **Round 2 → `0a90b9db`** (toolbar): build_widgets creates
   `$top.toolbar` (37 armed buttons — Insert Wire/Symbol/…, Cut/Copy/
   Paste/Delete/Move, FileOpen/Save/Reload, Netlist/Simulate/Waves) and
   pack_widgets packs it on every new window while global
   `toolbar_visible` is 1 (shipping default) — the landed viewer carried a
   fully armed mouse-reachable editing surface; edit clicks threw the
   readonly rejection into Tk's bgerror stack-trace modal. Fix =
   per-window `pack forget` in wviewer::open; nothing re-shows it (the
   Show-Toolbar checkbutton lives on the stripped editor menubar, the
   fullscreen key is swallowed by key_filter). +G1t/G9 legs, GUI 68/68.
3. All 3 lenses re-ran clean after round 2; outstanding problems empty.

## Implementer deviations (accepted, reality-forced)

- (a) Scout probe 1 was incomplete: with `.options savecurrents`
  ngspice-42's `write` aborts SILENTLY (zero-length `@m...[ib]` vectors
  fail checkvalid) — fix = emit `remzerovec` before `write`.
- (b) Prompt said test_ase_core changes = "ONLY the D1 golden", but the
  prompt's own D3 required-hook-list change makes register_backend reject
  the E2 fakesim 4-hook dict — 1-line `raw_file` entry added there.
- (c) Scout's over_graph coord source (`xschem object rect #2,N`) returns
  NO coordinates (scheduler.c object_descriptor = type/index/layer/id/name
  only) — over_graph instead tests the snapped pointer (mousex/y_snap)
  against wviewer-recorded graph-rect bboxes (safe: the viewer canvas
  holds only wviewer-created rects).
- (d) Viewer toplevel derived from win_path via regsub — `xschem get
  top_path` reports {} under the tabbed interface.
- (e) Headless `wviewer::open` returns 0 (shell is GUI-only).
- (f) GREEN-BUT-HOLLOW lesson, captured permanently in the test: renaming
  a namespaced proc into `::` breaks its `variable` resolution — the first
  S2 run was green because the instrumented filter ERRORED
  (swallow-by-error mimics swallow-by-design). Fixed by renaming within
  the namespace + a permanent "G* key_filter ran error-free" (kf_errs==0)
  check; this is why cd332719 was amended pre-report.
- (g) S2 was scoped to the allowlist decision only (fwd default), keeping
  the Ctrl-W branch, so it fails exactly G5 as the prompt predicted.

## Corrected anchors worth keeping (verified at 0a90b9db)

- `src/wave_viewer.tcl`: :58 namespace vars, :89 title_for, :109
  window_for, :142 open (toolbar strip + strip_bindings call live here),
  :202 close, :230 with_edit (retitle tail = S3 target), :251
  place_graph_rect, :261 display_raw, :279 over_graph, :301 key_filter,
  :322 btn3_filter, :346 strip_bindings (sweep), :366 build_menubar.
- `src/ase.tcl`: :189 required-hook list (5 hooks incl. raw_file), :667-679
  remzerovec+write emission, :704 raw_file, :742 ngspice registration.
- `src/xschem.tcl:14110` source site; `src/Makefile.in:23` ship list.
- Recon corrections vs the waveform_viewer.md spec's anchors:
  - `xschem object rect #2,N` has NO coordinate fields (scheduler.c
    object_descriptor) — do not plan geometry off it (items 12-13 beware).
  - `xschem get top_path` = {} under tabbed interface; derive the toplevel
    from win_path via regsub.
  - xinit.c create_new_window clones canvas bindings BEFORE any
    per-window customization can run; Tk canonicalizes bind sequences
    (`<KeyPress>`→`<Key>`, `<ButtonPress>`→`<Button>`, `<Key-i>`→`i`,
    `<Shift-Insert>`→`<Shift-Key-Insert>`) — any keep/strip set must use
    canonical spellings.
  - Toolbar: `toolbar_hide` is GLOBAL (`toolbar_visible`); per-window
    removal = `pack forget $top.toolbar`.
