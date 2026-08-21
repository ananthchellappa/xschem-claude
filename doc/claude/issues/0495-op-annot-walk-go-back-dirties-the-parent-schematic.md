# 0495 — `xschem go_back` dirties the parent, so any hierarchy walk violates I4

STATUS: **OPEN.** Measured on branch `annotate`, step S3d, 2026-08-21, at
`d56283ec`. Refuted attempt 4's I4 claim; see 0494.
Related: 0494 (the reverted attempt), 0499 (the guardian that cannot fail),
0431 (the prototypes' restore discipline).

---

## The claim

Invariant **I4** (spec §5): *the overlay never modifies the schematic: no
instance placed, no set_modify, nothing written to the .sch.* Attempt 4 repeated
it verbatim in `op_annot::save_cards`'s own header, and row **W19** asserts
`xschem get modified` is 0 after a walk.

## The measurement

`--nogui`, sky130 library path set **unqualified**, `sky130_procs.tcl` sourced
(the fixture route `test_op_annot.tcl:790-816` uses):

```
I4-REPRO bandgap_opamp    : modified BEFORE=0 AFTER=1  rc=0  lines=103
I4-REPRO tb_bandgap_opamp : modified BEFORE=0 AFTER=0  rc=0  lines=115
```

Isolated to the operation, by descending into each of the 73 top instances and
returning:

```
load: modified=0 insts=73
DIRTY inst=x1  modified before=0 afterdescend=0 aftergoback=1
DIRTY inst=x3  modified before=1 afterdescend=0 aftergoback=1
final modified=1
```

Read the middle column: **`descend` leaves the flag alone (0); `go_back` sets it
(1).** The flag lands on the *parent*, the cell the user was standing in.

Note `x3`'s row: `before=1` then `afterdescend=0` — descending **clears** the
flag, because loading the child resets it, and go_back sets it again on return.
So the damage is not cumulative-only, it is also *destructive of a real dirty
state*: a walk over a genuinely-modified sheet can clear the user's modify flag
on the way down and re-set it on the way up, which is a different bug wearing the
same face.

Not op_annot's invention: the shipped sky130 prototype does it too
(`sky130_save_fet_params` → `modified=1`). It is a property of `go_back`.

## Why it matters

The S3 menu item is advertised as read-only. A user clicks *Create device OP
.save file* on `sky130_tests_ase/bandgap_opamp`, and the sheet they never edited
is now dirty and will prompt on close. Invariant I3's precedent (`save.c` RULING
D5-1) is that a plausible-but-wrong state on a schematic is worse than none; a
spurious modify flag is exactly that, applied to the user's *file*.

## Options for attempt 5, none of them free

1. **Snapshot and restore the flag around the walk.** Smallest blast radius, but
   there is no `xschem set modified` verb on this tree — check before assuming.
2. **Fix `go_back` not to dirty the parent.** Correct, C-side, and blast radius
   is every descend/go_back user in the tree — needs its own step and its own
   guardian, and would touch `test_descend_*` suites.
3. **Scope the invariant text and the guardian to what they actually prove**, and
   state in the menu item's own documentation that the sheet is marked modified.
   Honest, but it concedes a user-visible wart.

Until one is chosen, **I4 must not be asserted in source comments** — a false
invariant in a header is worse than an absent one, because the next reader
believes it.

## Still open

* Whether `xschem set modified <0|1>` exists or must be added.
* Whether `go_back`'s dirtying is deliberate (a genuine hierarchy-state change)
  or incidental. Nobody has read the C to find out; that read is the first task.
* Row W19 in the reverted patch is vacuous and would not have caught this even
  if it had been run on the right fixture. See 0499.
