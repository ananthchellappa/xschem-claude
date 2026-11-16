# 1719 — `xschem rect`, `xschem line` and `xschem wire` take a position argument that nothing bounds, so a position past the end or below -1 writes outside the object array

**STAMP:** `v1 claim=open tree=e6b38ba83 stamped=2026-11-15 fix=untried open=1 scope=scripted by=drag_perf-D3`

Found by the selection-look batch's crew in an old fixture of `test_grid_toggle_sel_gc`, which
called `xschem rect 4 0 0 100 100` meaning layer 4. The verb has no layer argument (its usage is
`rect [x1 y1 x2 y2] [pos] [propstring] [draw]`, and the layer is `xctx->rectcolor`), so `100`
became the position and the run aborted at exit with rc 134. The fixture was corrected there; the
product is unchanged. Confirmed and measured while filing, on the base build `e6b38ba83`,
headless. **Present on the base build.** Reached only by a script or the command line (no GUI
path passes a position). Filed, not fixed. Whether upstream xschem shares it was not checked.

## Smallest reproduction

```sh
printf 'xschem rect 0 0 100 100 100\nexit 0\n' > /tmp/r.tcl
env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script /tmp/r.tcl     # rc 134
env -u DISPLAY valgrind -q ./src/xschem --nogui --pipe -q --nolog --script /tmp/r.tcl
```

The plain run prints `double free or corruption (!prev)` and exits 134. Under `valgrind -q` (with
`env` first, so valgrind traces xschem and not `env`), the first report is an `Invalid write of
size 8` in `storeobject` (`src/store.c`) called from `xschem_cmds_r` (`src/scheduler.c`), whose
address valgrind places outside any live block (`24 bytes before a block of size 8,000 alloc'd`).

## Measured while filing

Each verb drawn once on an empty sheet at `10 20 110 120` with the position shown, then saved and
the saved records read back. "file" is what the saved sheet holds for that object type:

| call | plain rc | valgrind reports | file |
|---|---|---|---|
| `rect … 1` (layer empty) | 0 | none | `B 4 0 0 0 0 {}`: a zero rectangle, the real one lost |
| `rect … 100` | 134 | 3 invalid writes, 1 invalid read | `B 4 0 0 0 0 {}` |
| `rect … 100000` | 0 | none | `B 4 0 0 0 0 {}` |
| `rect … -5` | 134 | invalid reads and writes (25 reports) | garbage coordinates (`4.56e+257 …`) |
| `line … 1` | 0 | none | `L 4 0 0 0 0 {}` |
| `line … 100` | 134 | 3 invalid writes, 1 invalid read | `L 4 0 0 0 0 {}` |
| `line … 100000` | 1 | invalid reads and writes (8 reports) | not saved |
| `line … -5` | 134 | invalid reads and writes (10 reports) | `L 4 0 0 0 0 {}` |
| `wire … 1` | 0 | none | `N 0 0 0 0 {}` |
| `wire … 100` | 0 | none | `N 0 0 0 0 {}` |
| `wire … 100000` | 0 | invalid reads and writes (16 reports) | `N 0 0 0 0 {}` |
| `wire … -5` | 1 | invalid reads and writes, uninitialised-value jumps (21 reports) | not saved |

So a position inside the array's spare capacity but past its count leaves the slot at the count
unwritten (the file gets a zero object) and stores the real one beyond the count, where it is
lost, with no report from any tool; a position further out, or below -1, writes outside the array.
Valgrind reported that for every such call except `rect … 100000`, where the write landed
somewhere neither the run nor valgrind noticed.

## Cause (by reading code)

- `rect` in `xschem_cmds_r`, `line` in `xschem_cmds_l` and `wire` in `xschem_cmds_w`
  (`src/scheduler.c`) each read the position with a bare `if(argc > 6) pos=atoi(argv[6]);` and
  pass it to `storeobject()`.
- `storeobject()` (`src/store.c`: its LINE and xRECT arms, and `wire_store()` for WIRE) uses it as
  given:
  `if(pos==-1) n=<count>; else { for(j=<count>;j>pos;j--) <shift>; n=pos; }`.
  `check_line_storage()` / `check_box_storage()` / `check_wire_storage()` only make room for one
  more object at the end, so `n` is never checked against the count or the capacity.
- **The missing check:** a position must be `-1` or `0 <= pos <= count`, where count is
  `xctx->rects[xctx->rectcolor]`, `xctx->lines[xctx->rectcolor]` or `xctx->wires`. Nothing enforces
  it, in the verbs or in the store functions.

## Open item

1. Refuse an out-of-range position with a Tcl error in the three verbs (and, defensively, clamp
   or refuse it in `storeobject()` / `wire_store()`, whose other callers pass -1 or an index they
   computed). Not built.
