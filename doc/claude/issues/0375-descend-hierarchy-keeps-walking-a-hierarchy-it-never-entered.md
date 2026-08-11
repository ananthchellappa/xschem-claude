# 0375 — `descend_hierarchy` discards every `xschem descend` result and keeps walking a hierarchy it never entered

Status: **OPEN — STUB, claimed by item D5 (descend census part 2), deliberately NOT fixed there.**
Source-read only; no transcript yet.

Area: `src/xschem.tcl:3856-3877` `descend_hierarchy`, and its consumers `select_inst`
(`:3881`), `probe_net`, and the ASE hierarchy machinery.

## The suspected defect

```tcl
  while { [regexp {\.} $path] } {
    ...
    xschem descend $instnum
  }
```

The result is never read. Each iteration consumes one path component whether or not the
descend happened, so a refused descend (bad selection, wrong type, busy, a child that could
not be loaded) leaves the walk at a level *shallower* than the path names — and the loop then
searches for the remaining components in the wrong schematic. `select_inst` reports the
instance it "found" from that level.

D5's landing contract (a descend that returns 0 leaves `currsch` exactly where it was) makes
the mismatch well-defined and detectable, but does not fix this caller: it still discards.

## Fix sketch

`if {![xschem descend $instnum]} { break }`, and return the *unconsumed* remainder so
`select_inst` falls into its existing "nothing found, walk back to top" arm. Both consumers
already handle an empty result. Check `probe_net` and the ASE callers before assuming that.

This is the same class as the `hier_traversal` / `sg13g2_hier_sch_expand` /
`sky130_hier_sch_expand` compensating arms that D5 moved to the `currsch`-delta form; this one
was left alone because it does not compensate — it simply does not look.

## Coverage

None.
