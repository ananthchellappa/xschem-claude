# Item 06 — multi-select plot from Add Trace — LEDGER RECEIPT

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `3c7c993f`
(item 5). Date 2026-08-05. Written by the ledger stage from the implementer result
**and** the independent verifier result. The implementer's long-form receipt (committed
inside `7f8affec`) is preserved **verbatim** as the appendix at the bottom of this file
— nothing it said was dropped. Where the two disagree, §1-§10 wins.

---

## 1. Verdict

**DONE — ledger mark `[x]`.** A behaviour item (driver note (a)), not a pixel item: the
checks are competent to judge the whole deliverable and they do. **No eyeball is owed**
and no eyeball-queue row was added. Two things are still worth a real user's eye if one
is passing by — §10 — but neither gates the item.

What shipped: `wviewer::add_trace_ok` with an **empty** Expression now adds **one trace
per selected row, in listbox order**, each through the unchanged `wviewer::add_trace`.
A typed Expression still wins and still adds exactly one (the RPN path is byte-for-byte
unchanged). The `Name` field is **refused** for N > 1 with a verbatim contract string and
**applies at exactly N = 1**. The first error aborts the rest, the already-added traces
**stay** (the deliberate NON-rollback of driver note (f)), and the message reports how
far it got — with the count suffix appearing **only** when there really was a batch, so
a single pick's message is byte-identical to today's.

Verified **first time, no rejection**: the verifier returned `ok: true`,
`scopeClean: true`, with two report-only problems (§7), neither attributable to item 6.

**Committed, NOT pushed.**

| | |
|---|---|
| commit | `7f8affec` *"feat(wviewer): multi-select add from Add Trace"* — **one** commit, 3 files |
| parent / item-start HEAD | `3c7c993f` |
| scope | **2 source files + this receipt, no C** (settled decision 8), **no new test file** (decision 9), no settled decision overturned |
| scope, re-checked from git by the verifier | `git show --stat 7f8affec` = **exactly** `src/wave_viewer.tcl`, `tests/headless/test_wave_sigsearch.tcl`, `doc/claude/signal_browser_batch/receipts/06_receipt.md`. `git status` shows **only** the 5 driver-owned doc bookkeeping files that were dirty on arrival (`PLAN.md` + receipts 02-05); **zero** tracked diffs under `src/` or `tests/`. |
| build | Tcl only; `cd src && make` → *"Nothing to be done for 'all'."* Re-run by the verifier, same answer. |
| driver note (c) | **honoured byte-exactly**, re-verified by the verifier from the `git show` hunk headers: the test file has **only 3 hunks** — two comment-header blocks and the appended MS group. `gsl_frozen_ref`, `GSO_NAMES`, `GSO_PATS`, `GSO_BLOBS`, `GSPLAIN` provably untouched. |
| driver note (d) — the assert-on-your-own-selection trap | **closed two ways.** MS03's expectation is a **hand-written literal** never recomputed from `curselection`; MS01 separately pins the Tk premise that `curselection` answers in DISPLAY order (rows clicked 7, 3, 4 → `{3 4 7}`). The verifier read the new test code specifically for tautologies and **found none** — it confirmed the literal genuinely separates listbox order from click order. |
| driver note (e) — `at_wait_mapped` | correctly **NOT used**: no MS check reads a value a timeout could forge (no focus record, no `ismapped` assertion). Item 5's helper is left exactly as written and no second waiting idiom was invented. Verifier concurs. |
| driver note (f) — the non-rollback | implemented **as written and DECLARED** (D5), not silently rolled back; MS14 pins that the message says how far it got. Verifier confirms it is correctly scoped away from settled decision 11. |

## 2. Commits and files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | `add_trace_ok` rewritten (**+45 / -11**): read `gi`/`rpn`/`name` up front; `rpn ne {}` → the old RPN path untouched; empty Expression → snapshot the selection **by NAME** (item 5's AT14 lesson — a repopulate invalidates indices), no `lsort`; refuse `Name` when `[llength $names] > 1`; empty selection routed through `add_trace` with an empty rpn so the *"empty expression"* string keeps one owner; loop, abort on first error, suffix `" (added N of M, stopped at 'X')"` only when M > 1. Plus the stale comment at the `-selectmode extended` line, which **this item's own change made false** (D7). |
| `tests/headless/test_wave_sigsearch.tcl` | group **MS**, 19 checks (MS00-MS18) appended after the AT group. Non-appended edits: three header paragraphs (D8) and one stale number inside a paragraph D8 already rewrites (D9). |
| `doc/claude/signal_browser_batch/receipts/06_receipt.md` | the implementer long-form — now the appendix of this file. |
| `doc/claude/signal_browser_batch/PLAN.md` | ledger tick only, left **UNSTAGED** (driver's file; item-2 D6 / items 3-5 precedent). Not part of the commit. No eyeball-queue row for this item. |

**Anchors re-verified from source before use** (the PLAN's line numbers had drifted +604,
mostly by item 5 itself): `add_trace_ok` at `:7821` (plan said `:7217`), the target
`lindex $sel 0` at `:7830` — the same +9 from the proc head the plan's pair implies. The
scout's **two decoys were confirmed untouched**: `:7818` in `add_trace_pick` (the
double-click-to-Expression route, which is correct as it stands) and `:3886` in
`hilight_wave`.

**Blast radius, measured not asserted:** `test_wave_viewer`'s G11 / G12 / G12b are the
only end-to-end drivers of `add_trace_ok` outside this batch — G11 the single
`selection set 1` listbox path, G12 the RPN+Name path, G12b the error path. All three
pass, in **both** sessions (`ALL PASS (400 checks)`, and 3/3 on the verifier's soak).
That is the evidence the single-pick behaviour is unchanged.

## 3. Tests

| | |
|---|---|
| test file | `/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_sigsearch.tcl` (settled decision 9: one file, appended) |
| checks added | **19** — MS00-MS18, no gaps |
| checks total | **139 → 158** in the DISPLAY arm; **90 unchanged** in the `--nogui` arm (the MS group is Tk-only and self-skips, printing `SKIPPED: MS group (Tk/X arm only)`). 158 − 90 = **68** DISPLAY-arm-only, which is what the rewritten header paragraph now says. |
| runtime | **1.04 s → 1.35 s** whole file (implementer); verifier measured **1.27 s** — immaterial, and disclosed. |
| green | implementer: `ALL PASS (158)` DISPLAY / `ALL PASS (90)` `--nogui`. Verifier, independently: the same two numbers, plus a **6/6 flake soak** (`run_suites.sh -n 6`) all `ALL PASS (158)`. |
| build | `cd src && make` → *"Nothing to be done for 'all'"* (both sessions). |

**Three INDEPENDENT oracles watch the same batch** — the model's `vec` list (MS03), the
trace **colors** (MS05, distinct for free because each `add_trace` re-reads the graph and
calls `next_color`), and the graph rect's `node` text read back **off the canvas** after
`regenerate` (MS07). This is why the named sabotage (a) legitimately fails a superset;
see §4.

| check | what it pins |
|---|---|
| MS00 | fixture sanity: dialog opens on the real-canvas ctx, 9 vars, graph combobox = 1 |
| MS01 | `curselection` comes back ASCENDING — the PREMISE of "listbox order", pinned as a fact |
| MS02 | OK on 3 rows does not throw |
| **MS03** | **three traces on the selected graph, in LISTBOX order** — hand-written literal |
| MS04 | the other graph got nothing |
| MS05 | the three traces are in DISTINCT colors |
| MS06 | the dialog closes on a fully successful multi-add |
| MS07 | the graph rect's `node` text on the CANVAS carries all three |
| MS08 | a typed expression beats 3 selected rows: exactly one trace, name and expr applied |
| MS09 | the RPN path still closes the dialog |
| **MS10** | **Name + 2 rows is REFUSED: dialog up, NOTHING added on either graph** |
| MS11 | the refusal message is the contract string, VERBATIM |
| MS12 | Name + exactly ONE row still applies the Name — the boundary |
| MS13 | the first failure aborts the rest and KEEPS the earlier add |
| MS14 | the message reports how many were added before the failure (note (f)) |
| MS15 | no expression and no pick yields `add_trace`'s own message, exact |
| MS16 | a single failing pick keeps that message with NO count suffix — DIFFERENTIAL, against `add_trace`'s own return value |
| MS17 | the multi-add path creates NO raw vectors; only the RPN path did |
| MS18 | teardown leaves the main ctx empty and writable (rects = 0, readonly = 0) |

## 4. Sabotage table — implementer (7 injections)

Every injection was diffed against the item baseline before running, run, **reverted**,
and the clean file re-run green after each. `reverted` is **yes for all seven**; see the
process note below for *how*, which is itself a finding.

| # | injection | target | predicted | **MEASURED** | failedExactly | reverted |
|---|---|---|---|---|---|---|
| **(a) narrow** — PLAN-named | `set names [lrange $names 0 0]` after the refusal block | PLAN: MS03, the 3-trace check | {MS03,MS05,MS07,MS13,MS14} (scout) | **{MS03,MS05,MS07,MS13,MS14}** = 5 | **no** — an honest SUPERSET of the PLAN's single-check prediction, exactly the scout's pre-measured set | **yes** |
| **(a) wide** — PLAN-named | the whole empty-expression block reverts to `lindex $sel 0` + a single add | PLAN: MS03 | {MS03,MS05,MS07,MS10,MS11,MS13,MS14} (scout) | **same 7** | **no** — superset for the same structural reason, plus the refusal is carried away with the block so MS10/MS11 join | **yes** |
| **(b)** — PLAN-named | delete the `[llength $names] > 1 && $name ne {}` refusal block | the name+multi refusal | {MS10,MS11} | **{MS10,MS11}** = 2 | **YES** — matches both the PLAN's and the scout's prediction | **yes** |
| U1 (unplanned) | `set names [lsort $names]` — the plausible wrong-ORDER re-implementation | the listbox-order claim | {MS03,MS07,MS13,MS14} | **same 4** | **YES** | **yes** |
| U2 (unplanned) | refusal threshold `> 1` → `> 0` (refuse a single row too) | MS12, the N = 1 boundary | {MS12} | **{MS12}** alone | **YES** | **yes** |
| U3 (unplanned) | drop the `if {$n > 1}` guard, append the count suffix always | MS15/MS16, the unsuffixed single-pick message | {MS15,MS16} | **same 2** | **YES** | **yes** |
| U4 (unplanned) | move the refusal block AFTER the loop | MS10 | scout measured {MS10} under a WEAKER regexp MS11 and **demanded re-measurement** | **{MS10} alone**, re-measured under the strengthened exact-match MS11 | **YES** | **yes** |

**Why (a) fails five and that is not a defect.** The loop *is* what MS03, MS05, MS07,
MS13 and MS14 each observe, through different oracles; there is **no injection point that
severs the loop for one of them and not the others**. Coverage was **not** narrowed to
flatter the sabotage — ruling 17's corollary is satisfied by **widening**, the way item 5
recorded its E7. The verifier independently re-measured (a)-narrow and got the same 5,
`153 + 5 = 158` (nothing skipped), and read MS05/MS07 specifically to confirm they are
genuine extra oracles rather than weakened checks.

**Why U4's number survived the stronger MS11.** U4 does not corrupt the *message*: the
loop runs first, both picks succeed, then the refusal fires and writes the contract
string verbatim. So MS11 (which pins the MESSAGE) legitimately passes while MS10 (which
pins that NOTHING was added) legitimately fails. The exact match was kept — strictly
stronger than the regexp, and free here.

### ⚠ THE SABOTAGE FOUND A REAL TEST DEFECT, ON ITS FIRST RUN

Sabotage (a)-narrow's **first** measurement did not produce the predicted set. It produced
`MS03, MS05, MS07, MS13` and then:

```
UNEXPECTED ERROR: invalid command name ".wvms1.wvadd.err"
RESULT: 5 FAILED (149 passed)
```

**MS14 never ran, and neither did MS15-MS18.** A bare `$w.err cget -text` throws when a
sabotage flips a refusal or an abort into a SUCCESS and the dialog is destroyed; it threw
into the outer `catch … bigerr` and aborted the rest of the file. The fail **count** still
read 5 **by coincidence** (the abort itself scores one fail) — which is exactly how this
would have shipped. Repaired by routing every error-label read through:

```tcl
proc ms_err {w} {
  if {![winfo exists $w.err]} { return NO-DIALOG }
  return [$w.err cget -text]
}
```

so *"the dialog vanished"* becomes an **assertable value** instead of a crash. Four checks
(MS11, MS14, MS15, MS16) go through it; the comment at `ms_err` records the measurement so
nobody "simplifies" it back. Re-measured after the repair: the predicted 5, with
`153 + 5 = 158`. The verifier's own V1 (below) independently re-proves the repair works.

### ⚠ PROCESS DEVIATION worth carrying to every later item

The discipline says revert a sabotage with `git checkout -- <file>`. **That idiom presumes
a COMMITTED baseline**, and this item's implementation was not yet committed: the first use
reverted `src/wave_viewer.tcl` all the way to `3c7c993f` and **deleted the item**. It was
restored from the transcript, the clean 158 re-verified, and every later injection was
reverted from a **byte-exact backup of the ITEM state**, with `diff -q` confirming equality
after each restore. While an item is uncommitted, a *targeted* revert must mean "back to
the item", not "back to HEAD". (The verifier, working post-commit, used the same backup
discipline anyway and re-confirmed `git status --porcelain src/wave_viewer.tcl` empty plus
md5 `1656bbf2a046bc95bb47a98ffaa7a20d` after every one of its injections.)

## 5. The verifier's own unnamed sabotages, and their outcomes

Three of its own, plus independent re-measurement of two of the implementer's. All
reverted from a byte-exact backup with md5 re-confirmed and a clean `ALL PASS (158)` after
each.

| # | injection | **MEASURED** | outcome |
|---|---|---|---|
| **V1** | `return` → `break` in the loop's error branch — the abort still happens and the partial adds still survive, but the dialog is destroyed so **the report is never seen** | **{MS13,MS14,MS15,MS16}** = 4, `154 + 4 = 158` (nothing skipped) | **CAUGHT.** Also an independent proof that the `ms_err` repair works: the label reads `NO-DIALOG` as a value instead of throwing a file-wide abort. |
| **V2** | refusal message reworded to *"cannot use one Name for N traces"*, block otherwise intact | **{MS11}** ALONE | **CAUGHT** — the verbatim-contract-string claim has teeth and is not asserted against itself. |
| **V3** | aimed at an item requirement the implementer did **NOT** sabotage — *"a non-empty Expression entry still wins"*: guard changed to `$rpn ne {} && ![llength [$w.vars curselection]]` so a selection beats a typed expression | **{MS08,MS09,MS17}** = 3 | **CAUGHT.** This is the one that closes the coverage question the implementer's own table could not answer. |
| re-measure (b) | delete the refusal block | **{MS10,MS11}** = 2 | matches the receipt and the PLAN exactly |
| re-measure (a)-narrow | `set names [lrange $names 0 0]` | **{MS03,MS05,MS07,MS13,MS14}** = 5, `153 + 5 = 158` | byte-identical to the receipt's claim; superset explanation confirmed honest |

The verifier also read the new test code for **tautologies** and found none: MS03's
expectation genuinely separates listbox order from click order (rows selected 7, 3, 4 →
expected `{i(v1) v(x1.x2.net5) I(V2)}` = indices 3, 4, 7, whereas click order would give
`{I(V2) i(v1) v(x1.x2.net5)}`); MS01 is labelled as a premise; MS16 is differential
against `add_trace`'s own return; MS17's expectation derives from the fixture but its
*claim* is real — **V3 broke it**.

## 6. Non-baseline fails

**NONE, in either session.** Both audits were solo and gated, both valid before
interpretation.

| | implementer | verifier |
|---|---|---|
| `full_audit.sh` | exit 0 — **265 pass / 17 fail / 0 crash / 1 skip** (283) | **265 pass / 17 fail / 0 crash / 1 skip** (283) |
| `grep -c 'X connection to :0 broken'` | **0** | **0** |
| `revive FAILED -- suite continues UNGATED` (ruling 19) | **none** | **none** |
| `WIREEDIT` / `SCRATCH` | PASS / 0 leaked dir(s) | PASS / 0 leaked dir(s) |
| the 17 fails | 16 HARD baseline names, each on its recorded check (both documented clusters intact) + `test_altf5_ciw`, on the 22-name FLAKY list — re-run **3/3 PASS** | 15 HARD names + `test_remap` (FLAKY list) + **`test_launch_context`, on NEITHER list** — re-run **3/3 PASS**, see §7 |
| the 1 skip | `test_ase_dirty` — the flapping environmental self-skip; re-run solo **ALL PASS (41)** | `test_fluid_editing` — same phenomenon, different name |

**Every waveform test passed in both audits** — `test_wave_viewer`, `test_wave_sigsearch`,
`test_wave_trace_menu`, `test_wave_markers`, `test_wave_hilight`, `test_wave_snap`,
`test_graph_context`, `test_graph_box_zoom_xy`, `test_ase_plot` and the rest. Notably
`test_wave_trace_menu` (the ~50% flake re-listed by ruling 22) passed, so **no ruling-22
A/B was needed**: nothing failed that either session had cause to suspect itself for.

## 7. Verifier problems (both REPORT-ONLY) — carried forward to the driver

1. **⚠ ADD `test_launch_context` TO THE FLAKY LIST.** The verifier's audit produced a 17th
   fail the implementer's did not, and it is on **neither** the 16-name HARD list nor the
   22-name FLAKY list. It fails one check — *"main window has a usable size
   (geom=1x1+14+8)"*, i.e. the WSLg toplevel had not been given a real size yet. The test
   **never loads `src/wave_viewer.tcl`**, and `run_suites.sh -n 3` returns **3/3 PASS**.
   Not attributable to item 6; it is baseline bookkeeping the driver owns.
2. The environmental self-skip landed on `test_fluid_editing` (a HARD name) in the
   verifier's run rather than on `test_ase_dirty` — consistent with the baseline's
   documented *"the name flaps run to run"*, but it means the two 17-name fail sets differ
   in **composition** (verifier: 15 HARD + `test_remap` + `test_launch_context`;
   implementer: 16 HARD + `test_altf5_ciw`). **Neither composition implicates item 6.**
3. COSMETIC, recorded for completeness: the receipt reports the file runtime as
   1.04 s → 1.35 s; the verifier measured 1.27 s. No consequence.

## 8. Divergences from the PLAN — every one, with its reason

| # | divergence | why |
|---|---|---|
| **D1** | the MS fixture points `win_path` at `$SLMAIN` (`.drw`), **NOT** at item 5's `$SLVWP` | **FORCED, and the item's biggest finding.** Item 5's handoff said *"reuse the `at_open` fixture"*; the **dialog** half works, the **ADD** half does not. `$SLVWP` is `.x1.drw`, a **TAB** (`tabbed_interface 1`), so `winfo exists` is 0 and `add_trace` → `regenerate` → `viewport_rect` throws *`bad window path name ".x1.drw"`* at `winfo width $wp` — **after** `set_graphs` has already written the trace into the model. Isolated: `viewport_rect .x1.drw` rc = 1 vs `viewport_rect .drw` rc = 0. |
| **D2** | each scenario opens its **OWN** dialog, **and** every error-label read goes through a new `ms_err` helper | forced. The first half was planned; **the second half was found by sabotage (a)-narrow** — see §4's boxed finding. A bare `$w.err cget -text` throws when a sabotage destroys the dialog, and the fail count matched the prediction by coincidence anyway. |
| **D3** | the empty-selection case is routed through `add_trace` with an **empty** rpn | so *"empty expression - type one or pick a raw variable"* keeps **ONE owner**. MS15 pins it by exact match. |
| **D4** | the count suffix appears **only** when N > 1 | so a single pick's message stays byte-identical to today's. MS16 pins it **differentially** against `add_trace`'s own return; U3 measures that dropping the guard is caught. |
| **D5** | the deliberate **NON-rollback** is implemented as written (driver note (f)), not silently rolled back | the partial state is honest as long as the message says how far it got, which MS14 pins. A rollback would have to un-`regenerate` N times. Verifier confirms this is correctly scoped away from settled decision 11. |
| **D6** | `plot_signals` considered and **rejected** as the vehicle | its own comment at `:5296` says it must capture live view state separately because the strip count grows under it. This batch **never creates a strip**, so `add_trace` in a loop is correct and simpler. |
| **D7** | the comment at the `-selectmode extended` line is rewritten | this item makes *"add_trace_ok still reads `lindex $sel 0`"* **FALSE** — the same "my own change made a neighbouring comment wrong" repair item 5 declared as its D10. |
| **D8** | three **non-appended** header-paragraph edits in the test file | items 3/4/5 all did the same: (i) an `MS00-MS18` entry in the group index; (ii) *"BAR AND AT … 49 of 139"* → *"BAR, AT AND MS … 68 of 158"*; (iii) the PROCESS-STATE paragraph gains an MS entry. Driver note (c)'s five frozen names were not touched by a single line, proven by hunk headers. |
| **D9** | one stale number fixed inside a paragraph D8 already rewrites | it said *"this whole **119**-check suite"* (stale since item 3) and now reads 158. Leaving 119 beside the corrected 158 in the same block would be actively misleading. No behaviour, no check. |
| **D10** | the receipt is `receipts/06_receipt.md`, not the PLAN item's cited **`receipts/06_multiselect.md`** | the batch's `NN_receipt.md` convention, followed by items 2, 3, 4 and 5. Recorded by the ledger stage so nobody hunts for a missing file. |
| **R9** (named non-optimisation, not a divergence) | N traces = N `wviewer::regenerate` calls, i.e. N full clear+replace+redraw cycles | the item says to go through the existing `add_trace`, so this is **as specified**. On a 20-signal pick it is a real cost. Batching it (`set_graphs` once, regenerate once) is a separate change with its own risk surface and belongs to whoever owns viewer performance. |

**Explicitly NOT divergences, recorded because a later reader will wonder:** driver note
(e)'s `at_wait_mapped` was neither needed nor used (no MS check reads a timeout-forgeable
value); no third xschem context was created; `wviewer::add_trace` itself is not touched by
a single diff line.

## 9. Carried forward to item 7

- **ITEM 7 INHERITS AN EXTENDED `sl_main.raw`.** The MS group extends the MAIN context's
  raw from **2 vectors to 10** (the 7 `SLFIX` names + `db1` from the RPN check) and
  deliberately does **NOT** `raw new` — that would drop `wrong_ctx_var`, which SL12 still
  names in the same process. The raw stays extended and cannot be undone in place;
  **MS17 pins the exact 10**, so item 7 must expect 10, not 2.
- **The MS group is the first in this file that really DRAWS.** `regenerate` puts graph
  rects into the MAIN schematic and `with_edit` leaves it `readonly 1`. The teardown
  switches back to `$SLMAIN`, clears readonly, clears the drawing and clears the modify
  flag; **MS18 is the check that it really did** (rects = 0, readonly = 0). Item 7 gets a
  clean canvas, not a promise of one.
- **Do not re-inherit item 5's fixture blindly** — D1. The AT token's `win_path` is a TAB
  and any code path reaching `viewport_rect` will throw on it *after* mutating the model.
- Left defined for item 7: `ms_open`, `ms_field`, `ms_err`, and the globals `MSALL` and
  `MSREF`. Item 3's `gsl_frozen_ref` / `gso_*` names remain off limits (driver note (c)).

## 10. If a human looks at one thing

Nothing is **owed** — this is `[x]`, not `[E]`, and no eyeball-queue row was added. But if
someone is in front of the viewer anyway, in this order:

1. **The refusal fires from `<Return>` in the Name field.** Two bindings reach
   `add_trace_ok` (`bind $ee <Return>`, `bind $ne <Return>`), so the likeliest way a real
   user meets *"one Name cannot cover N traces …"* is typing a name, hitting Return, and
   having the dialog stay up. That is correct behaviour; the question is whether the
   message **reads well in the label's actual width**.
2. **The partial-add message.** Pick five signals where the third is bad and confirm
   `… (added 2 of 5, stopped at 'X')` is legible and that the two traces really are on the
   graph behind the still-open dialog.

---

# APPENDIX — implementer long-form receipt, preserved verbatim

Committed inside `7f8affec` as this file's original content. Kept whole; where it and
§1-§10 above disagree, §1-§10 wins.

---

# Item 06 — multi-select plot from Add Trace — IMPLEMENTER RECEIPT

Batch: `doc/claude/signal_browser_batch/PLAN.md`, item 6.
Branch `fluid-editing`. Parent commit `3c7c993f` (item 5).

---

## 1. Verdict

**`[x]`** — behaviour item, not a pixel item (driver note (a)), so the tests are
expected to judge it and they do.

`wviewer::add_trace_ok` with an EMPTY Expression now adds **one trace per selected
row, in listbox order**, each through the unchanged `wviewer::add_trace`. A typed
Expression still wins and still adds exactly one. The Name field is refused for
N > 1 and applies at exactly N = 1. The first error aborts the rest and the
already-added traces STAY — the deliberate NON-rollback of driver note (f) —
with the message reporting how far it got.

19 new checks (MS00-MS18), all green. Two named sabotages measured, both landing
on their predicted sets; four unnamed mutants measured on top, all four matching
the scout's predictions including the one it flagged as needing re-measurement.

---

## 2. Files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | `add_trace_ok` rewritten (+45/-11); the stale comment at the `-selectmode extended` line rewritten (D7) |
| `tests/headless/test_wave_sigsearch.tcl` | GROUP **MS**, 19 checks appended; three header paragraphs updated (D8) |
| `doc/claude/signal_browser_batch/receipts/06_receipt.md` | this file |

No other file changed. `cd src && make` → `Nothing to be done for 'all'` (Tcl only,
as settled decision 8 requires — no C).

### Anchors, re-verified from source before use

| plan cites | actual at 3c7c993f | ok |
|---|---|---|
| `add_trace_ok` at `:7217` | `src/wave_viewer.tcl:7821` | yes, drift +604 |
| `lindex $sel 0` at `:7226` | `:7830`, same +9 from the proc head | yes |
| decoy `lindex $sel 0` in `add_trace_pick` | `:7818` — **NOT touched**, it is the double-click-to-Expression route and is correct | confirmed |
| decoy in `hilight_wave` | `:3886` — not touched | confirmed |
| stale comment "still reads `lindex $sel 0`" | `:7718` — this item makes it FALSE, so it is rewritten (D7) | confirmed |

---

## 3. The implementation

Shape, in the order the code reads:

1. Read `gi`, `rpn`, `name` up front.
2. **`rpn ne {}` → the RPN path, byte-for-byte what it was.** One `add_trace`,
   one `xschem raw add`, one trace. `test_wave_viewer`'s G12 drives exactly this
   and still passes.
3. Empty Expression → snapshot the selection **by NAME**:
   `foreach i [$w.vars curselection] { lappend names [$w.vars get $i] }`.
   By name, never by index — item 5's AT14 lesson, since a repopulate invalidates
   indices. No sort: `curselection` answers ASCENDING, which IS listbox order, and
   adding an `lsort` would be a bug (mutant U1 measures that it would be caught).
4. `llength $names > 1 && $name ne {}` → refuse, message in `$w.err`, nothing added.
5. Empty selection → `set names [list {}]`, so the empty `rpn` reaches `add_trace`
   and its own `empty expression - type one or pick a raw variable` stays the single
   owner of that string (D3).
6. Loop; on the first error, append ` (added N of M, stopped at 'X')` **only when
   M > 1**, show it, return. Traces already added stay.

### Two properties worth recording

- **Colors are distinct for free.** Each `add_trace` re-reads the graph and calls
  `next_color`, so an N-row batch lands in N different colors (measured 3 distinct
  over a 3-row add, MS05). Nothing in this item cycles color itself.
- **All N land on the same `gi`** from `$w.graph get` — the batch never creates a
  strip, so `capture_live_view_state`'s 1:1 rect/model guard keeps holding on every
  iteration. This is why the item can go through `add_trace` at all, unlike
  `plot_signals`, whose comment at `:5296` explains why it must capture separately.

### A named, deliberate NON-optimisation (R9)

N traces means N `wviewer::regenerate` calls — N full clear+replace+redraw cycles.
The item says to go through the existing `add_trace`, so this is as specified. On a
20-signal pick it is a real cost. It is NOT optimised into a batch write here; that
is a separate change with its own risk surface (`set_graphs` once, regenerate once)
and it belongs to whoever owns viewer performance.

---

## 4. Tests — GROUP MS, 19 checks

`tests/headless/test_wave_sigsearch.tcl`, appended after the AT group. Settled
decision 9: items 1-7 all live in this one file.

**139 → 158 checks in the DISPLAY arm. `--nogui` stays at 90** (the MS group is
Tk-only and self-skips). Runtime **1.04 s → 1.35 s** whole-file.

Nothing existing was edited. `gsl_frozen_ref`, `GSO_NAMES`, `GSO_PATS`,
`GSO_BLOBS`, `GSPLAIN` were not touched by a single line (driver note (c)).

| check | what it pins |
|---|---|
| MS00 | fixture sanity: the dialog opens on the real-canvas ctx, 9 vars, graph combobox = 1 |
| MS01 | `curselection` comes back ASCENDING — the PREMISE of "listbox order", pinned as a fact |
| MS02 | OK on 3 rows does not throw |
| **MS03** | **three traces on the selected graph, in LISTBOX order** — literal expectation |
| MS04 | the other graph got nothing |
| MS05 | the three traces are in DISTINCT colors |
| MS06 | the dialog closes on a fully successful multi-add |
| MS07 | the graph rect's `node` text on the CANVAS carries all three |
| MS08 | a typed expression beats 3 selected rows: exactly one trace, name and expr applied |
| MS09 | the RPN path still closes the dialog |
| **MS10** | **Name + 2 rows is REFUSED: dialog up, NOTHING added on either graph** |
| MS11 | the refusal message is the contract string, VERBATIM |
| MS12 | Name + exactly ONE row still applies the Name — the boundary |
| MS13 | the first failure aborts the rest and KEEPS the earlier add |
| MS14 | the message reports how many were added before the failure (note (f)) |
| MS15 | no expression and no pick yields `add_trace`'s own message, exact |
| MS16 | a single failing pick keeps that message with NO count suffix — DIFFERENTIAL |
| MS17 | the multi-add path creates NO raw vectors; only the RPN path did |
| MS18 | teardown leaves the main ctx empty and writable |

### Driver note (d) — the trap it warned about, and how it is closed

The obvious trap is asserting on the selection list I set myself rather than on
what `add_trace_ok` actually read from the listbox. It is closed two ways:

- **MS03's expectation is a hand-written literal**, `[list i(v1) v(x1.x2.net5) I(V2)]`,
  never recomputed from `curselection`. A loop over `curselection` would assert the
  list against itself and pin nothing.
- **MS01 pins the premise separately.** The rows are selected in the order 7, 3, 4
  and `curselection` must answer `{3 4 7}`. So "listbox order ≠ click order" is a
  MEASURED fact in this file, not an assumption in my head. Mutant U1 (`lsort`)
  confirms the order claim has teeth: it fails 4 checks.

Three INDEPENDENT oracles observe the same batch — the model's `vec` list (MS03),
the trace colors (MS05), and the graph rect's `node` text read back off the CANVAS
after `regenerate` (MS07). That is why both named sabotages fail a superset; see §5.

### Driver note (e) — `at_wait_mapped`

Not needed and not used: **no MS check reads a value a timeout could forge.** There
is no focus record, no `ismapped` assertion, nothing whose truth depends on the
toplevel having mapped. `at_wait_mapped` is left exactly as item 5 wrote it, and no
second waiting idiom was invented. WSLg map latency shows up here only as wallclock.

---

## 5. Sabotage table

Every injection was diffed against the item baseline before running (the runner
prints the diff), confirmed to hold nothing but the sabotage, run, then reverted,
then the clean file re-run green.

| # | injection | predicted | **MEASURED** | verdict |
|---|---|---|---|---|
| **(a) narrow** | `set names [lrange $names 0 0]` after the refusal block | {MS03,MS05,MS07,MS13,MS14} | **{MS03,MS05,MS07,MS13,MS14}** — 5 | exact |
| **(a) wide** | whole block reverts to `lindex $sel 0` + single add | {MS03,MS05,MS07,MS10,MS11,MS13,MS14} | **same 7** | exact |
| **(b)** | delete the `[llength $names] > 1 && $name ne {}` refusal | {MS10,MS11} | **{MS10,MS11}** — 2 | exact, = the PLAN's own prediction |
| U1 | `set names [lsort $names]` (wrong ORDER) | {MS03,MS07,MS13,MS14} | **same 4** | exact |
| U2 | refusal threshold `> 1` → `> 0` | {MS12} | **{MS12}** alone | exact |
| U3 | drop the `if {$n > 1}` guard, suffix always | {MS15,MS16} | **same 2** | exact |
| U4 | move the refusal AFTER the loop | scout measured {MS10} with a WEAKER MS11; **required re-measurement** | **{MS10} alone** | re-measured, holds |

### U4 — the re-measurement the scout demanded, and why the number survived

The scout measured U4 with MS11 as `regexp {2}` and warned that strengthening MS11
to an exact match might change the prediction to {MS10, MS11}. **Re-measured under
the exact match: still {MS10} alone.** The reason is that U4 does not corrupt the
*message* — the loop runs first, both picks succeed, then the refusal fires and
writes the contract string verbatim. So MS11 (which pins the MESSAGE) legitimately
passes and MS10 (which pins that NOTHING was added) legitimately fails. The two
checks are pinning different things and U4 only breaks one of them. The exact match
is kept: it is strictly stronger than the regexp and it costs nothing here.

### Both named sabotages fail a SUPERSET, and that is structural

Sabotage (a) is predicted by the PLAN to fail "the 3-trace check". It fails five.
This is not a test defect and MS05/MS07 were NOT weakened to manufacture a
single-target result (ruling 17 forbids narrowing coverage to flatter a sabotage).
The loop IS what MS03, MS05, MS07, MS13 and MS14 each observe, through five
different oracles; there is no injection point that severs the loop for one of them
and not the others. Recorded the way item 5 recorded its E7.

Sabotage (b) DOES hit exactly its predicted 2. The refusal block is genuinely
isolated, and only MS10/MS11 look at it.

### ⚠ THE SABOTAGE FOUND A TEST DEFECT, ON ITS FIRST RUN

Sabotage (a)-narrow's first measurement did **not** produce the predicted set. It
produced `MS03, MS05, MS07, MS13` and then:

```
UNEXPECTED ERROR: invalid command name ".wvms1.wvadd.err"
RESULT: 5 FAILED (149 passed)
```

**MS14 never ran, and neither did MS15-MS18.** MS14 read `$msw.err cget -text`
bare. Under that sabotage scenario E's batch is truncated to one name, which
SUCCEEDS, so the dialog is DESTROYED — and the bare `cget` threw into the outer
`catch ... bigerr` and aborted the rest of the file. The count coincidentally read
5 because the abort itself scores one fail, which is exactly the kind of
coincidence that would have let this ship.

This is D2's other half. Item 5 and the scout both got the "each scenario opens its
own dialog" half right; nobody had noticed that reading the error LABEL is the same
hazard one line later. Fixed by routing **every** error-label read through:

```tcl
proc ms_err {w} {
  if {![winfo exists $w.err]} { return NO-DIALOG }
  return [$w.err cget -text]
}
```

so "the dialog vanished" becomes an **assertable value** rather than a crash. Four
checks (MS11, MS14, MS15, MS16) now go through it. Re-measured after the repair:
sabotage (a)-narrow gives the predicted `{MS03,MS05,MS07,MS13,MS14}` with
`153 passed + 5 failed = 158`, i.e. nothing was skipped. The comment at `ms_err`
records the measurement so nobody "simplifies" it back.

### One process note on reverting sabotages

The discipline says revert with `git checkout -- <file>`. **That idiom presumes a
committed baseline, and this item's implementation was not yet committed** — the
first time I used it, it reverted `src/wave_viewer.tcl` all the way to `3c7c993f`
and deleted the item. It was restored from the transcript, the clean 158 re-verified,
and every later injection was reverted from a byte-exact backup of the item state
(`diff -q` confirms equality after each restore) instead. Worth carrying: while an
item is uncommitted, a *targeted* revert means "back to the item", not "back to HEAD".

---

## 6. Runs

| run | result |
|---|---|
| `cd src && make` | `Nothing to be done for 'all'` |
| `test_wave_sigsearch` DISPLAY arm | **ALL PASS (158 checks)**, 1.35 s |
| `test_wave_sigsearch` `--nogui` arm | **ALL PASS (90 checks)**, MS/AT/BAR banners printed |
| `run_suites.sh test_wave_viewer` (R6 guard) | **ALL PASS (400 checks)** — G11/G12/G12b intact |
| full `full_audit.sh`, solo, gated | see §7 |

`test_wave_viewer`'s G11/G12/G12b are the only end-to-end drivers of `add_trace_ok`
outside this batch. G11 is the single-`selection set 1` listbox path, G12 the
RPN+Name path, G12b the error path. All three still pass, which is the evidence
that the single-pick behaviour is byte-identical.

---

## 7. Audit

Solo, gated, `tests/headless/full_audit.sh`, exit **0**:

```
SUMMARY: 265 pass  17 fail  0 crash/timeout  1 skip  (total 283)
WIREEDIT: PASS
SCRATCH:  0 leaked dir(s)
```

Validity checks BEFORE interpreting it:
`grep -c 'X connection to :0 broken'` = **0**; no `revive FAILED -- suite continues
UNGATED` (ruling 19); `SCRATCH: 0 leaked dir(s)`; `WIREEDIT: PASS`.

**The 17 fails are the 16 HARD baseline names, plus one FLAKY name.** No new name,
and no HARD name failed on a different check than the PLAN's Baseline block records
— the two documented clusters are intact and unchanged in shape:

- cluster (a), ACTION-LOG / SELF-LOG: `test_ase_log_seam_0207`, `test_select_at`,
  `test_selflog_output`, `test_phase3_mints`, `test_ciw` — all on
  `action log open` / `logs <cmd>` shaped checks.
- cluster (b), the three PDK libmgr tests: each on its one
  `library_list = exactly the N intended libs` check, with the extras
  `{SANDBOX TEST …}` from the USER-LEVEL `/home/qflow/.xschem/library.defs`.
- the rest at their recorded checks: `test_ase_window` W7, `test_fluid_editing` FE8,
  `test_rotate_stretch_short_0104` rot180-ip, `test_reopen_readonly` R10,
  `test_lib_manager_gui` GUI8/GUI9, `test_lib_manager_locate` LM-LOC3,
  `test_lib_sweep` P1-P4, and `test_cadence_drag` (RE-ANCHORED, any failure is
  baseline by the stated exception).

The 17th, **`test_altf5_ciw`, is on the 22-name FLAKY list. Re-run 3x: 3/3 PASS.**
Cleared.

The one SKIP is **`test_ase_dirty`** — re-run solo: **ALL PASS (41 checks)**. This is
the "environmental self-skip whose NAME FLAPS run to run" the baseline documents; the
clean re-baseline run had exactly one such skip too (`test_alt_transform_group_0116`,
266/16/1). Same count, different name, same nature.

**Every waveform test passed**, including the two whose failure would most implicate
this item: `test_wave_viewer` (the G11/G12/G12b guard) and `test_wave_sigsearch` (the
item's own file). Notably `test_wave_trace_menu` — the ~50% flake ruling 22
re-listed — also passed here, so no ruling-22 A/B was needed: nothing failed that I
had cause to suspect myself for. Had one, the decisive evidence would have been an
A/B with `src/wave_viewer.tcl` reverted, not a re-run count.

---

## 8. Divergences — DECLARED

| # | divergence | why |
|---|---|---|
| **D1** | the MS fixture points `win_path` at `$SLMAIN` (`.drw`), NOT the AT group's `$SLVWP` | forced, and it is the item's biggest finding. `$SLVWP` is `.x1.drw`, a **TAB** (`tabbed_interface` 1), so `winfo exists` is 0 and `add_trace` → `regenerate` → `viewport_rect` throws `bad window path name ".x1.drw"` at `winfo width $wp` — **after** `set_graphs` has already written the trace. The dialog half of item 5's handoff works; the ADD half does not. Isolated: `viewport_rect .x1.drw` rc=1 vs `viewport_rect .drw` rc=0 |
| **D2** | each scenario opens its OWN dialog, **and every error-label read goes through `ms_err`** | forced; the second half was found by a sabotage, see §5 |
| **D3** | the empty-selection case is routed through `add_trace` with an empty rpn | so the "empty expression" string has ONE owner; MS15 pins it |
| **D4** | the count suffix appears only when N > 1 | so a single pick's message is byte-identical to today's; MS16 pins it differentially, U3 measures that dropping the guard is caught |
| **D5** | deliberate NON-rollback, per driver note (f) | stated, not silently rolled back. I agree with the ruling: a rollback would have to un-`regenerate` N times and the partial state is honest as long as the message says how far it got, which MS14 pins |
| **D6** | `plot_signals` considered and rejected as the vehicle | its own comment at `:5296` says it must capture live view state separately because the strip count grows under it. This batch never creates a strip, so `add_trace` in a loop is correct and simpler |
| **D7** | the comment at the `-selectmode extended` line is rewritten | this item makes "add_trace_ok still reads `lindex $sel 0`" FALSE. Same repair item 5 declared as its D10 |
| **D8** | three non-appended header-paragraph edits | (i) an `MS00-MS18` entry in the group index; (ii) "BAR **AND AT** … 49 of 139" → "BAR, AT **AND MS** … 68 of 158"; (iii) the PROCESS-STATE paragraph gains an MS entry. Items 3/4/5 all did the same |
| **D9** | one number fixed in a paragraph D8 already rewrites | that paragraph said "this whole **119**-check suite", stale since item 3. Leaving 119 beside my corrected 158 in the same block would be actively misleading, so it now reads 158. No behaviour, no check |

---

## 9. Carried forward

- **ITEM 7 INHERITS AN EXTENDED `sl_main.raw`.** The MS group extends the MAIN
  context's raw from 2 vectors to **10** — the 7 `SLFIX` names plus `db1` from the
  RPN check. It deliberately does NOT `raw new` (that would drop `wrong_ctx_var`,
  which SL12 still names in the same process). The raw stays extended; it cannot be
  undone in place. MS17 is the check that pins the exact 10.
- The MS group is the **first in this file that really DRAWS**. `regenerate` puts
  graph rects into the MAIN schematic and `with_edit` leaves it `readonly 1`. The
  teardown switches back to `$SLMAIN`, clears readonly, clears the drawing and clears
  the modify flag; **MS18 is the check that it really did** (rects=0, readonly=0).
  Item 7 gets a clean canvas, not a promise of one.
- Left defined for item 7: `ms_open`, `ms_field`, `ms_err`, and the globals `MSALL`
  and `MSREF`. Items 3's `gsl_frozen_ref`/`gso_*` names are still off limits.
- No third xschem context was created.

---

## 10. EYEBALL — what a human should look at (not owed as a gate, this is `[x]`)

Behaviour, so the checks judge it. But two things are worth a real user's eye:

1. **R8 — the refusal fires from `<Return>` in the Name field.** Two bindings reach
   `add_trace_ok`: `bind $ee <Return>` and `bind $ne <Return>`. So the most likely way
   a real user meets `one Name cannot cover N traces …` is typing a name, hitting
   Return, and having the dialog stay up. That is correct, and the message says what
   to do ("clear the Name field, or select a single row"). Worth confirming it reads
   well in the label's actual width.
2. **The partial-add message.** Pick five signals where the third is bad and confirm
   `… (added 2 of 5, stopped at 'X')` is legible and that the two traces really are on
   the graph behind the still-open dialog.
