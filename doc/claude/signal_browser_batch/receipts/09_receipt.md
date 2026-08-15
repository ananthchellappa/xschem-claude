# Item 09 — PIXEL — browser content: tree + search + filter — RECEIPT

*§1-§11 are the implementer's. §12 is the independent verifier's stage (`ok: true`,
`scopeClean: true`) — its own re-runs, its three unnamed sabotages, and the one minor
problem it carried forward. §13 is the ledger line.*

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `f3c89935`
(item 8's sidebar shell). **Commit: `46f89349`** — `feat(wviewer): Signal Browser tree,
search, filter`. **NOT pushed.** Date 2026-08-05.

**Filename note:** the PLAN's per-item Receipt line says `receipts/09_browser_tree.md`.
Every receipt on disk is `NN_receipt.md` and the task prompt says `09_receipt.md`, so
that is what this is. The PLAN's Receipt lines have been wrong since item 7
(`07_destination.md` vs the actual `07_receipt.md`); flagged for the driver, not fixed
here.

---

## Verdict: `[E]` — implemented, measured, sabotage-verified. **Never `[x]`.**

This is a PIXEL item. Three of its four deliverables are pinned by checks; the fourth —
what the sidebar *looks like* next to a real canvas — is not something a check can
judge, and §7 states exactly what was looked at and what a human still owes.

The one clause of the Eyeball that CAN be turned into evidence has been: the
2000-signal population-speed question is discharged as **two printed numbers, asserted
in-suite** (§7), not as an opinion.

---

## 1. Files touched

| file | what changed |
|---|---|
| `src/wave_viewer.tcl` | the item-9 block: `browser_rows`, `browser_kind`, `browser_leaf_names`, `browser_match_one`, `browser_and` (pure); `browser_reload`, `browser_match`, `browser_status`, `browser_refresh`, `browser_populate`, `browser_search_cb`, `browser_filter_cb` (state + refresh); `browser_plot_ids`, `browser_plot_selection`, `browser_plot_at` (the three gestures); `browser_width` (the width rule). Plus: `browser_build` extended, `browser_show`'s pack branch sizes and repopulates, the two new namespace arrays, `forget`'s declare+unset, and one narrowed comment on `browser_toggle`. |
| `tests/headless/test_wave_sigbrowser.tcl` | the **BT** group (item 9's prefix, per the file header's table), appended per settled decision 9. Plus two edits to item 8's own checks — both **widenings**, §6. |

**Not committed** (the driver's ledger commit picks them up): this receipt, `PLAN.md`,
and the other untracked batch bookkeeping. Nothing else under `src/`, `tests/` or `doc/`
was touched.

**No C.** Decision 8 holds: this is Tcl over `wviewer::signal_list` (which is itself
`xschem raw list`), and no `scheduler.c` branch was needed or added.

---

## 2. What was built, and the one line each piece exists for

* **`browser_rows {entries}`** — the PURE half. Item-2 dicts in, an ordered row list out
  (`{id parent text kind name}`), parents always before children. Groups minted lazily,
  one per **dot segment** of `path`, in first-appearance order, so ruling 14's split gives
  `v(x1.x2.net5)` → `x1 > x2 > net5` and no node is ever called `v(x1`.
  **FLAT when no entry has a path.**
* **The `g:` / `s:` id prefixes and the `#<n>` de-dup** — not styling. MEASURED: inserting
  a duplicate treeview id **throws** (`Item ... already exists`), and populate rides the
  searchbar `<KeyRelease>` pump, where a throw is bgerror, which is modal under X and
  hangs a headless run. A raw signal literally named `x1.x2` and the group `x1.x2` minted
  by `v(x1.x2.net5)` are exactly that collision; BT12 pins both halves.
* **`browser_and {sigs d1 d2}`** — THE AND, and the only place it lives. Written as two
  explicit `browser_match_one` calls rather than a loop so the one line carrying the whole
  claim — `[lindex $r1 1]` as the second call's input — is visible, greppable and singly
  sabotageable. It ANDs the two type dropdowns for free. An `err` from either bar
  short-circuits (decision 4).
* **`browser_refresh`** — match → rows → treeview → status line, and it **cannot throw**:
  every risky call is catch-wrapped, every exit is a guard. On `{err msg}` it **holds the
  last good tree** and mirrors the message to the status line.
* **The three gestures** all converge on `wviewer::plot_signals`. Nothing in the browser
  reads `plot_dest`, `plan_plot` or `dest_prepare` — ruling 24, asserted by BT06.
* **`browser_width`** — the measured width rule, §5.

---

## 3. Suites

| run | result |
|---|---|
| `test_wave_sigbrowser.tcl`, `--nogui` arm | **ALL PASS (91 checks)** |
| `test_wave_sigbrowser.tcl`, DISPLAY arm | **ALL PASS (216 checks)** |
| `test_wave_grid.tcl` (the GH0 literals) | **ALL PASS (245 checks)** — no bump owed, §6 |
| full `tests/headless/full_audit.sh` | see §4 |

**Checks: 216 total in the X arm, 132 of them new** (131 `BT*` + one new `BS22` leg).
63 of the new ones run in `--nogui` (28 → 91).

No group self-skipped in the shipping run: BT28/BT29/BT43 all found their rows mapped and
all real-viewer legs (BT40-BT47) executed.

---

## 4. Non-baseline fails: **NONE**

`tests/headless/full_audit.sh`, one run: **256 pass / 24 fail / 0 crash / 4 skip
(total 284)**. `WIREEDIT: PASS`. `SCRATCH: 0 leaked dir(s)`.

**Three of those 24 were not measurements.** `test_add_pin_lib_symbol_view`,
`test_perform_action_flipv_in_place` and `test_perform_action_replace_symbol` each
produced exactly:

```
X connection to :0 broken (explicit kill or server shutdown).
```

and nothing else — the WSLg Xwayland abort. `/mnt/wslg/stderr.log` corroborates it with
an `msrdc.exe … exited with status 0` at **13:04:41**, inside the audit window
(ruling 19: check that log before blaming the harness). All three were re-run under the
gate afterwards and **all three pass** (`test_add_pin_lib_symbol_view` prints
`OVERALL: ok`, `PASS=12 FAIL=0`; it reports no `RESULT:` line, so `run_suites.sh` scores
it `NORESULT` — a harness wording mismatch in that test, pre-existing and not item 9's).

**The remaining 21 are the baseline, exactly — 16 HARD + 5 FLAKY, no additions:**

* HARD, all 16 present and each failing on the check the PLAN's Baseline block records:
  `test_ase_log_seam_0207`, `test_ase_window` (W7), `test_cadence_drag` (re-anchored),
  `test_ciw` (PS*), `test_fluid_editing` (FE8), `test_gf180mcud_libmgr`,
  `test_ihp_sg13g2_libmgr`, `test_sky130a_libmgr` (all three: `library_list` with the
  user-level `{SANDBOX TEST}` extras — cluster (b)), `test_lib_manager_gui` (GUI8/GUI9),
  `test_lib_manager_locate` (LM-LOC3), `test_lib_sweep` (M1), `test_phase3_mints` (P1-P4),
  `test_reopen_readonly` (R10), `test_rotate_stretch_short_0104` (rot180-ip),
  `test_select_at` (SA5-SA8b), `test_selflog_output` (the six key-logs-transform lines).
  The action-log cluster (a) — ciw / select_at / selflog / phase3_mints / ase_log_seam —
  fails on "action log open"-shaped checks exactly as the Baseline block predicts.
* FLAKY, 5 of the listed names: `test_altf5_ciw`, `test_ase_unnamed_net` (AN8, the
  documented check), `test_pristine_untitled_viewer_0172`, `test_remap`,
  `test_sod_pick_no_select_0204` (SO10a/SO11d/SO14d).

**Every one of the sixteen wave suites PASSED**, including the ~50 % flake
`test_wave_trace_menu`, and including `test_wave_sigsearch` (items 1-7's file, untouched)
and `test_wave_grid`. No A/B against a reverted `wave_viewer.tcl` was needed, because
nothing outside the baseline failed.

---

## 5. THE MEASURED PIXEL DEFECT, and the fix the plan did not have

The scout measured that one `searchbar_build` wants **755 px** (680 with
`-showbutton 0`), and that with pack propagation ON a 700 px toplevel produced sidebar
width 700 **and** canvas width 700 — a broken layout, not a narrow one. The plan's answer
(A5) was `pack propagate 0` plus a derived width. **That answer, implemented literally,
did not work**, and the test caught it:

```
top w=1400  sidebar w=240   <- the FLOOR, not the intended 583
search x=0 w=1 mapped=0     <- settled decision 5 silently defeated
```

**Why:** a frame's `reqwidth` is computed by the packer **on the idle queue**. Straight
after `pack $f`, `winfo reqwidth $f.wvsearch` still reports 1, so `755 - 172` evaluated as
`1 - 1 = 0` and the 240 px floor took over. One `catch {update idletasks}` before the
measurement fixes it:

```
top w=1400  sidebar w=583  canvas w=817
search x=502 w=69 mapped=1     <- decision 5 honoured
err    x=577       mapped=0    <- DECLARED LIMIT D1
```

**And the second-order effect is the more interesting one.** With the sidebar collapsed to
240 px the search entry was clipped off-screen, and **Tk would not deliver a synthetic
`<KeyRelease>` to it at all** — so the live-filter checks failed with the tree simply not
changing, which reads exactly like "the callback is not wired". A pixel bug masquerading
as a logic bug. It is worth stating plainly: the geometry defect and the "binding does not
fire" symptom were the same defect.

---

## 6. Two edits to item 8's own checks — BOTH WIDENINGS (ruling 17)

1. **`BS22`'s ONLY-child leg.** It asserted `[winfo children .wvbs1.wvbrowser]` equals
   exactly `.wvbs1.wvbrowser.ph`, which filling the sidebar necessarily falsifies. The
   label **survives** — repurposed as item 9's status/error line — so the exists / class /
   "says what it is" legs are untouched; only the only-child leg was rewritten, into an
   assertion of the **full item-9 child set** plus "`.ph` is still child #1". That is
   strictly more coverage: it now also fails if a child is dropped or renamed. Mirrored by
   BT21 on the item-9 fixture.
2. **`BS08`'s NAME and comment.** It read "browser_toggle neither captures nor
   regenerates" under a comment claiming the toggle "changes WIDGET GEOMETRY only … no
   context switch". Toggling ON now **repopulates**, and that read takes a 0173 context
   loan — one level down, inside `wviewer::signal_list`. So the three greps stay green **by
   construction** rather than by luck, which is precisely the shape of a check name that
   overstates what it pins. Renamed to "browser_toggle's **own body** neither captures,
   regenerates nor switches", with the loan's real location written into both the test
   comment and the source comment. **The claim was narrowed; the coverage was not reduced.**

**No key, no menu entry, so `test_wave_grid`'s GH0 literals need no bump** — and that
claim is itself asserted, twice: BT09 greps every item-9 proc body for `bind WaveViewer`
and for menu `add`, and re-counts the guide's 15 `data-seq` rows / 10 menu accelerators.
`test_wave_grid` was re-run green (245) to confirm.

---

## 7. EYEBALL — `[E]`. What was looked at, what was measured, what a human still owes

### 7.1 DISCHARGED AS EVIDENCE — the 2000-signal clause

Not an opinion. Two printed, asserted numbers, both re-measured every run:

```
BT17 browser_rows over 2000 signals: 14-20 ms, 2220 rows     (asserted < 2000 ms)
BT33 browser_refresh over 2000 signals: 15-16 ms             (asserted < 5000 ms)
```

`browser_refresh` there is the whole real path — both searchbar reads, the chained
`sig_match` AND, `browser_rows`, and 2220 real `ttk::treeview` inserts. A 2000-signal raw
populates the sidebar in **~15 ms**. The thresholds are deliberately ~100× the measurement:
they are "not unusably slow" guards, not benchmarks.

### 7.2 LOOKED AT (by the implementer, on WSLg)

* **Indentation and nesting** — real ttk parents, confirmed structurally as well as
  visually: `$tv parent s:v(x1.x2.net5)` is `g:x1.x2`, whose parent is `g:x1` (BT24, BT42
  on a real raw). Groups are inserted `-open 1`, so the hierarchy is what you see rather
  than something you have to go find.
* **Column width** — `#0` set to 200 px, `-minwidth 80 -stretch 1`, inside a 583 px
  sidebar with a scrollbar on the right.
* **Sidebar vs canvas on a real viewer** — canvas stays packed, non-zero, and wider than
  the sidebar (BT45), packed order still `a-before-b`.

### 7.3 NOT CLAIMED — what a human still owes

* **The 583 px sidebar is WIDE.** On a 1400 px window that is 42 % of the toplevel, and it
  is wide *because settled decision 5 requires the Search button to be visible* and item 4's
  bar is 755 px. It is under the 45 % cap by design, not by accident. Whether that reads
  as "a sane sidebar" is a judgement, and the judgement is the human's.
* **The small-window case**, where the 45 % cap binds and both bars clip further. The
  status-line error mirror is what keeps decision 4 alive there; that it *reads* well at
  300 px is not asserted.
* **Repaint on toggle and on tree scroll.** The viewer toplevel's unguarded
  `<Visibility> -> raise_dialog` (xschem.tcl) now also fires for browser-subtree visibility
  churn. Pre-existing; item 8 already added a child frame without trouble. Watch-item, not
  a blocker.
* **Colour/theme** — `ase::ui::apply_theme` is applied to the whole sidebar and its
  `Treeview` arm already existed; nobody has looked at the result against the ASE palette.

---

## 8. Declared limits — every one measured, none inferred

* **D1 — the bars are wider than any sane sidebar.** 755 px with the button, 680 without
  (type 97, pat 204, syntax 87, case 92, search 69, err 172, plus padding). At the derived
  583 px the **Search button is mapped (x=502) and the error label is clipped
  (x=577, ismapped 0)** — asserted as a limit by BT23, mitigated by mirroring the message
  into the status line (BT27). Re-laying out item 4's widget was **not** done; that would
  need a `[D]`.
* **D2 — Replace-under-multi.** Inherited through `plot_signals` (ruling 24): under
  multi-plot, `plan_plot` emits no clear key, so a browser gesture offering Replace is
  really offering Append. **Asserted as the declared limit it is** (BT44), not pretended
  away, and not item 9's to fix.
* **D3 — a double-click on a GROUP does not plot.** ttk's expand/collapse owns that
  gesture. MMB and the Plot button do plot a group's leaves. Both halves asserted (BT29),
  and the asymmetry is what makes the zero a rule rather than a dead recorder.
* **D4 — item 8's BS22 was widened and `.ph` repurposed.** §6.
* **D5 — BS08's name and comment narrowed.** §6. The 0173 loan lives in `signal_list`.
* **D6 — the inventory is a SNAPSHOT.** `browser_reload` runs when the sidebar is SHOWN,
  not continuously; a raw loaded afterwards needs a re-show. That is what makes a keystroke
  cost no context loan (item 5's `atdsigs` precedent). Item 13/15 territory.
* **D7 — NEW, and stated rather than papered over. "Row order" means RAW-FILE order, not
  the tree's visual order.** ttk re-parents a late arrival under the group it belongs to, so
  a raw listing `v(x1.x2.n) v(x1.y3.n) i(x1.x2.n)` **draws** the two `x1.x2` leaves adjacent
  while `browser_leaf_names` still returns them first-and-last. Plotting a group therefore
  plots in raw order. Written into the source comment and asserted with that wording in
  BT29 ("in raw order"), because the check name would otherwise overstate what is pinned.
* **D8 — NEW: `browser_width` needs `update idletasks`.** §5.

---

## 9. Divergences from the PLAN, every one with its reason

### 9.1 THE PLAN'S SLAVE-ORDER ORACLE IS RIGHT BUT ITS *SEMANTICS* ARE NOT WHAT THE PLAN ASSUMED

Driver note (b) said: reuse `bs_order`, because widths cannot see `-before`. True, and
`bs_order` is used — for the sidebar-vs-canvas claim (BT21, BT45), where it is exactly
right.

But the plan also specified `bs_order` for the sidebar's **internal** layout ("slave order
puts `.wvfilter` after `.tvf` and `.ph` last"). **That is false, and it is false by
construction:** `pack slaves` reports **packing** order, and for a mixed `-side top` /
`-side bottom` stack, packing order is *not* visual order. `.ph` and `.wvfilter` are packed
**before** `.tvf` precisely so that the tree — packed last with `-expand 1` — takes
whatever is left *between* them. Written as the plan specified, the check would have
failed on correct code.

Resolved by **widening rather than weakening**: BT21 asserts the whole `pack slaves` list
*and* each slave's `-side` *and* the tree's `-expand`, which is the recipe that actually
produces search / toolbar / tree / filter / status top to bottom. This is note (b)'s own
lesson one level deeper: **when the plan names an oracle, verify what the oracle actually
measures — not merely that it can see the thing.**

### 9.2 `event generate <Double-Button-1>` IS ILLEGAL — MEASURED

Tk answers `Double, Triple, or Quadruple modifier not allowed`. A double-click is not an
event; it is a **pattern Tk's binding layer recognises in the press/release stream**. The
only way to drive the real route (driver note f: the REAL Tk route, not the handler
behind it) is to replay the stream — two `ButtonPress-1`/`ButtonRelease-1` pairs at the
same spot. `bt_dclick` does exactly that, and sabotage (b) confirms the double-click and
MMB routes are genuinely separate.

### 9.3 A SYNTHETIC KEY EVENT NEEDS FOCUS — MEASURED, and it is the same trap as item 4's

`event generate $entry <KeyRelease>` on an **unfocused** entry does not run the entry's
binding: Tk redirects key events to the toplevel's focus window. The tree simply did not
change, which is indistinguishable from a callback that was never wired — the
gesture-test-full-sequence lesson in a new costume. `bt_type` now focuses, **confirms the
focus landed**, and **returns whether delivery happened**, and that flag is carried in the
asserted tuple (`{1 <tree>}`), so a WSLg focus stall reads as `0` instead of masquerading
as a broken filter.

### 9.4 `pcall` ON EVERY HARD-CODED ROW ID — found by sabotage (c), not by review

`$tv parent g:x1.x2` **throws** when the row is absent. The first run of sabotage (c) hit
that inside a check, the throw escaped to the file's outer catch, and **51 later checks
never ran** while the printed fail count still looked plausible. That is item 6's
"a check that THREW instead of failing" trap, reproduced exactly. Every hard-coded row id
in the fixture and real-viewer groups is now `pcall`-wrapped; sabotage (c) re-run after
the guard fails 24 checks and **aborts nothing**.

This is the strongest argument in the item for sabotage-verification as a practice: the
defect was in the *test*, was invisible on green, and only a deliberate break exposed it.

### 9.5 Procs the plan did not name

`browser_match_one` (one bar applied to a name list, `{}` = identity), `browser_kind`
(`group`/`leaf`/`{}`), `browser_populate` (rows → widget) and `browser_status` (the status
line). All four are extractions that make a single claim greppable and singly
sabotageable; none adds policy.

### 9.6 Test numbering

BT18/BT19 unused (the pure arm needed nine numbers, not ten). The real-viewer group runs
BT40-BT47 rather than the plan's BT40-BT45 — the bindtag collision claim earned a real
viewer leg (BT46) of its own, and teardown got BT47.

### 9.7 GUI gate

Every DISPLAY run went through `tests/headless/gated_xschem.sh` or `full_audit.sh`. The
human had a 2 h window open throughout; no run was paused, no gate file was written by
hand, `GUI_GATE` was never set.

---

## 10. Sabotage table — all three named, each injected, measured, reverted, re-run green

Revert method: `src/wave_viewer.tcl` was copied to the scratchpad **after** item 9's work
and **before** the first injection; each sabotage was applied to that file, `diff` against
the pristine copy was shown to contain **nothing but the injection**, and the copy was
restored. A plain `git checkout --` would have discarded item 9 entirely (the work is
uncommitted), so `git diff` alone could not be the oracle here — that is stated rather
than glossed.

| # | injection | predicted | MEASURED | outside the claim |
|---|---|---|---|---|
| **(a)** break the AND — feed the 2nd `sig_match` the ORIGINAL `$sigs` | BT01 / BT14 / BT26 | **17 FAIL**: BT01 ×2 (source), BT14 ×3, BT15 ×3, BT16 ×1 (pure), BT25 ×3, BT26 ×3, BT27 ×2 (live) | **NONE.** Every failing check is the AND claim, at three levels — ruling 23's superset, not a widened target. Tree shape, gestures, layout, real viewer all green. |
| **(b)** delete `bind ... <Button-2>` | BT04 / BT28 / BT43's MMB leg | **5 FAIL**: BT04 ×2 (source), BT28, BT29's MMB leg (fixture), BT43's MMB leg (real viewer) | **NONE.** Double-click and Plot-button checks stayed GREEN — that asymmetry is the proof the target was single. |
| **(c)** flatten the grouping (`if {0 && $anypath …}`) | BT02 / BT10 / BT24 / BT42 / BT32 | **24 FAIL**: BT02 (source), BT10 ×2, BT11's mixed leg, BT12, BT13 ×3, BT17's grouping leg (pure), BT24 ×2, BT25 ×2, BT26 ×3, BT27 ×3, BT32 ×2, BT33 (fixture), BT40, BT42 (real viewer) | **NONE.** Every one is the grouping claim. **BT11's FLAT leg stayed green** — the discriminator that says the tree flattened rather than that `browser_rows` broke. The AND checks (BT01/14/15/16), the leaf gestures (BT28/29/30/31), the layout (BT21/22/23) and BT34/43-47 all green. |

All three reverted; the clean re-run after each is **ALL PASS (216)** under X and
**ALL PASS (91)** in `--nogui`. Sabotages (a) and (b) were each re-run a second time
against the **final** test file (after the §9.4 `pcall` guards landed) to be sure the
guards had not changed their footprint — identical fail sets both times.

---

## 11. If a human looks at one thing

Open a viewer with a real raw, press **Ctrl-L**, and look at the sidebar's **width**
against the canvas. Everything else in this item is pinned by a check that fails when it
is wrong; that one number is a settled trade (decision 5's Search button vs the canvas's
share) whose *rightness* is a judgement no check can make.

*(This item did NOT fail, so there is no "what a human needs to look at first" in the
failure sense. The line above is the EYEBALL entry point, not a defect report.)*

---

## 12. VERIFIER STAGE — `ok: true`, `scopeClean: true`

Independent session, working against the **committed bytes** of `46f89349`.

### 12.1 What it re-ran, and whether the numbers held

| re-run | result |
|---|---|
| `git show --stat 46f89349` | touches **only** `src/wave_viewer.tcl` + `tests/headless/test_wave_sigbrowser.tcl`; `git status` shows no other tracked diff under `src/`, `tests/`, `doc/` — receipt correctly left untracked per the driver's bookkeeping rule |
| `gated_xschem.sh … test_wave_sigbrowser.tcl` (X arm) | **216 passed / 0 failed** — MATCHES the claim (216 total, 132 new over item 8's 84) |
| `--nogui` arm | **91 passed / 0 failed** — MATCHES (63 new over 28). Skip banners use the non-`is_skip` wording, so blocked groups do **not** inflate `full_audit`'s skip count |
| `full_audit.sh` (all 284) | **260 pass / 22 fail / 1 crash-timeout / 1 skip** |
| targeted re-run of the 6 X-death / suspect names | **6 pass, 0 fail, 0 crash, 0 skip, ZERO `X connection` lines** |
| clean re-run after all three verifier sabotages reverted | **216 passed / 0 failed** |

**Non-baseline fails: NONE — confirmed independently.** The verifier's audit log carried
**4** `X connection to :0 broken` hits, corroborated in `/mnt/wslg/stderr.log` by
`weston: ../xwayland/window-manager.c:1387: weston_wm_handle_map_request: Assertion
!window->shsurf failed` plus a WSLGd restart at **13:32:50** (ruling 19). Re-running
`test_perform_action_change_elem_order`, `test_perform_action_instance_number`,
`test_perform_action_move_instance`, `test_pin_name_size_win`, `test_wave_legend` and
`test_launch_context` gave 6/6 pass with no X deaths, leaving the remaining fail set as
**exactly the 16 HARD baseline names + `test_wave_trace_menu`**. Both sessions therefore
report `nonBaselineFails = []`, from two different audits with two different X-death sets.

**Ruling-22 A/B on `test_wave_trace_menu`** (it failed TG10 in the verifier's audit):
3× at HEAD → **3/3 ALL PASS** (397 checks each); then `git checkout f3c89935 --
src/wave_viewer.tcl` and 3× again → **1/3 FAIL** (7 failed / 390 passed). The flake
reproduces **without** item 9 and is the documented ~50 % TG9/TG10 root-coords family.
Item 9 cleared; the tree was restored to `46f89349` and diffed byte-identical.

### 12.2 The verifier's three UNNAMED sabotages — none of them the PLAN's three

Each was applied to the committed file, measured, reverted with `git checkout --`, and
diffed byte-identical against a pristine copy.

| # | injection (nobody named these) | MEASURED | reverted | reading |
|---|---|---|---|---|
| **V1** | break the AND at the **WIRING** level, not inside `browser_and` — `set d2 [wviewer::searchbar_get $f.wvsearch]` in `browser_match`, so the filter bar is never read at all | **7 FAIL**, all `BT26`/`BT27`, each showing the **unfiltered superset** as the got-value | yes, diffed byte-identical | the AND is pinned at the WIRING seam too, not only inside the pure proc that sabotage (a) hit. Different injection point, different fail set, same claim. |
| **V2** | remove `catch {update idletasks}` from `wviewer::browser_width` | **1 FAIL**: `BT23` "at 1400 px the top bar's Search button is MAPPED, not just present" → `{1 0}` | yes, diffed clean | §5's width rule has a **real observable**. See 12.3 for what this run did *not* reproduce. |
| **V3** | sever the Plot toolbar button's `-command` (`[list list ignored $token]`) | **4 FAIL**: `BT30` ×1, `BT31` ×1, `BT32` ×2 — all of them driving the real `$BTF.tb.plot invoke` route against the `plot_signals` spy; MMB and double-click stayed **green** | yes, diffed clean | the target was single. It also **exposed the one problem below.** |

### 12.3 Problem 1 — MINOR, NON-BLOCKING, carried forward to item 10 (ruling 17)

**`BT44`'s two real-viewer checks are named as GESTURES but call the HANDLER.**
`tests/headless/test_wave_sigbrowser.tcl:1491` and `:1503` call
`pcall ::wviewer::browser_plot_selection $tok` directly, under the names *"a Plot-button
**gesture** under newstrip created a new strip"* and *"under multi, a Replace **gesture**
APPENDS (declared limit D2)"*. That is exactly driver note (f)'s warning — drive the REAL
Tk route, not the handler proc behind it.

**Proven, not inferred:** under sabotage **V3** (the button's `-command` severed)
BT30/BT31/BT32 failed and **BT44 stayed GREEN**.

**Coverage is not missing, but no single check spans the whole route.** The real
`$BTF.tb.plot invoke` route is pinned by BT30/31/32 in the fixture arm, and BT43 drives the
real MMB and double-click against real traces. What no one check does is
*(real button route → real trace added)* — only the composition does.

**Fix, one line, in item 10** (it re-touches these gestures anyway): swap to
`$BTVF.tb.plot invoke`, or narrow the names to say "the Plot **handler**". This affects
neither the implementation, the audit result, nor any settled decision. Ruling 17 is why it
is written down at all: *a check name that overstates what it pins is itself a defect.*

### 12.4 Problem 2 — an OBSERVATION, not a defect: the coupled-symptom story

§5 claims the missing `update idletasks` also broke synthetic `<KeyRelease>` delivery to the
search entry — "the pixel bug and the binding-does-not-fire symptom were ONE defect". The
verifier re-injected exactly that removal (**V2**) and got **one** failure, `BT23`; the
live-filter checks `BT25`/`BT26` **stayed green**.

So: the **width claim itself is genuinely covered**, and the coupled-symptom account is a
**development-time observation at a different window size** that does not reproduce at the
shipped fixture size. Recorded here as observed rather than as a pinned claim. No action.

### 12.5 What else the verifier checked by GREP rather than by claim

* Settled decisions re-verified in the source, not taken on trust: `browser_reload` derives
  content from `wviewer::signal_list` **only** (decision 13 — no rect-model read anywhere in
  the browser procs); **no** browser proc reads `plot_dest`, `plan_plot` or `dest_prepare`
  (ruling 24); the top bar keeps its Search button and the bottom is `-showbutton 0` named
  `wvfilter` (decision 5 / ruling 20); `-selectmode extended` present; the commit is
  **Tcl-only** (decision 8); appended to the second test file (decision 9).
* The new test code read for **tautologies**: expected values are literals, not
  self-computed; `bt_ents` uses the REAL `wviewer::signal_entry` so ruling 14's path/leaf
  split is *exercised* rather than re-implemented; `bt_tree` returns a three-shape assertable
  string (no-tree / empty / row list) so "never built" and "filtered to zero" are
  distinguishable; `bt_type` returns and asserts a focus-delivery flag; the plot spy has both
  a positive and a negative control. `BT16`'s "byte for byte" leg computes its expected by
  calling `sig_match` — judged **legitimate**, since the claim is precisely that
  `browser_and` propagates the message unrewritten.
* The two item-8 edits confirmed to be **widenings, not deletions** (ruling 17), per §6.
* The receipt-filename divergence confirmed real and already flagged: `PLAN.md:1176` says
  `receipts/09_browser_tree.md`, the prompt and every file on disk say `NN_receipt.md`.
* The Eyeball perf evidence reproduced in the verifier's own run: `BT17 … 14 ms, 2220 rows`
  and `BT33 … 16 ms`. No gesture leg self-skipped in its X run either.
* No droppings: no `test_scratch` dirs left, `git diff HEAD -- src tests` empty, `git status`
  dirty only on the expected batch bookkeeping.

---

## 13. Ledger

**`[E]` — DONE-PIXEL (`46f89349`)**, not pushed. `[E]` and never `[x]`: the deliverable is
visible UI that no test can judge. Eyeball queue row added to `PLAN.md` with the width
judgement as its entry point; the 2000-signal clause is discharged there as evidence.
Item 10 inherits the one-line BT44 name/route fix (§12.3).
