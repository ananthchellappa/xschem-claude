# 0892 — five status-line rows assert an untrimmed sentence against the fitted line

**Status:** **OPEN**, latent on this machine. Found by the item A11 verification
pass, re-measured at write-up 2026-08-28. **Introduced by 0886** — the rows are
older, but the margin that made them safe was eaten by the plain-English
rewrite. Test defect, not a product defect.

## The shape

Five rows in `tests/headless/test_op_annot.tcl` read `xschem get statusmsg` —
which is the copy `cadence::_annot_fit` has already **fitted to 255 bytes** —
and compare it, byte for byte, against the **whole untrimmed** sentence. Four of
the five bake an absolute filesystem path into that expectation:

| row | expectation | bytes on this machine | headroom |
|---|---|---|---|
| N9 | `<mask 1> Could not read the results file <abs path>, so nothing was placed on the schematic.` | 220 | **35** |
| N10b | `<mask 1> The loaded results do not include an operating point, … <menu path>, then press again.` | 222 | **33** |
| N6 | `<mask 1> There is no results file at <abs path> yet. Run a simulation first.` | 206 | 49 |
| N8 | `<mask 1> Loaded results from <abs path>.` | 169 | 86 |
| A64-3 | same sentence as N8 | 169 | 86 |

The scratch path is derived from the repository root, so **moving this
repository into a directory 35 characters deeper reds N9 with no code change at
all**, and 33 deeper reds N10b. An earlier verifier reproduced exactly that:
running the identical suite from a longer directory reddened N6 and N9 and
nothing else.

## Why the pass caused it

The old wording for N9 was

    OP annotation ON (device OP info) -- COULD NOT LOAD <path>

which left roughly 113 bytes of margin. Plain English is longer — that is the
whole point of 0886 — and it consumed 78 of them. Issue **0639**'s budget
problem was moved out of the product, where `_annot_fit` now handles it and row
`A11-10` sweeps 578 combinations against it, and straight into the test, where
nothing checks it.

## The row that shows how it should be written

**N15**, in the same file, already does it right. It asserts the sentence at the
mint, and of the status line asserts only that it fits and that it is *either*
the whole sentence *or* a properly marked elision of its front:

    [expr {[string length $n15_line] <= 255 ? 1 : 0}]
    [expr {($n15_line eq $n15_msg) ||
           ([string range $n15_line end-2 end] eq {...} &&
            [string first [string range $n15_line 0 end-3] $n15_msg] == 0) ? 1 : 0}]

That is strictly stronger, not weaker: it still pins the sentence byte for byte,
and it additionally pins the relationship between the two channels. It cannot
red on a long path.

## What to do

Re-shape N6, N8, N9, N10b and A64-3 on N15's pattern — assert the sentence
where it is minted, assert the fitted line's *relationship* to it. Note N15
measures with `string length`; after issue **0887** the budget is **bytes**, so
the re-shaped rows should use the suite's own `opa_a11_bytes` helper rather than
`string length`, and N15 itself should be moved to it in the same edit. (N15 is
not at risk today — its own margin is not path-dependent in the same way — but a
character measure and a byte wall is exactly the mismatch 0887 was filed about.)

## Why no row saw it

Nothing measures the margin of a golden. `A11-10` measures the *product's*
worst case across 578 combinations; no row measures whether a *test's own
expectation* still fits. The failure mode is environmental — it reds on a
machine whose checkout is deeper, and nowhere else — which is the hardest kind
to attribute when it finally happens.
