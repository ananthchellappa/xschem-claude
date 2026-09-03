# 1277 — the flavor glob wins by `lsort` order, not by narrowness, and it carries no class

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `op_param_lists::effective` yet.

This is **DD-2's override half** — *"a per-flavor entry is an optional override
that WINS when present"* — resolving by an accident of alphabetical order.

## What was claimed

Item B2's plan says the flavor arm resolves in *"file order, first match"*.
DD-2's own reading is that the **narrower** entry wins. The shipped code does
neither.

## The measurement (2026-09-03, `src/op_param_lists.tcl` md5 `bf023075`)

```tcl
op_param_lists::set_list class  mos          annotation {{cls cls 0}}
op_param_lists::set_list flavor *fet*        annotation {{broad broad 0}}
op_param_lists::set_list flavor *nfet_01v8*  annotation {{narrow narrow 0}}
op_param_lists::effective mos annotation nfet_01v8_lvt
```

```
TWOGLOB  winner={broad broad 0}     <-- the BROAD pattern wins
TWOGLOB2 winner={narrow narrow 0}   <-- rename the broad one to *zfet* and the narrow one wins
```

Both patterns match `nfet_01v8_lvt`. The winner flips on **renaming the loser**,
and the broad one won in **both insertion orders**. The cause is
`src/op_param_lists.tcl`'s `effective`:

```tcl
foreach k [lsort [array names owned]] {
  if {[lindex $k 0] ne "flavor"} { continue }
  ...
  if {[string match -nocase [lindex $k 1] $cellname]} { return $lists($k) }
}
```

`lsort` over the key triples orders by the first character after the leading
`*` — `f` before `n`, `n` before `z`. That is not file order (the store keeps
none — `owned` is an array), it is not narrowness, and it is not stable against
a user renaming an unrelated entry.

## Part 2 — a flavor entry carries no class, so it can hijack one

A flavor key is a bare cell-name glob with no class attached, and `effective`
scans **every** flavor entry regardless of the `<cls>` it was asked about.
Measured: `effective capacitor annotation cap_1v8_x` returned a flavor list
registered with MOS in mind, because the glob happened to match. There is no
way to express *"flavor X **of class mos**"*.

Low risk while item B5 writes exact cell names from a scope dialog; unbounded
the moment a user hand-edits a glob in the file they were told to hand-edit.

## Why the suite did not see it

`test_op_param_store_1245.tcl` section F only ever owns **one** flavor entry at
a time (`grep` for a second `set_list flavor` in one row: none), and every F row
passes a class that matches. F1/F1b/F2 prove the override *fires* and that a
non-matching sibling falls back — neither can see which of two matches wins,
nor that the class is ignored.

## Recommended fix

1. **Key the flavor entry on the class too** — `flavor <class>/<glob>`, or a
   fourth key field — so `effective <cls> …` scans only that class's flavors,
   and the settings-file spelling gains one field. This is the part that must be
   settled **before B5 writes the first flavor entry**, because it changes the
   file grammar (issue 1275 is the ratification door for that grammar).
2. **Order the scan deterministically and defensibly.** Two candidates, both
   better than `lsort`:
   * *most specific wins* — fewest `*`, then longest literal run, ties broken
     lexically. Matches DD-2's reading and a user's intuition.
   * *declaration order* — keep an insertion-ordered list beside the array, the
     same one-line repair issue 1274 names for `op_annot`.

**Rejected: leaving `lsort` and documenting it.** A rule a user cannot predict
from the file they are reading is not a rule; it is a coin flip with a comment.

## Acceptance rows this needs

* F3 — two flavor globs both matching one cell: the **narrower** wins, and the
  winner does not change when the loser is renamed.
* F4 — a flavor entry registered under class `mos` does **not** answer a query
  for class `capacitor`, even when its glob matches the cell name.

## Who inherits this

**Item B5** writes flavor entries from the scope dialog. If B5 ships before the
grammar gains a class field, every flavor entry in every shared settings file
has to be migrated later. Settle it at B2's seam.
