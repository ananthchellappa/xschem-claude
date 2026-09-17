# 1475 — PSS is declared by every ngspice that has it and converges in none of them, so Stage 14 is not built

**Status:** CLOSED AS NOT-BUILT — filed 2026-09-16 on the user's ruling of the same day. ⚖ **R7 is
reversed.** The PSS panel of `PLAN.md` Stage 14 is **not implemented**, no code changes, and this
file is where everything measured about `pss` is kept so that nobody re-derives it.

**Two evidence files carry every measurement below, and each claim names the one it comes from:**

* **[2BIN]** — `doc/claude/ase_analyses_batch/evidence/pss-two-binaries.md`, taken 2026-09-15 by the
  driver on the two binaries a user can actually run: the fork
  (`/home/analog/dev/ngspice/build-ver_50/src/ngspice`, md5 `c435f1431e68…`, `ngspice-46+`, rebuilt
  `--enable-pss --enable-cider` 2026-09-10) and **apt 45.2** (`/usr/bin/ngspice`, md5
  `67decb018967…`, Ubuntu `45.2+ds-1`).
* **[ARGC]** — `doc/claude/ase_analyses_batch/evidence/pss-stage14.md`, taken 2026-09-13, one RC
  deck, one `pss` command, argument count varied on both binaries.

Anything not from those two says so and names its source. **Nothing here was re-measured to write
this file**, and no ngspice was started by it.

## 1 — The headline: declared everywhere, converging nowhere

`pss` is `#ifdef`-gated behind `WITH_PSS` **[not from the evidence files — `APPENDIX` §2.12,
`CREW_BRIEF.md` and `evidence/dotcards.md`]**, and both binaries in the matrix answer `help pss`
with `pss [.pss line args] : Do a periodic state analysis.` **[2BIN]**. So ASE-L's capability probe
sees the analysis on both.

⚠ **The tag on the second clause is NOT the tag on the first, and they were one tag until an
adversarial pass separated them.** `[2BIN]` means *measured in `pss-two-binaries.md`*, and that
file records the `help pss` answer on both binaries; it says nothing about `WITH_PSS`. The macro
claim is true and is sourced elsewhere. **A tag that over-reaches is worse than no tag**, because
its whole purpose is to let the next reader skip re-deriving what was measured.

**On apt 45.2 — the binary a downloading user registers — PSS converged on nothing measured**
**[2BIN]**: not on ngspice's own shipped `examples/pss/ring_osc_pss_ctrl.cir` run with its own
arguments, not on **eighteen** perturbations of it, and not on ngspice's **second** shipped PSS
example, Van der Pol, run with *its* own arguments — which does not merely fail to converge but
**aborts** (`Timestep too small`, rc 1), while the fork solves it in 0.41 s. Twenty 45.2 runs,
**zero** `Convergence reached`:

| what 45.2 did | n |
|---|---|
| answered `Convergence not reached` | 15 |
| aborted rc 1 (the Van der Pol example; the five-argument card) | 2 |
| ran past the timeout — `fguess 0` at 60 s, `sc_iter` 1023 and 1024 at 90 s | 3 |
| **converged** | **0** |

The fork converges on that same example in **0.81 s** to **`3.758894068e9`** Hz — the number the
scratch `--enable-pss` build also gave **[2BIN]**. The second shipped example, Van der Pol, is worse
still on 45.2: it **aborts** with `Timestep too small; … trouble with node "gib"`, rc 1, only the TD
plot, where the fork converges in 0.41 s to `4.590456891e6` **[2BIN]**.

The three timeouts are recorded as *"did not finish"*, not *"hangs forever"* — they were killed by
`timeout` (SIGTERM, no core) and not investigated further **[2BIN]**.

## 2 — Why this is dangerous rather than merely broken

⚠ **The failing run returns rc 0 with both plots full of plausible data and one word of difference
on a stream nobody is reading.** On the ring oscillator, 45.2 reports

```
Convergence not reached … 3857280067 Hz
```

against the fork's converged `3.758894068e9` — **about 2.6 % high** — with **rc 0** and **both
plots full** **[2BIN]**. Nothing in the output marks the number as wrong; the exit code says
success and the waveform window would draw it.

**This is the silent-wrong-answer class**, and it is the one failure mode a GUI cannot paper over:
a user who sets up a periodic steady-state analysis gets an answer, gets it fast, and has no way to
know it is not one. A panel built on this evidence would be ASE-L putting its name to it.

⚠ **AND 2.6 % IS THE MILDEST CASE IN THE EVIDENCE, NOT THE REPRESENTATIVE ONE.** This section
argued the whole case on the gentlest number in the table until an adversarial pass said so. The
same file records errors **forty times larger**, at the same rc 0, with the same two full plots:

| what was asked of it | the fork | apt 45.2 | error |
|---|---|---|---|
| the ring example, as ngspice ships it | converged, `3.758894068e9` | rc **0**, both plots, `3857280067` | **+2.6 %** |
| the same, `points 2` | converged, `3.758894068e9` | rc **0**, both plots, `7714556828` | **+105 %** |
| the same, `fguess 8G` (2.1× high) | **rc 1 — REFUSED**, `Error: Strange behavior` | rc **0**, both plots, `7999996571` | **+113 %** |

⚠ **The last row is the sharpest sentence this evidence contains, and it is the one that should be
read into any future reopening.** Handed a starting guess 2.1× too high, **the fork refuses the
input outright** — it declines to answer. On the binary a user installs, the identical input
returns success, two full plots, and a fundamental frequency of `7999996571` Hz: the user's own
8 GHz guess handed back, to four parts in ten million. **The broken build does not merely get the
answer wrong; it fails to reject inputs the working build knows it cannot solve, and then dresses
the guess up as the result.** No verdict scrape catches that — the verdict string is present and
says `not reached` — and nothing downstream of a GUI can distinguish it from a real answer.

⚠ **And a `reached` verdict is not an answer until the process has exited cleanly** **[2BIN]**: on
the fork, `harmonics 1` and `harmonics 0` both **print `Convergence reached` and then** hang (rc 124
at 10 s) or segfault (rc 139). The verdict and the exit code are each necessary and neither is
sufficient.

## 3 — The stream split: the plan scrapes the stream the broken binary does not use

⚠ **45.2 writes the verdict — and every progress line — to STDERR. The fork writes them to STDOUT**
**[2BIN]**. `PLAN.md` §14 and `APPENDIX_ngspice_analyses.md` §2.12 both say *scrape stdout*, which
on 45.2 **finds nothing at all**. The two number spellings differ as well: `3.758894068e9` on the
fork against `     3857280067` on 45.2 **[2BIN]**.

**Any future implementation reads BOTH streams and parses BOTH spellings.** It is adapter content by
any reading **[2BIN]**.

Related, and from the same measurement: 45.2's stderr carries the
`Shooting cycle iteration number: … || rr: … || predsum: …` line that `builds.md` §1.7 recorded as
never printing — **on 45.2 it does** **[2BIN]**.

## 4 — Why it is upstream, and why no release escapes it

`git log ngspice-45.2..ccebdf2a2` over `src/spicelib/analysis/{dcpss,pssinit,psssetp}.c` **[2BIN]**:

| commit | date | subject | in a release tag? |
|---|---|---|---|
| `8351188e6` | 2025-12-15 | *PSS: new breakpoint deletion, copied from dctran.c: **no more endless loop**. … PSSDEBUG flag added* | **no** |
| `a2a22c0ce` | 2026-04-11 | *Improve PSS error messages* | **no** |
| `668329ca3` | 2026-04-20 | *PSS updates: Remove 1e6 factor … **this will re-enable convergence*** | **no** |
| `4614452f1` | 2026-04-21 | *Info message to stdout, not stderr* | **no** |
| `35b487108` | 2026-04-24 | *Use stderr or stdout adequately* | **no** |
| `5333bf658` | 2026-04-28 | *Use updated eng() to print frequency …* | **no** |

**`git tag --contains` is empty for every one of them** **[2BIN]**. `668329ca3` — the one whose own
message says *"this will re-enable convergence"* — is an ancestor of **neither** `ngspice-46`
(2026-03-29) **nor** `ngspice-45.2`. It *is* an ancestor of the fork's `ccebdf2a2` and of the
stock-47 build's `c5cd68015`, but that stock build was a bare `configure` and has no PSS at all
**[2BIN]**.

**So the consequence is flat: every released ngspice that has PSS has the non-converging one.** The
only binary on this machine on which Stage 14's plan is true is a master-era source build
configured `--enable-pss` — which is exactly what the plan's numbers were taken on, and exactly what
no user has.

## 5 — The four-argument SIGSEGV, and why it outranks every other failure class in this batch

⚠ **`pss 1meg 1m out 1024` — four arguments — dies with rc 139 on BOTH binaries**, printing only
`Error: Strange behavior` first. Five arguments or more survive **[ARGC]**:

| arguments | 45.2 | the fork | `SURVIVED` printed |
|---|---|---|---|
| `pss 1meg 1m out 1024` (**4**) | **rc 139** | **rc 139** | **no, on either** |
| `… 10` (5) | rc 0 | rc 0 | yes |
| `… 10 50` (6) | rc 0 | rc 1 | yes |
| `… 10 50 5e-3` (7) | rc 0 | rc 0 | yes |
| `… 10 50 5e-3 uic` (8) | rc 0 | rc 0 | yes |

The one binary-to-binary difference at six arguments is the **analysis** aborting, not the process
dying — `SURVIVED` printed on both **[ARGC]**.

**This is worse than every other class this batch has classified** **[ARGC]**. The classes were
*rc 1 with `$sim_status` 1* (the starved class: `noise`, `tf`, `sens`), *rc 0 with the guard silent*
(`pz`), and *exit(1) that takes the whole deck with it* (`sp` with no port). A short `pss` card
beats all three:

* **SIGSEGV, rc 139.** No `$sim_status`, no guard, no `remzerovec`, **no salvage** — issue 1433's
  checkpoint machinery runs *in the deck*, and there is no deck left.
* **Everything after it in emit order dies with it, including `op`** — which issue 0964 keeps LAST
  precisely so that a broken run still leaves it behind.
* The user sees a crash, not a message.

⚠ **And the attribution took a second pass to get right, which is itself worth keeping** **[ARGC]**:
the first probe ran `help pss`, `pss` and `edisplay` in one deck, saw rc 139, and read it as
*"`pss` is broken in this build"*. It is not. `help pss` and `edisplay` are fine and `pss` is fine
with five arguments or more. **The defect is input validation on a short argument list** — a
different sentence with different consequences, and it took isolating one command per deck to say
it.

## 6 — `oscnode`: the finding is two sentences, and the first alone is misleading

**[2BIN]**, stated in full because half of it has already been shipped as the whole:

> ⚠ **`oscnode` steers nothing among REAL nodes** — `bout`, `inv1`, `inv2` give the identical f0,
> and `dcpss.c:126` assigns `oscnNode` and never reads it — **but a name that is not a node moves
> the answer** (`3.7415e9` against `3.7589e9`, **0.46 %**), because the parser inserts a new floating
> node into the circuit.

So a form for this field **validates the name against the netlist**. *"ngspice never reads it"* is
true and is **not** the whole sentence — and it is the sentence ⚖ R7's recommendation asked to put
on screen as a hint (`PLAN.md` §14: *"ngspice records this and never reads it"*), which would have
told the user it is safe to type anything there.

## 7 — The plan's refusal thresholds are the scratch build's, and two of them are wrong on the fork

**[2BIN]** re-took the threshold table on the fork and found the plan's own allowed range contains
inputs that do not work:

| `PLAN.md` §14 says | the fork actually did **[2BIN]** |
|---|---|
| refuse `steady_coeff < 1e-6` — so **1e-6 is allowed** | `steady_coeff = 1e-6` **did not finish in 60 s** (rc 124) |
| a `fguess` 19× low *"converged — fine"*, so **bias the default low** | `fguess 200meg` (19× low) **did not converge** — `Convergence not reached`, one relaunch |

The refusals the fork **does** confirm are `harmonics < 2` (1 hangs, 0 segfaults — both after
printing `Convergence reached`), `fguess <= 0`, and `steady_coeff` far below `5e-3` (1e-9 gives a
**false** `Convergence reached` **4.5 % wrong**) **[2BIN]**.

⚠ **Treat the whole threshold table as a floor measured on one binary, not a validated range**
**[2BIN]**. That is the general shape of this issue: a parameter table taken on one build was read
as a property of the analysis.

## 8 — What ASE-L cannot do about it

**Both binaries answer `help pss` identically** **[2BIN]**, so the capability probe cannot tell the
converging build from the non-converging one. And this batch has a standing rule that **a declared
capability is never pruned by probing its behaviour** **[2BIN]** — the probe asks what the simulator
says it has, not whether the answers are any good.

There is therefore no measurement ASE-L can take that would let it offer the panel on the fork and
withhold it on 45.2. **The choice was between offering it to everyone and offering it to nobody**,
and that is what made this the user's question rather than an engineering one.

## 9 — What the user sees today, unchanged by this ruling

⚠ **Not from the evidence files — read from `src/ase.tcl` at the tree this was filed against.** The
ngspice adapter declares

```tcl
pss [dict create \
  label pss  baseline 0  registered 1 \
  emit {{role probe tmpl {pss}}}]
```

(`src/ase.tcl:27342-27344`) — `registered 1` so the GUI offers the type at all, `baseline 0` because
it is `#ifdef`-gated, a **probe-only** `emit` card and **no `fields` key**. So:

* the analysis is **listed** in the Choose Analyses grid, `blocked`/`unrenderable`, with
  `ase::analysis_state_msg` saying *"ASE-L cannot set up pss yet, so it is listed but cannot be
  enabled."*;
* a row that is enabled anyway — an older `.state` file, or a hand-edited one — answers
  **"This pss analysis is not one this simulator can set up."** (`ase::analysis_refusal_frames` plus
  `ase::analysis_emit_msg unrenderable`).

**That sentence is already ratified copy under ⚖ R9** — handles **`R9-065`** (the dialog status
line) and **`R9-160`** (the Arguments column), one literal behind both — **and it is not being
changed by this ruling.** Nothing in `src/` moves for issue 1475. What the user meets today is what
they will keep meeting: `pss` visible, named, and refused with a sentence that says why.

## 10 — When to reopen, and what to do first

**Revisit when a RELEASED ngspice contains `668329ca3`** — the convergence fix. Until then every
release with PSS has the broken one (§4), and the work would ship an analysis that fails on
ngspice's own example.

⚠ **At that point, re-take `evidence/pss-two-binaries.md`'s table on that release BEFORE writing any
code.** The thresholds in `PLAN.md` §14 were never validated on a binary a user can install, and §7
above is the measured proof that taking them on trust produces a form that refuses working inputs
and allows hanging ones. *(The reopening condition is a recommendation of this file, not a
measurement; the fact it rests on — `668329ca3` in no release tag — is **[2BIN]**.)*

## 11 — The ruling, and its provenance

⚠ **Not from the evidence files — this is the batch's ruling record and the user's own words.**

* ⚖ **R7 was answered 2026-09-13 as Option A, "ship it, explicitly experimental"** (`DECISIONS.md`
  ⚖ R7; the user's words were *"follow your recommendation"*). The recommendation it ratified
  carried four parts: ship it **last**, the word **experimental** on the form, the **transient+FFT
  cross-check offered beside the answer**, and the **`oscnode` sentence**.
* **That answer was taken on evidence from a scratch `--enable-pss` build of `ccebdf2a2` that no
  user has** **[2BIN]**. The two binaries in the matrix had only ever been measured for argument
  count **[ARGC]**.
* **Re-put to the user on 2026-09-16 on the two-binary evidence, the user answered: *"don't build
  it, write up the issue."***
* ⚠ **They first answered the question the 2026-09-13 ruling had left open — *"I have never run
  PSS"*.**

**The 2026-09-13 ruling is SUPERSEDED, not forgotten.** It was correct on the evidence it was given;
what changed is the evidence. `DECISIONS.md`'s ⚖ R7 block now carries the reversal at its head and
**keeps the 2026-09-13 answer in full beneath it**, under its own divider, so the record of what was
ruled, on what, and when survives the reversal intact.

⚠ **And the decisive input was a question no measurement could settle.** Every number in this file
argues about how badly PSS behaves; none of them can say whether a user would ever reach for it.
The user's *"I have never run PSS"* is what turned a hard-to-price feature into an easy decision,
and it arrived from the only source that had it. Worth recording for the next ruling that stalls on
a cost estimate: **ask whether the thing is used before refining the estimate of what it costs.**

## 12 — What is preserved, and what is discarded

**Preserved.** Both evidence files stay exactly where they are —
`evidence/pss-two-binaries.md` and `evidence/pss-stage14.md` — and this file is the index to them.
Two further findings in **[2BIN]** are preserved here because nothing else will carry them:

* the plot literals are **identical on both binaries** — `Time Domain Periodic Steady State
  Analysis` and `Frequency Domain Periodic Steady State Analysis`, typenames `pss1`/`pss2`, then
  `pss3`/`pss4` after a relaunch;
* **`eprvcd` after `pss` is safe on the fork** — Stage 12's open question, answered **for the fork
  only**; 45.2 was not run, by the standing rule against crashing the user's simulator. The VCD was
  valid, 158 timestamps.

**Recorded and NOT implemented** — Stage 14's design work, kept in `PLAN.md` §14 under its
not-built block for whoever revisits it: the hard validator and its refusal table, the
last-TD/FD-pair-by-`Plotname` rule, the verdict scrape, and the transient+FFT cross-check offered
beside the answer. **None of it is in the tree and none of it is owed.**

## Where `PLAN.md` and `APPENDIX` are now stale, and the evidence wins

`PLAN.md` §14 and `APPENDIX_ngspice_analyses.md` §2.12 were written from the scratch build. **Where
they disagree with the two evidence files, `PLAN.md` is the stale one** and these are the four
places it matters:

| the plan says | the measurement says |
|---|---|
| the panel scrapes **stdout** for the verdict string — stated twice in `PLAN.md` §14, of which the quoted wording is one (*"The panel scrapes stdout for the verdict string"*); also `APPENDIX` §2.12: *"A GUI must scrape stdout for these"* | 45.2 writes the verdict to **stderr** — scraping stdout finds nothing **[2BIN]** |
| the refusal table allows `steady_coeff = 1e-6` and calls a 19×-low `fguess` *fine* | neither finishes / converges on the fork **[2BIN]** |
| *"**`oscnode` steers nothing.** A nonexistent `oscnode` runs normally"*, hint *"ngspice records this and never reads it"* | true among **real** nodes; a name that is **not** a node moves f0 by **0.46 %** **[2BIN]** |
| *"a 3-stage ring in **0.91 s** … both `Convergence reached`"* as the case for shipping | that is the **scratch build**. The fork does it in 0.81 s; **45.2 does not do it at all** **[2BIN]** |

`APPENDIX` §2.12's gate row also still reads *"Absent in this build; present in `/usr/bin/ngspice`
45.2"*, which predates the 2026-09-10 `--enable-pss` rebuild of the fork. Left as-is: it is the
appendix's record of the build it was taken on, and §14's not-built block is where a reader is now
sent.
