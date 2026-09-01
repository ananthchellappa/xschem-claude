# xcount — count the calls that mint a server-side drawable

Written for issue **0612** (an OP-annotation session kills VcXsrv). Answers the
question "is XSCHEM leaking or flooding X drawables?" without a tracer — `xtrace`,
`xscope` and `ltrace` are not installed on this box.

```sh
gcc -shared -fPIC -o xcount.so  xcount.c  -ldl
gcc -shared -fPIC -o xcount2.so xcount2.c -ldl
LD_PRELOAD="$PWD/xcount.so $PWD/xcount2.so" ./src/xschem --script <t>.tcl
```

Each process prints its totals to stderr at exit. `xcount2` stays silent when all
its counters are zero, so the helper forks do not spam the log.

* **`xcount.c`** — Xlib: `XCreatePixmap` / `XFreePixmap`, `XCreateWindow`,
  `XCreateSimpleWindow`, `XRenderCreatePicture` / `Free`, `XRenderCreateGlyphSet`.
* **`xcount2.c`** — the XCB layer, because cairo links `libxcb-render` and
  `libxcb-shm` and its Render path *can* bypass Xlib entirely. On this box it does
  not (xcount2 never fires), but a different cairo build would.

Measured 2026-08-22 over a motion + hierarchy + resize storm: 168 pixmaps created
against 191 freed, 266 pictures against 267 freed. Balanced. See 0612.
