# test_annot_op_behind_tran_1242.tcl — ALT-6 FINDS THE OPERATING POINT THE RUN
# ACTUALLY PRODUCED, even when it is not the database that is selected.
# Issue 1242. Subject: cadence::_annot_op_db_ok (utils/annot_mode.tcl).
#
# THE BUG, REPORTED FROM A REAL BENCH. A `tb_bandgap` run in sky130 whose deck
# carried BOTH an operating point and a transient produced ONE raw file holding
# both plots -- `Transient Analysis` (424 variables, 20500 points) and, appended
# behind it by `set appendwrite`, `Operating Point` (891 variables, 1 point).
# ASE-L's auto-plot attaches the plot that HAS A SWEEP, so the selected database
# was the transient, and Alt-6 answered:
#
#   "No operating point results are loaded. These are from a 'tran' run instead,
#    so there are no operating-point numbers to show."
#
# — with 891 operating-point values in the file it had open. The user's words:
# "The sim has both OP and TRAN results available. The user can annotate
# whatever she chooses to."
#
# The predicate asked `xschem raw sim_type`, which answers for the SELECTED slot
# and for nothing else. It now walks three rungs: the selected slot, then any
# other loaded slot, then the selected slot's own FILE.
#
# ⚠ RULING 0856 IS NOT WEAKENED AND R5 IS WHERE THAT IS PROVED. A run that
# produced only a transient still has no operating point, still publishes
# nothing, still gets the sentence, and -- R5b -- is not silently switched away
# from underneath the user by a rung that went looking and failed.
#
# Run TRUE HEADLESS from the repo root (needs no display):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_annot_op_behind_tran_1242.tcl

source [file join [file dirname [info script]] scratch.tcl]
source [file join [file dirname [info script]] .. .. utils annot_mode.tcl]

set fail 0 ; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail" ; incr npass } \
  else { puts "FAIL: $name $detail" ; incr fail }
}
proc eqcheck {name got want} { check $name [expr {$got eq $want}] "(got '$got' want '$want')" }
proc pcall {args} { if {[catch {uplevel 1 $args} r]} { return "ERR:$r" } ; return $r }

set tmp [test_scratch annot_op_behind_tran]

# THE FIXTURE IS THE BENCH'S OWN SHAPE, SHRUNK: one file, the transient first and
# the operating point appended behind it, which is exactly what `set appendwrite`
# leaves on disk. ASCII values so the file is readable by a human debugging this.
# ⚠ BINARY, AND THE SECOND HEADER BUTTS STRAIGHT AGAINST THE FIRST PLOT'S DATA
# WITH NO SEPARATOR. That is the shape ngspice's `set appendwrite` actually
# leaves on disk -- verified byte for byte against the reported bench's own
# 69 MB tb_bandgap_ase.raw, whose `Plotname: Operating Point` begins immediately
# after 81918 lines of the transient's binary block. An ASCII `Values:` fixture
# was written first and the reader would NOT find the second plot in it, so the
# suite would have gone green on a file that is not the file the bug is about.
# `Command:` is present for the same reason: it is in the real header.
proc mkplot {fp title plotname vars pts data} {
  puts -nonewline $fp "Title: $title
Date: Tue Sep  1 22:12:49  2026
Command: ngspice-45.2, Build Fri Sep 12 11:58:13 UTC 2025
Plotname: $plotname
Flags: real
No. Variables: [llength $vars]
No. Points: $pts
Variables:
"
  set i 0
  foreach v $vars {
    puts -nonewline $fp "\t$i\t[lindex $v 0]\t[lindex $v 1]\n"
    incr i
  }
  puts -nonewline $fp "Binary:\n"
  puts -nonewline $fp [binary format d* $data]
}
proc mkboth {path} {
  set f [open $path wb]
  mkplot $f {* op behind tran (issue 1242)} {Transient Analysis} \
    {{time time} {v(a) voltage}} 2 {0.0 1.0 1e-09 2.0}
  mkplot $f {* op behind tran (issue 1242)} {Operating Point} \
    {{v(a) voltage} {v(b) voltage}} 1 {7.5 2.5}
  close $f
}
proc mktran {path} {
  set f [open $path wb]
  mkplot $f {* tran only} {Transient Analysis} \
    {{time time} {v(a) voltage}} 2 {0.0 1.0 1e-09 2.0}
  close $f
}
proc nslots {} { return [llength [pcall cadence::_annot_slots]] }

if {[catch {

set BOTH [file join $tmp both.raw]  ; mkboth $BOTH
set TRAN [file join $tmp tranonly.raw] ; mktran $TRAN

# --- R0 the fixture really is the reported shape ----------------------------
set fd [open $BOTH rb] ; set btxt [read $fd] ; close $fd
eqcheck R0-fixture-one-file-holds-BOTH-plots \
  [list [expr {[string first {Plotname: Transient Analysis} $btxt] >= 0}] \
        [expr {[string first {Plotname: Operating Point} $btxt] >= 0}] \
        [expr {[string first {Plotname: Transient Analysis} $btxt] <
               [string first {Plotname: Operating Point} $btxt]}]] {1 1 1}

# --- R1/R2 THE REPORTED BUG: the transient is selected, the OP is behind it --
catch {xschem raw clear}
eqcheck R1-PRECONDITION-the-transient-is-what-auto-plot-selected \
  [list [pcall xschem raw read $BOTH tran] [pcall xschem raw sim_type] [nslots]] {1 tran 1}
eqcheck R2-Alt-6-finds-the-operating-point-instead-of-refusing \
  [pcall cadence::_annot_op_db_ok] 1
eqcheck R2b-...and-the-selected-database-really-is-one-now \
  [list [pcall xschem raw sim_type] [pcall xschem raw points]] {op 1}
# ⚠ THE PUBLISH IS THE POINT, not the switch. A rung that selected an op
# database update_op() then refused would have moved the defect, not fixed it.
eqcheck R2c-...and-update_op-publishes-from-it [pcall xschem update_op] 1

# --- R3 HOLDING THE KEY DOWN COSTS ONE READ, NOT ONE PER PRESS --------------
# `xschem raw read` dedupes on (rawfile, sim_type): an already-registered pair
# is made current and nothing is re-parsed. Asserted by SLOT COUNT, which is the
# only thing a re-read would move.
set r3_before [nslots]
pcall cadence::_annot_op_db_ok
pcall cadence::_annot_op_db_ok
eqcheck R3-a-second-and-third-press-add-no-slot \
  [list $r3_before [nslots] [pcall xschem raw sim_type]] [list 2 2 op]

# --- R4 RUNG 2: an operating point already loaded, merely not selected -------
# The cheap rung, and it must not need the file at all -- so the file is DELETED
# under it. A rung 3 that fired here would answer 0.
catch {xschem raw clear}
set R4 [file join $tmp r4.raw] ; mkboth $R4
pcall xschem raw read $R4 op
pcall xschem raw read $R4 tran
eqcheck R4-PRECONDITION-two-slots-with-the-transient-selected \
  [list [nslots] [pcall xschem raw sim_type]] {2 tran}
file delete -force $R4
eqcheck R4b-rung-2-switches-to-the-loaded-operating-point-with-no-file-on-disk \
  [list [pcall cadence::_annot_op_db_ok] [pcall xschem raw sim_type] [nslots]] {1 op 2}

# --- R5 RULING 0856 IS INTACT ----------------------------------------------
catch {xschem raw clear}
pcall xschem raw read $TRAN tran
eqcheck R5-a-run-with-ONLY-a-transient-still-refuses \
  [pcall cadence::_annot_op_db_ok] 0
# ⚠ THE SECOND HALF IS THE ONE A CARELESS FIX BREAKS. Three rungs went looking
# and all three failed; the user must be left holding exactly the database they
# had, not whatever the last rung touched.
eqcheck R5b-...and-the-user-is-left-holding-the-database-they-had \
  [list [pcall xschem raw sim_type] [nslots]] {tran 1}

# --- R6 the no-database arm is unchanged ------------------------------------
# Nothing loaded is NOT a refusal: the three OP chords have always been usable
# with no results attached (they arm a rendering switch), and turning that into
# a refusal would break every user who presses 6 before running anything.
catch {xschem raw clear}
eqcheck R6-with-nothing-loaded-at-all-the-answer-is-still-yes \
  [pcall cadence::_annot_op_db_ok] 1

# --- R7 THE 0507 HAZARD: a rawfile path containing SPACES -------------------
# `xschem raw info` is line-structured and a path may contain spaces, so a
# word-range read turns one database into two malformed slots and truncates the
# path (issue 0507). The parser takes the index from the FIRST field and the
# type from the LAST, so the middle may be anything. Driven with a real file in
# a real directory whose name has two spaces in it, because a unit test of the
# parser alone would not prove `raw info` and the parser agree.
set SPDIR [file join $tmp {a dir with spaces}]
file mkdir $SPDIR
set SP [file join $SPDIR {both plots.raw}]
mkboth $SP
catch {xschem raw clear}
pcall xschem raw read $SP tran
set r7 [pcall cadence::_annot_slots]
eqcheck R7-a-path-with-spaces-parses-as-ONE-slot-with-the-path-intact \
  [list [llength $r7] [lindex [lindex $r7 0] 1] [lindex [lindex $r7 0] 2]] \
  [list 1 [file normalize $SP] tran]
eqcheck R7b-...and-the-operating-point-behind-it-is-still-reachable \
  [list [pcall cadence::_annot_op_db_ok] [pcall xschem raw sim_type]] {1 op}
catch {xschem raw clear}

} err]} {
  puts "FATAL: $err"
  puts "  $::errorInfo"
  incr fail
}

catch {test_scratch_drop $tmp}
puts "----"
puts "test_annot_op_behind_tran_1242: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
