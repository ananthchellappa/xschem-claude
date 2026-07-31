# 0181 — a pin symbol with no `PINLAYER` rect NULL-derefs in `prepare_netlist_structs()`

Status: **FIXED** — measured repro, measured fix, regression test.
Area: `src/netlist.c` `name_nodes_of_pins_labels_and_propagate()`
Tests: `tests/headless/test_list_nets_null_token_0180.tcl` leg **NN0**
Found: 2026-07-30, while trying to settle issue 0180's reachability
Related: **0180** — this crash is what made 0180 look unreachable

## The crash

A symbol whose `type=` is `ipin`, `opin` or `iopin` but which carries **no `PINLAYER`
(layer 5) rect** segfaults the moment anything runs `prepare_netlist_structs(1)` on a
schematic that instantiates it — `xschem netlist`, `xschem list_nets`, ERC, hierarchy
traversal.

```c
src/netlist.c:1457
    if(type && inst[i].node && IS_LABEL_OR_PIN(type) ) { /* instance must have a pin! */
      port=0;
      my_strdup2(_ALLOC_ID_, &dir, "");
      if(strcmp(type,"label")) {          /* instance is a port (not a label) */
        port=1;
        if(for_netlist)
          my_strdup2(_ALLOC_ID_, &dir,
              get_tok_value(xctx->sym[inst[i].ptr].rect[PINLAYER][0].prop_ptr, "dir",0));
                                        /* ^^^^^^^^^^^^^^^^^^^^^^ NULL when rects[PINLAYER]==0 */
      }
```

The comment on `:1457` — *"instance must have a pin!"* — states the assumption the code
then fails to check. `inst[i].node` does **not** mean "this symbol has a pin rect":

```c
src/netlist.c:1636  rects = (inst[i].ptr+ xctx->sym)->rects[PINLAYER] +
                            (inst[i].ptr+ xctx->sym)->rects[GENERICLAYER];
src/netlist.c:1638  if(rects > 0)
src/netlist.c:1640    inst[i].node = my_malloc(_ALLOC_ID_, sizeof(char *) * rects);
```

`reset_node_data_and_rehash()` allocates the node array when **PINLAYER + GENERICLAYER**
is non-zero. A symbol with zero pin rects and one **generic** rect (layer 3) therefore
has a node array, passes the `:1457` guard, and reaches an unconditional
`rect[PINLAYER][0]` on a NULL array.

## Measured

Fixture: `type=ipin`, no `B 5` rect, one `B 3` rect, instance `lab=` empty.

```
$ ./src/xschem --nogui --pipe -q --nolog --script <load fixture; xschem list_nets>
FATAL: signal 11
while editing: top_g_ipin
```

gdb on the shipped (optimised) binary:

```
Thread 1 "xschem" received signal SIGSEGV, Segmentation fault.
#0  prepare_netlist_structs.part ()
#1  list_nets ()
#2  xschem_cmds_l.constprop ()
```

Line pinned by a discriminator rather than by a debug build: the same 0-pin/1-generic
symbol declared `type=label` **survives**, because a label takes the `else` branch at
`:1467` and never reaches `:1465`; `type=probe` survives because it is not
`IS_LABEL_OR_PIN` at all. Only the pin types crash.

| symbol `type=` | 0 PINLAYER + 1 GENERICLAYER rect |
|---|---|
| `ipin` / `opin` / `iopin` | **SIGSEGV** |
| `label` | survives (skips `:1463-1465`) |
| `probe` | survives (fails `IS_LABEL_OR_PIN`) |

## Fix

```c
        if(for_netlist && xctx->sym[inst[i].ptr].rects[PINLAYER] > 0)
          my_strdup2(_ALLOC_ID_, &dir,
              get_tok_value(xctx->sym[inst[i].ptr].rect[PINLAYER][0].prop_ptr, "dir",0));
```

`dir` is already `""` from the `my_strdup2` at `:1459`, which is exactly what a pin with
no pin rect should report, so the guard needs no else-branch.

**Behaviour-neutral by construction**: the guard changes the code path only when
`rects[PINLAYER] == 0`, and every such design crashed before. Confirmed empirically by
`tests/netlist_diff/netlist_diff.sh` over the shipped libraries — see the 0180 doc for
the run.

## The sibling that was left alone

`set_lab_or_pin_inst_attr()` has the same unguarded index:

```c
src/netlist.c:970-971
        my_strdup2(_ALLOC_ID_, &dir,
              get_tok_value(xctx->sym[xctx->inst[i].ptr].rect[PINLAYER][0].prop_ptr, "dir",0));
```

It was **not** changed, because every path into it goes through `set_inst_node(i, j, …)`
with `j` a **PINLAYER pin index** — `name_unlabeled_instances()` (`:1611`) iterates
`j < rects[PINLAYER]`, and the bus-tap and pass-through callers (`:1352`, `:1383`) index
real pins. Reaching it therefore already implies `rects[PINLAYER] > 0`. If that ever
stops being true, this is the second site to guard, and the fix is identical.

## Why this mattered beyond the crash

The same fixture is the **only** shape known to reach issue 0180's NULL-token
truncation. Five earlier constructions failed to reproduce 0180 and it was filed as
"mechanism measured, reachability not demonstrated". They failed because this segfault
sits in front of it: fix 0181 and 0180 fires immediately, returning the literal string
`{` from `xschem list_nets`. See `doc/claude/issues/0180-list-nets-null-token-truncates-tcl-list.md`.
