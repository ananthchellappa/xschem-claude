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


# ===========================================================================
# ISSUE 1242 (second half) + ISSUE 0513 — SELECTING IS NOT SHOWING
# ===========================================================================
# The 1242 fix made Alt-6 SELECT the operating point. It did not make it SHOW
# one. Reported by the user immediately afterwards: "Once the Alt-Shift-6 has
# been exercised, there is no way to go back to annotating from the OP results.
# Bad." Measured on their bench, and the numbers say it exactly:
#
#     1. Alt-6        mask=2  db=op    annot(p x idx) = -1 0 -1
#
# `annot_p == -1` is what token.c gates the painted text on, so the mask said
# "Showing DC node voltages on the schematic" while every node read `?`.
#
# TWO CAUSES, and each is enough on its own:
#   * `xschem raw read` does not publish, and must not -- a read is "load this",
#     not "show this". Rung 3 used it.
#   * `xschem raw switch` DID publish, but its gate straddled two databases:
#     `raw->allpoints` is the OUTGOING one (snapshotted before the switch) while
#     `xctx->raw->sim_type` is the INCOMING one. Switching from a 20500-point
#     transient into the 1-point operating point behind it therefore published
#     nothing. Rung 2 used that.
proc annotp {} {
  set an {}
  if {[catch {xschem raw annot} an]} { return ERR }
  return [lindex $an 0]
}

# --- R8 RUNG 3 SHOWS, not merely selects ------------------------------------
catch {xschem raw clear}
pcall xschem raw read $BOTH tran
eqcheck R8-rung-3-publishes-so-a-number-reaches-the-sheet \
  [list [pcall cadence::_annot_op_db_ok] [pcall xschem raw sim_type] \
        [expr {[annotp] >= 0}]] {1 op 1}

# --- R9 RUNG 2 shows too ----------------------------------------------------
catch {xschem raw clear}
pcall xschem raw read $BOTH op
pcall xschem raw read $BOTH tran
eqcheck R9-PRECONDITION-op-loaded-but-transient-selected-and-nothing-published \
  [list [pcall xschem raw sim_type] [annotp]] {tran -1}
eqcheck R9b-rung-2-switches-AND-publishes \
  [list [pcall cadence::_annot_op_db_ok] [pcall xschem raw sim_type] \
        [expr {[annotp] >= 0}]] {1 op 1}

# --- R10 THE C STRADDLE, driven through the verb itself ---------------------
# ⚠ NOT THROUGH THE RUNGS. They now publish for themselves, so they would go
# green over the C defect and this row would prove nothing. `xschem raw switch`
# is asserted DIRECTLY: switching from the 2-point transient INTO the 1-point
# operating point must publish, and before the fix it did not because the gate
# asked the outgoing database how many points it had.
catch {xschem raw clear}
pcall xschem raw read $BOTH op
pcall xschem raw read $BOTH tran
set r10_slots [pcall cadence::_annot_slots]
set r10_op -1
foreach t $r10_slots { if {[lindex $t 2] eq {op}} { set r10_op [lindex $t 0] } }
eqcheck R10-PRECONDITION-a-multi-point-transient-is-selected \
  [list [expr {$r10_op >= 0}] [pcall xschem raw sim_type] [annotp]] {1 tran -1}
pcall xschem raw switch $r10_op
eqcheck R10b-raw-switch-INTO-a-1-point-op-publishes \
  [list [pcall xschem raw sim_type] [expr {[annotp] >= 0}]] {op 1}

# --- R11 THE REPORTED SEQUENCE, END TO END ----------------------------------
# Alt-6, then the transient annotation, then Ctrl-6, then Alt-6 again. The last
# step is the one the user could not get back to.
catch {xschem raw clear}
pcall xschem raw read $BOTH tran
pcall cadence::annot_mode opvolt                      ;# Alt-6
set r11_a [list [pcall xschem raw sim_type] [expr {[annotp] >= 0}]]
# Alt-Shift-6's effect: the transient is re-supplied and published at a time
# point, and bit2 is armed. (The chord itself needs a waveform window with a
# cursor on it; what it LEAVES BEHIND is what this row is about.)
pcall xschem raw read $BOTH tran
pcall xschem annotate_at 1e-09
pcall xschem set annot_show [expr {[pcall xschem get annot_show] | 4}]
set r11_b [list [pcall xschem raw sim_type] [expr {[annotp] >= 0}]]
pcall cadence::annot_mode none                        ;# Ctrl-6
set r11_c [pcall xschem get annot_show]
pcall cadence::annot_mode opvolt                      ;# Alt-6 again
set r11_d [list [pcall xschem raw sim_type] [expr {[annotp] >= 0}] \
                [pcall xschem get annot_show]]
pcall cadence::annot_mode op                          ;# 6
set r11_e [list [pcall xschem raw sim_type] [expr {[annotp] >= 0}] \
                [pcall xschem get annot_show]]
eqcheck R11-the-reported-sequence-gets-back-to-the-operating-point \
  [list $r11_a $r11_b $r11_c $r11_d $r11_e] \
  {{op 1} {tran 1} 0 {op 1 2} {op 1 3}}

# --- R12 rung 1: SELECTED is not PUBLISHED ----------------------------------
# An operating point that is already the selected database may still never have
# been published -- `cursor_b_val` is per database and starts zeroed with
# annot_p at -1. Rung 1 has to publish it, not wave it through.
catch {xschem raw clear}
pcall xschem raw read $BOTH op
eqcheck R12-PRECONDITION-selected-op-with-nothing-published \
  [list [pcall xschem raw sim_type] [annotp]] {op -1}
eqcheck R12b-rung-1-publishes-rather-than-waving-it-through \
  [list [pcall cadence::_annot_op_db_ok] [expr {[annotp] >= 0}]] {1 1}

# --- R13 THE WAY BACK OUT: Alt-Shift-6 after Alt-6 --------------------------
# The user's requirement is both directions, so the transient side is asserted
# too. With the schematic holding the OPERATING POINT and the waveform window
# holding the transient, `_annot_tran_db_current` must answer 0 -- "that is not
# the run you are looking at" -- which is what sends cadence::annot_tran to
# re-supply the transient instead of refusing `notran`.
#
# ⚠ THE VIEWER IS STUBBED, and it has to be: `cadence::_annot_viewer_db` reads
# a live waveform window, which a headless run has none of, and with none it
# answers "no opinion" (return 1, supply skipped). Stubbing it with a REAL
# fingerprint taken from the transient -- not a hand-written one -- is what
# makes this row about the comparison rather than about the stub.
catch {xschem raw clear}
pcall xschem raw read $BOTH tran
set r13_tranprint [pcall cadence::_annot_db_print]
pcall xschem raw read $BOTH op
set r13_had [expr {[info procs ::cadence::_annot_viewer_db] ne {}}]
if {$r13_had} { rename ::cadence::_annot_viewer_db r13_real_vdb }
proc ::cadence::_annot_viewer_db {args} { return [list x $::r13_tranprint ok] }
set r13 [pcall cadence::_annot_tran_db_current]
rename ::cadence::_annot_viewer_db {}
if {$r13_had} { rename r13_real_vdb ::cadence::_annot_viewer_db }
eqcheck R13-with-the-op-selected-the-transient-side-knows-to-re-supply \
  [list [pcall xschem raw sim_type] $r13] {op 0}
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
