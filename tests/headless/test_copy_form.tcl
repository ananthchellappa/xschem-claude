# Copy form (src/copy_form.tcl, doc/claude/specs/copy_hierarchical.md): the
# widgets. The engine and the form's decisions are fenced without a display in
# test_copy_retarget.tcl; this suite presses the form itself.
#
#   CF0-CF13   the view type model, the view filter, the default exclude list
#              and the plan of a form nobody has touched.
#   CF14-CF23  the form as built: the hierarchical section is hidden until
#              "Copy Hierarchical" is ticked; OK returns the plan, Cancel nothing.
#   T*         the table of cells: what it lists, a name typed in place, a row
#              switched between Copy and Keep by a click, the cells "Entire
#              destination library" would edit, Rescan.
#   A*         OK: a plan that cannot run is refused on the form with the reason.
#   E*         end to end: right-click > Copy on a bench in the Library Manager,
#              through the real form, to the files on disk.
#
# Needs a display. Run:  tests/headless/run_suites.sh test_copy_form
# Registered in dcases in tests/run_regression.tcl. Prints "OVERALL: ok".

# Self-skip in the full_audit banner shape so a display-less box scores SKIP,
# not FAIL.
if {[catch {winfo screenwidth .}]} {
  puts "RESULT: SKIP (no X)"; puts "OVERALL: ok"; exit 0
}
source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail : FAIL"; incr fail }
  flush stdout
}
# the same, comparing two values and printing both on a miss
proc eqc {name got exp} { check $name [expr {$got eq $exp}] "(=> {$got}, expected {$exp})" }
# Evaluate in the caller's frame; a raise becomes a legible value, so one thing
# that is not there costs one row and not the rest of the suite.
proc q {script} {
  if {[catch {uplevel 1 $script} r]} { return "RAISED($r)" }
  return $r
}

# --- fixture library ----------------------------------------------------------
# cflib/op: one cell, four views, three distinct types (the view model rows).
# cflib/amp_tb -> cflib/amp -> cflib/sub, plus cf_pr/res: the table rows.
# cflib/user instantiates amp: what "Entire destination library" would edit.
# test_scratch owns the directory's lifetime (issue 0148): it is removed on
# every exit path, including an early failure.
set tmp [test_scratch copyform]
proc put {path text} {
  file mkdir [file dirname $path]
  set fh [open $path w]; puts -nonewline $fh $text; close $fh
}
proc inst {ref x {attrs {name=x1}}} { return "C \{$ref\} $x 0 0 0 \{$attrs\}" }
set HEAD [join [list "v \{xschem version=3.4.8RC file_version=1.3\}" "G \{\}" "K \{\}" "V \{\}" "S \{\}" "F \{\}" "E \{\}"] \n]
proc sch {lines} { return "$::HEAD\n[join $lines \n]\n" }
foreach {view file} {schematic op.sch symbol op.sym ngspice_state1 op.state spectre_state2 op.state} {
  put [file join $tmp cflib op $view $file] {}
}
put [file join $tmp cflib sub schematic sub.sch] [sch [list [inst cf_pr/res 0 name=R1]]]
put [file join $tmp cflib sub symbol sub.sym] [sch {}]
put [file join $tmp cflib amp schematic amp.sch] [sch [list [inst cflib/sub 0 name=x1] [inst cf_pr/res 200 name=R1]]]
put [file join $tmp cflib amp symbol amp.sym] [sch {}]
put [file join $tmp cflib amp_tb schematic amp_tb.sch] [sch [list [inst cflib/amp 0 name=x1] [inst cf_pr/res 200 name=R1]]]
put [file join $tmp cflib amp_tb ngspice_state1 amp_tb.state] \
  "version 1\ndesign {lib cflib cell amp_tb view schematic}\nviewer {}\n"
put [file join $tmp cflib user schematic user.sch] [sch [list [inst cflib/amp 0 name=x1]]]
foreach lib {devices cf_pr cf_stdcells cf_tests} {
  put [file join $tmp $lib res symbol res.sym] {}
}
set fh [open [file join $tmp library.defs] w]
puts $fh "DEFINE cflib cflib"
foreach lib {devices cf_pr cf_stdcells cf_tests} { puts $fh "DEFINE $lib $lib" }
close $fh
set ::XSCHEM_LIBRARY_DEFS [file join $tmp library.defs]

library_manager
update idletasks
check "CF0 fixture library registered" [expr {[lsearch [libmgr::lib_names] cflib] >= 0}] \
  "(=> [libmgr::lib_names])"

# --- view type: derived from the datafile extension, not the view name ------
check "CF1 .sch view is type schematic" [expr {[copyform::view_type cflib op schematic] eq "schematic"}] {}
check "CF2 .sym view is type symbol"    [expr {[copyform::view_type cflib op symbol] eq "symbol"}] {}
check "CF3 ngspice_state1 is type state" [expr {[copyform::view_type cflib op ngspice_state1] eq "state"}] \
  "(=> [copyform::view_type cflib op ngspice_state1])"
check "CF4 state subtype keeps the simulator" \
  [expr {[copyform::view_subtype ngspice_state1 state] eq "ngspice_state" &&
         [copyform::view_subtype spectre_state2 state] eq "spectre_state"}] {}
check "CF5 non-state has no subtype" [expr {[copyform::view_subtype symbol symbol] eq {}}] {}

# --- filter expression ------------------------------------------------------
check "CF6 parse splits names from type:" \
  [expr {[copyform::parse_view_spec "type:symbol, sch*"] eq {names sch* types symbol}}] \
  "(=> [copyform::parse_view_spec {type:symbol, sch*}])"
check "CF7 type:symbol matches only the symbol view" \
  [expr {[copyform::match_views cflib op filter {} "type:symbol"] eq {symbol}}] {}
check "CF8 type:state matches every simulator's states" \
  [expr {[copyform::match_views cflib op filter {} "type:state"] eq {ngspice_state1 spectre_state2}}] \
  "(=> [copyform::match_views cflib op filter {} {type:state}])"
check "CF9 type:ngspice_state narrows to one simulator" \
  [expr {[copyform::match_views cflib op filter {} "type:ngspice_state"] eq {ngspice_state1}}] {}
check "CF10 bare token is a view-name glob" \
  [expr {[copyform::match_views cflib op filter {} "*_state1 symbol"] eq {ngspice_state1 symbol}}] {}
check "CF11 selected mode drops views that do not exist" \
  [expr {[copyform::match_views cflib op selected {symbol nosuch} {}] eq {symbol}}] {}

# --- default exclude list: device/primitive libraries stay referenced --------
copyform::init cflib op
set _ex [copyform::default_excludes cflib]
check "CF12 primitive/stdcell libraries excluded by default" \
  [expr {[lsearch $_ex devices] >= 0 && [lsearch $_ex cf_pr] >= 0 &&
         [lsearch $_ex cf_stdcells] >= 0}] "(=> $_ex)"
check "CF12a design libraries are NOT excluded" [expr {[lsearch $_ex cf_tests] < 0}] {}
check "CF12b the source library is never excluded" \
  [expr {[lsearch $_ex cflib] < 0 && [lsearch [copyform::default_excludes devices] devices] < 0}] \
  "(=> [copyform::default_excludes devices])"
check "CF13 plan defaults to all views, flat" \
  [expr {[dict get [copyform::plan] hier] == 0 &&
         [dict get [copyform::plan] views] eq {ngspice_state1 schematic spectre_state2 symbol}}] {}

# --- the widget: hierarchical section is revealed by the checkbox -----------
copyform::build
update
check "CF14 form built" [winfo exists .libmgr.cp] {}
check "CF15 hierarchy section hidden while unchecked" [expr {[llength [grid info .libmgr.cp.h]] == 0}] {}
check "CF16 view list shows name and type" \
  [expr {[lindex [.libmgr.cp.vw.lb get 0] 0] eq "ngspice_state1" &&
         [string match "*(state)*" [.libmgr.cp.vw.lb get 0]]}] "(=> [.libmgr.cp.vw.lb get 0])"
check "CF17 view widgets disabled in All-views mode" \
  [expr {[.libmgr.cp.vw.lb cget -state] eq "disabled" && [.libmgr.cp.vw.flt cget -state] eq "disabled"}] {}
eqc "CF17a flat, the status bar says so" [.libmgr.cp.status cget -text] {flat copy: this cell only}

set copyform::st(hier) 1
copyform::sync_hier
update
check "CF18 hierarchy section revealed when checked" [expr {[llength [grid info .libmgr.cp.h]] > 0}] {}
check "CF19 exclude list pre-selects the defaults" [expr {[llength [.libmgr.cp.h.excl curselection]] > 0}] {}
check "CF20 cell table has the top cell row" \
  [expr {[llength [.libmgr.cp.h.tvf.tv children {}]] >= 1 &&
         [string trim [.libmgr.cp.h.tvf.tv set [lindex [.libmgr.cp.h.tvf.tv children {}] 0] cell]] eq "op"}] {}

# update-references scope: Cadence's three-way, default "new copies only"
check "CF20a three update-reference choices exist" \
  [expr {[winfo exists .libmgr.cp.h.ur.none] && [winfo exists .libmgr.cp.h.ur.copies] &&
         [winfo exists .libmgr.cp.h.ur.lib]}] {}
check "CF20b default scope is copies-only" [expr {$copyform::st(updaterefs) eq "copies"}] \
  "(=> $copyform::st(updaterefs))"
.libmgr.cp.h.ur.none invoke
check "CF20c None keeps references on the originals" \
  [expr {[dict get [copyform::plan] updaterefs] eq "none" &&
         [string match "*ORIGINAL*" [.libmgr.cp.status cget -text]]}] \
  "(=> [.libmgr.cp.status cget -text])"
.libmgr.cp.h.ur.lib invoke
check "CF20d entire-library scope reaches the plan" \
  [expr {[dict get [copyform::plan] updaterefs] eq "library"}] {}
.libmgr.cp.h.ur.copies invoke
check "CF20e the 'On name conflict' choice is gone: each row of the table says what happens to it" \
  [expr {![winfo exists .libmgr.cp.h.cf]}] {}

set copyform::st(hier) 0
copyform::sync_hier
update
check "CF21 unchecking hides it again" [expr {[llength [grid info .libmgr.cp.h]] == 0}] {}

# --- accept returns the plan; cancel returns nothing ------------------------
set copyform::st(viewmode) filter
set copyform::st(viewfilter) "type:symbol"
set copyform::st(dstcell) op2
copyform::accept
eqc "CF22 accept returns a plan with the resolved views" \
  [list [q {dict get $copyform::result views}] [q {dict get $copyform::result dst}] \
        [q {dict get $copyform::result cells}]] {symbol {cflib op2} {{cflib op cflib op2 copy}}}
copyform::cancel
check "CF23 cancel returns nothing" [expr {$copyform::result eq {}}] {}
catch {destroy .libmgr.cp}

# =====================================================================
# T* -- the table of cells
# =====================================================================
set W .libmgr.cp
set tv $W.h.tvf.tv
# what the table shows: one {cell newname action} per row, in order
proc rows {} {
  set out {}
  foreach it [$::tv children {}] {
    lassign [$::tv item $it -values] l c n a
    lappend out [list [string trim $c] $n $a]
  }
  return $out
}
# a real click in the middle of one cell of the table
proc click {item col {n 1}} {
  lassign [$::tv bbox $item $col] x y w h
  if {$w eq {}} { return 0 }
  set cx [expr {$x + $w / 2}]
  set cy [expr {$y + $h / 2}]
  for {set i 0} {$i < $n} {incr i} {
    event generate $::tv <ButtonPress-1> -x $cx -y $cy
    event generate $::tv <ButtonRelease-1> -x $cx -y $cy
  }
  update
  return 1
}
# run a key binding of the name field the way the key would (a synthetic key
# press is not delivered reliably on this arm); 3 is the binding's own `break`
proc key {seq} {
  set rc [catch {uplevel #0 [bind $::tv.ed $seq]}]
  update
  return $rc
}
# type into a form entry and let the form hear it
proc typein {entry text} {
  $entry delete 0 end
  $entry insert 0 $text
  uplevel #0 [bind $entry <KeyRelease>]
  update
}

copyform::init cflib amp_tb
copyform::build
set copyform::done -1   ;# what copyform::open does before it waits
update
eqc "T1 the table's columns" [list [$tv cget -columns] [lmap c [$tv cget -columns] {$tv heading $c -text}]] \
  {{lib cell name action} {Library Cell {New name} Action}}
.libmgr.cp.hchk invoke
update
eqc "T2 Copy Hierarchical lists the cells below the bench; the primitive library is not among them" \
  [rows] {{amp_tb amp_tb Copy} {amp {} Keep} {sub {} Keep}}
typein $W.dst.cell namp_tb
eqc "T3 a new name typed in To: the bench's row follows, and the cell it is named after is proposed" \
  [rows] {{amp_tb namp_tb Copy} {amp namp Copy} {sub {} Keep}}
eqc "T4 the status bar is the plan in one line" [$W.status cget -text] \
  {2 cells to copy; 1 kept (still referenced where it is)}

# a click on Action switches the row; a kept cell of this library needs a name
check "T5 a click on the Action of a kept row" [click r2 action] {}
eqc "T5a ... opens the name field over that row's New name, because a copy here needs a new name" \
  [list $copyform::editing [winfo ismapped $tv.ed] \
        [q {list [dict get [place info $tv.ed] -x] [dict get [place info $tv.ed] -y]}]] \
  [list 2 1 [lrange [$tv bbox r2 name] 0 1]]
eqc "T5b ... and the status bar says why" [$W.status cget -text] \
  {sub stays in cflib: type a new name to copy it}
$tv.ed delete 0 end
$tv.ed insert 0 nsub
eqc "T6 Return in the name field ends the edit and stops there (the binding breaks)" [key <Return>] 3
update
eqc "T6a ... the row is copied under the typed name" [rows] {{amp_tb namp_tb Copy} {amp namp Copy} {sub nsub Copy}}
eqc "T6b ... the name field is gone and the form was NOT accepted" \
  [list [winfo ismapped $tv.ed] $copyform::editing $copyform::done [winfo exists $W]] {0 -1 -1 1}
click r1 action
eqc "T7 a click on the Action of a copied row keeps it instead" [rows] \
  {{amp_tb namp_tb Copy} {amp {} Keep} {sub nsub Copy}}
click r1 action
eqc "T8 ... and a second click copies it again, under the name it had" [rows] \
  {{amp_tb namp_tb Copy} {amp namp Copy} {sub nsub Copy}}
click r1 name 2
eqc "T9 a double-click on a New name opens the name field holding that name" \
  [list $copyform::editing [winfo ismapped $tv.ed] [$tv.ed get]] {1 1 namp}
$tv.ed delete 0 end
$tv.ed insert 0 zzz
eqc "T9a ... Escape drops what was typed" [list [key <Escape>] [winfo ismapped $tv.ed] [rows]] \
  [list 3 0 {{amp_tb namp_tb Copy} {amp namp Copy} {sub nsub Copy}}]
click r1 name 2
$tv.ed delete 0 end
$tv.ed insert 0 amp9
eqc "T10 a FocusOut that arrives while the field still has the focus does not close it" \
  [list [catch {copyform::edit_focusout $tv.ed}] $copyform::editing] {0 1}
focus $W.dst.cell
update
copyform::edit_focusout $tv.ed
update
eqc "T10a leaving the field keeps what was typed" [list $copyform::editing [rows]] \
  {-1 {{amp_tb namp_tb Copy} {amp amp9 Copy} {sub nsub Copy}}}
eqc "T10b ... and that is what the field's FocusOut binding runs" [bind $tv.ed <FocusOut>] \
  {copyform::edit_focusout %W}
typein $W.dst.cell namp2_tb
eqc "T11 rows named by hand keep their names when the bench is renamed again" [rows] \
  {{amp_tb namp2_tb Copy} {amp amp9 Copy} {sub nsub Copy}}
$tv selection set r1
$W.h.tb.tog invoke
update
eqc "T12 the Copy / Keep button switches the selected row" [lindex [rows] 1] {amp {} Keep}
$W.h.tb.tog invoke
update
$W.h.tb.ren invoke
update
eqc "T12a ... and the Rename button opens its name field" \
  [list [lindex [rows] 1] $copyform::editing [winfo ismapped $tv.ed]] {{amp amp9 Copy} 1 1}
key <Escape>
copyform::edit_begin 1
$tv.ed delete 0 end
$tv.ed insert 0 amp7
$W.h.ur.none invoke
update
eqc "T12b a name still being typed is kept when something else on the form is pressed" \
  [list $copyform::editing [winfo ismapped $tv.ed] [lindex [rows] 1]] {-1 0 {amp amp7 Copy}}
$W.h.ur.copies invoke
copyform::edit_begin 1
$tv.ed delete 0 end
$tv.ed insert 0 amp9
key <Return>
copyform::edit_begin 0
$tv.ed delete 0 end
$tv.ed insert 0 top9
key <Return>
update
eqc "T13 naming the first row in the table names the copy: the To field shows it" \
  [list [$W.dst.cell get] [lindex [rows] 0]] {top9 {amp_tb top9 Copy}}
copyform::edit_begin 2
$tv.ed delete 0 end
$tv.ed insert 0 user
key <Return>
update
eqc "T14 a name that is already a cell of the destination: that cell is used, nothing is copied over it" \
  [lindex [rows] 2] {sub user {Use existing}}
eqc "T14a ... and the status bar counts it" [$W.status cget -text] \
  {2 cells to copy; 1 already there (references go to it)}

# the exclude list
$W.h.eb.none invoke
update
eqc "T15 with no library excluded the primitive cell is listed too" \
  [lsort -unique [lmap r [rows] {lindex $r 0}]] {amp amp_tb res sub}
$W.h.eb.def invoke
update
eqc "T15a ... Defaults takes it out again" [lmap r [rows] {lindex $r 0}] {amp_tb amp sub}

# Rescan
set f [file join $tmp cflib amp_tb schematic amp_tb.sch]
set keep [read [set fh [open $f r]]][close $fh]
put $f "$keep[inst cflib/op 400 name=x9]\n"
uplevel #0 [bind $W.dst.cell <KeyRelease>]
update
eqc "T16 an instance added to the file meanwhile is not seen by an ordinary refresh" \
  [lsearch -exact [lmap r [rows] {lindex $r 0}] op] -1
$W.h.scan invoke
update
eqc "T16a ... Rescan reads the schematics again" \
  [expr {[lsearch -exact [lmap r [rows] {lindex $r 0}] op] >= 0}] 1
put $f $keep
$W.h.scan invoke
update

# "Entire destination library": the cells it would edit are listed before OK
$W.h.ur.lib invoke
update
eqc "T17 the cells already in the destination that use an original are listed as Re-point" \
  [lrange [rows] 3 end] {{user {} Re-point}}
eqc "T17a ... and counted on the status bar" [$W.status cget -text] \
  {Entire destination library: 1 cell already in cflib re-pointed too (listed below)}
eqc "T17b ... such a row is not a row of the plan" \
  [list [llength $copyform::rows] [llength [dict get [copyform::plan] cells]]] {3 3}
$W.h.ur.copies invoke
update
eqc "T17c New copies only takes them out again" [llength [rows]] 3

# =====================================================================
# A* -- OK
# =====================================================================
typein $W.dst.cell op
$W.b.ok invoke
eqc "A1 a copy onto a cell that exists is refused ON the form, with the reason, and the form stays" \
  [list [$W.status cget -text] $copyform::done [winfo exists $W]] {{cell already exists: cflib/op} -1 1}
typein $W.dst.cell namp_tb
copyform::edit_begin 1
$tv.ed delete 0 end
$tv.ed insert 0 {a b}
key <Return>
update
$W.b.ok invoke
eqc "A2 a row with a name no cell can have is refused the same way" \
  [list [string match "*'a b'*" [$W.status cget -text]] $copyform::done] {1 -1}
copyform::edit_begin 1
$tv.ed delete 0 end
$tv.ed insert 0 namp
key <Return>
update
$W.b.ok invoke
eqc "A3 OK on a plan that can run returns it" \
  [list $copyform::done [q {dict get $copyform::result cells}]] \
  {1 {{cflib amp_tb cflib namp_tb copy} {cflib amp cflib namp copy} {cflib sub cflib user use}}}
$W.b.cancel invoke
eqc "A4 Cancel returns nothing" [list $copyform::done $copyform::result] {0 {}}
set copyform::done -1
uplevel #0 [wm protocol $W WM_DELETE_WINDOW]
eqc "A5 the window's close button is Cancel" [list $copyform::done $copyform::result] {0 {}}
catch {destroy $W}

# =====================================================================
# E* -- end to end, through the Library Manager and the real, modal form
# =====================================================================
# The form blocks in its own event loop, so what the user would do is queued
# to run inside it. A step that fails cancels the form instead of leaving it up.
proc drive {script} {
  after 300 [list apply {{script} {
    if {[catch {uplevel #0 $script} e]} {
      set ::drive_err $e
      catch {set copyform::done 0}
    }
  }} $script]
  after 30000 {if {$copyform::done == -1} { set ::drive_err "the form never closed"; set copyform::done 0 }}
}
set ::drive_err {}
libmgr::refresh_after cflib amp_tb
update
drive {
  typein .libmgr.cp.dst.cell namp_tb
  .libmgr.cp.hchk invoke
  update
  .libmgr.cp.b.ok invoke
}
libmgr::ctx_copy_cell
update
eqc "E1 right-click > Copy on the bench, a new name, Copy Hierarchical, OK: no step failed" $::drive_err {}
eqc "E2 the bench and the cell it is named after are both copied" \
  [list [library_cell_layout cflib namp_tb] [library_cell_layout cflib namp] [library_cell_layout cflib nsub]] \
  {nested nested {}}
set txt [q {set fh [open [file join $tmp cflib namp_tb schematic namp_tb.sch] r]; set t [read $fh]; close $fh; set t}]
eqc "E3 the copied bench instantiates the copied cell" \
  [list [regexp -all -line {^C \{cflib/namp\}} $txt] [regexp -all -line {^C \{cflib/amp\}} $txt]] {1 0}
set txt [q {set fh [open [file join $tmp cflib namp_tb ngspice_state1 namp_tb.state] r]; set t [read $fh]; close $fh; set t}]
eqc "E4 its saved state simulates the copied bench" [q {dict get $txt design}] {lib cflib cell namp_tb view schematic}
eqc "E5 the Library Manager's status bar gives the account" [.libmgr.status cget -text] \
  {copied 2 cells, 1 instance re-pointed, 1 state re-pointed}
eqc "E6 ... the new bench is the selected cell, and the form is gone" \
  [list [.libmgr.pw.cell.lb selection] [winfo exists .libmgr.cp]] {namp_tb 0}

# the other order: the new device exists already, the bench is copied after it
set ::drive_err {}
libmgr::refresh_after cflib amp_tb
update
drive {
  typein .libmgr.cp.dst.cell second_tb
  .libmgr.cp.hchk invoke
  update
  copyform::edit_begin 1
  .libmgr.cp.h.tvf.tv.ed delete 0 end
  .libmgr.cp.h.tvf.tv.ed insert 0 namp
  catch {uplevel #0 [bind .libmgr.cp.h.tvf.tv.ed <Return>]}
  update
  set ::e7 [.libmgr.cp.h.tvf.tv item r1 -values]
  .libmgr.cp.b.ok invoke
}
set before [lsort [glob -nocomplain -directory [file join $tmp cflib] *]]
libmgr::ctx_copy_cell
update
eqc "E7 the bench copied AFTER its new device: naming the row after the existing cell uses it" \
  [list $::drive_err [q {lrange $::e7 2 3}]] {{} {namp {Use existing}}}
set txt [q {set fh [open [file join $tmp cflib second_tb schematic second_tb.sch] r]; set t [read $fh]; close $fh; set t}]
eqc "E8 ... one cell was made, and it instantiates the existing device" \
  [list [lsort [glob -nocomplain -directory [file join $tmp cflib] *]] [regexp -all -line {^C \{cflib/namp\}} $txt]] \
  [list [lsort [concat $before [list [file join $tmp cflib second_tb]]]] 1]

# Cancel
set ::drive_err {}
drive { .libmgr.cp.b.cancel invoke }
set before [lsort [glob -nocomplain -directory [file join $tmp cflib] *]]
set st [.libmgr.status cget -text]
libmgr::ctx_copy_cell
update
eqc "E9 Cancel in the form copies nothing and says nothing" \
  [list $::drive_err [lsort [glob -nocomplain -directory [file join $tmp cflib] *]] [.libmgr.status cget -text]] \
  [list {} $before $st]

catch {destroy .libmgr.cp}
catch {destroy .libmgr}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  puts "OVERALL: ok ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail != 0}]
