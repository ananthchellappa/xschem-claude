# 1403 — a hung suite had no upper bound, and T1 had no timeout at all

**The repair for the eight-hour stall of 2026-09-11**, written up in
`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md` and filed here as the
code that closes it. Two layers landed, because neither one covers what the other does.

## The defect

**A stall was the absence of an outcome rather than an outcome.** On 2026-09-11
`test_ase_optier_0963` printed 86 of its 103 rows on the display arm, stopped after row
**N3**, and sat there for **8 h 07 m** (`etimes` 29 208 s). No `ngspice` alive, no
`RESULT:` line, no error, no exit. A suite that is slow and a suite that is wedged emit
byte-identical output — none — so nothing in the session could tell them apart.

Two holes made that possible, and only one of them was known:

1. **`tests/run_regression.tcl` had no `timeout` on any of its four `exec` sites.** The
   other two drivers have had one all along — `run_suites.sh` wraps every arm in
   `timeout "$TIMEOUT"` (`SUITE_TIMEOUT`, 200 s) and `full_audit.sh` in `AUDIT_TIMEOUT`
   (300 s), and both print a stall as its own named verdict. **T1, the one suite whose
   baseline is ZERO, was the one with no bound at all** — including a six-suite display
   arm (`dcases`) where issue 1375's unclickable modal lives.
2. **Nothing bounds a bare invocation.** The command typed most often in a working
   session is `./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl`.
   No driver wraps it, no gate arms it, and a hand-rolled `for` loop around it — which is
   exactly what was running for those eight hours — inherits none of the shipped
   protections.

## What shipped

### Layer 1 — every child of T1 gets a deadline

`tests/run_regression.tcl` gains `t1_timeout` (env `T1_CASE_TIMEOUT`, default **900 s**,
`0` disables) and prefixes all four `exec` sites with `timeout --kill-after=20`.

⚠ **The number is generous on purpose.** `dcases` runs six suites under a real X display,
where a case is slower than its headless twin by a wide margin. 900 s is ~3× `full_audit`'s
cap: it bounds a hang without redefining *slow*.

⚠ **`timeout` signals the whole process group** — measured 2026-09-11 with a deliberate
grandchild — so the sixteen parallel `xargs` workers `open_close` fans out are reached
too. Without that a kill would orphan them and the next run would inherit the mess.

⚠ **The display-arm prefix sits INSIDE `devdisplay.sh exec`, not around it.**
`cmd_exec` runs its argument as an ordinary child and stays its parent, so a `timeout`
wrapped around the *script* would signal the shell and leave xschem orphaned on `:99`.
Prefixed inside, `timeout` is xschem's own direct parent. **PROC: `t1_why`** turns rc
**124** (and 137, the `--kill-after` upgrade) into a counted `FAIL` line that says
`TIMED OUT after <n>s and was killed`, in all three case loops — because a killed case
otherwise leaves only whatever it managed to print, which reads exactly like a case that
merely failed some checks.

### Layer 2 — the suite carries its own watchdog

`tests/headless/scratch.tcl`, sourced by **169 of 384** suites and already the home of the
`::exit` wrapper, gains `__wd_budget_ms`, `__wd_suite_name`, a `::puts` wrapper and
`__wd_fire`. It is armed by the suite being a suite, so it bounds the bare invocation that
nothing else reaches.

* **Budget** `XSCHEM_SUITE_WATCHDOG_MS`, default **900 000 ms**, `0` disables. A malformed
  value falls back to the default rather than disarming: a typo must not silently remove
  the only bound an unwrapped run has.
* ⚠ **The budget is deliberately LARGER than either shipped driver's**, so a run under one
  of them always reports *that* driver's verdict with *that* driver's number in it. This
  exists to bound the unwrapped case, not to compete with the wrapped one.
* **It exits 124** — `timeout(1)`'s code, and the code `run_suites.sh` already classifies
  as `TIMEOUT`. So a stall becomes a named outcome in every reader that already exists,
  with **no reader change and no change to `banner_rule.tcl`**.
* **It names the row.** `__wd_suite_name` reads `info frame 1`, because `info script`
  inside a sourced library names the *library*; and the wrapped `::puts` remembers the
  last line written **to stdout only**, so the message reads
  `###### WATCHDOG TIMEOUT ###### <suite> exceeded <n>ms -- last output: <line>`.
  *"86 of 103 rows, stops after N3"* is the finding; *"it hung"* is what an external
  timeout could already say.
* **It says it on both streams**, because a caller that captured only one of them would
  otherwise still see a silent death.
* ⚠ **And it leaves through the WRAPPED `exit`, which an external kill cannot.** Measured
  on the same hang: killed by SIGTERM the binary takes its emergency-save path and leaves
  a `/tmp/xschem_emergencysave_*` directory and the suite's scratch dir behind; the
  watchdog's clean exit leaves **neither** (26 → 26 against 25 → 26).

## ⚠ It is NOT a general timeout, and the limitation is pinned by a row

A Tcl `after` timer fires only when the interpreter reaches the event loop. Measured
2026-09-11 against this binary:

| hang shape | watchdog |
|---|---|
| `vwait` / `tkwait` — **issue 1375's modal** | **fires** |
| blocking `exec` (ngspice never returns) | does **not** fire |
| busy Tcl loop | does **not** fire |

The one class it covers is the class that bit. For the other two the answer is still an
external bound, which is what Layer 1 is for. **Row W13 asserts the limitation by
measurement** rather than by comment: if anyone later makes the watchdog general, W13 goes
red and names the paragraph in `scratch.tcl` that then needs rewriting. That is the correct
outcome, not a nuisance.

## Evidence

**RED first, and the witness was taken while the defect was live.** Two rows were written
inverted — asserting that a fixture hanging in `vwait` with a 2000 ms budget prints **no**
watchdog line and burns the full external cap — and both were **green** against the
unfixed code: 12 s elapsed, killed by SIGTERM (`FATAL: signal 15`), one emergency-save
corpse. After the change both went red: 3 s elapsed, rc 124, and the line
`###### WATCHDOG TIMEOUT ###### hangfix.tcl exceeded 2000ms -- last output: HANGFIX row N3
reached`.

**`tests/headless/test_suite_watchdog_1403.tcl`, 32 checks, floor declared at 32**, and
**identical on both arms** — every child is spawned `--nogui` on purpose, so the rows
measure the watchdog and not the display.

**Sabotage-verified, five passes**, each reddening only its own rows and nothing else:

| sabotage | rows reddened |
|---|---|
| `__wd_budget_ms` always returns 0 | W1a, W4a |
| `__wd_suite_name` names the library | W7a, W7b |
| the timer is never armed | W5b, W6a, W7a, W8a, W9a, W12a, W12b |
| the `puts` wrap records file channels too | W11c |
| one `run_regression.tcl` `exec` site loses its prefix | W15a |

Restored by `cp` from a pristine copy each time, md5 compared equal. **No `git checkout`,
`restore`, `stash` or `clean`.**

⚠ **The fourth pass reddened NOTHING on its first attempt, and that is recorded because it
is the point of sabotaging.** W11c's fixture wrote to its file channel *before* the stdout
writes, so the correct code and the broken code both answered `chan-stdout` and the row
held either way. The fixture now writes to the file channel **after** stdout, and the
ordering is called out as load-bearing in the suite. A row that cannot fail is not a test.

⚠ **T1 CAUGHT A REGRESSION THIS CHANGE INTRODUCED, WHICH IS WHY ITS BASELINE IS ZERO.**
The first cut wrote the display-arm command across a line continuation, putting `[list $dd exec]`
on one line and `$xschem_cmd` on the next. **Row V57 of `test_op_annot.tcl` went red on BOTH arms**
(`{1 1 1 0 1 1 1 1}`): its fourth leg isolates *the single line in the `dcases` loop that names
`$xschem_cmd`* and requires the devdisplay routing to be on **that** line. ⚠ **The wrong fix is to
widen the leg**, and the row says so: issue **0894** measured that a grep over the whole loop
answers `1` even with the routing stripped out entirely, because the liveness variable is named
`$dd_alive` and the runner's NODISPLAY sentence literally contains the words `devdisplay.sh start`.
So the leg stayed and the command went back onto one line, with a comment at the site saying not to
re-wrap it. `test_op_annot` reads **ALL PASS 485 headless / 492 display**.

## The adversarial review, and the three holes it found — all in the TESTS

Run against the uncommitted diff before it committed: four lenses, every finding handed to a
separate agent instructed to **refute** it. **Nineteen raised, sixteen refuted, three confirmed**,
23 agents. None was a defect in the product code; all three were rows that could not fail.

1. **Every numeric budget was pinned by an UNANCHORED SUBSTRING.** `has_text` is `string first`, so
   the needle `BUDGET 900000` sits inside `BUDGET 90000000` and `return 900` inside `return 90000`.
   The sabotage pass above tried only the **deflating** direction, which a prefix match does catch.
   **Inflating** `__wd_budget_ms` to 25 hours left the suite at 27/27 — silently reinstating the
   defect this issue exists to close. ⚠ **The mutation is not contrived:** both layers carry the
   same nominal **900 in DIFFERENT UNITS** (`t1_timeout` seconds, `__wd_budget_ms` milliseconds),
   landed in one issue and documented side by side in one CLAUDE.md bullet, so a unit mix-up is the
   likeliest future edit — and every unit mix-up in the harmful direction is a decimal-prefix
   extension, therefore silent. Now compared **by value** (`budget_of`), and `W14b` is scoped to
   `t1_timeout`'s body and anchored at both ends.
2. **`W15a` counted `$t1_pre` occurrences; it did not check POSITION.** Writing
   `concat [list tclsh ${tc}.tcl] $t1_pre` keeps the count at four while handing
   `timeout --kill-after=20 900` to the case as **argv** — no deadline applies, and the three
   longest cases in T1 (including the one that fans out sixteen parallel workers) go back to
   unbounded. Only the display arm had a positional guard, through `W16a`. Four **`W15c`** rows now
   assert the prefix position per site.
3. **Three rows were byte-exact source needles.** `W16a` pinned `[concat [list $dd exec] $t1_pre`,
   so renaming the local `dd` reddened it with the timeout still correctly placed; `W19a` pinned a
   whole source line, so `$tc` for `${tc}` reddened it. That is the brittleness the house rule
   *cite PROC NAMES, never bare line numbers* exists to prevent. `W16a` now asserts an **ordering**
   in V57's own idiom — the devdisplay token must precede `$t1_pre` on the line that builds the
   command, which is exactly the difference between the timeout being xschem's parent and being
   devdisplay.sh's — and `W19a` keeps the claim while dropping the spelling.

**Four further sabotage passes were run for the holes the review named**, none of which had been
tried before:

| sabotage | rows reddened |
|---|---|
| inflate the watchdog default 900 000 → 900 000 000 (25 h) | W1a, **W1b**, W4a |
| inflate `t1_timeout` 900 → 90 000 (25 h per case) | W14b |
| `tcases` APPENDS `$t1_pre` instead of prefixing it | W15c-tcases |
| the timeout wraps AROUND `devdisplay.sh` instead of inside it | W16a |

⚠ **And the first of those exposed one more row that guarded nothing — the row added to close the
finding.** `W1b` was written `set wd_def 900000`, comparing the *test's own constant* against the
two drivers' caps, so it stayed green when the code's default was inflated. It now reads the budget
the child actually resolved. **A row that restates the value it is guarding is guarding nothing** —
and the only reason this was caught is that the sabotage pass was re-run *after* the row was added.

⚠ **W5a does not discriminate on its own, by design.** `timeout` also exits 124, so the row
holds whether the watchdog fired or the external cap did — it pins the *code*, which is
what every reader keys on. W5b and W6a are the rows that tell the two apart, which is why
disarming the timer leaves W5a green.

**The blast radius was measured rather than assumed.** The `::puts` wrapper touches every
one of the 169 suites that source `scratch.tcl`, and the two suites that rename `::puts`
themselves — `test_ciw_actionlog_output` (25) and `test_results_select` (377) — are
`ALL PASS` with it in the tree.

## Registered, so it is not a guard nobody runs

`tests/headless/full_audit.sh`'s `nogui_tests` and `tests/run_regression.tcl`'s `hcases`.
The second is the one that matters: the driver whose hole this closes now runs the suite
that proves it is closed.
