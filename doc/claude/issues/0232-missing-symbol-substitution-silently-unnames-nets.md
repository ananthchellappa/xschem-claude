# 0232 — a label symbol missing from the library path silently stops naming its net; no ERC fires

Status: **OPEN** — measured repro, fix drafted, not implemented.
Area: `src/netlist.c` `name_nodes_of_pins_labels_and_propagate()` ERC block (`:1450-1457`); `src/token.c` `match_symbol()` (`:201`); `src/save.c` `load_sym_def()` (`:4680-4683`)
Tests: none yet — proposed `tests/headless/test_missing_sym_erc_0232.tcl`
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0125** — documents that the same `missing.sym` substitution counts as a mutation (`set_modify(1)` + an undo slot). This issue is about the substitution's *netlist* semantics, not its undo side effect.

## The defect

A schematic that references a net-label symbol not on the library path still opens, still
draws, and still netlists — but the label stops naming its net, connect-by-name links
through it are broken, and **no ERC diagnostic fires**.

The chain:

```c
src/token.c:201
int match_symbol(const char *name)  /* never returns -1, if symbol not found load systemlib/missing.sym */

src/token.c:215-218
  if(!found) {
    dbg(1, "match_symbol(): matching symbol not found: loading %s\n", name);
    load_sym_def(name, NULL); /* append another symbol to the xctx->sym[] array */
  }

src/save.c:4680-4683
  if(lcc[level].fd==NULL) {
    if(recursion_counter == 1) dbg(0, "l_s_d(): Symbol not found: %s\n", transl_name);
    my_snprintf(sympath, S(sympath), "%s/%s", tclgetvar("XSCHEM_SHAREDIR"), "systemlib/missing.sym");
```

```
src/systemlib/missing.sym:1-3
G {type=missing
format="*  @name -  @symname  IS MISSING !!!!"
template="name=x1"}
```

The placeholder then fails the naming guard for **two independent reasons**:

```c
src/netlist.c:1457
    if(type && inst[i].node && IS_LABEL_OR_PIN(type) ) { /* instance must have a pin! */
```

- `"missing"` is not in `IS_LABEL_OR_PIN` (`src/xschem.h:580-581`), and
- `inst[i].node` is **NULL**, because `missing.sym` contains no `B` (rect) record at all,
  so `reset_node_data_and_rehash()` never allocates the node array:

```c
src/netlist.c:1666-1671
    rects=(inst[i].ptr+ xctx->sym)->rects[PINLAYER] +
          (inst[i].ptr+ xctx->sym)->rects[GENERICLAYER];
    if(rects > 0)
    {
      inst[i].node = my_malloc(_ALLOC_ID_, sizeof(char *) * rects);
```

**This is why widening the type test would not work**: the placeholder has no pin to hang
a node on. The correct remedy is a diagnostic, not an attempt to salvage the label.

And the existing ERC cannot catch it. The "no type attribute set" branch requires an
*empty* type:

```c
src/netlist.c:1450-1456
    if(print_erc && (!type || !type[0]) ) {
      my_snprintf(str, S(str), "Warning: Symbol: %s: no type attribute set", inst[i].name);
      statusmsg(str,2);
      inst[i].color = -PINLAYER;
      xctx->hilight_nets=1;
    }
```

`"missing"` is non-empty. The "no name attribute set" branch (`:1431-1447`) is equally
blocked, because `missing.sym`'s `template="name=x1"` makes the name token non-empty.

## Measured

`good2.sch` — connect-by-name across two disjoint wire segments:

```
N 0 0 100 0 {lab=xxx}
N 0 200 100 200 {lab=xxx}
C {devices/lab_pin.sym} 0 0 0 0 {name=p1 sig_type=std_logic lab=VDD_LOCAL}
C {devices/lab_pin.sym} 0 200 0 0 {name=p2 sig_type=std_logic lab=VDD_LOCAL}
C {devices/res.sym} 100 30 0 0 {name=R1 value=1k}
C {devices/res.sym} 100 230 0 0 {name=R2 value=1k}
```

`bad2.sch` is byte-identical except that the two label symbols are `mylib/my_lab.sym`,
not on the path — i.e. the real-world case of opening a schematic whose in-house label
library was never added to `XSCHEM_LIBRARY_PATH`.

```
good2.spice          bad2.spice
R1 VDD_LOCAL net1 1k    *  p1 -  my_lab  IS MISSING !!!!
R2 VDD_LOCAL net2 1k    *  p2 -  my_lab  IS MISSING !!!!
                        R1 net1 net3 1k
                        R2 net2 net4 1k
```

`R1` and `R2` are now on **different nets** — a real electrical disconnection handed to
the simulator.

## Not "completely silent" — be precise

Three diagnostics do exist, and an issue that says "silent" will be dismissed:

1. **stderr**: `l_s_d(): Symbol not found: mylib/my_lab.sym` (`save.c:4682`). It is
   `dbg(0, …)` and `debug_var` defaults to 0 (`globals.c:166` → `xinit.c:3354`), so it
   always prints — but to stderr, invisible if xschem was launched from a desktop menu.
2. **The netlist** carries `missing.sym`'s format string as a **comment**:
   `*  p1 -  my_lab  IS MISSING !!!!`. The simulator ignores it and runs the wrong netlist.
3. **The canvas** draws the `---MISSING SYMBOL---` box, which is visually loud.

What genuinely does not fire is the **ERC layer**: no `statusmsg()`, no
`inst[i].color = -PINLAYER`, no `xctx->hilight_nets=1`. So the accurate statement is
*loud in the terminal and on the canvas, silent in the ERC and in the simulator-facing
netlist.*

## Fix

Add an ERC branch for the placeholder, immediately after the existing "no type attribute
set" block — i.e. between `src/netlist.c:1456` `}` and `:1457`:

```c
    /* systemlib/missing.sym stands in for any symbol not found on the library path
     * (token.c match_symbol -> save.c load_sym_def). Its type is "missing", which is
     * non-empty, so the !type[0] check above never fires, and it has no rect[PINLAYER]
     * so inst[].node stays NULL -- a net label that resolves to it stops naming its net
     * with no ERC at all. Report it. See doc/claude/issues/0232-*.md */
    if(print_erc && type && !strcmp(type, "missing")) {
      char str[2048];
      my_snprintf(str, S(str), "ERROR: instance: %s: symbol %s not found on library path; "
                  "it is not netlisted and any lab=/pin it carries is lost",
                  inst[i].instname ? inst[i].instname : "<unnamed>", inst[i].name);
      statusmsg(str, 2);
      inst[i].color = -PINLAYER;
      xctx->hilight_nets = 1;
    }
```

This deliberately fires for **all** missing symbols, not just labels: the placeholder has
no pins, so a missing hierarchical block is equally destructive and the same block covers
it.

Orthogonal second half, evaluate separately: `save.c:4682` uses `dbg(0, …)`, which only
reaches stderr. A `statusmsg()` there would surface it in the GUI, but `load_sym_def` runs
before the status bar exists on some paths.

## Risks

- **ERC noise**: a work-in-progress schematic with 50 unresolved symbols gets 50 status
  lines and 50 highlighted instances. `print_erc` (`netlist.c:1426`) already restricts this
  to the first top-level `for_netlist` pass, so it will not double-print.
- `inst[i].color = -PINLAYER` + `xctx->hilight_nets=1` change on-screen appearance of
  missing instances after a netlist. Run `tests/headless/full_audit.sh` (press
  **Allow 30m** on the gate panel once, per CLAUDE.md) before landing.
- A user symbol legitimately declaring `type=missing` would start being flagged. None
  exists — `grep -r 'type=missing'` hits only `src/systemlib/missing.sym`.
- Other C reader of `type=="missing"`: `src/save.c:5589` blocks descend into a missing
  symbol. Untouched.
- `statusmsg(str,2)` under `--nogui` routes through Tcl; the neighbouring ERC blocks at
  `:1443` and `:1453` use the identical call, so no new headless-safety question.
