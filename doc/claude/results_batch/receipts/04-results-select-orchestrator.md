# Item 4 — `results::select`, the ONE place that selects (R302, R303, R801-R805)

## 1. Files changed

| file | lines | what |
|---|---|---|
| `src/results.tcl` | **+542 / −9** | `results::select` + helpers `_engine_spelling` `_same_path` `_resolves_here` `_label` `_emit` `_select_msg` `_r804_msg`, and the persistence seam `results::persist` (documented no-op, item 6 fills it) |
| `tests/headless/test_results_select.tcl` | **+728** | groups AC..AL, **SEL214..SEL294 = 81 new** ids, total **296** |
| `doc/claude/specs/results_selection.md` | +200 / −1 | §5.2 (R302a/d/e/f/g/h, R802a, R804b, R804c), R805b under §10, §12's T-J split note, §18 re-checked |
| `doc/claude/issues/0514-no-tcl-accessor-for-a-raw-schname.md` | new, 101 | filed by this item, OPEN, deliberately unfixed (Tcl-only scope) |
| `doc/claude/issues/status.md`, `results_batch/CREW_BRIEF.md` | +1 / +14 | 0513 → 0514; CREW_BRIEF §3 gains the ad-hoc-drive shim rule (§5) |

**No C.** No rebuild. Scope fence held: `wave_viewer.tcl`, `ase.tcl`, `calculator.tcl`, `xschem.tcl` and every menu untouched — item 4 built the door and converted no caller (R303 is item 5/6/7/10's work).

## 2. Decisions taken, and the evidence

Ten crew rulings, all written into `doc/claude/specs/results_selection.md` (nine in §5.2, R805b under §10). None re-opens `DECISIONS.md`.

- **R302a — one spelling per run, decided by `file normalize`.** Item 3 measured `w/an.raw` and `w/../w/an.raw` producing two slots (engine dedupes by `strcmp`). Two halves: (a) the path handed to the engine is normalised; (b) *first* the registry is asked whether an existing slot's own spelling normalises to the same file, and if so **the engine's spelling is passed**, so the select lands on that slot — without (b) an oddly-spelled slot is permanently unreachable through this door. Pinned SEL237-242; half (b) has its own red (SA1 → SEL241 alone).
- **R302h — a FINAL-COMPONENT symlink is deliberately a second slot.** The fixer round measured that Tcl `file normalize` resolves a link in a *directory* component but **not** in the last one, falsifying R302a's original rationale. Ruled the boundary rather than adding a `readlink` loop: a `latest.raw` link is a moving target the user built on purpose, and resolving it would push the run-specific name into R803's sentence, the MRU and R302g's persistence slot. Cost is one extra slot, which F7 already accepts. Pinned **both ways**: SEL289 (intermediate link converges), SEL290 (final component does not) — SA2 reds SEL289 with SEL290 green, SA3 (ruling reversed) reds SEL290 alone.
- **R302d — the side effects follow the ENGINE, not `ok`.** A non-zero `raw select` changed the current database, so case-mode cache, browser inventory and MRU are owed whether or not the stamp resolves. Only a *refused* select runs none (F7/T-D). Measured with no shim: SEL287 — a `.vcd` select answers `ok 0` and still invalidates.
- **R302e — it does NOT switch context.** The registry is per-`Xschem_ctx`; a bracket here would put an enter/leave pair around the engine call, the window L7 forbids anything to redraw in. `rawbar_load`'s `switch_ctx` stays there, which keeps item 5's re-expression byte-identical.
- **R302f — `ok` is `results::current`'s answer**, with the F4 term conjoined, so verdict and sentence are read off ONE measurement (T-I). Not redundancy: without it the shimmed seam moved the sentence while `ok` stayed 1.
- **R302g — the persistence write is a NAMED SEAM**, `results::persist {path type opts}`, handed the engine's spelling; must not throw. Its header states exactly what item 6 must fill. SEL269-272 pin the call and its arguments, not a write.
- **R802a — the channel is derived and "no channel" is legitimate** (`opts host`; else token → viewer sidebar, ASE key → `ase::echo`; neither → no emission, sentence still in `msg`). A fallback to a global channel was **rejected** — that is what "never the status bar directly" exists to stop. SEL273-279, SEL288, SEL293, SEL294.
- **R804b — the F4 state is measured UNREACHABLE through `xschem raw select`** (`RAW_READ_REBIND` re-stamps on a dedupe hit). Guard KEPT: R111 leaves `raw switch` non-rebinding, `draw.c`'s autoload walk lacks the bit (U10), and it is what makes `ok 1` mean "names resolve here". Driven through the `_resolves_here` seam, with SEL247/248 pinning the seam to `xschem raw loaded` both ways.
- **R804c — the "was read against X" clause needs a caller.** `raw->schname` has **no Tcl accessor** (whole `raw`/`raw_query` arm enumerated; `xschem get raw_level` indexes a different stack in exactly this state). Item 4 is Tcl-only ⇒ **issue 0514 filed, not fixed**. Clause comes from `opts read_against`; without it the sentence keeps R804's load-bearing half (SEL251-253).
- **R805b — compose per OUTCOME**, F4 first, then R102's not-a-result, then stale/invalid/default/ok. Nine outcomes, nine non-empty sentences (SEL286). `switch` is deliberately not used to dispatch on the status, because one status is spelled `default`.

**§18 re-checked: UNCHANGED.** Item 4 added no bypass and removed none; the two that could have moved and did not are named in the spec (R302e keeps `rawbar_load`'s `switch_ctx`; R302g leaves `viewer.rawfile` unwritten).

## 3. Checks and result

`tests/headless/test_results_select.tcl`, groups AC..AL. **81 new ids SEL214-SEL294, 296 total.** Band measured free at 213; nothing renumbered.

```
PASS     | test_results_select          run 1/8  RESULT: ALL PASS (296 checks)
PASS     | test_raw_read_dispatch       run 2/8  RESULT: ALL PASS (51 checks)
PASS     | test_wave_viewer             run 3/8  RESULT: ALL PASS (400 checks)
PASS     | test_wave_sigbrowser         run 4/8  RESULT: ALL PASS (353 checks)
PASS     | test_wave_cursor_crossdb     run 5/8  RESULT: ALL PASS (93 checks)
PASS     | test_raw_case_mode           run 6/8  RESULT: ALL PASS (277 checks)
PASS     | test_calc_skeleton           run 7/8  RESULT: ALL PASS (503 checks)
PASS     | test_ase_persist             run 8/8  RESULT: ALL PASS (109 checks)
RESULT: 8/8 runs passed
```
`--nogui` arm: `RESULT: ALL PASS (296 checks)`.

**Audit — a DIFF, not a count.** `GUI_GATE=1 tests/headless/full_audit.sh`, dev display `:99`:

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
**0 green→red and 0 red→green across all 346 shared rows; nothing only in the baseline.** The single extra row is `test_results_select` PASS, which `LEDGER.md` records as added by item 1 and the brief names as a legitimate extra. The 15 reds are the baseline's 15 **by name**: `test_ase_window`, `test_cadence_drag`, `test_ciw`, `test_gf180mcud_libmgr`, `test_ihp_sg13g2_libmgr`, `test_lib_manager_gui`, `test_lib_manager_locate`, `test_lib_sweep`, `test_reopen_readonly`, `test_rotate_stretch_short_0104`, `test_selflog_output`, `test_sky130a_libmgr`, `test_wave_markers`, `test_wave_sigbrowser_0312`, `test_wave_sigbrowser_keys`. Counting note: a naive `grep -cE '^FAIL'` answers more, because within-file detail is spelled `FAIL     | key …`; the join anchors on `test_\S+`, which is what makes the row counts 346/347. Suite block, `--nogui` arm and audit all re-taken by the closer on the current tree (`md5sum src/results.tcl` `bf565ec6…`), not inherited.

**The four mandated invariants.** T-D (AE, SEL226-236): three refusal shapes, three routes out, three distinct sentences, registry + `raw rawfile` + `raw list` unchanged in all three, `did` empty. T-G (AG, SEL243-246): a strip carrying `aslot;v(n1)%<an.raw> tran`, select `bn.raw`, cursor B at 5 ns — the `%`-addressed database interpolates **its own** 1.5 while the selected one answers −1 to `raw index v(n1)`. **T-J — SELECT-REFUSAL HALF ONLY** (SEL230/231/279/288): the F6 **borrow** half is not this item's and is reassigned (§5). T-M (AH, SEL247-260, SEL287): seam pinned both ways, R804's sentence in both forms, the R102 case with no shim, `ok` ⟺ `results::current` from both ends.

## 4. Sabotage

Break, run, record reds, restore from a byte-exact backup (`md5sum`/`cmp`; never `git checkout --`, the item is uncommitted), re-run green. **All 41 drives restored green.** Every one of the 81 new ids has a red below.

| drive | what was broken | went red | restored green |
|---|---|---|---|
| PRE | `results.tcl` at its byte-exact item-3 state (no `results::select`) | SEL214-236, 239-249 (34) then abort | ✔ |
| SC1 *(C)* | `save.c:2400` `raw_select()` always refuses; `make` | SEL237 (+ item 3's band) | ✔ rebuilt, `git diff src/save.c` empty |
| S29 / SC2 *(C)* | fixture's two spellings collapsed / `realpath()` in `raw_select()`, `make` | SEL238 / SEL238+241 | ✔ |
| S2 | `_engine_spelling` returns the path unchanged | 239,240,241,242,270 | ✔ |
| S3 / SA1 | half (b) only: normalise, never ask the registry | **241 alone** (reproduced twice) | ✔ |
| SA2 | `_engine_spelling` → `return $p` | 239,240,241,242,**289**,270 (290 green) | ✔ |
| SA3 | a `file readlink` loop added — **R302h reversed** | **290 alone** | ✔ |
| **S4** | **the named sabotage — `ok` set unconditionally** | **250**,257,258,259,287 | ✔ |
| S5 / S19 | `$lv >= 0` dropped from `ok` / F4 bails instead of reporting | 250 / 250-254,286 | ✔ |
| S6 / S6b | seam always answers 0 / always −1 | 248 / 218,221,224,225,239-241,243,245,247,249,255,258,260-262,265,281-286 | ✔ |
| S7 / S8 / S9 | R804 clause dropped / `read_against` ignored / one sentence for every outcome | 251-253 / 252 / 251,252,253,258,282,284,285,286 | ✔ |
| S10 / S11 | no MRU push (0216 unfixed) / list appended directly, bypassing 0119's gate | 262,263 / **261** | ✔ |
| S12 / S13 / S14 | case-mode never invalidated / never re-applied / browser refreshed without `reload` | 264,287 / 265 / 267 | ✔ |
| S15 / SA4 / SA5 | side effects before the engine's answer / `browser_refresh` ahead of `casemode_invalidate` / **sentence emitted before the side effects** | 262,267,270 / **291 alone** / **292 alone** | ✔ |
| S16 / S17 / S17b | persist never called / handed the caller's spelling / stub claims it wrote | 270,271 / 270 / 269 | ✔ |
| S18 / S18b | engine-refusal arm runs the side effects / resolver-refusal arm does | 233 / 228,263,268,272 | ✔ |
| S20 / S20-redrive | `catch {xschem raw clear}` before the verb (L8) | 256,258,287 / 10 incl. **246** `got 'read 1 0' want 'read 1 1'` | ✔ |
| S21 / S26 | `$token ne {}` guard dropped / a key added to the returned dict | 266 / 223 | ✔ |
| S22 / S23 / S24 | all messages forced to `ase` / nothing emitted / `host none` falls back | 274,275,277,278 / 273-276,279 / 277,278 | ✔ |
| S25 | engine-refusal arm returns before it emits | **288 alone** | ✔ |
| SA6 / SA7 | `puts` fallback in `_emit`'s viewer arm / a **runtime-only** fallback evading the source grep | **293 alone** / 277,278,**294** (293 green) | ✔ |
| S27 / SA8c / SA9 / SA10 *(test-side)* | a shim restore dropped (`browser_status` / `::puts` / `persist` / `browser_refresh`) | 280 / **280 alone** / 273-278,280 / 275,277,280 | ✔ |
| S28 *(test-side)* | `_resolves_here` seam not put back | 255,258,260,261,262,265,281-286 | ✔ |
| — *(doc)* | four stale SEL citations + three stale `scheduler.c:10448` pointers in `src/results.tcl`; spec §5.2 count/order; T-J note | **no red — comments only** | drive is the grep in each row, re-run here: `sed -n 10494p src/scheduler.c` is the `"loaded"` handler; SEL216/217 = AC-signature/arity, SEL219/220/222/225 = group AD |

**Unsabotaged, i.e. not evidence.** *(a)* the doc row above (comment-only; `diff` of the comment-stripped file before/after the fixer round is empty, so no existing check's subject moved); *(b)* the `if {$sim_type eq {}}` branch — `raw_select()` does `if(type && !type[0]) type = NULL;`, so an empty positional is observably identical to none and no check can tell them apart (kept as L6 defence); *(c)* `results::_same_path` — reachable only where `results::current` and `raw rawfile` are the same slot by construction. Two checks were caught **weak by sabotage and strengthened**: SEL280 (`info procs` was satisfied by the shim → now compares `info body` for all 8 shims) and SEL246/222/229/232/235/245 (vacuous under the pre-feature drive → now carry their positive term in the same assertion).

## 5. What was NOT verified

- **Raised but NOT confirmed: none.** All thirteen confirmed review findings were reproduced before being fixed; the review returned an empty not-confirmed list. Two were fixed as **documentation only, deliberately** — T-J's borrow half (R302e is right; the *coverage claim* was wrong) and the stale citations.
- **T-J's F6 borrow half is not delivered.** `grep -n 'borrow\|enter_ctx\|leave_ctx'` over `src/results.tcl` and the suite returns nothing, by design. Reassigned in **spec §12 under the invariant table** to item 5 (R501 left `switch_ctx` in `rawbar_load`) and item 10 (R502/T-I); neither may mark T-J done on item 4's four checks.
- **Reviewer-marked not-proven, carried forward:** no live viewer window, no live ASE session, no Calculator, no multi-tab probe, no installed-tree run, no leak trace (`-d 3 -l log`), no `:0` run. `browser_refresh`/`browser_status`/`ase::echo`/`calc::status` are proved by **shim** — routing yes, delivery no. `casemode_invalidate`/`reapply` are proved by their real effect on the real arrays. L5/L7 were read, not test-forced. `results::persist` writes nothing (item 6). No on-disk MRU round-trip (that is `test_wave_viewer`'s).
- **A reviewer's open question, not ruled here:** a **typeless** select of a VCD or table refuses, because the no-type arm reaches the C reader as `<unspecified>` — so a non-spice database that reaches the MRU can never be re-selected through R303's door. Not called a bug; item 7's dialog is the first caller that can hit it and should rule it.
- **The user's `~/.xschem/raw_history` content is gone.** An **ad-hoc** verification drive (not the suite — group AJ shims the writer *before* setting the flag) set `::update_recent_files` without shimming `wviewer::rawhist_write`, and the real writer truncated the file. There is no `.bak`. The file now holds an honest empty list, the leak is preserved at `scratchpad/fix/raw_history.leaked`, and the durable guard is CREW_BRIEF §3's new rule, not a check.
- **Concurrency during review is real and is not fixed here** — files were rewritten mid-measurement in the implementation round, which is why every fixer-round drive records an md5 before and after. Batch-orchestration matter for the driver.
- **Eyeball: none owed.** The payload is a Tcl proc, a returned dict and a routing table; every sentence is asserted verbatim (SEL221/231/234/251/252/258/284/285). Nothing is drawn. Items 5, 6, 7 and 10 own the eyeballs for what a human will actually see. Nothing added to `owed.sh`.
