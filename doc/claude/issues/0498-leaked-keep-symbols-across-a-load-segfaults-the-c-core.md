# 0498 — a leaked `keep_symbols=1` across a schematic load segfaults the C core

STATUS: **OPEN.** Measured on branch `annotate`, step S3d, 2026-08-21, at
`d56283ec`. Observed while sabotage-testing attempt 4; see 0494.
Related: 0431 (the prototypes do not restore on a raise), 0494, spec §5 I6.

---

## The measurement

The `restore_skipped` sabotage variant — `op_annot::_restore` reduced to
clearing its re-entrancy latch, so the walk leaves `no_draw 1`,
`keep_symbols 1`, the log-suppress scope pushed and the hierarchy wherever it
stopped — crashed xschem **deterministically, 3 legs of 3**:

```
propagate_hilights(): .ptr<0, unbound symbol: inst 0, name=MP1 sch=w_bare.sch
FATAL: signal 11
(emergency save)
```

The Implement agent saw it once, judged it unreachable from shipping code, and
left it unfiled. The adversary reproduced it 3/3 and asked for a number. This is
that number.

## Why it is worth a number even though shipping code cannot reach it

It can only be reached by deliberately deleting the restore, so no user is
exposed **today**. What it establishes is the *consequence class* of an I6
violation, and that is much sharper than any write-up in this feature has stated:

> a leaked `keep_symbols=1` carried across a schematic load does not merely leave
> the symbol table dirty — it can drive `propagate_hilights()` through a negative
> pointer index and take the process down with SIGSEGV.

Invariant I6 has until now been justified on tidiness grounds ("restore what you
forced"). It is in fact a **memory-safety** boundary. Every future hierarchy walk
author should read it that way, and the spec §5 I6 text now says so.

Note also that **both shipped prototypes** (`sg13g2_sch_expand`,
`sky130_sch_expand`) restore only on the normal path, with no catch — issue 0431.
A raise below entry leaves `keep_symbols=1` set in a live session. The gap
between "0431 is a tidiness bug" and "0431 is a latent segfault" is this issue.

## Still open

* **Nobody has read the C.** The crash is reported, not diagnosed. The obvious
  hypothesis — a stale `xctx->sym` entry surviving a load that should have
  rebuilt the table, then an instance's `ptr` resolving to -1 — is untested.
* Whether a C-side hardening (refuse to keep symbols across a load, or bounds-
  check `propagate_hilights`) is warranted, or whether the Tcl-side restore
  discipline is the whole answer.
* Whether 0431's prototypes can reach it in a real session. They restore on the
  normal path, so it needs a raise below entry — `sky130_save_fet_params` on
  `xschem_library/generators/test_generators.sch` was the case 0431 measured.
