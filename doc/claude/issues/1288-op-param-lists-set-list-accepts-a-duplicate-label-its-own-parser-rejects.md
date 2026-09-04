# 1288 — `op_param_lists::set_list` accepts a duplicate label its own parser rejects, and `_save_set` then drops a row silently

**Filed by:** item **B2a-2**, 2026-09-03. Found by B2a-2's adversary against the
reverted patch; **root cause re-measured by the write-up agent on the reverted
tree at `849f2231`**, where it is a **HEAD defect**, not a property of the
patch. **FILED, NOT FIXED.**

**Status:** open. **Latent today** — nothing calls `set_list` outside the two
suites; item **B5**'s scope dialog is the door that opens it.

---

## 1. The two doors disagree about the same rule

The store has two ways in. `_parse_line` (the file reader) rejects a second
triple carrying a label it already saw, and reports it. `set_list` — the **API**
door, the one B5's dialog will call — checks no such thing.

Measured by the write-up agent on the **reverted** tree (i.e. this is HEAD's
behaviour, with no B2a-2 code present):

```
set_list dup-label 'A': rc=0 r=<1>
get_list                : <{A ids 0} {A vth 2}>
```

`rc=0`, the call **reports success**, and both rows are stored. A file
containing those same two rows is refused with a report. The same store, the
same content, two answers.

## 2. Why this is more than an inconsistency

Two consumers reduce the list by label and they disagree about which row wins:

* `_save_set` (`src/op_param_lists.tcl:1302` in the reverted patch) dedups by
  **label** — `seenl($l)` — keeping the **first**, so `{A vth 2}` never becomes
  a `.save` card.
* the display list (**DD-6**'s `shown`) is the annotation list **unreduced**, so
  `{A vth 2}` **is drawn**.

The consequence, measured by B2a-2's adversary on the patched tree, is that
**ruling DD-6's own subset guarantee fails**:

```
params = {A ids 0} {id ids 0} {gm gm 1}
shown  = {A ids 0} {A vth 2}
```

`{A vth 2}` is drawn and is **not in `params`**, so `op_annot::_kind MT0 vth`
and `op_annot::vector MT0 vth` both **raise**. B2a-2's own code comment asserted
the opposite in writing —

> `shown` is always a SUBSET of the union by construction, which is what keeps
> `op_annot::_kind` total

— and that sentence is **false while this issue is open**, whoever re-does DD-6.
Same run: `_cards_for` emits `.save @m.mt0[ids]` **twice**, against measured
rule **R1** (one card per device per parameter).

## 3. The fix

`set_list` must apply the **same duplicate-label rule its own parser applies**,
and report it the same way. That is a one-place change in the validator both
doors already share (`_key_why`'s sibling for triples); it was not made in
B2a-2 because the item was scoped to issues 1276–1285 and this is neither of
them, and because a validator change moves rows in a suite the item was required
to leave unmoved.

**Do not fix it by making `_save_set` and the display agree instead.** Both
reductions are correct for their own consumer; what is wrong is that the store
accepted an input its own grammar forbids.

## 4. Acceptance

* `set_list` with two triples sharing a label returns the same verdict and the
  same report text as the file reader given the same two rows.
* After the fix, `shown ⊆ params` holds for every list `set_list` accepts, and a
  row asserts it **structurally** rather than on one fixture.
* `_cards_for` never emits the same `.save` card twice (rule **R1**).
