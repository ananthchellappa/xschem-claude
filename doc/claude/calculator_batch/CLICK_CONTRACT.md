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
| 5.1 P-route insertion (R410) | **shipped** 2026-10-04 | `calc::fn_action` (pure, both arms) → `calc::fn_insert` → `calc::buf_insert_token`; `calc::fn_click` is now a four-arm dispatcher |
| 5.2 hover help (R413) | **shipped** | `calc::fn_hover` / `calc::fn_unhover` |
| 5.3 C-route functions | **shipped** 2026-10-04 | the four recipes live in `calc::catalogue`, S24 pins the strings, band `CE14` of `test_calc_engine` checks the **numbers** against independent arithmetic, and 5.1's branch is the insertion path |
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

⚠ **DONE — 1639 WAS FIXED ON 2026-10-03, SO 5.4 IS NO LONGER BLOCKED ON IT.** `calc::riseTime` now
defers behind the shared `listdefer` sentence (no new `cross_msg` kind, so no new user-visible
sentence), fenced by band `MT9b` of `tests/headless/test_calc_measure.tcl`. The paragraph below about
MT7/MT8 comparing by identity **still governs the dialog**, with one measured refinement: a split
that reworded the sentence *only for a new caller* was caught by `MT9b`'s identity row and by all
three `WD9` rows, and **not** by MT7/MT8 — those two read `delay`'s and `dutyCycle_scalar`'s answers,
so they redden on a split that touches the sentence the *siblings* use. Both routes are fenced; they
are fenced in different files.

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

## 8. The dialog, specified from the two modals this tree already has

Design crew, 2026-10-03, read-only. **Parent: `rdw::scope_dialog`** (with `scope_dialog_build` /
`scope_dialog_done`), borrowing the field layout from `ase::ui::dialog_frame` + `dialog_row` and
`<Return>`→OK from `ase::ui::bus_dialog`. Four parts: namespace state, build, done, wrapper.

**The one line that must be copied verbatim in spirit**, and its own comment says why:

> *"PRE-SET TO CANCEL, BEFORE THE BUILD. A window destroyed by a deadman timer or by a window
> manager never reaches `scope_dialog_done`, and a stale result would then be read as an answer the
> user never gave."*

That is R412's Cancel requirement surviving a route that never runs `_done` — i.e. **a stale result
being read as consent.** `bus_dialog` sets its result on the last line of `_build` instead, so a
raising build leaves the *previous* answer; that is the half not to copy.

`scope_dialog` wins on every axis that matters for eight fields: conditional field presence, a
no-Tk guard (`have_tk` + `winfo exists`, returning Cancel), a **caught** build, a `tkwait` guarded
by `winfo exists` **and** `catch`, a `wm protocol WM_DELETE_WINDOW` → cancel path, and the keyboard
**handed back** to the previously focused widget. `bus_dialog` restores no focus and has no WM-close
path.

⚠ **`xschem.tcl`'s `input_line` is the wrong thing to copy, and not only for being single-field**: it
does `tkwait visibility` *before* the grab, leaves `tkwait window` unguarded, and calls
`xschem set semaphore … -1` *after* it — so an early destroy raises out of the proc and **leaks the
semaphore increment, leaving the C side refusing canvas work.** Its re-entrancy guard returns empty,
which an R412 caller would read as Cancel. Neither recommended parent touches the semaphore; the
dialog must not either.

### `calc::fn_argspec {name}` — a new proc, pure Tcl, no Tk

Returns `{key label kind required default}` rows, and `{}` for any name with no arguments — which
also makes the route-T branch's **30-verb fall-through legible** rather than accidental.

| verb | fields |
|---|---|
| `cross` | `Level` (real, req) · `Occurrence (Nth)` (int, 1) · `Edge` (enum rising/falling/either) |
| `riseTime` | `Low level` **req** · `High level` **req** (R415: no derivation) · `Low threshold %` 10 · `High threshold %` 90 · `Occurrence (Nth)` 1 · `Dataset` |
| `delay` | `Signal A (RPN)` ← buffer · `Level A` · `Edge A` · `Occurrence A (Nth)` · `Signal B (RPN)` · `Level B` · `Edge B` · `Occurrence B (Nth)` |
| `dutyCycle` | `Level` (req) · `X axis` (enum start/number/mid, default `start` per R420) · `Cycle` · `Dataset` |

⚠ **The dialog validates SHAPE ONLY.** `real` is a finite double (`string is double -strict` **and**
not inf/nan), `int` is `string is integer -strict`, `enum` is membership, and an RPN field is
**non-empty text that is never parsed** (R401). **Semantic refusals stay with the verb** — `nth = 0`
must reach `cross_scalar`/`delay`, because MT7/MT8 compare against `[calc::cross_msg listdefer]` by
identity, so the dialog must never re-word one of those sentences.

### ⚠ R421 says where ONE operand comes from, and `delay` needs TWO

`delay`'s eight required arguments are **two RPN operands plus three fields per side**. R421 names
`calc::rpn_of_buffer` as the operand source, which supplies **A only**, and no ruling says where **B**
comes from. **Driver's decision, recorded rather than assumed**: signal A is pre-filled from the
buffer, signal B is a typed field, and both become pickable when phase 6's schematic picking lands.
Filed as a `rule` debt (`calc_argdialog_field_labels_and_delay_second_signal`) together with the
user-facing field labels above, so either can be overruled.

⚠ **One measurement is owed before coding**: `dutyCycle`'s formals disagree between two live
documents — `test_calc_measure.tcl`'s header says `<rpn> <level> ?<cycle>? ?<dataset>?` while R420
adds an `xaxis` option, and `DESTINATION_CONTRACT.md` §6 names neither the argument nor its position.
Read the shipped proc and settle it; do not infer the order.

### The Cancel fence — S23's existing idiom is NOT sufficient

R412's byte-identical requirement is fenceable only against a buffer read **twice**, with a
non-trivial sentinel already in it. Capture before: the buffer text, `edit modified`, the status
history, the status line, and the stack size. Assert all five after Cancel — **plus the undo
witness**: one `edit undo` must leave the buffer *still* equal to the capture (then `redo`).

**Why S23's `INERT SENTINEL` idiom does not cover it**: it captures the text, a count and a realness
leg, and checks **none** of `edit modified`, the undo stack or the status history — which are exactly
the three a touch-then-undo moves while staying byte-identical. Extend it with
`test_calc_buffer`'s vocabulary. ⚠ **Do not use `edit canundo`** — Tk 8.6 only; that suite's
`shadow_install`/`shadow_remove` exist to force the 8.5 arm, and `::calc::editcan` is the capability
cache.

### ⚠⚠ 9. The traps — the first one is a HANG, not a failure

**(a) The three suites that will drive this modal are the only `test_calc_*` suites that never arm
the watchdog.** They do not `source tests/headless/scratch.tcl`; every sibling does. So
`XSCHEM_SUITE_WATCHDOG_MS` is never armed in them, and their only `after` uses are small sleeps with
no deadman. `run_suites.sh` (200 s), T1 (900 s, counted `FAIL`) and `full_audit.sh` (300 s) still
bound their respective spellings — but **the bare `./src/xschem … --script <suite>` that a developer
types constantly has no bound at all.** That is `scratch.tcl`'s own declared gap landing on exactly
the three suites that lack the layer. **Being fixed before the modal exists**, because a hang is
indistinguishable from slowness and this project has already lost a night to one.

**(b) `event generate` is SYNCHRONOUS** (`-when now` is the default). So a `Button-1` delivered to a
T-route entry *enters* `fn_click` → `tkwait`, and **the next line of the suite never runs.** S23's
existing gesture band is Motion / Button-1 / ButtonRelease-1 on three consecutive lines; aimed at one
of these verbs it blocks on line two. **Arm the poll BEFORE the `event generate`.**

**(c) Copy the poll, never a delay** — `sd_arm` / `sd_poll_modal` / `sd_disarm` in
`test_rdw_keys_1245.tcl`. Three measured properties, all load-bearing: the condition is
`[winfo exists $w]` **AND `[grab current] eq $w`** (naming the window, because an unrelated grab
defeated the `ne {}` form); give-up needs a poll count **AND** a wall-clock deadline (`after 5` is a
floor — a 900-poll give-up measured 6.0–6.5 s under load, past the 5 s deadman it was believed to sit
inside); and **both timers are cancelled at the end of every row**, or row N's deadman destroys row
N+1's dialog. Two sabotage shapes are required, and the second is the one that ships the bug:
**A** the driver fires before the toplevel exists; **B** it fires inside the wrapper's own `update`,
window present and grab absent — **B passes under a `winfo exists`-only poll.**

**(d) Keep the grab LOCAL. `grab set $w`, never `grab set -global`.** The tree's only global grabs
are the print and screen-capture paths. A global grab from the Calculator would freeze the GUI
gate's Pause/Stop panel — a separate `wish` process — on a run against the user's real screen,
**disabling their emergency control**. `xvfb_arm.sh` forces `GUI_GATE=0` so the standard arms are
unaffected; the real screen is not.

**(e) `full_audit.sh` reaches all three suites** through its `test_*.tcl` glob, and none is in
`nogui_tests` — so a dialog that opens without the `have_tk` guard costs `AUDIT_TIMEOUT` 300 s plus a
crash row on **every** full audit run.

### The free coverage win

`calc::fn_argspec` needs **no Tk**, so its four specifications — keys, order, labels, kinds,
requiredness, defaults — belong in `test_calc_measure` (`hcases`, measured on **both** arms) rather
than in a `dcases`-only suite. That is the largest piece of this stage that can be fenced on the
counted arm, and it costs nothing.

**What stays display-only, and therefore gate-only**: every row touching `fn_click`, the browser
fill, the canvas gesture, the dialog and `grab`. `test_calc_skeleton` reports `ALL PASS (0 checks)`
under `--nogui` and the other two print a no-X skip. Report this stage's green as
`tests/headless/run_suites.sh <suite>`; a `--nogui` number proves nothing here. **`look` debts owed**:
the dialog's appearance on the real screen, that R421's provenance sentence fits the status bar
without eliding, tab order and Return/Escape feel, and that the modal does not open behind `.calc`.

## 10. Corrections from the suite author — four of them change the implementation

**61 rows, red first**: band **MT11** (23) in `test_calc_measure` (`hcases`, **both arms** — the free
coverage win §8 called for), **S28** (25, sub-bands `/0`–`/6`, `/A`–`/E`, `/Z`) in
`test_calc_skeleton`, and **CW14** (13) in `test_calc_widgets`. Against the tree with no
implementation: `19 FAILED (139 passed)` / `15 FAILED (558 passed)` / `9 FAILED (250 passed)`, with
**zero aborted bands, zero `RAISED:`, zero `UNEXPECTED ERROR`** in all three, and every failure
naming the absent thing rather than a bare mismatch — `NOPROC:calc::fn_argspec`,
`NOSUCHKEY:dutyCycle/xaxis`, `NO-MODAL`, `POISON-AN-ANSWER-THE-USER-NEVER-GAVE`. A conforming
reference took all three green, and the reference was then deleted and the red reproduced.

⚠ **These rows are a STANDING RED in T1 until the implementation lands** — three registered cases
with `banner_complete` 0 and three `HARNESS:` lines. Published counts when green: **135 → 158**,
**548 → 573**, **246 → 259**; both `--nogui` arms byte-unchanged; `cases`/`blocks`/`skips`/`wc -l`
all +0, since all three were already registered.

### (a) `dutyCycle`'s `xaxis` is the FIFTH formal, not the third

```
proc calc::dutyCycle        {rpn level {cycle 0} {dataset 0} {xaxis start}}
proc calc::dutyCycle_scalar {rpn level {cycle 0} {dataset 0}}
```

So §8's field order (`Level · X axis · Cycle · Dataset`) is a **display** order and genuinely differs
from the formal order. **Compose the call BY KEY, never positionally** — a row measures the divergence
deliberately. `test_calc_measure`'s own header had said `xaxis` was absent entirely; corrected.

### (b) `dutyCycle_scalar` cannot carry the axis at all

Its formals stop at `dataset`, and a row is red for that. Two legitimate fixes — extend the wrapper,
or have the click call `calc::dutyCycle` directly. **The driver's preference is to extend the
wrapper**: the dialog calls the surface, a field the dialog offers must reach the proc, and that
wrapper's own comment already names phase 5's dialog as the caller it is waiting for. The
implementer may choose the other **out loud**.

### (c) "Pre-set to cancel" belongs at the top of the BUILD as well as in the wrapper

`rdw::scope_dialog` does it only in the wrapper. A row requires both — one notch stronger than the
parent — because that is **the only way to measure it without entering `tkwait`**. Declared in the
row's own comment.

### (d) §9(a) is discharged

All three suites now `source tests/headless/scratch.tcl`; the stall bound landed in a concurrent
stage, and a derived row in `test_suite_watchdog_1403` now asserts that **every** registered
event-loop case has one. Likewise §6's *"fix 1639 first"* is discharged — `calc::riseTime` defers
`nth = 0` behind the shared sentence as of 2026-10-03.

### The sabotage table, and the rows that are the whole fence for their defect

| mutation | reddened |
|---|---|
| click calls raw `calc::cross` instead of `cross_scalar` | 5 rows, one reporting a diagnostic count |
| `-autoseparators` left ON across the replace | **exactly 1** — R421's undo witness |
| the dialog opens BEFORE the result gate | **exactly 2** |
| `grab set -global` | **exactly 2** — one reads the mode, one names the proc |
| pre-set-to-cancel in the wrapper only | **exactly 1** — the poison row |
| `delay` side B carrying side A's labels | **exactly 2** |
| no shape validation at all | **exactly 1**, printing the bad value composed into the call |

Both **poll** sabotages redden: weakening the condition to `winfo exists` alone catches the shape
that ships the bug, and replacing the poll with a fixed delay catches three rows.

### Holes the suite declares — the load-bearing ones

The OK path's measurement is **stubbed**, so these rows fence the **surface**, not the number. **Only
`cross` is driven through OK**; `delay`'s two-operand call is unfenced (its pre-fill is not). The
axis's *effect* is unobservable for a scalar answer, so nothing fences it reaching the data. R401's
*"an rpn field is never parsed"* has nothing observable to assert. Shape validation is driven for one
field. **And every sentence this gesture prints is unratified**, so the rows assert containment and
movement, never a string — except `calc::require_result`'s refusal, compared by identity. Five debts
filed by the driver: four `look` (appearance, the provenance line fitting the status bar without
eliding, tab order and Return/Escape feel, and that the modal does not open behind `.calc` — whose
structural half *is* mechanised via `wm transient`) and one `rule`, the click sentence.

### ⚠ Four Tcl traps the suite author hit, worth more than the rows

- **A bare `}` inside a braced word closes it** — hit **twice**, the second time *inside the comment
  warning about the first*. CLAUDE.md records the same accident, once inside the comment warning
  about it. The shape recurs because the warning itself is written in the medium it warns about.
- **A `{args}` stub measures the FIXTURE, not the product.** A recorder stub reddened against
  *correct* code, because a by-key composition reads `info args`; the stub now derives the real
  proc's own formals.
- **`cget` accepts abbreviations**, so `cget -value` on a combobox answers `-values` — a **false
  red** until caught.
- **`"$name(…)"` is an array reference**, which is why a leg asserting the click **returns rather
  than raises** now exists.

---

## New user-facing text this stage ships, collected for ratification

One sentence, and it is **unratified**. The standing practice is to collect a stage's new
user-facing sentences into one reviewable place rather than raise them one at a time, so this
section is that place and the `rule` debt `calc_insert_sentence_R410` points here.

**The sentence:** clicking a live function entry writes `function <name>: inserted <token>` on the
status line — `function average: inserted avg()`, or `function rms: inserted dup() * avg() sqrt()`.

Three measured facts bear on changing it:

* **Naming both halves is load-bearing, not redundant.** The catalogue's `name` and its `insert`
  token differ for most live rows — a user clicks `average` and `avg()` is what lands in the
  buffer — so a sentence naming only one of them hides which. The population where they differ is
  re-derived by band `MT13` of `tests/headless/test_calc_measure.tcl`, not counted here.
* **The budget is not a constraint.** `.calc.status.msg` measures 613 px in `TkTextFont` on the
  shipped window, and the widest sentence this catalogue can compose measures 347 px — the one for
  `groupDelay`, whose token is the longest. For calibration the refusal sentence
  (`function <name> is not available: <reason>`) measures 474 px, which is the figure
  `calc::fn_reason`'s own header records, so the instrument agrees with the one already in the tree.
  Nothing is near the cliff that truncated the old N-route reason mid-word.
* **An overrule is a two-site edit.** The sentence is composed in exactly one place,
  `calc::fn_insert`'s single `calc::status` call, and asserted by one row apiece in `S23` and
  `CW13`. Every other comparison in the band is by identity against the catalogue table, so nothing
  else moves.

House style for this surface, already in force elsewhere in it: terse, and acronyms in uppercase.
