Repo `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.

Continue the **two-pane Signal Browser batch**, **item 11 — the lower pane goes live**.
All design rulings are TAKEN — do not re-open them.

## WHERE YOU ARE

Item 10 landed as `d8e04c7a` and is **UNPUSHED** (**12 unpushed commits** vs
`github/fluid-editing`). Read
`doc/claude/signal_browser_2pane_batch/10_receipt.md` **first** — §2 is a source
change that contradicts `PLAN.md`, and item 11 inherits it.

**Baselines to reproduce before you touch anything:**

* Headless **1589**, thirteen files, zero failures.
* X arm **10/10**: panes 52, sigbrowser 343, i11 74, i12 101, i1315 167, i14 86,
  2pane 108, sigsearch 226, grid 347, modes 485.

Two known flakes, NOT regressions, both reproduced last session: `BR25` (a
`<Return>` through a bare `event generate`, ~1 in 5) and a whole-suite `NORESULT`
from the WSLg Xwayland death (`X connection to :0 broken`). Both pass on re-run.
**Re-verify the X server is alive first** — `timeout 15 xdpyinfo -display :0` must
return 0.

## ⚠⚠ THE ONE THING THAT CHANGES ITEM 11's SHAPE

`PLAN.md` item 11 says the sea reads the "class-filtered, **bar-matched** entry
snapshot". That is still right — but item 10 discovered that spec **§7.1** had
never been implemented and fixed it, so the two panes now take **different sets**:

* the **TREE** is built from the **bar-UNFILTERED** inventory
  (`browser_refresh` reads `$browsersigs($token)`), and `browserrows($token)`
  holds those unfiltered rows;
* the **SEA** is the half that the bars narrow.

**Item 10 deliberately did NOT compute the bar-matched entry set**, because dead
code is worse than an absent seam — `$names` (the `browser_and` result) is right
there in `browser_refresh` and is currently consumed only by the status count.
**Computing that set, class-filtering it, and handing it to the sea is item 11's
first job.** Do not "restore" the tree to the matched set; S6 in the receipt is
that exact sabotage and it reds 8 checks over three files.

## THE SEAMS ITEM 10 LEFT YOU

* `wviewer::browser_sea_refresh {token}` — the stub, `src/wave_viewer.tcl:7106`.
  Returns 0, never throws. It rides `<<TreeviewSelect>>`, which fires on **every
  keystroke in either bar**, so a throw there pops bgerror — modal under X, which
  hangs a headless run. **It must never call `$tv see`** (R5).
* `wviewer::browser_sea_build` (`:7133`) — `$f.pw.sea.c` canvas + horizontal
  scrollbar, already built and packed, still empty.
* The pure machinery items 5/6/7 shipped and item 11 composes, all already green:
  `browser_level_names` (own level only, NOT recursive), `browser_label` /
  `browser_label_full`, `browser_flow_layout` / `_cell` / `_hit` / `_scrollregion`
  (`:6346`-`:6390`), plus `browser_target_path` / `browser_id_path` for the
  `g:` → `{}` decode.
* `browser_class_filter` — R11's policy, still hardcoded `0 1` in
  `browser_refresh`. Item 12 wires the boxes; **do not do it here.**

## THE WORK

`PLAN.md` item 11 is the scope. Its band is **BQ50-BQ64** in a new
`test_wave_sigbrowser_sea.tcl` (X arm), and `bs_sea_labels` in `wvbs_common.tcl`
answering **`no-pane` / `empty` / the ordered label list** — three shapes, because
12 of `tb_bandgap`'s 44 kept nodes render legitimately empty.

Guide + oracles: **seven** new `data-bseq="pw.sea.c …"` rows, and
**GH8/GH9 `7` → `14`** (`tests/headless/test_wave_grid.tcl:474` and `:486`).
Bump those first, RED-first.

### Item 11 also has a DEBT to pay — three of them, and they are not optional

1. **Delete the throwaway leaf trees.** `bm_leaf_tree` / `bm_leaf_fill`
   (`test_wave_sigbrowser.tcl:2303` / `:2340`) and the toplevels `.wvbmleaf` /
   `.wvbmvleaf` exist ONLY because item 10 took leaf rows out of the tree and
   ~43 right-click checks lost their targets. **Re-point BM21-BM34 and BM43/BM45
   at the sea of names**, then delete the fixture, its two teardown checks
   (BM36/BM47's throwaway legs) and the `$BMRTV`/`$BMVRTV` split's *fixture* half.
   Keep `$BMRTV`/`$BMVRTV` for the structural claims (BM20, BM35, BM40, BM42,
   BM46 leg 2) — those are about the real widget and must not follow.
2. **Re-point the four relocated DIRECT calls.** `BT29` (`:1568`), `BT32`
   (`:1699`), `BT43` (`:1874`) call `browser_plot_ids` directly and say so in
   their names, because between item 10 and item 11 **no check in the repo drives
   a real click on a SIGNAL row that plots it**. Item 11 closes that hole: give
   them real sea gestures and drop the `(ROW MODEL, a DIRECT … call)` qualifier
   from the names when you do.
3. **The sea's RMB menu must be a DISTINCT widget** (`wvseamenu`) registered with
   `ctx_menu_drop`. Reusing `wvbrowsermenu` aliases the two panes' selections and
   disturbs the tree menu's reserved index 7 (BM02, BH40).

### The status line — §7.2, three distinguishable states

`x1.x2 has no signals of its own` /
`0 of 43 signals (the Search/Filter bar is hiding them)` /
`0 of 43 signals (device internals are hidden)` / `<n> of <own> signals`.
Composed **only** by `browser_say` / `browser_msg`, never inline. `browser_bars_active`
already answers the middle case; the third needs its twin.

⚠ **`browser_refresh`'s current status line is item 9's `"<matched> of <total>
signals"` and several green checks read it exactly** — `BT24`/`BT25`/`BT26`/`BT27`
now use a `bt_count` helper that extracts `N of M`, and `BD52` asserts the box-OFF
string byte-identically. Moving to §7.2's wording moves those. Decide whether
§7.2 replaces the line or sits beside it, and say which in the receipt.

## HOUSE RULES THAT HAVE BITTEN EVERY SESSION IN THIS BATCH

* Headless: `env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script <f>`
  from the repo ROOT; scripts end in `exit 0`.
* X arm: `tests/headless/run_suites.sh` under one **`Allow 2h`** press —
  never a bare `for` loop. `SUITE_TIMEOUT=400` for `test_wave_modes`. If the panel
  shows `PAUSE` in `~/.claude/gui_test_gate/control` nothing will start; that is
  the user's authority, ask rather than override.
* **⚠ A SHORTFALL IN THE CHECK COUNT IS THE ONLY WITNESS TO VACUITY.** Item 10's
  change silently stopped 43 checks from running and the file reported a
  plausible 276 instead of 319 — zero failures, six `SKIPPED:` banners. **Diff the
  COUNT, never just the fail count**, on every run and after every sabotage.
* **`pcall` returns the STRING `ERR:<msg>`.** `expr` on it THROWS past the check
  into the file's outer catch, deleting every remaining check. And `lsearch` on it
  does NOT throw — it answers -1, so `< 0` goes **green on a failed read**. Both
  shapes were found in this batch. Use assertable sentinels, three shapes minimum:
  "never built" / "built and empty" / "correctly filtered to zero".
* **Expected literals are STRING REPS, not nested lists.** `[list {g:} 0]` is
  `g: 0`, not `{g:} 0`. Five checks were red on CORRECT code last session. Build
  every expectation with `[list …]`.
* **`bs_type` (wvbs_common.tcl) needs its focus loop** — Tk routes KEY events to
  the toplevel's focus widget, not to the window named in `event generate`.
  Without it the bar holds the pattern, the helper answers it, and
  `browser_refresh` runs ZERO times while every claim goes green. If you write a
  new gesture helper for the canvas, `<Button-1>` does not have this problem but
  anything keyboard-driven does.
* **A check that compares an error string with itself is GREEN before the code
  exists.** When a check passes before you wrote the code, **stop and look**.
* **`begin {…}` is not a proc.** Named helpers, and they must RESTORE what they
  changed.
* **Do not renumber into BW20-BW53** — item 10 spent **BW40-BW53**. ⚠ PLAN gives
  item 13 the numbers BW53/BW54/BW55; **those are already gone** and item 13 must
  re-band.
* Never `make` while suites run. `MG13`, `test_ase_plot` P4/P6/P8 are known flakes.
* **Commit when green. DO NOT PUSH** unless told.
* Measure, don't reason. Every line number in every doc has drifted at least once.

## SABOTAGES — run them, don't reason about them

PLAN's four, at minimum: `$tv see` from `browser_sea_refresh` (**BQ53**);
`browser_leaf_names` instead of `browser_level_names` (**BQ51** reads `{18 406 0}`
— note its root leg stays right, which is why the check names a *descended* node);
the label in the canvas tag instead of the raw name (**BQ56/BQ58**); reuse
`wvbrowsermenu` for the sea (**BQ61/BQ62**).

Add two of your own: feed the sea the **bar-unfiltered** set (it must red, or the
two panes are not actually taking different sets), and drop the sea's refresh from
`browser_refresh`'s tail (a bar keystroke must move the sea).

## START BY

Confirming the X server is alive, re-measuring headless **1589**, then running the
X arm on the UNCHANGED tree to confirm 10/10 — so that every red after that is
yours. Then bump GH8/GH9 to 14 and write the BQ band RED before the code.

## CORPUS

`tests/headless/fixtures/tb_bandgap_vars.txt` (424 names) and
`tb_charge_pump_vars.txt` (1191) are committed. Every spec number reproduces off
them: 128/44/84 nodes, own-level 18 at the root and 43 at `x1`, recursive 406,
424/190/374/140 class totals. Use them rather than inventing counts.
