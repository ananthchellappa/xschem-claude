# 0413 — `backing_store = WhenMapped` on the drawing window lets XSCHEM kill the X server

> ## ⚠ `AUDIT_DISPLAY=:0` CANNOT PAY THIS ISSUE'S LOOK DEBT
>
> Measured 2026-08-22 with `xdpyinfo`: **three X servers run here at once.**
>
> | display | vendor string | what it is |
> |---|---|---|
> | `:0` | `Microsoft Corporation` | Xwayland, WSLg's own server |
> | `$DISPLAY` | `HC-Consult` | the Windows X server the user looks at, over TCP |
> | `:99` | `The X.Org Foundation` | Xvfb, the dev display |
>
> `AUDIT_DISPLAY=:0` exports the **literal** string `:0`
> (`tests/headless/xvfb_arm.sh:140`), so it targets **Xwayland** — not the server
> this issue is named after. A `backing_store` behaviour is a property of the X
> server implementation, so testing it on the wrong one proves nothing.
>
> Pay the look debt with `AUDIT_DISPLAY=$DISPLAY`, or by hand from a terminal.
> See CLAUDE.md, "THERE ARE THREE X SERVERS HERE".


Status: **FIXED** — root-caused by A/B measurement against a real VcXsrv, fixed in
`src/xinit.c`, regressed by `tests/headless/test_backing_store_0413.tcl`.
Reported by the user as "**Ctrl-B in the waveform viewer kills the X server**".
Area: `src/xinit.c:3579` (the attribute), `src/callback.c:9728` (`handle_expose`, which is why
we never needed it), `src/wave_viewer.tcl:12116` (`browser_show`, the gesture that exposed it).
Tests: `tests/headless/test_backing_store_0413.tcl`.
Environment: VcXsrv 21.1.16.1 `-multiwindow -clipboard -wgl -ac` on Windows, reached from WSL2.

## The symptom, and why it was mis-scoped at first

Pressing **Ctrl-B** (Signal Browser toggle) in the waveform viewer killed the **X server**, not
the client: every X program on the machine died and the server had to be restarted by hand.

The obvious first suspicion — and the one the session prompt led with — was a **16-bit
coordinate overflow** in the sea-of-names flow pane: `browser_flow_scrollregion` returns
`cols * colw`, `cols` grows with the signal count, and X11 coordinates are signed 16-bit.
It is a real hazard and it is worth knowing it is **not this bug**:

* A pure-Tk canvas with `-scrollregion {0 0 150096 1}` and 848 items at x up to 150,000
  survives on X.Org 21.1.11 (Xvfb) with no error at all.
* On the actual `tb_bandgap` database (424 raw variables) the sea pane flows **18** names,
  `cols=3 colw=88`, scrollregion width **264**. Nothing is near 32767.
* The user had already shortened the transient from 200us to 100ns — 59 points — and the crash
  survived that, which was the first sign the trigger scales with **signal count** or with
  nothing at all, not with data size.

## The measurement

The crash is not reproducible on Xvfb or Xwayland, so it was reproduced against a **second,
isolated VcXsrv instance** (`:1`, then `:11`/`:12`) launched with `-logfile ... -logverbose 3`,
leaving the user's `:0` untouched. Reproduced on the first try, and the server log ends:

```
Using Composite redirection
winMultiWindowWMProc - Error code: 8 (Match), ID: 0x180000, Major opcode: 12 (ConfigureWindow), Minor opcode: 0
```

That is **VcXsrv's own internal window manager thread** getting `BadMatch` on a
`ConfigureWindow` it issued, and treating it as fatal.

Bisecting `browser_show` reached the answer in one step: the crash is the very first statement,
`pack $f -side left -fill y -before $top.drw`, before the browser draws anything. Widening from
there:

| gesture | result |
|---|---|
| `pack` a widget **before** `.drw` (moves it right) | **server dies** |
| `pack` a widget **above** `.drw` (moves it down) | **server dies** |
| `pack` a widget **after** `.drw` (resize only, no move) | survives |
| `wm geometry` the toplevel (resize only) | survives |
| `pack forget .drw` | survives |
| the same gestures in **pure Tk**, no XSCHEM | survives |
| the same gestures on the **main** window, no waveform viewer | **server dies** |

So: the Signal Browser is incidental. **Any** widget packed to the left of or above an XSCHEM
drawing area kills VcXsrv, on the main window as readily as on the viewer. What XSCHEM has that
a plain Tk frame does not is one attribute:

```c
src/xinit.c:3580 (before the fix)
    winattr.backing_store = WhenMapped;
    Tk_ChangeWindowAttributes(tkwindow, CWBackingStore, &winattr);
```

Confirmed A/B on **one binary**, via a temporary `XSCHEM_BACKING_STORE` knob, same gesture, same
server, back to back: `WhenMapped` → server dead, every time. `NotUseful` → survives, every
time. Then the real Ctrl-B path on the real 424-signal session: survives.

## Why removing it is a fix and not a workaround

XSCHEM already double-buffers into `xctx->save_pixmap`, and `handle_expose()` repaints from it
on every Expose:

```c
src/callback.c:9731
  MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], mx,my,button,aux,mx,my);
```

whose neighbouring comment has read *"redraw selection on expose, needed if no backing store
available on the server"* since 2017. Server-side backing store was only ever a redundant second
copy of a buffer we keep ourselves, and it is a **request**, not a guarantee — most servers are
free to ignore it, and many do. We were paying a server crash for an optimisation that a
conforming server need not honour.

The fix sets `NotUseful` and leaves `XSCHEM_BACKING_STORE=1` as an escape hatch for anyone who
wants to measure the old behaviour. There is deliberately no Tcl preference: the only thing the
old value buys on this platform is the crash.

The three `CWBackingStore` call sites (startup, `new_schematic create_window`, tab detach) all
pass the same file-static `winattr`, so the single default covers all three — asserted, because
a fix applied to the startup path alone would have left every new window crashing.

## It is also a VcXsrv bug

A client must not be able to kill an X server; `winMultiWindowWMProc` turning a `BadMatch` on
its own request into server death is a server defect, and worth reporting upstream
(github.com/marchaesen/vcxsrv). **Updating the server does not help**: the user had already
upgraded 1.20.8 → 21.1.16.1 before this was diagnosed and the crash was unchanged, which is what
ruled out "old server" as the explanation and made it ours to fix.

## Coverage

The 14 `test_wave_sigbrowser*` suites are all headless, and **all of them passed** across this
crash. That is not a gap in their thoroughness: Xvfb and Xwayland both tolerate the exact
gesture that kills VcXsrv, so no headless suite on this machine can reproduce the consequence.

`tests/headless/test_backing_store_0413.tcl` therefore asserts the **request** rather than the
consequence — the attribute we hand the server, on the main window and on a second window, plus
the source-level shape of the default. Its negative control is `XSCHEM_BACKING_STORE=1`, under
which BS4 and BS5 fail; a check that cannot fail is not a check.

## Reproduction, for the record

```sh
# a SECOND VcXsrv, so the real :0 is never at risk
"C:\Program Files\VcXsrv\vcxsrv.exe" :11 -multiwindow -clipboard -wgl -ac \
    -logfile C:\Users\<you>\vcx11.log -logverbose 3

cd <repo>
XSCHEM_BACKING_STORE=1 DISPLAY=<host>:11 ./src/xschem --pipe -q --nolog --script <probe>
#   where <probe> does, on the main window:  pack <any frame> -side left -before .drw
# -> "X connection broken", and the tail of vcx11.log names the fatal ConfigureWindow.
```
