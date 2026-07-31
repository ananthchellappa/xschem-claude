# expandlabel() segfaults on zero- and negative-multiplicity label expressions
# (issue 0182), plus the once-per-schematic warning for the zero case.
#
# --- the crash ----------------------------------------------------------------
# expandlabel_strdup("") returns NULL, because it calls my_strdup(), which NULLs
# its destination for an EMPTY source (util.c:193). So a zero multiplier yields a
# NULL list string:
#
#     expandlabel.y   if(n==0) return expandlabel_strdup("");   /* -> NULL */
#                     len=strlen(s);                            /* <- NULL deref */
#
# Multiply that NULL again ("2*(0*a)", "0*a*2", "a*0*2") and strlen(NULL) faults,
# in expandlabel_strmult() or expandlabel_strmult2(). Independently, a bus range
# with a zero (or negative) repetition count -- "a[3:0:1:0]", "a[3:0:1:-1]" --
# leaves the element count n[0] at 0, and all four expandlabel_strbus*() then do
#
#     my_realloc(&res, n[0]*(strlen(s)+20));   /* size 0 -> my_realloc FREES res
#                                                 to NULL (util.c:907-910) */
#     sprintf(res+l, "%s[%d]", s, n[i]);       /* res is NULL; n[1] uninitialised */
#
# Third variant: a negative multiplier ("-1*a") reaches
# my_malloc((len+1)*n) with n < 0, which converts to a huge size_t, fails, and
# the memcpy writes through the NULL.
#
# 29 label expressions crashed the shipped binary. All are reachable from an
# ordinary `lab=` attribute on an instance, not merely from `xschem expandlabel`.
#
# --- the decided semantics (user, 2026-07-31) ---------------------------------
# 1. ZERO-COLLAPSE FOLLOWS THE "0*a" PRECEDENT. Every collapsing form returns the
#    ORIGINAL INPUT STRING with *m == -1 -- exactly what "0*a" and "a*0" already
#    do. Rejected: a real zero-width bus ("" with m == 0), and a syntax error.
#    This needed no new semantics: parselabel.l:139-142 ALREADY re-my_strdup2()s
#    the input when the parse produced a NULL, so the whole fix is to stop the
#    fault and let a NULL propagate.
# 2. A NEGATIVE MULTIPLIER IS A TYPO -> the existing yyparse_error path, the same
#    one malformed labels already use. Rejected: clamping negative to zero.
# 3. WARN ONCE PER SCHEMATIC, in the style of the '#'-label warning from issue
#    0165 (netlist.c:1491-1500, gated on print_erc). Rejected: fixing it
#    silently, and warning only during netlisting.
#
# The `m == -1` half of rule 1 is load-bearing, not cosmetic: expandlabel()
# returns NULL only for a NULL input and sets *m = -1 on that path, and sibling
# loops such as hilight.c:1008 are safe only because of that coupling.
#
# --- legs ---------------------------------------------------------------------
#   EB*   the measured battery: 73 label expressions, expansion + multiplicity +
#         whether the syntax-error path fired. 29 of them CRASH the pre-fix
#         binary; the other 44 are CONTROLS that must come out byte-identical.
#         The controls carry more weight than the crashers: a fix that stopped
#         the fault by inventing a new meaning for "0*a" or by breaking a working
#         bus would show up here and nowhere else.
#   ER*   reachability: the crash is reachable from plain schematic data, so at
#         least one leg goes through a real .sch rather than the pure command.
#   EW*   the rule-3 warning: it fires once per schematic, names the instance and
#         the label, and -- the leg that matters most -- does NOT fire for the
#         long-standing harmless forms ("0*a") that work today.
#
# Every leg runs the binary as a SUBPROCESS: pre-fix, most of this file
# segfaults, and a segfault in this file's own interpreter would take the whole
# run down and print nothing.
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_expandlabel_zero_neg_mult_0182.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_expandlabel_zero_neg_mult_0182.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch expandlabel_zero_neg_mult_0182]
set xbin    [file join $repo src xschem]

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE t0182 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

if {[catch {

# --- the battery --------------------------------------------------------------
# `xschem expandlabel` is PURE -- no design, no prepare_netlist_structs -- so the
# expansion legs need no fixture at all.
#
# Run one candidate in its own --nogui child. Returns a 3-element list
# {expansion multiplicity syntax-error?}, or {CRASH {} {}} when the child died
# before printing its marker. Returning a distinguishable CRASH sentinel (rather
# than, say, an empty expansion) is what keeps a dead child from passing a leg
# vacuously.
set seq 0
proc expand_child {lab} {
  global scratch xbin seq
  set sp [file join $scratch child_[incr seq].tcl]
  set f [open $sp w]
  puts $f "set no_recent_files 1"
  puts $f "set r \[xschem expandlabel \{$lab\}\]"
  puts $f {puts "EL=<<$r>>"}
  puts $f {flush stdout; exit 0}
  close $f
  set out {}
  catch {exec $xbin --nogui --pipe -q --nolog --script $sp 2>@1} out
  if {![regexp {EL=<<(.*)>>} $out -> body]} { return [list CRASH {} {}] }
  # `xschem expandlabel` returns "<expansion> <multiplicity>"; the expansion may
  # itself contain spaces (the " " candidate), so split on the LAST field.
  if {![regexp {^(.*) (-?\d+)$} $body -> expansion mult]} {
    return [list UNPARSEABLE $body {}]
  }
  return [list $expansion $mult \
    [expr {[string match {*syntax error in *} $out] ? 1 : 0}]]
}

# {label expansion multiplicity syntax-error?}
#
# Measured one subprocess per row. Rows marked CRASHED-PRE-FIX are the ones this
# file exists for; every other row is a control that must not move.
set battery {
  {{}                {}                                       1  0}
  {{ }               { }                                      1  0}
  {a                 a                                        1  0}
  {a,b               a,b                                      2  0}
  {a.b               a.b                                      1  0}
  {a:b               a:b                                      1  0}
  {$foo              $foo                                     1  0}
  {*                 *                                        1  0}
  {1*a               a                                        1  0}
  {2*a               a,a                                      2  0}

  {a[3:0]            {a[3],a[2],a[1],a[0]}                    4  0}
  {a[1:1]            {a[1]}                                   1  0}
  {a[3..0]           a3,a2,a1,a0                              4  0}
  {a[3:0]_z          {a[3]_z,a[2]_z,a[1]_z,a[0]_z}            4  0}
  {a[0..3]_z         a0_z,a1_z,a2_z,a3_z                      4  0}
  {a[3:0:1:1]        {a[3],a[2],a[1],a[0]}                    4  0}
  {a[7:0:1:1]        {a[7],a[6],a[5],a[4],a[3],a[2],a[1],a[0]} 8 0}
  {a[3:0:1:2]        {a[3],a[2],a[1],a[0],a[4],a[3],a[2],a[1]} 8 0}
  {2*a[3:0]          {a[3],a[2],a[1],a[0],a[3],a[2],a[1],a[0]} 8 0}
  {a[3:0]*2          {a[3],a[3],a[2],a[2],a[1],a[1],a[0],a[0]} 8 0}
  {a[3:0:1:0,5]      {a[5]}                                   1  0}
  {a[5,3:0:1:0]      {a[5]}                                   1  0}
  {a[3..0..1..0,5]   a5                                       1  0}

  {0*a               0*a                                     -1  0}
  {a*0               a*0                                     -1  0}
  {0*a,b             ,b                                       1  0}
  {b,0*a             b,                                       1  0}
  {a,0*b,c           a,,c                                     2  0}
  {0*a,0*b           ,                                        0  0}
  {0*a,0*b,c         ,,c                                      1  0}
  {(0*a),b           ,b                                       1  0}
  {(0*a),(0*b)       ,                                        0  0}
  {(a,b)*0           (a,b)*0                                 -1  0}
  {0*(a,b)           0*(a,b)                                 -1  0}
  {0*a[3:0]          {0*a[3:0]}                              -1  0}
  {a[3:0]*0          {a[3:0]*0}                              -1  0}
  {2*(0*a,b)         ,b,,b                                    2  0}
  {(0*a)             (0*a)                                   -1  0}
  {((0*a))           ((0*a))                                 -1  0}
  {0*(0*a)           0*(0*a)                                 -1  0}
  {0*a*0             0*a*0                                   -1  0}
  {2*a*0             2*a*0                                   -1  0}
  {0*$foo            0*$foo                                  -1  0}
  {$foo*0            $foo*0                                   1  0}

  {,                 ,                                       -1  1}
  {a,                a,                                      -1  1}
  {,a                ,a                                      -1  1}
  {a,,b              a,,b                                    -1  1}
  {a,b,              a,b,                                    -1  1}
  {a*-1              a*-1                                    -1  1}

  {2*(0*a)           2*(0*a)                                 -1  0}
  {(0*a)*2           (0*a)*2                                 -1  0}
  {0*a*2             0*a*2                                   -1  0}
  {2*0*a             2*0*a                                   -1  0}
  {a*0*2             a*0*2                                   -1  0}
  {2*((0*a))         2*((0*a))                               -1  0}
  {2*(0*$foo)        2*(0*$foo)                              -1  0}
  {2*0*a,c           ,c                                       1  0}
  {2*(0*a),b         ,b                                       1  0}
  {2*0*a[3:0]        {2*0*a[3:0]}                            -1  0}
  {a[3:0]*0*2        {a[3:0]*0*2}                            -1  0}

  {a[3:0:1:0]        {a[3:0:1:0]}                            -1  0}
  {a[0:0:0:0]        {a[0:0:0:0]}                            -1  0}
  {a[3:0:1:-1]       {a[3:0:1:-1]}                           -1  0}
  {a[3:0:1:0]_x      {a[3:0:1:0]_x}                          -1  0}
  {a[0:0:0:0]_x      {a[0:0:0:0]_x}                          -1  0}
  {a[3..0..1..0]     {a[3..0..1..0]}                         -1  0}
  {a[3..0..1..-1]    {a[3..0..1..-1]}                        -1  0}
  {a[3..0..1..0]_x   {a[3..0..1..0]_x}                       -1  0}
  {2*a[3:0:1:0]      {2*a[3:0:1:0]}                          -1  0}
  {a[3:0:1:0]*2      {a[3:0:1:0]*2}                          -1  0}
  {0*a[3:0:1:0]      {0*a[3:0:1:0]}                          -1  0}
  {2*(a[3:0:1:0])    {2*(a[3:0:1:0])}                        -1  0}
  {a[3:0:1:0],b      ,b                                       1  0}
  {b,a[3:0:1:0]      b,                                       1  0}

  {-1*a              -1*a                                    -1  1}
  {-2*a              -2*a                                    -1  1}
  {2*-1*a            2*-1*a                                  -1  1}
  {-1*(a,b)          -1*(a,b)                                -1  1}
  {-1*a[3:0]         {-1*a[3:0]}                             -1  1}
}

set n 0
foreach row $battery {
  lassign $row lab expansion mult syn
  incr n
  check "EB[format %02d $n] expandlabel {$lab}" \
    [expand_child $lab] [list $expansion $mult $syn]
}

# --- ER: the crash is reachable from ordinary schematic data ------------------
# The whole battery above goes through `xschem expandlabel`, which touches no
# design at all. Measured pre-fix: an instance carrying lab=2*(0*a) segfaults
# `xschem list_nets` and `xschem netlist`. Without these legs this file would
# only prove the pure command is safe.
proc write_top {path body} {
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach x {G K V S F E} { puts $f "$x {}" }
  puts $f $body
  close $f
}

# Load $sch in a fresh child, run $script there, and report what came back.
# Returns {survived out}.
proc sch_child {tag sch script} {
  global scratch xbin
  set sp [file join $scratch schchild_$tag.tcl]
  set f [open $sp w]
  puts $f "set no_recent_files 1"
  puts $f "set ::XSCHEM_LIBRARY_DEFS [list $::XSCHEM_LIBRARY_DEFS]"
  puts $f {set ::library_registry_defs_only 1}
  puts $f "set ::XSCHEM_LIBRARY_PATH [list $::XSCHEM_LIBRARY_PATH]"
  puts $f "set ::netlist_dir [list $scratch]"
  puts $f "xschem load [list $sch]"
  puts $f $script
  puts $f {puts "ELDONE"}
  puts $f {flush stdout; exit 0}
  close $f
  set out {}
  catch {exec $xbin --nogui --pipe -q --nolog --script $sp 2>@1} out
  return [list [expr {[string match {*ELDONE*} $out] ? 1 : 0}] $out]
}

write_top [file join $scratch top_mult.sch] "N 0 0 200 0 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=lA lab=2*(0*a)}"
lassign [sch_child mult [file join $scratch top_mult.sch] \
  {puts "ELNETS=<<[xschem list_nets]>>"}] surv out
check "ER1 an instance with lab=2*(0*a) survives xschem list_nets" $surv 1
# The node collapsed, so the label names nothing; what matters is that the
# result is a well-formed Tcl list rather than a crash tail. Carry $surv as well:
# a dead child leaves $rows unset, and "" is a perfectly good Tcl list, so
# without it this leg passes VACUOUSLY on exactly the crash it exists to reject.
set rows {}
if {![regexp {ELNETS=<<(.*)>>} $out -> rows]} { set rows {} }
check "ER2 list_nets output is still parseable as a Tcl list" \
  [list $surv [expr {[catch {llength $rows}] ? 0 : 1}]] {1 1}

write_top [file join $scratch top_bus.sch] "N 0 0 200 0 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=lC lab=c\[3:0:1:0\]}"
lassign [sch_child bus [file join $scratch top_bus.sch] \
  {puts "ELNETS=<<[xschem list_nets]>>"}] surv2 out2
check "ER3 an instance with a zero-repetition bus lab survives list_nets" $surv2 1

lassign [sch_child netlist [file join $scratch top_mult.sch] \
  {xschem set netlist_type spice; xschem netlist}] surv3 out3
check "ER4 a schematic with a collapsing lab still netlists without crashing" $surv3 1

# --- EW: the rule-3 warning ---------------------------------------------------
# lA and lC collapse (they crashed pre-fix); lB and lD are the controls. lB is
# the important one: "0*b" has ALWAYS expanded to itself with m == -1 and is
# legal input, so warning about it would turn this fix into a nag on working
# schematics.
write_top [file join $scratch top_warn.sch] "N 0 0 200 0 {}
N 0 100 200 100 {}
N 0 200 200 200 {}
N 0 300 200 300 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=lA lab=2*(0*a)}
C {devices/lab_pin.sym} 0 100 0 0 {name=lB lab=0*b}
C {devices/lab_pin.sym} 0 200 0 0 {name=lC lab=c\[3:0:1:0\]}
C {devices/lab_pin.sym} 0 300 0 0 {name=lD lab=dd}"
lassign [sch_child warn [file join $scratch top_warn.sch] \
  {xschem set netlist_type spice
   xschem netlist
   puts "ELINFO=<<[string map {\n |} [xschem get infowindow_text]]>>"}] surv4 out4
set info {}
regexp {ELINFO=<<(.*)>>} $out4 -> info
# Every 0182 warning line. The transcript also carries unrelated "undriven node"
# errors and the netlist banner, so match the distinctive phrase.
proc collapse_warns {info inst} {
  set n 0
  foreach ln [split $info |] {
    if {![string match {*has a zero-width sub-expression*} $ln]} continue
    if {$inst eq {} || [string match "*instance: $inst:*" $ln]} { incr n }
  }
  return $n
}
check "EW0 the warning fixture netlists at all" $surv4 1
check "EW1 a re-multiplied zero-multiplicity lab warns exactly once" \
  [collapse_warns $info lA] 1
check "EW2 a zero-repetition bus lab warns exactly once" \
  [collapse_warns $info lC] 1
# EW3 is worth more than EW1/EW2: it is the leg that stops the fix becoming a
# nag on schematics that work today. Both carry $surv4, because "no warning" is
# also what a segfaulted child reports.
check "EW3 (control) the long-standing legal form 0*b must NOT warn" \
  [list $surv4 [collapse_warns $info lB]] {1 0}
check "EW4 (control) an ordinary label must NOT warn" \
  [list $surv4 [collapse_warns $info lD]] {1 0}
check "EW5 exactly two warnings in the whole pass (once per schematic, not per \
prepare_netlist_structs call)" [collapse_warns $info {}] 2
check "EW6 the warning quotes the offending label text" \
  [expr {[string match {*net name '2*(0*a)' has a zero-width*} $info] ? 1 : 0}] 1

# EW7: a schematic with only legal labels must produce NO 0182 warning at all --
# the file-level version of EW3.
write_top [file join $scratch top_clean.sch] "N 0 0 200 0 {}
N 0 100 200 100 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=lE lab=0*e}
C {devices/lab_pin.sym} 0 100 0 0 {name=lF lab=f\[3:0\]}"
lassign [sch_child clean [file join $scratch top_clean.sch] \
  {xschem set netlist_type spice
   xschem netlist
   puts "ELINFO=<<[string map {\n |} [xschem get infowindow_text]]>>"}] surv5 out5
set info5 {}
regexp {ELINFO=<<(.*)>>} $out5 -> info5
check "EW7 (control) a schematic of legal labels raises no 0182 warning" \
  [list $surv5 [collapse_warns $info5 {}]] {1 0}

} err]} { puts "FATAL: $err" ; incr fail }

# House banner form: full_audit.sh is_pass() scores on "RESULT: ALL PASS".
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
