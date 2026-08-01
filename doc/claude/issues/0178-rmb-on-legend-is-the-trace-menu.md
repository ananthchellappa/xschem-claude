# 0178 — RMB on a legend entry is the TRACE CONTEXT MENU, not a selection toggle

**Status:** FIXED and **EYEBALLED PASS** (2026-07-30). CLOSED.
**Branch:** `fluid-editing`, commit `7562406d`, unpushed. Found at the 0177
eyeball, which also passed. Review gate: PROCEED — *"All good. Eyeball result
pass"*.

> The only thing I notice: RMB click on legend name is selecting a trace and RMB
> click legend of selected trace is deselecting it.

## 1. What it was

`callback.c`, inside `waves_callback`:

```c
else if(event == ButtonPress && button == Button3 &&
        !POINTINSIDE(xctx->mousex, xctx->mousey, gr->x1, gr->y1, gr->x2, gr->y2)) {
  if( edit_wave_attributes(2, i, gr)) { ... }
}
```

`what == 2` **toggles that trace's membership of the selection** — since issue
0175 the set version, before that a plain `hilight_wave` toggle. So an RMB press
on a legend name selected it, and a second one deselected it. Exactly as
reported, and deliberate: 0175 D7 made RMB-on-legend and Ctrl+LMB-on-legend the
same gesture on two buttons.

The reason it reads wrong is that it made the legend **the only region of the
viewer canvas where RMB is not a context menu**:

| RMB | before |
|---|---|
| on a trace, in the body | trace context menu (item 7, Tcl) |
| empty plot body | strip context menu → Split Strip (item 8, Tcl) |
| **a legend entry** | **toggles that trace's selection** (C) |
| press-drag on the body | box zoom (C) |
| axis margins, reorder grip | nothing |

Neither context menu could compete for the legend: `trace_menu_pick` required
proximity to a drawn trace (`trace_at`, body only) and `strip_menu_pick` gates on
`plotbox_at`. So the C toggle was the only thing there.

## 2. The fix

**A trace has two picking surfaces — its stroke in the body and its name in the
legend — and every other gesture already honours both.** Since 0175 an LMB click
selects from either. RMB now does the same thing from either.

Two Tcl changes; the only C edit is a **comment** (the arm itself is byte-identical):

1. `wviewer::trace_menu_pick` falls back to `wviewer::legend_at` when `trace_at`
   misses, so the trace menu's gate accepts a legend entry and resolves it to the
   same `{strip trace}` the legend names. Ordered stroke-first, matching the LMB
   arm's `on_body`-first test; the two regions do not overlap today, so the
   ordering is insurance rather than behaviour.
2. `wviewer::btn3_filter` **swallows a Button3 PRESS that lands on a legend
   slot** (new gate `wviewer::legend_slot_at`) instead of forwarding it to the
   engine. The release is still forwarded, and the menu posts from it as before.

### ⚠ Every modifier state, not just the unmodified press

The first cut copied the menu gate's own `$s & 13` (Shift|Control|Mod1) refusal
into the swallow, and **that left the entire reported defect alive under a
modifier.** Neither C's Button3 routing (`waves_selected`) nor the toggle arm
tests `state`, so Ctrl+RMB and Shift+RMB on a legend name went on selecting and
deselecting it — and *silently*, because the release gate then refuses to post a
menu for exactly those modifiers. Caught by adversarial review, not by the first
round of tests. A modified RMB on the legend is now inert: no toggle, no menu.
`TR4` covers Ctrl, Shift and Alt, and `TR5` asserts the exemption is gone.

### Why swallow the press rather than change the C arm

The C arm serves **graphs embedded in a schematic** as well as the viewer, and
those have no context menus at all — taking the toggle away there would remove
the only legend affordance they have, which nobody asked for. The viewer's RMB
policy already lives in Tcl (`btn3_filter`, `ctx_menu_post`), and the LMB path
already has the same shape: `strip_drag_press` decides whether to forward. So
"the viewer claims this press" is expressed where every other viewer-only gesture
decision is expressed.

### Why skipping the press is safe — and NOT for the reason first written here

`btn3_filter`'s block comment says the forward is unconditional "so that by the
time the menu gate runs, the engine has already erased any rubber rectangle and
cleared GRAPHPAN". That reasoning is about the **release**, and the release is
still forwarded.

The first draft justified the swallowed press with *"it is outside the plot box,
so it arms no box-zoom rubber and no GRAPHPAN"*. **That is false**, and
adversarial review caught it. The `GRAPHPAN` latch has **no plot-box test at
all**; it is suppressed by `xctx->graph_top`, which is set only for the band
*above* the plot box. Two of `legend_slot_hit`'s three layouts — `vlegend` and
`digital` — put the legend in the **left** margin, where `graph_top` is 0 and a
Button3 press *would* latch `GRAPHPAN`.

What actually kept the old press inert on a legend **hit** is the `return 0` C
takes as soon as `edit_wave_attributes` succeeds, *before* the latch. So on a
legend hit the engine only ever did the toggle, and not forwarding is equivalent
to it having done nothing.

⚠ **The corollary, which is why the wrong reason mattered:** do **not** widen
this swallow to the axis margins on the old argument. There `edit_wave_attributes`
misses, the latch *does* fire, `mx/my_double_save` is written, and the
still-forwarded release would commit a box zoom.

The press record `btn3_filter` keeps for its no-travel click test is written
before the forward either way, so the click test is unaffected.

**Fail-open, deliberately.** `legend_slot_at` answers `-1` when the band registry
is empty or the context switch is refused, and the press is then forwarded — it
degrades to the old toggle rather than swallowing a press that might have been a
box zoom. Failing closed would break RMB box-zoom on the body, the more costly
mistake.

### One behaviour deliberately given up

On a **single-trace strip** the trace menu refuses (the `>= 2 traces` rung, which
it has always had — its one action is "Move to Separate Strip"). RMB there now
does nothing, where it used to toggle. That is consistent with the body, where
RMB on the single trace of such a strip already did nothing, and
`legend_slot_at` deliberately has **no** `node_count` rung so the press is
claimed on those strips too — otherwise RMB would keep toggling on exactly the
strips where no menu can post, which is the same inconsistency moved somewhere
harder to find.

## 3. After

| RMB | after |
|---|---|
| on a trace, in the body | trace context menu |
| **a legend entry** | **trace context menu for that entry's trace** |
| empty plot body | strip context menu → Split Strip |
| press-drag on the body | box zoom |
| axis margins, reorder grip, a 1-trace strip's legend | nothing |
| **any** modified RMB on a legend entry (Ctrl / Shift / Alt) | nothing — inert |
| a graph embedded in a SCHEMATIC, on its legend | still toggles (C, unchanged) |

### A capability quietly gained: digital and bus strips

`trace_menu_pick`'s own contract block used to say digital and bus strips have no
trace menu at all, because `graph_wave_at` refuses their band/ribbon rendering.
That is still true of the **body** half of the gate — and now false of the whole
gate, because `graph_legend_at` deliberately does *not* refuse digital strips and
carries its own digital legend layout. It was given that exemption for the same
reason 0175 gave the legend an LMB select: on such a strip the legend is the only
way to name a trace at all.

So a digital or bus strip with two or more traces now gets "Move to Separate
Strip" from its legend, and `move_trace_to_new_strip` has no digital refusal, so
the entry works. Recorded here and in the source comment rather than left to be
rediscovered; **not covered by a test leg** (the fixture is analog).

Selection on the legend is **LMB's and Ctrl+LMB's alone**: plain LMB collapses
the selection to that trace, Ctrl+LMB adds/removes it (0175 D7, `TS6`).

## 4. Tests

`tests/headless/test_wave_trace_menu.tcl`, new group **`TR1`–`TR5`** (13 checks,
suite 315 → was 302), on the existing `TS*` fixture:

- `TR1` the gate: a legend pixel resolves to `{strip node}`, a body pixel and a
  pixel off every strip do not.
- `TR2` `trace_menu_pick` accepts a legend entry and names the same trace; **and
  the strip menu still refuses it.** ⚠ The two menus now partition the pointer by
  **two different mechanisms** — in the body the strip gate refuses whatever
  `trace_at` accepts, over the legend it cannot compete because it requires
  `plotbox_at`. Check both limbs when touching either gate.
- `TR3` the reported behaviour, through the real gesture: an unmodified
  `<ButtonPress-3>`/`<ButtonRelease-3>` on a legend entry does not select, and
  does not deselect a trace that was already selected. With an LMB control leg in
  between, so a leg that simply never selects anything cannot pass.
- `TR4` the menu posts.
- `TR5` the swallow is scoped to the unmodified press, and the C arm survives.

**Sabotage-verified:** restoring the unconditional forward reproduces the report
verbatim — `TR3` reports `{1 -}` where the selection must be empty and `{- -}`
where it must stay `1`.

⚠ **One existing leg had to be repaired, and it was right to fail.** `TG7`
"empty waveform space refuses" used `find_empty_px`, which walked the strip from
the top and returned a **legend** pixel — indistinguishable from body space while
both refused every gate, but now a legend pixel answers `{0 n}`. The helper gains
a `plotbox_at` rung, which is exactly the region item 8's own gate excludes, so
the fixture now agrees with the thing it tests against.

## 5. Verified / not verified

**EYEBALLED PASS, 2026-07-30.** The menu posts on a legend name, names that
trace, and neither a plain nor a modified RMB changes the selection.

Still not verified, and deliberately left:

- RMB on the legend of a graph **embedded in a schematic** still toggles. Not
  re-checked interactively; the C arm is byte-identical and `TR5` pins it.
- **Digital and bus strips gained a legend menu** ("Move to Separate Strip")
  they never had — a side effect of `graph_legend_at` not refusing them, kept
  because on such a strip the legend is the only way to name a trace. **No test
  leg covers it; the fixture is analog.** The cheapest way to close this is a
  digital fixture in `test_wave_trace_menu` asserting `trace_menu_pick` answers
  on the legend and `-1` across the body.
- A single-trace strip's legend is inert on RMB (no toggle, no menu). Recorded
  as a decision, not an accident: the menu's one action is meaningless there,
  and leaving the toggle would move the inconsistency somewhere harder to find.
