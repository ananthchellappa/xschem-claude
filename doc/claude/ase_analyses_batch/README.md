# ASE-L analyses batch — opened 2026-09-09

⚠ **THAT CHANGED ON 2026-09-10: Stage 0 has landed.** This paragraph read *"Nothing here is
implemented — `src/ase.tcl` and `src/ase_window.tcl` are untouched, no suite row was added,
no issue has been minted and no line of Tcl was written"* through the plan, the adapter
pivot, the salvage amendment and the variant amendment, and it was true of every one of
them. It is not true now: **Stage 0 shipped as issue 1401** — five new procs in
`src/ase.tcl`, twenty suite rows across two files, two floors raised, three spec paragraphs
and one `rule` debt. `src/ase_window.tcl` is still untouched (Stage 0 is entirely in the
non-GUI half), and **Stages 1–16 are still unimplemented**. `receipts/05-stage-0-silent-drop.md`
is the account and `LEDGER.md`'s Stage 0 block the numbers.

⚖ **R1 and R2 are answered** (both 2026-09-10); **R3 is next**, and R3–R11 are still the
user's. Everything in this directory that is not Stage 0 is still a plan.

## What was asked

> Without changing any designs, we want to create a plan to capture every simulation capability of this version of ngspice in the ASE-L GUI (Analog Simulation Environment) of Xschem being worked on in /home/analog/dev/xschem-claude - the fluid-editing branch. If you look in the src directory of that folder, you will see ase_window.tcl and ase.tcl
>
> Is this a reasonable ask - to look at two projects? We want to make every simulation capability (all analysis types, and accompanying options) easily accessible through the GUI - user should be able to choose any supported analysis and set options easily. We want to be better than Cadence's Analog Design Environment.
>
> For now, all I am asking is for analysis (for Xschem, I believe just those two Tcl files should suffice, but Claude knows best how to proceed). For ngspice, you know the project and you know where it is hosted - which websites to use : https://ngspice.sourceforge.io/tutorials.html and https://ngspice.sourceforge.io/docs.html
>
> The customer for the plan document that will be created is a future Claude Code session operating on Xschem, to incorporate the features into the future GUI

**And a second question, asked 2026-09-10, which the variant-support amendment answers:**

> Given that most users who download our Xschem won't have *our* ngspice, what hooks should be put
> into place so that Xschem ALSO works with the apt installed ngspice and the basic officially
> downloaded and built (version 47 as of this writing) repo? What our repo adds is casemode support
> and some bug fixes (plus the blanket OP device info save). Basically, we are asking for bells and
> whistles of ngspice to be exposed through ASE-L GUI, but the question of version does come up. So,
> there probably needs to be a stock 'basic' ASE-L which can fire up the needed hooks after
> detecting the version of ngspice the user has said to use.

The answer is **one ASE-L, N feature gates, zero version comparisons** — and two of the question's
own premises did not survive measurement. The fork implements **no blanket OP device-info save**
(`evidence/fork-features.md` §1: the shipped tier-`d` dump is an *upstream* fix that is in no
release), and **detecting the version cannot work**: stock upstream 47 and this fork both report
`ngspice-46+`, carry a byte-identical 134-row command and help table, and answer `devhelp`
identically (`evidence/variants.md` §1.1, §5.1). What separates them is *behaviour that lands in a
file*, which is what a probe measures. "Basic" and "enhanced" are also not two modes: apt 45.2 has
`pss` and the five CIDER families that neither 46+ build has, while the 46+ builds have `pyplot`,
`astate` and `ota` that 45.2 lacks — **the subsets overlap without nesting**, so neither binary is
the basic one.

Yes, it was reasonable, and the two files were enough for the Xschem side: every anchor
this batch needs is a proc in `src/ase.tcl` or `src/ase_window.tcl`. The ngspice side
needed more than the two websites — the manual and the source disagree in at least four
places (`evidence/docs-web.md`), so the grammars in this batch come from the parser and
from runs of the built binary, with the manual used as a cross-check and cited when it is
wrong.

## The files

The canonical set is `evidence/ase-conventions.md` §10.1's, and all of it is on disk. The
adapter amendment added **no document**: the doctrine rides in the files below, and the
conformance harness rides as `PLAN.md`'s Stage 15. Its only new file is its receipt,
`receipts/01-contract-pivot.md`. The salvage amendment of the same day added **one dossier**,
`evidence/salvage.md`, plus its receipt `receipts/02-r1-answered-salvage.md`; its plan items
ride as sub-items **2e** and **6f** inside the stages that own their surfaces. Stages **0–15
keep their numbers** — `LEDGER.md` has one section per stage and they are cited by number.

**The variant-support amendment, 2026-09-10 (later the same day again)**, added **three
dossiers** — `evidence/variants.md`, `evidence/fork-dependencies.md`, `evidence/fork-features.md`
— plus its receipt `receipts/03-variant-support.md`. It answers *"most users who download our
Xschem will not have our ngspice"*: its plan items ride as extensions to **1a/1b**, new sub-items
**2f/2g**, **6g**, **7g**, and one new **terminal Stage 16**; its decisions are **D42–D52**; and
it carries **one new unresolved ruling, ⚖ R11** — the minimum supported ngspice — filed *behind*
R2 in the ask order, not ahead of it. Stages **0–15 still keep their numbers.**

| file | what it holds |
|---|---|
| `README.md` | this file — what was asked, the file table, the one-paragraph version, how it was produced |
| `CREW_BRIEF.md` | **read before touching anything.** The request again, the standing rules every crew obeys, the "do not change designs" doctrine in its three senses, and the preflight — the facts the driver measured so no crew re-derives them |
| `PLAN.md` | **THE deliverable, and it is authoritative.** Fifteen stages on three axes, 0 through 14, plus two terminal stages that are on none of them — **Stage 15**, the adapter conformance harness, and **Stage 16**, *"the ngspice you actually have"* — opening with the corrections that did not survive checking, which is also where the adapter pivot and the variant amendment are recorded; the ruling ledger, the costed refuse-list, the ADE-L comparison and what it rests on, the sequencing table. Stage 1 carries the adapter contract, the naming rule that keeps later stages honest, and the paper check of the schema against a second simulator; Stage 2 owns the *Setup > Simulators* gesture and the variant record; Stage 15 is the conformance harness; **Stage 16 is terminal in numbering and first in adoption value** |
| `APPENDIX_ngspice_analyses.md` | the ngspice side at the **parameter level** — eleven analyses plus the pseudo-analysis, both option catalogues, the results routing, the trap and defect register. Every plan item cites a section here instead of restating it |
| `DECISIONS.md` | D1–D52, plus ⚖ R1–R11, of which **R1 and R2 are answered** (R1 Option A, 2026-09-10, with the always-salvage requirement; R2 yes-with-four-conditions, 2026-09-10) and R3–R11 wait — carried unresolved with options, trade-off and a recommendation. **D34–D37 and ⚖ R10 are the 2026-09-10 adapter pivot's; D38–D41 and the answer recorded at ⚖ R1 are the salvage amendment of the same day; D42–D52 and ⚖ R11 are the variant-support amendment's** |
| `LEDGER.md` | the baseline measured **before any crew started**, one empty section per stage, and the debts this batch already knows it will leave |
| `evidence/` | **29 files**, below. The research base. Nothing in it was written into either repository |
| `receipts/` | one receipt per stage lands here as the work does. `00-plan-authored.md` is the receipt for the authoring pass; `01-contract-pivot.md` is the receipt for the 2026-09-10 adapter pivot; `02-r1-answered-salvage.md` is the receipt for ⚖ R1's answer and the salvage amendment later the same day; **`03-variant-support.md`** is the receipt for the variant-support amendment (the *"what if the user does not have our ngspice"* pass); `04-dev-build-rebuilt.md` is the receipt for reconfiguring `build-ver_50` with PSS and CIDER; **`05-stage-0-silent-drop.md` is the first receipt for CODE — Stage 0, issue 1401, and ⚖ R2's answer** — each records what changed in every document, what was measured, and what was rejected |

### `evidence/` — 29 files

| file | what it holds |
|---|---|
| `design-of-record.md` | **the spine, 2323 lines.** The plan itself: eight areas S1–S8, twenty-eight decisions DR1–DR28, fifteen stages 0–14, nine rulings R1–R9, twenty-nine corrections C1–C29, the refuse-list, and twelve open measurements M1–M12. Synthesised from `design-A/B/C` after judging; its author re-measured nineteen claims personally, marked `[R-M<n>]` |
| `00-critique.md` | the completeness critique over the seventeen extraction dossiers: six resolved inter-dossier contradictions, four defects nobody else found, and the answers to the "how do I actually drive this" questions |
| `builds.md` | the decisive one. PSS, CIDER and libngspice **built and run**, plus the measured `-b` vs `-p` vs libngspice transport verdict |
| `an-core.md` | OP, DC, TRAN and `OPTinfo`, parameter by parameter, from the C structures |
| `an-smallsig.md` | AC, NOISE, PZ, TF, DISTO, SENS — parameters, plot names, failure modes |
| `an-rf-pss.md` | the build-gated ones: SP (RFSPICE), PSS (`WITH_PSS`), and the HB remnant |
| `dotcards.md` | the netlist dot-card grammar for analysis, as the parser accepts it — not as the manual describes it |
| `commands.md` | the `.control` / interactive command surface: what a GUI can drive and in what order |
| `options.md` | catalogue one — `OPTtbl`'s "~86" keywords (**corrected to 98 rows / 57 settable** in `PLAN.md` §0.4 and `APPENDIX` §3.1; "86" counted a narrower set), the five different mechanisms the word "option" covers, and which entries are dead |
| `hidden-vars.md` | catalogue two — 163 `cp_getvar` variables at 304 call sites, **provably disjoint** from `OPTtbl`, with the CP-type table and the 26 that `.options` cannot reach |
| `convergence.md` | initial conditions, the convergence machinery, and the "it did not converge" remedies as a GUI can offer them |
| `orchestration.md` | sweeps, corners, Monte Carlo, temperature; launching, monitoring, aborting and post-processing a campaign |
| `measure.md` | `.meas`, `four`, `fft`, `linearize`, the expression vocabulary — the surface that reads a number back |
| `outputs.md` | what a run produces and how a GUI gets it back: rawfile shape, plot names, the libngspice API |
| `xspice.md` | XSPICE / mixed-signal, and how event nodes change what the rawfile contains |
| `cider-devices.md` | CIDER, OSDI, and the per-device function-pointer gating of every analysis |
| `trnoise.md` | transient noise (`trnoise`) and random sources (`trrandom`) |
| `docs-web.md` | the official manual and tutorials as a cross-check, with each disagreement named |
| `salvage.md` | what a stopped batch run can keep: `stop after` checkpointing in `-b`, why `-r` deletes the path under a `.control` deck, the signal table, and what a checkpoint costs. **Supersedes the quick pass that preceded it — five of that pass's load-bearing statements are refuted in its §1 scorecard, and one of its own is refuted there too** |
| `ase-state.md` | ASE-L's persisted state schema and the blast radius of changing it |
| `ase-deck.md` | `render_deck`, the run pipeline, the capability probe |
| `ase-ui.md` | the window, the dialog, and the ADE-L parity table |
| `ase-conventions.md` | **the house-shape authority.** §1 the standing rules, §2 issue numbering, §3 "do not change designs", §10 the canonical file set and citation rules |
| `design-A.md` | competing design: minimum-risk incrementalism. Kept for provenance; source of the writer and the twelve-row table |
| `design-B.md` | competing design: "the simulator declares, the netlist permits, the GUI reflects". Source of the architecture |
| `design-C.md` | competing design: the analysis surface as a compiler with a visible IR. Source of the campaign generator and the sidecar |
| `variants.md` | **the variant-support amendment's first dossier, 2026-09-10.** Stock upstream 47 built and characterised beside apt 45.2 and the fork: the three-binary command/help/`devhelp` comparison, the measured proof that **stock 47 and the fork are indistinguishable by inspection** (same `ngspice-46+` string, byte-identical 134-row help table), and the measured `$casemode` false-positive trap |
| `fork-dependencies.md` | the 105 functional fork commits classified: 60 casemode-gated capability, 5 new default-mode diagnostics, 35 bugs still live upstream, 5 fork-internal. Five hard crashes reproduced live on apt 45.2, and the measured headline that **an ordinary ASE-L deck runs byte-identically on apt 45.2 and on the fork** |
| `fork-features.md` | what the fork actually adds, measured rather than assumed: there is **no blanket OP save** in it (the tier-`d` dump is an *upstream* fix, in no release), casemode's degrade path is already complete, and the per-binary capability dicts produced by running ASE-L's own probe decks A/B/C verbatim |

## The one-paragraph version

**ASE-L owns the schema; a per-simulator adapter owns the content.** The analysis list, each
analysis's fields, units and defaults, its emit syntax, its option catalogue and its result naming
are **data an adapter supplies**, not knowledge ASE-L's own source accumulates — the user registers
a simulator under *Setup > Simulators*, and its adapter is what makes the forms appear. Adapters are
first-party for now, written by Xschem's own agent and versioned with this tree, so an adapter is
executable Tcl on the existing `ase::register_backend` hooks. **ngspice is the first adapter and the
hardest case**, and it is written *through* the contract rather than around it, because a contract
with no implementation pulling on it fits nothing. Today ASE-L knows four analyses — `op`, `dc`,
`ac`, `tran` — and knows them **eight** times over:
`ase::state_default`'s seed, `anaargs`, the radio `foreach`, `anorder` plus its switch, **the
print anchor's own loop twelve lines below `anorder`**, `ase::ui::chana_fields`,
`ase::ui::chana_show`'s destroy list and `ase::plot_sim_type` each carry their own copy of the
answer, each fails silently when it drifts, and one already has (`ac`'s `dec` key is advertised
in `anaargs`, omitted from `chana_fields`, and hardwired in `render_deck`). Seven were known;
the eighth is `PLAN.md` §0.3's correction. The ngspice the user actually runs answers to ten
analysis verbs — `sp` present, `pss` absent from this build, measured today — and its option
surface is two provably disjoint catalogues, `OPTtbl`'s **98** keywords of which **57** are
settable, and 163 `cp_getvar` variables, 26 of which `.options` cannot reach at all. The plan
collapses the eight copies into one declarative registry, `ase::analysis_types`, resolved through an
**optional `analysis_types` backend hook** and falling back to the empty list, never to a literal —
that hook is the adapter contract, and ngspice's descriptor is its first content. It puts every
type, field and option through
four gates — can ASE-L render it, does this binary have it, does this netlist permit it,
can this value physically reach the simulator — presented in four states (`ok`, `caution`,
`blocked`, `absent`) so an analysis this build lacks is listed and disabled with the reason
and the fix rather than hidden, which is the first place it is plainly better than ADE-L.
It deletes the correctness defect under today's form — the analysis Options sheet collects,
stores, round-trips and displays option values the deck never emits — by refusing at OK
anything the emitter cannot spell. Analyses stay `.control` commands emitted one at a time;
multi-plot analyses gain a `setplot previous` walk plus a creation-ordered plotmap sidecar,
the only writer shape measured that keeps every plot and still leaves genuine data first in
the rawfile. Above that sit a measurement surface (the thing all three designs lost), a
shard-runner campaign for sweeps, corners and Monte Carlo with the statistics computed in
Tcl because ngspice has no sort and no histogram, and the digital half of a mixed-signal run
through `eprvcd` into the VCD pipeline ASE-L already owns. And because most users who download
this Xschem will run the ngspice their distribution shipped — measured, **45.2 on the current
Ubuntu LTS** — there is **one** ASE-L with N feature gates and **zero** version comparisons: the
capability dict `ase::sim_capabilities` already returns is the whole variant record, extended with
new keys rather than joined by a second store, and a **version-keyed table has exactly zero rows**
because stock upstream 47 and this fork are byte-identical on `-v`, on all 134 help strings and on
`devhelp`. Fifteen stages, 0 through 14, plus two terminal stages outside them, **Stage 15** (the
conformance harness, outside this pass) and **Stage 16** (*the ngspice you actually have*); stage 0
(the silent drop dies) and stage 1 (the registry, byte-identically — and, before that byte identity
is claimed, Xyce's descriptor written **on paper** to find what a second simulator breaks in the
schema) carry **no rulings** and can ship immediately; stage 15, the conformance harness an adapter
author runs against their own binary, is terminal because it is what the *second* adapter needs and
the first one does not; ⚖ R1 was asked first and alone and is **answered** (2026-09-10, Option A: keep `-b` this batch,
`-p` deferred), and it left a requirement behind — **always salvage**, which lands as Stage 6f, with
the Stop warning that is honest until it does as Stage 2e; ⚖ R2 was asked next and alone and is
**answered** (2026-09-10, yes with four conditions — the file is deleted and rewritten per run, the
user's own lines are copied and never `source`d, the run log says what it shadows, and it is refused
under `-n` and under the shared-rundir fallback), which unblocks Stage 7's pre-deck class and Stage
11's design-variable axis; **nine** rulings wait for the user, ⚖ R3
next and alone, R10 — how far the adapter contract is formalised — filed behind it
because Stage 1 builds the working hook either way, and **⚖ R11 — the minimum supported ngspice —
filed last of all**, because the probe answers "how old is too old" per binary and R11 asks only
whether the download page promises anything at all.

## Why this shape

**The goal is Xschem adoption.** The user is promoting Xschem and needs it to support everything
ngspice offers so usage takes off, so when two items compete, depth of ngspice coverage, the
differentiators someone would switch for, and low friction on first run win over internal elegance
no user sees. **And the person on the other end of that adoption is running the ngspice their
distribution shipped** — on the current Ubuntu LTS, `45.2+ds-1`, measured. The reassuring half of
the variant amendment is that the gate is largely already open: on apt 45.2, ASE-L's full deck runs
to rc 0, two plots, identical `Variables:` blocks and identical printed values, byte-identical to
the fork for the op and transient deck shapes it emits today (`evidence/fork-dependencies.md` §4.0,
`evidence/fork-features.md` §3). The remaining work is mostly a sentence that says so, plus a
handful of gates the tree already has the machinery for. The adapter split is not anticipation, it is measured on this one machine, both ways: a bare
`../configure` build of upstream (`workpad/builds/upstream47`) returns `Sorry, no help for pss.`
while `/usr/bin/ngspice` (45.2) answers `help pss` and runs it — and on 2026-09-10 the dev build at
`build-ver_50` went from the first answer to the second when it was reconfigured with
`--enable-pss --enable-cider`, reporting the identical version string `ngspice-46+` before and
after. So *the same simulator* presents different analysis sets depending on how it was
configured, and no version string can tell you which. That is why
capabilities are **asked for rather than asserted**, and why the analysis list is data an adapter
supplies instead of a literal ASE-L carries.

## How this was produced

Three research workflows, roughly 8.5 M subagent tokens across about fifty agents:

1. **Extraction.** Seventeen agents, one per area of the two trees, each writing a dossier
   from source and from runs of the built binary; then a completeness critic that read all
   seventeen end to end and produced `00-critique.md` — six inter-dossier contradictions
   resolved, four ngspice defects nobody else had found.
2. **Hole-filling.** A pass aimed at the critique's own gaps, which produced
   `hidden-vars.md`, `trnoise.md`, `docs-web.md` and the ASE-L-side dossiers.
3. **The design panel.** Three independent designs (`design-A/B/C`) written to the same
   brief, judged against each other, with build probes running concurrently —
   `--enable-pss`, `--enable-cider` and `--with-ngshared` were configured, built and run,
   which is `builds.md`. The panel's verdict was synthesised into `design-of-record.md`,
   whose author then re-measured nineteen claims personally rather than inherit them.

Every factual claim in `evidence/` is anchored to a file and line in one of the two trees,
to a URL, or to a run of `/home/analog/dev/ngspice/build-ver_50/src/ngspice`. Where a claim
was refuted the refutation stays in the document — `design-of-record.md` §12 is
twenty-nine corrections, including several against its own sources.

**Why the evidence lives here and not in a scratch directory.** An intermediate `/tmp` wipe
destroyed one pass's scratch files mid-batch. The dossiers were reconstructed from the agent
transcripts and copied into `evidence/`; that is why this directory carries its own research
base rather than pointing at one. Two consequences a reader should know:

- ⚠ **Cross-references inside the dossiers are stale.** They cite each other as
  `../dossiers/<file>.md` — read that as `evidence/<file>.md`. `design-of-record.md` cites
  its own decks as `../dor/<name>.cir`; **that directory no longer exists.** Every
  `[R-M<n>]` measurement quotes its deck text in full, so a challenged measurement is
  re-typed and re-run, not re-opened.
- ⚠ `design-of-record.md` §0.1 says nineteen measurements and numbers them `[R-M1]`…`[R-M19]`,
  while its §17 table says `[R-M1]…[R-M18]`. Nineteen is right; §17's count is stale.

Re-verified against the binary today, 2026-09-09, before this file was written: the `disto`
unresolvable-save segfault (rc 139), `sens … ac` under `.options klu` (rc 139), `ac lin 2`
returning one point, `help tf` printing the transient help, `sp` present and `pss` absent in
`build-ver_50`, CIDER absent from it, and 105 `.state` files on disk — **104 of them
committed** — each carrying exactly four analysis rows. `CREW_BRIEF.md` carries the numbers.
⚠ **Superseded 2026-09-10 for PSS and CIDER only:** `build-ver_50` was reconfigured with
`--enable-pss --enable-cider` and now has both; every measurement in `evidence/` predates that
binary. See `receipts/04-dev-build-rebuilt.md`.

## Not filed yet, deliberately

`design-of-record.md` §14 lists nine rulings and §2 twenty-eight decisions. **None of them is
in `owed.sh` and no issue has been minted**, because nothing has shipped and a ledger entry is
a record of an unratified decision that is already in the tree. When the work starts they go
in as one issue plus one `owed.sh add rule <that issue>`, per the ledger's own batching rule.

`doc/claude/issues/NUMBERING.md` has **not** been advanced by this batch. Its tail reads *"The
next free number is 1400."* at HEAD `2f1fad58` — but that is a value to re-read at the moment
of minting, never to trust from a document.
