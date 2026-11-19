# COPY A SET OF CELLS AND POINT THE COPIES AT EACH OTHER
# (doc/claude/specs/copy_hierarchical.md; engine and decisions in
# src/copy_form.tcl, wiring in src/library_manager.tcl).
#
# The case this exists for: copy a cell (buf -> nbuf) and its test bench
# (buf_tb -> ntb), and have the copied bench test the copied cell, saved ASE-L
# states included. A file copy alone leaves the bench instantiating the old cell
# and its states simulating the old bench.
#
# Everything here runs with no display: the engine edits files as text and the
# form's decisions are plain data. The widgets are in test_copy_form.tcl.
#
#   S*  reading a schematic: which lines are instances, and which cell a
#       reference names, in every spelling.
#   H*  the hierarchy below a cell, excluded libraries, a loop.
#   N*  names: what cannot be a cell name, and the names the form proposes.
#   R*  the table: default rows, copy / use / keep, hand edits, the plan.
#   W*  plans that are refused, each with its reason, nothing created.
#   X*  the copy itself: instances and states re-pointed, everything else
#       byte for byte, and what is reported as still naming an original.
#   U*  references pointed at a cell that already exists (nothing copied).
#   O*  the three reference scopes, and a file that is open in a window.
#   P*  a choice of views.
#   B*  a failure half way puts everything back.
#   F*  flat libraries, another library, bytes that are not ASCII.
#   L*  the Library Manager's own commands: copy, copy plan, rename, and the
#       action-log line a copy plan leaves, replayed.
#
# Run:  tests/headless/run_suites.sh --nogui test_copy_retarget
# Registered in hcases in tests/run_regression.tcl. Prints "OVERALL: ok".

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
  flush stdout
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# Evaluate $script in the CALLER's frame and return its result, or a legible
# sentinel if it raised, so one missing proc costs one row and not the band.
proc q {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED($r)" }
  return $r
}

set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set work [test_scratch copy_retarget]

proc slurp {path} {
  set f [open $path r]; fconfigure $f -translation binary
  set s [read $f]; close $f
  return $s
}
proc spit {path text} {
  file mkdir [file dirname $path]
  set f [open $path w]; fconfigure $f -translation binary
  puts -nonewline $f $text; close $f
}
proc md5of {path} { return [lindex [exec md5sum $path] 0] }

# ---------------------------------------------------------------------------
# fixture
# ---------------------------------------------------------------------------
# One instance record, as the schematic writer spells it.
proc inst {ref x {attrs {name=x1}}} { return "C \{$ref\} $x 0 0 0 \{$attrs\}" }
set HEAD [join [list "v \{xschem version=3.4.8RC file_version=1.3\}" "G \{\}" "K \{\}" "V \{\}" "S \{\}" "F \{\}" "E \{\}"] \n]
proc sch {lines} { return "$::HEAD\n[join $lines \n]\n" }
proc sym {} { return "$::HEAD\nL 4 -10 0 10 0 \{\}\n" }

# A state file in the saver's own form: one `key value` per line.
proc state_text {pairs} {
  set lines {}
  foreach {k v} $pairs { lappend lines "$k [list $v]" }
  return "[join $lines \n]\n"
}
proc state_of {path} { return [dict create {*}[slurp $path]] }

# Build (or rebuild) the whole fixture under $work. Returns nothing; every band
# that changes files calls it again, so no band depends on the one before it.
proc build {} {
  global work
  foreach d {dlib olib flib prim_pr far models sim} { file delete -force [file join $work $d] }
  set D [file join $work dlib]
  # --- dlib: the design library (cell/view directories) ----------------------
  spit $D/bias/schematic/bias.sch [sch [list [inst prim_pr/res 0 name=R1]]]
  spit $D/bias/symbol/bias.sym [sym]
  spit $D/buf/schematic/buf.sch [sch [list \
    "T \{buf: a buffer\} 0 -100 0 0 0.3 0.3 \{\}" \
    [inst dlib/bias 0 name=xb] [inst prim_pr/res 200 "name=R1\nvalue=1k"]]]
  spit $D/buf/symbol/buf.sym [sym]
  spit $D/buf_tb/schematic/buf_tb.sch [sch [list \
    "T \{buf_tb: the bench of buf\} 0 -100 0 0 0.3 0.3 \{\}" \
    "N 0 0 100 0 \{lab=IN\}" \
    [inst dlib/buf 200 name=x1] \
    [inst dlib/buf.sym 400 name=x2] \
    [inst dlib/buf.sch 600 name=x3] \
    [inst dlib/buf/symbol/buf.sym 800 name=x4] \
    [inst $D/buf/symbol/buf.sym 1000 name=x5] \
    [inst prim_pr/res 1200 "name=R1\nvalue=1k"] \
    [inst prim_pr/code 1400 "name=s1 value=\"* a comment\nC \\\{dlib/buf\\\} is text, not an instance\n.param a=1\n\""] \
    [inst dlib/nosuchcell 1600 name=x6] \
    [inst https://example.org/a.sym 1800 name=x7]]]
  spit $D/buf_tb/includes/ns.spice "* nodesets of the buf_tb bench\n.nodeset v(out)=1\n"
  spit $D/buf_tb/includes/corner.lib "* corner\n"
  set viewer [dict create open 0 sharedx 1 rawfile /sim/buf_tb_ase.raw \
    graphs [list \
      [dict create traces [list \
        [dict create expr v(out) name out vec v(out) color 4] \
        [dict create expr {lg db20()} name LG vec lg color 5 rawfile /sim/buf_tb_ase.raw sim_type stb] \
        [dict create expr x name x vec x color 6 rawfile /sim/saved/dlib/buf_tb/r1/other.raw sim_type ac] \
        [dict create expr z name z vec z color 7 rawfile /sim/abc_tb_ase.raw sim_type ac]] \
        logx 0 markers {2 0 0 154 5.5 -21.2}]] \
    mode single target 0 \
    tabs [list [dict create name {Tab 1} layout [dict create sharedx 0 graphs [list \
      [dict create traces [list [dict create expr y name y vec y color 4 rawfile buf_tb_ase.raw sim_type tran]]]]]]] \
    activetab 1]
  spit $D/buf_tb/ngspice_state1/buf_tb.state [state_text [list \
    version 1 simulator ngspice \
    design {lib dlib cell buf_tb view schematic} rundir {} temperature 27 \
    models [list {file {$::CR_ROOT/models/all.lib} section tt} {file {$::CR_ROOT/dlib/buf_tb/includes/corner.lib} section ff}] \
    variables {{name vsup value 3.6}} \
    outputs {{name out expr v(out) save 1 plot 1} {name a1 expr v(x1.a1) save 1 plot 0}} \
    includes [list {file {$::CR_ROOT/dlib/buf_tb/includes/ns.spice}} {file /abs/elsewhere/x.spice} {file {$::CR_ROOT/dlib/buf_tb/includes/missing.spice}}] \
    viewer $viewer]]
  # a state the user pointed at ANOTHER cell: not this bench's own
  spit $D/buf_tb/ngspice_other/buf_tb.state [state_text [list \
    version 1 simulator ngspice design {lib dlib cell bias view schematic} rundir {} \
    viewer {open 0 rawfile /sim/bias_ase.raw}]]
  # a state under the bench whose design is the DEVICE
  spit $D/buf_tb/ngspice_dut/buf_tb.state [state_text [list \
    version 1 simulator ngspice design {lib dlib cell buf view schematic} rundir {} \
    viewer {open 0 rawfile /sim/buf_ase.raw}]]
  spit $D/user1/schematic/user1.sch [sch [list [inst dlib/buf 0 name=x1] [inst dlib/bias 200 name=x2]]]
  spit $D/loop_a/schematic/loop_a.sch [sch [list [inst dlib/loop_b 0]]]
  spit $D/loop_a/symbol/loop_a.sym [sym]
  spit $D/loop_b/schematic/loop_b.sch [sch [list [inst dlib/loop_a 0]]]
  spit $D/loop_b/symbol/loop_b.sym [sym]
  # --- prim_pr: a primitive library (excluded by default) --------------------
  spit $work/prim_pr/res/symbol/res.sym [sym]
  spit $work/prim_pr/code/symbol/code.sym [sym]
  # --- olib: another design library, with a cell that uses dlib/buf ----------
  spit $work/olib/ouser/schematic/ouser.sch [sch [list [inst dlib/buf 0 name=x1]]]
  spit $work/olib/ouser2/schematic/ouser2.sch [sch [list [inst dlib/buf 0 name=x1]]]
  # --- far/zlib: a library that is not beside dlib ---------------------------
  spit $work/far/zlib/zz/schematic/zz.sch [sch {}]
  # --- flib: a library of loose files ----------------------------------------
  spit $work/flib/fl.sym [sym]
  spit $work/flib/fl.sch [sch [list [inst prim_pr/res 0 name=R1]]]
  spit $work/flib/fl_tb.sch [sch [list [inst fl.sym 0 name=x1] [inst flib/fl 200 name=x2]]]
  spit $work/models/all.lib "* models\n"
  set f [open [file join $work library.defs] w]
  foreach {n p} {dlib dlib olib olib prim_pr prim_pr zlib far/zlib flib flib} { puts $f "DEFINE $n $p" }
  close $f
}
build
set ::XSCHEM_LIBRARY_DEFS [file join $work library.defs]
set ::CR_ROOT $work
# the library root and the flat library are on the search list, as a workarea
# that still uses path references has them
set keep_pathlist $::pathlist
lappend ::pathlist $work [file join $work flib]
set D [file join $work dlib]

check "Z1 the fixture libraries are registered" \
  [lmap n {dlib olib prim_pr zlib flib} {expr {[library_resolve $n] ne {}}}] {1 1 1 1 1}
check "Z2 ... dlib keeps cells as directories and flib as loose files" \
  [list [library_cell_layout dlib buf_tb] [library_cell_layout flib fl]] {nested flat}

# =====================================================================
# S* -- reading a schematic
# =====================================================================
set tb [split [slurp $D/buf_tb/schematic/buf_tb.sch] \n]
set scan [copyform::sch_scan $tb]
set refs {}
foreach {i r} $scan { lappend refs $r }
check "S1 every instance record of the bench is found, in file order" $refs \
  [list dlib/buf dlib/buf.sym dlib/buf.sch dlib/buf/symbol/buf.sym $D/buf/symbol/buf.sym \
        prim_pr/res prim_pr/code dlib/nosuchcell https://example.org/a.sym]
check "S2 ... each at the line it is on" \
  [lmap {i r} $scan {string match "C \{*" [lindex $tb $i]}] {1 1 1 1 1 1 1 1 1}
check "S3 a line inside an attribute block is not an instance, escaped or not" \
  [copyform::sch_scan [list "K \{type=x" "C \{dlib/buf\} 0 0 0 0 \{\}" "\}" "C \{dlib/bias\} 0 0 0 0 \{\}"]] \
  {3 dlib/bias}
check "S4 a multi-line attribute does not hide the instance after it" \
  [copyform::sch_scan [list "C \{a/b\} 0 0 0 0 \{name=x" "value=1\}" "C \{c/d\} 0 0 0 0 \{\}"]] \
  {0 a/b 2 c/d}
check "S5 an escaped brace inside a reference stays part of it" \
  [copyform::sch_scan [list "C \{we\\\}ird\} 0 0 0 0 \{\}"]] [list 0 "we\\\}ird"]

copyform::fresh
set sd [file join $D buf_tb schematic]
check "S6 library/cell names a cell: lq, no extension" [copyform::ref_cell dlib/buf $sd] {dlib buf {} lq {}}
check "S7 ... with .sym" [copyform::ref_cell dlib/buf.sym $sd] {dlib buf .sym lq {}}
check "S8 ... with .sch" [copyform::ref_cell dlib/buf.sch $sd] {dlib buf .sch lq {}}
check "S9 a path found on the search list names the same cell: rel" \
  [copyform::ref_cell dlib/buf/symbol/buf.sym $sd] {dlib buf .sym rel symbol}
check "S10 an absolute path names it too: abs" \
  [copyform::ref_cell $D/buf/symbol/buf.sym $sd] {dlib buf .sym abs symbol}
check "S11 a loose file of a flat library, by search path" \
  [copyform::ref_cell fl.sym [file join $work flib]] {flib fl .sym rel {}}
check "S12 a cell that does not exist, a URL and an empty reference name nothing" \
  [list [copyform::ref_cell dlib/nosuchcell $sd] [copyform::ref_cell https://example.org/a.sym $sd] \
        [copyform::ref_cell {} $sd]] {{} {} {}}

check "S13 the reference written for the copy keeps the spelling: lq" \
  [lmap r {dlib/buf dlib/buf.sym dlib/buf.sch} {copyform::ref_new [copyform::ref_cell $r $sd] dlib nbuf}] \
  {dlib/nbuf dlib/nbuf.sym dlib/nbuf.sch}
check "S14 ... a search-path reference becomes library/cell" \
  [copyform::ref_new [copyform::ref_cell dlib/buf/symbol/buf.sym $sd] dlib nbuf] dlib/nbuf
check "S15 ... an absolute path whose copy is not there yet is left alone" \
  [copyform::ref_new [copyform::ref_cell $D/buf/symbol/buf.sym $sd] dlib nbuf] {}

# =====================================================================
# H* -- the hierarchy
# =====================================================================
check "H1 the cells a cell instantiates, each once, itself left out" \
  [copyform::cell_children dlib buf_tb] {{dlib buf} {prim_pr res} {prim_pr code}}
check "H2 everything below the bench, depth first" \
  [copyform::hier dlib buf_tb {}] \
  {{dlib buf 1} {dlib bias 2} {prim_pr res 3} {prim_pr code 1}}
check "H3 an excluded library is left out, with everything below it" \
  [copyform::hier dlib buf_tb {prim_pr}] {{dlib buf 1} {dlib bias 2}}
check "H4 excluding the design library leaves nothing" [copyform::hier dlib buf_tb {dlib prim_pr}] {}
check "H5 two cells that instantiate each other end, each listed once" \
  [copyform::hier dlib loop_a {}] {{dlib loop_b 1}}
check "H6 a cell with no schematic has nothing below it" [copyform::hier prim_pr res {}] {}
check "H7 who instantiates a cell, across the design libraries" \
  [lsort [copyform::cell_users dlib buf]] [lsort {{dlib buf_tb} {dlib user1} {olib ouser} {olib ouser2}}]
check "H7b the states, in other cells, that simulate a cell" \
  [copyform::state_users dlib buf] {{dlib buf_tb ngspice_dut}}
check "H7c ... a cell's own state is not another cell's" [copyform::state_users dlib buf_tb] {}
check "H8 the default excludes hold the primitive library and never the source" \
  [list [expr {[lsearch [copyform::default_excludes dlib] prim_pr] >= 0}] \
        [expr {[lsearch [copyform::default_excludes dlib] dlib] >= 0}] \
        [expr {[lsearch [copyform::default_excludes prim_pr] prim_pr] >= 0}]] {1 0 0}

# =====================================================================
# N* -- names
# =====================================================================
check "N1 names a cell can have" \
  [lmap n {nbuf fast_buf3_tb a.b A-1 x+y} {copyform::name_why $n}] {{} {} {} {} {}}
check "N2 names it cannot: each is refused" \
  [lmap n [list {} {a b} a/b "a\tb" "a\{b" "a\}b" {a"b} {a$b} {a;b} {a[b} {a]b} "a\\b" .hid -opt] \
     {expr {[copyform::name_why $n] ne {}}}] {1 1 1 1 1 1 1 1 1 1 1 1 1 1}
check "N3 the reason names the name" \
  [string match "*'a b'*" [copyform::name_why {a b}]] 1

# the two naming habits, and nothing guessed beyond them
foreach {id ts td child exp} {
  N4a my_buf3_tb fast_buf3_tb my_buf3 fast_buf3
  N4b my_buf3_tb my_buf3_boost_tb my_buf3 my_buf3_boost
  N4c tb_buf tb_nbuf buf nbuf
  N4d my_buf3 fast_buf3 my_buf3_bias fast_buf3_bias
  N4e my_buf3 fast_buf3 res_hpo_x10 res_hpo_x10
  N4f my_buf3_tb my_buf3_tb2 my_buf3 my_buf3
  N4g my_buf3_tb other my_buf3 my_buf3
  N4h my_buf3_tb my_buf3_tb my_buf3 my_buf3
  N4i amp_tb amp2_tb a a
  N4j my_buf3_tb _tb my_buf3 my_buf3
} {
  check "$id copying $ts as $td proposes $exp for $child" [copyform::suggest $ts $td $child] $exp
}
check "N5 no name typed yet proposes nothing new" [copyform::suggest my_buf3_tb {} my_buf3] my_buf3

# =====================================================================
# R* -- the table
# =====================================================================
copyform::init dlib buf_tb
check "R1 the form opens flat: one row, the cell itself" $copyform::rows {{dlib buf_tb 0 buf_tb 1 0}}
check "R2 ... and excludes the primitive library" \
  [expr {[lsearch $copyform::st(excl) prim_pr] >= 0}] 1
set copyform::st(excl) {prim_pr}
set copyform::st(dstcell) ntb
set copyform::st(hier) 1
copyform::rows_build
check "R3 hierarchical, renamed with no naming habit: the cells below are listed and kept" \
  $copyform::rows {{dlib buf_tb 0 ntb 1 0} {dlib buf 1 buf 0 0} {dlib bias 2 bias 0 0}}
check "R4 ... their actions" \
  [lmap r $copyform::rows i {0 1 2} {copyform::row_action $r $i}] {copy keep keep}
set copyform::st(dstcell) nbuf_tb
copyform::rows_build
check "R5 the bench renamed after its device: the device is proposed and copied" \
  $copyform::rows {{dlib buf_tb 0 nbuf_tb 1 0} {dlib buf 1 nbuf 1 0} {dlib bias 2 bias 0 0}}
check "R6 ... actions" [lmap r $copyform::rows i {0 1 2} {copyform::row_action $r $i}] {copy copy keep}
check "R7 a row switched by hand" [list [copyform::row_toggle 2] [lindex $copyform::rows 2]] \
  {1 {dlib bias 2 bias 1 1}}
check "R8 ... is still kept while its name is the original's, in its own library" \
  [copyform::row_action [lindex $copyform::rows 2] 2] keep
check "R9 a row named by hand is copied under that name" \
  [list [copyform::row_set_name 2 nbias] [lindex $copyform::rows 2] \
        [copyform::row_action [lindex $copyform::rows 2] 2]] {1 {dlib bias 2 nbias 1 1} copy}
set copyform::st(dstcell) zzz
copyform::rows_build
check "R10 a hand-set row survives a rebuild; an untouched one follows the new name" \
  $copyform::rows {{dlib buf_tb 0 zzz 1 0} {dlib buf 1 buf 0 0} {dlib bias 2 nbias 1 1}}
check "R11 the first row has no copy/keep switch, and no row past the end has" \
  [list [copyform::row_toggle 0] [copyform::row_toggle 9] [copyform::row_set_name 9 x]] {0 0 0}
check "R12 naming the first row names the copy" \
  [list [copyform::row_set_name 0 nbuf_tb] $copyform::st(dstcell)] {1 nbuf_tb}
check "R13 a name that is already a cell of the destination: use it, copy nothing" \
  [list [copyform::row_set_name 1 user1] [copyform::row_action [lindex $copyform::rows 1] 1]] {1 use}
check "R14 an emptied name is a kept row" \
  [list [copyform::row_set_name 1 {}] [copyform::row_action [lindex $copyform::rows 1] 1]] {1 keep}

copyform::init dlib buf_tb
set copyform::st(excl) {prim_pr}
set copyform::st(dstcell) nbuf_tb
set copyform::st(hier) 1
copyform::rows_build
set plan [copyform::plan]
check "R15 the plan's cells are the rows with what happens to each" [dict get $plan cells] \
  {{dlib buf_tb dlib nbuf_tb copy} {dlib buf dlib nbuf copy} {dlib bias dlib bias keep}}
check "R16 ... and it still carries what the form showed" \
  [list [dict get $plan src] [dict get $plan dst] [dict get $plan hier] [dict get $plan updaterefs] \
        [dict get $plan viewmode] [dict get $plan exclude]] \
  {{dlib buf_tb} {dlib nbuf_tb} 1 copies all prim_pr}
check "R17 what the action log records: the rows that do something, nothing else" \
  [copyform::plan_min $plan] \
  {cells {{dlib buf_tb dlib nbuf_tb copy} {dlib buf dlib nbuf copy}} updaterefs copies}
check "R18 the plan in one line" [copyform::plan_summary $plan] \
  {2 cells to copy; 1 kept (still referenced where it is)}
check "R19 ... with a cell that is already there" \
  [copyform::plan_summary {cells {{a b a c copy} {a d a e use} {a f a f keep} {a g a g keep}}}] \
  {1 cell to copy; 1 already there (references go to it); 2 kept (still referenced where they are)}

# into another library the hierarchy goes along
copyform::init dlib buf_tb
set copyform::st(excl) {prim_pr}
set copyform::st(dstlib) zlib
set copyform::st(hier) 1
copyform::rows_build
check "R20 a copy into another library takes the cells below along, same names" \
  [dict get [copyform::plan] cells] \
  {{dlib buf_tb zlib buf_tb copy} {dlib buf zlib buf copy} {dlib bias zlib bias copy}}
set copyform::st(prefix) n_
set copyform::st(suffix) _v2
copyform::rows_build
check "R21 prefix and suffix name the cells below, not the cell itself" \
  [lmap r $copyform::rows {lindex $r 3}] {buf_tb n_buf_v2 n_bias_v2}
set copyform::st(hier) 0
copyform::rows_build
check "R22 unticking Copy Hierarchical leaves the one row" [llength $copyform::rows] 1

# =====================================================================
# W* -- refused plans
# =====================================================================
proc cells {args} { return [dict create cells $args] }
set before [lsort [glob -nocomplain -directory $D *]]
foreach {id plan pat} [list \
  W1 [dict create] {*names no cells*} \
  W2 [cells {dlib nosuch dlib x copy}] {no such cell: dlib/nosuch} \
  W3 [cells {dlib buf nolib x copy}] {no such library: nolib} \
  W4 [cells {dlib buf dlib {a b} copy}] {*'a b'*} \
  W5 [cells {dlib buf dlib bias copy}] {cell already exists: dlib/bias} \
  W6 [cells {dlib buf dlib buf copy}] {cell already exists: dlib/buf} \
  W7 [cells {dlib buf dlib n1 copy} {dlib bias dlib n1 copy}] {two cells would be copied to dlib/n1} \
  W8 [cells {dlib buf dlib n1 copy} {dlib buf dlib n2 copy}] {dlib/buf is listed twice} \
  W9 [cells {dlib buf dlib nosuch use}] {no such cell: dlib/nosuch} \
  W10 [cells {dlib buf dlib buf use}] {*same cell*} \
  W11 [cells {dlib buf dlib bias use}] {nothing to copy} \
  W12 [cells {dlib buf dlib n1 frob}] {unknown action 'frob'*} \
  W13 [cells {dlib buf dlib buf keep}] {nothing to copy} \
  W14 [dict create cells {{dlib buf dlib n1 copy}} viewmode filter viewfilter type:state] {no view of dlib/buf matches*} \
  W15 [dict create cells {{flib fl dlib n1 copy}} viewmode selected viewsel symbol] {*copy all views} \
] {
  check "$id refused: [string range $pat 0 44]" [string match $pat [copyform::plan_why $plan]] 1
  check "$id ... and running it raises the same reason" \
    [list [catch {copyform::execute $plan} e] [string match $pat $e]] {1 1}
}
check "W16 nothing was created by any of them" [lsort [glob -nocomplain -directory $D *]] $before
check "W17 a plan that can run is not refused" \
  [copyform::plan_why [cells {dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy} {dlib bias dlib bias keep}]] {}

# =====================================================================
# X* -- the copy: bench + device, the sub-block kept
# =====================================================================
build
set src_md5 {}
foreach f [lsort [glob $D/*/*/*]] { dict set src_md5 $f [md5of $f] }
set plan [cells {dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy} {dlib bias dlib bias keep}]
set rc [catch {copyform::execute $plan} rep]
check "X1 the copy runs" $rc 0
if {$rc} { puts "      $rep" ; set rep [dict create copied {} used {} kept {} sch {} states {} edited {} skipped {} left {}] }
check "X2 the report names what was copied and what was kept" \
  [list [dict get $rep copied] [dict get $rep used] [dict get $rep kept]] \
  {{{dlib buf_tb dlib ntb} {dlib buf dlib nbuf}} {} {{dlib bias}}}
check "X3 both copies are cells, every view and the includes folder with them" \
  [lsort [lmap f [glob -nocomplain $D/ntb/*/* $D/nbuf/*/*] {string range $f [string length $D/] end}]] \
  [lsort {ntb/includes/corner.lib ntb/includes/ns.spice ntb/ngspice_dut/ntb.state ntb/ngspice_other/ntb.state
          ntb/ngspice_state1/ntb.state ntb/schematic/ntb.sch nbuf/schematic/nbuf.sch nbuf/symbol/nbuf.sym}]
check "X4 no original file changed by one byte" \
  [lmap f [dict keys $src_md5] {expr {[md5of $f] eq [dict get $src_md5 $f]}}] \
  [lrepeat [dict size $src_md5] 1]

# --- the bench schematic ---
set old [split [slurp $D/buf_tb/schematic/buf_tb.sch] \n]
set new [split [slurp $D/ntb/schematic/ntb.sch] \n]
set changed {}
foreach a $old b $new { if {$a ne $b} { lappend changed $b } }
check "X5 the copied bench has the same number of lines" [llength $new] [llength $old]
check "X6 ... and exactly its instances of the device differ, each in its own spelling" $changed [list \
  [inst dlib/nbuf 200 name=x1] [inst dlib/nbuf.sym 400 name=x2] [inst dlib/nbuf.sch 600 name=x3] \
  [inst dlib/nbuf 800 name=x4] [inst $D/nbuf/symbol/nbuf.sym 1000 name=x5]]
check "X7 the text inside an attribute that only LOOKS like an instance is as it was" \
  [regexp -all {C \\\{dlib/buf\\\} is text} [slurp $D/ntb/schematic/ntb.sch]] 1
check "X8 the copied device still instantiates the kept sub-block, byte for byte" \
  [expr {[slurp $D/nbuf/schematic/nbuf.sch] eq [slurp $D/buf/schematic/buf.sch]}] 1
check "X9 the report lists the five instances, old and new" \
  [lindex [dict get $rep sch] 0 1] [list dlib/buf dlib/nbuf dlib/buf.sym dlib/nbuf.sym \
    dlib/buf.sch dlib/nbuf.sch dlib/buf/symbol/buf.sym dlib/nbuf $D/buf/symbol/buf.sym $D/nbuf/symbol/nbuf.sym]

# --- the bench's own state ---
set so [state_of $D/buf_tb/ngspice_state1/buf_tb.state]
set sn [state_of $D/ntb/ngspice_state1/ntb.state]
check "X10 the state's design is the copied bench" [dict get $sn design] {lib dlib cell ntb view schematic}
check "X11 a model file kept inside the bench is read from the copy, the shared one is not touched" \
  [dict get $sn models] \
  [list {file {$::CR_ROOT/models/all.lib} section tt} {file {$::CR_ROOT/dlib/ntb/includes/corner.lib} section ff}]
check "X12 an include inside the bench follows; one elsewhere and one that was never there do not" \
  [dict get $sn includes] \
  [list {file {$::CR_ROOT/dlib/ntb/includes/ns.spice}} {file /abs/elsewhere/x.spice} {file {$::CR_ROOT/dlib/buf_tb/includes/missing.spice}}]
set vn [dict get $sn viewer]
check "X13 the saved plot setup no longer selects the old bench's result file" [dict get $vn rawfile] {}
set tr [dict get [lindex [dict get $vn graphs] 0] traces]
check "X14 a trace pinned to the old bench's result file is pinned to the copy's" \
  [list [dict get [lindex $tr 1] rawfile] [dict get [lindex $tr 1] sim_type]] {/sim/ntb_ase.raw stb}
check "X15 ... a trace with no pin has none, a trace pinned to some other saved file keeps it" \
  [list [dict exists [lindex $tr 0] rawfile] [dict get [lindex $tr 2] rawfile]] \
  {0 /sim/saved/dlib/buf_tb/r1/other.raw}
check "X15a ... and so does one pinned to ANOTHER bench's result file, even a name of the same length" \
  [dict get [lindex $tr 3] rawfile] /sim/abc_tb_ase.raw
check "X16 ... and a pinned trace inside a tab follows too, relative path and all" \
  [dict get [lindex [dict get [lindex [dict get [dict get [lindex [dict get $vn tabs] 0] layout] graphs] 0] traces] 0] rawfile] \
  ntb_ase.raw
set same {}
dict for {k v} $so { if {$k ni {design models includes viewer}} { lappend same [expr {[dict get $sn $k] eq $v}] } }
check "X17 every other key of the state is what it was" $same [lrepeat [llength $same] 1]
set lo [split [slurp $D/buf_tb/ngspice_state1/buf_tb.state] \n]
set ln [split [slurp $D/ntb/ngspice_state1/ntb.state] \n]
set nd 0
foreach a $lo b $ln { if {$a ne $b} { incr nd } }
check "X18 ... line for line: four lines differ, the rest are the same bytes" [list [llength $ln] $nd] [list [llength $lo] 4]
check "X19 everything else in the plot setup (markers, colours, tab names) is unchanged" \
  [list [dict get [lindex [dict get $vn graphs] 0] markers] [dict get $vn activetab] \
        [dict get [lindex [dict get $vn tabs] 0] name]] {{2 0 0 154 5.5 -21.2} 1 {Tab 1}}

# the rule behind X14-X16, one path at a time
foreach {id path old new exp} {
  X19a /sim/buf_tb_ase.raw buf_tb ntb /sim/ntb_ase.raw
  X19b buf_tb_ase.raw      buf_tb ntb ntb_ase.raw
  X19c /sim/buf_tb.raw     buf_tb ntb /sim/ntb.raw
  X19d /sim/buf_tb_ase.raw buf_tb buf_tb {}
  X19e /sim/buf_tb2_ase.raw buf_tb ntb {}
  X19f /sim/abc_tb_ase.raw buf_tb ntb {}
  X19g /sim/buf_tb_ase     buf_tb ntb {}
  X19h /sim/buf_tb/x.raw   buf_tb ntb {}
} {
  check "$id the result file $path of $old, for $new: [expr {$exp eq {} ? {left} : $exp}]" \
    [copyform::raw_rename $path $old $new] $exp
}

# --- the other two states ---
check "X20 a state the user pointed at a cell that was not copied is left byte for byte" \
  [expr {[slurp $D/ntb/ngspice_other/ntb.state] eq [slurp $D/buf_tb/ngspice_other/buf_tb.state]}] 1
set sd2 [state_of $D/ntb/ngspice_dut/ntb.state]
check "X21 a state whose design is the copied DEVICE now simulates the copy of the device" \
  [list [dict get $sd2 design] [dict get [dict get $sd2 viewer] rawfile]] {{lib dlib cell nbuf view schematic} {}}
check "X22 the report names the two states that changed, with what changed" \
  [lmap e [dict get $rep states] {list [file tail [file dirname [lindex $e 0]]] [lindex $e 1]}] \
  [list [list ngspice_dut [list {design is now dlib/nbuf} {saved plot setup now follows the copy's own results}]] \
        [list ngspice_state1 [list {design is now dlib/ntb} {1 model file now read from the copy} \
           {1 include file now read from the copy} {saved plot setup now follows the copy's own results}]]]

# --- what is left ---
set left [lmap e [dict get $rep left] {list [copyform::short_path [lindex $e 0]] [lindex $e 2]}]
check "X23 what still names an original is reported: comments, a title, the include that was never there, the other saved result" \
  [lsort -unique $left] [lsort -unique {
    {ntb/includes/ns.spice buf_tb} {nbuf/schematic/nbuf.sch buf} {ntb/schematic/ntb.sch buf_tb}
    {ntb/schematic/ntb.sch buf} {ntb/ngspice_state1/ntb.state buf_tb}}]
check "X24 ... each with its line number and an excerpt that holds the name" \
  [lsort -unique [lmap e [dict get $rep left] {expr {[string is integer -strict [lindex $e 1]] &&
     [string first [lindex $e 2] [lindex $e 3]] >= 0}}]] 1
check "X25 no re-pointed instance is among them" \
  [lsearch -glob [lmap e [dict get $rep left] {lindex $e 3}] "C \{dlib/buf*"] -1
set t [copyform::report_text $rep]
check "X26 the one-line account" [dict get $t summary] \
  "copied 2 cells, 5 instances re-pointed, 2 states re-pointed, [llength [dict get $rep left]] places still name an original (see the CIW)"
set kinds {}
foreach l [dict get $t lines] {
  switch -glob -- $l {
    "copy: * -> *"                { lappend kinds copy }
    "copy: *: instance of * is now *" { lappend kinds inst }
    "copy: still names *"         { lappend kinds left }
    "copy: * ngspice_*: *"        { lappend kinds state }
    default                       { lappend kinds other }
  }
}
check "X27 the long account: 2 copies, 5 instances, 2 states, then the leftovers" \
  $kinds [concat {copy copy} [lrepeat 5 inst] {state state} [lrepeat [llength [dict get $rep left]] left]]
check "X28 no temporary file is left beside anything" [glob -nocomplain $D/*/*/*.cp*] {}

# =====================================================================
# U* -- point at a cell that is already there
# =====================================================================
# (the copies of band X are still there: nbuf exists)
set plan [cells {dlib buf_tb dlib ntb2 copy} {dlib buf dlib nbuf use}]
set m [md5of $D/nbuf/schematic/nbuf.sch]
set rc [catch {copyform::execute $plan} rep]
check "U1 the bench copied after its new device exists: one cell copied, one used" \
  [list $rc [q {dict get $rep copied}] [q {dict get $rep used}]] \
  {0 {{dlib buf_tb dlib ntb2}} {{dlib buf dlib nbuf}}}
check "U2 ... the copy instantiates the existing cell" \
  [regexp -all -line {^C \{dlib/nbuf(\.sym|\.sch)?\}} [slurp $D/ntb2/schematic/ntb2.sch]] 4
check "U3 ... which was not written" [md5of $D/nbuf/schematic/nbuf.sch] $m
check "U4 ... and the account says so" \
  [lsearch -glob [dict get [copyform::report_text $rep] lines] "*dlib/buf now go to dlib/nbuf, which was already there"] 1

# =====================================================================
# O* -- the three scopes, and an open file
# =====================================================================
build
set rep [q {copyform::execute [dict create cells {{dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy}} updaterefs none]}]
check "O1 None: the copied bench still instantiates the ORIGINAL device" \
  [list [regexp -all -line {^C \{dlib/buf(\.sym|\.sch)?\}} [slurp $D/ntb/schematic/ntb.sch]] [q {dict get $rep sch}]] {3 {}}
check "O2 ... but its own state follows its own cell" \
  [dict get [state_of $D/ntb/ngspice_state1/ntb.state] design] {lib dlib cell ntb view schematic}
check "O3 ... and a state that names the device keeps naming the original" \
  [dict get [state_of $D/ntb/ngspice_dut/ntb.state] design] {lib dlib cell buf view schematic}
check "O4 ... what is reported as left is then only the copy's own old name" \
  [lsort -unique [lmap e [q {dict get $rep left}] {lindex $e 2}]] {buf buf_tb}

build
set mu [md5of $D/user1/schematic/user1.sch]
set mo [md5of $work/olib/ouser/schematic/ouser.sch]
set rep [q {copyform::execute [dict create cells {{dlib buf olib buf copy}} updaterefs copies]}]
check "O5 New copies only: a cell already in the destination library is not touched" \
  [list [md5of $work/olib/ouser/schematic/ouser.sch] [q {dict get $rep edited}]] [list $mo {}]

build
check "O6 Entire destination library: the cells already there that use the original" \
  [lsort [copyform::library_referrers [dict create cells {{dlib buf olib buf copy}}]]] {{olib ouser} {olib ouser2}}
# one of them is open in the editor
xschem load [file join $work olib ouser2 schematic ouser2.sch]
check "O7 a file loaded in a window is known to be open" \
  [expr {[lsearch -exact [copyform::open_files] [file normalize [file join $work olib ouser2 schematic ouser2.sch]]] >= 0}] 1
set rep [q {copyform::execute [dict create cells {{dlib buf olib buf copy}} updaterefs library]}]
check "O8 ... the closed one is re-pointed to the copy" \
  [list [regexp -all -line {^C \{olib/buf\}} [slurp $work/olib/ouser/schematic/ouser.sch]] [q {dict get $rep edited}]] \
  {1 {{olib ouser}}}
check "O9 ... the open one is left alone and named" \
  [list [md5of $work/olib/ouser2/schematic/ouser2.sch] [q {dict get $rep skipped}]] \
  [list $mo [list [list [file join $work olib ouser2 schematic ouser2.sch] open]]]
check "O10 ... and a cell of the SOURCE library that uses the original is not touched" \
  [md5of $D/user1/schematic/user1.sch] $mu
check "O11 the account names the open file" \
  [lsearch -glob [dict get [copyform::report_text $rep] lines] "*ouser2/schematic/ouser2.sch is open in a window*"] 2
check "O11a ... and the one-line account counts it" \
  [string match "*, 1 file left alone (see the CIW)" [dict get [copyform::report_text $rep] summary]] 1
xschem clear force
build
# a read-only file is somebody else's, or not checked out: it is not edited either
file attributes [file join $work olib ouser2 schematic ouser2.sch] -permissions 0444
set rep [q {copyform::execute [dict create cells {{dlib buf olib buf copy}} updaterefs library]}]
check "O11b a read-only user of the original is left alone and named, the writable one is re-pointed" \
  [list [md5of $work/olib/ouser2/schematic/ouser2.sch] [q {dict get $rep skipped}] [q {dict get $rep edited}]] \
  [list $mo [list [list [file join $work olib ouser2 schematic ouser2.sch] readonly]] {{olib ouser}}]
check "O11c ... with its own sentence" \
  [lsearch -glob [dict get [copyform::report_text $rep] lines] "*ouser2/schematic/ouser2.sch is read-only and was left as it is"] 2
file attributes [file join $work olib ouser2 schematic ouser2.sch] -permissions 0644
build
set rep [q {copyform::execute [dict create cells {{dlib buf dlib nbuf copy}} updaterefs library]}]
check "O12 inside one library the same scope re-points every other user of the original" \
  [lsort [q {dict get $rep edited}]] {{dlib buf_tb} {dlib user1}}
check "O13 ... and not the other design library" [md5of $work/olib/ouser/schematic/ouser.sch] $mo
build
set mtb [md5of $D/buf_tb/schematic/buf_tb.sch]
set rep [q {copyform::execute [dict create cells {{dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy}} updaterefs library]}]
check "O14 ... a bench that is itself being copied is never one of them: the ORIGINAL bench goes on testing the old cell" \
  [list [lsort [q {dict get $rep edited}]] [md5of $D/buf_tb/schematic/buf_tb.sch]] [list {{dlib user1}} $mtb]

# =====================================================================
# P* -- a choice of views
# =====================================================================
build
set rep [q {copyform::execute [dict create cells {{dlib buf_tb dlib ntb copy}} viewmode filter viewfilter {type:schematic ngspice_state1}]}]
check "P1 only the chosen views are copied" \
  [lsort [lmap d [glob -nocomplain -type d $D/ntb/*] {file tail $d}]] {ngspice_state1 schematic}
check "P2 ... the state follows its cell" \
  [dict get [state_of $D/ntb/ngspice_state1/ntb.state] design] {lib dlib cell ntb view schematic}
check "P3 ... and an include that was NOT copied is left pointing where it did, and reported" \
  [list [lindex [dict get [state_of $D/ntb/ngspice_state1/ntb.state] includes] 0] \
        [expr {[lsearch -glob [lmap e [q {dict get $rep left}] {lindex $e 3}] "*buf_tb/includes/ns.spice*"] >= 0}]] \
  [list {file {$::CR_ROOT/dlib/buf_tb/includes/ns.spice}} 1]
build
set rep [q {copyform::execute [dict create cells {{dlib buf dlib nbuf copy}} viewmode selected viewsel symbol]}]
check "P4 a picked view" [lsort [lmap d [glob -nocomplain -type d $D/nbuf/*] {file tail $d}]] {symbol}

# =====================================================================
# B* -- a failure half way puts everything back
# =====================================================================
build
spit $D/buf_tb/ngspice_bad/buf_tb.state "version 1 simulator\n"
set before [lsort [glob -nocomplain -directory $D *]]
set rc [catch {copyform::execute [cells {dlib buf dlib nbuf copy} {dlib buf_tb dlib ntb copy}]} e]
check "B1 a state file that cannot be read stops the copy, and says which" \
  [list $rc [string match "nothing was copied: *ntb.state is not a state file*" $e]] {1 1}
check "B2 ... no copy is left in the library, the one made before the failure included" \
  [lsort [glob -nocomplain -directory $D *]] $before
check "B3 ... they are in the library's trash, not deleted" \
  [lsort [lmap d [glob -nocomplain -directory [file join $D .xschem_trash] *] {file tail $d}]] {nbuf ntb}
file delete -force [file join $D .xschem_trash]

build
# a second user whose file cannot be replaced: its view directory is read-only
set ro [file join $work olib ouser2 schematic]
file attributes $ro -permissions 0555
set f1 [file join $work olib ouser schematic ouser.sch]
set m1 [md5of $f1]
if {[file writable $ro]} {
  puts "SKIPPED: B4-B6 (this user can write a read-only directory)"
} else {
  set rc [catch {copyform::execute [dict create cells {{dlib buf olib buf copy}} updaterefs library]} e]
  check "B4 a user of the original that cannot be written stops the copy" \
    [list $rc [string match "nothing was copied: *" $e]] {1 1}
  check "B5 ... the user that HAD been re-pointed is put back, byte for byte" [md5of $f1] $m1
  check "B6 ... and the copy is gone" [library_cell_layout olib buf] {}
}
file attributes $ro -permissions 0755

# =====================================================================
# F* -- flat libraries, another library, bytes that are not ASCII
# =====================================================================
build
set rep [q {copyform::execute [cells {flib fl_tb flib n_tb copy} {flib fl flib nfl copy}]}]
check "F1 loose-file cells are copied as loose files" \
  [lmap f {n_tb.sch nfl.sch nfl.sym} {file isfile [file join $work flib $f]}] {1 1 1}
check "F2 ... a search-path reference and a library/cell one both go to the copy" \
  [regexp -all -inline -line {^C \{[^\}]*\}} [slurp $work/flib/n_tb.sch]] {{C {flib/nfl}} {C {flib/nfl}}}

build
set rep [q {copyform::execute [cells {dlib buf_tb olib buf_tb copy} {dlib buf olib buf copy}]}]
check "F3 into a library beside this one: instances name the new library" \
  [regexp -all -line {^C \{olib/buf(\.sym|\.sch)?\}} [slurp $work/olib/buf_tb/schematic/buf_tb.sch]] 4
check "F4 ... the state's design too, and its include keeps the variable it was written with" \
  [list [dict get [state_of $work/olib/buf_tb/ngspice_state1/buf_tb.state] design] \
        [lindex [dict get [state_of $work/olib/buf_tb/ngspice_state1/buf_tb.state] includes] 0]] \
  [list {lib olib cell buf_tb view schematic} {file {$::CR_ROOT/olib/buf_tb/includes/ns.spice}}]
check "F4a ... the account of that state lists what changed in it" \
  [lindex [lsearch -inline -index 0 [q {dict get $rep states}] "*ngspice_state1*"] 1] \
  {{design is now olib/buf_tb} {1 model file now read from the copy} {1 include file now read from the copy} {saved plot setup now follows the copy's own results}}
check "F5 ... a result file named after a cell that kept its name is left as it is" \
  [dict get [lindex [dict get [lindex [dict get [dict get [state_of $work/olib/buf_tb/ngspice_state1/buf_tb.state] viewer] graphs] 0] traces] 1] rawfile] \
  /sim/buf_tb_ase.raw
build
set rep [q {copyform::execute [cells {dlib buf_tb zlib ztb copy}]}]
check "F6 into a library somewhere else: the include becomes the copy's full path" \
  [lindex [dict get [state_of $work/far/zlib/ztb/ngspice_state1/ztb.state] includes] 0] \
  [list file [file join $work far zlib ztb includes ns.spice]]

# bytes: CRLF line ends and a Latin-1 byte that is not valid UTF-8
build
set crlf "[string map [list \n \r\n] [sch [list "T \{caf\xe9\} 0 0 0 0 0.3 0.3 \{\}" [inst dlib/buf 0 name=x1]]]]"
spit $D/odd/schematic/odd.sch $crlf
set rep [q {copyform::execute [cells {dlib odd dlib nodd copy} {dlib buf dlib nbuf copy}]}]
check "F7 a file with CRLF line ends and a stray Latin-1 byte: one reference changes, nothing else" \
  [expr {[slurp $D/nodd/schematic/nodd.sch] eq [string map [list dlib/buf dlib/nbuf] $crlf]}] 1
# a name that is not ASCII, in a schematic and in a state
build
set uname "büf"
file rename $D/buf $D/$uname
foreach v {schematic symbol} e {.sch .sym} { file rename $D/$uname/$v/buf$e $D/$uname/$v/$uname$e }
spit $D/utb/schematic/utb.sch [encoding convertto utf-8 [sch [list [inst dlib/$uname 0 name=x1]]]]
spit $D/utb/ngspice_state1/utb.state [encoding convertto utf-8 [state_text [list version 1 design [list lib dlib cell $uname view schematic]]]]
set rep [q {copyform::execute [cells [list dlib utb dlib utb2 copy] [list dlib $uname dlib "nüf" copy]]}]
check "F8 a cell name that is not ASCII is found and re-pointed, in the schematic and in the state" \
  [list [string first [encoding convertto utf-8 "C \{dlib/nüf\}"] [slurp $D/utb2/schematic/utb2.sch]] \
        [encoding convertfrom utf-8 [dict get [dict get [state_of $D/utb2/ngspice_state1/utb2.state] design] cell]]] \
  [list [string first "C \{dlib/" [slurp $D/utb2/schematic/utb2.sch]] "nüf"]

# a state that is not in the saver's line form is left alone when nothing applies
build
set odd "version 1   simulator ngspice\ndesign {lib dlib   cell bias view schematic}\n"
spit $D/buf_tb/ngspice_hand/buf_tb.state $odd
set rep [q {copyform::execute [cells {dlib buf_tb dlib ntb copy}]}]
check "F9 a hand-formatted state nothing applies to is copied byte for byte" \
  [slurp $D/ntb/ngspice_hand/ntb.state] $odd

# =====================================================================
# L* -- the Library Manager's commands
# =====================================================================
build
set libmgr::last_status {}
check "L1 copying one cell succeeds" [libmgr::do_copy_cell dlib buf_tb dlib ntb] 1
check "L2 ... and its states simulate the copy" \
  [dict get [state_of $D/ntb/ngspice_state1/ntb.state] design] {lib dlib cell ntb view schematic}
check "L3 ... the status line says what was copied and that the states were re-pointed" \
  [list [string match "copied dlib/buf_tb -> dlib/ntb, 1 state re-pointed*" $libmgr::last_status] \
        [string match "*instance*" $libmgr::last_status]] {1 0}
check "L4 ... the bench still instantiates the original device (it was not copied)" \
  [regexp -all -line {^C \{dlib/buf(\.sym|\.sch)?\}} [slurp $D/ntb/schematic/ntb.sch]] 3
check "L5 a copy onto an existing cell is a soft failure, with the reason" \
  [list [libmgr::do_copy_cell dlib buf dlib bias] $libmgr::last_status] \
  {0 {copy failed: cell already exists: dlib/bias}}

build
set plan [dict create cells {{dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy} {dlib bias dlib bias keep}} updaterefs copies hier 1]
# What the commands hand to the action log is recorded here, whether or not a
# log file is open in this session (under --pipe there is none).
set ::logged {}
rename ::xschem ::xschem_real
proc ::xschem {args} {
  if {[lindex $args 0] eq "log_action"} { lappend ::logged [lindex $args 1] }
  return [uplevel 1 [list ::xschem_real {*}$args]]
}
check "L6 running a plan succeeds" [libmgr::do_copy_plan $plan] 1
check "L7 ... the status line is the one-line account" \
  [string match "copied 2 cells, 5 instances re-pointed, 2 states re-pointed, *" $libmgr::last_status] 1
check "L8 ... and the report is kept" [dict get $libmgr::last_copy_report copied] \
  {{dlib buf_tb dlib ntb} {dlib buf dlib nbuf}}
check "L9 a plan that cannot run is a soft failure and leaves the reason" \
  [list [libmgr::do_copy_plan $plan] $libmgr::last_status] {0 {copy failed: cell already exists: dlib/ntb}}
check "L10 the successful plan logged exactly one command, the refused one none" [llength $::logged] 1
set line [lindex $::logged 0]
check "L11 ... a complete command that names only the rows that do something" \
  [list [info complete $line] [q {lindex $line 0}] [q {lindex $line 1}]] \
  [list 1 libmgr::do_copy_plan {cells {{dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy}} updaterefs copies}]
set want [slurp $D/ntb/ngspice_state1/ntb.state]
set wsch [slurp $D/ntb/schematic/ntb.sch]
build
check "L12 ... replayed on the library as it was, it makes the same copy" \
  [list [q {uplevel #0 $line}] [expr {[slurp $D/ntb/ngspice_state1/ntb.state] eq $want}] \
        [expr {[slurp $D/ntb/schematic/ntb.sch] eq $wsch}]] {1 1 1}
set ::logged {}
build
libmgr::do_copy_cell dlib buf_tb dlib ntb
libmgr::do_rename_cell dlib ntb dlib ntb9
check "L12b a one-cell copy and a rename still log the commands they always did" $::logged \
  {{libmgr::do_copy_cell dlib buf_tb dlib ntb} {libmgr::do_rename_cell dlib ntb dlib ntb9}}
rename ::xschem {}
rename ::xschem_real ::xschem

# rename
build
check "L13 renaming a cell succeeds" [libmgr::do_rename_cell dlib buf_tb dlib rtb] 1
check "L14 ... its own state names the new cell, and reads its include from there" \
  [list [dict get [state_of $D/rtb/ngspice_state1/rtb.state] design] \
        [lindex [dict get [state_of $D/rtb/ngspice_state1/rtb.state] includes] 0]] \
  [list {lib dlib cell rtb view schematic} {file {$::CR_ROOT/dlib/rtb/includes/ns.spice}}]
check "L15 ... a state pointed at another cell is as it was" \
  [dict get [state_of $D/rtb/ngspice_other/rtb.state] design] {lib dlib cell bias view schematic}
check "L16 ... the status line says so" $libmgr::last_status \
  {renamed dlib/buf_tb -> dlib/rtb, 1 state now simulates it}
check "L17 renaming a cell others instantiate says how many still name the old one" \
  [list [libmgr::do_rename_cell dlib buf dlib rbuf] $libmgr::last_status] \
  {1 {renamed dlib/buf -> dlib/rbuf; 4 cells still instantiate dlib/buf, 1 state still simulates it (see the CIW)}}
check "L18 ... and does not edit them" \
  [regexp -all -line {^C \{dlib/buf\}} [slurp $D/user1/schematic/user1.sch]] 1
check "L19 a rename onto an existing cell is a soft failure" \
  [list [libmgr::do_rename_cell dlib bias dlib user1] [string match "rename failed: *" $libmgr::last_status]] {0 1}

# one view
build
check "L21 a state view copied into another cell simulates the cell it now belongs to" \
  [list [libmgr::do_copy_view dlib buf_tb ngspice_state1 dlib user1 ngspice_state1] \
        [dict get [state_of $D/user1/ngspice_state1/user1.state] design] $libmgr::last_status] \
  [list 1 {lib dlib cell user1 view schematic} \
        {copied view dlib/buf_tb/ngspice_state1 -> dlib/user1/ngspice_state1, it now simulates dlib/user1}]
check "L22 ... an include the new cell does not have is still read from where it was" \
  [lindex [dict get [state_of $D/user1/ngspice_state1/user1.state] includes] 0] \
  {file {$::CR_ROOT/dlib/buf_tb/includes/ns.spice}}
check "L23 a state view copied inside its own cell is byte for byte the state it was" \
  [list [libmgr::do_copy_view dlib buf_tb ngspice_state1 dlib buf_tb ngspice_state2] \
        [expr {[slurp $D/buf_tb/ngspice_state2/buf_tb.state] eq [slurp $D/buf_tb/ngspice_state1/buf_tb.state]}] \
        $libmgr::last_status] \
  {1 1 {copied view dlib/buf_tb/ngspice_state1 -> dlib/buf_tb/ngspice_state2}}
check "L24 a schematic view copied into another cell is a plain copy" \
  [list [libmgr::do_copy_view dlib buf schematic dlib user1 sch2] \
        [expr {[slurp $D/user1/sch2/user1.sch] eq [slurp $D/buf/schematic/buf.sch]}]] {1 1}

# the account goes to the CIW, line by line
build
set ::ciw_lines {}
if {[llength [info commands ::ciw_echo]]} { rename ::ciw_echo ::ciw_echo_real }
proc ::ciw_echo {line {tag {}}} { lappend ::ciw_lines $line }
libmgr::do_copy_plan [dict create cells {{dlib buf_tb dlib ntb copy} {dlib buf dlib nbuf copy}}]
check "L25 a copy's whole account is written to the CIW, one line each" $::ciw_lines \
  [dict get [copyform::report_text $libmgr::last_copy_report] lines]
check "L25a ... it starts with the copies and names each re-pointed instance" \
  [list [lindex $::ciw_lines 0] [lindex $::ciw_lines 2]] \
  {{copy: dlib/buf_tb -> dlib/ntb} {copy: ntb.sch: instance of dlib/buf is now dlib/nbuf}}
set ::ciw_lines {}
libmgr::do_rename_cell dlib buf dlib rbuf
check "L26 a rename names, in the CIW, every cell that still refers to the old name (the copies no longer do)" \
  [lsort $::ciw_lines] [lsort {
    {rename: dlib/buf_tb still instantiates dlib/buf} {rename: dlib/user1 still instantiates dlib/buf}
    {rename: olib/ouser still instantiates dlib/buf} {rename: olib/ouser2 still instantiates dlib/buf}
    {rename: dlib/buf_tb ngspice_dut still simulates dlib/buf}}]
rename ::ciw_echo {}
if {[llength [info commands ::ciw_echo_real]]} { rename ::ciw_echo_real ::ciw_echo }

# the trap this file's namespace sets for itself
check "L20 reading a file inside the copyform namespace does not open the form" \
  [list [q {copyform::slurp $D/bias/symbol/bias.sym}] [llength [info commands ::copyform::open]]] \
  [list [slurp $D/bias/symbol/bias.sym] 1]

set ::pathlist $keep_pathlist

# --- verdict ---
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail != 0}]
