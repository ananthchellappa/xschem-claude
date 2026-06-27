# P0: schematic_cellview reverse resolver. Spec: doc/claude/specs/create_symbol_view.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_symbol_view_resolve.tcl
#
# schematic_cellview {abspath} maps an absolute .sch/.sym path to {lib cell view
# layout} (layout = nested|flat), or {} if the path is not under any registered
# library. Longest matching library root wins.

set work /tmp/p0_symview_work
file delete -force $work; file mkdir $work

# A nested (OA) library "mylib" with cell1 having a schematic view, and a flat cell.
file mkdir $work/mylib/cell1/schematic
close [open $work/mylib/cell1/schematic/cell1.sch w]
close [open $work/mylib/flatcell.sch w]
# register it by putting it on the search path (auto-discovered as library "mylib")
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work/mylib:$XSCHEM_LIBRARY_PATH"

set ::fails 0
proc check {name ok got} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name [expr {$ok ? {} : "(got: {$got})"}]"; flush stdout
  if {!$ok} {incr ::fails}
}
proc result {} { puts [expr {$::fails==0 ? {RESULT: ALL PASS} : "RESULT: $::fails FAILED"}]; flush stdout; exit [expr {$::fails!=0}] }

# sanity: the fixture library is registered
set known [lsearch -index 0 -inline [library_list] mylib]
check "fixture library 'mylib' is registered" [expr {$known ne {}}] $known

set r1 [schematic_cellview $work/mylib/cell1/schematic/cell1.sch]
check "nested schematic -> {mylib cell1 schematic nested}" \
  [expr {$r1 eq {mylib cell1 schematic nested}}] $r1

set r2 [schematic_cellview $work/mylib/flatcell.sch]
check "flat schematic -> {mylib flatcell {} flat}" \
  [expr {$r2 eq {mylib flatcell {} flat}}] $r2

set r3 [schematic_cellview /tmp/definitely_nowhere_$work/x.sch]
check "unregistered path -> {}" [expr {$r3 eq {}}] $r3

# a symbol path in the nested cell resolves too (root matches cell)
file mkdir $work/mylib/cell1/symbol
close [open $work/mylib/cell1/symbol/cell1.sym w]
set r4 [schematic_cellview $work/mylib/cell1/symbol/cell1.sym]
check "nested symbol view -> {mylib cell1 symbol nested}" \
  [expr {$r4 eq {mylib cell1 symbol nested}}] $r4

result
