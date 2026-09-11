# Receipt 01 — the adapter pivot was folded into the documents, verified, and repaired

**Date.** 2026-09-10.
**Scope.** `doc/claude/ase_analyses_batch/` only. **No file under `src/` was touched**: `src/ase.tcl`
is still md5 `39531e402a3d2d2720ef834bc35b0009` and `src/ase_window.tcl` still
`1e8c6b5085ddc302f1d290a29c1258b7`, which are `LEDGER.md`'s recorded baselines. No suite row was
added, no issue was minted, `doc/claude/issues/NUMBERING.md` was not advanced.

⚠ **`git status --short` is NOT clean in this tree, and none of it is this pass's.** Five tracked
files show modified — `CLAUDE.md`, `doc/claude/issues/NUMBERING.md`, `doc/claude/specs/owed.md`,
`tests/headless/owed.sh`, `tests/headless/test_owed.sh` — plus untracked `doc/claude/numbering_batch/`
and `doc/claude/issues/1400-…md`. Those belong to the **parallel issue-1400 / issue-numbering work**
this tree's own `CLAUDE.md` describes. Attribution checked by mtime rather than asserted: all five
were last written between **10:49 and 11:16**, and every file this pass wrote carries **12:02–12:07**.
This batch directory is still untracked in its entirety.

---

## What the pivot was, in the user's own words

> "Going by the ADE-L experience (Cadence), the third party tool vendor has to do the integration.
> So Xschem is not responsible for setting up ASE-L to work seamlessly with the new ngspice-v_50. We
> should build some kind of framework that any simulator's coding agent can integrate the interface
> for that simulator into ASE-L. Once the user registers the simulator by going to Setup > Simulators
> and adds a new one by specifying path, magic needs to happen."

And, asked who writes the adapters:

> "It's Xschem's agent. I am trying to promote Xschem, so I have to make it support everything
> ngspice offers so that usage takes off."

**Why this was additive rather than corrective.** `PLAN.md` Stage 1 had already designed
`ase::analysis_types` to resolve through an **optional** `analysis_types` backend hook, falling back
to the empty list and — in its own words — *"NEVER to a literal list, because a literal fallback is
the ninth copy"*. The mechanism was already adapter-shaped. What was missing was the **doctrine**:
who owns the table, that adapters are first-party, that the contract is built by being its own first
customer, and that the goal is adoption. Nothing was ripped out.

---

## What changed, document by document

The pivot itself landed in a prior pass. **This pass applied the findings of two verification lenses
over that work, and added what the lenses found missing.** Both are recorded below.

### `PLAN.md` (3010 → 3180 lines)

| where | change |
|---|---|
| §0 preamble | §0.10 re-labelled as *"a different kind of entry"* rather than *"the newest"*, because §0.11 now is; §0.11 introduced |
| §0.10 | the consequence list extended — it now names Stage 1's **naming rule**, Stage 2's **2d**, and Stage 7's ownership statement alongside 1e, Stage 15, *Sequencing* and the refuse-list |
| **§0.11 — NEW** | the bare-verb capability probe, **rejected as proposed** and measured on both binaries. See *What was rejected* |
| §0 corrections table | **`C28`/`C29` renumbered to `C32`/`C33`** and moved into ascending order, with a ⚠ note. They collided with `evidence/design-of-record.md` §12's own C28 and C29, which are different corrections; the C-space is one space across the batch (`CREW_BRIEF.md` cites C21, `LEDGER.md` cites C18, both design-of-record ids). `C30`/`C31` were already correct and did not move |
| Stage 1 | **the naming rule** added as part of the stage's acceptance: `ase::…` is schema, `ase::backend::<sim>::…` is content, a registry entry is never a `variable` in `ase.tcl`, and where the answer is arguable the stage says which side and why. Anchored to the tree's own comment at `ase::register_backend ngspice` |
| Stage 1 §1a | a ⚠ block saying the rule covers **every** registry entry in the plan, not only Stage 1's four, plus the `src/Makefile.in` + `./configure` cost if an adapter is ever given its own file |
| Stage 1 file table | *"the registry variable"* → the schema readers plus *"the four entries are adapter content, declared through the hook"* |
| Stage 2a | a fourth probe rule: **never the bare verb in this deck** |
| Stage 2b | **Detect gains a second leg** — the command word with no circuit loaded, which needs no help database and is therefore the cheap half of **M15**; the two legs must agree and a disagreement is the signal, not a tie to break. Gated on ⚖ R1, because it needs `-p` |
| Stage 2 **2d — NEW** | *Setup > Simulators* — where an adapter lives and when it is loaded, what an empty grid says when a registered simulator's backend has no `analysis_types` hook, and that sentence being ⚖ R9's. **No fifth state**: the four states are per analysis and a simulator with no hook contributes no rows |
| Stage 2 header / rulings / suites / sequencing | ⚖ R9 added beside R4 (the `absent` reason string was already a new user-facing sentence and was uncited); the R9 row's Stage column widened `3–14` → `2–14`; one new suite row for 2d; `+220/−10` → `+230/−10` |
| Stage 4 file table | states explicitly that `ase::netlist_facts`, `ase::analysis_needs` and `ase::analysis_precheck` stay **core** and why |
| Stage 5 file table + the three registry entries | `ase::an_tf_out` / `an_pz_nodes` / `an_sens_out` / `sens_eligible` → `ase::backend::ngspice::…`, including inside the `{build <proc>}` escapes |
| Stage 6 file table | the walk is named as living inside `render_deck` (already backend); the plotmap procs are named core, because the sidecar is ASE-L's own artefact |
| Stage 7a | **the 220-row catalogue moves to `ase::backend::ngspice`** and the paragraph above it says why. This is what `DECISIONS.md` D33's amendment promised Stage 7 would settle, and Stage 7 had been contradicting it |
| Stage 7b | `proc ase::opt_line {name value}` → `{sim name value}`, and `dict get $::ase::sim_options $name` → `ase::sim_option_entry $sim $name`. The one speller stays core; it stops holding the content |
| Stage 7 file table | split into a schema row (`≈ +180`) and an adapter row (`≈ +720`); `spiceinit_write` and `effective_read` moved to the adapter, `.spiceinit` being an ngspice filename. Stage total unchanged at `+1330 / −120` |
| Stage 8 file table | split; `meas_line` / `meas_templates` / `meas_needs_degrees` → the adapter (`.meas` is ngspice's card, 8b's templates are its syntax, `meas_needs_degrees` encodes its radians trap). Stage total unchanged at `+660` |
| Stage 9 file table | `ase::sp_alter_lines` → `ase::backend::ngspice::sp_alter_lines`; `two_ports` named as core and why. Total unchanged |
| Stage 14 file table | `ase::pss_verdict` → `ase::backend::ngspice::pss_verdict` — it scrapes ngspice's own stdout. Total unchanged |
| The ruling ledger | opening line now says nine in the table **plus a tenth under it**; a ⚠ block after the table carries ⚖ R10 in full, with A/B/C and the recommendation, and says it is unanswered |
| Stage 15 rulings | **the (a)/(b) lettering deleted in favour of `DECISIONS.md`'s A/B/C**, with the consequence stated: if the ruling comes back C, this stage becomes scheduled and Stage 8 or Stage 11 gives up the time |
| Stage 15 *What it is not* | *"⚖ R10's (b) arm"* → *"⚖ R10's option B"* |
| *Still open* | the numbering paragraph extended to `M16`–`M17` with **the next free id is M18**; the **M16 and M17 rows added to the table**, so the authoritative document lists all seventeen; M15's row gains the two-probe cross-check |

### `DECISIONS.md` (775 → 790 lines)

* **D33's amendment** now says *namespace*, not *file*, and names where Stage 7 settles it —
  `ase::backend::ngspice` plus `ase::sim_option_entry`. The old wording (*"the file it lands in"*) is
  what let Stage 7 read as a contradiction for a day, and the correction says so.
* **D36** gains the naming rule as its enforcement mechanism, the statement that a file table naming a
  proc on the wrong side is the **table** that is wrong, the list of stages re-checked (5, 7, 8, 9,
  14), and the tree's own comment as an anchor.
* ⚖ **R10** was already correct — three options, a trade-off, a recommendation, `⚠ NOT DECIDED` — and
  was **not** edited. Its A/B/C lettering is now canonical everywhere.

### `LEDGER.md` (664 → 691 lines)

* **Stage 15** — *"this stage is the (a) arm"* → *"this stage is R10's **option C**; **option B** …
  is debt M16"*, plus `⚠ NOT DECIDED — the user has not answered R10 … No receipt is owed for it.`
  The measured argument is now quoted as **two probes** with both strings, matching `PLAN.md` §1.
* **Stage 2** — the two pivot sub-items recorded (2d, and Detect's second leg), and ⚖ R9 added.
* **Stage 7** — an amendment block: the catalogue is the adapter's content; decisions gain D34, D36.
* **M16** — *"⚖ R10's (b) arm"* → *"option B"*.
* **M15** — the two-probe cross-check named as the cheaper half, with the ⚖ R1 dependency.
* the debt-numbering paragraph — **next free id is M18**, and a warning not to confuse `M<n>` with
  the design of record's `[R-M<n>]` measurement markers.

### `README.md` (178 → 180 lines)

* the `DECISIONS.md` row: `D1–D33, ⚖ R1–R9` → **`D1–D37, ⚖ R1–R10`**, naming D34–D37 and R10 as the
  pivot's.
* the `PLAN.md` row: *"Sixteen stages on three axes — 0 through 15, one commit each"* → **fifteen on
  three axes, 0–14, plus a terminal Stage 15 on none of them**; Stage 1's naming rule and Stage 2's
  ownership of the *Setup > Simulators* gesture named.
* the one-paragraph version: the same stage-count fix, and **"ten rulings wait for the user"** with
  R10 named and filed last.
* ⚠ README:47 and README:173's *"nine rulings"* were **left alone**: they describe
  `evidence/design-of-record.md` §14, which the pivot did not touch and which really does hold nine.

### `CREW_BRIEF.md` (377 → 383 lines)

* the reading order: *"sixteen stages — 0 through 15, the numbers frozen"* → fifteen, **0 through 14,
  frozen**, plus a terminal Stage 15 outside them.
* *The goal behind the request*: the pivot's **numbers** added — D34, D35, D36, D37 and ⚖ R10 —
  because the brief sends crews to `DECISIONS.md` *"for the D-number or ⚖ R-number your commit will
  cite"* and previously handed them none.
* the standing rule *"No per-simulator knowledge goes into ASE-L's own source"*: the restated `pss`
  measurement cut to a **pointer at the preflight** (it was written out at full length twice in one
  file, ~160 lines apart, and the preflight's own closing line acknowledged the duplication); the
  **naming rule** added in its place, which is the operational form a crew needs.
* a new row in *The traps that will bite you in the first hour*: probing for a verb with the bare
  verb. Inserted second-to-last, so the preamble's *"rows 1, 2, 3, 6, 7 and 8 were re-measured"*
  still points at the same rows.

### `APPENDIX_ngspice_analyses.md` (2772 → 2779 lines)

* §8's numbering paragraph extended to `M16`–`M17`, with **next free id M18**, and a ⚠ separating the
  debt ids from `[R-M16]`/`[R-M17]`, which are the design of record's measurement markers and appear
  in this same file.

---

## What was verified, and how

**Every finding was re-checked before it was applied.** Two findings were re-derived from the
documents; one was measured against both binaries and came back the other way.

| claim | how it was checked | result |
|---|---|---|
| **P5 — the two binaries disagree about `pss`** | ran it, not inherited. `.control` deck with `help pss` / `help sp` against both | **holds, string for string.** `/usr/bin/ngspice` → `pss [.pss line args] : Do a periodic state analysis.`; `build-ver_50` → `Sorry, no help for pss.` Both answer `sp [.sp line args] : Do an S-parameter analysis.` |
| **P5's second half — the command probe** | bare `pss` on both | `build-ver_50` → `pss: no such command available in ngspice`; `/usr/bin/ngspice` → **started a PSS run** |
| the R10 lettering collision | read all three files | **confirmed.** DECISIONS says A/B/C with the harness at C and recommends **A**; PLAN and LEDGER said (a)/(b) with the harness at **(a)**. A crew reading LEDGER's *"this stage is the (a) arm"* and then DECISIONS' *"Recommendation: A"* would have built Stage 15 now — the opposite of what both documents argue |
| the M15/M16/M17 numbering gap | grepped all six documents | **confirmed.** LEDGER carried seventeen ids; PLAN and APPENDIX still capped the space at M15, and PLAN is the authoritative document a crew mints from |
| the C28/C29 collision | read `evidence/design-of-record.md` §12 | **confirmed.** Its C28 is Design B's *"41 points"* mock, its C29 the `.meas` card-vs-command wording. `grep` shows nothing else in the batch cited PLAN's C28 or C29, so the renumber was free |
| Stage 7 vs D33/D34 | read Stage 7a, 7b and its file table | **confirmed.** `variable ase::sim_options` in the core namespace, read directly by `ase::opt_line`, with `≈ +900 (the catalogue is most of it)` against `src/ase.tcl` |
| D36 unenforced downstream | read the file tables of Stages 4, 5, 6, 7, 8, 9, 14 | **confirmed in substance.** ~25 new procs in the core `ase::` namespace, several of them plainly per-simulator (`pss_verdict` scrapes ngspice stdout, `sp_alter_lines` spells `alter … portnum`, `meas_needs_degrees` encodes the radians trap) |
| *Setup > Simulators* has no owning stage | grepped the phrase | **confirmed.** Three hits, all doctrine prose, none in a stage. The plumbing half-exists: `ase::sim_register` takes `-backend`, `ase::register_backend` is keyed by backend name |
| where an adapter lives today | read the tree | `namespace eval ase::backend::ngspice` inside `src/ase.tcl`, registering at source time, under the comment *"the only ngspice literals outside `ase::backend::ngspice` stay the `state_default` schema defaults"*. `src/xschem.tcl` sources `ase.tcl` once; `src/Makefile.in` line 22 lists it |
| `src/` untouched | `md5sum` against LEDGER's baseline | **both match.** No file under `src/` was opened for writing |

All simulator runs were in the session scratchpad on scratch decks. **No bench under `sky130A/` was
run and nothing under `~/.xschem/` was touched.**

---

## What was rejected, and why

**One finding, and it is now `PLAN.md` §0.11 so the next reader does not re-propose it.**

A verification lens recommended adding the **bare command word** beside `help <verb>` as a
cross-check leg **in the same capability deck**, costing *"one line in the existing capability
deck"*, on the ground that it reads the command table rather than the help database and is therefore
immune to **M15**. The immunity is real and the idea is kept. **The placement is not, and it is
measured:**

```
build-ver_50, inside .control of a -b deck (deck has NO devices):
    pss -> pss: no such command available in ngspice
    sp  -> parameter error, "sp simulation(s) aborted"
    op  -> RAN.  "No. of Data Rows : 1"
/usr/bin/ngspice, same deck:
    pss -> STARTED A PSS RUN and did not return inside 30 s
```

A deck always has a circuit, even one with no devices, so inside `.control` the word is a **command,
not a question** — and on a user's real deck that is an unannounced simulation with the user's own
run directory underneath it. Measured again, the safe shape needs **no circuit loaded**, which needs
`-p`:

```
printf 'pss\nsp\nop\nquit\n' | <exe> -p
  build-ver_50      pss: no such command available in ngspice / there aren't any circuits loaded. x2
  /usr/bin/ngspice  there aren't any circuits loaded. x3        (all three verbs exist)
```

Plain stdin is not a substitute: ngspice reads those words as a **netlist** and answers
`Error: incomplete or empty netlist`. So the leg went into **Stage 2b as a second leg of Detect**,
where a run is already paid for, gated on ⚖ **R1** — and the hazard went into `CREW_BRIEF.md`'s trap
table, because a crew testing capability detection will type that verb.

**Partially accepted.** The same lens recommended re-namespacing roughly twenty-five procs across six
file tables. The ones that plainly spell a simulator's syntax were moved (Stages 5, 7, 8, 9, 14). The
ones that are genuinely core were **named as core with their reason** instead of moved —
`ase::netlist_facts` reads the SPICE netlist xschem itself emits, `ase::si_parse` only validates what
the user typed because the value is emitted verbatim, `ase::opt_line` is D23's one speller, and the
plotmap procs read a sidecar ASE-L writes. Defaulting either way would have been the mistake; the
naming rule now makes the next case answerable without a lens.

---

## The single most important thing for the next session

**Three sentences, in this order.**

1. **Stage 1 is no longer "a refactor" — it builds the first adapter**, and its acceptance now has
   two halves: byte-identity over today's four types (**D32**), and sub-item **1e**, Xyce's
   descriptor written **on paper** to find what a second simulator breaks in the schema, *before*
   byte-identity is claimed. Fix the key set against that list while it is still free to change.
2. **⚖ R1 is still the first question to ask — keep `-b`, or move to `-p` — and then stop.** One
   question at a time is the user's standing preference. The pivot did not displace it: D34–D37 are
   decisions, not rulings, so Stages 0 and 1 still carry none and can start unasked.

   > ⚠ **2026-09-10, later the same day: ⚖ R1 was asked and answered — Option A, keep `-b`, plus an
   > always-salvage requirement. See `receipts/02-r1-answered-salvage.md`. The next question is
   > ⚖ R2.** This sentence stays as it was written, because a receipt is a record of what a pass
   > believed at the time.
3. **⚖ R10 is open.** *How far the adapter contract is formalised* — **A** the working hook plus its
   documented schema (what Stage 1 builds anyway), **B** A plus a written adapter-author
   specification, **C** B plus Stage 15's conformance harness. Recommendation **A**, ask it **last**.
   If it comes back **C**, Stage 15 stops being terminal and **Stage 8 or Stage 11 gives up the
   time** — which is the trade the user should be shown when the question is put.

And the standing one: **ship Stage 0 first, alone.** It is the only urgent stage, it costs no ruling,
and it moves no existing row.

---

## What is still true and was re-confirmed

* **Stages 0–14 are frozen.** Sixteen `## Stage <n>` headings in `PLAN.md` and sixteen in
  `LEDGER.md`, 0 through 15, in order, none renumbered, reordered or merged. All new work rode as a
  sub-item (1e's naming rule, 2d, Detect's second leg) or as Stage 15.
* **Nothing is implemented.** This batch is still a plan.
* **The batch is self-contained.** The pivot and this pass added **no file** to the directory except
  this receipt.

---

## Follow-up, same day — the shared-clone reconciliation

Two edits to `CREW_BRIEF.md` after the pivot landed, both prompted by a discovery made while
verifying that the pivot's edits had not touched anything outside this batch.

**What was found.** `git status` in this clone showed five modified tracked files that are not
part of this batch — `CLAUDE.md`, `doc/claude/issues/NUMBERING.md`, `doc/claude/specs/owed.md`,
`tests/headless/owed.sh`, `tests/headless/test_owed.sh` — modified between 10:49 and 11:16 on
2026-09-10, filing issue 1400 and reserving issue block 1500–1599.

**Attribution, stated honestly.** These are *not* this batch's work: an audit of every agent
transcript from all four workflows found zero mutating operations (Bash command head, `Write`
or `Edit`) against any of the five, and every mtime precedes the pivot workflow. Who did write
them is **not established**. An initial guess that it was the `op-wcard` session was wrong and
is recorded here as wrong: `/home/analog/dev/xschem-op-wcard` is a **separate clone** on branch
`op-wcard`, with its own separate modifications (`psprint.c`, `save.c`, `xschem.tcl`, its
`hier_pdf_links_batch/` docs, and its own `NUMBERING.md`), and all four shared files differ in
content between the two clones. The guess came from reading the diff's subject matter and
inferring an author from it, which is not evidence.

**What changed in `CREW_BRIEF.md`.**

1. *The three ledger debt kinds* — a new block recording that the `owed.sh` ledger lives in
   `$HOME` and cannot distinguish two clones, that there are two clones on this machine, that
   `owed.sh add|clear … --repo <clone>` now exists, and that `CLAUDE.md` wins wherever it and
   this brief disagree about `owed.sh`. The brief's own quoted interface predates the flag,
   which is the reason the precedence rule is stated rather than the interface simply patched:
   `owed.sh` is under active change by work outside this batch.
2. *The xschem tree* preflight — a new row and a warning that this clone is shared, naming what
   was modified and when, and instructing a crew to run `git status` before starting and to
   re-measure this preflight's numbers and `LEDGER.md`'s baseline rather than trusting them.

**Not done, deliberately.** Nothing outside `doc/claude/ase_analyses_batch/` was touched. The
five modified files belong to whoever is working on them; this batch does not reconcile, revert
or comment on them in place.

**Consequence for the handoff.** The prompt handed to the implementing session no longer needs
to carry the shared-clone caveat as external context — the brief carries it. The prompt still
needs its counts kept current (`PLAN.md` is Stages 0–15; `DECISIONS.md` was D1–D37 and R1–R10 when
this was written, and is **D1–D41** with ⚖ R1 answered since `receipts/02-r1-answered-salvage.md`).
