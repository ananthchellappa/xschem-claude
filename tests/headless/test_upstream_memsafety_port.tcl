# Port of six upstream xschem memory-safety fixes (Stefan Schippers' master,
# 2026-07 .. 2026-10), adapted to this fork.  One band per fix that has a
# deterministic trigger; the fixes with none are named at the foot of this
# header with the reason.
#
#   UE  ff88b2a1b  expandlabel.y: after a parse error the static `idxsize` stayed
#                  grown, the next `index` rule malloc'd INITIALIDXSIZE ints and
#                  check_idx() believed the capacity was idxsize -> heap write
#                  past the block.  Without valgrind the pre-fix binary aborts
#                  ("double free or corruption"), so UE1 reddens on its own.
#   UG  88ee177a8  actions.c get_additional_symbols(): check_symbol_storage()
#                  can realloc xctx->sym, leaving `symptr` dangling for
#                  copy_symbol().  Fixture: exactly ELEMDEF (50) symbols loaded,
#                  so the first added polymorphic symbol forces the realloc.
#   UT  c4233c1f9  token.c translate(): a 511-char plain string writes the final
#                  '\0' one byte past the 512-byte result buffer.
#   UB  e29af39c6  save.c read_xschem_file(): an embedded-symbol `[` block with
#                  no preceding instance indexed xctx->inst[-1].
#   UR  e29af39c6  rawtovcd.c: a variable record whose index is >= nvars wrote
#                  names[i] out of bounds.
#
# The valgrind legs are the memory witnesses; they run only where valgrind is
# installed (a `note:` says so otherwise -- never a self-skip banner, which
# full_audit.sh would score as the whole suite skipping).
#
# NOT fenced here, with the reason:
#   830d54512 (draw.c draw_graph_variables sweep_idx bound) -- the only caller
#     already clamps sweep_idx into [0, nvars), so the callee guard is defence
#     in depth; it is out of range only with nvars == 0, and the path draws, so
#     it needs a display.  No cheap deterministic trigger.
#   0fa7b0ed7 (save.c delete_undo leak) -- in this fork undo_dirname is set only
#     by init_undo(), which sets undo_initialized in the same breath, so the
#     early-return leak is unreachable today; ported as a guard.
#
# Every leg runs the binary as a SUBPROCESS: pre-fix, several of these crash,
# and a crash in this file's own interpreter would print nothing.

source [file join [file dirname [info script]] scratch.tcl]

set fail 0; set npass 0
proc check {name got exp} {
    global fail npass
    if {$got eq $exp} { puts "ok:   $name"; incr npass } \
    else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

if {[catch {

set tmp  [test_scratch upmemsafe]
set xbin [info nameofexecutable]
set vtcv [file join [file dirname $xbin] rawtovcd]
set have_vg [expr {[auto_execok valgrind] ne ""}]
if {!$have_vg} { puts "note: valgrind is not installed here; the memory legs were not run" }

# run a shell command line, output to $logf, answer its exit code (-1 on harness error)
proc run_sh {cmdline logf} {
    if {[catch {exec sh -c "$cmdline >$logf 2>&1 ; echo RC=\$?"} out]} { return -1 }
    foreach l [split $out \n] { if {[string match RC=* $l]} { return [string range $l 3 end] } }
    return -1
}
proc tail_log {f n} {
    if {[catch {exec tail -$n $f} t]} return
    foreach l [split $t \n] { puts "  | $l" }
}
proc slurp {f} { set fd [open $f r]; set d [read $fd]; close $fd; return $d }
proc spit {f d} { set fd [open $f w]; puts -nonewline $fd $d; close $fd }
# xschem child, never on any display
proc run_x {script logf {vg 0}} {
    global xbin
    set pre [expr {$vg ? "valgrind -q --error-exitcode=42 " : ""}]
    return [run_sh "env -u DISPLAY timeout 300 $pre$xbin --nogui --pipe -q --norecent\
                    --script $script" $logf]
}
proc marker {log key} {
    if {[regexp -line "^${key}=(.*)\$" [slurp $log] -> v]} { return $v }
    return <absent>
}
proc vg_leg {name script tag} {
    global have_vg tmp
    if {!$have_vg} return
    set rc [run_x $script $tmp/$tag.vg.log 1]
    check "$name valgrind reports no memory error" $rc 0
    if {$rc != 0} { puts "  --- $tag.vg.log ---"; tail_log $tmp/$tag.vg.log 30 }
}

# ===========================================================================
# UE -- expandlabel after a parse error (ff88b2a1b)
# ===========================================================================
spit $tmp/ue.tcl {
catch {xschem expandlabel {a[0:20}}
puts "UE_B=[xschem expandlabel {b[0:30]}]"
catch {xschem expandlabel {a[1:2:]x}}
puts "UE_C=[xschem expandlabel {c[3:0],d}]"
puts "UE_D=[xschem expandlabel {e[2:0]}]"
exit 0
}
set rc [run_x $tmp/ue.tcl $tmp/ue.log]
set want {}
for {set k 0} {$k <= 30} {incr k} { lappend want "b\[$k\]" }
set want [join $want ,]
set got [marker $tmp/ue.log UE_B]
check "UE1 after a parse error, b\[0:30\] still expands to its 31 bits (child rc=$rc)" \
    [list $rc [lindex $got 0] [lindex $got 1]] [list 0 $want 31]
set got [marker $tmp/ue.log UE_C]
check "UE2 after a parse error ending mid-index, a later bus label still parses" \
    [list [lindex $got 0] [lindex $got 1]] [list {c[3],c[2],c[1],c[0],d} 5]
set got [marker $tmp/ue.log UE_D]
check "UE3 and a plain bus label after that" \
    [list [lindex $got 0] [lindex $got 1]] [list {e[2],e[1],e[0]} 3]
vg_leg UE4 $tmp/ue.tcl ue

# ===========================================================================
# UT -- translate() final NUL (c4233c1f9)
# ===========================================================================
spit $tmp/ut.tcl {
puts "UT_LEN=[string length [xschem translate -1 [string repeat a 511]]]"
puts "UT_LEN2=[string length [xschem translate -1 [string repeat b 1023]]]"
exit 0
}
set rc [run_x $tmp/ut.tcl $tmp/ut.log]
check "UT1 a 511- and a 1023-char plain string translate to themselves (child rc=$rc)" \
    [list $rc [marker $tmp/ut.log UT_LEN] [marker $tmp/ut.log UT_LEN2]] {0 511 1023}
vg_leg UT2 $tmp/ut.tcl ut

# ===========================================================================
# UB -- embedded-symbol block before any instance (e29af39c6, save.c)
# ===========================================================================
set V {v {xschem version=3.4.5 file_version=1.2}}
spit $tmp/ub.sch "$V\n\[\n$V\nK {type=subcircuit}\n\]\nC {devices/res.sym} 0 0 0 0 {name=R1}\n"
spit $tmp/ub.tcl "xschem load [list $tmp/ub.sch]\nputs \"UB_N=\[xschem get instances\]\"\nexit 0\n"
set rc [run_x $tmp/ub.tcl $tmp/ub.log]
check "UB1 a leading orphan \[ block is skipped and the instance after it loads (child rc=$rc)" \
    [list $rc [marker $tmp/ub.log UB_N]] {0 1}
vg_leg UB2 $tmp/ub.tcl ub

# ===========================================================================
# UG -- get_additional_symbols() after a symbol-array realloc (88ee177a8)
# ===========================================================================
set gd [file join $tmp gas]
file mkdir $gd
for {set k 0} {$k < 49} {incr k} {
    spit $gd/s$k.sym "$V\nK {type=label\nformat=\"*l@name\"\ntemplate=\"name=l1\"}\n"
}
spit $gd/sub.sym "$V\nK {type=subcircuit\nformat=\"@name @pinlist @symname\"\ntemplate=\"name=x1\"}\nB 5 -2.5 -2.5 2.5 2.5 {name=p dir=inout}\n"
spit $gd/sub.sch "$V\nC {devices/ipin.sym} 0 0 0 0 {name=p1 lab=p}\n"
spit $gd/alt.sch "$V\nC {devices/ipin.sym} 0 0 0 0 {name=p1 lab=p}\n"
set top "$V\n"
for {set k 0} {$k < 49} {incr k} { append top "C {s$k.sym} [expr {$k*20}] 0 0 0 {name=l$k}\n" }
append top "C {sub.sym} 0 100 0 0 {name=x1 schematic=alt.sch}\n"
spit $gd/top.sch $top
spit $tmp/ug.tcl "cd [list $gd]
xschem load [list $gd/top.sch]
puts \"UG_SYMS=\[xschem get symbols\]\"
xschem set netlist_type spice
set netlist_dir [list $gd]
xschem netlist
exit 0
"
set rc [run_x $tmp/ug.tcl $tmp/ug.log]
set net {}
catch {set net [slurp $gd/top.spice]}
# the fixture premise: symbols == ELEMDEF, so the added symbol must grow the array
check "UG1 the fixture loads exactly ELEMDEF symbols (child rc=$rc)" \
    [list $rc [marker $tmp/ug.log UG_SYMS]] {0 50}
check "UG2 the polymorphic instance netlists against its schematic= cell" \
    [list [regexp -line {^x1 \S+ alt$} $net] [regexp -line {^\.subckt alt p$} $net]] {1 1}
vg_leg UG3 $tmp/ug.tcl ug

# ===========================================================================
# UR -- rawtovcd variable index out of range (e29af39c6, rawtovcd.c)
# ===========================================================================
set raw "Title: t\nDate: x\nPlotname: Transient Analysis\nFlags: real\nNo. Variables: 1\n"
append raw "No. Points: 1\nVariables:\n\t5\tv(x)\tvoltage\nBinary:\n"
set fd [open $tmp/bad.raw wb]; puts -nonewline $fd $raw
puts -nonewline $fd [binary format d 0.0]; close $fd
if {![file executable $vtcv]} {
    check "UR0 the in-tree rawtovcd is built" [file executable $vtcv] 1
} else {
    set rc [run_sh "timeout 60 $vtcv $tmp/bad.raw" $tmp/ur.log]
    check "UR1 rawtovcd rejects the out-of-range variable record and still exits 0" \
        [list $rc [regexp {bad variable record} [slurp $tmp/ur.log]]] {0 1}
    if {$have_vg} {
        set rc [run_sh "timeout 120 valgrind -q --error-exitcode=42 $vtcv $tmp/bad.raw" $tmp/ur.vg.log]
        check "UR2 valgrind reports no memory error in rawtovcd" $rc 0
        if {$rc != 0} { tail_log $tmp/ur.vg.log 20 }
    }
}

} bigerr]} { puts "UNEXPECTED ERROR: $bigerr"; puts $::errorInfo; incr fail }

# banner_complete (tests/banner_rule.tcl) needs `OVERALL: ok`; RESULT: last, once.
if {$fail == 0} {
    puts "OVERALL: ok ($npass checks)"
    puts "RESULT: ALL PASS ($npass checks)"
} else {
    puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
