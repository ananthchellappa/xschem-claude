# 08 — profile-aware `run_cmd`: ANNEX (long form)

**This is the ANNEX to `08-profile-aware-run-cmd.md`** — the same material at
full length: every ruling with its measurement, the fix round's eight findings,
and the complete mutation tables. The receipt is authoritative for the verdict;
this file is authoritative for the detail.

**Casemode batch ITEM 8.** Authority: `PLAN.md` §3b item 8 · `DECISIONS.md` **B1** (the command is built from the profile), **A2** (no `-n` by default), **B4** (requested ≠ measured: `preserve` reports and continues, `distinguish` **REFUSES**). Spec **extended, not replaced**: `doc/claude/specs/simulator_profiles.md` **§12** (item 6 owns §1–§10, item 7 owns §11). Base `54546db8`, branch `fluid-editing`. Consumes item 7's `ase::sim_probe_run` and item 6's `sim_profile_*` accessors. **Untouched:** `render_deck` (the deck's shape is sacred — CREW_BRIEF §4), `sod_expr` (item 9), the pre-flight / `$sim_status` guard / constants-raw rejection (item 10), `result_probe` (item 11), every widget (item 13), `ase::expand_path` (issue `0422`). No C, nothing built.

§3b's line number was stale twice over: `run_cmd` is at `ase.tcl:3782` now, not `3238` and not `3487`.

> **READ §6 FIRST if you are reading this after 2026-08-17.** A three-lens review
> of the delivered item confirmed **8 findings**, all real, all fixed in a fix
> round: `-o` was silently discarding every result, a `stale`/`invalid` profile
> silently ran a different binary, one citation named a `sim()` row that does not
> exist, the advice named a lever the session may not have, and three rulings
> stated in §12 in words were enforced by **no check** (the probe's cwd, the
> gate's position vs the cosim block, the composer guard at the call site).
> **30 → 38 checks.** §6 supersedes anything in §1–§5 that disagrees with it.

## 1. Files changed

| file | ± | what |
|---|---|---|
| `src/ase.tcl` | **+462 −5** (incl. the fix round) | 9 new procs — `ase::run_filter_args`, `run_safe_args`, `run_profile`, `run_casemode_flag`, `run_casemode_verdict`, `run_composes_profile`, `run_status_note`, `run_mode_advice`, `run_precheck`; `run_cmd` rewritten; the gate call in `run_deck`; `run_done` gains an **optional** `notes` argument |
| `doc/claude/specs/simulator_profiles.md` | **+388 −0** | **§12**, nine subsections, every ruling with its evidence |
| `tests/headless/full_audit.sh` | +1 −1 | `test_sim_run_profile` → `nogui_tests` |

New (untracked before this commit): `tests/headless/test_sim_run_profile.tcl` (**723 lines, 38 checks**, band **`CS175`–`CS191`**; `CS174` was the highest in use, grepped across `tests/headless/*.tcl`, not quoted from a doc), this receipt, and the closer audit.

The five deleted lines are the old one-line `run_cmd` and its two-line comment, plus `run_done`'s signature and its log-write line.

## 2. Decisions taken, and the evidence for each

Every ruling is in the spec with its measurement; §12 is named after each.

- **RULING — the compatibility contract is a CHECK, against the literal (§12.1).** With no profile the composed list is byte-identical to `[list ngspice -b $deckpath 2>@1]`. `CS175` compares against that literal **and** composes a configured row in the same assertion, so it cannot pass by the feature being absent. This is what keeps the batch's empty-audit contract.
- **RULING — the run filter is NOT `sim_probe_safe_args`, and must never become it (§12.2).** ~~Every reason that filter exists is about a *probe* (no side effects); a **real run legitimately needs `-r`/`-o`** — xschem's own shipped `sim(spice,1,cmd)` is `ngspice -b -r "$N.raw" -o "$N.out" "$N"`.~~ **SUPERSEDED BY THE FIX ROUND — see §6: that citation names a row that does not exist, and `-o` is now DROPPED (measured).** The surviving form of the ruling: a real run legitimately needs **`-r`** (xschem's shipped batch row `sim(spice,2,cmd)` is `ngspice -b -r "$n.raw" "$N"`, `xschem.tcl:4086`, and ships no `-o` anywhere). `ase::run_safe_args` drops exec-syntax redirection and pipeline words **plus the `-o`/`--output` family**, and that is a defect argument, not taste: `execute` does `open "|$args"`, so `>` empties `execute(data,$id)` (the log is written **empty** and `result_probe` finds nothing), a **bare** `>` eats the next word — and `run_cmd` appends the deck **last**, so ngspice would run with no deck (`CS177b`) — and `|` splices a foreign program into what we then call "the simulator" (`&` goes too, but see §6.2 F8: the reason first given for it was wrong). **`CS177c` is the anti-copy check**: it reads both filters on the same words and fails if they ever agree about an option. Mutation **M45** (wiring the probe's option lines into the run filter) is what reddens it.
- **RULING — `-D casemode=` only for a request that is not `fold` (§12.3).** Measured 2026-08-17 on `build-ver_50`: with **no `-D` at all**, `CCM=fold` — the case-capable build already defaults to fold; released ngspice-46 accepts and ignores the flag (A1); and a `.spiceinit` overrides `-D` anyway (A2). So the flag would change every existing user's command line and nothing else. **The global floor counts as a request** (`sim_case_mode` is documented as "the mode we ask a simulator for when no profile names one") — `CS176d`.
- **RULING — a row naming an exe we cannot locate REFUSES, in every mode (§12.4).** Not a fallback: the bare `ngspice` off `PATH` is a **different simulator**, and with `ver_50` having moved three times in four days "the configured exe is gone" is the normal case. `CS180` drives it under a **`fold`** request specifically, so the mode gate cannot reach it.
- **RULING — "not confirmed" is a REFUSAL under `distinguish` (§12.5).** B4's clause is "confirmed to support it", not "not known to fail". A timeout, an unlocatable exe, a probe that errored: all refuse (`CS178c`). This is what catches B4's own third route — the binary changing under the path — because a moved exe probes as `noexe`.
- **RULING — a mismatch that is not a `distinguish` REQUEST reports, never refuses (§12.5).** B4 scopes the refusal to the request, and only a `distinguish` request states "these nets are different", so only its downgrade merges anything. Asked-`fold`-got-`distinguish` can only *split*, which is item 10's absent-vector case.
- **WHAT REFUSE MEANS, CONCRETELY (§12.5).** The gate is called from `ase::run_deck` **before its first `open`** — before the netlist is read, before the cosim VCDs are deleted, before any `.so` is rebuilt, before the deck is written. So: no deck, no raw, no log, no VCD deleted, no process, no `last_run`, no callback; **and the message names the run directory and says anything in it is from an earlier run** (`CS181`, `CS181b`). Item 10 is about a file that *looks like* a result; a refusal that writes nothing cannot manufacture one.
- **RULING — the gate is armed only by a non-`fold` request (§12.6).** A1: the warning "never fires for a stock user". `CS179d` reads the stand-in's own **launch log**, so it measures launches, not an absence of output. Declared consequence: a `.spiceinit` that turns a `fold` request into `preserve` is not detected — detecting it means probing every ASE-L run forever to compare fold against fold.
- **RULING — the policy applies only where the ngspice composer runs (§12.6).** `ase::run_composes_profile` compares the backend's `run_cmd` **hook identity**, because the policy describes exactly what that proc builds. A test backend with its own `run_cmd` hardcodes its binary and reads no profile. A sixth registered hook was rejected: `register_backend` requires all five it knows.
- **THE REPORT REACHES THREE CHANNELS, none conditional on a window (§12.7)** — item 14's lesson that a channel can be correct and reach nobody. CIW pane (`::ase::echo … note` orange / `… error` red) **before** the simulator starts, the action log via the same call, and **the run log**, prepended by `ase::run_done`'s new optional `notes`. `CS182` reads the note back out of `<cell>_ase.log` after a real `execute`; `CS182b` is the control; `CS183` pins that a 3-argument `run_done` still works.

## 3. Test, checks, RESULT — *as delivered; §6.4 has the post-fix numbers*

`tests/headless/test_sim_run_profile.tcl`, true headless (`--nogui`), **30 checks**, verbatim:

**`RESULT: ALL PASS (30 checks)`**

**MASTER RED:** `src/ase.tcl` replaced by `git show HEAD:` → **`RESULT: 30 FAILED (0 passed)`**; restored from a byte-exact backup, `md5sum -c` clean, green again. **No skip arm exists** — every launch is a `/bin/sh` stand-in, so the file needs no ngspice at all and there is no substring `full_audit.sh` could score the whole file on.

Suites, `GUI_GATE=1 run_suites.sh` on `:99`: `test_sim_run_profile` 30, `test_sim_probe` 61, `test_sim_profiles` 97, `test_ase_cosim` 342, `test_wave_viewer` 400, `test_ase_persist`, `test_ase_print_bracket_0167`, `test_raw_case_mode` — **all PASS**. `--nogui`: `test_ase_core` 75, `test_ase_final` 28, `test_ase_final_gf180` 33, `test_cosim_golden_e2e` 46 — all PASS.

**One red that is NOT mine, A/B confirmed:** `test_ase_log_seam_0207` run through `run_suites.sh` gives `16 FAILED (10 passed)` — and **exactly the same 16/10 with `src/ase.tcl` reverted to `HEAD`**. It is a `logdir_tests` suite (its own header says so, `full_audit.sh:84`) and I invoked `run_suites.sh` **without** `--logdir`, so `PS0 action log open` fails and cascades. `full_audit.sh` runs it on the `--logdir` arm and scores it PASS.

**CLOSER AUDIT** — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped, load average 0.6 at the start, nothing else running → `doc/claude/casemode_batch/audit_item08_closer_2026-08-17.txt`:

```
SUMMARY: 325 pass  15 fail  0 crash/timeout  0 skip  (total 340)
WIREEDIT: PASS    SCRATCH:  0 leaked dir(s)
TREE:     1 appeared  0 vanished (report only, gitignored paths excluded)
```

The one `TREEADD` row is this receipt, written while the audit ran; no source or test file moved (`md5` of `src/ase.tcl` and `test_sim_run_profile.tcl` identical before and after).

**DIFF vs `audit_item07_closer_2026-08-17.txt` (324/15/0/0 of 339, at `ebf4c952`), by NAME and STATUS: rows only in the baseline — NONE. Rows only in mine — `test_sim_run_profile` (PASS), this item's new suite. Status changes in EITHER direction — NONE, zero rows moved.** The 15 reds are the same 15 names the batch policy lists, compared as sorted lists; **`test_ase_core` is PASS**, as the contract requires. Counted with a differ matching only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so the six within-file `FAIL | key …` detail lines cannot be miscounted as rows; self-checked by diffing the baseline against itself (339 rows, 324/15, zero changes).

## 4. Sabotage — one row per check, 46 mutations, no survivors

Each mutation is an exact literal replacement **asserted to hit exactly once** (a silently-missed patch would otherwise read as "nothing went red"), applied over a byte-exact backup — never `git checkout`, which would delete the uncommitted item — run, restored, restore `md5`-verified. Driver: `…/scratchpad/item08/mutate.py`. **No check is unsabotaged**; all 30 ids appear below, verified by set difference.

| mutation | checks reddened |
|---|---|
| **M01 `run_cmd` returns the old hardcoded literal** | CS175 CS176 CS176b CS176c CS176d CS176e CS177b CS182 CS182b |
| M02 no bare-`ngspice` fallback · M03 args never spliced | CS175 · CS176 CS176e CS177b |
| M04 `-n` unconditional · M05 `-n` never | CS175 CS176b CS176c CS176d CS177b · CS176 CS176b CS176e |
| **M06 `-D` emitted for `fold` too** · M07 the global floor ignored | CS175 CS176c CS176d CS177b · CS176d |
| M08 the deck placed before the args | CS175 CS176 CS176b CS176c CS176d CS176e CS177b |
| **M09 `run_profile` routed through `sim_probe_safe_args`** | CS176 CS176e CS185 |
| M10 the run filter drops nothing · M11 a bare redirection keeps its operand · M12 `|` no longer ends the words | CS177 CS177b CS185 · CS177 · CS177 CS185 |
| **M13 a `distinguish` mismatch reports instead of refusing** | CS178b CS178c CS179b CS181 CS181b |
| **M14 "nothing measured" is OK** · M15 a `preserve` mismatch refuses | CS178c CS178d CS178f · CS178 CS178d CS179 CS182 |
| M16 a `fold` request compared too · M17/M18 the reason text flattened | CS178e · CS178f |
| **M19 the probe armed for `fold` too** · M20 the gate never probes | CS179d · CS179 CS179b CS179c CS179d CS181 CS181b CS182 |
| **M21 the exe check deleted** · **M22 the exe check gated on the mode** | CS180 · CS180 |
| M23 the report tagged `result` not `note` · M24 the refusal echoes but does not raise · M25 it raises but does not echo | CS179 · CS179b CS181 CS181b · CS179b |
| **M27 the gate moved after the deck is written** · M28 the gate never called · M29 `run_composes_profile` always 0 · M30 always 1 | CS181 CS181b CS182 · CS181 CS181b CS182 · CS180c CS181 CS181b CS182 · CS180c |
| M31 the log note not prepended · M32 appended instead · M33 the note not passed to `run_done` · M43 `notes` made mandatory | CS182 CS183 · CS182 CS183 · CS182 · CS183 |
| M34 `exe_named` always 0 · M35 args unfiltered in `run_profile` · M36 `nospiceinit` not read · **M37 `requested` hard-coded `fold`** | CS180 CS185 · CS177b CS185 · CS176 CS176b CS176e CS185 · CS176 CS176c CS176d CS176e CS179 CS179b CS179c CS179d CS181 CS181b CS182 CS185 |
| M38 a `winfo` planted in `run_precheck` · **M39 TEST: the no-Tk detector blinded** | CS184 · CS184 |
| M41 the refusal stops naming the rundir · M42 the gate echoes on agreement · M44 the gate always reports | CS181b · CS179c · CS179 CS179b CS179c CS180b CS182b |
| **M45 the PROBE's option filter wired into the RUN filter** (the anti-copy) · M46 `run_profile` reports `status ok` always | CS176 CS176e **CS177c** CS185 · **CS185b** |

Two mutations were rejected by the driver's own hit-count assertion and rewritten rather than reported as green: an earlier `M36` matched a literal that also appears inside `ase::sim_probe_run`, and `M26` (deleting the `auto_execok ngspice` fallback inside the gate) moves no check because every row in the suite carries an exe — it is **not** in the table, and its absence is disclosed here rather than papered over.

## 5. What was NOT verified

- **No real simulator ran in a check.** Every launch is a `/bin/sh` stand-in, deliberately — the suite must run on a machine with no ngspice. The one real measurement, `build-ver_50` with no `-D` answering `CCM=fold`, was taken by hand (`printf` deck + `-b`) and is recorded in spec §12.3, not asserted. **No mixed-case run was performed**, so "`preserve` really does keep the capitals in this pipeline" is inherited from items 1–5, not re-measured here.
- **The probe's argv and the run's argv differ by exactly the output-directing options** (`-r`, `-o`, `--rawfile`, `--soa-log`), because the probe filters them and the run does not. Nothing about those options can change a case mode, so A2's "probe with the real argv" holds in substance — but it is *not* byte-identical, and that is stated in §12.8 rather than hidden.
- **The `fold`-request blind spot is real and declared:** a `.spiceinit` that turns a `fold` request into `preserve` or `distinguish` is never detected, because the gate is not armed. §12.6 says so; the alternative is a probe on every ASE-L run forever.
- **The GUI shows a refusal TWICE** — once from the gate's echo, once from `ase::ui::do_run`'s own catch of the raised error. Deliberate (the gate's copy is the only channel a scripted caller has, and the only one that reaches the action log when the caller swallows the error), recorded in §12.7, and left for item 13 to dedupe in the UI.
- **The refusal does not delete the previous run's artefacts.** Writing nothing new is what this item owes; recognising a bad artefact on read is item 10's. A user who refuses a run and then opens the viewer sees the *earlier* run's raw — the refusal message says so in words, and nothing more is done about it here.
- **The refusal DOES create the run directory**, because `ase::rundir` is what names it in the message and that proc `file mkdir`s. An empty directory is not an artefact anything can read as a result, and `run_deck` was about to create it a few lines later anyway — but it is a side effect on a refusal path and is stated rather than left to be discovered.
- **`ase::run_precheck` is never reached by a non-ngspice backend**, so the whole policy is unexercised for any future backend; `run_composes_profile` is the seam that would have to change.
- **Windows is not measured** (`auto_execok`, `/bin/sh` stand-ins, `file attributes -permissions`); the suite is Linux-flavoured exactly like item 7's.
- **No eyeball owed** — no pixels here. The CIW line's *wording* is a user-visible string, but its channel and content are asserted; item 13 owns every widget. `owed.sh` untouched.

---

# 6. FIX ROUND (post-review) — 8 confirmed findings, all fixed

A three-lens review of the delivered item raised **8 confirmed findings** (0 raised-but-unconfirmed). All eight were real; **none was refuted**. This section records what changed. The suite went **30 → 38 checks**; nothing was removed, three existing checks were **restated** (their subject moved), and every touched or new check has a mutation that drives it red.

## 6.1 The two behaviour changes

**F1 — `-o` / `--output` silently discarded every result (major).** `ase::run_safe_args` deliberately passed the whole `-o` family through, on the theory that "a real run legitimately needs `-r` and `-o`". `-o` **redirects the stdout ASE-L parses**, so a profile carrying it produced exit 0, a banner-only `<cell>_ase.log`, **zero parsed results and no diagnostic** — the exact "runs fine and reports nothing" failure that same filter's comment cites as the reason redirections are dropped. Re-measured here on the real `/usr/local/bin/ngspice`:

```
ngspice -b d.cir          -> v(a) = 1.000000e+00        (on stdout)
ngspice -b -o o.log d.cir -> "Comments and warnings go to log-file: o.log"
                             (the numbers are in o.log)
```

and end to end through `ase::run_deck` + `ase::wait`, same circuit, same state, profile row the only difference:

| profile `args` | before the fix | after the fix |
|---|---|---|
| *(none)* | `result=<va 1.000000e+00>`, log 396 B | unchanged |
| `-o <rundir>/out.log` | **`result=<>`**, log 626 B of banner | `result=<va 1.000000e+00>`, log 903 B, `-o` dropped and reported |
| `-r <rundir>/extra.raw` | `result=<va 1.000000e+00>` | unchanged — `-r` is **kept** |
| `--output=<file>` | **`result=<>`** | `result=<va 1.000000e+00>`, dropped and reported |

**Fixed by dropping the `-o` family, and reporting the drop** (not by reading the `-o` file back: that would make ASE-L's parse depend on a path the user chose, and `run_cmd`'s own doc comment still says the stdout must flow into `execute(data,$id)`). All four spellings go — `-o <f>`, `--output <f>`, `--output=<f>`, `-o<f>`. `-r` / `--rawfile` / `--soa-log` are **kept**, measured harmless, and `CS177c` still proves the run filter is not the probe filter using exactly those words. **Ruling in spec §12.2; checks `CS186` (all four spellings + the `-r` control, driven through the composed command) and `CS186b` (the drop is reported, with the `-r` control).**

**F3 — a `stale` / `invalid` profile silently ran a different binary (major).** `ase::run_profile` computed the resolve `status` and **no consumer read it**, so a row renamed or inserted-above re-pointed the session at another executable with not one word to the user — the harm item 8's own refusal message names, and the decision item 6's spec had explicitly delegated here ("item 8 decides whether to run it"). **Ruled: REPORT, not refuse** — the exe guard refuses because its case has no run left in it, whereas here a real, locatable, configured simulator *is* resolved, and §5 already rules that a hand-edited `simrc` must not make a saved session unopenable. The mode cannot be smuggled past B4 either, because the probe measures the binary that will actually run. **Ruling in spec §12.9; checks `CS187` (stale names the stamped name, the current name and the exe; invalid names the missing index) and `CS187b` (an `ok` resolve says **nothing** — the control).** Driven live against two real binaries: a state stamped `Ngspice ver_50` whose row came to read `Ngspice 46` ran, produced `va 1.000000e+00`, and put the substitution line on the CIW **and** at the head of `cell_ase.log`.

## 6.2 The two wording / citation corrections

**F2 — the load-bearing citation named a row that does not exist (minor).** The sole justification for keeping `-o` cited `sim(spice,1,cmd)` as `ngspice -b -r "$N.raw" -o "$N.out" "$N"`. Verified false: `sim(spice,1,cmd)` is `{ngspice "$N" -a}` ("Ngspice Control mode", `xschem.tcl:4080`), the shipped batch row is `sim(spice,2,cmd)` = `{ngspice -b -r "$n.raw" "$N"}` (`:4086`) with **no `-o`**, and `grep -rn '\$N\.out' src/` matched exactly one line — the comment making the claim. Corrected in `ase.tcl` (the filter's comment and `run_cmd`'s), in spec §12.2 (with the correction recorded, not silently rewritten), and in §2 of this receipt. Once corrected the surviving justification covers `-r` only, which is also the only one of the two that measures harmless — so F1 and F2 resolve the same way.

**F4 — the advice named a lever the session does not have (minor).** On the global-floor path (no profile row; the mode from `sim_case_mode` in an rc) both messages said "point the profile at…" / "turn on the profile's `-n`". There is no row to point and no checkbox to turn on. The clause now branches on the resolve status and names `sim_case_mode` instead. **Ruling in spec §12.5; check `CS188`**, which drives the floor path with a real refusal *and* a real report and asserts the string does **not** contain "the profile's -n" — a leg that had **no coverage at all** before.

**F8 — the `&` branch's stated reason was wrong (minor).** `&` only backgrounds a Tcl pipeline as the **last** word, and `run_cmd` always appends the deck and `2>@1` after the filtered args, so "detaches it so EOF never arrives" cannot happen. The word is still dropped — ngspice would otherwise be handed a literal `&` as an argument — and the comment now says that. `&` added to `CS177`'s input list (one word, zero new checks); mutation **F06** reddens it.

## 6.3 The three coverage holes (rulings stated in words, enforced by nothing)

Each of these survived its own mutation with 30/30 green in the delivered item, and each mutation changes real behaviour.

| finding | the mutation that used to stay green | the check that now catches it |
|---|---|---|
| **F5** the probe's **cwd** | `-cwd [ase::rundir $state]` → `-cwd [file dirname …]` — a `distinguish` REFUSE becomes a silent run under a folding `.spiceinit` | **`CS189`** — a stand-in that answers `CCM=fold` with a `.spiceinit` in **its own cwd** and `CCM=distinguish` without one; marker planted in the rundir, the verdict flips. Every other stand-in in the file answers the same mode from anywhere, which is why nothing could see the cwd |
| **F6** the gate's **position** vs the cosim block | the gate moved to just after `ase::cosim_clear_artifacts` — a refused run **deletes the previous run's cosim map** (`cosim_save_map` `file delete`s the sidecar for an empty map) | **`CS190`** — a netlist carrying a real `.model … d_cosim` card, with `<cell>_ase.cosim` and `<cell>_dblk.vcd` planted from an "earlier run"; both must survive. Verified: that exact mutation now reds `CS190` **alone**, `CS181` stays green — so `CS190` is strictly wider, which was the complaint |
| **F7** the composer guard **at the call site** | `if {[ase::run_composes_profile $sim]}` → `if {1}` — a foreign backend gets refused over a profile exe it never runs; both `test_sim_run_profile` (30) and `test_ase_core` (75) stayed green | **`CS191`** — registers a second backend with its own `run_cmd` (all five hooks), gives the *spice* profile an unlocatable exe, and asserts `ase::run_deck` runs it to exit 0 with no refusal and no casemode line |

## 6.4 Sabotage — the fix round, 32 mutations, no survivors

Every check the fix touched or added, plus every check whose **subject** the fix changed. Byte-exact backup `…/scratchpad/fixr/ase.tcl.fixgood` (`md5 277f3d8581e74924b856e1d638f29fb9`); each literal asserted to occur **exactly once**; restored and md5-verified after every mutation. Driver: `…/scratchpad/fixr/mut.py`, `mut2.py`.

| # | what was broken | red |
|---|---|---|
| F01 | filter: `-o` / `--output` word test disarmed | CS186, CS186b |
| F02 | filter: `^--output=` disarmed | CS186 |
| F03 | filter: `^-o.` (attached form) disarmed | CS186 |
| F04 | filter drifted back toward the probe's — `-r`/`--rawfile` dropped too | CS176, CS176e, CS177, **CS177c**, CS186, CS186b, CS185 |
| F05 | `run_safe_args` body replaced by `sim_probe_safe_args` (the anti-copy mistake) | CS177, **CS177c** |
| F06 | the `&` branch disarmed | CS177 |
| F07 | `run_profile` reports `dropped {}` | CS186b, CS185 |
| F08 | the dropped-args report suppressed | CS186b |
| F09 | the dropped-args report emitted with tag `error` | CS186b |
| F10 | status note stops firing for `stale` | CS187 |
| F11 | status note stops firing for `invalid` | CS187 |
| F12 | status note computed and thrown away | CS187 |
| F13 | status note fires on **every** run | CS186b, CS179, CS179b, CS179c, CS180b, **CS187b**, CS182, CS182b |
| F14 | stale note loses the stamped name | CS187 |
| F15 | stale note stops naming the binary that will run | CS187 |
| F16 | advice never takes the floor branch | CS188 |
| F17 | advice always takes the floor branch | CS188 |
| F18 | probe cwd → the rundir's **parent** | **CS189** |
| F19 | the gate deleted from `run_deck` entirely | CS181, CS181b, CS190, CS182 |
| F20 | the composer guard → `if {1}` | **CS191** |
| F21 | the `fold` early return drops the accumulated notes | CS186b, CS187 |
| F22 | `winfo` planted in `ase::run_mode_advice` | CS184 |
| F23 | profile args and `-n` swapped in `run_cmd` | CS176 |
| F24 | **the reviewer's own mutation**: gate moved past `cosim_clear_artifacts` | **CS190** (and CS181 stays green — the point) |
| F25 | the `fold` early return emits a bogus note | CS186b, CS187, CS187b, **CS182b** |
| F26 | `run_profile` hard-codes `status ok` | CS187, CS188, **CS185b** |
| F27 | `run_profile` bypasses the filter entirely | CS177b, CS186, CS186b, CS185 |
| F28 | the no-profile `ngspice` fallback renamed | **CS175** (the compatibility contract) |
| F29 | `-n` gate inverted in `run_cmd` | CS175, CS176, **CS176b**, CS176c, CS176d, CS176e, CS177b, CS186 |
| F30 | `-D casemode=` hard-coded to `preserve` | **CS176c** |
| F31 | B4's `report` verdict downgraded to `ok` | **CS178**, CS178d, CS179, CS188, CS182 |
| F32 | `run_casemode_flag` stops reading the resolved profile | CS176, **CS176c**, CS176d, CS176e |

F29–F32 are the **untouched-but-adjacent** family: their subject was not changed by the fix, but the fix rewrote the proc around them (`run_profile` now returns a wider dict, `run_precheck` now accumulates notes), so they were re-driven rather than assumed. Every one of the 38 check ids appears in at least one red column across F01–F32.

**MASTER RED (re-run):** `src/ase.tcl` replaced by `git show HEAD:` → **`RESULT: 37 FAILED (1 passed)`**; restored from the byte-exact backup, md5 clean, **`RESULT: ALL PASS (38 checks)`** again.

## 6.5 What the fix round did NOT change

- **`render_deck` is still byte-identical.** No deck shape moved (CREW_BRIEF §4).
- **The compatibility contract is untouched and still checked against the literal** (`CS175`, mutation F28): with no profile the composed list is still exactly `[list ngspice -b $deckpath 2>@1]`.
- **`-r` still reaches the simulator**, verified end to end on the real binary. (It is *inert* on an ASE-L deck, because a `.control` block kills `-b -r` — a pre-existing, already-documented property of `render_deck`, not something this item changed.)
- **The remaining declared limits of §5 stand**, minus the two the fix round closed: the "probe argv vs run argv" gap is now `-r`/`--rawfile`/`--soa-log` only, and the refusal's artefact guarantee is now checked for the cosim sidecar and the VCD as well as the deck and the log.
- **The non-blocking notes the verifier recorded are still true and still not acted on:** `ase::run` regenerates `<rundir>/<cell>.spice` before `run_deck` is reached (a source artifact, by design), and the GUI shows a refusal twice (item 13's to dedupe).

## 6.6 Suites and the closer audit, re-run after the fix

`GUI_GATE=1 tests/headless/run_suites.sh` on `:99` (never `GUI_GATE=0`, never a bare loop):

```
PASS | test_sim_run_profile   RESULT: ALL PASS (38 checks)
PASS | test_sim_probe         RESULT: ALL PASS (61 checks)
PASS | test_sim_profiles      RESULT: ALL PASS (97 checks)
PASS | test_ase_cosim         RESULT: ALL PASS (342 checks)
PASS | test_cosim_golden_e2e  RESULT: ALL PASS (46 checks)
PASS | test_wave_viewer       RESULT: ALL PASS (400 checks)
RESULT: 6/6 runs passed
```

On the `--nogui` arm `full_audit.sh` actually uses: `test_ase_core` **75**, `test_ase_final` **28**, `test_ase_final_gf180` **33**, `test_ase_persist` **17**, `test_ase_window` **31** — all `ALL PASS`. (`test_ase_cosim` is the one that proves `run_done`'s 4th argument is still optional: it calls the proc with three arguments in six places.)

**CLOSER AUDIT (fix round)** — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped → `doc/claude/casemode_batch/audit_item08_fixround_2026-08-17.txt`:

```
SUMMARY: 325 pass  15 fail  0 crash/timeout  0 skip  (total 340)
WIREEDIT: PASS    SCRATCH: 0 leaked dir(s)    TREE: 0 appeared  0 vanished
```

**DIFF against `audit_item07_closer_2026-08-17.txt` (324/15/0/0 of 339 at `ebf4c952`), by NAME and STATUS, both directions:**

```
baseline rows=339   mine rows=340
ONLY IN BASELINE: NONE
ONLY IN MINE:     [('test_sim_run_profile', 'PASS')]     <- this item's own suite
STATUS CHANGES:   NONE
```

The 15 reds are the policy's 15 names, character for character, unchanged. `test_ase_core` is **PASS**. Matched with `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+(test_\S+)\s*$`, so the six within-file `FAIL | key …` detail lines cannot be miscounted.
