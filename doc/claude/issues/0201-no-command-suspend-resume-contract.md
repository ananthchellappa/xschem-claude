# 0201 — a command interrupted to descend is never resumed: there is no suspend/resume contract

Status: **OPEN**. Filed 2026-08-01, from the same user report as
[0200](0200-descend-has-no-verb-noun-pick.md). Established by reading; the cross-context
failure modes below are **reasoned, not measured** (they need a GUI run — see "What still
has to be measured").
Area: `src/ase_window.tcl` (`ase::ui::select_on_design` 1575, `sod_end` 1640,
`sod_click`, `sod_prompt_pump`), `src/ase.tcl` (`direct_plot_for_current` 908),
`src/cadence_style_rc:221` (the `Ctrl-4` binding), `src/xschem.tcl`
(`hi_descend_current` 5809, `hi_descend_newwin` 5821), `src/actions.c`
(`descend_schematic` 3507).
Tests: none yet.
Related: [0200](0200-descend-has-no-verb-noun-pick.md) (the pick half — this is unreachable
without it), [0202](0202-canvas-gesture-seize-has-no-stack.md) (the mechanical blocker),
0161 (which already made a descended pick name-correct), 0154 / 0168 (the ASE pick lineage).
Specs: `doc/claude/specs/ase_l.md`, `doc/claude/specs/hi_descend.md`.

## Report

> The reason someone might want to do this is, for example, they have just done CTRL-4 to
> enter select-signals-to-plot command mode. Now, they need to descend to select some
> voltages/currents. In this case, the descend, after it has received
> which-instance-to-descend-into information, should descend, and the command that was
> interrupted to do the descend should resume.

So: **descend is a parenthesis inside another command**, not a replacement for it.

## What Ctrl-4 actually is

```
src/cadence_style_rc:221   bind .drw <Control-Key-4> {ase::direct_plot_for_current; break}
src/ase.tcl:908            proc ase::direct_plot_for_current {}   -> ase::ui::direct_plot $key 0
src/ase_window.tcl:1929    proc ase::ui::direct_plot {key {do_raise 1}}
                             -> ase::ui::select_on_design $key {save 0 plot 1} plot $do_raise
```

`select_on_design` in `plot` flavour is the "select signals to plot" mode: each Button-1
queues a trace expression, ESC ends the mode and hands the queue to `dp_finish` → the
waveform viewer.

## The state a suspend would have to carry

All of it lives in the `ase::ui` `sod` array plus three seized Tk bindings
(`ase_window.tcl:1575-1629`):

| what | where |
|---|---|
| which session owns the mode | `sod(active)` |
| the canvas the mode is seized on | `sod($key,canvas)` — a **widget path**, captured from `xschem get current_win_path` |
| flavour / mode | `sod($key,flavor)`, `sod($key,mode)` |
| the queued traces and their colours | `sod($key,queue)`, `sod($key,qcolors)` |
| the count reported at end | `sod($key,count)` |
| the three displaced bindings | `sod($key,prevpress)`, `sod($key,prevrel)`, `sod($key,prevesc)` |
| the status-line prompt and its re-assert timer | `sod($key,prompt)`, `sod($key,pump)` |

`sod_end` (1640) restores the three bindings verbatim, cancels the pump, clears the
prompt, then **finishes** — in `plot` mode it plots the queue. There is no way to stop the
mode without ending it.

## Why nothing resumes today

**1. No suspend/resume concept exists anywhere in the tree.** Not a mode stack, not a
pending-command queue, not a resume-after callback. The nearest things are single-slot
ownership hand-backs (`addpin::grab_esc` / `release_esc`, `xschem.tcl:10817-10820`) and the
`sod_end` verbatim restore — both "give it back", neither "hold it and give it back later".

**2. ESC is the mode's own terminator.** `bind $cv <Key-Escape> "[list ase::ui::sod_end $key]; break"`.
An ESC that the user means as "cancel this descend pick" is, on that canvas, "end the plot
mode and plot what I have". A nested pick therefore cannot use ESC without first taking
the slot away from SOD and giving it back — see [0202](0202-canvas-gesture-seize-has-no-stack.md).

**3. Button-1 is seized, so the pick has to nest.** Same three lines. The pick mode
[0200](0200-descend-has-no-verb-noun-pick.md) proposes must sit *above* SOD's seize and
put it back afterwards.

**4. `target=new_window` / `new_tab` strands the mode.** `sod($key,canvas)` is a widget
path. `hi_descend_newwin` (`xschem.tcl:5821`) creates a *new* canvas and switches to it;
SOD's bindings stay on the parent's canvas, `sod(active)` still names the old key, and the
prompt pump keeps re-asserting a prompt on a canvas the user is no longer looking at.
"Resume in the descended context" means **re-seizing on the new canvas** — a genuinely
different operation from "leave it alone".

**5. `target=current` is the easy case — probably.** The Tk canvas widget is unchanged by
a same-window descend, so the seized bindings and the pump survive it untouched, and
`descend_schematic` never reads or writes `ui_state`/`semaphore` (`actions.c:3507-3718`).
This one may already work if the pick can be made to happen at all. **Unmeasured.**

## The one thing that is already right

A pick made while descended is **name-correct**: 0161 added `ase::ui::sod_qualify`, so a
click at `currsch>0` queues `v(x1.x2.mid)` / `i(v.x1.x2.v1)` rather than the bare token.
That is the semantic prerequisite for "descend, keep picking" — and it is already shipped
and tested (`tests/headless/test_ase_hier_pick_0161.tcl`, `HP1`-`HP18b`). Mixing levels in
one queue is therefore *sound*, not a hazard.

## Decisions

### D1 — the contract must be generic, not ASE glue ✔ (user, explicit constraint)
"Keep code changes as orthogonal as possible to any code that supports waveform viewer and
graph elements." So: a small registry in a **new file** (e.g. `src/cmdmode.tcl`), a command
registers `{suspend_cb resume_cb}` under a key, descend calls
`cmdmode::suspend_all` before and `cmdmode::resume_all <new_win_path>` after. ASE's whole
participation should be one `cmdmode::register` line next to `select_on_design`, and
`sod_end` untouched.

### D2 — resume where? → **in the descended context** ✔ (user, explicit)
`resume_cb` therefore receives the *current* canvas path, and SOD's implementation is
"re-seize on that canvas, restore prompt + pump, keep `queue`/`qcolors`/`count`".

### D3 — suspend must not finish the command ✔
`sod_end` plots. A suspend arm must stop short of `dp_finish`: restore bindings, cancel the
pump, clear the prompt, **keep** `sod($key,*)`. That is a new proc alongside `sod_end`
(shared teardown factored out), not a flag threaded through it.

### D4 — descend cancelled / failed → resume in place — OPEN
`hi_descend` returns 0 on a bad view, a non-subcircuit target (`actions.c:3552`), depth
`CADMAXHIER` (3517), or a Cancel in the dialog. Every one of those must resume the
suspended command on the *original* canvas. A `try`/`finally` shape, not a success path.

### D5 — ESC during the pick → abort the pick, resume the command — OPEN
Not "end the plot mode". Requires the ESC slot to be genuinely stacked
([0202](0202-canvas-gesture-seize-has-no-stack.md)).

### D6 — nesting depth — OPEN
`select_on_design` already self-serialises: `if {[info exists sod(active)]} { ase::ui::sod_end $sod(active) }`
(1577) — a second mode *ends* the first. One suspended command at a time is probably the
right first cut; say so explicitly rather than leaving it to be discovered.

### D7 — go_back — OPEN
Symmetric case: the user descends, picks, then pops back with `Ctrl-E`
(`go_back`, `actions.c:3764`). Does the mode follow her up? If resume is keyed on "the
current canvas after the navigation", `go_back` needs the same wrapper as descend, or the
mode is left resumed on a context that no longer exists.

### D8 — who else registers — deliberately nobody, at first
`addpin` / `addlabel` / `ciform` have the same shape (drop hooks + a shared ESC slot,
`xschem.tcl:10704-10709`, `11072`, `create_instance.tcl:56-61`) and could adopt the
contract later. Not in the first cut.

## What still has to be measured

None of the following has been run; all of it is reachable with a GUI smoke under the test
gate (`tests/headless/run_suites.sh`, never a bare loop):

1. With Direct Plot armed, does `e` reach `hi_descend` today? (Reading says yes — SOD
   seizes only Button-1/Release-1/Escape.)
2. Does a `target=current` descend leave the seized bindings and the prompt pump intact?
3. What exactly does the prompt pump do after a `new_window` descend — does it error on a
   dead path, or silently re-assert on the parent?
4. Does `dp_finish` behave if the queue spans two hierarchy levels? (0161 says the *names*
   are right; the plotting side is untested for a mixed-level queue.)

## Tests (proposed leg IDs)

Headless: **CR1** register/suspend/resume round trip on a stub command (no ASE, no Tk) —
the contract's own unit test; **CR2** resume runs even when the wrapped operation throws.
DISPLAY-gated: **CR3** Direct Plot armed → `e` → pick → descend → mode is live on the
descended canvas with the queue preserved; **CR4** same with `target=new_window`, mode live
on the *new* canvas, nothing left seized on the parent; **CR5** dialog Cancel → mode live on
the original canvas, hierarchy unchanged; **CR6** ESC during the pick → pick aborted, mode
still live, queue intact; **CR7** `go_back` after CR3.

## Cross-references

* `doc/claude/specs/ase_l.md` — Select-On-Design / Direct Plot scope.
* `doc/claude/issues/0161-ase-descended-pick-unqualified-name.md` — the hierarchy
  qualification that makes a mixed-level queue meaningful.
* `doc/claude/issues/0168-ase-direct-plot-not-hierarchical.md` — `session_for_current`
  walking the stack; the same ancestor logic a resumed mode leans on.
* `doc/claude/specs/hi_descend.md` §6 — the destination arms whose new-canvas behaviour is
  the hard case here.
