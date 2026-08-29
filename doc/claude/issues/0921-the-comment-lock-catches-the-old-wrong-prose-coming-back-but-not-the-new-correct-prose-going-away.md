# 0921 -- the comment lock catches the old wrong prose coming back, but not the new correct prose going away

Status: OPEN. Filed by the B3 sabotage pass, 2026-08-29, on HEAD e60e1974.
Class: test coverage. No user-visible behaviour is wrong today.

## What is guarded, and what is not

Issue 0861 reconciled the inventory comment in `src/save.c` `update_op()`. That
comment now names both readers of `cursor_b_val` that were unguarded, and it
lays down an obligation on future authors:

    Adding a reader of cursor_b_val obliges you to add the annot_p term to it
    and to this list, in the same commit.

`tests/headless/test_spice_get_node_0861.tcl` row SGN19 is presented as the lock
over that comment -- the item's own evidence says "Row SGN19 is a structural
check over that comment, because no behavioural row anywhere can see a comment
go false." SGN19's three terms are:

    regexp {INVENTORY IS SHORT BY ONE} $sgn_save   -> want 0
    regexp {six live_cursor2 sites}    $sgn_save   -> want 0
    regexp {annot_p}                   $sgn_save   -> want 1

The first two are ABSENCE assertions over two specific phrases from the old,
wrong revision. The third greps the WHOLE of `src/save.c`, where `annot_p`
appears dozens of times in ordinary code, so it is 1 no matter what the comment
says.

## Measured

Sabotage S5 (restore the two old phrases): SGN19 goes RED, `{1 1 1}` against
`{0 0 1}`. The lock works in that direction.

Sabotage S5b (delete the ENTIRE issue-0861 paragraph, lines 2171-2188 of
`src/save.c` -- the inventory naming both readers, the measurement, and the
obligation sentence above): `test_spice_get_node_0861` reports
`RESULT: ALL PASS (23 checks)` and SGN19 prints `ok`.

So the comment can be deleted wholesale and every check in the tree stays green.
The lock is one-directional: it forbids the old wrong sentence from coming back,
and it does not require the new correct sentence to be there.

That matters because the comment is the ONLY thing telling a future author that
a new reader of `cursor_b_val` needs the `annot_p` term. The previous revision's
wrong inventory is exactly what let the seventh reader sit unguarded and ship
the fabricated zero (0861). A refactor that tidies the comment away restores
that condition silently.

## Suggested fix

Give SGN19 PRESENCE terms over the load-bearing sentences, not only absence
terms over the retired ones. Something with the shape:

    regexp {spice_get_node} $sgn_save                        -> 1
    regexp {obliges you to add the annot_p term} $sgn_save   -> 1

and drop the third term, which is decoration. Keep the needles short and quoted
exactly once in the comment, so the comment's own text cannot satisfy them from
somewhere else.

## Related

* 0861 -- the fix this comment documents.
* The same one-directional shape is worth auditing on any other structural row
  in the tree that asserts a comment by absence alone.
