# 0897 — the plain-English protection for a refusal sentence can be switched off silently

**Status:** **OPEN**. Measured 2026-08-28 by the sabotage pass of backlog item
A12 and reproduced at the write-up. Predates A12 in form; A12 is what made it
load-bearing, by adding a ninth user-facing sentence that depends on it.

## The claim

The user's PLAIN ENGLISH ruling — *"wording too cryptic. Give it in plain
english with context, 9th grade level"* — is enforced by two hand-maintained
enumerations of refusal states:

* `A11_BANNED` and `opa_a11_sentences` in `tests/headless/test_op_annot.tcl`
  (no internal vocabulary, ASCII only, never contains its own state name);
* the A11-13 remedy loop there and its twin A11-11 loop in
  `tests/headless/test_results_freshness.tcl` (every refusal a user can act on
  says what to do next).

**Nothing asserts those lists cover every state the sentence minter can
render.** `cadence::_annot_tran_msg` has a `switch` with the states in it; the
test lists are typed out separately.

## Measured

Remove `viewerunread` from the jargon-ban list: `RESULT: ALL PASS (451 checks)`,
exit 0. Remove it from the remedy loop: `RESULT: ALL PASS (451 checks)`, exit 0.
**The check count does not even move**, so a reader diffing banners sees nothing.

## Why it matters more than it reads

This is the trap the suite's own A11-12 header warns about — *"a set with a hole
in it is how the hole got there"* — reached from the other direction. A future
tenth sentence can be minted, shipped, and read by a user with no plain-English
protection at all, and every runner stays green.

## The shape of a fix

Derive the loops' state list from the minter's own `switch` arms rather than
typing it twice: read `cadence::_annot_tran_msg`'s source, extract the arm
labels, and assert the enumerations equal that set. Then a new sentence with no
entry is a red, not a silence. Do the same for `cadence::_annot_msg` if it has
the same shape.

## Rows

The fix is itself a row: one structural check, both arms, in `test_op_annot.tcl`
beside A11-12, and the twin in `test_results_freshness.tcl`.
