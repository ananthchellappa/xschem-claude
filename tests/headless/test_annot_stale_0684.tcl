# tests/headless/test_annot_stale_0684.tcl -- ISSUE 0684, BOTH OPERATING-POINT
# SURFACES: the schematic keeps painting the PREVIOUS run's id / gm / gds.
#
# ============================================================================
# WHAT THE USER SEES, AND WHY THIS FILE EXISTS
# ============================================================================
# Press 6. Numbers appear. Change a device, re-run the simulation, press 6
# again -- the sheet repaints the PREVIOUS run's numbers under a sentence
# saying the results were already loaded. Nothing on screen distinguishes it
# from a correct annotation. RULING D5-1 and invariant I3 in their own words:
# "A missing vector renders BLANK. Not 0, not NaN on screen, not the previous
# run's number."
#
# Measured 2026-08-28 on the shipped in-tree binary, both arms:
#   press 6            -> id = 10u | gm = 100u | gds = 1u
#   the run is redone, the same path rewritten to id=9e-03
#   NO further gesture -> id = 10u | gm = 100u | gds = 1u
#   press 6 again      -> id = 10u | gm = 100u | gds = 1u, under
#                         "... These results were already loaded."
#   only Waves > Clear then 6 -> id = 9m | gm = 7m | gds = 50u
#
# ============================================================================
# THE THREE MEASURED TRAPS THIS FILE IS SHAPED AROUND
# ============================================================================
# 1. THE DECIDING LINE IS NOT THE GATE. cadence::_annot_op_db_ok answers 1
#    CORRECTLY for a stale operating point -- one really IS attached and its
#    sim_type really is op. Control then reaches cadence::annot_mode's
#    "if annotated -> state live" arm, which short-circuits every load path.
#    Tightening the gate alone leaves the old numbers on the sheet under a
#    sentence denying the analysis it is looking at. So the rows below drive
#    the CHORD, never the gate in isolation.
# 2. cadence::_annot_tran_db_current CANNOT BE CALLED AS IS. It consults
#    cadence::_annot_viewer_db, which reports a database only when the viewer's
#    sim_type is tran, so for an operating point it answers 1 = "current" both
#    before and after the disk changes. A fix that simply calls it passes while
#    doing nothing. The operating-point question is therefore minted once, as
#    op_annot::db_current, and BOTH operating-point surfaces call it.
# 3. xschem annotate_op NEVER RAISES for the failures that matter. Measured on
#    this binary: a missing path answers rc 0 with an EMPTY result, a garbage
#    file answers rc 0 with an EMPTY result AND destroys whatever was attached,
#    a good file answers rc 0 with "::op_annot::text". So an attach can only be
#    verified by RE-ASKING, and the shipped failure sentence in
#    ase::ui::annot_ensure_loaded -- which fires only inside a catch -- can
#    never actually be spoken. Rows F11, F26 and F32 own that.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE -- READ BEFORE TRUSTING IT
# ============================================================================
# * NO PIXELS. The block is read through op_annot::text, which is the ONE
#   renderer the overlay itself calls (op_annot.tcl's own gate). A green run
#   here is not proof the sheet repaints; that owes the user's eyes and is
#   recorded as a look debt.
# * NO SIMULATOR. A re-run is a rewrite of the same raw path, which is exactly
#   what ngspice does to <rundir>/<cell>_ase.raw.
# * file mtime is 1-second resolution, so every rewrite below is preceded by a
#   real sleep. A same-second rewrite of identical size is invisible to any
#   stamp and is a stated, unremoved limitation of the fix.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_annot_stale_0684.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_annot_stale_0684.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch annot_stale_0684]
set lib [file join $scratch lib]
set nd  [file join $scratch nd]
set nd2 [file join $scratch nd2]
file mkdir $lib $nd $nd2

# ============================================================================
# THE ANSWER DISCIPLINE -- an absent proc must never satisfy a golden
# ============================================================================
# Every helper below answers NOPROC when the thing it calls does not exist and
# RAISED:<text> when it blows up. A bare catch-and-discard would let
# "invalid command name op_annot::db_current" satisfy a row that expects 0,
# i.e. the whole file would go green against an absent namespace -- which is
# precisely the state of the tree this file was written in.
proc f_call {script} {
  set rc [catch {uplevel #0 $script} r]
  return [list $rc $r]
}
proc f_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc f_cur {cand}          { return [f_ans ::op_annot::db_current $cand] }
proc f_att {path {lvl {}}} { return [f_ans ::op_annot::db_attach $path $lvl] }
proc f_det {}              { return [f_ans ::op_annot::db_detach] }
proc f_ref {key}           { return [f_ans ::ase::ui::annot_refresh_after_run $key] }
# db_attach answers a two-element list; a row that only wants the ok half says so
proc f_attok {path {lvl {}}} {
  set r [f_att $path $lvl]
  if {$r eq {NOPROC} || [string match RAISED:* $r]} { return $r }
  return [lindex $r 0]
}

# --- what the sheet paints, as one line -------------------------------------
# op_annot::text is the block the overlay draws. The column padding is
# collapsed so a golden reads the way the user's eye reads it.
proc f_rows {{inst MZZ1}} {
  set r {}
  catch {set r [::op_annot::text $inst]}
  set r [string map [list "\n" { | }] [string trim $r]]
  regsub -all { +} $r { } r
  return $r
}
# the raw's own id vector, or a marker: `xschem raw value` RAISES with nothing
# attached, so it can never be called bare from a golden
proc f_val {vec} {
  if {[catch {xschem raw value $vec -1} r]} { return "RAISED:$r" }
  return $r
}
proc f_idx {vec} {
  if {[catch {xschem raw index $vec} r]} { return -1 }
  return $r
}
proc f_rawfile {} {
  if {[catch {xschem raw rawfile} r]} { return NONE }
  if {$r eq {}} { return NONE }
  return [file normalize $r]
}
proc f_info {} {
  set r {}
  catch {set r [xschem raw info]}
  set o {}
  foreach l [split [string trim $r] \n] {
    set l [string trim $l]
    if {$l eq {}} continue
    lappend o $l
  }
  return $o
}
# how many registry entries name <path>, whatever their sim_type
proc f_info_has {path} {
  set n 0
  set np [file normalize $path]
  foreach l [f_info] {
    if {[regexp {^([0-9]+)\s+(.*)\s+([A-Za-z0-9_]+)$} $l -> i p t]} {
      if {[catch {file normalize $p} pn]} continue
      if {$pn eq $np} { incr n }
    }
  }
  return $n
}
proc f_msg {} {
  set m {}
  catch {set m [xschem get statusmsg]}
  return $m
}
proc f_mask {} {
  set m 0
  catch {set m [xschem get annot_show]}
  if {![string is integer -strict $m]} { return -1 }
  return $m
}

# --- the fixtures ------------------------------------------------------------
# A 1-point operating point over ONE device, plus an optional extra vector so a
# row can tell "this database was left alone" from "this database was replaced".
proc f_mkop {path id gm gds {extra {}}} {
  set nv [expr {3 + ([llength $extra] ? 1 : 0)}]
  set f [open $path w]
  puts -nonewline $f "Title: 0684 stale-annotation fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: $nv
No. Points: 1
Variables:
\t0\ti(@m.xmzz1.mzz\[id\])\tcurrent
\t1\t@m.xmzz1.mzz\[gm\]\tadmittance
\t2\t@m.xmzz1.mzz\[gds\]\tadmittance
"
  if {[llength $extra]} { puts -nonewline $f "\t3\t$extra\tvoltage\n" }
  puts -nonewline $f "Values:
0\t$id
\t$gm
\t$gds
"
  if {[llength $extra]} { puts -nonewline $f "\t1.25\n" }
  close $f
}
# a TRANSIENT, i.e. the ordinary waveform graph a user has open. Two points, so
# it is unmistakably not an operating point.
proc f_mktran {path} {
  set f [open $path w]
  puts -nonewline $f "Title: 0684 foreign transient
Date: Mon Jan 1 00:00:00 2026
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(zzz)\tvoltage
Values:
0\t0
\t1.5

1\t1e-09
\t2.5
"
  close $f
}
# an unparseable file that IS present and IS readable -- the ordinary case of a
# simulator mid-rewrite, which is the case issue 0685 section 4 is about
proc f_mkjunk {path} {
  set f [open $path w]
  puts $f "ZZ this is not a spice raw database and never was"
  close $f
}
# ONE second of real time before a rewrite. `file mtime` is 1-second
# resolution, so without this a stamp cannot see the change and the whole file
# would measure the limitation instead of the defect.
proc f_bump {} { after 1100 }

set f [open [file join $lib zzfet.sym] w]
puts $f {v {xschem version=3.4.6 file_version=1.2}
G {}
K {type=zzs8fet
format="@name @pinlist @model"
template="name=MZZ1 model=zzdev"}
V {}
S {}
E {}
L 4 -10 -10 10 -10 {}
L 4 10 -10 10 10 {}
L 4 10 10 -10 10 {}
L 4 -10 10 -10 -10 {}}
close $f
set f [open [file join $lib mos.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}
G {}
V {}
S {}
E {}
C {[file join $lib zzfet.sym]} 0 0 0 0 {name=MZZ1}"
close $f

proc f_devproc {instname model path spiceprefix} { return {@m.xmzz1.mzz} }
catch {op_annot::register zzs8fet \
  [list devproc f_devproc params {{id id 0} {gm gm 1} {gds gds 1}}]}

set F_SCH  [file join $lib mos.sch]
set F_RAW  [file join $nd mos.raw]          ;# the session's own candidate
set F_OTHER [file join $nd2 corner.raw]     ;# another corner's operating point
set F_TRAN [file join $scratch foreign.raw] ;# an ordinary waveform graph
set F_JUNK [file join $nd mos.raw]          ;# the same path, made unreadable

set F_ID {i(@m.xmzz1.mzz[id])}
set F_R1 {id = 10u | gm = 100u | gds = 1u}
set F_R2 {id = 9m | gm = 7m | gds = 50u}
set F_BLANK {id = | gm = | gds =}

f_mktran $F_TRAN

# THE SENTENCES, byte for byte, as cadence::_annot_msg mints them. They are
# quoted here rather than composed so a row can tell "loaded the new file" from
# "these were already loaded" -- which on the shipped tree is the only thing on
# screen that differs between a correct annotation and the defect.
set F_M1 {Showing device operating-point values on the schematic.}
set F_M3 {Showing device operating-point values and DC node voltages on the schematic.}
set F_LIVE { These results were already loaded.}

# reach the surfaces under test the way a real session does
source [file join $repo utils annot_mode.tcl]
source [file join $repo src ase.tcl]
source [file join $repo src ase_window.tcl]

# --- source snapshots for the STRUCTURAL rows -------------------------------
# Taken BEFORE any stub is installed, so a row cannot read a test double's body
# and call it the product.
proc f_body {name} {
  if {![llength [info commands $name]]} { return NOPROC }
  return [info body $name]
}
# code lines only: a whole-line Tcl comment may name anything it likes
proc f_code {body} {
  if {$body eq {NOPROC}} { return {} }
  set o {}
  foreach l [split $body \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend o $l
  }
  return $o
}
proc f_lineidx {body re} {
  set i 0
  foreach l [f_code $body] {
    if {[regexp -- $re $l]} { return $i }
    incr i
  }
  return -1
}
proc f_pgrep {body re} {
  set n 0
  foreach l [f_code $body] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
# the LAST matching code line, or -1. Row F10b needs it: the forget it is about
# is the one on the FAILURE arm, below the verify, and `f_lineidx` would answer
# with the unrelated one at the top of the body every time.
proc f_lastidx {body re} {
  set i 0
  set last -1
  foreach l [f_code $body] {
    if {[regexp -- $re $l]} { set last $i }
    incr i
  }
  return $last
}
set F_B_ENSURE [f_body ::ase::ui::annot_ensure_loaded]
set F_B_FINISH [f_body ::ase::ui::run_finished]
set F_B_MODE   [f_body ::cadence::annot_mode]
set F_B_RELEASE [f_body ::cadence::_annot_db_release]

xschem load $F_SCH

# ===========================================================================
# F0 -- CONTROL: THE PREMISE. GREEN BEFORE AND AFTER, AND LOAD-BEARING
# ===========================================================================
# Without this row every row below degrades into a hollow pass: a fixture that
# never annotated at all would satisfy "the old numbers are gone".
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
set f0_blank [f_rows]
set f0_rc [f_call [list xschem annotate_op $F_RAW]]
set f0_rows [f_rows]
set f0_ann [f_call {::op_annot::_annotated}]
catch {xschem raw clear}
check {F0 CONTROL the fixture really annotates: blank with nothing attached, run 1's numbers with the operating point attached} \
  [list $f0_blank $f0_rc $f0_rows $f0_ann] \
  [list $F_BLANK {0 ::op_annot::text} $F_R1 {0 1}]

# ===========================================================================
# F1 .. F8 -- op_annot::db_current, THE ONE MINT (RULING D5-4, invariant I1)
# ===========================================================================
# The question this predicate answers is NOT the transient surface's question.
# TRAN asks "do two windows' in-memory copies agree"; OP asks "is the database
# this window is painting from still the file it was read from". An operating
# point run usually has no waveform window at all, so a viewer consult cannot
# answer it. Hence a second predicate, and hence the cross-reference this
# file's header carries.

# ⚠ THIS ROW DOES NOT OWN GUARD G1, AND ITS TITLE USED TO SAY IT DID (sabotage
# round 2026-08-28). With NOTHING attached at all, `xschem raw rawfile` RAISES,
# so G2's catch answers before G1's `_annotated` test is ever reached: deleting
# G1 outright leaves this row GREEN. G1 -- "is anything PAINTABLE attached",
# asked above every path comparison -- is owned by F6 and F24 here and by W1a27
# of tests/headless/test_ase_window.tcl, all three of which stage a database
# that IS attached and is NOT publishable. What this row actually witnesses is
# the empty-session floor: no arm of either proc answers CURRENT or blows up
# when the window is holding nothing.
catch {xschem raw clear}
check {F1 CONTROL with nothing attached at all the predicate says NOT CURRENT and taking a database off is a harmless no-op} \
  [list [f_cur {}] [f_cur $F_RAW] [f_det] [f_rawfile]] \
  [list 0 0 0 NONE]

catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
set f2_att [f_attok $F_RAW]
set f2_cur [f_cur $F_RAW]
set f2_rows [f_rows]
check {F2 straight after a verified attach the predicate says CURRENT and the block shows that run's numbers} \
  [list $f2_att $f2_cur $f2_rows] [list 1 1 $F_R1]

# ---- THE HEADLINE PREDICATE ----------------------------------------------
# The same path, rewritten with different values and a different size, with no
# gesture of any kind in between. This is the whole item, asked of the mint.
# ⚠ THE ENGINE IS ASKED TO ATTACH AS WELL, so this row measures the DEFECT and
# not an absent helper: on a tree where db_attach does not exist the sheet is
# still genuinely painting run 1 and the FAIL line says so out loud.
catch {xschem annotate_op $F_RAW}
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f3_cur [f_cur $F_RAW]
set f3_rows [f_rows]
set f3_val [f_val $F_ID]
check {F3 THE HEADLINE PREDICATE the same results file rewritten by a re-run is NOT current, even though the block is still painting from it} \
  [list $f3_cur $f3_rows $f3_val] [list 0 $F_R1 1e-05]

# a session with no results at all still touches nothing and says nothing
#
# ⚠ THE FILE IS REWRITTEN FIRST, AND THAT IS THE WHOLE ROW (sabotage round
# 2026-08-28). This row used to stage an UNCHANGED file, which the cheap path
# answers one line earlier -- so the arm it is named for was never reached and
# inverting it left the row green. The rewrite makes the stamp differ, which is
# what forces control down to the candidate test; the last leg below asks the
# SAME question with a candidate and requires 0, which is the proof that the
# cheap path did not answer and that the 1 above came from the no-candidate arm.
#
# THE STATE IN THE PRODUCT: the results file has been deleted, so ASE-L's
# `Results > Annotate` tick has no path to hand the question. Answering 0 there
# would mean "re-attach", and there is nothing to re-attach FROM -- the numbers
# on the sheet would be thrown away for nothing.
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
f_attok $F_RAW
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f4_cur [f_cur {}]
set f4_rf [f_rawfile]
set f4_rows [f_rows]
set f4_withcand [f_cur $F_RAW]
check {F4 guard G4 no-candidate arm with a rewritten results file and NO candidate to compare against the predicate says CURRENT and nothing is touched} \
  [list $f4_cur $f4_rf $f4_rows $f4_withcand] [list 1 [file normalize $F_RAW] $F_R1 0]

# ---- another corner's operating point, at a path this surface never owned --
# It is neither replaced nor erased: this surface never destroys data it did
# not attach. That is what keeps test_ase_window row W1a16 green.
#
# ⚠ THE FIRST LOOK IS TAKEN BEFORE THE REWRITE, AND THAT IS WHAT MAKES THIS
# ROW SEE THE ARM IT NAMES (sabotage round 2026-08-28). Asking only once, after
# the rewrite, is answered by G3a's FIRST-SIGHT arm several lines above the
# path comparison -- so the arm was never reached and inverting it left the row
# green. The first look stamps the foreign file; the rewrite makes that stamp
# differ; only THEN does the question reach "not mine, leave it alone".
#
# WHAT INVERTING IT COSTS THE USER: 0 there means "re-attach", and the chord
# above would then take this corner's operating point off and put the session's
# own in its place -- `xschem annotate_op` DELETES a 1-point op/dc it replaces
# (scheduler.c), so the corner the user loaded by hand is gone, not hidden.
catch {xschem raw clear}
f_mkop $F_OTHER 4e-06 2e-04 3e-06 {v(sentinel684)}
catch {xschem annotate_op $F_OTHER}
set f5_pre [f_idx {v(sentinel684)}]
set f5_first [f_cur $F_RAW]
f_bump
f_mkop $F_OTHER 8e-06 4e-04 6e-06 {v(sentinel684)}
set f5_cur [f_cur $F_RAW]
set f5_post [f_idx {v(sentinel684)}]
set f5_rf [f_rawfile]
check {F5 guard G4 path arm on the SECOND look a database at a path this surface never owned is still CURRENT as far as this surface is concerned, and its own vectors survive} \
  [list [expr {$f5_pre >= 0}] $f5_first $f5_cur [expr {$f5_post >= 0}] \
        [expr {$f5_rf eq [file normalize $F_OTHER] ? 1 : 0}]] \
  [list 1 1 1 1 1]

# ---- defect B, and the ordering that makes it work ------------------------
# An ordinary waveform graph leaves `raw loaded` 0 with `raw annot` -1 0 -1.
# G1 must be asked BEFORE the path test, or a foreign transient at a foreign
# path would read as "not mine, therefore current" and the tick would stay a
# dead control forever.
catch {xschem raw clear}
catch {xschem raw_read $F_TRAN tran}
set f6_ld [f_call {xschem raw loaded}]
set f6_an [f_call {xschem raw annot}]
set f6_cur [f_cur $F_RAW]
check {F6 defect B an ordinary waveform graph is NOT something this surface can paint from, and that is asked before any path comparison} \
  [list $f6_ld $f6_an $f6_cur] [list {0 0} {0 {-1 0 -1}} 0]

# ---- a database attached by some OTHER route ------------------------------
# Waves > Op Annotate, an xschemrc line, a test fixture. It is trusted the
# FIRST time it is seen -- there is nothing to compare against -- and
# revalidated from then on. Rows N5, N10 and V31b of test_op_annot.tcl are
# hand-attaches that expect the `live` arm, so a predicate that answered 0 on
# first sight would redden a suite this item is not allowed to touch.
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
set f7_first [f_cur $F_RAW]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f7_second [f_cur $F_RAW]
check {F7 guard G3a a database attached by some other route is trusted on FIRST sight and revalidated from the second look on} \
  [list $f7_first $f7_second] [list 1 0]

# ---- the guard no behavioural row can stage -------------------------------
# `xschem raw rawfile` RAISES with nothing attached, so every state in which it
# blows up is a state G1 has already refused. G2's catch is therefore invisible
# to behaviour, and this row is its only witness. An early return on an
# unanswerable question is the exact mechanism by which the shipped guard
# paints run 1 forever, so the claim is: no arm of this body returns 1 from a
# failure path, and no arm leaves the question unanswered.
set F_B_CUR [f_body ::op_annot::db_current]
set f8_ann [f_lineidx $F_B_CUR {_annotated}]
set f8_path [f_lineidx $F_B_CUR {file normalize|rawfile}]
check {F8 STRUCTURAL guard G2 op_annot::db_current asks whether anything publishable is attached before it asks about paths, and every failure arm answers NOT CURRENT rather than returning nothing} \
  [list [expr {$F_B_CUR ne {NOPROC} ? 1 : 0}] \
        [expr {($f8_ann >= 0 && $f8_path >= 0 && $f8_ann < $f8_path) ? 1 : 0}] \
        [f_pgrep $F_B_CUR {catch .*\{\s*return 1\s*\}}] \
        [f_pgrep $F_B_CUR {^\s*return\s*$}]] \
  [list 1 1 0 0]

# ===========================================================================
# F9 .. F14 -- op_annot::db_attach: THE RE-ATTACH, AND ISSUE 0685's TARGETED DROP
# ===========================================================================
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
set f9_r [f_att $F_RAW]
set f9_cur [f_cur $F_RAW]
set f9_rows [f_rows]
check {F9 a good results file attaches, is verified by re-asking, and is CURRENT immediately afterwards} \
  [list [lindex $f9_r 0] $f9_cur $f9_rows] [list 1 1 $F_R1]

# ---- an unparseable file -------------------------------------------------
# ⚠ MEASURED ON THIS BINARY: `xschem annotate_op <garbage>` answers rc 0 with an
# EMPTY result AND destroys whatever was attached. So the failure must be
# detected by re-asking.
#
# ⚠ THIS ROW WITNESSES G7 (verify by re-asking), NOT G8 (the stamp is written
# only after that verify). Its title used to claim both and the sabotage round
# of 2026-08-28 measured that it cannot see G8 at all: a failed attach leaves
# NOTHING publishable attached, so the very next question is refused by G1
# before any stamp is read, and writing a bogus stamp here changes no answer in
# this row. G8's witnesses are F10b below -- behavioural and structural.
catch {xschem raw clear}
f_mkjunk [file join $scratch junk.raw]
# ⚠ ONLY THE ENGINE'S RETURN CODE IS GOLDED, NOT ITS RESULT STRING: measured,
# annotate_op over an unreadable file answers an empty string headless and `0`
# on the display arm. The claim is that it answers SUCCESS either way, and that
# nothing is attached afterwards.
set f10_raw [f_call [list xschem annotate_op [file join $scratch junk.raw]]]
set f10_rawann [f_call {::op_annot::_annotated}]
catch {xschem raw clear}
set f10_r [f_att [file join $scratch junk.raw]]
set f10_cur [f_cur [file join $scratch junk.raw]]
set f10_rows [f_rows]
check {F10 guard G7 an unreadable results file does not attach, and the sheet is blank rather than "already loaded"} \
  [list [lindex $f10_raw 0] $f10_rawann [lindex $f10_r 0] $f10_cur $f10_rows] \
  [list 0 {0 0} 0 0 $F_BLANK]

# ---- GUARD G8, THE ONE THE 2026-08-28 SABOTAGE ROUND COULD NOT SEE --------
# G8 is "no freshness stamp is written until the attach has been VERIFIED, and
# any stamp already held for that path is dropped when it fails". Writing the
# stamp before the verify, and dropping the forget on the failure arm, left
# every suite in the tier list green. Both halves of that hole are closed here.
#
# THE BEHAVIOURAL HALF, AND THE STATE THAT REACHES IT. The stated hazard --
# "the next press says already loaded over a blank sheet" -- is NOT reachable,
# and saying so is part of the repair: a failed attach leaves nothing
# publishable attached, so G1 refuses the next question before a stamp can be
# consulted. What IS reachable is the path the fixture below walks. The
# simulator is mid-rewrite, the tick fires, the attach fails. Moments later the
# file is complete and the user attaches it from somewhere else entirely --
# `Waves > Op Annotate`, an xschemrc line, another session's hand. A stamp left
# behind by the failure describes the TRUNCATED file, so that perfectly good
# fresh attach is judged "changed since I last looked" on FIRST SIGHT and
# thrown away and re-read, which is exactly the needless re-read G3a exists to
# prevent -- and on a 40000-vector operating point it is the 58 ms re-read this
# item's cost table measures, paid for nothing, on every press.
catch {xschem raw clear}
f_mkjunk $F_RAW
set f10b_att [f_attok $F_RAW]
set f10b_ann [f_call {::op_annot::_annotated}]
f_bump
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
set f10b_first [f_cur $F_RAW]
set f10b_rows [f_rows]
# THE STRUCTURAL HALF. The ordering itself -- stamp BELOW verify, forget on the
# failure arm -- is a property of the source that no behavioural row can read,
# because the two orderings differ only in a state G1 refuses. `f_lineidx`
# skips whole-line comments, so the prose above cannot satisfy any of it.
set F_B_ATT0 [f_body ::op_annot::db_attach]
set f10b_ver [f_lineidx $F_B_ATT0 {_annotated}]
set f10b_got [f_lineidx $F_B_ATT0 {raw rawfile}]
set f10b_stamp [f_lineidx $F_B_ATT0 {_db_stamp}]
set f10b_forget [f_lastidx $F_B_ATT0 {_db_forget}]
check {F10b guard G8 no freshness stamp is written until the attach has been verified, and a failed attach leaves none behind, so a good file attached later by another route is still trusted on first sight} \
  [list $f10b_att $f10b_ann $f10b_first $f10b_rows \
        [expr {($f10b_ver >= 0 && $f10b_got >= 0 && $f10b_stamp >= 0 \
                && $f10b_ver < $f10b_stamp && $f10b_got < $f10b_stamp) ? 1 : 0}] \
        [expr {($f10b_forget >= 0 && $f10b_ver >= 0 && $f10b_forget > $f10b_ver) ? 1 : 0}]] \
  [list 0 {0 0} 1 $F_R1 1 1]

# ---- brief constraint 4, both facts in ONE golden -------------------------
# A fix that trusts annotate_op's return cannot pass this row, because the row
# states what that return actually is next to what db_attach must answer.
catch {xschem raw clear}
set f11_raw [f_call {xschem annotate_op /nonexistent/zz0684.raw}]
set f11_r [f_att /nonexistent/zz0684.raw]
set f11_ann [f_call {::op_annot::_annotated}]
check {F11 brief constraint 4 the engine answers OK for a results file that does not exist, so the attach is verified by re-asking and not by that answer} \
  [list [lindex $f11_raw 0] [lindex $f11_r 0] $f11_ann] [list 0 0 {0 0}]

# ---- ISSUE 0685: the stale registry entry any re-attach lands on ----------
# `xschem raw read <f> tran` ADDS (a waveform graph's own form) and leaves a
# same-path operating-point entry behind while making something else current;
# extra_rawfile's dedup loop then hands that stale entry straight back with NO
# read. Measured on this binary, exactly as 0685 section 2 records it.
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
catch {xschem raw read $F_TRAN tran}
set f12_pre [f_info_has $F_TRAN]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f12_naive [f_call [list xschem annotate_op $F_RAW]]
set f12_naiveval [f_val $F_ID]
set f12_r [f_att $F_RAW]
set f12_val [f_val $F_ID]
set f12_rows [f_rows]
set f12_post [f_info_has $F_TRAN]
check {F12 issue 0685 THE HAZARD, DEMONSTRATED with a waveform graph open a bare annotate_op of the rewritten results file hands back the STALE numbers, and a verified re-attach does not} \
  [list $f12_pre $f12_naive $f12_naiveval [lindex $f12_r 0] $f12_val $f12_rows $f12_post] \
  [list 1 {0 ::op_annot::text} 1e-05 1 0.009 $F_R2 1]

# ---- and the drop's OWN witness ------------------------------------------
# ⚠ F12 ABOVE DEMONSTRATES THE HAZARD BUT DOES NOT GUARD THE DROP, and the
# sabotage round of 2026-08-28 measured it: deleting the drop loop entirely
# leaves F12 GREEN. Its own naive `annotate_op` call is why -- that call makes
# the stale registry entry CURRENT, and once it is current the attach that
# follows re-reads with or without a drop. This row is the same staging with
# nothing in between: the stale operating-point entry sits at the session's
# path while the user's waveform graph is the current database, and
# `op_annot::db_attach` is the first thing to touch it. That is the ordinary
# bench state -- a graph open, the simulation re-run -- and without the drop
# extra_rawfile's dedup loop takes the "already loaded: switch to it" branch
# with NO read and the sheet paints the previous run.
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
catch {xschem raw read $F_TRAN tran}
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f12b_r [f_attok $F_RAW]
set f12b_val [f_val $F_ID]
set f12b_rows [f_rows]
set f12b_post [f_info_has $F_TRAN]
check {F12b issue 0685 guard G6 the stale registry entry at the session's own path is dropped before the re-read, so the FIRST touch after a re-run yields the new numbers and not the ones already in memory} \
  [list $f12b_r $f12b_val $f12b_rows $f12b_post] \
  [list 1 0.009 $F_R2 1]

# ---- 0685 section 4's data loss must NOT come back ------------------------
# The reverted attempt cleared op, dc AND tran at the session path before the
# re-read; when the re-read then failed the user's loaded waveform database was
# gone and nothing replaced it. This row is that scenario at a DIFFERENT path
# from the one being attached, which is the common bench layout.
#
# ⚠ IT IS NOT THE GUARD ON THE NEVER-TRAN HALF, and its comment used to say it
# was. The sabotage round of 2026-08-28 widened the drop to include `tran` and
# this row stayed GREEN, because the drop only ever touches the CANDIDATE's own
# path and this fixture's transient is somewhere else -- so the type list
# cannot matter here. F13b below is that guard, at the same path.
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
catch {xschem raw read $F_TRAN tran}
f_bump
f_mkjunk $F_RAW
set f13_r [f_attok $F_RAW]
set f13_has [f_info_has $F_TRAN]
set f13_readable [f_call [list xschem raw index {v(zzz)}]]
f_mkop $F_RAW 1e-05 1e-04 1e-06
check {F13 issue 0685 section 4 no new data loss: a re-attach that FAILS leaves the user's waveform database attached and still readable} \
  [list $f13_r $f13_has [lindex $f13_readable 0] [expr {[lindex $f13_readable 1] >= 0}]] \
  [list 0 1 0 1]

# ---- the never-tran half, AT THE SAME PATH -------------------------------
# ⚠ THIS IS WHERE 0685 SECTION 4's DATA LOSS ACTUALLY LIVES, and until
# 2026-08-28 nothing but a source grep stood between the user and it. One
# results file, read as a waveform by `xschem raw read` (the ADD form a graph
# uses), then rewritten by a re-run that this surface tries to annotate from
# while the simulator is still mid-write. The drop runs BEFORE the read, so a
# drop that included `tran` would take the user's trace off first and the
# failed read would put nothing back: the waveform on screen would have no
# database behind it, from a gesture the user never made about that graph.
# MEASURED both ways -- shipped, the registry keeps the entry and `v(zzz)`
# still reads; with `tran` in the list the registry is EMPTY.
catch {xschem raw clear}
set F_SAME [file join $nd same0684.raw]
f_mktran $F_SAME
catch {xschem raw read $F_SAME tran}
set f13b_pre [f_info_has $F_SAME]
f_bump
f_mkjunk $F_SAME
set f13b_r [f_attok $F_SAME]
set f13b_has [f_info_has $F_SAME]
set f13b_readable [f_call [list xschem raw index {v(zzz)}]]
check {F13b issue 0685 section 4 guard G6 a re-attach that FAILS at the SAME path the user's waveform was read from leaves that waveform attached and still readable} \
  [list $f13b_pre $f13b_r $f13b_has [lindex $f13b_readable 0] \
        [expr {[lindex $f13b_readable 1] >= 0}]] \
  [list 1 0 1 0 1]

set F_B_ATT [f_body ::op_annot::db_attach]
check {F14 STRUCTURAL guard G6 the drop before a re-attach names only the operating-point kinds it is about to read, and the blanket clear the reverted attempt used is nowhere in it} \
  [list [expr {$F_B_ATT ne {NOPROC} ? 1 : 0}] \
        [f_pgrep $F_B_ATT {\mtran\M}] \
        [f_pgrep $F_B_ATT {xschem raw clear\s*(\}|\]|$)}] \
        [expr {[f_pgrep $F_B_ATT {\mop\M}] > 0 ? 1 : 0}]] \
  [list 1 0 0 1]

# ===========================================================================
# F15 -- op_annot::db_detach: THE "OR BLANK" HALF
# ===========================================================================
# ⚠ THIS IS cadence::_annot_db_release's BODY, MOVED. RULING D5-4 says a
# decision is minted once and rendered by callers, and after this item BOTH
# operating-point surfaces need to take a database off. The named-file spelling
# and the digital test above the clear are issue 0902's, unchanged; what is new
# is the address. Row V74 of tests/headless/test_op_annot.tcl currently asserts
# those two things about _annot_db_release's OWN body and will need its legs
# re-homed here when the delegate lands -- the last leg below is what forces
# that, so the two cannot both claim to own the spelling.
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
set f15_pre [f_rawfile]
set f15_det [f_det]
set f15_post [f_rawfile]
set f15_rows [f_rows]
set F_B_DET [f_body ::op_annot::db_detach]
set f15_di [f_lineidx $F_B_DET {is_digital}]
set f15_ci [f_lineidx $F_B_DET {xschem raw clear}]
check {F15 RULING D5-4 taking a database off is minted once, names the file it takes off, asks the digital question first, and the old address is a one-line delegate} \
  [list [expr {$f15_pre ne {NONE} ? 1 : 0}] $f15_det $f15_post $f15_rows \
        [f_pgrep $F_B_DET {xschem raw clear \$f \$t}] \
        [f_pgrep $F_B_DET {xschem raw clear\s*(\}|\]|$)}] \
        [expr {($f15_di >= 0 && $f15_ci >= 0 && $f15_di < $f15_ci) ? 1 : 0}] \
        [f_pgrep $F_B_RELEASE {op_annot::db_detach}]] \
  [list 1 1 NONE $F_BLANK 1 0 1 1]

# ===========================================================================
# F16 .. F22 -- THE `6` AND `Alt-6` CHORDS, THROUGH THE REAL SUPPLY CHAIN
# ===========================================================================
# Nothing below hand-attaches anything. `cadence::annot_mode` finds the file
# through cadence::_annot_raw_candidate the way a key press does, which is why
# ::netlist_dir is set and the schematic is named mos.sch: the candidate is
# $netlist_dir/<cell>.raw.
set ::netlist_dir $nd

# ---- THE HEADLINE, ON THE GESTURE THE USER NAMED --------------------------
# Press 6. Re-run. Press 6. The block must read the new numbers, and the status
# line must say it LOADED them rather than that they were already loaded --
# that sentence is the only thing on screen that differs between a correct
# annotation and the defect.
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f16_r1 [f_rows]
set f16_m1 [f_msg]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f16_nogesture [f_rows]
catch {cadence::annot_mode op}
set f16_r2 [f_rows]
set f16_m2 [f_msg]
set f16_val [f_val $F_ID]
check {F16 THE HEADLINE press 6, re-run the simulation, press 6 again: the schematic shows the NEW numbers and says which file it loaded} \
  [list $f16_r1 [string match "$F_M1 Loaded results from *mos.raw." $f16_m1] \
        $f16_nogesture $f16_r2 $f16_val \
        [expr {$f16_m2 eq "$F_M1$F_LIVE" ? {SAID-ALREADY-LOADED} : {}}] \
        [string match "$F_M1 Loaded results from *mos.raw." $f16_m2]] \
  [list $F_R1 1 $F_R1 $F_R2 0.009 {} 1]

# ---- the same through Alt-6 ----------------------------------------------
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f17_m1 [f_mask]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
catch {cadence::annot_mode opvolt}
set f17_m2 [f_mask]
set f17_rows [f_rows]
set f17_msg [f_msg]
check {F17 the same through Alt-6: the second chord adds DC node voltages AND brings the numbers up to date} \
  [list $f17_m1 $f17_m2 $f17_rows \
        [string match "$F_M3 Loaded results from *mos.raw." $f17_msg]] \
  [list 1 3 $F_R2 1]

# ---- re-attach OR BLANK, never the old numbers under a caption ------------
# A captioned refusal sitting above a stale number is not an improvement on a
# silent stale number -- it is RULING D5-1 with a caption. So when the press
# learns the attached database is not the run it is about, the database comes
# OFF before any refusal can be spoken.
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f18_r1 [f_rows]
f_bump
f_mkjunk $F_RAW
catch {cadence::annot_mode op}
set f18_r2 [f_rows]
set f18_msg [f_msg]
f_mkop $F_RAW 1e-05 1e-04 1e-06
check {F18 guard G11 when the re-run's results cannot be read the schematic goes BLANK and says so, rather than keeping the previous run's numbers under a caption} \
  [list $f18_r1 $f18_r2 \
        [expr {[string first {10u} $f18_r2] >= 0 ? {STALE-STILL-ON-SHEET} : {}}] \
        [string match "*Could not read the results file*" $f18_msg]] \
  [list $F_R1 $F_BLANK {} 1]

# ---- the cheap path: nothing changed, nothing re-read ---------------------
# The anti-always-re-attach row. Sabotage "always re-attach" reddens exactly
# this one, and it is why the fix is a stamp rather than an unconditional
# re-read on every press.
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f19_rf1 [f_rawfile]
set f19_info1 [f_info]
catch {cadence::annot_mode op}
set f19_rf2 [f_rawfile]
set f19_info2 [f_info]
set f19_msg [f_msg]
check {F19 CONTROL pressing 6 twice with nothing changed on disk re-reads nothing and still says the results were already loaded} \
  [list [expr {$f19_rf1 eq $f19_rf2 ? 1 : 0}] [expr {$f19_info1 eq $f19_info2 ? 1 : 0}] \
        $f19_msg [f_rows]] \
  [list 1 1 "$F_M1$F_LIVE" $F_R1]

# ---- another corner's operating point is not this surface's to replace ----
# ⚠ THE SECOND PRESS IS THE POINT, and it is what carries this row past
# G3a. A single press is answered by the first-sight arm, so until 2026-08-28
# this row could not see the guard it is named for. The foreign file is
# rewritten between the two presses -- a second corner finishing in the
# background is the ordinary way that happens -- which makes the stamp differ
# and drives the question down to "is this candidate the file I am painting
# from". It is not, so the answer is "leave it alone": the sentinel vector is
# still there, the window is still painting from the corner the user chose, and
# the press says the results were already loaded rather than announcing that it
# swapped them.
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
f_mkop $F_OTHER 4e-06 2e-04 3e-06 {v(sentinel684)}
catch {xschem annotate_op $F_OTHER}
set f20_pre [f_idx {v(sentinel684)}]
catch {cadence::annot_mode op}
set f20_post [f_idx {v(sentinel684)}]
set f20_msg [f_msg]
f_bump
f_mkop $F_OTHER 8e-06 4e-04 6e-06 {v(sentinel684)}
catch {cadence::annot_mode op}
set f20_post2 [f_idx {v(sentinel684)}]
set f20_msg2 [f_msg]
set f20_rf [f_rawfile]
check {F20 guard G4 path arm through the chord: another corner's operating point survives a SECOND press taken after that corner's own file was rewritten, and the press still says the results were already loaded} \
  [list [expr {$f20_pre >= 0}] [expr {$f20_post >= 0}] $f20_msg \
        [expr {$f20_post2 >= 0}] $f20_msg2 \
        [expr {$f20_rf eq [file normalize $F_OTHER] ? 1 : 0}]] \
  [list 1 1 "$F_M1$F_LIVE" 1 "$F_M1$F_LIVE" 1]

# ---- the noop arm must not become a detach --------------------------------
# A database that published no operating point (annot_p < 0) is the `noop`
# state, and it has its own sentence naming the real cause. The detach above
# is conditional on something publishable being attached precisely so this arm
# is untouched -- row N10b of test_op_annot.tcl is its behavioural owner there.
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
# ⚠ THE FIXTURE IS AN OPERATING POINT READ THE WAY `Waves > Op` READS ONE --
# `xschem raw_read`, which leaves `raw loaded` 0 and `raw annot` -1 -- and NOT a
# transient. A transient never reaches this arm at all: the chord's own gate
# refuses it first, under RULING 0856's sentence. Row N10b of
# tests/headless/test_op_annot.tcl is the same fixture at its own address.
catch {xschem raw_read $F_RAW}
set f21_pre [f_call {xschem raw annot}]
catch {cadence::annot_mode op}
set f21_msg [f_msg]
set f21_rf [f_rawfile]
check {F21 CONTROL a database that published no operating point keeps its own explanation, and nothing is taken off or re-read behind it} \
  [list $f21_pre [expr {[string first {do not include an operating point} $f21_msg] >= 0 ? 1 : 0}] \
        [expr {$f21_rf eq [file normalize $F_RAW] ? 1 : 0}]] \
  [list {0 {-1 0 -1}} 1 1]

# ---- the guard that has to be ONE source line -----------------------------
# Item A14 pinned the same shape on the transient surface for the same reason:
# with the two questions on separate lines a later edit can reach the guarded
# block having asked only the first one, and the first one is the shipped
# defect's own predicate.
set F_B_MODE2 [f_body ::cadence::annot_mode]
set f22_live [f_lineidx $F_B_MODE2 {_annotated.*db_current|db_current.*_annotated}]
set f22_det [f_lineidx $F_B_MODE2 {db_detach}]
set f22_sel [f_lineidx $F_B_MODE2 {_annot_raw_candidate}]
check {F22 STRUCTURAL guard G10 the chord asks "is something attached" and "is it this run" on ONE line, and takes a stale database off above the search that would replace it} \
  [list [expr {$f22_live >= 0 ? 1 : 0}] \
        [expr {($f22_det >= 0 && $f22_sel >= 0 && $f22_det < $f22_sel) ? 1 : 0}]] \
  [list 1 1]

# ===========================================================================
# F23 .. F28 -- ASE-L's `Results > Annotate` TICK
# ===========================================================================
# The loader is driven directly with `ase::last_rawfile` and
# `ase::results_stale` stubbed, exactly the way tests/headless/test_ase_window.tcl
# steers these rows. The real menu widget is that suite's job (W1a24-W1a27);
# what is under test here is the loader's own decision.
rename ase::last_rawfile  f_saved_last_rawfile
rename ase::results_stale f_saved_results_stale
set ::f_rawstub $F_RAW
set ::f_stalestub 0
proc ase::last_rawfile  {key} { return $::f_rawstub }
proc ase::results_stale {key} { return $::f_stalestub }
set ::f_said {}
rename ase::echo f_saved_echo
proc ase::echo {msg {tag {}}} { lappend ::f_said [list $tag $msg] ; return 1 }
proc f_echoed {script} {
  set ::f_said {}
  catch {uplevel #0 $script}
  return $::f_said
}

catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {ase::ui::annot_ensure_loaded K}
set f23_r1 [f_rows]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f23_nogesture [f_rows]
catch {ase::ui::annot_ensure_loaded K}
set f23_r2 [f_rows]
set f23_val [f_val $F_ID]
check {F23 THE HEADLINE ON THE TICK ticking Results > Annotate again after a re-run shows the NEW numbers, with no untick in between} \
  [list $f23_r1 $f23_nogesture $f23_r2 $f23_val] \
  [list $F_R1 $F_R1 $F_R2 0.009]

# ---- defect B on the tick: today a silent dead control --------------------
# With an ordinary waveform graph in the design context the tick early-returns,
# nothing renders, and this is the one path in the proc that echoes nothing --
# so the user is told nothing either.
catch {xschem raw clear}
xschem load $F_SCH
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem raw_read $F_TRAN tran}
set f24_pre [f_info_has $F_TRAN]
set f24_said [f_echoed {ase::ui::annot_ensure_loaded K}]
set f24_rows [f_rows]
set f24_rf [f_rawfile]
set f24_post [f_info_has $F_TRAN]
# ⚠ THE LAST LEG IS GUARD G13's `$ann` TERM, AND WITHOUT IT THIS ROW IS BLIND
# TO IT (sabotage round 2026-08-28). The repair for defect B is to ADD the
# session's operating point BESIDE the graph, never to destroy the graph: the
# tick only takes a database off when one this surface can paint from is
# attached, and a waveform graph is not that. Making the detach unconditional
# reds nothing above -- the numbers still render and the session's file is
# still the current one -- while the trace the user was looking at is gone from
# the registry. So the row asks, out loud, whether the graph survived.
check {F24 defect B an unrelated waveform graph no longer blocks the tick: the session's own results are attached beside it, the numbers render, and the graph the user was looking at is untouched} \
  [list $f24_pre $f24_rows [expr {$f24_rf eq [file normalize $F_RAW] ? 1 : 0}] \
        [llength $f24_said] $f24_post] \
  [list 1 $F_R1 1 0 1]

# ---- the 0838 refusal still fires, and still leaves a BLANK sheet ---------
catch {xschem raw clear}
xschem load $F_SCH
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {ase::ui::annot_ensure_loaded K}
set f25_before [f_rows]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set ::f_stalestub 1
set f25_said [f_echoed {ase::ui::annot_ensure_loaded K}]
set ::f_stalestub 0
set f25_rows [f_rows]
check {F25 guard G13 a results file older than the circuit is still refused, still said out loud, and the sheet is BLANK rather than showing the previous run} \
  [list $f25_before [llength $f25_said] \
        [expr {[string match {*is from an earlier run than the circuit now on screen*} [lindex [lindex $f25_said 0] 1]] ? 1 : 0}] \
        $f25_rows] \
  [list $F_R1 1 1 $F_BLANK]

# ---- one sentence, from the one mint --------------------------------------
# ⚠ TODAY THIS SENTENCE CANNOT BE SPOKEN AT ALL. `xschem annotate_op` answers
# rc 0 for a file it could not read, so the catch it lives inside never fires.
# Row A11-8 of test_op_annot.tcl already requires exactly one copy of the
# fragment in the tree; this row requires that copy to actually REACH the user.
catch {xschem raw clear}
xschem load $F_SCH
f_mkjunk [file join $scratch junk2.raw]
set ::f_rawstub [file join $scratch junk2.raw]
set f26_said [f_echoed {ase::ui::annot_ensure_loaded K}]
set ::f_rawstub $F_RAW
check {F26 a tick that cannot put the numbers on the sheet says so, exactly once, in the one sentence minted for it} \
  [list [llength $f26_said] \
        [expr {[string match {ase: could not put the results from *} [lindex [lindex $f26_said 0] 1]] ? 1 : 0}] \
        [lindex [lindex $f26_said 0] 0]] \
  [list 1 1 error]

# ---- a session with no results at all -------------------------------------
catch {xschem raw clear}
xschem load $F_SCH
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {xschem annotate_op $F_RAW}
set ::f_rawstub {}
set f27_pre [f_rawfile]
set f27_said [f_echoed {ase::ui::annot_ensure_loaded K}]
set f27_post [f_rawfile]
set f27_rows [f_rows]
set ::f_rawstub $F_RAW
check {F27 CONTROL a session with no results file touches nothing, takes nothing off and says nothing} \
  [list [expr {$f27_pre eq $f27_post ? 1 : 0}] [llength $f27_said] $f27_rows] \
  [list 1 0 $F_R1]

set F_B_ENSURE2 [f_body ::ase::ui::annot_ensure_loaded]
set f28_ld [f_lineidx $F_B_ENSURE2 {xschem raw loaded}]
set f28_cur [f_lineidx $F_B_ENSURE2 {db_current}]
set f28_det [f_lineidx $F_B_ENSURE2 {db_detach}]
check {F28 STRUCTURAL guard G12 the tick no longer asks "is SOME database attached" and returns; the first question it asks is whether the attached one is this run} \
  [list [expr {$F_B_ENSURE2 ne {NOPROC} ? 1 : 0}] $f28_ld \
        [expr {$f28_cur >= 0 ? 1 : 0}] \
        [expr {($f28_det >= 0 && $f28_cur >= 0 && $f28_cur < $f28_det) ? 1 : 0}]] \
  [list 1 -1 1 1]

# ===========================================================================
# F29 .. F34 -- THE HALF THAT REACHES THE DISPLAY WITH NO GESTURE AT ALL
# ===========================================================================
# ⚠ THIS IS WHAT REFUTED ATTEMPT 1 (issue 0684 section 7). That attempt made the
# run-completion event drop the freshness STAMP, so the cache stopped lying --
# and the screen kept painting run 1's number, because nothing re-attached.
# Section 7's own words: "what it must do is re-attach-or-blank, not merely
# invalidate." None of these rows unticks anything.
rename ase::ui::design_path f_saved_design_path
proc ase::ui::design_path {key} { return [file normalize $::F_SCH] }

catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
set f29_pre [f_rawfile]
set f29_said [f_echoed {ase::ui::annot_refresh_after_run K}]
set f29_post [f_rawfile]
check {F29 guard G15 a finished run with annotation switched OFF attaches nothing, takes nothing off and says nothing} \
  [list $f29_pre $f29_post [llength $f29_said] [f_ref K]] \
  [list NONE NONE 0 0]

# ⚠ THE CALL COUNTER IS WHAT MAKES THIS ROW MEAN ANYTHING (sabotage round
# 2026-08-28). "Re-reads nothing" used to be golded as "the attached filename
# and the registry listing did not change", and a detach-and-re-attach of the
# SAME path leaves both byte-identical -- so forcing the currency question to
# answer "not current" on every call, i.e. re-reading the whole file on every
# press, left this row green while its sentence was false. The claim is about
# whether the file was READ, so the row counts the reads: a counting proxy
# stands in front of `op_annot::db_attach` for the length of this row and is
# taken away again immediately. It DELEGATES -- a stub that answered on its own
# would measure the test double instead of the product.
catch {xschem raw clear}
xschem load $F_SCH
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f30_rf1 [f_rawfile]
set f30_i1 [f_info]
set ::f_attn 0
rename ::op_annot::db_attach f_saved_db_attach
proc ::op_annot::db_attach {path {level {}}} {
  incr ::f_attn
  return [uplevel 1 [list f_saved_db_attach $path $level]]
}
catch {ase::ui::annot_refresh_after_run K}
set f30_n [set ::f_attn]
catch {rename ::op_annot::db_attach {}}
catch {rename f_saved_db_attach ::op_annot::db_attach}
set f30_rf2 [f_rawfile]
set f30_i2 [f_info]
# ⚠ THE FIRST ELEMENT IS THE ANTI-HOLLOW HALF. "Nothing was re-read" is
# trivially true of a seam that does not exist, which is the state of the tree
# this row was written in. The LAST is the anti-hollow half of the counter: a
# proxy that was never restored, or a rename that silently failed, would make
# the count meaningless.
check {F30 a finished run whose results are already the ones on screen re-reads nothing: the file is not opened again, not merely re-attached to the same name} \
  [list [expr {[llength [info commands ::ase::ui::annot_refresh_after_run]] ? 1 : 0}] \
        [expr {$f30_rf1 eq $f30_rf2 ? 1 : 0}] [expr {$f30_i1 eq $f30_i2 ? 1 : 0}] [f_rows] \
        $f30_n \
        [expr {[llength [info procs ::f_saved_db_attach]] == 0 \
               && [llength [info commands ::op_annot::db_attach]] == 1 ? 1 : 0}]] \
  [list 1 1 1 $F_R1 0 1]

# ---- THE ITEM, IN ONE ROW -------------------------------------------------
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f31_r1 [f_rows]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
set f31_before [f_rows]
catch {ase::ui::annot_refresh_after_run K}
set f31_r2 [f_rows]
set f31_val [f_val $F_ID]
set f31_mask [f_mask]
check {F31 THE ITEM annotation is on, the run finishes, and with NO key press and NO tick the schematic shows the new numbers} \
  [list $f31_r1 $f31_before $f31_r2 $f31_val $f31_mask] \
  [list $F_R1 $F_R1 $F_R2 0.009 1]

catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
f_bump
f_mkjunk $F_RAW
set f32_said [f_echoed {ase::ui::annot_refresh_after_run K}]
set f32_rows [f_rows]
f_mkop $F_RAW 1e-05 1e-04 1e-06
check {F32 the OR BLANK half: a finished run whose results cannot be read clears the previous run's numbers off the sheet and says so once} \
  [list $f32_rows \
        [expr {[string first {10u} $f32_rows] >= 0 ? {STALE-STILL-ON-SHEET} : {}}] \
        [llength $f32_said] \
        [expr {[string match {ase: could not put the results from *} [lindex [lindex $f32_said 0] 1]] ? 1 : 0}]] \
  [list $F_BLANK {} 1 1]

# ---- the borrow always gives the context back -----------------------------
# wviewer::enter_ctx's discipline, and issue 0173's shape if it is dropped: a
# borrow that entered and never left would strand the user in another window's
# context with the schematic still on screen.
#
# ⚠ THIS ROW CANNOT WITNESS THE BORROW, AND SAYING SO IS PART OF THE REPAIR.
# Every fixture in this file holds exactly ONE schematic window, so the design
# is already the current context on every call and the borrow branch is never
# entered -- measured 2026-08-28, all 7 calls here report cur == win. Deleting
# the switch-back, and separately deleting the landmine-17 check that the
# switch actually took, leave this row green. A second schematic window needs
# `xschem new_schematic create`, which needs Tk, so the guard's real witnesses
# are rows W1a28 and W1a29 of tests/headless/test_ase_window.tcl, which run on
# the dev display and drive the refresh from a FOREIGN current context. What
# this row is worth keeping for is the single-window floor: the ordinary case
# must not switch anything, on a success and on a failure alike.
catch {xschem raw clear}
xschem load $F_SCH
catch {xschem set annot_show 0}
f_mkop $F_RAW 1e-05 1e-04 1e-06
catch {cadence::annot_mode op}
set f33_c0 [f_call {xschem get current_win_path}]
f_bump
f_mkop $F_RAW 9e-03 7e-03 5e-05
catch {ase::ui::annot_refresh_after_run K}
set f33_c1 [f_call {xschem get current_win_path}]
f_bump
f_mkjunk $F_RAW
catch {ase::ui::annot_refresh_after_run K}
set f33_c2 [f_call {xschem get current_win_path}]
f_mkop $F_RAW 1e-05 1e-04 1e-06
# ⚠ SAME ANTI-HOLLOW HALF: a seam that does nothing gives the context back
# perfectly, so the row also demands the seam exist and the numbers actually
# move underneath it.
check {F33 CONTROL with one schematic window open the refresh changes no context at all, on a success and on a failure alike (the borrow itself is W1a28/W1a29's)} \
  [list [expr {[llength [info commands ::ase::ui::annot_refresh_after_run]] ? 1 : 0}] \
        [expr {$f33_c0 eq $f33_c1 ? 1 : 0}] [expr {$f33_c0 eq $f33_c2 ? 1 : 0}]] \
  [list 1 1 1]

set F_B_FINISH2 [f_body ::ase::ui::run_finished]
set f34_plot [f_lineidx $F_B_FINISH2 {auto_plot_idle}]
set f34_annot [f_lineidx $F_B_FINISH2 {annot_refresh_idle}]
check {F34 STRUCTURAL guard G14 a finished run schedules the annotation refresh, after the waveform auto-plot so the viewer's own borrow is balanced first} \
  [list [expr {$F_B_FINISH2 ne {NOPROC} ? 1 : 0}] \
        [expr {$f34_plot >= 0 ? 1 : 0}] \
        [expr {($f34_annot >= 0 && $f34_annot > $f34_plot) ? 1 : 0}]] \
  [list 1 1 1]

# ===========================================================================
# F35 -- WHAT A PRESS NOW COSTS
# ===========================================================================
# Item A14 measured that revalidating on every press costs 0.014 ms on 6
# vectors and 55.88 ms on 40000 vectors, and the operating-point path reads
# device parameter vectors. The predicate must therefore be O(1) in the number
# of vectors -- a path, an mtime and a size -- and must NOT reach for the
# fingerprint cadence::_annot_db_print builds, which is 28.3 ms at 40000
# vectors. This row is the guard on that, and the write-up carries the numbers.
proc f_median {n script} {
  set t {}
  for {set i 0} {$i < $n} {incr i} {
    set t0 [clock microseconds]
    catch {uplevel #0 $script}
    lappend t [expr {[clock microseconds] - $t0}]
  }
  set t [lsort -integer $t]
  return [lindex $t [expr {[llength $t] / 2}]]
}
# a big operating point: 40000 device vectors, one point
proc f_mkbig {path n} {
  set f [open $path w]
  puts -nonewline $f "Title: 0684 cost fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: [expr {$n + 3}]
No. Points: 1
Variables:
\t0\ti(@m.xmzz1.mzz\[id\])\tcurrent
\t1\t@m.xmzz1.mzz\[gm\]\tadmittance
\t2\t@m.xmzz1.mzz\[gds\]\tadmittance
"
  for {set i 0} {$i < $n} {incr i} {
    puts -nonewline $f "\t[expr {$i + 3}]\tv(zz$i)\tvoltage\n"
  }
  puts -nonewline $f "Values:\n0\t1e-05\n\t1e-04\n\t1e-06\n"
  for {set i 0} {$i < $n} {incr i} { puts -nonewline $f "\t0.5\n" }
  close $f
}
set F_BIG [file join $scratch big.raw]
f_mkbig $F_BIG 40000
catch {xschem raw clear}
f_mkop $F_RAW 1e-05 1e-04 1e-06
f_attok $F_RAW
set f35_small [f_median 11 [list ::op_annot::db_current $F_RAW]]
catch {xschem raw clear}
f_attok $F_BIG
set f35_big [f_median 11 [list ::op_annot::db_current $F_BIG]]
catch {xschem raw clear}
puts "COST| op_annot::db_current median of 11, microseconds: 6 vectors = $f35_small, 40003 vectors = $f35_big"
set F_B_CUR2 [f_body ::op_annot::db_current]
set F_B_ATT2 [f_body ::op_annot::db_attach]
# ⚠ THE FIRST ELEMENT IS THE ANTI-HOLLOW HALF, AND IT IS NOT DECORATION:
# f_median over an absent command measures Tcl's dispatch failure and answers a
# flattering 10 microseconds at both sizes. Without this leg the cost row goes
# green on a tree where nothing has been built.
check {F35 COST asking whether the numbers are still this run's is flat in the size of the results file, and never builds the transient surface's fingerprint} \
  [list [expr {[llength [info commands ::op_annot::db_current]] ? 1 : 0}] \
        [expr {$f35_small >= 0 && $f35_small < 1000 ? 1 : 0}] \
        [expr {$f35_big >= 0 && $f35_big < 1000 ? 1 : 0}] \
        [expr {($f35_big <= 3 * $f35_small + 100) ? 1 : 0}] \
        [f_pgrep $F_B_CUR2 {_annot_db_print}] \
        [f_pgrep $F_B_ATT2 {_annot_db_print}]] \
  [list 1 1 1 1 0 0]

# --- teardown ----------------------------------------------------------------
catch {rename ase::last_rawfile {}}
catch {rename f_saved_last_rawfile ase::last_rawfile}
catch {rename ase::results_stale {}}
catch {rename f_saved_results_stale ase::results_stale}
catch {rename ase::echo {}}
catch {rename f_saved_echo ase::echo}
catch {rename ase::ui::design_path {}}
catch {rename f_saved_design_path ase::ui::design_path}
catch {xschem raw clear}
catch {xschem set annot_show 0}

# --- verdict -----------------------------------------------------------------
# ⚠ THE DUAL BANNER IS REQUIRED BY tests/run_regression.tcl's hcases list, which
# this file is registered in. banner_complete needs a WHOLE-LINE "OVERALL: ok"
# as well as the RESULT line; registering a suite there without one reproduces
# the completion-sentinel false red filed four times as 0420 / 0492 / 0629 / 0689.
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
