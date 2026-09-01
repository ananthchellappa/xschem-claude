# 0900 — a second Alt+Shift+6 skips every safety check, and the previous run's numbers stay on the schematic

**Status:** ✅ **FIXED 2026-08-28 (item A14) for the waveform-window path**, which
is the path it was measured and ruled on. ⚠ **The same defect is still live when
the user reads the cursor off the schematic's OWN waveform graph and no ASE
waveform window is open — filed as 0903, open.** See *"one door is still open"*
below before quoting this issue as closed. It was a **live RULING D5-1
violation**: a number that was not measured for the thing it is displayed next to
reached the schematic, under an authoritative caption, with no refusal and no
warning. The fix, the three alternatives that were rejected, the cost of it and
the rows that hold it are at the bottom of this file; everything above them is
the measurement as it was filed and is left standing.

Filed 2026-08-28 by the item A13 write-up, from the A13 adversarial
verification pass. Measured on **both** arms, byte-identical.

**Not introduced by item A13.** The expression at fault arrived with issue 0881
(commit `1d466364`), one item earlier. A13 is filing it because A13's own fix
lives *inside* the block this expression guards, and because A13 shipped a
comment claiming a skipped compare is now impossible — which this measurement
disproves. See *"What this costs the A13 comment"* below.

## What the user does — and it is the ordinary sequence, not a corner

1. Runs a transient, puts a cursor on, presses **Alt+Shift+6**. It works: the
   node voltages land on the sheet. **That press leaves the results database
   attached to the design window** — a successful press never unwinds it, by
   design.
2. Changes something, re-runs the simulation. The waveform window re-plots and
   is now showing the **new** run.
3. Presses **Alt+Shift+6** again.

## What happens

The schematic is painted with the **first** run's numbers, under the caption
*"Showing each node's voltage at 3 ns, where cursor B is on the waveform."*,
while the waveform window is showing the second run. No refusal, no warning, no
compare. Measured, both arms:

```
P1 press1=0 ok
P1 after_press1_loaded=0 mask=4
P1 paint_after_press1=d 3 g 0.9 0 0.0 0 0.0     <- run 1, correct
P1 viewer_now v(d)@last=28 v(g)=0.1             <- the waveform window now holds run 2
P1 design_loaded_before_press2=0                <- the design window still holds run 1
P1 press2=0 ok
P1 loaded=0 mask=4
P1 msg=Showing each node's voltage at 3 ns, where cursor B is on the waveform.
P1 paint=d 3 g 0.9 0 0.0 0 0.0                  <- run 1 again, on a sheet describing run 2
```

The same door reaches issue 0896's own forbidden literal. With the design window
holding a finished run and the waveform window showing a **still-filling**
zero-point run — 0896's headline scenario, with A13's fix in place:

```
P5 design_loaded=0 design_v(d)@last=28 design_v(g)=0.1
P5 viewer_points=0 viewer_simtype=tran
P5 annot_tran=0 ok
P5 loaded=0 mask=4
P5 msg=Showing each node's voltage at 3 ns, where cursor B is on the waveform.
P5 paint=d 21 g 0.1 0 0.0 0 0.0
```

`d 21 g 0.1 0 0.0 0 0.0` is the literal item A13's brief names as the one that
must not appear. A13 closed the door it was chartered to close; this is a
different door onto the same room.

## The measured cause, at the statement

`utils/annot_mode.tcl`, `cadence::annot_tran`:

```tcl
set loaded -1
catch {set loaded [xschem raw loaded]}
if {![string is integer -strict $loaded] || $loaded < 0} {
  set sup [cadence::_annot_tran_supply]
  ...
}
```

**The entire supply is inside that `if`.** The waveform-window consult, the
`filegone` and `nopoints` guards item A13 just added, the staleness check, the
`viewerunread` guard and the **two-window compare** are all skipped whenever the
design window already holds *any* database. The test asks *"is some database
attached?"*, never *"is it the one the user is looking at?"*.

This is the identical predicate mistake already filed as **0684** against
`annot_ensure_loaded` — *"it guards on `xschem raw loaded` >= 0, which asks 'is
SOME database attached' rather than 'are THIS session's CURRENT results
attached'"*. 0684 is open, on the operating-point surface. This is the same
fault on the transient surface, reached by a different caller, and neither
issue's fix covers the other.

## What this costs the A13 comment, and why that matters here

`utils/annot_mode.tcl` shipped this claim above the compare:

> ⚠ GATED ON `$vseen`, WHICH MAKES A SKIPPED COMPARE STRUCTURALLY IMPOSSIBLE.

It is true **inside `cadence::_annot_tran_supply`** and false as a statement
about the feature, because the supplier is not always called. The same overclaim
went into `doc/claude/issues/0896-*.md` and
`doc/claude/specs/op_annotation.md`. All three were corrected in the A13
write-up commit — a comment that overstates its own coverage is exactly what
hid a guard for a whole item in **0899**, and this is the same shape one level up.

## The shape of a fix — as filed (the driver ruled it, and A14 built it; see below)

The honest gate is not *"is a database attached"* but *"is the attached
database the one the waveform window is showing"*. The consult already computes
the fingerprint that answers this. Sketch:

* run the consult **before** the `loaded < 0` test, and take the supply path
  whenever the consult reports a viewer file that disagrees with what the
  current window holds; or
* keep the short-circuit but add the two-window compare to it, so an
  already-attached database is still checked against the viewer's fingerprint
  before a single number is believed.

Either is a real change to the mode's control flow with its own unwind
consequences — a successful earlier press owns the attached database, so a
refusal on the second press must decide whether to detach it — and it needs its
own item, its own rows on both arms and its own sabotage pass. **It must not be
done as a drive-by.**

## Rows

**None, and that is the finding.** Every existing row that exercises
`cadence::annot_tran` starts from a design window holding nothing, so all of
them enter the guarded block and none can see this path. Rows V58–V65, V50, V51
and V37 included. A fix owes at minimum:

* a two-press row on both arms — press, re-run, press again, and assert the
  sheet does **not** still carry the first run's numbers;
* the 0896 fixture with the design window pre-loaded (probe `P5` above), which
  is the `d 21 g 0.1` case.

## Related

* **0896 / 0895** — the same D5-1 family, through the consulted path. Fixed by
  item A13; this is the unconsulted path.
* **0684** — the same "is SOME database attached" predicate, on the OP surface. Open.
* **0885** — the compare that runs but samples only the last point. Open.
* **0899** — a comment that overstated what its rows pinned. The A13 comment
  corrected here is that shape again.

## Evidence

Probes, re-run by the write-up agent rather than inherited, against the
already-built `src/xschem` (Aug 27 14:58) with the A13 fix in the tree:

* `.../scratchpad/vc/p.tcl` row **P1** — the two-press sequence.
* `.../scratchpad/vc/q.tcl` row **P5** — the `d 21 g 0.1` case.

Both reproduce byte-identically headless and on the persistent dev display
(`:99`, 1920x1080x24, **openbox 3.6.1** live per `devdisplay.sh status`).

---

# ✅ THE FIX (item A14, 2026-08-28)

## What the user gets

* Press the chord, re-run the simulation so the waveform window re-plots, press
  again — **the schematic now shows the NEW run's numbers**. That is not a new
  policy; it is the user's own 0881 ruling — *"The info should already be
  available - it's been loaded to display waveforms in the waveform viewer"* —
  applied a second time. The second press is **not** a case for a refusal.
* Press the chord, have the results file go off disk (or the run go back to
  having no values yet), press again — the press **says why, in the plain English
  it already shipped, AND takes the earlier press's numbers off the schematic**.
  A captioned refusal sitting above a stale number is not an improvement on a
  silent stale number.
* Press the chord and then **close the waveform window** — the numbers stay. With
  nothing on screen to disagree with, what the session holds is still the answer.
* Leave an operating point on the sheet from an earlier `6`, then press the
  transient chord over a plotted transient — it now annotates the transient
  instead of answering *"These results are not from a transient run"* about a
  database nobody is looking at. That is a second 0881-family repair the same
  gate gets for free.

**No new sentence was minted, and no existing one changed.**
`cadence::_annot_tran_msg`'s ten state names and its `error` list are untouched,
so nothing new is owed to the A11 plain-English rows or to 0897's enumerations.
What changed is that the shipped clause *"so nothing was placed on the
schematic"* is now **true of the sheet the user is looking at**, which it was not
before.

## The change, at the statement

`utils/annot_mode.tcl`, and it is Tcl only — nothing here is compiled.

**One new proc**, `cadence::_annot_tran_db_current`, placed above
`cadence::_annot_tran_unwind`:

```tcl
proc cadence::_annot_tran_db_current {} {
  set vw [cadence::_annot_viewer_db]
  if {![llength $vw]} { return 1 }
  if {[lindex $vw 2] ne {ok}} { return 0 }
  if {[cadence::_annot_db_print] ne [lindex $vw 1]} { return 0 }
  return 1
}
```

**One added disjunct and one three-line preamble** in `cadence::annot_tran`:

```tcl
  if {![string is integer -strict $loaded] || $loaded < 0 || ![cadence::_annot_tran_db_current]} {
    if {[string is integer -strict $loaded] && $loaded >= 0} {
      cadence::_annot_tran_unwind 1 $mask0
    }
    set sup [cadence::_annot_tran_supply]
```

Four things about that are decisions, and each has a row:

1. **The currency question is on the SAME LINE as "is anything attached".** A
   build that computed it into a variable further up and forgot to use it, or
   tested it in an arm below, passes every behavioural row on today's fixtures.
   Row **V69 leg 4** reads it as source text.
2. **The `||` short-circuits.** With nothing attached the helper is never called,
   so every press from an empty design window — every fixture written before this
   item, and the ordinary first press on a real bench — takes byte-for-byte the
   path it always took.
3. **The consult is the helper's first statement, above every return.** A
   currency test that answered from a cheap check or a remembered answer before
   asking the waveform window anything would be this very issue rebuilt one level
   down. Rows **V69 legs 6 and 7**.
4. **The held database comes off BEFORE the supplier runs**, not after, and it is
   `_annot_tran_unwind` rather than a bare `raw clear` so one place still knows
   how to take numbers off a sheet. The mask handed back is `$mask0`, i.e.
   unchanged: this detaches a database, it must not edit the user's annotation
   settings. Rows **V67**, **V71 leg c**, **B12k**; ordering pinned by **V69 leg
   4**.

## Three alternatives, rejected

* **Refuse on the second press** (*"the run on screen changed under you"*).
  Rejected by the driver's ruling and by 0881: the user re-ran the simulation and
  pressed the key; what they are asking for is the new numbers, and giving them
  the new numbers is the whole job.
* **Keep the short-circuit and add the compare inside it.** Rejected: it
  duplicates the consult, the `filegone`/`nopoints` classification and the
  staleness check at a second site, which is precisely the drift RULING D5-4
  exists to stop. Revalidating and then reusing the ONE supplier is the same work
  in one place.
* **Clear only when the transient bit is set** (so an earlier `6`'s operating
  point survives an unreachable viewer). Rejected: it reintroduces the wrong
  *reason*. `_annot_tran_supply` re-asks `xschem raw loaded` to learn whether its
  own read worked, so a database left attached makes an unreadable viewer file
  report *"from a different simulation run"* instead of *"could not be read"*.
  See the ruling debt below — this one goes a step past what the user ruled on.

## What it costs

The extra work on a press that finds nothing has changed is one context borrow
plus two `_annot_db_print` reductions, both over data already **in memory**; no
file is opened. Measured on this box, headless, `src/xschem` of Aug 27 14:58,
median of 20 presses, three database sizes:

| results database | press 2 **before** (short-circuit — and the WRONG numbers) | press 2 **after**, nothing changed | press 2 **after**, the run really changed | press **1** on the same file, for scale |
|---|---|---|---|---|
| 262 B — 2 cols x 5 pts | 0.110 ms | **0.151 ms** | 0.407 ms | 2.8 ms |
| 1.0 MB — 20 cols x 5000 pts | 0.126 ms | **0.195 ms** | 5.8 ms | 6.4 ms |
| 42.5 MB — 200 cols x 20000 pts | 0.220 ms | **0.678 ms** | 146.8 ms | 192.6 ms |

**Read that as two different presses.** The press where nothing has changed — the
common one — costs **+0.46 ms on that 42.5 MB database**: one context borrow and
two in-memory fingerprints, no file opened. The press where the run really *did*
change costs 146.8 ms because it reads the run the user is asking about — the
same work press 1 already does (192.6 ms, cold), unavoidable, and paid **only**
on the press where the answer actually changes.

**⚠ THE TABLE ABOVE SWEEPS THE WRONG AXIS, AND AN EARLIER REVISION OF THIS
SECTION CALLED +0.46 ms "the whole price of revalidating" — ISSUE 0904, OPEN.**
`_annot_db_print` ends in one `xschem raw value` per **saved vector**, at a
single point, computed twice per press; the point count barely enters, and the
three sizes above hold columns fixed at 200 while sweeping points. Re-measured
2026-08-28, headless, median of 11, both windows counted: **6 vectors x 20 000
points (995 KB) → 0.014 ms**, but **40 000 vectors x 50 points (11 MB, a quarter
the size) → 55.9 ms**. About 1.4 µs per saved vector per window, linear, no
ceiling; a `.save all` transient reaches tens of thousands of vectors routinely.
The +0.46 ms figure is true of the database it was taken on and false as a
general claim — issue **0899**'s class. Nothing bounds it and **no row measures
it**. Full table and the three sketched fixes: `doc/claude/issues/0904-*.md`.

Row **V68** is the standing proof that the cheap path really is taken: it puts a
*different* run on disk at the same path, leaves the waveform window showing the
old one, and requires the press to answer from memory. A change that started
re-reading the file on every press reds there.

## Rows

Both arms unless noted. Headless
(`./src/xschem --nogui --pipe -q --nolog --script ...`) and the persistent dev
display (`tests/headless/devdisplay.sh exec ...`, `:99`, 1920x1080x24,
**openbox 3.6.1** live).

| row | file | what it holds |
|---|---|---|
| **V66** | `test_op_annot.tcl` | the two-press sequence end to end through the real supply chain — press, re-run, press — and the second press paints the SECOND run. Leg 3 asserts the design window really holds a database after press 1; leg 4 asserts the waveform window really moved, before the press is asked anything. |
| **V67** | `test_op_annot.tcl` | the refusal branch **clears what the earlier press painted**: `viewergone` by name, one warning in the CIW, `raw loaded` = -1, the sheet bare, the mask unchanged. |
| **V68** | `test_op_annot.tcl` | the cache hit is a cache hit — a different run on disk at the same path is NOT read. The performance witness. |
| **V69** | `test_op_annot.tcl` | STRUCTURAL: the consult is not skippable when a database is already attached; the question is in the gate's own condition; the unwind precedes the supply; the consult is the helper's first statement. |
| **V70** | `test_op_annot.tcl` | the waveform window is closed, so the numbers stay. Sole witness for sabotage variant S-A14-3. |
| **V71** | `test_op_annot.tcl` | an operating point on the sheet and a transient in the window: leg a annotates the transient (was `notran`), leg c refuses and takes the OP numbers off too. |
| **B12j** | `test_annot_show_menu.tcl` (display) | the same two-press sequence through the product's own `wviewer::attach_raw`, with **no** design-window clear between the presses — the clear in B12d is exactly what hid this from every real-chain row. |
| **B12k** | `test_annot_show_menu.tcl` (display) | the refusal face through the real chain: `viewergone`, `raw loaded` = -1, reading a value raises, the mask unchanged. |

**One existing row's slicer was tightened, and its goldens did not move.**
`opa_v_arm` in `test_op_annot.tcl` used to define a refusal arm as *everything
after the previous `return`*, which is the same thing only while every statement
in between belongs to some arm. The new gate preamble does not: its
`_annot_tran_unwind` sits between `return nocursor` and `return staleraw` with no
`return` in between, so the old slice would have handed **V52**'s `staleraw`,
`noraw`, `viewerunread`, `viewergone` and `viewerfilling` roll-call entries a
call made a nesting level away from them. The slice is now anchored on each arm's
own `if`, which is a **strict subset** of the old one — the row can only get
sharper, and it still reds on an unwind added inside any arm. V52's nine
roll-call goldens are byte-for-byte what they were.

## The repair pass, 2026-08-28 — what the sabotage run sent back

Three things came back and all three were acted on.

1. **A defect this fix introduced, filed as 0902 and fixed in the same commit.**
   The gate's detach was a bare `xschem raw clear`, which unloads the window's
   **whole** registry. On a mixed-signal bench that took the user's co-simulation
   VCD off with the stale analog run. `cadence::_annot_db_release` now names the
   file and never touches a digital database. Rows **V72**, **V73**, **V75**
   behavioural (both arms), **V74** structural.
2. **An unwitnessed line, now pinned rather than re-described.** The
   `if {[string is integer -strict $loaded] && $loaded >= 0}` wrapping the gate's
   unwind can be deleted with every suite still ALL PASS on both arms. Measured:
   it is a **cheap exit, not a guard** — with nothing attached the unwind finds
   nothing to take off and writes back the mask it just read, so its only effect
   is one fewer redraw on a press that starts from an empty design window, and no
   row counts redraws. It is kept, its comment now says exactly that, and
   **V74 leg 8** is its honest witness.
3. **A comment this item wrote was falsified by measurement — issue 0899's own
   class.** It claimed the unwind's placement above the supply guarded a corner
   *"no fixture in the tree can stage"* and that V69's structural leg was its only
   witness. Deleting the preamble reds **V66**, **V67**, **V71** on both arms and
   **B12j**, **B12k** on the display arm, and V66's failure **is** that corner.
   The comment, the row's own prose and the spec paragraph built on it are
   rewritten. The row's leg numbering was off by one in the same three places and
   is corrected: measured against the eight-element vector, removing the gate
   disjunct zeroes legs **3 and 4**, deleting the preamble zeroes **5**, a
   behaviour-neutral early return in the currency test zeroes **7**, and deleting
   the fingerprint compare zeroes **8**.

## Debts

* **`rule 0900b`** (filed by the RED pass, kept): when the second press cannot
  reach the waveform window's data, **operating-point** numbers a *different*
  press painted come off the schematic too. The driver ruled on *"the numbers the
  earlier press painted"*; this goes one step past that. Row **V71 leg c**.
* **`look`** (filed by the RED pass, kept): the schematic going **bare** on a
  refusal is a pixel change no suite can judge.
* **`rule 0902`** (filed by the repair pass): the boundary chosen for the detach
  — take off the *current* database only, and never a digital one — against the
  two alternatives. See `doc/claude/issues/0902-*.md`.

## ⚠ FIXED FOR THE WAVEFORM WINDOW, AND ONE DOOR IS STILL OPEN — ISSUE 0903

Read the fix's scope literally. `cadence::_annot_tran_db_current` consults the
**ASE waveform window**, and only that. XSCHEM also draws waveforms **on the
schematic sheet itself**, and this mode reads a cursor off them on purpose
(`cadence::_annot_tran_cursor` falls back to `graph_flags` bits 2 and 4). On that
path the consult answers empty, the currency test keeps the cache without asking
anything, and **press → re-run → press repaints the first run's numbers under the
same confident caption** — this issue's own defect, through a door this issue's
fix does not reach. Measured on both arms by the write-up agent before the commit
landed, not inherited:

```
X1 cursor_source=3e-09 B sheet     <- the SHEET's own graph, no viewer anywhere
X1 press2=0 ok  supply_calls=0     <- the whole supply skipped, exactly as before
X1 paint=d 3 g 0.9 0 0.0 0 0.0     <- run 1, while run 2 sits on disk
```

Row **V70** asserts the cache is kept on that arm, which is correct for the
closed-window case it was written for and is exactly what makes this face
invisible. Filed as **0903**, with the shape of a fix and the reason it is not a
drive-by.

## Still open, and deliberately not touched here

* **0903** — the same defect on the sheet's own waveform graph, above. Filed,
  measured on both arms, **not fixed**.
* **0904** — the cost of revalidating scales on saved vectors, not points, and
  the number this issue published understates it by orders of magnitude on a
  `.save all` bench. The claim is corrected here; the cost is open and unguarded.
* **0684** — the identical *"is SOME database attached"* predicate on the
  **operating-point** surface (`cadence::_annot_op_db_ok`, `cadence::annot_mode`).
  A comment naming it now sits beside the fixed gate so a later reader does not
  think it was missed.
* **0885** — the two-window compare is a sample (the last point of every column),
  not a proof. Unchanged: the fingerprint this fix compares on is the same one
  the supplier already compared on.
* **0901**, **0897**, **0888** — wording, not this item.
