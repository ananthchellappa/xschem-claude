# 0165 — one `#`-leading name becomes TWO nodes in the netlist, depending on how it arrived

Status: **OPEN** — awaiting decisions D1-D4 (see "Not yet decided").
Area: the netlist emission sites that pass a name through verbatim, vs the ones that strip `#`.
Tests: **not "none"** — `tests/headless/test_resolved_net_attr_scope_0163.tcl` (AS1b, AS13, AS18)
and `tests/headless/test_resolved_net_templ_fallback_0164.tcl` (TF2, TF3, TF4, TF11, TF18, TF19)
already assert the CURRENT, unstripped behaviour. See "What a fix would redden".
Found: while fixing 0164, measuring what `resolved_net` must match (issue 0163's Correction)
Related: 0163 (the strip that was reverted because of this), 0158, 0156 (the `#`-reserved policy),
**0179** (a tEDAx segfault found while measuring this issue's D3)

> **Revision 2026-07-30.** The first version of this file was written from code reading plus one
> SPICE measurement. Everything below has now been re-measured on the built binary at `7791a85e`
> (ngspice-42, all five backends). Seven claims in revision 1 were wrong; the two that mattered are
> flagged **[WAS WRONG]** in place rather than deleted, because the wrong version is quoted in
> `src/hilight.c:2704-2717`, in 0163's test header comment, and in `next_session_prompt_0165.md`.

## In plain English

`#` is xschem's private marker for an auto-named net. Most netlist paths strip it, so a net the
engine called `#net1` reaches the simulator as `net1`. Issue 0156 ratified that a user may
nonetheless *write* `#foo` as an ordinary name, and 0158 measured that such a label netlists as
plain `foo`.

But several emission sites pass the name through **verbatim**. The one 0165 was opened for is an
`extra=` binding — a "hidden pin" whose connection is passed as an instance attribute
(`doc/xschem_man/symbol_property_syntax.html:284-305`). Its value is written onto the subcircuit
call line untouched. So the same spelling produces two different nodes.

MEASURED, ngspice-42, one deck:

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

## [WAS WRONG] "The node is unreachable by any other means"

Revision 1 said the binding's node was reachable by nothing else, so the failure mode was a silent
floating supply. **That is false, and the true shape is worse.** MEASURED at `7791a85e`, with
`top_is_subckt` (or `lvs_netlist`) set and the top cell's `ipin` labelled `#hfoo`:

```
.subckt h0165_top #hfoo          <- the PORT keeps the '#' (spice_netlist.c:375, from inst[n].lab)
*.PININFO #hfoo:I
V1 topn GND 1
X1 topn #hfoo h0165_child        <- the extra= binding lands on the SAME node
R9 hfoo GND 1k                   <- the wire drawn ON THAT VERY PIN becomes `hfoo`
.ends
```

The formal port and the binding **are the same node**; it is driven by whoever instantiates the
deck. What is orphaned is the *wire the user drew on that pin*. So the defect is not "a binding
creates an unreachable node" — it is "**a pin's port name and the pin's own wire have been split
into two nodes, and the drawn wire is the one that loses**".

Only the narrower sentence survives: there is no way to draw a *wire* that lands on `#hfoo`, because
every wire/instance connection goes through `net_name()` (`src/token.c:4016-4041`), which strips —
all 28 netlisting call sites pass `hash_prefix_unnamed_net=0`.

## Where the two paths diverge

- **Wire / instance-connection side, STRIPS.** `net_name()`, `src/token.c:4035/4037` (`+1` on the
  name). Plus `set_lab_or_pin_inst_attr()` attribute back-fill, `src/netlist.c:956`:
  ```c
  if(node[0] == '#') {
    node++;
  }
  ```
  and the VHDL/Verilog signal declarations `src/node_hash.c:290`, `:302`, `:351`, `:362`, the
  portmap `src/actions.c:3594-3599`, and the `.save` emitter `src/hilight.c:4203`/`:4207`/`:4291`.
- **`extra=` binding side, does NOT strip.** `print_spice_element()`, `src/token.c:2347`; the
  generic `@token` branch is `:2585-2674`, resolution `:2616-2642`, `value = val` at `:2646`, and
  the verbatim write is `my_mstrcat(_ALLOC_ID_, &result, value, NULL)` at **`:2671`**. No `#` test
  anywhere on that path. `result` reaches the file at `:2714`.

`src/netlist.c:775-787` documents the surrounding policy and is worth reading first: a bare
`name[0]=='#'` test does **not** mean "auto-named", which is why `is_auto_net_name()` (`:788-794`)
exists and why output-strip sites were deliberately left loose (0156).

### [WAS WRONG] `src/node_hash.c:132` is not a strip

Revision 1 listed it as "the same idiom" as `netlist.c:956`. It is the **opposite**: `:132` is
`if(token[0] == '#')` in `bus_node_hash_lookup()`, whose then-branch (`:134`) `my_strdup`s the token
**verbatim, keeping the `#`**, and whose else-branch (`:139`) is the only call to `expandlabel()`.
The hash table stores the name *with* its `#` — and, because `expandlabel()` is skipped, a
`#foo[3:0]` is stored as one literal entry instead of four bus elements.

### The site inventory is much wider than one binding

The verbatim-emission sites are not one; they are at least fifteen, in five backends. Grouped by
what the leaked name came from:

| origin | sites |
|---|---|
| top-level `.subckt`/`module`/`entity` port list, from `xctx->inst[n].lab` | `spice_netlist.c:375`, `spectre_netlist.c:261-263`, `verilog_netlist.c:170/184/198` + decls `:227-229/:246-248/:265-267`, `vhdl_netlist.c:244/261/278` |
| LVS `*.PININFO` card, raw `inst[i].lab` | `spice_netlist.c:200`, `spectre_netlist.c:86` |
| child port list, from the symbol pin `name` attribute | `token.c:2098-2100` (`print_spice_subckt_nodes`), `token.c:2259-2261` (`print_spectre_subckt_nodes`), `verilog_netlist.c:525` + decls `:560-564`, `vhdl_netlist.c:603-604`, `token.c:1872-1877` (tEDAx) |
| `@@pinname` / `@#n` single-pin forms | `token.c:2114`, `:2125-2127`, `:2275`, `:2286-2288` |
| attribute bindings | `token.c:2671` (SPICE/spectre `extra=`), `token.c:3943` + `verilog_netlist.c:582-586` (`verilog_extra`), `token.c:3251` (tEDAx `extra=`) |
| the Tcl surface | `node_hash.c:404-405` (`xschem list_nets`) |

A symbol pin `name=#pfoo` is therefore enough on its own — no `extra=` needed. MEASURED:

```
.subckt p0165_child A #pfoo
*.iopin #pfoo
R1 A pfoo 1k              <- port `#pfoo`, body `pfoo`: the port dangles INSIDE the child
.ends
```

Provenance for calling these "label-derived": `src/make_sym.awk:271/282/293/304` copy a schematic
pin's `lab=` verbatim into the symbol's pin `name=`.

## Two post-processing stages the netlister does not control

1. **`src/spice.awk` / `src/spectre.awk` rewrite the emitted deck** (dispatched at
   `src/xschem.tcl:2249-2266` and `:2268-2274`). `spice.awk:206-211` rewrites `##name` → `name` and
   `#pfx#name` → `pfxname`. **A single leading `#` matches neither pattern and survives** —
   measured. If D1 says "strip", it must say *where*: C emission, or this awk stage.
2. **`spectre.awk`'s `q()` (`:289-299`) quotes anything containing a character outside
   `[a-zA-Z0-9_$]`**, so spectre's leaked name comes out single-quoted. Two early returns matter:
   `if(s ~/.+=.+/)` (`:292`) means a `HN=@HN`-style binding is **not** quoted, and
   `if(s ~ /^[()=]$/)` (`:293`) is what keeps the call-line parens intact.

`q()` also produces a genuinely malformed line when the leaked name is the last field of a header:
`subckt t0165_top ( '#hfoo)'` — the closing paren was swallowed into the quoted string. MEASURED.

### `hash_prefix_unnamed_net` is not a user-facing knob

`net_name()`'s fifth parameter (`src/token.c:3961`, branch `:4028`, emission `:4030/:4032`) does
emit the `#`. But it is a **fixed call argument**, not a preference: `1` is passed at exactly two
sites, `src/hilight.c:1471` and `:1504`, both inside `drill_hilight()`. Every netlisting caller
passes `0`. No strip decision has to account for it.

## Why `resolved_net` was NOT the place to fix it

Issue 0163 originally shipped a `#` strip on the accepted attribute value and it was **reverted**
(`a5a08bc8`) once the above was measured. `resolved_net`'s contract is to name the node the
simulator actually has. Given a binding `HN=#hfoo`, that node *is* `#hfoo`; stripping named `hfoo`,
a different node the child's port is not connected to. `get_raw_index()` never strips `#` either, so
the strip would have silently resolved to the wrong node instead of failing.

That decision stands regardless of how 0165 is resolved — but if the netlister is changed to strip,
`resolved_net` must be revisited in the same change so the two stay in agreement (D4).

## How reachable

**Zero committed designs.** Re-measured 2026-07-30 with `git ls-files`-restricted greps (revision 1
measured the *working tree*, which is why it said 7 where the index has 6 — the 7th was an untracked
`tests/create_save/results/` artifact):

```sh
git ls-files '*.sch' '*.sym' | xargs grep -ho 'lab=#[^ }"]*'          | wc -l   # 4785
git ls-files '*.sch' '*.sym' | xargs grep -l  'lab=#'                 | wc -l   # 404
git ls-files '*.sch' '*.sym' | xargs grep -ho 'lab=#[^ }"]*' | sort -u \
  | grep -vE '^lab=#net[0-9]+$'                                                 # prints NOTHING
git ls-files '*.sch' '*.sym' | xargs grep -hoE '\b[A-Za-z_][A-Za-z0-9_]*="?#[^ }"]*' \
  | grep -v '^lab=' | sort | uniq -c    # 8 tedax_format, 6 xxxspiceprefix="#D#", 7 format="#...
git ls-files '*.sym' '*.sch' | xargs grep -hoE 'name=#[^ }"]*'                  # prints NOTHING
```

**The fact that should drive D1:**

- **Every one of the 4785 committed `lab=#…` records is `#net<digits>`.** No committed design
  contains a *user-authored* `#foo` label.
- **Zero** committed `extra=` bindings have a `#`-leading value. Zero committed symbol pins are
  named `#…`.
- The 6 `xxxspiceprefix="#D#"` are a *disabled* attribute (`xxx` prefix) on three mirror pairs of
  `voltage_protection.sch:73` / `pcb_voltage_protection.sch:80`. The 8 `tedax_format="#…` and 7
  `format="#…` are format strings using `#` as a tEDAx comment marker or the `#pfx#name` awk idiom,
  not node names.
- Revision 1's denominator "68016 non-empty instance attribute values" is not reproducible and its
  population is undefined. A defensible one: `499231` `key=value` tokens across all committed
  `.sch`/`.sym`, of which `4799` begin with `#`.

Consequently **the existing `netlist.c:1491` warning fires on zero stock designs, and any new
warning would too.** Option 3 is provably output-neutral and transcript-neutral on the shipped
libraries. Option 1 (strip) is the only one that needs a stock-design netlist diff.

## What a fix would redden

Revision 1's "Tests: none yet" was wrong. Which legs move depends on **which site** is touched:

| touched site | reddens |
|---|---|
| netlister (`token.c:2671` / the emission sites) | 0163 AS1b; 0164 TF2, TF3, TF4 (these three are **exact-string** comparisons against a generated `.spice` call line, so the whole line changes) |
| `resolved_net` binding side (`src/hilight.c`, after the comment at `:2705`) | 0163 AS13, AS18; 0164 TF11, TF18, TF19 |
| the `resolved_net` INPUT strip (`src/hilight.c:2673`) going strict, if D2 = strict | additionally 0158 HS8, HS10, HS11, HS14, HS15 and 0163 AS12 |

0163 AS14 (lone `#` → `#`) and AS15 survive both shapes on the table — AS15 has no `#` in it at all
(its label "exactly one '#' comes off" is stale text from before the `a5a08bc8` revert; the
assertion is identical to AS8). AS14 would only redden under an *unconditional*
`if(ptr[0]=='#') ++ptr;`, which 0158 HS12/HS13 already forbid.

Two assertions run the other way and a netlister-side strip only strengthens them:
`test_hash_label_crash_0156.tcl` N1 (no `#foo` in the deck for a label-sourced net) and
`test_ase_unnamed_net.tcl` AN13 (no `#net` in the deck). The committed `gold/` netlists contain no
`#` outside `* expanding symbol: … # of pins=N` header comments, so the gold-diff side is clean.

Both test files are picked up automatically by `full_audit.sh` (`ls test_*.tcl`), so nothing can
slip past. Baseline measured 2026-07-30, `--nogui`: 0163 34/34, 0164 23/23, 0157 19/19, 0158 21/21,
0156 23/23.

## Which backends — all MEASURED at `7791a85e` (revision 1 had only SPICE)

One fixture: symbol `extra="HN"`, `format="@name @pinlist @HN @symname"`, instance `HN=#hfoo`, plus
a wire labelled `#hfoo`.

| backend | emitted | verdict |
|---|---|---|
| SPICE | `X1 topn #hfoo h0165_child` vs `R9 hfoo GND 1k` | **affected**; ngspice-42 makes two nodes |
| Spectre | `X1 ( topn '#hfoo' ) h0165_child` vs `R9 ( hfoo GND )` | **affected**; additionally single-quoted by `spectre.awk`'s `q()` |
| Verilog | `h0165_child X1 ( topn , #hfoo );` vs `wire hfoo ;` | **affected**; and `#` is Verilog's delay operator, so the output is a **syntax error**, not a silent extra node. No `q()` exists on this path |
| VHDL | `generic map ( HN => #hfoo )` | extra tokens become **generics, not nodes** — no node divergence, but the generic is a VHDL syntax error |
| tEDAx | `conn #hfoo X1 9` vs the pin side's `conn topn X1 1` (which goes through `net_name()`) | **affected** — see below |

### [WAS WRONG] tEDAx is not exempt, and it crashes

Revision 1 said the tEDAx `conn` emission "is unreachable for subcircuits". Wrong twice over.

1. `if(!subcircuit)` at `src/token.c:3208` is **always true**. `subcircuit` is `int subcircuit = 0;`
   at `:3137` and is assigned only at `:3169`, inside `if(!format && !strcmp(type,"subcircuit"))`
   at `:3159`; the early `return` at `:3198-3206` (`if(name==NULL || !format || !format[0])`) fires
   whenever `!format`. So anything reaching `:3208` has a non-empty `tedax_format` and
   `subcircuit == 0`. (There is a second always-true `if(!subcircuit)` at `:3451`; if one goes, both
   must.) The real gate on `conn` lines is `tedax_format`, and it applies to every element type.
2. The extra-side `conn` field at `:3251` is a raw `get_tok_value` — no `translate`, no
   `expandlabel`, no `#` handling — while the pin-side field at `:3220` is
   `net_name(inst,i,&multip,0,1)`. Same divergence as SPICE. MEASURED: `conn #hfoo X1 9`.
3. **A `type=subcircuit` symbol with `tedax_format` and `extra=` but no `extra_pinnumber=` segfaults
   the tEDAx netlister.** `extra_pinnumber` is `NULL`, so `my_strtok_r(NULL, …, &saveptr1)` runs with
   `saveptr1` uninitialised (`token.c:3129`, `:3234`) and `util.c:168` dereferences garbage.
   Reproduced minimally; filed and FIXED as **0179** (`tests/headless/test_tedax_extra_pinnumber_0179.tcl`).
   Adding `extra_pinnumber="9"` or removing `extra=` both made it survive.

Reach: 1366 files under `xschem_library/` carry `tedax_format`, 529 of those also carry `extra=`;
but **zero** stock symbols pair `type=subcircuit` with `tedax_format`, which is why neither the dead
branch nor the crash has ever been seen.

## Not yet decided

1. **D1 — strip on the binding side, or warn and leave output alone?** Stripping makes the paths
   agree. **But it CHANGES NETLIST OUTPUT** — unlike 0163 and 0164, which were verified
   byte-identical over stock designs. Note that no such harness is committed today: neither 0163 nor
   0164 recorded the design set, and `tests/netlisting.tcl` walks `../xschem_library` and finds 189
   `.sch`. A strip needs that harness rebuilt as a committed script.
2. **D2 — strict or loose?** `is_auto_net_name()` (`#net<digits>`, issue 0156) versus any leading
   `#`. They disagree exactly on the user-authored `#foo`, which is the measured case. The label
   path is loose; the existing `netlist.c:1491-1492` warning is **loose AND NOT strict**
   (`node[0][0]=='#' && !is_auto_net_name(...)`), i.e. it targets precisely `#foo`.
3. **Or warn instead of rewrite?** Note `print_erc` is **not a function** — it is a local `int` gate
   declared at `src/netlist.c:1414` and assigned at `:1426`
   (`(xctx->netlist_count == 0 || startlevel < xctx->currsch) && for_netlist`), gating three warning
   sites inside `name_nodes_of_pins_labels_and_propagate()`. The third of those, `:1491`, is the
   `#`-reserved warning — and **it already fires on the label half of this exact trap and is silent
   on the binding half.** MEASURED on the fixture above:
   `Warning: instance: lH: net name '#hfoo' starts with '#', which is reserved for auto-named nets`.
   It cannot be widened in place: it sits behind an `IS_LABEL_OR_PIN` gate reading `inst[i].node[0]`,
   a slot an `extra=` binding never occupies. Option 3 is therefore "add a second check that reuses
   this one's gate and style", not "loosen this condition" — still much cheaper than option 1.
4. **Which backends?** SPICE, Spectre, Verilog and tEDAx all diverge; VHDL makes generics, not
   nodes. A fix in one and not the others is a new inconsistency.

## Reproduce

Raw ngspice, no xschem:

```
V1 topn 0 1
X1 topn #hfoo c
R9 hfoo 0 1k
.subckt c A HN
R1 A HN 1k
.ends
.op
.end
```

`ngspice -b` reports `hfoo 0.0V`, `#hfoo 1.0V`, `topn 1.0V`.

In xschem: a symbol with `extra="HN"`, `format="@name @pinlist @HN @symname"`, an instance carrying
`HN=#hfoo`, and a wire labelled `#hfoo`. Netlist it: the call line carries `#hfoo`, the wire becomes
`hfoo`. Set `top_is_subckt 1` and make that wire's label an `ipin` instead to get the collision in
"[WAS WRONG] The node is unreachable" above. Give the symbol a pin `name=#pfoo` for the
port-vs-body split with no `extra=` involved at all.
