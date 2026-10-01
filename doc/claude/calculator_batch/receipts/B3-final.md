# Receipt B3 — the last round for PLAN phase 2 (items D1–D8)

Stage label `B3-final`. Branch `fluid-editing`, tree at `493fa053`, **nothing committed,
pushed or stashed**. All scratch under `…/scratchpad/B3-final/`.

Two files changed: `src/calculator.tcl` and `tests/headless/test_calc_buffer.tcl`.
**I did not touch Stage B's or B2's receipts, `test_calc_skeleton.tcl`,
`test_calc_widgets.tcl`, `tests/run_regression.tcl`, `CREW_BRIEF.md`, `PLAN.md`,
`LEDGER.md` or the spec.**

`test_calc_buffer` went **109 → 119 checks** on the display arm. Three items were blocking;
all three were real and all three were observed failing first, two of them through the real
binary outside the suite as well. **Eight of the eight items are closed.** The scope was
closed and I did not widen it: two things I found that are not in the eight are recorded in
§9 for a later stage rather than fixed.

---

## 0. The verdicts, both arms

| suite | display arm | headless arm | before this stage |
|---|---|---|---|
| `test_calc_buffer` | `RESULT: ALL PASS (119 checks)` | `SKIP … (self-skipped: no X — nothing ran)` | 109 / same skip |
| `test_calc_skeleton` | `RESULT: ALL PASS (546 checks)` | `RESULT: ALL PASS (0 checks)` | 546 / 0 |
| `test_calc_widgets` | `RESULT: ALL PASS (246 checks)` | `SKIP … (self-skipped: no X)` | 246 / skip |
| `test_registered_banner_1626` | `RESULT: ALL PASS (10 checks)` | `RESULT: ALL PASS (10 checks)` | 10 / 10 |

`RESULT: 4/4 runs passed` and `RESULT: 2/2 runs passed (2 skipped)`, through the armed
spelling `tests/headless/run_suites.sh [--nogui] <t>`, display arm attached to the
persistent dev display `:99`, left exactly as found (`status` only, never
`start`/`stop`/`view`).

**The two sibling suites' counts did not move**, and that is the corroboration that I did
not disturb them: `src/calculator.tcl` changed under them and neither needed restating.

Neighbours that scan the tree's text, all `--nogui`, all `ALL PASS`:
`test_audit_classifier` 75, `test_selflog_grep_guard` 390, `test_scratch_home_note` 22,
`test_regression_concurrency_1476` 46, `test_issue_stamp` 102.

---

## 1. What I changed, by symbol

### `src/calculator.tcl`

| symbol | what changed and why |
|---|---|
| **`calc::buf_note_edit`** | gained the `calc::has_win .calc.buf` guard it never had. **D1.** It is an entry point, it is in the suite's own `$ph2calls`, and with no window it WROTE both fallback hints under all three of R508's cases. Its comment block now says that, and says that the state it wrote is exactly what `calc::close` exists to clear — so a `buf_note_edit` after a close resurrected the stale hints item C7 had just been fixed to prevent. |
| **`calc::buf_typed`** | the hints now go up **only if the buffer text actually changed**. **D3.** The unconditional raise destroyed the one thing that makes the fallback's conservative over-answer safe. Comment block rewritten to say what breaks without it. |
| **`calc::buf_sync`** | one line added: it snapshots the buffer text into `fbtext`, inside its own window guard and after the two `configure` calls. **D3.** Every phase-2 operation ends here, so this is the single place the snapshot is always current; the alternative was four procs each having to remember. |
| **`calc::fbtext` (NEW namespace variable)** | the buffer text as of the last `calc::buf_sync`. Declared `{}` and cleared by `calc::close`, with the hints, because it is the same window-scoped state — not with `editcan`, which measures the interpreter. **D3.** |
| **`calc::close`** | clears `fbtext` beside `fbundo`/`fbredo`. **D3.** |
| **`calc::buf_can`** | comment only: the "refuses once, not forever" sentence now says that it was **false until this change** and that it is held by **two** procs, `calc::buf_undo` doing the correcting and `calc::buf_typed` not undoing it. **D3.** |
| **`calc::build_buf`** | comment only: the undo-option sentence lost its dead `recon/` pointer and its site count, and no longer spells the option out at all, so the grep for that option over this file is clean again. **D6.** |
| comments only | the three remaining `CB2/8.4` band labels became `CB2/8.5`, and the `8.6-only subcommands` row's rationale now names this file's real floor. **D7.** |

### `tests/headless/test_calc_buffer.tcl`

| what | item |
|---|---|
| **`ns_state` / `ns_count` / `ns_diff` (NEW helpers)** — the whole of the `calc` namespace's state, enumerated from `info vars ::calc::*` and not from a list written in the suite. Arrays read with `array get` and sorted; a declared-but-unset variable recorded as `UNSET`. | **D2** |
| `CB4` — one named row for `calc::buf_note_edit`; the sweep now brackets **every** step with a namespace snapshot, pins the two hints to a sentinel first, and checks `winfo exists .calc` after each step rather than once at the end. | **D1, D2** |
| `CB5` — the same two axes, with the window-existence leg asked through the renamed-aside `::cb_real_winfo` because `winfo` is gone for the length of that loop; plus a status-line row. | **D2** |
| `CB5` — the structural absence row **renamed** to drop its false inference, and a **positive** row added: every phase-2 proc whose body names a `.calc` widget path also names `calc::has_win`, with the two pure functions pinned by name as the only exceptions. | **D4** |
| `CB2/8.5` — the self-correction row renamed to its method, and **five** new rows for the "not forever" half: a no-op keystroke over an empty buffer, its positive control, and the same pair over **non-empty** text with its fixture. | **D3** |
| `CB1` — the five-character row and the engine-split row renamed to say **representative**, and the band comment rewritten to say the class is a strict superset and why these five. | **D5** |
| headers — the `CB3` sentence about PLAN 2.4 corrected from LOOSER to **strictly TIGHTER**, in both places it appears; the band labels renamed to 8.5 with the measurement; `CB4`/`CB5` headers now state the two axes. | **D7, D8a** |

---

## 2. The red, verbatim

One capture, `red2.log`, taken with every new row in place and the product unfixed:
**`RESULT: 5 FAILED (111 passed)`**. No `UNEXPECTED ERROR`, no `group … ABORTED`, no
`BGERROR`: the rows **failed**, they did not throw.

```
FAIL: CB2/8.5 ...and a keystroke that CHANGES NO TEXT leaves that correction standing, so the button refuses once and not forever -> {{} normal} (exp {{} disabled}) : FAIL
FAIL: CB4 calc::buf_note_edit writes NEITHER fallback hint with no window, and returns cleanly (R508) -> {1 0 {}} (exp {7 7 {}}) : FAIL
FAIL: CB4 ...and none of them WRITES any calc:: namespace variable -- R508 says 'records nothing', which is about state and not only about raising -> {1 1 {{calc::buf_note_edit:fbredo fbundo}}} (exp {1 1 {}}) : FAIL
FAIL: CB5 ...and none of them WRITES any calc:: namespace variable on that path either, nor brings the window back -> {1 1 {{calc::buf_note_edit:fbredo fbundo}} {}} (exp {1 1 {} {}}) : FAIL
FAIL: CB5 every phase-2 proc whose body names a .calc widget path also names calc::has_win, and the only two that name no widget are the pure string functions -> {{} {calc::buf_note_edit calc::engine_space calc::token_sep}} (exp {{} {calc::engine_space calc::token_sep}}) : FAIL
```

The third and fourth reds are **the product naming its own defect**:
`calc::buf_note_edit:fbredo fbundo` is the proc, and the two variables it wrote with no
window, printed by a snapshot the suite took from the namespace itself.

And the sixth row of the final suite — the one over **non-empty** text — was red only after
I had already shipped a green fix. See §6.1; that is the most useful thing in this receipt.

### D1 reproduced under a REAL `--nogui`, outside the suite

The suite forces R508's third case by renaming `::winfo` away. To be sure the write is not
an artefact of that mechanism, the same thirteen calls plus `calc::status` and
`calc::has_win` were driven from a scratch script under the real binary with `--nogui`,
where Tk is genuinely not loaded, with the two hints **pinned to a sentinel no phase-2 proc
writes** so that writing back the value already held still shows as a difference.

```
######## PRE-FIX, real --nogui:
P: winfo command = {}
P: calc procs = 92
P: nsvars = 17
P: steps=15 raised={}
P: steps=15 wrote={{calc::buf_note_edit:fbredo fbundo}}
P: fbundo={1} fbredo={0} statusmsg={} hist={}
######## WITH THE FIX, real --nogui:
P: winfo command = {}
P: calc procs = 92
P: nsvars = 18
P: steps=15 raised={}
P: steps=15 wrote={}
P: fbundo={7} fbredo={7} statusmsg={} hist={}
```

**`raised={}` on both runs is the point of the item**: the pre-fix proc "returned cleanly"
exactly as the CB5 band header claimed, and wrote two variables while doing it. That is
why one axis was not enough.

### D3 reproduced through the REAL physical key, both ways

Driven as `event generate .calc.buf <Control-KeyPress-z>` followed by the `<KeyRelease>` of
that same key — not as a bare `<<Undo>>`, and not as my synthetic arrow key — with the
widget command shadowed so the 8.5 fallback is really in force:

```
######## WITH THE FIX:
P: event info <<Undo>> = <Control-Key-z> <Control-Lock-Key-Z>
P: probe on the shadowed interpreter = 0
P: before   buf={v(out)} undo=normal msg={}
P: after Ctrl+Z press   buf={v(out)} undo=disabled msg={nothing to undo} fbundo=0
P: after its KeyRelease buf={v(out)} undo=disabled msg={nothing to undo} fbundo=0
######## PRE-FIX (the tree as B2 left it):
P: before   buf={v(out)} undo=normal msg={}
P: after Ctrl+Z press   buf={v(out)} undo=disabled msg={nothing to undo} fbundo=0
P: after its KeyRelease buf={v(out)} undo=normal msg={nothing to undo} fbundo=1
```

Read the last pre-fix line: the status line says **`nothing to undo`** and the button says
**`normal`**, at the same instant, over an empty history. The self-correction lasted from
the key press to the key release of the same keystroke. That is D3 in the product's own
voice, and it is the measurement that settled "is the fix worth making".

---

## 3. Item by item

### D1 — BLOCKING, REAL: `calc::buf_note_edit` had no window guard. FIXED.

Red above, twice, including under a real `--nogui`. The guard is `calc::has_win .calc.buf`
— the helper B2 added for exactly this, which asks `[info commands winfo] eq {}` first —
placed **before** the two writes, which §4's `SAB-Y` shows is load-bearing. Its siblings
`buf_typed` and `buf_insert_token` guard the same widget, so the proc now matches them.

**No behaviour changed in the live product**, and I am stating that rather than implying a
cure: the two callers inside the file (`buf_insert_token`, `clr_buf`) are both already
guarded on `.calc.buf`, so the guard is never false when reached from the UI. What it fixes
is the **direct** call — which is what a test does, what PLAN 4.4 will do from the stack
side, and what the suite's own `$ph2calls` list does. The CB5 band header's claim that
"every phase-2 entry point is a silent no-op" was false for exactly this proc, and is now
true.

### D2 — BLOCKING: the R508 fence measured only RAISING. BOTH AXES NOW.

Before this stage `CB4` read **one** variable (`statusmsg`) **once**, after the whole loop,
and `CB5` read none at all. Twelve of the thirteen entry points could have written anything
and both bands would have stayed green — which is not hypothetical, since the thirteenth
did.

**The state is enumerated from the namespace, not from a list in the suite.** `ns_state`
walks `info vars ::calc::*`, reads arrays through `array get` and sorts them, and records a
declared-but-unset variable as `UNSET` so that becoming set is a difference. `ns_diff`
reports the **bare** names that moved, with `+`/`-` for ones that appeared or vanished, so a
failing row names the proc and the variable and stays short. **I did not need the exemption
the task offered**: the derivation is clean and `ns_count >= 17` rides in both rows so an
`info vars` that answered nothing cannot pass the band vacuously. Measured on the live
window: **17** variables in the namespace before this stage, one of them an array
(`::calc::sash`), none unset; **18** after `fbtext`.

⚠ **One thing the derivation cannot do, stated as the limit it is:** a proc that writes a
variable the value it already holds is invisible to a before/after snapshot. The sweep
therefore pins the two fallback hints to a sentinel (`7`) that no phase-2 proc writes,
before each band's loop, and says so in its own comment. **That was not a precaution — it
was a measured hole**: with the hints left at `0 0`, CB5's sweep went **green on the broken
tree**, because CB4's sweep had already left them at the values `buf_note_edit` writes. The
general version of the hole is open: a later phase's variable gets no sentinel. The honest
reading is that the snapshot catches a **changed** value and the sentinel extends it to a
**re-written** one, for the two variables where it mattered.

### D3 — BLOCKING: the keyboard route defeated its own self-correction. FIXED, and it was small.

**I checked the scope note before deciding, and it holds**: `calc::color`'s body is
`set pal [calc::palette]` then `if {[dict exists $pal $role]} { return [dict get $pal $role] }`,
`dict` is a Tcl 8.5 addition, and `calc::color` is on the path of every widget in the window
— so this file cannot run on 8.4 and the path only ever affects a Tk 8.5 user. (That `dict`
arrived in 8.5 is documentation; there is no 8.4 interpreter here. The `dict` use and the
fact that every widget asks `calc::color` are both grepped.) The development machine is
8.6.17 (`info patchlevel`).

**The fix is three lines of code and it is local**, so the task's pre-authorised "declare it
as a limit" arm was not needed. `calc::buf_typed` compares the buffer text with `fbtext`,
the text as of the last `calc::buf_sync`, and raises the hints only if they differ. The
hints are never **lowered** there — only a refusal does that — so this is strictly a
narrowing of when they rise, which is why nothing else in the band moved.

Why the snapshot lives in `calc::buf_sync` rather than in four procs: every phase-2
operation ends in a sync, so one site is always current and there is no "the proc that
forgot to update it". Why not `edit modified`: it is sticky until explicitly cleared, so
after the user has typed anything it answers 1 for every later arrow key, and whether Tk
resets it on an undo back to the unmodified point would have had to be measured and relied
on. The text comparison needs no Tk semantics at all.

**The two false claims are fixed with the code, and both were false about their METHOD as
much as about the tree.**

* The row `CB2/8.4 ...and SELF-CORRECTS the hint, so it refuses once, not forever` measured
  only the refusal and the button state immediately after it. It is now
  `CB2/8.5 ...and SELF-CORRECTS the hint on the refusal itself, so the button goes
  disabled`, which is its method, and the "not forever" claim moved to four new rows that
  measure it.
* `calc::buf_can`'s comment sentence ("a button refuses once and then goes disabled — it
  never refuses twice in silence") now carries a ⚠ saying it was false until 2026-09-30 and
  that it is held by **two** procs, naming both and naming what `buf_typed` used to do.

### D4 — MINOR: the CB5 structural row was vacuously satisfiable. POSITIVE ROW ADDED.

The old row asserted a proc body does **not** name `winfo` and its name concluded "...so
none of them can raise R508's third case on its own". A proc with no guard whatsoever
satisfies the predicate, and `calc::buf_note_edit` was that proc — which is why the old row
was green over a real defect. The name now claims only the absence ("so none of them carries
its own copy of the guard"), and a new row asserts the positive.

**"Touches a widget" is derived from the body, not listed:** a body that names a `.calc`
path must also name `calc::has_win`. The second leg pins the two genuine exceptions
(`calc::token_sep`, `calc::engine_space` — pure string functions, no widget) by name, which
is also the non-vacuity control: if the `.calc` regexp ever matched nothing, every proc would
land in the `pure` list and the row reddens rather than passing over a measurement it did
not make. `SAB-M` and `SAB-V` both redden it by name.

### D5 — MINOR: a row name asserted a false identity. RENAMED TO ITS METHOD.

**Measured here, in `tclsh` 8.6.17, over the whole BMP:** `string is space` accepts **29**
characters, of which **26** are not in the engine's `" \t\n"`. The accepted set is
`U+0009 U+000A U+000B U+000C U+000D U+0020 U+0085 U+00A0 U+1680 U+180E U+2000`–`U+200B`
`U+2028 U+2029 U+202F U+205F U+2060 U+3000 U+FEFF`. So a row name reading as an enumeration
of five was wrong about the class by twenty-one characters.

The row is now `CB1 token_sep: FIVE REPRESENTATIVE characters string is space accepts and
the engine does not -- a Windows paste's CR, a form feed, VT, NBSP, EN-SPACE -- still get a
separator, on both sides of the caret`, and the engine-split row beside it says
`REPRESENTATIVE` too. **The method was not widened**: five characters, as the scope says,
and the row's own `$nch` leg still asserts five. The band comment now says the class is a
**strict superset** and names the families it also takes, and says why these five are the
representatives — real input produces them (a Windows X server and a paste from Windows
carry CRs; a form feed arrives from printed or generated text; NBSP and EN-SPACE come from
anything that has been through a word processor or a web page).

The 29/26 figure is **in this receipt and nowhere in the tree**, because nothing re-measures
it. One command takes it again:
`for {set i 0} {$i<65536} {incr i} {...[string is space [format %c $i]]...}`.

### D6 — MINOR: the fifth surviving measurement digit. DROPPED, AND THE COMMENT CAUGHT ITSELF.

Both halves of `-undo 1 is the blanket house default on every editable text in the tree
(recon/widgets.md §5, 16 sites)` were wrong.

**The pointer:** `git log --all --oneline -- doc/claude/calculator_batch/recon` prints
nothing and the directory is not on disk. Never committed on any branch.

**The count, measured by occurrence over `src/*.tcl`:** this file 1 (the widget creation),
`src/ciw.tcl` 1, `src/xschem.tcl` 14 — **16** by that spelling if you count only widget
creations and comments are excluded, but **17** as the tree actually stood when the sentence
was written, because the sentence **itself** contained the option string and grep counted it.
That is the whole defect: the figure is a count over the tree's own text, and the comment is
part of the tree.

⚠ **AND I SHIPPED IT WRONG MYSELF, EXACTLY ONCE, BEFORE CATCHING IT.** My first replacement
sentence read *"`-undo 1` follows the house spelling … and NEITHER creates one with
`-undo 0`"* plus a parenthesis saying *"this file holds two of them"*. Measured straight
afterwards: `src/calculator.tcl` then held **3** occurrences of the option string and **1**
of the off-value, all but one of them inside my own correction — so the sentence written to
retire a polluted instrument polluted it further, and its own parenthetical count was wrong
the moment it was written. **This is the 1608 defect reproducing inside the fix for it, for
the second time in this batch** (B2 §6.3 records the first). The sentence now states the
shape, quotes no figure, and **does not spell the option out at all**; `/usr/bin/grep -c
-- '-undo' src/calculator.tcl` is back to **1**. The retired path and figure are not quoted
in the comment either — the comment names the kind of pointer and points here for the
measurement.

### D7 — MINOR: the 8.4/8.5 label. MADE CONSISTENT WITH THE 8.5 TRUTH.

The truth is C11's: this file cannot run on Tcl 8.4, so a band claiming to force 8.4 was
claiming to measure an interpreter the file dies on. Renamed: **21** `CB2/8.4` row names →
`CB2/8.5`; the suite's `FORCED 8.4/8.5` band header → `FORCED 8.5`; `ONE MECHANISM FOR
FORCING THE 8.4/8.5 FALLBACK` → `8.5`; `bufset`'s "the 8.4/8.5 fallback" → "the 8.5
fallback"; the suite's CB2 header gained a ⚠ saying the label was wrong until 2026-09-30 and
why. In the product: `CB2/8.4 band` and `rows CB2/8.4` and `the forced-8.4 band` → 8.5, and
the `8.6-only subcommands` row's rationale now says this file's own reachable floor is 8.5
instead of leaving "targets 8.4-8.6" to be read as a claim about this file.

**What I deliberately left at 8.4, and why it is not an inconsistency:** three pre-existing
phase-0/1 comments say `-stretch` and `-tristatevalue` are catch-guarded because Tk 8.4 does
not have them, and `bufset`'s comment says `edit reset` is Tk 8.4+. Those are statements
about **when a Tk feature arrived**, which remain true, and none of them claims an 8.4 user
can run this window. Changing them is a different subject and the scope is closed; §9 records
that the guards they describe are now known-moot.

### D8 — MINOR: two inverted descriptions and one wrong remedy.

**(a) FIXED in the suite.** PLAN 2.4's acceptance line "no silent mutation path remains" is
**strictly TIGHTER** than what `CB3` measures, not looser: a keystroke *is* a mutation, so
PLAN 2.4 would have it speak, and the group deliberately keeps it silent on the spec's
reading of R506. The word "mutation" names a **broader class** than "operation", and a
requirement quantified over a broader class is a **stronger** requirement — which is the
confusion the old sentence made. Both sites are fixed: the `CB3` header entry (which now
also says plainly that the group does **not** meet PLAN 2.4 as written, on purpose) and the
inline sentence above the raw-typing rows. **B2's receipt §3's C6 paragraph and Stage B's
receipt are dated records and are left unedited; this is the correction.**

**(b) NOT FIXED, out of scope, and the correct position is worse than B2 stated.** B2 §10.6
says "the two sibling calculator suites still print a bare `BGERROR:`, which neither reader
sees — worth the same one-line change". Measured:
`/usr/bin/grep -n 'bgerror' tests/headless/test_calc_skeleton.tcl
tests/headless/test_calc_widgets.tcl` returns **one** line, in `test_calc_widgets.tcl` only:
`proc ::bgerror {msg} { puts "BGERROR: $msg"; incr ::fail }`.

So the two files are in **different** states and only one of them fits B2's description:

* `test_calc_widgets.tcl` **has** a handler. It prints a bare line neither reader echoes or
  counts, **but it does `incr ::fail`**, so the suite's own verdict reddens and no
  `OVERALL: ok` is printed. The diagnosis is wrong; the gate is not. B2's one-line remedy
  (end the line in `: FAIL`) is correct for this file.
* `test_calc_skeleton.tcl` has **no `::bgerror` handler at all**. Nothing increments `$fail`,
  so a background error leaves the suite printing `OVERALL: ok` and `RESULT: ALL PASS` **over
  a real error** — a hollow pass, which is strictly worse than an uncounted line, and T1
  would score the case green. The remedy there is to **add** the handler, not to amend one;
  appending `: FAIL` to a line that does not exist does nothing. There is a second
  consequence I did not measure and so am flagging rather than asserting: with no handler the
  error reaches Tk's own default `bgerror`, which on a display arm is a modal dialog, and a
  modal dialog in a suite is a stall that only `SUITE_TIMEOUT` ends.

I did **not** touch either sibling: out of scope, and the decision is the driver's.

---

## 4. Sabotages: twenty-seven, every one of them red

Each applied to `src/calculator.tcl` alone by a scripted patch that **refuses to apply
unless its target text is unique in the file**, suite run on the display arm, file restored
from a checksummed backup, and **the md5 verified after every single one**
(`bd3ea77e2d48afd034460544aac75e78`, unchanged at the end; the suite file's
`569bc7415f9153754dac4b772530aea3` likewise).

**The twenty-three inherited from Stage B and B2 were ALL re-run against the tree as this
stage leaves it, and all twenty-three still redden.** That was the point of the exercise —
two rounds of fixes had passed over this code and a fix that silently disarmed an earlier
fence is the failure mode that matters most here. None did.

| # | the plausible wrong implementation | reds | the rows that caught it (named where few) |
|---|---|---|---|
| **A** | `insert end` instead of `insert insert` | 6 | the caret rows: MID-TEXT, chaining, inside a token, the selection rows |
| **B** | `token_sep` returns the bare token | 20 | incl. the engine-split and twelve-key rows |
| **C** | `token_sep` returns `" $tok "` — "always separate" | 21 | incl. the empty-buffer and already-separated rows |
| **D** | `buf_can` with no probe and no catch — what a reasonable person writes on this machine | 19 + 9 `BGERROR` | 28 counted; the whole forced-8.5 band |
| **D2** | D **and** a catch back around `buf_sync`'s two `configure` calls | 9 | the structural row, the accessor row, the button-state rows — **and every performing row still passes**, which is the shape C5 records |
| **E** | no `edit separator` bracketing in `buf_insert_token` | 3 | `CB2 a press after an UNSEPARATED edit…`, `…does not swallow the TYPING…`, `CB3 <<Undo>> undoes exactly ONE step` |
| **F** | the refusal path does not clear `fbundo` | 4 | the self-correction row **and all three new "not forever" rows** |
| **G** | `calc::status` added to `buf_typed` | 2 | `CB3 RAW TYPING writes no status line`, `…records no history entry` |
| **H** | every `calc::has_win` guard dropped from the entry points | 6 | both R508 bands, both axes, **plus the D1 row and the D4 positive row** |
| **I** | `buf_note_edit` does not call `buf_sync` | 4 | `CB2 one keypad press enables Undo…` + three fallback rows |
| **J** | `engine_space` asks `string is space` | 3 | the `engine_space` answers row, the five-character row, the engine-split row |
| **J2** | J **and** both `ne {}` guards deleted | 3 | the same three — the C9 measurement, still holding |
| **U** | correct predicate, both `ne {}` guards deleted | 14 | seven separator rows, the twelve-key sweep, three `CB2/8.5` and `CB3` rows |
| **K** | `engine_wsp` drifts from the engine by one character | 4 | **the `src/save.c` derivation row** + the CR legs |
| **L** | `has_win` written as the bare `winfo exists` | 2 | `CB5` behavioural + `CB5 …the helper … asks info commands winfo` |
| **M** | one proc (`clr_buf`) left on the bare guard | 3 | `CB5` behavioural, `CB5` absence, **and the new `CB5` positive row** |
| **N** | the hint update deleted from `buf_typed` | 2 | `CB2/8.5 TYPING raises BOTH the fallback's hints` **and the new positive control** |
| **O** | `buf_undo` sets `fbredo 0` on success — the under-answer | 1 | `CB2/8.5 ...and that undo enables the REDO button, through the hint` |
| **P** | `clr_buf` forgets `buf_note_edit` | 1 | `CB2/8.5 ClrBuf enables Undo through the fallback's hint` |
| **Q** | `<<Undo>>`/`<<Redo>>` left on the silent typing handler | 5 | four `CB3` keyboard rows + the binding-classification row |
| **R** | routed to the operation procs but **without `break`** | 1 | `CB3 <<Undo>> undoes exactly ONE step` |
| **S** | `close` does not clear the hints | 2 | both `CB2` close/reopen rows |
| **T** | the selection disarm removed | 1 | `CB1 the keystroke after a press ADDS one character and deletes nothing` |

### This stage's own four

| # | the plausible wrong implementation | reds | the rows that caught it |
|---|---|---|---|
| **V** | **D1 undone** — `buf_note_edit` back to no window guard | 4 | `CB4 calc::buf_note_edit writes NEITHER fallback hint…`, both write-axis rows, **the D4 positive row** |
| **Y** | **D1 written the plausible wrong way** — the guard present but placed **after** the two writes | 3 | the D1 row and both write-axis rows. ⚠ **NOT the D4 positive row**, and that is the finding: a structural row cannot see statement order, so the write-axis rows are what makes D1 a fence rather than a grep. This is why D2 and D1 had to land together. |
| **W** | **D3 undone** — `buf_typed` raises the hints on every `<KeyRelease>` again | 2 | both "changes no text" rows |
| **X** | **D3's snapshot never taken** — the line removed from `buf_sync` | 1 | `CB2/8.5 ...and a keystroke that changes NO TEXT leaves it standing over non-empty text` |

---

## 5. The trailer delta — derived from `summarize_all`'s own arms over real output

Method: capture the case exactly as T1's `dcases` arm does (`--pipe -q --nolog` on `:99`,
stdout and stderr together, a throwaway `HOME` under my scratch), then **lift
`summarize_all` and `t1_carry_line` out of `tests/run_regression.tcl`'s own text** (a line
scan from `^proc <name>` to the first line that is exactly `}`), `source
tests/banner_rule.tcl`, and run the lifted proc over that capture. No figure below is quoted
from a receipt.

```
lifted: t1_carry_line (5 lines)
lifted: summarize_all (89 lines)
--- the lifted summarize_all's arms ---
>> if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
>> } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
>> } elseif { [regexp {^skip:} $line] } {
>> } elseif { [regexp {^RESULT:} $line] } {
>> } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
--- how many lines of the capture each arm matches ---
counted-shape=0  lowercase(^skip:)=0  any-case(^skip)=0  ^RESULT:=1  NOGOLD/NODISPLAY=0  capture-lines=125
banner_complete=1 banner_died=0 regression_case_failed(0)=0
--- lifted summarize_all returned: 0 ; t1_blocks=1 t1_skips=0
--- the block it wrote ---
headless/test_calc_buffer
RESULT: ALL PASS (119 checks)
Total num fail: 0
```

**Relative to the tree as B2 left it, this stage's delta on every trailer field is ZERO.**
No case is registered or removed (`tests/run_regression.tcl` is untouched by me), the
counted arm matches no line, the `^skip:` arm matches **no** line of my output **in any
case**, and `NOGOLD`/`NODISPLAY` match none. The only thing that moves is the **published
check count inside the block Stage B's registration already added**:
`RESULT: ALL PASS (109 checks)` → `RESULT: ALL PASS (119 checks)`. `wc -l` of a full verdict
is unchanged by this stage.

Relative to the driver's committed baseline **`116/115/0/8` at `deccdbd1`** (per commit
`493fa053`), the *uncommitted* delta is still Stage B's and nobody else's: **+1 case, +1
block, +3 lines** — one new `dcases` entry, so one `Start` line, one `summarize_all` call,
and three lines in the verdict (the label, the one published `RESULT:`, the
`Total num fail:`). Derived from the `git diff` of `tests/run_regression.tcl`, which adds
exactly one quoted entry, and from the lifted proc's `t1_blocks=1` over my own capture.

⚠ **This is a derivation over my own suite's output, not a prediction of the trailer.**
CLAUDE.md records four occasions where careful reasoning about registration shape got
`skips=` wrong, most recently issue 1625 where two independent parties predicted movement and
both were wrong. What I have measured is that **my** suite contributes no line the `^skip:`
arm matches, in either case; whatever every other case contributes is unchanged, because the
only shared file this stage touched is none. **Read the trailer.**

### The registration shape is unchanged, re-checked through the only Tcl reader

```
display: banner_complete=1 banner_died=0 regression_case_failed(0)=0
nogui:   RESULT: SKIP (no X: ...)  -- no banner, deliberately, because nothing ran
```

Still `dcases`-only, for the reason Stage B recorded. Issue 1627's shape re-measured on the
real capture: column-0 `RESULT:` **1**, column-0 `OVERALL:` **1**, `^FATAL` **0**,
`^note:` **0**, `BGERROR` **0**, `group … ABORTED` **0**, `UNEXPECTED` **0**, and `ok:`
lines **119** against a published `RESULT: ALL PASS (119 checks)`. The file still has two
exit paths and each prints its verdict instead of the other.

---

## 6. What I got wrong, and what corrected me

**Three things. The first is the one that would have shipped a fence passing over the defect
it was written for, and it was caught by the sabotage round and nothing else.**

### 6.1 My D3 fence was green against a tree with the fix torn out

`SAB-X` deletes the snapshot line from `calc::buf_sync`, so `fbtext` stays at the empty
string forever. I ran it expecting one red and got **`RESULT: ALL PASS (116 checks)`**.

The reason is arithmetic and it is worth writing down: `fbtext` stuck at `{}` compares
**equal** to an empty buffer, so a no-op keystroke over an empty buffer behaves correctly
by accident, and every row I had written happened to run with the buffer empty at the moment
of the keystroke. For a user with text in the buffer — the entire real case — every keystroke
including the release of a refused Ctrl+Z would still have raised the hint, i.e. D3 would have
been half-fixed and fully fenced.

Fixed by adding the same pair over **non-empty** text, with its own fixture, and saying in
the band's comment why it is not a repetition. `SAB-X` now reddens by name, `SAB-W` reddens
both pairs, and `SAB-F` (the refusal not clearing the hint) picks up all three new rows for
free.

**The habit that caught it was running each sabotage and reading how FEW rows it reddened
rather than being satisfied that it reddened something** — which is exactly the habit B2 §7.2
records learning, arriving one stage later with a zero instead of a two.

### 6.2 My own D6 correction polluted the instrument it was written to clean

Documented in full in §3's D6. In one sentence: the replacement text spelled the option
string out twice and its off-value once, taking this file from one occurrence to four, and
carried a parenthetical count that was wrong the moment it was written. Caught by measuring
the grep **after** writing the sentence instead of before. The published version spells
nothing and counts nothing.

### 6.3 The CB5 write-axis row was green on the broken tree, for a reason the band set up itself

With the hints left at `0 0` after CB4's sweep, `calc::buf_note_edit`'s `fbundo 1 ; fbredo 0`
was a **no-change** for CB5, so CB5's identical sweep passed while CB4's reddened. I had
written the two bands to be the same measurement under two conditions and they were not,
because the first band's own side effects were the second band's initial state. The sentinel
pin fixes it and both bands now say so. **What corrected me was running the red capture and
reading which bands reddened, rather than counting that five rows had.**

---

## 7. Every claim audited — how I checked each

Every sentence and row name I wrote or edited, and every claim the task handed me.

### Claims the task handed me, checked before acting on them

| claim | how checked | verdict |
|---|---|---|
| `calc::buf_note_edit` has no window guard and writes state | read the body; red rows; real `--nogui` probe | **confirmed** — and it writes under all three R508 cases |
| the CB5 band header's "every phase-2 entry point is a silent no-op" is false for it | read the header against the body | **confirmed** |
| CB4 reads one piece of state, CB5 reads none | read both bands before editing | **confirmed** (CB4 read `statusmsg` once, after the loop) |
| `calc::buf_typed` unconditionally sets both hints on the fallback | read the body | **confirmed** |
| the refusal self-correction is undone by the next keystroke | probed through the real `<Control-KeyPress-z>` + its `<KeyRelease>`, pre-fix and post-fix | **confirmed**, §2 |
| "Ctrl+Z and the Undo button do not agree" | same probe: `msg={nothing to undo}` with `undo=normal` | **confirmed**, and it is the same instant |
| `src/calculator.tcl` already cannot run on Tcl 8.4 (`calc::color` uses an 8.5+ construct) | printed `calc::color`'s body: `dict exists` / `dict get`; `calc::color` is on every widget's path | **confirmed**; that `dict` is 8.5 is documentation, not measured here (no 8.4 interpreter) |
| the development machine is 8.6 | `info patchlevel` → `8.6.17` | **confirmed** |
| the CB5 structural row is vacuously satisfiable by a proc with no guard | `calc::buf_note_edit` was exactly that proc and the row was green | **confirmed by the defect itself** |
| `string is space` accepts 29 BMP characters, 26 not in the engine set | ran the loop over `0..65535` in `tclsh` 8.6.17 | **confirmed**, both figures |
| the `-undo` site count does not reproduce | counted occurrences and lines per file in `src/*.tcl` | **confirmed** — and the sentence was part of what it counted |
| `doc/claude/calculator_batch/recon/` was never committed on any branch | `git log --all --oneline -- <path>` prints nothing; not on disk | **confirmed** |
| the driver retired two other citations to that directory this session | one retirement note is visible in this file; the second I could not verify from the tree | **not asserted** — my note says "joins the citations already retired" and quotes no count |
| C11 narrowed the rationale to 8.5 and left 8.4 elsewhere | grepped `8.4` in both files | **confirmed**, and listed |
| PLAN 2.4's acceptance line is TIGHTER, not looser | read PLAN.md's table row 2.4 and R506; reasoned over the class, then checked the reasoning against what `CB3` actually asserts | **confirmed** |
| `test_calc_skeleton.tcl` has no `::bgerror` handler | grepped both siblings | **confirmed**, and the gap is worse than B2 described — §3 D8(b) |

### Factual claims about Tk, Tcl and the tree that I newly rely on

| claim | how checked |
|---|---|
| `<<Undo>>` maps to `<Control-Key-z>` here | `event info <<Undo>>` → `<Control-Key-z> <Control-Lock-Key-Z>` |
| the `<KeyRelease>` of that key reaches `calc::buf_typed` after `<<Undo>>` has run | the §2 probe: `fbundo` goes 0 → 1 across the release, pre-fix |
| `info vars ::calc::*` enumerates the namespace's variables from any scope | used from a proc in the live suite; **17** names returned, one array |
| `::calc::sash` is the one array | `array exists` over each name |
| no `calc::` namespace variable is declared-but-unset | the `UNSET` leg of the probe returned nothing |
| the window-existence check inside CB5 must go through the renamed-aside command | `winfo` is gone for the length of that loop by construction; the row uses `::cb_real_winfo` |
| the snapshot in `buf_sync` sits inside a window guard, so an R508 call writes nothing | the real `--nogui` probe reports `wrote={}` with the sentinel pinned |
| `calc::buf_note_edit`'s two in-file callers are both already guarded | grepped every call site of it in `src/` |
| `/usr/bin/grep -c -- '-undo' src/calculator.tcl` is 1 after the edit | run |

### Row names I wrote or renamed

All 119 names were read against their methods. Seven changed:

* `CB2/8.4 ...and SELF-CORRECTS the hint, so it refuses once, not forever` →
  `CB2/8.5 ...and SELF-CORRECTS the hint on the refusal itself, so the button goes
  disabled`. The "not forever" claim is now four rows that measure it.
* `CB5 no phase-2 proc's BODY names winfo at all, so none of them can raise R508's third
  case on its own` → `… so none of them carries its own copy of the guard`. The inference
  was false; the positive row carries it now.
* `CB1 token_sep: the five characters string is space accepts and the engine does not (CR VT
  FF NBSP EN-SPACE) …` → `… FIVE REPRESENTATIVE characters …`, and the engine-split row
  beside it says `REPRESENTATIVE` too.
* `CB4 ...and the window was not resurrected by any of them` → `… -- checked after EVERY
  step, not only at the end`, because the method changed to match.
* 21 `CB2/8.4 …` → `CB2/8.5 …` (the label, not the claim).

### Comment sentences I wrote, checked against the rule that a comment states no count

`calc::buf_typed`, `calc::buf_sync`, `calc::buf_note_edit`, `calc::buf_can`,
`calc::build_buf`, the `fbtext` declaration, `calc::close`, the suite's CB2/CB3/CB4/CB5
headers, the `ns_state` block and the three new bands: **re-read for digits**. What remains
is version identities (`Tk 8.6.17`, `8.5`, `8.4`, `8.6`), requirement numbers, row
identifiers, and the sentinel value `7` — which is a value, not a measurement. No sentence
quotes a count over the tree's own text.

---

## 8. What I did NOT do, and why

* **No T1 run.** The driver's job and the brief forbids it. §5 is the unit-level substitute
  for *scoring*, not for *running*.
* **Nothing committed, pushed or stashed.** To take the pre-fix captures I kept the fixed
  file in scratch and restored it by checksum; `git stash` was never used.
* **I did not widen the scope.** Two things I found are in §9 as records, not fixes: the
  `recon/` citations still live elsewhere in `src/calculator.tcl`, and the now-moot 8.4
  option guards. Neither is in the eight items.
* **I did not fix the two sibling suites' `::bgerror` state** (D8b explicitly says not to),
  and I did not edit `test_calc_skeleton.tcl` or `test_calc_widgets.tcl` at all — their
  check counts (546, 246) are unchanged, which is the independent corroboration.
* **I did not edit any earlier receipt, `CREW_BRIEF.md`, `PLAN.md`, `LEDGER.md` or the
  spec.** Three corrections that belong to the driver are recorded here instead: PLAN 2.4's
  acceptance line (D8a), B2 §3's C6 "looser" sentence and B2 §10.6's remedy (D8b).
* **I did not register anything new**, and the one suite I touched keeps its shape
  (`dcases` only, re-checked through `banner_complete`).
* **I did not widen the five-character band to twenty-six**, as the scope says.
* **I did not take the "declare it as a limit" arm the task pre-authorised for D3.** The fix
  turned out to be three lines in two procs plus a variable, and the measurement that
  justified making it rather than declaring it is in §2.
* **One limit I am declaring rather than closing**, because it is inherent: a before/after
  namespace snapshot cannot see a proc writing a variable the value it already holds. The
  sentinel pin covers the two variables where that mattered and the band says so; a later
  phase's new variable gets no sentinel.
* **No probe wrote anything.** No `xschem save`/`saveas` anywhere in this stage, nothing
  under `xschem_library/`, `tests/headless/gold/` or any tracked fixture. Every probe ran
  with `HOME` pointed at my own scratch directory; every suite ran through the armed
  spelling. The dev display `:99` was left as found (`status` only). As B2 records,
  `devdisplay.sh exec` needs the real `HOME`, so the hand probes used
  `HOME=<scratch> DISPLAY=:99 GUI_GATE=0`, which is what `exec` pins.
* **Nothing was verified by eye, and no `look` debt was incurred.** Every claim here is a
  row, a quoted command output, or a predicate lifted from the tree.
* **No `rule` debt filed.** No new user-visible wording or behaviour choice is mine this
  stage: the D3 fix makes an existing documented contract true, and the rest is tests and
  comments. The unratified items are still Stage B §11.6's status wordings and B2's
  selection-highlight choice.
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
?? doc/claude/calculator_batch/receipts/B2-close-blockers.md
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_calc_buffer.tcl
```

Identical to B2's listing, plus this file once written. **Of those, I changed exactly two:
`src/calculator.tcl` and `tests/headless/test_calc_buffer.tcl`.** The other three modified
files are Stage B's and I did not open them for writing. The four untracked entries other
than the new suite and the receipts were in this session's starting snapshot and are not
mine. Nothing else is modified; nothing is committed, pushed or stashed.

---

## 10. What the next stage must know

1. **A STRUCTURAL ROW CANNOT SEE STATEMENT ORDER, and `SAB-Y` is the proof.** A guard
   written **after** the writes it is meant to prevent satisfies every grep-shaped row —
   `CB5`'s positive row passes it — and is caught only by the behavioural write axis. So
   `CB4`/`CB5`'s two axes are not redundant with the structural rows and must not be
   collapsed into them.
2. **A phase-4 proc that needs a window guard has three obligations, not one**: call
   `calc::has_win` **before** any write, add itself to `$ph2calls` in
   `tests/headless/test_calc_buffer.tcl`, and — if it writes a new namespace variable that an
   operation could legitimately re-write to the same value — get a sentinel in the two
   sweeps, the way `fbundo`/`fbredo` have one. Without the third, the write axis is a
   snapshot and can pass over a no-change write.
3. **The fallback now has THREE pieces of state, not two.** `fbundo`, `fbredo` and
   **`fbtext`**, all cleared by `calc::close`, all window-scoped; `editcan` remains
   interpreter-scoped and is deliberately not cleared. PLAN 4.4's stack term has to be
   cleared there too, and if the stack's history is joined to the buffer's, `calc::buf_typed`'s
   "did the text change?" test needs a stack equivalent or the joined history will raise the
   hint for a keystroke that changed nothing.
4. **R505 is still only HALF done**, exactly as B and B2 said. PLAN 4.4 joins the histories;
   the procs it goes through are unchanged.
5. ⚠ **`test_calc_skeleton.tcl` can print `OVERALL: ok` over a real background error**, since
   it has no `::bgerror` handler and nothing increments its `$fail`. That is a registered
   `dcases` entry, so it is a live hole in T1's own scoring, not a cosmetic one. The remedy is
   to **add** the handler (the spelling `test_calc_buffer.tcl` uses, ending `: FAIL`), and
   `test_calc_widgets.tcl` separately needs only its existing line amended. Out of this
   stage's scope; §3 D8(b) has the measurement.
6. ⚠ **`src/calculator.tcl` still carries live-looking `recon/` citations** at several sites
   (`recon/theming.md` §1–§3, `recon/widgets.md` §1 twice and §2), and that directory does
   not exist on any branch. This stage retired the one in its own scope. Open item 2 of
   `LEDGER.md`; the honest instrument is `/usr/bin/grep -n 'recon/' src/calculator.tcl`.
7. ⚠ **Three 8.4 guards in this file are now known-moot and were deliberately left.**
   `-stretch` is catch-guarded "because Tk 8.4 does not have it" (twice) and
   `-tristatevalue` likewise, while the same file records that it cannot run on 8.4 at all.
   The comments are true about Tk; the guards they justify can never fire here. Removing them
   is a phase-0 decision, not a phase-2 one, and I left them rather than widen D7.
8. **Two traps measured here that will cost a later stage a run each.** (a) `env -u DISPLAY`
   must come **before** any `VAR=value` on the command line — `env HOME=x -u DISPLAY cmd`
   fails with `env: '-u': No such file or directory`, which looks like a missing binary.
   (b) A sabotage script that patches by text must **assert its target is unique** in the
   file; mine exits rather than apply, and that caught two patches whose anchor text had
   moved under this stage's own edits.
9. **The sabotage harness is reusable and is in scratch, not in the tree**: a Python patcher
   with 27 named sabotages plus a shell runner that applies, runs the suite, restores and
   verifies the md5. If the driver wants it kept, it would belong under
   `doc/claude/calculator_batch/` rather than `tests/`, and that is the driver's call — I did
   not add it to the tree.
