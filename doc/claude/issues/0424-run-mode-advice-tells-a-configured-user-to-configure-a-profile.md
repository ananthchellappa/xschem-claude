# 0424 — `ase::run_mode_advice` tells a user who just configured a profile to configure a profile

**Status:** OPEN. Measured on branch `fluid-editing` at `e998e853` (casemode batch item 13).
Documentation only — nothing fixed.
**Area:** `src/ase.tcl:990`, `ase::run_mode_advice`, and its `status default` test.
**Found:** 2026-08-17 by the casemode batch item-13 verifier (its PROBLEM 2), outside
that item's confirmed finding set and outside its scope fence. Named in
`doc/claude/casemode_batch/receipts/13-simulator-dialog.md` §5 as "it needs its own
item". Filed here by the driver.
**Related:** item 8 built the advice (`doc/claude/specs/simulator_profiles.md` §12);
item 13 is what makes this reachable by gesture.

**The diagnostic is not merely unhelpful — it asserts two things that are false and
then instructs the user to repeat the action they have already taken.**

---

## Mechanism

`ase::run_mode_advice` decides which lever to name by asking whether
`sim_profile_resolve` returned status `default`:

```tcl
set floor [expr {[dict get $p status] eq {default}}]
```

`status default` was intended to mean "this session has no profile row, so the request
came from the global floor `sim_case_mode`" — in which case there genuinely is no row to
re-point and no `-n` checkbox to turn on, and naming those levers would be wrong. Item 8
was careful about exactly this: its own spec ruling is "the advice must name a lever that
exists".

But `sim_profile_resolve` returns `default` **whenever the session names no explicit
`sim_profile` key**, which is not the same question. A user can configure a profile row
fully — exe, args, casemode, probed — and still have a session that does not *name* one.
For that user the refusal prints:

> This session has NO simulator profile row — the request came from the global floor
> 'sim_case_mode'. Set sim_case_mode to a mode this binary delivers, or configure a
> profile (Simulation > Configure simulators and tools) naming a simulator that supports
> distinguish.

Both clauses of the first sentence are false, and the second sentence tells the user to
do the thing they have just done.

## Why it matters more now

Reachable by a hand-edited `simrc` since item 6. **Item 13 makes it reachable by
gesture**: the dialog is precisely where a user configures a profile row, so the most
likely person to see this message is the one for whom it is most wrong.

## What a fix has to decide

1. **Separate the two questions.** "Did the session name a profile?" and "does a usable
   profile row exist for this tool?" are different, and only the second should select
   the floor-flavoured advice.
2. **Check whether `status default` has other readers** before changing its meaning —
   item 8's mismatch reporting and item 9's `sod_case_mode` both consult the resolve.
   Changing the status vocabulary is the wider fix; changing only the advice's test is
   the narrow one.
3. **Item 8's rule still governs:** the advice must name a lever that exists. A fix that
   makes the message technically accurate but names a control the user cannot reach has
   not fixed it.

## What is NOT claimed here

Nobody has checked whether the *non*-floor branch has the mirror-image defect, or
whether any other message keys off the same `status default` test.
