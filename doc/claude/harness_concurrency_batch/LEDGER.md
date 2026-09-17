# Ledger — harness concurrency batch

## ⚠ REOPENED 2026-09-17 — THE PREMISE WAS WRONG. SEE "R1-RECON" BELOW.

The batch closed at `77820c03` with T1 at zero. It reopened the same day for two reasons:

1. **The user returned all three rulings**, which were never theirs to make — internal
   test-harness engineering filed as if it needed their sign-off. *"I don't get into the
   weeds of the test-suites. As my coding agent, I am expecting you to make the best
   decision … you can't let me gate progress."* All three taken by the driver, `890cb5e5`.
2. **The user rejected R1's shape before returning it** — *"Why not make it fault-tolerant
   and find a way for both runs to proceed?"* — and was right. The constraint the whole
   choice rested on was a filename convention, not a property of the system.
3. **Recon then refuted the driver's own stated premise.** `results.log` was not the last
   shared object. It is **1 of 88**.

## Closing state of the first pass — T1 AT ZERO, 2026-09-17

| | |
|---|---|
| cases | **84** (`Start=84 / Finish=84`) |
| wall time | 375.1 s (**unattributed**) |
| counted failures | **0** |
| exit code | **0** |

`results.log` byte-identical to V1's and V2's green verdicts. Both 1477 gates pass:
mtime moved **and** 83 log lines against 84 cases, so the zero is a finished verdict,
not a truncation.

**Defect fixed:** the regression harness's concurrency collision, filed **five times
across seven weeks with zero attempts** (0384, 0867, 0990 — phantom FATAL; 0955, 0905 —
phantom PASS). All four faces closed; two of the four had never been recorded anywhere.

## Task table — 18 tasks, 19 commits

| id | task | status | commit |
|---|---|---|---|
| — | scaffolding | driver | `78d06f1e` |
| **A1** | the RED suite (13 RED / 7 green) | DONE | `5114dd8b` |
| **B1** | faces 1–3 (13 → 2 RED, 10 of 10) | DONE | `5f7164d4` |
| **C1** | face 4, the verdict (2 → 0, 18 of 18) | DONE | `43b40f04` |
| **V1** | solo T1 — GREEN | DONE | `d4946b61` |
| **D1** | the written record (1476 minted, 5 closed) | DONE | `1a46c800` |
| **D2** | lying detail strings (12 of 20 lied) | DONE | `d35db718` |
| **V2** | closing solo T1 — GREEN, committed tree | DONE | `aa0e2213` |
| **D3** | file the residuals (1477–1479) | DONE | `9dffeed4` |
| **E1** | 0805 + 0802 (69 → 75 checks) | DONE | `b3cc484c` |
| **E2** | 0408(a) (157 → 161; 8/20 bad → 0/40) | DONE | `b46892d6` |
| **E3** | 1332-residual (40 → 43; two sabotages) | DONE | `36226c0c` |
| **F1** | documentation pass | DONE | `bb069d89` |
| **F2** | stale citations (briefed 2, found 9) | DONE | `c9c50562` |
| **F3** | citations outside issues/ (briefed 4, found 43) | DONE | `c7f3cdba` |
| **F4** | the false count (briefed 4, found 7) | DONE | `26901af1` |
| **V3** | closing solo T1 — **RED (2)** | DONE | `973ddb9f` |
| **G1** | origin + clear + re-run — **GREEN** | DONE | `0e559104` |
| **H1** | mint 1480, argue 0609 | DONE | — |

## Second pass — rulings taken, premise re-measured

| id | task | status | commit |
|---|---|---|---|
| **R1/R2/R3** | all three rulings taken by the driver | DONE | `890cb5e5` |
| **R1-recon** | can both runs proceed? what else is shared? | DONE | *(this commit)* |
| **R2-R3-design** | isolation + C11 delta, read-only design | DONE | *(this commit)* |
| **0060-comment** | the comment that misdirects leak-hunters | DONE | `a6038098` |
| **ram-figure** | CLAUDE.md's RAM constraint is wrong by 2× | DONE | *(this commit)* |
| **R1-build** | per-pid logs + copied verdict + sentinels | DONE — 20 → **36 checks**, 16 red first | `32dff39a` |
| **claude-md** | 9 passages + **minted 1481** | DONE | `2e65e885` |
| **R3-build** | the C11 delta — landed **alone**, not hostage | DONE | `9ed27a7f` |
| **citations** | 9 stale in `test_no_untitled_litter.tcl`, +`test_ase_core.tcl:1516` | DONE (folded into R3-build) | `9ed27a7f` |
| **1480-update** | `write_backup()`'s header marked fixed, not re-filed | DONE (folded into R3-build) | `9ed27a7f` |
| **R2-build** | private `HOME` for the guard suite's children | IN FLIGHT (holds the suite slot) | — |
| **save-citations** | `save.c:4149` cited stale by ~7 suites | IN FLIGHT (no suite) | — |
| **V4** | solo T1 + a measured concurrent pair (relaxes R4) | QUEUED — after R2-build | — |
| **serialisation docs** | rewrite the 6 that cite the refuted RAM figure | QUEUED — needs V4's evidence | — |

⚠ **Only one crew may run suites at a time** — that is this batch's own subject, and a number
produced during a collision is void. The queue above is that constraint, not a priority order.

## ⚠ R2/R3 DESIGN — THREE MORE DRIVER ERRORS, AND A FOURTH BAD ISSUE FILE

Full detail in `DECISIONS.md`. The headline for anyone reading only this file:

1. **"Neither ships alone" was HALF WRONG, and it changed the build order.** The dependency is
   **one-directional** — the C11 delta is strictly safe on its own (it only makes the row *less*
   sensitive); only the *containment* cannot ship alone. The delta was being held hostage for no
   reason. `R3-build` is now queued to land it by itself.
2. **"0609's containment pins T1's cwd to `$REPO`" — 0609 names no directory at all.** The
   driver's summary dropped a conditional that 1480 §5 still carries.
3. **"`scratch.tcl` reaches 169 suites" — it is 187 suites / 193 sourcers / 195 mentions.**
   Another count taken from a plausible sentence instead of from the artefact. The out-of-scope
   ruling stands and is *stronger*; the number must not be requoted.

⚠ **0609's supplied fix code is partial — do not paste it.** It compares **counts, not sets**
(a `.sym`→`.sch` swap scores clean, and **0609 §3 is itself the correction recording that both
occur**) and watches **only `$repo`**, fixing the false-red direction while leaving the blind
direction exactly as blind. **Fourth issue file this batch whose prescribed fix would have
shipped a no-op or a regression** — after 0867, 0990 and 0805.

**G1's decisive measurement VERIFIED on seven independent legs**, so R3's premise holds: under
T1 the suite's cwd is `tests/` while `C11` reads the repo root, and it cannot catch its own leak.

**R2's decisive hop:** `init_action_log()` runs from `main.c:103` **before** `Tcl_AppInit`
(`xinit.c:3112`), so the child's log is open when `xschem.tcl` sources the registry. Had it been
the other way round the whole hypothesis collapses. The two affected rows are **`SG13`**
(`:332-334`) and **`SG14`** (`:343-352`); fix is a private `HOME` for the farm children, 22 → 23
checks. Options (b) and (c) are **impossible**, not merely worse — the registry reader is a
separate process, which makes this **a child-process face of issue 1377 that 1377 does not cover**.

⚠ **Everything in the R2/R3 design is INFERRED FROM SOURCE — nothing was executed.** The crew
supplied falsifiable predictions (`SG13` → `{3}`, `SG14` → `{0 1 1 0 4}`) precisely so the build
crews can prove the chain wrong. **Report the actual numbers; do not round them into "2 failed."**
The driver's own "clean HOME → ALL PASS (22)" is still taken **entirely on trust**.

## ⚠ RAM-FIGURE — THE NUMBER WAS HALF, AND THE REASONING BUILT ON IT HAS NO RECEIPT

Committed `2a60d81d`. `MemTotal: 16091816 kB` = **15.35 GiB**, plus **4 GiB of swap, zero in
use**, which CLAUDE.md never mentioned at all. "~7.8 GB" was not a rounding — it was almost
exactly **half**.

**The OOM attribution has no receipt anywhere.** `dmesg` shows **zero** OOM kills. A repo sweep
for an *observed* kill finds only SIGKILLs the harness sends deliberately, plus assertions citing
each other: **1477 cites 0905, 0905 calls it "a documented event", the ledgers say "the recorded
OOM path", and nothing at the end of that chain is a measurement.**

**Provenance is the sharpest part.** `git log -S` dates "7.8 GB" to **2026-08-07, in a session
prompt**. It spread by copying for **five weeks** and reached CLAUDE.md only on **2026-09-17** —
*the same commit that added the 1477 bullet, and the same day the driver reasoned from it.*
Nobody ever ran `free`.

**The truncation paragraph was correctly NOT deleted.** 1477's hole is about *a kill*, not a
cause; the cause list is reordered (1403's 900 s timeout first, OOM last) and the limits written
in — **concurrent `make` and the ngspice/display arms remain unmeasured by anyone**, so the
correction does not read as an all-clear.

**A trap the driver's own brief would have walked into:** **455 doc citations** point at
`src/ase.tcl` lines *below* 2857, so inserting a comment line there rots every one. The crew made
that fix **line-count-preserving** (`numstat 1 1`) — driver-verified, along with "every changed
line is a comment" in both `.tcl` files.

**Two further machine facts failed, and nobody was looking for either:**

* **`/usr/bin/xfwm4` does not exist.** Introduced — unmeasured — by the commit titled *"correct
  the AUDIT_WM claim"*. One WM fact corrected and a second invented in the same breath, into a
  paragraph warning that a missing WM falls back silently.
* **`/usr/local/bin/xschem` does not exist**; the directory is empty. The crew **strengthened**
  the never-a-bare-`xschem` rule rather than weakening it — one `make install` restores the
  hazard — noting only that the failure is now loud instead of silent. Correct judgement.

**17 stale sites deliberately left**, listed in the receipt: dated ledgers, another branch's park
doc, session prompts, and four issue files recording *why a past decision was made*. Rewriting
those would falsify the record. **The driver confirms that judgement.**

## ✅ R1-BUILD — BOTH RUNS PROCEED. `32dff39a`.

**20 → 36 checks, `RESULT: ALL PASS`, rc 0, and SIXTEEN of the 36 observed RED on the
unmodified tree first**, each quoted red-before/green-after. Collateral green: watchdog 1403
**32/32**, audit classifier **75/75**, op_annot **485/485**.

The verdict is **copied, never renamed** — a rename deletes the finisher's own answer, the
"lost cleanly" trap `DECISIONS.md` recorded. Refusal and `exit 2` are **deleted**; the lock now
brackets **one file copy** instead of a whole run. Per-case logs are pid-scoped and published
back, with `T1_LOG_TAG` carrying the agreed name across the process boundary — the cases run in
their own pids, so the name had to be *agreed*, not computed. Sentinels `T1-RUN-BEGIN`/
`T1-RUN-END` plus the load-bearing `fconfigure $fd -buffering line`.

**Driver-verified before commit:** the `file rename` at `:426` is the *per-case* path only and
never the verdict — its comment states the distinction unprompted, citing 1480 on litter, and
all five call sites are per-case.

### Five corrections from the crew

1. **"~6 lines" for Part 1 is 26.** The estimate missed the cross-process handshake, the
   publish-back, and `summarize_all`'s label argument.
2. ⚠ **Issue 1478 §3's prescribed fix would have REOPENED the race** — publishing before
   `summarize_all` lets the other run publish onto that name between the rename and the read.
   **Fifth issue file this batch whose prescribed fix would have shipped a regression**, after
   0867, 0990, 0805 and 0609.
3. **The brief's rows could not reach the riskiest mechanism** — section V neuters `tcases`, so
   the only cross-process name agreement was untestable. Added `P1e`/`P1f`.
4. ⚠ **The binary was STALE at task start** and `make -C src` relinked it — though an earlier
   crew had recorded *"Nothing to be done"* hours before. CLAUDE.md's rebuild-before-evidence
   rule earned its place again, in this batch, today.
5. **REFUTED: "five call sites would have to accumulate"** — only two did.

**Two self-inflicted defects caught and recorded rather than quietly fixed:** a first `V3c`
asserting count *equality* (false — 800 vs 1), and a `V1c` whose detail string quoted a comment
instead of the code — **this batch's own D2 class, committed by a crew that had read about it.**

### ⚠ NEW DEFECT, IN NO ISSUE FILE: the `Start`/`Finish` rule under-counts by 11

The NODISPLAY path **`continue`s before its `Finish` line**, so a box with no dev display prints
**84 `Start` / 73 `Finish`**. CLAUDE.md's *"count `Start`/`Finish` pairs"* rule — which exists
**precisely because two independent passes got the case count wrong** — is itself wrong on that
arm. Handed to the `claude-md` crew to document and mint.

## ✅ CLAUDE-MD — AND THE DRIVER'S OWN BRIEF WAS STILL TEACHING THE RETIRED RULES. `2e65e885`.

Nine passages corrected, `+141/−32`, every one in the house confessional style with the old
claim quoted rather than erased. **`rc 2` marked FALSE, not softened.** The refusal era turns
out to be **exactly datable and lasted hours** — `43b40f04` introduced it, `32dff39a` removed
it, both 2026-09-17 — so a transcript from that window is the only place it was ever real.

⚠ **`CREW_BRIEF.md` was still teaching three retired rules to every crew dispatched after the
change that retired them** — mtime-and-md5, and the `Start`/`Finish` count with 1481's hole in
it. **R2-build was to be the next crew to read it.** Repaired in the same commit, recorded
rather than silently swapped: *a receipt written under the old rules was right when written.*

⚠ **The driver's brief dropped item 7 of R1-build's seven, and the crew did it anyway** — the
sentence telling a crew its own answer is `tests/results.<pid>.log`. Arguably the most
operationally useful line of the whole change, since `results.log` during a concurrent run now
yields an answer that is complete, well-formed and **someone else's**.

⚠ **A THIRD PLAUSIBLE NUMBER.** Cases are still **84**, log lines still **83** — but `wc -l`
now answers **85**, because the verdict carries the two sentinel lines. That paragraph has
already been wrong **twice** by conflating the first two; the third neighbour is now written
out explicitly instead of waiting to be discovered.

**Issue 1481 minted** for the `Start`/`Finish` hole after three searches (this clone, repo-wide,
`xschem-op-wcard`) found it filed nowhere. ⚠ **1476 and 1477 both *cite* that rule as a
protection without noticing the hole in it.**

## ✅ R3-BUILD — THE OLD CHECK PASSED, rc 0, WHILE ITS SUITE WAS LEAKING. `9ed27a7f`.

| scenario | old row | new row |
|---|---|---|
| clean | `ALL PASS (675)` / `(70)` | **unchanged** |
| **foreign** litter in repo root | `C11 FAIL`, `H1 FAIL` | **green, both** |
| real leak, from repo root | `FAIL → {1}` | `FAIL → {/…/untitled~.sch}` |
| **real leak, from `tests/` — T1's cwd** | **`ALL PASS`, rc 0, *while writing the leak*** | `FAIL → {/…/tests/untitled~.sch}` |

**That fourth row is the whole justification.** G1 inferred it from source; this crew executed
it. The row was *simultaneously* too sensitive and completely blind.

**Only the IDEA was kept from 0609's fix code** — snapshot at suite start. Both halves of the
code discarded: `llength` became a real set difference (`:1597-1600`), and `-directory $repo`
became `{$repo, $env(PWD), [pwd]}`. 0609's block is banner-marked **SUPERSEDED — DO NOT PASTE**.

**Two design corrections, one of which the twin file would have exposed:** the watch list needs
**three** entries (two cwd producers; preferring one hides the other), and the list must be
**fixed at suite start** — the design re-derived it per call, and `test_op_dump_altshow`, the
twin it said to apply "the same edit" to, **is a suite that `cd`s**.

⚠ **A REFUTATION REACHING BEYOND THE TASK: the design crew reported `write_backup()`'s lying
comment as "re-confirmed by reading today" — it was already FIXED**, by `a6038098`, *inside the
window they were reading*. **1480 §6 item 3 and 0609's closing warning were both reporting done
work as outstanding.** Marked done, so a solved defect is not filed a sixth time.

**Reported, not fixed:** `src/save.c:4149` cited stale by ~7 further suites — dispatched as
`save-citations`.

## ⚖ R4 — the serialisation rule keeps its rule and loses its reason (driver's call)

**Six documents justify "one crew at a time" by citing a box that does not exist.** Decision in
`DECISIONS.md`: **the rule stands on its real basis and relaxes only on evidence.** The RAM figure
was always *secondary*; the *primary* justification is measured, reproduced in this batch, and
untouched — **concurrent runs corrupted each other 407/432/757 times** and the loser died. That
has nothing to do with memory.

`R1-build` exists to make concurrent runs safe. **When it lands and a verification crew measures a
clean concurrent pair, the rule relaxes on that measurement** — and the six documents get rewritten
to cite the collision evidence rather than a weight nobody took.

**The standing rule needs widening.** It was *"take the count from the artefact's own output, never
from a grep."* Three miscounts and now a fabricated hardware fact say it should read: **take every
measurable fact from the machine, never from a sentence** — *including facts that feel like
background rather than measurements.*

## ⚠ H1 RE-SCOPED ITS OWN BRIEF, AND THE IRONY IS EXACT

The brief said "mint 1480 as the sixth residue class". **Taken literally that would have
been the sixth filing of an already-filed proposal.** H1 read the neighbouring issues
first and found the litter half already filed **five times**:

* **0353** — detector half landed, backup shape excluded
* **0356** — the *open decision* on widening, tradeoff written out
* **0609** — owns `C11`
* **0673** — fix item 2 is *verbatim* "widen the tree-hygiene check crews are told to run"
* **0687** — already owns the `tests/` producer and the guardian's blindness

`.gitignore:48-52` also records the cure. **This batch exists because one defect was
filed five times and fixed zero times; the driver's brief was about to do it a sixth.**
H1 confined 1480 to what no issue file contains, opening with a table of the five prior
numbers and the sentence *"The litter is not this issue"* — the shape 1476 used.

**1480's unfiled core (§2.1):** **neither audit driver writes a per-suite `.log` under
`tests/` at all** (`out=$(…)` with `mktemp -d`), so V3's "no suite ran in that window"
sweep was *structurally incapable* of being right. Plus T1 writing one every green run
from a **passing** case (two distinct pids), the 63-of-69 static exposure, the scope
limit (`$repo` derives from `[info script]`, so the `tests/` copy can **never** reach
C11), and the must-land-together warning.

Mint verified **three times** (entry, pre-mint, post-mint): band awk silent, cross-clone
`ls` rc 2 no match in either checkout, `grep -lw` one hit — this clone's own pointer
sentence. 1481 checked before becoming the new pointer.

## ⚠ H1's three findings the brief did not have

1. **`write_backup()`'s header comment contradicts its own body.** `save.c:6137-6138`
   says untitled buffers are *skipped*; `:6149-6152` and the code do the deliberate
   opposite (issue 0060). **Wrong in exactly the direction that makes a reader conclude
   this leak cannot exist.** Reported, not fixed — it is source.
2. **`.gitignore:55/:56` is stale in 5 files across 7 sites**, one of them a
   **check-name string** at `test_audit_classifier.tcl:490` — **D2's exact defect
   class.** Today the lines are `:75/:76`; `:55` is `# Executables`. Reported, not
   edited (test logic).
3. **`test_op_dump_altshow` is not in T1's case list at all**, so under T1 the only
   exposed row is `C11` — narrowing the 0609/1480 interaction by one row. Also 0687's
   cited producer line `:374` is stale; the only `clear force` is `:484`.

## Driver decisions on H1's two flags

* **Its one overreach is KEPT.** H1 also corrected 0609's stale citations in place
  (`save.c` off ~2000 lines; the C11/H1 rows `:772`→`:1531`, `:924`→`:939-941`) and
  flagged it rather than letting an audit find it. **The pre-image of every one is in
  the new section's correction table**, so it is reversible and auditable. Dropping them
  would leave known-stale citations in the file — the rot this batch spent its tail
  documenting.
* **The sweep is NOT implemented.** 1480's proposed sweep is deliberately written as a
  `find` so it does not pre-empt **0356's open question** between `--ignored=matching`
  and a `find`-based arm. Implementing it touches 0356 and is the user's call.

**H1 re-measured the driver's CLAUDE.md refutation rather than take it on trust — and
confirmed it.** Joined-line search returns 0 for all four phrases; `:118` reads "The run
is 84 cases and 83 log lines"; `:130` is past-tense by construction. **CLAUDE.md was
never opened for writing.**

## The batch's own count: thirteen wrong recorded beliefs

Three issue files prescribed fixes that were no-ops or regressions (0867, 0990, 0805);
0408 reasoned wrongly about its own part (b); a residual was described incorrectly; E3
refuted its own row's premise; F2's correction went stale *inside the batch*; two
citations were wrong the day they were written; F4 found a count wrong in seven places,
two of them arithmetic no grep can reach; V3 misattributed a cause its sweep could not
observe; G1 read a past-tense sentence as a live claim; and the driver corrupted one
brief by summarising a receipt, mis-scoped 1480 toward a sixth duplicate filing, called
a working waiter dead, and twice left a commit hash out of this ledger — **both times
caught by a crew reading it.**

**Every one was found by re-measuring rather than re-reading.**

## Rulings — ALL THREE TAKEN BY THE DRIVER, none standing with the user

Cleared from `owed.sh` on the user's instruction. Reasoning in `DECISIONS.md`.

* **⚖ R1** (0990) → **both runs proceed.** Per-pid verdict files; `results.log` keeps its
  canonical name tracking the most recent completed run; every verdict gains a header and
  a trailer so a reader can tell whose answer it is and whether the run finished.
* **⚖ R2** (0663) → **isolate** the suite from the simulator registry; do not prune.
* **⚖ R3** (0609) → **`C11` becomes a delta.** Must land with 1480's containment.

**The filter that should have been applied at filing time:** *does this reach a person?*
UI wording and product behaviour are the user's; harness internals are the driver's. The
~190 rule debts still on the ledger have never been through that filter — a triage pass is
proposed, not scheduled.

## ⚠ R1-RECON — THE FOURTEENTH WRONG RECORDED BELIEF, AND IT WAS THE DRIVER'S

`DECISIONS.md` asserted, on the day the decision was taken, that *"the only single-slot
object left was the name `tests/results.log`"*. **Measured false.** A full T1 writes **88
fixed-name files** under `tests/`; **83 are verdict inputs**. The lock C1 built protects
**1 of 88**. The driver inherited that sentence from B1's receipt instead of measuring it —
the exact failure this batch spent its tail documenting, committed into the decision record.

**B1's fix is real, and re-measured rather than inherited:** two `open_close.tcl` runs
staggered 5 s produced **0 phantoms, rc 0, 1898 result files each, neither dying** — against
a pre-fix record of **407/432/757 phantoms with run B dead**. The *cases* are parallel. The
**driver** is not.

**The collision reproduced one file upstream**, in `<hc>.log`, wrong in **both** directions:
silently scoring run A's **two real failures as 0** (face 4 again), and inventing a failure
the passing run did not earn. Also shared: `<tc>.log` ×3, `<dc>.disp.log` ×11,
`tests/results/.actionlogs`, `~/.xschem/` (**19 T1 suites do not source `scratch.tcl`**), the
display. Cure: `.<pid>`, B1's own pattern, ~6 lines.

**Two corrections that outlive the batch:**

1. **This box is not ~7.8 GB. `MemTotal` ≈ 15.35 GiB — wrong by 2×** in CLAUDE.md, and
   inherited into `DECISIONS.md`. CLAUDE.md *reasons* from it (1477's OOM attribution).
   Crew `ram-figure` is repairing it; the truncation defect itself is real and stays.
   ⚠ **It repaired more than the number — see the next section.**
2. **Concurrency does not buy throughput** — 64.4 s concurrent vs **53.7 s back-to-back**,
   20% *worse*. The case for "both proceed" is that **no crew is ever refused**, never speed.

⚠ **The header sentinel does not survive a kill without a `fconfigure`**, and there is still
**zero** `fconfigure`/`flush` in `run_regression.tcl`. The trailer survives; the header is the
half buffering eats — and the header is what says whose answer a file is. It is load-bearing.

⚠ **Row `V1b` of `test_regression_concurrency_1476.tcl:100` encodes the OLD R1** and will red
on the correct new behaviour. Rekey it in the build, do not delete it.

## Candidates, recorded and deliberately not scheduled

1. **1478's fail-open warning should write into the verdict**, not only to stdout.
2. **"Cite the emitter, not the line", repo-wide in one deliberate pass** — supported by
   F2 (9 stale), F3 (43, two never correct), F4 (7 sites) and H1 (7 more).
3. **1480's sweep**, which requires deciding 0356 first.
4. **`save.c:6137-6138`'s contradicting comment** (issue 0060) — source, untouched.
