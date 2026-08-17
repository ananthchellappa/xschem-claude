# 08 — profile-aware `run_cmd`, and B4's mismatch policy

**Casemode batch ITEM 8.** Authority: `PLAN.md` §3b item 8 · `DECISIONS.md` **B1** (the command is built from the profile), **A2** (no `-n` by default), **B4** (`preserve` mismatch reports and continues, `distinguish` mismatch **REFUSES**). Spec **extended, not replaced**: `doc/claude/specs/simulator_profiles.md` **§12** (item 6 owns §1–§10, item 7 owns §11). Base `54546db8`. Long form — every ruling with its measurement, all 46+ mutations, the fix round's eight findings — is in **`08-profile-aware-run-cmd-annex.md`**. **Untouched:** `render_deck` (CREW_BRIEF §4), `sod_expr` (9), the pre-flight/`$sim_status` guard (10), `result_probe` (11), every widget (13), `ase::expand_path` (issue 0422). No C, nothing built. §3b's line number was stale twice over: `run_cmd` is `ase.tcl:3901+`, not `3238`, not `3487`.

## 1. Files changed

`git diff --numstat`, three tracked files, **+851 −6**:

| file | ± | what |
|---|---|---|
| `src/ase.tcl` | **+462 −5** | 9 procs (`run_filter_args`, `run_safe_args`, `run_profile`, `run_casemode_flag`, `run_casemode_verdict`, `run_composes_profile`, `run_status_note`, `run_mode_advice`, `run_precheck`); the gate call in `run_deck`; an optional `notes` arg on `run_done`; `ngspice::run_cmd` composed from the profile |
| `doc/claude/specs/simulator_profiles.md` | **+388 −0** | **§12**, nine subsections, every ruling with its evidence |
| `tests/headless/full_audit.sh` | +1 −1 | `test_sim_run_profile` → `nogui_tests` |

New: `tests/headless/test_sim_run_profile.tcl` (**723 lines, 38 checks**, band `CS175`–`CS191`; `CS174` was the highest in use, grepped across `tests/headless/*.tcl`, band unique to this file), this receipt + annex, three audit files (`_closer_`, `_fixround_`, `_closer2_` — provenance, as item 7 kept).

## 2. Decisions taken, and the evidence for each

Every ruling is in the spec; the subsection is named against each.

- **Compatibility is a CHECK, not a hope (§12.1, `CS175`).** With no profile the composed list is byte-identical to `[list ngspice -b $deckpath 2>@1]`; the same assertion composes a *configured* row, so it cannot pass by the feature being absent. This is what keeps the batch's empty-audit contract.
- **The run filter is NOT `sim_probe_safe_args` and must never become it (§12.2, `CS177c`).** Every reason that filter exists is about a *probe*; a real run needs `-r` — xschem's own shipped batch row `sim(spice,2,cmd)` is `ngspice -b -r "$n.raw" "$N"` (`xschem.tcl:4086`). `CS177c` reads both filters on `-r`/`--rawfile`/`--soa-log` and reddens if they ever agree; wiring the probe filter in reddens it.
- **RULING — `-o`/`--output` IS dropped, and reported (§12.2, `CS186`/`CS186b`).** Measured on real `/usr/local/bin/ngspice`: `-b d.cir` prints `v(a) = 1.000000e+00` on stdout, `-b -o o.log d.cir` prints only the log-file banner and `ase::last_result` comes back **empty**. Reading `-o`'s file back was rejected: it would make ASE-L's parse depend on a path the user chose.
- **RULING — `-D casemode=` only for a non-`fold` request (§12.3, `CS176c`/`CS176d`).** Measured: `build-ver_50` with no `-D` answers `CCM=fold`; stock accepts and ignores it; a `.spiceinit` overrides it anyway. Always emitting it would change every existing user's command line and buy nothing. The floor `sim_case_mode` counts as a request (B1).
- **RULING — an exe a row NAMES but we cannot locate REFUSES in every mode (§12.4, `CS180`).** The bare-PATH fallback would silently run a different simulator; ver_50 has moved three times in four days.
- **B4's split, and what REFUSE means (§12.5; `CS178`–`CS178f`, `CS181`/`CS181b`, `CS190`).** "Not confirmed" (timeout, noexe, probe error) refuses under `distinguish` — B4's clause is *confirmed to support it*, which is what catches B4's third route, the binary moving under the path. REFUSE = **before anything is generated**: the gate is `run_deck`'s first statement, before its first `open` and before the cosim artefacts are cleared — no deck, raw, log, VCD deletion, `.so` rebuild, process, `last_run` or callback — and the message says the rundir's files are from an earlier run.
- **RULING — the gate is armed only by a non-`fold` request (§12.6, `CS179d`).** A1: the warning never fires for a stock user. Declared consequence in §5 below.
- **RULING — the policy applies only where `::ase::backend::ngspice::run_cmd` composes, by hook IDENTITY (§12.6, `CS180c`/`CS191`).** A sixth registered hook was rejected: `register_backend` requires all five it knows.
- **RULING — a `stale`/`invalid` resolve is REPORTED, not refused (§12.9, `CS187`/`CS187b`).** Item 6 delegated this here; the first cut computed the status and read it nowhere, so a renamed row silently ran a *different binary* (measured, two stand-ins). Refusing was rejected: §5 of the spec rules a hand-edited `simrc` must not make a saved session unopenable, and the probe still measures the binary that will actually run, so no mode is smuggled past B4.
- **RULING — the advice must name a lever that exists (§12.5, `CS188`).** On the global-floor path there is no profile row and no `-n` checkbox; "turn on the profile's `-n`" was nonsense there.
- **The report reaches three channels (§12.7; `CS182`/`CS182b`/`CS183`, `CS186b`, `CS187`).** `ase::echo` → CIW pane (tag `note`/`error`, item 14's house rule), the action log, and the head of `<rundir>/<cell>_ase.log` via `run_done`'s new **optional** `notes` (optional so `test_ase_cosim`'s six 3-argument callers keep working). Confirmed live: note first, simulator output beneath.

## 3. Test, checks, RESULT, audit

`tests/headless/test_sim_run_profile.tcl`, true headless (`--nogui`; needs no display and no ngspice), **38 checks**, verbatim:

```
RESULT: ALL PASS (38 checks)
```

Master red: `src/ase.tcl` replaced by `git show HEAD:` → `RESULT: 37 FAILED (1 passed)`; restored from a byte-exact backup (md5 `277f3d8581e74924b856e1d638f29fb9`), green again.

**AUDIT, my own run** (`GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, DISPLAY never stripped), saved as `casemode_batch/audit_item08_closer2_2026-08-17.txt`: `SUMMARY: 325 pass  15 fail  0 crash/timeout  0 skip  (total 340)`; `WIREEDIT: PASS`; `SCRATCH: 0 leaked dir(s)`; `TREE: 0 appeared  0 vanished`. **Diffed by NAME and STATUS against `audit_item07_closer_2026-08-17.txt` (324/15/0/0 of 339 at `ebf4c952`): rows only in baseline NONE; rows only in mine `test_sim_run_profile` (PASS), this item's own new suite; status changes in EITHER direction NONE.** The 15 reds are the policy's 15 names exactly; `test_ase_core` is PASS. The differ matches only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so the six within-file `FAIL | key …` detail lines cannot be miscounted. The differ was self-checked by diffing the baseline against itself (339 rows, 324/15, zero changes). `TREE: 2 appeared 1 vanished` is report-only and is my own doc write during the audit window: the implementer's `08-profile-aware-run.md` renamed to `…-run-cmd-annex.md` plus this receipt.

## 4. Sabotage table

One row per check. Every mutation was an exact literal asserted to occur once, reverted from a byte-exact backup, md5-verified. "collateral" counts are other checks that also reddened — always a related consumer of the same value.

| check | what was broken | red? | restored green? |
|---|---|---|---|
| CS175 | `run_cmd`'s `set exe ngspice` fallback → `ngspice_MUTANT` | yes (1) | yes |
| CS176 | `run_cmd`: profile-args loop and the `-n` line swapped | yes (1) | yes |
| CS176b | `run_cmd`: `if {[dict get $p nospiceinit]}` inverted | yes (8, composition family) | yes |
| CS176c | `run_casemode_flag`: `-D casemode=$m` → hard-coded `preserve` | yes (1) | yes |
| CS176d | `run_profile`: `sim_profile_casemode` → `sim_profile_get …casemode` (floor dropped) | yes (2) | yes |
| CS176e | `run_cmd`: `lappend cmd $deckpath 2>@1` → `2>@1 $deckpath` | yes (8) | yes |
| CS177 | `run_filter_args`: `[string range $w 0 1] eq {2>}` → `{3>}` | yes (1) | yes |
| CS177b | `run_profile`: the filter unwired (`keep` = raw args) | yes (4) | yes |
| CS177c | `run_safe_args` body → `return [sim_probe_safe_args $arglist]` — the anti-copy mistake | yes (2) | yes |
| CS178 | `run_casemode_verdict`: final `action report` → `action ok` | yes (5) | yes |
| CS178b | `run_casemode_verdict`: `$requested eq {distinguish}` → `{nosuchmode}` | yes (8 on the final tree) | yes |
| CS178c | same guard widened with `&& $delivers ne {}` (not-confirmed stops refusing) | yes (1) | yes |
| CS178d | ok-condition widened with `\|\| ($delivers eq {} && $requested eq {preserve})` | yes (1) | yes |
| CS178e | ok-condition's `$requested eq {fold}` term deleted | yes (1) | yes |
| CS178f | reason text `"…measured to deliver '$delivers'"` → `"mismatch"` | yes (1) | yes |
| CS179 | `run_precheck`: report echoed with tag `error` instead of `note` | yes (1) | yes |
| CS179b | `run_precheck`: refusal echoed with tag `note` instead of `error` | yes (1) | yes |
| CS179c | `run_precheck`: `if {$act eq {ok}} {return}` → `{nosuchaction}` | yes (1) | yes |
| CS179d | `run_precheck`: the `fold` arming guard dropped, so a fold request probes | yes (1) | yes |
| CS180 | `run_precheck`: the exe guard disabled (`if {0 && …}`) | yes (1) | yes |
| CS180b | exe guard widened with `\|\| requested eq {fold}` (a good exe refuses) | yes (2) | yes |
| CS180c | `run_composes_profile`: unknown backend → `return 1` | yes (1) | yes |
| CS181 | `run_deck`: a line opening+closing `<cell>_ase.spice` inserted BEFORE the gate | yes (1) | yes |
| CS181b | the "files … are from an earlier run" clause deleted from the refusal message | yes (1) | yes |
| CS182 | `run_deck`: `$casenote` dropped from the `run_done` callback | yes (1) | yes |
| CS182b | the fold early return made to emit a note; complement: made to drop notes | yes (4 / 2) | yes |
| CS183 | `run_done`'s 4th arg made mandatory — **pre-fix-round drive; subject untouched since** | yes (1) | yes |
| CS184 | `catch {winfo exists .x}` planted inside the new `run_mode_advice` | yes (1) | yes |
| CS185 | `run_profile`: `dropped [dict get $fa drop]` → `dropped {}` | yes (2) | yes |
| CS185b | `run_profile`: `status [dict get $r status]` → hard-coded `ok` | yes (3) | yes |
| CS186 | `run_filter_args`: each of the four `-o` spellings disarmed in turn | yes (2/1/1) | yes |
| CS186b | `run_precheck`: the dropped-args report disabled; and its tag flipped | yes (1) | yes |
| CS187 | `run_status_note`: `stale`, and separately `invalid`, stops reporting | yes (1 each) | yes |
| CS187b | `run_status_note`: status guard made unconditional (reports on every run) | yes (8, every silence check) | yes |
| CS188 | `run_mode_advice`: `set floor …` pinned to 0, and separately to 1 | yes (1 each) | yes |
| CS189 | `run_precheck`: `-cwd [ase::rundir $state]` → its parent directory | yes (1) | yes |
| CS190 | `run_deck`: the gate moved past `ase::cosim_clear_artifacts` | yes (1; **CS181 stayed green**) | yes |
| CS191 | `run_deck`: `if {[ase::run_composes_profile $sim]}` → `if {1}` | yes (1) | yes |

No check is unsabotaged. **Closer re-drive on the final tree**, because the fix round moved several subjects and most of the pre-fix drives were taken against the earlier code: CS178b, CS180, CS182 and CS189 re-mutated one at a time from the byte-exact backup (md5 `277f3d…`), each restored and md5-verified. Measured here: CS178b → `8 FAILED (30 passed)` (every refuse consumer, CS188/CS189/CS190 among them — more collateral than the pre-fix drive because the fix added consumers); CS180, CS182, CS189 → `1 FAILED (37 passed)` each, alone; every restore back to `RESULT: ALL PASS (38 checks)`.

**One edit has no red/green drive and is declared, not implied:** `full_audit.sh` +1 −1 (`test_sim_run_profile` → `nogui_tests`). The suite emits the identical verbatim RESULT line on both arms `full_audit.sh` can pick, so removing the entry would not change its audit status either. Inert, and consistent with its siblings `test_sim_probe`/`test_sim_profiles`.

## 5. What was NOT verified

- **No check runs a real simulator** — every launch in the suite is a `/bin/sh` stand-in. The real-binary evidence (both ngspices, the `.spiceinit` override runs, `v(MidNode)` vs `v(midnode)` read out of a binary raw, the `-o` measurement) was taken by hand and is recorded in §12 and the annex, not asserted.
- **`REFUSE` = "before anything is generated" is true of `run_deck`, not of `ase::run`**, which calls `ase::netlist` first, so a refusal through that entry point has already regenerated `<rundir>/<cell>.spice`. A *source* artifact `ase::run` always regenerates by design, never a result (§12.5) — but no check drives `ase::run`.
- **Declared side effects of a refusal:** `ase::rundir` mkdir's the run directory; `ase::last_run` still holds the *previous* run, so `ase::last_result` serves stale numbers; the previous raw/log are not deleted (the message says so). Nobody constructed a user who mistakes them for the refused run.
- **The fold-request blind spot** (§12.6): a `.spiceinit` turning a `fold` request into `preserve`/`distinguish` is never detected, because the gate is not armed for `fold`.
- **`-r`/`--rawfile` are kept and reach ngspice, but are inert on an ASE-L deck** — `render_deck` emits a `.control` block, so `-b -r` writes no raw here. Pre-existing; keeping them is still right.
- **No human has looked at the CIW strings.** Channel, tag and content are asserted and were read back out of a real run log, so the payload is not pixels — but whether the five-clause refusal paragraph *reads* sensibly is unanswered. Verifier and one reviewer both flagged it and both judged it non-blocking; no `owed.sh` look was filed. That is the cheap remedy if the driver wants it.
- **In the GUI a refusal appears twice** (gate echo + `ase::ui::do_run`'s own catch). Deliberate, item 13's to dedupe. The note is prepended to the run log *file*, not streamed into the live log *window*; the CIW pane still gets it.
- **`ase::run_precheck` is unreachable for any non-ngspice backend**, so the policy is unexercised there; `run_composes_profile` is the seam that would have to change. **Windows is not measured** (`auto_execok`, `/bin/sh` stand-ins, `file attributes -permissions`), exactly like item 7's suite.
- **`ase::sim_profile_resolve` calls `::set_sim_defaults`**, which this item puts on the ASE-L run path for the first time (3× per run). No reviewer could construct a reachable failure (needs Tk plus a row added without rebuilding widgets — item 13's). Flagged, not claimed.
- **Reviewer findings raised but not confirmed: none.** All eight confirmed findings were real and all eight are fixed here; none was refuted. The reviewers' not-proven list is the material above plus: malformed profile `args` (chased, *not* a defect — read-side validation makes `sim_profile_get` return the default), `eval execute` re-substitution (tested in tclsh, no injection), and that with the global floor set and no profile row the command is *not* the bare literal (`-D casemode=preserve` is added and a probe runs first, ~18 ms) — §12.3's stated ruling under B1's floor, a scope note, not a defect.
