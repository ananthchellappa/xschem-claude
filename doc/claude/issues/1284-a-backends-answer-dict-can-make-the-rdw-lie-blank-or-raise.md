# 1284 — a backend's answer dict can make the RDW lie, blank, or raise

**Filed by:** item **B3**, 2026-09-03. Found by B3's adversary (Verify-C);
**four shapes re-measured independently by the write-up agent**, which found one
the adversary did not report (an **uncaught raise**). **FILED, NOT FIXED.**

**Status:** **FIXED by item B2d, 2026-09-04**, including §5's two remaining
shapes and a SIXTH the adversary found after the fix (the `state` key is a line
injector — §"Fixed by item B2d"). Four edges remain, filed as **1299**.
**Unreachable through the shipped ngspice backend**; reachable
by any third-party backend the **D-5** seam exists to admit.

---

## 1. Why this is filed at all

The whole point of ruling **D-5** and of `ase::backend_hook` is that
*"nothing above the seam changes when the wildcard arrives"* — a second simulator
plugs in and the window renders its answer. `rdw::format_answer` therefore treats
the five-key dict as **trusted input**, and it is not: it is whatever a backend
hands it.

Today `ngspice`'s `op_param_set` builds `devices` with `dict set` and gates every
value through `op_annot::raw_class`'s `string is double -strict`, so none of the
shapes below can occur. That is a property of **one backend**, not of the
renderer.

## 2. Four shapes, measured on this binary, 2026-09-03

All four driven through `rdw::block_text [rdw::format_answer $a $ctx]` with
`ctx = {header {M1:/} devpath @m.x1.m1 simtype op instname M1}`.

### (a) malformed at the DICT level → **a confident wrong answer**

`devices` = `"@m.x1.m1 {{id 1"` (not a valid list). `rdw::_rowdevs`'s `catch`
swallows it, the union comes back empty, and `format_answer` renders the
**fifth silence**:

```
M1:/
@m.x1.m1
This run's raw holds no operating-point columns for @m.x1.m1. Only parameters the deck explicitly saved appear here.
```

That sentence is a **statement about the raw** and it is false — the backend did
answer, its answer was unreadable, and the window says the run saved nothing.
This is the *wrong-answer-wearing-a-healthy-state* shape that returned item **B1**
`[F]` (issue 1272), one layer out.

### (b) malformed at the VALUE level → **an uncaught raise** *(not reported by the adversary)*

`devices` = a well-formed dict whose **value** is `{{id 1`:

```
RAISED: unmatched open brace in list
```

The raise escapes `rdw::format_answer` — the pure renderer, which every row of
the suite and every widget path calls. `_rowdevs` catches at the dict level;
nothing catches the `foreach {p v}` over a value. In the Tk path this surfaces as
a background error and the pane paints nothing.

### (c) a value-less pair → **blank, with no footnote**

`devices` = `{@m.x1.m1 {{id}}}` (a one-element pair) renders

```
    id :
```

i.e. **byte-identical to an `absent` column**, but without the footnote that
explains what a blank means. The renderer's one honest distinction between
"absent" and "present" is lost.

### (d) a newline inside a value → **one pair becomes two lines**

`devices` = `{@m.x1.m1 {{id "1.5\nINJECTED"}}}` renders

```
    id : 1.5
INJECTED
```

The second line is unindented and carries **no tag**, so it is neither a value
row nor a note. The one-pair-one-line model that `rdw::block_text` and
`rdw::render_pane` share is broken from the data side.

## 3. The related case that IS reachable: the footnote is per-block, not per-row

Measured separately, and this one needs no hostile backend:

* an **empty-string** value renders `    id :`
* a genuinely **absent** column renders `    id :` **plus** the block footnote
  *"A blank value means the raw names that column but the simulator did not
  compute it."*

The footnote is emitted **once per block, when `absent` is non-empty**. So in a
block that has *any* absent column, an empty-string value inherits a footnote
that is **false about it**. Low reachability through ngspice (values are
`string is double -strict` gated), but the coupling is in the renderer, not the
backend.

## 4. The fix

Small and entirely inside `src/rdw.tcl`; not applied here because it changes the
renderer B3 has just fenced with 42 checks, and because the choice of *what to
say* when a backend answers rubbish is itself a user-visible sentence (see rule
debt `1245_B3_window_wording`):

1. Wrap the per-value `foreach {p v}` in the same `catch` `_rowdevs` already has,
   so (b) cannot raise.
2. Give a malformed answer its **own sentence** — something that names the
   backend and says its answer could not be read — instead of letting (a) and (b)
   fall into the fifth silence, which is a claim about the *raw*.
3. Make the blank footnote per-row, or render a value-less/empty-string pair
   distinguishably from an absent column, closing (c) and §3.
4. Collapse or escape a newline in a value, closing (d).

## 5. Still open

All of the above. **Item B5** is the first item that will drive `::rdw::sim` and
therefore the first that can reach a second backend at all; **whoever adds the
second backend** is the one who makes every shape here live.

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03. All four shapes, plus the two the adversary did not report, plus §3.)


Ruling **D-5** records that the user **is building a custom ngspice** that will
supply a wildcard operating-point save, and this seam exists precisely to admit
it — so the first backend to hand this window an unexpected shape will be the
user's own. Every shape below was reproduced before it was fixed.

## What landed (`src/rdw.tcl`)

1. **`rdw::_answer_flaw {ans}`** — one verdict, taken **once, before anything
   walks the answer**, so the renderer stays pure rather than growing a `catch`
   per use. It validates the `devices` dict, every device's pair list, every
   pair, and the `absent` / `nonfinite` buckets and their entries (an entry of
   fewer than two fields would render a device sub-header with an empty
   parameter name — a blank row that means nothing). Helper `rdw::_wellformed`.
2. **`rdw::_flaw_line {sim}`** — a flawed answer gets its **own** sentence,
   **naming the backend**, because the remedy is there and not in the run. So
   `dump_devpath` now `dict set`s the resolved backend into `ctx`, and the
   suite's `rw_ctx` gained an optional fifth `sim` argument (defaulted, so no
   existing caller moved).
3. **`rdw::_value_text {v}`** — a value-less pair or an empty-string value now
   renders `(no value reported)`: **words**, in the same family as
   `(did not converge)`, never a number and never a bare blank.
4. **`rdw::_oneline {s}`** — `\n`, `\r` and `\t` collapse to one space in every
   parameter name, every value and every device sub-header, so one pair is one
   line and `block_text` and `render_pane` cannot disagree about how many lines
   a block has.

## The shapes, and what each did before

| shape | before | after |
|---|---|---|
| (a) malformed `devices` value | the **fifth silence** — *"This run's raw holds no operating-point columns for `<dp>`"*, a statement about the RAW and **false**; the same wrong-answer-wearing-a-healthy-state that returned B1 `[F]` | its own sentence, naming the backend |
| (b) malformed per-device **value** | **UNCAUGHT RAISE** out of the pure renderer every suite row and every widget path calls | a block, with the flaw sentence |
| (b′) malformed **`absent`** bucket | **UNCAUGHT RAISE** — *measured while planning B2a, not in this issue* | ditto |
| (b″) malformed **`nonfinite`** bucket | **UNCAUGHT RAISE** — *ditto* | ditto |
| (c) value-less pair | byte-identical to an ABSENT column, and with **no** footnote | `(no value reported)`, textually distinct |
| §3 empty-string value | inherited the per-block blank footnote, which is **false** about it | same — it is no longer a blank at all |
| (d) newline / CR / tab in a value, a param name or a **device name** | one pair became two lines, the second unindented and untagged | one space, one line |

**Rendering (c) and §3 as words closes both in one move** and leaves row `F5`'s
*"the footnote rides exactly once"* golden exactly where it is. **Rejected:
making the footnote per-row** — it moves F5 and repeats a sentence on every
blank row.

## Red before green

| row | red on |
|---|---|
| `F17` | rendered the fifth silence |
| `F18` | `RAISED: unmatched open brace in list`, **three times** |
| `F19` | two blanks indistinguishable from the absent one, footnote false about them |
| `F20` | **9** lines for a 7-entry block, one of them unindented and untagged |

Sabotage, with the fix in place:

* `SB-TRUST-THE-ANSWER` (`_answer_flaw` → `0`) → **F17, F18 red**, `2 FAILED (41 passed)`.
* `SB-BLANK-IS-BLANK` (`_value_text` → identity) → **F19, F20 red**, `2 FAILED (41 passed)`.
* `SB-NO-ONELINE` (`_oneline` → identity) → **F20 red**, `1 FAILED (42 passed)`.

## ⚠ Why this was reverted — THE FIX IS A REGRESSION AGAINST HEAD, IN THIS ISSUE'S OWN CLASS

Found by the adversary pass and **reproduced by the write-up agent** 2026-09-03,
running HEAD's `rdw.tcl` and the attempt's `rdw.tcl` side by side under plain
`tclsh` — `format_answer` is pure, so no xschem is needed.

`rdw::_answer_flaw` returns 1 whenever `dict get $ans devices` **raises**, which
it does when the `devices` key is simply **absent** — and it runs at
`format_answer`'s top, *before* the state check. So a third-party backend that
answers a refusal minimally (`{state no_raw}`) — the natural spelling, since a
refusal genuinely has no devices — gets this:

```
===== HEAD =====
no_raw      => No simulation results are loaded. Run a simulation, or load a raw file, then ask again.
not_op      => The loaded results are a op analysis, not an operating point. Nothing was read from them: ...
no_devpath  =>  has no operating-point descriptor, so there is no device path to ask about. ...
===== WORKING TREE (the attempted fix) =====
no_raw      => The ngspice operating-point reader answered in a shape this window could not read, ...
not_op      => The ngspice operating-point reader answered in a shape this window could not read, ...
no_devpath  => The ngspice operating-point reader answered in a shape this window could not read, ...
```

**Three correct, actionable sentences replaced by one false accusation against
the backend.** The fix written to stop the window lying introduces a new lie, in
the very reachability class this issue exists for: unreachable through the
shipped ngspice backend (which always populates all five keys, even on refusal
— `src/ase.tcl:8781`), reachable by any third-party backend. **Ruling D-5
records that the first such backend will be the user's own custom ngspice.**

The asymmetry proves it is a bug and not a policy: `_answer_flaw` **tolerates** a
missing `absent` and a missing `nonfinite` (it `catch`es both) and rejects only a
missing `devices`, while `_state_sentence`'s four non-`ok` arms need none of the
three.

**What the next crew must do.** Take the state verdict **first** and only run
`_answer_flaw` on the `ok` path — a refusal answer has nothing to validate — or
treat an absent `devices` key exactly as it already treats an absent `absent`
and `nonfinite`: an empty bucket, not a flaw. Then add the acceptance row that
would have caught it: **a refusal answer carrying ONLY `state`** must render its
own state sentence. The suite could not see this because its `rw_ansd` helper
*always* constructs all five keys, so no row can express a devices-less answer.

## Still open — two lies the fix did not close (adversary-measured)

* A `nonfinite` entry carrying only `{dev param}` passes `_answer_flaw` and
  renders `(did not converge)` on **no evidence** — `_nonfinite_text` discards
  its argument entirely.
* A `devices` pair `{{} 1.5}` renders `     : 1.5`, a value belonging to no
  parameter — the exact shape `_answer_flaw` rejects for `absent`/`nonfinite` by
  its own comment ("a blank row that means nothing") and does not test for
  `devices`.

---

## Item B2a-2 — FIX WRITTEN AND SURVIVED A 22-SHAPE ADVERSARIAL MATRIX, then reverted as collateral, 2026-09-03

**This is the one of B2a's three refuted fixes that B2a-2 got right, and the
adversary could not break it.** Recorded in detail because the third crew should
apply it unchanged.

### The regression B2a introduced, reproduced before the fix

B2a's `_answer_flaw` treated an **absent** `devices` key as malformed *and* ran
**before** the state check, so a legal minimal refusal produced a false
accusation. The Measure agent's transcript, and note the blast radius is **all
four** non-`ok` states, not just `no_raw` as first reported:

```
head |    >>> No simulation results are loaded. Run a simulation, or load a raw file, then ask again.
pat  |    >>> The ngspice operating-point reader answered in a shape this window could not read...
pat  | ans <state not_annotated> / <state not_op> / <state no_devpath> -> ALL THREE render the SAME accusation
```

### The fix

A new `rdw::_answer_state {ans}` returning `{hasstate state}`, called **first**,
with three arms in this order: (a) no readable `state` — including an `ans` that
is not a dict at all — is itself a malformed answer and gets `_flaw_line`;
(b) `state ne ok` returns `_state_sentence` immediately with **no shape check of
any kind**; (c) only under `state ok` is `_answer_flaw` consulted. `_answer_flaw`
was narrowed at the same time so every bucket is guarded by `dict exists`
(measured safe on a malformed dict: returns 0, never raises), making an
**absent** `devices`/`absent`/`nonfinite` **empty, not malformed**.

**Both halves are needed.** Reordering alone leaves a legal `{state ok …}`
unvalidated in the wrong direction; narrowing alone still lets `{state no_raw}`
reach `_flaw_line`. Rows **F21**–**F26** cover both, and **F26** is structural —
it reads `format_answer`'s own body and asserts `_answer_state` appears before
`_answer_flaw`, so a later edit cannot silently restore the order.

### The adversary's verdict

A 22-shape state/shape matrix found **no counterexample**: all four legal
minimal refusals render their own correct sentence and none names the backend;
a refusal carrying a *malformed data key* still renders its state sentence;
`{state ok}` with every bucket absent renders the fifth silence;
present-but-un-walkable `devices`/`absent`/`nonfinite`, a 1-element `absent`
entry, an odd-length `devices`, a no-state answer and a non-dict answer all
reach the flaw line; `{state weird}`/`{state {}}`/`{state OK}` get the
unknown-state sentence; **no raise on any shape**.

**Apply it unchanged** from
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch`. The item was
reverted for **1277**, **1281** and **1285**; nothing here was refuted.

### One cosmetic defect noticed and not fixed

`_state_sentence` renders *"a op analysis"* for simtype `op` (article
agreement). Pre-existing at HEAD, not in the reverted diff.

---

# Fixed by item B2d, 2026-09-04

**Files:** `src/rdw.tcl`, `tests/headless/test_rdw_window_1245.tcl`.
Pure Tcl, no build, no `Makefile.in` (`grep -c rdw.tcl src/Makefile` = 2 before
and after).

## What was measured BEFORE, verbatim

The four filed shapes, driven through `rdw::block_text [rdw::format_answer …]`
on HEAD `21fcece6`:

```
--- (a) devices malformed at the DICT level
M1:/
@m.x1.m1
This run's raw holds no operating-point columns for @m.x1.m1. Only parameters the deck explicitly saved appear here.
--- (b) devices malformed at the VALUE level
RAISED: unmatched open brace in list
--- (b-prime) malformed ABSENT bucket
RAISED: unmatched open brace in list
--- (b-dprime) malformed NONFINITE bucket
RAISED: unmatched open brace in list
--- (c) a value-less pair
    id :
--- (d) a newline inside a value
    id : 1.5
INJECTED
```

and §5's two, which the preserved B2a-2 fix leaves open:

```
--- a NONFINITE entry with only {dev param} - no text at all
    id : (did not converge)
--- a DEVICES pair with an EMPTY parameter name {{} 1.5}
     : 1.5
```

**And a SIXTH, found by B2d's adversary AFTER the fix was in the tree** — the
one that refuted the item's central claim on the first pass:

```
state = "weird\n    id  : 1.11e-05\n    vth : 0.45", every bucket EMPTY
  -> 4 block entries, 5 lines of block_text, 7 lines in the Tk pane on :99
M1:/
@m.x1.m1
The operating-point reader answered with a state this window does not know: 'weird
    id  : 1.11e-05
    vth : 0.45'.
```

Two correctly indented, correctly formatted operating-point rows that **no
bucket ever carried**, on the clipboard, indistinguishable from measured ones.

## What it renders now

```
--- 1284a / 1284b / 1284b-prime / 1284b-dprime / §5's two
M1:/
@m.x1.m1
The zzsim operating-point reader answered in a shape this window could not read, so nothing is shown for this device. This is a fault in that reader's answer, not a statement about the run.
--- 1284c
    id : (no value reported)
--- 1284d
    id : 1.5 INJECTED
--- the state key as a line injector
The operating-point reader answered with a state this window does not know: 'weird     id  : 1.11e-05     vth : 0.45'.
```

**Nothing raises**, and the four legal minimal refusals are untouched and still
name nobody:

```
--- {state no_raw}       No simulation results are loaded. Run a simulation, or load a raw file, then ask again.
--- {state not_op}       The loaded results are a op analysis, not an operating point. …
--- {state no_devpath}   M1 has no operating-point descriptor, …
--- {state not_annotated} Operating-point results are loaded but nothing has been published from them yet. …
```

(`a op analysis` is issue **1297**, filed and deliberately not fixed here.)

## The decisions, with the rung and the rejected alternative

* **L1 / invariant I3 — lift the preserved B2a-2 hunks verbatim and do NOT
  re-derive the flaw the brief named.** The brief's *"`_answer_flaw` treats an
  ABSENT `devices` key as malformed AND runs BEFORE the state check"* is true of
  **B2a's** patch and **false of B2a-2's**, whose `_answer_flaw` guards every
  bucket with `dict exists` and whose `format_answer` calls `_answer_state`
  first. Measured on a patched mirror before writing a line. *Rejected:* writing
  the state-first ordering fresh from the brief's prose — the one move that
  could have restored the refuted order.
* **L1 / invariant I3 — close §5's two holes as FLAWS, not as tolerated
  renders.** This issue's ACCEPT row says *"1284 FIXED"*. *Rejected:* rendering
  a text-less nonfinite as `(no value reported)` and a nameless pair under a
  placeholder — a partial predicate is the redesign B2a's revert warns against,
  and a placeholder invents data the backend never sent.
* **L2 — two NAMED one-line predicates**, `rdw::_bucket_width` (3 for
  `nonfinite`, 2 for `absent` — the shared `llength $e < 2` gate was the bug)
  and `rdw::_named` (a `string trim`-non-empty test on the pair's own first
  field and a bucket entry's second). *Rejected:* inline literals, which cannot
  be sabotage-proved and would leave `SB-TRUST-THE-ANSWER` — five rows at once —
  as their only witness. `_named` keys on the NAME never on arity, or F19's
  value-less `{id}` reds.
* **L1 / invariant I3 read one step further — the sixth shape is closed at the
  EMIT POINT, not at the sentence.** `rdw::_line {tag text}` wraps every line
  this file appends to a block. *Rejected:* wrapping each interpolated fragment
  separately — nine edits, and a tenth site the next author forgets; the
  measured escapes were in `_state_sentence`'s echo, `_flaw_line`'s backend
  name, the `dim` device-path line, the fifth silence's `$dp`, the `no_devpath`
  instance name and `dump_devpath`'s `"could not answer: $ans"`, which
  interpolates a caught Tcl error and is multi-line by nature.

## The sabotage matrix (`--nogui`, against 52 checks)

| variant | predicted | observed |
|---|---|---|
| `_answer_flaw` → 0 | F17 F18 F24 F27 F28 | **as predicted** |
| `_bucket_width` → 2 | F27 alone | **as predicted** |
| `_named` → 1 | F28 alone | **as predicted** |
| `_value_text` → identity | F19 **F20** | **F19 only** — see below |
| `_oneline` → identity | F20 | F20 **F29** |
| `_line` → `[list $tag $text]` | F20 F29 | **as predicted** |
| flaw check hoisted above the state check | F22 F26 | **as predicted** |
| B2a's unguarded `devices` arm restored | F23 alone (F21/F22 survive) | **as predicted** |

**One predicted red did not appear, and the reason is the fix.** Before
`_line`, a newline in a VALUE reached the block only through `_value_text`, so
neutralising that proc broke F20's line count. Now the value is one-lined twice
— once for the column-width computation, once at the emit point — so
`_value_text` → identity reds F19 (the `(no value reported)` words) and F20
stays green. F20's newline half is still fenced, by `_oneline` and by `_line`.
Defence in depth, recorded rather than quietly enjoyed.

## Still open

* **1299** — four edges of the same predicate: a device that names nothing,
  `_nonfinite_text` still discarding its argument, minimum-arity truncation, and
  `_named`'s `string trim` disagreeing with `ase::op_param_split`'s exact-empty.
* **1297** — `"a op analysis"`, the article, in the `not_op` arm.
* The flaw verdict is **whole-answer**: one bad entry withholds every device in
  the block while the sentence says *"this device"*, singular. Consistent with
  §4 item 2 as written; the wording under-states what was withheld (in 1299 §2).
