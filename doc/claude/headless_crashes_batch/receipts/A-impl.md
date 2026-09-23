# A-impl — the class is closed in the product, and T1 counts it

> ⚠ **CORRECTED BY THE FIX ROUND — read §8 first.** The title claim is too wide: six
> more Tcl-reachable doors of this same class were still killing the process when this
> receipt was written (`waves_callback` on any loaded example, `fill_type`, `windowid`,
> `preview_window`, the `'\\'` key into `toggle_fullscreen`, and the `XK_Print` key into
> `grabscreen`), and one guard below had turned a crash into a silent, permanent swallow
> of every later event. All six are fixed and measured in §8; three figures in §0/§4 are
> corrected there too. Nothing in §1–§7 is deleted — it is the record of what was
> measured then.

Crew: **IMPLEMENTER** (items A, B and C, plus the three entry points the Map found that
are in no issue file). Work measured in the throwaway clones `/var/tmp/xhc/i/{t,t2,t3}`;
the edits are **landed in the main tree**, byte-identical to what was measured (md5 below).
Read `receipts/A-map.md` first: every site fixed here is one it named, and two of its
corrections (`copy_hilights` is not a display defect; `compare_schematics`'s row was
swapped with it) are implemented as it recommended rather than as 1492 filed them.

---

## 0. Files changed

| file | what |
|---|---|
| `src/draw.c` | item A (`display = NULL;` in `xserver_ok()`), and `grabscreen()`'s entry guard |
| `src/callback.c` | `update_statusbar()` call site; entry guards in `handle_expose()`, `draw_crosshair()`, `draw_snap_cursor()`; the three `XSetFillStyle` loops of the Ctrl-`=` fill toggle |
| `src/scheduler.c` | new `scheduler_needs_x_reject()`; applied at `fill_reset`, `fullscreen`, `compare_schematics`, `grabscreen`; a different (correct) refusal at `copy_hilights`; one new `display=` line in `xschem globals` |
| `src/hilight.c` | `copy_hilights()` tolerates a NULL `old_xctx` |
| `tests/headless/test_callback_argc.tcl` | +19 checks (⚠ §0 said +18; 8 → 27 is +19 — corrected in §8) and the `skip:` rows that carry the arm (see §4) |

**No file under `doc/claude/` is touched except this receipt.** Nothing is committed.
Landed md5 (main tree == measured clone):

```
b4b0d26c5506610326f2e876d9db0241  src/draw.c
78ae778265e92866d477a1d1c7bb7ff5  src/callback.c
ba35cdc97b81e779098c9258a3f12b2f  src/scheduler.c
8e4f2fb3a57a5136533cf919cbeb24ec  src/hilight.c
a45c869891661cd56de271410f997ac8  tests/headless/test_callback_argc.tcl
```

---

## 1. THE SITE TABLE — every site, before and after

Measured one process per row, `HOME` in scratch, on **both** `has_x == 0` arms:
`env -u DISPLAY … --nogui` and `DISPLAY=:150 … --nogui` (a private Xvfb). "base" is the
unmodified binary built from the same clone.

| # | entry point (a user's `--script` file) | site fixed | base, no DISPLAY | base, DISPLAY set | after, BOTH arms |
|---|---|---|---|---|---|
| 1 | `xschem callback .drw 2 …` (any event, any window) | `callback.c` — `if(has_x) update_statusbar(…)` | `FATAL: signal 11`, rc 1 | **libxcb abort**, rc 134 | survives, rc 0 |
| 2 | `xschem callback . 2 …` (0834's window `.`) | same site — 0834 is 0227 | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | survives, rc 0 |
| 3 | `xschem callback .drw 12 …` (Expose) — **NEW** | `callback.c` `handle_expose()` entry guard | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | survives, rc 0 |
| 4 | `set draw_crosshair 1` + Motion — **NEW** | `callback.c` `draw_crosshair()` entry guard | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | survives, rc 0 |
| 5 | `set snap_cursor 1` + Motion — **NEW** (Map: "very likely reachable") | `callback.c` `draw_snap_cursor()` entry guard | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | survives, rc 0 |
| 6 | `xschem callback .drw 2 100 100 61 0 0 4` (Ctrl-`=`) — **NEW, Map class U** | `callback.c` — 3 × `if(has_x) for(…) XSetFillStyle(…)` | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | survives, rc 0 |
| 7 | `xschem grabscreen` then any ButtonPress — **NEW** | `scheduler.c` verb refusal **and** `draw.c` `grabscreen()` entry guard | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | **Tcl error**, process alive, rc 0 |
| 8 | `xschem fill_reset` | `scheduler.c` refusal (`free_gc()` → `XFreeGC`) | `FATAL: signal 11`, rc 1 | `FATAL: signal 11`, rc 1 | **Tcl error**, rc 0 |
| 9 | `xschem fullscreen` | `scheduler.c` refusal (`toggle_fullscreen()` → `XQueryTree`) | `FATAL: signal 11`, rc 1 | libxcb abort, rc 134 | **Tcl error**, rc 0 |
| 10 | `xschem compare_schematics` | `scheduler.c` refusal (`create_gc()` → `XCreateBitmapFromData`) | **rc 139** — died before xschem's own handler | rc 139 | **Tcl error**, rc 0 |
| 11 | `xschem copy_hilights` | `scheduler.c` + `hilight.c` — **NULL `old_xctx`, not a display defect** | `FATAL: signal 11`, rc 1 | `FATAL: signal 11`, rc 1 | **Tcl error**, rc 0 |

**The two messages a user now sees**, and they name the cause rather than just failing:

```
xschem fill_reset: no X server connection (DISPLAY unset, or --nogui / -x given); this command needs a display
xschem copy_hilights: no previous window or tab to copy highlights from (open one with 'xschem schematic_in_new_window' first)
```

### 1.1 Row 11 is the Map's correction, implemented

1492 files `copy_hilights` as one of four no-display crashes. It is not one: the Map
re-took the backtrace (`hilight.c`, `entry = &old_xctx->hilight_table[i]`, `get_old_xctx()`
NULL), it touches zero display sites, and **it crashes identically with a full GUI and
`has_x == 1`** — re-measured here on `DISPLAY=:150` without `--nogui`: `FATAL: signal 11`,
rc 1, on the base build. A `has_x` guard would have left that crash live on the arm
everybody runs. The guard is therefore on `get_old_xctx()`, and the suite row for it is
the one row of this block that is **unconditional on every arm**.

Both product callers (`src/xschem.tcl`, the two descend-into-new-window paths) run
immediately after `xschem schematic_in_new_window`, which sets `old_xctx`, so neither is
affected — READ, and confirmed by T1 staying green.

### 1.2 Item A, and what it actually bought

`display = NULL;` after the `XCloseDisplay()` in `xserver_ok()`. The Map already measured
that it finds no new red by itself, and that is reproduced here. What it buys is visible
in the table above and, sharpest, in sabotage **S2**: on the base build the two `has_x == 0`
arms fail **differently** (`FATAL: signal 11` with no DISPLAY, a libxcb
`Assertion !xcb_xlib_extra_reply_data_left failed` with one). With item A applied and
0227's guard removed, both arms produce `FATAL: signal 11` — **the same fault in the same
frame on every box**. That is 1493 step 4, and it is why a missed guard is now findable.

---

## 2. THE AFFECTED SUITES, headless, at the counts they have with a display

`tests/headless/<t>.tcl`, one process each, 200 s timeout, scratch HOME.

| suite | base, no DISPLAY | after, no DISPLAY | after, `DISPLAY=:150 --nogui` | after, X arm (`has_x` 1) |
|---|---|---|---|---|
| `test_keybind_snap_grid` | 2 `ok:`, `FATAL: signal 11` | **`ALL PASS (6 checks)`** | `ALL PASS (6 checks)` | `ALL PASS (6 checks)` |
| `test_undo_selection` | 20 `ok:`, `FATAL: signal 11` | **`ALL PASS`, 22 `ok:`** | `ALL PASS`, 22 `ok:` | `ALL PASS`, 22 `ok:` |
| `test_window_switch_bogus_enter` | 0 `ok:`, `FATAL: signal 11` | **`ALL PASS (2 checks)`** | `ALL PASS (2 checks)` | `ALL PASS (2 checks)` |
| `test_hilight_case_senders` | 6 `ok:`, `FATAL: signal 11` | 21 `ok:`, **no `RESULT:`** | same | `ALL PASS (30 checks)` |
| `test_callback_argc` (this batch's T1 case) | 8 `ok:`, `FATAL: signal 11` | **`ALL PASS (27 checks)`** | `ALL PASS (27 checks)` | `ALL PASS (18 checks)` + 5 `skip:` |

Three of 0227's four witnesses now pass headless with the counts they have with a display.
**The fourth does not, and it is not this defect** — see §6.1.

### 2.1 The whole headless corpus, base vs fixed

All **406** `tests/headless/test_*.tcl`, `--nogui`, `env -u DISPLAY`, 90 s timeout,
private HOME per job:

| | base | after |
|---|---|---|
| `FATAL: signal` | **5** — `test_callback_argc`, `test_hilight_case_senders`, `test_keybind_snap_grid`, `test_undo_selection`, `test_window_switch_bogus_enter` | **0** |
| `RESULT: ALL PASS` | 245 | 249 |

Three suites changed verdict for the better and one apparent regression was chased down:

* `test_no_untitled_litter`: **`2 FAILED` → `ALL PASS`**, re-measured by hand on both
  builds. It spawns `test_undo_selection` as a child and asserts on what that child left
  behind; the child used to die, so two of its rows could never hold. **A second suite
  fixed by this change, and it is not one 0227 lists.**
* `test_undo_link_symbols` printed `PASS → RESULTOTHER` in the sweep. **Re-run by hand on
  both builds: `RESULT: ALL PASS` on each.** It was my sweep harness — the per-job HOME it
  creates raced with `Tcl_AppInit(): failure creating <home>/.xschem`. Not a product
  difference, and named here rather than left as an unexplained delta.
* `test_ase_optier_0963` is `rc 124` on **both** builds: my sweep's 90 s cap, well under
  what that suite needs (it passes in T1, which allows 900 s). Not a finding.

### 2.2 Every subcommand, followed by ten canvas events

`src/xschem_subcommands.txt` (build-generated), **323** verbs, one process each, each
running `catch {xschem <verb>}` then ten `xschem callback .drw <e> …` events:

| | no DISPLAY | `DISPLAY=:150 --nogui` |
|---|---|---|
| base | **323 / 323 died** | **323 / 323 died** |
| after | **0 / 323 died** | **0 / 323 died** |

and the two fixed arms are **byte-identical to each other for all 323 verbs**. (The base
figure is saturated because `update_statusbar()` killed every one of the ten events.)

⚠ **`0 / 323` IS NOT `0` — the corpus has two blind spots, and both hid a live crash**
(fix round, §8). Every verb was driven **bare**, so any branch body inside `if(argc > 3)`
was never entered (`fill_type`, `preview_window`), and the ten canvas events ran on an
**empty untitled** schematic with key and state held fixed, so `waves_selected()` always
declined (`waves_callback`) and the one lethal keystroke (`'\\'`) never fired. Re-driven
with arguments, on a loaded example, and over a full key × state sweep, the same corpus
finds **three more deaths** on this build and a fourth by keystroke.

### 2.3 The X path is unchanged

The four guarded verbs, driven with `has_x == 1` on `DISPLAY=:150` (no `--nogui`),
`compare_schematics` given a real file so it does not open its modal chooser:

```
BASE : XARM: fill_reset:ok fullscreen:ok compare_schematics:ok grabscreen:ok
FIXED: XARM: fill_reset:ok fullscreen:ok compare_schematics:ok grabscreen:ok
```

Identical. `test_callback_argc` carries this as a counted row of its own (§4).

---

## 3. SABOTAGES — each guard, reverted, both arms

Method: revert one guard with a line-anchored `sed`, `make`, run the T1 case on both
`has_x == 0` arms, restore, `touch` (a restored file must be newer than its `.o`, or the
next build silently keeps the sabotage — that cost one wrong reading, recorded here so
nobody repeats it), rebuild, and **`md5sum -c` against the table in §0**, which passes.

| # | guard reverted | no DISPLAY | `DISPLAY=:150 --nogui` |
|---|---|---|---|
| S1 | item A `display = NULL;` | `ALL PASS (26)` — see below | **`1 FAILED`**: *1493 the display global reports NO connection when has_x is 0* |
| S2 | `if(has_x) update_statusbar(…)` | `FATAL: signal 11` | `FATAL: signal 11` |
| S3 | `handle_expose()` entry guard | `FATAL: signal 11` | `FATAL: signal 11` |
| S4 | `draw_crosshair()` entry guard | `FATAL: signal 11` | `FATAL: signal 11` |
| S5 | `draw_snap_cursor()` entry guard | `FATAL: signal 11` | `FATAL: signal 11` |
| S6 | the three `XSetFillStyle` guards | `FATAL: signal 11` | `FATAL: signal 11` |
| S7 | `fill_reset` refusal | `FATAL: signal 11` | `FATAL: signal 11` |
| S8 | `fullscreen` refusal | `FATAL: signal 11` | `FATAL: signal 11` |
| S9 | `compare_schematics` refusal | **rc 139**, no `RESULT:` line at all | rc 139 |
| S10 | `grabscreen` **verb refusal only** | `3 FAILED`, no crash | `3 FAILED`, no crash |
| S11 | `grabscreen` **entry guard only** | `ALL PASS (27)` | `ALL PASS (27)` | ⚠ **the reason given below is WRONG — see §8.4** |
| S12 | `grabscreen` **both** | `FATAL: signal 11` | `FATAL: signal 11` |
| S13 | `copy_hilights` both guards | `FATAL: signal 11` | `FATAL: signal 11` |

**Two rows are honest negatives and are printed rather than hidden.**

* **S1 does not redden on the DISPLAY-unset arm, and cannot.** With no DISPLAY the global
  was never assigned, so nulling it changes nothing there. It reddens on the arm where the
  defect lives — `--nogui` with a DISPLAY, which is T1's own arm on a developer box. The
  suite's comment states this limit in place rather than leaving it to be rediscovered.
* **S11 stays green because the guard it removes is unreachable once the verb refuses.**
  `grabscreen()`'s entry guard is deliberate defence in depth for a GRABSCREEN bit armed
  while a display existed; S10 shows the verb refusal alone holds the crash off, and S12
  shows that removing both brings it back. Three sabotages, not one, because one would
  have mis-stated which guard does the work.

---

## 4. T1 VISIBILITY (acceptance criterion 4)

`tests/headless/test_callback_argc.tcl` gains **18 checks** (8 → 26 on the `has_x == 0`
arms, plus the grabscreen sequence row = 27). ⚠ **The delta is +19, not +18** (8 → 27,
which is what the implementer's own hand-off message said); re-measured twice by the
verify round and once by the fix round, which takes it to 50. It is the right home, as the Map argued:
it is already a T1 case, it is already the case for issue 0076's contract ("a
Tcl-reachable subcommand must ERROR, never crash"), it already has three rows of exactly
this shape from 1483, and **`run_regression.tcl` hard-codes `--nogui`, so `has_x` is 0 in
T1 on every box** — including a developer desktop with a display.

Counts, measured on four arms:

| arm | checks | `skip:` |
|---|---|---|
| `env -u DISPLAY … --nogui` (T1's, headless box) | **27** | 0 |
| `DISPLAY=:150 … --nogui` (T1's, developer box) | **27** | 0 |
| `DISPLAY=:150 … -x` (the third route to `has_x` 0) | **27** | 0 |
| `DISPLAY=:150 …` (`has_x` 1 — `run_suites.sh`, `full_audit.sh`) | 18 | ~~4~~ **5** (⚠ corrected: fullscreen, compare_schematics, grabscreen, the grabscreen sequence, the Ctrl-`=` toggle — §2's own table already said five; the fix round adds two more, and 36 checks) |

**T1 gains no `skip:` line.** The rows that cannot be measured with a display are
`skip:`-ed on the X arm only, each with its reason, and `fill_reset` is branched instead
(one row either way, the 1483 rows' idiom) because it carries the anti-hollow assertion:
with `has_x == 1` the verb must still **work**, so a guard written `if(1)` reddens there.

Three of the X-arm skips are not laziness: `xschem compare_schematics` with no argument
opens a **modal file chooser** and hangs (measured, rc 124), the Ctrl-`=` toggle pops a
modal `alert_` and hangs the same way, and `xschem grabscreen` takes a **global pointer
grab**. Driving those on a shared display would wedge the suite.

The new `display=` key in `xschem globals` exists for one reason: it is the only thing
that makes **item A** observable from a test. It reports the pointer and never
dereferences it, and every other consumer of `xschem globals` in the tree reads
key-prefixed lines, so the extra line is additive (READ: `test_snap_bindkeys`,
`test_apply_hilight_log`, `test_flylines_render`, `test_auto_specialize_1201`,
`test_op_annot`, `test_flylines.sh`).

---

## 5. THE GATE

Two clones of the **current** `fluid-editing` HEAD `b2431613`, one per display arm, run
concurrently with `home=throwaway`; a third, older clone (`703b7b59`, 88 cases) ran the
DISPLAY-set arm as corroboration. Trailers **verbatim**:

**Arm 1 — `DISPLAY` UNSET** (`/var/tmp/xhc/i/t2`, `tests/results.3289915.log`):

```
T1-RUN-BEGIN pid=3289915 script=run_regression.tcl start=2026-09-22 14:53:57 planned_cases=90 verdict=results.3289915.log home=throwaway binary=/var/tmp/xhc/i/t2/src/xschem canonical=results.log
T1-RUN-END pid=3289915 cases=90 blocks=89 counted_failures=0 skips=6 elapsed=620s end=2026-09-22 15:04:17
```

**Arm 2 — `DISPLAY` SET** (`/var/tmp/xhc/i/t3`, `tests/results.3322230.log`):

```
T1-RUN-BEGIN pid=3322230 script=run_regression.tcl start=2026-09-22 14:55:13 planned_cases=90 verdict=results.3322230.log home=throwaway binary=/var/tmp/xhc/i/t3/src/xschem canonical=results.log
T1-RUN-END pid=3322230 cases=90 blocks=89 counted_failures=0 skips=6 elapsed=589s end=2026-09-22 15:05:02
```

**Corroboration — the older tree `703b7b59` + these changes, `DISPLAY` SET**
(`/var/tmp/xhc/i/t`, `tests/results.3226804.log`):

```
T1-RUN-BEGIN pid=3226804 script=run_regression.tcl start=2026-09-22 14:48:31 planned_cases=88 verdict=results.3226804.log home=throwaway binary=/var/tmp/xhc/i/t/src/xschem canonical=results.log
T1-RUN-END pid=3226804 cases=88 blocks=87 counted_failures=0 skips=5 elapsed=560s end=2026-09-22 14:57:51
```

Read with the trailers:

* **`counted_failures=0` on both arms**, and zero lines of any counted shape
  (`/usr/bin/grep -nE 'Total num fail: [^0]|^FATAL|FAIL$|GOLD\?$|RESULT\?$'` returns
  nothing in either verdict).
* **`skips=6` on both arms, which is the baseline this tree already carries** (CLAUDE.md,
  measured at the 1352 fix: `90/89/skips=6`). The six are `test_op_annot`'s five
  display-only rows and `test_input_line_inject_1352`'s Tk-dialog block. **This crew's 19
  new checks add ZERO skips to T1**, by design (§4) — `skips=5` on the 88-case tree is
  likewise its own documented baseline.
* `NODISPLAY: 0` and no `display arm NOT RUN` line in either: the eleven `dcases` really
  ran on both arms, on a private Xvfb from `:100` when `DISPLAY` was unset.
* `test_callback_argc` reports **`RESULT: ALL PASS (27 checks)`** in both verdicts — 8
  before this crew.
* The two runs were concurrent, in two separate clones, each with `home=throwaway`, and
  each names its own clone's binary in `binary=`. Neither announced a live peer in its own
  tree.

The **main tree** was rebuilt after the copy (`make -C src`, no warning in any file this
crew touched) and `test_callback_argc` re-run against that binary: `RESULT: ALL PASS (27
checks)`. **The driver should still rebuild before its own gate** — the harness never
builds, and this tree also carries other crews' uncommitted work.

---

## 6. WHAT I DID NOT FIX, AND WHY

### 6.1 `test_hilight_case_senders` still prints no `RESULT:` headless — and it is a test defect

After the fix it reaches **21 `ok:` rows** (from 6) and no longer crashes, then stops:

```
Tcl_AppInit() error: can not execute tests/headless/test_hilight_case_senders.tcl, please fix:
invalid command name "toplevel"
Line No: 564
```

`toplevel` is a **Tk** command, and `--nogui` has no Tk. This is the suite's own use of a
widget, not a `display` dereference, so no product guard can reach it. It is not a T1 case
and not in `full_audit.sh`'s `nogui_tests`, so nothing counts it either way; on the X arm
it is `ALL PASS (30 checks)`. **Filed here, not fixed** — making that suite headless means
editing the suite, which is a different item from this one.

### 6.2 `xschem hier_psprint` segfaults headless at `psprint.c` — a different class

The Map recorded it (`strcmp` on a NULL in `ps_draw_symbol()`); it is not a `display`
dereference and not this class. Untouched.

### 6.3 The Map's class U, beyond the sites this receipt names

The Map's §6(d) is right that "not reached by this workload" is not "unreachable", and
**one of its class-U rows turned out to be reachable from two lines of Tcl** — the Ctrl-`=`
`XSetFillStyle` sites, which are row 6 above. The rest were read and left:

* `xinit.c set_clip_mask` (8), `net_active_window` (3), `find_best_color` (3) and
  `actions.c fix_restore_rect` (4) are guarded **at every call site** (READ), and the
  323-verb × 10-event sweep reaches none of them.
* `draw.c draw_graph` / `draw_graph_points` / `draw_graph_bus_points` / `set_thick_waves`
  are reached through `draw()`, whose Xlib block is inside `if(has_x)`; the graph snap
  cursor family (`graph_snap_clear`, `draw_graph_snap_cursor`) **already** opens with
  `if(!has_x)` (READ).
* `move.c draw_selection_impl`'s `MyXCopyArea` needs `fix_broken_tiled_fill || !_unix`
  **and** `movelastsel > 800`; `xinit.c pending_events()` → `XPending(display)` is reached
  only from an `interruptable` move overlay. Neither was reached by any of the 1,059
  processes driven here. **Unreached, not proved unreachable**, and named so the next
  crew has the list rather than a count.
* `xinit.c create_gc`/`free_gc`/`toggle_fullscreen`/`grabscreen`'s remaining sites are
  past the first fault inside functions whose only Tcl-reachable entry now refuses.

### 6.4 The `#ifdef`-excluded sites the compiler cannot see

`psprint.c` (`HAS_LIBJPEG`), `draw.c:165` (no-cairo), the six `XDrawLine` and four
`Tk_*Pixmap` calls under `#ifndef __unix__` (Windows) and the `#if 0` XCB call. Out of
reach of any measurement on this configuration; unchanged, and the Map's §6(a) is the
list.

### 6.5 The issue files are not edited

The task fences `doc/claude/` to this receipt. 0227, 0834, 0467, 1492 and 1493 all need a
resolution section, and 0467's proposed closure as a duplicate of 0227 is now
implementable (0227 is fixed). **That is the driver's edit, not mine.**

---

## 7. Housekeeping

* **Scratch**: `/var/tmp/xhc/i/` only — three clones (`t`, `t2`, `t3`), a work dir and a
  scratch HOME. **Peak size 744 MB** (three built clones plus sweep output). Deleted by
  this crew; `/var/tmp/xhc` itself and the sibling `a/` subtree were left untouched, and
  `/var/tmp/xhc` now contains only `a/`.
* A private **Xvfb on `:150`** was started and stopped. The dev display `:99` was never
  touched; `HOME` was `/var/tmp/xhc/i/home` or a per-job scratch throughout; `~/.claude`,
  `~/.xschem` and `~/dev/xschem-op-wcard` were not written.
* Every crash writes an emergency-save directory to `/tmp`, ignoring `TMPDIR`. The 668
  present before this crew started were snapshotted; the **365** this crew's red-first
  runs created were removed, and `/tmp` is back at 668. One
  `/tmp/xschem-test-home.3479800.*` belongs to a T1 run that is not one of this crew's
  three (3226804, 3289915, 3322230) and was left alone.
* The build adds **no new compiler warning**: the six `-Wdiscarded-qualifiers` in a full
  rebuild are pre-existing, in `actions.c`, `util.c`, `save.c` and `token.c`, none of them
  a file this crew touched.

---

## 8. THE FIX ROUND — what this receipt got wrong, and what is true now

Appended by the **FIXER** crew (2026-09-22) after the two verify crews. Full measurements,
sabotages and both T1 trailers are in `A-verify.md`; this section exists so nobody reads
§0–§7 and stops.

### 8.1 The class was NOT closed. Six more doors, all Tcl-reachable, all measured

| door | shape | red-first on the binary this receipt landed |
|---|---|---|
| `xschem load <example>; zoom_full; callback … 6 …` | `waves_callback()` → `cairo_save(NULL)` | `FATAL: signal 11` (23 of the 60 shipped examples) |
| `xschem fill_type <n> <type>` | `free_gc()`/`create_gc()`, argc > 3 | `FATAL: signal 11` |
| `xschem windowid .drw` | `Tk_Display(Tk_MainWindow(NULL))` | `FATAL: signal 11` |
| `xschem preview_window create .x .x.drw` | `Tk_NameToWindow()` on a NULL mainwindow | `FATAL: signal 11` |
| `xschem callback .drw 2 … 92 0 0 0` (the `'\'` key) | `toggle_fullscreen()` → `XQueryTree` | `FATAL: signal 11` |
| `xschem callback .drw 2 … 65377 0 0 0` (the Print key) | arms `GRABSCREEN`; `grabscreen()` returned without clearing it | **no crash — every later event silently swallowed** |

The last row is the important one: this receipt's own guard turned a loud crash into a
permanently dead editor, which is what PLAN.md criterion 3 forbids. Measured: after Print,
the zoom-full key left `xorigin yorigin zoom` at `10 -870 1`; without Print it moved to
`104.418 103.093 0.2946`.

### 8.2 Why §2.2's `0 / 323` could not see any of them

The corpus drove every verb **bare** (so `if(argc > 3)` bodies were never entered), ran its
ten events on an **empty untitled** schematic (so `waves_selected()` always declined), held
**key and state fixed** (so one keystroke in ~700 never fired), and enumerated the `display`
**global** (blind to a shadowing local, and to handles stored in `xctx`). Each of the four
hid one of the six. The figure is not wrong; its scope was never stated.

### 8.3 The three corrections to the numbers

* §0 and §4: the delta is **+19**, not +18 (8 → 27). The suite is now at **50**.
* §4's arm table: the `has_x == 1` arm had **5** `skip:` lines, not 4 — §2's own table already
  said five. It is 7 now, on an arm T1 does not run.
* The title: the class is closed **at every site the methods used here can reach**; §8.2 is
  the list of what they cannot.

### 8.4 S11's conclusion was wrong

§3 says S11 "stays green because the guard it removes is unreachable once the verb refuses".
It was reachable through `XK_Print`, which the suite never drove. The correct sentence:
**green because the suite drove the verb and not the Print key.** It now reddens (`GX8`).
S13 had the same shape — it reverted both `copy_hilights` guards together, so it never showed
which one works. Sabotaged separately in the fix round: the `hilight.c` one is unreachable
today (green alone) and load-bearing the moment the scheduler refusal is not (2 rows red).

### 8.5 What the fix round added to the tests

`test_callback_argc.tcl` 27 → **50** checks, still **zero `skip:` in T1**: the six doors
above, a control/test pair for the Print-key swallow, and thirteen `GX*` rows that pin each
guard's *condition* (`if(1)`, `if(0)` or a guard moved to the wrong side all redden them).
Plus a new **`dcases`** suite, `test_headless_guards_xarm_1492.tcl` (8 checks with a
display), because this receipt's anti-hollow row lived on an arm T1 never runs.
