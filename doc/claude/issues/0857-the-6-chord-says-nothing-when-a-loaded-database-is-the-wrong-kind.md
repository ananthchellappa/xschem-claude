# 0857 - the `6` chord says nothing when the loaded database is the WRONG KIND, and its advisory is on the status bar, not the CIW

**Status:** OPEN, source-confirmed, not fixed. Filed 2026-08-26 from a user
report on `tb_bandgap`. Sibling of
[0856](0856-annotate-op-shows-a-transient-s-t-0-as-the-operating-point-silently.md),
which is the same day's other half: 0856 is the wrong NUMBER, this is the
missing EXPLANATION.

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
