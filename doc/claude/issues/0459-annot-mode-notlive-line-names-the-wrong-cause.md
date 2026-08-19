# 0459 — the annot_mode status line named `live_cursor2_backannotate 0` when that was not the cause

Status: **FIXED in S8** (found by S8's adversary pass, repaired and covered before commit).
Found: S8 of doc/claude/specs/op_annotation.md. Fix: `utils/annot_mode.tcl`, row N10b in
`tests/headless/test_op_annot.tcl`.

## What was wrong

`cadence::annot_mode` collapsed the two remaining terms of `op_annot::_annotated`
(src/op_annot.tcl:560) into ONE message. That gate is false when
*either* `live_cursor2_backannotate` is 0 *or* `raw annot` published no point
(`p == -1`) — but the line asserted the first, always.

The wrong branch is reached in **three shipped clicks**: `Waves > Op` (i.e.
`xschem raw_read`) loads a raw without publishing an OP point. BEFORE, measured
on the fixed binary at 8ac98756 with the S8 file as first written:

    W2 raw loaded = 0   raw annot = -1 0 -1
    W3 live_cursor2_backannotate = 1
    W4 statusmsg = 'OP annotation ON (device OP info) -- a raw is loaded but
                    backannotation is off (live_cursor2_backannotate 0)'

The line names a variable and a value, and **both are wrong** — the flag reads
1. The real cause (no OP point in this raw) is never named. Worse, the
`loaded >= 0` guard blocks the auto-load permanently, so this branch is a **dead
end**: a second press repeats the same false reason and the block stays blank
forever, with the user's actual way out (`Op Annotate`, or `raw_clear`) never
mentioned. Note `scheduler.c:2404` does `tclsetboolvar("live_cursor2_backannotate", 1)`,
so annotate_op *forces the flag on* — the branch's one TRUE reading is the rarest.

This is save.c ruling **D5-1** (a plausible wrong number on a schematic is worse
than none) wearing a reason's clothes, inside the very requirement S8 exists to
deliver: *say what happened*.

## The fix

Ask which term failed instead of assuming, and name the way out:

    set lv 1
    catch {set lv [uplevel #0 {set live_cursor2_backannotate}]}
    if {[catch {expr {$lv ? 1 : 0}} lvb]} { set lvb 1 }
    set state [expr {$lvb ? {noop} : {notlive}}]

AFTER, same probe:

    W3 live_cursor2_backannotate = 1
    W4 statusmsg = 'OP annotation ON (device OP info) -- a raw is loaded but it
                    published no operating point: use Waves > Op Annotate, or
                    `xschem raw_clear` then press again'

The `notlive` wording is kept for the case where the flag really is 0, so the
existing N10 row is unchanged and still green.

## Why the 171-check suite was blind to it

N10 sets `live_cursor2_backannotate` to 0 **itself**, so it could only ever
confirm the wording it was written from — a row shaped around the
implementation rather than the state space. New row **N10b** loads via
`xschem raw_read` (the route a user takes) and asserts the resulting line.
Sabotage SW1 (restore `set state notlive`) reds **exactly N10b** and nothing
else, printing the falsehood verbatim: 1 FAILED (171 passed).

## Still open

Issue 0451 owns the wider "four indistinguishable causes" question. This closed
its status-line half for the two causes `_annot_mode` can distinguish; a raw
that is *digital* is still folded into `noop`.
