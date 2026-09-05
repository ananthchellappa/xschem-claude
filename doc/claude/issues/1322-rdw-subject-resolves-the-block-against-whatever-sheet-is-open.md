# 1322 — `rdw::_subject` resolves the block against whatever sheet is open, so a button edits a device the user is not looking at

**Status:** FILED, NOT FIXED. **This is the defect that reverted item B5-2.**
Measured 2026-09-04 on `fluid-editing` at `c940a5df` + item B5-2's working tree
(preserved as `doc/claude/op_param_batch/B5-2_working_tree_REFUTED.patch`, md5
`c51587ad91d65a05bbd07930ff237f9b`).
**Component:** `src/rdw.tcl` — `rdw::_hdr_instname`, `rdw::_subject`,
`rdw::push` / `rdw::render_pane`.
**Related:** issue **1314** (B5's own wrong-scope findings A6/A7), ruling
**DD-7** (a write touches one tier's own file), issue **1300** (the three key
lists), issue **1311**.

## The mechanism

`rdw::header` builds a block header as `"<instname>:<cadence path>"`.
`rdw::_hdr_instname` regexps it back:

```tcl
proc rdw::_hdr_instname {line} {
    if {[regexp {^(.*):(/.*)$} $line -> nm path]} { return $nm }
    return {}
}
```

It captures **both** halves and returns only the first. `rdw::_subject` then
re-resolves that bare name against the live editor:

```tcl
catch {set type [::op_annot::type $inst]}
catch {set cell [xschem getprop instance $inst cell::name]}
```

Both answer about **whatever schematic is open now**, not the schematic the
block was dumped from. Nothing clears `::rdw::blocks` on a load — `keep_latest`
(key 4) is the only writer that ever shortens the list — so a block outlives the
sheet it describes.

`M1` is the default `template="name=M1 …"` of every device symbol in this tree,
so two sheets holding an `M1` is the *ordinary* case, not a contrived one.

## The measurement

Reproduced independently by B5-2's write-up agent through the real `rdw::header`
and `rdw::push`; no hierarchy needed, both sheets top-level.

```
SHEET A: M1 type=vndev cell=vn.sym
HDR=M1:/
SHEET B: M1 type=vpdev cell=vp.sym  blocks=1
SUBJECT of the block on screen = instname M1 type vpdev class pcls cellname vp.sym
SAY=<Delete: removed gm from the annotation list for class pcls.>
NCLS(the sheet the block came from) owns=0
PCLS(the sheet now open)            owns=1 list={id ids 0} {gds gds 1}
```

The pane shows a block about an `ncls` device. The user presses Delete. The
button edits **`pcls`**, a class belonging to a device on a different sheet,
**reports success naming the wrong class**, and leaves the device on screen
untouched. Confirmed a second time with a real subcircuit fixture (header
`M1:/X1/`, pmos inside `X1`, nmos at top): the top-level `M1`'s class is edited.

This is the exact failure `_subject`'s own comment claims to prevent. B5-2 closed
the **block-index** axis (rows BT10/BT21/SD3, and `SAB-SUBJECT` reds eight rows)
and left the **sheet** axis wide open.

## ⚠ THE OBVIOUS FIX IS REFUTED — MEASURED, SO NOBODY SPENDS A RUN ON IT

Issue 1314's successor and B5-2's own adversary both proposed the same *"minimum
honest fix"*: have `_subject` compare `[rdw::_cadence_path [xschem get sch_path]]`
against the header's discarded path half and refuse on a mismatch.

**It does not catch the reproduction above.** Both sheets are top-level, so
`sch_path` is `.` on both and the header path half is `/` on both:

```
A: sch_path=<.> cadence=</> hdr=<M1:/>
B: sch_path=<.> cadence=</> hdr=<M1:/>      PATHS_EQUAL=1
```

The guard sees equal paths and waves the wrong-device edit straight through. The
axis is **sheet identity**, not hierarchy path. A path check would close only the
subcircuit variant and would read, in every review afterwards, as though the
whole defect were fenced.

## Recommended fix

**`rdw::push` captures the subject at dump time** — `type`, `class`, `cellname`
and the schematic file — into the block itself, and `rdw::_subject` reads it back
instead of re-resolving anything. The block already carries its own header line;
the subject belongs beside it. This is the same principle B5-2 already applied
when it chose to derive the subject from the block rather than build a parallel
`::rdw::subjects` list (invariant **I1**) — it simply was not carried far enough:
the block stores a *rendering* of the subject and then re-derives the *identity*.

Rejected alternatives:

* **Compare the cadence path** — refuted above by measurement.
* **Clear `::rdw::blocks` on every schematic load** — throws away the user's
  history for a problem that is about identity, and key 4 (`keep_latest`)
  already means the pane is expected to outlive individual dumps.
* **Refuse to act unless exactly one block is present** — makes the common
  multi-dump workflow unusable and still gets the single-block case wrong.

## The adjacent hole in the same guard

`op_param_lists::class` returns the **token** when the token has no class
mapping. So a symbol xschem cannot find (type `missing`) passes
`rdw::button`'s `class eq {}` guard and the user is told
*"Delete: gm is not in the missing annotation list."* Found incidentally while
building the hierarchy fixture. The capture-at-dump-time fix closes this too, if
`push` refuses to record a subject whose class did not resolve.

## Still open

Everything here. Nothing was fixed; item B5-2 was reverted in full and the tree
is back at baseline (window 76/86, store 102, keys 35).
