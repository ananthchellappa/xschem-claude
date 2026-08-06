# 0224 — `bus_tap`'s `verilog_format`/`vhdl_format` are unreachable, and every label symbol's `format=` is dead

Status: **OPEN** — measured, two independent fixes drafted, neither urgent.
Area: `src/verilog_netlist.c:52`, `src/vhdl_netlist.c:77` (skip predicate); `xschem_library/devices/bus_tap.sym:26-27`; the `format="*.alias @lab"` line in six label symbols
Tests: none yet — proposed `tests/headless/test_backend_skip_divergence_0224.tcl`; fixture `xschem_library/examples/test_bus_tap.sch` already exists
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: no prior issue. `doc/claude/suggestions/next_session_prompt_0180.md:45` already warns the `IS_PIN` / `IS_LABEL_OR_PIN` / `IS_LABEL_SH_OR_PIN` macros differ. **Do not conflate with 0181**, which quotes `IS_LABEL_OR_PIN` for a different purpose.

## The divergence

The five backends use two different skip predicates:

```c
src/spice_netlist.c:211      if( type && !IS_LABEL_OR_PIN(type) ) {
src/spectre_netlist.c:98     if( type && !IS_LABEL_OR_PIN(type) ) {
src/tedax_netlist.c:50       if( type && !IS_LABEL_OR_PIN(type) ) {

src/verilog_netlist.c:51-56  if( type &&
                                ( !IS_LABEL_SH_OR_PIN(type) && … ))
src/vhdl_netlist.c:76-86     if( type &&
                                ( !IS_LABEL_SH_OR_PIN(type) && … ))
```

```c
src/xschem.h:578-582
#define IS_LABEL_SH_OR_PIN(type) (!(strcmp(type,"label") && strcmp(type,"ipin") && strcmp(type,"opin") && \
      strcmp(type,"scope") && strcmp(type,"show_label") && strcmp(type,"iopin") && strcmp(type,"bus_tap")))
#define IS_LABEL_OR_PIN(type) (!(strcmp(type,"label") && strcmp(type,"ipin") && \
                                 strcmp(type,"opin") && strcmp(type,"iopin")))
#define IS_PIN(type) (!(strcmp(type,"ipin") && strcmp(type,"opin") && strcmp(type,"iopin")))
```

They differ on exactly three types: `scope`, `show_label`, `bus_tap`.

### Corrections to the naive reading

Two things that look like defects and are not — record them so nobody "fixes" them:

- **`IS_PIN` is not a redundant third macro.** It is a genuinely different concept
  (hierarchy ports only) used deliberately in the spice/spectre/tEDAx first pass to emit
  `*.ipin` / `*.opin` / PININFO lines. It must stay narrow.
- **`src/netlist.c:1460` `if(strcmp(type,"label"))` is not a fourth skip test.** It sits
  *inside* the `IS_LABEL_OR_PIN` branch and discriminates a pure net-name label from a
  hierarchy port (label → read `global=`; port → read `dir=` off `rect[PINLAYER][0]`).
  Unifying it would be wrong.

So the real statement is: **two overlapping macros for one concept, differing on three
types, of which only one is observable.**

## What is actually observable

Reaching the emit loop is necessary but not sufficient — `print_spice_element` /
`print_spectre_element` / `print_verilog_primitive` all `return 0` when the symbol has no
format attribute:

```c
src/token.c:2481-2487
  if ((name==NULL) || (format==NULL)) {
    …
    return 0; /* do no netlist unwanted insts(no format) */
  }
```

Of the three differing types, only `bus_tap.sym` ships format strings. `scope.sym`,
`scope2.sym`, `scope_ammeter.sym`, `lab_show.sym` and `bus_connect_nolab.sym` carry no
`format=` at all, so they emit nothing in *any* backend and the divergence is **latent**
for them — it would surface only for a user-authored `show_label`/`scope` symbol that adds
a `format=`.

| type | spice | spectre | tEDAx | verilog | vhdl |
|---|---|---|---|---|---|
| `label` | skipped | skipped | skipped | skipped | skipped |
| `ipin`/`opin`/`iopin` | reached (IS_PIN loop) | reached | reached | skipped (ports come from the module port list) | skipped (entity port list) |
| `scope` | reached, no output | reached, no output | reached, no output | skipped | skipped |
| `show_label` | reached, no output | reached, no output | reached, no output | skipped | skipped |
| **`bus_tap`** | **emits `* tap:`** | no output (separate cause) | **emits `# tap:`** | **never emitted** | **never emitted** |

## Measured

```sh
mkdir -p /tmp/nlout && cat > /tmp/nl.tcl <<'EOF'
set netlist_dir /tmp/nlout
xschem load /home/analog/dev/xschem-claude/xschem_library/examples/test_bus_tap.sch
foreach f {spice verilog vhdl spectre tedax} { xschem set netlist_type $f; xschem netlist }
EOF
./src/xschem --nogui --pipe -q --script /tmp/nl.tcl
```

`grep -c "tap:"`:

```
test_bus_tap.spice   19    e.g.  "* tap: DATA[15:0] --> DATA[3]"
test_bus_tap.tdx     19    e.g.  " # tap: DATA[15:0] --> DATA[3]"
test_bus_tap.v        0    <-- expected "// tap: …"  (bus_tap.sym:26)
test_bus_tap.vhdl     0    <-- expected "-- tap: …"  (bus_tap.sym:27)
test_bus_tap.spectre  0    <-- separate cause, below
```

## Defect A — `bus_tap` is dead config in verilog/vhdl

```
xschem_library/devices/bus_tap.sym:23-28
K {type=bus_tap
template="name=l1 lab=[0]"
format="* tap: @#1:net_name --> @#0:net_name"
verilog_format="// tap: @#1:net_name --> @#0:net_name"
vhdl_format="-- tap: @#1:net_name --> @#0:net_name"
tedax_format="# tap: @#1:net_name --> @#0:net_name"}
```

The machinery to honour those two strings exists and is wired up —
`print_verilog_element` dispatches to `print_verilog_primitive` the moment
`verilog_format` is non-empty (`src/token.c:3915-3918`), and `print_vhdl_element` does the
same (`:1522-1534`). `IS_LABEL_SH_OR_PIN` in the two emit loops makes them unreachable.

The "a Verilog netlist should not instantiate a bus tap" defence does **not** apply: the
values are *comments*, not instantiations, exactly as spice and tEDAx already emit. So it
is a bug — but a small one: lost comments plus two dead attributes in one library symbol,
nothing that changes simulation results.

**Spectre is a separate, smaller inconsistency.** It reaches `bus_tap` (same narrow macro
as spice) and prints nothing, because `print_spectre_element` sets
`fmt_attr="spectre_format"` and its fallback to plain `format` is gated behind
`strcmp(fmt_attr, "spectre_format")` (`src/token.c:2856-2860`), which is 0 in a normal
spectre run.

## Defect B — every label symbol's `format=` is dead

```
xschem_library/devices/lab_wire.sym:23-25
K {type=label
format="*.alias @lab"
template="name=p1 sig_type=std_logic lab=xxx"
```

All five predicates contain `strcmp(type,"label")`, so `print_spice_element` is never
called for a label instance. The only other call sites are the `netlist_commands` loops
(`spice_netlist.c:333, 399, 562, 568`) and the `IS_PIN` loop (`:202`), none of which can
see a label; `spice_block_netlist`'s `format` check (`:639`) is gated by
`strcmp(xctx->sym[i].type,"subcircuit")==0` (`:480`).

Confirmed on the same run: `test_bus_tap.sch` has 31 `lab_pin`/`lab_wire`/`gnd`
instances, `grep -c alias` on the `.spice` and `.tdx` returns **0**, while `*.opin LDQ`
and `*.ipin LDCP` *are* present (`test_bus_tap.spice:125-126`) — the pin symbols' format
strings are live, the label ones are dead.

Affected: `lab_wire.sym:24`, `lab_pin.sym:24`, `lab_generic.sym:23`, `bus_connect.sym:24`,
`gnd.sym:26`, `vdd.sym:26`.

## Fixes

**A1 (preferred, lowest risk)** — accept current behaviour, delete the dead config so the
symbol stops lying: remove `bus_tap.sym:26-27`, and the same two lines in the three
mirrored copies (`xschem_libraries_oa/devices/bus_tap/symbol/bus_tap.sym`,
`xschem_libs_newsym/devices/bus_tap/symbol/bus_tap.sym`,
`tests/test_sweep_diff/devices/bus_tap/symbol/bus_tap.sym`).

**A2 (honour the intent)** — let `bus_tap` through **only** when it actually has a format
for that language. Without the guard, `print_verilog_element`'s fallback emits a bogus
structural `bus_tap l1 ( .tap(…), .bus(…) );`, which is a real regression.

```c
src/verilog_netlist.c:51-56, replace
    if( type &&
       ( !IS_LABEL_SH_OR_PIN(type) &&
with
    if( type &&
       ( (!IS_LABEL_SH_OR_PIN(type) ||
          (!strcmp(type, "bus_tap") &&
           get_tok_value(xctx->sym[xctx->inst[i].ptr].prop_ptr, "verilog_format", 0)[0])) &&
```

`src/vhdl_netlist.c:76-77`, same edit with `"vhdl_format"`. **Do not widen to
`scope`/`show_label`** — they have no format and would fall through to structural
instantiation. Pick A1 *or* A2, not both.

**A3 (spectre, if wanted)** — one line in the `.sym`, not in C:
`spectre_format="// tap: @#1:net_name --> @#0:net_name"`. The C-side fallback at
`token.c:2856-2860` is deliberately gated; do not touch it.

**B** — delete the `format=` line from the six label symbols, or leave them and just
document the dead attribute. The code needs no change either way.

## Risks

- **A2** changes generated Verilog/VHDL for every design containing bus taps. `tests/` has
  no committed gold for the netlisting case (CLAUDE.md), so nothing in-tree breaks, but
  downstream users diffing netlists see new comment lines.
- **A2 asymmetry**: instance-level `verilog_format=` overrides are read from
  `inst[i].prop_ptr` before the symbol (`token.c:3904-3913`), but the proposed guard
  inspects only the *symbol* prop_ptr — an instance supplying `verilog_format` on a
  `bus_tap` whose symbol lacks it would still be skipped. Acceptable; worth a comment.
- **A1 / B** touch shipped library files users may have copied into their own PDK trees.
  Keep the four `bus_tap.sym` copies and six label `.sym` files consistent, or a later
  grep-based audit re-flags them. `gf180mcuD/` and `xschem_libs_newsym/` in this tree carry
  their own symbol copies.
- **Never edit the macro itself.** `IS_LABEL_SH_OR_PIN` has ~25 other call sites
  (`hilight.c`, `draw.c`, `select.c`, `save.c`, `psprint.c`, `callback.c`, `scheduler.c`)
  where the wide membership is correct; changing the definition would silently break net
  highlighting, label-text drawing and selection. **Edit the two call sites.**
- `skip_instance()` / `skip_instance2()` (`netlist.c:1202-1228`) already filter per-format
  `*_IGNORE` / `*_SHORT` attributes ahead of every one of these loops and are unaffected.
