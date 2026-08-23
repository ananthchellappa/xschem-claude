# 0612 — an OP-annotation session kills VcXsrv, with 0413's fix active

STATUS: **OPEN — reproduced TWICE by the user on the real screen, 2026-08-22.**
Not reproducible on Xvfb. Related: **0413** (same symptom, different cause, marked
FIXED and its fix verified active here), 0457(b), spec §S9b.

---

## What happens

The **X server dies.** XSCHEM does not crash — it loses its connection to a
server that is no longer there:

```
X connection to 172.30.64.1:0 broken (explicit kill or server shutdown).
```

Measured immediately after, from the same machine:

```
port 6000            REFUSED            -> VcXsrv is down
DISPLAY=:99 (Xvfb)   still answers      -> the machine is healthy
XSCHEM_BACKING_STORE <unset>            -> 0413's fix WAS active
```

The user loses every X client on that server, not just XSCHEM.

## The two sequences that did it

Both on `sky130A/xschem_libs/sky130_tests_ase/bandgap_opamp` (13 FETs, two levels
inside `tb_bandgap`), launched with `sky130A/cadence_style_rc`, a 15.8 MB tran raw
loaded and `cursor2_x` at 20 µs.

**Run 1.** `6` (annotation on) → `Alt-6` → `Ctrl-6` → `Ctrl-X` up a level →
descend back → `Ctrl-6` → **server dies**.

**Run 2, sharper.** descend → `6` (annotation on) → `Ctrl-E`
(`cadence::return_one_level`) → *select an instance to descend into* →
**server dies**.

The common element is: **annotation has been ON, then a hierarchy change, then a
redraw.**

## What is NOT the cause — measured, so nobody re-walks these

* **Not an XSCHEM crash.** No SIGSEGV, no `FATAL: signal`, no emergency save. The
  process died because its server did.
* **Not 0413's backing store.** `XSCHEM_BACKING_STORE` was unset, so
  `src/xinit.c:3609` applied `NotUseful`, which is the whole of 0413's fix.
* **Not a stale overlay cache.** The first hypothesis was that
  `annot_cache` survives a level change and draws the child's blocks against the
  parent's instance array. It does not: `clear_drawing()` calls
  `annot_data_changed()` (`src/actions.c:2321`) and its comment names descend and
  ascend explicitly. The apparent evidence — `xschem get annot_overlay_count`
  reading **13** at the parent level where no instance is annotatable — was a
  misreading: that counter is **monotonic** (`src/actions.c:1261-1263`), a session
  running total, not a per-frame count.
* **Not reproducible under Xvfb.** The exact Run-2 sequence, scripted, plus
  selecting all 115 instances on the returned-to level with a redraw each:
  `REPRO413B SURVIVED`, `:99` still alive. A virtual server is far more robust
  than this one; absence here is not evidence of absence there.

## Why this is worth a number of its own rather than reopening 0413

0413's cause was a specific request (`backing_store = WhenMapped`) and its fix is
verified present and active. This is a different path to the same outcome, and the
family it belongs to — *XSCHEM can issue something that takes this server down* —
now has two members. That is the argument for treating the server's fragility as a
class rather than as one bug.

## What is owed, and the cheapest next step is NOT ours

**The VcXsrv log names the failing request.** VcXsrv writes a log on the Windows
side; the last entries before it exits should identify the request that killed it.
That is a manual step only the user can take, and it is worth far more than
further guessing from the Linux side.

Failing that, a bisect against the real server — each iteration costs the user
their X session, so it needs consent and should be scripted to run the sequence
unattended and report how far it got.

## The reproducer, scripted

`<scratch>/bg/repro413b.tcl` runs Run 2 headlessly and reports each step. It
survives on Xvfb; point it at the real server to reproduce.


---

# 2026-08-22, ROUND 2 — the server's own log, and what it eliminates

## The server names the failure

VcXsrv writes `%LOCALAPPDATA%\Temp\VCXSrv.0.log` (readable from WSL at
`/mnt/c/Users/<user>/AppData/Local/Temp/`). Two crashed runs:

```
run A   239 x  winCreateDIB: CreateDIBSection() failed   +  4 x BitBlt failed: 0x6
run B  2376 x  winCreateDIB: CreateDIBSection() failed   + 26 x BitBlt failed
run C   529 x  winCreateDIB: CreateDIBSection() failed   +  4 x BitBlt failed
```

A healthy server in between: **0**. `CreateDIBSection` is how VcXsrv allocates a
pixmap; `0x6` is `ERROR_INVALID_HANDLE`. The server runs out of GDI resources,
limps, and dies when a shadow blit finally fails. **XSCHEM does not crash — it
loses a server that is no longer there**, which is why there is never a signal or
an emergency save.

The user's description matches exactly: *"it stops responding to mouse movement,
then VcXsrv crashes."* The stall is XSCHEM waiting on a server that can no longer
allocate.

## THE FAILURES START ON THE FIRST LINE AFTER STARTUP

Run C, with the server started fresh:

```
line 52  Using Composite redirection          <- last startup line, baseline
line 53  winCreateDIB: CreateDIBSection() failed
```

**Not a slow accumulation.** Whatever is wrong is wrong from the moment XSCHEM
connects. That argues against simple exhaustion-over-time and toward either a
degenerate request or a server-side condition present from the start.

## `-logverbose 3` buys NOTHING at runtime

The user restarted VcXsrv with `-logverbose 3`. It only expands the **startup**
`(II)` lines; the runtime log is unchanged. Do not spend another crash on it.

## ELIMINATED — measured, so nobody re-walks these

**1. `ConfigureNotify` / `resetwin` churn.** `callback.c:10079` frees and
recreates the window pixmap on every ConfigureNotify, and CLAUDE.md records that a
real server emits 3 Configure events where Xvfb emits 1 — a good story. It is
wrong. XSCHEM run under `-d 1` through a full crashing session:

```
XSCHEM:  9 pixmap recreations (18 resetwin calls, 8 ConfigureNotify)
VcXsrv:  529 CreateDIBSection failures
```

Nine asks cannot produce 529 failures.

**2. XSCHEM leaking drawables.** An `LD_PRELOAD` counter
(`<scratch>/xcount.c`, build with `gcc -shared -fPIC -o xcount.so xcount.c -ldl`)
over the full motion + hierarchy + resize storm:

```
XCreatePixmap  168    XFreePixmap  191    outstanding -23
XCreateWindow  174
XRenderCreatePicture 266   XRenderFreePicture 267
XRenderCreateGlyphSet 27
```

Balanced and modest. No pixmap leak, no picture leak.

**3. Cairo allocating behind XSCHEM's back via XCB.** Cairo links
`libxcb-render` and `libxcb-shm`, so its Render path could bypass Xlib entirely
and be invisible to the counter above. A second shim (`<scratch>/xcount2.c`)
wrapping `xcb_create_pixmap`, `xcb_shm_create_pixmap`, `xcb_shm_attach`,
`xcb_render_create_picture` and `xcb_render_create_glyph_set` **never fired at
all** — this cairo uses the Xlib backend, which shim 1 already counted.

**4. The scripted sequence, motion, and resize** — all run against the real
server, all `+0` DIB failures, server survived:

* the exact Run-2 sequence, step by step, with the log polled after each step;
* 720 synthesised `<Motion>` events with the crosshair armed and annotation on;
* 100 window resizes (the one place XSCHEM recreates its pixmap).

Note the limit of the third: synthesised motion does not move the real pointer, so
anything keyed on `XQueryPointer` may not fire. Absence there is weak evidence.

## Where this leaves it

XSCHEM's request volume is unremarkable and its allocation is balanced. The
server fails to allocate from its first post-startup moment. That points at the
**server's configuration** rather than at request volume, and the user's own
startup line is the obvious lever:

```
"C:\Program Files\VcXsrv\vcxsrv.exe" :0 -multiwindow -clipboard -wgl -ac -logverbose 3
```

Two experiments, one variable at a time, both user-side:

* **`-nowgl`** — drops native WGL/AIGLX. The startup log spends 20 lines on GL
  and reports `670 pixel formats`; GL contexts consume GDI resources, and XSCHEM
  uses no OpenGL. Cheapest test with the highest prior.
* **`-multiwindow` off** — in multiwindow mode every X window becomes a Windows
  window with its own DIB, and the counter above shows **174 X windows created**
  in one session. A single-desktop server allocates completely differently.

If `-nowgl` stops it, the bug is a VcXsrv/driver interaction and XSCHEM's only
duty is to document it. If neither helps, the next instrument is a request-level
trace (`xtrace` is not installed here) or `-logfile` with a debug VcXsrv build.
