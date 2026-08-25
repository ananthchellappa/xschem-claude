# 0684 — ASE-L's raw-attach arm guards on `raw loaded`, so it can show the PREVIOUS run's numbers forever, and an unrelated waveform raw blocks it entirely

STATUS: OPEN — measured 2026-08-25 by issue 0682's adversary pass. **Filed, not fixed.**
FOUND IN: `ase::ui::annot_ensure_loaded` (`src/ase_window.tcl`), shipped by
[0682](0682-annotation-visibility-belongs-in-ase-l-results-annotate.md) decision D8.
RELATED: [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md) (the other half of
"annotation and its session are not actually bound"), invariant **I3**.

---

## 1. What D8 promised

0682 ruled that ASE-L's `Results > Annotate` is the only annotation visibility
control. Decision D8 went one step further, on measurement: ASE-L **never** loads
a raw into the DESIGN context —

```
grep -rn 'annotate_op|raw_read' src/ase.tcl src/ase_window.tcl src/wave_viewer.tcl
   -> nothing before 0682 (the waveform viewer attaches into its OWN context)
```

— so after a real `Netlist and Run` the design has no database, and a
visibility-only tick would turn annotation on and render BLANKS (invariant I3).
D8 therefore has the tick attach the session's raw when the design has none.

The guard it uses is one line:

```tcl
set ld -1
catch {set ld [xschem raw loaded]}
if {[string is integer -strict $ld] && $ld >= 0} { return }
```

with the header rationale *"`xschem raw loaded` >= 0 means this context already
has one — possibly the very run the user is looking at"*.

**That sentence is the defect.** `raw loaded >= 0` answers "is SOME database
attached here", not "are THIS session's CURRENT results attached here". Two
distinct failures fall out of it.

## 2. Defect A — the previous run's numbers, forever (invariant I3)

`ase::backend::ngspice::raw_file` is a **stable path** — `<rundir>/<cell>_ase.raw`
— which each run overwrites in place. So after run 2 the guard sees the run-1
database still attached, early-returns, and the schematic keeps painting run 1.

Measured headless:

```
run 1 annotated              -> screen shows v(a) = 111
run 2 written to the SAME path -> the file on disk now says 999
untick, then re-tick          -> screen STILL 111
   (unticking never calls the loader; re-ticking hits the early return)
explicit `xschem annotate_op` -> 999
```

Invariant I3 names this exact outcome: *"A missing vector renders BLANK. Not 0,
not NaN on screen, **not the previous run's number**."* The same phrase is in
`actions.c:1638`.

⚠ **Honest scoping**: the staleness is largely PRE-EXISTING — the deleted View
pair never loaded anything either, so it was stale by construction. What is NEW is
that (a) D8 claims to make the numbers live and only does so ONCE, and (b) ASE-L
now positively asserts, per session, that results exist — so the control says
"these are your results" while showing the previous run's.

## 3. Defect B — an ordinary waveform graph blocks the attach entirely

Measured:

```
after a bare `xschem raw_read`:
   xschem raw loaded      ->  0        (a database IS attached)
   xschem raw annot       -> -1 0 -1   (but nothing is ANNOTATED)
   xschem raw value v(a) -1 ->  0      (a fabricated 0, where the real value is 1.25)
```

That state is reachable in the design context by ordinary waveform-graph use —
`create_graph.tcl:40`, `xschem.tcl:5832`, `:6123`, `:14543` all call `raw_read`.
With such a raw present the product was probed directly: `annot_ensure_loaded`
returns without annotating, `annot_p` stays -1, the mask turns on and **nothing
renders**. It is also the one path in the proc that echoes nothing, so the user is
told nothing either.

**It is NOT an I3 violation, and that matters.** Every C consumer gates on
`xctx->raw->annot_p >= 0` (token.c:4339, 4828, 4920, 5006, 5101, 5174) and the Tcl
overlay gates on `op_annot::_annotated` (op_annot.tcl:883), measured returning 0 in
that state. The fabricated 0 does **not** reach pixels; the result is blank, not a
plausible wrong number. The defect is a dead-looking control, not a lie on screen.

## 4. Why one line covers both

The question `annot_ensure_loaded` means to ask is answered by
`xschem raw annot` (`annot_p >= 0`) plus "is this THIS session's raw" — not by
`raw loaded`. `op_annot::_annotated` (op_annot.tcl:781) already ships the correct
three-term test and is the obvious donor.

## 5. Options — none chosen, this is a ruling for the user

1. **Swap the guard for the three-term test** (`_annotated`-style: live
   backannotate AND `raw loaded` >= 0 AND `raw annot` >= 0), and re-annotate when
   the session's raw file is NEWER than the attached one (`file mtime` against the
   load time). Smallest change that fixes both defects. Cost: a visibility tick
   now re-reads a file, so a large raw makes the menu click slow.
2. **Attach unconditionally on every tick-ON.** Simplest to reason about, but it
   throws away a database the user may be looking at in a graph — the exact thing
   the current guard's second warning exists to prevent.
3. **Attach on the SESSION's run completion instead of on the tick** (ASE-L calls
   `annotate_op` when a run finishes, and the tick stays visibility-only). Puts
   the load where the new data actually arrives, and makes the tick cheap again.
   Largest blast radius: it changes what a completed run does to the design.

Recommendation, unratified: **(1)**, because it is the only one that keeps both of
D8's promises (the numbers are live, and a good database is never thrown away),
and because the correct predicate already exists and would otherwise be a fourth
copy of a question this codebase already asks three ways.

## 6. Acceptance rows for whoever fixes it

| row | claim |
|---|---|
| 1 | run 1 annotated, the SAME raw path rewritten with different values, untick + re-tick -> the NEW values are on screen |
| 2 | a `raw_read` database present with `annot_p` = -1, tick ON -> the session's raw is annotated and the numbers render (today: nothing renders and nothing is said) |
| 3 | a database that IS this session's current annotated raw -> the tick does NOT re-read it |
| 4 | the failure path still echoes through `ase::echo`, never silently |
