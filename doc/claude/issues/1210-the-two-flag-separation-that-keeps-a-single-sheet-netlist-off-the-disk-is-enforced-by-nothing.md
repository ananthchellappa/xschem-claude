# 1210 - the two-flag separation that keeps a single-sheet netlist off the disk is enforced by nothing

STATUS: **FIXED** 2026-08-31 (item S6a, the repair pass). Row AS57 of
`tests/headless/test_auto_specialize_1201.tcl` now pins it.

## What was wrong

Not the product code - the product code was right. What was missing was anything
that would notice if it stopped being right.

`auto_spec_begin()` in `src/actions.c` sets two flags, and the eleven-line
comment above them exists for no other purpose than to explain why one flag will
not do:

* `auto_spec_on` means "a SPICE netlist run owns these tables". It is set to 1 on
  **both** arms - whether the designer asked for the whole design or for just the
  sheet in front of them.
* `auto_spec_whole` carries the mode, and decides on its own whether the tool
  mints cell names.

A reader arrives at two flags for what looks like one question and simplifies:
just do not open the window when only the sheet on screen is being written out.
That is wrong, and the cost lands on the user. `auto_spec_would_specialize()`
drops its note of what it read out of each cell's drawing whenever no run owns
the tables. With the window shut on the single-sheet arm, every question the
"your setting went nowhere" warning asks re-reads that drawing off the disk,
once per token. And the warning **has** to ask on that arm - it is precisely the
arm where the setting really did go nowhere and the designer has to be told.

## How it was found, and why no existing row could see it

The sabotage pass on item S6a built the simplification and measured it, rather
than reasoning about it. Changing `auto_spec_on = 1;` to
`auto_spec_on = whole ? 1 : 0;`, rebuilding, and running the tier gave
**ALL PASS everywhere** - the subject suite 57/57, `test_unused_attr_0970` 67/67,
`test_ase_core` 182/182.

It is not decorative either. `strace -e trace=openat` over the suite's own
fixtures counted **295** opens of the fixture cell drawings under the
simplification against **286** correct, with one fixture alone going 102 -> 111.

No behavioural row can see it because the harm is only time - the deck the user
gets is byte-identical either way. Grepping the whole file cannot see it either:
`auto_spec_on` is mentioned in three functions, and the two that already have
rows (`auto_spec_would_specialize`, `auto_spec_end`, both pinned by AS43) keep a
file-wide count non-zero no matter what `auto_spec_begin` does.

## The fix

Row **AS57**, asked of `auto_spec_begin`'s body alone with C comments stripped:

| element | expected | what it stops |
|---|---|---|
| the function is found | 1 | a rename cannot answer the row with silence |
| `auto_spec_on = 1;` appears | once | the ternary spelling |
| `auto_spec_on` is mentioned at all | once | the `if(whole) ... else ...` spelling, and any second assignment |
| `auto_spec_whole = whole ? 1 : 0;` appears | once | the mode moving off its own flag |

The third element is what makes the row tight: the literal count alone still
passes for `if(whole) auto_spec_on = 1; else auto_spec_on = 0;`.

## Measured teeth (repair pass, each variant built and run one at a time)

| variant | AS-TWOFLAG diagnostic | result |
|---|---|---|
| restored | `on=1 on1=1 whole=1` | ALL PASS (59 checks) |
| `auto_spec_on = whole ? 1 : 0;` | `on=1 on1=0 whole=1` | **AS57 FAILED**, and AS57 alone |
| `if(whole) auto_spec_on = 1; else auto_spec_on = 0;` | `on=2 on1=1 whole=1` | **AS57 FAILED**, and AS57 alone |

"AS57 alone" is the point of the issue: with a real binary built from the
sabotaged source, 58 of 59 checks still passed. Nothing else in the tree sees
this.

## Rejected alternative

Pin the call site too - assert `auto_spec_begin(global);` in
`src/spice_netlist.c` rather than `auto_spec_begin(1)`. Rejected as redundant,
and the sabotage pass measured why: hardcoding the argument reddens AS44, AS45
and AS46 from a real deck. The mode flag being told the truth by its caller is
already covered behaviourally; only the *separation* of the two flags was blind.
