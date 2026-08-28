# 0639 — `_annot_msg`'s types clause is unbudgeted and overflows the 255-char statusmsg seam

Status: **OPEN — measured, not fixed. PRE-EXISTING** (not introduced by any recent
step). Filed by the 0617+0618 crew, 2026-08-23. Related: **0617**, 0614.

## The seam

`xschem get statusmsg` reads `xctx->statusmsg_text[256]` (`xschem.h:1653`) and
**truncates at 255 characters**. Measured: sent 300, read back 255.

## The defect

`cadence::_annot_msg` (`utils/annot_mode.tcl:227`) appends a "no OP descriptor for
symbol type(s): ..." clause listing up to four symbol type names. It clips the *list*
at four entries but never budgets the *line*. Measured by exhaustive enumeration over
4 masks × 8 states × 3 causes × 4 type-lists × 3 paths: **81 combinations exceed 255
characters, worst case 351.** The current shipped worst case with no new clause is
**241** — 14 characters of headroom.

This is not synthetic. A shipped ASE testbench sheet carrying four
`xschem_library/analyses/*.sym` symbols (`netlist_command_analysis_acstb`,
`_dcinc`, `_noise`, `_tran` — 29-30 chars each) produces it:

```
OLD(len 314) as the user saw it (C truncates at 255):
  |... -- NO RAW FILE: /home/analog/dev/xschem-claude/sky130_tests/simulations/
   tb_bandgap/tb_bandgap_ase.raw -- no OP descriptor for symbol type(s):
   netlist_command_analysis_acstb netlist_command_analysis_dcinc n|
```

The line dies mid-token. Whatever the user most needed is whatever happened to be last.

## The choice nobody has made

The 0617 attempt budgeted the **path** (full → basename → ellipsised → empty) so the
new sentence would fit, which changed the pinned case-(a) message from a full path to
a basename. That attempt was reverted, so the shipped behaviour is again "clip the
type list at 255, keep the full path".

**Neither is obviously right, and it is a user-visible choice**: is the raw's directory
or the list of unrecognised symbol types the thing worth keeping when the line will not
fit? A third option is to stop treating 255 as a wall — raise `statusmsg_text[256]` in
C — but that is a rebuild plus a mirrored-field edit for a display-layer problem.

## Recommended

Decide it as part of 0617's retry (which must fit a new sentence into the same line
and therefore cannot avoid the question), and record the ruling. Until then, note that
`_annot_path`-style path shortening is **not** a free win: it silently rewrites a
message the 0617 brief explicitly pinned as unchanged.

---

## THE CHOICE IS NOW MADE — a third way, landed with issue 0886 (2026-08-27)

STATUS: **decided provisionally, ratification owed** (`owed.sh` rule debt 0886).

The plain-English pass could not leave this open: plain English is longer than
jargon, and the half of a sentence that gets cut is the "what to do" half — which
is exactly the half the user asked to have added.

**The headroom recorded above is gone, and it was gone before the rewrite.**
Measured on the shipped binary 2026-08-27, with none of 0886's wording in it:
mask 7 + the `noop` state + five symbol types builds **257** characters,
`xschem get statusmsg` reads back **255**, and the tail dies mid-token —
`nmos pmos res cap ...` arrives as `cap .`. So the status line and the CIW copy
already disagreed on a reachable combination.

**Neither of the two options in "The choice nobody has made" was taken.** Nothing
structural is dropped — not the path, not the symbol-type list:

* `cadence::_annot_fit` (`utils/annot_mode.tcl`) is the ONE place that knows the
  number. It shrinks a character window until its contents fit **252 bytes**,
  cuts at a **space** inside it and appends `...`, so the elision is visible and
  never lands inside a token.
* `cadence::_annot_say` is the ONE renderer. The **CIW gets the sentence whole**
  — it is the record, and it scrolls, so it has no budget. The **held status
  line gets the fitted copy**. On the longest combinations the two channels
  therefore differ on purpose.
* The C wall was NOT raised. `statusmsg_text[256]` is untouched; this is a
  display-layer fix, as the note above argued it should be.

**What the user still has to rule on** (carried in 0886's rule debt): ratify the
split, or say which channel should win. The rejected alternative is to fit inside
the mint so both channels say the same shorter thing — they would agree, but the
CIW record would lose the tail forever.

**What holds it honest.** Rows **A11-1** (the budget as a unit: a line that fits
comes back byte-identical; a line that does not is cut at a space that really is
in the original, and marked), **A11-2** (end to end — the CIW keeps the whole
sentence, the bar is fitted, and *every* status-line write in the mint file goes
through the budget), **A11-9** (the unit itself — see below) and **A11-10** (578
combinations, every one ≤ 255 **bytes** after the budget) of
`tests/headless/test_op_annot.tcl`.

## ⚠ THE FIRST VERSION OF THIS FIX COUNTED THE WRONG UNIT — issue 0887 (2026-08-28)

`_annot_fit` measured with `string length`, which counts Tcl **characters**,
while the wall it defends is a **byte** count. The comment above defended that as
safe because every minted sentence is plain ASCII — true of the wording, false of
the sentence, because the `loaded`, `failed` and `noraw` clauses paste the user's
own results-file path into it. A project directory outside ASCII therefore put
the amputation straight back: **225 characters, 256 bytes**, waved through, cut
by C at 255 with no `...`.

`cadence::_annot_bytes` is now the one ruler, and row **A11-9** measures the
round trip through `xschem statusmsg -hold` → `xschem get statusmsg` against a
non-ASCII path. Full write-up in issue **0887**.

**One consequence worth knowing.** Row N15's claim had to move off the status
line and onto the minted sentence: in plain English that combination is 276
characters, so the symbol type the row exists to name now sits inside the elided
tail. Of the status line N15 asserts only that it fits and that it is either the
whole sentence or a properly marked elision of its front.

## HOW OFTEN THE ELISION ACTUALLY FIRES, and what it eats — measured 2026-08-28

The split above was ratified as a *decision*. It was never given a *frequency*,
and the frequency changes how the decision reads.

With an ordinary project path —
`/home/analog/proj/bandgap/tb_bandgap/simulation/run.raw`, 55 characters — and
sweeping all 8 masks × 8 states × {no symbol types, one, five}:

| | |
|---|---|
| combinations | 192 |
| elided on the status bar | **62** |
| widest sentence | **373 bytes** |

The same sweep against the *old* cryptic wording exceeded 255 in **1** of 192.
So the bar now shows a marked but truncated line about a third of the time,
where it used to show a whole one almost always. That is the cost of plain
English, and it is a real cost rather than a theoretical one.

**And the half it eats is the actionable half.** Mask 7 + `noop` fits as

    … values to show. Load a different results file from Waves...

The derived *Waves > Op Annotate* path — the entire point of the RULING D5-4 fix
in 0886, and the only remedy that sentence offers — is exactly the text that
gets cut. The CIW copy still carries it whole, which is why the split was chosen;
whether a user who is looking at the status bar ever reads the CIW is the part
only they can answer.

**No row can see this.** `A11-10` proves every fitted line is inside the budget,
which is a different claim from "the line still tells the user what to do". Row
`A11-11` matches the bare token `Load ` against the **unfitted** mint output, so
it survives the cut. If the user rules that the remedy must always survive, that
needs a new row asserting the remedy imperative in the **fitted** copy — and it
would red today, on 62 of 192.
