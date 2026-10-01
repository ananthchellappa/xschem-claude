# Receipt B — PLAN phase 2, "the buffer comes alive" (steps 2.2, 2.3, 2.4)

Stage label `B-buffer-alive`. Branch `fluid-editing`, tree at `493fa053`, nothing committed.
All scratch under `…/scratchpad/B-buffer-alive/`.

**The four phase-2 call sites are live.** The twelve operator keys insert their token at the
caret, whitespace-separated; `ClrBuf` clears as one undoable action; `Undo`/`Redo` drive the
buffer's own history and are disabled exactly when it is empty; and each of those operations
writes a status line while raw typing writes none.

---

## 1. What I changed, file by file, by symbol

### `src/calculator.tcl`

**New namespace variables** in the `namespace eval calc` block: `editcan` (the cached answer
to "has this Tk got `edit canundo`?", empty = not yet probed), `fbundo` and `fbredo` (the
fallback's two history hints, both 0 on a fresh window).

**New procs**, all defined in one block immediately after `calc::build_buf`:

| symbol | what it is |
|---|---|
| `calc::token_sep {tok pre post}` | the separator decision as a **pure** function of the text either side of the caret. Returns the string to insert. |
| `calc::edit_can_probe` | probes `edit canundo` **once inside a `catch`**, caches the answer in `editcan`. With no window it answers 0 and caches nothing. |
| `calc::buf_can {which}` | "is there anything to undo / redo?" — **the only site in the file that names the two 8.6-only subcommands** on the 8.6 path, and the fallback's two hints otherwise. |
| `calc::buf_sync` | R505's buffer half: sets both buttons' `-state` from `buf_can`. Silent no-op with no window. |
| `calc::buf_note_edit` | an edit *this file* made: `fbundo 1`, `fbredo 0` (our own edit really does clear Tk's redo stack), then sync. |
| `calc::buf_typed` | a keystroke: button state only, **never a status line**. Both hints go up, because a `<KeyRelease>` cannot tell an edit from an arrow key. |
| `calc::buf_insert_token {tok}` | PLAN 2.2: `insert insert` (not `insert end`), bracketed by `edit separator` so one press is one undo step. |
| `calc::clr_buf` | W19 ClrBuf: one undoable action, and it says *which* of "cleared" / "already empty" happened. |
| `calc::buf_undo` / `calc::buf_redo` | W22: a refusal is **reported, not thrown**, and corrects the fallback's hint. |

**Rewritten:** `calc::pad_click` — was `return [calc::inert "operator $tok" 2]`, now inserts
and speaks. It **moved** to the new block, next to the rest of the buffer behaviour.

**Edited:** `calc::build_buf` — the toolbar table grew a **fourth column**, the command. An
empty command still routes through `calc::inert` with the owning phase; `clrbuf`, `undo` and
`redo` now carry `calc::clr_buf` / `calc::buf_undo` / `calc::buf_redo`. The proc also now
binds `.calc.buf` `<KeyRelease>` and the six editing virtual events to `calc::buf_typed`
(with `+`, so nothing existing is displaced; the virtual events through `after idle`, because
their class binding runs *after* a widget-level one).

### `tests/headless/test_calc_buffer.tcl` — NEW, 73 checks on the display arm

Four groups: `CB1` (2.2, caret insertion and the engine's own split), `CB2` (2.3, ClrBuf and
R505's buffer half **including both branches of the Tk-8.6 guard**), `CB3` (2.4, R506 — the
operations speak, raw typing does not), `CB4` (R508 — no window, no throw). Helpers: `check`,
`check_expr` (predicate as a **script**, per the 1616 trap), `pcall`, `group`, `bufget`,
`btnstate`, `nsv`, `nsset` (a *restorer*, never a creator), `bufset`, `engine_tokens`.

### `tests/headless/test_calc_skeleton.tcl` — two bands RESTATED in place, 545 → 546

`S19`'s toolbar sweep and `S22`'s keypad sweep both asserted inertness that phase 2 removes.
Neither band was deleted; both were narrowed and **say so in their own comment**. The one new
row is `S19 fixture: an empty edit history disables undo/redo again (R505)`, which is what
makes the restated `S19 disabled undo/redo do not fire` row's precondition true again; §3
quotes the reds that forced the restatement and §11.3 says what a later phase has to do to
these bands. (An earlier draft of this paragraph pointed at "§5 of the green table below",
which is the sabotage table and does not contain it — a cross-reference to a section that does
not hold what it claims, which is the defect CLAUDE.md records as *five shipped source comments
citing rows that do not exist*. Corrected, and left visible.)

### `tests/headless/test_calc_widgets.tcl` — `CW13` RESTATED in place, 244 → 246

Same treatment, plus two **new positive** rows so the widened allow-list is not a hole.

### `tests/run_regression.tcl`

`"headless/test_calc_buffer"` added to **`dcases`** (23 entries now; 97 registered entries in
total, which row `RB1`'s name re-measures). The calculator comment block above the lists was
extended to name the third suite, to record the `banner_complete` check that was made *before*
registering, and to say that the other two suites' bands were restated and their totals moved.

---

## 2. The red, verbatim

**Every row in the final suite has been observed failing against the unmodified phase-1
`src/calculator.tcl`.** Two captures: `red-display.log`, taken before any product code existed
(41 FAILED / 23 passed), and `red-FINAL.log`, the finished 73-row suite run against
`git show HEAD:src/calculator.tcl` with the phase-2 file set aside and restored by checksum —
**49 FAILED (24 passed)**, and `RESULT: 49 FAILED (24 passed)` with **no** `OVERALL: ok`, so
T1 would have scored it a failure too. No `UNEXPECTED ERROR`, no `group … ABORTED`, no
`BGERROR` in either run: the rows **failed**, they did not throw.

The 24 that pass on the unfixed tree are the fixtures and the "nothing bad is present" rows,
which is why every one of those carries a count or a positive control alongside it.

### Step 2.2 — `CB1`, 16 rows red

```
FAIL: CB1 token_sep: after a non-space character, exactly one leading space -> {ERR:invalid command name "calc::token_sep"} (exp { +}) : FAIL
FAIL: CB1 token_sep: an EMPTY buffer gets no leading space it does not need -> {ERR:invalid command name "calc::token_sep"} (exp {+}) : FAIL
FAIL: CB1 token_sep: a buffer already ending in a space gets no SECOND one -> {ERR:invalid command name "calc::token_sep"} (exp {+}) : FAIL
FAIL: CB1 token_sep: text after the caret gets a trailing space too -> {ERR:invalid command name "calc::token_sep"} (exp { / }) : FAIL
FAIL: CB1 token_sep: a space already after the caret is not doubled -> {ERR:invalid command name "calc::token_sep"} (exp { /}) : FAIL
FAIL: CB1 token_sep: a TAB is whitespace on both sides (the engine's set is " \t\n") -> {ERR:invalid command name "calc::token_sep"} (exp {+}) : FAIL
FAIL: CB1 token_sep: a NEWLINE is whitespace too — the text widget's own line end -> {ERR:invalid command name "calc::token_sep"} (exp {+}) : FAIL
FAIL: CB1 a press with the caret at the end appends the token, separated -> {v(out) v(in)} (exp {v(out) v(in) /}) : FAIL
FAIL: CB1 a press with the caret MID-TEXT inserts THERE, not at the end -> {v(out) v(in)} (exp {v(out) / v(in)}) : FAIL
FAIL: CB1 the caret lands after the token, so a second press chains -> {v(out) v(in)} (exp {v(out) / ** v(in)}) : FAIL
FAIL: CB1 a caret INSIDE a token gets a separator on both sides -> {v(out)v(in)} (exp {v(out) / v(in)}) : FAIL
FAIL: CB1 ...and a second press still chains from there -> {v(out)v(in) v(out)v(in)} (exp {{v(out) / ** v(in)} {v(out) / ** v(in)}}) : FAIL
FAIL: CB1 an empty buffer does not acquire a leading separator -> {} (exp {+}) : FAIL
FAIL: CB1 a buffer already ending in whitespace gets no doubled separator -> {v(out) } (exp {v(out) +}) : FAIL
FAIL: CB1 all twelve keys insert their OWN token through the button -> {12 {k1=v(out) k2=v(out) k3=v(out) k4=v(out) k5=v(out) k6=v(out) k7=v(out) k8=v(out) k9=v(out) k10=v(out) k11=v(out) k12=v(out)}} (exp {12 {}}) : FAIL
FAIL: CB1 the engine's own tokeniser splits one press into two tokens -> {v(out)} (exp {v(out) +}) : FAIL
```

### Step 2.3 — `CB2`, 24 rows red, nine of them in the forced-8.4 band (15 quoted)

```
FAIL: CB2 ClrBuf empties the buffer -> {v(out) v(in) /} (exp {}) : FAIL
FAIL: CB2 ClrBuf is ONE undoable step, so one Undo restores the whole text -> {{ERR:invalid command name "calc::buf_undo"} {v(out) v(in) /}} (exp {{edit undone} {v(out) v(in) /}}) : FAIL
FAIL: CB2 the capability probe answers 1 here, and `edit canundo` really answers -> {{ERR:invalid command name "calc::edit_can_probe"} 1} (exp {1 1}) : FAIL
FAIL: CB2 one keypad press enables Undo and leaves Redo disabled -> {disabled disabled} (exp {normal disabled}) : FAIL
FAIL: CB2 one keypad press undoes in one step -> {{ERR:invalid command name "calc::buf_undo"} v(out)} (exp {{edit undone} v(out)}) : FAIL
FAIL: CB2 at the bottom of the history Undo re-disables and Redo enables -> {disabled disabled} (exp {disabled normal}) : FAIL
FAIL: CB2 Redo re-applies the press -> {{ERR:invalid command name "calc::buf_redo"} v(out)} (exp {{edit redone} {v(out) +}}) : FAIL
FAIL: CB2 after the Redo, Undo is enabled again and Redo is spent -> {disabled disabled} (exp {normal disabled}) : FAIL
FAIL: CB2 a press after an UNSEPARATED edit still undoes alone (`edit separator`) -> {{ERR:invalid command name "calc::buf_undo"} v(out)} (exp {{edit undone} v(out)}) : FAIL
FAIL: CB2 ...and one Undo after a press does not swallow the TYPING with it -> {{ERR:invalid command name "calc::buf_undo"} vout} (exp {{edit undone} vout}) : FAIL
FAIL: CB2 a refused Undo says so rather than throwing -> {ERR:invalid command name "calc::buf_undo"} (exp {nothing to undo}) : FAIL
FAIL: CB2 a refused Redo says so rather than throwing -> {ERR:invalid command name "calc::buf_redo"} (exp {nothing to redo}) : FAIL
FAIL: CB2 typing enables Undo (R505 is about the HISTORY, not about buttons) -> {disabled} (exp {normal}) : FAIL
FAIL: CB2 the 8.6-only subcommands name exactly TWO calc:: proc bodies -- the guarded accessor and the probe that measures them -- and no third -> {1 {}} (exp {1 {::calc::buf_can ::calc::edit_can_probe}}) : FAIL
FAIL: CB2/8.4 calc::buf_can ANSWERS for both directions instead of raising -> {0 0} (exp {1 1}) : FAIL
```

### Step 2.4 — `CB3`, 8 rows red, all of them

```
FAIL: CB3 a keypad press writes a status line naming the operator -> {operator +: not implemented (phase 2)} (exp {operator + inserted}) : FAIL
FAIL: CB3 ...and records it (R507's default record 1) -> {operator +: not implemented (phase 2)} (exp {operator + inserted}) : FAIL
FAIL: CB3 ClrBuf speaks -> {} (exp {buffer cleared}) : FAIL
FAIL: CB3 ClrBuf on an ALREADY EMPTY buffer speaks too, and says which -> {} (exp {buffer already empty}) : FAIL
FAIL: CB3 Undo speaks -> {} (exp {edit undone}) : FAIL
FAIL: CB3 Redo speaks -> {} (exp {edit redone}) : FAIL
FAIL: CB3 a REFUSED Undo speaks too — silence is a bug (R506) -> {} (exp {nothing to undo}) : FAIL
FAIL: CB3 four operations, four history entries, newest first (R509) -> {{operator *: not implemented (phase 2)} {operator +: not implemented (phase 2)}} (exp {{edit undone} {buffer cleared} {operator * inserted} {operator + inserted}}) : FAIL
```

The first two are the most useful red in the stage: the unfixed tree answers
`operator +: not implemented (phase 2)`, i.e. the row is reading the very stub it exists to
replace.

### R508 — `CB4`

```
FAIL: CB4 no phase-2 entry point raises with no window (R508) -> {6 {{calc::clr_buf:ERR:invalid command name "calc::clr_buf"} {calc::buf_undo:ERR:invalid command name "calc::buf_undo"} {calc::buf_redo:ERR:invalid command name "calc::buf_redo"} {calc::buf_sync:ERR:invalid command name "calc::buf_sync"} {calc::edit_can_probe:ERR:invalid command name "calc::edit_can_probe"}}} (exp {6 {}}) : FAIL
```

---

## 3. The green, each arm

Through the armed spelling `tests/headless/run_suites.sh [--nogui] <t>`, display arm attached
to the persistent dev display `:99` (left as found, `GUI_GATE=0`).

| suite | display arm | headless arm | before |
|---|---|---|---|
| `test_calc_buffer` (new) | `RESULT: ALL PASS (73 checks)` | `SKIP … (self-skipped: no X — nothing ran)` | did not exist |
| `test_calc_skeleton` | `RESULT: ALL PASS (546 checks)` | `RESULT: ALL PASS (0 checks)` | 545 display / 0 headless |
| `test_calc_widgets` | `RESULT: ALL PASS (246 checks)` | `SKIP … (self-skipped: no X)` | 244 display / self-skip |
| `test_registered_banner_1626` | `RESULT: ALL PASS (10 checks)` | `RESULT: ALL PASS (10 checks)` | 10 / 10 |

**Both existing suites' counts moved, and I intended it.** `+1` in the skeleton and `+2` in
the inventory are the rows the restatements added; **no row was removed from either**, and
every surviving row's claim is narrower and still true. The restatements were not optional:
on the unrestated tree the two suites reported `5 FAILED (540 passed)` and
`5 FAILED (239 passed)`, and the five reds in each were precisely the inertness claims phase 2
is supposed to falsify — e.g.

```
FAIL: S22 every operator key names itself and its phase (R506) -> {{k1=operator + inserted} … } (exp {}) : FAIL
FAIL: CW13 no control is wired to anything but a phase-1 stub -> {1 {{.calc.btb.clrbuf -> calc::clr_buf} {.calc.btb.undo -> calc::buf_undo} {.calc.btb.redo -> calc::buf_redo}}} (exp {1 {}}) : FAIL
```

Neighbours that read `tests/run_regression.tcl`'s text or scan the tree, run because I edited
it, all `--nogui`: `test_audit_classifier` 75, `test_scratch_home_note` 22,
`test_regression_concurrency_1476` 46, `test_selflog_grep_guard` 390, `test_issue_stamp` 102.
All `ALL PASS`.

---

## 4. The Tk 8.6-only guard, and how BOTH branches are fenced

`edit canundo` / `edit canredo` are 8.6-only and CLAUDE.md targets Tcl/Tk **8.4–8.6**. The
local interpreter is 8.6.17, so a bare call passes every test here and breaks for an 8.4/8.5
user. Nothing else in `src/*.tcl` uses them — the Calculator is the first, so the idiom copied
is the one `calc::build`'s `optnever`/`optalways` already uses for the 8.4-missing `-stretch`
option: **probe once inside a `catch`, keep a defined fallback.**

**The 8.6 branch** is a measurement, not an assumption:

```
ok:   CB2 the capability probe answers 1 here, and `edit canundo` really answers
```

**The 8.4/8.5 branch is forced by SHADOWING the widget command, not by setting a variable.**
`.calc.buf` is renamed to `::cb_real_buf` and a proxy proc installed that raises the error Tk
8.5 itself raises for exactly those two subcommands and forwards everything else; Tk addresses
the widget by its window rather than its command name, so the widget keeps working.
`::calc::editcan` is then cleared so the probe **re-measures**. As far as
`src/calculator.tcl` can tell, it is running on an interpreter that does not have the
subcommand. Why not just pin `::calc::editcan` to 0: that exercises the fallback *arm* but
proves nothing about the probe, and leaves an unguarded call site anywhere else in the path
undetected — which is the shape CLAUDE.md warns about under *"a fence keyed to a symptom dies
quietly"*. The band's own fixtures prove the shadow is real before anything is concluded from
it:

```
ok:   CB2/8.4 fixture: the widget command was shadowed
ok:   CB2/8.4 fixture: the shadow really removes the subcommand
ok:   CB2/8.4 fixture: everything else still reaches the real widget
ok:   CB2/8.4 the probe measures the shadowed interpreter as 0, without raising
ok:   CB2/8.4 calc::buf_can ANSWERS for both directions instead of raising
ok:   CB2/8.4 calc::buf_sync completes without raising
ok:   CB2/8.4 a keypad press still inserts, with the separator
ok:   CB2/8.4 ...and still enables Undo, from the fallback's own history
ok:   CB2/8.4 Undo still works and is still one step
ok:   CB2/8.4 Redo still works
ok:   CB2/8.4 fixture: the conservative hint can be enabled with an empty stack
ok:   CB2/8.4 a refused Undo reports it instead of throwing
ok:   CB2/8.4 ...and SELF-CORRECTS the hint, so it refuses once, not forever
ok:   CB2/8.4 nothing raised anywhere in the band while the subcommand was absent
ok:   CB2 the shadow is gone: the real widget command is back and answers
```

Plus a structural row over the **live** proc bodies (so a mention parked in a comment cannot
satisfy it, and a second real call site cannot hide):

```
ok:   CB2 the 8.6-only subcommands name exactly TWO calc:: proc bodies -- the guarded accessor and the probe that measures them -- and no third
ok:   CB2 the probe catches its own mention, the accessor asks the probe first, and the accessor carries both subcommands
```

**The fallback's declared limit, which is asserted rather than described.** Without the
subcommands Tk's own stack depth cannot be read, so the fallback answers from two hints that
are conservative in **one direction only**: they may say "there is something" when there is
not, never the reverse. What makes that safe is that a refused undo or redo **reports it and
corrects its own hint**, so a button refuses once and then goes disabled — it never refuses
twice in silence. Both halves are the last three `CB2/8.4` rows above. The limit is written
into `calc::buf_can`'s comment block, not only here.

**A safety net outside the group:** if any row inside the shadow band had aborted, the proxy
would have stayed installed and every later group would have been silently measuring a
simulated Tk 8.5 — the 1616 shape in a new costume. An unconditional restore sits after
`group CB2` and prints a `note:` if it ever fires. It does not fire on a green run
(`^note:` lines in the real capture: 0).

---

## 5. What I sabotaged, and what each reddened

Seven plausible wrong implementations, each applied to `src/calculator.tcl` alone, suite run,
then the file restored and the restore **verified by md5** (`7def2001…`, unchanged at the end).

| # | the plausible wrong implementation | rows reddened |
|---|---|---|
| **A** | `.calc.buf insert end $s` instead of `insert insert $s` — append, which is what you write if your only test presses a key with the caret already at the end | **4**: `CB1 a press with the caret MID-TEXT…`, `CB1 the caret lands after the token…`, `CB1 a caret INSIDE a token…`, `CB1 ...and a second press still chains…` |
| **B** | `token_sep` returns the bare `$tok` — no separator at all, the straight concatenation | **14**, including `CB1 the engine's own tokeniser splits one press into two tokens` and `CB1 no token is a fusion of a name and an operator, over all twelve` |
| **C** | `token_sep` returns `" $tok "` — "always separate", the other obvious one | **16**, including `CB1 token_sep: an EMPTY buffer gets no leading space it does not need` and `CB1 a buffer already ending in whitespace gets no doubled separator` |
| **D** | `buf_can` calls `edit canundo`/`edit canredo` with no probe and no catch — the version that passes every test on this machine | **8**: the structural probe/accessor row, both `calc::buf_can ANSWERS` / `calc::buf_sync completes`, `CB2/8.4 Undo still works`, `Redo still works`, `a refused Undo reports it`, `…SELF-CORRECTS…`, `nothing raised anywhere in the band` |
| **E** | no `edit separator` bracketing in `buf_insert_token` — "just insert it" | **2**: `CB2 a press after an UNSEPARATED edit still undoes alone`, `CB2 ...and one Undo after a press does not swallow the TYPING with it` |
| **F** | the refusal path does not clear `fbundo` — the fallback never self-corrects | **1**: `CB2/8.4 ...and SELF-CORRECTS the hint, so it refuses once, not forever` |
| **G** | `calc::status {buffer changed}` added to `buf_typed` — R506 read as PLAN 2.4's looser word "mutation" rather than the spec's "operation" | **2**: `CB3 RAW TYPING writes no status line`, `CB3 RAW TYPING records no history entry` |
| **H** | the four `winfo exists` guards dropped from the entry points — R508 forgotten | **1**: `CB4 no phase-2 entry point raises with no window (R508)` |
| **I** | `buf_note_edit` does not call `buf_sync` — the states never update after an edit | **2**: `CB2 one keypad press enables Undo and leaves Redo disabled`, `CB2/8.4 ...and still enables Undo` |

**SAB-D and SAB-E each exposed a real defect in my own fence and in my own code, before the
sabotage round was over, and both fixes are in the tree.** See §7.

---

## 6. `banner_complete` on the new suite, BEFORE registering it

The check the brief asks for, made in the order it asks for, through the **only Tcl reader**
and over the **real binary's** output on both arms (captured exactly as T1's `exec … 2>@1`
does, with a throwaway `HOME`):

```
display: banner_complete=1 banner_died=0 regression_case_failed(0)=0
nogui:   banner_complete=0 banner_died=0 regression_case_failed(0)=1
```

The predicate, quoted from `tests/banner_rule.tcl`'s `banner_complete`, which
`tests/run_regression.tcl` sources and `run_suites.sh` / `full_audit.sh` do **not**:

```tcl
proc banner_complete {body} {
  return [regexp -line {^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$} $body]
}
```

The suite's display arm ends:

```
OVERALL: ok (73 checks)
RESULT: ALL PASS (73 checks)
```

and its headless arm prints `RESULT: SKIP (no X: the Calculator buffer behaviour is Tk-only)`
and **no banner**, deliberately: it ran nothing. **That asymmetry is the whole reason for
`dcases` only**, and it is the check issue 1626 exists because nobody ran. The suite passes
standalone in `run_suites.sh` either way, which is exactly why that is not the evidence.

**Issue 1627 honoured.** The file has two exit paths and each prints its verdict *instead of*
the other, never as well. Measured on the real capture: column-0 `RESULT:` lines **1**,
column-0 `OVERALL:` lines **1**, death markers **0**, `^FATAL` **0**, and `ok:` lines **73**
against a published `RESULT: ALL PASS (73 checks)`.

### The fence suite after registration

`test_registered_banner_1626` green on both arms at 10 checks. Its own row names re-measured
the new state rather than my asserting it:

* `RB1 every one of the **97** registered entries resolves to a suite file` — was 96.
* `RB6 … Registered suites with the shape, as information and re-measured every run: **3**:
  test_calc_buffer test_calc_skeleton test_calc_widgets` — RB6 **sees** the new suite's
  whole-file no-X gate and correctly treats it as information rather than a failure, because
  it is a `dcases` entry. Had I put it in `hcases`, that is the row that would have reddened.
* `RB2` accepts it (its literal `puts "OVERALL: ok ($npass checks)"`).
* `RB7` names three entries only and is unaffected by a fourth.

---

## 7. What I got wrong, and what corrected me

**Five things. The second and third are the ones that would have shipped a fence measuring
nothing, and both were caught by the sabotage round rather than by review.**

1. **I wrote "one press is one undoable step" as a row that cannot fail.** `bufset` resets the
   edit history immediately before the press, so the press is the *only* entry in it and one
   Undo reverses it whether a separator was written or not. **SAB-E proved it: with both
   `edit separator` calls deleted the suite stayed at `ALL PASS`.** The row's *name* claimed
   the mechanism and its *method* did not test it — exactly CLAUDE.md's "a row's name must
   describe its method". Fixed two ways: the row was renamed to what it measures
   (`one keypad press undoes in one step`), and two new rows were written that **need** the
   separator — a press after an unseparated widget insert, and a press after real synthesised
   typing — because Tk's `-autoseparators` writes a separator only when the *edit mode*
   changes, and typing and a keypad insert are both `insert` mode. SAB-E now reddens both. The
   comment above those rows records the measurement.

2. **I put a `catch` around `buf_sync`'s two `configure` calls, and it swallowed the one
   failure the whole guard exists for.** With the catch in place, SAB-D (the bare 8.6-only
   implementation, i.e. the version a reasonable person writes on this machine) reddened **2**
   rows; without it, **8**. The catch looked like cheap robustness and its real effect was
   that on an 8.4 interpreter undo/redo would silently *freeze* with nothing in any log. Both
   catches are gone — the `winfo exists` guard above them is what makes them unnecessary,
   since both buttons are created in the same loop — and the reason is written at the proc.
   I removed the `catch`es around `edit separator` in the same pass for the same reason:
   `edit separator` is 8.4+, so wrapping it masks rather than guards.
   **The habit that corrected me was running each sabotage and reading how FEW rows it
   reddened**, rather than being satisfied that it reddened something.

3. **My first synthesised typing sent only `<KeyPress>`, and the row then reported a defect in
   code that was correct.** The Text class binding for `<KeyPress>` does the insert, so the
   buffer changed and the row's own fixture passed — but the Calculator's sync hangs off
   `<KeyRelease>`, and `event generate <KeyPress>` does **not** synthesise a release. The row
   printed `CB2 typing enables Undo … -> {disabled} (exp {normal})` against a working tree.
   This is PLAN 6.7's recorded trap (*"a synthesised click alone does not reach the handler"*)
   in its keyboard form, and it cost a green run. Both typing bands now generate both halves,
   and the comment says why.

4. **`set nbody 0` where it should have been `set nbody {}`.** A `lappend` onto an integer
   initialiser, so the "appears in no other proc" leg reported `0` rather than an empty list
   and could never match. Visible in the very first red capture as `{0 0}` against `{2 {}}` —
   found because I read the red output row by row instead of only counting it.

5. **I wrote one fixture row that compared `[bufget]` with `[bufget]`.** `CB2/8.4 fixture:
   everything else still reaches the real widget` evaluated the same reader on both sides of
   the `check`, which is vacuous however the shadow behaves. It now snapshots before the
   insert and compares against `"${pre84}Z"`.

### A correction to the brief, and to the task text

**"Four phase-2 sites should be gone" from `/usr/bin/grep -n "calc::inert"` is not what
happens, and it cannot be.** The grep is a **line** grep, and only one of the four phase-2
sites was ever a line of its own:

* **before**: 14 matching lines (one of them the header comment at the top of the file, one
  the proc definition).
* **after**: 13. The single line that went is `return [calc::inert "operator $tok" 2]`.

`ClrBuf`, `Undo` and `Redo` were **table rows** (`clrbuf {ClrBuf} 2`) dispatched by a shared
`-command [list calc::inert $label $phase]` line that seven still-inert controls also use, so
that line correctly stays. Those three lost their stub by **gaining a fourth column** in
`calc::build_buf`'s table, not by losing a line. I made the table carry the command explicitly
so the state is readable in one place, and wrote the distinction into the table's own comment
with *"Do not read the line count as a control count"*. I also deliberately avoided putting
the literal string `calc::inert` into any new comment of mine, because a comment that mentions
it pollutes the instrument the batch calls its progress bar — the same defect family as
CLAUDE.md's *"a comment must not quote a count a command produces over the tree's own text"*.
Before/after output is in §9.

---

## 8. What I did NOT do, and why

* **No T1 run.** The driver's job, and the brief forbids it. §9's trailer delta is the
  unit-level substitute, derived from `summarize_all`'s own arms — it is a substitute for
  *scoring*, not for *running*.
* **Nothing committed, pushed or stashed.** §10. To take the complete red in §2 I set the
  phase-2 `src/calculator.tcl` aside with `cp` and restored it by checksum; `git stash` was
  not used.
* **R510 is not implemented, on purpose.** Spec §8.2's binary-operator stack rule is PLAN
  4.3, and `?` needs its own three-operand rule (W30 records that the engine's `COND`
  consumes **three**). Phase 2 gives the keys caret insertion only. `S22`'s restated band
  asserts the negative — **no key touched the stack** — so a phase-4 leak reddens.
* **R505 is only HALF done and the receipt says so in its own §1.** Phase 2 owns the
  **buffer** half. The full requirement spans buffer **and** stack as one history and is PLAN
  4.4; the stack model itself is 4.1 and does not exist. `test_calc_buffer`'s header, `CB2`'s
  own comment block and `calc::build_buf`'s amended comment all state this. **Do not read
  R505 as closed.**
* **PLAN 2.1 (the `calc_fixture.raw` test fixture) was not built.** It is phase 2's other row
  and belongs to phase 3's engine work; nothing in 2.2/2.3/2.4 needs a raw file, and this
  stage's brief scoped it to the four `calc::inert` sites.
* **I did not re-litigate "operation vs keystroke".** The driver's reading (the spec's
  "operation" wins over PLAN 2.4's looser "mutation") is implemented, fenced by `CB3`, and
  SAB-G is the sabotage that holds it.
* **I did not touch the earlier receipts, `EYEBALL_SIGNOFF.md`, `PLAN.md`, `LEDGER.md` or
  the spec.** Corrections are in this receipt, per the brief. Two of them are the driver's to
  action: §7's grep correction and §11's open items.
* **Nothing was verified by eye, and no `look` debt was incurred.** Every claim here is a row,
  a quoted command output, or a predicate lifted from the tree. The one thing a test cannot
  settle is whether `operator + inserted` / `buffer cleared` / `edit undone` /
  `nothing to undo` are the **wordings** the user wants on the status line; they follow the
  house style (terse, acronyms uppercase) and are asserted literally by `CB3`, so a change of
  mind is a one-line edit plus the rows that name it. Flagged in §11, **not** filed as a
  `look` — there is nothing to look at, only wording to approve, and nothing is blocked on it.
* **No probe wrote anything.** No `xschem save` / `saveas` anywhere in this stage (grepped:
  none in the new suite), nothing under `xschem_library/`, `tests/headless/gold/` or any
  tracked fixture. The dev display `:99` was left as found (`status` only, never
  `start`/`stop`/`view`).
* **No permission prompt denied me anything.**

---

## 9. The progress bar, and the trailer delta — both derived

### `/usr/bin/grep -n "calc::inert" src/calculator.tcl`

**BEFORE** (14 lines):

```
20:#       routes through calc::inert -> calc::status and changes nothing else.
607:proc calc::inert {what phase} {
1176:    return [calc::inert {Eval} 3]
1385:    return [calc::inert "selector $id: signal picking" 6]
1424:            -command [list calc::inert "pick scope $label" 6]
1435:        -command [list calc::inert {Clip} 6]
1448:            set cmd [list calc::inert $label $phase]
1479:        -command [list calc::inert {Table} 10]
1487:    return [calc::inert "plot destination [.calc.mode.dest get]" 3]
1533:            -command [list calc::inert $label $phase]
1571:            -command [list calc::inert "Stack $label" $phase]
2039:    return [calc::inert "function $name" 5]
2124:            -command [list calc::inert "user $i" 9]
2138:    return [calc::inert "operator $tok" 2]
```

**AFTER** (13 lines):

```
20:#       routes through calc::inert -> calc::status and changes nothing else.
616:proc calc::inert {what phase} {
1185:    return [calc::inert {Eval} 3]
1394:    return [calc::inert "selector $id: signal picking" 6]
1433:            -command [list calc::inert "pick scope $label" 6]
1444:        -command [list calc::inert {Clip} 6]
1457:            set cmd [list calc::inert $label $phase]
1488:        -command [list calc::inert {Table} 10]
1496:    return [calc::inert "plot destination [.calc.mode.dest get]" 3]
1550:        if {$cmd eq {}} { set cmd [list calc::inert $label $phase] }
1838:            -command [list calc::inert "Stack $label" $phase]
2306:    return [calc::inert "function $name" 5]
2391:            -command [list calc::inert "user $i" 9]
```

**One line gone: `2138: return [calc::inert "operator $tok" 2]`. Nothing else moved** — every
other entry is the same site with a shifted line number, and the one textual change is
`1533` → `1550`, where `-command [list calc::inert $label $phase]` became
`if {$cmd eq {}} { set cmd [list calc::inert $label $phase] }`. The other **three** phase-2
sites were the table rows `clrbuf {ClrBuf} 2`, `undo {Undo} 2`, `redo {Redo} 2`, which never
contained the string; they now read `clrbuf {ClrBuf} 2 {calc::clr_buf}`,
`undo {Undo} 2 {calc::buf_undo}`, `redo {Redo} 2 {calc::buf_redo}`.

⚠ **An earlier draft of this sentence said "no `2` is left in that table", and that is
false** — I checked it and the three rows above plainly still read `2`. The `phase` column
names the **owning** phase, which does not change when a phase lands, and it is the argument
the inert fallback passes; the **fourth** column is what says whether it landed. The honest
reading is therefore *"the rows with an EMPTY fourth column carry phases 4, 4, 4, 4, 4, 9, 9"*
— five phase-4 controls (`enter pop swap roll clrstk`) and two phase-9 ones (`mplus me`), and
**no still-inert row carries a 2**. Recorded rather than quietly fixed, because this is the
exact defect CLAUDE.md names under *"a comment must not quote a count a command produces over
the tree's own text"*, arriving in a receipt instead of a comment. See §7 for why the grep
cannot show any of this.

### Trailer delta, re-derived from `summarize_all`'s own arms over real output

Method: capture the new case exactly as T1's `dcases` arm does (`./src/xschem --pipe -q
--nolog --script …` on `:99`, stdout and stderr together), then **lift `summarize_all` and
`t1_carry_line` out of `tests/run_regression.tcl`'s own text** and run them over that capture.
No figure below is quoted from a receipt.

```
blocks=1 counted_failures=0 skips=0
--- the block summarize_all wrote ---
headless/test_calc_buffer
RESULT: ALL PASS (73 checks)
Total num fail: 0
--- summarize_all's own arms, printed from the LIFTED body ---
>>      if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>>      } elseif { [regexp {^skip:} $line] } {
>>      } elseif { [regexp {^RESULT:} $line] } {
>>      } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
```

The same lift over the two restated suites' real captures:

```
headless/test_calc_skeleton   RESULT: ALL PASS (546 checks)   Total num fail: 0
headless/test_calc_widgets    RESULT: ALL PASS (246 checks)   Total num fail: 0
```

And a census of the lines the `skip:` arm actually matches, over all three real captures:

```
test_calc_buffer:   lowercase ^skip: = 0   any-case ^skip = 0
test_calc_skeleton: lowercase ^skip: = 0   any-case ^skip = 0
test_calc_widgets:  lowercase ^skip: = 0   any-case ^skip = 0
```

So, against the driver's stated baseline of `cases=116 blocks=115 counted_failures=0 skips=8`:

| | delta | why, derived |
|---|---|---|
| `cases=` | **+1** (116 → 117) | one new `dcases` entry, one new `Start` line |
| `blocks=` | **+1** (115 → 116) | `summarize_all` ran once and `incr ::t1_blocks` once |
| `counted_failures=` | **+0** | the lifted proc returned `num_fail 0` over the real log; no line in it ends `FAIL`/`GOLD?`/`RESULT?` or starts `FATAL` |
| `skips=` | **+0** | **not predicted — measured**: the `^skip:` arm matches **zero** lines in all three captures, in any case, and my suite announces nothing skipped at all |
| `wc -l` | **+3** | the block's label line, its one published `RESULT:` line, and its `Total num fail:` line. The two restated suites add **no** lines — they already published a `RESULT:`; only the numbers in them moved, 545 → 546 and 244 → 246. |

⚠ **This is a derivation over my own three suites' output, not a prediction of the trailer.**
CLAUDE.md records three occasions where careful reasoning about registration shape got
`skips=` wrong — most recently issue 1625, where an adversarial verifier *and* the driver both
predicted movement and both were wrong. What I have measured is that **my** suites contribute
no line the arm matches; whatever every other case contributes is unchanged by this stage,
since the only shared file I touched is `tests/run_regression.tcl` and the five suites that
read its text are green at the counts §3 reports. **Read the trailer.**

---

## 10. `git status --short` at the end

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

(Taken after this receipt was written, so the receipt itself appears. The listing one step
earlier, before it existed, was the same minus that line.)

**The four modified files and the two new untracked ones are exactly mine**, and nothing else is
modified. The three remaining untracked entries (`.xschem/`,
`open_feature_build_survey_2026_09_30.md`, `sky130A/…/debug_st1/`) were all present in this
session's starting snapshot and are not mine — I did not touch them. Unlike Stage A, nothing
edited this tree underneath me: `src/calculator.tcl` was mine throughout, and its md5 at the
end (`7def2001…`) matches the backup taken before the sabotage round.

Nothing is committed, pushed or stashed. This receipt is the only file added under
`doc/claude/`; the earlier receipts, `EYEBALL_SIGNOFF.md`, `PLAN.md`, `LEDGER.md` and the spec
are untouched.

---

## 11. What the next stage must know

1. **R505 IS HALF DONE, and the half that is done is the buffer.** PLAN **4.4** joins the
   stack's history to the buffer's as one history, and when it does, `calc::buf_can`,
   `calc::buf_sync`, `calc::buf_note_edit` and `calc::buf_undo`/`buf_redo` are the five procs
   it has to go through. **The two fallback hints (`fbundo`, `fbredo`) will need a stack term
   as well**, and the conservative-direction contract in `calc::buf_can`'s comment is the
   thing to keep, not the particular booleans.
2. **PLAN 4.3 puts R510 IN FRONT of `calc::pad_click`, it does not replace it.** The stack
   rule consumes the top two entries and pushes `<second> <top> <op>`, **falling back to
   `calc::buf_insert_token`** when the stack cannot supply the operands — so phase 4.3 edits
   `pad_click` and leaves `buf_insert_token` alone. And **`?` is not binary**: spec W30
   records that the engine's `COND` consumes **three** stack entries, so a `?` button needs
   `<third> <second> <top> ?`; emitting `<second> <top> ?` leaves the `stackptr2 > 2` guard
   false and the expression silently yields an operand instead of a conditional.
   Row `S22 NO key and no user button touched the stack -- R510 is PLAN 4.3` in
   `test_calc_skeleton` **will redden the moment 4.3 lands**, and that is deliberate: it is
   the row that notices phase 4 arriving, and it must be restated in that commit, not widened.
3. **The phase-1 inertness bands are now three-way, and a fourth phase will have to restate
   them again.** `CW13` in `test_calc_widgets` holds a named `$live2` list, **asserts its
   size** (`exactly fifteen controls are wired to a landed phase-2 proc`) and **asserts how
   many of them the sweep really pressed** (13 — Undo and Redo are disabled on an empty
   history). Both of those numbers are rows, not comments, so they re-measure every run; a
   phase that lands another control must move them in the same change. The same shape is in
   `S19` (`btbsays` / `btblive`) and `S22` in `test_calc_skeleton`. **Widening a list without
   moving its size row is the hole this structure exists to close.**
4. **`src/calculator.tcl`'s dead `recon/` citation is STILL LIVE** (open item 2 of
   `LEDGER.md`), near `calc::catalogue` / `calc::build_stk`. I edited this file and did not
   retire it, because the ledger assigns it to "whoever next edits that file" and I did not
   want a doc change mixed into a behaviour commit the driver has to gate. It is one line.
5. **`/usr/bin/grep -n "calc::inert"` under-reports by three, permanently.** See §7 and §9.
   Three of the ten toolbar controls are dispatched from a table and have never appeared in
   that grep; the honest progress reading is **the grep's lines PLUS the phase numbers in
   `calc::build_buf`'s and `calc::build_stk`'s tables**. The table comment says so. If the
   batch wants the grep to stay the single indicator, the fix is to give each table row its
   own explicit command rather than a shared fallback line — a change I did not make, because
   it would add ten lines to make a grep tidier.
6. **The status wordings are mine and are unratified.** `operator + inserted`,
   `buffer cleared`, `buffer already empty`, `edit undone`, `edit redone`, `nothing to undo`,
   `nothing to redo`. They are user-visible, they follow the house style, and `CB3` asserts
   each literally — so changing one is a one-line product edit plus the row that names it.
   I did not file a `rule` debt: the user is on a phone, nothing is blocked on it, and
   CLAUDE.md's standing instruction is to decide internal-looking things and proceed. **If
   the driver wants them ratified, this is the list.**
7. **Three traps in this area, measured, that will cost a later stage a run each if
   forgotten.** (a) `event generate <KeyPress>` does **not** synthesise a `<KeyRelease>`, and
   anything hanging off the release never fires — §7.3. (b) A bare `edit separator` on an
   empty undo stack does **not** make `edit canundo` true, so bracketing a press costs
   nothing at the start of a session (measured on Tk 8.6.17). (c) Tk merges **consecutive
   inserts** into one undo step and splits only at a separator, and `tk::TextInsert` writes a
   separator only for a compound replace-selection — so typing and a programmatic insert
   collapse together unless you bracket, and **a row that resets the history immediately
   before the press cannot detect that**.
8. **Issue 1627 is still open and unfenced**, and `test_calc_buffer` now carries the citation
   at its verdict block like its two siblings. It has two exit paths today; **a third must
   print its verdict INSTEAD of one of them, never as well.**
9. **`test_audit_classifier` is in neither list** for the fourth stage running — carried as
   open item 2 of issue 1627. Section K gates nothing today. I ran it (75 checks, green) but
   did not register it: out of scope, and the decision is the driver's.
