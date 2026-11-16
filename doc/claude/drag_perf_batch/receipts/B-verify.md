# B-verify: adversarial verification of stage A (the cached `::cadsnap` read)

Verifier receipt for `receipts/A-fix.patch` (md5 `a36e6556d0585785dcdb6e3f09a8b6f6`, against
`bd14668b9`). Applied to `3b36f24a1` in `~/gdv0`, with base `3b36f24a1` in `~/gdb0`. The commits
between them touch docs only. Both clones were built fresh by the verifier. Nothing in
`~/dev/xschem-claude` was touched except this file.

## Verdict: SAFE WITH LIMITS

- On every in-tree path the patch gives the same results as base, and it is 3.3x to 7.5x faster
  per drag frame on three pages the crew did not use.
- Three corner cases differ from base. Each needs a user-installed Tcl trace on `::cadsnap`,
  or a deliberate `unset ::cadsnap`, and nothing in the tree does either. The crew's
  "can't go stale" claim is therefore not true as written. A two-line change, built and
  measured below, closes all three and costs nothing.
- The fence's comment claims more coverage than it has.

No finding blocks stage C. F1 is worth folding in before the commit because it is cheap and
fully measured.

## 1. Claims re-measured

| crew claim | verifier result |
|---|---|
| 28 call sites converted | **Confirmed.** Base has 30 `tclgetdoublevar("cadsnap")` lines; 2 are comments (`callback.c` near the group transform and the rotate snap). Every code site moved. In the fix the only direct reads left are the two fallbacks inside `tclgetcadsnap()`. The only C writer is `set_snap()` → `tclsetcadsnap()`. `xinit.c`'s startup `set_ne cadsnap` runs before any read. |
| Byte-identical saved pages and netlists | **Confirmed** on 12 new pages and 4 libraries, with the snap changed during drags and mid-command (§3). |
| 2–6x faster per frame | **Confirmed and slightly exceeded** on 3 new pages: 3.3x–7.5x (§4). |
| Cache can't go stale; every change path covered | **Refuted for three trace or unset shapes** (F1–F3). Every in-tree path is covered. |
| Receipt §3 row "a write inside another write trace on cadsnap … covered by 2 + 3" | **Refuted** when the outer writer is Tcl running inside a C command (F1). |
| Fence red on base for the right reason, green on fix | **Confirmed.** Base fails R1/R2/R3 with exactly the crew's per-step read counts. Fix passes 37/37. |
| Fence catches a per-iteration read coming back "for cadsnap or any other variable" | **Partly refuted** (F4). It catches one only at sites the live `step` commands reach. |
| T1 delta cases +1, blocks +1, counted +0, skips +0, `wc -l` +3 | **Confirmed** by deriving it from `summarize_all` (§5). |
| Suite outputs identical to base | **Confirmed** on 66 wiring/fluid/drag suites × 2 arms, plus the 58 wireedit tests (§6). |

## 2. Findings

### F1 (LOW): a nested write trace leaves the cache stale for the rest of one C command

**Shape.** Three things must line up:
- A user write trace on `::cadsnap` is **older** than the cache's own trace.
- Its body calls any `xschem` command, which refills the cache, and then writes `::cadsnap`
  again. That second write fires no trace, because Tcl disables traces while one runs.
- The outer write is a Tcl write made **inside** a C command, for example from a read trace
  on a variable the drag pipeline reads.

**Result.** The rest of that C command uses the old snap. The next `xschem` entry recovers.

**Measured** (two probes, base vs fix):
- `xschem align`: base computes the dot size from snap 14 (`5.18`). Fix uses the stale 16
  (`5.92`).
- One-shot stretch drag `xschem move_objects 40 0 stretch kissing`: base follows the wire to
  x=40 (snap 20). The fix leaves it at x=0 (snap 10), so the geometry is wrong.

**Repro** (headless, fix binary):
```tcl
proc s4_page {} { xschem clear force
  set ::enable_stretch 1; set ::orthogonal_wiring 1; set ::cadence_compat 1
  set ::autotrim_wires 1; set ::fluid_editing 1; set ::unselect_partial_sel_wires 0
  xschem instance devices/res 0 0 0 0 {name=RA m=1 value=1k}
  xschem wire 0 37 0 100 ; xschem wire 0 100 60 100 }
proc user {args} { catch {xschem redraw} ; set ::cadsnap 20 }
set ::N 0
proc mid {args} { incr ::N ; if {$::N == 1} { trace remove variable ::fluid_editing read mid ; set ::cadsnap 10 } }
xschem set cadsnap 10 ; s4_page ; xschem select instance 0
unset ::cadsnap ; set ::cadsnap 10        ;# so the user trace is OLDER than the cache's
trace add variable ::cadsnap write user
xschem redraw                             ;# re-arms the cache's trace (newest)
trace add variable ::fluid_editing read mid
xschem move_objects 40 0 stretch kissing
# base: wires {40 100 60 100} {40 37 40 100}   fix: {0 100 60 100} {0 37 0 100}
```

**Reach.** Nothing in the tree traces `::cadsnap`. This takes a plugin or a user's rc file.

**Fix.** Drop the cache on `xschem()` exit as well as on entry: one line,
`cadsnap_cache_ok = 0;` after `} /* switch */`. Every return in `xschem()` comes after that
point except the `argc < 2` return, which reads nothing. Measured below.

### F2 (LOW): a read trace that unsets and recreates `::cadsnap` leaves it cached but untraced

**Shape.** A read trace on `::cadsnap` unsets and recreates it inside the `Tcl_GetVar` call in
`tclgetcadsnap()`. The unset destroys the cache's trace (`cadsnap_traced = 0`), but the code
then sets `cadsnap_cache_ok = 1`. A later Tcl write in the same command fires nothing.

**Measured.** In the `xschem align` shape, base computes the dot size from 16 (`5.92`). Fix
uses the stale 12 (`4.44`).

**Fix.** Read first, then arm the trace (F3 shows the code).

### F3 (LOW, a behaviour change, not staleness): `upvar` onto an unset `::cadsnap` now fails

**Shape.** After `unset ::cadsnap`, any C read installs a trace on the missing variable, which
creates an undefined-but-traced variable. After that, `upvar #0 x cadsnap` fails with
`variable "::cadsnap" has traces: can't use for upvar` in the fix. It succeeds in base.

**Reach.** No in-tree code unsets `::cadsnap`. `restore_ctx` uses `set` for every name in
`tctx::global_list`.

**Fix.** Do not arm a trace when the variable is missing. This is the same reorder as F2:
```c
double tclgetcadsnap(void)
{
  const char *p;
  if(cadsnap_cache_ok) return cadsnap_cache;
  p = Tcl_GetVar(interp, "cadsnap", TCL_GLOBAL_ONLY);       /* read FIRST */
  if(!p) return tclgetdoublevar("cadsnap");                 /* never trace a missing var (F3) */
  if(!cadsnap_traced) {                                     /* after the read: re-arms (F2) */
    if(Tcl_TraceVar2(interp, "cadsnap", NULL, TCL_GLOBAL_ONLY | TCL_TRACE_WRITES | TCL_TRACE_UNSETS,
                     cadsnap_trace, NULL) != TCL_OK) return tclgetdoublevar("cadsnap");
    cadsnap_traced = 1;
  }
  cadsnap_cache = atof_spice(p);
  cadsnap_cache_ok = 1;
  return cadsnap_cache;
}
```
No Tcl code runs between the read and `atof_spice`, so `p` stays valid.

**Variant measured with F1 + F2 + F3 together:**
- All 82 probe lines are identical to base, including F1, F1's drag form, F2 and F3.
- Fence: `ALL PASS (37 checks)`. R1 still holds, so the exit drop adds no read per step.
- Timing on switch_level_sim, 3 rounds each, n=108: the variant runs at 8.6 / 12.9 / 16.9 ms
  against the fix's 8.4 / 13.3 / 17.4 ms at K=1/3/8. Drag outcomes are identical.

An F1-only variant (exit drop plus `cadsnap_cache_ok = cadsnap_traced`) also closes F1 and F2
and passes 37/37, but it still differs from base on F3.

### F4 (LOW): the fence's R3 comment claims more than it covers

The header says R3 is *"the shape that would catch a per-iteration lookup coming back, for
cadsnap or any other variable"*. It counts reads only inside the live `move_objects step`
commands of its fixture.

**Per-site reachability** (instrumented build, fence run):
- **Hit:** `point_near_pin`, `fluid_pin_on_seg`, `fluid_seg_pair_touch` (and `_except`),
  `fluid_jog_is_moved_pin_escape_overshoot`, `insert_exit_stubs`, the reroute, offset and
  three shove sites, `select.c`, `linewidth_ref_snap`, `set_snap`.
- **Never reached:** the `fluid_straighten_reversals` inner site, `fluid_jog_pin_off_backbone`,
  `fluid_manh_route`, the `move_objects` covered-check, `check.c`, `snap_to_grid`, and the
  callback rotate/flip/entry sites.

**Sabotages.** Each one reverts a single site to a per-call `tclgetdoublevar("cadsnap")`:

| reverted site | rows red |
|---|---|
| `point_near_pin` | R1 R2 R3 |
| `fluid_seg_pair_touch` | R1 R2 |
| `_except` | R1 R2 |
| `insert_exit_stubs` | R1 R2 |
| a new per-call `tclgetboolvar("fluid_editing")` in `point_near_pin` | R3 |
| `fluid_jog_is_moved_pin_escape_overshoot` (per wire, in the straighten loop at END) | **none (green)** |
| the straighten inner site, `fluid_jog_pin_off_backbone`, `fluid_manh_route` | **none (green)** |
| the same new boolean read placed in `fluid_manh_route` | **none (green)** |
| the trace body not dropping the cache (`notrace`) | S1 S3 |
| no drop at entry (`noentry`) | R4 S2 |

**Why it matters only a little.** The unfenced sites are cold on real pages. Call counts over
96 drags each:

| page | `point_near_pin` | `fluid_pin_on_seg` | overshoot | `fluid_jog_pin_off_backbone` | `fluid_manh_route` |
|---|---|---|---|---|---|
| LACG | 82.4M | 56.7M | 42k | 19 | 1 |
| autozero_comp | 134M | 76.6M | 33k | 180 | 18 |
| switch_level_sim | 146M | 85M | 32.7k | 105 | 17 |

So every hot site is fenced. The overshoot site is the warmest unfenced one, at about
0.05% of the hottest.

**Fix.** Either narrow the comment to "at sites the fixture's live `step` commands reach", or
also count reads in the `end` command and add a fixture that triggers the straighten, jog and
Manhattan passes.

## 3. Identity

All comparisons are byte-for-byte, base vs fix. Netlists are compared after mapping out only
the `wd/B` vs `wd/F` path in `** sch_path:`.

**Pages.** 12, none of them the crew's:
- sky130A: LACG, test_ff, charge_pump2, bandgap_opamp. These load with their own
  `cadence_style_rc`.
- xschem_library: autozero_comp, mos_power_ampli, switch_level_sim, rulz-r8c33. These load
  with the default library path; rulz has 3 symbols missing on both trees.
- ihp-sg13g2: ac_svaricap_test, dc_mos_temp.
- gf180mcuD: test_cap_mim_analog, test_cap_nmos_06v0.

**Seam sweep** (`move_objects start … kissing stretch / step / end`):
- **Design.** 8 rounds at snaps 10, 5, 7, 2.5, 13, 20, 10 and 0.5. Each round's snap was set a
  different way: `xschem set`, plain `set`, `upvar`, `uplevel #0`, `snap double`, `snap half`.
  Up to 12 devices per page, every third drag with 2 instances selected. Drags accumulate.
- **Mid-drag changes, at step 4.** A plain `set ::cadsnap`, an `xschem set cadsnap`, or a read
  trace on `::fluid_editing` that writes `::cadsnap` at its 5th read, in the middle of one
  `step`.
- **Saved.** Every drag, the full undo chain, two redos, and a netlist per round.
- **Result:** **4265/4265 files identical** on a display arm (base `:286`, fix `:287`), and
  **4265/4265** headless. That is 1000 drags, 954 of which changed the page, and 72 or more
  mid-drag snap changes per page. Logs identical. All mid-step writes fired.

**Event-driven sweep** (Tk events on `.drw` → `xschem callback`):
- **Design.** Snaps 10, 7 and 2.5, up to 8 devices per page. The press point was retried
  until a move armed (`ui_state & 32`).
- **Mid-drag changes, between motions 4 and 5.** None, `xschem set cadsnap`, **Alt+Up**
  (view snap double), an `after 0` timer, or `uplevel #0 set`. Then a netlist, undo ×3 and a
  redo.
- **Phase B.** A second toplevel window on a copy of the page, with its own snap (20 / 5).
  Drags alternate between the two windows, switched only by `<Enter>`/`<Motion>` events.
- **Volume.** 390 drags; 382 armed a move and 8 found no press point, identically on both
  trees.
- **Phase A result:** identical on all 12 pages.
- **Phase B, first run:** 4 pages differed. That was a harness artifact. The title-block
  symbol prints the file path, and the paths differed by one letter (`/B/` vs `/F/`). That
  moves the text bbox, then `zoom_full`, then the pixel-to-schematic mapping of the scripted
  presses.
- **Phase B rerun:** 5 pages run sequentially from one identical path gave **356/356
  identical**, with identical zoom logs.

**Fresh reads where the code needs them.** The two reads that follow a write (`set_snap` →
`set_dotsize_from_snap`, and `view_snap_change`'s "new" value) both come after
`tclsetcadsnap()`, which drops the cache.

**Odd values.** These spellings behave the same in base and fix, through plain `set` and
`xschem set`, including the "can't read" stderr counts: `0 -10 abc {} 1k 2.5 7 0.1 1e-3
" 12 " 12abc 0x10 15.0 1.5e1 13 14 14.000001 13.999999 NaN inf`.

**18 other write paths, also identical:** `incr`, `append`, `lappend`, `upvar`, `global`,
`interp alias`, `namespace eval variable`, a namespaced proc, `foreach`, `scan`, `regexp`,
`unset`+`set`, `after 0`, `after idle`, `eval`, `uplevel`, `subst`, and the array error.

## 4. Timing (ABAB, interleaved)

**Setup.**
- One private Xvfb, `:295`, 1920x1080x24 with openbox; main window 1200x900.
- 4 rounds in the order B F / F B / B F / F B.
- Pages: LACG (71 inst / 162 wires), autozero_comp (133 / 165), switch_level_sim (107 / 227).
- K = 1, 3 and 8 selected devices; 3 drags per K; 12 timed motions per drag, each crossing a
  snap step. Each drag is undone so every drag starts from the loaded page.
- Every drag armed a move, and the selection size equalled K. Drag outcomes were identical in
  all 12 B/F pairs.

**Metric.** Wall time from `event generate <Motion> -when now` through `update`. It includes
drawing, but not an explicit X round trip. n = 144 frames per cell per tree.

**Machine.** 20 cores. 1-minute load at round starts was 0.28, 0.59, 1.10 and 1.78. Other
agents' xschem processes alive at round starts: 0, 0, 2, 4.

Median ms, with the min..max of the 4 per-round medians in brackets:

| page | K | base | fix | speedup |
|---|---|---|---|---|
| LACG | 1 | 29.1 (27.3..30.4) | 6.6 (5.9..6.6) | 4.4x |
| LACG | 3 | 38.9 (36.9..42.0) | 8.0 (7.3..8.4) | 4.9x |
| LACG | 8 | 65.2 (59.1..69.3) | 10.1 (8.9..11.1) | 6.4x |
| autozero_comp | 1 | 27.4 (25.8..29.2) | 8.2 (7.4..9.7) | 3.3x |
| autozero_comp | 3 | 45.2 (42.5..50.2) | 10.6 (9.6..12.7) | 4.3x |
| autozero_comp | 8 | 84.0 (74.8..88.7) | 14.4 (13.0..16.0) | 5.8x |
| switch_level_sim | 1 | 43.6 (38.8..46.3) | 9.5 (7.5..10.7) | 4.6x |
| switch_level_sim | 3 | 80.6 (72.9..83.7) | 12.2 (11.9..13.1) | 6.6x |
| switch_level_sim | 8 | 121.3 (112.8..134.1) | 16.2 (15.4..17.3) | 7.5x |

- No base and fix round-median ranges overlap in any cell.
- Base drifted up a little in the loaded rounds 3–4; the fix stayed flat.
- With the fix, every cell fits a 60 Hz refresh (16.7 ms).

## 5. The fence (`tests/headless/test_drag_tclvar_reads.tcl`)

**Red on base for the right reason.** Through `run_suites.sh --nogui` and on the display arm,
base fails exactly R1, R2 and R3 (`3 FAILED (34 passed)`). Its per-step cadsnap reads are
`867 867 1822 1820 1820 1731` (N=4) and `28299 28299 57046 57044 57044 56595` (N=40), the
crew's figures exactly. The fix gives `ALL PASS (37 checks)` on both arms.

**Not vacuous.**
- R4–R7 hold on the fix.
- Every live-step sabotage turned R rows red, and the trace and entry sabotages turned S rows
  red (§2, F4).
- The blind spots are END-only and untriggered passes (F4).

**Registration.**
- The suite is in `hcases` only, after `headless/test_wave_subwindows`, with a `##` comment.
- `hcases` goes 136 → 137; `dcases` (60) and `tcases` (3) are unchanged, so
  `planned_cases` = 3 + 137 + 60 + 1 = 201.
- Display-only rows: none, so `hcases` alone is the right list.

**banner_rule.tcl.**
- Capture taken T1-style from `tests/`: `env -u DISPLAY ../src/xschem --nogui --pipe -q
  --script headless/test_drag_tclvar_reads.tcl`, rc 0.
- `banner_complete` = 1, `banner_died` = 0, `regression_case_failed` = 0.

**T1 delta, derived rather than predicted.**
- Method: every proc `summarize_all` needs (16) was lifted out of `run_regression.tcl`'s own
  text with no lift errors. `banner_complete` was sourced from `banner_rule.tcl`. The lifted
  `summarize_all` was then run on the capture.
- The block is 3 lines: a label, `RESULT: ALL PASS (37 checks)` and `Total num fail: 0`. It
  holds 0 `^skip:` lines, 1 `^RESULT:` line and no uppercase SKIP.
- **Delta: cases +1, blocks +1, counted +0, skips +0, `wc -l` +3.** This matches the crew.

**Meta-suites on the fix clone** (`run_suites.sh --nogui`): `test_suite_watchdog_1403` 40,
`test_registered_banner_1626` 10, `test_issue_stamp` 102 and `test_scratch_home_note` 22,
all PASS. `test_home_isolation` was not run: its H band spawns Xvfbs outside this verifier's
display range.

## 6. Health

**Warnings.** Compile-only over all 39 `OBJ` files, base vs fix:

| configuration | base | fix | diff |
|---|---|---|---|
| cairo | 6 | 6 | empty |
| no cairo | 6 | 6 | empty |
| `-std=c89 -pedantic` | 67 | 67 | empty |
| `-std=c89 -pedantic -Wall -Wextra` | 438 | 438 | empty |

**valgrind memcheck.** Runs: the staleness probe headless, and the event-driven drag sweep
with a second window on bandgap_opamp (fix `:291`, base `:290`).
- 0 invalid reads, writes or frees, 0 uninitialised-value errors, and no frame in any cadsnap
  code.
- GUI: definitely lost 3,208 B / 3 blocks and indirectly lost 2,571 B / 12 blocks, identical
  on both trees.
- Probe: definitely lost 3,607 B on base vs 3,604 B on the fix. The 3 bytes are the content
  length of an existing `xschem_cmds_w` `my_mstrcat` record.
- The remaining error-context counts (GUI 299 vs 302) come from "possibly lost" totals, which
  vary run to run.

**Modes.**
- `--nogui --pipe` with commands on stdin (no `-q`): identical output except path lines.
- `--script`: used throughout.

**Suites.** `tests/headless/run_suites.sh` over 66 wiring, fluid, drag, move, snap, rotate,
align and stretch suites, in each clone, with `env -u DISPLAY GUI_GATE=0` and an explicit
`AUDIT_DISPLAY` (fix `:293`, base `:294`):

| arm | base | fix | how they differ |
|---|---|---|---|
| display | 58/64 runs passed, 2 skipped | 59/64 runs passed, 2 skipped | only `test_drag_tclvar_reads` |
| `--nogui` | 24/30 runs passed, 36 self-skipped | 25/30 runs passed, 36 self-skipped | only `test_drag_tclvar_reads` |

The display arm has 5 failing suites, with **identical failure text on base**:
`test_ase_log_seam_0207`, `test_cadence_drag`, `test_rdw_seam_1245`,
`test_rotate_stretch_short_0104` and `test_snap_bindkeys`. None of them is in
`run_regression.tcl`. They are not caused by this patch and were not diagnosed further.

`tests/headless/wireedit/run_wireedit.sh` gives `WIREEDIT: ALL PASS` (58 tests) on both trees,
with identical output.

## 7. Not covered

- A full T1 run. That is stage C's gate, in a short-path clone.
- `test_home_isolation`, which was not run (see §5).
- Tabbed-interface tab switches (`::tabbed_interface 1`) were not driven by real events here.
  Separate toplevel windows were, with byte-identical results. The crew's `tabs.tcl` probe
  covers tabs through `restore_ctx`. That `restore_ctx` uses `set` was confirmed by reading it.
- The snap dialog and the statusbar entry were not driven as widgets. Their code paths were
  driven as the Tcl they run (`xschem set cadsnap`, and plain `set` followed by `xschem set`).
- `:0`, `$DISPLAY` and the user's real screen were never used, by rule. There was no eyeball
  look, because there is no visible change to look at.
- Timing has no X round trip in the metric. The crew's metric had one.
- Windows builds.

## 8. Method notes

**Isolation.**
- Displays: private Xvfb + openbox on `:286`–`:295` only, each checked free before start.
  Every headless run used `env -u DISPLAY`.
- Homes: a throwaway `HOME` per run.
- Designs: copied to scratch, with cwd there.
- `*~.sch` files newer than the start mark were removed from `~/gdv0` and `~/gdb0` after the
  `run_suites.sh` passes.

**Scripts.** All in the verifier's scratch, `dragverify/scr/`, which is trimmed at the end.
This file inlines what is needed to reproduce F1–F3:
- `probe.tcl`: staleness probes P0–P8.
- `ident.tcl`: seam sweep.
- `ident_gui.tcl`: event sweep.
- `time_gui.tcl` and `abab.sh`: timing.
- `mksab.py` and `sab.sh`: sabotages.
- `derive.tcl`: the T1 delta.
