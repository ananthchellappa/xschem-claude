# 0194 — Ctrl-G deselects the selected trace, and eleven siblings do the same

**Status:** FIXED (2026-08-01)
**Branch:** `fluid-editing`. Reported by the user against the ASE waveform
viewer.

> Select a trace, then press **CTRL-G** to toggle the grid in the Waveform
> Viewer. **The trace gets deselected.**

A second symptom was reported as seen ONCE and never reproduced ("haven't been
able to reproduce this one"); it is answered in §6.

---

## 1. WHAT WAS MEASURED

`wviewer::regenerate` does `xschem clear_drawing` and re-places every graph rect
purely from `wviewer::graph_props`, i.e. from the Tcl MODEL. The selection is
not in the model. It is a per-RECT pair of prop tokens —

```
hilight_wave=<n>     the head (lowest) selected NODE index, or -1
sel_waves="<n> <n>"  the whole set, ascending; emitted only when >= 2
```

— written straight into `prop_ptr` by `graph_sel_waves_set` / `_toggle`
(`src/draw.c:3047` / `:3093`) from the two click arms in `src/callback.c:1142`
and `:1164`, and read back into the model by exactly one proc,
`wviewer::capture_live_graph_state`. Nothing pushes it the way markers get
pushed: issue 0175 considered a C→Tcl hook and declined it, because losing view
state on an incidental resize is "a cosmetic annoyance, not data loss".

Nothing in `xctx` survives either. `clear_drawing` (`src/actions.c:1890`) frees
the rects; `xctx->graph_struct.hilight_wave` / `.sel_wave[]` are scratch that
`setup_graph_data` (`draw.c:3963-3980`) refills from the rect before every draw.
So after a regenerate that did not capture, the selection is **gone**, not
merely stale.

`wviewer::grid_toggle` ended:

```tcl
  wviewer::sync_grid_mirror $token
  wviewer::regenerate $token
  wviewer::log_action [list wviewer::grid_toggle $new $token]
```

No capture. Select a trace ⇒ C writes the tokens into the RECT. Ctrl-G ⇒
regenerate rebuilds the rects from a MODEL that never heard about it ⇒ the
selection is destroyed. Measured, with the fix stashed, on the suite written for
this issue:

```
FAIL: GS2 the multi-trace selection SURVIVED the grid toggle -> {- -} (exp {- {0 2}})
FAIL: GS2 both tokens survived, not just the head         -> {{} {}} (exp {0 {0 2}})
FAIL: GS10 a REAL Ctrl-G keeps the selection              -> {- -} (exp {- {0 2}})
```

### 1.1 The prediction — CONFIRMED, and it makes this a class

The session prompt predicted `wviewer::sharedx_toggle` had the identical shape
and would drop the selection too, unreported only because it is toggled less.
It does:

```
FAIL: GS4 the selection survived the Shared-X toggle -> {- -} (exp {- {0 2}})
```

The two other suspects in the prompt were audited and are **clean, for a reason
worth recording**: `wviewer::set_plot_mode` and `wviewer::cursor_toggle` never
call `regenerate` at all (the first writes a per-window mirror and a status bar,
the second drives the engine cursors and calls `xschem redraw`). Toggling the
plot mode or a cursor therefore cannot lose a selection. The defect is not "a
window option"; it is "a regenerate with nothing folded back first".

### 1.2 The full audit of the class

All 22 `wviewer::regenerate $token` call sites, before this issue:

| verdict | procs | why |
|---|---|---|
| **must capture** (12, all broken) | `configure_apply` `display_raw` `attach_raw` `add_trace` `add_graph` `plot_signals` `grid_toggle` `sharedx_toggle` `apply_range` `wheel_zoom` `pan_x` `axes_ok` | the strips on the canvas carry forward |
| already safe (7) | `move_strip` `move_trace` `move_traces` `move_trace_to_new_strip` `split_strip` `delete_empty_strips` `delete_items` | full capture already, before `push_undo` |
| **must not capture** (3) | `restore` `state_apply` `clear_all` | the model is replaced wholesale |

`configure_apply` is the widest exposure: it is a plain window **RESIZE**, and
both `capture_live_graph_state`'s own header and spec §15.5 already named that
path in prose while the code did not keep the rule. `wheel_zoom` and `pan_x`
hand-roll a per-strip RANGE read-back (their D7 freeze) and so looked covered —
they were not; ranges are not the selection.

---

## 2. THE FIX

**The rule, stated once so the next window option does not rediscover it:**

> A `regenerate` that is meant to carry forward the strips currently on the
> canvas must first fold the live C-written rect state back into the model. The
> only exemptions are the procs that REPLACE the model wholesale (`restore`,
> `state_apply`, `clear_all`) and `delete_all_markers`, which must not
> regenerate at all. "It is only a window option, not model content" is a valid
> reason to skip `push_undo` and NEVER a reason to skip the capture: the capture
> is about surviving `clear_drawing`, not about undo.

### 2.1 Why a bare capture would have been a second bug — `skip_ranges`

The one-line fix the symptom invites (`wviewer::capture_live_graph_state $token`
in `grid_toggle`) is wrong at eleven of the twelve sites. The RANGES do not obey
the absent-means-absent rule the other keys do, and folding them turns out to be
destructive in **two** independent ways:

1. **It pins auto.** `graph_props` ALWAYS emits a concrete `x1/x2/y1/y2`
   (substituting a placeholder for a model `{}`), and regenerate's autozoom
   overwrites them with the `fullx`/`fullyzoom` fit. So `xschem getprop rect 2
   $gi x1` is never empty and the pre-0194 capture stores whatever it finds.
   Capturing on every RESIZE would convert every `{}` axis — the model's way of
   saying "autozoom on each regenerate" — into a frozen number, for every strip
   including empty ones. A later Direct Plot into an auto strip would be drawn
   off-screen, and a re-run would be drawn in the outgoing run's window.
2. **It destroys per-strip X under Shared X** — this one was caught by
   adversarial review of the first version of this fix, which "only" refreshed
   an *already pinned* axis and therefore looked safe. `regenerate` writes graph
   0's x onto every other strip's RECT when `sharedx 1`, in a LOCAL copy, so the
   model keeps each strip's own window; that non-destructiveness is the entire
   point of Shared X. Reading a pinned x back off the rect copies graph 0's
   window into every strip's model, permanently and with no undo point, so
   un-sharing no longer reveals anything. Measured, with a control: turn Shared
   X on and straight back off, and strip 1's `[0,1u]` had become `[0,1m]`.

So `capture_live_graph_state` gained a third optional argument, `skip_ranges`
(default 0, so the seven content sites and `marker_changed` are byte-identical),
and a named wrapper:

```tcl
proc wviewer::capture_live_view_state {token} {
  return [wviewer::capture_live_graph_state $token 0 1]
}
```

At `skip_ranges 1` the fold does not touch `x1/x2/y1/y2` at all — not to pin,
not to refresh. Range lifetime is therefore exactly what it was before this
issue (spec §17.4: a C-written pan/zoom the model never saw is discarded by the
next regenerate). **0194 changes what happens to the SELECTION and nothing
else**, which is also the smallest change that fixes what was reported.

### 2.2 Placement, which is mechanical and easy to get silently wrong

At each of the twelve: after any `switch_ctx` guard, **before** any structural
mutation, and **before** the `$gs` / `$lay` read.

* the 1:1 guard (`xschem get graph_rects` == model length) fails **silently**
  (`return 0`), so a capture placed after an add/remove is a no-op that reads as
  installed. This is why `plot_signals` captures itself instead of relying on
  the capture now inside `add_trace`, which it calls in a loop after the strips
  have already grown;
* the capture writes through `set_graphs`, so a `lay`/`gs` read taken earlier is
  stale and writing it back would revert the fold. `grid_toggle` and
  `sharedx_toggle` both read `lay` and write it back — the capture has to
  precede that read.

### 2.3 What deliberately did NOT change

* **No `push_undo` anywhere new.** Window options stay outside the undo stack
  (spec `waveform_viewer_modes.md` §14). `GX8` and the pre-existing `GT23` both
  forbid it; Ctrl-G is still not undoable.
* **No C→Tcl selection push hook.** 0175 declined one and this does not revisit
  it: with the twelve sites folding, the only regenerates left that can drop a
  selection are the three that are destroying the plot anyway.
* **No new log line, no modify flag.** Selection remains view state.

---

## 3. THE LEGS

`tests/headless/test_wave_grid.tcl`, two new blocks — **168 checks with a
DISPLAY (was 80), 81 without (was 44)**.

**`GX*` — source-level, both arms.** The rule is about code SHAPE across twelve
procs, and no behavioural leg can see eleven of them at once: each `GX1` leg
asserts capture-BEFORE-regenerate (order, not presence — a capture after the
regenerate reads as installed and folds nothing), `GX2` pins the three
exemptions, `GX3` pins the seven pre-existing FULL captures, `GX4` asserts
12+7+3 accounts for every call site so a new one cannot be added unclassified,
and `GX5`-`GX7` pin the `skip_ranges` contract, including that it is mentioned
exactly twice in the capture body — a third mention would mean someone gated the
selection with it, which reads identically in a single-strip fixture.

**`GS*` — behavioural, DISPLAY arm.** Fixture: two strips, three traces each,
from a synthetic `xschem raw new` + `raw add` so the vectors validate.

The load-bearing fixture rule: **the selection is planted on the RECTS ONLY**
(`with_edit` + `setprop`, exactly what the C click arm writes), never through
the model, and `GS1` asserts `wviewer::model_sel` is empty before each gesture.
A model-side plant survives a regenerate whether or not the fix is present, so
it would be green-but-hollow by construction.

Probe placement, per the batch's universal discipline:

* every leg selects on **strip 1, not strip 0**, and on **node 2, not node 0** —
  `atoi("")` reads a destroyed token as node 0, so a strip-0/node-0 witness
  passes on the bug;
* every leg reads back **every strip** (`gs_sels`), so a selection wrongly
  surviving, or wrongly appearing, on the neighbour is visible;
* three witnesses, not one: the C-side accessor (`wviewer::selected_waves`), the
  raw token pair (`hilight_wave` + `sel_waves` separately, so a head-only fold
  cannot pass) and the MODEL (`wviewer::model_sel`);
* `GS2` also asserts the toggle really regenerated (`grid=0` reached both rects)
  so the leg cannot pass by the gesture doing nothing.

Coverage: Ctrl-G with a multi-trace selection (`GS2`), with a single selection on
a non-zero node (`GS3`), Shared X (`GS4`), wheel zoom and X pan (`GS5`), a resize
refit through `configure_apply` (`GS6`), `add_trace` (`GS7`), `add_graph`
(`GS8`), the auto-range regression guard (`GS9`), `apply_range` plus its refusal
path (`GS11`), `display_raw` and `plot_signals` (`GS12`), the Shared-X per-strip
range guard (`GS13`), symptom 2's resurrection (`GS14`, §6) and the REAL key via
the WSLg-robust `send_key` (`GS10`).

Every site gets its OWN rect-only plant. A chain of gestures after one plant is
inert past its first link — the first fold puts the selection in the model and
every later regenerate re-emits it from there — so `GS9`'s end-to-end chain is
labelled as exactly that, and `GS8` was re-planted after review found it
inheriting `GS7`'s fold.

**Against a stash of the fix: 40 legs red**, including every one of the above.

---

## 4. SABOTAGE TABLE

Each sabotage was applied to the shipped fix alone, the whole suite re-run under
a DISPLAY, then reverted.

| # | sabotage | result | reads |
|---|---|---|---|
| 1 | delete the capture from `grid_toggle` only | **9 FAILED / 153 passed** | kills `GX1 grid_toggle` + `GS2`, `GS3`, `GS9`-chain, `GS10` — and NOTHING else. `GS4`-`GS8`, `GS11`-`GS13` (the eleven siblings) stay green, so the legs are per-site rather than one global witness |
| 2 | capture, but discard the selection (ranges + markers only) | **18 FAILED / 144 passed** | kills every selection leg at all twelve sites; `GS9`'s auto-range guard, `GS13`'s Shared-X guard and all `GX*` stay green |
| 3 | capture the head (`hilight_wave`), never `sel_waves` | **16 FAILED / 146 passed** | kills only the MULTI-trace legs — witness `{- 0}` where `{- {0 2}}` was expected. `GS3`, the single-selection leg, stays GREEN: a single-selection fixture cannot tell the two stores apart, which is exactly why the multi-trace leg had to be written |
| 4 | wrapper asks for the FULL capture (`skip_ranges 0`) | **4 FAILED / 158 passed** | kills `GX5`, `GS9 every auto axis is STILL auto`, and both `GS13` Shared-X legs — i.e. it reproduces BOTH regressions §2.1 lists, including the one review caught |
| 5 | delete the capture from `ase_window.tcl`'s `auto_plot` | **1 FAILED / 161 passed** | kills `GX9` only. Stated rather than hidden: that site has no behavioural leg (it needs a completed simulation run), so it is pinned by source order alone |

---

## 5. FILES

```
src/wave_viewer.tcl                       capture_live_graph_state grows `skip_ranges`;
                                          new wrapper capture_live_view_state (the rule, in
                                          a comment block); the 12 call sites fold first;
                                          grid_toggle's header CORRECTED (it taught the bug)
src/ase_window.tcl                        auto_plot's no-plottable-rows branch folds before
                                          it clears the auto strip — the 13th site, in the
                                          other file, invisible to a wave_viewer-only audit
tests/headless/test_wave_grid.tcl         new GX* (source) + GS* (behavioural) blocks
tests/headless/probe_0194_symptom2.tcl    measurement rig for §6, not a suite
doc/claude/specs/waveform_viewer.md       Ctrl-G "not an undo point" bullet CORRECTED —
                                          it said "no push_undo, no capture"
doc/claude/specs/waveform_viewer_modes.md §15.5 the required capture, made true; §18.4
                                          corrected (wheel_zoom does capture now)
doc/claude/specs/graph_markers.md         §8's "only three sites capture / configure_apply
                                          is unguarded" rationale, updated — the push hook
                                          is still required, for a different reason
doc/claude/code_analysis/waveform_subsystem_reference.md   landmine 50
```

**Deliberately NOT touched:** `restore`, `state_apply`, `clear_all`,
`delete_all_markers`, the seven content gestures' FULL captures, the C side
(no new verb, no push hook), the undo stack, and range lifetime.

---

## 5b. EYEBALLED — PASS (2026-08-01)

User confirmed on screen, in the real mode (`src/xschem --script
src/cadence_style_rc --logdir /tmp`, ASE waveform window): selecting a trace and
pressing **CTRL-G** keeps the trace selected. Issue RESOLVED.

This is the part no check reaches — the suite asserts the tokens the renderer
reads (`hilight_wave`, `sel_waves`), never the pixels that come out (§8).

---

## 6. SYMPTOM 2 — the alternating bold: EXPLAINED, and it is the same root

> Plot signals A, B, C to three strips. Move **B from strip 2 to strip 1**. Press
> CTRL-G. The trace that was moved across strips (B) gets **bolded / unbolded
> with each CTRL-G** — it alternates.

Measured with `tests/headless/probe_0194_symptom2.tcl`, five starting states ×
four consecutive Ctrl-G presses, on the fix and on a stash of it.

**The mechanism.** A cross-strip move is one of the seven gestures that ALREADY
captured. So the moved trace is the one trace in the window whose selectedness
lives in the **model** — every other trace's lives only in its rect. Pre-fix,
that difference is exactly the difference between the two symptoms:

* a trace selected by a CLICK is in the rect only, so a non-capturing regenerate
  **destroys** it — symptom 1;
* the MOVED trace is in the model, so the same regenerate **resurrects** it.

Measured, pre-fix, with B moved across strips and then deselected by the user
(a click writes the rect, never the model):

```
  after move B 1->0      rect=1 - -     model=1 - -
  after the click        rect=- - -     model=1 - -     <- deselected
  after CTRL-G #1        rect=1 - -     model=1 - -     <- BOLD IS BACK
```

Deselect again, press Ctrl-G again, and it comes back again. That is the
reported alternation: the user unbolds B, Ctrl-G rebolds it, and only B, because
only B is in the model. The same probe shows the other half — with a DIFFERENT
trace clicked after the move, pre-fix Ctrl-G moves the bold back onto B
(`rect=- - 0` → `rect=1 - -`), i.e. "the moved trace gets bolded".

**Why it read as unreproducible.** It needs a cross-strip move AND a deselect
between the toggles. Press Ctrl-G repeatedly without touching anything and it is
stable in BOTH builds (probe cases A/B/C), which is what a bare "press Ctrl-G a
few times" attempt produces.

**Post-fix**, the same sequences are stable and the deselect sticks: the fold
makes the RECT authoritative before every regenerate, so the stale model entry
is corrected instead of re-applied. Pinned by leg `GS14`.

So symptom 2 is explained by this issue's root cause and closed by this issue's
fix. What is NOT claimed: that the user's original run went through exactly this
sequence — that was not observed, and the report says it was seen once. The
claim is that the mechanism exists, reproduces on demand pre-fix, produces
precisely "bolded/unbolded with each CTRL-G" for the moved trace only, and no
longer happens.

---

## 7. WHAT ADVERSARIAL REVIEW OF THE FIRST VERSION CHANGED

The first version of this fix was reviewed by three independent lenses
(placement, test-hollowness, doc-accuracy), each finding then handed to a
separate agent asked to REFUTE it. 14 survived. The ones that changed the work:

* **the Shared-X range clobber** (§2.1 item 2). The first version's capture
  refreshed an already-pinned axis; the verifier reproduced the loss with a
  control run and it became `skip_ranges` + `GS13` + sabotage 4.
* **the 13th site**, `ase_window.tcl`'s `auto_plot` — the audit had been scoped
  to `wave_viewer.tcl`, and `GX4`'s "every call site is classified" count was
  scoped the same way. Fixed at the source and pinned by `GX9`.
* **`grid_toggle`'s own header still taught the bug** ("no push_undo and no
  capture here"), five lines above the proc that now captures. The spec bullet
  had been corrected; the comment a maintainer actually reads had not.
* **two capture-before-validation placements** (`apply_range`, `axes_ok`): a
  refused call used to be a pure no-op and had started mutating the model and
  moving the xschem context. Both now validate first.
* **three hollow legs**: `GS8` inherited `GS7`'s fold (re-planted), `GX3`'s
  prefix match could not detect the conversion it existed to forbid (anchored),
  `GX2` went vacuously green if a proc was renamed (added a found-guard).
* **stale docs elsewhere**: `waveform_viewer_modes.md` §18.4 and
  `graph_markers.md` §8 both asserted things this fix falsified.

Two findings were accepted and NOT acted on, deliberately:

* `marker_changed` still takes the FULL capture, so a marker gesture still pins
  every auto axis in the window. That is pre-existing behaviour with its own
  undo-snapshot rationale, and changing it is a separate issue.
* five of the twelve sites (`display_raw`, `attach_raw`, `plot_signals`,
  `apply_range`, `axes_ok`) had no behavioural leg. Four now do (`GS11`,
  `GS12`); `attach_raw` still does not — see §8.

---

## 8. WHAT NO CHECK CAN SEE

* **`attach_raw`** needs a real `.raw` on disk, which needs a completed
  simulator run, so it is pinned by source order (`GX1`) alone.
* **`ase_window.tcl`'s `auto_plot`** likewise — sabotage 5 kills only its source
  leg.
* **The pixels.** That a trace still *looks* bold after Ctrl-G is asserted
  through the tokens the renderer reads (`hilight_wave`, `sel_waves`), never
  through what was drawn; `wave_is_hilighted` is shared with the pre-existing
  render path and is not re-verified here.
* **The user's real gesture sequence** for symptom 2, per §6.

