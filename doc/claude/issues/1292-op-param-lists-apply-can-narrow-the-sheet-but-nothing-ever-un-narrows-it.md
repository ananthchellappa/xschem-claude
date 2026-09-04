# 1292 — `apply` can narrow the sheet but nothing ever un-narrows it: a stale `shown` survives `reset`

**Filed by:** item **B2b**, 2026-09-03, from Verify-C's adversary pass,
re-measured by the write-up agent.
**FILED, NOT FIXED.** Latent until item **B5** ships the button that calls
`apply`; user-visible the moment it does.

**Status:** open. This is the **sheet-visible half** of issue **1287** and is
listed separately because 1287 is about the *seed* the store reads back, while
this is about what the *schematic draws* and about a button B5 has to build.

---

## 1. What was measured

On the landed tree, one process, a descriptor registered with three `params`
rows:

```
APPLY1=nmos
SHOWN1={id id 0}
OWNS_AFTER_RESET=0
APPLY2=
SHOWN2={id id 0}
PARAMS2={id id 0} {gm gm 1} {cgg cgg 1}
SEED_AFTER={id id 0} {gm gm 1} {cgg cgg 1}
```

Read it as: narrow to one row, then drop **every** user list
(`op_param_lists::reset`, after which `owns` answers 0) and apply again. `apply`
returns the empty list — its `_apply_owns` guard `continue`s a class the user
owns nothing for, by design — so the **stale `shown` stays on the descriptor**
and the sheet stays narrowed for the rest of the session.

`grep -n 'dict unset\|shown' src/op_param_lists.tcl` confirms it: `apply` is the
only writer of the key and there is **no code path anywhere that removes it**.

## 2. Why the guard is not simply wrong

`apply`'s "a class the user owns nothing for is left strictly alone" rule is
deliberate and predates B2b: re-applying the seed over the PDK's own descriptor
would bump the generation counter and rewrite a dict this file does not own. It
is right for `params`. It is wrong for `shown`, because `shown`'s **absence is
meaningful** — absent is the only value that means "draw every row" — so
"leave it alone" and "restore the PDK's behaviour" are different outcomes, and
only the first is reachable.

## 3. What it costs

* **B5's Reset / Defaults button will not work** if it is built on
  `reset` + `apply`. The lists go back to the PDK's; the schematic does not.
* Together with issue **1287** (the seed is now the *union* after an apply) the
  session has **no route back** to the PDK's own drawing short of restarting
  xschem or re-registering the descriptor by hand from an rc (**I5**).
* It is silent. No report, no visible difference in the RDW — only the sheet
  disagrees with the lists.

## 4. Options, costed but not chosen

1. **`apply` unsets `shown` for a class the user owns no annotation list for.**
   Smallest, and it makes absent-means-everything true again. But it writes to a
   descriptor for a class the user owns nothing for, which is the exact thing
   the existing guard exists to avoid, so it needs its own narrow justification:
   removing a key *this file wrote* is not the same as rewriting a PDK's dict,
   and that distinction should be stated in the code if this option is taken.
2. **A pristine-descriptor stash**, which is also issue **1287**'s fix. One
   snapshot of every descriptor `apply` has ever touched, restored by `reset`.
   Fixes both defects at once and is the honest design; costs a store.
3. **Leave it and document it**, i.e. `reset` does not restore the sheet.
   Rejected as a default: an undo that undoes half of what it did is worse than
   one that says it cannot.

## 5. Still open

Which option, and whether it is B5's work (the button that exposes it) or a
follow-up to 1287 (the store that should own the stash). Nobody is assigned.
