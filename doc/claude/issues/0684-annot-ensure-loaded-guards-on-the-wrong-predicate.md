# 0684 — ASE-L's raw-attach arm guards on `raw loaded`, so it can show the PREVIOUS run's numbers forever, and an unrelated waveform raw blocks it entirely

STATUS: **STILL OPEN. Fix ATTEMPTED 2026-08-25, REFUTED and REVERTED the same day —
read §7 before retrying.** Originally measured 2026-08-25 by issue 0682's adversary pass.
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

### ⚠ THE USER ASKED THE RIGHT QUESTION AND IT REFUTES THIS SECTION'S FRAMING

2026-08-25, asked to choose, the user did not pick one:

> A run that finishes is an event. It should trigger such things as these updates
> of annotation info, etc. What does "run-just-finished" currently trigger?

Measured, `ase::ui::run_finished` (`src/ase_window.tcl:4623`), on exit code 0:

```tcl
ase::session_setattr $key results [ase::last_result]
ase::ui::refresh_output_values $key
ase::ui::set_status $key ok
after idle [list ase::ui::auto_plot_idle $key]
```

It **already** re-reads the results, refreshes the output values, and auto-plots.
**Annotation is the only consumer of new results that is NOT on this event.**

Option (3) is therefore described wrongly above. "Largest blast radius ... it
changes what a completed run does to the design" is false: a completed run already
updates outputs and redraws plots. Putting annotation there makes it
**consistent**, not exceptional — and it is the only option that removes the
staleness question instead of managing it, because the tick stops being a data
operation at all.

**Direction taken: (3)**, on the user's reasoning, in the absence of an objection.
The residual to MEASURE rather than assume: whether a completed run should refresh
annotation on a design whose annotation is currently OFF (cheap and harmless, or a
surprise?).

Superseded recommendation, kept for the record: **(1)**, because it is the only one that keeps both of
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

---

## 7. ⚠ ATTEMPT 1 (2026-08-25) — REFUTED AND REVERTED. READ BEFORE RETRYING

Fixed together with [0683](0683-annotation-is-reachable-with-no-bound-ase-l-session.md)
(the two are one defect) and reverted together. The full proc inventory and the
0683-side refutations are in **0683 §7**; this section records only what it settles
about 0684.

### What the attempt got right, and should be re-used

The one-line `[xschem raw loaded] >= 0 -> return` guard was replaced by
`ase::ui::annot_attached_current {key np}`, which **calls** `op_annot::_annotated`
rather than copying its three terms a fourth time (invariant **I1**), and adds two
terms the old guard lacked: path identity (`file normalize [xschem raw rawfile]`
against the session's normalized path) and a freshness stamp
`annot($key,src)` = `{normpath mtime size}`. Every term is catch-wrapped and
**every catch falls to 0 = RE-ATTACH, never to `return`** (invariant **I3**) —
`xschem raw rawfile` and `xschem raw annot` both RAISE with nothing attached, and an
early return on an unanswerable question is exactly how the shipped guard shows run
1's numbers forever. The attach is verified by re-asking `op_annot::_annotated`,
never by trusting `annotate_op`'s return: measured, `xschem annotate_op /nonexistent`
returns the path string with `TCL_OK` and nothing attached.

Defect **B** (§3, an unrelated waveform raw blocks the attach) was genuinely closed by
this and stayed closed under adversarial probing. Sabotage S3 (predicate always
satisfied — the shipped defect's exact behaviour) turned 6 rows red; S4 (always
re-attach) turned the no-needless-re-read row red. Both halves of the predicate were
therefore load-bearing.

### What it did NOT close: the headline case, on the primary gesture

The brief's requirement was *"annotate, re-run the simulation, and prove the displayed
numbers are the NEW ones or blank, never the old ones"* — **no untick in that
sentence**. Measured against the shipped bodies, no sabotage live:

```
A1 after the tick: raw value v(a) -1   = 111  (run 1 = 111)
A2 the file on disk now says v(a)      = 222
A2 (no tick, no untick -- annotation is simply still ON)
A2 raw value v(a) -1                   = 111  <<< 111 = STALE ON THE SHEET
A2 op_annot::_annotated                = 1  (1 = the overlay paints)
A3 calling ase::ui::run_finished K (the 0684 'exactness' seam)
A3 raw value v(a) -1                   = 111  <<< still 111
A4 ONLY an untick+retick repairs it:   = 222
```

`ase::ui::annot_ensure_loaded` is the **only** re-attach and `annot_apply` its only
caller, so nothing refreshes without a tick. `run_finished` drops the *stamp*, so the
cache stops lying — but the **screen** keeps painting the previous run's number, which
is invariant I3's forbidden case in its own words. The three rows that were written
for this (W1a18/W1a19/W1a20) all untick then re-tick, so none of them can see it.

**Binding on attempt 2:** the fix has to reach the *display*, not just the next tick.
`run_finished` is the seam; what it must do is re-attach-or-blank, not merely
invalidate. That is close to §5's rejected option (3), and §5's reason for rejecting
it (blast radius) now has to be weighed against the fact that option (1) alone does
not satisfy 0684's own headline.

### Two sentences of §5 that measurement refutes

* The shipped D8 comment's *"A LOADED DATABASE IS NEVER THROWN AWAY … replacing it
  would be a data loss caused by a menu tick"*, which §5 leans on to reject option (2),
  is **too strong**. Measured: `annotate_op` ADDS a database and only moves the CURRENT
  pointer; it destroys the previous one **only** when that one is a 1-point `op`/`dc`
  (`scheduler.c:2410-2414`). The waveform graph the warning is written about is never
  lost. The real loss is another corner's operating point.
* But the attempt's own repair overshot in the other direction and **created** a data
  loss where none existed — see
  [0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md) §4.
  Both facts have to be held at once: `annotate_op` is safer than the comment claims,
  and a blanket `raw clear` before it is not.

### Known limitation the attempt hit and could not remove

`file mtime` is 1-second resolution, so a same-second rewrite of identical size is
invisible to the stamp. Only ASE-L's own `run_finished` closes that hole; a re-run
driven from a terminal or from `Simulation > Netlist and Run` does not go through it.
