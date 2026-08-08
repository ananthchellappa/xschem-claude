# Xvfb for the GUI test arm — what it fixes, what it cannot, how to use it

**Status:** measured report, 2026-08-08, on `fluid-editing` at `00530250`, binary
`src/xschem` built 2026-08-08. Xvfb `2:21.1.12-1ubuntu1.6` (X.Org 21.1),
`xvfb-run` present. Every number below was produced on this box by the commands
quoted in §8 — nothing is quoted from another machine or another day unless it
is explicitly labelled *historical control*.

**One-line verdict:** Xvfb's advantage is not that it renders better — it is that
it is a **second, private, disposable X server**, and that single property
removes four whole failure classes we have been paying for — the WSLg Xwayland/weston aborts, the display flood that
makes the PC unusable, the serialisation of every GUI suite onto one desktop,
and the geometry/focus flakes that come from a real window manager moving our
windows around. It is a game changer for **throughput and unattendedness** —
and, measured here, it is also **faster and far more repeatable** than WSLg
(§3.3). It is **not** a substitute for the `:0` arm before shipping visible UI,
and it is not a window manager.

**What it is not, in one line:** it does not make a failing test pass. Every
`:0` baseline failure failed here too; the four apparent differences resolved to
three pre-existing failures, one screen-size-sensitive test, and one
timeout budget — none of them caused by Xvfb (§3.1, §3.2).

---

## 1. What Xvfb actually is (and what it is not)

- It is a **real X server** — same protocol, same Xlib, same Tk. It renders into
  an in-memory framebuffer instead of a screen. Tests do not know the difference:
  drawing, `event generate`, XTEST, `winfo`, cairo, Xpm all work.
- Measured on this box: `1600x1200x24`, 23 extensions including **RENDER,
  XTEST, XFIXES, SHAPE, MIT-SHM, DOUBLE-BUFFER, XKEYBOARD** — everything xschem
  and Tk ask for. ~65–90 MB RSS per server, ready in under 2 s.
- It is **not** a compositor and **not** a window manager. Nothing reparents,
  decorates, stacks, iconifies or focuses windows unless a client does it itself.
  This is the source of both its main advantage and its main limitation (§3, §5).
- It is **not** `--nogui`. `--nogui` means *no X at all, no Tk loaded*; Xvfb
  means *full Tk, full drawing, on a display nobody can see*. They cover
  different halves of the suite and neither replaces the other (§4.3).

## 2. The WSLg failure classes, and what Xvfb does to each

The left column is the failure catalogue this repo has accumulated (memories
`wslg-xwayland-aborts`, `tg9-root-coords-wslg-flake`, `wslg-key-delivery-flakes`,
`ase-test-flakes-wslg-gestures`, `gui-test-gate`, plus the receipts cited in §8).

| WSLg failure class | mechanism | under Xvfb |
|---|---|---|
| **Xwayland aborts ~3×/session** (`(EE) request could not be marshaled`, SIGABRT) — every client on `:0` dies, Tk dies without running `WM_DELETE_WINDOW`; whole suites come back `NORESULT (exit 1)` | a bug in WSLg's software-render fd marshalling | **GONE.** Our server, our lifetime, no compositor in the path. Already relied upon in `doc/claude/signal_browser_2pane_batch/13_receipt.md`: *"the Xvfb arm is immune to the third"* |
| **weston itself SIGABRTs (mode B)** — `:0` is bound but nothing answers for ~3 s; clients connect and hang with no error, no exit, no window | WSLGd restarts the compositor before Xwayland exists | **GONE**, same reason. Also removes the whole revive/adopt problem the gate had to grow (`gui_gate.sh` v6) |
| **The display flood** — a GUI suite maps hundreds of windows and the PC is unusable; the entire `gui_test_gate` machinery (panel, Proceed, Snooze, Pause, autostart, revive, brake) exists to make that tolerable | tests share the user's one desktop | **GONE.** Nothing is visible. The gate becomes unnecessary for this arm — and **must be turned off explicitly**, see §6.2 |
| **One desktop = one suite at a time**; parallel worktree/subagent runs steal each other's focus | shared focus, shared pointer, shared stacking | **GONE — one display per runner.** `:98`, `:99`, … are fully isolated; a probe on `:98` cannot touch a soak on `:99` |
| **Synthetic-key loss ~1 run in 5** (`test_wave_modes` MG16, `test_ase_plot` P4, `test_wave_clear_all` CG5/6) | keys go to the DISPLAY's focus window and the WSLg focus round-trip is asynchronous | **Strongly reduced**, not by magic: with no WM there is nobody to arbitrate focus, so `focus -force` takes effect immediately. Measured: §3 |
| **TG9 "posted in ROOT coordinates" — 4-in-10 on a pristine tree**; and the sibling TR3/TR4/TS8 legend-slot legs, *"10 FAILED (313 passed) in two runs out of three on PRISTINE HEAD"* | the WM reparents/moves the viewer between legs, so Tk's synthesised `%X/%Y` lag `winfo rootx` | **Measured 0 failures in 10 runs** (§3) — nothing moves a window that no WM manages |
| **`test_ase_plot` silently degrading to 30 checks** instead of 145 when WSLg geometry misbehaves (a green banner over a skipped body) | geometry probe fails → the gesture body self-skips | **150 checks every run** (§3). The body actually ran |
| **Stale mouse cursor** (WSLg stops repainting the pointer; cured only by `wsl --shutdown`) | Windows-side RDP client | Not applicable — there is no visible pointer. Also means Xvfb **cannot** find that class of bug either |

## 3. The measurement

**Soak, 30 runs, `DISPLAY=:99 GUI_GATE=0 tests/headless/run_suites.sh -n 10
test_wave_trace_menu test_ase_plot test_wave_modes`** — the three suites whose
WSLg flake rates are the best documented in this repo.

| suite | historical failure rate on `:0` | Xvfb ×10 | checks, every run |
|---|---|---|---|
| `test_wave_trace_menu` (TG9 + legend-slot legs) | 4-in-10 (TG9, pristine tree); a separate legend-slot family 2-in-3 on pristine HEAD | **10/10 pass** | **397** |
| `test_ase_plot` (P4/P6/P8 gestures) | 1–2 in 10, *"and always have"*; degrades to **30** checks when it half-runs | **10/10 pass** | **150** |
| `test_wave_modes` (MG16 key delivery) | ~1 in 5 for the bare `event generate` form | **10/10 pass** | **488** |

**`RESULT: 30/30 runs passed`** — 12:33:57 → 12:50:38, **16 min 41 s** for 30
GUI suite runs (~33 s each), unattended, nothing on screen, machine usable
throughout (loadavg ~1.1 of 14 cores).

**The counts are the anti-hollow control, and they were checked against `:0` on
the same tree, same binary, the same afternoon:**

```
:0  PASS | test_wave_trace_menu  RESULT: ALL PASS (397 checks)
:0  PASS | test_ase_plot         RESULT: ALL PASS (150 checks)
:0  PASS | test_wave_modes       RESULT: ALL PASS (488 checks)
```

Identical to the Xvfb numbers, so **Xvfb is running the same legs, not a
skipped subset** — the check count is the signal this repo already uses to tell
a real `test_ase_plot` run (145–150) from a self-skipped one (30). What changes
between the two arms is not what runs; it is whether it runs *the same way
twice*: ten Xvfb rounds produced three constants, where `:0` has produced
documented rates of 4-in-10, 2-in-3 and 1-in-5 on unmodified trees.

(The `:0` control passed 3/3. That is not a contradiction — these are 1-in-N
flakes, and three green runs is the common case. The claim is about variance
across ten rounds, not about `:0` being unable to pass.)

**Full audit, `DISPLAY=:99 GUI_GATE=0 tests/headless/full_audit.sh`** — the whole
suite, unattended, nothing on screen, **711.96 s (11 min 52 s)**:

| | |
|---|---|
| PASS | **279** |
| FAIL | **18 tests** (24 `FAIL` lines; 6 of them are inner legs of `test_selflog_output`) |
| TIMEOUT | 1 (`test_placement_wire_gate`) |
| **SKIP** | **0** |

**Zero skips is a result, not a detail.** GUI tests self-skip when `$DISPLAY` is
unset (`RESULT: SKIP (no X)`), so a display-less box gives a green-looking audit
that never exercised a canvas. Xvfb runs all of them.

**The fail list is the `:0` baseline's fail list.** Compared against the contract
recorded in `doc/claude/signal_browser_batch/receipts/baseline_2026-08-04.md`,
**all 15 of its RECONFIRMED-HARD names failed here too**, none missing:
`test_ase_log_seam_0207`, `test_ase_window`, `test_cadence_drag`, `test_ciw`,
`test_gf180mcud_libmgr`, `test_ihp_sg13g2_libmgr`, `test_lib_manager_gui`,
`test_lib_manager_locate`, `test_lib_sweep`, `test_phase3_mints`,
`test_reopen_readonly`, `test_rotate_stretch_short_0104`, `test_select_at`,
`test_selflog_output`, `test_sky130a_libmgr`.

### 3.1 The four differences, each chased down

Four names differed from that baseline. Each was re-run **twice on Xvfb and twice
on `:0`, same tree, same binary**, via `full_audit.sh <names>`:

| test | Xvfb ×2 | `:0` ×2 | verdict |
|---|---|---|---|
| `test_save_as_cellview` | FAIL | **FAIL** | pre-existing; the baseline is 4 days and many commits old |
| `test_untitled_reuse` | FAIL | **FAIL** | pre-existing (fails on UR4b with `window name "x1" already exists in parent`) |
| `test_placement_wire_gate` | TIMEOUT | **TIMEOUT** | pre-existing hang, both arms |
| `test_fluid_bodyshove_guards_0132` | FAIL | **PASS** | the **only** real divergence — and it is not Xvfb, see below |

**One test in 283 diverged, and the cause is the SCREEN SIZE, not the server.**
`test_fluid_bodyshove_guards_0132` is pure scripted geometry (`place_symbol`,
`move_objects 20 0 stretch kissing`) — no events, no pointer, no WM. Sweeping
the virtual screen geometry, with everything else held fixed:

| virtual screen | verdict |
|---|---|
| 1280x1024 (`xvfb-run`'s default) | **ALL PASS** ×2 |
| 1600x900 | ALL PASS |
| **1600x1200** (the size this report started with) | **FAIL** ×5 — and unstably, 1 fail in some runs, 2 in others |
| 1920x1080 | ALL PASS |
| 2560x1440 | ALL PASS |
| 5120x1440 (= the WSLg `:0` size) | ALL PASS |
| `--nogui` (no X at all) | ALL PASS |

The canvas is the same size in every case (`.drw` = 1112x695) and so are `zoom`,
`xorigin`, `yorigin` — so a scripted geometry test is reading something
environment-dependent it should not be. **That is a latent defect in the shove
path (or in the test), and it is worth filing:** `:0` cannot see it because WSLg
happens to be 5120x1440, and `--nogui` cannot see it because it never has a
screen. Xvfb found it by accident, in one afternoon, simply by being a display
whose size you choose.

**Practical rule that follows: pin the virtual screen to a normal size**
(1280x1024 or 1920x1080), and treat "the verdict changed when the screen changed"
as a bug report, not as a reason to distrust Xvfb.

### 3.2 A second audit at 1280x1024 — and the two names it moved

The whole audit was then re-run at `xvfb-run`'s default geometry:
**278 PASS / 18 FAIL / 2 TIMEOUT / 0 SKIP, 789 s**.
`test_fluid_bodyshove_guards_0132` passed, as predicted. Two names appeared that
audit 1 did not have, so **Xvfb is not bit-stable at whole-suite level either**
— ±2 names between two Xvfb audits. Both were chased the same way (2× per arm):

| test | Xvfb ×2 | `:0` ×2 | verdict |
|---|---|---|---|
| `test_descend_untitled_preserve` | FAIL | **FAIL** | pre-existing, both arms |
| `test_wave_markers` | TIMEOUT | PASS | **not a failure at all** — see below |

`test_wave_markers` runs **983 checks** and takes **61–149 s**, straddling
`full_audit.sh`'s default `AUDIT_TIMEOUT=120`. It therefore flips PASS↔TIMEOUT on
either display depending on how the run goes. Worse, it has an **intermittent
hang**: four consecutive standalone runs (two per arm, alternating) all sat until
a 400 s kill, each stalling right after `MF11a the buffer is read-only`, and each
leaving a `/tmp/xschem_emergencysave_mf13_*` behind. **That reproduces on `:0`
exactly as on Xvfb** — it is a suite defect, not a display property.

Two actions fall out, both independent of Xvfb: run the audit with
`AUDIT_TIMEOUT=300`, and file the `test_wave_markers` hang.

### 3.3 Speed — Xvfb is FASTER than WSLg here, and far more consistent

Two suites, two runs each, alternating arms on an otherwise idle box:

| suite | Xvfb (`:92`) | WSLg (`:0`) |
|---|---|---|
| `test_wave_modes` (488 checks) | **2.43 s / 2.30 s** | 6.17 s / **45.59 s** |
| `test_wave_trace_menu` (397 checks) | **3.48 s / 3.46 s** | 4.56 s / 5.70 s |

Same verdict and same check count everywhere; only the clock differs. Note the
shape as much as the ratio: the two Xvfb numbers agree to within 5%, while `:0`
produced a **45 s** run of a 6 s test. Software rendering into RAM with no
compositor, no WM and no Windows-side RDP client beats the WSLg path.

⚠ A single earlier pair (`test_wave_markers`, 149 s on Xvfb vs 61 s on `:0`)
suggested the opposite and was **retracted**: that suite is the one with the
intermittent hang, so its timings measure nothing.

## 4. What Xvfb enables that neither `:0` nor `--nogui` can

### 4.1 Unattended and overnight

No panel to press, no window to steal your keyboard, no desktop to ruin. A batch
can run for hours while the machine is used normally. `13_receipt.md` already
did this: *"Xvfb arm (unattended window, 393 min left at the first run, 356 at
the last)"*.

### 4.2 Parallelism

One `Xvfb :$N` per concurrent runner and GUI suites stop colliding. This is the
single biggest throughput change: the GUI arm has been strictly serial, and the
worktree/subagent workflow this repo uses has had no safe way to run more than
one GUI suite at a time. **Displays are the unit of isolation — two suites on
the SAME Xvfb still share focus and will still fight.** (Learned the hard way
while measuring this report: a scheduling slip started two `full_audit.sh` runs
on `:99` at once. They interleaved windows and both wrote the same log; the run
was discarded and redone. One display per runner, or one runner.)

### 4.3 Pixels, headlessly — the capability `--nogui` does not have

Measured, same script, same schematic:

| arm | `xschem print png out.png 800 600` |
|---|---|
| `DISPLAY=:99` (Xvfb) | **80 KB PNG, 800×600 RGB, correct render** |
| `--nogui` | **no file at all — and no error on stdout, even at `-d 1`** |

So the only headless way to produce an image of what xschem drew is a virtual X
server. That opens automated pixel checks for the class of deliverable this repo
currently marks `[E]` (DONE-PIXEL, eyeball owed) — a golden-PNG or
histogram/nonblank check is now mechanically possible, where before the only
oracle was a human at `:0`. It does not *replace* the eyeball (§5.2), but it can
catch "the pane rendered blank / the trace vanished" without one.

### 4.4 CI parity

GitHub runners already run this way (`xvfb-run -a`); `full_audit.sh`'s own header
documents `XSCHEM=... xvfb-run -a tests/headless/full_audit.sh` as the CI form.
Running the same arm locally means a local red is a CI red and vice versa — see
`doc/claude/suggestions/hardening_sprint_plan.md` A5 and `doc/claude/WIRING.md`
R1, both of which have been waiting on exactly this.

## 5. What it CANNOT do — do not oversell it

### 5.1 There is no window manager

This is already the standing ruling in `doc/claude/signal_browser_detach_batch/PLAN.md`:

> A private Xvfb can be stood up with no root and is fine for pure
> geometry/packing/bindtag work, but it has **no window manager**, so decoration,
> iconify, stacking and raise results from it are worthless. Anything in that
> class is an eyeball, not a check.

Concretely, under bare Xvfb do not trust: window decorations and their offsets,
`wm iconify`/`deiconify` round-trips, `raise`/stacking order between toplevels,
`wm attributes -topmost`, WM-driven geometry echo, reparenting, focus-follows
policy, and anything that depends on the user's VirtuaWin virtual desktops.

**Mitigation available and untested here:** `openbox` and
`matchbox-window-manager` are both in the Ubuntu archive and neither is
installed. Starting one against the virtual display
(`DISPLAY=:99 openbox &`) would restore most of that class. It needs a
password-authorised `apt install` — an agent cannot do it; the user can, with
`! sudo apt install matchbox-window-manager`. Until then the ruling above stands.

### 5.2 It cannot eyeball

`pixel-deliverables-need-eyeball` is not repealed: two defects shipped past 28
green checks. Xvfb can prove *something* was drawn; it cannot prove it looks
right. `[E]` rows still owe a human at a real display.

### 5.3 It is not the environment the user runs in

WSLg is where the product is actually used on this box. A bug that only appears
under a real compositor — stale cursor, reparenting geometry, WM focus policy,
the repaint-on-dialog-open issue in `wslg-dialog-open-repaint` — is invisible to
Xvfb by construction. **Keep a `:0` arm as the pre-ship gate for visible UI**;
demote it from "the arm we run constantly" to "the arm we run before shipping and
when a symptom smells like the display stack".

### 5.4 It does not fix test code that is racy

The retry-until-effect idiom (`send_key` in `test_wave_clear_all.tcl`, the ESC
loop in `test_ase_plot.tcl`, `mg16_key` in `test_wave_modes.tcl`) is still the
rule. Xvfb removes the WM's contribution to the race, not the test's.

### 5.5 It does not replace `--nogui`

For netlist-only and engine work `--nogui` is still faster, still needs no X at
all, and is the arm that compares cleanly run-to-run. Xvfb is for the arm that
needs Tk.

## 6. How to use it

### 6.1 Start one

```sh
# persistent, one per concurrent runner
setsid Xvfb :99 -screen 0 1920x1080x24 -ac -nolisten tcp >/tmp/xvfb99.log 2>&1 &
DISPLAY=:99 xdpyinfo >/dev/null && echo up

# or per-invocation, auto-allocating a free display number (screen 1280x1024x24)
XSCHEM=$PWD/src/xschem GUI_GATE=0 xvfb-run -a tests/headless/full_audit.sh
```

`-ac` matters: without it (and without an `xauth` cookie, which `xvfb-run` sets
up for you) every client is refused with `Authorization required, but no
authorization protocol specified`. `-nolisten tcp` keeps it local. Depth **24** —
do not leave it at a legacy 8. **Pick a conventional screen size and keep it**
(1280x1024 or 1920x1080 — both verified clean here; 1600x1200 is not, see §3.1),
and record it next to any result, because it is now part of the environment.

### 6.2 ⚠ ALWAYS set `GUI_GATE=0` on an Xvfb arm

Verified in `tests/headless/gui_gate.sh`: `_gate_enabled` only checks that
`$DISPLAY` is non-empty and `wish` exists, so with `DISPLAY=:99` **the gate
arms**. Two consequences, both bad:

1. Every suite waits for a Proceed from a panel that is rendered on a display
   nobody can see — i.e. the full `GUI_GATE_AUTOSTART` (2 min) per suite, for
   nothing.
2. Worse: `gate_start` → `_gate_attention` **kills the live panel and relaunches
   it with the calling suite's `DISPLAY`**. An Xvfb run therefore *moves the
   user's visible control panel onto the virtual display* — the user is left with
   no Pause and no Stop over the real `:0` suites, and the control dir
   (`~/.claude/gui_test_gate/`) is shared by every worktree, so this reaches
   other sessions too.

```sh
export DISPLAY=:99 GUI_GATE=0        # the two variables that always travel together
```

(If you ever *do* want a gate against a virtual display, override
`GUI_GATE_DIR=` to a scratch dir so the real panel is not touched.)

### 6.3 Parallel arms

```sh
for n in 96 97 98 99; do
  setsid Xvfb :$n -screen 0 1920x1080x24 -ac -nolisten tcp >/tmp/xvfb$n.log 2>&1 &
done
DISPLAY=:96 GUI_GATE=0 tests/headless/run_suites.sh -n 5 test_wave_markers &
DISPLAY=:97 GUI_GATE=0 tests/headless/run_suites.sh -n 5 test_wave_modes &
```

Bound the fan-out by cores, not by displays: `headless-suite-flakes-under-cpu-load`
still applies, and **never `make` while suites run**.

### 6.4 Capture pixels

```tcl
# in a --script file
xschem load "xschem_library/examples/0_examples_top.sch"
xschem zoom_full
xschem print png "/tmp/shot.png" 800 600
exit 0
```
```sh
DISPLAY=:99 ./src/xschem --pipe -q --nolog --script shot.tcl
```

Whole-screen capture is `DISPLAY=:99 xwd -root -out shot.xwd` (`xwd` is
installed; ImageMagick and netpbm are **not**, so converting an `.xwd` needs a
package install — xschem's own `print png` avoids the problem entirely).

### 6.5 Suggested wrapper (not yet written)

A `tests/headless/with_xvfb.sh` that (a) allocates a free display, (b) starts
Xvfb with the flags above, (c) exports `GUI_GATE=0`, (d) runs the given command,
(e) kills the server and keeps its log on failure. Then
`tests/headless/with_xvfb.sh full_audit.sh` is the everyday unattended arm and
`DISPLAY=:0 tests/headless/run_suites.sh …` stays the pre-ship eyeball arm.

## 7. Recommendation

1. **Move the routine GUI arm to Xvfb.** Soaks, baselines, batch preflights,
   subagent/worktree runs, overnight audits — all of it. It is faster (measured
   §3.3, plus no gate waits), parallelisable, unattended, and immune to the abort
   class that has been silently invalidating runs.
2. **Keep `:0` for two jobs only:** the pre-ship eyeball of visible UI, and any
   WM-dependent test (decoration/stacking/iconify/raise/geometry echo). Label
   those tests so it is obvious which arm owns them.
3. **Install a lightweight WM** (`matchbox-window-manager` or `openbox`) and
   re-measure the WM-dependent list under `Xvfb + WM`. If it holds, the `:0`
   arm shrinks to "the eyeball" alone.
4. **Never run an Xvfb arm without `GUI_GATE=0`** (§6.2).
5. **Do not retire the gate.** It still governs the `:0` arm, and the brake still
   catches ungated runs.
6. **Pin the screen geometry and record it with the result** (§3.1), and run the
   audit with **`AUDIT_TIMEOUT=300`** — the 120 s default sits inside
   `test_wave_markers`' normal 61–149 s range on both arms (§3.2).
7. **File the two defects this exercise surfaced**, neither of which is an Xvfb
   problem: `test_fluid_bodyshove_guards_0132`'s verdict depending on the screen
   size, and `test_wave_markers`' intermittent hang after `MF11a` (reproduced on
   `:0` too). Both were invisible before because `:0` is always 5120x1440 and
   nobody re-ran the suite four times in a row.

## 8. Evidence appendix

Environment: WSL2, Linux 6.6.87.2, 14 cores. `Xvfb 2:21.1.12-1ubuntu1.6`,
`xvfb-run` from the same package. Repo `fluid-editing` @ `00530250`, worktree
dirty only with untracked files.

```sh
# server
setsid Xvfb :99 -screen 0 1600x1200x24 -ac -nolisten tcp
DISPLAY=:99 xdpyinfo | grep -E 'dimensions|depth of root|number of extensions'
#   dimensions: 1600x1200 pixels ; depth of root window: 24 planes ; 23 extensions
ps -o rss,cmd -C Xvfb          # 67176-88608 kB

# soak (30 runs)
DISPLAY=:99 GUI_GATE=0 tests/headless/run_suites.sh -n 10 \
    test_wave_trace_menu test_ase_plot test_wave_modes

# the anti-hollow control: same three suites on the real display, same tree
DISPLAY=:0 tests/headless/run_suites.sh \
    test_wave_trace_menu test_ase_plot test_wave_modes   # 397 / 150 / 488, 3/3

# full audit, twice, at two geometries
DISPLAY=:99 GUI_GATE=0 tests/headless/full_audit.sh          # 1600x1200, 711.96 s
DISPLAY=:92 GUI_GATE=0 tests/headless/full_audit.sh          # 1280x1024, 789.10 s

# every differing name, twice per arm, same tree and binary
DISPLAY=:99 GUI_GATE=0 tests/headless/full_audit.sh <names>
DISPLAY=:0             tests/headless/full_audit.sh <names>

# the screen-size sweep (one Xvfb per geometry, test run on each)
Xvfb :NN -screen 0 <W>x<H>x24 -ac -nolisten tcp
DISPLAY=:NN ./src/xschem --pipe -q --nolog \
    --script tests/headless/test_fluid_bodyshove_guards_0132.tcl

# speed, alternating arms on an idle box
DISPLAY=:92|:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_modes.tcl

# png capability A/B
DISPLAY=:98 ./src/xschem --pipe -q --nolog --script png_probe.tcl   # -> 80272-byte PNG
env -u DISPLAY ./src/xschem --pipe -q --nolog --nogui --script png_probe.tcl  # -> no file, no error

# gate arming
DISPLAY=:99 bash -c '. tests/headless/gui_gate.sh; _gate_enabled && echo ARMS'   # ARMS
```

Historical controls quoted in §2/§3 come from, in the repo:
`doc/claude/signal_browser_2pane_batch/13_receipt.md` (Xvfb arm, immunity to the
Xwayland death), `doc/claude/signal_browser_detach_batch/PLAN.md` §"Environment
traps" (the no-WM ruling), `doc/claude/overnight_batch_2026_08_01/PLAN.md:214`
and `receipts/03_axis-region-drag-zoom.md:23` (TG9 4-in-10),
`doc/claude/overnight_batch_2026_08_01/receipts/05_multi-trace-drag-to-strip.md:262`
(the legend-slot family, 2-in-3 on pristine HEAD),
`doc/claude/suggestions/next_session_prompt_0174.md:217` (`test_ase_plot` 1–2 in
10), and `doc/claude/signal_browser_batch/receipts/16_receipt.md:282`.

Related: `doc/claude/specs/gui_test_gate.md`, `doc/claude/WIRING.md` R1,
`doc/claude/suggestions/hardening_sprint_plan.md` A5.
