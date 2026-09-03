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
