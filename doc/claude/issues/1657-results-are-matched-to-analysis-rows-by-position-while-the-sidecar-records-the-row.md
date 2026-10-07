# 1657 — Results are matched to analysis rows by POSITION, while the sidecar already records the row

**STAMP:** `v1 claim=open tree=790556f2 stamped=2026-10-07 fix=untried open=2`

## The user's own evidence

From `/tmp/Xschem.log.3`, a real `tb_bandgap` run on 2026-10-07 (the user handed the log
over while reporting unrelated Calculator defects):

```
#= ase: results -- a row whose expression names exactly one vector is read from the
      results file; anything else is read from the print log. This run: 5 from the file, 0 from the log.
#= ase: results -- the tran analysis in row 3 recorded 'Transient Analysis' where the
      registry declares 'Operating Point', so results cannot be matched to the row that asked for them.
#= ase: results -- the op analysis in row 0 recorded 'Operating Point' where the
      registry declares 'Transient Analysis', so results cannot be matched to the row that asked for them.
```

The two sentences are **each other's mirror image**: row 3 (`tran`) produced the title the
registry expected for row 0, and row 0 (`op`) produced the one expected for row 3. That is
not two independent mislabels — it is **one crossed pairing** reported twice.

## The mechanism, read in `ase::cap_verdict` (`src/ase.tcl`)

Two lists are built and then compared **1:1 by position**:

| list | built from | order |
|---|---|---|
| `$map` | `ase::plotmap_read` — the sidecar written at run time | the order the plots were **written** |
| `$expect` | a walk over the registry's analysis rows | the order the rows are **listed** |

```tcl
# 1:1, position by position, against BOTH the file and the registry
for {set i 0} {$i < $n} {incr i} {
    set mrec [lindex $map $i]
    ...
    set sel [lindex [lindex $expect $i] 2]
    if {![string match -nocase $sel $got]} {
        lappend mis [list [lindex $mrec 0] [lindex $mrec 1] $got $sel registry]
    }
}
```

⚠ **`$mrec` carries the row index at element 1 and the comparison throws it away.** The
sidecar record is `{atype rowindex plotname}` and `$expect`'s elements are
`{atype rowindex plot_select}` — so **both sides already know which row each plot belongs
to**, and the matcher pairs them by their position in two differently-ordered lists instead.
The row index is used only to *report* the mismatch it caused.

The `registry` side of the comparison is guarded by `if {!$orderok || ...} continue`, so this
fired with `orderok` TRUE — i.e. something upstream judged the order sound and the positional
pairing then crossed two rows anyway. Whether `orderok`'s own computation is wrong, or whether
it is answering a different question from the one this loop needs, is **not established here**.

## What is NOT established, and must be before anything is changed

1. **Whether position is the intended contract.** It is possible the sidecar is *supposed* to
   be written in registry-row order and the real defect is upstream, in whatever writes it —
   in which case keying on the row index would paper over a wrong sidecar. Read
   `ase::plotmap_read` and its writer before deciding.
2. **What the user actually lost.** The sentence says results "cannot be matched to the row
   that asked for them", but not what the consequence is downstream — whether those two rows
   show no results, the wrong results, or stale ones. **That is the half that decides how
   urgent this is**, and it is unmeasured. The run reported `5 from the file, 0 from the log`,
   so the data was read; only the pairing failed.
3. Whether this reproduces, or needs this particular registry's row ordering. One observation.

## Why it is filed rather than fixed

It arrived inside a report about seven Calculator defects and is none of them. Keying the
match on the row index both sides already carry is a two-line change and looks obviously
right, which is exactly the shape this tree has been burned by twice (CLAUDE.md records a
guard that "looked right" and refused correct work, and two wrong repairs to a predicate whose
own 187-check suite passed against both). It needs (1) and (2) answered first.

Family: not the same as 1413/1647 (knowing `hcases`-alone trades). Nearest relative is issue
1650's shape — a positional assumption that is right for every fixture anyone drove and wrong
for the real case.
