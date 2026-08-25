# VcXsrv — server dies during sustained redraw in `-multiwindow` when composite redirection is on

**Upstream**: https://github.com/marchaesen/vcxsrv
**Status**: drafted 2026-08-24, **NOT FILED**. Filing needs the maintainer's go-ahead.
**Our issue**: `doc/claude/issues/0680-reproducible-crash-descend-then-zoom-on-the-real-x-server.md`
**Duplicate check**: no exact match found (see *Prior art* below).

---

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

**Directly measurable, if a maintainer wants it**: Windows caps a process at
10,000 GDI objects by default. `GetGuiResources(hProcess, GR_GDIOBJECTS)` sampled
against `vcxsrv.exe` during the workload would settle whether this is a monotonic
leak or a burst. An idle server on these flags sits at **GDI=21**. From WSL:

```powershell
powershell.exe -NoProfile -Command "Add-Type -Namespace W -Name U -MemberDefinition '[DllImport(\"user32.dll\")] public static extern uint GetGuiResources(IntPtr h, uint f);'; \$p=Get-Process vcxsrv; '{0} GDI={1} USER={2}' -f \$p.Id, [W.U]::GetGuiResources(\$p.Handle,0), [W.U]::GetGuiResources(\$p.Handle,1)"
```

We have not run this under a crashing session yet; it costs the reporter one more
deliberate crash and we did not want to claim a number we had not taken.

## Available on request

Ten minidumps (2.9–5.0 MB each) and the full 1398-line log of the crashing run,
plus the clean log of the surviving one. **Not attached here**: dumps of an X
server carry window titles and possibly window contents, so they should be
reviewed before being handed to anyone.

## Prior art

Related but not the same defect, from an upstream search:

- [Bug #3 — Resizing in multiwindow mode crashes vcxsrv](https://sourceforge.net/p/vcxsrv/bugs/3/) — fixed in 1.9.4.1, and resize-driven, which this is not.
- [Bug #136 — vcxsrv crash in multiwindow mode](https://sourceforge.net/p/vcxsrv/bugs/136/) — crashes around screen lock/unlock.
- [Bug #161 — Restart problems after vcxsrv crash](https://sourceforge.net/p/vcxsrv/bugs/161/)
- [Issue #25 — Crash dump](https://github.com/marchaesen/vcxsrv/issues/25)

None names `CreateDIBSection` exhaustion under sustained redraw, and none reports
the `-nocompositewm` toggle as a fix.
