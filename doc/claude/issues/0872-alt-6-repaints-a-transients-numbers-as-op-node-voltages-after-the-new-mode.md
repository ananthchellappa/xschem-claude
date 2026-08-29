# 0872 — the two node-voltage bits share one render class, so the mode the user picked no longer describes the number on the sheet

**Status:** ✅ **FIXED 2026-08-27**; **RULING SETTLED 2026-08-29** — the detach stands, see the closing RULING section. Fixed in **two passes**, and the first one did not
close it. The A3h hardening pass added the refusal; verification then showed the
ruling-0856 breach was still **one key press away** from the most ordinary desktop
state there is, because the chord's OWN candidate search loads a transient AFTER that
refusal has already said yes. The A3h **repair** pass added the second ask and the
unwind. §6 is the measurement; §7 is what landed. ⚠ **THE MECHANISM THIS FILE
NAMES IS WRONG**; the correction is in §1. The residual — the render class still
carrying no provenance stamp, and the ASE-L menu writing the mask past the refusal —
is **issue 0877**, OPEN and awaiting a user ruling.
Originally filed by the A3 write-up, 2026-08-27,
from the adversary leg of the 0868 run. Class: **RULING 0856** reopens on the road
issue **0868** built, plus a status line that describes a state that is not the one
shown.

Owner: `annot_class_mask()` and `text_hidden()` in `src/actions.c` (~:1520/:1541),
`cadence::_annot_msg` in `utils/annot_mode.tcl` (~:266).

## The user's ruling this is measured against

> **0856 (user, verbatim)** — *"if OP is part of the run, then plot from OP. We
> haven't yet built anything for annotating from TRAN results, so it should do
> nothing silently. Why complicate things?"*

0868 built the on-request transient road correctly. But it wired bit2
(`ANNOT_SHOW_TRAN`) onto the SAME content class as bit1 (`ANNOT_SHOW_VOLTAGE`) —
`annot_class_mask()` returns `ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN` — so the two
bits are two switches onto ONE store. Which is why a bare bit2 paints at all, and
also why the mode no longer tells the user where the number came from.

## Measured, 2026-08-27, shipped binary + the 0868 tree, paint by SVG export

**Direction 1 — a transient's numbers relabelled as operating-point node voltages.**
Fixture `/tmp/a3m` (lab_pin `d`, 5-point transient, graph, cursor B at 3 ns). Three
keystrokes after using the new mode:

```
WU3 state=ok mask=4 PAINTED=d 3                                   <- Alt-Shift-6, correct
WU4 after Ctrl-6: mask=0 PAINTED=d
WU5 after Alt-6:  mask=2 PAINTED=d 3 sim_type=tran
WU5 status line = OP annotation ON (node voltages) -- loaded
```

`Alt-6` on a database whose `sim_type` is `tran` does **not** "do nothing silently".
It turns the transient numbers back on and labels them operating-point node voltages.

**Direction 2 — an operating point's number rendered by the TRANSIENT bit.**

```
WUA sim_type=op  annot=0 0 -1
WUA mask 1 over an OP database: PAINTED=d
WUA mask 2 over an OP database: PAINTED=d 1.234
WUA mask 4 over an OP database: PAINTED=d 1.234       <- the transient bit
WUA mask 6 over an OP database: PAINTED=d 1.234
```

**And the combined sentence describes two kinds of number when the sheet only ever
shows one:**

```
WU6 mask 6 line = OP annotation ON (node voltages + transient node voltages) -- loaded
WU9 status line (mask 4, op database) = OP annotation ON (transient node voltages) -- loaded
```

## How much of this is 0868's

Partly pre-existing: with the deliberately-ungated `xschem set cursor2_x`
(0868's Part-0 deviation, itself owed a ruling), a transient number could already be
published and then shown by `Alt-6`. What 0868 added is the **most convenient way to
load that state** — one chord — and a **third label** that now names a provenance the
render path cannot honour.

## Options

1. **One store, one provenance stamp.** Record which analysis published the current
   annotation (the engine already knows: `xctx->raw->sim_type`) and let each bit
   render only its own kind, blanking otherwise (invariant I3's blank, not a
   fabricated number). Honest; costs a stamp and a test per bit.
2. **Collapse the two bits into one** and drop the third menu entry, keeping only the
   ACTION (annotate at the cursor) as a command rather than a mode. Smallest code;
   contradicts 0868's shipped menu, which the user has not yet seen.
3. **Leave the render shared and fix only the WORDS** — one label, "Node voltages",
   with the source named in the sentence the mode mints. Cheapest; leaves `Alt-6`
   re-enabling transient numbers, which is the 0856 breach.

Recommended: **1**, and it wants the user's ruling because option 2 removes a menu
entry they asked for. ⚠ Rule debt `0868` already asks the user about the neighbouring
deviation; ask both together.


---

# The fix (A3h, 2026-08-27), and the mechanism correction

## 1. The mechanism named above is not the one the user can reach

This file blames **the shared render class** — the `ANNOT_SHOW_VOLTAGE |
ANNOT_SHOW_TRAN` return in `annot_class_mask()`, `src/actions.c:1533`.

Measured with `cadence::annot_tran` **never called** and bit2 **never set**, `Alt-6`
alone (mask 2, bit1 by itself) already repaints the transient's `d 3`:

```
### 0872-B  Alt-6 ALONE, no transient mode ever used
  before        : mask=0  annot=2 3e-09 0  PAINT=d g
  Alt-6         : mask=2  PAINT=d 3
  Alt-6 status  : OP annotation ON (node voltages) -- raw already loaded
```

So that return is **not in the chain in this direction at all**. The real chain is:

1. `xschem set cursor2_x` publishes a transient sample into `cursor_b_val[]` and sets
   `annot_p >= 0` — deliberately ungated, pinned by row **V25** as a typed request;
2. the six `@spice_get_voltage` render gates in `src/token.c` test only
   `live && sch_waves_loaded() >= 0 && annot_p >= 0` — **they never ask which analysis
   minted the number**;
3. `annot_show` is only a **visibility** switch, read in `text_hidden()`;
4. `cadence::annot_mode` flips that switch **without ever asking
   `xschem raw sim_type`**, while its sibling `cadence::annot_tran` refuses the wrong
   analysis by name **nine lines away** in the same file.

The asymmetry is inside one file, and the fix belongs at **the point where the mode is
chosen**, exactly as the hardening brief predicted.

## 2. A third face, recorded nowhere until now, and it is the worst

With a transient attached and **nothing published**, `Alt-6` painted nothing but still
**spoke**, and what it said was impossible:

```
### 0872-C  a TRANSIENT attached with NOTHING published
  annot         = -1 0 -1  mask=0
  Alt-6         : mask=2  PAINT=d g
  Alt-6 status  : OP annotation ON (node voltages) -- a raw is loaded but it published
                  no operating point: use Waves > Op Annotate, or `xschem raw_clear`
                  then press again
```

`Waves > Op Annotate` on a transient is **precisely** what A0's `update_op()` guard
(`src/save.c:2293-2298`) refuses. Ruling 0856 says *do nothing silently*; this said
something, and what it said was wrong. **Any fix that only gated the paint leaves this
sentence standing** — which is why the fix returns before the mask is written and
before any sentence is minted.

## 3. What landed

`utils/annot_mode.tcl`, two hunks:

* new `cadence::_annot_op_db_ok` — 1 when the ATTACHED database can supply an
  operating point (`op` / `dc`, spelling copied from `update_op()`'s own guard so one
  grep finds one predicate shape), **and 1 when nothing is attached at all**, because
  a refusal that swallowed *"there is no database to ask"* would stop `6` being able
  to FIND a raw at all. `xschem raw sim_type` RAISES with nothing loaded — measured —
  hence the catch.
  ⚠ **THIS BULLET USED TO SAY "A0's guard is the backstop", AND THAT WAS FALSE.**
  `update_op()`'s guard only declines to PUBLISH. It does not stop the mask being
  written, the sentence being minted, or `raw_read()`'s tail gate publishing at
  cursor B. §6 is the measurement that refutes it.
* one line in `cadence::annot_mode`, after the mask is computed and **before**
  `xschem set annot_show`:

  ```tcl
  if {$mask != 0 && ![cadence::_annot_op_db_ok]} { return }
  ```

  `$mask != 0` **exempts the off switch**: Ctrl-6 must always clear, clearing never
  puts a number on a sheet, and a refusal that swallowed Ctrl-6 would strand the user
  with bit2 armed and no way to turn it off.

Measured after that first pass: **with a database already attached**, on a transient
sheet `Alt-6` and `6` write no mask, paint nothing, and a status-line sentinel planted
before the press survives it. On an operating-point database `Alt-6` still arms bit1
and still paints `7.5`; with no database and no file on disk `6` still runs the
candidate search and still speaks.

⚠ **AND THAT SENTENCE'S FIRST FOUR WORDS ARE THE WHOLE HOLE.** With **nothing**
attached the chord goes and loads one itself, past the refusal. See §6.

## 4. The rows

* **V31** — five legs, one check, with a held sentinel before every press because
  *"said nothing"* cannot be read off a status line that is never empty. Leg 2 is the
  Ctrl-6 exemption's only guard; leg 5 is face C above.
* **V31b** — the positive control. Without it a fix that turned the mode chooser into
  a no-op everywhere would pass V31 and both shipped OP chords would be dead.

Tcl sabotage, run 2026-08-27, no build needed:

| variant | mutation | reds |
|---|---|---|
| S14 | the refusal line deleted | **V31** |
| S14b | the `$mask != 0` term dropped, so Ctrl-6 is refused too | **V31** |

## 6. THE SECOND PASS: the breach was still one key press away, and §3's own defence was false

Found by verification of the A3h pass, reproduced independently here on the repo's
own tree. **Input: the most ordinary desktop state there is.** A `.tran` has just been
run, so `$netlist_dir/<cell>.raw` exists and is a Transient Analysis raw. Nothing is
attached yet — `xschem raw loaded` is `-1` — because the waveform viewer has not been
opened. Press `Alt-6` **once**:

```
### 0872-D  ONE Alt-6, nothing attached, a transient at the candidate path
  before        : loaded=-1  mask=0
  after Alt-6   : mask=2  loaded=0  sim_type=tran
                  status = OP annotation ON (node voltages) -- loaded <that transient>
  plain 6       : mask=1
                  status = OP annotation ON (device OP info) -- loaded <that transient>
```

...and with a waveform strip on the sheet, cursor B parked at 3 ns and
`Live annotate probes with 'b' cursor` **ticked** — measured under sabotage S18, which
is exactly the pre-repair code:

```
  after Alt-6   : mask=2  annot=2 3e-09 0  PAINT=d 3 g 0.9 0 0.0 0 0.0
                  status = OP annotation ON (node voltages) -- loaded <that transient>
```

A transient sample on the pins, under a status line calling it OP node voltages.
**RULING D5-1, with the sentence lending it authority.**

**Mechanism.** `cadence::_annot_op_db_ok` answers **1** whenever `xschem raw loaded`
is `< 0` — deliberately, so the chord can still go and find a file. `annot_mode` then
runs its OWN candidate search (`_annot_raw_candidate` → `$netlist_dir/$cell.raw`, or
`::ase::last_rawfile` in an ASE session) and **loads that transient itself**, after
the one and only gate. `update_op()`'s guard is **not** a backstop for that: it only
declines to publish, and `raw_read()`'s tail gate (guard **G1**, `src/save.c`) then
publishes at cursor B on that very load.

**Why the rows could not see it, and it is the same shape the defect had.** V31
exercises the refusal only with a raw **already attached**; V31b leg 2 exercises the
candidate search only with **no raw on disk**. Nothing composed them — the same gap
the hardening brief quoted against the previous pass (*"V4 tests the paint without the
sentence, V17 tests the sentence without data, and nothing composes them"*),
reproduced one layer up.

## 7. What landed in the repair

`utils/annot_mode.tcl`, one hunk, still **Tcl only, no C change**: a **second ask** at
the end of the candidate branch, after the load, with an unwind.

```tcl
if {![cadence::_annot_op_db_ok]} {
  catch {xschem raw clear}
  catch {xschem set annot_show $cur}
  catch {xschem update_all_sym_bboxes}
  catch {xschem redraw}
  return
}
set state loaded
```

Three decisions in it, each of which a cheaper shape gets wrong:

* **It unwinds; it does not refuse earlier.** Making the first gate say no when
  nothing is attached is the tempting one-liner and it breaks the chord's ability to
  find a raw at all — measured, it reds **V31d, N8 and A64-3**, because pressing `6`
  with nothing loaded must still search, still load, and still name the file.
* **The mask goes back to `$cur`, never to a bare 0.** A press that cannot do its job
  must not clear bits the press did not set. Row **V31c** leg 3 starts at mask 1 and
  requires mask 1 back.
* **The database this proc attached itself is detached.** Leaving it attached is not
  *"nothing"*: the waveform viewer would hold data the user never loaded and cursor
  motion would start publishing from it. We only reach the search when nothing was
  attached, so the clear returns the session to exactly the state the press found.

### The rows the repair added

* **V31c** — four legs: `Alt-6`, `6`, `Alt-6` from a non-zero mask, and the waveform
  strip with the Live-annotate box ticked. Each asserts the mask, that **nothing is
  attached**, that the held sentinel **survives**, and the paint; leg 4 also asserts
  nothing was published.
* **V31d** — the candidate search's own positive control: the **same** candidate path,
  an **operating point** in it, must still load, still arm, still paint `7.5` and
  still name the file. The only difference from V31c is the analysis in the file, so
  a refusal that cannot tell them apart reds here.

Tcl sabotage for the repair, run 2026-08-27, no build needed:

| variant | mutation | reds |
|---|---|---|
| S18 | the second ask deleted (the pre-repair code) | **V31c**, and only V31c |
| S19 | the unwind fires unconditionally | **V31d**, N8, A64-3 |

## 8. What is NOT fixed — issue 0877

* **Direction 2**, and this one IS the OR at `actions.c:1533`: over an
  **operating-point** database, masks 4 and 6 paint the OP number `1.234` under the
  wording *"OP annotation ON (transient node voltages)"* — a number minted by an OP
  solve, labelled transient. D5-1 in the mirror direction.
* The ASE-L `Results > Annotate` checkbuttons write `annot_show` **directly** in
  `ase::ui::annot_apply` (`src/ase_window.tcl:2489`) and so bypass the mode chooser's
  new refusal entirely.

Neither is reachable by the chord this file measured. Both are closed by one thing —
option 1 above, a provenance stamp in the render class — which would red row V9's
mask-2 leg and change what the ASE-L menu does. That is a separate item and it needs
the user's ruling: **issue 0877**, owed as `rule 0877`.

## 9. Debt

After this fix, `Alt-6` and `6` on a transient sheet do **literally nothing** — no
paint, no status line, no CIW. That is ruling 0856 verbatim, so it was applied without
asking, but a user who presses a key and gets no acknowledgement at all may read it as
a broken keyboard. Owed as a `look` so the user sees the silence once. Ruling 0857
(*"if OP has been run but we don't have device info … we want to say something in the
CIW"*) covers only the case where OP HAS been run, which this is not.

---

## 10. RULING, 2026-08-29 — the detach stands (decided under the user's "decide the 23" instruction)

**Question put to the user (`rule 0872`):** after a transient run, pressing `6` or
`Alt-6` on the schematic finds the run's results file, opens it, decides it is the
wrong analysis, and closes it again. Should it instead leave that file loaded, as a
side benefit?

**Decided: keep the detach.** `cadence::annot_mode` continues to put back whatever the
key press attached — the whole-registry clear when nothing was loaded on entry, the
by-name `::op_annot::db_detach` otherwise (issue 0914's split) — restore the mask to
`$cur`, redraw, and say the plain-English `notop` sentence. **No code moves.**

Why, against the standing rulings:

* **Cadence.** In Virtuoso an annotation gesture never populates the waveform
  display; choosing which results are open is its own explicit act. A chord that
  asked for operating-point numbers and came back having opened a transient is not a
  use mode Cadence has.
* **"Annotation must only happen when the user requests it."** The user asked for
  DC node voltages. Leaving the transient attached is not "nothing": a waveform strip
  on the sheet would start plotting a run the user never opened, and cursor motion
  would publish that run's samples onto the pins — which is issue 0872's own defect
  arriving by the back door, and RULING D5-1 with it.
* **Nothing is lost.** The refusal names the analysis and points at `Alt-Shift-6`,
  and `cadence::annot_tran` runs its **own** supply (`_annot_tran_supply`,
  `utils/annot_mode.tcl:2061`) — the waveform-window consult of issue 0881, then the
  candidate path. So the advice in the sentence works from exactly the state the
  detach leaves behind; the user does not have to re-find the file. `Waves > Op
  Annotate` remains the explicit route for loading one by hand.
* **Precedent, already shipped on the sibling surface.** `cadence::annot_tran` keeps
  its supply *below* the cursor resolve for this reason, naming this unwind: a press
  that refuses must not attach a database on its way out
  (`utils/annot_mode.tcl:2438`, rows V38/V67/V71/B12k).

**§9's debt is superseded in one respect:** the press is no longer silent. Since
ruling 0857 landed it says *"No operating point results are loaded. These are from a
'tran' run instead, so there are no operating-point numbers to show. Run an operating
point analysis, or press Alt-Shift-6 for node voltages at the waveform cursor."* The
`look` debt for the silence is therefore about a sentence, not about nothing at all.

**Unaffected:** issue 0877 (the render class still carries no provenance stamp, and
the ASE-L `Results > Annotate` checkbuttons still write the mask past this refusal)
is a separate ruling and this does not touch it.

**Verified in the tree before ruling:** `utils/annot_mode.tcl:1302-1334` (the second
ask and both detach spellings), `:893-903` (the sentence the user reads),
`tests/headless/test_op_annot.tcl:12658` (V31c — four legs, each asserting
`xschem raw loaded` back to `{0 -1}`, no paint, the golden sentence, leg 3 the `$cur`
mask), `:12691` (V31d — an operating point at the same path still loads, arms and
paints).

---

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, 2026-08-29: **"decide the 23, leave 0861 and 0299 for me"**.
This debt was one of the 23 a read-only audit classified as **cheap and obvious** —
a question whose answer the standing rulings already settle — so it was decided on
the user's behalf rather than added to their reading pile. (0861 and 0299 were
excluded and remain theirs.) §10 above recorded the same decision during the same
pass; this section is the formal record and carries the parts §10 does not: the
instruction it was decided under, the adversary's verdict, and the reversal line.

### The ruling, as an instruction to the codebase

**Keep the detach.** When the `6` / `Alt-6` chord's own candidate search opens a
results file and then finds it is not an operating point, it must put the session
back exactly as the key press found it:

* take the file back off — the whole-registry clear when **nothing** was loaded on
  entry, the by-name `::op_annot::db_detach` otherwise (issue 0914's split);
* restore the annotation mask to `$cur`;
* redraw;
* say the plain-English `notop` sentence, which names the analysis it found and
  points the user at `Alt-Shift-6`.

It must **not** leave the file loaded as a side benefit. Rows **V31c** (nothing
attached, all four legs) and **V31d** (the operating-point positive control) stay as
the fence around this.

**One line for the user:** pressing `6` or `Alt-6` right after a transient run will
keep closing the results file it opened to check — it won't leave a transient sitting
in your waveform window that you never asked to open; it tells you what it found and
points you at `Alt-Shift-6`, which goes and gets the file itself.

### Why

* **Cadence or nothing.** In Virtuoso an annotation gesture never populates the
  waveform display — choosing which results are open is its own explicit act. A chord
  that asked for operating-point numbers and came back having opened a transient is
  not a use mode Cadence has.
* **"Annotation must only happen when the user requests it."** Leaving the transient
  attached is not "nothing": a waveform strip on the sheet would plot a run the user
  never opened, and cursor motion would publish that run's samples onto the pins under
  an operating-point caption — this issue's own defect through the back door, and
  **D5-1** with it.
* **Nothing is lost by detaching.** The refusal names the analysis and points at
  `Alt-Shift-6`, and `cadence::annot_tran` runs its **own** supply
  (`utils/annot_mode.tcl:2061` — the issue 0881 waveform-window consult, then the
  candidate path), so the advice works from exactly the state the detach leaves.
  `Waves > Op Annotate` remains the by-hand route for loading a results file.
* **Precedent already shipped on the sibling surface.** `cadence::annot_tran` keeps
  its supply *below* the cursor resolve, citing this very unwind, and calls
  `_annot_tran_unwind 1 $mask0` (`utils/annot_mode.tcl:2438`). Same rule, one surface
  over.
* **0900** makes the attached database a cache and never an authority, so nothing
  downstream gains anything from the file being left on.

### What was verified in the tree, so a later reader need not re-derive it

* `utils/annot_mode.tcl:1302-1334` — the second ask: `if {![cadence::_annot_op_db_ok]}`
  reads `xschem raw sim_type` **before** detaching, then `xschem raw clear` when
  `$entry_loaded < 0` else `::op_annot::db_detach`, then `xschem set annot_show $cur`,
  bbox update, redraw, and `cadence::_annot_say [cadence::_annot_msg $cur notop $st {}] warn`.
  The detach this debt asks about is live and shipped.
* `utils/annot_mode.tcl:893-903` — the sentence the user actually reads: *"No
  operating point results are loaded. These are from a 'tran' run instead, so there
  are no operating-point numbers to show. Run an operating point analysis, or press
  Alt-Shift-6 for node voltages at the waveform cursor."*
* `tests/headless/test_op_annot.tcl:12658-12665` — row **V31c**, four legs (`Alt-6`;
  `6`; `Alt-6` from mask 1; a waveform strip with cursor B and Live-annotate ticked).
  Every leg golds `xschem raw loaded` == `{0 -1}` — nothing attached — plus the
  no-pins paint and the golden `notop` sentence; leg 3 golds mask 1 back, leg 4 golds
  `RAISED:No raw file loaded`.
* `tests/headless/test_op_annot.tcl:12691-12695` — row **V31d**, the positive control:
  the same candidate path holding an operating point still loads (`{0 0}`, `sim_type
  op`), still arms mask 2, still paints the pins and still names the file. The detach
  is not a blanket refusal of the candidate search.
* `utils/annot_mode.tcl:678-682` — `Waves > Op Annotate`, the by-hand route.
* Two attacks were run against the mechanism and both died. A whole-registry
  `xschem raw clear` cannot steal the waveform viewer's file: it routes through
  `extra_rawfile(3, NULL, ...)` (`src/save.c:1797`), which touches only this window's
  own registry, and the bare clear is reached **only** when this window held nothing
  when the key went down. And a user's own hand-loaded transient never reaches this
  unwind at all — `cadence::_annot_op_db_ok` (`utils/annot_mode.tcl:1014`) refuses at
  the top, before the candidate search.

### Does anything move?

**No. This ratifies behaviour that already ships.** No code change is implied, and no
test row changes. Two housekeeping notes for a later reader, neither of them work
owed by this ruling:

* **§9's debt is superseded in one respect.** The press is **no longer silent** —
  since ruling 0857 it speaks the `notop` sentence above. The outstanding `look` is
  therefore about whether that *sentence* reads right, not about a dead keyboard.
* **A slight over-claim, corrected.** "The advice works from exactly the state the
  detach leaves" is true of the *file* but not of the whole press: `Alt-Shift-6`
  resolves a cursor first, so on a bench with no waveform window and no graph placed
  the user meets a second, different plain-English refusal asking them to turn on
  cursor A or B. That chain is progressively actionable, and it is **independent of
  the detach** — a cursor comes from a graph or a viewer window, never from an
  attached results file, so leaving the transient loaded would produce the identical
  second sentence. It argues about wording, not about the unwind.
* **Untouched:** issue **0877** (the render class still carries no provenance stamp;
  the ASE-L `Results > Annotate` checkbuttons still write the mask past this refusal)
  is a separate ruling and remains the user's.

**The adversary ran** and could not overturn it: it granted the question is unusually
obvious (three standing rulings pull the same way, nothing pulls back, and the
decision moves no code), and both of its attack scenarios — the registry clear
stealing the viewer's file, and the unwind destroying a transient the user loaded by
hand — were refuted in the tree. Its verdict: **decision stands**.

**The user may reverse this at any time; it was decided to spare their attention, not
to bind them.**
