# 0186 — a waveform-viewer context is still destroyed by `xschem reload` and by the routing-exempt in-place loads

Status: **OPEN**. Filed 2026-07-31, spawned by the fix for
`doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md`.
**Re-measured and re-anchored 2026-08-03** (Signal Browser batch item 00) — still
reproduces verbatim; deferred there because it needs C. See "Re-measurement" below.

## Re-measurement, 2026-08-03 at `ccd5f30a`

Reproduced verbatim with the recipe in §1, `--nogui`, with a raw loaded as well:

```
before wv=1 ro=1 rects2=1 rawvars=424 rawpoints=20503
after  wv=1 ro=0 rects2=0 rawvars=424 rawpoints=20503
```

Three things this adds to the original filing:

* **the raw survives intact** — 424 vars / 20503 points before and after. The blast
  radius is the **graph-rect model**, not the loaded waveform data. Anything that
  derives its state from `xschem raw list` rather than from the rects is immune.
* **reload frees no Tk widget.** Measured under a real `DISPLAY` with a `frame
  $top.wvbrowser` packed `-side left -fill y -before $top.drw` and carrying a child:
  `sidebar=1 sidebar_packed=1 child=1 toplevel=1 drw=1` **both before and after**.
  `clear_drawing()` clears the C document model; it has no reach into the Tk widget
  tree. A viewer's widgets are not orphaned by a reload — they are left sitting on an
  empty document.
* **under X it also HANGS.** The original measurement was `--nogui`. Under a real
  `DISPLAY`, `load_schematic()`'s fopen-failure path runs `update; alert_ {Unable to
  open file: …}` (`src/save.c:3814`) — a **modal** with nobody to dismiss it. A
  scripted probe sat there until killed at 200 s. Whatever fixes this must account for
  the modal, not only for the model wipe.

### Line numbers re-anchored

* the `reload` branch has **moved** from `src/scheduler.c:9494` to **`:10036`**; its
  body at `:10039-10041` is still `unselect_all(1); remove_symbols();
  load_schematic(1, xctx->sch[xctx->currsch], 1, 1);` with no guard of any kind.
* `src/save.c:3734` (the `readonly = 0` reset), `:3810` (the fopen failure), `:3814`
  (the message) and `:3827` (`clear_drawing()`) are all still **exact**.

### Disposition

Deferred `[D]` by Signal Browser batch item 00, for two independent reasons:

1. it needs **C** at two families of site (`scheduler.c:10036` and the routing-exempt
   in-place loads), and that batch's decision 8 forbids new C. `src/xschem.tcl` holds
   only a `xschem reload` *caller* (`:13074`, plus `action_registry.tcl:183`), so no
   Tcl edit can close it;
2. its §2 is an **undecided design question by this document's own words** — the
   in-place loads are "arguably correct as it stands".

The split-out `readonly`-cleared-on-failed-load defect is still unfiled. Next free
issue number is **0212** (0188-0194 and 0200-0211 are taken).

Receipt: `doc/claude/signal_browser_batch/receipts/00_precondition.md`.

## What 0172 fixed, and what it did not

0172 closed the four doors through which an *open* could land a schematic in a live
waveform viewer: the three `is_pristine_untitled()` callers and `ask_new_file()`. The
predicate now refuses a `wave_viewer` context, and `ask_new_file()` forces its new-window
arm for one.

Two families of command still take a viewer context over, because neither goes anywhere
near that predicate.

## 1. `xschem reload` wipes the viewer (measured)

```tcl
xschem clear force
xschem set rectcolor 2
xschem rect 0 0 100 100 -1 "flags=graph,unlocked" 0
xschem set_modify 0
xschem set wave_viewer 1
xschem set readonly 1
xschem reload
```

```
before wv=1 ro=1 rects2=1
load_schematic(): unable to open file: .../untitled.sch
after  wv=1 ro=0 rects2=0
```

`--nogui`, 2026-07-31, against the post-0172 binary. Two separate defects in one line:

* **the graph rects are gone.** `reload` re-reads `xctx->sch[currsch]`, which for a viewer
  is `untitled.sch` — a file that does not exist — and `load_schematic()` calls
  `clear_drawing()` on the fopen-failure path, so the viewer's whole model is dropped and
  the window is left blank while `wviewer::windows` still lists it.
* **`readonly` is cleared as a side effect** (`save.c`, in `load_schematic()`), on a
  *failed* load. That is not viewer-specific: any read-only buffer whose file has been
  removed comes back writable. The viewer's D1 contract ("read-only for the window's
  life") is broken by a command the viewer never opted into.

Reachability: not from the viewer's own keyboard — `wviewer::key_filter` forwards only
ESC, `f`/`Z`/`Ctrl-z` and the `graphkeys` `{97 98 100 115 109 116 65 66 77}` — and the
viewer's File menu has only Close. It is reachable by typing `xschem reload` in the CIW
while the viewer holds the context, and by any Tcl that calls it.

## 2. The routing-exempt loads

`xschem load -window <winpath>` (an explicitly named target) and any load carrying an
in-place hint (`-inplace`, `-nodraw`, `-nofullzoom`, `-keep_symbols`, `-noundoreset`,
`-nosymbols`) never compute `route_newwin` and never consult `is_pristine_untitled()`, so
they load in place over a viewer.

This one is **arguably correct as it stands** and is why it is filed rather than fixed:
`-window` is the caller naming the target window explicitly, and the hint flags are the
documented contract for scripted/internal in-place loads
(`doc/claude/specs/load_window_routing.md`). The open question is only whether "explicit"
should still mean "explicit" when the target is a viewer.

## Suggested direction (not decided)

The cheap, honest version of both is a single guard rather than four: a
`wave_viewer`-aware refusal in the small number of C entry points that *replace* a
context's whole document (`load_schematic` in-place callers, `clear_drawing` from
`reload`), reported through `ciw_echo` the way `wviewer::open`'s own refusals are. The
separate `readonly`-cleared-on-failed-load defect should be split out and fixed on its own
merits — it affects ordinary read-only buffers, not just viewers.

## Cross-references

* `doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md` — the
  `wave_viewer` flag this would reuse, and the four doors already closed.
* `doc/claude/specs/waveform_viewer.md` — D1, the read-only-for-life contract.
* `doc/claude/specs/load_window_routing.md` — the in-place vs new-window rules.
