# 1613 — `instcheck()` dereferences a symbol index in three initialisers, then guards the same value five times

**STAMP:** `v1 claim=open tree=16e28b7f stamped=2026-09-27 fix=untried open=2 by=driver`

Found by the issue 1611 crew while answering a different question. **Latent, and the reason it is
worth fixing anyway is that the function contradicts itself inside its own body.**

## The defect

`instcheck()` in `src/netlist.c` opens with declaration initialisers that dereference
`xctx->sym[inst[n].ptr]` **three times**:

```c
int rects = xctx->sym[inst[n].ptr].rects[PINLAYER];
...
int bus_tap = xctx->sym[inst[n].ptr].type &&
              !strcmp(xctx->sym[inst[n].ptr].type, "bus_tap");
int k = inst[n].ptr;
```

and then, a few lines later, tests that same value **five times** before using it:

```c
if( xctx->netlist_type == CAD_VERILOG_NETLIST &&
     ((inst[n].flags & VERILOG_IGNORE) ||
     (k >= 0 && (sym[k].flags & VERILOG_IGNORE))) ) return 0;
```

— once per netlist back end. **So the function's own later code states that `ptr` may be
negative, while its initialisers assume it cannot be.** One of the two is wrong, and only the
guarded half can be right: `k >= 0` is dead weight if `ptr` is always non-negative.

⚠ **Declaration initialisers run before every early return in the function**, which issue 1603
already had to write a comment about at this exact site. So the three dereferences cannot be
avoided by any guard placed after them.

## Reachability, and why it is not an argument for leaving it

**Not reachable today**, established by the 1611 crew and not re-derived here:
`match_symbol()` in `src/token.c` is documented as *"never returns -1, if symbol not found load
systemlib/missing.sym"*, so a broken symbol yields a valid placeholder index with
`rects[PINLAYER] == 0`; `link_symbols_to_instances()` dereferences `xctx->sym[inst[i].ptr]`
unguarded immediately after assigning it; and `ptr == -1` exists only inside windows no user
action can interrupt (`load_inst()` before its link, after `remove_symbols()` before the paired
link, paste allocation). This site has a second barrier: it is reached only via
`instpin_spatial_table`, whose sole writer `hash_inst_pin()` has one caller, the guarded
`reset_node_data_and_rehash()`.

Sibling sites in the same class, also unguarded: `name_attached_inst_to_net()` and
`name_attached_inst()` in `src/netlist.c`, and `break_wires_at_pins()` in `src/check.c` — while
`break_wires_at_attach_points()`, in the same file, guards the identical expression.

## Open

1. **The fix must not change behaviour.** Returning early on `k < 0` would *skip* the five
   back-end checks, which today proceed with `k < 0` treated as "not ignored". Preserving that
   means computing `k` first and making `rects` and `bus_tap` take their `k < 0` values (`0` and
   false) rather than bailing out. The reorder is legal C89 — an initialiser may reference a
   variable declared earlier in the same block.
2. **Whether the sibling sites are worth the same treatment, or whether the honest fix is one
   assertion at the top of the class.** Four unguarded sites and one guarded one in the same two
   files is the sort of inconsistency that invites a future reader to "fix" it in whichever
   direction they meet first. ⚠ Per issue 1611's own lesson — two sibling loops there needed
   *opposite* index spellings and a pattern fix would have broken one — do not resolve this
   family by pattern.
