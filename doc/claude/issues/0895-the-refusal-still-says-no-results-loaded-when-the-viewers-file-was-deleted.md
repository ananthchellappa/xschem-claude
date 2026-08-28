# 0895 — the refusal still says "no results are loaded" when the waveform window's file was deleted

**Status:** **OPEN**. Measured 2026-08-28 at the item A12 write-up, on both arms,
against the tree that closes issue 0893. **Issue 0893's commonest trigger is the
one 0893 does not cover**, and 0893's own comment names that trigger.

## The claim

Issue 0893 gave the annotation a truthful sentence for the case where the
waveform window names its results file and that file cannot be read again off
disk. Its stated motivation, in `utils/annot_mode.tcl`, is *"a simulator
rewriting it in place, a truncated write, a corrupt header."*

**Most simulators do not rewrite in place. They unlink and re-create.** During
that window the file is **absent**, not corrupt — and 0893's guard never sees
it, because the consult itself gives up first:

    proc cadence::_annot_viewer_db {} {
      ...
      if {$path eq {} || ![file exists $path]} { return {} }

An empty return means `$vprint` is empty, and `$vprint` is the whole of 0893's
guard. So the arm falls straight through to `noraw`.

## Measured

Fixture: exactly row V55's, except the waveform window's results file is
**deleted** rather than overwritten with an unreadable one. The waveform window
is holding and plotting that database in memory throughout. Reproduced in a
`/tmp` symlink shadow tree with the repository untouched, on **both** arms
(`--nogui`, and `devdisplay.sh exec` on `:99` with **openbox 3.6.1** live):

    PROBEA state=noraw
    PROBEA msg=No simulation results are loaded, so there are no voltages to show. Run a simulation first, then try again.
    PROBEA ld=0 -1 mask=0 paint=d g 0 0

That sentence is word-for-word the one issue 0893's title condemns, produced by
the scenario 0893's own comment claims to cover.

## What is right about it, and what is wrong

**Right:** the refusal. Nothing was measured, so nothing is painted —
`xschem raw loaded` is `{0 -1}`, the mask is `0`, the sheet is bare. RULING
D5-1 holds.

**Wrong:** the reason. The user is looking at traces drawn from that very
database and is told no results are loaded. That is the PLAIN ENGLISH ruling
breached, and a wrong reason is the same defect class as a wrong number.

## The shape of a fix

The consult conflates two answers into one empty return: *"there is no waveform
window showing a transient for this sheet"* and *"there is one, and here is what
it is showing, but I cannot fingerprint or re-read its file."* Only the first
should read as "no viewer in play". A third element on
`cadence::_annot_viewer_db`'s answer saying **the consult succeeded** — separate
from the path and the fingerprint — would let the supplier tell an absent file
from an absent window and reach `viewerunread` (or a sibling sentence naming
deletion) instead of `noraw`.

Note this is the **same** conflation as issue **0896**, seen from the other
side. They should probably be fixed together.

## Rows

None. No row in the tree covers a deleted viewer file. A fix owes a behavioural
row in **both** arms, alongside V55, and it must leave row **V37** (an
unparseable candidate with **no** waveform window in play must still say
`noraw`) green.

## Still for the user

The larger question 0893 already recorded applies here more sharply: under the
INTENT OVER MECHANISM ruling, should this case refuse at all? The data is in the
waveform window's memory; only the file is gone. Reading it across the window
boundary needs machinery that does not exist today.
