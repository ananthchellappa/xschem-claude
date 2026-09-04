# 1287 — `op_param_lists::seed` reads the list `apply` overwrote, so the PDK's own list is gone from the running process

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


**Filed by:** item **B2a-2**, 2026-09-03. Measured by the Measure agent on the
tree at `849f2231`, re-measured from a fresh process. **FILED, NOT FIXED.**

**Status:** open. **Latent today** — nothing in `src/` calls
`op_param_lists::apply`; it becomes reachable the moment item **B5** wires the
button.

---

## 1. What was measured

`op_param_lists::seed` is the D-7 door: *"the seed comes from the PDK"*. It
reads `dict get $d params` (`_params`, `src/op_param_lists.tcl:598`) — and
`apply` **overwrites that same field**. So the seed answers whatever `apply`
last wrote, and `reset` cannot restore it, because `reset` clears this file's
own arrays and the clobbered value lives in `op_annot`'s descriptor.

Measure agent's transcript, verbatim:

```
seed | seed(mos) BEFORE any apply = {id id 0} {gm gm 1} {gds gds 1}   ->   AFTER apply + reset = {id id 0}
```

The PDK's own three-row list is **permanently gone from the running process**.
Only a re-`source` of the PDK's `_procs.tcl` brings it back.

> **A false-clean is easy to produce here and one was.** The Measure agent's
> first attempt read the "before" seed in a process that had *already* called
> `apply`, and got `{id id 0}` both times — a clean-looking no-op. The number
> above is from a **fresh process**. Any acceptance row that calls `apply` and
> then asserts a seed, or an `effective` fall-back, **is measuring the union**
> and will pass while the defect is live. Capture the seed before the first
> `apply`.

## 2. Why ruling DD-6 makes it worse, not better

**DD-6** (issue 1285) has `apply` write the **union** into `params`. The seed
therefore becomes the union — still not the PDK's list, and now silently
**wider** than what the PDK declared. A second `apply` then seeds from the first
one's union, so the list can only grow.

Item B2a-2's row **A7** (in the reverted patch) fences the one shape B5 actually
hits — `apply` run twice leaves `params` and `shown` byte-identical — which
contains the growth for that call pattern but does not fix the clobber.

## 3. The fix, and why it was not made here

The store must keep a **pristine copy of each descriptor's declared list**,
taken before the first `apply` touches it, and `seed` must read *that*;
`reset` must restore it. That is a new stash with its own lifetime question
(when is it captured for a type registered *after* the first apply — invariant
**I5**'s rc door allows exactly that), and it is outside issue range 1276–1285
that item B2a-2 was scoped to. Filed rather than fixed silently.

## 4. Acceptance for whoever takes it

* `seed <cls>` answers the **PDK's** triples after any number of `apply` calls.
* `reset` restores the seed to the PDK's list.
* A type registered *after* an `apply` still seeds from its own declared list.
* The row must capture the seed **in a fresh process before the first apply**,
  or it fences nothing (§1).

---

# What B2e landed (2026-09-04)

This issue's **stated acceptance rows** are now true, and they were false when
it was filed.

## The BEFORE line, quoted verbatim from B2e's Measure agent

Tree at `ee61aa4a`. A row the **user** adds to her annotation list becomes "the
PDK seed" and survives `op_param_lists::reset`:

```
seed_after_add         = {id ids 0} {gm gm 1} {gds gds 1} {MINE mine 1}
seed_after_reset       = {id ids 0} {gm gm 1} {gds gds 1} {MINE mine 1}
```

So this file's own acceptance row — *"`reset` restores the seed to the PDK's
list"* — was **false**.

## The AFTER lines

Ruling **DD-13** (issue **1312**) gives the descriptor a third list, `declared`,
written by `op_annot::register` alone under a preserve-if-present stamp and read
by `op_param_lists::_params` alone. `seed` therefore answers the declaration and
no edit reaches it.

Against this file's four acceptance rows, one by one:

* **"`seed <cls>` answers the PDK's triples after any number of `apply` calls."**
  Measured over a 40-edit storm and, separately, over a 200-cycle apply storm:
  `declared` and `seed mos` byte-identical to the PDK's three rows throughout
  (rows **N1**, **N11**; Verify-C's own probes).
* **"`reset` restores the seed to the PDK's list."** Rows **N6** and **N11**.
* **"A type registered *after* an `apply` still seeds from its own declared
  list."** True by construction — the stamp happens at registration, which is
  precisely the *hard part this file named for itself* in §3 and could not solve
  with a pristine-descriptor stash. Row **N9b** measures a user's own bare
  `op_annot::register` in her rc: `seed mos` answers her list on the next call,
  no restart (invariant **I5**).
* **"The row must capture the seed in a fresh process before the first apply, or
  it fences nothing."** Honoured: section N's rows capture in a fresh process
  and row **N0** is a green-before-and-after control proving the fixture can
  actually reach the states the rows name.

## Why §3's proposed stash was NOT built

This file's §3 proposes a pristine-descriptor stash and names its own hard part:
*"when is it captured for a type registered AFTER the first apply (I5)."*
DD-13's declaration key answers that for free — it is captured at registration,
by definition — so the stash was not built for `params`. Ladder **L2**;
*rejected* precisely because the key is cheaper and has no capture-time question
at all.

What **did** need a stash is only issue **1292**'s `shown`, whose *absence* is
meaningful and cannot be recovered from any key, and only for the types `apply`
itself rewrote. That is the `applied` session record; see 1292's own
"What B2e landed" section.

## Still open

Nothing specific to this file. The residuals live on issues **1315** (status E,
a `rule` debt), **1316**, **1317**, **1318**, **1319** and **1320**.
