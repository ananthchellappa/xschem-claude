# 0874 — `text_hidden()`'s widened `hide=voltage` arm has no row: masks 4 and 5 are the only discriminating ones and no suite reaches them

**Status:** 🔴 **OPEN — measured, NOT fixed.** Filed by the A3 write-up, 2026-08-27,
from the sabotage leg of the 0868 run. Class: **a guard no row can see.**

Owner: issue **0868**, `text_hidden()` in `src/actions.c` (~:1541).

## The code and the claim it makes

0868 widened the explicit `hide=voltage` arm:

```c
if(flags & HIDE_TEXT_VOLTAGE)
  return (xctx->annot_show & (ANNOT_SHOW_VOLTAGE | ANNOT_SHOW_TRAN)) ? 0 : 1;
```

with a comment saying the implicit and explicit classes *"must not disagree about
which masks show a node voltage, or the same number would appear on one sheet and
vanish on another for the same mask"*. That is a real invariant, and it is
unguarded.

## Measured, 2026-08-27

A probe injected into `test_op_annot`'s own `u_hv` fixture, reading the visibility of
an explicit `hide=voltage` text at all eight masks:

```
mask   0 1 2 3 4 5 6 7
shown  0 0 1 1 1 1 1 1
```

**Masks 4 and 5 are the only discriminating ones** — 6 and 7 have bit1 set anyway, so
they are visible either way. The shipped rows never reach them:

* **U11** sweeps `{0 1 2 3}`
* **L8** uses masks 1 and 2
* **U29** has the same shape

So sabotage variant **S6b** — reverting that arm to `ANNOT_SHOW_VOLTAGE` alone —
flips masks 4 and 5 from visible to hidden, creating precisely the inconsistency the
comment says it is preventing, **and every suite stays green.**

0868's own sabotage table anticipated this: *"if S6b reds nothing behaviourally, that
arm needs its own structural row before landing."* It reds nothing, and no row was
added.

## Fix shape

Extend U11's sweep from `{0 1 2 3}` to `{0 1 2 3 4 5 6 7}` and pin the eight-element
visibility vector `0 0 1 1 1 1 1 1` for BOTH the implicit class (a plain
`@spice_get_voltage` floater) and the explicit `hide=voltage` text, in one row, so a
divergence between them is what reds. That is a behavioural row, which is stronger
than the structural fallback and costs no more.
