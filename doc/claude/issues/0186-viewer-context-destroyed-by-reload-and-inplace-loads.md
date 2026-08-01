# 0186 — a waveform-viewer context is still destroyed by `xschem reload` and by the routing-exempt in-place loads

Status: **OPEN**. Filed 2026-07-31, spawned by the fix for
`doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md`.

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
