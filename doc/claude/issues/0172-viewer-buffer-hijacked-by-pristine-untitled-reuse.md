# 0172 — a waveform-viewer window can be hijacked by the pristine-untitled reuse path, and viewer keys then eat the loaded schematic

Status: **OPEN**. Filed 2026-07-29. Pre-existing; **not** introduced by viewer
plan item 4 — surfaced by the adversarial review of it, and reproduced
independently by two agents.

## Summary

`xschem load_new_window` reuses a *pristine untitled* buffer in place instead of
opening a new window. An ASE waveform-viewer buffer satisfies every test
`is_pristine_untitled()` applies, **permanently and by construction**, so a real
user schematic can be loaded into a live viewer window. The window keeps its
`WaveViewer` bindtag, its viewer menubar and its `wviewer::windows` registry
entry, so the viewer's own keys and menu entries then operate on the user's
schematic:

* **`Ctrl-D` / Graph > Clear All** — `wviewer::clear_all` replaces the model with
  one empty strip and regenerates. Probed on a hijacked window: the loaded
  schematic went from `instances=14 wires=8 graph_rects=3` to
  `instances=0 wires=0 graph_rects=1`. **The whole document.**
* **`u` / `Shift-u`** — `wviewer::undo_at` / `redo_at` drive the viewer's
  model-snapshot stack, not the C undo stack, against a document that stack
  knows nothing about.
* **`Ctrl-E` / Graph > Delete All Markers** (item 4, 2026-07-29) — strips
  `markers=` from the schematic's graph rects. Strictly the *smallest* instance
  of the family.

## Root cause

`scheduler.c` ~6571:

```c
if(is_pristine_untitled() && tcl_braceable(f)) tclvareval("xschem load {", f, "}");
```

`is_pristine_untitled()` (`scheduler.c` ~6072) tests only `currsch`, `modified`,
`instances`, `wires` and the basename. A viewer buffer is `currsch == 0`, has no
instances and no wires (its content is graph rects), is named `untitled`, and —
this is the part that makes it permanent rather than merely momentary — the
`wviewer::with_edit` contract (D1) ends every mutation with `xschem set_modify 0`
before restoring `readonly 1`, so **`modified` is 0 for the buffer's whole
life**. A viewer therefore never ages out of "pristine" the way an ordinary
untitled buffer does the moment the user draws something.

## Why it is not an item-4 defect

Item 4 adds no new reachability: the bindtag, the registry, the token
resolution and the menubar attachment all pre-date it, and the damage it can do
(one prop token) is strictly smaller than what `Ctrl-D` on the same bindtag has
been able to do since issue 0171. Any session that reaches this state has
already lost the whole schematic to the key one to the left.

Mitigating, but not a fix: the post-op buffer is left `readonly=1 modified=0`,
so the loss cannot reach disk unless the user explicitly clears read-only. And
the hijacked window is visibly wrong long before a key is pressed — viewer
menubar, no toolbar, no grid.

## Fix direction (not yet implemented)

Exclude viewer buffers from the reuse test. The registry is the honest oracle,
not a heuristic on the buffer contents: `is_pristine_untitled()` (or its caller
at ~6571) should refuse when the candidate window path is a value of
`wviewer::windows`. A C-side flag on the viewer's `xctx` set at
`wviewer::open` time would avoid the C→Tcl query.

Whatever the mechanism, the regression guard belongs in
`tests/headless/test_wave_clear_all.tcl` next to the existing `CG*` binding legs
— open a viewer, `load_new_window` a real schematic, and assert it landed in a
**new** window and that the viewer still holds its own buffer.

## Cross-references

* `doc/claude/specs/waveform_viewer.md` — the `with_edit` / D1 read-only contract
  that makes `modified == 0` permanent.
* `doc/claude/issues/0171-viewer-clear-all-ctrl-d.md` — the `Ctrl-D` that makes
  this destructive rather than cosmetic.
* `doc/claude/specs/graph_markers.md` §6.1.1 — the `Ctrl-E` that surfaced it.
