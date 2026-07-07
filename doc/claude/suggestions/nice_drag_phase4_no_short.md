# Session prompt: Phase 4 — no-short guard + rip-up (P2 becomes enforced)

Branch `fluid-editing`. Feature: **nice multi-pin drag rerouting**
(`doc/claude/specs/nice_drag_rerouting.md`). Phases 0–3 are DONE and pushed
(github/fluid-editing @ `c0ce9d06`): golden predicate harness (P1..P7), runtime P1/P2
guards (log-only), the escape-normal getter, and the fluid nice-escape (exit stubs) now
fires and is **connectivity-safe** (P1 holds; the touch()-ordering disconnect is fixed via
`order_wire_coords`). Your job is **Phase 4**: make the hard invariant **P2 (no-short)**
actually hold for the moving bundle, not just get logged.

## The problem (one line)

A drag can leave two **distinct nets touching** — a silent short. Two sources: (a) the plain
stretch drag slides a moved pin's wire onto an adjacent net (F5); (b) the Phase-3 exit-stub
**slide** shifts a leg/stub one grid sideways onto a different-net wire. Today both are only
**detected and logged** (`dbg(0, ... INVARIANT (P2) ...)` + `fluid_last_move_violations`),
never prevented. Spec §4 says P2 is a HARD invariant: *block/undo the move rather than ship a
short.* Phase 4 = detect the distinct-net coincidence and **repair or refuse** it.

## Exact repro (a real short today)

```sh
cd <repo-root>   # headless tests need repo-root cwd; XSCHEM_SHAREDIR
```
Two adjacent labelled nets; drag a device pin onto the neighbour (this is `test_wireedit_26`'s
shorting case and fixture F5 `test_wireedit_22`):

```tcl
source [file join tests headless wireedit fixtures.tcl]
source [file join tests headless wireedit predicates.tcl]
proc ibn {n} { set ni [xschem get instances]; for {set i 0} {$i<$ni} {incr i} { if {[xschem getprop instance $i name] eq $n} {return $i} }; return -1 }
we_reset 1 1
set cadence_compat 1; set autotrim_wires 1; set fluid_editing 1
xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
xschem wire 0 30 0 130  ; xschem instance {lab_pin.sym} 0 130 0 0 {name=LA lab=NETA}
xschem wire 40 30 40 130; xschem instance {lab_pin.sym} 40 130 0 0 {name=LB lab=NETB}
set snap [net_snapshot]
xschem unselect_all; xschem select instance [ibn RA]
we_move_stretch 40 0
puts "P1=[p1_netlist_invariant $snap] P2=[p2_no_short] viol=$::fluid_last_move_violations"
```
Run: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <that>.tcl`.
Today: **`P2=0`** (NETA/NETB merged; NETA wins, NETB vanishes) and `viol>=1` (the guard SAW it
but let it ship). Phase 4 must make this **`P2=1`** — the move must not silently short.

## Where the code is (`src/move.c`, HEAD c0ce9d06)

- `fluid_check_move_invariants()` ~L1751 — the runtime P1/P2 guard at move END. **P2 block**
  at ~L1756 already detects the short (every net label must still sit on a wire whose resolved
  node == the label's own net; mismatch ⇒ `++shorts`) and publishes `fluid_last_move_violations`.
  It is **log-only, non-fatal**. This is your detection primitive — extend it (or a sibling) to
  ACT.
- `fluid_snapshot_partition()` ~L1731 captures pre-move state at move START (you likely need a
  fuller snapshot to roll back to — today it stores only the pin partition for P1).
- `insert_exit_stubs()` ~L1565 + the slide at ~L1615 — the Phase-3 stub inserter; its slide is
  the (b) short source. `order_wire_coords()` ~L1555 (don't disturb — it's the P1 fix).
- Move END + gate ~L2285 (`insert_exit_stubs()` under `wire_exit_stub || fluid_editing`).

## Decide the Phase-4 shape (spec §5b vs §4)

Two viable scopes — **pick one, state why**, ask the user if unsure (§10.2 is unresolved):
1. **Refuse/undo (minimum, safe):** on detected short, roll the move back (or roll back just
   the offending stub-slide) so the schematic is never left shorted. Simplest; P2 always holds;
   the drag just "declines" the unsafe reroute. Matches §4's "block/undo rather than ship."
2. **Rip-up-reroute the offender (spec §8 Phase 4 target):** reuse `touch()` + net-compare (the
   H2/H3 no-short machinery from wire-splitting, see [[wire-segment-splitting]] W5) to find the
   distinct-net coincidence, then minimally reroute the offending wire (jog it off the other
   net) to clear the short while keeping P1. More work; lands the "nice" result.

Recommend starting at (1) as a correctness floor (RED-first test proves P2 enforced), then
layering (2) where a cheap local jog obviously fixes it. The full solver is Phase 6 — don't
build it here.

## Task

1. **RED-first test.** Add `tests/headless/wireedit/test_wireedit_3?_no_short_guard.tcl`: the
   repro above asserts `P2==GREEN` after the move (RED against HEAD). Plus a sabotage case
   proving the guard has teeth, and a NON-short control (a clean drag must NOT trigger the
   refuse/reroute — no false positive).
2. **Enforce P2** in `move.c` per your chosen shape. Gated on `fluid_editing` (default off ⇒
   byte-identical). Keep P1 GREEN (don't fix a short by disconnecting).
3. **Re-baseline the flipped fixtures.** F5 (`test_wireedit_22`) P2 flips RED→GREEN (that flip
   IS Phase 4 working) — update its `pred_verdict` baseline. Check F3/F8 P2 stay GREEN.
4. Keep the whole wireedit suite green (31 tests today) and `test_wire_split` +
   `test_fluid_editing` `OVERALL: ok`.
5. Adversarial review workflow of the guard (does the rollback/reroute ever ITSELF disconnect
   or loop; does it stay byte-identical when off; memory-safety of any snapshot/restore).

## Test / discipline notes (carried through this feature)

- Harness `tests/headless/wireedit/`: `fixtures.tcl` (build/move helpers), `predicates.tcl`
  (`p1_netlist_invariant`, `p2_no_short`, p3..p7, `pred_verdict`). Runner
  `sh tests/headless/wireedit/run_wireedit.sh` (true-headless `--nogui`, globs `test_wireedit_*`).
- `we_move_stretch dx dy` == `move_objects dx dy stretch kissing` == the interactive drag
  release (byte-identical).
- Net readback MUST use `xschem resolved_net 0` (the `0`), never bare — bare resolves the
  SELECTED net and mislabels every wire after a move, hiding shorts. `p2_no_short` handles this.
- **P1 and P2 are complementary:** `instance_nodemap` ECHOES a label's own name so P1 is blind
  to a merge; `p2_no_short` (wire-level resolved names) catches merges; P1 catches disconnects.
  F5 is the proof case (real short today: P2 RED, P1 GREEN).
- Gate everything so default (`fluid_editing`/`wire_exit_stub` off) stays byte-identical (the
  golden harness is authoritative). Every predicate/guard needs a sabotage case
  ([[green-but-hollow]]).
- New `xschem` subcommand ⇒ put it in the matching-first-letter `xschem_cmds_<letter>()` in
  scheduler.c or it's silently unreachable ([[scheduler-letter-dispatch]]).
- `run_regression.tcl` from `tests/` shows env FAILs (needs `xschem` on PATH + gold dirs) —
  run headless tests DIRECTLY with `./src/xschem --nogui ...` ([[xschem-pipe-script-test-gotchas]]).

## Acceptance

- Repro: `P1=1 P2=1` (no short, no disconnect).
- F5 P2 re-baselined RED→GREEN; F3/F8 P2 stay GREEN; whole wireedit suite + wire_split +
  fluid_editing green.
- Guard gated (default off byte-identical), sabotage-proven, adversarially reviewed.

## Known residual carried IN (not Phase 4's job unless trivial)

- **Phase-2 crude normal** on ambiguous pins (mos bulk `b` = F8.P3 RED; corner pins; text-skew
  from `symbol_bbox` inflating `inst.x1..x2` with attr text — the graphic-only box `inst.xx1..xx2`
  is the cheap lever). Quality only, never connectivity. Refine geometry later, no `dir=` property
  (§10.1 decided).
- **F8.P3** (bulk-pin escape) is a Phase-5 lane-assignment concern, not Phase 4.
