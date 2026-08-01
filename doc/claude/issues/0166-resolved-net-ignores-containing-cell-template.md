# 0166 — `resolved_net()` misses an `extra=` node supplied by the CONTAINING CELL's template

Status: **OPEN**
Area: `src/hilight.c` (`resolved_net`, the attribute-resolution loop at `:2658-2690`)
Tests: none yet — `tests/headless/test_resolved_net_templ_fallback_0164.tcl` is the natural home
Found: immediately after 0164 landed, from re-reading which chain the SPICE netlister actually uses
Related: **0164 (this is the half of it that was missed)**, 0163, 0161

## In plain English

Issue 0164 gave `resolved_net` a template fallback: when a parent instance does not carry an
`extra=` attribute, take the default from that instance's own symbol template
(`hier_attr[level-1].templ`). That was measured against `translate()` at `src/token.c` ~5206, a
generic two-step `instance property string → the instance's symbol template`.

**That is not the whole chain the SPICE netlister uses for an `extra=` node.**
`print_spice_element()` (`src/token.c` ~2615-2645) runs a *cascade*, re-trying while the value still
contains an unresolved `@`, and one of its later steps consults the template of the cell that
**contains** the instance — `hier_attr[currsch-1].templ` at that point — not the instance's own
symbol template.

So a cell can supply an `extra=` default to everything instantiated inside it, and the netlist
honours that while `resolved_net` does not.

## Measured

Fixture: `cleaf.sym` has `extra="VCCPIN"`, `format="@name @pinlist @VCCPIN @symname"` and
`template="name=x1"` — **no** `VCCPIN` default of its own. `cmid.sym` has
`template="name=x1 VCCPIN=MIDVCC"` and its schematic holds `xa` of `cleaf` with **no** `VCCPIN=`
attribute. Top holds `xm` of `cmid`.

```
.subckt cmid A  VCCPIN=MIDVCC
xa net1 MIDVCC cleaf              <- xa's node comes from cmid's template
.subckt cleaf A VCCPIN
```

Descended into `.xm.xa.`:

```
xschem resolved_net {VCCPIN}  ->  xm.xa.VCCPIN
```

The netlister put `xa`'s `VCCPIN` on the node `MIDVCC`, which is **local to `cmid`**, so its
simulator name is `xm.MIDVCC`. Confirmed with ngspice-42 on the equivalent deck:

```
   xm.midvcc     6.666667e-01
   topn          1.000000e+00
```

**Expected: `xm.MIDVCC`. Actual: `xm.xa.VCCPIN`.** Note the expected value carries the `xm.` prefix —
it is *not* the flat `MIDVCC`. Getting that wrong is the easy mistake here.

## Shape of the fix

At level `L`, the source order should become

```
hier_attr[L-1].prop_ptr   (the instance's own attributes)          -- 0163
hier_attr[L-1].templ      (the instance's own symbol template)     -- 0164
hier_attr[L-2].templ      (the CONTAINING cell's template)         -- 0166, missing
```

and on a hit from the third source the walk must still `level--` exactly once, so the resolved name
(`MIDVCC`) is then interpreted in the containing cell's scope and picks up that cell's path prefix.
That is what produces `xm.MIDVCC` rather than `MIDVCC`.

Points to settle before writing it:

1. **Bounds.** `L-2` must be guarded against both `< 0` and `< start_level`. `start_level` is
   `sch_waves_loaded()`, so the floor is not always 0.
2. **`get_tok_value` returns a STATIC buffer** — three candidate sources means three calls, only one
   of which may be live at a time. `xctx->tok_size` is the "token absent" signal and is reset by
   every call, so it must be read immediately after the call it refers to.
3. **Does the `attr_is_extra_node()` gate still apply?** The gate reads
   `hier_attr[L-1].sym_extra` — the `extra=` list of the instance's own symbol, which is the right
   list regardless of which template supplied the value. Confirm rather than assume.
4. **Is the cascade order right?** `print_spice_element` re-tries only while the value still holds an
   `@`. Whether that makes the containing-cell template a *fallback* or a *parallel* source in some
   case was NOT determined — read `translate3()` (`src/token.c` ~5452-5556) before deciding.
5. **Deeper than two levels?** Whether a great-grandparent template can supply the value was NOT
   measured. Build the three-level case.

## How reachable

**Not measured for this variant.** 0164's sweep established that every committed instance of an
`extra=`-carrying symbol spells its attributes out explicitly, so the plain 0164 case has no in-tree
hit; whether any committed cell supplies an `extra=` default from its *own* template to instances
inside it was not swept for. Do that sweep before deciding how much this matters.

## Provenance note

This was surfaced by a background investigation agent, and the claim was then reproduced
independently before being written down — including the `xm.` prefix, which the agent's summary got
wrong (it reported the expected value as flat `MIDVCC`). Treat the agent's remaining unverified
claims in that report the same way.
