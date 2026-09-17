# Crew brief — harness concurrency batch

You are a task-crew on a driver-orchestrated batch. You get **one task**. Read this
brief, your stage's row in `PLAN.md`, and **the previous stage's receipt** in
`receipts/` — that is where corrections to the plan live.

## The rules that actually cost people nights here

1. **Verify; never inherit.** The premise that started this batch — 0990's claim that
   a red "would have to run two regressions at once, which is expensive" — was
   **false**, and it had stood unchallenged for seventeen days. If a doc, an issue
   file or this brief states a number, re-measure it before you rely on it. Say in
   your receipt which claims you checked and which you took on trust.
2. **Never a bare `xschem`.** It resolves to `/usr/local/bin/xschem`, which is 3.4.6
   from Jan 2025 and predates the `no_recent_files` gate — one run of it emptied the
   user's `File > Open Recent` (issue 0924). Always `./src/xschem`, `$XSCHEM`, or
   `tests/headless/devdisplay.sh exec ./src/xschem`.
3. **Every command gets a `timeout`.** A hung suite and a slow suite emit identical
   silence; one cost this project 8 h 7 min (issue 1403). A stall must be a **named
   outcome** — `PASS`/`FAIL`/`TIMEOUT`/`NORESULT` — never the absence of one. Prefer
   `tests/headless/run_suites.sh` (200 s per arm) over a hand-rolled loop, which
   forfeits both the timeout and the GUI gate.
4. **Never run a suite while another crew is running one.** This batch's whole
   subject is that concurrent runs corrupt each other. The driver dispatches serially
   for this reason. If you believe another run is live, stop and say so in the
   receipt rather than producing a number.
5. **T1 is `cd tests && tclsh run_regression.tcl`** — never `tclsh
   tests/run_regression.tcl` from the repo root, which exits 1 without running and
   leaves the **previous** run's `results.log` byte-for-byte in place. Read
   `results.log` itself, never stdout. **T1's baseline is ZERO counted failures.**
   A standing red is a defect, not furniture.

   ⚠ **THIS BULLET TAUGHT THREE RETIRED RULES UNTIL 2026-09-17**, and was still
   teaching them to crews dispatched *after* the change that retired them. Corrected
   by the `claude-md` crew's finding; recorded rather than silently swapped, because
   a receipt written under the old rules is not wrong — it was right when written.

   * **It said "confirm its mtime moved first (a green run is byte-deterministic, so
     an unchanged md5 proves nothing)".** Both clauses are now false. **Read the
     `T1-RUN-END` trailer instead** — mtime only ever proved a run *wrote*; the
     trailer proves it *finished*, which is what you actually need. And a green
     verdict is **no longer byte-deterministic**: the sentinels carry a pid and a
     timestamp, so two identical green runs now differ.
   * **It said "count cases by `Start`/`Finish` pairs, not by log lines".** That rule
     has a hole, filed as **issue 1481**: the NODISPLAY path `continue`s before its
     `Finish` line, so a box with no dev display prints **84 `Start` / 73 `Finish`**
     — under-counting by 11. Note what this means: the rule was written *because* two
     independent passes miscounted by using log lines, and the trusted alternative
     was wrong too.
   * **There are now THREE plausible numbers, not two.** 84 cases; 83 `Total num
     fail:` lines; and `wc -l` answers **171**.

     ⚠ **THIS BULLET SAID 85 UNTIL V4 MEASURED IT, AND THAT IS THE SHARPEST LESSON
     IN THE BATCH.** 85 is 83 + 2 — the log lines plus the two sentinels — and it
     omits the **83 block-header lines**. The real decomposition, verified on four
     green verdicts, is **2 + 83 + 83 + 3 = 171**. So this paragraph has now been
     wrong **three times**, and the number added *to prevent the conflation* **was
     itself the conflation**, arrived at by arithmetic on a sentence instead of by
     running `wc -l` once. **Take the number from the artefact. Every time. Including
     when you are writing the warning about not doing that.**

   ⚠ **AND `results.log` MAY NOT BE YOUR ANSWER.** Both runs now proceed, so during a
   concurrent run `results.log` can hold a verdict that is complete, well-formed and
   **someone else's**. **Your answer is `tests/results.<pid>.log`** — and the
   `T1-RUN-BEGIN` header names the pid that wrote whatever you are reading. Check it.
6. **Rebuild before any measurement meant as evidence.** No test harness builds;
   `full_audit.sh` runs `$REPO/src/xschem` as it finds it. A correct source tree with
   a stale binary produces a plausible, wrong audit.
7. **Do not commit.** The driver holds the git identity and the commit message. Leave
   the tree dirty and describe it in the receipt.
8. **Do not touch the owed ledger** (`owed.sh`). The driver owns it.
9. **`_ALLOC_ID_`, C89, `dbg()`** — house conventions, if you touch C. This batch is
   Tcl and shell.

## Red-first, and what "red" has to mean

A row that has never been observed RED proves nothing. For each row you add, record
in your receipt: the row name, the **observed red output on today's tree**, and the
**observed green output after the fix**. If a row cannot be made to red, say so
explicitly and explain why it is still worth having — do not quietly keep it.

The cheap idiom for asserting on a driver's source text is
`tests/headless/test_suite_watchdog_1403.tcl` rows W14–W19 (`has_text $rr {…}`):
milliseconds, no run. Use it for "the fixed path is gone" / "the sentinel exists" /
"the lock exists". Reserve the expensive behavioural rows (~70 s) for the faces that
only a real collision shows.

## Receipt format

Write `receipts/<task-id>.md`, and make it readable by someone who was not there:

```markdown
# <task-id> — <one-line what was done>
**Status:** DONE | BLOCKED | PARTIAL
**Files touched:** <paths, with line numbers>
**Rows added/changed:** <names>, with red-before and green-after output quoted
**Commands run:** <exact, with timeouts>
**Measurements:** <numbers, with the command that produced each>
**Claims checked vs taken on trust:** <explicit list>
**Corrections to PLAN.md:** <what the plan got wrong — the next crew reads this>
**Left dirty:** <tree state for the driver>
**Owed to the user:** <any unratified decision or pixel deliverable>
```
