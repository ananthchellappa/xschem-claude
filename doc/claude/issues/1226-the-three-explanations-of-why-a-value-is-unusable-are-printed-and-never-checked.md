# 1226 - the three explanations of why a value is unusable are printed and never checked

**Filed by** item S6b's sabotage pass, 2026-08-31. **Severity** low-medium (PLAIN
ENGLISH ruling). **Area** `ua_value_fault()`, src/token.c.

## What is wrong

When a designer types a value XSCHEM cannot pass down, the warning names **which way**
it is unusable, in one of three phrases:

* "is nothing but blank space"
* "has a space, a tab or a line break in it"
* "has no letters or digits in it"

**No check anywhere reads any of them.** They appear in the repository only inside the
gitignored `tests/headless/test_auto_specialize_1201.log`. The rows that look at this
sentence test for `one word`, which lives in the fixed part of the advice and survives
any change to the three branches.

## Measured

Collapse all three returns to a single string and rebuild:
`test_auto_specialize_1201` **77 checks all pass**, `test_unused_attr_0970` 67.

A designer who typed `---` is then told:

> the value you typed **is nothing but blank space**

which is simply not true of `---`, on the one surface the **PLAIN ENGLISH** ruling
governs. The suite is green throughout.

## The repair

Three elements, one per shape, in the rows that already netlist those fixtures --
AS59 (space) expects "is nothing but blank space", AS62 (punctuation) expects "has no
letters or digits in it", AS63 (trailing space) expects "has a space, a tab or a line
break in it". They cost nothing: those rows already capture the sentence.

## Note

The function is correct today. This is a guard with no row, filed so the next hand
that touches the wording finds out from a suite rather than from a user.

---

## CLOSED 2026-08-31 by item S6b's REPAIR pass

New row **AS83**, and it is one row rather than elements on four, because what
has to be true is that the four explanations are FOUR: each shape gets its own
words, and the number of distinct explanation clauses across the four fixtures
is 4. There are four now, not three -- issue 1227 added the `@`/`%` one.

Measured by collapsing all four returns of `ua_value_fault()` to one string:
AS83 goes red and nothing else does.
