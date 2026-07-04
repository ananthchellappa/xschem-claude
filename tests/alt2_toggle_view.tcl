#
#  File: alt2_toggle_view.tcl
#
#  Regression for the Alt-2 "toggle view type (schematic <-> symbol)" feature
#  (src/alt2_toggle_view.tcl). See doc/claude/specs/alt2_toggle_view.md
#
#  Run UNDER xschem (needs the `xschem` command + a real registry):
#      cd tests
#      ../src/xschem --nogui --pipe -q --script alt2_toggle_view.tcl
#

set here [file normalize [file dirname [info script]]]
# capture CIW output (override the real ciw_echo, which no-ops headless anyway)
set ::ECHO {}
proc ciw_echo {line {tag {}}} { lappend ::ECHO [list $tag $line] }
source [file normalize [file join $here .. src alt2_toggle_view.tcl]]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } \
  else { puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail }
}

# --- pure helpers ---------------------------------------------------------
check "other_ext of .sch"  [alt2::other_ext /p/aa.sch]                {.sym}
check "other_ext of .sym"  [alt2::other_ext /p/aa.sym]                {.sch}
check "other_ext nested sym" [alt2::other_ext /p/aa/symbol/aa.sym]    {.sch}
check "default_view sym"   [alt2::default_view .sym]                  {symbol}
check "default_view sch"   [alt2::default_view .sch]                  {schematic}

set wins {
  {.drw     .   .   111 /t/aa/schematic/aa.sch 1}
  {.x1.drw  .x1 .x1 222 /t/aa/symbol/aa.sym    3}
  {.x2.drw  .x2 .x2 333 /t/bb/symbol/bb.sym    4}
}
check "find_window match sym"  [alt2::find_window_for /t/aa/symbol/aa.sym .drw $wins] {.x1.drw}
check "find_window match bb"   [alt2::find_window_for /t/bb/symbol/bb.sym .drw $wins] {.x2.drw}
check "find_window excl curwin" [alt2::find_window_for /t/aa/schematic/aa.sch .drw $wins] {}
check "find_window no match"   [alt2::find_window_for /t/zz/symbol/zz.sym .drw $wins] {}
check "find_window match is cur" [alt2::find_window_for /t/aa/symbol/aa.sym .x1.drw $wins] {}

# --- integration: a real temp library -------------------------------------
set src_sym [abs_sym_path devices/res.sym]
set src_sch [file normalize buried_hilight/a.sch]
check "fixtures resolve" [expr {[file exists $src_sym] && [file exists $src_sch]}] 1

proc cp {src dst} { file mkdir [file dirname $dst]; file copy -force $src $dst; catch {file attributes $dst -permissions 0644} }
set tmp [file join [pwd] _alt2_[pid]]
file delete -force $tmp
# aa: two symbol views + a schematic view (exercises the chooser view-list)
cp $src_sym $tmp/tl/aa/symbol/aa.sym
cp $src_sym $tmp/tl/aa/sym_alt/aa.sym
cp $src_sch $tmp/tl/aa/schematic/aa.sch
# cc: one symbol + one schematic view (obvious toggle, no dialog)
cp $src_sym $tmp/tl/cc/symbol/cc.sym
cp $src_sch $tmp/tl/cc/schematic/cc.sch
# bb: schematic only (no symbol view -> toggle toward symbol is a no-op)
cp $src_sch $tmp/tl/bb/schematic/bb.sch
# flat (unregistered): sibling of the other type in the same dir
cp $src_sch $tmp/flat/foo.sch
cp $src_sym $tmp/flat/foo.sym
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tl $tmp/tl"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# views_of_ext / target_candidates
check "views_of_ext aa .sym" [alt2::views_of_ext tl aa .sym] {sym_alt symbol}
check "views_of_ext aa .sch" [alt2::views_of_ext tl aa .sch] {schematic}
check "views_of_ext bb .sym" [alt2::views_of_ext tl bb .sym] {}
set aacands [alt2::target_candidates [file normalize $tmp/tl/aa/schematic/aa.sch]]
check "aa schematic -> 2 symbol candidates" [llength $aacands] 2
set flatcands [alt2::target_candidates [file normalize $tmp/flat/foo.sch]]
check "flat sch -> sym sibling" [lindex [lindex $flatcands 0] 1] [file normalize $tmp/flat/foo.sym]

# end-to-end toggle on cc (single view each type -> no dialog)
xschem load [file normalize $tmp/tl/cc/schematic/cc.sch]
check "cur is cc schematic" [string match {*/cc/schematic/cc.sch} [xschem get schname]] 1
check "cc schematic editable" [xschem get readonly] 0
alt2_toggle_view
check "toggled to cc symbol" [string match {*/cc/symbol/cc.sym} [xschem get schname]] 1
check "symbol opened read-only (first time)" [xschem get readonly] 1
alt2_toggle_view
check "toggled back to cc schematic" [string match {*/cc/schematic/cc.sch} [xschem get schname]] 1
check "schematic re-opens editable (was edited)" [xschem get readonly] 0
alt2_toggle_view
check "symbol still read-only (never edited)" [xschem get readonly] 1
# simulate the user making the symbol editable (Ctrl-2), then toggle away and back
xschem set readonly 0
alt2_toggle_view
alt2_toggle_view
check "symbol now opens editable (was edited)" [xschem get readonly] 0

# toggling a schematic-only cell toward symbol is a no-op with a hint
xschem load [file normalize $tmp/tl/bb/schematic/bb.sch]
set ::ECHO {}
alt2_toggle_view
check "bb stays schematic (no symbol view)" [string match {*/bb/schematic/bb.sch} [xschem get schname]] 1
check "bb no-op warns" [expr {[string first {no symbol view} [join $::ECHO]] >= 0}] 1

file delete -force $tmp

if {$nfail} { puts "alt2_toggle_view: $nfail check(s): FAIL" } \
else        { puts "alt2_toggle_view: all checks PASS" }
