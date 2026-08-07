# Two-pane Signal Browser — RED-first implementation plan

> **STOP — the tree moved under all four planners.** Item 1 (M1: `sig_declass` + the `class` field) is **already implemented and committed** as `422b3f55 fix(wviewer): strip ngspice device-class prefixes (0217)`. `wviewer::sig_declass` is live at `src/wave_viewer.tcl:1756`, `wviewer::sig_class` at `:1776`, `sig_split` already routes through it (`:1792`), and `signal_entry` already returns the fifth key (`:1810-1815`). SB07/SB10 are already at their new values and a **DC01-DC28+ band** already exists in `test_wave_sigsearch.tcl:455-575`. A `doc/claude/specs/waveform_signal_browser_two_pane.md` (721 lines) also already exists and settles most of what the four planners re-derived.
>
> **MEASURED BASELINE, re-run just now, all green:** sigsearch **139**, sigbrowser 135, i11 50, i12 29, i1315 80, i14 47, grid **214** = **694** `--nogui` checks (not 660). `test_wave_modes.tcl` = 212, separately.
>
> **LINE DRIFT: every `src/wave_viewer.tcl` anchor in all four plans is ~+65/+76 low.** Corrected table in §2 preamble. Test-file anchors are accurate.

---

## 0. Unresolved — driver rulings still owed

**None blocking.** Four holes the adversary found are real; three are resolved here by a *measured* default, and one is a doc correction. Listed so the driver can veto, not so the work waits.

1. **R8's rule and R8's own table contradict each other — resolved by measurement, not taste.**
   Spec §5.4 states "the instance half is the **last path segment**", but its own row 6 wants `i(@c.x1.c1[i])` → `c1:i`, and last-path-segment gives `x1:i`. I ran both candidate rules over all 2656 corpus names:

   | rule | reproduces spec §5.4's 7 rows | label collisions inside one own-level node |
   |---|---|---|
   | last-path-segment (as written) | 6 of 7 | **29** (`n_diffamp` `xr1`, `test_analog`, `montecarlo_mismatch_sim`, …) |
   | **hybrid (adopted)** | **7 of 7** | **0** |

   **STATED DEFAULT (adopted, item 6):** for a device-classed signal, the instance half is the **leaf's base** unless that base is *model-shaped* — i.e. contains `_` — in which case it is the **last path segment**. sky130 names the device inside a pcell wrapper after the model (`msky130_fd_pr__nfet_01v8`); a discrete `c1`/`r1`/`q1` is its own instance. This reproduces `xm1:id`, `c1:i`, `v1:i`, `xm1:#body` and every corpus name, with zero collisions. Escalate only if the driver prefers a per-class table (`@m`/`@n` carry a model segment, `@c`/`@r`/`@l`/`@b`/`@q` do not) — that is a one-proc swap in item 6 and nothing downstream moves.

2. **`i(@ibias[current])` renders `@ibias:current`.** 25 of 2656 corpus labels keep a leading `@` (untagged single-segment `@`-names, 11 in `cmos_ac_sweep`). **STATED DEFAULT:** strip one leading `@` from the instance half. Pinned by BQ12.

3. **The root node's own `-open` state.** "Collapsed by default" cannot include the root or the tree renders as one line. **STATED DEFAULT:** the design root is inserted `-open 1`; every other node `-open 0`. Pinned by BW21 as a two-value assertion.

4. **Two numbers in the spec/brief are wrong; correct them, do not re-derive them.** The "device node" counts. Measured with R1's own rule ("kept iff any signal at-or-under is `net`/`srcbranch`"): `tb_bandgap` 128 all / 44 kept / **84 hidden** (brief and spec §14 say 78); `tb_charge_pump` 316 / 13 / **303** (brief says 278). The first two of each triple reproduce exactly, so the classifier is right and the third figure was derived some other way. Item 19 fixes the spec text. Likewise **M6's flip count is 9 of 22, not 11** (measured: designs whose entry set has a path pre-filter and none post-`devint`-off).

Everything else the adversary raised is already ruled in `waveform_signal_browser_two_pane.md`: §7.1 (search does not touch the tree), §7.2 (the three status-line states), §7.3 (`sel` stays a list, narrowed on restore), §7.4 (R12's auto-tick **is** logged — it is user-initiated), §7.5 (an empty own level is not a hidden node), §7.6 (`browser_leaf_names` untouched), §9 (the three new keys, appended `sash devint srccur`), §6 (**a recursive plot obeys the checkboxes** — one consistent set).

---

## 1. Item table

Item 0 is verification only. Execution order is **B's** (pure model first, keys last) with **A's** accessor placement: the pure-model items put the most coverage into the `--nogui` arm *before* any pinned widget surface moves, so a red in items 9-13 can only be layout, and the C/`keybindings.csv` regeneration happens exactly once, late, under one X window.

| # | item | size | risk | pure/X | depends | reds existing |
|---|---|---|---|---|---|---|
| 0 | **VERIFY ONLY** — M1 already landed (`422b3f55`) | S | low | pure | — | none |
| 1 | `browser_tree` / `browser_sea` accessors — the 17-site sweep, paths UNCHANGED | S | low | pure+X | 0 | none |
| 2 | `browser_rows` gains optional `root` + `anypath` (R2 root row, M6 gate) | M | med | pure | 0 | none |
| 3 | `browser_class_filter` — R11's two policies as one pure proc | S | low | pure | 0 | none |
| 4 | `browser_tree_rows` + `browser_root_label` — the node model, R1's prune | L | med | pure | 2,3 | none |
| 5 | `browser_level_names` — own-level selector (R3) | M | low | pure | 2 | none |
| 6 | `browser_label` / `browser_label_full` — Cadence labels (R8) | M | med | pure | 0 | none |
| 7 | `browser_flow_layout` / `_cell` / `_hit` / `_scrollregion` (M2, R3) | M | low | pure | 0 | none |
| 8 | `browser_node_for {…{start {}}}` + the `d:N\|` decode fix (both sites) | M | med | pure | 2 | none |
| 9 | The paned skeleton, M4's scrollbars, `browse`, INERT checkboxes | L | high | X | 1,7 | BS22, BT21, BT22, BR20, BR21, BR23, BH40/41 paths, 21 test path literals |
| 10 | Upper pane live: node rows, root, collapsed-by-default | L | high | X | 4,8,9 | BT20/24/25/26/27/29/30/32/33/42, BM40, BX30, BP54 |
| 11 | Lower pane live: selection → own level → flow → canvas | L | high | X | 5,6,7,10 | GH8, GH9 |
| 12 | The two checkboxes stop being inert | M | med | X | 3,4,10,11 | none |
| 13 | `browser_reveal` / `browser_tree_apply` under collapsed-by-default | M | high | X | 10 | BX31, BX42, BP41, BP53, BP54 |
| 14 | Persistence: `sash` / `devint` / `srccur` | M | high | pure+X | 12,13 | BP10, BP13, BP45 |
| 15 | R7 — All-DBs headers + a design root per DB | M | med | pure+X | 4,8,10 | BD50; **not** BD19/BD21/BD22/BD25 |
| 16 | R9 — Ctrl-L → Ctrl-B, incl. the C-table row deletion | M | high | pure+X | 9 | BS03, BS04, BS05, BS09, BS42, BS45, BS46, GH1, GH3, GH5, GH6, test_bindings_file |
| 17 | R10 — Ctrl-Alt-V via the action registry + the selected-instance arm | L | high | pure+X | 16 | test_bindings_file, test_keybindings_help, BX13 |
| 18 | R12 — auto-tick, reveal, and say so | M | med | pure+X | 12,13,17 | none |
| 19 | Docs, oracles, the four-file lockstep, 0217 closed | M | low | pure | all | GS0, GS2, GH8, GH9, BT09, BX13 |

---

## 2. Items

**CITED-vs-ACTUAL, `src/wave_viewer.tcl` (all four plans are low by 65-76 lines; test files did not drift):**

| symbol | cited | **actual** |
|---|---|---|
| `sig_split` / `signal_entry` | 1726 / 1736 | **1791 / 1810** |
| `sig_declass` / `sig_class` (NEW, live) | — | **1756 / 1776** |
| `browser_rows` + the `anypath` gate | 6008-6012 | **6084-6088** |
| `browser_rows_reparent` / `_multi` / `_kind` / `_leaf_names` | 6136/6085/6180/6125 | **6136 / 6161 / 6180 / 6201** |
| `browser_build` | 6466 | **6542** |
| treeview create / `column #0` | 6517 / 6519-6522 | **6593-6594 / 6595** |
| the 4 tree binds | 6543-6561 | **6619, 6621, 6629, 6637** |
| `browser_alldbs` / `browser_refresh` / `browser_populate` | 6612 / 6663 / 6731 | **6688 / 6739 / 6807** |
| `browser_plot_at` / `browser_menu_ids` | 6770 / 6879 | **6894 / 6950** |
| `browser_target_path` + its `string range` | 7303 / 7325 | **7379 / 7397** |
| `browser_node_for` | 7504 | **7580** |
| `browser_reveal` / `browser_show_path` + its `string range` | 7574 / 7612 | **7650 / 7688 / 7765** |
| `browser_width` | 7775 | **7851** |
| `browser_state_default` / `_is_default` | 7977 / 7998 | **8053 / 8074** |
| `browser_tree_state` / `_apply` | 8030 / 8061 | **8106 / 8137** |
| `browser_state` / `_apply` | 8093 / 8134 | **8169 / 8210** |
| `install_default_binds` / the Ctrl-L bind / the rejection comment | 9238 / 9295 / 9288 | **9314 / 9372-9373 / 9364** |
| `key_filter` / graphkeys arm / `set fwd` | 11079 / 11130-39 | **11155 / 11206-11214 / 11214** |
| `graphkeys` `{97 98 100 115 109 116 65 66 77}` | 320 | **320** ✓ |

**Exact as cited:** `src/callback.c:4988`, `:1647`, `:6035`, `:5271`; `src/keybindings.csv:23` and `:46`; `src/cadence_style_rc:245`; `src/xschem.tcl:14938-14939`. **`.wvbrowser` in src = 20; `tvf.tv` = 17 (five in the `$windows`-dict form at `:6877, :7510, :7654, :8109, :8141`, twelve local `$f.tvf.tv`).** Tests: 73 `.wvbrowser`, 21 `tvf.tv`, and only **4** of those name `.tvf` in a docked path (`i11:413`, `i11:609`, `i12:595`, `sigbrowser:311`). **`bind $f.` in `browser_build` = 6; `data-bseq` rows = 6; `data-seq` = 16; `data-accel` = 11.** All confirmed.

---

### Item 0 — VERIFY ONLY: M1 already landed

**Scope.** No code. Confirm `422b3f55` is the tip and re-run the seven files.

**RED first.** Nothing. This item's whole content is that its expected reds have *already fired and been fixed*.

**Green.**
```
cd /home/qflow/dev/xschem/claude_1/xschem
for f in sigsearch sigbrowser sigbrowser_i11 sigbrowser_i12 sigbrowser_i1315 sigbrowser_i14 grid modes; do
  env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_$f.tcl | tail -1
done
```
must print `ALL PASS` at 139 / 135 / 50 / 29 / 80 / 47 / 214 / 212.

**Done when** that command prints those eight numbers. Record them in the ledger as the batch's real baseline (**694**, not 660). If sigsearch reads 107, you are on the wrong commit.

---

### Item 1 — `browser_tree` / `browser_sea` accessors

**Scope.** `src/wave_viewer.tcl`, immediately above `browser_refresh` (`:6739`):

```tcl
proc wviewer::browser_tree {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  return [dict get $windows $token top].wvbrowser.tvf.tv
}
proc wviewer::browser_sea {token} {
  variable windows
  if {![dict exists $windows $token]} { return {} }
  return [dict get $windows $token top].wvbrowser.sea.c
}
```
Replace the **five** `$windows`-dict spellings (`:6877, :7510, :7654, :8109, :8141`) with `wviewer::browser_tree $token`. The **twelve** local `$f.tvf.tv` reads inside `browser_build` / `browser_refresh` / `browser_show_path` (`:6593-6637, :6746, :6792, :7700, :7703`) stay local — they are *construction* and item 9 rewrites them. Add `wvbs_tv {top}` to `tests/headless/wvbs_common.tcl` returning `$top.wvbrowser.tvf.tv`, and re-point the four docked test literals (`i11:413`, `i11:609`, `i12:595`, `sigbrowser:311`) through it.

Spec contract lines for both accessors land in **this** commit (GS1).

**RED first** — new band `BN01`-`BN04` in the NEW file `tests/headless/test_wave_sigbrowser_model.tcl`:
```tcl
check {BN01 no $windows-dict tree spelling survives outside the accessor} \
  [regexp -all {windows \$token top\]\.wvbrowser\.tvf\.tv} $wsrc] 0
check {BN02 (POSITIVE CONTROL) the accessor itself carries exactly one} \
  [regexp -all {\.wvbrowser\.tvf\.tv} [wvproc_body $wsrc browser_tree]] 1
check {BN03 browser_tree on an unknown token ANSWERS {}, never throws} \
  [pcall ::wviewer::browser_tree nosuchtoken] {}
check {BN04 browser_tree on a faked window entry answers the docked path} \
  [pcall ::wviewer::browser_tree bn1] {.bnfake.wvbrowser.tvf.tv}
```
BN01 is red today (5 hits). **BN04 is the canary whose expected value item 9 changes** — pinning it now is what makes item 9's path move a deliberate red instead of a silent rename.

**Green.** The two procs exist; the five sites call them; every other number is byte-identical (694 + 4).

**Existing checks it reds.** None.

**Sabotages.**
- Leave `:8141` behind → **BN01 red**, BN02 green (control proves the grep is live).
- Make `browser_tree` throw on an unknown token → **BN03 red**, BN04 green.
- Return the FRAME (`…wvbrowser.tvf`) → BN04 red *and* dozens of X-arm checks red at once; run it, a green-everywhere result would mean the accessor is not on the live path.

**Done when** 694 + 4 checks green and `grep -c 'windows \$token top\]\.wvbrowser\.tvf\.tv' src/wave_viewer.tcl` is 0.

---

### Item 2 — `browser_rows` gains optional `root` and `anypath`

**Scope.** `src/wave_viewer.tcl:6084`:
```tcl
proc wviewer::browser_rows {entries {root {}} {anypath {}}} {
  if {![string is integer -strict $anypath]} {
    set anypath 0
    foreach e $entries {
      if {[wviewer::dget $e path {}] ne {}} { set anypath 1 ; break }
    }
  }
  set rows {}
  if {$root ne {}} {
    lappend rows [dict create id {g:} parent {} text $root kind group name {}]
  }
  ...                          ;# unchanged, except: a top-level row's parent
                               ;# starts at {g:} when $root ne {}, else {}
```
and `browser_rows_multi {groups {root {}}}` threads `$root` into each group's `browser_rows` call. **`browser_rows_reparent` is NOT touched** — it already re-keys `g:` → `d:0|g:` and re-parents correctly.

The root id is **`g:`** (empty prefix), per spec §4.1. *Verified:* `browser_target_path`'s group arm is `[string range $id 2 end]` (`:7397`) so `g:` decodes to the empty path — the legitimate sim-root ascend — with **zero change to that proc**. `r:` (plan A) and `root:` (test-delta) are both rejected: `root:` decodes to `ot:`.

`browser_leaf_names`, `_kind`, `_reparent`, `_node_for` bodies are **not edited** (R6).

**RED first** — `BN10`-`BN18` in `test_wave_sigbrowser_model.tcl`:
```tcl
# --- the anypath override, M6. TWO VALUES ON ONE FIXTURE. ---------------------
set bn_pre  [bn_ents {v(out) v(m.x1.xm1.msky130_fd_pr__nfet_01v8#body)}]
set bn_post [bn_ents {v(out)}]
check {BN10 (POSITIVE CONTROL, the DEFECT as a value) the gate answers 1 pre-filter and 0 post} \
  [list [bn_anypath $bn_pre] [bn_anypath $bn_post]] {1 0}
check {BN11 browser_rows with the gate AUTO flattens the filtered set} \
  [dict get [lindex [::wviewer::browser_rows $bn_post] 0] text] {v(out)}
check {BN12 ...and with the gate FORCED 1 it keeps hierarchy semantics} \
  [dict get [lindex [::wviewer::browser_rows $bn_post {} 1] 0] text] {out}
check {BN13 the override is BIDIRECTIONAL: forcing 0 on a pathed set flattens it} \
  [dict get [lindex [::wviewer::browser_rows $bn_pre {} 0] 0] text] {v(out)}
# --- the design root ----------------------------------------------------------
check {BN14 with no root arg the row list is byte-identical to the shipped one} \
  [::wviewer::browser_rows $bt_fix] $bn_frozen_digest
check {BN15 a root arg mints ONE row, id `g:`, parent {}, kind group, text the design} \
  [lrange [lindex [::wviewer::browser_rows $bt_fix tb_bandgap] 0] 0 end] \
  {id g: parent {} text tb_bandgap kind group name {}}
check {BN16 ...and every former top-level group now hangs off it} \
  [dict get [lindex [::wviewer::browser_rows $bt_fix tb_bandgap] 1] parent] {g:}
check {BN17 the root id decodes to the EMPTY path through the SHIPPED string range} \
  [string range {g:} 2 end] {}
check {BN18 an empty entry list still emits the root (R4 needs something to select)} \
  [llength [::wviewer::browser_rows {} tb_bandgap]] 1
```
BN10-BN13 and BN15-BN18 are red today (`wrong # args`). **BN14 must pass from the first run and never move** — it is the guard that every shipped caller is unchanged.

**Green.** The two optional args exist and are exercised by checks whose expected values *differ* between the two calls.

**Existing checks it reds.** None — BT10 (`:850`), BT11 (`:868, :877`), BT12 (`:884`), BT13 (`:890`), BD19 (`i14:366`), BD22 (`i14:385`), BX01-BX08 (`i12:220-269`) all call `browser_rows`/`_multi` with a bare list and stay green **by construction**. That is the whole point of making the args optional.

**Sabotages.**
- Ignore the `anypath` argument → **BN12 and BN13 red**, BN10/BN11 green. This is the silent-green trap in §3.5; run it.
- Default `anypath` to `1` instead of `{}` → **BN14 red** (a truly flat inventory grows groups).
- Emit the root unconditionally → **BT10, BT12, BD19, BD22, BX01 red at once**; that five-file fan-out is the signature of a mandatory arg.

**Done when** BN10-BN18 green and the seven baseline files are untouched at 694 + 4 + 9.

---

### Item 3 — `browser_class_filter` (R11's model half)

**Scope.** `src/wave_viewer.tcl`, beside `browser_rows`:
```tcl
proc wviewer::browser_class_filter {entries devint srccur} {
  set out {}
  foreach e $entries {
    switch -exact -- [wviewer::dget $e class net] {
      devnode -  devmeas   { if {!$devint} continue }
      srcbranch          { if {!$srccur} continue }
    }
    lappend out $e
  }
  return $out
}
```
An entry with **no** `class` key defaults to `net` and survives every combination — that is what keeps every pre-M1 hand-built fixture inert.

**RED first** — `BN20`-`BN29`, driving the **committed** name fixture (see §4):
```tcl
check {BN20 (FIXTURE CONTROL) the tb_bandgap fixture is intact} [llength $bn_bg] 424
check {BN21 (FIXTURE CONTROL) and it really carries all four classes} \
  [bn_hist $bn_bg] {net 140 devnode 234 devmeas 0 srcbranch 50}
check {BN22 both on is the IDENTITY (list equality, not length)} \
  [::wviewer::browser_class_filter $bn_bg 1 1] $bn_bg
check {BN23 devint 0 / srccur 1 -> the MEASURED 190} \
  [llength [::wviewer::browser_class_filter $bn_bg 0 1]] 190
check {BN24 devint 1 / srccur 0 -> the MEASURED 374} \
  [llength [::wviewer::browser_class_filter $bn_bg 1 0]] 374
check {BN25 devint 0 / srccur 0 -> the MEASURED 140} \
  [llength [::wviewer::browser_class_filter $bn_bg 0 0]] 140
check {BN26 the four totals are FOUR DIFFERENT values (one ignored box is an equality)} \
  [llength [lsort -unique [list 424 190 374 140]]] 4
check {BN27 a TOP-LEVEL branch current i(e5) is class net and SURVIVES srccur 0} \
  [bn_has [::wviewer::browser_class_filter $bn_cp 0 0] {i(e5)}] 1
check {BN28 the sweep variable survives every combination (M8)} \
  [list [bn_has [::wviewer::browser_class_filter $bn_bg 0 0] time] \
        [bn_has [::wviewer::browser_class_filter $bn_bg 1 1] time]] {1 1}
check {BN29 an entry with NO class key is never hidden} \
  [llength [::wviewer::browser_class_filter [list [dict create name x path {} leaf x type v]] 0 0]] 1
check {BN30 (DEVMEAS CONTROL — tb_bandgap has ZERO devmeas) charge_pump moves by 283} \
  [expr {[llength $bn_cp] - [llength [::wviewer::browser_class_filter $bn_cp 0 1]]}] 1045
```
BN30 exists because **tb_bandgap cannot see a devnode/devmeas mix-up at all** (0 devmeas). Without the second fixture, "drop devmeas with srcbranch instead of with devnode" is invisible.

**Green.** The proc exists; all four measured totals reproduce.

**Existing checks it reds.** None — nothing calls it yet.

**Sabotages.**
- Fold the two flags into one → **BN24 red** (374 becomes 190 or 424), BN23 green.
- Drop `devmeas` with `srcbranch` → **BN30 red**, BN23/BN25 green *on tb_bandgap*. Run it: this is the sabotage that proves why the second fixture is committed.
- Key `srccur` on the `i(` prefix instead of the class → **BN27 red** alone.
- Drop the missing-`class` default → **BN29 red**.

**Done when** BN20-BN30 green, +11.

---

### Item 4 — `browser_tree_rows` + `browser_root_label` (R1, R2)

**Scope.** Two new procs beside `browser_rows`.

```tcl
# PURE. Rows -> the NODE-ONLY projection, parents before children.
proc wviewer::browser_tree_rows {rows} {
  set out {}
  foreach r $rows {
    if {[wviewer::dget $r kind {}] ne {group}} { continue }
    lappend out $r
  }
  return $out
}
# The design name for the root row. NEVER {} — R2 requires the row to exist.
proc wviewer::browser_root_label {path} {
  if {$path eq {}} { return design }
  set b [file rootname [file tail $path]]
  regsub {_ase$} $b {} b
  if {$b eq {}} { return design }
  return $b
}
```
**R1's device-node prune is NOT a third proc.** It falls out of item 3 for free, and that is the architectural decision of this batch: `browser_refresh` runs `browser_class_filter` **before** `browser_rows`, so a node all of whose signals are device-classed has no surviving entry and is never minted. Spec §6 ("one consistent set") rules this, and it satisfies R1's "exclude only if EVERY signal at or under it is device-classed" **exactly and structurally** — `xr1.x0` survives because its `t1`/`t2` nets survive. Verified against the corpus: 128 → 44 for `tb_bandgap`, 316 → 13 for `tb_charge_pump`.

M6 is why item 2 landed first: the `anypath` gate must see the **pre**-filter set.

**RED first** — `BN40`-`BN52`:
```tcl
check {BN40 tb_bandgap, all classes -> 128 nodes}  [bn_nodecount $bn_bg 1 1] 128
check {BN41 ...net-carrying only -> 44}            [bn_nodecount $bn_bg 0 1] 44
check {BN42 ...the difference, MEASURED, is 84 (the spec's 78 is wrong)} \
  [expr {[bn_nodecount $bn_bg 1 1] - [bn_nodecount $bn_bg 0 1]}] 84
check {BN43 tb_charge_pump 316 / 13 / 303}  \
  [list [bn_nodecount $bn_cp 1 1] [bn_nodecount $bn_cp 0 1] \
        [expr {[bn_nodecount $bn_cp 1 1]-[bn_nodecount $bn_cp 0 1]}]] {316 13 303}
check {BN44 (THE R1 CONTROL) xr1.x0 carries real nets AND @r measurements and SURVIVES,
       while a pure-device sibling does not — one check, two nodes} \
  [list [bn_hasnode $bn_nd 0 1 {xr1.x0}] [bn_hasnode $bn_nd 0 1 {xr1.x0.xdev}]] {1 0}
check {BN45 (R1's MEASURED NO-OP) an x-prefix filter would hide NOTHING} \
  [llength [lsearch -all -not -inline -glob $bn_segs x*]] 0
check {BN46 browser_tree_rows emits NO leaf rows} \
  [lsearch -exact [bn_kinds [::wviewer::browser_tree_rows $bt_rows]] leaf] -1
check {BN47 ...and it preserves parent-before-child order} \
  [bn_parents_precede [::wviewer::browser_tree_rows $bt_rooted]] 1
check {BN48 ...the root survives the projection and is FIRST} \
  [dict get [lindex [::wviewer::browser_tree_rows $bt_rooted] 0] id] {g:}
check {BN49 the node ids are BYTE-IDENTICAL to browser_rows' group ids} \
  [bn_ids [::wviewer::browser_tree_rows $bt_rooted]] [bn_group_ids $bt_rooted]
check {BN50 browser_root_label strips the _ase suffix and the directory} \
  [::wviewer::browser_root_label {/x/y/tb_bandgap_ase.raw}] tb_bandgap
check {BN51 ...and NEVER answers {}} \
  [list [::wviewer::browser_root_label {}] [::wviewer::browser_root_label {/x/.raw}]] {design design}
check {BN52 a devnode-only design still emits its root row} \
  [llength [::wviewer::browser_tree_rows \
     [::wviewer::browser_rows [::wviewer::browser_class_filter $bn_devonly 0 1] d]]] 1
```

**Green.** Both procs exist; the six measured node counts reproduce.

**Existing checks it reds.** None.

**Sabotages.**
- Prune with "exclude if **ANY** signal under it is device-classed" (the inversion) → **BN44's first leg red**, BN41 collapses well below 44.
- Filter on the x-prefix instead of the class → **BN40 == BN41 == BN43**, three checks red at once; the measured no-op made visible.
- Let `browser_tree_rows` keep leaves → **BN46 red**, BN49 green.
- Return `{}` from `browser_root_label` on a pathless token → **BN51 red**, and item 10's root row loses its text.

**Done when** BN40-BN52 green, +13.

---

### Item 5 — `browser_level_names` (R3)

**Scope.**
```tcl
# PURE. The FULL RAW NAMES whose declassed path is EXACTLY $nodepath, in entry
# order. NOT browser_leaf_names — that one is recursive and R6 keeps it so; the
# two must stay greppably distinct so a later edit cannot merge them.
proc wviewer::browser_level_names {entries nodepath} {
  set out {}
  foreach e $entries {
    if {[wviewer::dget $e path {}] ne $nodepath} { continue }
    lappend out [wviewer::dget $e name {}]
  }
  return $out
}
```

**RED first** — `BN60`-`BN66`:
```tcl
check {BN60 the ROOT's own level is tb_bandgap's 18 top-level signals (R2)} \
  [llength [::wviewer::browser_level_names $bn_bg {}]] 18
check {BN61 (THE R3/R6 CONTRAST, both values in ONE check) x1 own-level vs recursive} \
  [list [llength [::wviewer::browser_level_names $bn_bg x1]] \
        [llength [::wviewer::browser_leaf_names [::wviewer::browser_rows $bn_bg] {g:x1}]]] \
  {43 406}
check {BN62 the largest own-level anywhere in the corpus is 52} $bn_max_own 52
check {BN63 a PURE ANCESTOR answers {} — an ANSWER, not a throw} \
  [pcall ::wviewer::browser_level_names $bn_bg {x1.x1.x1}] {}
check {BN64 ...and tb_bandgap has 18 such nodes of 128, 12 of the 44 kept} \
  [list $bn_empty_all $bn_empty_kept] {18 12}
check {BN65 a nodepath that does not exist answers {} without throwing} \
  [pcall ::wviewer::browser_level_names $bn_bg zzz] {}
check {BN66 it returns FULL RAW NAMES, not leaves or labels} \
  [lindex [::wviewer::browser_level_names $bn_bg x1.x2] 0] $bn_first_x1x2_raw
```
BN61 is the standing proof R6 survived: 43 and 406 are two different numbers on one fixture.

**Green.** The proc exists; the six measured counts reproduce.

**Sabotages.**
- `string match $nodepath.*` instead of exact equality → **BN61 becomes `{406 406}`**, one red.
- Return declassed leaves instead of raw names → **BN66 red**, BN60/BN61 green; and item 11's copy-full-name check reds cross-item.

**Done when** BN60-BN66 green, +7.

---

### Item 6 — `browser_label` / `browser_label_full` (R8)

**Scope.** Beside `sig_split` (`:1791`). **The rule is §0.1's measured hybrid.**

```tcl
# The DISPLAY string for a raw name. Display, NEVER identity — browser_label_full
# is the identity, and it is a named proc so "the tooltip and the clipboard carry
# the full raw name" is greppable and not a comment.
#
# ⚠ THE MODEL DISCRIMINATOR IS `_` IN THE LEAF BASE, and it is MEASURED, not
# reasoned: sky130 wraps each MOSFET in a pcell subckt (`xm1`) whose inner device
# is named after the MODEL (`msky130_fd_pr__nfet_01v8`), while a discrete
# `c1`/`r1`/`q1` IS the instance. Over 2656 corpus names this reproduces all seven
# of spec §5.4's rows with ZERO duplicate labels inside any own-level node; the
# spec's literally-stated "last path segment" rule reproduces six and collides 29
# times (`n_diffamp` xr1 renders `x0:i` three times).
proc wviewer::browser_label {name} {
  lassign [wviewer::sig_declass [wviewer::sig_bare $name]] tag rest
  set cls [wviewer::sig_class $tag]
  lassign [wviewer::sig_split $name] path leaf
  if {$cls eq {net} && [wviewer::sig_type $name] eq {v}} { return $leaf }
  set base $leaf ; set par {}
  if {[regexp {^(.*)\[([^]]*)\]$} $leaf -> b p]} { set base $b ; set par $p } \
  elseif {[regexp {^([^#]*)(#.*)$} $leaf -> b p]} { set base $b ; set par $p }
  if {$par eq {}} { set par i }
  set inst $base
  if {($cls eq {devnode} || $cls eq {devmeas}) && [string match {*_*} $base] \
      && $path ne {}} {
    set inst [lindex [split $path .] end]
  }
  regsub {^@} $inst {} inst        ;# 25 corpus names, e.g. i(@ibias[current])
  if {$inst eq {}} { return $leaf }
  return "$inst:$par"
}
proc wviewer::browser_label_full {name} { return $name }
```

**RED first** — new file `tests/headless/test_wave_sigbrowser_sea.tcl`, band `BQ`:
```tcl
# --- spec §5.4's SEVEN rows, VERBATIM, one check --------------------------------
check {BQ01 the spec 5.4 table renders exactly} [bq_map {
    v(vbg)  v(x1.adj)  i(v1)  i(v.x1.v1)
    i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])  i(@c.x1.c1[i])
    v(m.x1.xm1.msky130_fd_pr__nfet_01v8#body)}] \
  {vbg adj v1:i v1:i xm1:id c1:i xm1:#body}
check {BQ02 (THE DUAL) a SHORT instance name is not mistaken for a model} \
  [::wviewer::browser_label {i(@r.x1.r1[i])}] {r1:i}
check {BQ03 (THE OTHER DUAL) a v-typed device MEASUREMENT is not rendered bare} \
  [::wviewer::browser_label {v(@q.xq1.qsky130_fd_pr__pnp_05v5_w3p40l3p40[vbe])}] {xq1:vbe}
check {BQ04 an UNWRAPPED @-name (sig_type `other`) still renders} \
  [::wviewer::browser_label {@m.xm5.msky130_fd_pr__nfet_01v8[gm]}] {xm5:gm}
check {BQ05 the nine MEASURED params pass through verbatim} [bq_params] \
  {id i current is ie ic ib vth vbe gm}
check {BQ06 (M9) a trailing bracket is the param; an EMBEDDED one is a path segment} \
  [list [::wviewer::browser_label {v(x1.xm1[0].d)}] \
        [::wviewer::browser_label {i(@m.x1.xm1[3].msky130_fd_pr__nfet_01v8[id])}]] \
  {d xm1[3]:id}
check {BQ07 (SB08's twin) a BUS BIT net is NOT bracket-parsed} \
  [::wviewer::browser_label {v(x1.data[3])}] {data[3]}
check {BQ08 i(vcc) and v(vcc) — same design, same level — render DIFFERENTLY} \
  [list [::wviewer::browser_label {i(vcc)}] [::wviewer::browser_label {v(vcc)}]] {vcc:i vcc}
check {BQ09 an XSPICE `n.` node keeps its #suffix} \
  [::wviewer::browser_label {v(n.xu1.n1#flow(out))}] {n1:#flow(out)}
check {BQ10 an unrenderable shape comes back NON-EMPTY (an empty row is unclickable)} \
  [expr {[::wviewer::browser_label {}] eq {} ? 0 : 1}] 1
check {BQ11 browser_label_full is the IDENTITY on all seven} [bq_full_ok] 1
check {BQ12 no label in the whole 2656-name corpus begins with @} $bq_at 0
check {BQ13 (THE COLLISION SWEEP) no own-level node anywhere renders a duplicate label} \
  $bq_dups 0
```
**BQ13 is the check that kills the spec's literal rule** — it reads 29 under last-path-segment and 0 under the hybrid.

**Green.** `browser_label` as above; BQ01-BQ13 pass.

**Sabotages.**
- Drop the model arm → **BQ01 red** (`msky130_…:id`), BQ02 green.
- Take the instance from the last path segment unconditionally → **BQ01 red** at row 6 (`x1:i`) *and* **BQ13 = 29**; the two sabotages are duals and prove both arms are covered.
- Anchor the param regexp without `$` → **BQ06 red** (`0` becomes the param).
- Return `{}` for an unknown shape → **BQ10 red** — this is what stops an empty pane looking like an empty level.

**Done when** BQ01-BQ13 green, +13.

---

### Item 7 — `browser_flow_*` (M2, R3)

**Scope.** Four pure procs ported from `::tk::IconList::Arrange` (`/usr/share/tcltk/tk8.6/iconlist.tcl:301-376`, `DrawSelection :378-397`) — **copied, not subclassed** (M2). `rowh`/`colw` are **arguments**; the caller reads `font metrics AseEntryFont -linespace` at runtime and never hardcodes.

```tcl
proc wviewer::browser_flow_layout  {n availh rowh}          -> {rowsPerCol ncols}
proc wviewer::browser_flow_cell    {i rowsPerCol colw rowh} -> {x y}
proc wviewer::browser_flow_hit     {px py rowsPerCol colw rowh n} -> index | -1
proc wviewer::browser_flow_scrollregion {ncols colw availh}  -> {0 0 W H}
```
`rowsPerCol = max(1, int(availh/rowh))`; `ncols = ceil(n/rowsPerCol)`; hit is `col*rowsPerCol + row`, **never `find closest`**.

**RED first** — `BQ20`-`BQ33`:
```tcl
check {BQ20 n=0 -> no columns at all, and a hit answers -1} \
  [list [::wviewer::browser_flow_layout 0 400 20] \
        [::wviewer::browser_flow_hit 5 5 20 100 20 0]] {{20 0} -1}
check {BQ21 exact fit gives ONE column} [::wviewer::browser_flow_layout 20 400 20] {20 1}
check {BQ22 one over gives TWO (the ceil, not int/)} \
  [::wviewer::browser_flow_layout 21 400 20] {20 2}
check {BQ23 exact double gives TWO, never a phantom third} \
  [::wviewer::browser_flow_layout 40 400 20] {20 2}
check {BQ24 availh smaller than one row still gives rows 1, never 0} \
  [::wviewer::browser_flow_layout 5 10 20] {1 5}
check {BQ25 a zero or negative rowh ANSWERS (font metrics can report 0 mid-map)} \
  [list [::wviewer::browser_flow_layout 5 400 0] [::wviewer::browser_flow_layout 5 400 -3]] \
  {{1 5} {1 5}}
check {BQ26 the MEASURED geometries: 424 names, 400px pane, rowh 20} \
  [::wviewer::browser_flow_layout 424 400 20] {20 22}
check {BQ27 the largest own-level node anywhere (52)} \
  [::wviewer::browser_flow_layout 52 400 20] {20 3}
check {BQ28 COLUMN-MAJOR: item 1 is BELOW item 0, not beside it} \
  [list [::wviewer::browser_flow_cell 0 20 100 20] [::wviewer::browser_flow_cell 1 20 100 20]] \
  {{0 0} {0 20}}
check {BQ29 ...and item rowsPerCol starts the NEXT column} \
  [::wviewer::browser_flow_cell 20 20 100 20] {100 0}
check {BQ30 (THE ROUND TRIP) hit(centre(cell(i))) == i for every i in 0..423} $bq_rt {}
check {BQ31 (BQ30's PERTURBATION CONTROL) +rowh -> i+1, +colw -> i+rowsPerCol} \
  [list [bq_hit_at 17 0 20] [bq_hit_at 17 100 0]] {18 37}
check {BQ32 dead space past the last partial column answers -1, NOT the nearest item} \
  [::wviewer::browser_flow_hit 250 380 20 100 20 45] -1
check {BQ33 the scrollregion HEIGHT is clamped to the pane — horizontal scrolling ONLY} \
  [::wviewer::browser_flow_scrollregion 22 100 400] {0 0 2200 400}
```
**BQ32 is the only check that distinguishes M2's arithmetic from Tk's `find closest`**, which always returns the nearest item and never -1. **BQ30 without BQ31 is green on a hit-test that returns `int(py/rowh)`.**

**Green.** The four procs exist; BQ20-BQ33 pass with `$bq_rt` (the failing-index list) empty.

**Sabotages.**
- Swap to row-major → **BQ28/BQ29 red**, BQ30 still green — which is exactly why BQ28 exists.
- Keep IconList's nearest-item fallback → **BQ32 red** alone. Run it.
- `int(n/rowsPerCol)` without the ceiling → **BQ22 red**.
- Clamp rows to 0 on a tiny `availh` → **BQ24 red**, and `ncols` goes infinite.

**Done when** BQ20-BQ33 green, +14.

---

### Item 8 — `browser_node_for` root-skip + the `d:N|` decode fix

**Scope.** Three edits, all pure, all forced by item 2's root row.

1. `browser_node_for {rows segs {start {}}}` (`:7580`) — `set parent $start` instead of `set parent {}`. **VERIFIED NECESSARY:** the walk scans for a group whose `parent` is `{}` (`:7589`); with a root at `g:` every real instance hangs off `g:`, so the walk dead-ends and answers `{{} 0}`.
2. NEW `wviewer::browser_root_id {rows}` → the **current DB's** design-root id: `g:` normally, `d:0|g:` when All-DBs put the current DB under a header (item 15). Pure, scans for the first row whose id ends in `g:` and whose text is not a DB label.
3. **The pre-existing `d:N|` defect (spec §4.3, filed as a new issue in item 19).** `browser_target_path:7397` and `browser_show_path:7765` both do `[string range $id 2 end]`, which mis-decodes `d:0|g:x1.x2` into `0|g:x1.x2`. Fix **both**: strip a leading `d:<digits>|` first, then the two-char prefix.
4. `browser_target_path`'s leaf arm (`:7399`) reads `sig_split` on the **raw name**. Change it to prefer the row's stored `path` key when present. *(Adversary item 18 — moot for tree rows, live for the sea's RMB menu, which posts leaf ids.)*

**RED first** — `BN70`-`BN78`:
```tcl
check {BN70 (CONTROL) an UNROOTED row list still resolves with the default start} \
  [::wviewer::browser_node_for $bx_rows {x1 x2}] {g:x1.x2 2}
check {BN71 a ROOTED list resolves the same path when started at the root} \
  [::wviewer::browser_node_for $bx_rooted {x1 x2} {g:}] {g:x1.x2 2}
check {BN72 ...and started at {} it does NOT — the root-skip is load-bearing} \
  [::wviewer::browser_node_for $bx_rooted {x1 x2}] {{} 0}
check {BN73 browser_root_id finds the unprefixed root} \
  [::wviewer::browser_root_id $bx_rooted] {g:}
check {BN74 ...and the CURRENT DB's prefixed root under All-DBs} \
  [::wviewer::browser_root_id $bx_multi] {d:0|g:}
check {BN75 browser_target_path decodes a PREFIXED group id} \
  [bn_tpath $bx_multi {d:0|g:x1.x2}] {ok x1.x2}
check {BN76 (POSITIVE CONTROL) ...and the unprefixed form still decodes} \
  [bn_tpath $bx_rooted {g:x1.x2}] {ok x1.x2}
check {BN77 ...and the ROOT id decodes to the sim root} [bn_tpath $bx_rooted {g:}] {ok {}}
check {BN78 a LEAF row's path comes from its stored key, not a re-parse of the name} \
  [bn_tpath $bx_rooted {s:i(@m.x1.m1[id])}] {ok x1}
```
BN71-BN78 are red today. BN70 must pass from the first run and never move — it is BX01's local twin and the guard that the default start is unchanged.

**Green.** The three edits land; BX01-BX08 (`i12:220-269`) stay green untouched.

**Existing checks it reds.** None.

**Sabotages.**
- Hard-code `set parent {g:}` instead of taking the argument → **BN70 red**, BN71 green.
- Strip two characters unconditionally in `browser_target_path` → **BN76 red**.
- Fix `browser_target_path` and forget `browser_show_path:7765` → BN75 green, and item 10's BW-arm reveal on a foreign node lands on garbage; **BW34** is the check that sees it.

**Done when** BN70-BN78 green, +9. Model file total ≈ 62.

---

### Item 9 — The paned skeleton, M4's scrollbars, `browse`, INERT checkboxes

> **DONE.** Receipt: `09_receipt.md`. ⚠ **Two of the checks sketched below were WRONG and were replaced after being run** — see §"Corrections" at the end of this item. The band as built is BW01-BW14 (`--nogui`) + BW20-BW35 (X).

> **This is the pinned-surface move, and it happens exactly ONCE.** Everything the layout checks pin moves here; items 10-13 add behaviour to a shape that has already stopped moving.

**Scope.** `src/wave_viewer.tcl` `browser_build` (`:6542-6660`):

- `frame $f.opt` holding `ttk::checkbutton $f.opt.dev` ("Show device internals", `-variable ::wviewer::browserdev($token)`, seeded **0**) and `$f.opt.src` ("Show source currents", `-variable ::wviewer::browsersrc($token)`, seeded **1**). **Built and packed, but `-command {}` — INERT.** Item 12 wires them. Neither gets an accelerator (GH4/GH0 stay at 11).
- `ttk::panedwindow $f.pw -orient vertical` (M3).
- The tree frame becomes `$f.pw.tvf` (keeping the name `tvf` so the guide's four `data-bseq` values become `pw.tvf.tv …`, a one-token edit): `ttk::treeview $f.pw.tvf.tv -show tree -selectmode browse -style Ase.Treeview -yscrollcommand [list $f.pw.tvf.sb set] -xscrollcommand [list $f.pw.tvf.hsb set]`; `$f.pw.tvf.tv column #0 -width 200 -minwidth 80 -stretch 0` (**M4** — `-stretch 1` today at `:6595`, and inside `pack propagate 0` a stretching column always fits, so an h-scrollbar would be decorative).
- `$f.pw.sea` from a new `wviewer::browser_sea_build {parent}`: `canvas $f.pw.sea.c -takefocus 1 -xscrollcommand [list $f.pw.sea.hsb set]` + `scrollbar $f.pw.sea.hsb -orient horizontal`. **No `-yscrollcommand`, no vertical scrollbar** (R3).
- `$f.pw add $f.pw.tvf -weight 1` then `$f.pw add $f.pw.sea -weight 1` — tree on top (M3).
- Pack: `$f.opt -side top -fill x` after `$f.tb`; `$f.pw -side top -fill both -expand 1` in `$f.tvf`'s old slot. **`browser_width` (`:7851`) is NOT touched** (M5) — `$f` still receives `-width`; `$f.pw` is its child.
- `browser_tree`/`browser_sea` (item 1) each change **one line**. The twelve local `$f.tvf.tv` reads become `$f.pw.tvf.tv`.
- `browserdev` / `browsersrc` declared **and unset** in the teardown block beside `browserrows`.
- Sash: a `browser_sash {token {want {}}}` accessor lands here; **persistence is item 14**. Default 0.55, applied on the idle queue from `browser_show`'s **pack** branch — after `browser_width`'s `catch {update idletasks}` (`:7865`), because `sashpos` on an unmapped pane computes `fraction × 0` and collapses the tree pane.

`doc/waveform_viewer_guide.html:1135,1139,1143,1147`: `data-bseq="tvf.tv …"` → `pw.tvf.tv …`. **GH8's count `6` does not move in this item** — four rows change value, none is added.

**RED first.** Edit these to their new values **first**; each is red against today's source.

```tcl
# BN04 (item 1's canary) -> .bnfake.wvbrowser.pw.tvf.tv
# BS22 test_wave_sigbrowser.tcl:308
check {BS22 the frame's children are exactly item 13's set} \
  [lsort [winfo children $F]] \
  [lsort [list $F.ph $F.wvsearch $F.tb $F.opt $F.pw $F.wvfilter $F.loc]]
# BT21 :1089
check {BT21 the tree is a browse-mode Treeview with BOTH scrollbars} \
  [list [winfo class $BTTV] [$BTTV cget -selectmode] \
        [winfo exists $BTF.pw.tvf.sb] [winfo exists $BTF.pw.tvf.hsb]] \
  {Treeview browse 1 1}
# BT21 :1109 / :1112
check {BT21 the packing recipe is the seven-slave stack} [pack slaves $BTF] \
  [list $BTF.loc $BTF.wvsearch $BTF.tb $BTF.ph $BTF.wvfilter $BTF.opt $BTF.pw]
check {BT21 ...and its sides} [bs_sides $BTF] {top top top bottom bottom top top}
```
plus the mechanical `s/\.wvbrowser\.tvf/.wvbrowser.pw.tvf/` at `i11:413`, `i11:609`, `i12:595`, `sigbrowser:311`, and the same in `wvbs_tv`.

New file `tests/headless/test_wave_sigbrowser_panes.tcl`, band `BW`:
```tcl
check {BW01 $f.pw is a vertical TPanedwindow with exactly two panes, tree first} \
  [list [winfo class $F.pw] [$F.pw cget -orient] [$F.pw panes]] \
  [list TPanedwindow vertical [list $F.pw.tvf $F.pw.sea]]
check {BW02 (M4, ONE CHECK — either leg alone goes green on a dead scrollbar)
       column #0 is -stretch 0 with a width, and -xscrollcommand is set} \
  [list [$TV column #0 -stretch] [expr {[$TV column #0 -width] > 0}] \
        [expr {[$TV cget -xscrollcommand] ne {}}]] {0 1 1}
check {BW03 (SOURCE) browser_build carries no -stretch 1 any more} \
  [regexp -all {-stretch 1} $bw_build] 0
check {BW04 the sea has a HORIZONTAL scrollbar and NO vertical one} \
  [list [lsort [winfo children $F.pw.sea]] [$F.pw.sea.hsb cget -orient] \
        [$F.pw.sea.c cget -yscrollcommand]] \
  [list [lsort [list $F.pw.sea.c $F.pw.sea.hsb]] horizontal {}]
check {BW05 the two checkbuttons exist, in R11's order, with R11's DIFFERENT defaults} \
  [list [winfo class $F.opt.dev] [set ::wviewer::browserdev($tok)] \
        [set ::wviewer::browsersrc($tok)]] {TCheckbutton 0 1}
check {BW06 ...and they are INERT for now} \
  [list [$F.opt.dev cget -command] [$F.opt.src cget -command]] {{} {}}
check {BW07 ...and they are per-TOKEN, not namespace globals} \
  [regexp -all {browserdev\(\$token\)} $bw_build] 1
check {BW08 (BT08's LOCAL TWIN) browser_build still changes NO geometry} \
  [list [regexp -all {pack propagate} $bw_build] [regexp -all {pack \$f } $bw_build]] {0 0}
check {BW09 the four STANDING CONTROLS are still green: BT08's four width literals} \
  [bw_width_literals] {1 1 1 1}
check {BW10 selecting two rows programmatically leaves ONE selected} \
  [begin {$TV selection set [list g:x1 g:x1.x2]}; llength [$TV selection]] 1
check {BW11 (BW10's CONTROL — ttk gates selectmode in the CLASS BINDINGS, not in
       `selection set`; so BW10 only means anything next to this) } \
  [begin {$TV configure -selectmode extended
          $TV selection set [list g:x1 g:x1.x2]
          set r [llength [$TV selection]]
          $TV configure -selectmode browse; set r}] 2
check {BW12 (M4 BEHAVIOURAL) a DEEP tree really has something to h-scroll} \
  [expr {[$TV xview] ne {0 1}}] 1
check {BW13 (BW12's CONTROL) a ONE-LEVEL tree does not} [expr {[$TV xview] eq {0 1}}] 1
check {BW14 the sash reads a FRACTION strictly between 0 and 1 on a MAPPED pane} \
  [list [expr {[winfo height $F.pw] > 1}] \
        [expr {[bs_sash_frac $F.pw] > 0 && [bs_sash_frac $F.pw] < 1}]] {1 1}
```
**BW11 matters:** verified in `/usr/share/tcltk/tk8.6/ttk/treeview.tcl:263`, `-selectmode` dispatches only from the *class bindings* — `$tv selection set {a b}` is unaffected. Without BW11, BW10 is green on a broken `selection set`.

**Green.** The skeleton exists; the tree is empty and populated exactly as before (item 10 changes the content).

**Existing checks it reds.**

| id | file:line | old | new |
|---|---|---|---|
| BN04 | model file | `.bnfake.wvbrowser.tvf.tv` | `….pw.tvf.tv` |
| BS22 | sigbrowser:308 | `{ph wvsearch tb tvf wvfilter loc}` | `{ph wvsearch tb opt pw wvfilter loc}` |
| BT21 | :1089 | `{Treeview extended 1}` | `{Treeview browse 1 1}` |
| BT21 | :1109 | `{loc wvsearch tb ph wvfilter tvf}` | `{loc wvsearch tb ph wvfilter opt pw}` |
| BT21 | :1112 | 6 sides + expand | 7 sides `{top top top bottom bottom top top}` |
| BT22 | :1123 | `pack propagate $BTF` 0 | unchanged; **re-run** |
| BR20 | i1315:513 | child set | as BS22 |
| BR21 | i1315:516 | six-slave list | seven-slave list |
| BR23 | i1315:533 | Location row | unchanged; **re-run** |
| BH40/BH41 | i11:413,609 | `$BHTV` path | `.pw.tvf.tv` |
| — | i12:595, sigbrowser:311 | path | `.pw.tvf.tv` |

**Sabotages.**
- Leave `column #0 -stretch 1` → **BW02 and BW03 red, BW12 red, BW13 green**. That exact three-red/one-green signature is M4's measured claim, confirmed by running it.
- Build `$f.pw` as a child of the toplevel instead of `$f` → **BW08/BW09 stay GREEN** (they are source greps) while BW14 and every X-arm width check red. Run this one: it is the proof that the four grep-pinned `browser_width` literals do **not** prove the width rule still applies.
- Add a vertical scrollbar to the sea → **BW04 red**.
- Wire the checkbuttons now → **BW06 red**, and item 12 loses its own attribution.

**Done when** the eight `--nogui` files are green after the literal edits, and the `BW` file's X arm passes under **one** `Allow 2h` window via `tests/headless/run_suites.sh`.

#### Corrections — measured while building item 9, not argued

1. ⚠⚠ **BW10 above is RED ON A CORRECT WIDGET, and it contradicts this plan's own trap row 9.** `$tv selection set {a b}` under `-selectmode browse` really does select **two**: `-selectmode` is read in exactly one place, `ttk::treeview::SelectOp` (`/usr/share/tcltk/tk8.6/ttk/treeview.tcl:262-275`), which only the **class bindings** call. As built, the pair is a REAL GESTURE — `<Button-1>` then `<Shift-Button-1>`, which dispatches `select.extend.<mode>`: `BrowseTo` (1) under `browse`, `selection set [between …]` (2) under `extended`. **BW26 + BW27**, same widget, same rows, same events. **BW26b** keeps the measured fact itself assertable, because it is the live hazard trap 9 names: a shipped two-id `sel` restores straight through `selection set`, so R4 is false from the first restore until item 13/14 narrows it.
2. ⚠⚠ **BW12/BW13 above are wrong: DEPTH IS NOT THE DISCRIMINATOR.** `ttk::treeview` does **not** auto-grow column `#0` for deep or long items. Measured on Tk 8.6.14, a six-level tree of 32-char names in a 570 px pane reports `xview {0.0 1.0}` under **both** stretch settings. What differs: `-stretch 0` leaves `#0` at 200 while `-stretch 1` grows it to 568, and `#0` wider than the pane gives `{0.0 0.79}`. As built: **BW28** (the column does not track the pane), **BW29** (its control — the same widget as `-stretch 1` **does** track it and has nothing to scroll, the exact state M4 forbids), **BW30** (the `-xscrollcommand` wiring reaches the scrollbar: widen `#0` past the pane and the scrollbar's own `get` moves off `{0 1}`).
3. **The red-list above is short by four.** `bind $f.tvf.tv` is also a SOURCE grep in **BT04 (×2), BM01 and BH08**; all four red on the path move.
4. **BT31 and BM21 red for a reason that is not the gate.** They spelled blank tree space as `[winfo height $tv] - 3`, which was blank only while the tree was as tall as the sidebar. MEASURED after the split: sidebar 500 → panedwindow 286 → tree **144 px** against ~220 px of rows, so that y lands ON A ROW. `bs_blank_y` (new, in `wvbs_common.tcl`) finds a provably blank y and answers a negative code rather than 0; both sites now assert the precondition.
5. **`pcall` returns the STRING `ERR:<msg>`, so `expr {[pcall winfo width $w] > 1}` THROWS.** Under sabotage 2 that aborted the BW file at check 17 of 34 — and BW31/BW32, the two checks written to catch that very sabotage, never ran. `bs_num`/`bs_set` and a non-throwing `bs_wait_mapped` fix it. **Any later item writing an X-arm check must use them**, or the same sabotage will pass silently again.

---

### Item 10 — Upper pane live: node rows, root, collapsed by default

**Scope.**
- `browser_refresh` (`:6739`): the pipeline becomes
  `names → browser_and → signal_entry → browser_class_filter (hardcoded 0/1 here; item 12 wires the boxes) → browser_rows $ents [browser_root_label $rawpath] $anypath_pre → browserrows($token) → browser_tree_rows → the widget`.
  `browserrows($token)` keeps **the full row list, leaves included** — `browser_leaf_names`, `browser_plot_ids`, `browser_menu_ids`, `browser_target_path`, `browser_descend_to` all read it and are **not edited** (R6).
  `$anypath_pre` is computed on the entries **before** `browser_class_filter` (M6).
- `browser_populate` (`:6807`): two changes only — skip rows whose `kind` is not `group`, and insert `-open 0` except the root (`g:`), which is `-open 1` (§0.3). Then: if the previously selected id still exists, re-select it; otherwise select `[browser_root_id $rows]` (R2/R4). Never leave the selection empty.
- New `bind $f.pw.tvf.tv <<TreeviewSelect>>` → `wviewer::browser_sea_refresh $token`, a **no-op stub** in this item so the guide row and GH8/GH9 move once, not twice.
- `browser_show_path`'s root branch (`:7760` region) selects the root instead of `selection set {}`.
- Guide: one new `data-bseq="pw.tvf.tv &lt;&lt;TreeviewSelect&gt;&gt;"` row; **GH8/GH9 `6` → `7`** in this item's commit.

**RED first.** Bump GH8's literal (`test_wave_grid.tcl:473`) and GH9's (`:485`) to 7 first — red until both the guide row and the bind exist.

```tcl
# BW20-BW34 in test_wave_sigbrowser_panes.tcl
check {BW20 the tree's top level is exactly ONE node, id g:, and it is SELECTED} \
  [list [$TV children {}] [$TV selection]] {{g:} {g:}}
check {BW21 the ROOT is open; EVERY other node is closed (the set, not a count)} \
  [list [$TV item {g:} -open] [bs_open_set $TV]] {1 {g:}}
check {BW22 the tree holds ZERO leaf rows...} [bw_kinds_in_tree $tok] {group}
check {BW23 ...and `$tv exists` on a leaf id is 0 — an ASSERTABLE ABSENCE} \
  [pcall $TV exists {s:v(x1.x2.net5)}] 0
check {BW24 (THE R6 CONTROL, MUST STAY GREEN) browserrows still holds the leaves,
       so browser_leaf_names still answers RECURSIVELY} \
  [llength [::wviewer::browser_leaf_names $::wviewer::browserrows($tok) {g:x1}]] 406
check {BW25 (R5's DEFECT, AS A VALUE) typing in the Search bar leaves the OPEN SET
       byte-identical while the pane count changes} \
  [begin {set a [bs_open_set $TV]; bs_type $F.wvsearch v*; set b [bs_open_set $TV]
          list [expr {$a eq $b}] [expr {$n0 ne $n1}]}] {1 1}
check {BW26 ...and the Filter bar likewise} ...
check {BW27 a refresh preserves an existing valid selection} \
  [begin {$TV selection set {g:x1}; ::wviewer::browser_refresh $tok; $TV selection}] {g:x1}
check {BW28 ...and falls back to the root when the selection is gone} \
  [begin {$TV selection set {g:x1}; bs_type $F.wvsearch zzzz
          ::wviewer::browser_refresh $tok; $TV selection}] {g:}
check {BW29 (R4) the selection is NEVER empty, in three ways} \
  [list [llength [$TV selection]] \
        [begin {$TV selection set {}; update; llength [$TV selection]}] \
        [begin {::wviewer::browser_refresh $tok; llength [$TV selection]}]] {1 1 1}
check {BW30 browser_show_path at the sim root SELECTS the root, never clears} \
  [list [pcall ::wviewer::browser_show_path $tok {}] [$TV selection]] {{root g: {}} {g:}}
check {BW31 (M6 BEHAVIOURAL) a design whose hierarchy exists only under device signals
       does NOT collapse to a flat tree — the tree still has depth >= 2} \
  [bw_depth $TV] 2
check {BW32 (SOURCE) browser_refresh computes anypath BEFORE the class filter} \
  [bw_index_order $bw_ref {anypath} {browser_class_filter}] 1
check {BW33 (SOURCE) browser_refresh assigns browserrows exactly ONCE, from the
       UNPROJECTED rows} [regexp -all {set browserrows\(\$token\)} $bw_ref] 1
check {BW34 a reveal onto a FOREIGN (d:0|) node decodes correctly (item 8's fix, live)} \
  [pcall ::wviewer::browser_show_path $tok {x1.x2}] {ok d:0|g:x1.x2 x1.x2}
```

**Green.** As above; the eight files green with GH8/GH9 at 7.

**Existing checks it reds.**

| id | file:line | old | new |
|---|---|---|---|
| GH8/GH9 | grid:473, :485 | 6 | **7** |
| BT20 | sigbrowser:1078 | `no-tree` / `empty` | value unchanged, path only |
| BT24 | :1156 | 11-row interleaved `$BTALL` | `{g:\|<design>} {g:x1\|x1} {g:x1.x2\|x2} {g:x1.y3\|y3}` |
| BT24 | :1168 | `{g:x1.x2 g:x1 {g:x1.x2 g:x1.y3}}` | `[list g:x1 {g:} {g:x1.x2 g:x1.y3} 0]` via `pcall … exists` |
| BT25/BT26/BT27 | :1176-1230 | tree-only discriminator | **compound triple** (below) |
| BT29 | :1252 | leaf double-click | **retarget to the sea cell**, expected value byte-identical |
| BT30 | :1285 | 2-leaf tree selection | **retarget to a 2-cell sea selection**, value unchanged |
| BT32 | :1320 | group + its own leaf, deduped | **DELETE** — unexpressible under R4; BM11 (`:1723`) is the surviving pure oracle for the dedup, note it in the deleted check's place |
| BT33 | :1335 | `[$TV children {}]` == 20 | `[list 1 [llength [$TV children {}]] [llength [$TV children {g:}]]]` == `{1 1 20}` |
| BT42 | :1414 | leaf parent | `pcall … exists` == 0 |
| BM40 | :2254 | 6 rows incl. leaves | `{g:\|<basename>} {g:x1\|x1} {g:x1.x2\|x2}` |
| BX30 | i12:396 | `visible` | **`collapsed`** + a two-state control (below) |
| BP54 | i1315:1297 | `$BPT parent {s:v(x1.x2.n1)}` | `pcall … exists` == 0; see item 13 |

**THE DISCRIMINATOR REBUILD (BT25/BT26/BT27) — do not relax it.** With leaves out of the tree, ALL / SEARCH / FILTER / AND all give the *same* four-row tree, so `BT26 …and the three trees are genuinely three different values` (`:1207`) becomes vacuously false. Replace the single tree oracle with the compound triple `{<tree> <sea at g:> <sea at g:x1.x2>}` read by the new `bs_sea_labels` helper. It **is** four distinct values on the shipped fixture *only because R8's labels distinguish* `v(x1.x2.net5)`→`net5` from `i(x1.x2.net5)`→`net5:i`:

| state | tree | sea @ `g:` | sea @ `g:x1.x2` |
|---|---|---|---|
| ALL | 4 nodes | `{out out2 v1:i net1 vsweep}` | `{net5 net5:i}` |
| SEARCH `v(*)` | 4 nodes | `{out out2}` | `{net5}` |
| FILTER `*net5*` | 4 nodes | `{}` | `{net5 net5:i}` |
| AND | 4 nodes | `{}` | `{net5}` |

The `*N of 8 signals*` legs (`:1182`, `:1199`) are untouched and stay the cheap discriminator.

**BX30's replacement control (i12:396):**
```tcl
check {BX30 (POSITIVE CONTROL) bx_vis distinguishes the two states on this very tree} \
  [list [bx_vis $BXTV g:x1.x2] \
        [begin {$BXTV item {g:} -open 1; $BXTV item g:x1 -open 1; bx_vis $BXTV g:x1.x2}]] \
  {collapsed visible}
```

**Sabotages.**
- Put `browser_tree_rows`' output into `browserrows` as well → **BW24 red** (nothing to plot). The single most likely wrong edit in the batch.
- Insert every node `-open 1` → **BW21 red**, everything else green.
- Recompute `anypath` after the class filter → **BW31 and BW32 red**, BW22 green; item 2's BN12 is the pure twin.
- Call `$tv see` from `browser_populate` → **BW25 red** — today's defect, re-introduced.

**Done when** all eight `--nogui` files green and the `BW` X arm green.

---

### Item 11 — Lower pane live

**Scope.**
- `wviewer::browser_sea_refresh {token}` (the item-10 stub, filled): read the one selected node → `browser_target_path`-style decode to a dotted path (`g:` → `{}`) → `browser_level_names` over the **class-filtered, bar-matched** entry snapshot → `browser_label` each → `browser_flow_*` onto `$f.pw.sea.c`. Each canvas text item is tagged `cell` and `n<index>`; a parallel `browsersea($token)` list holds `{label fullname}` pairs. **The full raw name is the tag payload; the label is never an identity.**
- Status line (spec §7.2), three distinguishable states:
  `x1.x2 has no signals of its own` / `0 of 43 signals (the Search/Filter bar is hiding them)` / `0 of 43 signals (device internals are hidden)` / `<n> of <own> signals`. Composed **only** by `browser_say`/`browser_msg` — never inline.
- Seven binds on `$f.pw.sea.c`: `<Button-1>` (select one), `<Shift-Button-1>` (extend in **flow order**), `<Control-Button-1>` (toggle), `<Double-Button-1>` (plot), `<Button-2>` (plot), `<Button-3>` (post the browser menu scoped to the sea's selection), `<Configure>` (reflow). All plot routes converge on the existing `wviewer::plot_signals` / `browser_plot_ids`; the RMB route uses a **distinct** context-menu name (`wvseamenu`) registered with `ctx_menu_drop`, so the tree menu's reserved index 7 (BM02, BH40) is untouched.
- Tooltip on hover shows `browser_label_full`.
- `browser_refresh` calls `browser_sea_refresh` last, so a bar keystroke refreshes the sea. **There is no `see` on this path** — that is the whole of R5's fix.
- Guide: **seven** new `data-bseq="pw.sea.c …"` rows; **GH8/GH9 `7` → `14`**.

**RED first.** Bump GH8/GH9 to 14 first.
```tcl
# BQ50-BQ64 in test_wave_sigbrowser_sea.tcl (X arm)
check {BQ50 (PURE) the composition level_names -> label gives the exact ordered list} \
  [bq_compose $bn_fix x1] $bq_expected_labels
check {BQ51 selecting the ROOT shows 18 items; selecting g:x1 shows 43; and the
       two sets are DISJOINT (a recursive pane would read 424 at the root)} \
  [list $bq_n_root $bq_n_x1 [bq_disjoint]] {18 43 1}
check {BQ52 a PURE ANCESTOR renders EMPTY and the status line SAYS SO — and the
       pane was NON-empty one selection earlier} \
  [list $bq_prev_n [bs_sea_labels $C] [string match {*has no signals of its own*} $st]] \
  {43 empty 1}
check {BQ53 (R5's HEADLINE) with g:x1 collapsed, a Search keystroke leaves the
       open set UNCHANGED while the sea's contents change; and an EXPLICIT
       browser_show_path DOES open it} [bq_r5_triple] {1 1 1}
check {BQ54 the canvas scrolls HORIZONTALLY and only horizontally} \
  [list [expr {[lindex [$C cget -scrollregion] 2] > [winfo width $C]}] \
        [expr {[lindex [$C cget -scrollregion] 3] == [winfo height $C]}] \
        [expr {[$hsb get] ne {0 1}}]] {1 1 1}
check {BQ55 (BQ54's CONTROL) with 5 names there is nothing to scroll} \
  [$hsb get] {0 1}
check {BQ56 the item at flow index k shows the LABEL while its tag is the FULL RAW NAME} \
  [list [$C itemcget [bq_item 4] -text] [bq_name_at 4]] {net5:i i(x1.x2.net5)}
check {BQ57 Shift-click from column 0 to column 2 selects the ARITHMETIC range} \
  [llength [::wviewer::browser_sea_selection $tok]] 41
check {BQ58 double-click plots exactly that ONE signal (the traces, not the return)} \
  $bq_plotted {{wvbt {net1}}}
check {BQ59 (R6 REGRESSION GUARD, BEHAVIOURAL) MMB on the TREE's g:x1 still plots
       every signal under x1, descendants included} [llength $bq_tree_plotted] 406
check {BQ60 copy yields FULL RAW NAMES, not labels} [bq_clip] $bq_raws
check {BQ61 the sea's RMB menu is a DISTINCT widget from the tree's} \
  [expr {[bq_seamenu] ne [bq_treemenu]}] 1
check {BQ62 ...and both are destroyed when the window closes} [bq_menus_gone] {0 0}
check {BQ63 the sea's item ids do NOT alias the tree's s:/g: namespace} \
  [regexp {^[sg]:} [lindex [$C gettags [bq_item 0]] 0]] 0
check {BQ64 rowHeight came from font metrics at RUNTIME} \
  [list [regexp {font metrics AseEntryFont -linespace} $bq_flowbody] \
        [regexp {rowh +[0-9]+} $bq_flowbody]] {1 0}
```

**Green.** As above; `bs_sea_labels` (in `wvbs_common.tcl`) answers `no-pane` / `empty` / the ordered label list — **three distinct shapes**, because 12 of `tb_bandgap`'s 44 kept nodes render legitimately empty.

**Existing checks it reds.** GH8/GH9 → 14.

**Sabotages.**
- Call `$tv see` from `browser_sea_refresh` → **BQ53 red** (today's defect, re-introduced).
- Feed the sea `browser_leaf_names` instead of `browser_level_names` → **BQ51 reads `{18 406 0}`**; note BQ51's *root* leg stays right, which is why the check names a descended node.
- Put the label in the canvas tag → **BQ56 and BQ58 red** (`plot_signals` gets `net5:i`, which no raw contains).
- Reuse `wvbrowsermenu` for the sea → **BQ61/BQ62 red**, and the two panes' selections alias.

**Done when** all eight `--nogui` green with GH8/GH9 at 14, `BQ` X arm green.

---

### Item 12 — The checkboxes stop being inert

**Scope.** Two accessors modelled verbatim on `browser_alldbs` (`:6688`) — **one read site each**, so a scoping sabotage has exactly one place to land:
```tcl
proc wviewer::browser_devint {token {want {}}}   ;# R11(a), default 0
proc wviewer::browser_srccur {token {want {}}}   ;# R11(b), default 1
```
`-command [list wviewer::browser_refresh $token]` on both. `browser_refresh` replaces item 10's hardcoded `0 1` with the two accessors. **The widgets already exist and are already packed (item 9), so no pinned child-set check moves here** — that is why they were built inert.

**RED first** — `BW40`-`BW49`:
```tcl
check {BW40 the defaults read back through the accessors, and they DIFFER} \
  [list [::wviewer::browser_devint $tok] [::wviewer::browser_srccur $tok]] {0 1}
check {BW41 an unknown token answers R11's defaults, not {} and not a throw} \
  [list [pcall ::wviewer::browser_devint nosuch] [pcall ::wviewer::browser_srccur nosuch]] {0 1}
check {BW42 (THE MEASURED ARITHMETIC, END TO END) defaults -> 190 signals, 44 nodes} \
  [list [bw_status_n $tok] [bw_nodecount $TV]] {190 44}
check {BW43 tick device internals -> 424 signals, 128 nodes} \
  [begin {::wviewer::browser_devint $tok 1}; list [bw_status_n $tok] [bw_nodecount $TV]] \
  {424 128}
check {BW44 untick source currents from the default -> 140} \
  [begin {::wviewer::browser_devint $tok 0; ::wviewer::browser_srccur $tok 0}
   bw_status_n $tok] 140
check {BW45 the four combinations are FOUR DIFFERENT totals} [bw_four] {424 190 374 140}
check {BW46 (SOURCE) each checkbox variable is read from exactly ONE place} \
  [list [bw_reads browserdev] 1] {1 1}
check {BW47 toggling a box does NOT re-enter the engine (signal_list is not called)} \
  [begin {bw_spy_reset; ::wviewer::browser_devint $tok 1}; bw_spy_count] 0
check {BW48 (R5's DISCIPLINE, applied to the boxes) toggling changes neither the
       open set nor the selected node} [bw_scope_stable] {1 1}
check {BW49 the boxes are NOT menu entries and carry NO accelerator (GH0/GH4)} \
  [list [$F.opt.dev cget -text] [catch {$F.opt.dev cget -accelerator}]] \
  {{Show device internals} 1}
```

**Green.** The accessors exist and are each read once; the measured arithmetic reproduces through the widget.

**Existing checks it reds.** None. GH0's `11` accelerators and GH4's count do not move (a checkbutton uses `-command`, not `bind $f.`, and gets no accelerator).

**Sabotages.**
- Share one variable between the two checkbuttons → **BW40 reads `{0 0}` or `{1 1}`, BW45's four totals collapse to two.**
- Read the checkbox in `browser_refresh` **and** in `browser_sea_refresh` → **BW46 red**, and BW43 goes *half* right (signals rescope, nodes do not). Run it — the half-right state is what ships if nobody checks.
- Seed the variables in the namespace rather than per token → **BW41 red**; a second viewer inherits the first's boxes.
- Let the class filter reach `browser_rows_multi`'s `anypath` → **BW31 (item 10) and BN12 (item 2) red together.**

**Done when** BW40-BW49 green.

---

### Item 13 — `browser_reveal` / `browser_tree_apply` under collapsed-by-default

**Scope.** `browser_reveal` (`:7650`) and `browser_tree_apply` (`:8137`). Spec §4.2: `see` may only be reached from a **user-initiated** reveal; `browser_populate` never calls it.

- `browser_reveal` walks the target's **ancestor chain** and opens exactly those, does **not** open the target itself (R3 makes the lower pane the answer to "what is inside"), then calls `see` for scrolling. `$tv see` stays — deleting it breaks scrolling, and item 10 already stopped `populate` from reaching it.
- `browser_tree_apply` (`:8137`): keep the shipped selection-first / open-set-last order. **New:** union the *selection's ancestor chain* into the applied open set, or R4's "always exactly one node selected" is satisfiable with the selection collapsed out of view. §7.3's narrowing (`sel` is a list; take the first surviving id, else the root) lands here.

**RED first** — `BW50`-`BW58`:
```tcl
check {BW50 reveal from a fully collapsed tree: two ancestors OPEN, the TARGET
       CLOSED, and it is visible — three values, one check} \
  [begin {::wviewer::browser_reveal $tok {g:x1.x2}}
   list [$TV item {g:x1} -open] [$TV item {g:x1.x2} -open] [bx_vis $TV g:x1.x2]] \
  {1 0 visible}
check {BW51 (CONTROL) a SIBLING of an ancestor stays collapsed — a chain, not a subtree} \
  [$TV item {g:y3} -open] 0
check {BW52 R1: MORE THAN ONE subtree may be expanded at once} \
  [begin {$TV item g:x1 -open 1; $TV item g:y3 -open 1; bs_open_set $TV}] {g: g:x1 g:y3}
check {BW53 a persisted COLLAPSE beats `see` (BP54's claim, on node ids)} \
  [begin {::wviewer::browser_tree_apply $tok {open {g: g:y3} sel {g:y3}}}
   list [$TV item g:x1 -open] [$TV item g:y3 -open]] {0 1}
check {BW54 a restored SELECTION is never collapsed out of view} \
  [begin {::wviewer::browser_tree_apply $tok {open {g:} sel {g:x1.x2}}}
   list [bs_open_set $TV] [bx_vis $TV g:x1.x2]] {{g: g:x1} visible}
check {BW55 (BW54's CONTROL) the union is the SELECTION's chain, not `open everything`} \
  [begin {::wviewer::browser_tree_apply $tok {open {g: g:y3} sel {g:y3}}}
   $TV item g:x1 -open] 0
check {BW56 a SHIPPED-shape multi-id sel narrows to its first surviving id (§7.3)} \
  [begin {::wviewer::browser_tree_apply $tok {open {g:} sel {g:zz g:x1.x2}}}
   $TV selection] {g:x1.x2}
check {BW57 ...and an all-dead sel falls back to the root, never to empty} \
  [begin {::wviewer::browser_tree_apply $tok {open {g:} sel {g:zz}}}
   $TV selection] {g:}
check {BW58 browser_reveal on {} answers 0 and leaves the selection alone
       (`$tv exists {}` is TRUE — the trap the proc's own comment records)} \
  [list [pcall ::wviewer::browser_reveal $tok {}] [$TV selection]] {0 {g:x1.x2}}
```

**Green.** As above.

**Existing checks it reds.**

| id | file:line | old | new |
|---|---|---|---|
| BX31 | i12:412 | `{visible 1}` | `[list visible 1 1]` — add a `[$BXTV item {g:} -open]` leg; **rename** to `…: see re-opened the COLLAPSED-BY-DEFAULT ancestor` |
| BX42 | i12:666, :671 | control legs | value unchanged, **re-run** — verified at `i12:627` it calls `ase::show_in_browser_for_current` **directly**, so R10's chord move cannot touch it |
| BP41 | i1315:1145 | fresh window == default | unchanged claim, **re-run** after item 14 |
| BP53 | i1315:1289 | `{0 1}` | keep `{0 1}`, **add an explicit pre-snapshot `$BPT item g:y3 -open 1` and a PRE control**: without it a collapse that persisted nothing reads identically |
| BP54 | i1315:1297 | `{0 g:x1.x2}` on a leaf | `[list [pcall $BPT item g:x1 -open] [pcall $BPT parent {g:x1.x2}] [pcall $BPT exists {s:v(x1.x2.n1)}]]` == `{0 g:x1 0}`; **keep the fixture's selection OUTSIDE `g:x1`** (select `g:y3`) so BP54 keeps testing the collapse and BW54 owns the union |

**Sabotages.**
- Open the target too → **BW50 red**.
- Open every descendant (a subtree `see`) → **BW51 red**.
- Drop the ancestor union → **BW54 red, BW55 green, BP54 green** — three files' verdicts triangulate the change to one proc.
- Delete `$tv see` "to honour collapsed-by-default" → **BX31 red**.

**Done when** BW50-BW58 green and BX31/BX42/BP41/BP53/BP54 restated-and-green.

---

### Item 14 — Persistence: `sash` / `devint` / `srccur`

**Scope.**
- `browser_state_default` (`:8053`) gains **three keys, appended in exactly this order** (spec §9): `sash 0`, `devint 0`, `srccur 1`. **Append, never insert** — `browser_state_is_default` (`:8074`) is a whole-dict **string** compare.
- `browser_state` (`:8169`) writes them through the item-12 accessors and a new `browser_sash {token {want {}}}`. **`sash` reads `0` unless the sash was dragged** — `browsersash($token)` is written only by the panedwindow's `<ButtonRelease-1>`. A live `sashpos/height` read can never equal a constant default, and the gate would then be permanently false.
- `browser_state_apply` (`:8210`): `devint`/`srccur` restore **before** `browser_show` (so the first populate already respects them); `sash` **after**, on the same idle-flushed branch `width` uses.
- Two new arrays declared and unset in the teardown block.
- Persisting must **not** log: write the checkbox variables directly, as `browser_state_apply` already does for `dest`/`browser` (`:8199-8206`, declared as D-F). R12's auto-tick is the opposite case and **does** log (§7.4).

**RED first.** Edit BP10/BP13/BP45 first — all three red immediately.
```tcl
# BP10 i1315:781
check {BP10 browser_state_default's key list is the snapshot shape} [dict keys $bp_def] \
  {shown width search filter dest open sel hist sash devint srccur}
# BP13 i1315:809 — grow 7 legs to 10
[dict replace $bp_def sash 0.6]  -> 0
[dict replace $bp_def devint 1]  -> 0
[dict replace $bp_def srccur 0]  -> 0        ;# NON-default is 0, not 1
# BP45 i1315:1224 — 8 sentinel reads become 11; `sel` becomes {g:x1.x2}
```
New `BP60`-`BP68`:
```tcl
check {BP60 (PURE) is_default is 1 on the canonical default INCLUDING the three new keys} \
  [::wviewer::browser_state_is_default [::wviewer::browser_state_default]] 1
check {BP61 (PURE) the two checkbox defaults are R11's ASYMMETRIC pair} \
  [list [dict get $bp_def devint] [dict get $bp_def srccur]] {0 1}
check {BP62 (SOURCE) browser_state never writes a raw pixel sash} \
  [list [regexp {browser_sash} $bp_state] [regexp {sashpos 0\]} $bp_state]] {1 0}
check {BP63 (SOURCE) apply restores the boxes BEFORE browser_show and the sash AFTER} \
  [bp_order $bp_apply {devint} {browser_show} {browser_sash}] 1
check {BP64 (X) a FRESH window's sash reads 0 (never dragged), not a live fraction} \
  [dict get [::wviewer::browser_state $tok] sash] 0
check {BP65 (BP64's CONTROL) after a drag it reads the fraction} \
  [begin {::wviewer::browser_sash $tok 0.62}; dict get [::wviewer::browser_state $tok] sash] 0.62
check {BP66 (X) ROUND TRIP on NON-DEFAULT values for all three} \
  [bp_roundtrip {devint 1 srccur 0 sash 0.35}] {1 0 0.35}
check {BP67 (X) restore into a SHORTER window reproduces the FRACTION, not the pixel} \
  [list [expr {abs([bs_sash_frac $PW]-0.62) < 0.03}] [expr {$px_after != $px_before}]] {1 1}
check {BP68 (X, THE CROSS-FILE GUARD, LOCAL) a viewer with the browser hidden emits
       no `browser` key} [lsearch -exact [dict keys [::wviewer::snapshot $tok {}]] browser] -1
check {BP69 (BP68's CONTROL) ...and ticking one box makes it appear, LAST} \
  [begin {::wviewer::browser_devint $tok 1}; lindex [dict keys [::wviewer::snapshot $tok {}]] end] browser
check {BP70 restoring does NOT fill the replay log} [bp_log_delta] 0
```
Add **MG10** to `tests/headless/test_wave_modes.tcl` (it already owns the snapshot-shape claim) mirroring BP68/BP69.

**Green.** The three keys exist, appended, with `sash` read as its default when never dragged.

**Existing checks it reds.** BP10, BP13, BP45. **BP41 (`i1315:1145`), BP42 (`:1153`), BP44 (`:1211`), BP02 (`:674`), BP04 (`:698`) and MG9 (`test_wave_modes.tcl:1314`) must all stay GREEN** — they are the controls. **BP04's `sbcase(|sbcfg(|sballdb(|dest(` zero-hit leg is an *unanchored substring*: the new arrays MUST be named `browsersash(` and `browserdev(`/`browsersrc(`, never `browserdest(`.**

**Sabotages.**
- Read the sash live in `browser_state` → **BP62, BP64 red, BP41 red, MG9 red** — four oracles across three files, one defect.
- Persist the sash in pixels → **BP67's second leg red**, BP66 green.
- Default `srccur` to 0 → **BP61 red here, MG10 red in `test_wave_modes.tcl`.**
- Insert the new keys mid-dict → **BP10 red with a confusing diff**; the append rule exists to make this loud.
- Write `devint` through the checkbutton's `-command` on restore → **BP70 red.**

**Done when** BP10/BP13/BP45 restated-and-green, BP60-BP70 green, and `test_wave_modes.tcl` green at 214.

---

### Item 15 — R7: All-DBs headers + a design root per DB

**Scope.** `browser_refresh`'s All-DBs arm. **`browser_rows_multi`'s helper contract is NOT changed** — the `$glab eq {}` flat arm stays exactly as it is, which is what keeps BD19 (`i14:366`), BD21 (`:381`), BD22 (`:385`), BD25 (`:415`) green. What changes is what the **caller passes**: with the box on, group 0 gets a **label** (the current DB's `db_label`), so it too gets a header and a `d:0|` prefix.

Consequences, all handled by procs that already exist:
- `browser_rows_reparent` (`:6136`) already re-keys `g:` → `d:0|g:` and re-parents children. No edit.
- `browser_node_for`'s walk starts at `[browser_root_id $rows]` (item 8), which answers `d:0|g:` here. No edit to the walk.
- `browser_target_path` / `browser_show_path` decode the `d:N|` prefix (item 8). No further edit.
- BD21's "the header row's kind is `group`, not a new kind" **survives** — the design-root row is `kind group` too, so `browser_leaf_names`, `browser_plot_at`'s `!$groups` guard and `browser_menu_ids` need no vocabulary change.

**RED first** — `BD60`-`BD70` in `test_wave_sigbrowser_i14.tcl`:
```tcl
check {BD60 (PURE, THE HELPER IDENTITY — MUST STAY GREEN) one unlabelled group
       == browser_rows, byte-identical}  ...unchanged, re-run...
check {BD61 (PURE) a ROOTED multi list: root FIRST, unprefixed, kind group} \
  [list [dict get [lindex $bd_rooted 0] id] [dict get [lindex $bd_rooted 0] kind] \
        [dict get [lindex $bd_rooted 1] parent]] {g: group g:}
check {BD62 (PURE) each FOREIGN DB gets its OWN prefixed root under its header} \
  [list [bd_id_of $bd_rooted {d:0|g:}] [bd_parent_of $bd_rooted {d:0|g:}]] {d:0|g: d:0}
check {BD63 (PURE) browser_leaf_names on a DB HEADER still reaches THROUGH its root} \
  [::wviewer::browser_leaf_names $bd_rooted {d:0}] {time v(alpha) v(shared)}
check {BD64 (PURE) every id in a rooted multi list is UNIQUE (a shared g: THROWS in ttk)} \
  [expr {[llength [lsort -unique $bd_ids]] == [llength $bd_ids]}] 1
check {BD65 (PURE) a group with zero entries emits NO header and NO root} \
  [bd_has $bd_rooted {d:1}] 0
check {BD66 (PURE) browser_node_for started at the CURRENT DB's root still lands
       on the current DB's node} \
  [::wviewer::browser_node_for $bd_rooted {x1} [::wviewer::browser_root_id $bd_rooted]] \
  {d:0|g:x1 1}
check {BD67 (X, THE CALLER — the check the break-lists were all missing) after a
       LIVE refresh with the box ON, browserrows' FIRST row is a group whose text
       is the current DB's label} \
  [list [dict get [lindex $::wviewer::browserrows($tok) 0] kind] \
        [dict get [lindex $::wviewer::browserrows($tok) 0] text]] \
  [list group [::wviewer::db_label $cur]]
check {BD68 (X) with the box ON the tree's TOP level is the DB headers} \
  [$TV children {}] {d:0 d:1}
check {BD69 (BD68's CONTROL) with it OFF it is the single design root} [$TV children {}] {g:}
check {BD70 (X) on open with the box ON, the CURRENT DB's design root is selected} \
  [$TV selection] {d:0|g:}
```
**BD67 is the item's whole point:** BD19/BD22/BD25 pin `browser_rows_multi` **called directly** with a hand-built `{}`-labelled group. R7 changes the **caller**, so all three would stay green on a code path production no longer takes (silent-green trap §3.2).

**Green.** As above.

**Existing checks it reds.**

| id | file:line | old | new |
|---|---|---|---|
| BD50 | i14:643 | `bd_parent_text … {d:0\|s:v(shared)}` == `{bd_a.raw (tran)}` | parent is now `d:0\|g:` whose text is `bd_a`; add a `bd_grandparent_text` leg for `{bd_a.raw (tran)}` |
| BD51 | i14:665 | `$BVF.tvf.tv exists {d:0}` | path → `.pw.tvf.tv`; value `{0 {s:v(beta)}}` stands |

**Sabotages.**
- Emit foreign nodes without the `d:N|` prefix → **BD62 and BD64 red**, and the live populate throws `Item g: already exists`, which `browser_refresh`'s catch turns into a status-line message → **BD68 red**. Three reds from one defect.
- Skip the per-DB root → **BD62 red**, BD68 green.
- Root `browser_rows_multi` unconditionally instead of via the caller → **BD60 and BD22 red** while BD61 goes green; that inversion says the arg was made mandatory.

**Done when** BD60-BD70 green and BD19/BD21/BD22/BD25 untouched-and-green.

---

### Item 16 — R9: Ctrl-L → Ctrl-B

**Scope.** Four surfaces, one commit.

1. `src/wave_viewer.tcl:9372-9373` — `<Control-Key-l>` → `<Control-Key-b>` in both the guard and the bind; the rejection paragraph at `:9364` is **rewritten to record the override**, not deleted.
2. `key_filter`'s graphkeys arm, `:11214`:
   `set fwd [expr {!($N == 100 && ($s & 4))}]` → `set fwd [expr {!(($N == 100 || $N == 98) && ($s & 4))}]`
   Bare `b` (`$s & 4 == 0`) still forwards. **`graphkeys` (`:320`) keeps 98** — the fix is a modifier carve-out, not a membership deletion.
3. `build_menubar` accelerator `Ctrl+L` → `Ctrl+B`.
4. `src/callback.c:4988` `set_input_binding(DEV_KEY, 'b', ControlMask, ACTX_OVER_GRAPH, "graph.forward");` is **DELETED**, and `src/keybindings.csv` is **REGENERATED** by `save_input_bindings_file` — never hand-edited (`test_bindings_file.tcl:28-31` byte-compares).
5. `doc/waveform_viewer_guide.html:483-490` — `data-seq="Control-Key-l"` → `Control-Key-b`, `<kbd>Ctrl-L</kbd>` → `Ctrl-B`, `data-accel="Ctrl+L"` → `Ctrl+B`. **A pure rename: GH0's 16/11, BT09 and BX13 do not move.**

**RED first.** Edit BS03 (2 legs, `:132-135`), BS04 (`:137`), BS05 (`:143`), BS09 (2 legs, `:200-203`), BS42 (`:531`), BS45 (5 legs, `:560-570`), **and retarget BS46's two `send_key` calls (`:581-590`)** — ⚠ **BS46 does not go red today, it goes SILENT**: `send_key` on an unbound chord burns its budget and prints `SKIPPED: BS46 real-key leg`. That printed line is its red state; watch for it.

New file `tests/headless/test_wave_sigbrowser_keys.tcl`, band `BK`:
```tcl
check {BK01 (SOURCE) the carve-out names BOTH keysyms in ONE expression} \
  [regexp {set fwd \[expr \{!\(\(\$N == 100 \|\| \$N == 98\) && \(\$s & 4\)\)\}\]} $wsrc] 1
check {BK02 (SOURCE, POSITIVE CONTROL) graphkeys STILL contains 98 — the fix is a
       modifier carve-out, not a membership deletion} \
  [lsearch -exact {97 98 100 115 109 116 65 66 77} 98] 1
check {BK03 (FILE) no ctrl row for 98 survives} \
  [regexp -line {^key,98,ctrl,} $kbcsv] 0
check {BK04 (FILE, BK03's CONTROL) ...while the BARE-b graph row does} \
  [regexp -line {^key,98,0,graph,graph\.forward,1} $kbcsv] 1
check {BK05 (X) key_filter's decision, as a VALUE: bare-b forwards, Ctrl-b does not,
       Ctrl-d still does not} [bk_fwd_triple] {1 0 0}
check {BK06 (X) Ctrl-B over a strip toggles the BROWSER and does NOT toggle sym_txt} \
  [list [::wviewer::browser_shown $tok] [xschem get sym_txt]] [list 1 $bk_sym0]
check {BK07 (X, R9's SAFETY CLAIM) bare `b` over the same strip still toggles
       waveform cursor B and still leaves sym_txt alone} [bk_bare_b] {1 0}
check {BK08 (X) test_bindings_file's byte-identity still holds} ...
check {BK09 (X) test_keybindings_help lost no id} ...
```
**BK05/BK06 are the only checks that see the R9 landmine.** `set fwd` at `:11214` has **zero** test coverage today — grepped, it appears once in the repo and no test reads it. Without the carve-out, Ctrl-B still toggles the browser (the WaveViewer tag binding fires and `key_filter` never `break`s) **and** falls through to `callback.c:6035`, flipping `xctx->sym_txt`. Every other check stays green.

**Green.** Bind, carve-out, C deletion, csv regeneration and guide rename all in one commit.

**Existing checks it reds.** BS03 ×2, BS04, BS05 (leg 1), BS09 ×2, BS42, BS45 ×5, BS46 ×2 (silent→retargeted) → `Control-Key-b` / `Ctrl+B`. GH1 (`grid:409-413`), GH3 (`:426-433`), GH5/GH6 (`:1057-1087`) are **loops over the guide's own values** — no literal edit, and they red the instant guide and source drift. `test_bindings_file.tcl:30`.

**Sabotages.**
- Skip the `key_filter` carve-out → **BK05/BK06 red with `sym_txt` flipped**, BS03/BS04/BS45 all green. **Run this one rather than reasoning about it.**
- Delete 98 from `graphkeys` instead of carving out the modifier → **BK02 red**; bare `b` stops reaching `waves_callback`.
- Delete the bare-`b` csv row too → **BK04 and BK07 red**.
- Hand-edit `keybindings.csv` without deleting `callback.c:4988` → **BK08 red and NOTHING else** — the whole reason BK08 sits on this item.
- Rename the guide row but not the bind → **GH1 red alone** (16 rows still, one unresolvable): the lockstep failure GH0's count cannot see.

**⚠ FLAG, NOT A RE-OPENING.** `src/callback.c:991` computes `access_cond = !graph_use_ctrl_key || (state & ControlMask)`, and `:1647`'s `case 'b'` is gated on it. R9's "bare `b` is sufficient" holds for the shipped default (`graph_use_ctrl_key` 0, `src/xschemrc:716` commented out). **For a user who sets it to 1, bare `b` never reached cursor B and Ctrl+b was the only chord — after this item there is none.** `src/wave_viewer.tcl:347` already records `graph_use_ctrl_key` as a known residual risk. Record it in spec §10 as declared limit 8; do not condition the carve-out on it without a new ruling.

**Done when** the eight `--nogui` files green, `BK01`-`BK04` green headless, `BK05`-`BK09` green under the gate.

---

### Item 17 — R10: Ctrl-Alt-V via the action registry + the selected-instance arm

**Scope.** Five coordinated edits plus the one genuinely new capability in this batch.

1. `src/callback.c` `action_registry[]` (`:4677`), Tcl-backed, on the `view.toggle_view_type` template:
   `{ "wave.show_in_signal_browser", NULL, "ase::show_in_browser_for_current", "Show in Signal Browser" }`.
2. `init_input_bindings()` (`:4920`): `set_input_binding(DEV_KEY, 'v', ControlMask|Mod1Mask, ACTX_CANVAS, "wave.show_in_signal_browser");`
   ⚠ **The Tcl command takes no `%W`.** `dispatch_input_action` (`:5178-5195`) runs a **constant string** — there is no event substitution. That is safe because `callback()` calls `handle_window_switching(win_path)` at `:8611` *before* dispatch, so the context is already correct and `ase::show_in_browser_for_current`'s `{win {}}` arm (`src/ase.tcl:1054`) is exactly right. Make the csv command `ase::show_in_browser_for_current` with no argument and **assert it**, so a logged replay line is context-free by design rather than by accident.
3. `src/actions.csv` — one row; `test_keybindings_help.tcl:38-49` renders `(bare: <id>)` without it.
4. `src/keybindings.csv` — **REGENERATED**; the row must read `key,118,ctrl+alt,canvas,wave.show_in_signal_browser,` (`mods_name`, `src/callback.c:5271`, emits `ctrl+shift+alt+super` order; verified there are **zero** existing `ctrl+alt` rows and **zero** code-118 rows, so it is unambiguous).
5. `src/cadence_style_rc:245` deleted; `src/xschem.tcl:14939` `-accelerator Ctrl+5` → `Ctrl+Alt+V` (the `-command "ase::show_in_browser_for_current ${topwin}.drw"` is unchanged — a menu click knows its window).
6. **THE NEW CAPABILITY.** `src/ase.tcl` `show_in_browser_for_current` (`:1054-1107`), between the `hier_now` pivot (`:1075`) and the origin drop: read the schematic selection; **if exactly one instance is selected**, append its `name=` token (lowercased to match ngspice's raw) to `$segs`. Zero or 2+ selected, or a non-instance selection → unchanged behaviour, and it **says which it did**. The instance name comes from the same token `hier_resolve` compares against (`new_prop_string()`, `src/token.c:795-833`), so the two agree by construction.

**RED first** — `BK20`-`BK32`:
```tcl
check {BK20 (FILE) actions.csv has exactly one wave.show_in_signal_browser row} $n 1
check {BK21 (FILE) the keybindings row is spelled EXACTLY, mods order included} \
  [regexp -line {^key,118,ctrl\+alt,canvas,wave\.show_in_signal_browser,$} $kbcsv] 1
check {BK22 (FILE) the registry row is Tcl-backed with a NULL fn} [bk_reg_row] {1 1}
check {BK23 (FILE) the Tcl command takes NO window argument} \
  [regexp {"ase::show_in_browser_for_current"} $csrc] 1
check {BK24 (FILE) cadence_style_rc no longer binds Control-Key-5 ...} \
  [regexp {Control-Key-5} $rc] 0
check {BK25 (BK24's CONTROL, SAME FILE) ...and still binds Control-Key-4 for Direct Plot} \
  [regexp {Control-Key-4} $rc] 1
check {BK26 (FILE) ...and no rc file binds Control-Alt-Key-v either — the point of
       R10 is REMAPPABILITY, and an rc bind bypasses `xschem bind`} \
  [regexp {Control-Alt-Key-v} $rc] 0
check {BK27 (FILE) the Tools entry spells the new accelerator, adjacent to the label} \
  [regexp {-label "Show in Signal Browser" *\\\n *-accelerator Ctrl\+Alt\+V} $xsrc] 1
check {BK28 (X) the dump carries the row and no canvas row for code 53} [bk_dump] {1 0}
check {BK29 (X) it is REMAPPABLE: unbind -> the chord stops working -> rebind -> it works} \
  [bk_remap_triple] {1 0 1}
check {BK30 (PURE) the composition: nothing selected -> hier_now; ONE instance ->
       hier_now + that name; TWO -> hier_now and it SAYS so} [bk_compose] \
  {{x1} {x1 x2} {x1}}
check {BK31 (SOURCE) the selection is read BETWEEN the hier_now pivot and the
       origin drop, never after the viewer is raised} [bk_order] 1
check {BK32 (SOURCE) the selection arm fires only on `== 1`, so a `>= 1` cannot hide} \
  [regexp {llength \$bk_sel\] == 1} $ase] 1
check {BK33 (X) one instance selected lands on <hier_now>.<instance>; nothing
       selected lands on <hier_now> — BOTH legs, same fixture} [bk_two_arms] \
  {g:x1.x2 g:x1}
check {BK34 (X) the composed path is case-insensitive against the raw (X2 finds x2)} ...
check {BK35 (X) the DESIGN window never moves and context is LEFT ON THE VIEWER} ...
```

**Green.** All five edits plus the selection arm.

**Existing checks it reds.** `test_bindings_file.tcl` (regenerated csv), `test_keybindings_help.tcl:38-49` (the new id needs its `actions.csv` row). **BX13 (`i12:338-341`) stays at `{0 0}` in value but is RENAMED and WIDENED** to assert three zeros — no `data-seq` for the old chord, none for the new, and no `data-menu="Show in Signal Browser"` — with its existing `data-seq="Key-E"` control leg (`:342`) kept **verbatim**, or the three zeros are vacuous on a stripped guide.

**Sabotages.**
- Spell the mods `alt+ctrl` → **BK21 red and `test_bindings_file` red** — two files, one cause.
- Add the registry row but not `actions.csv` (or vice versa) → **`test_keybindings_help` red one way, `find_action_def` NULL the other**; assert both directions.
- Bind it in `cadence_style_rc` instead of the registry → **BK26 and BK29 red, BK33 green.** The behaviour is indistinguishable except through the un-bind.
- Use `>= 1` selected → **BK32 and BK30's third leg red.**
- Read the selection after the viewer is raised → **BK31 red**, and the pivot becomes the viewer's untitled buffer (`src/ase.tcl:1075`'s stated reason).
- Add a guide row for the new chord → **BX13 red and GH0's 16 moves.**

**Done when** BK20-BK27, BK30-BK32 green headless; BK28/BK29/BK33-BK35 and both binding suites green under the gate.

---

### Item 18 — R12: auto-tick, reveal, and say so

**Scope.** `browser_show_path`'s miss arm (`:7688-7772`). When the requested node resolves to nothing **and it WOULD resolve with `devint` on**, tick R11(a) **through the normal toggle path** (§7.4: it is a user-initiated change from a key the user pressed, so it **is** logged — one keystroke, one log line), refresh, re-resolve, reveal, and return a new `{unhidden <id> <path>}` result. `browser_msg` gains its sentence via the **one** formatter — a second wording composed inline would drift from the sidebar's status line. The box **stays** ticked (R12).

⚠ **The unhide test must be a POSITIVE, not an absence.** "The node is missing, so tick the box" would tick it for a genuinely absent path. It ticks only when the `devint 1` model **has** the node.

**RED first** — `BK40`-`BK47`:
```tcl
check {BK40 (PURE) browser_msg renders the new `unhidden` result into ONE sentence
       naming the node} [::wviewer::browser_msg {unhidden g:x1.xm1 x1.xm1}] \
  {showing device internals to reach x1.xm1}
check {BK41 (BK40's CONTROL) the four SHIPPED results still render as BX13's four} ...
check {BK42 (X) devint OFF, target a device instance: ok, selected, box now 1} \
  [list $res [$TV selection] [::wviewer::browser_devint $tok]] {{unhidden g:x1.xm1 x1.xm1} {g:x1.xm1} 1}
check {BK43 (X) ...and it SAYS SO} [string match {*device internals*} [$F.ph cget -text]] 1
check {BK44 (X, R12's LAST SENTENCE) the box STAYS ticked one refresh later, and the
       ACCESSOR and the VARIABLE agree} \
  [begin {::wviewer::browser_refresh $tok}
   list [::wviewer::browser_devint $tok] [set ::wviewer::browserdev($tok)]] {1 1}
check {BK45 (X, THE ABSENCE CONTROL) a path that exists in NEITHER model leaves the
       box UNTICKED and reports err/partial} \
  [list $res2 [::wviewer::browser_devint $tok]] {{err {no such node}} 0}
check {BK46 (X, THE OTHER CONTROL) a node hidden by the SEARCH BAR does NOT tick the
       box — it reports the existing bars-active sentence} \
  [list [::wviewer::browser_devint $tok] [string match {*Search/Filter*} $msg]] {0 1}
check {BK47 (X) the auto-tick is ONE refresh, not two} [bk_refresh_count] 1
check {BK48 (X) with devint ALREADY on, the same call gives a plain ok — no
       spurious "I turned it on"} $res3 {ok g:x1.xm1 x1.xm1}
check {BK49 (X) the improve-or-restore discipline survives: a retry that finds LESS
       restores browsersigs, browserrows, browserdbsigs AND the selection} ...
```

**⚠ §9 note, live here:** ticking the box makes `browser_state` non-default, so `snapshot` starts emitting a `browser` key it did not emit before. **That is correct** (spec §9), MG9 is unaffected (it pins the *snapshot's* key list, and `browser` is a value inside it), and BP02's "exactly one emission site" is what proves no second site grew. Re-run `test_wave_modes.tcl` on this item.

**Sabotages.**
- Tick the box on **any** miss → **BK45 and BK46 red**, BK42/BK43/BK44 green. The dual pair.
- Untick after revealing → **BK44 red.**
- Compose the sentence inline instead of through `browser_say` → **BK40 red**, and the sidebar and the CIW then disagree, which no count can see.
- Refresh twice → **BK47 red** alone; nothing visible changes.

**Done when** BK40/BK41 green headless, BK42-BK49 green under the gate, `test_wave_modes.tcl` still 214.

---

### Item 19 — Docs, oracles, lockstep, 0217 closed

**Scope.** See §5 for the full delta. In this item:

- `doc/claude/specs/waveform_signal_browser.md` (the **parent** spec — GS1/GS2/GS3 read only this file): reconcile the contract list so **every** proc this batch minted is named. Extend GS2's hard-coded 23-name roster.
- `doc/claude/specs/waveform_signal_browser_two_pane.md`: fix §5.4's stated rule to the measured hybrid (§0.1); fix §14's device-node counts (78→84, 278→303); fix M6's 11→9; add declared limit 8 (`graph_use_ctrl_key`, item 16); record the `d:N|` fix as closed.
- `doc/waveform_viewer_guide.html` §11 rewritten for two panes; the fourteen `data-bseq` rows final; §9.1's Ctrl-B row.
- `doc/claude/issues/0217-*.md` closed **and `git add`ed** — it is currently **untracked**, and GS3 requires every cited issue to resolve to exactly one file on a clean checkout. File the new `browser_target_path` `d:N|` issue and cite it.

**RED first** — `GS10`-`GS15` in `test_wave_grid.tcl`:
```tcl
check {GS10 the parent spec's contract list NAMES every proc this batch added} \
  [bs_missing $gs_names {browser_tree browser_sea browser_class_filter browser_tree_rows
     browser_level_names browser_label browser_label_full browser_root_label browser_root_id
     browser_flow_layout browser_flow_cell browser_flow_hit browser_flow_scrollregion
     browser_sea_build browser_sea_refresh browser_sea_selection browser_devint
     browser_srccur browser_sash}] {}
check {GS11 GS0's floor really grew} [expr {[llength $gs_names] >= 48}] 1
check {GS12 the guide's browser section names BOTH panes and BOTH checkbox labels} \
  [bs_all_in $guide {instance tree} {sea of names} {Show device internals}
                    {Show source currents}] 1
check {GS13 the guide carries NO data-seq row for Control-Key-l and none for the
       schematic chord} \
  [list [regexp -all {data-seq="Control-Key-l"} $guide] \
        [regexp -all {data-seq="[^"]*Alt-Key-v"} $guide]] {0 0}
check {GS14 (GS13's CONTROL) ...while Control-Key-b and Key-E ARE there} \
  [list [regexp -all {data-seq="Control-Key-b"} $guide] \
        [regexp -all {data-seq="Key-E"} $guide]] {1 1}
check {GS15 the batch's issue files all resolve, 0217 among them} ...
```
Plus **GH11**, the hole GH9 cannot see:
```tcl
check {GH11 browser_build binds nothing through a widget ALIAS} \
  [regexp -all -line {^\s*bind \$[a-z]} $gh_bb] $gh_nbb
check {GH11 (CONTROL) the counter sees the binds that ARE there} [expr {$gh_nbb >= 14}] 1
```
`set c $f.pw.sea.c; bind $c <Button-1> …` is invisible to **both** GH8 and GH9, so the shipped count could be wrong *and* green.

**Green.** All eight `--nogui` files green; the guide, both specs, GH0/GH8/GH9/GH11, BT09, BX13 and GS0-GS15 all agree.

**Sabotages.**
- Name a proc in the spec that was never written → **exactly one GS1 leg red**, naming the proc. Demonstrate this once deliberately — it is the mechanism that forces spec and code into one commit.
- Delete half the contract list → **GS11 red.**
- Describe the old single-pane tree → **GS12 red.**
- Bump the guide's count in one file of four → **BT09 or BX13 red**; run it in each of the four to confirm all four fire.

**Done when** the final sweep records the new totals in the batch ledger.

---

## 3. Silent-green traps

Ranked by how far the failure lands from the check that would have caught it.

| # | trap | why it is silent | the check that catches it | item |
|---|---|---|---|---|
| **1** | **`browser_width`'s four literals are SOURCE greps, so they stay green while the width rule stops applying.** Build `$f.pw` as a child of the toplevel instead of `$f` and BT08 (`:787-794`) and BP07 (`i1315:736-747`) — the two files that doubly pin M5 — are both green, and the sidebar silently stops governing the panes. | Both oracles read `wvproc_body`, never a live widget. | **BW14** (`winfo height $F.pw > 1` **and** the sash fraction strictly in (0,1)), asserted on a **mapped** pane. BW08/BW09 are the greps and are deliberately *not* trusted alone. | 9 |
| **2** | **`browser_state_is_default` is a whole-dict string compare, and its only behavioural consequence lands in a DIFFERENT FILE.** Read `sash` live, or default `srccur` to 0, and the gate is permanently false → every window's snapshot grows a `browser` key → **MG9 (`test_wave_modes.tcl:1314`) red**, in a file nobody running the browser suites will open. | The browser suites' own BP checks all pass; the damage is one `dict keys` in another suite. | **BP60/BP61/BP64/BP68/BP69 locally + MG10 in `test_wave_modes.tcl`.** `test_wave_modes.tcl` joins the per-item verifier set from item 9 onward. | 14 |
| **3** | **BD19/BD21/BD22/BD25 pin `browser_rows_multi`'s HELPER contract, not the caller.** R7 changes what `browser_refresh` *passes*; the `{}`-label arm simply stops being used, and all four checks keep passing on a code path production no longer takes. | Every one of them calls the helper directly with a hand-built group. | **BD67** — after a LIVE refresh with the box on, `browserrows`' first row is a `group` whose text is the current DB's label. | 15 |
| **4** | **`key_filter`'s `set fwd` (`:11214`) has ZERO test coverage.** Grepped: the expression appears once in the repo and no test file reads it. Skip the Ctrl-B carve-out and the browser still toggles (the tag binding fires; `key_filter` never `break`s) while `xctx->sym_txt` also flips. | The visible effect is correct; the second, unwanted effect is invisible. | **BK05** (the `fwd` decision as a three-value tuple, headless) and **BK06** (`sym_txt` unchanged, live). | 16 |
| **5** | **A new optional argument that the body ignores.** `browser_rows {entries {root {}} {anypath {}}}` keeps BT10/BT11/BT12/BD19/BD22/BX01 green whether or not the args are read — and M6's flat-mode downgrade hits 9 of 22 designs. | Every existing pure fixture passes one argument. | **BN12 + BN13** (the same filtered set with the gate forced 1 and forced 0 → two different `text` values) and **BW31/BW32** behaviourally. | 2, 10 |
| **6** | **`browser_leaf_names` is untouched, but its INPUT changes.** R6 says the proc stays recursive; R11 changes what `browserrows` holds. With internals hidden, `tb_charge_pump` drops 1191 → 137 and a "plot everything under this block" plots 12% of it — with zero red checks, because BT13/BM12/BD23/BX all use synthetic fixtures. | Spec §6 **rules** this correct ("one consistent set"), but nothing asserts it. | **BW24 + BW43** — `browser_leaf_names` on `g:x1` reads 406 with internals on, and the two checkbox states give two different measured numbers. | 10, 12 |
| **7** | **`send_key` on an unbound chord SKIPS, it does not fail.** BS46 (`sigbrowser:572-592`) prints `SKIPPED: BS46 real-key leg` and asserts nothing. Retarget it to Ctrl-B or R9's only real-key coverage evaporates silently. | The printed skip line looks like a WSLg flake. | Watch for the literal `SKIPPED: BS46` in the run output; it is the check's red state. | 16 |
| **8** | **The guide's `bind $f.` count is greppable only if every bind is literally `bind $f.`.** A local alias (`set c $f.pw.sea.c; bind $c …`) is invisible to GH8 *and* GH9, so the count can be wrong and green in both directions. | Both oracles regex the same literal prefix. | **GH11** — `bind $<var>` count must equal `bind $f.` count. | 19 |
| **9** | **`-selectmode browse` gates only the CLASS BINDINGS.** Verified at `/usr/share/tcltk/tk8.6/ttk/treeview.tcl:263`: `$tv selection set {a b}` is unaffected, so a state file written by the shipped `extended` version restores a two-id selection into a browse tree and R4 is false from the first restore. | The widget *looks* single-select under the mouse. | **BW10 with BW11 as its control** (the same widget, reconfigured to `extended`, gives 2), plus **BW56/BW57** for the restore narrowing. | 9, 13 |
| **10** | **`browser_populate` clears the selection on every keystroke.** `$tv delete [$tv children {}]` drops it, and `browser_refresh` runs on every character typed in either bar. Under R4 the invariant is broken constantly, and nothing asserts it. | The tree looks fine; the selection just blinks. | **BW29** — three legs (after refresh, after an explicit `selection set {}`, after a keystroke), all 1. | 10 |
| **11** | **BP04's zero-hit leg is an unanchored substring.** `sbcase(\|sbcfg(\|sballdb(\|dest(` — an array named `browserdest(` would match and red it for a reason nobody would guess. | The regexp reads like it names four specific arrays. | Naming rule, asserted: the new arrays are `browsersash(`, `browserdev(`, `browsersrc(`. **BP04 re-run unedited.** | 14 |
| **12** | **`browser_target_path`'s leaf arm re-parses the raw name** (`:7399` `sig_split [dget $row name]`) instead of reading the row's stored `path`. Harmless for tree rows (they are groups) but live for the sea's RMB menu. | Group ids decode from the id; only leaf ids go through the re-parse. | **BN78.** | 8 |

---

## 4. Test file layout

Ruling 30 (one process per design-window-coupled item) and M10's ~150 ceiling both hold. `wvbs_common.tcl` **keeps its name** — `full_audit.sh` globs `test_*.tcl` and a prelude with that name runs as a case, reports zero checks, prints no `RESULT` line and scores FAIL forever.

| file | band | arm | now | after | contains |
|---|---|---|---|---|---|
| `test_wave_sigsearch.tcl` | SB, DC, SL, GS | pure | **139** | 139 | **untouched** — M1's DC01-DC28 band already landed |
| `test_wave_sigbrowser.tcl` | BS, BT, BM | mixed | 135 | **~146** | Ctrl-B rename (items 16), child set + pack recipe (9), the BT24-BT33 tree restatement + the BT25/26/27 compound-triple rebuild (10). ⚠ **the tightest file — add nothing else** |
| `test_wave_sigbrowser_i11.tcl` | BH | mixed | 50 | **~56** | path re-point (9); BH41's narrowed name; BH60-BH63 (browse-mode + `browser_menu_ids` per widget) |
| `test_wave_sigbrowser_i12.tcl` | BX | mixed | 29 | **~36** | BX30's inversion + two-state control, BX31's third leg, BX42 re-run, BX13 widened (17) |
| `test_wave_sigbrowser_i1315.tcl` | BR, BP | mixed | 80 | **~95** | BR20/BR21 child+pack sets (9); BP10/BP13/BP45 restated, BP53's PRE control, BP54 re-aimed, BP60-BP70 (14) |
| `test_wave_sigbrowser_i14.tcl` | BD | mixed | 47 | **~60** | BD50's grandparent leg, BD51 path, BD60-BD70 (15) |
| `test_wave_grid.tcl` | GH, GS | pure | 214 | **~226** | GH8/GH9 6→14, GH11, GS10-GS15 (19) |
| `test_wave_modes.tcl` | MG | mixed | 212 | **214** | MG10 + control (14) |
| **NEW** `test_wave_sigbrowser_model.tcl` | **BN** | pure | — | **~62** | items 1-5, 8: accessors, `browser_rows`' two args, the class filter, the node model, `browser_level_names`, the root-skip and the `d:N\|` decode |
| **NEW** `test_wave_sigbrowser_sea.tcl` | **BQ** | mixed | — | **~42** | items 6, 7 (pure: labels + flow arithmetic) and 11 (X: the live canvas) |
| **NEW** `test_wave_sigbrowser_panes.tcl` | **BW** | X | — | **~62** | items 9, 10, 12, 13: the paned skeleton, the tree going live, the checkboxes, reveal-vs-collapsed |
| **NEW** `test_wave_sigbrowser_keys.tcl` | **BK** | mixed | — | **~46** | items 16, 17, 18: Ctrl-B, Ctrl-Alt-V, R12 |

**`--nogui` total after the batch: ≈ 694 → ≈ 830.** Nothing crosses 150.

**`tests/headless/wvbs_common.tcl` gains five readers**, each an **assertable value** with three distinct shapes for "never built" / "built and empty" / "correctly filtered to zero" — never a count, never a boolean, never a throw:

| helper | answers |
|---|---|
| `bs_tree_flat {tv}` | relocated from `bt_flat`/`bt_tree` (`sigbrowser:644-657`), now needed by four files; `no-tree` / `empty` / the depth-first `id\|text` list. `bt_tree` stays as a one-line alias so 20 call sites do not churn |
| `bs_sea_labels {c}` | `no-pane` / `empty` / the ordered label list in creation order. ⚠ **`empty` is a LEGITIMATE render** — 12 of `tb_bandgap`'s 44 kept nodes have zero own-level signals |
| `bs_open_set {tv}` | the **set** of expanded ids, e.g. `{g:}` vs `{g: g:x1 g:x1.x2 g:x1.y3}`. Never a count — a count of 1 vs 4 says the same thing far less legibly when a node is renamed |
| `bs_sash_frac {pw}` + `bs_wait_sash {pw {budget 300} {settle 12}}` | the fraction, or `-1` (no panedwindow) / `-2` (zero height), so a mid-map read is visible in the log instead of masquerading as 0.0. Modelled on `bs_wait_widths`' settle poll |
| `wvbs_tv {top}` / `bs_opt {tok key}` | the docked tree path (one line to change in item 9) and `pcall`-wrapped checkbox reads |

**Committed fixtures** (`tests/headless/fixtures/`): the 22-raw corpus lives under `tests/headless/.scratch/0211/…`, which `test_scratch_drop` deletes and no clean checkout has. Extract **name-only** lists once — `tb_bandgap_vars.txt` (424 names, ~14 KB) and `tb_charge_pump_vars.txt` (1191 names, ~40 KB). The second is **mandatory**: `tb_bandgap` has **zero** `devmeas` signals and cannot see a devnode/devmeas mix-up at all (BN30). ⚠ `tb_charge_pump_ase.raw` is 621 MB — `head -c 4000000` only, once, at fixture-freeze time; never `cat`.

---

## 5. Doc deltas

### `doc/claude/specs/waveform_signal_browser.md` — the **parent** spec (the only file GS1/GS2/GS3 read)

Every proc gets its `- \`wviewer::name\` — …` contract line **in the same commit as the proc** (GS1 goes red once per missing proc, and that count is the running to-do list).

| item | contract lines added |
|---|---|
| 1 | `browser_tree`, `browser_sea` |
| 2 | amend `browser_rows` / `browser_rows_multi` for the two optional args |
| 3 | `browser_class_filter` |
| 4 | `browser_tree_rows`, `browser_root_label` |
| 5 | `browser_level_names` |
| 6 | `browser_label`, `browser_label_full` |
| 7 | `browser_flow_layout`, `browser_flow_cell`, `browser_flow_hit`, `browser_flow_scrollregion` |
| 8 | amend `browser_node_for` (the `start` arg), `browser_root_id` |
| 9 | `browser_sea_build`, `browser_sash` |
| 11 | `browser_sea_refresh`, `browser_sea_selection` |
| 12 | `browser_devint`, `browser_srccur` |
| 19 | **reconcile**: §5 contract list complete; §8 becomes "the tree AND the sea"; §14's declared-limit table gains the R8 residual risk, the sash-fraction/pixel divergence, the legitimately-empty pure ancestor, and `graph_use_ctrl_key`; §16's test map gains the four new files. **GS2's 23-name roster grows to 29** with `sig_declass`, `browser_class_filter`, `browser_tree_rows`, `browser_level_names`, `browser_label`, `browser_flow_layout`. **GS0's `>= 20` floor becomes `>= 48`.** |

### `doc/claude/specs/waveform_signal_browser_two_pane.md` — the ruling document (**item 19**)

1. **§5.4** — replace "the instance half is the last path segment" with the measured hybrid (§0.1), and add the measurement: *last-path-segment reproduces 6 of 7 table rows and collides 29 times; the hybrid reproduces 7 of 7 and collides 0, over 2656 corpus names.* Add the leading-`@` strip (25 names).
2. **§14** — the device-node counts: `tb_bandgap` 78 → **84**, `tb_charge_pump` 278 → **303**. The corrected percentages follow.
3. **§2.2 M6** — "11 of 22 corpus designs" → **9 of 22**, with the method stated (entries with a path pre-filter, none post-`devint`-off).
4. **§4.1** — the design root is `-open 1`, everything else `-open 0` (§0.3).
5. **§7.3** — add BW54/BW55: the applied open set unions the restored selection's ancestor chain, or R4 is satisfiable with the selection invisible.
6. **§10** — new declared limit 8: with `graph_use_ctrl_key 1`, R9 removes the only chord that reached cursor B.
7. **§11** — mark the `browser_target_path` `d:N|` mis-decode **FIXED** (both sites, item 8) and file it as a numbered issue.
8. **§12.1** — the corrected inventory: **17** `tvf.tv` in src (five in the `$windows`-dict form), **73** `.wvbrowser` and **21** `tvf.tv` in tests, of which only **four** are docked paths.
9. **§12.2 / §13** — GH8/GH9 `6` → **14**, not 12: the six sea gestures plus `<Configure>` plus the tree's `<<TreeviewSelect>>`. Baseline **694**, not 660 — M1 already landed.

### `doc/waveform_viewer_guide.html`

| what | where | item |
|---|---|---|
| `data-seq="Control-Key-l"` → `Control-Key-b`; `<kbd>Ctrl-L</kbd>` → `Ctrl-B`; `data-accel="Ctrl+L"` → `Ctrl+B` | `:483-490` | **16** |
| the four browser rows `data-bseq="tvf.tv …"` → `pw.tvf.tv …` | `:1135, :1139, :1143, :1147` | **9** |
| **+1 row** `data-bseq="pw.tvf.tv &lt;&lt;TreeviewSelect&gt;&gt;"` | browser table | **10** |
| **+7 rows** `data-bseq="pw.sea.c …"` — Button-1, Shift-Button-1, Control-Button-1, Double-Button-1, Button-2, Button-3, Configure | browser table | **11** |
| §11 rewritten for two panes: the collapsed single-select instance tree with one design root; the column-major sea of names with horizontal scroll only and Cadence labels; the two checkboxes and their defaults; R6's rationale for the tree's recursive plot | §11 | **19** |
| Ctrl-Alt-V in **PROSE ONLY** — no `data-seq`, no `data-menu` row (it is a *schematic* key; Ctrl-5 is the precedent BX13 was written against) | §11 | **17/19** |
| the two checkbuttons get **no accelerator** — GH0's 11 and GH4's count must not move | §11 | **12** |

### The four-file lockstep — exactly what moves and when

| oracle | file:line | today | after | moves in item |
|---|---|---|---|---|
| **`data-seq` = 16** | `grid:404` (GH0), `sigbrowser:823` (BT09), `i12:332` (BX13, reads `test_wave_grid.tcl` **as text**), the guide | 16 | **16 — UNCHANGED** | — (Ctrl-L→Ctrl-B is a rename; Ctrl-Alt-V gets no row) |
| **`data-accel` = 11** | same four | 11 | **11 — UNCHANGED** | — (the checkbuttons get no accelerator) |
| **`data-bseq` = 6** | `grid:473` (GH8), `grid:485` (GH9), the guide | 6 | **7** then **14** | **10**, then **11** |
| GH1 / GH3 / GH5 / GH6 | `grid:409-433, :1057-1087` | loops over the guide's own values | value-follows | **16** (no literal edit; they red the instant guide and source drift) |
| GH11 (**new**) | `grid` | — | `bind $<var>` count == `bind $f.` count | **19** |

**The rule:** the guide row and the `bind $f.` line ship in the **same commit**, and the GH8 literal is bumped **first** so it is red until both exist. GH9 is the automatic other direction; GH11 is the only check that sees a bind written through an alias.

### `doc/claude/issues/`

- **`0217-raw-device-class-prefixes-render-as-fake-hierarchy-levels.md`** — currently **UNTRACKED**. `git add` it in item 19 or **GS3 reds on a clean checkout**. Close it with the measured declass numbers (2656 names, 87% under a tag, four classes, the `#`-backward trap).
- **NEW** — `browser_target_path` and `browser_show_path` mis-decode `d:N|`-prefixed All-DBs ids (`:7397`, `:7765`), enabling "Descend to here" on foreign rows and firing a garbage instance path. Fixed in **item 8**; cite it from both specs so GS3 resolves it.