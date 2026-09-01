# 0801 — `test_ase_window` is load-sensitive and intermittently red on unmodified code

Status: **OPEN** (measured, NOT fixed)
Filed by: the 0674+0675+0677 crew, 2026-08-25, from its Verify-A leg.
Class: a **test** defect — a suite whose verdict depends on machine load, so a
single-run baseline cannot catch it and any crew that happens to hit it spends
its budget chasing a product bug that is not there.

## The measurement

Verify-A ran `test_ase_window` **48 times** against the (then-uncommitted)
0674+0675+0677 working tree on `:99` with openbox 3.6.1 live:

* **46 runs** `RESULT: ALL PASS (214 checks)`
* **2 runs** `RESULT: 6 FAILED (208 passed)` — rows `W1v2`, `W1v`, `W1x`, `W1z`,
  `W1za`, `W1zd`, all belonging to the **previous** commit's subject
  (0679/0692/0695/0696), in a suite file that step did not modify
  (`git diff tests/headless/test_ase_window.tcl` empty).

Both failures were the **1st and 2nd** runs of the session. The next 41 runs,
including two replays of the exact 5-suite batch that first failed, all passed.

### It reproduces on PRISTINE code under load

A/B against a `XSCHEM_SHAREDIR` farm whose four `.tcl` files were
`git show HEAD:` content, interleaved with the fixed arm:

| condition | fixed arm | pristine arm |
|---|---|---|
| idle | 20/20 ALL PASS | 20/20 ALL PASS |
| 5-way CPU load | 4/4 ALL PASS | 4/4 ALL PASS |
| **12-way CPU load** | **3/3 FAILED** | **3/3 FAILED** |

Under 12-way load **both** arms failed on the same row:

```
W7 simulator produced output before Stop -> {0} (exp {1})
```

Identical behaviour on unmodified HEAD code is direct proof the suite carries
timing-sensitive rows independent of any product change.

## The mechanism, as far as it was measured

In the failing runs `::xschem::notify_last` carried neither `menu` nor `command`
(`W1v2` read `{0 0 {}}`, `W1v` read `{0 0 0 0 0}`), i.e. both `$w1v_cmd` and
`$w1v_menu` were empty — which is either the degraded-bootstrap record (0658
deliberately carries no remedy) or the nudge never firing at all. `W1x`/`W1z`/
`W1za`/`W1zd` then cascade off the same block.

Full failing transcripts were **not** captured: `run_suites.sh` discards output
on the runs that fail, and 48 later runs with output preserved never reproduced
it. That is itself worth fixing — see acceptance 3.

## Why it is filed, not fixed

It is not the 0674+0675+0677 subject, the suite file was never modified by that
step, and it reproduces on pristine code. Charging it to that item would have
been a false attribution; leaving it unfiled would let the next crew burn a
budget on it.

## Acceptance

1. `W7` ("simulator produced output before Stop") waits on a **deterministic**
   condition rather than elapsed time — the `test_calc_skeleton` S12 precedent:
   force the race, do not hope the environment supplies it.
2. The `W1v*` block asserts the remedy fields only after confirming the notice
   came from the **full** channel, not the degraded bootstrap (which carries no
   remedy by design, fenced by NT18).
3. `run_suites.sh` **preserves** the output of runs that FAIL. Discarding exactly
   the runs worth reading is why this took 48 runs to characterise.
4. A soak row: 20 consecutive runs, identical check counts, under nominal load.

---

## 2026-08-30 — W7 seen again, by two of the four agents on item S3, and its
## acceptance row 1 is still the fix

Recorded here rather than under a new number: this is the same suite, the same
class, and the acceptance above already names `W7` by name.

* One verification agent hit `FAIL: W7 simulator produced output before Stop ->
  {0} (exp {1})` on **three consecutive runs**, then passed **six** later runs
  of the byte-identical tree. They checked it against the change under review
  and it is not attributable: with the new call removed it passed 5/5, and under
  a deliberate 4-way CPU load **both** arms passed.
* Two other agents on the same tree, same day, same display, ran the suite once
  each and got `RESULT: ALL PASS (228 checks)` — so a single green run is not
  evidence the row is stable, and a crew reading "228" as a hard tier number is
  reading one sample.

The named cliff is the fixed five-second wait at
`tests/headless/test_ase_window.tcl:2594-2601`. Acceptance row 1 above — force
the race, do not wait on the clock — remains the fix, and this is the second
crew to pay for it.
