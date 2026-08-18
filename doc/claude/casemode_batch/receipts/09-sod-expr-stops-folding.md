# 09 — `sod_expr` stops folding, and `sod_qualify`'s current arm

**Casemode batch item 9.** Authority `PLAN.md` §3b item 9 + §D6 part 1; `DECISIONS.md` **A1** (fold is the default, so a stock user sees no change) and **B1**. Spec **extended, not replaced**: `doc/claude/specs/simulator_profiles.md` **§13** (§13.1–§13.7) carries the long form and every measurement; this is the receipt. Base `7fc7d810`, `fluid-editing`, nothing pushed, no C, no rebuild. Untouched by fence: pre-flight/`$sim_status` (10), `result_probe -nocase` (11), post-load current repair (12), widgets (13), `render_deck`, `ase::expand_path` (issue `0422`).

## 1. Files changed

- `src/ase_window.tcl` **+135 −12** — `sod_expr` takes a required `mode`; `sod_qualify`'s current arm stops folding and derives the branch prefix from the token; new `ase::ui::sod_case_mode`; `sod_click` resolves the mode once per gesture.
- `src/ase.tcl` **+25 −4** — `sim_profile_resolve`/`sim_profile_casemode` gain `{init 1}`; `init 0` is the read-only form.
- `doc/claude/specs/simulator_profiles.md` **+362 −0** (§13, seven subsections).
- `tests/headless/`: `test_ase_dialogs.tcl` **+35 −0** (`G13` + fixture) · `test_ase_hier_pick_0161.tcl` **+16 −4** · `test_ase_unnamed_net.tcl` **+11 −4** · `test_ase_interact.tcl` **+10 −2** · `test_ase_hier_plot_0168.tcl` **+10 −1** · `full_audit.sh` **+1 −1** (`test_ase_sod_case` → `nogui_tests`).
- NEW: `tests/headless/test_ase_sod_case.tcl` (468 lines, **52 checks**, band `SC192`–`SC211b`; `CS191` was the highest `CS` id in use, re-grepped) · `doc/claude/issues/0423-a-fold-picked-output-row-goes-stale-under-a-later-distinguish-profile.md` (81) · this receipt · audit transcripts `audit_item09_{,fixround_,closer_}2026-08-17.txt`.

## 2. Decisions, and the evidence for each

- **The mode is a REQUIRED third argument of `sod_expr`** (spec §13.2, `SC195`). `sod_expr` must stay pure — called with no design loaded (`H1`; `SC196` renames the `xschem` command away) — so the mode arrives from outside. *Required*, not defaulted, because a defaulted mode is a **silent** fold and a folded `.save` under `distinguish` is `rc=1`, zero vectors, "analysis not run" (`PLAN` §F2, re-measured on `ver_50`) — the whole session's data. A missing argument is a loud Tcl error. One production caller.
- **`sod_qualify` gains NO mode; the branch prefix follows the TOKEN** (§13.3, `SC201`/`SC203`/`SC203b`). This **refutes** "`v.` when folding, `V.` otherwise", by re-using item 4's `ver_50` measurement: deck `Vs` → `i(V.X1.Vs)`, deck `vs` → `i(v.X1.vs)` — the device's own first character. `sod_qualify` now answers in the schematic's spelling in every mode and `sod_expr` owns the whole case mapping; `hilight.c`'s `sender_current_prefix()` (`buf[0]=t[0]`) is the C half of the same rule.
- **The governing mode is the RUN's request** (§13.4): profile `casemode` → floor `sim_case_mode` → `fold`; never a loaded raw's `case_sensitive`, never a file's verdict. Stated, not inherited — item 3 lets a question about a *run* use the floor and item 8 already treats it as a request. Resolved **once per gesture** in `sod_click`, before the bus fan-out (`SC204b`).
- **`sod_case_mode` delegates, it does not re-validate** — a ruling found *by* sabotage. The first cut kept a second copy of `::sim_profile_casemode`'s validation; it survived every mutation green **and masked a real defect** (a `sod_case_mode` reading `$::sim_case_mode` raw still folded garbage, so `SC206` was blind). Deleted; `M10b`/`N13` now redden three checks.
- **The resolve must be READ-ONLY** (§13.4; review finding, reproduced before fixing). `sim_profile_resolve` opened with `::set_sim_defaults`, which is **not a read**: with `.sim` open it slurps every `…r.$i.cmd` widget into `sim()`. Measured on the shipped tree — `USER-IS-STILL-TYPING` typed into the spice row-0 box survived one `sod_click` **and** the Cancel after it. A read-only pick (issue `0204`) may not write global config. Fix: ask with `init 0`, plus our own one-time build guarded by `![info exists ::sim(tool_list)]` — a state in which `.sim` cannot exist. Other callers keep `init 1`; item 6's `CS163k` stays green.
- **A resolver throw folds but is ANNOUNCED** (`SC208c`) — the blanket `catch` was the same silent fold one layer up; narrowed to the resolver call, and it echoes before falling back.
- **A1 is not universal, and the exception is a REPAIR — measured, not preferred** (§13.3, `SC211`). `vsource_pwl`/`vsource_arith` ship `type=vsource` templated `name=E1`, `filesource` `name=A1`, so the fold expression *does* move for them. On `ver_50`, `render_deck`'s deck shape, VCVS `E1` in `X1`: the raw carries `i(e.x1.e1)`; `.save i(e.x1.e1)` → rc 0 with the vector, `.save i(v.x1.e1)` → "analysis not run", 570-byte empty raw. The old literal `v.` was **broken** for those devices, not "unchanged". Code kept; the false quantifier struck from the comment, the spec and this receipt; both columns pinned.
- **DECLARED DEPARTURE** (§13.5b): `PLAN` §D3 says `sod_expr` stops folding *unconditionally*. A1's byte-identity requirement outranks it and forces the mode-conditional shape; the property §D3 bought — a row picked under `fold` is stale under a later `distinguish` profile — is filed as issue **`0423`**, mitigation (item 10's pre-flight must REFUSE such a run) written into §13.6.
- **MEASUREMENT correcting the dispatch:** the plan predicted "~20 committed assertions flip". Enumerated across all ten named files plus a whole-tree grep: **ten change, and only `HL17` changes its expected value** (`v.x2.V1` → `V.x2.V1`). The other nine (`AN10`, `AN11`, `AN12`×2, `H1`×2, `HP1`, `HP2`, `HP3b`) gain an explicit `fold` with unchanged values — A1's result, not a shortfall. All ten keep their ids and gained a why-comment; none renumbered, none deleted. Row-by-row table in spec §13.5.

## 3. Tests, counts, verbatim RESULT lines

New suite, true headless, no simulator, no `ver_50` dependency, nothing printing a `SKIP` substring: `./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_sod_case.tcl`

```
RESULT: ALL PASS (52 checks)     test_ase_sod_case  (RED before the code: RESULT: 30 FAILED (12 passed))
RESULT: ALL PASS (149 checks)    test_ase_dialogs   (147 + G13 + its fixture)
```

`GUI_GATE=1 tests/headless/run_suites.sh` on `:99` — restated suites and every neighbour the change reaches, green at unchanged counts: `test_ase_hier_pick_0161` 21 · `test_ase_hier_plot_0168` 31 · `test_ase_unnamed_net` 28 · `test_ase_interact` 63 · `test_ase_bus_bits_0159` 39 · `test_ase_locked_wire_pick_0160` 16 · `test_ase_persist` 109 · `test_ase_print_bracket_0167` 12 · `test_ase_plot` 150 · `test_ase_core` 75 · `test_ase_final` 28 · `test_ase_log_seam_0207` 26 · `test_sim_profiles` 97 (with `CS163k`, the check that would catch the `ase.tcl` signature change) · `test_sim_probe` 61 · `test_sim_run_profile` 38. Arm trap: on the wrong arm `test_ase_log_seam_0207` shows 16 FAILED and `test_ase_final` 1 FAILED — both reproduce on a pristine `ase_window.tcl`, A/B'd.

**AUDIT** (`GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped), transcript `casemode_batch/audit_item09_closer_2026-08-17.txt`: `SUMMARY: 326 pass  15 fail  0 crash/timeout  0 skip  (total 341)`, `WIREEDIT: PASS`, `SCRATCH: 0 leaked dir(s)`. **Diffed by NAME and STATUS against `audit_item08_closer2_2026-08-17.txt` (325/15/0/0 of 340 at `d44febbd`): rows lost NONE · rows added `test_ase_sod_case` (PASS), this item's own suite · status changed in EITHER direction NONE.** The 15 reds are the POLICY block's 15 names exactly; `test_ase_core` and `test_ase_dialogs` are PASS.

## 4. Sabotage — one row per new check

Each mutation applied to a fresh copy of a byte-exact backup, run, restored, md5 re-verified (`ase_window.tcl` `1b2bffe7…`, `ase.tcl` `fbc6fb45…`). Pure Tcl, no rebuild. `M` = implementer round, `V` = verifier's independent round, `N` = fix round.

| check | what was broken | red? | green after restore? |
|---|---|---|---|
| SC192 | M18 `sod_expr`'s fold arm disarmed | yes | yes |
| SC192b | M1 the mode test → `1` (always folds) | yes | yes |
| SC192c | M2 the test → `$mode ne {preserve}` (distinguish stops keeping case) | yes | yes |
| SC192d | M20 the fold test → `$mode eq {fold}` (unknown mode emits verbatim) | yes (alone) | yes |
| SC193 | M18 | yes | yes |
| SC193b | M1 | yes | yes |
| SC194 | M4 the voltage `#` strip disarmed | yes | yes |
| SC194b | M4 | yes | yes |
| SC194c | M1; independently M18 | yes | yes |
| SC194d | M1; independently M18 | yes | yes |
| SC195 | M3 `{kind token mode}` → `{kind token {mode fold}}` | yes (alone) | yes |
| SC196 | M13b a bare `xschem get currsch` planted inside `sod_expr` | yes (alone) | yes |
| SC196b | N5 the fold arm made to consult `$::sim_case_mode` | yes (alone) | yes |
| SC197 | M18; independently M19 (`sod_case_mode` pinned `preserve`) | yes | yes |
| SC197b | M1; independently M11 (pinned `fold`) | yes | yes |
| SC197c | M2 | yes | yes |
| SC198 | M18; independently M19 | yes | yes |
| SC198b | M1; independently M11 | yes | yes |
| SC199b | V-R `sod_qualify`'s voltage arm returns the bare token | yes | yes |
| SC199c | V-R (the control against `preserve` uppercasing on its own) | yes | yes |
| SC200 | M16 prefix → `[string index $token 1]`; independently M18 | yes | yes |
| SC200b | M5 prefix → the shipped literal `v.` | yes | yes |
| SC201 | M5; independently M16 | yes | yes |
| SC202b | M18; independently V-R | yes | yes |
| SC202c | M1; independently M15 (the keep-case arm uppercases) | yes | yes |
| SC203 | M5; independently M7 (the path re-folded) | yes | yes |
| SC203b | M6 prefix → `[string toupper …]`, the refuted "`V.` otherwise" | yes (alone) | yes |
| SC203c | M16; independently M18 | yes | yes |
| SC204 | M2; independently M5 | yes | yes |
| SC204b | M9 the mode passed for the FIRST bus bit only | yes (alone) | yes |
| SC204c | M18 | yes | yes |
| SC204d | M14 the 0153 colour cue given `$ex` instead of `$token` | yes (alone) | yes |
| SC205 | M19 `sod_case_mode` pinned `preserve` | yes | yes |
| SC205b | M11 pinned `fold` | yes | yes |
| SC205c | M11; independently M19 | yes | yes |
| SC206 | M10b `sod_case_mode` bypasses the authority, reads `$::sim_case_mode` | yes | yes |
| SC206b | M19; independently M18 | yes | yes |
| SC207b | M10b; independently N11 | yes | yes |
| SC207c | M10b; independently N11 | yes | yes |
| SC207d | M19; independently N12 | yes | yes |
| SC208 | N1 the resolve asked with `init 1` again (the shipped defect) | yes | yes |
| SC208b | N2 the guarded one-time `set_sim_defaults` deleted | yes | yes |
| SC208c | N3 the narrowed catch reverted to the blanket one, no notice | yes (alone) | yes |
| SC208c-sane | N10 `sod_case_mode` memoised across clicks; independently N11 | yes | yes |
| SC209 | N4 the key made dead: `ase::session_state $key` → `{}` | yes | yes |
| SC209b | N4 | yes | yes |
| SC209c | N10; independently N12 and N14 | yes | yes |
| SC211 | N6 prefix → the old literal `v.` | yes | yes |
| SC211b | N7 prefix → `[string toupper …]` | yes | yes |
| G13 (`test_ase_dialogs`) | N1; independently N8 (`ase.tcl`'s `if {$init}` made unconditional) | yes | yes |
| HL17 (`0168`, restated) | N6/M5, whole suite: `RESULT: 1 FAILED (30 passed)` | yes | yes |

**Unsabotaged, and therefore NOT evidence for this item** — four fixture preconditions with no item-9 code beneath them: `SC199`, `SC202` (the descend worked), `SC207` (the spice tool has a default profile row), `G13 fixture` (the simconf row-0 cmd widget exists). **One edit has no red/green drive and is declared:** `full_audit.sh` +1 −1 — the suite emits the identical verbatim RESULT line on either arm the audit can pick, exactly as item 8 declared for its own entry; the row does land and score (`PASS | test_ase_sod_case`, total 340 → 341). The nine restated assertions other than `HL17` kept their values, so their drive is `M18`/`M1` inside the new suite, which re-asserts the same literals (spec §13.5).

## 5. What was NOT verified

- **No simulator runs in any CHECK.** The `ver_50` work above is measurement recorded in the spec, not a test dependency; that a full `preserve` deck runs green end to end was driven once by the verifier, not by a check.
- **Reviewer findings raised but not confirmed: none** — that list was empty. Their **not-proven** items stand as limits: no reviewer re-shot the audit independently (they diffed the committed transcript and ran 25 suites, zero statuses moved either way); item 11's premise that a *delivered* `preserve` echo keeps its case is unmeasured; the `plot`-flavour path (expression matched against an already-loaded raw instead of written into a deck) was traced by reading, not exercised — no defect found, and §13.4 now says so; whether `simconf` is realistically open during a pick is a usage judgement, only the mechanism was proved; whether item 10 will implement the re-case pass (hence issue `0423`); and whether `i(e.x1.x2.e1)` is the spelling ngspice wants for a VCVS branch current *at depth* — only the flat `E1`-in-`X1` row was measured.
- **No Xyce anywhere** — ASE-L's pick path has no Xyce branch where `hilight.c` does, so the two differ for Xyce by construction. UNVERIFIED, as in item 4. **Ammeters are reasoned, not picked** by any check; their class is driven on a vsource named `E1` through the identical code path.
- **Left deliberately stale for item 15:** `doc/claude/code_analysis/ngspice_case_sensitivity.md:62` still quotes the two-argument `sod_expr` call site.
- **Disclosed slips, both inert and both re-checked:** an eight-line comment was added to `sod_expr` after the implementer's sabotage round (the verifier re-drove every mutation against the shipped bytes), and a dead `set m {}` was deleted and reverted within a minute during the fix-round audit. The shipped md5s are the ones every drive above ran against.
- **No eyeball owed.** The payload is the spelling of strings written into a deck plus a global array that must not change, all asserted byte for byte; `G13` drives a real dialog but asserts a string, not pixels. `owed.sh` untouched.
