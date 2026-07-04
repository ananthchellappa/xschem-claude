#
#  File: select_same_cell.tcl
#
#  Regression for the Ctrl-Alt-H "select all instances of the same cell / view"
#  feature (utils/select_same_cell.tcl). See doc/claude/specs/select_same_cell.md
#
#  Run UNDER xschem (needs the `xschem` command + a real registry/selection):
#      cd tests
#      ../src/xschem --nogui --pipe -q --script select_same_cell.tcl
#

set here  [file normalize [file dirname [info script]]]
set utils [file normalize [file join $here .. utils]]
# capture CIW output (override the real ciw_echo, which no-ops headless anyway)
set ::ECHO {}
proc ciw_echo {line {tag {}}} { lappend ::ECHO [list $tag $line] }
source [file join $utils cadence_nav.tcl]
source [file join $utils select_same_cell.tcl]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure text parse ------------------------------------------------------
check "parse 3-comp"       [selsame::parse_libcellview {a/b/c}]        {a b c}
check "parse 2-comp"       [selsame::parse_libcellview {a/b}]          {a b {}}
check "parse embedded"     [selsame::parse_libcellview {pre foo/bar/sym_alt post}] {foo bar sym_alt}
check "parse no-slash"     [selsame::parse_libcellview {I3}]           {}
check "parse bracket vec"  [selsame::parse_libcellview {x1[5]}]        {}
check "parse 4-comp first3" [selsame::parse_libcellview {a/b/c/d}]     {a b c}

# --- pure matcher ---------------------------------------------------------
set ids {
  {0 tl aa symbol  /p/aa_sym}
  {1 tl aa symbol  /p/aa_sym}
  {2 tl aa sym_alt /p/aa_alt}
  {3 tl bb symbol  /p/bb_sym}
  {4 {} {} {}      /p/x_unreg}
}
check "match lib"          [lindex [selsame::match lib  {tl}          $ids] 0] {0 1 2 3}
check "match cell aa"      [lindex [selsame::match cell {tl aa}       $ids] 0] {0 1 2}
check "match cell bb"      [lindex [selsame::match cell {tl bb}       $ids] 0] {3}
check "match view sym m"   [lindex [selsame::match view {tl aa /p/aa_sym} $ids] 0] {0 1}
check "match view sym o"   [lindex [selsame::match view {tl aa /p/aa_sym} $ids] 1] {{2 sym_alt}}
check "match view alt m"   [lindex [selsame::match view {tl aa /p/aa_alt} $ids] 0] {2}
check "match view alt o"   [lindex [selsame::match view {tl aa /p/aa_alt} $ids] 1] {{0 symbol} {1 symbol}}
check "match view unreg"   [lindex [selsame::match view {{} {} /p/x_unreg} $ids] 0] {4}
check "match view unreg o" [lindex [selsame::match view {{} {} /p/x_unreg} $ids] 1] {}

# --- integration: a real temp library with two symbol views of one cell ----
set src_res [abs_sym_path devices/res.sym]
check "fixture: res.sym resolves" [expr {$src_res ne "" && [file exists $src_res]}] 1

set tmp [file join [pwd] _selsame_[pid]]
file delete -force $tmp
file mkdir $tmp/tl/aa/symbol $tmp/tl/aa/sym_alt $tmp/tl/bb/symbol $tmp/tl/aa/schematic
file copy $src_res $tmp/tl/aa/symbol/aa.sym
file copy $src_res $tmp/tl/aa/sym_alt/aa.sym
file copy $src_res $tmp/tl/bb/symbol/bb.sym
# a schematic-type view for cell aa (used to prove "schematic view == no symbol view")
set fp [open $tmp/tl/aa/schematic/aa.sch w]; puts $fp "v {xschem}"; close $fp
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tl $tmp/tl"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# place instances on the (empty) startup schematic
set base [xschem get instances]
xschem instance tl/aa 0 0   0 0 {name=Xa1}
xschem instance tl/aa 0 100 0 0 {name=Xa2}
xschem instance [file normalize $tmp/tl/aa/sym_alt/aa.sym] 0 200 0 0 {name=Xa3}
xschem instance tl/bb 0 300 0 0 {name=Xb1}
check "placed 4 instances" [expr {[xschem get instances]-$base}] 4

# per-instance identity resolves through the registry
check "i0 ident" [lrange [selsame::inst_ident [expr {$base+0}]] 0 2] {tl aa symbol}
check "i2 ident" [lrange [selsame::inst_ident [expr {$base+2}]] 0 2] {tl aa sym_alt}
check "i3 ident" [lrange [selsame::inst_ident [expr {$base+3}]] 0 2] {tl bb symbol}

# build real idents (as select_same_cell does) and run the matcher over them
set real {}
set n [xschem get instances]
for {set i 0} {$i < $n} {incr i} { lappend real [linsert [selsame::inst_ident $i] 0 $i] }
check "real cell aa = both views" \
  [lsort -integer [lindex [selsame::match cell {tl aa} $real] 0]] "$base [expr {$base+1}] [expr {$base+2}]"

# end-to-end: select one aa/symbol instance -> selects the same-view siblings, warns re alt
set ::ECHO {}
xschem unselect_all ; xschem select instance [expr {$base+0}]
select_same_cell
check "one-inst -> same view count" [xschem get lastsel] 2
set warned 0
foreach e $::ECHO { if {[lindex $e 0] eq "error" && [string match {*different symbol view*} [lindex $e 1]]} { set warned 1 } }
check "one-inst warns re alt view" $warned 1
check "warning names sym_alt" [expr {[string first sym_alt [join $::ECHO]] >= 0}] 1

# Library-Manager decision (target_from_libsel, real registry, no GUI needed)
check "libsel {tl} -> lib mode"   [lindex [selsame::target_from_libsel {tl}] 0] lib
check "libsel {tl aa} -> cell"    [selsame::target_from_libsel {tl aa}] {cell {tl aa} {tl/aa (any view)}}
check "libsel symbol view -> view" [lindex [selsame::target_from_libsel {tl aa symbol}] 0] view
check "libsel schematic view -> cell" [lindex [selsame::target_from_libsel {tl aa schematic}] 0] cell

# target resolution for the text / instance branches (stub cadence::selkind)
proc cadence::selkind {} { return $::FAKE_SEL }
set ::FAKE_SEL {text 0 {look at tl/aa/sym_alt in this note}}
set t [selsame::target]
check "text 3-comp -> view mode" [lindex $t 0] view
check "text 3-comp lib/cell"     [lrange [lindex $t 1] 0 1] {tl aa}
set ::FAKE_SEL {text 0 {ref tl/aa here}}
check "text 2-comp -> cell mode" [lindex [selsame::target] 0] cell
set ::FAKE_SEL [list inst [expr {$base+2}]]
set t [selsame::target]
check "inst -> view mode"        [lindex $t 0] view
check "inst view label"          [lindex $t 2] tl/aa/sym_alt

file delete -force $tmp

if {$nfail} { puts "select_same_cell: $nfail check(s): FAIL" } \
else        { puts "select_same_cell: all checks PASS" }
