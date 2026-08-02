# 0201 — a command interrupted to descend is never resumed: there is no suspend/resume contract

Status: **FIXED** (2026-08-01), sabotage-verified three ways. Awaiting the human eyeball.
Filed the same day, from the same user report as
[0200](0200-descend-has-no-verb-noun-pick.md).
Area: **`src/cmdmode.tcl` (new file — the whole mechanism)**, `src/ase_window.tcl` (new
`sod_release` / `sod_suspend` / `sod_resume` + one `cmdmode::register` line),
`src/xschem.tcl` (the source line; `hi_descend_pick_arm` / `hi_descend_pick_cancel` /
`hi_descend_dialog` / `hi_descend_do` hooks), `src/callback.c` (`abort_operation` — ESC
during an armed pick had no Tcl continuation at all), `utils/cadence_nav.tcl`
(`return_one_level`'s window-hop arm), `src/Makefile.in` (install list).
Tests: `tests/headless/test_cmdmode_0201.tcl` — `CR1a`..`CR3c3`, 37 checks, pure Tcl, no
C / no Tk / no ASE, runs under bare `tclsh`. `tests/headless/test_cmdmode_descend_0201.tcl`
— `CS1`..`DS6h`, 70 checks, DISPLAY-gated, a real seized canvas driven through
`xschem callback`.
Related: [0200](0200-descend-has-no-verb-noun-pick.md) (the pick half — this is unreachable
without it), [0202](0202-canvas-gesture-seize-has-no-stack.md) (filed as the mechanical
blocker; **it turned out not to be one** — see "0202 is not a blocker" below),
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

### D1 — the contract must be generic, not ASE glue ✔ (user, explicit constraint) — DONE
"Keep code changes as orthogonal as possible to any code that supports waveform viewer and
graph elements." So: a small registry in a **new file** (e.g. `src/cmdmode.tcl`), a command
registers `{suspend_cb resume_cb}` under a key, descend calls
`cmdmode::suspend_all` before and `cmdmode::resume_all <new_win_path>` after. ASE's whole
participation should be one `cmdmode::register` line next to `select_on_design`, and
`sod_end` untouched.

Built as `src/cmdmode.tcl`: `register` / `unregister` / `suspend_all` / `resume_all` /
`rehome` / `is_suspended` / `pending`. Pure Tcl, no Tk (it is sourced unconditionally and
must survive `--nogui`, where `winfo` is not even a command), no ASE vocabulary anywhere.
ASE's entire share is two arms next to its own state plus one line:

```tcl
cmdmode::register ase_sod ase::ui::sod_suspend ase::ui::sod_resume
```

### D2 — resume where? → **in the descended context** ✔ (user, explicit) — DONE
`resume_cb` receives the canvas path, and `resume_all` reads it **itself, after the wrapped
body**. That timing is the whole decision: `alloc_xschem_data` installs the child path as
`current_win_path` inside `xschem schematic_in_new_window`, so a read taken any earlier —
in `hi_descend`, or at suspend time — yields the window the user just left. SOD's
implementation re-seizes on the given canvas, re-captures *that* canvas' predecessors, and
keeps `queue`/`qcolors`/`count`. Measured: `DS6c` lands the mode on `.x1.drw`.

### D3 — suspend must not finish the command ✔ — DONE
The teardown half of `sod_end` (lines 1642-1648: restore the three bindings, cancel the
pump, clear the prompt) is factored into `ase::ui::sod_release`. `sod_end` calls it and
then finishes; `sod_suspend` calls it and stops. `sod_end`'s own behaviour is byte-for-byte
what it was. The capture-then-`array unset` block that sits *between* teardown and finish
is what made a flag-through-`sod_end` wrong: it is neither, and a suspend must skip it.

### D4 — descend cancelled / failed → resume in place ✔ — DONE
`hi_descend_do` and `hi_descend_dialog` each became a thin wrapper around a `_body` proc,
with the resume after a `catch` — a finally, not a success path. One wrapper on
`hi_descend_do` covers every failure below it, because they are all inner frames: bad view,
non-subcircuit, `CADMAXHIER`, a cancelled Save-As or iteration prompt,
`schematic_in_new_window` refusing, `load_schematic` failing. The wrapper on
`hi_descend_dialog` covers Cancel, `<Escape>` on the dialog, the WM closing it, and a Tk
error building it.

Split into wrapper + `_body` rather than reindenting 85 lines into a `catch` block: the
diff stays off every line of a proc that lives in an actively-edited file.

### D5 — ESC during the pick → abort the pick, resume the command ✔ — DONE (needed C)
There was **no Tcl hook at all**. `abort_operation()` drops the arm via its blanket
`xctx->ui_state = 0` and calls nothing, so an ESC'd pick would have stranded the suspended
command forever. New arm at the top of `abort_operation` (`callback.c`), shaped like the
existing `DESEL_MODE` block and placed above it because that one returns:

```c
if((xctx->ui_state & MENUSTART) && (xctx->ui_state2 & MENUSTARTDESCEND)) {
  xctx->ui_state &= ~MENUSTART;
  xctx->ui_state2 &= ~MENUSTARTDESCEND;
  if(has_x) statusmsg(" ", 1);
  tcleval("hi_descend_pick_cancel");
}
```

so ESC and the click-on-empty-space cancel share one Tcl terminal. Clearing
`MENUSTARTDESCEND` is hygiene, not necessity — every arming site *assigns* `ui_state2`
wholesale, so a stale bit cannot be misread as a live arm — but it keeps
`xschem get ui_state2` an honest report, which `DS2f` asserts on.

### D6 — nesting depth → **one suspended set at a time** ✔ — DONE
`suspend_all` while already suspended is a no-op returning 0: everything is already
released, there is nothing left to take. `resume_all` with nothing suspended is likewise a
no-op. That latch is what makes the two-frame verb-noun descend honest — arm the pick, N
event-loop turns pass, then the dialog and the descend run in a *different Tcl call frame*
— because the several sites that must be able to resume can each call `resume_all`
unconditionally and exactly the first to arrive wins.

### D7 — go_back ✔ — DONE
Two arms, and only one needed anything. `cadence::return_one_level`'s **in-place**
`xschem go_back` does not change the canvas, and `ase::ui::sod_base_level` recomputes the
hierarchy prefix per click rather than latching it at arm time (0161), so a mode simply
stays correct across an in-place ascent. Its **window-hop** arm (`cadence::focus_window
$parent`, issue 0053) does change canvas, and now calls `cmdmode::rehome` — a
suspend+resume pair, not a pause, because the command was never interrupted.
`cadence::return_to_top` loops through `return_one_level` and inherits it.

### D8 — who else registers — deliberately nobody, still
`addpin` / `addlabel` / `ciform` have the same shape and could adopt the contract later.
Unchanged by this fix; nothing in their behaviour moved.

### D9 — abandoning an armed pick by arming a DIFFERENT verb — **OPEN, known gap**
Armed pick, and instead of clicking or pressing ESC the user presses `m` / `c` / `r`. Those
handlers do `xctx->ui_state2 = MENUSTARTMOVE;` — a wholesale **assignment** — which discards
`MENUSTARTDESCEND` silently, with no Tcl continuation. The suspended command is then
stranded: bindings down, queue unreachable until the user re-arms the mode (`Ctrl-4`, whose
`select_on_design` self-serialises through `sod_end` and plots the stranded queue, so it is
recoverable but ugly).

Not fixed here on purpose. The clean fix is a `set_menu_start(sub)` helper in `callback.c`
that every arming site routes through, notifying on displacement — ~15 call sites in the
single hottest file of the `fluid-editing` branch, which is exactly the merge risk 0200 and
0202 both went out of their way to avoid. Filed as a gap rather than smuggled in.

## 0202 is not a blocker after all

[0202](0202-canvas-gesture-seize-has-no-stack.md) was filed as this issue's *mechanical*
blocker, on the reasoning that a descend pick would have to **nest** above ASE's live
Button-1 seize, and the slots hold one predecessor each.

The pick does not nest. `hi_descend_pick_arm` suspends **before** `xschem descend_pick`, so
SOD has already handed `.drw` back by the time the pick is armed — the two owners are
strictly sequential and each slot still only ever has one. 0202 remains a real latent
hazard (nothing *enforces* LIFO, and `addpin`/`addlabel` still hand off by hardcoded
sibling name) but it is not on this path. `CS3a`-`CS3c` assert the hand-back is
string-identical, trailing `break` included, which is the invariant 0202 says the whole
scheme rides on.

The ordering has a second payoff nobody had written down. `clone_canvas_bindings`
(`xschem.tcl`) copies `.drw`'s bindings verbatim onto every new canvas at creation
(`xinit.c:2036`, `2252`). Had the seize still been up when a `new_window` descend ran, the
child would have inherited a **copy** of it with the parent's key already substituted:
clicks there would queue, but the child's ESC would call a `sod_end` that restores bindings
on the *parent* only, leaving the child permanently seized with dead scripts. Suspending
first means the clone always copies pristine bindings. `DS6d` is the leg that pins this.

## Measured

The four items this issue previously listed as unmeasured, now run:

1. **With Direct Plot armed, does `e` reach `hi_descend`?** **Yes** — and this needed a
   second pass to answer honestly. `DS1a` only shows that *calling* `hi_descend` works with
   the mode live; it enters the chain below the keyboard and proves nothing about the key.
   `DS7` closes it with real Tk events: `event generate .drw <Key-e>` arms the pick and
   suspends the command, then a real `<ButtonPress-1>`/`<ButtonRelease-1>` on the instance
   resolves it. SOD seizes only Button-1/Release-1/Escape, and `cadence_style_rc` binds
   only `<Control-Key-e>` / `<Alt-Key-e>`, so the plain-`e` binding `set_bindings` installs
   (`bind $topwin <Key-e>`, default `hi_descend_key e`) is untouched by either.

   **One real limitation, pre-existing and now pinned by `DS7e`:** that binding is on the
   **canvas**, so `e` only fires while the canvas holds keyboard focus. `select_on_design`
   does `catch {focus $cv}` at arm time for exactly this reason, so Ctrl-4 leaves focus in
   the right place — but clicking away into the ASE window or the CIW afterwards parks the
   focus elsewhere and `e` then does nothing at all. Not introduced here, not fixed here.
2. **Does a `target=current` descend leave the seize intact?** Moot, and better than the
   question assumed: the seize is deliberately taken down and put back (`DS5b`-`DS5h`), so
   the answer does not depend on `descend_schematic` happening not to touch Tk state.
3. **What does the prompt pump do after a `new_window` descend?** It no longer gets the
   chance to re-assert on a stale canvas: `sod_release` cancels it at suspend and
   `sod_resume` restarts it against the new canvas (`DS6c`).
4. **Does `dp_finish` behave with a queue spanning two hierarchy levels?** **Still
   unmeasured.** `CS9b` / `DS5i` prove the queue crosses a descend *unshortened* and
   reaches `dp_finish` whole, but `dp_finish` is stubbed in that test — the plotting side
   of a genuinely mixed-level queue needs simulation results and is untouched by this fix.

## Tests

**`tests/headless/test_cmdmode_0201.tcl`** — 37 checks, the contract on its own against
stub modes. No C, no schematic, no canvas, no Tk, no ASE: it runs under bare `tclsh`, which
is the executable proof of D1. `CR1a`-`CR1c3` registration; `CR1d`-`CR1i` the round trip
(every registered mode is *asked*, only the live ones are recorded, resume is LIFO and
carries the canvas); `CR1j`-`CR1l2` the D6 latch; `CR1m`-`CR1n2` the default canvas;
`CR2a`-`CR2c2` a **throwing suspend arm** does not strand the modes after it and is *not*
queued for resume (a half-released seize stays down); `CR2d`-`CR2e2` a throwing resume arm
does not stop the ones after it; `CR2f` a mode unregistered mid-flight is skipped;
`CR3a`-`CR3c3` `rehome`, including that it is a no-op while a suspend is in flight.

**`tests/headless/test_cmdmode_descend_0201.tcl`** — 70 checks, DISPLAY-gated, a real
`select_on_design` seize on a real canvas driven through `xschem callback`. `do_raise 0`
skips `ase::ui::design_window`, so no ASE session window has to exist; `dp_finish` is
stubbed so a suspend that wrongly *plotted* is visible and so the real end needs no
simulation. `CS1`-`CS3d` the seize and its verbatim hand-back; `CS4`-`CS5b` the records
survive; **`CS6`** the point — a suspend does not plot; `CS7`-`CS8c` resume re-seizes with
the queue intact; `CS9` ending after a full round trip still plots the *whole* original
queue. Then `DS1`-`DS6h` against the descend: **`DS1b`** the seize lets go so the armed
pick can actually receive its click, `DS2` ESC, `DS3` click on empty space, `DS4` click on
the instance with the dialog bailing, `DS5` a real `target=current` descend, `DS6` the hard
case — `target=new_window`.

**Sabotage-verified, three ways.**

| sabotage | legs that go red |
|---|---|
| `sod_suspend` calls `sod_end` (i.e. a suspend that *finishes*) | 27, incl. `CS6`, `CS4a`-`CS4d`, `CS8a` |
| drop `cmdmode::suspend_all` from `hi_descend_pick_arm` | `DS1b`, `DS1c`, `DS3a` — exactly the "the pick can receive its click" claim |
| `if(0 && ...)` on the new `abort_operation` arm | `DS2b`, `DS2c`, `DS2f` — exactly the ESC hole |

The first sabotage also exposed a hole in the test itself: legs read `sod()` directly and
threw on the missing records, aborting the file before its `RESULT:` banner and turning a
precise red into an unreadable `NORESULT`. Every `sod()` reader is now absence-tolerant.

Regressions, all still green: `test_cmdmode_0201`, `test_hi_descend`,
`test_ase_hier_pick_0161`, `test_ase_bus_bits_0159`, `test_ase_locked_wire_pick_0160`,
`test_ase_unnamed_net`, `test_ase_plot` (headless); `test_verb_noun_descend_0200`,
`test_ase_dialogs` (DISPLAY-gated, under the test gate).

## Not done here (deliberately)

- **D9**, above — an armed pick abandoned by arming a different verb.
- **The bypass descend entry points.** `callback.c` `case 'e'` / context-menu cases 12 and
  22, `xschem descend`, `xschem descend_symbol`, `cadence::descend_into_inst` all reach
  `descend_schematic()` without passing through any `hi_descend*` Tcl proc, so they neither
  suspend nor resume. Hooking them means wrapping `descend_schematic()` / `go_back()` in C
  rather than in Tcl. None of them is the reported user path.
- **A mixed-level queue through the real `dp_finish`** — item 4 above.
- **`addpin` / `addlabel` / `ciform` adopting the contract** — D8, unchanged.

## Cross-references

* `doc/claude/specs/ase_l.md` — Select-On-Design / Direct Plot scope.
* `doc/claude/issues/0161-ase-descended-pick-unqualified-name.md` — the hierarchy
  qualification that makes a mixed-level queue meaningful.
* `doc/claude/issues/0168-ase-direct-plot-not-hierarchical.md` — `session_for_current`
  walking the stack; the same ancestor logic a resumed mode leans on.
* `doc/claude/specs/hi_descend.md` §6 — the destination arms whose new-canvas behaviour is
  the hard case here.
