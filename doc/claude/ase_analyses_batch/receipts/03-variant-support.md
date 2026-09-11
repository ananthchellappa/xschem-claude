# Receipt — the variant-support amendment, 2026-09-10

*"Most users who download our Xschem won't have **our** ngspice."*

**What this pass was asked.** Verbatim:

> Given that most users who download our Xschem won't have *our* ngspice, what hooks should be put
> into place so that Xschem ALSO works with the apt installed ngspice and the basic officially
> downloaded and built (version 47 as of this writing) repo? What our repo adds is casemode support
> and some bug fixes (plus the blanket OP device info save). Basically, we are asking for bells and
> whistles of ngspice to be exposed through ASE-L GUI, but the question of version does come up. So,
> there probably needs to be a stock 'basic' ASE-L which can fire up the needed hooks after
> detecting the version of ngspice the user has said to use.

**The answer, in one line.** **One ASE-L, N feature gates, zero version comparisons** — and the
version-keyed table the question implies has **exactly zero rows**, because the two binaries it
would most need to separate are byte-identical on every identity signal ngspice exposes.

⚠ **Nothing was implemented.** `src/ase.tcl` and `src/ase_window.tcl` are untouched, no suite row
was added, no issue was minted, no line of Tcl was written. Every write is inside
`doc/claude/ase_analyses_batch/`.

---

## 1. What was measured, and what it overturned

Three dossiers were written before this pass (`evidence/variants.md`,
`evidence/fork-dependencies.md`, `evidence/fork-features.md`) and a third binary was built. This
pass re-measured what it was about to write down. Everything below was executed, 2026-09-10.

### 1.1 Two of the question's own premises did not survive

| the premise | what is true |
|---|---|
| *"what our repo adds is … the blanket OP device info save"* | **The fork implements no blanket OP save.** A grep for `saveopparam\|saveoppoint\|saveopinfo\|oppoint\|opparams\|allop` over the fork returns nothing; the fork's entire diff to `src/frontend/breakp2.c` (the `save` grammar) is **two `eq`→`eqc` substitutions**; and `save @m.xo1.xi1.m1[*]` fails byte-identically on apt 45.2 and on the fork. What exists is a request document whose own status line reads *"draft — not yet sent"*. ⚠ **And the one tier that behaves like a blanket save — tier `d`, `set altshow` + `show all >` — is UPSTREAM**: it needs `10276f993`, and `git tag --contains 10276f993` returns **nothing** (verified this pass), so it is in `pre-master-47` and in **no release** |
| *"after detecting the version of ngspice the user has said to use"* | **Version detection cannot work.** Stock upstream 47 and the fork both print `ngspice-46+`; all 134 `spcp_coms[]` names match; a join of the two 134-row help-string lists filtered to rows that differ is **empty**; `devhelp` is identical. Only the build timestamp differs, and that records whoever ran `make` |

And a third, from the shape of the request rather than its words: *"a stock **basic** ASE-L"* cannot
be a mode, because **the subsets overlap without nesting**. apt 45.2 has `pss` (verified this pass:
`help pss` → *"Do a periodic state analysis"*) and CIDER's five families, which **neither** 46+
build has; the 46+ builds have `pyplot`, `astate` and `ota`, which 45.2 lacks. Neither binary is
the basic one.

### 1.2 What this pass measured itself, beyond re-verifying the dossiers

| # | measurement | result |
|---|---|---|
| **1** | **A narrowed `save` starves `noise`, `tf` and dc `sens` — not only `disto`** | On **all three** binaries: `save v(mid)` + `noise … dec 5 1k 100k 1` → `Error: no data saved for Noise analysis; analysis not run`, `$sim_status` **1**, a rawfile holding only `Plotname: constants`. Identical for `tf` (*"no data saved for transfer function analysis"*) and dc `sens` (*"no data saved for Sensitivity analysis"*). **`pz` survives** (`$sim_status` 0). Remove the save and the same decks give rc 0 and both noise plots. **New — no document in the batch had this**, and it generalises T2/X1: *an analysis whose result vectors are not netlist names cannot run under a `save` list derived from netlist names* |
| **2** | **A bare `write` after `noise` keeps ONE of its two plots** | On all three: `$plots` = `const noise1 noise2`; a bare `write z.raw` produces only `Plotname: Integrated Noise` — the spectral-density curves gone, at rc 0 and `$sim_status` 0. `write z.raw noise1.all noise2.all` yields both, and (unlike `foreach p $plots`) does **not** write `constants` first. ⚠ But the plot ids are **session counters** — measured `const op1 ac1 noise1 noise2` in a deck that ran `op` and `ac` first — so a second noise run is `noise3`/`noise4`. The `setplot previous` walk stays the shape of record |
| **3** | **The keyword-case probe: the obvious form probes nothing** | A capitalised **command name** works on all three — `Echo "…" >> f` produced its line on apt 45.2 *and* on the fork, because command dispatch inside a deck's `.control` block is folded. The unfolded path is the **argument**: `write probe_k.raw ALL` leaves **no file** on apt 45.2 and stock 47 (`Warning from checkvalid: vector ALL …` / `Error during 'write': no writable vector found.`) and a file on the fork. **New probe, one line, zero extra processes** |
| **4** | **The `gnd` probe is free** | `echo "@@gnd=M7 my gnd rail" >> f` returns `M7 my 0 rail` on apt 45.2 **and stock 47**, `M7 my gnd rail` on the fork. One line inside leg D's already-running `.control` block |
| **5** | **Leg D and the refused leg E reproduce exactly** | Leg D: `v(mid)` + **`v(all)`** on apt 45.2 and stock 47, `v(mid)` alone on the fork. Leg E: rc **134**, `it's a US_SIMVAR!` / `free(): invalid pointer`, marker absent on apt 45.2 and stock 47; rc 0 and `lifetime_ok` on the fork. `/usr/bin/time` on leg D: **0.00 s** on all three |
| **6** | **apport is installed and enabled on this very release** | `dpkg -l apport` → `ii  apport  2.34.1-0ubuntu0.1`; `/etc/default/apport` → `enabled=1`; `systemctl is-enabled apport.service` → `enabled`; `/usr/lib/systemd/system/apport-coredump-hook@.service` present. It is silent **here** only because WSL leaves `/proc/sys/kernel/core_pattern` at `core` and `systemd-coredump` is `un` (not installed) |
| **7** | **The tree's own seams, read in `src/ase.tcl` / `src/xschem.tcl`** | `ase::raw_content_verdict` returns `{ok constants appended plotname nvars npoints signature why}` — no variable list, and it never reads `Values:`. `ase::cap_raw_plots` is the one Tcl proc that returns a vector list. `ase::op_param_split` demands an `@dev[param]` shape. `ase::cap_run` sets `cut` only `if {[llength $cap]}`, and `ase::cap_timeout_cmd` answers `{}` with no `timeout(1)`. `sim_probe_capability` loops `foreach m {fold preserve distinguish}` — **three** processes — and lives at **global scope in `src/xschem.tcl`**, where `sim_probe_argv` emits `-D casemode=$mode`. `ase::run_precheck` makes an **uncached** `ase::sim_probe_run` launch on every Run press when the requested casemode is not `fold`. 17 `dict exists … && [dict get …]` sites, ~12 of them capability keys |

---

## 2. The reviews — what was adopted, and what was rejected

Two reviews were run against the design. **Sixteen of eighteen findings were verified and
adopted; one was adopted with its proposed form replaced by a measured one; one was partly
rejected.** Verification was against the tree and against runs, not against the reviews' own text.

### 2.1 Adopted, verified

| finding | verified how | what it changed |
|---|---|---|
| The "free twin" cannot live in `ase::raw_content_verdict` | read the proc: read-only diagnosis over a 64 KB head/tail slice, no variable list, never reads `Values:` | `PLAN.md` 6g-2 names the real seams (`ase::cap_raw_plots`, the `xschem raw list` consumers) and records that ASE-L is **already immune** at the op-parameter seam. Also drops `allv`/`alli` from the filter — they are ASE-L's own Save-All tokens, not vector names |
| Leg E's verdict is single-sided and its guard is structurally unavailable | read `ase::cap_run` (`cut` only when `[llength $cap]`) and `ase::cap_timeout_cmd` (`{}` with no `timeout(1)`) | folded into **D50**'s two-marker discipline for any future aborting leg, and *"`cut` is corroboration, never the guard"* |
| Leg E crashes the user's ngspice from the Run path | rc 134 reproduced on both; apport verified installed **and enabled** on this release | **leg E deleted.** `DECISIONS.md` **D50**, `PLAN.md` §0.13.6, a refuse-list entry, `APPENDIX` §7.5's ⚠ |
| The "new sub-item 1e" collides with the existing 1e | `PLAN.md` line 1072 is `### 1e. Xyce's descriptor…` | `requires`/`notes`/`lint` ride **1a** and **1b**; **1e is re-run against the extended schema** and gains one question |
| Leg D's `@@casemode=` feeds no key and would narrow `casemode_detected` | measured `none`/`none`/`fold`; `sim_probe_leg`'s own header names the inference measured-false | **D52**: Band-1 `curcasemode_default` only; `casemode_detected` owned exclusively by the three delivery legs |
| "First probe that separates fork from stock" is false | the shipped `nocasemode` arm already publishes `{fold}` for apt/stock and `{fold preserve distinguish}` for the fork | leg D is justified on `one_vector_write` alone; the claim is gone |
| R11 blocks the ship-first item; the ruling queue is closed at R2 | `DECISIONS.md` reads *"Ask ⚖ R2 next, and stop"* | **16e splits**: the description ships with no ruling, only the support sentence is R11, and R11 is filed **last** |
| "One reader, not fourteen" was asserted but never staged | 17 idiom sites in `src/ase.tcl` | conversion is **part of Stage 2f's commit**, plus a conformance row |
| The D34/D36 audit misses that the casemode legs live in `xschem.tcl` | `sim_probe_capability` at global scope; `sim_probe_argv` emits `-D casemode=` | **D51** records the breach explicitly rather than moving the procs |
| The leg arithmetic is wrong | `foreach m {fold preserve distinguish}` is three processes | **six** today, **seven** with leg D — stated with the drop order beside it |
| `noise` is starved by a narrowed save | measured, all three (§1.2 #1) | **T15**, `APPENDIX` §7.5.2, 6g-1, 7g — **and extended to `tf` and dc `sens`, which the review did not name** |
| The M-free/M-artifact cost test fails its own examples | — | **D46** restates it as two questions, and files the narrowed-save rule as *M-artifact applied unconditionally as a correctness precondition*; `ac lin 2` becomes a **warning that names the fix**, not a refusal |
| §4b's worked sentences claim an unproven fix and contradict their own frame | `git tag --contains 10276f993` → empty; `help pss` answers on apt 45.2 | **three sentences 16a must not say**, written into `PLAN.md` Stage 16a |
| `caps_is` cannot express a mitigation gate | — | **`ase::caps_measured_as`** added as the third predicate, with the rule and a conformance grep (**D48**) |
| The budget arithmetic hides which legs a slow box drops | `ase::sim_caps` written only on `known 1` | true count stated with the drop order; **`unmeasured_keys` promoted to a Stage 2 deliverable**; **a fourth sentence frame** for *"measured, but not completely"* |

### 2.2 Adopted, with the proposed FORM replaced by a measured one

**"The `gnd` and keyword-case probes cost no leg."** The premise is right and the rule it replaces
(*"a probe that only buys silence is not worth a leg"*) was too blunt — **D49** now distinguishes a
probe that needs its own **process** from one that is a line in a deck already running. The `gnd`
half works exactly as proposed. ⚠ **The keyword-case half does not**: the review proposed *"a
capitalised keyword echo"*, and a capitalised **command name** is folded and probes nothing
(measured: `Echo` works on all three). The working form is a capitalised **argument** —
`write probe_k.raw ALL` — which is a clean file-existence verdict. The corrected form is what went
into `APPENDIX` §7.5.1 and `PLAN.md` 2g, with the refuted form recorded beside it in §0.13.8 so the
next reader does not re-propose it.

### 2.3 Partly rejected, with the reason

**"`noise` is offered as ungated `ok` while ASE-L's writer silently discards half the result — so
drop `noise` and `disto` from `ok` to `caution`."**

* **The measurement is right and is banked** (§1.2 #2, `APPENDIX` §7.5.3): a bare `write` after
  `noise` keeps one plot of two, at rc 0.
* **The conclusion conflates two different things.** In `PLAN.md`'s four-state grid, `ok` is a
  statement about **the binary** — *this ngspice has that analysis* — and `registered` is the
  separate key that decides whether **the GUI offers** the type. Stage 1's four registered types are
  `op dc ac tran`; `noise` becomes offerable at **Stage 6**, whose 6a is the `setplot previous`
  walk — i.e. the plan already schedules the fix as a precondition of the offer. Downgrading the
  binary-capability cell to `caution` would say something false about the user's ngspice
  (`noise` works perfectly there) in order to describe a gap in ASE-L.
* **What was adopted instead:** the measurement, as `T16` and `APPENDIX` §7.5.3, and the review's
  other half — **§8c's "every deck shape ASE-L emits" was narrowed to the shapes actually measured,
  `op` and `tran`**, in `PLAN.md` §0.13.1's ⚠.

### 2.4 One reviewer statement corrected

The honesty review wrote that apport is *"'un' (not installed)"* on this box. **Measured: apport is
`ii` — installed — at `2.34.1-0ubuntu0.1`, `/etc/default/apport` says `enabled=1`, and
`apport.service` is `enabled`.** What is `un` is `systemd-coredump`. The conclusion is unchanged
and stronger: apport is present and enabled on this very release, and only WSL's
`core_pattern=core` keeps the crash silent here.

---

## 3. What changed in every document

| file | what changed |
|---|---|
| **`PLAN.md`** | **§0 preamble** announces §0.13 and notes there are three binaries now. **§0.13** — the whole variant architecture as a standing-assumption correction, in eight parts: the good news (§0.13.1, narrowed to op+tran), no blanket OP save (§0.13.2), version detection impossible (§0.13.3), no two modes (§0.13.4), what a stock user really loses (§0.13.5), never crash the user's simulator (§0.13.6), two new universal hazards (§0.13.7), and **what was refused inside the variant work itself** (§0.13.8). **§0.1** gains *The three binaries* table with four consequences, and **T15/T16/T17** join the trap set (*"these seventeen"*). **§1** axis split now names two terminal stages. **1a** gains `requires`/`notes`/`lint` in the contract block plus `ase::requires_state`, and the ⚠ that they are **not** a new 1e; **1b** gains field-level `requires`; **1e** is re-run against them. **New 2f** (the record, four bands, three predicates, the conversion, `unmeasured_keys`) and **2g** (leg D, the three keys, the refused leg, the honest budget, the "no probe per Run press" note). **New 6g** (four mitigations, the two halves of T17, the real seams). **New 7g** (`rules` may read `caps`). **New terminal Stage 16** with 16a–16e. **Refuse-list** gains five entries: a version comparison, a version-keyed hazard table, a basic/enhanced mode split, a probe that crashes the user's simulator, and rewriting user control text. **Ruling ledger** now eleven, with R11 under the table and filed last. **Sequencing table** gains Stage 16 and the two ship-first items. **Still open** gains **M19–M21**; next free id is **M22** |
| **`DECISIONS.md`** | new **§8 Variants**, **D42–D52**: the record is the capability dict; no version-keyed table; `version_line` never compared; one ASE-L not two modes; V6′ with the two-question class test; the unknown-binary policy; the three predicates and the rule; free-probe vs own-process-probe; never crash the user's simulator (with the two-marker discipline); the `xschem.tcl` seam recorded; `casemode_detected`'s sole owner. **New ⚖ R11** — the minimum supported ngspice — carried **unresolved**, with three options, the trade-off, recommendation **C** and three conditions, and *the one thing the user is really being asked*. Rulings heading now *eleven: ONE ANSWERED, ten carried*; R10's closing line updated; the preamble says R11 is filed last and jumps nothing |
| **`APPENDIX_ngspice_analyses.md`** | new **§1.8**, the three-variant capability matrix (twenty rows, including the ASE-L capability dict and the tier each binary lands on) with the three things to read off it and the `altshow_op_dump`-is-not-a-fork-feature ⚠. New **§7.5**, the variant-keyed hazard table with its keying rule and **zero version-keyed rows**, plus **§7.5.1** the three probes with their decks and measured answers (including the ⚠ that a capitalised command name probes nothing), **§7.5.2** the narrowed-save starvation across four analyses, **§7.5.3** the one-`write` loss and why the named-plot shortcut was not taken. §10's evidence-owner table gains the three dossiers |
| **`CREW_BRIEF.md`** | the preflight's *"use this path, always"* is superseded by **⚠ THREE BINARIES, NOT ONE**, with the table, four facts, the 99-second rebuild note and the never-crash-the-user's-simulator ⚠. **Testing discipline gains a first bullet**: run the stock binary too, and say so in the receipt. Reading order updated for two terminal stages, §0.13, the three dossiers and R11 |
| **`LEDGER.md`** | baseline gains the **three-binary** amendment (apt 45.2, stock 47 with its build numbers, the removed worktree) and the rule that follows. Evidence base **26 → 29 files, 35 490 lines**, with the three new dossiers described. Rulings *nine → ten* open. **Stage 1** gains the hard-deadline sub-item and a new Stage-1-only receipt field; **Stage 2** gains 2f/2g; **Stage 6** gains 6g; **Stage 7** gains 7g; **new Stage 16 section** with a required *"tested on apt 45.2 as well as the fork"* receipt field. Debts gain **M19–M21** |
| **`README.md`** | the second question added verbatim with its answer and the two refuted premises; file table `evidence/` **29 files**; the three dossiers added to the evidence table; receipts row gains `03-variant-support.md`; the amendment paragraph added; `PLAN.md` and `DECISIONS.md` rows updated (D1–D52, R1–R11, two terminal stages); the one-paragraph version gains the variant sentence and *ten* rulings; *Why this shape* gains the adoption measurement |
| **`receipts/03-variant-support.md`** | this file |

---

## 4. What was NOT done, deliberately

* **⚖ R11 was not decided.** It is carried unresolved with options, trade-off and a recommendation,
  and it is filed **behind R2 and R10** in the ask order. The standing preference is one question at
  a time; an eleventh ruling arriving at the head of the queue would be a request to jump nine
  places.
* **No leg that crashes a user's simulator was designed in.** Leg E is deleted from the Run path
  and the discipline it leaves behind is written into **D50**.
* **The `xschem.tcl` casemode procs were not moved.** **D51** records the D36 breach instead, so a
  Stage-1 schema freeze does not close around it silently.
* **No code was written and no issue was minted.** `doc/claude/issues/NUMBERING.md` was not
  advanced; re-read its tail at the moment of minting.

## 5. Repository state

`src/` in `/home/analog/dev/xschem-claude` is **untouched** — no tracked file is modified.
`git status --porcelain` at the end of this pass shows the same five untracked entries it showed at
the start:

```
?? .xschem/
?? doc/claude/ase_analyses_batch/
?? doc/claude/rdw_lists_batch/
?? doc/claude/rdw_sim_batch/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
```

⚠ **This clone is shared with another session.** Those untracked directories are other passes'
work as well as this one's; nothing was reverted, staged or committed here. The ngspice tree
(`/home/analog/dev/ngspice`, `ver_50`) is clean, and the stock-47 build worktree created for this
work was removed — `git worktree list` shows only the main tree.
