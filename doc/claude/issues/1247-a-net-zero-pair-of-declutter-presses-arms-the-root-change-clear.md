# 1247 — a net-zero pair of `Ctrl-Alt-6` presses silently arms the root-change clear

Status: **FIXED** by item A3, 2026-09-02 — **but the fix is a ladder-L3 change
and the ruling is the user's**; recorded on `owed.sh` as `rule`
**1244_A3_rc_armed_stamp**. See the bottom of this file. · Branch: `fluid-editing`
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

---

## FIXED by item A3, 2026-09-02 — and the question it leaves is the user's

**BEFORE**, driven by item A3's measure agent as a CONTROL/VARIANT pair (stronger
than this file's original evidence, which was a code read plus one run). The
rc-armed shape cannot be reached from Tcl at all — `xschem set annot_show 3`
stamps the root immediately — so it is armed at init with
`--preinit 'set annot_show 3'`, which yields mask 3 with an EMPTY stamp:

```
=== 1247 CONTROL: rc-armed, NO presses -> the annotation SURVIVES File>Open ===
  AT START (armed by --preinit)        annot_show=3   annot_root=<EMPTY>
    after File>Open, NO presses        annot_show=3   annot_root=<EMPTY>

=== 1247 VARIANT: the SAME sheet, after a NET-ZERO pair of presses -> CLEARED ===
  AT START (armed by --preinit, rc shape)  annot_show=3   annot_root=<EMPTY>
    after press 1                          annot_show=11  annot_root=<STAMPED>
    after press 2  (mask is back to 3)     annot_show=3   annot_root=<STAMPED>
    after File>Open, AFTER the net-zero pair annot_show=0   annot_root=<EMPTY>
```

The advertised effect of the pair is nothing. Its real effect was that the
annotation now died on the next `File > Open`.

**AFTER** — `annot_show_set()` (`src/actions.c`) gained one line:

```c
if(old && (old ^ mask) == ANNOT_SHOW_NOPARAM) return;
my_strdup(_ALLOC_ID_, &xctx->annot_root, xctx->sch[0]);
```

*"A write that moves the declutter bit and **nothing else** does not adopt a mask
it did not arm."* Row **A25** drives the control/variant pair on two root sheets
and both now survive; row **A26** asserts 0688 is not weakened.

### The rule shipped is NOT the rule the plan chose, and the substitution is recorded

The plan chose *"stamp only on the 0 → nonzero arming edge, refresh an existing
stamp otherwise"*. Traced against the (then red) suite, that rule cannot separate
the three states the rows pin: `(3 → 11, NULL)` must not stamp, `(11 → 3, NULL)`
must not stamp, `(3 → 3, NULL)` **must** stamp — and an arming-edge rule declines
the third, reddening row A26. The exact-XOR rule separates all three.

**Rejected, with reasons:**

1. *"Do not stamp when the mask is unchanged."* **Refuted by measurement**, not by
   taste: the pair is `3 → 11 → 3` and **both** writes change the mask.
2. *"Do not stamp for bit 3 alone"* as a **subset** test — this is close to what
   shipped, and the plan's objection ("it makes `ANNOT_SHOW_NOPARAM` a
   second-class bit") is fair and is written into the code comment. The exactness
   is what keeps 0688 whole: any write that moves an **arming** bit still stamps.
3. Routing the `xschemrc` arm through the setter — reverses decision **D2** of
   issue **0688** outright.

### ⚠ STILL OPEN — the ladder-L3 question, verbatim

> After this fix, pressing `6` or `Alt-6` on a sheet whose `annot_show` was armed
> from `xschemrc` leaves it **rc-armed** — a later `File > Open` does **not**
> clear it — where today that press adopts the mask and the next `File > Open`
> clears it. Is that the behaviour you want, or should any press through the
> setter still adopt an rc-armed mask?

Recorded on `tests/headless/owed.sh` as `rule 1244_A3_rc_armed_stamp`. Item A3's
adversary pass drove six sequences on two and three root sheets looking for a case
where the new rule refuses a stamp that 0688 needed, and found none — including
the `saveas` case, which clears `annot_root` outright so a stale stamp has no
target.
