# 0227 — a net label tapping a wire's span interior is stranded when the wire translates; the net silently reverts to `#netN`

Status: **CLOSED 2026-08-06 — superseded and fixed by `doc/claude/specs/wire_label_ride.md` S3
(R3 = RIDE).** Not implemented as filed: the fix drafted below extends `connect_by_kissing()` to
*rescue* the stranded label with another stub, and the spec deletes the stub instead and replaces it
with a per-gesture rider set. The escalation notice below is therefore **lifted** — it stood for
exactly one day.

> ### ✅ FIXED 2026-08-06 by S3. Measured on this issue's own repro
>
> `label_ride_capture()` (`src/move.c`) now registers a rider for a STATIONARY net label whose copper
> the gesture is about to move, and `label_ride_apply_ride()` carries it at move END and on every
> live drag step — position **and** orientation, so rotating or flipping the wire rotates and flips
> the label's text with it (R3, the Cadence behaviour). It is behind `label_ride` (default 1) and is
> **not** gated on `connect_by_kissing`, so the keyboard stretch paths get it too.
>
> Wire count is after the gesture; the label rides in every row and the net survives in every row.
>
> | config | wires | `fluid_last_move_label_strands` | resolved net |
> |---|---|---|---|
> | `autotrim_wires 0` (stock default) | 1 | **0** | `VOUT` |
> | `autotrim_wires 1`, `label_splits_wires 0` | 1 | **0** | `VOUT` |
> | `autotrim_wires 1`, `label_splits_wires 1` | 1 | **0** | `VOUT` |
> | `label_ride 0`, stock or `label_splits_wires 0` | 1 | **1** | `#net1` |
> | `label_ride 0`, `label_splits_wires 1` (the old accident) | 3 | 0 | `VOUT` |
>
> The last two rows are the pre-S3 world: the loss, and the split-plus-tether accident that used to
> hide it from `cadence_compat` users at the cost of two extra wire records.
>
> The same commit removes `connect_by_kissing()`'s wire-endpoint TETHER for net labels (spec change
> #8) — the two are a matched pair behind the one preference, because the tether was the only thing
> holding an END-OF-STUB label and removing it alone would have widened the loss rather than closed
> it.
>
> Regressions: `tests/headless/test_label_ride.tcl` sections **V** and **U** (89 → 157 checks),
> `tests/headless/test_label_strand_oracle.tcl` **A/AL, C/CL, D1–D2b/DL, DM1–DM4, D3–D4/D3L–D4L**
> (19 → 32), `tests/headless/test_wire_split.tcl` **W7b2** (115 → 119). Every re-authored case kept a
> `label_ride 0` legacy leg, so the pre-fix numbers below are still executed on every run.
> Spec: `wire_label_ride.md` **§7 S3** and **§16**; `WIRING.md` §9 "P1 label ride", landmine 16.

> ### ⚠ ESCALATED 2026-08-06 by S2, LIFTED the same day by S3 (kept for the record)
>
> Until today, `autotrim_wires` (which `cadence_compat` force-enables) **masked** this issue — see
> "Instrumented" below, and `wire_label_ride.md` §13.5 row 2. The mask was never a feature: the
> split put the mid-span label on a wire ENDPOINT, and *two* separate rescues fire only on endpoint
> coincidence — `connect_by_kissing()`'s wire-endpoint tether (`actions.c`, spec change #8, still
> alive; it goes with S3) and `select_attached_nets()`' `endpoint_near` ELEMENT arm (`select.c`).
>
> **S2 (`wire_label_ride.md` R2, landed 2026-08-06) removes the split, so it removes both rescues.**
> Measured, this issue's own repro (label stationary, wire translates, kissing armed):
>
> | config | wires | `fluid_last_move_label_strands` | resolved net |
> |---|---|---|---|
> | `autotrim_wires 0` (stock default) | 1 | **1** | `#net1` |
> | `autotrim_wires 1`, `label_splits_wires 1` (pre-S2) | 3 | **0** | `VOUT` |
> | `autotrim_wires 1`, `label_splits_wires 0` (**S2**) | 1 | **1** | `#net1` |
>
> So the blast radius of this issue **grew** from "stock-config users" to "everyone", and it grew
> for the person who filed it. It is not a new defect — the cadence user was accidentally
> protected, not correctly served — but the practical effect is a regression until **S3/RIDE**
> lands. That makes S3 the other half of S2, not merely the next stage.
>
> **Mitigation available now:** `set label_splits_wires 1` restores the pre-S2 mask exactly
> (verified: `tests/headless/test_label_strand_oracle.tcl` DM0–DM2). Consider defaulting it to 1
> until S3 ships, and flipping it with S3.
>
> Regression witnesses for the unmasked state: `test_label_strand_oracle.tcl` **D0–D2**,
> `test_wire_split.tcl` **W7b/S2** (the same mask removal on the `stretch`-without-`kissing` path,
> which is issue **0228**'s cell). Spec: `wire_label_ride.md` **§15.3**, §9 loss 5.

**S1 landed 2026-08-05 — the rescue stub is now GONE, and the half of the fix that exists is the
LEASH, not the ride.** `connect_by_kissing()`'s ELEMENT arm skips `type=label` instances
(`inst_is_netlabel()`), and a MOVING label whose anchor lands off copper is projected back onto its
owner span at move END. That covers the *label-dragged* direction of this issue's contact-matrix
cell. ~~**This issue's own repro — the label is stationary and the WIRE translates — is untouched and
still scores `fluid_last_move_label_strands = 1`;** it needs RIDE (S3), which is where change #8
(the wire-endpoint arm's tether) is finally removed too. Do not remove #8 before then.~~
**S3 landed 2026-08-06 and did exactly that** — see the FIXED box at the top.

**Instrumented 2026-08-05 (spec S0).** The defect is now *audible*: the move END publishes
`fluid_last_move_label_strands` (`fluid_count_label_strands()`, `src/move.c`) — labels that sat on
copper at gesture START and touch none at END. The repro below scores 1.
Regression: `tests/headless/test_label_strand_oracle.tcl`. That test also pins two facts this
issue only asserted in prose: `cadence_compat`/`autotrim_wires` really does mask the loss (case
D1 — the split puts the label on an endpoint and kissing tethers it), and the mask fails on the
keyboard stretch paths that never arm kissing (case D3, issue **0228**).

Original status: measured repro on stock defaults, fix drafted, not implemented.
Area: `src/actions.c` `connect_by_kissing()` (`:2042`, endpoint sweep at `:2110-2121`)
Tests: none yet — proposed `tests/headless/wireedit/test_wireedit_NN_midspan_label_0227.tcl`
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0228** — the sibling hole on the keyboard stretch paths (do both). **0117** (diagonal fluid drag of a net label leaves a selection ghost — a redraw defect, not this), **0162** (fluid label guards drop a user `#` label). `doc/claude/WIRING.md` open risks 5 (`:477-480`) and 6 (`:481-483`) are adjacent but do **not** cover this cell.

> This touches the fluid engine. Per `MEMORY.md` another agent owns that area — cite issue
> numbers rather than quoting current `move.c` text, and read `doc/claude/WIRING.md` §7
> landmines before implementing.

## The defect

`connect_by_kissing()` rescues connectivity by dropping a zero-length `SELECTED1` stub
wherever a **moving wire's endpoint** coincides with a stationary instance pin. Its wire
arm samples only the two endpoints, never the span interior:

```c
src/actions.c:2110-2121
  /* add wires to moving wire endpoints */
  for(j=0; j < k; ++j) if(xctx->sel_array[j].type == WIRE) {
    int wire = xctx->sel_array[j].n;
    if(xctx->wire[wire].sel != SELECTED) continue; /* skip partially selected wires */
    for(i=0;i<2; ++i) {
      if(i == 0) {
        x0 = xctx->wire[wire].x1;
        y0 = xctx->wire[wire].y1;
      } else {
        x0 = xctx->wire[wire].x2;
        y0 = xctx->wire[wire].y2;
      }
```

A `lab_pin` tapping the **middle** of a wire is therefore never kissed. The wire
translates away, the label is left behind, and since the label is the sole carrier of the
net's name, the net silently becomes `#netN`.

`cadence_compat` masks this — that mode force-enables `autotrim_wires`
(`src/xschem.tcl:16260-16263`), which splits the wire at the label pin so the label ends
up on an endpoint. With the stock default `autotrim_wires 0` (`src/xschem.tcl:15733`)
there is no split and the loss is real.

## Measured — stock defaults

`cadence_compat 0`, `autotrim_wires 0`, `enable_stretch 0`, `fluid_editing 1`,
`intuitive_interface 1`.

1. Draw one wire from (0,0) to (200,0).
2. Drop a net label `lab_pin.sym lab=VOUT` at (100,0) — tapping the middle of the span.
   The wire resolves to `VOUT`.
3. Ctrl + left-drag the wire **body** down by 100 — the connectivity-preserving stretch
   drag (`stretch = 1 ^ enable_stretch(0)`, `src/callback.c:8014`, which *does* arm
   `connect_by_kissing`).

Result: the wire is (0,100)-(200,100) with `lab=#net1`. The label sits alone at (100,0).
No stub, no warning, `fluid_last_move_disconnects` = 0.

```
xschem wire 0 0 200 0
xschem instance {lab_pin.sym} 100 0 0 0 {name=l1 lab=VOUT}
xschem unselect_all; xschem select wire 0
xschem move_objects 0 100 stretch kissing
xschem resolved_net 0; xschem getprop wire 0 lab      ;# -> #net1   (was VOUT)
```

**Control, proving it is the span interior and not labels in general:** move the label to
(0,0) — an endpoint — and repeat. Result: 2 wires, both `lab=VOUT`; the kissing stub
(0,0)-(0,100) preserved the name.

Downstream: the SPICE/Spectre netlist silently switches that node from `VOUT` to an auto
`#net<N>`, so any `.measure`, probe, subcircuit port reference or LVS run against `VOUT`
breaks with no on-screen indication.

## Corrections to the first reading — do not repeat these

- **`src/move.c:6246-6271` is not a "label re-inclusion pass".** It is block (3b) inside
  `fluid_ml_hazards()` (`:6161`), the P2 hazard scorer that ranks the two candidate L-elbow
  orientations in `place_moved_wire`. It only ORs `FLUID_MLH_FPIN`/`FLUID_MLH_STRAY` so the
  elbow prefers the other orientation, it explicitly skips *selected* instances
  (`if(xctx->inst[i].sel) continue; /* only STATIONARY labels */`), it detects a **merge**
  (label over foreign copper) rather than a stranding, and it never runs on a rigid
  whole-wire translation (it is the partial-selection elbow chooser, `WIRING.md:265`).
- **`select_attached_nets()` is `src/select.c:1738-1853`**, not `:1579-1689` (that range is
  `select_line` / `select_object` / `endpoint_near`). It adds only wires — see the fix
  section for why that must stay true.
- **There is an END label pass**, `fluid_count_label_shorts()` (`src/move.c:7997-8018`) —
  but it only counts a label touching a wire of the *wrong* net. A label touching
  **nothing** falls out of its `for(w…)` loop and is invisible. The P1 partition
  (`fluid_build_partition`, `move.c:2625`) does include label pins, but it is name-derived,
  so a stranded label keeps its own `lab=` and its id is unchanged — and P1 disconnects are
  log-only anyway (`WIRING.md` §9: "P1 disconnect: still **log-only** … NOT part of the
  refuse signal").

Per `WIRING.md:8` root-cause class B ("trigger-bound detection … the contact matrix was
never enumerated"), the missing cell is **{pin-on-span, stationary, rigid-translation}**.

## Fix

Turn the endpoint sweep into a span sweep. In `connect_by_kissing()`, insert a third pass
before `str_hash_free(&coord_table);` (`src/actions.c:2166`):

```c
  /* A stationary pin fed STRICTLY INSIDE a moving wire's span is stranded when the wire
   * translates: the endpoint sweep above never sees it. A net label is the damaging case
   * (it is the sole carrier of the net's name), so drop the same rescue stub there.
   * See doc/claude/issues/0227-*.md */
  for(j = 0; j < k; ++j) if(xctx->sel_array[j].type == WIRE) {
    int wire = xctx->sel_array[j].n;
    double wx1, wy1, wx2, wy2;
    if(xctx->wire[wire].sel != SELECTED) continue;
    /* hoist the coords: storeobject() below can realloc xctx->wire (WIRING.md 7.3) */
    wx1 = xctx->wire[wire].x1; wy1 = xctx->wire[wire].y1;
    wx2 = xctx->wire[wire].x2; wy2 = xctx->wire[wire].y2;
    for(ii = 0; ii < xctx->instances; ++ii) {
      const char *type;
      if(xctx->inst[ii].ptr < 0 || xctx->inst[ii].sel) continue;
      type = xctx->sym[xctx->inst[ii].ptr].type;
      if(!type || strcmp(type, "label")) continue;           /* scope: net labels only */
      get_inst_pin_coord(ii, 0, &pinx0, &piny0);             /* a label has a single pin */
      if(!touch(wx1, wy1, wx2, wy2, pinx0, piny0)) continue;
      if((pinx0 == wx1 && piny0 == wy1) ||
         (pinx0 == wx2 && piny0 == wy2)) continue;           /* endpoint: already handled */
      if(!done_undo) { xctx->push_undo(); done_undo = 1; }
      my_snprintf(coord, S(coord), "%.16g %.16g", pinx0, piny0);
      if(str_hash_lookup(&coord_table, coord, "", XLOOKUP) == NULL) {
        str_hash_lookup(&coord_table, coord, "", XINSERT);
        storeobject(-1, pinx0, piny0, pinx0, piny0, WIRE, 0, SELECTED1, NULL);
        changed = 1;
        xctx->prep_hash_wires = 0;
        xctx->need_reb_sel_arr = 1;
      }
    }
  }
```

The `SELECTED1` zero-length stub translates its endpoint 1 with the drag, becoming the
(100,0)-(100,100) jumper — the identical mechanism to the endpoint case that already
works.

### Rejected alternative

Teaching `select_attached_nets()` to add the label **instance** to the follow set. It is
the intuitive fix and it breaks a documented invariant:

```
src/callback.c:5827
 * (ROTATELOCAL). A follow-set (select_attached_nets) only ever adds WIREs, so every selected
```

Issue 0114's rigid-group rotate/flip pivot logic relies on that to distinguish user objects
from tool-grabbed ones. A tool-grabbed label would be counted as a user object and change
the Alt+R / Alt+F group pivot.

## Risks

- **Goldens move.** Every wireedit/gesture golden with a label tapping a moved wire's
  interior gains a wire. Re-baseline `tests/headless/wireedit/` (52 tests) and the 16
  gesture tests before/after. `WIRING.md` §10 says CI cannot catch a fluid regression — run
  it by hand (`tests/headless/wireedit/run_wireedit.sh`), and press **Allow 30m** on the
  GUI-gate panel once rather than Proceed per suite.
- **END-pipeline survival.** The new stub is a fresh wire created before the fluid END
  pipeline. Verify it survives the healers rather than being eaten as a "novel orphan
  stub" — `fluid_wire_is_novel_span` (`move.c:2447`) and the novel-orphan-stub prune
  operate on exactly this shape. If the stub carries the label's explicit name it hits the
  `fluid_wire_explicit_lab` (`move.c:2471`) universal decline, which is protective here but
  is also `WIRING.md` open risk 1 (named-rail blackout) — check the stub does not turn a
  repairable move into a B3 REFUSE.
- **Undo slot.** `connect_by_kissing()` calls `xctx->push_undo()` on the first stub; the
  new pass must reuse the existing `done_undo` latch (it does above) or it burns a second
  slot.
- **Realloc landmine** (`WIRING.md` §7.3): `storeobject` can realloc `xctx->wire`, so the
  four wire coords are hoisted into locals above. Do not reintroduce an `xWire *` alias
  across the store.
- **Deliberate scope limit.** Restricting to `type=="label"` leaves the mid-span *device*
  pin equivalent unfixed. That is a real but separate cell of the same contact matrix;
  widening to all stationary pins is more correct and touches far more goldens. Decide
  explicitly — do not widen by accident.
- Other readers of these shapes: `unselect_partial_sel_wires()` (`actions.c:2171`) walks
  the same kissed-stub shapes, and `move.c:8231` deletes zero-length stubs
  `connect_by_kissing()` created when a move is aborted. Both must still behave for the new
  mid-span stubs.
