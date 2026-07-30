# 0174 — a click anywhere on a strip selects a trace, and always the same one

- **Status:** FIXED (2026-07-29)
- **Area:** `src/callback.c` (`waves_callback`, the LMB wave-bold arm), `src/draw.c`
  (`find_closest_wave`), `src/xschem.h`, `src/scheduler.c`, `src/wave_viewer.tcl` (comments)
- **Tests:** `tests/headless/test_wave_viewer.tcl` — `WB-precise*` + the retargeted
  `WB-click`; `tests/headless/test_wave_trace_menu.tcl` — the new `TB*` block
- **Related:** 0152 (the arm's previous owner — its "toggle semantics unchanged"
  paragraph is superseded here), 0142 (RMB box zoom), 0134/0151 (viewer modes)
- **Reference:** `doc/claude/code_analysis/waveform_subsystem_reference.md`
  landmines 19, 20, 33, 34; `doc/claude/specs/waveform_viewer_modes.md` §12.5

## Report

> Right now, clicking anywhere on a strip selects the first trace that was
> plotted on that strip. Not good. We should only permit a trace to be selected
> when the click happens reasonably close to a point on that trace. Currently, if
> there are multiple traces on a strip, it is only ever possible to select the
> very first trace that was plotted.

## What it actually was — FOUR defects, all measured

The recon named two. A third fell out of measuring them, and a fourth out of the
review. Everything below is a
number off a running binary (`--nolog --script` probe, ASE viewer, one strip,
three separated ramp traces `vsweep+1 / +3 / +5`, 1000x776 canvas), not a
reading of the source.

### (a) There was no distance threshold

`find_closest_wave()` (`draw.c` ~4488) has none: it minimises `fabs(yval - yy)`
at the nearest sample and returns the winner **however far away it is**. The
`GRAPH_CLICK_TOL` in the arm's guard is the click-vs-drag **travel** test, not a
distance to a trace.

Measured, centre column, `px = 500`:

- **714 of 776 pixel rows** are more than 10 screen px from every trace
  (`graph_trace_at` says -1), and a click on every one of those rows inside the
  plot body bolted a trace anyway.
- What it bolted was **not** node 0. It was banded, top to bottom:
  rows 116–276 → node 2, 284–500 → node 1, 508–660 → node 0. So **(a) on its own
  gives a wrong-but-VARYING trace**, never "always the first".

### (b) The toggle compared the wrong thing — this is the "always the first" half

```c
  /* NOTE (pre-existing semantics, kept): the test is on the CURRENT bold wave, not
   * on wcnt -- so while any wave is bold a click anywhere in the body un-bolds it,
   * and only a click with nothing bold selects the closest wave. */
  if(gr->hilight_wave >= 0) gr->hilight_wave = -1;
  else                      gr->hilight_wave = wcnt;
```

Measured, clicking pixels the engine agrees are exactly on each trace:

```
start                      bold = -1
click ON node 0     ->     bold = 0     (correct)
click ON node 2     ->     bold = -1    (wanted 2)
click ON node 2 again ->   bold = 2
```

**The selection can never move from trace A to trace B.** The click that should
pick B clears A instead. This is what produces the user's words: whichever trace
they land on first is the only one that ever appears selected, because every
attempt to move to another one just deselects. Two further things sharpen it
into *"the very first trace that was plotted"*:

- the very first click of a session has nothing bold, so it takes the `else`
  branch and picks by (a) — nearest `|Δy|`;
- `find_closest_wave`'s running minimum is strictly-less (`tmp < min`, `min`
  seeded by the first candidate), so **ties go to the lowest node index**, i.e.
  to the first trace plotted. On a strip where traces overlap or sit at the same
  value — routine in a bandgap testbench — node 0 wins outright.

**Verdict on the prompt's question:** the user's exact wording is produced by
**(b)**; (a) supplies the "clicking anywhere selects something" half. Neither
alone reports index 0 always, and the `min < 0.0` first-candidate seeding is a
real contributor but only on ties, so it is not a separate third mechanism.

### (c) NEW — the two early exits left `*node_number` unwritten

Found by measurement, not by reading. `find_closest_wave()` returned from both
`if(!xctx->raw)` and `if(gr->digital)` **before** `*node_number = -1`, and the
caller declared `int wcnt;` uninitialised. So a plain body click:

```
digital strip, three traces:   hilight_wave = -1859984240
analog strip, raw cleared:     hilight_wave = -1859984240
```

Stack garbage, written through `subst_token` into the graph rect's persisted
`hilight_wave` token. Not a crash — `draw_graph` just never matches it — but it
is undefined behaviour and it rides a save.

### (d) The selection is per-STRIP, so it cannot move between strips either

Raised by the user at review, after (a)-(c) were already fixed and committed:

> clicking on another trace SHOULD deselect all currently selected traces
>
> [and] It is currently true only if the two traces are within the same strip

`hilight_wave` is a **per-rect prop token**, and the arm only ever touches
`xctx->rect[GRIDLAYER][xctx->graph_master]` — the strip under the pointer. So
even with (b) fixed, selecting a trace on strip A and then clicking one on strip
B left BOTH bold. Measured, two strips with two traces each, as
`{strip0 strip1}`:

```
start                        -> {-1 -1}
click a trace on strip 0     -> { 0 -1}
click a trace on strip 1     -> { 0  0}    <- both bold; wanted {-1 0}
```

This is the same "the selection cannot move" defect as (b), one level up. It is
also why the within-strip legs alone were not enough: `tb_bold` reads strip 0,
and every leg written against it passes while strip 1 keeps a stale bold. The
witness for these legs has to be the WHOLE STACK (`tb_bolds`).

### The asymmetry that made it a bug report

`graph_wave_at(i, px, py, tol)` (`draw.c` ~5229, via `graph_point_at`) already
answers "which displayed trace passes within `tol` **screen pixels** of this
**canvas pixel**" with a real point-to-segment distance, and the RMB trace
context menu, the LMB trace drag between strips and the RMB strip menu's
negative gate **all already gate on it, at tol 10**. So the RMB menu was precise
and the LMB select was not, on the same strip, from the same pixel. Closing that
was mostly deleting the old pick.

## Decisions

### D1 — `tol` is `GRAPH_TRACE_PICK_TOL`, 10 screen pixels, not zoom-scaled, not a config var

10 is what `wviewer::trace_at` / `wviewer::near_wave_at` default to and what
every existing picking surface therefore uses: `trace_menu_pick` (~5603),
`strip_drag_press` (~2859), `trace_drag_arm` (~3826), `strip_menu_pick` (~5748),
plus the `xschem get graph_trace_at` / `graph_near_wave` verb defaults
(`scheduler.c`). Four surfaces on one strip disagreeing about "close enough" is
the next bug report, so the click matches them rather than inventing a number.

Not zoom-scaled: the metric is already screen pixels (`S_X`/`S_Y` carry
`xctx->mooz`), and every tolerance in this family is fixed screen pixels by
design (`xschem.h` ~399). ⚠ The travel test above it multiplies `GRAPH_CLICK_TOL`
by `xctx->zoom` because that one is compared in **world** units — do not copy
that pattern here.

Not a config var: nothing else in this family is one, and a knob would let the
four surfaces drift apart, which is the failure this decision exists to prevent.
The literal was instead promoted to `#define GRAPH_TRACE_PICK_TOL 10.0` in
`xschem.h` beside the marker tolerances and used from both C sites; the two Tcl
proc defaults are commented as mirroring it.

### D2 — a click in empty plot-body space CLEARS the selection

⚠ **REVERSED AT REVIEW (2026-07-30).** I originally decided *leave it alone*,
reasoning that empty body space is also the strip drag-reorder gesture (§12.5)
so "clears" would mean a drag that fails its travel threshold silently
deselects. The user's decision: **"clicking on empty space SHOULD deselect all
currently selected traces."**

The worry was unfounded and I should have checked it instead of designing around
it: the two gestures are separated by the **travel test**, not by this branch. A
real reorder drag travels well past `GRAPH_CLICK_TOL` (3 px), so its release
never reaches the wave-bold arm at all. The only thing that clears is a
press-release that moved less than 3 px — which is a click by any definition.
`WB-lmb-drag` is the leg that holds the drag half of that.

### D3 — clicking the already-selected trace KEEPS it selected

⚠ **REVERSED AT REVIEW (2026-07-30).** I originally chose toggle-off, on the
grounds that with D2 = leave-alone there would otherwise be **no LMB way to
deselect at all**. The user's decision: **"clicking on a selected trace should
not deselect it"** — Cadence behaviour, which was the starting position and
which I talked myself out of.

Both halves of my argument fell with D2. Deselecting everything is now a click
on empty space, and deselecting ONE trace is 0175's Ctrl+click:

> if a few traces are selected and user clicks on A trace, then only the
> recently clicked-on trace will be selected. It takes a CTRL+click to add to
> selection. CTRL+Click on a selected trace will also deselect that trace.

So a plain click never deselects what it lands on — that affordance belongs to
Ctrl+click, and reserving it here is what leaves room for 0175.

**WB leg count before starting: 18** (`test_wave_viewer.tcl`, lines 1551-1687).
D3 turns **zero** of them red — the WB fixture carries a single trace, so
`WB-click second LMB click un-bolds` re-clicks the same trace and still clears.
The leg that did go red is `WB-click LMB click bolds the closest wave (trace 0)`,
and for the D1 reason: it clicked (0.50W, 0.50H), about **0.30·H** from the only
trace. It is retargeted to a scanned on-trace pixel and renamed
`WB-click LMB click ON a trace bolds it (trace 0)` — the old label asserted
"closest", which is no longer what the arm does.

### D4 — everywhere, on-canvas schematic graphs included

The arm is one branch of `waves_callback`, shared with the ~127 embedded
schematic graphs. Precise picking is strictly better there too, and gating it
viewer-only would leave those graphs with the imprecise pick **and** with defect
(c). Stated explicitly: **on-canvas schematic graph behaviour changes as well.**

### D5 — digital and bus strips answer -1, and that is a FIX, not a loss

The worry was that a digital strip's body becomes unselectable where today it
selects something. Measured: **today it selects garbage.**
`find_closest_wave` already refused digital strips (`draw.c` ~4509) and already
skipped bus entries (~4550) — exactly like `graph_wave_at` — so there was never
a selection to lose; the difference is only that the old refusal returned before
writing `*node_number` and the new one returns a clean -1. Nothing regressed and
defect (c) is closed on both paths.

Recorded for later: the ASE viewer never emits `digital=1` (its `graph_props`
has no such key), so digital strips today are an **embedded-graph** phenomenon.
If selecting on one is ever wanted, 0175's legend click is the way — and the
legend RMB already works there, it has its own digital layout.

## Fix

`callback.c`, the `ButtonRelease + Button1` arm (~877):

```c
      wcnt = graph_wave_at(i, (double)mx, (double)my, GRAPH_TRACE_PICK_TOL);
      /* the selection BECOMES what the click picked; wcnt is -1 on a miss */
      if(gr->hilight_wave != wcnt) {
        gr->hilight_wave = wcnt;
        my_strdup2(_ALLOC_ID_, &r->prop_ptr,
                   subst_token(r->prop_ptr, "hilight_wave", my_itoa(gr->hilight_wave)));
      }
      /* ... and it is ONE trace in the WINDOW: clear every other graph rect */
      for(k = 0; k < xctx->rects[GRIDLAYER]; ++k) {
        xRect *rk = &xctx->rect[GRIDLAYER][k];
        const char *hw;
        if(k == i || !(rk->flags & 1)) continue;
        hw = get_tok_value(rk->prop_ptr, "hilight_wave", 0);
        if(!hw[0] || atoi(hw) < 0) continue;   /* ABSENT is not index 0 */
        my_strdup2(_ALLOC_ID_, &rk->prop_ptr,
                   subst_token(rk->prop_ptr, "hilight_wave", "-1"));
        need_all_redraw = 1;
      }
      if(save != gr->hilight_wave && !need_all_redraw) { draw_graph(...); }
```

One assignment covers D2, D3 and the reported defect at once, because
`graph_wave_at` already answers -1 on a miss. The cross-strip sweep is the
separate half (defect (d)).

- `mx`/`my` are **`waves_callback`'s own parameters** — the event's canvas
  pixels. Not `xctx->mousex/mousey`, which are schematic-space and stale for a
  press with no preceding Motion (landmine 33), and which `graph_wave_at` would
  not accept anyway.
- the prop write happens only when the value actually **changes**, so a click in
  empty space with nothing selected does not churn the prop string.
- the cleared strips are repainted by the existing all-graphs loop
  (`need_all_redraw`, `callback.c` ~1520), which runs its own
  `setup_graph_data(k, 0, gr)` per rect. Doing the repaint inline would mean
  calling `setup_graph_data` on a non-master rect with the SHARED
  `xctx->graph_struct` this arm is still holding (landmines 11 and 37).
- an **absent** `hilight_wave` token means nothing is bold there. A bare
  `atoi("")` would read it as node 0 and "clear" a strip that was never
  selected — the check is `hw[0] && atoi(hw) >= 0`.
- `graph_wave_at` uses a LOCAL `Graph_ctx` and brackets the hcursor flag bits
  (landmines 11 and 37), so it cannot disturb `gr`.
- **Unchanged, deliberately:** `POINTINSIDE` (the arm is plot-BODY-only; the
  legend margins are Button3's) and the `GRAPH_CLICK_TOL * xctx->zoom` travel
  test. The double-click arm (~1199) poisons `graph_press_x/y` with `-1e30`
  precisely to make that test unsatisfiable, which is what stops a double-click
  from bolding underneath the wave dialog — the gate must stay on those fields.
- No `set_modify`, no `push_undo` (landmine 19): selection is view state.
- Nothing is logged, as before.

`draw.c`, `find_closest_wave`: `*node_number = -1;` moved **above** both early
returns (defect (c)). The one remaining caller — the `t` dataset-track arm,
`callback.c` ~1341 — only reads the return value, but the "always writes"
contract belongs in the function, not at a call site. The function itself is
otherwise untouched and is **not** deleted.

`xschem.h`: `#define GRAPH_TRACE_PICK_TOL 10.0`, with the four-surface list.
`scheduler.c`: the two `10.0` verb defaults now name it.

## Tests + teeth

| leg | asserts |
|---|---|
| `WB-precise` (test_wave_viewer) | a plot-body click FAR from every trace bolds nothing, and does not clear an existing bold either |
| `WB-click` (retargeted) | a click ON the trace bolds it; a second one clears it |
| `TB-far` (test_wave_trace_menu) | defect (a): a far click selects NOTHING |
| `TB-move` | defect (b): a click on trace B while A is selected MOVES the selection, in ONE click |
| `TB-same` | D3: re-clicking the selected trace KEEPS it selected |
| `TB-clear` | D2: a far click CLEARS the selection |
| `TB-cross` | defect (d): the selection is one trace in the WINDOW — a click on strip B clears strip A, and empty space on B clears everything. Witness is the whole stack (`tb_bolds`), never one rect |
| `TB-agree` | the C click arm and `graph_trace_at` agree on EVERY scanned row of the plot box |
| `TB-node` | the witness is a NODE index (node 2 = MODEL index 3 on a fixture with a vec-less trace) |
| `TB-digital` / `TB-noraw` | defect (c): no uninitialised garbage on either early-exit path |
| `TB-clean` | landmine 19: no modify, no undo point |

Counts: `test_wave_viewer` **349 → 356** DISPLAY, 48 nogui unchanged;
`test_wave_trace_menu` **223 → 249** DISPLAY, 71 nogui unchanged.

**Anti-hollowness.** "It picks the nearest trace" is not the test — a leg that
only clicks ON a trace passes against the thresholdless pick too. `TB-far` and
`WB-precise` are the load-bearing ones, and both carry the same teeth: the same
pixel queried with `tol 1e30` **does** find a trace, so -1 at the shipping
tolerance means "far from every trace", not "this strip has no data". The click
pixels are scanned from the engine's own `graph_trace_at`, never a fraction of
the widget — a fixed fraction is exactly how the old `WB-click` passed.

The multi-trace legs live in `test_wave_trace_menu.tcl` because that is the only
suite with a **live** multi-trace strip (hermetic `xschem raw new/add`, no
ngspice). `test_wave_viewer.tcl`'s WB fixture has one trace on strip 0, where
"picks the nearest" and "picks node 0" are the same answer and neither defect is
witnessable; it keeps the single-trace precision legs. The TB fixture also plants
a **vec-less** trace at model index 1 so MODEL and NODE index spaces diverge
(landmine 34).

### Sabotage matrix — (a), (b) and (c) turn DISJOINT leg sets red

| sabotage | red legs |
|---|---|
| (a) `find_closest_wave` restored at the call site | `WB-precise` ×2, `TB-far`, `TB-keep`, `TB-agree` (31 of 108 scanned rows disagreed) — **`TB-move` stayed green** |
| (b) `if(gr->hilight_wave >= 0)` restored | `TB-move`, `TB-same` — **and nothing else** |
| (c) defect (c) restored (`*node_number` unwritten again) | `TB-digital`, `TB-noraw` — **and nothing else** |
| tol forced to 0 | `WB-click`, `WB-precise` ×2, `SD2`, `TD4`, `TD6` ×2, `TG11`, `TB-move` ×2, `TB-keep` ×2, `TB-agree`, `TB-node` — the pre-existing legs guard the tolerance too |
| MASTER: the whole pre-0174 arm restored | the union of (a) and (b) |

After the review reversed D2/D3 and added (d), re-verified:

| sabotage | red legs |
|---|---|
| (f) cross-strip sweep removed | the four `TB-cross` legs — **and nothing else**. Measured pre-fix state: `{0 0}`, both strips bold |
| (g) a click on the selected trace deselects again | `TB-same`, `TB-cross` re-click, `WB-click a second click on the same trace KEEPS it bold` |
| (h) a miss changes nothing (the pre-review D2) | `TB-clear`, `WB-precise a far click CLEARS the selection` |

A model-index sabotage is **not expressible**: `hilight_wave` and
`graph_wave_at` are both NODE-space in C and the model space exists only in Tcl,
so there is nothing to swap. `TB-node`'s teeth are instead that the fixture's two
spaces genuinely diverge (`TB0` asserts 4 model traces / 3 node slots and node 1
= model 2), which the tol-0 sabotage does red.

`TG9 it was posted in ROOT coordinates` went red in some runs. **Measured
control: it fails 4 in 10 on PRISTINE HEAD** (work stashed, pristine rebuild,
`run_suites.sh -n 10 test_wave_trace_menu` → 6/10 passed, the only failure TG9
every time). It is a WSLg flake of the same family as `test_ase_plot`'s: the leg
compares a synthetic `<ButtonPress-3>`'s Tk-synthesised `%X/%Y` against
`winfo rootx`, and the WM can move the viewer between legs. It is a Button3 leg
that runs *before* the `TB*` block, so it is upstream of everything changed here.
Not touched.

## Not changed (deliberately)

- `find_closest_wave()` itself, beyond the `*node_number` ordering. The `t`
  dataset-track arm still uses it.
- The double-click path (`edit_wave_attributes(1, ...)`) and its `-1e30`
  press-anchor poison.
- The Button3-on-legend per-trace bold — it was already precise and already
  per-trace; the body click now agrees with it.
- `POINTINSIDE` still reads the schematic-space mouse mirror. The arm is
  body-only and that contract is unchanged; switching it is a separate change
  with its own risk to the `WB-legend` boundary.
- Multi-select, legend clicks and Ctrl-click (0175). DEL (0176).

### Suites

Full waveform battery, DISPLAY arm, one pass: **14/15**, every count as pinned
(`test_wave_snap` 59, `test_wave_grid` 80, `test_wave_legend` 44,
`test_wave_empty_strips` 94, `test_wave_modes` 410, `test_wave_markers` 712,
`test_wave_clear_all` 68, `test_ase_plot` 150, `test_wave_split_strip` 221,
`test_wave_drag_preview` 46, `test_ase_persist` 109, `test_ase_unnamed_net` 28,
`test_ase_window` 166) plus this issue's two: `test_wave_viewer` 349 → **356**,
`test_wave_trace_menu` 223 → **243**. nogui unchanged: 48 / 71.
(Both re-verified against the committed code on 2026-07-30 — 356 / 243, ALL
PASS. The first attempt at that re-verification was worthless: WSLg had stopped
mapping toplevels, so every GUI leg SKIPPED and the suites reported
"ALL PASS (73 checks)" / "ALL PASS (72 checks)". ⚠ **A green line is not a green
suite — always read the check COUNT.**)

**10× soak of the whole battery: 136/150.** The 14 non-passes are six *different*
suites failing six *different* legs at about 1-in-10 each, all of the
synthetic-gesture / scan-found-nothing / keysym-didn't-resolve shape that WSLg
produces — a real defect fails the same leg every time:

| leg | rate | note |
|---|---|---|
| `TG9` posted in ROOT coordinates | 6/10 | **4/10 on pristine HEAD** (measured control) |
| `test_ase_plot` P4/P6 | 1/10 | the documented always-flaky ESC+wire-click legs |
| `SG6` / `ST21` (snap) | 1/10 | trace-pixel scan found nothing |
| `MF0` / `MF1` / `MZ1` (markers) | 1/10 | `MF0` "two trace pixels were SCANNED" failed first; `MZ1`'s count shortfall follows from it |
| `MG13` Ctrl+Shift+4 keysym | 1/10 | Tk keysym resolution |
| `AN8` empty-space click | 1/10 | **schematic** `sod_click`; never enters `waves_callback` |
| `W3` double-click editor | 1/10 | ASE window dialog |
| `NORESULT` ×2 of 150 | — | harness "binary never reported"; the same scripts exit 0 run directly |

**The pristine control, 2026-07-30.** Run in a `git worktree` at the pre-0174
commit (verified pristine: zero occurrences of `GRAPH_TRACE_PICK_TOL`), NOT by
stashing — an interrupted stash cycle leaves the tree sitting on pristine code,
which is how the first attempt at this control ended. 10× the five suites other
than `test_wave_trace_menu`: **46/50**.

| leg | pristine | verdict |
|---|---|---|
| `AN8 empty-space click queues nothing -> {v(short)}` | **1/10, byte-identical** | flake, confirmed directly |
| `MF1 the anchor really SLID` | **1/10** | flake, confirmed directly |
| `test_ase_window` | **2/10** (`W6c Ctrl-W destroyed the log window`) | the suite has flaky legs on pristine; the soak's `W3` is the same family |
| `SG6` / `ST21` (`test_wave_snap`) | 0/10 | see below |
| `MG13` (`test_wave_modes`) | 0/10 | see below |

`SG6`/`ST21` and `MG13` did not recur — but neither did they on a follow-up
**15× of both suites on the 0174 build: 30/30**. One occurrence in 25 runs of
each suite on this code, zero in 10 on pristine. n is too small to separate those
two rates, so the argument that closes it is **reachability, not statistics**:

- `SG6`/`ST21` drive a `<Motion>` sweep and read `xschem get graph_snap`. No
  Button1, no ButtonRelease — they never enter the arm that changed. The snap
  path is `graph_plotbox_at` + `graph_point_at` at tol `1e30`, and neither
  function was touched.
- `MG13` resolves a Tk keysym string (`<Control-Key-dollar>`). No C graph code at
  all; it is the `wslg-key-delivery-flakes` family.

The only behavioural deltas in this commit are the ButtonRelease+Button1 arm and
`find_closest_wave`'s `*node_number` ordering (a no-op for its one surviving
caller, which reads the return value). The `scheduler.c` edits replace the
literal `10.0` with a `#define` of the same value — identical semantics.

## Manual sequence (this is a POINTER behaviour — the suite cannot close it)

```
src/xschem --script sky130A/cadence_style_rc --logdir /tmp
```
open `sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/schematic/tb_bandgap.sch`,
then its `ngspice_state1` so the viewer comes up. Get **three or more traces onto
one strip** and Fit (`f`) so they are separated.

| # | do | expect | must NOT happen |
|---|---|---|---|
| 1 | click on trace A | A goes bold | — |
| 2 | **click on trace B (no click in between)** | B goes bold, A goes thin | ❌ nothing bold — that was the bug |
| 3 | click on trace C | C bold, B thin | ❌ selection stuck on A or B |
| 4 | click on C again | **C stays bold** (a plain click never deselects) | ❌ C un-bolds |
| 5 | click well **between** two traces, in the middle of the plot body | **everything un-bolds** | ❌ a trace bolds |
| 6 | select A, then click in empty body space | **A un-bolds** | ❌ A stays bold |
| 7 | with A bold, press-drag from empty body space to another strip and drop | strips reorder as before, **A still bold** — a real drag is not a click | ❌ A un-bolds |
| 7b | **two strips**: select a trace on strip 1, then click a trace on strip 2 | strip 1 goes thin, strip 2 bold — **never both** | ❌ both stay bold |
| 7c | with a trace bold on strip 1, click empty space on strip 2 | **strip 1 un-bolds** | ❌ strip 1 stays bold |
| 8 | click ~5 px above/below a trace | it bolds (10 px band) | — |
| 9 | click ~25 px away from every trace | nothing | ❌ something bolds |
| 10 | RMB on a trace → the trace menu; LMB on the same pixel | both act on the **same** trace | ❌ they disagree |
| 11 | double-click a trace | the wave dialog opens; the bold state is **unchanged** by the double-click | ❌ a trace bolds under the dialog |
| 12 | on an **embedded schematic graph** (`xschem_library/examples/test_ne555.sch`), click in the body away from every trace | nothing bolds | ❌ a trace bolds (D4: this changed too) |
| 13 | on a **digital** strip (an embedded graph with `digital=1`), click anywhere in the body | nothing bolds, and the graph does not misdraw | ❌ anything bolds |

Step 2 is the reported defect within a strip; **7b is the same defect across
strips** (defect (d)). Step 5 is the proximity half. Steps 5/6/7c are D2, step 4
is D3, step 12 is D4, step 13 is D5. Step 7 is the one that would break if D2 had
been implemented by clearing on anything other than a no-travel click.

## Not verified

- Pixels. That the bolder trace *looks* bold, and that 10 px feels right under a
  real hand rather than a synthetic event, is eyeball-only — see the manual
  sequence handed over with this issue.
- Behaviour on a strip where two traces cross within 10 px of the click. The
  engine's rule is documented (strictly-nearer wins, ties to the first node) and
  is unchanged from what the RMB menu has always used, but no leg drives it.
