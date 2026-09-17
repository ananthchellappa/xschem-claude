# ASE-L — writing an adapter for a simulator that is not ngspice

Status: SPECIFICATION — written 2026-09-16, ⚖ **R10** option B, paying `LEDGER.md` debt **M16**
Owner branch: fluid-editing
Related: `doc/claude/specs/ase_l.md` (the system spec — read its *State file schema (v1)*,
*What that program can actually do (issue 0948)*, *The one architectural rule* and
*Integration points* sections; this document does not repeat them),
`doc/claude/ase_analyses_batch/DECISIONS.md` (**D2**, **D30**, **D34**–**D37**, ⚖ R10),
`doc/claude/ase_analyses_batch/PLAN.md` §1 and §15,
`doc/claude/issues/1475-pss-declared-everywhere-working-nowhere.md`.

## Who this is for, and what it assumes

You own a simulator that is not ngspice and you want it to work inside ASE-L. You have never
read this codebase. You are not in the room with the people who wrote it, and you cannot ask
them anything.

You need to know Tcl. Adapters are **executable Tcl living in this tree** (**D35**) — there is
no manifest format, no sandbox, no declarative-data-only restriction. An adapter is exactly as
trusted as `src/ase.tcl` itself, and it may run arbitrary code. That decision was taken because
the useful parts of a descriptor — a `requires` predicate, a `salvage` point counter, a `setup`
leg that writes as many lines as the user's table has rows, a refusal evaluated
against the netlist — cannot be expressed in inert data. If a third-party adapter is ever
wanted, that is the moment to ask what it may execute; nothing here assumes it.

Everything in ASE-L is Tcl. There is no C to touch.

## How to read this document — and why it wants you to argue with it

⚖ **R10** chose this document over a conformance harness, and the reason governs how it is
written. A harness with **one** implementation behind it cannot tell the contract from the
implementation: run against ngspice it passes against ngspice, and codifies ngspice's shape
**as** the contract, with nothing able to disagree. Prose fails differently — *prose that is
wrong about a hook is wrong in a way a second author notices and complains about.*

**You are that second author.** So wherever something below is true only because ngspice
happens to work that way, it is marked:

> **[NGSPICE-SHAPED]** — this is an ngspice fact currently wearing a schema's clothes. If your
> simulator cannot do it, the schema is wrong, not you. Say so.

Those marks are the document's main safety mechanism, not a caveat on it. A schema with exactly
one implementation is a transcription of that implementation (**D37**), and every mark below is
a place where the transcription has not yet been tested.

**When this document disagrees with `src/ase.tcl`, the source wins**, and the disagreement is a
defect in this file. §11 says what to do about it.

---

## 0. Corrections — what writing this document found wrong in the tree's own documents

House rule: a refuted claim stays visible as a correction rather than being silently deleted.
All four were measured against `src/ase.tcl` at `df7609c7`.

1. ⚠ **`PLAN.md` §1a's key-by-key contract block is STALE and must not be used as the adapter
   reference.** Seven keys it specifies — `verb`, `gated`, `rules`, `fatal`, `options`, `notes`
   and `lint` — **have no analysis-descriptor reader**: zero shipped analysis descriptors carry
   them, and zero core procs read them *off an analysis descriptor*.
   ⚠ **That qualifier is load-bearing and an earlier draft omitted it, claiming the seven "do
   not exist anywhere in the tree".** They do, in other roles, and the sharpest counterexample is
   the very key this correction is about: **`gated` is live, shipped and core-read on a
   `sim_options` catalogue row** — `ase::opt_gate_state` reads it (hint `:7400`) and the
   `filetype` row carries `gated 1` (hint `:29723`). `fatal` is a live verdict tier, `options` a
   live state key, `notes` a live dict key, and `verb` a live proc parameter. Only `rules` is
   absent as a word anywhere. `gated` was renamed to `baseline` **and its sense
   inverted** (Stage 1 correction C42, the comment above `ase::requires_state`). `notes` and
   `lint` shipped as top-level registry hooks under different names (`variant_notes`,
   `lint_control_text`). **§5.1 below is the shipped key set.** This is ⚖ R10's own argument
   arriving as evidence: a contract written against a moving implementation goes stale, and the
   batch's own plan is the proof.
2. ⚠ **`ase_l.md`'s precondition vocabulary is twenty ids; the tree implements twenty-seven.**
   The seven it does not list are `lin_points`, `points_max`, `setup_check`, `stimuli_check`,
   `tstart_note`, `two_ports`, `xspice`.
3. ⚠ **`register_backend`'s own comment over-claims.** It says `op_param_set` and
   `op_param_enumerable` "are reached through `ase::backend_hook` like everything else". Measured
   across `src/` and `tests/`: `op_param_set` is (`src/rdw.tcl`, the results-display seam);
   **`op_param_enumerable` is never reached through the dispatch by anything** — the adapter calls
   its own proc directly. The same is true of `scripts_dir_of`. Both are registered hooks that no
   core reader asks for. See §4's last paragraph before you copy them.
4. ⚠ **`DECISIONS.md` ⚖ R9's quotation of the unrenderable refusal carries a word the shipped
   string does not.** It quotes *"…is not one this simulator **backend** can render"*. The
   literal in `ase::analysis_unrenderable_msg` has no `backend`. Every string quoted in this
   document was taken from `src/ase.tcl`, not from another document, for exactly this reason.

---

## 1. The shape, in one page

ASE-L owns the **schema**; your adapter owns the **content** (**D34**). Concretely:

* ASE-L knows that an analysis has a label, an emit template, form fields, plots, and a results
  destination. **It may not know a single sentence of your simulator's syntax.**
* You supply every value: which analyses exist, what their fields are called and in what units,
  what line to write into the deck, what the output plot is named, what a stop costs, what your
  binary can be measured to do.
* The two meet at a **registry entry** and at **named hooks**.

The naming rule is mechanical and it is how the split is enforced: `ase::…` is schema — readers,
one speller per surface, refusal evaluators, state keys. `ase::backend::<sim>::…` is content —
any proc that spells your syntax, encodes one of your traps, or enumerates your facts. A proc on
the wrong side is a defect in the *file table*, not a style preference (**D36**).

Three doors exist between them, and there are only three:

| door | what it is | where |
|---|---|---|
| `ase::register_backend <name> <hooks>` | you declare yourself, once | `src/ase.tcl`, *Backend registry* section (hint `:684`) |
| `ase::backend_hook <sim> <hook>` | core resolves one of your procs by name | hint `:722` |
| `ase::conv_hook <sim> <hook> ?args?` | the same, pre-wrapped in a `catch`, for one family | hint `:20982` |

Nothing else reaches you. There is no private path from core to a backend, and a stage that
needed one would have found a missing schema key — which is the finding, not the workaround.

---

## 2. Registering: five hooks, and that is the whole requirement

### 2.1 The five, with their signatures

```tcl
ase::register_backend mysim [dict create \
  render_deck  ::ase::backend::mysim::render_deck  \
  run_cmd      ::ase::backend::mysim::run_cmd      \
  log_file     ::ase::backend::mysim::log_file     \
  result_probe ::ase::backend::mysim::result_probe \
  raw_file     ::ase::backend::mysim::raw_file]
```

`ase::register_backend`'s required-hook loop names **exactly these five** and nothing else. Any
other key in the dict is carried straight through and becomes an optional hook.

| hook | called as | must return |
|---|---|---|
| `render_deck` | `$h $state $netlist_text` | the complete deck text your simulator will run |
| `run_cmd` | `$h $state $deckpath` | a Tcl `exec`-style command list. The ngspice one accepts an optional third `quiet` argument; **core passes two**, so a third parameter must have a default |
| `log_file` | `$h $state` | the path the run's log is written to |
| `result_probe` | `$h $state $logtext` | a flat `{key value …}` list of the scalar results named by the state's `outputs` |
| `raw_file` | `$h $state` | the path your results file will be at |

`$state` is the ASE-L state dict throughout — its schema is `ase_l.md`'s *State file schema (v1)*
section and this document does not restate it. Read values out of it with
`ase::state_get $state <key> ?default?`.

> **[NGSPICE-SHAPED]** — `raw_file` presumes there **is** a single results file, and
> `result_probe`'s second argument presumes the log text is where non-vector results live. A
> simulator writing one directory per analysis, or a database, has to answer `raw_file` with
> something, and today the honest answer is a path that core will then hand to readers expecting
> a rawfile. **D37** predicted this against Xyce and it has never been tested. If this is you,
> this is the first thing to complain about.

> **[NGSPICE-SHAPED]** — ⚠ **and the other three of the required five carry the same assumption,
> which is worse, because these are the first thing you read.** `run_cmd` must return a Tcl
> `exec`-style **command list**; `log_file` must return **one path** a log is written to; and
> `capabilities` is handed `{exe exeargs workdir}` where `exe` is *"the absolute path of the
> program that will actually start"*. **All three presume your simulator is a command-line
> program, launched once per run, writing one log file to a path.** Core calls them exactly that
> way — `[$run_cmd $state $deckpath]` and `[$log_file $state]`, one process, one log.
>
> A simulator that is a **library binding**, a **persistent server**, a **socket protocol**, or a
> job submitted to a **scheduler** cannot answer any of the three honestly. There is no
> "attach to a running session" hook and no "the run has no command line" answer; the least-bad
> shapes today are a wrapper script that *looks* like a one-shot program, and a `log_file` path
> you write the transcript to yourself. Both are fictions core cannot tell from the real thing.
> **If this is you, say so** — this mark and the one above it are the two places the required
> five stop being a schema and start being a description of ngspice.

**A working five-hook registration already exists in the tree** and is the cheapest thing to
read: `tests/headless/test_ase_core.tcl`, the `fakesim` registration in section E2. It borrows
four of ngspice's hooks and substitutes one of its own, which is also a legitimate way to start.

### 2.2 What `register_backend` does NOT check — read this before you debug

* It checks **only that the five keys are present in the dict.** It does not check that the
  named procs exist, that they are callable, or that they take the right arguments. A hook
  naming a proc you have not written yet registers perfectly and fails at call time.
* It does not validate your descriptors. Registration cannot fail because an analysis entry is
  malformed. The schema checkers in §9 are **pure readers you call on purpose**; they are
  deliberately never run at load time, because `ase.tcl` is sourced from inside `Tcl_AppInit()`
  and a raise there does not produce a dialog — it aborts xschem at startup with no layers,
  colours, menus or key bindings set up.
* It does not reserve your name. Registering a name that is already registered **replaces** the
  entry wholesale.

The **one** error it can raise is worth knowing by sight — it names the first missing hook, and
it is the only way registration can fail at all:

```
ase: backend '<name>' missing hook '<h>'
```

(The *two* errors an adapter author meets more often are `ase::backend_hook`'s, and they are in
§3.1. Do not confuse them: these fire at registration, those at every call site.)

### 2.3 Registering twice, and the memo problem

Several core readers cache your hook's answer **keyed on your backend name** — the analysis
registry, the measurement kinds, the convergence rung catalogue, the campaign axis kinds, the
event inventory. Re-registering `<name>` is the one event that changes what those answers should
be, so `ase::register_backend` drops every one of those memos as part of registering.

This matters to you in one situation: if you build your hooks dict incrementally and register
more than once during development, **the caches are handled for you**. If you instead mutate
`::ase::backends` directly, they are not, and you will spend an afternoon looking at a stale
analysis list. Do not mutate it directly.

> ⚠ **Do not add a sixth name to that required-hook loop.** Row **A3** of
> `tests/headless/test_ase_simcaps_0948.tcl` reads that loop's own source line and asserts it
> names exactly the five and does **not** name `capabilities`. Anything added inside the loop is
> read by that row as a sixth required hook and it reddens. The rule it protects is the one in
> §3: a backend must be able to register without writing a probe, an operating-point reader, or
> anything else.

---

## 3. The governing rule of the whole contract: no hook, no content

**A backend with no hook gets NO fallback content** (**D34**/**D36**). Not a default, not a best
guess, not ngspice's answer borrowed. This sentence appears in over a dozen places in
`src/ase.tcl` and it is the single idea this document exists to convey:

> *"⚠ A BACKEND WITH NO HOOK GETS NO FALLBACK CONTENT (D34/D36). `.spiceinit` is an ngspice
> filename and the banner is ngspice comment syntax; core knows neither."* — above
> `ase::predeck_deliver`

> *"⚠ THE CLAUSE IS THE ADAPTER'S AND THERE IS NO FALLBACK SENTENCE. If a backend declares no
> `run_stop_cost` hook, ASE-L says nothing at all rather than guessing … Silence is the honest
> answer; a wrong warning is not."* — above `ase::run_stop_cost`

> *"⚠ A BACKEND WITH NO HOOK GETS NO FALLBACK CONTENT (D34/D36). The axis kinds a simulator can
> deliver, and HOW, are facts about that simulator … Core owns the odometer, the directory, the
> index and the sampler and knows none of it."* — above `ase::campaign_axis_kinds`

> *"THE ANSWER IS THE ADAPTER'S, and there is no fallback: whether `vp()` comes back in radians
> is a fact about one simulator, and a core that guessed it would be wrong for the next one in
> exactly the direction that stays silent."* — above `ase::meas_needs_degrees`

> *"a backend that declares none of them gets NO convergence content at all — every reader here
> answers `{}` and every feature then refuses rather than guessing."* — the convergence section
> header

**What this means for you, and it is the opposite of what an integration usually means.** Not
implementing a hook is a **safe, supported, permanent choice**. It is not a hole to be filled
before shipping and it is not a degraded mode. The feature that hook serves simply does not
appear, and the surface that would have shown it says nothing — never something wrong.

Four consequences worth internalising:

1. **You can register and be genuinely useful with five hooks.** You get netlisting, deck
   generation, running, logging and results. Everything else is additive.
2. **Silence is a designed answer, not an error path.** `ase::run_stop_cost` returning `{}`
   means the Stop button says nothing about what a stop costs. That is correct behaviour for a
   simulator nobody has described, and it is better than a sentence invented for ngspice's run
   model.
3. **You are never obliged to lie to fill a key.** If your simulator has no concept a hook is
   about, do not implement the hook. An adapter that answered "0" to a question it cannot answer
   would be worse than one that stays absent, because absent is distinguishable and 0 is not.
4. **Adopt incrementally, in any order.** There is no dependency graph among the optional hooks
   and no "phase 2". Add `analysis_types` when you want the analyses grid; add `capabilities`
   when you want measurement rather than assumption; never add `campaign_axis_kinds` if you do
   not want campaigns.

### 3.1 The dispatch idiom — how to read any call site

`ase::backend_hook` raises a clean Tcl error for **both** an unknown hook and an unknown
simulator:

```
ase: unknown simulator '<sim>' (registered: <sorted names>)
ase: unknown hook '<hook>' for simulator '<sim>'
```

Because an absent optional hook **raises**, every optional-hook resolve at a call site is
wrapped in a `catch`. The tree states the rule explicitly, above `ase::analysis_emit_check`
(hint `:5254`):

> *"⚠ AND EVERY OPTIONAL-HOOK RESOLVE GOES INSIDE A `catch`. MEASURED in source:
> `ase::backend_hook` RAISES both for an unknown hook AND for an unknown simulator;
> `ase::analysis_types` survives only because it wraps the lookup in its own catch. A call site
> written to 'it falls back' raises instead of answering — and this one runs on the Run path."*

So an optional-hook call site looks like exactly one of these three shapes, and once you can
read them you can read every one in the file:

```tcl
# Shape A — the common one. `{}` survives an absent hook.
set r {}
catch {
  set h [ase::backend_hook $sim run_stop_cost]
  if {$h ne {}} { set r [$h] }
}
return $r

# Shape B — the pre-wrapped helper, used by the convergence family.
return [ase::conv_hook $sim ladder_parse $text]

# Shape C — the "does it declare one at all" peek, no call.
variable backends
return [expr {[dict exists $backends $sim variant_notes] ? 1 : 0}]
```

Shape C exists because "did the adapter describe this?" and "what did the adapter say?" are
different questions, and a surface often needs the first without paying for the second.

The **five required** hooks are resolved **without** a catch, deliberately: `ase::run` and
`ase::run_existing` resolve them up front so an unknown simulator errors before any netlisting
or file I/O happens. (Note that those two pre-resolve only four of the five — `raw_file` is not
in that list. Harmless, since a missing `raw_file` cannot be registered, but do not read the
list as normative.)

---

## 4. The optional hooks — forty-eight of them, grouped

Measured at `df7609c7`: the ngspice adapter registers **53** hooks (the five required plus 48
optional), and core asks for **51** distinct hook names by literal across the three resolution
paths of §1.

Do not read this table as a to-do list. Read it as a menu in which every row is independently
optional, and in which the rows most simulators will want are in the first two groups.

| group | hooks | what you get by implementing them |
|---|---|---|
| **Analyses** (start here) | `analysis_types`, `analysis_caveat`, `analysis_suppress` | the Choose Analyses grid, per-type forms, the emitted line in the Arguments column. `analysis_types` is the single highest-value optional hook in the system — §5 is entirely about it |
| **Capability** | `capabilities` | measured answers instead of assumptions; the Detect button; the four-state grid. §6 |
| **Deck & syntax** | `si_suffixes`, `deck_keywords`, `out_decompose`, `dc_swkind`, `predeck_write`, `lint_control_text` | numeric suffix parsing, keyword awareness in hand-edited text, decomposition of an output expression, classification of a sweep target, a pre-deck settings file, warnings over user-supplied control text |
| **Options** | `sim_options`, `option_spell`, `option_fallback`, `option_restore_spell`, `effective_emit`, `effective_lookup` | the option catalogue, one speller per surface, and the requested-versus-effective read-back of §7 |
| **Measurements** | `meas_kinds`, `meas_analyses`, `meas_rule`, `meas_needs_degrees`, `meas_templates`, `meas_template_derive` | the Value column rows a user switches tools for |
| **Campaigns** | `campaign_axis_kinds`, `campaign_control_lines`, `campaign_seed_option`, `campaign_seed_range`, `campaign_seed_notes`, `campaign_axis_refusals` | sweeps, corners, Monte Carlo. Core owns the odometer, the shard directory, the index and the sampler; you own what a shard's deck says |
| **Convergence & run health** | `ncdump_parse`, `ladder_rungs`, `ladder_parse`, `optran_line`, `opstrategy_options`, `opstrategy_arg_refusals`, `opstate_lines`, `opstate_arg_refusals`, `runhealth_lines`, `runhealth_labels`, `runhealth_parse` | the non-convergence table, the strategy ladder, run-health counters. All reached through `ase::conv_hook` |
| **Events / co-simulation** | `event_probe`, `event_inventory`, `xspice_caveat`, `cosim_shim_verdict` | mixed-signal event data and a verdict about a co-simulation shim |
| **Run model** | `run_stop_cost`, `variant_notes` | what a Stop costs this run; the one-line per-binary sentence |
| **Results display** | `op_param_set` | the operating-point parameter seam in `src/rdw.tcl` |

⚠ **Two registered hooks are never asked for through the dispatch by anything** —
`op_param_enumerable` and `scripts_dir_of`. Both are called by the ngspice adapter **on itself**,
by direct proc call. They are in the registration dict because a comment says they ride there, and
the comment over-claims (§0.3). **Do not implement them expecting core to call them.** If you want
their behaviour you must also find their caller, and their caller is inside the ngspice adapter.

---

## 5. The analysis descriptor — the hook that is worth the most

`analysis_types` takes **no arguments** and returns a dict of `type → descriptor`. Core caches
the answer per backend name and drops the memo when you re-register.

`ase::analysis_types` is itself wrapped in a catch and falls back to `{}` — **never to a literal
list**. That is deliberate and it is worth understanding: a literal fallback would be another
copy of "what is a dc analysis", and it would be the copy nobody greps for.

### 5.1 The key set, as shipped

Verified across the eleven entries the ngspice adapter ships and against the core procs that read
them. **This, not `PLAN.md` §1a, is the contract.**

| key | required | meaning |
|---|---|---|
| `label` | yes | display noun. **USER-FACING** — in this tree every new user-facing sentence is the user's to ratify, so a new label is a question, not a decision |
| `emit` | yes | list of cards, each `{role <r> tmpl <token template>}`. `role analysis` is the card that makes the type renderable at all |
| `baseline` | effectively | `1` when **every** build of your simulator has this analysis; `0` when a build flag can remove it. ⚠ **An absent `baseline` defaults to 0**, and the default is the safe direction — see §6.2 |
| `registered` | yes in practice | `1` to offer the type in the GUI. Lets a half-built entry land in one commit and be switched on in the next |
| `fields` | no | **ordered** list of field descriptors — **defined in §5.1b, which you need before you can write an analysis that takes an argument**. ONE list serving THREE roles: form order, Arguments-column order, emit slot order. Two lists is exactly how a key once drifted between three places (**D31**) |
| `results` | **by design, NOT enforced** | destination map; shape in §5.1b. **D30** says no analysis may be registered without one — that is how "a scalar goes in the Value column and a waveform does not" stops being remembered — but ⚠ **nothing enforces it at registration**; see §5.3 |
| `matrix` | no | command prefix answering a result *grid* (ngspice's `sp` ships the only one). Mistype the proc name and `ase::analysis_matrix` silently answers `{}`; the schema checker's `badmatrix` is what tells you |
| `plots` | no | list of `{select <glob on the plot name> role <r> results <dest> label <s>}`, optionally `when <pred>`. The key is **`select`**, not `match` |
| `needs` | no | precondition ids, evaluated before the run. §5.4 |
| `emitorder` | no | ascending integer. The order cards are written into the deck |
| `viewrank` | no | which analysis the waveform window opens on when several ran. **Separate from `emitorder` on purpose** — coupling them was a defect once and must not be re-established |
| `seed_enabled` | no | whether a campaign seed applies to this type |
| `resultvecs` | no | `own` when the type names its own result vectors |
| `salvage` | no | `{points <proc> vector <name>}` — how a stopped run's partial output is counted |
| `stimuli` | no | the estimate contract used to predict run length and arm checkpointing |
| `setup` | no | fields consumed by setup legs rather than by a template |
| `requires` | no | a three-valued predicate — **see §5.5** |

The shortest real entry in the tree, verbatim:

```tcl
op [dict create \
  label op  baseline 1  registered 1  seed_enabled 1  emitorder 0  viewrank 10 \
  needs  {saves_resolve} \
  fields {} \
  emit   {{role analysis tmpl {op}}} \
  results {value {kind opvectors}} \
  plots  {{select {Operating Point} role scalars results value label op}}]
```

### 5.1b The field descriptor and the results destination — what §5.1 names and must define

⚠ **An earlier draft named `fields` and `results` in the table above and defined neither.** The
measured consequence was that a stranger could register the five-hook minimum from this document
and **could not write a single analysis that takes an argument.** Both are defined here.

**A field descriptor is a flat dict.** Every key core reads off one:

| key | what it does |
|---|---|
| `name` | the slot name; `@<name>` in a template fills from this field |
| `kind` | which widget the form builds — and see the ⚠ below, because it is mostly not core's |
| `required` | `1` makes `ase::analysis_emit_check` report `missing` when the row has no value |
| `label` | the caption. **USER-FACING**, so a new one is the user's to ratify, not yours |
| `labels` | per-mode captions, when a neighbouring `mode` field relabels this one |
| `relabels` | on a `mode` field: the name of the field whose caption this one rewrites |
| `unit` | appended to the caption in parentheses, and kept in refusal sentences |
| `default` | used when the row stores none — **and it is what the deck emits**, so a precondition must reason about it too |
| `values` | the legal set, for a `mode` field's picker |
| `valuelabels` | display word → stored deck word. Both directions fall back to identity |
| `min` | a numeric floor |
| `depends` | `{<other field> <value>}`, **exactly two elements**. Unsatisfied, the field emits **nothing** — checked *before* the default |
| `whenskipped` | what a skipped positional slot contributes instead |
| `when_true` / `when_false` | `kind bool` only: the word emitted for on / for off |
| `advanced` | `1` puts it behind Advanced |
| `group` | a caption for a set of advanced fields |

⚠ **`kind` is the FORM's vocabulary far more than core's.** Shipped values are `real`, `int`,
`freq`, `time`, `bool`, `mode`, `source`, `node`, `outvar`, `filter` — but the form's switch has
arms for only `bool` (a checkbutton) and `mode` (a combobox) and **a `default` arm that builds a
plain entry box for everything else, deliberately**, so a kind nobody has heard of still produces
a usable control rather than no control at all. The only kind *core* acts on is `bool`:
`ase::field_emits` emits your `when_true` word when the row says exactly `1` and **never the
stored `0`**, because a simulator may have no way to spell "off". **So inventing a `kind` is safe
and buys you nothing** — it is a request for a widget, and an unrecognised request gets a text box.

**A results destination is `{<dest> {kind <k>}}`, and the two halves are not equal:**

* **The destination NAME is the contract, and it is checked.** `plots` rows point at it by name
  (`results viewer`), and `ase::analysis_schema_errors` reports `badplotroute` when a plot names
  a destination its own entry never declares. Shipped names: `value` (the Value column), `viewer`
  (the waveform window), `table` (a result table) — plus the literal `none`, which is the **only**
  legal destination for a `role opinfo` plot and is refused for every other role.
* ⚠ **The `kind` inside it is read by NOTHING today.** Measured across `ase.tcl`,
  `ase_window.tcl` and `rdw.tcl`: each of `opvectors`, `scalars`, `sweep`, `roots`, `params` and
  `contributors` occurs **only inside the ngspice descriptor literal itself.** No core reader
  consumes it. So there is no vocabulary to conform to, and no checker that will notice you
  invented one. **Copy the nearest shipped kind and treat it as documentation for the next
  reader, not as a switch.** If you need the kind to *mean* something, that is a missing reader
  and it is the finding.

**The minimal analysis that takes an argument and produces a readable result** — the thing §2.1's
five-hook registration cannot yet do:

```tcl
proc ::ase::backend::mysim::analysis_types {} {
  return [dict create \
    tran [dict create \
      label tran  baseline 1  registered 1  emitorder 0  viewrank 10 \
      fields  {{name stop kind time required 1 label {Stop time} unit s}} \
      emit    {{role analysis tmpl {tran @stop}}} \
      results {viewer {kind sweep}} \
      plots   {{select {Transient Analysis} role sweep results viewer label tran}}]]
}
```

That renders `tran 1u` from a row storing `stop 1u`. Swap the last two lines for
`results {value {kind scalars}}` and
`plots {{select {...} role scalars results value label tran}}` and the numbers land in the Value
column instead. **Four rules that entry obeys**, each an error token if you break it: every
`@slot` has a field of that name (`noslotfield`); every field is spent by a template, by another
field's `depends`, or by a `setup` leg (`fieldunused`); every `plots` row carries `select`, `role`
and `results` (`noplotselect` / `noplotrole` / `noplotresults`); and the destination a plot points
at is declared in the entry's own `results` (`badplotroute`). `ase::analysis_schema_errors mysim`
tells you which — see §9 Check 1.

### 5.2 The emit token template

A template is a Tcl list of tokens. A token beginning `@` is a **slot** filled from the field of
that name; everything else is literal. Two suffixes modify a slot: `?` and `!`. `ase::analysis_slots`
strips both when enumerating slot names, so the field is named without its suffix.

```tcl
emit {{role analysis tmpl {tran @step @stop @tstart? @tmax? @uic!}}}
```

⚠ **THERE IS NO ESCAPE FROM THE TOKEN TEMPLATE, AND AN EARLIER DRAFT OF THIS DOCUMENT TOLD YOU
THERE WAS.** `PLAN.md` §1c specifies a `{build <proc>}` form for the shapes a token template
cannot express. **It was never built, and the decision is not to build it** — `src/ase.tcl` says
so in capitals above the `sens` entry: *"⚠ **THE DECISION IS: DO NOT BUILD IT**"* (hint `:26751`),
with the reason at `:5920` (*"specified and never shipped"*) and `:26576` (*"the `{build <proc>}`
escape is **not in this tree**"*).

**What happens if you write it anyway — and this is why it matters.** Nothing refuses you.
`ase::analysis_expand` has no `build` arm: its first act on each token is
`if {[string index $tok 0] ne {@}} { lappend res [list 1 $tok {}] ; continue }`, so a
`{build ::ase::backend::mysim::foo}` **token** is passed through as **the literal words** and
lands in your deck as `build ::ase::backend::mysim::foo`. A `{build <proc>}` written as a whole
**card** — `emit {{build <proc>}}`, which is what the sentence this paragraph replaces implied —
is worse in a quieter way: `ase::analysis_schema_errors` sees a card with no `tmpl` and reports
the token **`nocard`**, so the only checker §9 tells you to run calls your entry malformed
without saying why. Neither failure names `build`, and registration accepts both silently (§2.2).

**What to do instead.** The constraint is real and has no bypass today, so:

* If you need a **variable number of lines around** the card, that is the `setup` contract, not
  `emit` — it is the shipped answer to exactly this problem (ngspice's `sp` promotes N ports from
  inside `.control`, where N is the length of a table the user filled in). Its `lines` and `post`
  procs are adapter Tcl called as `<proc> $state $row $idx`. See §5.1's `setup` row.
* If you need to **compose one token out of several fields** — `v(a,b)` out of four — the tree's
  own answer is to ship the composed token as **one** field and to register an `out_decompose`
  hook that takes it apart again for any surface that wants the parts. That is what
  `:26751`'s decision rests on: composition buys nothing a reader does not already give.
* If neither fits, **you have found the finding.** Report it (§11) rather than working around it;
  needing the escape is a stronger statement of this document's thesis than the escape would be.

> **[NGSPICE-SHAPED]** — the whole template idea presumes an analysis is **one command line
> with positional arguments**, and `ase::analysis_card_tmpl`'s notion of a `role analysis` card
> presumes there is one such line per analysis. **D37** flagged this against Xyce, which has no
> interactive control language at all: *"an analysis is a `.control` command word, never a dot
> card"* is an ngspice fact currently wearing a schema's clothes. If your simulator needs a
> block, a nested structure, or a separate file per analysis, **there is no escape hatch** — see
> the ⚠ above. `setup` buys you extra lines *around* the card; it does not buy you a different
> shape *for* the card. This is the mark most likely to be the one that breaks, and the first
> one to complain about.

### 5.3 `plots` and `results` — mandatory by design, unenforced in fact

`plots` says how to recognise the output your analysis produced; `results` says **where its
numbers go** (shape in §5.1b). A destination is not "the waveform viewer" for most analyses:
scalars belong in the Value column, some analyses produce a result *table*, and only sweeps are
traces. **D30** makes a registry entry without a `results` destination an error precisely so this
stops being something the next author has to know.

⚠ **BUT "mandatory" IS A DESIGN STATEMENT AND NOT A BEHAVIOUR, AND §5.1 CLAIMED OTHERWISE UNTIL
THIS CORRECTION.** D30's load-time error **was never implemented.** `ase::register_backend`
checks five hook keys and nothing else (§2.2), so **an entry with no `results` registers
perfectly.** The only entry-level `results` test anywhere is inside
`ase::analysis_schema_errors`' `badplotroute` arm — a **pure reader you must call on purpose**,
never run at load time — and there is not even a standalone missing-`results` token among the
26 it emits. An author who trusts the word "enforced" ships an entry with no destination and
learns nothing until a plot route is walked, which may be months. **Call the checker (§9 Check 1);
nothing else will tell you.**

> **[NGSPICE-SHAPED]** — `plots`' `select` is a glob matched against the **plot name literal**
> your simulator writes, and the reconciliation of §7 compares recorded names positionally
> against a sidecar. Both presume your results file is a sequence of named plots. If yours is
> not, `results` still has to be nameable without a rawfile underneath it — **D37** says so in
> as many words, and nothing has tested it.

### 5.4 `needs` — preconditions, and who owns which half

`needs` names precondition ids. They are evaluated before a run against facts read from the
netlist xschem itself emits, and each returns one of three tiers: `fatal` refuses the run,
`caution` advises and lets it proceed, silence means nothing is known to be wrong.

⚠ **The tier is the decision, not the detection** — and this is the one place where the
schema/content split is genuinely blurred. The **evaluator** is core's — `ase::analysis_needs` is
a short driver, and ⚠ **the twenty-seven id bodies are in `ase::needs_eval`, which is where to go
looking**; an earlier draft pointed only at the driver, and a stranger following that pointer
lands in twenty-one lines that contain none of the ids. Both are core's: **twenty-seven ids are
implemented inside `src/ase.tcl`**, and several
are named for ngspice internals (`noise_klu`, `cider_klu`, `pz_klu`, `sens_filters`,
`disto_f1src`, `xspice`). Each returns `{tier sentence remedy}`, and the *sentences* are the
adapter's words even though they sit in a core proc.

> **[NGSPICE-SHAPED]** — **this is the largest unmarked ngspice dependency in the system.** The
> precondition vocabulary is not extensible by an adapter today: there is no hook that lets you
> add an id, and `needs` ids you invent will simply not match any arm and evaluate to silence.
> **If you want preconditions of your own, that is a missing hook, and it is the finding.**
> Until then, omit `needs` entirely — silence is a correct answer (§3).

⚠ And note the standing judgement inside that machinery, because it will bite you the same way:
the netlist reader answers `exact 0` — a hierarchical node inside an included subcircuit is
unresolvable to it and perfectly resolvable to the simulator. That blind spot is why the
save-resolution precondition is `caution` and not `fatal`: **a false refusal is worse than a
missed one.** Choose your tiers with that asymmetry in mind.

### 5.5 `requires` — one evaluator, two levels, and a worked example twenty lines from the catalogue

`requires` is a command prefix answering a **three-valued** question about your own facts:
`present` / `absent` / `unknown`. It is valid at **two** levels with identical semantics — on a
registry entry and on an option-catalogue row — and one evaluator reads both.
⚠ **An earlier draft said three levels, adding a field descriptor.** There is **no
field-descriptor reader** of `requires`: two levels, two readers, and a `requires` written on a
field is read by nothing at all. `ase::requires_state {req caps baseline}` grades the answer:

```
present  -> {state ok     reason measured}
absent   -> {state absent reason notbuilt}
unknown  -> baseline ? {state ok     reason baseline}
                     : {state absent reason unmeasured}
raised   -> {state caution reason requires_raised}
```

⚠ **The predicate never starts the simulator.** `caps` arrives as an **argument**, already in
hand; a predicate that measured for itself would put a multi-second freeze behind every form the
user opens.

⚠ **There IS a shipped implementation, and an earlier draft of this document said there was not
— which would have sent you past a worked example sitting twenty lines from the catalogue you
are about to copy.** The ngspice adapter's `filetype` option row carries
`requires ::ase::backend::ngspice::requires_cider`, and `proc requires_cider {caps}` is
implemented in that adapter. It is the honest shape for the hardest case: a catalogue row whose
**very existence** is a build option, answering `unknown` rather than guessing when nothing was
measured.

What is true is narrower: **no shipped *analysis* descriptor uses `requires`** — the analyses
reach the same question through `baseline` plus the capability probe (§6.2). So at the
option-catalogue level you are the second author and there is an example to read; at the
analysis-descriptor level you are the first, and that is worth reporting either way.

---

## 6. Capabilities: declare, never infer, never prune

### 6.1 The `capabilities` hook

```tcl
proc capabilities {exe exeargs workdir} { … }
```

Called as `$h $resolved $eargs $wd`, where `$resolved` is the **absolute path of the program
that will actually start** — never a bare name. Return a dict. The vocabulary is
`ase_l.md`'s *What that program can actually do (issue 0948)* section and is not repeated here;
the three rules that bind an adapter are:

1. **The method is a probe run, never a version string.** Measured in this tree: a stock build
   and a patched one print the **identical version string** — both say `ngspice-46+`, because
   both trees' `configure.ac` declares it and the patch never touched it. ⚠ **Not a
   byte-identical banner**, which an earlier draft claimed: the banner's `Creation Date` line
   differs, and it is the timestamp of whoever last ran `make` rather than an identity — rebuild
   the stock one tomorrow and it is *newer* than the patched one. That is the argument, sharpened
   rather than weakened: the one field that differs is the one that means nothing.
   **D44** forbids any ordering comparison
   applied to a version string anywhere, and a test row greps the tree for one.
2. **The verdict is the RESULT, never the exit code and never the log.** Every answer is read
   out of the results file the probe's own deck asked for.
3. **Absent is not zero.** When `known` is 0 the capability keys are **absent**, not 0. Absent
   means nobody measured; 0 means measured-and-no. A reader can tell those apart and must be
   able to.

⚠ **Never run a probe that crashes the user's simulator** (**D50**). If the only way to
establish a capability is to trigger the defect, the capability is established by construction
from what you know about your own build, or not at all.

### 6.2 The four-state grid, and the safe default

`ase::analysis_state` joins three things — can the adapter emit this type at all, does this
build have it, does the netlist support it — into one cell. The renderable test sits **above**
the availability arms deliberately: a type your adapter cannot emit is `blocked` whatever the
binary says, because offering it would produce a run that emits nothing.

The sentences the user reads are ASE-L's frames; a `caution` cell's clause is yours, quoted
verbatim from `analysis_caveat`. Quoted exactly as shipped:

```
Offered because every build of this simulator has it. Nothing was measured.
This build cannot run <label> -- the simulator was asked and does not have it.
Nothing has been measured about this simulator yet. Press Detect to ask it which analyses it can run.
Nothing can be measured about this simulator, so ASE-L cannot tell whether it has <label>.
ASE-L cannot set up <label> yet, so it is listed but cannot be enabled.
ASE-L could not work out whether this simulator has <label>.
<label> will run, but <clause>.
```

⚠ **`baseline` absent defaults to 0, and the default is inverted from what the plan specified.**
The key was once called `gated` and meant "an `#ifdef` could remove this". Renaming it flipped
what an **absent** key must mean. With the default at 0, an adapter that cannot assert a
source-verified invariant gets every unmeasured capability resolving to `absent/unmeasured` —
offered nowhere — rather than to `ok/baseline`, **which would offer analyses nobody verified.**
Set `baseline 1` only where you can assert it about every build of your simulator that has ever
shipped.

### 6.3 The rule that costs something: never probe-and-prune. Worked example — PSS

**Offer a feature only where the simulator itself declares support. Never infer a capability,
and never disqualify a declared one by testing whether it behaves.**

That rule sounds free until it costs you a feature, so here is the case where it did. It is
recorded in full at `doc/claude/issues/1475-pss-declared-everywhere-working-nowhere.md`; read it
before you argue with the rule.

* **Both** ngspice binaries on the development machine answer `help pss` identically. The
  capability probe therefore sees the analysis on both.
* On the binary a downloading user installs, PSS **converged on nothing measured**: not on
  ngspice's own shipped example, not on eighteen perturbations of it, and not on the second
  shipped example — which aborts. Twenty runs, **zero** convergences.
* And the failures are **silent**. The ring-oscillator case returns **rc 0, both plots full of
  plausible data**, and a frequency 2.6 % wrong. Worse cases in the same table are **+105 %** and
  **+113 %** at the same rc 0. The sharpest row: handed a starting guess 2.1× too high, the good
  build **refuses the input outright**; the broken one returns success and hands the user's own
  guess back to four parts in ten million, dressed as the result.

So: a declared capability that is worthless in practice, detectable by nobody, on the build most
users have. **And ASE-L still did not prune it.** There is no measurement it could take that
would let it offer the panel on one build and withhold it on the other — the probe asks what the
simulator *says* it has, not whether the answers are any good. The choice was between offering it
to everyone and offering it to nobody, and that is what made it the user's question rather than
an engineering one. The user's answer was to **not build the panel at all**, and the analysis
remains listed, named, and refused with a sentence that says why:

```
This <type> analysis is not one this simulator can set up.
```

**Three lessons for you, in order of how much they will cost:**

1. **Do not add a behaviour probe to rescue a bad build.** It is the obvious fix and it is the
   one this project has ruled against. A probe that measures quality rather than declaration is
   a second, softer source of truth about what your simulator can do, and it will be wrong in
   the direction that stays silent.
2. **The right lever is the feature, not the capability.** When a declared capability is
   untrustworthy across the builds your users have, the honest response is to not offer the
   feature — visibly, with a sentence — rather than to offer it conditionally on a measurement
   nobody can defend.
3. **Ask whether the thing is used before refining the estimate of what it costs.** Every number
   in that issue argues about how badly PSS behaves; none of them could say whether a user would
   ever reach for it. The user's *"I have never run PSS"* is what turned a hard-to-price feature
   into an easy decision, and it arrived from the only source that had it.

---

## 7. rc 0 is not success

Several analyses in this tree return success and produce plausible wrong data. ASE-L has four
guards against that, and **each one needs something from your adapter to work at all.**

### 7.1 The in-deck status guard

The deck itself checks the simulator's own status after each analysis and reports a failed one.
**[NGSPICE-SHAPED]** — this is `$sim_status`, an ngspice interpreter variable, emitted by the
ngspice adapter's `render_deck`. If your simulator has no equivalent, this guard does not exist
for you and the next three matter more.

⚠ **And it is not sufficient even where it exists.** Measured on both binaries: after a run is
stopped mid-way, the deck's guard prints **nothing**, a valid partial plot lands in the results
file, and the process exits **rc 0**. Exit status and the status variable both say success.

**What ASE-L does instead:** the deck emits a completion marker as its last line, and
completeness is read **by that marker's absence**. `ase::ckpt_marker` spells the three literals
once, and they are `ASE-RUN-COMPLETE` (last line of a finished run), `ASE-CKPT-ARMED` and
`ASE-CKPT-DONE` (the checkpoint pair). If you want the same protection, your `render_deck` emits
the same markers — ask `ase::ckpt_marker complete|armed|done` for them rather than retyping them,
so there stays one speller.

### 7.2 Plot reconciliation — `ase::reconcile_plots`

Three facts are compared after every run, before anything is attached: the **prediction** (from
your enabled descriptors' `plots`), the **record** (a sidecar your deck writes, one line per
write), and the **reality** (the plots actually in the results file).

This exists for a failure that is otherwise completely silent: a write that aborts leaves a
results file with fewer plots than the run asked for, rc 0, nothing on either stream. Counting
finds it as an `under` verdict.

⚠ **And the arm nobody predicts is `mislabel`.** Measured: when the walk asks for one plot more
than the analysis produced, the walk does **not** fail — it **saturates** on a built-in
`constants` plot, and the next write appends twelve mathematical constants to the results file
under a perfectly plausible record. **Counting alone cannot see that**: the record count and the
plot count agree. Only comparing the recorded name against the descriptor's own `select` sees
it — which is the second reason `plots` earns its keep.

**What you must supply:** accurate `select` globs, and a deck that writes the sidecar. An
adapter with `plots` entries that do not match what the simulator actually names its output
gets an `under` or `mislabel` verdict on every run, which trains the user to ignore the channel.

The full verdict set is **eight**, and the four this section has not named are as diagnostic of a
wrong descriptor as the two it has: `ok`, `norun` (no results file), `nomap` (no sidecar),
`mislabel`, `under`, `over` (more plots than predicted — a `when` naming a field you never
declared produces this on a run where nothing went wrong), `predmismatch`, and `aborted`. ⚠ Note
`aborted` **replaces** `under` and `predmismatch` when the user pressed Stop, because a stop
explains those two — and deliberately does **not** replace `over` or `mislabel`, because nothing
about stopping a run explains a plot recorded under the wrong name.

### 7.3 Requested-versus-effective read-back

After the run, ASE-L asks the simulator what it **actually** has set and diffs that against what
the bench asked for. Two hooks: `effective_emit {path}` writes the read-back lines into the deck,
`effective_lookup {name eff}` finds one setting in the answer. The verdicts and the exact
sentences:

```
you asked for <name> <want>; <sim> reports <got>
<name> did not reach <sim> -- it reports no such setting
<sim> does not know '<name>' and made a variable out of it (<name> = <got>); <sim> never
reports a name it does not recognise, so this is the only sign you will get
'<name>' is not in this simulator's catalogue, and <sim> says nothing about a name it does
not recognise -- nothing here can tell you whether it took effect
```

The `invented` case is the one worth the hooks: a setting whose name the simulator does not
recognise becomes a variable, silently, and the read-back is **the only sign the user will get**.
Measured on ngspice; ask whether yours does the same before assuming it does not.

⚠ The channel is **armed by there being something to verify** — with no stored option rows there
is no requested value to compare against, and an unconditional read-back would put dozens of
lines of dump into every run log for a report that could only ever be empty.

### 7.4 The capability probe's own verdict rule

Already stated in §6.1 and repeated because it is the same idea a fourth time: *the verdict is
the result, never the exit code and never the log.* A blanket device save exits 0, writes a
results file, logs no warning and no error, and contains no operating point at all.

---

## 8. Never conclude from one build of your own simulator

`doc/claude/ase_analyses_batch/evidence/binary-differences.md` catalogues where **two builds of
ngspice** disagree. Not two simulators — two builds of one, on one machine, both current.
Nine measured differences. The four that should frighten you:

| what | the older build | the newer build |
|---|---|---|
| a parameter expression a campaign design rested on | **the run DIES**, rc 1 | works |
| an export line given an analog argument | **the process ABORTS**, rc 134, output 0 bytes | rc 0, valid output |
| a rawfile written for one saved vector | **2 variables** — a phantom duplicate column | 1 variable |
| a precision setting | **accepted and INERT** — silently ignored | honoured |

⚠ **The build in the middle column — the OLDER one — is the build your users have.** (Counting
the columns is the wrong way to read that sentence and an earlier draft invited it: "the second
column" is correct only if you count the `what` column, and it inverts the warning if you count
the two data columns. So: **the older build, the one whose cells say DIES / ABORTS / phantom
column / inert, is what a user who installs the simulator from their distribution gets.** Here
that is ngspice 45.2, shipped by the current Ubuntu LTS.)

The campaign design rested on the row in the first line of that table, and a feature verified on
the newer build alone **would have exited 1 on every shard for most users**. The design changed
shape — to a nominal deck plus a one-line diff per shard — *because of* that row, before it
shipped, which is why the failure is counterfactual rather than historical. The export line now
names only what the simulator itself reported, for the same reason on the second row.

⚠ **And "accepted and inert" is worse than refused.** A user interface that offers "more digits"
and gets silence and no digits has no way to know. Refusal is a signal; silent acceptance is not.

⚠ **The agreements are the load-bearing half.** That file's second section lists what *did* agree
across both builds, and those agreements are what make a golden portable. Measure both halves.

**The rule for you:** your simulator disagrees with itself across versions and build flags, and
you do not know where until you look. Two builds is the minimum, and the transferable habit is
that **any golden pinning a count, a digit count, or a timestamp is build-dependent until proven
otherwise.** In this tree one setting removes a point-count difference entirely — which turned
out to be a better argument for offering that setting than the one originally given for it.

⚠ **And capability is probed, not read off a build flag, for a measured reason:** one feature is
compiled into both binaries here though only one build's configuration names it, and neither
binary's banner mentions it at all.

---

## 9. How you know you are done — a self-check list you run by hand

**There is no conformance harness, and that is a decision rather than an omission.**
`PLAN.md` §15 designs one; ⚖ **R10** deliberately did not build it. The reason is the one from
the top of this document: with a single implementation the harness would be run against ngspice,
pass against ngspice, and grade the thing that defined it. Its own §15 text carries the sharpest
version of the argument, about check 3 below:

> *"A harness that only ever ran against one build would have called both descriptors
> conformant."*

So §15's five checks are below **as a list you work through by hand**, with the callable thing
that helps for each. **Nothing here runs automatically and nothing reports a pass.** When a
second adapter exists, this list is the specification the harness should be built from — and at
that point it can be built honestly, because there will be two implementations to disagree.

**Check 1 — Schema.** Every required key present and of the declared kind; every registry row
naming a `results` destination.

> Call `ase::analysis_schema_errors <yoursim>`. It returns a list of `{type token detail}`
> triples, or `{}`. It is a **pure reader**: it never raises and it is never called at load time.
> The sibling checkers are `ase::option_schema_errors`, `ase::meas_schema_errors` and
> `ase::campaign_schema_errors` — call whichever families you implemented. The error vocabulary
> is long and specific — **43 tokens**, measured:
>
> | family | tokens |
> |---|---|
> | template & fields (4) | `nocard`, `noslotfield`, `fieldunused`, `baddepends` |
> | `plots` (8) | `noplots`, `noplotselect`, `noplotrole`, `noplotresults`, `badplotroute`, `badplotwhen`, `badplotwhenfield`, `badplotwhenhook` |
> | `setup` (13) | `badsetup`, `badsetupfield`, `badsetuphook`, `badsetuplines`, `badsetupmin`, `badsetupscan`, `badsetupcolumn`, `badsetupcolumns`, `nosetupkey`, `nosetuplines`, `nosetupcolumns`, `setupkeyclash`, `setupcolumnclash` |
> | `stimuli` (11) | `badstimuli`, `badstimuliarg`, `badstimulifunction`, `badstimulihook`, `badstimulilines`, `nostimulikey`, `nostimulilines`, `nostimulifunctions`, `nostimuliselector`, `nostimulitargets`, `stimulikeyclash` |
> | `salvage` (4) | `badsalvage`, `badsalvagepoints`, `nosalvagepoints`, `nosalvagevector` |
> | `matrix` / `resultvecs` / other (3) | `badmatrix`, `badresultvecs`, `twotables` |
>
> Two of them exist because they caught real defects: `noslotfield` is a template slot no field
> describes, so the user can never fill it and the deck can never carry it; `fieldunused` is a
> field the form offers that no template consumes, so the user fills it in and it reaches nothing.
>
> ⚠ **READ THAT TABLE AS A SPECIFICATION, NOT AS AN ERROR LIST — it is the best one this tree has
> for the five keys §5.1 gives a single line each.** **Thirty of the forty-three** are about
> `setup`, `stimuli`, `salvage`, `resultvecs` and `matrix`. Where the prose above says "fields
> consumed by setup legs rather than by a template" and stops, the checker names every part a
> `setup` must have and every way it can be wrong; where it calls `stimuli` "the estimate
> contract" and stops, eleven tokens say what that contract contains. **When this document is
> thinner than the checker, the checker is right** (§11's rule, applied to itself).

**Check 2 — Emit.** Render each declared analysis from its own descriptor defaults, hand the
deck to your binary, and assert it is **accepted**.

> `ase::analysis_cards` gives you every emitted card for a row; `ase::analysis_emit_check` gives
> you every reason a row cannot reach a deck, **all of them, not the first** — a validator that
> stopped at the first offence would make the user press OK once per mistake. An `emit` template
> that cannot produce one runnable line is a descriptor that fails on a user's first click.

**Check 3 — Probe, in BOTH directions.** This is the sharpest check and the hardest to fake.

> The capability answer must say **present** on a build that has the analysis **and absent on one
> that does not.** You need two builds. §8 is why you need them anyway. A descriptor whose
> capability answer has only ever been observed saying *present* has not been tested; it has been
> agreed with. `ase::caps_analysis_present` is the three-valued reader — note that it answers
> `unknown`, not `absent`, when nothing was measured, and that distinction is the check.

**Check 4 — Results.** Every `results` destination names something that **exists after a run of
the analysis that claims to produce it.**

> This is where a wrong plot literal shows up as a failure now rather than as an empty Value
> column six months later. `ase::reconcile_plots` (§7.2) is the machinery; run it against a real
> run of each type and read the verdict rather than the exit code.

**Check 5 — Refusals.** At least one precondition and one cross-field refusal per adapter
**shown to actually refuse.**

> A descriptor whose refusals never fire has refusals that were never wired. This is a specific
> instance of a rule this tree paid for seven times over: **a row whose fixtures never disagree
> cannot fail.** Check that a refusal's inputs actually differ *before* you trust the green.

**A sixth check this tree would add, from its own experience:** point your adapter at a program
that is not a simulator at all, and at one that never answers. Both are ordinary user mistakes.
The measured worst case for a program that never answers is **31.2 s with the interface frozen**,
which is why only an explicit Detect may pay that cost and why no dialog may start a probe.

---

## 10. Undefined behaviour — things with no defined answer today

Say so when you hit one of these, rather than inventing an answer. Each is a genuine gap, not a
trick question.

1. **Registering a hook naming a proc that does not exist.** Accepted at registration; fails at
   call time, wherever that is. There is no validation pass.
2. **Re-registering a name that is already registered.** Replaces the entry wholesale. Caches
   are dropped correctly; anything else that captured a hook name earlier is not notified.
3. **A `needs` id core does not implement.** Evaluates to silence. There is no error and no way
   for an adapter to add one (§5.4).
4. **A descriptor key core does not read.** Ignored silently. There is no unknown-key check on
   descriptors — which is the opposite of the state file's behaviour, where an unemittable
   setting is refused loudly.
5. **`raw_file` for a simulator with no single results file.** Undefined. §2.1.
6. **Two rows sharing a results key.** Possible only if they carry the same name, which the
   interface does not offer; the precedence is fixed in one place so it is not an accident of
   dict traversal, but it is not a designed feature.
7. **The default simulator.** `ase::default_simulator` returns the literal `ngspice`.
   **[NGSPICE-SHAPED]**, and knowingly so — the comment above it explains that resolving it any
   other way is unbounded recursion, and it sits under a standing carve-out that schema defaults
   are the one place an ngspice word may live outside the ngspice namespace. **A second adapter
   does not become the default by registering.**

---

## 11. When this document is wrong — which it will be

It is written against `src/ase.tcl` at `df7609c7`, where the ngspice adapter is ~8,100 lines and
registers 53 hooks. For scale: when ⚖ R10 was first framed that adapter registered **8** hooks;
three days later, **23**; today, **53**. **The contract has grown more than sixfold since the
question of whether to write this document was first asked**, and there is no reason to think it
has stopped.

So:

* **The source wins.** `ase::register_backend` and `ase::backend_hook` are twenty lines between
  them and they are the actual contract. Read them first when something here does not match.
* **Cite sections, not line numbers.** Line hints in this document are hints; a section name
  survives an edit and a line range does not.
* **File what you find.** ⚠ **If you are outside this tree, do not try to follow the in-tree
  mechanism** — it is `doc/claude/issues/NNNN-*.md` governed by `doc/claude/issues/NUMBERING.md`,
  and minting a number there requires a clone, a reserved-block check and a cross-clone grep you
  have no way to run. **Open an issue on the Xschem project instead, or mail the maintainer**,
  and quote the section name and the sentence you are disagreeing with. A maintainer will mint
  the number. (An earlier draft pointed its stated audience — a stranger with no clone — at a
  procedure only a committer can perform.)
* **Complain about the [NGSPICE-SHAPED] marks specifically.** They are this document's
  hypotheses about where the schema is a transcription. Every one you can refute with a
  simulator that does not fit is worth more than a correct sentence, because it is the feedback
  a harness could not have given until you arrived.

⚠ **And if nothing broke, be suspicious.** **D37** wrote that rule for a paper exercise against
a second simulator and it applies twice as hard to a real one: *"Nothing broke" is a suspicious
answer* — attach what you built so somebody can check.
