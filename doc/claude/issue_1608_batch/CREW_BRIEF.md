# Crew brief — issue 1608 batch

You are one crew on one stage. Read, in order: this file, your stage's section of `PLAN.md`,
`DECISIONS.md`, and **the previous stage's receipt in `receipts/`** — the corrections to the
plan live in the receipts, not in the plan.

Return **one receipt** as `receipts/<letter>-<slug>.md`. A receipt states what you measured,
the command that measured it, the verbatim output that matters, and what you could **not**
measure. A receipt that only says "done" is not a receipt.

## Non-negotiables in this repo

* **Never invoke a bare `xschem`.** Always `./src/xschem`, `$XSCHEM`, or
  `tests/headless/devdisplay.sh exec ./src/xschem`. A bare `xschem` is not this tree.
* **A headless arm means `env -u DISPLAY … --nogui`.** `$DISPLAY` here is `172.20.160.1:0`,
  the user's **real Windows X server**, and `--pipe` does **not** imply `--nogui`. A crew on
  the 1603 batch mapped windows on the user's screen this way; the cause was a brief that
  said "redirect HOME" and nothing about `DISPLAY`. Do not repeat it.
* **Never `devdisplay.sh start|stop|view`** against `:99`, and never modify
  `~/.claude/xschem_dev_display` or `~/.claude/gui_test_gate`. `devdisplay.sh exec` and
  `devdisplay.sh status` are fine.
* **`/usr/bin/grep`, never the bare `grep`** — here `grep` is a function routing to ugrep and
  it misses forms this repo relies on.
* **Never write in `~/dev/xschem-op-wcard`.** It is read-only: `git show`/`git log`/read only.
* **Do not touch the owed ledger** (`~/.claude/xschem_owed/`). `rule` and `look` debts clear
  only when the user says so, and that is the driver's conversation, not a crew's.
* **Do not commit.** The driver holds the git identity, the commit message and the gate.
* Temporary files go in the session scratchpad, **not** `/tmp` and not the repo. Do not delete
  any `/tmp/xschem_emergencysave_*` — they may belong to another process.

## Measuring, in this tree

* **No test harness builds.** Every suite runs `$REPO/src/xschem` as found, so **rebuild
  before any run meant as evidence** (`make -C src`). On an unexpected red, check the binary
  before the code.
* **Restore a sabotaged file with `cp`, never `cp -a`.** A preserved mtime makes `make` skip
  the file and your next figure comes from a stale binary. This cost the 1603 batch one bogus
  red.
* **The armed spelling for a suite is `tests/headless/run_suites.sh [--nogui] <name>`** — it
  arms the throwaway HOME. A bare `./src/xschem --script tests/headless/<t>.tcl` keeps the
  user's real HOME and their real display.
* **Put `timeout <n>` on every command that runs the binary**, and a deadline on every waiting
  loop. A stall must be a named outcome, never silence.
* Cite code **by symbol name**, not by bare `file:line`. If a line number is unavoidable, name
  the commit you measured it at.

## Writing a test row here

* **Assert by name, never by count.** This tree has defeated a whole-file regexp twice: a
  `#if 0` region holding a byte-for-byte clone of the live code (1607 row `V27`), and a source
  **comment** quoting the very guard the row greps for (1603 rows `S1`–`S4`). So a static row
  **strips block comments and `#if 0` regions** — depth-counted — before it matches, and
  collapses whitespace, because at least one shipped clamp contains a double space.
* **Every guard needs a row that reddens when the guard is removed.** A guard with no such row
  leaves silently the day someone refactors above it. Sabotage each one and record the
  verbatim failing line.
* **A `skip:` line is lowercase and must never end in `FAIL`, `GOLD?` or `RESULT?`** — those
  shapes are counted as failures by `summarize_all` wherever they appear.
* A behavioural row asserts **both** the exit code and the absence of a column-0
  `FATAL: signal` marker.
* A row that needs a display **self-skips** with a `skip:` line when `devdisplay.sh status`
  does not report a live display. It never silently passes.

## What to report even though nobody asked

* Anything you find that contradicts `PLAN.md`, `DECISIONS.md` or the issue file. The plan is
  the driver's best guess and has been wrong in each of the last two batches.
* Anything you could not drive, with the reason.
* Any defect outside this issue's scope: name it, do **not** fix it, and say it is carried
  forward.

## What the 1606 batch paid four rounds to learn, and you inherit for free

The immediately preceding batch (`doc/claude/issue_1606_batch/`, landed as `eb20dc62`) fixed
thirteen sites of exactly this defect class. Its fences were defeated **fifteen times** across four
hardening rounds before they held. Read `tests/headless/test_ev_precision_bound_1606.tcl`'s NAMED
LIMITS header before you write a single static row; the short version:

* **A static row over C text decides a SET OF SPELLINGS, never a property of the program.** Five
  consecutive rounds shipped a sentence saying how many shapes escaped, and a crew refuted the
  number every time. **Do not claim a count.** Name the shapes you drove, as a list that may grow.
* **A row's NAME must describe its METHOD, not its coverage.** Three false row names shipped in that
  batch — "every write to X", "every sprintf in the tree" — each refuted by a single whitespace
  variant or a `#define` alias. If a row greps, its name says what text it greps for.
* **The shapes that defeated static rows there**: a `/* */` comment quoting the guard; a `#if 0`
  clone; a `//` line comment; `#if 0 && 1`; `#ifdef <undefined>`; a **dead but allowlisted**
  `#ifndef __unix__` region; the statement inside a **string literal**; `#define X <statement>`
  never invoked; `if(0) <statement>`; a `%.*` split across adjacent string literals (C joins them
  in translation phase 6, so the text never contains the token); a two-hop `#define` alias to
  `sprintf`; and a macro alias for the field being asserted about.
* **Prefer a BEHAVIOURAL row or a COMPILER-DIAGNOSTIC row.** Those two have none of that weakness.
  The 1606 batch's single strongest fence turned out to be a row that compiles the sources and
  asserts zero `-Wformat-overflow` diagnostics — because no decoy can fool the compiler's own
  opinion. **`my_snprintf` is directly callable from a test, so a behavioural row is available here
  and should be the backbone.**
* **Two redundant guards on one path means NEITHER has a behavioural row that reddens on its own
  removal.** That defeated a whole fencing plan there. If you add belt-and-braces bounds, fence
  each one separately and say so.
* **A comment that quotes a measurement must reproduce it.** That batch shipped, and then caught: a
  figure that was `double((float)1.111)` and could not come from the path it was attached to; a
  claimed **Win64 measurement** on a machine with no Windows toolchain; and a probe quoted from a
  tree that no longer existed — inside the very paragraph rewritten to fix a stale quoted probe.
  ⚠ **`my_snprintf`'s existing comments are in this category**: the 1606 batch found `save.c`'s and
  `draw.c`'s accounts of what this function does with `%.*g` to be right about the mechanism and
  wrong about the ABI and the number. Re-measure anything you quote.
* **Restore a sabotaged file with `cp`, never `cp -a`** — a preserved mtime makes `make` skip it and
  your next figure comes from a stale binary.

## ⚠ Namespace your scratch — crews overwrite each other otherwise

Measured on this batch's Stage A: **another crew dispatched at the same time overwrote a census
script mid-run**, because both wrote the same filename into the shared session scratchpad. The whole
census had to be re-run.

**Put everything under `<scratchpad>/<your-stage-label>/`** — e.g. `stageC_1608/` — and never write a
bare filename at the scratchpad root. Assume a sibling crew is running concurrently with the same
instincts about what to call a file.
