# ASE deck: a BRACKETED output expression must be printable (issue 0167).
#
# `render_deck` interpolated an output expr verbatim into `print <expr>`, but
# ngspice's expression parser reads the `[0]` of `print a[0]` as a SUBSCRIPT of
# a vector named `a`, so a bus-bit output printed NOTHING:
#
#   Warning from checkvalid: vector a is not available or has zero length.
#
# and `ase::result_probe` — which scrapes `<expr> = <float>` out of the log —
# saw no value, leaving the Outputs pane blank. Measured against ngspice-42:
#
#   print a[0]      -> warning, no output      print "a[0]"     -> works
#   print v(a[0])   -> warning, no output      print "v(a[0])"  -> works
#   print {a[0]} / print a\[0\]  -> warning    print "@r1[i]"   -> works (bare too)
#   .save a[0]                   -> the vector IS saved (this half was fine)
#
# and the quoted form echoes its label WITH the quotes: `"a[0]" = 1.500000e+00`,
# so result_probe has to accept them.
#
# This became reachable in bulk when ase_migrate started expanding graph bus
# rows into per-bit outputs (1088 bit rows in sky130_tests/test_carry_lookahead).
#
# Legs:
#   PB1-PB4  print_arg: brackets quoted, plain exprs untouched, idempotent
#   PB5-PB7  render_deck emits the quoted form for bracket rows only
#   PB8-PB9  result_probe accepts both the bare and the quoted log label
#   PB10-PB12 REAL ngspice: a bus-bit output prints and result_probe reads it
#             back (guarded on auto_execok ngspice)
#
# True headless (no X). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_print_bracket_0167.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_print_bracket_0167]

if {[catch {

# --- PB1-PB4: print_arg ------------------------------------------------------
check "PB1 bracketed name is quoted" \
  [ase::backend::ngspice::print_arg {a[0]}] {"a[0]"}
check "PB2 bracketed v() form is quoted" \
  [ase::backend::ngspice::print_arg {v(z[6])}] {"v(z[6])"}
check "PB3 plain expr untouched" \
  [ase::backend::ngspice::print_arg {-i(v1)}] {-i(v1)}
check "PB4 an already-quoted expr is left alone" \
  [ase::backend::ngspice::print_arg {"a[0]"}] {"a[0]"}

# --- PB5-PB7: the rendered deck ---------------------------------------------
proc bitstate {rundir} {
  set st [ase::state_default]
  dict set st design {lib l cell c view schematic}
  dict set st rundir $rundir
  dict set st models {}
  dict set st analyses {{type op enabled 1} {type dc enabled 0}
                        {type ac enabled 0} {type tran enabled 0}}
  dict set st outputs {{name a0 expr {a[0]} save 1 plot 0}
                       {name vout expr v(out) save 1 plot 0}}
  return $st
}
set netlist_text "* t\nv1 a\[0\] 0 1.5\nr1 a\[0\] 0 1k\nv2 out 0 0.75\nr2 out 0 1k\n.end\n"
set render [ase::backend_hook ngspice render_deck]
set deck [$render [bitstate $scratch] $netlist_text]
check_true "PB5 bracket output prints quoted" \
  [expr {[string first "print \"a\[0\]\"" $deck] >= 0}]
check_true "PB6 plain output still prints bare" \
  [expr {[string first "print v(out)" $deck] >= 0}]
check_true "PB7 .save side is NOT quoted" \
  [expr {[string first ".save a\[0\]" $deck] >= 0}]
if {$fail} { puts "  deck:\n$deck" }

# --- PB8-PB9: result_probe reads both label forms ----------------------------
set probe [ase::backend_hook ngspice result_probe]
set res [$probe [bitstate $scratch] "\"a\[0\]\" = 1.500000e+00\nv(out) = 7.500000e-01\n"]
check "PB8 quoted log label parsed" [dict get $res a0] 1.500000e+00
check "PB9 bare log label still parsed" [dict get $res vout] 7.500000e-01

# --- PB10-PB12: the real simulator ------------------------------------------
# The deck rendered above is fed to the REAL simulator and its log back through
# the REAL result_probe — the exact chain the defect broke. (`ase::run` is not
# used here because it resolves a lib/cell design out of the registry; this
# case only needs the deck→ngspice→probe leg, hermetically.)
if {[auto_execok ngspice] eq {}} {
  puts "skip: PB10-PB12 (ngspice not installed)"
} else {
  set deckf [file join $scratch bit.sp]
  set f [open $deckf w]; puts $f $deck; close $f
  set logtext ""
  catch {exec ngspice -b $deckf 2>@1} logtext
  set res [$probe [bitstate $scratch] $logtext]
  check_true "PB10 bus-bit output produced a value" [dict exists $res a0]
  if {[dict exists $res a0]} {
    check_true "PB11 bus-bit value is 1.5 V" \
      [expr {abs([dict get $res a0] - 1.5) < 1e-6}]
  } else {
    check_true "PB11 bus-bit value is 1.5 V" 0
  }
  check_true "PB12 the plain output still works" \
    [expr {[dict exists $res vout] && abs([dict get $res vout] - 0.75) < 1e-6}]
  if {$fail} { puts "  last_result: $res" }
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
