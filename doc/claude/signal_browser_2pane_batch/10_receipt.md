# Item 10 receipt — the upper pane goes live

**Status: DONE, committed, UNPUSHED.** Spec: `waveform_signal_browser_two_pane.md`
(R1, R2, R4, R5, R6, M11, §7.1). Plan: `PLAN.md` item 10.

---

## 1. The two baselines, re-measured first

**Headless 1586, thirteen files, zero failures** — the prompt's figure reproduced
exactly. (The receipt for items 2/4/8 quotes grid at 216; it is **222** now, because
item 10's own GH8 bump was already in the working tree.)

**The X arm was then run on the UNCHANGED working tree**, which is what produced the
real red list rather than a predicted one:

| suite | X baseline (item 9) | measured before | after |
|---|---|---|---|
| panes | 34 | 49, **7 FAILED** | **52 PASS** |
| sigbrowser | 319 | 276, 16 FAILED, **43 SKIPPED** | **343 PASS, 0 SKIPPED** |
| i11 | 74 | 74 PASS | 74 |
| i12 | 92 | 92, 5 FAILED | **101 PASS** |
| i1315 | 166 | 166, 7 FAILED | **167 PASS** |
| i14 | 83 | 83, 1 FAILED | **86 PASS** |
| 2pane | 59 | 108 PASS | 108 |
| sigsearch | 226 | *X server died mid-run* | 226 PASS |
| grid | 341 | 347 PASS | 347 |
| modes | 485 | 485 PASS | 485 |

**`item10_blast_radius.md` was accurate.** Its FAIL counts reproduced exactly, per
file: sigbrowser 16, i12 5, i1315 7, i14 1. Its 53 "VACUOUS" in sigbrowser showed up
as **43 checks that simply never ran** — 319 → 276 with six `SKIPPED:` banners. The
prompt's warning that a shortfall reads as a plausible number was correct, and the
check COUNT is what exposed it, not the fail count.

Two NORESULTs in the first batch (`i1315`, `sigsearch`) were **not** item 10: run
standalone they gave 166 and 226. `sigsearch` died with
`X connection to :0 broken (explicit kill or server shutdown)` — the known WSLg
Xwayland abort. `BR25` (a `<Return>` key-delivery check) reddened once in ten and
passed 3/3 on re-run: the known bare-`event generate` flake.

---

## 2. ⚠⚠ THE BIG ONE — spec §7.1 was not implemented, and it is a source change

`PLAN` item 10 spells the pipeline as
`names → browser_and → signal_entry → browser_class_filter → browser_rows`, i.e. the
tree is built from the **bar-matched** set. **Spec §7.1 forbids exactly that**, in so
many words:

> the tree's node set is derived from the **unfiltered** inventory (minus R11's class
> filter, which is not a search). A pattern that matches nothing leaves the tree intact
> and the sea of names empty. The alternative — pruning the tree to nodes with
> surviving signals — was rejected: it makes the navigation surface flicker under the
> user's fingers while they type, **which is the defect R5 exists to fix, merely
> relocated.**

§6's "the tree, the sea of names, the status line and every gesture see one consistent
set" is **not** in conflict: that sentence is in the R11 section and is about the
CLASS filter, which §7.1 explicitly exempts ("which is not a search").

**The flicker was measured, not argued.** Expand `x1`, then type `v(x1.x2*` one
character at a time as a user does. The FIRST keystroke makes the shell pattern `v`,
which matches nothing, so the tree empties; `x1` is deleted and its open state dies
with it; the remaining seven keystrokes rebuild it CLOSED. No amount of open-set
carrying inside `browser_populate` can survive that — the node was not there to carry.

**Driver ruled: fix it in item 10.** `browser_refresh` now builds its entries from
`$browsersigs($token)`. `browserrows($token)` therefore holds the bar-UNFILTERED rows,
and it must: every gesture resolves a tree row id through it.

**Scope, declared:** this governs the CURRENT DB only. The All-DBs branch still matches
each foreign inventory with the bars, because R7's tree shape is **item 15's** and
BD51/BD51b pin today's behaviour. BD51b now asserts that asymmetry from both sides.

---

## 3. Four defects, all found by RUNNING

1. **§7.1 (above).** The tree was bar-filtered. Source fix in `browser_refresh`.
2. **⚠ `bs_type` never fired the filter at all.** The helper item 10 added to
   `wvbs_common.tcl` had no focus loop. Tk delivers KEY events to the toplevel's
   **focus widget**, not to the window named in `event generate`, so the bar ended up
   HOLDING the pattern, the helper cheerfully ANSWERED it, and `browser_refresh` ran
   **zero** times. Measured on a probe: `bs_type returned |v(x1.x2*|`,
   `refreshes fired 0`, tree unchanged. Every R5 claim built on it (BW46/BW47) was
   green and hollow. `bt_type` has carried the focus loop since item 9; the divergence
   was the bug. Fixed, plus the empty-string case (zero loop iterations → no event at
   all, so `bs_type $bar {}` cleared the entry while leaving the old filter applied).
3. **Five over-braced expected literals** (BW40/41/45/48/51). `check` compares
   STRINGS and `[list {g:} 0]` has the string rep `g: 0`, not `{g:} 0`. Red on a
   CORRECT widget.
4. **S3's sabotage had only a SOURCE witness.** Adding `$tv see` to
   `browser_populate` reddened BW53 and nothing else, because every check in the band
   restored a selection whose ancestors were already open. A **behavioural** BW53 was
   added: it collapses `g:x1`, selects `g:x1.x2`, repopulates, and asserts the ancestor
   is still closed.

The three defects item 10 had already fixed in the working tree (the `has children`
predicate, the open-set carry, the one-id narrowing) all stand, and S5/S4/BW26b red
without them.

---

## 4. What the restatement did to the vacuity

**The `BM` band — driver ruling, option (a), implemented.** `bm_leaf_tree` /
`bm_leaf_fill` build a **throwaway `ttk::treeview` in its own toplevel**, filled from
`browserrows($token)` (the FULL list, R6), rows `-open 1`. `browser_menu_post` /
`browser_menu_ids` take a clicked row id and are widget-agnostic, so all ~43 checks
keep asserting exactly what they asserted before; only the widget the click lands in
moved. `$BMRTV` / `$BMVRTV` keep every **structural** claim on the real tree
(BM20, BM35, BM40, BM42, BM46 leg 2). The fixture is titled `NOT production`, and
**item 11 deletes it** when the sea of names gives leaves a widget again.

Anti-vacuity guards added because a skip must never be silent:
* **BM20** gains three legs — the real tree's exact node projection (raw-free), and
  two FIXTURE legs (mapped / `ok:12` / last row has a bbox) so a band that goes quiet
  always has a red beside it.
* **BM36 / BM47** were `destroy; assert destroyed` — green forever. Now transition
  tuples, and BM47 carries a `never-built`/`built` sentinel because `winfo exists`
  after a destroy cannot tell "reaped" from "never created".
* **BT28/BT29/BT43** turn their `SKIPPED` into asserted preconditions via
  `bt_spot` / `bt_spot_state` (`absent` / `offscreen` / `mapped`), so "the row
  vanished" and "the pane is too short" are different reds.

**Result: sigbrowser went 319 with 43 skips → 343 with ZERO skips.**

### The BT25/BT26/BT27 discriminator, rebuilt twice
PLAN's answer was a compound triple reading the **lower pane's labels** — invalid: the
sea is empty until item 11. The obvious second answer (`browserrows`) is invalid too,
because §7.1 makes the row model bar-independent as well. What still varies is the
**status-line count** and **`wviewer::browser_match`** (which re-reads both live bars
and is the proc `browser_refresh` itself calls). `bt_sig` is the four-tuple
`{tree model count matched-names}` and `bt_distinct` answers `distinct:4` or
`collision: <value>` — widened from three states to **four**, because with the tree
equal everywhere ALL is the only state a "second bar ignored" break can be caught
against.

**"Never widened" is now unexpressible from the upper pane, and that is declared
rather than faked** — BT27's hold moved to `browser_refresh`'s own `0` return.

### Coverage genuinely deleted, named rather than hidden
Between item 10 and item 11 **no check in the repo drives a real click on a SIGNAL row
that plots it**. Stated in BT28's and BT29's comments. The positive arms relocate to
DIRECT `browser_plot_ids` calls, each named `(ROW MODEL, a DIRECT ... call — NOT a Tk
gesture)`.

### Declared gaps, asserted as values
* **BP43a** — with All-DBs ON there is no design root, so **R4's never-empty selection
  does not hold**. It is the gap's tombstone: **item 15 must edit it**, and PLAN item
  15's break-list (which names only BD50/BD51) must name it too.
* **BD48c** — the same carve-out on the i14 fixture, with **BD47c** as its box-OFF
  positive control (root text `bd_b`, from a raw that file wrote itself).
* **BX15** — a ROOTED row list walked with no `start` DEAD-ENDS (`{} 0`). Not a defect
  to paper over with a default: it is what makes passing `browser_root_id` load-bearing.

---

## 5. Sabotages — RUN, not reasoned about

| # | sabotage | measured reds |
|---|---|---|
| S1 | `browser_tree_rows`' output into `browserrows` as well | **31 over two files** — BW43, BW44; BT24 ×3, BT25 ×2, BT26 ×2, BT27 ×2, BT28, BT29, BT30, BT31, BT32 ×3, BT33, BT40, BT42, BT43 ×2, BT44 ×2, BM20 ×2, BM40, BM42, BM43. (PLAN said "BW44 is the only thing that sees it".) |
| S2 | insert every node `-open 1` | BW41, BW46 (pre), BW47, **BX30** — 4 over two files |
| S3 | `browser_populate` calls `$tv see` | BW53 (SOURCE) **only** on the first pass → **BW53 (BEHAVIOURAL) added**, then both |
| S4 | drop the open-set preservation | BW41, BW46 ×2, BW47 |
| S5 | restore the "has children" predicate | BW52 **+ BP43, BP45, BP53** — the persistence end catches it too |
| S6 | revert §7.1 (bars filter the tree again) | BW46, BW47; BT25 ×2, BT26 ×2, BT27; **BD51b** — 8 over three files |
| S7 | `bs_type` loses its focus loop | **BW46 (PRECONDITION)** — the guard added for exactly this |

Source restored byte-identical after every one (`diff -q`). Every run's **check COUNT**
was read alongside its fail count; only S1 aborted a band (297 seen vs 343, 3 skips)
and it did so **with reds beside the skips**, which is the design.

---

## 6. Things PLAN says that were NOT reinstated

1. **BW32 was not written** — the anypath gate has no production caller and passing it
   would flatten a hierarchical FOREIGN inventory (receipt §4.1 of the 2/4/8 receipt).
2. **No renumbering into BW20-BW35** — item 10 is BW40-BW53.
3. **BW24's `406`** is not used here; the panes fixture is a 3-signal one and its R6
   control is `{3 2 1}`.
4. **`begin {…}` is not a proc** — named helpers throughout, each restoring what it
   changed (`bw_sel_after_*`, `bt_open`/`bt_close`, `bp_order_probe`).

## 7. Owed

* **The eyeball.** Every claim here is a measured value; nobody has looked at the
  actual sidebar. Collapsed-by-default, the design-root label, and "typing no longer
  disturbs the tree" are pixel claims.
* **Item 11** deletes `bm_leaf_tree`/`bm_leaf_fill` and re-points BM21-BM34 and
  BT28/BT29's relocated arms at the sea of names.
* **Item 13** reds BP54 by design (it unions the selection's ancestor chain into the
  applied open set). ⚠ The numbers PLAN gives item 13 — **BW53/BW54/BW55 — are already
  spent by item 10**; it must re-band before citing them.
* **Item 15** must edit BP43a, BD48c and BD47c, not just BD50/BD51.
