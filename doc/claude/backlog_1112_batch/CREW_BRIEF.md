# Crew brief — backlog batch 2026-11-12

You are a task crew in a driver-orchestrated batch. Read, in order: this file, your stage in
`PLAN.md` (same directory), `LEDGER.md`, and the PREVIOUS stage's receipt in `receipts/` if
there is one (corrections to the plan live there). Repo: /home/analog/dev/xschem-claude,
branch fluid-editing. CLAUDE.md in the repo root applies in full.

## Hard constraints (each one has been violated before; the driver checks)

1. **Never touch the user's screen.** `$DISPLAY` is the user's real Windows X server. Start
   EVERY Bash command that could run xschem, wish or tclsh-with-Tk with `unset DISPLAY;`.
   Counted arm: `AUDIT_DISPLAY=:<n> tests/headless/run_suites.sh --nogui <suite>`.
   Display arm: start your OWN Xvfb on a free number in 260-299
   (`Xvfb :<n> -screen 0 1920x1080x24 &` then `DISPLAY=:<n> openbox &`), run
   `AUDIT_DISPLAY=:<n> tests/headless/run_suites.sh <suite>`, and kill exactly those two pids
   when done (never `pkill openbox`/`pkill Xvfb` by name — other sessions' servers live here).
   For a hand run: `unset DISPLAY; HOME=$(mktemp -d) ./src/xschem --nogui --pipe -q --nolog
   --norecent --script <f>`, or with `DISPLAY=:<n> GUI_GATE=0` for your own Xvfb.
   A bare `./src/xschem` with an inherited DISPLAY is a reportable defect.
2. **Never use display :99** (another session gates on it) and never run T1
   (`run_regression.tcl`) — the driver gates.
3. **Do not commit, push, stash, reset or checkout.** Leave your work as uncommitted changes
   in the working tree; the driver commits. Do not touch files outside your stage's scope; the
   tree has unrelated untracked files — leave them.
4. **~/private/xschem-private is read-only and private**: only `git -C ~/private/xschem-private
   show <rev>[:path]`; never fetch it into this repo, never write there.
5. Rebuild after any C change: `make -C src` (check for errors/warnings).
6. Red first: every new row must be shown FAILING on the tree without your fix (stash-free:
   copy the file, sabotage, run, restore with `cp`, then `cmp` to prove the restore).
7. New issue files: follow CLAUDE.md's numbering + STAMP rules; run
   `tclsh tests/headless/issue_stamp.tcl` → `ok (0 problems)`. Receipts are NOT issue files.
8. Use `/usr/bin/grep`, not bare `grep`.
9. Comments: cite code by symbol; quote no count a command produces; prose above procs, never
   between `switch` arms.

## Receipt

Write `receipts/<stage>-<short>.md`: what you changed (files, symbols), what you measured
(commands + results), each sabotage and whether it reddened, suites run on which arm with
check counts, anything you could NOT measure or decided not to do and why, any decision that is
the USER's (do not take it — describe it). Your final message to the driver: the receipt path
and a 5-line summary. Nothing else.
