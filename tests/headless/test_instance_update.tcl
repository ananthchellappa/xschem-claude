# RED-first regression for the "Instance Update" form (doc/claude/specs/instance_update.md).
# Ctrl+Shift+I opens a modeless Tk form that BULK-RETARGETS the master (symbol reference)
# of instances in the current schematic, chosen by an optional Name regex + Scope +
# From-library + From-cell, replaced by a To-library + To-cell. This is the Xschem port of
# the Tanner S-Edit "Instance Update" utility -- every S-Edit primitive replaced by a real
# Xschem verb (getprop/replace_symbol/cellview_path/schematic_cellview/selected_set; native
# Tk clipboard). The split MasterLibrary/MasterCell pair maps to Xschem's single symbol ref.
#
# The util file utils/instance_update.tcl is PURE TCL: the proc DEFINITIONS load headless
# (no Tk); only show()/the fonts and the trailing `bind .drw` are Tk-guarded. Every assertion
# below FAILS before the implementation exists (namespace inst_update:: undefined) -> RED.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_instance_update.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL" ; incr fail }
}

# Source the util under test (relative to repo root, where the harness runs).
set here [file dirname [file normalize [info script]]]
source [file join $here .. .. utils instance_update.tcl]
source [file join $here scratch.tcl]

# Issue 0601: this suite edits the startup UNTITLED buffer, and set_modify(1) ->
# write_backup() (src/actions.c:208 -> src/save.c:4149) then writes `untitled~.sch` into
# the cwd captured at STARTUP (pwd_dir, src/xinit.c:2952) -- the repo root for a hand run,
# tests/ under run_regression.tcl. Nothing here descends or recovers, so suppress it:
# write_backup() returns early when autosave_backup is off (src/save.c:4156). See
# tests/headless/test_undo_selection.tcl for the full note; guarded by
# tests/headless/test_no_untitled_litter.tcl.
set ::saved_autosave_0601 $::autosave_backup
set ::autosave_backup 0

# convenience
proc iu_set {args} { foreach {v val} $args { set ::inst_update::$v $val } }
proc inst_name  {i} { xschem getprop instance $i name }
# {lib cell} of instance $i's master (via the util's reverse-map)
proc inst_lc {i} { lrange [inst_update::inst_master $i] 0 1 }

# ===========================================================================
# A. Pure-Tcl units (no engine, no Tk, no document) -- RED-first core.
# ===========================================================================

# --- 1. set_scratch: sentinel -> scratch mapping ---
iu_set nameRegex {  X1  } fromLib mylib fromCell {(none)} cellRegex {} \
       toLib otherlib toCell {(n/a - keep cell)} fscope view
inst_update::set_scratch
check "scratch none fltCell"    $::inst_update::fltCell   {}
check "scratch none fltCellRe"  $::inst_update::fltCellRe {}
check "scratch name trimmed"    $::inst_update::fltName   X1
check "scratch newCell keep"    $::inst_update::newCell   {}
check "scratch newLib"          $::inst_update::newLib    otherlib
iu_set fromCell {(any cell)} ; inst_update::set_scratch
check "scratch any fltCell"     $::inst_update::fltCell   {}
check "scratch any fltCellRe"   $::inst_update::fltCellRe {}
iu_set fromCell {(Regex)} cellRegex {  nand.*  } ; inst_update::set_scratch
check "scratch regex fltCell"   $::inst_update::fltCell   {}
check "scratch regex fltCellRe" $::inst_update::fltCellRe {nand.*}
iu_set fromCell nand2 cellRegex {} ; inst_update::set_scratch
check "scratch concrete fltCell" $::inst_update::fltCell  nand2
iu_set toCell foocell ; inst_update::set_scratch
check "scratch newCell concrete" $::inst_update::newCell  foocell

# --- 2. runnable predicate ---
iu_set fromLib mylib fromCell {(none)} cellRegex {} toLib otherlib toCell foocell
check "runnable none=0"        [inst_update::runnable] 0
iu_set fromCell {(Regex)} cellRegex {}
check "runnable regex-empty=0" [inst_update::runnable] 0
iu_set fromCell {(Regex)} cellRegex nand.*
check "runnable regex-full=1"  [inst_update::runnable] 1
iu_set fromCell nand2 cellRegex {} toLib {}
check "runnable no-tolib=0"    [inst_update::runnable] 0
iu_set toLib otherlib toCell {}
check "runnable no-tocell=0"   [inst_update::runnable] 0
iu_set toCell {(n/a - keep cell)}
check "runnable keepcell=1"    [inst_update::runnable] 1

# --- 3. on_from_lib_changed resets From-cell to (none) ---
iu_set fromLib mylib fromCell nand2
inst_update::on_from_lib_changed
check "fromlib-changed resets" $::inst_update::fromCell {(none)}

# --- 4. on_to_lib_changed keep-or-fallback (stubbed get_cells) ---
# override get_cells so the unit is document-free
proc inst_update::get_cells {lib} {
  switch -- $lib { has_foo {return {foo bar}} no_foo {return {bar baz}} }
  return {}
}
iu_set toLib has_foo toCell foo
inst_update::on_to_lib_changed
check "tolib keeps foo"        $::inst_update::toCell foo
iu_set toLib no_foo toCell foo
inst_update::on_to_lib_changed
check "tolib drops foo"        $::inst_update::toCell {(n/a - keep cell)}
rename inst_update::get_cells {}   ;# restore the real one

# --- 5. on_from_cell_changed: (any cell) forces To-cell keep ---
iu_set fromCell {(any cell)} toCell somecell
inst_update::on_from_cell_changed
check "anycell forces keep"    $::inst_update::toCell {(n/a - keep cell)}

# --- 6. build_summary canonical string ---
iu_set fscope view nameRegex {} fromLib mylib fromCell nand2 cellRegex {} \
       toLib otherlib toCell {(n/a - keep cell)}
check "summary keep" [inst_update::build_summary] \
      {retarget instance  scope=view  from=mylib/nand2  to=otherlib/(keep)}
iu_set fscope selection nameRegex {X[12]} fromLib mylib fromCell {(Regex)} \
       cellRegex {^nand} toLib otherlib toCell inv
check "summary regex+name" [inst_update::build_summary] \
      {retarget instance  scope=selection  from=mylib/regex:^nand  to=otherlib/inv  name=X[12]}

# --- 7. snapshot / apply_state round-trip over all 8 statevars ---
check "statevars count" [llength $::inst_update::statevars] 8
iu_set nameRegex nn fromLib LL fromCell CC cellRegex RR toLib TL toCell TC \
       fscope selection gotonone 0
set snapA [inst_update::snapshot]
inst_update::reset_fields
check "reset changed fromCell" $::inst_update::fromCell {(none)}
inst_update::apply_state $snapA
check "restore nameRegex" $::inst_update::nameRegex nn
check "restore fromCell"  $::inst_update::fromCell  CC
check "restore cellRegex" $::inst_update::cellRegex RR
check "restore fscope"    $::inst_update::fscope    selection
check "restore gotonone"  $::inst_update::gotonone  0

# --- 8. history snapshot/recall + dup-collapse + clamp + label ---
set ::inst_update::history {}
set ::inst_update::histidx 0
check "hist empty label" [inst_update::histlabel] {(empty)}
inst_update::reset_fields ; iu_set nameRegex AAA
inst_update::history_save
inst_update::history_save              ;# dup of A -> collapse
check "hist len A,A" [llength $::inst_update::history] 1
iu_set nameRegex BBB
inst_update::history_save
check "hist len B"   [llength $::inst_update::history] 2
check "hist parked"  [inst_update::histlabel] {2 saved}
inst_update::history_up
check "hist up1 B"   $::inst_update::nameRegex BBB
check "hist up1 lbl" [inst_update::histlabel] {2 / 2}
inst_update::history_up
check "hist up2 A"   $::inst_update::nameRegex AAA
check "hist up2 lbl" [inst_update::histlabel] {1 / 2}
inst_update::history_up                ;# clamp
check "hist up clamp" $::inst_update::nameRegex AAA
inst_update::history_down
check "hist down B"  $::inst_update::nameRegex BBB

# --- 9. hier_guard: hierarchy -> view + warn + returns 1 ---
iu_set fscope hierarchy
set g [inst_update::hier_guard]
check "hier guard fired"   $g 1
check "hier guard reset"   $::inst_update::fscope view
check "hier guard warns"   [string match {*hierarchy*} $::inst_update::results] 1
iu_set fscope view
check "hier guard view=0"  [inst_update::hier_guard] 0
iu_set fscope selection
check "hier guard sel=0"   [inst_update::hier_guard] 0

# --- 10. compose: keep-cell vs many-to-one vs view default (the -modify core) ---
iu_set newLib foo newCell {}
check "compose keep cell"  [inst_update::compose devlib res {}]     {foo/res symbol}
check "compose keep view"  [inst_update::compose devlib res sch2]   {foo/res sch2}
iu_set newCell capa
check "compose m2one"      [inst_update::compose devlib res {}]     {foo/capa symbol}

# --- 11. regex-as-data safety (regexp on DATA, never eval/subst) ---
# fltName / fltCellRe carrying [ ] { } $ must be inert -- fed only to regexp.
check "inj name bracket" [inst_update::name_match {a[0-9]} a5]   1
check "inj name miss"    [inst_update::name_match {a[0-9]} aX]   0
check "inj cell dollar"  [inst_update::cell_match {r$} xr]       1
check "inj cell brace"   [inst_update::cell_match {n{2}} nnn]    1
check "inj cell brace2"  [inst_update::cell_match {n{2}} n]      0
# (no error thrown above == the transform is regexp, not subst)

# ===========================================================================
# B. Loaded-fixture units (in-memory schematic).
#    devices/res (R1@0,0  R2@100,0), devices/capa (C3@200,0), an off-registry
#    orphan (.sym not under any library, U4@300,0 -> unresolvable master).
# ===========================================================================
set orphdir [test_scratch iu_orph]
file copy -force [abs_sym_path devices/res.sym] [file join $orphdir orph.sym]
set orphsym [file join $orphdir orph.sym]

proc build_fixture {} {
  global orphsym
  xschem clear force
  set res  [abs_sym_path devices/res.sym]
  set capa [abs_sym_path devices/capa.sym]
  xschem instance $res    0 0 0 0 {name=R1}
  xschem instance $res  100 0 0 0 {name=R2}
  xschem instance $capa 200 0 0 0 {name=C3}
  xschem instance $orphsym 300 0 0 0 {name=U4}
  xschem unselect_all
  inst_update::reset_fields
}

# --- 12. inst_master reverse-map + unresolvable ---
build_fixture
check "master R1"     [inst_lc 0] {devices res}
check "master C3"     [inst_lc 2] {devices capa}
check "master orphan" [inst_update::inst_master 3] {}

# --- 13. collect by From-lib/From-cell (concrete) ---
build_fixture
iu_set fscope view fromLib devices fromCell res cellRegex {} nameRegex {}
inst_update::set_scratch
check "collect res idx"   [lsort -integer [inst_update::collect]] {0 1}

# --- 14. collect (any cell) -> every instance of the library ---
build_fixture
iu_set fromLib devices fromCell {(any cell)} cellRegex {} nameRegex {}
inst_update::set_scratch
check "collect any"       [lsort -integer [inst_update::collect]] {0 1 2}

# --- 15. collect (Regex) anchored ---
build_fixture
iu_set fromLib devices fromCell {(Regex)} cellRegex {^res$} nameRegex {}
inst_update::set_scratch
check "collect regex res" [lsort -integer [inst_update::collect]] {0 1}
build_fixture
iu_set fromLib devices fromCell {(Regex)} cellRegex {^ca} nameRegex {}
inst_update::set_scratch
check "collect regex ca"  [inst_update::collect] 2

# --- 16. collect + Name regex narrows the master-matched set ---
build_fixture
iu_set fromLib devices fromCell {(any cell)} cellRegex {} nameRegex {R[12]}
inst_update::set_scratch
check "collect name R12re" [lsort -integer [inst_update::collect]] {0 1}

# --- 17. Retarget many-to-one (observable) + ONE undo restores all ---
build_fixture
iu_set fscope view fromLib devices fromCell res cellRegex {} nameRegex {} \
       toLib devices toCell capa
inst_update::run
check "m2one R1 master"  [inst_lc 0] {devices capa}
check "m2one R2 master"  [inst_lc 1] {devices capa}
check "m2one C3 untouched" [inst_lc 2] {devices capa}
check "m2one hits"       [llength $::inst_update::hits] 2
check "m2one fails"      [llength $::inst_update::fails] 0
check "m2one status"     $::inst_update::status {2 updated}
xschem undo
check "m2one undo R1"    [inst_lc 0] {devices res}
check "m2one undo R2"    [inst_lc 1] {devices res}

# --- 18. Keep-cell composition uses per-instance cell, not a fixed one ---
# (flat-lib migration is not observable via reverse-map; the sabotage target --
#  composing a fixed cell instead of the instance's own -- is asserted directly.)
build_fixture
iu_set newLib devices newCell {}
check "keepcell R1 target" [inst_update::compose {*}[inst_update::inst_master 0]] {devices/res symbol}
check "keepcell C3 target" [inst_update::compose {*}[inst_update::inst_master 2]] {devices/capa symbol}

# --- 19. FAILED path: To a cell that does not exist -> fails, no crash, others ok ---
build_fixture
iu_set fscope view fromLib devices fromCell {(any cell)} cellRegex {} nameRegex {} \
       toLib devices toCell {__no_such_cell_xyz__}
inst_update::run
check "fail count"       [llength $::inst_update::fails] 3
check "fail hits"        [llength $::inst_update::hits]  0
check "fail R1 untouched" [inst_lc 0] {devices res}
check "fail status"      [string match {*failed*} $::inst_update::status] 1

# --- 20. refdes-rename robustness: index-addressed loop retargets every match ---
build_fixture
iu_set fscope view fromLib devices fromCell res cellRegex {} nameRegex {} \
       toLib devices toCell capa
# res template name prefix R -> capa template prefix C : refdes changes mid-batch
inst_update::run
check "rename both retargeted" [list [inst_lc 0] [inst_lc 1]] {{devices capa} {devices capa}}
check "rename hits pre-swap"   [lsort [list [lindex [lindex $::inst_update::hits 0] 0] \
                                            [lindex [lindex $::inst_update::hits 1] 0]]] {R1 R2}

# --- 21. get_from_selection ---
build_fixture
xschem unselect_all
xschem select instance 0 nodraw ; xschem select instance 1 nodraw   ;# both res
inst_update::get_from_selection
check "get one-cell lib"  $::inst_update::fromLib  devices
check "get one-cell cell" $::inst_update::fromCell res
build_fixture
xschem unselect_all
xschem select instance 0 nodraw ; xschem select instance 2 nodraw   ;# res + capa
inst_update::get_from_selection
check "get multi-cell lib"  $::inst_update::fromLib  devices
check "get multi-cell cell" $::inst_update::fromCell {(none)}
build_fixture
xschem unselect_all
inst_update::get_from_selection
check "get none selected" [string match {*no instance*} $::inst_update::results] 1

# --- 22. scope=selection restricts the enumerate set ---
build_fixture
xschem unselect_all
xschem select instance 0 nodraw    ;# only R1 (one of two res)
iu_set fscope selection fromLib devices fromCell res cellRegex {} nameRegex {}
inst_update::set_scratch
set sel [inst_update::collect]
check "scope selection len" [llength $sel] 1
check "scope selection idx" [inst_lc [lindex $sel 0]] {devices res}

# --- 23. list_matches end-to-end: read-only, no selection/history/undo change ---
build_fixture
set ::inst_update::history {}
xschem unselect_all
iu_set fscope view fromLib devices fromCell res cellRegex {} nameRegex {}
inst_update::list_matches
check "list matched R"     [string match {*2 matching*} $::inst_update::results] 1
check "list no selection"  [xschem get lastsel] 0
check "list no history"    [llength $::inst_update::history] 0

# --- 24. hierarchy guard on run + list: reset to view, warn, no cross-sheet mutation ---
build_fixture
iu_set fscope hierarchy fromLib devices fromCell res cellRegex {} nameRegex {} \
       toLib devices toCell capa
inst_update::run
check "hier run reset"   $::inst_update::fscope view
check "hier run warns"   [string match {*hierarchy*} $::inst_update::results] 1
build_fixture
iu_set fscope hierarchy fromLib devices fromCell res
inst_update::list_matches
check "hier list reset"  $::inst_update::fscope view

# --- 25. readonly guard: run refuses, no master changed ---
build_fixture
iu_set fscope view fromLib devices fromCell res cellRegex {} nameRegex {} \
       toLib devices toCell capa
xschem set readonly 1
inst_update::run
xschem set readonly 0
check "ro guard flag"    $::inst_update::last_guard readonly
check "ro no mutation"   [inst_lc 0] {devices res}

# --- 26. symbol-view guard ---
set symf [file join [test_scratch iu_sym] iu.sym]
set fhh [open $symf w]
puts $fhh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fhh "G {}"; puts $fhh "K {type=subcircuit}"; puts $fhh "V {}"; puts $fhh "S {}"; puts $fhh "E {}"
puts $fhh "L 4 -10 -10 10 -10 {}"
close $fhh
xschem load $symf
check "loaded symbol view" [string match {*.sym} [xschem get current_name]] 1
iu_set fscope view fromLib devices fromCell res toLib devices toCell capa
inst_update::run
check "symview run guard"  $::inst_update::last_guard symbol
inst_update::list_matches
check "symview list guard"  $::inst_update::last_guard symbol
catch {file delete -force $symf}

# ===========================================================================
set ::autosave_backup $::saved_autosave_0601   ;# issue 0601
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
