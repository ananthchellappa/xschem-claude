# Receipt A3 — close the three blockers and five declarative findings against the issue-1626 fence

Stage **A3** of `doc/claude/calculator_batch/`, worked 2026-09-30 on `fluid-editing` at
`621c1ff5`. **Nothing is committed** — the work is left in the tree for the driver, which
keeps the T1 gate. The Stage A and A2 receipts are dated records and are **not edited**;
every correction to them is in §F6-note and §10 below.

One code fix (**B4**), one real logic defect found while fixing it (**B8** turned out to be
two spellings, not one), eight declarative corrections, and the full claims walk the
previous stage was refuted for not doing (§11). The fence suite stays at **10 checks** —
B4's fix and B8's are measured by **new fixtures inside existing rows**, not new rows, so
nothing in the verdict's published count moves.

---

## B1 — the fence suite's OWN epilogue repeated the false claim F1 removed

**Outcome: fixed. No red is possible — it is a comment. Before and after quoted.**

I read `wvbs_finish` in `tests/headless/wvbs_common.tcl` first, as instructed. Its comment
says, verbatim:

```
# ⚠ THE ORDER OF THE TWO LINES IS
# NOT load-bearing and this comment does not claim it is: `banner_complete`
# uses `regexp -line` over the whole captured body, and only one `RESULT:`
# line is ever emitted here, so "last" is satisfied either way.
```

So the cited authority states the **opposite** of what the citation claimed.

### Before (`tests/headless/test_registered_banner_1626.tcl`, the epilogue above `if {$fail == 0}`)

```
## THE COMPLETION BANNER, then the RESULT line LAST. `summarize_all` publishes a
## case's last `RESULT:` line into the verdict and run_suites.sh greps the last
## one, so the order is not free: see the comment at wvbs_finish in
## tests/headless/wvbs_common.tcl. Only the success path claims completion.
```

### After

```
## THE COMPLETION BANNER, AND `RESULT:` LAST -- which is a claim about being the
## LAST `RESULT:` LINE and NOT a claim about following the banner. THE ORDER OF
## THESE TWO LINES IS FREE, measured: printing `RESULT:` first left all three
## readers green, correctly, because `banner_complete` is `regexp -line` over
## the whole captured body, `summarize_all` keeps a case's last `^RESULT:` line
## of which there is then still one, and run_suites.sh does
## `grep -E '^RESULT' | tail -1`. Nothing in the tree catches a swap and nothing
## should.
## ⚠ AN EARLIER REVISION OF THIS VERY COMMENT CLAIMED THE OPPOSITE -- "so the
## order is not free" -- and cited `wvbs_finish` in tests/headless/wvbs_common.tcl
## as the authority. That comment says, in as many words, "THE ORDER OF THE TWO
## LINES IS NOT load-bearing and this comment does not claim it is". The same
## false clause was removed from both calculator suites by issue 1626 stage A2
## and survived here, in the file doing the editing, until stage A3.
## What DOES cost something is a SECOND `RESULT:` line: the published check count
## silently becomes whatever the last one says, with `counted_failures` and
## `skips` both still 0 and no reader reddening. That is issue **1627**, OPEN and
## unfenced, and its own file carries the dated measurement. This file has ONE
## exit path, so any new one must print its verdict INSTEAD of this one, never as
## well. Only the success path claims completion.
```

"This file has ONE exit path" is measured, not assumed:
`/usr/bin/grep -n 'exit' tests/headless/test_registered_banner_1626.tcl` shows exactly one
executable `exit`, the last line, reached from both arms of the verdict `if`.

---

## B2 — row names: RB6 renamed to its method, and every other row name re-tested

**Outcome: fixed. Three names changed, one comment block changed, seven audited and kept.**

`regression_case_failed` in `tests/banner_rule.tcl` is
`childcode != 0 OR !banner_complete OR banner_died`, measured by reading it. `RB6` touches
only the middle arm, fences one unreachability shape, and covers only `hcases` — exactly
what limit `L6` already says.

| row | before (the offending clause) | after |
|---|---|---|
| `RB6` | "…**so no registered headless arm can be scored a HARNESS failure with all of its own checks passing**" | "`RB6` **rb_nogui_dead** -- find a whole-file no-X early-exit gate in a suite's text, then ask `rb_frag_emitters` whether a banner is reachable INSIDE it, proc calls and the source chain followed -- **answers 0 for every `hcases` entry**; plus the detector's own N controls, M that must be flagged and K that must not. ⚠ ONE unreachability shape, `hcases` only, and only the `banner_complete` arm of `regression_case_failed`: limit L6 … states what it does not cover, and T1's own HARNESS line is the backstop." |
| `RB2` | "the two channels **T1 captures**" | "the two channels **T1's `hcases` and `dcases` arms** capture, **being the only two that are banner-scored**… Static text, arm-blind, generous where the spelling is unknowable: **limits L1-L7**" |
| `RB7` | "…**so a deregistration that nothing notices cannot put issue 1626's defect back**" | "**look up three entry names** in the lists lifted from the driver's own text … **THESE THREE ONLY -- no other entry's registration is asserted anywhere in this file**" |
| `RB5` | "…and **spells no banner regexp of its own**" | "…and **carries no line on which a `regexp` command and the ok-sentinel appear together -- the shape in which a private fourth spelling of the rule would be written. A pattern parked in a variable and used elsewhere is not read: one line, one shape**" |

`RB5`'s was a real instance of the same defect and the lens did not name it: the row is
three `regexp`s over this file's own non-comment text, and the third is
`regexp "regexp[^\n]*<sentinel>"` — a **single-line co-occurrence** test. A private
pattern in a variable, used by a `regexp` on another line, is not detected, so "spells no
banner regexp of its own" claimed the general property and measured one spelling of it.

**Audited and kept unchanged, with why:**

* `RB0` "the lists were lifted from the driver's own text and are non-empty" — three
  `llength > 0` legs. The name is the method.
* `RB1` "every one of the N registered entries resolves to a suite file (both spellings…)"
  — a `file isfile` over every lifted entry; N is `[llength $reg]`, computed at runtime.
* `RB1b` "the driver's two launch lines spell `--script ${hc}.tcl` / `${dc}.tcl` … and
  rb_suite_path preserves an entry's directory components … a NESTED entry included" — two
  legs, both spelled in the name.
* `RB3` "the predicate's own controls: N synthesized suites, M accepted and K rejected" —
  all three figures computed from the fixture list at runtime.
* `RB3b` "a suite whose own text has no banner and whose sourced common prints one is
  accepted (the source chain is followed)" — exactly the two-file fixture it runs.
* `RB4` "every registered suite that scan would REJECT is one this predicate ACCEPTS, and
  at least one must-be-accepted control fixture is rejected by that scan" — the two legs
  verbatim.

---

## B3 — `test_calc_widgets`' comment contradicted itself nine lines apart

**Outcome: fixed in BOTH suites — `test_calc_skeleton` had the same shape, as the task
suspected. No red is possible; before and after quoted.**

### `test_calc_widgets.tcl` before

```
## one silently rewrites the published check count with nothing reddening — issue
## **1627**, OPEN and unfenced, measured on this suite at 244 → 0. This file has
```

### After

```
## one silently rewrites the published check count to whatever the last one says,
## with `counted_failures` and `skips` both still 0 and no reader reddening —
## issue **1627**, OPEN and unfenced. ⚠ THE FIGURE IS DELIBERATELY NOT REPEATED
## HERE: it was measured on this suite, so quoting it would pin this file's own
## moving check total inside a comment nothing re-measures, which is the defect
## the paragraph above refuses. Issue 1627's own file carries it, dated. This
```

### `test_calc_skeleton.tcl` before (same shape, the sibling's number)

```
## `counted_failures` and `skips` both still 0 and no reader reddening —
## measured at 244 → 0 on this batch's sibling suite. That is issue **1627**,
```

### After

```
## `counted_failures` and `skips` both still 0 and no reader reddening. The
## measurement was taken on this batch's sibling suite and is NOT repeated here:
## it is that suite's own moving check total, and quoting it would be the defect
## the parenthesis above refuses. Issue 1627's own file carries it, dated. That
## is issue **1627**,
```

The **1627 citation is kept in both**, which the task required: it is the load-bearing
half. Issue 1627's own file carries `244 → 0` with its date and `tree=621c1ff5` stamp.

---

## B4 — `rb_nogui_dead` reintroduced the gap `rb_emitters` closes. THE CODE FIX.

**Outcome: fixed. The red is a real red, observed on the unmodified tree before any
edit.**

### The red, and it is the strongest evidence in this receipt

The lens's counterexample, rebuilt and **run for real**. `tests/banner_rule.tcl`,
`tests/run_regression.tcl` and `test_headless_guards_xarm_1492.tcl` mirrored into scratch;
the gate's inline `puts "OVERALL: ok"` replaced by a one-line helper proc plus a call:

```
proc xg_skip {name why} { puts "skip: $name -- $why" }
proc xg_banner {} { puts "OVERALL: ok" }
...
if {![info exists ::has_x]} {
  xg_skip "the whole display arm" ...
  puts "RESULT: SKIP (no display)"
  xg_banner
  exit 0
}
```

Run headless against the real binary, armed with a throwaway HOME:

```
$ env -u DISPLAY HOME=<scratch>/fakehome ./src/xschem --nogui --pipe -q --nolog \
    --script <scratch>/mirror/tests/headless/test_headless_guards_xarm_1492.tcl
skip: the whole display arm -- has_x 0 in this process: ...
RESULT: SKIP (no display)
OVERALL: ok

banner_complete=1 banner_died=0 regression_case_failed(0)=0
```

**The banner IS printed and T1 would score the case clean.** The pre-A3 detector, lifted
from the shipped file:

```
rb_nogui_dead(<mirror>/tests/headless/test_headless_guards_xarm_1492.tcl) = 1
gate found = 1
gate body  = |   xg_skip "the whole display arm" \ | ... |   puts "RESULT: SKIP (no display)" |   xg_banner |   exit 0 |
```

`1` means *flagged as unreachable*. A **false red in the rejecting direction** — a standing
red in T1 waiting for someone to factor a gate's banner into a helper. The unpatched
in-tree original answered `0`, which is why nothing in the tree showed it.

### The fix, by symbol

`tests/headless/test_registered_banner_1626.tcl`:

| symbol | what |
|---|---|
| `rb_proc_defs` | **new.** Every `proc` defined in one text, as a flat name/body list, body taken by brace balance. Needed because the whole-file question gets proc bodies for free — they are lines of the file `rb_emitters` walks — and a fragment carries only the call. Handles a braced or a bare argument list. |
| `rb_cmd_words` | **new.** The command words of a fragment: the first word of each line and the first word after each `;`, `{` or `[`, skipping the inside of a quoted word. Used instead of a regexp over the proc's own name (metacharacters) and instead of a substring search (would read a word inside a message string as a call — fixture `g8`). |
| `rb_source_closure` | **new.** Every `.tcl` reachable through a file's `source` chain, transitively, excluding itself. |
| `rb_frag_emitters` | **new.** The fragment answer, by the **same** machinery as the whole-file one: the fragment's own `puts` commands, every file it `source`s (through `rb_emitters`), and transitively the body of every proc it calls that is defined in this file or anywhere on its source chain. |
| `rb_nogui_dead` | **changed.** `rb_scan_text gate $body $txt` → `rb_frag_emitters $repo $path $body`. |
| `RB6`'s `g_fix` | **grew from 4 to 8 controls**: `g5` the lens's counterexample (helper proc in the same file, must NOT be flagged), `g6` a helper in a **sourced common** sourced at file scope (must NOT), `g7` **anti-overshoot** — a gate calling a helper that prints no banner must STILL be flagged, and `g8` **anti-overshoot** — a gate that merely *mentions* a banner-printing helper inside a message string must STILL be flagged. |

### ⚠ The detector over ALL registered entries, before and after, as the task required

A2's receipt records that its own first version of this detector flagged **eight** real
`hcases` entries including `test_op_annot`, so this was measured before committing to the
change, not after.

```
BEFORE (shipped pre-A3 predicate, lifted from the file):
  entries scanned: 96
  FLAGGED (registered): 2
     headless/test_calc_skeleton
     headless/test_calc_widgets
  FLAGGED and in hcases: 0

AFTER (rb_frag_emitters):
  entries scanned: 96
  FLAGGED (registered): 2
     headless/test_calc_skeleton
     headless/test_calc_widgets
  FLAGGED and in hcases: 0
```

**Identical.** The fix removes a false red on a shape nothing in the tree has today and
introduces none. The lens counterexample went `1 → 0`; the unpatched original stayed `0`.

### The green

`RB6` with all eight controls: `g1=1 g2=0 g3=0 g4=0 g5=0 g6=0 g7=1 g8=1`, matching the
wanted vector, `hc_dead` empty.

---

## B5 — "computed by expr: the 13 test_ase_* suites"

**Outcome: fixed (declarative). The claim was measured first.**

```
registered total: 96   hc=90 dc=22
registered test_ase_* : 23
  of which NO literal sentinel on a non-comment line: 13
  with a literal: 10
```

So **23** registered `test_ase_*` suites and 13 of them lack a literal — the definite
article read as all of them. Before / after:

```
-##       - computed by expr:     the 13 test_ase_* suites
+##       - computed by expr:     puts "OVERALL: [expr ...ok...]" -- the shape SOME
+##         registered test_ase_* suites use, NOT all of them. No count here: RB4
+##         prints the real set at runtime, and an earlier revision of this bullet
+##         said "the 13 test_ase_* suites", whose definite article reads as all
+##         the registered `test_ase_*` suites when the shape belongs to only
+##         some of them.
```

⚠ **The same "13" was in a SECOND place the lens did not name** — `RB4`'s own comment
block: *"The day the 13 test_ase_* suites and test_wave_sigbrowser_panes start printing a
literal sentinel"*. Also rewritten to "the suites this row NAMES AT RUNTIME".

---

## B6 — "T1 execs EVERY arm as `> $log 2>@1`", and `regression_case_failed`'s call sites

**Outcome: fixed (declarative), in TWO places. Both facts verified in
`tests/run_regression.tcl` myself.**

```
$ /usr/bin/grep -n 'exec' tests/run_regression.tcl | ...
  1656:    if {[catch {eval exec $tccmd > $tcout} msg opt]} {          <-- tcases, NO 2>@1
  1714:    if {[catch {eval exec $hccmd > $hclog 2>@1} msg opt]} {     <-- hcases
  1857:    if {[catch {eval exec $dccmd > $dclog 2>@1} msg opt]} {     <-- dcases
  1886:  if {[catch {eval exec $xtcmd > $xtlog 2>@1} msg]} {           <-- xschemtest

$ /usr/bin/grep -n 'regression_case_failed' tests/run_regression.tcl
  1001: source banner_rule.tcl   ;# ... (the source line)
  1722:    if {[regression_case_failed $childcode $body]} {            <-- hcases
  1865:    if {[regression_case_failed $childcode $body]} {            <-- dcases
```

**FOUR** exec sites, not three; the `tcases` one has no stderr redirect; and
`regression_case_failed` is called at exactly **two** sites, the two banner-scored arms.
Both sentences rewritten — the header's method bullet and the comment above `RB2`, which
carried the same overstatement with "three exec sites" spelled out.

⚠ **Correction to A2's §F7, recorded HERE and not in that receipt** (it is a dated
record): A2 wrote *"`tests/run_regression.tcl` execs all three arms as `> $log 2>@1`
(three sites)"*. There are four arms and four exec sites; three of them use `2>@1`. A2's
conclusion — that accepting `puts stderr` is correct — is **unaffected**, because both
arms that reach the predicate are among the three.

---

## B7 — "No count is quoted here" in a block that quoted 789 seventeen lines above

**Outcome: fixed (declarative). The number went, not the sentence.**

`789 = 545 + 244` and nothing re-measures it.

```
-## this file sources) cannot score, so 789 passing checks gated NOTHING for a
-## month while `run_suites.sh` and `full_audit.sh` -- the two readers that are not
-## the gate -- reported them green. Same defect as issue 1615's
+## this file sources) cannot score, so every passing check in both suites gated
+## NOTHING for a month while `run_suites.sh` and `full_audit.sh` -- the two
+## readers that are not the gate -- reported them green. (No count here either:
+## the sum was the two suites' then-current totals and both move with the phase;
+## issue 1626's own table carries the dated figures.) Same defect as issue 1615's
```

⚠ **The same 789 was in TWO places in the fence suite the lens did not name** — its
header ("*789 checks, green under run_suites.sh and full_audit.sh*") and `RB7`'s comment
block ("*789 passing Calculator checks gating NOTHING for a month*"). Both rewritten the
same way. The dated claims the lens checked in `run_regression.tcl` — the
`measured 2026-09-30 at 621c1ff5` figures and the `RESULT: ALL PASS (0 checks)` /
`RESULT: SKIP (no X: ...)` output shapes — were left, and I re-measured both this stage
(§3): still exactly those lines.

---

## B8 — a one-argument `puts $v` with trailing whitespace was eaten as a channel word

**Outcome: ACCEPTED, as the stage's own constraint prefers. And it is TWO spellings, not
one — the second is an everyday idiom.**

### The red, measured on the shipped predicate before any edit

```
rb_puts_args {puts $b}    -> {{} var b}      <-- an emitter
rb_puts_args {puts $b }   -> (empty)         <-- NOTHING
rb_puts_args "puts $b\t"  -> (empty)         <-- NOTHING
```

⚠ **And worse, which the finding did not state:**

```
rb_decomment {puts $b ;# c}  -> |puts $b ;|
rb_puts_args {puts $b ;}     -> (empty)      <-- NOTHING
```

So the everyday `puts $v ;# the verdict` — a tail comment, which `rb_decomment` correctly
reduces to `puts $v ;` — was **also** swallowed. That is a far likelier spelling than
trailing whitespace, and it is reachable through the file's own decommenting step.

### The fix, two parts, both independently load-bearing

* `rb_puts_args` consumes a candidate channel word **only when another word follows it**:
  `([ \t])` → `[ \t]+[^ \t]`. The last word of a `puts` is its message, never its channel.
* **new `rb_upto_semi`** — the command is truncated at its first command-terminating
  semicolon, one outside quotes, braces and brackets. Without it, the `;` left by
  `rb_decomment` is read as the message.

Declared in `L3` rather than left silent, and fenced by **two new must-be-accepted
fixtures** `a9` (trailing whitespace) and `a10` (tail comment). `r4` (`puts $fd "…"`) and
`a8` (`puts stderr "…"`) both stay as they were — the channel arm still works.

**No registered suite is affected today**, confirmed: the flagged/accepted sets over all
96 entries are unchanged (§B4, and `RB2` green).

---

## B9 — the command-substitution arm judges each quoted literal independently

**Outcome: DECLARED as limit `L7`, not narrowed. It is in the accepting direction.**

Measured:

```
line: puts [concat "ok: note" "OVERALL: ok"]
  pa = {} cmd {concat "ok: note" "OVERALL: ok"}
    literal |ok: note|    rendered |ok: note|    banner_complete=0
    literal |OVERALL: ok| rendered |OVERALL: ok| banner_complete=1   <-- accepted
what Tcl actually prints: ok: note OVERALL: ok
banner_complete of that : 0                                          <-- rejected
```

`L7`, in the L1–L6 voice, says exactly this, says it was measured, enumerates why judging
the bracket body as a whole would need the command's semantics (`format`, `concat`, `join`,
`string cat`, `subst` all compose differently), and says why accepting is deliberate: the
error costs a missed defect that T1's own `HARNESS:` line still catches on the next run,
where the rejecting direction would cost a standing red in T1.

---

## 1. What I changed, by symbol

| file | what |
|---|---|
| `tests/headless/test_registered_banner_1626.tcl` | **new procs** `rb_upto_semi`, `rb_proc_defs`, `rb_cmd_words`, `rb_source_closure`, `rb_frag_emitters`. **changed** `rb_puts_args` (channel arm requires a following word; truncates at the terminating semicolon), `rb_nogui_dead` (asks `rb_frag_emitters`), the `rb_decomment` comment. **rows renamed to their method**: `RB2`, `RB5`, `RB6`, `RB7`. **fixtures**: `a9`, `a10` on RB3's accept side; `g5`, `g6`, `g7`, `g8` in RB6's battery (4 → 8), plus the `rb_gate_common.tcl` fixture g6 sources. **header**: the method bullet on channels rewritten (B6), the `expr` bullet de-numbered (B5), `L3` extended (B8), `L6` extended (B4), **`L7` added** (B9), the negative-existence sentence restated with what was checked, the 789s removed (B7), the epilogue rewritten (B1). |
| `tests/headless/test_calc_widgets.tcl` | the verdict block's comment only — the restated 1627 figure replaced by a pointer to issue 1627's own dated file (B3). No code. |
| `tests/headless/test_calc_skeleton.tcl` | the same, for the sibling's figure (B3). No code. |
| `tests/run_regression.tcl` | the `dcases` comment block only — `789` removed (B7), and `RB6`'s description updated to the reachability wording plus an explicit "that is one shape on one arm, not a general guarantee". **No list change**; the three entries are byte-identical to A2's. |

Nothing else. **Zero new rows**, so the fence suite's published check count is `10` before
and after this stage — see §5.

---

## 2. The red, per item

| item | red possible? | the red |
|---|---|---|
| B1 | **no** — a comment | before/after quoted; `wvbs_finish`'s contradicting text quoted |
| B2 | **no** — row names | before/after quoted for all four changed |
| B3 | **no** — a comment | before/after quoted, both suites |
| **B4** | **YES, on the unmodified tree** | `rb_nogui_dead` = **1** on a mirrored real suite whose real headless run prints the banner and scores `regression_case_failed 0`. Plus sabotage **S2** below, which reddens `g5=1 g6=1`. |
| B5 | **no** — a count in prose | the measurement (23 registered, 13 without a literal) quoted |
| B6 | **no** — prose | the four exec sites and two call sites quoted from the driver |
| B7 | **no** — a count in prose | quoted |
| **B8** | **YES, on the unmodified tree** | `rb_puts_args {puts $b }` → nothing; `rb_puts_args` of the decommented `puts $b ;` → nothing. Plus sabotages **S1** and **S5**. |
| B9 | **no** — a limit | the measurement quoted, both the predicate's answer and Tcl's real output |

---

## 3. The green, each arm

`tests/headless/run_suites.sh [--nogui] test_registered_banner_1626 test_calc_skeleton
test_calc_widgets`:

```
headless arm:
PASS     | test_registered_banner_1626  run 1/3  RESULT: ALL PASS (10 checks)
PASS     | test_calc_skeleton           run 2/3  RESULT: ALL PASS (0 checks)
SKIP     | test_calc_widgets            run 3/3 (self-skipped: no X — nothing ran)
RESULT: 2/2 runs passed (1 skipped)

display arm:
PASS     | test_registered_banner_1626  run 1/3  RESULT: ALL PASS (10 checks)
PASS     | test_calc_skeleton           run 2/3  RESULT: ALL PASS (545 checks)
PASS     | test_calc_widgets            run 3/3  RESULT: ALL PASS (244 checks)
RESULT: 3/3 runs passed
```

Before → after, per suite per arm: **every figure unchanged** from A2's
(`10 / 0 / SKIP` headless, `10 / 545 / 244` display). That is the point: B4 and B8 change
what the predicate *answers*, not how many questions it asks, and the four new gate
controls and two new accept fixtures live inside `RB6` and `RB3`.

The ten rows, display-arm order: `RB0 RB1 RB1b RB2 RB3 RB3b RB4 RB6 RB7 RB5`.

### The authoring constraint, re-measured on real output

```
column-0 ok-banner lines: 1
column-0 death lines:     0
column-0 RESULT lines:    1
lowercase ^skip: lines:   0
counted shapes:           0
```

---

## 4. What I sabotaged and what it reddened

The suite was byte-restored after every one and the restore **verified by `md5sum`**
(`fab2c7dadcd2e29bdfbf84d259468122` before and after the whole round).

| # | the plausible wrong implementation | what reddened |
|---|---|---|
| **S1** | `rb_puts_args` back to the pre-A3 form (channel word consumed on bare whitespace, no semicolon truncation) — **the code B8 fixes** | `RB3` → `a9=0 a10=0` (exp `a9=1 a10=1`) |
| **S2** | `rb_nogui_dead` back to `rb_scan_text gate $body $txt` — **the code B4 fixes** | `RB6` → `g5=1 g6=1` (exp `g5=0 g6=0`). The two false reds, on fixtures, with no tree change needed. |
| **S3** | `rb_frag_emitters` counts a *call* as a banner without reading the called proc's body — the over-generous way to "follow proc calls" | `RB6` → `g7=0` (exp `1`). This is why `g7` exists. |
| **S4** | proc-call detection by **substring** (`string first $n $f`) instead of command position | `RB6` → `g8=0` (exp `1`). A banner-printing helper merely *named inside a message string* would have counted as called. This is why `rb_cmd_words` is not a substring search. |
| **S5** | only `rb_upto_semi` removed, the channel-arm fix kept | `RB3` → `a10=0` (exp `1`). Both halves of B8's fix are independently load-bearing; neither subsumes the other. |

Every new fixture has been observed red and every new piece of machinery observed
load-bearing. A2's nine sabotages were not re-run: nothing in this stage touched
`rb_var_literals`, `rb_suite_path`, `RB7`'s legs or the registration lists, and `RB3`'s
six reject fixtures all stayed rejected throughout (printed in every run above).

---

## 5. The trailer delta, RE-DERIVED over my own output

**A2's figure is not quoted.** `t1_carry_line` and `summarize_all` were lifted out of
`tests/run_regression.tcl`'s own text by the tree's idiom (`\nproc <name> ` to the next
column-0 brace), `tests/banner_rule.tcl` sourced beside them, and run over logs captured
**exactly as T1 captures them** — the `hcases` arm as
`--nogui --pipe -q --script X.tcl > log 2>&1`, the `dcases` arm through
`devdisplay.sh exec` on `:99` with `GUI_GATE=0` and a `--logdir` of its own.

`summarize_all`'s own arms, printed from the lifted body:

```
ARM: if { [regexp {FAIL$} $line] || [regexp {GOLD\?$} $line] || [regexp {RESULT\?$} $line] || [regexp {^FATAL} $line]} {
ARM: } elseif { [regexp {^(NOGOLD|NODISPLAY)} $line] } {
ARM: } elseif { [regexp {^skip:} $line] } {
ARM: } elseif { [regexp {^RESULT:} $line] } {
ARM: } elseif { [banner_complete $line] && [regexp {\([^)]*\)} $line] } {
```

Per log, and raw:

```
fence.hc.log                  blocks+1 counted+0 skips+0
test_calc_skeleton.dc.log     blocks+1 counted+0 skips+0
test_calc_widgets.dc.log      blocks+1 counted+0 skips+0
TOTALS: blocks=3 counted_failures=0 skips=0

fence.hc.log               ^skip:=0 ^SKIP=0 nocase=0 counted-shapes=0 ^RESULT:=1 banner_complete=1
test_calc_skeleton.dc.log  ^skip:=0 ^SKIP=0 nocase=0 counted-shapes=0 ^RESULT:=1 banner_complete=1
test_calc_widgets.dc.log   ^skip:=0 ^SKIP=0 nocase=0 counted-shapes=0 ^RESULT:=1 banner_complete=1
```

The blocks it wrote — what the verdict file will contain:

```
test_registered_banner_1626.log
RESULT: ALL PASS (10 checks)
Total num fail: 0
test_calc_skeleton.disp.log
RESULT: ALL PASS (545 checks)
Total num fail: 0
test_calc_widgets.disp.log
RESULT: ALL PASS (244 checks)
Total num fail: 0
```

`wc -l` of that = **9**.

**Delta against the baseline `cases=113 blocks=112 counted_failures=0 skips=8` at
`f3d60af9`: cases +3, blocks +3, counted_failures +0, skips +0, `wc -l` +9.**
Expected trailer **`cases=116 blocks=115 counted_failures=0 skips=8`**.

⚠ **`skips=` is derived, not predicted.** All three real logs carry **zero** `^skip:`
lines **and** zero `^SKIP` lines **and** zero case-insensitive `^skip` lines — so there is
no uppercase/lowercase trick hiding here, the trap that caught both an adversarial verifier
and the driver on issue 1625. **Read the trailer.**

**My A3 rows move nothing in the trailer and nothing in the published check counts
either** — the renamed row names and new fixtures live inside the three blocks above, and
the three `RESULT:` lines are identical to A2's.

---

## 6. Neighbouring suites, both arms

The same set the two prior stages ran. The repo is at a **29-character** path and
`test_op_annot` passes, as CLAUDE.md's short-path rule requires.

```
headless arm:
PASS | test_audit_classifier              RESULT: ALL PASS (75 checks)    # section K intact
PASS | test_scratch_home_note             RESULT: ALL PASS (22 checks)    # C1 lifts summarize_all
PASS | test_regression_concurrency_1476   RESULT: ALL PASS (46 checks)
PASS | test_issue_stamp                   RESULT: ALL PASS (102 checks)
PASS | test_snprintf_fmt_1608             RESULT: ALL PASS (48 checks)
PASS | test_op_annot                      RESULT: ALL PASS (486 checks)   # V57, the dcases loop line
PASS | test_home_isolation                RESULT: ALL PASS (116 checks)   # G2, new-file launcher scan
RESULT: 7/7 runs passed

display arm:
PASS | test_audit_classifier              RESULT: ALL PASS (75 checks)
PASS | test_scratch_home_note             RESULT: ALL PASS (22 checks)
PASS | test_regression_concurrency_1476   RESULT: ALL PASS (46 checks)
PASS | test_issue_stamp                   RESULT: ALL PASS (102 checks)
PASS | test_snprintf_fmt_1608             RESULT: ALL PASS (48 checks)
PASS | test_op_annot                      RESULT: ALL PASS (493 checks)   # +1 skip: W23, the known run_suites.sh artefact
PASS | test_home_isolation                RESULT: ALL PASS (116 checks)
RESULT: 7/7 runs passed
```

`test_op_annot` 493/486 reproduces A2's figures exactly, including its one display-arm
`skip:` line (`W23 … no action log -- run with --logdir`), which is a hand-run artefact:
T1's `dcases` loop passes `--logdir`.

And because I edited `tests/run_regression.tcl` a second time after that batch, the three
suites that parse the driver's own text were re-run:

```
PASS | test_scratch_home_note             RESULT: ALL PASS (22 checks)
PASS | test_regression_concurrency_1476   RESULT: ALL PASS (46 checks)
PASS | test_selflog_grep_guard            RESULT: ALL PASS (390 checks)
RESULT: 3/3 runs passed
```

`info complete` over `tests/run_regression.tcl`'s whole text returns **1**, and the three
new entries still grep to 4 occurrences (3 list entries + 1 prose mention).

---

## 7. `git status --short` at the end

```
 M doc/claude/calculator_batch/PLAN.md
 M doc/claude/issues/NUMBERING.md
 M doc/claude/specs/calculator.md
 M src/calculator.tcl
 M tests/headless/test_calc_skeleton.tcl
 M tests/headless/test_calc_widgets.tcl
 M tests/run_regression.tcl
?? .xschem/
?? doc/claude/calculator_batch/CREW_BRIEF.md
?? doc/claude/calculator_batch/LEDGER.md
?? doc/claude/calculator_batch/receipts/A-register-1626.md
?? doc/claude/calculator_batch/receipts/A2-fence-fixes-1626.md
?? doc/claude/calculator_batch/receipts/A3-close-blockers-1626.md   <-- this file
?? doc/claude/code_analysis/open_feature_build_survey_2026_09_30.md
?? doc/claude/issues/1626-….md
?? doc/claude/issues/1627-….md
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_registered_banner_1626.tcl
```

**The set is identical to A2's apart from this receipt. Nothing new appeared.**
Mine are exactly five: the fence suite, `tests/run_regression.tcl`, the two calculator
suites, and this receipt. **Checked by mtime, not by intention** — my four code files carry
20:53–21:08; `PLAN.md` 19:12:05, `specs/calculator.md` 19:12:32, `src/calculator.tcl`
19:19:52 and `NUMBERING.md` 19:34:04 are all older than my first edit and are the driver's.

`git diff --stat tests/` shows **comments only** in the three tracked files
(`test_calc_skeleton.tcl` +50 / `test_calc_widgets.tcl` +37−1 / `run_regression.tcl`
+57−2 across both stages; this stage changed no line of executable Tcl in any of the
three). All executable change is in the untracked fence suite.

**No probe wrote anything.** This stage ran no `xschem save` / `saveas`; nothing under
`xschem_library/`, `tests/headless/gold/` or any tracked fixture was touched. All scratch
is under `…/scratchpad/A3-close-blockers/` (the mirror tree, the fixture probes, the
backups, a throwaway `fakehome`, the T1-shaped captures). The real dev display `:99` was
**attached to, never started or stopped**. No T1 run.

⚠ One environment note for whoever repeats §5: `devdisplay.sh exec` resolves its state dir
from `$HOME/.claude/xschem_dev_display`, so capturing a `dcases`-shaped log with an
overridden `HOME` fails with `:99 is not running` until `XSCHEM_DEVDISPLAY_DIR` is passed
explicitly — which is what T1 itself does (`run_regression.tcl` reads that variable). I
passed the real state dir read-only and started/stopped nothing.

---

## 8. What I did NOT do, and why

* **No T1 run** — the driver's job; a concurrent run plus my hand-run suites can redden a
  gate. §5 is the unit-level substitute for *scoring*, not for *running*.
* **Nothing committed, pushed or stashed.**
* **I did not narrow `L7`.** Explicitly instructed not to, and it is the right call: the
  error is in the accepting direction and narrowing it risks a standing red.
* **No per-arm reachability analysis.** Still out of scope; `L6` says so and now also says
  what the one shape it *does* read now follows.
* **I did not fence issue 1627.** Still a run-time property whose honest home is inside the
  driver (that issue's own §"Still open"). Both suites and this file carry the citation.
  Measured again as information: each of my three T1-shaped logs has `^RESULT:` = 1.
* **I did not register `test_audit_classifier`.** Still in neither list; out of scope and
  untaken for the third stage running. It is issue 1627's open item 2.
* **I did not put the gate counterexample into `RB3`'s battery**, which is where the task
  named it. `RB3`'s fixtures feed `rb_emitters`, which never sees a gate and has no
  "flagged" verdict to assert; `RB6`'s `g_fix` is the battery with a must-be-flagged side.
  The counterexample is `g5` there, with `g6`/`g7`/`g8` beside it. An internal engineering
  call, named here rather than queued.
* **I did not re-run A2's nine sabotages.** Nothing this stage touched their targets, and
  all of A2's fixtures were green in every run above. §4 says what that does and does not
  cover.
* **Nothing was verified by eye.** Every claim here is a row, a sourced predicate, or
  quoted command output. No `look` debt incurred and none needed.

---

## 9. What I got wrong, and what corrected me

**Four things, and the second is the one that would have shipped a fence measuring
nothing.**

1. **I read B8 as one spelling and it is two.** The finding says
   `rb_puts_args {puts $b }` with trailing whitespace. I probed `rb_decomment` beside it
   out of habit and found that `puts $v ;# comment` — which `rb_decomment` correctly
   reduces to `puts $v ;` — was swallowed by the *same* bug, and that spelling is far
   likelier than a stray trailing space. A fix keyed only to whitespace (`[ \t]+[^ \t]`)
   leaves it broken, because the `;` satisfies `[^ \t]`. `rb_upto_semi` is the second
   half, and **sabotage S5 proves neither half subsumes the other**. What corrected me was
   probing the adjacent proc rather than only the one the finding named.

2. **My first `rb_frag_emitters` would have made `g7` and `g8` impossible to write wrong,
   and I nearly shipped it without them.** The obvious over-generous implementation is "the
   gate calls a proc, so a banner is reachable" — and my first instinct for the anti-vacuity
   control was the `rb_cmd_words` filter, which **reddens nothing**: dropping the filter
   entirely changes no answer on this battery or on the 96 registered entries, because the
   calculator gates call no file-defined proc at all. The filter is a *precision*
   improvement that the obvious battery does not fence. `g7` (a called helper with no
   banner) and `g8` (a helper merely named inside a message string) are what make S3 and S4
   redden. What corrected me was asking, for each new line of the predicate, *which fixture
   goes red if I delete this* — and writing the fixture when the answer was "none".

3. **I started to fix B5 and B6 in the header only.** Both overstatements were in **two**
   places each: "the 13 test_ase_* suites" was also in `RB4`'s comment block, and
   "execs every arm … three exec sites" was also in the comment immediately above `RB2`.
   `789` was in **three** places across two files. What corrected me was grepping the files
   for every digit in every comment line and reading each hit, rather than editing the
   sentences the lens quoted. **That is the method the full walk in §11 exists to force**,
   and it is exactly the failure A2 was refuted for.

4. **`RB5`'s name has the RB6 defect and the lens did not list it.** The task said not to
   assume RB6 was the only one, and it was right: `RB5` claimed "spells no banner regexp of
   its own" while measuring a **single-line co-occurrence** of the word `regexp` and the
   sentinel. A pattern in a variable, used on another line, is invisible to it. Renamed to
   the method. What corrected me was reading each row's *code* beside its name instead of
   judging the name on its own.

---

## 10. Corrections to the earlier receipts, recorded here as the brief requires

* **A2 §F7** said *"`tests/run_regression.tcl` execs all three arms as `> $log 2>@1`
  (three sites)"*. There are **four** arms and **four** exec sites; the `tcases` one is
  `eval exec $tccmd > $tcout` with no stderr redirect. A2's conclusion about accepting
  `puts stderr` stands, because both arms that reach `regression_case_failed` are among the
  three that do redirect. The receipts are left as the dated records they are.
* **A2 §F1** fixed the "or reordering" clause in both calculator suites and **left it
  standing in the fence suite it was editing** (B1). Noted, not edited.
* **Stage A §6** and **A2 §9.3** between them put "FOUR different mechanisms" then "six
  spellings" into the tree; neither number is in any file now. `RB4` prints the set at
  runtime.
* Both receipts' quoted check counts for the fence suite (`7`, `8`, `9`, `10`) are correct
  **as dated observations** and are no longer restated inside the suite's own comments; the
  suite now points at the receipts instead.

---

## 11. THE FULL CLAIMS WALK — every comment sentence, every row name, every limit

Required field. "How I checked" is a command, a row, or a quoted file, never "it reads
right".

### Limits L1–L7, every one measured on a purpose-built fixture

```
L1  puts "OVERALL: $v"                       accepted=1   (want 1)
L2a $v set in a SOURCED file, printed here   accepted=0   (want 0 -- same-file only)
L2b $v from ANOTHER variable                 accepted=0   (want 0 -- one level)
L3  -- see fixtures a8 (stderr), a9, a10 (accepted) and r4 (channel variable, rejected)
L4a a puts split across a CONTINUATION line  accepted=0   (want 0)
L4b two puts -nonewline halves               accepted=0   (want 0)
L5a banner inside an `if 0` block            accepted=1   (want 1 -- dead code not detected)
L5b banner in a proc NOTHING calls           accepted=1   (want 1)
L6  -- see RB6's eight controls, and the before/after over all 96 registered entries (§B4)
L7  puts [concat "ok: note" "<banner>"]      accepted=1   (want 1 -- deliberately generous)
L7  what Tcl really prints there             |ok: note OVERALL: ok|  banner_complete=0
```

Every limit behaves **exactly** as declared. `L2`'s "in-order concatenation" clause is held
by fixture `a7` and sabotages S3/S4 of stage A2.

### Row names: method or coverage?

All ten re-read against their own code. Four renamed (§B2). The six kept are listed there
with the legs each name describes.

### Every factual claim in the file's comments

| claim | how I checked |
|---|---|
| "`banner_complete` … is the ONLY Tcl reader … and the only one run_regression.tcl sources" | `/usr/bin/grep -n 'source banner_rule' tests/run_regression.tcl` → exactly 1 (line 1007). The "only reader" half is `banner_rule.tcl`'s own header restated; 40+ Tcl files **source** it, which is consistent with "only implementation". |
| "A suite that never emits a line it accepts is scored `HARNESS: … (exit=0, OVERALL_ok=0, died=0)`" | the two real `puts $af "HARNESS: …"` lines in the `hcases` and `dcases` loops, read. The illustrative shape omits the ` -- <why>: FAIL` tail; it is inside a `##` comment and cannot forge anything. |
| "Issue 1615 cost a red gate at `809c03d1`" | documentary, CLAUDE.md and `wvbs_common.tcl`'s own comment. |
| "section K … THAT SUITE IS IN NEITHER `hcases` NOR `dcases`" | lifted both lists, searched: `in hcases: 0`, `in dcases: 0`. Also `/usr/bin/grep -c 'hcases\|dcases' tests/headless/test_audit_classifier.tcl` → **0**. |
| "NOTHING FOUND IN THE TREE CHECKED THE CONVERSE" | **restated this stage as the negative-existence claim it is**, naming what was looked at (section K never mentions the lists; V57 asserts membership without asking about scorability) and saying plainly that no row re-measures it. |
| "row X1 of test_snprintf_fmt_1608.tcl" | `/usr/bin/grep -c '"X1 '` → 1, and its name is about citation-checking, which is the point being cited. **CLAUDE.md records five shipped comments citing rows that do not exist**; this one does. |
| "the lock K17 holds for run_regression.tcl" | `check "K17 run_regression sources the shared rule and keeps no private copy"` exists in `test_audit_classifier.tcl`. |
| "a literal: … (most suites)" | mechanism census over all 96 registered entries: **literal 93, variable 3**. "most" holds; no number is in the comment. |
| "a counted literal … (test_pdk_launcher)" | `test_pdk_launcher.tcl` emits `puts "OVERALL: ok ($npass checks)"`, and it is registered. |
| "computed by expr … SOME registered test_ase_* suites" | 23 registered `test_ase_*`, 13 without a literal. **Fixed this stage** (B5). |
| "from a sourced file: `wvbs_finish` in `wvbs_common.tcl`" | `test_wave_sigbrowser_panes` is registered and sources `wvbs_common`; `RB3b` holds the mechanism on a fixture. Note the label asymmetry: `rb_scan_text` labels that hit `literal` and the *file* is what records the source chain — which is what `RB3b` asserts. |
| "from a variable: `hilight_hier_oracle` and two siblings" | exactly **3** registered suites use the `variable` mechanism: `hilight_hier_oracle`, `hilight_hier_dump_replay`, `hilight_xwin_sync_headless`, each `set summary [expr …]` then `puts $summary`. |
| "two idiomatic spellings nothing registered uses TODAY" (a6 command substitution, a7 append) | census: **0** registered suites have a `command` emitter. For `append`: four registered suites `append` into a variable that is `puts`-printed, and **none of those variables ever holds a banner** (the `variable` mechanism count is 3 and all three are `set`+`expr`). |
| "the four bare-name entries" (rb_suite_path) | lifted the lists and counted entries with no `/`: **4** — `buried_hilight`, `hilight_hier_dump_replay`, `hilight_hier_oracle`, `hilight_xwin_sync_headless`. |
| "Both Calculator suites open with an unconditional file-scope `if` … print something, flush, exit" | read both: `test_calc_skeleton.tcl` and `test_calc_widgets.tcl` each have `if {![info exists ::has_x] || [info commands winfo] eq {}} {` at file scope with `puts` / `flush stdout` / `exit 0`. |
| "`test_headless_guards_xarm_1492` is the in-tree example it must not flag" | `rb_nogui_dead` on the real file = **0**, before and after the fix; it is a `dcases` entry (`in hcases: 0`). |
| "`rb_decomment` … reject fixtures r1 and r2 are the two spellings" | **reworded this stage** from "one of the two sabotages this file is fenced against", which was a count about something else. `r1`/`r2` are green in every run. |
| "A banner whose only spelling is a failure one is … rejected" (rb_render) | fixture `r5` (`puts "OVERALL: notok"`) → rejected, every run. |
| "T1 execs … `> $log 2>@1`" / "three exec sites" | **fixed this stage in two places** (B6): four exec sites, `tcases` without the redirect, `regression_case_failed` at exactly two call sites. |
| "rb_suite_path preserves … four spellings, one of them nested" | **fixed this stage**: the fixture list has **two** nested spellings. The count is now gone; `RB1b` prints what it resolved. |
| "`RB4` … the 13 test_ase_* suites and test_wave_sigbrowser_panes" | **fixed this stage** (B5, second site). |
| "`RB6` … MEASURED … the fence said `ALL PASS (8 checks)`" | **reworded this stage** to "reported ALL PASS", attributed to stage A2, because that count moves with the row's own fixtures. |
| "the sourced-common mechanism … as the 14 registered suites that take it from a common require" | **FALSE and fixed this stage** — the lens did not name it. It conflated the sourced-common set (1 registered suite) with the naive-false-red set (printed at runtime by `RB4`). |
| "789 checks" (header) / "789 passing Calculator checks" (RB7 block) / "789 passing checks" (run_regression) | **all three removed this stage** (B7). The dated figures live in issue 1626's own table. |
| "This file has ONE exit path" (epilogue) | `/usr/bin/grep -n 'exit'` → one executable `exit`, the last line. |
| "AUTHORING CONSTRAINT: no check NAME or printed value carries the banner or death text at column 0" | measured on real output: column-0 ok-banner lines **1**, death lines **0**, `RESULT:` lines **1**. |
| "NO LITERAL BRACE … IN A COMMENT INSIDE A PROC BODY" | the file parses and all ten rows run; every brace in my five new procs' comments is absent or spelled by `[format %c …]`. |
| "`measured 2026-09-30 at 621c1ff5` … headless arm prints `RESULT: ALL PASS (0 checks)` … `RESULT: SKIP (no X: …)`" (run_regression) | re-measured this stage on both arms: exactly those two lines. Dated claims left as dated. |
| "`summarize_all`'s own arm is `regexp {^skip:}`" (run_regression) | printed from the lifted proc body (§5), and `/usr/bin/grep -n 'regexp {\^skip:}'` → line 960. |
| "`RB6` asserts … no `hcases` entry … prints no banner" (run_regression) | **updated this stage** to the reachability wording, plus "that is one shape on one arm, not a general guarantee". |

**Nothing is left in the file that claims more than the code does, as far as this walk
reached.** What the walk cannot settle is the one negative-existence claim, and the file
now says so in its own header rather than asserting it.

---

## 12. What the next stage must know

1. **`rb_nogui_dead` now follows proc calls and the source chain inside a gate.** A gate
   whose banner lives in a helper, or in a sourced common, is correctly **not** flagged
   (`g5`, `g6`); a gate that calls a helper printing no banner, or merely names one inside
   a message string, **is** (`g7`, `g8`). The flagged set over all 96 registered entries is
   unchanged at exactly the two calculator suites, 0 in `hcases`.
2. **`rb_puts_args` now truncates at the terminating semicolon.** If you extend it, keep
   `rb_upto_semi` and keep the channel arm requiring a following word; `a9`/`a10` and
   sabotages S1/S5 are what hold them.
3. **`L7` is a declared accepting-direction limit, not a bug to fix.** Narrowing it needs
   the called command's semantics and risks a standing red. If you ever do narrow it,
   measure over all registered entries **before** committing to the row — that habit is
   what caught A2's eight-case near-miss and my own `rb_cmd_words` dead control.
4. **Row names in this file are method names.** If you add a row, name what it *does*.
   `RB5` and `RB6` both had to be renamed because their names claimed the consequence.
5. **Issue 1627 is still open and unfenced** and now cited in three places (both calculator
   suites and the fence epilogue) **without its figure restated**, because it was measured
   on a suite whose total moves. Phase 2 adds rows to `test_calc_widgets`, so a third exit
   path in either suite must print its verdict **instead of** one of the existing two.
6. **`test_audit_classifier` is in neither list** for the third stage running — issue 1627's
   open item 2. Section K gates nothing today.
7. **The trailer delta is cases +3, blocks +3, counted_failures +0, skips +0** and the three
   published `RESULT:` lines are `10` / `545` / `244`. Re-derived here from
   `summarize_all`'s own arms over real T1-shaped logs. **Read the trailer anyway.**
8. **Issue 1626's file still says `open=3`.** Items 1 and 2 are done; item 3 was and remains
   out of scope. The driver should re-stamp.
