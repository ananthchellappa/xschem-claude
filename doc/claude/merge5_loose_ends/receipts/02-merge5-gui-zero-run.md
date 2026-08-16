# Item 02 — drain the `merge5-gui` suite debt: the `:0` leg of the open_pdk merge

Base HEAD `22ecc20c` (item 01, on `938388a5`), branch `fluid-editing`. **Every number below says
which display it came from.** `GUI_GATE=1` was exported for every run I launched; the gate's
control dir was already armed `allow_until=forever` and I never wrote to it, never relaunched
the panel and never pressed anything — every `gate_start` took the "approved batch window open"
path and said so. Nothing was pushed; the tree is left dirty for the verifier.

**Verdict: [x].** No pixels: the merged C is byte-identical to `github/open_pdk`, which the user
has already eyeballed, so this was always the WSLg *event-traffic* leg, not a look debt. No
`owed.sh add look` is owed by this item.

## 1. What was run, and why that list

`full_audit.sh:161`'s `nogui_tests` was read first and **every member of it was excluded** — its
seven merge-touched members (`test_descend_symbol`, `test_placement_wire_gate`,
`test_shape_draw_gate`, `test_placement_preview_doors`, `test_paste_modify_flag_0244`,
`test_descend_refusal_channel_0251`, `test_cosim_golden_e2e`) raise modals that nothing dismisses
under X and hang rather than fail (issue 0414).

The driver's list was then **widened, and the widening is the reason this item found anything**.
The measured set of what the merge actually touched is

```sh
git diff --name-only pre-open-pdk-merge-5 e7ae4d77 -- tests/headless/   # 24 test_*.tcl
```

24 suites, minus the 7 `nogui_tests` members = **17 GUI-capable merge-touched suites**, of which
the driver's list named 9. The other 8 (`test_altf5_ciw`, `test_phase3_mints`,
`test_add_pin_lib_symbol_view`, `test_ase_dialogs`, `test_audit_classifier`,
`test_backing_store_0413`, `test_cmdmode_descend_0201`, `test_readonly_guard`) were added: they
are merge-touched, they are not `nogui_tests`, they already pass under X on `:99` (so none of
them can be a modal hang), and two of them turned out to be the only merge-touched suites that
are red on the user's real screen. Plus the three that carry their **own** debts
(`test_calc_skeleton`, `test_calc_widgets`, `test_ase_window`) = **20 suites**.

**Mode matched per suite, or the A/B lies.** Six of them are on `full_audit.sh`'s `logdir_tests`
(`test_select_same_net_by_label`, `test_snap_bindkeys`, `test_context_menu_descend_refusal_0249`,
`test_hi_descend`, plus the added `test_altf5_ciw` and `test_phase3_mints`) and were run
`--logdir`; the rest `--nolog`. Three print **custom banners** that `run_suites.sh` scores
`NORESULT` by construction (`run_suites.sh:150-152`) — `test_hi_descend`,
`test_cadence_descend_newwin_ro`, `test_readonly_guard` — so their verdicts were read from their
own banner, not from the driver's summary line.

Instruments: `tests/headless/run_suites.sh` for the gated batch verdicts and the repeat runs, and
`tests/headless/gated_xschem.sh` one suite at a time (the sanctioned drop-in) to capture full
output, since `run_suites.sh` discards it and three of these suites report no check count. **No
bare `for … ./src/xschem` loop was written.** `owed.sh drain` was not run (its `:306` hands names
to `run_suites.sh` with no mode flag, and `merge5-gui` is a debt name, not a test name).

## 2. The run, both displays, verbatim

`:99` = the persistent dev display (Xvfb 1920x1080x24 + openbox), `:0` = the user's real WSLg
screen. `ok=` is the count of `^ok` lines; `RESULT` is verbatim. Both legs used the identical
per-suite command; only `AUDIT_DISPLAY` differed.

**FINAL state (after the two fixes in §4):**

| suite | `:99` | `:0` |
|---|---|---|
| test_select_same_net_by_label | 28 ok `RESULT: ALL PASS` | 28 ok `RESULT: ALL PASS` |
| test_snap_bindkeys | 46 ok `RESULT: ALL PASS` | 46 ok `RESULT: ALL PASS` |
| test_context_menu_descend_refusal_0249 | 6 ok `OVERALL: ok (6 checks)` | 6 ok `OVERALL: ok (6 checks)` |
| test_hi_descend | 24 ok `hi_descend headless: all checks passed` | 24 ok, same banner |
| test_altf5_ciw | 10 ok `RESULT: ALL PASS` | 10 ok `RESULT: ALL PASS` |
| test_phase3_mints | 26 ok `RESULT: ALL PASS` | 26 ok `RESULT: ALL PASS` |
| test_descend_inert_class | 177 ok `OVERALL: ok (177 checks)` | 177 ok, same |
| test_cadence_descend_newwin_ro | 21 ok `cadence_descend_newwin_ro headless: all checks passed` | 21 ok, same |
| test_create_instance | 72 ok `RESULT: ALL PASS` | 72 ok `RESULT: ALL PASS` — **but this was ONE sample and it was wrong to report it as the suite's `:0` state; see §9.1. Repeated, the pre-fix file is 0/10 on `:0`** |
| test_add_wire_label | 184 ok `RESULT: ALL PASS (184 checks)` | 184 ok, same |
| test_sch_add_pin | 25 ok `RESULT: ALL PASS (25 checks)` | 25 ok, same |
| test_calc_skeleton | 503 ok `RESULT: ALL PASS (503 checks)` | 503 ok, same **(but see §3.3 — 5 of 6 earlier `:0` runs were red)** |
| test_calc_widgets | 244 ok `RESULT: ALL PASS (244 checks)` | **243 ok `RESULT: 1 FAILED (243 passed)`** |
| test_ase_window | 168 ok `RESULT: 1 FAILED (168 passed)` | **168 ok `RESULT: 1 FAILED (168 passed)`** |
| test_add_pin_lib_symbol_view | 12 ok `OVERALL: ok` | 12 ok `OVERALL: ok` |
| test_ase_dialogs | 147 ok `RESULT: ALL PASS (147 checks)` | 147 ok, same |
| test_audit_classifier | 50 ok `RESULT: ALL PASS (50 checks)` | 50 ok, same |
| test_backing_store_0413 | 6 ok `RESULT: ALL PASS (6 checks)` | 6 ok, same |
| test_cmdmode_descend_0201 | 90 ok `RESULT: ALL PASS` | 90 ok `RESULT: ALL PASS` |
| test_readonly_guard | 13 ok `READONLY_GUARD_TEST_PASS` | 13 ok, same |

**TOTAL check counts are identical on the two displays for all 20 suites** — that is the witness
that nothing aborted early on either. Two corrections to what that sentence originally claimed,
both made by the fix round:

* **`ok`-counts are NOT identical for all 20.** `test_calc_widgets` is 244 ok on `:99` against
  243 ok + 1 FAIL on `:0`. The totals match; the `ok`-counts do not, and the `ok`-count is the
  half the `:0`/`:99` comparison is actually about. 19 of 20 match.
* **An identical count is not, by itself, evidence about the `:0` leg.** Some of these suites are
  not display-sensitive at all: `test_audit_classifier` runs the same 50 checks with
  `AUDIT_DISPLAY=none` (no X connection whatsoever), so its `:0 == :99` count says nothing about
  WSLg event traffic. The count is a witness that a suite ran to the end, and only that; the
  display-sensitivity evidence is in §3, §5 and §9.

`test_ase_window`'s single red is W7 (`simulator produced output before Stop`): 1 failed / 168
passed on **both** displays here, matching the A/B against the pre-merge binary in
`open_pdk_merge5_result.md` §6. Not chased, as instructed.

## 3. What was red on `:0` and nowhere else — four cases, each diagnosed

The first `:0` pass (before any fix) read:

```
test_altf5_ciw            ok=9   fail=1   RESULT: FAIL
test_calc_skeleton        ok=501 fail=2   RESULT: 2 FAILED (501 passed)
test_calc_widgets         ok=243 fail=1   RESULT: 1 FAILED (243 passed)
test_cmdmode_descend_0201 ok=80  fail=9   RESULT: 9 FAILURE(S)
```

against 20/20 green on `:99` (bar W7). Repeat rates on `:0`, through `run_suites.sh -n 5/6`:
`test_altf5_ciw` 2/5 passed, `test_cmdmode_descend_0201` 3/6, `test_calc_skeleton` 2/7 across the
whole item (1/6 before the closing pass, which happened to be green), `test_calc_widgets` **0/7**. None of the four is one of the three known WSLg flakes I was told
not to report (TG9 root-coords, `test_ase_plot` P4/P6/P8, bare `event generate` key delivery) —
each was probed to a mechanism rather than labelled.

### 3.1 `test_cmdmode_descend_0201` — the canvas was never mapped **(a): WSLg timing. FIXED here.**

A copy of the suite in the scratchpad, with three diagnostic lines added, run four times on `:0`
and once on `:99`:

```
:0 run 1  DIAG AT-DS4 win=1067x666 mapped=1 zoom=1.835 sx=108 sy=551 focus=.drw  -> ALL PASS
:0 run 3  DIAG AT-DS4 win=1x1      mapped=0 zoom=1834.6 sx=0  sy=0   focus=      -> 9 FAILURE(S)
:0 run 4  DIAG AT-DS4 win=1x1      mapped=0 zoom=1834.6 sx=0  sy=0   focus=      -> 9 FAILURE(S)
:99       DIAG AT-DS4 win=1110x693 mapped=1 zoom=1.764  sx=112 sy=574 focus=.drw -> ALL PASS
```

In the red runs `.drw` is **1x1 and `ismapped 0` for the entire run**. The file's preamble used
`update idletasks`, which runs idle handlers and processes **no X events at all**, so the
MapNotify was still in the queue; `xschem zoom_full` then fitted the drawing into one pixel
(zoom 1834 vs 1.83), `sx`/`sy` computed (0,0) for every point so every click landed on the
corner instead of the instance, and `focus -force .drw` could not take, so DS7's real `<Key-e>`
went nowhere. **Worse than the 9 reds: 80 checks still printed `ok:` against a canvas that was
never there** — red-but-hollow's mirror image.

### 3.2 `test_altf5_ciw` — `wm state` is asynchronous on WSLg **(a). FIXED here.**

A probe replaying the suite's own sequence and then polling:

```
:0 run 1  immediately-after-update-idletasks: state=iconic   settled normal after   60 ms
:0 run 2  immediately-after-update-idletasks: state=iconic   settled normal after 1100 ms
:0 run 3  (leg C) immediate=iconic                            settled normal after 2920 ms
:99       immediate=normal                                    settled normal after    0 ms
```

The CIW *is* raised; the state has simply not been reported back when the suite reads it.

### 3.3 `test_calc_skeleton` S11 — the same class, but **not fixed here**: filed as issue 0416

```
FAIL: S11 default sash2 near 64% of 777   FAIL: S11 default bot sash near 78% of 1
```

The denominators are the diagnosis: `H` reads 777/657 instead of the 800 just requested, and
`W` reads **1** — `.calc.pw.bot` was never laid out. `calc::restore_layout_body`
(`src/calculator.tcl:2245`) correctly *skips* every sash when `extent <= 40`, so the product is
innocent; only the assertion is wrong. **Ruling: not mine to fix.** `test_calc_skeleton` belongs
to the Calculator batch and carries its own suite debt; the diagnosis and the prescribed fix
(the S12 pattern, applied to S11) are written into
`doc/claude/issues/0416-…-before-wslg-has-applied-it.md`. Its debt is left **standing**.

### 3.4 `test_calc_widgets` R111 — a font-metric coincidence, **not** a race: issue 0417

A probe printing the failing check's three conjuncts separately:

```
:99  conj1 bot_h>both0 : 1 (374 vs 227)   conj2 pad_w==pad_reqw : 1 (128 vs 128)
:0   conj1 bot_h>both0 : 1 (374 vs 227)   conj2 pad_w==pad_reqw : 0 (128 vs 116)
```

`.calc.pad`'s *requested* width is 128 under Xvfb and **116** under WSLg (different default font),
while its *allocated* width is 128 on both, because the pane's documented `-minsize 140` floor
(`src/calculator.tcl:2035-2076`, "140 == 140 IS ZERO SLACK") is doing exactly what it was
written to do. The check pins that zero slack, i.e. one display's font metrics. Deterministic
(0/7 on `:0`, 7/7 on `:99`), not a race, not a product bug. Same ruling as 3.3: filed as issue
**0417**, debt left standing.

## 4. What changed — two test files, no C, no product code

```
tests/headless/test_cmdmode_descend_0201.tcl  | +30  (a bounded map wait + one new check, FX0)
tests/headless/test_altf5_ciw.tcl             | +25  (a `wait_state` poll; 3 checks restated)
```

Both are the prescribed class-(a) fix: **force the race in the test**, the
`test_calc_skeleton` S12 pattern, never chase window managers. No check was renumbered or
deleted. `test_altf5_ciw`'s three checks are **restated, not replaced** — same names, same
claims, an oracle that waits for the state instead of reading a value the server has not sent
yet. Cost: `test_altf5_ciw` goes 0.3 s → 5.6 s on `:99` (7.1 s → 8.0 s on `:0`), because the
negative leg must spend its whole window; that is stated in the file.

**New checks: exactly one** — `FX0 the canvas is mapped and really sized before anything is
measured`. Check ids here are per-file names (`CS*`/`DS*`/`MS*`), not a global numeric band;
`FX` was unused in the file (`grep -c 'FX0\|FX1'` = 0 before the edit).

## 5. Drives and sabotages

| drive | what was broken | red? | restored green? |
|---|---|---|---|
| **FX0** | `wm withdraw .` inserted above the wait loop in the shipped file | **yes, deterministically on BOTH displays** — `FAIL: FX0 … (got 0 1 want 1 1)`, `RESULT: 5 FAILURE(S)`. Note the other 84 checks tolerated it: FX0 is the only one that sees an unmapped canvas | **yes** — restored from a byte-exact backup (never `git checkout`), `RESULT: ALL PASS`, 90 ok |
| **the map wait itself** | the pre-item file (md5 `535f149bcc349a8f5b87ade7682712c9`), which is the same file without the loop | **yes** — 3 of 6 runs on `:0` `RESULT: 9 FAILURE(S)`, plus 2 of 4 probe runs, with the `win=1x1 mapped=0` trace above. **⚠ this rate is not reproducible on demand — see §9.3; it ranges from 1-in-31 to 6-in-8 with the compositor's state** | **yes** — with the loop, 6/6 `run_suites.sh -n 6` on `:0` at the time, and 90 ok on both displays. **Corrected in §9.3: what the loop reliably removes is the `MS4/MS7b/MS8c/MS9c` sx/sy-collapse signature; residual reds are the documented key-delivery flake, and a reviewer measured 5/6 not 6/6** |
| **`test_altf5_ciw` positive legs** | product sabotage: `return ;# SABOTAGE` above `raise_activate_toplevel .ciw` in `src/ciw.tcl:38` | **yes on both displays** — `FAIL - Alt-F5 raises/opens the CIW`, `FAIL - rebound Alt-F5 raises CIW again`; the negative leg stayed green, correctly | **yes** — `src/ciw.tcl` md5 `6f500773d9b5bf1e0f581874650adce2` before and after, `git status` clean |
| **`test_altf5_ciw` negative leg** | the suite's `xschem unbind key $F5 alt canvas` neutered | **yes** — `FAIL - un-bound Alt-F5 no longer raises CIW` | **yes** — restored, `RESULT: ALL PASS` |
| **the `wait_state` poll on `:0`** | 6 consecutive `run_suites.sh -n 6 --logdir` runs | before: **2/5 passed**; after: **6/6 passed** | — |

**Honest negative result, recorded rather than buried:** the same neutered-unbind sabotage run
against the *pre-item* file (immediate read) was caught **4 times out of 4** on `:0`. So the
false-green the negative leg's 5 s window guards against is a *measured mechanism* (the same
0–2920 ms lag), **not an observed failure**. The test comment says so in those words.

## 6. Debt decisions

| debt | decision | why |
|---|---|---|
| `merge5-gui` | ~~CLEARED~~ → **RE-ADDED, then cleared again on better evidence.** See §9.4 — the original clear was premature and is the fix round's headline correction | the original justification (below) was true of a single sample per suite. It is now backed by a third `:0` defect found and fixed (CI15), a written scope ruling in `doc/claude/specs/owed.md` R4b, and a repeat run rather than one pass |
| `test_ase_window` | **STANDING** | its suite did not run clean (W7). Pre-existing and A/B-confirmed, so the debt as written can never be paid by a green run — that is for the ASE/Calculator crew to re-scope, not for me to discharge |
| `test_calc_skeleton` | **STANDING** | 2 of 7 `:0` runs green (S11 is flaky, not deterministic); issue 0416 |
| `test_calc_widgets` | **STANDING** | 0 of 7 `:0` runs green; issue 0417 |
| `test_gui_gate_revive` | **UNTOUCHED** | not in this item's set; not run, not cleared |
| any **look** debt | **UNTOUCHED** | none added, none cleared. A suite debt and a look debt are not interchangeable, and only the user clears a look |

## 7. What was NOT verified

* **`test_calc_skeleton` S11 and `test_calc_widgets` R111 were diagnosed, not fixed.** Two
  issues were filed instead (0416, 0417). Whether the fixes are right is the Calculator batch's
  call.
* **Only the merge-touched, non-`nogui` set was run on `:0`** (20 suites). The other ~300 audit
  suites have still only ever run on `:99`; this item never claimed otherwise.
* **`test_cmdmode_descend_0201` exits 0 even when it reports 9 failures** — noticed while
  measuring (`ec=0` against `RESULT: 9 FAILURE(S)`). `full_audit.sh` still scores it FAIL through
  `has_failure`, so nothing is currently hidden. Pre-existing, out of scope, **not** fixed here.
* **The seven `nogui_tests` members were not run under X at all**, deliberately: they hang.
* **No `.sh` suite was run.** `full_audit.sh` globs `test_*.tcl` only; this item touched none.
* The `:0` repeat counts are 5–7 runs per suite, not a 30-run soak.

## 8. Audit

Full `tests/headless/full_audit.sh` on `:99` against the files being handed over, archived at
`doc/claude/merge5_loose_ends/audit_item02_2026-08-15.txt`. Diffed by test NAME and STATUS
against `doc/claude/batch_F/baseline_status_2026-08-15_postmerge5.txt` (314/17/0/0 of 331), whose
expected shape at this base is **316/15** because item 01 landed `test_ase_log_seam_0207` and
`test_select_at` FAIL→PASS.

```
SUMMARY: 316 pass  15 fail  0 crash/timeout  0 skip  (total 331)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
TREE:     1 appeared  0 vanished
TREEADD | ?? doc/claude/merge5_loose_ends/receipts/02-merge5-gui-zero-run.md
```

Row-by-row diff against the baseline, by name and status, in **both** directions — same 331
names on both sides, none added, none dropped:

```
test_ase_log_seam_0207: FAIL -> PASS
test_select_at:         FAIL -> PASS
```

**That is the whole delta, and both rows are item 01's landed change, not this item's.** The two
files this item edited (`test_cmdmode_descend_0201`, `test_altf5_ciw`) were PASS in the baseline
and are PASS here — a status diff cannot show what they gained, which is why §2's identical
`:0`/`:99` check counts and §5's drives carry that evidence instead. The one `TREEADD` is this
receipt, written while the audit was running. The 15 reds are the baseline's 17 minus item 01's
two, name for name: W7, the four libmgr environment reds, `test_ciw`/`test_selflog_output`
(mode/key-delivery), and the rest, all previously documented.

---

# 9. FIX ROUND (2026-08-15/16) — what review found, and what changed

Three reviewers ran the `:0` leg independently. They found **one blocker, one wrong debt
decision, and four accuracy defects in this receipt's own evidence**. Everything below is the
fix round's own measurement, on the user's real screen under the live gate (`GUI_GATE=1`
throughout; the forever grant was already armed and nothing was written to
`~/.claude/gui_test_gate/`). **Zero new checks were added by this round** — the check count of
every file it touched is unchanged. The evidence is red/green drives, not new assertions.

## 9.1 BLOCKER — `test_create_instance` CI15 was a `:0` race, and the original run missed it

The original `:0` pass recorded `test_create_instance` as `72 ok RESULT: ALL PASS`. That was
**one sample**. Repeated, the pre-fix file is **0 of 10 runs** on `:0`:

```
FAIL: CI15a precondition: .addlabel open, focus in the FORM, wire armed (=> focus= ui=65536 ui2=1)
FAIL: CI15a form-focused Escape aborted the arm (.addlabel)             (=> ui=65536 ui2=1)
FAIL: CI15b precondition: .addpin open, focus in the FORM, wire armed   (=> focus= ui=65536 ui2=1)
FAIL: CI15b form-focused Escape aborted the arm (.addpin)               (=> ui=65536 ui2=1)
```

`focus=` is **empty** — focus on nobody, neither the form nor `.drw`. The suite opened a
placement form and read `[focus]` after a single `update`, which processes only what the server
has already sent. This is class (a), WSLg event traffic, in a **merge-touched suite that was in
the driver's own list of nine** — exactly what this item was chartered to find.

**Fixed in the test** (`test_create_instance.tcl`, the `CI15` `foreach`): the single `update`
became a bounded 200×25 ms poll on the same `[focus] eq $wantfocus` the check asserts. The
precondition stays the assertion; nothing is forced.

Instrumenting the loop with its iteration count (1 iteration = one `update` + 25 ms):

| display | measured iterations to focus arrival |
|---|---|
| `:99` (Xvfb + openbox) | **0**, all three legs, every run — which is why `:99` never saw this |
| `:0` (WSLg), five runs | **0, 1, 3, 5, 76** (76 ≈ 1.9 s of real waiting) |
| `:0`, concurrent GUI batch | bare `update` sufficed in **2 runs of 8** |

## 9.2 The CI15 drives — both directions, same display state

| drive | what was broken | red? | restored green? |
|---|---|---|---|
| **CI15a/b preconditions (the poll itself)** | the change reverted to the pre-item HEAD file (md5 `77bcc6c710d8393463eba6cd40769145`) | **yes — 0/10 runs passed on `:0`** (detail captured for runs 7-10, CI15 red in all four), and a second control at `-n 6` where **all six** runs were red on CI15a/CI15b | **yes — the shipped file, `-n 10` and `-n 6` in the SAME display state: CI15 red in 0 runs.** Controls taken back-to-back with the reverted file so the compositor state is held constant |
| **CI15b precondition (does the poll MASK a real regression?)** | **PRODUCT**: `src/xschem.tcl:11360`, `focus $w.f.ename` in `addpin::open` commented out | **yes** — `FAIL: CI15b precondition: .addpin open, focus in the FORM, wire armed (=> focus=.addpin …)`, red **after the poll ran its full 5 s** | **yes** — restored from a byte-exact backup, md5 `5bb0c615505a1b14d92d3662034d3da7`, `git status src/xschem.tcl` clean, CI15b green |
| **FX0** (file re-touched this round, comment only) | `wm withdraw .` above the map-wait loop | **yes** — `FAIL: FX0 … (got 0 1 want 1 1)`, `RESULT: 5 FAILURE(S)` | **yes** — restored, `RESULT: ALL PASS` |

The second row is the one that matters: a poll that waits for the very thing it asserts could
easily have become a check that can no longer fail. It still fails, and it fails **loudly and
late** rather than being masked.

## 9.3 A speculative fix that was tried, measured, and REVERTED

The same treatment was applied to `esc14` (`focus -force .drw ; update`) to chase the
`CI14c/CI14d/CI14f/CI14g` reds. **It was wrong and was backed out**, and the reasoning is left
in the file as a comment so nobody re-applies it:

* `[focus]` reports the **form** (`.ciform` / `.addlabel`) even after `focus -force .drw`, so a
  5 s poll for `.drw` ran to its full timeout on **2 of the 3** `esc14` calls, changed no
  verdict, and added ~10 s per run.
* The Escape is **lost, not late**. Probing the *effect* — poll `ui_state` for 3 s after the
  `event generate` — gave `PROBE esc14 late-settle after 3000ms -> ui=65536`. Nothing arrives.
  **No wait can fix a lost event**, and a fix that cannot work must not ship.

`CI14*` is therefore the documented **bare `event generate` key-delivery** non-regression.
Note **the rate compounds**: the documented "~1 in 5" is per *call*, and this suite makes about
seven, so per-*run* redness is much higher and swings with compositor state — measured 0/8,
5/6, 1/6 and 5/6 on `:0` on one day with no code change between. Same lesson for §5's map-race
rate: 1-in-31 (quiet), 1-in-4 (cold launch), **6-in-8** (after a session of GUI testing, my own
8-launch probe: `.drw` at 1×1 in six, settling in 22–34 iterations).

**`X connection to :0 broken (explicit kill or server shutdown)`** is the answer to the
reviewer's "chase the `exit 1` NORESULTs": the WSLg Xwayland abort, documented, and it appeared
in `test_calc_skeleton` under the same load. It is not a suite killing the binary.

## 9.4 The debt, decided properly this time

The original clear rested on an **unstated narrowing** of the run set, which is the exact defect
the two-list rule exists to prevent. Sequence this round: **re-added first** (before any fixing,
so the ledger never lied), then cleared only after the evidence below.

The governing rule was genuinely open, so the crew made the ruling and **wrote it into
`doc/claude/specs/owed.md` as R4b** (R411–R414) rather than leaving it implicit:

* **R411** a debt's scope must be *derivable*, not asserted — `merge5-gui`'s is
  `git diff --name-only pre-open-pdk-merge-5 e7ae4d77 -- tests/headless/` minus `nogui_tests`.
  Re-derived independently this round: 24 touched, 7 `nogui`, **17 GUI-capable**.
* **R412** a suite outside that scope carrying its **own** debt cannot hold this one open, and
  must still be named. `test_calc_widgets` (R111, deterministic on `:0`) is **not** merge-touched
  and keeps its own standing debt.
* **R413** widening is allowed, narrowing after the fact is not.
* **R414** a documented WSLg non-regression does not block a clear if the receipt names it, names
  its mechanism, and shows a re-run.

Evidence for the clear: all **17** merge-touched GUI-capable suites green in a full `:0` pass
with modes matched (`--logdir` for the six, banners read for the three custom-banner suites —
`hi_descend` 24/24, `cadence_descend_newwin_ro` 21/21, `readonly_guard` 13/13, identical on both
displays); the CI15 defect found, fixed and sabotage-proved; `test_create_instance` **5/6** on a
repeat run with the single red being the documented lost-key flake.

| debt | decision | why |
|---|---|---|
| `merge5-gui` | **CLEARED** (after being re-added first) | the 17-suite scope runs clean on `:0`; the one real `:0` defect is fixed with a drive in both directions; residual is a documented non-regression, named with its mechanism |
| `test_calc_skeleton` | **STANDING** | issue 0416 — and it now records **two** `:0`-only modes (S11 and S21), not one |
| `test_calc_widgets` | **STANDING** | issue 0417; R111 still deterministic red on `:0` |
| `test_ase_window` | **STANDING** | W7, pre-existing on both displays |
| `test_gui_gate_revive` | **UNTOUCHED** | out of scope |
| any **look** debt | **UNTOUCHED** | none added, none cleared — all 7 still stand. Only the user clears a look |

## 9.5 Audit, re-run by the fix round

`tests/headless/full_audit.sh` on `:99` against the handed-over tree, archived at
`doc/claude/merge5_loose_ends/audit_item02_fixround_2026-08-16.txt`.

```
SUMMARY: 316 pass  15 fail  0 crash/timeout  0 skip  (total 331)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
TREE:     0 appeared  0 vanished
```

Row-by-row against `doc/claude/batch_F/baseline_status_2026-08-15_postmerge5.txt` (314/17/0/0),
same 331 names on both sides, none added, none dropped, **both directions**:

```
test_ase_log_seam_0207: FAIL -> PASS
test_select_at:         FAIL -> PASS
```

Both are **item 01's landed commit `22ecc20c`**, not this item. No other row moved in either
direction — in particular `test_create_instance` was PASS in the baseline and is PASS now, which
is exactly why the CI15 defect could hide: **`full_audit.sh` runs each suite once, on `:99`, and
neither repetition nor `:0` is part of it.** That is the general lesson of this item, and the
reason a `:0` debt is worth carrying at all.

## 9.6 What is still NOT verified, after the fix round

* **`test_create_instance` is 5/6 on `:0`, not 6/6.** The residual is `CI14*`, the documented
  bare-`event generate` key-delivery non-regression, proved here to be event *loss* (nothing
  after 3 s) rather than lateness. It is not fixable in the test and was deliberately not chased.
* **`:0` degrades across a session.** Every rate in §9 is state-dependent; the same suite and
  binary gave 8/8, 0/6, 5/6 and 1/6 on one day. Judge a `:0` change only by an A/B taken
  back-to-back, never against a number measured hours earlier.
* **The 7 `nogui_tests` members were still never run under X** — they hang, by design (0414).
* **`test_calc_widgets` R111 and `test_calc_skeleton` S11/S21 remain diagnosed, not fixed**
  (issues 0417 / 0416); both debts stand, and 0416 now records two `:0`-only modes, not one.
* **No C was built or changed.** `src/xschem.tcl` was sabotaged and restored byte-exact
  (md5 `5bb0c615505a1b14d92d3662034d3da7`, `git status` clean); the binary is untouched.
