# Crew brief — issue 1606 batch

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
