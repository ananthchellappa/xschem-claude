# Drag responsiveness batch 2026-11-15 — PLAN

Base: bd14668b9 (fluid-editing), WITHOUT the uncommitted selection-look diff.

## Why
The user asked what our weak spot is in REASONABLE use ("Don't go off extreme cases. We need to
worry about *reasonable* cases where a user will notice something bad"). The realistic-timing run
(doc/claude/selection_look_batch/receipts/realistic-timing.md) found it is base dragging, not the
selection look: a drag frame on ordinary pages is 20–80 ms for one device and 100–450 ms for a
handful of connected devices, identical with and without the selection change; ~80% of it is the
fluid-wiring passes calling `tclgetdoublevar("cadsnap")` (Tcl lookup + sscanf) inside loops over
every pin and wire segment, growing with the square of page size.

## Scope
A pure performance fix: no visible behaviour change, wiring results byte-identical. Internal
engineering, not a user ruling. Separate commit from the selection-look batch.

| stage | what | who |
|---|---|---|
| A | profile on real pages, confirm the cause, fix, red-first timing + identity | crew |
| B | adversarial verify | verifier |
| C | T1 gate in a short-path clone, commit | driver |

## Queued behind stage A (same code): issues 1716 and 1715
Filed 2026-11-15 (3b36f24a1), both fork defects, chained: an Escape-aborted fluid drag leaves the
sheet modified and writes the cancelled geometry to `cell~.sch` (1716); a later go-back adopts a
backup this session never wrote, prompts "has unsaved changes" on an untouched parent, and Yes saves
the backup's geometry into the cell (1715). Fixes are behaviour-restoring, not rulings: an aborted
drag stays clean and writes nothing (as the code's own comments promise); go-back adopts only a
backup this session wrote and otherwise loads the cell from disk, leaving a foreign backup untouched
(issue 1486). Stage D, crew + verifier, based on stage A's patch because both touch the drag commit
path in move.c.
