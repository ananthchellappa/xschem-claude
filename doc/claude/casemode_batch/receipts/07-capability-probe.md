# 07 — the capability probe, the run probe, and the mandatory hard timeout

**Casemode batch ITEM 7.** Authority: `PLAN.md` §3b item 7 · `DECISIONS.md` **B3** (the two probes + the hard timeout), **A1** (offer only what the binary can deliver), **A2** (`.spiceinit` overrides — ask, never guess). Spec **extended, not replaced**: `doc/claude/specs/simulator_profiles.md` **§11** (item 6 owns §1–§10). Base `ce1fe3b5`, branch `fluid-editing`. Long-form detail — the transport measurements, both `.spiceinit` layers, the fix round's six code and four evidence defects, both complete mutation tables — is in **`07-capability-probe-annex.md`**. **Untouched:** `run_cmd` (item 8), every widget (item 13), `ase::expand_path` (issue 0502). No C, nothing built.

## 1. Files changed

| file | ± | what |
|---|---|---|
| `src/xschem.tcl` | **+576 −0** | **11 procs** (`sim_probe_timeout_ms` / `_kill` / `_tmpdir` / `_deck` / `_safe_args` / `_argv` / `_parse` / `_once`, `sim_profile_probe_once` / `_autoprobe_ok` / `_capability`) + `set_ne sim_probe_timeout 5000` |
| `src/ase.tcl` | **+104 −0** | `ase::sim_probe_run` — the ASE-L run probe, item 8's caller |
| `doc/claude/specs/simulator_profiles.md` | **+559 −0** | **§11**, eleven subsections, every ruling with its measurement |
| `tests/headless/full_audit.sh` | +1 −1 | `test_sim_probe` → `nogui_tests` |

`git diff --numstat`, four tracked files, **+1240 −1**; both source diffs are **pure additions — zero deleted lines**. New (untracked before this commit): `tests/headless/test_sim_probe.tcl` (**896 lines, 61 checks**, band `CS167`–`CS174`; `CS166` was the highest in use, grepped across `tests/headless/*.tcl` rather than quoted from a doc), this receipt + annex, and three audit files (`audit_item07_2026-08-17.txt` — the pre-fix-round cut, kept for provenance — `_fixround_`, and `_closer_`, this one).

## 2. Decisions taken, and the evidence for each

Every ruling is written into the spec with its measurement; the section is named after each.

- **RULING — there are TWO probes, and §3b's row is self-contradictory (§11.1).** §3b calls this "the capability probe" and specifies **cwd = the deck's directory**; at registration there is no deck. B3 draws the line ("*B3 is only about the first*"). Built as **one mechanism parameterised by cwd**, with both callers: `sim_profile_probe_capability` (xschem.tcl, fresh empty temp dir, **records** `detected`+`probed`) for item 13, and `ase::sim_probe_run` (ase.tcl, the **deck's own directory**, **records nothing** — `CS170i`) for item 8. Building only one would have blocked one of those items.
- **RULING — A1's open question resolved (b): probe EACH mode, three invocations (§11.3).** Rejected: "`$curcasemode` exists ⇒ all three work". `$curcasemode` reports the *current* mode, never the supported *set*, and A1 is about what a *request* yields; item 3's measured wrong-case-**key** silent ignore and A2's `.spiceinit` override are both request-vs-measurement failures presence-implies-support cannot see. `CS169h`/`CS173d`/`CS173e`; the rejected design, wired, reddens them (M22/MU/MF).
- **RULING — `no such variable` is an ANSWER, recorded as `detected {fold}` (§11.4), and for the run probe it is a MEASURED delivery of `fold` (§11.10).** Stock replies `Error: curcasemode: no such variable.` **and** an empty `CCM=`; both halves required. This is A1's own clause; recording `{}` would offer the ordinary `apt install` user nothing. Not a B2b breach — B2b governs *no answer*. The first cut had the two probes disagreeing about the same bytes (`detected {fold}` vs `agree {}`) for the commonest real mismatch there is; the new `delivers` field settles it. `CS171`, `CS173k`, `CS170l`.
- **RULING — a TIMED-OUT leg never contributes a mode, and invalidates the WHOLE measurement (§11.5).** New status **`partial`**, never recorded, `timedout` carried out beside it. The first cut recorded a partial as `ok`, so one transient stall permanently narrowed the row — and with `fold` stalled, claimed the row could not deliver the global default. `CS173f`, `CS169j`, `CS170g`.
- **RULING — the transport is a batch deck, not §3b's `-p` pipe (§11.2).** Measured live, mid-item: `ngspice -p` opens `$DISPLAY`; on an exhausted server it exits with **no answer**, with `DISPLAY` unset it **dumps core**, on `:99` it answers. A three-mode binary was reporting as supporting none because X was busy. `-b <abs deck>` answers identically under all three and is nearer the real run. `CS170n` pins all three conditions; reverting to `-p` reddens it.
- **RULING — the hard timeout is Tcl-native and bounds the WHOLE probe (§11.6).** `open |…` + non-blocking read + `after 5` deadline poll + **kill before close**. Rejected `timeout(1)` (GNU-only; this tree ships on Windows) and `fileevent`+`vwait` (re-entrancy inside item 13's modal dialog). The first cut's timeout was per **leg** — 3 × 5000 = **15016 ms** frozen, the exact outcome B3 mandated it to prevent; now one budget, re-measured **5006 ms, `legs 1`**. Driven by actually hanging it: a stand-in (`CS169b`) and a **real** ngspice (`CS170f`, `CS173g`).
- **RULING — a profile's `args` are FILTERED before they reach a probe (§11.2).** The argv is spliced into Tcl exec syntax: `args {> zap.txt}` wrote a file into the probe's cwd — the user's own rundir for a run probe — and `args {| cat}` swallowed the answer, recorded as "delivers nothing"; `-r`/`-o` (xschem's own shipped batch shape) made the run probe **overwrite the previous run's outputs**. `sim_probe_safe_args` drops redirections and output-directing options. `CS173`/`CS173b`/`CS173i`/`CS174`. Two hygiene rulings ride with it: the probe deck never lands in the caller's cwd and the child's stdin is the **null device** (§11.2, `CS169p`/`CS169q`); `sim_probe_tmpdir` needs a per-process **counter** and `file normalize` — `file mkdir` succeeds silently on an existing dir, so two calls in one millisecond shared one and the second's cleanup deleted the first's (§11.7, `CS173c`).

## 3. Test, checks, RESULT

`tests/headless/test_sim_probe.tcl`, true headless (`--nogui`), **61 checks**, verbatim:

**`RESULT: ALL PASS (61 checks)`**

**MASTER RED:** both source files replaced by `git show HEAD:` → `RESULT: 61 FAILED (0 passed)`, restored from a byte-exact backup, `md5sum -c` clean, green again. **SKIP-NOT-FAIL:** `NGSPICE_CASE_TEST=/no/such/ngspice` → **`RESULT: ALL PASS (46 checks)`**, with **no column-0 skip banner**, so `full_audit.sh` cannot score the file SKIP and discard the checks that ran. (This receipt said **33** twice and it was never 33 — 35 at the first cut, 46 now that 11 of the 12 fix-round checks are stand-in-driven. Measured, not computed.)
Suites, `GUI_GATE=1 run_suites.sh` on `:99`: `test_sim_probe` 61, `test_sim_profiles` 97, `test_ase_cosim` 342, `test_raw_case_mode` 277 — **4/4 PASS**. `test_ase_core` `--nogui` (the arm `full_audit.sh` uses): `ALL PASS (75 checks)`.

**CLOSER AUDIT** — `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped, load average 0.10 at the start, nothing else running → `doc/claude/casemode_batch/audit_item07_closer_2026-08-17.txt`:

```
SUMMARY: 324 pass  15 fail  0 crash/timeout  0 skip  (total 339)
WIREEDIT: PASS    SCRATCH:  0 leaked dir(s)
TREE:     1 appeared  0 vanished (report only, gitignored paths excluded)
```

The one `TREEADD` row is `receipts/07-capability-probe-annex.md`, written by the closer while the audit ran; no source or test file moved (`md5`s of `src/xschem.tcl`, `src/ase.tcl` and `test_sim_probe.tcl` identical before and after). **DIFF vs `audit_item06_closer_2026-08-17.txt` (323/15/0/0 of 338, at `169495a4`), by NAME and STATUS: rows only in the baseline — NONE. Rows only in mine — `test_sim_probe` (PASS), this item's new suite. Status changes in EITHER direction — NONE, zero rows moved.** The 15 reds are the same 15 names the batch policy lists; `test_ase_core` is **PASS**, as the contract requires. Counted with a differ matching only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so the six within-file `FAIL | key …` detail lines cannot be miscounted as rows; self-checked by diffing the baseline against itself (338 rows, 323/15, zero changes). The fix round's own audit file, over identical source `md5`s, diffs the same way.

## 4. Sabotage — one row per check, 69 mutations over two rounds, no survivors

Each mutation is an exact literal replacement asserted to hit **exactly once**, applied over a byte-exact backup (never `git checkout` — that would delete the uncommitted item), run, restored, restore `md5`-verified; suite green before and after. Drivers: `…/scratchpad/item07/mutate.py` (47) + `…/scratchpad/fix07/mutate.py` (22). **No check is unsabotaged** — the 61 ids below are the complete set in the file, verified by set difference. **Four first-cut mutations came back GREEN; each exposed a real test defect, all four fixed and re-driven red** (annex §7): `CS169c` re-took its `[pwd]` baseline too late; nothing exercised the run probe on a *failed* probe (`CS170m` added); `CS169q`'s stand-in merely drained stdin; two checks were vacuous against a *missing* proc. **`CS170e`'s `home_restored` and `CS170n`'s `display_restored` terms were DROPPED, not repaired** — each re-read a variable the test itself set two lines earlier with no product code in between, so they could never fail (§11.8).

| check | what was broken | red? | restored green? |
|---|---|---|---|
| CS167 | parse regexp anchors dropped (**the echo trap**) | yes | yes |
| CS167b | same, echo line alone then answers `CCM=` | yes | yes |
| CS167c | the `ngspice N ->` prompt-strip `regsub` deleted | yes | yes |
| CS167d | `nocasemode` regexp broken | yes | yes |
| CS167e | the two-halves condition weakened to `&& 1` | yes | yes |
| CS167f | `sim_casemode_valid` gate removed (any word is a mode) | yes | yes |
| CS167g | only the first output line scanned | yes | yes |
| CS167h | trailing `\r` no longer trimmed | yes | yes |
| CS168 | `-b` dropped from the argv | yes | yes |
| CS168b | `-n` appended before the profile args | yes | yes |
| CS168c | `-D casemode=` appended unconditionally | yes | yes |
| CS168d | the `nospiceinit` test inverted | yes | yes |
| CS168e | the explicit-timeout branch disabled | yes | yes |
| CS168f | built-in default 5000 → 6000 | yes | yes |
| CS169 | the parse copy into the result dict deleted | yes | yes |
| CS169b | the kill before `close` removed | yes | yes |
| CS169c | the `cd` restore after a successful `open` deleted | yes | yes |
| CS169d | a failed `open` reports `ok` | yes | yes |
| CS169e | a bad cwd ignored instead of erroring | yes | yes |
| CS169f | the record gate accepts every outcome | yes | yes |
| CS169g | the `break` after the `nocasemode` short circuit removed | yes | yes |
| CS169h | **presence-implies-support (the REJECTED design)** | yes | yes |
| CS169i | the record gate additionally requires a non-empty measurement | yes | yes |
| CS169j | a timed-out leg contributes its parsed mode | yes | yes |
| CS169k | the auto-probe name gate returns 1 unconditionally | yes | yes |
| CS169k2 | that gate reads the whole path, not `file tail` | yes | yes |
| CS169l | the private temp dir left behind | yes | yes |
| CS169m | an unknown option silently ignored | yes | yes |
| CS169n | a row with no `exe` reports `ok` | yes | yes |
| CS169o | the profile `args` never spliced into the argv | yes | yes |
| CS169p | the deck written into the caller's cwd | yes | yes |
| CS169q | `< $devnull` removed (child inherits our stdin) | yes | yes |
| CS170 | only the `fold` leg probed | yes | yes |
| CS170b | same (legs 3 → 1) | yes | yes |
| CS170c | the `nospiceinit` test inverted, so `-n` never reaches ngspice | yes | yes |
| CS170d | the mode never asked for (`-D` never appended) | yes | yes |
| CS170e | same, against a `HOME`-scoped `.spiceinit` | yes | yes |
| CS170f | the kill removed, against a **real** hanging ngspice | yes | yes |
| CS170g | the record gate accepts a timed-out outcome | yes | yes |
| CS170h | the run probe's `-deck` branch removed | yes | yes |
| CS170i | the run probe made to record `detected` | yes | yes |
| CS170j | `requested` hard-coded to `fold` | yes | yes |
| CS170k | the profile's `nospiceinit` forced to 0 | yes | yes |
| CS170l | the `noexe` early return / its `delivers` key deleted | yes | yes |
| CS170m | `agree` set to 0 where nothing was measured | yes | yes |
| CS170n | **transport reverted to §3b's `-p` pipe** | yes | yes |
| CS171 | `nocasemode` regexp broken (released ngspice records nothing) | yes | yes |
| CS171b | same, the `nocm` half | yes | yes |
| CS172 | a `winfo` planted in a probe proc (the no-Tk detector) | yes | yes |
| CS173 | the pipeline separator no longer ends the filtered words | yes | yes |
| CS173b | output-directing options pass through the filter | yes | yes |
| CS173c | `$TMPDIR` no longer `file normalize`d | yes | yes |
| CS173d | **every leg asks the profile's single mode** (rejected design, three invocations) | yes | yes |
| CS173e | same, plus presence-implies-support | yes | yes |
| CS173f | **a partial measurement reports `ok` and is recorded** | yes | yes |
| CS173g | **the timeout is per leg again** (3 × 5000) | yes | yes |
| CS173h | the capability probe's `-cwd` made a no-op | yes | yes |
| CS173i | output-directing options pass through (stand-in writes the user's file) | yes | yes |
| CS173j | the run probe's `-exe` and `-args` made no-ops | yes | yes |
| CS173k | **`nocasemode` delivers nothing** instead of `fold` | yes | yes |
| CS174 | same filter break, driven with the **real** `build-ver_50` over a live rundir | yes | yes |

## 5. What was NOT verified

- **Windows is written, not measured**: `sim_probe_kill`'s `taskkill` arm, the `NUL` null device, `sim_probe_tmpdir`'s `C:/Windows/Temp` fallback. **The kill reaches the direct child, not its grandchildren** — a wrapper `exe` that does not `exec` would orphan its simulator (§11.6, declared, unfixed; a process-group kill is the real answer and stays out of scope because the child is not in its own group, so killing the group would kill xschem). The suite's own 8 orphans per run are gone (the stand-ins now `exec`); `CS170f`'s real ngspice still leaves **3 `sh -c sleep 25`** per run, inherent to that limit.
- **The 64 KB output cap and its `truncated` flag are undriven** (nothing in reach is chatty enough), so whether an answer printed after 64 KB of banner is lost is unmeasured. **The `-p` transport is gone, not kept as a fallback** — a build too old for a batch `.control` `echo` would need one and none is in reach. Only the **two measured `.spiceinit` layers** (cwd, `$HOME`); no `-D` key but `casemode`. A future or localised `no such variable` wording would defeat the parse: a hypothesis, not a finding. **`partial` has no consumer yet**, and neither does B3's auto-probe gate (`sim_profile_probe_autoprobe_ok` is a PREDICATE nothing calls — item 13 owns the Add flow). `detected` is still *returned* on a partial as a display value; a consumer reading it without checking `status` would draw the wrong conclusion (§11.5). **`CS169q` is conditional coverage** — it bites only when the *parent's* stdin is not already `/dev/null`; one reviewer measured it live here (fd 0 a socket), the verifier measured it vacuous under their arm, product behaviour correct either way. It and the `alive` helper are Linux-specific (`/proc`, `kill -0`), like the suite's `/bin/sh` stand-ins.
- **Item 8 inherits the redirection exposure.** `ase::run_cmd` is byte-identical to `HEAD` and composes no profile `args` today, but when item 8 splices them in, that list goes to `execute`, which reads Tcl exec syntax. `sim_probe_safe_args` deliberately does **not** apply there (a real run's `-o`/`-r` are the point); only the redirection half is item 8's to handle. Its output-option list is **hand-enumerated and ngspice-specific** (`-o --output -r --rawfile --soa-log` + attached and `=` forms).
- **Nothing was written to the user's home directory and no `simrc` was read or written.** `~/.spiceinit` does not exist on this machine, checked before and after (`ls -a ~ | grep -ci spiceinit` = 0); the `HOME` layer was driven with `HOME` pointed at a scratch dir, ngspice having been measured to honour it. **Reviewers raised nothing that was raised-but-not-confirmed** (17 confirmed findings, 11 distinct after de-duplication, all fixed). Not independently re-proven by them: the master red (they declined to mutate the shared tree) and this closer's audit run (they diffed the implementer's file instead). **No eyeball owed** — no pixels here; item 13 owns them all, `owed.sh` untouched.
