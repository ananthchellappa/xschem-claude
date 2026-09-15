# Issue 1468 — the point estimate reads a whole number of any size

**Issue `doc/claude/issues/1468-the-gigabytes-caution-goes-silent-at-four-billion-points.md`**, handed
to this crew by the driver as one task. Files touched, and nothing else: `src/ase.tcl` (**+19 / −1**),
`tests/headless/test_ase_effective_1442.tcl` (**+73**), `tests/headless/test_ase_trnoise_1466.tcl`
(**+52**), the issue file (**+66 / −2**, status → FIXED) and this receipt.

md5 at hand-over: `src/ase.tcl` `cfae0e2f…` (was `250d949b…`), `src/ase_window.tcl` `cd552daa…`
**unchanged**, `test_ase_effective_1442` `299fd287…` (was `a417338e…`), `test_ase_trnoise_1466`
`8fa2e42c…` (was `ef521e22…`).

**No commit, no `git add`, no stash/restore/clean/push. `tests/run_regression.tcl` NOT run and not
edited** — both suites are already where T1 finds them. **No C**: `make -q -C src` rc 0 before and
after, `src/xschem` md5 `96fc4899…`. **No simulation** is started by any row this task adds, and none
on any bench under `sky130A/`. **No issue minted**, `NUMBERING.md` untouched. **No new user-facing
sentence**: the one added non-comment line in `src/ase.tcl` is
`if {![string is entier -strict $n]} { return {} }` (`git diff -U0 src/ase.tcl | grep '^+' | grep -v
'^+ *#'`), so no `owed.sh add rule` and no `R9_COPY_REVIEW.md` entry.

---

## ⚠ THE HEADLINES

### 1. One word: `string is entier -strict`, and why it is that word and not the other two

`ase::analysis_point_estimate` now accepts the hook's answer through `string is entier -strict`. Measured
on this tree's Tcl, **8.6.17**, over 36 spellings (whitespace, signs, `0x`/`0o`/`0b`, `08`, `1e3`, `1.`,
`.5`, `5e9`, `5000000000.0`, `Inf`, `NaN`, `1_0`, words, the empty string, and the boundaries on both
sides): **every string `integer` accepts, `entier` accepts, and the only strings `entier` adds are whole
numbers of magnitude 2³² or more.** So the range widens and the type does not.

| candidate | what it does here | sabotage |
|---|---|---|
| `integer` (the shipped test) | 1 for 4294967295, **0 for 4294967296** | S01 reds RU12 RU13 NX6 NK22 |
| `wideinteger` | 1 up to 18446744073709551615, **0 from 2⁶⁴** — moves the silence, does not remove it | S02 reds RU13 |
| `double` (the issue's third candidate, "as the planner does") | accepts `5e9`, `5000000000.0`, `3.5` — **loosens the type** | S03 reds RU13 |
| **`entier`** | every whole number, nothing else | — |

The readers do all their arithmetic on the answer in `expr` — `$n <= 99999999`, `$k > $n`,
`entier($points) * …` — and `expr` is exact on an integer of any size, so nothing downstream needed to
change.

### 2. Each of the three readers has its own row above 2³², and each row is specific to its reader

| reader | row | on the pre-change tree | on the fixed tree |
|---|---|---|---|
| §7g `points_max` | **RU12** `test_ase_effective_1442` | `1n 4.294967295` warns; `1n 4.294967296`, `1n 5`, `1f 10` → **none** | all four `caution`, quoting `about 4294967296` / `5000000000` / `10000000000000000 points` |
| `ase::stimuli_points` (the Tran form's `≈ N points`) | **NX6** `test_ase_trnoise_1466` | 5e9 card: `{}` with no table, **25000000** (800 MB) under noise asking 2.5e7 | **5000000000** both, bytes 160000000000; noise asking 2.5e16 unchanged either way |
| the adapter's noise check | **NK22** `test_ase_trnoise_1466` | 5e9 card under noise asking 2e8: the noise caution fires quoting **2e+08** and advising a larger NOISE timestep; `points_max` **none** | no noise caution; `points_max` `caution` — exactly as the 3e9 control |
| the estimator itself | **RU13** `test_ase_effective_1442` | 2³², 5e9, 2⁶⁴, −5e9 → `{}` | all four returned verbatim; `5e9`, `5000000000.0`, `3.5`, `abc`, `{}` → `{}`; the old test as oracle finds no difference under 2³² |

**Specificity, measured**: re-binding the old test inside ONE reader reds that reader's row and no other
— S05 (points_max) → RU12 + NK22 (NK22 reads `points_max`'s tier), S06 (`stimuli_points`) → NX6 alone,
S07 (the noise check) → NK22 alone.

### 3. Receipt 43's M10 now reds NK20

Re-run verbatim on the fixed tree (S08), task 1's S44 — the salvage hook made noise-aware — reds
**NK20** NX2 NX6 NP1 NP2 NP5. Receipt 43 C3 recorded that NK20's 1e13-point fixture slipped past M10
because the estimate was dropped as `{}`; with the range fixed the noise-aware hook's 1e13 reaches the
noise check as its base, the caution goes silent, and NK20 says so.

### 4. ⚠ The survey changed nothing else — the issue's premise about rawfiles is wrong for this tree

Per site, in *Survey* below. The short version: **only `ase::analysis_point_estimate` reads a count that
can reach 2³².** The rawfile header counts the issue named are bounded at **2³¹−1** by both the writer
and xschem's own reader, and `~:15293` is not a count at all.

### 5. ⚠ FOUND, NOT FIXED, FOR THE DRIVER — the same defect one boundary up, in the adapter's hook

`ase::backend::ngspice::tran_points` ends `int(double($nstop - $nstart) / $nstep + 0.5)`, and Tcl 8.6's
`int()` keeps the low 64 bits. Measured through the real hook: **`tran 1a 10` → −8446744073709551616**
(no caution even with this fix, and `ase::ckpt_plan` → `{}`), **`tran 1a 100000` → 200376420512301056**
for 1e23 points (a caution quoting the wrong count, and a checkpoint plan on it). `entier()` does not
wrap, but `ase::ckpt_plan` would then feed that bignum to its own `int()` and `wide()`, which wrap — so
fixing the hook means touching the planner this task was told to leave unchanged. Not minted; named here
and in the issue file.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15, `HOME` → `…/i1468/home`, every command under `timeout`.

| claim | evidence |
|---|---|
| `integer -strict` 1 at 4294967295, 0 at 4294967296 and at −4294967296; `wideinteger` 0 from 2⁶⁴; `entier` ⊇ `integer`, adding only \|v\| ≥ 2³² | **MEASURED HERE** (`tclsh` 8.6.17, 19 + 36 spellings) |
| the three readers silent/wrong from exactly 4294967296 on the pre-change tree; `ckpt_plan` arms at 5e9 and 1e16 regardless | **MEASURED HERE** (`meas/p1.pre.log`, through `./src/xschem --nogui`) |
| `tran_points` wraps at 1e19 and 1e23 (headline 5) | **MEASURED HERE** (`meas/p1.pre.log`) |
| `ase::campaign_seed` → `{}` for 5000000000, `4294967295` for 4294967295 | **MEASURED HERE** (`meas/p1.pre.log`) |
| ngspice `write` prints `No. Points: %d` from `int length`; `v_length` is `int`; the `-r` writer back-fills with `%d` | **READ HERE** in `/home/analog/dev/ngspice` (`src/frontend/rawfile.c`, `src/include/ngspice/dvec.h`, `src/frontend/outitf.c`) — source, not a run |
| xschem's reader scans `No. Points: %d` into `int *npoints`; `xschem raw points` returns it through `my_itoa` | **READ HERE** (`src/save.c` `read_dataset`, `src/xschem.h`, `src/scheduler.c`) |
| the boundary table in the issue file | **TRANSCRIBED** from the driver, and every row re-measured above |

---

## What shipped

### `src/ase.tcl`

| proc | change |
|---|---|
| `ase::analysis_point_estimate` | `string is integer -strict` → `string is entier -strict`, under a comment carrying the boundary, the three readers, why not `wideinteger`, and the rows that pin it |

Nothing else. `ase::ckpt_plan`, `ase::stimuli_points`, `ase::stimuli_raise_points`, `ase::noise_points`,
the `points_max` evaluator and the ngspice adapter's `noise_check` are byte-for-byte what they were.

### `tests/headless/test_ase_effective_1442.tcl` — 92 → 94, floor raised with a new *THE HISTORY* paragraph

The file had no numeric history; it now has one, starting from the measured 92 at `02288c30`.

| row | what it pins |
|---|---|
| **RU12** | `tran 1n 4.294967295` (control), `1n 4.294967296`, `1n 5`, `1f 10` each give `points_max` `caution` and a sentence quoting the whole count |
| **RU13** | a fixture backend (`zz1468`, ngspice's own `tran` entry with the salvage points hook swapped for one returning the row's `ans`, registry restored after each call): whole numbers of any size and sign returned verbatim; float spellings, a fraction, a word and `{}` → `{}`; over 11 spellings under 2³² the estimator answers exactly what `string is integer -strict` answers |

### `tests/headless/test_ase_trnoise_1466.tcl` — 76 → 78, floor raised with the file's own paragraph

| row | what it pins |
|---|---|
| **NX6** | `ase::stimuli_points` at 4294967295 / 4294967296 / a 5e9 card with no table / under noise asking fewer points; the readout's `points` and `bytes`; noise asking more than the card (2.5e16) unchanged |
| **NK22** | the noise check's gigabytes caution silent and `points_max` `caution` for a 3e9 card and a 5e9 card, both under noise asking 2e8 |

---

## Suites — before → after, every arm, with rc

**Before** = the untouched tree at `02288c30` (`…/i1468/logs/base/`). **After** = the fixed tree
(`…/logs/after/`). **Final** = the restored tree after the campaign, on the hand-over bytes
(`…/logs/final2/`). Headless `./src/xschem --nogui --pipe -q --nolog --script`; display
`tests/headless/devdisplay.sh exec timeout --kill-after=20 900 ./src/xschem --pipe -q --nolog --script`
on `:99` (openbox). Every run `HOME=…/i1468/home`, `XSCHEM_DEVDISPLAY_DIR` the real state dir,
`GUI_GATE=0`, each command under `timeout --kill-after=20 900`.

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_effective_1442`** | 92, rc 0 | **ALL PASS (94), rc 0** | 92, rc 0 | **ALL PASS (94), rc 0** |
| **`test_ase_trnoise_1466`** | 76, rc 0 | **ALL PASS (78), rc 0** | 76, rc 0 | **ALL PASS (78), rc 0** |
| `test_ase_trnoise_gui_1467` | 19, rc 0 | 19, rc 0 | 63, rc 0 | 63, rc 0 |
| `test_ase_preflight` | 235, rc 0 | 235, rc 0 | 235, rc 0 | 235, rc 0 |
| `test_ase_persist` | 49, rc 0 | 49, rc 0 | 153, rc 0 | 153, rc 0 |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |

Every cell is `ALL PASS (<n> checks)`. **Final** (restored tree, hand-over bytes): `test_ase_effective_1442`
94 / 94 and `test_ase_trnoise_1466` 78 / 78, rc 0 on both arms.

**Not a count diff — a name diff.** For all 12 logs, the sorted `ok:`/`FAIL:` + row-id list after
versus before: the four neighbours' eight logs are **identical**; the two touched suites differ by
exactly `> ok: RU12`, `> ok: RU13` (both arms) and `> ok: NK22`, `> ok: NX6` (both arms). No existing
row moved.

**Without the fix, first**: the new rows were written and run against the **unchanged** `src/ase.tcl`
before the fix was applied — `test_ase_effective_1442` `2 FAILED (92 passed)` {RU12 RU13},
`test_ase_trnoise_1466` `2 FAILED (76 passed)` {NK22 NX6}, every original row green (`logs/m00/`).

### Per binary

The four new rows are pure Tcl and **start no simulator**, so there is nothing to test twice. The
suite's existing sections EE and EC ran `/usr/bin/ngspice` 45.2 and the fork on both arms in every
before, after and final run, **0 `SKIPPED` lines** in any of them.

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`**, inside the suite (row NC1), on the after and final
trees, both arms:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No state key added; `ase::omit_if_empty` untouched.

---

## THE SABOTAGE CAMPAIGN — 9 arms, 9 killed by name, 0 restore mismatches

`sab.py` started after the after-runner printed `RUNNER DONE` and no `xschem` process was alive
(matched by `comm`). **The gate is a positive assertion and was fed the empty case first**:
`GATE CONTROLS empty=NORESULT partial=NORESULT pass=SURVIVED fail=KILLED`. Each arm checks an exact
anchor count of 1, writes the mutated bytes, runs both suites headless under `timeout 300` with
`ASE_NZ_NGSPICE=/nonexistent/ngspice` (so **no simulator runs in the campaign**; EE/EC print their
`SKIPPED` lines and `test_ase_trnoise_1466` counts 58), reads reds by row name, then restores by plain
write and md5-checks before the next arm. Tcl only, nothing to build.

| # | what I broke | reds |
|---|---|---|
| **S00** | **the whole pre-change `src/ase.tcl`** | RU12 RU13 · NK22 NX6 |
| **S01** | **`string is integer -strict` put back** | RU12 RU13 · NK22 NX6 |
| S02 | `wideinteger` instead of `entier` | RU13 |
| S03 | `double` instead of `entier` (type loosened) | RU13 |
| S04 | the type test deleted | RU13 |
| S05 | reader 1 alone: `points_max` re-drops an estimate from 2³² | RU12 · NK22 |
| S06 | reader 2 alone: `stimuli_points` re-drops its base from 2³² | NX6 |
| S07 | reader 3 alone: the noise check re-drops its base from 2³² | NK22 |
| S08 | receipt 43's M10 verbatim (salvage hook made noise-aware) | NK20 NX2 NX6 NP1 NP2 NP5 |
| **final** | **the restored tree**, md5 `cfae0e2f…` | **both suites ALL PASS on both arms, simulators live, 0 SKIPPED** |

**Every new row reddened under at least one arm:** RU12 (S00 S01 S05), RU13 (S00 S01 S02 S03 S04), NX6
(S00 S01 S06 S08), NK22 (S00 S01 S05 S07).

Logs: `…/i1468/sab/results.txt`, `…/i1468/sab/logs/<arm>.<suite>.h.log`.

---

## Survey — every other `string is integer` in `src/ase.tcl`

**None changed.** The rule applied: fix it if the value is a count that can reach 2³².

| site (proc, line hint) | reads | why not changed |
|---|---|---|
| `ase::cap_raw_plots` (~`:2804`, `:2810`) | `No. Variables:` / `No. Points:` | ⚠ **bounded at 2³¹−1.** ngspice's `write` prints `No. Points: %d` from `int length`, fed by `int v_length`; the `-r` writer back-fills with `%d`. xschem's C reader scans `%d` into `int *npoints`. No file this tree writes or loads carries more |
| `ase::raw_scalars` (~`:2946`, `:2952`) | the same two headers | the same; and it only keeps a plot with `np == 1` |
| `ase::raw_content_verdict` (~`:17605`, `:17613`, **`:17614`**, `:17650`) | `nv`, `np` from the header | the same. **These are the issue's `:17587`/`:17595`/`:17596`**, 18 lines lower after this change |
| `ase::attach_dbs` (~`:17740`) | `xschem raw points` | a C `int` returned through `my_itoa` |
| `ase::with_design_current` (~`:15311`) | `xschem get no_draw` | ⚠ **not a count — the issue's `~:15293`.** A 0/1 flag, beside `modified`, `autosave_backup` and `readonly` (~`:15223`, `:15226`, `:15283`), also flags |
| `ase::analysis_schema_errors` (~`:5097`), `ase::analysis_setup_min` (~`:5414`), the `two_ports` precondition (~`:12340`) | a `setup` contract's `min` | an adapter-declared minimum entry count |
| the emit-rank sort (~`:8641`) | an emit rank | not a count |
| `ase::analysis_handle`, `ase::analysis_handle_fields`, `ase::stimuli_nvec`, `ase::campaign_rerun`, the models axis, `ase::stimuli_readout`'s `k`, `ase::backend::ngspice::s2p_file` (~`:10255`, `:10340`, `:22157`, `:21506`, `:20612`, `:21888`, `:27313`) | an index | bounded by a list the caller holds |
| the hierarchy walk (~`:15040`, `:15068`, `:15072`, `:15111`, `:15132`, `:15211`, `:18921`, `:18949`) | `xschem get currsch` | depth, bounded by `CADMAXHIER` |
| `ase::wait`, `ase::campaign_wait` (~`:16557`, `:20978`) | a job id | an id |
| `ase::backend::ngspice::op_param_set` (~`:24967`) | `xschem raw loaded` | a database index, `< 0` for none |
| `ase::mc_draw` (~`:20338`) | a sample count | a loop that appends every sample; memory bounds it long before 2³² |
| `ase::stat_bins`, `ase::stat_histogram` (~`:21336`, `:21360`) | `llength` of a sample list; a bin count | list lengths |
| `ase::stimuli_readout` `nvec` (~`:21915`) | `ase::stimuli_nvec`'s `llength` of one plot's variable list | a list length |
| `ase::backend::ngspice::sp_row_check`, `sp_port_candidates` (~`:27406`, `:27498`, `:27511`), `noise_value_check` (~`:29663`) | an `sp` port number; `trrandom`'s 1–4 `dist` | small declared numbers |
| **`ase::campaign_seed`** (~`:20260`) | a seed | ⚠ **not a count, so outside this task — but it has the same shape:** 5000000000 reads as "not seeded" (measured) while `ase::mc_seed_norm` would fold it. Named for the driver, not fixed |

`src/ase_window.tcl`'s sites were scanned too: indices, entry numbers, hierarchy levels, `annot_show`
flags, a font size, a colour index and a pipe id — none a count. It has no reader of the estimate but
`ase::ui::nz_readout_text`, which formats `points` with `format %.0f` and was never bounded.

---

## Debts — queue

`owed.sh count` at hand-over: **180 rule, 69 look, 11 suite** — the same as receipt 43's after. Nothing
was added: no new user-facing sentence, no pixel, no `:0` debt (neither suite maps a window of this
change). The ledger was not written, so no backup was needed.

---

## Corrections

| | |
|---|---|
| **C1** | **The task brief: "§7g's rows live in `test_ase_preflight` or `test_ase_core`."** They live in **`test_ase_effective_1442` section RU** (RU9–RU11); RU12/RU13 went there |
| **C2** | ⚠ **The issue file: "`src/ase.tcl` ~`:15293` … test[s] point and vector counts".** It is `xschem get no_draw` in `ase::with_design_current`, a flag |
| **C3** | ⚠ **The issue file: "a rawfile's point count is not bounded by 2³²".** In this tree it is bounded at 2³¹−1 by the writer (`int length`, `%d`) and by xschem's reader (`%d` into `int`). The three `raw_content_verdict` sites were left alone for that reason. The issue file now says so |
| **C4** | **The issue file, "why NK20 was not reddened by M10"** — no longer true; S08 reds NK20 |
| **C5** | **The issue file's candidates, and receipt 43 *What binds later stages* 5 ("read with `string is double` or `string is entier`").** `double` loosens the type (S03 reds RU13), and `wideinteger` stops at 2⁶⁴ (S02). Only `entier` is "a whole number of any size" |
| **C6** | **My own first cut of RU13's oracle** used `expr {[string is integer -strict $v] ? $v : {}}`; `expr` returns the NUMBER, so ` 7` came back `7` and `0x10` `16`, and the row reported two false differences on the unfixed tree. Replaced with `if`, with a comment saying why |
| **C7** | **My own first draft of `test_ase_trnoise_1466`'s history paragraph** carried *"the count with a binary missing falls by eight as before"* forward — unmeasured by me, and `ASE_NZ_NGSPICE=/nonexistent` in the campaign took the suite from 78 to **58**. That case differs from "one of two binaries missing", and I did not measure that one, so the clause is gone |
| **C8** | **The driver's boundary table in the issue file** stops at 9223372036854775807 for `wideinteger`. Measured further: 1 at 18446744073709551615, **0 at 18446744073709551616** — which is why `wideinteger` is not the fix |

---

## What binds later stages

1. **On Tcl 8.6 a whole number is `string is entier -strict`.** `integer` means "fits 32 bits, give or
   take a sign" (1 at 4294967295, 0 at 4294967296); `wideinteger` stops at 2⁶⁴; `double` accepts `5e9`
   and `3.5`. Any count that can be large — points, bytes, a seed — is read with `entier`.
2. **`int()` and `wide()` wrap silently from 2⁶³.** An estimate computed from user-typed numbers uses
   `entier()` — and whoever does that for `ase::backend::ngspice::tran_points` has to take
   `ase::ckpt_plan`'s `int()`/`wide()` with it (headline 5).
3. **A test oracle compares with `if`, never `expr {… ? $v : …}`** — `expr` canonicalises the number and
   the oracle stops being the string the code returns (C6).
4. **A count the file format writes is bounded by the writer's C type, not by the text.** Before widening
   a rawfile reader, read the writer and xschem's own reader (C3).

## Hygiene

* **One tree-reading runner at a time**, in this order: baseline → rows written, run on the unfixed tree
  → fix → both touched suites → after-runner (all six, both arms) → campaign (after `RUNNER DONE`, no
  `xschem` alive by `comm`) → final (both touched suites, both arms). The two probes (`meas/p1.tcl`,
  `meas/p2.tcl`) ran before any edit, alone.
* **Every wait had a deadline** in the brief's shape (600 s / 420 s), reporting progress on the way out;
  none fired. No `pkill`, no `pgrep -f`; processes matched by `ps -eo comm=`.
* **Nothing under `~/.xschem/`**: every run had `HOME` pointed at `…/i1468/home`. `owed.sh count` was
  read against the real ledger and did not write to it.
* **No simulator was started by anything this task added.** `/usr/bin/ngspice` and the fork ran only the
  existing EE/EC decks of `test_ase_trnoise_1466` (and 1467's EE on its display arm) inside the
  before/after/final suite runs — decks receipt 43 already ran on both.
* **Snapshots disarmed**: the pre-change copies, the campaign's `pristine_post_ase.tcl` and `sab.py` are
  under `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/i1468/`, so nothing can restore from them. Logs are kept in
  `…/scratchpad/i1468/logs/` (`base/`, `m00/`, `fix1/`, `after/`, `final/`, `final2/`), `…/i1468/meas/`,
  and `…/i1468/sab/` (`results.txt`, `logs/`).
* **No background process of this crew is running** — checked by process name.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
