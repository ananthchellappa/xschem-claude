# 1481 — the NODISPLAY arm skips its `Finish` line, so the `Start`/`Finish` case count under-counts by eleven on any box with no dev display

**STAMP:** `v1 claim=open tree=7a46275f stamped=2026-09-18 fix=untried open=1 by=F-docs`

**Status: OPEN — found 2026-09-17** by the harness concurrency batch: recorded as a new
finding in `doc/claude/harness_concurrency_batch/receipts/R1-build.md:277-282`, confirmed
against the source and filed by `receipts/claude-md.md`.
**Subject** `tests/run_regression.tcl:840-887` (the display arm) — ⚠ this read
`:825-872` until 2026-09-17, see the citation note below — and the counting rule in
`CLAUDE.md`'s Tests section that every reader of a T1 run is told to apply.
**Class** harness / verification method — a *counting rule* that under-counts silently, on
one whole class of machine, in the one suite whose baseline is ZERO.

**Related, and read them first:** **0891** (the display arm itself, and the design decision
that a missing display prints a loud but **uncounted** `NODISPLAY:` line rather than a red),
**1476** face 2 (a case that vanishes from the verdict, and nothing counts a line that is
not there — precisely the defect the `Start`/`Finish` rule was written to catch), **1477**
(a truncated verdict reads as a clean sweep), **1478** (per-case log names), **1403**
(timeouts, the other way a case disappears mid-run).

---

## Why this is a new number and not a sixth copy of something

Searched before filing, on this tree and on the other clone:

* `/usr/bin/grep -rn "73 .Finish\|84 .Start\|Finish=73\|under-count\|undercount" doc/claude/ tests/`
  → the only hit naming this asymmetry is `receipts/R1-build.md:277-282`, this batch's own
  build receipt. No issue file.
* `/usr/bin/grep -rln 'Start/Finish\|Start`/`Finish\|NODISPLAY\|nodisplay' doc/claude/issues/`
  → 1476, 1477, 1478, 1479, 0891, 0894, 1397, 1403. **Each one is about something else:**
  1476:75 and 1477:101 *cite* the `Start`/`Finish` rule as a protection and neither notices
  it has a hole; 1478:28,154 touches the NODISPLAY path only to rename the log file it
  writes; 0891 owns the `NODISPLAY` line's existence and its uncounted status, not the
  `Finish` line's absence.
* `/usr/bin/grep -rln 'NODISPLAY' /home/analog/dev/xschem-op-wcard/doc/claude/issues/`
  → 0891, 0894, 1397, 1403 — the same four, none of them this.

So the asymmetry is in no issue file. It is, pointedly, **in the file that teaches the rule**:
`CLAUDE.md` says *"Count `Start`/`Finish` pairs for cases; count log lines only for
failures"*, a sentence added because two independent passes had already miscounted, and it
is that sentence this defect defeats.

## The defect

`tests/run_regression.tcl`, display-arm loop:

```tcl
foreach dc $dcases {
    puts "Start ${dc}.tcl (display arm)"        ;# :841
    incr t1_cases
    set dclog [t1_run_file $dc .disp.log]
    file delete -force $dclog
    if {!$dd_alive} {
      incr t1_blocks
      puts $fd "${dc}.disp.log"
      puts $fd "NODISPLAY: ${dc} display arm NOT RUN -- ..."
      puts $fd "Total num fail: 0"
      puts "NODISPLAY: ${dc} display arm NOT RUN -- this arm verified NOTHING"
      continue                                   ;# :856  <-- leaves before the Finish
    }
    ...
    puts "Finish ${dc}.tcl (display arm)"        ;# :887  <-- never reached when !$dd_alive
  }
```

`$dd_alive` is 0 whenever `tests/headless/devdisplay.sh status` does not report an alive
display — a fresh boot (the dev display does not survive one), a container, a CI box, any
machine where nobody ran `devdisplay.sh start`. It is an ordinary state, not an exotic one.

**The `tcases` and `hcases` loops print their `Finish` unconditionally** (`:751`, `:807`),
and so does the `xschemtest` arm (`:910`). This one branch is the only asymmetry in the
driver.

⚠ **EVERY LINE NUMBER IN THIS FILE WAS WRONG BY +15, CORRECTED 2026-09-17.** As filed,
this issue cited `:825-872` as its subject, `:826`/`:841`/`:872` in the code block above,
and `:736`/`:792`/`:895` in the paragraph above. Measured against **`69c65249`**, every one
is **+15**: `:841`/`:856`/`:887` and `:751`/`:807`/`:910`. Nobody mis-read the file — a
single `+22/−7` edit (net **+15**) landed above all six sites on the same day this issue
was minted, from the crew fixing `W12b`. **The mechanism is this batch's own subject**: a
line number is a position in a namespace another actor is writing to, and *position is not
identity*. That same `+15` produced the batch's four-source-citation failure, in which four
passes gave three different coordinates for one sentence and **every one was correct
against the tree that pass had read**. Quoted with their text, so the next reader
re-derives rather than inherits:

```
841:    puts "Start ${dc}.tcl (display arm)"
842:    incr t1_cases
856:      continue
887:    puts "Finish ${dc}.tcl (display arm)"
```

**Re-grep before requoting these.** `/usr/bin/grep -n 'puts "Start\|puts "Finish'
tests/run_regression.tcl` is the whole check and costs nothing.

## The arithmetic, which needs no run to derive

The case lists are 3 `tcases` + 69 `hcases` + 11 `dcases` + 1 `xschemtest` = **84**
(`sed -n '23p' / '27,93p' / '309,318p' | /usr/bin/grep -o '"[^"]*"' | wc -l` → `3 / 69 / 11`).
With no dev display, all eleven `dcases` take the `continue`:

```
  84  Start lines          (every case announces itself)
- 11  dcases that continue before their Finish
= 73  Finish lines
```

A reader applying the documented rule to that stdout gets **73 cases** and concludes
**eleven cases vanished** — the exact conclusion 1476 face 2 is about, arrived at from a
perfectly healthy run. The reverse error is available too: a reader who counts `Start`
gets 84 and cannot tell from the pairs that eleven arms **verified nothing**, which is what
the `NODISPLAY:` lines are there to say.

## What it does not break

* **`results.log` is unaffected.** The NODISPLAY branch writes its own block by hand,
  including `Total num fail: 0`, and increments `t1_blocks` — so a display-less green run
  still produces the normal **83** `Total num fail:` lines. Nothing is miscounted *in the
  verdict*; the damage is entirely in the stdout-derived case count.
* **`T1-RUN-END` is correct.** `incr t1_cases` happens at the top of the loop, before the
  branch, so the trailer reports `cases=84` on a display-less box as on any other. The
  sentinel added by the harness-concurrency batch is therefore already the *right* answer
  to this question — which is why this issue is a live hole in a **documented rule** rather
  than a live hole in the harness's own counting.

  ⚠ **RE-MEASURED AND CONFIRMED 2026-09-17 by `receipts/V5.md:119-129`**, recorded here so
  that nobody files this refinement a second time believing it new. V5 read the increment
  sites rather than the comment that asserts them — `t1_cases` at `:715`, `:781`, **`:842`**,
  `:894` — and confirmed `incr t1_cases` fires **before** the `continue` at `:856`: on a
  NODISPLAY box the trailer still reports `cases=84` while stdout drops to 73 `Finish`.
  **So `T1-RUN-END cases=` is not merely the newer instrument, it is the structurally
  better one** — 1481's hole cannot reach it. That is the reverse of the intuition that the
  stdout pairs are primary and the trailer a convenience, and it is why fix direction 2
  below is written as it is. **The paragraph above already said this when the issue was
  filed**; V5 supplied the measurement, and **no part of this issue needed rewriting as a
  result.**

## Fix directions

1. **Print a `Finish` line on the NODISPLAY path too** — one `puts` before the `continue`,
   or restructure the branch so the `Finish` is unconditional. Cheapest, and it makes the
   documented rule true again. The `Finish` line would then mean "the driver finished with
   this case", which is what a reader counting pairs already assumes it means; the
   `NODISPLAY:` line on the adjacent stdout row is what says the arm verified nothing, and
   it is loud and already there.
2. **Or retire the stdout counting rule in favour of `T1-RUN-END cases=`**, which cannot
   drift because the driver increments it itself. This is strictly better as a *reader's*
   rule — but the stdout pairs are the only signal available while a run is still going,
   and a live run has no trailer yet, so direction 1 should land regardless.

⚠ **Whichever lands, it must not make the NODISPLAY arm look like a pass.** 0891 chose the
uncounted-loud-line design deliberately, following 0147's precedent, so that a headless CI
box stays green while saying out loud that it verified nothing. A `Finish` line is a
statement about the *driver*, not about the arm; if adding one would let a reader score
those eleven arms as verified, the `NODISPLAY:` text needs to stay on the same stdout row,
not be relocated.

## What holds it

Nothing yet — **this issue ships with no row.** A guard belongs in
`tests/headless/test_regression_concurrency_1476.tcl` or
`tests/headless/test_suite_watchdog_1403.tcl`, in the cheap `has_text` idiom
(`W14`–`W19`): assert that the `dcases` loop contains no `continue` that precedes its
`Finish`, or — behaviourally, once fixed — that a driver copy run with `$dd_alive` forced
to 0 prints equal numbers of `Start` and `Finish` lines. The source-text form is
milliseconds and needs no display; the behavioural form is the one that would have caught
this in the first place.

**Documented meanwhile** in `CLAUDE.md`'s Tests section, inline with the counting rule it
undermines, so no reader meets the rule without meeting its hole.

---

## UPDATE, 2026-09-18 — observed twice, and the trigger narrowed (outsider-fixes batch)

**Filed by** the outsider-fixes batch, stage F (docs crew). The defect is **still live at
`7a46275f`**, READ: the display-arm loop prints `Start` at `:1190`, both can't-run paths
leave through one `continue` at `:1212`, and `Finish` is at `:1245`
(`/usr/bin/grep -n 'puts "Start ${dc}\|puts "Finish ${dc}'`). The same three lines were
at `:841`, `:856` and `:887` at `69c65249`. **No row locks it yet.** A grep for `Finish`
over `test_home_isolation.tcl`, `test_regression_concurrency_1476.tcl` and
`test_suite_watchdog_1403.tcl` finds only a comment.

### It is no longer "derived, not measured"

* **85 `Start` / 74 `Finish` / 11 `NODISPLAY`, three runs.** MEASURED by the S1 crew in a
  `git archive` export, with `devdisplay.sh` stubbed so that `status` said dead and `start`
  refused (pre-D8 code, 85-case tree; `receipts/S1.md` §7). Each run was solo, with 0
  lines of `another regression run is live`.
* **87 `Start` / 76 `Finish`**, with `T1-RUN-END cases=87` correct. MEASURED by the R3
  prover on the new code, with a PATH `Xvfb` that exits 1 (`t1_h8_brokenx`,
  `receipts/S2c-R3-prove.md`). The trailer's counter was right in both, as this file
  predicted: `incr t1_cases` precedes the branch.

### The trigger is narrower now (DECISIONS D8, `7a46275f`)

This file's premise, *"`$dd_alive` is 0 whenever `devdisplay.sh status` does not report
an alive display — a fresh boot, a container, a CI box"*, **no longer reaches the
`continue`** on a box with a working Xvfb. Such a box now runs the 11 `dcases` on a
**private Xvfb numbered from `:100`, for that run only**. The stage-F gate printed
`display arm: PRIVATE Xvfb :100 for this run only` and 87 `Start` / 87 `Finish`. The
`continue` is reached only:

1. with **no Xvfb installed**: an uncounted `NODISPLAY:` line per case, as 0891 designed;
   or
2. with an **installed Xvfb that will not start**: a **counted** `HARNESS: <dc> display
   arm NOT RUN -- Xvfb is installed but no display could be started (…): FAIL` per case
   (D17.9), 11 counted failures.

So the shape to fear is a stripped container or CI image without `xvfb`. That is still
the box nobody watches.

### What this changes about the fix

* **Fix direction 1 got easier on one path.** On the `HARNESS` path the case is already
  a counted red, so a `Finish` line there cannot make it read as a pass. The caution in
  "Whichever lands" now applies to the `NODISPLAY` path alone.
* **The arithmetic above is the 84-case tree's.** Today it is 87 `Start` against 76
  `Finish` (MEASURED, the R3 prover). The verdict carries 86 `Total num fail:` lines
  whichever path the arm takes. That is MEASURED on the green gate
  (`T1-RUN-END … blocks=86`), and on the can't-run paths it is READ from the branch's own
  `incr t1_blocks`. CLAUDE.md's Tests section carries the corrected numbers inline with
  the rule.
