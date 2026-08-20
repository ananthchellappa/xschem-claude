# Item 6 — `viewer.rawfile` is finally WRITTEN (R601-R605)

## 1. Files changed

| file | lines | what |
|---|---|---|
| `src/wave_viewer.tcl` | **+182 / −17** | new `wviewer::selected_rawfile` + `wviewer::selection_record`; `snapshot` writes the slot (was the hardcoded `rawfile {}`) and never erases it; `restore`'s inline attach comes onto `results::select`; `forget` drops the record; the build-order comment corrected |
| `src/ase_window.tcl` | **+145 / −11** | new `ase::ui::viewer_rawfile_relative` (R602b/d/e); `viewer_restore` re-expressed on `results::resolve` and given the R604a sentence |
| `src/results.tcl` | **+67 / −37** | `results::persist` filled (item 4's stub) as the F4 fallback store; `results::select` gains the `host none` arm's door duties |
| `tests/headless/test_results_select.tcl` | **+438 / −5** | group **AO**, ids **SEL339-SEL359 (21 new)**, 340 → **361** checks; SEL269 and SEL346 restated, SEL350 el.1 repaired, SEL351 extended |
| `tests/headless/test_ase_persist.tcl` | **+242 / −2** | new always-running group **R6** + G7/G8/G10/**G11b**/T-E legs, 109 → **136** |
| `doc/claude/specs/results_selection.md` | **+258 / −40** | new **§8.1** (l.1314): R602a-f, R604a, R605a; §5.2's item-4 description corrected in place (l.914) |
| this receipt | rewritten | 487 → this |

**No C, no rebuild.** Scope fence held: no Select dialog (item 7), no Waves menu (8), `raw_is_loaded` still there (9), `calculator.tcl` untouched (10), and the restore path's **clear-then-read ORDER is unchanged** (out of batch).

## 2. Decisions taken, and the evidence

Seven crew rulings, all written into `doc/claude/specs/results_selection.md` **§8.1**. None re-opens `DECISIONS.md`.

- **R602a (l.1321) — the persisted value is read from the ENGINE at snapshot time** (`results::current` through the 0173 `enter_ctx $token 1` loan); `results::persist` is only its F4 fallback. **This OVERTURNS item 4's description of its own seam**, and §5.2 l.914 is corrected rather than left standing. Evidence: `results::persist` neutered back to item 4's `return 0` stub leaves **G7 green** — the state file still carries the right path — while SEL340/341/343/344/352 go red. The acceptance flow T-F names never comes through R303's door; and the state dict is rebuilt at save time, so a write there would dirty the session (`ase::session_dirty` is derived) on every Location-bar load.
- **R602b (l.1366) — `ase::ui::viewer_snapshot` is where the path becomes relative**, not `wviewer::snapshot` (it does not know the rundir) and not `results::persist` (R602a). The under-the-rundir test is **component-wise** (`file split`/`lrange`), not a string prefix: the `string first` form answers `is/an.raw` for a `<rundir>bis/…` sibling (SEL347).
- **R602c/d/e/f (l.1392-1450, fix round) — four defects the review found, ruled and fixed.** *(c)* the "absolute in memory" contract is **enforced**, not asserted: `cd <dir>; xschem raw read an.raw tran` leaves the registry answering `an.raw`, so both sources `file normalize` where the cwd still means something (SEL358). *(d)* an already-relative slot value is a **fixed point** — without the `file pathtype` guard `file normalize` re-relativised it against the CWD and it COMPOUNDED (`an.raw` → `sub/an.raw` → `sub/sub/an.raw`, rc 1 each time), then the read side called a present file `invalid` (SEL353, SEL359). *(e)* the rundir is **queried**, `ase::rundir` is not called — it is a create-and-default helper that `file mkdir`s and rewrites the global `::netlist_dir`; SEL355 shims it to a counter and requires **zero** calls. The cost, that a state naming no rundir stores a machine-specific path, is taken deliberately: guessing the default from `::netlist_dir` can disagree with what `viewer_restore` resolves against once `local_netlist_dir` re-points it, and a path resolving to the WRONG file is worse than one merely unportable. *(f)* a Save State never **erases** the stored selection — `prev`'s value is kept when neither source answers (SEL357).
- **R604a (l.1467) — `ok` and `default` say nothing; `stale` and `invalid` speak, once.** The pre-existing no-results sentence is suppressed when the resolver has already spoken (`said` gate). Evidence: announcing every status reds R6a/R6b/R6c; dropping the `said` gate gives two sentences for one event and reds R6e ×2 + G10's "did NOT also emit".
- **R605 confirmed UNCHANGED** — the `catch {xschem raw clear}` on the restore path stays exactly where and when it was; SEL348 asserts it positionally (clear present, door present, clear **before** the door). That behaviour change needs T-E and is explicitly out of this batch.
- **R605a (l.1451, fix round) — a session restore IS a selection for the MRU.** Routing the attach through `results::select` makes re-opening a saved session write `$USER_CONF_DIR/raw_history`, which the bare `xschem raw read` never did. **Ruled kept**: 0216's shape, and **bounded** — `rawhist_add` dedupes on the normalised path and caps at 20, so re-opening the same session writes once. SEL356 asserts exactly that (same path twice, `mru` in `did` the first time and **not** the second), in group AJ's shim discipline: every writer the flag ungates is shimmed *before* the flag is raised, the flag is raised around the single call under test, `::wviewer::rawhist` saved and restored.
- **R201c divergence accepted** (l.500) — a named result that exists but cannot be READ now falls back instead of being attached, because the resolver calls it `invalid`. Recorded in the spec and in the proc's own comment.

## 3. Checks and result

`tests/headless/test_results_select.tcl` group **AO** — **SEL339-SEL359, 21 new ids, 340 → 361 checks.** Band measured free at 338 by `grep -ohE 'SEL[0-9]+' tests/headless/*.tcl | sort -n | tail`, not from a doc; nothing renumbered. **SEL269 restated** — its VALUE did not move (an opts dict naming neither `token` nor `key` still answers 0) but its old name's claim, *"a no-op stub today"*, stopped being true. `tests/headless/test_ase_persist.tcl` — **109 → 136**: new always-running group **R6** (15 checks), G7 restated + 1, G8 + 1, G10 + 5, **G11b** + 4, and the T-E reason gate.

**T-E was the one test in this batch that could have been green by not running, and three things were done about it.** (1) The skip **REASON** is asserted, not the count: `te_why` is recorded at each self-skip branch and compared, at the foot of the file, against preconditions re-measured there independently — forcing `te_why` to `RAN` under `--nogui` reds that check alone. (2) The "says so" half was moved into **R6a-R6f**, a group that CANNOT skip: six shimmed states driven through `ase::ui::viewer_restore` with no DISPLAY and no ngspice, all sentences asserted by text. (3) **G11 was made discriminating as G11b** — G11's relative `test_nfet_final_ase.raw` is also what `ase::last_rawfile` derives, so it could not tell "the stored name was followed" from "the fallback happened to be the same file"; G11b copies a second raw to `alt_pick.raw`, a name the derived default can never produce. Dropping the rundir resolution reds G11b while **G11 stays green** — the gap measured, not asserted.

Closer's own runs on the final tree, `GUI_GATE=1` through `run_suites.sh`, dev display `:99`:

```
display arm: ATTACHED to persistent dev display :99 (devdisplay.sh), GUI_GATE=0
PASS     | test_results_select          run 1/3  RESULT: ALL PASS (361 checks)
PASS     | test_ase_persist             run 2/3  RESULT: ALL PASS (136 checks)
PASS     | test_wave_crossdb_trace      run 3/3  RESULT: ALL PASS (130 checks)
RESULT: 3/3 runs passed
```
`--nogui` arms: `test_results_select` **ALL PASS (361)**; `test_ase_persist` **ALL PASS (33)** printing `T-E legs: no usable DISPLAY` — on `:99` the same file prints `T-E legs: RAN` and 136, so the reason tracks reality both ways. `test_wave_crossdb_trace` is the strongest existing read-side witness (a state whose `viewer.rawfile` names an analog raw with cross-database VCD trace suffixes) and is unbroken.

**Audit — a DIFF, not a count.** `GUI_GATE=1 tests/headless/full_audit.sh`, dev display `:99`, closer's own run on the final tree:

```
SUMMARY: 332 pass  15 fail  0 crash/timeout  0 skip  (total 347)
WIREEDIT: ALL PASS / PASS      SCRATCH: 0 leaked dir(s)
TREE:     0 appeared  0 vanished (report only, gitignored paths excluded)
```
Joined by test NAME and STATUS against `baseline_2026-08-19_226302f9.txt` (331/15/0/0 of 346):
```
baseline rows 346   new rows 347
baseline: PASS 331  FAIL 15        new: PASS 332  FAIL 15
STATUS CHANGED (0):
ONLY IN BASELINE (0):
ONLY IN NEW (1):    test_results_select   PASS
```
**0 green→red and 0 red→green across all 346 shared rows, and nothing only in the baseline.** The one extra row is `test_results_select`, which `LEDGER.md` records as item 1's declared addition. The 15 reds are the baseline's 15 **by name**: `test_ase_window`, `test_cadence_drag`, `test_ciw`, `test_gf180mcud_libmgr`, `test_ihp_sg13g2_libmgr`, `test_lib_manager_gui`, `test_lib_manager_locate`, `test_lib_sweep`, `test_reopen_readonly`, `test_rotate_stretch_short_0104`, `test_selflog_output`, `test_sky130a_libmgr`, `test_wave_markers`, `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`. Counting note: a naive `grep -cE '^FAIL'` over-counts, because within-file detail is spelled `FAIL     | key …`; the join anchors on `test_\S+`, which is what makes the row counts 346/347. **No `.sh` suite was touched**, so nothing needed a by-hand run outside the glob.

## 4. Sabotage

**29 drives** (18 first-round + 11 fix-round), each broken, run, restored from a byte-exact backup (`filecmp`-asserted; never `git checkout --`, the item is uncommitted) and re-run green. Drivers `scratchpad/item06/sab.py`, `scratchpad/fix06/sab.py`. **All 29 restored green.** Every new check has a row; the six with no red are listed as unsabotaged at the foot and are **not evidence**.

| check | what was broken | red | restored |
|---|---|---|---|
| SEL339 | *(see foot — unsabotaged)* | — | — |
| SEL340, SEL344 | `results::persist` back to item 4's `return 0` stub / the record fallback dropped | ✔ | ✔ |
| SEL341 | persist keys on `key` before `token`; and the stub drive | ✔ | ✔ |
| SEL342 | `selected_rawfile`'s ENGINE arm dropped | ✔ | ✔ |
| SEL343 | the RECORD preferred over the engine (R602a reversed) | ✔ | ✔ |
| SEL345 | "nothing known" answers something other than `{}` | ✔ | ✔ |
| SEL346 *(restated)* | the `rawfile {}` hardcode restored in the `dict create` | ✔ | ✔ |
| SEL347 | the component-wise rundir test → `string first`; and `rawfile $rel` → `$np` | ✔ | ✔ |
| SEL348, SEL349 | the restore path back to a bare `xschem raw read`; and `host none` replaced by a derived channel | ✔ | ✔ |
| SEL350 *(el.1 repaired)* | `viewer_restore` keeps its hand-written copy of §4's arms; and the resolver CALL removed with the comment kept | ✔ | ✔ |
| SEL351 el.3-5 | test-side: one `cd $ao_pwd` restore dropped | ✔ | ✔ |
| SEL351 el.1-2 | *(see foot — unsabotaged)* | — | — |
| SEL352 | `wviewer::forget` stops dropping the record; and the `variable selected` declaration deleted | ✔ | ✔ |
| SEL353, SEL359 | the two `file pathtype` guard lines deleted — reproduces the exact compounding, and rc 1 on every save | ✔ | ✔ |
| SEL354 | `results::current` → "last result-typed of `results::list`" (the review's own sabotage, which had survived all 490 checks) | ✔ | ✔ |
| SEL355 | `ase::state_get $st rundir` → `ase::rundir $st` | ✔ | ✔ |
| SEL356 | the `wviewer::rawhist_push` call neutered (also reds 9 pre-existing MRU checks) | ✔ | ✔ |
| SEL357 | the keep-`prev` block deleted; and the hardcode drive | ✔ | ✔ |
| SEL358 | `selected_rawfile`'s `file normalize` deleted (el.3); `selection_record` stores `$path` not `$p` (el.5) — one drive per normaliser | ✔ | ✔ |
| R6a ×2, R6c ×2 | the resolver's `key` dropped / `rundir` dropped / R604a reversed (every status announced) | ✔ | ✔ |
| R6b "sentence, once" | R604a reversed | ✔ | ✔ |
| R6b "no raw handed" | *(see foot — unsabotaged)* | — | — |
| R6d ×3 | `key` dropped; `state_get path` → `named`; the `ase::echo` line deleted; the hand-written revert | ✔ | ✔ |
| R6e ×4 | `state_get path` → `named`; the echo deleted (0 sentences); the `said` gate dropped (2 sentences) — pinned from both sides | ✔ | ✔ |
| R6f | `viewer_restore`'s `open 1` gate dropped (+30 downstream G-legs) | ✔ | ✔ |
| R6 shims el.4 *(repaired)* | the resolver CALL removed, comment kept — **stayed green before the repair** | ✔ | ✔ |
| R6 shims el.1-3 | *(test hygiene — unsabotaged)* | — | — |
| G7 ×2 | the hardcode restored; the relativisation dropped; the engine arm removed | ✔ | ✔ |
| G8 T-F round-trip | the attach removed entirely | ✔ | ✔ |
| G10 sanity | the hardcode; the relativisation dropped | ✔ | ✔ |
| G10 T-E ×3 | the echo deleted; the hand-written revert; the hardcode; the engine arm removed; the `said` gate dropped | ✔ | ✔ |
| G10 "echo shim restored" | *(see foot — unsabotaged)* | — | — |
| G11b "STORED name followed" | the rundir resolution dropped — **G11 stays green in the same run**, which is why G11b exists | ✔ | ✔ |
| G11b "really attached" | the attach removed | ✔ | ✔ |
| G11b "reopen → 1", "viewer up" | *(see foot — unsabotaged)* | — | — |
| T-E legs reason | *(see foot — unsabotaged; driven in two real states instead)* | — | — |
| PRE drive | all three sources at their pre-item bytes | **22 checks red** | ✔ |

**Unsabotaged, therefore not evidence — 6, all guard/hygiene, none of them the payload:** `SEL339` (a negative boundary that was green before the feature too; its positive counterpart SEL340 reds), `SEL351` elements 1-2 and `R6 every shim restored` elements 1-3 and `G10 T-E: the echo shim was restored` (test hygiene, no production code behind them), `R6b nothing at all: no raw handed to the viewer` (null-input boundary — nothing aimed at it moves it), `G11b reopen → 1` and `G11b viewer up` (structural guards for the two checks after them), and `T-E legs: the recorded reason matches the measured preconditions` (a meta-check on the file's own skip bookkeeping — driven instead in two REAL states: `RAN` on `:99` with 136 checks, `no usable DISPLAY` under `--nogui` with 33, and the reason matched both ways).

## 5. What was NOT verified

- **Raised but not confirmed: none.** All nine confirmed review findings were reproduced before being fixed (six code defects, three evidence defects); the reviewers' "raised but not confirmed" list was empty.
- **Reviewer not-proven, carried forward.** *(a)* No lens ran `full_audit.sh` — three lenses shared one tree; the audit in §3 is the closer's own on the final tree. *(b)* **The `sim_type` is not persisted** — `snapshot` keeps only `[lindex … 0]` of `selected_rawfile`'s `{path type}` and `viewer_restore` re-reads with `ase::plot_sim_type $st`, so a result whose analysis differs from the state's plot analysis restores under the wrong type. Hypothesis only; no multi-analysis fixture was built, and it is arguably pre-existing (the slot was always the hand-editable seam). Not filed. *(c)* Whether the CWD-under-rundir precondition of the compounding defect is the *common* case: proven to corrupt when the cwd is a strict descendant (cwd == rundir and cwd outside are both safe), frequency not measured. *(d)* The `enter_ctx $token 1` borrow from inside a real GUI gesture frame — group AO hands `enter_ctx` a `win_path` that IS the current one, so the "already there" fast path makes `borrow 1` vs `0` observably identical in a script. *(e)* The R201c divergence itself: no fixture drives an unreadable-but-present file. *(f)* A record made under an ASE `key` rather than a viewer `token` is never dropped by `wviewer::forget` (which unsets by token); for ASE the two are the same string, so no leak was constructible.
- **The MRU chain is pinned at the door, not end-to-end.** SEL356 asserts `results::select`'s push and its dedupe; SEL348/349 pin the `wviewer::restore` → door chain by source shape. What is NOT driven is restore → door → `raw_history` with `::update_recent_files` actually up — that is precisely the `$HOME` risk this batch has realised twice.
- **`~/.xschem` checked by md5 before and after every drive and the audit.** `raw_history` `34ff432f…` and `recent_files` `f219bba5…` **byte-unchanged**; `grep -c _resultssel_` / `_ase_persist_` both 0. The one file that moved is `geometry`, the per-cell window-geometry cache every GUI xschem exit rewrites — it already carried an earlier item's `_ws_w1_…` entries with timestamps predating this item.
- **Not driven:** multi-tab, an installed-tree run, a leak trace (`-d 3 -l log`), a `:0` run. **Citations:** 31 re-derived from their symbols in the touched files and the spec; **owed and named rather than bulk-edited** (a blind `+N` is forbidden) — `PLAN.md` §2's table (explicitly a dated snapshot at 226302f9), `doc/claude/specs/typed_signal_accessors.md:1054`, and ~30 `wave_viewer.tcl:<line>` citations inside `wave_viewer.tcl` and other suites. Offsets: `wave_viewer.tcl` +8 after :591, +8 after :3916, +72 after :4005, +30 after :4142, +25 after :4175; `ase_window.tcl` +72 after :3451.
- **One measurement worth carrying forward:** `info body` COLLAPSES every backslash-newline to a single space. The first restatement of SEL346 (`regexp {rawfile \{\} \\}`) was therefore INERT — green with and without the sabotage — and only a probe printing the body caught it. Two of the round's three evidence defects were the sibling case (a literal that also lives in a comment). Source-shape checks in this tree must be sabotage-proved, never read-proved.
- **Eyeball: none owed, nothing added to `owed.sh`.** The payload is a string in a state file (asserted verbatim, G7/G11b/SEL347/SEL353) and one CIW sentence (asserted verbatim, R6a-R6f/G10). Nothing is drawn, no widget moved, no colour changed; the sentence a human *would* eyeball is the one R604a suppresses on the common path, which is the point of the ruling.
