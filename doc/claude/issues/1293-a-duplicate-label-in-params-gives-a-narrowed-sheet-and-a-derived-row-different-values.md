# 1293 — a duplicate label in `params` gives a narrowed sheet and a `derived` row two different values

**Filed by:** item **B2b**, 2026-09-03, from Verify-C's adversary pass,
re-measured by the write-up agent.
**FILED, NOT FIXED.** Minor, and **unreachable through `op_param_lists::apply`**
— it needs a hand-written descriptor or a PDK rc.

**Status:** open, low severity, no user affected today.

---

## 1. What was measured

Descriptor `params {{gm gm 1} {gm cgg 1}}` — one label, two different raw
parameters — plus `derived {{twice {$gm*2}}}`, on a raw where `gm` = 100u and
`cgg` = 10f:

```
NO SHOWN  : gm    = 100u / gm    = 10f / twice = 20f
WITH SHOWN: gm    = 100u / twice = 20f
```

Narrowed, the sheet says `gm = 100u` while the derived row says `twice = 20f`,
i.e. 2 x **10f**. Two rows of one block disagree about what `gm` is, and the
narrowing is what removed the second row that would have shown the reader why.

## 2. Why

`op_annot::text` now keeps two things from one pass over `params`:

* `vals`, the label→value cache the narrowed rows are minted from, is
  **FIRST wins** (`if {![dict exists $vals $lbl]} { dict set vals $lbl $val }`);
* `vars`, which `_evalrow` evaluates a `derived` expression over, is **LAST
  wins** — `_evalrow` (`src/op_annot.tcl:1690-1694`) does
  `foreach {n v} $vars { set $n $v }`, so the later binding overwrites.

The `vars` half is **pre-existing** and unchanged by B2b. What is new is that
before the narrowing both rows were drawn, so a reader saw both numbers; a
narrowed sheet shows one of them and computes with the other.

## 3. Why it is not reachable from the store

`op_param_lists::_save_set` dedups the union **by label**, so `apply` can never
write a `params` with a duplicate label — that dedup is also what makes
`shown ⊆ params` hold under issue **1288**'s live duplicate-label door. The only
routes in are a PDK's own `op_annot::register` and a user's rc under **I5**.
No shipped PDK does it (all four register sites carry distinct labels).

## 4. The fix, when someone takes it

Make the two agree. **Last wins in both** is the smaller change — one word in
`op_annot::text`, dropping the `dict exists` guard — and matches `_evalrow`,
which cannot be changed without touching how every existing `derived` row
evaluates. First-wins in both would mean rewriting `_evalrow`'s binding loop,
which is fenced by the `P_DERIVED*` tables in `test_op_annot`.

Either way the honest answer may be neither: a duplicate label in `params` is
arguably a descriptor defect that `register` should **report** (not raise —
see the DD-6 amendment), the same way issue **1288** says `set_list` should.

## 5. Still open

All of it. Also worth deciding together with 1288, since both are "one label,
two rows, silently accepted".
