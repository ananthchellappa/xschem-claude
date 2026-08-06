# Item 05 — searchbar into `add_trace_dialog` — LEDGER RECEIPT

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `51291535`.
Date 2026-08-05. Written by the ledger stage from the implementer result **and** the
independent verifier result, after one rejection and a fixup round. The implementer's
long-form receipt (committed inside `3c7c993f`) is preserved **verbatim** as the appendix
at the bottom of this file — nothing it said was dropped. Where the two disagree,
§1-§10 wins.

---

## 1. Verdict

**DONE-PIXEL — ledger mark `[E]`, NOT `[x]`.** The deliverable is visible UI that no
headless check can judge. The checks pin the model, the four Tk routes, the grid
arithmetic and (now) Tk's focus record; they cannot judge width, spacing or a visible
caret. **The eyeball is OWED, not waived** — appendix §7, six points, with **WIDTH** the
risk the PLAN never named.

Verified after a **REJECTION and a fixup round**. The verifier's first pass returned one
**blocker** — AT18 was a *shipped flake*, 3 fails in 22 solo runs — plus four reports.
The blocker was **accepted in full and repaired by WIDENING** (§10 of the appendix); the
re-verification returned `ok: true`, `scopeClean: true`. The second verifier did not take
the repair on trust: it re-measured the mechanism **on the real dialog rather than on a
probe**, ran **115 valid solo runs** of the suite (including 43 under 2- and 3-way
parallel load) with **zero AT18 fails**, wrote **five of its own unnamed sabotages**
(all single-target, one of them aimed at the repair's anti-masquerade term and one a
subtle re-implementation rather than a deletion), ran its own solo gated 283-test audit,
and ran a **controlled A/B with the item's source reverted** to dispose of the one
non-baseline name both sessions saw.

**Committed, NOT pushed.**

| | |
|---|---|
| commit | `3c7c993f` *"feat(wviewer): searchbar in the Add Trace dialog"* — **one** commit, 3 files |
| parent / item-start HEAD | `51291535` |
| why one commit, not a fixup pair | the item had **never been committed** at the time of the first verification (that was verifier finding 4), so there was no base to fix up. Item 4's two-commit shape does not apply. |
| scope | **2 source files + this receipt, no C** (settled decision 8), **no new test file** (decision 9), no settled decision overturned |
| scope, re-checked from git by the verifier | `git show --stat 3c7c993f` = **exactly** `src/wave_viewer.tcl`, `tests/headless/test_wave_sigsearch.tcl`, `doc/claude/signal_browser_batch/receipts/05_receipt.md`. `git diff --name-only` on the working tree shows **only** the four driver-owned files that were dirty on arrival — nothing else under `src/` or `tests/`. |
| the fixup is test-file-only, proven not asserted | `md5sum src/wave_viewer.tcl` = **`987360a53e783cde4cfe13b483a433bb`** — the value the FIRST verifier recorded, re-checked by the second. The source the first verifier statically audited is byte-identical to what shipped. |
| driver note (d) | **honoured byte-exactly**, re-verified from `git show` by the verifier: **zero** `+`/`-` lines touch `gsl_frozen_ref`, `GSO_NAMES`, `GSO_PATS`, `GSO_BLOBS` or `GSPLAIN`; the only deleted lines in the whole test file are the **six** declared header lines. |
| item 4's carried-forward **V-U2** | **CLOSED.** `AT21` pins the throwing-consumer -> `searchbar_error` path (the gap item 4's verifier found and could not close, because item 4 shipped with no consumer) with an anti-vacuity pre-read. Verified statically by the verifier. |

## 2. Commits and files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | **+98 / -10.** Four planned edit sites — `variable atdsigs` in the `namespace eval wviewer` block (keyed by **session token**, because the dialog is a per-window singleton, unlike item 4's path-keyed `sbcfg`); the bar at grid row 4 in `add_trace_dialog` with rows renumbered 3-7 **and no hole**, inventory via `wviewer::signal_list`, `-selectmode extended`, the `<Destroy>` bind; the `add_trace_filter` consumer callback (every exit a guard — it rides `searchbar_fire`, which rides `<KeyRelease>`, so it must not throw); `add_trace_forget` with the mandatory `%W` guard. Plus two comment repairs made necessary by this item's own change (D10). |
| `tests/headless/test_wave_sigsearch.tcl` | group **AT**, 20 checks, appended after the BAR group. Non-appended edits: the header paragraph (D9) and, in the fixup round, the header's AT paragraph + the new `at_wait_mapped` helper + AT18 itself. |
| `doc/claude/signal_browser_batch/receipts/05_receipt.md` | the implementer long-form — now the appendix of this file. |
| `doc/claude/signal_browser_batch/PLAN.md` | ledger tick + eyeball-queue row only, left **UNSTAGED** (driver's file; item-2 D6 / item-3 D9 / item-4 precedent). Not part of the commit. |

**Blast radius, measured not asserted:** `add_trace_filter` / `add_trace_forget` have zero
hits outside `src/wave_viewer.tcl`; `atdsigs` appears elsewhere only in the AT group's own
assertions. The one production caller of `add_trace_dialog` is the Graph menu's
*Add Trace…* entry; the one out-of-batch test caller is `test_wave_viewer.tcl` (§3, green).
The verifier's hunk-header check confirms every source hunk lands in the `namespace eval
wviewer` block, the item-4 comment section, `add_trace_dialog`, or the three appended
procs — **`wviewer::add_trace` is not touched by a single diff line**, which is what makes
the two wave suites that reference it inert to this item.

## 3. Tests

| | |
|---|---|
| test file | `/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_sigsearch.tcl` (settled decision 9: one file, appended) |
| checks added | **20** — AT01-AT04, AT07-AT14, AT16-AT23. **There is no AT05, AT06 or AT15**: those names were never written, nothing was deleted; the gap is inherited from the PLAN's own numbering and is called out in the file header so no maintainer hunts for removals. |
| checks total | **119 -> 139** in the DISPLAY arm; **90** unchanged in the `--nogui` arm |
| the fixup changed the count by **zero** | 139 before, 139 after. AT18 was **widened in place** — not split, not deleted. No check was removed at any point in this item. |
| runtime | **1.86 s** DISPLAY (was 0.73 s), **0.37 s** `--nogui`. The map wait adds ~10 ms in the common case and up to **+3.5 s** on the ~1-in-8 runs where the WM maps late. |
| build | Tcl-only; `cd src && make` -> *"Nothing to be done for 'all'."* |
| green | implementer: `ALL PASS (139)` DISPLAY / `ALL PASS (90)` `--nogui`, plus a **25/25 instrumented soak**. Verifier, independently: `ALL PASS (139)` on every clean run, `ALL PASS (90)` `--nogui` (confirming the receipt's count), and **115 valid solo runs with 0 AT18 fails** — `run_suites.sh -n 40` (40/40), 30 instrumented `gated_xschem` runs (30/30), 16 under 2-way load, 27 valid under 3-way load (3 further runs **voided** by `X connection to :0 broken`, and disclosed as void rather than counted), plus 2 final clean runs. |
| cross-file regression guard | `run_suites.sh test_wave_viewer` -> **ALL PASS (400 checks)**, run by BOTH sessions. This is the file that carries the *"the Name entry still WORKS"* half of the PLAN's regression clause: G11/G12/G12b drive `add_trace_dialog` -> `add_trace_ok` end to end including `$w.name insert 0 db1`, and G11's *"listbox count == raw vars"* now depends on item 5's changed population path. |

**The blocker, and why the repair is not a wait-until-green loop.** AT18 read
`focus -lastfor $atw` behind a single `update`. A brand-new toplevel is frequently still
**unmapped** at that point, so Tk has not applied the `focus $ee` request yet and the
record still answers with the toplevel. Both sessions measured that **Tk does not discard
the request — it re-applies it at MAP time**, which is the fact that made *widening*
available instead of the deletion ruling 17 would otherwise have forced. `at_wait_mapped`
polls `winfo ismapped` (15 s budget = 4.3x the worst measured map, an eighth of the
audit's per-test timeout), and AT18 asserts the pair
`[list [winfo ismapped $atw] [focus -lastfor $atw]]` == `[list 1 $atw.expr]`. Three
deliberate properties: it polls the **precondition**, never the asserted value; `ismapped`
is **in the tuple**, so a budget expiry prints `{0 …}` ("never mapped") and can never be
confused with a focus theft (`{1 …wvsearch.pat}`); and it is **not a self-skip** — item 4's
BAR25 lesson says a check whose only oracle is *"did the thing happen"* must fail, not skip.

**The mechanism was reproduced twice, independently, and once on the shipping fixture.**
The implementer's standalone Tk probe: 12/12 unmapped-and-unsettled immediately after
`focus`, 3 of 12 still unmapped after one `update`, **12/12 correct after a bounded
`ismapped` poll — including all three late-mapping iterations.** The verifier went one
better and instrumented the *real* dialog: **1 of 30 idle runs was still unmapped after the
bare `update` and read `focus -lastfor` = `.wvat1.wvadd` — the first verifier's exact
failure value** — and the bounded wait took **2255 ms**, after which it read
`.wvat1.wvadd.expr`. That single run is a direct demonstration that the old assertion
would have failed and the new one recovers. Instrumentation reverted, file md5 verified.

## 4. Sabotage table — round 1 (implementer, 9 injections, uncommitted tree)

Every injection `diff`-confirmed to be the sabotage and nothing else **before** the run;
every revert from a **byte-exact snapshot** with md5 re-verified (item 3's D5 / item 4's
D6 — the item was still uncommitted, so `git checkout --` would have destroyed the item
along with the sabotage), clean green re-run at the end in **both** arms.

| # | injection | predicted | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| **NAMED (a)** | delete the `keep` selection-snapshot loop in `add_trace_filter` | AT14 | **AT14 alone**, 1 FAILED / 138 passed | **yes** | **yes** (md5 OK) |
| **NAMED (b)** | delete the Name row **pair** (`dialog_row … name` AND `bind $ne <Return>`) | AT01 | **AT01 alone**, got `{1 1 1 1 0 0 1 1 1 1 1}` | **yes** | **yes** |
| **E1** | delete `$w.vars configure -selectmode extended` | AT17 | **AT17 alone**, got `browse` | **yes** | **yes** |
| **E2** | drop the `%W ne $w` guard in `add_trace_forget` | AT20 | **AT20 alone** — *but on ONE half only on the first injection; see below* | **yes** | **yes** |
| **E3** | replace `wviewer::searchbar_error $w $e` with a comment (item 4's verifier U2, verbatim) | AT21 | **AT21 alone**, got `{{} {}}` | **yes** | **yes** |
| **E4** | drop the `if {[lindex $r 0] ne {ok}} return` guard | AT11 | **AT11 alone** — the got value shows the mechanism exactly: the error string became the sole listbox row | **yes** | **yes** |
| **E5** | `focus $sb.pat` after `focus $ee` (the bar steals focus) | AT18 | **AT18 alone** | **yes** | **yes** |
| **E6** | swap the searchbar's and `$w.vars`' grid rows | AT02 | **AT02 alone**, got `{3 5 4 6 7}` | **yes** | **yes** |
| **E7** | feed `sig_bare`-stripped names to `sig_match` | AT12 | **8 FAILED** — AT07-AT09, AT11-AT14, AT20 | **NO — honest superset** | **yes** |

**E7 — the PLAN's prediction is measurably wrong, and the truth is stronger.** The plan
predicted *"AT12 exactly"*. The reason it fails eight is structural, not a test defect:
**the filter's output IS the listbox content**, so stripping the inventory changes
everything displayed, not merely what the type dropdown selects. There is no injection
point that isolates AT12 without moving the violation into item 1's `sig_match`
(out of scope). Recorded as an **honest superset** — the disposition item 4 gave its u2
and u8 — and the consequence is a stronger result than planned: **settled decision 2 is
load-bearing for the entire Add Trace surface, not just the type dropdown.** AT12 remains
the named decision-2 witness and is among the eight.

**E2 exposed a vacuous half, which was WIDENED rather than explained away.** On its first
injection E2 failed AT20 on one half only: AT14 leaves the listbox already showing the
`v(*)` set, so a filter that bails out on a missing cache leaves *exactly the expected
content* behind — the *"and the filter still works"* half had no teeth. Per **ruling 17's
corollary** the check was widened (reset to the full list, record it, then destroy the
child), E2 re-injected, and it now fails on **both** halves — the cache flag *and* a stale
8-row list. The first measurement is recorded because it is the honest one.

## 5. Sabotage table — fixup round (implementer, 4 injections on the committed 139-check file)

The source is byte-identical across the fixup, so only the checks changed; both NAMED
sabotages were re-run to prove the repair did not **soften** them.

| # | injection | predicted | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| **S-AT18 (new this round)** | delete `focus $ee` from `add_trace_dialog` — sever the very route the repaired AT18 claims | AT18 | **AT18 alone**, 1 FAILED / 138 passed, got `{1 .wvat1.wvadd}`. The leading `1` is the new `ismapped` element: the wait worked and the assertion failed on the **focus record**, not on a timeout. | **yes** | **yes** (md5 OK) |
| **E5 (re-run against the repaired check)** | `focus $sb.pat` after `focus $ee` | AT18 | **AT18 alone**, got `{1 .wvat1.wvadd.wvsearch.pat}` | **yes** | **yes** (md5 OK) |
| **NAMED (a) (re-run)** | delete the `keep` snapshot loop | AT14 | **AT14 alone**, got `{{1 3 4} {} {}}` | **yes** | **yes** (md5 OK) |
| **NAMED (b) (re-run)** | delete the Name row pair | AT01 | **AT01 alone**, got `{1 1 1 1 0 0 1 1 1 1 1}` | **yes** | **yes** (md5 OK) |

**S-AT18 is the direction round 1 lacked.** E5 proved the bar *cannot steal* the focus;
nothing proved the dialog *still gives* it. Both directions are pinned now, and both `got`
values carry `ismapped 1` — the widened wait visibly working rather than papering over.

## 6. The verifier's own unnamed sabotages, and their outcomes

Five, none of them on any implementer list, each `git diff`-confirmed as the only change,
each reverted with `git checkout --` (the item was committed by then) and md5-verified.
**All five failed EXACTLY one check.**

| # | sabotage | outcome |
|---|---|---|
| **U1 — on the repaired check itself** | delete `focus $ee` from `add_trace_dialog` | **CAUGHT. AT18 alone, 3/3 runs, 1 FAILED / 138 passed**, got `{1 .wvat1.wvadd}` — **deterministic**, and with `ismapped 1`, which is the verifier's own proof that the wait is a precondition poll and not a wait-until-green loop. |
| **U2 — aimed at the anti-masquerade claim itself** | `wm withdraw $atw` + budget cut to 20 iterations, i.e. force the budget to expire | **CAUGHT. AT18 alone**, got `{0 .wvat1.wvadd.expr}`. A budget expiry **FAILS** (it never silently passes) and prints as *"never mapped"*, which is distinguishable from a focus theft (`{1 …wvsearch.pat}`). The repair's second design property is therefore measured, not argued. |
| **U3** | `-type $type` -> `-type All` in `add_trace_filter` | **CAUGHT. AT12 alone.** |
| **U4** | blank the listbox instead of holding, on an invalid pattern | **CAUGHT. AT11 alone** — D3's choice is pinned against the opposite behaviour, not merely against deletion. |
| **U5 — the subtle one: a re-implementation, not a deletion** | snapshot the selection **by INDEX instead of by NAME** — the plausible thing a maintainer would actually write | **CAUGHT. AT14 alone**, got `{{1 3 4} {} {}}`. |

**Nothing survived.** Unlike item 4 (whose U2 survived and was carried here as V-U2), item
5 leaves no unpinned-and-unclaimed route behind. The verifier also re-verified statically,
from `git show` rather than from this receipt, that **AT21 exists and pins the
throwing-consumer -> `searchbar_error` path with an anti-vacuity pre-read** — i.e. the
carried-forward V-U2 debt is genuinely discharged — and that `ase::ui::dialog_frame`
destroys any existing dialog **before** `add_trace_dialog` writes `atdsigs`, so the reopen
ordering is safe (AT04 exercises it).

## 7. Non-baseline fails

**Implementer, fixup audit** (solo, gated):

```
SUMMARY: 260 pass  19 fail  0 crash/timeout  4 skip  (total 283)
grep -c 'X connection to :0 broken'  = 0     <- the run IS a measurement
grep -c 'revive FAILED'              = 0     <- the gate held all the way through
scratch dirs leaked                  = 0
wireedit suite                       = PASS (8/8)
test_wave_sigsearch                  = PASS  (INSIDE the audit)
test_wave_viewer                     = PASS  (INSIDE the audit)
```

19 = **15 of the 16 HARD** names (the 16th, `test_fluid_editing`, **SKIPped** rather than
failed) + **4 non-HARD**. That `test_wave_sigsearch` PASSES *inside* the audit matters more
than the solo soak: audit load is exactly the condition under which the first verifier's
AT18 flake — and item 4's deleted BAR25 — revived.

| name | in the audit | re-run | on the FLAKY list? | disposition |
|---|---|---|---|---|
| `test_ase_unnamed_net` | FAIL `AN8` | 2 pass / 1 fail, the fail again `AN8` | **yes, and the list NAMES `AN8`** | baseline flake |
| `test_deselect_mode` | FAIL (DM8/DM9/DM10b) | **3/3 PASS** | **yes** | baseline flake |
| `test_wave_markers` | FAIL `MX5`,`MX11`,`MX12` | 6 solo runs: 4 pass / 2 fail — the fail was **`MF1` every time, `MX*` never reproduced** | **yes, and the list NAMES `MF1`** | baseline flake; the `MX*` set is an audit-load artifact of an already-listed name. **Reported rather than swallowed** because the check set differed from the list's — the right instinct. |
| `test_wave_trace_menu` | FAIL `TG9` | 6 solo runs: 4 pass / 2 fail, **always `TG9`** | **no — the PLAN de-listed it** | **RE-LIST. See below.** |

**Verifier, independent solo gated audit:**

```
SUMMARY: 261 pass  18 fail  0 crash/timeout  4 skip  (total 283)
WIREEDIT PASS   SCRATCH 0 leaked   revive FAILED = 0
X connection to :0 broken = exactly 1  (it killed ONE test; that name's result is VOID)
test_wave_sigsearch = PASS (inside the audit)   test_wave_trace_menu = PASS (inside it)
```

18 reconciles exactly: **15 HARD** (same shape — `test_fluid_editing` SKIPped) +
`test_pristine_untitled_viewer_0172` (FLAKY-listed, **3/3 PASS** on re-run) +
`test_wire_vertex_grab` + `test_window_switch_bogus_enter`. The verifier's audit *passed*
`test_wave_markers` and `test_ase_unnamed_net`, which is the other half of the case that
those two are load flakes rather than regressions.

| name | disposition |
|---|---|
| `test_wire_vertex_grab` | **NEW non-baseline name, NOT item 5's.** FAILed the verifier's audit on *"shorten: wire is (0,0)-(60,0)"* and *"grow: wire is (0,0)-(150,0)"*; **3/3 PASS** solo; **zero** `wviewer` / `add_trace` / `wave_viewer` references in the file. Audit-load artifact. **RECOMMEND the FLAKY list.** |
| `test_window_switch_bogus_enter` | **VOID, not a measurement.** Its process died with `X connection to :0 broken` — the single occurrence in the whole audit. **3/3 PASS** solo. Not a fail, and not a FLAKY-list candidate on this evidence. |
| `test_ase_dialogs` | the FIRST verifier's new name. **PASS** in the implementer's audit and **3/3** solo; **PASS** in the second verifier's audit and **3/3** solo. Against the first verifier's audit FAIL + 1-fail-in-3, and with a *different fail set each time*, that is the ASE-L state-leftover signature. **Zero item-5 identifier hits. RECOMMEND the FLAKY list.** |
| `test_hier_close_prompt` | **driver note (f) DISCHARGED.** PASS in both audits, **3/3 solo twice** (implementer, round 1 and fixup) and **3/3 solo** (verifier), on top of the scout's clean audit. Six-plus green data points across three agents. **RECOMMEND NEITHER list — remove its line from the FLAKY block.** |

**`test_wave_trace_menu` / TG9 — the one both sessions ask the driver to act on, and the
only one settled by a CONTROLLED EXPERIMENT.** The PLAN de-listed TG9 because it *"passed
both re-baseline runs"*. The implementer measured **2 fails in 6** solo runs on a tree
item 5 cannot reach, making two consecutive clean runs a **~0.44 coincidence** — weaker
than a coin flip, so the de-listing evidence does not carry. The verifier then ran the A/B
the PLAN never had: **6 solo runs at HEAD = 2 pass / 4 fail** (fail sets varying —
TR4+TS8 x2, TG10 x2, *never* TG9), then `git checkout 51291535 -- src/wave_viewer.tcl`
(pre-item-5 source, md5 `3817b5a06d98591e76234c302fbe9aab`) and **6 more = 3 pass /
3 fail, the same fail shapes**. **Identical rate with the item present and absent**, and it
PASSED inside the verifier's audit. The failing checks are RMB/pointer-gesture and
box-zoom checks; item 5 touches no gesture code. Source restored, md5 re-verified.
**RECOMMEND: back on the FLAKY list.**

**Ledger conclusion: NO regression is attributable to item 5.** Every non-baseline name is
either FLAKY-listed, cleared on re-run, void by X death, or disposed of by an A/B with the
item's source reverted — and in every case item 5 was additionally shown **statically
inert** (identifier grep + diff hunk headers), not merely re-run until green.

## 8. Verifier problems (all REPORT-ONLY) — carried forward

* **B1 — the blocker, and it was real.** The first verifier caught a **shipped flake in a
  check the implementer had already declared green**. It is the batch's second such catch
  (item 4's BAR25 was the first) and both were AT/BAR-family Tk-timing checks. The lesson
  is now written into the shipping test file as a header warning — *do not simplify this
  back to a bare `update`* — which is the durable form, because a maintainer acts on a
  comment as readily as on a check name.
* **B2 — item 4's V-U2 is CLOSED by AT21**, as item 4's ledger predicted it would be.
* **P1 — carried unfixed a THIRD time, deliberately.** `src/xschem.tcl:4548` says
  `wave_viewer.tcl` is *"sourced unconditionally at xschem.tcl:14352"*; the `source` is at
  **`:14374`**. `src/xschem.tcl` is outside item 5's Files line, so fixing it here would be
  a silent scope widening. **The number has now rotted in three consecutive items** —
  the driver should replace it with a grep-able phrase, which is precisely the remedy item
  5 applied to the one comment it *did* own (D10b).
* **R9 residual, NOT closed here.** Item 4's `u6` (the searchbar's own `%W` `<Destroy>`
  guard is still dead code by Tk's bindtag rules) stays a declared gap. **The `%W` guard in
  `add_trace_forget` is a different case entirely** — it is live, measured, and pinned by
  AT20 (sabotage E2).
* **DRIVER DECISION REQUESTED — the Search button (D15).** Driver note (b) suggested
  `-showbutton 0`; **settled decision 5 mandates the button** (*"live-as-you-type AND a
  Search button"*), so the button is present and AT09 drives it as a real route. It is also
  the **widest single child**, i.e. the main contributor to the WIDTH risk in the eyeball
  note. Both verifiers agree the current choice is right and that changing it is a
  **ruling, not an implementer's fix**.
* **BASELINE FEEDBACK — three edits to the FLAKY block, all endorsed by both sessions:**
  **add** `test_wave_trace_menu` (re-list; A/B-proved), **add** `test_wire_vertex_grab`,
  **add** `test_ase_dialogs`; **remove** the `test_hier_close_prompt` line (note (f)
  discharged — it belongs on neither list).
* **Gate discipline: clean this round.** `revive FAILED` = **0** in both audits — item 4's
  G1 (seven occurrences in one day, one of which cost a verifier a completed measurement)
  did **not** recur. `GUI_GATE` was never set and no control file was ever hand-written by
  either session; the user's run-at-will authorisation was live throughout.

## 9. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** *(planned)* | population moves from a bare, never-restored `xschem new_schematic switch $wp` to `wviewer::signal_list` | the scope line said so — and it incidentally repairs a live **issue-0173 loan violation** that left the viewer's wm title clobbered. Pinned by **AT22**. Safe because `add_trace` self-switches and `test_wave_viewer` G11/G12 switch explicitly; both re-verified green. |
| **D2** *(planned)* | the `rawnote` trigger becomes *"the inventory is empty"* rather than *"`xschem raw list` threw"* | same user-visible string, and now **pinned by AT23**, which the plan did not require. |
| **D3** *(planned)* | an invalid regexp **HOLDS** the last good list rather than blanking it | item 4's contract comment explicitly delegates this choice to item 5; the legacy `.graphdialog` blanks and ruling 16 makes that surface the exception. Pinned by AT11 — and by the verifier's U4, which injected the *opposite* behaviour. |
| **D4** *(planned)* | the PLAN's *"still exist and still work"* is **NARROWED** for the Name row to *"still exists at its contract path"* | **AT01 is the only check in the group that reads `$atw.name`/`$atw.lname`** — a second reader would give named sabotage (b) a second target and destroy its single-target property. The *"still works"* half is carried by `test_wave_viewer` G12, run green by both sessions. Ruling 17's corollary: the claim is narrowed to the coverage and the gap is named. |
| **D5** *(planned)* | the `<KeyRelease>` leg is driven at `searchbar_fire`, not by a generated key | driver note (g) / item 4's D9. The button, type-combobox and checkbutton legs ARE driven through real Tk routes, each confirmed by a sabotage. Claim narrowed to match: **end-to-end X key delivery into this dialog is NOT pinned.** |
| **D6** | **E7 fails 8 checks, not the predicted 1** | honest superset; structural, not a test defect — §4. |
| **D7** | **AT20 was widened** after E2 measured one of its two halves vacuous | ruling 17's corollary; the first, weaker measurement is recorded rather than retro-edited. |
| **D8** | **AT23 added beyond the PLAN's table** | to pin D2's changed trigger. It uses a token whose `win_path` does not exist, so `signal_list`'s landmine-17 refusal supplies the empty inventory — **no third xschem context is created**, and the header's process-state paragraph stays true. |
| **D9** | the test file's `--nogui` coverage claim was **re-stated, not left stale**: the header now names **both** BAR and AT (49 of 139 checks are DISPLAY-arm-only) | a maintainer debugging with `--nogui` would otherwise read a green run as coverage of the Add Trace filter. This is the only non-appended edit of round 1. |
| **D10** | two comment repairs in `src/wave_viewer.tcl` — (a) the dead `set wp [dict get $windows $token win_path]` removed; (b) item 4's *"THIS SECTION SHIPS WITH ZERO CONSUMERS"* header rewritten | made **necessary by this item's own change**, not opportunistic: item 5 *is* the consumer, so item 4's comment became false and a maintainer would act on it. Per R9's lesson the replacement is a **grep-able phrase, not a line number**. |
| **D11** | **AT13 uses the pattern `I(*)`, not the plan's implied empty pattern** | an empty pattern matches everything of the selected type *regardless of case*, so it could not discriminate `Match case` at all — the check would have been vacuous. Measured: `I(*)` case-OFF -> `{i(v1) I(V2)}`, case-ON -> `{I(V2)}`, exactly the plan's expectation table. |
| **D12** | **check order: AT20 runs before AT19** | AT19 destroys the dialog AT20 needs alive. Ordering only; both expectations are the plan's. |
| **D13** *(fixup)* | **AT18 now waits for the MAP and asserts it** | the one-`update` form was a measured flake (the blocker). Full mechanism and measurements in appendix §10. Count unchanged at 139 — widened, not split, nothing deleted. |
| **D14** *(fixup, declared LATE — the first verifier was right to flag it)* | driver note (b) says *"`pack $w -fill x` is REQUIRED"*; the bar is placed with `grid $sb -row 4 -column 0 -columnspan 3 -sticky we -padx 8 -pady {4 2}` | the **grid-manager equivalent**, not a departure: `add_trace_dialog` is a grid-managed toplevel and packing a child into it would throw *"cannot use geometry manager pack inside …"*. `-sticky we` + `-columnspan 3` **is** what `-fill x` means in grid, and **AT16 pins `winfo manager` = `grid`**, so a later "tidy" back to `pack` fails a check rather than silently collapsing the bar to its natural width — the trap item 4's eyeball note warned about. **No code changed; this was a REPORTING defect, and both verifiers agree the code is right.** |
| **D15** *(fixup, declared LATE)* | `searchbar_build` is called **without `-showbutton 0`**, against note (b)'s suggestion | **settled decision 5 mandates the button** and AT09 drives it as a real route, so keeping it is correct — but it is the widest child and therefore the main WIDTH risk. Escalated as a driver ruling rather than silently changed. |
| **F1** *(fixup)* | the blocker was repaired by **WIDENING**, where the verifier had offered deletion as the alternative | justified by a measurement the verifier did not have: their probe established that `focus -lastfor` is *unsettled* while unmapped; the implementer's additionally established that **Tk re-applies the deferred request at MAP time (12/12)**, so the value is recoverable and the claim is measurable. Ruling 17 permits either branch; widening is stronger. |
| **F2** *(fixup)* | the eyeball line the verifier called overstated (appendix §7 item 3) was **rewritten**, not defended | it now names exactly what AT18 does and does not pin. Rewording alone, without the coverage, would have been the failure mode ruling 17 exists to prevent — here **both** were done. |
| **F3** *(fixup)* | committed as **ONE `feat(…)` commit**, not a fixup pair on top | the item had never been committed (verifier finding 4), so there was no base to fix up. Explicit 3-file list, no push. `PLAN.md` and `receipts/{02,03,04}` left unstaged — driver-owned, and dirty on arrival. |
| **L1** *(this stage)* | the ledger line carries the item's open flags inline rather than a bare `-> DONE-PIXEL (…)`, and this file **merged** the implementer long-form as an appendix instead of clobbering it | item 1/2/3/4 ledger precedent. The implementer wrote its long-form straight to the pipeline path `receipts/05_receipt.md` and committed it inside `3c7c993f`, so this stage put the ledger receipt on top and preserved the long-form verbatim — nothing lost, no second file. This receipt is consequently **dirty vs `3c7c993f`**, like `PLAN.md` and `receipts/{02,03,04}`; **this stage committed nothing and touched nothing outside `doc/claude/signal_browser_batch/`.** |
| **L2** *(this stage)* | the Eyeball-queue row quotes the PLAN's `Eyeball:` line **verbatim, including its stale `:7200`**, and appends the correction in the parenthetical | the instruction is to carry the line as written; silently renumbering it would edit the plan's record. The scout measured `focus $ee` at **`:7719`** (uniform +519 drift), and P1 is the standing lesson about line numbers — so the row also says *"the last statement before `return $w"`*, which does not rot. |

## 10. If a human looks at one thing

Item 5 is **DONE-PIXEL** and nothing here is a failure, so this is a queue, not a
post-mortem. In order:

1. **The eyeball itself — appendix §7, and specifically WIDTH.** This is why the mark is
   `[E]` and not `[x]`. Open **Graph > Add Trace…** on a real viewer with a raw loaded.
   The bar is an 8-char combobox + a 20-char entry + a 7-char combobox + `Match case` +
   `Search` + a **fixed** 24-char error label, gridded `-columnspan 3 -sticky we`, while
   the dialog's other rows are 26-char entries — so **the bar becomes the dialog's minimum
   width** and will roughly double or triple it. If that is unacceptable the fix is a
   **DRIVER RULING**: `-showbutton 0` contradicts settled decision 5, and an elastic
   `$sb.err` re-introduces exactly the resizing item 4's BAR21 forbids (item 4's own note
   says the right answer there is a tooltip). Also check height with the 8-row listbox, the
   6/4/3-px gutters against the dialog's 8/6/2 pads, that two selected rows are still
   *visibly* highlighted after filtering down and back, and that the caret really is in
   **Expression** — AT18 pins Tk's focus record once mapped, **not** the visible caret and
   **not** that the WM gives this toplevel focus at all.
2. **A visible lag before the dialog paints is real and worth reporting** — 3 of 25 opens
   on an **idle** machine took up to **3.5 s** to map. It is not item 5's doing (WSLg /
   weston, and it predates the bar), but it is now measured, and it is the same phenomenon
   that made AT18 flake.
3. **The four baseline-list edits** in §8, one of which is A/B-proved: re-list
   `test_wave_trace_menu`, add `test_wire_vertex_grab` and `test_ase_dialogs`, remove
   `test_hier_close_prompt`.
4. **P1, rotted for the third consecutive item** (`src/xschem.tcl:4548`). Replace the
   number with a grep-able phrase; it will rot again otherwise.

To hand to item 6 when it starts: **a live fixture** — `at_open`, `at_lb`,
`at_wait_mapped` and `at_throwcb` are left defined on purpose, and `$w.vars` is now
`-selectmode extended`, which is the thing item 6 consumes. **If item 6 asserts anything
about focus, a caret, a grab, or `<Visibility>`-dependent geometry, it must go through
`at_wait_mapped` — appendix §10 is the reason, and this item is the second in the batch to
ship a Tk-timing flake past a green suite.** Also inherited: **D7** (`--nogui` covers 90 of
139 checks; the AT half needs real Tk), **D3** (invalid pattern HOLDS the list), and
**D4** (`test_wave_viewer` G12 carries the Name row's *"still works"* half).

---

---

# APPENDIX — implementer long-form receipt, preserved verbatim

Below is the receipt as committed inside `3c7c993f`
(file `doc/claude/signal_browser_batch/receipts/05_receipt.md`, 452 lines), unedited.
Where it and §1-§10 above disagree, **§1-§10 wins** — specifically, its §8
disposition of `test_wave_trace_menu` is superseded by the verifier's **controlled A/B**
(§7), which reaches the same recommendation on stronger evidence, and its §9 list of names
carried to the driver is extended by `test_wire_vertex_grab`.

---

# Item 05 — searchbar into `add_trace_dialog` — IMPLEMENTER RECEIPT

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `51291535`.
Date 2026-08-05. PIXEL item.

---

## 0. FIXUP ROUND — what the verifier rejected, and what changed

The verifier REJECTED this item on one blocker and returned four reports. Disposition:

| # | verifier finding | disposition |
|---|---|---|
| **1** | **BLOCKER — AT18 is a shipped flake** (3 fails in 22 solo runs, always `{.wvat1.wvadd}` vs `{.wvat1.wvadd.expr}`) | **ACCEPTED IN FULL, REPAIRED by WIDENING.** §10. Their mechanism was re-measured here, independently, and is correct. |
| **2** | mechanism: `focus $w` on an UNMAPPED toplevel does not settle `focus -lastfor`; one `update` does not guarantee a map | **CONFIRMED and EXTENDED** — see §10: their probe stopped at "not settled"; the extension needed for the repair is that the record DOES settle at map time, so a bounded wait is sound. |
| **3** | ruling 17's corollary: widen the coverage or narrow the claim; and §7 item 3's wording overstated | **BOTH DONE.** Coverage widened (§10), and §7 item 3 rewritten. |
| **4** | not committed, so scope could not be checked from `git show` | **FIXED** — this round commits, explicit file list, no push. Their DISCHARGE of the implementer's blocker (the 4 unclearable names) is confirmed by the audit in §8. |
| **5** | new non-baseline audit name `test_ase_dialogs`, item-5-inert | **AGREED, and re-measured here** (§8). Reported to the driver, §9. NOT charged to item 5. |
| **6** | undeclared literal divergences from driver note (b): `grid` not `pack $w -fill x`; `-showbutton` left at 1 | **ACCEPTED as reporting defects, now DECLARED** — §6 D14 and D15. No code change: the verifier's own analysis (and settled decision 5) says both current choices are right. |

Nothing else was touched. `src/wave_viewer.tcl` is **byte-identical to what the verifier
audited** (`md5 987360a53e783cde4cfe13b483a433bb`, their value, re-checked at the end of
this round). **The whole fixup is in the test file.**

## 1. Verdict

**DONE-PIXEL — ledger mark `[E]`, NOT `[x]`.** The deliverable is visible UI. The
headless checks pin the model, the routes and the grid arithmetic; they cannot judge
width, spacing or the visible caret. **§7 is the eyeball note and it is OWED, not
waived.** No claim of visual correctness is made anywhere in this receipt.

Scope held: **2 source files, no C** (settled decision 8), no new test file
(decision 9), no settled decision overturned.

## 2. Files touched

| file | what |
|---|---|
| `src/wave_viewer.tcl` | the four planned edit sites + one comment repair (§6 D10). `+98/-10`. |
| `tests/headless/test_wave_sigsearch.tcl` | group **AT**, 20 checks, APPENDED after the BAR group. The only non-appended edits are the header (R4, §6 D9) and, in the FIXUP round, the header's AT paragraph + `at_wait_mapped` + AT18 itself (§10). |
| `doc/claude/signal_browser_batch/receipts/05_receipt.md` | this file. |

**The FIXUP round changed the TEST FILE ONLY.** `src/wave_viewer.tcl` still hashes to the
value the verifier recorded, so their static re-verification of the source still stands
unmodified.

`PLAN.md` left **UNSTAGED** — driver's file, item-2 D6 / item-3 D9 / item-4 precedent.

Four edit sites, as planned:
1. `namespace eval wviewer` — `variable atdsigs`, keyed by **session token** (the dialog
   is a per-window singleton, unlike the searchbar's `sbcfg` which is keyed by widget path).
2. `add_trace_dialog` — the bar at row 4, grid renumbered 3-7 with no hole, inventory via
   `wviewer::signal_list`, `-selectmode extended`, the `<Destroy>` bind.
3. `add_trace_filter` — the consumer callback. Every exit is a guard; it must not throw,
   because it rides `searchbar_fire`, which rides `<KeyRelease>`.
4. `add_trace_forget` — the cache drop, **with the mandatory `%W` guard**.

**Blast radius, measured not asserted:** `add_trace_filter` / `add_trace_forget` have
**zero hits outside `src/wave_viewer.tcl`**; `atdsigs` appears elsewhere only in the AT
group's own assertions. The one production caller of `add_trace_dialog` is the Graph menu's
Add Trace… entry (`grep -n 'wviewer::add_trace_dialog \$token' src/wave_viewer.tcl` — a
phrase, not a line number, per R9's lesson; the number moved by 7 within this item alone);
the one test caller outside this batch is `test_wave_viewer.tcl` (§3, green).

## 3. Tests

| | |
|---|---|
| test file | `tests/headless/test_wave_sigsearch.tcl` (decision 9: one file, appended) |
| checks added | **20** (AT01-AT04, AT07-AT14, AT16-AT23) |
| checks total | **119 -> 139** DISPLAY arm; **90** unchanged in `--nogui` |
| runtime | **1.86 s** DISPLAY (was 0.73 s), **0.37 s** `--nogui` (unchanged). FIXUP round: unchanged in the common case (~10 ms of extra wait), up to **+3.5 s** on the ~1-in-8 runs where the WM maps the dialog late (§10.3) |
| build | Tcl-only; `cd src && make` -> *"Nothing to be done for 'all'."* (re-confirmed in the FIXUP round) |

**The FIXUP round did not change the check count.** 139 before, 139 after: AT18 was
**widened in place**, not split and not deleted (§10). No check was removed at any point in
this item.

**There is no AT05, AT06 or AT15** — those names were never written, nothing was deleted.
The gap is inherited from the plan's own numbering and is called out in the file header so
no maintainer hunts for removed checks.

**R3 — the real regression guard lives in a file this item does not own.** Because the
open population now routes through the new filter, `test_wave_viewer.tcl`'s G11
(`listbox count == raw vars`) depends on item 5. Run and green:
**`test_wave_viewer` -> ALL PASS (400 checks)**. G11/G12/G12b drive
`add_trace_dialog` -> `add_trace_ok` end to end including `$w.name insert 0 db1`, so they
are what carries the *"the Name entry still WORKS"* half of the PLAN's regression clause
(see D4).

**Driver note (d) honoured byte-exactly.** `gsl_frozen_ref`, the GSO block, `GSO_NAMES`,
`GSO_PATS`, `GSO_BLOBS` and `GSPLAIN` are untouched — `git diff` shows **zero** `+`/`-`
lines matching any of those identifiers, and the only deleted lines anywhere in the test
file are the six lines of the header paragraph rewritten for R4.

## 4. Sabotage table

Every injection `diff`-confirmed against a byte-exact pristine snapshot **before** the
run, every revert md5-verified (item 3's D5 / item 4's D6 — the item was uncommitted, so
`git checkout --` could not be used), clean green re-run at the end in **both** arms.

| # | injection | predicted | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| **NAMED (a)** | delete the `keep` snapshot loop in `add_trace_filter` | AT14 | **AT14 alone**, 1 FAILED / 138 passed | **yes** | yes (md5 OK) |
| **NAMED (b)** | delete the Name row **pair** (`dialog_row … name` AND `bind $ne <Return>`) | AT01 | **AT01 alone**, got `{1 1 1 1 0 0 1 1 1 1 1}` | **yes** | yes |
| **E1** | delete `$w.vars configure -selectmode extended` | AT17 | **AT17 alone**, got `browse` | **yes** | yes |
| **E2** | drop the `%W ne $w` guard in `add_trace_forget` | AT20 | **AT20 alone** | **yes** | yes |
| **E3** | replace `wviewer::searchbar_error $w $e` with a comment (item 4's verifier U2, verbatim) | AT21 | **AT21 alone**, got `{{} {}}` | **yes** | yes |
| **E4** | drop the `if {[lindex $r 0] ne {ok}} return` guard | AT11 | **AT11 alone** — and the got value shows the exact mechanism: the error string became the sole listbox row | **yes** | yes |
| **E5** | `focus $sb.pat` after `focus $ee` | AT18 | **AT18 alone** | **yes** | yes |
| **E6** | swap the searchbar's and `$w.vars`' grid rows | AT02 | **AT02 alone**, got `{3 5 4 6 7}` | **yes** | yes |
| **E7** | feed `sig_bare`-stripped names to `sig_match` | AT12 | **8 FAILED** — AT07, AT08, AT09, AT11, AT12, AT13, AT14, AT20 | **NO — honest superset, see below** | yes |

**FIXUP ROUND — re-run against the repaired test file** (the source is byte-identical, so
only the checks changed; the two NAMED sabotages were re-run to prove the repair did not
soften them, plus one new one for the repaired check):

| # | injection | predicted | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| **NAMED (a)** re-run | delete the `keep` snapshot loop in `add_trace_filter` | AT14 | **AT14 alone**, got `{{1 3 4} {} {}}` | **yes** | yes (md5 OK) |
| **NAMED (b)** re-run | delete the Name row pair | AT01 | **AT01 alone**, got `{1 1 1 1 0 0 1 1 1 1 1}` | **yes** | yes (md5 OK) |
| **S-AT18 (NEW)** | delete `focus $ee` — sever the very route AT18 claims to pin | AT18 | **AT18 alone**, got `{1 .wvat1.wvadd}` | **yes** | yes (md5 OK) |
| **E5** re-run | `focus $sb.pat` after `focus $ee` | AT18 | **AT18 alone**, got `{1 .wvat1.wvadd.wvsearch.pat}` | **yes** | yes (md5 OK) |

S-AT18 is the one the first round lacked: E5 proved the bar *cannot steal* the focus, but
nothing proved the dialog *still gives* it. Both directions are pinned now, and both got
values carry `ismapped 1`, which is the widened wait visibly working.

### E7: the plan's prediction is measurably wrong, and the truth is stronger

The plan predicted E7 would fail *"AT12 exactly"*. It fails **eight** checks. The reason is
structural, not a test defect: **the filter's output IS the listbox content**, so stripping
the inventory changes everything displayed, not merely what the type dropdown selects.
There is no injection point that isolates AT12 without moving the violation into item 1's
`sig_match` (out of scope).

Recorded as an **honest superset**, the same disposition item 4 gave its u2 and u8. The
consequence is a *stronger* result than planned: **settled decision 2 is load-bearing for
the entire Add Trace surface, not just the type dropdown.** AT12 remains the named
decision-2 witness, and it is among the eight.

### E2 exposed a vacuous half, which was widened rather than explained away

On its first injection E2 failed AT20 on **one** half only. AT14 leaves the listbox already
showing the `v(*)` set, so a filter that bails out on the missing cache leaves *exactly the
expected content* behind — the *"and the filter still works"* half had no teeth.

Per **ruling 17's corollary** (widen the coverage or narrow the claim, never neither) the
check was **widened**: AT20 now resets to the full list first, records it, and only then
destroys the child. E2 was re-injected and now fails on **both** halves — the cache flag
*and* a stale 8-row list. Recorded because the first measurement is the honest one.

## 5. Runs

| run | result |
|---|---|
| `cd src && make` | *"Nothing to be done for 'all'."* |
| `run_suites.sh test_wave_sigsearch` | **ALL PASS (139 checks)** |
| `--nogui` arm | **ALL PASS (90 checks)**, both groups self-skip |
| `run_suites.sh test_wave_viewer` (R3) | **ALL PASS (400 checks)** |
| `test_hier_close_prompt` x3 (driver note f) | **3/3 ALL PASS** |
| solo gated `full_audit.sh` | see §8 |

**FIXUP ROUND runs** (all gated; the user's run-at-will authorisation still live, expiry
epoch 1785934870 — the round finished well inside it, and no control file was hand-written
and `GUI_GATE` was never set):

| run | result |
|---|---|
| `cd src && make` | *"Nothing to be done for 'all'."* (no C, no rebuild — Tcl only) |
| `test_wave_sigsearch` DISPLAY, **25 solo runs** (instrumented soak) | **25/25 ALL PASS (139 checks)**; 3 of them exercised the late-map path the old AT18 died on (§10.3) |
| `test_wave_sigsearch` `--nogui` | **ALL PASS (90 checks)**, both banners still self-skip |
| 4 sabotages re-run + reverted, md5-verified | §4, all `failedExactly` |
| `test_hier_close_prompt` x3 | see §8 |
| `test_ase_dialogs` x3 | see §8 |
| solo gated `full_audit.sh` (283 tests) | §8 |

**Driver note (f) — DISCHARGED.** `test_hier_close_prompt` passed **3/3** off a healthy
panel (pid 1008879, uptime 2 h at start). This independently reproduces the scout's
result. **Recommendation: it belongs on NEITHER list** — item 4's failure of it sat inside
the 3-second window in which the gate panel died, which ruling 19 has since explained as a
weston restart, not a harness bug.

**Gate discipline:** every run went through `run_suites.sh` / `gated_xschem.sh` /
`full_audit.sh`. `GUI_GATE` was **never set**, no control file was ever hand-written. The
user's run-at-will authorisation was live throughout (expires epoch 1785934870 =
2026-08-05 06:01 MST).

## 6. Divergences — DECLARED, not hidden

- **D1** (planned) population moves from a bare, never-restored `xschem new_schematic
  switch $wp` to `wviewer::signal_list`, per the scope line — incidentally repairing a live
  **issue-0173 loan violation** that left the viewer's wm title clobbered. Pinned by
  **AT22**. Safe because `add_trace` self-switches, and `test_wave_viewer` G11/G12 switch
  explicitly themselves — both re-verified green.
- **D2** (planned) the `rawnote` trigger becomes *"the inventory is empty"* rather than
  *"`xschem raw list` threw"*. Same user-visible string. Now **pinned by AT23**, which the
  plan did not require (§6 D8).
- **D3** (planned) an invalid regexp **HOLDS** the last good list rather than blanking it.
  Item 4's contract comment explicitly delegates this choice to item 5; the legacy
  `.graphdialog` blanks, and ruling 16 makes that surface the exception. Pinned by AT11.
- **D4** (planned) the PLAN's *"still exist and still work"* is **NARROWED** for the Name
  row to *"still exists at its contract path"*. **AT01 is the only check in the group that
  reads `$atw.name`/`$atw.lname`** — a second reader would give named sabotage (b) a second
  target. The *"still works"* half is carried by `test_wave_viewer` G12, run and reported
  green. **Ruling 17's corollary: the claim is narrowed to the coverage, and the gap is
  named.**
- **D5** (planned) the `<KeyRelease>` leg is driven at `searchbar_fire`, not by a generated
  key (driver note g / item 4's D9). The button, type-combobox and checkbutton legs ARE
  driven through real Tk routes, each confirmed by a sabotage. Claim narrowed to match:
  **end-to-end X key delivery into this dialog is NOT pinned.**
- **D6 (NEW)** **E7 fails 8 checks, not the predicted 1** — honest superset, §4.
- **D7 (NEW)** **AT20 was widened** after E2 measured one of its two halves vacuous, §4.
- **D8 (NEW)** **AT23 added, beyond the plan's table**, to pin D2's changed `rawnote`
  trigger. It uses a token whose `win_path` does not exist, so `signal_list`'s landmine-17
  refusal supplies the empty inventory — **no third xschem context is created**, and the
  process-state paragraph in the file header stays true.
- **D9 (NEW / R4)** the file header's `--nogui` coverage claim was **re-stated, not left
  stale**: the ⚠ paragraph now names **both** BAR and AT (49 of 139 checks are
  DISPLAY-arm-only), so a maintainer cannot read a green `--nogui` run as coverage of the
  Add Trace filter. This is the only non-appended edit to the test file.
- **D10 (NEW)** two comment repairs in `src/wave_viewer.tcl` made necessary **by this
  item's own change**, not opportunistic:
  (a) the dead `set wp [dict get $windows $token win_path]` was removed — the switch it fed
  is gone and nothing else referenced it;
  (b) the item-4 section header asserted *"THIS SECTION SHIPS WITH ZERO CONSUMERS …
  `grep -rn searchbar_build src/` outside this section returns nothing today"*. **Item 5
  makes that false**, and a maintainer would act on it. Rewritten to name the consumer and
  to warn that the section is no longer blast-radius-free. Per R9's lesson the replacement
  is a **grep-able phrase, not a line number**.
- **D11 (NEW)** **AT13 uses the pattern `I(*)`, not the plan's implied empty pattern.** An
  empty pattern matches everything of the selected type *regardless of case*, so it cannot
  discriminate `Match case` at all — the check would have been vacuous. Measured:
  `I(*)` case-OFF -> `{i(v1) I(V2)}`, case-ON -> `{I(V2)}`, which is exactly the
  expectation the plan's table records.
- **D12 (NEW)** **check order: AT20 runs before AT19.** The plan's table lists AT19 first,
  but AT19 destroys the dialog that AT20 needs alive. Ordering only; both expectations are
  the plan's.
- **D13 (FIXUP)** **AT18 now waits for the dialog to MAP, and asserts the map.** The
  original one-`update` form was a measured flake. Full mechanism, measurements and the
  severance proof in **§10**. The check count is unchanged (139) — AT18 was widened, not
  split, and nothing was deleted.
- **D14 (FIXUP, declared late — the verifier was right to flag it)** driver note (b) says
  *"`pack $w -fill x` is REQUIRED"*. The bar is placed with
  `grid $sb -row 4 -column 0 -columnspan 3 -sticky we -padx 8 -pady {4 2}` instead. This is
  the **grid-manager equivalent**, not a departure from the note's intent: `add_trace_dialog`
  is a grid-managed toplevel, and packing a child into it would throw
  *"cannot use geometry manager pack inside …"*. `-sticky we` + `-columnspan 3` is what
  `-fill x` means in grid. **AT16 pins `winfo manager` = `grid`**, so a later "tidy" back to
  `pack` fails a check rather than silently collapsing the bar to its natural width — which
  is the trap item 4's eyeball note was warning about. Should have been in the D-list on the
  first pass; it was not, and that is a reporting defect, not a code defect.
- **D15 (FIXUP, declared late)** `searchbar_build` is called **without `-showbutton 0`**, so
  the Search button is present. Driver note (b) mentions `-showbutton 0` "for the filter-bar
  variant", but **settled decision 5 mandates the button** ("live-as-you-type AND a Search
  button") and AT09 drives it as a real route. The button is kept deliberately. **It is also
  the widest single child**, so it is the main contributor to §7 eyeball item 1 (WIDTH) —
  the driver should confirm which of the two it meant, because dropping it is a
  **decision-5 change and therefore a driver ruling, not an implementer's call.**

## 7. EYEBALL NOTE — OWED, `[E]`

Open **Graph > Add Trace…** on a real viewer with a raw loaded. Nothing below has a
headless proxy; **no visual claim is made here.**

1. **WIDTH — the risk the PLAN does not name (scout's R1).** The bar is an 8-char combobox
   + a 20-char entry + a 7-char combobox + `Match case` + `Search` + a FIXED 24-char error
   label, gridded `-columnspan 3 -sticky we`. The dialog's other rows are 26-char entries,
   so **the bar becomes the dialog's minimum width** and will roughly double or triple it.
   Judge whether that is acceptable. **If rejected it needs a DRIVER RULING, not an
   implementer's fix:** `-showbutton 0` would contradict settled decision 5, and making
   `$sb.err` elastic would re-introduce the resizing item 4's BAR21 forbids (item 4's own
   note says the right answer there is a tooltip).
2. **Height** — the dialog must still fit on screen with the 8-row listbox and the extra row.
3. **Focus** — the caret must be in the **Expression** entry on open. *(AT18 pins Tk's
   focus record ONLY ONCE THE DIALOG IS MAPPED, and pins the map itself; see §10. It does
   NOT pin the visible caret, and it does not pin that the window manager gives this
   toplevel the focus at all — under a WM that focus-follows-mouse or refuses focus to a
   transient, the record can be right and the caret still elsewhere. That is precisely why
   this line is an eyeball line.)* **Watch for a SLOW MAP:** the repair round measured the
   dialog taking up to **3.5 s** to appear on 3 of 25 opens on an idle machine — if what
   you see is a visible lag before the dialog paints, that is real and worth reporting,
   even though it is not item 5's doing (it is WSLg/weston, and it predates the bar).
4. **Spacing/alignment** — the bar's 6/4/3-px gutters against the dialog's 8/6/2 grid pads;
   whether it reads as part of the dialog or bolted on.
5. **Live filter feel** — type `v(` under `Shell`, then switch to `RegExp` and watch the
   dark-red message appear in the reserved 24-char slot **without the dialog resizing**.
6. **Selection** — select two rows, filter down, filter back: both must still be
   highlighted. *(AT14 pins the model; that the highlight is VISIBLE is the eyeball's.)*

## 8. Audit — FIXUP ROUND, solo, gated

```
SUMMARY: 260 pass  19 fail  0 crash/timeout  4 skip  (total 283)
grep -c 'X connection to :0 broken'  = 0     <- the run IS a measurement
grep -c 'revive FAILED'              = 0     <- the gate held all the way through
scratch dirs leaked                  = 0     <- `git status` unchanged but for the expected files
wireedit suite                       = PASS (8/8)
```

**The item's own tests, inside the audit:** `test_wave_sigsearch` **PASS** and
`test_wave_viewer` **PASS**. This matters more than the solo soak: audit load is exactly
the condition under which the verifier's AT18 flake, and item 4's deleted BAR25, revived.

**Fails vs the HARD baseline (16 names):** 15 of the 16 FAILED, and
**`test_fluid_editing` SKIPped rather than failed** — identical to the verifier's own
solo audit. No HARD name failed on a *different* check than the PLAN's Baseline block
records (`test_cadence_drag` excepted by the baseline's own re-anchoring clause).

**Four non-HARD fails, all re-run and all disposed of:**

| name | audit | 3x (and 6x) solo re-run | on the FLAKY list? | disposition |
|---|---|---|---|---|
| `test_ase_unnamed_net` | FAIL `AN8` | **2 pass / 1 fail**, the fail again `AN8` | **yes, and the list NAMES `AN8`** | baseline flake |
| `test_deselect_mode` | FAIL (DM8/DM9/DM10b) | **3/3 PASS** | **yes** | baseline flake |
| `test_wave_markers` | FAIL `MX5`,`MX11`,`MX12` | **6 solo runs: 4 pass / 2 fail — the fails are `MF1` EVERY time, `MX*` NEVER reproduced** | **yes, and the list NAMES `MF1`** | baseline flake; the `MX*` set is a load artifact of the audit, and it did not survive six solo attempts |
| `test_wave_trace_menu` | FAIL `TG9` | **6 solo runs: 4 pass / 2 fail, always `TG9`** | **no — the PLAN de-excused it after two clean re-baseline runs** | **see below: recommend RE-listing** |

**`test_wave_trace_menu` / TG9 — report to the driver, NOT item 5's.** The PLAN's Baseline
block de-excused TG9 because it *"passed both re-baseline runs"*. Measured here it fails
**2 in 6** solo runs on a tree where item 5 cannot reach it — so at that rate the
probability of two consecutive clean runs is ~0.44, i.e. **the de-excusing evidence is
weaker than a coin flip and does not carry.** The older lore (TG9 root-coords, ~4-in-10
under WSLg) matches what is measured. **Recommend TG9 goes back on the FLAKY list.**

**Item-5 inertness for all four, checked statically, not asserted:** `test_ase_dialogs`
and `test_ase_unnamed_net` contain **zero** references to any identifier this item touched.
`test_wave_markers` (2 hits) and `test_wave_trace_menu` (12 hits) reference only
`wviewer::add_trace` — a **different proc**, and `git diff -U0 src/wave_viewer.tcl`'s hunk
headers show every source hunk landing in the `namespace eval wviewer` block, the item-4
comment section, `add_trace_dialog`, or the three appended procs. **`wviewer::add_trace`
is not touched by a single diff line.**

**`test_ase_dialogs` (the verifier's new non-baseline name):** **PASS in this audit**, and
**3/3 PASS** solo. Combined with the verifier's audit FAIL + 1-fail-in-3, that is 5 passes
and 2 fails across two agents, with a *different* fail set each time. **FLAKY, and inert
to item 5** (zero identifier hits). §9 carries the recommendation.

**`test_hier_close_prompt` (driver note f):** **PASS in this audit** and **3/3 PASS** solo,
on top of the first round's 3/3 and the verifier's and scout's clean audits. **Recommend
NEITHER list.**

## 9. Carried forward to the driver

- **R9 residual, NOT closed by this item.** Item 4's `u6` (the searchbar's own `%W` guard is
  still dead code by the frame rule — item 5 does not change that; **note the guard in
  `add_trace_forget` is a different case entirely and is live, measured, and pinned by
  AT20**), and **P1**, the twice-rotted line number at `src/xschem.tcl:4548`
  (*"sourced unconditionally at xschem.tcl:14352"*). `src/xschem.tcl` is outside item 5's
  Files line, so fixing it here would be a silent scope widening. Item 4's recommendation
  stands: replace the number with a grep-able phrase, since any number rots. (Item 5 applied
  exactly that remedy to the one comment it *did* own — D10b.)
- **`test_hier_close_prompt`: recommend NEITHER list** (3/3 pass in the first round, 3/3
  again in the fixup round, §5 — plus the scout's and the verifier's own clean audits. Six
  green data points from three agents; it is not flaky and it is not a baseline fail).
- **`test_ase_dialogs`: recommend the FLAKY list. NOT item 5's.** Reported by the verifier
  and re-measured here, §8. Item 5 is **statically inert** with respect to it:
  `tests/headless/test_ase_dialogs.tcl` contains zero references to `wviewer`,
  `add_trace` or `wave_viewer`, and item 5's diff is confined to the `wviewer` namespace
  plus its own test group. Its fail set is different on every failing run, which is the
  signature of ASE-L state-file leftovers, not of a regression.
- **`test_wave_trace_menu` / TG9: recommend RE-LISTING as FLAKY.** Measured 2 fails in 6
  solo runs this round (§8), which makes the PLAN's *"it passed both re-baseline runs"*
  a ~0.44-probability coincidence rather than evidence. Item 5 is inert to it.
- **DRIVER DECISION REQUESTED — the Search button (§6 D15).** Note (b) suggested
  `-showbutton 0`; settled decision 5 mandates the button. The button is currently PRESENT
  (decision 5 wins), and it is the widest child in the widest row, i.e. the main driver of
  the WIDTH risk in §7 item 1. If the eyeball rejects the width, the choice between
  "drop the button" and "shorten/tooltip the error label" is a **ruling**, not an
  implementer's fix.
- **Item 6 inherits a live fixture**: `at_open`, `at_lb`, `at_wait_mapped` and `at_throwcb`
  are left defined on purpose, and `$w.vars` is now `-selectmode extended` — the thing item
  6 consumes. **Item 6: if you assert anything about focus, a caret, a grab or a
  `<Visibility>`-dependent geometry, go through `at_wait_mapped` — §10 is the reason.**

## 10. THE FIXUP: AT18, from flake to pinned

**The verifier's blocker, restated:** AT18 read `focus -lastfor $atw` behind a single
`update` and asserted `$atw.expr`. It failed 3 times in 22 solo runs, always with the
TOPLEVEL as the value.

### 10.1 Mechanism, re-measured here (not taken on trust)

A standalone Tk probe (12 iterations, fresh toplevel + two entries + `focus` on the first):

| observation | result |
|---|---|
| `focus -lastfor` immediately after `focus $e`, toplevel not yet mapped | **the TOPLEVEL, 12/12** |
| after ONE `update` | the entry **only when `winfo ismapped` had turned 1**; 3 of 12 were still unmapped, and still read as the toplevel |
| after a bounded poll on `winfo ismapped` | **the ENTRY, 12/12 — including all 3 late-mapping iterations** |

The last row is the part the verifier's probe did not establish, and it is the part the
repair rests on: **Tk does not discard a `focus` request made on an unmapped toplevel; it
records it and applies it at MAP time.** So the value AT18 wants is not lost, it is merely
*not yet settled* — which makes this a WAIT problem, i.e. repairable by WIDENING, and not a
"the claim is unmeasurable" problem, which would have forced deletion.

### 10.2 The repair

`at_wait_mapped` (a new helper beside `at_open`/`at_lb`) polls `winfo ismapped` with
`after 10 ; update`, budget **15 s**, then one final `update`. It is called once, right
after the dialog opens. AT18 became:

```tcl
  check {AT18 mapped, and focus goes to the Expression entry not the search bar} \
    [list [winfo ismapped $atw] [focus -lastfor $atw]] [list 1 $atw.expr]
```

Three properties, deliberately:
* **It polls the PRECONDITION, never the asserted value.** A loop that spun until
  `focus -lastfor` equalled `$atw.expr` would be a "wait until green" tautology that can
  only ever report a timeout. This one waits on mapping — an independent fact — and then
  reads the focus record **cold, once**.
* **`ismapped` is IN the tuple.** If the budget ever expires, the failure prints
  `{0 .wvat1.wvadd}` and says "never mapped"; a real focus theft prints
  `{1 .wvat1.wvadd.wvsearch.pat}`. The two failure modes can no longer be confused — which
  was the other half of what made the original check bad evidence.
* **It is not a self-skip.** Item 4's BAR25 lesson says a check whose only oracle is "did
  the thing happen" must not be made conditional, because that masks the regression it
  exists to catch. AT18 still FAILS if the map never comes.

### 10.3 Measurements

**Instrumented soak, 25 solo runs, idle machine** (temporary diagnostic printing the
pre-wait state and the wait duration; removed before commit, tree md5-verified):

* **25/25 `RESULT: ALL PASS (139 checks)`**.
* **3 of the 25** were `pre m=0 rec=.wvat1.wvadd` — i.e. **the OLD form would have failed
  exactly those 3**. 3-in-25 reproduces the verifier's 3-in-22 almost exactly, which is the
  best confirmation available that this repair addresses THE observed defect and not a
  lookalike.
* Those three needed **1927 ms, 3233 ms and 3479 ms** more before the map. The other 22 were
  mapped in ~10 ms. The 15 s budget is 4.3x the worst measurement and an eighth of
  `full_audit.sh`'s 120 s per-test timeout.

**Severance proof (the check is not hollow) — sabotage `S-AT18`:** delete `focus $ee` from
`add_trace_dialog`. Result: **AT18 alone, 1 FAILED / 138 passed**, got
`{1 .wvat1.wvadd}` — note `ismapped 1`, which is the wait doing its job and the assertion
failing on the focus record, exactly as designed. Reverted from a byte-exact snapshot,
md5 re-verified.

**Sabotage `E5` re-run against the repaired check** (`focus $sb.pat` after `focus $ee` —
the bar STEALS the focus): **AT18 alone**, got `{1 .wvat1.wvadd.wvsearch.pat}`. Both
directions of the claim are therefore pinned: nobody removes the focus call, and nobody
takes the focus for the bar.

### 10.4 What is STILL not pinned (ruling 17: the claim is narrowed to the coverage)

* the visible **caret** (§7 item 3);
* that the **window manager** hands the focus to this toplevel at all — AT18 reads Tk's
  per-toplevel record, which exists whether or not the WM cooperates;
* end-to-end **X key delivery** into the dialog (unchanged, D5).
