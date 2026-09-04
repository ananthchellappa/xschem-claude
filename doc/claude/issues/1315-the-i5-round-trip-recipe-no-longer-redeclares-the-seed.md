# 1315 — the documented invariant-I5 round-trip no longer redeclares the seed

**Status: STATUS E — UNRATIFIED, IMPLEMENTED, FENCED IN BOTH DIRECTIONS.**
Filed by item **B2e** while implementing ruling **DD-13** (issue 1312). A `rule`
debt is owed on it. It is *not* a defect report: the behaviour below is the
consequence of the design DD-13 chose, it is deliberate, and it is fenced by row
**N10** of `tests/headless/test_op_param_store_1245.tcl` in *both* directions so
that whichever way the user rules, the other direction reds rather than drifts.

## 1. What changed

DD-13 gives the descriptor a third list, `declared`, written by
`op_annot::register` and read by `op_param_lists::_params` (and therefore by
`seed`). The stamp is **preserve-if-present**: `register` puts a `declared` on a
non-empty descriptor that does not already carry one, from that descriptor's own
`params`, and leaves an existing one alone.

That rule is the whole reason `op_param_lists::apply` cannot destroy a
declaration — apply reads a descriptor, sets `params`/`shown` on it and
re-registers, so the key rides through untouched and apply's body never names it
(row **N12** counts the writing lines and expects zero). The guarantee is built,
not asserted, which is the standard the DD-6 amendment set.

## 2. The consequence nobody has ruled on

All three PDK `_procs.tcl` files document a recovery round-trip for invariant I5:

```tcl
set d [op_annot::descriptor nmos]
dict set d params {{id id 0} {gm gm 1}}
op_annot::register nmos $d
```

Under preserve-if-present that round-trip **carries the old declaration with
it**. So it changes what the run computes and what the sheet draws, and leaves
`seed` answering the list the PDK registered. Measured (row N10 leg 1):

```
params after = {{X x 0}}      declared = the PDK's list      seed mos = the PDK's list
```

The escape hatch is one line before re-registering — `dict unset d declared` —
or registering a fresh dict, which is what all four shipped register sites
(sky130 :422, gf180 :128, IHP :779 and :829) already do. Measured (row N10 leg 2):

```
params after = {{X x 0}}      declared = {{X x 0}}           seed mos = {{X x 0}}
```

Both the hatch and the sentence explaining it are now printed in all three PDK
files (row **C3**) and in `op_annot::register`'s own header.

## 3. The question for the user

**Should the documented recipe itself redeclare?** Three answers, all
implementable, none obviously right:

* **(a) what B2e shipped** — preserve, document the hatch. The round-trip means
  "change what this run computes", and the declaration stays the PDK's.
* **(b) restamp always** — `register` recomputes `declared` from `params` every
  time. Simplest to explain and **reintroduces issue 1312 on the first apply**,
  because after an apply `params` *is* the union. Rejected on that measurement,
  not on taste.
* **(c) a second verb** — `op_annot::redeclare`, so the round-trip is explicit
  in both directions. One more public name for a case that has never been
  reported in the field.

B2e took (a) under ladder rule **L3** and recorded the question here rather than
resolving it silently. Overruling costs one proc and one row's golden.

## 4. Also recorded here, because it is the same rule seen from the other side

A **non-empty descriptor registered with no `params` at all** is stamped with the
**empty** declaration, deliberately. Without that, `apply` could later give the
type a `params` and the re-register would then record apply's own *union* as
that type's declaration — issue 1312 surviving in the one corner nobody would
look at. Measured on this tree:

```
register nmos {devpath …}          -> declared = {}
set_list class mos annotation {{q q 0}} ; apply
params = {{q q 0}}                    declared = {}      seed mos = {}
```

The cost is stated: such a type seeds nothing until somebody declares for it,
which is the same answer it gave before this key existed.
