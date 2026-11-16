# Stage A2 receipt: closing the verifier's F1–F4 on the cached `::cadsnap` read

Fix crew A2, 2026-11-15. Base `3b36f24a1`. Stage A (`A-fix.patch`, md5
`a36e6556d0585785dcdb6e3f09a8b6f6`) applied in the clone `~/gdf2` as a local scratch commit
`0c8523a2c`; this change is uncommitted on top of it.

| file (next to this one) | what | md5 |
|---|---|---|
| `A2-incremental.patch` | `git -C ~/gdf2 diff`: this change only, against the stage-A tree. 2 files, +193 −24 | `86e7fcd8eae49d33c7958783711a6ac2` |
| `A2-combined.patch` | `git -C ~/gdf2 diff 3b36f24a1`: stage A + this change against base. 9 files, +683 −32 | `ed6e5da01a5ce8e7ee26a49303eee230` |

Both were checked on a clean `git archive 3b36f24a1` export: the combined patch alone, and
`A-fix.patch` followed by the incremental one, each reproduce the `~/gdf2` working tree byte for
byte.

## In plain English

- **What was wrong.** The verifier (`B-verify.md`) found three corner cases where stage A's cache
  answered differently from base, plus one comment in the fence that claimed too much. Each case
  needs a user-made Tcl trace on `::cadsnap`, or an `unset ::cadsnap`. Nothing in the tree does
  either, so no user of the shipped tool could hit them.
- **What changed.** Three small things in `src/scheduler.c`:
  - the cache is now also dropped when an `xschem` command **returns** (F1);
  - `tclgetcadsnap()` now **reads the variable first** and only then puts its trace on it (F2);
  - it puts **no trace on a variable that is missing** (F3).
  The fence comment now says what it really measures (F4).
- **The fence.** Three new rows, one per finding, are red on the stage-A build and green after.
  A fourth row was needed because the F1 fix made an existing row unable to see one of the
  other drops (§3). The fence is now **41 checks**.
- **Cost.** None measured. On two real pages, drags with 1 and 8 devices run at the same speed as
  stage A, within 2% either way, in 8 interleaved rounds. Real mouse motions read the snap
  twice per frame on both builds.

## 1. The change (by symbol)

**`xschem()`** (`src/scheduler.c`): `cadsnap_cache_ok = 0;` right after `} /* switch */`.
Every case in the switch only sets `retcode` and breaks. So every return after the switch passes
this line: the `retcode != TCL_OK` return, the invalid-command return and `TCL_OK`. The one
earlier return is the `argc < 2` "Missing arguments" one. It reads nothing, and the drop at entry
has already emptied the cache.

**`tclgetcadsnap()`**: the new order is:
1. Read with `Tcl_GetVar`.
2. If the variable is missing, return `tclgetdoublevar("cadsnap")`, the uncached path, with the
   same message, result and 0.0 as before. No trace is armed.
3. Parse with `atof_spice()`, before any other Tcl call.
4. If the trace is not armed, arm it.
5. Cache.

The trace-failure branch (unreachable for a global scalar, as before) now returns the value it
has already parsed. It is still not cached. It reads once instead of twice.

**The comment above `tclgetcadsnap()`** now:
- lists **four** drops: the trace, entry, `tclsetcadsnap()` and exit;
- says that the entry drop now matters only for an `xschem` command run from inside another C
  command (row S2b);
- states the read-then-arm order and why each half exists (rows S8 and S9);
- names the two shapes still not covered (§9).

It cites rows and symbols, not line numbers.

**The fence** (`tests/headless/test_drag_tclvar_reads.tcl`):
- new rows **S7**, **S8**, **S9** and **S2b**;
- the R3 header now says the rows count only reads made inside the fixture's live
  `move_objects step` commands, and it names the sites they do not reach:
  - the END-only passes: `fluid_straighten_reversals` and the per-wire
    `fluid_jog_is_moved_pin_escape_overshoot()` it calls, `fluid_jog_pin_off_backbone()` under
    `fluid_ripup_foreign_pin_short`, and `fluid_manh_route()` under
    `fluid_manhattanize_relay_diagonals`;
  - the sites this fixture's steps never reach: the `move_objects` covered-wire check, check.c,
    `snap_to_grid()`, and the callback.c rotate/flip and snap-change sites.

  I checked the END-only gating by reading the pass table: `FLUID_PASS_CLUSTER`, and the
  `!commit_now` gate on the Manhattanize call;
- S2's comment no longer says that only the entry drop makes it fresh;
- S8 declares that it is blind on the display arm (§5).

C89 throughout. `double v;` is declared at the top of its block.

## 2. Red first, then green (headless, `run_suites.sh --nogui`)

Builds:
- **A** is stage A (`src/xschemA0`, md5 `2f29ec03…`).
- **A2** is this change (`src/xschemA2`, md5 `5404c6d4…`).
- **base** is `3b36f24a1` (`src/xschemB0`, md5 `079ef3c1…`).

All three ran in `~/gdf2/src` with the same fence file, so paths and the share directory are
identical.

| row | finding | stage A | A2 | base |
|---|---|---|---|---|
| S7 | F1 | **red**. Wires `{0 100 60 100} {0 37 0 100}`: the snap-10 result, although `::cadsnap` holds 20. Both traces fired once. | green: `{40 100 60 100} {40 37 40 100}` = S4's snap-20 reference | green |
| S8 | F2 | **red**. Dot size 4.44 (snap 12's) while the variable holds 16. The read trace fired once. | green: dot 5.92 (16's) | green |
| S9 | F3 | **red**. `upvar` rc 1: `variable "cadsnap" has traces: can't use for upvar`. The next drag gives the snap-10 result, because the variable stayed unset. | green: rc 0, and the drag is S4's snap-20 reference | green |
| S2b | (§3) | green | green | green |

Whole fence:

| build | result |
|---|---|
| stage A | `3 FAILED (38 passed)`: S7 S8 S9 |
| A2 | `ALL PASS (41 checks)`, with `OVERALL: ok (41 checks)` printed before the `RESULT:` line |
| base | `3 FAILED (38 passed)`: R1 R2 R3, exactly as before. The per-step reads `867 867 1822 1820 1820 1731` and `28299 28299 57046 57044 57044 56595` are unchanged. All S rows pass on base. |

**The 37 stage-A rows are unchanged, byte for byte.** Two runs were compared:
- the old 37-row fence file on the stage-A build;
- the new fence on A2, with the four new rows filtered out.

Their `ok:` lines diff empty, including every count in a row name. R1 and R2 read `1 1 1 1 1 1`
on both pages. R3 totals `{82 82 148 148 148 148}` on both pages. R4's `fluid_editing` counts
are `{18 18 26 26 26 26 …}`. R6 is `{234 234 232 …}` / `{2106 2106 2104 …}`. So the exit drop
adds no Tcl read to a drag step.

## 3. Why there is a fourth new row (S2b)

The first copy broken on purpose that I built was stage A's own `noentry`: no drop on entry, on
the A2 code. **The 40-check fence was all green.** The new exit drop empties the cache between
any two top-level commands. So S2 and R4, which stage A used to show the entry drop was needed,
can no longer tell whether it is there. Stage A's red rows for `noentry` were R4 and S2; on the
A2 code there were none.

The entry drop is still needed. It covers an `xschem` command run from Tcl in the **middle** of
another C command that has already filled the cache: a newer write trace runs before the cache's
own trace, and its body's nested `xschem redraw` would read the stale value.

**S2b** drives exactly that. A Tcl write is made in the middle of `xschem align` (S1's read
trace on `::autotrim_wires`), after align's first snap read. A newer write trace's body redraws
and records the dot size.

S2b's results:
- green on stage A, A2 and base;
- **red only on the copy with no entry drop** (§4).

It is not a red-first row for a finding. It fences a drop that my change would otherwise have
left unfenced.

## 4. Copies broken on purpose

Each copy is the final A2 `scheduler.c` with one change, built and run with the same fence file.
The diffs are `scr/K*.diff` in scratch.

| copy | what was removed | headless red rows | display-arm red rows |
|---|---|---|---|
| K1 | the exit drop (F1 fix) | **S7** | **S7** |
| K2 | arm-after-read: the arming decision is taken before the read (F2 fix) | **S8** | none (§5) |
| K3 | no-trace-on-missing: the trace is armed before the missing-variable return (F3 fix) | **S9** | **S9** |
| K4 | the entry drop (stage A's `noentry`) | **S2b** | **S2b** |
| K5 | the trace body's drop (stage A's `notrace`) | S1 S3 S8 | S3 |
| K6 | `tclsetcadsnap()`'s drop (stage A's `noset`) | S6 | S6 |
| K7 | re-arming after a destroyed trace (stage A's `noreinstall`) | S3 S8 | S3 |

So each of the four drops, and each half of the read-then-arm order, turns at least one row red
on the counted (headless) arm when only it is removed. That is the claim the fence header
makes.

## 5. The display arm: S8 and S1 are blind there

On the display arm, `xschem align` reads `::cadsnap` twice from C, against once headless. With a
window, align's draw runs nested `xschem get schname` and `xschem get current_win_path` commands.
They run between the mid-command write (the `::autotrim_wires` read) and the dot-size read, and
their entry and exit drops make that later read fresh on **any** build. I measured this with an
execution trace on `xschem`.

So, on the display arm:
- stage A's fence fails only S7 and S9 (`2 FAILED (39 passed)`);
- K2 passes everything;
- under K5, S1 passes as well as S8, and only S3 stays red.

S1's blindness is a property of the stage-A row. Stage A measured its broken copies through
`--nogui` only.

The suite is in `hcases` alone, so T1 runs it on the arm where both rows are red. S8's comment
now says so. I tried a drag form of S8 that would see F2 on both arms. It does not work: the
mid-drag write lands after the geometry-deciding reads, so base gives the snap-10 result too.
I dropped it.

## 6. Health

**Compiler warnings.** I compiled all 39 `OBJ` files compile-only with the build's own `CFLAGS`
(cairo, from `Makefile.conf`), stage A against A2. Line numbers were stripped before the diff.

| configuration | stage A | A2 | diff |
|---|---|---|---|
| cairo (the build) | 6 | 6 | empty |
| `-std=c89 -pedantic` | 67 | 67 | empty |
| scheduler.c alone, `-std=c89 -pedantic -Wall -Wextra -Wdeclaration-after-statement` | 18 | 18 | empty |

**valgrind memcheck** (`--leak-check=full`, headless, `env` before `valgrind`):

| fence file | stage A | A2 |
|---|---|---|
| the old 37-row file (both builds take the same path) | definitely lost 32,171 B / 1,910 blocks; indirectly lost 161 B / 6 blocks; 123 error contexts | **the same** |
| the new 41-row file | definitely lost 32,219 B / 1,914 blocks; 125 contexts | definitely lost 32,225 B / 1,914 blocks; 125 contexts |

- Both builds: 0 invalid reads, writes or frees, 0 uninitialised-value errors, and no frame in
  any cadsnap code.
- The 6-byte difference on the new file is inside one record, with the same block count. The
  record is `xschem()` → `my_mstrcat` (an existing per-command result-string loss, the one the
  verifier traced to content length). Stage A fails three rows there and formats different
  values.

**T1 shape.** The capture was taken from `tests/` as T1's `hcases` loop takes it: `env -u
DISPLAY ../src/xschem --nogui --pipe -q --script headless/test_drag_tclvar_reads.tcl`, rc 0.
- `banner_complete=1`, `banner_died=0`, `regression_case_failed=0`, with `tests/banner_rule.tcl`
  sourced.
- 0 lowercase `^skip:` lines, 1 `^RESULT:` line, 0 uppercase `SKIP`.

## 7. Timing (ABAB, interleaved, real Tk events)

**Setup.**
- One private Xvfb, `:286`, 1920x1080x24 with openbox; main window 1200x900.
- The verifier's `time_gui.tcl`, cut to K ∈ {1, 8}: 3 drags per K, 12 timed motions per drag,
  every motion crossing a snap step, each drag undone.
- Metric: wall time from `event generate <Motion> -when now` through `update`.
- Pages:
  - `xschem_library/ngspice/autozero_comp.sch` (133 instances, 165 wires), loaded with
    `src/cadence_style_rc`'s editing settings and the default library path;
  - sky130A `LACG` (71 / 162), with `sky130A/cadence_style_rc`.
- 8 rounds, in the order A A2 / A2 A / … The 1-minute load at round starts was 0.32–0.61. One
  other agent's xschem was alive.
- Every drag armed a move. The `META` and `END` lines (selection size, modified flag, wire count
  after each drag) are **identical** between A and A2 in all 16 page×round pairs.

Median ms per frame, with the min..max of the 8 per-round medians in brackets. n = 288 frames per
cell per build.

| page | K | stage A | A2 | A2 / A |
|---|---|---|---|---|
| autozero_comp | 1 | 7.50 (7.26..7.62) | 7.45 (7.30..7.71) | 0.994 |
| autozero_comp | 8 | 13.08 (12.87..13.35) | 12.96 (12.64..13.11) | 0.991 |
| LACG | 1 | 6.14 (5.83..8.30) | 6.06 (5.77..6.35) | 0.986 |
| LACG | 8 | 9.33 (8.95..10.17) | 9.14 (8.89..9.40) | 0.980 |

- The round-median ranges overlap in every cell. The fix costs nothing measurable.
- Why: a Tcl read trace on `::cadsnap` during the same real drags counts **2 reads per motion
  event on both builds**, at K=1 and K=8, on both pages (36 motions per cell). The exit drop adds
  no read to a real frame.

## 8. Suites on both arms, stage A against A2

The selection is the fence plus every `tests/headless/test_*fluid*`, `test_*drag*`,
`test_*stretch*` and `test_*snap*` file: 40 suites. Each ran through `run_suites.sh` with
`GUI_GATE=0` and `XSCHEM=` set to the build, sequentially in `~/gdf2`.
- Headless: `--nogui`, `env -u DISPLAY`, `AUDIT_DISPLAY=none`.
- Display: `AUDIT_DISPLAY=:286` with openbox.

| arm | stage A | A2 | how they differ |
|---|---|---|---|
| headless | 8 PASS, 1 FAIL, 1 NORESULT, 30 self-skipped | 9 PASS, 1 NORESULT, 30 self-skipped | only `test_drag_tclvar_reads` (stage A red S7 S8 S9, as designed) |
| display | 36 PASS, 4 FAIL | 37 PASS, 3 FAIL | only `test_drag_tclvar_reads` (stage A red S7 S9, see §5) |

The other failures are pre-existing, have identical failure text on both builds, and were also
listed in `A-fix.md` §7 and `B-verify.md` §6:
- `test_cadence_drag`: NORESULT headless, 2 FAIL on the display arm.
- `test_rotate_stretch_short_0104`: 1 FAIL.
- `test_snap_bindkeys`: fails only because `run_suites.sh` passes `--nolog`. Its rows assert the
  action log. Re-run with `--logdir`, it is `ALL PASS` on **both** builds. That matters here,
  because it drives `view_snap_change()`, which logs `tclgetcadsnap()` right after
  `tclsetcadsnap()`.

## 9. What is still not covered (measured, not fixed)

Both shapes need Tcl run from inside a C command (a trace or a `tcleval`) that does something
nothing in the tree does: trace, unset or alias `::cadsnap`. In each, the rest of **that** C
command keeps the old value and the next `xschem` command reads the new one. Both exist
identically in stage A; this change neither adds nor fixes them. The source comment now names
both, where stage A named only the first, loosely.

Probe `scr/plim.tcl` (headless; dot sizes 3.7 / 5.18 / 5.92 are snap 10 / 14 / 16):

| shape | base | stage A | A2 |
|---|---|---|---|
| L1: a read trace on `::cadsnap`, armed and fired by a **Tcl** read in the middle of `xschem align`, writes 16 | 5.92 | 3.7 | 3.7 |
| … the next command | 5.92 | 5.92 | 5.92 |
| L2: `::cadsnap` is an `upvar` alias of `la`, and is re-pointed to `lb` (16) in the middle of a command | 5.92 | 3.7 | 3.7 |
| … the next command | 5.92 | 5.92 | 5.92 |
| L2b: later, a mid-command Tcl write of 14 through the re-pointed alias | 5.18 | 5.92 | 5.92 |
| … the next command | 5.18 | 5.18 | 5.18 |

L2b could be closed cheaply: at each real read, check with `Tcl_VarTraceInfo2` and a non-NULL
clientData that our trace is on the variable the name now resolves to. L1 and L2 cannot be closed
without a Tcl lookup per read, which is what the cache exists to avoid. I did not build either.

## 10. T1 delta (derived, not predicted)

**Method.**
- All 16 procs `summarize_all` needs were lifted out of `~/gdf2/tests/run_regression.tcl`'s own
  text with no lift errors (the verifier's `derive.tcl`).
- `banner_complete` was sourced from `tests/banner_rule.tcl`.
- The lifted `summarize_all` was run on the hcases-shaped capture of each build: stage A with its
  own 37-row file, and A2 with the 41-row file.

**Result.** Both blocks are 3 lines: the label, `RESULT: ALL PASS (N checks)` and
`Total num fail: 0`. Each has 0 `^skip:` lines.

**Relative to stage A:** cases +0, blocks +0, counted_failures +0, **skips +0**, `wc -l` +0. The
suite is already registered, and `tests/run_regression.tcl` is not in this diff. Only the
published count moves, 37 → **41**.

`skips=` cannot move. The suite prints no lowercase `^skip:` line on the `hcases` arm, measured
on the capture. None of the new rows prints one on either arm.

Relative to base, the combined patch keeps stage A's derived delta: cases +1, blocks +1,
counted +0, skips +0, `wc -l` +3.

## 11. Not covered, and harness notes

- **No full T1 run.** That is stage C's gate, in a short-path clone.
- **Not run:** `test_home_isolation` (by rule), the meta-suites, Windows builds and Tcl 8.4.
- **No `:0`, `$DISPLAY` or `:99`.** Nothing user-visible changed, so there is nothing to look at.
- **Three early headless runs went outside my display range.** They ran as `env -u DISPLAY
  tests/headless/run_suites.sh --nogui …` without `AUDIT_DISPLAY`. That spelling still takes
  `xvfb_arm.sh`'s private Xvfb, numbered from `:200`, outside my `:286`–`:295`. The logs say
  `display arm: private Xvfb from :200 up`. `xvfb-run` removed it, and none remained when I
  checked. Every later headless run set `AUDIT_DISPLAY=none` (`display arm: none`). **A brief
  that wants a headless run with no X server at all should say `AUDIT_DISPLAY=none`.**
- `run_suites.sh` and the T1-shaped runs left `*~.sch` and `untitled~.sch` backups in `~/gdf2`:
  - `tests/untitled~.sch`
  - `tests/from_user/before_{3,5,7,10,39,41}~.sch`
  - `tests/headless/fixture_0098_pre~.sch`, `fixture_0105_pre~.sch`
  - `xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc~.sch`
  - the two timing pages' `autozero_comp~.sch` and `LACG~.sch`

  Each was listed, then deleted. A final `find` for backups newer than the start mark returns
  nothing.

## 12. Reproduction

Scratch (tmpfs, may be gone):
`/tmp/claude-1000/-home-analog-dev-xschem-claude/77b869a3-9e5c-4256-9142-c01d3eba1aef/scratchpad/dragA2/`.

| what | scripts in `scr/` |
|---|---|
| finding probes | `p1.tcl` (F1–F3 shapes), `plim.tcl` (§9), `pwho.tcl`, `pnest.tcl` (§5), `p8.tcl` (the rejected drag form of S8) |
| broken copies | `mkbroken.py`, `build_all.sh`, `K1.diff`…`K7.diff` |
| health | `warn.sh`, `banner.tcl`, `derive.tcl` |
| timing | `time_gui.tcl`, `reads_gui.tcl`, `trun.sh`, `rrun.sh`, `abab.sh`, `abab58.sh`, `agg.py`, `xstart.sh`, `xlib_rc` |
| suites | `suites.sh`, `suites.txt` |

Logs are in `log/`, `suites/`, `vg/` and `tim/`.

**State left behind.**
- `~/gdf2`: detached at the scratch commit `0c8523a2c` (stage A), with this change uncommitted.
  It is configured and built, and `src/xschem` is the A2 build (same source as the measured
  `xschemA2`; its md5 differs only through `__DATE__`). The renamed binary copies (`xschemA0`,
  `xschemA2`, `xschemB0`, `xschemK1`…`K7`) were deleted at the end. `git status` shows only
  `src/scheduler.c` and the fence.
- `~/gdf2b`: base `3b36f24a1`, configured and built, clean.
- My Xvfb `:286` and its openbox were stopped by pid, after matching the display number in the
  Xvfb command line and in openbox's environment. No other display was started on purpose.
