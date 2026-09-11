# 1375 — `xschem descend -fallback` raises a modal under `--script`, and it hangs the GUI arm of a suite

**Status: FILED, NOT FIXED.** Found by the driver while verifying the
1368–1374 batch, and **it is not that batch's doing** — reproduced identically
at HEAD `5dc7b2c8`. Subject: `src/actions.c` `descend_schematic()`
(the `if(fallback && !is_gen && filename[0])` block, the `if(has_x)` inside it),
`tests/headless/test_ase_optier_0963.tcl` (`n_dsc_base`, and the comment above
it that asserts this cannot happen).

## What happens

`tests/headless/test_ase_optier_0963.tcl` is **ALL PASS (102) under `--nogui`**
and **hangs for ever with a display**:

    ./src/xschem --nogui --pipe -q --script tests/headless/test_ase_optier_0963.tcl
      -> RESULT: ALL PASS (102 checks), rc 0

    tests/headless/devdisplay.sh exec ./src/xschem --pipe -q \
        --script tests/headless/test_ase_optier_0963.tcl
      -> last row reached: N3
      -> then nothing.  Killed at 500 s and at 900 s; measured once at 30 min,
         0.0% CPU, `State: S (sleeping)`, `wchan futex_do_wait`, no child
         process, X socket open.  `FATAL: signal 15` / `while editing: bandgap`.

Both taken on `:99` (Xvfb 1920x1080x24, openbox 3.6.1), and the same hang at
HEAD in a detached worktree running the same binary.

⚠ **STILL LIVE 2026-09-11, and a third measurement, taken by a crew that walked into it.**
Reproduced twice more on `:99` with issue 1401 in the tree: **86 of 103 rows printed, stops
after row N3**, no `RESULT:` line, no `OVERALL:` line, no `ngspice` process alive. One of those
runs was left unattended and sat there for **8 hours 7 minutes** (`etimes` 29 208 s) before it
was noticed, because it had been launched from a hand-rolled loop with no `timeout` — where
`tests/headless/run_suites.sh` would have printed `TIMEOUT | test_ase_optier_0963 … (after
200s)` and moved on. **The stall point is stable across all four recorded reproductions**, which
is consistent with this file's root cause: a modal raised at a deterministic place in the
script, not a race.

Write-up of how the eight hours happened, and the standing rule added to `CLAUDE.md` because of
it: `doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`. ⚠ **The suite's own header
already said `## ⚠ THIS SUITE NEEDS `--nogui`; its GUI arm hangs for ever (issue 1375).`** — the
warning was twelve lines above the code being read, and was walked past. Anyone adding a suite
to a both-arms run should grep the suite header for `--nogui` first.

## Why

`n_dsc_base` calls `xschem descend -fallback 1 2`. The `-fallback` flag exists
so the verb behaves like the right-click canvas item (issues 0979 / 1228), and
in `descend_schematic()` that path reaches:

```c
if(fallback && !is_gen && filename[0]) {
  file_exists = !stat(filename, &buf);
  if(!file_exists) {
    ...
    if(has_x) {
      ...
      tcl_call("ask_save", msg, NULL, "0");     /* <-- MODAL, nothing clicks it */
```

`ask_save` is a `tkwait`. The gate is **`has_x` alone**: a display is enough. A
script has one, so a script gets the modal, and issue 0803's rule applies word
for word — *a modal a suite cannot click does not FAIL, it HANGS, and takes the
audit with it.*

Note `descend_schematic`'s third parameter is `alert`, which the command ties to
`fallback` — and which this block never consults. `alert` reaches
`load_schematic()` and nothing else. So there is not even a lever today.

## The part that makes it dangerous

The suite's own comment, twenty lines above the call, says the opposite:

> `## No dialog can hang a GUI suite on this (issue 0803 was the fear): the`
> `## question is only asked when there is a display AND the caller asked for`
> `## the fallback, and it now has two buttons instead of three.`

Both halves of that sentence are true and the conclusion does not follow: a
suite HAS a display and this caller DID ask for the fallback, so the stated
conditions are the conditions under which it hangs. Two buttons hang exactly as
well as three. A reader auditing this file is told the hazard was considered and
dismissed, which is why it survived.

## What is owed

The fix is a decision, not a typo, so it is the user's: a script-driven descend
must not raise a modal, but "driven by a script" is not a thing the C side can
currently see. The options, shortest first:

* **(a)** gate the question on `alert` as well as `has_x`, and give the command
  a form that asks for the fallback without the offer (`-fallback yes`, taking
  the Yes answer as given). One C line plus one grammar arm; the suite's call
  becomes `xschem descend -fallback yes 1 2`.
* **(b)** a general "no modals" flag the whole tree honours under `--script` /
  `--pipe`. Correct, much wider, and every existing modal has to be audited.
* **(c)** leave it and forbid `-fallback` in GUI suites — cheapest, and it
  leaves a booby trap for the next author, which is how this one survived.

Recorded on the owed ledger as rule debt `1375`.

## Until it is settled

`test_ase_optier_0963` must be run **`--nogui`**. It is ALL PASS there. A GUI
run of it will hang, and it will look like the machine has stopped.
