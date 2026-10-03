# Receipt I3 — a stall bound for the three Calculator GUI suites

**Task.** Protective, not a feature: give `test_calc_skeleton`, `test_calc_widgets` and
`test_calc_buffer` an upper bound before PLAN phase 5 adds a modal argument dialog that blocks in
`tkwait`. No new rows, no moved check counts, no commit.

**Left uncommitted in the tree**, as the brief requires.

---

## 1. What changed, by file

Three files, **one non-comment line each**, placed at file scope immediately after the suite's no-X
gate and before its `if {[catch {` body:

```tcl
source [file join [file dirname [info script]] scratch.tcl]
```

* `tests/headless/test_calc_skeleton.tcl` — after the gate that prints `RESULT: ALL PASS (0 checks)`
* `tests/headless/test_calc_widgets.tcl` — after the gate that prints `RESULT: SKIP (no X: …)`
* `tests/headless/test_calc_buffer.tcl` — same, plus a paragraph on why it is compatible with band
  `CB5`, which renames `::winfo` aside globally

`git diff --stat` over the three: 120 insertions, 0 deletions; every added line but those three is a
comment.

The line arms `__wd_fire` in `tests/headless/scratch.tcl` (`XSCHEM_SUITE_WATCHDOG_MS`, `0` disables).
Nothing else scratch.tcl offers is taken: `test_scratch` is never called, so no directory is created,
and `test_sim_registry_isolate` is opt-in.

---

## 2. The claim, verified per file

The sibling crew's claim was **true for the three suites and wrong about one other**.

| suite | sources `scratch.tcl`? | `after <n>` | `vwait`/`tkwait`/`grab` |
|---|---|---|---|
| `test_calc_skeleton` | **no** | 2 (`after 5`, `after 10`, both small sleeps) | none |
| `test_calc_widgets` | **no** | 2 (`after 25 ; update`) | none |
| `test_calc_buffer` | **no** | **none** | none |
| `test_calc_scratch_reuse` | **no** | none | none |
| `test_calc_cross` | yes | | |
| `test_calc_engine` | yes | | |
| `test_calc_measure` | yes | | |
| `test_calc_plot` | yes | | |
| `test_calc_wave_dest` | yes | | |

None of the three owned suites contains a `source` statement of any kind — they each define their own
`check` / `check_expr` / `pcall` inline. So `XSCHEM_SUITE_WATCHDOG_MS` was never armed in them, and
their only `after` uses were small sleeps with no deadman, exactly as claimed.

⚠ **`test_calc_scratch_reuse.tcl` does not source it either**, so "every other `test_calc_*` suite
does" is false. It is the one calc suite where the bound would be **inert**: it has no `after`, no
`vwait`, no `tkwait`, no `grab`, no `toplevel` and no `exec` — nothing in it can reach the event loop,
which is the only place an `after` timer fires. Not changed; reported for the driver's judgement.

---

## 3. The shape chosen, and what the alternative would have cost

**Chosen: (a), source `scratch.tcl`.**

What (a) brings with it, enumerated from scratch.tcl's own file scope rather than assumed:

1. wraps `::exit` so scratch dirs are removed on every exit path — a **no-op** here, since these
   suites own no scratch dir;
2. wraps `::puts` to record the last stdout line, so the watchdog can say **where** it stopped;
3. arms `after 900000 __wd_fire`;
4. prints **one** `note:` line **on stderr**, once per process, only when HOME is **not** armed;
5. everything else is procs, called only on request.

Checked for collision and found none: zero hits in the three suites for `__wd`, `__scratch`,
`test_scratch`, `test_real_home`, `test_corpus`, `test_sim_registry` or `store_geom`.
`test_calc_buffer`'s `ns_state` / `ns_count` enumerate `info vars ::calc::*` and `info procs
::calc::*` — namespaced, so scratch.tcl's `::`-level globals are invisible to them. No suite
enumerates `info globals`. `test_calc_plot` — the fourth Calculator `dcases` entry — already sources
scratch.tcl at exactly this point, so this is the established in-batch precedent.

**Why not (b), a per-suite deadman in the `test_rdw_keys_1245` style.** `sd_arm` / `sd_poll_modal` /
`sd_disarm` are not a suite-level bound at all: they are a **per-dialog driver** with a 5 s deadman
that destroys one named window, armed and disarmed around a single row. Copying that shape would
bound one dialog, not the suite. Phase 5 will want it *for its modal rows*; it does not answer "the
suite must not hang".

And (b) done the obvious naive way is measurably worse — see the sabotage in §5.

---

## 4. The behavioural proof

### The RED: no bound, the bare spelling

A verbatim copy of `test_calc_skeleton.tcl` with `vwait ::never` injected at the point the bound now
occupies, run as `devdisplay.sh exec ./src/xschem --pipe -q --script <f>` under an outer
`timeout 25`:

```
outer-timeout rc=124  wall=25s
--- last 6 lines of what the suite said:
rename dir (null) to /tmp/xschem_emergencysave_untitled_cdegbcacbd failed
EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_untitled_cdegbcacbd

FATAL: signal 15
while editing: untitled
Terminated                 "$@"
--- any named outcome?  WATCHDOG/TIMEOUT/RESULT/OVERALL lines:
  (none -- the suite said NOTHING about stopping)
```

Only the probe's **own** outer timeout stopped it. The external SIGTERM took xschem's emergency-save
path, left a `/tmp/xschem_emergencysave_*` behind, and printed `FATAL: signal 15` — which
`banner_died` matches, i.e. a **death marker**, not a timeout. With no outer timeout, which is the
bare spelling, there is nothing at all.

### The GREEN: all three edited suites, both hang shapes

Copies of the **edited** suites with the hang injected directly after the new `source` line, budget
3000 ms, outer `timeout 25`:

```
test_calc_skeleton / vwait : rc=124 wall=4s watchdog_lines=2 death_markers=0
test_calc_skeleton / modal : rc=124 wall=3s watchdog_lines=2 death_markers=0
test_calc_widgets  / vwait : rc=124 wall=4s watchdog_lines=2 death_markers=0
test_calc_widgets  / modal : rc=124 wall=3s watchdog_lines=2 death_markers=0
test_calc_buffer   / vwait : rc=124 wall=4s watchdog_lines=2 death_markers=0
test_calc_buffer   / modal : rc=124 wall=3s watchdog_lines=2 death_markers=0
```

`modal` is `toplevel .pretendmodal ; grab set .pretendmodal ; tkwait window .pretendmodal` — the exact
shape phase 5's dialog will have. Two watchdog lines per run = stdout **and** stderr. Zero death
markers, zero emergency-save dirs. Sample:

```
###### WATCHDOG TIMEOUT ###### test_calc_widgets_modal.tcl exceeded 3000ms -- last output: HANG: a REAL modal -- grab set + tkwait window
```

### The bound is live in the **real** files, not only in copies

`XSCHEM_SUITE_WATCHDOG_MS` set small against the repo's own edited suites, no injection:

```
### test_calc_skeleton budget=300ms : rc=124 wall=1s
###### WATCHDOG TIMEOUT ###### test_calc_skeleton.tcl exceeded 300ms -- last output: ok:   S25 ...and it scrolls ITSELF, not the function browser
### test_calc_buffer  budget=50ms  : rc=124 wall=0s
###### WATCHDOG TIMEOUT ###### test_calc_buffer.tcl exceeded 50ms -- last output: ok:   CB2 a press after an UNSEPARATED edit still undoes alone (`edit separator`)
```

It names the file and the row it stopped after, which is the finding an external timeout cannot give.

### What the bound does NOT catch

Measured, same budget, same harness:

```
busy Tcl loop   : rc=124 wall=25s   (killed by the OUTER timeout) FATAL: signal 15
blocking exec   : rc=124 wall=25s   (killed by the OUTER timeout) FATAL: signal 15
```

CLAUDE.md and scratch.tcl's own comment both say this, and row `W13` of
`test_suite_watchdog_1403.tcl` pins it. **A third shape, measured here and not in that list:**

```
after 200ms of `update idletasks` only : fired=0
after one full `update`                : fired=1
```

`update idletasks` services **idle** events only, not timers. So the bound fires at a full `update`,
a `vwait` or a `tkwait`, and a suite stuck in a long run of pure `update idletasks` work would not be
interrupted either. That is also why `test_calc_widgets` did **not** fire even at a 1 ms budget on its
normal run — it reaches a full `update` only inside one conditional band — while its `tkwait` hang
fires reliably, as the table above shows. **For a blocking `exec`, a busy loop and a pure
`update idletasks` stretch, the answer is still an external bound.**

---

## 5. The sabotages

**Sabotage A — the "uniform, top of the file" instinct: source ABOVE the no-X gate.** Measured on the
headless arm with HOME **unarmed** (the bare spelling), correct placement vs sabotaged:

```
2a3
> note: this suite is using your real HOME; tests/headless/run_suites.sh test_calc_widgets_above gives it a throwaway one
```

Exactly one extra stderr line. ⚠ **Honest limit of this sabotage: T1 would not catch it.** T1 arms
HOME, so the note never prints there; `summarize_all` has no arm that matches `note:` and would drop
it; `run_suites.sh` echoes only `^note: corpus-source`. So placing the source below the gate is the
**stricter** choice — a byte-identical headless arm under every HOME — not a T1-correctness
requirement. Said plainly rather than dressed up.

**Sabotage B — shape (b) done the obvious naive way:** replace the `source` with
`after 3000 {puts "suite deadline reached" ; exit 1}`.

```
### hand-rolled deadman: rc=1 wall=4s
HANG: vwait on a variable nothing sets
suite deadline reached
```

It stops the hang, and it **names the outcome wrongly**. `t1_why`, lifted verbatim from
`tests/run_regression.tcl`:

```
t1_why 1   -> crashed, aborted mid-script, or a check failed
t1_why 124 -> TIMED OUT after 900s and was killed -- nothing after this point ran
```

`run_suites.sh` likewise classifies only `124` as `TIMEOUT`. So the naive deadman turns a stall into
"a check failed" in both drivers, prints on stdout only, names neither the suite nor where it
stopped, and would have to be written and kept in sync three times. That is the argument for (a) in
one measurement.

---

## 6. The T1 delta, derived and not predicted

Method: `summarize_all`'s **own** regexp arms lifted out of `tests/run_regression.tcl`'s text by
brace-group extraction (never retyped, no line numbers), plus `banner_complete` / `banner_died` /
`regression_case_failed` from `tests/banner_rule.tcl` — the only Tcl reader `run_regression.tcl`
sources. Eight arms lifted and all eight classified: `FAIL$`, `GOLD\?$`, `RESULT\?$`, `^FATAL`,
`^(NOGOLD|NODISPLAY)`, `^skip:`, `^RESULT:`, and the banner-trailer clause `\([^)]*\)`.

Run over each suite's **real captured output**, before and after, on **both** arms:

| suite / arm | counted | `^skip:` | `^SKIP` | `^RESULT:` | `banner_complete` | published count | verdict lines |
|---|---|---|---|---|---|---|---|
| skeleton / display | 0 | 0 | 0 | 1 | **1** | `ALL PASS (548 checks)` | 1 |
| skeleton / `--nogui` | 0 | 0 | 0 | 1 | 0 | `ALL PASS (0 checks)` | 1 |
| widgets / display | 0 | 0 | 0 | 1 | **1** | `ALL PASS (246 checks)` | 1 |
| widgets / `--nogui` | 0 | 0 | 0 | 1 | 0 | `SKIP (no X: …)` | 1 |
| buffer / display | 0 | 0 | 0 | 1 | **1** | `ALL PASS (130 checks)` | 1 |
| buffer / `--nogui` | 0 | 0 | 0 | 1 | 0 | `SKIP (no X: …)` | 1 |

**Identical before and after, every cell** — `diff` of the two score reports prints nothing. The
captured bodies themselves are byte-identical before and after on all six arm/suite pairs except
line 1, which is the harness's own `test home: throwaway /tmp/xschem-test-home.<pid>.<suffix>` banner
and carries a fresh pid per run.

**So the derived delta is zero on every term: cases +0, blocks +0, counted +0, skips +0, `wc -l` +0.**
These three were already registered in `dcases`; nothing about their registration changes.
`banner_died` is 0 and `regression_case_failed 0 <body>` is 0 on the display arm and 1 on `--nogui`,
before and after — the pre-existing asymmetry that is the whole reason they are `dcases` alone.

Per the brief and CLAUDE.md: **do not read the zero as a prediction about the trailer's `skips=`.
Read the trailer.**

---

## 7. Check counts before and after — unchanged

| suite | display arm before | display arm after | `--nogui` before | `--nogui` after |
|---|---|---|---|---|
| `test_calc_skeleton` | 548 | **548** | 0 checks | **0 checks** |
| `test_calc_widgets` | 246 | **246** | SKIP | **SKIP** |
| `test_calc_buffer` | 130 | **130** | SKIP | **SKIP** |

`src/calculator.tcl`'s md5 was identical at the start and end of the AFTER measurement window, so no
part of this is the other crew's in-flight edits moving under the measurement.

Canonical armed spelling, after the change:

```
PASS     | test_calc_skeleton           run 1/3  RESULT: ALL PASS (548 checks)
PASS     | test_calc_widgets            run 2/3  RESULT: ALL PASS (246 checks)
PASS     | test_calc_buffer             run 3/3  RESULT: ALL PASS (130 checks)
RESULT: 3/3 runs passed
```

Three neighbouring T1 cases that could plausibly have been disturbed, all green after the change:
`test_scratch_home_note` (22 checks), `test_suite_watchdog_1403` (32 checks),
`test_registered_banner_1626` (10 checks).

---

## 8. What I got wrong during the stage

1. **I first tried to take the behavioural control against a copy of `test_calc_skeleton.tcl` placed
   in the scratchpad, and it came back `RESULT: 1 FAILED (547 passed)`** — row
   `S27 the source really was read (positive control)`. The suite is path-dependent: that row resolves
   a source file relative to its own location. Harmless for the hang proof (the injected hang is
   above every check), but it falsified my assumption that the copy was a faithful control, and it is
   why §4 also proves the bound against the **real** repo files with a small budget rather than
   resting on copies.
2. **My first `summarize_all` lift was wrong twice** — a `switch -glob` whose braced patterns would
   have silently failed to match the backslash in `GOLD\?$`, and a `string first "\{"` that grabbed
   the proc's **argument list** instead of its body. Both would have produced a confident, wrong
   score. Fixed by brace-group extraction plus exact-match classification, and by making the probe
   **refuse to score** unless it can classify all four counted arms plus the three others.
3. **I expected `test_calc_widgets` to fire the watchdog at a 1 ms budget and it did not.** The
   explanation needed its own measurement (`update idletasks` does not service `after` timers), and
   it turned into the third limitation in §4 — the one that is in neither CLAUDE.md's list nor
   scratch.tcl's.

---

## 9. What I did NOT do, and the holes I am declaring

* **No row asserts that these three suites source `scratch.tcl`.** Delete the line and nothing in the
  tree reddens; the fence for the bound's *behaviour* is `test_suite_watchdog_1403`, and the fence
  for its *presence here* is this receipt and nothing else. Closing it means a row in a fourth file
  (`test_suite_watchdog_1403` or `test_scratch_home_note`, enumerating the registered `dcases`
  entries and requiring the bound), which would move **that** suite's published check count — the
  thing I was told to stop and report rather than absorb. **Driver's call.**
* **No new row and no changed row in the three suites**, per instruction 5.
* **`test_calc_scratch_reuse.tcl` left alone** — §2: not in my ownership list, and the bound would be
  inert there.
* **Did not touch** `src/calculator.tcl`, `tests/headless/test_calc_measure.tcl` or
  `tests/headless/test_calc_wave_dest.tcl` (the other crew's), the `owed.sh` ledger,
  `~/.xschem/ase_simulators`, `~/.claude/xschem_dev_display`, `~/.claude/gui_test_gate`, or
  `~/dev/xschem-op-wcard`. Did not run a full T1. Did not commit.
* **Did not run `devdisplay.sh start|stop|view`**; `status` only, and the display was found alive on
  `:99` and left as found.
* **Not verified by eyes, and nobody needs to look:** the whole of this is behavioural.

### Left behind

* **Three `/tmp/xschem_emergencysave_*` directories, dated today**, created by the three probes that
  had to be killed from outside (the RED, the busy loop, the blocking `exec`). **Not deleted**, per
  the hard rule against removing any such directory. For scale: 806 exist in total, 3.3 MB, 803 of
  them predating this stage.
* **352 KB of evidence** under
  `<scratchpad>/I3-watchdog/` — the six before/after captures, the two score reports, the hang and
  sabotage transcripts, `probe/score.tcl` and `hang/mk.awk`. Swept from 2.6 MB by deleting the
  regenerable 200 KB suite copies; `/tmp` is at 723 MB.
* `tests/headless/.scratch/` is **empty** — these suites never call `test_scratch`.

---

## 10. What the next stage must know

1. **PLAN phase 5's modal is now bounded in all three widget suites, in the one shape that matters**
   (`grab set` + `tkwait window`), but the bound's budget is deliberately **larger than either
   shipped driver's**, so a run under `run_suites.sh` still reports `TIMEOUT … (after 200s)` and a
   run under T1 still reports its own `T1_CASE_TIMEOUT`. The watchdog is the floor for the bare
   spelling only. Do not shrink it to "catch things sooner" — scratch.tcl's own comment explains why.
2. **A phase-5 row that drives the modal still needs its own per-row deadman**, `sd_arm` /
   `sd_poll_modal` / `sd_disarm` in `test_rdw_keys_1245.tcl` being the idiom: poll for `winfo exists`
   **and** the grab being that window's, never a fixed `after 100`, and disarm at the end of the row
   or the chain presses OK on a later row's dialog. The suite-level bound added here is a backstop
   that kills the run; it is not a way to pass a row.
3. **`run_regression.tcl`'s comment block about the Calculator suites is unchanged and still
   accurate.** Nothing about registration moved.
4. The claim "every other `test_calc_*` suite sources `scratch.tcl`" is **false** —
   `test_calc_scratch_reuse.tcl` does not. See §2 before repeating it.
