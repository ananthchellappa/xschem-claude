# Making a measurement verb clickable — the implementation contract

**Opened by the driver 2026-10-02**, before any code exists. PLAN phase 5, rows 5.1 and 5.4.
Companion to `CROSS_CONTRACT.md`, `TIMING_CONTRACT.md` and `DESTINATION_CONTRACT.md`, all of which
stay in force. Where this file and `doc/claude/specs/calculator.md` differ, **the spec wins and this
file is the bug**.

The stage exists because **four verbs are built, tested and gating — 312 checks across two registered
suites — and a user cannot reach any of them.** `calc::fn_click` dispatches on `calc::fn_reason`,
which is empty for route `T`, so `cross`, `riseTime`, `delay` and `dutyCycle` all fall through to
`calc::inert … 5`.

## 1. The gesture, in the rulings' own words

- **R410** — *"Clicking a function in RPN mode **appends** its token to the buffer, preceded by a
  space."*
- **R411** — *"Clicking a function in algebraic mode **wraps** the current buffer: `abs(<buffer>)`."*
- **R412** — *"A function needing extra arguments (`riseTime`, `cross`, `bandwidth`, `clip`, …) opens
  a small argument dialog **before** touching the buffer. Cancel leaves the buffer byte-identical."*
- **R404** — *"A T-route function that returns a scalar puts the scalar in the buffer as a **literal
  number with a comment of provenance in the status area**, not as an opaque handle."*
- **R401** — *"A T-route function **must not** parse the expression… It operates on numbers, never on
  text."*

**So the gesture is: dialog → measure → the NUMBER in the buffer.** R410's token append is for routes
P and C only; a T verb's click never inserts the word `cross`.

## 2. R421 — the measured number replaces the buffer, and the expression stays recoverable

⚠ **Recon found that two halves of this gesture are unstated in EVERY ruling**: nothing anywhere says
what **OK** does (R412 specifies only Cancel), and nothing says where the verb's `rpn` operand comes
from. The only precedent in the tree is `calc::eval_click` → `calc::require_result` →
`calc::rpn_of_buffer`, which reads the buffer. So if the buffer is both the operand source and R404's
destination, **the measured number overwrites the user's expression** — and no ruling covered that.

Put to the user with the preserving shape offered first, their answer:

> **Replace it, but keep it recoverable.**

So, as one behaviour with three parts and none of them optional:

1. The number lands in the buffer as a literal, per R404, where further arithmetic can use it.
2. **The expression it was measured from is spelled out on the status line** — which is R404's
   *"comment of provenance"* made concrete: not just the value, but `riseTime(v(out), 0.1, 0.9) = …`.
3. **Undo restores the expression.** `calc::buf_insert_token` already emits `.calc.buf edit separator`,
   so the mechanism exists; what this ruling adds is that the separator placement must make **one**
   undo put the user's expression back, not two.

A row must fence each of the three. In particular part 3 is the one that will rot silently: a later
change to the insertion path could leave the number in place and the undo history subtly wrong, and
nothing else would notice.

## 3. What recon settled, and where it refuted the driver

### ⚠⚠ The `insert` field is NOT a shortcut — two registered rows FORBID filling it

The driver's hope was that `calc::catalogue`'s existing `insert` field already held a call template,
which would have turned the dialog from an M into an S. Measured, by lifting the catalogue literal and
grouping by route: `insert` is non-empty for **all 56** route-P rows and **all 4** route-C rows, and
**empty for all 34 route-T rows** (and all N and X rows).

That is not an omission waiting to be filled. Both S24 predicates were lifted and run over the real
catalogue and over one giving the four verbs `insert = <name>()`:

```
REAL    : nemit = 60   badempty = {}
MUTATED : nemit = 64   badempty = {cross=(cross()) riseTime=(riseTime()) delay=(delay()) dutyCycle=(dutyCycle())}
```

Two rows redden — *"S24 every emitted token is one the engine lexes, or a number"* and *"S24 P and C
rows emit, T/N/X rows emit nothing"* — both in `test_calc_skeleton`, **`dcases` only, so only a
gate's display arm would have caught it.** `insert` also has exactly one consumer in `src/`:
`calc::fn_fill` binds it and never reads it, same as `returns`.

**So the argument spec is a NEW PROC, `calc::fn_argspec {name}`, and not a seventh catalogue field.**
A seventh field reddens *"S24 the schema is the six ruled fields"*, S24's arity-6 check, *"D3 the row
schema is six fields"* in `test_calc_widgets` and that suite's own arity loop — and, worse, **silently
skips two S23 loops that `continue` on `llength != 6`**, which is a row that stops measuring rather
than failing.

### Phase 5 has FIVE rows, not four

| row | status | proving symbol |
|---|---|---|
| 5.1 P-route insertion (R410) | **absent** | `calc::fn_click` has no route branch at all; the primitive it needs, `calc::buf_insert_token`, already exists and `calc::pad_click` uses it |
| 5.2 hover help (R413) | **shipped** | `calc::fn_hover` / `calc::fn_unhover` |
| 5.3 C-route functions | **partial** | four recipes live in `calc::catalogue` and S24 pins the strings; no proc, no insertion path, no numeric check |
| 5.4 argument dialog (R412) | **absent** | zero `grab`, zero `tkwait`, zero `vwait` in `src/calculator.tcl`; its only `toplevel` is `.calc` |
| 5.5 `data` selector | **absent** | outside this stage, named because the driver's relayed "5.1 + 5.4 remain" omitted it **and** 5.3 |

### The smallest useful change: four sites, no catalogue edit

1. **`calc::fn_click`** — a route-`T` branch dispatching by name to a new `calc::fn_measure`, **keeping
   the `inert … 5` fall-through for every other T name.** ⚠ There are **34 T rows and only 4 have
   procs**; a blanket route-T branch strands 30 verbs with no handler.
2. **`calc::fn_argspec {name}`** — new proc, per above.
3. **The modal dialog — copy `rdw::scope_dialog`, do not invent one.** It is the tree's closest fit:
   `scope_dialog_build` / `scope_dialog_done` / `scope_dialog`, multi-field, a `have_tk` guard, and
   `scope_result` **pre-set to cancel before the build** — its own comment explains why, and it is
   exactly R412's requirement: *"a window destroyed by a deadman timer or by a window manager never
   reaches `scope_dialog_done`, and a stale result would then be read as an answer the user never
   gave"*. `ase::ui::bus_dialog` is the same tripartite shape with teardown tolerance.
   `xschem.tcl`'s `input_line` is **single-field** and cannot carry `delay`'s eight.
4. **The result path** — `calc::eval_click`'s shape exactly: `calc::require_result` gate →
   `calc::rpn_of_buffer` → measure → `calc::status` with provenance → R421's number into the buffer.

The surface wrappers the click calls **already exist and say so**: `calc::cross_scalar`'s own comment
reads *"R412's argument dialog is phase 5's … this proc is the decision written down where the dialog
will find it."* All four return the same dict `{ok absent value dataset dest msg}`.

⚠ The click must call **`calc::cross_scalar`, not `calc::cross`** — the raw proc answers `nth = 0`
with success and a *list*, and has no deferral. And the driver's "riseTime takes seven arguments,
delay takes nine" was counting **formals, not requirements**: `riseTime` needs `lo` and `hi` (R415
refuses them empty) with four defaulted, and `delay` needs **eight**.

## 4. Registered rows: route T costs nothing, route P costs six

There are **12** `fn_click` sites in `tests/` and **not one clicks a T-route verb**. The four rows
asserting the phase-5 sentence by literal — S23 ×2 in `test_calc_skeleton`, CW13 ×2 in
`test_calc_widgets` — all drive **route-P `average`**, including the one that reaches it indirectly
through `[.calc.fn.list itemcget [lindex $fnitems 0] -text]`, which resolves to `average` because
`fn_fill` creates item `i = col*nrow + r` and the dictionary-sorted head of Special Functions is
`average`.

⚠ **So wiring route T is free, and wiring 5.1 (route P) reddens six** — those four plus *"S23 no
function click touched the buffer"* and *"S23 no function click touched the stack"*. **This stage does
route T only.** 5.1 is a separate decision with a real cost attached.

### ⚠⚠ WHY route T is free — and the trap that reading it carelessly sets

The driver verified the crew's premise and found the **mechanism**, which the receipt did not state and
which turns the premise into a hard constraint. Of the 12 sites, ten name a verb literally
(`average`, `dft`, `pzbode` — routes P, N and X) and two are loops. The dangerous-looking one iterates
over **every entry the browser drew** and would click all 34 T verbs — except for this line:

```tcl
set why [pcall calc::fn_reason [lindex $row 2]]
if {$why eq {}} continue
```

**Route T is skipped only because `calc::fn_reason` answers empty for it.** The loop then asserts that
each clicked entry's message is exactly `"function $nm is not available: $why"`.

**So: do NOT make route `T` non-empty in `calc::fn_reason`.** That is the one-line change someone
would reach for to fix the false message of §5, and it would make this loop click all 34 T verbs and
assert the *"is not available"* phrasing over four verbs that **are** available — reddening a row
while also telling the user something false in a second place. The truthful message belongs in a
**route-`T` branch of `calc::fn_click`**, which this loop never reaches.

That distinction is also why the other loop is safe for a different reason: it iterates the literal
list `{average dft pzbode}`, not the catalogue. Two loops, two different reasons, and only one of them
would have survived a careless fix. ⚠ Both loops carry a **count** alongside their assertion
(`nrefused`, `fnclicked`) with comments saying why — *"nothing was clicked"* and *"everything was
clicked and touched nothing"* are otherwise the same green. That is the same vacuous-row discipline
this batch has now applied four times, already present in the suite being extended.

## 5. Greying is deliberate and fenced; the MESSAGE is the defect

A T-route entry renders as **live** and does nothing. That is not an oversight — three independent
sources say so. `calc::fn_dead_routes` returns `{N X}`; the ruling comment above `calc::fn_fields`
says *"every N row, and every X row, is RENDERED IN THE LIST AND DISABLED"*; spec §7.2 names the
greyed set as **exactly** fourteen functions, no T verb among them; and row *"S23 moving the dead-route
set repaints the greying"* asserts `{14 48 14 1}`, so **14 grey is a number re-measured every gate**
and greying `cross` would redden it. `calc::inert`'s own comment adds the principle: *"'Not implemented
(phase N)' is a promise, and it may only be made where a phase really is coming."*

⚠ **But the sentence the user reads is false, and that is worth fixing on its own.** Today a click on
`cross` prints `function cross: not implemented (phase 5)` — and `cross` **is** implemented, with 187
checks, as are the other three with 125. The sentence is true about the *click* and false about the
*function*: **four built-and-gated verbs currently tell the user they do not exist.** A route-T branch
saying instead that the verb needs arguments and the dialog is phase 5 reddens **no registered row**,
because no test clicks a T verb. It ships whether or not the dialog does. The replacement wording is
user-visible, so it is filed as a `rule` debt rather than chosen here.

## 6. Two prerequisites and one fencing limit

**Issue 1639 is a PREREQUISITE of 5.4, not a parallel item.** `calc::riseTime` has **no `nth == 0`
guard** — it passes `nth` straight to `calc::cross`, which answers `nth = 0` with success and a list,
and the subtraction then **raises**. `cross_scalar` and `delay` both guard with `listdefer`;
`riseTime` does not. **A dialog that exposes `nth` turns that raise into a user gesture.** Fix 1639
first.

**MT7/MT8 of `test_calc_measure` (`hcases`, gating) compare against `[calc::cross_msg listdefer]` by
identity.** If the dialog's refusal path rewords or splits that sentence, both redden. And ⚠ the
dialog's refusals will add arms to the same `switch` in `calc::cross_msg` where **a comment between
two patterns is a parse error `info complete` cannot see** — 34 rows red at once, last stage. Prose
goes **above the proc**, never between patterns.

**"Byte-identical on Cancel" is fenceable only against a buffer read twice** — with a non-empty,
non-trivial sentinel already in it, **and the undo history checked too**, because
`calc::buf_insert_token` emits `edit separator`: a dialog that touched the buffer and undid it is
byte-identical while having moved `edit modified` and the undo stack. S23's existing `INERT SENTINEL`
idiom is the pattern to copy.

⚠ **The click is not fenceable headless at all.** Every row touching `calc::fn_click`, `fn_fill`, the
canvas gesture, the dialog and `grab` lives in `test_calc_skeleton` or `test_calc_widgets`, both
`dcases` **alone**: the first prints `ALL PASS (0 checks)` under `--nogui`, the second prints
`RESULT: SKIP (no X: …)`. The measurement procs stay fenced headless in `test_calc_cross` and
`test_calc_measure`. **So only the gate's display arm verifies this stage** — which is a reason to
state it plainly in the report, not a reason to skip the rows.

## 7. Focus

The dialog takes the keyboard, and that is correct here: the user opened it by clicking. The standing
rule against stealing focus governs **surfacing a message** at a moment the user did not ask for one —
a modal the user invoked is the opposite case. `rdw::scope_dialog`'s `grab set` + `focus -force` +
hand-the-keyboard-back teardown is the idiom to copy, teardown included.
