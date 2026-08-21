# 0493 — `op_annot::save_cards` spends 5.2 s in `_normkey` on a 97-block hierarchy

**Status:** open, measured. The code it profiles is **not on the tree**: S3
attempt 4 was reverted (0494) and `op_annot::save_cards` lives only in
`0494-attempt-4-reverted.patch`. The measurement stands and binds attempt 5.
**Filed by:** step S3d of `doc/claude/specs/op_annotation.md`.

## Measured

`xschem_library/examples/0_examples_top.sch`, the largest shipped design
(49 top-level instances, 97 `.subckt` blocks, a 1.2 MB deck), with **no
op_annot descriptor registered at all** — i.e. the walk produces an EMPTY
`.save` block:

```
oracle_deck   =  686 ms     (the `xschem netlist -keep_symbols -noalert` run)
deck_index    =   19 ms     (parsing the 1.2 MB deck)
save_cards    = 5176 ms     total
                            _normkey calls   = 34538
                            descend/go_back  =  1712
```

For scale, on ordinary designs the whole call is 16-116 ms
(`loading.sch` 16 ms, `mos_power_ampli.sch` 32 ms, `greycnt.sch` 116 ms).

So the oracle inversion is **not** the cost; `op_annot::_normkey` is. It runs
`abs_sym_path` + `file normalize` — a filesystem-touching pair — and is called
from `_here_block` on every `_netlisted` test and again from `_descendable`, so
it is O(instances visited) with a large constant.

## Why it matters

`Create device OP .save file` is a menu click. On this design it is a ~6 second
freeze that produces nothing.

## Why it was not fixed here

The obvious fix is a memo on `_normkey`, which is a pure function of its
argument **for a fixed `XSCHEM_LIBRARY_PATH`** — and the library path is exactly
what `tests/headless/test_op_annot.tcl` rewrites between sections. A cache
therefore needs a defined invalidation point (clear at `save_cards` entry is the
candidate) and its own guardian row proving a library-path change between two
walks does not serve a stale key. That is a change with its own blast radius and
it belongs in its own step, not bolted onto the step that introduced the walk.

Recording it instead, per the crew rule that a discovered defect is filed and
never fixed silently.

## Suggested fix

`variable _nkcache`; memoize `_normkey` on its input string; clear the array at
the top of `op_annot::save_cards`. Guardian row: two walks over the same design
with `XSCHEM_LIBRARY_PATH` changed in between must produce the same block as two
walks in two fresh interpreters.
