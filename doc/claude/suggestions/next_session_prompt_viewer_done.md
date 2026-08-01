# Resume prompt — viewer enhancements, all ten items landed

Paste the block below into a fresh session.

---

The waveform-viewer enhancement plan
(`doc/claude/suggestions/plan_viewer_enhancements_2026-07.md`) is **complete —
all ten items built, tested and committed.**

**State.** Branch `fluid-editing`, HEAD `780bd468`, **19 commits ahead of
`github/fluid-editing`, nothing pushed — do not push unless I say so.**
Order run: 4, 5, 1, 2, 3, 9, 10, 7, 8, 6.

## What landed this session

| commit | what |
|---|---|
| `50c3537f` | item 7 — RMB a trace → "Move to Separate Strip" |
| `5ddb8361` | **fix**: `wviewer::open` intermittently opened onto the main window |
| `6ca278c6` | item 8 — RMB empty strip space → "Split Strip" (+ `xschem get graph_plotbox_at`) |
| `9727791a` | item 6 — the dragged trace shrinks while you carry it |
| `780bd468` | item 6 round 2 — **both axes, 30 %** (review rejected Y-only at 10 %) |

Suites: `test_wave_trace_menu` 128/34, `test_wave_split_strip` 122/38,
`test_wave_drag_preview` 46/18. Full wave battery 12/12 at unchanged counts
(snap 59, grid 80, legend 44, empty_strips 94, modes 385, markers 712,
viewer 349, clear_all 68, ase_plot 145).

## THE ONLY THING OUTSTANDING: three pixel deliverables nobody has looked at

The plan's review ledger carries the detail. In short, **~300 green checks across
three suites and not one of them can see a pixel**:

- **Item 6 round 2** (`780bd468`) — the gate was raised and is still open when
  this was written. Both-axes-at-30 % is unconfirmed.
- **Items 7 and 8** — the suites spy `tk_popup` rather than posting for real (a
  live popup takes a global grab and swallows the rest of the run), so "the menu
  looks right and lands under the pointer" is unchecked.
- **Item 6 is worse and deliberately so** — the shrink happens between `S_Y()`
  and `XDrawLines`. There is no seam to spy and no pixel readback, so **deleting
  the C line that does the shrinking leaves all 46 checks green.** Everything
  that suite proves is plumbing.

So the first job of the next session is an **eyeball pass**, not more code:

1. Right-click a trace in a strip with 2+ traces → menu, correct header name,
   "Move to Separate Strip" does the right thing, `u` undoes it.
2. Right-click empty waveform space → "Split Strip". Check it does **not** appear
   over the wave labels above the plot box (that collision is what
   `graph_plotbox_at` was added to close).
3. Drag a trace between strips → does it visibly shrink in **both** axes? Is
   30 % right? (`wviewer_drag_shrink`, default `0.7`; `1.0` disables the
   effect.) Round 1 shipped Y-only at 10 % and was rejected on sight; round 2
   is `780bd468` and **has not been looked at yet**.

## Two decisions I deferred to you

- **Digital and bus strips get NO context menu at all** — neither item 7's nor
  item 8's. Both engine queries (`graph_wave_at`, `graph_plotbox_at`) refuse
  them. Splitting a bus strip into one strip per bus is a reasonable want; say so
  and it can be relaxed, **but the same guard drives item 9's snap cursor**, so
  it has a second consumer.
- **A one-pixel RMB wobble is a box zoom, not a menu.** The engine commits a zoom
  on *any* Button-3 travel (snapping is off for graph interaction, issue 0143),
  so the menu's tolerance is zero to keep the two mutually exclusive. If that
  feels twitchy in use, the fix is in C — teach the release to ignore sub-N-pixel
  travel — and it would change box zoom for the ~127 schematics that embed
  graphs.

## Process that worked — keep it

**build → suites green → COMMIT → raise the review gate in the background →
start the next item while it runs.** Never push.

```
tools/review_gate/review_gate.sh --label "..." --body-file <summary.md> --out <verdict.txt>
```
Run suites through `tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never
a bare loop, or the GUI gate cannot pause them.

**The 10-run soak earned its keep this session**: it is what caught `5ddb8361`,
a pre-existing intermittent that no single run reproduces and that had been live
for eight days. Do not skip it on gesture items.

## Traps added to the pile this session

1. **`GRAPH_CLICK_TOL` is a Button-1 constant.** Button3 has a box zoom to
   collide with and its gate is exact equality on the raw pointer
   (`callback.c` ~1871); graph interaction disables snapping (~810). Copying the
   3 px LMB tolerance to RMB shipped a defect.
2. **A gate that says "no trace here" also matches the LEGEND MARGIN**, where a
   Button3 press is already the wave-attributes dialog. Any strip-space gate
   needs `graph_plotbox_at` as well.
3. **Test both index spaces or the mapping is untested.** A leg asserting "armed
   with the NODE index" passed against model-index code because the fixture's two
   spaces coincided. Plant a `vec`-less trace to separate them.
4. **`wviewer::in_ctx` is `uplevel #0`, `with_edit` is `uplevel 1`** (unchanged,
   still true, still silent).
5. **A suite's check COUNT is the signal**, not its verdict.
6. **Never rebuild while a suite batch is queued.**
