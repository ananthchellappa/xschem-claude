# Issue 0173 — Ctrl-Shift-4 (viewer plot-mode toggle from the schematic) leaves
# the xschem CONTEXT on the viewer window

Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
HEAD `f07fb464`; `github/fluid-editing` is at `0f1720de`, so **6 commits are
local and unpushed** — do not push unless I say so.

## The bug, as reported

Launch:

```sh
src/xschem --script sky130A/cadence_style_rc --logdir /tmp
```

Open (Ctrl-Shift-O, most recent)
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`, then
open `ngspice_state1` for that cell — a waveform viewer comes up with a couple of
strips, status bar shows mode `multi`, title `Waveforms tb_bandgap
(ngspice_state1)`.

Now, **in the schematic window**, press **Ctrl-Shift-4** (toggle viewer plot
mode). Three things go wrong at once:

1. **The schematic window loses focus.**
2. **The viewer's title changes to `xschem [5] - untitled.sch (read-only)`.**
   Hovering the pointer over the viewer window restores the correct title.
3. **The next click in the schematic window selects a plot in the VIEWER**
   instead of acting on the schematic. Clicking away to another window and back
   restores normal behaviour.

The mode itself *does* toggle — this is not about the mode.

## The diagnosis is already done. Verify it, do not re-derive it

**Root cause: `wviewer::in_ctx` switches the xschem context to the viewer canvas
and never restores it** (`src/wave_viewer.tcl:722`):

```tcl
proc wviewer::in_ctx {token script} {
  variable windows
  if {![dict exists $windows $token]} { return }
  xschem new_schematic switch [dict get $windows $token win_path]
  uplevel #0 $script
}
```

The Ctrl-Shift-4 path:

```
bind .drw <Control-Shift-Key-4>   src/cadence_style_rc:233
  -> ase::plot_mode_for_current invert          src/ase.tcl:925
     -> wviewer::set_plot_mode                  src/wave_viewer.tcl:1999
        -> wviewer::status_refresh              src/wave_viewer.tcl:4488
           -> wviewer::in_ctx $token {xschem get graph_snap}   :4508
              -> xschem new_schematic switch <viewer .drwN>   ... and stays there
```

That single un-restored switch explains all three symptoms:

- **Symptom 2 (title).** The C `switch_window()` (`src/xinit.c:1784`) ends with
  `set_modify(-1)`, whose comment says *"sets window title"*. The viewer buffer
  genuinely IS an untitled read-only schematic, so the title becomes
  `xschem [5] - untitled.sch (read-only)`. The viewer has a repair binding —
  `bind $top <FocusIn> "+wviewer::retitle $token"` (`wave_viewer.tcl:687`,
  `title_for`/`retitle` at `:412`/`:423`) — which is exactly why **hovering fixes
  it**: the hover gives the window focus, FocusIn fires, `retitle` runs.
  `with_edit`'s header already records this hazard for the readonly toggles
  ("re-assert the title … probe-verified"); nothing re-asserts it here.
- **Symptom 3 (click goes to the viewer).** The current context is still the
  viewer's, so the next event dispatched through `callback` runs against the
  wrong `xctx`. Clicking another window and back repairs it via the FocusIn →
  `switch_window` (Tcl, `xschem.tcl:13757`) → `xschem callback` → ctx switch path.
- **Symptom 1 (focus).** Least certain of the three — measure it rather than
  assume. Suspects: `raise_dialog` in the Tcl FocusIn path, and the WM reacting
  to the title rewrite. **State what you measured.**

**Same bug class, adjacent:** `wviewer::readout_refresh` (`:4516`) does a bare
`xschem new_schematic switch $wp` with no restore either. There are **19** bare
`new_schematic switch` sites in `wave_viewer.tcl`; most are legitimate (they run
from viewer-side gestures, where the context is *supposed* to end up the
viewer's). **The ones that matter are the paths reachable FROM THE SCHEMATIC
SIDE.** Enumerate them before fixing anything — at least
`ase::plot_mode_for_current` (Ctrl-Shift-4), `ase::direct_plot_for_current`
(Ctrl-4), `ase::window_number_for_current`, the `~` button, and anything the
menus reach while a schematic is current.

## READ FIRST

1. `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — **landmine
   17** (`switch_ctx` no-ops under a raised semaphore, so a switch must be
   VERIFIED, never assumed) and **landmine 41**. Landmine 17 is the reason the
   restore cannot be a bare `new_schematic switch` either.
2. `src/wave_viewer.tcl` header comment ~line 40 — the readonly/title clobber
   note, and `with_edit` (`:756`), which is the **existing precedent for
   save → mutate → restore-and-re-assert-title**. Copy its shape.
3. `doc/claude/specs/waveform_viewer_modes.md` (issue 0151) — the plot-mode
   contract and the Ctrl-Shift-4 entry point.
4. `doc/claude/specs/window_numbering.md` — `notify_window_active` fires off
   these switches; do not let the fix spam window-activation logging.

## Seams that already exist — compose, do not reinvent

| what | where | note |
|---|---|---|
| `wviewer::in_ctx {token script}` | `wave_viewer.tcl:722` | THE fix site; 5 callers, all refreshes/redraws |
| `wviewer::switch_ctx {token}` | `:737` | switches and **VERIFIES** (returns 0 when refused) — the restore needs the same verification |
| `wviewer::with_edit` | `:756` | save → switch → run → restore → **re-assert title** → propagate errors afterwards. The shape to copy |
| `wviewer::retitle` / `title_for` | `:423` / `:412` | the title repair, already used by `with_edit` and the FocusIn binding |
| `xschem get current_win_path` | `scheduler.c:3697` | what to save, and what to assert in tests |
| `wviewer::status_refresh` | `:4488` | the caller on this path; reads `graph_snap` only for the x/y readout |

## Decisions to make BEFORE writing code — answer them in the spec

- **D1: fix `in_ctx` itself, or the `status_refresh` call?** My recommendation is
  **both, in this order**: (a) `status_refresh` should not switch context at all
  when the viewer's ctx is not already current — the pointer is not over that
  viewer, so `graph_snap` is stale/meaningless, and the mode-change path then
  does zero switching; (b) `in_ctx` gains a save/restore + `retitle` regardless,
  because all five of its callers are refreshes that have no business moving the
  current context. (a) alone leaves the landmine armed for the other callers;
  (b) alone leaves a needless switch-and-switch-back (two `set_modify(-1)`
  title rewrites, two `notify_window_active` candidates) on every mode change.
- **D2: what does the restore do when it is REFUSED** (landmine 17 — semaphore
  raised)? Recommend: leave the context where it is, do not loop or retry, and
  say so in the spec. A refused restore is not silently ignorable; consider a
  `dbg`/`ciw_echo`. Do NOT make `in_ctx` throw — its callers are status/redraw
  paths that must not break a keystroke.
- **D3: does the restore re-assert the viewer title, the schematic title, or
  both?** Recommend the **viewer's** (`retitle`), because that is the window
  whose title `set_modify(-1)` corrupted. Check whether switching back also
  corrupts anything on the schematic side and record the answer.
- **D4: is the fix in `in_ctx` or in a new `wviewer::preserving_ctx` wrapper?**
  Recommend changing `in_ctx` — its name already promises "in that context", not
  "leave everything there". If any of its 5 callers actually *wants* the context
  to stay moved, say which and why.
- **D5: `readout_refresh` and the other schematic-reachable switch sites** — fix
  in this change or file a follow-up? Recommend: fix `readout_refresh` here (same
  proc family, same defect), and record an audit list for the rest with a verdict
  per site rather than a blanket sweep.

## Hard constraints

- **Landmine 17: every switch is verified, both ways.** `switch_ctx` exists
  because `new_schematic switch` silently no-ops while the current context's
  semaphore is raised. A restore that assumes success is the same bug in reverse.
- **Do not change the plot-mode semantics.** `set_plot_mode` writes the model,
  pushes the status bar, logs one line. The mode toggling already works; this is
  about the context and the title.
- **The status bar must still be right.** Item 10's contract is that the mode is
  PUSHED from the one mutation site. If `status_refresh` stops reading
  `graph_snap` on this path, the mode text must still update, and the x/y readout
  must still work when the pointer IS over the viewer (that is the Motion path).
- **One log line per gesture.** Ctrl-Shift-4 logs `wviewer::set_plot_mode <mode>
  <token>`. Do not add a second line, and do not let the fix emit
  `notify_window_active` noise into the action log.
- **The Ctrl-4 Direct Plot path must not regress** — it also crosses from the
  schematic into the viewer, and it has its own suite.

## ⚠ THE HOLLOWNESS TRAP — read before writing a single leg

**The repair paths will mask this defect in a test.** `bind $top <FocusIn>
retitle` and the Tcl `switch_window` FocusIn handler both fix the damage as soon
as focus moves — and a Tk test that calls `update` after the toggle may let
exactly that happen. So:

1. **Assert with NO `update` between the toggle and the assertion**, and say in
   a comment why the missing `update` is load-bearing.
2. **Assert `xschem get current_win_path` directly** — that is the primary
   defect and it needs no pixels. Before the toggle it is the schematic's;
   after, it must be unchanged.
3. **Assert `wm title $viewertop` equals `wviewer::title_for $token`** right
   after the toggle. And **spy `wviewer::retitle`** to prove the title was never
   corrupted rather than corrupted-and-repaired — a leg that only compares the
   final string passes either way.
4. `test_wave_modes.tcl:1622` **already calls `ase::plot_mode_for_current
   invert` and asserts it returns `multi` — and it is green today.** That is the
   green-but-hollow leg this bug hid behind; it never looked at the context or
   the title. Read it before adding yours.

Also still true: a suite's check COUNT is the signal, not its verdict; and
`wviewer::open` has an intermittent that only a 10-run soak catches.

## Tests

Extend the suites that own these paths — do not add a new one:

- `tests/headless/test_wave_modes.tcl` (**385** DISPLAY / **134** nogui) — owns
  plot modes and the Ctrl-Shift-4 entry. The context/title legs belong here.
- `tests/headless/test_ase_plot.tcl` (**145** / **30**) — owns the
  schematic→viewer crossing; add the Ctrl-4 no-regression leg if D5 touches it.

Sabotage-verify at minimum: (a) drop the restore, (b) drop the `retitle`,
(c) make the restore unverified (pretend a refused switch succeeded) — each must
turn different legs red.

Full battery that must stay green at these counts:
`test_wave_snap` 59, `test_wave_grid` 80, `test_wave_legend` 44,
`test_wave_empty_strips` 94, `test_wave_modes` 385, `test_wave_markers` 712,
`test_wave_viewer` 349, `test_wave_clear_all` 68, `test_ase_plot` 145,
`test_wave_trace_menu` 223, `test_wave_split_strip` 221.

## Process

Run suites through `tests/headless/run_suites.sh` with `SUITE_TIMEOUT=900`, never
a bare loop, or the GUI-test gate cannot pause them. **Soak the DISPLAY arm 10x.**

Then: **build → suites green → COMMIT → raise
`tools/review_gate/review_gate.sh` in the background.** Never push.

⚠ **This one is a pixels-and-focus bug, so the suite cannot close it.** After the
suites are green, hand me the exact manual sequence to re-run (the repro above)
and say which of the three symptoms you expect me to see gone. Symptom 1 (focus)
in particular may need a second round — do not report it fixed on the strength of
a green suite.

Implementer session, not a driver round: one root cause, one proc, two callers.
See `doc/claude/suggestions/orchestration_driver_vs_implementer.md`.

## Docs to update

- **New issue file** `doc/claude/issues/0173-viewer-plot-mode-toggle-leaks-ctx.md`
  (0172 is the highest so far) — symptoms, the trace above, the fix, and the
  audit verdict per switch site from D5.
- `doc/claude/specs/waveform_viewer_modes.md` — the Ctrl-Shift-4 entry now
  guarantees the schematic keeps the context and the viewer keeps its title.
- `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 — extend
  landmine 17, or add a new one: **"a context switch rewrites the target
  window's TITLE (`set_modify(-1)`), and the viewer repairs it only on FocusIn —
  so any Tcl that switches into a viewer must restore the context AND re-assert
  the title."** That is the reusable half of this bug.
- `doc/claude/suggestions/plan_viewer_enhancements_2026-07.md` — the debt list
  there still has **item 6 round 2 (`780bd468`) un-eyeballed**; do not let this
  work bury it.
