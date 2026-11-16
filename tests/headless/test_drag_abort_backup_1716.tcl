# test_drag_abort_backup_1716.tcl -- a cancelled drag must leave the sheet exactly as it was, and
# returning up the hierarchy must adopt only a cellName~ backup THIS session wrote.
#
# ISSUE 1716 (doc/claude/issues/1716-*.md): every live step of a fluid stretch drag runs the commit
# pipeline (move_objects() in src/move.c, the `commit_now` RUBBER step), and the passes in it --
# insert_exit_stubs() unconditionally, trim_wires() and the other healers whenever they change
# something -- call set_modify(1). That flagged the sheet modified and wrote the in-progress
# geometry to cellName~.sch on EVERY motion, and an Escape (move_objects ABORT) restored the
# geometry but neither the flag nor the file: a clean sheet came back "modified" with a backup of a
# drag the user cancelled, and a sheet with real unsaved edits had its backup overwritten by it.
# The B3 refusal at END had the same leak and also read the pre-gesture flag only at END, after the
# live steps had already set it. The fix holds those declarations (xctx->modify_hold, honoured by
# set_modify() in src/actions.c) for the duration of a live step and of a refusable END.
# A gesture can also end with NEITHER an END nor an ABORT: unselect_all() zeroes ui_state, and
# undo, redo, netlist, the u / Shift-U / n keys and `xschem unselect_all` reach it mid-drag. Held,
# the live steps' geometry would then stay moved and undeclared; fluid_reroute_orphan_check()
# (src/move.c, called as the outermost xschem command returns) declares it once, unless the verb
# replaced the document, saved it, or left the hierarchy level and file the gesture started on.
#
# ISSUE 1715: go_back() loaded the parent through load_backup_as(), which adopts ANY cellName~ that
# exists -- including one another session left (a crash, a kill, issue 1716's cancelled drag). The
# untouched parent then came back modified with that file's geometry, the next go_back prompted,
# "Yes" saved the foreign geometry into the cell and "No" deleted a crash recovery that was never
# this session's (issue 1486). The fix records, when a level is descended FROM, whether its unsaved
# edits were in a ~ this session wrote (xctx->sch_backup_mine[], set by descend_schematic() and
# descend_symbol()); go_back() adopts only that, and hierarchy_modified() counts only that.
#
# BANDS (every band but E, K and Z2/Z3 runs on both arms; those need real Tk and self-skip under --nogui)
#   F  the fixture really is the scratch copy, with every symbol resolved, before anything writes.
#   A  1716 through the scripted drag seam (`xschem move_objects start|step|abort|end`, the same
#      move_objects(START/RUBBER/ABORT/END) calls the Tk handlers make) on a copy of the issue's own
#      sheet, bandgap.sch, with the issue's selection (l1 p2 p4) and its settings:
#        A1  an aborted drag of a CLEAN sheet: not modified and no backup at ANY step, nor after;
#        A2  the same through `xschem abort_operation`, which is what Escape calls;
#        A3  an aborted drag of a sheet with real unsaved edits: the backup holding those edits is
#            byte-identical at every step and after, and the sheet stays modified;
#        A4  (control) a COMPLETED drag still flags the sheet and writes the moved geometry;
#        A5  (control) after an aborted drag a real edit still flags the sheet and writes a backup,
#            so the hold did not leak past the gesture;
#        A6  (control) a completed drag of the dirty sheet DOES rewrite its backup, so A3's
#            "unchanged" is a measurement and not a backup nothing could have touched.
#      A1 and A3 also carry non-vacuity legs: the selection really moved at every live step, and
#      really came back on abort.
#   R  the B3 enforcement refusal, on issue 0105's named-rail fixture (as
#      wireedit/test_wireedit_54_enforce_refuse_named_rail_0105.tcl builds it), saved to scratch and
#      re-loaded so the sheet starts clean:
#        R1/R2  one-shot / stepwise refusal of a CLEAN sheet: not modified, no backup;
#        R3/R4  one-shot / stepwise refusal of a DIRTY sheet: backup byte-identical, still modified;
#        R5     (control) the same stepwise gesture with enforcement off is accepted and does flag
#               the sheet and write the backup;
#        R7     `xschem end_live_drag` on a refused gesture reverts it as a release would and
#               declares nothing;
#        R6     (control) after a refusal a real edit still flags the sheet and writes a backup.
#      Every R row also asserts the refusal really fired (dev_merges > 0, R18 back where it was).
#   G  1715 on a copy of the issue's own hierarchy, tb_bandgap -> bandgap (x1) -> bandgap_opamp
#      (x1), with ask_save replaced by a counter that answers for the user:
#        G1  a foreign bandgap~.sch (p2 displaced, newer than the cell): the walk never prompts,
#            bandgap comes back clean with its DISK geometry, and the foreign file is untouched;
#        G2  the same answering "yes" with descend_readonly 0: the cell file is byte-identical;
#        G3  hierarchy_modified at the leaf does not count the foreign ancestor backup;
#        G4  (control) unsaved edits at the top survive the walk down and back, still modified, and
#            hierarchy_modified counts them from the leaf;
#        G5  (control) unsaved edits at the MIDDLE level are restored by go_back, and the next
#            go_back prompts and "no" drops this session's own backup;
#        G6  own edits at the top AND a foreign ~ in the middle: the middle loads from disk, the
#            top's edits come back -- the record is per level;
#        G7  (control) unsaved edits survive descend_symbol and the go_back from the symbol;
#        G8  the ownership comparison alone: an edit made with autosave_backup off (modified, no
#            backup written) beside a foreign ~, autosave back on at the descend: not adopted;
#        G9  edits discarded by reloading the cell leave this session's ~ on disk: the clean level
#            is not given them back by a descend and a go_back;
#        G10 (control) the record is copied with the hierarchy (copy_hierarchy): edits at the top
#            come back through the go_back of a descend-in-new-window.
#   O  1716's ORPHANED gesture, on the scripted seam: a stretch of l1 p2 p4, three live steps, then a
#      verb that ends it without END or ABORT:
#        O0  (per-step leg) nothing is declared while the gesture is live -- not modified, no ~;
#        O1-O4  `unselect_all`, `undo`, `redo`, `netlist -noalert` with no undo history: modified,
#            hierarchy_modified (the quit prompt), and the ~ holds the sheet on screen;
#        O5  the declaration is made once: a ~ removed after it is not written again;
#        O6  `undo 0 0` WITH history: the ~ is the restored sheet, never an empty or stale one;
#        O7  `save` mid-drag of a dirty sheet: clean, no ~, the file holds the moved geometry;
#        O8-O11  `load` of another cell, `reload`, `clear force` below the top, go_back: no ~ is
#            written for a document the verb replaced, and nothing is declared on the new one;
#        O12/O13  `descend 1 0` and `go_back 2` (no-title forms, which load WITHOUT an undo reset):
#            neither the child nor the parent is declared for the other level's gesture.
#      O11 is go_back mid-drag answered "no": since G1 it ASKS, because the drag is ended first.
#   L  G1's door, `xschem end_live_drag` (the call hierarchy_close makes): L1 ends a live drag as a
#        release would; L2 no gesture, L3 a plain (non-fluid) move, L4 an orphaned gesture: it
#        answers 0 and changes nothing.
#   V  G1 on the scripted verbs (finding G1 of doc/claude/drag_perf_batch/receipts/D2-verify.md):
#        a verb that leaves or discards the document mid-drag asks about the moved shapes.
#        V1/V2  go_back answered Cancel / Yes;  V3/V4  `clear schematic` answered Cancel / No;
#        V5/V6  descend and descend_symbol: the go_back brings the parent back as the screen had it;
#        V7  descend_symbol on an EMBEDDED symbol asks first, Cancel keeps the shapes.
#   K  G1 through REAL Tk events (display arm only), sky130A/cadence_style_rc sourced as for E:
#        K1-K9  Ctrl-Q and Ctrl-W at the top and Ctrl-E in the child, Button-1 held, each answered
#            Cancel, No and Yes (K*n: the drag was live and undeclared before the key);
#        K10  Ctrl-Q in the child; K11/K12  File > Close and File > Clear Schematic during an 'm'
#            move; K13  Ctrl-O held; K14  Quit with another tab's drag left live; K15/K15b  a separate
#            window's window-manager close, tabbed interface on / off (`xschem exit closewindow` /
#            `new_schematic destroy`); K16  `new_schematic destroy` of the current tab;
#        K17  Quit with the tabbed interface off and another window's drag live;
#        K18  Edit > Pop: the action log keeps the move line AND the menu's own line (needs the
#            action log, so it prints SKIP under --nolog, which is run_suites.sh's default).
#   E  the display arm, through REAL Tk events, with sky130A/cadence_style_rc sourced as in the
#      issue's reproduction (its library registry replaced by the scratch one before anything loads):
#        E1  press on l1, twelve motions, Escape, release, on a CLEAN sheet: never modified, no
#            backup, while the selection visibly moved;
#        E2  the same on a dirty sheet: the backup is byte-identical throughout;
#        E3  issue 1715's walk with the rc's settings (descend_readonly 1): no prompt, disk geometry,
#            the foreign backup untouched;
#        E4  a press on l1 and four motions, then the REAL `u` key with Button-1 still held: the
#            gesture is orphaned (STARTMOVE gone, no END or ABORT) and its shapes are declared.
#   Z  crash recovery, the one place a foreign ~ that go_back now leaves in place is meant for:
#        Z1  no SCRIPTED load in the bands above offered it (only an interactive load does);
#        Z2/Z3  (display arm only: the offer needs has_x) an interactive `xschem load -gui` into a
#            pristine untitled window, of a cell with a planted foreign ~: the product's own
#            xschem_recover_backup offers once; Yes restores the backup, No discards it. A -gui open
#            from an OCCUPIED window is routed to a new one and makes no offer (measured).
#
# HERMETIC FIXTURE: every cell this suite loads or writes is a copy under its own scratch directory.
# library.defs discovery would otherwise resolve sky130_tests_ase to the tree's own sky130A (it
# looks in each search directory AND its parent), so an explicit XSCHEM_LIBRARY_DEFS names the
# scratch copy, and every other library it names is only read. Row F1 proves it before any write.
#
# Runs on both arms. From the repo ROOT:
#   tests/headless/run_suites.sh --nogui test_drag_abort_backup_1716
#   tests/headless/run_suites.sh test_drag_abort_backup_1716

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { incr npass; puts "ok: $name" } \
    else { incr fail; puts "FAIL: $name -- got {$got} want {$exp}" }
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set SC   [test_scratch dab1716]
set SRCL [file join $REPO sky130A xschem_libs sky130_tests_ase]
set LIB  [file join $SC lib]
set TL   [file join $LIB sky130_tests_ase]
foreach c {tb_bandgap bandgap bandgap_opamp lvnand} {
    foreach {k ext} {schematic sch symbol sym} {
        file mkdir [file join $TL $c $k]
        file copy [file join $SRCL $c $k $c.$ext] [file join $TL $c $k $c.$ext]
    }
}
file copy [file join $SRCL library.tag] [file join $TL library.tag]
set DEFS [file join $LIB library.defs]
set fd [open $DEFS w]
puts $fd "DEFINE sky130_tests_ase $TL"
foreach l {sky130_fd_pr sky130_tests sky130_stdcells stdcells} {
    puts $fd "DEFINE $l [file join $REPO sky130A xschem_libs $l]"
}
puts $fd "DEFINE devices [file join $REPO xschem_library devices]"
close $fd

## the scratch registry; called again after the display arm sources the rc, which names the tree's
proc fixture_paths {} {
    set ::XSCHEM_LIBRARY_DEFS $::DEFS
    set ::XSCHEM_LIBRARY_PATH [file join $::REPO xschem_library devices]
    catch {set_paths}
}
## the settings issue 1716's reproduction ran with (sky130A/cadence_style_rc), for the counted arm
proc issue_settings {} {
    foreach v {cadence_compat fluid_editing orthogonal_wiring autotrim_wires
               fluid_enforce_invariants autosave_backup} { set ::$v 1 }
    set ::enable_stretch 0
}
fixture_paths
issue_settings

set TB  [file join $TL tb_bandgap schematic tb_bandgap.sch]
set BG  [file join $TL bandgap schematic bandgap.sch]
set OA  [file join $TL bandgap_opamp schematic bandgap_opamp.sch]
set TBB [file join $TL tb_bandgap schematic tb_bandgap~.sch]
set BGB [file join $TL bandgap schematic bandgap~.sch]
set OAB [file join $TL bandgap_opamp schematic bandgap_opamp~.sch]
set RD  [file join $SC refuse]
set RS  [file join $RD refuse.sch]
set RB  [file join $RD refuse~.sch]

## the user's answers: ask_save counts and answers $::ANSWER; a crash-recovery prompt can never
## block (a tk_messageBox would hang the display arm), it is counted and declined
set ::ANSWER no; set ::asks 0
proc ::ask_save {args} { incr ::asks; return $::ANSWER }
## the product's own offer is kept aside for band Z, which drives it with its dialog answered here
catch {rename ::xschem_recover_backup ::z_real_recover}
proc ::xschem_recover_backup {args} { incr ::recovers; return 0 }
set ::recovers 0

## a band runs in its own catch: an error in one is a counted FAIL that names it, and the bands
## after it still run and report, so a sabotage cannot silently delete the rows below it
proc band {name body} {
    if {[catch {uplevel #0 $body} e]} {
        incr ::fail
        puts "FAIL: band $name ABORTED -- $e"
        puts $::errorInfo
    }
}
proc md5f {f} { if {![file exists $f]} { return - }; return [lindex [exec md5sum $f] 0] }
proc sweep_backups {} {
    foreach f [list $::TBB $::BGB $::OAB $::RB] { file delete -force $f }
}
proc fresh {f} {
    while {[xschem get currsch] > 0} { xschem go_back 0 }
    xschem clear force
    sweep_backups
    xschem load $f
}
proc ibb {n} { lrange [lindex [split [xschem instance_bbox $n] \n] 0] 1 4 }
proc ixy {n} { lrange [xschem instance_coord $n] 2 3 }
proc under_scratch {f} { expr {[string first "$::SC/" $f] == 0} }
## one sample of the bandgap sheet's state: flag, backup content, p2's place
proc bstate {} { list [xschem get modified] [md5f $::BGB] [ixy p2] [xschem get ui_state] }
## how many of samples first..last carry STARTMOVE in ui_state (src/xschem.h: STARTMOVE is 32U)
proc nmoving {samples first last} {
    set n 0
    foreach s [lrange $samples $first $last] { if {[lindex $s 3] & 32} { incr n } }
    return $n
}

if {[catch {

# ================================================================================================
# F -- the fixture
# ================================================================================================
band F {
fresh $BG
set f_bg [xschem get schname]
fresh $TB
xschem unselect_all; xschem select instance x1; xschem descend
set f_l1 [xschem get schname]
xschem unselect_all; xschem select instance x1; xschem descend
set f_l2 [xschem get schname]
set miss 0
for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[string match *missing* [xschem getprop instance $i cell::name]]} { incr miss }
}
fresh $TB
set f_tb [xschem get schname]
check "F1 every level this suite loads is the scratch copy (bandgap, tb, x1, x1.x1)" \
    [list [under_scratch $f_bg] [under_scratch $f_tb] [under_scratch $f_l1] [under_scratch $f_l2]] \
    {1 1 1 1}
check "F1b the descends reached bandgap.sch and bandgap_opamp.sch ([file tail $f_l1], [file tail $f_l2])" \
    [list [file tail $f_l1] [file tail $f_l2]] {bandgap.sch bandgap_opamp.sch}
check "F2 no missing symbol at the leaf, so the walks below measure a real sheet" $miss 0

}
# ================================================================================================
# A -- 1716 through the scripted seam, on bandgap.sch
# ================================================================================================
band A {
## drag l1 p2 p4 by six (+10,+10) live steps from p2's corner, then finish with $how.
## Returns a list of bstate samples: pre, started, step1..step6, after.
proc bdrag {how {plant 0}} {
    fresh $::BG
    if {$plant} { xschem wire -400 -900 -300 -900 }
    set s [list [bstate]]
    xschem unselect_all
    foreach n {l1 p2 p4} { xschem select instance $n fast }
    lassign [ibb p2] x1 y1
    set ax [expr {round($x1 / 10.0) * 10}]; set ay [expr {round($y1 / 10.0) * 10}]
    xschem move_objects start $ax $ay stretch
    lappend s [bstate]
    for {set k 1} {$k <= 6} {incr k} {
        xschem move_objects step [expr {$ax + 10 * $k}] [expr {$ay + 10 * $k}]
        lappend s [bstate]
    }
    switch -- $how {
        abort  { xschem move_objects abort }
        escape { xschem abort_operation }
        end    { xschem move_objects end }
    }
    lappend s [bstate]
    return $s
}
## the samples whose flag or backup differ from want, as {index flag backup}
proc deviations {samples wflag wbak} {
    set bad {}; set i 0
    foreach s $samples {
        lassign $s m b
        if {$m ne $wflag || $b ne $wbak} { lappend bad [list $i $m $b] }
        incr i
    }
    return $bad
}
## p2 moved at every live step and is back where it started after the last sample
proc moved_and_back {samples} {
    set p0 [lindex $samples 0 2]; set ok 1
    foreach s [lrange $samples 2 7] { if {[lindex $s 2] eq $p0} { set ok 0 } }
    list $ok [expr {[lindex $samples end 2] eq $p0}]
}

set s [bdrag abort]
check "A1 aborted drag of a CLEAN sheet: not modified and no backup at any step or after\
       (deviating samples as index/flag/backup)" [deviations $s 0 -] {}
check "A1n non-vacuity: a move was in progress (STARTMOVE) at all six live steps, p2 moved at\
       each, and it is back after the abort" [list [nmoving $s 2 7] {*}[moved_and_back $s]] {6 1 1}

set s [bdrag escape]
check "A2 the same through xschem abort_operation (Escape's path): never modified, no backup" \
    [deviations $s 0 -] {}
check "A2n non-vacuity: STARTMOVE at all six live steps, p2 moved and came back" \
    [list [nmoving $s 2 7] {*}[moved_and_back $s]] {6 1 1}

set s [bdrag abort 1]
set pre_bak [lindex $s 0 1]
check "A3 aborted drag of a DIRTY sheet: its backup is byte-identical at every step and after,\
       and it stays modified" [deviations $s 1 $pre_bak] {}
check "A3n non-vacuity: the planted edit really wrote a backup, STARTMOVE at all six live steps,\
       and p2 moved and came back" [list [expr {$pre_bak ne {-}}] [nmoving $s 2 7] {*}[moved_and_back $s]] {1 6 1 1}

set s [bdrag end]
set fin [lindex $s end]
set p2line {}
if {[file exists $BGB]} {
    set fd [open $BGB r]
    foreach ln [split [read $fd] \n] { if {[string match {C {devices/opin} * {name=p2 *}} $ln]} { set p2line $ln } }
    close $fd
}
check "A4 (control) a COMPLETED drag flags the sheet and writes a backup" \
    [list [lindex $fin 0] [expr {[lindex $fin 1] ne {-}}]] {1 1}
check "A4b (control) that backup holds p2 at its moved place ([lindex $fin 2]; backup line: $p2line)" \
    [expr {[lsearch -exact $p2line [lindex $fin 2 0]] >= 0 && [lsearch -exact $p2line [lindex $fin 2 1]] >= 0
           && [lindex $fin 2] ne [lindex $s 0 2]}] 1

bdrag abort
xschem wire -400 -950 -300 -950
check "A5 (control) after an aborted drag a real edit still flags the sheet and writes a backup" \
    [list [xschem get modified] [expr {[md5f $BGB] ne {-}}]] {1 1}

set s [bdrag end 1]
check "A6 (control) a completed drag of the dirty sheet DOES rewrite its backup and stays modified" \
    [list [lindex $s end 0] [expr {[lindex $s end 1] ne [lindex $s 0 1] && [lindex $s end 1] ne {-}}]] {1 1}

}
# ================================================================================================
# O -- 1716, the ORPHANED drag: a live stretch that ends neither in END nor in ABORT
# ================================================================================================
band O {
## start a stretch of l1 p2 p4 and run three live steps; returns {samples p2-at-start}
proc odrag3 {} {
    set p0 [ixy p2]
    xschem unselect_all
    foreach n {l1 p2 p4} { xschem select instance $n fast }
    lassign [ibb p2] x1 y1
    set ax [expr {round($x1 / 10.0) * 10}]; set ay [expr {round($y1 / 10.0) * 10}]
    xschem move_objects start $ax $ay stretch
    set s {}
    for {set k 1} {$k <= 3} {incr k} {
        xschem move_objects step [expr {$ax + 10 * $k}] [expr {$ay + 10 * $k}]
        lappend s [bstate]
    }
    return [list $s $p0]
}
## p2's place, and the instance and wire counts, as the file $f records them ({- - -}: no file)
proc filed {f} {
    if {![file exists $f]} { return {- - -} }
    set fd [open $f r]; set t [read $fd]; close $fd
    set p -
    regexp {\nC \{devices/opin\} (\S+) (\S+) \S+ \S+ \{name=p2 } $t -> px py
    if {[info exists px]} { set p [list $px $py] }
    list $p [regexp -all -line {^C } $t] [regexp -all -line {^N } $t]
}
## what the screen holds, in filed's shape
proc onscreen {} { list [ixy p2] [xschem get instances] [xschem get wires] }
## after the verb: {modified hierarchy_modified ~-is-the-screen STARTMOVE-gone p2-moved}
proc orphaned {p0} {
    list [xschem get modified] [xschem get hierarchy_modified] [expr {[filed $::BGB] eq [onscreen]}] \
        [expr {([xschem get ui_state] & 32) == 0}] [expr {[ixy p2] ne $p0}]
}

fresh $BG
lassign [odrag3] s p0
check "O0 the live steps declare nothing: not modified and no backup at any of three steps\
       (deviating samples), while STARTMOVE is set and p2 moves" \
    [list [deviations $s 0 -] [nmoving $s 0 2] [expr {[lindex $s 2 2] ne $p0}]] {{} 3 1}
xschem unselect_all
check "O1 'xschem unselect_all' mid-drag leaves the moved shapes DECLARED: modified,\
       hierarchy_modified (the quit prompt), the ~ holds the sheet on screen; the gesture really\
       was orphaned and p2 really moved" [orphaned $p0] {1 1 1 1 1}

foreach {row verb} {O2 {xschem undo} O3 {xschem redo} O4 {xschem netlist -noalert}} {
    fresh $BG
    lassign [odrag3] s p0
    eval $verb
    check "$row '$verb' mid-drag of a sheet with no undo history: declared as O1 is" [orphaned $p0] {1 1 1 1 1}
}

## the orphan is declared once per gesture: a ~ removed after the declaration stays removed
fresh $BG
lassign [odrag3] s p0
xschem unselect_all
set o5_decl [list [xschem get modified] [file exists $BGB]]
file delete -force $BGB
xschem redraw
xschem get instances
check "O5 the orphan is declared ONCE: after the declaration ($o5_decl) a ~ removed by hand is not\
       rewritten by later xschem commands" [file exists $BGB] 0

## undo WITH history: the restore replaces the drag's geometry -- the ~ is what the screen holds.
## (Control, measured on the base build, D-fix and this fix alike: 'xschem undo 0 0' of a plain edit,
## no drag, leaves the ~ as it was, since its second argument asks pop_undo not to touch the modify
## state. Here the orphaned gesture is declared after the verb, which rewrites it.)
fresh $BG
xschem wire -400 -900 -300 -900
lassign [odrag3] s p0
xschem undo 0 0
check "O6 'xschem undo 0 0' mid-drag with history: the ~ is the sheet on screen, never an empty or a\
       stale one (p2/instances/wires filed vs on screen: [filed $BGB] / [onscreen])" \
    [list [xschem get modified] [expr {[filed $BGB] eq [onscreen]}] [expr {[xschem get instances] > 0}]] {1 1 1}

## a SAVE mid-drag commits the drag's geometry to the file: nothing is left to declare
fresh $BG
xschem wire -400 -900 -300 -900
lassign [odrag3] s p0
set o7_pre [xschem get modified]
xschem save
xschem redraw
## (wires are not compared: a real save coalesces split wire segments, a backup does not)
check "O7 'xschem save' mid-drag of a DIRTY sheet (modified $o7_pre before) leaves it clean with no ~,\
       and the file holds p2 and the instances where the screen has them" \
    [list [xschem get modified] [file exists $BGB] [expr {[lrange [filed $BG] 0 1] eq [lrange [onscreen] 0 1]}]] {0 0 1}
## that save wrote the dragged geometry into the scratch cell: put the pristine copy back
file copy -force [file join $SRCL bandgap schematic bandgap.sch] $BG

## a verb that REPLACES the buffer takes the drag's geometry with it: no ~ for a document that is gone
fresh $BG
lassign [odrag3] s p0
xschem load $OA
check "O8 'xschem load' of another cell mid-drag: no bandgap~.sch is written, the new cell is clean" \
    [list [file exists $BGB] [xschem get modified] [file tail [xschem get schname]]] {0 0 bandgap_opamp.sch}

fresh $BG
lassign [odrag3] s p0
xschem reload
check "O9 'xschem reload' mid-drag: the reloaded sheet is clean, at its disk geometry ($p0), with no ~" \
    [list [xschem get modified] [file exists $BGB] [ixy p2] $p0] {0 0 {150 -130} {150 -130}}

proc down1 {} { fresh $::TB; xschem unselect_all; xschem select instance x1; xschem descend }
down1
set o10_lvl [list [xschem get currsch] [file tail [xschem get schname]]]
lassign [odrag3] s p0
xschem clear force
check "O10 'xschem clear force' mid-drag BELOW the top (at $o10_lvl): no backup is written for either\
       level -- not tb_bandgap~.sch (clear resets currsch before it unselects), not bandgap~.sch" \
    [list [file exists $TBB] [file exists $BGB]] {0 0}

## (go_back is a verb that LEAVES the level, so since the G1 follow-up it ends the live drag first and
## asks about it, as base did -- band V holds the Cancel and Yes answers; ask_save answers "no" here)
down1
lassign [odrag3] s p0
set ::asks 0
xschem go_back
check "O11 go_back mid-drag ASKS about the drag (G1), and answered No: the parent is clean, and no\
       bandgap~.sch nor tb_bandgap~.sch is left behind (asks/level/modified/~/tb~)" \
    [list $::asks [xschem get currsch] [xschem get modified] [file exists $BGB] [file exists $TBB]] {1 0 0 0 0}

## descend mid-drag at the top, in a no-title form ('descend 1 0': bit 0 of the last argument clear,
## as src/op_annot.tcl's own descend has it): the child is then loaded WITHOUT an undo reset, so no
## latch is set and only the level/file test keeps the parent's gesture from being declared on it
fresh $TB
xschem unselect_all
xschem select instance x1
set x0 [lrange [xschem instance_coord x1] 2 3]
lassign $x0 ax ay
xschem move_objects start $ax $ay stretch
for {set k 1} {$k <= 3} {incr k} {
    xschem move_objects step [expr {$ax + 10 * $k}] [expr {$ay + 10 * $k}]
}
set o12_live [lrange [xschem instance_coord x1] 2 3]
xschem descend 1 0
set o12_child [list [xschem get currsch] [file tail [xschem get schname]] [xschem get modified] [file exists $BGB]]
xschem go_back
set o12_now [lrange [xschem instance_coord x1] 2 3]
set o12_mod [xschem get modified]
check "O12 'xschem descend 1 0' mid-drag: the CHILD is not declared for the parent's gesture -- clean, and no\
       bandgap~.sch (level/sheet/modified/~)" $o12_child {1 bandgap.sch 0 0}
check "O12b ...and after go_back the parent is declared or pristine, never between: modified with a\
       tb_bandgap~.sch, or clean with x1 at its disk place $x0 and no ~ (x1 was live at $o12_live, is\
       now at $o12_now, modified $o12_mod)" \
    [list [expr {$o12_live ne $x0}] \
          [expr {$o12_mod ? [file exists $TBB] : ($o12_now eq $x0 && ![file exists $TBB])}]] {1 1}

## go_back mid-drag in its no-title form ('go_back 2', as src/op_annot.tcl and src/ase.tcl call it):
## the parent is loaded without an undo reset, so again only the level/file test keeps the child's
## gesture off the parent
down1
lassign [odrag3] s p0
set ::asks 0
xschem go_back 2
check "O13 'xschem go_back 2' mid-drag: no prompt, the parent is clean, no tb_bandgap~.sch and no\
       bandgap~.sch (asks/level/modified/tb~/~)" \
    [list $::asks [xschem get currsch] [xschem get modified] [file exists $TBB] [file exists $BGB]] {0 0 0 0 0}

}
# ================================================================================================
# L -- the door: `xschem end_live_drag` (end_live_fluid_drag() in src/callback.c), scripted seam
# ================================================================================================
band L {
## the door, answering ERR where it does not exist (a build without it), so each row reds on its own
proc door {} { if {[catch {xschem end_live_drag} r]} { return ERR }; return $r }
## band O's gesture (odrag3: l1 p2 p4 stretched in three live steps), ended through the door
fresh $BG
lassign [odrag3] s p0
set plive [ixy p2]
set r1 [door]
set l1 [list $r1 [expr {[xschem get ui_state] & 32}] [xschem get modified] \
    [expr {[filed $BGB] eq [onscreen]}] [expr {[ixy p2] eq $plive}] [expr {$plive ne $p0}]]
set r2 [door]
check "L1 'xschem end_live_drag' mid-drag ends the gesture as a release would: it answers 1, STARTMOVE is\
       gone, the sheet is modified, the ~ holds the sheet on screen, p2 stays where the live steps put it\
       ($plive, from $p0); a second call answers 0 (answer/STARTMOVE/modified/~/p2-kept/p2-moved/again)" \
    [list {*}$l1 $r2] {1 0 1 1 1 1 0}
fresh $BG
check "L2 with no gesture live it answers 0 and declares nothing (answer/modified/~)" \
    [list [door] [xschem get modified] [file exists $BGB]] {0 0 0}
## a PLAIN move commits nothing before its END, so there is nothing to declare and the door leaves it
fresh $BG
set ::fluid_editing 0
lassign [odrag3] s p0
set l3 [list [door] [expr {[xschem get ui_state] & 32}] [xschem get modified]]
xschem move_objects abort
set ::fluid_editing 1
check "L3 a plain (non-fluid) move is not a fluid drag: the door answers 0 and the gesture stays live,\
       undeclared; its ABORT then leaves the sheet clean (answer/STARTMOVE/modified, then modified/~)" \
    [list {*}$l3 [xschem get modified] [file exists $BGB]] {0 32 0 0 0}
## a gesture ORPHANED by unselect_all (band O's O1) is no longer live: the door must not END it again,
## which would restore the START snapshot and recommit a stale delta over the declared sheet
fresh $BG
lassign [odrag3] s p0
xschem unselect_all
set l4_pre [list [ixy p2] [md5f $BGB] [xschem get modified]]
check "L4 after the gesture was orphaned (and declared) the door answers 0 and changes nothing: p2, the ~\
       and the flag are as the orphan check left them ($l4_pre)" \
    [list [door] [ixy p2] [md5f $BGB] [xschem get modified]] [list 0 {*}$l4_pre]
}
# ================================================================================================
# V -- G1 of the 1716 follow-up (doc/claude/drag_perf_batch/receipts/D2-verify.md): a verb that
#      leaves the level or discards the buffer while a fluid drag is LIVE ends the drag the way its
#      release would, so the verb's "save changes?" asks about it -- scripted seam, both arms
# ================================================================================================
band V {
set BG0 [md5f [file join $SRCL bandgap schematic bandgap.sch]]
## the pristine cell back after a row that answered Yes and so saved the dragged geometry into it
proc pristine_bg {} { file copy -force [file join $::SRCL bandgap schematic bandgap.sch] $::BG }
## onscreen, answering "-" for p2 when the verb took the sheet away (a build that clears without asking),
## so a wrong answer is a red row and not an aborted band
proc vscreen {} {
    if {[catch {ixy p2} p]} { set p - }
    list $p [xschem get instances] [xschem get wires]
}
## after the verb: {asks level STARTMOVE modified ~-is-the-screen cell-file-untouched}
proc vstate {} {
    list $::asks [xschem get currsch] [expr {[xschem get ui_state] & 32}] [xschem get modified] \
        [expr {[filed $::BGB] eq [vscreen]}] [expr {[md5f $::BG] eq $::BG0}]
}
check "V0 the comparand is real: the scratch bandgap.sch is the pristine copy" [md5f $BG] $BG0

down1
lassign [odrag3] s p0
set ::ANSWER {}; set ::asks 0
xschem go_back
check "V1 'xschem go_back' (Edit > Pop, Ctrl-E) mid-drag in the child, answered CANCEL: it asked, the\
       child stays, the gesture is over, the sheet is modified with a ~ holding the screen, the cell\
       file is untouched (asks/level/STARTMOVE/modified/~/file)" [vstate] {1 1 0 1 1 1}
set ::ANSWER no

down1
lassign [odrag3] s p0
set plive [ixy p2]
set ::ANSWER yes; set ::asks 0
xschem go_back
set ::ANSWER no
check "V2 the same answered YES: the cell file holds p2 where the screen had it ($plive), no ~, back at\
       the top and clean (asks/level/modified/file-p2/~)" \
    [list $::asks [xschem get currsch] [xschem get modified] [lindex [filed $BG] 0] [file exists $BGB]] \
    [list 1 0 0 $plive 0]
pristine_bg

fresh $BG
lassign [odrag3] s p0
set ::ANSWER {}; set ::asks 0
xschem clear schematic
check "V3 'xschem clear schematic' (File > Clear Schematic, Ctrl-N) mid-drag, answered CANCEL: it asked\
       and the sheet is kept, modified, the gesture over (asks/level/STARTMOVE/modified/~/file, sheet)" \
    [list {*}[vstate] [file tail [xschem get schname]]] {1 0 0 1 1 1 bandgap.sch}
set ::ANSWER no

fresh $BG
lassign [odrag3] s p0
set ::asks 0
xschem clear schematic
check "V4 the same answered NO: the sheet is cleared, and this session's bandgap~.sch goes with it\
       (asks/sheet/~/file)" \
    [list $::asks [file tail [xschem get schname]] [file exists $BGB] [expr {[md5f $BG] eq $BG0}]] \
    {1 untitled.sch 0 1}

## descend LEAVES the level downwards: the parent's moved shapes must be in a ~ the go_back adopts.
## x1 of tb_bandgap stretched by (+20, 0) in two live steps, a gesture whose END is accepted
proc vlive_x1 {} {
    fresh $::TB
    xschem unselect_all; xschem select instance x1
    lassign [ixy x1] ax ay
    xschem move_objects start $ax $ay stretch
    foreach k {1 2} { xschem move_objects step [expr {$ax + 10 * $k}] $ay }
    return [list $ax $ay]
}
foreach {row verb name} {V5 {xschem descend} {Edit > Push schematic, e} V6 {xschem descend_symbol} {Edit > Push symbol, i}} {
    set x0 [vlive_x1]
    set xl [ixy x1]
    eval $verb
    set lvl [xschem get currsch]
    set ::asks 0
    xschem go_back
    check "$row '$verb' ($name) mid-drag at the top, then go_back: the parent comes back with x1 where the\
           screen had it ($xl, from $x0), modified, its ~ written (level-below/asks/x1/modified/tb~)" \
        [list $lvl $::asks [ixy x1] [xschem get modified] [file exists $TBB]] [list 1 0 $xl 1 1]
}
## an EMBEDDED symbol: descend_symbol asks to save the parent first, so the drag must be declared
## before that prompt. The fixture is a scratch copy of tb_bandgap saved with x1 embedded.
set TE [file join [file dirname $TB] tb_bandgap_emb.sch]
set TEB [file join [file dirname $TB] tb_bandgap_emb~.sch]
fresh $TB
xschem setprop instance x1 embed true
xschem saveas $TE
fresh $TE
set v7_pre [list [xschem getprop instance x1 embed] [xschem get modified]]
xschem unselect_all; xschem select instance x1
lassign [ixy x1] ax ay
xschem move_objects start $ax $ay stretch
foreach k {1 2} { xschem move_objects step [expr {$ax + 10 * $k}] $ay }
set xl [ixy x1]
set ::ANSWER {}; set ::asks 0
xschem descend_symbol
check "V7 'xschem descend_symbol' mid-drag on an EMBEDDED x1 (fixture: embed=$v7_pre, clean), answered\
       CANCEL: it asked, stayed at the top, the gesture is over, x1 stays where the screen had it\
       ($xl), modified, its ~ written (asks/level/STARTMOVE/x1/modified/~)" \
    [list $::asks [xschem get currsch] [expr {[xschem get ui_state] & 32}] \
         [expr {[catch {ixy x1} v7x] ? "-" : $v7x}] [xschem get modified] [file exists $TEB]] \
    [list 1 0 0 $xl 1 1]
set ::ANSWER no
xschem clear force
file delete -force $TE $TEB
}
# ================================================================================================
# R -- the B3 refusal, issue 0105's named-rail fixture
# ================================================================================================
band R {
## Built on a NAMED empty sheet, never an untitled one: an untitled sheet's backup is anchored to
## the startup directory (CLAUDE.md, untitled~.sch), which here is the tree.
file mkdir $RD
set fd [open $RS w]; puts $fd "v {xschem version=3.4.6 file_version=1.2\n}"; close $fd
fresh $RS
set r0_name [xschem get schname]
set ::cadsnap 10; set ::unselect_partial_sel_wires 0
xschem instance devices/capa    -320 -190 0 0 {name=C12 m=1 value="40u"}
xschem instance devices/res      -40    0 3 1 {name=R18 m=1 value=200}
xschem instance devices/ammeter -360  140 3 0 {name=v8}
xschem instance devices/opin    -270  140 0 0 {name=p5 lab=OUT}
xschem instance devices/lab_pin -200  -40 0 0 {name=lvdd lab=VDD}
foreach w {
    {-550 140 -550 160} {-550 120 -550 140} {-330 140 -270 140} {-550 140 -400 140}
    {-400 140 -390 140} {-400 -40 -400 140} {-320 -300 -320 -220} {-420 -300 -320 -300}
    {-320 -160 -320 -150} {-320 -150 -80 -150} {-400 -40 0 -40} {-80 -150 -80 0}
    {0 -40 0 0} {-80 0 -70 0} {-10 0 0 0}
} { xschem wire {*}$w }
xschem save
fresh $RS
check "R0 the refusal fixture is a scratch file, saved, and re-loads clean with its 15 wires" \
    [list [under_scratch $r0_name] [xschem get modified] [xschem get wires] [file exists $RB]] {1 0 15 0}

proc rstate {} { list [xschem get modified] [md5f $::RB] [ixy R18] }
## R18 dragged by (-90,-40), one-shot or in five live steps. Returns {samples merges}.
proc rdrag {how {plant 0} {enforce 1} {ender {xschem move_objects end}}} {
    fresh $::RS
    set ::fluid_enforce_invariants $enforce
    if {$plant} { xschem wire -900 -900 -800 -900 }
    set ::fluid_last_move_dev_merges 0
    set s [list [rstate]]
    xschem unselect_all; xschem select instance R18
    if {$how eq "oneshot"} {
        xschem move_objects -90 -40 stretch kissing
    } else {
        xschem move_objects start -40 0 stretch kissing
        foreach {x y} {-50 -10 -70 -20 -90 -30 -110 -40 -130 -40} {
            xschem move_objects step $x $y
            lappend s [rstate]
        }
        if {[catch {eval $ender} ::r_ended]} { set ::r_ended "ERR: $::r_ended" }
    }
    lappend s [rstate]
    set ::fluid_enforce_invariants 1
    return [list $s $::fluid_last_move_dev_merges]
}
proc refused {r} {
    lassign $r s merges
    list [expr {$merges > 0}] [expr {[lindex $s end 2] eq [lindex $s 0 2]}]
}

set r [rdrag oneshot]
check "R1 one-shot refusal of a CLEAN sheet: not modified, no backup (samples deviating)" \
    [deviations [lindex $r 0] 0 -] {}
check "R1n the refusal fired (dev_merges > 0) and R18 is back" [refused $r] {1 1}

set r [rdrag steps]
check "R2 stepwise refusal of a CLEAN sheet: not modified and no backup at any step or after" \
    [deviations [lindex $r 0] 0 -] {}
check "R2n the refusal fired and R18 is back; R18 really moved at the live steps" \
    [list {*}[refused $r] [expr {[lindex $r 0 3 2] ne [lindex $r 0 0 2]}]] {1 1 1}
xschem wire -900 -950 -800 -950
check "R6 (control) after a refusal a real edit still flags the sheet and writes a backup" \
    [list [xschem get modified] [expr {[md5f $RB] ne {-}}]] {1 1}

set r [rdrag oneshot 1]
set pre_rb [lindex $r 0 0 1]
check "R3 one-shot refusal of a DIRTY sheet: backup byte-identical, still modified" \
    [deviations [lindex $r 0] 1 $pre_rb] {}
check "R3n the planted edit wrote a backup; the refusal fired and R18 is back" \
    [list [expr {$pre_rb ne {-}}] {*}[refused $r]] {1 1 1}

set r [rdrag steps 1]
set pre_rb [lindex $r 0 0 1]
check "R4 stepwise refusal of a DIRTY sheet: backup byte-identical at every step and after" \
    [deviations [lindex $r 0] 1 $pre_rb] {}
check "R4n the refusal fired and R18 is back" [refused $r] {1 1}

set r [rdrag steps 0 0]
set fin [lindex $r 0 end]
check "R5 (control) the same gesture with enforcement OFF is accepted: modified, backup written,\
       R18 moved (R18 at [lindex $fin 2])" \
    [list [lindex $fin 0] [expr {[lindex $fin 1] ne {-}}] [expr {[lindex $fin 2] ne {-40 0}}]] {1 1 1}

## the G1 door ends a refusable gesture through the same END: refused, it declares nothing either
set r [rdrag steps 0 1 {xschem end_live_drag}]
check "R7 a stepwise gesture ended by 'xschem end_live_drag' (what a quit, close, go-up or clear does\
       with a drag live) is refused exactly as its release would be: the door answered 1, the sheet\
       is clean with no backup at any step or after, the refusal fired and R18 is back" \
    [list $::r_ended [deviations [lindex $r 0] 0 -] {*}[refused $r]] {1 {} 1 1}

}
# ================================================================================================
# G -- 1715, go_back on tb_bandgap -> bandgap -> bandgap_opamp
# ================================================================================================
band G {
## a cellName~ this session never wrote: bandgap with p2 moved to (220,-80), newer than the cell
proc plant_foreign {} {
    set fd [open $::BG r]; set t [read $fd]; close $fd
    set t2 [string map {{C {devices/opin} 150 -130 0 0 {name=p2 lab=VBG}}
                        {C {devices/opin} 220 -80 0 0 {name=p2 lab=VBG}}} $t]
    if {$t2 eq $t} { error "plant_foreign: p2's line not found in bandgap.sch" }
    set fd [open $::BGB w]; puts -nonewline $fd $t2; close $fd
    file mtime $::BGB [expr {[file mtime $::BG] + 60}]
}
proc down {} { xschem unselect_all; xschem select instance x1; xschem descend }
## the walk; edit is {} | top | mid. Returns a dict of what each stop saw.
proc walk {edit {foreign 0} {answer no} {ro 1}} {
    set ::descend_readonly $ro
    ## re-copy the three cells: a "yes" on a broken tree saves the foreign geometry INTO bandgap.sch
    foreach c {tb_bandgap bandgap bandgap_opamp} {
        file copy -force [file join $::SRCL $c schematic $c.sch] [file join $::TL $c schematic $c.sch]
    }
    fresh $::TB
    if {$foreign} { plant_foreign }
    set w [dict create fbak0 [md5f $::BGB] fmt0 [expr {[file exists $::BGB] ? [file mtime $::BGB] : {-}}] \
               bg0 [md5f $::BG] tbw0 [xschem get wires]]
    set ::ANSWER $answer; set ::asks 0
    if {$edit eq "top"} { xschem wire -2000 -2000 -1900 -2000 }
    dict set w tbw_edit [xschem get wires]
    down
    dict set w l1 [xschem get currsch]
    dict set w bgw0 [xschem get wires]
    if {$edit eq "mid"} { xschem wire -2000 -2000 -1900 -2000 }
    dict set w bgw_edit [xschem get wires]
    down
    dict set w l2 [xschem get currsch]
    dict set w hm_leaf [xschem get hierarchy_modified]
    xschem go_back
    dict set w up1 [list [xschem get currsch] [xschem get modified] [ixy p2] [xschem get wires]]
    dict set w asks_up1 $::asks
    xschem go_back
    dict set w up2 [list [xschem get currsch] [xschem get modified] [xschem get wires]]
    dict set w asks [list $::asks]
    dict set w fbak1 [md5f $::BGB]
    dict set w fmt1 [expr {[file exists $::BGB] ? [file mtime $::BGB] : {-}}]
    dict set w bg1 [md5f $::BG]
    set ::ANSWER no; set ::descend_readonly 0
    return $w
}

set w [walk {} 1 no 1]
check "G0 the walk reached the leaf (levels [dict get $w l1] [dict get $w l2]) with the foreign file planted" \
    [list [dict get $w l1] [dict get $w l2] [expr {[dict get $w fbak0] ne {-}}]] {1 2 1}
check "G1 a FOREIGN bandgap~.sch: no prompt on the way up" [dict get $w asks] 0
check "G1b bandgap comes back CLEAN at its DISK geometry, p2 at 150 -130 (level/modified/p2)" \
    [lrange [dict get $w up1] 0 2] {1 0 {150 -130}}
check "G1c the foreign file is byte-identical and its mtime unchanged after the walk" \
    [list [expr {[dict get $w fbak1] eq [dict get $w fbak0]}] [expr {[dict get $w fmt1] eq [dict get $w fmt0]}]] {1 1}
check "G1d the top comes back clean" [lrange [dict get $w up2] 0 1] {0 0}

set w [walk {} 1 yes 0]
check "G2 answering YES with descend_readonly 0: no prompt, and bandgap.sch is byte-identical" \
    [list [dict get $w asks] [expr {[dict get $w bg1] eq [dict get $w bg0]}] [expr {[dict get $w fbak1] eq [dict get $w fbak0]}]] {0 1 1}
check "G3 hierarchy_modified at the leaf does not count the foreign ancestor backup" \
    [dict get $w hm_leaf] 0

set w [walk top 0 no 1]
check "G4 (control) edits at the TOP survive the walk: restored and still modified (level/modified/wires)" \
    [dict get $w up2] [list 0 1 [dict get $w tbw_edit]]
check "G4b (control) the edit was real (wires [dict get $w tbw0] -> [dict get $w tbw_edit]),\
       and hierarchy_modified counts it from the leaf" \
    [list [expr {[dict get $w tbw_edit] == [dict get $w tbw0] + 1}] [dict get $w hm_leaf]] {1 1}

set w [walk mid 0 no 0]
check "G5 (control) edits at the MIDDLE level are restored by go_back, still modified (level/modified/wires)" \
    [list {*}[lrange [dict get $w up1] 0 1] [lindex [dict get $w up1] 3]] [list 1 1 [dict get $w bgw_edit]]
check "G5b (control) the edit was real, the next go_back prompted once, and no dropped OUR backup" \
    [list [expr {[dict get $w bgw_edit] == [dict get $w bgw0] + 1}] [dict get $w asks_up1] [dict get $w asks] [dict get $w fbak1]] {1 0 1 -}

set w [walk top 1 no 1]
check "G6 own edits at the top AND a foreign ~ in the middle: the middle loads clean from disk\
       (level/modified/p2)" [lrange [dict get $w up1] 0 2] {1 0 {150 -130}}
check "G6b the top's own edits come back, still modified; no prompt; the foreign file untouched" \
    [list {*}[dict get $w up2] [dict get $w asks] [expr {[dict get $w fbak1] eq [dict get $w fbak0]}]] \
    [list 0 1 [dict get $w tbw_edit] 0 1]

set ::descend_readonly 0
fresh $TB
set tbw0 [xschem get wires]
xschem wire -2000 -2000 -1900 -2000
xschem unselect_all; xschem select instance x1
set ds [xschem descend_symbol]
set g7_lvl [xschem get currsch]
set g7_name [file tail [xschem get schname]]
xschem go_back
check "G7 (control) unsaved edits survive descend_symbol ($g7_name at level $g7_lvl, rc $ds) and its go_back" \
    [list $ds $g7_lvl [xschem get currsch] [xschem get modified] [xschem get wires]] [list 1 1 0 1 [expr {$tbw0 + 1}]]

## G8: the ownership comparison on its own. The top is edited with autosave_backup OFF, so it is
## modified and wrote no backup; a foreign tb_bandgap~.sch (the cell plus two wires) sits beside it;
## autosave is back on when the walk descends. The flag and the setting both say "has a backup", and
## only the comparison with the path this session wrote says that file is not ours.
set ::descend_readonly 1
fresh $TB
set tbw0 [xschem get wires]
set fd [open $TB r]; set t [read $fd]; close $fd
set fd [open $TBB w]
puts -nonewline $fd "[string trimright $t \n]\nN -3000 -3000 -2900 -3000 {}\nN -3000 -3100 -2900 -3100 {}\n"
close $fd
file mtime $TBB [expr {[file mtime $TB] + 60}]
set g8_f0 [md5f $TBB]
set ::autosave_backup 0
xschem wire -2000 -2000 -1900 -2000
set g8_edit [list [xschem get modified] [md5f $TBB]]
set ::autosave_backup 1
down
set g8_lvl [xschem get currsch]
xschem go_back
check "G8 an edit made with autosave_backup OFF beside a FOREIGN tb_bandgap~.sch: go_back does not\
       adopt it (level/modified/wires, foreign file unchanged)" \
    [list [xschem get currsch] [xschem get modified] [xschem get wires] [expr {[md5f $TBB] eq $g8_f0}]] \
    [list 0 0 $tbw0 1]
check "G8n the edit flagged the top and wrote nothing (the ~ is still the foreign one), and the walk\
       descended (level $g8_lvl)" [list {*}$g8_edit $g8_lvl] [list 1 $g8_f0 1]
set ::descend_readonly 0

## G9: edits this session DISCARDED by reloading the cell leave its ~ on disk (a load keeps the
## owned path on purpose, issue 1486) -- the file is ours, but the level is clean, so a descend and
## a go_back must not bring the discarded edits back.
fresh $TB
set tbw0 [xschem get wires]
xschem wire -2000 -2000 -1900 -2000
set ::asks 0
xschem load $TB
set g9_reload [list [xschem get modified] [xschem get wires] [file exists $TBB] $::asks]
down
xschem go_back
check "G9 edits discarded by a reload are not resurrected from this session's stale ~ by go_back\
       (level/modified/wires)" [list [xschem get currsch] [xschem get modified] [xschem get wires]] [list 0 0 $tbw0]
check "G9n the reload really discarded the edit and left the stale ~ on disk (modified/wires/~/asks)" \
    $g9_reload [list 0 $tbw0 1 0]

## G10: the record travels with the hierarchy. Edit the top, descend in place, then descend
## into a NEW window (hi_descend, which copies this window's hierarchy with copy_hierarchy and
## descends there). Going back up in the new window reaches the top through levels this window
## descended: its own edits must still come back, as they did before the record existed.
fresh $TB
set tbw0 [xschem get wires]
xschem wire -2000 -2000 -1900 -2000
down
set g10_w1 [xschem get current_win_path]
xschem unselect_all; xschem select instance x1
hi_descend target=new_window
set g10_w2 [xschem get current_win_path]
set g10_l2 [list [xschem get currsch] [file tail [xschem get schname]]]
xschem go_back
xschem go_back
check "G10 own edits at the top come back through a descend-in-new-window's go_back\
       (new window, level/modified/wires)" \
    [list [expr {$g10_w2 ne $g10_w1}] [xschem get currsch] [xschem get modified] [xschem get wires]] \
    [list 1 0 1 [expr {$tbw0 + 1}]]
check "G10n the new window opened at the leaf (level, sheet)" $g10_l2 {2 bandgap_opamp.sch}
catch {xschem new_schematic destroy_all force}

}
# ================================================================================================
# E -- the display arm: real Tk events, with the issue's rc
# ================================================================================================
band E {
if {[info commands winfo] eq {} || ![winfo exists .drw]} {
    puts "SKIP: band E (E1 E2 E3 E4) needs real Tk events and a .drw canvas; it runs on the display arm"
} else {
    set launch_library_manager 0
    source [file join $REPO sky130A cadence_style_rc]
    catch {destroy .libmgr}
    fixture_paths
    set ::E_rc [list $::fluid_editing $::cadence_compat $::fluid_enforce_invariants $::descend_readonly]
    wm geometry . 1400x1000+0+0; update
    set ::EVT [expr {[clock milliseconds] & 0x3fffffff}]
    proc evt {} { incr ::EVT 700 }
    proc ev_motion {px py {st 0}} { event generate .drw <Motion> -x $px -y $py -state $st -when now }
    proc ev_press {px py} { event generate .drw <ButtonPress-1> -x $px -y $py -state 0 -time [evt] -when now }
    proc ev_release {px py} { event generate .drw <ButtonRelease-1> -x $px -y $py -state 256 -time [evt] -when now }
    proc ev_key {k px py} {
        event generate .drw <KeyPress-$k> -x $px -y $py -when now
        event generate .drw <KeyRelease-$k> -x $px -y $py -when now
    }
    proc w2s {x y} {
        list [expr {int(($x + [xschem get xorigin]) / [xschem get zoom])}] \
             [expr {int(($y + [xschem get yorigin]) / [xschem get zoom])}]
    }
    ## the issue's gesture on bandgap.sch: select l1 p2 p4, press on l1, twelve motions, Escape,
    ## release. Returns {samples hit} with samples = pre, pressed, motion1..12, escape, released.
    proc edrag {plant} {
        fresh $::BG
        xschem zoom_full; update; xschem redraw; update
        event generate .drw <Enter> -x 700 -y 500 -when now; focus -force .drw; update
        lassign [ibb l1] x1 y1 x2 y2
        set hit {}
        foreach {fx fy} {0.5 0.5 0.5 0.9 0.5 0.95 0.2 0.9 0.8 0.9 0.5 0.1 0.1 0.5 0.9 0.5} {
            lassign [w2s [expr {$x1 + ($x2 - $x1) * $fx}] [expr {$y1 + ($y2 - $y1) * $fy}]] px py
            xschem unselect_all; update
            ev_motion $px $py; ev_press $px $py; ev_release $px $py; update
            if {[xschem get lastsel] == 1 && [lindex [xschem selected_set] 0] eq {l1}} {
                set hit [list $px $py]; break
            }
        }
        xschem unselect_all; update
        if {$hit eq {}} { return [list {} {}] }
        lassign $hit px py
        if {$plant} { xschem wire -400 -900 -300 -900; update }
        foreach n {l1 p2 p4} { xschem select instance $n fast }
        update
        set s [list [bstate]]
        ev_motion $px $py; update
        ev_press $px $py; update
        lappend s [bstate]
        for {set k 1} {$k <= 12} {incr k} {
            set mx [expr {$px + 6 * $k}]; set my [expr {$py + 4 * $k}]
            ev_motion $mx $my 256; update
            lappend s [bstate]
        }
        ev_key Escape $mx $my; update
        lappend s [bstate]
        ev_release $mx $my; update
        lappend s [bstate]
        return [list $s $hit]
    }
    proc e_moved {s} {
        set p0 [lindex $s 0 2]; set n 0
        foreach x [lrange $s 2 13] { if {[lindex $x 2] ne $p0} { incr n } }
        list [expr {$n >= 6}] [expr {[lindex $s end 2] eq $p0}]
    }
    check "E0 the rc is live (fluid_editing cadence_compat enforce descend_readonly = $::E_rc)" $::E_rc {1 1 1 1}

    lassign [edrag 0] s hit
    check "E0b a click point on l1 was found ($hit)" [expr {$hit ne {}}] 1
    check "E1 real-event drag + Escape of a CLEAN sheet: never modified, no backup (deviating samples)" \
        [deviations $s 0 -] {}
    check "E1n non-vacuity: STARTMOVE at all twelve motions, p2 moved on at least six of them, and\
           it is back after Escape" [list [nmoving $s 2 13] {*}[e_moved $s]] {12 1 1}

    lassign [edrag 1] s hit
    set pre_bak [lindex $s 0 1]
    check "E2 real-event drag + Escape of a DIRTY sheet: its backup byte-identical throughout, still modified" \
        [deviations $s 1 $pre_bak] {}
    check "E2n non-vacuity: the planted edit wrote a backup, STARTMOVE at all twelve motions, p2\
           moved and came back" [list [expr {$pre_bak ne {-}}] [nmoving $s 2 13] {*}[e_moved $s]] {1 12 1 1}

    ## E4: E1's gesture ended by a KEY pressed with Button-1 still held, instead of by Escape:
    ## press on l1, four motions, the key, two more motions, Escape, release
    proc ekey {key} {
        fresh $::BG
        xschem zoom_full; update; xschem redraw; update
        event generate .drw <Enter> -x 700 -y 500 -when now; focus -force .drw; update
        lassign [ibb l1] x1 y1 x2 y2
        set hit {}
        foreach {fx fy} {0.5 0.5 0.5 0.9 0.5 0.95 0.2 0.9 0.8 0.9 0.5 0.1 0.1 0.5 0.9 0.5} {
            lassign [w2s [expr {$x1 + ($x2 - $x1) * $fx}] [expr {$y1 + ($y2 - $y1) * $fy}]] px py
            xschem unselect_all; update
            ev_motion $px $py; ev_press $px $py; ev_release $px $py; update
            if {[xschem get lastsel] == 1 && [lindex [xschem selected_set] 0] eq {l1}} {
                set hit [list $px $py]; break
            }
        }
        xschem unselect_all; update
        if {$hit eq {}} { return {} }
        lassign $hit px py
        foreach n {l1 p2 p4} { xschem select instance $n fast }
        update
        set p0 [ixy p2]
        ev_motion $px $py; update
        ev_press $px $py; update
        for {set k 1} {$k <= 4} {incr k} {
            set mx [expr {$px + 6 * $k}]; set my [expr {$py + 4 * $k}]
            ev_motion $mx $my 256; update
        }
        set pre [list [expr {[xschem get ui_state] & 32}] [xschem get modified] [file exists $::BGB]]
        event generate .drw <KeyPress-$key> -x $mx -y $my -state 256 -when now
        event generate .drw <KeyRelease-$key> -x $mx -y $my -state 256 -when now
        update
        set post [expr {[xschem get ui_state] & 32}]
        for {set k 5} {$k <= 6} {incr k} {
            set mx [expr {$px + 6 * $k}]; set my [expr {$py + 4 * $k}]
            ev_motion $mx $my 256; update
        }
        ev_key Escape $mx $my; update
        ev_release $mx $my; update
        list $pre $post [xschem get modified] [xschem get hierarchy_modified] \
            [expr {[filed $::BGB] eq [onscreen]}] [expr {[ixy p2] ne $p0}]
    }
    set k [ekey u]
    check "E4 the REAL 'u' key (undo) pressed mid-drag ends the gesture with no END or ABORT, and the\
           moved shapes stay DECLARED: modified, hierarchy_modified, the ~ holds the sheet on screen" \
        [lrange $k 2 4] {1 1 1}
    check "E4n non-vacuity: STARTMOVE, no flag and no ~ before the key; STARTMOVE gone after it; p2 moved\
           ($k)" [list {*}[lindex $k 0] [lindex $k 1] [lindex $k 5]] {32 0 0 0 1}

    set w [walk {} 1 no $::descend_readonly]
    check "E3 issue 1715's walk under the rc: no prompt, bandgap clean at its disk geometry,\
           the foreign file untouched (asks/level/modified/p2/same)" \
        [list [dict get $w asks] {*}[lrange [dict get $w up1] 0 2] [expr {[dict get $w fbak1] eq [dict get $w fbak0]}]] \
        {0 1 0 {150 -130} 1}
}

}
# ================================================================================================
# K -- G1 through REAL keys and menus: a verb that quits, closes, goes up, clears or opens, reached
#      while a fluid drag is live (Button-1 still held, or a keyboard 'm' move), asks about the drag
# ================================================================================================
band K {
if {[info commands winfo] eq {} || ![winfo exists .drw]} {
    puts "SKIP: band K (K1-K18) drives real keys and menus on a .drw canvas; it runs on the display arm"
} else {
    set ::K_BG0 [md5f [file join $SRCL bandgap schematic bandgap.sch]]
    ## quit and close must not happen here: the REAL hierarchy_close runs (its end_live_drag, its
    ## prompts, its save or its discard) and its answer is recorded, then the teardown is refused
    rename ::hierarchy_close ::k_real_hc
    proc ::hierarchy_close {action} { set r [::k_real_hc $action]; lappend ::k_hc [list $action $r]; return 0 }
    ## every other dialog a verb could open is counted and declined, so none can block
    rename ::tk_messageBox ::k_real_mb
    proc ::tk_messageBox {args} { lappend ::k_mb [dict get $args -message]; return cancel }
    rename ::load_file_dialog ::k_real_lfd
    proc ::load_file_dialog {args} { incr ::k_lfd; return {} }
    proc kpristine {} { file copy -force [file join $::SRCL bandgap schematic bandgap.sch] $::BG }
    ## the canvas the events go to: .drw, or a separate window's own (K15, K17)
    set ::KW .drw
    proc kev_motion {px py {st 0}} { event generate $::KW <Motion> -x $px -y $py -state $st -when now }
    proc kev_press {px py} { event generate $::KW <ButtonPress-1> -x $px -y $py -state 0 -time [evt] -when now }
    proc kev_release {px py} { event generate $::KW <ButtonRelease-1> -x $px -y $py -state 256 -time [evt] -when now }
    proc kev_key {k px py} {
        event generate $::KW <KeyPress-$k> -x $px -y $py -when now
        event generate $::KW <KeyRelease-$k> -x $px -y $py -when now
    }
    ## l1 p2 p4 of the bandgap sheet on screen, live in four motions: pressed and held (hold) or moved
    ## by the keyboard 'm' (m). Returns {mx my p0} (pointer, p2 before) or {} with no click point on l1.
    proc klive {mode} {
        xschem zoom_full; update; xschem redraw; update
        event generate $::KW <Enter> -x 700 -y 500 -when now; focus -force $::KW; update
        lassign [ibb l1] x1 y1 x2 y2
        set hit {}
        foreach {fx fy} {0.5 0.5 0.5 0.9 0.5 0.95 0.2 0.9 0.8 0.9 0.5 0.1 0.1 0.5 0.9 0.5} {
            lassign [w2s [expr {$x1 + ($x2 - $x1) * $fx}] [expr {$y1 + ($y2 - $y1) * $fy}]] px py
            xschem unselect_all; update
            kev_motion $px $py; kev_press $px $py; kev_release $px $py; update
            if {[xschem get lastsel] == 1 && [lindex [xschem selected_set] 0] eq {l1}} {
                set hit [list $px $py]; break
            }
        }
        xschem unselect_all; update
        if {$hit eq {}} { return {} }
        lassign $hit px py
        foreach n {l1 p2 p4} { xschem select instance $n fast }
        update
        set p0 [ixy p2]
        kev_motion $px $py; update
        if {$mode eq "hold"} { kev_press $px $py; set st 256 } else { kev_key m $px $py; set st 0 }
        update
        for {set k 1} {$k <= 4} {incr k} {
            set mx [expr {$px + 6 * $k}]; set my [expr {$py + 4 * $k}]
            kev_motion $mx $my $st; update
        }
        return [list $mx $my $p0]
    }
    proc kp2 {} { if {[catch {ixy p2} p]} { return - }; return $p }
    ## one drive: the drag live at $lvl (top: bandgap.sch; child: tb_bandgap -> x1, editable), then
    ## the key with modifier state $mods (Button1Mask added when held) or a menu entry
    ## (menu:<label>), the user answering $ans. Then, when held, two more motions and the release.
    proc kdrive {lvl mode key mods ans} {
        set ::ANSWER $ans; set ::asks 0; set ::k_hc {}; set ::k_mb {}; set ::k_lfd 0
        if {$lvl eq "top"} { fresh $::BG } else {
            fresh $::TB; xschem unselect_all; xschem select instance x1; xschem descend
        }
        set g [klive $mode]
        if {$g eq {}} { return [dict create hit 0] }
        lassign $g mx my p0
        set plive [kp2]
        set d [dict create hit 1 p0 $p0 pre [list [expr {[xschem get ui_state] & 32}] [xschem get modified] \
            [file exists $::BGB] [expr {$plive ne $p0}]]]
        set bst [expr {$mode eq "hold" ? 256 : 0}]
        if {$::K_LF ne {}} { set ::k_logpos [file size $::K_LF] }
        if {[string match emenu:* $key]} {
            if {[catch {.menubar.edit invoke [string range $key 6 end]} e]} { dict set d menuerr $e }
        } elseif {[string match menu:* $key]} {
            if {[catch {.menubar.file invoke [string range $key 5 end]} e]} { dict set d menuerr $e }
        } else {
            event generate .drw <KeyPress-$key> -x $mx -y $my -state [expr {$mods | $bst}] -when now
            event generate .drw <KeyRelease-$key> -x $mx -y $my -state [expr {$mods | $bst}] -when now
        }
        update
        set ::ANSWER no
        dict set d post [list $::asks $::k_hc [llength $::k_mb] $::k_lfd [xschem get currsch] \
            [expr {[xschem get ui_state] & 32}] [xschem get modified]]
        dict set d bak [expr {[filed $::BGB] eq [list [kp2] [xschem get instances] [xschem get wires]]}]
        dict set d file [list [expr {[md5f $::BG] eq $::K_BG0}] [lindex [filed $::BG] 0]]
        dict set d plive $plive
        dict set d sheet [file tail [xschem get schname]]
        dict set d kept [expr {[kp2] eq $plive}]
        if {$mode eq "hold"} {
            foreach k {5 6} { ev_motion [expr {$mx + 6 * ($k - 4)}] [expr {$my + 4 * ($k - 4)}] 256; update }
            set m0 [xschem get modified]
            ev_release [expr {$mx + 12}] [expr {$my + 8}]; update
            dict set d release [list [expr {[xschem get ui_state] & 48}] [xschem get modified] \
                [expr {[kp2] eq $plive || [xschem get currsch] != ($lvl eq "child")}]]
        }
        return $d
    }
    ## the open action log, or {} under --nolog (run_suites.sh's default; T1's display arm passes --logdir)
    set ::K_LF [xschem get actionlog_filename]
    proc klogtail {} {
        set fd [open $::K_LF r]; seek $fd $::k_logpos; set t [read $fd]; close $fd
        return [split [string trimright $t \n] \n]
    }
    ## the three answers to each of the three keys; Ctrl-E goes up, so it is driven one level down
    set ::descend_readonly 0
    foreach {key lvl verb rows} {q top quit {K1 K2 K3} w top close {K4 K5 K6} e child up {K7 K8 K9}} {
        foreach ans {{} no yes} row $rows {
            set d [kdrive $lvl hold $key 4 $ans]
            if {![dict get $d hit]} { check "$row a click point on l1 was found" 0 1; continue }
            set aname [expr {$ans eq {} ? {CANCEL} : [string toupper $ans]}]
            lassign [dict get $d post] asks hc nmb nlfd lvlafter live mod
            set hc1 [lindex $hc 0 1]
            set pre [dict get $d pre]
            if {$ans eq {}} {
                set want [list 1 [expr {$key eq "e" ? 1 : 0}] 0 1 1 [list 1 [dict get $d p0]] 1 {0 1 1}]
                set got [list $asks $lvlafter $live $mod [dict get $d bak] [dict get $d file] \
                    [dict get $d kept] [dict get $d release]]
                set what "it asked; the gesture is over, the sheet stays modified with a ~ holding the\
                          screen, the cell file is untouched, p2 stays where the drag put it; the release\
                          after it changes nothing (asks/level/STARTMOVE/modified/~/file/p2-kept/release)"
            } elseif {$ans eq "no"} {
                ## (at the top a No leaves the buffer to the teardown this test refuses, so only the child's
                ## go-up has a "modified" to read: the parent it lands on)
                set want [list 1 0 [expr {$key eq "e" ? 0 : $mod}] 0 [list 1 [dict get $d p0]]]
                set got [list $asks $lvlafter $mod [file exists $::BGB] [dict get $d file]]
                set what "it asked, the drag is dropped with the level's other edits: no ~ is left, the\
                          cell file is untouched (asks/level/modified-parent/~/file)"
            } else {
                set want [list 1 0 0 [list 0 [dict get $d plive]]]
                set got [list $asks $mod [file exists $::BGB] [dict get $d file]]
                set what "it asked, and the cell file now holds p2 where the screen had it, clean, no ~\
                          (asks/modified/~/file-untouched+p2)"
                kpristine
            }
            if {$key ne "e"} { lappend want [list [list $verb [expr {$ans eq {} ? 0 : 1}]]]; lappend got $hc }
            check "$row Ctrl-[string toupper $key] with Button-1 still held mid-drag ([expr {$lvl eq {top} ? {at the top} : {in the child}}]),\
                   answered $aname: $what[expr {$key ne {e} ? {, and hierarchy_close answered} : {}}]" $got $want
            check "${row}n non-vacuity: before the key the drag was live, unflagged, with no ~, and p2 had\
                   moved (STARTMOVE/modified/~/p2-moved)" $pre {32 0 0 1}
        }
    }
    ## Ctrl-Q one level down: the walk up asks at the child first, and Cancel stops it there
    set d [kdrive child hold q 4 {}]
    if {[dict get $d hit]} {
        lassign [dict get $d post] asks hc nmb nlfd lvlafter live mod
        check "K10 Ctrl-Q held mid-drag in the CHILD, answered CANCEL at the child's prompt: the walk stops\
               there, the child modified with its ~, the gesture over (asks/hierarchy_close/level/STARTMOVE/modified/~)" \
            [list $asks $hc $lvlafter $live $mod [dict get $d bak]] {1 {{quit 0}} 1 0 1 1}
    } else { check "K10 a click point on l1 was found" 0 1 }
    ## File > Close schematic is `xschem exit`: in the main window it asks through tk_messageBox
    set d [kdrive top m {menu:Close schematic} 0 {}]
    if {[dict get $d hit]} {
        lassign [dict get $d post] asks hc nmb nlfd lvlafter live mod
        check "K11 File > Close schematic during a keyboard 'm' move: the UNSAVED prompt appears and,\
               declined, the sheet stays, modified, the gesture over (prompts/sheet/STARTMOVE/modified/~)" \
            [list $nmb [dict get $d sheet] $live $mod [dict get $d bak]] {1 bandgap.sch 0 1 1}
    } else { check "K11 a click point on l1 was found" 0 1 }
    ## (under the rc Ctrl-N opens a new WINDOW, which discards nothing: File > Clear Schematic is the
    ## clear here; band V drives it scripted, and without the rc Ctrl-N reaches the same clear_schematic)
    foreach {row key mods mode name} {K12 {menu:Clear Schematic} 0 m {File > Clear Schematic during an 'm' move} K13 o 4 hold {Ctrl-O (open in place) held}} {
        set d [kdrive top $mode $key $mods {}]
        if {![dict get $d hit]} { check "$row a click point on l1 was found" 0 1; continue }
        lassign [dict get $d post] asks hc nmb nlfd lvlafter live mod
        check "$row $name mid-drag, answered CANCEL: it asked before anything else, no file dialog opened,\
               the sheet stays, modified, the gesture over (asks/dialogs/sheet/STARTMOVE/modified/~)" \
            [list $asks $nlfd [dict get $d sheet] $live $mod [dict get $d bak]] {1 0 bandgap.sch 0 1 1}
    }
    ## a TAB left with its drag live: an 'm' move in a second tab, a click on the main tab, then the
    ## part of Quit that closes the other tabs (xschem new_schematic destroy_all, as quit_xschem calls it)
    xschem new_schematic destroy_all force; update
    fresh $TB
    set ::k_mb {}
    xschem load_new_window $BG; update
    set ktab [xschem get current_win_path]
    set g [klive m]
    if {$g eq {}} { check "K14 a click point on l1 was found in the tab" 0 1 } else {
        set kpre [list [expr {[xschem get ui_state] & 32}] [xschem get modified]]
        xschem new_schematic switch .drw; update
        set kon [file tail [xschem get schname]]
        xschem new_schematic destroy_all; update
        set kmb $::k_mb
        set ktabs [xschem new_schematic ntabs]
        xschem new_schematic switch $ktab; update
        check "K14 Quit with another tab's drag left live: that tab's UNSAVED prompt appears and, declined,\
               the tab stays, modified, its gesture over (from/prompts/other-tabs/STARTMOVE/modified/~; live\
               before the switch: $kpre)" \
            [list $kon [llength $kmb] [string match {bandgap*UNSAVED*} [lindex $kmb 0]] $ktabs \
                 [expr {[xschem get ui_state] & 32}] [xschem get modified] \
                 [expr {[filed $BGB] eq [list [kp2] [xschem get instances] [xschem get wires]]}]] \
            {tb_bandgap.sch 1 1 1 0 1 1}
    }
    xschem new_schematic destroy_all force; update
    ## the action log of a verb that ended the drag: the move is recorded as the release would record
    ## it, and the verb keeps its own line (menu_action_logged drops a pick's line when anything inside
    ## it logged, so the drag's end must not count as the verb having logged itself)
    if {$::K_LF eq {}} {
        puts "SKIP: K18 needs the action log, which --nolog disables (T1's display arm passes --logdir)"
    } else {
        set d [kdrive child m emenu:Pop 0 {}]
        if {![dict get $d hit]} { check "K18 a click point on l1 was found" 0 1 } else {
            set tl [klogtail]
            set im [lsearch -regexp $tl {^xschem move_objects }]
            set ig [lsearch -all -exact $tl {xschem go_back}]
            check "K18 Edit > Pop in the child during an 'm' move, answered Cancel: it asked, and the action\
                   log gains the move line and then the menu's own 'xschem go_back' line, once\
                   (asked/move found/go_back count/in order; the lines: $tl)" \
                [list [lindex [dict get $d post] 0] [expr {$im >= 0}] [llength $ig] \
                     [expr {$im >= 0 && [llength $ig] == 1 && $im < [lindex $ig 0]}]] \
                {1 1 1 1}
        }
    }
    xschem new_schematic destroy_all force; update
    ## a TAB closed directly (`xschem new_schematic destroy <tab>`) while its drag is live
    fresh $TB
    set ::k_mb {}
    xschem load_new_window $BG; update
    set ktab [xschem get current_win_path]
    set g [klive m]
    if {$g eq {}} { check "K16 a click point on l1 was found in the tab" 0 1 } else {
        xschem new_schematic destroy $ktab; update
        check "K16 'xschem new_schematic destroy' of the current tab during its 'm' move: the UNSAVED prompt\
               appears and, declined, the tab stays, modified, the gesture over (prompts/tab/STARTMOVE/modified/~)" \
            [list [llength $::k_mb] [xschem get current_win_path] [expr {[xschem get ui_state] & 32}] \
                 [xschem get modified] [expr {[filed $BGB] eq [list [kp2] [xschem get instances] [xschem get wires]]}]] \
            [list 1 $ktab 0 1 1]
    }
    xschem new_schematic destroy_all force; update
    ## a separate WINDOW: its window manager close button while its drag is live (K15), and, with the
    ## tabbed interface off, Quit's closing of the other windows (K17)
    foreach {row tabbed} {K15 1 K15b 0 K17 0} {
        set ::tabbed_interface $tabbed
        fresh $TB
        set ::k_mb {}
        xschem new_schematic create_window {} $BG; update
        set kwin [xschem get current_win_path]
        set ::KW $kwin
        if {![winfo exists $kwin]} {
            check "$row the separate window's canvas exists ($kwin)" 0 1
        } else {
            wm geometry [winfo toplevel $kwin] 1400x1000+0+0; update
            set g [klive m]
            if {$g eq {}} { check "$row a click point on l1 was found in the window" 0 1 } else {
                ## K15b drives the script build_widgets installs on a window made with the tabbed interface
                ## off; the toplevel can be reused with its earlier protocol, so it is not read back
                set kproto [string trim [wm protocol [winfo toplevel $kwin] WM_DELETE_WINDOW]]
                if {$row eq "K15b"} { set kproto "xschem new_schematic destroy $kwin {}" }
                if {$row ne "K17"} {
                    uplevel #0 $kproto; update
                } else {
                    xschem new_schematic switch .drw; update
                    xschem new_schematic destroy_all; update
                    xschem new_schematic switch $kwin; update
                }
                ## the close button runs `xschem exit closewindow` with the tabbed interface on and
                ## `xschem new_schematic destroy <window>` with it off (set when the window is made)
                set what [expr {$row eq "K15" ? "its window manager close button (tabbed interface on)" : \
                    $row eq "K15b" ? "the close script of a window made with the tabbed interface off" : \
                    "Quit closing the other windows (tabbed interface off), with the main window current"}]
                check "$row a separate window's 'm' move, then $what: the UNSAVED prompt appears and,\
                       declined, the window stays, modified, the gesture over\
                       (prompts/window/STARTMOVE/modified/~; the close script: [regsub -all {\s+} $kproto { }])" \
                    [list [llength $::k_mb] [winfo exists $kwin] [expr {[xschem get ui_state] & 32}] \
                         [xschem get modified] [expr {[filed $BGB] eq [list [kp2] [xschem get instances] [xschem get wires]]}]] \
                    {1 1 0 1 1}
            }
        }
        set ::KW .drw
        xschem new_schematic switch .drw; update
        xschem new_schematic destroy_all force; update
        set ::tabbed_interface 1
    }
    set ::descend_readonly 1
    rename ::hierarchy_close {}; rename ::k_real_hc ::hierarchy_close
    rename ::tk_messageBox {}; rename ::k_real_mb ::tk_messageBox
    rename ::load_file_dialog {}; rename ::k_real_lfd ::load_file_dialog
    fresh $TB
}
}
band Z {
fresh $TB
xschem clear force
sweep_backups
check "Z1 no SCRIPTED load in the bands above offered crash recovery (only an interactive\
       'xschem load -gui' makes the offer, and none of them is one)" $::recovers 0
if {[info commands winfo] eq {} || ![winfo exists .drw]} {
    puts "SKIP: band Z (Z2 Z3) drives the crash-recovery offer, which only an interactive load makes,\
          and only with a display (has_x); it runs on the display arm"
} elseif {[info commands ::z_real_recover] eq {}} {
    check "Z2 the product's xschem_recover_backup was kept aside for this band" 0 1
} else {
    ## the product's own offer, with its dialog answered here instead of by a person
    rename ::xschem_recover_backup {}
    rename ::z_real_recover ::xschem_recover_backup
    proc ::tk_messageBox {args} { lappend ::z_mb [dict get $args -title]; return $::z_answer }
    ## the 1715 state: a bandgap~.sch this session never wrote, newer than the cell, is KEPT by the
    ## walk -- this is the one place that keeping it pays off for the user
    ## The door is an interactive open INTO a pristine untitled window (what File > Open does in a
    ## fresh xschem): a -gui open from an occupied window is routed to a new one, which makes no
    ## offer at all (measured; see the header). Planted AFTER the clear, which drops this session's
    ## own last backup and could otherwise take the planted file with it.
    foreach {row ans} {Z2 yes Z3 no} {
        fresh $TB
        xschem clear force
        plant_foreign
        set ::z_answer $ans; set ::z_mb {}
        xschem load -gui $BG
        set z($row) [list $::z_mb [file tail [xschem get schname]] [xschem get modified] [ixy p2] [file exists $BGB]]
    }
    check "Z2 an interactive load of a cell with a crash backup OFFERS recovery once, and Yes restores\
           the backup: modified, p2 at the backup's 220 -80 (offers/sheet/modified/p2/~)" \
        $z(Z2) {{{Recover unsaved changes?}} bandgap.sch 1 {220 -80} 1}
    check "Z3 the same offer answered No: the sheet is clean at its disk geometry and the backup is\
           discarded, as the dialog says (offers/sheet/modified/p2/~)" \
        $z(Z3) {{{Recover unsaved changes?}} bandgap.sch 0 {150 -130} 0}
    rename ::tk_messageBox {}
    fresh $TB
}

}
} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

# `OVERALL: ok` is the completion sentinel tests/banner_rule.tcl's banner_complete requires
# (issue 1652); `RESULT:` stays LAST because summarize_all publishes a case's last RESULT line.
if {$fail == 0} { puts "OVERALL: ok ($npass checks)"
                  puts "RESULT: ALL PASS ($npass checks)" } \
else            { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
