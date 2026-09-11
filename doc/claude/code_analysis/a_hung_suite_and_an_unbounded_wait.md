# Eight hours of silence: a hung suite, an unbounded wait, and three guards that were already there

**Measured 2026-09-10/11, during Stage 0 of `doc/claude/ase_analyses_batch/` (issue 1401).**
Nothing in this report is hypothetical; every number is from the run it describes.

## What happened

Stage 0's code was written, tested RED-first, sabotage-verified and green by late evening.
The last thing outstanding was confirmation on the **display arm** — the same suites re-run
against `:99` rather than `--nogui`, because this tree's suites genuinely differ per arm
(`test_ase_window` is 56 headless against 295 on `:99`).

`test_ase_optier_0963` on the display arm printed 86 of its 103 rows, stopped after row
**N3**, and sat there. No `ngspice` process alive, no `RESULT:` line, no error, no exit.

It sat there for **8 hours 7 minutes** (`etimes` 29 208 s when it was finally read).

The session was waiting on it like this:

```sh
until grep -q '###### done ######' "$S/verify2.out"; do sleep 15; done
```

That loop has no deadline. A suite that is *slow* and a suite that is *wedged* produce
byte-identical output — none — so the wait never ended and nothing woke the session. The
work was finished; the reporting of it was not; and the difference cost a night.

## The mechanism, in three parts

**1. A hand-rolled suite loop.** To get one `RESULT:` line per suite per arm, this session
wrote its own driver: a `for` loop calling `./src/xschem --nogui --pipe -q --nolog --script
tests/headless/<t>.tcl` and grepping the output. Fourteen suites, two arms, twenty-eight
bare invocations.

**2. No timeout on any of them.** Every one of those twenty-eight commands could hang
forever, and the twenty-third did.

**3. An unbounded waiter on top.** Even a bounded suite run needs a bounded *wait*; this had
neither, so the failure had no upper bound in either layer.

## The part that makes it a discipline problem rather than bad luck

⚠ **AMENDED AFTER FILING — and the amendment is the real finding.** The first version of this
report treated the missing timeout as the failure. It was the *third* guard to be walked past,
and the least important of the three.

**The hang was already filed, already root-caused, and already announced in the suite's own
header.** Issue **1375** — *`xschem descend -fallback` raises a modal under `--script`, and it
hangs the GUI arm of a suite* — names this exact suite, records the same stall point (*"last
row reached: N3, then nothing"*), and traces it to `descend_schematic()` calling
`tcl_call("ask_save", …)` behind a gate that tests `has_x` alone. `ask_save` is a `tkwait`, and
nothing in a `--script` run can click it.

Twelve lines above the code being read, the suite says so itself:

```tcl
## ⚠ THIS SUITE NEEDS `--nogui`; its GUI arm hangs for ever (issue 1375).
```

| # | guard already in the repository | what using it would have cost |
|---|---|---|
| 1 | the suite's own header line | reading it — the file was already open |
| 2 | issue **1375**, filed, with the root cause | one grep for the suite name in `doc/claude/issues/` |
| 3 | `run_suites.sh`'s `timeout` | using the shipped driver instead of writing one |

The first two would have **prevented** the accident. The third would only have **bounded** it —
200 seconds instead of eight hours. All three were there; none was used, because the loop ran
every suite on both arms and no header was read.

⚠ **And it nearly became worse.** The stall was first written up as a *new* issue, which would
have been a duplicate of 1375 — precisely the scar CLAUDE.md names, where eight issue files
were filed four times each because crews re-derived known reds instead of grepping for them.
It was caught by finally reading the suite header. **Grep the issues directory before minting,
and read the header of any suite you are about to run in a way nothing has run it before.**

### The tooling half: the timeout that was there

**Measured:**

| | |
|---|---|
| `tests/headless/run_suites.sh` | every arm is wrapped: `out=$(timeout "$TIMEOUT" "$XSCHEM" --pipe -q --nolog --nogui --script "$f" 2>&1)`. `TIMEOUT="${SUITE_TIMEOUT:-200}"` |
| its report line | `printf 'TIMEOUT  \| %-28s run %d/%d (after %ss)\n'` — **a stall is a named verdict, printed, not an absence** |
| `tests/headless/full_audit.sh` | `TIMEOUT="${AUDIT_TIMEOUT:-300}"` on all five invocation arms, and its `SUMMARY:` line counts `crash/timeout` as its own column |
| and it already knew this failure shape | `full_audit.sh`'s own comment: a startup Tcl error popup *"does not fail, it HANGS, and paid AUDIT_TIMEOUT (300 s) plus a crash row"* |

So the correct tool would have turned eight hours into **200 seconds and one line reading
`TIMEOUT | test_ase_optier_0963`**. The cost of the bespoke loop was not the loop; it was
losing every property the shipped driver already had — the timeout, the shared banner rule
(`tests/banner_rule.tcl`, so a suite that reports and *then* dies is not scored a pass), the
gate integration, and the pause point between runs.

⚠ **CLAUDE.md warned about the adjacent hazard and not this one.** It says a bare
`for i in ...; do ./src/xschem --script t.tcl; done` *"enrols in neither"* — meaning the GUI
gate and the panel's Pause — and it names `run_suites.sh` as preferred. It does not say that
a hand-written loop also forfeits the timeout. A reader looking for reasons not to hand-roll
found one reason, judged it irrelevant (`GUI_GATE=0` was already set), and hand-rolled.
**That gap is now closed in CLAUDE.md's Tests section.**

## The guards, in the order they would have saved the night

**1. Do not hand-roll a suite loop. `run_suites.sh` is the driver.**
`tests/headless/run_suites.sh <suite> [<suite> ...]` takes a list, takes `REPEAT` for soaks,
reports `PASS`/`FAIL`/`TIMEOUT`/`NORESULT` per run, and honours `AUDIT_DISPLAY` for the arm.
If it is missing something a run needs, **extend it** — the extension is then there for the
next person, whereas a private loop rots in a scratchpad.

**2. If a bespoke invocation is genuinely unavoidable, `timeout` is not optional.**
Per *command*, not per batch, so the output names which one hung:

```sh
timeout 600 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/<t>.tcl
# rc 124 == it hung. That is a RESULT, not a gap in the log.
```

**3. Every waiter gets a deadline, and says so when it expires.**

```sh
deadline=$(( $(date +%s) + 1500 ))
until <condition>; do
  [ "$(date +%s)" -gt "$deadline" ] && { echo '!! did not finish in 25 min'; break; }
  sleep 10
done
```

**4. A stall must be a distinct outcome, never the absence of one.** This is the rule the
whole report reduces to. `PASS` / `FAIL` / `TIMEOUT` / `NORESULT` are four verdicts; "no
output yet" is not a fifth, because it is indistinguishable from "working". Both shipped
drivers get this right and the bespoke loop could not.

**5. Do not gate the whole report on the last item.** Thirteen of fourteen suites were green
on both arms hours before anyone knew it. The green, sabotage-verified majority should have
been reported — and committed — with the one outstanding suite named as outstanding. Holding
finished work hostage to one hung check converts a small uncertainty into hours of zero
delivered value.

**6. Treat a suite's first display-arm run as unexplored ground.** `run_regression.tcl`'s
case list runs `test_ase_optier_0963` **headless only** — its display arm is a path nothing
in CI has ever walked. A suite that has only ever been exercised on one arm should be given
a timeout and watched the first time it is asked to run on the other.

## Two further findings this produced, each worth its own issue

**(a) The display-arm stall is issue 1375, already filed — so nothing new was minted for it.**
86 of 103 rows, stops after row N3, no `ngspice` alive, no verdict line. Reproduced four times
now at the same point: 8 h 07 m unattended, and then a bounded re-run that exited **rc 124** at
its 600-second cap. What this session contributed is the third and fourth reproductions, the
eight-hour datapoint, and the confirmation that it is still live with issue 1401 in the tree —
all appended to **1375**, which is where it belongs.

**(b) Row X7 is intermittent, and the flake is in the SIMULATION rather than in the assertion.
Filed as issue 1402.** Three consecutive isolated runs, identical code, `HOME` and binary:
`1 FAILED`, `ALL PASS`, `ALL PASS`. The row prints its own measurements, and they settle it:

```
red    MEASURE X7 rc=1 raw=-1bytes op-vectors=0
green  MEASURE X7 rc=0 raw=284381bytes op-vectors=891
```

On the red run the simulator exited non-zero and wrote **no results file at all**, so there
were no vectors to read and the check honestly reported their absence — after the same process
had run the same bench successfully three times immediately before. And the answer moves even
when it succeeds: the low-threshold passgate's `[vth]` reads **0.42189628** on one green run
and **0.485901** on the next, about 15 %, while the ordinary passgate holds to four significant
figures. A DC operating point that is not reproducible means a bias point with more than one
solution — which is what a bandgap reference is. **The blast radius is wider than one test
row**: any number read off that bench's low-threshold devices is reproducible only by luck.

## The same family of mistake, twice more in the same session

Recorded because the pattern is the point: **the harness is part of the experiment, and a
defect in the harness reads exactly like a defect in the tree.**

* **A scratch-`HOME` race.** The first T1 baseline reported `1 FATAL` in
  `create_save/simple_inv`: `Tcl_AppInit(): failure creating …/t1home/.xschem`. Sixteen
  parallel workers raced to create `$HOME/.xschem` in a scratch `HOME` that did not exist
  yet, and the loser scores as a case failure. Issue **1397** mandates the scratch `HOME`
  and does not mention this corner. **Pre-create `$HOME/.xschem`.**
* **Editing product code under a running suite.** The second T1 baseline reported 3 failures
  in `test_ase_simcaps_0948` because `src/ase.tcl` was being edited while the run was in
  flight. The suite sources it, so it reported a defect that existed for nobody — and it
  looked exactly like a real one. **Do not edit product code while a suite is running**; the
  cheap guard is an `md5sum` of the file before and after, checked at the end of the run
  (this session did that for the final verification, and it read `src/ase.tcl: OK`).

All three are the same shape: the measurement apparatus failed, and the failure was
*legible only as a fact about the tree*. That is why a green run taken through an
unverified harness is not evidence — the point CLAUDE.md already makes about a stale binary
producing a plausible audit with wrong answers, arriving here from a different direction.

## What was actually true about the tree, once the harness stopped lying

| | |
|---|---|
| `T1` (`run_regression.tcl`, solo) | **0 counted failures**, 57 cases, 0 launch failures, 0 `exit -1` |
| `test_ase_core` | 230 → **243**, `ALL PASS`, both arms |
| `test_ase_preflight` | 115 → **122**, `ALL PASS`, both arms (floor declared for the first time) |
| the rest of the ASE family, both arms | `cosim` 341, `final` 82, `gf180` 35, `view` 32/36, `persist` 44/147, `dialogs` 37/215, `window` 56/295, `simcaps` 110, `simreg` 111, `simdlg` 5/55, `rdw_seam` 49 — all `ALL PASS` |
| sabotage | exactly nine rows red (D7a, D7b, D7c, D7e, PF222a–e), nothing else |
| `src/ase.tcl` | md5-verified unchanged across the whole final run, so the numbers describe one tree |
