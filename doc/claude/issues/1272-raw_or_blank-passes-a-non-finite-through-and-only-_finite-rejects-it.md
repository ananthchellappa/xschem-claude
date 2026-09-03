# 1272 — `op_annot::raw_or_blank` passes a non-finite through; only `op_annot::_finite` rejects it, and nothing at the seam says so

Status: **FIXED, 2026-09-03** (option 1, plus a companion accessor) — measured
the same day by item **B1** of `doc/claude/op_param_batch/PLAN.md`, which fell
into it, and repaired in B1's driver re-do · Branch: `fluid-editing`

Related: invariant **I3**, ruling **D5-1**, issues **1259**, **1263**, **0213**,
**1245** (the Results Display Window), `src/save.c`'s own non-finite decision
block

## The defect, in one sentence

`op_annot::raw_or_blank` is documented as *"the number, or `{}`"* and gates on
`string is double -strict`, which **accepts `nan` and `inf`** — so it returns the
string `nan` as if it were a number, and the only thing in the tree that catches
it is a **second, separate** call to `op_annot::_finite` that every existing
consumer happens to make and that nothing at the seam obliges a new one to make.

## The measurement, first-hand, on this binary (`src/xschem`, 2026-09-03)

A **binary** raw — which is what `write` produces by default, i.e. what a real
ngspice run leaves behind — carrying an IEEE NaN in one operating-point column:

```
raw value -1 : <nan>
raw value  0 : <nan>
raw_or_blank : <nan>          <-- string is double -strict says YES
_finite      : 0              <-- the only thing that says NO
```

This is not an exotic input. `src/save.c`'s own non-finite decision block
records, measured on this box, that **`ngspice-46` emits all four of `inf`,
`-inf`, `nan`, `-nan`** into a raw, and a non-converged operating point is the
ordinary way to get one.

**The ASCII path hides it, which is worse, not better.** The same value written
into an *ascii* raw comes back as `0`:

| written | `xschem raw value … -1` |
|---|---|
| `nan` | `0` |
| `-nan` | `-0` |
| `inf` / `Inf` / `INF` | `0` |
| `1e999` | `1.0000001e+38` |

`src/save.c` documents that deliberately: the fast `my_atof()` continuation path
has never parsed the words and returns `0.0`, while the two `sscanf`-validated
paths do store a real non-finite. So **the same failed simulation reports `nan`
from a binary raw and a confident `0` from an ascii one** — a fabricated zero,
which is D5-1's own failure. That asymmetry predates this issue and is recorded
there as a known inconsistency; it is quoted here because it is why a consumer
cannot reason about non-finites from a single test.

## Why it is a seam defect and not just a caller's mistake

Every existing consumer of `raw_or_blank` is correct, and all of them are
correct **the same way** — by making a second call:

* `src/op_annot.tcl` — `if {[::op_annot::_finite $val]} { break }`, then
  `if {![::op_annot::_finite $val]} { set val {} }`, then again at the pinexpr
  and text rows. Four call sites, one per read.
* `op_annot::eng_or_blank` — `if {![::op_annot::_finite $v]} { return {} }`
  before it will let a value near `to_eng`.

So the tree really does run a **two-stage** discipline — *read, then prove
finite* — and the first stage's own doc comment does not mention the second.
That is a seam whose contract is carried entirely by the habit of its existing
callers, and **item B1 is the measured case of a new caller not inheriting the
habit**: `ase::backend::ngspice::op_param_set` read through `raw_or_blank`,
skipped `_finite`, and returned

```
devices {@m.x1.m1 {{id nan} {gm 0.5}}} absent {} complete 0 state ok
```

— `nan` in the **value** bucket, of a seam whose own documented contract says
`absent` carries *"columns the raw NAMES but the simulator did not compute"*.
Item B3 rendering that unfiltered puts **`id = nan`** on a schematic, which is
verbatim what invariant I3 forbids: *"A missing vector renders BLANK. Not 0, not
NaN on screen."* B1 was **green at 37/37** with that defect live, because the
suite had no non-finite row — see `doc/claude/op_param_batch/receipts/B1.md`.

## Recommended option

**Option 1 (recommended) — fold the finite test into `raw_or_blank`.** Change
its last two lines to require `_finite` as well as `string is double -strict`.
One stage, one place, and the seam's doc comment becomes true.

* *For:* every consumer present and future is correct by default; it is the
  narrowest possible edit; the four existing `_finite` calls become belt-and-
  braces rather than load-bearing, so nothing regresses if it is taken alone.
* *Against:* it changes an existing accessor five callers already depend on, so
  it needs `test_op_annot` and `test_annot_declutter_1244` re-run, and it must
  land with a row that reds if the gate is removed again.
* *Risk that it is wrong:* a future consumer that genuinely wants to see `nan`
  (a diagnostic view saying "this device did not converge") loses the ability to
  distinguish it from an absent column. That consumer does not exist, and the
  distinction it would want is better served by a third outcome than by leaking
  a non-finite through a two-outcome accessor.

**Option 2 (rejected) — leave `raw_or_blank` alone and gate at each new caller.**
That is the status quo, and the status quo just shipped a refuted seam. It makes
correctness a property of whether the next author read four other call sites.

**Option 3 (rejected) — route the non-finite into `absent`.** Attractive for
B1 specifically, and it is what B1's reconstruction must do at *its* layer, but
as a change to `raw_or_blank` it would make "absent" mean two different things
(the column is not there / the column is there and holds NaN) at the one seam
that exists to keep those apart. Item 1245's seam should carry that distinction
explicitly — a `nonfinite` bucket, or `absent` with a reason — not inherit it.

## Acceptance rows for whoever takes this

1. A **binary** fixture raw carrying an IEEE NaN in one OP column: the value
   accessor answers `{}`, not `nan`, and not `0`.
2. The same fixture with `inf`: same answer.
3. A genuinely computed `0.0` still answers `0` — the cut-off transistor is a
   measurement and must not be swept up (issue 1259's other half).
4. A `dims=0` column still answers `{}` and is still distinguishable from (3).
5. `test_op_annot` and `test_annot_declutter_1244` unchanged by name and count.
6. A structural row that reds if the finite test is removed from the accessor.

## What was actually done, 2026-09-03

**Option 1 was taken, and it grew one companion.** Folding `_finite` into
`raw_or_blank` makes every consumer correct by default, but it also makes the
accessor two-outcome forever — and item B1's seam needs three, because it has to
report a non-converged device as such. So the three outcomes moved into a new
accessor and `raw_or_blank` became one line on top of it:

```tcl
proc op_annot::raw_class {v} {          ;# absent | nonfinite | value
  if {$v eq {}} { return [list absent {}] }
  if {[catch {xschem raw value $v -1} r]} { return [list absent {}] }
  if {![string is double -strict $r]} { return [list absent {}] }
  if {![::op_annot::_finite $r]} { return [list nonfinite $r] }
  return [list value $r]
}
proc op_annot::raw_or_blank {v} {
  set c [::op_annot::raw_class $v]      ;# ONE call: this is the annotation
  if {[lindex $c 0] eq {value}} { return [lindex $c 1] }   ;# hot path
  return {}
}
```

That is one place that reads the vector and one place that classifies it, so
neither of option 1's costs is paid twice. The four `_finite` calls in
`op_annot.tcl` and the one in `eng_or_blank` are now belt-and-braces and are
**deliberately left**: they cost nothing, and removing them would make this one
edit load-bearing for five call sites at once.

**Item B1's seam gives the non-finite its own bucket**, which is this issue's
option-3 note applied at the layer it belongs to: `op_param_set` returns
`{devices absent nonfinite complete state}`, and `nonfinite` carries
`{<rawdev> <param> <text>}` triples. `absent` keeps meaning exactly one thing.

### The acceptance rows, all six, all green

| row | where | verdict |
|---|---|---|
| 1 binary NaN answers `{}`, not `nan`, not `0` | `test_rdw_seam_1245` **NF1** | pass |
| 2 the same for `inf` | **NF2** | pass |
| 3 a genuinely computed `0.0` still answers `0` | **NF3** | pass |
| 4 a `dims=0` column still `{}`, distinguishable from (3) | **NF5**, and the pre-existing A1/A2 pair | pass |
| 5 `test_op_annot` / `test_annot_declutter_1244` unchanged | 485 ALL PASS · **134 ALL PASS** | pass |
| 6 a structural row that reds if the finite test is removed | **NF7** | pass |

Row **NF0** was added beneath all of them: it asserts the fixture really carries
a non-finite. Without it the five rows after it would pass vacuously the day
someone rewrites the fixture as ascii — which is precisely how the original
defect shipped green at 37/37.

**Sabotage, measured:** deleting the `_finite` line from `raw_class` reds
**NF1 NF2 NF5 NF6 NF7** and nothing else.

## Still open

* The **ascii/binary asymmetry** above is not fixed by any option here. A failed
  run still reads back as a confident `0` from an ascii raw. `src/save.c` says
  changing it *"would change what every consumer of `raw->values` sees — min/max,
  dB, the viewer's autoscale; that is a separate decision"*. It is still separate,
  and it is still unmade.
* Nothing pins the two stages together today. Until option 1 lands, **any new
  reader of `raw_or_blank` must call `_finite`**, and this issue is the only
  place that says so.
