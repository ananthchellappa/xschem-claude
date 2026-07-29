# Resume prompt — viewer enhancements, item 7 onward

Paste the block below into a fresh session.

---

Continue the waveform-viewer enhancement plan:
`doc/claude/suggestions/plan_viewer_enhancements_2026-07.md`.

**State.** Branch `fluid-editing`, HEAD `00fa2aba`, **12 commits ahead of
`github/fluid-editing`, nothing pushed — do not push unless I say so.**
Seven of ten plan items are DONE, committed and eyeballed-OK by me: **4, 5, 1,
2, 3, 9, 10**. The review ledger near the top of the plan doc records each one;
keep it current.

**Next: item 7** (RMB context menu on a trace → "move to separate strip"), then
**item 8** (RMB on empty strip space → split strip; nearly free once 7 lands),
then **item 6** (mid-drag 10% shrink preview; pure polish, defer-able).

## Item 7 — the design is already settled, do not redesign it

The plan told me to enumerate every Button-3 site before writing menu code. I
did, and it **changed the recommended gesture**. The full table and the
reasoning are in the plan doc under item 7 (`✅ RECON DONE`), committed as
`00fa2aba`. The short version:

- **Post the menu on the no-travel `ButtonRelease-3`, not on a hold timer.**
- **MEASURED:** a bare RMB click in the plot body is a **no-op** today (probe:
  x range `0 1` unchanged through press *and* release; with no motion
  `graph_rubber_active` stays 0 so no zoom is committed). So a click-menu is a
  pure addition, not a replacement.
- Posting on the release, *after* `btn3_filter` has forwarded to C, dissolves
  all three hazards the plan worried about instead of mitigating them: no grab
  exists during press→release so `GRAPHPAN` clears normally; the rubber
  rectangle is erased by `callback.c` ~1460 on that same release; and the modal
  `input_line` is on the **press**, which this design never touches.
- Travel test precedent: the LMB wave-bold click uses
  `xctx->graph_press_x/y` vs `GRAPH_CLICK_TOL` (`callback.c` ~879). In Tcl,
  record `%x`/`%y` on `T==4` in `wviewer::btn3_filter` and compare on `T==5`.

**Still to build:** the menu widget, the gate predicates (over a trace via
`xschem get graph_trace_at`; `wviewer::node_count >= 2`), and the payload
`wviewer::move_trace_to_new_strip` — which the plan says must be
`wviewer::move_trace` plus one `linsert` of an `empty_graph`, reusing the PURE
`wviewer::move_trace_in_graphs` (~2521) so marker migration, the
`hilight_wave` hand-off and empty-destination range blanking come for free.
It must **not** call `add_graph` (regenerates mid-op, skips capture/undo/log).
Shift the stored target with `plot_signals`' arithmetic, **not**
`reordered_index`. ⚠ Landmine 33: `near_wave` answers 0 across the whole body
of a digital/bus strip.

## Process I am using — keep it

After each item: **build → suites green → COMMIT → raise the review gate**, then
start the next item while the gate runs.

```
tools/review_gate/review_gate.sh --label "Item N — <title> (<commit>)" \
  --body-file <summary.md> --out <verdict.txt>
```
Run it with `run_in_background: true` (a 30-min foreground wait exceeds the
600 s command ceiling). `PROCEED`/`TIMEOUT`/`NOGATE` → exit 0, go on; `STOP` →
exit 3, halt. On `TIMEOUT`, proceed **and** mark the item un-eyeballed in the
plan doc's ledger. Spec: `doc/claude/specs/review_gate.md`.

**Never push.** Commit before asking for review.

## Suites that must stay green (full counts)

Run through `tests/headless/run_suites.sh` — never a bare soak loop, or the
GUI gate cannot pause it. `SUITE_TIMEOUT=600` (the 200 s default is too short
for `test_wave_markers`).

| suite | DISPLAY | nogui |
|---|---|---|
| `test_wave_snap` (items 9+10) | 59 | 36 |
| `test_wave_grid` (items 2+3) | 80 | 44 |
| `test_wave_legend` (item 1) | 44 | 33 |
| `test_wave_empty_strips` (item 5) | 94 | 28 |
| `test_wave_modes` | 385 | |
| `test_wave_markers` | 712 | |
| `test_wave_viewer` | 349 | |
| `test_wave_clear_all` | 68 | |
| `test_ase_plot` | 145 | |

## Hard-won traps from this session — read before writing code

1. **A pixel deliverable is not done until it is eyeballed.** Item 9 shipped
   TWO defects past 28 green checks (a cursor trail; a proximity gate instead
   of the plot box). Everything the suite could reach was correct. For
   pixel/gesture work the report is "suites green, please look" — never "done".
2. **`wviewer::in_ctx` uses `uplevel #0`** (global level): a `set` inside its
   script body creates a *global* and the caller's local stays empty. Take the
   value through the **return**. `wviewer::with_edit` uses `uplevel 1` and DOES
   reach the caller's scope. Two sibling brackets, different behaviour, silent.
3. **`xschem get`/`set` are letter-dispatched internally** — `get` groups
   sub-keys by first letter, `set` splits on `argv[2][0] < 'n'`. A key in the
   wrong half is **silently unreachable**; the setter just does nothing.
4. **Erasing a window-only overlay**: do not re-stroke with `xctx->gctiled`
   (the schematic snap-cursor path) — it does not remove the glyph in a viewer
   window. Copy the patch back from `save_pixmap` with `MyXCopyArea`, and never
   write the overlay into `save_pixmap`.
5. **Sabotage every new suite, including legs just written to catch a reported
   bug.** One of mine used a magic `> 12` threshold that the buggy code cleared
   at ~13. Behavioural thresholds should be **fractions** of a measured range.
6. **A suite's check COUNT is the signal, not its verdict.** `test_ase_plot`
   prints `ALL PASS (30 checks)` when WSLg geometry makes it skip P1–P7, vs 145
   for a real run. `test_wave_clear_all` does the same (68 vs 58).
7. **`run_suites.sh` classifies on the literal string `ALL PASS` and on exit
   status.** A new suite whose footer says `RESULT: PASS` is reported FAIL while
   printing PASS itself.
8. **Never rebuild while a suite batch is queued or running** — the batch waits
   at the GUI gate and will run against whatever binary exists when it starts.
   Cost me one bisect that returned no output at all.
9. **Blast radius**: `draw_graph_grid`, `draw_graph_variables` and
   `graph_point_at` are shared with ~127 shipped schematics that embed a graph.
   Viewer-only behaviour goes in a **per-rect prop token** (emitted only by
   `wviewer::graph_props`) or a **per-context `xctx` flag** (the `no_grid`
   precedent) — never a global Tcl var. Defaults must be set **before** the
   `RECT_OUTSIDE` early return in `setup_graph_data` (shared `graph_struct`).
10. **A decision about how something LOOKS is provisional until it is looked
    at.** The plan's recorded "all legend entries bold" decision was reversed on
    sight. Ship the knob, default it conservatively, let the eyeball settle it.

## Docs to keep updated

`doc/claude/specs/waveform_viewer.md` (one section per item),
`doc/claude/suggestions/plan_viewer_enhancements_2026-07.md` (checkbox, a `⚠`
block for anything the section got wrong, and the review ledger),
`src/cadence_style_rc` for any new rc-overridable var.
