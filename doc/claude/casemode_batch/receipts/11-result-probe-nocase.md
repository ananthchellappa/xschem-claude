# 11 — `result_probe` reads the SIMULATOR's spelling, not ours

**Casemode batch ITEM 11.** Authority `PLAN.md` §3b item 11 + §F3; `DECISIONS.md` **B4**, **D2**, **A1**.
Base `82b076ea`, branch `fluid-editing`. Pure Tcl — no C, nothing rebuilt, nothing pushed.
Rulings live in `doc/claude/specs/simulator_profiles.md` **§15** (§15.1–§15.8, incl. §15.4b); **§13.6 is corrected in place**.
Untouched by fence: item 12's post-load current repair, item 13's widgets, item 10's three defences, `render_deck`'s deck shape, `0422`, `0423` (still narrowed, not closed).

## 1. Files changed

`git diff --stat` at commit time:

| file | ± | what |
|---|---|---|
| `src/ase.tcl` | **+100 −4** | `ase::backend::ngspice::result_probe`: literal match → two-rung ladder with a D2 decline, a `distinguish` gate, and a delivered-mode veto read out of the log |
| `doc/claude/specs/simulator_profiles.md` | **+245 −0** | new §15 (eight subsections + §15.4b) and the §13.6 correction block |
| `src/ase_window.tcl` | **+14 −6** | the comment that mirrored §13.6's superseded "exactly ONE combination" corrected, and told the truth about the fix's shape |
| `tests/headless/full_audit.sh` | **+1 −1** | `test_ase_result_case` registered in `nogui_tests` |
| NEW `tests/headless/test_ase_result_case.tcl` | 473 lines | 28 checks, band `NC222`–`NC230d` (`PF221an` was the highest id in use; `NC` unused anywhere) |
| NEW this receipt + `audit_item11_closer_2026-08-18.txt` | | receipt and the closer's audit transcript |

## 2. Decisions taken, and the evidence

- **A LADDER, not a `-nocase` flag** (§15.3). Exact spelling first (first line wins, unchanged); a case-insensitive pass second; **decline when the second offers more than one differently-cased label** — D2's rule, the shape item 2's `get_raw_index` and item 5's `resolve_signal_db` already use. Evidence: **I re-ran the naive fix myself** (`-nocase` as a flag on rung 1) and it reddens **10** checks incl. `NC226e` and `NC226` — `v(EN)`'s row taking `v(en) = 1.0`, a wrong number in the Value column.
- **Rung 2 is OFF under `distinguish` — measured, not cautious** (§15.4). Under `-D casemode=distinguish` a card naming a spelling the circuit lacks prints **nothing**, while the case-kept line prints two rows away; a lenient match there attributes that number to a different net. `NC225b` is the positive control (same row+log under `preserve` resolves), so `NC225` pins the gate, not an unmatchable pattern.
- **What the run DELIVERED outranks what it REQUESTED** (§15.4b, added in the fix round after a reviewer produced the run). `~/.spiceinit` overrides `-D casemode=` and items 7/8 arm only on a **non-`fold`** request, so a plain `fold` run against a `distinguish` init file is measured by nobody — and pre-fix it was handed the value of a signal ngspice had **just refused to print**. The log announces the delivery (banner, or `differs only in case`), so the log is read; a false positive costs an empty cell, i.e. the pre-item-11 behaviour, the safe direction. Announced once per log at tag `note`.
- **The collision counts SPELLINGS, not lines** (§15.5). Two analyses print `v(in) = …` twice; rung 1 always took the first, so rung 2 does too. Counting lines would kill every multi-analysis run's values (`NC226c`, `M7`, `M10`).
- **The decline SAYS SO** — one CIW line at tag `error` naming every candidate (`NC226b`, `M11`). Item 14's lesson: a silent decline is the same empty cell this item exists to remove.
- **The KEY is never folded, only the MATCH** (§15.6). A folded key puts a named row's value where `ase::ui::output_result_key` will not look — found and still not displayed (`NC222b`, `M5`).
- **The mode is asked READ-ONLY, once per log** (§15.7): `ase::sim_profile_casemode $state 0` — profile row → floor → `fold`. `::set_sim_defaults` is not a read; it commits an open Simulation Configuration dialog's unsaved edits (`NC229`, `M9`). A stamped profile row outranks the floor (`NC229b`, `M8`).
- **§13.6 CORRECTED, not taken on trust** (§15.2). The dispatch asked for verification and the doc was one combination short: `render_deck` writes an output row's `expr` verbatim and the **only** fold in `ase_window.tcl` is `:956`, inside item 9's `sod_expr` (whole-file grep, one hit). Add/Edit Output, hand-written state files and `expand_bus_outputs` all ship mixed case, so a **plain `fold` run reaches the defect too**. The fix's shape serves both.
- **Reachability of the decline stated, not hidden** (§15.5): with rung 2 off under `distinguish`, and `fold`/`preserve` merging case-variant nets, **no run this tree can produce reaches it today**. Kept as a standing guard, driven synthetically — the alternative is an unguarded `-nocase` that becomes wrong the moment item 8's policy is relaxed.

## 3. Test, checks, verbatim RESULT

`tests/headless/test_ase_result_case.tcl` — true headless (`--nogui`, no Tk). Real-simulator legs **skip, never fail**, when the binary is absent, printing no substring `full_audit.sh` scores a whole file on.

```
RESULT: ALL PASS (28 checks)
```

**MASTER RED, re-measured by me** — test file untouched, `src/ase.tcl` ← its pre-item-11 bytes (`51e69dc5b13bfb26517f845a66041c6e`), restored byte-exact afterwards (`67e7616ba53039765fcd7891d451c8f2`):

```
RESULT: 13 FAILED (15 passed)
```

reds `NC222 NC222b NC222c NC225b NC226b NC226c NC226d NC227b NC227c NC229 NC230b NC230d NC228b`. The fifteen survivors are the unchanged-behaviour controls, `NC228` (the premise), and the two §15.4b checks that assert an EMPTY cell — the old matcher is trivially strict and passes them **for the wrong reason**; mutation `F1` is their real drive. *(An earlier revision of this receipt said `10 FAILED (10 passed)`, which cannot describe a 28-check file; three reviewers and this closer all measure 13/15.)*

**AUDIT — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped, tree frozen for the run.** Transcript `casemode_batch/audit_item11_closer_2026-08-18.txt`:

```
SUMMARY: 328 pass  15 fail  0 crash/timeout  0 skip  (total 343)
WIREEDIT: PASS      SCRATCH: 0 leaked dir(s)      TREE: 0 appeared  0 vanished
```

**Diffed by NAME and STATUS against `audit_item10_closer_2026-08-17.txt` (327/15/0/0 of 342 at `c56581a4`): status changed in EITHER direction — NONE. Rows only in the baseline — NONE. Rows only in mine — `test_ase_result_case` (PASS), this item's own suite.** My 15 reds are the POLICY list **exactly**, no extras and none missing; `test_ase_core`, `test_ase_preflight`, `test_ase_sod_case` and `test_ase_print_bracket_0167` are all PASS. The differ matches only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so within-file `FAIL | key …` detail lines cannot be miscounted, and it was self-checked by diffing the baseline against itself (342 rows, zero changes).

Neighbours, `GUI_GATE=1 run_suites.sh` on `:99`, green at unchanged counts: `test_ase_print_bracket_0167` 12 · `test_sim_run_profile` 38 · `test_ase_preflight` 114 · `test_ase_sod_case` 52 · `test_sim_profiles` 97 · `test_sim_probe` 61 · `test_ase_persist` 109 · `test_ase_interact` 63 · `test_ase_dialogs` 149; `--nogui` arm `test_ase_core` 75 · `test_ase_cosim` 342. **Arm traps, A/B-confirmed on the pre-item-11 file and NOT this item's:** on the *display* arm `test_ase_core`, `test_ase_log_seam_0207` and `test_ase_final` fail identically with or without the change (item 9's receipt records the same two).

## 4. Sabotage — one row per check

Every mutation is one exact literal, applied to a byte-exact backup, run, restored, md5 re-asserted. **Three were re-driven independently by this closer** (marked ✔): the master red, `F1`, and `M4` (the naive `-nocase`).

| check | what was broken | red? | green after restore? |
|---|---|---|---|
| NC222 | `M1` rung 2 deleted (= the pre-fix matcher) ✔ | yes | yes |
| NC222b | `M5` the KEY folded as well as the match | yes | yes |
| NC222c | `M1` rung 2 deleted ✔ | yes | yes |
| NC222d | `M12` the no-match guard removed (records with nothing to record) | yes | yes |
| NC223 | `M13` the label capture group dropped from the pattern | yes | yes |
| NC223b | `M13` capture group dropped | yes | yes |
| NC224 | `M5` the KEY folded as well as the match | yes | yes |
| NC225 | `M3` the `distinguish` gate removed | yes | yes |
| NC225b | `M1` rung 2 deleted ✔ | yes | yes |
| NC225c | `M5` the KEY folded as well as the match | yes | yes |
| NC226 | `M2` the D2 collision guard disarmed | yes | yes |
| NC226b | `M11` the decline downgraded from tag `error` to `note` | yes | yes |
| NC226c | `M7` the collision counts LINES, not distinct spellings | yes | yes |
| NC226d | `M2` the D2 collision guard disarmed | yes | yes |
| NC226e | `F6` **the ladder inverted** — rung 2 first (sole red); also `M4` ✔ | yes | yes |
| NC227 | `M6` the `\W` escape narrowed, so `.` becomes a wildcard | yes | yes |
| NC227b | `M1` rung 2 deleted ✔ | yes | yes |
| NC227c | `M13` capture group dropped | yes | yes |
| **NC228** | **NOTHING — unsabotaged, and NOT evidence about our code.** It asserts the SIMULATOR echoes `v(In)` as `v(in)`: red if ngspice changes, not if `result_probe` does. Declared the item's PREMISE (§15.8); the evidential count is **27 of 28**. | n/a | n/a |
| NC228b | `M1` rung 2 deleted ✔ | yes | yes |
| NC228c | `M3` the `distinguish` gate removed | yes | yes |
| NC228d | `F1` the §15.4b delivered-mode block disabled ✔ | yes | yes |
| NC229 | `M9` the resolve asks with `init 1` — not a read | yes | yes |
| NC229b | `M8` the mode never resolved (pinned `fold`) | yes | yes |
| NC230 | `F1` the §15.4b block disabled ✔ | yes | yes |
| NC230b | `F3` the detector always fires (proves the gate is the DETECTOR's doing, not blanket strictness) | yes | yes |
| NC230c | `F2` the banner tell dropped, only `differs only in case` kept | yes | yes |
| NC230d | `F4` the announcement removed; `F5` (guard dropped) reddens it alone too | yes | yes |

**One edit has no mutation and is declared, not implied:** `full_audit.sh` +1 −1 — the suite emits the identical RESULT line on either arm; the row lands and scores (items 8/9/10 declared the same). Closer's independent drives, verbatim: master red `RESULT: 13 FAILED (15 passed)`; `F1` `RESULT: 4 FAILED (24 passed)` — exactly `NC230 NC230c NC230d NC228d`; `M4` `RESULT: 10 FAILED (18 passed)` — incl. `NC226e`.

## 5. What was NOT verified

- **`NC228` is unsabotageable** (above). No mutation of `src/ase.tcl` can reach it; 19 mutations across two rounds left it green.
- **Raised by the verifier, NOT confirmed by any reviewer, and deliberately NOT changed:** `result_probe`'s blanket `catch {set mode [ase::sim_profile_casemode $state 0]}` falls back to `fold` **mutely**, where item 9's `sod_case_mode` announces a resolver throw at tag `error`. The verifier hunted for a reachable throw (unknown simulator, malformed `sim_profile` dict, index 999, virgin `sim()` array) and found none — every one resolves cleanly and stays strict under a `distinguish` floor. An inconsistency with an item-9 ruling, not a demonstrated defect; item 9's ruling is item 9's to extend. Same for the missing lazy `set_sim_defaults` build, measured safe on a virgin array.
- **Reviewers could not fault the ladder itself.** 17 hand-built adversarial inputs through the real hook produced no wrong number the pre-item-11 matcher would not also produce. The two oddities found — an empty `expr` matching a bare ` = 3.0` line, and `\s*` crossing a newline — are **byte-for-byte pre-existing** in the unchanged rung-1 pattern.
- **`if {$mode eq {}} { set mode fold }` is behaviourally dead** (the only downstream test is `eq {distinguish}`): untested defensive code, not shown to be wrong.
- **The D2 decline is unreachable by any real run today** (§15.5) — driven synthetically only; no reviewer constructed a reaching run, and none tried to relax item 8's policy to manufacture one.
- **`ase::run` is never launched end to end by a check.** `NC228b`/`NC228d` feed real ngspice logs to the real probe, which is the seam this item owns; the run_done → results → pane path is asserted through the pane's own `ase::ui::output_result_key` + `ase::format_value`, never painted.
- **The detector is a string match on the simulator's own wording, and `ver_50` keeps moving.** Both tells were measured today and each is pinned, but a reworded banner *and* warning silently reverts the gate to request-only. The failure is biased safe (empty cell, not a wrong one) and `NC228d` is the canary — it SKIPS rather than failing.
- **Cost is reasoned, then spot-measured by a reviewer**, not by this item's checks: 30 missing rows against a 5.2 MB dump cost 493 ms before / 950 ms after. Real, small, declared.
- **No `owed.sh look` filed — nothing here is pixels.** The payload is a dict and a CIW line, both asserted headlessly. **No eyeball owed.**
- **Issue `0423` untouched** — still narrowed, not closed; closing it needs a schematic-derived re-case pass.
