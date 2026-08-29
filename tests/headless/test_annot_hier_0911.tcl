# tests/headless/test_annot_hier_0911.tcl -- ISSUE 0911: on a DESCENDED sheet
# with no ASE-L session, pressing 6 never shows the new numbers, and the one
# escape that used to work tells the user a sentence that is false.
#
# ============================================================================
# WHAT THE USER DOES AND SEES
# ============================================================================
# A top sheet that instantiates a subcircuit. No ASE-L session -- the plain
# "results go in netlist_dir" way of working.
#
#   press 6 on the top sheet    -> numbers appear, "Loaded results from
#                                  .../top.raw."
#   descend into the instance
#   re-run the simulation       -> top.raw on disk now holds the new numbers
#   press 6                     -> THE PREVIOUS RUN'S NUMBERS, under
#                                  "These results were already loaded."
#   press 6 again, and again    -> the same
#   Ctrl-6 then 6               -> the same
#   Waves then Clear, then 6    -> the block goes blank under
#                                  "There is no results file at .../sub.raw
#                                   yet. Run a simulation first."
#
# That last sentence is false about a run that just finished, and it names a
# file the design never had. The design's results file is top.raw; it is on
# disk, freshly written, and was attached moments earlier.
#
# RULING D5-1 -- never a number displayed next to a thing it was not measured
# for. Invariant I3 -- not the previous run's number. Driver ruling 0900 --
# every press re-consults the source. The PLAIN ENGLISH ruling -- a refusal
# must say what actually happened. All four, on one gesture.
#
# ============================================================================
# THE MECHANISM, AND WHY EVERY EXISTING ROW STAYS GREEN OVER IT
# ============================================================================
# With no ASE-L session the candidate falls through to the netlist_dir arm of
# cadence::_annot_raw_candidate, which builds the path from
#   xschem get schname
# -- the sheet the user is STANDING ON. After a descend that names the SUBCELL,
# so the candidate is .../sub.raw while the attached database is .../top.raw.
# Guard G4 in op_annot::db_current sees candidate not-equal attached path and
# answers "not mine, leave it exactly where it is" -- the arm that exists so a
# press about one corner never destroys another corner's operating point
# -- issue 0908. Correct rule, wrong input.
#
# Nothing else in the tree descends on this surface: test_annot_stale_0684 and
# test_op_annot both stage a single flat sheet and never leave level 0. So
# staging a hierarchy at all is the first work of this file.
#
# ============================================================================
# THE TWO HALVES OF THE ANSWER, AND WHY BOTH NEED ROWS
# ============================================================================
# 1. THE PATH. Resolve the fallback from the TOP of the hierarchy stack --
#    xschem get schname 0 -- not from the sheet the user is standing on.
# 2. THE LEVEL. The netlist_dir arm hands back an EMPTY level while the ASE-L
#    arm hands back a real one, and that level is what
#    op_annot::db_attach passes to xschem annotate_op, which sets the raw's
#    own idea of which sheet it describes. MEASURED on this binary, descended
#    one level into x1 with the top's operating point attached:
#      attached with level 0   -> sim_sch_path is "x1."  -> device path
#                                 @m.x1.mzz  -> the numbers appear
#      attached with no level  -> sim_sch_path is empty  -> device path
#                                 @m.mzz     -> the block is BLANK
#    So a fix that corrects only the path would re-attach the right file and
#    still paint nothing. Row H2 measures that engine fact directly so the
#    level assertions below are not taken on trust, and the headline rows
#    cannot pass without both halves.
#
# ============================================================================
# WHAT THIS FILE DOES NOT MEASURE
# ============================================================================
# * NO PIXELS. The block is read through op_annot::text, the one renderer the
#   overlay itself calls. A green run here is not proof the sheet repaints.
# * NO SIMULATOR. A re-run is a rewrite of the same raw path, which is what
#   ngspice does.
# * file mtime is 1-second resolution, so every rewrite below is preceded by a
#   real sleep -- issue 0915, a same-second rewrite at the same byte length, is
#   open and known and is staged around here rather than measured.
# * Every path in the fixture is real, never a symlink -- issue 0916 is open
#   and known and is staged around the same way.
#
# Runs on BOTH arms, unchanged:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_annot_hier_0911.tcl
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog --script tests/headless/test_annot_hier_0911.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# --- locations, cwd-independent ---------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch annot_hier_0911]
set lib [file join $scratch lib]
file mkdir $lib

# ============================================================================
# THE ANSWER DISCIPLINE -- an absent proc must never satisfy a golden
# ============================================================================
# Every helper answers NOPROC when the thing it calls does not exist and
# RAISED:<text> when it blows up, so "invalid command name ..." can never
# satisfy a row that expects a real answer.
proc h_ans {cmd args} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  set rc [catch {uplevel #0 [linsert $args 0 $cmd]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc h_cand {}             { return [h_ans ::cadence::_annot_raw_candidate] }
proc h_att {path {lvl {}}} { return [h_ans ::op_annot::db_attach $path $lvl] }
proc h_cur {cand}          { return [h_ans ::op_annot::db_current $cand] }
proc h_attok {path {lvl {}}} {
  set r [h_att $path $lvl]
  if {$r eq {NOPROC} || [string match RAISED:* $r]} { return $r }
  return [lindex $r 0]
}

# --- what the sheet paints, as one line -------------------------------------
proc h_rows {{inst MZZ1}} {
  set r {}
  catch {set r [::op_annot::text $inst]}
  set r [string map [list "\n" { | }] [string trim $r]]
  regsub -all { +} $r { } r
  return $r
}
proc h_msg {} {
  set m {}
  catch {set m [xschem get statusmsg]}
  return $m
}
proc h_rawfile {} {
  if {[catch {xschem raw rawfile} r]} { return NONE }
  if {$r eq {}} { return NONE }
  return [file normalize $r]
}
proc h_simpath {} {
  set p RAISED
  catch {set p [xschem get sim_sch_path]}
  return $p
}
proc h_devpath {{inst MZZ1}} { return [h_ans ::op_annot::devpath $inst] }
proc h_press {mode} { catch {cadence::annot_mode $mode} ; return }
# ONE second of real time before a rewrite: file mtime is 1-second resolution.
proc h_bump {} { after 1100 }

# --- the fixtures ------------------------------------------------------------
# A 1-point operating point over ONE device, named by the caller. The device
# name is a parameter because the whole point of this file is that the name the
# annotator builds DEPENDS on which sheet the database says it describes.
proc h_mkop {path dev id gm gds} {
  set f [open $path w]
  puts -nonewline $f "Title: 0911 hierarchy fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\ti($dev\[id\])\tcurrent
\t1\t$dev\[gm\]\tadmittance
\t2\t$dev\[gds\]\tadmittance
Values:
0\t$id
\t$gm
\t$gds
"
  close $f
}

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
set f [open [file join $lib sub.sym] w]
puts $f {v {xschem version=3.4.6 file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"}
V {}
S {}
E {}
L 4 -20 -20 20 -20 {}
L 4 20 -20 20 20 {}
L 4 20 20 -20 20 {}
L 4 -20 20 -20 -20 {}}
close $f
set f [open [file join $lib sub.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}
G {}
V {}
S {}
E {}
C {[file join $lib zzfet.sym]} 0 0 0 0 {name=MZZ1}"
close $f
set f [open [file join $lib top.sch] w]
puts $f "v {xschem version=3.4.6 file_version=1.2}
G {}
V {}
S {}
E {}
C {[file join $lib sub.sym]} 0 0 0 0 {name=x1}"
close $f

# ⚠ THE DEVPROC IS HIERARCHY-AWARE ON PURPOSE, AND THAT IS WHAT LETS THIS FILE
# SEE THE LEVEL AT ALL. The third argument a descriptor's devproc receives is
# op_annot's ONE prefix seam -- sim_sch_path, the walk from the sheet the
# attached database describes down to the sheet the user is standing on. The
# fixtures in test_annot_stale_0684 and test_op_annot return a CONSTANT device
# path, which is why a wrong level is invisible to every row in them.
proc h_devproc {instname model path spiceprefix} { return "@m.${path}mzz" }
catch {op_annot::register zzs8fet \
  [list devproc h_devproc params {{id id 0} {gm gm 1} {gds gds 1}}]}

set H_TOP [file join $lib top.sch]
set H_SUB [file join $lib sub.sch]
# the device name as seen FROM THE TOP -- the raw a top-level run writes
set H_DEV_HIER {@m.x1.mzz}
# the device name as seen from the subcell opened as its own top sheet
set H_DEV_FLAT {@m.mzz}
set H_R1 {id = 10u | gm = 100u | gds = 1u}
set H_R2 {id = 9m | gm = 7m | gds = 50u}
set H_R3 {id = 3m | gm = 2m | gds = 20u}
set H_BLANK {id = | gm = | gds =}

# THE SENTENCES, byte for byte, as cadence::_annot_msg mints them.
set H_M1 {Showing device operating-point values on the schematic.}
set H_LIVE { These results were already loaded.}

# ⚠ EVERY BLOCK GETS ITS OWN netlist_dir AND ITS OWN top.raw. Two blocks
# sharing a path would put the second one's question on the SECOND-LOOK path,
# where the freshness stamp already exists and the tree is already right; the
# defect lives on the first sight of a path.
proc h_nd {name} {
  set d [file join $::scratch nd $name]
  file mkdir $d
  set ::netlist_dir $d
  return $d
}

# reach the surface under test the way a real session does
source [file join $repo utils annot_mode.tcl]

# --- source snapshots for the STRUCTURAL rows -------------------------------
# Taken BEFORE anything is stubbed, so a row cannot read a test double's body
# and call it the product.
proc h_body {name} {
  if {![llength [info commands $name]]} { return NOPROC }
  return [info body $name]
}
# CODE lines only. The candidate resolver carries a long comment block that
# NAMES the defective spelling out loud, so a structural row that did not strip
# comments would match the warning instead of the code and stay green forever.
proc h_code {body} {
  if {$body eq {NOPROC}} { return {} }
  set o {}
  foreach l [split $body \n] {
    if {[regexp {^\s*#} $l]} continue
    lappend o $l
  }
  return $o
}
proc h_pgrep {body re} {
  set n 0
  foreach l [h_code $body] { if {[regexp -- $re $l]} { incr n } }
  return $n
}
set H_B_CAND [h_body ::cadence::_annot_raw_candidate]
set H_B_CUR  [h_body ::op_annot::db_current]

# ===========================================================================
# H0 -- THE STAGING, SO NOTHING BELOW CAN PASS VACUOUSLY
# ===========================================================================
# A hierarchy really is a hierarchy, and the two spellings really disagree on a
# descended sheet. If they ever agreed -- a subcell whose file name happened to
# match the top's -- every row in this file would pass while the defect was
# live, so the disagreement is asserted out loud rather than assumed.
set ND0 [h_nd h0]
h_mkop [file join $ND0 top.raw] $H_DEV_HIER 1e-05 1e-04 1e-06
catch {xschem raw clear}
xschem load $H_TOP
catch {xschem set annot_show 0}
set h0_top_lvl [xschem get currsch]
set h0_top_sn  [file tail [xschem get schname]]
xschem unselect_all
xschem select instance x1
xschem descend
set h0_dn_lvl [xschem get currsch]
set h0_dn_sn  [file tail [xschem get schname]]
set h0_dn_sn0 [file tail [xschem get schname 0]]
check {H0 fixture: pressing 6 on the top sheet and then descending into the instance really moves the user one level down, and the sheet they are standing on is NOT the sheet the design is simulated from} \
  [list $h0_top_lvl $h0_top_sn $h0_dn_lvl $h0_dn_sn $h0_dn_sn0] \
  [list 0 top.sch 1 sub.sch top.sch]

check {H0b fixture: the two ways of naming the results file really disagree once the user has descended -- the sheet they are standing on says sub, the top of the hierarchy says top} \
  [list [file rootname [file tail [xschem get schname]]] \
        [file rootname [file tail [xschem get schname 0]]]] \
  [list sub top]

# ===========================================================================
# H1 -- THE ENGINE FACT THAT MAKES THE LEVEL WORTH ASSERTING
# ===========================================================================
# Still descended. Attach the SAME top-level results file two ways and watch
# what the annotator builds. This row measures the binary, not the fix, so it
# is green before and after -- its job is to stop a reader dismissing the level
# half of this item as bookkeeping. Without the level the device values the
# user came for are simply not there.
catch {xschem raw clear}
set h1_a_ok [h_attok [file join $ND0 top.raw] 0]
set h1_a_sp [h_simpath]
set h1_a_dp [h_devpath]
set h1_a_rw [h_rows]
catch {xschem raw clear}
set h1_b_ok [h_attok [file join $ND0 top.raw] {}]
set h1_b_sp [h_simpath]
set h1_b_dp [h_devpath]
set h1_b_rw [h_rows]
check {H1 the level is half the answer: on a descended sheet the top's results file attached WITH the level paints the device values, and the very same file attached with no level paints an empty block} \
  [list $h1_a_ok $h1_a_sp $h1_a_dp $h1_a_rw $h1_b_ok $h1_b_sp $h1_b_dp $h1_b_rw] \
  [list 1 {x1.} {@m.x1.mzz} $H_R1 1 {} {@m.mzz} $H_BLANK]

# ===========================================================================
# H2 -- THE CANDIDATE ITSELF, ON A DESCENDED SHEET
# ===========================================================================
# The one function this item changes. Descended, with no ASE-L session, the
# file this surface would load is the TOP's results file and the level travels
# with it. On the shipped tree it names the subcell and hands back an empty
# level, which is issue 0911 in one line.
check {H2 on a descended sheet with no ASE-L session the results file this surface would load is the TOP sheet's, and the hierarchy level travels with it} \
  [h_cand] [list [file join $ND0 top.raw] 0 netlist_dir]

# ===========================================================================
# H3 -- THE HEADLINE, ON THE GESTURE THE USER NAMED
# ===========================================================================
# Press 6 on the top sheet. Descend. Re-run the simulation. Press 6. ONE press
# must show the new numbers and say which file it loaded.
set ND1 [h_nd h3]
set R3 [file join $ND1 top.raw]
h_mkop $R3 $H_DEV_HIER 1e-05 1e-04 1e-06
catch {xschem raw clear}
xschem load $H_TOP
catch {xschem set annot_show 0}
h_press op
set h3_top_msg [h_msg]
set h3_top_att [h_rawfile]
xschem unselect_all
xschem select instance x1
xschem descend
set h3_dn_rows [h_rows]
h_bump
h_mkop $R3 $H_DEV_HIER 9e-03 7e-03 5e-05
h_press op
set h3_p1_rows [h_rows]
set h3_p1_msg  [h_msg]
set h3_p1_att  [h_rawfile]
check {H3 press 6 on the top sheet, descend into the instance, re-run the simulation, press 6 -- ONE press shows the NEW device values and names the file it loaded} \
  [list $h3_top_msg $h3_top_att $h3_dn_rows $h3_p1_rows $h3_p1_msg $h3_p1_att] \
  [list "$H_M1 Loaded results from $R3." $R3 $H_R1 $H_R2 "$H_M1 Loaded results from $R3." $R3]

# ---- and the second and third presses agree with the first ----------------
# Nothing has been re-run in between, so "These results were already loaded."
# is the honest sentence here -- what must never happen is the NUMBERS moving
# back, or a fourth gesture being needed.
h_press op
set h3_p2_rows [h_rows]
set h3_p2_msg  [h_msg]
h_press op
set h3_p3_rows [h_rows]
h_press none
h_press op
set h3_p4_rows [h_rows]
set h3_p4_att  [h_rawfile]
check {H4 pressing 6 twice more, and untick-then-retick with Ctrl-6 and 6, all agree with the first press -- the new numbers stay put and no extra gesture is needed} \
  [list $h3_p2_rows $h3_p2_msg $h3_p3_rows $h3_p4_rows $h3_p4_att] \
  [list $H_R2 "$H_M1$H_LIVE" $H_R2 $H_R2 $R3]

# ---- Waves then Clear, then 6: the one escape the old tree had -------------
# On the shipped tree this is where the false sentence is minted, because the
# search that follows the clear looks for the SUBCELL's results file. It must
# find the file the design really uses and reload it.
catch {xschem raw clear}
h_press op
set h3_wc_rows [h_rows]
set h3_wc_msg  [h_msg]
set h3_wc_att  [h_rawfile]
check {H5 Waves then Clear and then 6, still descended, finds the file the design really uses and puts the numbers back} \
  [list $h3_wc_rows $h3_wc_msg $h3_wc_att] \
  [list $H_R2 "$H_M1 Loaded results from $R3." $R3]

# ===========================================================================
# H6 -- THE FALSE SENTENCE, WITH NO RESULTS FILE ANYWHERE
# ===========================================================================
# The user is told to run a simulation. If they are, the sentence must at least
# name the file the design would produce. On the shipped tree, descended, it
# names the subcell's -- a path nothing in the bench ever writes.
set ND2 [h_nd h6]
catch {xschem raw clear}
xschem load $H_TOP
catch {xschem set annot_show 0}
xschem unselect_all
xschem select instance x1
xschem descend
h_press op
set h6_rows [h_rows]
set h6_msg  [h_msg]
check {H6 with no results file at all, pressing 6 on a descended sheet names the file the design would really produce -- the top sheet's -- not a subcell path nothing ever writes} \
  [list $h6_rows $h6_msg] \
  [list $H_BLANK "$H_M1 There is no results file at [file join $ND2 top.raw] yet. Run a simulation first."]

# ===========================================================================
# H7 / H8 -- TWIN 1: THE FLAT SHEET, WHICH MUST NOT MOVE
# ===========================================================================
# The common case, and the one every existing row in the tree stages. A
# top-level sheet with no hierarchy resolves to exactly the shipped
# select_raw spelling and behaves exactly as it does today.
set ND3 [h_nd h7]
set R7 [file join $ND3 sub.raw]
h_mkop $R7 $H_DEV_FLAT 1e-05 1e-04 1e-06
catch {xschem raw clear}
xschem load $H_SUB
catch {xschem set annot_show 0}
set h7_lvl [xschem get currsch]
set h7_cand [h_cand]
h_press op
set h7_p1_rows [h_rows]
set h7_p1_msg  [h_msg]
h_bump
h_mkop $R7 $H_DEV_FLAT 9e-03 7e-03 5e-05
h_press op
set h7_p2_rows [h_rows]
set h7_p2_msg  [h_msg]
check {H7 flat twin: on an ordinary top-level sheet the results file is still netlist_dir plus the cell name, pressing 6 loads it, and pressing 6 after a re-run shows the new numbers -- unchanged} \
  [list $h7_lvl [lindex $h7_cand 0] [lindex $h7_cand 2] \
        $h7_p1_rows $h7_p1_msg $h7_p2_rows $h7_p2_msg] \
  [list 0 $R7 netlist_dir \
        $H_R1 "$H_M1 Loaded results from $R7." $H_R2 "$H_M1 Loaded results from $R7."]

# ⚠ THE ONE DELIBERATE CHANGE ON THE FLAT ARM IS THE LEVEL, AND IT IS A NO-OP
# HERE. The netlist_dir arm used to hand back an empty level; it now hands back
# the level of the top of the stack, which on a flat sheet is 0. Attaching with
# no level lets the engine default the raw to the CURRENT sheet, which on a
# flat sheet IS level 0 -- so the two are the same attach, and this row proves
# it rather than arguing it. Rows N12 and N13 of tests/headless/test_op_annot.tcl
# gold the empty level and move with this change.
catch {xschem raw clear}
set h8_a_ok [h_attok $R7 {}]
set h8_a_sp [h_simpath]
set h8_a_rw [h_rows]
set h8_a_at [h_rawfile]
catch {xschem raw clear}
set h8_b_ok [h_attok $R7 0]
set h8_b_sp [h_simpath]
set h8_b_rw [h_rows]
set h8_b_at [h_rawfile]
check {H8 flat twin, the level half: on a sheet with no hierarchy, carrying the level and not carrying it are the SAME attach -- same device values, same file, same hierarchy prefix} \
  [list $h8_a_ok $h8_a_sp $h8_a_rw $h8_a_at [lindex $h7_cand 1]] \
  [list $h8_b_ok $h8_b_sp $h8_b_rw $h8_b_at 0]

# ===========================================================================
# H9 -- TWIN 2: ISSUE 0908, WHICH MUST NOT BE WEAKENED
# ===========================================================================
# A press whose results file is a genuinely DIFFERENT file must leave the
# attached database exactly where it is. That arm is the whole reason the
# defect looks like a refusal rather than a crash, and the fix repairs its
# INPUT, never the rule. Staged the only way that reaches it: attach another
# corner's operating point, let it be rewritten so the freshness stamp no
# longer matches, and then ask with a candidate at a different path.
set ND4 [h_nd h9]
set CORNER [file join $scratch corner]
file mkdir $CORNER
set RC [file join $CORNER corner.raw]
h_mkop [file join $ND4 top.raw] $H_DEV_HIER 9e-03 7e-03 5e-05
h_mkop $RC $H_DEV_HIER 1e-05 1e-04 1e-06
catch {xschem raw clear}
xschem load $H_TOP
catch {xschem set annot_show 0}
xschem unselect_all
xschem select instance x1
xschem descend
set h9_att [h_attok $RC 0]
set h9_r0  [h_rows]
h_bump
h_mkop $RC $H_DEV_HIER 3e-03 2e-03 2e-05
set h9_cur [h_cur [h_ans ::cadence::_annot_op_target]]
h_press op
set h9_r1  [h_rows]
set h9_msg [h_msg]
set h9_at  [h_rawfile]
check {H9 issue 0908 twin: another corner's operating point is attached and has since been rewritten -- a press whose own results file is a different file still leaves that database exactly where it is, and says so} \
  [list $h9_att $h9_r0 $h9_cur $h9_r1 $h9_msg $h9_at] \
  [list 1 $H_R1 1 $H_R1 "$H_M1$H_LIVE" [file normalize $RC]]

# ===========================================================================
# H10 -- TWIN 3: THE ASE-L ARM, WHICH IS ALREADY CORRECT
# ===========================================================================
# When a session owns the sheet its answer is the answer, and it is NOT routed
# through the hierarchy resolution added for the fallback: the session already
# walks the stack itself and already carries its own level, which is the level
# of the cell the deck was built from and is not always 0.
set ND5 [h_nd h10]
h_mkop [file join $ND5 top.raw] $H_DEV_HIER 1e-05 1e-04 1e-06
set H_ASE_RAW [file join $scratch ase_session.raw]
h_mkop $H_ASE_RAW $H_DEV_HIER 1e-05 1e-04 1e-06
catch {xschem raw clear}
xschem load $H_TOP
catch {xschem set annot_show 0}
xschem unselect_all
xschem select instance x1
xschem descend
namespace eval ase {}
set h10_had_sfc [llength [info commands ::ase::session_for_current]]
set h10_had_lrf [llength [info commands ::ase::last_rawfile]]
if {$h10_had_sfc} { rename ::ase::session_for_current ::ase::_h10_sfc }
if {$h10_had_lrf} { rename ::ase::last_rawfile ::ase::_h10_lrf }
proc ::ase::session_for_current {} { return [list zzhkey 1 zzlib zzcell schematic] }
proc ::ase::last_rawfile {key} { return [expr {$key eq {zzhkey} ? $::H_ASE_RAW : {}}] }
set h10_cand [h_cand]
catch {rename ::ase::session_for_current {}}
catch {rename ::ase::last_rawfile {}}
if {$h10_had_sfc} { rename ::ase::_h10_sfc ::ase::session_for_current }
if {$h10_had_lrf} { rename ::ase::_h10_lrf ::ase::last_rawfile }
check {H10 ASE-L twin: when a session owns the sheet its own results file and its own level are the answer, on a descended sheet, and the netlist_dir fallback is never consulted} \
  $h10_cand [list $H_ASE_RAW 1 ase]

# ===========================================================================
# H13 -- THE COST OF THE ANSWER, MADE VISIBLE INSTEAD OF SILENT
# ===========================================================================
# ⚠ THIS ROW PINS A DECISION THE USER HAS NOT RATIFIED, AND IT SAYS SO.
# Recorded as a rule debt against issue 0911.
#
# The close stated in issue 0911 section 4 is "always the top of the hierarchy
# stack". There is one working case that pays for it, and it is a real one:
# xschem netlists the sheet the user is STANDING ON, so a user who descends
# into the subcell and runs a simulation from there really does get
# netlist_dir/sub.raw on disk -- measured, the deck is written as sub.spice.
# On the shipped tree pressing 6 in that state loads sub.raw and shows the
# numbers. With the top-always answer it refuses and names top.raw, a file that
# standalone run never produced.
#
# So this row is the OTHER over-refusal, the one the fix itself introduces, and
# it is a running row rather than a paragraph because this branch has twice
# shipped an over-refusal past a green suite. The option set is in the issue
# file: top always, or top first with the current sheet as a fallback. If the
# user rules the second way, THIS row is the one that moves.
set ND6 [h_nd h13]
h_mkop [file join $ND6 sub.raw] $H_DEV_FLAT 1e-05 1e-04 1e-06
catch {xschem raw clear}
xschem load $H_TOP
catch {xschem set annot_show 0}
xschem unselect_all
xschem select instance x1
xschem descend
h_press op
set h13_rows [h_rows]
set h13_msg  [h_msg]
check {H13 UNRATIFIED: a subcircuit simulated on its own from the descended sheet leaves its results next to the subcell name, and pressing 6 there now asks for the top sheet's results file instead -- the price of always answering from the top of the hierarchy} \
  [list $h13_rows $h13_msg] \
  [list $H_BLANK "$H_M1 There is no results file at [file join $ND6 top.raw] yet. Run a simulation first."]

# ===========================================================================
# H11 -- STRUCTURAL: THE SPELLING THE SABOTAGE ROUND PUTS BACK
# ===========================================================================
# The defect is one word. A behavioural row sees it, but this row names it, and
# it is what a reader reaches for when deciding whether the fallback is still
# hierarchy-aware. Comments are stripped first: the warning block inside this
# very proc quotes the defective spelling, so an unstripped grep would match
# the warning and stay green over the defect it warns about.
check {H11 STRUCTURAL the results-file fallback asks for the TOP of the hierarchy stack and carries a level back, and no code line of it asks for the sheet the user is standing on} \
  [list [h_pgrep $H_B_CAND {xschem get schname\s*\]}] \
        [h_pgrep $H_B_CAND {xschem get schname\s+0}] \
        [h_pgrep $H_B_CAND {return \[list .*\{\}\s+netlist_dir\]}] \
        [expr {$H_B_CAND ne {NOPROC} ? 1 : 0}]] \
  [list 0 1 0 1]

# ===========================================================================
# H12 -- STRUCTURAL: GUARD G4 IS NOT WEAKENED, AND THE 0912 FENCE HELD
# ===========================================================================
# The fix repairs guard G4's INPUT. Its two arms must both still be there: the
# no-candidate arm, which is issue 0912's subject and is blocked on a user
# ruling, and the not-mine comparison, which is issue 0908's promise. A fix
# that deleted either would make H9 pass for the wrong reason one day.
check {H12 STRUCTURAL the guard that decides whether the attached results belong to this press still has both arms -- the one issue 0912 is about, untouched, and the one issue 0908 promised} \
  [list [h_pgrep $H_B_CUR {if \{\$cand eq \{\}\} \{ return 1 \}}] \
        [h_pgrep $H_B_CUR {\$nc eq \{\} \|\| \$nc ne \$np}] \
        [expr {$H_B_CUR ne {NOPROC} ? 1 : 0}]] \
  [list 1 1 1]

# --- teardown ----------------------------------------------------------------
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
