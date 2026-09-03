# 1279 — `op_param_lists::apply` cannot reach a type the class map does not name

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `apply` yet.

The class map is an **override table** for `class` and `effective` — an
unmapped `type=` token is its own class, which `src/op_param_lists.tcl`'s own
header calls the design's key property, and spec §4.3's promise that *"a PDK
with a token nobody anticipated is a one-line user fix and not a tool release"*
rests on it. For `apply` it is a **gate** instead, and the promise fails there.

## The measurement (2026-09-03, `src/op_param_lists.tcl` md5 `bf023075`)

```tcl
op_annot::register widgetron [dict create params {{a a 0}} match {*wid*}]
op_param_lists::set_list class widgetron annotation {{zz zz 1}}
op_param_lists::apply              ;# no args
op_param_lists::apply widgetron    ;# named
```

```
UNMAPPED class=widgetron apply_noargs= gen 1->1 apply_named=widgetron gen->2
```

`class widgetron` correctly answers `widgetron` (the identity fallback), and the
user's list is correctly stored and correctly returned by `effective`. But
`apply` with no arguments returns **{}** and `::op_annot::gen` **does not move**
— so by invariant **I5** the change is stored, correct in Tcl, and **invisible
on screen**. Naming the type explicitly works.

The cause is one line in `apply`:

```tcl
set cands [array names classmap]        ;# <-- the shipped default map only
```

Every shipped-but-unmapped token inherits the gap. Measured present in this
tree and **absent from §4.3's map**: sky130 `varactor`, `npn`, `pnp`,
`pwell_resistor`, `p_diffusion_resistor`, `n_diffusion_resistor`,
`high_precision_p`; IHP `pnp`, `inductor`, `esd`; and `xschem_library`'s
arbitrary part numbers (`2N3906`, `4001`, `12SK7`).

## Why the suite did not see it

`test_op_param_store_1245.tcl` row **A1** exercises `apply` on `mos` only — a
class the shipped map names. Row **M2** proves the identity fallback for
unmapped tokens, but never applies one. The two halves are each green and the
seam between them is where the defect lives.

## Recommended fix

Make `apply`'s candidate set the **types the user owns a list for**, unioned
with the map, instead of the map alone. The store already knows them: every
`owned` key of scope `class` is a class name, and a class that is its own type
is exactly the identity case.

```tcl
set cands [array names classmap]
foreach k [array names owned] {
  if {[lindex $k 0] eq "class" && [lindex $k 2] eq "annotation"} {
    lappend cands [lindex $k 1]
  }
}
```

**Rejected: enumerating `::op_annot::desc`.** `src/op_param_lists.tcl` reaches
into no other namespace's internals on purpose, and there is no published
enumerator to reach for — that missing accessor is issue **1274**.

**Rejected: extending the shipped default map with the measured census.** A map
entry is a *claim* that two tokens share one list; `varactor` → capacitor and
`esd` → diode are groupings no ruling covers, and inventing them is the shape
ruling **D-4** forbids one level up. Item B2 rejected this deliberately and it
stays rejected — the fix is to stop `apply` gating on the map, not to grow the
map.

## Acceptance row this needs

* A2 — a type the map does not name, with an owned class list: bare `apply`
  re-registers it and `::op_annot::gen` **moves**.

## Who inherits this

**Item B5**, which calls `apply` after a Save. Until this is fixed, a user who
customises a device whose `type=` token nobody anticipated sees the list
accepted, the file written, and the schematic unchanged — the exact silent
failure invariant I5 exists to prevent.
