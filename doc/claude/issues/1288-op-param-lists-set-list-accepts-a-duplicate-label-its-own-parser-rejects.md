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

---

## ATTEMPT 1 — item B2c, 2026-09-03: FIXED IN THE PATCH, NOT LANDED

The item was reverted for issue **1294**, in a different proc. This fix survived
the adversary without a counterexample and is preserved in
`doc/claude/op_param_batch/B2c_working_tree_REVERTED.patch`.

### ⚠ This issue's own §1 is imprecise, and the correction changes the fix

The text says the file parser *"rejects"* the duplicate row. **It does not.**
`_parse_line` **replaces in place** at the earlier index and keeps the **later**
triple, reporting once. Measured at HEAD:

```
set_list class mos annotation {{A ids 0} {A vth 2}}
  -> rc=1, ZERO reports, BOTH rows stored
the same two rows through the file parser
  -> rc=1, ONE report, ONE row stored: {A vth 2}
_save_set mos  ->  {A ids 0}          <- the user's LATER row silently dropped
```

So *"the same verdict and the same report text as the file reader"* (this
issue's §4) means `set_list` must **return 1 with a report and one row** — not
0 with a refusal.

### The ladder-L3 decision, because that contradicts `set_list`'s own contract

`set_list`'s written contract is *"Returns 1, or 0 **with a report and no change
at all**."* The two cannot both hold. **Taken: a malformed TRIPLE stays an
all-or-nothing refusal; a duplicate LABEL becomes a reduction returning 1**, and
the contract comment is amended in the same edit.

*Rejected:* returning 0 and refusing — it keeps the old contract but leaves the
two doors disagreeing, which is the entire defect. **On the user's queue as rule
debt 1288; the user can overrule.**

### What the patch does

`_parse_line:626-641`'s reduction is lifted into **two shared procs** —
`_dup_index {cur label}` → index or −1, and `_dup_why {label scope key
listname}` → the one sentence — called by **both** doors. `_parse_line` adds the
`<path>:<line>: ` prefix and the `: <line>` suffix; `set_list` says the bare
sentence. That is this issue's §3, *"a one-place change in the validator both
doors already share"*.

**`_save_set`, `_show_set`, `apply` and `_params` were not touched** (B2b's and
the driver's; rows Z0–Z4 stay green). They are consumers, not fix sites.

### Measured after (rows E1–E4)

| row | after |
|---|---|
| **E1** | `set_list … {{A ids 0} {A vth 2}}` → **1**, exactly **one** report, stores `{{A vth 2}}` |
| **E2** | the API report is **byte-identical** to the file report with the prefix and suffix removed, both computed in one run |
| **E3** | `_save_set mos` now carries the user's **later** row, and names label `A` exactly once (rule **R1**) |
| **E4** | position is kept: `{{A ids 0} {B gm 1} {A vth 2}}` → `{{A vth 2} {B gm 1}}` |

### ⚠ Knock-on: row D5's golden moves, and that is correct

Item **B2b**'s row **D5** was built **on this issue's open door** — its own
comment said *"Issue 1288 is LIVE on this tree"*. Closing the door changes its
golden from `{{A id 0} {A gm 1}}` to `{{A gm 1}}`, and `params`/`shown` follow.
B2c edited **only the golden and the prose**, kept the row's input unchanged, and
confirmed the row is still non-vacuous: sabotage **SB-DUP-BLIND** reds D5
alongside E1–E4. **Expect this move; it is not a regression.**

### ⚠ Introduced by the fix, still open

`_key`'s canonicalisation **silently truncates** a >2-element flavor key, so
`owns` and `get_list` answer for a key `set_list` refuses — **a new two-door
disagreement of exactly this class**. Recorded under issue **1294**. Latent;
B5's scope dialog is the first door that could reach it.
