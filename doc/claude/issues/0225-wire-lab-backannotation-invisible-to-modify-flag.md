# 0225 — netlist/highlight back-annotates `lab=` into wire records without setting modified, and `#netN` renumbers on every topology change

Status: **OPEN** — measured repro, fix drafted, not implemented. Unchanged by
`wire_label_ride.md` S1/S2, but **strictly rarer as of S2** (2026-08-06) and worth recording why:
`trim_wires`' in-place collinear merge keeps `wire[i]`'s `prop_ptr` with **no comparison**
(`check.c`, the merge branch), so when two halves weld, a diverged `lab=` on one of them is
dropped — this issue's class. S1 made that newly *reachable* at a net label (the kissing stub that
used to block the degree-2 merge was removed, spec §14.8); S2 removes the label split outright, so
there are no halves to diverge at a label and the only remaining way in is a **device**-pin
boundary. Concretely, the one file spec §12.3 found keeping a label-pin split on disk
(`xschem_library/pcb/pcb_test1.sch`, `lab_wire lab=A` at `(700,-460)` — one half `{}`, the other
`{lab=A}`, so `merge_collinear_wires`' byte-equal-`prop_ptr` gate refused the weld) can no longer
reach that state through a label. **Do not fold this into that spec** — it is an independent writer
bug in `netlist.c` and the fix below is unchanged.
Area: `src/netlist.c` `wirecheck()` (`:1093`), `name_attached_nets()` (`:1117`), `set_unnamed_net()` (`:1584-1588`); `set_modify(-2)` at `:1765`
Tests: none yet — proposed `tests/headless/test_wire_lab_backannot_0225.tcl`
Found: 2026-08-05, while grounding `doc/claude/code_analysis/net_label_model_instance_vs_wire_attached.md`
Related: **0226** — the other document-mutating path in this area (`auto_set_wire_bus` in `draw()`). No prior issue covers wire `lab=` back-annotation.

## The defect

`prepare_netlist_structs()` writes resolved net names into every wire's `prop_ptr` as a
`lab=` token. Nothing in that path sets the modified flag, and nothing reverts it. So:

- the user highlights one net — a read-only-looking action — and the in-memory document
  silently diverges from disk;
- `xschem get modified` stays 0, the title bar shows no `*`;
- a later, unrelated save ships a large diff of wire records the user never touched;
- the auto-generated `#netN` names in that diff **renumber** whenever wire order changes.

```c
src/netlist.c:1093    my_strdup(_ALLOC_ID_, &wire[n].prop_ptr, subst_token(wire[n].prop_ptr, "lab", wire[n].node));
src/netlist.c:1117    my_strdup(_ALLOC_ID_, &wire[n].prop_ptr, subst_token(wire[n].prop_ptr, "lab", wire[n].node));

src/netlist.c:1584-1588
static int set_unnamed_net(int i)
{
  …
  my_snprintf(tmp_str, S(tmp_str), "#net%d", get_unnamed_node(1,0,0));
  my_strdup(_ALLOC_ID_, &xctx->wire[i].node, tmp_str);
  my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr, subst_token(xctx->wire[i].prop_ptr, "lab", tmp_str));
```

The only `set_modify` in the path is

```c
src/netlist.c:1765  set_modify(-2); /* to reset floater cached values */
```

and per the mod-code table at `src/actions.c:162-170`, `-2` only resets floater caches and
recolours the simulation buttons. `delete_netlist_structs()` frees `wire[i].node`
(`:1831`) but never reverts `prop_ptr`, so the mutation is permanent for the session, and
`save.c:5847` writes `wire[n].prop_ptr` verbatim.

The `#netN` counter is a plain monotonic allocator consumed in wire-array order, and the
committed value is **never read back** — `reset_node_data_and_rehash()` (`:1654`) seeds
nothing from `prop_ptr`:

```c
src/netlist.c:808-816
  else if(what==1) { /* get a new unique unnamed node */
    do {
      ++xctx->new_node;
      my_snprintf(tmp_str, S(tmp_str), "net%d", xctx->new_node);
    } while (bus_node_hash_lookup(tmp_str, "", XLOOKUP, 0, "", "", "", "")!=NULL);
```

## Measured

No preference needed, no netlisting needed.

1. Copy `xschem_library/examples/cmos_example.sch` and delete the `lab=` token from every
   `N …` record (simulating a schematic authored or converted without wire
   back-annotation).
2. `xschem load /tmp/t.sch` ; `xschem hilight_netname VCC` — in the GUI, just click a net
   to highlight it.
   → `xschem get modified` = **0**. No `*` in the title. The user believes nothing changed.
3. `xschem saveas /tmp/after.sch`
   → **39 wire records changed** — `lab=VCC`, `lab=GN`, `lab=S`, … plus `lab=#net1` and
   `lab=#net2`. Expected: an identical file, since no edit was performed.
4. Insert one extra unnamed wire ahead of the others (`N 2000 -2000 2100 -2000 {}` as the
   first `N` record), reload, netlist, save.
   → the new wire takes `lab=#net1`, and the two pre-existing records flip
   `lab=#net1`→`lab=#net2` and `lab=#net2`→`lab=#net3`.

In a git repo, a one-wire edit therefore ships a renumbering diff across every auto-named
net in the sheet. On a large sheet with hundreds of unnamed nets, that buries the real
change.

## Nuance that keeps this honest

The shipped `xschem_library/` `.sch` files **already** carry `lab=` on their wires,
including auto-named ones on some sheets — this back-annotation has historically been
committed to disk. On an already-annotated, topologically unchanged file the diff is
empty. The noise appears exactly when wire topology changed, or when the file was authored
without wire `lab=` (script-generated, converted, or hand-written).

## Fix

Stop committing *auto-generated* names to disk; keep the stable ones. `wire[].node`
already carries the value at runtime, and `prop_ptr` `lab=` is never read back by the
netlister, so the auto names buy nothing on disk.

`src/netlist.c:1586-1588`, in `set_unnamed_net()`, drop the prop_ptr write:

```c
  my_snprintf(tmp_str, S(tmp_str), "#net%d", get_unnamed_node(1,0,0));
  my_strdup(_ALLOC_ID_, &xctx->wire[i].node, tmp_str);
  /* do NOT write auto names into prop_ptr: they renumber on every topology change and
   * would ship as a spurious save diff (there is no set_modify here).
   * See doc/claude/issues/0225-*.md */
```

`src/netlist.c:1093` and `:1117`, guard the propagated write the same way:

```c
      if(wire[n].node[0] != '#')
        my_strdup(_ALLOC_ID_, &wire[n].prop_ptr, subst_token(wire[n].prop_ptr, "lab", wire[n].node));
```

`src/netlist.c:780-782` already warns that `name[0]=='#'` is not a reliable "auto-named"
test for *incoming* user data; here it is safe, because the string was just minted by
`get_unnamed_node()` or propagated from one.

**Deliberately not recommended:** calling `set_modify(1)` from
`prepare_netlist_structs()`. That would make every net highlight dirty the buffer, fire
`write_backup()`, and pop the save-on-close prompt — worse UX than the disease.

## Risks

- The format change is subtractive-only for future saves, but any consumer reading wire
  `lab=` straight out of the file loses the `#netN` entries. Known readers: the generic
  search path `get_tok_value(xctx->wire[i].prop_ptr, tok, 0)` at `src/hilight.c:1244` (a
  user searching `lab` = `#net*` on wires would stop matching; route it to `wire[].node`),
  the `*.awk` import/convert utilities that grep `.sch` text, and any golden files.
- `grep -rn 'lab=#net' xschem_library/ tests/` before committing, and re-promote any
  golden that carries auto names. Re-run `tests/headless/` — several cases save and diff
  schematics.
- `prepare_netlist_structs()` is on the hot path for highlight, netlist, ERC
  (`check.c:673`), SVG export (`svgdraw.c:1246`) and flyline drawing (`flyline.c:175`).
  `flyline.c:190` documents relying on the `node[0]=='#'` marker — that marker lives on
  `wire[].node`, which this fix does not touch, so flylines are unaffected.
