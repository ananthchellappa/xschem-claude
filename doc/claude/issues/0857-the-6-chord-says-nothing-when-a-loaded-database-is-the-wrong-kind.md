# 0857 - the `6` chord says nothing when the loaded database is the WRONG KIND, and its advisory is on the status bar, not the CIW

**Status:** **PARTLY FIXED** 2026-08-27 by item A10 — the WRONG-KIND half, which
is the half the user ruled on. **The originally reported case is still open**: see
"What landed" at the foot of this file for exactly which half is which. Filed
2026-08-26 from a user report on `tb_bandgap`. Sibling of
[0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md),
which is the same day's other half: 0856 is the wrong NUMBER, this is the
missing EXPLANATION.

## ⚠ HALF 2's CHANNEL ALREADY EXISTS — DO NOT BUILD A SECOND ONE (added 2026-08-27)

Issue [0868](0868-on-request-transient-node-voltage-annotation-at-the-waveform-cursor.md)
landed **`cadence::_annot_ciw {msg {tag {}}}`** in `utils/annot_mode.tcl`: the ONE
emitter for the annotation chords' user-facing sentences. It tries `::ase::echo`,
then `::xschem::notify`, then `stderr`, and it is deliberately **not** a bare
`catch {::ase::echo ...}` — a catch-and-discard would go silent exactly where this
issue says silence is the defect.

0868's own mode uses it beside a `xschem statusmsg -hold` of the same string, i.e.
it answers half 2 with **both** sinks for its own five sentences. The work still
owed here is to route the `6` / `Alt-6` chords' existing `_annot_msg` line through
the same emitter, and to add the missing wrong-kind wording — **through
`cadence::_annot_msg`, which is already the one mint** (RULING D5-4). Two channels
for "the annotation chord could not deliver" is the drift invariant I1 forbids.

The BOTH-sinks choice is itself unratified and is recorded as decision 4 of 0868's
rule debt; it is the same unruled question as this issue's half 2 and as 0636. One
ruling settles all three.

## What the user did, and what they expected

Opened `tb_bandgap`, descended `x1 > x1`, pressed **`6`**. Every device row came
up blank (`id = `, `gm = `, …) — which is correct — **and nothing said why, or
what to do about it.**

## Two distinct gaps

### 1. There is no wording for "a database is loaded, but it is the wrong KIND"

`utils/annot_mode.tcl` already treats requirement 4 — *"SAY WHAT HAPPENED, HELD,
on the status line"* — as the deliverable, not a courtesy, and its own header
names the two first-run confusions it set out to kill: *"there is no raw file"*
and *"nothing on this sheet has an OP descriptor"*. `cadence::_annot_msg` has
eight states:

    off | live | notlive | noop | loaded | failed | noraw | nopath | stale

Walk the user's case through `cadence::annot_mode op`: a raw IS loaded and IS
annotated, so `::op_annot::_annotated` answers 1 and the state is **`live`**.
The line reads:

    OP annotation ON (device OP info) -- raw already loaded

Every word of that is true and none of it is the news. The news is *"the loaded
database is a transient; device OP parameters live in the operating-point
database"*. There is no state for it, because the state machine asks **"is
something loaded and published?"** and never **"is what is loaded the kind this
chord needs?"**.

The descriptor clause cannot cover it either: it is appended only when
`_annot_scan` finds **zero** annotatable devices on the sheet
(`if {[lindex $scan 0] == 0}`). On `tb_bandgap`'s `x1 > x1` the devices are
annotatable — `op_annot::devpath` resolves fine — they simply have no vectors in
this database. So the one clause that might have hinted at it is suppressed by
the very fact that the sheet is healthy.

**The diagnostic already exists and is one call:** `xschem raw sim_type`. Nothing
on this path asks it.

### 2. The advisory lands on the status bar, and the user was watching the CIW

`cadence::annot_mode` ends with `xschem statusmsg -hold`. `-hold` is deliberate
and well-reasoned (a plain `statusmsg` is erased by one `<Motion>` event —
issue 0248), but the status bar is a single line at the bottom edge that a user
mid-descend is not looking at. The CIW is where this session's other
announcements go — `backannot_refuse_digital()` and `backannot_refuse_empty()`
(`src/save.c`) both route through `ciw_echo`, and the notice-channel work of
0664/0675 built exactly that habit.

So even when the chord DOES have something to say — `noraw`, `nopath`, `failed`,
`stale`, `notlive`, `noop` are all real and reachable — it says it somewhere the
user is not looking.

## Why the two halves are one issue

Fixing only the wording leaves it on a line nobody reads; fixing only the
channel makes a truthful-but-useless sentence louder. Neither alone changes what
the user experiences.

## The fix shape, and what needs a ruling

**Half 1 (mechanical, no ruling needed).** Add a state — call it `wrongkind` —
between `live` and the rest: when the mask includes bit0 (device OP info) and
`xschem raw sim_type` is not `op`/`dc`, say so and name the remedy. It must be
worded off the sim type actually found, not off a guess. Note this must NOT fire
for bit1-only (`Alt-6` alone): node voltages from a transient are a different
question, and that one is 0856's.

**Half 2 (needs YOUR ruling).** Where does it go?

* **(a)** CIW **and** status bar — the refusal sentences' shape, one line each.
* **(b)** CIW only for the states that are news (`wrongkind`, `noraw`, `failed`,
  `stale`), status bar for the routine ones (`live`, `loaded`, `off`).
* **(c)** Status bar only, as today.

⚠ (a) has a real cost: `6` is a chord people press repeatedly, and every press
would write a CIW line. 0636 is an open ruling about exactly that failure mode
for the OP-card nudge — *"once per session per cellview, every netlist, or not at
all?"* — and this would be the second instance of the same question. Answer both
together, or answer this one in a way that does not prejudge that one.

## Acceptance if fixed

1. `6` with a transient database current names the sim type and the remedy, once,
   through the chosen channel.
2. **Positive twin.** `6` with a proper OP database current still says
   `OP annotation ON (device OP info) -- raw already loaded` and nothing more —
   the routine case must not become chatty.
3. `Alt-6` alone (mask 2) does NOT emit the device-OP wrong-kind line.
4. Every existing golden string in `tests/headless/test_op_annot.tcl` section N
   (rows N3/N5/N6/N8/N9/N10/N10b/N15/N23) is either unchanged or its change is
   deliberate and listed.
5. No CIW line is emitted when `has_x` is 0 — this is a chord, and headless
   suites press it.
6. Sabotage: force `sim_type` to `op` on a transient and confirm row 1 reds.


---

# What landed (item A10, 2026-08-27) — and what did NOT

## The user's ruling this answers, verbatim

> "Yes, 6 does nothing when there is ONLY a TRAN result. But, it's a good idea to
> say 'No OP results available' in the CIW."

That retires the collision between this issue and ruling 0856. 0856 said *"it
should do nothing silently"*; the user has now said the "do nothing" keeps
standing for the **screen** — nothing published, no bit armed, no number painted —
and stops standing for the **user**, who was left holding a key that looked broken.

## Measured before the change: the OP chords had no CIW route at all

All five `cadence::_annot_ciw` call sites in the shipped product were inside
`cadence::annot_tran`. `cadence::annot_mode` — the body behind `6`, `Alt-6` and
`Ctrl-6` — had one `xschem statusmsg -hold` at its very end, and **both** silent
refusals returned before reaching it. So this was not "route the existing line
through the emitter"; the wiring did not exist. It does now, at both refusals, and
they are the emitter's first call sites outside `annot_tran`.

## What speaks now

Both of `cadence::annot_mode`'s silent returns:

* the `$mask != 0 && ![_annot_op_db_ok]` refusal at the top — a database is
  attached and it is not an operating point;
* the issue 0872 unwind — nothing was attached, the chord went and found the run's
  `.raw`, it turned out to be a transient, and everything was put back. The
  analysis type is read **before** `xschem raw clear`, because afterwards the
  accessor raises and the sentence could only be the typeless shape.

Both render one new state of `cadence::_annot_msg` — `notop`, minted in two shapes
from ONE arm (RULING D5-4), the analysis type named when the database can say what
it is and left out when it cannot:

    No operating point results available -- the results loaded here are a 'tran'
    analysis, not an operating point. Run an operating point analysis, or press
    Alt-Shift-6 to annotate transient node voltages at the waveform cursor.

It carries **no** `OP annotation ON/OFF (...)` prefix, unlike every other sentence
this proc mints: on both paths the mask is never written or is written and put
straight back, so a prefix would make a claim about a screen that did not change.

Both sinks — the CIW **and** the held status line. The user's words were "say
something in the CIW", and that is where an ASE-L user looks; the three OP chords
have always spoken on the held status line, and a plain xschem user with no ASE-L
window open would never see a CIW-only sentence. **Unratified** — `owed.sh` rule
debt 0857 covers this and the wording.

`Ctrl-6` is still exempt and still says only `OP annotation OFF`, with nothing
added to the CIW: clearing can never put a number on a sheet, and a chord people
press repeatedly must not write a line every press. That is the 0636 chattiness
question left un-prejudged.

## What did NOT land: the case the user originally reported

The `tb_bandgap` report — a **proper OP database** loaded and annotated, every
device row blank because nothing on the sheet has an OP descriptor — goes down
`_annot_op_db_ok` = 1, takes no refusal, and reaches the routine `live` / `noop`
sentence on the status line with **nothing in the CIW**. Gap 2 of this issue
("the advisory is on the status bar, not the CIW") is untouched, and so is the
`live`-state wording. That work is still owed.

## Acceptance list, re-scored

1. **Met** for the transient case — `6` names the analysis it actually has and the
   remedy. Rows **V40** (a transient already attached) and **V41** (the post-run
   desktop where the chord finds the file itself).
2. **Met.** Row **V31d**: an operating point at the same candidate path still
   loads, still arms, still paints and still says
   `OP annotation ON (node voltages) -- loaded <file>` and nothing more.
3. **Met.** `Alt-6` renders the same one `notop` sentence, not a device-OP-specific
   line — there is one arm, not two.
4. **Met.** Every section-N golden is byte-unchanged; the new state returns before
   the mask switch those rows exercise.
5. **SUPERSEDED, deliberately.** This item said "no CIW line when `has_x` is 0".
   `cadence::_annot_ciw` is built the opposite way on purpose — its last sink
   always works, because a catch-and-discard would go silent exactly where this
   issue says silence is the defect (row V30 pins that). Headless rows therefore
   see the line, which is what makes rows V40/V41 possible at all. Issue **0873**
   records that muting this channel once left every check in the file green; the
   experiment was re-run after this change and now reds **V28, V29, V30, V40 and
   V41**.
6. **Met.** Muting either refusal's emit pair reds V40 or V41 respectively;
   dropping the `$mask != 0` term reds V31 leg 2 and V40 leg 3.


---

# Repair note (item A10, second pass, 2026-08-27)

A sabotage pass found that the ruling's own words — *"it's a good idea to say
'No OP results available' in the CIW"* — were only half delivered at the newest
refusal. Item A10 added a FOURTH way for the transient annotation to decline
(the results file is older than the circuit it describes), and it does speak in
the CIW — but **deleting that CIW call left every check in the tree green**.
Only its held status line was pinned. Row **V29** enumerates the three refusals
that existed before that item and was never extended.

Closed by row **V49** of `tests/headless/test_op_annot.tcl`, which is V29 applied
to the fourth state: the sentence must reach the CIW tagged `warn` AND the held
status line. Muting the CIW call alone now reds it.

A FIFTH refusal arrived with the same repair — the results file on disk is a
different simulation run from the one the waveform viewer is showing — and its
CIW half is pinned by row **V51**, which asserts the spy output and the status
line together for exactly this reason.

Both new sentences are plain English per the user's 2026-08-27 ruling: they say
what happened and what the user can do about it, and name the file.
