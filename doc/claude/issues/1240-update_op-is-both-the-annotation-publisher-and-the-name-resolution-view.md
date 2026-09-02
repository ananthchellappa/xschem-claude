# 1240 — `update_op()` is both the annotation publisher and the name-resolution view

**Status:** OPEN — a design question, with an interim in place that honours the
user's ruling. On the owed ledger as a `rule`.

## What the merge found

`fluid-editing` and `annotate` both changed `update_op()` (`src/save.c`), and
**git merged them with no conflict marker**. The result was neither branch's
behaviour, and roughly 40 checks across `test_raw_case_mode`,
`test_ngspice_data_view` and `test_ngspice_data_ctx` went red at once with
nothing to point at. This is the sharpest thing the merge turned up: two
correct changes composing into a third, wrong one, invisibly.

## The two rulings, both the user's, both right

**0856 (`annotate`, 2026-08-26), verbatim:** *"We haven't yet built anything for
annotating from TRAN results, so it should do nothing silently."* Enforced by a
guard at the top of `update_op()`: anything that is not `op` or `dc` publishes
nothing and answers 0. A transient's t=0 sample is not an operating point, and
painting it as one is the fabricated-number defect.

**D3 (`fluid-editing`, casemode item 5b):** `ngspice::ngspice_data` stopped being
an eager folded publish and became a **read-traced lazy view** over
`get_raw_index_in()`, so both `v(MidNode)` and `v(midnode)` resolve through the
one ladder and enumeration answers with the database's own spelling. The viewer,
the case-mode ladder and any script need it armed for **any** analog database.

## Why they cannot both be served as the code stands

It was tempting to split them at their enforcement points: leave `annot_p` at -1
for a non-op database (which is what `token.c` gates the C overlay on:
`published = ... && annot_p >= 0`) while still arming the array for scripts.
**Measured false as a separation.** The array is *also* the schematic's value
source on the Tcl road — `ngspice::get_voltage` reads it, and
`test_backannotate_digital`'s own helper calls that read *"what the SCHEMATIC
would print"*. Arming it for a transient therefore puts t=0 on the schematic
wearing the label "operating point", which is exactly what 0856 forbids.

One array, two consumers, no way to serve one without serving the other.

## The interim, and what it costs

**0856 wins**: the guard is restored verbatim. It is the user's own dated words,
and it is substantively right.

`fluid-editing`'s case-mode ladder can therefore no longer be exercised through
a transient. It does not need to be — the ladder is about **name spelling**,
which is identical in every analysis — so two new fixtures were added,
`doc/claude/casemode_batch/fixtures/op_preserve.raw` and `op_fold.raw`: the same
four variable names in the same two spellings, one point,
`Plotname: Operating Point`. The three suites arm from those and assert the same
rulings. Nothing was weakened; the rows now exercise the publisher on the
analysis kind it actually serves.

**What is genuinely lost:** a script cannot resolve a name out of a transient
through `ngspice::ngspice_data`. It can still do so at a cursor — the other
publisher, `backannotate_cursor_b_in_db()` (`callback.c`), arms the same view
from cursor B, which is the honest place for a transient to have a value.

## The option NOT taken

**Split the array in two**: an annotation channel (what the schematic prints,
op/dc only) and a resolution channel (what a name resolves to, any analog
database). That serves both rulings with no loss, and it is the right shape —
`update_op()` doing both jobs is what made two correct changes collide.

It was not done here because it is a design change with a user-visible surface
(`ngspice::ngspice_data` is read by `ngspice_backannotate.tcl`, by the viewer and
by users' own scripts), and a merge is not the place to introduce one. It needs
its own commit, its own spec section and its own ruling on what the second array
is called.
