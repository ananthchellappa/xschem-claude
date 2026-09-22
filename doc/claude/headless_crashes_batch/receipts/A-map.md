# A-map — which code dereferences the display when there is none, and which of it a user can reach

Crew: **MAPPING** (item A, issue 1493 step 1). Tree `7e1e6a6f`, branch `fluid-editing`.
**No product code changed.** Everything below was measured in a scratch clone at
`/var/tmp/xhc/A/t`, now deleted. The only file this crew adds to the repository is this
receipt.

---

## 0. Summary — the three numbers that matter

| | |
|---|---|
| **271** | dereferences of the `display` global, enumerated **by identity** (the compiler, not a pattern), in **51** functions across 7 files |
| **17** | of those 271 **execute with `has_x == 0`**, measured, spread over **7** functions |
| **5** | distinct user-reachable crash *entry points*, of which **2 are new** — `xschem grabscreen` + any button event, and `set draw_crosshair 1` + a motion event |

The batch's three item issues account for **12** of the 17 reached sites. The other 5 are
new. One of 1492's four verbs (`copy_hilights`) turns out **not to be a display defect at
all** — it crashes identically with a live GUI and `has_x == 1`.

Issue 1493's warning against quoting a count forward is respected below: **every claim is a
list of `file:line` sites with the statement text**, and §6 says what the method cannot see.

---

## 1. Method

### 1.1 The static sweep, by identity

1493 step 1 asks for an enumeration "by identity rather than by that pattern", after three
passes with `/usr/bin/grep -rEc 'X[A-Za-z_]+ *\( *display'` produced 152/69/13, 172/70/7 and
182/70/13. The method used here is the C compiler:

```c
/* src/xschem.h, scratch clone only */
extern Display *display __attribute__((deprecated("XHCUSE")));
```

`gcc` then emits **one warning per use site**, with `file:line:column`, for every reference to
that object — regardless of what the callee is called, whether it is a macro, or whether it is
an argument, an assignment or a test. A full `make` produced **271 distinct `file:line`**
sites. (A first attempt renamed the global instead; that is wrong — gcc reports an undeclared
identifier only **once per function**, so it yields 52 functions, not 271 sites.)

```
draw.c 177 · xinit.c 69 · callback.c 13 · scheduler.c 4 · actions.c 4 · hilight.c 3 · move.c 1
```

Sites were attributed to functions from the **`-O0`** debug info (`info line file:line`, then
`info functions` for the ranges). This matters: at `-O2` gdb folds inlined statics into their
caller, and the first pass mis-attributed `handle_expose`'s three sites to `callback`,
`erase_crosshair`'s four to `draw_crosshair`, and `drawgrid`'s nineteen to `draw`. **All
function names below are the `-O0` ones.**

### 1.2 The dynamic sweep — a per-site execution tracer

A grep cannot say what *runs*. Two scratch builds were made:

* **null build** — the item-A change itself, `display = NULL;` after the `XCloseDisplay()` in
  `xserver_ok()` (`src/draw.c`). This is the production shape: a missed guard faults.
* **tracer build** — `xserver_ok()` **keeps** the probe connection open instead of closing it,
  and installs an `XSetErrorHandler` that swallows protocol errors. So `has_x` is 0 while
  `display` is a *live, usable* pointer: a missed guard does **not** fault, and the run
  continues past it. That is what makes an exhaustive reachability sweep possible instead of a
  stop-at-the-first-crash one.

  ⚠ The tracer's two edits are written so they **shift no line number** (the helper is
  appended to `globals.c`; the call site is a one-line block-scope `extern`). The first
  attempt inserted 15 lines above `xserver_ok()` and every `draw.c` breakpoint silently landed
  15 lines late — `drawtempline` "executed with `has_x==0`" although it has an entry guard.
  After the fix, gdb placed **271 of 271** dprintfs at exactly the requested line, **0
  mismatches**; before it, 241 of 258 slid.

The tracer build is driven under gdb with one `dprintf` per site:

```
dprintf draw.c:208,"XHCHIT draw.c:208 has_x=%d\n", has_x
```

printing and continuing. Any line tagged `has_x=0` is a statement that **executed with no X**.
(`tbreak … if has_x==0` was tried first; `$_hit_bpnum` is not usable inside a `commands`
range, and 13 of the 271 breakpoints were never created. `dprintf` needs no bpnum mapping.)

### 1.3 What was driven

| workload | processes | how |
|---|---|---|
| every `xschem` subcommand, bare | **323** | `src/xschem_subcommands.txt` (build-generated from `scheduler.c`), one process each, `catch {xschem <verb>}` |
| every subcommand **then 10 canvas events** | **323** | same, followed by `xschem callback .drw <e> …` for e ∈ {2,4,5,6,7,8,9,10,22,33} |
| every `xschem callback` combination | **540** | 3 window paths × 12 event types × (10 keys + 5 buttons), **one process each** so a crash loses only that cell |
| every headless suite | **406** | `tests/headless/test_*.tcl`, `--nogui`, 150 s timeout |
| every documented CLI flag | **44 + 14** | the 42 long options in `options.c` plus `-x`, `--nogui` and 14 `-x`/`--nogui` × export combinations |
| 5 stateful scenarios | 5 | crosshair/snap-cursor armed; load + select_all + redraw; hilight family; graph family; print/export family |

Both `has_x == 0` arms were used throughout: `env -u DISPLAY` and `DISPLAY=:151` (a private
Xvfb) with `--nogui`. Nothing touched the user's HOME, `:99`, `~/.claude` or
`~/dev/xschem-op-wcard`.

---

## 2. THE SITE LIST — reached with `has_x == 0` (17 sites, 7 functions)

Measured. Each line is a statement that executed while `has_x` was 0.

| site | function | statement | entry point that reaches it | issue |
|---|---|---|---|---|
| `callback.c:9891` | `update_statusbar` | `XGetKeyboardControl(display, &kbdstate);` | **any** `xschem callback` — 540/540 combinations | **0227** / 0834 / 0467 |
| `callback.c:9929` | `handle_expose` | `MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], mx,my,button,aux,mx,my);` | `xschem callback <win> 12 …` (Expose) — 45/45 | **NEW** |
| `callback.c:4153` | `erase_crosshair` | `MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], …)` | `set draw_crosshair 1` then `xschem callback .drw 6 …` | **NEW** |
| `draw.c:208` | `grabscreen` | `white = WhitePixel(display, screen_number);` | `xschem grabscreen` then `xschem callback .drw 4 …` | **NEW** |
| `draw.c:209` | `grabscreen` | `displayh = DisplayHeight(display, screen_number);` | ″ | **NEW** |
| `draw.c:210` | `grabscreen` | `displayw = DisplayWidth(display, screen_number);` | ″ | **NEW** |
| `draw.c:212` | `grabscreen` | `XQueryPointer(display, xctx->window, …);` | ″ | **NEW** |
| `draw.c:215` | `grabscreen` | `gc = XCreateGC(display, rw, gcvm, &gcv);` | ″ | **NEW** |
| `draw.c:218` | `grabscreen` | `clientwin = XCreateWindow(display, rw, …);` | ″ | **NEW** |
| `draw.c:220` | `grabscreen` | `XMapRaised(display,clientwin);` | ″ | **NEW** |
| `draw.c:257` | `grabscreen` | `XQueryPointer(display, xctx->window, …);` | ″ | **NEW** |
| `draw.c:329` | `grabscreen` | `XFreeGC(display, gc);` | ″ | **NEW** |
| `draw.c:330` | `grabscreen` | `XDestroyWindow(display, clientwin);` | ″ | **NEW** |
| `xinit.c:615` | `free_gc` | `XFreeGC(display,xctx->gc[i]);` | `xschem fill_reset` | **1492** |
| `xinit.c:586` | `create_gc` | `pixmap[i] = XCreateBitmapFromData(display, xctx->window, …);` | `xschem compare_schematics` | **1492** |
| `xinit.c:1467` | `toggle_fullscreen` | `XQueryTree(display, topwin_id, …);` | `xschem fullscreen` | **1492** |
| `xinit.c:1497` | `toggle_fullscreen` | `window_state(display , parent_id,fullscr);` | `xschem fullscreen` (with a live pointer) | **1492** |

**Classification — all five entry points are reachable from a user's script**, and none needs
the GUI. Each was reached by a `catch`-wrapped `xschem …` call in a `--script` file, which is
how `op_annot.tcl` and every suite in `tests/headless/` drive the program. `catch` does not
catch a SIGSEGV, so a correctly-written script still dies.

### 2.1 Backtraces (the statement that faulted)

Production **null build**, `env -u DISPLAY --nogui`, `handle SIGSEGV stop nopass`:

```
#0  XFreeGC () from libX11.so.6
#1  free_gc () at xinit.c:615
#2  xschem_cmds_f (…) at scheduler.c:3880          <-- xschem fill_reset
   display = 0x0, has_x = 0
```
```
#0  XQueryTree () from libX11.so.6
#1  toggle_fullscreen (topwin=".drw") at xinit.c:1467
#2  xschem_cmds_f (…) at scheduler.c:4260          <-- xschem fullscreen
```
```
#0  XCreatePixmap () from libX11.so.6
#1  XCreateBitmapFromData () from libX11.so.6
#2  create_gc () at xinit.c:586
#3  compare_schematics (f=0x0) at xinit.c:1070
#4  xschem_cmds_c (…) at scheduler.c:3085          <-- xschem compare_schematics
```
```
#0  XGetKeyboardControl () from libX11.so.6
#1  update_statusbar (persistent_command=0, wire_draw_active=0) at callback.c:9891
#2  callback (win_path=".drw", event=2, …) at callback.c:10093
#3  xschem_cmds_c (…) at scheduler.c:2770          <-- xschem callback .drw 2 …
```
```
#0  XCopyArea () from libX11.so.6
#1  MyXCopyArea (display=0x0, src=0, dest=0, gc=0x0, …) at draw.c:10836
#2  handle_expose (mx=100, my=100, button=0, aux=0) at callback.c:9929
#3  callback (win_path=".drw", event=12, …) at callback.c:10212   <-- NEW
```
```
#0  XCopyArea () from libX11.so.6
#1  MyXCopyArea (display=…, src=0, dest=0, gc=0x0, …) at draw.c:10836
#2  erase_crosshair (size=0) at callback.c:4153
#3  draw_crosshair (what=1, state=0) at callback.c:4238
#4  handle_motion_notify (…, draw_xhair=1, …) at callback.c:7176
#5  callback (win_path=".drw", event=6, …) at callback.c:10222    <-- NEW
```
```
#0  grabscreen (win_path=".drw", event=4, …) at draw.c:208
        208  white = WhitePixel(display, screen_number);
#1  callback (win_path=".drw", event=4, …) at callback.c:10191    <-- NEW
   display = 0x0, has_x = 0
```

### 2.2 The two new entry points, as repro

```tcl
# NEW 1 -- xschem grabscreen arms xctx->ui_state |= GRABSCREEN with NO has_x guard
#          (scheduler.c, the "grabscreen" branch); the next canvas event dispatches
#          into grabscreen(), which has no guard either (callback.c:10191).
catch {xschem grabscreen}
catch {xschem callback .drw 4 100 100 0 1 0 0}   ;# ButtonPress -> SIGSEGV at draw.c:208
puts "never printed"
```

```tcl
# NEW 2 -- the crosshair family. draw_crosshair()/erase_crosshair() have no has_x
#          guard; handle_motion_notify() calls them on the Tcl variable alone.
set draw_crosshair 1
catch {xschem callback .drw 6 100 100 0 1 0 0}   ;# Motion -> SIGSEGV at callback.c:4153
puts "never printed"
```

```tcl
# NEW 3 -- Expose. No state needed at all.
catch {xschem callback .drw 12 100 100 0 0 0 0}  ;# SIGSEGV at callback.c:9929
puts "never printed"
```

All three were measured on the null build with `DISPLAY` unset **and** on the **unmodified
base build** with `DISPLAY=:151 --nogui`; on the base build they abort inside libxcb instead:

```
[xcb] Extra reply data still left in queue
xschem.base: ../../src/xcb_io.c:682: _XReply: Assertion `!xcb_xlib_extra_reply_data_left' failed.
```

That is 1493's second failure shape, reproduced **first-hand** here (1493 records it at second
hand from `test_undo_selection`). It is also why these are pre-existing and not caused by the
item-A change.

---

## 3. Which issue each site belongs to, and which are NEW

| issue | what it claimed | what was measured |
|---|---|---|
| **0227** (`update_statusbar`) | `XGetKeyboardControl` on a NULL/closed `Display*`, four witness suites, blast radius unmeasured | **Confirmed exactly.** It is the *only* display site in the whole 406-suite corpus: across every headless suite, `callback.c:9891` is the single statement that ever runs with `has_x == 0`, and only in those same four suites. |
| **0834** (`xschem callback` under `--nogui`) | same crash, window `.` vs `.drw` unsettled | **Settled: it is 0227.** Window `.` and `.drw` and `.x1.drw` all reach `callback.c:9891` and nothing else; all 540 combinations hit it. §4 below applies 0227's guard and re-runs 0834's own repro — it survives. 0834's second candidate, "the window-name lookup for `.`", is **refuted**. |
| **0467** (`test_undo_selection`) | proposed duplicate of 0227 | **Confirmed duplicate.** With 0227's one-line guard the suite reaches `RESULT: ALL PASS` headless. |
| **1492** `fill_reset` | `free_gc()` → `XFreeGC()` | **Confirmed**, `xinit.c:615`. |
| **1492** `fullscreen` | `toggle_fullscreen()` → `XQueryTree()` | **Confirmed**, `xinit.c:1467` (and `xinit.c:1497` once the first survives). |
| **1492** `compare_schematics` | "inside `copy_hilights()`" | **Wrong.** It is `compare_schematics()` (`xinit.c:1070`) → `create_gc()` (`xinit.c:586`) → `XCreateBitmapFromData()`. |
| **1492** `copy_hilights` | `create_gc()` → `XCreateBitmapFromData()` | **Wrong, and not this class at all.** It faults at `hilight.c:230`, `entry = &old_xctx->hilight_table[i];` — `get_old_xctx()` returned NULL. **It crashes identically with a full GUI and `has_x == 1`** (measured on the private Xvfb), and the tracer shows it touches **zero** display sites. 1492's ⚠ about a "suspect pairing" was right: the two rows were swapped, and one of them was never a display defect. |
| **1483** | fixed in `2288d437` | **Still fixed.** `xschem globals` reaches no display site on either arm. |

**NEW — in no issue file:**

1. `callback.c:9929` `handle_expose` → `MyXCopyArea` — `xschem callback <win> 12 …`.
2. `callback.c:4153` `erase_crosshair` → `MyXCopyArea` — `set draw_crosshair 1` + motion.
3. `draw.c:208-330` `grabscreen` (10 sites) — `xschem grabscreen` + any button event. The
   arming branch in `scheduler.c` sets `xctx->ui_state |= GRABSCREEN` with **no `has_x`
   guard**, which is the actual defect; `grabscreen()` itself has none either.
4. `copy_hilights` is a **NULL-`Xschem_ctx` crash**, not a display crash, and is
   display-independent (see above).
5. `xschem hier_psprint` on a loaded schematic segfaults headless at
   `psprint.c:1070` in `ps_draw_symbol()` (`strcmp` on a NULL). **Out of this item's class
   and NOT diagnosed** — it is not a `display` dereference. Its arm comparison is
   inconclusive: with `has_x == 1` the same call had not returned after 120 s. Recorded, not
   fixed.

### 3.1 Two sibling classes this map makes visible

The three new callback sites all fault on a **NULL GC**, not a NULL `Display*`:
`MyXCopyArea(display=…, src=0, dest=0, gc=0x0, …)`. With `has_x == 0` `create_gc()` is never
called, so `xctx->gc[]`, `xctx->window` and `xctx->save_pixmap` are all 0/NULL. **Nulling
`display` does not make these safe and never could** — they crash on the tracer build with a
perfectly live connection. A `has_x` guard fixes them; a `!display` guard would not.
`copy_hilights` is the third member of this family (a NULL `Xschem_ctx`).

---

## 4. What the item-A change does, measured

`display = NULL;` after `XCloseDisplay()` in `xserver_ok()`.

| measurement | base build | null build |
|---|---|---|
| 323 bare subcommands, `DISPLAY` unset | 4 die | **same 4 die** |
| 323 bare subcommands, `DISPLAY=:151 --nogui` | 4 die | **same 4 die** |
| 323 bare subcommands, outputs of the two builds on the `DISPLAY`-set arm | — | **byte-identical** for all 323 (after normalising the random `xschem_web_*` tmpdir name) |
| 406 headless suites, `DISPLAY` unset | 4 SIGNAL | **same 4** — `test_hilight_case_senders`, `test_keybind_snap_grid`, `test_undo_selection`, `test_window_switch_bogus_enter` |
| 406 headless suites, `DISPLAY=:151 --nogui` | 4 SIGNAL | **same 4** |
| the two `has_x == 0` arms compared suite by suite (null build) | — | **identical on 403 of 406**; the 3 exceptions are check-count differences in suites that add `DISPLAY`-dependent rows (`test_del_negative_arg` 21→24, `test_startup_guard_0663` 18→23, `test_no_untitled_litter` verdict) — **no crash difference anywhere** |
| `xschem callback .drw 2 …`, `DISPLAY=:151 --nogui` | **libxcb abort**, `rc 134` | clean `SIGSEGV`, `rc 1`, same frame as the no-display arm |

**So the change is not the fault-finder 1493 expected, because 1483's fix already took the one
statement that was reading freed memory.** What it does buy, and it is exactly 1493 step 4's
property, is that **the two `has_x == 0` arms now agree**: the `DISPLAY`-set arm stops
producing undefined behaviour (the libxcb abort) and produces the same fault, in the same
frame, as the headless arm. It found **no new red** in 406 suites, 323 verbs or 58 CLI
invocations. Landing it is cheap.

The one guard in the tree that tests the pointer rather than the flag,
`net_active_window()`'s `if(!display || !win) return EXIT_FAILURE;` (`xinit.c:106`), becomes
meaningful with the change — but its only caller is already `if(has_x && argc > 2)`
(`scheduler.c`, the `activate_window` branch), so it is not reachable with `has_x == 0` either
way.

### 4.1 0227's one-line guard, applied as a probe

A third scratch build added `if(has_x)` before the `update_statusbar()` call
(`callback.c:10093`) — 0227's own "Suggested fix". Headless, `env -u DISPLAY --nogui`:

| suite | before | after (probe) | X arm, same build |
|---|---|---|---|
| `test_keybind_snap_grid` | `FATAL: signal 11` | `RESULT: ALL PASS (6 checks)` | `ALL PASS (6 checks)` |
| `test_undo_selection` | `FATAL: signal 11` | `RESULT: ALL PASS` | `ALL PASS` |
| `test_window_switch_bogus_enter` | `FATAL: signal 11` | `RESULT: ALL PASS (2 checks)` | `ALL PASS (2 checks)` |
| `test_hilight_case_senders` | `FATAL: signal 11` | **no `RESULT:`** — `invalid command name "toplevel"` at line 564 | `ALL PASS (30 checks)` |

0227's own warning — *"clears the FIRST headless landmine in `callback()`; the rest of that
function is unproven headless"* — is now measured rather than suspected:

* For the **four witness suites**, the guard is sufficient for three. The fourth stops on a
  different headless problem that is **not** a display dereference: the suite itself calls the
  Tk command `toplevel`, which does not exist without Tk.
* For **`callback()` in general** the guard is **not** sufficient. On the probe build,
  `xschem callback .drw 12 …` still segfaults, now at `handle_expose` (`callback.c:9929`).
  That is the **second** landmine, and this map names it.

---

## 5. T1 visibility (acceptance criterion 4)

Read at `7e1e6a6f` in `tests/run_regression.tcl` and `tests/headless/full_audit.sh`:

| suite | a T1 case? | in `full_audit.sh`'s `nogui_tests`? |
|---|---|---|
| `test_keybind_snap_grid` | **no** | no |
| `test_undo_selection` | **no** | no |
| `test_hilight_case_senders` | **no** | no |
| `test_window_switch_bogus_enter` | **no** | no |
| `test_callback_argc` | **YES** | no (it hard-codes its own arm) |

So the whole 0227/0834/0467 class is invisible to T1 today, and `full_audit.sh` runs all four
on its X arm where they pass — unchanged from what 0227 records. **The T1-visible home already
exists**: `test_callback_argc` is a T1 case, it is the case for "a Tcl-reachable `xschem`
subcommand must ERROR, never crash" (issue 0076), and `2288d437` already gave it three rows
that branch on the `::has_x` mirror for 1483. It runs 8 checks today. Every site in §2 can be
counted there with no new registration, because `run_regression.tcl` hard-codes `--nogui`, so
`has_x` is 0 in T1 **even on a developer desktop with a display**.

Nothing else needs to become a T1 case for criterion 4 to be met; the four witness suites are
better used as red-first fixtures (they are deterministic, and `test_undo_selection` gives 20
`ok:` rows before the crash).

---

## 6. WHAT THIS METHOD CANNOT SEE

Stated as measured, with the residue enumerated rather than estimated. All **344** lines in
`src/*.c` containing the token `display` were diffed against the 271 compiler-reported sites;
the **73-line residue** was read by hand. It falls into five classes.

**(a) Code this configuration does not compile — the compiler is blind by construction.**
These are real, unguarded `display` dereferences that will exist in other builds:

| site | statement | excluded by |
|---|---|---|
| `psprint.c:333` | `cairo_xlib_surface_create(display, xctx->save_pixmap, …)` | `#if defined(HAS_LIBJPEG) && HAS_CAIRO==1` — **HAS_LIBJPEG is off here**. On a libjpeg build this is live in `ps_embedded_graph()`, reachable from `xschem hier_psprint`. |
| `draw.c:165` | `XpmWriteFileFromPixmap(display, "plot.xpm", …)` | `#else /* no cairo */` — live on a **no-cairo** build |
| `draw.c:1519,1521,1596,1598,1847,1908` | `XDrawLine(display, …)` | `#ifndef __unix__` — the **Windows** path |
| `xinit.c:1208,1213,2927,2940` | `Tk_FreePixmap(display,…)` / `Tk_GetPixmap(display,…)` | `#ifndef __unix__` — the **Windows** path |
| `xinit.c:3761` | `XGetXCBConnection(display)` | `#if 0` **and** `#ifdef HAS_XCB`, and `xschem.h` does `#undef HAS_XCB` regardless of `config.h`. Dead in every build today. |

1493 names `cairo_xlib_surface_create` ×7 and `XGetXCBConnection` ×1 as the sites a `X…(display`
pattern cannot see. **The compiler method sees six of the seven cairo calls without special
handling** (`draw.c:148,268,10127`, `xinit.c:2821,2845`, `scheduler.c:8818`); the seventh is
`psprint.c:333`, invisible for the *configuration* reason above, not the callee-name one. It
also sees `MyXCopyArea`/`MyXCopyAreaDouble` ×17, the `WhitePixel`/`DisplayHeight`/`DisplayWidth`
macros, `window_state`, `client_msg` and `Tk_Display`. **Callee naming is not a blind spot of
this method; the preprocessor is.**

**(b) Shadowed locals and parameters.** `MyXCopyArea`, `MyXCopyAreaDouble` and `XSetTile`
(`draw.c:10815-10864`), the `err()` error handler (`xinit.c:362`) and `windowid()`
(`xinit.c:321`, `Display *display;` assigned from `Tk_Display(mainwindow)`) all have a
**local or parameter named `display`** that shadows the global. Their bodies dereference *a*
display that is not the global, so no warning is emitted there. The map catches the **call
site** (which is where the `has_x` guard belongs) but not the deref inside the callee — which
is why `draw.c:10836` appears in three backtraces in §2.1 and in no row of the site list.
`windowid()` is the one that does not pass the global at all: it builds its own from
`Tk_Display(Tk_MainWindow(interp))`, which is a separate NULL risk the sweep cannot see.

**(c) Handles derived from the display and stored in `xctx`.** `xctx->gc[]`,
`xctx->gcstipple[]`, `xctx->gc_scope`, `xctx->window`, `xctx->save_pixmap`,
`xctx->cairo_sfc`, `xctx->cairo_save_sfc` are all created inside `if(has_x)` paths and are
0/NULL with `has_x == 0`. Every later use of them is invisible to a `display` sweep, and
§3.1 shows three measured crashes of exactly that shape. **A complete map of "dies without a
display" is strictly larger than this map**, and the difference is this class. Likewise the
`cairo_*` calls that take `xctx->cairo_sfc` rather than `display`, and (on a build where
`HAS_XCB` survives) any `xcb_*` call on a connection obtained once from `XGetXCBConnection`.

**(d) Reachability is bounded by what was driven.** 1,650 processes is not "all user scripts".
A verb called with arguments, or after a state-setting sequence this crew did not think of,
can reach a site marked unreached in §7 — `grabscreen` is the proof: it is reachable only
because *another verb* arms `ui_state` first, and it took the verb×callback matrix to find it.
The bare-verb sweep alone found four sites; adding one canvas event after each verb found ten
more. **The unreached sites in §7 are "not reached by this workload", never "unreachable".**

**(e) The GUI arm is not covered.** Everything here is `has_x == 0`. Sites that only run with
`has_x == 1` are out of scope by construction and are not claimed to be safe or unsafe.

---

## 7. The rest of the 271 — classification, and how it was decided

**Class G1 — proved unreachable with `has_x == 0` by an entry guard (124 sites, 18 functions).**
Decided by **reading**: the function opens with `if(!has_x) return;` (or `… || !has_x) return;`)
on a line strictly before its first site. Confirmed by measurement: none was hit in any run.

```
draw.c  drawgrid(19, guard :1211)  drawline_duty(17, :1506)  drawrect(13, :2619)
        drawarc(13, :2144)  filledrect(10, :2249)  drawpolygon(9, :2486)
        drawtempline(8, :1836)  draw_wave_hilight(7, :7397)  draw_hilight_wire(6, :1752)
        filledarc(6, :2067)  drawtemparc(4, :1966)  drawtemprect(3, :2716)
        draw_hilight_dot(3, :1810)  drawtemppolygon(2, :2571)  print_image(1, :116)
        svg_embedded_graph(1, :10084)  wave_hilight_erase(1, :7369)
hilight.c resolve_hilight_style_rgb(1, :861)
```

**Class G2 — guarded by an enclosing `if(has_x)` block (read, 28 sites).**
`xinit.c build_colors(13, under :1317/:1321/:1332/:1345/…)`, `resetwin(9, inside the
:2874–:2972 block)`, `change_linewidth(2, :2750)`, `xwin_exit(3, :1200)`,
`Tcl_AppInit(2, inside `if( has_x )` at :3751)`, `draw.c draw(3, inside :10563–:10805)`,
`scheduler.c xschem_cmds_g(3 — :4918 in the `else` of `if(!has_x||…)`, :6124/:6126 under the
`if(has_x)` 1483 added)`, `xschem_cmds_n(1, :8817 `if(has_x && xctx->save_pixmap)`)`,
`hilight.c draw_hilight_net(2, :4381 `… && has_x`)`.

**Class U — no `has_x` guard, and NOT reached by any of the 1,650 driven processes
(99 sites).** These are the follow-up surface. Read §6(d) before treating any of them as safe.

| function | sites | note on how it is entered |
|---|---|---|
| `draw.c grabscreen` | 8 more of 18 (`234,237,242,268,271,272,282,283`) | the same path as the 10 reached ones; the run faulted before them |
| `xinit.c create_gc` | 10 more of 11 | reached at `:586` and faults there |
| `xinit.c free_gc` | 6 more of 7 | reached at `:615` and faults there |
| `xinit.c set_clip_mask` | 8 | all three callers (`select.c:1091,1113,1138`) are inside `if(has_x)` — guarded **at the call site**, read |
| `xinit.c resetwin`/`resetcairo` | 2 (`resetcairo :2821,:2845`) | called from `resetwin`'s `if(has_x)` block |
| `xinit.c find_best_color` | 3 | one caller guards (`hilight.c:625`, `has_x ? … : 0`), the other is `build_colors` (Class G2) |
| `xinit.c net_active_window` | 3 | sole caller `if(has_x && argc > 2)` — guarded, read |
| `xinit.c pending_events` | 1 (`:1442`) | — |
| `xinit.c toggle_fullscreen` | 3 more of 5 (`1500,1501,1504`) | same verb, past the first fault |
| `callback.c handle_key_press` | 4 (`8707,8708,8714,8719`) | inside `handle_key_press`; the body has `if(has_x)` at 7452/7480/8087 but **none covers these four** |
| `callback.c erase_crosshair` | 3 more of 4 (`4146,4149,4155`) | same path as `:4153` |
| `callback.c erase_snap_cursor` | 1 (`:4067`) | `draw_snap_cursor` callers: `callback.c:705` guards with `if(has_x && …)`, **`:648`, `:7178`, `:7186`, `:7302`, `:8636`, `:8642` do not**. Very likely reachable by the §2.2 recipe with `snap_cursor` instead of `draw_crosshair`; not isolated because `erase_crosshair` faults first |
| `callback.c handle_expose` | 2 more of 3 (`9935,9942`) | downstream of `:9929`, which always faults first |
| `draw.c draw_xhair_line` | 6 | called from `erase_crosshair`/`draw_crosshair` and `draw.c:6431` — same family as the crosshair crash |
| `draw.c draw_graph` | 5 of 9 (`9454,9457,9479,9482,9494`) | the other 4 are under `… && has_x`; these 5 are not |
| `draw.c draw_graph_points` | 6 | called from `draw_graph` |
| `draw.c draw_graph_bus_points` | 2 | ″ |
| `draw.c drawbezier` | 3 | called from `drawpolygon`/`drawtemppolygon` (Class G1) and `xinit.c:1198` |
| `draw.c set_thick_waves` | 2 | called from the graph drawers |
| `draw.c graph_snap_erase` | 1 | — |
| `draw.c hilight_cairo_set_source` | 1 (`:1627`) | — |
| `actions.c fix_restore_rect` | 4 | sole caller `draw.c:2733`, inside `drawtemprect` (Class G1) |
| `move.c draw_selection_impl` | 1 (`:276`) | callers `move.c:257,261` |
| `draw.c xserver_ok` | 3 (`68,69,75`) | the probe itself — not a defect; `:75` is the line item A changes |

---

## 8. Suites, check counts, and what did not change

406 `tests/headless/test_*.tcl`, `--nogui`, 150 s timeout, three passes:

| pass | PASS | `RESULT:` other | no `RESULT:` | SIGNAL | checks in the counted PASS suites |
|---|---|---|---|---|---|
| null build, `DISPLAY` unset | 244 | 93 | 65 | 4 | 12 347 over 156 suites |
| null build, `DISPLAY=:151 --nogui` | 245 | 92 | 65 | 4 | 12 355 over 156 |
| base build, `DISPLAY=:151 --nogui` | 245 | 92 | 65 | 4 | 12 355 over 156 |

The `RESULT: other` and no-`RESULT:` populations are **identical across all three passes** and
are an artefact of running each suite as a bare binary invocation rather than through
`run_suites.sh` (no armed HOME, no scratch, no display for the display-arm legs). They are
**not** findings of this crew and no claim is made about them. The only cross-pass difference
is the three check-count rows named in §4.

The four SIGNAL suites are the same four in every pass:
`test_hilight_case_senders`, `test_keybind_snap_grid`, `test_undo_selection`,
`test_window_switch_bogus_enter`.

CLI flags: all 42 long options plus `-x`, `--nogui` and 14 `-x`/`--nogui` × export
combinations ran with `DISPLAY` unset and with `DISPLAY=:151`; **no crash on either build**.
`--png` already refuses correctly: *"xschem: can not do a png export if no X11 present / Xserver
running (check if DISPLAY set)."* `--detach` and `--logdir` produce no `XHC-NOOP` line for
reasons unrelated to X (daemonising; `--nolog`/`--logdir` are mutually exclusive).

⚠ Note for whoever drives the fix round: `-x` / `--no_x` is a **third** route to `has_x == 0`
that neither 1483 nor 1492 mentions — it sets `has_x = 0` **without** `--nogui`, so
`cli_opt_nogui` stays 0 while the display is gone. Any guard written as "if `--nogui`" instead
of "if `!has_x`" will miss it.

---

## 9. Files changed, scratch, and housekeeping

* **Repository files changed by this crew: one — this receipt.** No product code, no test, no
  other document. `git status` in `/home/analog/dev/xschem-claude` is unchanged apart from it.
* All builds and edits were in the scratch clone `/var/tmp/xhc/A/t` (`git clone --shared` of
  `7e1e6a6f` plus the three generated files `Makefile.conf`, `config.h`, `src/Makefile`).
  Four binaries were built there: **base** (`-O2 -g`, unmodified), **null** (item A's one
  line), **tracer** (`-O0 -g`, live connection + `XSetErrorHandler`), **probe** (`-O2 -g`,
  null + 0227's `if(has_x)`).
* **Scratch peak size: 239 MB**, at `/var/tmp/xhc/A` only. Deleted by this crew; the root
  `/var/tmp/xhc` and any sibling crew's subtree were left alone.
* A private **Xvfb on `:151`** was used and stopped. The dev display `:99` was never touched,
  `HOME` was `/var/tmp/xhc/A/home` throughout, and `~/.claude`, `~/.xschem` and
  `~/dev/xschem-op-wcard` were not written.
* Every crash writes an emergency-save directory to `/tmp` (it ignores `TMPDIR`). The set
  present before this crew started was snapshotted and only the delta this crew created was
  removed.

## 10. Recommendations to the driver, in the order the evidence supports

1. **Land item A** — it is measurably free (no new red anywhere) and it removes the libxcb
   undefined-behaviour arm, which is the one shape that cannot be reasoned about.
2. **Item B is one line and it works** (§4.1) — but file the **second** landmine,
   `handle_expose` at `callback.c:9929`, before closing 0227, because 0227's "the rest of that
   function is unproven headless" is now proven false-optimistic by measurement.
3. **Item C needs a correction before it is worked**: `copy_hilights` is not a display defect,
   and 1492's `compare_schematics` / `copy_hilights` rows are swapped. Fixing three verbs by
   the `has_x` contract leaves a fourth crash that no `has_x` guard can touch.
4. **The new entry points belong in the same sweep as item C**, because they are the same
   contract broken in the same place — `scheduler.c`'s `grabscreen` branch arms a ui_state bit
   with no `has_x` guard, and `callback.c`'s crosshair/expose paths dispatch on Tcl variables
   and event type alone.
5. **Count them in `test_callback_argc`** (§5). It is already a T1 case, it already hard-codes
   the arm that makes `has_x` 0 on every box, and it already has three rows of exactly this
   shape.
