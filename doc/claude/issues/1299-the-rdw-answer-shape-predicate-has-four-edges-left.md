# 1299 — four edges the RDW's answer-shape predicate still leaves open

**Status:** FILED, NOT FIXED. All four measured by item **B2d**'s adversary
(Verify-C) on the fixed tree, re-measured by the write-up agent. **Unreachable
through the shipped ngspice backend**, reachable by any third-party backend the
**D-5** seam exists to admit — which is the same reachability class as every
shape issue **1284** *did* close.

**File:** `src/rdw.tcl` — `rdw::_answer_flaw` (:316), `rdw::_named` (:314),
`rdw::_bucket_width` (:313), `rdw::_nonfinite_text` (:177).

---

## 1. The four

### (a) a device that names nothing

`_named` closes *"a value belonging to no parameter"*. Nothing closes the same
question one level up:

```
devices {{} {{id 1.5}}}        ->  a blank device sub-header above real numbers
devices {{   } {{id 1.5}}}     ->  the same, whitespace
devices {@m.x1.m1 {}}          ->  a device sub-header with zero rows under it
```

That is the "blank row that means nothing" `_answer_flaw`'s own comment
rejects, one level up from where the predicate looks.

### (b) `_nonfinite_text` still discards its argument

`_bucket_width` now requires the seam's `{<rawdev> <param> <text>}` **triple**,
so an entry carrying no evidence is rejected. But the third field is still never
read: `{@m.x1.m1 gm hello}` and `{@m.x1.m1 gm EXTRA junk}` both render
`(did not converge)`. The shipped rationale — *"the window made an assertion on
NO evidence, because the raw was never quoted"* — is equally true of a 3-field
entry whose third field is junk. The **filed shape** is closed; the **stated
reason** is not yet satisfied.

### (c) malformed-by-excess truncates in silence

The predicate is a **minimum**-arity check, so `{id 1 2 3}` renders `id : 1` and
drops `2 3` with no sentence. A backend that pads its entries loses data
invisibly — the mirror image of the underspecified class B2d closed.

### (d) the two gates disagree by exactly one shape

`_named` uses `string trim`; `ase::op_param_split` (src/ase.tcl:3782) uses exact
empty (`$p eq {}`). A whitespace-only parameter name is therefore **legal to the
seam and a flaw to the window**, and neither gate cites the other.

## 2. And one that is a wording question, not a shape

The flaw verdict is **whole-answer**: an answer carrying twenty well-formed
devices and one unnamed pair renders the flaw sentence and nothing else — all
twenty-one suppressed — while the sentence says *"nothing is shown for **this
device**"*, singular. That is consistent with issue 1284 §4 item 2 as written
and raises nothing, but the wording under-states what was withheld, and a
partially good answer now shows **less** than it did at HEAD.

## 3. Options

* **(a) Extend `_named` to the device key and require a non-empty row list**,
  closing (a) with the predicate that already exists. Smallest, and it is the
  same one-line shape as `_named` itself.
* **(b) Make `_nonfinite_text` read its argument** — render the words only when
  the text is one of the non-finite spellings the raw actually uses, and treat
  anything else as a flaw. Closes (b) and (c) for that bucket, and finally makes
  the proc's argument load-bearing.
* **(c) Exact arity rather than minimum**, closing (c) everywhere. Blast radius
  is every bucket at once; wants its own sabotage row per bucket.
* **(d) Align `_named` with `ase::op_param_split`**, or make the seam trim.
  Either direction is one line; the pair must cite each other whichever wins.
* **(e) Name the count in the flaw sentence**, or degrade per device rather than
  per answer. A wording change, so it is the user's, not a crew's.

**Recommendation: (a) + (b) as one small item; (c) and (d) costed but deferred;
(e) is a `rule` debt, not a fix.**

## 4. Acceptance

* Each of the four shapes above gets the malformed-answer sentence, or a
  recorded reason why it does not.
* Rows F17–F20 and F27–F29 stay green, and each new clause has a sabotage handle
  of its own (a named one-line predicate, per B2d's precedent).
* No live path moves: `ase::op_param_set` still renders byte-identically.
