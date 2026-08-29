# 0865 — with "Live annotate" off, a node voltage stays on the sheet after the cursor leaves it

STATUS: **RULING SETTLED 2026-08-29 — see the RULING section at the foot of this file.** ✅ **CLOSED 2026-08-27 by issue
[0868](0868-on-request-transient-node-voltage-annotation-at-the-waveform-cursor.md).**
Introduced by **0864** (the opt-in split), found by that item's adversarial
verification and re-measured from scratch here.

RULED: ✅ **2026-08-29 — the shipped reading is ACCEPTED. Both arms of
`xschem set cursor2_x <t>` keep publishing, ungated.** Decided under the user's
2026-08-29 instruction to settle the cheap questions rather than queue them.
This CLOSES the live question the `rule` debt carried; nothing in the tree moves.

**What was verified in the tree before ruling** (not taken on the audit's word):

* The two gates 0868 added are real and spelled identically to the six
  cursor-motion sites: `src/save.c:1302` (loading a waveform file) and
  `src/actions.c:4867` (descending into a child), both
  `tclgetboolvar("live_cursor2_backannotate") && (xctx->graph_flags & 4)`.
* Both `set cursor2_x` arms are genuinely ungated — the graph arm
  (`backannotate_at_cursor_b_pos`) and the no-graph arm
  (`backannotate_at_cursor_b_nograph`), `src/scheduler.c:12157`–`12194`.
* The `cursor1_x` block this issue's inventory listed as an ungated publisher
  really is inside `#if 0`, `src/scheduler.c:12146`–`12155`. Dead code.
* Row **V25** exists and pins both arms, `tests/headless/test_op_annot.tcl:12163`.
* The box really does ship unticked, `src/xschem.tcl:16819`.

**The reason the answer is not close.** *Publishing is not painting.* The
`annot_show` mask is a text-HIDING mask (`xschem.h:2262`, `text_hidden()`), and
the six `@spice_get_voltage` readers in `src/token.c` no longer consult the
Live-annotate box at all (`token.c:4328` and the ISSUE 0864 paragraph at
`:4348`). So with the mask at its shipped 0, typing `xschem set cursor2_x 3e-9`
writes a value into the database and puts **nothing on the schematic** — this
issue's own P1/P2 measurement. The non-gating can only change what the user
SEES after the user has already pressed `6`, `Alt-6` or `Alt-Shift-6`. So
"MUST ONLY HAPPEN WHEN USER REQUESTS IT" is satisfied twice over: the class was
armed by a request, and the time was named by a typed one.

**Why the drag/type asymmetry is coherent, not arbitrary.** The tick box is
labelled *"Live annotate probes with 'b' cursor"*. **Live** is the whole word:
it governs the continuous following that happens as a side effect of dragging a
cursor around while reading a plot. A typed sentence naming one time point is
not live, it is a one-shot statement, and it stamps `annot_x` at the position it
was measured at — so it is never stale at the moment it happens.

**Why gating it would be the worse defect (INTENT OVER MECHANISM).**
`xschem set cursor2_x` is the scripting road and S11's only road; a grep for the
verb hits 102 lines across seven suites (`test_op_annot` 92,
`test_wave_cursor_crossdb` 4, `test_wave_viewer` 2, plus
`test_wave_crossdb_trace`, `test_spice_get_node_0861`,
`test_backannotate_digital`, `test_annot_show_menu` — comment lines included, so
read it as an order of magnitude, not a call count; 0868's own figure was 43
across five suites). Most of those suites never mention the box. Gating it would make a typed command silently do nothing
because of a GUI checkbutton that ships off — correct at every joint and
collectively absurd.

**No GUI gesture reaches the ungated arm.** `wviewer::cursor_toggle` runs
`xschem new_schematic switch $wp` before its `set cursor2_x`
(`src/wave_viewer.tcl:14239–14250`), so the waveform window's own cursor
buttons act inside the viewer's context and never touch the design sheet.
`Alt-Shift-6` goes through `xschem annotate_at`, a different verb. The only road
to the ungated arm is a command someone types.

**And the D5-1 hole this publish used to open is already shut.** The worry that
a transient sample could surface under an "OP node voltages" heading was issue
0872; `cadence::_annot_op_db_ok` / `cadence::annot_mode` (`utils/annot_mode.tcl`)
now return silently before the mask is written, so `6` and `Alt-6` do nothing on
a transient sheet. Ratifying this publish does not re-open it.

**What stays open and is NOT covered by this ruling:** the provenance stamp on
the node-voltage render class is issue **0877**, still owed. And 0868 measured
that both plans leave the identical residual — after any on-request annotation
the number persists while the cursor moves on — so gating would have bought
nothing here either.

## How it was closed — and what deliberately did NOT change

**⚠ READ THIS BEFORE "FINISHING THE GATING".** 0868 gated the two ACQUISITION
publishers and left both `xschem set cursor2_x` arms publishing, on purpose.

* **GATED** — `raw_read()`'s tail (`src/save.c`, guard G1) and
  `descend_schematic()`'s tail (`src/actions.c`, guard G2) now carry the same
  `tclgetboolvar("live_cursor2_backannotate")` term the six cursor-motion sites
  have always carried. Loading a waveform file and walking into a child are things
  the PROGRAM does; neither is a request.
* **NOT GATED, DELIBERATELY** — both arms of `xschem set cursor2_x <t>`. That verb
  is a sentence somebody TYPED naming a time, it stamps `annot_x` at the position
  it was measured at, it is the scripting verb and step S11's only road, and the
  waveform viewer's own call runs inside the VIEWER's context and never reaches the
  design sheet. **Row V25 of `tests/headless/test_op_annot.tcl` pins that
  decision**, so a later crew meets an explained row rather than what looks like a
  missed gate. Ratification is owed to the user as a `rule` debt on 0868.
* **THE INVENTORY IN THIS ISSUE IS WRONG IN BOTH DIRECTIONS**, measured:
  `src/scheduler.c:12080`, listed here as an ungated publisher, is inside `#if 0`
  and is dead code; and the `else if(backannotate_at_cursor_b_nograph())` arm of
  the same `set cursor2_x` is a **fourth** publisher this issue never listed.
* **THE USER'S DOOR IS THE NEW MODE.** Gating alone was not shippable: measured
  with the box off, NO gesture in the program re-measured the stale number — not
  `s`, not `Alt-6` again, not `Ctrl-6` then `Alt-6`. 0868's `Alt-Shift-6` chord and
  ASE-L **Results > Annotate > Transient Node Voltages (at cursor)** item are the
  on-request door that makes the gating usable.
* This was also **finishing 0856**, not merely repairing staleness: `update_op()`
  already refused a transient, so the `6` chord painted nothing on one — while
  these two doors put a transient node voltage on the operating-point surface
  unasked, which is exactly what the user's *"it should do nothing silently"*
  forbids.

Acceptance: row **V24** of `tests/headless/test_op_annot.tcl` is the transcript
below, end to end, as four painted SVG lists; **V22** and **V23** are the two
guards, each with a box-ticked positive control.

## What the user sees

1. Plot a transient, put cursor B at 4 ns.
2. Load the waves.
3. Press **`Alt-6`** — node voltages appear. Node `d` reads **4**. Correct: at
   4 ns, `v(d)` really is 4 V.
4. Press **`s`** in the graph to swap the cursors. Cursor B is now at 1 ns, where
   `v(d)` is **1 V**.
5. **The schematic still says 4.** Pressing `Alt-6` again does not refresh it.
   Nothing on the sheet says which time point that 4 belongs to.

The number is not fabricated — it was measured, at 4 ns — but it is displayed
beside a cursor that has moved on, which is the reading rulings **D5-1** and
**D4-3** exist to prevent.

## Why this is new, and it is 0864's doing

Before 0864, **Simulation > Graphs > "Live annotate probes with 'b' cursor"**
shipped TICKED, and it was also (wrongly) the render gate:

* ticked → every cursor move re-annotated, so the sheet could not go stale;
* unticked → the render gate blanked every node voltage, so there was nothing on
  the sheet to go stale (the 0864 BEFORE transcript, line B2f: *"box UNTICKED
  translate l1 @spice_get_voltage = ''"*).

0864 removed the render gate (correctly — the box's label promises only
"follow the cursor") and flipped the default to OFF (the user's demand). The
combination is a state that could not be reached before: **painted, and not
following.**

## Measured — 2026-08-27, binary as built for 0864, no rebuild

`./src/xschem --nogui --pipe -q --nolog --script <probe>`, fixture `g.sch`
(one `devices/lab_pin.sym` labelled `d`) plus a graph rect plotting `v(d)` from
a 5-point transient (0/1/2/3/4 V at 0/1/2/3/4 ns), cursor A at 1 ns,
cursor B at 4 ns. **`PAINTED` is the text actually emitted by an SVG export**,
not a token expansion — that distinction is the whole of this measurement, and
issue 0866 is what happens without it.

```
P0 shipped default: live_cursor2_backannotate=0  annot_show=0
P1 after loading waves, SHIPPED annot_show=0: token='4'  PAINTED texts = d
P2 after Alt-6 (annot_show 2):                token='4'  PAINTED texts = d 4
P3 after pressing s (cursor B now 1ns, v(d)=1):
     token='4'  annot=3 4e-09 0  PAINTED texts = d 4      <-- THE DEFECT
P4 after Ctrl-6 (annot_show 0):               token='4'  PAINTED texts = d
```

and, through the real chord (`cadence::annot_mode opvolt` — what `Alt-6` runs):

```
Q1 user presses Alt-6 (opvolt): mask=2 statusmsg='OP annotation ON (node voltages) -- raw already loaded'
   PAINTED = d 4   annot=3 4e-09 0
Q2 user presses s: cursor B now 1ns, v(d)@1ns=1
   PAINTED = d 4   annot=3 4e-09 0
Q3 user presses Alt-6 AGAIN to refresh: statusmsg='OP annotation ON (node voltages) -- raw already loaded'
   PAINTED = d 4   annot=3 4e-09 0                        <-- NO MANUAL REFRESH
```

The switch's remaining meaning still works, which is the positive control
(`probe3`, both legs identical but for the box):

```
R1 switch=1  cursorB 4ns labpin '4' -> after swap (B now 1ns) labpin '1'  annot 0 1e-09 0
R1 switch=0  cursorB 4ns labpin '4' -> after swap (B now 1ns) labpin '4'  annot 3 4e-09 0
```

## Mechanism — publication is not gated, only re-publication is

`backannotate_at_cursor_b_pos()` (`src/callback.c:1548`) is what writes
`xctx->raw->cursor_b_val[]` and stamps `raw->annot_p`. Its callers split in two:

**GATED on the switch** — these are the "follow the cursor" road, and 0864 left
them alone, correctly:

```
src/callback.c:2382  2553  2691  2747  3282   (cursor drags / clicks in a graph)
src/scheduler.c:13278                          (swap_cursors — the `s` key)
```

**NOT GATED** — these publish a cursor-B annotation whatever the box says:

```
src/save.c:1287        raw_read()      — loading waves
src/actions.c:4819     descend_schematic()
src/scheduler.c:12080 / 12112   `xschem set cursor2_x`
```

So with the box off the sheet still ACQUIRES a cursor-B annotation, and then the
gated half refuses to keep it current. That asymmetry is the defect. It was
invisible before 0864 only because the render gate hid the result.

## The shape of a fix, if the user rules that this must not happen

Gate **publication** on the switch instead of rendering: with the box off,
`raw_read` / `descend` / `set cursor2_x` publish nothing, `annot_p` stays -1,
nothing renders, and nothing can go stale. `6` and `Alt-6` are unaffected —
they publish through `update_op()` (`src/save.c:2276`), which never read the
switch and is a different road entirely. That keeps 0864's ruling intact
("the switch means follow-the-cursor") while removing the half-state.

The alternatives, so the ruling is a choice and not a rubber stamp:

* **(a) Gate publication** (above). Cost: with the box off, `Alt-6` on a
  *transient* would then paint nothing at all — because 0856 already ruled that
  `update_op()` does nothing silently for a transient, the cursor-B road is the
  only thing that publishes for one. That is arguably the ruled behaviour
  already ("we haven't yet built anything for annotating from TRAN results"),
  but it is a visible loss for anyone using `Alt-6` on a transient today.
* **(b) Re-annotate on demand.** Make `Alt-6` re-publish at the current cursor B
  even with the box off, so the sheet is refreshable by the chord the user
  already presses. Cheapest for the user; keeps a number on the sheet that is
  correct at the moment it is asked for.
* **(c) Say which time point it is.** Leave the value and make the sheet or the
  status line carry the annotated time, so a stale number is legible rather than
  silent. Most work, no behaviour removed.
* **(d) Accept it.** The box is off, so nothing follows the cursor — that is
  what off means, and Ctrl-6 clears the sheet.

## What is NOT wrong here — measured, so a later crew does not re-derive it

* **Nothing is painted unasked.** With the shipped `annot_show` of 0, loading
  waves paints no number at all (P1). The value only reaches the sheet after the
  user presses `Alt-6`. A report that says otherwise measured
  `xschem translate`, which is the token expansion and not the render path.
* **The user can still take them off:** `Ctrl-6` blanks them (P4). See **0866**.
* **The switch's own job is intact:** ticked, the annotation follows cursor B
  (R1, switch=1).

## Acceptance rows to write with the fix

Whichever option is ruled, these are the rows that pin it, and each needs a
PAINT (SVG-export) leg, not a `translate` leg — the token expands either way:

* **the stale row** — box off, `Alt-6`, then `s`: assert the painted text equals
  the value at cursor B's NEW position (or is absent, under option (a)).
* **the positive twin** — the identical sequence with the box ticked, which must
  keep following, so the row cannot pass by blanking everything.
* **the `Ctrl-6` control** — mask 0 paints no value in either arm.
* **a structural row** over the caller list above, since "gated" and "not gated"
  is a property of six-plus call sites that no single fixture reaches.

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim, on 2026-08-29: *"decide the 23, leave 0861 and 0299 for
me"*. A read-only audit had gone through the 57 queued ruling debts and sorted
out the ones whose answer is cheap and obvious; **this debt was one of the 23 the
user handed back to be decided** rather than read. 0861 and 0299 remain the
user's. So the decision below was made on the user's behalf, at the user's own
instruction — not by an agent deciding it was entitled to.

### The ruling, as an instruction to the codebase

**Both arms of `xschem set cursor2_x <t>` stay UNGATED on the "Live annotate
probes with 'b' cursor" tick box. Nothing in the tree moves.**

* `src/scheduler.c:12157`–`12194` — the graph arm (calling
  `backannotate_at_cursor_b_pos`) and the no-graph arm (calling
  `backannotate_at_cursor_b_nograph`) both keep publishing whatever the box says.
* The tick box governs **continuous following only** — the thing its own "Live"
  label promises. It must **never** gate a one-shot command somebody typed.
* The two ACQUISITION doors that 0868 gated **stay gated**: `src/save.c:1302`
  (loading a waveform file) and `src/actions.c:4867` (descending into a child).
  Those are things the program does on its own; neither is a request.
* **Do not "finish the gating".** Row **V25** of
  `tests/headless/test_op_annot.tcl` remains the pin that explains this to the
  next crew.

### Why

* **"MUST ONLY HAPPEN WHEN USER REQUESTS IT" is satisfied twice over, not
  breached.** *Publishing is not painting.* `annot_show` is a text-HIDING mask
  (`xschem.h:2262`, `text_hidden()`), and since 0864 the six
  `@spice_get_voltage` readers in `src/token.c` no longer consult the box at all
  (`token.c:4328`, and the ISSUE 0864 paragraph at `:4348`). With the shipped
  mask of 0, typing `xschem set cursor2_x 3e-9` writes a value into the database
  and puts **nothing on the schematic** — this issue's own P1/P2 measurement. The
  non-gating can only change what the user sees **after** they have already
  pressed `6`, `Alt-6` or `Alt-Shift-6`. So the class was armed by a request, and
  the time was named by a second, typed one.
* **D5-1 is satisfied.** The value is stamped at the position it was measured at,
  so it is right at the instant it lands.
* **INTENT OVER MECHANISM settles the other direction.** `set cursor2_x` is the
  scripting road and step S11's only road, exercised across seven suites most of
  which never mention the box. Gating it would make a typed command that names a
  time silently do nothing, forever, because of a GUI checkbutton that ships
  unticked — locally correct at every joint and collectively absurd.
* **CADENCE OR NOTHING points the same way.** "Live annotate probes with 'b'
  cursor" is a stock-XSCHEM leftover with no Virtuoso counterpart. Widening its
  authority over a typed command is the disfavoured direction, not the favoured
  one.
* **There is no cost on the accept side for the user to weigh.** With the
  annotation off — the shipped state — the typed command paints nothing at all.
  With it on, it puts the number for the time the user just named next to the
  node it was measured on, which is strictly better than leaving the previous
  time's number sitting there. A question with a real cost on only one side is
  not the user's to arbitrate.
* **The D5-1 hole this publish once opened is already shut.** A transient sample
  surfacing under an "OP node voltages" heading was issue 0872;
  `cadence::_annot_op_db_ok` / `cadence::annot_mode` (`utils/annot_mode.tcl`) now
  return silently before the mask is written. Ratifying does not re-open it.
* 0868 also measured that **both plans leave the identical residual**, so gating
  would have bought nothing here.

### What was verified in the tree, so a later reader does not re-derive it

* `src/save.c:1302` — guard G1 present:
  `if(tclgetboolvar("live_cursor2_backannotate") && (xctx->graph_flags & 4))` in
  `raw_read()`'s tail.
* `src/actions.c:4867` — guard G2 present, identical spelling, in
  `descend_schematic()`'s tail.
* `src/scheduler.c:12157`–`12194` — both `set cursor2_x` arms confirmed UNGATED.
* `src/scheduler.c:12144`–`12155` — the `cursor1_x` backannotate block this
  issue's inventory listed as an ungated publisher really is inside `#if 0`.
  Dead code; the inventory was wrong.
* `grep -n live_cursor2_backannotate src/*.c` — exactly **8** live call sites
  carry the gate (`callback.c` ×5, `actions.c`, `save.c`, `scheduler.c:13348`
  swap_cursors). Three further hits are C comments (`token.c:4354`,
  `token.c:4525`, `scheduler.c:2487`). None is in the `set cursor2_x` block.
* `src/xschem.tcl:16819` — `set_ne live_cursor2_backannotate 0`; the box really
  does ship unticked.
* `tests/headless/test_op_annot.tcl:12139` — row **V25** exists and asserts both
  arms publish with the box off, goldens `{0 {2 3e-09 0}}` and `{1 {2 3e-09 0}}`;
  the explaining header sits at `:11311`.
* `src/token.c:4328` — `int live = !raw_is_digital(xctx->raw);` (×6 sites); the
  ISSUE 0864 paragraph records that the switch term was removed, so the box no
  longer gates rendering.
* `src/xschem.h:2262` and `:909`–`915` — `annot_show` is a text-HIDING mask,
  which is why publication with mask 0 paints nothing.
* `src/wave_viewer.tcl:14239`–`14250` — `wviewer::cursor_toggle` runs
  `xschem new_schematic switch $wp` before its `xschem set cursor${which}_x`, so
  the waveform window's own cursor buttons act inside the viewer's context.
* `utils/annot_mode.tcl` — `cadence::_annot_op_db_ok` / `cadence::annot_mode`
  return silently before writing the mask on a transient (the 0872 fix).

### Two corrections for the record — neither moves the ruling

1. **There is a FIFTH ungated publisher nobody has inventoried:**
   `xschem annotate_at <time>` (`src/scheduler.c:2362`). It is the `Alt-Shift-6`
   door, so it is ungated on purpose and for exactly the same reason — but this
   issue still says "four", and the next crew counting publishers will find five.
2. **The tick box controls three things, not one.** Besides following cursor B as
   it is dragged, with the box ticked *loading a waveform file* and *descending
   into a sub-circuit* also re-read the numbers with no press (`src/save.c:1302`,
   `src/actions.c:4867`). The honest plain-English sentence is: it "controls
   whether the numbers re-read themselves on their own — as you drag cursor B,
   when new results load, and when you walk into a sub-circuit."

There is also a **known follow-up defect, not an overturn**: the waveform
viewer's **Cursors > Cursor B** tick uses a bare `xschem new_schematic switch`
(`src/wave_viewer.tcl:14239`) and never checks that it worked, while the same
file at `:1563`–`:1575` documents that this switch silently does nothing while a
semaphore is up and offers `wviewer::switch_ctx` precisely so callers verify it.
During a run with a wait in progress, that tick can therefore land on the design
sheet. The remedy is one line inside that tick handler; gating the typed command
would not fix it, because the same refused switch also fires `xschem cursor 2 1`
at the design sheet, which zeroes the cursor position outright and is the larger
breakage.

### Does this imply a code change?

**No. This RATIFIES what already ships. Nothing moves.** No file is edited under
this ruling; row V25 stays, both guards stay, both `set cursor2_x` arms stay
ungated. The two corrections above are bookkeeping about *this issue's text*, and
the waveform-viewer tick and the `annotate_at` inventory line are follow-up work
**not done here**.

One residual remains true and belongs to issue **0877** (the provenance stamp),
not to this ruling: after `Alt-Shift-6` puts transient node voltages on the
sheet, dragging cursor B in the waveform window does not move them — press
`Alt-Shift-6` again to re-read at the new time, or tick the Live box to have them
follow.

### Adversary

An adversary was run against this decision and **could not overturn it**: "I
tried to break this and could not. The ruling stands." Its strongest attack — the
unverified context switch in the waveform viewer's cursor tick — is recorded
above as a separate follow-up defect, since gating the typed command would not
have repaired it.

---

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
