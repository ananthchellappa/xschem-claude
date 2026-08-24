# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

XSCHEM is a hierarchical schematic capture and netlisting EDA tool for VLSI/analog
custom design. It draws schematics and symbols and generates SPICE, Spectre, VHDL,
Verilog and tEDAx netlists. The drawing engine is plain C on top of Xlib primitives
(optionally Cairo for text/anti-aliasing); the GUI and the extension/scripting
language are Tcl/Tk.

## Build & run

```sh
./configure          # wraps scconfig; run from repo root. See ./configure --help
make                 # builds src/, xschem_library/, doc/, src/utile/
make install         # installs (honors DESTDIR=/tmp/pkg and PREFIX)
cd src && ./xschem   # run directly from the source tree, no install needed
```

- Build is **scconfig**-based (a self-contained ./configure system under `scconfig/`),
  not autotools. `configure` regenerates `Makefile.conf` and `config.h` from the
  `.in` templates — edit the `.in` files, not the generated ones (they carry a
  "DO NOT EDIT" header).
- Requires a C89 compiler, awk (mawk/gawk), Tcl/Tk 8.4–8.6, Xlib, Xpm, bison, flex.
  Optional: cairo, xcb, xrender.
- `src/Makefile` lists object files explicitly in `OBJ` — adding a new `.c` file
  means adding it to `OBJ` and adding an explicit compile rule (or regenerate from
  `Makefile.in`).
- A `CMakeLists.txt` exists as an alternative build but the Makefile path is canonical.
- **Editing `src/Makefile.in` obliges you to re-run `./configure`.** `src/Makefile`
  and `config.h` are generated, gitignored, and have **no self-regeneration rule**, so
  a corrected `Makefile.in` sits happily next to a stale `Makefile` and `make` never
  notices. The trap is invisible in-tree — `XSCHEM_SHAREDIR` resolves to `src/`, so a
  helper that was never added to the install list is still found — and fatal once
  installed: `make install` then ships an `xschem.tcl` that sources a file it did not
  install, and the installed binary **segfaults at startup** (exit 139, via issue 0423,
  where `Tcl_AppInit()` continues after a failed `source`). Issue 0424 is the measured
  case: 275 in-tree checks green, installed binary dead. Verify with
  `grep -c <newfile> src/Makefile` — expect 2, an install line and an uninstall line.

### Generated parsers (do not hand-edit the .c)
- `expandlabel.c`/`expandlabel.h` ← bison from `expandlabel.y` (bus/label expansion)
- `eval_expr.c` ← bison from `eval_expr.y`, prefix `kk` (expression evaluator)
- `parselabel.c` ← flex from `parselabel.l`

## Tests

Regression tests live in `tests/` and are driven by Tcl, comparing generated output
against golden files.

```sh
cd tests
tclsh run_regression.tcl        # runs all cases: create_save, open_close, netlisting
```

- Each case is a `<name>.tcl` script; `run_regression.tcl` execs them and greps
  `results.log` for `FAIL` / `GOLD?` / `FATAL`. To run one case, source its script
  directly (e.g. `tclsh netlisting.tcl`).
- Tests invoke the built binary headless via `xschem ... --pipe -q --script <file>`.
  `tests/test_utility.tcl` resolves it as **`$XSCHEM` → in-tree `src/xschem` →
  `PATH`**, so an uninstalled dev tree works out of the box (issue 0147 — it used
  to be a bare `xschem`, and with nothing installed the entire suite silently
  no-op'd while still printing a plausible `results.log`).
- **`create_save`, `open_close` and `netlisting` have no committed `gold/`
  baseline**, so they can only report `NOGOLD` — they run the cases and produce
  `<case>/results/`, but verify nothing until someone promotes a baseline. The
  trustworthy signal is the headless cases (which do have
  `tests/headless/gold/`), or running one directly:
  `./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl`.
- **Reading `results.log`:** a `FAIL` ending a line, `GOLD?`, `RESULT?` or a
  leading `FATAL` is counted. `couldn't execute "xschem"` or `exit 127` anywhere
  means the binary never launched and *nothing in that run is meaningful*
  (issue 0016 Part 4 distinguishes this from the benign rc=10 fall-through).
- `xschemtest.tcl` is a broader functional/perf harness, run as
  `xschem --script xschemtest.tcl` then calling `xschemtest`. Use `-d 3 -l log` to
  log allocations for leak checking.

### The persistent dev display (`tests/headless/devdisplay.sh`)
**Start this once and GUI testing stops touching your screen at all**, including
the case no wrapper script can reach — a bare
`./src/xschem --pipe -q --script tests/headless/<t>.tcl`, which is the most-typed
command in a session and which no arming script wraps.

```sh
tests/headless/devdisplay.sh start     # Xvfb :99 + openbox, ~0.3 s, idempotent
tests/headless/devdisplay.sh view      # x11vnc on localhost, to watch it
tests/headless/devdisplay.sh status|stop
```

**The human does NOT want `DISPLAY=:99` in their interactive shell**, and an
earlier revision of this section wrongly told them to put it in `~/.bashrc`. A
person launching xschem is launching it *to use it* — sending that to an
invisible display is the bug, not the fix. The armed entry points
(`full_audit.sh`, `run_suites.sh`, `gated_xschem.sh`, the 8 standalone
`test_*.sh`) already need nothing.

**The one consumer of the export is the assistant**, whose bare
`./src/xschem --pipe -q --script tests/headless/<t>.tcl` is typed dozens of
times a session and is armed by nothing. Two ways to cover it, in order:

1. **Launch the session as `DISPLAY=:99 claude`.** Tool shells inherit the
   Claude Code process's environment, so every bare invocation lands on the dev
   display and the human's own terminals keep `:0`. One word, no rc edits, and
   it does not depend on the assistant remembering anything.
2. **Failing that — assistant, route it yourself**: `tests/headless/devdisplay.sh
   exec ./src/xschem --pipe -q --script <t>.tcl`, or run suites through
   `run_suites.sh`. Never a bare `./src/xschem --script` on a live `:0` unless
   the point *is* the real screen.

Note `~/.bashrc` cannot serve purpose 1 here anyway: it returns at its line 6–9
for non-interactive shells, and the Bash tool's shell is non-interactive
(`$- = hmtBc`). It inherits its environment; it does not source that file. (An
earlier claim in this section that it *is* sourced was wrong — inferred from
`~/eda/bin` being on `PATH`, which arrives by inheritance.)

`shellinit` remains, for the narrow case it fits: a **dedicated terminal used
only for running tests by hand**. It emits a *conditional* export, because an
unconditional one in an rc outlives the display it names — after a reboot or a
`stop`, every GUI program in that shell dies with `cannot open display`. **The
display does not survive a reboot**; re-run `start`.

The arm (below) **attaches** to it when it is up, so every entry point lands on
one stable display. `:0` becomes the opt-in (`AUDIT_DISPLAY=:0`), which is the
right way round — the only thing that still needs it is reproducing
Xwayland-specific defects. Side wins: immune to the WSLg Xwayland aborts that
kill `:0` clients ~3×/session, and no per-run Xvfb spawn.

### ⚠ THERE ARE THREE X SERVERS HERE, AND `:0` IS NOT THE USER'S SCREEN

Measured 2026-08-22 with `xdpyinfo`, all three live at once:

| display | vendor string | what it is |
|---|---|---|
| `:0` | `Microsoft Corporation` | **Xwayland**, WSLg's own server |
| `$DISPLAY` = `<win-ip>:0` | `HC-Consult` | the **Windows X server** the user actually looks at, over TCP |
| `:99` | `The X.Org Foundation` | Xvfb, the persistent dev display |

`$DISPLAY` comes from `~/.profile:48` (`export DISPLAY="$WINDOWS_IP:0"`). Note
`~/.bashrc:152-153` would override it to `:0` when `WAYLAND_DISPLAY` is set — and
it *is* set — but bashrc returns early for non-interactive shells, so a tool shell
keeps the TCP display and an interactive terminal may not. **Check `$DISPLAY`
rather than assuming.**

**This matters because `AUDIT_DISPLAY=:0` exports the LITERAL string `:0`**
(`tests/headless/xvfb_arm.sh:140`), not `$DISPLAY`. So:

* every `:0` measurement recorded below — the flake rates, the 3-vs-1
  `<Configure>` traffic, the Calculator phase-0 failures, `test_wave_modes` at
  6.2–45.6 s — was taken against **Xwayland**, and the WSLg attributions in this
  section are correct;
* a **bare** `./src/xschem --script …` inherits `$DISPLAY` and therefore lands on
  the **user's real screen**, a different server from the one the suites call
  `:0`. That is the reason for the "never a bare run on a live `:0`" rule above,
  and it is a sharper reason than it sounds: the two are not the same X server;
* **"run a GUI feature's suite on `:0`" means Xwayland**, not the user's screen.
  A look debt that says "on the real VcXsrv screen" — issue 0413's does — is
  asking for something `AUDIT_DISPLAY=:0` **cannot** provide. Pay that one with
  `AUDIT_DISPLAY=$DISPLAY`, or by hand from a terminal.

Do not "correct" WSLg to VcXsrv in this file. Both are here; they are different
displays; the distinction is the load-bearing part.

`_gate_enabled` returns false on the dev display, deliberately: an invisible
display would otherwise arm the gate and `_gate_attention` would relaunch the
user's Pause panel where nobody can see it. Spec: `doc/claude/specs/dev_display.md`.

**Two platform traps recorded there**: under WSLg `/tmp/.X11-unix` is mode 777
without the sticky bit, so Xvfb binds only the *abstract* socket
`@/tmp/.X11-unix/XN` and a `[ -S /tmp/.X11-unix/XN ]` readiness poll is always
false; and `xdpyinfo` against a dead display **hangs** on the TCP fallback rather
than failing — check the listen state before probing.

### The owed ledger (`tests/headless/owed.sh`)
Three debts still cost the user's attention, and they used to arrive scattered —
one at a time, whenever a feature happened to finish, and out of *two different
files*. Record them instead, pay them in one batch:

```sh
owed.sh add rule  <id> [why] [--eyes]  # owes the USER a RULING (a driver run's
                                       #   E questions; --eyes if it cannot be
                                       #   decided without looking at pixels)
owed.sh add look  <what> [why]         # owes the USER's eyes (pixel deliverables)
owed.sh add suite <name> [why]         # owes a :0 run ("run a GUI feature's
                                       #   suite on :0 once before calling it done")
owed.sh list | count | show            # `show` = the user's queue: rule + look
owed.sh drain                          # runs the SUITE debts, one batch, gate live
```

**`rule` and `look` are the user's queue; `suite` is not.** A suite debt clears
itself on a pass. A **rule or look debt clears only when the user says so**
(`clear rule <id>` / `clear look <id>`), and no command converts one kind into
another — `drain` does not so much as open the other two lists. A ledger that
discharged an eyeball because a suite went green would be exactly the defect
that rule was written about (two defects shipped past 28 passing checks), and
one that closed a *ruling* that way would be the same defect wearing a tie.

**A rule entry is a pointer, not a copy.** The option set stays in
`doc/claude/issues/NNNN-*.md`; `add rule` resolves the path from the id. Spec:
`doc/claude/specs/owed.md` (§6 for why `rule` exists).

Assistant: `add` at the moment the debt is incurred; it costs nothing and is the
only thing that makes the batching possible. Never report a pixel deliverable
"done" on a green suite — record a `look` and say "suites green, please look".
Never leave a step's unratified user-visible decision in a write-up only —
record a `rule`, or the user never sees it was theirs to make.

### The display arm: Xvfb by default (`tests/headless/xvfb_arm.sh`)
`full_audit.sh`, `run_suites.sh`, `gated_xschem.sh` and the 7 window-mapping
standalone `test_*.sh` suites run on the persistent dev display if one is up,
otherwise a **private Xvfb**, and no longer
borrow the screen they were launched from. That is the routine arm because it is
measured better, not merely quieter: 30/30 soak with identical check counts where
the same suites on `:0` flake 4-in-10 / 2-in-3 / 1-in-5, a full audit reproducing
the recorded `:0` fail list exactly, and `test_wave_modes` at 2.3 s against
6.2–45.6 s. Knobs: `AUDIT_DISPLAY=:0` (Xwayland — **not** the user's screen,
see the three-server table above; use `=$DISPLAY` for that), `=none` (no DISPLAY, GUI
legs self-skip), `AUDIT_SCREEN=WxHxD` (default `1920x1080x24` — **pin it**, and
never `1600x1200`, the one size `test_fluid_bodyshove_guards_0132` fails at).

**`GUI_GATE=0` is forced on the Xvfb arm, not defaulted.** `_gate_enabled` only
checks that `$DISPLAY` is non-empty, so a virtual display arms the gate; then
`gate_start` → `_gate_attention` kills the live panel and relaunches it on the
invisible display, for every session sharing the control dir. Xvfb without
`GUI_GATE=0` doesn't free the screen, it breaks Pause.

**A window manager runs inside the virtual session** (`AUDIT_WM`, default
`openbox`; `none` for the old empty-Xvfb behaviour). Measured: empty Xvfb does
not reparent and silently no-ops `wm iconify`; with a WM both work — and on
iconify a real WM is *more* faithful than WSLg, which doesn't honour it either.
So decoration/iconify/stacking/raise are no longer a reason to reach for `:0`.

⚠ **`openbox` WAS MISSING UNTIL 2026-08-23** (issue 0645). It is installed now
(`/usr/bin/openbox`, Openbox 3.6.1, verified), so `xvfb_arm.sh:154`'s default
finally resolves and a WM really is live. But **every WM-dependent measurement
recorded before that date was taken WM-less** — `:156` falls back to no WM with
only a stderr warning, so suites that believed they had a window manager did not.
Re-measure rather than trusting an older number.

The fallback path is still real (another box, a stripped container), so the rule
stands: a suite whose subject is reparenting, iconify, stacking or raise **must
say in its report which WM was actually live**, and if it needs to be certain it
should name one explicitly — `AUDIT_WM=openbox`, or `AUDIT_WM=xfwm4` as issue
0616's did (`xfwm4 --compositor=off`; `/usr/bin/xfwm4` is also present). A report
that omits the WM is a bare-Xvfb measurement wearing a window manager's name, and
it will pass while the bug is live. The warning line is not cosmetic; it is the
difference between evidence and nothing.

**Xvfb is still not a substitute for `:0`** for a human eyeball, or for Xwayland's
own quirks. The sharpest of those is **event traffic**: one `wm geometry`
request yields 3 `<Configure>` events on `:0` against 1 under Xvfb with or
without a WM, and Calculator phase 0 passed 49/49 under Xvfb while failing 3
checks on `:0` for exactly that reason. **Run a GUI feature's suite on `:0` once
before calling it done** — but treat a bug that only `:0` can reproduce as a
*test* defect too: the fix is to force the race deterministically
(`test_calc_skeleton` S12), not to hope an environment supplies it.

### GUI-test control gate (`tests/headless/gui_gate.sh`)
Running a suite under a real/WSLg `$DISPLAY` pops a **control panel**
(`tests/headless/gui_gate_widget.tcl` via `wish`) that **warns before the
suite runs** (Proceed / Snooze 5·15·30 min) and gives a **Pause/Resume toggle
+ Stop** during it — the GUI suite otherwise floods the display and makes the
machine unusable. The gate lives in the harness (`gui_gate.sh`), **not** a
Claude Code settings hook (a prior hook-based gate silently died when
`settings.local.json` was rewritten — do NOT reintroduce it as a hook). Control
dir `~/.claude/gui_test_gate/` is shared by the main session and all
worktree/subagent runs, so one Pause pauses every suite. It **fails open** (no
`DISPLAY`, `GUI_GATE=0`, or a closed panel → tests just run) so CI/headless is
unaffected. Spec: `doc/claude/specs/gui_test_gate.md`.

Since the default arm became Xvfb the panel should be **rare** — it now guards
the deliberate `AUDIT_DISPLAY=:0` runs, not the everyday ones. A panel popping
for a routine suite means something bypassed `xvfb_arm.sh`.

**Don't press Proceed forty times.** Many small runs each cost a click, or a
2-minute autostart wait with nobody at the desk. Press **`Allow 30m` / `Forever`**
once and every suite in that window starts unprompted — Pause and Stop keep
working throughout, and the panel shows how many have run. Approving *before*
launching a batch works too.

**Getting a run under the panel's control:** `run_suites.sh` (preferred, reports
PASS/FAIL and gives a pause point between runs) or `gated_xschem.sh` as a
drop-in for `./src/xschem` in a hand-written loop. A bare
`for i in ...; do ./src/xschem --script t.tcl; done` enrols in neither, so Pause
cannot reach it — the panel lists such processes as `UNGATED` and the
**`Halt N xschem`** button (SIGSTOP, resumable) is the only authority over them.

## Architecture

### The `xctx` global context
Almost all program state hangs off a single global `Xschem_ctx *xctx` (defined in
`xschem.h`, ~`Xschem_ctx` struct). It holds the current schematic's object arrays
(`wire`, `inst`, `sym`, `rect[layer]`, `line[layer]`, `poly`, `arc`, `text`),
the hierarchy stack (`sch[CADMAXHIER]`, `sch_path[]`, `currsch`), zoom/pan state,
selection (`sel_array`), spatial hash tables, undo slots, highlight/node tables, and
the drawing GCs/colors. When reading or modifying behavior, the relevant fields are
usually grouped in the struct with comments pointing to the owning `.c` file
(e.g. `/* move.c */`, `/* callback.c */`). Multiple open windows/tabs each have their
own context — see `get_save_xctx()` / `get_old_xctx()` and the tabbed-interface logic
in `xinit.c`.

Core object types (`xWire`, `xRect`, `xLine`, `xPoly`, `xArc`, `xText`, `xInstance`,
`xSymbol`) are all defined together near the top of `xschem.h`.

### The `xschem` Tcl command — central dispatcher
The C core exposes essentially all functionality through one Tcl command, `xschem`,
registered in `xinit.c` (`Tcl_CreateCommand(interp, "xschem", ...)`) and implemented
by the giant dispatcher `scheduler()` in `scheduler.c` (function `xschem(...)`). Tcl
scripts, menus, keybindings and tests all drive the editor by calling
`xschem <subcommand> ...` (e.g. `xschem load`, `xschem netlist`, `xschem hilight`,
`xschem get xorigin`, `xschem callback ...`). **When adding a new user-facing
operation, you add a branch in `scheduler.c` and usually wire it up from Tcl** rather
than inventing a new C entry point. GUI events are funneled in as
`xschem callback <win> <event> ...` → `callback()` in `callback.c`.

### Layering: C engine ↔ Tcl GUI
- `src/xschem.tcl` (~12k lines) is the Tcl GUI: menus, dialogs, simulation launchers,
  preferences. Many config variables are deliberately **mirrored between C and Tcl**
  (search `MIRRORED IN TCL` in `xschem.h`) — keep both sides in sync when changing one.
- Other `.tcl` files are loadable helpers (`mouse_bindings.tcl`, `place_pins.tcl`,
  `create_graph.tcl`, `*_backannotate.tcl`, custom menu/button hooks).
- The C side reads/writes Tcl variables via helpers like `tclgetvar`,
  `tclgetboolvar`, `tcleval`.

### Drawing
`draw.c` is the rendering core over Xlib (with `#if HAS_CAIRO` paths for text/images;
`svgdraw.c` and `psprint.c` produce SVG and PostScript/PDF output). `font.c` holds the
vector font. Spatial hash tables in `xctx` (`*_spatial_table[NBOXES][NBOXES]`)
accelerate hit-testing and selection.

### Netlisting
`netlist.c` is the shared hierarchy traversal and node-naming machinery; per-format
backends are separate files: `spice_netlist.c`, `spectre_netlist.c`,
`vhdl_netlist.c`, `verilog_netlist.c`, `tedax_netlist.c`. Label/bus expansion goes
through the bison/flex parsers. Highlighting and node tracing live in `hilight.c`,
`findnet.c`, `node_hash.c`.

### Editing pipeline
`actions.c` (largest file — high-level edit ops), `move.c`, `paste.c`, `clip.c`,
`select.c`, `editprop.c` (property/attribute editing), `store.c` (object allocation),
`save.c` (the `.sch`/`.sym` file format I/O), `check.c` (ERC/symbol consistency),
`in_memory_undo.c` (undo can be on-disk or in-memory; chosen via the `push_undo`/
`pop_undo` function pointers in `xctx`).

### awk scripts
The many `*.awk` scripts in `src/` are import/convert/flatten utilities (e.g.
`gschemtoxschem.awk`, `make_sym_from_spice.awk`, `flatten.awk`). They are part of the
shipped toolchain, invoked from Tcl, not build-time codegen.

## Symbol & schematic libraries
`xschem_library/` holds the standard device symbols (`devices/`) plus example
designs and generators. The library search path is configured in `Makefile.conf`
(`xschem_library_path`) and overridable in `~/.xschem/xschemrc` or a `./.xschemrc`.
`.sym` (symbol) and `.sch` (schematic) share the same text record format handled by
`save.c`; the format version is `XSCHEM_FILE_VERSION` in `xschem.h`.

## Conventions
- C89 throughout; the codebase targets both Unix and Windows (`XSchemWin/` holds the
  Windows config). Guard platform code with `__unix__`.
- Memory tracking: allocations use id-tagged wrappers (`my_malloc`, `my_realloc`,
  `my_strdup`, etc.) whose first arg is the placeholder macro `_ALLOC_ID_`. The
  `create_alloc_ids*.awk` / `get_malloc_id.awk` scripts rewrite those placeholders
  into unique numeric ids for leak tracing — write `_ALLOC_ID_`, don't hand-number.
  Debug logging via `dbg(level, ...)`.

## AI / planning docs
Design and working notes live under `doc/claude/` (not installed — `doc/Makefile`
ships only `*.svg/*.html/*.css/*.png`): `doc/claude/specs/` (feature specs),
`doc/claude/issues/` (numbered issue tracker, `NNNN-*.md`), `doc/claude/code_analysis/`
(analysis & decision write-ups), `doc/claude/suggestions/` (session prompts, plans), and
`doc/claude/FAQ.md` (a running design Q&A, newest entries on top).
Source comments reference these by their full path (e.g. `see doc/claude/specs/foo.md`).

**Wiring work**: before touching anything that creates, moves, deletes, or reroutes wires
(move.c, the fluid passes, trim/break/merge, connected drag/rotate/flip), read
`doc/claude/WIRING.md` — data model, END pipeline, pass contracts, landmines, open risks.
Keep it updated when fixing wiring issues.
