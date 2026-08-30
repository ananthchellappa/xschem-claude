# 0975 — the "did not come back" sentence names one cause it cannot know, and says "1 devices"

**Status:** FILED, NOT FIXED.
**Found:** item S4a's verification pass, 2026-08-30; both halves reproduced
first-hand by the write-up before filing, by rendering the sentence from the
shipped code.
**Scope:** the wording of `ase::sim_why op_numbers_missing`. Two defects, one
sentence, one fix site.

## What this sentence is for

Issue **0965**'s headline demand: *a name that cannot be resolved must never
again be silent*. When the deck asks for a device's operating-point numbers and
no vector comes back, the run now says so. That part works and is pinned by
rows Q1–Q11.

## Defect 1 — it gives one confident cause, even when it cannot know

Rendered from the shipped code, with 1 device asked for and 0 back:

    This run asked your simulator for the operating-point numbers of 1 devices
    and only 0 of them came back, so the rest will show nothing at all on your
    schematic. These are the ones it did not answer for: @m.xz1.mzmod. That
    almost always means the deck spells a device differently from the way the
    schematic does. Save the schematic, netlist it again and re-run; if the
    same devices keep coming back empty, this run's log is where to look.

`ase::op_report_missing` deliberately treats a results file with **no Operating
Point plot in it at all** as "none of them came back" — `vars` stays empty, the
answered set is empty, and every device is missing. That is the right data
model. But the sentence it then prints tells the user, with no hedge, that the
deck spells a device differently and to re-netlist.

When *none* came back, the far likelier reason is that the operating point did
not converge, or the analysis was not run. `tb_bandgap`'s own run log already
carries `Warning: singular matrix: check node x1.xr7.x0.t1`. Sending that user
to re-netlist their schematic is a wrong diagnosis, delivered confidently, on
the one surface built to stop wrong impressions.

Note the asymmetry: when *some* came back and some did not, the misspelling
cause is exactly right — that is issue 0965's own case. It is only the
all-or-nothing case that needs a different sentence.

## Defect 2 — "of 1 devices"

Same render, verbatim: **`the operating-point numbers of 1 devices`**. There is
no singular form. A design with one device that fails to answer is not a
contrived case: issue **0973**'s bench asks for one bussed device name.

## Why no row catches either

Row **Q6** checks the sentence for code words (`blanket`, `tier`, `save card`,
`optier`, `.options`, `@m.`, `raw`, `vector`) and for a minimum length. Neither
grammar nor the correctness of a causal claim is a code word. Rows Q1 and Q4
drive 3-of-5 and 2-of-20 missing; **no row anywhere drives file-present-and-
zero-back**, which is the shape that gets the wrong cause. Q3 is a different
shape again (no file at all, which has its own sentence).

## What would pin it

A third sentence for "the results file is here but it holds no operating
point", with a row driving that shape; and a row asserting the singular form on
a one-device miss. Both belong with whoever writes the sentence.

## Not fixed here

Filing, not fixing, for the reason the sabotage pass established on this very
item: a change with no row watching it is not a fix.
