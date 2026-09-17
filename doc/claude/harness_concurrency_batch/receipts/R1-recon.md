# R1-recon — can two regression runs BOTH proceed today? Measured: the CASES can; the DRIVER still cannot

**Status:** DONE

**Headline.** Two concurrent `open_close.tcl` runs staggered 5 s apart both produced a
verdict **identical to the solo baseline** — 0 phantom FATALs each, against the 407/432/757
PLAN.md records before B1. B1's per-run roots work. **But the verdict file was never the only
single-slot object**, and `DECISIONS.md:129`'s claim that it was is **false**: a full T1 run
writes **83 fixed-name per-case log files that are verdict INPUTS**, and I measured a
collision on one producing a wrong answer **in both directions** — a silent phantom PASS and
a phantom RED — using the tree's own shipped `banner_rule.tcl` predicate.

---

## Files touched

**None modified.** Read-only recon plus two bounded experiments. Files *read*:
`tests/open_close.tcl`, `tests/create_save.tcl`, `tests/netlisting.tcl`,
`tests/test_utility.tcl`, `tests/run_regression.tcl`, `tests/banner_rule.tcl`,
`tests/headless/scratch.tcl`, `src/util.c:273-418`, `.gitignore`, the batch's
`PLAN.md`/`DECISIONS.md`/`LEDGER.md`/`CREW_BRIEF.md`.

Experiment scratch lives in the session scratchpad
(`/tmp/claude-1000/.../scratchpad/{solo,pairA,pairB,mem,hc,hc2,hc3}*`), **not** in the repo.

## Rows added/changed

**None.** This task added no suite rows — it is recon plus measurement, as briefed.

---

## Commands run

Every command carried a `timeout`. Exact forms:

```sh
timeout 600 make -C src                                   # -> "Nothing to be done for 'all'"
timeout 300 tclsh open_close.tcl                          # solo baseline, from tests/
timeout 300 tclsh open_close.tcl  (x2, 5 s apart)         # the staggered pair
timeout 120 ./src/xschem --nogui --pipe -q --script tests/headless/test_callback_argc.tcl
timeout 60  tclsh   <<'EOF' ... source banner_rule.tcl    # scoring the log collisions
timeout 60  tests/headless/devdisplay.sh status
```

Never a bare `xschem`: every invocation is `./src/xschem` or `tclsh <case>.tcl` (which
resolves the binary through `test_utility.tcl:47-49`, the in-tree path).

**Solo-ness confirmed before measuring.** `pgrep -af run_regression` / `-af open_close`
returned **only my own shell's command line** (self-match). `pgrep -af xschem` showed six
processes, all from **`/opt/xschem-repo`** (the user's `pdk_launcher` on `DISPLAY=:10`) —
a different tree, not this one, and not a regression run. `tests/results.log` mtime was
`1789642203` (G1's run, 03:50) and never moved.

---

## Part A1 — `publish_results`, read exactly

`publish_results` is **`tests/test_utility.tcl:214-226`**:

```tcl
proc publish_results {testname resdir} {
  set canon $testname/results
  if {$resdir eq $canon || ![file isdirectory $resdir]} { return 0 }
  if {[catch {
        file delete -force $canon          ;# :218
        file rename -force $resdir $canon  ;# :219
      } e]} {
    puts "WARNING: could not publish $resdir as $canon ($e) -- this run's result\
 files are in $resdir"
    return 0
  }
  return 1
}
```

### Q1: if two runs both reach it, is either *verdict* corrupted?

**No. It is last-writer-wins on the published artifact tree only.** The code that settles it
is the call ORDER in all three cases — the verdict is computed first, from the private root:

| case | verdict computed | published |
|---|---|---|
| `open_close.tcl` | `:139` `print_results $testname $pathlist $num_fatals $resdir` | `:140` |
| `create_save.tcl` | `:111` | `:112` |
| `netlisting.tcl` | `:152` | `:153` |

and `print_results` reads **only** `$resdir` — `test_utility.tcl:296` (`![file exists
$resdir/$f]` → `RESULT?`) and `:300` (`comp_file $testname/gold/$f $resdir/$f`) — with
`$resdir` defaulting to the canonical name only for a caller that passes none (`:279`).
`$testname/gold/` is read-only. So by the time `publish_results` runs, the verdict is already
written to `$testname.log` and nothing in `publish_results` can change it.

### Q2: can A's `publish_results` delete or rename a directory B is still using?

**Not the private roots.** `$canon` is `$testname/results`, which has **no `.<pid>` suffix**,
so `:218`'s delete cannot match B's `results.<pidB>`. The guard at `:216` also makes the proc
a no-op if it is ever handed the canonical name.

**The one genuine race is `:218`→`:219`**: A deletes `$canon`, B deletes `$canon` (gone
already), A renames its dir onto `$canon`, B renames onto the now-existing `$canon`. Tcl's
`file rename -force` onto an existing non-empty directory can fail; `:217`'s `catch` turns
that into `WARNING` at `:221-223` and the loser's files stay under `results.<pid>`. The
failure direction is "a leftover survives", never "a live run's tree is deleted".
**Measured on the pair: `WARNING` = 0 in both runs, and the canonical tree ended with exactly
1898 files** — one run won cleanly, the other's tree was replaced. Artifact only.

The other deleter, `sweep_dead_run_dirs` (`test_utility.tcl:239-251`), globs `results.*` and
`.work.*` but skips its own pid and any pid with `/proc/$p` present (`:244`), so a live run's
dirs are never swept. **Measured: `swept` lines = 0 in both runs of the pair.**

---

## Part A2 — `run_regression.tcl` at HEAD, exact line numbers

| what | line(s) |
|---|---|
| `set log_fn "results.log"` | **:319** |
| `set lock_file "$log_fn.lock"` | **:525** |
| lock taken (`t1_lock_take` call, env defaults `T1_LOG_LOCK_WAIT`=0, `T1_LOG_LOCK_TTL`=14400) | **:526-527** |
| `t1_lock_take` body | **:481-523** — O_EXCL create at **:488**, break-on-evidence **:500-514**, fail-open **:502-506**, refusal return **:515**, `WAITING` message **:519** |
| refusal block (loud), `exit 2` | **:528-547**, exit at **:546** |
| waited path PRESERVES prior verdict as `results.<pid>.log` | **:554-561** |
| verdict file opened mode `w` | **:563** |
| verdict closed | **:720** |
| lock released (both arms) | **:732** |
| `summarize_all` (the counted-shape rule) | **:321-351**, the four regexps at **:327** |

### Is the verdict channel `fconfigure`d?

**No.** `grep -n "fconfigure\|flush" tests/run_regression.tcl` returns **zero hits**. The
channel opened at `:563` is still **full-buffered at 4096 B** against a 4785-byte verdict —
**issue 1477's hole is entirely open at HEAD.**

### Is there a start/end sentinel?

**No.** All 12 `puts $fd` sites (`:322, :328, :339, :342, :348, :349, :671, :672, :673, :714,
:715, :716`) are per-case block content. The first byte written is `summarize_all`'s
`puts $fd "$fn"` at **:322**. Nothing marks that a run began or ended.

---

## Part A3 — EVERYTHING ELSE TWO RUNS SHARE

This is the part that matters, and it refutes the batch's current premise.

**A full T1 run writes 88 fixed-name files under `tests/`.** Counted from the case lists
(`sed -n '23p'` → 3 tcases; `sed -n '27,93p'` → **69** hcases entries; `sed -n '309,318p'` →
**11** dcases entries; +`xschemtest`; = **84 cases**, matching CLAUDE.md):

```
  3 tcases  x (<tc>.log + <tc>_output.txt)   =  6
 69 hcases  x  <hc>.log                      = 69
 11 dcases  x  <dc>.disp.log                 = 11
    stefan_xschemtest.log + results.log      =  2
                                        total 88
```

**The lock protects 1 of those 88.** Of the other 87, **83 are verdict inputs** —
`summarize_all` and `regression_case_failed` are applied to their contents.

| # | shared object | writer (file:line) | reader | verdict |
|---|---|---|---|---|
| 1 | `tests/results.log` (+ `.lock`) | `:319`, `:563` | the operator, `crew.js` | **CLOSED by C1's lock** |
| 2 | `tests/<tc>.log` ×3 | `test_utility.tcl:281` (`open "$testname.log" w`, **no pid**); deleted `run_regression.tcl:571` | `:587` `summarize_all` | **WRONG ANSWER** |
| 3 | `tests/<tc>_output.txt` ×3 | `run_regression.tcl:574` | nothing parses it | NOISE (but it is the only place a case's FATAL detail survives → evidence loss) |
| 4 | `tests/headless/<hc>.log` ×69 | `run_regression.tcl:620` (`> ${hc}.log`, O_TRUNC) | read `:625`, scored `:626-631`, counted `:633` | **WRONG ANSWER — MEASURED, both directions** |
| 5 | `tests/headless/<dc>.disp.log` ×11 | `:669` delete, `:691` write | read `:696`, counted `:704` | **WRONG ANSWER** (same shape as #4) |
| 6 | `tests/stefan_xschemtest.log` | `:713` | only the exec rc is scored (`:713-718`) | NOISE |
| 7 | `tests/results/.actionlogs/Xschem.log[.N]` | `run_regression.tcl:661` (`file mkdir`, shared fixed dir); chosen by `src/util.c:383-399` | suites that read their own log back | **WRONG ANSWER** — see below |
| 8 | `~/.xschem/` | GUI/display arm | suites pinning registry/geometry state | **WRONG ANSWER** for the 15 unisolated suites |
| 9 | the dev display `:99` | dcases map real windows | focus/pointer grabs are server-global | NOISE → WRONG ANSWER for grab/focus rows |
| 10 | `~/.claude/gui_test_gate/` | `gui_gate.sh` | — | NOISE: `devdisplay.sh exec` sets `GUI_GATE=0`, so T1's display arm never arms it |
| 11 | `tests/headless/.scratch/_<tag>_<pid>` | `scratch.tcl:119` | — | **SAFE** — pid-scoped; sweep skips live pids (`:75`) |
| 12 | `.parallel_jobs.[pid]`, `.cleanup_files.[pid]` | `test_utility.tcl:82`, `:135` | — | **SAFE** — pid-scoped |
| 13 | `<case>/results` canonical | `publish_results` `:218-219` | gold promotion, humans | artifact only, last-writer-wins |
| 14 | fixed `/tmp` paths in T1 suites | e.g. `test_ase_core.tcl:1673` `/tmp/osdi_fixture` | | NOISE — most are deck *strings* never written |
| 15 | CPU / RAM / the box | — | — | see A4 |

### #4 measured — the per-case log collision, scored by the shipped rule

`run_regression.tcl:620` is `exec … > ${hc}.log` — a fixed name, O_TRUNC, one slot per suite
*name*, not per run. Two runs of the same suite write the same file. I ran the collision and
scored the result with `tests/banner_rule.tcl` exactly as `:626-631` does.

**Direction 1 — the SILENT one (both children exit 0, the ordinary shape: a suite that
reports N failed checks still prints its banner and exits 0):**

```
run A body: ok / broken thing A : FAIL / broken thing B : FAIL / RESULT: 2 FAILED / OVERALL: ok
run B body: ok / ok / RESULT: ALL PASS (2 checks) / OVERALL: ok
file on disk after both:  B's body (+ a 5-byte tail fragment "ILED" from A)

run A: childcode=0 -> regression_case_failed = 0     (no synthesized FAIL)
summarize_all counts 0 failures -- run A's TWO real failures reported as 0
```

**A whole suite's failures vanish and the run reports green.** That is face 4 — the dangerous
direction — reproduced in the per-case log, which the lock does not touch.

**Direction 2 — the phantom RED (failing body lands last):**

```
the PASSING run's driver counts 1 failure(s) it did not earn
```

**Direction 3 — the diagnosis is destroyed even when the count survives.** With run A's child
exiting 1 and B's body on disk, `regression_case_failed 1 <B's body>` = 1, so A does get a
counted failure — but `summarize_all` counts **0** lines from that body, so A's real
`something broken : FAIL` is gone and the operator is told only "did not complete cleanly".

### #7 measured — the action-log directory is not just noisy

`run_regression.tcl:661` gives every display-arm child the **same** `--logdir`
(`tests/results/.actionlogs`). `src/util.c` picks the filename with a classic TOCTOU:

```c
383  for(i = 0; i < ACTIONLOG_KEEP; ++i) {
385    if(stat(fname, &buf)) { slot = i; break; }   /* free slot */
386    if(i == 0 || buf.st_mtime < oldest_mtime) { oldest_mtime = buf.st_mtime; oldest = i; }
388  if(slot < 0) slot = oldest;                    /* all full -> recycle the oldest */
399  actionlog_fp = fopen(fname, "w");
```

`stat()` then `fopen(…, "w")` — **not atomic**, no `O_EXCL`. And it is worse than a race
today: `ACTIONLOG_KEEP` is **10** (`:277`) and the directory **already holds exactly 10 files**
(`Xschem.log`, `.1` … `.9`, all mtime 03:49-03:50). So every new session now takes the
`slot = oldest` branch at `:388`, which is **deterministic** — two concurrent runs pick the
*same* slot by arithmetic, not by luck, and the second `fopen(…,"w")` truncates the first's
live log. Suites that read their own action log back (`test_op_annot` W23 at `:9749-9761`,
`test_annot_show_menu:279`, `test_ase_campaign_gui_1464:1669-1675`) would be reading the other
run's. The comment at `:378-379` — *"The oldest is almost never a concurrently-open session"* —
is true for sequential runs and false for concurrent ones.

### #8 measured — `~/.xschem/` and how much of T1 is isolated

`scratch.tcl` provides `test_scratch` (`:104-124`) and `test_sim_registry_isolate`
(`:166-190`), and **`:148-153` states in terms that nothing there touches a file** — the
registry isolation is memory-only by design.

Measured coverage of T1's own case list:

* **4 of 4** root hcases (`hilight_hier_oracle`, `hilight_hier_dump_replay`,
  `hilight_xwin_sync_headless`, `buried_hilight`) do **not** source `scratch.tcl`.
* **15 of 66** registered `headless/` suite names do not source it — including
  `test_recent_conf_compat_0924`, `test_sky130a_libmgr`, `test_gf180mcud_libmgr`,
  `test_ihp_sg13g2_libmgr`, `test_pdk_launcher`, `test_results_freshness`.
  (`test_recent_conf_compat_0924` names `USER_CONF_DIR` and does **not** source `scratch.tcl`.)
* 51 of 66 do source it. Repo-wide, `scratch.tcl` is sourced by **195 files / 191 headless
  suites** — which is why `DECISIONS.md:171-172`'s refusal to redirect `USER_CONF_DIR` there
  is right about the blast radius.

**Which `~/.xschem` files a T1 run writes, measured by mtime against G1's run window
(03:43-03:50):** `geometry` (03:49), `.clipboard.sch` (03:44), `op_annot/` (03:49),
`simulations/` (03:44). Untouched: `ase_simulators`, `recent_files`, `xschemrc`,
`op_param_lists.conf`, `pdk_launcher.conf`, `raw_history`.
⚠ This is **correlational** (mtime inside the run window), not a traced write.
**Measured directly: my open_close runs did NOT touch `~/.xschem` at all** — every mtime was
unchanged at 06:40 from its 03:44/03:49 pre-value. So the golden cases are clean; the GUI and
unisolated headless arms are where this lives.

---

## Part A4 — resource reality (measured, not guessed)

| quantity | measured | command |
|---|---|---|
| cores | **20** | `nproc` |
| RAM | **16091816 kB = 15.35 GiB** | `/proc/meminfo` MemTotal |
| swap | 4 GiB | `/proc/meminfo` |
| parallel jobs per T1 case | **16** (`nproc - 4`, `test_utility.tcl:65-74`, floor 1) | run stdout: `Running 1898 open_close jobs on 16 parallel workers` |
| peak concurrent `xschem` during the pair | **31** | 1 Hz `ps` sampler |
| peak combined `xschem` RSS | **487 MB** | same |
| min MemAvailable during the pair | **5282 MB** | same |
| peak 1-min loadavg | **18.06** | same |

### ⚠ CLAUDE.md AND DECISIONS.md ARE BOTH WRONG ABOUT THIS BOX'S RAM

CLAUDE.md (issue 1477 bullet) says **"this ~7.8 GB box"**; `DECISIONS.md:154` repeats it as
**"this ~8 GB box"**. Measured: **MemTotal 16091816 kB ≈ 15.35 GiB**, roughly **double**.
This matters because `DECISIONS.md:153-156` asks this recon to assess OOM risk *against that
number*, and the number is wrong in the direction of alarm.

**CPU: yes, oversubscribed — 32 workers requested on 20 cores.** Cost measured:

| run | wall |
|---|---|
| solo | **26.85 s** |
| pair, run A | **55.13 s** (2.05× solo) |
| pair, run B | **59.44 s** (2.21× solo) |

**Both verdicts are available 64.4 s after A starts** (B began at +5 s). Running the two
**back-to-back** costs **53.7 s**. So for the golden cases, *concurrency is ~20% SLOWER
to-both-answers than serialising*. Two runs do not finish sooner; they finish later, twice.

**OOM: not a risk from this shape.** 487 MB peak against 5.3 GB available is two orders off.
⚠ **But I measured only `open_close`.** 1477's OOM is not attributed anywhere I can check, and
the memory-hungry arms — the dcases under X, and the `hcases` that start real `ngspice`
(`test_ase_sp_1452`, `_converge_1459`, `_campaign_1462`, `_campaign_gui_1464`,
`_trnoise_1466`) — were **not** measured here. Two concurrent T1 runs would double *those*,
and that is the arm where an OOM is plausible. **Unmeasured, and I am not claiming it is safe.**

---

## Part B — the bounded experiment

**THE KEY QUESTION: do both runs survive and both produce the solo verdict? YES.**

| | solo | pair A | pair B |
|---|---|---|---|
| rc | **0** | **0** | **0** |
| wall | 26.85 s | 55.13 s | 59.44 s |
| jobs planned | 1898 | **1898** | **1898** |
| `^FATAL` | **0** | **0** | **0** |
| `exit -1` (the phantom tell) | **0** | **0** | **0** |
| `NO STATUS FILE` | 0 | **0** | **0** |
| `UNREADABLE STATUS FILE` | 0 | **0** | **0** |
| `cleanup_debug_files` problems | 0 | **0** | **0** |
| `WARNING` (publish failure) | 0 | **0** | **0** |
| `swept` (dead-dir sweeps) | 0 | **0** | **0** |
| stdout lines | — | 1900 | 1900 |
| died at startup | no | **no** | **no** |

Both runs reached `print_results` with `num_fatals = 0` and a full 1898-entry pathlist (0
FATALs ⇒ every job's status file was read), so **both computed the solo verdict**. The
canonical `open_close/results` afterwards holds exactly **1898** files. No `results.<pid>`
or `.work.<pid>` leftovers.

**Compare PLAN.md's pre-fix record** (3/6/9 s stagger): 407 / 432 / 757 phantom `FATAL … exit
-1` in run A and run B **dead, rc 1** in all three. Today: **0 and 0, both rc 0.** B1's fix is
real and I re-measured it rather than inheriting it.

**`tests/results.log` was never touched** — mtime `1789642203` and md5 `cb8b3911…` before and
after, still G1's green verdict. `open_close.tcl` run directly takes no verdict lock, which is
exactly why it is the right probe.

**The shared `tests/open_close.log` is invisible here and that is the trap.** Both runs wrote
that one fixed-name file (`test_utility.tcl:281`); one survived. Their content was identical
(`NOGOLD … 1898 result file(s) produced`), so the collision left no trace. Under `run_regression`
it would not be identical — see A3 #2 and #4.

---

## Part C — the proposed "both runs proceed" design, costed

Design as stated: per-pid `results.<pid>.log`, canonical `results.log` tracks the most recent
completed run, header (pid/script/start) + trailer (pid/case count/counted failures).

### Which shared objects would STILL break

**The design closes exactly one of the 88 fixed names.** Still broken, in priority order:

1. **`tests/headless/<hc>.log` × 69** — `run_regression.tcl:620/625/633`. **Measured wrong
   answer, both directions, including the silent one.** This is the same defect as face 4, in
   69 more files, and it is *upstream* of the verdict: fixing `results.log` while this stands
   means each run writes a correct-looking verdict computed from the other run's body.
2. **`tests/headless/<dc>.disp.log` × 11** — `:669/691/696/704`. Identical shape.
3. **`tests/<tc>.log` × 3** — `test_utility.tcl:281` + `run_regression.tcl:571/587`. Extra
   sharpness: `:571` *deletes* the log at the next case's start, so B's delete between A's case
   exiting and A's `summarize_all` at `:587` makes A take the `:348` branch —
   `HARNESS: <fn> missing -- case produced no log (never ran?): FAIL`, **a counted failure that
   never happened**, in the one suite whose baseline is ZERO.
4. **`tests/results/.actionlogs`** — deterministic slot collision (`util.c:388`), non-atomic
   `fopen(…, "w")` at `:399`, read back by three T1 dcases.
5. **`~/.xschem/`** — 19 T1-registered suites (4 root + 15 headless) do not source `scratch.tcl`.
6. **The display `:99`** — focus and pointer grabs are server-global; two runs' dcases coexist.
7. **CPU** — 32 workers on 20 cores, measured **slower to-both-answers than serialising**.

**The fix for 1-3 is the same one B1 already used**, and it is cheap: the per-case logs take a
`.<pid>` infix and are published (or simply left per-run — nothing outside the driver reads
them; `.gitignore:94-95` covers `tests/headless/*.log` and `tests/*.log` either way). That is a
much smaller change than the verdict rework and it is the one that decides whether "both runs
proceed" means "both proceed **correctly**".

### Do the header/trailer sentinels close the two recorded traps?

**FOSSIL — YES, and better than mtime.** A trailer naming pid + start time makes a stale
`results.log` self-identifying from content alone. Today only the mtime separates "rewritten
identically" from "never rewritten", and CLAUDE.md:99-113 records two receipts and a commit
message carrying a case count taken from a fossil. Caveat: it only helps a reader who looks, so
CLAUDE.md's reading rule has to change from *"confirm the mtime moved"* to *"read the trailer"* —
otherwise the sentinel is written and never consulted.

**1477 TRUNCATION — YES, and this is the stronger half.** "No trailer ⇒ did not finish" is
decidable from content, which is exactly what *every prefix of a green run is itself a green
run* defeats. The 4096-byte buffer against a 4785-byte verdict actually **helps** here: a killed
run cannot have flushed the trailer.

⚠ **But only if the channel is fixed at the same time.** There is still **no `fconfigure` and
no `flush`** anywhere in `run_regression.tcl` (measured: zero hits). With full buffering the
**header** sits in the buffer too, so a run killed early leaves a 0-byte file with neither
header nor trailer — which reads as "never started" rather than "started and died". If the
header is meant to mean "a run is in progress", it must be flushed. **One line at `:563`:**
`fconfigure $fd -buffering line` (or an explicit `flush $fd` after the header). Without it the
sentinels inherit the very hole they were added to close.

### Every reader of the canonical name

Measured with `grep -rn "results\.log"` repo-wide plus `--include=*.sh`.

**Code / behaviour — must be updated:**

| file:line | what |
|---|---|
| `tests/run_regression.tcl:319` | `set log_fn "results.log"` |
| `tests/run_regression.tcl:525` | `set lock_file "$log_fn.lock"` |
| `tests/run_regression.tcl:554-561` | preserve-as-`results.<pid>.log` (becomes redundant) |
| `tests/run_regression.tcl:563` | the `open … w` |
| `tests/headless/test_regression_concurrency_1476.tcl:38` | quotes `set log_fn "results.log"` |
| `tests/headless/test_regression_concurrency_1476.tcl:92` | asserts the fixtures' lock is `<scratch>/results.log` |
| `tests/headless/test_regression_concurrency_1476.tcl:100` | **row `V1b` reds if `results.log` is renamed** — written to enforce R1 as originally ruled; the driver's new R1 supersedes it, so this row must be rewritten, not deleted |
| `tests/headless/test_regression_concurrency_1476.tcl:467` | `slurp [file join $fdir results.log]` |
| `.gitignore:96, 118-123` | `tests/*/results.log`, the `.lock` rule and its comment (`:122` already anticipates `tests/results.<pid>.log` and notes `tests/*.log` covers it) |

**Prose read by agents — must be updated or they will instruct the wrong thing:**

| file:line | what |
|---|---|
| `CLAUDE.md:59, 65, 82, 84, 94, 99, 103, 114, 144, 158, 170` | the whole "Reading `results.log`" block, including "confirm the mtime moved" and the SOLO bullet |
| `doc/claude/ledger/crew.js:184, 187-189, 504` | *"Run it SOLO — two concurrent runs … truncate each other's `results.log`"* |
| `doc/claude/ledger/crew_annotate.js:86, 90` | the T1 line + the counted-shape rule |
| `doc/claude/ledger/crew_opfix.js:95, 99` | same |
| `doc/claude/op_param_batch/item_pipeline.js:119, 123` | same |

**Measured, and good news for the design: NO shell script reads `results.log`.**
`grep -rn "results\.log" --include=*.sh .` returns **zero hits** — `run_suites.sh` and
`full_audit.sh` neither read nor write it. `tests/hilight_xwin_sync.tcl:32` has a
`results.log` of its own under `tests/hilight_xwin_sync/`, unrelated and covered by
`.gitignore:96`.

### Rough size of the change in `run_regression.tcl`

Anchors: the file is **732 lines**; C1's lock block is **157 lines** (`:405-561`), of which
roughly 110 is comment.

* per-pid name + publish to canonical: **~6 lines** (`:319`, plus a rename near `:720`)
* header: **~4 lines** (after `:563`)
* `fconfigure … -buffering line`: **1 line**
* trailer: **~8 lines** — **and it needs two counters that do not exist today.**
  `summarize_all` (`:321-351`) returns nothing; its `num_fail` is local. Making the trailer
  report *counted failures* means returning it and accumulating at **all five** counting sites
  (`:587`, `:633`, `:704`, and the two inline blocks `:671-673`, `:714-716`). A *case count*
  needs a third counter, since the driver tracks `Start`/`Finish` only as printed text.
* sweeping stale `results.<pid>.log` (reuse `sweep_dead_run_dirs`'s idiom,
  `test_utility.tcl:239-251`) so verdicts do not accumulate one per run: **~10 lines**

**Code: ~30-40 lines changed or added.** At this file's comment density (the lock block is
~70% comment and every ⚠ paragraph in it is load-bearing), the realistic diff is
**~100-150 lines added, ~8 changed.** The lock block itself should be *retained and demoted*
as `DECISIONS.md:150-151` says — deleting it loses the evidence-based stale-lock logic, which
is the only correct code in the tree for "is that pid still the thing that took this".

**One implementation note:** publish the canonical name with `file rename` or a copy,
**not a symlink**. A symlink adds a dangling-link state the moment the per-pid file is swept,
and `sweep_dead_run_dirs`'s own contract ("the failure direction must be 'a leftover
survives'") is easier to honour with a real file.

---

## Measurements, with the command that produced each

| measurement | value | command |
|---|---|---|
| cores | 20 | `nproc` |
| RAM | 16091816 kB | `grep MemTotal /proc/meminfo` |
| build state | up to date | `timeout 600 make -C src` → `Nothing to be done for 'all'` |
| solo `open_close` | rc 0, 26.85 s, 1898 files, 0 FATAL, 0 `exit -1` | `timeout 300 tclsh open_close.tcl` |
| pair A | rc 0, 55.13 s, 0 FATAL, 0 `exit -1`, 0 WARNING | same, backgrounded |
| pair B | rc 0, 59.44 s, 0 FATAL, 0 `exit -1`, 0 WARNING | same, +5 s |
| both-answers time, concurrent | 64.4 s | `date +%s.%N` either side |
| both-answers time, serial | 53.7 s | 2 × solo |
| peak xschem procs / RSS | 31 / 487 MB | 1 Hz `ps -eo rss,comm` sampler |
| min MemAvailable | 5282 MB | same sampler |
| `results.log` untouched | mtime 1789642203, md5 `cb8b3911…`, 4785 B, before **and** after | `stat`, `md5sum` |
| case-list sizes | 3 / 69 / 11 (+1) = 84 | `sed -n '23p'`, `'27,93p'`, `'309,318p'` + `grep -o` |
| `fconfigure` in run_regression | **0** | `grep -n "fconfigure\|flush"` |
| shell readers of results.log | **0** | `grep -rn "results\.log" --include=*.sh .` |
| suites sourcing scratch.tcl | 195 files / 191 headless; 51 of 66 registered | `grep -rln` |
| `<hc>.log` collision, silent direction | A's 2 real failures counted as **0** | `banner_rule.tcl` + `summarize_all`'s regexps on the collided file |
| `<hc>.log` collision, phantom red | passing run counts **1** failure it did not earn | same |
| actionlog slots occupied | **10 of 10** (`ACTIONLOG_KEEP`) | `ls tests/results/.actionlogs` |

---

## Claims checked vs taken on trust

**Checked and CONFIRMED:**
* PLAN.md's pre-fix phantom counts are no longer reproducible — **0 phantoms, both runs rc 0**.
* `publish_results` cannot corrupt a verdict — confirmed by the call order at
  `open_close.tcl:139-140` and `print_results`' use of `$resdir`.
* C1's lock exists, is O_EXCL (`:488`), refuses with `exit 2` (`:546`), preserves on the
  waiting path (`:554-561`).
* CREW_BRIEF rule 5's case-count arithmetic: 3 + 69 + 11 + 1 = **84**, as CLAUDE.md:118 says.
* `.gitignore` already covers `tests/results.<pid>.log` via `tests/*.log` (`:95`, and `:122`
  says so explicitly).
* `scratch.tcl` touches no file for registry isolation (`:148-153`) — confirmed by reading
  `test_sim_registry_isolate` (`:166-190`), which only clears in-memory state.

**Checked and REFUTED — see the corrections section.**

**Taken on trust (NOT verified by me):**
* That issue 1477's truncated `results.log` was caused by an OOM. I did not reproduce it and
  the memory-hungry arms were not measured.
* PLAN.md's 2026-09-16 numbers themselves (407/432/757) — I measured only the *post-fix* state.
* That the `~/.xschem` writes I attribute to T1 came from T1: mtime correlation with G1's
  03:43-03:50 window, not a traced write.
* G1's and V2's T1 results. I ran **no** T1 (briefed not to).
* That `xschem`'s action-log slot collision *actually* produces a wrong suite verdict: I
  measured the mechanism (non-atomic `stat`/`fopen`, all 10 slots full ⇒ deterministic
  `slot = oldest`) and that three T1 dcases read a log back; I did **not** run two concurrent
  display-arm suites to observe the wrong answer.

---

## Corrections to PLAN.md / DECISIONS.md / CLAUDE.md — loud

1. **`DECISIONS.md:129` is FALSE: *"The only single-slot object left was the name
   `tests/results.log`"*.** A full T1 writes **88** fixed-name files under `tests/`, **83** of
   which are verdict inputs. A collision on one of them produces a wrong answer **in both
   directions**, measured with the tree's own `banner_rule.tcl`. The design as written would
   ship "both runs proceed" while both runs score each other's per-case bodies.
   **The recommended shape is `.<pid>` on the per-case logs too** — the same fix B1 already
   applied one directory away, ~6 lines in `run_regression.tcl:571/574/620/669/691` plus
   `test_utility.tcl:281`.

2. **CLAUDE.md's "this ~7.8 GB box" and `DECISIONS.md:154`'s "this ~8 GB box" are wrong.**
   Measured `MemTotal 16091816 kB ≈ 15.35 GiB`. Roughly double. `DECISIONS.md:153-156` asks
   this recon to judge OOM risk against that figure, so the premise of the question was off by
   2×. Measured headroom during the pair: **5282 MB minimum available, 487 MB peak xschem RSS.**

3. **`DECISIONS.md:133-136`'s design does not close 1477 unless the channel is also fixed.**
   There is still **no `fconfigure` and no `flush`** in `run_regression.tcl` (measured: 0 hits).
   The trailer works regardless; the **header** does not, because it will sit unflushed in the
   4096-byte buffer. One line.

4. **Concurrency does not buy throughput here.** Two concurrent runs deliver both answers in
   **64.4 s** where back-to-back delivers them in **53.7 s** — measured, 20% worse. The case
   for "both proceed" is *agent ergonomics* (no crew is ever refused), not speed, and the
   write-up should say so rather than implying the box is being used better.

5. **`test_regression_concurrency_1476.tcl` row `V1b` was written to enforce the OLD R1** —
   it reds *"if C1 renames `results.log`"* (`A1.md:36`, suite `:100`). The driver's new R1
   keeps the canonical name, so V1b survives as written **only** if the canonical file is a
   real file at that path. If the implementation uses a symlink, V1b's intent needs re-reading.

6. **Minor, for the record:** `CREW_BRIEF.md:29-30`'s advice to "confirm its mtime moved" is
   correct today and becomes obsolete the moment the trailer lands. The two must be changed
   together or the next crew will apply a rule that no longer matches the file.

---

## Left dirty

**Nothing added to the repo.** `git status --porcelain` at the end is byte-identical to the
start:

```
?? .xschem/
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

(All four pre-date this task — they are in the session's opening git status.)

**Litter checked the way issue 1480 says to check it — `ls`, not `git status`:**
`ls untitled*.s*` and `ls tests/untitled*.s*` → **no such file** in either location.
No `tests/*/results.<pid>`, no `tests/*/.work.<pid>`, no `tests/results.<pid>.log`, no
`tests/results.log.lock`. `tests/headless/.scratch/` is empty.

**Regenerated (gitignored, pre-existing, and T1 rewrites them every run):**
`tests/open_close.log`, `tests/open_close/results/` (1898 files, now from my pair rather than
G1's run), `tests/open_close_output.txt` untouched (I did not run through `run_regression`).
`tests/results.log` is **byte-for-byte G1's** (4785 B, md5 `cb8b3911…`, mtime 1789642203).
`tests/results/.actionlogs/` untouched (still 10 files at 03:49-03:50).
`~/.xschem/` untouched (every mtime unchanged).

This receipt is the only file I created in the repo.

## Owed to the user

**Nothing new, and I did not touch `owed.sh`.** `DECISIONS.md:103-124` records that the user
returned R1/R2/R3 with *"you can't let me gate progress"*, so the two decisions this recon
surfaces — whether to `.<pid>` the 83 per-case logs, and whether to flush the verdict channel —
are internal harness engineering of exactly the kind the driver was told to decide. They are
recorded above as recommendations, not as rulings.

**One item for the driver, not the user:** CLAUDE.md's RAM figure is wrong by 2× and is quoted
in a bullet about OOM truncation. Correcting it is a one-word edit in a file the driver owns.
