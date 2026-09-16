# M13 — why a DC sweep through an auto-bridged node does not propagate, and why no option fixes it

**Measured and read 2026-09-15 by the driver**, on both binaries, after Stage 16 closed. Debt **M13**
was *"the DC-sweep + auto-bridge failure has a reproducer and no root cause"*, and Stage 12 ships a
**permanent** caution — `dc` on a deck with event nodes is `caution`, never `ok` — with that debt behind
it. This file gives the root cause and the reason the caution stays.

## The reproducer, re-measured on both binaries

`evidence/xspice.md` §12.1's deck: a `d_nand` driven by two supplies, its output through a
`dac_bridge` to a 1 kΩ load, swept `dc vin2 0 3.3 0.3`. `v(out)` should fall once `in2` crosses the
gate's threshold.

| deck | apt 45.2 | the fork |
|---|---|---|
| **as written** — ngspice auto-bridges `in1`/`in2` | `v(out)` = **3.3 V at every step**, first to last | the same |
| `+ .options maxevtiter=100` | **unchanged** | unchanged |
| `+ .options maxopalter=100` | **unchanged** | unchanged |
| `+ maxevtiter=100 maxopalter=100 convstep=0` | **unchanged** | unchanged |
| **the ADC bridge written by hand, before the gate** (§12.2) | the sweep resolves — `v(out)` ends at **1.65 V** | the same |

rc 0 everywhere; nothing crashed. The 1.65 V ending is §12.2's own second artefact (a hysteretic
`adc_bridge` latching at UNKNOWN once the input enters the dead band), not a new finding.

## The root cause, read in ngspice's source

Three facts compose it:

1. **The hybrid table is netlist instance order.** `EVTinit` walks every instance and keeps the ones
   with an analog side: `for(i = 0, j = 0; i < num_insts; i++) if(inst_table[i]->inst_ptr->analog)
   hybrids[j++] = inst_table[i]->inst_ptr;` (`src/xspice/evt/evtinit.c:255-263`). The bridges *are*
   those hybrids.
2. **Each DC step evaluates that table once, in order.** `EVTcall_hybrids` is a single `for` loop over
   `ckt->evt->info.hybrids` calling `EVTload_with_event(..., MIF_STEP_PENDING)`
   (`src/xspice/evt/evtcall_hybrids.c:62-80`). There is no inner fixpoint loop.
3. **The DC sweep re-solves the event side only if something changed.** `dctrcurv.c` calls `NIiter`,
   then `EVTcall_hybrids`, and re-enters `EVTop` only `if ((converged != 0) || (ckt->evt->queue.output
   .num_changed != 0))` — and a DC sweep has **no time axis**, so none of the transient's machinery
   (breakpoints, timestep backup, `EVTaccept`) can carry a late value into a second pass.

And the fourth fact, from `evtcheck_nodes.c`: **auto-generated bridge cards are appended at the end of
the deck**. So the automatic `adc_bridge` is the *last* hybrid in the table: on every step the gate is
evaluated before the bridge that feeds it, sees the previous step's digital input, and the sweep never
moves. Written by hand ahead of the gate, the same bridge is the *first* hybrid, and one pass suffices.

## Why the caution stays, and what the remedy is not

* **No ngspice option reaches it.** `maxevtiter` and `maxopalter` bound iteration *within* the event
  solver and the operating-point alternation; the defect is an **ordering** one inside a single pass, so
  raising either changes nothing — measured above, on both binaries. There is no setting ASE-L could
  emit as a fix, which is exactly the shape a caution must keep saying.
* **The remedy is the netlist's order**, and ASE-L does not write the user's netlist: the bridge must be
  instantiated ahead of the device that consumes its output. That is §12.2's finding, now explained.
* **So Stage 12's `dc` caution is correct as it stands** — *"a DC sweep does not always reach digital
  nodes through the bridges the simulator inserts on its own"*, with the fix *"write the bridge devices
  into the netlist yourself, ahead of the digital devices"* (R9-558/559). The measurement vindicates the
  wording: the sentence names the auto-bridging, and the fix names the ordering.

## What this closes, and what it does not

**Closes M13's question** — there is a root cause, it is ordering, and it is in ngspice's own design
rather than in this tree. **It does not make the caution removable**, and nothing in ASE-L changes as a
result: no emitter, no refusal, no new sentence. ⚠ **Not measured**: whether a future ngspice sorts
hybrids by dependency (it would have to; nothing in the source suggests it does), and the UNKNOWN-latch
artefact of §12.2, which is a separate ngspice behaviour with its own thresholds.
