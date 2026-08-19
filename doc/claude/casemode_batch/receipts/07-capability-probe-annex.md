# 07 — the capability probe: ANNEX (long form)

**This is the ANNEX to `07-capability-probe.md`** — the same material at full length: the transport measurements, the `.spiceinit` layers, the fix round's six code defects and four evidence defects, and both complete mutation tables. The receipt is authoritative for the verdict; this file is authoritative for the detail.

**Casemode batch ITEM 7.** Authority: `PLAN.md` §3b item 7 · `DECISIONS.md` **B3** (the two probes + "the probe needs a hard timeout"), **A1** (offer only what the binary can deliver), **A2** (`.spiceinit` overrides — ask, do not guess). Spec **extended, not replaced**: `doc/claude/specs/simulator_profiles.md` **§11** (item 6 owns §1–§10). Base `ce1fe3b5`, branch `fluid-editing`, nothing pushed, nothing committed here.
Consumes item 6's accessors and records through `sim_profile_probe_record`. **Untouched:** `run_cmd` (item 8 — `ase.tcl` is +104 −0, a pure addition), every widget (item 13), `ase::expand_path` (issue 0502). No C, nothing built.

## 1. Files changed

| file | ± | what |
|---|---|---|
| `src/xschem.tcl` | **+576 −0** | 10 procs (`sim_probe_timeout_ms/kill/tmpdir/deck/safe_args/argv/parse/once`, `sim_profile_probe_once/_autoprobe_ok/_capability`) + `set_ne sim_probe_timeout 5000` |
| `src/ase.tcl` | **+104 −0** | `ase::sim_probe_run` — the ASE-L run probe, item 8's caller |
| `tests/headless/full_audit.sh` | +1 −1 | `test_sim_probe` → `nogui_tests` |
| `doc/claude/specs/simulator_profiles.md` | **+559 −0** | §11, eleven subsections, every ruling with its measurement |

New (untracked): `tests/headless/test_sim_probe.tcl` (**871 lines, 61 checks**, band `CS167`–`CS174`; the highest id previously in use was `CS166`, grepped across `tests/headless/*.tcl` rather than quoted from a doc), this receipt, two audit files. Both source diffs are **pure additions — zero deleted lines**.

**§10 is the FIX ROUND** (a second pass over this item's own review findings): 12 new checks, one behaviour change in each of the two source files' probe paths, and four corrections to this receipt's own numbers. Read it with §3–§8, which describe the first cut.

## 2. THE CONTRADICTION IN §3b, RESOLVED (spec §11.1)

§3b calls this "the capability probe" and specifies **cwd = the deck's directory** — impossible as one sentence, because at registration there is no deck. B3 draws the line ("*B3 is only about the first*"), so: **one mechanism, parameterised by cwd**, with both callers built.

| | capability probe | run probe |
|---|---|---|
| entry | `sim_profile_probe_capability` (xschem.tcl) | `ase::sim_probe_run` (ase.tcl) |
| cwd | fresh **empty temp dir**, removed after | the **deck's own directory** |
| argv | row `exe`/`args`/`-n` + `-D casemode=<m>` **per mode** | the run's own argv, `-D casemode=<requested>` |
| records | `detected` + `probed` | **nothing** (`CS170i`) |

Building only one would have blocked an item: 13 needs the first, 8 the second.
**Where the code lives:** the mechanism sits beside item 6's model in `xschem.tcl` (item 13's dialog is there; the thing probed is a `sim()` row), and `ase.tcl` gets only the state/rundir/deck wrapper. §3b's file column says `ase.tcl`; the split is item 6's own and is written into §11.1.

## 3. A1's substantive question — RULED (b), probe each mode (spec §11.3)

**Chosen: three invocations, one per mode, each compared against what came back.** Rejected: "`$curcasemode` exists ⇒ all three work". `$curcasemode` reports the **current** mode, never the supported **set**, and A1 is about what a *request* yields. Item 3's measured silent-ignore shape is exactly what this catches: a wrong-case **key** (`-D CaseMode=`) leaves `fold` with no diagnostic. `CS169h` drives it with a stand-in that accepts every `-D casemode=` and always answers `fold` → honest `detected {fold}`; the rejected design (**M22**) reddens it by offering all three. A binary with no casemode at all settles in one leg (the short circuit, `CS169g`).

**RULING — `no such variable` is an ANSWER, recorded as `detected {fold}`** (§11.4). Stock replies `Error: curcasemode: no such variable.` **and** an empty `CCM=`; both halves are required. This is A1's own clause ("no case support ⇒ pre-fill `fold` and offer nothing else"); recording `{}` would land on item 6 §4 row 3 and offer the ordinary `apt install` user **nothing**. Not a B2b breach — B2b governs *no answer*, and this is an answer; the `fold` half is measured (PLAN F1, plus `CS171b` today). It is the **one** place the probe records a mode it did not watch delivered, and the spec says so. Item 6 §4 row 3 becomes reachable for the first time and is driven: `CCM=sideways` → `detected {}`, `probed` set, `selectable {}` (`CS169i`).

**RULING — a timed-out leg never contributes a mode** (§11.5). Nothing recorded ⇒ `probed` empty ⇒ item 6's unprobed `fold`-alone, byte-identical to today. `CS169j` (a stand-in that answers *then* hangs), `CS170g`, `CS170m`.

## 4. THE TRANSPORT CHANGED, AND THE REASON WAS MEASURED LIVE (spec §11.2)

The item started on the shape the dispatch confirmed — `… | $exe -p …`. **It needs a working X display, and that broke the probe for real, mid-item:** a WSLg `:0` filled up and every real-binary check went from `fold preserve distinguish` to **"unknown"** — a binary supporting all three modes reported as supporting none. Same command, three displays:

```
DISPLAY=:0, server out of client slots -> "Maximum number of clients reached" / "Can't open display: :0", exits, NO answer
DISPLAY unset (headless server / CI)   -> "ERROR: (external) no graphics interface;" and the process DUMPS CORE
DISPLAY=:99 (live Xvfb)                -> answers normally
```

A capability probe whose answer depends on whether an X server has a free slot is the silent-wrong-answer class this batch keeps finding — item 13's dropdown would have offered `fold` only, because X was busy. **So the transport is a two-card batch deck** (`-b`, absolute path, its own temp dir), measured to answer identically with `$DISPLAY` unset, exhausted and good, and *nearer the real run*, which is `ngspice -b <deck>` (A2 asks for the real argv). `CS170n` pins all three display conditions in one expectation — it would have caught what I hit. Two consequences earned their own checks: the deck never lands in the caller's `cwd` (`CS169p`; and measured, ngspice reads `.spiceinit` from the **cwd**, not the deck's directory), and the child's stdin is the **null device** (`CS169q` — in `--pipe` mode xschem's own stdin is its command channel).

## 4b. The hard timeout (B3) — route and measurements (spec §11.6)

**`printf 'echo CCM=$curcasemode\n' | ngspice -p` — EOF on stdin does NOT end an interactive ngspice**: still running at 8 s, burning **2.4 s user + 5.6 s system**, so a hung probe *spins*. The batch transport removes that particular hang (a deck ends at `.endc`) and **the timeout stays mandatory anyway** — B3 is a decision, and a simulator blocks for other reasons, which is how `CS170f` hangs a **real ngspice** (a `.control` blocked in `shell sleep`).
**Route: Tcl-native `open |…` + non-blocking `read` + `after 5` deadline poll + kill.** `after ms` with no script does **not** process events, so nothing re-enters the event loop — item 13's caller is a modal dialog. Rejected: `timeout(1)` (GNU-only; this tree ships on Windows) and `fileevent`+`vwait` (re-entrancy).
**KILL BEFORE CLOSE:** `close` on a command pipeline *waits for the child*, so closing a hung probe inherits the hang. Measured — kill first ⇒ `close` returns in 0 ms with no survivor; **M14** (no kill) turns a 0.7 s deadline into a two-minute call.
Driven by actually hanging it, twice: a stand-in (`CS169b`) and a real ngspice (`CS170f`). Second measurement recorded there: **a batch ngspice killed mid-run has flushed nothing** (0 bytes — stdout is block-buffered into the pipe), so a timed-out real probe carries no answer at all; `CS169j` is what drives the harder case where an answer *is* present and is discarded anyway. Default `sim_probe_timeout` = **5000 ms**.

## 5. `.spiceinit`, both layers, and what was done to the user's home directory

Re-measured on today's build under the shipped transport (`CS170c`–`CS170e`):

```
.spiceinit beside the deck says fold, -D casemode=preserve -> fold      (+ -n -> preserve)
no .spiceinit anywhere,               -D casemode=preserve -> preserve
HOME/.spiceinit says fold,            -D casemode=preserve -> fold
```

So **the capability probe is not clean either** — an empty cwd cannot exclude `~/.spiceinit` — recorded in §11.8.
**NOTHING WAS WRITTEN TO THE DEVELOPER'S HOME DIRECTORY.** `~/.spiceinit` **does not exist** on this machine, checked before and after (`ls: cannot access '/home/qflow/.spiceinit': No such file or directory`; `ls -a ~ | grep -ci spiceinit` = 0). ngspice was **measured to honour `HOME`**, so that layer is driven with `HOME` pointed at a scratch directory; `CS170e` asserts the override, the control answer with the real `HOME`, **and** that `HOME` is restored — all in one expectation.

## 6. Test, checks, RESULT

> **CORRECTED IN §10.** The counts in this section are the FIRST CUT's (49 checks, and a skip-arm number that was wrong twice). The shipped file is **61 checks**, skip arm **46**. Everything else here still holds.

`tests/headless/test_sim_probe.tcl`, true headless (`--nogui`), **49 checks**: **`RESULT: ALL PASS (49 checks)`**, and 3/3 repeat runs identical.
**MASTER RED, re-driven on the final transport:** both source files replaced by `git show HEAD:` → **`RESULT: 49 FAILED (0 passed)`** — every check carries positive evidence of this item's code — restored from a byte-exact backup, `md5sum -c` clean, green again. An earlier cut had **two** survivors; both were real test defects and are fixed (§7).
**SKIP-NOT-FAIL drive:** `NGSPICE_CASE_TEST=/no/such/ngspice` → **`RESULT: ALL PASS (46 checks)`** plus two `note:` lines and **no column-0 skip banner**, so `full_audit.sh` cannot score the file SKIP and silently discard the checks that ran. (This receipt first said **33** and it was never 33: it was **35** at the first cut — 49 minus the 14 ver_50 legs `CS170`…`CS170n`, `/usr/local/bin/ngspice` being present so `CS171`/`CS171b` still run — and it is **46** now, because 11 of §10's 12 new checks are stand-in-driven and need no simulator at all. Measured, not computed.)
Suites, `GUI_GATE=1 run_suites.sh` on `:99`: `test_sim_probe` 49, `test_sim_profiles` 97, `test_ase_cosim` 342, `test_raw_case_mode` 277 — **4/4 PASS**. Two rows seen earlier in that runner are **pre-existing and A/B-proven, not mine**: `test_ase_core` fails 1/59 on the *display* arm (`--nogui`: ALL PASS 75 — the ledger's documented correction) and `test_ase_persist` **TIMEOUTs at 200 s on the display arm with both source files reverted to `HEAD` as well** (`--nogui`: ALL PASS 17). `full_audit.sh` runs the first `--nogui` and allows 300 s, which is why neither is among the baseline's 15 reds.

## 7. Sabotage — 47 mutations + the master red, no survivors

Each an exact literal replacement asserted to hit **exactly once**, applied over a byte-exact backup, run, restored, restore `md5`-verified. Driver + full log: `…/scratchpad/item07/{mutate.py,mut_round2.log}`. **Every one of the 49 checks is reddened by at least one mutation** — verified by set difference between the ids in the file and the ids in the logs, `NEVER REDDENED: []`.

| mutation | checks reddened |
|---|---|
| M01 naive first-`CCM=` line (**the echo trap**) · M05 break outside the match | CS167 CS167b CS167d CS167g +4 · 18 checks |
| M02 prompt strip · M06 trailing trim · M33 any word is a mode · M03 `nocasemode` drops the error-line half · M03c never set | CS167c · CS167h · CS167f · CS167e · CS167d CS169g CS169l CS171 CS171b |
| M07 `-b` dropped · M08 `-n` always · M09 `-D` with no mode · M09b mode never asked · M10 args dropped | 5 · 6 · CS168c · 11 · CS168b CS169o |
| M11 explicit timeout ignored · M12 global ignored · M12b built-in default moved · **M13 deadline inverted** · M13b timeout reported `ok` · **M14 kill removed** | CS168e CS169b · CS168e · CS168f · 20 · CS169b CS169j CS170f CS170g · CS169b CS170f |
| M15 cwd not restored · M17 failed `open` reports ok · M18 bad cwd ignored · M27 probes with no exe | CS169c CS169e · CS169d · CS169e · CS169n |
| M19 no short circuit · M20 `nocasemode` records nothing · M21 only the fold leg probed · M24/M24b/M25 the name gate says yes to everything / reads the whole path / becomes case-sensitive | CS169g · CS169g CS171 · CS169h CS170 CS170b CS170i · CS169k CS169k2 · CS169k2 · CS169k2 |
| **M22 presence-implies-support (the REJECTED design)** · M23 unanswered probe recorded · M23b empty measurement not recorded · M18b timed-out leg contributes | CS169h CS169i · CS169f CS169j CS170g · CS169i · CS169j |
| M26 unknown option ignored · M32 no private dir · M32b temp dir left behind · M16 stderr not folded in | CS169m · CS169l · CS169l · CS171 CS171b |
| **M35 deck written into the caller's cwd** · **M36 child inherits our stdin** · **M37 deck loses its title line** · **M38 tmpdir back to a bare timestamp** | CS169p · CS169q · 11 checks · CS169f CS169i CS170 CS170b CS170i |
| M29 run probe ignores the deck's dir · M30 requested hardcoded · M30b `agree` without an answer · M31 run probe records · M28 ignores `-n` · M33b noexe falls back silently · M34 a `winfo` in a probe proc | CS170h · CS170h CS170j CS170k · CS170m · CS170i · CS170k · CS170l · CS172 |

**Four mutations came back GREEN across the two rounds; each exposed a real test defect, all four now fixed and re-driven red:**
1. **M15** — `CS169c` re-took its `[pwd]` baseline immediately before the probe, so a leaked cwd moved the baseline with it. Baseline hoisted to before any probe runs.
2. **M30b** — nothing exercised the run probe on a *failed* probe. Added `CS170m`.
3. **M36** — `CS169q`'s first stand-in merely drained stdin, which succeeds either way. It now reports `readlink /proc/self/fd/0` and answers a different mode for `/dev/null` than for an inherited socket (measured: without the redirection the child gets `socket:[…]`, xschem's own).
4. Two earlier survivors of the first master red (`CS169l`, `CS169m`) were vacuous against a *missing* proc; both now carry a positive term.
**One mutation was silently skipped in round 2** (`M16`, stale literal after the rewrite: `PATCH HIT 0 TIMES`) and was re-driven afterwards with the current literal — which is why the harness asserts the hit count rather than trusting the patch.

## 8. Audit

`GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to `:99`, `DISPLAY` never stripped, **nothing else running**: `doc/claude/casemode_batch/audit_item07_2026-08-17.txt`.
```
SUMMARY: 324 pass  15 fail  0 crash/timeout  0 skip  (total 339)
WIREEDIT: PASS    TREE: 0 appeared  0 vanished
```

**DIFF vs `audit_item06_closer_2026-08-17.txt` (323/15/0/0 of 338, at `169495a4`), by NAME and STATUS: rows only in the baseline — NONE. Rows only in mine — `test_sim_probe` (PASS), this item's new suite. Status changes in either direction — NONE, zero rows moved.** The 15 reds are the same 15 names the POLICY block lists. `test_ase_core` is **PASS** (the contract) and so is `test_ase_persist`. Counted with a differ matching only `^(PASS|FAIL|CRASH|TIMEOUT|SKIP) +\| +test_…$`, so the within-file `FAIL | key …` detail lines cannot be miscounted as rows.

**Two earlier audit attempts were discarded, not reported**, and the reason is §4's orphans: the first overlapped with suite runs of mine, the second ran while ~260 orphaned `ngspice -p` processes still spun (load average **260**), and both scored suites TIMEOUT that pass standalone. Killed, deleted, re-run clean on an idle machine. "Never run suites while the audit runs" now has a second half: **check the load average first.**

## 9. What was NOT verified

- **Windows is written, not measured**: `sim_probe_kill`'s `taskkill` arm, the `NUL` null device, `sim_probe_tmpdir`'s `C:/Windows/Temp` fallback. **The kill reaches the child, not its grandchildren** — a wrapper `exe` that does not `exec` would orphan its simulator (§11.6, declared, unfixed; a process-group kill is the real answer).
- **The 64 KB output cap / `truncated` flag are undriven**; **the pipe transport is gone, not kept as a fallback** (a build too old for a batch `.control` `echo` would need one, and none is in reach); only the **two measured `.spiceinit` layers** (cwd, `$HOME`); no `-D` key but `casemode`.
- **The auto-probe gate is a PREDICATE only** — nothing calls it; item 13 owns the Add flow. (**`ase::sim_probe_run -exe` was driven by no check** — fixed in §10, `CS173j`.)
- **No `simrc` was written or read** — rows are built in memory under an isolated `USER_CONF_DIR`; nothing touched the user's configuration or home directory. **`CS169q` and `alive` are Linux-specific** (`/proc`, `kill -0`), like the suite's `/bin/sh` stand-ins.
- **No eyeball owed**: no pixels here (item 13 owns them all); `owed.sh` untouched.

---

# 10. THE FIX ROUND — the review's confirmed findings, and what each cost

Three reviewers attacked the first cut with their own drivers and stand-in
executables. **The audit/regression half was clean** (no status moved in either
direction, independently re-diffed) and **no mutation survived** — every finding
below is about the new code's own contract or the evidence for it. Nothing here
re-opens a `DECISIONS.md` ruling; §11.5 and §11.10 gain a ruling each, §11.6
loses a false rationale.

Result: **61 checks** (was 49), `RESULT: ALL PASS (61 checks)`; **22 mutations,
no survivors**; audit diff unchanged (§10.4).

## 10.1 The six code defects

| # | defect | fix | driven by |
|---|---|---|---|
| 1 | **A PARTIAL measurement was RECORDED.** One stalled leg + two answers gave `status ok`, `recorded 1`, `stale 0` — so a transient stall permanently narrowed the row, and with `fold` as the stalled leg the row claimed it could not deliver the global default. Worse than never probing: unprobed still offers `fold` and reads stale, recorded never re-probes. | new status **`partial`**, never recorded, `timedout` carried out beside it; `nocasemode` stays the one definitive single-leg answer (spec §11.5) | **`CS173f`** (MG, MN, MF) |
| 2 | **The run probe answered `agree {}` for a definitive negative.** A released ngspice replying `no such variable` + `CCM=` is recorded by the CAPABILITY probe as `detected {fold}` (§11.4) while the RUN probe said "nothing measured" — the two halves of one item disagreeing about the same bytes, for the commonest real mismatch there is (`distinguish`, the case B4 tells item 8 to REFUSE). | new **`delivers`** field: the mode the run will actually get. `nocasemode` ⇒ `delivers fold`, `agree` compares that (spec §11.10) | **`CS173k`** (ML, MP), `CS170l` (MX) |
| 3 | **The "hard timeout" was per LEG**, so three legs blocked the interpreter for **3 × 5000 = 15016 ms** at the shipped default, in the modal dialog B3's timeout exists to protect. | one budget for the whole probe: the clock starts in `sim_profile_probe_capability`, each leg gets what is LEFT, the loop stops when it is gone. **Re-measured: 5006 ms, `legs 1`.** Stated in §11.6 and in the `set_ne` comment | **`CS173g`** (MH, MN) |
| 4 | **A profile `args` word could REDIRECT the probe.** The argv is spliced into Tcl exec syntax: `args {> zap.txt}` wrote a file into the probe's cwd — the user's own rundir, for a run probe — and `args {\| cat}` swallowed the answer, recorded as "delivers nothing". | `sim_probe_safe_args` (spec §11.2) | **`CS173`** (MA, MB, MQ) |
| 5 | **The run probe CLOBBERED the run's outputs.** `-r <raw> -o <log>` is an ordinary batch profile; the probe overwrote the previous run's `tb.log` with its own and then answered `mode {}`, its stdout having gone into that file. | same filter: output-directing options and their operands are dropped | **`CS173i`** (stand-in) + **`CS174`** (real ver_50 over a rundir holding `tb.raw`/`tb.log`, both byte-identical afterwards) — MC, MD, MP |
| 6 | **A relative `$TMPDIR` produced a relative deck path** the child could not open — a good binary reported as `unknown`, silently. | `file normalize` on the base (spec §11.7) | **`CS173c`** (ME) |

## 10.2 The four evidence defects

1. **The per-mode sweep — this item's headline ruling — had NO stand-in
   coverage.** `always_fold` answers `fold` whatever it is asked, so "ask each
   mode" and "ask one mode three times" are indistinguishable to it; the ruling
   was pinned only by ver_50 legs that SKIP wherever that private build is
   absent — and the brief mandates that skip. **Fixed**: `CS173d` (a stand-in
   that echoes `-D casemode=<m>` back) and `CS173e` (honours `preserve`,
   silently downgrades `distinguish` → `detected {fold preserve}`). Mutation
   **MF** — every leg asks the profile's single mode — now reddens `CS173d`,
   `CS173e` and `CS173f` **on the skip arm**.
2. **Four accepted options were exercised by nothing** (`-cwd` on both probes,
   `-args`/`-exe` on the run probe); making them no-ops left the suite green,
   and item 8 is the caller that will pass `-args`/`-exe`. **Fixed**: `CS173h`
   (a stand-in that answers by what is in its own cwd; also asserts a
   caller-supplied directory is NOT removed) and `CS173j`. MI, MJ, MK.
3. **§11.6's "`close` waits for the child" was FALSE as shipped** — the channel
   is non-blocking by then, so `close` detaches. Re-measured and rewritten with
   both halves: `close` on a **non-blocking** pipeline returns in **0 ms** and
   the child survives; on a **blocking** one it waits **39702 ms**. So
   `fconfigure -blocking 0` is load-bearing (do not reorder or drop it) and the
   **kill is what stops the child**, not what unblocks `close`; the term that
   reddens without it is `CS169b`'s `child=dead` (mutation **MM**).
4. **`CS170e`'s `home_restored` and `CS170n`'s `display_restored` could not
   fail** — each re-read a variable the test itself had set two lines earlier,
   with no product code in between that can touch it. **Both terms dropped**,
   and §11.8 says plainly that HOME/DISPLAY safety here rests on the test's own
   bookkeeping plus the control probe in the same expectation (which *would*
   notice a missed restore).

## 10.3 Orphans — the suite leaked 8 processes per run

The hang stand-ins were `/bin/sh` scripts that *ran* `sleep 120` instead of
`exec`ing it, and the kill reaches the direct child only (the declared limit), so
**every run of this suite reparented 8 two-minute sleeps to init** — the
~260-orphan incident in miniature, inside a suite `full_audit.sh` runs, in a
batch that has already had two audits invalidated by exactly this. They now
`exec`. Measured after: `ps` shows **no `sleep 120` at all**.

What remains is inherent and is declared: `CS170f` hangs a **real** ngspice with
`shell sleep`, whose `sh -c` is a grandchild no kill of ours reaches — **3 per
run**, and the deck's sleep was cut from 60 s to **25 s** to bound the residue.
The real fix is a process-group kill, which stays out of scope: the probe's child
is not in its own process group, so killing the group would kill xschem.

## 10.4 Sabotage — 22 mutations, no survivors

Each an exact literal replacement asserted to hit **exactly once**, applied over
a byte-exact backup of the **fixed** files (never `git checkout`, which would
delete the item), run, restored, restore `md5sum`-verified. Driver:
`…/scratchpad/fix07/mutate.py`.

| mutation | checks reddened |
|---|---|
| MA pipeline separator not honoured · MB bare redirection keeps its filename | `CS173` · `CS173` |
| MC output-directing options pass through · MD long forms pass through | `CS173b CS173i CS174` · `CS173b` |
| ME `$TMPDIR` not normalised | `CS173c` |
| **MF every leg asks the profile's single mode (the REJECTED design, wearing three invocations)** | `CS170 CS170i CS173d CS173e CS173f` — and `CS173d`/`CS173e` are the two that fire **with no simulator present**, which is the whole point of adding them |
| **MG a partial measurement reports `ok`** · MN every outcome is recorded | `CS173f` · `CS169f CS169j CS170g CS173f CS173g` |
| **MH the timeout is per leg again** | `CS173g` |
| MI capability `-cwd` is a no-op · MJ run-probe `-exe` is a no-op · MK run-probe `-args` is a no-op | `CS173h` · `CS173j` · `CS173j` |
| **ML `nocasemode` delivers nothing** · MP the run probe never compares · MX `noexe` carries no `delivers` | `CS173k` · `CS170h CS170j CS170k CS173j CS173k CS174` · `CS170l` |
| MM no kill before close · MO capability temp dir left behind | `CS169b CS170f` · `CS169l` |
| MQ profile args never reach the argv · MR the mode is never asked for | `CS168b CS169o CS173 CS173b CS173j` · 19 checks |
| MS only the fold leg is probed · MT no short circuit on `nocasemode` · MU presence-implies-support · MV an empty measurement is not recorded · MW `agree` compares with nothing measured | `CS169h CS170 CS170b CS170i CS173d CS173e CS173f CS173h` · `CS169g` · `CS169h CS173e CS173h` · `CS169i` · `CS170m` |

MM…MX exist because the fix **changed those checks' subject**: the kill/close
path, the record gate, the status resolution, the leg loop, the argv composition
and the run probe's comparison. Every check the fix touched is re-driven red and
restored green here.

## 10.5 Suites and audit

```
GUI_GATE=1 tests/headless/run_suites.sh test_sim_probe test_sim_profiles test_ase_cosim test_raw_case_mode test_ase_core
  PASS | test_sim_probe      RESULT: ALL PASS (61 checks)
  PASS | test_sim_profiles   RESULT: ALL PASS (97 checks)
  PASS | test_ase_cosim      RESULT: ALL PASS (342 checks)
  PASS | test_raw_case_mode  RESULT: ALL PASS (277 checks)
  FAIL | test_ase_core       RESULT: 1 FAILED (58 passed)   <- display arm only
```

`test_ase_core`'s display-arm failure is the documented pre-existing one
(`ase: design aselib/nfet_clean is not the current schematic`) and was
**A/B-confirmed again in this round**: with `src/xschem.tcl` and `src/ase.tcl`
replaced by `git show HEAD:` it fails identically, 1 failed / 58 passed. On the
`--nogui` arm `full_audit.sh` actually uses it is `RESULT: ALL PASS (75 checks)`.

**THE SKIP ARM CARRIES THE RULING NOW, and that was measured, not asserted:**
with `NGSPICE_CASE_TEST=/no/such/ngspice` the suite is `ALL PASS (46 checks)`,
and mutation **MF** — the rejected one-mode design — takes it to
`3 FAILED (43 passed)`, reddening `CS173d CS173e CS173f` **with no simulator on
the machine at all**. Before this round the same mutation left the skip arm fully
green.

**AUDIT (fix round):** `GUI_GATE=1 tests/headless/full_audit.sh`, self-armed to
`:99`, `DISPLAY` never stripped, load average 0.2 at the start, nothing else
running →
`doc/claude/casemode_batch/audit_item07_fixround_2026-08-17.txt`.

```
SUMMARY: 324 pass  15 fail  0 crash/timeout  0 skip  (total 339)
WIREEDIT: PASS    SCRATCH: 0 leaked dir(s)    TREE: 0 appeared  0 vanished
```

**Diff against `audit_item06_closer_2026-08-17.txt` (323/15/0/0 of 338, at
`169495a4`), by NAME and STATUS:** rows only in the baseline — **NONE**; rows
only in mine — **`test_sim_probe` (PASS)**, this item's suite; **status changes
in either direction — NONE.** The 15 reds are the same 15 names the batch policy
lists. Counted with a differ that matches only
`^(PASS|FAIL|CRASH|TIMEOUT|SKIP)\s+\|\s+test_\S+$`, so the within-file
`FAIL | key …` detail lines cannot be miscounted as rows; the same differ
reproduces the first cut's audit against the same baseline exactly.
