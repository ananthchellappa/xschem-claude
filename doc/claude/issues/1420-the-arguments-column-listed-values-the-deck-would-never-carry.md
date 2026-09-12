# 1420 — the Arguments column listed values the deck would never carry

**Status:** fixed
**Branch:** fluid-editing
**Stage:** commit **C7** of Stage 3 of `doc/claude/ase_analyses_batch/` — **the last one**.

## The other half of the acceptance criterion

> *nothing the window shows may fail to reach the deck, and nothing the deck contains may be
> unshowable in the window.*

Commits C5 and C6 were about the first half. This is the second, and it had been hiding in plain
sight: an **enabled** analysis row that cannot render had its keys dumped into the Arguments column
as `step=1n stop=10u` — which reads exactly like a setting that is in force, in the one column whose
entire job is to say what the deck carries. Nothing in that cell says the row produces no deck line
at all.

The honest answer to *"what will this run?"* for a row that cannot run is **the reason it cannot**,
and it is now given in the same words the commit door and the preflight gate use.

⚠ **Three surfaces, one vocabulary.** If the pane and the dialog disagreed about why a row will not
run, one of them would be wrong and the user could not tell which. Row **AC2** asserts the column's
text is the identical clause `ase::analysis_emit_check` produces — not a second sentence about the
same thing.

⚠ **Only for an ENABLED row.** A switched-off row makes no claim about a run, so it has nothing to
be wrong about — and `ase::state_default` seeds **every new bench with three empty disabled rows**,
each of which would otherwise open wearing a complaint about a value nobody has been asked for yet.

⚠ **And a type the backend cannot set up says so**, rather than naming a missing value. Seven of the
eleven registered types are probe-only until Stage 6; an enabled one of those has nothing missing —
there is simply nothing ASE-L can write for it, and *"needs a value for …"* would send the user
hunting for a field that does not exist.

## A comment that was the defect, written down and shipped

`ase::ui::chana_options`' header ended:

> DECK emission of extra keys stays deferred (v1 limit, documented here).

That sentence **is** the defect of this entire stage, recorded as a design note and left in place.
Keys that round-trip and never emit are keys the window confirms and the simulator never sees.
Issue 1418 closed that door; issue 1419 opened the honest one. The comment now says so, because a
stale comment describing a behaviour that no longer exists is how the next person re-derives a
decision that has already been made.

## Suites

`test_ase_core.tcl` **343 → 348** (section **AC**).

⚠ **Two of the five rows failed on their first run for a reason that had nothing to do with the
code**: the expectations were written as literal braced lists (`{{stop=10u} {} {}}`) where Tcl
produces no braces around a single word. Expectations that must compare as **lists** are now built
with `[list …]` on both sides, so the canonical form is whatever Tcl says it is rather than whatever
the author guessed.

## Stage 3 is complete with this commit

Seven commits: **1414** the slot grammar · **1415** one refusal reader and the number alphabet ·
**1416** the field tables and the positional back-fill · **1417** the typed form · **1418** the door
closes · **1419** the verbatim hatch · **1420** the Arguments column.
