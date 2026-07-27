# 0164 — `resolved_net()` ignores the symbol template when an instance omits an `extra=` node

Status: **FIXED**
Area: `src/hilight.c` (`resolved_net`, the attribute-resolution loop at `:2658-2690`)
Tests: `tests/headless/test_resolved_net_templ_fallback_0164.tcl` (23 checks, both arms)
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
/* src/token.c ~5206, inside translate() -- the path SPICE actually takes */
value = get_tok_value(xctx->inst[inst].prop_ptr, token+1, 0);
if(!xctx->tok_size && xctx->inst[inst].ptr >= 0) {
  value = get_tok_value(xctx->sym[xctx->inst[inst].ptr].templ, token+1, 0);
}
```

(The tEDAx backend has its own chain at `token.c:3245-3247` with an extra `net:<pinnumber>`
middle step and an `!extra_token_val[0]` guard. That guard is **not** the one to copy — see the
present-but-empty case below.)

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

## Fix

One fallback in the accepted-attribute arm, mirroring `translate()`:

```c
ptr = get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0);
if(!xctx->tok_size) ptr = get_tok_value(xctx->hier_attr[level - 1].templ, resolved_net, 0);
```

The guard is **`!xctx->tok_size`** — "the token is ABSENT from the instance attributes" — not
`!ptr[0]`. That distinction is measured, not stylistic: an instance carrying `VCCPIN=""` gets **no
node** in the netlist, so it must *not* inherit the template default. Legs TF10 and TF15 are the
ones that fail if the fallback is written the other way.

`hier_attr[k].templ`, `.prop_ptr` and `.sym_extra` are written together from the same instance /
symbol pair at every write site (`actions.c:3582-3586`, `save.c:5588-5593`), so `level-1` indexes
the same thing for all three. `get_tok_value()` returns `""` for a `NULL` first argument, so a
symbol with no template is safe, and `xctx->tok_size = 0` is the first statement of
`get_tok_value()`, so the flag is a valid signal from the call immediately above.

A leading `#` on the template-sourced value is kept **verbatim**, same as an instance-sourced one —
see issue 0163's Correction section for the ngspice measurement behind that.

Three things settled before writing it:

1. `get_tok_value` returns a pointer into a **static** buffer (`static char *result`,
   `src/token.c`), so a second call invalidates the first — the fallback must not be written as
   `a ? a : b` with both calls live at once. It is written as two statements for that reason; the
   first value is known empty when the second call runs.
2. The `netstring` (`net:<pinnumber>`) middle step is **not** copied. It belongs to the tEDAx
   backend's own chain and is a pin-number override (`extra_pinnumber`); the SPICE path that
   `resolved_net` must match does not have it.
3. The `#` strip 0163 originally added was **reverted** before this change landed (see 0163's
   Correction), so a template-sourced value is passed through verbatim like an instance-sourced
   one. Legs TF18/TF19 assert that.

## Ground truth (measured, one fixture, netlist + `resolved_net` side by side)

Child `c` has `extra="VCCPIN"`, `template="name=x1 VCCPIN=VCC"`; `n` has `extra="NX"` and no
default for it; `g` has `extra="GX"`, `template="... GX=VCCPIN"` and sits inside `c`.

| instance | netlist emits | before | after |
|---|---|---|---|
| `X1` — attribute absent, template has a default | `X1 TOP1 VCC c` | `X1.VCCPIN` | **`VCC`** |
| `X2` — attribute explicit | `X2 TOP2 VDDEXPLICIT c` | `VDDEXPLICIT` | unchanged |
| `X5` — attribute present but **empty** | `X5 TOP5 c` (no node) | `X5.VCCPIN` | unchanged |
| `X3` — no default anywhere | `X3 TOP3 n` (no node) | `X3.NX` | unchanged |
| `X1.Y1` — two template hops | `Y1 YIN VCCPIN g` → `VCC` | `X1.Y1.GX` | **`VCC`** |
| `X2.Y1` — template hop then explicit | → `VDDEXPLICIT` | `X2.Y1.GX` | **`VDDEXPLICIT`** |

## Verification

- **RED first**: 7 legs failed / 16 passed before the fix; 23/23 after, in both the `--nogui` and
  the `--pipe`+`DISPLAY` arm.
- **Sabotage matrix, both directions**, each patch pattern-asserted in python: remove the fallback
  → 7 fail; fall back on empty value instead of absent token → 2 fail (TF10, TF15 — exactly the
  discriminating pair); always use the template, ignoring the instance → 5 fail in 0164 and 9 in
  0163; read `hier_attr[level]` instead of `[level-1]` → 7 fail; remove 0163's `extra=` gate → 2
  fail in 0164 (TF16/TF17) and 10 in 0163. Every leg has teeth.
- **Netlist-neutral**: 201 stock designs netlisted back-to-back with a true pre-0163 binary and the
  current one are byte-identical apart from the output directory in one `.include` path. (Run them
  back to back — xschem writes gitignored `<cell>~.sch` autosave files as it descends, and a stale
  one made an earlier comparison show a spurious diff.)
- Adjacent suites green: 0155-0161, `test_ase_core/final/final_gf180`, `test_ase_unnamed_net`, the
  58-file wireedit suite.

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
