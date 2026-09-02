# 1247 — a net-zero pair of `Ctrl-Alt-6` presses silently arms the root-change clear

Status: **open** (measured by item A1's adversary pass and re-measured by the
write-up pass; **not fixed** — the mechanism is pre-existing and A1 owns no C file
that could fix it) · Branch: `fluid-editing`
Related: **0688** (the mechanism), **1244** (the chord that exposed it), RULING D-8

## The one-sentence statement

`cadence::annot_declutter` writes the mask through `xschem set annot_show`, which
is `annot_show_set()` (`src/actions.c:1406`), which **stamps `xctx->annot_root`**
for any nonzero mask. So pressing `Ctrl-Alt-6` **twice** — a chord whose whole
advertised effect today is *nothing*, and which leaves `annot_show` bit-for-bit
where it started — converts an `xschemrc`-armed annotation from one that
**survives** a `File > Open` into one that is **cleared to 0** by it.

## What was measured

`annot_show_set()` (`src/actions.c:1406`, the one C writer):

```c
void annot_show_set(int mask)
{
  if(!xctx) return;
  xctx->annot_show = mask;
  tclsetintvar("annot_show", xctx->annot_show);
  if(mask) my_strdup(_ALLOC_ID_, &xctx->annot_root, xctx->sch[0]);
  else     my_strdup(_ALLOC_ID_, &xctx->annot_root, NULL);
}
```

and `annot_show_check_root()` (`:1430`) returns early on a NULL stamp — by
design, and the comment says why in so many words:

> *"A NULL stamp is 'never armed through the setter' and is left ALONE: an
> `set annot_show 1` in the user's xschemrc (honoured at `xinit.c:3839`) never
> passes through `annot_show_set`, so it is never stamped and must never be
> cleared. That is decision D2 and it is what keeps this fix inside the 0683
> ruling's scope."*

The probe (write-up pass, 2026-09-02, `./src/xschem --pipe -q --nolog`, dev
display `:99`; the control and the variant differ **only** by the two presses):

```
CONTROL armed by rc-style set, on sheet A -> mask 1
CONTROL after File>Open of sheet B      -> mask 1
VARIANT armed the same, two Ctrl-Alt-6  -> mask 1  (bit-for-bit the same mask)
VARIANT after File>Open of sheet B      -> mask 0
```

The two presses net to zero on the mask (`1 → 9 → 1`) and net to a **permanent
change of behaviour** on the stamp: `NULL → sheet A`.

## Why item A1 did not fix it

* The mechanism is **pre-existing and shared**. `6` and `Alt-6` reach
  `annot_show_set()` the same way and have stamped the root since issue 0688.
  A1 introduced no C behaviour at all — its `src/xschem.h` hunk is one `#define`
  that no `.c` file reads until item A3.
* A1's Files cell is `src/xschem.h`, `utils/annot_mode.tcl`,
  `src/cadence_style_rc` and its own suite. Every candidate repair lives in
  `src/actions.c`.
* The repair is **ruled, not mechanical** — see below.

What A1 *is* responsible for is the exposure: it is the first chord that reaches
the stamp **while advertising that it does nothing**, and item A1's implement
notes called the interaction "harmless". In the rc-armed configuration, measured
above, it is not.

## Why "just don't stamp on a no-op" is the wrong repair

Three candidate shapes, none of them free:

1. **Don't stamp when the new mask equals the old.** Cheapest, and wrong in the
   other direction: after a genuine `6` on an rc-armed sheet the user *has*
   armed through the setter, and a later identical write would then leave the
   stamp stale rather than refreshing it.
2. **Don't stamp for bit 3 alone.** Makes `ANNOT_SHOW_NOPARAM` a second-class
   bit and re-opens exactly the "two builders of one fact" drift invariant I1
   and issue 0688's own header forbid.
3. **Stamp on the rc arm too** (i.e. route `xinit.c:3839` through
   `annot_show_set`). Most honest, and it **reverses decision D2 of 0688** — an
   rc-armed mask would start being cleared by a root change, which is precisely
   what 0688 was told not to do.

All three change user-visible behaviour that a prior ruling already settled, so
this is a question for the user, not a patch.

## Acceptance (proposed, once ruled)

* An rc-armed `annot_show` behaves **identically** across a `File > Open` whether
  or not `Ctrl-Alt-6` was pressed an even number of times first.
* Whatever is chosen, `6` / `Alt-6` / `Ctrl-6` keep the 0688 behaviour they were
  ruled into.
* A row in `tests/headless/test_annot_declutter_1244.tcl` that loads a **second
  root sheet** — the suite has no such row today, which is why nothing in it can
  see this (see 1248).
