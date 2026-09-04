# 1292 — `apply` can narrow the sheet but nothing ever un-narrows it: a stale `shown` survives `reset`

> # ✅ FIXED by item **B2e**, 2026-09-04, commit on branch `fluid-editing`.
> `op_param_lists::apply` now RECORDS what it wrote (namespace variable
> `applied`, one entry per type, holding the pre-apply and the written
> `{present value}` state of `params` and `shown`) and, on a later `apply` over
> a class nobody owns any more, **un-does exactly its own write, in full or not
> at all** — including `dict unset`ing `shown`, which no verb could do before.
> The undo fires only when both fields are still byte-identical to what apply
> left, which is §4 option 1's demanded distinction made checkable rather than
> stated. `reset` deliberately does NOT clear the record: `reset` + `apply` IS
> the undo the record exists to serve.
> **Read the "What B2e landed" section at the bottom of this file for the AFTER
> transcript and for what stayed open.**


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

---

# What B2e landed (2026-09-04)

## The BEFORE lines, quoted verbatim from B2e's Measure agent

Tree at `ee61aa4a`. Own the annotation list, `apply`, `op_param_lists::reset`,
`apply` again:

```
shown_STILL            = {id ids 0}
params_STILL           = {id ids 0} {gm gm 1} {gds gds 1}
keys_after_register      = devpath params
keys_after_apply         = devpath params shown
has_shown_after_reset    = 1
```

`apply_after_reset` returned **EMPTY** — the `_apply_owns` `continue` — so the
sheet stayed narrowed for the rest of the session with nothing owning it. And as
a grep fact: `dict set d2 shown` was the **only** writer of the key in the tree,
and `dict unset … shown` occurred in **zero** files under `src/`.

## The AFTER lines

Row **N6**: own annotation `{{id ids 0}}`, `apply` (the sheet narrows),
`op_param_lists::reset`, `apply` —

* `ol_dkey nmos shown` is **NOKEY** again,
* `params` is back to its pre-apply value,
* the return list names **both** `nmos` and `pmos`,
* `::op_annot::gen` **moved** (the restore goes through `::op_annot::register`
  and through nothing else — a direct `set ::op_annot::desc(…)` would be correct
  Tcl, would not bump the counter, and would leave the sheet narrowed until an
  unrelated redraw: invariant **I5** failing silently),
* `op_annot::text M1` draws every `params` row again.

Row **N7**, the restraint half — the restore reaches **only** what apply itself
wrote: `vertical_npn`, a class the user never owned and apply never wrote, is
byte-identical before and after; and a `shown` written by someone **other** than
apply (re-registered between the apply and the reset) is left alone.

Adversarially, beyond the suite (Verify-C, and B2e's own 40-edit probe):

* after a 40-edit storm, `reset` + `apply` restores `params` to the PDK's three
  rows and removes `shown`; a **second** `apply` returns `{}` and changes
  nothing — the undo is not repeatable and does no damage;
* a type the user class-mapped **herself** is still restorable after `reset`
  wipes `classmap` back to the shipped map;
* the undo correctly **restores** a `shown` a PDK shipped itself
  (present → present), not merely removes one apply created;
* re-driven with 3 and with 200 intervening applies, it restores the state
  before the **first** apply, not the state before the last.

## The decisions, with their ladder rung and their rejected alternative

* **The undo un-does exactly apply's own write, in full or not at all** — both
  `params` and `shown`, and only when **both** are still byte-identical to what
  apply wrote. Ladder **L2**. This is §4 option 1's demanded distinction —
  *"removing a key THIS FILE wrote is not the same as rewriting a PDK's dict"* —
  made real in code instead of stated in a comment, per landmine 23.
  *Rejected:* unsetting `shown` for every unowned class (it reaches
  `vertical_npn`, reds row A1, and rewrites dicts this file never wrote);
  restoring `shown` alone (an undo that undoes half of what it did — §4 option
  3's own rejection); a pristine-descriptor stash for `params` as issue 1287 §3
  proposes (DD-13's declaration key answers that half at zero cost, and 1287
  names its own hard part — capture time for a type registered *after* the first
  apply — which the registration stamp answers by definition).

* **`reset` does NOT clear the session record, and bare `apply`'s candidate set
  becomes `[array names classmap]` + `[array names applied]`.** Ladder **L2**.
  `reset` + `apply` **is** the undo the record exists to serve, and `reset`
  wipes `classmap` back to the shipped defaults — so a type the user
  class-mapped herself would otherwise be un-restorable forever. *Rejected:*
  clearing the record in `reset` (it makes this issue unfixable by the very pair
  of verbs the issue names) and leaving the candidate set alone (the defect
  survives in the corner a user extended the map for).

## A bug the implementer introduced and caught with a probe, not with the suite

Worth reading, because it is this batch's own lesson happening again. The first
version passed `$d` as the pre-state to `_record_applied`. In Tcl
`dict set d params …` **writes back into the variable** as well as answering the
new dict, so by that line `$d` was already the *post*-apply descriptor and every
record's pre-state equalled its own write — the undo restored the state before
the **last** apply instead of the state before the **first**.

**The suite was ALL PASS at 102 with the bug in.** Rows N6 and N11 cannot reach
the state that distinguishes the two, because in both of them the first apply's
pre-state and the last apply's pre-state happen to be the same value. The
40-edit adversarial probe written *outside* the suite caught it in one line.
Fixed by passing `[lindex $e 1]`, which the dict writes cannot touch; the reason
is written into the code beside the call.

**The row that is still missing:** *after N applies, `reset` + `apply` restores
the state before the FIRST apply, not the state before the last.* Verify-C
re-drove it by hand with 3 and with 200 intervening applies and it holds — but
nothing in the tree fences it. That gap is recorded here and in issue **1316**.

## Still open

* The missing N-applies row above.
* Issue **1317** — `_restorable` decides "apply's own write" by byte equality on
  two fields, not provenance. Contrived to reach; the realistic neighbour is
  benign; three options costed.
* Issue **1318** — `apply`'s return list now conflates the types it NARROWED
  with the types it RESTORED. Harmless today, and it **binds B5-2**.
