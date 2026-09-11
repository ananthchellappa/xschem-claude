# Receipt 02 — ⚖ R1 was answered, always-salvage became a requirement, and the amendment was verified and repaired

**Date.** 2026-09-10, later the same day as receipt 01.
**Scope.** `doc/claude/ase_analyses_batch/` only. **No file under `src/` was touched**: `src/ase.tcl`
is still md5 `39531e402a3d2d2720ef834bc35b0009` and `src/ase_window.tcl` still
`1e8c6b5085ddc302f1d290a29c1258b7`, which are `LEDGER.md`'s recorded baselines. No suite row was
added, no issue was minted, `doc/claude/issues/NUMBERING.md` was not advanced.

⚠ **`git status --short` is still not clean in this tree, and none of it is this pass's.** The same
five tracked files receipt 01 names — `CLAUDE.md`, `doc/claude/issues/NUMBERING.md`,
`doc/claude/specs/owed.md`, `tests/headless/owed.sh`, `tests/headless/test_owed.sh` — plus untracked
`doc/claude/numbering_batch/`, `doc/claude/rdw_lists_batch/`, `doc/claude/rdw_sim_batch/`,
`doc/claude/issues/1400-…md`, `.xschem/` and a `sky130A/.../debug_st1/` directory. Their md5s were
recorded at the start of this pass and were unchanged at the end. This batch directory is still
untracked in its entirety.

**This receipt covers two passes that arrived as one.** First the ruling and the salvage amendment;
then a verification pass over that amendment, which found the published recipe defective. Both are
recorded here, because a receipt that recorded only the first would hand a crew the defective deck.

---

## The ruling, in the user's own words

R1 asked whether ASE-L moves from `ngspice -b` to `-p` in this batch. The user asked two questions
first, and then ruled:

> *"In batch mode, is there no way to write what was simulated 'thus far' to disk before exiting?"*
>
> *"What is the benefit of losing partial results on Stop? Why would one ever want to do that?"*
>
> *"We should put that in right away - always salvage, and alert user that her sittings will cause
> loss of simulation effort 'thus far'"*
>
> *"That being said, in terms of milestones on the plan, it can wait. We proceed along path of
> least resistance"*

— quoted verbatim, and quoted verbatim again in `DECISIONS.md`'s ⚖ R1 entry.

**⚖ R1 is ANSWERED: Option A — keep `-b` in this batch; `-p` stays deferred.** Path of least
resistance on milestones. And the answer added something neither option contained: **always
salvage**, plus a warning wherever a Stop would still discard work. Two separable things, and the
documents keep them separable on purpose — the transport is a milestone question, the requirement
is not.

---

## The measurements that changed the premise

R1's write-up costed Option A with *"`-b` … leaves the only measured capability gap — stop and keep
what you have — permanently open on a single long run."* **That was wrong**, and the correction is
why the user could rule the cheap way. All of it is in `evidence/salvage.md`, measured against
`/home/analog/dev/ngspice/build-ver_50/src/ngspice`.

* **`stop after <points>` checkpointing works in `-b`, and it preserves ASE-L's `.control` deck
  shape.** No argv change, so none of the six `test_ase_simreg_0931` rows that pin `run_cmd` move.
  Measured end to end in ASE-L's own deck shape, SIGTERM 6 s into an 80 ms transient: rc 143, the
  completed `op` and `ac` plots intact in the results file, and **60 % of the transient** in a
  `.ckpt` that loads (`maximum(time)` = 4.799992e-02 of 0.08 s).
* **`stop after` does not perturb the run.** At 3 and at 100 checkpoints the final rawfile body's
  sha256 is `b9836c494d9d52ad`, byte-identical to the unchecked run's.
* **`stop when time > X` does perturb it, and does not disarm when it fires.** Its `resume` advances
  one point and re-fires; the obvious deck simulates **12.5 %** of what it was asked for and exits
  **rc 0**. That deck was the quick pass's, and writing it into a stage would have shipped a
  checkpoint loop that silently truncates every run long enough to matter.
* **Why ngspice throws the work away by default: a missing handler, not a decision.** `src/main.c`
  puts its whole `signal()` block inside `if (!ft_batchmode)`, and SIGTERM/SIGHUP/SIGQUIT are
  installed in no mode at all. Every signal is fatal at its default disposition. Nothing is being
  traded away — which is the answer to the user's second question, and it is *"one would not"*.

---

## What each document now says

| document | what changed |
|---|---|
| `README.md` | the DECISIONS row reads **D1–D41** with R1 marked answered; both evidence counts read **26** and the per-file table gains a `salvage.md` row; the receipts row names this file; the one-paragraph version says R1 is answered and **nine** rulings wait, ⚖ R2 next; the file-set paragraph records that the salvage amendment added one dossier and one receipt, and that stages **0–15** keep their numbers |
| `CREW_BRIEF.md` | ⚖ R1 flagged answered up front and in full at the end, with *"Ask ⚖ R2 next, and stop"*; the one-line salvage summary now names the `.tmp` + `shell mv` step and the counter placement, because without either the sentence is false; the `-r` trap row attributes the `unlink` to `dosim()` |
| `PLAN.md` | §0.12 is the correction that let R1 be answered cheaply; correction **C34** withdraws the old cost line and **C35** records this pass's three; §0.1 gains the *Salvaging a stopped run* block (rows **SV1–SV15**, re-prefixed so they do not collide with `APPENDIX` §7.2's S1–S33); the ruling ledger's R1 row is ✅ ANSWERED with the requirement under it; **Stage 2e** is the warning and **Stage 6f** the salvage, neither minting a stage number; the *Deferred* table and the refusals paragraph no longer list `stop` / `resume` as needing `-p` |
| `APPENDIX_ngspice_analyses.md` | §6.8 is the run-control and salvage section — signals, `-r`'s incremental write and its two defects, `stop`/`resume` checkpointing, what a checkpoint costs, the recipe and its four silent failures, and where salvage is unavailable; §7.1–§7.3 gain the register rows; §8 records **M18** and advances the next free id to **M19** |
| `DECISIONS.md` | new §7 carries **D38** (always salvage), **D39** (the warning, and that it is not salvage), **D40** (checkpointing, `stop after`, nine rules) and **D41** (five refusals); ⚖ R1's entry is ANSWERED with the user's words, the false premise marked in place and the trade-off kept visible; the rulings header reads *ten: one answered, nine carried*; the closing line of ⚖ R10 no longer says *"Ask R1 first"* |
| `LEDGER.md` | a new *Rulings answered* section; the two things R1's write-up said that measurement refutes, kept visible; sub-items **2e** and **6f** in the stages that own them; debt **M18**; the evidence base re-counted at 26 files / 33 494 lines with `salvage.md`'s md5; freeze line advanced to **0–15** |
| `evidence/salvage.md` | the dossier itself — 913 lines, md5 `201a7a8836fe73a9e919300401758aa0`. Its §1 scorecard grades the quick pass that preceded it, and now also grades **itself** |

---

## What the verification pass found in the amendment, and repaired

Four things. One of them would have shipped.

1. **The published recipe contaminated every file it wrote, and its own byte count said so.** All
   three printed copies of the checkpoint deck — `evidence/salvage.md` §3.8, `PLAN.md` §0.1,
   `APPENDIX` §6.8.6 — put `let ckdone = 0` **after** the `tran`. A `let` on a name that does not
   exist creates it in the *current* plot, which after a `tran` is `tran1`, so every `write` from
   then on emits it. Measured: `No. Variables: 5` and a `ckdone notype dims=1` column beside
   `time`, `v(in)`, `v(out)`, `i(v1)` — in the checkpoint **and** in `<cell>_ase.raw`, which ASE-L
   reads by enumerating a plot's vectors. It also falsified the headline: the byte-identity result
   was measured on §3.2's plain `stop after` decks, which have no counter, and was carried onto a
   deck that cannot satisfy it. **The block's own number was the proof and nobody read it** —
   192,000,311 bytes for 4,800,000 points is 40 bytes a row, five vectors, not four. Repair
   measured: the counter moves up beside `ckstep` and `cknext`, before the first analysis;
   `No. Variables: 4`, final body sha256 `b9836c494d9d52ad` = the unchecked run's, the loop still
   terminates, `ASE-RUN-COMPLETE` still printed. The quoted checkpoint size is now **153,600,270**
   and the arithmetic is printed beside it. This is `PLAN.md` **C35(a)**.
2. **Abort latency was published as a constant and is not one.** `4.5–5.6 ms` appeared in four
   documents. Re-measured, it tracks the run's **resident memory** — the kernel tearing down an
   address space — not the signal: SIGKILL at three depths into the same deck gave **0.78–0.85 ms
   at 24 MB RSS**, **1.83–2.14 ms at 62 MB**, **3.84–5.15 ms at 177 MB**. And a
   `T0=$(date +%s%N); kill; wait; T1=$(date +%s%N)` harness charges its own two fork/execs to
   ngspice: 4.21–4.46 ms the `date` way against 1.83–2.14 ms timed parent-side across `waitpid`,
   at one fixed depth. The conclusion is unharmed and strengthened — batch aborts at or inside the
   *"under 5 ms"* figure `evidence/builds.md` credits to `-p`, so `-p` buys a **non-destructive**
   abort and not a faster one. **C35(b)**.
3. **The cost table's constants moved and "ceiling" was the wrong word.** Three sittings on one
   machine: N = 4 → +8 / +18 / +21 %; N = 20 → +60 / +62 / +75 %; N = 100 → +288 / +299 / +380 %,
   implying B = 410–540 MB/s — *above* the 410 MB/s the text called a ceiling. The model
   (extra bytes = N/2 × final size, linear in bytes) reproduces exactly; the constants do not.
   Everything derived from the model survives: N = 4 default, `[2, 50]` clamp, 20 % worst-case
   loss, and the ten-minute/200 MB job still lands near 34 checkpoints at ~1.4 %. **C35(c)**.
4. **`shell mv` was quoted at ≈ 12 ms per checkpoint; two A/B sittings measured 3.7 and 3.9 ms.**
   Immaterial to the cost model at any plausible N, but it was presented as a measurement and was
   three times too large. Now ≈ 4 ms. **C35(c)**.

And five smaller repairs, each a cross-document disagreement rather than a wrong number:

* **`ft_dorun()` was named for code that is not in it**, in five documents. `ft_dorun()` in
  `src/frontend/runcoms.c` is a four-line wrapper that does nothing but `return dosim("run", &wl)`;
  the `fopen(…, "wb")`, the `if (ftell(rawfileFp) == 0) { fclose; unlink(...); }` close arm and the
  `err = 1 → "simulation interrupted" → err = 0` mapping all live in **`dosim()`**. The findings
  were right; a crew grepping `ft_dorun` would have found a wrapper with none of it and read the
  claim as false. Every attribution now says `dosim()`.
* **The salvage block minted a second `S1–S15` label space** inside a document that already cites
  `APPENDIX` §7.2's `S1–S33`. Re-prefixed to **`SV1–SV15`**; §7.2 keeps the `S` space it had first.
* **`PLAN.md`'s *Deferred* table and refusals paragraph still said `stop` and `resume` need `-p`**,
  while its own Stage 6f emits both in a `-b` deck. `LEDGER.md` already carried the correction;
  `PLAN.md` now matches it. `stop when` is refused **on its own merits (D41.1)**, not for want of a
  transport.
* **`LEDGER.md`'s Stage 2e cited the wrong suite rows.** In `tests/headless/test_ase_window.tcl`,
  **W1s1** is the row asserting the `!` button's tip is `[ase::ui::menu_path_stop]` and the literal
  `Simulation > Stop`; **W1s2** is the no-tip gap guard and **W1s2b** pins the key set. `PLAN.md`
  had all three right; `LEDGER.md` now quotes `PLAN.md`'s list.
* **Counts and pointers**: `APPENDIX` §8 advanced from *"next free id is M18"* to **M19** with M18's
  own paragraph; `LEDGER.md`'s intro reconciled to eighteen debts and its freeze line to **0–15**;
  `README.md`'s three stale counts fixed and `LEDGER.md`'s ⚠ paragraph handing that fix to the next
  editor discharged, because this pass was that edit; `DECISIONS.md` §6's title says which
  twenty-eight it means, now that the file runs to D41.

---

## What was rejected, and why

* **Moving to `-p` in this batch.** The user ruled Option A. `-p` keeps three justifications — a
  non-destructive abort, the no-circuit capability probe (the only oracle that closes **M15**), and
  collapsing the pre-deck door to one `set` before `source` — and **not one of them is whether work
  survives a Stop**. Say that plainly wherever R1 is cited.
* **`stop when time > X` as the checkpoint primitive.** It is not disarmed when it fires, it hands
  the integrator a breakpoint that forces a timepoint, and it changes both the timestep grid and
  the byte count (+3 rows per checkpoint). The physics survives — max |Δv(out)| = 4.7e-13 at shared
  timepoints — the bytes do not, and anything comparing two runs sees a difference the user did not
  ask for. **D41.1**.
* **`-r` as a progress or fallback rawfile.** On a deck whose `.control` block runs the analysis it
  is a **destructor**: measured, a good rawfile at the named path was gone at exit, rc 0. Separately
  it corrupts its own output above 99,999,999 points (`fileInit()` reserves 8 characters,
  `fileEnd()` writes `%d`) — an upstream ngspice defect, measured end to end, **not yet filed** in
  the ngspice tree's `doc/codex/issues/`. **D41.3**.
* **A checkpoint written into the results file.** `render_deck` emits `set appendwrite`, which turns
  an overwrite into a stack: four plots and 64,001,536 bytes where one plot is 25,600,541, and
  readback-by-plot-name broken. **D41.2**.
* **`libngspice`.** Unchanged from the batch's standing refusal; nothing in this amendment touches
  it.
* **A proposed replacement for the latency figure — *"under 1 ms, measured 0.40–0.58 ms"*.** It does
  not reproduce either: three sittings on this machine gave 0.4–0.6, 1.6–2.2 and 4.5–5.6 ms.
  Swapping one unreproducible constant for another is the defect, not the fix. What is written
  instead is the mechanism, which reconciles all three and which any reader can re-time. Recorded
  in `PLAN.md` **C35** so it is not re-proposed.

---

## What is owed

* **Debt M18** — the window in which Stage 2e's warning is honest and ASE-L is still lossy. It is a
  debt to the **user**, not to a stage; it gates nothing and Stage 6f landing discharges it.
  `LEDGER.md`'s debt table owns its text.
* **The upstream ngspice defect** — `-b -r` corrupting `No. Points:` above 99,999,999 — belongs in
  `/home/analog/dev/ngspice/doc/codex/issues/`. Not filed. Not this batch's to file, and named here
  so it is not lost.
* **A permanent residue survives Stage 6f**, and the plan says so in both places rather than
  implying it is transitional: `op` has one point; `noise` and `disto` leave an incomplete plot
  *set* rather than a short plot; and `pss`, `sp`, `pz`, `sens`, `tf` are unmeasured (`sens` is
  already known not to honour `bg_halt`). For those, the honest-but-lossy sentence is the final
  answer.

---

## What the next session should do first

**Three sentences, in this order.**

1. **Do not re-ask ⚖ R1.** It is answered — Option A, 2026-09-10 — and the answer carried the
   always-salvage requirement with it. `README.md`, `CREW_BRIEF.md`, `PLAN.md`, `DECISIONS.md` and
   `LEDGER.md` all say so now; if a document you are reading does not, it is stale and this receipt
   is the correction.
2. **Ask ⚖ R2 next, and stop.** *May ASE-L write `<rundir>/.spiceinit`, copying the user's own file
   into it?* R1 = A does **not** shrink it — R2's own blocks-line says it largely disappears only if
   R1 = B — so all 26 pre-deck variables, the three doors and the four traps stay where they were.
   One question at a time is the user's standing preference.
3. **Ship Stage 0 first, alone**, exactly as receipt 01 says. It is the only urgent stage, it costs
   no ruling, and it moves no existing row. Stage **2e**'s warning is the next cheapest honest thing
   and it ships before any checkpoint code exists.

⚠ **And one thing to carry into Stage 6f.** The deck printed in `evidence/salvage.md` §3.8,
`PLAN.md` §0.1 and `APPENDIX` §6.8.6 is now correct, but it was not on the day it was written, and
the defect was visible in the block's own arithmetic. **Check a published byte count against
`points × vectors × 8` before you build on it.** That is what this pass's C35(a) cost, and it is the
cheapest check in the batch.
