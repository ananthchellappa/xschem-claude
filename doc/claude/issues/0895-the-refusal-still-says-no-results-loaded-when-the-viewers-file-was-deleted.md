# 0895 — the refusal still says "no results are loaded" when the waveform window's file was deleted

**Status:** ✅ **FIXED 2026-08-28 (item A13), together with issue 0896 — they
are one conflation wearing two faces.** First measured 2026-08-28 at the item
A12 write-up, on both arms, against the tree that closes issue 0893, and
re-measured independently before the fix. **Issue 0893's commonest trigger was
the one 0893 did not cover**, and 0893's own comment names that trigger.

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

## The fix, as it shipped (item A13, 2026-08-28)

`utils/annot_mode.tcl`, no C change. The consult stopped answering a bare `{}`
to two different questions:

    if {$path eq {}} { return {} }
    if {![file exists $path]} { return [list $path $print filegone] }
    if {![llength $print]} { return [list $path $print nopoints] }
    return [list $path $print ok]

`cadence::_annot_tran_supply` carries a separate `$vseen` flag for *"the consult
succeeded"* and refuses `filegone` with the new state **`viewergone`**, above
the `annotate_op` hand-off, so nothing is attached and no unwind is owed.

### Before / after, same fixture, both arms

| | before | after |
|---|---|---|
| state | `noraw` | `viewergone` |
| sentence | *No simulation results are loaded, so there are no voltages to show. Run a simulation first, then try again.* | *The waveform window is showing the results file v_a10_vrun.raw, but that file is no longer on disk, so nothing was placed on the schematic. If a simulation is running, wait for it to finish, then try again.* |

The refusal itself was already right and stays right: `xschem raw loaded` is
`-1`, the mask is `0`, the sheet is bare.

### The sharper face, which the original filing did not record

With a perfectly good but **different** results file sitting at the preferences
path — the ordinary case, a previous run of the same cell — the old
fall-through did not merely say the wrong thing: it **annotated the wrong run**,
21 V on a sheet whose waveform window was showing something else. That is
0896's RULING D5-1 family reached from 0895's side, and it is what the driver's
ruling 1 (*never fall through to the file on disk when the two windows cannot be
compared*) is about. Row **V61** is its only behavioural witness; **B12i** is the
same thing through the real supply chain.

## Still for the user — now a recorded RULE debt, not an open question in a file

Under the INTENT OVER MECHANISM ruling, should this case refuse at all? The data
is in the waveform window's memory; only the file is gone. **It is not reachable
with any shipped verb, and that was checked rather than assumed:** `Raw *raw` is
a member of `Xschem_ctx` (`src/xschem.h`), one per window; `annotate_at`
resolves against the **current** window's raw; and the only shipped verb that
attaches one, `xschem annotate_op <path>`, reads **from disk** — which is the
thing that is gone. Building a cross-window read is a C change and its own item.
This item refuses with an honest sentence instead, and the choice is on the
user's ruling queue (`tests/headless/owed.sh add rule 0895`).

### Rows

* **V60** — the acceptance, alongside V55: seven legs, the seventh asserting
  the **wrong** sentence is gone rather than merely that some sentence appeared.
* **V61** — the sharper face above.
* **V62 / V63** — the structural and direct witnesses that an absent window and
  an absent file are no longer the same answer.
* **B12i** — the real supply chain, display arm.

Row **V37** (an unparseable candidate with **no** waveform window in play must
still say `noraw`) is green, in both arms.
