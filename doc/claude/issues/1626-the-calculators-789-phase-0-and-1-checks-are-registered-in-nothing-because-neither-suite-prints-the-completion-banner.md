# 1626 — the Calculator's 789 phase-0/1 checks are registered in nothing, because neither suite prints the completion banner

**STAMP:** `v1 claim=fixed tree=621c1ff5 stamped=2026-09-30 fix=taken open=2 scope=banner-complete-arm`

Status: **FIXED**, 2026-09-30, in three stages (A, A2, A3) · Branch: `fluid-editing`
`scope=` is set because the fence this issue's item 2 asked for covers **one of the three arms** of
`regression_case_failed`, and nothing else carries the other two — see "Still open" for the exact
boundary, measured rather than asserted.
Related: batch `doc/claude/calculator_batch/` (this blocks its Phase 2); issue **1615**, the same
defect in the `test_wave_sigbrowser*` family; `tests/banner_rule.tcl`, which states the rule;
`doc/claude/code_analysis/t1_runs_84_of_418_headless_suites.md`.

## The measurement, as it stood at `621c1ff5` before the fix

⚠ **This section and the two after it are the ORIGINAL measurement and are written in the present
tense of that moment.** They describe the tree at `621c1ff5`, not the tree now — "What shipped"
below is what changed. They are left in their own tense rather than retro-fitted, because the
diagnosis is the valuable part and rewriting it to agree with today's tree would destroy the
evidence that it was measured rather than assumed.

Both Calculator suites pass, and neither is run by T1:

| suite | display arm | headless arm | `banner_complete` on its real output |
|---|---|---|---|
| `test_calc_skeleton` | `ALL PASS (545 checks)` | `ALL PASS (0 checks)` | **0** |
| `test_calc_widgets` | `ALL PASS (244 checks)` | self-skips, `RESULT: SKIP (no X …)` | **0** |

`/usr/bin/grep -n 'calc' tests/run_regression.tcl` returns nothing: the suites are in neither
`hcases` nor `dcases`. **789 passing checks gate no commit.**

## Why, mechanically — and it is not an oversight

`banner_complete` in `tests/banner_rule.tcl` is the **only Tcl reader**, and the only one
`run_regression.tcl` sources. Its pattern accepts one spelling and that file's own header says it
*"implements no `RESULT: ALL PASS` spelling at all"*. Both Calculator suites end with

```tcl
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILED ($npass passed)" }
```

and print the `OVERALL:` sentinel **zero** times. They source no common that prints it either —
which is why the table above is a runtime measurement of their actual output and not a grep of
their text. So registering either one today would score

```
HARNESS: … did not complete cleanly (exit=0, OVERALL_ok=0, died=0)
```

**with every one of its own checks passing**, which is exactly what issue 1615's first gate did at
`809c03d1`. The suites are **structurally unregisterable**, not merely unregistered, and that is a
different defect with a different fix.

`run_suites.sh` and `full_audit.sh` carry their own EREs and both accept `RESULT: ALL PASS` — so
the two readers that can see these suites are the two that are not the gate. Every green run
recorded in this batch's five Phase-0/1 receipts came from one of those two.

## ⚠ The count in this file's title is the only count in it

A text census said *"268 of 421 suites print `RESULT` and never `OVERALL`"*. **Do not quote that
number**, and do not quote the correction this file first carried either. The grep measures file
text; the defect is a property of output. The useful finding is the **shape** — a suite's epilogue
must be checked against `banner_complete`, never against `run_suites.sh` — and `789` is quoted
because it is the sum of two numbers this file's own table re-measures.

⚠ **This file's first revision said "7 registered suites get the sentinel from a sourced common
their own text does not contain", and that was wrong about the number AND about the mechanism.**
The `7` came from a grep that counted the sentinel **inside comments** as present, over only
`tests/headless/test_*.tcl` — which excludes the four entries registered by **bare name** in
`tests/`. Measured properly by Stage A, over all registered entries, ignoring comments: **16**
registered suites emit no literal sentinel, and they do it **three different ways** —

* **13** compute it: `puts "OVERALL: [expr {$fail ? {notok} : {ok}}]"`, all `test_ase_*`;
* **3** build it into a variable and print that: `set summary [expr {$nfail ? … : "OVERALL: ok"}]`
  then `puts $summary` — the three bare-name `hilight_*` entries;
* **1** takes it from a sourced common: `test_wave_sigbrowser_panes`.

So the sourced common — the mechanism this file originally named, and the one issue 1615 made
famous — is the **minority** case, one suite in sixteen. **A fence that handled only it would have
shipped a standing red in T1 on the other fifteen**, and Stage A's first prototype did exactly that
on three of them before its own control rows caught it. `RB4` in
`tests/headless/test_registered_banner_1626.tcl` re-measures the figure every run instead of
quoting any of these numbers.

## What shipped (stages A, A2, A3)

* **`tests/headless/test_calc_skeleton.tcl`, `tests/headless/test_calc_widgets.tcl`** — an
  `OVERALL: ok ($npass checks)` line added **additively** on the **success path only**, with
  `RESULT:` kept last. Check counts unchanged on every arm, which is what makes "additive" a
  measurement rather than an adjective. Each suite's no-display early exit deliberately gets **no**
  banner: it ran nothing, and a path announcing completion when nothing ran would be a worse defect
  than this one.
* **`tests/run_regression.tcl`** — both suites registered in **`dcases` alone**. Not `hcases`:
  `test_calc_widgets` self-skips without X and `test_calc_skeleton`'s headless arm reports **0
  checks**, so an `hcases` entry would spend a whole case measuring nothing.
* **`tests/headless/test_registered_banner_1626.tcl`** — new, in `hcases`, ten rows. It lifts both
  registration lists from the driver's own text at runtime and asks whether each registered suite
  **can** emit a line `banner_complete` accepts, resolving the `source` chain transitively, a
  command-substitution word, and one level of same-file `set`/`append`.

**Measured delta:** cases +3, blocks +3, `counted_failures` +0, `skips` +0 — derived from
`summarize_all`'s own regexp arms over real captured output, not predicted. All three suites emit
**no** skip announcement at all, in any case, on any arm, so there is no uppercase/lowercase
subtlety hiding here of the kind that misled two parties on issue 1625.

## ⚠ It took three stages, and the reason generalises

Stage A fixed the defect. Stage A2 closed seven findings from three adversarial lenses. Stage A3 was
convened because A2's **claims** lens returned `REFUTED`: A2 had reproduced, inside the fence suite
itself, the very defect it was convened to remove — a comment asserting that the `RESULT:`/banner
**order** mattered, when the same stage's receipt had measured that it does not, citing as its
authority a comment in `wvbs_common.tcl` that says the opposite in as many words.

**Three consecutive stages, each tasked with auditing the previous one's claims, each shipped at
least one sentence that overstated its code.** That is not carelessness three times. **A prose claim
is the one artefact here that nothing re-runs**, so it is the only place an error survives a green
suite, a sabotage round *and* an adversarial lens. Everything else gets re-executed; sentences do
not. That is the mechanism behind CLAUDE.md's rule that either a row asserts a thing or the sentence
drops it, and it is why A3 was required to walk every remaining sentence, row name and limit and
state how each was checked — the step A2 omitted.

Four near-misses were caught by **measuring before claiming**, each of which would have shipped a
standing red in T1:

1. Stage A's first predicate handled only the literal sentinel spelling and false-redded **three**
   real suites that build the banner into a variable.
2. Stage A2's first arm detector had no `exit` requirement and flagged **eight** real `hcases`
   entries, `test_op_annot` among them.
3. `RB4` was twice about to assert something vacuously true — once reporting 94 false reds of 95,
   once a property already entailed by the row above it.
4. `RB5` used its own stripper, which dropped whole-line comments only, so appending
   `set z 1 ;# regexp -line {^OVERALL: ok} $body` turned that row **red on a comment**. It now uses
   `rb_code`, the file's own decommenting reader. Verified both directions: with the poison appended
   the old stripper answers 1 (red) and the new one 0; on the unmodified file both answer 0.

## Still open (open=2)

### 1. Item 2 is **PARTLY** closed, and this is the exact boundary

Measured independently of the stage receipts, by lifting the fence's own predicate and running it
over the lifted lists. The fence is green at `ALL PASS (10 checks)` on **both** arms.

**Closed.** A structural row over the lists exists, is itself an `hcases` entry, and so gates every
commit; the lists are lifted from the driver's own text at runtime (96 entries, `hcases` 90,
`dcases` 22). All 96 resolve to files and none lacks an emitter. Mechanism census over the 96:
literal 93, variable 3, command-substitution 0 — and a one-file text scan would false-red **14** of
them, so the resolved predicate is not interchangeable with a grep. Deregistration is asserted for
**three named entries** (`RB7`). One arm-dependent unreachability shape is asserted empty over
`hcases` (`RB6`). Anti-vacuity is real: `RB0`, `RB3`'s fixture battery, `RB3b`'s source chain,
`RB6`'s gate controls, and `RB4`'s two legs.

**Not closed.** Per-arm reachability in general (limit `L6`) — only the one gate shape is read; a
suite made headless-unreachable by a file-scope `return`, a differently spelled gate, or a banner in
a proc only the display arm calls is not detected. The **`dcases` arm is not covered by `RB6` at
all**. The other two arms of `regression_case_failed` — `childcode != 0` and `banner_died` — are
unfenced, so *"can T1 score this"* is roughly one third fenced; hence this file's `scope=`. Dead
code (`L5`) counts as emittable. The registered-entry **count** is not asserted: `RB1` prints 96 as
information, and only three names are asserted, so 93 entries could be deregistered with nothing
here reddening.

⚠ **Two limits run in the REJECTING direction** and are now signed as such in the suite's header,
because that is the direction that reddens T1: `L2`'s sourced-variable case and `L4`'s continuation
case report a suite that *really does* print an acceptable line as having no emitter. Neither shape
is used by any registered suite today, which is the only reason the fence is green — not a property
of the predicate. **Anyone who hits one has found a fence defect, not a suite defect.**

### 2. The unregistered tail

Explicitly not this issue. CLAUDE.md's bounded rule — *a suite you add a fence to, you register in
the same commit* — is the adopted reading, and this file keeps to the Calculator. Two live instances
are carried elsewhere rather than here: **`test_audit_classifier` is in neither list**, so section K
— the tree's only lock holding the three banner readers in agreement — gates nothing (issue **1627**
open item 2); and the run-time property *"exactly one `^RESULT:` line per run"* is issue **1627**
item 1.
