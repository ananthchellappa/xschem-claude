# 0636 — the gate-off OP-card nudge fires on EVERY `op` netlist, for everyone, with no opt-out

Status: **FIXED 2026-08-23** by the 0617+0618 crew — **RULING SETTLED 2026-08-29** (frequency ratified as shipped; the OFF-direction re-arm and the wording owe a code change) — see **RULING, 2026-08-29 — decided on the user's instruction** at the FOOT of this file, which supersedes the earlier
**THE RULING** at the bottom of this file. (The question that was owed is at the
bottom of this section.)

## BEFORE (Measure agent, verbatim)

```
[] ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in this
   deck. Tick Outputs > Save All > Save device OP parameters to annotate them (issue 0617).
have op_annot::save_cards in a bare session: 1
nudge #1 / nudge #2 / nudge #3  ->  TOTAL NUDGES IN ONE SESSION, SAME CELL: 3
```

## AFTER

`TOTAL NUDGES IN ONE SESSION, SAME CELL: 1`.

## Decision D6 (L3 — user-visible, ratification owed)

Implemented as this issue's own "cheapest defensible fix": `set_ne
ase_op_card_nudge 1` beside the `ase_eng_notation` precedent, a once-per-session latch
keyed on the design `lib/cell/view` via `ase::op_cards_nudge_ok`, and
`ase::op_cards_nudge_reset` as the test seam.

Two shapes matter and are pinned by tests:

* the latch is consulted **last and only** where the nudge is about to be echoed, so a
  state that fails the `op`-analysis gate does not silently consume its cellview's one
  turn (the two gates are **nested**, not `&&`-ed) — row **F19e**;
* it is keyed **per cellview**, not globally — a different cell still nudges.

`test_ase_final`'s F19 had to be reshaped: measured, `ase::netlist` fires three times
in one session on that cell (F6, F9's `ase::run`, and F19's own call) and F19 armed its
collector around the **third**. It now resets the latch first. F19b (a second netlist
nudges 0), F19c (`::ase_op_card_nudge 0` nudges 0), F19d (the default is 1) and F19e
are new siblings. Sabotage: forcing `op_cards_nudge_ok` to return 1 reds exactly F19b
and F19c, as predicted.

*Rejected:* every-netlist (shipped — no opt-out, advertising an opt-in feature the user
may have deliberately declined). *Rejected:* removing it (re-opens 0617 in silence).

### ⚠ THE QUESTION OWED TO A HUMAN

> Should the gate-off OP-card nudge fire **once per session per cellview** (what now
> ships), on **every netlist** (what shipped before — measured at three identical lines
> in one session about one cell, into a pane and a log people diff), or **not at all**
> unless asked?

---

## Original filing follows

Status: **OPEN — measured, not fixed. A ratification is arguably owed.**
Filed by the S4 write-up agent, 2026-08-23. Found by the S4 adversary (Verify-C),
re-measured independently before filing.
Related: **0617** (the nudge is 0617's emit-side channel), 0620 (deck cost), 0633.

## What S4 shipped

The `save_op_params` gate defaults **off** (deliberately — 468 cards on the
user's 31-FET bench, ~3000 on a 500-device block per 0620, and two committed
byte-exact deck goldens). A gate that defaults off has to be discoverable, so
`ase::op_cards_capture` echoes one line when the gate is off **and** an `op`
analysis is enabled:

```
ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in
this deck. Tick Outputs > Save All > Save device OP parameters to annotate them
(issue 0617).
```

That is pinned green by `test_ase_final` row **F19**, and it is the right idea:
it is exactly the configuration the user reported 0617 from.

## The defect

**The condition it is gated on is always true.** `$have` is
`[info commands ::op_annot::save_cards] ne {}`, and `src/xschem.tcl:14600`
sources `op_annot.tcl` **unconditionally** at startup — so `have` is 1 in every
session, including sessions with no PDK descriptor registered and designs with
nothing annotatable anywhere in them.

MEASURED (binary md5 `fce30432968d678ab24640729569317f`, `src/ase.tcl` md5
`b82f5ba3b26d5159a2fa0ab21c7b82cc`): a bare session, a synthetic two-line
netlist artifact, a state whose design is a non-existent cell — nothing in the
picture is annotatable and no descriptor is registered —

```
A) op_annot::save_cards present in a bare session: 1
B) gate-off nudge lines: 1
   ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in
   this deck. Tick Outputs > Save All > Save device OP parameters to annotate
   them (issue 0617).
```

So for every existing ASE user who runs an `op` analysis, **every netlist from
now on** adds one line to the ASE pane and one `#=` line to `Xschem.log`,
advertising an opt-in feature that may deliver nothing on their design — and
there is **no way to turn it off**. It is not an `error`-tagged line, but it is
still a new line in a log people diff and a pane people read.

## Why this is worth a ruling and not just a tidy

The trade is real in both directions and S4 chose one side without the user:

* **Nudging always** guarantees no user re-lives 0617 in silence — which is
  precisely the failure this feature exists to delete.
* **Not nudging** keeps every existing user's pane and log exactly as it was.

The middle grounds nobody has measured: nudge only when the design actually
contains a device with a registered descriptor (costs a walk, which is the
expensive thing the gate exists to avoid); nudge once per session; nudge once
per design; or give it a `::ase_op_card_nudge` off switch in `xschemrc`.

## The cheapest defensible fix

An `xschemrc` variable (`::ase_op_card_nudge`, default 1) plus a once-per-session
latch keyed on the design cell. Roughly six lines, and it owes a `test_ase_final`
row beside F19: *the nudge fires once, and not at all when the variable is 0*.

Not applied by the write-up agent because it changes user-visible behaviour that
Verify-A/B/C measured as shipped, and because which way to go is genuinely the
user's call.

---

## THE RULING (2026-08-29)

Decided by the assistant under the user's instruction of 2026-08-29, *"decide the
23, leave 0861 and 0299 for me"*. Not a bounce: the two alternatives are noise and
silence, and both are already answered by standing rulings.

**The ruling: the shipped frequency stands.** When an `op` analysis is enabled and
`Outputs > Save All… > Save device OP parameters (gm, gds, vth, ...)` is not ticked,
the ASE-L output pane and `Xschem.log` say so **once per design cellview per
session**, and get one more turn **only when the user actually moves that tickbox**
(a `save_op_params` change committed through the session, or an OP-parameters tick
the Save All dialog discarded). Every-netlist is rejected: measured at three
identical lines in one session about one cell, into a pane people read and a log
people diff. Never-at-all is rejected: it re-opens 0617 in silence, which is the
failure this feature exists to delete, and INTENT OVER MECHANISM forbids it.

`::ase_op_card_nudge` (default 1) stays as an escape hatch for a user who has
deliberately declined the feature. It is **not** to be advertised, documented in
the tutorial, or grown: under CADENCE OR NOTHING a knob Virtuoso has no equivalent
for earns nothing by being promoted, and at once-per-cellview-per-session it is a
footnote, not a feature.

**One consequence that does move code.** What the user actually reads today is

```
ASE: device operating-point parameters (gm, gds, vth, ...) were NOT saved in this
deck (issue 0617).
```

(`src/ase.tcl:794`). Ratifying how often a line appears cannot ratify a tracker
number printed to a user: the PLAIN ENGLISH ruling covers every user-facing
sentence. **Drop `(issue 0617)` from the emitted string** and keep it in the
comment above the call. Nothing else in that sentence is ratified here — a fuller
9th-grade rewrite of it (`deck` is jargon; compare the annotate-side mints in
`utils/annot_mode.tcl:558`) is a wording question of the same family as 0618 and
0664 and is left on the user's queue. No test matches the literal `(issue 0617)`
in the emitted line (`test_ase_final` F19 asserts the `Outputs > Save All` menu
path, not the tag), so the edit is one string.

### What was verified in the tree before ratifying

* `src/ase.tcl:227` — `set_ne ase_op_card_nudge 1`, default on, rc may preset.
* `src/ase.tcl:704` `ase::op_cards_nudge_ok` — off switch first, then the latch
  take; deliberately not `notify -once`, which would bypass the off switch.
* `src/ase.tcl:750` `ase::op_cards_capture` — gates **nested**, not `&&`-ed: an
  `op`-disabled state never consumes its cellview's one turn.
* `src/ciw.tcl:188–212` — the storage is the generalised `xschem::notify_latch_*`
  keyed on `{subject state}` with subject `opcards` (R-0653-c), so one cellview
  cannot eat another's turn.
* `src/ase.tcl:2799–2810` — the re-arm fires only on an actual `save_op_params`
  change (`ase::op_cards_gate_changed`), never on every pane mutation.
* `src/ase_window.tcl:3917–3920` — a discarded Save All re-arms only for the
  OP-parameters box, not for a discarded all-voltages/all-currents tick.
* `tests/headless/test_ase_final.tcl` F19 / F19b / F19c / F19d / F19e / F19g /
  F19h / F19n — once, then silence; off switch; default 1; `op` disabled stays
  silent; re-arm on change only; per-cellview keying.
* `utils/annot_mode.tcl:558` — the safety net that makes once-per-session safe:
  pressing `6` on a sheet with no device numbers explains the blanks in plain
  English and names the remedy, independently of this netlist-time hint.


---

## RULING, 2026-08-29 — decided on the user's instruction

This supersedes "THE RULING (2026-08-29)" above, which was written before the
adversary pass. That section is left in place unedited as the record of what was
first decided; where the two disagree, **this section governs**.

The user, 2026-08-29, verbatim:

> "decide the 23, leave 0861 and 0299 for me"

A read-only audit of the 57-entry ruling queue classified 25 debts as questions
whose answer is cheap and obvious — things to be decided rather than put to the
user. **0636 was one of the 23** the user then handed over (0861 and 0299 were
kept back for themselves). So this is a decision taken on the user's explicit
instruction, not an assistant overstepping.

### The ruling

**(a) The frequency stands, exactly as it ships.** When an `op` analysis is
enabled and `Outputs > Save All… > Save device OP parameters (gm, gds, vth, ...)`
is not ticked, the ASE-L output pane and `Xschem.log` say so **once per schematic
per session**. Every-netlist stays rejected. Never-at-all stays rejected.

**(b) The re-arm becomes one-directional — this part moves code.** The hint gets
its turn back **only when the user tried to switch the tickbox ON and it did not
take**. Turning the tickbox **OFF must not re-arm anything**: the re-arm reached
through `ase::session_update` must fire on a `{} -> 1` edge only, never on
`1 -> {}`. The Save All dialog's discarded-tick path is unaffected — it already
re-arms only for a discarded **OP-parameters** tick, which is an attempted ON.
Nothing else about the latch changes.

**(c) The sentence loses its tracker number and its jargon.** The emitted string
at `src/ase.tcl:794-795` must read, in the same English as the `6`-key message it
is the early-warning twin of:

```
ASE: this simulation will not save the device operating-point numbers like gm,
gds and vth, so those values will be blank on the schematic.
```

`(issue 0617)` moves into the comment above the call. "deck" comes out. The menu
path and the pasteable command ride as separate fields (`-menu` / `-command`) and
are unchanged. Any **further** rewrite of this sentence belongs with the
`cadence::_annot_cause_msg` mints under the **0909** wording debt, where the twin
sentence already lives — not with 0618 (the simulation log's provenance header)
or 0664 (notice-channel fault wording), which are about other sentences.

**(d) `::ase_op_card_nudge` (default 1) stays, unadvertised.** Not documented in
the tutorial, not grown. With (b) applied it is close to vestigial, which is the
right size for it.

### Why

* **The frequency.** The three candidates are noise, silence, or what ships.
  Every-netlist was *measured* at three identical lines in one session about one
  cell, into a pane people read and a log people diff, advertising an opt-in
  feature the user may have declined — that is the defect 0636 was filed as, not
  a trade-off. Never-at-all is refused on the honest ground: not because silence
  would return (pressing `6` already explains the blanks and offers the remedy,
  `utils/annot_mode.tcl:558`), but because the netlist-time line arrives **before**
  the simulation and can save the user a run they would otherwise have to repeat.
  A heads-up before a long run has value that a message after it does not.
* **The one-directional re-arm.** As shipped, a user who unticks the box on
  purpose — the thing the code's own comment says people do, because it costs 468
  extra save lines on a 31-FET bench and about 3000 on a 500-device block (0620) —
  gets told on the very next netlist to tick it back on, with a one-click command
  whose whole job is to switch it on. That is **MUST ONLY HAPPEN WHEN USER
  REQUESTS IT** violated, and it is verbatim what this issue was filed about:
  "advertising an opt-in feature the user may have deliberately declined."
  Cadence agrees: ADE does not chase you to re-enable a save option you disabled
  (**CADENCE OR NOTHING**). The off-direction re-arm was never part of the owed
  three-way frequency question — it arrived later, in 0648, and rode in under the
  ratification.
* **The sentence.** **PLAIN ENGLISH** covers every user-facing sentence. A tracker
  number printed to a user fails it outright, and so does "deck" sitting four
  words from the end of a sentence that is otherwise plain — beside a mint that
  says "results file" at ninth-grade level. If PLAIN ENGLISH is authority enough
  to strip the tracker number without asking, it is authority enough to finish the
  sentence.
* **The off switch.** It is not a stock-XSCHEM-preservation knob, so CADENCE OR
  NOTHING does not bite it; it is a silence hatch that costs nothing at default-on.
  Keep it, do not promote it.

### What was verified in the tree (so a later reader need not re-derive it)

* `src/ase.tcl:227` — `set_ne ase_op_card_nudge 1`; default on, an rc may preset
  it, beside the `ase_eng_notation` precedent.
* `src/ase.tcl:704` `ase::op_cards_nudge_ok` — reads the `::ase_op_card_nudge` off
  switch **first**, then takes the latch; the comment states it is deliberately
  not `notify -once`, because `-once` would bypass the off switch.
* `src/ase.tcl:750` `ase::op_cards_capture` — the two gates are **nested**, not
  `&&`-ed, so an `op`-disabled state never consumes its schematic's one turn.
* `src/ase.tcl:794-795` — the emitted string still ends
  `... were NOT saved in this deck (issue 0617).`
* `src/ase.tcl:688` `ase::op_cards_gate_changed` — **symmetric today**:
  `expr {[ase::op_gate_on $old] != [ase::op_gate_on $new]}`. This is the line (b)
  narrows.
* `src/ase.tcl:2799-2810` `ase::session_update` — re-arms only when
  `ase::op_cards_gate_changed` reports an edge, not on every pane mutation.
* `src/ase_window.tcl:3917-3920` — a Save All dismissed with a discarded tick
  re-arms only for the `opparams` box, not for `allv` / `alli`.
* `src/ciw.tcl:188-212` — storage is the generalised
  `xschem::notify_latch_ok/_rearm/_reset` keyed on `{subject state}`, subject
  `opcards`; per-schematic, so one cell cannot eat another's turn.
* `tests/headless/test_ase_final.tcl` — F19d:358 (default 1), F19:365 (once),
  F19b:370 (second netlist = 0), F19c:383 (off switch silences even after a
  reset), F19e:400 (`op` disabled = 0), F19n:488 (per-schematic), F19g:507
  (re-arm on an ON change), F19h:520 (no re-arm without a change), **F19i:524-531**
  (asserts the OFF edge re-arms — the assertion (b) overturns), **F19j:533-545**
  (`op_cards_gate_changed 1 {}` -> 1 in its last cell).
* `grep -rn 'issue 0617' tests/headless/*.tcl` — no test matches that literal in
  the emitted line, so the (c) string edit breaks nothing.
* `utils/annot_mode.tcl:558` `cadence::_annot_cause_msg` — pressing `6` with no
  device numbers explains the blanks in plain English and names the remedy,
  independently of this hint. This is the safety net that makes once-per-session
  safe, and it did not exist when 0636 was filed on 2026-08-23.

### Does this move code?

**Part (a) ratifies shipped behaviour — nothing moves.** Parts (b) and (c)
**imply a code change, NOT YET DONE**, recorded here as follow-up work:

1. **`src/ase.tcl:688` `ase::op_cards_gate_changed` becomes one-directional** —
   report a change only for OFF -> ON. (The alternative, narrowing the caller at
   `src/ase.tcl:2799-2810` instead, is ruled out by the test consequence below:
   F19j exercises the detector directly and its last cell must flip.)
2. **`tests/headless/test_ase_final.tcl` F19i (lines 524-531) flips to expect 0**
   and **must be re-titled**, because its current header comment — "Turning the
   gate back OFF is just as much 'the user acted on this setting'" — *is* the
   reasoning being overturned. The new title should say why: unticking the box is
   the user declining the feature, and declining it must not re-trigger the
   advertisement for it.
3. **F19j's last cell** (`op_cards_gate_changed 1 {}`) flips from `1` to `0`:
   expected `{0 1 0 0 0 1}` becomes `{0 1 0 0 0 0}`. The truthy-not-1 cells are
   0637's subject and stay as they are.
4. **`src/ase.tcl:794-795`** — replace the emitted text with the (c) sentence;
   move `(issue 0617)` into the comment above the `::xschem::notify` call. Keep
   `-short {no OP params saved}`, `-menu $opmenu`, `-command $opcmd`.
5. Untouched: F19, F19b, F19c, F19d, F19e, F19g, F19h, F19n; the
   `src/ase_window.tcl:3917-3920` discarded-tick re-arm; `::ase_op_card_nudge`.

### The adversary

An adversary pass ran against the first ruling and **overturned it in part**: it
ratified the frequency, showed that the OFF-direction re-arm nags a user about a
switch they just deliberately turned off (F19i pins that behaviour green on
purpose), and showed that leaving the rest of the sentence "on the user's queue,
family of 0618/0664" put it on no queue at all. Its better answer is what is
ruled above.

**The user may reverse this at any time; it was decided to spare their attention,
not to bind them.**
