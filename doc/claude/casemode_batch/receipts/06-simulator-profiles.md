# 06 — extend `sim()` / `simconf` / `simrc`: the profile MODEL

**This receipt is casemode batch ITEM 6.** The other `06-` receipt here, `06-one-lookup-authority.md` (+ annex), belongs to **item 5b** — the pipeline numbered both from the same `n`.
Authority: `PLAN.md` §3b item 6 · `DECISIONS.md` **B1** (both halves) + **A1** (requested vs measured) + **A2** (`-n`). Spec **NEW**: `doc/claude/specs/simulator_profiles.md`.
Long-form detail — recovery narrative, the three inherited defects, all 20 reviewer findings, both full mutation tables — is in `06-simulator-profiles-annex.md`.
**Recovery run:** a first crew's work sat on disk unverified after an API 529; it was assessed, corrected (3 defects), then verified and reviewed by three lenses (5 more code defects, 8 coverage holes) and fixed. Model only: no probe (item 7), no run path (8), no widget (13). Pure Tcl, no C, nothing built. Base `d0eb835d`.

## 1. Files changed

`git diff --numstat`, five tracked files, **+700 −9**:

| file | ± | what |
|---|---|---|
| `src/xschem.tcl` | **+531 −0** | 6 profile fields, **20** `sim_profile_*` procs, the `save_sim_defaults` arm, the `set_sim_defaults` normalize call, `simconf_add`'s row shape |
| `src/ase.tcl` | **+148 −3** | `sim_profile` in `schema_keys` (after `simulator`) + `omit_if_empty` + `state_default`; 5 procs (`backend_tool`, `sim_profile_resolve`/`casemode`/`stamp`/`clear`); index canonicalization; an `ase::expand_path` warning comment |
| `tests/headless/test_ase_core.tcl` | +12 −2 | 16→**17** schema keys (restated), + 1 new check |
| `tests/headless/test_ase_persist.tcl` | +8 −3 | 16→**17** schema keys (restated) |
| `tests/headless/full_audit.sh` | +1 −1 | `test_sim_profiles` → `nogui_tests` |

New (untracked before this commit): `tests/headless/test_sim_profiles.tcl` (**949 lines, 97 checks**, band `CS150`–`CS166`, contiguous; highest elsewhere was `CS149`) · `tests/headless/fixtures/simrc_pre_casemode` (frozen **pre-change** `save_sim_defaults` output) · `doc/claude/specs/simulator_profiles.md` · this receipt + annex · `doc/claude/issues/0502-*.md` · two audit files (§3).
**Not created:** `$USER_CONF_DIR/ase_simulators` — B1 killed it. **Untouched:** every existing `cmd` string, `run_cmd`, `simconf`'s widgets, `sod_expr`, all C.

## 2. Decisions, and the evidence for each

Spec is authoritative; every ruling is written there with its measurement.

- **Fields are STRUCTURED and additive, never parsed out of `cmd`** (B1): `exe args casemode detected probed nospiceinit`, one canonical `sim_profile_field_defaults` walked by normalizer, reader, writer, persister and tests. Existing `cmd` strings untouched and still driving the Simulation menu.
- **`casemode` (requested) and `detected` (measured) stay SEPARATE** (A1) so item 13 can build a dropdown that never offers an undeliverable mode; `CS156` asserts one disagreement in one assertion.
- **`selectable` keys off `probed`, not `detected`** (spec §4): unprobed → `fold` alone, probed-and-measured-to-deliver-nothing → **nothing**. Reviewer finding: the first shape offered `fold` while `supports fold` answered 0 in the same breath, i.e. A1 broken for a measured binary. `CS156g`.
- **`sim_is_xyce` does NOT consult `exe`** (spec §6): item 4 built `hilight.c`'s Xyce sender fallback on its answer. Pinned both ways with an `exe` pointing the other way (`CS160`/`CS160b`); the rejected design, wired, reddens `CS160` (M37).
- **The persistence guard IS the round trip, and must model the SCRIPT parser** (spec §5): `info complete "{$value}"` passed `a}b`, which was written and made the user's whole `~/.xschem/simrc` unsourceable. The replacement parses the emitted line and additionally refuses backslash-newline and bare CR — measured, the only two sequences on which list and script parsing diverge inside braces. `CS153d`/`CS153e`/`CS153g`, with `CS153f` the acceptance half.
- **Only what DIFFERS from the default is written**, so an old `simrc` keeps working and a pre-batch one round-trips byte-for-byte (`CS150`, `CS158`). An **invalid hand-edited value is DROPPED** at the next save rather than written back (`CS158g`) — writing it back can make the file unsourceable; item 13's dialog is where a typo gets reported.
- **Path expansion is VARIABLES ONLY; `subst -nocommands` is not a sandbox** (spec §5): measured, it still runs a `[...]` inside an **array index**, so a stored `exe` ran `exec touch` during a pure staleness query. Own expander now — `CS157k` (top level), `CS157l` (array index), `CS157n` (a reference not at offset 0, a defect the fix itself introduced).
- **The normalize guard is a ROW-COUNT MEMO** inside `sim()` (spec §5): gating on "did this call rebuild the array" left an **rc-appended** row — one of the two population routes B1 names — unshaped for the whole session. `CS151f` now drives the real `set_sim_defaults` route, `CS151i` the later-reader leg.
- **A state's profile index is CANONICALIZED once it validates** (spec §8): `string is integer -strict` accepts `02`, `-0`, ` 2 `, each of which passed the bounds test, then indexed a row that does not exist, while reporting `ok`. `CS163l`; `CS163j` pins why the integer test itself is load-bearing.
- **`sim_profile` state key** sits after `simulator`, is in `omit_if_empty`, `version` stays **1** — so no existing state file gains a line on its first save (`CS161c`, `CS165`, frozen-fixture round trip).
- **RULING — `save.c:netlist_case_mode()` stays UNWIRED** (spec §10), against its own comment's expectation: no shipped row carries a `casemode`, so wired and unwired answers are identical for every configuration that can exist before item 13, and re-pointing a green item-14 authority for zero observable difference can only move an audit row. The spec records the one-line expression a consumer uses and what its author then owes.
- **Declared, not fixed** (all in the spec): a state naming another **tool**'s row resolves `ok`; a **nameless** row can never report `stale`; `default_index` answers `-1` with no downstream meaning yet; `sim_profile_row` on an out-of-range index returns a plausible dict with no "exists" flag; `ase::expand_path`'s pre-existing code-execution hole → **issue 0502**.

## 3. Test names, check count, RESULT

`tests/headless/test_sim_profiles.tcl`, true headless (`--nogui` — which is what its no-Tk claim asserts), **97 checks**, verbatim:

**`RESULT: ALL PASS (97 checks)`**

Also green: `test_ase_persist` 109, `test_ase_cosim` 342, `test_raw_case_mode` 277, `test_hilight_case_senders` 30 (`GUI_GATE=1 run_suites.sh` on `:99`, 5/5 runs passed); `--nogui` `test_ase_core` 75, `test_ase_final` 28, `test_ase_final_gf180` 33. Those three fail one check on the DISPLAY arm at a **fully pristine** tree too (`ase: design aselib/nfet_clean is not the current schematic`), A/B'd; all three are `nogui_tests` in the audit, where they pass.

**Closer audit** — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped. Verbatim:

```
SUMMARY: 323 pass  15 fail  0 crash/timeout  0 skip  (total 338)
WIREEDIT: PASS    SCRATCH:  0 leaked dir(s)
TREE:     2 appeared  0 vanished (report only, gitignored paths excluded)
```

The two `TREEADD` rows are this receipt's own annex and `issues/0502-*.md`, written by
the closer while the audit ran — no source or test file moved, and the `md5`s of
`src/xschem.tcl`, `src/ase.tcl`, `test_sim_profiles.tcl` and the `simrc` fixture are
identical before and after the run.

**DIFF vs `audit_item14_closer_2026-08-17.txt` (322/15/0/0 of 337, at `a7f56fa6`), by NAME and STATUS: rows only in the baseline — NONE. Rows only in mine — `test_sim_profiles` (PASS), this item's new suite. Status changes in either direction — NONE, zero rows moved.** The 15 reds are the same 15 names compared as sorted lists; **`test_ase_core` is PASS**, as the contract requires. Counted with a differ matching only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP) +\| +test_…$`, so the six within-file `FAIL | key …` detail lines cannot be miscounted as rows; self-checked by diffing the baseline against itself (337 rows, 322/15, zero changes).
Two files, both diffing empty: `audit_item06_closer_2026-08-17.txt` (mine) and `audit_item06_fixround_2026-08-17.txt` (the fix round's, over identical source `md5`s). The first crew's two audit files were deleted by the fix round — they predated five code fixes and fifteen checks.

## 4. Sabotage

**100 drives** over two rounds. Each is an exact literal replacement asserted to hit **exactly once** (a silently-missed patch would otherwise read as "nothing went red"), applied over a byte-exact backup, run, restored, restore `md5`-verified; suite green before and after, and the tracked fixture is `git status`-clean afterwards. Scripts: `…/scratchpad/item06/{mutate,mut2}.py` (64) + `…/scratchpad/fix06/{mutate,mut2}.py` (36). **MASTER RED** — both source files replaced by `git show HEAD:` → **`RESULT: 95 FAILED (2 passed)`**, restored → `ALL PASS (97)`. Every row below went red and restored green.

| mutation | checks reddened |
|---|---|
| M01 persister writes every field · M02/M02b normalize never runs / no-op | CS150 CS151g CS158 · CS150 CS151c CS151f CS151g |
| **M03 FIX-B revert** (per-row short circuit back) · **M04 FIX-A revert** (`info complete`) · M04b guard deleted · **M05 FIX-C revert** (`resolve` stops building `sim()`) | CS151g · CS153e · CS153d CS153e · CS163k |
| M06 read-side validation off · M17 `detected` unfiltered | CS154b CS156f · CS156d CS156f |
| M07/M09/M10 casemode / probed / nospiceinit validation off | CS154 CS154c · CS154d · CS154e |
| M30 `nospiceinit` dropped from the field list | CS151 CS151b CS151f CS151g CS154e CS154f CS158 CS158c CS158d |
| M11/M12/M13/M14 row mode ignored · floor never consulted · floor unvalidated · floor+fold deleted | CS155c CS156 CS158c CS164 · CS155b CS164c · CS155d · CS155 CS159 CS164b |
| M15 `supports` unprobed=1 · M16 `selectable` offers all three | CS156b · CS156c |
| M18/M19/M20/M57/M67 staleness and probe-stamp legs | CS157e CS157i · CS157c CS157d · CS157b · CS157 · CS157f |
| M21/M22/M23/M24/M64 `exe_path` legs | CS157g · CS157i · CS157k · CS157j · CS157h |
| M25/M26/M27/M28 unknown field · `info exists` · unknown default · row range | CS152c · CS152 CS152b · CS152b · CS152d |
| M29 the setter writes the wrong array element | 23 checks, incl. CS153 CS153b CS153c CS156e |
| M31/M32 a built-in row given an `exe` · `simconf_add` shape dropped | CS151d CS158 · CS151e |
| M33/M34/M35/M36 `row` drops `requested` · default clamp · no-such-tool guard · constant `default_index` | CS159 · CS159c · CS159d · CS159b |
| M37 `sim_is_xyce` consults `exe` (**the rejected design**) · M38 its regexp deleted · M39 a `winfo` in a profile proc | CS160 · CS160b · CS166 |
| M40/M41/M42/M43 `schema_keys` · `omit_if_empty` · `state_default` · key moved last | CS161 CS161e CS165 · CS161c · CS161d · CS161b CS161f |
| M44/M62/M45/M46/M47/M48/M49/M50/M51/M65/M66 `backend_tool` + `resolve`/`stamp`/`clear` legs | CS162 CS162b CS163 CS163e CS163f CS163g CS163i CS163j CS163h · CS163c CS163d CS163b CS165c |
| M55/M59 persister writes unbraced · guard becomes too strict | CS153f CS158b CS158d |
| **D1/D2 DATA** drives: each frozen fixture given a new-field line | CS150b CS150 · CS165b CS165 |
| N01/N02/N03 backslash-NL, bare CR, over-refuse · N33 any brace refused | CS153g · CS153f |
| N04/N05 `subst` back · array-index refusal deleted · N31/N32/N35/N36 expander legs | CS157l · CS157i CS157j CS157n |
| N06/N07 memo blind to a new row · memo never hits | CS151f CS151i · CS151i |
| N08/N09 both shape builders plant `{}` · N10 no-configuration guard deleted | CS151h · CS151j |
| N11/N12 `selectable` back on `detected` · offers nothing even unprobed | CS156g · CS156c CS159 |
| N13 `probe_record` records a mode it was never given (A1) · N14 stamp hard-coded | CS157m CS156g · CS157c |
| N15/N16/N17 `probed` never written · spice-only · raw invalid value survives | CS158e · CS158f · CS158g |
| N18/N19 `row` drops `fg`/`st` · N20 `backend_tools` map deleted | CS159 · CS162c |
| N21 index no longer canonicalized · N23/N24 `stamp`/`resolve` tool hard-coded | CS163l · CS163m |
| N25 a `canvas` in a profile proc · N26 **TEST**: detector made blind (sentinel half) | CS166 · CS166 |
| N27/N28 `sim_profile_valid`'s `args`/`detected` list arms always say yes | CS154g |
| N34 `state_default` loses `sim_profile {}` | the two committed 17-key checks · CS161d CS165 |

**The closer re-drove two rows from scratch** rather than citing them: the master red
(`RESULT: 95 FAILED (2 passed)`, restore `md5`-equal, back to `ALL PASS (97 checks)`),
and `N01` — deleting only the backslash-newline refusal — which gives
`RESULT: 1 FAILED (96 passed)`, `FAIL: CS153g … got 'bsnl=0 …' want 'bsnl=1 …'`,
then green again. The remaining 98 rows are the implement/fix rounds' measurements.

**No check is unsabotaged**: all 97 ids appear above (verified by set difference against the ids in the file). The master red's two survivors, `CS150b`/`CS165b`, are fixture-**premise** checks with no item-6 code beneath them, which is why D1/D2 exist. **One drive stays green deliberately** — `N29`, deleting `sim_profile_supports`' mode guard, moves nothing: the guard is **declared unreachable by construction** in spec §4 (`detected` is filtered through the canonical three, so a non-mode can never be in it) and kept as defence in depth. `CS156e` asserts the behaviour, not that line, and reddens under M29.

## 5. What was NOT verified

- **No probe ran, no simulator was launched** — item 7 owns that. `detected`/`probed` were written by hand or against a **fake** exe, never `build-ver_50`; "released ngspice ignores `-D casemode=`" is inherited from A1, not re-measured.
- **No old xschem binary read a new `simrc`.** Compat half 2 rests on the grep argument (no `array names`/`array get sim` anywhere; the three C readers name `sim(spicewave,%d,name)` explicitly) plus write-only-what-differs. Not executed by anyone.
- **The requested mode reaches NO consumer yet** — `netlist_case_mode()` is unwired on purpose (§2). `args`, `nospiceinit`, `probed` and `sim_profile` are storage whose USE is unproven by construction, and `simconf_add` is reachable only from commented-out dialog code, so `CS151e` drives a proc no user can reach until item 13.
- **The rc route ships empty**: `src/cadence_style_rc` mentions `sim(` nowhere, and populating an `exe` there would break the no-built-in-`exe` ruling. It is exercised only by tests writing the same globals an rc writes.
- **`ase::expand_path` is left unsafe on purpose** → **issue 0502**: it expands model paths from a state file with the same `subst -nocommands` this item measured to run a command inside an array index. Not item 6's surface to change.
- **`CS166` is a static blocklist** with two declared blind spots: Tk reached by dynamic dispatch (`[$cmd .w]`), and a Tk word in a trailing `;#` comment. The primary no-Tk evidence is that the whole file runs under `--nogui`.
- **Reviewer bookkeeping now corrected, not merely disclosed:** the earlier "66 mutations" was wrong (round-1 scripts drive 64) and the suite is 949 lines, not 616/617. Nothing was raised-but-unconfirmed — all 20 confirmed findings are fixed or listed here as declared.
- **One unexplained single red**: a reviewer saw `CS153e` fail twice in 341 runs, never reproduced, most plausibly another reviewer's live mutation of the shared tree. Recorded, not attributed.
- **No C, nothing built, no valgrind. No eyeball owed** — the payload is data + persistence, asserted byte for byte; `owed.sh` untouched; item 13 owns every pixel.
