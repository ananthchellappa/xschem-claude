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
