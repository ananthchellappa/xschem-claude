# tests/headless/test_wave_sigbrowser_i12.tcl — Signal Browser PLAN item 12,
# HIERARCHY SYNC schematic -> browser ("Show in Signal Browser", Tools menu +
# Ctrl-5). The MIRROR of item 11.
# doc/claude/signal_browser_batch/PLAN.md item 12; receipts/12_receipt.md.
#
# ⚠⚠ THIS FILE WAS CARVED OUT OF test_wave_sigbrowser.tcl BY DRIVER RULING 30.
# Settled decision 9 put items 8-15 in one file. At 489 checks that file was
# killed mid-run by WSLg with ZERO check failures (measured 2026-08-06: 0 of 9
# completions), which made every later item's verification unmeasurable.
# Ruling 30 revised decision 9 and split the checks BY ITEM RANGE:
#
#   test_wave_sigbrowser.tcl       items 8, 9, 10   BS BT BM
#   test_wave_sigbrowser_i11.tcl   item 11          BH
#   test_wave_sigbrowser_i12.tcl   item 12          BX   <- THIS FILE
#   (items 13-15 create ONE more file; item 13 owns that decision)
#
# ⚠ WHY ITEM 12 GOT A FILE TO ITSELF — the FIXTURE COST, which is the mechanism
# the ruling names, not the check count. BX40-BX52 holds a REAL VIEWER AND THE
# REAL DESIGN WINDOW AT THE SAME TIME, walks the hierarchy in both, opens and
# closes sessions, and drives the real Tools menu and a real Ctrl-5. In the 8
# pre-split runs five deaths landed inside BX4x/BX5x and three inside item 11's
# equally two-windowed BH5x; not one landed in BS, BT or BM.
#
# ============================================================================
# ⚠⚠ THE FIXTURE PROLOGUE — THE ONE PLACE THIS SPLIT COULD HAVE GONE HOLLOW
# ============================================================================
# In the merged file, item 12's BX4x block ran on state ITEM 11 HAD BUILT: the
# design window loaded on the wvhier fixture, `bh_library.defs`, both session
# state files, and three registered sessions. Carving item 12 out without
# rebuilding that would not have failed loudly — `viewer_ready` would have
# answered 0, the block would have printed its own `SKIPPED:` line, and the
# file would have gone GREEN having verified nothing. That is precisely the
# "green but hollow" outcome ruling 30 warns about, so the prologue below
# rebuilds item 11's fixture VERBATIM, in item 11's ORDER:
#
#   1. `::library_registry_defs_only 1`   (item 8's viewer group set this, and
#      item 11 inherited it; it is now explicit rather than accidental)
#   2. `XSCHEM_LIBRARY_PATH` = the wvhier fixture + xschem_library, set
#      UNQUALIFIED so the variable trace fires (memory: the LIBRARY_PATH gotcha)
#   3. `xschem load wvhier_top.sch` into the MAIN design window — BEFORE the
#      defs file is written, exactly as item 11 did it
#   4. `bh_library.defs` + `XSCHEM_LIBRARY_DEFS`
#   5. the two session state files and THREE sessions:
#      `bh/wvhier_top/schematic`, `bh/wvhier_mid/schematic` (item 11's BH32) and
#      `wvhier/wvhier_top/schematic` (item 11's BH50). The third one looks
#      redundant and is not: BX47 closes EVERY session that could bind to this
#      design and then asserts the command declines. With that session missing,
#      BX47's close of it would be a no-op and the check would be weaker than it
#      was in the merged file.
#
# ⚠ THE PROLOGUE IS NOT TAKEN ON TRUST. `BX40 (FIXTURE)` reads the design
# window's schname, sim_sch_path and currsch back and asserts them; the block's
# `SKIPPED:` line names WHICH precondition failed rather than saying "no X". A
# prologue that silently did nothing therefore fails BX40 instead of vanishing.
#
# ============================================================================
# CONVENTIONS — SHARED WITH EVERY OTHER BROWSER FILE (wvbs_common.tcl)
# ============================================================================
# `check`, `check_true`, `pcall`, the counting `::bgerror`, `wvproc_body`,
# `bs_packed`, `bs_order`, `bs_wait_mapped`, `bs_wait_mapped_top`,
# `bs_wait_widths`, `send_key`, `viewer_ready`, `$wsrc` and `wvbs_finish` come
# from `tests/headless/wvbs_common.tcl`, which is deliberately NOT named
# `test_*.tcl` (full_audit.sh selects cases with `ls test_*.tcl`).
#
# GROUP PREFIX: item 12 is `BX`, never reused. Numbers are BLOCKED by arm:
# 01-19 source/pure (BOTH arms), 20-39 the throwaway toplevel, 40-59 the REAL
# viewer + the REAL design window.
#
# ⚠ THE ARM STATEMENT. The `--nogui` arm runs BX01-BX14 only — the source greps
# and the pure-Tcl reads. Every behavioural claim (the reveal, the scroll, the
# Tools entry, the real Ctrl-5) needs real Tk and real X, so A GREEN `--nogui`
# RUN PROVES NOTHING ABOUT "Show in Signal Browser".
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated groups print
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i12.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_i12.tcl

set ::wvbs_tag  wvsigbrowser_i12
set ::wvbs_name test_wave_sigbrowser_i12
source [file join [file dirname [info script]] wvbs_common.tcl]

# --- THE FIXTURE PROLOGUE (see the ⚠⚠ above) --------------------------------
# fixtures/wvhier: top holds `X1` AND `x1` (both instances of mid) plus the
# non-subcircuit `V9`; mid holds `X2`; leaf is a leaf. Item 11's BH20 built it;
# this rebuilds it, in the same order, for a process item 11 never touched.
set ::library_registry_defs_only 1
set bh_fix [file join $repo tests headless fixtures wvhier]
set XSCHEM_LIBRARY_PATH "$bh_fix:[file join $repo xschem_library]"
set bx_load [pcall xschem load [file join $bh_fix wvhier_top.sch]]
set bh_defs [file join $scratch bh_library.defs]
set bh_f [open $bh_defs w]
puts $bh_f "DEFINE wvhier $bh_fix"
close $bh_f
set XSCHEM_LIBRARY_DEFS $bh_defs
set bh_stTOP [dict merge [ase::state_default] \
  [dict create design [dict create lib wvhier cell wvhier_top view schematic]]]
set bh_stMID [dict merge [ase::state_default] \
  [dict create design [dict create lib wvhier cell wvhier_mid view schematic]]]
pcall ase::state_save [file join $scratch bh_top.state] $bh_stTOP
pcall ase::state_save [file join $scratch bh_mid.state] $bh_stMID
pcall ase::session_open bh/wvhier_top/schematic [file join $scratch bh_top.state]
pcall ase::session_open bh/wvhier_mid/schematic [file join $scratch bh_mid.state]
# item 11's BH50 session — kept so BX47's close of it stays live (see above)
pcall ase::session_open [ase::session_key wvhier wvhier_top schematic] \
  [file join $scratch bh_top.state]

if {[catch {

# ============================================================================
# BX01-BX52 — item 12: hierarchy sync SCHEMATIC -> BROWSER
# ("Show in Signal Browser", Tools menu + Ctrl-5). The MIRROR of item 11.
#
# ⚠⚠ THE ORACLE, and it is the reason this block can make the claim at all
# (driver note (d) / ruling 26). "The node is VISIBLE" has FOUR failure modes
# that `selection` cannot tell apart and that `bbox` alone reports IDENTICALLY:
#   * the node is not in the tree at all              -> `absent`
#   * it is there but an ancestor is COLLAPSED        -> `collapsed`
#   * ancestors are open but the tree is SCROLLED off -> `offscreen`
#   * the widget itself was never mapped / was
#     withdrawn (bbox answers for a once-mapped,
#     now-withdrawn tree, so bbox CANNOT see this)    -> `unmapped`
# plus `root` (id {}, which `exists` reports TRUE) and `no-tree`. SEVEN
# assertable strings, every one of them measured on this fixture, in the shape
# item 9's `bs_order` and item 10's `bm_menu_state` established. It never throws.
#
# ⚠ THE VACUOUS-CHECK TRAP (driver note (c)) — all three PLAN sabotages look
# identical to "the command did nothing". The POSITIVE CONTROLS come FIRST and
# are named as such: BX30 proves collapsed->visible really happens on the good
# path, BX32 proves offscreen->visible, BX34 asserts the selection is EMPTY
# before claiming the fallback moved it, and BX40 asserts the sidebar is
# `browser_shown` 0 AND absent from `pack info` before claiming it un-hid.
#
# ⚠ WHAT THIS BLOCK DOES NOT CLAIM, stated rather than hidden: settled decision
# 10's PIVOT CHOICE is NOT behaviourally proven here, for the same reason item
# 11 could not prove it — in the DESIGN window no raw is loaded, so
# `sim_sch_path` and `sch_path` are byte-identical and swapping the getter fires
# nothing. What IS proven is the level>0 ORIGIN MAPPING (BX48: the same
# hierarchy position answers `x1.x2` under a level-0 session and `x2` under a
# level-1 one) plus a source guard that the shipped bodies contain zero
# `sch_path` reads (BX09). Claim narrowed, not check invented (ruling 17).
# ============================================================================

# SEVEN-VALUED, NEVER THROWS. `unmapped` is checked BEFORE bbox precisely
# because bbox cannot see it.
proc bx_vis {tv id} {
  if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
  if {$id eq {}} { return root }
  if {[catch {$tv exists $id} ex] || !$ex} { return absent }
  set p $id
  while {1} {
    set par {}
    if {[catch {$tv parent $p} par]} { return absent }
    if {$par eq {}} break
    set o 0
    catch {set o [$tv item $par -open]}
    if {!$o} { return collapsed }
    set p $par
  }
  set m 0
  catch {set m [winfo ismapped $tv]}
  if {!$m} { return unmapped }
  set bb {}
  catch {set bb [$tv bbox $id]}
  if {$bb eq {}} { return offscreen }
  return visible
}

# ⚠ THE MAPPING-AWARE WRAPPER, and it is item 5's rule not a fudge: POLL THE
# PRECONDITION, NEVER THE ASSERTED VALUE. Under WSLg a freshly raised viewer can
# still report `winfo ismapped` 0 for a few milliseconds, and `bx_vis` would then
# answer `unmapped` for a node that is perfectly visible a moment later.
# MEASURED: BX42's second leg flaked exactly that way, 1 run in 4 — the same
# shape as item 11's own BH54 `winfo ismapped .` flap. This waits for the
# MAPPING (the precondition) and then asks the oracle once; a genuinely unmapped
# widget still reads `unmapped` after the budget, so no failure mode is hidden.
# The throwaway-toplevel group deliberately keeps the RAW `bx_vis`, because
# BX33's whole point is to observe `unmapped` on purpose.
#
# ⚠⚠ WIDENED AGAIN BY THE RULING-30 SPLIT ROUND — the wrapper was watching the
# WRONG WIDGET. Measured in a post-split soak: BX43 failed 2 of ~26 runs with
# `{1 g:x1.x2 unmapped}` — the recorder had fired and the SELECTION was already
# correct, so the only wrong element was the mapping. The reason is that
# `raise_activate_toplevel` is `wm withdraw` + `wm deiconify` (issue 0054's WSLg
# idiom), and a withdraw unmaps the WHOLE TOPLEVEL SUBTREE. Waiting on the tree
# alone therefore polls a widget whose mapping cannot come back until its
# toplevel's does, and on a loaded compositor the toplevel's MapNotify can take
# longer than the tree's own budget allowed. So the toplevel is waited on FIRST.
#
# ⚠ STILL A WIDENING, NOT A WEAKENING. Both waits poll a PRECONDITION and
# neither returns a verdict: the oracle is asked exactly once afterwards, a
# genuinely unmapped widget still reads `unmapped` and still FAILS, and the
# throwaway-toplevel group deliberately keeps the RAW `bx_vis` because BX33's
# whole point is to observe `unmapped` on purpose.
proc bx_vis_m {tv id} {
  if {![catch {winfo ismapped $tv} m] && $m} { return [bx_vis $tv $id] }
  # THE TOPLEVEL FIRST — a withdrawn toplevel makes every descendant unmapped,
  # so polling the tree alone is polling a consequence, not the cause.
  catch {bs_wait_mapped_top [winfo toplevel $tv] 400}
  # then the widget itself. BOUNDED: 4s is orders of magnitude more than a map
  # race needs, and bs_wait_mapped's 1500-iteration default would spin `update`
  # (and therefore redraws) for 15 SECONDS on a genuinely unmapped widget.
  catch {bs_wait_mapped $tv 400}
  return [bx_vis $tv $id]
}

# --- BX01-BX14: PURE + SOURCE, BOTH ARMS ------------------------------------
# `browser_node_for` and `browser_origin_drop` take no Tk and no xschem, which
# is exactly why the deepest-ancestor fallback and the origin arithmetic — the
# two things sabotages (b) and (d) attack — are provable in `--nogui`.
set bx_rows [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(x1.x2.net5)}] \
  [wviewer::signal_entry {v(x1.y3.net7)}] \
  [wviewer::signal_entry {v(out)}]]]
check {BX01 (fixture) the row set really carries the two group levels} \
  [list [wviewer::browser_kind $bx_rows g:x1] \
        [wviewer::browser_kind $bx_rows g:x1.x2] \
        [wviewer::browser_kind $bx_rows {s:v(out)}]] \
  [list group group leaf]
check {BX01 an EXACT two-segment path finds the deep group} \
  [pcall ::wviewer::browser_node_for $bx_rows {x1 x2}] {g:x1.x2 2}
# ⚠ THE CASE LEG, and it is the one that decides whether this item works on a
# real ngspice raw at all: ngspice lowercases the raw while sim_sch_path reports
# the SCHEMATIC's own `X1.X2`. Sabotage (d) deletes the -nocase candidate.
check {BX02 (CASE) the SCHEMATIC's X1.X2 finds the raw's lowercase x1.x2} \
  [pcall ::wviewer::browser_node_for $bx_rows {X1 X2}] {g:x1.x2 2}
set bx_rows2 [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(x1.a)}] \
  [wviewer::signal_entry {v(X1.b)}]]]
check {BX03 (EXACT-FIRST) a level carrying BOTH x1 and X1 resolves each to itself} \
  [list [pcall ::wviewer::browser_node_for $bx_rows2 {x1}] \
        [pcall ::wviewer::browser_node_for $bx_rows2 {X1}]] \
  [list {g:x1 1} {g:X1 1}]
# ⚠ THE DEEPEST-ANCESTOR FALLBACK — sabotage (b)'s pure target. The PLAN's
# "select the deepest ancestor that does exist" IS this return value.
check {BX04 (FALLBACK) a path one segment too deep answers the deepest ancestor} \
  [pcall ::wviewer::browser_node_for $bx_rows {X1 X2 X9}] {g:x1.x2 2}
check {BX04 ...and two segments too deep answers the same node, matched 2} \
  [pcall ::wviewer::browser_node_for $bx_rows {x1 x2 x9 x8}] {g:x1.x2 2}
check {BX05 a path with nothing in common answers {} and matched 0} \
  [pcall ::wviewer::browser_node_for $bx_rows {Z9 Q1}] {{} 0}
check {BX06 an EMPTY segment list is {} 0 — the sim-root case, handled elsewhere} \
  [pcall ::wviewer::browser_node_for $bx_rows {}] {{} 0}
# a leaf is a SIGNAL, not an instance: `v(out)` must not make `out` descendable,
# and `net5` must not extend the path past its own group
check {BX07 (DECLARED LIMIT) leaves are NOT matched — a top-level signal name} \
  [pcall ::wviewer::browser_node_for $bx_rows {out}] {{} 0}
check {BX07 ...nor a leaf under a real group: x1.x2.net5 stops at x1.x2} \
  [pcall ::wviewer::browser_node_for $bx_rows {x1 x2 net5}] {g:x1.x2 2}
# THE ORIGIN ARITHMETIC (issue 0168's mapping, without touching sch_path)
check {BX08 browser_origin_drop: no raw in the design ctx -> drop `level` segments} \
  [list [pcall ::wviewer::browser_origin_drop 0 -1] \
        [pcall ::wviewer::browser_origin_drop 1 -1] \
        [pcall ::wviewer::browser_origin_drop 2 -1]] \
  [list 0 1 2]
check {BX08 ...a raw AT the session's level cancels out; below it is NEGATIVE (refused)} \
  [list [pcall ::wviewer::browser_origin_drop 1 1] \
        [pcall ::wviewer::browser_origin_drop 2 1] \
        [pcall ::wviewer::browser_origin_drop 0 1]] \
  [list 0 1 -1]
check {BX08 ...and junk from either getter degrades to the level-0/no-raw case} \
  [list [pcall ::wviewer::browser_origin_drop {} {}] \
        [pcall ::wviewer::browser_origin_drop -3 xx]] \
  [list 0 0]

# --- BX09-BX13: the SOURCE guards -------------------------------------------
set bx_ap [file join $repo src ase.tcl]
set bx_fp [open $bx_ap r]; set bx_asrc [read $bx_fp]; close $bx_fp
set bx_sib [wvproc_body $bx_asrc ase::show_in_browser_for_current]
check_true {BX09 ase::show_in_browser_for_current was found in the source} \
  [expr {$bx_sib ne {}}]
# THE DECISION-10 SOURCE GUARD, item 11's BH06 one layer over. It is a SOURCE
# check on purpose: with no raw in the design window the two getters are
# byte-identical, so no behavioural check can tell them apart (see the block
# header's narrowed claim).
check {BX09 it pivots on hier_now (sim_sch_path) and NEVER reads sch_path} \
  [list [expr {[string first {wviewer::hier_now} $bx_sib] >= 0}] \
        [regexp -all {(^|[^_])sch_path} $bx_sib]] \
  [list 1 0]
set bx_bsp [wvproc_body $wsrc wviewer::browser_show_path]
set bx_bnf [wvproc_body $wsrc wviewer::browser_node_for]
check {BX09 ...and neither viewer-side body reads sch_path either} \
  [list [regexp -all {(^|[^_])sch_path} $bx_bsp] \
        [regexp -all {(^|[^_])sch_path} $bx_bnf]] \
  [list 0 0]
# ⚠ ORDER, not merely presence: `wviewer::open` and the sidebar show both move
# the xschem context to the VIEWER, so a pivot read after them measures the
# viewer's own untitled buffer. Measured in the scout's probes; the check is
# what stops a future edit reordering the two lines.
set bx_i1 [string first {wviewer::hier_now} $bx_sib]
set bx_i2 [string first {wviewer::open} $bx_sib]
check {BX10 the PIVOT is read BEFORE wviewer::open moves the context} \
  [list [expr {$bx_i1 >= 0}] [expr {$bx_i2 > $bx_i1}]] [list 1 1]
check {BX10 ...and it does NOT re-implement an opener — wviewer::open is the only one} \
  [regexp -all {load_new_window|window_for \$key} $bx_sib] 0
# THE KEY, in the file the PLAN names
set bx_rcp [file join $repo src cadence_style_rc]
set bx_fp [open $bx_rcp r]; set bx_rc [read $bx_fp]; close $bx_fp
set bx_rcline {}
foreach bx_l [split $bx_rc "\n"] {
  if {[string first {<Control-Key-5>} $bx_l] >= 0} { set bx_rcline $bx_l ; break }
}
check {BX11 cadence_style_rc binds .drw <Control-Key-5> to the command, and BREAKs} \
  [regexp {^bind \.drw <Control-Key-5>\s+\{ase::show_in_browser_for_current %W; break\}$} \
     $bx_rcline] 1
check {BX11 ...and it is the ONLY Control-Key-5 line in the rc (no double-bind)} \
  [regexp -all {<Control-Key-5>} $bx_rc] 1
# THE MENU, in src/xschem.tcl (the PLAN said ase_window.tcl; that file builds
# the ASE-L SESSION window's menubar, not the design window's — see the receipt)
set bx_xp [file join $repo src xschem.tcl]
set bx_fp [open $bx_xp r]; set bx_xsrc [read $bx_fp]; close $bx_fp
check {BX12 the design window's Tools cascade carries `Show in Signal Browser`} \
  [regexp {menubar\.tools add command -label "Show in Signal Browser" \\\n\s+-accelerator Ctrl\+5 -command "ase::show_in_browser_for_current \$\{topwin\}\.drw"} \
     $bx_xsrc] 1
check {BX12 ...exactly once, and right after Launch ASE-L (Tools stays one ASE block)} \
  [list [regexp -all {Show in Signal Browser} $bx_xsrc] \
        [expr {[string first {Show in Signal Browser} $bx_xsrc] >
               [string first {Launch ASE-L} $bx_xsrc]}]] \
  [list 1 1]
# ⚠ THE BUMP THAT MUST NOT HAPPEN. test_wave_grid's GH0 counts VIEWER keys
# (`bind WaveViewer ...` in install_default_binds) and VIEWER menu accelerators
# (build_menubar). Item 12's key is a SCHEMATIC `.drw` bind and its menu entry
# is on xschem.tcl's Tools cascade, so 16/11 must stay put and the guide must
# gain no data-seq row — adding one would break GH0 and GH2.
set bx_fp [open [file join $repo tests headless test_wave_grid.tcl] r]
set bx_gsrc [read $bx_fp]; close $bx_fp
check {BX13 test_wave_grid's GH0 literals are UNCHANGED at 16/11} \
  [list [regexp {\[llength \$gh_seqs\] 16} $bx_gsrc] \
        [regexp {\[llength \$gh_menus\] 11} $bx_gsrc]] \
  [list 1 1]
set bx_fp [open [file join $repo doc waveform_viewer_guide.html] r]
set bx_gd [read $bx_fp]; close $bx_fp
check {BX13 ...and the guide gained NO data-seq/data-menu row for the schematic key} \
  [list [regexp -all {data-seq="Control-Key-5"} $bx_gd] \
        [regexp -all {data-menu="Show in Signal Browser"} $bx_gd]] \
  [list 0 0]
check {BX13 (control) the guide DOES still carry item 11's viewer key row} \
  [regexp {data-seq="Key-E"} $bx_gd] 1
# the four sentences, PURE — one formatter, so the status line, the CIW echo and
# the ASE-side echo cannot drift into three accounts of one event
check {BX14 browser_msg: ok} [pcall ::wviewer::browser_msg {ok g:x1.x2 x1.x2}] \
  {showing x1.x2}
check {BX14 browser_msg: partial names BOTH the asked path and the landing} \
  [pcall ::wviewer::browser_msg {partial g:x1.x2 x1.x2 x1.x2.x9}] \
  {no signals under 'x1.x2.x9' - showing x1.x2 instead}
check {BX14 browser_msg: root} [pcall ::wviewer::browser_msg {root {}}] \
  {showing the simulation top level}
check {BX14 browser_msg: err passes its own reason through} \
  [pcall ::wviewer::browser_msg {err {no simulation data loaded - read a raw file first}}] \
  {no simulation data loaded - read a raw file first}

# --- BX20-BX39: the REVEAL, on a throwaway toplevel (X only) -----------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  catch {destroy .wvbx1}
  toplevel .wvbx1
  wm title .wvbx1 {item12 show-in-browser fixture}
  wm geometry .wvbx1 900x400+40+40
  canvas .wvbx1.drw -background white -width 700 -height 360
  pack .wvbx1.drw -side right -fill both -expand true
  dict set ::wviewer::windows wvbx [dict create top .wvbx1 win_path .wvbx1.drw]
  pcall ::wviewer::browser_build wvbx .wvbx1
  set BXF .wvbx1.wvbrowser
  set BXTV $BXF.pw.tvf.tv
  pack $BXF -side left -fill y -before .wvbx1.drw
  set bx_mapped [bs_wait_mapped .wvbx1.drw]
  catch {bs_wait_mapped $BXTV}
  update

  # seed the inventory + the tree DIRECTLY (the BT2x idiom): this fixture has no
  # xschem raw behind it, which is also what makes BX39's restore leg real.
  proc bx_seed {names} {
    global BXTV
    set ::wviewer::browsersigs(wvbx) $names
    set e {}
    foreach n $names { lappend e [wviewer::signal_entry $n] }
    set r [wviewer::browser_rows $e]
    set ::wviewer::browserrows(wvbx) $r
    wviewer::browser_populate $BXTV $r
    update
    return [llength $r]
  }
  set bx_names {v(x1.x2.net5) v(x1.y3.net7) v(out)}
  check {BX20 (FIXTURE) the sidebar built, is mapped, and the tree is seeded} \
    [list $bx_mapped [winfo exists $BXTV] [expr {[bx_seed $bx_names] > 0}]] \
    [list 1 1 1]

  # ⚠⚠ POSITIVE CONTROL #1, and without it every "not visible" claim below is
  # worthless: prove the fixture can be put into `collapsed` at all, and that
  # `collapsed` is a DIFFERENT value from `visible` on the very same node.
  check {BX30 (POSITIVE CONTROL) a freshly populated tree reads `visible`} \
    [bx_vis $BXTV g:x1.x2] visible
  pcall $BXTV item g:x1 -open 0
  pcall $BXTV selection set {}
  update
  check {BX30 (POSITIVE CONTROL) collapsing the ancestor reads `collapsed`, selection empty} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV selection]] [list collapsed {}]

  # THE ITEM, on the HIT path (sidebar already shown, node present) — so no
  # repopulate can intervene and erase the evidence.
  check {BX31 browser_show_path returns ok with the exact node} \
    [pcall ::wviewer::browser_show_path wvbx x1.x2] {ok g:x1.x2 x1.x2}
  update
  check {BX31 ...the node is SELECTED} [pcall $BXTV selection] {g:x1.x2}
  # ⚠ SABOTAGE (a)'s TARGET. `selection` above stays GREEN under it — that is
  # the built-in control that excludes "the command did nothing".
  check {BX31 ...and it is VISIBLE: `see` re-opened the collapsed ancestor} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV item g:x1 -open]] [list visible 1]

  # THE SCROLL LEG — a node whose ancestors are ALL open and which is still not
  # on screen. `collapsed` cannot see this one; only the bbox can.
  set bx_fill {}
  for {set bx_i 0} {$bx_i < 60} {incr bx_i} { lappend bx_fill "v(zz$bx_i)" }
  bx_seed [concat $bx_names $bx_fill]
  pcall $BXTV yview moveto 1.0
  pcall $BXTV selection set {}
  update
  check {BX32 (POSITIVE CONTROL) scrolled to the bottom, x1.x2 reads `offscreen`} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV item g:x1 -open]] [list offscreen 1]
  check {BX32 browser_reveal scrolls it back into view} \
    [list [pcall ::wviewer::browser_reveal wvbx g:x1.x2] [bx_vis $BXTV g:x1.x2]] \
    [list 1 visible]
  bx_seed $bx_names

  # F4: `see`/`selection set`/`bbox` THROW on a missing id, and `exists {}` is
  # TRUE (the root) — both are refused rather than swallowed into a false 1.
  set bx_f0 $::fail
  check {BX33 revealing a MISSING id returns 0 and does not throw} \
    [list [pcall ::wviewer::browser_reveal wvbx g:nope] [bx_vis $BXTV g:nope]] \
    [list 0 absent]
  check {BX33 revealing the EMPTY id returns 0 — `exists {}` is TRUE, so this is explicit} \
    [list [pcall ::wviewer::browser_reveal wvbx {}] [pcall $BXTV exists {}]] \
    [list 0 1]
  check {BX33 ...and neither raised a bgerror} [expr {$::fail - $bx_f0}] 0

  # ⚠ THE FALLBACK, on the widget — sabotage (b)'s behavioural target. The
  # selection is CLEARED first and asserted empty, so "it selected the ancestor"
  # cannot be satisfied by a leftover.
  pcall $BXTV selection set {}
  update
  check {BX34 (control) the selection really is empty before the fallback runs} \
    [pcall $BXTV selection] {}
  check {BX34 a path one segment too deep answers `partial` naming BOTH paths} \
    [pcall ::wviewer::browser_show_path wvbx x1.x2.x9] \
    {partial g:x1.x2 x1.x2 x1.x2.x9}
  update
  check {BX34 ...and the DEEPEST ANCESTOR is selected and visible} \
    [list [pcall $BXTV selection] [bx_vis $BXTV g:x1.x2]] [list {g:x1.x2} visible]

  # the sim root: an ANSWER, not a failure — the selection is cleared and the
  # tree scrolled home on purpose
  pcall $BXTV selection set {g:x1.x2}
  check {BX36 an EMPTY path is the `root` branch} \
    [pcall ::wviewer::browser_show_path wvbx {}] {root {}}
  check {BX36 ...and it CLEARS the selection deliberately} \
    [pcall $BXTV selection] {}

  # THE FOUR SENTENCES, on the real status label
  bx_seed $bx_names
  pcall ::wviewer::browser_show_path wvbx x1.x2
  check {BX37 the status line says `showing <path>` on a hit} \
    [pcall $BXF.ph cget -text] "Signal Browser\nshowing x1.x2"
  pcall ::wviewer::browser_show_path wvbx x1.x2.x9
  check {BX37 ...names both paths on the fallback} \
    [pcall $BXF.ph cget -text] \
    "Signal Browser\nno signals under 'x1.x2.x9' - showing x1.x2 instead"
  pcall ::wviewer::browser_show_path wvbx {}
  check {BX37 ...and says so at the sim root} \
    [pcall $BXF.ph cget -text] "Signal Browser\nshowing the simulation top level"
  # ⚠ the SELECTION IS LEFT ALONE on an outright miss (decision 11's mirror:
  # a failed sync leaves the user where they were)
  bx_seed $bx_names
  pcall $BXTV selection set {g:x1}
  check {BX35 a path matching nothing is an `err` that names what was asked} \
    [pcall ::wviewer::browser_show_path wvbx z9.q1] {err {no signals under 'z9.q1'}}
  check {BX35 ...the status line carries it} \
    [pcall $BXF.ph cget -text] "Signal Browser\nno signals under 'z9.q1'"
  check {BX35 ...and the user's SELECTION SURVIVED the refusal} \
    [pcall $BXTV selection] {g:x1}
  # the Search/Filter clause: a bar CAN hide a node that is really in the raw,
  # which is otherwise indistinguishable from "the raw has no such node"
  check {BX38 (control) with both bars EMPTY the message carries no bar clause} \
    [expr {[string first {Search/Filter} [pcall $BXF.ph cget -text]] >= 0}] 0
  pcall $BXF.wvsearch.pat insert 0 zzz
  check {BX38 with a bar non-empty the message NAMES the bars} \
    [pcall ::wviewer::browser_show_path wvbx z9.q1] \
    {err {no signals under 'z9.q1' (the Search/Filter bar may be hiding it)}}
  check {BX38 ...and the bars were NOT cleared behind the user's back (declared limit)} \
    [pcall $BXF.wvsearch.pat get] zzz
  pcall $BXF.wvsearch.pat delete 0 end

  # ⚠ IMPROVE-OR-RESTORE. This fixture has no xschem raw behind it, so the
  # miss-retry's `browser_refresh $token 1` genuinely FAILS and would otherwise
  # replace a good tree with an empty one — measured on the first cut of
  # browser_show_path, which turned BX34's `partial` into an `err`. The guard is
  # what makes BX34 and BX35 mean anything at all here.
  bx_seed $bx_names
  set bx_rows_before $::wviewer::browserrows(wvbx)
  pcall ::wviewer::browser_show_path wvbx x1.x2.x9
  check {BX39 a MISS whose reload fails RESTORES the rows byte-for-byte} \
    [expr {$::wviewer::browserrows(wvbx) eq $bx_rows_before}] 1
  check {BX39 ...and the widget still holds them, so the tree is not emptied} \
    [list [pcall $BXTV exists g:x1.x2] [bx_vis $BXTV g:x1.x2]] [list 1 visible]

  # `unmapped` — the value bbox CANNOT produce (a withdrawn-but-once-mapped tree
  # still answers bbox), which is why the oracle checks ismapped first
  wm withdraw .wvbx1
  update
  check {BX33 (ORACLE) a withdrawn tree reads `unmapped`, and bbox still answers} \
    [list [bx_vis $BXTV g:x1.x2] [expr {[pcall $BXTV bbox g:x1.x2] ne {}}]] \
    [list unmapped 1]

  destroy .wvbx1
  catch {unset ::wviewer::browsersigs(wvbx)}
  catch {unset ::wviewer::browserrows(wvbx)}
  catch {dict unset ::wviewer::windows wvbx}
  check {BX39 (teardown) the throwaway toplevel and its registry entry are gone} \
    [list [winfo exists .wvbx1] [dict exists $::wviewer::windows wvbx]] [list 0 0]

} else {
  puts "SKIPPED: BX2x/BX3x group (Tk/X arm only)"
}

# --- BX40-BX52: END TO END — real viewer, real design window, real key -------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # ⚠ UPDATED BY THE RULING-30 SPLIT. This used to read "item 11 left the design
  # window loaded…"; it does not any more, because item 11 now lives in its own
  # process. THE FILE'S OWN PROLOGUE builds it (see the ⚠⚠ block at the top), and
  # the two facts this group relies on are unchanged: the design window is loaded
  # on the wvhier fixture, and TWO sessions are registered —
  # bh/wvhier_top/schematic AND bh/wvhier_mid/schematic, in that insertion order,
  # because `session_for_design` returns the FIRST match. That is exploited
  # rather than fought: closing/reopening the MID session is how this block moves
  # `level` between 0 and 1 without a second fixture.
  # ⚠ THE DESIGN WINDOW IS NAMED, NOT INHERITED, and that rule outlived its
  # original reason. `wviewer::open` leaves the context ON THE VIEWER, so
  # `current_win_path` read after the fact names the wrong window and reading the
  # fixture through it produces a skip that looks like "the viewer would not
  # open". The fixture is loaded into the MAIN window by the prologue's
  # `xschem load`, so that is the one, and the switch is VERIFIED like every
  # other switch in this file.
  set bx_dwin .drw
  # ⚠ AND THE SWITCH IS RETRIED AND VERIFIED, never fired once and trusted. An
  # `update` between a raise and a context read can deliver an Enter/FocusIn on
  # some other canvas, which switches the context straight back — measured: the
  # first cut of this block read `.x1.drw` (the viewer) after switching to
  # `.drw`, and self-skipped the whole group. So: DRAIN, switch, RE-READ.
  # ⚠ THE FAST PATH PUMPS NO EVENTS, AND THAT IS A MEASURED REQUIREMENT, not
  # tidiness. `xschem new_schematic switch` is synchronous, so `current_win_path`
  # is already true on return; the `update` retry exists only for the rare bounce
  # above. An unconditional `update` per call redraws BOTH canvases, and with ~25
  # call sites that pushed this file's X-request count from ~5k to ~68k — enough
  # to trip WSLg's Xwayland `can't send file descriptor` abort on nearly every
  # run (receipt §10.2). Measured: 32s and 0/6 completions before, ~4s after.
  proc bx_ctx_to {w} {
    if {[xschem get current_win_path] eq $w} { return 1 }
    catch {xschem new_schematic switch $w}
    if {[xschem get current_win_path] eq $w} { return 1 }
    for {set i 0} {$i < 10} {incr i} {
      update
      catch {xschem new_schematic switch $w}
      if {[xschem get current_win_path] eq $w} { return 1 }
      after 20
    }
    return 0
  }
  bx_ctx_to $bx_dwin
  set bx_tok bh/wvhier_top/schematic
  set bx_mid bh/wvhier_mid/schematic
  pcall ::wviewer::hier_walk {}
  check {BX40 (FIXTURE) the design window is on wvhier_top, at its top level} \
    [list [file tail [pcall xschem get schname 0]] [pcall xschem get sim_sch_path] \
          [pcall xschem get currsch]] \
    [list wvhier_top.sch {} 0]

  set bx_open [pcall ::wviewer::open $bx_tok]
  set bx_vtop [wviewer::window_for $bx_tok]
  # wviewer::open leaves the context ON THE VIEWER (measured) — go back before
  # reading anything hierarchical, and VERIFY the switch followed
  bx_ctx_to $bx_dwin
  set bx_ready [expr {$bx_vtop ne {} && [viewer_ready $bx_vtop]}]
  set bx_ctx [expr {[bx_ctx_to $bx_dwin] ? $bx_dwin : [xschem get current_win_path]}]
  if {$bx_open ne 1 || !$bx_ready || $bx_ctx ne $bx_dwin} {
    # name WHICH precondition failed — a bare skip line hides a broken fixture
    puts "SKIPPED: BX4x/BX5x group (open=$bx_open top='$bx_vtop'\
 ready=$bx_ready ctx='$bx_ctx' want='$bx_dwin')"
    catch {wviewer::close $bx_tok}
  } else {
    set BXVTV $bx_vtop.wvbrowser.pw.tvf.tv
    # ⚠⚠ POSITIVE CONTROL #3 (sabotage (c)): the sidebar is HIDDEN before the
    # command runs, asserted TWO ways — the authority and the packing order —
    # because `pack info` alone cannot tell "hidden" from "never built".
    check {BX40 (POSITIVE CONTROL) a fresh viewer's sidebar is HIDDEN, but BUILT} \
      [list [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser] \
            [winfo exists $bx_vtop.wvbrowser]] \
      [list 0 0 1]

    # a REAL raw in the VIEWER's own context (the BTV/BMV/BH5x idiom): a
    # two-level path, a one-level one, and a top-level `x2.` — the last so that
    # a level-1 origin has somewhere real to land as well as a level-0 one.
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw new bx_item12.raw dc vsweep 0 1.0 0.5
    foreach bx_n {v(out) v(x1.x2.net5) v(x1.topsig) v(x2.deep)} {
      pcall xschem raw add $bx_n {vsweep 1 +}
    }
    bx_ctx_to $bx_dwin
    check {BX40 (control) the context is back on the DESIGN window} \
      [expr {[pcall xschem get current_win_path] eq $bx_dwin}] 1

    # WHICH session resolves, asserted before anything is claimed about the
    # viewer (the scout's risk: item 11's two sessions are still live)
    pcall ase::session_close $bx_mid
    pcall ::wviewer::hier_walk X1.X2
    set bx_sfc [pcall ase::session_for_current]
    check {BX41 at X1.X2 with the MID session closed, the TOP session resolves at level 0} \
      [list [lindex $bx_sfc 0] [lindex $bx_sfc 1]] [list $bx_tok 0]

    # ==== THE ITEM, END TO END ====
    set bx_r [pcall ase::show_in_browser_for_current $bx_dwin]
    # ⚠ READ THE CONTEXT WITH NO EVENT PUMP IN BETWEEN — an `update` here can
    # deliver a stray Enter and move it, which would make the DECLARED context
    # rule below untestable rather than false.
    set bx_ctxafter [xschem get current_win_path]
    update
    check {BX42 the command returns the session key} $bx_r $bx_tok
    # ← sabotage (c)
    check {BX42 (SIDEBAR) it UN-HID the sidebar — authority AND packing agree} \
      [list [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser] \
            [bs_order $bx_vtop $bx_vtop.wvbrowser $bx_vtop.drw]] \
      [list 1 1 a-before-b]
    # ← sabotage (d): X1.X2 must find the raw's lowercase x1.x2
    check {BX42 (SELECTION) the node for X1.X2 is selected — the raw's x1.x2} \
      [pcall $BXVTV selection] {g:x1.x2}
    # ← sabotage (a)
    check {BX42 (VISIBLE) and it is on screen with its ancestors open} \
      [bx_vis_m $BXVTV g:x1.x2] visible
    check {BX42 the browser status line reports the landing} \
      [pcall $bx_vtop.wvbrowser.ph cget -text] "Signal Browser\nshowing x1.x2"
    # THE DECLARED CONTEXT RULE (item 11's mirror): the viewer was raised, so
    # the context is left there. Asserted, not accidental.
    check {BX42 (DECLARED) the context is LEFT ON THE VIEWER, the raised window} \
      [expr {$bx_ctxafter eq "$bx_vtop.drw"}] 1
    bx_ctx_to $bx_dwin
    check {BX42 ...and the DESIGN window never moved: still wvhier_top, still at X1.X2} \
      [list [file tail [pcall xschem get schname 0]] \
            [pcall xschem get sim_sch_path]] \
      [list wvhier_top.sch {X1.X2.}]

    # ⚠⚠ THE FIRST INVOKE CANNOT PROVE THE EXPANSION, and that was MEASURED, not
    # reasoned: un-hiding the sidebar repopulates the tree, and `browser_populate`
    # inserts every group `-open 1`, so the node is visible whether or not
    # anything expanded it. Sabotage (a) (delete `$tv see`) left the leg above
    # GREEN. The SECOND invoke is the real one — sidebar already shown, so no
    # repopulate intervenes, and the ancestor deliberately collapsed first.
    pcall $BXVTV item g:x1 -open 0
    pcall $BXVTV selection set {}
    update
    check {BX42 (POSITIVE CONTROL) with its ancestor collapsed the node reads `collapsed`} \
      [list [bx_vis_m $BXVTV g:x1.x2] [pcall $BXVTV selection]] [list collapsed {}]
    bx_ctx_to $bx_dwin
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX42 (SECOND INVOKE) on an already-shown COLLAPSED tree it still lands VISIBLE} \
      [list [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1.x2] \
            [pcall $BXVTV item g:x1 -open]] \
      [list {g:x1.x2} visible 1]
    bx_ctx_to $bx_dwin

    # THE 0168 AGREEMENT, as a VALUE rather than an assumption (driver note (f)).
    # sod_rel_path is the ASE session side's own answer to the same question;
    # this asserts the two agree at level 0 AND level 1. ⚠ TEST-ONLY: the shipped
    # path never calls it (it reads sch_path, which decision 10 forbids us) —
    # BX09 is what guards that.
    set bx_segs [pcall ::wviewer::hier_now]
    check {BX49 (0168 AGREEMENT) drop-0 equals sod_rel_path 0, byte for byte} \
      [list "[join [lrange $bx_segs 0 end] .]." [pcall ase::ui::sod_rel_path 0]] \
      [list {X1.X2.} {X1.X2.}]
    check {BX49 ...and drop-1 equals sod_rel_path 1 — the ancestor-owned-raw case} \
      [list "[join [lrange $bx_segs 1 end] .]." [pcall ase::ui::sod_rel_path 1]] \
      [list {X2.} {X2.}]

    # ==== BX48: THE LEVEL>0 MAPPING — the one behavioural proof of the origin
    # arithmetic. SAME hierarchy position, DIFFERENT session level, DIFFERENT
    # browser path: x1.x2 at level 0 (BX42 above), x2 at level 1.
    # ⚠ MEASURED BY SPY, and the spy is the RIGHT instrument here rather than a
    # shortcut. The claim is exactly "which PATH does the command compute", and
    # a second real viewer toplevel adds only WSLg fragility to it (the first cut
    # self-skipped when the mid session's window would not map). BX42 already
    # proves the whole chain end to end at level 0; this isolates the ORIGIN
    # ARITHMETIC and runs BOTH levels from the SAME hierarchy position, so the
    # two answers are a genuine discriminator rather than one value in a vacuum.
    set ::bx_paths {}
    rename ::wviewer::open ::wviewer::__bx_open
    proc ::wviewer::open {token} { return 1 }
    rename ::wviewer::browser_show_path ::wviewer::__bx_bsp
    proc ::wviewer::browser_show_path {token path} {
      lappend ::bx_paths [list $token $path]
      return [list err {spy}]
    }
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    # leg 1 — the level-0 session (mid still closed): the WHOLE path
    set ::bx_paths {}
    pcall ase::show_in_browser_for_current $bx_dwin
    set bx_p0 $::bx_paths
    # leg 2 — the level-1 session: the SAME position, one segment shorter
    pcall ase::session_open $bx_mid [file join $scratch bh_mid.state]
    bx_ctx_to $bx_dwin
    set bx_sfc2 [pcall ase::session_for_current]
    check {BX48 (control) with the MID session back, X1.X2 resolves it at level 1} \
      [list [lindex $bx_sfc2 0] [lindex $bx_sfc2 1]] [list $bx_mid 1]
    set ::bx_paths {}
    pcall ase::show_in_browser_for_current $bx_dwin
    set bx_p1 $::bx_paths
    check {BX48 (ORIGIN) one position, two session levels, two DIFFERENT browser paths} \
      [list $bx_p0 $bx_p1] \
      [list [list [list $bx_tok X1.X2]] [list [list $bx_mid X2]]]
    # leg 3 — a raw loaded IN THE DESIGN CONTEXT at level 1. sim_sch_path is then
    # already `X2.`, so the level-1 session needs NO drop and lands identically —
    # while the level-0 session is a NEGATIVE drop and must be REFUSED outright
    # rather than guessed at.
    pcall xschem raw new bx_dsgn.raw dc vsweep 0 1.0 0.5
    pcall xschem raw add {v(zz)} {vsweep 1 +}
    pcall xschem set raw_level 1
    check {BX48 (control) the design ctx now really has a raw at level 1} \
      [list [pcall xschem raw loaded] [pcall xschem get sim_sch_path]] [list 1 {X2.}]
    set ::bx_paths {}
    pcall ase::show_in_browser_for_current $bx_dwin
    check {BX48 a raw at the session's OWN level needs no drop — same path, no double-strip} \
      $::bx_paths [list [list $bx_mid X2]]
    pcall ase::session_close $bx_mid
    bx_ctx_to $bx_dwin
    set ::bx_paths {}
    set bx_neg [pcall ase::show_in_browser_for_current $bx_dwin]
    check {BX48 (NEGATIVE DROP) a raw read BELOW the session's design is REFUSED, not guessed} \
      [list $bx_neg $::bx_paths] [list {} {}]
    pcall xschem raw clear
    rename ::wviewer::browser_show_path {}
    rename ::wviewer::__bx_bsp ::wviewer::browser_show_path
    rename ::wviewer::open {}
    rename ::wviewer::__bx_open ::wviewer::open
    check {BX48 (teardown) both spied procs are back in place} \
      [list [expr {[info commands ::wviewer::__bx_bsp] eq {}}] \
            [expr {[info commands ::wviewer::__bx_open] eq {}}] \
            [expr {[info commands ::wviewer::browser_show_path] ne {}}] \
            [expr {[info commands ::wviewer::open] ne {}}]] \
      [list 1 1 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX44: the REAL Tools entry, found BY LABEL ====
    set bx_tm .menubar.tools
    if {![winfo exists $bx_tm]} {
      puts "SKIPPED: BX44 (the main window has no Tools menu)"
    } else {
      set bx_ti -1
      catch {set bx_ti [$bx_tm index {Show in Signal Browser}]}
      check {BX44 the Tools entry exists, with its accelerator and its command} \
        [list [expr {$bx_ti >= 0}] \
              [pcall $bx_tm entrycget $bx_ti -accelerator] \
              [pcall $bx_tm entrycget $bx_ti -command]] \
        [list 1 {Ctrl+5} {ase::show_in_browser_for_current .drw}]
      # invoke it FOR REAL from a different hierarchy position and assert the
      # world moved to match
      bx_ctx_to $bx_dwin
      pcall ::wviewer::hier_walk x1
      pcall $BXVTV selection set {}
      update
      pcall $bx_tm invoke $bx_ti
      update
      check {BX44 invoking it really re-targets the browser at x1} \
        [list [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1] \
              [pcall $bx_vtop.wvbrowser.ph cget -text]] \
        [list {g:x1} visible "Signal Browser\nshowing x1"]
      bx_ctx_to $bx_dwin
    }

    # ==== BX45: at the TOP -> the `root` branch; the sidebar STAYS shown ====
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk {}
    pcall $BXVTV selection set {g:x1.x2}
    update
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX45 at the sim top the selection is cleared and the reason given} \
      [list [pcall $BXVTV selection] \
            [pcall $bx_vtop.wvbrowser.ph cget -text]] \
      [list {} "Signal Browser\nshowing the simulation top level"]
    check {BX45 ...and the sidebar is STILL shown (a no-op must not re-hide it)} \
      [list [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser]] \
      [list 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX50: RELOAD-ON-MISS (item 9's D6, decided deliberately) ====
    # a signal added to the raw BEHIND the browser's back is invisible to the
    # snapshot; a MISS spends one reload and finds it. A HIT must NOT reload —
    # a repopulate would clear the selection and re-open every group.
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1
    set bx_rows_a $::wviewer::browserrows($bx_tok)
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    bx_ctx_to $bx_dwin
    check {BX50 (control) a HIT does not reload — the row snapshot is byte-identical} \
      [expr {$::wviewer::browserrows($bx_tok) eq $bx_rows_a}] 1
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw add {v(x1.x2.x7.late)} {vsweep 1 +}
    bx_ctx_to $bx_dwin
    check {BX50 (control) the browser has NOT seen the new signal yet (D6 snapshot)} \
      [lindex [pcall ::wviewer::browser_node_for $::wviewer::browserrows($bx_tok) \
                 {x1 x2 x7}] 1] 2
    pcall ::wviewer::hier_walk X1.X2
    # there is no X7 instance in the fixture, so walk there by hand-feeding the
    # path — what is under test is the RELOAD, not the descend
    set bx_r3 [pcall ::wviewer::browser_show_path $bx_tok x1.x2.x7]
    update
    check {BX50 a MISS reloads once and FINDS the late signal's group} \
      [list $bx_r3 [expr {[llength $::wviewer::browserrows($bx_tok)] >
                          [llength $bx_rows_a]}]] \
      [list {ok g:x1.x2.x7 x1.x2.x7} 1]

    # ==== BX46: NO RAW AT ALL -> the honest report, sidebar untouched ====
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw clear
    bx_ctx_to $bx_dwin
    catch {unset ::wviewer::browsersigs($bx_tok)}
    pcall $BXVTV selection set {}
    update
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX46 with no raw loaded it says so rather than doing nothing} \
      [pcall $bx_vtop.wvbrowser.ph cget -text] \
      "Signal Browser\nno simulation data loaded - read a raw file first"
    check {BX46 ...nothing is selected, and the sidebar is still shown} \
      [list [pcall $BXVTV selection] [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser]] \
      [list {} 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX43: THE REAL KEY, on the REAL design canvas ====
    # ⚠ NOT `source`d from cadence_style_rc (that installs every cadence bind and
    # sources eight util files, perturbing later groups) — the exact line is
    # grepped in BX11 and bound HERE, verbatim, the test_cadence_window_hop_log
    # idiom.
    set ::bx_calls 0
    rename ::ase::show_in_browser_for_current ::ase::__bx_real
    proc ::ase::show_in_browser_for_current {{win {}}} {
      incr ::bx_calls
      return [uplevel 1 [list ::ase::__bx_real $win]]
    }
    bind .drw <Control-Key-5> {ase::show_in_browser_for_current %W; break}
    bx_ctx_to $bx_dwin
    # rebuild the inventory the raw clear above emptied
    bx_ctx_to $bx_vtop.drw
    pcall xschem raw new bx_key.raw dc vsweep 0 1.0 0.5
    foreach bx_n {v(out) v(x1.x2.net5)} { pcall xschem raw add $bx_n {vsweep 1 +} }
    bx_ctx_to $bx_dwin
    pcall ::wviewer::browser_refresh $bx_tok 1
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    pcall $BXVTV selection set {}
    catch {raise_activate_toplevel .}
    catch {focus .drw}
    update
    set bx_c0 $::bx_calls
    if {![send_key .drw <Control-Key-5> {$::bx_calls > $bx_c0}]} {
      puts "SKIPPED: BX43 (WSLg key-delivery stall on the design canvas)"
    } else {
      update
      check {BX43 a REAL Ctrl-5 on the design canvas targets the browser at x1.x2} \
        [list [expr {$::bx_calls - $bx_c0}] \
              [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1.x2]] \
        [list 1 {g:x1.x2} visible]
      # NEGATIVE CONTROL on the SAME recorder: an unbound chord must read ZERO,
      # which is what stops the recorder passing vacuously
      bx_ctx_to $bx_dwin
      catch {raise_activate_toplevel .}
      catch {focus -force .drw}
      update
      set bx_c1 $::bx_calls
      catch {event generate .drw <Control-Key-6>}
      update
      check {BX43 (NEGATIVE CONTROL) an unbound Ctrl-6 records ZERO on the same spy} \
        [expr {$::bx_calls - $bx_c1}] 0
    }
    catch {bind .drw <Control-Key-5> {}}
    rename ::ase::show_in_browser_for_current {}
    rename ::ase::__bx_real ::ase::show_in_browser_for_current
    check {BX43 the real ase::show_in_browser_for_current is back in place} \
      [list [expr {[info commands ::ase::__bx_real] eq {}}] \
            [expr {[info commands ::ase::show_in_browser_for_current] ne {}}]] \
      [list 1 1]

    # ==== BX47: NO SESSION AT ALL -> an honest notice, and no viewer opened ==
    bx_ctx_to $bx_dwin
    set bx_tops0 [llength [winfo children .]]
    pcall ase::session_close $bx_tok
    pcall ase::session_close wvhier/wvhier_top/schematic
    set bx_none [pcall ase::show_in_browser_for_current $bx_dwin]
    update
    check {BX47 with no session bound the command returns {} and opens nothing} \
      [list $bx_none [expr {[llength [winfo children .]] - $bx_tops0}]] \
      [list {} 0]
    pcall ase::session_open $bx_tok [file join $scratch bh_top.state]
    bx_ctx_to $bx_dwin
    catch {wviewer::close $bx_tok}
  }

} else {
  puts "SKIPPED: BX4x/BX5x group (Tk/X arm only)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  puts "$::errorInfo"
  incr fail
}

wvbs_finish
