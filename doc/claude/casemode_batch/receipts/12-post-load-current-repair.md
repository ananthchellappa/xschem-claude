# 12 — the database's own spelling repairs a constructed current

**Casemode batch ITEM 12** (PLAN §3b item 12 / §D6 part 2). Base `347f8968`, `fluid-editing`. Pure Tcl. Rulings in `doc/claude/specs/simulator_profiles.md` **§16** (§16.1–§16.11); **§13.6 corrected in place** by §16.4. A **fix round** answered seven confirmed review findings; the seven defects, both sabotage tables in full and the first cut's own record live in `receipts/12-post-load-current-repair-annex.md`. Fences honoured: item 13's widgets/`simconf`, item 15's docs, `render_deck` untouched (no vector named on any `write` line), `0502` and `0503` not touched (`0503` still **narrowed** — §16.9 argues why a database-derived pass cannot close a schematic-derived issue).

## 1. Files changed

| file | ± | what |
|---|---|---|
| `src/wave_viewer.tcl` | **+202 −0** | six purely additive procs — `is_current_ref`, `name_fold_candidates`, `prepare_slots`, `repair_current_token`, `repair_current_expr` (pure) and `repair_currents` (one inventory read per batch). **No existing proc touched.** |
| `src/ase_window.tcl` | **+136 −2** | `ase::ui::repair_currents` (announcement + the two caller contracts), `ase::ui::dedupe_plot_queue`, and the two post-attach seams: `dp_finish` (gated on `attach_raw`'s own return) and `auto_plot` (after `plot_map_expr`, before `add_trace`) |
| `doc/claude/specs/simulator_profiles.md` | **+403 −0** | §16.1–§16.11, including §16.4's in-place correction of §13.6 |
| NEW `tests/headless/test_ase_current_repair.tcl` | 701 lines | **56 checks** on a display, **53** `--nogui`; band `CU231`–`CU243c` (`NC230` was the highest id in use; `CU` was unused) |
| `tests/headless/full_audit.sh` | **untouched** | the first cut registered the file in `nogui_tests`; the fix round reverted that, so the audit runs it on the display arm with all 56 |

## 2. Decisions, and the evidence for each

- **The narrowing was verified, not inherited — and item 9's construction model is RIGHT** (§16.2). On `build-ver_50`, `.subckt Blk` holding `Vs` and VCVS `E1` in `X1`: `fold` → `i(v.x1.vs) i(e.x1.e1) i(v1)`; `preserve`/`distinguish` → `i(V.X1.Vs) i(E.X1.E1) i(V1)` — byte for byte what `sod_qualify`+`sod_expr` compose. **On a correctly-picked expression the repair is needed never.** That is the "measure how much less" the dispatch asked for; it is why this item is a guard and not a rescue.
- **§13.6 was one producer short, exactly as it was for item 11** (§16.4). A current also arrives verbatim from `output_editor_ok`, a hand-written state file and `expand_bus_outputs`, and `plot_map_expr` buries one inside the RPN `i(v1) -1 *`. Hence the repair is **token-wise**, and `auto_plot` maps *before* it repairs (`CU234b`, `CU239b`; `M19`). §13.6 carries the correction in place.
- **The real gate is `Raw.case_sensitive`, and it is a theorem** (§16.3). `-case distinguish` → `raw index i(v.x1.vs)` = −1 while `i(V.X1.Vs)` = 4; under `preserve`/`fold` item 2's folded rung answers every case-only mismatch, so "unmatched" and "matchable case-insensitively" are **disjoint** and this code cannot fire (`CU232d`, `CU236f`). One exception, now covered: a folding DB whose fold key is D2-poisoned (`CU233f`).
- **Reachability is stated, not overstated** (§16.3, corrected by the fix round). Nothing in ASE-L passes `-case`; `grep -n 'raw read .*-case\|raw case 1' src/*.tcl` finds **no** shipped caller, `rawbar_load` reads bare, and the viewer's Case Mode control is item 3's reporting-only `xschem raw casemode`. **Unreachable from every gesture a user can make today**; the one live route is a script/console `xschem raw case 1` followed by `dp_finish`/`auto_plot`. A **standing guard**, in item 11 §15.5's shape, that item 13 turns live.
- **It is not a second lookup ladder** (§16.5). The candidate scan runs over `wviewer::name_rungs`, so item 2's `i(v.x`→`i(x` rung is honoured, not re-implemented (`CU235`, `M6`); `CU235b` is the agreement leg against `resolve_signal_db`. The rule is re-applied **inline** rather than by calling that proc — calling it would cost one `signal_list_all` per token, which `CU242` forbids — and §16.5 and the file header now say so, after saying the opposite (finding 7).
- **D2 governs the rewrite and counts SPELLINGS, not slots or occurrences** (§16.6). One differently-cased spelling repairs; two decline at `error` naming every candidate (`CU233`, `CU233c`, `CU240`); one name in two databases is one answer (`CU233d`, `M8`). **In memory; the session is NEVER rewritten** (§16.7) — D1's precedent and item 10's explicit `ase::preflight_fix_session`. The row's `expr` and the state file keep the user's text, nothing is marked dirty (`CU241c`), and the next load repairs and announces again.
- **Currents only, by argument not by fence** (§16.1): a voltage is *resolved* by `xschem resolved_net`, so there is nothing constructed to be wrong about (`CU231c`, `M1`). The predicate was **widened** to ngspice's `savecurrents` form `@m.x1.m0[id]` because `ase::ui::output_kind` in the same feature already calls that a current — two predicates disagreeing was finding 3 (`CU231d`, `CU232f`). **Announced once per offender, in both directions** (§16.8): repair at `note`, D2 decline at `error` worded "names in it match case-insensitively" (the old "differ only in case" was false for a rung-reached candidate — finding 6, `CU240d`); a `none` token says nothing here (`CU240c`); notes folded on `{status old new}` so N rows citing one offender give one line (`CU240e`).
- **One inventory read per batch, one name index per slot per batch, never from a redraw** (§16.8). Item 3 measured 147–189 ms uncached nearby. `CU242` counts inventory reads; the per-token `name_index` rebuild it was blind to (finding 2) cost **581.2 ms** on 30 expressions over 10001 names and is hoisted into `prepare_slots` — re-measured **450.9 ms → 17.7 ms**, verdicts byte-identical (`CU242f`).
- **The repair may collapse two queue entries into one string** (§16.11, finding 5), so `dp_finish` re-dedupes afterwards and filters `qcolors` in lockstep, keeping `dp_queue`'s contract and issue `0153`'s one-colour-per-signal invariant (`CU238f`, `CU238g`).
- **"Post-load" means after an attach actually happened** (§16.10, finding 1). `dp_finish`'s no-run branch attaches nothing, and the first cut repaired there against whatever raw the viewer already held; the call is now gated on `attach_raw`'s own return value (`CU238e`). **Two caller contracts are checked, not trusted**: the answer's length, since `dp_finish` pairs it with `qcolors` positionally (`CU241`, `M15`), and a throw (`CU241b`, `M16`).

## 3. Test, check count, verbatim RESULT

`tests/headless/test_ase_current_repair.tcl` — **56 checks** (53 `--nogui`; the three `CU243*` legs need a real viewer and stand down without one, and the real-simulator leg **skips, never fails**, printing no substring `full_audit.sh` scores a file on).

```
RESULT: ALL PASS (56 checks)      display arm :99 — the arm the audit uses
RESULT: ALL PASS (53 checks)      --nogui
```

**MASTER RED** — test file kept, both sources ← their pre-item bytes, restored byte-exact after (`src/wave_viewer.tcl` `47950d02…`, `src/ase_window.tcl` `0df4d6ce…` are the delivered bytes):

```
RESULT: 45 FAILED (8 passed)      (the first cut's was 36 FAILED / 7 passed of 43)
```

Neighbours, `GUI_GATE=1 run_suites.sh` on `:99`, all green at unchanged counts: `test_ase_plot` 150 · `test_ase_sod_case` 52 · `test_ase_result_case` 28 · `test_ase_preflight` 114 · `test_ase_interact` 63 · `test_ase_dialogs` 149 · `test_wave_casemode` 134 · `test_wave_viewer` 400 · `test_ase_cosim` 342 · `test_wave_crossdb_trace` 130 · `test_wave_modes` 488 · `test_wave_clear_all` 75 · `test_sod_pick_no_select_0204` 66 · `test_cmdmode_descend_0201` · `test_ase_hier_plot_0168` 31 · `test_wave_tabs` 172 · `test_wave_split_strip` 221 · `test_wave_grid` 399 · `test_wave_sigsearch` 233 · `test_wave_sigbrowser_sea` 79 · `test_wave_sigbrowser_i14` 109 · `test_wave_sigbrowser_i1315` 191 · `test_wave_sigbrowser_digital` 82 · `test_backannotate_digital` 81.

**AUDIT (a diff, not a count).** `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped. Transcript `casemode_batch/audit_item12_closer_2026-08-18.txt`. `SUMMARY: 329 pass  15 fail  0 crash/timeout  0 skip  (total 344)`. Diffed by NAME and STATUS against `audit_item11_closer_2026-08-18.txt` (328/15/0/0 of 343 at `1d217632`): **status changed in either direction — NONE. Rows only in the baseline — NONE. Rows only in mine — `test_ase_current_repair` (PASS)**, this item's own suite. The 15 reds are the POLICY list exactly. The differ matches only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so within-file `FAIL | key …` lines cannot be miscounted, and it was self-checked by diffing the baseline against itself (343 rows, zero changes).

## 4. Sabotage — one row per check

One exact literal each (`M21` is a relocation of one call), applied to a byte-exact backup, run, restored, md5 re-asserted, re-run green. `M*` = first cut, `N*` = fix round; the full tables with file/line are in the annex §B and §C.

| check | what was broken | red? | green after restore? |
|---|---|---|---|
| CU231 | `M2` `is_current_ref` always FALSE | yes | yes |
| CU231b | `N2` `@.+`→`@.*` (a bare `@` reads as a current); `M1` | yes | yes |
| CU231c | `M1` predicate always TRUE — a mis-cased voltage gets repaired | yes | yes |
| CU231d | `N1` the `@` alternative dropped from the predicate | yes | yes |
| CU232 | `M2`; independently `M5`/`N13` per-slot `case` flag pinned fuzzy | yes | yes |
| CU232b | `M2`, `M5` (non-`v` prefix `E1` variant) | yes | yes |
| CU232c | `M2`, `M5` (flat top-level variant) | yes | yes |
| CU232d | `M4` the already-resolves rung removed | yes | yes |
| CU232e | `M2` a `none` verdict returned as `keep` | yes | yes |
| CU232f | `N1`; independently `N13`, `N14` (the `@` form repairs) | yes | yes |
| CU233 | `M3` the D2 collision guard removed — it guesses | yes | yes |
| CU233b | `M2` a near miss no longer reported as `none` | yes | yes |
| CU233c | `M3`; independently `M2` | yes | yes |
| CU233d | `M8` the cross-slot distinct-**spelling** dedupe removed | yes (alone) | yes |
| CU233e | `M3`; independently `M2`, `M5` | yes | yes |
| CU233f | `N3` a `case 0` slot contributes no candidates (theorem's exception) | yes (alone) | yes |
| CU234 | `M7` the byte-identity passthrough removed | yes (alone) | yes |
| CU234b | `M2`+`M5`; whole-expression instead of token-wise misses the RPN | yes | yes |
| CU234c | `M1`+`M2`+`M5` | yes | yes |
| CU234d | `M3`+`M2` the notes drop the candidate list | yes | yes |
| CU235 | `M6` the candidate scan stops using `name_rungs` | yes (alone) | yes |
| CU235b | `M4`; independently `M2`, `M5` (agreement with `resolve_signal_db`) | yes | yes |
| CU236 | **NOTHING — declared premise** (the committed fixture exists) | n/a | n/a |
| CU236b | **NOTHING — declared premise** (`-case distinguish` ⇒ `raw case` 1) | n/a | n/a |
| CU236c | **NOTHING — declared premise** (the engine then MISSES `i(vs)`) | n/a | n/a |
| CU236d | `M2`; independently `M5` (real engine leg) | yes | yes |
| CU236e | `M2`, `M5` — the answer no longer resolves in `raw index` | yes | yes |
| CU236f | `M4` — a folding read is no longer kept (the theorem) | yes (alone) | yes |
| CU237 | `M2`; independently `M5` (real `build-ver_50` raw) | yes | yes |
| CU237b | `M2`, `M5` | yes | yes |
| CU238 | `N12` the `dp_finish` call deleted; `M21` the call relocated **above** `attach_raw` | yes | yes |
| CU238b | `N16`(=`M32`) `dp_finish` hands `{}` to `plot_signals` | yes | yes |
| CU238c | `M13` the `note` echo deleted; independently `N9`, `N12`, `N15` | yes | yes |
| CU238d | `M1`; independently `M4` (a voltage is left alone) | yes | yes |
| CU238e | `N4` the `if {$attached}` gate defeated — repairs with 0 attaches | yes (alone) | yes |
| CU238f | `N5` the post-repair `dedupe_plot_queue` call deleted | yes (alone) | yes |
| CU238g | `N6` `set paired 1` — a non-positional colour list filtered too | yes (alone) | yes |
| CU239 | `M12` `auto_plot` does not repair; `M19` it repairs **before** `plot_map_expr` | yes | yes |
| CU239b | `M13`; independently `M12`, `M19` | yes | yes |
| CU240 | `M14` the D2-decline `error` echo deleted | yes (alone) | yes |
| CU240b | `M3` — the declined expression is silently guessed | yes | yes |
| CU240c | `M17` a `none` token announced too | yes | yes |
| CU240d | `N7` the old "differ from it only in case" wording restored | yes (alone) | yes |
| CU240e | `N8` the per-offender note dedupe removed | yes (alone) | yes |
| CU241 | `M15` the list-length contract check deleted | yes (alone) | yes |
| CU241b | `M16` the `catch` around the resolver removed | yes (alone) | yes |
| CU241c | `M12`; independently `N9`, `N15` (second half only — see §5) | yes | yes |
| CU242 | `M9` the inventory read moved inside the per-expression loop | yes (alone) | yes |
| CU242b | `M22` the empty-batch short circuit deleted | yes (alone) | yes |
| CU242c | `M10` the `catch` around `signal_list_all` removed | yes (alone) | yes |
| CU242d | `M23` the no-database short circuit deleted | yes (alone) | yes |
| CU242e | `N9` `signal_list_all {}` instead of `$token` — the no-op mutation | yes | yes |
| CU242f | `N10` the `prepare_slots` hoist removed (index rebuilt per token) | yes (alone) | yes |
| CU243 | **NOTHING — declared premise** (shipped `signal_list_all` gives `case 1`) | n/a | n/a |
| CU243b | `N9d` the same `signal_list_all {}`, on the **display** arm | yes | yes |
| CU243c | `N11` asks the FIRST registered window, not the caller's token | yes | yes |

`N13`(=`M5`) and `N14`(=`M30`) were re-run after the fixes to prove nothing was disarmed: blast radius **grew**, 19→24 and 16→20, and shrank for none. **Four checks are unsabotageable declared premises and are NOT evidence about this item's code** — `CU236`, `CU236b`, `CU236c`, `CU243`; they go red if item 1/2/5's code changes and never if this item's does. **Evidential count 52 of 56.** No file in this item is left without a mutation: the first cut's one exception (the `full_audit.sh` registration) was reverted.

## 5. What was NOT verified

- **No reviewer finding was raised-but-unconfirmed** — all seven confirmed findings were accepted as real and fixed; nothing was changed to appease an unconfirmed one. **But not re-shot by every stage.** Reviewer 3 diffed the audit transcript as a document rather than re-running it (this closer's run above is the fresh one). Spec §16.2's three-mode `build-ver_50` measurement was reproduced by the verifier but by no reviewer; the MASTER RED count and 21 of the 23 first-cut sabotage rows were likewise taken from the verifier's table on one re-run data point (`M8`).
- **`CU241c`'s D1 half is structurally undrivable** — item 12's code never touches session state, so "the session is not rewritten" is asserted by construction; only its second half (the repair reached `add_trace`) has a mutation.
- **Nothing repairs a trace already in the viewer's model** — a restored layout, or a trace added before the first run, keeps its stored spelling. This acts on expressions **on their way in**, at the two ASE-L seams only; `wviewer::rawbar_load` is untouched.
- **The `i(v.x` anchor gap is named, not widened** (§16.5): a database dropping the branch prefix for a non-`v` device (`i(x1.e1)` vs a constructed `i(E.X1.E1)`) is repaired by nothing — item 2's rung to widen.
- **Two costs remain named and unfixed** (§16.9): the inventory is read even when no token in the batch is a current (a pre-scan would be a second place deciding what a current is — finding 3's exact cost), and `signal_list_all` is called without its `statusVar`, so issue `0314`'s REFUSED-vs-empty conflation is present. Benign — no repair, no announcement, expressions untouched — and no reviewer could produce a wrong output from it, so it is recorded rather than filed.
- **No counter-example search was exhaustive.** No reviewer could make the repair write a *wrong* spelling across every slot combination tried, and the §16.3 theorem held under every input thrown at it, but no proof over the whole rung set was attempted. A repaired expression's whitespace is normalised (`"i(v.x1.vs)\t-1   *"` → `"i(V.X1.Vs) -1 *"`); reasoned harmless because `validate_rpn` splits on whitespace too, not guarded.
- **Issue `0503` stays narrowed, not closed** — it needs a *schematic*-derived re-case pass; this one is *database*-derived and cannot re-case a row for a signal the run never wrote. **No eyeball is owed.** The payload is a list of strings handed to `plot_signals`/`add_trace` plus two CIW lines, all asserted byte for byte; no check loads Tk. `owed.sh` untouched (4 suite / 11 look, unchanged).
