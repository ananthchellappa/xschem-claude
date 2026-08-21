# 0487 — issue 0443 is a claimed number carried by a `.patch` alone, with no issue `.md`

**Status:** OPEN (measured, not fixed)
**Filed:** 2026-08-21, during S12b of `doc/claude/specs/op_annotation.md`
**Measured on:** HEAD `479be885`
**Severity:** low (records), but it makes a cited issue number unreadable — a
maintainer following "S3 failed three times (0436, 0442, 0443)" can read two of the
three and finds only a diff for the third.

## What was measured

`doc/claude/issues/` holds, for the three reverted S3 attempts:

    0436-attempt-1-reverted.patch
    0436-save-cards-from-devpath-carry-raw-relative-names.md     <- issue text exists
    0442-attempt-2-reverted.patch
    0442-...                                                     <- issue text exists
    0443-attempt-3-interrupted.patch                             <- ONLY the patch

`0443` has **no** `NNNN-*.md`. The number is nevertheless cited as an issue in at
least two places — `doc/claude/specs/op_annotation.md` line 8 ("S3 failed three times
(issues **0436**, **0442**, **0443**)") and, until S12b, in
`waveform_subsystem_reference.md` §6.5.

Found while writing §6.5: the S12b implement agent flagged it, and the S12b write-up
agent re-confirmed it with

    $ ls doc/claude/issues/ | grep '^0443'
    0443-attempt-3-interrupted.patch

## Why it was not fixed here

L2 (least surprising, smallest blast radius). Writing the missing `0443-*.md` means
reconstructing what attempt 3 measured before it was interrupted, from a patch alone —
that is S3 archaeology, not an S12b documentation edit, and a reconstructed issue that
mis-states why attempt 3 stopped is worse than a visible gap. Rejected alternative:
silently dropping `0443` from the citations, which would erase the evidence that a
third attempt happened at all.

S12b instead annotated both citation sites in place, so a reader is told what they will
find: `op_annotation.md` line 8 and `waveform_subsystem_reference.md` §6.5 now say
"0443 is a claimed number carried by that patch alone, with no issue `.md`".

## Fix

Either write `doc/claude/issues/0443-<slug>.md` from the patch and whatever the S3
attempt-3 transcript recorded, or retire the number explicitly with a one-line
tombstone file so the citations resolve.
