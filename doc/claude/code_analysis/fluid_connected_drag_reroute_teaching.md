# Connected-drag wire rerouting — how it works, and why it's a hairball

**Audience:** anyone about to touch `src/move.c`'s fluid wiring, or trying to understand why the
0088–0139 issue series keeps recurring. Read this alongside `doc/claude/WIRING.md` (the reference: data
model, pass catalog, invariant contract) — this document is the *plain-English mental model* behind that
reference, plus an honest account of the structural reasons the code is fragile.

---

## 1. What connected drag has to do

You select some objects (usually one or more instances, maybe some wires) and drag them. The selection's
own shapes translate rigidly — that part is trivial. The hard part is the **wires that straddle the
boundary**: one endpoint sits on the moving selection, the other on something that stays put.

A fixed far end — a **destination** — is one of:

- an **instance pin** (a `PINLAYER` rectangle on a symbol, e.g. a device terminal or an ipin/opin), or
- a **wire junction**: a T where a third segment taps a run mid-span, or an explicit solder dot.

Destinations do not move. So each straddling wire is a **rubber band**: the near end follows the
selection, the far end is nailed down, and the wire's *shape* between them must be recomputed on the fly.

The only hard rules are:

1. **No shorts** — the reshaped copper must not newly connect two different nets.
2. **No body crossings** — no wire may pass through the drawn body of another instance, or through the
   body of the selection being dragged. (A pin's own short escape leg out of its body is exempt.)

Everything else (Manhattan-ness, minimum copper, not disturbing the user's own wires) is a *preference*,
ranked below those two rules. The formal priority (WIRING §9) is:

```
P1 connectivity = P2 no-short  >  P3 escape-perpendicular  >  P5 no-body-cross
  >  P4 Manhattan  >  P7 stability (don't reshape the user's copper)  >  P6 min-bends
```

---

## 2. The execution model: rebuild-from-scratch every step

The single most important thing to understand: **the router is stateless across mouse steps.** It does
*not* incrementally nudge the previous frame. On every live mouse-move (a "RUBBER" step) *and* again at
button-release (the "END" commit), it:

1. **Restores** the schematic to the exact pre-gesture geometry (`fluid_reroute_restore`).
2. **Re-derives the whole route from the TOTAL delta** — where the selection is now, relative to where it
   started.

Consequence, by construction: **release == stepwise.** The saved result depends only on the final delta,
not on the path your mouse took or how many frames fired. This is a deliberate, valuable property — but it
means every pass must be a pure function of `(pristine geometry, total delta)`, and any per-step state
leak is a bug (issues 0086, 0109 both patched "never leak past the gesture").

At arm time (`fluid_gesture_arm`) the engine snapshots the **START wire set** — every wire's
order-normalized endpoints plus its `lab=` — into `fluid_g.start_wire[]`. This snapshot is the baseline
for the single most overloaded concept in the whole system: **novelty** (§5 below). Note it is
**re-captured once per gesture**: in a multi-gesture drag, gesture 2's baseline is gesture 1's *result*,
not the original file (this subtlety is exactly what 0139 turned on).

### The core translate + the attempt ladder

For each straddling wire, `place_moved_wire` translates the moving end and re-draws a Manhattan **L**. The
L's orientation (horizontal-first vs vertical-first) comes from `recompute_orthogonal_manhattanline`
(basically `|dx|` vs `|dy|`), later possibly overridden by a per-pin "escape bias" (`fluid_p6_bias_ml`).

A **diagonal** drag is handled by an **attempt ladder** — try progressively less-ambitious decompositions
until one verifies clean:

- **attempt 0** — pure-ortho *leg split*: do the whole X move, then the whole Y move, as two ortho legs.
- **attempt 1** — a rigid single pass from the restored pristine.
- **attempt 2** — the *rigid diagonal relay*: allow a literal diagonal wire, then Manhattanize it
  afterward (`fluid_manhattanize_relay_diagonals`).

Whichever attempt first passes the connectivity check (`partition_changed == 0`) is **ACCEPTED**.

---

## 3. There is no global router — only a cascade of local patches

This is the architectural crux. Nowhere does the code solve the clean problem —
*"given these two fixed endpoints and these obstacle rectangles, compute a short Manhattan route that
crosses no body and shorts no net."* Instead, after the naive translate, a **cascade of ~20 narrow
"cleanup passes"** runs. Each pass:

- **recognizes one specific bad shape** ("a reversal S-bend", "an overshoot stub", "a backbone a body now
  sits on", "a trunk one jog off the pin", "copper that landed on a foreign net"), then
- **applies its one repair**, under a memory snapshot, and
- **verifies and reverts itself** if the repair changed connectivity.

Grouped by role, the END cascade (order matters — see the trace in any `xschem_fltrace_*.log`) is roughly:

| Role | Passes (function names in `move.c`) |
|------|-------------------------------------|
| Un-short | `fluid_ripup_foreign_pin_short`, `fluid_prune_shorting_anchor_tails` |
| Remove dead copper | `fluid_remove_redundant_loops`, `fluid_prune_anchor_tails`, `fluid_prune_novel_orphan_stub` |
| Straighten / compact | `fluid_straighten_reversals`, `fluid_collapse_axis_overshoot_stub` |
| Escape a pin cleanly | `insert_exit_stubs` (slide the pin's perpendicular leg out along its lead normal) |
| Un-cross a body | `fluid_shove_body_crossing_backbone` (pin-incident), `fluid_shove_jog_separated_trunk` (one jog off the pin), `fluid_reroute_body_crossing_feeds` / `fluid_delete_body_crossing_copper` (relay path only) |
| Manhattanize | `fluid_manhattanize_relay_diagonals` (relay path only) |
| Pin-driven shove | `fluid_shove_connected_wire` |

**Correctness is emergent** from *which* passes run, in *what order*, on *what geometry the earlier passes
produced.* That is the source of nearly every bug below.

---

## 4. The two connectivity oracles — and their blind spots

Passes "detect a change" and "verify a repair" using two checks. Both are **partial**, and their blind
spots are the recurring root cause of shorts and lost copper.

**Oracle A — pin partition** (`fluid_loop_partition` / `fluid_partition_changed`): group the instance
pins by touch-connectivity; a repair is safe iff the pin groups are unchanged. **Blind to:**

- a **single-pin net** — a net with only one device pin and a dangling/label tail. Dooming its sole feed
  wire moves no *pin* between groups, so a load-bearing wire reads as "redundant, delete-safe" (root of
  0134 defect A; part 2 of 0139).
- a **pin-less labeled net** — a `lab=` supply/net stub carrying no device pin at all is invisible to a
  pin-indexed partition (root of the 0094 foreign-backbone short).

**Oracle B — foreign weld / reach** (`fluid_seg_welds_foreign`, `fluid_wire_reach_set`): does the reshaped
segment newly *touch* a wire of a different net? This backstops Oracle A's pin-less blind spot. **Blind
to:** a **4-way crossing** — two wires crossing mid-span with no shared endpoint. `touch()` only fires on
endpoint/T contact, so an X-crossing is (correctly) not treated as an electrical connection — but it means
"clears the neighbour" and "shares no endpoint with the neighbour" are different tests, and the passes
sometimes need the distinction (0136 defect 2, 0139's accepted near-miss).

**Enforcement is asymmetric** (WIRING §9): P2 (no-short) is now *refused* on commit
(`fluid_check_move_invariants`, hardening B3). But **P1 disconnect is only logged, not refused**, and
P3/P5/P6 are *produced procedurally by the healer ladder and never verified* — if a pass fails to fire,
nothing downstream catches the residual body-cross. That is why a "missed" pass ships a visible bug rather
than a refused edit.

---

## 5. Novelty — the ownership proxy that is load-bearing and two-sided

To respect P7 ("don't reshape the user's own wires"), passes must tell **tool-laid copper** (reshape
freely) from **user copper** (leave alone). The proxy for "who owns this wire" is
`fluid_wire_is_novel_span(w)`: is `w`'s endpoint span byte-identical to something in the START snapshot?
Present at start ⇒ pre-existing/user ⇒ protected. Absent ⇒ this-drag ⇒ fair game.

This geometry-hash stand-in for *ownership* misfires **in both directions**, and both directions have
shipped bugs:

- **Over-fire (laundering, WIRING §11 landmine 11):** trim splits/welds a wire the user never touched, so
  its span no longer matches START → it reads "novel" → a straightener reshapes the user's own detour
  (the 0088–0090 redundant-route family).
- **Under-fire (pin-tracked shrink, 0139):** a pre-existing trunk has one endpoint dragged inward because
  it's soldered to a moved pin's feed → its span shrinks → it reads "novel" → the pass that *should* shove
  it out of the body **skips it as if it were fresh tool copper** → the body-cross survives.

A byte-identical span is simply not the same thing as ownership. Every fix here is a *narrowing* bolted
onto the proxy: an id-watermark, a sub-span test, `fluid_wire_pretracked_shrink` (0139). The proxy itself
is never replaced.

---

## 6. Why the "hairball" shape *causes* the bugs

Six concrete, recurring structural failure modes — each maps to a cluster of issues:

1. **Pass-interaction / fix-the-fix.** A pass assumes the geometry the *previous* passes leave, but that
   contract is nowhere written. Widen one and another breaks: 0138 (open copper-reclaim to named nets)
   regressed 0136 (body-cross), whose fix then regressed 0137 (min-copper). Two of the three 0138 commit
   notes are "fix-the-fix landmines."
2. **Oracle blind spots (§4).** Single-pin / pin-less nets and 4-way crossings keep slipping through the
   verify, so a "verified safe" repair deletes a load-bearing wire or leaves a body-cross.
3. **Ownership proxy misfire (§5).** Novelty over- and under-fires; the P7/reshape decision rides on a
   geometry hash.
4. **Single-axis machinery reused for diagonal motion.** Diagonal drags are faked as x-then-y by
   *spoofing* one axis of the delta to axis-gated passes. The spoof mis-models any pin whose escape is on
   the *other* axis (0135 D1: a shove dragged REF's feed straight through the body).
5. **Phase / coordinate ambiguity.** "The pin position" and "the geometry" differ between a live RUBBER
   step and the END commit; body tests have used the text-inflated bbox vs the real drawn body (0138
   fix-the-fix); the novelty baseline is re-captured per gesture (0139). A pass written against one phase
   silently misbehaves in another. *(0139's whole difficulty was that the shove fired on the live step but
   not at END, because END's straighten had already parked the neighbour net on the target line.)*
6. **God-object + file-scope statics.** All state hangs off the global `xctx` plus file-scope `fluid_g.*`
   statics in the largest source file. Each pass's real preconditions live in that shared mutable state,
   implicit and undocumented. (The top structural-backlog item, WIRING R2, is literally "replace the
   file-scope statics with a lifecycle-scoped `Fluid_gesture` struct.")

None of these is a *logic typo*. They are all the same disease: **local heuristics standing in for a
router, coordinated only by order and shared state.**

---

## 7. How many issues are this, and the common theme

Of **137** tracked issues, roughly **45–50 (about a third)** are connected-drag rerouting — the numbered
runs 0079–0117 and 0130–0139, plus the named memories (`nice-drag-rerouting`, `wire-editing-on-move`,
`fluid-editing-tip-grab`, the whole 0098–0139 short/body-cross/reroute series). They **dominate the
`fluid-editing` branch's active work.** No other subsystem is close.

The common theme, in one sentence:

> **A moving pin's feed wire ends up crossing a body or shorting a neighbour because a stack of local
> heuristics — not a constraint solver — patches symptoms, and each patch rests on an implicit assumption
> (a connectivity oracle with a blind spot, an ownership proxy that misfires, a topology one pass covers
> but its neighbour doesn't, or a phase/axis fake) that the next fixture quietly violates.**

Everything from 0088 to 0139 is a variation on that theme.

---

## 8. Canonical worked example: issue 0139 (after_42)

One fixture that exhibits *four* of the six failure modes at once — the best single case to study.

- **Gesture:** two separate drags of one device (solar_ctl, rot1): `move_objects 0 20`, then
  `move_objects -10 -40`.
- **Symptom:** the LED net's crossbar threads the device body.
- **Mode 5 (phase):** gesture 1 drags the crossbar to y=−130, harmless *then* (body top was −100);
  gesture 2 advances the body top to −140 *over* it.
- **Mode 3 (ownership):** the crossbar's right end tracks the LED column inward (x2 90→80), so it reads
  "novel" and the body-shove pass skips it.
- **Mode 2 (oracle):** the net has only the LED pin, so the pin-partition can't see the crossbar is
  load-bearing — it reads "redundant."
- **Mode 1 (pass interaction):** the one-grid shove target collides with the REF net, which the
  *straighten* pass parked there first — so a naive shove welds foreign and declines.

The fix needed **three** narrowings, not one: re-admit the pin-tracked shrink
(`fluid_wire_pretracked_shrink`), a wire-level cut-edge test for the single-pin case, and step the shove
target past the neighbour net. That a single body-cross required patching a novelty proxy, a connectivity
oracle, *and* a pass-ordering collision is the hairball in miniature.

---

## 9. What the durable fix looks like (not more passes)

The backlog (WIRING §12) names the real remedies. In priority order of leverage:

1. **One connectivity model** without the single-pin / pin-less blind spots (id-keyed union-find
   maintained through edits) — kills the Oracle-A class outright.
2. **Ownership as identity, not geometry** — session-stable wire ids already exist
   (`fluid_wire_is_user_selected` uses them); lean on *those* for P7 instead of the novelty span-hash.
3. **A real obstacle-aware Manhattan route** between the two fixed endpoints (bodies as obstacles, other
   nets as no-touch) — so the passes stop *standing in* for a router. This is the structural fix the whole
   0088–0139 series is asking for.
4. **Lifecycle-scoped gesture state** (R2) + **explicit pass contracts / ordering** (R4) + an
   **idempotence checker** (run the cascade twice ⇒ fixpoint; the 0111 oscillation oracle) — so pass
   interaction stops being invisible.

Until then: **every new fixture is a new narrowing.** Add it RED-first (a failing test before the fix),
verify the two over-fire guards still bind (wireedit_36 case j for the novelty gate, wireedit_45 U/T for
the bridge gate), and never widen a gate without the full `wireedit` (57/57) + `test_fluid_*` gesture
sweep — because widening is exactly how the fix-the-fix regressions happen.

---

## 10. Reading guide (where to look)

- **The reference:** `doc/claude/WIRING.md` — data model (§1), END pipeline (§2–4), the pass catalog
  (table), the invariant contract (§9), the landmines (§11), the backlog (§12).
- **The spec:** `doc/claude/specs/nice_drag_rerouting.md` — the P1–P8 contract this all descends from.
- **The code:** `src/move.c` — `fluid_gesture_arm`, `place_moved_wire`, the attempt ladder and END block
  (search `what=END`), the pass functions named in §3, the verify helpers `fluid_loop_partition` /
  `fluid_seg_welds_foreign` / `fluid_wire_reach_set`, the novelty proxy `fluid_wire_is_novel_span`, the
  commit gate `fluid_check_move_invariants`.
- **The issues:** `doc/claude/issues/00{88..139}-*.md` — each is one narrowing, and most carry a "root
  cause" section that names which of the six failure modes bit.
- **Tracing a real gesture:** run with `FLUID_TRACE=/tmp/foo.log` and drive a real-X gesture; every pass
  logs `ran/SKIP/DECLINE/SHOVED/REVERTED` with its reason. Reading that log top-to-bottom *is* the
  fastest way to see the cascade actually execute.
