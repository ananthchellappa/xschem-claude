# 0684 — ASE-L's raw-attach arm guards on `raw loaded`, so it can show the PREVIOUS run's numbers forever, and an unrelated waveform raw blocks it entirely

STATUS: **FIXED 2026-08-28 (attempt 2) FOR THE ROUTES §8's TABLE NAMES — see §8
and §10.** The gesture the user complained about (annotate, re-run, press `6` /
re-tick) now shows the new numbers or blanks them, on both operating-point
surfaces, and a finished ASE-L run repaints by itself. **Three measured states of
the same defect SURVIVE** and are filed, not silently carried:
[0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md)
(attached from a menu outside this surface, same path — trusted forever),
[0911](0911-on-a-descended-sheet-with-no-ase-l-session-the-chord-never-repairs.md)
(descended sheet, no session), and
[0912](0912-the-two-operating-point-surfaces-disagree-when-the-results-file-is-deleted.md)
(the results file deleted). Attempt 1, 2026-08-25, was REFUTED and REVERTED the
same day; §7 records what it settled and is the specification attempt 2 was
written against. Originally measured 2026-08-25 by issue 0682's adversary pass.
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

### THE RESIDUAL WAS A BADLY POSED QUESTION, AND THE USER SAID SO

The lead asked whether a finished run should "refresh annotation" on a design
whose annotation is OFF. The user answered:

> depends on what you mean by "refresh". The annotations are currently off. When
> the user asks for annotations to be displayed, the updated data from the
> just-finished simulation is what will be displayed. How does your question
> arise?

It arose because **attaching a raw is not a neutral act**: `annotate_op` releases
the loaded op/dc database and `array unset`s `ngspice::ngspice_data` *before*
reading the new file — the very path [0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md)
proves can destroy it outright. So "attach at run completion" means firing a
destructive data operation the moment a run ends, whether or not anything needs
the result, while the user may be looking at a different database in a graph.
The question was really *"is it acceptable to do that when nothing needs it yet?"*
and it was dressed up as a question about display.

**The user's answer is an INVARIANT, not a mechanism**: *turn annotation on ->
see the just-finished run's data.* That is a guarantee about the TICK. It does
not require an eager attach at all.

### DIRECTION TAKEN — smaller than all three options above

Measured: `ase::run_done` (`src/ase.tcl:1177`) already stamps
`last_run = {results ... exitcode ... log ... diagnostics ...}`, and
`ase::ui::run_finished` already writes it onto the session with
`ase::session_setattr $key results [ase::last_result]`. **The fact "which raw is
this session's current result" therefore already exists the instant a run ends.**

| when | what happens |
|---|---|
| run finishes | already stamps `results` on the session — **no change needed** |
| tick ON | compare what is ATTACHED against that stamp; attach only if they differ |
| tick OFF | nothing |

This satisfies the user's invariant exactly, and:

* the database is never swapped while nothing is displaying it — which matters
  because that swap can fail destructively (0807);
* the common case (stamp matches what is attached) costs a comparison, so the
  slow-menu-click objection against option (1) does not apply;
* a large raw is re-read only when it is genuinely a different result.

Options (1), (2) and (3) are all superseded and kept above for the record. (3)'s
fatal flaw, which the crew that filed it did not see: it fires the destructive
path at a moment nobody asked for it.

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


---

## 8. ✅ ATTEMPT 2 (2026-08-28) — LANDED. Tcl only, no C, no rebuild needed

### The line the title names is NOT the line the defect lives on

Measured 2026-08-28 before writing anything, on both arms:

* On the `6` / `Alt-6` surface the deciding line is **not** the gate
  `cadence::_annot_op_db_ok`. With run 1 stale-attached that gate answers 1 and it
  is **right** to — an operating point really is attached and its `sim_type`
  really is `op`. Control then reaches `cadence::annot_mode`'s
  `if {$annotated} { set state live }`, which short-circuits every load path.
  Tightening the gate alone turns a wrong number into a **self-contradicting
  refusal that still shows the old numbers**: `id = 1e-05` on the sheet, mask still
  1, under *"No operating point results are loaded. These are from a 'op' run
  instead…"*. The gate's body is therefore **unchanged**; only its 0684 scope-fence
  comment was rewritten to point at where the question really lives.
* `cadence::_annot_tran_db_current` **cannot be called** from here, and calling it
  would look like a fix. It consults `cadence::_annot_viewer_db`, which reports a
  database only when the waveform viewer is showing a `tran`, so with a stale
  operating point attached it answers 1 = "current" both **before and after** the
  file on disk becomes a different run. Widening `_annot_viewer_db` past `tran` was
  rejected: it is issue 0903's line, and a viewer consult cannot answer this
  question at all because an operating-point run usually has no waveform window.

The two surfaces ask genuinely different questions — **TRAN**: *do two windows'
in-memory copies agree?*  **OP**: *is the database this window is painting from
still the file it was read from?* — so RULING D5-4 is honoured by minting the OP
question **once** and having **both** OP surfaces call it, with cross-referencing
paragraphs in each helper saying why they are not the same question.

### What was built

| proc | file | what |
|---|---|---|
| `op_annot::db_current {cand}` | `src/op_annot.tcl` | THE MINT. G1 nothing publishable attached → 0 (defect B, asked **first**); G2 unnameable → 0 (**every catch falls to re-attach, never to `return`**); G3a first sight → stamp and trust; G3b stamp matches → 1 (the cheap path); G4 stamp differs → 1 when the candidate is elsewhere or absent, **0 when it is this file** (the headline) |
| `op_annot::db_attach {path ?level?}` | `src/op_annot.tcl` | issue 0685's **targeted** drop (`op`/`dc` at this path only, using the registry's own path spelling, **never** `tran`, **never** the bare `xschem raw clear`), then `annotate_op`, then **verify by re-asking**, then stamp |
| `op_annot::db_detach` | `src/op_annot.tcl` | the "or BLANK" half. `cadence::_annot_db_release`'s body, moved verbatim; that proc is now a one-line delegate |
| `op_annot::_db_key` / `_db_stat` / `_db_stamp` / `_db_forget` | `src/op_annot.tcl` | the stamp table, keyed `<current_win_path>|<normpath>` because the mask and `xctx->raw` are both per-context |
| `cadence::_annot_op_target` | `utils/annot_mode.tcl` | element 0 of `_annot_raw_candidate`, so the currency question can be asked **above** the candidate search |
| `ase::ui::annot_refresh_after_run` / `_here` / `_idle` | `src/ase_window.tcl` | the half that reaches the DISPLAY with no gesture |

`cadence::annot_mode`'s live arm became, with both questions on **one source
line** (guard G10, item A14's shape):

```tcl
catch {set live [expr {[::op_annot::_annotated] && [::op_annot::db_current [cadence::_annot_op_target]]}]}
```

and guard G11 detaches **before** the selector, so no refusal can ever sit above
the previous run's numbers. `ase::ui::annot_ensure_loaded` lost its
`xschem raw loaded >= 0 -> return` opening entirely (guard G12) and detaches on
the same condition (G13). `ase::ui::run_finished` gained one line in its exit-0
arm, immediately **below** the existing `auto_plot_idle` so the viewer's own
context borrow balances first (guard G14).

### §7's three binding constraints, and how each is met

1. **"It must reach the display, not merely the next tick."** `run_finished` now
   schedules a re-attach-or-blank, not an invalidation. Row F31 stages the exact
   sequence with **no** gesture; row W1a24 does it through the **real Tk menu** on
   `:99` and reads `7.77` where the shipped tree read `1.25`.
2. **"No acceptance row may untick and re-tick."** None does. F16/F17 press `6`
   and `Alt-6`; F23 ticks twice with no untick between; F31/F32 and W1a24/W1a25
   make no gesture at all.
3. **"Every catch falls to re-attach, never to `return`."** Row F8 reads
   `db_current`'s own source and requires zero `catch … { return 1 }` and zero bare
   `return`. It is that guard's **only** witness, because G1 already refuses every
   state in which `xschem raw rawfile` can raise.

Constraint 4 (**do not trust `annotate_op`'s return**) is row F11, which golds the
engine's `TCL_OK` for `/nonexistent` next to `db_attach`'s 0 **in one golden**, so
a fix that trusts the return cannot pass. Constraint 5 (**no blanket `raw clear`**)
is rows F13 and F14. Constraint 6 (**defect B stays closed**) is rows F6, F24 and
W1a27.

### What measurement changed about the plan

* **`annotate_op` never RAISES for the failures that matter.** Missing path → rc 0,
  empty result. Unreadable file → rc 0, empty result, and it destroys a 1-point
  `op`/`dc` it was replacing. So ASE-L's failure sentence — which only ever fired
  inside a `catch` — **could not be spoken at all** before this item. `db_attach`
  now supplies a reason when the engine gives none; that wording is invented and
  is recorded as `owed.sh add rule 0684`.
* **The chord asks `xschem raw loaded`, not `db_attach`'s answer, for "did anything
  attach".** `annotate_op` with no type token tries op → dc → **tran**, so on the
  commonest post-run desktop `db_attach` answers 0 with a **transient attached**.
  RULING 0856's unwind has to SEE that database to put it back and to name the
  analysis in its sentence. Reading the 0 as "nothing happened" reddened rows V31c
  and V41 and would have left the user's window holding a transient nobody asked
  for, under *"Could not read the results file"*.
* **Row V74 of `test_op_annot.tcl` moved with the body it reads.** Legs 3–5 asserted
  the named-file spelling and the digital-question ordering inside
  `cadence::_annot_db_release`; they now read `op_annot::db_detach`, and a new leg 9
  requires the old address to be a delegate — so the spelling still has exactly one
  owner.

### RE-RUN ROUTES: covered, and NOT covered

**Covered with no gesture at all — ONE route only.** ASE-L's own
`Simulation > Netlist and Run`, because `ase::ui::run_finished` is the only
run-completion event in the tree. Grepped over its whole body before the change:
zero `annotate_op` / `annot_show` / `raw` / `op_annot` hits.

**Covered on the next press or tick — every route the annotation surface itself
attached from**, including a terminal re-run and **xschem's own
`Simulation > Netlist and Run`**. The stamp is a property of the file on disk,
not of a session, so `6`, `Alt-6` and the tick repair themselves whoever ran the
simulation — *provided the database was attached through `op_annot::db_attach`
and the sheet the user is standing on resolves to the file that is attached.*

> ⚠ **THIS PARAGRAPH SAID "every route" UNTIL 2026-08-28 AND THAT WAS FALSE.**
> The adversary pass measured two states it does not cover, and both are the
> filed defect surviving verbatim. **Neither is fixed.** See §10, and
> [0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md)
> and
> [0911](0911-on-a-descended-sheet-with-no-ase-l-session-the-chord-never-repairs.md).

**NOT covered, stated plainly:**

* xschem's own menubar run and any terminal-driven run have **no completion event
  that reaches annotation**. `proc simulate` (`src/xschem.tcl:4092`) sets
  `execute(callback)` to `set_simulate_button` plus the caller's callback and
  nothing else. Hooking it was **rejected**: it is stock upstream code on the path
  of every simulation, and a callback-chain edit there is a far larger blast radius
  than the defect. A fix that works only for ASE-L's own button and is presented as
  general is the shape this branch keeps shipping, which is why this paragraph is
  mandatory and not optional.
* **A same-second rewrite of identical size** is invisible to the stamp, on every
  route. `file mtime` is 1-second resolution. Unremoved, and issue 0904 is the
  axis on which a content fingerprint would have to be paid for.
* A database attached by some **other** route — `Simulation > Graphs > Annotate
  Operating Point into schematic`, `Waves > Op Annotate`, an xschemrc line — is
  trusted on **first sight**, and the stamp is taken at that first *observation*,
  not at the attach. If the file changed in between, the stamp already describes
  the NEW file and the OLD numbers are blessed **forever**: press `6` three times
  and the first run's `id`/`gm`/`gds` repaint every time. Filed as
  [0910](0910-an-operating-point-attached-from-outside-is-trusted-forever-at-the-same-path.md),
  measured on the delivered tree. The trust arm itself is load-bearing — it is
  what keeps rows N5, N10 and V31b green — so the fix is narrower than deleting
  it (0910 §4).
* On a **descended sheet with no ASE-L session**, the `netlist_dir` candidate is
  built from the sheet the user is standing on, so it names the SUBCELL's raw
  while the design is painting from the TOP's. Guard G4 reads that as "not mine,
  leave it alone" and the chord never repairs; worse, `Waves > Clear` then `6`
  now answers *"There is no results file at …/sub.raw yet. Run a simulation
  first."* about a run that just finished. An ASE-L session rescues it, because
  `ase::session_for_current` walks the hierarchy stack. Filed as
  [0911](0911-on-a-descended-sheet-with-no-ase-l-session-the-chord-never-repairs.md).
* When the results file has been **deleted**, ASE-L's tick keeps the numbers
  (`ase::last_rawfile` answers `{}`, G4's no-candidate arm answers "current") and
  `6` blanks them. The two operating-point surfaces disagree about the same
  state and only one of them says so. Filed as
  [0912](0912-the-two-operating-point-surfaces-disagree-when-the-results-file-is-deleted.md).
* A database at a path **other** than this surface's candidate is never replaced,
  so the tick can still show another corner's operating point — filed as
  [0908](0908-the-annotate-tick-can-show-another-corners-operating-point.md),
  deliberately, because replacing it would destroy it.

### COST — measured, median of 11, both arms

The ordinary press is **flat in the size of the results file**:

| vectors | bytes | press `6`, nothing changed | `db_current` alone | press `6` after a re-run |
|---|---|---|---|---|
| 3 | 246 | 0.17 ms | 0.010 ms | 0.47 ms |
| 200 | 5 353 | 0.18 ms | 0.011 ms | 0.76 ms |
| 2 000 | 55 951 | 0.18 ms | 0.011 ms | 3.2 ms |
| 20 000 | 597 949 | 0.18 ms | 0.011 ms | 32.7 ms |
| 40 000 | 1 217 949 | 0.20 ms | 0.011 ms | 83.7 ms |

(headless; on `:99` the same columns read 0.29–0.42 ms / 0.010–0.022 ms /
2.4–121 ms.)

**The revalidation itself never exceeds 0.022 ms at any size**, against
`cadence::_annot_db_print`'s 28.3 ms and a full `annotate_op` re-read's 58.2 ms at
40 000 vectors (issue 0904's table). Row F35 greps `db_current` and `db_attach`
for `_annot_db_print` and requires **zero** hits, so the transient surface's
fingerprint cannot drift onto this path.

The last column is the honest cost of the fix: the press that **actually re-reads**
pays what reading the file costs. That press happens once per re-run — and it is
the press that used to show the wrong answer.

### Acceptance rows

`tests/headless/test_annot_stale_0684.tcl`, 36 checks, registered in
`run_regression.tcl`'s `hcases` **and** `dcases` and in `full_audit.sh`'s
`nogui_tests`, ALL PASS on both arms. `tests/headless/test_ase_window.tcl` gained
W1a24–W1a27 on the display arm (221 → 225 checks, ALL PASS, openbox 3.6.1 live on
`:99` at 1920x1080x24). `test_op_annot` 472 headless / 479 on `:99`,
`test_annot_show_menu` 36, `tclsh run_regression.tcl` 41 cases at
`Total num fail: 0`.

**A green suite is not proof the sheet repaints.** Nothing here draws pixels: the
block is read through `op_annot::text`, the one renderer the overlay itself calls.
Recorded as `owed.sh add look 0684-rerun-repaints`.

---

## 9. Sabotage round 2026-08-28 — six guards nothing could see, and what closed them

The fix in section 8 behaves correctly at every point that was probed, and the
restore was byte-exact. What failed was the **coverage**: 24 mutations, applied
one at a time to the real files, found that **six of the twenty-six guard parts
could be neutralised with every suite in the tier list green** — and four of the
six exist to stop the annotation surface **destroying data the user is looking
at**. None of the guards was removed. Each one gained a row.

### The six, and the witness each now has

| guard | what it stops | why nothing saw it | the row that sees it now |
|---|---|---|---|
| **G8** — the freshness stamp is written only *after* the attach is verified, and a failed attach drops any stamp it held | a stamp describing a file that never attached | the stated hazard ("already loaded over a blank sheet") is **unreachable**: a failed attach leaves nothing publishable attached, so G1 refuses the next question before any stamp is read | **F10b**, both halves — behavioural (a simulator mid-write fails the attach; the file finishes; the user attaches it from `Waves > Op Annotate`, and that good fresh attach must still be trusted on first sight, not thrown away and re-read) plus a structural leg pinning the stamp **below** the verify and a forget **after** it |
| **G16** — the design-window borrow: switch, verify the switch took (landmine 17), give the context back | numbers written into a **foreign schematic** | every fixture held **one** schematic window, because the tick's own `annot_goto_design` leaves the design current — 12 of 12 calls entered with `cur == win`, so the branch was dead code under test | **W1a28** and **W1a29** of `test_ase_window.tcl`, which drive a finished run from the decoy tab. W1a29 stages the refused switch through `xschem set semaphore` — the landmine itself — and measures the failure: without the check the refresh answers "done" and the session's operating point lands in the **foreign** tab |
| **G4's path arm** — a database at a path this surface never owned is left where it is | one corner's operating point wiped by a press about another (`annotate_op` **deletes** a 1-point op/dc it replaces) | F5 and F20 staged the situation and then asked **once**, which G3a's first-sight arm answers several lines above the path comparison | **F5** takes a first look, *then* rewrites the foreign file, then asks again; **F20** does the same through two presses of `6` |
| **G4's no-candidate arm** | the tick throwing away good numbers when the results file has been deleted and there is nothing to re-attach from | F4 staged an **unchanged** file, so the cheap path answered one line earlier | **F4** rewrites the file first, and its last leg asks the same question *with* a candidate and requires `0` — the proof that the cheap path did not answer |
| **G6's never-tran half** | issue 0685 §4's data loss: the user's waveform unloaded by a failed re-attach | F13 puts the waveform at a **different** path, where the type list cannot matter — only F14's source grep moved | **F13b**, the same failure at the **same** path. Measured: shipped keeps the entry and `v(zzz)` still reads; with `tran` in the list the registry is empty |
| **G13's `$ann` term** | an ordinary waveform graph destroyed by a tick that is not about it | F24 golded that the numbers render and the session's file is current — both still true when the detach is unconditional | **F24's last leg**: is the graph still in the registry afterwards |

### Four rows whose titles claimed more than they measured

* **F1** said "guard G1". With nothing attached at all, `xschem raw rawfile`
  raises and G2's catch answers first — deleting G1 left F1 green. Retitled to
  what it does measure (the empty-session floor); G1's owners are F6, F24 and
  W1a27.
* **F12** said it guarded issue 0685's drop. Its own bare `annotate_op` call
  makes the stale entry **current**, and once it is current the attach re-reads
  with or without the drop. Kept as the hazard demonstration; **F12b** is the
  guard.
* **F13** claimed to be "the only guard on the never-tran half". It is a guard
  on the drop existing at all. **F13b** is the type list's.
* **F30** claimed "a finished run whose results are already the ones on screen
  re-reads nothing", golded as "the attached filename and the registry listing
  did not change" — and a detach-and-re-attach of the same path leaves both
  byte-identical, so forcing a re-read on **every** press left the row green.
  It now **counts the reads**: a delegating proxy stands in front of
  `op_annot::db_attach` for the length of the row and requires zero calls.

### Two findings recorded rather than acted on

* The plan's mutation **S4** ("move the rawfile/normalize block above the
  is-anything-attached question") is behaviourally inert — only F8's structural
  ordering leg moves. The hazard the G1 comment describes is staged by hoisting
  the **candidate comparison** above that question, which reds F6, F24, F8 and
  W1a27. The ordering claim is witnessed; the plan named a mutation that cannot
  stage it.
* Row **W7** of `test_ase_window` ("simulator produced output before Stop") went
  red in 4 of 14 dev-display runs during the sabotage rounds, under mutations to
  files that touch neither the simulator nor the Stop button, and green in 5
  consecutive runs on the restored tree. A load-sensitive timing row, unrelated
  to this item. Re-run before filing it.

### Counts after the repair

`test_annot_stale_0684` **39** checks (was 36), ALL PASS on both arms.
`test_ase_window` **227** checks (was 225) on `:99`. Every mutation above was
re-applied after the rows landed and each reds **only** the row(s) named for it.

---

## 10. Adversary pass 2026-08-28 — three states where the defect survives verbatim

The refutation pass re-ran §2's original repro on the delivered tree (it goes
`10u` → `9m`, and the ASE-L tick with it), then went looking for the states the
fix does **not** reach. It found three. All three were **re-measured by the
write-up agent on the delivered tree before being filed**, using the adversary's
own probes; none is fixed here, and each has its own issue rather than a bullet
somebody can lose.

| # | the state | what the user sees | filed |
|---|---|---|---|
| 1 | the database was attached by `Simulation > Graphs > Annotate Operating Point into schematic` or `Waves > Op Annotate` — both a bare `xschem annotate_op` — and the run happened after that | press `6`, `6`, `6`: **run 1's `id`/`gm`/`gds` every time**, under *"These results were already loaded."* Permanent. Guard G3a stamps at the first **observation**, not at the attach, so the stamp already describes run 2's file while the in-memory copy is run 1's | **0910** |
| 2 | a descended sheet, no ASE-L session (the plain `netlist_dir` way of working) | the same permanence, **and the escape breaks**: `Waves > Clear` then `6` says *"There is no results file at …/sub.raw yet. Run a simulation first."* about a run that just finished. The candidate is built from the sheet the user is standing on, so it names the subcell while the design paints from the top | **0911** |
| 3 | the results file has been deleted (the simulator removed it and the run died) | ASE-L's **tick keeps the numbers of a file that is gone** and untick-and-re-tick does not clear it; `6` in the identical state blanks and says why. The two surfaces disagree and only one speaks | **0912** |

**Why the suite could not see any of them.** Row F7 — the row that owns the
first-sight stamp — stages `attach → ask → rewrite → ask`, so it observes while
the file is still run 1 and its stamp is correct. The user's order is
`attach → walk away → re-run → FIRST ask`. Nothing in the tree descends a
hierarchy. Nothing in the tree deletes a results file mid-session. This is the
same class of gap §7 records against attempt 1 (its rows all unticked and
re-ticked, which is why a refuted fix looked green) — a row that stages the
right situation and then asks the *wrong question at the wrong moment*.

**What the pass confirmed, and it matters as much as the refutations.** The
headline repro is fixed on both surfaces; the acceptance rows are not hollow (the
shipped defect restored by proc override reds F16/F23/F24/F31/F32 and W1a24/25/27
— 15 of 36 headless, 5 of 225 on `:99`); there is no over-refusal (a transient at
the candidate path still refuses exactly as RULING 0856 requires, unchanged
across three presses); the targeted drop's `xschem raw info` parser is sound
against the real two-line format; and the cost claim reproduces independently —
a 40 000-vector operating point re-reads in 54.3 ms on the press that must, and
0.156 ms (median of 11) on every press that must not.

**One behaviour change nobody ratified**, recorded on the `owed.sh` rule debt for
this issue rather than left in a write-up: when a press finds the candidate
rewritten but **unreadable** (a simulator still writing it), guard G11 detaches
BEFORE refusing, so the user **loses** the previous run's numbers and gets
*"Could not read the results file …"*. That is D5-1-correct and row F18 owns it,
but it is a strictly new loss of on-screen information against the shipped tree.
