# Decisions — the cross-checkout numbering collision

These are the user's rulings. They override the spec, the plan, and any
adversary finding. If your item seems to need something a decision forbids,
**stop and say so in your write-up** — do not implement around it.

## D-1 — this branch only

> *"proceed to fix collisions on this branch. Don't worry about op-wcard for now."*

**Nothing in `/home/analog/dev/xschem-op-wcard` may be read-modify-written,
renamed, committed, or rebased by this batch.** Reading it to measure is fine
and is how most of the evidence here was gathered. Editing it is out of scope
by ruling, not by difficulty.

That rules out the option the design work recommended first — moving op-wcard's
`next free number` pointer off 1349. It stays aimed at 51 numbers this branch
committed on 2026-09-05, and this batch cannot fix it. **Say so in the write-up
rather than quietly working around it.**

## D-2 — the two trees will become one

> *"That branch's work will be absorbed into this one soon"*

This is the ruling that shapes everything else. A merge was measured, not
inferred (scratch clone, merge-base `28dabfe8`, `git merge --no-commit`):
`NUMBERING.md`, `src/ase.tcl`, `src/op_annot.tcl` and
`tests/headless/test_op_dump_altshow.tcl` conflict, and **all 14 colliding issue
files land as clean adds with no conflict at all**. The merged tree would then
hold two `1338`s, two `1339`s and so on, inside one checkout, permanently — and
the only file that would have flagged it is the one a human resolves as prose.

So the deliverable is not a tidy-up. It is **making the absorption safe before
it happens**, from the only side we are allowed to touch.

## D-3 — the band, and who moves (UNRATIFIED — carried as a rule debt)

The assistant's recommendation, recorded here so it is visible as a decision
and not smuggled in as an implementation detail:

* **op-wcard's numbers move, this branch's do not.** Six to ten of this
  branch's commit subjects naming band numbers are ancestors of
  `origin/fluid-editing` and are published; op-wcard has no remote branch at
  all and three local subjects. Renumbering published subjects is not
  available; renumbering unpublished ones is.
* **`1333–1348` → `1500–1515`,** a single `+167` offset. Source and target
  bands are disjoint, so a rewrite cannot alias, and the arithmetic is
  checkable by eye.
* **`1500–1599` is reserved and skipped by this branch:** after **1499** the
  next number here is **1600**.

**This is the user's call, not the batch's.** It is recorded as a `rule` debt
against issue **1400**. The batch implements the reservation and publishes the
map; it does not renumber anything.

## D-4 — the shared ledger is append-only for this batch

`~/.claude/xschem_owed/` is shared with a live op-wcard session that was
measured writing to it mid-audit. This batch may **add** `repo:` lines to
existing entries. It may **not** delete, rename, or rewrite line 1 of any
entry, and it may not run `owed.sh clear` against the real ledger. Take a
`cp -a` backup before any stamping pass.

A `rule` or `look` debt clears **only when the user says so** — that rule is
what this batch is defending, so it may not be the batch that breaks it.
