# Session prompt: fix the exit-stub disconnect, then enable the fluid nice escape

Branch `fluid-editing`. Feature: **nice multi-pin drag rerouting**
(`doc/claude/specs/nice_drag_rerouting.md`). Phase 0 (golden predicates + fixtures),
Phase 1 (runtime P1/P2 guards) and Phase 2 (escape-normal getter) are done and pushed;
Phase-3 groundwork is committed (`f564f6ae`). Your job is the **remaining Phase-3 work**:
make the single-pin "nice escape" connectivity-safe and turn it on in fluid mode.

## The problem (one line)

Firing `insert_exit_stubs()` on a plain fluid stretch drag **disconnects a net** — even a
2-pin resistor. The nice escape itself works (it makes P3 and P5 go GREEN), but it breaks
P1 (connectivity). Root-cause and fix that, then enable it.

## Exact repro

```sh
cd <repo-root>   # must run from repo root (headless tests need it; XSCHEM_SHAREDIR)
```
Scratch (2-pin res, both pins wired to labels, perpendicular drag, exit-stubs firing):

```tcl
source [file join tests headless wireedit fixtures.tcl]
source [file join tests headless wireedit predicates.tcl]
proc ibn {n} { set ni [xschem get instances]; for {set i 0} {$i<$ni} {incr i} { if {[xschem getprop instance $i name] eq $n} {return $i} }; return -1 }
we_reset 1 1
set cadence_compat 1; set autotrim_wires 1; set fluid_editing 1; set wire_exit_stub 1
xschem instance devices/res 0 0 0 0 {name=RA}
xschem wire 0 30 0 130 ;  xschem instance {lab_pin.sym} 0 130 0 0 {name=LM lab=NM}
xschem wire 0 -30 0 -130 ; xschem instance {lab_pin.sym} 0 -130 0 0 {name=LP lab=NP}
set snap [net_snapshot]
xschem unselect_all; xschem select instance [ibn RA]
we_move_stretch 40 0
puts "P1=[p1_netlist_invariant $snap] P3=[p3_escape_perp RA 10] P4=[p4_orthogonal] P5=[p5_no_body_cross]"
```
Run: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <that>.tcl`.
Observed today: **`P1=0 P3=1 P4=1 P5=1`** (P1=0 is the disconnect). Note `wire_exit_stub 1`
here forces the stub via the shipped gate so you can debug without touching the fluid gate.

## Where the code is (`src/move.c`)

- `insert_exit_stubs()` ~L1548 — the exit-stub inserter (this IS Phase-3's ⟂ stub). It loops
  over selected instances' pins; for a pin whose single attached first leg is PERPENDICULAR
  to the escape normal, it SLIDES that leg one grid out along the normal, drags the far corner
  and its neighbours with it (~L1595-1606), and drops a short stub at the pin
  (`storeobject(...)`). Escape normal now comes from `get_pin_escape_normal()` (Phase 2).
- The slide/store block (~L1595-1606) and the corner-neighbour drag (~L1598-1602) are the
  prime suspects: dragging the far corner may detach a wire that WASN'T part of the corner, or
  the new stub may not preserve the pin↔net attachment. Existing guards: `point_on_fixed_pin`,
  `has_corner`.
- Move-END call site + gate ~L2251 (currently `wire_exit_stub` only; a NOTE there documents the
  deferral). Re-enable fluid by OR-ing `tclgetboolvar("fluid_editing")`.

## Task

1. **Root-cause the disconnect.** Instrument: dump `segset` + `instance_nodemap RA` / label
   nodemaps before and after, for the repro. Find which wire/endpoint loses its net. Likely a
   far-corner drag that moves a wire off a pin, or the pin-side stub not reconnecting.
2. **Fix it so P1 stays GREEN** while P3/P5 stay GREEN (the nice escape must not disconnect).
   Add a RED-first unit test in `tests/headless/wireedit/` that asserts P1==GREEN for the repro.
3. **Enable the fluid nice escape:** gate `insert_exit_stubs` on `wire_exit_stub || fluid_editing`
   (keep the `type=="label"` skip already in the loop), rebuild.
4. **Re-baseline the fixtures.** F3 (`test_wireedit_24`) and F8 (`test_wireedit_25`) will change:
   re-run them, and where P3/P5 flip RED→GREEN, update their `pred_verdict` baselines to the new
   reality (that flip is Phase 3 WORKING — the whole point). Add an **F2 fixture**
   (`test_wireedit_2?_F2_two_pin_res.tcl`): 2-pin res, both pins wired, drag ⟂, assert P1/P3/P4/P5.
5. Keep the full wireedit suite green and `test_wire_split` + `test_fluid_editing` `OVERALL: ok`.

## Test / discipline notes (learned this feature)

- Harness: `tests/headless/wireedit/` — `fixtures.tcl` (build/move helpers), `predicates.tcl`
  (p1..p7, seg_touch, pin_escape_normal, pred_verdict). Runner: `sh tests/headless/wireedit/run_wireedit.sh`
  (true-headless, auto-globs `test_wireedit_*.tcl`; F-fixtures numbered 20+).
- `move_objects dx dy stretch kissing` == the interactive drag release (byte-identical);
  `we_move_stretch`/`we_move` wrap it.
- Net readback MUST use `xschem resolved_net 0` (the `0`!), never bare `resolved_net` — bare
  resolves the SELECTED net and mislabels every wire after a move, hiding shorts.
- P1 (`instance_nodemap`) and P2 (wire nodes) are complementary — instance node echoes a label's
  own name and is blind to merges; the Phase-1 C guards (`move.c fluid_check_move_invariants`,
  `fluid_snapshot_partition`) mirror them and publish `fluid_last_move_violations` /
  `fluid_last_move_disconnects` for tests.
- Gate everything so default (fluid_editing/wire_exit_stub off) stays byte-identical.
- Every predicate/test needs a sabotage case (green-but-hollow discipline).
- Adding an `xschem` subcommand: put it in the matching-first-letter `xschem_cmds_<letter>()`
  function in scheduler.c or it's silently unreachable ("invalid command").

## Acceptance

- Repro: `P1=1 P3=1 P4=1 P5=1` (nice escape, no disconnect).
- Fluid gate on; F2 GREEN across P1/P3/P4/P5; F3/F8 re-baselined with P3/P5 flipped GREEN and
  P1 GREEN; whole wireedit suite + move regressions green.
- Consider an adversarial review workflow of the fix (memory-safety + connectivity-correctness).
