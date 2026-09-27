# 1611 — the VHDL component loop tests the PARENT symbol, so `xschem_libs` is honoured at the top level and silently dropped one level down

**STAMP:** `v1 claim=open tree=cee5945b stamped=2026-09-27 fix=untried open=3 by=driver`

## The defect

`vhdl_block_netlist(FILE *fd, int i, int alert)` in `src/vhdl_netlist.c` takes the block being
expanded as **`i`**. Inside it, the component-declaration loop walks the candidate components as
**`j`**:

```c
for(j=0;j<xctx->symbols; ++j)
{
  const char *default_schematic;
  if( strboolcmp(get_tok_value(xctx->sym[j].prop_ptr,"vhdl_primitive",0),"true")==0 ) continue;
  default_schematic = get_tok_value(xctx->sym[i].prop_ptr, "default_schematic", 0);   /* <-- i */
  if(!strcmp(default_schematic, "ignore")) continue;
  ...
  my_strdup2(_ALLOC_ID_, &abs_path, abs_sym_path(xctx->sym[i].name, ""));             /* <-- i */
  if(( strcmp(xctx->sym[j].type,"subcircuit")==0 || … ) && check_lib(1, abs_path)
```

**Sixteen accesses in that loop; fourteen use `j` and two use `i`.** Both `type` tests, the
`vhdl_primitive` test, the instance-name comparison and all five `rect[PINLAYER][k]` accesses use
`j`. The two above read the **parent block's** symbol while claiming to filter the **candidate
component**.

Both are symbol-index-for-symbol-index, so **neither can leave the array**: this is a logic
defect, not a memory defect.

## What each one costs

1. **`check_lib(1, abs_path)` on the parent's path.** `check_lib` is what makes `xschem_libs` —
   documented as the list of libraries **not** to netlist or export — actually exclude something.
   Because the path handed to it is the parent's, and the parent has already passed the identical
   test in the caller, the test **always passes** here. So an exclusion is honoured at the top
   level, where `vhdl_netlist()`'s own component loop spells the same access with `j`, and
   silently ignored one level down.

   **Driven** on a three-level fixture (`top` → `mid` → `leaf`) so that parent ≠ candidate:
   with `xschem_libs` set to exclude the leaf's directory, the top-level architecture's component
   list **moves** and the mid-level architecture's is **byte-identical** to the unexcluded control.
   The excluded `leaf` is declared *and instantiated* inside `arch_mid`, with `grep -c 'entity
   leaf'` = 0 — i.e. the netlist references an entity it never emits.

2. **`default_schematic` on the parent's property.** `vhdl_block_netlist()` already tests the
   parent's `default_schematic` near its top and `return`s early, so the in-loop copy is
   **provably dead code** — it can only ever re-read a value that has just been checked.
   Consequently `default_schematic=ignore` on a **component** has no effect: driven, `component
   dsi` is declared although `dsi.sym` carries the attribute, and stripping the attribute gives a
   `diff`-identical component section.

## Why this is a typo and not a design choice — the tree's own history

* `dfef332f` — the site read `check_lib(abs_sym_path(xctx->sym[j].name, ""))`, with **`j`**.
* `f251918a` — *"fix usage of `xschem_libs`, list of libraries/schematics NOT to netlist /
  export"* — hoisted that call into `abs_path` at **three** sites and mistyped **two** of them.
* `242523cb` — titled literally **"typo fix"** — repaired one of the two, in
  `global_vhdl_netlist()`'s descent loop, where the symbol index genuinely *is* `i`:
  `-my_strdup(1242, &abs_path, abs_sym_path(xctx->sym[j].name, ""));`
  `+my_strdup(1242, &abs_path, abs_sym_path(xctx->sym[i].name, ""));`
* The other has been `[i]` ever since, and is still `[i]` at `cee5945b`.

So a commit whose whole purpose was making `xschem_libs` work introduced the defect that stops it
working below the top level, and the follow-up titled "typo fix" fixed the sibling and missed this
one. ⚠ Note the two loops need **opposite** answers — `i` is right in the descent loop and `j` is
right here — which is exactly why the repair caught one and not the other, and why a fix must not
be applied by pattern.

## Scope

* **The two suspected loops named in this project's earlier notes are CLEAN.** The suspicion
  pointed at `vhdl_netlist()`'s and `global_vhdl_netlist()`'s two-index regions, which use
  opposite naming conventions from one another; both are internally consistent. That half is
  **refuted**. The real defect is in the third such region, which the suspicion did not name.
* **No sibling back end has a component-declaration loop** — it is VHDL-only — so the peer for
  comparison is this file's own top-level component loop, which spells the same accesses with `j`.

## Open

1. **The fix changes emitted netlists** for any design using `xschem_libs` below the top level or
   `default_schematic=ignore` on a component. That is the documented behaviour being restored
   rather than a new behaviour, so it is a defect fix and not a ruling — but it wants a regression
   row, not just a patch, and the row has to be a three-level fixture or it measures nothing.
2. A **separate, non-index** defect fell out of the same fixture and is recorded here rather than
   chased: in this loop the `found` test compares `xctx->sym[j].name` against
   `xctx->inst[l].name`, and the synthetic symbol `get_additional_symbols()` creates for an
   instance-level `schematic=` override does not carry the instance's name, so it never matches —
   a `schematic=dsi_alt` instance is emitted as `xd1 : dsi_alt` with **no `component dsi_alt`
   declared anywhere**. Needs its own number.
3. **Not driven, and labelled so:** that the emitted file is *rejected* by a VHDL analyser. There
   is no `ghdl` or `nvc` on this machine, so "the netlist is invalid VHDL" is a derivation here;
   what is driven is that it names an entity it does not emit.
