# 1265 — the absence rule reached **one of three** readers of `cursor_b_val[]`

**Filed** 2026-09-02 by item **A6**, half from the implement pass and half from
the adversary pass, which measured the resulting split. **Measured, not fixed.**

## The defect

Item A6-b installed the absent-vs-zero rule (`raw_vector_absent()`, `src/save.c`)
in **exactly one** consumer: the **annotation fall-through** of the `raw value`
arm in `src/scheduler.c`. There are three readers of `raw->cursor_b_val[]` that
put a number in front of a user, and the other two still publish the fabricated
`0` for a `dims=0` column:

| reader | dims=0 column shows |
|---|---|
| `xschem raw value <v> -1` (the overlay's accessor) | **blank** — corrected by A6 |
| `xctx->raw->cursor_b_val[idx]` behind a bare `idx >= 0` test in `src/token.c` (six `@spice_get_*` branches) | `0` |
| `ngspice::ngspice_data(<v>)` — the lazy view built by `nd_view_set()` / `nd_view_read()` in `src/save.c` | `0` |

Measured by the adversary on one `dims=0` fixture, same instant, same vector:

```
xschem raw value i(@m1[ib]) -1   ->  {}     (blanked by A6)
xschem raw value i(@m1[ib])  0   ->  0      (deliberate: data inspection stays live)
$ngspice::ngspice_data(i(@m1[ib]))  ->  0   (unguarded)
```

## Why it matters more than "a third file"

`ngspice::get_current` (`src/xschem.tcl:3529`) reads that array, and it is used
by **five shipped library schematics** —
`xschem_library/ngspice/solar_panel.sch`, `examples/cmos_example.sch`,
`mos_power_ampli.sch`, `poweramp.sch`, `poweramp_lcc.sch`. So the split is
reachable on a stock sheet, not only on an `op_annot` one: **before A6 the
overlay and a schematic's own `@spice_get_*` text agreed; now the same quantity
can render blank in one and `0` in the other on the same sheet.**

Reachability is nonetheless low today: it needs a `dims=0` column *and* both
readers displaying the same quantity, and issue **0418** already makes
`@spice_get_modelparam_<p>()` inert, while a node **voltage** is never `dims=0`.
It is not a live split of ruling **D5-4**.

## Why A6 stopped at one reader

Ladder **L2**: a fourth and fifth file at feature close, on a much wider
surface. `nd_view_set()`/`nd_view_read()` in particular is the backannotate and
casemode machinery, whose blast radius is far beyond a declutter item. Recorded
rather than done quietly.

It is also the reason the second `raw_vector_absent(` line in `src/save.c` is the
predicate's own `dbg()` trace and not an in-file use: there **is** no in-file
consumer that does not change a second face's behaviour.

## Fix shape

Widen the one predicate's reach, do not re-derive absence in `token.c` or in
`nd_view_read()` — invariant **I1**. Note that `token.c`'s branches must keep
publishing a **real** measured `0`, so the guard is `raw_vector_absent()`, never
"the value is 0".

## Still open

All of it.
