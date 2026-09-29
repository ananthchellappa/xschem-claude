# DECISIONS — selectall_getprop_batch

Numbered decisions taken during this batch. A decision here is one the DRIVER took and is
answerable for; anything that reaches the user's eyes or changes wording they see is a
RULING and goes to them instead, via `owed.sh add rule`.

## D1 — two issues, not one (driver, 2026-09-29)

Ctrl-A (wish new-list 13) and the `getprop` arms (wish old-list 21) get **separate issue
numbers, 1617 and 1618, and separate commits**, although the user asked for them in one
breath. They share no code: one is a waveform-viewer binding over the Tcl selection model,
the other is C arms in `scheduler.c`'s dispatcher. Bundling them would make any resulting
gate red unattributable, which is the mistake issue 1615 recorded at `809c03d1` and issue
1616 avoided by splitting registration from behaviour.

## D2 — a recon stage before any code (driver, 2026-09-29)

Stage R is read-only and produces no code. It exists because the driver's own scouting was
refuted twice in the immediately preceding work: issue 1616 was scouted as "one seeded
value" and turned out to need three changes plus fixture repairs in two suites, and the
claim that its fix was narrowly scoped was falsified by a test row. The enumeration of
`getprop`'s nine arms in PLAN.md question 7 is driver scouting of exactly the kind that has
been wrong, so it is put to a crew as a question rather than handed down as a fact.
