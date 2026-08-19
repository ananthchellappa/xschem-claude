# 0462 — no test row makes the `file exists` guard the last line of defence

Status: OPEN (measured by S8's sabotage pass, not fixed)
Found: S8 of doc/claude/specs/op_annotation.md. Subject: `cadence::annot_mode`'s
third guard, and rows N5/N6/N10/N15 of `tests/headless/test_op_annot.tcl`.

`cadence::annot_mode` has THREE guards in front of the one measured destructive
call. `xschem annotate_op` deletes the previously loaded OP and unsets
`ngspice::ngspice_data` **before** it tries to open the new file
(scheduler.c:2409) and returns rc=0 either way, so a failed load silently
destroys a good annotation. The guards, outermost first:

  1. `op_annot::_annotated`  — never reload while the numbers are LIVE   (row N5)
  2. `loaded >= 0`           — never reload while a raw is merely loaded (row N10)
  3. `file exists $path`     — never hand over a path that is not there  (**no row**)

Sabotage SB6 removed guard 3 and predicted N6 + N10 red. Observed: N6 red, N15
red, and **N10 stayed GREEN** — N10's fixture already has a raw loaded, so it
exits at guard 2 and never reaches guard 3 at all. (SB5, which removes guard 1,
does red N10, confirming N10 covers guard 2 and not guard 3.)

So guard 3 is covered **only through the wording of the held status line** —
`NO RAW FILE: <path>` versus `COULD NOT LOAD <path>` — and by nothing that
observes data destruction. If a future edit removed guards 1 and 2, only
wording rows would notice; no row would fail on the annotation actually being
thrown away.

Fix shape: a row that starts from a LIVE annotation (`raw loaded` 0,
`op_annot::text` populated), points the candidate at a path that does **not
exist**, bypasses guards 1 and 2 the way a refactor would, and asserts the
annotation SURVIVES — the same shape N5 already uses for guard 1, where the
assertion is on the data (`raw loaded` 0 -> -1, `op_annot::text` 100u -> {})
rather than on the sentence.

## Still open

The general lesson, worth applying to the next step that adds guards: N10 was
written from the implementation (it sets `live_cursor2_backannotate` itself)
rather than from the state space, which is also what made issue 0459 invisible
to a 171-check suite. Rows that pin a guard should be built from the state a
user can reach, not from the branch the code happens to take.
