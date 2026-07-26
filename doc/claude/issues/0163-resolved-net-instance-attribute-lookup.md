# 0163 — `resolved_net()` trusts any instance attribute whose name matches a net name

Status: **OPEN**
Area: `src/hilight.c` (`resolved_net`, the attribute-resolution loop at `:2629-2640`)
Tests: none yet
Found: while fixing 0158 (the `#`-per-element strip), both symptoms measured first-hand
Related: 0157, 0158 (the two defects already fixed in the same function), 0156 (the `#`-reserved
policy), 0154 (the audit these all came out of)

## In plain English

When you ask xschem "what is the real, full name of this net?" — which is what
`xschem resolved_net` does, and what the netlister and the waveform viewer use internally to turn
a net you clicked on into a name the simulator understands — it walks up the hierarchy one level
at a time.

The very first thing it tries at each level is: *"maybe this net isn't connected through a pin.
Maybe the parent passed it down as an attribute on the instance."* So it takes the net's name,
looks for an attribute with that exact name on the parent instance, and if it finds one, it
**replaces the net name with that attribute's value** and keeps going.

That lookup is completely unguarded. It does not check that the attribute was meant to name a net.
It does not check that the value looks like a net name. It does not clean the value up afterwards.
Two things go wrong because of that.

### Problem 1 — any attribute at all can hijack a net name

An instance carries all sorts of attributes that have nothing to do with connectivity: `value`,
`spice_ignore`, `name`, `model`, whatever the symbol defines. If a net inside the subcircuit
happens to be *named* the same as one of those attributes, the lookup matches it and the net's
resolved name silently becomes the attribute's value.

Measured, on a two-level design where the child contains nets called `value` and `spice_ignore`,
and the parent instance is `X1` with `value=1k spice_ignore=false`:

```
xschem resolved_net {value}         ->  1k
xschem resolved_net {spice_ignore}  ->  false
```

`1k` and `false` are not nets. Anything downstream that takes that string and looks for a
simulator vector, or writes it into a netlist card, is now working with a value out of a completely
unrelated field. Nothing warns. The names involved (`value` especially) are not exotic — `value` is
one of the most common attribute names in the whole symbol library.

### Problem 2 — a `#` in the attribute value survives into the answer

Unlabeled nets are called `#net1`, `#net2`, … inside xschem, but the simulator only ever sees
`net1`, `net2`. `resolved_net` is supposed to hand back the simulator's spelling, so it strips that
leading `#`. Issue 0158 moved that strip so it runs once per element of a bus instead of once per
whole name — but it still runs on the name **going in**, before this attribute lookup happens. So a
value that comes *out of* the attribute lookup is never cleaned.

Measured, same shape of design, parent instance `X1` carrying `LOC=#foo`, descended into `X1`:

```
xschem resolved_net {LOC}         ->  #foo         (should be foo)
xschem resolved_net {LOC,A}       ->  #foo,TOP
xschem resolved_net {LOC,#x,GND}  ->  #foo,X1.x,GND
```

The `#` matters because nothing downstream removes it: `get_raw_index` never strips `#`
(waveform-reference landmine 23), so a trace named `#foo` simply is not found and the plot comes up
empty with no error. In a netlist card it names a net that does not exist.

This is pre-existing, not something 0158 introduced — before 0158 the same escape applied to the
first element of a bus. The other route into this function, the **portmap** (nets passed properly
through pins), is already immune, because it strips the `#` when the map is built
(`src/actions.c:3568-3572`).

## Where it is

`src/hilight.c:2629-2640`:

```c
      while(level > start_level) { /* check if net passed by attribute instead of by port */
        const char *ptr = get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0);
        if(ptr && ptr[0]) {
          my_strdup2(_ALLOC_ID_, &resolved_net, ptr);
          ...
```

`hier_attr[].prop_ptr` is the parent instance's **entire property string**, copied wholesale at
descend time (`src/actions.c` ~3581), so `get_tok_value` can reach every attribute on the instance,
not just ones intended as net bindings. The `dbg()` line just below calls it `lcc`, which points at
the intended use — an instance whose "symbol" is really a schematic inlined into the parent (the
LCC / Local Custom Component path in `src/save.c` ~4261+), where a net genuinely can be rebound by
an attribute.

Worth noting: the measurements above were taken on a **plain subcircuit** instance, not an LCC one.
The lookup does not check which kind it is, so it fires either way.

## Not yet decided

1. **How should the lookup be narrowed?** Options, roughly in increasing ambition:
   - leave it alone and only fix the `#` (cheapest, fixes Problem 2 only);
   - skip attribute names that are known non-net fields (`name`, `value`, `model`,
     `spice_ignore`, …) — a denylist, which will always be incomplete;
   - only consult the attribute path when the instance really is an LCC one, which is what the
     comment says it is for — needs a reliable "is this LCC" test at this point in the code;
   - require the value to look like a net name before accepting it.
2. **Should the `#` be stripped off the attribute value?** The parallel case argues yes: a
   user-authored `lab=#foo` was measured (issue 0158) to netlist as plain `foo`, and the portmap
   path already strips. If so the fix is one strip on `ptr` before or after `my_strdup2`, kept
   LOOSE for the same reason 0158's is loose.
3. **How reachable is Problem 1 in a real design?** It needs a child net whose name collides with a
   parent-instance attribute name. `value` makes that plausible rather than theoretical, but no
   real-world case has been found yet — a sweep of the shipped libraries and
   `tests/`/`xschem_library` designs for child nets named like common attributes would settle it,
   and would also tell us whether a fix is a silent improvement or a behavior change someone
   depends on.

## Reproduce

Two-level design, child instantiated as `X1`, then `xschem descend` into it.

Problem 1 — child contains nets `value` and `spice_ignore`; parent instance is
`C {child.sym} 0 0 0 0 {name=X1 value=1k spice_ignore=false}`:

```
xschem resolved_net {value}         ->  1k
xschem resolved_net {spice_ignore}  ->  false
```

Problem 2 — child contains a net `LOC`; parent instance is
`C {child.sym} 0 0 0 0 {name=X1 LOC=#foo}`:

```
xschem resolved_net {LOC}  ->  #foo
```

Both reproduce identically in the `--nogui` and the `--pipe`+`DISPLAY` arm at df0f02a5.
