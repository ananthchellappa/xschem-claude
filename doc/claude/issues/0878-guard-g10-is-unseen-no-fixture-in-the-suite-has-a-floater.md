# 0878 — guard G10 is unseen: no fixture in test_op_annot.tcl has a floater

Status: ✅ **FIXED 2026-08-27** by the A3h repair pass — row **V10b**, a dedicated
fixture sheet, no C change. Filed by the A3h sabotage run the same day. Measured, not
inferred, at both ends: the sabotage that reddened nothing now reddens exactly one row.

## The finding

`src/scheduler.c:2372`

    if(rc && floaters) set_modify(-2); /* refresh floater caches: see guard G10 above */

**Deleting this line reddens nothing.** The whole suite still reports
`RESULT: ALL PASS (410 checks) / OVERALL: ok`, rc=0. Row **V10**, written
expressly to cover G10, passes with the guard gone.

## Why — and it is not "V10 is weak", it is "the statement never executes"

`there_are_floaters()` (src/actions.c:87) scans **only the schematic's own**
`xctx->text[]` for `TEXT_FLOATER`. Instrumenting the arm with a printf over a
full suite run gives, for all twenty `annotate_at` calls in the file:

    18 x  G10PROBE rc=1 floaters=0
     2 x  G10PROBE rc=0 floaters=0

`floaters` is **0 every single time**, so `if(rc && floaters)` is never taken.
The guarded statement is dead for the entire suite.

The fixture is why. `s5_flat.sch` (built at test_op_annot.tcl:1540-1551) contains
four `C {lab_pin.sym}` instances and **no `T` record at all**. The
`@spice_get_voltage` text that V10 actually measures lives in `lab_pin.sym`
(`T {@spice_get_voltage} 1.875 3.90625 0 0 0.2 0.2 {layer=15}`) — a **symbol**
text rendered through `TEXT_CTX_INSTANCE`, which `there_are_floaters()` does not
count and which does not go through the floater cache.

So V10's stated premise is false for its own fixture. Its header says:

> `@spice_get_voltage` on every lab_pin / ipin / opin / vdd / probe text is a
> FLOATER, and floaters render from a cache that only `set_modify(-2)` refreshes.

For a **schematic-level** text that is true. For the fixture V10 loads there is
no such text.

## G10 is a REAL guard, not dead code — the counterfactual

Added one schematic-level floater to the fixture:

    T {SFLOAT=@spice_get_voltage} 200 -200 0 0 0.4 0.4 {name=p1 layer=15}

Then `annotate_at 1e-9` -> SVG export -> `annotate_at 4e-9` -> SVG export, with
no mask change and no intervening redraw (V10's exact shape). `there_are_floaters()`
now reports 1. Measured, two builds, same fixture:

| build | first export | second export |
|---|---|---|
| G10 present  | `SFLOAT=1` | `SFLOAT=4` |
| G10 deleted  | `SFLOAT=1` | **`SFLOAT=1`** |

With the guard gone the sheet keeps rendering the **previous request's number** —
the RULING D5-1 breach, and the I3 breach that got S9 attempt 1 reverted. The
guard earns its place; nothing in the suite can see it earn it.

## What landed

One fixture line and one row, no new mechanism, no C change.

* **`v_g10.sch`** — its own sheet, written fresh beside the others, carrying the same
  four `lab_pin` instances plus **one schematic-own floater**:
  `T {ZZG10=@spice_get_voltage} -200 -200 0 0 0.2 0.2 {name=p1}`. The `name=` property
  is what sets `TEXT_FLOATER` (`src/actions.c:1325`), so the text renders through
  `get_text_floater()`'s cache. A **dedicated** sheet, deliberately: adding the text to
  `s5_flat.sch` moves fifteen other goldens.
* **Row V10b** — arm, mask 2, `annotate_at 1e-9`, one export, `annotate_at 4e-9`, one
  export, with no `opa_l_annot` and no redraw between the second call and its export.
  Golden `ZZG10=1` then `ZZG10=4`.
* **Row V10's header was corrected.** It claimed to be G10's witness and is not; it now
  says what it does measure — the SYMBOL-text render path carrying the new value in the
  first frame — and points at V10b for the floater cache.

### The sabotage, re-run against the new row

| variant | mutation | reds |
|---|---|---|
| S9 (before) | `if(rc && floaters) set_modify(-2);` deleted, rebuilt | **nothing**, 410 ALL PASS |
| S9 (after)  | same deletion, same rebuild | **V10b, and only V10b** |

The failure line reads `{0 1 ZZG10=1 1 ZZG10=1}` against `{0 1 ZZG10=1 1 ZZG10=4}` —
the sheet still showing the previous request's number, which is the D5-1 breach this
guard exists to prevent. `src/scheduler.c` restored with `cp` + `touch` and rebuilt;
source md5 identical to the backup; `git diff HEAD -- src/` empty.
⚠ Binary md5 is **not** a valid restore check for a scheduler.c variant — `__DATE__`
and `__TIME__` are compiled in at `scheduler.c:4343`, so two builds of identical source
differ. Compare the source.

## Provenance
A3h sabotage run, variant S9. Backups restored with `cp` + `touch`;
`grep -rn SABOTAGE src/` empty; `git diff HEAD -- src/` empty; tier list green on
the restored binary.
