# 1318 — `op_param_lists::apply` returns one list holding two opposite meanings

**Filed by item B2e's Verify-C (adversary) pass, 2026-09-04. Measured, NOT
fixed.** Status: **open — harmless today, and it BINDS the re-land of item B5
(B5-2).**

---

## 1. What changed

Before B2e, `apply` returned *"the list of types re-registered"* — every one of
them **narrowed** to the user's lists.

B2e added the issue-1292 undo, and its restored types are appended to the same
list:

```tcl
foreach t [_restore_applied $undo] { lappend done $t }
return $done
```

So one flat list now names both:

* types whose descriptor apply **narrowed** (the user's lists were written in),
  and
* types whose descriptor apply **put back** (the user's lists were removed).

Those are opposite outcomes and a caller cannot tell them apart.

## 2. Why nothing breaks today

Measured: `op_param_lists::apply` has **no functional caller anywhere** in
`src/`, `xschem_library/` or any of the three PDK trees — every hit outside its
own file is inside a comment. The refuted B5 patch's `rdw::_apply_now` calls it
and **ignores the return value**.

## 3. Why it binds B5-2

B5's status line is the first thing that will want to say *what just happened*,
and the obvious sentence — *"updated N device types"* — is now wrong for half
the cases it will meet. A Reset/Defaults press is precisely the press whose
types are all **restores**, and it is the press whose status line most needs to
be accurate, because nothing else on screen says the sheet went back.

**B5-2 must not read this list as a single meaning.** Either it ignores the
return (what the preserved patch does), or this issue is fixed first.

## 4. Options

1. **Return a dict**: `{applied {…} restored {…}}`. Honest; breaks no caller
   because there is none; is a shape change a later caller cannot get wrong.
   **Recommended.**
2. Return two lists. Same information, worse to extend.
3. Leave it and document it. The cheapest, and it puts the trap one function
   call away from the person most likely to fall into it.

## 5. Still open

Which option, and whether it lands with B5-2 or before it. Nobody is assigned.
