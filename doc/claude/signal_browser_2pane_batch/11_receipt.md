# Item 11 receipt — the lower pane goes live

**Status: DONE, committed, UNPUSHED.** Spec: `waveform_signal_browser_two_pane.md`
(R3, R4, R5, R6, R8, §5, §7.1, §7.2, §7.5, §7.6). Plan: `PLAN.md` item 11.
Prompt: `doc/claude/suggestions/next_session_2pane_item11.md`.

---

## 1. The two baselines, re-measured on the UNCHANGED tree first

**Headless 1589, thirteen files, zero failures** — reproduced exactly:
sigsearch 139, sigbrowser 135, 2pane 108, panes 14, i11 50, i12 32, i1315 80,
i14 47, grid 222, modes 212, viewer 57, markers 437, tabs 56.

**X arm 10/10**, every count the prompt gave, exactly: panes 52, sigbrowser 343,
i11 74, i12 101, i1315 167, i14 86, 2pane 108, sigsearch 226, grid 347,
modes 485. So every red after that was mine. Neither known flake (`BR25`, the
WSLg Xwayland abort) appeared in any run this session.

**After:** headless **1602** (14 files), X arm **11/11**:

| suite | before | after |
|---|---|---|
| panes | 52 | **53** |
| sigbrowser | 343 | **352** |
| **sea (NEW)** | — | **66** |
| grid | 347 | **354** |
| i11 / i12 / i1315 / i14 / 2pane / sigsearch / modes | 74 / 101 / 167 / 86 / 108 / 226 / 485 | unchanged |

Zero `SKIPPED:` banners in any X run of sigbrowser or sea.

---

## 2. ⚠⚠ THE STATUS-LINE RULING — §7.2 SITS BESIDE ITEM 9's LINE, ON ITS OWN PANE

The prompt asked for a decision and for it to be recorded. **§7.2's sentence is a
caption on the LOWER PANE (`$f.pw.sea.st`), not the sidebar's `.ph` status line.**
All three candidates were measured against the suites rather than argued:

| candidate | measured cost |
|---|---|
| **REPLACE** `.ph`'s line with §7.2's | BT24/BT25/BT26/BT27's counts, BD52/BD52b's byte-identity and BW46's "the search really RAN" proof all move — **and the FILTER and AND bar states stop being distinguishable at the design root** (both read `0 of N`), which is the discriminator item 10 rebuilt *twice* to keep. |
| **APPEND** a third line to `.ph` | BD52, BD52b, BX37, BX42, BX44, BX45, BX46, BH50, BH51, BH54 all assert `[$F.ph cget -text]` **byte-identically** as `"Signal Browser\n<msg>"`. A third line reds every one of them — ~12 checks across four files, none of them about item 11. |
| **A CAPTION ON THE PANE IT DESCRIBES** | exactly ONE existing check (the sea frame's pinned child set, panes BW23) plus BW35, which item 11 had to move anyway. |

The third was taken. `.ph` keeps item 9's `<matched> of <total> signals` about the
WHOLE inventory, byte-identical; the caption says `<shown> of <own> signals` about
the SELECTED NODE. Two facts, two lines, both visible at once.

`browser_say`/`browser_status` are **untouched**. What is shared is the SPELLING:
`browser_msg` gained five kinds (`seanone`, `seaempty`, `seabars`, `seaclass`,
`seacount`) and remains the one place the sentences exist, which is what the plan
asked for. `browser_sea_say` writes the caption and deliberately does **not** echo —
it fires on every keystroke and every arrow through the tree, and `wviewer::echo`
writes an action-log line.

---

## 3. Four numbers the PLAN and the SPEC got wrong, corrected by measuring

1. **⚠ BQ59's `406` is the PRE-class-filter figure.** `browser_rows` is built from
   `browser_class_filter`'s output (`0 1`), so the row model holds **190** leaves,
   not 424, and R6's recursive plot on `g:x1` answers **172**. The check asserts 172
   beside the own-level 43, so the two questions are visibly different.
2. **The tree is 45 rows, not 44.** Spec §3.3's 44 counts *instance nodes*; the
   design root (R2) is the 45th. Both numbers are right about their own question.
3. **⚠⚠ §7.5's "reachable" state is NOT reachable on either committed corpus.**
   Measured at the shipped `devint 0 srccur 1`: `tb_bandgap` has **zero** nodes whose
   own level survives unfiltered and is emptied by the class filter;
   `tb_charge_pump` has **four** where the filter takes SOME (4→2, 5→4, 5→4) and none
   where it takes ALL. The state is reachable *in principle* — a wrapper kept because
   a DESCENDANT carries a net, whose own level is all device — so **BQ67c builds that
   inventory by hand** (`{v(x1.x2.net5) v(m.x1.mn1#body)}`) rather than leaving the
   third sentence untested. "We could not reach it" and "we did not look" are
   different facts.
4. **The two levels' LABEL sets are not disjoint.** The root and `x1` both render a
   `net1` (`v(net1)` and `v(x1.net1)`) — R8's label drops the path, so this is
   correct, and BQ51's disjointness leg therefore compares **names**. The collision is
   pinned as its own value (`shares: net1`) rather than left as a trap for the next
   person who compares labels.

---

## 4. Two traps that cost real debugging, both measured

### 4.1 ⚠⚠ `event generate` STAMPS TIME 0, SO EVERY SAME-SPOT CLICK IS A DOUBLE-CLICK

Two `<Control-Button-1>` events on ONE cell toggled once and then **plotted**. Tk's
double-click detector compares the previous button event's TIME field, and
`event generate` leaves it at **0** unless `-time` is given — so any two presses at
one position have a delta of 0 and the second is matched as `<Double-Button-1>`.
`after 400` changed nothing; `after 700` changed nothing; **wall-clock time is not
what Tk compares.** `bs_sea_click` now carries a strictly increasing `-time`, and
`bs_sea_dclick` deliberately shares ONE stamp because there a zero delta is what
*makes* the double. This is the canvas twin of item 10's `bs_type` focus-loop trap.

### 4.2 The tail call had NO witness, and the reason is a ttk behaviour nobody wrote down

Sabotage S6 (drop `browser_sea_refresh` from `browser_refresh`'s tail) produced
**ZERO reds**. Probed rather than reasoned about:

> `ttk::treeview` fires `<<TreeviewSelect>>` on **every** `selection set`,
> **including one that sets the value it already held** (measured on a bare
> two-row treeview: same-value `selection set` → 1 event).

`browser_populate` re-sets the selection on every repopulate, so the event route
already refreshed the sea on every keystroke. The tail is kept — `browser_populate`
skips `selection set` entirely when no previous selection survives AND there is no
root row (the All-DBs shape BP43a is the tombstone for) — and **BQ66b makes it
attributable** by removing the other route: it unbinds `<<TreeviewSelect>>`, types,
asserts the sea still moved, and restores the binding.

---

## 5. What landed

### Source (`src/wave_viewer.tcl`)
* `browser_refresh` computes the sea's snapshot as a **narrowing of the tree's
  class-filtered entries by the bar-matched name set** — one `browser_class_filter`
  call for the current DB, so the two panes provably agree about what R11 did (§6)
  while §7.1 lets them disagree about what the BARS did. Set **before**
  `browser_populate` runs, because populate's `selection set` fires the sea refresh
  mid-refresh. Tail call added.
* `browser_sea_refresh` + 22 new procs: the layout (`browser_sea_layout`, one
  arithmetic shared by the draw and the hit-test so they cannot drift), the draw,
  the six gestures + `<Configure>`, the accessors, and a **distinct** `wvseamenu`
  context menu with its own gate, build, post, unpost, target-path, copy, send and
  descend.
* `browser_sea_build` gained `$w.st`, with `-width 1` so its requested width is
  constant — a label whose request tracked its text would re-request, the frame
  would re-request, the canvas would get `<Configure>`, and `<Configure>` writes the
  caption.
* `browser_msg` +5 kinds. `forget` and `tab_drop_transients` both drop the sea menu
  (a fourth `tk_popup` grab) and `forget` unsets the four new arrays.
* Seven `bind $f.pw.sea.c` lines in `browser_build`, where GH8/GH9 can count them.

### Docs
`doc/waveform_viewer_guide.html` §11.6 gained seven `data-bseq` rows and a paragraph
naming the caption's three states. `test_wave_grid.tcl` GH8 `7` → **14** (GH9 carries
no literal — it compares the two directions and auto-tracks; the prompt's "GH8/GH9
7 → 14" is one literal, at `:474`).

### Tests
* **NEW `test_wave_sigbrowser_sea.tcl`**, band `BQ` — 6 pure + 60 X = **66**.
* `wvbs_common.tcl`: `bs_sea_labels` (`no-pane`/`empty`/the ordered labels — three
  shapes, because 12 of the 44 kept nodes render legitimately empty), `bs_sea_at`,
  `bs_sea_item`, `bs_sea_xy`, `bs_sea_click`, `bs_sea_dclick`.
* `test_wave_sigbrowser_panes.tcl`: BW23's child set restated (three, not two);
  BW35's "the sea is still EMPTY" became "the sea draws the selected node's own
  level", with the pure ancestor between as a third value.

---

## 6. The debt, paid — and the one part of it that could not be

### 6.1 The throwaway leaf trees are DELETED
`bm_leaf_tree` / `bm_leaf_fill`, `.wvbmleaf`, `.wvbmvleaf` and the `::bm_vleaf`
sentinel are gone. The re-point turned out to be **three**-way, not two:

* **SIGNAL gestures → the REAL lower pane** (`$BMC` / `$BMVC`). BM20 (fixture legs),
  BM21-BM26, BM28-BM34, BM43, BM45. The currency moved with them — the tree's menu
  closes over ROW IDS, the sea's over FLOW INDICES — and BM24's name now says the
  claim is "fully resolved: token, target AND code", which is what it always pinned.
* **GROUP gestures → the REAL TREE** (`$BMRTV`). **BM27 never needed a fixture at
  all**: item 10 removed only leaves, so `g:x1.x2` was always still clickable. It sat
  on the throwaway purely because it was inside the same guard — exactly the drift a
  fixture invites. It also gained a leg asserting the two menus did not alias.
* **STRUCTURAL claims** stayed where item 10 put them (BM20 legs 1-2, BM35, BM40,
  BM42, BM46 leg 2).

BM36 and BM47 lost their throwaway legs and gained production ones: `forget` and
`close` must reap **both** menus, and the pre-state is captured **before** `forget`
(which reaps them itself), so "the sea menu was never built" is a red rather than a
tautology. BM36 also asserts `.wvbmleaf` does not exist anywhere any more — that zero
is what says the deletion really happened.

### 6.2 The relocated DIRECT calls — two given gestures back, one that CANNOT be
* **BT29** and **BT43** are real Tk gestures again (a double-click, and on the real
  viewer a double-click *and* a middle-click), and the
  `(ROW MODEL, a DIRECT … call — NOT a Tk gesture)` qualifier came off both. The hole
  item 10 declared — *"no check in this repo drives a real click on a SIGNAL row that
  plots it"* — is closed, on the fixture arm **and** on the real-raw arm.
* **⚠ BT32 KEEPS ITS QUALIFIER, and item 11 did not remove it because it cannot.**
  Its target is a GROUP **and** a LEAF at once, and after the two-pane split those
  live in two widgets holding two independent selections. There is no single gesture
  that expresses it, which is exactly why the dedup rule needs an oracle at the entry
  point both panes converge on. The name now says so instead of implying a pending
  relocation.

### 6.3 The sea's RMB menu is a DISTINCT widget
`wvseamenu`, registered through `ctx_menu_widget`/`ctx_menu_drop`. `ctx_menu_widget`
**destroys and re-mints** the name it is handed, so a sea post through
`wvbrowsermenu` would tear the tree's menu down mid-life and `ctx_menu_drop` on
either name would take the other with it. The entry table is spelled twice rather
than factored, because BM01-BM09 grep `browser_menu_build`'s own body; the AGREEMENT
is pinned **behaviourally** instead (BQ68 compares the two posted menus entry for
entry, by type and by label shape — the header and the Copy count must differ,
because the two menus are over two different targets).

---

## 7. Sabotages — RUN, not reasoned about

| # | sabotage | measured reds |
|---|---|---|
| S1 | `$tv see` from `browser_sea_refresh` | **SOURCE ONLY** on the first pass (BQ64) → **BQ53 (BEHAVIOURAL) added**, then **2** |
| S2 | `browser_leaf_names` instead of `browser_level_names` | **12** — BQ51, BQ52 ×2, BQ53, BQ65 ×2, BQ66, BQ57, BQ64, BQ67 ×2, BQ67c |
| S3 | the LABEL where the raw name goes | **26 over two files** — 12 in sea (BQ51 ×2, BQ56 ×2, BQ58 ×3, BQ60, BQ65, BQ68 ×3), 14 in sigbrowser (BM20, BM23 ×2, BM30 ×2, BM31 ×2, BM33 ×2, BM43 ×2, BM45 ×3) |
| S4 | reuse `wvbrowsermenu` for the sea | **35 over two files** — 5 in sea (BQ68 ×4, BQ62), 30 in sigbrowser (BM22-BM34) |
| S5 | feed the sea the **bar-UNFILTERED** set | **6** — BQ53, BQ65 ×2, BQ66, BQ67 ×2 |
| S6 | drop the sea refresh from `browser_refresh`'s tail | **ZERO** on the first pass → **BQ66b added** (see §4.2), then **1** |

Source restored **byte-identical** after every one (`diff -q`). Every run's check
COUNT was read alongside its fail count; no run lost a check.

---

## 8. Found, named, NOT fixed

* **⚠ THE SEA HAS NO HOVER TOOLTIP — an acknowledged MISS, not a deferral.**
  `PLAN.md` item 11's scope names *"Tooltip on hover shows `browser_label_full`"*
  (PLAN:816) and nothing binds `<Motion>` on `$f.pw.sea.c`: **seven** binds shipped,
  not eight. The pane draws a LABEL and gives the user no way to see the NAME behind
  it. — **PAID by two-pane item 20's second commit** (`20_receipt.md` §5): one `<Motion>` bind,
  GH8's literal `14` → `15`, a fifteenth `data-bseq` row, and BQ75-BQ77. *(This entry
  was itself added late: item 11's receipt did not record the miss, and the next
  session's prompt cited a §8 line that was not here.)*
* **`browser_show_path`'s bar clause is now stale.** Its `$matched == 0` arm appends
  *"(the Search/Filter bar may be hiding it)"* when `browser_bars_active` — but since
  item 10 the bars cannot hide a node from the tree for the current DB (§7.1). The
  message is now false on that path. Left alone: BX37/BX38 pin the strings verbatim
  and BX38 is the only test of `browser_bars_active` at all, so correcting it is its
  own item with its own reds.
* **Guide §11.2 prose is pre-two-pane** ("Signals are grouped by hierarchy: …
  `net5` inside `x2` inside `x1`") and describes a single tree. Nothing pins it; a
  prose pass is owed.
* **The eyeball.** Every claim here is a measured value. Collapsed-by-default, the
  design-root label and "typing no longer disturbs the tree" were item 10's pixel
  claims and are still owed; item 11 adds its own — the flow's column widths, the
  selection tint (`ase::theme header` behind `ase::theme accent` text; the palette has
  no `select` key and none was added), the caption's three sentences, and the
  horizontal scrollbar appearing only when the pane is squeezed.

## 9. Owed / for item 12

* Item 12 replaces the hardcoded `0 1` in `browser_refresh`'s **two**
  `browser_class_filter` calls (the current DB's and the All-DBs loop's) with
  `browser_devint`/`browser_srccur`. Item 11 added no third call site — the sea is a
  narrowing of the already-filtered list, on purpose.
* Item 12's own reds now include **BQ67c**, whose synthetic inventory assumes
  `devint 0`, and **BQ50's `190`** precondition.
* **Item 13 must re-band**: PLAN gives it BW53/BW54/BW55, all spent by item 10.
  Item 11 spent **BQ50-BQ68** and did not renumber into BQ01-BQ13.
* Item 15 must still edit BP43a, BD48c and BD47c (item 10's list), and now also
  **BQ52/BQ67**, whose `seanone` branch is the All-DBs no-selection case.
