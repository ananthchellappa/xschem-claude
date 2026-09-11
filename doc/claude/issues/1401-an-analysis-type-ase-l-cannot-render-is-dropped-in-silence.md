# 1401 — an analysis type ASE-L cannot render is dropped in silence

**Stage 0 of `doc/claude/ase_analyses_batch/`**, and the only stage in that plan that is
urgent. It is also the only one that carries no ruling: nothing here waits on the user,
and nothing here moves an existing suite row.

## The defect

A `.state` row whose `type` is anything but `op`, `dc`, `ac` or `tran` produces a run that
**completes normally and does nothing**.

`ase::backend::ngspice::render_deck`'s emit loop was `foreach type {op dc ac tran} {
foreach a [analyses] { if {[type] ne $type} continue … } }`. A row of any other type was
therefore never visited **at all**: the `continue` skipped it once per type, and the
`switch` below has no `default` arm to catch what fell through. Meanwhile
`ase::n_enabled_analyses` counted the row — it answers *"how many did the user tick"*,
which is the right question for deciding whether the deck needs `set appendwrite`, and the
wrong one for *"can this be rendered"*, which had **no reader anywhere**.

**Measured 2026-09-10**, on a state whose only enabled row is
`{type noise enabled 1 output v(out) source v1 sweep dec points 10 start 1 stop 1meg}`:

```
** sch_path: /fixture/nfet_clean.sch
… netlist, .GLOBAL GND, .lib, two .param, .options savecurrents, .temp 27, .save -i(v1) …
.control
set appendwrite
print -i(v1)
.endc
.end
```

rc **0**. No analysis command. No `$sim_status` guard. No `remzerovec`. **No `write` at
all** — so the run produced no raw file whatsoever, because issue 0929 moved the write
inside the per-analysis loop. Nothing on stdout, nothing on stderr, nothing in the action
log, and the Analyses pane still showing the row ticked with its arguments beside it.

⚠ **The plan's own description of this defect was wrong in the direction that made it look
milder.** `PLAN.md` Stage 0 said today's deck was *".control / set appendwrite /
remzerovec / write / .endc"* — i.e. that a rawfile was written and merely empty. It is not:
there is no write and no file. Downstream, `ase::attach_dbs` reports `NOT ATTACHED … the
analysis did not run` about a run that never contained the analysis, which is the one
message a user would read as *"the simulator failed"*.

**Why it matters now rather than in the abstract.** Nothing in the shipped GUI can create
such a row today — `ase::state_default` seeds exactly the four types and the Choose
Analyses dialog offers exactly those four. The row arrives three other ways: a hand-edited
`.state`, a `.state` written by a later version of ASE-L and opened by this one, and every
stage of the analyses batch from Stage 5 onward, each of which adds types to the registry.
Stage 0 ships first precisely so that the failure mode is closed **before** anything starts
producing rows that would hit it.

## What shipped

**One refusal, minted once.** `ase::analysis_unrenderable_msg` is the only place the
sentence is spelled:

> `ase: analysis type 'noise' is not one this simulator backend can render`

Both refusal sites say it with that proc. Two spellings of one refusal is the drift this
batch exists to delete, one layer up.

**`ase::analysis_emit_rank {type {op_last 0}}`** — the rank table, `op`=0 `dc`=10 `ac`=20
`tran`=30, and `op`=90 under issue 0964's `op`-last variant. `{}` for anything else, which
*is* the refusal; a `return 0` default would have put an unknown type first in the emit
order and back in the silence. **The order is unchanged**, and deck golden D1 of
`test_ase_core.tcl` does not move.

⚠ `op`-last is a **separate named rule** and not a property of these numbers: its reason is
that ngspice's save list is sticky *forward only*, so the per-device requests sitting
immediately before `op` would be recorded again by every analysis after it (issue 0964, and
the 74.9 MB it deleted). It does not generalise to a type added later.

**`ase::analysis_emit_order {state {op_last 0}}`** — the enabled rows, as `{rank index
type}` triples, or a named error. **It iterates the rows and then orders them; it never
iterates the order.** A row that is walked cannot be skipped without somebody deciding to
skip it. The index is part of the sort key, so two enabled rows of one type emit in the
order the state lists them — the state is the user's document and its order is theirs.
`lsort` is a merge sort and stable; row **D7i** pins that rather than trusting it.

**`ase::analysis_unrenderable {state}`** — every enabled type with no rank, so the gate can
name all of them in one refusal instead of stopping at the first. A hand-edited `.state`
may well carry more than one.

**`ase::preflight_gate` refuses too, and earlier.** The gate runs *before* the deck is
written, so nothing in the run directory is touched. ⚠ **Its clause sits above the
`ase_preflight` early return, deliberately.** That escape is a real lever for the
save-name check — a user who knows their netlist better than the scanner does must not be
locked out of their own simulator — and there is nothing for it to be right about here: a
deck that emits no analysis at all is not a run anyone can usefully force. Row **PF222e**
fails if the clause ever drifts below the early return.

**`ase::plot_sim_type_reason {state}`** — `{}` from `ase::plot_sim_type` has always meant
two different things and the caller could not tell them apart: *"nothing is enabled, so
nothing ran"* and *"something is enabled and this viewer has no mapping for it"*. The
second is the honest answer for every type beyond the four, and it was reported as the
first. ⚠ `ase::plot_sim_type` itself is **unchanged** — row R6 of
`test_ase_optier_0963.tcl` pins its ranking and this issue does not touch it.

## Evidence

**RED first, and the witness is the point.** This defect leaves nothing behind — no error,
no message, not even a file that looks missing — so a fix landed without a witness has no
evidence the defect was ever there. The rows were written in their *inverted* form first:
one asserted that a noise-only state rendered **without** error, another that the deck
carried `set appendwrite` and no analysis command at all. Both were **green** against the
unfixed code, in both arms, at `ALL PASS (235 checks)`. Then the code changed and both went
red — and only then were they inverted to assert the refusal. (Named by assertion rather
than by letter, for the reason given below the sabotage table.)

| suite | before | after | arms |
|---|---|---|---|
| `test_ase_core.tcl` | 230 | **248** | `--nogui` and `:99`, identical |
| `test_ase_preflight.tcl` | 115 | **125** | `--nogui` and `:99`, identical |

⚠ **The last eight of those rows came from an adversarial review run before this committed** —
four lenses over the diff, every finding handed to a separate agent instructed to refute it.
Fifteen findings raised, **ten refuted, five confirmed**, and the two that changed the code are
recorded in *What the review changed* below.

⚠ `test_ase_preflight.tcl` **had no declared floor** until this issue; one is declared with
these rows, because a floor is worth having from the moment somebody adds to a file.

**Sabotage-verified, four times.** `ase::analysis_emit_rank`'s `return {}` → `return 0` (the
shape of the defect, not a syntax break) turned **exactly nine rows red**: D7a, D7b, D7c, D7e
and PF222a–e. Then, for the review's fixes: deleting the backend-scope guard reddened **D7e5
and PF222j** and nothing else; dropping the `lsearch` dedup reddened **D7e2** alone; dropping
the rundir clause reddened **PF222h** alone.

⚠ **Row letters are not durable across a red-first cycle and must not be cited as if they
were.** The red-first section had five rows and the committed one has eighteen, so today's
**D7d** — `n_enabled_analyses` still counts the row — is **not** the historical D7d. It holds
against fixed and unfixed code alike and is deliberately absent from the sabotage list. Cite
the assertion, never the letter. Every other row in both suites stayed green. Restored by `cp` from a
pristine copy, md5 compared equal (`b2a0269e3ba1b3703a48655bb42711f5`), both suites green
again. No `git checkout`, `restore`, `stash` or `clean` was used.

## What this does NOT do

* **It does not collapse the eight copies of *"what is a `dc` analysis"*.** That is Stage 1
  of the batch, and the rank table above is explicitly temporary: Stage 1 replaces it with
  the `emitorder` column of a per-backend registry reached through an optional
  `analysis_types` hook. **The loop shape is final; only the table is Stage 1's to replace.**
* **It does not touch the print anchor**, which is a *separate* literal twelve lines below
  the old `anorder` — `foreach type {dc ac tran op}` inside the same proc, governed by issue
  1243's ruling rather than 0964's. It is the eighth copy, it is Stage 1's, and a row of an
  unknown type can no longer reach it because the refusal fires first.
* **It adds no analysis type.** `noise` is the fixture here, not a feature; ASE-L still
  offers exactly four.

## What the review changed

**1. The refusal was not scoped to a backend.** `ase::analysis_emit_rank`'s four entries are
ngspice's — they are `ase::state_default`'s schema defaults — but `ase::preflight_gate` applied
them to **every** registered backend. `ase::register_backend` is a real extension point (five
required hooks, extras tolerated) that `src/rdw.tcl` names to the user, so a second backend
whose `render_deck` emits a fifth type would have been refused *before its own hook was ever
called* — a claim about a backend nobody asked. The precedent was two statements above the
call site all along: `ase::run_deck` gates the casemode precheck behind
`ase::run_composes_registry`, whose header says *"a refusal about an entry it never runs would
be a lie."* Fixed by **`ase::analysis_rank_authority`**, which compares the state's simulator
against the schema default's rather than naming `ngspice` in core — so no new simulator literal
is introduced, and Stage 1's `analysis_types` hook replaces the whole question.

**2. The refusal dropped a clause a written ruling requires of this proc.** Every other refusal
in `ase.tcl` ends *"Any files already in `<rundir>` are from an earlier run"*, and
`doc/claude/specs/simulator_profiles.md`'s *where the gate sits* ruling is written about this
gate specifically. This one omitted it, while running **above** `run_deck`'s delete of the
previous raw — so a prior run's artifacts really were still on disk and unmentioned. Restored,
with one improvement on the siblings: `ase::rundir` does `file mkdir`, so they **create** a
directory from inside a message whose whole claim is that nothing was written. This one names
the rundir only when it already exists (**PF222i** is the non-vacuity row).

Three further findings were confirmed and are documentation rather than code: the row-letter
drift above, D7e's unpinned *"names it once"* (now **D7e2**/**D7e3**/**D7e4**), and that the
gate's second sentence is user-facing copy that the rule debt did not name — corrected below.

## The sentences are the user's

**Two** sentences are minted here, not one, and the review caught that only the first was
filed:

1. `ase: analysis type '<t>' is not one this simulator backend can render` — the refusal
   itself, minted once in `ase::analysis_unrenderable_msg` and said by both refusal sites.
2. the gate's second line — *"it is enabled on this bench, so the run would have completed,
   produced no result for it, and said nothing. Nothing was generated: no deck, no raw, no
   log. …`set ase_preflight 0` does NOT disable this check."* — which is equally user-facing
   and appears nowhere else.

Per the batch's standing rule both are the **user's** to ratify, filed as `owed.sh add rule
1401` and paid with the ⚖ R9 batch of Stage 3.
