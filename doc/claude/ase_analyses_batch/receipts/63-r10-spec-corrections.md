# 63 — applying receipt 62b's audit to ⚖ R10's adapter-author specification

**Subject:** `doc/claude/specs/ase_l_adapter_authors.md`
**Input:** `receipts/62b-r10-adapter-spec-verification.md` (61 CONFIRMED / 5 REFUTED / 11 PARTLY), read in full.
**Method:** every finding re-verified against `src/ase.tcl` / `src/ase_window.tcl` / `src/rdw.tcl`
directly. No literal was taken from `DECISIONS.md`, `PLAN.md`, receipt 62 or receipt 62b.
Nothing built, run or simulated.

**Line count: 775 → 977 (+202).**
**`[NGSPICE-SHAPED]` marks: 8 → 9.** ⚠ blocks: 25 → 42.

---

## 1 — THE MOST SERIOUS: `{build <proc>}` (REFUTED — removed)

**Verified independently, not taken on trust:**

* `ase::analysis_expand` has no `build` arm. Its first act per token is
  `if {[string index $tok 0] ne {@}} { lappend res [list 1 $tok {}] ; continue }` — a
  `{build …}` **token** is passed through as **literal words**.
* `ase::analysis_slots` likewise `continue`s on any non-`@` token.
* No core reader of a card-level or token-level `build` exists: an exhaustive grep for
  `dict exists … build` / `dict get … build` over `ase.tcl` returns only comment prose and two
  unrelated hits (`cosim build=never`, `build_date`).
* `ase::analysis_schema_errors` flags a card with no `tmpl` as **`nocard`**.
  ⚠ **Line correction to 62b:** that token is emitted at **`:5537`**, not `:5558`.
* The source's three statements all confirmed verbatim: `:5920` *"specified and never shipped"*;
  `:26576` *"the `{build <proc>}` escape is **NOT IN THIS TREE**"*; `:26750`
  *"⚠ **THE DECISION IS: DO NOT BUILD IT**"*, whose stated reason is a measurement — `out_decompose`
  already recovers the structure composition would have bought.

**Changed.** The escape hatch is gone and replaced by a ⚠ block that says it was specified in
`PLAN.md` §1c and deliberately not built, cites the three source lines, and states **both** silent
failure modes (token → literal words in the deck; card → `nocard` from the one checker §9 tells the
author to run, naming nothing). It then says what to do instead: `setup` for a variable number of
lines around the card, one composed token plus an `out_decompose` hook for composition, and
otherwise *"you have found the finding"*.

⚠ **THE BRIEF SAID §5.2. IT WAS IN THREE PLACES.** Besides §5.2's prose and its
`[NGSPICE-SHAPED]` block, the **front matter** ("Who this is for") offered *"a `build <proc>`
emitter"* as a reason adapters are executable Tcl. A reader meets that on page one. All three are
corrected; the front matter now names three executable things that **do** ship (`requires`
predicate, `salvage` point counter, `setup` leg).

---

## 2 — THE ACID-TEST FAILURE: `fields` and `results` (fixed by §5.1b)

New subsection **§5.1b**, because both were named in §5.1's table and defined nowhere.

**`fields`** — every key core reads off a field descriptor, extracted exhaustively from
`dict exists/get $fd|$f <key>` across `ase.tcl` and `ase_window.tcl`, now tabulated with what each
does: `name kind required label labels relabels unit default values valuelabels min depends
whenskipped when_true when_false advanced group`. Sourced from `ase::field_descriptor`,
`field_default`, `caption_of`, `field_caption_for_row`, `field_value_label`, `field_value_labels`,
`field_emits`, `field_value`, `field_depends`, `field_active`, `analysis_expand` and
`analysis_emit_check`.

⚠ **A finding of my own that changes what the document should say about `kind`.** The shipped
values are `real int freq time bool mode source node outvar filter`, but
`ase::ui::chana_field_row`'s switch has arms for only `bool` and `mode` and **a `default` arm that
builds a plain entry box**, deliberately (*"declares a kind this proc has never heard of still
produces a usable control"*). The only kind **core** acts on is `bool`. So the document now says
plainly: inventing a `kind` is safe and buys nothing — it is a request for a widget.

**`results`** — ⚠ **and here the brief's instruction is refuted by the source; see §5 below.**
The document now separates the two halves: the **destination name** (`value`, `viewer`, `table`,
plus `none`, legal only for `role opinfo` and refused for every other role) is the checked
contract, read by `ase::plot_results` and enforced by `badplotroute`; the inner **`kind` is read
by nothing**.

**Worked example added** — the minimal analysis taking one argument and producing one readable
result, with the four rules it obeys named against the error tokens that catch each
(`noslotfield`, `fieldunused`, `noplot*`, `badplotroute`), plus the two-line swap that routes it to
the Value column instead. A stranger can now go zero → one working analysis.

---

## 3 — THE OTHER REFUTATIONS

| # | finding | verified | change |
|---|---|---|---|
| 1 | `requires` **has** a shipped implementation | `proc requires_cider {caps}` at `:29424`; the `filetype` `sim_options` row at `:29723` carries `requires ::ase::backend::ngspice::requires_cider` | §5.5 rewritten. Narrowed to *no shipped **analysis** descriptor uses it*; the option-catalogue worked example is now pointed at |
| 1b | **two** levels, not three | Exhaustive grep for readers returns exactly `ase::opt_gate_state` (`:7405/7412`) and `ase::analysis_state` (`:10457/10458`). **No field-descriptor reader exists** | §5.5 heading and body corrected; states a `requires` on a field is read by nothing |
| 2 | `results` **not** enforced at registration | `ase::register_backend` (`:686`) checks five hook keys and nothing else. The only entry-level `results` test is `analysis_schema_errors`' `badplotroute` arm — a pure reader never called at load time (`:5518-5523`). No standalone missing-`results` token exists | §5.1 row → **"by design, NOT enforced"**; §5.3 gained a ⚠ block; §5.3's heading changed to *"mandatory by design, unenforced in fact"*. §5.1 and §2.2 now agree |
| 3 | "byte-identical banner" overstates | `evidence/variants.md`: both report `ngspice-46+`; *"the only field that differs is `Creation Date`"* | §6.1 now says **identical version string**, names `Creation Date` as the differing field, and notes it is a `make` timestamp — sharpening the argument rather than weakening it |
| 4 | §8's "second column" ambiguous | Table header is `what \| the older build \| the newer build`; `binary-differences.md` confirms 45.2 is the damaged build and that the current Ubuntu LTS ships it | Rewritten to **name the build** ("the older one… ngspice 45.2") and to say explicitly that counting data columns inverts it |
| 4b | §8's "verified on the newer build first" asserted as history | Source states it counterfactually (*"a feature verified on the fork alone **would have** exited 1"*); the design changed **before** shipping | Tense corrected; now says the failure is counterfactual rather than historical |
| 5 | §0 over-claims "do not exist anywhere in the tree" | `gated` is live and core-read: `ase::opt_gate_state` at `:7400`, `gated 1` shipped at `:29723`. `options` is a live state key (`state_default`, `:538`); `notes` a live dict key (`:4266`); `fatal` a live verdict tier (`:8413`); `verb` a live proc parameter (`analysis_refusal_frames`, `:5509`). Only `rules` is absent as a word | §0.1 narrowed to **"no analysis-descriptor reader"**, with `gated` named as the sharpest counterexample and the other four listed by role |

---

## 4 — THE ADDED MARK (U1)

`§2.1` gained a second `[NGSPICE-SHAPED]` block covering the **three launch hooks inside the
required five** — the first thing a stranger reads. Call sites verified:

* `run_cmd` → `[$run_cmd $state $deckpath]` (`:17040`) — **core passes two**, one process per run;
* `log_file` → `[$log_file $state]` (`:17039`) — one path;
* `capabilities` → `[… capabilities] $resolved $eargs $wd` (`:3510`) — `$resolved` an absolute path.

The mark states what a **library binding, persistent server, socket protocol or job scheduler**
would have to do instead, names the two least-bad fictions available today (a wrapper script that
looks like a one-shot program; a `log_file` path the adapter writes itself), and says core cannot
tell either from the real thing.

---

## 5 — FINDINGS I CONCLUDED WERE THEMSELVES WRONG

**(a) 62b's W2 under-counts the schema checker by seventeen, and my first edit repeated it.**
62b says `ase::analysis_schema_errors` emits **26** tokens and lists them. Measuring the proc's
true bounds — `:5524` to `:5861`, the next top-level `proc` being `ase::analysis_verbatim` at
`:5862` — and extracting every `lappend out [list $ty …]` gives **43** distinct tokens. The
missing seventeen include an entire **`stimuli` family of eleven** (`badstimuli`, `badstimuliarg`,
`badstimulifunction`, `badstimulihook`, `badstimulilines`, `nostimulikey`, `nostimulilines`,
`nostimulifunctions`, `nostimuliselector`, `nostimulitargets`, `stimulikeyclash`), five more
`setup` tokens (`badsetupscan`, `badsetupcolumn`, `badsetupcolumns`, `nosetupcolumns`,
`setupcolumnclash`) and `twotables`. ⚠ **I wrote "26 tokens" into §9 on 62b's word before
measuring, then caught it.** §9 now carries the full 43 in a family table, and the sharper claim
that **30 of the 43** are about the five keys §5.1 gives one line each — which makes the checker a
better specification of `stimuli` than the prose is, a point 62b could not make because it had not
seen the family.

**(b) The brief's instruction on `results` is refuted by the source.** It asked me to make the
`kind` vocabulary discoverable. Measured across `ase.tcl`, `ase_window.tcl` and `rdw.tcl` — with a
**positive control first**, because my initial grep returned empty for a string I knew existed
(my own filter was stripping the 27xxx lines) — every one of `opvectors`, `scalars`, `sweep`,
`roots`, `params`, `contributors` occurs **only inside the ngspice descriptor literal**. There is
no reader. Publishing a "legal kind values" list would assert a contract that does not exist and
would be the same defect as the `{build <proc>}` escape, one layer down. The document instead says
the destination name is the checked half, the `kind` is an unread annotation, copying the nearest
shipped one is correct, and needing it to *mean* something is a missing reader and a finding.

**(c) 62b's W4 under-counts `reconcile_plots` too.** It names six verdicts plus `aborted`.
Measured: **eight** — `ok`, `norun`, `nomap`, `mislabel`, `under`, `over`, `predmismatch`,
`aborted` — and the substitution rule is asymmetric on purpose: `aborted` replaces `under` and
`predmismatch` (a Stop explains those) and deliberately **not** `over` or `mislabel`. §7.2 now
carries all eight and the reason.

**(d) 62b's `nocard` line hint is off by 21** (`:5558` → `:5537`). Immaterial to the finding.

---

## 6 — CHEAP CORRECTIONS ALSO APPLIED

§2.2 *"The two errors it can raise"* showed one — `register_backend` raises exactly one shape
(`:688`); corrected, with a pointer to §3.1 for `backend_hook`'s two and the note that these fire
at registration and those at every call site. §5.4 now points at **`ase::needs_eval`** for the
27 id bodies rather than at `ase::analysis_needs`, which is a short driver containing none of them.
§1's `conv_hook` hint `:20981` → **`:20982`**. §7.1 now quotes the three checkpoint literals
(`ASE-RUN-COMPLETE`, `ASE-CKPT-ARMED`, `ASE-CKPT-DONE`) and tells the author to ask
`ase::ckpt_marker` rather than retype them. §5.1 gained the omitted live key **`matrix`** (shipped
on `sp` at `:27323`, read at `:5717` and `:6155-6190`). §11 now gives an outsider a filing route
they can actually use — the in-tree `NUMBERING.md` procedure requires a clone and a cross-clone
grep the document's own stated audience cannot run.

---

## 7 — WHAT I DID **NOT** DO

* **No file outside the two in my remit was touched.** Only
  `doc/claude/specs/ase_l_adapter_authors.md` and this receipt.
* No `src/`, `tests/`, `LEDGER.md`, `DECISIONS.md`, `PLAN.md`, `NUMBERING.md`, and neither
  existing receipt.
* **No simulator, build or test suite run.** No `git` write command. Nothing under `~/.xschem/`
  or `~/.claude/xschem_owed/`. No issue minted.
* **Not verified by execution.** These are documentation edits; the claims are verified by reading
  `src/ase.tcl`, not by running anything. Every count in this receipt is reproducible read-only.
* 62b's W5, W6 and the `role`/`sidecar`/`rung`/`shard` undefined-terms list were **not** addressed
  — they are real but outside the brief, and `role` in particular is still used and never
  enumerated. Worth a later pass.

### `git diff --stat`

The spec is **untracked** (`?? doc/claude/specs/ase_l_adapter_authors.md`), so `git diff --stat`
reports nothing for it. The measured delta is **775 → 977 lines (+202)**.

⚠ **AND `git diff --stat` IS NOT CLEAN, THROUGH NO ACT OF MINE.** At the start of this task
`git status` showed only `LEDGER.md` modified. It now also shows:

```
 doc/claude/ase_analyses_batch/DECISIONS.md |  2 +-
 doc/claude/ase_analyses_batch/PLAN.md      | 14 +++++++++++++-
```

**I edited neither.** Another writer is live in this clone (CREW_BRIEF: *"YOU ARE NOT THE ONLY
WRITER IN THIS CLONE"*). Worth recording: `DECISIONS.md`'s change removes the word **`backend`**
from the unrenderable refusal — *"is not one this simulator ~~backend~~ can render"* — which is
**exactly the live pre-edit literal this specification's §0.4 caught** and 62b confirmed. The
correction is being acted on by someone else while I write this. §0.4 stands and needed no edit.
