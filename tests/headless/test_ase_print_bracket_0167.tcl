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
#   PB8-PB9  the LOG reader accepts both the bare and the quoted log label
#   PB13     ⚖ R3's routing (issue 1429): a BRACKETED row reads the log and a
#            single-vector row reads the results file. The bracket half is this
#            issue's own finding restated -- a bracket is how ngspice's
#            expression parser spells a SUBSCRIPT, so `a[0]` does not NAME a
#            vector to it, which is exactly why print_arg quotes it.
#   PB10-PB12 REAL ngspice: a bus-bit output prints and result_probe reads it
#             back (guarded on auto_execok ngspice); PB12b says which FILE the
#             plain output's number now comes out of
#
# ⚠ THE COUNT IS A FLOOR: 12 -> 14 with issue 1429. ⚖ R3 is ASKED AND
# UNANSWERED; Option C is DECISIONS.md's RECOMMENDATION, built so that a later
# ruling of A or B moves one proc and deletes one reader.
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

# --- PB8-PB9: the LOG reader reads both label forms --------------------------
## ⚠ PB8/PB9 DRIVE `result_probe_log` BY NAME SINCE ISSUE 1429, and the swap
## being one line is the point. ⚖ R3's Option C made the registered
## `result_probe` hook a DISPATCHER: it asks ase::result_source where each row's
## number comes from, and a row whose expression names exactly one vector reads
## the RESULTS FILE instead of the log. `v(out)` is such a row; these two rows
## are about the LOG LABEL issue 0167 is filed about, so they ask the log reader.
## ⚠ `a[0]` STAYS ON THE LOG UNDER THE RULE TOO, and for 0167's own measured
## reason: a bracket is how ngspice's expression parser spells a SUBSCRIPT, so
## `a[0]` does not NAME a vector to it — which is exactly why print_arg quotes
## it. PB13 below asserts both halves of that routing.
## ⚠ AND THE READ IS GUARDED. A `dict get` of a key the change under test can
## REMOVE kills the file instead of reddening a row — measured here: the first
## run of issue 1429 against this suite printed `UNEXPECTED ERROR: key "vout"
## not known in dictionary` and stopped at 8 of 12, which in a sabotage log
## reads as "nothing went red".
proc pbkey {d k} {
  if {[catch {dict exists $d $k} e] || !$e} { return ABSENT }
  return [dict get $d $k]
}
set probe [ase::backend_hook ngspice result_probe]
set logprobe ::ase::backend::ngspice::result_probe_log
set PBLOG "\"a\[0\]\" = 1.500000e+00\nv(out) = 7.500000e-01\n"
set res [$logprobe [bitstate $scratch] $PBLOG]
check "PB8 quoted log label parsed" [pbkey $res a0] 1.500000e+00
check "PB9 bare log label still parsed" [pbkey $res vout] 7.500000e-01

## ⚠ THE ROUTING ITSELF (⚖ R3, ASKED AND UNANSWERED — Option C is DECISIONS.md's
## RECOMMENDATION). With NO results file present, the dispatcher answers the
## bracketed row from the log and the `v(out)` row not at all; the number
## `v(out)` gets in PB12 below comes from the results file the real run writes.
set res [$probe [bitstate $scratch] $PBLOG]
check "PB13 the rule routes a bracketed row to the log and a single-vector row\
 to the results file" \
  [list [pbkey $res a0] [pbkey $res vout] \
        [ase::result_source ngspice {a[0]}] [ase::result_source ngspice v(out)]] \
  {1.500000e+00 ABSENT log raw}

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
  ## ⚠ SINCE ISSUE 1429 THIS NUMBER COMES OUT OF THE RESULTS FILE the same run
  ## wrote, not out of the log — `v(out)` names exactly one vector. The deck
  ## above already carried the `write` line, so nothing in the fixture changed;
  ## what changed is which of the two files was read, and the number is the same.
  check_true "PB12 the plain output still works" \
    [expr {[dict exists $res vout] && abs([dict get $res vout] - 0.75) < 1e-6}]
  check_true "PB12b …and it is the results file it came out of" \
    [file isfile [ase::backend::ngspice::raw_file [bitstate $scratch]]]
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
