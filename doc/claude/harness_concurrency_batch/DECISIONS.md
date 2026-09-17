# Decisions — harness concurrency batch

## ⚖ R1 — scratch made parallel-safe, verdict serialised

**Status: IMPLEMENTED ON THE RECOMMENDED SHAPE, NOT RATIFIED.** Recorded on the owed
ledger against issue 0990. The user was asked twice and the question is still open;
the batch proceeds on the recommendation rather than idling, and this ruling remains
theirs to overturn. Overturning it changes C1 only.

**The question.** When two regression runs collide, both believe they own
`tests/<case>/results/` and both believe they own `tests/results.log`. Two ways out,
differing in what happens to the second agent: a **lock** (it waits or refuses) or
**per-run roots** (both proceed, nothing is shared).

**Why it is the user's call and not an engineering detail.** This user runs crews
that verify in parallel by design. A lock means two agents can never finish a T1 at
the same time. Per-run roots mean they can — at the cost of the canonical filename.

**What tipped it.** The two files are different kinds of thing:

* `tests/<case>/results/.work` is **scratch**. Nothing reads it after the run. Giving
  it the pid scope the runner already uses at `test_utility.tcl:82` costs nothing and
  no reader notices.
* `tests/results.log` is **the verdict**. Per-run naming (`results.<pid>.log`) would
  delete the canonical filename that `doc/claude/ledger/crew.js`, CLAUDE.md's own
  reading instructions, and the user all name explicitly. That is a real cost the
  scratch directory does not carry.

**Decision.** Pid-scope the scratch unconditionally (B1). Lock only the verdict (C1),
keeping `results.log` under its own name, with the second run told plainly to wait —
never silently truncating. This closes all four faces without renaming the file
everyone reads.

**What would overturn it.** The user preferring that a second agent never wait at
all. Then C1 becomes `results.<pid>.log` plus a stable symlink, and every reader of
the canonical name has to be updated — `crew.js` and CLAUDE.md included.

## ⚖ R1 — AMENDED 2026-09-16 by A1's measurement, still unratified

R1's *verdict* half stands unchanged: `results.log` keeps its canonical name and is
serialised. Its *scratch* half was *wrong as written* and is amended.

R1 said "pid-scope the scratch and it costs nothing". A1 measured that exact shape:
`"$testname/results/.work.[pid]"` leaves **658** phantom FATALs against today's 660 —
a no-op. The shared object is `$testname/results` itself, wiped at startup by every
run. So the amended scratch half is: **the workroot moves out of `results/`**
(`"$testname/.work.[pid]"`, measured 0 phantoms), **and the startup wipe is made
run-safe** — which is what face 2 actually turns on.

**This strengthens the case for the verdict lock rather than weakening it.** With the
wipe and the workroot both per-run, two runs stop corrupting each other's *files*; the
lock remains what stops them corrupting each other's *answer*. Nothing here changes
the question the user was asked, so it is not re-asked — but note that a lock taken for
the whole of `run_regression.tcl` would close all four faces at once, at the price of
serialising runs completely, and that option only became visible through this
measurement. If the user overturns R1 toward "no agent ever waits", that is the branch
where it matters.

## ⚖ R1 — a third shape appeared, and it is the "no agent waits" branch

B1's `publish_results` pattern — work in `<case>/results.<pid>`, then restore the
canonical `<case>/results` name — raises an option nobody had when the user was asked:
the **verdict file could do the same thing**. Write `results.<pid>.log`, then rename to
`results.log` at the end.

That would give the "no agent ever waits" branch of R1 something it previously lacked:
`results.log` keeps its canonical name *and* no run is made to queue. It is not free —
the second finisher's rename still overwrites the first's verdict, so one run's answer
is lost, merely lost *cleanly* (a complete, internally consistent file) instead of
truncated mid-write. A lock, by contrast, serialises and keeps **both** answers.

**This does not change what was implemented.** R1 as ruled stands: C1 builds the lock.
But the option is recorded here so that if the user overturns R1 toward "no agent
waits", the work is already scoped rather than rediscovered — and C1 is asked to
evaluate it in its receipt for exactly that reason.

## ⚖ R1 — AMENDED A SECOND TIME, 2026-09-17: "waits" was the unsafe half

The ruling put to the user was "the second run **waits**". C1 measured that shape and
it **destroys the thing the lock protects**: a run that queues politely and then
truncates leaves `results.log` holding **0** of the first run's four blocks. The
polite option was the data-losing one.

**Built instead:** refusal by default; waiting opt-in via `T1_LOG_LOCK_WAIT`; and the
waiting path **preserves** the prior verdict as `results.<pid>.log` before taking the
canonical name. `results.log` still keeps its name, so R1's load-bearing half — the
canonical filename every reader names — is intact.

**What this does to the user's open question.** The choice was framed as "second agent
waits" versus "no agent ever waits". The first option, as literally worded, does not
exist in a safe form: waiting is only safe if it *preserves*, which it now does. The
question that remains is genuinely narrower — whether a second run should be refused
(today's default) or should preserve-and-proceed. That is a smaller decision than the
one filed, and it stays the user's.

## Note — the measured premise that failed

0990 stated a row here "would have to run two regressions at once, which is
expensive". Measured 2026-09-16: one **case**, not a regression, and ~70 s. The
estimate that stood on that sentence was wrong for seventeen days and nobody
re-measured it. Recorded because it is the batch's own cautionary tale.

## ⚖ R1, R2, R3 — TAKEN BY THE DRIVER, 2026-09-17. THEY WERE NEVER THE USER'S.

**The user returned all three and told us why.** Asked to rule on the verdict filename,
they answered: *"I barely know what you are talking about. I don't get into the weeds of
the test-suites. As my coding agent, I am expecting you to make the best decision. We want
good test coverage. But you can't let me gate progress."*

**This was a filing error, not an unanswered question.** All three are internal test-harness
engineering with a knowable right answer. The user's stated goal — good test coverage — is
the whole of their input. Contrast the ~22 rule debts left standing on the ledger, which are
almost entirely UI wording and product behaviour: what sentence a refusal shows, what a
blank column displays, whether a registered argument reaches a command line. **Those reach a
person; these three do not.** The test for a ruling is that question, and it was not applied.

Earlier in the same exchange the user also rejected R1's *shape*: offered "refuse" versus
"wait", they asked *"Why not make it fault-tolerant and find a way for both runs to
proceed? Innovation and progress are about having one's cake and eating it."* They were
right, and the constraint the whole choice rested on turned out to be a **filename
convention**, not a property of the system. R1's decision below is theirs in spirit and the
driver's in detail.

`owed.sh clear rule 0990 / 0663 / 0609` — cleared on that instruction.

### ⚖ R1 → BOTH RUNS PROCEED. Nobody waits, nobody is refused.

B1 already made the *work* parallel-safe: every case computes its verdict in a private
`<case>/results.<pid>`. The only single-slot object left was the **name** `tests/results.log`
— a convention CLAUDE.md, `doc/claude/ledger/crew.js` and the crews adopted, not a limit the
system imposes. C1's lock protected that convention as if it were physics.

**Decided shape.** Each run writes `results.<pid>.log`. The canonical `results.log` remains,
tracking the most recent completed run, so no reader's spelling changes. Every verdict gains
a **header** (pid, script, start time) and a **trailer** (pid, case count, counted failures),
so a reader can always tell *whose* answer it is and *whether the run finished*.

**The sentinels are worth more than the concurrency fix**, and are the reason this shape wins
outright rather than trading one cost for another. They close two recorded traps that no
amount of locking touches:

* **The fossil.** A stale `results.log` reads as a perfect clean sweep today; only its mtime
  ever said otherwise, and two receipts plus a commit message already carry a case count
  taken that way. A trailer naming the run makes a fossil self-identifying.
* **1477's truncation hole.** Every prefix of a green run is itself a green run, because all
  four counted shapes need a line to *exist*. The 4096-byte full buffering against a 4785-byte
  verdict makes a **0-byte** file the typical kill outcome. A file with no trailer did not
  finish, and that is detectable where a short one is not.

C1's lock is **demoted to a safety net**, not deleted: it stops nothing that now needs
stopping, but the evidence-based stale-lock logic is sound and cheap to keep armed.

⚠ **A filename was the obvious shared object; it is not proven to be the only one.** Two runs
also share `~/.xschem/`, the dev display, and this box's memory — and an OOM kill is precisely
what produced 1477's truncated log. Those are physics, not convention. Recon task **R1-recon**
is measuring them; the build must not begin until it reports.

⚠ **IT REPORTED. THE SENTENCE ABOVE THAT SAYS "the only single-slot object left was the name
`tests/results.log`" IS FALSE — see the next section.**

### ⚖ R2 → ISOLATE the suite from the simulator registry. Do not prune.

`test_startup_guard_0663` false-reds **2 of 22** on this box because `~/.xschem/ase_simulators`
holds three dead ASE-L entries (`stub` → a vanished `/tmp/stage11/...`, `slowstub` likewise,
and `src/xschem` registered as `ng-cm3`). With a clean `HOME` it is `ALL PASS (22 checks)`.

Pruning fixes **this box on this day**. The next developer, and this box after the next ASE-L
session registers a simulator, inherits the identical false red — and a suite that reds for
reasons outside the repository is a suite people learn to ignore. **That is how a standing red
becomes furniture**, which this project has already paid for twice (0689 and 0690, four filings
each, everybody re-deriving and nobody fixing).

Not in T1's case list, so **T1's zero is unaffected either way**; `full_audit.sh` globs it, so
the audit is what is being repaired. Deliberately *not* done: redirecting `USER_CONF_DIR` in
`scratch.tcl`, which reaches **169 suites** and is a far larger blast radius than this warrants.

### ⚖ R3 → YES, `C11` BECOMES A DELTA. Clean before, compare after.

`C11` is a raw existence test — `[file exists [file join $repo untitled~.sch]]` expecting 0 —
so it reds on any repo-root litter regardless of who produced it, and it says nothing about the
run that just happened. R2's twin: a check that fails for reasons outside its own subject.

The decisive measurement is G1's: **under T1 the suite's cwd is `tests/` while `C11` reads the
repo root, so under T1 `C11` cannot catch its own leak at all.** It is simultaneously too
sensitive (ambient litter) and completely blind (its own producer). A delta fixes both
directions at once.

0609 already names `C11`, records 13/13 red audits and supplies fix code — **no new number.**

⚠ **MUST LAND TOGETHER WITH 1480's CONTAINMENT.** 0609's proposed containment pins T1's cwd to
`$REPO`, which would **red every T1 run**. Neither ships alone.

⚠ **BOTH SENTENCES ABOVE ARE WRONG — corrected 2026-09-17 by the R2/R3 design crew.** See the
"R2/R3 DESIGN — THREE DRIVER ERRORS" section at the end of this file. In short: the dependency
is **one-directional** (the C11 delta is strictly safe alone and must NOT be held hostage; only
the *containment* cannot ship alone), and **0609 names no directory at all** — the driver's
summary dropped a conditional that 1480 §5 still carries.

⚠ **1480's sweep still requires deciding 0356 first** (`--ignored=matching` versus a `find`-based
arm). That one is a *repository hygiene policy* affecting what the user's own `git status` shows
them, so unlike these three it does not obviously belong to the driver. Left open, not filed.

## ⚖ R1 — AMENDED BY RECON, 2026-09-17. THE LOCK PROTECTS 1 OF 88.

**R1's decision stands; its stated PREMISE was wrong, and the error is the driver's own.**
The section above asserts *"the only single-slot object left was the name `tests/results.log`"*.
Measured by R1-recon: a full T1 writes **88 fixed-name files** under `tests/`, of which **83 are
verdict inputs**. `results.log` is one of them. **The lock C1 built protects 1 of 88.**

This is the batch's **fourteenth** wrong recorded belief, and it was written *by the driver,
into the decision record, on the day the decision was taken* — inherited from B1's receipt
rather than measured. The batch's own standing rule was available and not applied: take the
number from the artefact, never from a plausible sentence.

### What was measured, and what it refutes

**B1's fix is real — re-measured, not inherited.** Two `open_close.tcl` runs staggered 5 s, on a
freshly-verified build:

| | solo | run A | run B |
|---|---|---|---|
| rc | 0 | **0** | **0** |
| wall | 26.85 s | 55.13 s | 59.44 s |
| phantom `FATAL … exit -1` | 0 | **0** | **0** |
| result files | 1898 | **1898** | **1898** |
| died at startup | no | **no** | **no** |

Against PLAN.md's pre-fix record for the identical shape — **407/432/757 phantoms with run B
dead, rc 1**. The *cases* are genuinely parallel now. It is the **driver** that is not.

**The collision was reproduced one file upstream.** `<hc>.log` (`run_regression.tcl:620`),
scored with the tree's own `banner_rule.tcl`, gives wrong answers **in both directions**:

* **Silently** — both children exit 0, the ordinary shape — run A's **two real failures counted
  as 0**. This is face 4 again, in a file nobody had looked at.
* **Phantom red** — the passing run counts a failure it did not earn.

Also still shared: `<tc>.log` ×3 (where `:571`'s delete can synthesise
`case produced no log … FAIL` **in the suite whose baseline is ZERO**), `<dc>.disp.log` ×11,
`tests/results/.actionlogs` (`util.c:385`/`:399` is stat-then-fopen, and with all 10
`ACTIONLOG_KEEP` slots full every session now takes the **deterministic** `slot = oldest`
branch), `~/.xschem/` (**19 T1-registered suites do not source `scratch.tcl`**), and the display.

**The cure is the one B1 already proved:** `.<pid>` on the per-case logs. **~6 lines.**

### Two corrections that outlive this batch

1. ⚠ **THIS BOX IS NOT ~8 GB. `MemTotal` is 16091816 kB ≈ 15.35 GiB — roughly double.**
   CLAUDE.md says "~7.8 GB" and `DECISIONS.md` inherited it as "~8 GB" *in the section above*,
   which then asked the recon to judge OOM risk against a figure that was wrong by 2×. Measured
   headroom during the pair: **5282 MB minimum available, 487 MB peak xschem RSS, 31 concurrent
   processes.** No OOM risk from this shape — measured on `open_close` only, **not** the ngspice
   or display arms, so the figure is not yet a licence for those.
2. ⚠ **CONCURRENCY DOES NOT BUY THROUGHPUT.** Both answers arrive at **64.4 s** concurrent
   against **53.7 s** back-to-back — **20% worse**. The case for "both proceed" is that **no crew
   is ever refused**, never that it is faster, and every write-up must say so. A reader who
   believes this is a speed optimisation will draw the wrong conclusion about when to use it.

### Consequences for the build

* **Scope grows from 1 file to the per-case logs**: the `.<pid>` treatment extends to `<hc>.log`,
  `<tc>.log` ×3 and `<dc>.disp.log` ×11. Small, and exactly B1's pattern.
* **Cost of the sentinel half:** ~30–40 lines, ~100–150 at this file's comment density. The
  trailer needs **two counters that do not exist** — `summarize_all` (`:321-351`) returns nothing
  and five call sites would have to accumulate.
* ⚠ **The header does NOT survive a kill without a `fconfigure`.** There is still **zero**
  `fconfigure`/`flush` in `run_regression.tcl`. The trailer survives regardless; the header is
  the half that buffering eats, and the header is what identifies *whose* answer a file is.
  **The `fconfigure` is not optional — it is the load-bearing line.**
* **Readers to update:** `CLAUDE.md` ×11 lines, `crew.js:184-189,504`, `crew_annotate.js`,
  `crew_opfix.js`, `item_pipeline.js`, `.gitignore:96,118-123`, and
  `test_regression_concurrency_1476.tcl:100` — row **`V1b` encodes the OLD R1** and must be
  rekeyed or it will red on the correct new behaviour.
* **Measured good news:** **no shell script reads `results.log` at all.** `run_suites.sh` and
  `full_audit.sh` are untouched by this change.

## R2/R3 DESIGN — THREE DRIVER ERRORS, AND A FOURTH ISSUE FILE WHOSE FIX CODE IS WRONG

### The designs (both INFERRED FROM SOURCE — nothing was executed, another crew held the slot)

**R2.** The 2-of-22 are **`SG13`** (`test_startup_guard_0663.tcl:332-334`) and **`SG14`**
(`:343-352`) — the only two rows counting the child's **total** `#! ` durable-log lines; every
other row counts a *named* string, and the registry's sentences carry none of those names. The
decisive hop in a twelve-hop chain: **`init_action_log()` runs from `main.c:103` *before*
`Tcl_AppInit`** (`xinit.c:3112` says so), so the child's log is open when `xschem.tcl` sources
the registry. Had that been the other way round the hypothesis would have collapsed.

**Fix: give the farm children a private `HOME`, inside this suite only** — a `$sg_home` with a
pre-created `.xschem` after `:90`; save/set/restore `::env(HOME)` around the launch in `sg_run`
(`:132-139`); new row **SG22** plus two witness lines in `SG_INNER` so the isolation can redden.
Check count **22 → 23** (17 → 18 headless); nothing asserts on it, but it is recorded here.

⚠ Options (b) and (c) from the brief are **impossible**, not merely worse: the registry reader
is a **separate process**, so `test_sim_registry_isolate` cannot reach it. **This is a
child-process face of issue 1377 that 1377 does not cover.**

**R3.** **G1's decisive measurement is VERIFIED** on seven independent legs — no `cd` and no
`env(PWD)` anywhere in `run_regression.tcl`, relative script path at `:619`, `$repo` from
`[info script]` at `:460`, `test_ase_core` never `cd`s. Under T1, `C11` genuinely cannot catch
its own leak. **Fix: a set-difference delta over *both* the repo root and the process's own
working directory**, snapshotted at suite start, replacing `:1531-1532`; the same edit for the
twin at `test_op_dump_altshow.tcl:939-941`.

### Three driver errors

1. ⚠ **"Neither ships alone" is HALF WRONG, and it changes the build order.** The dependency is
   **one-directional**: the C11 delta alone is strictly safe — it only ever makes the row *less*
   sensitive — while the **containment** is what cannot ship alone. **Land the delta now; do not
   hold it hostage.**
2. ⚠ **"0609's containment pins T1's cwd to `$REPO`" — 0609 names no directory** (`:52-54`).
   1480 §5 keeps the conditional; the driver's summary dropped it. **Any per-case directory that
   is not the repo root is already safe today.**
3. ⚠ **"`scratch.tcl` reaches 169 suites" is wrong — it is 187 suites / 193 sourcers / 195
   mentions.** The out-of-scope ruling stands, and is in fact *stronger*; the number must not be
   requoted. Another count taken from a plausible sentence rather than from the artefact.

### The fourth issue file in this batch whose prescribed fix is wrong

⚠ **0609's supplied fix code is partial — DO NOT PASTE IT.** It compares **counts, not sets**
(a `.sym`→`.sch` swap scores clean, and **0609 §3 is itself the correction recording that both
occur**), and it watches **only `$repo`** — so it fixes the false-red direction and leaves the
blind direction exactly as blind. Joining 0867, 0990 and 0805 on this batch's list of issue
files that would have shipped a no-op or a regression to anyone who followed them.

### Falsifiable predictions — the implementation crew MUST report actual numbers

`SG13` should read **`{3}`** against an expected 0; `SG14` **`{0 1 1 0 4}`** against an expected
`{0 1 1 0 1}` — three bad entries (`stub`, `slowstub` missing; `ng-cm3` → `iseditor`, the child's
own binary), `realsim` and `eebin` clean, all five stat'd. ⚠ **Any other number means the chain
is wrong somewhere. Report what you actually see; do not round it into "2 failed."** The
driver's "clean HOME → ALL PASS (22)" is taken **entirely on trust** and has not been re-measured.

For R3: the delta must still **redden** when the `:1520-1530` autosave park is removed
(non-vacuity); the containment must not disturb **W15a/b/c, W16a, V57**; the five T1 suites using
`[pwd]` are inference, not measurement; and ⚠ **`test_regression_concurrency_1476` copies the
regression driver and runs two copies of it**, so a containment edit changes what those copies do.

### Also reported, not fixed

**Nine stale citations in `test_no_untitled_litter.tcl`**, plus `test_ase_core.tcl:1516`
(`actions.c:207` → `:208`). The F2/F3/F4 class, still live.

### Boundary held

1480's sweep stays out: the containment adds **no `.gitignore` rule** and **no sweep**, reusing
the existing `_*_[0-9]*/` shape (verified with `git check-ignore -v`) **specifically so 0356
remains the user's to settle.**

## ⚖ R4 — "ONE CREW AT A TIME" KEEPS ITS RULE AND LOSES ITS REASON. Driver's call.

The `ram-figure` crew surfaced this and could not file it: **six documents justify the
serialisation rule by citing the "~7.8 GB box", and that box does not exist.** It is 15.35 GiB
with 4 GiB of untouched swap, `dmesg` shows **zero** OOM kills, and the whole OOM chain is
assertions citing each other — 1477 cites 0905, 0905 calls it *"a documented event"*, the
ledgers say *"the recorded OOM path"*, and **nothing at the end of that chain is a
measurement.** A rule whose stated basis evaporates deserves re-examination, not inertia.

**This is the driver's decision, not the user's** — it is internal scheduling policy and reaches
no person. Per the filter now recorded at the head of this file: *does this reach a person?*

**Decision: the rule stands, on its real basis, and relaxes on evidence — not before.**

The memory figure was always a **secondary** justification. The **primary** one is measured,
reproduced in this very batch, and untouched by the correction: **concurrent runs corrupted each
other 407/432/757 times** in the pre-fix pairs, and the loser died outright. That has nothing to
do with RAM. Serialising crews is correct *because concurrent runs produce void numbers*, which
is the batch's entire subject.

**What changes is when it may be lifted.** `R1-build` exists precisely to make concurrent runs
safe. Once it lands **and a verification crew has measured a clean concurrent pair**, the rule
relaxes on that measurement. Until then it holds — and the six documents must be rewritten to
cite the collision evidence rather than a box that was never weighed.

⚠ **Do not read this as an all-clear on concurrency generally.** Concurrent `make` is
**unmeasured by anyone**, and so are the `ngspice` and display arms; the recon measured
`open_close` only. Those remain open questions, and the relaxation must not silently cover them.

## ⚠ AND THE RULE ABOUT NUMBERS NOW HAS A THIRD VICTIM: PROVENANCE

"7.8 GB" first appears on **2026-08-07, in a session prompt** (`git log -S`), spread by copying
for **five weeks**, and reached CLAUDE.md only on **2026-09-17** — *the same commit that added
the 1477 bullet, and the same day the driver reasoned from it*. Nobody ever ran `free`.

This batch's standing rule was *"take the count from the artefact's own output, never from a
grep."* It needs widening: **take every measurable fact from the machine, never from a
sentence** — including facts that feel like background rather than measurements. Two further
machine claims failed the same day and nobody had been looking for either: `/usr/bin/xfwm4` does
not exist (introduced, unmeasured, by the commit titled *"correct the AUDIT_WM claim"*), and
`/usr/local/bin/xschem` does not exist either.
