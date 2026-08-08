# 0231 — a net's name is decided by file record order, and a hierarchy port loses to a plain label

Status: **OPEN** — measured, no fix proposed (a real fix is a naming-policy change, not a patch).
Area: `src/netlist.c` `name_nodes_of_pins_labels_and_propagate()` (`:1427`), `wirecheck()` (`:1090`), `name_attached_nets()` (`:1114`)
Tests: none yet — proposed `tests/headless/test_net_name_precedence_0231.tcl`
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0230** — the short detector that should make this audible is silent on `-nohier` and never highlights. Prior art on net naming: 0154, 0156, 0157, 0158, 0163, 0164, 0165, 0166, 0180, 0185.

## The defect

When two differently-named labels or ports touch the same conductor, the name that
survives is whichever instance appears **first in the `.sch` file**. There is no
precedence rule of any kind — in particular, **a hierarchy port does not beat a net
label**.

The driving loop is a plain ascending walk of the instance array, which is file order:

```c
src/netlist.c:1427
  for (i=0;i<instances; ++i) {
```

and both naming sites are first-writer-wins on a NULL check:

```c
src/netlist.c:1090-1098                       (wirecheck — net-to-net propagation)
        if( touches ) {
          if(!wire[n].node) {
            my_strdup(_ALLOC_ID_, &wire[n].node, wire[k].node);
            …
          } else {
            if(for_netlist>0) err |= signal_short("Net to net", wire[n].node, wire[k].node);
          }

src/netlist.c:1114-1121                       (name_attached_nets — label/pin to net)
    if(touch(wire[n].x1, wire[n].y1, wire[n].x2, wire[n].y2, x0,y0)) {
      if(!wire[n].node) {
        my_strdup(_ALLOC_ID_,  &wire[n].node, node);
        …
      } else {
        if(for_netlist>0) err |= signal_short("Net", wire[n].node, node);
      }
```

Labels and ports share one branch, with no ordering by kind:

```c
src/netlist.c:1457
    if(type && inst[i].node && IS_LABEL_OR_PIN(type) ) { /* instance must have a pin! */
```

## Measured

**Order dependence.** `short1.sch` and `short3.sch` are byte-identical except that the two
`C {...}` lines are swapped:

```
N 0 0 200 0 {lab=AAA}
C {devices/lab_pin.sym} 0 0 0 0 {name=l1 sig_type=std_logic lab=AAA}
C {devices/lab_pin.sym} 200 0 0 0 {name=l2 sig_type=std_logic lab=BBB}
C {devices/res.sym} 100 30 0 0 {name=R1 value=1k …}
```

```
short1.spice ->  R1 AAA net1 1k
short3.spice ->  R1 BBB net1 1k
```

**No port-beats-label precedence — and it corrupts the interface.** `p1.sch` has
`lab_pin lab=AAA` listed first and `ipin lab=BBB` second; `p2.sch` is the same two lines
swapped:

```
p1.spice -> **.subckt p1 BBB      /  R1 AAA net1 1k
p2.spice -> **.subckt p2 BBB      /  R1 BBB net1 1k
```

In `p1` the port `BBB` is declared in the `.subckt` header and **connects to nothing in
the body** — the hierarchy port lost to a plain label purely because it came second in the
file. The parent netlist will wire a signal into a port that goes nowhere.

## Why it is not merely academic

`.sch` record order is not stable under editing. Copy/paste, delete-and-redraw, symbol
regeneration and any script that rewrites a schematic can reorder instance records without
changing the drawing, silently changing which name reaches the simulator and which port is
live. Under **0230** the `-nohier` and Shift-N paths do not even print the short.

## Direction, not a fix

A patch to `:1091` / `:1115` is not enough — by the time the second writer arrives the
first name has already propagated through `wirecheck()`'s recursion. Options, in
increasing order of cost:

1. **Deterministic-but-arbitrary** — sort candidate namers before the loop, so at least
   the result no longer depends on file order. Cheap, does not fix the port case.
2. **Port beats label** — run a pre-pass over `IS_PIN(type)` instances (`xschem.h:582`,
   already the exact concept) before the general loop, so a hierarchy port claims its net
   first. Fixes the `.subckt` corruption above; still arbitrary between two labels.
3. **Report and refuse** — treat two distinct explicit names on one conductor as an ERC
   error that fails the netlist, rather than picking one. This is the Cadence semantic.
   Depends on **0230** landing first, since today the message does not reach the user on
   every path.

Whichever is chosen, `signal_short()` must keep firing — the collision should stay audible
even once the winner is deterministic.

## Risks

- Any of options 1–3 changes generated netlists for existing designs that currently rely
  (knowingly or not) on the file-order outcome. `tests/netlist_diff/netlist_diff.sh
  <old-binary>` over the shipped libraries is the check; it netlists every
  `xschem_library` design in all five backends with two binaries and diffs them.
- Option 2 changes `wirecheck()`'s propagation order, which is recursive — verify the
  recursion still terminates and that bus expansion (`bus_node_hash_lookup`,
  `node_hash.c:123-163`) sees the same names.
- Option 3 turns designs that netlist today into designs that refuse to netlist. That is
  the correct semantic but needs a preference and a release note.
