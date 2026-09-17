# Crew brief — issue tracker batch

You are a task-crew on a driver-orchestrated batch. You get **one task**. Read this
brief, your stage's row in `PLAN.md`, and **the previous stage's receipt** in
`receipts/` — that is where corrections to the plan live.

## What this batch is about, and why it is different

Every other batch in this repo fixes code. **This one's subject is the tracker itself**
— `doc/claude/issues/`, 1047 numbered files, 12 MB of prose, which is the project's
memory and is the thing that tells the next person what to do.

The batch exists because of what the harness-concurrency batch measured on 2026-09-17:

* **Six issue files prescribed fixes that would have changed working code.** 0867 and
  0990's fix was a no-op (658 phantoms against 660). 0805's would have scored a green
  shipped suite FAIL. 0609's supplied code compares **counts where it needed sets** —
  and **that same file's own §3** is the recorded correction saying why counting fails
  there. 1478 §3's would have **re-opened the race it was written to close**. The sixth
  was written by the **driver**, in a dispatch brief, in a message lecturing a crew
  about citing without reading.
* **Two files reported finished work as outstanding** — 0609's closing ⚠ and 1480 §6
  item 3, whose subject was already fixed by commit `a6038098`.
* **One defect was filed five times across seven weeks and attempted zero times**
  (0384, 0867, 0955, 0905, 0990), because each arrival read the previous filing,
  believed it, and filed again. A sixth filing was caught mid-draft.
* **The reasoning cites itself in a loop.** 1477's OOM attribution cites 0905; 0905
  says "a documented event"; nothing at the end of the chain is a measurement, and
  `dmesg` carries zero OOM kills.
* **Nothing mechanical checks any of this.** Measured 2026-09-17: every hit on
  `doc/claude/issues` in `*.sh`/`*.tcl`/`*.js`/`Makefile*` is source code **citing** an
  issue number in a comment. There is no linter, no test, no schema. 1047 files, zero
  checks.

**So the thing you are reading may be wrong, and its confidence is not evidence.**
That is not a warning about one file. It is the measured base rate of this corpus, and
it is what your task exists to quantify or repair.

## The rules that actually cost people nights here

1. **Classify against the TREE, not against the DOCUMENT.** An issue that says
   `**Status:** FIXED` is making a claim about code. Go read the code. A status line is
   the *least* reliable line in the file — it is written once, at filing time, by
   someone who did not yet know the outcome, and nothing has ever re-checked one.
2. **"I could not determine this" is a VALID and VALUABLE verdict.** Record it as
   `UNKNOWN` with what you tried. A fabricated confident answer is the disease this
   batch is treating; adding one to the measurement of it would be the batch's own
   sixth prescribed fix. **Never guess to fill a cell.**
3. **Verify; never inherit.** If a doc, an issue file or *this brief* states a number,
   re-measure it before relying on it. Say in your receipt which claims you checked and
   which you took on trust. This brief's own numbers are fair game — check them.
4. **Never a bare `xschem`.** It resolves to `/usr/local/bin/xschem`, 3.4.6 from Jan
   2025, which predates the `no_recent_files` gate — one run of it emptied the user's
   `File > Open Recent` (issue 0924). Always `./src/xschem`, `$XSCHEM`, or
   `tests/headless/devdisplay.sh exec ./src/xschem`. Nothing is installed at that path
   today, which **re-arms** this rule rather than retiring it: one `make install` puts
   it back, and `test_utility.tcl`'s third fallback *is* PATH.
5. **Every command gets a `timeout`.** A hung job and a slow job emit identical silence;
   one cost this project 8 h 7 min (issue 1403). A stall must be a **named outcome** —
   `PASS`/`FAIL`/`TIMEOUT`/`NORESULT` — never the absence of one.
6. **READ-ONLY CREWS MAY RUN IN PARALLEL. This is a deliberate change from the
   harness-concurrency brief**, whose rule 4 said *"never run a suite while another crew
   is running one"*. That rule was about **suite contention** and it was correct for a
   batch whose crews all ran T1. Most crews here run **no suite at all** — they read
   files. Reading does not contend. And the contention rule itself was relaxed on
   measurement the same day (⚖ R4): two T1 runs in one tree are now supported, both
   proceed, each writes `tests/results.<pid>.log`. **If your task does run a suite, say
   so in the receipt and name the arm.**
7. **T1 is `cd tests && tclsh run_regression.tcl`** — never `tclsh
   tests/run_regression.tcl` from the repo root, which exits 1 without running and
   leaves the **previous** run's `results.log` byte-for-byte in place. **Your answer is
   `tests/results.<pid>.log`**, not `results.log`, which holds whichever run finished
   last. **Read the `T1-RUN-END` trailer** — it states `cases=`, `blocks=` and
   `counted_failures=` outright, and a verdict with no trailer **did not finish**,
   whatever its contents. T1's baseline is **ZERO** counted failures.
8. **Do not commit.** The driver holds the git identity and the commit message. Leave
   the tree dirty and describe it in the receipt.
9. **Do not touch the owed ledger** (`tests/headless/owed.sh`). The driver owns it, and
   a backup is taken at `~/.claude/xschem_owed_backup_20260917_tracker`. **`rule` and
   `look` debts clear ONLY when the USER says so** — no crew, and not the driver,
   clears one. A triage crew produces a *recommendation*; the user decides.
10. ⚠ **A CITATION NEEDS A TREE STATE, NOT JUST A LINE.** Cite against a named revision
    — or quote the text and say **which tree you read it in**. `HEAD` and the working
    tree are different documents, and in this repo crews edit concurrently.

    Quoting the line is **necessary and not sufficient**, and the driver is the proof:
    it read the lines, quoted them, and was still wrong. **Position is not identity.**

    ⚠ **The worked example is the driver's, and it is the last batch's most instructive
    failure.** Four passes gave three different coordinates for one sentence. The driver
    read two of them, found unrelated code, and committed `d5396ddd` accusing everyone —
    itself included — of citing without reading. All four readings were **correct against
    the tree each had read**: a live crew's `+15`-line edit sat above the banner and
    shifted everything below it. Nobody's grep was broken; the tree was moving underneath
    the conversation about it.

    ⚠ **Then the driver ordered a revert that would have DESTROYED the fix** — `git
    checkout HEAD --` restores the defect. **The crew refused, and was right.** If an
    instruction from the driver would discard work you have measured as correct, **say so
    and do not comply.** That refusal is the behaviour this batch most wants to keep.

11. **Use `/usr/bin/grep`, never a bare `grep`.** The bare name is a function routing to
    ugrep and it returns different results — measured: for an anchored-alternation form
    it found **nothing in either clone** where `/usr/bin/grep` found the number taken in
    **both**.

## What "measured" has to mean in a prose batch

The last batch's rule was *red-first*: a row that has never been observed RED proves
nothing. The equivalent here:

**A classification is worthless without the evidence that produced it.** For every
verdict you record, give the **command you ran** and the **output you saw** — a path and
a line, a quoted sentence, a grep that returned nothing. "The issue looks fixed" is not
a verdict; "`src/save.c:1204` contains the guard 0060 asks for, quoted here, read at
`2cbce753`" is.

Where a verdict would need a suite run to settle, **do not run it** unless your task
says to — record `NEEDS-RUN` and name the suite. Sizing that set is itself a finding.

## Receipt format

Write `receipts/<task-id>.md`, and make it readable by someone who was not there:

```markdown
# <task-id> — <one-line what was done>
**Status:** DONE | BLOCKED | PARTIAL
**Files touched:** <paths, with line numbers>
**Commands run:** <exact, with timeouts>
**Measurements:** <numbers, with the command that produced each>
**Claims checked vs taken on trust:** <explicit list>
**Corrections to PLAN.md / to this brief:** <what they got wrong — the next crew reads this>
**Left dirty:** <tree state for the driver>
**Owed to the user:** <any unratified decision or pixel deliverable>
```
