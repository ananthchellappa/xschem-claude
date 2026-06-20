# Tutorial 0016 — Making a Tk app truly headless, and telling code regressions from environment noise

**Written:** 2026-06-19
**Status:** Reference / lessons-learned (the `--nogui` feature itself is DONE)
**Companion to:** the `--nogui` commits on `feature/headless` (e6308aa3, e407a481)
and `fluid-editing` (ff86b147, 2750bd54)
**Audience:** anyone adding a batch/headless mode to a C+Tcl/Tk program, or
debugging a regression suite that "fails on my branch."

This is a post-mortem of a deceptively small task — "add a `--nogui` flag" — that
turned into a clinic on *testing the invisible* and *not trusting a green (or red)
suite until you know why it is green (or red)*. The feature was ~20 lines. The
learnings are the valuable part.

---

## Part 1 — What actually makes xschem windowed, and how `--nogui` flips it

The whole GUI hinges on one global, `has_x`, and one fork in `main.c`:

```c
/* main.c (~line 145) */
if(has_x) Tk_Main(1, argv, Tcl_AppInit);   /* builds the Tk window + event loop */
else      Tcl_Main(1, argv, Tcl_AppInit);  /* pure Tcl: no Tk, no window, ever */
```

`has_x` is set in two places:
- `main.c` → `xserver_ok()` (`draw.c:63`) returns 1 whenever `$DISPLAY` is set and
  connectable.
- `options.c` → `-x/--no_x` (and now `--nogui`) force `has_x = 0`.

`Tcl_AppInit` (`xinit.c:2514`) only calls `Tk_Init` when `has_x` is true. So when
`has_x == 0`, **Tk is never loaded** — and that fact is the lever for testing (Part 3).

**The lesson about "headless" that bites everyone:** the regression harness ran the
binary with `--pipe -q`. Neither flag touches `has_x`. `--pipe` only disables
readline; `-q` only quits-after. With `DISPLAY` set (the normal dev/CI case),
`xserver_ok()` returns 1 → `Tk_Main` → a window opens and operations render on
screen. "Headless" in the test scripts meant "no interactive console," **not**
"no window." The existing `-x` flag already forced `has_x=0` but was undiscoverable
and unused by most of the suite.

`--nogui` is therefore tiny — it is `-x` with a discoverable, Cadence-style name plus
a recorded intent flag:

```c
/* options.c */
} else if( type == LONG && !strcmp("nogui", opt) ) {
    cli_opt_nogui = 1;   /* explicit headless intent, distinct from "no DISPLAY" */
    has_x = 0;
}
```

`cli_opt_nogui` (global in `globals.c`, extern in `xschem.h`) currently only mirrors
`has_x=0`, but it lets future code distinguish *"user asked for headless"* from
*"there happens to be no display,"* so GUI-only operations (e.g. raster export) can
fail with a clear message instead of silently no-op'ing.

---

## Part 2 — Testing the invisible: how do you assert "no window opened"?

You cannot screenshot the absence of a window, and you cannot ask X "did anyone
*not* map a window." The trick is to assert against a **necessary precondition**
instead of the symptom:

> If Tk was never loaded, then no Tk top-level can possibly have been mapped.

In headless mode `Tk_Init` never runs, so **none of Tk's commands exist**. That is
directly observable from inside the interpreter:

```tcl
# tests/headless/test_nogui.tcl
check_expr {[llength [info commands winfo]] == 0} "Tk not loaded (winfo absent)"
check_expr {[llength [info commands wm]]    == 0} "Tk not loaded (wm absent)"
check_expr {[llength [info commands tk]]    == 0} "Tk not loaded (tk absent)"
check_expr {![info exists has_x]}               "has_x Tcl var unset (headless path)"
```

Then prove the engine still does real work headless (load + netlist). The runner
(`tests/headless/run_nogui.sh`) deliberately keeps `DISPLAY` set, so the test proves
the strong claim: *`--nogui` wins even when an X server is available.*

**Sabotage check (mandatory — see the green-but-hollow lesson):** run the *same*
script *without* `--nogui`. It must FAIL the Tk-absent assertions. It does — in GUI
mode `winfo`/`wm`/`tk` all exist and `has_x` is set. That proves the test is
actually exercising the flag and is not vacuously green.

**Transferable rule:** to test that something *didn't* happen, find an invariant that
is *only* true in the desired state, assert it, and then prove the assertion can fail
by running the other path.

---

## Part 3 — The two traps that ate an hour (the real value of this document)

The feature worked on the first build. Then wiring the flag into the regression
suite produced terrifying numbers: `open_close` FATAL=**1893**, `netlisting`=**728**,
`create_save` going 0→5. It looked like `--nogui` had detonated the suite. It had
not. Two compounding illusions:

### Trap A — A "passing" baseline that was actually hollow

`create_save`'s original command had **no `-q`** and ran in GUI mode; the per-test
scripts end with `xschem exit closewindow`. Under a cooperative window manager that
exits cleanly. Headless (or under a degraded WSLg compositor) the window never
closes, so the process **hangs** and the outer `timeout` kills it — producing an
*empty* output file. `grep -c FATAL` on an empty file is `0`. So the "baseline =
0 FATALs" I trusted was a **timeout with no output**, not a success. Always confirm a
green result produced the *artifacts* it should (here: saved `.sch` files, a
non-empty log, exit code 0) — not merely the absence of the failure string.

### Trap B — An environment failure masquerading as a code regression

The harness invokes the binary as bare `xschem` (`set xschem_cmd "xschem"`) through
Tcl `exec`, so `argv[0]` is `"xschem"` — **no slash**. xschem's sharedir detection
(`xinit.c:2532`, "Priority 2: executable-relative") is explicitly gated on
`strchr(xschem_executable, '/')`. No slash → that whole branch is skipped → it falls
through to the **compile-time** `/usr/local/share/xschem` (Priority 4), which is not
installed in this dev tree → `cannot find .../xschem.tcl` → every subtest FATALs.

This is **flag-independent and pre-existing**: it hits `-x`, `--nogui`, and plain
`--pipe` identically. It only *looked* like `--nogui` caused it because Trap A made
the `--pipe` baseline hang (empty → 0 FATAL) while the faster-failing `--nogui` path
errored out loud (5 FATAL). Two different failure *modes* of the *same* root cause,
mistaken for a before/after delta.

**The fix for local runs** is one line — give the binary a way to find its share dir:

```sh
export XSCHEM_SHAREDIR="$PWD/src"     # Priority 1: env var beats everything
# ...or `make install`, or invoke the binary by a path containing a '/'.
```

With that set, baseline and `--nogui` both produce **FATAL=0** across
`create_save` / `open_close` / `netlisting`. The 1893 and 728 evaporated entirely.

### The method that cut through both traps

Isolate the *one* variable. Toggle only the flag via `git stash`, run the *exact*
harness both ways back-to-back in the *same* environment, and compare — but inspect
**full output and artifacts**, not just a grep count:

```sh
git stash push -q tests/*.tcl          # revert to baseline flags
run_suite ; capture full logs + saved files + exit codes
git stash pop -q                       # restore --nogui edits
run_suite ; compare
```

The moment I captured *exit codes* (124 = timeout, not 0) and *which sharedir line*
the binary printed (`Using compile-time XSCHEM_SHAREDIR = /usr/local/...`), both
illusions collapsed. A bare `FATAL` count would never have revealed either.

---

## Part 4 — Smaller gotchas worth remembering

- **`-q` exits non-zero on fall-through.** An xschem `--script` that simply reaches
  end-of-file under `-q` exits with a non-zero code (observed rc=10), which Tcl
  `exec` reports as "child process exited abnormally." End headless test scripts with
  an explicit `exit 0` on success so the runner gets a clean code. (Note:
  `run_regression.tcl`'s last line has always thrown this benign error for the
  `xschemtest.tcl` source-check; it is cosmetic and post-dates all real tests.)

- **Sourcing ≠ running.** `xschem --script xschemtest.tcl` only *defines* procs;
  the actual `xschemtest` call at the bottom of the file is commented out. So even
  though those procs call `wm`/`update` (pure Tk), `--nogui` is safe there — verify
  a script has no top-level GUI statements before assuming it needs a display.

- **Per-branch `./configure`.** `feature/headless` (off master) and `fluid-editing`
  have different `src/Makefile.in` object lists — `util.c` (defines
  `my_calloc`/`my_strdup`) is in fluid-editing's list but not master's. Switching
  branches and reusing a stale generated `Makefile` link-fails with
  `undefined reference to my_calloc`. Re-run `./configure` after switching branches,
  then `make clean && make`.

---

## TL;DR checklist for "add a headless/batch mode"

1. Find the single gate between the windowed loop and the headless loop
   (here `has_x` → `Tk_Main` vs `Tcl_Main`); add your flag to flip it.
2. Test the *absence* of a window via a precondition that is only true headless
   (Tk commands absent), and sabotage-check it by running the GUI path.
3. Before believing any before/after suite delta, **set the environment the binary
   needs** (here `XSCHEM_SHAREDIR`) — an unresolved runtime dependency dwarfs your
   change and fails every row identically.
4. Compare baseline vs change by toggling **one** variable (`git stash`), in the
   **same** environment, inspecting **exit codes + artifacts**, not just grep counts.
5. A green result is hollow until you confirm it produced what it should; a red
   result is meaningless until you know whether it reproduces at baseline.
