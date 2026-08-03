# Session prompt — Waveform Viewer user guide + shortcut inventory

*Written 2026-08-01. Paste the block below into a fresh session.*

---

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Write the **user guide for the ASE Waveform Viewer**. Audience: a new user who
has never opened it, not a maintainer.

## WHAT ALREADY EXISTS — checked 2026-08-01, re-verify before writing

- **No standalone user guide.** The only user-facing viewer text is
  **§6 "The Waveform Viewer" of `doc/ase_l_tutorial.html`** (~7 kB), including
  subsections "Viewer keyboard" and "Viewer mouse / wheel".
- **Those two tables are STALE.** They list `f`, `Z`/`Ctrl-z`, arrows,
  `a b s m t A B`, `Ctrl-W`, `ESC`, wheel/Shift-wheel/Ctrl-wheel and
  "right-button drag = box zoom". Missing at least: markers (`m`, `d`, DEL),
  `Ctrl-D` Clear All, `Ctrl-E` Delete All Markers, `e` Delete Empty Strips,
  `Ctrl-G` grid, `u`/`U` viewer undo/redo, legend LMB select + Ctrl+click
  multi-select, LMB strip drag-reorder, LMB trace drag between strips, RMB
  legend/trace context menu, Ctrl+wheel in an axis MARGIN (per-axis zoom),
  plot modes + target-strip click, snap. And one is WRONG: the **graph pan
  moved LMB → MMB**.
- `doc/xschem_man/graphs.html` is upstream and covers **embedded schematic
  graphs**, a different surface. Do not fold the two together; cross-link.
- `doc/claude/specs/waveform_viewer.md`, `waveform_viewer_modes.md`,
  `graph_markers.md`, `ase_l.md` and `doc/claude/code_analysis/waveform_subsystem_reference.md`
  are DESIGN docs. They are **not installed** (`doc/Makefile` ships only
  `*.svg *.html *.css *.png` from `doc/` and `doc/xschem_man/`) and are not the
  deliverable. Mine them for facts; do not copy their register.

## DELIVERABLE 1 — the guide

`doc/waveform_viewer_guide.html`, so `make install` ships it. Match
`doc/ase_l_tutorial.html`'s structure and reuse `style.css` — same look, same
heading scheme, same table styling. Cover, in a task order a new user follows:

1. what the viewer is (a read-only xschem window with its own menubar) and the
   three ways it opens: the `~` strip button, auto-plot after a run, Direct Plot
   / `Ctrl-4`;
2. strips (graphs) vs traces; the target strip and single vs multi plot mode;
3. getting traces in: Outputs `Plot` column, Direct Plot, `Graph > Add Trace…`
   incl. RPN expressions and the re-run caveat that expression vectors go stale;
4. reading values: cursors A/B, the readout bar, markers and delta markers;
5. navigating: fit, zoom, pan, per-axis zoom, shared X, axes dialog;
6. organising: reorder strips, move traces between strips, split, delete
   traces/strips/markers, Clear All, undo/redo;
7. selection: what "selected" means, single vs multi, and what a selection is
   FOR (delete, drag, bold);
8. saving and reloading with the session state;
9. **§ Keyboard and mouse reference** — deliverable 2;
10. a short troubleshooting list (nothing plotted, traces draw empty after a
    re-run, viewer will not open, op-only results).

Then: shrink `ase_l_tutorial.html` §6 to a short orientation plus a link to the
new guide (do not leave two copies to drift), and **add the link to
`doc/index.html`** — note that `ase_l_tutorial.html` is not linked there either,
so fix both while you are in the file.

## DELIVERABLE 2 — the keyboard + mouse reference, derived FROM SOURCE

An **inventory**, not a sample. Every key and every mouse gesture the viewer
window responds to, plus the ones it deliberately swallows or forwards. Build it
by reading the code, never by copying the stale tables:

| where | what to extract |
|---|---|
| `src/wave_viewer.tcl` `wviewer::install_default_binds` | the `WaveViewer` bindtag defaults (`Ctrl-D`, `Ctrl-E`, `e`, `Ctrl-G`, `u`, `U`, …) and the "only if unbound" rule |
| `src/wave_viewer.tcl` `key_filter` | which keys are FORWARDED to the C engine (the `graphkeys` set) and which are swallowed |
| `src/wave_viewer.tcl` `btn2_filter` / `btn3_filter` / `strip_bindings` | MMB forwarding, the Button-3 swallow, and which cloned `.drw` bindings are swept off a viewer canvas |
| `src/wave_viewer.tcl` the drag arms | LMB strip reorder, LMB trace-to-strip drag, the press-zone split, ESC-cancel |
| `src/callback.c` `waves_callback` + the graph key/button arms | `a b s m t A B`, DEL, cursor drags, box zoom, marker create/drag |
| `src/wave_viewer.tcl` wheel arms + `graph_axis_wheel_map` (`src/draw.c`) | wheel / Shift+wheel / Ctrl+wheel, and the axis-MARGIN variant |
| `src/cadence_style_rc` | what an rc already rebinds, and `Ctrl-4` |
| the viewer menus | every accelerator shown in a menu must appear in the table with the same spelling |

Each row: **gesture — what it does — where it works** (whole window / only over
a strip / only over the legend / only in an axis margin), because several are
position-gated and a user who does not know that reports them as broken.

Flag the collisions that surprise people: `Ctrl-E` is *go back* in a schematic
but *delete all markers* here; `e` is *descend* in a schematic but *delete empty
strips* here; `Ctrl-G` toggles the global dot grid in a schematic and the
per-strip graph grid here.

## DELIVERABLE 3 — how to CHANGE a binding, with working examples

A subsection showing the real mechanisms, each with a copy-pasteable snippet the
user can drop in `~/.xschem/xschemrc` (or any `--script` rc, e.g.
`src/cadence_style_rc`):

- **the `WaveViewer` bindtag** — defaults are installed once, at the first
  viewer open, and only for a sequence nothing has bound yet, so an rc that
  binds first WINS:

  ```tcl
  bind WaveViewer <Control-Key-d> {break}                  ;# drop the default
  bind WaveViewer <Control-Key-r> {wviewer::clear_all_at %W; break}
  ```

  Explain the trap explicitly: disable with `{break}`, **not** `{}` — an empty
  script DELETES the binding, which reads as "never bound" and gets
  re-defaulted.
- **why it is a bindtag and not the canvas widget** (`strip_bindings` sweeps
  widget-level sequences; the tag is reachable before any viewer window exists).
- **config variables** that change behaviour without rebinding anything —
  `wviewer_plot_mode`, `wviewer_grid_show`, `wviewer_grid_dash_off`,
  `wviewer_legend_textmag`, `wviewer_legend_bold` — read lazily, so an rc can
  set them. Give the one-line form for each and say what it changes.
- **the action registry / bindings file**, if it reaches this window: check
  `src/xschem.tcl`'s action registry, `src/mouse_bindings.tcl`,
  `tests/headless/test_bindings_file.tcl` and `test_remap.tcl`, and say plainly
  whether viewer bindings are remappable that way. If they are NOT, say so —
  a user who tries it and fails is worse off than one who was told.
- what canNOT be rebound today (the C-side `waves_callback` keys, mouse-button
  roles inside the engine) and what happens if you try.

## VERIFICATION — the guide is a claim, not prose

- Every shortcut in the table must be **traced to the code that implements it**;
  cite nothing you did not read.
- Where a suite already drives the gesture, say so; where you can cheaply add a
  check that the binding EXISTS (`bind WaveViewer <Key-x>` non-empty, the menu
  accelerator string matches the table), add it to
  `tests/headless/test_wave_grid.tcl` or the suite that owns the feature — a
  doc table that silently rots is the thing being replaced.
- Mark anything you could not exercise as such. Do not write "this opens a
  dialog" if you never opened it.
- Screenshots are optional; if you add any, they go in `doc/` as `.png` (the
  Makefile installs them) and must be of the real window.

## DISCIPLINE

- Read `doc/claude/code_analysis/waveform_subsystem_reference.md` first (it is
  the map, and landmine 50 is the most recent addition), then
  `doc/claude/specs/waveform_viewer_modes.md` §§12-19 and
  `doc/claude/specs/graph_markers.md`.
- The user runs `src/xschem --script src/cadence_style_rc --logdir /tmp`; the
  surface that matters is the **ASE waveform window**, not an embedded
  schematic graph.
- ⚠ **Never** `pkill -f 'src/xschem'` — that pattern matches the user's live
  session. Kill only PIDs you launched, after reading `pgrep -af xschem`.
- Running anything under a real `$DISPLAY` goes through the GUI gate: use
  `tests/headless/run_suites.sh` or `tests/headless/gated_xschem.sh`, never a
  bare loop, and press `Allow 30m` / `Allow 2h` once rather than clicking
  Proceed repeatedly.
- **KNOWN-FLAKY, not yours**: `test_cadence_drag`, `test_wave_trace_menu` TG9,
  `test_ase_plot` P4/P6/P8, `test_hover_highlight`, `test_palette`. The check
  COUNT is the signal, not the verdict.
- Git: explicit file list, no `git add -A`, no `git reset --hard`, no
  `git push`. Commit message ends with:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`

## DELIVERABLES

1. `doc/waveform_viewer_guide.html` — the guide, installed by `doc/Makefile`.
2. Its keyboard + mouse reference section, complete and source-derived,
   including the position-gated column and the schematic-vs-viewer collisions.
3. The rebinding subsection with working rc snippets, including what cannot be
   rebound.
4. `ase_l_tutorial.html` §6 reduced to an orientation + link; `doc/index.html`
   linking both.
5. Any checks you added, and an explicit list of what in the guide is
   unverified.
