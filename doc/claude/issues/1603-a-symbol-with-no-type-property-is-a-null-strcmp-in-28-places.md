# 1603 — a symbol with no `type=` property is a NULL `strcmp` in 28 places, one of them measured

**STAMP:** `v1 claim=open tree=d9f45e8f stamped=2026-09-22 fix=untried open=3 by=driver`

**Status: OPEN — filed 2026-09-22** by the driver, from a crash the headless-crashes
batch's Map crew found, recorded and explicitly declined as out of its class.
**Class** NULL dereference on an optional symbol property, in the netlisters and the
printers.
**Related:** **1492** and **1493** (the display-crash class this was found beside and is
*not* a member of — it is not a `display` dereference, and no `has_x` guard touches it).
Receipt: `doc/claude/headless_crashes_batch/receipts/A-map.md` §3, item 5.

---

## The one that is MEASURED

Cited from the Map receipt, which drove it:

> `xschem hier_psprint` on a loaded schematic segfaults headless at `psprint.c:1070` in
> `ps_draw_symbol()` (`strcmp` on a NULL). **Out of this item's class and NOT diagnosed.**
> Its arm comparison is inconclusive: with `has_x == 1` the same call had not returned
> after 120 s.

READ at `d9f45e8f`, the statement is the `pdfmarks` branch of `ps_draw_symbol()`:

```c
/* pdfmarks, only if doing hierarchy print and if symbol has a subcircuit */
if(what != 7) {
  char fname[PATH_MAX];
  if(!strcmp(xctx->sym[xctx->inst[n].ptr].type, "subcircuit")) {
```

`xSymbol.type` is **optional**, and its absence is represented as `NULL`, not as `""`.

## Why NULL is a reachable state — READ, not inferred

Two independent places set it and neither substitutes an empty string:

* `src/save.c`, symbol load: `symbol[symbols].type = NULL;` in the per-symbol
  initialisation block, alongside `prop_ptr`, `templ`, `parent_prop_ptr`, `base_name` and
  `name`. It is filled afterwards **only if the symbol file carries a `type=` property**.
  A symbol without one keeps the NULL.
* `src/actions.c`, `copy_symbol()`: `dest_sym->type = NULL;` then
  `my_strdup2(_ALLOC_ID_, &dest_sym->type, src_sym->type)`.

So "a symbol with no `type=`" is an ordinary, supported thing to have in a library, and
every unguarded `strcmp` on that field is a segfault waiting for one.

## The family — 45 sites, 17 guard, 28 do not

Swept at `d9f45e8f` over `src/*.c` for `strcmp` whose argument is a `.type` or `->type`
field, then each site classified by whether a NULL test guards it within two preceding
lines:

| | count |
|---|---|
| sites total | **45** |
| guarded (`sym->type && !strcmp(...)` or equivalent) | **17** |
| **unguarded** | **28** |

The 28, by name:

```
draw.c:1042          editprop.c:1348      netlist.c:1030       netlist.c:1354
psprint.c:1070       scheduler.c:12009    scheduler.c:12010    scheduler.c:12011
spectre_netlist.c:251  spectre_netlist.c:270  spectre_netlist.c:388
spice_netlist.c:96   spice_netlist.c:399  spice_netlist.c:418  spice_netlist.c:567
tedax_netlist.c:184  tedax_netlist.c:234
token.c:1227         token.c:4998         token.c:5577
verilog_netlist.c:353
vhdl_netlist.c:45    vhdl_netlist.c:330   vhdl_netlist.c:331   vhdl_netlist.c:442
vhdl_netlist.c:582   vhdl_netlist.c:591   vhdl_netlist.c:662
```

**The split is the evidence.** Seventeen sites in this tree already write
`xctx->sym[i].type && !strcmp(...)` — `actions.c:3840`, `actions.c:3922`,
`netlist.c:1984`, `move.c:2726` (`if(!sym->type || strcmp(sym->type, "label"))`) and
thirteen more. The guard is not a new idea anyone has to be persuaded of; it is the
house style at 38% of the call sites and missing at the other 62%.

⚠ **What that sweep is and is not.** It is a two-line-context pattern match, so:
a site guarded further up the function reads as unguarded here, and a site where `type`
is provably non-NULL by construction reads as a defect when it is not. **28 is the
candidate list, not the defect count.** Exactly **one** — `psprint.c:1070` — has been
driven to a segfault. Line numbers are at `d9f45e8f` and must be re-grepped before being
quoted again.

## Why this is worth more than one `if`

Line numbers cluster in the **netlisters**: `spice_netlist.c` ×4, `vhdl_netlist.c` ×7,
`spectre_netlist.c` ×3, `tedax_netlist.c` ×2, `verilog_netlist.c` ×1, `netlist.c` ×2 —
19 of the 28. Netlisting is the operation this program exists to perform, it runs
headless in every batch flow, and a segfault there takes the whole process with it. The
Map crew found this one by driving *every* `xschem` subcommand with no display; nobody
had driven `hier_psprint` on a loaded schematic before.

## Still open

1. **Reproduce `psprint.c:1070` from a named fixture** — a symbol with no `type=`
   property, a schematic instancing it, and `xschem hier_psprint`. The Map crew's repro
   is in a deleted scratch clone; the finding survives, the fixture does not.
2. **Triage the other 27.** For each, either prove `type` cannot be NULL there or add the
   house-style guard. The netlister cluster first, for the reason above.
3. **Decide what a NULL `type` should MEAN at each site**, which is the part that is not
   mechanical. `move.c:2726` reads `if(!sym->type || strcmp(sym->type, "label")) return -1;`
   — a typeless symbol is *not* a label. But at `psprint.c:1070` the question is whether a
   typeless symbol should get a PDF link, and at `netlist.c:1030` whether it is a port.
   A blanket `type ? type : ""` would answer all 28 at once and would be wrong wherever
   the absence means something other than "not that type".

## What this is NOT

Not a display defect. It was found during a display-crash sweep and the receipt says
plainly it is out of that class: it crashes on a NULL string field, no `has_x` guard
touches it, and `psprint.c:333` — the one genuine `display` dereference in this file — is
a different site, excluded from this build because `HAS_LIBJPEG` is off.
