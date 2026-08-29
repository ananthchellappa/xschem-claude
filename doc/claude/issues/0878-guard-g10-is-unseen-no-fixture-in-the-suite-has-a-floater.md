# 0878 — guard G10 is unseen: no fixture in test_op_annot.tcl has a floater

Status: ⚠ **PARTIAL — ruling settled 2026-08-29** (see the RULING section at the foot of this file, which supersedes the "FIXED / no C change" claim below): one of the operating-point publishers now has a witness — row **V10b**, a dedicated
fixture sheet, no C change. Filed by the A3h sabotage run the same day. Measured, not
inferred, at both ends: the sabotage that reddened nothing now reddens exactly one row.

## RULING — 2026-08-29 (decided under the user's "decide the 23" instruction)

**The dedicated fixture sheet and row V10b are RATIFIED as shipped. Nothing moves,
and no C code changes.**

Nothing the user sees or presses is touched by this: `v_g10.sch` is written fresh
into the run's scratch directory (`test_op_annot.tcl:201`, `set lib [file join
$scratch lib]`), it is not a tracked file, it ships in no library, and it appears in
no menu, dialog or keybinding. The only thing that changed is that the annotation
suite now has one more row.

Ratified because the row buys the one thing this branch keeps failing to have:
a guard that a reader can actually see earn its place. Before V10b, deleting
`if(rc && floaters) set_modify(-2);` from `src/scheduler.c` left the whole suite
green — a guard shipped untested behind a row named after it. That is the exact
shape of "two defects shipped past twenty-eight passing checks". After V10b the same
deletion reds one named row, and what it reds is a **D5-1** breach: the sheet keeps
showing the previous request's number after the user moves the waveform cursor and
presses Alt-Shift-6 again.

Its own sheet rather than a text added to `s5_flat.sch` is also ratified: adding a
schematic-level text there moves fifteen other inline expectations in the same file,
which is fifteen goldens' worth of churn to buy one check. A separate sheet costs one
`file mkdir`-scoped write and moves nothing.

Verified in the tree before ruling:
* `src/scheduler.c` — the guard line `if(rc && floaters) set_modify(-2); /* refresh
  floater caches: see guard G10 above */` is present in the `annotate_at` arm.
* `src/actions.c:87` `there_are_floaters()` scans only `xctx->text[]`, confirming the
  finding that a sheet of `lab_pin` instances with no `T` record counts zero.
* `src/actions.c:1325` `t->flags |= xctx->tok_size ? TEXT_FLOATER : 0;` — the `name=`
  property on the fixture's text is what makes it a floater, as the row claims.
* `tests/headless/test_op_annot.tcl` — V10b and the `v_g10.sch` fixture are committed
  at HEAD (not working-tree-only), `git diff` over that file touches neither, and the
  fixture lands in scratch, so no untracked `.sch` litter reaches the repo root.
* No `tests/headless/gold/` baseline exists for this suite; its expectations are
  inline, so "no golden moved" means the fifteen inline expectations in the file.

No user ruling was worth spending here: this is a test-only change with no
user-visible surface, and the alternative — leaving a real guard uncovered — is one
this project's own standing rules already forbid.

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

## RULING, 2026-08-29 — decided on the user's instruction

The user said, verbatim: *"decide the 23, leave 0861 and 0299 for me"*. This debt was
one of the 23 classified as cheap and obvious — a question whose answer the codebase's
own standing rulings already settle — so it was decided here rather than added to the
user's reading queue. It is not a new choice being made for them.

**This section supersedes the earlier RULING section above.** That one was reviewed by
an adversary and partly overturned; the earlier text is left untouched as a record of
what was first decided, but where the two differ, this one governs.

### The ruling, as an instruction to the codebase

1. **KEEP row V10b and its dedicated `v_g10.sch` scratch sheet.** Do not move its
   expectation into `s5_flat.sch`: that would churn fifteen inline expectations in
   that file to buy one check, and the separate sheet costs nothing but a scratch
   write. This half of the earlier ruling stands unchanged.
2. **The clause "and no C code changes" is STRUCK.** The same evidence that justifies
   V10b shows the floater-refresh guard is *missing entirely* from the other three
   operating-point publishers. That is a live defect, not a style preference, and the
   earlier ruling foreclosed its repair.
3. **0878 does not close as FIXED. It is PARTIAL.** Its own headline is "no fixture in
   the suite has a floater"; after V10b exactly one floater fixture sits on the
   Alt-Shift-6 (`annotate_at`) path, and the publishers behind `6`, `Alt-6` and a
   results-file switch in the waveform viewer still have no witness — because they
   still have no guard.
4. **Follow-up work, not yet done** (recorded here because this run may write only
   this file):
   * Make the three unguarded publishers honour the same guard the Alt-Shift-6 arm
     already carries at `src/scheduler.c:2372` — read `there_are_floaters()` before
     the operation, call `set_modify(-2)` after a successful publish:
     `src/scheduler.c:2544` (the `annotate_op` arm behind the `6` and `Alt-6` chords),
     `src/scheduler.c:10541` (`raw switch`) and `src/scheduler.c:10554`
     (`switch_back`). The switch pair is the most urgent: it can never be rescued by
     luck (see below). The bare `xschem update_op` verb at `src/scheduler.c:14038` is
     the same shape and should be settled with them.
   * File those three as their own issue, citing the shipped floaters that make the
     staleness user-visible.
   * Point the fixture that now exists at more rows: reuse `v_g10.sch` for a
     `6`/`Alt-6` row and a `raw switch` row. That costs rows, not goldens — which is
     the very argument used above to justify the dedicated sheet.

### Why

* **D5-1** — never a number displayed next to a thing it was not measured for — is the
  user's own standing ruling, so making every publisher honour it is compliance, not a
  new decision. `xctx->text[i].floater_ptr` is sticky: filled lazily in
  `get_text_floater()` and freed, on the annotation path, in exactly one place —
  `set_modify()`'s floater block at `src/actions.c:238-243`. `draw()` does not clear
  it, and `annot_data_changed()` bumps only the operating-point overlay epoch, a
  different cache model (`src/actions.c:1710` says so in as many words). So after a
  results-file switch, or a `6` press onto a file the waveform viewer already holds,
  the operating-point blocks repaint with the new database's numbers while every
  floating text keeps rendering the previous database's string — two runs' numbers on
  one sheet at once, with nothing saying so.
* **This is shipped content, not a test contrivance.** Floating texts carrying these
  very values ship in the standard library: `xschem_library/examples/cmos_example.sch:194`
  (`Power: @spice_get_voltage(power)`, `floater=true`) and
  `xschem_library/ngspice/solar_panel.sch:269-270` (`@spice_get_current`, `name=L2` /
  `name=C1`). Sharpest of all, `xschem_library/examples/cmos_example.sch:186` and
  `xschem_library/examples/test_ac.sch:92` carry `tcleval([xschem raw info])` as a
  floating text — a label whose whole job is to say *which results file is loaded*.
  After a file switch from the waveform viewer's own selector it keeps naming the old
  file beside the new file's numbers. A provenance stamp that lies is worse than none.
* **INTENT OVER MECHANISM** — closing this as FIXED with "no C code changes" ruled in
  would have been locally correct at every joint and collectively wrong: the
  investigation's own findings point straight at the defect the row was written to
  prove matters, arriving through the chord the user presses most.
* **PLAIN ENGLISH** — the report to the user says what was found, not only what was
  kept. The one-line summary owed to them is: *"Kept the extra test sheet that proves
  the schematic really repaints when you move the waveform cursor and press Alt-Shift-6
  again — and while checking it I found the same safeguard is missing on the `6` chord
  and on switching results files in the waveform viewer, where a node-voltage or
  current label can keep showing the previous run's number. Filed; no action needed
  from you."*

### What was verified in the tree (so a later reader need not re-derive it)

* `src/scheduler.c:2372` — the guard is present in the Alt-Shift-6 arm exactly as this
  issue describes: `floaters = there_are_floaters(); rc = backannotate_at_time(...);
  if(rc && floaters) set_modify(-2);`.
* `src/scheduler.c:2543-2544` — the `annotate_op` arm (the `6` / `Alt-6` chords) is
  `update_op(); draw();` with no floater refresh of its own.
* `src/scheduler.c:10530-10543` (`raw switch`) and `:10549-10556` (`switch_back`) —
  each calls `update_op()` under an `allpoints == 1 && (op|dc)` condition, with no
  floater refresh. `src/scheduler.c:14038` (`xschem update_op`) is bare.
* `src/save.c:1267` — `set_modify(-2); /* clear text floater caches */` lives inside
  `raw_read()`'s successful-read branch only. `extra_rawfile()`'s switch arms
  (`src/save.c:1954-1995`, `what == 2` and `what == 5`) move `xctx->extra_idx` and
  reassign `xctx->raw` **without reading a file at all**, so that clear can never
  cover a switch. The `/* file found: switch to it */` branches of the read arms
  (`src/save.c:1900`, `:1948`) likewise skip the read when the viewer already holds
  the file, which on this branch is the normal state.
* `src/actions.c:87` — `there_are_floaters()` scans only `xctx->text[]` for
  `TEXT_FLOATER`, confirming a sheet of `lab_pin` instances with no `T` record counts
  zero. `src/actions.c:1325` — `t->flags |= xctx->tok_size ? TEXT_FLOATER : 0;` after
  the `name` lookup, so the fixture's `name=p1` is what makes its text a floater.
* `src/actions.c:238-243` — the only free of `floater_ptr` on this path;
  `src/actions.c:1685-1689` names `annotate_op` / `raw switch` / `update_op` as the
  three requests that funnel through the point-0 publisher; `src/actions.c:1710`
  contrasts the overlay epoch with the `xText.floater_ptr` model.
* `tests/headless/test_op_annot.tcl:11651-11711` — row V10b, the inline `v_g10.sch`
  heredoc with `T {ZZG10=@spice_get_voltage} -200 -200 0 0 0.2 0.2 {name=p1}`, and its
  expectation `{0 1 ZZG10=1 1 ZZG10=4}`. It is committed at HEAD, not working-tree-only.
* `tests/headless/test_op_annot.tcl:201` — fixtures are written into the run's scratch
  directory, so no untracked `.sch` reaches the repo root (the known litter trap).
  No `tests/headless/gold/` baseline exists for this suite; its expectations are inline.
* **Refinement on the coverage claim, measured rather than assumed:** `v_g10.sch` is
  not the suite's only floating-text fixture — `u_acc.sch`, `u_nr.sch` and `u_edit.sch`
  (built around `test_op_annot.tcl:7716`, `:7728`, `:7756`) carry `floater=true` texts
  for the U-series rows. It *is* the only one on the Alt-Shift-6 path. And row **O37**
  (`test_op_annot.tcl:5646-5669`), the one row that does switch between two operating-
  point databases under a static schematic, loads `o_rl.sch`, which has no
  schematic-level floating text — so the switch-path staleness is covered by nothing.
  The finding stands either way.

### Does anything move?

**Partly.** Keeping V10b and `v_g10.sch` ratifies what already ships — nothing the user
sees or presses changes, and no golden moves. **The follow-up in point 4 implies a real
code change and it is NOT yet done**: three (arguably four) publishers in
`src/scheduler.c` need the guard, the rows that would witness them are not written, and
the separate issue for the unguarded publishers is not yet filed — this run was
permitted to write only this file.

An adversary reviewed the first ruling and overturned it in part: it accepted the
dedicated fixture sheet and row V10b, and struck the "no C code changes" clause and the
FIXED close, on the ground that the deciding pass's own evidence exposes a live D5-1
breach on the `6` chord and on a waveform-viewer file switch.

The user may reverse this at any time; it was decided to spare their attention, not to
bind them.
