# 0680 — reproducible crash: descend two levels, then zoom in and out, on the user's real X server

Status: OPEN, **NOT YET REPRODUCED BY THE DRIVER**. Reported by the user 2026-08-24
as "very predictable". Awaiting the terminal stderr, which is the missing evidence.

## The user's report

> All I did was tb_bandgap descend x1 > x2 and then zoom in and out a few times.

and, importantly:

> the crash doesn't need me to annotate OP info - which is what I was doing before

So this is **not** an OP-annotation defect. It is in the ordinary descend + zoom path
and predates, or is independent of, everything on this branch.

## Evidence in hand

`/tmp/Xschem.log.2`, the action log, is a complete replay script and ends **mid
zoom-out with no error line**:

```
xschem load {.../sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch}
xschem descend -inst x1
xschem descend -inst x2
set draw_grid [expr {!$draw_grid}]; xschem redraw
xschem zoom_in    x15
xschem zoom_out   x8
...  (161 lines, stops abruptly)
```

## What the driver ruled OUT

**Replaying that log verbatim does NOT crash** — under `gdb`, on Xvfb `:99` and on
Xwayland `:0`, both reached `SURVIVED-REPLAY` with no stack.

**Because the action log records the COMMAND, not the EVENT.** A wheel or key zoom
enters through `callback()` with a real X event and drags hit-testing, cursor
tracking and hover repair with it; `xschem zoom_in` skips that entire path. Any
faithful reproduction needs synthetic X events (XTest) or the real server.

**The dmesg segfaults are NOT this crash.** The driver initially attributed them to
it; that was wrong. Measured: the most recent kernel segfault is ~2.5 h older than
the user's crash, and the 32 crashes in the buffer are the 0663/0664 crews' own
deliberate sharedir-farm sabotage runs. There is **no kernel record at the crash
time at all**, which means it was probably **not a SIGSEGV** — an Xlib protocol error
(`X Error of failed request` -> `exit(1)`) or an abort leaves no dmesg entry and
stops the log exactly like this.

**`/tmp/xschem_fltrace_876745.log` being empty says nothing.** `fltrace()`
(`src/move.c:2356`) opens its file the moment tracing is armed, and only ever writes
for wire/move/elbow/slide/placement events. Descend and zoom produce none. Empty is
the expected result of pointing a wire-editing instrument at a zoom crash — it is the
wrong instrument, not a clue.

## The missing evidence, and why

A windowed launch **detaches and `freopen()`s stderr to `/dev/null`** (`src/main.c`),
which is the same reason `fltrace` writes to its own file at all
(`src/move.c:2350-2353`). So an Xlib error message may already be going nowhere.

Next step is a foreground run with stderr captured:

```sh
cd /home/analog/dev/xschem-claude
src/xschem --script sky130A/cadence_style_rc --logdir /tmp 2>&1 | tee /tmp/xschem_stderr.txt
```

then reproduce: open `tb_bandgap`, descend `x1 > x2`, zoom in and out until it dies.

What the last lines discriminate:

| last line | meaning |
|---|---|
| `X Error of failed request: ...` | Xlib protocol error, `exit(1)`. Server-specific, which is why `:99` and `:0` survive |
| `Segmentation fault` from the shell | a real SIGSEGV that the kernel did not log |
| nothing at all | killed, or a clean `exit()` down some path |

## Open question the answer changes everything for

The user's `$DISPLAY` is the **Windows X server (HC-Consult) over TCP** — a different
server from both `:0` (Xwayland) and `:99` (Xvfb); see CLAUDE.md's three-server table.
If this is an Xlib protocol error, it may be reachable only there, and issue **0413**
(`backing_store=NotUseful`, look debt still open on that exact server) is in the same
neighbourhood: both are about what the real server does on expose/redraw.
