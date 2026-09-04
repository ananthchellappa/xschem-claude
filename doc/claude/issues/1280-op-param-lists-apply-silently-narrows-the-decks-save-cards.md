# 1280 — `op_param_lists::apply` silently narrows the deck's `.save` cards, so list 2 can go permanently blank

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass,
2026-09-03. Latent: nothing calls `apply` yet. **This is the most consequential
of the six B2 seam defects**, because its symptom is a blank number on a
schematic with no report anywhere.

## The coupling

The three lists are specified as independent — list 1 annotates the sheet, list
2 is the summary dump, list 3 is what the run holds. They are **not**
independent, because both the display and the **deck** read the same field:

* `op_annot::_cards_for` (`src/op_annot.tcl:2808-2820`) emits **one `.save` card
  per `params` row** of the descriptor.
* `op_param_lists::apply` writes the **annotation** list into `params`.

So the annotation list silently bounds what any other list can ever contain.

## The measurement (2026-09-03, IHP `sg13g2`)

Trimming the annotation list to two rows and applying makes `params` those two
rows, and the generated deck stops saving `gds`, `vgs`, `vth` and `vds`. The
store's own **summary** list still asks for all six. By measured rule **R1**
those four parameters *exist in the raw only if the deck saved them
explicitly* — so the summary's four rows render **blank, forever**, and nothing
tells anyone why.

Invariant **I3** says a missing vector renders blank rather than a wrong
number, and that is correct behaviour for a run that did not compute the value.
Here the value was never *asked for*, because of an edit the user made to a
different list.

## Why the suite did not see it

`grep -c 'save_cards\|_cards_for' tests/headless/test_op_param_store_1245.tcl`
= **0**. Row A1 asserts that `apply` goes through `op_annot::register`, that
`gen` moves and that the descriptor's other keys survive. It never asks what
the deck then saves. The store's suite and the deck's suite each fence their
own side of a field they share.

## Recommended fix — one of two, and the choice is a ruling

**Option 1 (recommended): `apply` writes the UNION of the annotation and
summary lists into `params`, and the display narrows to the annotation list.**
`params` then means what `_cards_for` already treats it as — *"what this device
must save"* — and the annotation list becomes purely a display decision, which
is what §4.1 already says it is. Nothing is invented: every row in the union
was declared by the user or by the PDK.

**Option 2: leave `params` alone and give the descriptor a separate display
key.** Cleaner in the abstract, but it edits `op_annot.tcl`'s dict shape, which
item B2 may not do and which every existing consumer would have to learn.

**Rejected: reporting the narrowing and shipping it.** A sentence at Save time
about a number that will be missing after the *next* simulation is a sentence
nobody will connect to the blank they eventually see.

⚠ **Option 1 is a user-visible choice about what a Delete means** — does
removing `vth` from the sheet stop the deck saving `vth`, or only stop drawing
it? That is a question for the user, and it belongs with the item that ships
Delete (**B5**), not with the store.

## Acceptance rows this needs

* A3 — after `apply` with a trimmed annotation list and a full summary list,
  `op_annot::_cards_for` still emits a card for every summary parameter.
* A4 — a parameter in **neither** list gets no card, so the fix is not a
  save-everything.

## Who inherits this

**Item B5.** It owns Delete, Add and Save, and it is where the ruling above has
to be asked.

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **THE SAVE HALF IS FIXED**, 2026-09-03. THE DISPLAY HALF IS ISSUE 1285 AND BLOCKS B5.)


Ruling **DD-4** (DECISIONS.md, driver decisions) settles this issue as its own
**Option 1**: *Delete is a display decision, never a save decision.* `apply`
writes the **union** of the annotation and summary lists into `params`, and the
display narrows to the annotation list.

## What landed (`src/op_param_lists.tcl`)

New `_save_set {cls}`: the union of `effective $cls annotation` and
`effective $cls summary`, **deduped by LABEL with the annotation triple
winning**. `apply` now runs in **two passes** — every class's save set is
computed before anything is registered, because `_save_set` reads the PDK seed
through `::op_annot::descriptor` and the second pass rewrites exactly those
descriptors; one loop would let the first type applied change the seed the
second type reads.

⚠ **The union is taken over `effective`, not `get_list`, and that is the whole
fix.** With the summary **unowned**, `effective` answers the PDK seed, so the
union is a **superset** of what `params` held before and the deck can never lose
a card. That is precisely the measured 6 → 2.

**Rejected: unconditionally adding the PDK seed as well.** It over-reads DD-4 —
`params` could then never shrink at all, so clearing *both* lists could not
reduce the deck, and DD-4 says a "stop saving this" control would be a separate
control with a separate name. **Rejected: unioning only the OWNED lists** — a
summary-only customisation would then narrow `params` below the seed, which is
this issue again one door over.

**No `src/op_annot.tcl` edit was needed.** `_cards_for` already treats `params`
as "what this device must save", and B1's landed seam contract is untouched.

## Red before green

| row | red on | green after |
|---|---|---|
| `A3` DD-4, live one-instance fixture | **6 `.save` cards before `apply`, 2 after**; `params` = `{id ids 0} {vth vth 2}` | 6 before, **6 after**, same set, the annotation list's own two first |
| `A4` the counterweight | a label in the SUMMARY alone got **no** card | it gets one; a label in neither list still gets none; `effective <c> annotation` still answers the annotation list by itself |
| `A1` | `params` = the annotation list alone | `params` = the union (the user's two rows, then the PDK seed's six) — **this golden's move IS the fix** |

Sabotage, with the fix in place: `SB-SAVE-NARROW` (`_save_set` →
`effective $cls annotation`, today's narrowing) → **A1, A2, A2b, A3, A4 red**,
`RESULT: 5 FAILED (51 passed)`.

## ⚠ DD-4'S SECOND CLAUSE CANNOT LAND IN B2a — SEE ISSUE 1285

MEASURED: `op_annot::text` (`src/op_annot.tcl:1726`, the `params` loop at `:1741`)
builds the **on-sheet
annotation rows** by iterating the **same** `dict get $d params` list that
`_cards_for` turns into `.save` cards. So DD-4's first clause (`apply` writes
the union into `params`) and its second (the display narrows to the annotation
list) **cannot both be true of one field**, and B2a owns four files of which
`op_annot.tcl` is not one.

B2a implements the SAVE half — the half whose failure is silent, destructive and
invisible on a schematic (invariant **I3**). The DISPLAY half is filed as issue
**1285** and is a **hard blocker for item B5**: until it lands, a user who
deletes a row from the annotation list will see the deck keep saving it
(correct, per DD-4) **and** see the row still drawn on the sheet — the opposite
of the user's own word *declutter*. The store's narrowing is already to hand:
`effective <c> annotation`, which row A4 asserts by name for exactly that reason.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.

---

## Item B2a-2 — REVERTED A SECOND TIME, 2026-09-03, AGAIN AS COLLATERAL

**This issue's own fix was still not refuted.** Item **B2a-2** re-applied
B2a's patch unchanged, re-fixed the three holes, added ruling **DD-6**'s display
key, and went green everywhere — store **39→71**, RDW window **32→49** headless
and **42→59** on `:99`, `test_op_annot` **485/492** and
`test_annot_declutter_1244` **134** all unmoved, audit back at the 367/12/0/2
baseline with an empty non-PASS diff.

**It was reverted anyway**, because the adversary refuted the central claim on
**1277**, **1281** and **1285** and the write-up agent reproduced **four**
attacks first-hand. Same reasoning as the first revert: the diff was one
2,838-line change across eight files, and splitting it at write-up time would
commit code no verification pass had ever seen.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a-2_working_tree_REVERTED.patch` (md5
`1977a39e5d419d31fcbbbc3932c2606f`, 3,573 lines, eight files) **applies clean to
`849f2231`** — verified with `git apply --check` in both directions. It contains
**both** attempts: B2a's six sound fixes *and* B2a-2's re-fixes. This issue's
portion should survive the third pass unchanged; apply the patch and fix only
what §"Still open after B2a-2" in **1277**, **1281** and **1285** names.
