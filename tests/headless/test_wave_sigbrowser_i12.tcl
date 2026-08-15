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
# ⚠ THE ARM STATEMENT. The `--nogui` arm runs BX01-BX15 only — the source greps
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

# item 17's fixture reader: the design window's instance names in INDEX order.
# A list, so a check can name what it addresses by index (BX16) instead of
# trusting the fixture not to have been reordered.
proc bx_inst_names {} {
  set out {}
  if {[catch {xschem objects -type instance} objs]} { return OBJECTS-FAILED }
  foreach o $objs { lappend out [dict get $o name] }
  return $out
}

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
# BX01-BX53 — item 12 + item 17: hierarchy sync SCHEMATIC -> BROWSER
# ("Show in Signal Browser", Tools menu + a key). The MIRROR of item 11.
#
# ⚠ BX54-BX56 — TWO-PANE ITEM 17b. The chord moved off the cadence_style_rc
# `Ctrl-5` Tk bind and onto the C action registry as `Ctrl+Alt+V`, so it is
# remappable and works outside the cadence profile. Only THIS file's fixture (a
# real design window AND a real viewer at once) can measure it behaviourally.
# BX11/BX12/BX13/BX43/BX44 are RESTATED for it in place — inverted, retargeted
# or widened, never deleted; each carries a note where it sits.
# MEASURED spent ids in this file: BX01-BX18, BX20, BX30-BX56 (BX19 and
# BX21-BX29 are PRE-EXISTING GAPS — do not back-fill them). NEXT FREE: BX57.
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

# --- BX01-BX15: PURE + SOURCE, BOTH ARMS ------------------------------------
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
# ⚠⚠ BX11 IS RESTATED BY INVERSION, NOT DELETED — TWO-PANE item 17b (R10).
# Item 12 shipped this chord as a cadence_style_rc Tk bind; two-pane item 17b
# MOVES it into the C action registry as Ctrl+Alt+V so it is remappable
# (`xschem bind` / keybindings.csv) and works outside the cadence profile. Both
# legs keep their ids and their file; what they assert flips from presence to
# ABSENCE. The `test_key_graph_context` precedent (two-pane item 16) is why the
# inversion carries its own positive control in the next check rather than
# standing alone — an emptied rc would satisfy an absence claim.
check {BX11 (INVERTED by two-pane item 17b) cadence_style_rc no longer binds
       .drw <Control-Key-5> — the chord moved to the C registry} \
  [regexp {^bind \.drw <Control-Key-5>\s+\{ase::show_in_browser_for_current %W; break\}$} \
     $bx_rcline] 0
check {BX11 (INVERTED) ...no Control-Key-5 line survives at all, and the rc is
       not simply emptied: Ctrl-4 (Direct Plot) and Ctrl-$ are still bound} \
  [list [regexp -all {<Control-Key-5>} $bx_rc] \
        [regexp {<Control-Key-4>} $bx_rc] [regexp {<Control-Key-dollar>} $bx_rc]] \
  [list 0 1 1]
# THE MENU, in src/xschem.tcl (the PLAN said ase_window.tcl; that file builds
# the ASE-L SESSION window's menubar, not the design window's — see the receipt)
set bx_xp [file join $repo src xschem.tcl]
set bx_fp [open $bx_xp r]; set bx_xsrc [read $bx_fp]; close $bx_fp
# ⚠ RETARGETED IN PLACE by two-pane item 17b: the accelerator is now Ctrl+Alt+V
# (the C registry's chord). The -command is UNCHANGED — a menu click knows its
# own window, which the keyboard route deliberately does not.
check {BX12 the design window's Tools cascade carries `Show in Signal Browser`} \
  [regexp {menubar\.tools add command -label "Show in Signal Browser" \\\n\s+-accelerator Ctrl\+Alt\+V -command "ase::show_in_browser_for_current \$\{topwin\}\.drw"} \
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
# ⚠ WIDENED by two-pane item 17b, same id, same value class. The chord moved
# from Control-Key-5 to Control-Alt-Key-v, so the OLD zero alone would now be
# green for the wrong reason: it is trivially true of a chord that no longer
# exists. The NEW spelling's zero is the claim that matters, and both are kept
# so a re-added row of either vintage reds here.
check {BX13 ...and the guide gained NO data-seq/data-menu row for the schematic
       key — NEITHER the old chord NOR two-pane item 17b's new one} \
  [list [regexp -all {data-seq="Control-Key-5"} $bx_gd] \
        [regexp -all {data-seq="Control-Alt-Key-v"} $bx_gd] \
        [regexp -all {data-menu="Show in Signal Browser"} $bx_gd]] \
  [list 0 0 0]
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

# ⚠ THE ROOTED ROW LIST — item 2's design root, and item 8's `start` argument
# which exists for it. BX01-BX07 above walk a ROOT-LESS list on purpose: that is
# the All-DBs shape and it is what every pre-item-2 caller produced. Nothing
# pinned what the SAME walk does once the root is there, and the answer is
# `{} 0` — every real instance hangs off `g:`, so a walk seeded `{}` dead-ends
# on the first segment (the only group whose parent is `{}` is the ROOT ROW, and
# its text is a design name, not an instance). That is not a defect to be
# papered over with a default: it is the fact that makes passing
# `browser_root_id` LOAD-BEARING at every call site, and BX50's D6 snapshot
# control is the same fact on the real viewer.
set bx_rrows [wviewer::browser_rows [list \
  [wviewer::signal_entry {v(x1.x2.net5)}] \
  [wviewer::signal_entry {v(out)}]] bx_root]
set bx_rid0 [pcall ::wviewer::browser_root_id $bx_rrows]
check {BX15 (fixture) the rooted list carries `g:`; the root-less one answers {} — absence is an ANSWER} \
  [list $bx_rid0 [pcall ::wviewer::browser_root_id $bx_rows]] \
  [list {g:} {}]
check {BX15 (ITEM 8) a ROOTED list walked with NO start DEAD-ENDS — declared, not defended} \
  [pcall ::wviewer::browser_node_for $bx_rrows {x1 x2}] {{} 0}
check {BX15 ...and seeded with browser_root_id the same walk finds the same node} \
  [pcall ::wviewer::browser_node_for $bx_rrows {x1 x2} $bx_rid0] {g:x1.x2 2}

# --- BX16-BX18 (ITEM 17): THE SELECTION IS THE DIRECT OBJECT -----------------
#
# ⚠⚠ THE DEFECT, STATED AS THE THING THAT WAS ACTUALLY TRUE. Until item 17,
# `ase::show_in_browser_for_current` read `wviewer::hier_now` — that is
# `xschem get sim_sch_path`, WHERE THE WINDOW IS STANDING — and nothing else.
# Descended into x1 with x2 SELECTED it revealed `g:x1`. It did NOT "do
# nothing": it revealed the CURRENT level and filled the sea with that level's
# signals. What it ignored was the selection. A check written against "it does
# nothing" would be pinning a false premise, so this one is written against the
# true one, and BX51's NEGATIVE CONTROL is the other half of it.
#
# These legs pin the REDUCER — `ase::browser_sel_segment` — on the REAL design
# window the prologue loaded, with no viewer and no Tk anywhere near it, which
# is why they sit in the both-arms band. The three answers it can give are the
# three rulings: `ok` extends the path, `none` keeps today's behaviour, and
# `many` keeps today's behaviour AND owes the user a sentence (BX53).
pcall xschem unselect_all
check {BX16 (PRECONDITION) the prologue's design is still loaded, still at its
       TOP level, and nothing is selected — the pure band above walks synthetic
       row lists and must not have moved the design window} \
  [list [file tail [pcall xschem get schname 0]] \
        [llength [pcall ::wviewer::hier_now]] \
        [pcall xschem selected_set]] \
  [list wvhier_top.sch 0 {}]
check {BX16 (RULING 3's FALLBACK) nothing selected answers `none`, which is what
       keeps every pre-item-17 invocation answering exactly as it did} \
  [pcall ::ase::browser_sel_segment] {none}
# ⚠ THE FIXTURE'S SIX INSTANCES, ASSERTED BY NAME AND INDEX, because every leg
# below addresses them by index and a fixture edit that reordered them would
# otherwise change what these checks MEAN while leaving them green.
check {BX16 (FIXTURE) the top level's six instances, in index order — two
       spellings of the same cell (`X1`, `x1`) and the non-subcircuit `V9`} \
  [bx_inst_names] {l1 X1 V9 l2 l3 x1}
pcall xschem select instance 1
check {BX17 ONE selected instance answers `ok` and its name — the SCHEMATIC's
       own spelling, capital and all, because the browser's own walk is what
       folds case (browser_node_for's -nocase fallback) and a second folding
       here would be a second answer to one question} \
  [pcall ::ase::browser_sel_segment] {ok X1}
pcall xschem unselect_all
check {BX17 (CONTROL) ...and unselecting puts it back to `none`, so the reader
       is reading the LIVE selection and not something it cached} \
  [pcall ::ase::browser_sel_segment] {none}
# RULING 2. `X1` and `x1` are two instances of the SAME cell, so this is not a
# contrived pair: it is the case a user actually hits by rubber-banding.
pcall xschem select instance 1
pcall xschem select instance 5
check {BX18 (RULING 2) TWO selected instances answer `many` WITH THE COUNT — the
       lower pane shows ONE level, so two targets is not a question it can
       answer, and the count is what the CIW sentence needs} \
  [list [pcall ::ase::browser_sel_segment] \
        [llength [pcall xschem selected_set]]] \
  [list {many 2} 2]
# ⚠ THE `-type instance` FILTER, BEHAVIOURALLY. `xschem select_all` takes the
# wires and the text too; if the reducer counted those, this level would answer
# `many <a bigger number>` — or `ok` on a WIRE at a level with one instance,
# which would put a net name into a hierarchy path.
pcall xschem unselect_all
pcall xschem select_all
check {BX18 (THE -type FILTER) select-all selects more OBJECTS than instances,
       and the reducer still counts only the INSTANCES} \
  [list [pcall ::ase::browser_sel_segment] \
        [expr {[llength [pcall xschem objects -selected]] >
               [llength [pcall xschem objects -type instance -selected]]}]] \
  [list {many 6} 1]
pcall xschem unselect_all
check {BX18 (RESTORE) the selection is clear again, so BX20 onward starts where
       it always did} \
  [list [pcall xschem selected_set] [pcall ::ase::browser_sel_segment]] \
  [list {} none]

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
  # THE TREE'S ITEM COUNT, as a value that CANNOT throw — used at BX32, where 63
  # ids would be unreadable. `no-tree` and `empty` are kept DISTINCT from a
  # number because they are three different facts and a bare `0` says two of
  # them at once. `bs_tree_ids` is the shared depth-first walk and returns {}
  # rather than throwing, so nothing here can blow past a check.
  proc bx_nodes {tv} {
    if {[catch {winfo exists $tv} e] || !$e} { return no-tree }
    set ids [bs_tree_ids $tv]
    if {![llength $ids]} { return empty }
    return [llength $ids]
  }
  set bx_names {v(x1.x2.net5) v(x1.y3.net7) v(out)}
  check {BX20 (FIXTURE) the sidebar built, is mapped, and the tree is seeded} \
    [list $bx_mapped [winfo exists $BXTV] [expr {[bx_seed $bx_names] > 0}]] \
    [list 1 1 1]

  # ⚠⚠ THIS FIXTURE IS DELIBERATELY THE NO-ROOT SHAPE, and saying so is what
  # stops the next reader "fixing" it. `bx_seed` calls `browser_rows` with NO
  # root argument, so the rows carry no `g:` — the All-DBs shape, and the shape
  # every pre-item-2 caller produced. THREE later checks rest on it: BX36's
  # "an EMPTY path CLEARS the selection" is browser_show_path's no-root FALLBACK
  # arm (the rooted arm selects the root, and BX45 on the real viewer is where
  # that is proven); BX30's control has to OPEN a node by hand because there is
  # no root to be the one node item 10 inserts open; BX31/BX34 walk seeded `{}`
  # and still resolve. And two-pane item 10 keeps LEAVES OUT of the tree
  # entirely, so `s:v(out)` is in `browserrows` and NOT in the widget.
  # ⚠ THE IDS, NOT A COUNT. Three top-level nodes would also count three; the
  # ids are what say `g:x1.x2` and `g:x1.y3` are still CHILDREN of `g:x1`.
  set bx_seedrows [pcall set ::wviewer::browserrows(wvbx)]
  check {BX20 (FIXTURE) no design root, NODES only, still nested — the shape BX30/BX32/BX36 rest on} \
    [list [pcall ::wviewer::browser_root_id $bx_seedrows] \
          [pcall $BXTV exists {g:}] [bs_tree_ids $BXTV] \
          [pcall $BXTV exists {s:v(out)}]] \
    [list {} 0 {g:x1 g:x1.x2 g:x1.y3} 0]

  # ⚠⚠ POSITIVE CONTROL #1, and without it every "not visible" claim below is
  # worthless: prove this very node can be put into BOTH `collapsed` AND
  # `visible`, so the two are known to be distinguishable HERE.
  #
  # ⚠ RESTATED BY TWO-PANE ITEM 10 (R1/M11): the DIRECTION of the gesture moved,
  # not the claim. `browser_populate` used to insert every group `-open 1`, so a
  # fresh tree read `visible` and this control CLOSED a node to reach
  # `collapsed`. Item 10 inserts nodes `-open 0` — collapsed by default is the
  # ruling — and opens exactly one exception, `browser_root_id $rows`, which
  # this fixture does not have (BX20's fixture leg). So the fresh tree reads
  # `collapsed` and the control OPENS a node to reach `visible`. Both values,
  # same node, same block.
  # ⚠ AND IT ENDS WHERE IT BEGAN — g:x1 closed, selection empty — because BX31
  # below proves `see` RE-OPENED a collapsed ancestor and is worthless if the
  # ancestor was open on entry.
  check {BX30 (POSITIVE CONTROL) item 10's freshly populated tree is COLLAPSED} \
    [bx_vis $BXTV g:x1.x2] collapsed
  pcall $BXTV item g:x1 -open 1
  update
  check {BX30 (POSITIVE CONTROL) OPENING the ancestor reads `visible` — same node, other value} \
    [list [pcall $BXTV item g:x1 -open] [bx_vis $BXTV g:x1.x2]] [list 1 visible]
  pcall $BXTV item g:x1 -open 0
  pcall $BXTV selection set {}
  update
  check {BX30 (POSITIVE CONTROL) collapsing it again reads `collapsed`, selection empty} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV selection]] [list collapsed {}]

  # THE ITEM, on the HIT path (sidebar already shown, node present) — so no
  # repopulate can intervene and erase the evidence.
  check {BX31 browser_show_path returns ok with the exact node} \
    [pcall ::wviewer::browser_show_path wvbx x1.x2] {ok g:x1.x2 x1.x2}
  update
  check {BX31 ...the node is SELECTED} [pcall $BXTV selection] {g:x1.x2}
  # ⚠ SABOTAGE (a)'s TARGET. `selection` above stays GREEN under it — that is
  # the built-in control that excludes "the command did nothing".
  #
  # ⚠⚠ RESTATED BY TWO-PANE ITEM 13, WITH A THIRD LEG. The first two legs are
  # unchanged and still say what they always said: `see` re-opened the COLLAPSED
  # ANCESTOR (`g:x1`), which is the whole reason the node is on screen. What
  # item 13 adds is the other half of the same sentence — the TARGET ITSELF is
  # left CLOSED, because R3 makes the LOWER pane the answer to "what is inside
  # this node". That leg read `1` before item 13 landed, so it is this file's
  # red-first witness and the cross-file twin of BW68 (leg 5) in
  # test_wave_sigbrowser_panes.tcl.
  #
  # ⚠ THE PLAN PRESCRIBED A DIFFERENT LEG — `[$BXTV item {g:} -open]` — AND IT
  # IS IMPOSSIBLE ON THIS FIXTURE. BX20 above asserts `$BXTV exists {g:}` == 0:
  # `bx_seed` calls `browser_rows` with NO root argument on purpose, so there is
  # no `g:` row to read an `-open` from. The ancestor leg already there IS the
  # claim the PLAN was reaching for.
  check {BX31 ...and it is VISIBLE: `see` re-opened the COLLAPSED ANCESTOR —
         while TWO-PANE item 13 leaves the TARGET ITSELF CLOSED (R3: the lower
         pane is the answer to "what is inside")} \
    [list [bx_vis $BXTV g:x1.x2] [pcall $BXTV item g:x1 -open] \
          [pcall $BXTV item {g:x1.x2} -open]] [list visible 1 0]

  # THE SCROLL LEG — a node whose ancestors are ALL open and which is still not
  # on screen. `collapsed` cannot see this one; only the bbox can.
  # ⚠⚠ THE FILL MINTS NODES, NOT SIGNALS, AND THAT IS TWO-PANE ITEM 10's DOING.
  # The old fill was 60 FLAT names (`v(zz0)`..`v(zz59)`), which mint LEAF rows —
  # and item 10 keeps leaves OUT of the tree (they belong to the lower pane from
  # item 11 on). With that fill the widget held THREE items, `yview moveto 1.0`
  # scrolled nothing, and this control read `visible`: the `offscreen` state it
  # exists to prove had become unreachable, so restating its expectation would
  # have left a green check covering nothing. One dot per name fixes it —
  # `v(zz0.n)` is two segments, so sig_declass passes it through untouched and
  # sig_split gives path `zz0`, minting the TOP-LEVEL GROUP `g:zz0` (plus a leaf
  # the tree drops). 60 of them put 63 NODES in the widget.
  # ⚠ WHY 63 IS ENOUGH: the tree pane lives inside a 900x400 toplevel, i.e. at
  # most ~20 rows tall, so a 63-row tree scrolled to its end cannot be showing
  # its second row. If this ever reads `visible` the pane grew — a LOUD failure
  # with the 63-item leg right beside it naming the cause, not a silent one.
  set bx_fill {}
  for {set bx_i 0} {$bx_i < 60} {incr bx_i} { lappend bx_fill "v(zz${bx_i}.n)" }
  bx_seed [concat $bx_names $bx_fill]
  # ⚠ THE ANCESTOR IS OPENED ON PURPOSE, not inherited. `offscreen` requires
  # every ancestor OPEN; item 10 inserts nodes `-open 0` and only CARRIES the
  # previously-open set across a repopulate, so leaning on BX31's `see` to have
  # left g:x1 open would make this control depend on a different item's rule.
  # The flag is still ASSERTED below — it is the precondition the `offscreen`
  # verdict rests on, and reading it back is what stops a silent revert.
  pcall $BXTV item g:x1 -open 1
  update
  pcall $BXTV yview moveto 1.0
  pcall $BXTV selection set {}
  update
  check {BX32 (control) the fill really minted NODES — 63 items, so the scroll has something to do} \
    [bx_nodes $BXTV] 63
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

    # ⚠⚠ RESTATED BY TWO-PANE ITEM 10, AND THE OLD RATIONALE IS NOW BACKWARDS.
    # It used to read "THE FIRST INVOKE CANNOT PROVE THE EXPANSION", and it was
    # true: un-hiding the sidebar repopulates, `browser_populate` inserted every
    # group `-open 1`, and the node was visible whether or not anything expanded
    # it — sabotage (a) (delete `$tv see`) left the leg above GREEN. Item 10
    # INVERTED that. The first populate of an empty tree opens exactly ONE node,
    # the design root (browser_populate's `$first`/`$rootid` branch); `g:x1` is
    # born `-open 0`, so the `visible` verdict above ALREADY rests on `see`.
    # THE SECOND INVOKE IS KEPT, and its claim is the different one it was
    # always also making: with the sidebar ALREADY SHOWN,
    # `ase::show_in_browser_for_current` skips its `browser_toggle`, so NO
    # repopulate runs at all and the reveal is the only thing that can re-open a
    # hand-collapsed ancestor.
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
        [list 1 {Ctrl+Alt+V} {ase::show_in_browser_for_current .drw}]
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
    # ⚠⚠ POSITIVE CONTROL. Two things it pins, both needed to READ the leg below.
    # (1) THE TOP LEVEL IS ONE ROOT. R2's single `g:` is what `g:` MEANS here,
    # and it is also the precondition of the branch under test: with no root row
    # browser_show_path takes its legacy CLEAR arm and the leg would red without
    # ever saying which half was wrong.
    # (2) THE PRE-STATE IS A NON-ROOT NODE THAT STILL EXISTS, so the three
    # outcomes are distinguishable: a command that bailed early leaves
    # `g:x1.x2`, a reverted sim-root branch clears to `{}`, and only the branch
    # under test leaves `g:`.
    # ⚠ NOTE WHAT DOES NOT HAPPEN HERE, because it is what keeps the leg clean:
    # the sidebar is ALREADY shown, so ase::show_in_browser_for_current skips
    # `browser_toggle` and NO browser_show / repopulate runs; browsersigs is
    # non-empty, so browser_show_path takes no reload either. Nothing but the
    # sim-root branch can move this selection.
    check {BX45 (control) ONE top-level root, and a NON-root node selected going in} \
      [list [pcall $BXVTV children {}] [pcall $BXVTV selection]] \
      [list {g:} {g:x1.x2}]
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    # ⚠ RESTATED BY TWO-PANE ITEM 10 (R4), NAME AND ALL. It used to read "the
    # selection is cleared" — which WAS the behaviour while the tree's top level
    # was a forest of instances with no row meaning "the whole design". Item 10
    # gives the tree exactly such a row and forbids an empty selection, so the
    # sim root now SELECTS it. The claim is unchanged in substance (the sim top
    # is an ANSWER, not a failure, and it is reported); only the value the answer
    # leaves behind moved, so the NAME moved with it rather than staying a lie
    # that happens to be green.
    check {BX45 at the sim top the DESIGN ROOT is selected (R4) and the reason given} \
      [list [pcall $BXVTV selection] \
            [pcall $bx_vtop.wvbrowser.ph cget -text]] \
      [list {g:} "Signal Browser\nshowing the simulation top level"]
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
    # ⚠ THE WALK IS SEEDED WITH THE DESIGN ROOT, and that is item 8's `start`
    # argument, not a workaround: two-pane item 2 gave the row list a `g:` root,
    # every real instance hangs off it, and browser_show_path passes exactly this
    # seed. A walk left on the default `{}` would answer 0 here BEFORE the reload
    # and 0 AFTER it — green either way, i.e. a control that controls nothing.
    # The bare-start fact is pinned as a value in BX15, where no reload exists to
    # make it ambiguous.
    set bx_rows_b [pcall set ::wviewer::browserrows($bx_tok)]
    set bx_rid [pcall ::wviewer::browser_root_id $bx_rows_b]
    check {BX50 (control) the snapshot really carries item 2's design root to walk from} \
      [list [string equal $bx_rid {g:}] [pcall $BXVTV exists {g:}]] [list 1 1]
    check {BX50 (control) the browser has NOT seen the new signal yet (D6 snapshot)} \
      [lindex [pcall ::wviewer::browser_node_for $bx_rows_b {x1 x2 x7} $bx_rid] 1] 2
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
    check {BX46 (control) the selection really is EMPTY before the command runs} \
      [pcall $BXVTV selection] {}
    pcall ase::show_in_browser_for_current $bx_dwin
    update
    check {BX46 with no raw loaded it says so rather than doing nothing} \
      [pcall $bx_vtop.wvbrowser.ph cget -text] \
      "Signal Browser\nno simulation data loaded - read a raw file first"
    # ⚠ RESTATED BY TWO-PANE ITEM 10 (R2 + R4). "Nothing is selected" was the old
    # shape of "the sidebar is untouched". Item 10 forbids an empty selection,
    # and the inventory unset above makes browser_show_path spend its ONE
    # empty-inventory reload (NOT browser_show, which is skipped here because the
    # sidebar is already shown). That reload rebuilds the tree from an EMPTY
    # inventory, which browser_rows still gives a design root, because
    # browser_root_label's floor is the literal `design` once browser_reload has
    # captured an empty raw path. So the honest report leaves a ONE-NODE tree
    # with that root selected, and only THEN does the second guard speak. Claim
    # kept: the command SPOKE and did not re-hide the sidebar. Claim gained: R4
    # holds on the degenerate path too.
    # ⚠ THE `design` TEXT IS THE DISCRIMINATOR. A reload that had bailed would
    # leave the OLD tree standing, root and all, named `bx_item12` — the text is
    # the only element that can tell a real rebuild from a no-op.
    check {BX46 ...the emptied tree is ONE `design` root, selected (R4), sidebar still shown} \
      [list [pcall $BXVTV children {}] [pcall $BXVTV item {g:} -text] \
            [pcall $BXVTV selection] [pcall ::wviewer::browser_shown $bx_tok] \
            [bs_packed $bx_vtop.wvbrowser]] \
      [list {g:} design {g:} 1 1]
    bx_ctx_to $bx_dwin

    # ==== BX43: THE REAL KEY, on the REAL design canvas ====
    #
    # ⚠⚠ RETARGETED BY TWO-PANE ITEM 17b, AND THE HAND-INSTALLED BIND IS GONE.
    # Item 12 bound `.drw <Control-Key-5>` HERE, verbatim from the rc (the
    # test_cadence_window_hop_log idiom), because the chord lived in a profile
    # file the suite must not source. That made this check GREEN NO MATTER WHAT
    # THE TOOL SHIPPED — it drove a binding the TEST had installed. Item 17b
    # moves the chord into the C action registry, so the tool owns it and the
    # test must not: no `bind` here, and the drive goes through the shipped
    # binding table or not at all. (Two-pane item 16 caught the identical shape
    # at BS46.)
    #
    # ⚠⚠ `<Control-Alt-Key-v>` DOES NOT WORK UNDER `event generate` AND WOULD
    # FAIL ON CORRECT CODE. MEASURED with a %s spy under Tk 8.6.14: Tk's `Alt`
    # PATTERN modifier is the virtual META bit (1<<17), so
    # `<Control-Alt-Key-v>` delivers state 131076, not 12. `<Control-Mod1-Key-v>`
    # delivers 12, which is ControlMask|Mod1Mask — what the C row matches, and
    # what a physical Alt sets on a real keyboard.
    set ::bx_calls 0
    rename ::ase::show_in_browser_for_current ::ase::__bx_real
    proc ::ase::show_in_browser_for_current {{win {}}} {
      incr ::bx_calls
      return [uplevel 1 [list ::ase::__bx_real $win]]
    }
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
    if {![send_key .drw <Control-Mod1-Key-v> {$::bx_calls > $bx_c0}]} {
      puts "SKIPPED: BX43 (WSLg key-delivery stall on the design canvas)"
    } else {
      update
      check {BX43 a REAL Ctrl-Alt-V on the design canvas targets the browser at x1.x2} \
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

    # ==== BX54-BX55 (TWO-PANE ITEM 17b): the chord is the C REGISTRY's ========
    #
    # ⚠ BX43 above rides `event generate`, which stalls ~1-in-5 under WSLg and
    # therefore SELF-SKIPS. These two drive `xschem callback` numerically, so
    # they are deterministic and are the item's HARD behavioural oracles.
    # Signature: <win> <event=2 KeyPress> <x> <y> <keysym> <button> <aux> <state>.
    proc bx_drive_cav {st} {
      bx_ctx_to $::bx_dwin_g
      catch {xschem unselect_all}
      pcall $::BXVTV_g selection set {}
      update
      set c0 $::bx_calls
      catch {xschem callback $::bx_dwin_g 2 100 100 118 0 0 $st}
      update
      bx_ctx_to $::bx_dwin_g
      return [expr {$::bx_calls - $c0}]
    }
    set ::bx_dwin_g $bx_dwin
    set ::BXVTV_g   $BXVTV
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    set bx_n12 [bx_drive_cav 12]
    set bx_sel12 [pcall $BXVTV selection]
    # ⚠⚠ THE NEAR-MISS STATES WERE CHOSEN BY MEASUREMENT, AND THE OBVIOUS ONES
    # ARE BOOBY-TRAPPED. `handle_key_press` looks a printable keysym up under
    # `rstate`, which is `state & ~ShiftMask` (callback.c: "rstate does not have
    # ShiftMask bit"), and `case 'v'` in the C switch owns THREE of the four
    # low states for this keysym:
    #   state 4  (Ctrl)        -> clipboard PASTE, `merge_file(2,".sch")`
    #   state 5  (Ctrl+Shift)  -> Shift is STRIPPED, so it is state 4 again
    #   state 8  (Alt)         -> vertical flip in place; with nothing selected
    #                             it ARMS a click-to-flip prompt in ui_state
    # A first cut of this check drove 8 and 5. The 5 became a paste, whose file
    # dialog is MODAL, and the whole file hung ten minutes into the run with a
    # `go_back` waiting behind it. Do not "tidy" these back.
    #
    # ⚠ STATE 13 (Ctrl+Alt+Shift) IS EXPECTED TO **FIRE**, and that is the same
    # rule seen from the other side: Shift is stripped to 12. It is not a
    # reachable chord in practice — a shifted v arrives as keysym 86 ('V'), not
    # 118 — so this leg documents the stripping rather than asserting a refusal.
    # State 68 (Ctrl+Super) is the genuine near-miss: the right shape, the wrong
    # modifier, no `case 'v'` arm, and NOT equal to the bound 12.
    #
    # ⚠ NOT ASSERTED, AND SAY SO RATHER THAN GUESS: a state-28 (Ctrl+Alt+NumLock)
    # drive was tried here and recorded ONE call on the spy. By reading, it should
    # record zero — `key_chord_has_binding` compares mods for EQUALITY and 28 != 12
    # — and nothing in callback.c strips Mod2Mask. The discrepancy was NOT
    # attributed inside this item's budget, so the leg is left OUT instead of
    # being pinned to a number nobody can explain. See 17b_receipt's declared
    # limits; whoever settles it owns the leg.
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    set bx_n13 [bx_drive_cav 13]
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    set bx_n68 [bx_drive_cav 68]
    bx_ctx_to $bx_dwin
    check {BX54 (X, THE BEHAVIOUR) a Ctrl-Alt-V through the REAL dispatcher runs
           the command once and lands the browser on x1.x2; Ctrl-Alt-Shift-v is
           the SAME chord (Shift is stripped for printable keysyms) and fires
           too; Ctrl-Super-v — the right shape, the wrong modifier — does not} \
      [list $bx_n12 $bx_sel12 $bx_n13 $bx_n68] \
      [list 1 {g:x1.x2} 1 0]

    # ---- BX55: R10's WHOLE POINT, behaviourally. -----------------------------
    # An rc `bind` and a C registry row are INDISTINGUISHABLE through BX54. Only
    # the un-bind can tell them apart, and only a registry row can be un-bound.
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    set bx_r0 [bx_drive_cav 12]
    pcall xschem unbind key 118 ctrl+alt canvas
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    set bx_r1 [bx_drive_cav 12]
    pcall xschem bind key 118 ctrl+alt canvas wave.show_in_signal_browser
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1.X2
    set bx_r2 [bx_drive_cav 12]
    check {BX55 (X, REMAPPABILITY) the chord is the BINDING TABLE's, not a Tk
           bind: unbind it and the same drive does nothing; rebind it and it
           works again} \
      [list $bx_r0 $bx_r1 $bx_r2] [list 1 0 1]

    catch {bind .drw <Control-Key-5> {}}
    rename ::ase::show_in_browser_for_current {}
    rename ::ase::__bx_real ::ase::show_in_browser_for_current
    check {BX43 the real ase::show_in_browser_for_current is back in place} \
      [list [expr {[info commands ::ase::__bx_real] eq {}}] \
            [expr {[info commands ::ase::show_in_browser_for_current] ne {}}]] \
      [list 1 1]

    # ==== BX51-BX53 (ITEM 17): THE SELECTION IS THE DIRECT OBJECT ===========
    #
    # ⚠ THE CIW CAPTURE, INSTALLED HERE AND REMOVED AT THE END OF THE BLOCK.
    # `ase::echo` writes its message to `::ciw_echo` first, unconditionally
    # (ase.tcl:117-118 says so and names this as the way tests capture ASE
    # notices), so renaming it is the supported hook rather than a reach-in. It
    # is NOT installed file-wide: BX42/BX45/BX47 assert what the command SAYS
    # through other surfaces, and a global rename would silently change what
    # those are reading.
    set ::bx_said {}
    set ::bx_had_ciw [expr {[info commands ::ciw_echo] ne {}}]
    if {$::bx_had_ciw} { rename ::ciw_echo ::__bx_real_ciw }
    proc ::ciw_echo {args} { append ::bx_said [lindex $args 0] "\n" }
    #
    # ⚠⚠ THE DRIVER'S OWN CASE, VERBATIM: "descend to x1 and now, within x1, the
    # user has selected x2 and issues this command — it should expand this
    # instance in the hierarchy navigator so that the signals at the x1.x2 level
    # are visible in the signal pane. It should not be necessary to descend."
    #
    # The fixture is unusually well suited and that is not luck — item 11 built
    # it to carry exactly these shapes: `wvhier_top` holds `X1` AND `x1` (two
    # instances of the same cell, RULING 2's pair) plus the non-subcircuit `V9`
    # (RULING 1's), and `wvhier_mid` holds `X2`.
    bx_ctx_to $bx_dwin
    pcall xschem unselect_all
    pcall ::wviewer::hier_walk X1
    pcall $BXVTV selection set {}
    catch {$BXVTV item {g:x1} -open 0}
    update
    check {BX51 (PRECONDITION) the design window is descended to X1 with NOTHING
           selected, the browser's selection is cleared and g:x1 is COLLAPSED —
           so nothing below can be true of the state it started in} \
      [list [pcall xschem get sim_sch_path] [pcall xschem selected_set] \
            [pcall $BXVTV selection] [pcall $BXVTV item {g:x1} -open]] \
      [list {X1.} {} {} 0]
    # ⚠ THE NEGATIVE CONTROL COMES FIRST, deliberately. It is what makes the
    # positive leg below mean "the SELECTION moved it" rather than "something
    # moved it": same position, same command, one difference.
    set bx_s0 [pcall ase::show_in_browser_for_current $bx_dwin]
    update
    check {BX51 (NEGATIVE CONTROL) with NOTHING selected the command still lands
           on the descend level, exactly as it did before item 17 — the
           selection is an EXTENSION of the answer, never a replacement for it} \
      [list $bx_s0 [pcall $BXVTV selection]] [list $bx_tok {g:x1}]
    # ...now the same command, from the same place, with X2 selected.
    bx_ctx_to $bx_dwin
    pcall xschem select instance 1
    # ⚠ `lindex`, not the bare list: `xschem selected_set` BRACE-QUOTES every
    # name (scheduler.c:10779), so a one-element answer has the string rep
    # `{X2}` and comparing it to `X2` fails on correct code — this file's own
    # string-rep warning, one layer down.
    check {BX51 (PRECONDITION) `X2` is what is selected, and the window has NOT
           descended into it — that is the whole point of the item} \
      [list [llength [pcall xschem selected_set]] \
            [lindex [pcall xschem selected_set] 0] \
            [pcall xschem get sim_sch_path]] \
      [list 1 {X2} {X1.}]
    set bx_s1 [pcall ase::show_in_browser_for_current $bx_dwin]
    update
    check {BX51 (THE DRIVER'S OWN CASE) selecting X2 one level up reveals
           g:x1.x2 — the raw's lowercase node, found through browser_node_for's
           -nocase fallback — with its ancestors open and ON SCREEN} \
      [list $bx_s1 [pcall $BXVTV selection] [bx_vis_m $BXVTV g:x1.x2]] \
      [list $bx_tok {g:x1.x2} visible]
    check {BX51 ...and the LOWER PANE is showing that level's own signals, which
           is what the user asked for — not x1's} \
      [bs_sea_labels $bx_vtop.wvbrowser.pw.sea.c] {net5}
    # ⚠ THE CONTEXT SWITCH IS REQUIRED, and forgetting it is how this leg first
    # read `{} {}` and looked like a real defect: the command LEAVES THE CONTEXT
    # ON THE VIEWER (BX42 pins that as declared behaviour), so a design-window
    # question asked without switching back is answered by the viewer's own
    # untitled buffer.
    bx_ctx_to $bx_dwin
    check {BX51 (DECLARED) the DESIGN window never descended: still at X1, with
           X2 still merely SELECTED} \
      [list [pcall xschem get sim_sch_path] \
            [lindex [pcall xschem selected_set] 0]] \
      [list {X1.} {X2}]

    # ==== BX52 (RULING 1): a NON-HIERARCHICAL selection lands on the parent ==
    #
    # ⚠ `V9` is a voltage source. It has no level in the simulation data, so the
    # extended path cannot resolve — and the ruling is that this LANDS ON THE
    # PARENT AND SAYS SO rather than erroring or silently ignoring the pick.
    # Driven at the TOP level on purpose: that is the case `browser_show_path`
    # alone gets WRONG. With no ancestor segment to fall back on, `matched` is 0
    # and its answer is `err` with the selection untouched — so item 17 owes the
    # retry, and this check is what says so.
    bx_ctx_to $bx_dwin
    pcall xschem unselect_all
    pcall ::wviewer::hier_walk {}
    pcall $BXVTV selection set {}
    update
    check {BX52 (PRECONDITION) back at the top level with a cleared browser} \
      [list [pcall xschem get sim_sch_path] [pcall $BXVTV selection]] \
      [list {} {}]
    pcall xschem select instance 2
    set ::bx_said {}
    set bx_s2 [pcall ase::show_in_browser_for_current $bx_dwin]
    update
    set bx_selv9 [list]
    bx_ctx_to $bx_dwin
    set bx_selv9 [lindex [pcall xschem selected_set] 0]
    check {BX52 (RULING 1) with the non-subcircuit `V9` selected the command
           lands on the PARENT — here the design root, because the parent of a
           top-level pick is the design — instead of refusing} \
      [list $bx_selv9 $bx_s2 [pcall $BXVTV selection]] \
      [list {V9} $bx_tok {g:}]
    check {BX52 (RULING 1, "SAY SO") ...and the user is TOLD, by name, that the
           thing they picked has no level and what was shown instead} \
      [list [expr {[string first {V9} $::bx_said] >= 0}] \
            [expr {[string first {no level in the simulation data} $::bx_said] >= 0}]] \
      [list 1 1]

    # ==== BX53 (RULING 2): TWO selected -> the descend level, and a comment ==
    bx_ctx_to $bx_dwin
    pcall xschem unselect_all
    pcall ::wviewer::hier_walk {}
    pcall $BXVTV selection set {}
    set ::bx_said {}
    pcall xschem select instance 1
    pcall xschem select instance 5
    update
    check {BX53 (PRECONDITION) both spellings of the same cell are selected} \
      [pcall xschem selected_set] {{X1} {x1}}
    set bx_s3 [pcall ase::show_in_browser_for_current $bx_dwin]
    update
    check {BX53 (RULING 2) two selected instances do NOT pick a winner — the
           answer is the DESCEND LEVEL's, which at the top is the design root} \
      [list $bx_s3 [pcall $BXVTV selection]] [list $bx_tok {g:}]
    # ⚠ THE SENTENCE MUST NAME BOTH HALVES. "2 instances are selected" alone is
    # a fact the user can see; what they cannot see is what the tool DID with
    # it. A notice that reports only the ambiguity is a warning nobody can act
    # on, so both legs are asserted separately.
    check {BX53 (RULING 2, THE CIW COMMENT) the CIW is told BOTH the ambiguity
           AND the action taken — the count, and that the selection was ignored
           in favour of the hierarchy position} \
      [list [expr {[string first {2 instances} $::bx_said] >= 0}] \
            [expr {[string first {ignoring the selection} $::bx_said] >= 0}]] \
      [list 1 1]
    check {BX53 (NOT AN ERROR) it is a COMMENT, not a failure — the command
           still answers with the session key, which is how a caller tells a
           refusal from a fallback} \
      [expr {$bx_s3 ne {}}] 1
    bx_ctx_to $bx_dwin
    pcall xschem unselect_all
    # ⚠ RESTORE WHAT WAS CHANGED (the named-helper rule). BX47 below reads the
    # command's decline through the ordinary channels; leaving the capture
    # installed would swallow its notice.
    catch {rename ::ciw_echo {}}
    if {$::bx_had_ciw} { catch {rename ::__bx_real_ciw ::ciw_echo} }
    check {BX53 (RESTORE) the real ciw_echo is back and the stand-in is gone} \
      [list [expr {[info commands ::ciw_echo] ne {}}] \
            [expr {[info commands ::__bx_real_ciw] eq {}}]] \
      [list $::bx_had_ciw 1]

    # ==== BX56 (TWO-PANE ITEM 17b): the SELECTION ARM rides the NEW chord ====
    #
    # ⚠ NOT A DUPLICATE OF BX51. BX51 calls `ase::show_in_browser_for_current`
    # DIRECTLY, with the window argument. This drives the chord through the C
    # dispatcher, which runs a CONSTANT string with NO argument — so it is the
    # only check that can show item 17's selection arm still reaching the
    # `{win {}}` (current-context) arm of the same command. Both legs on one
    # fixture: nothing selected -> the descend level; ONE instance selected ->
    # that instance's level.
    bx_ctx_to $bx_dwin
    pcall xschem unselect_all
    pcall ::wviewer::hier_walk X1
    pcall $BXVTV selection set {}
    update
    catch {xschem callback $bx_dwin 2 100 100 118 0 0 12}
    update
    set bx_k0 [pcall $BXVTV selection]
    bx_ctx_to $bx_dwin
    pcall ::wviewer::hier_walk X1
    pcall $BXVTV selection set {}
    pcall xschem select instance 1
    set bx_ksel [lindex [pcall xschem selected_set] 0]
    update
    catch {xschem callback $bx_dwin 2 100 100 118 0 0 12}
    update
    set bx_k1 [pcall $BXVTV selection]
    bx_ctx_to $bx_dwin
    check {BX56 (X) the new chord carries item 17's selection arm: nothing
           selected lands on the descend level, ONE selected `X2` lands on
           x1.x2 — SAME fixture, SAME gesture, one difference} \
      [list $bx_k0 $bx_ksel $bx_k1] [list {g:x1} {X2} {g:x1.x2}]
    bx_ctx_to $bx_dwin
    pcall xschem unselect_all

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
