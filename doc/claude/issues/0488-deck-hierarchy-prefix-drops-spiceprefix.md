# 0488 — the deck hierarchy prefix carries the instance NAME only and drops `spiceprefix`

**Status:** open, UNMITIGATED on the tree. A guard (`op_annot::_prefix_ok`) was
written for S3 attempt 4 and **reverted with it** — see 0494; the guard survives
only in `0494-attempt-4-reverted.patch`.
**Filed by:** step S3d of `doc/claude/specs/op_annotation.md`.

## What was measured

All three hierarchy-path sources — `xschem get sch_path`, `xschem get
sim_sch_path` (scheduler.c:5178) and translate's `@path` (token.c:4719) — build
the path out of the instance NAME. None of them prepends `spiceprefix`.

On a subcircuit symbol carrying `template="name=x1 spiceprefix=X"` and an
instance placed as `name=SUB1`:

```
xschem translate SUB1 @spiceprefix@name   ->  XSUB1      <- what the deck writes
xschem get sch_path (after descending)    ->  .SUB1.     <- what a card is built from
```

So every save card generated below that instance would name `@m.sub1.<inner>`
against a raw holding `@m.xsub1.<inner>`.

## Why it matters more than a wrong number

Every card in that subtree is bogus at once. Re-measured on ngspice 46+ under
the `.control … write … .endc` idiom every shipped PDK bench uses, an ALL-bogus
device block makes ngspice write **no raw file at all**, at rc 0. The generator
would kill the simulation it was generated for.

## Reachability

`grep` over the 533 shipped `type=subcircuit` symbols in
`xschem_library/sky130A`, `gf180mcuD`, `ihp-sg13g2` and `xschem_libs_newsym`:
**zero** carry `spiceprefix`, and 527 of 533 have a `format` whose first token
is a plain `@name`. So this is user-reachable and not shipped-reachable.

## The mitigation that was written and reverted (and was never a fix)

`op_annot::_prefix_ok` compares the last component of the live `sch_path`
against `op_annot::_elements` (`@spiceprefix@name`, expanded for vector
instances). On a mismatch the subtree emits **no cards** and the instance is
named in `op_annot::last_warnings`, which `write_save_file` writes into the file
as a `* NOTE:` line. Guardian: row W18 of the reverted acceptance — **not on the tree**; it lives in
`0494-attempt-4-reverted.patch` and must come back with attempt 5.

Blank beats a plausible wrong card (save.c RULING D5-1, invariant I3) — and here
a plausible wrong card is worse than a wrong number, because it removes the
whole raw.

## The real fix, not attempted here

Either a hierarchy-path source that carries `spiceprefix`, or a per-level
`spiceprefix` accessor the Tcl side can compose. Both are C changes in the
`sch_path` machinery and would move `sim_sch_path`, which every existing
annotation READ path depends on.
