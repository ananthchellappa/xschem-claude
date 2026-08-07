# Item 10 blast radius — the 84 X-arm checks the tree change reaches

Produced 2026-08-07 by an 8-agent audit (one reader per test file) followed by an
adversarial verify pass (one refuter per claimed hit, default-refute-when-unsure).
**110 candidates found, 84 confirmed, 26 refuted.** The refuted list is kept at the
end because "we looked and it does not apply" is worth as much as the hits.

The change audited: (A) leaf rows leave the tree; (B) nodes insert `-open 0` except
the design root; (C) a new root node `g:` becomes the single top level; (D) the
selection is never empty; plus `browser_show_path`'s sim-root branch selecting the
root instead of clearing.

⚠ **PLAN.md item 10's own red list names ~12 of these.** It is short by a factor of
seven, and the bulk of the miss is one shape: the whole `BM` right-click-menu band
clicks LEAF ids in the tree, and those checks do not FAIL when the row disappears —
they print `SKIPPED` and assert nothing, which reads green.

`VACUOUS` below means exactly that: still green, no longer testing anything.


## `test_wave_sigbrowser.tcl` — 69 (16 FAIL, 53 VACUOUS)

| line | check | effect | cause | fragment |
|---|---|---|---|---|
| 1176 | BT24 | FAIL | A,C | `[bt_tree $BTTV] $BTALL` |
| 1183 | BT24 | FAIL | A | `[pcall $BTTV parent {s:v(x1.x2.net5)}]` |
| 1194 | BT25 | FAIL | A,C | `[list $bt_k [bt_tree $BTTV]] [list 1 $BTSEARCH]` |
| 1204 | BT25 | FAIL | A,C | `the Search BUTTON rebuilds the same tree ... [bt_tree $BTTV] $BTSEARCH` |
| 1211 | BT26 | FAIL | A,C | `[list $bt_k [bt_tree $BTTV]] [list 1 $BTAND]` |
| 1220 | BT26 | FAIL | A,C | `the FILTER bar alone gives a THIRD, larger tree ... [list 1 $BTFILT]` |
| 1225 | BT26 | FAIL | A,C | `re-typing the search puts the AND back ... [list 1 $BTAND]` |
| 1234 | BT27 | FAIL | A,C | `the tree is HELD ... [bt_tree $BTTV] $BTAND` |
| 1239 | BT27 | FAIL | A,C | `a valid regexp recovers, and the AND is back ... [list 1 $BTAND]` |
| 1244 | BT27 | FAIL | A,C | `clearing both bars restores the whole tree ... [list 1 $BTALL]` |
| 1249 | BT28 | VACUOUS | A | `set bt_c [bt_centre $BTTV {s:v(out2)}]  -> "SKIPPED: BT28 MMB leg"` |
| 1261 | BT29 | VACUOUS | A | `set bt_c [bt_centre $BTTV {s:net1}]  -> "SKIPPED: BT29 double-click leg"` |
| 1300 | BT30 | FAIL | A,D | `$::bt_plot_calls [list [list wvbt {v(out) net1}]]   (setup line 1296 `selection set [list ` |
| 1335 | BT31 | FAIL | A | `...and the very next real gesture still records (the spy is alive)   (setup 1331 `selectio` |
| 1349 | BT32 | VACUOUS | A | `a group plus one of its own leaves does not plot that leaf twice   (setup 1345 `selection ` |
| 1364 | BT33 | FAIL | C | `[list $bt_ok [llength [$BTTV children {}]]] [list 1 20]` |
| 1434 | BT40 | FAIL | A,C | `[bt_tree $BTVTV] [list {s:vsweep\|vsweep} {s:v(out)\|v(out)} {g:x1\|x1} ...]` |
| 1443 | BT42 | FAIL | A | `[pcall $BTVTV parent {s:v(x1.x2.net5)}]` |
| 1457 | BT43 | VACUOUS | A | `set bt_c [bt_centre $BTVTV {s:v(out)}]  -> "SKIPPED: BT43 real MMB leg"` |
| 1467 | BT43 | VACUOUS | A | `set bt_c [bt_centre $BTVTV {s:v(x1.x2.net5)}]  -> "SKIPPED: BT43 real double-click leg"` |
| 1497 | BT44 | VACUOUS | A,D | `a Plot-button gesture under newstrip created a new strip   (setup 1481 `selection set [lis` |
| 1510 | BT44 | VACUOUS | A,D | `under multi, a Replace gesture APPENDS (declared limit D2)   (setup 1507 `selection set [l` |
| 1941 | BM22 | VACUOUS | A | `set bm_c [bm_centre $BMTV {s:v(out)}]  -> "SKIPPED: BM22-BM34"` |
| 1947 | BM22 | VACUOUS | A | `an RMB on a leaf row posts, and returns 1` |
| 1950 | BM22 | VACUOUS | A | `the oracle now says `built:8`` |
| 1953 | BM22 | VACUOUS | A | `tk_popup was handed the menu and the ROOT coords` |
| 1958 | BM22 | VACUOUS | A | `with no root coords supplied they are derived from the tree's origin` |
| 1970 | BM23 | VACUOUS | A | `the menu is the exact eight-entry table ... {command\|v(out)\|disabled}` |
| 1980 | BM23 | VACUOUS | A | `the header names the row the gate picked ... [list {v(out)} disabled normal normal]` |
| 1986 | BM24 | VACUOUS | A | `the `Plot to` entry really is a cascade pointing at the submenu` |
| 1988 | BM24 | VACUOUS | A | `the submenu carries the four destinations, in dest_labels order` |
| 1992 | BM24 | VACUOUS | A | `[list wviewer::browser_plot_ids wvbm {s:v(out)} append] ...` |
| 2000 | BM24 | VACUOUS | A | `the top Plot entry passes no override at all ... {s:v(out)}` |
| 2013 | BM25 | VACUOUS | A | ``Descend to here` is LAST ... [list wviewer::browser_descend_to wvbm {s:v(out)}]` |
| 2020 | BM26 | VACUOUS | A | `pcall $BMTV selection set [list {s:v(out)} {s:net1} {s:vsweep}] ; bm_centre $BMTV {s:net1}` |
| 2027 | BM26 | VACUOUS | A | `a 3-row target headers `3 signals` and offers `Copy names (3)`` |
| 2030 | BM26 | VACUOUS | A | `...the entries act on all three ids ... {s:v(out) s:net1 s:vsweep}` |
| 2040 | BM27 | VACUOUS | B | `set bm_c3 [bm_centre $BMTV {g:x1.x2}]  -> "SKIPPED: BM27"` |
| 2044 | BM27 | VACUOUS | A,B | `an RMB on a GROUP posts (unlike the double-click, which refuses)` |
| 2047 | BM27 | VACUOUS | A,B | `...it acts on the group's leaves, headered as `2 signals`` |
| 2056 | BM28 | VACUOUS | A,D | `an RMB on an UNSELECTED row leaves the selection untouched   (setup 2053 `selection set [l` |
| 2062 | BM28 | VACUOUS | A,D | `...and on a SELECTED row it leaves it untouched too   (gate 2058 `bm_centre $BMTV {s:net1}` |
| 2068 | BM29 | VACUOUS | A | `an RMB on a row INSIDE the selection targets the whole selection ... {s:v(out) s:net1}` |
| 2073 | BM29 | VACUOUS | A | `...and on a row OUTSIDE it targets that row alone ... {s:vsweep}` |
| 2085 | BM30 | VACUOUS | A | `invoking `Plot` plots that row with NO override ... [list wvbm {v(out)} {}]` |
| 2095 | BM30 | VACUOUS | A | `...and the next real invoke still records (the recorder is alive)` |
| 2108 | BM31 | VACUOUS | A | ``Plot to -> New Strip` passes newstrip as a ONE-SHOT override` |
| 2117 | BM31 | VACUOUS | A | `...and NO set_plot_dest line reached the action log` |
| 2122 | BM31 | VACUOUS | A | `the other three cascade entries pass their own codes` |
| 2126 | BM31 | VACUOUS | A | `...and after all four the policy is STILL the untouched default` |
| 2144 | BM32 | VACUOUS | A | `under MULTI both admit the declared limit, from the ONE shared proc` |
| 2156 | BM33 | VACUOUS | A | ``Copy name` puts the full raw name on the clipboard ... {v(out)}` |
| 2158 | BM33 | VACUOUS | A | `...and it says so on the sidebar's status line (*copied 1 name*)` |
| 2166 | BM33 | VACUOUS | A | ``Copy names (3)` joins the three names with newlines   (setup 2160 `selection set [list {s` |
| 2168 | BM33 | VACUOUS | A | `...and the status line pluralises (*copied 3 names*)` |
| 2204 | BM34 | VACUOUS | A | `$bm_seq [list absent built:8 posted:8 built:8 absent]` |
| 2293 | BM40 | FAIL | A,C | `[bt_tree $BMVTV] [list {s:vsweep\|vsweep} {s:v(out)\|v(out)} {g:x1\|x1} ...]` |
| 2319 | BM42 | VACUOUS | A | `set bm_c [bm_centre $BMVTV {s:v(out)}]  -> "SKIPPED: BM42-BM45"` |
| 2327 | BM42 | VACUOUS | A | `a REAL RMB on a browser row posts the menu and reaches the canvas ZERO times` |
| 2333 | BM43 | VACUOUS | A | `the real menu's header is the real raw name from `xschem raw list`` |
| 2338 | BM43 | VACUOUS | A | `...and invoking its Plot entry added a REAL trace` |
| 2345 | BM44 | VACUOUS | A | ``Plot to -> New Strip` really created a strip on the real model` |
| 2347 | BM44 | VACUOUS | A | `...and the window's own destination is STILL the untouched default` |
| 2359 | BM44 | VACUOUS | A | ``Plot to -> New Tab` added a tab and still left the policy alone` |
| 2369 | BM46 | VACUOUS | A | `the tab switch inside New Tab took the built menu down with it` |
| 2373 | BM45 | VACUOUS | A | `set bm_c7 [bm_centre $BMVTV {s:i(x1.x2.net5)}]  -> "SKIPPED: BM45"` |
| 2383 | BM45 | VACUOUS | A | ``Send to Add Trace...` opens the dialog with the EXACT raw name prefilled` |
| 2394 | BM45 | VACUOUS | A | `with a MULTI-row target only the FIRST name is prefilled   (setup 2389 `selection set [lis` |
| 2421 | BM46 | VACUOUS | A | `a REAL tab switch takes the built menu down (it was there first) ... [list built:8 absent]` |

## `test_wave_sigbrowser_i12.tcl` — 7 (5 FAIL, 2 VACUOUS)

| line | check | effect | cause | fragment |
|---|---|---|---|---|
| 396 | BX30 | FAIL | B | `check {BX30 (POSITIVE CONTROL) a freshly populated tree reads `visible`} \     [bx_vis $BX` |
| 401 | BX30 | VACUOUS | B | `collapsing the ancestor reads `collapsed`, selection empty} \     [list [bx_vis $BXTV g:x1` |
| 423 | BX32 | FAIL | A (and B on the second e | `check {BX32 (POSITIVE CONTROL) scrolled to the bottom, x1.x2 reads `offscreen`} \     [lis` |
| 425 | BX32 | VACUOUS | A | `check {BX32 browser_reveal scrolls it back into view} ... [list 1 visible]` |
| 792 | BX45 | FAIL | show_path (+C: the root  | `check {BX45 at the sim top the selection is cleared and the reason given} \       [list [p` |
| 817 | BX50 | FAIL | C | `[lindex [pcall ::wviewer::browser_node_for $::wviewer::browserrows($bx_tok) \             ` |
| 842 | BX46 | FAIL | D | `check {BX46 ...nothing is selected, and the sidebar is still shown} \       [list [pcall $` |

## `test_wave_sigbrowser_i1315.tcl` — 7 (7 FAIL, 0 VACUOUS)

| line | check | effect | cause | fragment |
|---|---|---|---|---|
| 1169 | BP43 | FAIL | A | `check {BP43 (FIXTURE) the sidebar shows and the tree carries the groups} ... [pcall $BPT e` |
| 1198 | BP43 | FAIL | A + B + D | `check {BP43 the non-defaults TOOK: shown/dest/sel/collapse read back live} ... [pcall dict` |
| 1229 | BP45 | FAIL | A + D | `check {BP45 every field made it into the snapshot dict} ... [dict get $bpg sel] ... exp ..` |
| 1288 | BP52 | FAIL | A + D | `check {BP52 the tree SELECTION round-tripped} [pcall $BPT selection] {s:v(x1.x2.n1)}` |
| 1294 | BP53 | FAIL | B + A | `[pcall $BPT item g:x1 -open] [pcall $BPT item g:y3 -open]] [list 0 1]` |
| 1302 | BP54 | FAIL | A | `[pcall $BPT parent {s:v(x1.x2.n1)}]] [list 0 g:x1.x2]` |
| 1312 | BP55 | FAIL | A + D | `[pcall ::wviewer::browser_target_path $tok [pcall $BPT selection]] {ok x1.x2}` |

## `test_wave_sigbrowser_i14.tcl` — 1 (1 FAIL, 0 VACUOUS)

| line | check | effect | cause | fragment |
|---|---|---|---|---|
| 652 | BD50b | FAIL | A | `[$BVF.pw.tvf.tv exists {d:0\|s:v(alpha)}] [pcall $BVF.pw.tvf.tv parent {d:0\|s:v(alpha)}] ` |

## Refuted (26) — looked at, does not apply

| file | line | check | why |
|---|---|---|---|
| `test_wave_grid.tcl` | 473 | GH8 | GH8 is a pure doc-vs-source TEXT check, not a widget check. At tests/headless/test_wave_grid.tcl:473-474 the check reads `check "GH8 the guide's brows |
| `test_wave_grid.tcl` | 485 | GH9 | REFUTED. GH9 (tests/headless/test_wave_grid.tcl:485-486) is a pure source-text vs doc-text count with no widget fixture at all: gh_nbb counts lines ma |
| `test_wave_sigbrowser.tcl` | 1222 | BT26 | REFUTED. The check at line 1222-1223 (`check_true {BT26 and the three trees are genuinely three different values}`) never touches the treeview: it is  |
| `test_wave_sigbrowser.tcl` | 1278 | BT29 | The claim does not hold. The check at line 1278 — `check {BT29 a DOUBLE-CLICK on a GROUP plots nothing (declared limit D3)} $::bt_plot_calls {}` (Tk/X |
| `test_wave_sigbrowser.tcl` | 1307 | BT31 | REFUTED. BT31 at line 1307 (Tk/X arm — inside the `if {[info exists ::has_x] && [info commands winfo] ne {}}` block opened at line 988; fixture `.wvbt |
| `test_wave_sigbrowser.tcl` | 2091 | BM30 | BM30 at line 2091 (`check {BM30 invoking either DISABLED entry records nothing} $::bm_plot_calls {}`, Tk/X arm) is not made VACUOUS by cause A. Two in |
| `test_wave_sigbrowser.tcl` | 2110 | BM31 | REFUTED as stated. BM31's leg at line 2110 ("...and the window's own destination is untouched, never even created") does not become a silently-green v |
| `test_wave_sigbrowser.tcl` | 2142 | BM32 | REFUTED as stated. BM32 (tests/headless/test_wave_sigbrowser.tcl:2142-2145, Tk/X arm, inside `if {[info exists ::has_x] ...}` at 1812) asserts ONLY th |
| `test_wave_sigbrowser.tcl` | 2153 | BM33 | REFUTED. The BM33 sentinel at line 2153 (Tk/X arm, tests/headless/test_wave_sigbrowser.tcl) asserts only a clipboard round-trip on the fixture topleve |
| `test_wave_sigbrowser.tcl` | 2206 | BM34 | The BM34 check at line 2206 is not made vacuous by (A). Its two values come from `wviewer::browser_menu_unpost` (src/wave_viewer.tcl:7712 -> `ctx_menu |
| `test_wave_sigbrowser.tcl` | 2231 | BM36 | REFUTED — BM36's first check (tests/headless/test_wave_sigbrowser.tcl:2231-2232, Tk/X arm, BMF group) is already unconditionally true TODAY, so cause  |
| `test_wave_sigbrowser.tcl` | 2430 | BM47 | BM47 at line 2430 (`check {BM47 ...and no browser menu survived the close} [list [winfo exists $BMVM] [bm_menu_state $BMVM]] [list 0 absent]`) never a |
| `test_wave_sigbrowser_i11.tcl` | 632 | BH43 | REFUTED. BH43 (/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_sigbrowser_i11.tcl:632, Tk/X arm, BH50-BH54 block) is untouched by (A)( |
| `test_wave_sigbrowser_i11.tcl` | 654 | BH44 | BH44 (tests/headless/test_wave_sigbrowser_i11.tcl:654, Tk/X arm) is unaffected. The id it drives, `g:x1` (line 648), is a GROUP row, so (A) — which de |
| `test_wave_sigbrowser_i12.tcl` | 458 | BX36 | REFUTED. Line 458 is BX36's *return-value* assertion `[pcall ::wviewer::browser_show_path wvbx {}] {root {}}`. The item-10 sim-root change (src/wave_v |
| `test_wave_sigbrowser_i12.tcl` | 460 | BX36 | REFUTED. BX36's second leg (tests/headless/test_wave_sigbrowser_i12.tcl:460-461, X-arm) runs on the throwaway-toplevel fixture whose tree is seeded by |
| `test_wave_sigbrowser_i1315.tcl` | 1150 | BP41 | REFUTED. BP41 (line 1150, X/Tk arm) reads `browser_state $tok` on the window opened one check earlier by BP40, and that window's sidebar has never bee |
| `test_wave_sigbrowser_i1315.tcl` | 1158 | BP42 | BP42 (tests/headless/test_wave_sigbrowser_i1315.tcl:1158, X/Tk arm) snapshots a viewer whose sidebar has never been shown and whose treeview has never |
| `test_wave_sigbrowser_i1315.tcl` | 1253 | BP46 | BP46 (test_wave_sigbrowser_i1315.tcl:1253) reads browser_state on a viewer that was just closed and re-opened, with the sidebar HIDDEN and never toggl |
| `test_wave_sigbrowser_i1315.tcl` | 1317 | BP55 (CONTROL) | REFUTED. tests/headless/test_wave_sigbrowser_i1315.tcl:1317-1318 reads `check {BP55 (CONTROL) an EMPTY selection is refused by the same gate} [lindex  |
| `test_wave_sigbrowser_i1315.tcl` | 1378 | BP58 | BP58 runs on a window where the treeview is NEVER POPULATED, so item 10's (C) root node and (D) never-empty selection cannot reach it. The leg closes  |
| `test_wave_sigbrowser_i14.tcl` | 632 | BD48 | BD48 (tests/headless/test_wave_sigbrowser_i14.tcl:632-636, Tk/X arm) reads only the model, never the treeview: `bd_rows` is `return $::wviewer::browse |
| `test_wave_sigbrowser_i14.tcl` | 638 | BD49 | REFUTED. Two independent reasons. (1) BD49 (line 638) does not touch the treeview at all: bd_parent_text (line 147-158) walks the ROW MODEL — bd_rows  |
| `test_wave_sigbrowser_i14.tcl` | 643 | BD50 | BD50 (line 643 of /home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_sigbrowser_i14.tcl) reads only the row MODEL, never the treeview: bd |
| `test_wave_sigbrowser_i14.tcl` | 677 | BD51c | REFUTED. BD51c (tests/headless/test_wave_sigbrowser_i14.tcl:677-678, `[list [$BVF.pw.tvf.tv exists {d:0}] [llength [bd_rows $tok]]] [list 1 7]`) runs  |
| `test_wave_sigbrowser_panes.tcl` | 393 | BW34 | The claim is against a stale blob, not the working-tree file. In the on-disk tests/headless/test_wave_sigbrowser_panes.tcl, line 393 is BW29's expecte |
