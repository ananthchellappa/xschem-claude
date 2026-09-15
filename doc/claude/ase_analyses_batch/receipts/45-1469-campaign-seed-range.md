# Issue 1469 — a campaign seed ngspice does not honour is never written and never reported

**Issue `doc/claude/issues/1469-a-campaign-seed-outside-ngspices-range-runs-unseeded-and-says-seeded.md`**, handed
to this crew by the driver as one task. Files touched, and nothing else: `src/ase.tcl` (**+202 / −9**),
`src/ase_window.tcl` (**+41 / −1**), `tests/headless/test_ase_campaign_1462.tcl` (**+436 / −1**),
`tests/headless/test_ase_campaign_gui_1464.tcl` (**+113 / −1**), `doc/claude/ase_analyses_batch/R9_COPY_REVIEW.md`
(**+76**), the issue file (status → FIXED pending the driver, a *The fix* section appended) and this receipt.

md5 at hand-over: `src/ase.tcl` `c34184f6…` (was `cfae0e2f…`), `src/ase_window.tcl` `96095410…` (was
`cd552daa…`), `test_ase_campaign_1462` `1823b9c1…` (was `0c48a66d…`), `test_ase_campaign_gui_1464` `d4c41268…`
(was `6f47cf62…`).

**No commit, no `git add`, no stash/restore/clean/push. `tests/run_regression.tcl` NOT run and not edited.**
**No C**: `make -q -C src` rc 0 before and after, `src/xschem` md5 `96fc4899…`. **No issue minted**,
`NUMBERING.md` untouched. **No simulation on a bench under `sky130A/`**: every run used a scratch `rundir`.
Both binaries ran, **fork first** for every new deck, and **neither crashed** (every run rc 0).

⚠ **HEAD moved during the task**, `36153d03` → `396070ad`: two test-only commits by another writer
(`test_ase_effective_1442`, `test_ase_meas_1443`, `test_ase_converge_1459`), none touching this task's files.
The baseline was taken at `396070ad`.

---

## ⚠ THE HEADLINES

### 1. The defect, measured through ASE-L's own runner before the fix — both binaries, fork first

A campaign seeded **2147483647** over two points that differ **only** by their seed (the resistor is ngspice's
own `agauss`), run twice on each binary (`meas/p1.tcl`, `meas/p1.pre.log`):

| | shard 1 deck | shard 1 `vmax`, run 1 → run 2 | shard 2 deck | shard 2 log | shard 2 `vmax`, run 1 → run 2 |
|---|---|---|---|---|---|
| fork | `seed=2147483647` | 5.00604e-01 → 5.00604e-01 | **`seed=2147483648`** | **1 `Cannot convert … seed value`** | **5.13913e-01 → 4.75481e-01** |
| apt 45.2 | `seed=2147483647` | 5.006044e-01 → 5.006044e-01 | **`seed=2147483648`** | **1 warning** | **5.257042e-01 → 4.713302e-01** |

A second campaign with an **options row** `seed 0` put `seed=0` in its deck and the same warning in its
`rc_ase.log` on both binaries — which is what proves the shard log carries ngspice's stderr, and is the
control row EE8 now uses.

### 2. The range is the adapter's, and `ase::campaign_seed` answers only a seed ngspice honours

`ase::backend::ngspice::campaign_seed_range` → `{1 2147483647}`, registered beside `campaign_seed_option`,
its comment carrying the driver's table and `eval_opt()`'s `int sr = atoi(token); if (sr <= 0) <warn>`
(read in `/home/analog/dev/ngspice/src/frontend/inp.c`). Core:

* `ase::campaign_seed_range {sim}` — the hook's answer, or `{}`. **No hook → no range, no fallback.** A
  malformed answer (not two whole numbers, lowest not first) is `{}`, and `ase::campaign_schema_errors` names
  it.
* `ase::campaign_seed {state {sim {}}}` — `string is entier -strict` (1468's lesson), then the range of `sim`,
  else of the state's own `simulator` key (the key `ase::ui::camp_sim` reads), else the default. Under ngspice
  0, −5, 2147483648 … 4294967295, 2³² and above, `abc` and `1.5` all answer `{}`; under a no-range backend
  5000000000 is now a seed (it was `{}`).

### 3. ⚖ DECISION: every shard's seed is FOLDED into the range, not refused — and why

`ase::campaign_shard_seed {sim state idx}`: base+idx, and past the top it counts on from the bottom
(`lo + (s − lo) mod (hi − lo + 1)`). The alternative the brief offered was to refuse any seed whose
`seed + (shards − 1)` leaves the range. Why the fold:

* **A refusal of `seed+(n−1)` depends on the point count.** A seed that is fine turns refused because the user
  **added an axis** — a sentence about the Seed field appearing while they edit a different one, including
  inside the axis editor. The fold keeps **every** honoured seed usable at **every** campaign size; a seed near
  the top refused for a reason the user cannot see is a restriction ADE-L does not impose.
* **Deterministic**, so Re-run Point reproduces the shard: `ase::campaign_rerun` → `campaign_step` →
  `campaign_shard_state` → the same seed, and the shard's own deck carries it, so the adapter's promise that a
  point re-run *by hand* from its directory reproduces it still holds. Row **SR10** deletes the wrapped
  shard's deck, re-runs the point, and requires the rewritten deck byte for byte.
* **Collision-free** while the campaign has no more points than the range has seeds: n consecutive integers are
  n distinct residues. ngspice's range is 2147483647 seeds against `ase::campaign_max_points` 2000 (**SR4b**
  walks all 2000 across the top). A smaller declared range is **refused** (`seedspan`, **SR5b**) rather than
  folded onto itself.
* **Said.** The per-shard sentence gains `, wrapping to 1 after 2147483647` exactly when a campaign crosses
  the top (**SR6**, **GS5**); every other seeded campaign keeps its sentence byte for byte (**SR6**'s second
  element, NT5 unmoved).
* **Precedent**: `ase::mc_seed_norm` already folds the sampler's seed rather than refusing it.
* **The cost**: past the top, shards reuse seeds 1, 2, … that another campaign seeded 1 also uses — the same
  overlap base+N already has between any two campaigns (campaign 5's shard 3 is campaign 8's shard 0).

Filed with the sentences as `owed.sh add rule 1469`, so the user sees it was a choice.

### 4. Refused at the form and at run, before anything is written

`ase::campaign_seed_refusals {sim state}` → `{badseed refuse "the seed must be a whole number from 1 to
2147483647, the only seeds this simulator honours" "type a seed in that range, or leave it empty"}`. It is
its **own** reader, not gated on the campaign being enabled, because a seed typed before the first axis is
still a seed. It is asked at every door:

| door | what happens now | row |
|---|---|---|
| `ase::campaign_refusals` → `ase::campaign_run` | refused before `campaign/` exists | SR3 SR9 EE9/apt EE9/fork |
| `ase::campaign_rerun` (Re-run Point) | refused | SR9 |
| the dialog's note line + Run button (`ase::ui::camp_refusals`) | the sentence as typed, Run dead — **also with no axes**, where it replaces *No axes yet* | GS1 GS4 |
| OK (`ase::ui::camp_ok`) | refused, dialog stays, session keeps its seed | GS2 |
| Run Campaign (`ase::ui::camp_run`) | refused **before** it commits the form (it deliberately commits before every other refusal) | GS3 |
| the axis editor | **not** refused over the bench's seed — it reads `ase::campaign_seed`, which is `{}` for a refused seed | GS6 |
| a `.state` already carrying such a seed | loads, keeps the seed, saves byte for byte — refused, never repaired | SR11 |

### 5. The seed report agrees with the simulator — including a branch the issue did not name

`ase::stimuli_seeded` (so `ase::stimuli_seed_report`, the Tran form's noise sentence) counts a campaign seed
only through `ase::campaign_seed`, **and** — under a declared range — counts an options `seed` row only when
`ase::campaign_seed_honoured` says ngspice keeps its value. Before, **any** row named `seed` counted, so
`seed 0`, `seed 2147483648` and `seed random` made the noise section say RTS noise *"repeats exactly under the
seed"* (**SR7** before: `{1 1 1 1 1 1 1}`, after `{1 0 0 1 0 0 0}`). A backend with no range keeps the old
answer (**SR7c**).

### 6. Not a `look` — decided by measurement on `:99` (openbox 3.6.1)

`meas/p2.tcl` opened the real Campaign dialog and read its requested size and the note label (`meas/p2.log`):

| state | dialog req | note req | rendered lines |
|---|---|---|---|
| A seeded campaign, notes | 715×464 | 597×140 | 8 |
| B the wrap variant of the notes | 715×481 | 596×157 | 9 |
| **C the new refusal, with axes** | **715×362** | 547×38 | 2 |
| D an **existing** refusal (`temp` as a variable) | **715×362** | 601×38 | 2 |
| **E the new refusal, no axes** | **715×362** | 547×38 | 2 |
| F *No axes yet* (existing) | 715×345 | 454×21 | 1 |

The refusal is **exactly** the size of a refusal the dialog already shows (C = D); with no axes it takes that
same existing size (E = D) in place of F; the wrap variant adds one wrapped line to a label that already grows
line by line (A → B). No widget, no layout, no width changed. The words are the rule debt.

---

## ⚠ WHAT I MEASURED VERSUS WHAT I TRANSCRIBED

All 2026-09-15, `HOME` → `…/i1469/home`, `XSCHEM_DEVDISPLAY_DIR` the real state dir, `GUI_GATE=0`, every command
under `timeout`.

| claim | evidence |
|---|---|
| the full refusal/wrap table in the issue | **TRANSCRIBED** from the driver |
| `.options seed=2147483647` repeats with `$rndseed` 2147483647; `seed=2147483648` → one warning, `$rndseed` 1, a different value per run, rc 0 | **MEASURED HERE**, fork then apt, two runs each, ASE-L's own spelling (`meas/probe.sh`) |
| `eval_opt()` is `atoi` then `sr <= 0` → warn | **READ HERE**, `src/frontend/inp.c` in `/home/analog/dev/ngspice` — source, not a run |
| the defect through ASE-L's runner (headline 1) | **MEASURED HERE**, both binaries, fork first (`meas/p1.pre.log`) |
| a shard's `rc_ase.log` carries the simulator's stderr warning | **MEASURED HERE** (p1's options `seed 0` campaign), and in-suite as EE8's control |
| Tcl 8.6.17: `integer` vs `entier` on 0 −5 2³¹ 2³²−1 2³² 5e9 `08` `010` `0x10` ` 7` `+7` `1.5` `abc` `{}` `1e3` `-0`; `entier(010)` = 8 | **MEASURED HERE** (`tclsh`) |
| dialog geometry (headline 6) | **MEASURED HERE** on `:99`, openbox live (`devdisplay.sh status`) |
| `.state` round trip | **MEASURED HERE** (`tests/headless/state_roundtrip.tcl` through `test_ase_trnoise_1466` NC1, both arms) |

---

## What shipped

### `src/ase.tcl`

| proc | change |
|---|---|
| `ase::campaign_seed` | `entier`; optional `sim`; `{}` for a seed outside the simulator's declared range |
| `ase::campaign_seed_range` | **new** — the adapter's range, validated, `{}` with no hook |
| `ase::campaign_seed_honoured` | **new** — whole number inside the range (any whole number with no range) |
| `ase::campaign_seed_refusals` | **new** — `badseed`, independent of the campaign being enabled |
| `ase::campaign_shard_seed` | **new** — base+idx folded into the range |
| `ase::campaign_shard_state` | writes `ase::campaign_shard_seed` instead of `wide($seed) + $idx` |
| `ase::campaign_refusals` | includes the seed refusal; passes `sim` to the sampler's seed; `seedspan` |
| `ase::campaign_notes` | reads the honoured seed; the wrap clause; `entier` in place of `wide` |
| `ase::campaign_schema_errors` | names a malformed `campaign_seed_range` |
| `ase::stimuli_seeded` | `sim` to `campaign_seed`; under a range, an options seed row counts only when honoured |
| `ase::backend::ngspice::campaign_seed_range` + its registration | **new** — `{1 2147483647}` |

Untouched: `ase::mc_seed_norm`, `ase::mc_draw`, `ase::campaign_axis_values`, `ase::campaign_points`,
`ase::campaign_rerun`, `ase::stimuli_seed_report`. The only 2147483647 literals in core outside the adapter are
the sampler's pre-existing Park-Miller modulus (`ase::mc_seed_norm`, `ase::mc_next`, `ase::mc_unit`).

### `src/ase_window.tcl`

| proc | change |
|---|---|
| `ase::ui::camp_refusals` | adds the seed's own refusal when core's campaign refuser is silent (no axes) |
| `ase::ui::camp_ok` | refuses a seed refusal, dialog stays |
| `ase::ui::camp_run` | asks the seed refusal **before** committing the form |

The three readers the brief names (`ase::ui::camp_axis_points`, `camp_axis_sync`, `camp_axis_ok`) needed **no
edit** — correction **C2**.

### `tests/headless/test_ase_campaign_1462.tcl` — 133 → **161**, both arms, floor raised with its own paragraph

Section **SR** (20 rows, pure Tcl): SR1 SR2 SR2b SR2c SR3 SR3b SR3c SR3d SR4 SR4b SR4c SR5 SR5b SR6 SR6b SR7
SR7b SR7c SR8 SR11 — with fixture backends `norange` (no hook), `tinyrange` (10..12, which is what makes the
fold arithmetic and `seedspan` falsifiable) and two malformed ranges. **SR9 SR10** in section RN (the `/bin/sh`
stand-in). **EE7 EE8 EE9** once per binary in section EE.

### `tests/headless/test_ase_campaign_gui_1464.tcl` — display 156 → **162**, headless 78 unchanged, floor raised

Section **GS** after GR13b: GS1–GS6. It restores the form and the session to GR13's state for GT.

---

## Suites — before → after, every arm, with rc

**Before** = the untouched tree at `396070ad` (`…/i1469/logs/base/`, 13:12:51–13:13:49). **After** = the final
tree (`…/logs/after/`). Headless `timeout --kill-after=20 900 ./src/xschem --nogui --pipe -q --nolog --script`;
display `tests/headless/devdisplay.sh exec timeout --kill-after=20 900 ./src/xschem --pipe -q --nolog --script`
on `:99`. Verdicts are a positive assertion (`PASS` only on rc 0 **and** `RESULT: ALL PASS`; no `RESULT:` line
is `NORESULT`).

| suite | headless before | headless after | display before | display after |
|---|---|---|---|---|
| **`test_ase_campaign_1462`** | 133, rc 0 | **ALL PASS (161), rc 0** | 133, rc 0 | **ALL PASS (161), rc 0** |
| **`test_ase_campaign_gui_1464`** | 78, rc 0 | 78, rc 0 | 156, rc 0 | **ALL PASS (162), rc 0** |
| `test_ase_trnoise_1466` | 78, rc 0 | 78, rc 0 | 78, rc 0 | 78, rc 0 |
| `test_ase_trnoise_gui_1467` | 19, rc 0 | 19, rc 0 | 63, rc 0 | 63, rc 0 |
| `test_ase_persist` | 49, rc 0 | 49, rc 0 | 153, rc 0 | 153, rc 0 |
| `test_ase_core` | 638, rc 0 | 638, rc 0 | 638, rc 0 | 638, rc 0 |

Every cell is `ALL PASS (<n> checks)`.

**Not a count diff — a name diff.** For all 12 logs, the sorted `ok:`/`FAIL:` + row-id list after versus
before: **eight logs identical** (1464 headless and every neighbour, both arms); 1462 differs on each arm by
exactly the 28 added `> ok:` rows; 1464's display arm by exactly `> ok: GS1` … `> ok: GS6`. No existing row
moved.

**Without the fix, first** (`…/logs/m00/`): the rows were written and run against the **unchanged** `src/`
before any fix — 1462 **`26 FAILED (134 passed)`** on both arms, the reds being every new row but SR7c (a
no-fallback guard, green by design) with SR11 not yet written; 1464 display **`5 FAILED (157 passed)`**, GS1–GS5
(GS6 is a guard). Every original row green. The pre-fix values of the rows that measure the defect:
EE7 `{done done {seed=2147483647 seed=2147483648} 0 1}`, EE8 `{4 2 {4 0} 1 1 seed=0}`, EE9 `{done {} 1 0}`,
SR9 `{{done {}} {done {}} 1}`, SR10 `{done {seed=2147483647 seed=2147483648} done 1}`, SR2b `{0 -5 {} {}}`,
GS2 `{0 2147483648}`, GS3 `{{done {}} 2147483648 1 1}`.

### Per binary

EE7, EE8 and EE9 ran on **`/usr/bin/ngspice` 45.2 and the fork** in every before/after/final and sabotage run,
**0 `SKIPPED` lines**. The new decks ran on the fork first (`meas/p1.tcl`) before the suite ran them on either.
Everything else this task added is pure Tcl and starts no simulator.

---

## `.state` byte identity

Through **`tests/headless/state_roundtrip.tcl`** inside `test_ase_trnoise_1466` (row NC1), on the after tree,
both arms:

```
tracked 104    bad {}    control_disagrees 1    control_agrees 1
```

No state key added; `ase::omit_if_empty` untouched. And **SR11**: a `.state` written with a seed of `0`,
`2147483648`, `5000000000` or `abc` reloads through `ase::state_load` and re-saves through `ase::state_save`
byte for byte, keeps its seed, reads as no seed and is refused — with a control that a repaired seed saves
differently.

---

## THE SABOTAGE CAMPAIGN — 23 arms, every one of 34 new rows reddened, 0 restore mismatches

`sab.py` started after the after-runner printed `RUNNER DONE` with no `xschem` alive (matched by `comm`),
13:36:08–13:40:25. **The gate is a positive assertion and was fed the empty case first**:
`GATE CONTROLS empty=NORESULT partial=NORESULT pass=SURVIVED fail=KILLED`. Each arm checks the tree is the
post-fix bytes, applies one mutation on an exact anchor count of 1, runs 1462 headless (EE live on both binaries)
and 1464 on the dev display, reads reds **by row name**, then restores by plain write and md5-checks. Tcl only,
nothing to build.

| # | what I broke | reds |
|---|---|---|
| **S00** | **the whole pre-change `src/ase.tcl` and `src/ase_window.tcl`** | SR1 SR2 SR2b SR2c SR3 SR3b SR3c SR3d SR4 SR4b SR4c SR5 SR5b SR6 SR6b SR7 SR7b SR8 SR11 SR9 SR10 · EE7 EE8 EE9 (both) · GS1–GS5 |
| S01 | the adapter does not register `campaign_seed_range` | SR1 SR2 SR2c SR3 SR3b SR3d SR4 SR4b SR4c SR6 SR6b SR7 SR7b SR11 SR9 SR10 · EE7 EE8 EE9 (both) · GS1–GS5 |
| S02 | `campaign_seed` reads with `integer` again | SR2b |
| S03 | `campaign_seed` does not consult the range | SR2 SR2c SR3 SR3b SR3d SR5 SR6b SR7 SR7b SR11 SR9 · EE9 (both) · GS1–GS4 |
| S04 | the seed refusal never fires | SR3 SR3b SR3d SR5 SR11 SR9 · EE9 (both) · GS1–GS4 |
| S05 | the seed refusal fires for **every** seed | SR3c SR5 SR5b SR10 · EE7 EE8 (both) · GS5 — plus 38 existing rows whose seeded campaigns it refused (RN1–RN8b RN13, EE1 EE2 EE3b both, RR1–RR7, GR1–GR13, GT2, GX0) |
| S06 | no fold: base+N past the top | SR4 SR4b SR4c SR5 SR10 · EE7 EE8 (both) |
| S07 | the fold off by one (mod hi−lo) | SR4 SR4b SR4c SR5 SR10 · EE7 (both) |
| S08 | a no-range backend given ngspice's range as a **fallback** | SR1 SR2b SR2c SR3d SR4c **SR7c** |
| S09 | `seedspan` never asked | SR5b |
| S10 | the notes never say the wrap | SR6 · GS5 |
| S11 | the notes read the typed seed | SR6b |
| S12 | `stimuli_seeded` counts any options seed row | SR7 |
| S13 | `stimuli_seeded` counts the typed campaign seed | SR7 SR7b |
| S14 | a range with its lowest last accepted | SR8 |
| S15 | the validator does not name a malformed range | SR8 |
| S16 | the runner's refuser omits the seed refusal (the form still has it) | SR3 SR5 SR11 SR9 · EE9 (both) |
| S17 | the shard state writes `wide(seed)+idx` again | SR4 SR10 · EE7 EE8 (both) |
| S18 | `campaign_seed` ignores the state's own simulator | SR2b |
| S19 | OK does not refuse the seed | GS2 GS3 |
| S20 | Run commits the form before asking the seed | GS3 |
| S21 | the dialog's list omits the seed refusal with no campaign | GS4 |
| S22 | the axis editor hands core the raw typed seed | **GS6** |
| **final** | **the restored tree**, md5 `c34184f6…` / `96095410…` | **1462 ALL PASS (161) both arms, 1464 ALL PASS 78 headless / 162 display, rc 0** |

**Coverage, every new row → the arms that reddened it** (from `results.txt`): each of the 34 has at least one;
the two with a single killer are **SR7c** (S08) and **GS6** (S22), both guards against a specific wrong turn.

Logs: `…/i1469/sab/results.txt`, `…/i1469/sab/logs/<arm>.<suite>.<h|d>.log`.

---

## Debts — queue

`owed.sh count`: **180 rule, 69 look, 11 suite** before → **181 rule, 69 look, 11 suite** after. The ledger was
backed up first (`…/i1469/owed_backup/`).

* **rule `1469`** — the six new strings and the fold decision; **R9_COPY_REVIEW.md** section *Issue 1469*,
  **R9-672 … R9-677**: the `badseed` refusal and its fix, the `seedspan` refusal (unreachable on ngspice) and its
  fix (the existing *too many points* fix's words), the per-shard sentence's wrap variant, and an adapter-author
  diagnostic.
* **look** — none, by measurement (headline 6).
* **suite** — none added: `test_ase_campaign_gui_1464` is **already** on the suite list from Stage 11, and that
  standing `:0` debt now covers section GS.

---

## Corrections

| | |
|---|---|
| **C1** | **The brief and the issue: "`ase::campaign_prepare` writes `.options seed=[expr {wide($seed) + $idx}]`".** It is **`ase::campaign_shard_state`**; `campaign_prepare` renders only the nominal deck, which carries no campaign seed |
| **C2** | **The brief names the dialog's seed readers (~`:13834`, `:14345`, `:14372`) as surfaces to fix.** None needed an edit: each passes the form state to `ase::campaign_seed`, which resolves the simulator from that state's `simulator` key — the key `ase::ui::camp_sim` → `chana_sim` reads. GS6 pins the one consequence that matters (S22 reds it) |
| **C3** | **The issue names only the campaign seed.** `ase::stimuli_seeded`'s options-row branch had the same defect — `seed 0`, `seed 2147483648` and `seed random` all counted as seeded — and it is the other half of "the seed report agrees with the simulator", so it is fixed here (SR7; S12 reds it). No-range behaviour kept (SR7c) |
| **C4** | **The issue: "a campaign whose last shard would cross the boundary never writes an unhonoured seed" by refusing or folding.** Folded — headline 3 — with the per-shard sentence saying so |
| **C5** | ⚠ **My own first "launch" of the baseline only made the runner executable and printed a time.** Caught on reading my own output before any result was used; the baseline was then launched and completed (13:12:51–13:13:49) |
| **C6** | **My own first draft of `camp_run`'s comment said "Nothing is routed" for a refused seed.** The check sits after `ase::ui::route_design`, which writes nothing; the comment was corrected before any run |
| **C7** | **SR11 was written after the unfixed-tree run `m00`**, so its pre-fix red is S00's (the whole pre-change source), not `m00`'s |

---

## What binds later stages

1. **A simulator's seed facts are `campaign_seed_option` and `campaign_seed_range`.** Read a campaign seed with
   `ase::campaign_seed $state $sim`, a shard's with `ase::campaign_shard_seed`, a free-standing value with
   `ase::campaign_seed_honoured` — never `wide($seed) + $idx`.
2. **A form door that commits before asking core must ask FIRST about a value the form itself holds** (GS2/GS3):
   otherwise the refusal is about a number it has just written into the state.
3. **A shard's `rc_ase.log` carries the simulator's stderr**, so a per-shard ngspice warning is greppable — EE8's
   control shows how to make such a grep able to disagree.
4. **Named, not filed** (both in the issue file): the Options sheet still accepts `seed 0` / `2147483648` / `random`
   and renders them (the report now says unseeded, which is true); and Tcl 8.6 reads `08` as not a number and
   `010` as 8, so a numeric field meant as decimal must say so or normalise.

## Hygiene

* **One tree-reading runner at a time**, in this order: baseline → probe `p1` (unfixed tree) → rows written →
  `m00` (unfixed tree) → fix → `fix1` (touched suites) → SR11 → look probe `p2` → after-runner (all six, both
  arms) → sabotage campaign (after `RUNNER DONE`, no `xschem` alive by `comm`) → its final restored-tree row.
* **Every wait had a deadline** in the brief's shape (the campaign's waiter, 570 s, reporting arms done and
  whether `python3`/`xschem` were alive; it finished in 240 s), and every command a `timeout`. No `pkill`, no
  `pgrep -f`; processes matched by `ps -eo comm=`.
* **Nothing under `~/.xschem/`**: every run had `HOME` pointed at `…/i1469/home`; every simulation used a scratch
  `rundir`. `owed.sh` wrote the real ledger once (`add rule 1469`), after a backup.
* **Snapshots disarmed**: the pre-change copies, the campaign's post-fix copies and `sab.py` are under
  `…/scratchpad/ARCHIVED_DO_NOT_RESTORE/i1469/`, so nothing can restore from them. Logs kept:
  `…/i1469/logs/{base,m00,fix1,after}/`, `…/i1469/meas/{probe.sh,p1.tcl,p1.pre.log,p2.tcl,p2.log}`,
  `…/i1469/sab/{results.txt,stdout.txt,logs/}`.
* **No background process of this crew is running** — checked by process name.
* ⚠ **If this crew is woken after collection: `git status` and `git log` before touching anything.**

`…/scratchpad` is `/tmp/claude-1000/-home-analog-dev-xschem-claude/c8183bb1-7387-41d6-9d30-a409f8d7e1a3/scratchpad`.
