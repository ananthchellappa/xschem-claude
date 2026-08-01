# 0172 — a waveform-viewer window can be hijacked by the pristine-untitled reuse path, and viewer keys then eat the loaded schematic

Status: **FIXED** 2026-07-31. Filed 2026-07-29. Pre-existing; **not** introduced by
viewer plan item 4 — surfaced by the adversarial review of it, and reproduced
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

## It reproduces HEADLESS — that is the useful part

`is_pristine_untitled()` never looks at the viewer, only at the buffer's SHAPE, so a
buffer shaped like a viewer's is hijacked identically with no Tk, no `DISPLAY` and no
`wviewer::open`. Measured 2026-07-31 against `54eabbaf`, `--nogui`:

```tcl
xschem clear force
xschem set rectcolor 2
xschem rect 0 0 100 100 -1 "flags=graph,unlocked" 0
xschem set_modify 0          ;# the with_edit/D1 contract, permanently
xschem set no_grid 1
xschem set no_snap 1
xschem set readonly 1
xschem load_new_window <real.sch>
```

```
before  rects2=1 inst=0 wires=0 modified=0 readonly=1 ntabs=0 sch=untitled.sch
after   rects2=0 inst=1 wires=1 modified=0 readonly=0 ntabs=0 sch=real.sch
```

`ntabs` never moved and `rects2` went to **0**: the schematic was loaded *into* the
viewer-shaped buffer and its graph rect was destroyed. Note `readonly` went **1 → 0** as
well — the load resets it — so "the window is read-only, nothing can reach disk" is a
mitigation that the hijack itself removes.

## Root cause

`is_pristine_untitled()` (`src/scheduler.c`, pre-fix) tested only `currsch`,
`modified`, `instances`, `wires` and the basename. A viewer buffer is
`currsch == 0`, has no instances and no wires (its content is graph *rects*), is
named `untitled`, and — this is the part that makes it permanent rather than
merely momentary — the `wviewer::with_edit` contract (D1) ends every mutation
with `xschem set_modify 0` before restoring `readonly 1`, so **`modified` is 0
for the buffer's whole life**. A viewer therefore never ages out of "pristine"
the way an ordinary untitled buffer does the moment the user draws something.

## FOUR doors, not one

The predicate has three callers — the earlier draft of this doc named only the second —
and there is a fourth door that does not go through the predicate at all:

| door | where (2026-07-31) | reachable under `--nogui`? |
|---|---|---|
| 1. `xschem load -gui` routing | `src/scheduler.c` `route_newwin = has_x && !force && !inplace_hint && !is_pristine_untitled()` | no — `has_x` is the first conjunct, so the predicate is not even evaluated |
| 2. `load_new_window <file>` | `src/scheduler.c`, the `is_pristine_untitled() && tcl_braceable(f)` reuse | **yes** |
| 3. `load_new_window` via the file dialog | same file, the dialog arm | no — needs the dialog |
| 4. `ask_new_file()` | `src/actions.c` — the in-place arm calls `load_schematic()` **unconditionally**; the predicate is never consulted | no — `if(!has_x) return;` |

The CIW rewrites a typed `xschem load <file>` into the `-gui` form
(`tests/headless/test_ciw_interactive_load.tcl`, `doc/claude/specs/load_window_routing.md`),
so door 1 is a *user-facing* door, not an internal one.

**Door 4 was found while fixing 1–3 and is the nastiest**, because no change to
`is_pristine_untitled()` can reach it: with `open_in_new_window` at its shipping default of
0, `ask_new_file()` clears hilights, resets `currsch`, removes symbols and calls
`load_schematic()` over whatever the current context holds. It is entered from `xschem
load` with **no filename** (the CIW rewrite only adds `-gui` to a load that *has* an
argument) and from Ctrl-O / Alt-O. It is *not* reachable from the viewer's own keyboard —
`wviewer::key_filter` forwards only ESC, `f`/`Z`/`Ctrl-z` and the `graphkeys`
`{97 98 100 115 109 116 65 66 77}`, which excludes `o` (111), and the viewer's File menu
has only Close — but it is reachable by typing `xschem load` in the CIW while the viewer
holds the context. Measured: with door 4 open and 1–3 closed, that clobbered the viewer
and its graph rects went to 0 (`test_wave_clear_all` CG10, both legs red).

## The fix (implemented 2026-07-31)

Inside `is_pristine_untitled()` itself, so doors 1–3 close at once and the next caller
cannot reintroduce the hijack, plus one line in `ask_new_file()` for door 4. Three
mechanisms, deliberately:

1. **`xctx->wave_viewer`** — a fifth per-context C flag next to `no_grid` / `no_snap` /
   `graph_snap` (`src/xschem.h`), with `xschem get wave_viewer` / `xschem set
   wave_viewer 0|1` arms in `src/scheduler.c`, stamped by `wviewer::open`
   (`src/wave_viewer.tcl`) in the same block as the other four and *below* that block's
   `[xschem get current_win_path] ne $wp` refusal, so it cannot be branded onto a real
   schematic that took the context by accident. `alloc_xschem_data()` uses `my_calloc`,
   so every other context is 0 for free — there is no explicit `no_grid = 0` / `no_snap
   = 0` anywhere either, and that is why. `is_pristine_untitled()` returns 0 when it is
   set: a viewer is excluded because it **is** a viewer, not because of what it happens
   to contain.
   Making it settable from Tcl is not only for `wviewer::open`: it is what lets the
   regression guard brand a buffer as a viewer **headlessly**.
2. **"pristine" hardened to mean actually empty** — no texts and no rects / lines /
   polygons / arcs on any layer, not merely no instances and no wires. Drawing normally
   sets `modified`, which is what made the other arrays look redundant; but any path
   that clears it (the viewer's D1 contract, a script calling `xschem set_modify 0`)
   handed a buffer *with content in it* to the next open. Measured: a freshly created
   untitled buffer is 0 in every one of those arrays, at startup and after `xschem clear
   force`, so this costs the intended behaviour nothing.
3. **`ask_new_file()` forces its new-window arm for a viewer** (`src/actions.c`):
   `if(xctx && xctx->wave_viewer) in_new_window = 1;`. That arm goes through
   `load_new_window`, hence through the fixed predicate, so door 4 lands where doors 1–3
   do. One line rather than an argument about who can press Ctrl-O.

The registry lookup this doc originally proposed (`is_pristine_untitled()` asking Tcl
whether the window path is a value of `wviewer::windows`) was **not** implemented: it
puts a C→Tcl query in the middle of a predicate that runs on every open, and it is not
testable without a real viewer.

### What was deliberately NOT done

Refusing reuse whenever `xctx->readonly` is set would also fix this and needs no new
flag. It is a bigger behavioural claim than the evidence supports: this branch has
several paths that open ordinary schematics read-only (descend read-only, the reopen
shortcuts) and a read-only buffer is not obviously a bad reuse target. Measured
pre-fix and unchanged after: a **read-only** pristine untitled buffer is reused exactly
like a writable one, and `tests/headless/test_pristine_untitled_viewer_0172.tcl` leg R1
pins that. If that ever flips it should be a decision, not a regression.

## Guards

* `tests/headless/test_pristine_untitled_viewer_0172.tcl` — **23 checks, no X needed**.
  The mechanism: F* the flag itself (default 0, round-trip, per-context — branding one
  window does not brand another); V* the defect (viewer-shaped + branded buffer →
  new window, graph rect intact, branding intact); S* the emptiness hardening (an
  *unbranded* graph rect, and a lone text); P* the behaviour that must not change (a
  genuinely pristine untitled buffer is still reused in place); R* read-only is not the
  guard; M* the control that proves the "a new window appeared" witness can fail.
  Pre-fix it failed 16 of 23; the P/R/M legs passed pre-fix and still pass.
* `tests/headless/test_wave_clear_all.tcl` **CG9** (needs X, 4 checks) — the leg that
  proves `wviewer::open` *itself* brands the context, i.e. that the C-side refusal is
  armed in production and not only in the headless test's imitation.
* `tests/headless/test_wave_clear_all.tcl` **CG10** (needs X, 2 checks) — door 4: a bare
  `xschem load` (dialog stubbed, as `test_load_window_routing` stubs `ask_save`) against a
  real viewer must open a new window and leave the viewer's rects alone. Verified honest
  by reverting `src/actions.c` to `HEAD` in the worktree, rebuilding, and watching both
  legs go red — the second one because the viewer's graph rects were destroyed. Use a
  file that is *not* already open: `new_schematic create` switches to the window holding
  an already-open file instead of creating one, which leaves `ntabs` unmoved and reads
  exactly like the hijack.
* `tests/headless/test_load_window_routing.tcl` (needs X, 14 checks) — the pre-existing
  guard on the `-gui` door; re-run green after the fix, including its "pristine untitled
  is reused in place" legs.

## One thing the flag itself broke, and the fix for it

A per-context flag travels with the *document*, but "this window is a viewer" is a
property of the *Tk surface* — the WaveViewer bindtags and the viewer menubar stay on the
widget. `swap_windows()` / `swap_tabs()` (`src/xinit.c`), which run when the **main**
window is closed while another window/tab exists, swap the two contexts between slots and
then re-swap `top_path` / `current_win_path` / `window`. So the viewer's document lands on
`.drw` — and, before this was fixed, its brand with it: the ordinary editor canvas came
out `wave_viewer 1` permanently (nothing clears it, and unlike `readonly` it is not reset
by `clear_schematic`), so `.drw` was never a pristine-untitled reuse target again, even
after File>New. Measured A/B with a control, headless, both in windowed and tabbed mode.

Fixed by swapping `wave_viewer` back alongside the window paths in both functions; legs
`W-win` / `W-tab` guard it, and were confirmed red against a `HEAD` `src/xinit.c`. The
sibling flags (`readonly`, `no_grid`, `no_snap`, `graph_snap`) have exactly the same
surface-vs-document mismatch and were left alone deliberately — that is a bigger
behavioural claim than this issue supports; recorded in issue 0186.

## Residual risks (measured, filed, not fixed here)

* **`xschem reload` still wipes a viewer** and clears `readonly` as a side effect —
  issue 0186. Reproduced headless on the post-fix binary.
* **`xschem load -window <win>` and the in-place-hint loads** (`-inplace`, `-nodraw`, …)
  bypass the predicate by design and still land in place on a viewer — issue 0186.
* **`wviewer::open`'s own "did the context follow?" guard compares a value with itself**
  and can brand a live user schematic with all five flags — issue 0187, pre-existing, and
  reproduced both headless and under X.
* **CG9/CG10 need X.** Without a `DISPLAY`, `test_wave_clear_all` skips the whole CG block
  and still prints `RESULT: ALL PASS (3 checks)`; the file now prints an explicit NOTE
  saying the 0172 legs did not run. The headless guard is the one that runs everywhere.

## Cross-references

* `doc/claude/specs/waveform_viewer.md` — the `with_edit` / D1 read-only contract
  that makes `modified == 0` permanent.
* `doc/claude/specs/load_window_routing.md` — the reuse rule this predicate implements.
* `doc/claude/issues/0171-viewer-clear-all-ctrl-d.md` — the `Ctrl-D` that makes
  this destructive rather than cosmetic.
* `doc/claude/specs/graph_markers.md` §6.1.1 — the `Ctrl-E` that surfaced it.
