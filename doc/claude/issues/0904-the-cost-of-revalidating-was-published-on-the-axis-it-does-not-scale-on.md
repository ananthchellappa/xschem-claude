# 0904 — the cost of revalidating every press was measured on the axis it does not scale on

**Status:** 🟠 **OPEN — the published claim is corrected in this commit; the
cost itself is real, unbounded and unguarded.**

**Filed:** 2026-08-28 by the item A14 write-up, from A14's adversarial
verification pass, and **re-measured by the write-up agent** with its own probe
before filing.

## What was published

Item A14 made `Alt+Shift+6` revalidate the design window's cached database on
**every** press (issue 0900). The item's brief required the cost to be measured,
and it was — across three databases of **262 B, 1.0 MB and 42.5 MB**, varying the
**point count** at a fixed 200 columns. The conclusion shipped into
`doc/claude/specs/op_annotation.md` and into issue 0900 as:

> **0.220 ms to 0.678 ms** — +0.46 ms, **the whole price of revalidating**.

The number is correct for the database it was taken on. The sentence around it is
not, and it is the sentence a later reader will act on.

## What actually drives the cost

`cadence::_annot_db_print` — the fingerprint the revalidation compares, computed
**twice** per press, once in each window — ends:

```tcl
  foreach n $names {
    catch {set x [xschem raw value $n $last]}
    lappend vals $x
  }
```

One `xschem raw value` per **saved vector**, always at the same single point. The
point count does not enter the loop at all. So the price of revalidating scales
with **how many signals the run saved**, and the published table held that axis
fixed at 200 while sweeping the one axis it is nearly independent of.

## Measured, write-up agent's own probe, headless, `src/xschem` of Aug 27 14:58

Median of 11 calls to `cadence::_annot_db_print`, and doubled, because a
revalidation computes it in both windows:

| vectors | points | file size | one fingerprint | **both windows** |
|---|---|---|---|---|
| 6 | 20 000 | 995 KB | 0.007 ms | **0.014 ms** |
| 500 | 200 | 514 KB | 0.332 ms | **0.664 ms** |
| 2 000 | 200 | 2.0 MB | 1.260 ms | **2.520 ms** |
| 8 000 | 100 | 4.2 MB | 5.663 ms | **11.33 ms** |
| 20 000 | 50 | 5.5 MB | 13.49 ms | **26.98 ms** |
| 40 000 | 50 | 11.0 MB | 27.94 ms | **55.88 ms** |

Read the first and last rows together. A **995 KB** database with six saved
signals revalidates in **14 microseconds**. An **11 MB** database — a quarter the
size of the one the published number was taken on — revalidates in **56
milliseconds**, four thousand times more, because it saved forty thousand
signals. Roughly **1.4 µs per saved vector per window**, linear, with no ceiling
anywhere in the code.

Item A14's verification pass measured the same thing end to end (the whole press,
rather than the fingerprint alone) and got the same shape at a higher constant:
+42.1 ms at 20 000 vectors and +85.7 ms at 40 000, taking a no-change press from
70.1 ms to 155.8 ms. Two independent measurements, one conclusion.

## Why this matters rather than being a footnote

* **A `.save all` transient on a moderate analog block reaches tens of thousands
  of saved vectors routinely.** That is not an exotic bench; it is the default
  way people run when they do not yet know which node they will want.
* The cost is paid on **every press**, including — especially — the common press
  where nothing has changed and the user gets the same numbers back.
* The published sentence *"the whole price of revalidating"* invites the next
  reader to skip measuring, and to conclude that revalidation is free. On the
  bench above it is a fifth of a second's worth of key presses.

## What is fixed in this commit, and what is not

**Fixed:** the claim. `doc/claude/specs/op_annotation.md` and
`doc/claude/issues/0900-*.md` now say the price scales with **saved vectors**,
carry the table above, and no longer generalise a 200-column measurement to
"the whole price". A comment on `cadence::_annot_db_print` says the same at the
loop that causes it. This is issue **0899**'s class — a claim that outruns what
was measured — caught before it hardened.

**Not fixed:** the cost. Nothing bounds the fingerprint, and **no row measures
it**. Row V68 proves the *cheap path* is taken (no file is re-read); it says
nothing about how expensive the cheap path is.

## The shape of a fix — not attempted here

* **Sample the fingerprint** rather than reducing every vector — e.g. a fixed
  budget of N vectors chosen deterministically, plus the header fields. This
  weakens the compare, and the compare is **already** a sample in the other
  dimension (issue **0885**: the last point only). Both would need ruling
  together.
* **Ask a cheaper question first** — the results file's mtime and size, with the
  full fingerprint only when those differ. That also happens to be one of the
  sketches issue **0903** needs, and one of **0684**'s.
* **Cache the design window's own fingerprint** across presses, invalidated when
  the press itself attaches. Halves the work, and no more.

Any of these changes what a press believes; none is a drive-by.

## Related

* **0900** — the fix whose cost this is. Fixed.
* **0885** — the compare samples the last point only. Open. A ruling on sampling
  should cover both dimensions at once.
* **0899** — a claim shipped ahead of what was measured. This is that class.
* **0903** — the other open door on the same gate, and it wants an mtime check
  too.

## Evidence

Probe:
`/tmp/claude-1000/-home-analog-dev-xschem-claude/3722da05-e61e-4d11-903c-80c3d1bb943c/scratchpad/wu3/cost.tcl`,
written and run by the write-up agent. Source of record:
`utils/annot_mode.tcl`, `cadence::_annot_db_print`.
