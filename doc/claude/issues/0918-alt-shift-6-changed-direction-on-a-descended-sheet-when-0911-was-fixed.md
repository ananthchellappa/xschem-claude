# 0918 — the same two lines that fixed `6` on a descended sheet also moved
#         **Alt-Shift-6**, in both directions, and nobody was told

STATUS: OPEN
FOUND BY: the adversary/guard-coverage pass on item B2, 2026-08-28.
SEEN BY: NOTHING. No row anywhere in the tree exercises the transient chord on a
         descended sheet; every transient fixture is flat.
RELATED: [0911](0911-on-a-descended-sheet-with-no-ase-l-session-the-chord-never-repairs.md)
         (the change that moved it),
         [0917](0917-answering-always-from-the-top-of-the-hierarchy-moves-the-0911-defect-into-the-standalone-block-workflow.md)
         (the same ruling governs both — answer them together), 0893, 0895, 0896.

---

## 1. Why the transient chord moved at all

Issue 0911's fix is two lines inside `cadence::_annot_raw_candidate`'s
`netlist_dir` arm. That proc is not the operating point's private helper:
`cadence::_annot_tran_supply` (`utils/annot_mode.tcl:2062-2064`) calls it and
reads **both** halves —

```tcl
set cand [cadence::_annot_raw_candidate]
set path [lindex $cand 0]
set lvl  [lindex $cand 1]
```

— and hands them straight to `xschem annotate_op $path $lvl tran` (`:2118`). So a
change that was reasoned about, measured and rowed entirely on the `6` surface
silently changed **Alt-Shift-6 / Results > Annotate > Transient Node Voltages**
too. The item that landed 0911 did not say so, and its rule debt did not mention
it.

## 2. What the user gets, MEASURED, and it cuts both ways

Descended into `x1`, no ASE-L session:

**(a) Only the BLOCK's own transient on disk** (`sub.raw`, vector `v(a)`) — the
user simulated the block on its own from the descended sheet, which is exactly
what `xschem netlist` from that sheet produces:

* BEFORE: candidate `<nd>/sub.raw {} netlist_dir`; supply `1 ok <nd>/sub.raw`;
  the user sees the node voltages.
* AFTER: candidate `<nd>/top.raw 0 netlist_dir`; supply `-1 noraw <nd>/top.raw`;
  the user is told **"No simulation results are loaded, so there are no voltages
  to show. Run a simulation first, then try again."**

That sentence is false about a run that just finished, and — unlike the
operating-point refusal 0911 was filed about — **it names no path at all**, so it
is strictly *less* diagnosable than the sentence this branch has just spent an
item removing. It fails PLAIN ENGLISH's "say what happened AND what the user can
do about it" on the same reading 0911 did.

**(b) Only a CHIP-level transient on disk** (`top.raw`, vector `v(x1.a)`) — the
ordinary hierarchical bench:

* BEFORE: `-1 noraw` and that same false sentence.
* AFTER: `0 ok <nd>/top.raw` — the node voltages appear.

So (b) is a genuine repair, and it is probably the commoner case. **The point is
not that 0911's fix is wrong.** It is that a second user-facing surface moved in
both directions, no row measures either direction, and the user is about to
ratify option A vs option B without being told they are also ruling on this
chord.

## 3. A second, narrower defect in the same proc — reasoned, NOT measured

Inside `_annot_tran_supply` the waveform viewer is asked next and **its answer
overwrites `$path` but not `$lvl`** (`:2078`, inside the `if {[llength $vw]}` block at `:2077-2082`; the `$lvl` normalisation is at `:2104`):

```tcl
if {[llength $vw]} {
    set path   [lindex $vw 0]
    ...
}
...
if {$lvl eq {} || ![string is integer -strict $lvl]} { set lvl -1 }
```

Before 0911 the `netlist_dir` arm returned an empty level, so this normalised to
`-1` — "bind the raw to the current sheet" — and path and level were at least
*incoherently consistent*. After 0911 it returns `0`. So once the viewer supplies
the file (e.g. a session whose `ase::last_rawfile` is empty), **the path comes
from the viewer and the level comes from the `netlist_dir` arm**, and the raw is
bound to `xctx->sch[0]` on the strength of a file nothing in that arm chose.

This is spec landmine 4's device-path question with the two inputs sourced from
two different subjects. I could not stage it cheaply — it needs a live Tk viewer
*and* a session — so it is filed as reasoned, not measured, and it is the half a
row should chase first, because the reasoning says it is a real hole and the
measurement does not exist either way.

## 4. What would close it

1. **A running row** for §2(a): descend, only the block's own transient on disk,
   press Alt-Shift-6. It golds whatever the ruling in
   [0917](0917-answering-always-from-the-top-of-the-hierarchy-moves-the-0911-defect-into-the-standalone-block-workflow.md)
   §3 decides — option **D** on that menu exists precisely because the transient
   chord may deserve a different answer from `6`.
2. **A running row** for §2(b), which is a repair and should be locked in so a
   later ruling cannot silently undo it.
3. **A row for §3**, pinning that `$path` and `$lvl` are sourced from the same
   subject — whichever subject that ends up being.
4. If the refusal in §2(a) survives the ruling, its sentence must **name the
   file it looked for**, the way the operating-point refusal does. A refusal that
   names nothing is the one shape PLAIN ENGLISH forbids outright.
