# 1614 — a failed SVG export leaves the user's grid switched off, and leaks `svg_colors`

**STAMP:** `v1 claim=open tree=5d7380b2 stamped=2026-09-27 fix=untried open=2 by=driver`

## The user-visible half

`svg_draw()` in `src/svgdraw.c` turns the grid off before drawing, so the exported picture has no
grid, and restores the user's setting on the way out:

```c
old_grid = tclgetboolvar("draw_grid");
tclsetvar("draw_grid", "0");
...
fclose(fd);
tclsetboolvar("draw_grid", old_grid);       /* the ONLY restore */
my_free(_ALLOC_ID_, &svg_colors);
my_free(_ALLOC_ID_, &unused_layer);
```

Between those two points it opens the plot file, and **both failure paths `return` without
restoring anything**:

```c
if(xctx->plotfile[0]) {
  fd = fopen(xctx->plotfile, "w");
  if(!fd) { dbg(0, "can not open file: %s\n", xctx->plotfile); return; }
} else {
  fd = fopen("plot.svg", "w");
  if(!fd) { dbg(0, "can not open file: %s\n", "plot.svg"); return; }
}
```

So **an export that fails switches the user's grid off and leaves it off.** Driven at `5d7380b2`,
headless, into a directory with mode 500:

```
PROBE before=1
can not open file: …/nowrite/out.svg
PROBE print rc=0 e=
PROBE after=0   (want 1)
PROBE file created: 0
```

Note `rc=0`: the verb reports success. The only sign anything went wrong is a `dbg(0, …)` line on
stderr — and in the GUI the visible consequence is the grid vanishing from the schematic, which
does not obviously point at a failed file write. A user who exports to a read-only directory, a
full disk or a stale network mount gets their canvas changed under them by a failure they may not
have noticed.

## The leak half

`svg_colors` is `my_calloc`'d **before** the `fopen`, and neither failure path frees it. Also
carried in this project's notes as the original finding; the grid is the more serious half and was
found while confirming the leak.

`unused_layer` is allocated *after* the `fopen`, so it is not affected.

## Open

1. **Restore-and-free on every exit, not two more copies of the cleanup.** Three exits need it now
   and a fourth will be added eventually; duplicating the tail is how one of them gets missed
   again. A single exit label, or hoisting the `fopen` above the grid change, are both candidates —
   **hoisting is the smaller change and removes the window entirely**, and it is worth checking
   whether anything between the two points depends on the grid already being off.
2. **Is `rc=0` on a failed export right?** That is a separate, arguably larger question about the
   `print` verb's contract and it is **not** in this issue's scope: a script that cannot tell
   whether its export succeeded is a different defect from a setting being clobbered. Needs its own
   number if it is taken up. ⚠ Do not quietly change the return value while fixing the grid — that
   would be a user-visible contract change riding along inside a bug fix.
