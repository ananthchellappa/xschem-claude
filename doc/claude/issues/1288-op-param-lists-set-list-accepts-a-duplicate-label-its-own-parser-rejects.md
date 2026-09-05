# 1288 — `op_param_lists::set_list` accepts a duplicate label its own parser rejects, and `_save_set` then drops a row silently

**Filed by:** item **B2a-2**, 2026-09-03. Found by B2a-2's adversary against the
reverted patch; **root cause re-measured by the write-up agent on the reverted
tree at `849f2231`**, where it is a **HEAD defect**, not a property of the
patch. (Filed as *not fixed*; see the Status line immediately below for where it
ended up.)

**Status:** ✅ **CLOSED**, 2026-09-04 by item **B5-3** — see the section at the
end of this file. (It was **HALF FIXED** between B2e and B5-3: the store half
landed in the tree, the button half existed only inside a reverted patch. The
body below still describes that intermediate state; the closing section is
authoritative.)

* **The store half — FIXED by item B2e (`21fcece6`/`0abba4cb`).** `_dup_index`
  and `_dup_why` are now *shared* by `set_list` and `_parse_line`, so the two
  doors reach the same verdict with the same sentence. Note the CONTRACT MOVED
  with the fix, and the rest of this file describes the pre-fix behaviour: a
  repeated **label** is now a **reduction, not a refusal** — the later triple
  replaces the earlier one in place, the user is told once, and `set_list`
  returns **1**. A malformed triple is still a refusal with no change at all.
* **The button half — WRITTEN AND THEN REVERTED WITH ITEM B5-2, 2026-09-04. STILL
  OPEN AGAINST THE TREE.** The fix exists, measured and sabotage-proved, but only
  inside `doc/claude/op_param_batch/B5-2_working_tree_REFUTED.patch` (md5
  `42890cf163dd9ba1e85e312e1801c6ed`) — item B5-2 was reverted in full for an
  unrelated blocker (issue **1322**), so nothing in `src/` carries it. It is
  latent meanwhile: there is again no UI door to `set_list`. The description
  below is what the re-do must re-land. The first UI door to
  `set_list` read the store's report only on the **rc=0** arm, so on the success
  arm — the one the new contract routes a label collision to — the sentence was
  dropped and the status line reported a plain success. Measured at HEAD: adding
  `{id vgs 2}` to `{{id ids 0} {gds gds 1}}` returns 1, reports *"the later one
  replaces it in place"*, and the untouched `ids` row is **gone**. IHP's shipped
  `{id ids 0}` is exactly that label != param shape. `rdw::_edit` now reads
  `rdw::_store_tail` on the success arm too and appends the store's own wording.
  The Add is **not** refused — a third door with a third rule is the
  disagreement this issue is about. Fenced by window row **BT27**; sabotaged
  (`rdw::_store_tail` stubbed to its fallback) and BT27 reds.

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

---

## ✅ CLOSED 2026-09-04 by item **B5-3**. The button half landed.

The store half was already fixed (`set_list` and the parser reach the same
verdict with the same sentence). What was left open was that **nothing read the
store's report on the SUCCESS arm** — `set_list` returns **1 with a report**
when it reduced the list by label, which is this issue's own ruled behaviour
("the later one replaces it in place"), and the preserved B5-2 patch read the
report only on the `rc=0` arm. So in the one case the ruling exists for, the
user was told **zero times**.

`rdw::_edit` now reads `rdw::_store_tail` on the success arm and appends the
store's own wording — never a second one for the same fact. Fenced by window row
**BT27** by name (an Add whose triple collides by label is ACCEPTED, replaces the
earlier row in place, and says so once) and by store row **BE6** (a refused Save
repeats the store's sentence rather than inventing a second). Sabotage
`store_tail_success_blind` — replacing `rdw::_store_tail`'s body with
`return $fallback` — reds both.

### ⚠ The "introduced by the fix, still open" residual above is REFUTED, not fixed

That paragraph predicts *"B5's scope dialog is the first door that could reach
it."* **It cannot.** Measured by reading the landed code: `rdw::_edit` builds its
flavor key as `[list $cls $cell]` — always exactly **two** elements — and
`rdw::_scope_for` returns `[lindex $g 1]` from `op_param_lists::governs`, whose
keys came through `_key` already canonicalised to two. **The button column cannot
mint a three-element flavor key.** The truncation itself still reproduces
verbatim (`_key flavor {mos *n* JUNK} annotation` is byte-identical to
`_key flavor {mos *n*} annotation`), so it stays open under issue **1294**, but
it is latent **and unreachable**, and it was not "fixed" by changing the store's
key canonicaliser — which is used as an array index, on the batch's last item,
for a door this feature provably cannot open. An uncanonicalised key as an index
is how item B2a-2 lost entries.
