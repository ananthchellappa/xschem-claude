# 0893 — the transient refusal blames a missing results file while the waveform window is plotting it

**Status:** **FIXED** 2026-08-28 (backlog item A12, alongside issue 0891).
**Wording NOT ratified** — recorded as `owed.sh add rule 0893`, and a `look`
debt is open for the sentence, which no user has ever seen.

## The claim

`cadence::_annot_tran_supply` (`utils/annot_mode.tcl`) could return `noraw` —
whose user-facing sentence is

    No simulation results are loaded, so there are no voltages to show. Run a
    simulation first, then try again.

— while holding the path the 0881 viewer consult had **successfully** reported.
That happens when the consult finds the waveform window's own results file but
the annotation then cannot read that file again off disk: a simulator rewriting
it in place, a truncated write, a corrupt header.

The user is looking at traces drawn from that very file and is told no results
are loaded. That breaches the PLAIN ENGLISH ruling (say what actually happened)
and is the same defect class as a wrong number: **a wrong reason**.

## Not the same thing as V51

V51's wrong sentence on the display arm was a **symptom of issue 0891's dead
consult**, not this. With 0891's fixture repaired, V51 refuses with the correct
`viewerdiff` state and the correct file-naming sentence, product untouched
(measured: the shadow-tree experiment in 0891's close changed no product byte).
This issue is the case that remains **after** 0891 is closed, and no row in the
tree covered it.

## What shipped

**A new refusal state, `viewerunread`, and its own minted sentence.** Three
edits, all in `utils/annot_mode.tcl`:

1. `cadence::_annot_tran_supply` — at the second failure arm only:

       if {[llength $vprint]} { return [list -1 viewerunread $path] }
       return [list -1 noraw $path]

   **The guard is the condition, not the arm.** `$vprint` is non-empty *only*
   when the viewer consult above succeeded — i.e. the waveform window is on
   screen showing a transient and this is the very file it named. With no viewer
   in play the arm must still say `noraw`, which is row **V37**'s job.

2. `cadence::_annot_tran_msg` — one new arm, minted in the one place RULING
   D5-4 requires, and the unknown-state error string now names it:

       The waveform window is showing the results file <name>, but that file
       could not be read again just now, so nothing was placed on the schematic.
       Plot the results again in the waveform window, then try again.

3. `cadence::annot_tran` — **the ordering is the guard.** The new test sits
   BELOW the `stale` test (an out-of-date file on disk is the older, more
   specific complaint) and ABOVE the `noraw` test, because `loaded` is `-1` on
   this path too and the `noraw` branch would otherwise swallow it and put the
   user straight back where they started. Nothing has been attached at that
   point, so no unwind is owed and RULING D5-1 holds byte-for-byte: the mask is
   untouched and the sheet stays bare.

The state is held to the same plain-English standard as its seven siblings:
added to `A11_BANNED`, to `opa_a11_sentences`, to the A11-13 remedy loop in
`tests/headless/test_op_annot.tcl` and to the twin A11-11 loop in
`tests/headless/test_results_freshness.tcl`. It carries a remedy
(`Plot ` … `try again`), is plain ASCII, and never contains its own state name.

## Acceptance

Row **V55** of `tests/headless/test_op_annot.tcl`, **both arms**. Six claims,
the same six V51 makes: the state is its own named refusal and not the
no-results one; the CIW got the sentence once, tagged as a warning; the held
status line carries it and names the file the waveform window is showing;
`xschem raw loaded` is `{0 -1}`; the annotation mask is 0; the sheet is bare.

Measured green: `--nogui` `ALL PASS (451 checks)`, and
`devdisplay.sh exec` on `:99` (openbox 3.6.1 live) `ALL PASS (458 checks)`.

## The rejected alternative

**Keep the state `noraw` and reword its sentence.** Rejected: one state mints
exactly one sentence (RULING D5-4), so the plain never-simulated case would then
inherit a sentence about a waveform window that is not open.

## The larger question, still open, for the user

Should this case refuse at all? The INTENT OVER MECHANISM ruling points at
falling back to the copy of the data the waveform window **already holds in
memory** rather than going back to disk — which is the argument that closed
0881. That needs a cross-window value read that does not exist today and was far
outside item A12's blast radius. Recorded as a `rule` debt.

---

## Measured after the close, and it narrows what this fixed

Two cases reach the *same* wrong sentence and this fix does **not** cover
either, because both make `$vprint` empty — and `$vprint` is the whole of the
guard. Both were reproduced on both arms at the item A12 write-up, against this
very tree:

* **Issue 0895 — the file was DELETED, not corrupted.** Most simulators unlink
  and re-create rather than rewrite in place, so the commonest instance of the
  trigger named in the code comment above ("a simulator rewriting it in place")
  leaves the file **absent**. `cadence::_annot_viewer_db`'s own
  `![file exists $path]` return then kills the consult before `$vprint` is ever
  set, and the user gets `noraw`: *"No simulation results are loaded"*, with the
  traces still on screen.
* **Issue 0896 — the fingerprint could not be computed.** A run still filling
  has `No. Points: 0`, so `cadence::_annot_db_print` answers `{}` while the
  consult itself succeeds. That case does not merely miss this sentence; it
  skips the RULING D5-1 two-window compare and **paints another run's numbers**.

Both are the same conflation: `$vprint` is standing in for *"the consult
succeeded"* and cannot. **The honest repair is one repair** — have
`cadence::_annot_viewer_db` report success as its own answer, separate from the
path and the fingerprint — and it should be done for 0893, 0895 and 0896
together.

## Guard coverage

The arm, its condition, its sentence and its ordering are each seen by a row
(V55 and V37, both arms; verified by four sabotage variants). The **no-unwind**
guarantee this arm's comment states was **not** — giving the arm an unwind it
must not have left the whole tree green. Filed and fixed as issue **0894**;
row V52 now names `viewerunread` in its roll-call.
