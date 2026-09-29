# CREW BRIEF — selectall_getprop_batch

Read this whole file before touching anything. Then read the PLAN stage section you were
handed, and **the previous stage's receipt in `receipts/`** — that is where corrections to
the plan live, and the plan itself may be wrong where a receipt contradicts it.

## What this batch is

Two items from the user's own wish list, `doc/claude/specs/wish_list.txt`:

* **Stage A** — new-list item **13**: *"WV: CTRL-A to select all traces. Select and delete
  traces."* The select-and-delete half already ships (issues 0175, 0176). Ctrl-A does not.
  Issue number **1617** is minted for it.
* **Stage B** — old-list item **21**: *"Provide a way, through TCL, to access properties of
  any object."* `xschem getprop` has arms for instance / instance_notcl / symbol (full prop
  string) and rect / text / wire (**token-only**), and **no arm at all for line, poly or
  arc**. Issue number **1618** is minted for it. This also unblocks old-list item **26**
  (`o~>prop`-style access), which is NOT in this batch.

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

T1 at `b89fddda` is `cases=107 blocks=106 counted_failures=0 skips=8 elapsed=621s`. Read
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
