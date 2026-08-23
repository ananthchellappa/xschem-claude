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


---

# ROUND 3 — the allocator is IDENTIFIED, and it is not XSCHEM

A crash-proof counter (`tools/debug/xcount.c`, dumping continuously to a per-PID
file so the totals survive the process dying with its server) run against the
real VcXsrv through a full crashing session:

```
XCreatePixmap          2795      XSCHEM's own resetwin() asked for 5 of these
XFreePixmap            2761
outstanding              34      <- identical to the value at startup
XCreateWindow           204
XRenderCreatePicture   3050      freed 3048
XRenderCreateGlyphSet   137      (27 on Xvfb)
VcXsrv: 682 CreateDIBSection failures
```

**XSCHEM does not leak.** Outstanding was 34 at startup and 34 at death. The
client is balanced. What kills the server is **churn**: ~2800 pixmap
create/destroy cycles and ~3050 Render pictures in one session. Windows frees DIB
sections lazily, so that rate fragments the GDI heap until `CreateDIBSection()`
begins failing and VcXsrv exits.

**The allocator is cairo, not XSCHEM.** 2790 of the 2795 pixmaps were requested
by the cairo Xlib backend, not by any XSCHEM call.

## The server-side comparison that matters

```
                        Xvfb (:99)        VcXsrv
startup                 ~106 pixmaps      367 pixmaps
full session            ~110 pixmaps      2795 pixmaps
glyph sets                27              137
```

Startup alone on VcXsrv allocates more than an entire storm does on Xvfb. That is
the signature of a **rendering fallback**: cairo compensating for a Render
implementation that cannot serve an operation natively, by building intermediate
surfaces. Xvfb's Render is complete, so the fallback never engages there — which
is exactly why no scripted reproduction on `:99` has ever worked, and why
`AUDIT_DISPLAY=:0` (Xwayland, a third server) would not reproduce it either.

## A HYPOTHESIS THAT WAS WRONG, recorded so it is not re-tried

`draw_annot_overlay()` created and destroyed a cairo toy font face **per
annotated instance per frame** (~13x/frame on this sheet). The theory was that
`cairo_font_face_destroy()` dropped the last reference, invalidating the
server-side glyph set and forcing continuous re-upload — which fitted the 27 ->
137 glyph-set rise, the annotation-only trigger, and the correlation with motion.

**Measured false.** A/B on Xvfb, 100 annotated redraws: 100 vs 110
`XCreatePixmap`, **27 vs 27 glyph sets**. Again over 60 zoom in/out cycles (to
catch the zoom-dependent font size at `draw.c:475`): 35 with annotation on, 33
with it off. `cairo_toy_font_face_create()` hits cairo's own toy-face cache, so
the original pair was already nearly free.

The hoist was kept as hygiene — strictly less work per frame — and `src/draw.c`
says in terms that it does **not** close this issue.

## Also eliminated this round

* **`-nowgl`.** The user restarted VcXsrv without native WGL (verified: GL startup
  lines 20 -> 3, `DRISWRAST` instead of `Win32 native WGL`). Crashed anyway, 1319
  failures against 7 XSCHEM pixmap recreations.
* **`draw_crosshair`.** It is the last XSCHEM call in *both* crash logs and ran
  1259 times against 1319 failures — a compelling correlation. It allocates
  nothing: `erase_crosshair()` uses `MyXCopyArea` from `save_pixmap`. It
  correlates with motion because everything does.

## What is left, and it is no longer an XSCHEM bug hunt

The remaining question is **which Render operation cairo cannot do natively on
VcXsrv**, and that is answerable only against that server. Options:

1. `-multiwindow` off — the one startup flag not yet varied. 204 X windows were
   created in the measured session, and in multiwindow mode each becomes a
   Windows window with its own DIB.
2. A different Windows X server (X410, MobaXterm, or WSLg's own `:0`) — if the
   churn does not kill those, the defect is VcXsrv's.
3. Build XSCHEM with `HAS_CAIRO=0` — removes the allocator entirely, at the cost
   of anti-aliased text. A diagnostic, not a shipping answer.

**XSCHEM's own duty is discharged**: no leak, balanced allocation, and its direct
requests (5 pixmaps) are three orders of magnitude below the failure count.
