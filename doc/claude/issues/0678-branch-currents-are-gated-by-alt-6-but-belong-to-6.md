# 0678 — a voltage source's current is device OP info, so it belongs to `6`, not `Alt-6`

Status: **FIXED 2026-08-24, commit `94c507fc`** — shipped and independently
re-verified (test_op_annot 342 ALL PASS, test_annot_show_menu 26 ALL PASS,
test_launch_context ALL PASS, on :99 with openbox 3.6.1 live). **A RULING
REVERSAL, not a coding slip** — the code did exactly what decision D4 said.
Reported by the user 2026-08-24 from the 0614/0615 eyes-on look.
Residual filed as **0681** (three shipped floaters moved chord with no test row,
under a committed test comment that says none moved). The View-menu label question
this issue raised is **MOOT** under **0682**, which moves the control out of the
View menu entirely; its rule debt stands until the user clears it.
Related: 0613 (where the wrong grouping entered), 0614, 0615, 0621, 0681, 0682.

## The user's report, verbatim

> Yes, ALT-6 is going it's job for node voltages - but, it's also displaying OP info
> of voltage sources - namely their current. That should be controled by 6 key, not
> Alt-6.
>
> Otherwise, Alt-6 and 6 and Ctrl-6 behave as expected.

So the two additive setters and the clear-all are confirmed correct on a real bench.
Only the *membership* of one content class is wrong.

## Measured — it is deliberate, and the comment says so

`src/actions.c:1290-1291` classifies by content and sets two distinct flags:

```c
if(cls == ANNOT_CONTENT_VOLTAGE)      t->flags |= TEXT_ANNOT_VOLTAGE;
else if(cls == ANNOT_CONTENT_CURRENT) t->flags |= TEXT_ANNOT_CURRENT;
```

but `src/actions.c:1397` then gates BOTH with the same switch:

```c
if(flags & (TEXT_ANNOT_VOLTAGE | TEXT_ANNOT_CURRENT)) {   /* -> ANNOT_SHOW_VOLTAGE */
```

`src/actions.c:1359` records the intent — *"BRANCH CURRENTS ARE NOT HERE (decision
D4): TEXT_ANNOT_CURRENT joins the voltage SWITCH"* — and `src/xschem.h:416` traces it
to issue **0613**, *"0613 lists branch currents among what [the voltage chord]
controls"*.

**The flag split already exists.** `TEXT_ANNOT_CURRENT` (bit 9, `xschem.h:423`) is a
separate bit that was deliberately routed to the wrong switch. Nothing needs
inventing; one gate needs re-pointing.

## Why the user is right

`@spice_get_current` is read **per instance** — it is *that device's* terminal
current. A voltage source's current is a property of the device, exactly like a FET's
`id`. A node voltage is a property of the *net*. The chords split on that line:

* `6` — **device** operating-point information
* `Alt-6` — **net** quantities

Under that reading `TEXT_ANNOT_CURRENT` is on the wrong side of the line, and 0613
grouped it by *where the number comes from in the raw* rather than by *what the
number is about*.

## Fix

Re-point `TEXT_ANNOT_CURRENT` from `ANNOT_SHOW_VOLTAGE` to `ANNOT_SHOW_OP` at
`src/actions.c:1397`, and update the three sites that document the old grouping
(`actions.c:1359`, `xschem.h:416`, `xschem.h:886`).

⚠ **Do not fold the two flags together.** They are separate bits precisely so this
grouping is one line to change; collapsing them would make the next reversal a
rewrite.

⚠ **The data sources differ and must not be confused.** Branch currents come from
`.option savecurrents` (terminal currents), device OP parameters from explicit save
cards (measured rule R1). Moving the VISIBILITY switch does not move the data source,
and a sheet can legitimately have one without the other — so `6` must still render a
blank row rather than hiding the label when only one source is present (invariant I3).

## Acceptance

1. `6` on a sheet with `savecurrents` shows voltage-source currents; `Alt-6` does not.
2. `Alt-6` still shows node voltages, and still does not disturb OP blocks.
3. `Ctrl-6` still clears both.
4. `6` alone, with no `savecurrents` in the deck, renders the current row BLANK, not
   absent (I3).

   ⚠ **MEASURED DURING IMPLEMENTATION, 2026-08-24, AND THIS SENTENCE IS WRONG.** It
   renders **neither** blank nor absent: the `<text>` element is present and its
   content is the literal placeholder `-`. **THIS IS ALREADY FILED — it is issue
   [0625](0625-a-missing-vector-renders-a-hyphen-not-blank-which-contradicts-invariant-i3.md),**
   opened by the 0614/0615 adversary and left open deliberately by the 0617+0618
   crew; the implementing agent did not know that and reserved a fresh number for
   it. **No new issue was filed. 0625 is the record**, and this crew adds one fact
   to it: after 0678 those hyphens appear on the **`6`** chord instead of `Alt-6`.
   That is not `op_annot`'s doing and not
   this issue's to change — it is the C token path's long-standing convention
   (`valstr = "-"` at `token.c:4366/4478/4866/4968/5072/5140/5279`), the same string
   a `@spice_get_current` has printed for a missing vector since long before
   `annot_show` existed. **The part of I3 that matters holds exactly**: after
   re-annotating from a raw that carries `v(d)` and no `i(v1)`, the previous run's
   `-321u` is gone — no stale number survives. Row **U34** of
   `tests/headless/test_op_annot.tcl` pins the placeholder as a golden so a later
   change that turns it into a blank, a `0` or a `NaN` reds a named row.
5. The 0614 ruling table re-verified end to end — this must not silently re-open it.

## As implemented (2026-08-24)

The gate did not become two parallel `if`s. The grouping was lifted into **one named
place**, `annot_class_mask(int flags, int ctx)` in `src/actions.c`, shaped exactly
like its colour twin `annot_text_layer(flags, ctx)` beside it so the two answers
cannot drift (invariant **I1**), with invariant **I7**'s `ctx` term *inside* it:

```c
static int annot_class_mask(int flags, int ctx)
{
  if(ctx != TEXT_CTX_INSTANCE && !(flags & TEXT_FLOATER)) return 0;
  if(flags & TEXT_ANNOT_VOLTAGE) return ANNOT_SHOW_VOLTAGE;   /* bit1, Alt-6 */
  if(flags & TEXT_ANNOT_CURRENT) return ANNOT_SHOW_OP;        /* bit0, `6`   */
  return 0;
}
/* text_hidden(): */
int m = annot_class_mask(flags, ctx);
if(m) return (xctx->annot_show & m) ? 0 : 1;
```

Two parallel branches would have meant writing `ctx == TEXT_CTX_INSTANCE || (flags &
TEXT_FLOATER)` **twice**, and a dropped copy silently blanks a literal string a user
typed — measured before the change: a schematic-own NON-floater
`T {@spice_get_current} … {layer=17}` renders the literal token at all four masks,
and nothing in the tree guarded that (row U27 covered the voltage spelling only).
Row **U33** closes it; row **U35** is this issue's ⚠ *"do not fold the two flags
together"* made executable — `annot_class_mask(` appears exactly twice in
`actions.c` and the folded flag test appears zero times.

**The View > Show pair was relabelled with it** (`src/xschem.tcl`): bit0 is now
*"Show device OP / branch current annotation"* and bit1 *"Show node voltage
annotation"*. Leaving the old pair would make the one discoverable surface a lie in
the same commit that fixed the behaviour. ⚠ **The exact wording is an unratified
user-visible decision** and is on the owed ledger as a `rule` debt pointing here.
Rows A4 / A5 / A19 of `tests/headless/test_annot_show_menu.tcl` pin both strings.

`cadence::_annot_msg`'s four status strings are deliberately **byte-identical** —
mask 2's *"node voltages"* became exact rather than terse, and adding *"+ branch
currents"* to mask 1 would churn nine committed goldens for no user gain (0614's own
decision D9, which survives the reversal).

---

## STILL OPEN after this change (write-up agent, 2026-08-24)

Nothing below refutes the fix; the adversary leg returned **refuted: false** after
attacking it with an independent fixture, a second back end (PostScript), a
`show_hidden_texts` override, a hierarchy descend/ascend, and a raw switch.

1. **THE PIXELS HAVE NOT BEEN SEEN.** `draw.c` has no headless oracle — every
   measurement here came through `svgdraw.c` and `psprint.c`, which share
   `text_hidden()` with `draw.c` but not its GC/colour/clipping path. On the owed
   ledger as `look` debt `[0678_branch_currents_moved_from_Alt-6_to_6]`.
   **Suites green, please look.**
2. **THE VIEW LABEL WORDING IS UNRATIFIED** — `rule` debt `[0678]`, pointing here.
   The question is in *"As implemented"* above.
3. **THREE SHIPPED SHEETS MOVED AND NO ROW GUARDS THEIR SHAPE** — issue **0681**.
   `solar_panel.sch:269,270` and `pv_ngspice.sch:68` carry schematic-own
   **FLOATER** `@spice_get_current` records; they resolve and follow bit0 now
   (measured, correct), but U33 guards the **non**-floater spelling, which ships
   nowhere. 0681 also records that U33's original comment claimed the opposite;
   that comment was corrected with this write-up.
4. **A DOCUMENTED EXCEPTION MAKES THE HEADLINE NOT UNIVERSAL.** A text whose
   author typed `hide=voltage` on `@spice_get_current` content still follows
   **bit1** — deliberate (an explicit class beats an implicit one, which is why
   the two classes need two bits), but it means *"branch currents belong to `6`"*
   has an authorable exception that neither View label nor status line hints at.
5. **`U35` IS BRITTLE TO ITS OWN DOCUMENTATION.** Its golden is
   `annot_class_mask(` **== 2** in `actions.c`. Any future *comment* that writes
   the helper's name with a paren reds the row for a purely editorial edit — the
   surrounding comments already write `annot_text_layer(flags, ctx)` twice.
6. **U35's CALL-COUNT ELEMENT CANNOT SEE A SHADOWING REIMPLEMENTATION** (Verify-B's
   one missing predicted red). Renaming the real helper and putting a same-named
   stub in front of it leaves the literal-regex count at 2; only the *folded
   expression* element moved under SB1, and U35 stayed fully green under SB3 and
   SB5. The behavioural rows caught all three, so the suite has no hole — but
   U35 alone is narrower than its header claims.
7. **NODE VOLTAGES ONE LEVEL DOWN RENDERED `-` IN THE ADVERSARY'S HIERARCHY
   FIXTURE** while the branch current resolved correctly (six spellings tried).
   **Not attributable to this change** — nothing here touches `spice_get_node` —
   and possibly an artifact of a minimal hand-built subcircuit. Not filed for
   that reason. Worth one measurement on the real bench before the look debt is
   cleared, because the consequence would be that `Alt-6` *inside* a subcircuit
   now shows only placeholders where it at least used to show a real current.
8. **`get_fqdevice()` HARDCODES PDK ELEMENT LETTERS** (`token.c:4547/4560`, again
   at `:5052/5230/5243`) — IHP's psp103-via-OSDI (`n`) and HBT (`q`) are the named
   counterexample class. Pre-existing and untouched; 0678's only effect is that
   the resulting `-` placeholders now appear on `6` instead of `Alt-6`.
