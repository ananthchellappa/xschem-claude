# 0638 — the two stock Annotate-OP menu items say nothing at all, ever

Status: **OPEN — measured, not fixed.** Filed by the 0617+0618 crew, 2026-08-23.
Related: **0617** (the report channel this is about), 0614, 0621.

## The defect

`utils/annot_mode.tcl` — the cadence-profile chord path — is the only surface that
reports *anything* about an annotation attempt: which mask is on, whether a raw
loaded, which symbol types have no descriptor. It is sourced only from
`src/cadence_style_rc`.

The two **stock** entry points have no reporting channel whatsoever:

* `src/xschem.tcl:15038` — *Waves → Op Annotate*
* `src/xschem.tcl:15440` — *Simulation → Graphs*

Verified by grepping their whole inline bodies: each holds `xschem set annot_show 3`
plus `xschem annotate_op` and **no `statusmsg`, no `ciw_echo`, no `puts` of any kind**.
A stock-profile user who picks the menu item and gets six blank rows is told nothing —
not even the existing "NO RAW FILE" sentence a cadence-profile user gets.

## Why it was not fixed with 0617

Decision **D5 (L2)** of that crew: the 0617 report was scoped to the chord path,
because hoisting `_annot_msg` / `_annot_cause` into `src/op_annot.tcl` so both surfaces
share them is a refactor well beyond the step. That reasoning stands, but 0617's
attempt was then **refuted and reverted**, so today *neither* surface reports the
interesting causes and this one reports nothing at all.

## The cost of fixing it, measured

Both are X-only inline `-command` bodies under `if {[info exists has_x]}`. **No
headless row can reach them** — coverage for anything added there is a source-grep row
only (the N22/N22b idiom already used in `test_op_annot.tcl`).

## Recommended

Fix it *with* 0617's retry, not before: hoist the message builder into
`src/op_annot.tcl`, have both the chord and the two menu bodies call it, and pin the
menu bodies with a source-grep row. Fixing it first would ship a third voice into a
feature that already had three.
