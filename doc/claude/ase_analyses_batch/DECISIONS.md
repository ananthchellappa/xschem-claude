# Decisions — ASE-L analyses batch

Numbered so a crew, a suite row and a commit message can all cite the same thing.

**Two kinds, and the difference is the point of this file.**
A **D<n>** is a decision *this plan takes* on the evidence: it is the lead's, it is
reversible on a word, and it is written so that a future session can implement from it
without re-reading the dossiers. A **⚖ R<n>** is a question that is the **user's**, carried
here unresolved, with its options, its trade-off and a recommendation. No crew resolves an
R on its own; no crew re-opens a D without saying so in its receipt.

**Provenance.** `D<n>` is `DR<n>` of `evidence/design-of-record.md` §2, restated in one
place so a commit can cite one number instead of a section. `D29`–`D33` are not in §2:
they are forced by the registry's own shape (§3.1) and by the stage table (§13), and they
are called out separately below because they are the decisions that make the other
twenty-eight *enforceable* rather than *remembered*. `⚖ R1`–`R9` are §14 verbatim in
substance, re-ordered not at all — §14 already orders them by consequence.

`D34`–`D37` and `⚖ R10` are newer than the design of record and appear in neither §2 nor §14.
They come from the **2026-09-10 architecture change** — the user's ruling that the third-party
tool vendor does the integration, so ASE-L has to be a thing an adapter plugs into rather than a
thing that knows about ngspice — which `PLAN.md` §0 carries as a Corrections entry. The mechanism
they govern was already designed (D2's optional hook); what they add is the ownership statement,
the first-customer rule and the paper validation.

`D38`–`D41` are newer still, and they are **§7**. They come from **⚖ R1's answer, 2026-09-10** —
the user kept `-b` and added a requirement while answering, *always salvage* — and from
`evidence/salvage.md`, the dossier that was measured because of the two questions they asked
before ruling. The ruling itself is recorded at ⚖ R1 below, which is now the one answered entry
in that section.

**Citation rule, and it is a ruling this tree already took.** `xschem-claude` is dirty and
moving; every anchor below is a **proc, variable or section name**. A line number appears
only in parentheses, as a hint, and is stale the moment someone edits above it. (Adversary
finding #4 on item 1 of the UX batch: *"Three `:321-335` citations stale the day they
land"* → *"Line ranges replaced by section names — a section survives an edit, a line
range does not."* `ase_l_ux_batch/LEDGER.md`.)

**Measurement markers.** `[R-M<n>]` is a measurement the design-of-record's author took
personally on `/home/analog/dev/ngspice/build-ver_50/src/ngspice`; the decks are listed in
`evidence/design-of-record.md` §0.1 and none of it should be re-derived. `[builds §x]`,
`[crit §x]` name the dossier that owns the evidence. `CODE-HERE` means read in the
xschem-claude working tree.

---

## 1. Architecture

**D1 — One registry, `ase::analysis_types`, in `ase.tcl` (Tk-free), is the single
description of an analysis.** Radio row, form, Arguments column, emit arm, validation,
plot list, results destination, capability gate and refusal set all derive from it.

*Reason.* There are **eight** copies of the answer to "what is a dc analysis" today —
`ase::state_default`'s seed; the `ase::ui::anaargs` variable (hint `:83`); the radio
`foreach` in `ase::ui::choose_analyses`; the `anorder` literal plus the switch inside
`ase::backend::ngspice::render_deck` (hint `:10863`); **the print anchor's own
`foreach type {dc ac tran op}` in the same proc** (hint `:10929`) — a *separate literal*
twelve lines below `anorder`, governed by issue **1243**'s ruling rather than **0964**'s, and
the one loop whose job is to decide which analysis the Value column reports;
`ase::ui::chana_fields`; `ase::ui::chana_show`'s five-name destroy list; and
`ase::plot_sim_type`. Each fails **silently** when it drifts, and one already has: `ac`'s
`dec` key is advertised in `anaargs`, omitted from `chana_fields`, and hardwired in
`render_deck`. Eight literals become eight readers.

⚠ **CORRECTION 2026-09-09** — this said **seven** and omitted the print anchor. A registry
pass that collapses `anorder` and leaves the anchor loop alone has left the drift in place.
Measured and listed in `PLAN.md` §0.3; `README.md` and `CREW_BRIEF.md` carry the same fix.

*Anchor.* `evidence/design-of-record.md` §0 thesis 1, §3.1. Unanimous across design-A/B/C.

**D2 — The registry is per backend, declared through an OPTIONAL hook.**
`ase::register_backend` requires exactly five hooks — its required-hook `foreach h
{render_deck run_cmd log_file result_probe raw_file}` (hint `:665`) — and tolerates
extras; `capabilities` already rides that way. `analysis_types` joins it the same way.

*Reason.* A second simulator must be able to declare a different analysis vocabulary
without touching `ase.tcl`'s core, and the mechanism already exists and is already
exercised. Satisfies spec `ase_l.md` **D3**.

**D3 — The state schema does not change in stages 0–8, with TWO named exceptions.**
`analyses` stays a list of open dicts, `version` stays `1`.

⚠ **CORRECTED 2026-09-13. THIS DECISION SAID "NO NEW TOP-LEVEL KEY" AND NAMED THE CAMPAIGN
KEY AS THE *SINGLE* EXCEPTION. THERE ARE TWO.** Stage 8's **`measurements`** list is the
other, authorised by `PLAN.md` §8a and shipped by issue 1443 — and it was already in the
tree when ⚖ R8 was put to the user. Both use the same mechanism and both are safe for the
same reason: **`ase::omit_if_empty`**, so a bench that has none serialises byte-identically.
Driver-measured: `omit_if_empty` is `{cosim save_op_params sim_entry measurements}` and
**no committed `.state` file has moved**.

⚠ **AND §8a's OWN WORDING FOR IT IS WRONG.** The *Files and procs* table calls it *"the
`measurements` state list (**per-row**, absent by default)"*. It shipped **top-level**, one
list per state — `ase::meas_rows {state}` reads `[ase::state_get $state measurements]` — and
top-level is the **right** shape, because a measurement *references* an analysis (via its
`analysis` and `id` fields) rather than belonging to one. Per-row would duplicate every
measurement that reads a second analysis. **The code is right and the plan's parenthetical
is wrong.**

*Reason.* **104 committed** `.state` files — 105 are on disk and the extra one is untracked
(`LEDGER.md`'s baseline; `PLAN.md` §0.5) — and five byte-identity suite rows
depend on it. Everything new is a **per-row key, absent by default**, which
`ase::state_serialize` round-trips byte-stably. The single proposed exception is the
campaign key, and that exception is ⚖ **R8**, not this decision.

**D4 — Exactly two optional per-row keys: `id` and `x`.** `id` is a stable handle that
makes N rows of one type addressable (⚖ **R6**). `x` is a *labelled* verbatim list of
`.control` lines that **actually emits**, rendered in the Arguments column as
`verbatim: <n> line(s)`.

*Reason.* Two keys is the smallest set that buys "two DC sweeps at once" and "the thing the
GUI cannot yet spell", and `[list]` quoting round-trips both without a schema bump.

**D5 — `ase::state_default` keeps its four rows.** ⚖ **R4** — but it is recorded here
because *today it would change by accident*: the moment the registry exists, seeding it is
one line, and nobody would notice they had moved every committed golden.

### The adapter split — added 2026-09-10, and the reason D1–D5 exist

D1–D5 describe a registry. D34–D37 say **whose** it is. The mechanism was already right —
D2 declares the registry through an optional backend hook, and `PLAN.md` Stage 1's contract
block already refuses a literal fallback "because a literal fallback is the ninth copy" — so
nothing below rips anything out. What was missing was the ownership statement, and without it a
later crew reads "registry" as "a table in `ase.tcl` that currently happens to be filled in from
a hook" and puts the twelfth analysis in the core file, correctly, by the letter of D1.

**D34 — ASE-L owns the analysis-descriptor SCHEMA; a per-simulator ADAPTER owns the CONTENT.**
No per-simulator fact lives in ASE-L's own source: not the analysis list, not a field's units or
default, not an emit syntax, not an option-catalogue row, not a result name. ASE-L owns the key
set, the meaning of each key, the readers, the emitter and the refusals; the adapter supplies
every value, through D2's hook.

*Reason, and it is measured rather than tasteful.* Two ngspice binaries on **this one machine**
disagree about what analyses exist: `/usr/bin/ngspice` (ngspice-45.2) answers `help pss` with
`pss [.pss line args] : Do a periodic state analysis.`, and `build-ver_50/src/ngspice` answers
`Sorry, no help for pss.` — `--enable-pss` was given to one build and not the other. Same
simulator, same box, two analysis sets. So a literal analysis list in `ase.tcl` is already wrong
for **ngspice alone**, before a second simulator is imagined; the choice is not "generalise now
or later" but "be correct or not". It is also the split every later stage already assumes: the
adapter says which rows *could* exist, D7's probe says which of them this binary *has*, and D6's
four-state grid is the join of the two. The user's framing is the same thing from the other end
— the vendor integrates their own tool, so what a vendor hands over must be content, not a patch
to ASE-L.

⚠ *AMENDED 2026-09-10 — the pair changed, the reason did not.* `build-ver_50` was reconfigured
with `--enable-pss --enable-cider` and now answers `help pss`; the no-PSS side is reproduced by the
bare-configure upstream build (`workpad/builds/upstream47`, measured `Sorry, no help for pss.`).
The rebuild is the sharper form of the same reason: one source commit and one version string,
`ngspice-46+` before and after, and the analysis set changed by configure flags alone.

*Anchor.* `APPENDIX_ngspice_analyses.md` §1.7 `[A-M7]`; `LEDGER.md`'s **M2** row, which records
that measurement closing the "does `help <verb>` answer the same on another build" risk;
`evidence/design-of-record.md` §3.1; `PLAN.md` Stage 1 §1a's contract block, key by key.

**D35 — Adapters are FIRST-PARTY: written by Xschem's own agent, living in this tree, versioned
with Xschem — and therefore executable Tcl.** They ride `ase::register_backend`'s existing
optional-hook shape, the same door `capabilities`, `op_param_set` and `op_param_enumerable`
already use. **No manifest format, no sandbox, no inert-data-only restriction is designed in this
batch.**

*Reason.* An inert declarative format defends against an adapter from an author nobody here
trusts, and there is no such author: the ngspice adapter and the ones after it are written in
this tree, reviewed in this tree and shipped with Xschem, which makes an adapter exactly as
trusted as `ase.tcl` itself. Buying that defence now costs the thing descriptors most need — a
`when` predicate, a `build <proc>` emit for the two shapes a token template cannot express
(§1c), a `needs` clause evaluated against `netlist_facts` — and pays for it against a threat that
does not exist. If a third-party adapter is ever wanted, *that* is the moment to ask what it may
execute, and the schema written here is what the question would be asked about.

*Anchor.* `ase::register_backend`'s required-hook `foreach h {render_deck run_cmd log_file
result_probe raw_file}` (CODE-HERE, `src/ase.tcl`, hint `:665`); row **A3** of
`test_ase_simcaps_0948`, which pins the five required hooks and is what proves extras already
ride. D2 is the mechanism; this is its licence.

**D36 — The ngspice adapter is written THROUGH the contract, not around it.** ASE-L core reaches
an ngspice fact only by the hook a future adapter would use; no stage gets a private path from
core to backend "just for ngspice", and a stage that needs one has found a missing schema key,
which is the finding, not the workaround.

*Reason.* A contract with no implementation pulling on it is an abstraction that fits nothing,
and the only way to know a key is expressive enough is to have something demand it. This is also
already how the batch is graded: **D32** makes Stage 1's acceptance byte-identity over today's
four types, which is exactly the statement *"the four analyses ASE-L ships were expressed as
adapter content and nothing moved"*. The failure mode a private path creates is the one D29 is
about — it works, it is silent, and the next simulator's author cannot see what ASE-L did for
ngspice that it will not do for them.

*How it is enforced, and it is a naming rule rather than a habit.* `ase::…` is the schema — the
readers, the one speller per surface, the refusal evaluator, the state keys. `ase::backend::<sim>::…`
is the content — any proc that spells a simulator's syntax, encodes one of its traps, or enumerates
its facts. A file table that names a proc on the wrong side is the **table** that is wrong. The
stages re-checked against this rule when the pivot landed, and changed, are **5, 7, 8, 9 and 14**;
where the answer is genuinely arguable the stage says which side and why (`ase::netlist_facts` and
`ase::si_parse` both stay core, with their reasons given).

*Anchor.* D32's acceptance list; `PLAN.md` Stage 1's file table (`src/ase.tcl` row), Stage 1's
own §1a and the naming-rule paragraph above it; the tree's own comment at
`ase::register_backend ngspice` — *"Kept inside this namespace eval so the only ngspice literals
outside `ase::backend::ngspice` stay the `state_default` schema defaults."*

**D37 — The schema is paper-validated against a SECOND simulator before it is fixed.** Xyce's
adapter descriptor is written **on paper — not implemented** — inside Stage 1, before Stage 1's
byte-identity acceptance (D32) is claimed; what it cannot express is reported, and the schema is
changed then, while changing it is free.

*Reason.* A schema with exactly one implementation is a transcription of that implementation.
Xyce is the useful adversary precisely because it breaks the assumptions ngspice lets us keep:
it has a **native `.STEP`**, so the sweep axis belongs to the simulator rather than to the GUI
(⚖ **R8**, Stage 11); it has **no interactive control language**, so D13's "analyses are
`.control` commands, never dot cards" is an ngspice fact currently wearing a schema's clothes,
and D20's run interface and ⚖ **R1**'s `-p` have no counterpart at all; and it has a **different
output format**, so D16's `setplot previous` walk, the `.plotmap` sidecar and D30's mandatory
results destination have to be nameable without a rawfile underneath them. Each of those is
cheap to fix in a key set and expensive to fix in eight readers. The cost is a day of reading
against a schema every stage after 1 is built on. The adoption goal points the same way: a second
adapter is what "Xschem supports everything" eventually has to mean for a user who is not on
ngspice, and this is the cheapest possible rehearsal of it.

*Anchor.* `PLAN.md` Stage 1's Xyce paper-validation sub-item, which owns the exercise and its
report; `PLAN.md` Stage 15, which is where the same concern becomes executable. ⚖ **R10** asks
how much further than this the formalisation goes, and is **not** answered here.

---

## 2. Capability

**D6 — What is offered is `registry ∩ analyses_available`, with the ungated baseline as the
fallback.** Four visible states, and **never invisible**: `ok` / `caution` / `blocked` /
`absent`, each with its reason and, for `absent`, a **Detect** button.

*Reason.* `ase::sim_capabilities`' standing contract is that a **missing key means "not
measured", never "no"** (recorded decision J). Applied naively that empties the dialog, so
the registry carries `gated 0|1`, sourced from the `#ifdef` set in ngspice's
`src/frontend/commands.c`: `ac dc op tran pz tf disto noise sens` are unconditional in
every ngspice that has ever shipped; only `sp` (RFSPICE) and `pss` (WITH_PSS) are
bracketed. We never claim a measurement — we fall back to a source-verified invariant.
A user who cannot find `pss` in Cadence's ADE-L has no way to learn why; this costs one
column in a table.

**D7 — One new probe leg, inside the capability deck that already runs, with the verdict
read from a file.** `help <verb>` per registry verb, redirected, plus `devhelp`.

*Reason.* **[R-M16]**: one `-b` deck answered for all ten present verbs; `pss` and `hb`
returned `Sorry, no help for …`. Never `help all` — it truncates at the first NULL
`co_func` (`com_help.c:56`, [crit §3.2]). Never the exit code — **[B-M4]**: a parse-only
deck exits 1 while writing its redirects correctly. The parse rule is **keep a stanza only
when its first token equals the verb probed**, which survives the upstream copy-paste bug
`help tf` → `tf [.tran line args] : Do a transient analysis.`

⚠ **AMENDED 2026-09-10, by D34 — the probe belongs to the adapter, not to ASE-L.** `help`,
`devhelp`, `Sorry, no help for …` and the first-token stanza rule are all ngspice spellings, and
this decision reads as if `ase::sim_capabilities_at` in `src/ase.tcl` knows them. What survives
unchanged is the shape ASE-L owns: **one probe run per binary, no new run, the verdict read from
a file rather than an exit code, cached on path + mtime + size (D9), and a missing key meaning
"not measured" rather than "no"**. The deck text, the parse rule and the `analyses_available` /
`devices_available` vocabulary are content the ngspice adapter supplies — a simulator whose
capability answer comes from a version string, a plugin directory listing or nothing at all must
be able to say so without editing this probe. **D12**'s device-family leg rides the same run and
is amended the same way. Nothing measured here changes; only where it is written down.

**D8 — The dialog never starts a probe.** `ase::sim_caps_have_path {backend path {eargs {}}}`
is the free peek; **Detect** is the only door to a cold measurement.

*Reason.* Measured worst case for a program that never answers is **31.2 s**
(issues 0953 / 0958 / 0959). A startup probe in front of the analyses list would make
opening that list take 31 seconds.

**D9 — Two caches, two keys.** Binary → resolved path + mtime + size. Netlist → the exact
netlist text (the key `op_annot` already uses).

*Reason.* They invalidate on different events; one cache keyed on either alone is wrong
half the time.

---

## 3. Netlist admissibility

**D10 — `ase::netlist_facts {netlist_text}` is a second pure-Tcl pass beside
`ase::netlist_map`.** It reuses the continuation folding and the `.subckt` scope stack but
**keeps the `k=v` parameter tokens `netlist_map` deliberately discards**.

*Reason.* Those tokens are the only way to answer "does this source carry an `ac` value",
"a `distof1`", "a `portnum`", "a `trnoise`" — i.e. every precondition NOISE, DISTO and SP
have. Free, cached on the netlist text.

**D11 — Static by default, exact on request.** The static pass **warns**; the exact pass
(**[B-M2]**'s `show v : acmag` parse-only probe, one run per netlist, verdict from a file)
**blocks**.

*Reason.* A false refusal is worse than a missed one, and the stand-down precedent for
`.include`-bearing scopes is already ruled inside `ase::netlist_map_resolve`.

**D12 — The device × analysis matrix is computed for the user's own deck**, from the
binary's families (`devhelp`, same probe run) × the deck's families × the hook matrix. The
distinction that matters: a missing **contribution** hook (`DEVnoise`, `DEVdisto`) is
usually *correct* → `caution`; a missing **matrix stamp** (`DEVacLoad`, `DEVpzLoad`) is
always wrong → `blocked`.

*Reason.* "3 of 14 device families contribute no noise: `e1`, `g2`, `t1`" is a true
sentence a user can act on; "noise analysis failed" is not.

---

## 4. The deck

**D13 — Analyses are `.control` COMMANDS, one at a time — never dot cards.**

*Reason.* Five measured ones: a bare `run` dispatches every card in `analInfo[]` order
regardless of type [crit §5.5]; `.op`/`.tf` cards starve the save scope; two `.sens`
**cards** abort with rc 134 while two `sens` **commands** are fine [crit §D5]; `-b`
double-runs; and the dot-card route is one of the two that reaches **[R-M13]**'s segfault.
Unanimous across all three designs.

**D14 — No conditional logic in the generated deck except the numeric `$sim_status`
guard.**

*Reason.* **[B-M5]**: `.control`'s `if` on strings takes the **false** branch for both `eq`
and `ne`. Every decision belongs to the renderer, in Tcl, where it is testable.

**D15 — Recorded decisions A / D / E / F stand unchanged.** `op` last (and the
`dc ac tran op` reorder when device-OP requests are live); a `$sim_status` guard after
**every** analysis and **above** any write; `remzerovec` before **every** write, because it
is per-plot; the device `@dev` names ride the `op` write **and no other**.

*Reason.* Not style. **[R-M4]**: with `.save all` in the deck,
`write raw all @m1[gm] @m1[id] @m1[vdsat]` produces a 7-variable OP plot carrying those
three device vectors, while `setplot op1` + `write raw all` produces **zero**. The device
names on the write line are the **generator** of those vectors, not a filter over vectors
that already exist.

**D16 — The writer is the `setplot previous` walk, plus a per-write sidecar.**
⚠ This **replaces** design B's writer, which **[R-M2]** shows produces a rawfile ASE-L
itself rejects. Contract:

* a single-plot analysis emits exactly what it emits today — `remzerovec` then
  `write <raw>` — so **single-plot decks stay byte-identical** and the committed goldens do
  not move at Stage 1;
* a multi-plot analysis appends `(nplots-1)` × { `setplot previous` ; `remzerovec` ;
  `write <raw>` };
* from Stage 6 an `echo "PLOT <type> <id> |$curplotname|" >> <cell>_ase.plotmap` line
  precedes each write, giving a **creation-ordered, 1:1** map from the rawfile's
  `Plotname:` records to the analysis row that produced them;
* `<cell>_ase.plotmap` is **deleted before every run**, exactly as the rawfile is, because
  `>>` appends;
* `nplots` is a **predicate**, not a constant, and an over-count **degrades** the result set
  rather than destroying it **[R-M3]**, so post-run reconciliation is a safety net and not
  a blocker.

*Reason, in the negative.* `foreach p $plots / setplot $p / write raw all` writes
`constants` **first** — `Title: Constant values`, `Plotname: constants`,
`No. Variables: 12`, `No. Points: 1`, `Date` identical to the build stamp — all four
markers `ase::raw_content_verdict` (CODE-HERE, `src/ase.tcl`) treats as decisive; it
returns `ok 0` and `ase::attach_dbs` answers *"NOT ATTACHED … the analysis did not run"*.
`destroy const` is refused outright (`Error: can't destroy the constant plot`), there is no
in-deck filter (**[B-M5]**), and the one escape that does work — naming plots literally on
one `write` line — **cannot be generated from inside the deck**, because `$p.all` swallows
the dot (**[R-M19]**: `Error: p.all: no such variable`). The walk is the only shape left.

*Positive evidence.* **[R-M1]**: the walk plus the sidecar produced
`Integrated Noise` / `Noise Spectral Density Curves` / `Operating Point` in `pm.map` and
the same three `Plotname:` records in `pm.raw`, in the same order, 1:1, rc 0.

**D17 — Pre-deck options go into `<rundir>/.spiceinit`, plus `-D` for the bool/string
subset only.**

*Reason.* **[R-M17]**: the file beside the deck is found first from any cwd (ngspice
`main.c` searches netlist dir → `$SPICE_USERINIT_DIR` → cwd → `$HOME`, `break` on first
hit). `-D name` makes a `CP_BOOL`; `-D name=v` makes a `CP_STRING` and **nothing else**, so
it cannot carry a `CP_NUM`, `CP_REAL` or `CP_LIST`. Gated by ⚖ **R2**.

**D18 — Every pre-deck option and the entire campaign mechanism are REFUSED when the
simulator entry carries `-n`.**

*Reason.* **[R-M17]**: the same deck gives `@r1[resistance] = 4700` with the file honoured
and `1e-12` with `-n`, and the only message ngspice prints is about the *resistor* — not a
word about the ignored file. `ase::sim_nospiceinit` already answers the question, so the
refusal costs nothing.

**D19 — ASE-L owns `<rundir>/.spiceinit`, and chains the user's own file by COPYING, never
by `source`.** ⚠ This corrects both design B and design C.

*Reason.* **[R-M7]**: with a user file holding `set frobnicate` / `set myother = 77`,
copying its lines in gives `@r1[resistance] = 4700`, `FROB SET`, `MYOTHER = 77` —
everything survives; `source <userfile>` makes ngspice parse the target as a **netlist**
(`Circuit: set frobnicate`, `Error on line 2 … Unable to find definition of model`) and the
user's variables are **lost**. ASE-L therefore reads `$HOME/.spiceinit` (or
`$SPICE_USERINIT_DIR`'s) itself, copies its lines under a banner, deletes and rewrites the
file per run, refuses when it finds one it did not write, and prints one line in the run log
saying the file exists and what it shadows.
⚠ `ase::rundir` falls back to `set_netlist_dir 0` when the state carries no rundir — one
directory shared by every cell and by xschem's own netlister — so **the campaign and the
whole pre-deck class require an explicit per-session rundir**, and the refusal must name
that. (This is the same resolution that cost the UX batch a user's rawfile; see that
batch's LEDGER incident.)

**D20 — One internal run interface — start / progress event / abort / results-located —
with `-b` as its first implementation.** ⚖ **R1** decides when the second implementation
lands. `libngspice` is refused outright (see PLAN.md's refusals).

*Reason.* **[R-M8]** removes the argument for hurrying: `tran 10n 20m` under plain `-b`
printed **8** ` Reference value :  1.80112e-02` records on stdout, `\r`-terminated. The GUI
wrote `tstop`, so `refvalue/tstop` is a percentage it can compute for tran, dc, ac, noise,
disto and sp alike [builds §3.2]. Design B's transport table says "progress: none" for `-b`;
that is **wrong**.

⚠ **AMENDED 2026-09-10, by D38 — `abort` is a SALVAGING abort.** This interface was written when
stopping a `-b` run meant losing it, and the word *abort* carried that assumption. It no longer
does: a stopped run keeps what it computed (**D38**), so the `abort` element owes a salvaged
result and the `results-located` element owes an honest statement of how far that result got
(**D39**, third sentence). The `-b` implementation reaches it through **D40**'s checkpoint loop;
a later `-p` implementation reaches it without one. ⚖ **R1** has since answered when that second
implementation lands — **after Stage 10** — and answered Option A, so the first implementation is
the one that has to carry D38. Nothing about **[R-M8]**'s progress records changes.

---

## 5. Honesty

**D21 — Any value the form collects and cannot emit is REFUSED at OK, never stored.** The
only storable-but-unemitted thing is `x` (D4), which *does* emit and says so.

*Reason.* This is the decision that deletes the F3 correctness defect:
`ase::ui::chana_options` collects name/value pairs, round-trips them, renders them in the
Arguments column — and never emits them. The acceptance criterion for the whole batch is
one sentence: **nothing the window shows may fail to reach the deck, and nothing the deck
contains may be unshowable in the window.**

**D22 — Refusals appear where the typing is.** Generalise `ase::ui::rsel_status` into
`ase::ui::dialog_status {w key msg}` at a reserved grid row; keep the `ase::echo` line for
the action log and for headless assertions.

*Reason.* Today OK "does nothing" and the sentence lands in another window.

**D23 — Every option descriptor carries its type and its door, and ONE emitter is the only
thing allowed to spell an option line.** ⚠ **The type is not one field.** The `cp_getvar`
half needs `CP_BOOL|CP_NUM|CP_REAL|CP_STRING|CP_LIST`; the OPTtbl half needs its own split,
because ngspice's `cktsopt.c` mixes `IF_FLAG` (`keepopinfo`, `klu`, `oldlimit`, `noopiter`),
`IF_INTEGER` (`itl4`, `srcsteps`, `gminsteps`, `maxord`) and `IF_REAL` (`trtol`, `temp`) in
one table.

*Reason.* Design C's single `class opt` arm emits `.options gminsteps` for a user who typed
`0` — a window reporting a setting that is not in force, inside the very proc written to
prevent that. ngspice accepts unknown option names in silence, drops out-of-range values in
silence, and turns a `CP_BOOL` written `=1` **off** in silence (F15).

**D24 — An option that is INERT in this build is never offered as a live field**, and its
catalogue row keeps the reason, so the next reader does not re-add it from the manual.
Three shapes: not offered at all / offered with a clamp and the reason / kept as a
tombstone.

*Reason.* `nosavecurrents` is documented by the manual §13.7 and the string appears
**nowhere** in this tree. A knob that does nothing is worse than a missing knob, because it
is indistinguishable from a working one.

**D25 — The GUI is the sole authoritative store of analysis settings.** The simulator is
asked only what it *can* do, never what it *was told*.

*Reason.* OP has zero parameters and nothing about a DC or OP job can be read back (F12).
The one exception runs in the opposite direction and is D26.

**D26 — There is a post-run verification channel, and it is a requested-vs-effective diff.**
After the run, a bare `option` and a bare `set` are read back and compared with what the GUI
asked for.

*Reason.* **[R-M9]**: after `option reltol=0.05 itl4=7 method=gear`, a bare `option` printed
`reltol (current) = 0.05`, `itl4 (transient iterations) = 7`, `Integration Method = GEAR`
plus ten more; a bare `set` listed every variable in force — **including `bogusopt 3`,
silently created by `option bogusopt=3`**. Neither reveals a `CP_` class, so the type table
still ships (D33), but together they catch F15's silent drops and prove a pre-deck delivery
landed. No design used this channel.

**D27 — Phase is rendered in degrees, always, and the deck says so.**

*Reason.* **[R-M10]**: `vp(mid)` on an AC run = `-4.96729e-04`; after `set units=degrees`,
`-2.84605e-02` — a factor of 57.2958. `units` is a `CP_STRING` variable. All three designs
route a phase margin to the user's Value column and **none** of them says this, so a
generated PM would be wrong by a factor of 57 under a correct heading. Every `meas`, every
derived phase margin and every phase trace is preceded by `set units=degrees`, and the
Y-axis label says `deg`.

**D28 — Event-driven results ride a VCD, not the rawfile.**

*Reason.* **[R-M6]**, on an `adc_bridge → d_inverter → dac_bridge` deck: `edisplay` prints a
machine-readable inventory (`din : d , 7` / `dout : d , 7`) with no netlist parsing;
`eprvcd din dout > mx.vcd` writes a valid VCD; and `write mx.raw all` contains
`time i(adac) v(aout) v(in) i(vin)` and **not** `din`/`dout`, silently. ASE-L already has a
complete VCD pipeline (`ase::cosim_map`, `ase::last_vcdfiles`,
`ase::attach_dbs {rawfile sim_type {vcdfiles {}}}` — CODE-HERE), so the digital half of a
mixed-signal run is **one `eprvcd` line** away from the viewer. No design proposed it.

---

## 6. The five decisions that make the design of record's twenty-eight enforceable

**The "twenty-eight" are `evidence/design-of-record.md`'s DR1–DR28**, which are D1–D28 here —
not a count of this file, which now runs to **D41**. D29–D33 are the five below; D34–D37 are
the adapter pivot's and D38–D41 are §7's.

These are not in §2 of the design of record. They come out of the registry's own shape
(§3.1) and the stage table (§13), and each one converts a rule somebody would otherwise
have to *remember* into a structure that *breaks* when it is violated.

**D29 — The emit loop iterates the enabled rows of the registry, never a literal order.**
`ase::backend::ngspice::render_deck`'s `anorder {op dc ac tran}` literal goes away; the
`op`-last rule (D15) survives as a **named** `emitorder` on the registry row, not as a
position in a list.

*Reason, and this is Stage 0's whole content.* Today a state row whose `type` is not one of
the four literals renders a deck with **no analysis, rc 0, and says nothing**. That silent
drop is the failure mode every later stage would inherit. A row whose type is not in the
registry must raise a **named error**, and the same check joins `ase::preflight_gate`.
`ase::plot_sim_type` returns `{}` honestly rather than guessing.

**D30 — Every registered analysis MUST name a results destination; a registry entry without
one is a load-time error.**

*Reason.* This is how the "scalars go in the Value column, waveforms do not" rule stops
being a thing a future crew has to know. It is enforced **structurally** — the registry
will not accept the row — instead of by review. It is also what forces NOISE, TF and SENS
to have somewhere to put their answer at all, which is why ⚖ **R3** exists.

**D31 — One ordered `fields` list per analysis serves three roles: form order,
Arguments-column order, and emit slot order.**

*Reason.* Two lists is exactly how `ac`'s `dec` key drifted — advertised in `anaargs`,
omitted from `ase::ui::chana_fields`, hardwired in `render_deck`. One list cannot
disagree with itself.

**D32 — Stage 1's acceptance is BYTE-IDENTITY, and if byte-identity cannot be met the
descriptor's shape is wrong and the plan stops there.** The list, identical to `PLAN.md`
Stage 1's and verified row for row: deck golden **D1** and **D2** / **R1** / **R4** of
`test_ase_core`, **V4** of `test_ase_view`, **R2** of `test_ase_persist`, **F3** of
`test_ase_final`, **G3** of `test_ase_final_gf180`, **W1p** of `test_ase_window`, the
**104 committed** `.state` round-trips, and the print anchor. All unmoved after the registry
lands with exactly today's four types.

⚠ **CORRECTION 2026-09-09** — this list used to name "row E12" without a suite, and `E12`
exists in two suites with unrelated meanings, **neither of them a byte-identity row**:
`test_ase_simreg_0931.tcl:1009` ("a simulator list with a mismatched brace … costs the user a
sentence, not the whole editor") and `test_ase_optier_0963.tcl:718` ("with the tick off and
nothing captured there is nothing to move"). It is dropped rather than guessed at.

*Reason.* The registry is a refactor pretending to be a feature. If it cannot reproduce
today's four emitted lines byte-for-byte, the `emit` template language is not expressive
enough, and discovering that at Stage 6 — where every golden moves anyway — would hide it.
⚠ The one knowingly accepted move is **six** widget-path lines in `test_ase_dialogs.tcl` —
`:625`, `:626`, `:629`, `:655`, `:656`, `:657`, all in G2/G2b — because the `.form` child
frame changes those paths. ⚠ **CORRECTION 2026-09-09**: correction **C18** said *five*.
`PLAN.md` §0.2 re-measured and the grep is quoted there. The sixth is `:629`,
`send_return $top.chana.step {![winfo exists $top.chana]}` — and a `send_return` to a path
that no longer exists does not fail an assertion, it **fails to submit the form**, which is
the shape of the 300-second hang the UX batch already hit once. Moving five and leaving that
one is the expensive mistake.

**D33 — The GUI ships the per-variable `CP_` type table as data, because there is no
runtime way to discover a variable's class.** **220 rows, the measured floor**, over **both**
option catalogues — 57 settable `OPTtbl` keywords (of 98 rows: 29 are `IF_ASK` `rusage`
statistics, 2 carry both flags, 14 carry neither) plus the 163 `cp_getvar` variables, the two
sets provably **disjoint** — each carrying `cptype`, `door`, `phase`, `scope` and `inert`.

⚠ **CORRECTION 2026-09-09** — this said "~250 catalogue rows … OPTtbl's ~86 keywords".
Counted over `cktsopt.c:264-386` in `PLAN.md` §0.4 and `APPENDIX_ngspice_analyses.md` §3.1:
the table is **98** rows and **57** are settable. "~86" was `evidence/hidden-vars.md` §2's
count of a **narrower** set (57 `IF_SET` + 27 `IF_ASK`-only + `itl3`/`itl5`), which is
arithmetically right about a different question. Quote **98** for the table, **57** for the
settable floor, **220** for the catalogue.

*Reason.* D26's verification channel reports values and never classes: a bare `set` will
happily list `bogusopt 3`, a variable ngspice invented on the spot. Without the shipped
table the GUI is guessing at the exact moment it claims to be validating. The table is
generated once from `evidence/options.md` and `evidence/hidden-vars.md` and hand-maintained
thereafter; ⚖ **R9** covers the labels it mints, not the data.

⚠ **AMENDED 2026-09-10, by D34 — "the GUI ships the table" is superseded; the ngspice ADAPTER
ships it.** 220 rows of `CP_BOOL`/`CP_NUM`/`CP_REAL`/`CP_STRING`/`CP_LIST`, `OPTtbl`'s
`IF_FLAG`/`IF_INTEGER`/`IF_REAL` split, `itl4`, `gminsteps`, `nosavecurrents`'s tombstone — every
one of those is an ngspice fact and by D34 none of them may sit in ASE-L's own source. What ASE-L
owns is the **shape** of a catalogue row (`cptype`, `door`, `phase`, `scope`, `inert`), the one
emitter allowed to spell an option line (**D23**), and the rule that an inert option is never
offered as a live field (**D24**). A simulator with no `CP_` classes at all supplies rows whose
`cptype` vocabulary is its own; the emitter does not care. **Nothing about the count, the
provenance or the hand-maintenance changes** — quote 98, 57 and 220 exactly as above. Only the
namespace it lands in does, and `PLAN.md` **Stage 7a** now settles it: the catalogue is declared in
`ase::backend::ngspice` and `ase::opt_line` reaches it through `ase::sim_option_entry`, never through
a `$::ase::sim_options` variable in core. ⚠ An earlier version of this line said *"the file it lands
in"*; the file is `ase.tcl` either way, because `ase::backend::ngspice` is a namespace inside it —
**the namespace is what the rule is about**, and saying "file" was what let Stage 7 read as a
contradiction of this amendment for a day.

---

## 7. Salvage — added 2026-09-10, out of ⚖ R1's answer

⚖ **R1** was answered Option A — `-b` stays, `-p` is deferred — and the answer carried a
requirement that neither option contained: *always salvage*, with the user warned wherever a
Stop would still throw work away. D38–D41 are that requirement written down.

They exist in this form because the dossier measured something R1's write-up had assumed away:
**`ngspice -b` can keep a stopped run's work.** Everything cited below is MEASURED in
`evidence/salvage.md` on 2026-09-10 against `/home/analog/dev/ngspice/build-ver_50/src/ngspice`,
and the dossier supersedes the quick pass that preceded it — five of that pass's load-bearing
statements were wrong, and its own checkpoint deck silently truncates every run it is given.

**D38 — ALWAYS SALVAGE: a run that is stopped keeps what it computed.** This is a property of
the **run pipeline** — D20's interface, its `abort` element and its `results-located` element —
and **not** a property of a transport. It holds under `-b` and it holds under `-p`; what changes
between them is the mechanism (D40) and how much of the last interval is lost, never whether the
requirement applies.

*Reason.* It is the user's, ruled 2026-09-10, and their reason is the one recorded at ⚖ R1:
*"What is the benefit of losing partial results on Stop? Why would one ever want to do that?"*
There is no benefit. `evidence/salvage.md` §4.1 (SOURCE, `main.c`) is the whole story: the signal
block sits inside `if (!ft_batchmode)`, so batch installs no handler, every signal takes its
default disposition and the process dies where it stands. Batch was written for scripted use
where nobody presses Stop. Nothing is being traded away for the loss, which is why the
requirement can be stated flatly rather than balanced against something.

The requirement is also **affordable where it is written**, which is what keeps it out of the
transport question: §3.8's recipe is extra lines inside `ase::backend::ngspice::render_deck`'s
analysis loop plus one checkpoint path beside the `raw_file` hook's answer. It touches no argv,
so none of the six `test_ase_simreg_0931` rows that pin `run_cmd` word-for-word — **A2 / B5 / B6
/ B11 / B12 / D4**, with **L11** on the exe — move.

*Anchor.* **D20** and its 2026-09-10 amendment; ⚖ **R1**'s answer below; `evidence/salvage.md`
§0, §3.8 and §6.

**D39 — Until salvage is implemented, the GUI SAYS SO before the work can be lost — and the
warning is the interim, never the destination.** Shipping the sentence does not discharge D38.

*Reason.* §5's rule has two halves and this is the second one. D21's acceptance sentence covers
what the window shows about the *deck*; a run panel that offers **Stop** without saying the run
dies with it is the same defect pointed at the *run* — the window showing something untrue. The
warning is free, which is the point: it is one sentence on the run panel, correct today, and it
ships in whichever stage ships that panel, with no checkpoint code underneath it.

It is **three** sentences, not one, and `evidence/salvage.md` §5 shows they are not
interchangeable:

1. **Before an uncheckpointed run** — *"Stopping this run discards it. ngspice in batch mode
   writes nothing on a stop."* True today, measured (§4.1). This is the free one.
2. **Before a checkpointed run** — how much a Stop costs, `100/(N+1)` per cent, **20 % at the
   default N = 4**, *and* what the checkpoints themselves cost in I/O (§3.7). A user choosing an
   interval is trading exactly one of those against the other, so the panel says both numbers or
   neither.
3. **On the results after a Stop** — that this rawfile is salvaged and not complete, and **how
   far it got**: `maximum(time)` (or `frequency`, or the sweep variable) of the salvaged plot
   against what was asked for. It must come from the deck's completion echo, **not** from rc and
   **not** from `$sim_status`, both of which say the run succeeded (§3.6, D40).

Each of the three is a new user-facing sentence and therefore ⚖ **R9**'s to ratify, filed with
`owed.sh add rule <id>` the moment it is minted and paid in its stage's batch. Sentence 3 also
carries D41's fifth refusal for `noise` and `disto`.

*Anchor.* **D21**, **D22** (the sentence belongs where the gesture is — the run panel, with the
`ase::echo` line for the log and for headless assertions); `evidence/salvage.md` §5.

**D40 — Checkpointing is the batch-mode salvage mechanism, and its primitive is
`stop after <points>`.** The deck stops itself on a point count, writes everything so far, and
resumes; a Stop then costs at most one interval. The recipe is `evidence/salvage.md` §3.8,
measured end to end against ASE-L's own deck shape and against `kill -9`. Nine rules come with
it, each of them measured, and each of them the difference between a checkpoint loop that works
and one that fails at rc 0:

* **`stop after N`, never `stop when time > x`** — D41.1. `stop after`'s test is an equality on
  the written point count, so it fires once per analysis; `stop when` is not disarmed when it
  fires and will re-fire on the next point.
* **The interval is counted in POINTS, not in simulated time.** For `tran tstep tstop` the
  measured count is `tstop/tstep + 8`; where the count is not predictable the loop reads
  `length(time)` at the first checkpoint and re-arms from the measured value.
* **The interval rule: `N + 1 = sqrt(T × B / S)`** — T the expected runtime in seconds, S the
  expected rawfile size, B ≈ 400–500 MB/s. Measured cost is linear in bytes, and it is
  **page-cache** throughput (there is no `fsync` anywhere in `rawfile.c` or `outitf.c`).
  ⚠ **B is a planning constant, not a bound**: three sittings on one machine put it at
  410–540 MB/s, and the reference deck's overhead at N = 4 moved between **+8 % and +21 %**
  (N = 20: +60 to +75 %; N = 100: +288 to +380 %). The model reproduces; the constants do not, so
  compute from `N/2 × S / B` with a B measured where the run will happen rather than quoting a
  percentage. **Default N = 4, clamped `[2, 50]`,** whenever T and S cannot be estimated: a
  20 % worst-case loss, which is the number D39's second sentence quotes. The same formula gives
  a ten-minute, 200 MB job ~34 checkpoints at ~1.4 %.
* **The checkpoint goes to its own path, never into the results file** — D41.2 — with `unset
  appendwrite` around the write and `set appendwrite` restored after it.
* **`write <path>.tmp` then `shell mv -f`.** A kill during a plain checkpoint write tears the
  file, and a torn file loads *nothing* (`raw_write` writes the true count up front and then
  streams, so the header over-claims); one of five kills caught the `fopen(…, "wb")` window and
  left **0 bytes** where the previous good checkpoint had been. ⚠ One hit in five is **not a
  rate** — a later sitting got 0 in 5 — but it is what makes tmp+rename mandatory rather than
  tidy, because that failure destroys the **fallback**, not the new file. tmp+rename measured
  kill-safe 6/6, ≈ 4 ms per checkpoint (two A/B sittings: 3.7 and 3.9 ms; an earlier pass
  recorded ≈ 12 ms and was three times too large). ngspice has **no rename, move or copy primitive** — `spcp_coms[]`
  offers `write`, `fopen`/`fread`/`fclose`, `cd`, `getcwd` and `shell` — so the atomicity comes
  from `shell mv` in the deck or from the GUI renaming a path it owns. It cannot come from
  ngspice.
* **`delete all` before the next analysis in the same block.** ASE-L renders one `.control` block
  with op/dc/ac/tran in it, and a stop armed for one is armed for all: `stop after 200000` armed
  once truncated the `tran` **and** the following `ac`, rc 0; a `stop when time` left armed during
  an `ac` wrote 600,045 `Error: time: no such node` lines into a 15.6 MB log.
* **Counters are created before the first analysis**, so they land in the `const` plot. A `let`
  counter created after an analysis lands in *that* analysis's plot and is invisible to the next
  one — the loop then fails with `Error: &cknext: no such variable`, stops checkpointing, and
  carries on at rc 0. ⚠ **And it is worse than invisible: it is a vector of that plot, so every
  `write` from then on emits it.** Measured with `let ckdone = 0` after the `tran`:
  `No. Variables: 5` and a `ckdone notype dims=1` column beside time and the circuit quantities,
  in the checkpoint **and** in `<cell>_ase.raw`, which ASE-L reads by enumerating a plot's
  vectors. This is `PLAN.md` correction **C35**; the recipe printed in `evidence/salvage.md`
  §3.8 carried the defect until 2026-09-10, and with it the byte-identity claim above was false
  for the deck as printed.
* **A threshold reaches `stop after` through a `set` variable, never `$&vec`.** `com_stop()`
  parses the argument digit by digit and `$&` formats 1,500,000 as `1.5E+06`: the command prints
  *"Syntax error parsing breakpoint specification."*, arms nothing, and the run completes
  unchecked at rc 0. This bites only above 1,000,000 points — exactly the regime checkpointing
  exists for, so a loop tested on short runs passes and stops working when it matters. The `set`
  route rounds to 6 significant figures; a checkpoint threshold is approximate and that is fine.
* **Completeness is a deck-emitted echo.** `dosim()` — which `ft_dorun()` calls — maps an
  interrupted run to `err = 0`, so
  `$sim_status` is **0** after a stop, ASE-L's existing guard prints nothing, the write runs and
  rc is **0**. Neither rc nor the guard can tell a completed run from a checkpointed one. The
  deck echoes a completion marker after the last analysis and the GUI reads its **absence**.
  `remzerovec` and `.options savecurrents` are undisturbed by a stop — measured, nothing removed.

*Reason.* This is the route that keeps ASE-L's deck shape. The alternative — `ngspice -b -r`,
which really is written incrementally — is refused by D41.3, and its header repair is a
two-step recipe that the quick pass had as one. The abort itself stays cheap either way: batch
dies in **a few milliseconds at worst** for SIGTERM and SIGKILL alike, because nothing handles
either — the figure tracks the run's resident memory, not the signal (`PLAN.md` **C35**). ASE-L sends
**SIGTERM first, SIGKILL after ~200 ms** — not because ngspice does anything with SIGTERM, but
because a `shell` child may be mid-`mv` and because `rename(2)` is atomic in the kernel, so a
kill landing anywhere in that window leaves either the old checkpoint or the new one.

*Anchor.* `evidence/salvage.md` §3.2, §3.3, §3.5–§3.9, §4.2–§4.4; `ase::backend::ngspice::render_deck`'s
analysis loop and the `raw_file` hook (CODE-HERE).

**D41 — The refusals salvage brings with it.** Five, and each one is refused because the
alternative was measured and found destructive, silently wrong, or unproven.

1. **`stop when time > x` is refused as a checkpoint primitive — it changes the answer.**
   `com_stop()` hands a time condition to `CKTsetBreak()`, which forces a timepoint. One
   time-checkpoint costs 3 extra rows and a different timestep grid from that point on; three
   cost 9. The physics survives (max |Δv(out)| = 4.7e-13 at shared timepoints) but the point
   count and the bytes do not, and anything downstream that compares two runs — a golden, a
   regression, two campaign shards — sees a difference the user did not ask for. With `stop
   after`, at 3 checkpoints and at 100, the final body's **sha256 is identical** to the unchecked
   run's. A checkpoint that perturbs the result is not a checkpoint.
2. **A checkpoint is never written into the results file.** `render_deck` emits `set appendwrite`
   (issue **0929**: one results file, one plot per analysis), and under `appendwrite` a `write`
   to an existing path **appends a plot** instead of replacing it. Measured: three checkpoints
   plus the final write to one path produced **four** stacked plots, 64,001,536 bytes where the
   single plot is 25,600,541 — quadratic in the checkpoint count — and ASE-L reads results **by
   plot name**, so `tran1` stops being the run's answer. Accumulate-and-overwrite is otherwise
   exactly as good as it sounds: checkpoint *k* is a byte-exact prefix of the final file.
3. **`-r` is never pointed at a path ASE-L cares about while the deck carries a `.control`
   block.** It does not merely go unused — it **deletes the path**. `main.c`'s batch arm calls
   `ft_dorun(ft_rawfile)` unconditionally; **`dosim()`** beneath that four-line wrapper opens the
   path `"wb"`, and its close arm does `if (ftell(rawfileFp) == 0) { fclose; unlink(...); }`.
   (Grep `ft_dorun` and you find a wrapper with no `fopen` and no `unlink` — the behaviour is one
   call down.) Measured: a good rawfile written by
   the block's own `write` to that path was **gone** at exit, rc 0. (Separately, and not ASE-L's
   problem until it is: `-b -r` corrupts its own output above 99,999,999 points, because
   `fileInit()` reserves 8 characters for the count and `fileEnd()` writes `%d`. Upstream defect,
   measured end to end, not yet filed in the ngspice tree's `doc/codex/issues/`.)
4. **No analysis advertises salvage without a measured `stop`/`resume` row.** Measured working:
   `tran`, `dc`, `ac`. Measured as not applicable: `op` — one point, nothing to salvage.
   **Unmeasured and therefore refused until someone measures them: `pss`, `sp`, `pz`, `sens`,
   `tf`** — `evidence/builds.md` item 3 already records that `sens` does not honour `bg_halt` and
   that `pz` likely cannot be interrupted, so these are where salvage may simply not exist. The
   refusal is on the *offer*: the run panel says salvage is unavailable for that analysis and
   why — naming the reason rather than hiding the row, which is D6's habit — instead of offering
   a Stop that quietly behaves like the old one.
5. **A salvaged `noise` or `disto` is never presented as merely short.** Both produce **two**
   plots. Measured: an unchecked `noise` leaves `noise1 noise2`; stopped mid-run it leaves
   `noise1` **only**, and `resume` is what produces `noise2`. A checkpoint taken during one is
   not a truncated plot, it is an **incomplete plot set** with the integrated-noise plot missing
   entirely. This is the second way to break the invariant `evidence/ase-deck.md` §7.4 already
   flagged — *"one analysis produces one plot … is false for `noise` and `disto`"* — and D39's
   third sentence has to say *may be missing a plot*, not *is shorter than asked for*.

⚠ **One thing not refused because it was not measured: `shell` on Windows.** The rename in D40
goes through `com_shell`, which on a Windows build runs `cmd`, where `mv -f` is not a builtin. If
ASE-L is ever expected to run there, the rename moves into the GUI. Until someone measures it,
the Windows path claims nothing.

---

## 8. Variants — added 2026-09-10, out of *"most users won't have our ngspice"*

The user's question: *"Given that most users who download our Xschem won't have our ngspice, what
hooks should be put into place so that Xschem ALSO works with the apt installed ngspice and the
basic officially downloaded and built (version 47 as of this writing) repo? … there probably needs
to be a stock 'basic' ASE-L which can fire up the needed hooks after detecting the version of
ngspice the user has said to use."*

Three binaries were measured (`APPENDIX` §1.8): **apt 45.2** (what the current Ubuntu LTS ships),
**stock upstream 47** (built for this pass) and **the fork**. Two of the question's own premises
did not survive: the fork implements **no blanket OP device-info save**, and **detecting the
version cannot work**. D42–D52 are what replaces it.

**D42 — There is no variant record. The variant record is the capability dict, extended.**
`ase::sim_capabilities` already has a lazy probe, a cache keyed on resolved path + argv, an
mtime+size stamp, one shared budget, a private workdir, a *"never remember an answer nobody worked
out"* rule and a three-state discipline. Every one of those was paid for with an issue number
(0929, 0935, 0948, 0949, 0950, 0951, 0952, 0953, 0960, 1371). A parallel `ase::variant_info` would
re-earn all ten. **Everything the variant work adds is keys in that dict**, in four bands:
**identity** (display and log only), **capability** (gate UP: 1 = proven present), **defect**
(gate MITIGATIONS: 1 = the defect is ABSENT, i.e. sound — the same polarity as
`altshow_op_dump`, so no reader has to remember an inversion), and **provenance of absence**
(`unmeasured`, and the new per-key `unmeasured_keys`).

**D43 — There is no version-keyed table, and that is a finding rather than an omission.** Every
hazard in the batch is either **probeable** (then it is a probe, keyed on the probe's answer) or
**universal** (then there is no key and the mitigation is unconditional). `APPENDIX` §7.5 is the
enumeration, and it has **zero version-keyed rows**. The rule for a future crew:

> **Probe what a run can answer. Table only what a run must not be allowed to ask. If neither, the
> fact does not exist and the mitigation is unconditional.**

A table with one row reading *"all known versions"* is machinery that earns nothing.

**D44 — `version_line` may be DISPLAYED and LOGGED. It may never be COMPARED.** Measured: stock
upstream 47 and the fork **both** answer `ngspice-46+`, carry a byte-identical 134-row command and
help table, and answer `devhelp` identically. So any `>=`, `<`, `package vcompare` or
`string match "4[5-9]*"` against a version string is **wrong today**, before ngspice 48 exists.
This is enforceable rather than conventional: **a conformance row (Stage 15/16) greps for any
ordering operator taking `version_line` as an operand and reds if one appears.**

**D45 — ONE ASE-L with N feature gates. Not a "basic" mode and an "enhanced" mode.** Four measured
reasons, and the first is decisive: **the subsets overlap without nesting.** apt 45.2 has `pss` and
the five CIDER families that neither 46+ build has; the 46+ builds have `pyplot`, `astate` and
`ota` that 45.2 lacks; the fork has casemode and nobody else does. **Neither binary is the basic
one**, so whichever box a two-mode UI puts 45.2 in is a false statement about the other axis.
Second, there is no basic deck to switch *to*: under `fold`, apt 45.2 and the fork produce
byte-identical raw files for every deck shape ASE-L emits today. Third, the tree already has N
gates and zero modes and they work — `ase::cap_altshow_verdict` withheld tier `d` from apt 45.2
with **no version number anywhere**, and was right. Fourth, modes rot on a schedule nobody
controls: *"enhanced = has the fast OP dump"* was true of the fork and false of stock until
`10276f993` landed in `pre-master-47`, at which point it became true of stock too — **the gate did
not need editing; a mode would have.**

**D46 — V6′: gate capabilities UP; apply every FREE mitigation DOWN, unconditionally; a mitigation
that is not free is gated on a measurement.** The driver's principle was *"gate up, mitigate
down"*, and it survives with one amendment, because two of the three mitigation classes cost
something. The classification test is **two questions, not one** (an earlier form said *"costs the
user nothing"*, and two of its own examples failed it):

| class | test | policy |
|---|---|---|
| **M-artifact** | *does it change bytes in the user's results file?* | gated on a measurement — **except** where it is a correctness precondition (below) |
| **M-refusal** | *does it remove something the user asked for?* | **warn always; refuse only when measured 0**; never refuse on an unmeasured build |
| **M-free** | neither | **unconditional.** No probe, no gate, no version |

⚠ **A correctness precondition is applied unconditionally even though it is M-artifact**, and it
is justified on that ground rather than on freeness: *"never emit a narrowed `save` in the same run
as an analysis whose result vectors are not netlist names"* changes the results file, but without
it the analysis **does not run at all** (`APPENDIX` §7.5.2 — measured for `disto`, `noise`, `tf`
and dc `sens` on all three binaries). Say which ground each unconditional M-artifact stands on.

**D47 — The unknown binary gets capabilities gated up, M-free applied, M-artifact NOT applied, and
M-refusal WARNED rather than refused.** The instinct *"assume every bug is present, because
assuming it is fixed produces a crash"* is right for capabilities and for M-free, and wrong for the
other two. For **M-artifact**, assume-present is not free: it changes the results file of a user
whose binary nobody measured, to work around a defect there is no evidence they have. For
**M-refusal**, assume-present means refusing a line a user deliberately wrote, on a binary newer
than ASE-L, with no override — *the* failure mode that makes a user conclude the GUI is in their
way, landing specifically on the users who upgraded. **There is a third option the instinct
skipped and it dominates both: warn and proceed.** Unmeasured → the sentence (free) and the line
kept (free); measured 0 → the refusal, strictly better than a crash that eats the log; measured
1 → silence.

**D48 — Three predicates, and each mitigation and capability must use the right one.** The idiom
`[dict exists $c k] && [dict get $c k] == 1` is written out at ~12 capability sites today
(`ase::op_save_tier`'s five guards, `ase::cap_report`'s three, the casemode layer's) and every copy
is a chance to fuse "absent" with "0". The schema therefore gains **exactly three procs** and a
rule about which is which:

* `ase::caps_get {caps key}` → `{measured 0}` / `{measured 0 why <token>}` / `{measured 1 value <v>}`.
  **The three states as data, in one place.** `value` is **absent** rather than empty when nothing
  was measured, so a `dict get` on it **raises** — a defect that shows up in a test row instead of
  a fabricated 0 that shows up in a user's Outputs pane six months later.
* `ase::caps_is {caps key want}` — the **gate-UP** predicate. Unmeasured answers 0, which is right
  for a **capability** and wrong for a mitigation.
* `ase::caps_measured_as {caps key want}` — the **mitigation** predicate. True only when
  `measured 1` **and** the value matches; unmeasured is **false**, so the mitigation does not fire.

**The rule: capabilities use `caps_is`; mitigations use `caps_measured_as`; nobody calls
`caps_get` outside those two.** ⚠ Without the third proc, the natural translation of a mitigation
gate is `![ase::caps_is $c one_vector_write 1]`, which is **true for unmeasured** and therefore
inverts D47 for every binary nobody measured. A schema that needs a comment to stop the natural
spelling from inverting a policy will lose, so this is a proc and a conformance row
(`caps_is` appearing under a `!` is a red), not a convention.

**D49 — A probe that needs its OWN PROCESS to buy silence is not worth a leg; a probe that is one
more LINE in a deck already running is free.** This replaces the blunter *"a probe that only buys
silence is not worth a leg"*, which was measured wrong in one direction and right in the other.
Measured: the `gnd`-rewrite verdict and the capitalised-keyword-argument verdict are each **one
line** inside leg D's already-running `.control` block, costing zero extra processes
(`APPENDIX` §7.5.1) — so they are taken. A leg that needs its own run to suppress one warning line
is not.

**D50 — ASE-L never runs a probe that crashes the user's simulator.** The `cp_remvar` /
`define` / `load` aborts are all cleanly probeable — a marker file written after the aborting
statement is a file-existence verdict, `absent` on apt 45.2 and stock 47, present on the fork. The
probe is refused anyway, for three reasons, in order of weight:

1. **It files a crash report against the user's own `/usr/bin/ngspice`.** Measured on this machine
   (Ubuntu 26.04.1 LTS): `dpkg -l apport` → `ii 2.34.1-0ubuntu0.1`, `/etc/default/apport` →
   `enabled=1`, `systemctl is-enabled apport.service` → `enabled`, and the
   `apport-coredump-hook@.service` unit is present. It is silent *here* only because WSL leaves
   `core_pattern` at `core` and `systemd-coredump` is not installed. On a stock Ubuntu desktop —
   the platform this whole amendment exists for — the first thing a user sees after registering
   their binary is *"ngspice closed unexpectedly."*
2. **It buys almost nothing.** Under D47 the linter warns on an unmeasured build and warns on a
   measured-1 build whose key is absent; the key's only purchase is upgrading *warn* to *refuse* on
   two of three binaries, and D47 argues at length that warn-and-proceed dominates refusal.
3. **Its verdict is single-sided and its guard is structurally unavailable on some boxes.**
   "Marker absent" is also what a failed start, a bad `.spiceinit`, a parse failure, an OOM kill
   and a timeout look like. `ase::cap_run` reports a `cut` flag — but it sets `cut` only
   `if {[llength $cap]}`, and `ase::cap_timeout_cmd` answers `{}` when `auto_execok timeout` finds
   nothing. **On a box with no `timeout(1)` the guard never fires**, and a healthy simulator would
   be published as defective.

⚠ **The discipline this leaves behind, for any future leg that CAN abort**, because the rule is
worth more than the leg: (a) **both outcomes must be positive artifacts** — write a marker
*before* the aborting statement and one *after*, so "the leg never ran" (neither marker) is
distinguishable from "the defect fired" (first marker only); every shipped leg already works this
way, and deck C's own header says *a missing key means "not measured", never "no"*. (b) `cut` is
**corroboration, never the guard.** (c) The aborting leg is **last, in its own process** — an
artifact written and closed **before** an `abort()` survives it (measured), but buffered stdout
does not.

**D51 — The variant work lives on the adapter side of D34/D36, and one existing seam is on the
wrong side of it.** `ase::` owns the shape of a variant — `caps_get` / `caps_is` /
`caps_measured_as`, `requires_state`, the sentence frames, the warn/refuse policy.
`ase::backend::ngspice::` owns every ngspice spelling, trap and fact — the probe decks, the clause
list, the pass-through linter's five patterns, the co-simulation file checks. ⚠ **But the casemode
probe is not there yet**: `sim_probe_capability`, `sim_probe_leg` and `sim_probe_argv` are
**global procs in `src/xschem.tcl`**, and `sim_probe_argv` literally emits `-D casemode=$mode` — an
ngspice spelling, unnamespaced, in a file stock xschem sources. D36's naming rule is already broken
there. This decision does **not** move them (they predate the seam and the file is not ASE-L); it
**records the breach** so a Stage-1 schema freeze does not freeze around it silently, and so no
reader takes the adapter table at face value. It matters more now, because `casemode_detected` is
the load-bearing key that separates the fork from stock.

**D52 — `casemode_detected` is owned by `sim_probe_capability`'s three delivery legs and by nothing
else.** The tempting shortcut — read `$curcasemode` once in the variant deck and publish what comes
back — is **measured wrong**: with no `-D casemode=` flag, `$curcasemode` reports the **current**
mode, so it reads `none` / `none` / `fold` across apt 45.2, stock 47 and the fork. A crew that
populated `casemode_detected` from it would publish `{fold}` for the fork, narrowing the fork's
real answer of `{fold preserve distinguish}` and **switching off the one feature the fork has**.
`sim_probe_leg`'s own shipped header names this exact inference as measured-false. If the variant
deck collects `$curcasemode` at all, it is **Band 1 identity** under a different key
(`curcasemode_default`) — display and log only, never compared, never a gate.

---

**D53 — The `tran` emit template's `?` and `!` in the plan are SWAPPED, and the plan's spelling
would have moved all 104 committed goldens.** §3a writes
`emit {tran @step @stop @tstart! @tmax! @uic?}`. Under the slot grammar Stage 3's own C1 shipped
(issue 1414), `!` is resolved through `ase::field_emits`, which for a **non-bool** field returns the
field's **`default`** when the key is absent — so a `tstart` carrying a default emits
`tran 1n 10u 0` for **every** committed transient row, and `@uic?` would emit the stored value `1`
rather than the word `uic`. The shipped template is `{tran @step @stop @tstart? @tmax? @uic!}`:
optional value slots take `?`, and `!` is the **bool**. The positional obligation the plan was
reaching for with `!` is carried instead by **`whenskipped` on the field**, which is where it
belongs — a card-level flag would force every optional slot in every future template to answer the
same way, and `tmax` and `tstart` answer differently on purpose.

**D54 — The DC sweep variable is `source`, and the corpus is the whole argument.** §3a's sketch
names it `@target` with a `kind` field beside it. Measured over every tracked `.state` file:
**36** dc rows carry `source`, **0** carry `target`, and a **required** `@target` slot raises on
every one of them — reddening `test_ase_core`'s deck goldens, `test_ase_dialogs` G2 and
`test_ase_persist`'s summary rows for a field name nothing on disk has ever used. The classifier the
plan wanted from `kind` survives as the adapter hook `dc_swkind`, derived from the name rather than
stored beside it, which also means a bench edited by hand or written by an older ASE-L still
classifies correctly instead of carrying a stale second key.

**D55 — `dc_swkind` classifies by the SPICE device letter, never by a literal word list.** The
plan's shape — *the literal word `temp`, else a voltage source* — is **measured wrong on shipped
benches**. The 104 committed benches carry twelve distinct sweep variables
(`I0 V1 VD Vce Vds Vin Vres i0 i1 temp v2 vd`), of which three spellings are **current** sources
across **seven** rows; the sketch labels every one of them a voltage source and would offer the
wrong picker on seven benches that ship in this repository. The test is the **first character**,
lowercased — `i` current source, `r` resistor, else voltage source — with `temp` matched
case-insensitively as a whole word first. ⚠ **And it must be the first character and not a
substring**: `Vres` is a committed sweep variable and it is a **voltage source whose name contains
`res`**.

**D56 — The `grid` field (`native` / `interp` / `linearize`) is deferred from Stage 3 to Stage 6.**
It is the one item in §3a that is not a *parameter of the analysis card* — `interp` and `linearize`
are `.control` commands that run before and after the analysis, so shipping it in the field table
would put a control in the form whose emission has nothing to do with the slot grammar the rest of
the table uses. Stage 6 already owns the `.control` block's shape. ⚠ **The plan's own M8 row
anticipates this**: it asks whether `set interp` behaves on a complex AC plot and a nested DC sweep,
and answers *"the Tran form's `grid` field is Stage 3; the AC and DC arms are Stage 6"* — so the
field would have shipped in Stage 3 measured on one of its three arms. It ships in Stage 6 with all
three measured.

---

## ⚖ The user's rulings — eleven: THREE ANSWERED, eight carried

**House rule, and it is a standing preference recorded in this project: ONE AT A TIME.**
Raise the single most consequential open question, give the evidence and the
recommendation, then **stop** and let the user respond. Do not end a report with a numbered
list of ten open decisions and wait for ten answers; do not batch several into one
multiple-choice picker. Each is meant to be a short conversation, and the answer to one may
change how the next is framed.

**⚖ R1 is ANSWERED — 2026-09-10, Option A, and it added a requirement while it was at it (§7).**
Its entry stays where it is, first and in full, because the question, the options and the
trade-off are what the answer has to be read against.

**⚖ R2 is ANSWERED too — 2026-09-10, yes, with the four conditions as recommended (see its
entry).** It ratified the recommendation as written, so nothing in the plan moves and **D17**,
**D18** and **D19** stand; what changes is that the four conditions are now requirements rather
than advice, and Stage 7's pre-deck class and Stage 11's design-variable axis are unblocked.

**⚖ R3 is ANSWERED (2026-09-12, Option C). Ask ⚖ R4 next, and stop.** They are ordered below by
consequence, not by stage; with R1, R2 and R3 answered the order now puts R4 first. ⚠ **⚖ R11 is new (2026-09-10) and is filed LAST, behind R10.** It arrived
with the variant amendment, whose ship-first item is a release note — but the *description* in that
note needs no ruling and ships without one; only its **support sentence** is R11. Nothing about
R11 jumps the queue, and a crew that asks it out of turn has taken a wrong turn. R1's answer does **not** shrink it: R2's own blocks-line says it
"largely disappears" if R1 = B, and R1 = **A**, so all 26 pre-deck variables, the three doors and
the four traps stay exactly where they were. **R10 is new (2026-09-10) and does not displace it**:
it is filed last because it decides how much *further* than Stage 1 the adapter contract is
formalised, and Stage 1 builds the working hook either way.

**NOTHING HERE BLOCKS STAGE 0 OR STAGE 1.** Both carry zero rulings by construction — this
tree's own sequencing habit — so the plan can start the day it is read and the first
question can be asked while Stage 0 is being built. **R10 does not change that**: D34–D37 are
decisions, not rulings, so the doctrine, the first-customer rule and Stage 1's Xyce paper
validation all proceed unasked. R10 is only about what is written down *after* them.

**R9 is the exception to one-at-a-time, deliberately: it is BATCHED PER STAGE.** It is the
standing label-ratification debt, and twelve analyses would otherwise mean twelve rounds of
asking, which is precisely what the standing preference forbids.

---

### ⚖ R1 — ANSWERED. The transport. Move from `-b` to `-p` in this batch, or keep `-b` and treat `-p` as a later stage?

**✅ ANSWERED 2026-09-10 — Option A. `-b` stays in this batch; `-p` stays deferred.** The ruling
is the user's, and so are these words:

> *"In batch mode, is there no way to write what was simulated 'thus far' to disk before exiting?"*
>
> *"What is the benefit of losing partial results on Stop? Why would one ever want to do that?"*
>
> *"We should put that in right away - always salvage, and alert user that her sittings will cause
> loss of simulation effort 'thus far'"*
>
> *"That being said, in terms of milestones on the plan, it can wait. We proceed along path of
> least resistance"*
>
> — the user, 2026-09-10. Quoted verbatim.

**What that settles.** Two things, and they are separable. On the *transport* it is Option A:
`run_cmd`'s word order does not move, the six pinned `test_ase_simreg_0931` rows do not move, and
the `-p` reader is a later stage. On the *requirement* it adds something neither option contained
— **always salvage, and warn wherever a Stop would still lose work**. That is **D38** and **D39**;
**D40** is the batch-mode mechanism and **D41** the refusals it brings. Milestones take the path of
least resistance; the requirement does not wait for a transport.

⚠ **The trade-off below was stated on a FALSE PREMISE, and the answer stands anyway.** The premise
was that batch mode cannot salvage — *"`-b` … leaves the only measured capability gap — stop and
keep what you have — permanently open on a single long run"*. It can. `evidence/salvage.md` §3 is
that capability, in `-b`, on the stock binary, without touching `run_cmd`. Read the trade-off's
first line as: **`-b` costs nothing now, and salvage costs a deck-renderer change rather than a
transport change.** The answer does not move on the correction, because the user ruled on
**milestones** — *"path of least resistance"* — not on the premise. It was their two questions
above that sent someone to measure it in the first place; the measurement made the cheap answer
the honest one as well.

⚠ **`-p`'s abort advantage is not latency, and Option B says it is.** Measured: batch dies in
**a few milliseconds at worst** for SIGTERM and SIGKILL alike, because nothing handles either —
at or below the "under 5 ms" figure `evidence/builds.md` credits to `-p`. (The figure tracks the
run's resident memory rather than the signal, which is why three sittings gave three answers;
`PLAN.md` **C35** has the mechanism.) What `-p` buys is a
**non-destructive** abort, not a faster one: no checkpoint granularity, no torn-file window, no
`shell mv`, and the data still live in the process afterwards. State it that way wherever this
comparison is repeated; the latency framing invites a reader to think the two are close, and on
*that* axis they are.

**What still argues for `-p` after Stage 10 — and it is no longer the price of admission for not
losing work.** Three things, none of them about losing work: the **no-circuit capability probe**
that D34's adapter doctrine leans on; the pre-deck door collapsing to **one** (`set` before
`source`), which is what would moot ⚖ R2 and delete D19; and the four accidents of driving a
checkpoint loop from *outside* the process that D40 has to work around — the two silent traps of
`evidence/salvage.md` §3.9, the stop leaking into the next analysis (§3.5), the blind status guard
(§3.6) and the torn-file window (§4.3). Each is individually cheap to handle. Together they are
the reason the second implementation is still worth scheduling.

---

*The question as it was carried, kept for the record:*

*Blocks: nothing until Stage 10 — but it REORDERS Stages 7, 10 and 11, and it changes R2's
stakes.* **This was the most consequential ruling in the batch; it was asked first.**

* **Option A — keep `-b` this batch** (design B's position). Zero change to
  `ase::backend::ngspice::run_cmd`, whose word order is pinned byte-for-byte by
  `test_ase_simreg_0931` rows **A2 / B5 / B6 / B11 / B12 / D4** — six of them, with **L11**
  pinning the exe alone. (D4 reaches argv through `a_runcmd_said`'s first element; it was
  named alone in the design of record, which was true but incomplete. `PLAN.md` §0.1 has the
  six-row list and records that an earlier draft of §0.1 wrongly claimed D4 asserts nothing
  about argv — this line was right the whole time.) the pre-deck door stays `<rundir>/.spiceinit` + `-D`;
  abort stays SIGKILL, and the shard runner is what makes a long campaign interruptible.
* **Option B — move to `-p` now** (`evidence/builds.md`'s recommendation). Graceful abort
  measured at **under 5 ms** with partial results fully intact — a valid 388 MB rawfile
  written after the stop, `resume` continuing to 5.1 M points, `quit` rc 0 — against **any
  ngspice the user already has**; and the pre-deck problem collapses from three doors and
  four traps to **one** (`set` before `source`), which would make R2 moot and delete D19
  entirely.

*Trade-off.* `-b` costs nothing now and leaves the only measured capability gap — *"stop and
keep what you have"* — permanently open on a single long run. `-p` costs one asynchronous
reader that parses the `ngspice N -> ` prompt, plus a rewrite of `run_cmd`, the log framing
(decision G) and the exit-status contract (I6), and buys the abort, the option door, and the
transient debugger (`iplot` / `stop when` / `resume` / `step`) that every later stage wants.

⚠ **Two lines inside the options as carried are now wrong, and the answer does not rescue them.**
Option A's *"abort stays SIGKILL"* — it is SIGTERM, then SIGKILL after a ~200 ms grace, so a
`shell` child can finish its rename (**D40**). Option A's *"the shard runner is what makes a long
campaign interruptible"* — the shard runner is no longer the *only* partial-result story; a single
long run inside one shard is now interruptible too (**D38**).

**Recommendation — ADOPTED, with its cost line corrected: define ONE internal run interface now
(D20), implement it with `-b` for Stages 0–9, and schedule `-p` as its second implementation
immediately after Stage 10** — because the abort story matters most once campaigns (Stage 11)
exist, and because **[R-M8]** removes the progress argument for hurrying. `libngspice` is refused
either way. The correction is that "implement it with `-b`" now includes salvage (**D38**, via
**D40**), which the recommendation was written believing it could not.

### ⚖ R2 — ANSWERED. May ASE-L write `<rundir>/.spiceinit`, copying the user's own file into it?

**✅ ANSWERED 2026-09-10 — yes, with the four conditions.** The user's words, verbatim:

> *"yes, with those four conditions"*

The recommendation below is ratified **as written**, so no option was modified and no cost line
was refuted — this is the rare ruling that changes nothing except that it settles something. What
it does change is the standing of the four conditions: they are **requirements** now, not advice,
and a crew that ships the file without one of them has shipped a defect rather than a shortcut.

1. **Deleted and rewritten per run** — it joins the rawfile, the plotmap, the `.ckpt` and
   `<cell>_ase.effective` on the pre-run delete list, and for the same reason: a stale one is
   indistinguishable from a live one.
2. **The user's own file is COPIED under a banner, never `source`d.** `source <user file>` makes
   ngspice parse the target as a **netlist** and the user's variables are lost (**[R-M7]**,
   **D19**). ASE-L reads `$HOME/.spiceinit` — or `$SPICE_USERINIT_DIR`'s — itself.
3. **The run log says once that the file exists and what it shadows**, because ours is found first
   (netlist dir → `$SPICE_USERINIT_DIR` → cwd → `$HOME`, first hit wins) and therefore shadows the
   user's entirely for that run.
4. **Refused** when the rundir is the shared `set_netlist_dir 0` fallback (**C19**) and when `-n`
   is in force on the simulator entry (**D18**). Both refusals must **name** what they are refusing
   over: under `-n` the file is silently ignored and the only message ngspice prints is about a
   resistor, and the shared-rundir fallback is the resolution that cost a user their rawfile once
   already.

**What it unblocks.** Stage 7's pre-deck option class — the 26 `cp_getvar` variables `.options`
cannot reach, `casemode`, `ngbehavior` and `wnflag` among them — and Stage 11's design-variable
axis, which is what makes a sweep, a corner set or a Monte Carlo run possible with the schematic
untouched. **D17** and **D19** stand exactly as written.

⚠ **Measured on this machine the day it was answered, and it is condition 2's own case:** there is
**no `$HOME/.spiceinit` here** and `SPICE_USERINIT_DIR` is unset, so nothing of the user's is
shadowed today. Condition 2 therefore costs nothing now and becomes load-bearing the first time
the user writes one — which is exactly the moment a crew that skipped it would discover `source`
loses their variables. **A crew must not read "no user file today" as "condition 2 is optional".**

---

*The question as it was carried, kept for the record:*

*Blocks: Stages 7 and 11. If R1 = B, this ruling largely disappears.* ⚠ **Note 2026-09-10: R1 was
answered A, so it does not.**

* **Option A — yes.** It is the **only** door to 26 pre-deck variables (`CP_NUM`, `CP_REAL`
  and `CP_LIST` cannot ride `-D`) and therefore the only door to the campaign's
  design-variable axis. Ours **shadows `$HOME/.spiceinit` entirely** for that run, so the
  user's lines are copied in — measured working, **[R-M7]**.
* **Option B — no.** Then `casemode`, `wnflag`, `ngbehavior` and 23 others stay unreachable,
  and the campaign falls back to `alterparam` over ASE-L's own `.param` rows only.

*Trade-off.* Yes buys the whole pre-deck class and the campaign, at the cost of ASE-L owning
a file in the run directory that changes what a hand-run deck in that directory does. No
keeps the run directory inert and leaves a documented capability class permanently out of
reach.

**Recommendation: yes**, with four conditions — the file is deleted and rewritten per run;
the user's own file is **copied** under a banner, never `source`d (**[R-M7]**); the run log
says once that the file exists and what it shadows; and it is **refused** when the rundir is
the shared `set_netlist_dir 0` fallback (C19) or when `-n` is in force (D18).

### ⚖ R3 — ANSWERED. Do the Outputs Value-column numbers come from the rawfile's one-point plots instead of the `print` log?

**✅ ANSWERED 2026-09-12 — Option C, "both with a rule". The user's words: *"both with a rule is right, keep it"*.**

Named vectors are read from the **rawfile**; arbitrary typed expressions are read from the **`print` log**. This is what shipped in issue **1429** as the recommendation, so **no code changes** — the ruling ratifies the standing behaviour rather than redirecting it.

⚠ **What this closes.** `noise`, `tf` and `sens` get a Value column they could not have had under Option B, because with the prints anchored where the user's own ruling in issue 1243 put them, `print Transfer_function`, `print onoise_total` and `print r1` produce **nothing at all** — no value, no warning, no error line — while all three vectors sit in the results file. And `v(a)*2` keeps working, which Option A would have broken.

⚠ **What stays true regardless.** The separability that let this ship unratified is now load-bearing documentation rather than an escape hatch: the rule lives in one proc, `ase::result_source`, and row **RS3** of `test_ase_core` performs *both* rulings by stubbing it, with a fixture log deliberately carrying a different number from the results file so the row can say which reader answered. Keep that row: it is what makes a future reversal one line instead of an archaeology exercise.

⚠ **Still open and NOT closed by this**: ⚖ **R9**, the standing label ratification, which includes the three sentences the R3 reader seam added. The `owed.sh` entry for issue 1429 says so in as many words, and it remains outstanding.

*Blocked: Stage 6 — now unblocked.*

* **Option A — move to the rawfile.** Every scalar an analysis produces is a one-point plot
  (`Operating Point`, `Integrated Noise`, `Transfer Function`, dc `Sensitivity Analysis`).
  It removes `result_probe`'s case-folding ladder and it is what gives NOISE, TF and SENS a
  scalar home at all.
* **Option B — keep the log.** `result_probe` parses `<expr> = <number>` out of `print`
  output, which is the **only** thing that can evaluate an arbitrary user-typed expression
  such as `v(a)*2` — not a vector in the raw.
* **Option C — both.** Named vectors from the raw; expressions from `print`.

*Trade-off.* A is cleaner and unlocks three analyses but silently breaks every expression row
a user has typed. B keeps expressions and leaves three analyses with nowhere to put their
answer. C keeps both, at the cost of two readers and a rule about which wins.

**Recommendation: C**, with the rule stated **on screen**: a row whose expression names
exactly one vector reads the raw; anything else reads the log. Issue 1243 was the user's own
ruling and this extends it rather than reversing it.

### ⚖ R4 — ANSWERED. Does `ase::state_default` gain any of the new analysis types?

**✅ ANSWERED 2026-09-13 — Option A, keep four.** The user's words:

> *"keep four. I don't know how we ended up with this, but it's probably more user-friendly
> than zero. In Cadence ADE-L it **is** zero"*

⚠ **AND THE ANSWER CORRECTS THE ARGUMENT IT WAS PUT ON.** Option A below was offered with
*"Cadence does not add analyses to your bench either"*, i.e. as ADE-L **parity**. That is
wrong: **ADE-L seeds ZERO.** So ASE-L's four seeded rows were never a match — they are a
deliberate divergence in the user's favour, and the user ratified them as such. The
recommendation happened to land on the right answer for a reason that was not true, which
is the worse kind of right.

⚠ **The general rule that follows**, because this batch cites ADE-L constantly: **ADE-L is
the FLOOR, not the ceiling.** *"ADE-L does not do this"* is an argument for removing a
**restriction** of ours (the standing rule, and the reason issue 0643 was a defect); it is
**not** an argument for removing a **convenience** of ours. Check, do not recall, before
citing ADE-L behaviour in a decision the user is being asked to make.

*Blocked: Stage 2, which shipped Option A by construction long before the ruling arrived —
so this ratifies eleven commits' worth of existing behaviour rather than changing anything.*

* **Option A — no** (**CHOSEN**). All committed `.state` files carry exactly four rows,
  `test_ase_core.tcl` R1 asserts "the four types in order". New types arrive through the
  dialog. ⚠ The original wording of this option also said *"and Cadence does not add
  analyses to your bench either"* — struck, see above.
* **Option B — yes**, seeding all the registered types as disabled rows so every type is
  visible on a fresh bench. ⚠ This option said **twelve**; the registry holds **eleven**
  (`op`, `dc`, `ac`, `tran`, `noise`, `tf`, `pz`, `sens`, `disto`, `pss`, `sp`), of which
  four are seeded. The twelve was never re-counted after the registry settled.

*Trade-off.* No keeps every golden and every existing bench identical and costs a user one
click. Yes makes the whole surface discoverable at a glance and moves R1's assertion, the D1
golden and every freshly created view.

**Recommendation was A (no)**, and A is what the user ruled. Discoverability is served by
D6's four-state grid, which shows all eleven whether or not they are in the state file.

⚠ **WHAT THE RULING NOW OBLIGES.** The reason this was a ruling at all is that *"today
this would change by accident"* (D5): the registry carries a `seed_enabled` key, and every
analysis type added across Stages 5–8 could have picked it up silently. Eleven commits
kept it off by hand. **A ratified decision must not depend on anybody remembering it**, so
the follow-up is a row that reddens if a twelfth type is ever seeded — not merely the
existing assertion that four rows come out, but one that names `seed_enabled` as the thing
that must stay off.

### ⚖ R5 — ANSWERED. Reverse recorded decision D4: should switching the analysis type keep what you typed?

**✅ ANSWERED 2026-09-13 — Option A, reverse it.** The user's words:

> *"Make it remember — that's a more professional UI. We are trying to be better than
> Cadence"*

⚠ **THIS IS THE FIRST RULING IN THIS BATCH THAT CHANGES BEHAVIOUR RATHER THAN RATIFYING
IT.** ⚖ R1, R2, R3 and R4 all landed on what the tree already did. D4 is what shipped, and
the recommendation was its opposite, so this one is **work**, not a rubber stamp.

*Blocked: Stage 3, which shipped **Option B** — so Stage 3's form is the thing being
changed.*

* **Option A — reverse it** (**CHOSEN**). Cache per-type edits for the dialog's lifetime and
  commit only the visible type at OK. D4's stated reason — *"deterministic, no hidden
  multi-type writes"* — is still satisfied, because **nothing is written until OK either
  way**. D4's reasoning defends the **commit**, and the commit does not change; it never
  defended the discarding.
* **Option B — keep D4.** A radio click discards the form.

*Trade-off.* Reversing costs one dict per dialog and makes the type row explorable; keeping
it is defensible with four types and a trap with twelve.

**Recommendation was A (reverse)**, and A is what the user ruled.

⚠ **THE TRADE-OFF LINE UNDERSTATED ITS OWN CASE, AND THE TREE HAD ALREADY MEASURED IT FROM
THE USER'S SIDE.** *"Defensible with four types"* was written when the radio row held four.
Issue **1411** made it a wrapping grid of **eleven**, four per row — so clicking across the
grid to see what each analysis offers, which is the first thing a new user does, costs them
whatever they had typed, every time. And `doc/claude/ase_l_ux_batch/FINDINGS.md` had already
recorded it as a lived defect rather than a hypothetical:

> *"PROBE after ac->tran round trip, stop = '200u' — typing survived? 0 — I typed 500u,
> clicked the ac radio, clicked back, and 500u was gone."*

⚠ **WHICH `D4` THIS IS.** Not `DECISIONS.md`'s own **D4** (*"exactly two optional per-row
keys: `id` and `x`"*) — a different batch's. R5's D4 is
`doc/claude/ase_l_batch/prompts/item07_dialogs.md`, and it is quoted in `src/ase_window.tcl`
at the `chana_show` repopulate comment. **The reversal must name that file**, or the next
reader reverses the wrong decision.

⚠ **WHERE IT LANDS.** `src/ase_window.tcl` only; one dict per open dialog; no new widget
and nothing newly drawn, so **no `look` debt**. It is sequenced **before Stage 8 task 2**,
deliberately: task 2 builds the Measurements sub-dialog in the same file and the same form
idiom, and it should **inherit** the remembering behaviour rather than be retrofitted with
it afterwards.

### ⚖ R6 — ANSWERED. Do analysis rows gain identity (`id`) — i.e. two DC sweeps or two AC sweeps at once?

**✅ ANSWERED 2026-09-13 — Option A, add it.** The user's words: *"Add it"* — **and the same
message added a requirement neither option contained**, which is now issue **1444**:

> *"also plan for a way for measure statements (pending work) that could be used in the
> calculator to refer to different analyses. It should be easy for a user to find out how to
> refer to different analyses for purposes of building measure statements."*

⚠ **THAT IS THE SECOND TIME A RULING IN THIS BATCH HAS ARRIVED CARRYING A REQUIREMENT THE
OPTIONS DID NOT OFFER** — ⚖ R1's *always salvage* was the first. **A ruling is a
conversation, not a selection**, and the offered options are the floor of the answer rather
than its shape.

*Blocked: nothing; wanted after Stage 3, which is complete — so it is unblocked now.*

* **Option A — yes** (**CHOSEN**). One optional per-row key, **absent on every committed
  file** — driver-verified 2026-09-13: the four `.state` files that match `id` carry an
  **output row named `id`** (a drain current), not a per-analysis key, so the premise holds
  and no committed bench moves. No schema version bump. It is the difference between a bench
  that can say "sweep VIN **and also** sweep temperature" and one that cannot.
  ⚠ The original wording also claimed *"it is ADE-L behaviour #9"*. **That was NOT asserted
  to the user when the ruling was put**, deliberately — an ADE-L claim had just been wrong in
  R4's recommendation — and it is recorded here as the plan's claim, unverified.
* **Option B — no.** `ase::ui::chana_row` returns the **first** row of a type and
  `pane_dblclick` discards the index, so the addressing work has to come first either way.
  ⚠ **Driver-verified at HEAD**: `chana_row` still walks `analyses` and returns on the first
  type match. The addressing is genuinely not done.

*Trade-off.* Yes needs the dialog to address rows by index before the key is useful; no
leaves a common bench shape unsayable for the life of the plan.

**Recommendation was A**, and A is what the user ruled. ⚠ **The honest content of "yes" is
the sequencing, not the key**: the key is nearly free and the row addressing is the work,
and it was required under either option.

⚠ **WHAT R6's TASK NOW OWNS, BECAUSE OF 1444.** The naming scheme is R6's deliverable, not
Stage 8's: `ase::meas_binding` already answers *"which analysis occurrence this row reads"*
as **`{type idx}`**, and the user-visible spelling must follow that shape and be settled
**once**. R6's task ships the scheme, a handle column in the Choose Analyses grid, and
`Analyses > List`; Stage 8 task 2's Measurements dropdown **consumes** it. If that order ever
inverts, task 2 consumes `{type idx}` verbatim rather than minting a display form.

### ⚖ R7 — **REVERSED 2026-09-16. The PSS panel is NOT built.** Do we ship a PSS panel at all?

✅ **THE ANSWER IS NOW *NO*, AND THE 2026-09-13 RULING BELOW IS SUPERSEDED IN FULL.** Re-put to the
user on `evidence/pss-two-binaries.md`, their words: ***"don't build it, write up the issue."***
Issue **1475** carries the measurement; `PLAN.md` §14 is retained as the design that was not
implemented.

⚠ **WHAT CHANGED WAS THE EVIDENCE, NOT THE ARGUMENT.** Every performance number the 2026-09-13
ruling rested on came from a **scratch `--enable-pss` build of `ccebdf2a2`** that no user has. On
the binary Ubuntu ships, PSS converges on **nothing measured** — twenty cases, zero convergences,
including ngspice's own shipped example with its own arguments — and reports **rc 0** with both
plots full and a frequency about **2.6 % high**. The upstream fix `668329ca3` ("this will re-enable
convergence") is in **no release tag**, so this is every released ngspice, not this machine.

⚠ **AND THE DECIDING INPUT WAS NOT A MEASUREMENT.** The block below records that the driver asked
whether the user actually *runs* PSS and that *"the user answered by delegating instead"* — it was
put again on 2026-09-16 and answered: ***"I have never run PSS."*** That is the thing no
measurement here could settle, and it is what made the ruling easy. **The paragraph below that
names Stage 14 as the cheapest stage to cut was written before anyone knew it would be cut; it was
right.**

⚠ **NOTHING USER-VISIBLE CHANGES.** `pss` keeps `baseline 0  registered 1` with a probe-only
template (`src/ase.tcl:27342`), so it stays **listed** and an enabled row keeps answering *"This
pss analysis is not one this simulator can set up."* That string is ratified copy under ⚖ R9 and
is **not** reopened by this ruling.

#### ⬇ THE SUPERSEDED 2026-09-13 RULING, KEPT IN FULL — everything below this line until ⚖ R8 is the answer that no longer stands

#### ⚖ R7 as it was ANSWERED on 2026-09-13. Do we ship a PSS panel at all, given that the build probes ran it successfully?

⚠ **MEASURED AFTER THE RULING, 2026-09-13, AND IT SHARPENS WHAT "EXPERIMENTAL" HAS TO
MEAN: `pss` SEGFAULTS ON A SHORT ARGUMENT LIST, ON BOTH BINARIES.** `pss 1meg 1m out 1024`
— four arguments — dies with **rc 139** on 45.2 *and* on the fork, printing only
`Error: Strange behavior`. Five arguments or more survive. Full measurement:
`evidence/pss-stage14.md`.

That is a worse class than anything else this batch has classified: no `$sim_status`, no
guard, no `remzerovec`, **no salvage** — issue 1433's checkpoint machinery runs *in the
deck*, and there is no deck left — and everything after it in emit order dies with it,
**including `op`**, which is kept LAST (0964) exactly so a broken run still leaves it
behind.

**So the ruling stands and its implementation gains a hard requirement:** the panel ships,
and the emitter **never writes a `pss` card with fewer than five arguments** — not as a
default, not for a blank optional field, not for a `.state` file written by an older ASE-L
or edited by hand. A test row must prove the *shortest possible* emission is five, by
counting words in the rendered deck. **The experimental wording is not the guard**: a
sentence warns, it does not stop a four-word card reaching the simulator.


**✅ ANSWERED 2026-09-13 — Option A, ship it, explicitly experimental.** The user's words:
*"follow your recommendation"*.

⚠ **WHAT "THE RECOMMENDATION" INCLUDES, STATED SO A LATER READER DOES NOT HAVE TO GUESS.**
The user ratified the **written** recommendation below, which carries four parts: ship it
**last**, the word **experimental** on the form, the **transient+FFT cross-check offered
beside the answer**, and **the sentence that `oscnode` steers nothing** (correction C17).
⚠ The first three were restated to the user when the ruling was put; **the `oscnode`
sentence was not**, so it is inherited from the written recommendation rather than
separately ratified. Its *wording* is R9's in any case.

⚠ **AND THE ARGUMENT HAS MOVED SINCE THIS WAS WRITTEN, IN ASE-L's FAVOUR.** The trade-off
below says not shipping *"avoids owning a panel whose `Convergence not reached` returns rc 0
with plausible-looking data"* — the silent-wrong-answer class. Three pieces of machinery
built **after** this ruling was drafted exist to catch exactly that: the `$sim_status` guard
(0964/1243), issue **1430**'s post-run plot reconciliation, and issue **1442**'s
requested-versus-effective readback. ASE-L is now materially better placed to own a run that
lies about itself than it was when the question was framed, and that was put to the user as
part of the case.

*Blocks: Stage 14 only — five stages away, so nothing is gated on this.*

* **Option A — ship it, explicitly experimental**, gated on `help pss`, with the hard
  validator and the stdout verdict scrape. It runs in under a second on both shipped
  oscillators and its plot literals are now recorded [builds].
* **Option B — declare it and offer no form**, as all three designs proposed *before* the
  build probes ran.

*Trade-off.* Shipping gives ngspice's only large-signal periodic analysis a home and is
defensible because every crashing input is now known and refusable. Not shipping avoids
owning a panel whose `Convergence not reached` returns **rc 0 with plausible-looking data**.

**Recommendation: A**, last, with the word *experimental* on the form, the transient+FFT
cross-check offered beside the answer, and the sentence that `oscnode` steers nothing
(correction C17).

### ⚖ R8 — ANSWERED. Where does a campaign's configuration live?

**✅ ANSWERED 2026-09-13 — Option A, the state file.** The user asked what *"inside the
bench"* meant before ruling, and their answer carried the requirement:

> *"What does 'inside the bench' mean? Will there be an artifact on the schematic? I want it
> in the simulation state — so the user can interact with this Monte-carlo 'campaign' in
> ASE-L"*

⚠ **THE QUESTION WAS ASKED BECAUSE THE DRIVER'S PHRASING WAS AMBIGUOUS, AND THAT IS WORTH
RECORDING.** *"Inside the bench"* can be read as *"on the schematic"*. It is **not**: the
`.state` file is a separate **view** (`ngspice_state1/`) sitting beside `schematic/` and
`symbol/`, and **nothing is written to the schematic at all**. A ruling put in words that
admit a wrong reading is a ruling that can be answered wrongly; the user caught it.

⚠ **AND THE ANSWER ADDED A SURFACE REQUIREMENT NEITHER OPTION STATED** — *"so the user can
interact with this campaign in ASE-L."* Option A as written is a **storage** decision; the
user ruled on it as an **interaction** decision. Stage 11 owes a surface, not merely a key.
**Third ruling in this batch to arrive carrying a requirement the options did not offer**
(⚖ R1's *always salvage*, ⚖ R6's analysis-reference discovery, and now this).

⚠ **THE BENCH THE USER NAMED IS ALREADY SHAPED FOR IT.**
`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap` carries
`{name VCCGAUSS value {agauss(1.8, 'ABSVAR', 1)}}` in its `variables` — a Monte Carlo
distribution written **by hand**, which ASE-L today runs exactly **once**. The campaign key
is what turns that into *"run it 200 times and show me the spread"*, and it lands on a bench
that already has the distribution in it.

*Blocks: Stage 11.*

* **Option A — a new top-level `sweep` state key** joining `ase::omit_if_empty`
  (the `ase::omit_if_empty` variable, hint `:110`, today `{cosim save_op_params sim_entry}`),
  absent on every one of the 104 committed files.
  D3 forbids new top-level keys; this would be the single named exception.
  ⚠ **NO LONGER SINGLE, AND THE EXCEPTION IS ALREADY PAID.** Driver-measured 2026-09-13
  while this ruling was being put: Stage 8's `measurements` list is **already** a new
  top-level key, added by the same `ase::omit_if_empty` mechanism
  (`{cosim save_op_params sim_entry measurements}`), with **all 104 committed `.state`
  files still byte-for-byte unchanged**. So the mechanism Option A was costed against is
  in use and proven safe across every bench in the repository, and **Option A is cheaper
  than its own trade-off line claims**. See D3, corrected.
* **Option B — outside the state file**, as a sibling artifact in the run directory.

*Trade-off.* A keeps the campaign with the bench, travels with the cellview, and round-trips
through the existing serializer — at the cost of the one schema exception. B keeps the
schema untouched and makes a campaign something you can lose.

**Recommendation: A**, with `omit_if_empty` so byte-identity for the committed files is
preserved **by construction**, and `version` still `1`.

### ⚖ R9 — The standing label ratification. BATCHED PER STAGE.

⚠ **THE DOCUMENT NOW EXISTS: `R9_COPY_REVIEW.md`, written 2026-09-13.** R9 is the only
ruling left in the batch, and it needs something to read rather than a conversation, so it
was built: **291 strings from 19 issues**, each with a stable handle `R9-001`–`R9-291`,
grouped by **where the user sees them** rather than by issue number — every label on one
form together, every refusal together, the whole options sheet together.

**Two measured facts from building it, both of which change how a copy debt should be paid
in future.**

1. **The issue files could not be the source.** Most of them only *describe* their copy
   (*"every label carries its unit"*, *"mints three frames"*, *"four precondition sentences
   with their four remedies"*), and several quote a draft that was superseded before the
   commit landed. Every string in the review was therefore taken from the **committed source
   at HEAD** and cross-checked against the commit that introduced it, with
   continuation-joined Tcl strings rendered through `tclsh` so the text is what the widget
   shows. **A `rule` debt that records only a description does not preserve the sentence** —
   file the string itself.
2. **The interesting questions are cross-cutting, not per-string.** Reading 291 strings one
   at a time would ask the user the same question nine times over; reading them by surface
   surfaced **nine recurring choices** — shouted words mid-sentence, lowercase acronyms in
   pickers, internal slot names shown where the form shows a label, `Stop` vs `Stop time` vs
   `Stop frequency`, units in parentheses, developer vocabulary (*"this simulator backend"*,
   *"readable list"*), two frames for the same event, sibling sentences that drifted apart,
   and placeholders the user is meant to read as placeholders. **Section A of the review is
   those nine**, each with a recommendation; the other 282 entries are mostly consequence.

Issue **1443**'s strings are **not** in it: that crew is still running and its issue is not
committed. They join when its receipt lands.


*Blocks: nothing; owed at the end of every stage that mints a sentence.*

Every new user-facing sentence in this plan is the user's to ratify: the four type-state
sentences, every field label and unit, every precondition sentence, every refusal, the
`optran` sentence, the transient-noise seed sentence. Each is filed with
`tests/headless/owed.sh add rule <id>` at the moment it is minted — never later — and paid
in one batch when the stage closes.

**Recommendation: batch per stage, and say so when the first one is raised.** Twelve
analyses asked one sentence at a time would be dozens of rounds; one round per stage
respects the standing preference instead of defeating it.

Stage 1 mints **no** user-facing sentence. Stage 0 mints exactly **one** — the refusal naming
the unrenderable type, *"ase: analysis type '<t>' is not one this simulator can
render"* — which is filed as a rule debt (`owed.sh add rule <issue>`) **the moment it lands**
and paid with Stage 3's batch. It **blocks nothing**, and both stages still carry no ruling
that has to be answered before they ship. ⚠ **CORRECTION 2026-09-09**: this paragraph used to
say Stages 0 and 1 mint no sentence at all, which collides with CREW_BRIEF's standing rule
that a new user-facing sentence is the user's ruling and must never live in a write-up only.

### ⚖ R10 — ANSWERED. How far is the adapter contract FORMALISED in this batch?

**✅ ANSWERED 2026-09-13 — Option B, the written specification. The user's words: *"go with B
— your recommendation"*.**

⚠ **AND THE RECOMMENDATION WAS NOT ONE OF THE THREE AS WRITTEN.** It was **B now, and C only
when a second adapter exists to run it against**, for a reason this batch paid for nine times:
**a conformance harness with ONE implementation behind it cannot tell the contract from the
implementation.** Written today it would be run against ngspice, pass against ngspice, and
codify ngspice's shape as *the contract* — with nothing able to disagree with it. That is *a
row whose fixtures never disagree cannot fail*, at architecture scale and costing a whole
stage. A written spec has no such failure mode: prose that is wrong about a hook is wrong in a
way a second author **notices and complains about**, which is the feedback a harness cannot
give until there are two implementations.

⚠ **SO STAGE 15 IS OUT OF THIS BATCH'S COMMITTED SCOPE.** It stays in `PLAN.md` as a stage
that may be **chosen** when a second adapter appears; it is no longer a stage this batch owes.
That is what this ruling was filed to decide, and it decides it.

⚠ **THE MEASUREMENT THAT DECIDED IT, AND IT IS WHY THE RULING WAS RE-READ AGAINST THE TREE
RATHER THAN THE PAGE.** Option A — *"a second adapter's author reads the ngspice one and the
contract block"* — was framed on **2026-09-10**. Driver-measured 2026-09-13:

| when | hooks the ngspice backend registers |
|---|---|
| 2026-09-10, when R10 was written | **8** |
| 2026-09-13 at HEAD | **23** |
| the same day, with Stage 8 in flight | **27** |

and `ase::backend::ngspice` is **4,987 lines**. **The contract has roughly tripled since the
question was framed, with eight stages still to go.** Option A was reasonable at eight hooks;
at twenty-seven it means inferring a contract from five thousand lines. ⚠ **Third ruling in
one day whose cost had moved since drafting** — ⚖ R7 and ⚖ R8 were the others.

*Blocks: nothing in Stages 0–14. Decided whether Stage 15 is in this batch's scope at all —
it is not. New 2026-09-10, from the architecture change that produced D34–D37.*

⚠ **WHEN OPTION B's DOCUMENT IS WRITTEN MATTERS, AND IT IS NOT NOW.** The contract is still
growing — Stages 9–14 and 16 will add hooks — and a specification written against a moving
contract is stale on arrival. That is not a guess: `doc/claude/specs/ase_l.md` sat **five
stages** behind until 2026-09-13 for exactly that reason. **The adapter-author specification is
written after the last hook-adding stage**, i.e. after Stage 14 and with or before Stage 16,
and the ledger carries that as the scheduling note.

D34 settles **that** ASE-L owns a schema and an adapter owns the content. It does not settle how
much of that schema is written down for somebody who is not in this room.

* **Option A — the working hook plus its documented schema.** Exactly what Stage 1 already
  builds: `ase::analysis_types` resolving an optional backend hook, the key-by-key contract block
  in Stage 1 §1a, D37's Xyce descriptor written on paper, and the ngspice adapter standing as the
  worked example. A second adapter's author reads the ngspice one and the contract block.
* **Option B — A, plus a written adapter-author specification**, aimed at a coding agent working
  on another simulator: every key, its type, what is required and what may be omitted, what the
  core promises to call and in what order, and what is undefined behaviour.
* **Option C — B, plus the Stage 15 conformance harness**: a suite an adapter author runs against
  their own binary until it goes green, which turns "write an integration" from an essay into a
  closed loop with a pass/fail signal.

*Trade-off.* Each step buys reusability for the **next** simulator and costs time the two adoption
gates are also asking for — **Stage 8** (measurements: `meas`, `.four`/`fft`/`psd`, the Value
column rows a user actually switches tools for) and **Stage 11** (campaigns: sweeps, corners,
Monte Carlo). A is free, because Stage 1 pays for it anyway, and leaves a second author reading
an example rather than a spec. B is perhaps two days and is the difference between "read
`ngspice_adapter.tcl` and copy it" and "implement to a document" — but a specification written
against one implementation documents that implementation's accidents as if they were rules, and
every one of those accidents is then something the second author has to discover is optional. C
is the only one that actually proves an adapter works, and it is also the only one with no
customer yet: with adapters first-party (D35) the author is us, the binary is ngspice, and the
harness would grade the thing that defined it.

**Recommendation: A in this batch, with B written the moment a second adapter is genuinely
wanted** — and D37's paper Xyce descriptor is the cheap half of B, taken now, because it is what
finds the accidents while a key set can still be changed for free. C stays as **Stage 15**, filed
as what the *second* adapter needs rather than what the first one does; if the answer to this
ruling is C, Stage 15 moves from terminal-and-optional to scheduled, and Stage 8 or Stage 11
gives up the time.

⚠ **NOT DECIDED. The user has not answered this.** ⚖ R1 is answered (2026-09-10, Option A) and
⚖ R2 with it (2026-09-10, yes with four conditions); **⚖ R3 is ANSWERED (2026-09-12, Option C); ⚖ R4 is ANSWERED (2026-09-13, Option A, keep four); ⚖ R5 is the next one to ask**, and this one
is filed second-to-last — ⚖ **R11**, added 2026-09-10 with the variant amendment, is now the one
filed last.

---

### ⚖ R11 — ANSWERED. The minimum supported ngspice. Do we promise anything at all?

⚠ **THE EVIDENCE FOR THIS RULING WAS MEASURED AFTER IT, 2026-09-13: `evidence/binary-differences.md`.**
The two binaries differ in **four** measured places — the `v(all)` phantom column apt 45.2
writes beside a lone op save, the `meas` echo line's six decimals against five, XSPICE event
counts and transition times, and one `pss` return code — and **not one of them is a
capability the older binary lacks**. `sp`, `optran`'s numbers to every digit, seeded
randomness, all four `meas` readback facts, the `pss` four-argument segfault, `CKTncDump`,
XSPICE and CIDER all **agree**. So a version floor would have refused work that 45.2 does
correctly, which is the empirical form of the argument this ruling was answered on.


**✅ ANSWERED 2026-09-13 — Option C, the capability floor plus a stated tested set.** The
user's words: *"go with your recommendation"*. **All three conditions below are ratified with
it**, and they were restated when the ruling was put except condition 3's re-measurement
clause, which is inherited.

⚠ **OPTION A WAS NOT OFFERED TO THE USER AS LIVE**, because this entry already records it as
listed-to-show-why-rejected: a version floor requires the comparison **D44** forbids and gets
the stock-47/fork pair wrong **by construction**, since both answer `ngspice-46+`. Putting a
dead option in front of a ruling makes the choice look wider than it is.

⚠ **AND RE-MEASURING STRENGTHENED C RATHER THAN WEAKENING IT.** This entry's ground was that
apt **45.2** — what a downloading Ubuntu user gets, and still what is installed on this
machine (`apt-cache policy ngspice` → `45.2+ds-1`) — sits above every capability floor ASE-L
has. Still true. **But the eight stages since have measured that it is NOT identical to the
fork**: apt 45.2 writes a phantom duplicate column beside a lone operating-point save, and
issue **1434** emits a deck line specifically to work around it, gated on a measured
capability rather than a version. **So C's sentence describes something the project is
demonstrably already doing** — every measurement in Stages 1–8 was taken on both binaries for
exactly this reason — rather than an aspiration. A promise about **what we test** can be kept;
a promise about **what works** cannot, for archives nobody here has seen.

⚠ **THIS WAS THE LAST SINGLE RULING IN THE BATCH.** ⚖ R1–R8, R10 and R11 are answered. Only
⚖ **R9** remains, and it is the standing batched copy debt rather than a question.

*New 2026-09-10, with the variant amendment. **Blocks: one sentence** — the support statement in
the release note — **and Stage 16's mint.** Blocks nothing else, and it is filed LAST, behind
R10. The release note's **description** of what works on which binary is a measured finding and
ships without this ruling; only the **promise** waits here.*

#### The measured ground

* **Ubuntu 26.04.1 LTS ships ngspice 45.2** — `apt-cache policy ngspice` → `45.2+ds-1`, from
  `resolute/universe`, measured on this machine. That is the binary a downloading user will
  register, and **it is above every capability floor ASE-L has**: `usable 1`, `appendwrite 1`,
  `hier_op_names 1`, and every deck shape ASE-L emits today produces results byte-identical to the
  fork's (`evidence/fork-dependencies.md` §4.0, `evidence/fork-features.md` §3).
* **A version floor cannot be enforced honestly.** Stock upstream 47 and the fork both answer
  `ngspice-46+`; 47 is unreleased and still reports 46+; a distribution may backport a fix without
  moving the number. **Any runtime comparison against a version string is already wrong today**,
  before ngspice 48 exists (**D44**).
* **What Debian stable, older Ubuntu LTSs and Fedora ship was NOT measured.** One machine, one
  distribution, one version. Any floor stated as a number is a guess about other people's archives.

#### The options

* **Option A — a version floor, enforced.** Pick a number (say 44) and refuse below it.
  *Cost:* it requires exactly the comparison **D44** forbids, and it gets the stock-47/fork pair
  wrong **by construction** — they are the same string. It would also refuse a distribution-patched
  43 that works perfectly. **Listed so the crew can see why it was rejected, not as a live option.**
* **Option B — a CAPABILITY floor, enforced by the probe; no version anywhere.** The floor is
  `known 1 && usable 1`. Below it ASE-L **still starts and still runs**: it says the one sentence
  it already has (`cap_not_a_simulator` — *"produced no results at all when it was tried on a tiny
  test circuit"*) and gates everything off. Nothing is refused for being **old**; a thing is
  refused only for being **measured unable**.
* **Option C — Option B's mechanism, plus a stated support promise in the release note.** B decides
  what runs. The note says what we **test and will fix bugs against**, named as *binaries*, not
  versions: *"ASE-L is tested against the ngspice your distribution ships (45.2 on the current
  Ubuntu LTS), against stock upstream at the 47 tip, and against our own build. Older ngspice is
  not refused — it is measured, and ASE-L offers whatever it proves it can do."*

#### Trade-off

A buys a crisp sentence and a false one. B is honest, enforceable and costs nothing to maintain,
but on its own says nothing to a person deciding whether to download — *"it depends what your
binary can do"* is an unsatisfying answer on a project page. C is B plus the sentence, and the
sentence is about **what we test**, which is a promise that can be kept, rather than about **what
works**, which cannot be known for archives nobody here has seen.

#### Recommendation: **C**, with three conditions

1. **The floor is never a version comparison.** The support statement is prose in the release note;
   the gate is `known 1 && usable 1` in the code; the conformance suite greps for any ordering
   operator applied to a version string and reds if one appears (**D44**).
2. **Below the floor ASE-L runs, gated, and says why once.** Refusing to *start* over a binary
   measured only on a five-device test circuit is a bad trade — the measured worst case for the
   probe is a program that never answers, and that is a *slow* program, not an unusable one.
3. **The tested set is named as binaries and is re-measured when it moves.** Today it is exactly
   three and the receipts exist. When ngspice 47 releases, the row changes from *"stock upstream at
   the 47 tip"* to *"47"*.

#### The one thing the user is really being asked

**Not "how old is too old"** — the probe answers that per binary, and D43/D47 already settle what
happens on a binary nobody measured. It is: **do we promise anything at all?** C promises a *tested
set*; B promises nothing and measures everything. If the answer is *"promise nothing, it is a free
tool"*, B is coherent and cheaper. The recommendation is C because a project page needs one
sentence and C's sentence is true.

⚠ **NOT DECIDED. The user has not answered this.** ⚖ R1 and ⚖ R2 are answered (both 2026-09-10);
**⚖ R3 is ANSWERED (2026-09-12, Option C); ⚖ R4 is ANSWERED (2026-09-13, Option A); ⚖ R5 is the next one to ask**; R10 is filed after the table and this one after R10.
