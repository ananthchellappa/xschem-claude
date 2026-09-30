# CREW BRIEF — replay_door_batch

Read this whole file before touching anything. Then read the PLAN stage section you were
handed, and **the previous stage's receipt in `receipts/`** — that is where corrections to
the plan live, and the plan itself may be wrong where a receipt contradicts it.

## What this batch is

**One item** from the user's own wish list, `doc/claude/specs/wish_list.txt` — old-list item **3**:
*"Logging of all user interactions to enable macros and script creation from log files. WIP - but
25% DONE by Claude Code"*.

Stage R already ran: six parallel read-only crews, receipt `receipts/R-recon-wishlist.md`. **Read
that receipt before you touch anything.** Its headline: the logging engine is done, safe and fenced
by 29 round-trip suites — `replay_action_log` (`src/xschem.tcl`) replays a recorded log and the
replay's own log comes back **byte-identical** — but **macros are at zero**, because that proc has
no `actions.csv` row, no menu entry, no keybinding and no file dialog. The only way to reach it is
to type it into the CIW.

* **Stage A** — give replay a door. Issue **1619**. One `actions.csv` row plus a small Tcl proc
  with a file chooser, calling the existing `replay_action_log`. **No C change.**
* **Stage B** — close the selection gap. Issue **1620**. `select_all()` and `unselect_all()` are
  the only wholly unlogged selection primitives, and selection is the commonest macro prefix.

⚠ **`doc/claude/code_analysis/action_log_coverage_audit_and_core_selflog_refactor.md` (July 2026)
CONTRADICTS THE CODE IN FOUR PLACES** — its claims that Ctrl-X, the Delete key, Edit Copy and File
Save log nothing, and that property edits emit only a `# property-edit` marker, are all FALSE at
HEAD, each one verified against the binary. Its "roughly 70% landed" is stale and its bare
`file:line` citations have rotted. **Do not cost work off that document.** The recon receipt
supersedes it.

## ⚠ The single most important rule: RED FIRST

The user is remote and cannot look at a screen. A test is the only evidence that counts.

For every unit of work: **write the failing row first, run it, capture what it printed
while failing, then write the code that turns it green.** A row written after the code has
never been observed to fail and is unproven as a fence. Your receipt must quote the red
output verbatim. A stage whose receipt cannot show a red is not done, however green it is.

Prefer, in order: a behavioural row that drives the real binary; a compiler diagnostic; a
structural row that greps the tree and names what it greps. If something genuinely cannot
be verified without eyes, build it, fence what is fenceable, and say in **one line** which
part is unverified — do not hold the work and do not ask the user to look.

## ⚠ A row must FAIL, not THROW

Measured in issue 1616, one stage earlier: a red row wrote
`dict get [lindex $gs 0] traces` and, on the broken tree, `lindex {} 0` was the empty
string, so `dict get {} traces` **raised**. The error hit the suite's file-scope catch,
printed one `UNEXPECTED ERROR:` and **aborted the suite at 62 of 402 checks** — a band
written to expose one defect hid 340 unrelated ones. Wrap anything that can raise on the
broken tree in `catch` and check a legible sentinel instead:

```tcl
if {[catch {llength [dict get [lindex $gs 0] traces]} v]} { set v "no-graph ($v)" }
check "row name" $v 0
```

## ⚠ Before you register a suite, check its epilogue against `banner_complete`

`banner_complete` in `tests/banner_rule.tcl` is the **only** Tcl reader of the
completion-banner rule and the one `run_regression.tcl` sources:

```tcl
^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$
```

It accepts **no** `RESULT: ALL PASS` spelling. `run_suites.sh` and `full_audit.sh` carry
their own EREs which DO accept it — so **a suite passing standalone is not evidence it can
be registered.** A suite added to `hcases`/`dcases` while printing only `RESULT:` scores
`HARNESS: … did not complete cleanly (exit=0, OVERALL_ok=0, died=0)` with every one of its
own checks passing. That has now happened twice (issues 1615, 1616). If a suite you touch
lacks the sentinel, add it **additively** — keep the `RESULT:` line, because
`summarize_all` publishes a case's last `RESULT:` line into the verdict.

**A suite you add a fence to, you register in `tests/run_regression.tcl` in the same
change.** `hcases` if its rows run headless; `dcases` if they need a display; both only if
both arms genuinely measure something.

## Environment — every one of these has cost someone a wasted run

* **`/usr/bin/grep`, never bare `grep`.** Here `grep` is a shell function routing to ugrep
  with different flag semantics.
* **Never invoke a bare `xschem`.** Use `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`. A bare `xschem` is not this tree.
* ⚠ **`$DISPLAY` is `172.20.160.1:0` — the user's REAL Windows X server.** A bare
  `./src/xschem --script …` inherits it and paints on the screen they are using. For a
  headless arm pass **`--nogui`** or run under **`env -u DISPLAY`**. `--pipe` does **not**
  imply `--nogui`.
* **The armed spelling is `tests/headless/run_suites.sh [--nogui] <suite>`** — it arms a
  throwaway `HOME` and picks the display arm safely. A bare `./src/xschem … --script` keeps
  the user's real HOME and writes their clipboard, geometry and `simulations/`.
* **Put `timeout <n>` on every command that can hang**, and a self-announcing deadline on
  every waiting loop. A stall must be a named outcome, never silence.
* **Scratch only under `<your scratchpad>/<stage-label>/`.** Never `/tmp` directly, never
  the repo root.

## ⚠ Two traps Stage R paid for -- do not repeat them

**1. Absence of a log line is not absence of coverage.** The recon crew's GUI fixture load silently
failed (`xschem get instances` = 0 while `file exists` = 1), so every selection-dependent probe read
"not logged" when in truth nothing was selected to act on. **Always assert the EFFECT alongside the
log line.** A bare "no new log line" result is uninterpretable and has already produced one wrong
conclusion in this batch.

**2. A scripted verb is not the interactive path, and it badly under-reports.** Headless
`xschem <verb>` logged **9 of 20** operations; the same operations driven through
`xschem callback .drw 2 ...` key events logged real replayable commands. Anyone measuring coverage
with a `--script` driver will conclude the feature is far worse than it is. Measure the path you
are making a claim about, and say which path it was.

Two smaller ones: take chords from **`xschem bindings dump`**, never from memory (two first-pass
"misses" were the crew probing keysym `'o'` = 111 where the binding is on `'O'` = 79); and
**dialog-opening keys hang a headless probe with no upper bound** on a modal `vwait`, so put
`timeout` on every such run and write output to a **file**, because under `--pipe` a suite's `puts`
may never reach your stdout.

## ⚠ A PROBE THAT SAVES, SAVES TO SCRATCH

Stage R cost us a shipped library schematic. A crew under an explicit *"READ-ONLY, change NOTHING"*
brief left `xschem_library/examples/nand2.sch` gutted in the working tree -- 35 lines deleted,
every net and instance gone, the version header rewritten. It was restored from HEAD (batch
decision **D9**), and the mechanism is worth more than the incident: the crew was using
`xschem saveas` to READ BACK what a placement had written, which is a good instrument, because the
`.sch` text is ground truth for "did this place four labels or one". But a save needs a
destination, and that one went to the file the probe had loaded. **A crew reasoning about reads does
not notice that its read instrument is a write.**

So:

* **Every `xschem save` / `saveas` in a probe targets your own scratch directory.** Never a path
  under `xschem_library/`, never under `tests/`, never anything tracked, and never the file the
  probe loaded. Load from the library if you must; save somewhere you own.
* **End your stage by proving you changed nothing you did not mean to.** Run `git status --short`
  and put its output in your receipt. *"I did not intend to write anything"* and *"nothing is
  written"* are different claims and only the second one is checkable. This applies even to a stage
  that legitimately edits code: the receipt names the files you meant to change, and `git status`
  must show no others.

## Do not touch

* `~/dev/xschem-op-wcard` — a second checkout, **read-only**. `git show` / `git log` only.
* `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate`.
* Any `/tmp/xschem_emergencysave_*` belonging to another process.
* `tests/headless/devdisplay.sh start|stop|view` against the real `:99` — leave it as found.
* Issue **0356** is the user's own.
* `tests/headless/owed.sh clear rule|look` — those clear **only when the user says so**.

## You do not commit, push, or gate

The driver keeps the git identity, the commit message, the solo T1 gate, and the judgement
about whether a red is real. **Leave your work uncommitted in the tree** and say so in your
receipt. Never `git commit`, never `git push`, never `git stash` the whole tree, never
force-push anything.

**If a permission prompt denies you something, say so in the receipt and stop.** Do not
work around a denial and do not ask another agent to do it for you.

## The current baseline, for comparison only

T1 at `acd30d62` is `cases=107 blocks=106 counted_failures=0 skips=8 elapsed=619s`
(`tests/results.775219.log`). Read
`tests/results.<pid>.log`, never `results.log`. **Do not run a full T1** — that is the
driver's job and two concurrent runs plus your hand-run suites can redden a gate.

Known pre-existing reds, not yours: `test_wave_sigbrowser_keys` BK22/BK29/BK31,
`test_wave_sigbrowser_0312` BF21a/BF24a, `test_results_dialog` SEL389, `test_ase_dialogs`,
`test_rdw_keys_1245`. `test_ase_optier_0963` is a characterised nondeterministic flake —
if it reds, re-run it before believing it.

## Your receipt

Write `receipts/<stage>-<role>.md` and make it answerable without your transcript:

1. **What you changed**, file by file, by **symbol name** (proc/function), not line number.
2. **The red**, quoted verbatim — row names and what they printed when failing.
3. **The green**, quoted — the suite's `RESULT:` line before and after.
4. **What you sabotaged and what it reddened.** Break the fix in the most plausible wrong
   way a reasonable person would have written it, and name which rows caught it. A fence
   that survives a plausible wrong implementation is not a fence.
5. **What you got wrong** during the stage, and what corrected you. This is required, not
   optional — the previous two stages each found the driver's own scouting wrong, and that
   is the most valuable line in a receipt.
6. **What you did NOT do**, and why — including anything you could not verify.
7. **Anything the next stage must know**, especially where this brief or the PLAN is wrong.

Cite code by symbol. If you must cite a line number, name the commit you measured it at.
