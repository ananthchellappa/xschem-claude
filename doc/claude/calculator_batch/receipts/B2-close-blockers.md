# Receipt B2 — closing Stage B's eleven findings (C1–C11)

Stage label `B2-close-blockers`. Branch `fluid-editing`, tree at `493fa053`, **nothing
committed, pushed or stashed**. All scratch under `…/scratchpad/B2-close-blockers/`.

Two files changed: `src/calculator.tcl` and `tests/headless/test_calc_buffer.tcl`.
**I did not touch Stage B's receipt, `test_calc_skeleton.tcl`, `test_calc_widgets.tcl`,
`tests/run_regression.tcl`, `PLAN.md`, `LEDGER.md` or the spec.**

`test_calc_buffer` went **73 → 109 checks** on the display arm. Both blocking bugs were
real and are fixed; both were observed failing first. Three of the eleven items could not
have a red (they fence a *plausible wrong implementation*, not a present defect) and that
is stated per item below with the sabotage that stands in for it.

---

## 0. The verdicts, both arms

| suite | display arm | headless arm | before this stage |
|---|---|---|---|
| `test_calc_buffer` | `RESULT: ALL PASS (109 checks)` | `SKIP … (self-skipped: no X — nothing ran)` | 73 / same skip |
| `test_calc_skeleton` | `RESULT: ALL PASS (546 checks)` | `RESULT: ALL PASS (0 checks)` | 546 / 0 |
| `test_calc_widgets` | `RESULT: ALL PASS (246 checks)` | `SKIP … (self-skipped: no X)` | 246 / skip |
| `test_registered_banner_1626` | `RESULT: ALL PASS (10 checks)` | `RESULT: ALL PASS (10 checks)` | 10 / 10 |

Through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`, display arm
attached to the persistent dev display `:99`, left exactly as found (`status` only, never
`start`/`stop`/`view`). `RESULT: 4/4 runs passed` and `RESULT: 2/2 runs passed (2 skipped)`.

**The two siblings' counts did NOT move**, and that is the point: `src/calculator.tcl`
changed under them and neither suite's claims needed restating.

---

## 1. What I changed, by symbol

### `src/calculator.tcl`

| symbol | what changed and why |
|---|---|
| **`calc::has_win {w}` (NEW)** | R508's three cases in one place. `[info commands winfo] eq {}` first, then `winfo exists $w`. Every phase-2 entry point now asks this; so does `calc::status`, whose inline copy it replaces, so there is exactly one site that knows the rule. **C2.** |
| **`calc::engine_wsp` (NEW namespace variable)** | `" \t\n"` — the netlist engine's own delimiter set, declared once. **C1.** |
| **`calc::engine_space {ch}` (NEW)** | "is this one character already a separator *to the engine*?" Membership of `engine_wsp`, and **0 for the empty string**. Replaces `string is space`. **C1.** |
| **`calc::token_sep`** | asks `calc::engine_space` instead of `string is space`. Both `ne {}` guards are now load-bearing; the comment that described them as needed-for-the-wrong-reason is replaced by one that says why they are alive now and that they were dead before. **C1, C9.** |
| **`calc::buf_insert_token`** | after the insert, if the caret ended up inside a live selection, the `sel` tag is dropped — Tk's `tk::TextInsert` would otherwise delete that selection on the next keystroke. The predicate is re-evaluated *after* the insert, so a selection the caret has moved past survives. **C8.** |
| **`calc::buf_undo`** | brackets `edit undo` with `edit separator` when `-autoseparators` is on, exactly as Tk's own `<<Undo>>` class script does. Needed because C6 routes Ctrl+Z here and `break`s that class script; without it the keyboard route would have lost a protection it had. |
| **`calc::build_buf`** | `<<Undo>>`/`<<Redo>>` now bind to `calc::buf_undo`/`calc::buf_redo` with `break`. The four text-entry virtual events stay on the silent `calc::buf_typed`. **C6.** |
| **`calc::close`** | clears `fbundo`/`fbredo`, beside the `statusmsg`/`statushist` it already cleared. `editcan` is deliberately **not** cleared (it measures the interpreter, not the window). **C7.** |
| **`calc::status`** | its inline `info commands winfo` guard now goes through `calc::has_win`. Behaviour identical; fenced by row `S13` of `test_calc_skeleton`, which is green. |
| comments only | the SAB-D count dropped for a shape (**C5**); the §0 quotation re-attributed (**C10**); the 8.4 half of the guard rationale narrowed to 8.5 (**C11**); `calc::build`→`calc::build_panes` mis-citation fixed; two more counts over the tree's own text dropped (**C5**, found by the audit). |

### `tests/headless/test_calc_buffer.tcl`

New helpers: `wsp_show` (a readable spelling of a whitespace set, so a failing row stays
on one physical line), `engine_src` (locates `save.c` the way `test_calc_widgets` locates
`calculator.tcl`), `shadow_install` / `shadow_remove` (the 8.5-forcing mechanism, now
**one** proc pair used by two bands instead of open-coded once), and `$ph2calls` /
`$ph2procs` — every phase-2 entry point with its arguments, declared once and used by
three rows.

`::bgerror` now prints a line ending `: FAIL`, so a background error is a **counted**
failure rather than one that neither reader echoes. I found that by accident (§6).

New groups and bands: `CB1`'s delimiter-derivation and wide-whitespace bands, `CB1`'s
selection-arming band, `CB2/8.4`'s under-answer pairs and typing leg, `CB2`'s
close/reopen band, `CB3`'s keyboard-route band and binding classification, and **`CB5`**
(R508's `--nogui` case).

---

## 2. The red, verbatim

One capture, `red2.log`, taken with every new row in place and the product unfixed:
**`RESULT: 16 FAILED (93 passed)`**. No `UNEXPECTED ERROR`, no `group … ABORTED`, no
`BGERROR`: the rows **failed**, they did not throw.

```
FAIL: CB1 the class token_sep separates on IS the delimiter string in src/save.c's own my_strtok_r(ntok_ptr, ...) call, read out of that file -> {<sp><tab><nl> NOVAR} (exp {<sp><tab><nl> <sp><tab><nl>}) : FAIL
FAIL: CB1 ...and the empty string is NOT in it, which is what keeps the two emptiness guards in token_sep alive -> {{ERR:invalid command name "calc::engine_space"} {ERR:invalid command name "calc::engine_space"} {ERR:invalid command name "calc::engine_space"}} (exp {0 1 0}) : FAIL
FAIL: CB1 token_sep: the five characters `string is space` accepts and the engine does not (CR VT FF NBSP EN-SPACE) still get a separator, on both sides of the caret -> {5 {pre-CR post-CR pre-VT post-VT pre-FF post-FF pre-NBSP post-NBSP pre-EN-SPACE post-EN-SPACE}} (exp {5 {}}) : FAIL
FAIL: CB1 the ENGINE splits the buffer into exactly two tokens with the operator standing alone, for each of those five characters on both sides of the caret -> {5 {pre-CR:1 post-CR:1 pre-VT:1 post-VT:1 pre-FF:1 post-FF:1 pre-NBSP:1 post-NBSP:1 pre-EN-SPACE:1 post-EN-SPACE:1}} (exp {5 {}}) : FAIL
FAIL: CB1 the keystroke after a press ADDS one character and deletes nothing, for a selection starting at, ending at, or spanning the caret -> {3 {1.7:14->10 1.9:15->8}} (exp {3 {}}) : FAIL
FAIL: CB2 calc::close clears the fallback's two history hints, like the message history it already clears (R705) -> {1 1} (exp {0 0}) : FAIL
FAIL: CB2 a cold sync on a REOPENED window leaves both buttons disabled on the 8.5 fallback (R505's "exactly when their history is empty") -> {0 {} normal normal} (exp {0 {} disabled disabled}) : FAIL
FAIL: CB3 ...and it SPEAKS, so the status line is not left making a false claim (R506) -> {a sentence about the buffer that an undo makes false} (exp {edit undone}) : FAIL
FAIL: CB3 ...and records it, exactly as the button does (R509) -> {a sentence about the buffer that an undo makes false} (exp {edit undone}) : FAIL
FAIL: CB3 <<Redo>> re-applies one step and speaks -> {{v(out) + *} {}} (exp {{v(out) + *} {edit redone}}) : FAIL
FAIL: CB3 a REFUSED <<Undo>> speaks too, and raises nothing into the event loop -> {{} {}} (exp {{} {nothing to undo}}) : FAIL
FAIL: CB3 the six editing virtual events, classified off their live bindings: undo and redo reach the operation procs that speak, the four text-entry ones reach the silent handler -> {<<Undo>>=typing <<Redo>>=typing <<Paste>>=typing <<Cut>>=typing <<Clear>>=typing <<PasteSelection>>=typing} (exp {<<Undo>>=operation <<Redo>>=operation <<Paste>>=typing <<Cut>>=typing <<Clear>>=typing <<PasteSelection>>=typing}) : FAIL
FAIL: CB4 no phase-2 entry point raises with no window (R508's first two cases: never built, and closed) -> {1 {{calc::engine_space:ERR:invalid command name "calc::engine_space"}}} (exp {1 {}}) : FAIL
FAIL: CB5 no phase-2 entry point raises when the `winfo` command does not exist (R508's --nogui case) -> {1 {{calc::engine_space:ERR:…} {calc::buf_can:ERR:invalid command name "winfo"} {calc::buf_can:ERR:invalid command name "winfo"} {calc::buf_sync:ERR:invalid command name "winfo"} {calc::buf_note_edit:ERR:invalid command name "winfo"} {calc::buf_typed:ERR:invalid command name "winfo"} {calc::buf_insert_token:ERR:invalid command name "winfo"} {calc::pad_click:ERR:invalid command name "winfo"} {calc::clr_buf:ERR:invalid command name "winfo"} {calc::buf_undo:ERR:invalid command name "winfo"} {calc::buf_redo:ERR:invalid command name "winfo"}}} (exp {1 {}}) : FAIL
FAIL: CB5 no phase-2 proc names `winfo` itself — they all ask the one guarded helper, so R508's third case cannot be forgotten in one of them -> {1 {calc::engine_space:NO-BODY calc::edit_can_probe calc::buf_can calc::buf_sync calc::buf_typed calc::buf_insert_token calc::pad_click calc::clr_buf calc::buf_undo calc::buf_redo}} (exp {1 {}}) : FAIL
FAIL: CB5 ...and the helper exists and is the one that asks `info commands winfo` -> {0 0} (exp {1 1}) : FAIL
```

**Four of those reds are the two blocking bugs stated in the product's own voice:**

* `pre-CR:1 post-CR:1 …` — the engine saw **ONE** token where two were intended, for all
  five characters, on both sides of the caret. That is C1, reproduced through the real
  widget and the real split.
* `1.7:14->10` and `1.9:15->8` — a single keystroke after a press **deleted four and
  seven characters**. That is C8, and it is text the user never asked to lose.
* the eleven `invalid command name "winfo"` entries — that is C2, and every phase-2 entry
  point was in it.

### C2 also has a red taken OUTSIDE the suite, under a real `--nogui`

The suite forces the condition by renaming `::winfo` away (row `S13`'s own mechanism). To
be sure that is not an artefact of the mechanism, I ran the same thirteen calls from a
scratch script under the real binary with `--nogui`, where Tk is genuinely not loaded.
**`calc::` procs do exist on that path** (92 of them), so R508's third case is reachable
in the shipped product:

```
P: winfo command = {}
P: calc procs = 92
P: steps=15 raised={{calc::edit_can_probe:invalid command name "winfo"} {calc::buf_can:…}
   {calc::buf_can:…} {calc::buf_sync:…} {calc::buf_note_edit:…} {calc::buf_typed:…}
   {calc::buf_insert_token:…} {calc::pad_click:…} {calc::clr_buf:…} {calc::buf_undo:…}
   {calc::buf_redo:…} {calc::status:…} {calc::has_win:…}}
```

and after the fix, same command, same binary:

```
P: winfo command = {}
P: calc procs = 92
P: steps=15 raised={}
P: statusmsg={} hist={}
```

⚠ **Honest qualification of that first capture.** I reproduced the pre-fix guard by
reverting `calc::has_win` to the bare `winfo exists` with a one-line sabotage, because the
nine bare guards were already gone from the tree by then. That sabotage *also* breaks
`calc::status`, which was correct before this stage — so `calc::status` and
`calc::has_win` appear in that raiser list and **should not be read as pre-existing
defects**. The eleven phase-2 entries are the real ones.

---

## 3. Item by item

### C1 — BLOCKING, REAL BUG: `token_sep`'s class was wider than the engine's. FIXED.

**Measured first**, in `tclsh` 8.6.17: `string is space` answers **1** for CR (U+000D),
VT (U+000B), FF (U+000C), NBSP (U+00A0) and EN-SPACE (U+2002), and the engine's call site
is `my_strtok_r(ntok_ptr, " \t\n", "", 0, &ntok_save)` at one line inside
`plot_raw_custom_data()` in `src/save.c` (grepped; the function starts well above it).
Then measured in the live product: `calc::token_sep + "v(out)\r" {}` returned `+` — no
separator at all.

**Fixed by deriving rather than hardcoding a third copy, as the task asked.** There are
still two copies of the set — the C literal and `calc::engine_wsp` — but they are **locked
to each other by a row** that opens `src/save.c`, pulls the delimiter string out of that
very call with a regexp, un-escapes it and compares it with `engine_wsp`. A drift in
either reddens. I could not make the Tcl side *read* the C side at run time without
making the predicate depend on a file that `make install` does not ship, which would
trade a silent drift for a silent absence; the row is the lock instead, and
`SAB-K` below proves it is one.

Rows: CR, VT, FF, NBSP and EN-SPACE are each driven **on both sides of the caret**, twice:
once as a pure `token_sep` call and once through the real widget, where the assertion is
the **engine-split property** — `engine_tokens` must yield exactly two tokens with the
operator standing alone — not "a space appeared".

**The row name is fixed too, and its method was widened to make the new name true.** The
old `CB1 token_sep: a TAB is whitespace on both sides (the engine's set is " \t\n")`
claimed the predicate matched the engine's set, which it did not. It is now
`CB1 token_sep: a TAB before and after the caret adds nothing` — exactly its method — and
the class claim lives in two rows that measure it. The five-character row's name says
"the five characters `string is space` accepts and the engine does not", so the loop now
**measures both of those legs** (`string is space $ch` must be 1, `calc::engine_space $ch`
must be 0) alongside the two separator legs.

### C2 — BLOCKING, REAL BUG: R508's third case threw. FIXED.

Red above, twice, including under a real `--nogui`. Fixed with `calc::has_win`, which
follows `calc::status`'s existing idiom rather than inventing a second one — and
`calc::status` now routes through it too, so the rule lives at one site. Three comment
sentences and one row name that asserted R508 compliance are rewritten to say which cases
are measured where: `CB4` is the closed case (which is the same condition the guard sees
as never-built — the row now says that instead of claiming two cases), `CB5` is the
`--nogui` one.

`CB5` also carries a **structural** row over the live proc bodies: no phase-2 proc's body
names `winfo` at all. `SAB-M` (one proc reverted to the bare guard) reddens it by name.

### C3 — BLOCKING: the fallback's typing leg was unfenced. FENCED. ⚠ No red was possible.

The product was already correct here; what was missing was a row. So there is **no red to
quote** — the evidence is `SAB-N`, which deletes exactly what C3 names (the hint update in
`calc::buf_typed`) and now reddens:

```
FAIL: CB2/8.4 TYPING raises BOTH the fallback's hints, so Undo enables from the keyboard and not only from a keypad press -> {disabled disabled} (exp {normal normal}) : FAIL
```

Before this stage that sabotage reddened **nothing**. The row reuses the band's own
shadow mechanism — which is now `shadow_install`/`shadow_remove`, one pair of procs, so
there is still exactly one way to simulate an old Tk in this file.

### C4 — BLOCKING: the fallback's unsafe direction had no row. FENCED. ⚠ No red was possible.

Same situation, same honesty: the hints are correct today, so these rows are green on
arrival. The gap was real and I can name it precisely: the band **never read the REDO
button after a successful undo**, so a `buf_undo` that set `fbredo 0` — an under-answer,
because an undo always leaves something to redo — was invisible. Every row that could have
seen it called `calc::buf_redo` *directly*, which does not consult the hint.

Four pairs now cover it, each pair being the catcher: assert the **button state**, then
immediately prove the history really was non-empty by performing the operation. An
under-answering hint reddens the first row of the pair while the second still passes.
`SAB-O` (the `fbredo 0` under-answer) reddens exactly one row, by name, and `SAB-P`
(`clr_buf` forgetting `buf_note_edit`) another. A fifth row pins the one hint an operation
*does* set to 0, and shows the 0 is **exact**: after an undo then a further insert, the
real widget agrees there is nothing to redo (`{disabled {nothing to redo}}`). Measured
first: `edit canredo` is 1 straight after an undo and 0 after any later insert.

### C5 — BLOCKING: a count in a comment that nothing re-measures. DROPPED, and I found two more.

`calc::buf_sync`'s comment said the SAB-D measurement "reddened 2 rows with the catch in
place and 7 without it". **I re-took that measurement both ways rather than copying either
figure**, and the shape it now states is what I saw, with no number:

* **with** a catch around the two `configure` calls, every row in the forced-8.4 band that
  *performs* an undo or a redo still passes — the operations do not go through `buf_can`,
  so they work while the buttons freeze — and what reddens is the structural row, the row
  that reads the accessor directly, and the rows that read a **button state**;
* **without** it, the error reaches the band: the performing rows redden too, the row
  asserting that nothing raised reddens, and `::bgerror` fires out of the synthesised
  typing.

**The grep for other measurement-digits found two more, both Stage B's, both in
`src/calculator.tcl`**: `calc::build_buf`'s table comment said "these ten rows do not
contain it — the three phase-2 entries here lost their stub" and "the grep shows phase 2
removing ONE site", and the comment above `calc::pad_click`'s old site said "the ONE line
the batch's progress grep lost". All three are counts over the tree's own text with no row
behind them; all are now shapes, and the comment points at `CW13`, which *does* re-measure
how many controls are wired to a landed phase-2 proc.

**What I examined and deliberately kept**, with the reason:

* `62 of 402 checks … hid 340 others` — a *citation* of CREW_BRIEF/CLAUDE.md's dated
  issue-1616 record, attributed in the sentence. Nothing here could re-measure another
  suite's historical run, and CLAUDE.md says dated records keep their figures.
* `R509's whole 50-entry cap` and "crosses fifty entries in a second" — quotations of the
  spec's own R507/R509 text, and `histmax 50` is in the code.
* `Measured on Tk 8.6.17` (three sites) — a version, i.e. the identity of the instrument,
  printable with `info patchlevel`. It makes the measurement reproducible rather than
  standing in for one.
* `-autoseparators 1`, `fbredo 0`, `{0 0}` — option and variable values, not measurements.

### C6 — MINOR, user-visible: Ctrl+Z was silent. FIXED.

**Measured first** in the live product: with `v(out) + *` in the buffer and a status line
showing, `event generate .calc.buf <<Undo>>` left the buffer at `v(out) +` and
`statusmsg` **empty** — the buffer moved and the status line said nothing. The binding was
`after idle calc::buf_typed`.

**I routed the two events to the handlers the buttons use** (the first of the two options
offered), because that makes the keyboard and the button *the same code* by construction
rather than by agreement, which is what "an undo is an operation whichever way it is
invoked" actually means. The alternative — teaching `buf_typed` to distinguish them —
would leave two paths that have to be kept saying the same thing.

Two mechanics I had to measure before trusting the routing:

* `break` in a widget-level binding **does** cancel the Text class binding on Tk 8.6.17
  (probed directly: a widget binding ending in `break` left the buffer unchanged by the
  class script). Without it Ctrl+Z would undo twice — `SAB-R` reddens exactly that row.
* Tk's `<<Undo>>` class script **brackets** `edit undo` with `edit separator` when
  `-autoseparators` is on, and its own comment says why. Cancelling that script would have
  made the keyboard route *weaker* than the one it replaced, so the bracketing moved into
  `calc::buf_undo`, where it now protects the button route as well. Nothing reddened.

**The four remaining editing virtual events stay silent, and that is a decision I am
stating rather than assuming:** a paste, a cut, a clear-selection and a middle-click paste
are text entry, there is no Calculator control for any of them, and a status line per
paste is R507's cap problem again. A row reads all six **live bindings** and classifies
them, so a fifth event wired to the wrong handler is visible without driving it.

**PLAN 2.4's acceptance and the suite's header are both corrected.** PLAN 2.4 says "no
silent mutation path remains"; under the driver's settled reading of R506 that is looser
than the spec, because raw text entry is silent *by design*. The header now says what CB3
measures — every operation speaks **by either route**, and the four text-entry events do
not — instead of implying the literal acceptance line is met. I did not edit `PLAN.md`;
that correction is the driver's to make if they want it.

### C7 — MINOR: `fbundo`/`fbredo` survived `calc::close`. FIXED. ⚠ And it is LATENT, not reachable.

Red above (`{1 1}` where `{0 0}` is wanted, and `normal normal` on a cold sync after a
reopen). The fix is two lines in `calc::close`.

**But the task's framing is stronger than what I could measure, and I am correcting it
rather than repeating it.** "A freshly reopened Calculator shows Undo ENABLED over an
empty history" is not reachable from the shipped UI today. I grepped every caller of
`calc::buf_sync` in `src/`: there are exactly four — `buf_note_edit`, `buf_typed`,
`buf_undo`, `buf_redo` — and **every one writes the hints before syncing**; the two
buttons are created `disabled` in `calc::build_buf`. So nothing in the product reads a
stale hint before something overwrites it. What reads `buf_sync` cold is a **test fixture**
(both sibling suites do `edit reset` + `calc::buf_sync` to arrange an empty history) and
PLAN 4.4, which will sync from the stack side. The state was wrong, the class of state is
exactly the one `calc::close` already clears for `statusmsg`/`statushist`, and the fix
removes a latency rather than curing an observable symptom. Both the row's comment and the
product comment say so.

**The citation is corrected too.** R705's own text is about the *current raw* and stale
vector names. The phrase "nothing stale is resurrected" is the spec's own gloss of R705
**inside R508**, in the sentence "The history is a property of the window: a
closed-and-reopened Calculator starts with an empty one". That is the clause that binds
here, so the row name now cites R508 and the comment quotes it.

### C8 — MINOR: a press left a selection armed. FIXED.

**Measured first**, three caret positions, in the live product:

```
case 1.7 : after-press {v(out) + v(in)} sel {1.9 1.14} insert 1.9  -> after-typing {v(out) + X}
case 1.12: after-press {v(out) v(in) +} sel {1.7 1.12} insert 1.14 -> after-typing {v(out) v(in) +X}
case 1.9 : after-press {v(out) v( + in)} sel {1.7 1.15} insert 1.12 -> after-typing {v(out) X}
```

One keystroke deleted the selected token in two of the three. `tk::TextInsert`'s predicate
is `[llength [$w tag ranges sel]] && [$w compare sel.first <= insert] && [$w compare
sel.last >= insert]` (read out of the live proc body; factored out as
`::tk::TextCursorInSelection` on 8.6).

**I agree with the lens that NOT replacing the selection is right under R501, so the fix
is to the armed state and not to the policy**: after the insert, and only if the caret
ended up inside the selection, the `sel` tag is dropped. Re-evaluating *after* the insert
matters — case 1.12 is armed before the insert and not after it, and dropping that
selection would be a visible change for nothing. The row asserts the **consequence** (a
keystroke adds one character and deletes nothing, across all three caret positions) rather
than a widget state, so it stays a fence if Tk refactors its predicate again.

The selection highlight disappearing on a keypad press is a user-visible choice I made
without a ruling: the alternative keeps the highlight and loses the text, and CLAUDE.md's
standing instruction is to decide this kind of thing and say so. **Said.**

### C9 — MINOR: dead guards and a backwards sentence. MEASURED, then made true.

Both claims verified, and the deadness measured three ways on the real suite:

| what | reds |
|---|---|
| `SAB-J` — predicate back to `string is space` | **3** |
| `SAB-J2` — that, **and** both `ne {}` guards deleted | **3**, the same three |
| `SAB-U` — correct predicate, both guards deleted | **14** |

`J2 == J` is the proof the guards were dead: under `string is space` (which answers 1 for
the empty string) deleting them changed nothing. `U` is the proof they are alive now. So
the remedy was "make the guards do something", which the C1 fix does as a side effect, and
the comment now says that — including that the old sentence's warning about the `post` side
ran the wrong way round (for an empty `post` the caret is at the end of the buffer and
suppressing the trailing separator is the **correct** behaviour, which is what rows
`CB1 token_sep: after a non-space character, exactly one leading space` and
`CB1 token_sep: an EMPTY buffer gets no leading space it does not need` demand).

### C10 — NOTE: the §0 misattribution. FIXED.

Spec §0's heading is **"The single most important fact"**. The sentence "Most of the engine
already exists. Do not write an expression evaluator." is §0's first *line*, not its
heading. The comment now attributes it that way and records the correction.
⚠ **`CREW_BRIEF.md` carries the same error** ("it is the spec's own §0 heading"). I did not
edit the brief — it is the driver's file — so it is recorded here.

### C11 — NOTE: the 8.4 half of the guard rationale. VERIFIED, then narrowed.

`calc::color`'s body is `if {[dict exists $pal $role]} { return [dict get $pal $role] }`,
and `calc::palette`/`calc::color` is on the path of every widget in the window (grepped:
`dict` appears at seventeen lines in the file, `{*}` and `in`-as-expr at none, so `dict` is
the binding constraint). `dict` is a Tcl **8.5** addition, so this file cannot run on 8.4
at all. The sentence now says the guard protects an **8.5** user, keeps the guard, and
records that it previously claimed 8.4 as well.

⚠ **This is the one claim in the stage I verified from documentation rather than by
measurement**: there is no Tcl 8.4 interpreter on this machine to run `dict` against. The
comment says so in a parenthetical. What *is* measured is the `dict` calls and the fact
that every widget goes through `calc::color`.

---

## 4. Sabotages: fifteen, each run against the shipped tree

Each applied to `src/calculator.tcl` alone, suite run on the display arm, file restored
from a checksummed backup and **the md5 verified after every single one**
(`1a4faa381f6e186a41ec075c4d1d5f9c`, unchanged at the end).

| # | the plausible wrong implementation | reds | the rows that caught it |
|---|---|---|---|
| **J** | `engine_space` asks `string is space` — the implementation that was there | 3 | the `engine_space` answers row, the five-character row, the engine-split row |
| **J2** | J **and** both `ne {}` guards deleted | 3 | the same three — which is the C9 measurement |
| **U** | correct predicate, both `ne {}` guards deleted | 14 | seven `CB1` separator rows, the twelve-key sweep, `CB2 Redo re-applies`, three `CB2/8.4` and `CB3` rows |
| **K** | `engine_wsp` set to `" \t\n\r"` — a copy drifting from the engine by one character | 4 | **the `src/save.c` derivation row**, plus the CR legs |
| **L** | `has_win` written as the bare `winfo exists` — what the nine procs had | 2 | `CB5` behavioural + `CB5 …the helper … asks info commands winfo` |
| **M** | one proc (`clr_buf`) left on the bare guard | 2 | `CB5` behavioural (names `calc::clr_buf`) + `CB5` structural (names it too) |
| **N** | the hint update deleted from `buf_typed` — **C3's own sabotage** | 1 | `CB2/8.4 TYPING raises BOTH the fallback's hints` |
| **O** | `buf_undo` sets `fbredo 0` on success — the under-answer | 1 | `CB2/8.4 ...and that undo enables the REDO button` |
| **P** | `clr_buf` forgets `buf_note_edit` | 1 | `CB2/8.4 ClrBuf enables Undo through the fallback's hint` |
| **Q** | `<<Undo>>`/`<<Redo>>` left on the silent typing handler — what the tree had | 5 | four `CB3` keyboard rows + the binding-classification row |
| **R** | routed to the operation procs but **without `break`** | 1 | `CB3 <<Undo>> undoes exactly ONE step` (got `v(out)`: it undid twice) |
| **S** | `close` does not clear the hints — what the tree had | 2 | both `CB2` close/reopen rows |
| **T** | the selection disarm removed — what the tree had | 1 | `CB1 the keystroke after a press ADDS one character and deletes nothing` |
| **D** | `buf_can` with no probe and no catch — the version a reasonable person writes on this machine | 19 | 15 rows **plus 4 `BGERROR`s** (see §6) |
| **D2** | D **and** a catch restored around `buf_sync`'s two `configure` calls | 5 | the structural row, the accessor row, three button-state rows — and **every performing row still passed** |

`D` vs `D2` is the re-measurement that replaced C5's quoted count, and the new rows made
that sabotage markedly more visible: with the catch in place it now reddens the three
button-state rows, where before this stage it reddened two rows in total.

---

## 5. The trailer delta — derived, not predicted

Method: capture the case exactly as T1's `dcases` arm does (`--pipe -q` on `:99`, stdout
and stderr together, throwaway `HOME`), then **lift `summarize_all` and `t1_carry_line` out
of `tests/run_regression.tcl`'s own text** (a line scan from `^proc <name>` to the first
line that is exactly `}`) and run them over that capture. No figure below is quoted from a
receipt.

```
lifted: t1_carry_line (5 lines)
lifted: summarize_all (89 lines)
blocks=1 counted_failures=0 skips=0 returned=0
--- the block summarize_all wrote ---
headless/test_calc_buffer.disp.log
RESULT: ALL PASS (109 checks)
Total num fail: 0
--- summarize_all's own arms, printed from the LIFTED body ---
>> if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>> } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
>> } elseif { [regexp {^skip:} $line] } {
>> } elseif { [regexp {^RESULT:} $line] } {
>> } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
--- how many lines of the capture each arm matches ---
counted-shape=0  lowercase(^skip:)=0  any-case(^skip)=0  ^RESULT:=1  NOGOLD/NODISPLAY=0  capture-lines=115
```

**Relative to the tree as Stage B left it, this stage's delta on every trailer field is
ZERO**: no case is registered or removed, `counted_failures` contributes 0, and the
`^skip:` arm matches **no** line of my output in either case. The only thing that moves is
the **published check count inside the block Stage B's registration already added**:
`RESULT: ALL PASS (73 checks)` → `RESULT: ALL PASS (109 checks)`. `wc -l` of a full verdict
is therefore unchanged by this stage.

Relative to the driver's committed baseline (`116/115/0/8` at `deccdbd1`, per commit
`493fa053`), the *uncommitted* delta is Stage B's: +1 case, +1 block, +3 lines. I did not
re-derive Stage B's half; §9 of its receipt did, and nothing I changed touches it.

⚠ **This is a derivation over my own suite's output, not a prediction of the trailer.**
CLAUDE.md records four occasions where careful reasoning about registration shape got
`skips=` wrong. **Read the trailer.**

### The registration shape is unchanged, re-checked through the only Tcl reader

```
display: banner_complete=1 banner_died=0 regression_case_failed(0)=0
nogui:   banner_complete=0 banner_died=0 regression_case_failed(0)=1
```

Still `dcases`-only, for the reason Stage B recorded. Issue 1627's shape re-measured on the
real capture: column-0 `RESULT:` **1**, column-0 `OVERALL:` **1**, `^FATAL` 0, `^note:` 0,
`BGERROR` 0, `ok:` lines 109 against a published `RESULT: ALL PASS (109 checks)`.

---

## 6. What I got wrong, and what corrected me

**Five things. The second is the most useful, because it was invisible in both readers.**

1. **Two of my own expected values were wrong on the first red run, and one of them was
   the vacuity trap Stage B had already hit.** `CB1 fixture: a live selection…` compared
   against the literal `{{1.7 1.12} {v(in)}}` where Tcl's own list representation is
   `{1.7 1.12} v(in)` — braces I had typed by hand instead of letting `[list]` build.
   Fixed by building the expected side with `[list]`. Separately, three of my rows had
   `[list [llength $ph2calls] {}]` on the **expected** side while the got side computed the
   same `llength` — a leg that passes however the loop behaved, which is exactly Stage B's
   `[bufget]`-versus-`[bufget]` defect one row over. All three now assert `>= 13` (or
   `>= 12`), which a shrunk or emptied list fails and a later phase's growth does not.

2. **`run_suites.sh` reported fewer failures than the suite had counted, and it took a
   separate run to find out why.** `SAB-D` printed `RESULT: 19 FAILED` with only **15**
   `FAIL:` lines echoed. The missing four were `BGERROR:` lines: the unguarded 8.6-only
   accessor raised out of `<KeyRelease>` during my new synthesised typing, the suite's own
   `::bgerror` counted each one, and **neither reader could see them** —
   `run_suites.sh` echoes `^(FAIL|FATAL)` and `summarize_all` counts lines *ending* in
   `FAIL`. T1 would still have reddened the case through `banner_complete` (no
   `OVERALL: ok` is printed when `$fail` is nonzero), but with the wrong diagnosis.
   `::bgerror` now ends its line in `: FAIL`. **The habit that caught it was reconciling
   two numbers that should have agreed instead of reading the larger one as the answer.**

3. **I wrote a shape sentence for C5 before re-taking the measurement, and it was wrong.**
   My first replacement for the dropped count said that with the catch in place "only the
   two rows that read the accessor directly reddened, and the whole forced-8.4 band went on
   passing". Then I ran `D` and `D2` and found **five** reds with the catch, three of them
   button-state rows my own new pairs had added — so the sentence I had just written to fix
   a stale number was itself stale about its own stage. Rewritten from the run. **This is
   the C5 defect reproducing itself inside the fix for C5**, which is precisely what
   CLAUDE.md records happening three times to one sentence in the 1608 batch.

4. **My first `--nogui` probe failed on its own bug and I nearly read it as a product
   defect.** It reported all fifteen calls raising `bad level "1"` — because a `--script`
   file runs at level 0 and my probe used `uplevel 1`. Switching to `eval` gave the real
   answer. A probe that fails in a way that *resembles* the defect you are hunting is worth
   one extra look: the error string is the tell.

5. **I had to check three citations I would otherwise have copied, and two were wrong.**
   `calc::build`'s optnever/optalways probe is in **`calc::build_panes`**, not
   `calc::build`; and the xschem.tcl precedent is *inside* `load_file_dialog`, not after
   it. Also `full_audit.sh`'s `is_skip` does not "match before `is_pass`" — `is_pass` is
   defined first and **defers** to it (`&& ! is_skip "$out"` in every arm that could match
   this output). All three sentences are now what the tree says. CLAUDE.md's rule about
   citing by symbol is only half the protection; the other half is reading the symbol.

---

## 7. Every claim audited — how I checked each

The stage-A3 walk, over every comment sentence, row name and requirement citation I or
Stage B added to the two files I touched.

### Requirement citations

| citation | how checked | verdict |
|---|---|---|
| R501 "buffer is free text … never rejects keystrokes" | read §8.1 | exact |
| R505 "disabled exactly when their history is empty" | read §8.1 | exact |
| R506 "every operation … silence is a bug" | read §8.1 | exact |
| R507 `record` defaults to 1, hover help passes 0, "crosses fifty entries in a second" | read §8.1 | exact quotations |
| R508 three cases, "silent no-op that returns cleanly", ciw_echo precedent | read §8.1 | exact; the three cases are as quoted |
| R508's window-property sentence (new C7 citation) | read §8.1 | exact quotation |
| R509 50 entries, newest first | read §8.1 | exact |
| R509a / the ex-`R510` collision | read §8.1's own note | exists, dated 2026-09-30 |
| R510 §8.2 binary-operator stack rule | read §8.2 | exists; phase 4.3 |
| **R705** "nothing stale is resurrected" | read R705 **and** R508 | ⚠ **R705's own text is about the current raw and stale vector names.** The phrase is the spec's gloss of R705 *inside R508*. Row name and comments re-cited to R508. |
| R705 in `calc::close`'s pre-existing comment | same | left as Stage B wrote it (it says "the same trap R705 names", which is an analogy, not a quotation) |
| W19 ClrBuf / W22 undo-redo initial `disabled` / W30 operators-only | read §4's table | all three exact |
| R113 (sibling suite) | not mine, not touched | — |
| PLAN 2.2 / 2.3 / 2.4 and their acceptance lines | read PLAN.md's table | exact; 2.4's looseness is now stated |
| PLAN 4.3 / 4.4 | read PLAN.md's table | exact |
| issues 1616 / 1626 / 1627 | 1626 and 1627 issue files exist; 1616's figures are a CREW_BRIEF citation | kept as citations |

### Factual claims about Tk, Tcl and the tree

| claim | how checked |
|---|---|
| `string is space` accepts CR VT FF NBSP EN-SPACE | run in `tclsh` 8.6.17; **and now a row leg** |
| the engine's delimiters are `" \t\n"` | grepped `src/save.c`; the call is inside `plot_raw_custom_data()` (function start grepped too); **and a row reads it out of the file every run** |
| `tk::TextInsert` deletes the selection when the caret is inside it | printed `info body ::tk::TextInsert` |
| the predicate is `tag ranges sel` + two `compare`s, `::tk::TextCursorInSelection` on 8.6 | printed `info body ::tk::TextCursorInSelection` |
| Tk's `<<Undo>>` class script runs `%W edit undo` and brackets it with separators | printed `bind Text <<Undo>>` |
| a widget-level `break` cancels the class binding | probed: bound `{… ; break}`, generated the event, buffer unchanged by the class script |
| `edit canredo` is 1 after an undo, 0 after a later insert | probed on the live widget |
| a bare `edit separator` on an empty stack does not make `edit canundo` true | re-probed (Stage B's claim; three separators, still 0) |
| `edit canundo`/`edit canredo` appear nowhere else in `src/*.tcl` | `grep -l` over `src/*.tcl`: one file |
| `calc::color` uses `dict`, so 8.4 is already impossible | grepped the body; **`dict` → 8.5 is documentation, not measured here** (no 8.4 interpreter) |
| `edit reset` is Tk 8.4+ (Stage B's, in `bufset`'s comment) | **not verifiable here** for the same reason; inherited unchanged |
| `calc::status` asked `info commands winfo` from the start | `git show HEAD:src/calculator.tcl`, and `git log -S` names phase 1a's own commit `c141f765` |
| row `S13` fences the no-`winfo` clause by renaming `::winfo` | read the band |
| only four procs call `calc::buf_sync`, all writing the hints first | grepped every `calc::buf_sync` in `src/` |
| the two buttons are created `disabled` in `calc::build_buf` | read the two `configure` lines |
| both sibling suites do `edit reset` + `calc::buf_sync` cold | read both sites in each |
| `summarize_all` counts lines **ending** in FAIL and lowercase `^skip:` | printed from the **lifted** body |
| `run_suites.sh` echoes only `^(FAIL|FATAL)` | read the line in the script |
| `full_audit.sh`'s `is_pass` defers to `is_skip` | read both procs — ⚠ **corrected a sentence that said "matches BEFORE"** |
| `$XSCHEM_SHAREDIR` is a Tcl global and is `src/` in-tree | printed by the binary at startup |
| `CW13` asserts the live-control count and the pressed count | read both rows |
| `calc::build_panes` holds the optnever probe, copied from inside `load_file_dialog` | ⚠ **corrected**: the comment said `calc::build` |
| spec §0's heading vs its first line | read §0 — ⚠ **corrected** (C10) |

### Row names

All 109 names were read against their methods. Five claimed more than they measured and
were repaired — four by renaming, one by widening the method so the name became true:

* `CB1 token_sep: a TAB is whitespace on both sides (the engine's set is " \t\n")` →
  `a TAB before and after the caret adds nothing` (the class claim moved to the rows that
  measure the class). Same for the NEWLINE row.
* `CB1 the class token_sep separates on IS the delimiter string…` →
  `calc::engine_wsp, which token_sep's predicate reads, IS the delimiter string…`, because
  what the row compares is the variable.
* `CB1 ...and the empty string is NOT in it, which is what keeps…` → names the three
  answers it takes (`0` for empty, `1` for space, `0` for CR) before drawing the
  conclusion.
* `CB1 token_sep: the five characters string is space accepts and the engine does not…` —
  **method widened**: the loop now also asserts `string is space $ch` is 1 and
  `calc::engine_space $ch` is 0, so both halves of the name are measured.
* `CB2/8.4 TYPING raises the fallback's hints` — **method widened** from one button to
  both, because the name says "hints".
* `CB4 … (R508's first two cases: never built, and closed)` →
  `… the CLOSED case, which is the same condition the guard sees as never-built`.
* `CB5 no phase-2 proc names winfo itself — they all ask the one guarded helper` →
  `no phase-2 proc's BODY names winfo at all, so none of them can raise R508's third case
  on its own`, because the regexp measures the absence, not the asking.

Those changes were made **after** a green run and the suite plus the five affected
sabotages were re-run; all still green / still red by name.

---

## 8. What I did NOT do, and why

* **No T1 run.** The driver's job and the brief forbids it. §5 is the unit-level
  substitute for *scoring*, not for *running*.
* **Nothing committed, pushed or stashed.** To take the red I kept the fixed file in scratch
  and restored it by checksum; `git stash` was never used.
* **I did not edit `CREW_BRIEF.md`, `PLAN.md`, `LEDGER.md`, the spec, Stage B's receipt or
  the two sibling suites.** Three corrections belong to the driver and are recorded here
  instead: CREW_BRIEF's own §0 misattribution (C10), PLAN 2.4's acceptance line being
  looser than R506 as read (C6), and `bufset`'s inherited "`edit reset` is Tk 8.4+" claim,
  which I could not verify on this machine.
* **I did not re-litigate "operation vs keystroke".** The driver's reading is settled; C6
  applies it to the invocation route, which is a different question.
* **I did not add separator bracketing to `calc::buf_redo`.** Tk's `<<Redo>>` class script
  does not bracket either (printed: it is a bare `catch { %W edit redo }`), so there is
  nothing to lose by cancelling it. Only `<<Undo>>`'s script brackets, and only `buf_undo`
  gained it.
* **I did not register anything new**, and the registration shape of the one suite I
  touched is unchanged (`dcases` only, re-checked through `banner_complete`).
* **No probe wrote anything.** No `xschem save`/`saveas` anywhere in this stage, nothing
  under `xschem_library/`, `tests/headless/gold/` or any tracked fixture. Every probe ran
  with `HOME` pointed at my own scratch directory, and every suite ran through the armed
  spelling. The dev display `:99` was left as found.
  ⚠ One thing to know for next time: **`devdisplay.sh exec` does not work with an
  overridden `HOME`** — it keeps its state in `~/.claude/xschem_dev_display` and reports
  `:99 is not running`. For a hand probe, `DISPLAY=:99 GUI_GATE=0` with a scratch `HOME`
  is the equivalent (that is what `devdisplay.sh exec` pins) and is what §2's captures used.
* **Nothing was verified by eye, and no `look` debt was incurred.** Every claim is a row, a
  quoted command output, or a predicate lifted from the tree.
* **No `rule` debt filed.** One user-visible choice is mine and unratified: a keypad press
  now **drops the selection highlight** when the caret is inside it (C8). The alternative
  keeps the highlight and silently deletes the text one keystroke later. Nothing is blocked
  on it; if the driver wants it ratified, that is the sentence.
* **No permission prompt denied me anything.**

---

## 9. `git status --short` at the end

```
 M src/calculator.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/receipts/B-buffer-alive.md
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_calc_buffer.tcl
```

Identical to the listing Stage B's receipt ends with, plus this file once it is written.
**Of those, I changed exactly two: `src/calculator.tcl` and
`tests/headless/test_calc_buffer.tcl`.** The other three modified files are Stage B's and I
did not open them for writing; their check counts (546, 246) are unchanged, which is the
independent corroboration. The four untracked entries other than the new suite and the two
receipts were in this session's starting snapshot and are not mine.

---

## 10. What the next stage must know

1. **`calc::has_win` is now the only site in `src/calculator.tcl` that may name `winfo`
   for a phase-2 proc**, and `CB5`'s structural row enforces it over the live bodies. A
   phase-4 proc that needs a window guard adds itself to `$ph2calls` in the suite and calls
   `calc::has_win`. The rest of the file still uses bare `winfo exists` in many places —
   that is out of this stage's scope and the row deliberately covers only the listed procs.
2. **`calc::engine_wsp` is the single declaration of the engine's delimiter set on the Tcl
   side, and a row locks it to `src/save.c`.** Anything later that needs "is this already
   separated?" asks `calc::engine_space`, never `string is space`. `SAB-K` is what notices
   a drift.
3. **R505 is still only HALF done**, exactly as Stage B said. PLAN 4.4 joins the stack's
   history; the five procs it goes through are unchanged, and **the fallback's two hints
   now also get cleared on close**, so 4.4's stack term has to be cleared there too.
4. **The 8.5 fallback's contract now has rows in BOTH directions.** The pairing to copy for
   the stack half is: assert the button state, then immediately perform the operation to
   prove the history was non-empty. An under-answering hint reddens the first and not the
   second.
5. **PLAN 4.3 edits `calc::pad_click`, and `calc::buf_insert_token` now also disarms a
   selection.** If 4.3's stack path bypasses `buf_insert_token`, it must do the same, or
   the C8 defect comes back through the new route. `CB1`'s selection rows drive
   `calc::pad_click`, so they will notice.
6. **`::bgerror` in this suite now prints a counted line.** The two sibling calculator
   suites still print a bare `BGERROR:`, which neither reader sees — worth the same
   one-line change when someone is next in those files. I did not make it, to keep this
   stage's diff to two files.
7. **The status wordings are still unratified** (Stage B's §11.6 list), and `edit undone` /
   `edit redone` / `nothing to undo` now reach the user from the keyboard as well as the
   buttons, which makes them slightly more visible than when that list was written.
8. **Three traps measured here that will cost a later stage a run each.** (a) A `--script`
   file runs at **level 0**, so `uplevel 1` in a probe raises `bad level "1"`. (b)
   `devdisplay.sh exec` needs the real `HOME`. (c) A `foreach` list written in **braces**
   does not process backslash escapes — `{CR \r}` is a backslash and an `r`; use
   `[list CR \r]`.
