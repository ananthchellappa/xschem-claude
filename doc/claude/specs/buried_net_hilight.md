# Buried-Net Highlight Indicator — surface deep highlighted nets at ancestor instances

Status: IMPLEMENTED (detection + drawing; headless test green, GUI-verified at levels
C and A). Animation parity inherited by construction; multi-window per-context by
construction. Plan: `doc/claude/suggestions/plan_buried_net_hilight.md`. Derived from
[[net_hilight_styles]]. Related memory: [[net-hilight-styles]],
[[hilight-anim-freeze-on-descend]], [[hi-descend]], [[descend-newwin-return-chain]].

## 1. Goal

When a net is highlighted deep in the hierarchy and the user climbs back up, the
highlight currently **vanishes from view**: a net buried inside an instance — one
that does not reach any of that instance's interface pins — leaves no trace at the
parent level. The user has no way of knowing, while looking at the parent, that
"there is something highlighted down there."

This feature makes an instance **inherit a visual cue** when its subtree contains a
highlighted net that is *not visible at the current level*. The cue is a rectangle
drawn around the instance, rendered in the **same highlight style** (color / width /
dash / blink / march) as the buried net, so the user can tell at a glance both *that*
and *with which style* a net is highlighted somewhere inside.

This is the natural complement to the existing **pin propagation**: today, a buried
net that *does* connect to an instance pin already colors the instance (via
`propagate_hilights()` setting `inst[i].color`). This spec covers the gap — buried
nets that connect to **no** pin and are therefore invisible above.

## 2. Behavior (the canonical walkthrough)

Hierarchy: **A** contains **B** (instance `x_b`) contains **C** (instance `x_c`)
contains **D** (instance `x_d`). The user descends all the way into `x_d` (now
viewing cell **D**) and highlights a net **internal to D** — i.e. a net of D that is
**not** wired to any of D's symbol pins.

| User is viewing | Sees | Why |
|---|---|---|
| **D** (deepest) | the net itself highlighted (wire + style) | the net lives here |
| **C** (one up) | instance **`x_d`** gets a styled rectangle | the highlighted net is buried inside `x_d`'s subtree, not on its pins |
| **B** (two up) | instance **`x_c`** gets a styled rectangle | the highlight is buried somewhere under `x_c` |
| **A** (three up) | instance **`x_b`** gets a styled rectangle | …and under `x_b` |

The rectangle's style is identical to the buried net's highlight style. If that style
blinks or marches, the rectangle blinks/marches in phase with it.

### 2.1 Removing the cue

Because the buried net is several levels down and **cannot be picked at the parent
level**, there is *no* per-net unhighlight available from above. Removal is therefore
by **unhighlight-all** only:

```
xschem unhilight_all        # the only way to clear a buried-net cue from above
```

(If the user descends all the way back down to D and unhighlights that specific net,
the cue also disappears — because it is recomputed from the live highlight table.)
This asymmetry is **intentional and documented**, not a defect.

## 3. Definitions

- **Current level / current path** — the schematic the user is viewing, identified by
  `xctx->sch_path[xctx->currsch]`. Paths are dot-delimited with a leading and trailing
  dot: `"."` (root), `".x_b."`, `".x_b.x_c."`.
- **Subtree of instance `inst[i]`** — every highlighted net whose hierarchical path is
  *strictly deeper than* the current path through that instance, i.e.
  `entry->path` begins with `current_path + inst[i].instname + "."`.
- **Buried net** — a highlighted net in an instance's subtree that is **not exposed at
  that instance's pins** at the current level (so it is not already shown by pin
  propagation / instance color here).
- **Buried-highlight cue / indicator** — the styled rectangle this feature draws
  around an instance that owns at least one buried net.

## 4. Detection algorithm

Detection runs wherever instance highlight state is already recomputed:
inside (or immediately after) `propagate_hilights()` — which the engine already calls
on every highlight change, on descend, and on ascend. One extra pass, computed once
per recompute (not per redraw, not per animation frame):

1. **Reset.** Set `inst[i].buried_hilight = -1` for every instance (`-1` = no cue).
2. **Collect.** Single scan over `xctx->hilight_table[]`. Let `P =
   xctx->sch_path[xctx->currsch]`. For each live entry whose `entry->path` is strictly
   longer than `P` **and** begins with `P`:
   - Extract the *immediate child component* `c` = the substring of `entry->path`
     after `P` up to the next `.`. That is the instance name at the current level whose
     subtree the highlight lives in.
   - Record `child_style[c] = pick(child_style[c], entry->value)` where `pick` is a
     deterministic choice (v1: **lowest style index**; see §8 for multi-style).
3. **Assign.** For each instance `inst[i]`:
   - If `inst[i].instname` matches a collected child `c`, **and** the instance is not
     already shown as pin-highlighted at this level (`inst[i].color < 0`, i.e. the
     `-10000` "no hilight" sentinel — see `propagate_hilights()`), then set
     `inst[i].buried_hilight = child_style[c]`.
   - (Excluding pin-highlighted instances avoids double-marking: if the buried net
     reaches a pin, the instance is already colored, which is the existing, sufficient
     cue.)

The algorithm is **inherently recursive over depth**: at level C, `x_d`'s subtree
matches; at level B, the same deep highlight now sits under `x_c` (path
`.x_b.x_c.x_d.…`), whose immediate child component at B is `x_c`, so `x_c` is flagged;
and so on up the chain — with no explicit recursion, purely by prefix matching against
the *current* path.

Cost: O(number of live highlight entries) per recompute, plus O(instances) assignment.
Highlight tables are small in practice; this is negligible next to the netlist-struct
preparation `propagate_hilights()` already does.

## 5. Visual representation

- A rectangle around the instance's symbol bounding box (`inst[i].xx1, yy1, xx2, yy2`
  — the bbox *without* text, so it hugs the symbol body), drawn during the highlight
  draw pass (`draw_hilight_net()` in `hilight.c`) so it layers above the symbol and
  shares the highlight GC / cairo source setup.
- Rendered with the buried net's style via `get_hilight_style(inst[i].buried_hilight)`:
  the rectangle uses that style's **color, line width, and dash pattern**.
- The user originally likened this to "the rectangle used to mark the instance whose
  properties are being edited." Note: **no such rectangle exists in the code today**
  (`xctx->edit_sym_i` is tracked but nothing draws a box). So this feature *introduces*
  the styled-box idiom rather than reusing one.
- Distinct from selection (dashed `SELLAYER` box) and hover (separate GC) overlays —
  it carries the highlight color, so it reads as "highlight," not "selected."

## 6. Animation

The cue participates in the same animation machinery as net highlights (Pass 2 of
[[net_hilight_styles]]):

- **Blink** — gated by `net_hilight_style_on_now(st, now)`: the rectangle is drawn only
  on "on" frames, in phase with the net it mirrors.
- **March** — the rectangle's dash phase uses `net_hilight_march_offset(st, now)`, so
  the dashes crawl around the box in sync with the buried wire.
- Drawing inside `draw_hilight_net()` lets the cue ride the existing per-window
  animation tick (`net_hilight_anim_update()`, multi-window borrow); no new timer.
  **But the tick's scanner had to be taught about the cue**: `scan_animating_hilights()`
  (the shared "does this window animate? + which region to redraw?" walk) originally only
  saw highlighted wires and pin-colored instances. A buried cue has *no* visible wire at
  this level (the animated net is down in a child), so without a dedicated pass the window
  reported "nothing animating", the tick never armed, and the rectangle stayed static. A
  third loop now folds each `inst[i].buried_hilight` whose style animates into the
  predicate / signature / redraw bbox. Unlike a pin-colored symbol (blink-only, since a
  symbol is colored not stroked), the cue is drawn as wire edges, so it admits **both blink
  and march** (`net_hilight_style_animates`). The redraw bbox uses the outset cue rectangle
  (shared `BURIED_CUE_OUTSET_PX`). On ordinary/hardcopy draws the offset is 0 and blink is
  forced on, keeping exports deterministic — same contract as net highlights.

## 7. Clearing semantics

Because `buried_hilight` is **derived state** recomputed from the live highlight table
on every `propagate_hilights()`:

- `xschem unhilight_all` → `clear_all_hilights()` empties the table; the next recompute
  sets every `buried_hilight = -1`. Cue gone everywhere. (Add an explicit reset in
  `clear_all_hilights()` too, so a no-instance-loop clear path can't leave a stale cue.)
- Descending to the buried net and unhighlighting it removes its table entry; recompute
  drops the cue.
- No per-instance "unhighlight this buried cue" command in v1 (would require resolving
  *which* deep net to drop — out of scope; see §10).

## 8. Edge cases, design decisions & open holes

These are the holes in the original one-paragraph spec, with the v1 resolution:

1. **What counts as "internal"?** A net not connected to any of the instance's pins.
   Operationally: an instance already colored by pin propagation
   (`inst[i].color >= 0`) is *not* given a buried cue, because the highlight is already
   visible there. **Limitation:** if an instance has *both* a pin-reaching highlight
   *and* a different buried net, v1 shows only the pin color, not the buried cue.
   Documented; revisit if it bites.

2. **Multiple buried nets / multiple styles in one instance.** v1 draws **one**
   rectangle, styled with the **most-recently-applied** buried net's style (per the
   user's rule: the latest highlight lends its style to the cue). Implemented via a
   monotonic apply-sequence stamp (`Hilight_hashentry.seq`); the buried net with the
   highest seq under the instance wins. *Future:* nested/inset rectangles, one per
   distinct style.

3. **Animate the cue or draw it steady?** v1 **mirrors the net's style fully**,
   including blink and march, for visual consistency. (Cheap, since it rides the
   existing tick.)

4. **Vector / bussed instances.** The hierarchy path component for a vector instance
   is an *expanded* name (e.g. `x_d[1]`), while `inst[i].instname` is the unexpanded
   `x_d[1:0]`. v1 matches the path component against the instance's base name (text
   before `[`); a buried net inside one slice of a vector instance flags the whole
   vector instance. Documented approximation; exact per-slice cues are future work.

5. **Performance under animation.** Detection runs only on highlight *change* /
   traversal (inside `propagate_hilights`), **never** per animation frame. The
   per-frame path only *reads* `inst[i].buried_hilight`. No regression to the 30fps
   tick.

6. **Multi-window / tabs.** `buried_hilight` is per-instance and therefore per-context;
   each window/tab computes its own from its own `currsch`/path. The existing
   multi-window animation borrow redraws each. No special handling.

7. **`edit_sym_i` rectangle reference.** As noted in §5, it does not exist; we are
   creating the idiom. (If a future "mark the instance being edited" box is added, it
   should use a *different* color/GC so the two cues don't read as the same thing.)

8. **Read-only / hidden / ignored instances.** Cue still applies (it is informational,
   not an edit). Hidden instances (`HIDE_INST`) already draw only their bbox; the cue
   around that bbox is fine.

## 9. Introspection / test seam

Drawing cannot be asserted headlessly, so the *detection* is exposed for tests:

- `xschem hilight_buried <instname>` → returns the instance's `buried_hilight` style
  index, or `-1` if none. (Read-only query; lives beside the other `hilight_*`
  subcommands in `scheduler.c`.)
- Optional `xschem hilight_buried_list` → list of `{instname styleindex}` for all
  flagged instances at the current level (convenience for tests / scripting).

These let the regression test descend, highlight a buried net, ascend, and assert the
ancestor instance reports the right style — and that `unhilight_all` clears it.

## 10. Out of scope (v1)

- Per-net removal of a buried cue from above (only `unhilight_all`, by design).
- Nested per-style rectangles for instances with multiple distinct buried styles.
- Exact per-slice cues on vector/bussed instances.
- A separate "instance being edited" rectangle (`edit_sym_i`) — unrelated, may reuse
  the same drawing helper later with a different style.

## 11. Acceptance criteria

Verified by `tests/buried_hilight.tcl` (headless, 7 checks) unless noted.

1. ✅ Descend A→B→C→D, highlight a net internal to D (no pin connection), ascend to C:
   `xschem hilight_buried x_d` returns the highlight's style index.
2. ✅ Ascend to B: `xschem hilight_buried x_c` returns the same style index.
3. ✅ Ascend to A: `xschem hilight_buried x_b` returns the same style index.
4. ✅ A net that *does* reach a pin colors the instance (existing behavior) and does
   **not** additionally produce a redundant buried cue at that level. (Discriminating
   test — both nets create a deep entry under x_d; only the non-pin one yields a cue.)
5. ✅ `xschem unhilight_all` → all `hilight_buried` queries return `-1`.
6. ✅ GUI (PNG export): the cue renders as a styled rectangle surrounding the ancestor
   instance in the buried net's color/width/dash — verified at level C (style 3) and at
   the top level A with the net 3 levels deep (style 1). **Animation verified**: with a
   blinking style, `xschem get net_hilight_animated` → 1 at the ancestor level, and
   sampling the forced clock (`net_hilight_test_now`) shows the cue present in the ON
   phase and absent in the OFF phase. March rides the same wire path + redraw signature.
7. ◻ No regression in the existing suites: the buried test + real-design smoke (49-inst
   design, full highlight table, descend/ascend/clear) pass with no crash. The library
   golden suites (`run_regression.tcl`) need an installed `xschem` + gold refs not present
   in this checkout (environmental). Detection runs only in `propagate_hilights()`, never
   per draw/animation frame.
