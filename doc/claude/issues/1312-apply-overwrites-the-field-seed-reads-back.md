# 1312 — `apply` writes the union into `params`, and `seed` reads that same field back as "the PDK's own list"

> # ✅ FIXED by item **B2e**, 2026-09-04, commit on branch `fluid-editing`.
> Ruling **DD-13** implemented: the descriptor carries a third list, `declared`,
> written by `op_annot::register` alone (preserve-if-present) and read by
> `op_param_lists::_params` alone — so `seed` means what its name says and no
> sequence of edits can destroy it. `apply` additionally unions in **the type's
> own declaration, appended LAST** (`_merge_declared`), which is what makes
> ruling **DD-4**'s guarantee — *Delete never changes what the simulator is
> asked to save* — hold once the button column owns **both** lists.
> **Read the "What B2e landed" section at the bottom of this file for the AFTER
> transcript and for what stayed open.**


**⚠ ESCALATED 2026-09-04: this is not only an order defect. It DESTROYS PDK
rows, and it is the BLOCKER that refuted and reverted item B5 — see issue
1314.**

**Filed by item B5 (2026-09-04), which is the first caller of
`op_param_lists::apply` in the tree. Measured, NOT fixed.** Status: **FILED, NOT
FIXED.**

## The collision, in two lines of the store

* `op_param_lists::apply` writes `_save_set` — the **union** of the annotation
  and summary lists, in **annotation-then-summary order** — into the
  descriptor's `params` (ruling **DD-6**: `params` is what the run computes).
* `op_param_lists::seed` reads the PDK's list through `_params`
  (`src/op_param_lists.tcl:700`), which reads **`dict get $d params`** — the very
  field `apply` has just overwritten.

So after the first `apply`, "the PDK seed" is no longer the PDK's list. It is
whatever the last apply computed, in whatever order the user's annotation list
happened to be in.

## Measured, on this binary, 2026-09-04

Two `type=` tokens in one class, both registered with `{{id ids 0} {gm gm 1}
{gds gds 1}}`, nothing owned:

```
seed0        = {id ids 0} {gm gm 1} {gds gds 1}
eff summary0 = {id ids 0} {gm gm 1} {gds gds 1}
                     # now the user REORDERS the ANNOTATION list only
reordered annotation = {gm gm 1} {id ids 0} {gds gds 1}
apply        = zz1 zz2
descr params = {gm gm 1} {id ids 0} {gds gds 1}
seed1        = {gm gm 1} {id ids 0} {gds gds 1}
eff summary1 = {gm gm 1} {id ids 0} {gds gds 1}   <-- the SUMMARY list nobody owns
```

**Reordering list 1 silently reordered what list 2 answers**, with nothing said
anywhere. The user never touched the summary list and does not own it. That is
invariant I3's family — a plausible wrong answer, on a schematic, with no
report.

## ⚠ AND IT IS A DATA-LOSS DEFECT. The paragraph that used to stand here was wrong.

This file originally said *"the content is not lost (the union is a superset),
so this is an order and provenance defect, not a data-loss one"*, copying
`_save_set`'s own in-code comment. **Both are false, and they are false in
exactly the case this feature creates.** The superset argument holds only while
at least one of the two lists is UNOWNED — an unowned list answers the seed, so
the union re-includes it. Own both, which two Delete presses do, and the union
consults no seed at all.

Measured 2026-09-04 on `./src/xschem` at `79f163cb`, driving the reverted B5
button path, broad scope:

```
PARAMS0    = {id ids 0} {gm gm 1} {gds gds 1}
  delete gm from annotation ; apply
PARAMS1    = {id ids 0} {gds gds 1} {gm gm 1}     # reordered, still present
  delete gm from summary    ; apply
PARAMS2    = {id ids 0} {gds gds 1}               # gm is GONE from params
SEED2      = {id ids 0} {gds gds 1}               # and gone from the PDK seed
SIBPARAMS2 = {id ids 0} {gds gds 1}               # and from the sibling type
```

`op_annot::_cards_for` iterates `params`, so the `.save` card goes with it and
**the simulator stops being asked to compute the parameter** — a direct
violation of binding ruling **DD-4/DD-6**. Nothing can put the row back inside
the session: `reset` restores the user's lists, not the descriptor, and the
window's own Add refuses because no list and no seed declares it any more.

The provenance half is real too and was always real: a row the user ADDS to the
annotation list ends up in the PDK seed, so a later `reset` of the user's own
list answers a seed that carries the user's row.

## What item B5 tried, and why it was reverted

B5's containment was *"Delete and Add apply; a reorder does not"* — Delete and
Add paying the cost because their visible effect **is** the feature. That
containment is what the transcript above defeats: the two presses that destroy a
PDK row are both Deletes, so the one path B5 chose to keep applying is the one
path that loses data. The item's adversary landed the attack, the write-up agent
re-measured it, and **item B5 was reverted in full** (status F, patch preserved
at `doc/claude/op_param_batch/B5_working_tree_REFUTED.patch`).

**So there is no containment in the tree, and none is possible from
`src/rdw.tcl` alone.** Any caller of `apply` that can own both lists inherits
this. Fixing it is a change to `src/op_param_lists.tcl`, which B5's Files cell
forbids — which is itself the finding: **B5 was mis-scoped and cannot be
delivered until this issue is fixed.**

## Options

* **(a)** give the descriptor a separate key for the PDK's own declaration
  (written once, by `op_annot::register`, never by `apply`) and have `_params`
  read that. Smallest change that makes `seed` mean what its name says; costs one
  descriptor key and a line in the three PDK `_procs.tcl` header comments.
* **(b)** have `apply` refuse to overwrite `params` when the value it would write
  differs only in ORDER from what is there. Cheap, and wrong: it would also
  freeze the drawn order, which is what Up/Down exist to change.
* **(c)** have `seed` cache the first `_params` answer per type. Rejected: a
  cache that outlives an `op_annot::register` from a user's rc breaks invariant
  I5 (a user's own registration must take effect on redraw).

**Recommended: (a), and it is now a BLOCKER, not a nicety.** With it, the reorder can apply like every other edit and
row **BT8** of `tests/headless/test_rdw_window_1245.tcl` — which asserts that
reordering the annotation list leaves `effective ... summary` at the PDK seed —
still holds.

## Related

Sibling of **1292** (nothing ever removes `shown`, so Reset/Defaults cannot be
built on `reset` + `apply`). Both are the same shape: `apply` writes descriptor
state that no verb can put back.

---

# What B2e landed (2026-09-04)

## The BEFORE transcript, quoted verbatim from B2e's Measure agent

Reproduced on `./src/xschem` at `ee61aa4a` with B5's own `rdw::_edit` /
`rdw::_find_triple` shapes reduced to the store — **not a paraphrase**, and it
matched issue 1312's own recorded transcript byte for byte:

```
PARAMS0                = {id ids 0} {gm gm 1} {gds gds 1}
seed1                  = {gm gm 1} {id ids 0} {gds gds 1}
effsum1                = {gm gm 1} {id ids 0} {gds gds 1}
owns_summary           = 0
del_ann_gm             = ok
PARAMS1                = {id ids 0} {gds gds 1} {gm gm 1}
del_sum_gm             = ok
PARAMS2                = {id ids 0} {gds gds 1}
SEED2                  = {id ids 0} {gds gds 1}
SIBPARAMS2             = {id ids 0} {gds gds 1}
ADDBACK                = REFUSED - no list and no seed declares gm
seed_after_add         = {id ids 0} {gm gm 1} {gds gds 1} {MINE mine 1}
seed_after_reset       = {id ids 0} {gm gm 1} {gds gds 1} {MINE mine 1}
```

And the simulator consequence, measured through the **real**
`op_annot::_cards_for` on a **real loaded instance** (a scratch `.sch` holding
one `nmos.sym` instance M1; `type_M1 = nmos`, `claims_M1 = 1`, so the fixture is
live and cannot pass by drawing nothing) — this leg was inferred when 1312 was
filed and is now measured:

```
CARDS_BEFORE           = {.save m1[ids]} {.save m1[gm]} {.save m1[gds]}
CARDS_AFTER            = {.save m1[ids]} {.save m1[gds]}
```

Under measured simulator rule **R1** the parameter then does not exist in the
raw at all.

## The AFTER lines

The same two broad-scope Deletes, on the tree B2e landed:

* `ol_dkey nmos declared`, `ol_dkey pmos declared` and `seed mos` are all still
  `{id ids 0} {gm gm 1} {gds gds 1}`, **byte for byte and in the PDK's order**
  (row **N1**).
* `_cards_for M1 {}` still emits `.save m1[gm]`, and `ol_dkey nmos params`
  still holds `{gm gm 1}` while `ol_dkey nmos shown` does not — the deck is
  unchanged and the sheet is decluttered, which is DD-4 in one row (row **N2**).
* Add has a source again: both effective lists lack `gm`, `seed mos` declares
  it, and the triple it declares is `{gm gm 1}` (row **N3**).
* The order half: owning the annotation list only, reordered, leaves
  `owns class mos summary` at 0 and leaves `effective mos summary` and
  `seed mos` in the PDK's **original** order (row **N4**).
* Adversarially, beyond the suite: a **40-edit storm** alternating both lists
  through delete/rotate/insert/truncate with an `apply` after each leaves
  `declared(nmos)` = `declared(pmos)` = `seed mos` byte-identical to the PDK's
  three rows, and the `{gds gds 1}` triple still in `params`
  (`/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_B2e/adv_B2e.tcl`).
  A 200-cycle apply storm was run separately by Verify-C with the same result.

## The decisions, with their ladder rung and their rejected alternative

* **The key is named `declared`; `op_annot::register` is its only writer and
  `op_param_lists::_params` its only reader** — the *opposite* direction from
  `shown`, which `apply` writes and `op_annot::text` reads. Ladder **L1**,
  invariant **I5** (only `register` bumps `::op_annot::gen`), plus DD-13's
  table. *Rejected:* `pdk_params` — a user's own rc declares too, and naming
  the PDK in the key would make her registration look like a PDK's.

* **PRESERVE-IF-PRESENT is the whole design.** `register` stamps `declared`
  only onto a descriptor that carries none, so `apply` — which round-trips the
  dict it read — cannot touch it, and the guarantee is *built* rather than
  asserted (the standard `_show_set` set for the DD-6 amendment). Ladder
  **L2**. *Rejected:* restamp-always with `apply` explicitly re-setting
  `declared` to what it read — that makes the guarantee an assertion inside one
  caller, and the **next** round-tripper (a user's rc changing `match`, B5-2,
  anything) silently destroys the declaration. That is the exact failure this
  batch hit three times: DD-4 → DD-6 → DD-13.

* **The empty dict is the only unstamped registration.** Any NON-empty
  descriptor with no `declared` gets one — its `params` when present, `{}` when
  not. Ladder **L2**. *Rejected:* the narrower rule *"stamp only when
  `dict exists $descriptor params`"* — it leaves a reachable corner where a
  descriptor registered **without** `params` (legal today; `_claims` answers 0
  for it) is later given one by `apply`, and `register` then records apply's own
  **union** as that type's declaration, i.e. 1312 surviving in the one place
  nobody would look. Both pre-existing fences still hold: `register <t> {}`
  stores `{}` exactly (`opa_clear_store`; test_op_annot rows P0/P11/P16), and
  the stamp never parses the value (row **K17** registers a `params` holding an
  unmatched open brace and golds an rc=0 register).

* **`apply`'s union gains a third input — the type's own declaration, appended
  LAST.** Ladder **L2**, taking DD-4's *guarantee* sentence over its *mechanism*
  sentence. DD-13 alone leaves B5's other measured harm alive: with both lists
  owned, the union of the two has no row for the deleted parameter, so
  `_cards_for` still drops the `.save` card. **LAST**, not first, because
  `_show_set` filters the union *in union order*, so a declaration placed first
  would freeze the drawn order — which is exactly what DD-13 rejected its option
  (b) for. *Rejected:* (i) leaving the union at two lists and making B5 refuse
  any edit that shrinks it below the seed — a Delete that refuses on most of the
  PDK's shipped rows, with the ruling's guarantee living in the UI layer where
  the next caller of `apply` inherits the defect again; (ii) unioning with
  `seed $cls` rather than the type's own declaration — `seed` is
  first-lexical-wins across the class, so a sibling type that declares
  differently would lose its own rows.

* **The two `does not parse` reports moved with the read** and now name which
  list was dropped (`declaration` or `params`), keeping the literal substring
  `does not parse` that rows Z1/Z3 match on. Ladder **L2**. *Rejected:* leaving
  the wording — after an apply the two fields can differ, so the message would
  say *"params does not parse"* about a `params` that parses fine, which is
  invariant **I3**'s family one layer up.

## The sabotage matrix, INCLUDING the predicted reds that did not appear

| variant | predicted | observed |
|---|---|---|
| SB-NO-STAMP (`_declare` returns its argument) | N1 N4 N8 N9a N9b N10 N11 N12 | **exact match, 8/8** |
| SB-RESTAMP-ALWAYS (drop the `![dict exists]` test) | N1 N4 N10 N11 | N1 N4 **N8** N10 — **N11 did NOT fire** |
| SB-UNION-WITHOUT-DECLARATION (`_declared_rows` → `{}`) | N1 N2 N11 D5 | N2 D5 — **N1 and N11 did NOT fire** |
| SB-SEED-READS-PARAMS (`_decl_state` → `{0 {}}`) | N1 N4 N8 N10 N11 | N1 N4 N8 N10 — **N11 did NOT fire** |
| SB-RESTORE-NEVER (`_restore_applied` → `{}`) | N6 | **exact match, 1/1** |
| SB-RESTORE-BLIND (`_restorable` → 1, loop over `classmap`) | N7, A1 flagged possible | N7 A1 **+ N4 N6 Z3** |
| SB-PDK-DOC (drop the sentence from gf180 only) | C3 | **exact match**; C0 and C2 stayed green |

**The four misses are one root cause and it is filed as issue 1316.** N11 reads
all six of its terms *after* the `reset` + `apply` that ends its storm — and
that pair fires the issue-1292 undo, which repairs `params` one line before the
row looks at it. Measured mid-storm, SB-RESTAMP-ALWAYS leaves `declared` in the
**union's** order from step 1 onward, and SB-UNION-WITHOUT-DECLARATION loses the
`{gds gds 1}` triple and its `.save` card **inside N11's own storm** — the live
DD-4 violation, invisible to the row. N1's miss is separate and smaller: its
`params` leg is captured after the **first** delete only, where the still-unowned
summary list drags the row back into the union either way, and N1 has no cards
leg at all; **N2 is the row that carries that mechanism, and it does carry it.**

## Still open

* Issue **1316** — N11 and N12 fence less than they claim (the four misses
  above). The fix is a pure addition of terms to N11 and a rewrite of N12's
  assertion from a source-line count to an outside comparison.
* Issue **1315** — preserve-if-present means the documented I5 recovery
  round-trip no longer redeclares the seed. **STATUS E, a `rule` debt is owed.**
* Issue **1319** — `_merge_declared` re-reads through `_params`, doubling the
  malformed-list report for the common ownership shape.
* Issue **1320** — both class lists owned and EMPTY now yields the full
  declaration in `params` and flips `_claims` 0 → 1. Deck-only, DD-4-consistent,
  and it falsifies the risk note B2e was carrying.
* **Rule debt `1312` on the owed ledger is now MOOT** — it asked the user
  whether to accept B5's containment *or* fix 1312 with option (a). DD-13 chose
  option (a) and B2e implemented it. The live question is rule debt **1314**
  (which DD-13 answers) and rule debt **1315** (which nothing answers yet).
  Do not answer 1312's question twice; clear the entry.
