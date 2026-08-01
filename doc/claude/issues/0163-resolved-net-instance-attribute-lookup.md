# 0163 — `resolved_net()` trusts any instance attribute whose name matches a net name

Status: **FIXED**
Area: `src/hilight.c` (`resolved_net`, the attribute-resolution loop at `:2629-2640`)
Tests: `tests/headless/test_resolved_net_attr_scope_0163.tcl` (33 checks, both arms)
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
(`src/actions.c:3594-3599`).

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

## What the loop is actually for — `extra=`, not LCC

The `dbg()` line's "lcc" is only the struct's type name (`Lcc *hier_attr`), not a statement about
which instances the loop serves. The real feature is the **`extra=`** symbol attribute, documented
upstream at `doc/xschem_man/symbol_property_syntax.html:284-305`:

> This property specifies that some parameters defined in the format string are to be considered as
> additional pins. This allows to realize inherited connections, a kind of hidden pins with
> connections passed as parameters.

— with a worked example that is literally `format="@name @pinlist @VCCPIN @VSSPIN @symname ..."`,
`template="... VCCPIN=VCC VSSPIN=VSS"`, `extra="VCCPIN VSSPIN"`. `src/token.c` says the same thing
from the netlister's side: *"extra is the list of attributes NOT to consider as instance
parameters"*; `print_spice_subckt_nodes()` emits them as subckt ports and `get_sym_template()` keeps
them out of the parameter list. The two upstream commits that created and extended this loop
(`60c523072` "resolve nets passed to symbols via attributes", `c5705e28f` "resolve multiple levels
of port-by-attribute propagation") name the same feature.

Measured on the stock library, `xschem_library/rom8k/lvnot.sym` carries `extra="VCCPIN VSSPIN"` and
netlists as

```
.subckt lvnot y a VCCPIN VSSPIN     wn=10u lln=1.2u wp=10u lp=1.2u
x10 FN DDN vcc vss lvnot wn=8.4u lln=2.4u wp=8.4u lp=2.4u
```

so descending into `x10`, `resolved_net VCCPIN` → `vcc` is **correct and must keep working**. The
same descend also gave `m` → `1`, `wn` → `8.4u`, `lp` → `2.4u`, which are parameters, not nets —
the identical mechanism, hijacking, and harmless there only because `lvnot.sch` has no net named
`m`/`wn`/`lp`.

An "is this an LCC instance" test was considered and is **not available**: nothing reachable at
`hilight.c:2629` distinguishes an LCC level from a plain subcircuit level. `hier_attr[].prop_ptr` is
just the instance property string in both cases, `.templ` exists for both, and `.symname` is always
`NULL` on `xctx->hier_attr` (written only in `load_sym_def`'s local `lcc` array, `save.c:5279`).

## Reachability (measured, sweep of every committed `.sch`/`.sym`, `.claude/worktrees` excluded)

Corpus 881 `.sch` + 3447 `.sym`; 24797 instance records, of which only ~1525 have a child schematic
at all. Strict sweep — *a parent instance carrying an attribute whose name is a net inside that
instance's own child schematic*:

- **932 hits** (404 after de-mirroring `xschem_library` / `xschem_libs_newsym` /
  `xschem_libraries_oa`, which are three copies of the same rom8k + ngspice designs).
- All 932 use only **four** attribute names: `VCCPIN`, `VSSPIN`, `VCCBPIN`, `VSSBPIN`.
- **926 are declared bindings** — the child symbol's `extra=` names them. These are the feature.
- **6 are not**: an instance sets `VSSBPIN=VSS` on `lvnor2` (`xschem_library/rom8k/rom2_predec1.sch:92`,
  `rom2_predec3.sch`, + their mirrored copies) while `lvnor2.sym` declares only `VCCPIN VSSPIN`, and
  `lvnor2.sch:29,33` really are wires labelled `VSSBPIN`. `.subckt lvnor2 y a b VCCPIN VSSPIN` has
  no `VSSBPIN` port, so those wires are local nets. Verified at runtime, descended into `x9[15]`:
  `resolved_net VSSBPIN` → `VSS` (wrong; `x9[15].VSSBPIN` is right, and `net1` in the same schematic
  correctly returned `x9[15].net1`).
- **Zero accidental collisions** — no committed design has a child net named `value`, `m`, `model`,
  `spice_ignore`, `w`, `l`, … Near misses exist (`m` is a net in 4 schematics and an attribute on
  3050 instances, but those cells are never instantiated).

Loose upper bound, ignoring the parent/child relation: **15** names that can actually fire
(`C COUT CTRL L1 VCC VCCBPIN VCCPIN VM VNN VSSBPIN VSSPIN gnd in m outp` — three further raw
matches, `IN`/`data`/`result`, occur only as valueless bare tokens, which `get_tok_value` cannot
return), across 4700 valued attribute occurrences. 3050 of those 4700 (65%) are `m` alone, and `m`
is a net only in `diode_1.sch`, which is never instantiated anywhere in the corpus — so the largest
near miss cannot meet its net. A denylist was rejected on these numbers: 516 distinct attribute
names vs 1328 distinct net names.

**Problem 2 is not reachable from any committed design**: of 68016 non-empty instance attribute
values, exactly 7 start with `#`, all of them the same disabled `xxxspiceprefix=#D#`, none colliding
with a child net. It also turned out not to be a defect at all — see the Correction below.

## Fix

`src/hilight.c`. New static `attr_is_extra_node(extra, name)` — an **exact whitespace-token** match
(deliberately not the `strstr()` the netlister uses internally, so a net named `EXTRA` cannot be let
through by an `EXTRANET` entry). The loop now does

```c
if(!attr_is_extra_node(xctx->hier_attr[level - 1].sym_extra, resolved_net)) break;
ptr = get_tok_value(xctx->hier_attr[level - 1].prop_ptr, resolved_net, 0);
if(ptr && ptr[0]) {
  my_strdup2(_ALLOC_ID_, &resolved_net, ptr);   /* value taken VERBATIM -- see below */
  ...
```

`sym_extra` was already captured next to `prop_ptr` at **all four** write sites (`actions.c:3585`,
`save.c:5592`, `spice_netlist.c:477`, `spectre_netlist.c:363`) and, before this fix, was read
nowhere — the only other reference is a commented-out line at `token.c:2973`.

`break` (rather than `level--`) is the right exit: it is the same exit the "attribute not found"
arm already took, and it leaves `level` for the portmap loop that follows.

**`extra=` is the complete declaration channel.** Swept every symbol whose `format=` references a
single-`@` token that is also a net name in its schematic and is neither a pin nor in `extra=`:
**0 hits**. (`@@X` is a *pin* reference and resolves through the portmap, untouched by this gate.)

## Correction — Problem 2 was not a defect, and the strip shipped here was reverted

The fix as first committed (75da344e) also stripped a leading `#` off the accepted attribute
value, on the issue doc's premise that "nothing downstream strips it … so the trace is simply not
found, silently". **That premise is false for this path.** Measured, ngspice-42, one deck:

```
V1 topn 0 1
X1 topn #hfoo c      <- an extra= value reaches the CALL LINE verbatim, '#' and all
R9 hfoo  0    1k     <- a wire LABELLED #hfoo netlists as plain hfoo

   hfoo    0.0V      <- the label's node
   #hfoo   1.0V      <- the binding's node        TWO DISTINCT, UNCONNECTED NODES
```

So the child's port really is on node `#hfoo`. Stripping did not clean up a name — it named a
*different* node, and because `get_raw_index()` never strips `#` either, it would have resolved
to that wrong node rather than failing loudly.

The portmap path strips (`actions.c:3594-3599`) for a reason that does not transfer: a net passed
through a *pin* as `#net1` really is `net1` everywhere downstream. Each path must follow its own
path's netlist. The strip was reverted; legs AS1b/AS13/AS18 pin the verbatim behaviour, with AS1b
reading the `#` back out of the generated call line so the justification is in the fixture, not
just in this doc.

(xschem's own netlister is internally inconsistent here — the label path strips and the extra path
does not, so one spelling yields two nodes. That is an upstream issue, not one this fix creates,
and resolved_net's job is to report what the netlist actually did.)

## Verification

- **RED first**: the test failed 12 legs / passed 21 before the fix, on a binary rebuilt from
  `git checkout HEAD -- src/hilight.c` (trap 12 — not a stash). 33/33 after, in both the `--nogui`
  and the `--pipe`+`DISPLAY` arm.
- **Sabotage matrix, both directions**, each patch pattern-asserted in python (trap 4):
  revert the gate → 10 legs fail; gate always refuses → 9 fail; `strstr` instead of exact match →
  2 fail; and, after the Correction, **re-adding** the `#` strip → 2 fail (AS13, AS18).
  **No half of the fix is toothless.**
- **Netlist-neutral**: 201 stock designs netlisted with the true pre-fix and the fixed binary are
  byte-identical apart from the output directory baked into one `.include` path.
- Adjacent suites green: 0155 (12), 0156 (23), 0157 (19), 0158 (21), 0159 (22), 0160 (16), 0161 (21),
  `test_ase_unnamed_net` (28), `test_ase_core` (66), `test_ase_final` (28), `test_ase_final_gf180`
  (33), the 58-file wireedit suite, and the 752-job netlisting regression (which has no gold, so the
  netlist diff above is the real check).

## Left undone — see issue 0164

`resolved_net` reads only `prop_ptr`; the netlister falls back to the symbol **template** when the
instance omits the attribute (`token.c:3247`), and `hier_attr[].templ` is captured for exactly that.
No committed design hits it, so it was split out rather than folded in.

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
