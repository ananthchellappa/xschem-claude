# 0451 — the annotator block is blank, and nothing says which of four reasons caused it

Status: OPEN, NOT FIXED. Measured by S6's adversary pass on branch `annotate` at
9fe40128 + the S6 working tree. Filed because it is the FIRST-CLICK EXPERIENCE
of the plan's first user-visible deliverable and no check and no ledger row
names it.
Related: I3 (spec §5), issue 0446 (the one case that is NOT blank but wrong),
`src/op_annot.tcl` `op_annot::text`, `xschem_library/devices/annotate_params.sym`.

## What is wrong

Invariant **I3** says a missing vector renders BLANK — never `0`, never `NaN`,
never the previous run's number — and S6's carrier honours it exactly. The cost
is that **blank is now the single output of four completely different
situations**, and the user is given no way to tell them apart. All four measured
through the shipped symbol:

| what actually happened | what the user sees |
|---|---|
| no descriptor registered for this symbol type (a stock xschem with no PDK procs file sourced) | a corner tick, an `M1` label, and a zero-length block |
| `ref` names an instance that does not exist (renamed, deleted, or a typo) | empty block; the `T {@ref}` label does still print the dangling name |
| a raw is loaded but `xschem annotate_op` was never run (`xschem raw read` alone leaves `xschem raw annot` at -1, so `op_annot::_annotated` returns 0) | ten `label =` rows with nothing after the `=` |
| the raw is loaded and published, but this device's vectors are genuinely absent (no save cards — the ordinary case while S3 stays reverted) | the same ten `label =` rows |

There is no message, no status-bar hint, no differing render. The first row is
the worst of the four: on a tree with no PDK, `Simulation > Graphs > Add device
OP annotator` is **unconditionally enabled**, places a symbol, and produces a
**zero-length** string — which is indistinguishable from "the symbol is broken".

A related sharp edge in the same family: an instance with **no `ref` property at
all**, or with `ref=` explicitly empty, falls back to the K record's
`template="name=annot1 ref=M1"` and silently renders **whatever instance happens
to be called `M1`**. Measured. The `T {@ref}` label does print `M1`, so it is
labelled rather than anonymous — but nothing distinguishes "I chose M1" from
"I never set it".

## Why S6 did not fix it

Out of S6's Files cell, and every candidate fix is a user-visible behaviour
choice that S6 had no ratification for:

* printing `no descriptor for type <t>` in the block contradicts nothing in I3
  but does put PROSE where a user expects numbers, and it would appear on every
  annotator on a non-PDK tree;
* greying the menu item out when the registry is empty makes the feature
  invisible rather than inert, and the registry can be populated at any time by
  a user rc (I5), so the item would have to re-evaluate per open;
* a distinct render for "not annotated yet" versus "annotated but no vectors" is
  the genuinely useful one, and it is also the only one that needs the block to
  distinguish two states op_annot::text currently collapses.

## The open questions

1. Should the block say *why* it is blank, or is silence the right answer for an
   overlay that sits on a schematic?
2. Should `Add device OP annotator` be disabled — or should it warn once — when
   `op_annot::descriptor` would return nothing for anything on the sheet?
3. Should a carrier whose `ref` came from the template default (rather than from
   a selection or a hand edit) render differently, so "I never set it" is
   visible?

Whoever answers 1 should answer it for BOTH carriers — S9's draw-time overlay
inherits the same silence.
