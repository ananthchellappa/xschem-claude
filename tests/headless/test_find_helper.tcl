# RED-first regression for the "Find Navigator" form (doc/claude/specs/find_helper.md).
# Ctrl+Shift+G opens a modeless Tk form that FINDS ports / instances / net-labels by name
# pattern in the current schematic and can SELECT / COUNT / LIST (screen-ordered CSV) /
# bulk-RENAME (regsub on Name) them. This is the Xschem port of the Tanner S-Edit
# "find <type> ... -filter/-modify {script}" utility -- every S-Edit primitive replaced by a
# real Xschem verb (getprop/setprop/select/iterate; native Tk clipboard).
#
# The util file utils/find_helper.tcl is PURE TCL: the proc DEFINITIONS load headless (no Tk),
# only the show()/fonts and the trailing `bind .drw` are Tk-guarded. Every assertion below
# FAILS before the implementation exists (namespace find_helper:: undefined) -> RED, passes after.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_find_helper.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL" ; incr fail }
}

# Source the util under test (relative to repo root, where the harness runs).
set here [file dirname [file normalize [info script]]]
source [file join $here .. .. utils find_helper.tcl]

# convenience
proc fh_set {args} { foreach {v val} $args { set ::find_helper::$v $val } }
proc inst_lab  {i} { xschem getprop instance $i lab }
proc inst_name {i} { xschem getprop instance $i name }

# ===========================================================================
# A. Pure-Tcl units (no engine, no Tk, no document) -- RED-first core.
# ===========================================================================

# --- 1. name_token: type-dependent Name routing (the biggest porting hazard) ---
check "name_token instance" [find_helper::name_token instance] name
check "name_token port"     [find_helper::name_token port]     lab
check "name_token netlabel" [find_helper::name_token netlabel] lab

# --- 2. type_ok: cell::type -> object-class membership ---
check "type_ok port ipin"    [find_helper::type_ok port ipin]        1
check "type_ok port opin"    [find_helper::type_ok port opin]        1
check "type_ok port iopin"   [find_helper::type_ok port iopin]       1
check "type_ok port label"   [find_helper::type_ok port label]       0
check "type_ok port subckt"  [find_helper::type_ok port subcircuit]  0
check "type_ok netlabel lab" [find_helper::type_ok netlabel label]   1
check "type_ok netlabel ipin" [find_helper::type_ok netlabel ipin]   0
check "type_ok inst subckt"  [find_helper::type_ok instance subcircuit] 1
check "type_ok inst res"     [find_helper::type_ok instance resistor]   1
check "type_ok inst ipin"    [find_helper::type_ok instance ipin]    0
check "type_ok inst label"   [find_helper::type_ok instance label]   0
check "type_ok inst showlab" [find_helper::type_ok instance show_label] 0
check "type_ok inst empty"   [find_helper::type_ok instance {}]      0

# --- 3. match: matchers per mode (mode pat val nocase) ---
# default (whole-string)
check "match default hit"    [find_helper::match default clk clk  0] 1
check "match default sub"    [find_helper::match default clk clk2 0] 0
check "match default case"   [find_helper::match default clk CLK  0] 0
# wildcard (glob)
check "match wc star"        [find_helper::match wildcard *_port* v_port1 0] 1
check "match wc no"          [find_helper::match wildcard *_port* port    0] 0
check "match wc q hit"       [find_helper::match wildcard d? d0  0] 1
check "match wc q miss"      [find_helper::match wildcard d? d10 0] 0
# regex
check "match re hit1"        [find_helper::match regex {v.*_port[12]} vx_port1 0] 1
check "match re hit2"        [find_helper::match regex {v.*_port[12]} vy_port2 0] 1
check "match re miss"        [find_helper::match regex {v.*_port[12]} v_port3  0] 0
# exact (case-sensitive whole-string)
check "match exact hit"      [find_helper::match exact clk clk 0] 1
check "match exact case"     [find_helper::match exact clk CLK 0] 0
# contains (substring)
check "match cont angle"     [find_helper::match contains < a<3> 0] 1
check "match cont mid"       [find_helper::match contains port clk_port_a 0] 1
check "match cont miss"      [find_helper::match contains port clk 0] 0
# nocase folds default/contains/exact and combines with regex
check "match default nocase" [find_helper::match default  clk CLK  1] 1
check "match cont nocase"    [find_helper::match contains IN  clk_in 1] 1
check "match regex nocase"   [find_helper::match regex    clk CLK  1] 1

# --- 4. link auto-uncheck rules ---
proc allmodes_on {} { fh_set wildcard 1 regex 1 nocase 1 exact 1 contains 1 add 1 sub 1 first 1 }
allmodes_on ; find_helper::link wildcard
check "link wc clears regex"  $::find_helper::regex 0
check "link wc clears exact"  $::find_helper::exact 0
check "link wc keeps nocase"  $::find_helper::nocase 1
allmodes_on ; find_helper::link regex
check "link re clears wc"     $::find_helper::wildcard 0
check "link re clears exact"  $::find_helper::exact 0
check "link re keeps nocase"  $::find_helper::nocase 1
allmodes_on ; find_helper::link exact
check "link ex clears wc"     $::find_helper::wildcard 0
check "link ex clears regex"  $::find_helper::regex 0
check "link ex clears cont"   $::find_helper::contains 0
check "link ex clears nocase" $::find_helper::nocase 0
allmodes_on ; find_helper::link contains
check "link cont clears exact" $::find_helper::exact 0
allmodes_on ; find_helper::link nocase
check "link nocase clears exact" $::find_helper::exact 0
allmodes_on ; find_helper::link add
check "link add clears sub"   $::find_helper::sub 0
allmodes_on ; find_helper::link sub
check "link sub clears add"   $::find_helper::add 0

# --- 5. order_by_screen: horizontal -> ascending X ; vertical -> top-first (asc Y) ---
check "order horizontal" [find_helper::order_by_screen {{a 0 0} {b 100 0} {c 50 0}}] {a c b}
check "order vertical"   [find_helper::order_by_screen {{a 0 0} {b 0 100} {c 0 50}}] {a c b}
check "order tie->horiz" [find_helper::order_by_screen {{a 0 0} {b 10 10}}]           {a b}
check "order single"     [find_helper::order_by_screen {{a 0 0}}]                     {a}
check "order no-dedup"   [find_helper::order_by_screen {{a 0 0} {a 100 0}}]           {a a}

# --- 6. build_summary canonical string ---
fh_set ftype port fname {v.*_port[12]} fscope view \
       wildcard 0 regex 1 nocase 1 exact 0 contains 0 \
       first 0 add 0 sub 0 count 0 gotonone 1 ffrom {} fto {} report 0
check "summary A" [find_helper::build_summary] \
      {find port  name=v.*_port[12]  regex  nocase  scope=view}
fh_set ftype instance fname {} fscope selection \
       wildcard 1 regex 0 nocase 0 exact 0 contains 0 \
       first 0 add 0 sub 0 count 0 gotonone 0 ffrom {^R} fto RES report 1
check "summary B" [find_helper::build_summary] \
      {find instance  wildcard  scope=selection  goto  rename:/^R/RES/  report}

# --- 7. snapshot / apply_state round-trip over all 16 statevars ---
check "statevars count" [llength $::find_helper::statevars] 16
fh_set ftype netlabel fname foo fscope view wildcard 1 regex 0 nocase 1 exact 0 \
       contains 0 first 1 add 0 sub 1 count 0 gotonone 0 ffrom aa fto bb report 1
set snapA [find_helper::snapshot]
# clobber everything, then restore
find_helper::reset
check "reset changed ftype" $::find_helper::ftype port
find_helper::apply_state $snapA
check "restore ftype"    $::find_helper::ftype netlabel
check "restore fname"    $::find_helper::fname foo
check "restore wildcard" $::find_helper::wildcard 1
check "restore sub"      $::find_helper::sub 1
check "restore gotonone" $::find_helper::gotonone 0
check "restore ffrom"    $::find_helper::ffrom aa
check "restore report"   $::find_helper::report 1

# --- 8. history snapshot/recall + dup-collapse + clamp + label ---
set ::find_helper::history {}
set ::find_helper::histidx 0
check "hist empty label" [find_helper::histlabel] {(empty)}
# state A
find_helper::reset ; fh_set fname AAA
find_helper::history_save
find_helper::history_save            ;# dup of A -> collapse
check "hist len after A,A" [llength $::find_helper::history] 1
# state B
fh_set fname BBB
find_helper::history_save
check "hist len after B"   [llength $::find_helper::history] 2
check "hist parked label"  [find_helper::histlabel] {2 saved}
find_helper::history_up
check "hist up1 recalls B"  $::find_helper::fname BBB
check "hist up1 label"      [find_helper::histlabel] {2 / 2}
find_helper::history_up
check "hist up2 recalls A"  $::find_helper::fname AAA
check "hist up2 label"      [find_helper::histlabel] {1 / 2}
find_helper::history_up               ;# clamp at oldest
check "hist up clamp"       $::find_helper::fname AAA
check "hist up clamp label" [find_helper::histlabel] {1 / 2}
find_helper::history_down
check "hist down recalls B" $::find_helper::fname BBB
find_helper::history_down             ;# park
check "hist down park label" [find_helper::histlabel] {2 saved}

# --- 9. From/To injection safety (regsub on DATA, never eval/subst) ---
check "inj bracket repl" [find_helper::rename_transform x {[BAD]} axbxc] {a[BAD]b[BAD]c}
check "inj dollar data"  [find_helper::rename_transform a b {a$b}]       {b$b}
check "inj brace data"   [find_helper::rename_transform "\{x\}" Y "a{x}b"] {aYb}
check "inj anchor strip" [find_helper::rename_transform {_in$} {} clk_in] clk
check "inj suffix"       [find_helper::rename_transform {$} {_n} foo]     foo_n

# ===========================================================================
# B. Loaded-fixture units (in-memory schematic).
#    2 ipin ports (clk_in@0,0  clk_out@100,0), 1 lab_pin netlabel (data0@200,0),
#    2 component instances (R1@300,0  R2@400,0), a horizontal row for ordering.
# ===========================================================================
proc build_fixture {} {
  xschem clear force
  set ipin [abs_sym_path devices/ipin.sym]
  set labp [abs_sym_path devices/lab_pin.sym]
  set res  [abs_sym_path devices/res.sym]
  xschem instance $ipin   0 0 0 0 {name=p1 lab=clk_in}
  xschem instance $ipin 100 0 0 0 {name=p2 lab=clk_out}
  xschem instance $labp 200 0 0 0 {name=l1 lab=data0}
  xschem instance $res  300 0 0 0 {name=R1 value=1k}
  xschem instance $res  400 0 0 0 {name=R2 value=2k}
  xschem unselect_all
  find_helper::reset
}

# --- 10. collect by type ---
build_fixture
fh_set ftype port fname {} fscope view
check "collect port count"     [llength [find_helper::collect]] 2
check "collect port idx"       [lsort -integer [find_helper::collect]] {0 1}
fh_set ftype netlabel
check "collect netlabel"       [find_helper::collect] 2
fh_set ftype instance
check "collect instance"       [lsort -integer [find_helper::collect]] {3 4}

# --- 11. collect by pattern ---
build_fixture
fh_set ftype port fname clk* wildcard 1
check "collect clk* wildcard"  [llength [find_helper::collect]] 2
build_fixture
fh_set ftype port fname clk_in exact 1
check "collect clk_in exact"   [find_helper::collect] 0
build_fixture
fh_set ftype port fname IN contains 1 nocase 1
check "collect IN contains/nc" [find_helper::collect] 0

# --- 12. -first ---
build_fixture
fh_set ftype port fname clk* wildcard 1 first 1
check "collect first" [llength [find_helper::collect]] 1

# --- 13. selection actions ---
build_fixture
fh_set ftype port fname clk* wildcard 1
find_helper::run
check "sel replace lastsel"   [xschem get lastsel] 2
check "sel replace set"       [lsort [xschem selected_set]] {p1 p2}
# add: pre-select R1, add ports
build_fixture
xschem select instance 3 nodraw   ;# R1
fh_set ftype port fname clk* wildcard 1 add 1
find_helper::run
check "sel add grows"          [xschem get lastsel] 3
# sub: select all, subtract ports
build_fixture
xschem select_all
set total [xschem get lastsel]
fh_set ftype port fname clk* wildcard 1 sub 1
find_helper::run
check "sel sub removes"        [xschem get lastsel] [expr {$total - 2}]
# count: selection unchanged, reports N
build_fixture
xschem select instance 3 nodraw
fh_set ftype port fname clk* wildcard 1 count 1
find_helper::run
check "sel count keeps sel"    [xschem get lastsel] 1
check "sel count n_found"      $::find_helper::n_found 2

# --- 14. rename port (lab token), one undo restores ---
build_fixture
fh_set ftype port fname clk* wildcard 1 ffrom clk fto CK
find_helper::run
check "rename port in"         [inst_lab 0] CK_in
check "rename port out"        [inst_lab 1] CK_out
check "rename n_found"         $::find_helper::n_found 2
check "rename n_renamed"       $::find_helper::n_renamed 2
check "rename n_failed"        $::find_helper::n_failed 0
check "rename hits len"        [llength $::find_helper::hits] 2
xschem undo
check "rename undo in"         [inst_lab 0] clk_in
check "rename undo out"        [inst_lab 1] clk_out

# --- 15. rename instance (name token), index stability ---
build_fixture
fh_set ftype instance fname R* wildcard 1 ffrom {^R} fto RES
find_helper::run
check "rename inst R1"         [string match RES* [inst_name 3]] 1
check "rename inst R2"         [string match RES* [inst_name 4]] 1

# --- 16. report-only (From empty, Report on) ---
build_fixture
fh_set ftype port fname clk* wildcard 1 report 1
find_helper::run
check "report no change in"    [inst_lab 0] clk_in
check "report n_renamed"       $::find_helper::n_renamed 0
check "report hits"            [lsort $::find_helper::hits] {clk_in clk_out}

# --- 17. empty-To delete ---
build_fixture
fh_set ftype port fname clk_in exact 1 ffrom {_in$} fto {}
find_helper::run
check "delete suffix"          [inst_lab 0] clk

# --- 18. FAILED path: a per-item setprop/getprop error lands in `fails`,
#     the valid one in `hits`, and the sweep continues. (Xschem dedups duplicate
#     names silently rather than erroring like S-Edit, so the deterministic
#     per-item error source is an unresolvable identifier -> getprop/setprop throw.)
build_fixture
fh_set ftype port ffrom clk fto CK
set emsg [find_helper::do_rename {0 99}]
check "fail: valid in hits"    [llength $::find_helper::hits] 1
check "fail: bad in fails"     [llength $::find_helper::fails] 1
check "fail: valid applied"    [inst_lab 0] CK_in

# --- 19. scope=selection restricts the enumerate set ---
build_fixture
xschem unselect_all
xschem select instance 0 nodraw     ;# only clk_in
fh_set ftype port fname {} fscope selection
set sel [find_helper::collect]
check "scope selection len"    [llength $sel] 1
check "scope selection obj"    [xschem getprop instance [lindex $sel 0] lab] clk_in

# --- 20. hierarchy guard: run + list refuse, no mutation ---
build_fixture
fh_set ftype port fname clk* wildcard 1 ffrom clk fto CK fscope hierarchy
find_helper::run
check "hier guard flag"        $::find_helper::last_guard hierarchy
check "hier no mutation"       [inst_lab 0] clk_in
find_helper::list_names
check "hier list guard"        $::find_helper::last_guard hierarchy

# --- 21. readonly guard ---
build_fixture
fh_set ftype port fname clk* wildcard 1 ffrom clk fto CK fscope view
xschem set readonly 1
find_helper::run
xschem set readonly 0
check "ro guard flag"          $::find_helper::last_guard readonly
check "ro no mutation"         [inst_lab 0] clk_in

# --- 22. symbol-view guard ---
set symf [file join [pwd] _fh_[pid].sym]
set fhh [open $symf w]
puts $fhh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fhh "G {}"; puts $fhh "K {type=subcircuit}"; puts $fhh "V {}"; puts $fhh "S {}"; puts $fhh "E {}"
puts $fhh "L 4 -10 -10 10 -10 {}"
close $fhh
xschem load $symf
check "loaded symbol view"     [string match {*.sym} [xschem get current_name]] 1
fh_set ftype port fname {} fscope view ffrom {} fto {}
find_helper::run
check "symview run guard"      $::find_helper::last_guard symbol
find_helper::list_names
check "symview list guard"     $::find_helper::last_guard symbol
catch {file delete -force $symf}

# --- 23. list_names end-to-end: screen-ordered CSV, no selection/history change ---
build_fixture
set ::find_helper::history {}
xschem unselect_all
fh_set ftype port fname {} fscope view
find_helper::list_names
check "list csv"               $::find_helper::results {clk_in,clk_out}
check "list n_listed"          $::find_helper::n_listed 2
check "list no selection"      [xschem get lastsel] 0
check "list no history"        [llength $::find_helper::history] 0

# ===========================================================================
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
