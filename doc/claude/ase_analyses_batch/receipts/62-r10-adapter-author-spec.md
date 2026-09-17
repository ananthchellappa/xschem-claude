# 62 — ⚖ R10 option B: the adapter-author specification

**Task:** write the teaching document that lets someone support a different simulator in ASE-L.
Write-only, one new file. Pays measurement debt **M16**. **No code, no tests, no simulator.**

**Delivered:**

| file | state | lines |
|---|---|---|
| `doc/claude/specs/ase_l_adapter_authors.md` | **new** | **775** |
| `doc/claude/ase_analyses_batch/receipts/62-r10-adapter-author-spec.md` | this file | — |

**`git diff --stat` (tracked files):**

```
 doc/claude/ase_analyses_batch/LEDGER.md | 10 +++++-----
 1 file changed, 5 insertions(+), 5 deletions(-)
```

⚠ **That LEDGER.md change is NOT mine.** It was already in the working tree when I started
(it is the driver's Task-7 dispatch row) and I did not touch the file. `git status --short src
tests` and `git diff --stat HEAD -- src tests` are both **empty**. My only output is the
untracked new spec plus this receipt.

---

## VERDICT TABLE

| # | question | answer |
|---|---|---|
| 1 | is the hook count 39? | **no — it is 51**, and a second number matters more: the adapter *registers* **53**. §1 |
| 2 | brief claims refuted by the source | **one** (the "39"), plus **one quoted literal** the brief inherited from `DECISIONS.md` that the source does not contain. §2 |
| 3 | brief claims confirmed against source | **all others**, including all four line hints, which are exact rather than approximate. §3 |
| 4 | things wrong in the **tree's own documents**, found while writing | **four**, all recorded as §0 corrections inside the spec itself. §4 |
| 5 | `[NGSPICE-SHAPED]` marks placed | **8**, listed with line numbers. §5 |
| 6 | new user-facing copy minted? | **none** — every string is quoted from shipped source, so **no `rule` debt is owed**. §6 |
| 7 | anything run, built, or simulated? | **no.** §7 |

---

## 1 — The hook count: the brief said 39, and there are two right answers, neither of them 39

The brief said *"Thirty-nine hook names the core actually asks for … derive the list yourself
(grep the call sites; do not trust this number — verify and correct it if it differs, and say
so)."* It differs. Measured at `df7609c7`:

| quantity | value | how |
|---|---|---|
| hooks `register_backend` **requires** | **5** | the `foreach h {…}` literal at `src/ase.tcl:686` |
| hooks the ngspice adapter **registers** | **53** | the `::ase::register_backend ngspice [dict create …]` block, `src/ase.tcl:31645-31699` |
| of those, **optional** | **48** | 53 − 5 |
| distinct hook names **core asks for**, by literal | **51** | see below |

**How the 51 was derived.** A naive `grep backend_hook` is wrong three ways, and each cost a
correction:

1. **Comment lines match the call pattern.** My first pass returned 56 and included
   `everything`, `hook`, `mints`, `serve` — all from prose inside `⚠` comment blocks. Fix:
   strip comment lines (`sed 's/^[[:space:]]*#.*$//'`) **before** extracting.
2. **`backend_hook` is not the only resolution path.** Three exist, and a grep for the first
   finds 30 of the 53:
   * `ase::backend_hook $sim <name>` — the direct resolve;
   * `ase::conv_hook $sim <name> ?args?` (`src/ase.tcl:20981`) — a pre-wrapped `catch` helper
     that the whole convergence family goes through. **11 hook names are reached only this
     way** (`ncdump_parse`, `ladder_rungs`, `ladder_parse`, `optran_line`, `opstrategy_options`,
     `opstrategy_arg_refusals`, `opstate_lines`, `opstate_arg_refusals`, `runhealth_lines`,
     `runhealth_parse`, `runhealth_labels`);
   * `dict exists $backends $sim <name>` — the "does the adapter declare one at all?" peek, no
     call. Reaches `capabilities`, `variant_notes`, `cosim_shim_verdict`, `lint_control_text`,
     `event_probe`, `event_inventory`.
   Plus two literal `foreach h {render_deck run_cmd log_file result_probe}` lists in `ase::run` /
   `ase::run_existing`, and one continuation-split call for `effective_emit` at `:24731`.
3. **A continuation line yields a false name.** `ase::backend_hook [namespace tail [namespace
   current]] \` makes a positional extractor return `tail`. Removed by hand and named here so the
   next person does not re-add it.

**Result: 51 names, every one of which is among the 53 registered.** Intersection is exactly 51.

### ⚠ And the leftover two are a finding, not rounding

**`op_param_enumerable` and `scripts_dir_of` are registered hooks that NO core reader asks for
through any of the three paths.** Searched across `src/` *and* `tests/`:
`grep -rn 'backend_hook.*op_param_enumerable\|conv_hook.*op_param_enumerable'` → **no matches**;
same for `scripts_dir_of`. Both are called by the ngspice adapter **on itself**, by direct proc
call (`src/ase.tcl:26387` and `:25749`).

This **refutes a comment in `ase::register_backend`'s own header**, which says the
operating-point pair *"ride in the dict and are reached through ase::backend_hook like everything
else"*. `op_param_set` is (from `src/rdw.tcl:1621`). `op_param_enumerable` is not. It is recorded
as correction **§0.3** in the spec, and §4 of the spec warns an author not to implement either one
expecting core to call it.

### Cross-check performed on the delivered document

The spec's §4 table was checked mechanically against the registry rather than by eye: every hook
name appearing in §4 was extracted and compared to `registered − required`. **Exact set
equality — 48 = 48, no omissions, no extras.**

---

## 2 — Claims in the brief the source refutes

**(a) "Thirty-nine hook names."** It is **51**. Fully derived in §1. I wrote 51 in the document
and showed the three resolution paths so the number can be re-derived rather than trusted.

**(b) A quoted literal that does not exist in the source.** The brief, following
`DECISIONS.md:1541`, gives the Stage 0 refusal as:

> *"ase: analysis type '\<t\>' is not one this simulator **backend** can render"*

The shipped literal, `ase::analysis_unrenderable_msg` at `src/ase.tcl:4706`, is:

```tcl
return "ase: analysis type '$type' is not one this simulator can render"
```

**There is no `backend`.** This is exactly the trap the brief warned about — *"a copy review in
this batch holds a pre-edit literal for at least one string"* — and it turned out to be this
string, in `DECISIONS.md` rather than in `R9_COPY_REVIEW.md`. Recorded as spec correction
**§0.4**. I did not edit `DECISIONS.md`; the driver owns it.

**Every string quoted in the spec was then verified against `src/ase.tcl` by exact substring
match, not against any other document.** Twenty fragments checked, including both halves of each
Tcl backslash-continuation so the join is what the widget shows. All 20 matched. The
`effective_report` sentences were re-read line by line for the same reason.

---

## 3 — Claims in the brief the source confirms

Every line hint in the brief is **exact**, not approximate:

| brief | measured |
|---|---|
| `ase::register_backend` at `~684` | `684` |
| enforces exactly `render_deck`, `run_cmd`, `log_file`, `result_probe`, `raw_file` | confirmed, `:686` |
| its comment explains why `capabilities` and the operating-point pair are not required | confirmed, `:668-683` |
| row **A3** of `test_ase_simcaps_0948.tcl` reads that loop's own source line | confirmed — `a_body ase::register_backend`, finds the `foreach` line containing `render_deck`, asserts it contains the five-name string and does **not** contain `capabilities` |
| `ase::backend_hook` at `722` | `722` |
| raises for unknown hook **and** unknown simulator | confirmed, `:724-729`, two distinct messages |
| optional resolves wrapped in `catch`, see `~5254` | `5254` exactly — the `⚠ AND EVERY OPTIONAL-HOOK RESOLVE GOES INSIDE A catch` block |
| D34/D36 "no fallback" appears about a dozen times | confirmed; the spec cites five verbatim, from `predeck_deliver`, `run_stop_cost`, `campaign_axis_kinds`, `meas_needs_degrees` and the convergence header |
| ⚖ R10 in `DECISIONS.md` near line 1548 | `1548` |
| `PLAN.md` Stage 15 near line 3865 | `3865` |
| issue 1475 is the worked example for never-probe-and-prune | confirmed and used as §6.3, the longest worked example in the document |
| `evidence/binary-differences.md` catalogues two-build disagreement | confirmed; 9 numbered differences plus an "AGREE" section the spec also uses |

**D30, D34, D36, D37 and ⚖ R10 were read in full** and are reflected in §1, §3, §5.3 and §9 of
the spec respectively.

---

## 4 — What I found wrong in the tree's own documents

All four are recorded as **§0 corrections inside the spec**, per the house rule that a refuted
claim stays visible.

**(1) `PLAN.md` §1a's key-by-key contract block is stale, and this is the sharpest finding.**
Seven keys it specifies as the adapter contract **do not exist anywhere in the tree**:

| key | shipped descriptors carrying it | core procs reading it |
|---|---|---|
| `verb` | 0 | 0 |
| `gated` | 0 | 0 |
| `rules` | 0 | 0 |
| `fatal` | 0 | 0 |
| `options` | 0 | 0 |
| `notes` (as a descriptor key) | 0 | 0 |
| `lint` (as a descriptor key) | 0 | 0 |

`gated` was renamed to `baseline` **with its sense inverted** (Stage 1 correction C42);
`notes`/`lint` shipped as top-level registry hooks under different names (`variant_notes`,
`lint_control_text`). ⚠ **`PLAN.md` §14's "Files and procs" still describes "the `pss` registry
entry with its `rules`", and no `rules` key exists.**

**Why this is the finding and not a nitpick:** ⚖ R10's own scheduling note says a specification
written against a moving contract is stale on arrival. §1a **is** that specification, written
for Stage 1, and it is measurably stale now. The spec cites this as evidence for its own §11
("when this document is wrong — which it will be") rather than pretending it will not happen
again. It is also why I wrote §5.1 from the shipped descriptors and the core readers rather than
from the plan.

**(2) `ase_l.md`'s precondition vocabulary is short by seven.** It says *"The vocabulary is
twenty ids"* and lists 20. The tree implements **27** switch arms in `ase::analysis_needs`
(`src/ase.tcl:12180-13426`). Set difference run mechanically: the 7 extras are `lin_points`,
`points_max`, `setup_check`, `stimuli_check`, `tstart_note`, `two_ports`, `xspice`; nothing in
`ase_l.md` is absent from the tree.

⚠ **My first run of this check was wrong and I caught it before it shipped.** The extractor used
`[a-z_]+`, which excludes digits, so it silently dropped `disto_f1src` and `disto_f2src` and
reported 19-vs-27 with nine extras. Re-run with `[a-z_0-9]+` it gives 20-vs-27 with exactly seven.
The document carries the corrected numbers.

**(3) `register_backend`'s comment over-claims about `op_param_enumerable`.** §1 above.

**(4) `DECISIONS.md` ⚖ R9's quotation of the unrenderable refusal has a word the source does
not.** §2(b) above.

### One further finding, reported as an observation rather than a defect

**`requires` is a live schema key with two core readers and zero implementations.**
`ase::requires_state` is called from `:7412` and `:10458`, and **not one of the eleven shipped
ngspice descriptors carries a `requires` key** (0 occurrences in the `analysis_types` body). So a
second adapter's author is the *first* implementor of that key, not the second — the one place in
the whole contract where the R10 argument inverts. The spec says so in §5.5 rather than
presenting it as settled.

---

## 5 — Where I marked something as true only because ngspice does it that way

Eight `[NGSPICE-SHAPED]` marks, plus a reading instruction at the top telling the author these
marks are the document's main safety mechanism and asking them to argue with each one.

| line | subject | what is ngspice-shaped |
|---|---|---|
| 38 | the convention itself | defines the mark and invites contradiction |
| 137 | `raw_file` / `result_probe` | presumes a **single results file**, and that non-vector results live in the log text. **D37** predicted this against Xyce; never tested |
| 373 | the `emit` token template | presumes an analysis is **one command line with positional arguments**. Quotes D37: *"an analysis is a `.control` command word, never a dot card"* is an ngspice fact wearing a schema's clothes |
| 389 | `plots`' `select` glob | presumes the results file is a sequence of **named plots**, and that reconciliation can compare names positionally against a sidecar |
| 408 | the `needs` vocabulary | **called the largest unmarked ngspice dependency in the system** — 27 ids implemented in *core*, several named for ngspice internals (`noise_klu`, `cider_klu`, `pz_klu`), and **no hook lets an adapter add one**. An invented id silently evaluates to silence |
| 557 | the in-deck status guard | `$sim_status` is an ngspice interpreter variable; a simulator without an equivalent loses that guard entirely |
| 744 | `ase::default_simulator` | returns the literal `ngspice`; **a second adapter does not become the default by registering** |
| 768 | closing instruction | asks the author to refute these specifically, because that is the feedback a harness could not give |

The spec also carries **25 `⚠` blocks** marking measured traps and inversions.

---

## 6 — Copy, rulings and debts

**No new user-facing sentence was minted.** Every string in the document is quoted from shipped
source. Under the batch's standing rule that a new user-facing sentence is the user's to ratify,
**nothing here is owed as a `rule` debt.** Nothing was written to `~/.claude/xschem_owed/` — the
brief forbade touching it, and there was nothing to file in any case.

Strings quoted (all verified by exact substring against `src/ase.tcl`): the two dispatch errors
and the registration error; `ase::analysis_unrenderable_msg`; `ase::analysis_emit_msg`'s
`unrenderable` clause; `ase::analysis_refusal_frames`' log and status frames; all seven
`ase::analysis_state_msg` arms; all four `ase::effective_report` verdict sentences; the three
`ase::ckpt_marker` literals.

**M16 is paid** by the existence of this document; the driver owns marking it on `LEDGER.md`.
I did not edit the ledger.

---

## 7 — What I did NOT do

* **No simulator was started.** No ngspice, no probe, no deck, no run. Every number in the spec
  and in this receipt comes from reading files on disk.
* **No build.** No `make`, no `./configure`.
* **No tests.** No `run_regression.tcl`, no headless suite, no `full_audit.sh`. This is a
  documentation task and nothing in it can move a row — `git status --short src tests` is empty.
* **No `git` write commands.** No add, commit, stash, checkout.
* **Nothing outside `doc/claude/` was touched**, and inside it nothing but my two files.
  Specifically **not** `LEDGER.md`, `DECISIONS.md`, `PLAN.md`, `NUMBERING.md` — the driver
  collects those.
* **No issue number was minted.** This task produces a spec, not an issue, and minting one would
  have required the two-check procedure against every clone; not needed here.
* **`~/.xschem/` and `~/.claude/xschem_owed/` untouched.**
* **No sabotage campaign**, so no snapshots were taken and there is nothing to disarm. Nothing in
  `/tmp` of mine can restore over a live tree.

## 8 — What the next person should check first

1. **The `[NGSPICE-SHAPED]` marks are hypotheses, not measurements.** They are my reading of
   where the schema is a transcription of one implementation. Each is falsifiable by a real
   second simulator and none has been tested by one.
2. **The 51/53 split will move.** It moved from 8 → 23 → 27 → 53 in six days. Any future reader
   should re-derive it with the three-path method in §1 rather than quoting the number.
3. **`PLAN.md` §1a should probably carry a pointer to this document**, since it is the stale
   artifact a stranger is most likely to find first and trust. I did not edit it — it is the
   driver's file — but the spec's §0.1 names it explicitly so a reader who arrives via the plan
   is redirected.
