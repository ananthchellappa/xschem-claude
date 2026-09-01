# 0864 — pressing `6` silently re-ticks the "Live annotate" box the user turned off

STATUS: **FIXED 2026-08-27.** The switch means only "follow cursor B" again, and
it ships off. Number claimed by the MEASURE agent for backlog item A1+A2.

USER'S WORDS: *"MUST ONLY HAPPEN WHEN USER REQUESTS IT!!"*

## What the user sees

**Simulation > Graphs > "Live annotate probes with 'b' cursor"** is a checkbutton.
It is ticked when xschem starts. Untick it, then press `6` (or use
**Simulation > Graphs > Annotate Operating Point**, or **Waves > Op Annotate**, or
ASE-L's **Results > Annotate**) and the box comes back ticked. There is no way to
keep it off across an annotation.

Two separate defects are entangled here:

* **A1 — the box does more than its label says.** It is also the *first* gate on
  what the operating-point annotation RENDERS. Unticking it blanks the device
  operating-point block that `6` draws, and blanks every node voltage and branch
  current that `Alt-6` draws — while the numbers sit untouched in the loaded
  database.
* **A2 — because of A1, the annotate path force-ticks the box** so that `6` still
  shows something. That force-set is the mechanism the user is complaining about.

## BEFORE state — measured 2026-08-27 on a clean tree at `e31975e7`

Headless, no build, binary as built: `./src/xschem --nogui --pipe -q --nolog
--script /tmp/a1a2_measure/probe.tcl`. Fixture: one device carrying an `op_annot`
descriptor plus the shipped `devices/annotate_params` carrier and a
`devices/lab_pin.sym` labelled `a`; a 1-point Operating Point raw carrying
`id`/`gm`/`gds` and `v(a)` = 3.14. Literal output:

```
== B0 STARTUP DEFAULT ==
B0 live_cursor2_backannotate at startup = 1

== B1 THE FORCE-SET: pressing Op Annotate re-ticks the box the user unticked ==
B1a user unticks the box -> live_cursor2_backannotate = 0
B1b xschem annotate_op result = {::op_annot::text}
B1c AFTER annotate_op       -> live_cursor2_backannotate = 1
B1d raw loaded = 0   raw annot = 0 0 -1

== B2 A1 COUPLING: the box also blanks the device operating-point block ==
B2a box TICKED   op_annot::_annotated = 1
B2b box UNTICKED op_annot::_annotated = 0
B2c box TICKED   op_annot::text MZZ1  = id  = 10u|gm  = 100u|gds = 1u|
B2d box UNTICKED op_annot::text MZZ1  = id  =|gm  =|gds =|
B2e box TICKED   translate l1 @spice_get_voltage = '3.14'
B2f box UNTICKED translate l1 @spice_get_voltage = ''
B2g the numbers are in the database either way: raw value v(a) -1 = 3.1399999
B2h                                              raw value @m.xmzz1.mzz[gm] -1 = 9.9999997e-05

== B3 THE `6` CHORD RE-TICKS THE BOX (the user's complaint, end to end) ==
B3a before pressing 6: live_cursor2_backannotate = 0  raw loaded = -1
B3b statusmsg = 'OP annotation ON (device OP info) -- loaded /tmp/a1a2_measure/nd/dev.raw'
B3c AFTER pressing 6: live_cursor2_backannotate = 1

== B4 THE STATUS SENTENCE THAT NAMES THE VARIABLE ==
B4a raw loaded, box unticked, press 6 -> statusmsg = 'OP annotation ON (device OP info) -- a raw is loaded but backannotation is off (live_cursor2_backannotate 0)'
B4b raw loaded, box ticked,   press 6 -> statusmsg = 'OP annotation ON (device OP info) -- raw already loaded'
```

The menu entry itself, measured on the persistent dev display `:99`
(openbox live), `tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog
--script /tmp/a1a2_measure/menu_probe.tcl`:

```
M1 menu entry index = 6
M2 label    = 'Live annotate probes with 'b' cursor'
M3 -variable = 'live_cursor2_backannotate'
M4 -command  = ''
M5 -onvalue/-offvalue = 1 / 0
M6 the box is TICKED at startup? live_cursor2_backannotate = 1
```

## SCOPE CORRECTION — A1 IS IN TWO LANGUAGES, NOT ONE

The brief names only `op_annot::_annotated` (`src/op_annot.tcl:782`). B2e/B2f
above measure the second half: the `Alt-6` node-voltage road never enters
`op_annot.tcl`. `xschem_library/devices/lab_pin.sym:32` carries
`T {@spice_get_voltage} ... {layer=15}`, expanded by `translate()` out of
`xctx->raw->cursor_b_val[]` (the ruling comment is `src/actions.c:1167-1175`), and
the six expansion sites in `src/token.c` (`:4328 :4834 :4925 :5012 :5107 :5180`)
each open with

```c
int live = tclgetboolvar("live_cursor2_backannotate") && !raw_is_digital(xctx->raw);
```

and render nothing when `live` is false. **A1 done in Tcl only, followed by A2,
ships a `6` block that renders and an `Alt-6` overlay that is blank for
everybody.** Both halves land together or neither does.

⚠ When those six lines are edited the `!raw_is_digital(xctx->raw)` half MUST
survive — it is RULING D5-1/D5-3 enforcement, and
`tests/headless/test_backannotate_digital.tcl:750` (row BA87) is its structural
witness. BA87 needs rewriting to the new line shape, never deleting.

## Baselines at the time of measurement (clean tree, `e31975e7`)

```
test_op_annot             RESULT: ALL PASS (364 checks)   OVERALL: ok   exit 0
test_backannotate_digital RESULT: ALL PASS (83 checks)    OVERALL: ok   exit 0
test_annot_show_menu      RESULT: ALL PASS (22 checks)                  exit 0   (:99)
```

The eleven reds the run's tier list names are already gone; A0 landed at `e31975e7`.

## Rows that assert the OLD behaviour and must be REWRITTEN, not reverted

All five pass today:

```
ok:   S16 live_cursor2_backannotate 0 blanks the WHOLE block, not just pinexpr
ok:   N10 a raw loaded with backannotation OFF is named as such, and is NOT cleared
ok:   N10b a raw that published no OP point names THAT, not the backannotate flag
ok:   O29 `live_cursor2_backannotate` 1 -> 0 -> 1 blanks every row and restores it, with no other change
ok:   X10 FIXTURE n_dev.sch: an annotatable device, the SHIPPED carrier and its hide=true twin, raw live
ok:   BA87 SOURCE WITNESS: every one of token.c's live-backannotation gates carries the D5 term -- all six branches, not just the one the fixture can reach
```

X10 survives the change and becomes the positive control.

## History — the feature is being KEPT and made opt-in, not removed

Upstream `96f80d1d` (2022-09-18) added it: *"Alt-a in graph annotates schematic
with values at cursor b position. Simulation->Live annotate option to
automatically update schematic probes if cursor moved"*. That commit shipped
`set_ne live_cursor2_backannotate 0` — **the default upstream chose was OFF**.
`89d847fb` (2023-06-12) hit exactly the A1 coupling and papered over it with the
force-set instead of decoupling. `fc19e646` (2024-03-26) flipped the default to 1.

## THE FIX AS LANDED

### A1 — the switch is not a render gate, in EITHER language

The coupling existed **twice, in two languages**, and the item brief named only
one of them. Fixing the named half alone and then landing A2 would have shipped a
`6` block that renders beside an `Alt-6` overlay — every node voltage and every
branch-current floater — that is blank for every user.

* **`src/op_annot.tcl`, `op_annot::_annotated`.** The three lines that read,
  coerced and tested the switch are gone. The gate is two terms: `xschem raw
  loaded >= 0` and `annot_p >= 0`, both still catch-wrapped (`xschem raw annot`
  raises on no-raw, measured). This is the road `6` draws through.
* **`src/token.c`, all six `cursor_b_val[]` expansion branches** (`get_pin_attr`'s
  `@#<pin>:spice_get_voltage`, `translate`'s bare `@spice_get_voltage`,
  `@spice_get_voltage(<net>)`, `@spice_get_diff_voltage`, and the two
  `@spice_get_current` / `modelparam` / `modelvoltage` arms). Each

  ```c
  int live = tclgetboolvar("live_cursor2_backannotate") && !raw_is_digital(xctx->raw);
  ```

  became

  ```c
  int live = !raw_is_digital(xctx->raw);
  ```

  This is the road `Alt-6`'s node voltages and the `lab_pin` / `ipin` / `opin` /
  `vdd` / `ngspice_probe` / `scope` floaters draw through.

**`!raw_is_digital()` SURVIVES UNTOUCHED — it is RULING D5-1 / D5-3 enforcement,
not tidiness.** Without it a digital database prints a logic level as a voltage
(measured `1` on a net whose analog raw reads 0.7535, and `0.5` for a VCD `X`).
`test_backannotate_digital` row BA87 is its source witness and now carries a
second job: it counts every `int live = ` line in `token.c`, requires all six to
carry `raw_is_digital`, and requires none to name the switch.

**The switch's legitimate readers are untouched.** The five sites in
`src/callback.c` and `src/scheduler.c:13276` read it to decide whether to *call*
`backannotate_at_cursor_b_pos()` when the cursor moves. That is the whole of what
the label promises, and none of them is a render gate.

### A2 — the behaviour is opt-in

* **`src/xschem.tcl`** — `set_ne live_cursor2_backannotate 1` → **`0`**. This
  restores the default upstream itself chose in `96f80d1d`.
* **`src/scheduler.c`, the `annotate_op` arm** — `tclsetboolvar
  ("live_cursor2_backannotate", 1);` is **deleted**. Nothing else in the arm
  moved: the digital refusal, the `extra_rawfile(3)` delete, the op/dc/tran
  fallback ladder and `update_op()` are as they were.

### Consequential edits

* **`utils/annot_mode.tcl`** — the `notlive` state and its sentence *"a raw is
  loaded but backannotation is off (live_cursor2_backannotate 0)"* are **deleted,
  not re-worded.** After A1 the switch is not a term of `_annotated`, so with a
  database attached the gate can fail on one cause only: `annot_p < 0`, a file
  that published no operating point. Keeping the sentence would blame an innocent
  variable, which is precisely the defect **issue 0459** was filed for — **0459
  closes here.** Users who saw that line now see the `noop` line, which names the
  real cause and the way out.
* **`src/actions.c`, `annot_overlay_sync()`** — the 14th epoch term
  `e.live_annot` is **removed**. It existed only because the switch changed what
  was rendered; after A1 nothing rendered reads it, so it is a cache-flush trigger
  keyed to an irrelevant variable. **Alternative considered and rejected:** keep
  the term and merely correct its comment. Rejected because the comment *is* the
  A1 coupling, and standing furniture is the failure mode this branch has been
  warned about twice. Row O29b is the only thing that can see it come back — O29
  stays green with the term left in.
* **`src/xschemrc`** — the option's paragraph said *"Default: enabled (1)"*,
  which the default flip turns into a shipped contradiction in the file users are
  told to read. It now says what the switch does, that `6` / `Alt-6` / the
  Annotate menu items do not need it, and *"Default: disabled (0)"*.
* **Spec and analysis prose** — `doc/claude/specs/op_annotation.md`,
  `doc/claude/code_analysis/waveform_subsystem_reference.md` and issue **0466**
  all stated the old three-term gate, the force-set and epoch term 14 as current.
  Each is marked SUPERSEDED BY 0864 in place.
* **Issue 0468** (the checkbutton has no `-command`) — its premise **inverted
  rather than went moot**, and it stays open. See below.

## WHAT AN EXISTING USER MUST DO — call this out, it is a behaviour change

**What `6` and `Alt-6` PAINT is unchanged.** They rendered with the box ticked
before; they render with it unticked now.

**What changes is that dragging cursor B no longer repaints schematic voltages
until the box is ticked once.** A user who relied on that must tick
**Simulation > Graphs > "Live annotate probes with 'b' cursor"** one time. The
setting is in the persisted variable list (`xschem.tcl`), so it survives once set.

This is a user-visible default change the user has not ratified, and a `rule`
debt is recorded against this issue for it.

## Considered and DEFERRED — ticking the box has no immediate effect

The checkbutton has no `-command` (**issue 0468**), so after ticking it nothing
repaints until the cursor next moves. That barely mattered while the default was
on; it now greets every user who opts in, so 0468 is **more** user-visible than
when it was filed, not moot. Not fixed here: it fixes neither measured defect and
widens the blast radius into the menu's command path with its own Tk row. If the
user wants the toggle to take effect at once, that is a one-line `-command` and a
D4 row.

## Also NOT in scope, said so a later crew does not assume it shipped

The feature request bundles this opt-in split with a new **Results > Annotate**
menu item (and an `Alt-Shift-6` binding through `cadence_style_rc`) for annotating
TRAN node voltages at cursor A. **That is a separate item and it did not ship
here.** This issue is only the split.

## Rows

`test_op_annot` (headless) 364 → **371**:

| row | kind | claim |
|---|---|---|
| **S16** | behavioural, rewritten | switch OFF renders the WHOLE block. Its params rows come through the Tcl gate and its `vgs`/`vds` rows through `token.c:4328`, so **one golden sees a fix done in only one language** — it reds with a half-blank block |
| **N10** | behavioural, rewritten | switch OFF + database attached → `6` reports *"raw already loaded"* and the block still renders. The behavioural death certificate of the `notlive` sentence |
| **N10b** | adjusted | the flag reads 0 after everything the file has annotated |
| **N10c** | structural | the switch and the `notlive` arm are gone from `utils/annot_mode.tcl`'s **code** lines. MANDATORY: after A1 the `live` arm is taken first, so a restored `notlive` is unreachable and no behavioural row can see it |
| **O29** | behavioural, rewritten | three SVG exports at switch 1 / 0 / 1 are byte-identical and populated — the **cache-level** pin, through the overlay epoch |
| **O29b** | structural | the epoch carries no live-annotate term. MANDATORY: invisible to every behavioural row |
| **A64-1** | behavioural | **Annotate Operating Point does not re-tick the box** — the user's sentence in one row, with the landed annotation as its positive control |
| **A64-2** | structural | the force-set is not back in the `annotate_op` arm |
| **A64-3** | behavioural, end-to-end | the `6` chord loads a database without re-ticking the box |
| **A64-4** | structural | the render gate is two terms and the switch is not one |
| **A64-5** | structural | the shipped default is OFF **and the option's own rc paragraph says so**. Source-only: after A1 the default changes nothing rendered, so no behavioural row in the tree can see this half |

`test_backannotate_digital` (headless) 83 → **84**: **BA87** rewritten into a
double witness (D5 term present in all six, switch absent from all six);
**BA88** new — switch OFF renders the measured voltage on an analog database and
still renders nothing on a digital one, which separates "dropped the switch term"
from "dropped the D5 term".

`test_annot_show_menu` (Tk, dev display) 22 → **25**: **D1** the checkbutton is
still there, still a checkbutton, still labelled and still 1/0 — *the feature is
kept, not removed*, and every other 0864 row is a negative claim a build that
deleted the entry would satisfy; **D2** it ships unticked; **D3** clicking the
entry the user actually clicks changes neither `_annotated` nor the
`@spice_get_voltage` floater — one road per language.

## AFTER state

```
test_op_annot             RESULT: ALL PASS (371 checks)   OVERALL: ok   exit 0
test_backannotate_digital RESULT: ALL PASS (84 checks)    OVERALL: ok   exit 0
test_annot_show_menu      RESULT: ALL PASS (25 checks)                  exit 0   (:99, openbox)
test_zero_point_raw_0836 73 | test_zero_point_pos_at_0852 41 | test_raw_read_dispatch 137
test_raw_ascii_point_bounds 90 | test_raw_read_failure_0306 63
test_wave_cursor_crossdb 93 | test_wave_markers 437 | test_wave_viewer 57
tests/run_regression.tcl (T1): ZERO counted failures
```

## STILL OPEN — what this change leaves behind

**0865 — a node voltage can now stay on the sheet after cursor B leaves it.**
Removing the render gate and shipping the switch OFF creates a state that could
not be reached before: the sheet is painted (the user pressed `Alt-6`) and does
not follow the cursor (the box is off), so node `d` reads 4 while cursor B sits
at 1 ns where `v(d)` is 1. Pressing `Alt-6` again does not refresh it. Measured
against the **painted** output, not the token:

```
P2 after Alt-6 (annot_show 2):                token='4'  PAINTED texts = d 4
P3 after pressing s (cursor B now 1ns, v(d)=1):
     token='4'  annot=3 4e-09 0  PAINTED texts = d 4
Q3 user presses Alt-6 AGAIN to refresh:       PAINTED = d 4   annot=3 4e-09 0
```

Root cause: three call sites PUBLISH a cursor-B annotation without consulting
the switch (`save.c:1287` raw_read, `actions.c:4819` descend,
`scheduler.c:12080/12112` `set cursor2_x`) while the six that would keep it
current are gated on it. **0865 carries the measurement, the four options and
the rows; it needs the user's ruling and a `rule` debt is recorded for it.**

**0866 — REFUTED, filed so it is not re-derived.** The verification also
reported that nothing takes annotated numbers off the sheet any more, and that
loading a raw paints them unasked. Both measured `xschem translate`, which is
the token expansion and not the render path. Against an SVG export: with the
shipped `annot_show` of 0 nothing is painted at all (`P1 ... PAINTED texts = d`),
and `Ctrl-6` still blanks them (`P4 ... PAINTED texts = d`). The `annot_show`
mask ruled in **0614** is the off switch and it is intact.

**0867 — unrelated, found while verifying this item.** Two concurrent
`run_regression.tcl` runs in one tree destroy each other's job status files
(`open_close.tcl`'s `.work` is not pid-scoped) and 25 phantom `FATAL: ... :
exit -1` lines get counted. Filed separately.

## Correction to the recorded `rule` debt's wording

The debt reads *"existing users must tick Simulation > Graphs > Live annotate
once to keep the schematic following cursor B"*. Two corrections, recorded here
because a `rule` entry is a pointer to this file and must never be silently
re-written:

* `live_cursor2_backannotate` is in the **persisted** variable list
  (`src/xschem.tcl`), so any user who has ever used *Save configuration* already
  carries `set live_cursor2_backannotate 1` in their own rc and sees **no
  change at all** — for them the sentence is simply wrong.
* The half most worth ruling on is not the tick, it is **0865**: what the sheet
  should do with a number whose cursor has moved on.

## Two coverage claims in this item's own comments were WRONG, and are corrected

Both said a guard was invisible to every behavioural row; the sabotage run
disproved both, and the prose is now fixed in place
(`tests/headless/test_op_annot.tcl`, `utils/annot_mode.tcl`):

* the `notlive` arm — SAB-8 reddened **N10b**, whose fixture has `annot_p < 0`
  and so falls through the `live` arm into the selector. N10c is still mandatory
  (it is the only cover for the published-point path, which is every real
  user's), but it is not the only row that can see the arm return.
* the shipped default — SAB-6 reddened **N10b** too, which reads the variable
  directly. Nothing *paints* differently for it; that is the true claim.

An unchecked coverage claim left standing in a comment is how a guard rots, and
this branch has the scar tissue to prove it.

## Coverage note — where the three menu rows actually run

`tests/headless/test_annot_show_menu.tcl` needs Tk, so it is in neither
`full_audit.sh`'s `nogui_tests` nor `run_regression.tcl`'s `hcases`;
`full_audit.sh` reaches it by glob and **T1 can never run it**. D1/D2/D3 are the
only rows in the tree that click the actual **Simulation > Graphs** entry, and
they are invisible to the routine gate. That is the normal arrangement for every
Tk suite here, not a defect of this item — but it is worth knowing which gate
would catch a regression in them, and which would not.
