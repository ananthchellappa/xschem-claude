# 0156 — a `#`-leading net name crashes the binary (two unguarded `node_mult` accesses)

Status: **FIXED** (2026-07-26)
Area: `src/netlist.c` (`get_unnamed_node`, `set_inst_node`, `name_nodes_of_pins_labels_and_propagate`),
`src/node_hash.c`, `src/xschem.h`, `src/xschem.tcl` (`addlabel::name_ok`)
Tests: `tests/headless/test_hash_label_crash_0156.tcl` — `HA*`/`HB*`/`S*`/`E*`/`C*` (21 checks, new file)
Related: 0154 (the audit that surfaced it — "Not fixed" item 5), 0155
Policy decision: net names are **not** restricted to `[a-zA-Z_]`; only `#` is reserved. See
"Why not a charset rule" below.

## Report

From the 0154 backlog:

> a .sch with one unlabeled wire and TWO `devices/lab_wire` instances both carrying `lab=#foo`,
> then `xschem nets` → `FATAL: signal 11`.

Reproduced, with the same backtrace as reported:

```
#0  set_inst_node ()
#1  name_attached_inst_to_net ()
#2  wirecheck ()
#3  name_attached_nets ()
#4  prepare_netlist_structs.part ()
#5  xschem_cmds_n.constprop ()
```

But the reported shape was **too narrow in one direction and too wide in another**, and the
difference decides the fix.

## What actually crashes

Measured matrix (`xschem nets`, both arms):

| fixture | result |
|---|---|
| `#foo` + `#foo` on **one** wire | **signal 11** |
| `#foo` + `#bar` on one wire | **signal 11** |
| **`#net1` + `#net2`** on one wire | **signal 11** |
| `#` , `#1` , `#fo` , `#net` (×2, one wire) | **signal 11** |
| `#foo` + `foo` on one wire | **signal 11** |
| `foo` + `#foo` on one wire | survives |
| `#foo` + `#foo` on **separate** wires | survives |
| any single label | survives |
| `foo` + `bar` | survives |

The invariant is **not** "a malformed `#` name". It is: *a wire whose established net name begins
with `#`, carrying a second label*. The first label wins, so `foo` + `#foo` is safe while
`#foo` + `foo` is not — and the engine's own well-formed `#net1` + `#net2` crashes just as hard.

**Crash A — NULL deref.** `set_inst_node` (`netlist.c`) ran for *any* `node[0]=='#'`:

```c
  if(node[0] == '#') { /* update multilicity of unnamed node */
    expandlabel(get_tok_value(rect[j].prop_ptr, "name", 0), &pin_mult);
    get_unnamed_node(2, pin_mult * inst_mult, atoi((inst[i].node[j]) + 4));
```

and `get_unnamed_node`'s `what==2` did `xctx->node_mult[node]` with no NULL check. `node_mult` is
**unconditionally NULL at that point**: `prepare_netlist_structs` frees it via
`get_unnamed_node(0,0,0)` at its start and only refills it in `name_unlabeled_nets()`, which runs
*after* `name_nodes_of_pins_labels_and_propagate()`. Adding an unrelated auto-named net to the
fixture does **not** rescue it — that is the observation that proves NULL deref rather than a
merely out-of-range index.

**Crash B — out-of-bounds read.** Independent, and found while mapping A. A single well-formed
`lab=#net99999999` kills **VHDL and Verilog** netlisting: `node_hash.c` (twice) does
`get_unnamed_node(3, 0, atoi(tok+4))` for the signal-declaration multiplicity, indexing
`node_mult[99999999]` far past `node_mult_size`. `xschem netlist` in `vhdl` or `verilog` mode →
`FATAL: signal 11`. SPICE mode does not reach this path.

**And the blind `+4`.** `atoi(name + 4)` assumes the literal `#net` prefix. `#foo` is exactly 4
chars so `+4` lands on the NUL, but a shorter name (`#fo`) reads *past* the buffer, and `#12345`
silently yields `45` — retuning an unrelated node's multiplicity with no symptom at all.

## Fix — four parts

1. **`get_unnamed_node`: NULL + range guard for `what>=2`** (`netlist.c`). This is *the* crash fix.
   Returns `0`, which is already the "unknown multiplicity" answer — an in-range but never-assigned
   entry reads 0 too (the array is zeroed on growth) and every caller treats `mult<=1` as scalar.
2. **`is_auto_net_name()`** — strictly `#net` followed by ≥1 digit; declared in `xschem.h`. Applied
   at the three `atoi(name + 4)` sites (`netlist.c` `set_inst_node`, `node_hash.c` ×2), so a name
   that carries no index can never produce one.
3. **ERC warning** in `name_nodes_of_pins_labels_and_propagate`, `print_erc`-gated and in the same
   `statusmsg(str,2)` + `inst[i].color = -PINLAYER` style as the sibling checks in that loop:
   `net name '#foo' starts with '#', which is reserved for auto-named nets`.
4. **`addlabel::name_ok` refuses a leading `#`** (`xschem.tcl`) — the only label validator that
   exists today. Entry-point only: **existing files keep loading**, which is mandatory (see below).

**The guard and the strictness are complementary, not redundant** — the sabotage matrix proves it:

| sabotage | caught by |
|---|---|
| drop the NULL/range guard | `HA-c`, `HB-vhdl`, `HB-verilog`, `HB-huge` — the **strictly well-formed** names only |
| loosen `is_auto_net_name` to any leading `#` | `E1` |
| revert the `name_ok` rejection | `S1`, `S2` |

With strictness in place, `#foo` never enters the branch, so the guard is not what saves it; with
the guard in place, `#net1`+`#net2` and `#net99999999` are legal-but-huge indices that only the
guard catches. Removing either one reopens a crash.

## Why not a charset rule

The proposal on the table was to require net names to start with `[a-zA-Z_]`. Measured against the
corpus — **30,770** `lab=` records across `xschem_library/`, `xschem_libs_newsym/`,
`xschem_libraries_oa/`, `gf180mcuD/`, `sky130A/`, `tests/`:

| leading char | count | what it is |
|---|---|---|
| `[a-zA-Z]` | 24,314 (78.9%) | ordinary names |
| `#` | 4,756 (15.5%) | engine auto-names, **committed to disk** |
| `[0-9]` | 1,424 (4.6%) | SPICE ground `lab=0` ×1397, `3V3OUT`, `4*LDX[3:0]` |
| `+` / `-` | 97 | supply nets `+5V`, `-5V`, `-12V` |
| `~` | 11 | inverted signals `~B`, `~Y_NAND` |
| `%` | 6 | probes `%vd(TEST_V VREF)` |
| `_` | **0** | unused |

The rule would reject ~6,267 committed names (20%) — including every SPICE ground — while the one
character it adds is used by nobody. It also fights the lexer: `parselabel.l` deliberately admits
`-a-zA-Z_%$~"+#!/\<>` as label start characters.

So the policy is the narrow one: **`#` is reserved for the engine; everything else the lexer
accepts stays legal.** Existing `#`-leading names are treated as ordinary user names (decision (a)
of the design call) and reported by ERC (decision (c)) — never rewritten, never refused at load.

## Verification

- `tests/headless/test_hash_label_crash_0156.tcl` — 21 checks. **RED on 11 of 18** before the fix
  (the `E*` legs were added after). Crash legs run the binary as a **subprocess** (`exec`), so a
  regression is a failed leg rather than a dead test file.
- Sabotage-verified three ways, table above; restored green with no markers left.
- Regression, all green: `test_add_wire_label`, `test_sch_add_pin`, `test_add_pin_lib_symbol_view`
  (the `name_ok` consumers), `test_ase_unnamed_net` (28), `test_ase_interact` (63), `test_ase_plot`
  (145), `test_wire_split`, `test_fluid_rotate_body_route_0130`,
  `test_fluid_bodyshove_guards_0132`, `test_prep_result_contamination_0155` (12), the `--nogui`
  trio `test_ase_core` (66) / `test_ase_final` (28) / `test_ase_final_gf180` (33), and
  `sh tests/headless/test_flylines.sh` (A6 unchanged — `C1` is the in-file mirror).

## Not verified / deliberately not done

- **The other `#` sites were left LOOSE.** The sweep classified 27 sites; only the three that feed
  `atoi(name+4)` were converted. Left alone on purpose:
  - `flyline.c` / `callback.c` — rule A6 excludes *any* `#` net by design.
  - the OUTPUT-STRIP sites (`hilight.c` ×7, `node_hash.c` ×4, `netlist.c:917`) — cosmetic, correct
    for any `#` name.
  - **`move.c` `fluid_wire_explicit_lab` (~2945) and the H2 doom guard (~3196)** use
    `lab[0] != '#'` to decide a label is user-authored and must be protected. A user-typed `#foo`
    is therefore still read as regenerable by the fluid-editing passes. That is a **real
    remaining defect** — it can drop a user's label during a reshape — but it is a behavior change
    in the fluid hot path and belongs in its own issue with the fluid suites as the gate. Not
    fixed here. → **FIXED, issue 0162** (both swapped to `is_auto_net_name()`). It was worse than
    "drops a label": `fluid_wire_explicit_lab` is the universal named-copper decline for 12 call
    sites, so every de-shorter could reshape a `#foo` net. The H2 half turned out to have no
    observable behavior at all — see 0162 for the sweep that established that.
- **No test tooth for the strictness at `set_inst_node` specifically.** `E1`/`E2` pin the
  *predicate*; the sabotage that loosens it is caught there, but I could not construct a fixture
  that observes the multiplicity corruption (`atoi("#12345"+4) == 45`) end to end.
- No GUI eyeball of the ERC warning in the info window; only the `infowindow_text` read-back.
- Windows build not compiled.
