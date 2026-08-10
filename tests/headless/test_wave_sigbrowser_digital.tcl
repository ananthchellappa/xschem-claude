# tests/headless/test_wave_sigbrowser_digital.tcl — §F items F1 and F5 of
# doc/claude/specs/mixed_signal_signal_browser.md, THE VIEWER HALF.
#
# Ctrl-Alt-V on a code block scopes the Signal Browser to that instance's
# DIGITAL database (F1), and when there is no digital data to show it says WHY
# instead of leaving a blank pane (F5).
#
# ⚠⚠ WHY THIS FILE EXISTS SEPARATELY FROM test_ase_cosim.tcl's FV GROUP. FV
# proves the BRANCH — which cell enters it, which sentence each cause produces,
# and that the design is read before the viewer is raised — and every one of
# those claims is pure Tcl, so FV lives in the `--nogui` arm where it can never
# be killed by a display. What FV cannot reach is the other half: a treeview, a
# checkbutton, a canvas and a status label. `wviewer::browser_show_db_scope` and
# `wviewer::browser_notice` touch all four, so a green `--nogui` run proves
# NOTHING about them. That is this file, and it is Tk/X only by construction.
#
# GROUP PREFIX: `FD`, never reused (FV is the engine-arm twin in
# test_ase_cosim.tcl).
#
# ⚠ SKIP-BANNER WORDING IS LOAD-BEARING. The X-gated group prints
# `SKIPPED: <group> (Tk/X arm only)`. NEVER `RESULT: SKIP`, never
# `skipped: no X`, never `SKIP: no X connection` — full_audit.sh's `is_skip`
# matches those three strings and would score the WHOLE FILE as SKIP, silently
# discarding every check that did run.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_sigbrowser_digital.tcl

set ::wvbs_tag  wvsigbrowser_digital
set ::wvbs_name test_wave_sigbrowser_digital
source [file join [file dirname [info script]] wvbs_common.tcl]

proc fd_wr {path body} {
  file mkdir [file dirname $path]
  set fp [::open $path w]; puts -nonewline $fp $body; ::close $fp
}

# the mkraw/mkvcd idiom of test_ase_cosim.tcl — a valid ASCII ngspice raw and a
# valid VCD in fifteen lines each, so this file runs no simulator.
proc fd_mkraw {path} {
  set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n0\t0.0\n\t0.0\n\n1\t1e-09\n\t1.0\n\n2\t2e-09\n\t0.5\n\n"
  fd_wr $path $body
}
proc fd_mkvcd {path} {
  fd_wr $path "\$timescale 1ps \$end
\$scope module TOP \$end
 \$scope module m \$end
  \$var wire 1 ! siga \$end
  \$var wire 1 # sigb \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
0#
#100
1!
1#
#200
"
}

# --- source-arm checks (BOTH arms) -------------------------------------------
# The formatter rule this file's X arm then exercises: the eleventh outcome
# sentence is spelled in browser_msg and NOWHERE else, exactly as the tenth is.
check {FD01 (SOURCE) the digital branch's outcome sentence is spelled once, in
       the one formatter} \
  [list [regexp -all {every results database to reach} $wsrc] \
        [regexp -all {every results database to reach} \
           [wvproc_body $wsrc wviewer::browser_msg]]] \
  [list 1 1]
# ⚠ THE NOTICE IS A RENDERER: it must not know any cause. A `switch` on a code
# inside it would be a second author of F5's sentence, free to drift from the
# resolver's (RULING 5f-3).
check {FD02 (SOURCE) browser_notice composes nothing — no cause code, no switch} \
  [regexp -all {nomap|notraced|notloaded|noscope|switch} \
     [wvproc_body $wsrc wviewer::browser_notice]] 0
# and the notice's lifetime: set in one place, cleared in one place
check {FD03 (SOURCE) the notice is cleared by the sea refresh and set by the
       notice writer, one site each} \
  [list [regexp -all {set browserseanote\(\$token\) \{\}} \
           [wvproc_body $wsrc wviewer::browser_sea_refresh]] \
        [regexp -all {set browserseanote\(\$token\) \$msg} \
           [wvproc_body $wsrc wviewer::browser_notice]] \
        [regexp -all {browserseanote} [wvproc_body $wsrc wviewer::browser_sea_draw]]] \
  [list 1 1 4]

# =============================================================================
# FD10-FD29 — THE REAL VIEWER, THE REAL TREE, A REAL SECOND DATABASE. Tk/X only.
# The session fixture is test_wave_sigbrowser_i14.tcl's BD40 recipe verbatim.
# =============================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set fd_raw [file join $scratch fd_anlg.raw]
  set fd_vcd [file join $scratch fd_dig.vcd]
  fd_mkraw $fd_raw
  fd_mkvcd $fd_vcd

  set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
  set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
  set f [::open [file join $scratch library.defs] w]
  puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
  puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
  puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
  ::close $f
  set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
  set ::library_registry_defs_only 1
  set ::XSCHEM_LIBRARY_PATH {}

  if {![file isfile $statefile]} {
    puts "SKIPPED: group FD1x (the sky130A session fixture is absent)"
  } else {
  set st [ase::state_load $statefile]
  dict set st rundir [file join $scratch run]
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate

  check {FD10 (FIXTURE) wviewer::open returns 1} [pcall ::wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: group FD1x (viewer canvas never mapped)"
    catch {wviewer::close $tok}
  } else {

  set FDV $vtop.wvbrowser
  set FDB $FDV.wvsearch
  check {FD10 (FIXTURE) the sidebar toggles on and the tree is real} \
    [list [pcall ::wviewer::browser_toggle 1 $tok] [winfo exists $FDV.pw.tvf.tv]] \
    [list 1 1]
  update
  # ⚠ THE PRODUCT'S OWN ATTACH PATH, `ase::attach_dbs` (§E's E3), NOT
  # `rawbar_load`: the raw bar reads a file as SPICE, and a VCD handed to the
  # spice parser is not a database. E3 reads the analog raw first, then each
  # VCD, then switches back — so the VCD really is a FOREIGN slot here, which is
  # the arrangement the branch has to survive.
  wviewer::switch_ctx $tok
  set fd_at [pcall ase::attach_dbs $fd_raw tran [list $fd_vcd]]
  check {FD11 (FIXTURE) both databases attach, the analog one current} \
    [list [wviewer::dget $fd_at n NONE] [pcall xschem raw rawfile]] [list 2 $fd_raw]
  set fd_cur [pcall xschem raw rawfile]
  wviewer::browser_refresh $tok 1
  update
  check {FD11b (FIXTURE) the analog DB is current and the VCD is a FOREIGN slot} \
    [list $fd_cur [llength $::wviewer::browserdbsigs($tok)] \
          [wviewer::dget [lindex $::wviewer::browserdbsigs($tok) 0] path {}]] \
    [list $fd_raw 1 $fd_vcd]
  # ...and the scope box is OFF, which is what makes the next check a real one:
  # with it off, the VCD's rows are not in the tree at all.
  check {FD12 (FIXTURE) the All-DBs box starts OFF and the VCD has no rows} \
    [list $::wviewer::sballdb($FDB) \
          [pcall ::wviewer::browser_rows_headered $::wviewer::browserrows($tok)]] \
    [list 0 0]

  # --- F1: THE DIGITAL SCOPE IS SHOWN --------------------------------------
  lassign [pcall ::wviewer::browser_db_group_id $tok $fd_vcd] fd_gid fd_iscur
  set fd_r [pcall ::wviewer::browser_show_db_scope $tok $fd_vcd TOP.m]
  update
  check {FD13 (F1) the scope resolves to a row in the VCD's own subtree, and the
         result says the tree was re-scoped to reach it} \
    [list $fd_iscur $fd_r] [list 0 [list alldbs "$fd_gid|g:TOP.m" TOP.m]]
  check {FD14 (F1) the tree SELECTION is that row and the row belongs to the
         VCD's registry slot, not to the analog raw} \
    [list [$FDV.pw.tvf.tv selection] \
          "d:[pcall ::wviewer::browser_row_db [lindex [$FDV.pw.tvf.tv selection] 0]]"] \
    [list [list [lindex $fd_r 1]] $fd_gid]
  check {FD15 (F1) the landing decodes to the VCD's scope, with no database
         prefix left on it} \
    [pcall ::wviewer::browser_id_path [lindex $fd_r 1]] TOP.m
  # THE BOX WAS TICKED ON THE USER'S BEHALF, and the sentence says so — R12's
  # rule ("grew the tree without being asked, so say so"), one database over.
  check {FD16 (F1) the All-DBs box is now ON and the status line names what was
         done} \
    [list $::wviewer::sballdb($FDB) \
          [$FDV.ph cget -text]] \
    [list 1 "Signal Browser\nshowing every results database to reach TOP.m"]
  # ⚠ A SCOPE THE DATABASE DOES NOT DECLARE. Measured, and the answer is the
  # analog path's: the walk lands on the deepest ancestor that DOES exist and
  # reports `partial`, naming what was asked. That is deliberate parity — a
  # digital scope that has moved one level (RULING 5c's inlining case) should
  # leave the user inside the right database rather than nowhere.
  set fd_bad [pcall ::wviewer::browser_show_db_scope $tok $fd_vcd TOP.nosuch]
  check {FD17 (F1) a scope the database does not declare lands on its deepest
         ancestor and says which scope was asked for} \
    [list [lindex $fd_bad 0] [pcall ::wviewer::browser_id_path [lindex $fd_bad 1]] \
          [lindex $fd_bad 3]] \
    [list partial TOP TOP.nosuch]
  # ...and a first segment that matches nothing is a refusal, not a landing
  set fd_bad2 [pcall ::wviewer::browser_show_db_scope $tok $fd_vcd NOSUCH.deep]
  check {FD17b (F1) a scope whose FIRST segment misses is refused, and the
         refusal names the scope and the database} \
    [list [lindex $fd_bad2 0] \
          [expr {[string first {NOSUCH.deep} [lindex $fd_bad2 1]] >= 0}] \
          [expr {[string first {fd_dig.vcd} [lindex $fd_bad2 1]] >= 0}]] \
    [list err 1 1]
  # a database this viewer does not hold is a different refusal
  set fd_nodb [pcall ::wviewer::browser_show_db_scope $tok \
                 [file join $scratch fd_absent.vcd] TOP.m]
  check {FD18 (F1) a database the viewer does not hold is refused by name} \
    [list [lindex $fd_nodb 0] \
          [expr {[string first {fd_absent.vcd} [lindex $fd_nodb 1]] >= 0}]] \
    [list err 1]

  # --- F5: THE NOTICE, ON THE PANE THE USER IS LOOKING AT -------------------
  set fd_msg {no digital signals to show: the last run promised no VCD for 'dcell'}
  check {FD20 (F5) the notice reaches the pane's caption AND the sidebar status
         line, verbatim} \
    [list [pcall ::wviewer::browser_notice $tok $fd_msg] \
          [$FDV.pw.sea.st cget -text] [$FDV.ph cget -text]] \
    [list 1 $fd_msg "Signal Browser\n$fd_msg"]
  # THE PANE ITSELF. The canvas arm draws the sentence only when there is
  # nothing else in the pane — which is the state F5's spec row is about.
  set fd_c $FDV.pw.sea.c
  set fd_cells [llength [$fd_c find withtag cell]]
  set fd_note  [$fd_c find withtag seanote]
  check {FD21 (F5) with an empty pane the sentence is DRAWN IN THE PANE, wrapped,
         and it is the same string} \
    [list $fd_cells [llength $fd_note] \
          [expr {[llength $fd_note] ? [$fd_c itemcget [lindex $fd_note 0] -text] : {NONE}}] \
          [expr {[llength $fd_note] && [$fd_c itemcget [lindex $fd_note 0] -width] > 0}]] \
    [list 0 1 $fd_msg 1]
  # ...and it does NOT survive the next thing the user does. A stale reason on a
  # pane that has since been repopulated is worse than none.
  wviewer::browser_sea_refresh $tok
  update
  check {FD22 (F5) the next sea refresh clears the notice from the state and
         from the canvas} \
    [list $::wviewer::browserseanote($tok) [llength [$fd_c find withtag seanote]]] \
    [list {} 0]

  catch {wviewer::close $tok}
  }
  }
} else {
  puts "SKIPPED: group FD1x (Tk/X arm only)"
}

wvbs_finish
