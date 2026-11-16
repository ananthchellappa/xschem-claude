# Stage A receipt: drag frame time, the `cadsnap` read

Crew A, 2026-11-15. Base `bd14668b9`. Fix in the clone `~/gdf0`, uncommitted. Patch:
`A-fix.patch`, next to this file, **md5 `a36e6556d0585785dcdb6e3f09a8b6f6`**. It is
`git -C ~/gdf0 diff bd14668b9`: 9 files, +514 −32, the new suite included. It applies
cleanly to a `git archive bd14668b9` export (`git apply --check`).

## In plain English

**What was slow.** Dragging a device on a fluid-wiring page runs a set of wiring checks
on every mouse step. They ask "is this point on that pin, is this pin on that wire". Each
check began by fetching the snap size, `cadsnap`, from Tcl by name: a hash lookup, then a
text-to-number parse through `sscanf`. These checks run inside loops over pins × wire
segments, so one constant was fetched thousands of times per mouse step. A small page made
867–1822 fetches per step and a page ten times larger made 28 299–57 046. That fetching was
**75–90% of the drag's CPU** on the three real pages profiled.

**What changed.** The C side now keeps the parsed value and fetches it again only when it
may have changed. There is one new function, `tclgetcadsnap()` in `src/scheduler.c`, and
28 call sites switch to it. Nothing else moves. Saved schematics and netlists from scripted
drags on 8 real pages are byte-identical to base, and so are the suite outputs. The cache
can't go stale because three separate things drop it (§3), and each of the three has a
test row that only it can pass.

**Before/after, per frame, on real pages.** Real Tk drags on Xvfb + openbox. The figure is
the median ms per motion event, from `event generate` through `update` and an X round
trip, so it includes drawing. K is the number of selected devices dragged.

| page (instances) | K=1 | K=3 | K=5 | K=12 |
|---|---|---|---|---|
| tb_tca_tran (167) | 58.3 → **12.5** | 78.1 → **14.4** | 84.1 → **15.2** | 105.7 → **17.7** |
| test_comparator (168) | 39.7 → **9.7** | 66.5 → **12.2** | 78.0 → **13.5** | 123.1 → **19.5** |
| charge_pump (80) | 29.0 → **8.4** | 29.1 → **8.6** | 29.6 → **9.5** | 63.9 → **13.9** |
| sg13g2_sdfrbp_2 (81) | 31.9 → **7.9** | 31.7 → **7.9** | 31.6 → **7.9** | 31.8 → **7.9** |
| tca_main (109) | 18.4 → **5.8** | 26.6 → **6.8** | 34.0 → **8.1** | 64.0 → **13.8** |
| bandgap (115) | 15.4 → **7.0** | 21.0 → **8.9** | 28.0 → **10.1** | 40.8 → **12.7** |
| rom8k (169) | 18.4 → **13.3** | 26.5 → **14.7** | 34.4 → **15.3** | 75.5 → **21.4** |
| test_nfet_TRAN (7) | 3.7 → **3.4** | 4.4 → **3.9** | – | – |

At K ≤ 5, every page now fits one 60 Hz refresh (16.7 ms). Before the fix, only the
7-instance page and bandgap's one-device drag did. At K = 12, three pages remain slightly over one refresh
(17.7, 19.5, 21.4 ms). The remaining cost is other work (§9), not this read.

## 1. The change (by symbol)

- **`tclgetcadsnap()`** (`src/scheduler.c`, just above `xschem()`): returns exactly what
  `tclgetdoublevar("cadsnap")` returns. The first time, it installs a write/unset trace on
  `::cadsnap`. It then reads with `Tcl_GetVar` and parses with `atof_spice()`, the same
  conversion `tclgetdoublevar()` uses, and caches the result. If the variable is missing,
  it never caches: it falls through to `tclgetdoublevar()`, so the `dbg()` message, the
  interp error result and the 0.0 are unchanged.
- **`cadsnap_trace()`**: drops the cache. On `TCL_TRACE_DESTROYED` or
  `TCL_INTERP_DESTROYED` it also clears `cadsnap_traced`, so the next read re-installs the
  trace.
- **`tclsetcadsnap()`**: the only way C writes `::cadsnap`. It calls
  `tclsetdoublevar()` and then drops the cache. `set_snap()` in `src/actions.c` uses it.
- **`xschem()`**: its first statement drops the cache (`cadsnap_cache_ok = 0;`).
- **28 call sites** of `tclgetdoublevar("cadsnap")` now call `tclgetcadsnap()`: move.c 15,
  callback.c 6, actions.c 3, check.c 1, select.c 1, plus `run_core` "align" and the
  `log_action` of `xschem set cadsnap` in scheduler.c. Two comments that quoted the old call were updated.
  In callback.c, check.c, move.c and select.c the diff touches **only** lines that mention
  `cadsnap`: a grep of the changed lines for anything else returns nothing.
- `src/xschem.h`: two prototypes.
- **New suite** `tests/headless/test_drag_tclvar_reads.tcl`, 37 checks. It is registered
  in `tests/run_regression.tcl`, in `hcases` alone, in the same change (§6).

C89 only: no declarations after statements and no `//` comments. It uses Tcl API only and
no platform code. The trace callback's signature is the same as the existing
`ngspice_data_trace()` in `src/save.c`.

## 2. Profile (what the fix was chosen from)

callgrind, `--toggle-collect=move_objects`, Ir. The base binary has debug info.

| run | base Ir | fixed Ir | `tclgetdoublevar` inclusive share in base |
|---|---|---|---|
| tb_tca_tran, 3-device drag | 21.55 G | 2.72 G | 87.55% (atof_spice 45.37%, of which sscanf 40.5%; Tcl_GetVar2 41.89%) |
| test_comparator, K=12 | 34.05 G | 3.46 G | 90.03% |
| bandgap, K=5 | 5.97 G | 1.49 G | 75.12% |

On tb_tca_tran in base, most of it comes from `fluid_ml_hazards` (58.99% inclusive,
12.7 G → 0.62 G after the fix), through `fluid_pin_on_seg` and `point_near_pin`.

Base `src/move.c` has these readers inside loops: `point_near_pin`, `fluid_pin_on_seg`,
`fluid_seg_pair_touch`, `fluid_seg_pair_touch_except`, `fluid_reroute_around_obstacles`,
`fluid_shove_*`, `fluid_jog_*`, `fluid_offset_foreign_pin_landing` and
`fluid_straighten_reversals`. They read the variable per call, not per frame.

**What the fixed tb_tca_tran profile spends its time on** (inclusive):

| function | share |
|---|---|
| fluid_ml_hazards | 22.6% |
| translate | 15% |
| prepare_netlist_structs | 13.5% |
| tcleval (the `sim_is_*` calls inside translate) | 12% |
| symbol_bbox | 11.3% |
| write_backup | 6.2% |
| update_symbol_bboxes | 5.3% |

On comparator, translate is 22% and tcleval 18%. On bandgap they are 34% and 25%.

**Read probe** (the suite's instrument: a Tcl read trace on every scalar global, counted
per `xschem move_objects step`):
- Base, cadsnap reads per step: N=4 gives `867 867 1822 1820 1820 1731`; N=40 gives
  `28299 28299 57046 57044 57044 56595`.
- Fixed: at most 1 per step, and the total of all global reads per step is the same at
  N=4 and N=40 (rows R1–R3, drawing off).

## 3. Every way cadsnap can change, and why the cache can't go stale

**The three invalidations** (stated in the source comment above `tclgetcadsnap()`):

1. **The write/unset trace on `::cadsnap`.** It sees every write, by any writer, because
   Tcl itself enumerates the writers. An unset destroys every trace on the variable, and
   the next read re-installs ours before trusting anything.
2. **Every entry into `xschem`.** Tcl runs a variable's write traces newest first. So a
   write trace added after ours runs before ours has dropped the cache, and if its body
   calls into C, it can only do so through `xschem`. The cost is at most one real read per
   `xschem` command.
3. **`tclsetcadsnap()`.** Tcl disables every trace on a variable while one of its traces
   runs. A write made inside another write trace on `::cadsnap` therefore fires none,
   ours included. If the outer writer was C, it re-reads because of this invalidation; if
   the trace body calls C, it goes through `xschem` and is covered by (2).

**Each path, and the row that proves it:**

| change path | writer | covered by | proof |
|---|---|---|---|
| `set cadsnap v` / `set ::cadsnap v` (scripts, console, rc file, plugins) | Tcl | 1 | S4 `plainset` both ways; S1 |
| `xschem set cadsnap v`, and the snap dialog (`input_line … {xschem set cadsnap}`) | C `set_snap` → `tclsetcadsnap` | 2, 3 (and 1) | S1a/S1b; S4 `xschemset` |
| `xschem snap double` / `half` | C `set_snap` | 2, 3 | S4 `snap double`, `snap half` |
| statusbar entry (`set ::cadsnap …; xschem set cadsnap $::cadsnap`) | Tcl + C | 1, 2 | S4 `statusbar` |
| `upvar` alias | Tcl | 1 (the trace belongs to the variable, not the name) | S4 `upvar` |
| restore_ctx per tab or window (`uplevel #0 set`, run by a `tclvareval` from C) | Tcl | 1 | S4 `uplevel0`; `tabs.tcl` probe: 3 contexts at snaps 10/20/5, 7 switches, each drag used its own context's snap, B and F identical |
| change during a drag (a `tcleval` mid-command, or a binding between motions) | Tcl | 1 (mid-command), 2 (each motion is an `xschem callback`) | S1 (a read trace on `::autotrim_wires` rewrites cadsnap inside one `xschem align`); GUI identity drag d4 (`xschem set cadsnap 20` between motions 4 and 5), byte-identical to base |
| `unset` then `set` | Tcl | 1 with re-install | S3, S3b, S3c |
| a newer user write trace whose body calls `xschem` | Tcl | 2 | S2 |
| a write inside another write trace on cadsnap (traces disabled) | Tcl or C | 2 + 3 | S6, S6b, S6c |
| non-normalised spelling (`1.5e1`) | – | `atof_spice`, as before | S5 |
| startup `set_ne cadsnap` in `Tcl_AppInit` | C | runs before any read; the cache starts invalid | – |
| interp teardown | – | `TCL_INTERP_DESTROYED` clears the trace flag | – |

**Every row above is red if its own invalidation is removed.** Each sabotage was built
from the final source and run through `run_suites.sh --nogui`:

| sabotage | red rows |
|---|---|
| `notrace` (trace body does not drop the cache) | S1, S3 |
| `noentry` (no drop at `xschem` entry) | R4, S2 |
| `noreinstall` (trace not re-armed after unset) | S3 |
| `noset` (`tclsetcadsnap` does not drop the cache) | S6 |
| `noinval` (all three removed) | 17 failures over R4, S1, S1a, S2, S3, S3b, S4, S4a, S5, S6, S6b |

The base binary fails only R1, R2 and R3 (34 passed). The S rows pass on base because
base has no cache and so cannot be stale.

**The other C entry points.** Invalidation 2 assumes that C code which runs from Tcl runs
under `xschem`. The C entry points other than `Tcl_CreateCommand(interp, "xschem", …)` are:
- the signal handlers in `main.c`;
- the exit handler `tclexit()`;
- the `ngspice::ngspice_data` trace callback in `save.c`.

None of them reads cadsnap.

## 4. Identity (byte-identical results)

**Seam sweep** (`ident_seam.tcl`):
- Setup: 8 real pages. On each, up to 16 devices spread across the page, each given a
  live-commit stretch drag of 6 steps through `xschem move_objects start … kissing stretch
  / step / end`, at snaps 10, 5 and 20. The page is saved after every drag and then undone.
  After each snap, the undone state is saved and a netlist written.
- Volume: 342 drags, 342 + 24 saved schematics and 24 netlists, **390 files**.
- Result: **390/390 identical**, base vs fix. All 366 schematics are raw byte-identical.
  The 24 netlists are identical once the `wd/B` vs `wd/F` path in their header is mapped
  out.
- Run on the final fix and on the earlier fix (before invalidation 3): both identical.

**GUI sweep** (`ident_gui.tcl`), through the real event path (Tk events on `.drw` →
`xschem callback`):
- Setup, per page: 5 committed drags with the snap changed between drags and during one.
  d1: K=3. d2: `xschem snap double`, K=1. d3: plain `set ::cadsnap 5`, K=5. d4:
  `xschem set cadsnap 20` between motion 4 and motion 5. d5: `uplevel #0 {set cadsnap 10}`,
  K=8. Then undo, undo, redo, each saved, and a netlist.
- Result: **80/80 identical** (8 pages × 10 files). The 72 schematics are raw-identical;
  the 8 netlists are identical after path mapping.
- **Not vacuous**: 38 of the 40 drags changed the saved page. The two that did not are
  tb_tca_tran d1 and d5; d5's press landed on a pin (ui=1).

**Pages**:
- sky130A: `bandgap`, `test_comparator`, `tb_tca_tran`, `charge_pump`, `tca_main`;
- `xschem_library/rom8k/rom8k`;
- ihp-sg13g2: `sg13g2_sdfrbp_2`;
- gf180mcuD: `test_nfet_TRAN`.

Each was copied to scratch and loaded from there.

## 5. Speedup, measured ABAB

**Design.**
- Four interleaved rounds on one private Xvfb (`:272`, 1920x1080x24, openbox), in the order
  B F / F B / B F / F B.
- Each round covers every page at K ∈ {1, 3, 5, 12}, 2 drags per K, 12 timed motions each,
  every motion crossing a snap step.
- Only drags that armed a move (ui=40) are counted. That drops the first K=1 drag of each
  run, which rubber-bands (ui=16).
- n is 48 frames for K=1 and 96 for K ≥ 3.

**Machine.**
- 20 cores; 1-minute load 1.1–1.6 at round starts.
- Other agents' xschem processes alive at round starts: 10, 10, 0, 1.
- Rounds ran 14:58–15:01, all after the final fix binary was built (14:46:53).

**Builds.** Base `-pipe -O2 -g`, fix `-pipe -O2`. `-g` does not change gcc's code at -O2.

**Results.** Median ms over all frames, with the min..max of the per-round medians:

| page | K | base | fixed | ratio |
|---|---|---|---|---|
| bandgap | 1 | 15.4 (14.0..16.9) | 7.0 (6.6..7.4) | 2.2x |
| bandgap | 3 | 21.0 (20.4..22.5) | 8.9 (8.6..9.4) | 2.4x |
| bandgap | 5 | 28.0 (27.1..29.2) | 10.1 (9.5..10.6) | 2.8x |
| bandgap | 12 | 40.8 (39.2..41.7) | 12.7 (12.1..13.8) | 3.2x |
| comparator | 1 | 39.7 (33.9..41.0) | 9.7 (9.5..10.4) | 4.1x |
| comparator | 3 | 66.5 (61.2..73.4) | 12.2 (11.8..13.1) | 5.4x |
| comparator | 5 | 78.0 (71.8..83.0) | 13.5 (12.9..14.3) | 5.8x |
| comparator | 12 | 123.1 (113.6..131.2) | 19.5 (18.2..21.4) | 6.3x |
| cpump | 1 | 29.0 (28.4..32.3) | 8.4 (8.1..9.3) | 3.4x |
| cpump | 3 | 29.1 (28.7..31.4) | 8.6 (8.2..9.4) | 3.4x |
| cpump | 5 | 29.6 (28.3..31.9) | 9.5 (8.9..10.2) | 3.1x |
| cpump | 12 | 63.9 (62.2..67.4) | 13.9 (13.4..15.7) | 4.6x |
| gfnfet | 1 | 3.7 (3.3..4.2) | 3.4 (3.3..4.1) | 1.1x |
| gfnfet | 3 | 4.4 (4.1..5.2) | 3.9 (3.5..4.3) | 1.1x |
| rom8k | 1 | 18.4 (17.6..19.7) | 13.3 (12.9..13.9) | 1.4x |
| rom8k | 3 | 26.5 (26.1..28.4) | 14.7 (14.1..15.1) | 1.8x |
| rom8k | 5 | 34.4 (33.9..36.5) | 15.3 (14.8..16.1) | 2.2x |
| rom8k | 12 | 75.5 (73.9..81.2) | 21.4 (20.3..22.2) | 3.5x |
| sdfrbp | 1 | 31.9 (30.2..33.2) | 7.9 (7.6..8.1) | 4.0x |
| sdfrbp | 3 | 31.7 (29.2..33.3) | 7.9 (7.5..8.4) | 4.0x |
| sdfrbp | 5 | 31.6 (29.8..33.8) | 7.9 (7.5..8.2) | 4.0x |
| sdfrbp | 12 | 31.8 (29.1..33.9) | 7.9 (7.6..8.3) | 4.0x |
| tbtcatran | 1 | 58.3 (56.1..63.6) | 12.5 (11.4..13.3) | 4.7x |
| tbtcatran | 3 | 78.1 (74.8..86.7) | 14.4 (13.3..16.4) | 5.4x |
| tbtcatran | 5 | 84.1 (80.1..91.4) | 15.2 (14.6..16.5) | 5.5x |
| tbtcatran | 12 | 105.7 (99.4..119.0) | 17.7 (16.7..19.0) | 6.0x |
| tcamain | 1 | 18.4 (18.2..20.4) | 5.8 (5.4..5.9) | 3.2x |
| tcamain | 3 | 26.6 (26.3..31.0) | 6.8 (6.5..7.6) | 3.9x |
| tcamain | 5 | 34.0 (33.4..38.9) | 8.1 (7.9..8.9) | 4.2x |
| tcamain | 12 | 64.0 (61.1..74.4) | 13.8 (13.3..14.8) | 4.6x |

No base and fixed spread ranges overlap except gfnfet, the 7-instance page, which barely
runs the fluid passes.

**Scaling grid** (`gridseam.tcl`): N sky130 nfets, each with a wire, 40 per row. One device
dragged through the seam with drawing off, 6 timed steps. Two rounds (B F, F B) at
N ≤ 800; at N = 1600, two rounds of 2 reps. The table gives median ms per step:

| N | base | fixed | ratio |
|---|---|---|---|
| 100 | 29.6 (28.0..30.4) | 5.0 (5.0..5.0) | 5.9x |
| 200 | 101.1 (99.9..104.8) | 13.3 (12.6..13.7) | 7.6x |
| 400 | 387.9 (386.4..394.2) | 37.3 (37.2..37.4) | 10.4x |
| 800 | 1530.9 (1527.8..1541.3) | 138.1 (136.6..139.4) | 11.1x |
| 1600 | 6065.8 (6055.9..6067.7) | 506.3 (505.1..507.2) | 12.0x |

The brief's "about 50 ms at 100 devices + 100 wires" is this fixture at N = 100. Its figure
included drawing; this one, 29.6 ms, does not. Both columns are still roughly quadratic:
×3.4–4.0 per doubling in base, ×2.7–3.7 in the fix. The quadratic is a
different one now (§9).

## 6. The fence: red on base, green after, registered

`tests/headless/test_drag_tclvar_reads.tcl`, 37 checks, runs headless.

**Band R** (reads per live-commit drag step on a 4-device page and a 40-device page):
- R1/R2: cadsnap is read from Tcl at most once per step.
- R3: the total of all global reads per step is the same on both pages, which catches any
  variable re-read per pin or per wire.
- R0: the counted drags ran with drawing off.
- R4–R7: non-vacuity (the instrument sees C reads; every step committed a reroute; a drag
  of every device does grow the count; the fixture size).

**Band S**: the staleness rows tabulated in §3.

**Results, through `run_suites.sh`** with `GUI_GATE=0 AUDIT_DISPLAY=:274`:

| binary | `--nogui` | display arm |
|---|---|---|
| fix | `ALL PASS (37 checks)` | `ALL PASS (37 checks)` |
| base (same suite file) | `3 FAILED (34 passed)`: R1, R2, R3 | `3 FAILED (34 passed)`: R1, R2, R3 |

**Registration.**
- Placement: in `hcases` alone, appended after `headless/test_wave_subwindows`, with a
  `##` comment saying why.
- Banner rule: the epilogue prints `OVERALL: ok (37 checks)` and then `RESULT:` last. The
  hcases-shape capture scores `banner_complete=1` with `banner_rule.tcl` sourced, prints
  0 lowercase `^skip:` lines, and has exactly one `RESULT:` line.
- **Derived T1 delta: cases +1, blocks +1, counted_failures +0, skips +0, `wc -l` +3.**
  This is not a predicted figure; T1 itself was not run here (stage C's gate).
- Meta-suites green on the fixed tree: `test_registered_banner_1626` (10),
  `test_suite_watchdog_1403` (40, including W20h), `test_home_isolation` (120, including
  G2 and X), `test_issue_stamp` (102), `test_scratch_home_note` (22).

## 7. Suites, base vs fix

**Selection.** 137 suites from `tests/headless/`:
- 79 whose name matches fluid, wire, drag, move, snap, stretch, rotate, select, cadence or
  similar, or that use cadsnap;
- 58 from `wireedit`;
- both arms where the suite has one (137 headless, 79 display).

**Verdicts.** The `run_suites.sh` verdict lists were identical, B vs F, apart from the new
suite. These were measured on the fix before invalidation 3; the final fix was then
re-checked by full output (below).

**Full output** (`fullout.sh`: each suite run on its own, from a temporary cwd, output
normalised for binary path, scratch paths, timings and pids). Final fix vs base:
- headless: 136/137 identical, the exception being the new suite;
- display: 77/79 identical, the exceptions being the new suite and
  `test_key_graph_context`;
- exit codes identical.

`test_key_graph_context`'s zoom depends on the length of the install path. Running the
fixed binary from a path as long as base's gives base's `z=0.9597`.

**Not passing on base, identically not passing on the fix** (pre-existing at `bd14668b9`,
not touched):
- headless NORESULT: `test_cadence_descend_newwin_ro`, `test_cadence_drag`,
  `test_key_graph_context`, `test_phase3_mints`, `test_select_at`, `test_selflog_output`,
  `test_wire_complete_with_selection`, `test_wire_stub_bindings`, `test_wire_vertex_grab`;
- display FAIL: `test_cadence_drag` (2), `test_rotate_stretch_short_0104` (1),
  `test_select_at` (5), `test_snap_bindkeys`;
- display NORESULT: `test_cadence_descend_newwin_ro`, `test_phase3_mints`,
  `test_selflog_output`.

With `--logdir`, base's `test_select_at` and `test_snap_bindkeys` pass, and
`test_selflog_output` still fails (six `key … logs …` rows).

## 8. Health

- **Warnings**: cairo build 6 = 6, no-cairo 6 = 6, `-std=c89 -pedantic` 67 = 67, and
  `-Wall -Wextra` on the changed files 208 = 208. The warning texts diff empty.
- **valgrind memcheck** (leak-check full), on a seam sweep and on the GUI drag sequence,
  base and fix:
  - 0 invalid reads or writes, 0 uninitialised-value uses;
  - every definite-loss record is allocated inside fontconfig or cairo under
    `resetcairo()` at startup, with no xschem source frame in any of those records;
  - the `cairo_xlib_surface_create` record shows up in 3 of the 4 runs (all but base's
    seam run), so whether it appears varies between runs.
- **`--nogui --pipe`**: both stdin and `--script` modes behave identically to base.

## 9. Limits (declared, not fixed)

1. **A Tcl read trace on `::cadsnap` fires only at real reads.** One that rewrote the
   value on read would be honoured only then. Nothing in the tree puts a trace on
   `::cadsnap`. This is stated in the source comment.
2. **A missing variable costs two Tcl reads instead of one** (`Tcl_GetVar`, then
   `tclgetdoublevar()`). It returns the same value, message and result. An unset
   `::cadsnap` is not a working state anyway.
3. **Draw-time per-object Tcl reads remain**: `draw()` reads `lvs_ignore` per symbol and
   `auto_set_wire_bus` per wire. They grow with the page; with drawing on, the per-step totals
   were 294–398 reads at N=4 and 438–542 at N=40. R3 runs with drawing off, and R0 asserts that,
   so **R3 does not fence `draw()`**.
4. **The remaining frame cost is other work.** At K=12, three real pages are still over
   one refresh (17.7, 19.5, 21.4 ms). From the profiles:
   - `translate()`'s `sim_is_*` `tcleval`s: 12–25% of the remaining CPU. Caching these is
     not a pure change, because `set_sim_defaults` has side effects;
   - `prepare_netlist_structs` on every frame;
   - `write_backup` on every `set_modify`;
   - `symbol_bbox` / `update_symbol_bboxes`;
   - a full redraw per frame.
5. **Still quadratic on big pages.** The grid gives 138 ms per step at N = 800 and 506 ms
   at N = 1600. callgrind of the fix at N = 400 (inclusive):

   | function | share |
   |---|---|
   | `fluid_build_partition` / `fluid_partition_changed` | 28.8 / 27.1% |
   | `prepare_netlist_structs` | 23.5% |
   | `remove_move_orphan_wires` | 18.0% |
   | `fluid_reroute_around_obstacles` | 17.7% |
   | `point_on_fixed_pin` | 17.6% |
   | `strcmp` (self) | 20.6% |

   `tclgetcadsnap` itself is 3.0% self there: many calls, each now a flag test.
6. **Input was synthesised, on Xvfb.** The user's real display (the Windows X server over
   TCP) was not measured and no real hand drag was made. The fix removes CPU work in the C
   engine, which does not depend on the X server, but absolute frame times on that screen
   are unmeasured.
7. **Not built on Windows. Not built against Tcl 8.4.** It uses only Tcl API calls that
   `src/save.c` already uses, with the same callback signature.
8. **The base binary has `-g`; the fix does not** (§5).

## 10. Harness notes (pre-existing, found on the way)

- **`run_suites.sh` does `cd "$REPO"`**, so its xschem runs with cwd at the clone root. My
  run_suites passes therefore ran with cwd at `~/gdf0`'s root. Suites wrote 12 `*~.sch`
  backups there:
  - `tests/untitled~.sch`
  - `tests/from_user/before_{3,5,7,10,39,41}~.sch`
  - `tests/headless/fixture_0098_pre~.sch`, `tests/headless/fixture_0105_pre~.sch`
  - `xschem_library/examples/nand2~.sch`, `xschem_library/examples/tb_test_evaluated_param~.sch`
  - `xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc~.sch`

  All 12 are newer than the start mark and all are deleted. `git status` in `~/gdf0` shows
  only the 9 patch files. The gate clone will likely collect the same files; CLAUDE.md
  records that `untitled~.sch` reddens the `test_rdw_*` hygiene rows. (The `fullout.sh`
  runs used a temporary cwd.)
- **Displays outside 270–279 were started, transiently, by one suite.** I ran
  `test_home_isolation` through `run_suites.sh` with `AUDIT_DISPLAY=:271`, as a
  meta-suite check. Its H band drives a copy of T1's display arm, which numbers private
  Xvfbs from `:100`, and it starts fixture displays of its own (its comments name `:150`).
  So that suite started and stopped servers outside my range. They were not my choice of
  display, and the suite reaps them (its rows passed). At the end, the only Xvfb servers
  running anywhere were my `:270`–`:275`. The verifier's `286`–`295` were not touched,
  but another agent's T1 private arm in the `:1xx` range could have been.
- **`test_cadence_descend_newwin_ro` uses the fixed path `/tmp/cadence_gate_brace_work`.**
  Two concurrent runs collide: B and F run in parallel gave different output and a hang;
  run serially they are identical.
- **`test_key_graph_context`'s zoom depends on the install path length** (§7).
- Synthesised `event generate` presses without `-time` all carry the same time, so presses
  a few pixels apart bind as `<Double-Button-1>`. My GUI drivers pass an increasing
  `-time`.

## 11. Reproduction

Scratch (tmpfs, may be gone):
`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dragperf/`.

Scripts are in `scr/`:

| what | scripts |
|---|---|
| run helpers | `hrun.sh` |
| identity sweeps | `ident_seam.tcl`, `identpass.sh`, `ident_gui.tcl`, `identgui.sh`, `cmpdir.sh` |
| timing | `drag.tcl`, `dragpass.sh`, `abab.sh`, `agg.py` |
| scaling grid | `gridseam.tcl`, `gridpass.sh` |
| suites | `rs.sh`, `fullout.sh`, `nz.sh` |
| health | `warn.sh`, `vg.sh` |
| staleness probes and sabotages | `tabs.tcl`, `nested.tcl`, `mksab.py` |

Outputs are in `out/`, `fo/`, `fo2/`, `log/`, `vg/`, `wb/` and `cg/`. All runs used private
Xvfb displays `:270`–`:275` or `env -u DISPLAY`, with a throwaway HOME and `GUI_GATE=0`
plus an explicit `AUDIT_DISPLAY`.
