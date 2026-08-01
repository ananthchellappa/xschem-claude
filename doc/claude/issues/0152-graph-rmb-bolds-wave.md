# 0152 — RMB in a graph bolds the nearest trace, including during box-zoom

Status: **FIXED** (2026-07-25)
Area: `src/callback.c` (`waves_callback`), `src/xschem.h`, `src/xinit.c`
Tests: `tests/headless/test_wave_viewer.tcl` — `WB-*` legs
Related: 0142 (RMB XY box-zoom), 0149 (the graphs own the viewer window)
Reference: `doc/claude/code_analysis/waveform_subsystem_reference.md` §5

## Report

> What does RMB click currently do in the waveform window in the vicinity of a
> plotted trace (signal that has been plotted)? The trace become really thick.
> Is that a form of "selection"?
> Whatever, it is also happening (trace becoming thick) when I do RMB
> press-and-drag to zoom. Not good.
> If it is "selection", move that to plain LMB click.

## What it actually was

Yes — a form of selection/emphasis. It is the `hilight_wave` prop token on the
graph rect: `setup_graph_data()` parses it into `Graph_ctx.hilight_wave` and
`draw_graph`/`draw_graph_points` draw that one trace with extra width.

`waves_callback` toggled it on **ButtonPress + Button3** when the pointer was
inside the plot body (`callback.c`, the `POINTINSIDE(... gr->x1..gr->y2)` arm),
choosing the trace with `find_closest_wave()`. Two consequences:

1. Being on the **press**, it also fired at the start of every RMB press-drag —
   which since issue 0142 is the XY box-zoom. So every zoom gesture bolded
   whatever trace happened to be nearest the press point. That is the reported
   defect.
2. `find_closest_wave()` has **no distance threshold** — it returns the closest
   trace however far away it is. So "in the vicinity of" was really "anywhere in
   the plot body".

Note the pre-existing toggle semantics, which this issue does **not** change:
the branch tests the *currently* bold wave, not the one just found, so while any
trace is bold a click anywhere in the body un-bolds it, and only a click with
nothing bold selects the closest trace.

> ⚠ **SUPERSEDED by issue 0174 (2026-07-29).** Both paragraphs above are the
> record of what this issue knowingly left in place, and both were the reported
> defect the next time round. The pick is now `graph_wave_at()` at
> `GRAPH_TRACE_PICK_TOL` (10 screen px), so a click more than that from every
> trace selects nothing; and the toggle compares the trace just PICKED, so a
> click on trace B while trace A is bold moves the selection instead of clearing
> it. Kept, not deleted: this file is the record of why they survived this long.
> See `doc/claude/issues/0174-trace-pick-needs-proximity.md`.

## Decision (user, 2026-07-25)

- Move it to a plain **LMB click**, and remove it from RMB inside the plot body
  (RMB there becomes box-zoom only).
- Apply to **all graphs**, on-canvas schematic graphs included — one shared code
  path in `waves_callback`, no viewer-only gate. This does change long-standing
  upstream xschem behavior for embedded graphs.
- "Click" = **release with no drag**, and the click **wins over a cursor grab**
  armed by the same press.
- The **legend** affordance is untouched (see below).

## Fix

`waves_callback` (`src/callback.c`):

- The Button3-press arm keeps only its `else` branch — Button3 press **outside**
  the plot body still calls `edit_wave_attributes(2, ...)`.
- A new arm fires on **ButtonRelease + Button1**, inside the plot body, when the
  pointer travelled no more than `GRAPH_CLICK_TOL` (3) screen pixels from the
  press. A few pixels of tolerance rather than zero because real mice jitter on
  a click; 3 px is far below any intentional drag.
- Per the decision the click is not suppressed by a cursor grab: with no travel
  no cursor moved, and the `ButtonRelease` arm in the per-graph loop clears the
  grab flags (`graph_flags & (16|32|512|1024)`) regardless.

The press anchor lives in **new dedicated fields** `xctx->graph_press_x/y`
(`xschem.h`, initialized in `xinit.c`), **not** in `mx_double_save`/
`my_double_save`. That is the load-bearing part of the fix:

> the Button1 graph drag-pan **re-seeds** `mx/my_double_save` to the current
> pointer on every motion step past a threshold (`waves_callback`,
> `save_mouse_at_end` near the end of the function). At the end of a long pan
> they therefore equal the release position, and a click test against them
> fires — recreating the very defect on the new trigger.

A double-click (`event == -3 && button == Button1`, which opens the wave
attributes / graph properties dialog) invalidates the anchor, so the trailing
release of the double cannot also toggle the bold.

## Not changed (deliberately)

- **RMB on the legend** (outside the plot body) still toggles bold for the trace
  whose label was hit — `edit_wave_attributes(2, ...)` in `draw.c`. That is the
  *precise*, per-trace affordance; only the imprecise "closest wave to the press
  point" toggle moved. A **double**-click on a legend entry still opens the
  attributes dialog (`what == 1`).
- **LMB on the legend** does nothing, as before — the new click arm is gated on
  `POINTINSIDE` the plot body. Recorded as a boundary, not as a desired end
  state; making the legend LMB-selectable would be a separate change.
- The toggle semantics described above. **(Superseded by 0174 — see the note in
  "What it actually was".)**

## Tests + teeth

`tests/headless/test_wave_viewer.tcl`, block `WB` (needs the ngspice raw the
file already produces — `find_closest_wave()` bails on a NULL `xctx->raw`, so
without data every click writes `-1` and nothing is witnessable). Full Tk event
sequences through the shipped bindings, never a lone synthetic callback:

| leg | asserts |
|---|---|
| `WB-click` | LMB click bolds the closest trace; a second click clears it; canvas pinned |
| `WB-rmb-click` | RMB click in the body leaves the bold alone |
| `WB-rmb-drag` | RMB press-drag box-zoom leaves the bold alone **and still zooms** |
| `WB-lmb-drag` | a Button1 drag-pan does not bold **and still pans** |
| `WB-legend` | legend RMB still bolds that trace / un-bolds; ~~legend LMB does not~~ **SUPERSEDED — see below** |

⚠ **The `WB-legend` row's second clause is SUPERSEDED by issue 0175
(2026-07-30).** *"legend LMB does not [bold]"* was true here and was recorded as
a boundary rather than a decision. It is no longer true: a legend LMB click
**selects** that trace, Ctrl+LMB adds/removes it, and the leg in
`test_wave_viewer.tcl` asserts the new answer. The RMB half of the row still
stands, with one refinement — RMB on a legend entry now toggles that entry's
MEMBERSHIP of a possibly multi-trace selection, which is byte-identical to this
issue's behaviour whenever at most one trace is selected. The row is marked, not
deleted: it is the record of what the button meant between 0152 and 0175. See
`doc/claude/issues/0175-trace-legend-click-and-multiselect.md`, D5/D7.

Sabotage-verified:

- **S1** put the toggle back on Button3 press → `WB-click`, `WB-rmb-click`,
  `WB-rmb-drag` all FAIL.
- **S2** swap `graph_press_x/y` for `mx_double_save`/`my_double_save` →
  `WB-lmb-drag` FAILs (and only it).

**Test-harness gotcha found while writing these legs:** two identical
`event generate <ButtonPress-N>` calls close together are collapsed by Tk into
`<Double-Button-N>`, which the viewer binds to `{break}` — the second press then
never reaches the C engine at all (probe-verified: no `xschem callback`), and
the leg fails for a reason unrelated to the code under test. The WB legs stamp
every synthetic event with an explicitly increasing `-time` (`wb_ev`).

## Not verified

The actual **pixels** — that the bolded trace looks right — is eyeball-only,
like all wave rendering (`test_wave_viewer.tcl` header). What is asserted is the
`hilight_wave` token value, which is what the renderer reads.
