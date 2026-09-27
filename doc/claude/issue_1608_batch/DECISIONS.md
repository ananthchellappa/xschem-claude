# Decisions — issue 1608 batch

## H1 — the driver's prediction, registered BEFORE Stage A reports

Recorded at `91bb1bd7`, so the measurement tests it rather than confirming it. The last four
batches each had a crew catch the driver overstating his instrument; registering the guess is how
that stays visible.

**Prediction: (C) aborts on all three arms and (A)/(B) is unreachable from any format string in
this tree — so the fix is three one-line bounds plus a comment, and the valuable output is the
reachability census rather than the patch.**

The reasoning:

* **(C) is a fortified `sprintf` into a local array**, which is the exact shape that gave 1606 its
  `*** buffer overflow detected ***` at thirteen sites. `_FORTIFY_SOURCE` is 3 by default on this
  build, and it can size a local. So a loud abort is the expected outcome, not silent corruption.
* **(A)/(B) needs a conversion SPEC over 49 characters**, which means something like `%` followed
  by fifty flag or digit characters. Nothing writes that by hand, and this tree's formats are all
  literals. ⚠ This is the bullet most likely to be wrong, because "all literals" is an assertion
  about ~748 call sites that the driver has not checked.
* **The reachability claim inherited from 1606 will survive but narrow.** That batch checked float
  callers; it did not check `%-Nd` widths or `%*d`. The census should therefore find the boundary
  closer than 24 characters is comfortable, without finding a live overflow.

⚠ **What would refute it.** Any arm where (C) corrupts silently instead of aborting — which would
matter, because 1606 measured that a destination reached through a pointer parameter gets no
fortify check at all, and `nstr` is a local only from `my_snprintf`'s own frame; a live caller that
already produces over 49 characters; a non-literal format string anywhere; or (A)/(B) turning out
reachable, which would make the `nfmt` half the headline rather than a footnote.

⚠ **What must NOT happen if the prediction holds.** "Latent" is not a reason to close it. The
guard is two lines, the function has ~748 callers, and latency here is a property of today's format
strings rather than of the code — one `%-60d` in a future commit makes it live with nothing in
`util.c` having changed. 1606's own prediction was right about the number and wrong about the
reason, and its warning ("an unreachable defect is one refactor away from a reachable one") turned
out to be measurable rather than rhetorical: one token's change produced two segfaults.

## H2 — truncate-vs-refuse is internal unless a user reads the difference

Bounding a conversion changes what `my_snprintf` returns in a case that today corrupts the stack,
so there is no existing correct behaviour to preserve. That makes the choice internal engineering
and the driver's, **unless** the measurement shows a live caller whose string a user reads changing
shape — in which case it becomes a ruling and gets filed rather than decided.

⚠ The inherited argument needs re-running rather than copying. 1606 found truncation *there* was
user-visible badly, because truncating a formatted number amputates its exponent and suffix and
leaves something that reads as a different value. Here the truncation is of **one conversion inside
a longer string**, which may or may not carry the same hazard. Stage B answers it; Stage A's census
says whether any live caller can reach the case at all.

## H3 — internal test engineering is the driver's and the crews', not a ruling

How a row is structured, whether a fence is behavioural or static, what the suite is named and
which list it registers in are decided here and stated, never queued. Per the standing instruction:
the user does not work inside the harness, and a question about it is not theirs.
