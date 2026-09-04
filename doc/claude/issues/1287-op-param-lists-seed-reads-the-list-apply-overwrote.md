# 1287 — `op_param_lists::seed` reads the list `apply` overwrote, so the PDK's own list is gone from the running process

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
