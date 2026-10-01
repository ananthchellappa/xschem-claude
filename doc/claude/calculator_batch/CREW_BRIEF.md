# CREW BRIEF — calculator_batch

Read this whole file before touching anything. Then read the `PLAN.md` stage section you were
handed, and **the previous receipt in `receipts/`** — that is where corrections to the plan live,
and the plan itself may be wrong where a receipt contradicts it.

## What this batch is

The **waveform Calculator**, benchmarked against Cadence's: a toplevel where you select signals,
type an expression, and plot or evaluate it. Spec `doc/claude/specs/calculator.md` (requirements
R1xx–R7xx), work breakdown `PLAN.md` (70 steps, phases 0–10), explainer
`doc/claude/code_analysis/viva_calculator_explained.md`.

**The batch was dormant from 2026-09-01 to 2026-09-30.** Phases 0 and 1 landed —
`src/calculator.tcl` is 136 KB and the window opens looking like the reference — and the receipts
stop at Phase 1. Phase 2 is *"the buffer comes alive"*.

### ⚠ THE SINGLE MOST IMPORTANT FACT, and it is the spec's own §0 heading

> **Most of the engine already exists. Do not write an expression evaluator.**

`raw_add_vector()` → `plot_raw_custom_data()` in `src/save.c` is an RPN engine with ~52 operators,
reached from Tcl as `xschem raw add <varname> [<expr>] [<sweep_var>]` — documented in
`scheduler.c`'s own help text with the example `xschem raw add power {outm outp - i(@r1[i]) *}`.
Spec §0 carries a table mapping each thing the Calculator needs to where it already is. A crew that
writes a parser has done the wrong work, however well.

### ⚠ The second most important fact: 14 controls route to `calc::inert`

`calc::inert {what phase}` is the batch's deliberate stub — it writes
`not implemented (phase N)` to the status line and changes nothing else. `/usr/bin/grep -n
'calc::inert' src/calculator.tcl` lists every control still inert **and the phase that owns it**.
That grep is the batch's real progress bar. Making a control live means replacing its `calc::inert`
call, and the phase number in the call site tells you whether it is yours.

## ⚠ The single most important rule: RED FIRST

The user is remote, on a phone, and cannot look at a screen. A test is the only evidence that
counts.

For every unit of work: **write the failing row first, run it, capture what it printed while
failing, then write the code that turns it green.** A row written after the code has never been
observed to fail and is unproven as a fence. Your receipt must quote the red output verbatim. A
stage whose receipt cannot show a red is not done, however green it is.

Prefer, in order: a behavioural row that drives the real binary; a compiler diagnostic; a
structural row that greps the tree and names what it greps. If something genuinely cannot be
verified without eyes, build it, fence what is fenceable, and say in **one line** which part is
unverified — do not hold the work, and never ask the user to look at anything.

## ⚠ A row must FAIL, not THROW

Measured in issue 1616: a red row wrote `dict get [lindex $gs 0] traces` and, on the broken tree,
`dict get {} traces` **raised**. The error hit the suite's file-scope catch, printed one
`UNEXPECTED ERROR:` and **aborted the suite at 62 of 402 checks** — a band written to expose one
defect hid 340 unrelated ones. Both calculator suites have exactly that file-scope `catch … bigerr`
structure, so this trap is live here. Wrap anything that can raise on the broken tree and check a
legible sentinel instead. `test_calc_skeleton` already has a `pcall` helper for this; use it.

## ⚠ Before you register a suite, check its epilogue against `banner_complete`

This batch is the reason issue **1626** exists, so take it as measured fact rather than advice.

`banner_complete` in `tests/banner_rule.tcl` is the **only** Tcl reader of the completion-banner
rule, and the only one `run_regression.tcl` sources:

```tcl
^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$
```

It accepts **no** `RESULT: ALL PASS` spelling. `run_suites.sh` and `full_audit.sh` carry their own
EREs which DO accept it — so **a suite passing standalone is not evidence it can be registered.**
Measured 2026-09-30 at `621c1ff5`: `test_calc_skeleton` scores `ALL PASS (545 checks)` and
`test_calc_widgets` `ALL PASS (244 checks)` on the display arm, and `banner_complete` returns **0**
for both, on every arm. **789 passing checks gated nothing for a month.**

If a suite you touch lacks the sentinel, add it **additively** — keep the `RESULT:` line and keep it
**last**, because `summarize_all` publishes a case's last `RESULT:` line into the verdict.

⚠ **An earlier revision of this brief said the sentinel-less registered suites "get it from a
sourced common". That was wrong, and believing it would have shipped a standing red in T1.**
Measured by Stage A over every registered entry, ignoring comments: **16** registered suites emit no
literal sentinel, by **three** mechanisms — 13 compute it (`puts "OVERALL: [expr {$fail ? {notok} :
{ok}}]"`, all `test_ase_*`), 3 build it into a variable and `puts $var` (the bare-name `hilight_*`
entries), and **1** uses a sourced common. The famous mechanism is the rarest. Stage A's first fence
prototype handled only the literal case and false-reddened three real suites before its own control
rows caught it. **Do not reason about this from a remembered number** —
`tests/headless/test_registered_banner_1626.tcl` row `RB4` re-measures it every run, and `RB2` will
tell you before the gate does.

**A suite you add a fence to, you register in `tests/run_regression.tcl` in the same change.**
`hcases` if its rows run headless; `dcases` if they need a display; both only if both arms genuinely
measure something. For this batch the answer is **`dcases`**: the Calculator is Tk, and
`test_calc_skeleton`'s headless arm reports **0 checks**.

## ⚠ Do not predict the T1 trailer's `skips=` figure

CLAUDE.md records three separate occasions where someone reasoned carefully about registration
shape and got this wrong — most recently issue 1625, where an adversarial verifier **and** the
driver both predicted the number would move and both were wrong. The cause is always the same:
`summarize_all` counts **lowercase** `^skip:` and suites announce skipped bands with uppercase
`SKIP:`/`SKIPPED:`. If you need the figure, check `summarize_all`'s own `regexp` arm against your
suite's real output. Do not quote a remembered number.

## Environment — every one of these has cost someone a wasted run

* **`/usr/bin/grep`, never bare `grep`.** Here `grep` is a shell function routing to ugrep with
  different flag semantics.
* **Never invoke a bare `xschem`.** Use `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`. A bare `xschem` is not this tree.
* ⚠ **`$DISPLAY` is `172.20.160.1:0` — the user's REAL Windows X server.** A bare
  `./src/xschem --script …` inherits it and paints on the screen they are using. For a headless arm
  pass **`--nogui`** or run under **`env -u DISPLAY`**. `--pipe` does **not** imply `--nogui`.
* **The armed spelling is `tests/headless/run_suites.sh [--nogui] <suite>`** — it arms a throwaway
  `HOME` and picks the display arm safely (the dev display `:99` is up; leave it as found). A bare
  `./src/xschem … --script` keeps the user's real HOME and writes their clipboard, geometry and
  `simulations/`.
* **Put `timeout <n>` on every command that can hang**, and a self-announcing deadline on every
  waiting loop. A stall must be a named outcome, never silence.
* **Scratch only under `<your scratchpad>/<stage-label>/`.** Never `/tmp` directly, never the repo
  root.
* **Never `make` while suites are running** — they flake under CPU load.

## ⚠ A PROBE THAT SAVES, SAVES TO SCRATCH

An earlier batch cost a shipped library schematic: a crew used `xschem saveas` to read back what a
placement had written — a good instrument, because the `.sch` text is ground truth — and the save
went to the file the probe had loaded, gutting `xschem_library/examples/nand2.sch`. **A crew
reasoning about reads does not notice that its read instrument is a write.**

* **Every `xschem save` / `saveas` in a probe targets your own scratch directory.** Never a path
  under `xschem_library/`, never under `tests/`, never anything tracked, never the file you loaded.
* **End your stage by proving you changed nothing you did not mean to.** Run `git status --short`
  and put its output in your receipt. *"I did not intend to write anything"* and *"nothing is
  written"* are different claims and only the second is checkable. This applies even to a stage that
  legitimately edits code: the receipt names the files you meant to change, and `git status` must
  show no others.

## Do not touch

* `~/dev/xschem-op-wcard` — a second checkout, **read-only**. `git show` / `git log` only.
* `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate`.
* Any `/tmp/xschem_emergencysave_*` belonging to another process.
* `tests/headless/devdisplay.sh start|stop|view` against the real `:99`.
* Issue **0356** is the user's own.
* `tests/headless/owed.sh clear rule|look` — those clear **only when the user says so**.
* The five Phase-0/1 receipts and `EYEBALL_SIGNOFF.md` are a dated record. **Do not edit them to
  agree with what you found** — add your correction to your own receipt instead, or you falsify the
  record.

## You do not commit, push, or gate

The driver keeps the git identity, the commit message, the solo T1 gate, and the judgement about
whether a red is real. **Leave your work uncommitted in the tree** and say so in your receipt.
Never `git commit`, never `git push`, never `git stash` the whole tree, never force-push anything.

**If a permission prompt denies you something, say so in the receipt and stop.** Do not work around
a denial and do not ask another agent to do it for you.

## The current baseline, for comparison only

T1 at `f3d60af9` is `cases=113 blocks=112 counted_failures=0 skips=8 elapsed=620s`
(`tests/results.1227234.log`, taken in a throwaway clone at a 9-character path). Read
`tests/results.<pid>.log`, never `results.log`.

**Do not run a full T1** — that is the driver's job, and two concurrent runs plus your hand-run
suites can redden a gate.

⚠ **Gate clones go at a SHORT path.** `test_op_annot` and `test_annot_hier_0911` compare a
status-bar sentence that embeds an absolute path, and the product deliberately elides a sentence too
long for the bar, so a deep scratch path invents **11** failures. The session scratchpad is ~100
characters before your clone name — it is the wrong place for one.

`test_ase_optier_0963` is a characterised nondeterministic flake: if it reds, read the `rc=` it now
prints and re-run it before believing it.

## Your receipt

Write `receipts/<stage>-<role>.md` and make it answerable without your transcript:

1. **What you changed**, file by file, by **symbol name** (proc/function), not line number.
2. **The red**, quoted verbatim — row names and what they printed when failing.
3. **The green**, quoted — the suite's `RESULT:` line before and after, for **each arm** you ran.
4. **What you sabotaged and what it reddened.** Break the fix in the most plausible wrong way a
   reasonable person would have written it, and name which rows caught it. A fence that survives a
   plausible wrong implementation is not a fence.
5. **What you got wrong** during the stage, and what corrected you. This is required, not optional —
   it is reliably the most valuable line in a receipt.
6. **What you did NOT do**, and why — including anything you could not verify.
7. **Anything the next stage must know**, especially where this brief or `PLAN.md` is wrong.

Cite code by **symbol**, not by bare `file:line` — coordinates rot, identity holds. If you must cite
a line number, name the commit you measured it at.

**Do not write down a number nothing re-checks.** Either a row asserts the count, where it is
re-measured every run, or your sentence drops the number and states the shape instead.
