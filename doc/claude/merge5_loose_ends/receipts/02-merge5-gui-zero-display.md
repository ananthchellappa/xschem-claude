# Item 02 — drain the `merge5-gui` owed suite debt (a `:0` run)

Closer's receipt. HEAD at start `22ecc20c` (item 01). **No product code changed, no behaviour shipped**: the deliverable is a
run on the user's real WSLg screen, its comparison against the dev display, three `:0`-only *test* races fixed, and the debt
decision. Verbatim per-suite logs and the full diagnosis of every case are in the evidence annex **`02-merge5-gui-zero-run.md`**
(same directory) — referenced by name from `test_cmdmode_descend_0201.tcl` and issues 0416/0417, so it keeps its path. `:99` =
the persistent dev display (Xvfb + openbox); `:0` = the user's real WSLg screen; every number below says which. Every run used
`GUI_GATE=1` through `run_suites.sh` / `gated_xschem.sh` under the pre-armed forever grant; nothing was written to
`~/.claude/gui_test_gate/`, no panel pressed or re-armed.

## 1. Files changed

`git diff --stat` — `git diff --cached --stat` was empty, nothing staged before this commit:
`doc/claude/specs/owed.md | 34 +`, `tests/headless/test_altf5_ciw.tcl | 34 +-`,
`tests/headless/test_cmdmode_descend_0201.tcl | 45 +`, `tests/headless/test_create_instance.tcl | 43 +-` —
**4 files changed, 149 insertions(+), 7 deletions(-)**. Committed alongside: this receipt, the annex, issues
`0416-…`/`0417-…`, three archived audits (`audit_item02_*.txt`). `LEDGER.md` was **not** touched — the driver owns it.

## 2. Decisions, and the evidence for each

**D1 — the run set was WIDENED beyond the brief's nine.** Scope re-derived twice independently: `git diff --name-only
pre-open-pdk-merge-5 e7ae4d77 -- tests/headless/` = 24 `test_*.tcl`, minus the 7 `nogui_tests` members (modal dialogs; they hang
under X — issue 0414) = **17 GUI-capable**, plus the 3 suites with their own debts = 20. It earned itself: two of the three real
`:0` reds are *outside* the brief's nine.

**D2 — the three `:0`-only reds in merge-touched suites are class (a), WSLg event traffic, fixed in the TEST** (the
`test_calc_skeleton` S12 pattern) — not chased through window managers, not treated as product bugs; the merged C is
byte-identical to the tip the user already eyeballed. (i) `test_cmdmode_descend_0201`: `.drw` still 1×1 / `ismapped 0` at script
start, so `zoom_full` fits the drawing into one pixel (zoom 1834 vs 1.83) and every click lands on the corner — 9 red checks
**and 80 that printed `ok:` against a canvas that was never there**; fixed with a bounded map wait plus one new assertion, FX0.
(ii) `test_altf5_ciw`: `wm state .ciw` reads `iconic` for 60/1100/2920 ms after the raise on `:0`, `normal` at 0 ms on `:99`;
fixed with a `wait_state` poll, 3 checks restated, none renumbered or deleted. (iii) `test_create_instance` CI15 — the blocker
review found: reported `ALL PASS` on `:0` from **one sample**, but repeated the pre-fix file is **0 of 10** with `focus=` empty,
a single `update` seeing only what the server already sent. Fixed with a bounded 200×25 ms poll on the same `[focus] eq
$wantfocus` the check asserts — the check stays the assertion, nothing is forced; `:99` needs 0 iterations every run (why the
dev display never saw it), `:0` needed 0, 1, 3, 5 and 76.

**D3 — a fix that could not work was measured and REVERTED.** The same poll on `esc14` timed out on 2 of 3 calls (`[focus]`
reports the *form*, not `.drw`), and an effect probe showed the Escape never arrives at all (`ui=65536` after 3000 ms): `CI14*`
is event **loss**, the documented bare-`event generate` non-regression, no wait fixes it, and the reasoning is left in the file
so nobody re-applies it.

**D4 — RULING, written into the spec.** What a debt's *scope* is, and what may block clearing it, was genuinely open — which is
why the first clear was wrong. `doc/claude/specs/owed.md` now carries **R4b (R411–R414)**: a scope must be derivable, not
asserted, and the receipt must print the command (R411); an out-of-scope suite carrying its own debt cannot hold this one open
but must still be named (R412); widening is allowed, post-hoc narrowing is not (R413); a documented WSLg non-regression does not
block a clear if named with its mechanism and a re-run — and the "~1 in 5" key-delivery rate is **per `event generate` call**,
so a suite making seven goes red far more often per run (R414).

**D5 — debts.** `merge5-gui` was **re-added first** (so the ledger never lied during the fix round) and **CLEARED** only after
the 17-suite scope ran clean on `:0` with modes matched. `test_ase_window` (W7: pre-existing, 1 failed / 168 passed on **both**
displays — not chased), `test_calc_skeleton` (0416) and `test_calc_widgets` (0417) **STAND**; `test_gui_gate_revive` untouched;
**all 7 look debts untouched**, none added, none cleared. S11/S21 and R111 were diagnosed, not fixed — those suites belong to
the Calculator batch and carry their own debts.

## 3. Tests, check counts, verbatim RESULT lines

Three files, **168 checks**, **exactly one new check** (FX0): `test_cmdmode_descend_0201` 89 → **90**; `test_altf5_ciw` **10**
unchanged; `test_create_instance` **68** unchanged.

| suite | `:99` | `:0` (real screen) |
|---|---|---|
| test_cmdmode_descend_0201 | 90 ok `RESULT: ALL PASS` | 90 ok `RESULT: ALL PASS` |
| test_altf5_ciw | 10 ok `RESULT: ALL PASS` | 10 ok `RESULT: ALL PASS` |
| test_create_instance | 72 ok `RESULT: ALL PASS` | 72 ok `RESULT: ALL PASS`; repeat `RESULT: 5/6 runs passed` |

Whole `:0` scope, verbatim batch lines: `RESULT: 5/6 runs passed` (logdir batch; the non-PASS is `NORESULT test_hi_descend (exit
0, custom banner)`, own banner `hi_descend headless: all checks passed`, 24/24 both displays) and `RESULT: 9/11 runs passed`
(nolog batch; the two non-PASS are the other custom-banner suites — `cadence_descend_newwin_ro headless: all checks passed`
21/21 and `READONLY_GUARD_TEST_PASS` 13/13, identical on both displays; `run_suites.sh` scores a custom banner `NORESULT` by
construction). **All 17 in-scope suites: total check counts identical on `:0` and `:99`** — but two corrections review forced on
the first round's wording: **ok**-counts match for 19 of 20, not 20 (`test_calc_widgets` is 244 ok on `:99` vs 243 ok + 1 FAIL
on `:0`), and a matching count is not by itself `:0` evidence — `test_audit_classifier` runs the same 50 checks under
`AUDIT_DISPLAY=none`, no X.

**Audit** (closer's own `:99` run, `GUI_GATE=1`, archived as `audit_item02_closer_2026-08-16.txt`): `SUMMARY: 316 pass 15 fail
0 crash/timeout  0 skip  (total 331)`, `WIREEDIT: PASS`, `SCRATCH:  0 leaked dir(s)`, `TREE: 1 appeared` — that one being
`TREEADD | ?? …/02-merge5-gui-zero-display.md`, this receipt, written while the audit ran. Row-by-row against
`baseline_status_2026-08-15_postmerge5.txt` (314/17/0/0), same 331 names, none added or dropped, **both directions**:
`test_ase_log_seam_0207: FAIL -> PASS`, `test_select_at: FAIL -> PASS` — item 01's landed commit `22ecc20c`, not this item. **No
other row moved either way.**

## 4. Sabotage table

| check | what was broken | red? | restored green? |
|---|---|---|---|
| **FX0** (the only new check) | `wm withdraw .` above the map wait, shipped file | **yes, both displays** — `FAIL: FX0 … (got 0 1 want 1 1)`, `RESULT: 5 FAILURE(S)`; collateral exactly the 4 focus-dependent DS7 rows, the other 84 tolerated an unmapped canvas, which is FX0's point | **yes**, byte-exact backup (never `git checkout`), `RESULT: ALL PASS`, 90 ok |
| `test_altf5_ciw` positive legs (2 restated) | **PRODUCT**: `return ;# SABOTAGE` above `raise_activate_toplevel .ciw`, `src/ciw.tcl:38` | **yes**, both named; the negative leg correctly stayed green | **yes**, md5 `6f500773…`, `git status` clean |
| `test_altf5_ciw` negative leg (1 restated) | **PRODUCT C + rebuild**: early return in `action_cmd_unbind`, `src/callback.c:6658` | **yes** — `FAIL - un-bound Alt-F5 no longer raises CIW` and nothing else, so the widened 5 s window still discriminates a leaked binding | **yes**, rebuilt byte-identical, md5 `95f4ebba…` |
| `test_create_instance` CI15a/b (6 checks; no new assertion) | the change reverted to the pre-item HEAD file (md5 `77bcc6c7…`) | **yes — 0/10 and 0/6 runs passed on `:0`**, CI15a+CI15b red in all six of the control | **yes** — shipped file, same display state back-to-back: CI15 red in 0 of 10 and 0 of 6 |
| `test_create_instance` CI15b — *does the poll mask a real failure?* | **PRODUCT**: `focus $w.f.ename` commented out in `addpin::open`, `src/xschem.tcl:11360` | **yes**, red **after** the poll ran its full 5 s — waiting for the condition did not make the assertion a rubber stamp | **yes**, md5 `5bb0c615…`, `git status src/xschem.tcl` clean |
| the map wait itself (run-only drive) | the pre-item `test_cmdmode_descend_0201` | **yes** — 3/6, 1/4 and 6/8 on `:0` depending on compositor state, with the `win=1x1 mapped=0` trace | **yes** — the `MS4/MS7b/MS8c/MS9c` sx/sy-collapse signature disappears; residual reds are the key-delivery flake |

**Unsabotaged, therefore not evidence:** the `wait_state` widening of the *negative* leg on its own. The false green it guards
against was **never reproduced** — the pre-item immediate read caught the neutered unbind 4 times out of 4 on `:0`. It hardens
against a measured mechanism (the 0–2920 ms lag), not an observed failure; test file and annex say so.

## 5. What was NOT verified

* **Only the 17-suite scope ran on `:0`**; the other ~300 audit suites have still only ever run on `:99`, and the 7
  `nogui_tests` members were never run under X at all — they hang, by design.
* **`:0` rates are not reproducible on demand, which invalidates cross-hour comparison.** The same file and binary gave 8/8,
  0/6, 5/6 and 1/6 in one day; the map race measured 1-in-31, 1-in-4 and 6-in-8; three reviewers disagreed by an order of
  magnitude and all were right — judge a `:0` change only by an A/B taken back-to-back. `test_create_instance` is **5/6 on
  `:0`**, not 6/6: residual `CI14*`, event loss, not fixable in the test.
* **Reviewer findings raised-but-not-confirmed / not-proven, carried forward:** nobody independently reproduced the 60/1100/2920
  ms `wm state` measurements; "all 17 green on `:0`" is unproven at n>1 (a reviewer saw `test_snap_bindkeys` red 1-in-3 on a
  bare `event generate`, green 8/8 on re-run, and two NORESULTs traced to `X connection to :0 broken`); the second window's
  `zoom_full` at `test_cmdmode_descend_0201.tcl:366` has no map wait and FX0 does not assert it; `wait_state`'s `incr t 20`
  makes its "5 s" a floor, not a ceiling (`AUDIT_TIMEOUT` is 300 s); whether the new poll can introduce a *new* flake could not
  be made to happen (8/8 on `:0`, 6/6, 2/2 on a WM-less `:77`); and whether 0416/0417's proposed oracles are right is the
  Calculator batch's call.
* **`test_cmdmode_descend_0201` exits 0 while reporting failures** (`ec=0` against `RESULT: 9 FAILURE(S)`); `full_audit.sh`
  still scores it FAIL via `has_failure`, so nothing is hidden today. Pre-existing, out of scope, not fixed. A reviewer also saw
  the binary **SIGSEGV** when its X connection died mid-startup; may deserve its own issue.
* **No eyeball is owed**: the payload is a run plus three harness-race fixes, and the merged C is byte-identical to
  `github/open_pdk`, which the user has already eyeballed. No `look` debt added, none cleared.
