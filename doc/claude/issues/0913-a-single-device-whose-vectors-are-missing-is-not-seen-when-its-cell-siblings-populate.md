# 0913 — a single device whose vectors are missing is not seen when its cell siblings populate

**Status:** STUB, claimed 2026-08-28 by item A16 (issue 0909's blank-row
explanation). Filed BEFORE the work so a later crew cannot collide on the number.

`cadence::_annot_scan` walks the sheet **deduped by `cell::name`** — one instance
per distinct cell answers for all of them, because that is what `cell::type` and a
descriptor's `match` globs are functions of. Issue 0909's blank-row probe rides
that same loop, so it costs one `op_annot::text` per distinct *cell* rather than
one per *device*.

The consequence: on a sheet with twenty instances of one cell, where nineteen
have their `@…[…]` vectors in the results file and one does not, the probe asks
only the representative. If the representative is populated, the sheet is
reported as fully populated and the user is told nothing about the one blank
block in front of them. The honest general `somedev` sentence covers the case
only when the representative happens to be the missing one.

**The cost of exactness** is one `op_annot::text` build per device on a bench
that may hold 500 of them, on every `6` press — the axis issue 0904 already says
was published against the wrong variable.

Recorded as an accepted limitation of issue 0909's fix, not as a defect of it.
Needs a user ruling on whether to pay for exactness (question 6 of A16's plan).
