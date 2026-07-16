# 0091 — fluid reroute: a same-net follow-wire crosses the MOVED instance's own body

Status: FIXED (2026-07-08)
Branch: fluid-editing
Repro: `tests/from_user/before_5.sch` → `after_11.sch`
Trace: `FLUID_TRACE=/tmp/fltrace_7_8_7.log` (the user's session)
Test: `tests/headless/wireedit/test_wireedit_48_body_cross_0091.tcl` (RED-first)
Related: [0088](0088-fluid-reroute-redundant-samenet-loop.md) / [0089](0089-fluid-reroute-redundant-samenet-detour.md) /
[0090](0090-fluid-reroute-redundant-samenet-staircase.md) (the same END same-net cleanup family this
extends). This closes the topic memory's deferred "per-component (vs wholesale) decline" item.

## Symptom

Select **C12** (capa), **R18** (res) and the **#net2 wire connecting them**, then drag the group around
(the user reached the final spot in several gestures; a single-gesture `(-20,+60)` reproduces it
byte-for-byte). Saved as `after_11.sch`. The riser meeting **R18's M pin** (net `#net1`) is routed so the
fixed `#net1` backbone runs **straight through R18's body**, even though there is open space to avoid it:

```
after_11.sch  #net1 near R18 (R18 @ (-280,10), body x in [-287.5,-272.5], y in [-10,30]):
  (-400,-10)---(-260,-10)   <-- backbone at y=-10 crosses R18's body top (x=-280 is inside)
  (-260,-10)-(-260,50)-(-280,50)-(-280,40)=M   <-- M riser wraps R18's right+bottom

ideal (produced when only the instances are selected):
  (-400,140)-(-400,50)-(-280,50)-(-280,40)=M   <-- M exits down, runs left UNDER R18, up the far-left column
```

No short, no disconnect — purely a P5 (body-cross) legibility defect. The M riser's right-side wrap is a
*correct* body dodge (M's escape normal is down; joining the backbone on the right at (-260,-10) clears the
body). The crossing is the **stationary backbone** continuing left from that join across R18.

## Root cause — the redundant-route cleanup was wholesale-gated off by ANY wire selection

The single-gesture equivalent move produces the **identical** crossing, so this is not a multi-gesture
artifact (unlike 0090). The clean route *is* reachable: with **only the instances** selected the END
straighten pass (0089/0090) reshapes `#net1` to the clean under-and-left route. But the pass — and the
0088 loop-remover — are gated on `xctx->fluid_startsel_wires == 0`:

```c
if(!commit_now && fluid_editing && stretch_select && rot==0 && flip==0 &&
   leg_ortho && leg == nlegs-1 && xctx->fluid_startsel_wires == 0) {   /* <-- wholesale */
  fluid_remove_redundant_loops();
  fluid_straighten_reversals();
}
```

`fluid_startsel_wires` counts the wires the **user** selected at drag START. The user selected the `#net2`
connecting wire, so the count is 3 and the whole cleanup is skipped — **for every net**, including `#net1`,
which the user never selected. Proof the gate is the sole cause: selecting a completely **unrelated** wire
(the far-away `OUT` wire at y=140) *also* leaves `#net1` crossing R18. The "selection wins" policy was
implemented as *wholesale* decline instead of *per-net*.

## Fix — per-component decline (`fluid_mark_user_protected`)

Drop the `== 0` from the gate so the cleanup runs whenever a fluid stretch could have made redundant
copper, and make both passes decline **per touch-component** instead of wholesale:

- `select_attached_nets()` (select.c) snapshots the **session-stable ids** (`xWire.id`) of exactly the
  wires the user selected at START (before the follow-grab), into `xctx->fluid_startsel_id[]`. Ids survive
  the move (an in-place SELECTED translate keeps the struct) and never alias, so they identify the user's
  wires even after the follow reroute renumbered every `#net`. Gated on `fluid_editing`, freed with the
  move (mirrors `stretch_grabbed_xy`'s lifecycle exactly).
- `fluid_mark_user_protected(prot)` (move.c) flood-fills `prot[]` over the touch-component of every
  user-selected wire (`fluid_wire_reach_set`). `fluid_remove_redundant_loops` never dooms a `prot[]` wire;
  `fluid_straighten_reversals` skips a jog/tail whose wire is `prot[]`. Distinct nets never share a
  touch-component (that would be a short), so protecting the user's net **never** blocks a foreign-net
  cleanup — the reported `#net1` (unselected) is cleaned; the user's `#net2` is left byte-intact.

So `#net1`'s M riser is reshaped to the clean under-and-left route (no body cross, ~40u shorter) while
`#net2` — the wire the user actually grabbed — is untouched. "Selection wins" is now honoured **per net**.

## Safety

Unchanged from 0088-0090: every reshape/delete is pin-partition VERIFIED (`fluid_loop_partition`, pure
`touch()`) against the pass-entry base and reverted on any change (subsumes no-short + no-disconnect); a
pin-less labeled net a partition can't see is guarded by `fluid_slide_merges_foreign`; a staircase leg is
body-cross-guarded; the jog must be NOVEL (`fluid_wire_is_novel_span`) so a user's deliberate routing is
never rewritten. The new `prot[]` guard is strictly ADDITIVE (declines more, never more), so it cannot
introduce a short or disconnect. Caller-gated on `fluid_editing` (default off ⇒ never runs ⇒ byte-identical;
verified: HEAD reference vs fixed produce identical geometry on the repro with `fluid_editing=0`).

`prot[]` is recomputed each straighten iteration (indices renumber after a trim) and once per loop-remover
entry (its greedy phase only masks, leaving geometry — hence indices — stable until the final delete).

## Verification

- `test_wireedit_48_body_cross_0091` (21 checks): the repro (P5 no body-cross + crossing backbone gone +
  exact clean-L geometry + P1/P2/P4), an instances-only no-regression, a **protection** case (user also
  selects a `#net1` wire ⇒ cleanup declines `#net1` but P1/P2/P4 still hold), and a non-crossing no-op.
  RED-first: the P5 / crossing / clean-geometry checks FAIL on HEAD `f66aec00`.
- Full `run_wireedit.sh`: ALL PASS (47 prior + 48). `--memcheck`: clean.
- `fluid_editing=0`: byte-identical (HEAD-reference segset diff on the repro).

## Adversarial review finding (wf_bbb1dcb1) — a heap OOB in the first cut, FIXED

The first cut sized `prot[]` **once** to the pass-entry wire count and re-flooded it to the CURRENT
`xctx->wires` every straighten iteration, on the (wrong) assumption that the pass "only ever removes/merges
wires". But `trim_wires` (run after a kept slide) has a **break phase** (`check.c` → `wire_store_split`)
that SPLITS a wire and **grows** `xctx->wires` when a slid endpoint lands mid-span on same-net copper — so
the count is not monotone. On such an iteration the next `fluid_mark_user_protected` memset/flood and the
`prot[kd]` reads run one-or-more bytes past the buffer (heap OOB write+read). Three independent review
lenses converged on it; the other two findings were refuted (the id-lifecycle, gate-relaxation,
connectivity, and determinism all held — the partition-verify remains the connectivity backstop).

Fix: `prot` starts NULL and is `my_realloc`'d to the current `xctx->wires` at the top of each iteration,
before the flood (mirrors how `trim_wires` reallocs its own `wireflag`). `fluid_remove_redundant_loops`
needs no change — its single mark precedes a delete-only compaction with no intervening `trim_wires`, so
its wire count is genuinely fixed across every `prot[]` read.

## Deferred / out of scope

- When the user *does* select a wire on the crossing net (case P), the net is protected and can keep a
  small redundant tail — "selection wins", conservative and connectivity-safe, but not cleaned. A future
  wire-origin tag (tool-emitted vs user-drawn) could reshape tool-created legs on a user-selected net while
  still preserving the user's own segments.
- Genuinely no-clean-L ortho-quality routing (the deferred 0089/0090 diagonal-relay tail) is unchanged.
