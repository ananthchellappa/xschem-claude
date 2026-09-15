# Issue 1465 — Stage 12, event-driven results: a mixed-signal run's digital half

**PLAN.md §12, all of it, as one task.** Files touched, and nothing else:
`src/ase.tcl`, **`src/scheduler.c`, `src/vcd_read.c`, `src/xschem.h`** (the run end is C — see the
headline), `tests/headless/test_ase_events_1465.tcl` (new), `tests/run_regression.tcl` (`hcases`),
`doc/claude/issues/1465-a-mixed-signal-runs-digital-half-never-reached-the-window.md` (new),
`doc/claude/issues/NUMBERING.md`, `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md`,
`doc/claude/ase_analyses_batch/PLAN.md` (debt M13's row only),
`doc/claude/ase_analyses_batch/evidence/stage12-{after,noend}-apt.png` (new) and this receipt.

**No commit, no `git add`, no stash/restore/clean/push. `tests/run_regression.tcl` NOT run** (issue
0990 — the driver's, solo). **The binary was rebuilt with `make -C src`** after the C change, and
again after the sabotage campaign, so **T1 needs no rebuild**: `src/xschem` at hand-over is built
from the sources at hand-over (last `make` rc 0, every suite below measured on it). No simulation
on any bench under `sky130A/`; every run is a hand-written netlist in a suite scratch directory with
an explicit `rundir`, against an explicit binary path. Nothing under `~/.xschem/` was opened for
writing by anything this stage added (see *Hygiene* for the one pre-existing path a run takes).

---

## ⚠ THE HEADLINES

### 1. The digital half reaches the window — measured on both binaries, and in pixels

A real ASE-L run of the debt-M9 chain now exports `din`/`dout`, the viewer is handed the VCD beside
the raw, and **the digital strip reaches the analog run's end**:

| | apt 45.2 | fork |
|---|---|---|
| run rc (dc → tran → tf, all through `ase::run_deck`) | **0** (EE1) | **0** (EE1) |
| deck line | `eprvcd din dout > …/MixEvt_ase_evt.vcd`, after the transient's `write` (EE2) | same |
| VCD `$var`s | `din dout` (EE3) | same |
| the transfer function AFTER the export is in the results | yes — `dc tran tf` (EE4) | yes |
| `ase::last_vcdfiles` | the VCD (EE5) | same |
| attach: digital DB end == analog DB end; the file alone ends earlier | **yes / yes** (EE6) | yes / yes |
| beside a DC sweep the VCD keeps its own end | yes (EE10) | yes |
| `.probe alli` on the same chain | refused by the simulator's own answer, no deck (EE8); asked again, refused at the gate before anything is deleted (EE9) | same |

The screenshot pair, **one window, one run, one variable** (the run end), taken on `:99` with
`winshot.sh`: `evidence/stage12-after-apt.png` — `dout` goes to 1 at 26.3 ns and **holds it to
30 ns** — and `evidence/stage12-noend-apt.png`, the same window with the VCD re-read without a run
end, where `din` and `dout` both **stop at 26.3 ns**. The analog strip is pixel-identical in the two.
Databases at the moment of each shot: after, `slot1 vcd points=26 end=3e-08`; no end,
`points=25 end=2.6275e-08`; the analog slot `tran points=656 end=3e-08` in both.

### 2. ⚠ The run end is the READER's, and it is C — because the deck cannot write it

M9 left the route open. **Measured: the emission route is impossible.** A deck would have to write an
integer tick after `eprvcd`, and ngspice's `$&` prints a 30 ns end in fs as **`3E+07`** — with and
without `set numdgt=17` — on **both** binaries. `#3E+07` is not a VCD timestamp and six significant
figures cannot carry 26 274 999. So:

* **`xschem raw read <file> vcd -end <seconds>`** (`src/scheduler.c`, parsed as an option exactly like
  `-case`) sets a run end for **one** read; `vcd_read()` (`src/vcd_read.c`) extends the traces to it
  **only when it is later than the file's last timestamp by more than half a tick**; the value is
  reset on every path out. `src/xschem.h` gains `vcd_read_set_end()`.
* **`ase::attach_dbs`** passes the analog database's last scale value **when that database is a
  transient** — the only axis a VCD shares.
* Measured in C directly (rows AT1–AT7): no end → 25 points / 2.6275e-08; `-end 3e-08` → 26 / 3e-08;
  an earlier end, an unreadable end, and an end within half a tick of the last timestamp → unchanged;
  `-end` with no value → `xschem raw read: -end needs a time in seconds`; a later read that names no
  end is plain.

The VCD **file** on disk still ends at the last value change; the **database** spans the run.

### 3. ⚠ `eprvcd` AFTER A TRANSFER FUNCTION SEGFAULTS BOTH BINARIES

Found by sabotage **T13** (the export line after every analysis), whose mutated run made **EE1 red on
both binaries**. Then measured directly on the M9 chain:

| deck | apt 45.2 | fork |
|---|---|---|
| `dc vin 0 1 0.5` then `eprvcd din dout > dc.vcd` then `tran` | rc 0, VCD 225 bytes, tran runs | rc 0, 224 bytes |
| `tf v(aout) vin` then `eprvcd din dout > tf.vcd` | ⚠ **rc 139, SIGSEGV, VCD 0 bytes** | ⚠ **rc 139, the same** |

So *"only a transient carries the export line"* is not taste — a line after `tf` kills the run on the
binary users have. ⚠ **This measurement crashed `/usr/bin/ngspice` twice** (the T13 arm, then the
direct deck). It was not a deliberate crash probe — the event names were real event nodes, the known
abort trigger is an analog word — but it is the case CREW_BRIEF's apport warning is about; WSL files
no report here. I did not probe `eprvcd` after `op`/`ac`/`noise`/`pz`/`sp`/`pss` on 45.2 for that reason.

### 4. ⚠ My own sabotage restore left a stale binary, and the campaign's last row caught it

The first pass restored C files with **`cp -p`**. A preserved mtime is older than the object `make`
built from the MUTATED file, so `make` kept that object: **the C arms C2 and C3 ran with the previous
mutation still compiled in**, and the restored tree's binary still carried C5 and C3. Sources were
md5-identical the whole time. The runner's final row — *the suite on the restored tree must be a
positive `ALL PASS`* — came back **`3 FAILED` (AT2, EE6/apt, EE6/fork)** and that is how it was found.
Repaired: `touch` + `make` (the suite green at 87), the restore changed to plain `cp`, AT7 repaired
(below), and **the whole C arm re-run** — five of five killed by name, final restored tree `ALL PASS
(87)`. The first C arm's results are **discarded** and kept in the log for the record.

### 5. ⚠ The first cut split `run_cmd`, and three rows in other suites named it

The probe must start the run's program with the run's words. The first cut split them into a silent
`run_argv`. **`test_ase_simreg_0931` P6 and `test_ase_predeck_1439` CM5/CM6 reddened by name**: they
read `run_cmd`'s BODY for the router call `ase::predeck_argv ngspice $state` and for the word order.
The body was put back byte-for-byte in structure and `run_cmd` gained an optional **`quiet`** argument
that suppresses only its one stale-entry echo; the probe asks `run_cmd … 1` and drops the deck and
`2>@1`. Row **PD5** asserts the probe says nothing where `run_cmd` says it once.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

| claim | evidence |
|---|---|
| `edisplay` in a no-analysis deck lists event nodes, counts 0, rc 1 | **MEASURED HERE**, both binaries, byte-identical tables |
| `.probe alli` + digital → exit 1 with the message; + analog-only `gain` → rc 0 | **MEASURED HERE**, both; source `evtcheck_nodes.c` gates on `ckt->evt->info.node_list` |
| trtol reduced for an analog-only `a` card | **MEASURED HERE**, both (`Reducing trtol to 1 for xspice 'A' devices`) |
| `set xtrtol=7` → `Override trtol to 7 …` | **MEASURED HERE**, both |
| `eprvcd` 94 names → `limited to 93 arguments`, empty file, rc 0 | **MEASURED HERE**, both |
| `$&` → `3E+07`, `numdgt` inert for it | **MEASURED HERE**, both |
| name characters: `_ - + : # @ / .` survive, `$` substitutes, `% < > ' [ ]` parse-refused, `~ = ,` split | **MEASURED HERE**, both, through `eprint` (reports, never aborts) |
| `n:1` and a 33-character name round-trip through `edisplay`/`eprvcd` | **MEASURED HERE**, both |
| `x1.dint` hierarchical and `Mixed_Case` → `mixed_case` | **MEASURED HERE**, both (fork's default case mode folds) |
| §12.1 DC through auto-bridge fails; §12.2 bridge-first works | **MEASURED HERE**, both — new for 45.2 |
| `eprvcd` after `tf` → SIGSEGV; after `dc` → rc 0 | **MEASURED HERE**, both |
| an analog word on the `eprvcd` line aborts 45.2 | **TRANSCRIBED** from M9 / `binary-differences.md` #9 — deliberately NOT re-measured (it crashes the user's simulator) |
| 104 committed `.state` files round-trip | **MEASURED** through `ase_state_roundtrip`, twice, numbers below |
| the probe's wall-clock cost on a PDK bench | **NOT MEASURED** — stand-in and M9 chain only (milliseconds) |
| the dialog banner shows the cautions | **NOT MEASURED on a display** — it reads the same `ase::analysis_needs` over facts the gate donates; rows CA10/CA11 measure the gate's echo |

---

## What shipped

`git diff --numstat` at hand-over: `src/ase.tcl` **+626 / −6**, `src/vcd_read.c` **+32 / −2**,
`src/scheduler.c` **+24 / −3**, `src/xschem.h` **+4**, `tests/run_regression.tcl` **+8 / −1**; new
`tests/headless/test_ase_events_1465.tcl` **935 lines**. (PLAN.md §12 budgeted `src/ase.tcl` **≈ +120**
and no C — see C2.)

### Schema — `src/ase.tcl`, namespace `ase::`

| proc | what |
|---|---|
| `ase::event_vcd_path {state {i 1}}` | `<rundir>/<cell>_ase_evt.vcd`, then `_2`, `_3` … |
| `ase::event_vcd_max` | 1000 — the bound the adapter's chunking also stops at |
| `ase::event_vcd_files` / `ase::event_vcd_clear` | the files on disk, **contiguous** from the first; delete them |
| `ase::event_probe_path` | the throwaway probe deck, in the run directory, deleted when the answer is in |
| `ase::event_probe` | resolves the optional `event_probe` hook; `{}` with no hook — **no fallback** |
| `ase::event_inv_key` | program + arguments + stamp + deck text |
| `ase::event_nodes_peek` | the free peek — never starts a program |
| `ase::event_nodes` | the cold door; never raises; **an unmeasured answer is never cached**; cache bounded at 16 |
| `ase::event_nodes_known` | the nodes of a MEASURED answer, else `{}` |
| `ase::event_refusals` | `{<id> fatal <sentence> <fix>}` rows, **from the peek only** |
| `ase::event_facts` | facts + `evtinv` (the peek) for the precondition evaluator |
| `ase::last_vcdfiles` | appends the event VCDs **after** the co-simulation ones |
| `ase::attach_dbs` | the run end, for a transient |
| `ase::needs_eval` | new `xspice` arm: core evaluates, the adapter's `xspice_caveat` words it, no hook → nothing |
| `ase::preflight_gate` | merges the inventory into its facts before donating them; a new refusal block, **above the escape**, frame `ase: this circuit cannot run: …` |
| `ase::run_deck` | deletes stale event VCDs with its siblings; takes the inventory **immediately before render** (caught), names unexportable nodes |
| `ase::campaign_prepare` | takes the inventory before rendering the nominal deck |
| `ase::register_backend` | drops the inventory memo, below the five-hook loop (row A3's rule) |

### Content — `ase::backend::ngspice::`, three new hooks on `register_backend`

`event_probe` (the probe deck — netlist, includes, libraries, parameters, `pre_` commands, `edisplay`;
**nothing that writes**; only for a circuit with an `a` card; argv from `run_cmd … quiet`),
`event_inventory` (runs it via `ase::cap_run` in the run directory under `cap_budget_ms`),
`xspice_caveat` (the two cautions). Plus the adapter-internal `event_parse`, `event_exportable`,
`event_argmax` (93), `event_lines`, and `run_cmd`'s `quiet` argument. The registry's `tran` and `dc`
entries gain `xspice` in `needs`.

### Where the export line sits, and why each side

At the **end of each transient row's block**: **below the `$sim_status` guard** (a failed transient
`quit 1`s before it can export), **below `remzerovec` and the `write`** (M9 measured the rawfile
surviving a 45.2 abort on this line), and **below every anchor another issue pinned by position**
(1430, 1433, 1434, 0963, 0967, §7e) — appending there moves none of them. **Only after a transient**:
a digital pane is a picture over time, event history is the most recent analysis's, and after `tf` the
line segfaults (headline 3). EM3 pins guard < write < export < next analysis.

### The refusal's two tiers — and the cost of the second, stated

* **The gate** refuses a circuit an **earlier run** measured, before anything is deleted (RF5, EE9).
* **`render_deck`** refuses a circuit measured **for the first time by this run** — after
  `ase::run_deck`'s stale-artifact deletions, before the deck is written (RF6, EE8). ⚠ **Cost:** in
  that first case the previous run's raw is already gone. The inventory cannot be taken earlier
  without reading the previous run's `.spiceinit` (the pre-deck file is delivered after the gate), and
  a case mode spelt differently by the probe than by the run would put a non-event word on the export
  line. Precedent: a failed `cosim_build` throws from the same place.

---

## Suites — before → after, every arm, with rc

**Before** is the untouched tree and binary (`src/xschem` 2026-09-05, md5 `7f1d34ae…`), measured first.
**After** is the finished tree, rebuilt. Same command shapes as T1: headless
`./src/xschem --nogui --pipe -q --nolog --script`, display
`tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script`, each under `timeout`.

### Headless

| suite | before | after |
|---|---|---|
| **`test_ase_events_1465`** | — (new) | **ALL PASS (87), rc 0** |
| `test_ase_cosim` (RD1–RD11 inside) | ALL PASS (341), rc 0 | ALL PASS (341), rc 0 |
| `test_ase_core` | 638, rc 0 | 638, rc 0 |
| `test_ase_preflight` | 235 | 235 |
| `test_ase_persist` | 49 | 49 |
| `test_ase_window` | 56 | 56 |
| `test_backannotate_digital` | 84 | 84 |
| `test_op_annot` | 485 | 485 |
| `test_ase_simcaps_0948` | 211 | 211 |
| `test_ase_simreg_0931` | 117 | 117 |
| `test_ase_campaign_1462` | 133 | 133 |
| `test_ase_effective_1442` | 92 | 92 |
| `test_ase_converge_1459` | 76 | 76 |
| `test_vcd_read` | 156 | 156 |
| `test_raw_read_dispatch` | 137 | 137 |
| `test_raw_case_mode` | 277 | 277 |
| `test_vcd_time_base` | 112 | 112 |
| `test_raw_read_failure_0306` | 63 | 63 |
| `test_ase_current_repair` | 51 | 51 |
| `test_results_select` | 377 | 377 |
| `test_ngspice_data_view` | 139 | 139 |
| `test_node_token_split` | 174 | 174 |
| `test_ase_dialogs` | 37 | 37 |
| `test_ase_meas_1443` | 113 | 113 |
| `test_ase_sp_1452` | 58 | 58 |
| `test_ase_optier_0963` | 109 | 109 |
| `test_ase_predeck_1439` | 78 | 78 |
| `test_ase_options_1437` | 75 | 75 |
| `test_ase_optsheet_1441` | 62 | 62 |
| `test_cosim_golden_e2e` | ⚠ **1 FAILED (45), rc 1** — GE24 | ⚠ **1 FAILED (45), rc 1** — GE24, **FAIL line byte-identical** |

Every one of those except the last is rc 0. **GE24 is issue 1431** (a one-nanosecond-stale golden,
filed, deliberately not re-baselined, not in T1).

### Dev display (`:99`, openbox live)

| suite | before | after |
|---|---|---|
| `test_ase_window` (W1m inside) | ALL PASS (295), rc 0 | ALL PASS (295), rc 0 |
| `test_ase_persist` | 153 | 153 |
| `test_op_annot` | 492 | 492 |
| `test_annot_show_menu` | 36 | 36 |
| `test_wave_crossdb_trace` | 130 | 130 |
| `test_wave_cursor_crossdb` | 93 | 93 |
| `test_wave_sigbrowser_digital` | 82 | 82 |
| `test_wave_casemode` | 134 | 134 |
| `test_ase_cosim` | 341 | 341 |
| `test_ase_campaign_gui_1464` | 156 | 156 |
| `test_ase_conv_gui_1460` | 104 | 104 |
| `test_ase_simdlg_0937` | 55 | 55 |
| `test_ase_optsheet_1441` | 87 | 87 |
| **`test_ase_events_1465`** | — | **ALL PASS (87), rc 0** (T1 runs it headless only) |

All rc 0. **W1m did not move** — no menu entry was added.

### Per binary

Section **EE** of the new suite runs the real chain on **`/usr/bin/ngspice` (45.2)** and on
**`/home/analog/dev/ngspice/build-ver_50/src/ngspice` (the fork)**, ten rows each, all twenty green
(`EE1/apt` … `EE10/fork`). Every direct ngspice measurement in this receipt was taken on both. The
other suites that start simulators (`campaign_1462`, `converge_1459`, `optier_0963`) carry their own
two-binary sections and were unmoved.

### Reds met on the way, and whose they were

| red | whose | outcome |
|---|---|---|
| `test_ase_core` **C11** *no untitled~.sch in the repo root* | ⚠ **not mine** — the `untitled~.sch` read by my first after-run was left by the BASELINE run's `test_node_token_split` (its body names `.scratch/_ndtok_<pid>/`; mtime equals that suite's log end). Issue **0609**'s class | the file moved to scratch evidence, C11 green on rerun. ⚠ **It happens on EVERY `test_node_token_split` run** — my final stream left another (`_ndtok_67482`), also moved out. T1 does not run that suite, so T1 only sees it when a crew's run leaves one. **The root is clean at hand-over** |
| `test_ase_simreg_0931` **P6**, `test_ase_predeck_1439` **CM5/CM6** | **mine** — headline 5 | repaired; 117 / 78 |
| suite rows IP7, PD2, EM3, EE4 (first run) and PD5 (first cut) | **mine, in the suite** — a braced dict value, an off-by-one strip, an `op` assumed to sort after `tran` (it sorts first; `tf` sorts at 50), and a stand-in renamed out of `ase::` (losing its `variable` bindings) | repaired before the campaign |

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`** (`ase_state_roundtrip`), measured after the code
landed and again on the finished tree:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No state key was added; `ase::omit_if_empty` untouched.

---

## THE SABOTAGE CAMPAIGN — 45 mutations, 45 killed by name, 0 restore mismatches

One runner at a time (`ps` checked before each launch). **The green gate is a positive assertion**
(`RESULT: ALL PASS (`) and was **fed the empty case and a failing result first** — both refused. Every
mutation: exact-anchor check (a miss is named), apply, `make` for C, the suite headless under
`timeout`, reds by row name, restore by `cp` with md5 printed, `make` again for C, and a pristine check
of every file before the next. Final row: the suite on the restored tree.

**Rows added BEFORE the campaign, from reading the mutation list and finding nothing it could kill**
(the brief's *your first list will be short*): **CA11** (the gate merges the measurement), **LV7** (the
run door deletes stale VCDs), **UN1** (the unexportable warning), **EM9** (campaign_prepare warms),
**CI9** (re-registration drops the memo), **AT7** (the half-tick slack), **EE10** (a non-transient
attach is not stretched), **PD5** (the probe is silent). And three strengthened: **AT6** (a plain
`raw read` sets its own end, so only the OTHER verb can see a missing reset), **EE10** moved from beside
the operating point to beside a **DC sweep** (an OP's first variable can be 0, so a stretch-everything
mutation could hide there; a sweep ends at 1), and **AT7** (below).

| # | what I broke | result | rows that reddened |
|---|---|---|---|
| T1 | `last_vcdfiles` stops serving the event VCDs | 5 FAILED | LV3 LV4 LV5 EE5/apt EE5/fork |
| T2 | `event_vcd_files` skips a gap | 1 FAILED | LV4 |
| T3 | every chunk gets the same path | 8 FAILED | EM5 LV1 LV3 LV4 LV5 LV6 EE5/apt EE5/fork |
| T4 | an unmeasured inventory is cached | 1 FAILED | CI6 |
| T5 | the inventory is never cached | 30 FAILED | CI3 CI4 CI9 EM2–EM6 EM8 EM9 CA11 RF2 RF3 RF5 RF5b RF6 EE2/3/5/6/8/9/10 on both |
| T6 | the probe deck is left behind | 3 FAILED | CI7 EE7/apt EE7/fork |
| T7 | the peek starts a program | 8 FAILED | CI1 CI5 CI6 CI9 EM1 CA11 RF1 RF6 |
| T8 | the cache key ignores the deck | 11 FAILED | CI5 CI6 EM5 EM6 EM7 EM8 RF4 EE8/apt EE9/apt EE8/fork EE9/fork |
| T9 | `event_refusals` ignores the refusal | 10 FAILED | EM8 RF2 RF3 RF5 RF5b RF6 EE8/apt EE9/apt EE8/fork EE9/fork |
| T10 | the gate's refusal block reads nothing | 4 FAILED | RF3 RF5 EE9/apt EE9/fork |
| T11 | `render_deck`'s refusal tier reads nothing | 6 FAILED | EM8 RF6 EE8/apt EE9/apt EE8/fork EE9/fork |
| T12 | the export line is never emitted | 16 FAILED | EM2–EM6 EM9 EE2/3/5/6/10 on both |
| T13 | the export follows EVERY analysis | 14 FAILED | EM2 EM4 EM5 EM6 **EE1/apt EE1/fork** EE2/3/6/10 on both — ⚠ headline 3 |
| T14 | the export sits right after the analysis line, above guard and write | 3 FAILED | EM3 EE2/apt EE2/fork |
| T15 | the gate does not merge the inventory | 1 FAILED | CA11 |
| T16 | a hookless backend gets fallback content | 1 FAILED | CA9 |
| T17 | `tran` loses the `xspice` precondition | 4 FAILED | CA1 CA2 CA7 CA10 |
| T18 | `dc` loses it | 4 FAILED | CA1 CA4 CA6 CA11 |
| T19 | trtol caution needs event nodes, not any `a` card | 2 FAILED | CA2 CA10 |
| T20 | DC caution fires on a measured "none" | 2 FAILED | CA5 CA11 |
| T21 | DC caution ignores measured nodes without an `a` card in the text | 3 FAILED | CA5 CA6 CA11 |
| T22 | the parser stops a name at its first colon | 1 FAILED | IP2 |
| T23 | "No event node available!" read as unknown | 2 FAILED | IP3 CA11 |
| T24 | an empty answer read as "no event nodes" | 3 FAILED | IP5 IP6 CI6 |
| T25 | the parser ignores the `.probe alli` refusal | 12 FAILED | IP4 IP4b EM8 RF2 RF3 RF5 RF5b RF6 EE8/apt EE9/apt EE8/fork EE9/fork |
| T26 | `$` is exportable | 4 FAILED | IP7 IP8 EM6 UN1 |
| T27 | the export takes 94 names | 1 FAILED | EM5 |
| T28 | a circuit with no `a` card is probed | 1 FAILED | PD1 |
| T29 | the probe deck drops the includes | 1 FAILED | PD2 |
| T30 | the probe starts a hard-coded `ngspice -b` | 16 FAILED | PD3 CI2 CI3 CI6 CI8 EM5–EM8 CA11 RF2 RF3 RF5 RF5b RF6 UN1 |
| T31 | the probe deck runs an analysis | 1 FAILED | PD2 |
| T32 | the probe runs outside the run directory | 1 FAILED | CI8 |
| T33 | `run_cmd` echoes even when quiet | 1 FAILED | PD5 |
| T34 | `run_deck` only peeks, never asks | 16 FAILED | RF6 UN1 EE2/3/5/6/8/9/10 on both |
| T35 | `run_deck` does not delete stale VCDs | 1 FAILED | LV7 |
| T36 | `campaign_prepare` does not ask | 1 FAILED | EM9 |
| T37 | re-registration keeps the old inventory | 1 FAILED | CI9 |
| T38 | `attach_dbs` passes no run end | 2 FAILED | EE6/apt EE6/fork |
| T39 | `attach_dbs` passes a run end beside ANY database | 2 FAILED | EE10/apt EE10/fork |
| T40 | an unexportable name is not listed | 2 FAILED | IP7 UN1 |
| C1 | `vcd_read` ignores the run end | 3 FAILED | AT2 EE6/apt EE6/fork |
| C2 | `raw read` never resets the run end | 1 FAILED | **AT6** |
| C3 | the extension has no half-tick slack | 1 FAILED | **AT7** |
| C4 | `-end` is not an option | 4 FAILED | AT2 AT5 EE6/apt EE6/fork |
| C5 | the parsed end never reaches the reader | 3 FAILED | AT2 EE6/apt EE6/fork |
| final | the restored tree | **ALL PASS (87)** | — |

C1–C5 are the **second** C arm (headline 4). ⚠ **In the discarded first arm C3 reddened AT6 and not
AT7**, which is how AT7's own weakness showed: its end was written as exactly the last timestamp,
which divides by the timescale to a float a ulp either side of the tick and cannot tell a half-tick
slack from none. AT7 now uses an end **0.4 fs** past the tick, and the second arm's C3 reds it.

Logs: `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/sab/results.txt` (both passes, the discarded C arm
included), `…/sab/logs/<id>.log` per mutation, `runner.out`, `runner_c.out`.

---

## Debts filed — queue before → after

Backed up first: `…/scratchpad/owed_backup_091403` (`cp -a ~/.claude/xschem_owed`).

| | rule | look | suite |
|---|---|---|---|
| **before** | 177 | 67 | 11 |
| **after** | **178** | **68** | **11** |

* **`add rule 1465`** — recorded. `R9_COPY_REVIEW.md` **R9-557 … R9-564**, header 556 → **564
  strings from 30 issues**. Every string is byte-present in `src/ase.tcl`.
* **`add look ase-digital-pane-run-end-1465`** — recorded. ⚠ **PLAN.md §12 says this stage files no
  look debt "because no new pane is built". That half is stale**: no pane is built, but an existing
  pane's DRAWING changes — measured, the screenshot pair differs exactly in the digital strip's last
  3.7 ns — and M9's own finding is that only the pixels showed the defect. **Suites green on both arms —
  please look.** ⚠ `:99` is Xvfb; the user's real screen is `AUDIT_DISPLAY=$DISPLAY`.
* **No `suite` debt**: the new suite maps no window and is headless in T1.

### ⚖ R9 — the new sentences

```
this circuit has XSPICE devices, so the simulator lowers trtol to 1 and takes smaller time steps than the options ask for
add `set xtrtol=<n>` to this analysis's verbatim lines to choose the value yourself
a DC sweep does not always reach digital nodes through the bridges the simulator inserts on its own
write the bridge devices into the netlist yourself, ahead of the digital devices
this circuit has digital nodes, and with `.probe alli` the simulator exits before it simulates anything
remove `.probe alli` from the netlist
ase: this circuit cannot run: <sentence>
ase: left out of the VCD, because the export command cannot take these digital node names: <names>
```

The two cautions reach the user through the existing precheck frame, `ase: the <type> analysis:
<sentence>. Fix: <fix>`. ⚠ R9-559's DC caution is **permanent until M13 closes**.

---

## Corrections — to PLAN.md, the CREW_BRIEF, the ledger and the driver's M9 evidence

| | |
|---|---|
| **C1** | ⚠ **PLAN.md §12: "`trtol` is silently forced to 1 whenever event nodes exist" is too narrow.** It is forced for **any** XSPICE `a` card (`CKTadevFlag`) — an analog-only `gain` block prints the same line, on both binaries. The caution fires on an `a` card, and on measured event nodes |
| **C2** | ⚠ **PLAN.md §12: "one emitted line and one list append" (≈ +120) is the wrong size by 5× and misses a language.** Measured need: an inventory taken by a probe run with the run's own words and cached; groups of 93; a name filter (45.2's abort); a reader-side run end in **C**; two refusal tiers. `src/ase.tcl` +626, plus C |
| **C3** | ⚠ **PLAN.md §12 *Files and procs*: "`src/ase_window.tcl` — none", "`src/ase.tcl` — ≈ +120"** omits `src/scheduler.c`, `src/vcd_read.c`, `src/xschem.h`. `ase_window.tcl` was indeed untouched |
| **C4** | **PLAN.md §12: "`ase::event_nodes` (parses `edisplay`)"** puts a simulator word in core. Shipped split: core `ase::event_nodes` is the cache and the door; parsing is the adapter's `event_parse` (D34) |
| **C5** | ⚠ **PLAN.md §12 *Re-measure on the dev display*: "no new look debt is filed"** — stale, see *Debts*. The rule that binds: **a change to what an existing pane draws is a pixel deliverable**, pane or no pane |
| **C6** | **The driver's M9 evidence, finding 1: "neither route was measured"** — now measured: the **emission** route cannot be built (`$&` → `3E+07`, `numdgt` inert, both binaries); the reader route shipped. ⚠ **I found nothing in the M9 evidence that is wrong.** Re-confirmed here on both binaries: the `edisplay` table, the absence of `din`/`dout` from `write … all`, the VCD's last tick `#26275000` on 45.2, the attach `n 2` with `time din dout`. Not re-measured: the analog-argument abort (deliberately) and the 1012-pixel fork/apt screenshot difference |
| **C7** | ⚠ **The M9 evidence's rule 2 "emit `eprvcd` after `write`" needs a rule 4: only after a TRANSIENT.** After `tf` it segfaults both binaries (headline 3); after `dc` it runs. `evidence/xspice.md` §12.6 ("`tf` and `disto` run silently") is true of the analyses and silent about the export that follows |
| **C8** | ⚠ **CREW_BRIEF, testing discipline: a C sabotage restore must not preserve the mtime.** `cp -p` from a snapshot leaves `make` keeping the mutated object; the next arm runs against a stale binary with md5-perfect sources. The brief's *No harness builds* paragraph describes this trap from the git-stash side; this is the same trap from the sabotage side, and **the only thing that caught it was a positive final row on the restored tree** — every crew touching C should carry one |
| **C9** | **CREW_BRIEF / any stage touching `run_cmd`: rows `test_ase_simreg_0931` P6 and `test_ase_predeck_1439` CM5/CM6 read `run_cmd`'s BODY** for the router call and word order. A refactor that moves those lines out reds all three. They are in no stage's *Suites that move* list |
| **C10** | ⚠ **`test_node_token_split` leaves `untitled~.sch` in the repo root on every run**, and `test_ase_core` **C11** (a T1 case) then reds for whatever runs next — including a crew's baseline and the driver's T1 after a crew's campaign. Issue 0609 names the class; nothing names this suite. Not filed as a new issue (not this stage's, and 0609 covers the mechanism) — the driver may want a pointer |
| **C11** | **Debt M13 (PLAN.md "still open" row, annotated in place)**: §12.1's failure and §12.2's remedy reproduce on **apt 45.2** exactly as on the fork. Root cause not chased |

---

## What Stage 12 learned that binds later stages

1. **An `eprvcd` line belongs directly after a transient and nowhere else.** Stage 13's transient
   noise is a transient — fine. **Stage 14's `pss` is unmeasured** and must not carry the line until
   someone measures it on the fork first (a crash there is harmless; on 45.2 it is apport's case).
2. **A question only the simulator can answer is asked of the simulator, with the run's own words, in
   the run's own directory, once per distinct circuit** — and read from a peek everywhere else. The
   pattern is `ase::event_nodes` / `ase::event_nodes_peek`; reuse it rather than parsing a netlist.
3. **A deck cannot compute an integer above six significant figures** (`$&` and the `set` route both
   round). Any number a deck would have to print exactly belongs in Tcl or C.
4. **`xschem raw read <vcd> vcd -end <s>` exists now**; any future VCD producer attached beside a
   transient reaches the run's end with no further work.
5. **A refusal read from the simulator has two tiers**, and the second costs the previous run's
   deleted artifacts on a first measurement. Say so when copying it.
6. **Structural rows pin `run_cmd`'s body** (C9); **C sabotage restores without `-p`, and ends on a
   positive restored-tree row** (C8).

## Declared limits (also in the issue file)

* An `a` card that lives only inside an `.include` is not seen by the gate that decides whether to ask
  — that circuit's digital half stays unexported, as before this stage.
* An included file edited in place keeps its path and so its cached inventory, until the netlist or the
  binary changes.
* The probe is synchronous: one extra read of the circuit per distinct circuit, before a mixed bench's
  first run. A campaign whose axes change `.param` values asks once per shard.
* Two enabled transients export to one file; the second's history wins.
* A session with `cosim attach 0` suppresses the event VCDs too (`ase::last_vcdfiles`' existing early
  return).
* The first-measurement refusal comes after the stale-artifact deletions (see *two tiers*).

## Hygiene

* **One sabotage runner at a time**, confirmed with `ps`; no `pkill`, no `pgrep -f` kill; every suite
  command under `timeout`, every wait with a deadline that reports progress and runner liveness.
* **Nothing under `~/.xschem/` was written by anything this stage added.** The probe deck lives in the
  suite's scratch run directory and is deleted (CI7, EE7). ⚠ The rows that go through `ase::run_deck`
  (RF5, RF6, LV7, UN1, EE1–EE9) also pass through the **pre-existing** `ase::cap_report`, whose probe
  folder is `set_netlist_dir 0`/`.ase_probe` — created and removed per run, exactly as every T1 suite
  that runs a deck already does. The simulator registry was isolated (`test_sim_registry_isolate`,
  autosave off).
* **Snapshots disarmed**: the pre-change copies and the post-change pristine set, **and the runner
  script**, are under `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/` (`pre_change_pristine/`,
  `sab/pristine_post/`, `sab/sab.py`). Logs kept beside them.
* **Repo root clean at hand-over** (`untitled~.sch` absent; both leftovers kept at
  `…/scratchpad/evidence/`). No background process of this crew is running.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
