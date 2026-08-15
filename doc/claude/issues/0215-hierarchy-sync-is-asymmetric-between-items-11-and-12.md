# 0215 — hierarchy sync is asymmetric: browser→schematic REFUSES what schematic→browser MAPS

Status: **OPEN**, low priority. A **declared limit**, not a regression — both halves behave
as shipped and as asserted.
Found by: Signal Browser batch item 12 (`receipts/12_receipt.md` §13 row 8), filed by item 16.
Spec: `doc/claude/specs/waveform_signal_browser.md` §10.7.

## The asymmetry

The two hierarchy-sync commands are mirror images everywhere except one case: **the design
window sits on an ANCESTOR of the session's design** (i.e. the raw was read further down
than the window is standing).

| direction | command | behaviour in that case |
|---|---|---|
| browser → schematic | `Descend to here` (item 11) | **REFUSES.** `wviewer::hier_origin_ok` returns 0 and the walk never starts. |
| schematic → browser | `Show in Signal Browser` (item 12) | **MAPS.** `wviewer::browser_origin_drop {level rawlevel}` drops `level` leading segments and the sync succeeds. |

So from the schematic the user can jump into the browser, but the return trip from the very
node they landed on refuses.

## Why each half is the way it is

Both are correct in isolation, and the reason is the arm described in the spec's §10.2:

* With **no raw loaded in the design context**, `sch_waves_loaded()` is `-1`, the C skip
  loop in `xschem get sim_sch_path` never runs, and the getter **degrades to `sch_path`
  minus its leading dot**. That degraded value is measured from the *window's* origin, not
  the *browser's*.
* Item 11 has nothing to reconcile the two origins with, so it **guards and refuses** —
  `hier_origin_ok` is the item's only claim a readback cannot check, and without it a walk
  would land N levels off **and report success**, because the pivot and the verify share the
  same wrong origin.
* Item 12 **does** have the missing number: `ase::session_for_current` hands it `level`, the
  stack level the session's design sits at in that window (issue 0168). Dropping `level`
  segments reproduces `ase::ui::sod_rel_path $level` exactly — a MEASURED identity, and
  reached without reading `sch_path`, which the batch's decision 10 forbids.

Item 12 also refuses the genuinely irreconcilable case: a **negative** drop means the raw
was read *below* the session's design, and it declines rather than guessing.

## Why it was not closed

Closing the gap means **changing item 11** — giving `browser_descend_to` the same
session-level input item 12 has, so `hier_origin_ok` can map instead of refusing. That was
out of item 12's scope, and item 12 recorded it as a finding rather than agreeing it was
fine.

## Suggested direction

Give item 11's entry points the session level (`ase::session_for_current`'s second element)
and let `hier_origin_ok` return a **drop count** rather than a boolean, reusing
`browser_origin_drop`'s arithmetic instead of adding a second one. The refusal then narrows
to the case item 12 already refuses (a negative drop).

⚠ Whatever is done, keep the **guard** — do not simply delete `hier_origin_ok` because the
common case works. Its whole reason for existing is that the failure it prevents *reports
success*.

## Coverage that must not be lost

* item 11's refusal is asserted in `tests/headless/test_wave_sigbrowser_i11.tcl`
* item 12's mapping is asserted in `tests/headless/test_wave_sigbrowser_i12.tcl`
  (BX48 proves the mapping works, BX49 proves it equals `sod_rel_path`)

Any fix must update the first without weakening the second.
