# 0646 — `test_ase_window` W4's raise self-SKIP masks a real never-raise regression, on a reparenting WM

STATUS: **OPEN — measured 2026-08-23 by the 0616 crew (sabotage V2 and V3).**

## What the test claims about itself

`tests/headless/test_ase_window.tcl`, W4's block: after nudging
Session > Design Window up to five times through the product path, a persistent
stall prints `SKIPPED: W4 raise assertion (WSLg stackorder stall after 5
product-path attempts)` instead of failing. The in-file comment justifies it:

> A REAL never-raises regression degrades to this SKIP line on EVERY run (and red
> on any non-WSLg display).

## What was measured

Under **`xfwm4 --compositor=off`** on a private Xvfb — a **reparenting,
non-WSLg** WM — two deliberate never-raise sabotages of `raise_window_entry` were
run against the suite:

| sabotage | W4 | the new W6m rows |
|---|---|---|
| V2 — flip the `raise_mode` default to `ifhidden` everywhere | **SKIPPED** (check vanished from the count: 177+1 vs 179) | W6m6 red |
| V3 — replace `raise_activate_toplevel` with a no-op inside `raise_window_entry` | **SKIPPED** | W6m6 + W6m7 red |

So the claim is false: **it is not red on a non-WSLg display; it is skipped.** W4
is not a discriminator for a never-raise regression at all — only the newer W6m
rows are. And because the skip removes a check from the total, a stalled run
reports **178** rather than 179, which reads like a lost check to anyone diffing
tiers.

## Why the blind retry is the defect

The retry cannot tell "the product did not ask for a raise" from "this X session
cannot raise". It answers both with SKIP, and the first of those is exactly the
regression the row exists to catch.

## The fix shape, already demonstrated

The W6m rows added for issue 0616 use a **mechanism probe** instead of a blind
retry: when the assertion fails, call the underlying helper (`raise .`,
`raise_activate_toplevel .`) *directly* and re-measure.

* helper works, product did not → **RED** (a real regression)
* helper also fails → **SKIP**, naming WSLg's documented raise no-op (issue 0054)

Verified to discriminate: sabotage **V7** (drop the `raise` from the `ifhidden`
arm) produced `FAIL: W6m5 the run brings the BURIED design window back to the
front -> {design-below-ase} (exp {design-above-ase})` — the probe did **not**
swallow it, because a direct `raise .` worked in that session.

W4 should be converted to the same shape.

## Acceptance

- A never-raise sabotage of the product turns W4 **red** on any display where a
  direct raise demonstrably works.
- W4 still skips (with a true reason) on a display where nothing can raise.
- The check count does not silently change between a skipped and an asserted run,
  or if it must, the banner says so.

## Related

- Issue **0645** — on this box the documented arm has no WM at all, which is the
  other half of how a window-mapping defect survives a green suite.
