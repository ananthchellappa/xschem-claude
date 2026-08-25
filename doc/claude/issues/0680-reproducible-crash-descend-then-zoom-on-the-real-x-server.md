# 0680 — reproducible crash: descend two levels, then zoom in and out, on the user's real X server

Status: **RESOLVED — NOT AN XSCHEM DEFECT.** The X SERVER crashes; xschem dies as
collateral. Root-caused 2026-08-24 from the user's `_XIOError` backtrace plus eight
VcXsrv crash dumps on the Windows side. Kept open only until the user confirms the
VcXsrv configuration change holds.

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

### ⚠ THE OBVIOUS CAPTURE RECIPE DEFEATS ITSELF. MEASURED.

The driver told the user to run `... 2>&1 | tee /tmp/xschem_stderr.txt`. The file came
back **empty**, and the shell did not print `Segmentation fault` either. That is not a
failed capture, it is the capture *causing* the problem:

```c
/* src/main.c:105-113 */
if(!fstat(0, &statbuf)) {
   if(statbuf.st_mode & S_IFIFO) stdin_is_a_fifo = 1;   /* tests STDIN */
}
if(!stdin_is_a_fifo && getpgrp() != tcgetpgrp(STDOUT_FILENO) && !cli_opt_no_readline) {
  cli_opt_detach = 1;                    /* -> freopen("/dev/null", "w", stderr) at :135 */
}
```

`stdin_is_a_fifo` tests **stdin**; a `| tee` pipes **stdout**, so stdin stays the
terminal and the flag is 0. And `tcgetpgrp()` on a **pipe** returns **-1**, so
`getpgrp() != -1` is true. Both conditions hold, xschem detaches, and stderr is
`/dev/null` before a single X error can print. The detach also stops the process being
the shell's child, which is why bash never reported the death either.

**So piping stdout is exactly the wrong move for this bug.** Two runs were spent on it.

The escape is `-r` / `--no_readline` (`src/options.c:50`), which is the third term of
the condition, or simply not piping stdout at all.

### The recipe that works

```sh
cd /home/analog/dev/xschem-claude
gdb -q -ex 'set pagination off' -ex 'break _XError' -ex 'break _XIOError' -ex run \
    --args src/xschem -r --script sky130A/cadence_style_rc --logdir /tmp
```

`_XError` and `_XIOError` are both present in this box's `libX11.so.6` (verified), so
the breakpoints catch a protocol error and an I/O error *before* Xlib's handler can
exit. gdb stops on SIGSEGV by itself. Either way, `bt` at the prompt gives the stack.

then reproduce: open `tb_bandgap`, descend `x1 > x2`, zoom in and out until it dies.

What the last lines discriminate:

| last line | meaning |
|---|---|
| `X Error of failed request: ...` | Xlib protocol error, `exit(1)`. Server-specific, which is why `:99` and `:0` survive |
| `Segmentation fault` from the shell | a real SIGSEGV that the kernel did not log |
| nothing at all | killed, or a clean `exit()` down some path |

## Second run, same shape, still no kernel record

The user reproduced again with the (defeated) capture in place. `/tmp/Xschem.log.7`,
249 lines, ends mid `zoom_out` exactly like the first. **dmesg still shows no
segfault at either crash time** — the newest kernel record is over three hours older
and belongs to the 0663/0664 crews' sabotage runs.

Twice now, no kernel record. A SIGSEGV is logged by this kernel (32 of the crews' own
are in the buffer), so the absence is evidence, not a gap: this is most likely an
Xlib-level exit rather than a signal.

The user also confirmed: **ASE-L was never launched.** The crash needs only load,
descend twice, zoom.

## Open question the answer changes everything for

The user's `$DISPLAY` is the **Windows X server (HC-Consult) over TCP** — a different
server from both `:0` (Xwayland) and `:99` (Xvfb); see CLAUDE.md's three-server table.
If this is an Xlib protocol error, it may be reachable only there, and issue **0413**
(`backing_store=NotUseful`, look debt still open on that exact server) is in the same
neighbourhood: both are about what the real server does on expose/redraw.


## ROOT CAUSE, 2026-08-24 — VcXsrv is crashing, not xschem

The user's gdb backtrace stopped at **`_XIOError`**, not `_XError`. That distinction
is the whole answer: `_XError` is a protocol error (a bad request WE sent), while
`_XIOError` is **connection loss** — Xlib discovering the socket to the server is
gone. Its default handler prints `XIO: fatal IO error ...` and calls `exit(1)`, which
is exactly why there was never a signal, never a core, and never a dmesg entry.

```
#0  _XIOError              libX11
#1  _XReply                libX11
#2  XSync                  libX11
#3  Tk_DeleteErrorHandler  libtk
#4  Tk_DrawChars           libtk
#5-7 ??                    libtk
#8  TclServiceIdle         libtcl
#9  Tcl_DoOneEvent         libtcl
#10 Tk_MainLoop            libtk
#11 Tk_MainEx              libtk
#12 main                   main.c:148
```

**Not one xschem frame.** The tree had just been rebuilt with `-g` specifically to
resolve our frames, and there were none to resolve.

⚠ **`Tk_DrawChars` is a red herring, and chasing it would cost a day.** With an I/O
error the frame that DETECTS the loss is not the frame that CAUSED it — X is
asynchronous, so `XSync` here is merely the first place that tried to read a reply
and found the socket dead. Tk was doing an unrelated idle text redraw.

### The Windows-side evidence, one dump per crash

`/mnt/c/Users/anant/AppData/Local/CrashDumps/`:

```
vcxsrv.exe.27036.dmp   15:45     Xschem.log.7   15:45
vcxsrv.exe.14572.dmp   15:52     Xschem.log.8   15:52
vcxsrv.exe.19360.dmp   15:55     Xschem.log.9   15:55
vcxsrv.exe.29624.dmp   15:56     fltrace log    15:56
vcxsrv.exe.13336.dmp   15:57     Xschem.log.2   15:57
vcxsrv.exe.23736.dmp   16:38
vcxsrv.exe.14164.dmp   17:02     the gdb run
```

Eight dumps, exact 1:1 correspondence with every xschem log that ends mid-zoom. The
server dies; xschem notices and exits cleanly. Every "xschem crash" on this bench was
this.

### Why it survived on :99 and :0

Not a timing accident and not the scripted-vs-event difference the earlier sections
guessed at: **Xvfb and Xwayland simply are not the process that was crashing.** See
CLAUDE.md's three-server table — `$DISPLAY` is VcXsrv over TCP and is a wholly
separate program from the other two.

### The suspect configuration

`C:\Users\anant\Documents\config.xlaunch`:

```xml
WindowMode="MultiWindow"  Wgl="True"  DisableAC="True"  Clipboard="True"
```

`Wgl="True"` is Native OpenGL, and two measurements indict it:

* the server's own log falls back to software GL regardless — `IGLX: Loaded and
  initialized swrast`, `GLX: Initialized DRISWRAST GL provider` — so `-wgl` is buying
  nothing here;
* the dumps carry **`nvcontainer.exe`, `nvsphelper64.exe`, `nvxdsync.exe`**, i.e.
  NVIDIA's ICD loaded into the VcXsrv process, which `-wgl` is what pulls in.

**xschem uses no GLX at all** (Xlib plus optional Cairo, all software), so turning it
off costs nothing.

Secondary suspect if that does not settle it: `MultiWindow` plus `Using Composite
redirection` (also in the server log), with `winMultiWindowWMProc - Error code: 3
(Window), Major opcode: 18 (ChangeProperty)` in `vcxsrv_dbg.log`.

A no-Native-GL launcher was written to `config_nowgl.xlaunch` beside the original,
which was left untouched. One attribute differs.

### Verification is objective, not a feeling

The dump directory is the oracle: reproduce hard, then check whether a **new**
`vcxsrv.exe.*.dmp` appeared. "It felt stable" is not the test.

## What this invalidates in the sections above

* The "capture recipe defeats itself" finding about `| tee` and `cli_opt_detach`
  **stands** and is worth keeping — it is a real trap and cost two runs.
* The plan to force `XSynchronize` and hunt a bad request **is moot**. There is no bad
  request; there is a dying server.
* The driver's speculation that the action-log replay failed to reproduce "because the
  log records the command, not the event" was **plausible but not the reason**. The
  reason is that `:99` and `:0` are different servers that do not crash.

---

## 2026-08-24 17:51 — the server log names the failure, and it is not GL

Crash #10 landed at 17:49 (`vcxsrv.exe.24188.dmp`). VcXsrv rotates its log on
restart, so the crashing run survives verbatim as
`/mnt/c/Users/anant/AppData/Local/Temp/VCXSrv.0.log.old`. Its tail:

```
Using Composite redirection
winCreateDIB: CreateDIBSection() failed        <- x27
winBltExposedWindowRegionShadowGDI - BitBlt failed: 0x6
winCreateDIB: CreateDIBSection() failed
```

Then the process is gone. That is the whole story of the run: everything before
`Using Composite redirection` is ordinary startup, and every line after it is a
GDI allocation failing.

* `CreateDIBSection()` is the Win32 call that allocates a device-independent
  bitmap. Under `-compositewm` VcXsrv allocates one per redirected window and
  reallocates on resize. Zooming a schematic churns the backing pixmap.
* `BitBlt failed: 0x6` is `ERROR_INVALID_HANDLE` — the blit is reading the DIB
  that the preceding `CreateDIBSection` failed to produce. So the server keeps
  running against a null handle for a few frames and then dies.

**This displaces the earlier `Wgl="True"` hypothesis, which a test had already
disproven.** It also corrects a claim made in this file from the Aug-15
`vcxsrv_dbg.log`: that GL was falling back to `swrast`. Both the crashing run and
the current one print

```
(II) 670 pixel formats reported by wglGetPixelFormatAttribivARB
(II) GLX: Initialized Win32 native WGL GL provider for screen 0
```

— native WGL, not software. The `IGLX: swrast` lines belong to a *different*
configuration from Aug 15 and should not have been carried forward as evidence
about this crash.

### The single-variable test now running

Server restarted 17:50 with the user's original flags plus one addition:

```
-multiwindow -clipboard -primary -ac -wgl -nocompositewm
```

`-nocompositewm` is independent of `-multiwindow` (confirmed against the flag
list), so multi-window mode is retained — the user's normal working layout is
unchanged, which matters because a config they would not actually use cannot
falsify anything about the config they do.

Confirmation the flag took: the new `VCXSrv.0.log` has **no** `Using Composite
redirection` line.

Falsification plan, one variable per round:

| round | change from the user's original | predicted if DIB churn is the cause |
|---|---|---|
| 1 | `+ -nocompositewm` | survives |
| 2 | back to `-compositewm` alone | crashes again (positive control) |
| 3 | `-swcursor` | no effect |

Round 2 is not optional. A survival in round 1 with no positive control is the
same shape of non-result as the four invalid drive attempts recorded above.
