# 1291 — `op_param_lists::apply` raises on a malformed registered `params`, through the unowned list's seed

**Filed by:** item **B2b**, 2026-09-03, from Verify-C's adversary pass and
re-measured by the write-up agent on the landed tree.
✅ **FIXED 2026-09-03 by the DRIVER**, immediately after B2b landed and before
item B2c was dispatched — it was a **new** raise door opened by B2b's own
change, in B2b's own file, and latent only because nothing calls `apply` until
item **B5**. B2b was right to file rather than widen its own scope.

**The fix, in `op_param_lists::_params`:** every guard there asked a question
about the *dict* and none asked whether the value parses as a **list**. Two
levels are now checked, because both raise — a malformed OUTER list breaks
`foreach`, and a well-formed outer list holding a malformed ELEMENT breaks the
`lindex` that reads the triple one line later. Either answers `{}` for the whole
descriptor and reports which type was dropped: half a parameter list is not a
safer answer than none.

**Measured, the issue's own vulnerable shape** (malformed registered `params`,
user owning `annotation` only, so `summary` falls through to the seed):

```
before:  APPLY_RC=1   APPLY_ANS=RAISED:unmatched open brace in list
after:   APPLY_RC=0   APPLY_ANS={nmos pmos}
         REPORTS={the descriptor for `nmos` has a params list that does not
                  parse; ignoring it. Fix it in the rc that registered it.}
```

Fenced by rows **Z0-Z4** of `tests/headless/test_op_param_store_1245.tcl`
(51 → 56 checks). Sabotage: deleting the guard reds **Z1 Z2 Z3 Z4** and nothing
else. Row **Z0** proves the fixture really is malformed, so the rest cannot pass
vacuously. Feature A unmoved: `test_op_annot` 485, `test_annot_declutter_1244`
134, `test_rdw_seam_1245` 49, `test_rdw_window_1245` 32.

⚠ **Two things the fix's own construction taught, both recorded in the code:**
the malformed literal must never be written into a comment or a test file as a
literal — an unbalanced brace makes *that file* fail `info complete`, which
happened while writing this fix and was caught by a syntax check rather than a
test. And the first draft of row Z2 was **wrong, not the code**: poisoning
`nmos` alone leaves `seed mos` correctly answering `pmos`'s list, because the
class map is not onto and one bad type must not blind a whole class.

**Status:** open. Not a violation of the letter of B2b's brief — the DD-6
amendment constrains `op_annot::text`, the *draw-time* proc, and `apply` is a
user-invoked door with a `_say` reporting channel — but it is a raise door
opened by a change whose whole amendment exists because a raise door was opened
last time, and it must not reach B5 unexamined.

---

## 1. What was measured

Fixture: a descriptor whose `params` is malformed in **issue 0447's own live
shape** (`{id id 0} {bad` — the shape `test_op_annot` row K17 golds), the user
owning `annotation` only. Both halves from one script,
`scratch_B2b_vc/a7_body.tcl`, re-run by the write-up agent against the landed
tree and against `git show HEAD:src/op_param_lists.tcl` sourced over it.

**HEAD (81ecfc4d):**

```
HEAD_HAS_SHOWSET=1
APPLY_RC=0
APPLY_ANS=nmos
PARAMS_AFTER=devpath @m.@path@name params {{id id 0}}
```

**After B2b:**

```
APPLY_RC=1
APPLY_ANS=RAISED:unmatched open brace in list
PARAMS_AFTER=devpath @m.@path@name params \{id\ id\ 0\}\ \{bad
```

`apply` raises, writes nothing, and the descriptor is permanently un-applyable
for the rest of the session.

## 2. Why

`_save_set` and `_show_set` both walk `effective`:

```tcl
foreach t [effective $cls $ln] { ... }
```

`effective` (`src/op_param_lists.tcl:439-448`) falls through to `seed` for a
list the user does **not** own, and `seed` returns `_params $t`, i.e. **the
string the PDK registered as `params`, verbatim and unvalidated**. A malformed
one is not a list, so the bare `foreach` raises.

HEAD's `apply` never called `seed` at all — it wrote
`dict set d params [get_list class $c annotation]`, a value the store itself
built, and it did so **inside a `catch`**. B2b's union is precisely what made
the seed reachable from `apply`, and the guard change (`annotation` **or**
`summary`) widened the exposure: owning only `annotation` is the vulnerable
case, because `summary` is then the list that falls through to the seed.

## 3. Blast radius today, and tomorrow

* **Today: none.** `grep -rn 'op_param_lists::apply' src/ xschem_library/
  sky130A/ gf180mcuD/ ihp-sg13g2/` finds only comments; the sole caller anywhere
  is `tests/headless/test_op_param_store_1245.tcl`.
* **At B5:** the RDW's Apply button calls this. A user with one malformed
  descriptor — from her own rc under **I5**, which is the documented way to
  change a list — would get a Tcl error dialog from a button, and *no* list
  applied for *any* device type, because the raise escapes the whole proc.
* The malformed descriptor itself is issue **0447**, which is filed, accepted
  and deliberately still open: `op_annot::text` still raises on it too. The
  defect here is that a **second, differently-shaped** door was added to it.

## 4. The fix, when someone takes it

One `catch` per `foreach` in `_save_set` and `_show_set` is the mechanical part;
the design part is **what a malformed seed should mean**, and it must be decided
rather than defaulted:

* **treat as empty** — silently drops the PDK's rows out of the union, so the
  deck stops saving them. Strictly worse than the raise: it is the union's own
  guarantee ("can only ever be a SUPERSET") failing quietly.
* **skip the class, and `_say` why** — the descriptor is left exactly as the PDK
  registered it, the user gets one report naming the type, and every other class
  still applies. This is the recommendation: it matches how `apply` already
  handles a failing `register` (`continue` plus `_say`), and it keeps a
  malformed descriptor a *reported* condition rather than a silent one.
* validate at `register` — rejected for the same two reasons the DD-6 amendment
  gives: it cannot see the nested malformation (measured: `{id id 0} {d "x}`
  has `llength` 2), and a raise there rejects the whole descriptor.

A fence belongs in `test_op_param_store_1245.tcl` section D next to **D7**,
which already golds that the *draw* path still raises for this same input.

## 5. Still open

The design choice above. Measured while filing: `effective` has exactly **two**
callers in the file, both added by B2b (`:763` in `_save_set`, `:777` in
`_show_set`), and `seed` has exactly one (`effective` itself, `:446`) — so
`write_conf`, `load_conf` and the rest of the store are **not** exposed to this
shape and need no change. The whole defect is the two `foreach` lines.
