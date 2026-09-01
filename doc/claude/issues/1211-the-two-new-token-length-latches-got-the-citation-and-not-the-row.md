# 1211 - the two new token-length latches got the citation and not the row

STATUS: **FIXED** 2026-08-31 (item S6a, the repair pass). Row AS58 of
`tests/headless/test_auto_specialize_1201.tcl` now pins both of them.

## What was wrong

Again, not the product code - the guards were there and were correct. What was
missing was anything that would notice if they went away.

Two functions item S6a added to `src/actions.c` ask the property reader
questions of their own while somebody else is in the middle of reading a token:

* `auto_spec_collides()` - does any copy on this sheet already name this cell
  body by hand?
* `auto_spec_qualifies()` - does this symbol name its own drawing, or say its
  insides are never written out?

The property reader leaves the length of what it found in one place every caller
shares (`xctx->tok_size`). An observer that clobbers it becomes the reason a real
netlist value goes missing for whoever was asking. So each function latches that
length before its first lookup and puts it back before it hands an answer out,
and each carries a comment saying it does so **"for the reason GUARD UA-TOKSIZE
gives in token.c"**.

That citation is the finding. The guard in `token.c` **is** pinned, by row UB9 of
`tests/headless/test_unused_attr_0970.tcl`. Somebody already learned this lesson
on the sibling, wrote the row, and left a note in it recording that a looser
anchor "could not fail". The two new copies got the citation and not the row.

## How it was found

The sabotage pass on item S6a deleted the restore in `auto_spec_collides()`,
rebuilt, and got **ALL PASS** everywhere - 57/57, 67/67, 182/182.

The repair pass found a **second** unpinned latch of the same shape that the
sabotage pass had not probed, in `auto_spec_qualifies()`, and confirmed it was
equally blind. Both are now covered by one row.

## The fix

Row **AS58**, asked of each of the two function bodies separately, four elements
each:

| element | expected | what it stops |
|---|---|---|
| the function is found | 1 | a rename answering with silence |
| `saved_tok_size = xctx->tok_size` | 1 | the latch going away |
| `xctx->tok_size = saved_tok_size` | 1 | the restore going away |
| `return` **between** the latch and the restore | 0 | a new way out of the latched region |

**The fourth element is the lesson of issue 0986 gap 4** and is the part the
sabotage pass did not ask for. Counting restores alone still passes when someone
adds a new exit path *inside* the latched region: the restore is still there, it
is just no longer on every path. 0986 gap 4 is exactly that defect, found in the
sibling guard in `token.c` after a loose row had let it through. A new helper
`as_between` returns the text strictly between two anchors so the row can ask
the question directly; its missing-anchor sentinel carries the word `return`, so
a vanished anchor reds the row rather than quietly answering zero.

## Measured teeth (repair pass, each variant built and run one at a time)

| variant | AS-TOKSIZE diagnostic | result |
|---|---|---|
| restored | `collides latch=1 restore=1 escapes=0` / `qualifies latch=1 restore=1 escapes=0` | ALL PASS (59 checks) |
| restore deleted from `auto_spec_collides` | `collides latch=1 restore=0 escapes=1` | **AS58 FAILED**, and AS58 alone |
| restore deleted from `auto_spec_qualifies` | `qualifies latch=1 restore=0 escapes=1` | **AS58 FAILED**, and AS58 alone |
| `break` in the collides loop turned into `return 1` - a new exit inside the latched region, restore untouched | `collides latch=1 restore=1 escapes=1` | **AS58 FAILED**, and AS58 alone |

The last row is the one worth keeping: latch=1 and restore=1, so the row shape
the sabotage pass suggested - and the shape `test_unused_attr_0970` used before
0986 gap 4 corrected it - would have passed while an exit path left the shared
token length holding an observer's leftovers.

## Note for whoever moves these call sites

There is no user-visible harm today: nothing reads `xctx->tok_size` after
`auto_spec_name()` returns at either of the two call sites in `src/token.c`.
That is why no behavioural row exists and why a structural one is the honest
answer. The guard is for the day a call site moves, which is the same reason
UB9's own comment gives in `token.c`.
