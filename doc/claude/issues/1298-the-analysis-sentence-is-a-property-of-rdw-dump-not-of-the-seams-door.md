# 1298 — ruling DD-5's analysis sentence is a property of `rdw::dump`, not of the seam's own door

**Status:** FILED, NOT FIXED. **Latent today, live the moment items B4 or B5
call the door themselves.** Found by item **B2d**'s adversary (Verify-C) and
re-measured by the write-up agent before filing.

**Files:** `src/rdw.tcl` — `rdw::dump` (:729), `rdw::dump_devpath` (:706),
`rdw::_analysis_line` (:224).

---

## 1. The claim

Item B2d implemented ruling **DD-5** (issue 1282 part 1): a state-`ok` block
whose analysis is not an operating point carries one extra sentence naming the
analysis. The sentence is built by `rdw::_analysis_line {ctx}`, and its gate is

```tcl
if {$sty eq {} || $sty eq {op}} { return {} }
```

The empty half of that gate is deliberate and correct — a hand-built ctx and a
failed `xschem raw sim_type` both produce `{}`, and a sentence that fired on
those would be indistinguishable from an honest one.

**But `simtype` is put into the ctx by `rdw::dump` alone.** `rdw::dump_devpath`
— the proc the file's own comment calls **THE SEAM'S ONLY DOOR**, and the entry
point items **B4** and **B5** are expected to call — takes the ctx from its
caller and adds only `sim`:

```tcl
proc rdw::dump_devpath {devpath ctx} {
    set s [rdw::sim]
    catch {dict set ctx sim $s}          ;# <- the backend, added by the door
    ...                                   ;# simtype, never
}
```

So a caller that builds its own ctx without `simtype` gets a DC sweep rendered
as an operating point again — **silently, with the defect issue 1282 filed and
no row anywhere that would notice**.

## 2. Measured, 2026-09-04, on the fixed tree

ONE answer, `{devices {@m.x1.m1 {{id 1.11e-05} {vth 0.45}}} absent {} nonfinite
{} complete 0 state ok}`, rendered through TWO contexts — the one
`dump_devpath` passes on (header, devpath, instname, and the `sim` the door
adds) and the one `rdw::dump` builds (the same plus `simtype dc`):

```
--- door : mentions-dc = 0
M1:/xdut/xbg
@m.x1.m1
Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.
    id  : 1.11e-05
    vth : 0.45

--- dump : mentions-dc = 3
M1:/xdut/xbg
@m.x1.m1
These numbers come from the first point of results xschem reports as a dc analysis, not as a standalone operating point. A dc sweep's first point is one sweep step, and xschem also reports a multi-point operating point as dc.
Not a complete list: these are the operating-point columns this run saved for this device, not everything the device has.
    id  : 1.11e-05
    vth : 0.45
```

The first block is byte-identical to the pre-DD-5 render issue 1282 was filed
about. The second is what rows F14 and Q6 assert.

**No shipped caller does this today.** `rdw::dump` is the only caller in the
tree, and it sets `simtype` from `xschem raw sim_type`. This is a latent defect,
filed because the next two items are the ones that make it live.

## 3. Options

* **(a) The door fills it in.** `dump_devpath` does what it already does for
  `sim`: `if {![dict exists $ctx simtype]} { catch {dict set ctx simtype [xschem raw sim_type]} }`.
  One line, and DD-5 becomes a property of the seam's door rather than of one
  caller. A ctx that carries an explicit `simtype` still wins, so the suite's
  hand-built contexts are unaffected. **RECOMMENDED.**
* **(b) A suite row that fences it.** Necessary either way, but on its own it
  only converts a silent defect into a red row for whoever writes B4.
* **(c) Leave it and document the obligation in B4/B5's plan cells.** Cheapest,
  and exactly the shape of "a promise kept in prose", which this batch has been
  burned by twice.

**Recommendation: (a) plus a row from (b).** Not taken by B2d because it is
outside the item's three-issue scope, and this batch has twice reverted nine
issues at once for work that reached past its brief.

## 4. Acceptance

* A block dumped through `rdw::dump_devpath` with a ctx carrying no `simtype`
  names the analysis when the loaded raw is not an operating point.
* An explicit `simtype` in the ctx still wins over the door's fallback.
* Rows F14, F15 (the `op`/`{}` control) and Q6 stay green.
