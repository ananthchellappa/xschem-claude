# Phase 0 receipt — skeleton and dividers

Plan: `doc/claude/calculator_batch/PLAN.md` steps 0.1–0.10.
Spec: `doc/claude/specs/calculator.md` §4.
Screenshot: `00-phase0-skeleton.png` (this directory).

**Status: all ten steps done.** The window opens, shows five labelled regions in
the reference proportions, every divider drags, the layout persists, and nothing
else works — which is exactly what phase 0 is.

---

## What landed

| Step | |
|---|---|
| 0.1 | `src/calculator.tcl`, namespace `calc`, added to `src/Makefile.in`'s share list |
| 0.2 | toplevel `.calc`, raise-or-open (spec R101), `WM_DELETE_WINDOW` → `calc::close` |
| 0.3 | menubar, six cascades (File Tools View Options Constants Help), every entry disabled |
| 0.4 | the pane tree: `.calc.pw` vertical (3 sashes) with `.calc.pw.bot` horizontal (1 sash) nested in it |
| 0.5 | placeholder labelframes, and first-open proportions (see "eyeball" below) |
| 0.6 | status bar packed `-side bottom` **outside** the panes |
| 0.7 | sash + geometry persistence, with the D4 clamp guard |
| 0.8 | main-window `Tools > Calculator`, viewer `View > Calculator...`, `calc.open` row in `actions.csv` |
| 0.9 | `tests/headless/test_calc_skeleton.tcl` |
| 0.10 | eyeball, below |

`Makefile.in` changed, so `./configure` was re-run (rc=0) before `make` (rc=0, no
warnings). `src/Makefile` now carries the install and uninstall rules for
`calculator.tcl`.

### Wiring notes

- **The viewer entry is under View, not Tools.** `test_wave_viewer` G2 asserts
  that menubar's cascade set is *exactly* `{File View Graph Cursors Options}`, so
  a Tools cascade for one launcher would have broken it for nothing. Comment in
  `wave_viewer.tcl` records why.
- **CIW has no menubar**, so "Tools > Calculator in the CIW" from the plan is
  satisfied by the main window's Tools menu, which is the same reach.
- The `actions.csv` row registers the action (so it is remappable) without
  generating a menu item — only the File menu is table-generated today.

---

## Evidence

### Test: 49 checks, all pass

```
GUI_GATE=0 xvfb-run -a -s "-screen 0 1400x1000x24" \
  ./src/xschem --pipe -q --nolog --script tests/headless/test_calc_skeleton.tcl
RESULT: ALL PASS (49 checks)
```

S1 open/raise · S2 menubar · S3 pane classes and orientations · S4 panes managed
with their `-minsize` · S5 `-stretch` where Tk has it · S6 four sashes report
coordinates · S7 status bar outside the panes · S8 sash drag → `save_layout` →
`restore_layout` round trip · S9 the D4 guard · S10 close/reopen · S11 first-open
proportions.

### Sabotage: four breaks, four reds

A green suite over untouched code proves nothing, so each was broken deliberately
and reverted.

| Sabotage | Result |
|---|---|
| drop `-minsize 250` from `.calc.pw.bot.fn` | `FAIL: S4 .calc.pw.bot.fn -minsize -> {0} (exp {250})` |
| remove the D4 clamp guard in `restore_layout` | `FAIL: S9 oversize saved sash ignored -> {201} (exp {151})` and `FAIL: S9 negative saved sash ignored -> {121} (exp {151})` |
| `calc::open` always builds (no raise-or-open) | `RESULT: 1 FAILED (4 passed)` |
| status bar added as a pane | `RESULT: 1 FAILED (0 passed)` |

The D4 one is the informative one. Without the guard the poisoned coordinates do
not error and do not get ignored — they **clamp**, to 201 and 121, silently
rewriting the layout. That is the whole failure mode the landmine describes, and
it is invisible without this test.

### Regression: two pre-existing failures, confirmed not mine

`test_wave_viewer` 400/400, `test_accelerators` all pass, `test_wave_trace_menu`
397/397, `test_bindings_file`, `test_key_graph_context`, `test_deselect_mode` all
pass.

Two tests are red. Both were re-run with the tracked edits stashed (which also
neutralises the untracked `calculator.tcl`, since its `source` line lives in the
stashed `xschem.tcl`) and produced **identical counts**:

| Test | with changes | stashed baseline |
|---|---|---|
| `test_wave_sigbrowser_keys` | `3 FAILED (46 passed)` | `3 FAILED (46 passed)` |
| `test_reopen_readonly` | `1 FAILED` | `1 FAILED` |

`test_action_log_dispatch` prints no `RESULT:` line in either run — also
pre-existing, not a symptom of this change.

---

## Eyeball

Captured under Xvfb (`ffmpeg -f x11grab`), 660x700, stored alongside this file.

**Two defects the tests could not have caught, both found by looking and both
fixed before commit:**

1. **The window opened in Tk's even split, not the reference's proportions.**
   Four panes of roughly equal height, where the reference gives the selector
   grid only what its two button rows need and hands the surplus to the stack
   and the function browser. Fixed by adding default sash fractions to
   `calc::pw_list` (`{0.21 0.36 0.64}` vertical, `{0.78}` horizontal, measured
   off the reference screenshot) applied when nothing is saved. S11 now asserts
   them, including a negative check that an even split would fail.

2. **`{digits,\noperators,\nuser 1-4}` printed a literal `\n`.** Tcl does not
   substitute backslash escapes inside braces. Caught immediately in the capture;
   fixed by switching to `"..."`. Cosmetic, on a placeholder that dies in phase 1
   — but it is the exact class of thing 49 green checks say nothing about.

**Confirmed by eye:** six cascades in the right order; five regions in the right
order with the right titles; sash handles visible on all four dividers; the
status bar spans the full width and does not move when a sash is dragged.

**Noted, not acted on:** the keypad pane sits at its 140px minimum, against ~115px
in the reference. Phase 1 puts real buttons there and that is when the number
should be judged — a placeholder's width is not evidence.

---

## Addendum — a fourth defect, found only on `:0`

After phase 0 was committed, `full_audit.sh`/`run_suites.sh` were switched to a
private Xvfb by default (`tests/headless/xvfb_arm.sh`). Exercising the new
`AUDIT_DISPLAY=:0` opt-in immediately turned this suite red on the real screen:

```
FAIL: S8 restore_layout reproduced it -> {123} (exp {153})
FAIL: S11 default sash0 near 21% of 769 -> {0} (exp {1})
FAIL: S11 default sash2 near 64% of 769 -> {0} (exp {1})
```

49/49 under Xvfb, 46/49 on `:0`, same binary.

**Cause (landmine D6):** `restore_layout` writes the layout, but a `<Configure>`
delivered while it runs lands in `save_layout`, captures the positions the
restore is halfway through replacing, and clobbers the values it was about to
apply. The visible symptom is a restore that appears to do nothing. Xvfb runs no
window manager, so no such Configure is ever pending — the bug is invisible
there **by construction**.

**Fix:** `calc::restoring`, held across the whole restore on every exit path,
with `save_layout` returning early while it is set.

**A wrong turn worth recording.** The first hypothesis was that `wm geometry` is
negotiated asynchronously under a WM and `update idletasks` cannot see the reply,
so a `calc::settle` proc was added to poll until the size stopped changing. That
made the tests pass — but pinning it down showed the D6 guard *alone* is
sufficient and `settle` is not load-bearing. It was removed: a 200-iteration
`update` loop pumps X events, and events can run anything including
`calc::close`, so keeping unproven machinery with a real reentrancy hazard is a
bad trade. Verified after removal: `:0` 3/3 × 49 checks, Xvfb 3/3 × 49 checks.

**The general lesson**, now in `CLAUDE.md`: Xvfb is the right default arm. Run a
GUI feature's suite on `:0` once before calling it done — and see the next
section for why that alone is not enough.

## Addendum 2 — openbox, and what it did and did not fix

openbox was installed and wired into `xvfb_arm.sh` (`AUDIT_WM`, default
`openbox`, `none` to opt out) to try to close the `:0`-only gap. It closes part
of it. Measured 2026-08-13:

| arm | reparented | `wm iconify` → state | ismapped |
|---|---|---|---|
| Xvfb, no WM | 0 | `normal` (silent no-op) | 1 |
| Xvfb + openbox | **1** | **`iconic`** | **0** |
| `:0` (WSLg) | 1 | `normal` | 1 |

So openbox restores reparenting and real iconify/withdraw semantics, and on
iconify is *more* faithful than WSLg — Xwayland does not honour it either. The
standing "decoration/iconify/stacking/raise are worthless under Xvfb" ruling in
`doc/claude/signal_browser_detach_batch/PLAN.md` has been amended accordingly.

**It did not reproduce D6.** With the D6 guard removed:

| arm | result |
|---|---|
| Xvfb, no WM | ALL PASS — bug hidden |
| Xvfb + openbox | ALL PASS — bug still hidden |
| `:0` | 3 FAILED |

Instrumenting `save_layout` gave the reason, and it is not about window
management at all:

| arm | `<Configure>` per `wm geometry` | `save_layout` entries per `restore_layout` |
|---|---|---|
| Xvfb, no WM | 1 | 0 |
| Xvfb + openbox | 1 | 0 |
| `:0` (WSLg) | **3** | **2** |

D6 needs that extra asynchronous traffic, which is a WSLg/Xwayland property, not
a window-manager one. Adding window managers until a bug appears is not a
strategy.

**What actually closed the hole: S12.** A guard that only fires on one
developer's display is not covered at all, so the test now *forces* the race —
it wraps the restore body so a real `save_layout` lands while `calc::restoring`
is set, which is precisely what a mid-restore Configure does. Verified by
removing the guard again:

```
AUDIT_WM=none      FAIL: S12 mid-restore save did not clobber -> {161} (exp {191})
AUDIT_WM=openbox   FAIL: S12 mid-restore save did not clobber -> {161} (exp {191})
AUDIT_DISPLAY=:0   FAIL: S12 mid-restore save did not clobber -> {123} (exp {153})
```

Red on every arm. That is the shape to prefer for anything in this class:
reproduce the hazard deterministically rather than hoping an environment
supplies it.

**openbox was kept as the default anyway**, because it costs nothing and closes
the reparent/iconify class — but only after proving it shifts no verdict. The
full audit was run twice, `AUDIT_WM=none` and `AUDIT_WM=openbox`, and the
verdict sets diffed **identical**: 319 tests, 300 PASS, 18 FAIL, 1 TIMEOUT, same
names. Baseline stored beside this file as
`00b-audit-baseline-2026-08-14.txt`; the 18+1 are all pre-existing and include
the two this batch already re-ran against a stashed tree (`test_cadence_drag`,
`test_reopen_readonly`). `test_calc_skeleton` PASSes on both arms.

(Method note: the first A/B attempt produced a 534-byte log and a false "exit 0".
The command had been double-backgrounded — a `&` inside an already-backgrounded
call — so the detached subshell was killed with its process group after 11
tests. A truncated log that still reports success is worth recognising on sight.)

## Next

Phase 1: replace each placeholder's body with the real, inert controls. The
labelframes and their panes stay exactly as they are; phase 1 must not move a
sash or change a minsize.
