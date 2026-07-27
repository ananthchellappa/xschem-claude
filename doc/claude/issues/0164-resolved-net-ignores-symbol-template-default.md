# 0164 — `resolved_net()` ignores the symbol template when an instance omits an `extra=` node

Status: **OPEN**
Area: `src/hilight.c` (`resolved_net`, the attribute-resolution loop at `:2629-2657`)
Tests: none yet
Found: while fixing 0163, from reading how the netlister resolves the same attributes
Related: 0163 (the fix that scoped this loop to `extra=`), 0158, 0157

## In plain English

A symbol can declare "hidden pins" — connections passed as attributes rather than drawn as pins —
with its `extra=` attribute (`doc/xschem_man/symbol_property_syntax.html:284-305`). `resolved_net`
now honours exactly those (issue 0163), reading the binding off the parent **instance**:

```c
ptr = get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0);
```

But a symbol also carries a **template**, which supplies a default for every attribute the instance
does not spell out. `xschem_library/rom8k/lvnot.sym`:

```
template="name=x1 m=1 ... VCCPIN=VCC VSSPIN=VSS"
extra="VCCPIN VSSPIN"
```

An instance written as `C {lvnot.sym} … {name=x9 wn=8.4u}` — no `VCCPIN=` — is netlisted by the
netlister against `VCC`, because it falls back to the template when the instance has nothing:

```c
/* src/token.c:3245-3247 */
extra_token_val = get_tok_value(xctx->inst[inst].prop_ptr, extra_token, 0);
if(!extra_token_val[0]) extra_token_val = get_tok_value(xctx->inst[inst].prop_ptr, netstring, 0);
if(!extra_token_val[0]) extra_token_val = get_tok_value(template, extra_token, 0);
```

`resolved_net` has no such fallback. It finds nothing on the instance, breaks out of the loop, and
returns the *local* form `x9.VCCPIN` — a node the simulator never emitted. The waveform trace is not
found and the plot comes up empty with no error, the same silent failure mode as 0158 and 0163.

The data needed is already there: `xctx->hier_attr[].templ` is captured next to `.prop_ptr` at every
write site (`actions.c:3584`, `save.c:5590`, `spice_netlist.c:472`, `spectre_netlist.c:358`) and is
already read for parameter substitution in `token.c` (`:2596`, `:2972`).

## How reachable

**No committed design hits it.** Swept every instance of every symbol with a non-empty `extra=`:
every subcircuit instance in the tree that has an `extra=` node spells the attribute out explicitly
(xschem writes template attributes into the instance property string when the instance is placed).
The instances that *do* omit them are all tEDAx/PCB part symbols (`4000-1`, `22V10-DIP-1`, …) with
no schematic, so no descend and no `resolved_net` ever reaches them.

So this is a latent correctness gap, not a live defect: it bites a hand-edited instance, an instance
written by a generator or script that emits only the non-default attributes, or any future symbol
whose template default is the common case.

## Fix sketch

One fallback in the accepted-attribute arm, mirroring `token.c:3247`:

```c
ptr = get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0);
if(!ptr || !ptr[0]) ptr = get_tok_value(xctx->hier_attr[level - 1].templ, resolved_net, 0);
```

Three things to settle before writing it:

1. `get_tok_value` returns a pointer into a **static** buffer (`static char *result`,
   `src/token.c`), so a second call invalidates the first — the fallback must not be written as
   `a ? a : b` with both calls live at once. It also sets `xctx->tok_size`, which is the way to tell
   "token absent" from "token present with an empty value" if that distinction turns out to matter.
2. Whether the `netstring` (`net:<pinnumber>`) middle step of `token.c`'s chain matters here; it is
   a tEDAx pin-number override and probably does not, but that was not measured.
3. The `#` strip that 0163 added to the accepted value must apply to the template-sourced value too.

## Reproduce (measured)

Two-level design. Child symbol with `extra="VCCPIN"`, `format="@name @pinlist @VCCPIN @symname"` and
`template="name=x1 VCCPIN=VCC"`; child schematic with a net labelled `VCCPIN`. Parent holds two
instances, `X1` written **without** a `VCCPIN=` attribute and `X2` with one. Netlist:

```
.subckt c A VCCPIN
X1 TOP VCC c                 <- X1's node comes from the TEMPLATE default
X2 net1 VDDEXPLICIT c
```

Descended:

```
X1 -> xschem resolved_net {VCCPIN}  ->  X1.VCCPIN     (wrong; the netlist says VCC)
X2 -> xschem resolved_net {VCCPIN}  ->  VDDEXPLICIT   (correct)
```
