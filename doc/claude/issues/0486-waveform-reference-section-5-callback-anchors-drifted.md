# 0486 — `waveform_subsystem_reference.md` §5: six `callback.c` anchors have drifted ~1100 lines

**Status:** OPEN (measured, not fixed)
**Filed:** 2026-08-21, during S12b of `doc/claude/specs/op_annotation.md`
**Measured on:** HEAD `479be885`
**Severity:** low (documentation), but it is the exact defect class S12b existed to
fix in §6 — a maintainer who trusts a line number lands on unrelated code and
concludes the function moved or was deleted.

## What is wrong

§5 of `doc/claude/code_analysis/waveform_subsystem_reference.md` (around line 368,
the cursor/marker gesture list) cites six `callback.c` symbols by approximate line.
All six are stale by roughly 1100 lines:

| §5 cites | Real line on HEAD `479be885` |
|---|---|
| `backannotate_at_cursor_b_pos` ~425 | `src/callback.c:1531` |
| `graph_marker_press` ~567 | `src/callback.c:1674` |
| `graph_marker_drag_to` ~610 | `src/callback.c:1741` |
| `graph_marker_drag_clear` ~664 | `src/callback.c:1831` |
| `graph_marker_drag_abort` ~674 | `src/callback.c:1842` |
| `graph_marker_release` ~684 | `src/callback.c:1852` |

The file's own header (lines 11–13) declares all its line numbers approximate,
captured 2026-07-22 at ~`cf57955c`, and says "grep the symbol name, don't trust the
number". That contract makes this tolerable, not correct: a ~1100-line drift is far
past the point where a reader can find the symbol by scrolling.

## Why it was not fixed in S12b

S12b was scoped by its brief to §6 only. The second `backannotate_at_cursor_b_pos`
anchor sits in §5, and fixing that one alone would leave §5 *looking* swept while the
other five stayed stale — a worse state than uniformly-stale, because the reader loses
the cue that the whole section is dated. Either all six move or none do. S12b chose
none, and files this.

## Fix

Re-verify and rewrite all six anchors in one pass, and date-stamp §5 the way S12b
date-stamped §6 ("anchors re-verified on HEAD <sha>, <date>"), so the section's
precision is declared rather than assumed.

## Related

- `doc/claude/code_analysis/lessons_census_before_design.md:240` cites
  `waveform_subsystem_reference.md:1447`, which is **already** stale today (it lands on
  landmine 36's heading, not the sentence quoted). Same class, different file; worth
  folding into the same pass.
- The §6 half of this problem was fixed by S12b (five anchors corrected, section
  date-stamped).
