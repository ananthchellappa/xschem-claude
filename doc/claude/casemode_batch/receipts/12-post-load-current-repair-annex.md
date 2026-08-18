# 12 — ANNEX: the fix round's sabotage table, and the seven defects it answers

Companion to `receipts/12-post-load-current-repair.md`. Everything here is the
**fix round** (2026-08-18), run by the FIXER against the first cut's delivered
bytes (`src/wave_viewer.tcl` `7b53a5a9…`, `src/ase_window.tcl` `b70f9af7…`).

## A. The seven confirmed findings, and what each one cost

| # | finding | severity | fix |
|---|---|---|---|
| 1 | `dp_finish` ran the "post-load" repair on the explicit **NO-RUN** path, where `attach_raw` was never called — so a queued current was rewritten to a spelling harvested from whatever unrelated raw the viewer already held, while the notice one line above promised it would "resolve after the run". Measured: **0 attaches, queue rewritten anyway.** | major | the repair is gated on `wviewer::attach_raw`'s **own return value** (§16.10, `CU238e`) |
| 2 | `repair_current_token` rebuilt `wviewer::name_index` for **every (token, slot) pair** — O(tokens × names), against `name_index`'s own documented "built ONCE per name list" contract. Measured: 219.9 ms for 40 exprs × 2 slots × 2001 names; **581.2 ms** for 30 exprs over 10001 names, every token answering `keep`, all of it waste, on the shipped folding path where §16.3 proves the repair cannot fire. `CU242` counts inventory reads and is blind to it. | major | `wviewer::prepare_slots` builds one index per slot per batch under the key **`nameidx`**; `repair_current_token` keeps its signature and builds its own only for a caller passing raw slots (§16.8, `CU242f`). Re-measured after the fix, both shapes in one process on one 10001-name slot: **450.9 ms → 17.7 ms** for 30 expressions, every verdict unchanged |
| 3 | `is_current_ref` matched `i(...)` only, so ngspice's `.options savecurrents` form `@m.x1.m0[id]` — which `ase::ui::output_kind` in the **same feature** calls a `current` (verified: it matches `i(*` **or** `@*`) — was silently skipped. Two predicates in one feature disagreeing about what a current is. | minor | predicate widened to `^(i\(.+\)|@.+)$` (§16.1, `CU231d`, `CU232f`) |
| 4 | one CIW line per token **occurrence**, so one mis-cased current used by N rows produced N byte-identical lines — the noise the proc's own comment cites item 10's per-offender rule against. | minor | notes folded onto `{status old new}` before the echo loop (§16.8, `CU240e`) |
| 5 | the repair can rewrite two distinct queue entries into the **same string**, defeating `dp_queue`'s exact-string dedupe: `plot_signals` plots the same data twice at two different `qcolors`, so one of issue `0153`'s schematic net cues can never match its trace. | minor | `ase::ui::dedupe_plot_queue`, applied in `dp_finish` only, filtering `qcolors` **in lockstep** (§16.11, `CU238f`, `CU238g`) |
| 6 | the D2 decline always said the candidates "differ from it only in case", but a candidate reached through item 2's `i(v.x` → `i(x` rung differs by the whole dropped branch prefix (`i(X1.Vs)` for a query of `i(V.X1.VS)`). | minor | reworded to "… names in it match case-insensitively …" (§16.8, `CU240d`) |
| 7 | §16.5 and the `wave_viewer.tcl` header both said the repair "asks `wviewer::resolve_signal_db` … for that verdict"; the code **re-implements its loop body inline**. In a batch whose banner is *one lookup authority*, the prose hid a second copy of that loop. | minor | both corrected in place: the RULE is re-applied inline, the reason is one `signal_list_all` per token, and **`CU235b` is named as the only thing holding the two copies together** (§16.5) |

Two further review findings were about the SUITE, not the code, and are fixed
the same way:

- **the one impure call had no coverage.** `wviewer::signal_list_all` was stubbed
  with a **token-ignoring** proc in every check, so `signal_list_all {}` in place
  of `signal_list_all $token` — a one-word mutation that makes the feature a
  permanent no-op for every user — left the suite at ALL PASS. Fixed twice over:
  the stub now mirrors the real proc's own first line
  (`if {![dict exists $windows $token]} { return {} }`), and `CU243`–`CU243c`
  drive the **real** proc through a real viewer window on a real
  `-case distinguish` database. The file is therefore **out of `nogui_tests`**
  (that `full_audit.sh` edit is reverted; the file is now untouched by this item)
  so the audit runs it on the display arm, where all 56 checks run.
- **the theorem's one exception had no coverage.** §16.3 cited `CU233c` for a
  D2-poisoned **folding** database; `CU233c`'s slot is `case 1`. `CU233f` is the
  real shape, and the mutation that motivated it (`continue` on every `case 0`
  slot) now reddens exactly that one check.

## B. Sabotage — one row per new or changed check

Driver: `sab.py` — apply one exact literal to the fixed bytes, run, restore from
the byte-exact snapshot, assert the md5, re-run and require ALL PASS. Every row
below did that; the "restored green" column is a real re-run, not an assumption.

| mutation | file:what | red checks | restored |
|---|---|---|---|
| **N1** | `wave_viewer.tcl` — `is_current_ref`'s `@` alternative dropped | `CU231d` `CU232f` | ALL PASS 53 |
| **N2** | `wave_viewer.tcl` — `@.+` → `@.*`, so a bare `@` reads as a current | `CU231b` | ALL PASS 53 |
| **N3** | `wave_viewer.tcl` — `continue` on every `case 0` slot (a folding DB contributes no candidates) | `CU233f` | ALL PASS 53 |
| **N4** | `ase_window.tcl` — the `if {$attached}` gate defeated (`if {1}`) | `CU238e` | ALL PASS 53 |
| **N5** | `ase_window.tcl` — the post-repair `dedupe_plot_queue` call deleted | `CU238f` | ALL PASS 53 |
| **N6** | `ase_window.tcl` — `set paired 1`: a non-positional colour list filtered too | `CU238g` | ALL PASS 53 |
| **N7** | `ase_window.tcl` — the decline's old "differ from it only in case" wording restored | `CU240d` | ALL PASS 53 |
| **N8** | `ase_window.tcl` — the per-offender note dedupe removed | `CU240e` | ALL PASS 53 |
| **N9** | `wave_viewer.tcl` — `signal_list_all {}` instead of `signal_list_all $token` (**the mutation that used to leave 43/43 green**) | `CU238` `CU238c` `CU238f` `CU239` `CU239b` `CU240` `CU240d` `CU240e` `CU241c` `CU242e` `CU242f` | ALL PASS 53 |
| **N9d** | the same, on the **display** arm | the eleven above **+ `CU243b`** | ALL PASS 56 |
| **N11** | `wave_viewer.tcl` — asks the FIRST registered window instead of the caller's token (display arm) | the same eleven **+ `CU243c`** | ALL PASS 56 |
| **N10** | `wave_viewer.tcl` — the `prepare_slots` hoist removed (index rebuilt per token) | `CU242f` | ALL PASS 53 |
| **N15** | `wave_viewer.tcl` — `prepare_slots` stashes an index built over **no** names | `CU238` `CU238c` `CU238f` `CU239` `CU239b` `CU240` `CU240d` `CU240e` `CU241c` `CU242e` | ALL PASS 53 |
| **N12** | `ase_window.tcl` — the `dp_finish` repair call deleted | `CU238` `CU238c` `CU238f` | ALL PASS 53 |
| **N16** (=`M32`) | `ase_window.tcl` — `dp_finish` hands `{}` to `plot_signals` instead of `$qcolors` | `CU238b` `CU238f` | ALL PASS 53 |
| **N13** (=`M5`) | `wave_viewer.tcl` — the per-slot `case` flag pinned fuzzy | 24 checks incl. `CU232*` `CU235*` `CU236d`–`f` `CU237*` `CU242e` | ALL PASS 53 |
| **N14** (=`M30`) | `wave_viewer.tcl` — a repair returns the ORIGINAL token, not the DB spelling | 20 checks | ALL PASS 53 |

`N13`/`N14` are the first cut's two load-bearing mutations, re-run to prove the
fixes **disarmed nothing**: their blast radius grew (19→24 and 16→20) with the
new checks and shrank for none.

**MASTER RED** (test file kept, both sources ← their pre-item bytes
`c23ff099…` / `25737084…`): `RESULT: 45 FAILED (8 passed)` — was 36/7 of 43.

**`CU243` is a declared premise**, the fourth: it asserts that the *shipped*
`wviewer::signal_list_all` returns one slot carrying `case 1` for a real
`-case distinguish` read. That is item 5's proc and item 1/2's C; no mutation of
item 12's code can redden it. It is the precondition `CU243b`/`CU243c` stand on.
**Evidential count 52 of 56.**

## C. The FIRST CUT's sabotage table, moved here verbatim

`M1`–`M35`, one exact literal each (`M21` is one relocation: the same call,
moved), applied to a byte-exact backup, run, restored, md5 re-asserted. Kept as
the record of the first cut; `N13`/`N14` above re-run its two load-bearing ones.

| check | what was broken | red? | green after restore? |
|---|---|---|---|
| CU231 | `M2` `is_current_ref` always FALSE | yes | yes |
| CU231b | `M1` `is_current_ref` always TRUE | yes | yes |
| CU231c | `M1`; independently `M2`, `M5` | yes | yes |
| CU232 / CU232b / CU232c | `M2`; independently `M5` (per-slot case flag pinned fuzzy) | yes | yes |
| CU232d | `M4` the already-resolves rung removed | yes | yes |
| CU232e / CU233 | `M2` · `M3` the D2 collision guard removed (also `M2`) | yes | yes |
| CU233b / CU233c | `M2` · `M3`; independently `M2` | yes | yes |
| CU233d | `M8` the distinct-spelling dedupe removed; independently `M2`, `M5` | yes | yes |
| CU233e | `M3`; independently `M2`, `M5` | yes | yes |
| CU234 | `M7` the byte-identity passthrough removed; independently `M1`, `M4` | yes | yes |
| CU234b / CU234c / CU234d | `M2`+`M5` · `M1`+`M2`+`M5` · `M3`+`M2` | yes | yes |
| CU235 | `M6` candidates skip the ladder rungs (bare token only) | yes (alone) | yes |
| CU235b | `M4`; independently `M2`, `M5` | yes | yes |
| CU238 | `M11` `dp_finish` does not repair · `M18` it repairs and DISCARDS the answer · **`M21` the call relocated ABOVE `attach_raw`** — not post-load at all | yes | yes |
| CU238b | `M20` `dp_finish` drops the 0153 colours | yes (alone) | yes |
| CU238c | `M13` announced at tag `error`, not `note`; independently `M11`, `M21`, `M2` | yes | yes |
| CU238d | `M1`; independently `M4` | yes | yes |
| CU239 | `M12` `auto_plot` does not repair · **`M19` it repairs BEFORE `plot_map_expr`**, missing the RPN form | yes | yes |
| CU239b | `M13`; independently `M12`, `M19`, `M2`, `M5` | yes | yes |
| CU240 | `M14` the D2 decline says nothing; independently `M3`, `M12`, `M17` | yes | yes |
| CU240b / CU240c | `M3` · `M17` a `none` token announced too | yes | yes |
| CU241 | `M15` the length contract unchecked | yes (alone) | yes |
| CU241b | `M16` the resolver throw not caught | yes (alone) | yes |
| CU241c | `M12`; independently `M2`, `M5` | yes | yes |
| CU242 | `M9` the inventory read moved INSIDE the loop | yes (alone) | yes |
| CU242b | `M22` the empty-batch short circuit removed | yes (alone) | yes |
| CU242c | `M10` the inventory `catch` removed | yes (alone) | yes |
| CU242d | `M23` the no-database short circuit removed | yes (alone) | yes |
| CU236d / CU236e | `M2`; independently `M5` | yes | yes |
| CU236f | `M4` | yes (alone) | yes |
| CU237 / CU237b | `M2`; independently `M5` | yes | yes |
| **CU236 / CU236b / CU236c** | **NOTHING — unsabotageable, and NOT evidence about this item's code.** They assert the committed fixture exists, that `-case distinguish` makes `xschem raw case` answer 1, and that the engine then MISSES `i(vs)`: red if item 1/2's C changes, never if this item's Tcl does (§16.9). **Evidential count 40 of 43.** | n/a | n/a |

