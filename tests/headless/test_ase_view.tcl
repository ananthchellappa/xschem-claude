# ASE-L view dispatch (item 02 of doc/claude/ase_l_batch, P2 of
# doc/claude/specs/ase_l.md) — `ngspice_state1` as a first-class view:
#   V1/V2  discovery/resolution through the UNCHANGED cell_views/cellview_path
#   V3/V4  library_new_view seeds a VALID serialized default state (never empty)
#   V5     libmgr::view_handler dispatch-table unit checks (no Tk)
#   V6     ase::open_state return codes (headless: no Tk side effects)
#   V7-V9  hi_descend enum type / hi_descend_do routing / finish refuse
#   V10    saveform::resolve_target type mapping (+ schematic no-regression)
#   V11    git plumbing is view-name agnostic (silent skip without git)
#   G1-G3  GUI legs (real LibMgr View-pane double-click, Open read-only,
#          newview combobox) — run only under DISPLAY, else a partial skip
#
# Runs via full_audit's DEFAULT arm. Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_view.tcl
# (add DISPLAY for the GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# the live ASE-L session window of session `key` (item 03 replaced the v0
# read-only textwindow with the real ase::ui window), or {}. GUI sessions only.
proc find_ase_window {key} {
  if {![info exists ::has_x] || [info commands winfo] eq {}} { return {} }
  set w [ase::ui::window_for $key]
  if {$w ne {} && [winfo exists $w]} { return $w }
  return {}
}

# --- scratch lib fixture ------------------------------------------------------
set scratch [file normalize [file join [pwd] _ase_view_[pid]]]
file delete -force $scratch
file mkdir [file join $scratch aseviewlib]
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aseviewlib [file join $scratch aseviewlib]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1

if {[catch {

# build the cell through the REAL backends; the ngspice_state1 call is itself
# code under test (D5 seeding)
library_new_cell aseviewlib vcell schematic
library_new_view aseviewlib vcell symbol symbol
library_new_view aseviewlib vcell ngspice_state1 ngspice_state1

# --- V1/V2: discovery + resolution (unchanged machinery) ---------------------
set views [xschem cell_views aseviewlib vcell]
check_true "V1 cell_views lists ngspice_state1" [expr {[lsearch -exact $views ngspice_state1] >= 0}]
check_true "V1 cell_views lists schematic + symbol too" \
  [expr {[lsearch -exact $views schematic] >= 0 && [lsearch -exact $views symbol] >= 0}]
set spath [xschem cellview_path aseviewlib/vcell ngspice_state1]
check_true "V2 cellview_path resolves the .state file" \
  [string match "*ngspice_state1/vcell.state" $spath]

# --- V3: seeded file loads as a valid state dict -----------------------------
set st [ase::state_load $spath]
check "V3 version" [ase::state_get $st version] 1
check "V3 simulator" [ase::state_get $st simulator] ngspice
set design [ase::state_get $st design]
check "V3 design lib"  [expr {[dict exists $design lib]  ? [dict get $design lib]  : {}}] aseviewlib
check "V3 design cell" [expr {[dict exists $design cell] ? [dict get $design cell] : {}}] vcell
check "V3 design view points at the schematic" \
  [expr {[dict exists $design view] ? [dict get $design view] : {}}] schematic

# --- V4: seeded file non-empty + load->save byte-stable ----------------------
check_true "V4 seeded file non-empty" [expr {[file size $spath] > 0}]
set f [open $spath rb]; set seeded [read $f]; close $f
ase::state_save [file join $scratch v4.state] $st
set f [open [file join $scratch v4.state] rb]; set resaved [read $f]; close $f
check_true "V4 load->save byte-identical to the seeded file" [expr {$seeded eq $resaved}]

# --- V5: dispatch-table unit checks (no Tk) ----------------------------------
check "V5 name glob: ngspice_state1 -> ase" [libmgr::view_handler ngspice_state1] ase::open_state
check "V5 name: schematic -> editor" [libmgr::view_handler schematic] editor
check "V5 name: symbol -> editor" [libmgr::view_handler symbol] editor
check "V5 path authoritative: .state under any view name -> ase" \
  [libmgr::view_handler mystate /x/c/mystate/c.state] ase::open_state
check "V5 path authoritative: .sch under ngspice_state1 name -> editor" \
  [libmgr::view_handler ngspice_state1 /x/c/ngspice_state1/c.sch] editor

# --- V6: ase::open_state return codes ----------------------------------------
check "V6 existing view -> 1" [ase::open_state aseviewlib vcell ngspice_state1] 1
set caught [catch {ase::open_state aseviewlib vcell nosuchview} r6]
check "V6 missing view throws no error" $caught 0
check "V6 missing view -> 0" $r6 0
# under DISPLAY the V6 call opened the real ASE-L session window: close it
# (real Close path) so G1/G2 see only their own window; headless just drop the
# session registration
set akey [ase::session_key aseviewlib vcell ngspice_state1]
set w [find_ase_window $akey]
if {$w ne {}} { ase::ui::close $akey; update } else { ase::session_close $akey }

# --- parent schematic for the hi_descend legs --------------------------------
set psch [file join $scratch parent.sch]
set f [open $psch w]
puts $f "v {xschem version=3.4.7RC file_version=1.2}"
foreach r {G K V S E} { puts $f "$r \{\}" }
puts $f "C {aseviewlib/vcell} 100 -100 0 0 {name=X1}"
close $f
xschem load $psch

# --- V7: enum shows the state view with its own type -------------------------
set rows [hi_descend_enum_views X1]
set staterow {}
foreach r $rows { if {[lindex $r 0] eq {ngspice_state1}} { set staterow $r } }
check "V7 enum row type is ngspice_state" [lindex $staterow 1] ngspice_state
check "V7 enum row path is the .state file" \
  [file normalize [lindex $staterow 2]] [file normalize $spath]

# --- V8: hi_descend_do routes to ase::open_state (recorder) ------------------
set ::v8_calls {}
rename ::ase::open_state ::ase::open_state_real
proc ::ase::open_state {lib cell view} {
  lappend ::v8_calls [list $lib $cell $view]
  return 1
}
# catch guard: a failed leg must not poison the restore below
if {[catch {
  set cs0 [xschem get currsch]
  check "V8 target=current routed" [hi_descend_do X1 ngspice_state1 {} current 1 readonly] 1
  check "V8 recorder got lib/cell/view" [lindex $::v8_calls 0] {aseviewlib vcell ngspice_state1}
  check "V8 target=new_window routed too" [hi_descend_do X1 ngspice_state1 {} new_window 1 readonly] 1
  check "V8 recorder hit twice" [llength $::v8_calls] 2
  check "V8 currsch unchanged (no window machinery ran)" [xschem get currsch] $cs0
} v8err]} {
  puts "FAIL: V8 leg errored: $v8err : FAIL"; incr fail
}
rename ::ase::open_state {}
rename ::ase::open_state_real ::ase::open_state

# --- V9: hi_descend_finish refuses non-descendable view types ----------------
set cs0 [xschem get currsch]
check "V9 finish refuses ngspice_state" [hi_descend_finish X1 ngspice_state /any/path 1 readonly] 0
check "V9 currsch unchanged" [xschem get currsch] $cs0

# --- V10: Save-As type mapping -----------------------------------------------
set p10 [saveform::resolve_target aseviewlib vcell ngspice_state1 ngspice_state1]
check_true "V10 ngspice_state1 type -> <cell>.state" \
  [string match "*ngspice_state1/vcell.state" $p10]
set p10b [saveform::resolve_target aseviewlib vcell schematic schematic]
check_true "V10 schematic type still -> <cell>.sch (no regression)" \
  [string match "*schematic/vcell.sch" $p10b]

# --- V11: git plumbing is view-name agnostic (silent skip without git) -------
if {[auto_execok git] ne {}} {
  set libdir [file join $scratch aseviewlib]
  exec git -C $libdir init -q
  exec git -C $libdir add vcell/ngspice_state1/vcell.state
  exec git -C $libdir -c user.name=asetest -c user.email=asetest@localhost \
    commit -q -m "seed state view"
  set tv [libmgr::tracked_views aseviewlib vcell]
  check_true "V11 tracked_views has ngspice_state1" [dict exists $tv ngspice_state1]
  lassign [libmgr::git_target aseviewlib vcell ngspice_state1] root ps
  check "V11 git_target root is the lib repo" [file normalize $root] [file normalize $libdir]
  check "V11 git_target has one pathspec" [llength $ps] 1
}

# --- GUI legs (DISPLAY-guarded partial skip) ---------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  # G1: the REAL View-pane double-click binding is the surface under test
  # (gesture-test-full-sequence lesson). Tk refuses `event generate
  # <Double-1>` outright ("Double ... modifier not allowed"), so replay the
  # real event stream instead: two press/release pairs at one spot — Tk's own
  # click-count machinery turns the second press into the <Double-1> match,
  # firing the shipping binding. Aim at the ngspice_state1 row's bbox center
  # (a press moves the treeview selection to the row under the pointer).
  library_manager
  libmgr::refresh_after aseviewlib vcell ngspice_state1
  update
  set t .libmgr.pw.view.lb
  set bx 10; set by 10
  set bb [$t bbox ngspice_state1]
  if {[llength $bb] == 4} {
    lassign $bb x y wdt hgt
    set bx [expr {$x + $wdt/2}]; set by [expr {$y + $hgt/2}]
  }
  foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
    event generate $t $ev -x $bx -y $by
  }
  update
  set viewer [find_ase_window $akey]
  check_true "G1 double-click opened the ASE-L session window" [expr {$viewer ne {}}]
  if {$viewer ne {}} { ase::ui::close $akey; update }

  # G2: Open (read-only) diverts to the (already read-only) viewer and must
  # NOT force the current schematic window read-only
  libmgr::refresh_after aseviewlib vcell ngspice_state1
  update
  libmgr::open_view_ro
  update
  set viewer [find_ase_window $akey]
  check_true "G2 open_view_ro opened the ASE-L window" [expr {$viewer ne {}}]
  check "G2 current window readonly untouched" [xschem get readonly] 0
  if {$viewer ne {}} { ase::ui::close $akey; update }

  # G3: the newview dialog's editor-type combobox offers ngspice_state1
  # (harvested from inside the modal vwait, then cancelled)
  set ::g3_values {}
  after 300 {catch {set ::g3_values [.libmgr.nv2.type cget -values]}; set ::libmgr::dlg_done 0}
  libmgr::newview_dialog aseviewlib vcell
  check_true "G3 newview combobox offers ngspice_state1" \
    [expr {[lsearch -exact $::g3_values ngspice_state1] >= 0}]
  catch {destroy .libmgr}
} else {
  puts "gui legs skipped (no DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# belt-and-suspenders: if a V8 abort left the recorder installed, restore
if {[info commands ::ase::open_state_real] ne {}} {
  catch {rename ::ase::open_state {}}
  catch {rename ::ase::open_state_real ::ase::open_state}
}

# --- cleanup + verdict -------------------------------------------------------
catch {file delete -force $scratch}
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
