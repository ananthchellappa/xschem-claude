# 62b — ADVERSARIAL VERIFICATION of ⚖ R10's adapter-author specification

**Subject:** `doc/claude/specs/ase_l_adapter_authors.md` (775 lines) and its own receipt
`doc/claude/ase_analyses_batch/receipts/62-r10-adapter-author-spec.md`.
**Method:** every number re-derived by my own extraction before comparing; every quoted literal
checked against `src/ase.tcl` and never against another document; every claim about another file
checked against that file. Nothing was built, run or simulated. One file written: this one.

**Headline:** the document is **substantially sound** — the central numbers are right, every
literal I could check is exact, and the four corrections it makes to the tree are real. It has
**one serious defect**: §5.2 hands the stranger an escape hatch, `{build <proc>}`, that the tree
**does not implement**, and the source says so in capitals in three places.

**Tally: 61 CONFIRMED · 5 REFUTED · 11 PARTLY.**

---

## 1 — THE NUMBERS, DERIVED INDEPENDENTLY BEFORE COMPARING

**My method, stated first.** (i) *Registered*: parsed the dict literal at `src/ase.tcl:31645-31699`,
taking the odd fields. (ii) *Required*: the `foreach` literal at `:686`. (iii) *Asked by core*:
stripped comment lines from `src/ase.tcl`, `src/rdw.tcl`, `src/ase_window.tcl`, `src/xschem.tcl`,
then extracted three patterns — `backend_hook <sim> <name>`, `conv_hook <sim> <name>`,
`dict exists $backends $<var> <name>` — then removed phantoms and added the continuation-split name.

| quantity | **my number** | crew's | verdict |
|---|---|---|---|
| hooks `register_backend` requires | **5** | 5 | **CONFIRMED** — `src/ase.tcl:686` |
| hooks the ngspice adapter registers | **53** | 53 | **CONFIRMED** — `:31645-31699` |
| of those, optional | **48** | 48 | **CONFIRMED** |
| distinct names core asks for | **51** | 51 | **CONFIRMED** |
| registered − asked | **{`op_param_enumerable`, `scripts_dir_of`}** | same | **CONFIRMED** |
| asked − registered | **∅** | ∅ | **CONFIRMED** |

Composition of my 51: 39 via `ase::backend_hook` + 11 reachable **only** via `ase::conv_hook`
+ `effective_emit` (name on the continuation line `:24732`). The driver's original figure of
**39** is now explained rather than merely refuted: **39 is exactly the `backend_hook` path with
the two phantoms removed.** It is a real number reached by a defensible method that stops one
path short.

### The three grep traps — one is misattributed

| trap | verdict | evidence |
|---|---|---|
| (a) comment lines match the call pattern | **CONFIRMED** (mechanism), **PARTLY** (attribution) | Comment prose does inflate a naive grep. But the `hook` phantom the receipt blames on comments actually comes from the **proc signature lines** `proc ase::backend_hook {sim hook}` (`:722`) and `proc ase::conv_hook {sim hook args}` (`:20982`) — it survives comment-stripping. My run reproduced it after stripping. |
| (b) `conv_hook` is the sole route to 11 names | **CONFIRMED** | `ncdump_parse ladder_rungs ladder_parse optran_line opstrategy_options opstrategy_arg_refusals opstate_lines opstate_arg_refusals runhealth_lines runhealth_labels runhealth_parse` appear in no other path. `src/ase.tcl:21011-21303`. |
| (b′) `dict exists` peeks "reach **6 more**" | **REFUTED as stated** | The 6 peek names (`capabilities`, `variant_notes`, `cosim_shim_verdict`, `lint_control_text`, `event_probe`, `event_inventory`) are **every one of them also resolved through `ase::backend_hook`** elsewhere. `comm -13 p1 p3` = empty. The peek path adds **ZERO** names to the 51. The *document* makes no numeric claim here and is clean; the **receipt §1 and the driver's brief are wrong** to present it as +6. The 51 is still 51 — the arithmetic that reaches it by 30+11+6 is wrong in two places that cancel. |
| (c) a continuation yields the phantom `tail` | **CONFIRMED** | `[namespace tail [namespace current]]` at `:3510` and `:24731`. |

### Set equality, checked by comparing sets and not by trusting arithmetic

`comm` between `registered − required` (48) and the hook names in §4: **exact equality, no
omissions, no extras** (only stray token `df7609c7`, a commit hash). **CONFIRMED.**

⚠ **Nuance the receipt does not state.** §4's **table** carries **46**; the other two live in the
trailing ⚠ paragraph. The section heading says "forty-eight of them, grouped" over a 46-row
table. Defensible, not wrong — but a reader counting the table gets 46.

### Other counts

| claim | verdict | evidence |
|---|---|---|
| eleven shipped analysis entries | **CONFIRMED** | `proc analysis_types` spans `:26489-27474`; 11 entries `op dc ac tran noise tf pz sens disto sp pss`. (A wider window catches `trigtarg find when …` — those are `meas_kinds` at `:27475`, a trap I fell into once.) |
| ngspice adapter "~8,100 lines" | **CONFIRMED** | `namespace eval ase::backend::ngspice` at `:23554`, file ends `:31699` → **8,146**. |
| hook history 8 → 23 → 53 | **CONFIRMED** | `DECISIONS.md:1573-1576` gives 8 (2026-09-10) and 23 (2026-09-13); 53 is today's, measured above. |
| "over a dozen places" for the no-fallback sentence | **CONFIRMED** | 15 occurrences of `no fallback` (case-insensitive) in `src/ase.tcl`. |
| "31.2 s with the interface frozen" | **CONFIRMED** | `src/ase.tcl:10389` — *"is executable and never answers is **31.2 s** with Tk frozen"*. |
| 25 ⚠ blocks | **CONFIRMED** | 25. |
| 8 `[NGSPICE-SHAPED]` marks | **CONFIRMED** | lines 38, 137, 373, 389, 408, 557, 744, 768. |

---

## 2 — EVERY QUOTED LITERAL, CHARACTER BY CHARACTER AGAINST `src/ase.tcl`

| # | quoted fragment | verdict | source |
|---|---|---|---|
| Q1 | `ase: backend '<name>' missing hook '<h>'` | **CONFIRMED** | `:688` |
| Q2 | `ase: unknown simulator '<sim>' (registered: <sorted names>)` | **CONFIRMED** | `:725` |
| Q3 | `ase: unknown hook '<hook>' for simulator '<sim>'` | **CONFIRMED** | `:728` |
| Q4 | `ase::analysis_unrenderable_msg` — **has no `backend`** | **CONFIRMED** | `:4706` `return "ase: analysis type '$type' is not one this simulator can render"` |
| Q5 | `predeck_deliver` no-fallback block | **CONFIRMED** | `:6905-6908` |
| Q6 | `run_stop_cost` clause block | **CONFIRMED** | `:17245-17250` |
| Q7 | `campaign_axis_kinds` block | **CONFIRMED** | `:21746-21751` |
| Q8 | `meas_needs_degrees` block | **CONFIRMED** | `:8581-8583` |
| Q9 | convergence-section header | **CONFIRMED** | `:20957-20958` |
| Q10 | the `⚠ AND EVERY OPTIONAL-HOOK RESOLVE…` block | **CONFIRMED** | `:5254-5258` |
| Q11-17 | all **seven** `analysis_state_msg` arms | **CONFIRMED** | `:10502-10521`, **both halves of every backslash continuation checked** |
| Q18-21 | all **four** `effective_report` verdict sentences | **CONFIRMED** | `:7860-7876`, continuations checked |
| Q22 | `This <type> analysis is not one this simulator can set up.` | **CONFIRMED** | composed from `:5512` (`status "This $type analysis $clause."`) + `:5480` (`unrenderable { return "is not one this simulator can set up" }`) |
| Q23 | `ase::requires_state`'s four-line grading table | **CONFIRMED** | `:10366-10375`, verbatim in behaviour |
| Q24 | the `op` descriptor, "verbatim" | **CONFIRMED** | `:27132-27138`, **byte-for-byte** |
| Q25 | `ase::ckpt_marker` "spells the three literals once" | **CONFIRMED** | `:9922-9929` (`ASE-RUN-COMPLETE`, `ASE-CKPT-ARMED`, `ASE-CKPT-DONE`) |

**§0.4's correction of `DECISIONS.md` is CONFIRMED.** `DECISIONS.md:1541-1542` holds
*"…is not one this simulator **backend** can render"*; `src/ase.tcl:4706` has no `backend`. The
crew found a live pre-edit literal in the batch's own decision log.

**Two notes, neither a defect:**
* The document normalises the source's ASCII `--` to an em-dash inside quotes. Consistent, cosmetic.
* `ase::effective_report` has a **fifth** string — the `⚠ neither read-back channel reported any
  stored option on this run…` preface (`:7879`). §7.3 says "the verdicts and the exact sentences"
  and gives four; the fifth is not a verdict. An omission, not an error.

**Q26 — one quoted-fact claim REFUTED.** §6.1: *"a stock build and a patched one print the
**byte-identical banner**."* What was measured is an identical **version string** and a
byte-identical **134-row command/help table** (`DECISIONS.md:816-818`); the banner's
`Creation Date` line **demonstrably differs** (`evidence/variants.md:491-496`). The *argument* —
a version string cannot tell the builds apart — survives intact; the word "banner" overstates it.

---

## 3 — THE FOUR CORRECTIONS THE DOCUMENT MAKES TO THE TREE'S OWN DOCUMENTS

| # | claim | verdict |
|---|---|---|
| C1 | `PLAN.md` §1a's contract block is stale; seven keys have zero shipped descriptors and zero core readers | **CONFIRMED in substance, PARTLY on phrasing** |
| C1a | `gated` → `baseline` with its sense inverted, C42, "the comment above `ase::requires_state`" | **CONFIRMED** |
| C1b | `notes`/`lint` shipped as `variant_notes` / `lint_control_text` | **CONFIRMED** |
| C2 | `ase_l.md` says twenty ids; the tree implements 27 | **CONFIRMED, exactly** |
| C3 | `register_backend`'s comment over-claims about `op_param_enumerable` | **CONFIRMED** |
| C4 | `requires` has two core readers and **zero implementations** | **REFUTED** |

**C1 detail.** All seven keys *are* specified in §1a (`PLAN.md:1156, 1159, 1184, 1186, 1187, 1224,
1232`), and **zero** shipped analysis descriptors carry them, and **zero** core procs read them
*from an analysis descriptor*. That is the substantive claim and it holds. But §0.1's phrasing —
*"Seven keys it specifies **do not exist anywhere in the tree**"* — is an **over-claim**, and its
sharpest counterexample is the very key the correction is about: **`gated` is live, shipped and
core-read on a `sim_options` catalogue row** — `ase::opt_gate_state` reads it at `src/ase.tcl:7400`,
and the `filetype` row at `:29723` carries `gated 1`. `fatal` is a live verdict tier (`:8413`),
`options` a live state key (`:538`), `notes` a live dict key (`:4266`). Only `verb`, `rules` and
`lint` are absent as keys anywhere. The qualifier "as descriptor keys" attaches grammatically only
to `notes`/`lint` and needs to govern the whole sentence.

**C2 detail.** `ase_l.md:618` lists exactly 20; `ase::needs_eval` implements exactly 27
single-pattern arms with no `default`; the difference is exactly the seven named
(`lin_points points_max setup_check stimuli_check tstart_note two_ports xspice`), and nothing in
`ase_l.md` is missing from the tree. The crew's own self-caught digit-class trap is real and I
avoided it independently (`disto_f1src`, `disto_f2src` both present).

**C4 — REFUTED, and this is the document's second-most-serious error.**
* Two readers: **CONFIRMED** — `ase::opt_gate_state:7412` and `ase::analysis_state:10458`.
* "Zero implementations": **FALSE.** The `filetype` option row at `src/ase.tcl:29723` carries
  `requires ::ase::backend::ngspice::requires_cider`, and `proc requires_cider {caps}` is
  implemented at `:29424`. **`requires` has a shipped first implementation.** It is true only of
  *analysis descriptors*, which is not what §5.5 says: *"It is a schema key with no first
  implementation. That makes it the one key in this document where you are the first author
  rather than the second."* A second author reading that will not go looking for the worked
  example that exists twenty lines from the catalogue they are about to copy.
* And §5.5's *"valid at three levels … so one evaluator reads all three"* is **REFUTED for the
  third level**: there is **no field-descriptor reader** of `requires`. Two levels, two readers.

---

## 4 — THE EIGHT `[NGSPICE-SHAPED]` MARKS

All eight present and each justified. Six are marks; line 38 defines the convention and line 768
is a back-reference.

| line | subject | justified? |
|---|---|---|
| 137 | `raw_file` / `result_probe` presume a single results file and a log | **YES** — `D37` (`DECISIONS.md:200-213`) predicts exactly this against Xyce |
| 373 | the emit token template presumes one positional command line | **YES** — `D37`'s *".control command word, never a dot card"* is verbatim |
| 389 | `plots`' `select` presumes a sequence of named plots | **YES** — `D37` names `.plotmap` and D30's destination as needing to be nameable without a rawfile |
| 408 | the `needs` vocabulary, "the largest unmarked ngspice dependency" | **YES, and correctly the strongest** — 27 ids in *core*, six named for ngspice internals (`noise_klu:12863`, `cider_klu:13322`, `pz_klu:12573`, `sens_filters:12690`, `disto_f1src:13262`, `xspice:13351`), **no hook to add one**, and `needs_eval` has no `default` arm so an invented id is silently satisfied (`:12203-12208`) |
| 557 | `$sim_status` | **YES** |
| 744 | `ase::default_simulator` returns the literal `ngspice` | **YES** — `:4780`, with the recursion reason and the carve-out both as the comment states |

### ⚠ THE HARDER THING: PLACES THAT SHOULD CARRY THE MARK AND DO NOT

**U1 — `run_cmd`'s contract is the deepest unmarked ngspice-ism in the document, and it is in the
required five.** §2.1 says `run_cmd` must return *"a Tcl `exec`-style command list"*, `log_file`
*"the path the run's log is written to"*, and `capabilities` takes `{exe exeargs workdir}` with an
absolute path to *"the program that will actually start"*. **The whole required-five table presumes
the simulator is a command-line program launched once per run, writing one log to a path.** A
simulator driven by a library binding, a persistent server, a socket or a job scheduler cannot
answer any of the three honestly. The mark at 137 covers only `raw_file` and `result_probe` —
the two *results* hooks — and leaves the three *launch* hooks unmarked. This is the same class of
finding the marks exist for, and it sits in the section a stranger reads first.

**U2 — `baseline`'s definition presumes compile-time feature selection.** §5.1: *"`1` when **every
build** of your simulator has this analysis; `0` when a **build flag** can remove it."* That is
ngspice's `#ifdef`/`--enable-*` world (the key was literally called `gated` for *"an `#ifdef` in
`commands.c` can remove it"*, `PLAN.md:1159`). A simulator whose features vary by **licence**, by
runtime plugin, or not at all has no natural answer. Unmarked.

**U3 — §7.2's `mislabel` arm is explained entirely through an ngspice artefact.** The `constants`
plot saturation (`src/ase.tcl:9643-9645`) is *"ngspice's own built-in plot"* (`:2983`). §7.2 is
under no mark. The *mechanism* (compare recorded name to `select`) generalises; the *worked
example* is pure ngspice and a reader may take the failure mode as universal.

**U4 — `si_suffixes` appears in §4's table with no caveat**, though `PLAN.md:562` (correction C37)
records that the tree's own number lexicon is **narrower than xschem's C parser**, which carries
Xyce's `x` = 1e6. A known, measured, simulator-divergent key listed as an ordinary menu row.

None of these is fatal. U1 is the one I would add a mark for.

---

## 5 — ⚠ THE MOST SERIOUS FINDING: `{build <proc>}` DOES NOT EXIST

§5.2 tells the adapter author:

> *"For the two shapes a token template cannot express, `emit` accepts `{build <proc>}` instead —
> which is the reason adapters are executable Tcl rather than data."*

and its `[NGSPICE-SHAPED]` block closes:

> *"If your simulator needs a block, a nested structure, or a separate file per analysis,
> `{build <proc>}` is your **escape hatch**."*

**REFUTED. The escape hatch is specified in `PLAN.md` §1c and was never built**, and `src/ase.tcl`
says so in three places, in capitals:

* `:5920` — *"a `{build <proc>}` slot (PLAN.md §1c, **specified and never shipped**)"*
* `:26576-26583` — *"⚠ TWO FIELDS, NOT THE PLAN'S FIVE, **BECAUSE THE `{build <proc>}` ESCAPE IS
  NOT IN THIS TREE**. … Stage 1 shipped `@x`, `@x?` and `@x!` and **no `build` arm**
  (`ase::analysis_expand`), so a `{build …}` token today is emitted as the **LITERAL WORDS**
  `build ase::backend::…`."*
* `:26743-26751` — *"THE `{build <proc>}` ESCAPE IS **STILL NOT IN THIS TREE**. … ⚠ **THE DECISION
  IS: DO NOT BUILD IT.**"*

I verified this independently rather than taking the comments' word:
* `ase::analysis_expand` (`:5072`) passes any non-`@` token through **as a literal**
  (`if {[string index $tok 0] ne {@}} { lappend res [list 1 $tok {}] ; continue }`). No `build` arm.
* A search for any core reader of a card-level or token-level `build` (`dict exists $card build`,
  `dict get $card build`) returns **nothing**.
* `ase::analysis_schema_errors` treats a card with no `tmpl` as the error token **`nocard`**
  (`:5558`) — so a card-level `{build <proc>}` is not merely ignored, it is *flagged as malformed*
  by the one checker §9 tells the author to run.

**Why this is the worst thing in the document.** It is the *only* place the document offers a way
out of the constraint it has just identified as most likely to break a non-ngspice simulator —
§5.2's own `[NGSPICE-SHAPED]` block. A second author whose analysis is a block rather than a line
follows the document to `{build <proc>}`, writes it, and gets the literal words
`build ::ase::backend::mysim::foo` emitted into their deck. That failure is silent at registration
(§2.2 is right that nothing validates), produces a deck the simulator rejects for a reason that
names nothing, and the document's own §11 advice — *"the source wins, read `register_backend` and
`backend_hook` first"* — points at the two procs that have nothing to do with it.

The honest sentence is: *the escape hatch is specified in `PLAN.md` §1c, is deliberately not built
(`src/ase.tcl:26751`), and needing it is itself the finding to report.* That is a stronger
statement of the document's own thesis than the one it prints.

---

## 6 — INTERNAL CONTRADICTIONS

**X1 — `results` is "enforced at registration" and also "registration validates nothing".**
§5.1: *"`results` | **yes — enforced** | … **No analysis may be registered without one** (**D30**)."*
§2.2: *"It does not validate your descriptors. **Registration cannot fail because an analysis entry
is malformed.**"* §2.2 is the true one. `ase::register_backend` (`:684-717`) checks five dict keys
and nothing else. **D30's "load-time error" was never implemented**: the only entry-level `results`
test in the tree is inside the `badplotroute` arm of `ase::analysis_schema_errors` (`:5659-5660`),
a **pure reader the document itself says is never called at load time** (§2.2, and `:5519-5523`).
There is not even a standalone missing-`results` token among the 26 that checker emits.
**Verdict: PARTLY — the requirement is real design (D30, `DECISIONS.md:513-519`), the enforcement
is not.** An author who trusts §5.1 will ship an entry with no `results` and learn nothing until a
plot route is walked.

**X2 — "The two errors it can raise" followed by one error** (doc lines 161-165). `register_backend`
raises exactly **one** shape. Either the count is wrong or a block is missing. **Editorial defect.**

**X3 — §8's "second column" is ambiguous in the one place ambiguity is expensive.** The table is
`| what | the older build | the newer build |`, so *"⚠ The second column is the one your users
have"* means **the older build** if columns are counted literally — which is **correct**
(`evidence/binary-differences.md:25`: *"the current Ubuntu LTS ships 45.2"*) and is confirmed by the
very next sentence. But a reader who counts *data* columns reads it as the newer build and takes
away the opposite of the truth, in a section whose entire purpose is to say *your users have the
build that dies*. **PARTLY — say "the first column" or name the build.**

**X4 — §8's "The campaign feature was verified on the newer build first" is asserted as history.**
The evidence states it **counterfactually**: *"a feature verified on the fork alone **would have**
exited 1 on every shard for most users. The design became *nominal deck plus a one-line diff per
shard* **because of this row**"* (`binary-differences.md:25`). The design changed *before* shipping
so that never happened. **PARTLY.**

**X5 — §5.4 attributes the precondition id bodies to `ase::analysis_needs`.** That proc
(`:12180-12200`) is a 21-line driver; the 27 id bodies are in **`ase::needs_eval`**
(`:12210-13417`). **PARTLY — a stranger following the pointer lands in the wrong proc.**

**X6 — §1's line hint `:20981` for `ase::conv_hook`.** The proc is at **`:20982`**. `:684`, `:722`
and `:5254` are all exact. Trivial, and §11 disclaims line hints — but it is the one hint that is
wrong.

**No contradiction found between the document and ⚖ R10.** `DECISIONS.md:1548-1600` records Option
B, the user's *"go with B — your recommendation"*, and the single-implementation-harness argument
the document's §0 and §9 reproduce faithfully. D30/D31/D34/D35/D36/D37/D44/D50 are all quoted or
paraphrased accurately; D35's *"a `build <proc>` emit for the two shapes a token template cannot
express (§1c)"* is the **origin of finding §5 above** — D35 cited it as a *reason for executable
Tcl*, which is exactly how §5.2 uses it, and neither noticed it was never built.

---

## 7 — WHERE THE DOCUMENT IS **WEAKER** THAN THE SOURCE PERMITS

| # | under-claim | what the source supports |
|---|---|---|
| W1 | §5.1 presents 16 descriptor keys as "the shipped key set … **This, not `PLAN.md` §1a, is the contract**" | **It omits `matrix`.** Shipped on the `sp` entry (`:27323`), read by core at `:5717` (its own error token `badmatrix`), `:6155`, `:6170`, `:6177`, `:6188`. A table that claims to be the contract and is missing a live key repeats §1a's own failure mode one generation later. |
| W2 | §9 Check 1 gives nine error tokens and a "…" | `ase::analysis_schema_errors` emits **26**: the nine plus `badmatrix badplotroute badplotwhen badplotwhenfield badplotwhenhook badresultvecs badsalvage badsalvagepoints badsetup badsetuphook badsetuplines badsetupmin nosalvagepoints nosalvagevector nosetupkey nosetuplines setupkeyclash`. Fourteen of the missing seventeen name the very keys §5.1 lists without explaining (`salvage`, `setup`, `resultvecs`, `matrix`) — so the checker is a better specification of those keys than the prose is, and the document never says so. |
| W3 | §7.1 says `ase::ckpt_marker` "spells the three literals once" and does not quote them | They are `ASE-RUN-COMPLETE`, `ASE-CKPT-ARMED`, `ASE-CKPT-DONE` (`:9924-9927`). The section tells the author to "emit the same markers" without saying what they are. |
| W4 | §7.2 names two verdicts (`under`, `mislabel`) | `ase::reconcile_plots` sets **six**: `norun`, `nomap`, `mislabel`, `under`, `over`, `predmismatch`, plus `aborted` (`:9708-9812`). `over` and `predmismatch` are as adapter-diagnostic as the two named. |
| W5 | §2.3 lists five dropped memos | Correct and complete — `:697-714` — but does not say the fifth (`event_inv_clear`) is wrapped in a bare `catch` because *"the cache is defined further down this file, after the first registrations some suites make"*. That is a load-order fact an adapter registering early will meet. |
| W6 | §10.6 calls two rows sharing a results key "not a designed feature" | `:25357-25359` states the rule outright: *"**RAW WINS A KEY CLASH.** Two rows can only share a results key by carrying the same `name`, which the Outputs pane does not offer; the order is **fixed here** so it is not an accident of dict traversal."* The precedence is documented and deliberate; the document could just say which wins. |

---

## 8 — THE ACID TEST: could a stranger register a minimal adapter from this alone?

**Yes for the five-hook minimum — and that is the document's real achievement.** §2.1 gives the
exact dict, every signature, every return; §2.2 says what is not checked; §3 makes "implement
nothing else" a supported destination rather than a shortfall; §2.1 points at a *working*
five-hook registration in the tree (`tests/headless/test_ase_core.tcl:2351`, section E2 —
**verified: it borrows four ngspice hooks and substitutes `run_cmd`**, exactly as described). I
could write that adapter from this document without opening `src/ase.tcl`.

**No for anything past it.** Four places a competent stranger stops:

**S1 — `fields` is named and never defined, and it is the gate to everything.** §5.1 says
*"`fields` | no | **ordered** list of field descriptors"* and the document **never says what a
field descriptor contains.** The shipped shape is
`{name <n> kind <k> required <0|1> label {…} default <v> values {…} depends <…> whenskipped <…>}`
(`:27145` onward), with eleven `ase::field_*` readers behind it (`:4853-9601`) and a `kind`
vocabulary (`source`, `real`, `int`, `mode`, `bool`, …) that is nowhere in this document. Yet
§5.2 requires a field per `@slot`, §9 Check 1's first two named error tokens (`noslotfield`,
`fieldunused`) are both about fields, and `ase::analysis_slots` is explained in detail. **An
author can register, and cannot write a single analysis with an argument.** This is the largest
gap in the document.

**S2 — `results` destinations are mandatory and their vocabulary is never given.** §5.3 says
*"`results` says **where its numbers go**"* and §5.1 marks it "yes — enforced", but the legal
`kind` values are never listed. The tree ships `opvectors`, `scalars`, `sweep`, `roots`, `params`,
`contributors`, `row`, `ent`, `name`. §5.1's cross-reference is to *"`ase_l.md`'s **State file
schema (v1)***", which does not contain them; `DECISIONS.md` calls the list "APPENDIX §6.2", a
section the document never resolves to a path. **The one mandatory key is the one whose values
are undiscoverable from here.**

**S3 — `salvage`, `stimuli`, `setup`, `resultvecs`, `requires` are given one line each and no
shape.** `salvage` gets `{points <proc> vector <name>}` — the only one of the five with a shape.
`stimuli` is "the estimate contract used to predict run length and arm checkpointing"; `setup` is
"fields consumed by setup legs rather than by a template". Neither names a key. The schema checker
has **nine** error tokens about `setup` alone. W2 above is the fix: point at the checker.

**S4 — the `[NGSPICE-SHAPED]` marks ask for complaints and never say where to send them.** §11
says *"file what you find"* and names `doc/claude/issues/NNNN-*.md` and `NUMBERING.md`. A stranger
outside this tree has no issue tracker, no clone, and no way to run the two-clone minting
procedure `NUMBERING.md` requires. The document's own §11 advice is unreachable by its stated
audience. **Say "open a GitHub issue" or "mail the maintainer" and the loop closes.**

**Terms used before definition:** `state dict` before §2.1's pointer (used at §2.1's table, defined
one paragraph later — fine); `role` (used in `emit`, §5.1 and §5.2, never enumerated); `sidecar`
(§7.2, never named as `<cell>_ase.plotmap`, `:8908`); `rung`/`ladder` (§4, never explained);
`shard` (§4 and §8, never defined). **`role` is the one that matters** — §5.1 says
*"`role analysis` is the card that makes the type renderable at all"* and never says what other
roles exist or what they do.

**WHAT without WHY** is rare — this is the document's strongest suit; §3, §5.3, §6.2, §6.3 and §8
are all mechanism-first. Two exceptions: §5.1's `viewrank` says *"coupling them was a defect once
and must not be re-established"* without naming issue **0964** (`:4741`, `:17797`), which is the
one thing that would let the author check; and §2.1's *"core passes two, so a third parameter must
have a default"* is correct (`:17040` `[$run_cmd $state $deckpath]`) but does not say why the
adapter's own `quiet` exists.

---

## 9 — ASSERTIONS I COULD FIND NO SOURCE FOR

Built independently; I did not consult the crew's list.

1. **`{build <proc>}` as a live escape hatch** (§5.2, twice) — §5 above. The only one that is
   actively contradicted by source.
2. **"`results` … No analysis may be registered without one"** (§5.1) — X1. Design, not behaviour.
3. **"a stock build and a patched one print the byte-identical banner"** (§6.1) — Q26. The version
   string is identical; the banner is not.
4. **"`requires` … no first implementation"** (§5.5) — C4. One exists.
5. **"valid at three levels … one evaluator reads all three"** (§5.5) — two levels, two readers.
6. **"The campaign feature was verified on the newer build first"** (§8) — X4. Counterfactual in
   the source.

Everything else I checked resolved. In particular these, which a reader would reasonably doubt,
are all **CONFIRMED**: the five caches dropped by `register_backend` (`:697-714`); row **A3** of
`test_ase_simcaps_0948.tcl:709-717` reading the loop's own source line and asserting it names the
five and not `capabilities`; `ase::run`/`ase::run_existing` pre-resolving only **four** of the five
(`:16620`, `:16637`); `ase::analysis_types` catching and falling back to `{}` **never to a literal
list** (`:4785-4796`); `ase::analysis_slots` stripping both `?` and `!` (`:5084-5090`); the key
being **`select`** and not `match` (zero `match` keys remain; `:5618`); `ase::caps_analysis_present`
answering `unknown` rather than `absent` when nothing was measured (`:10331-10344`);
`ase::analysis_state`'s renderable test sitting **above** the availability arms, with the comment
giving the same reason the document gives (`:10442-10447`); the `baseline`-absent-defaults-to-0
inversion and its C42 provenance (`:10346-10354`); `analysis_schema_errors` and its three siblings
being pure readers never called at load time, for the `Tcl_AppInit()` reason stated
(`:5519-5523`); `analysis_emit_check` returning **all** offences (`:5248-5251`); D50, D44, D30,
D31, D34–D37 all quoted accurately; and every one of the twelve PSS and nine binary-difference
figures in §6.3 and §8.

---

## 10 — VERDICT

**The document is sound and I am saying so plainly.** It is the best-sourced artefact I have
checked in this batch: 51 was right and I reached it by a different route; every one of 25 quoted
literals is exact, including both halves of every continuation; it caught a live pre-edit string in
`DECISIONS.md`; and its refusal to quote from any document but the source is what made that catch
possible. The §0 house-rule corrections are real findings, not throat-clearing.

**Fix these five, in order:**

1. **§5.2 — `{build <proc>}` is not implemented.** Say so, cite `src/ase.tcl:26751`, and make
   "you needed it and it is not there" the reportable finding. *(REFUTED — most serious.)*
2. **§5.5 — `requires` has a shipped implementation** (`:29723` / `:29424`) at the option-catalogue
   level, and **two** levels of reader, not three. *(REFUTED.)*
3. **§5.1 — `results` is not enforced at registration** (§2.2 is the truth), and the table **omits
   `matrix`**. *(Contradiction + under-claim.)*
4. **§2.1 — add a `[NGSPICE-SHAPED]` mark to the launch three** (`run_cmd`, `log_file`,
   `capabilities`), which presume a command-line program launched once per run. *(U1.)*
5. **§5.1 — define the field descriptor**, or point at `ase::analysis_schema_errors` as the
   specification of `fields`, `setup`, `salvage`, `resultvecs` and `matrix`. *(S1/S2/W2 — the acid
   test's real blocker.)*

Plus the cheap ones: §2.2's "two errors" shows one; §8's "second column" should name the build;
§5.4 should point at `ase::needs_eval`; `:20981` → `:20982`; §11 should give an outsider a way to
file.

**Nothing in this verification required a build, a test run or a simulator. `git status --short`
outside `doc/claude/ase_analyses_batch/receipts/` is unchanged by me.**
