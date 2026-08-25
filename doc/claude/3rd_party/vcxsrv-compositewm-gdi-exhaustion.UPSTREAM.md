## Workaround, for anyone arriving with this symptom

Add `-nocompositewm` to the VcXsrv command line. It is **independent of
`-multiwindow`**, so multi-window mode and native WGL are both retained. Via
XLaunch, put it in `ExtraParams`:

```xml
<XLaunch WindowMode="MultiWindow" ... ExtraParams="-nocompositewm" Wgl="True" .../>
```

The visible cost is that occluded top-level windows no longer render correctly in
Taskbar / Task-Switcher previews, which is what composite redirection buys.

---

## Summary

With composite redirection active, a client performing sustained full-window
redraws drives `CreateDIBSection()` to fail repeatedly; the server then blits
against bitmap handles it never received (`BitBlt failed: 0x6`,
`ERROR_INVALID_HANDLE`) and terminates. The X client sees connection loss and
exits normally, so the crash looks like a client bug until the server log is read.

Toggling the one flag toggles the crash, in both directions, on the same workload.

## Environment

| | |
|---|---|
| VcXsrv | **21.1.16.1** (`vcxsrv.exe` dated 2025-03-10) |
| Windows | 10.0.26200.9168 (64-bit) |
| GL provider | native WGL — `(II) GLX: Initialized Win32 native WGL GL provider for screen 0` |
| Client | XSCHEM (Xlib + Cairo schematic editor) running under WSL2, kernel 5.15.167.4-microsoft-standard-WSL2, connecting over TCP |
| Crashing flags | `-multiwindow -clipboard -primary -ac -wgl` |
| Surviving flags | `-multiwindow -clipboard -primary -ac -wgl -nocompositewm` |

## Reproduction

1. Start VcXsrv with `-multiwindow -clipboard -primary -ac -wgl` (composite
   redirection is on by default in this mode).
2. From a WSL2 shell with `DISPLAY` pointing at the Windows host, run an X client
   that repeatedly repaints its whole canvas. In our case: open a schematic in
   XSCHEM, descend two levels of hierarchy, then zoom in and out continuously with
   the scroll wheel.
3. Within roughly one to three minutes the server exits and a
   `vcxsrv.exe.<pid>.dmp` appears in `%LOCALAPPDATA%\CrashDumps`.

**Ten crashes in one afternoon**, at 15:45, 15:52, 15:55, 15:56, 15:57, 16:38,
17:02, 17:24, 17:49, 18:06 — reproducible on demand, by hand, every time the flag
is present.

The same workload on WSLg's Xwayland and on Xvfb never reproduces it.

## Evidence — the flag toggles the crash both ways

Three runs, same schematic, same hand-driven zoom, same machine, within 20 minutes:

| log line | run A: composite (17:49) | run B: **`-nocompositewm`** | run C: composite restored (18:06) |
|---|---|---|---|
| `Using Composite redirection` | 1 | **0** | 1 |
| `winCreateDIB: CreateDIBSection() failed` | 27 | **0** | **1303** |
| `winBltExposedWindowRegionShadowGDI - BitBlt failed: 0x6` | 2 | **0** | **15** |
| server afterwards | **dead** | **alive** | **dead** |
| new crash dump | yes | **no** | yes |

Run B is the negative, run C the positive control. Run B was not merely quieter —
it produced **zero** allocation failures across a full working session.

### Log excerpt, run C (1398 lines total)

Startup is unremarkable through line 27. Then:

```
 28: Using Composite redirection
 81: winCreateDIB: CreateDIBSection() failed
 82: winCreateDIB: CreateDIBSection() failed
     ... 1303 occurrences ...
152: winBltExposedWindowRegionShadowGDI - BitBlt failed: 0x6
     ...
     winCreateDIB: CreateDIBSection() failed        <- last line before exit
```

Note that the server **keeps running for over a thousand failed allocations**
before dying. Whatever calls `winCreateDIB` here does not appear to check its
result — `winBltExposedWindowRegionShadowGDI` is still issuing blits against the
handles those calls failed to produce, which is what `0x6`
(`ERROR_INVALID_HANDLE`) is reporting. **A failed `CreateDIBSection()` looks like
it should be a bailout, not a warning.**

### Not implicated

`winMultiWindowWMProc - Error code: 3 (Window)` appears 35 times in run B, the run
that survived. It is ambient noise in `-multiwindow` mode and should not be read
as part of this failure. We initially took it as corroborating evidence and were
wrong.

## What we have proven, and what we have not

**Proven**: the presence of composite redirection is necessary for the failure on
this workload, and sufficient to bring it back once removed. Both directions,
controlled.

**Not proven**: the allocation path that exhausts the resource. Our first
hypothesis was per-window DIB reallocation on resize, but **the client does not
resize its window while zooming** — we checked its source: it recreates its
backing pixmap only when the drawable's dimensions change, and a separate
allocation audit in that codebase records `XCreatePixmap 2795 / XFreePixmap 2761`,
i.e. no client-side leak. So the churn is more likely in the server's own
per-window backing store, or in glyph/pixmap handling under redirection, and we
are not going to guess further in a bug report.

**Now measured** — see the next section. It is a **burst, not a slow leak**, and
it terminates at exactly the documented per-process GDI ceiling.

## The GDI curve, measured 2026-08-24 18:22–18:23

`GetGuiResources(hProcess, GR_GDIOBJECTS)` sampled against `vcxsrv.exe` at 2 Hz
across a full crash, from idle through death. The registry ceiling on this machine
is the Windows default:

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows
    GDIProcessHandleQuota    REG_DWORD    0x2710      (= 10000)
```

### Two regimes, and the boundary is sharp

| phase | wall clock | GDI objects | behaviour |
|---|---|---|---|
| idle, no client | 18:22:47 | **22** | — |
| client attached, ordinary use | 18:22:50 – 18:23:09 (**22 s**) | 217 → **507** | **bounded**; oscillates ±1 around 502–507, i.e. allocation and release are balanced |
| sustained redraw | 18:23:09 – 18:23:20 (**11 s**) | 507 → **10000** | **monotonic**; not one release in the entire climb |
| process gone | 18:23:23 | — | new crash dump written |

Raw deltas over the runaway phase (2 Hz, `+n` = objects gained since previous sample):

```
18:23:09    507
18:23:09   1180   +673
18:23:10   1274    +94
18:23:10   1350    +76
18:23:11   1727   +377
18:23:12   2352   +625
18:23:13   3581  +1229
18:23:13   4658  +1077
18:23:14   5494   +836
18:23:15   5992   +335
18:23:15   6644   +652
18:23:16   7349   +705
18:23:16   7928   +579
18:23:17   8323   +395
18:23:18   8646   +163
18:23:19   9151   +486
18:23:19   9514   +363
18:23:20   9662   +148
18:23:20  10000   +338      <- ceiling, exactly
```

Roughly **860 GDI objects per second, sustained, with zero releases**, from a
healthy steady state of ~500.

### Three things this settles

1. **It is not a gradual leak.** The server sat at a flat ~500 for 22 seconds of
   ordinary interaction, releasing as fast as it allocated. Whatever the redraw
   path does, it takes a different branch — one with no matching free.
2. **It is GDI specifically.** `GR_USEROBJECTS` stayed flat at **45–48** and the
   kernel handle count peaked at **613** across the whole run. Only the GDI pool
   moves.
3. **`CreateDIBSection() failed` is the symptom, not the cause.** In this run the
   log carries 74 of them, first at line 30 — they begin *after* the pool is
   exhausted. The 1303 seen in an earlier uninstrumented run is just a longer
   tail. **The bug to find is whatever allocated ~9500 GDI objects in 11 seconds
   without freeing one**, not the allocation that eventually failed.

Sample data and all three server logs were kept and can be attached on request.

## Available on request

Minidumps (2.9–5.0 MB each), the 1398-line log of the uninstrumented crashing
run, the 108-line log of the instrumented one, the clean log of the surviving run,
and the raw 2 Hz GDI sample CSV. **Not attached here**: dumps of an X
server carry window titles and possibly window contents, so they should be
reviewed before being handed to anyone.

## Prior art

I searched before filing; these look related but are not the same defect:

- [Bug #3 — Resizing in multiwindow mode crashes vcxsrv](https://sourceforge.net/p/vcxsrv/bugs/3/) — fixed in 1.9.4.1, and resize-driven, which this is not.
- [Bug #136 — vcxsrv crash in multiwindow mode](https://sourceforge.net/p/vcxsrv/bugs/136/) — crashes around screen lock/unlock.
- [Bug #161 — Restart problems after vcxsrv crash](https://sourceforge.net/p/vcxsrv/bugs/161/)
- [Issue #25 — Crash dump](https://github.com/marchaesen/vcxsrv/issues/25)

None names `CreateDIBSection` exhaustion under sustained redraw, and none reports
the `-nocompositewm` toggle as a fix.
