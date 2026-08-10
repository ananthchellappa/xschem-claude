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
  # ⚠ FD10b, NOT a second FD10. The draft shipped this id twice, which makes a
  # sabotage table unreadable (two rows can claim "FD10 went red" and mean
  # different checks). Restated, not renumbered: the assertion is byte-identical
  # and only the label moved.
  check {FD10b (FIXTURE) the sidebar toggles on and the tree is real} \
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
  # --- RULING F1e: WHAT THE HAPPY PATH ACTUALLY LEAVES ON SCREEN -----------
  #
  # ⚠⚠ THE SCOPE IS SHOWN AND THE PANE IS STILL EMPTY. The lower pane is drawn
  # from `browserseaent`, the CURRENT database's entries alone (item 15's
  # declared limit, BD70d one file over), so a FOREIGN VCD's scope selects a
  # real row that lists nothing — and the shipped `seaempty` arm then captions
  # it "'TOP.m' has no signals of its own", about a scope that has two. This is
  # the state that makes `ase::show_in_browser_for_current`'s step 7b fire; FV41
  # owns the arm, this owns the FACT, and without the fact the arm is a guess.
  check {FD19 (F5/F1e) the digital scope is shown and the lower pane still lists
         NOTHING — the state the "shown but not listed" notice exists for} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [llength $::wviewer::browsersea($tok)] \
          [llength [$FDV.pw.sea.c find withtag cell]]] \
    [list 1 0 0]
  # THE POSITIVE CONTROL, and it is not optional: a reader that answered 1 for
  # everything would pass FD19 and be worthless. The CURRENT database's design
  # root lists its own signals, so the same reader must answer 0 there.
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  check {FD19b (F5/F1e CONTROL) the same reader answers 0 on the current
         database's own root, whose pane really does list signals} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [expr {[llength $::wviewer::browsersea($tok)] > 0}]] \
    [list 0 1]
  # ⚠ AND THE FIXTURE GOES BACK, WITH AN `update`, BEFORE ANYTHING ELSE READS
  # IT. `selection set` only QUEUES <<TreeviewSelect>>; without the flush the
  # pane below still holds the previous node's cells, and FD21 (which asserts
  # the canvas notice draws only on an EMPTY pane) then reads two stale cells
  # and fails for a reason that has nothing to do with the notice. Measured.
  pcall $FDV.pw.tvf.tv selection set [list [lindex $fd_r 1]]
  update
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

  # ===========================================================================
  # FD23-FD26 — THE ORDERING THE PRODUCT CANNOT AVOID (salvage pass, review
  # findings R1/R2/R2-D).
  #
  # ⚠⚠ EVERY CHECK ABOVE READS ITS SURFACE IN THE SAME EVENT-LOOP TURN THAT
  # WROTE IT, AND THAT IS THE ONE TURN THE PRODUCT NEVER GETS. `browser_reveal`
  # changes the treeview selection, which only QUEUES <<TreeviewSelect>>;
  # `browser_sea_refresh` is delivered on the NEXT turn — i.e. the instant the
  # Ctrl-Alt-V binding returns — and its first act is to clear the notice and
  # its last is to re-caption the pane from the shipped `seaempty` arm. So a
  # notice written before that flush lives for microseconds. Measured on the
  # real viewer, both arms, before step 6c existed: caption held the sentence on
  # return and read "TOP.m has no signals of its own" one `update` later.
  #
  # FD20/FD21 above cannot see any of it — they call `browser_notice` directly,
  # and this file's `update` calls all sit BEFORE the notice, never after it.
  # ===========================================================================

  # ⚠⚠ THE COMMAND ITSELF, NOT ITS PIECES. Only the five DESIGN-side reads are
  # stubbed (this file has no schematic and no session of its own); steps 4, 5,
  # 6, 6c, 7 and 7b are the shipped code running against the real treeview, the
  # real checkbutton, the real pane and the real canvas. Deleting step 6c's
  # `catch {update}` from src/ase.tcl reds this; so does moving it above step 6.
  proc fd_drive_on {} {
    foreach p {::ase::session_for_current ::wviewer::hier_now \
               ::ase::browser_sel_segment ::wviewer::browser_origin_drop \
               ::ase::browser_digital_probe} {
      if {[info commands $p] ne {}} { rename $p ${p}_fdsaved }
    }
    proc ::ase::session_for_current {} { return [list $::fd_tok 0] }
    proc ::wviewer::hier_now {} { return {} }
    proc ::ase::browser_sel_segment {} { return {ok a1} }
    proc ::wviewer::browser_origin_drop {level lv} { return 0 }
    proc ::ase::browser_digital_probe {key selname token} { return $::fd_dig }
  }
  proc fd_drive_off {} {
    foreach p {::ase::session_for_current ::wviewer::hier_now \
               ::ase::browser_sel_segment ::wviewer::browser_origin_drop \
               ::ase::browser_digital_probe} {
      if {[info commands ${p}_fdsaved] ne {}} {
        catch {rename $p {}}
        rename ${p}_fdsaved $p
      }
    }
  }
  set ::fd_tok $tok
  set ::fd_dig [list ok $fd_vcd TOP.m]

  # ⚠ THE PRE-STATE IS A SETTLED PANE THAT LISTS THINGS, and it is load-bearing
  # for the SECOND blocker. Step 7b's predicate reads the pane MODEL, which the
  # queued refresh has not rebuilt yet — so from here, without step 6c, it
  # answers about the design root the user is leaving (2 signals -> "not empty"
  # -> the arm refuses and writes nothing at all). Starting from an already
  # empty pane would hide that: the stale answer and the true answer would
  # coincide, and this check would pass with the flush deleted.
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  set fd_pre [list [llength $::wviewer::browsersea($tok)] \
                   [pcall ::wviewer::browser_sea_empty $tok]]
  fd_drive_on
  set fd_dr [pcall ase::show_in_browser_for_current]
  fd_drive_off
  # ⚠⚠ AND HERE IS THE TURN OF THE EVENT LOOP THAT TK ALWAYS TAKES. Everything
  # this item ships is judged after this line, never before it.
  update
  set fd_want "showing the digital scope 'TOP.m' of 'fd_dig.vcd' in the tree,\
 but the lower pane lists only the current results database, so this scope's\
 own signals are not in it yet"
  check {FD23 (F5/F1e) the real command's notice SURVIVES the refresh its own
         gesture queued — pane caption, one turn after the binding returns} \
    [list $fd_pre $fd_dr [$FDV.pw.sea.st cget -text]] \
    [list [list 2 0] $tok $fd_want]
  # the other two surfaces, same settled moment: the sidebar status line and the
  # pane canvas. The canvas arm draws only on an empty pane, which is exactly
  # the state this path produces — and it only reaches that state because 6c let
  # the refresh happen FIRST.
  check {FD24 (F5/F1e) the same sentence is on the sidebar status line and drawn
         in the pane canvas, one turn after the binding returns} \
    [list [$FDV.ph cget -text] \
          $::wviewer::browserseanote($tok) \
          [llength [$fd_c find withtag seanote]] \
          [llength [$fd_c find withtag cell]]] \
    [list "Signal Browser\n$fd_want" $fd_want 1 0]
  # ⚠ THE TOMBSTONE FOR WHY 6c EXISTS. The same two product calls in the same
  # order with NO flush between them: the notice is written, and one turn later
  # the queued refresh has cleared it and put the shipped `seaempty` falsehood
  # back. This is the state the feature shipped in before the salvage pass, kept
  # as a check so nobody re-derives it from first principles.
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  pcall ::wviewer::browser_show_db_scope $tok $fd_vcd TOP.m
  pcall ::wviewer::browser_notice $tok {FD25 unflushed}
  set fd_before [$FDV.pw.sea.st cget -text]
  update
  check {FD25 (F5/F1e TOMBSTONE) a notice written WITHOUT the settle is erased by
         the queued refresh, and the false shipped caption comes back} \
    [list $fd_before [$FDV.pw.sea.st cget -text] $::wviewer::browserseanote($tok)] \
    [list {FD25 unflushed} {TOP.m has no signals of its own} {}]

  # ⚠⚠ F5's OWN ROW, END TO END, ON THE PATH THAT SHIPPED THE DEFECT FIRST.
  # FD23/FD24 drive the SUCCESS path; this is the REFUSAL path, whose notice was
  # erased by exactly the same queued refresh. That half was inherited from
  # `fda9d5a8` — RULING F1e did not introduce it and nothing pinned it — so
  # without this check the flush could be removed from under F5's original row
  # and only the F1e rows would notice. Same five stubs, same real steps 4-7;
  # the probe answers a refusal, so step 7 writes and step 7b never runs.
  set fd_refuse {the last run promised no VCD for 'dcell' (tracing off)}
  set ::fd_dig [list none notraced $fd_refuse]
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  fd_drive_on
  pcall ase::show_in_browser_for_current
  fd_drive_off
  update
  check {FD27 (F5) the REFUSAL notice also survives the refresh its own gesture
         queued — caption and sidebar status line, one turn after the binding
         returns} \
    [list [$FDV.pw.sea.st cget -text] \
          $::wviewer::browserseanote($tok) \
          [$FDV.ph cget -text]] \
    [list "no digital signals to show: $fd_refuse" \
          "no digital signals to show: $fd_refuse" \
          "Signal Browser\nno digital signals to show: $fd_refuse"]

  # --- FD26: "the pane lists nothing" is not the same fact as "a bar is hiding
  # everything" ------------------------------------------------------------
  #
  # ⚠⚠ `browsersea` IS THE FILTERED SET, so an empty one has two causes and only
  # one of them is this reader's. With a no-match Filter pattern the design root
  # draws nothing while still HAVING two own-level signals, and the shipped
  # caption says so truthfully. A reader that called that "empty" would let step
  # 7b replace a true caption with a sentence blaming a foreign database — the
  # guessed yes its own ⚠⚠ block forbids. Leg 1 is the reader, legs 2/3 are the
  # state it is answering about, leg 4 is the shipped caption it must not
  # displace.
  pcall ::wviewer::searchbar_set $FDV.wvfilter \
    {pattern zzzznomatchzzzz syntax shell type all case 0}
  pcall ::wviewer::browser_refresh $tok 1
  pcall $FDV.pw.tvf.tv selection set [list {g:}]
  update
  check {FD26 (F5/F1e) a Search/Filter bar that hides every name is NOT an empty
         scope: the reader declines and the shipped bar caption stands} \
    [list [pcall ::wviewer::browser_sea_empty $tok] \
          [llength $::wviewer::browsersea($tok)] \
          [pcall ::wviewer::browser_sea_own $tok {}] \
          [pcall ::wviewer::browser_bars_active $tok]] \
    [list 0 0 2 1]
  pcall ::wviewer::searchbar_set $FDV.wvfilter \
    {pattern {} syntax shell type all case 0}
  pcall ::wviewer::browser_refresh $tok 1
  update

  catch {wviewer::close $tok}
  }
  }
} else {
  puts "SKIPPED: group FD1x (Tk/X arm only)"
}

wvbs_finish
