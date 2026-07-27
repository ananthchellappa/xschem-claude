# 0165 — one `#`-leading name becomes TWO nodes in the netlist, depending on how it arrived

Status: **OPEN**
Area: `src/token.c` (`print_spice_element`, the `extra=` node emission) vs the label/net-naming path
Tests: none yet
Found: while fixing 0164, measuring what `resolved_net` must match (issue 0163's Correction)
Related: 0163 (the strip that was reverted because of this), 0158, 0156 (the `#`-reserved policy)

## In plain English

`#` is xschem's private marker for an auto-named net. The netlisters strip it, so a net the engine
called `#net1` reaches the simulator as `net1`. Issue 0156 ratified that a user may nonetheless
*write* `#foo` as an ordinary name, and 0158 measured that such a label netlists as plain `foo`.

But an `extra=` binding — a "hidden pin" whose connection is passed as an instance attribute
(`doc/xschem_man/symbol_property_syntax.html:284-305`) — is **not** stripped. Its value is written
onto the subcircuit call line verbatim. So the same spelling produces two different nodes.

Measured, ngspice-42, one deck:

```
V1 topn 0 1
X1 topn #hfoo c      <- the extra= binding: value passed through verbatim
R9 hfoo  0    1k     <- a wire LABELLED #hfoo: the '#' stripped by the label path

   hfoo    0.000000e+00      <- the label's node
   #hfoo   1.000000e+00      <- the binding's node
   topn    1.000000e+00
```

Two nodes, unconnected, from one name the user wrote once. ngspice accepts `#` in a node name and
reports it verbatim, so nothing downstream complains.

The node reached only by the binding is, in practice, **unreachable by any other means**: there is
no way to draw a wire that lands on `#hfoo`, because every label goes through the stripping path. So
a design that binds `VCCPIN=#foo` silently connects the child's supply to a node nothing else
touches — a floating supply, with no warning from ERC or the simulator.

## Where the two paths diverge

- **Label / net-name side, strips.** `set_lab_or_pin_inst_attr()`, `src/netlist.c:956`:
  ```c
  if(node[0] == '#') {
    node++;
  }
  ```
  plus the same idiom in `src/node_hash.c` (`:132`, and the print paths `:290`, `:302`, `:351`,
  `:362`).
- **`extra=` binding side, does not strip.** `print_spice_element()`, `src/token.c` ~2615-2645,
  resolves the `@TOKEN` and writes the value straight into the call line. No `#` test anywhere on
  that path.

`src/netlist.c:778-790` already documents the surrounding policy and is worth reading first: a bare
`name[0]=='#'` test does **not** mean "auto-named", which is why `is_auto_net_name()` exists and why
output-strip sites were deliberately left loose (0156).

## Why `resolved_net` was NOT the place to fix it

Issue 0163 originally shipped a `#` strip on the accepted attribute value and it was **reverted**
(`a5a08bc8`) once the above was measured. `resolved_net`'s contract is to name the node the
simulator actually has. Given a binding `HN=#hfoo`, that node *is* `#hfoo`; stripping named `hfoo`,
a different node the child's port is not connected to. `get_raw_index()` never strips `#` either, so
the strip would have silently resolved to the wrong node instead of failing.

That decision stands regardless of how 0165 is resolved — but if the netlister is changed to strip,
`resolved_net` must be revisited in the same change so the two stay in agreement.

## How reachable

**Zero committed designs.** Of 68016 non-empty instance attribute values in the tree, exactly 7
begin with `#`, all of them the same disabled `xxxspiceprefix=#D#`
(`xschem_library/pcb/voltage_protection.sch:69`, `pcb_voltage_protection.sch:76`, + mirrors), and
none is an `extra=` binding. For contrast, 4778 net labels across 407 `.sch` files begin with `#`,
so the label-side strip is heavily exercised — it is only the binding side that has no committed
case.

So this is latent. It needs a user to type `#something` as an attribute value, which nothing
prevents and nothing warns about.

## Not yet decided

1. **Strip on the binding side, or leave it?** Stripping makes the two paths agree and removes the
   unreachable-node trap. **But it CHANGES NETLIST OUTPUT** — unlike 0163 and 0164, which were
   verified byte-identical over 201 stock designs. That is a much higher bar: any change here needs
   the same 201-design diff run and an explicit decision that the diff is desirable.
2. **Strict or loose?** `is_auto_net_name()` (`#net<digits>`, issue 0156) versus any leading `#`.
   The label path is loose (`node[0] == '#'`). Matching it argues loose; the 0156 policy that only
   engine-minted names are the engine's business argues strict. Note the two disagree exactly on the
   user-authored `#foo`, which is the case in the measurement above.
3. **Or warn instead of rewrite?** An ERC warning ("attribute `%s=%s` names a node starting with
   '#', which no label can reach") would surface the trap without touching netlist output. `print_erc`
   fires on a netlist run and is assertable via `xschem get infowindow_text`; `netlist.c:1491` is an
   existing example of exactly this shape of warning for a `#` name.
4. **Which backends?** The divergence was measured on SPICE. Spectre has the structurally identical
   code path but was NOT measured. Verilog uses `verilog_extra` and a different two-step resolution;
   VHDL turns extra tokens into *generics*, not nodes; the tEDAx `conn` emission is unreachable for
   subcircuits (all three READ, not measured).

## Reproduce

```
V1 topn 0 1
X1 topn #hfoo c
R9 #hfoo 0 1k
.subckt c A HN
R1 A HN 1k
.ends
.op
.end
```

`ngspice -b` reports node `#hfoo`. Then build the same shape in xschem — a symbol with
`extra="HN"`, `format="@name @pinlist @HN @symname"`, an instance carrying `HN=#hfoo`, and a wire
labelled `#hfoo` — and netlist it: the call line carries `#hfoo`, the wire becomes `hfoo`.
