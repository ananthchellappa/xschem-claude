# 1317 — the issue-1292 undo identifies "apply's own write" by byte equality on two fields, not by provenance

**Filed by item B2e's Verify-C (adversary) pass, 2026-09-04, against the change
B2e landed. Measured, NOT fixed.** Status: **open — contrived to reach, and the
realistic neighbours are benign.**

---

## 1. What the code promises

`op_param_lists::_restorable` is the guard that decides whether `apply` may put
a descriptor back when its class is no longer owned. Issue **1292 §4 option 1**
asked, in so many words, for the distinction to be **real** rather than stated:

> *"removing a key THIS FILE wrote is not the same as rewriting a PDK's dict,
> and that distinction should be stated in the code if this option is taken."*

B2e made it checkable instead of stated, which is the right move. The check is:

```tcl
proc _restorable {t} {
  ...
  if {![_state_eq $d params [dict get $rec wparams]]} { return 0 }
  if {![_state_eq $d shown  [dict get $rec wshown]]}  { return 0 }
  return 1
}
```

i.e. **both fields are still byte-identical to what this session's apply wrote.**

## 2. What it actually distinguishes

Byte equality on two fields, not provenance. A writer who lands `params` and
`shown` bytes identical to apply's output owns neither field afterwards.

Measured (Verify-C): a **wholly different descriptor** was registered between
the apply and the `reset` — different `devpath`, `declared {{THEIRS x 0}}` —
whose `params`/`shown` happened to equal what apply had written. The next
`reset` + `apply` reverted **both** fields, over a dict this file never wrote.

## 3. Why it is not urgent

* The realistic version is benign. The documented invariant-I5 recovery
  round-trip copies both fields verbatim out of the live descriptor, so
  "identical bytes" there means *the descriptor apply left*, which is exactly
  what the undo is entitled to remove.
* The row that fences the honest case, **N7**, passes: a third party whose
  `params`/`shown` **differ** is left strictly alone, and an unowned class apply
  never wrote (`vertical_npn`) is byte-identical after `reset` + `apply`.
* Reaching the failure needs a writer that reproduces apply's output byte for
  byte while intending to own it. No shipped path does.

## 4. Options

1. **Stamp the record with a token** — a monotonic write id apply writes into
   its own session record *and* into the descriptor, compared on the way back.
   Real provenance; costs a fourth key on the descriptor, which is the thing
   DD-13's whole pattern-paragraph warns about (four fields, four readers).
2. **Widen the equality to the whole descriptor.** One line, no new key; makes
   the undo refuse more often (any unrelated key change disarms it), which is
   the safe direction but silently reduces how often Reset/Defaults works.
3. **Leave it, and say so in the code.** The guard is a *conservative*
   heuristic: it can only ever revert a descriptor that is byte-identical in
   both fields to one this file wrote, and the cost of a false positive is
   bounded — two fields go back to what the PDK had, which is where the undo
   was going to put them anyway.

Recommended: **(3) now, (1) only if a fourth writer of `params`/`shown` ever
appears.** Today there are exactly two (`op_annot::register`'s callers and
`apply`), and option 1 buys precision nobody can currently use.

## 5. Still open

Which option. Nobody is assigned.
