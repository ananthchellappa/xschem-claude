# 1733 — A Direct Plot, or a re-run plotted under Replace, resets the zoom

**STAMP:** `v1 claim=fixed tree=e0c68fc79 stamped=2026-11-22 fix=taken open=0 by=crew-zoomkeep`

Measured at `e0c68fc79` and with the fix on it, on a private Xvfb: the probe readings below, band
`PV`, and every sabotage named below (each built and run on both suites). Fixed by the commit that
adds this file.

## The report and the ruling

User report, 2026-11-22: after a run, a strip was zoomed, then another signal was sent with Direct
Plot (Ctrl-4), and every strip snapped back to the full sweep. Asked whether a re-run should keep
the zoom as well, the user ruled the same day:

> "yes, re-run which then plots in Replace mode should retain zoom level, not reset it"

## Why it happened

`ase::ui::dp_finish` attaches the session's raw (`wviewer::attach_raw`) before it plots the picked
signals. `attach_raw` re-reads the databases (`ase::attach_dbs`) and then called a plain
`wviewer::regenerate`, which rebuilds every rect from the Tcl model. The engine writes a box zoom,
an axis drag and a pan into the rect only, so the rebuild fitted every strip again. The carry that
the 2026-11-16 rulings gave to a trace added, an Axes dialog and a resize
(`wviewer::view_take` → `wviewer::view_keep`) was deliberately not given to `attach_raw`: it was
listed in row `GZP20` of `tests/headless/test_wave_grid.tcl` as "new data", whose windows fitted the
old data. A Direct Plot attaches the SAME data almost every time, and `~` or the run-end plot under
Replace emptied the subwindow after that attach anyway.

Measured with the fix, on a probe that drives a real Direct Plot into a session on the bundled
`test_nfet_final` raw: fitted `{0 1e-8 1.6 1.7}`, zoomed `{2e-9 4e-9 1.6 1.7}`, after the Direct
Plot `{2e-9 4e-9 0 1.7}` (the X kept; the Y fitted again because that strip gained a trace). In
multi-plot both old strips keep `2e-9 4e-9` and the new strip joins that window. With the same-data
carry taken out again (sabotage 1 below, which is the old plain rebuild), band PV's untouched strip
reads `{0.0 1e-8 0.0 1.0}` where it showed `{2e-9 4e-9 0.0 1.0}`: the reported snap.

## The fix

The rules are in `doc/claude/specs/waveform_viewer.md`, "Keeping the view across a rebuild",
**A Direct Plot, a re-run and `~`** (R1 to R5 and a declared limit). In short:

- **R1, the same data.** `attach_raw` records what it attached per viewer window
  (`wviewer::attach_stamp`: the normalized raw, the analysis, the VCDs, each file's mtime and size,
  and the current database it left). Re-attaching the same thing, unchanged on disk, with that
  database still current (`wviewer::attach_is_same`), carries the view exactly as adding a trace
  does.
- **R2, new data.** The axes the user moved are kept and the others are fitted to the new data
  (`wviewer::view_new_data`). A kept X is dropped when X is not the same thing any more
  (`wviewer::x_same`, now also `view_align`'s test) or when the window does not overlap the new
  sweep (`wviewer::x_overlaps`, inside `wviewer::regenerate`'s new `xnew` arm). When X is not the
  same thing a moved Y is dropped with it (review round, below).
- **R3.** `ase::ui::auto_plot` reads the view after `attach_raw`, with the strips of the target
  subwindow in it, and hands it to its last rebuild once the rows are in, matched among that
  subwindow's old strips only (`wviewer::view_keep_subwin`), so under Replace a strip that comes
  back with its traces takes its view by R1 or R2 and every other subwindow shows what it showed.
  Append keeps the old strips' views; under New SubWin the subwindows already there keep theirs and
  the new one fits; New Tab is unchanged (the tab stash). The rebuild that reflects the
  destination's window half carries the live view (review round, below).
- **R4.** The hand loads (`wviewer::rawbar_load`, `ase::ui::rsel_commit`, `wviewer::display_raw`,
  `wviewer::restore`) keep their plain rebuild and drop the record (`wviewer::attach_forget`), as
  does `wviewer::forget`.

## Behaviour this changes beyond the ruling (declared)

- A failed attach (no database read) used to refit; it is now new data, so moved axes are kept.
- A Direct Plot after a re-run now keeps the moved axes (R2), not only `~`.
- On new data a strip whose X is no longer the same thing (another analysis or X column) keeps
  nothing, a moved Y included (review round): it is rebuilt as if nobody had zoomed it.
- `~` and the run-end plot under New SubWin keep the view of the subwindows already on screen, by
  R1 or R2 (review round). They were fitted again before the fix, and by its first cut.

## Declared limit

A rewrite of the same file to the same size within the same second as the attach before it is taken
for the same data, because the stamp is `file stat`'s whole-second mtime and the size.

## Tests

`tests/headless/test_wave_grid.tcl`: `GZP20` (attach_raw moved out of the plain list), `GZP21`
(attach_raw's order), `GZP27`–`GZP34` (the pure rules, the stamp on a real file, the loader
population, the match inside one subwindow), `GX9` (restated from three to four regenerate sites,
and auto_plot's order).
`tests/headless/test_ase_plot_outputs.tcl` band `PV` (display arm): the real `dp_finish`,
`plot_outputs` under Replace and Append, `rawbar_load` and `attach_raw`, on raws the band writes and
rewrites, every strip read back off its rect; group `PV5` there plots into two subwindows under
Replace and New SubWin and re-runs a tran as an ac; `PV2` attaches an ac and a dc file where the
tran was; `PV6` presses `~` with nothing ticked beside a zoomed subwindow (second review round). Each of five sabotages (no R1 carry, the stamp blind
to the mtime, no R4 drop in `rawbar_load`, unmoved axes carried on new data, no overlap check) turns
rows of both suites red.

## Review round (2026-11-22)

Three findings of the reviewers, each measured on the real path on a private Xvfb, reproduced
first as red rows (group `PV5` and a new leg of `PV2` in `tests/headless/test_ase_plot_outputs.tcl`;
`GZP28` and the new `GZP34` in `tests/headless/test_wave_grid.tcl`), then fixed:

1. **A zoom moved between subwindows under Replace.** `auto_plot` handed its last rebuild a view
   read before `clear_subwin`, and `view_keep` matched it by traces across every subwindow. Once the
   target subwindow's strip count changed, a strip of a subwindow the plot never touched took the
   view of a strip of the emptied one, and the reverse. Red before the fix: with the same rows in two
   subwindows, the second zoomed and a row unticked, `~` into the first reset the second's
   `v(b)` to `{0.0 1e-8 0.0 1.0}`; with a single-plot strip in the first, the first subwindow's new
   strips came up at `{6e-9 8e-9}`, the second's zoom. Fix: `wviewer::view_keep_subwin` (its pure
   half `wviewer::view_within`) matches the old view inside the target subwindow only and gives every
   other strip what it shows now.
2. **A moved Y kept over another analysis.** `view_new_data` dropped only X when `x_same` failed, so a
   tran re-run as an ac kept the transient's Y window over the magnitudes (`{3.0 6.0 0.25 0.5}`, the
   curve off screen). Fix: a strip whose X is no longer the same thing keeps nothing; it is
   rebuilt as if nobody had zoomed it. The brief's R2 named only X; this is a behaviour beyond it,
   declared in the spec.
3. **New SubWin reset every subwindow already there.** The rebuild that reflects the destination's
   window half was plain, so it threw away the view `attach_raw` and `new_subwin` had kept: `~` under
   New SubWin, on the same data, reset the first subwindow's zoom to `{0.0 1e-8 0.0 1.0}`. The first
   cut's comment ("nothing of its own to take from") was true of the new strips only. Fix: that
   rebuild carries the live view (`wviewer::live_axes`). No pre-plot view is read for New SubWin or
   New Tab: the run's strips there are new and fit.

Each fix was taken out again on its own and the rows named went red: Y kept across another analysis
(`GZP28`; `PV2`'s Y leg, `PV5`'s ac rows); the plain rebuild back (`GX9`'s live-view leg; `PV5`'s
two untouched-subwindow rows under Replace and both New SubWin rows); the old view matched across
subwindows (`GX9`'s last-rebuild leg; `PV5`'s three Replace rows); `view_within` matching the
subwindow against the whole old view (`GZP34`; `PV5`'s new-strips row); `view_within` giving the
other strips the old view instead of the live one (`GZP34` three rows; `PV5`'s two untouched-subwindow
rows).

The zero-rows branch of `auto_plot` (Replace with nothing ticked) was read, not measured, in this
round; the second round below measured it and changed it.

## Second review round (2026-11-22)

Four findings, each measured first, on the base `e0c68fc79` with this fix on it:

1. **A real-path row that could not see `x_same`.** Band PV2's ac file sweeps 1e3..1e6, which never
   meets the zoomed transient window (1.2n..1.8n), so regenerate's overlap rule (`x_overlaps`)
   dropped the X whether or not `view_new_data` asked `x_same`. Built as sabotage S7 (the X half of
   `view_new_data` no longer gated on `x_same`, the Y half still gated): only the pure `GZP28` went
   red; band PV stayed green. PV2 now also attaches a dc file whose sweep (X column `v-sweep`) runs
   0..10n, over the kept window's own numbers, with a distinctness row proving by plain arithmetic
   that the engine's fit of it is the written 0..10n, overlaps the window and is not it. Under S7
   that row reads `{0 0 0}` (the window kept on the dc sweep) where it wants `{0 1 1}`. S7b (the
   whole `x_same` gate taken out) reddens it too, with PV2's two Y rows and PV5's two ac rows.
2. **The fix's rows went red on the pre-fix product only by dying.** With `src/wave_viewer.tcl` and
   `src/ase_window.tcl` of `e0c68fc79` swapped in (S0), every PV band ABORTED on `invalid command name
   "wviewer::attach_record"` and `test_wave_grid` died at `GZP27` with `FATAL: key "tr" not known
   in dictionary` (its verdict stopped at `5 FAILED (195 passed)` of the suite's 479 rows). Every answer of a verb this fix
   added is now read through an accessor that answers a value on any failure (`pv_same`,
   `pv_record`, `pv_curdb`, `pv_at`, `pv_swx`; `gzn_dg`, `gzn_dd`, `gzn_ex`, `gzn_cur`,
   `gzn_rest`, `gzn_args`). Under S0 now: `test_wave_grid` 44 FAILED (441 passed) on the counted arm and
   44 FAILED (689 passed) on the display arm, the totals of the fixed tree to the row (no row
   missing, no FATAL); `test_ase_plot_outputs` 36 FAILED (239 passed) on the display arm, the fixed
   tree's total, no band ABORTED, and ALL PASS on the counted arm (band PV is display-only). The sources were restored byte for byte
   (sha256).
3. **`GZP33` missed loaders.** Its pattern missed `xschem raw_clear`, `xschem raw switch_back`,
   `xschem raw table_read`, `vcd_read` and a verb held in a variable (`xschem raw $autoload`), and
   it gave a line to the last column-0 proc above it, so a proc indented in a `namespace eval` was
   never named. The verbs are now derived from `src/scheduler.c`'s own `raw` branch and held as a
   closed partition (a loader or not; a new verb is a red); a verb that is no plain word is taken
   for a loader; the lines go to the proc whose body holds them by Tcl's brace rule, qualified by
   the `namespace eval`s around it, and a row requires every file to end at depth 0. Red first: the
   widened scan named `graph_fill_listbox` and `wviewer::raw_prev_idx`, both now classified (each
   puts the current database back with `switch_back`). Sabotages S9 (a variable-verb `switch_back`
   in `wviewer::x_overlaps`) and S9b (a `raw_clear` in `ase.tcl`'s indented `sim_status_guard`)
   each turn the row red naming the proc (`ase::backend::ngspice::sim_status_guard` for S9b). The
   blind spots the scan cannot see are declared in the row's comment.
4. **Replace with nothing ticked refitted the other subwindows.** Measured on the real path (band
   PV6, private Xvfb): with two subwindows, the second zoomed to 6n..8n and its v(a) strip to
   0.25..0.5 in Y, `~` under Replace with no row ticked into the first left the second at
   `{0.0 1e-8 0.0 1.0}`. The same reading on the pre-fix sources (S0): the plain rebuild after
   `clear_subwin` is older than this fix. Fix: that rebuild carries the live view
   (`wviewer::regenerate $key [wviewer::live_axes $key]`), as the reflect-the-clear rebuild does.
   Sabotage S8 (the plain rebuild back) reddens PV6's row and two `GX9` legs (the zero-rows
   rebuild's order, and "no plain rebuild left in auto_plot").

Found while measuring this: issue 1734 (a Direct Plot makes an expression trace and a Calculator
wave stop drawing). It is older than this fix and not changed by it. (Fixed 2026-11-23; that
issue's file says how.)

## Third review round (2026-11-22)

Three findings in the fences, each measured on the base `e0c68fc79` with this fix on it:

1. **`GZP33` missed `xschem annotate_op`.** Its top-level verbs were the scheduler's names through a
   hand-kept prefix filter (`raw`, `table_read`, `vcd_read`), and `annotate_op`'s branch clears the
   registry and reads a file into it: a reviewer's `proc ase::probe_annot_1733 {f} { xschem
   annotate_op $f }` in `src/ase.tcl` left the suite green. The loader verbs are now derived from
   the C side: a top-level verb, or a sub-verb of `raw`, is a loader when its branch in
   `src/scheduler.c` (comments and strings blanked) calls a registry function, which is
   `extra_rawfile` in any mode but 4, `free_rawfile`, every function of `src/save.c`,
   `src/vcd_read.c` and `src/scheduler.c` that writes the registry, and to a fixpoint every
   function of those files that calls one. That makes `raw case` a loader too (its branch reaches
   `raw_case_reread`, which drops the current database and reads it again); its bare form, a query
   the C answers from a field, is pinned on the C text as the one query form. The method is shown
   on a C text the suite writes; non-vacuity rows name loaders and queries of both kinds. Planted
   in `src/ase.tcl`, the reviewer's probe and `proc ase::probe_case_1733 {} { xschem raw case fold
   }` turn the classification row red naming both procs; a control `proc ase::probe_casebare_1733
   {} { return [xschem raw case] }` leaves it green. `src/ase.tcl` was restored byte for byte
   (sha256). The row's comment now also declares a loader in a callback script registered outside
   every proc and `xschem {*}$cmd`; the depth row is named for its method (it sees a brace shift
   that does not balance out by the end of the file, never one that does).
2. **Band PV still aborted on a layout answer.** With `wviewer::clear_all` in place of
   `wviewer::clear_subwin` under Replace in `ase::ui::auto_plot` (S11), group `PV5` ABORTED on
   `key "2" not known in dictionary` and the display arm read 11 FAILED (247 passed): 17 of the 275
   rows gone from the verdict. Every layout read of bands PV1-PV6 now goes through an accessor that
   answers a value on any failure (`pv_at`, `pv_swx`, `pv_gs`, `pv_auto`, and `pv_axes`, `pv_vecs`,
   `pv_fit`, `pv_zoom`, `pv_sw`, `pv_bysw` catch), and the band's product calls go through `pcall`.
   Under S11 now: 15 FAILED (263 passed), the fixed tree's total, no band ABORTED.
3. **`PV6`'s "attached nothing" leg compared attach records**, which an attach of the same data
   leaves as they were. It is now a spy on the real `wviewer::attach_raw` (every call recorded, then
   handed on), whose arguments a row pins to the real proc's (`info args`, `info default`), with a
   control that the spy sees the one attach a press with rows ticked makes. Sabotage S10 (an
   `attach_raw` put in `auto_plot`'s zero-rows branch, before `capture_live_view_state`) reads 1
   FAILED (277 passed): only the spy's row is red, and its record leg still reads 1 there.
