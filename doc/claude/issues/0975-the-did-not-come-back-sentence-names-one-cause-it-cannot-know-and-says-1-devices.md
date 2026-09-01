# 0975 — the "did not come back" sentence names one cause it cannot know, and says "1 devices"

**Status:** **FIXED 2026-08-30 by item S4b**, both defects. (Filed by item
S4a's verification pass; the finding below is kept because it is the
measurement — but see **THE CORRECTION** at the end, one detail of it did not
reproduce.)
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


---

# THE REPAIR, 2026-08-30 (item S4b)

## Defect 1 — a cause the code never established

A third kind, **`op_numbers_none`**, is minted for the all-or-nothing shape:

> This run asked your simulator for the operating-point numbers of **1 device**
> and not one of them came back, so no device numbers will appear on your
> schematic at all. The results file `zzcell_ase.raw` is there and holds the rest
> of the run, but there is no operating point in it. Something stopped the
> operating point itself from finishing, and this run cannot tell you what: open
> the log your simulator wrote for this run and read what it printed there.

It names **no cause**. It says what was actually found — the file exists, the
operating point is not in it — and points at the one place that can answer.

`ase::op_report_missing` chooses between the two kinds (GUARD **NB-ZERO**) and
now **returns** the kind it said, so a row can assert the shape without reading
prose. Rows **Q12**, **Q15**, **Q16**.

**The cause clause STAYS on the some-came-back shape**, because there it is
right — that is issue 0965's own case, and throwing it away would undo the
sentence 0965 was closed on. Row **Q13** is the control that says so.

## Defect 2 — "of 1 devices"

`ase::sim_plural` is the one place a singular or plural wording is chosen. Both
offending clauses go through it: there were **two**, not one — the list intro
`These are the ones it did not answer for` was plural-only as well. It takes both
wordings whole rather than a stem and a suffix, because one caller is a clause
and not a word. Row **Q14** drives both kinds and both clauses.

## ⚠ THE CORRECTION

The filing says the likelier reason for the all-or-nothing shape is an operating
point that did not converge, and cites `tb_bandgap`'s own log carrying
`Warning: singular matrix`.

**That did not reproduce.** The bench was rendered and run through the real
ngspice for the measurement pass: exit 0, a 284,283-byte results file, an
Operating Point plot complete with **891 vectors**, and **zero** singular-matrix
and **zero** convergence lines anywhere in the log.

So the defensible statement is *the code asserted a cause it never established* —
which is provable from the source alone, and is what the fix acts on — **not**
*the real cause is non-convergence*. The replacement sentence names no cause for
exactly that reason, and a comment in `src/ase.tcl` says so at the site, so
nobody puts one back.

## ⚠ THE FIRST FIX MADE THIS ISSUE'S OWN EXAMPLE WORSE, AND THE VERIFICATION PASS CAUGHT IT BEFORE IT SHIPPED

`ase::op_report_missing` chose between the two sentences on **the count alone**:

    if {[llength $miss] == [llength $devs]} { ... op_numbers_none ... }

"Not one of the devices I asked about came back" and "this results file holds no
operating point" are two different facts, and the proc holds the one that
separates them — `vars`, the operating-point plot it read three dozen lines
earlier. A sheet with **one** device whose name is spelled differently in the
deck leaves every requested device missing while the operating point sits
complete in the file. On that input the run said, verbatim:

    This run asked your simulator for the operating-point numbers of 1 device
    and not one of them came back, so no device numbers will appear on your
    schematic at all. The results file zzcell_ase.raw is there and holds the
    rest of the run, but there is no operating point in it. Something stopped
    the operating point itself from finishing, and this run cannot tell you
    what: open the log your simulator wrote for this run and read what it
    printed there.

There **is** an operating point in it. Nothing stopped it finishing. The user is
sent to a log with nothing wrong in it. And this issue's own worked example — a
single `@m.xz1.mzmod` — is exactly that shape, so the first fix for 0975
reproduced 0975 on the very case that motivated it: **a cause the code never
established**, now stated by the sentence written to stop doing that.

**Fixed before commit.** The branch now also requires that no operating point
was found at all:

    if {[llength $miss] == [llength $devs] && ![llength $vars]} {

On the same input the run now says *"only 0 of them came back ... That almost
always means the deck spells a device differently from the way the schematic
does"* — which is right, and is the sentence issue 0965 was closed on. Row
**Q17** in `tests/headless/test_ase_optier_0963.tcl` pins it: it was written
first, watched fail with `{op_numbers_none 0 1}` against the expected
`{op_numbers_missing 1 0}`, and passes on the fix. `Q12` was blind to it because
its fixture writes a transient with no operating point, so it only ever
exercised the arm where the sentence happens to be true.

