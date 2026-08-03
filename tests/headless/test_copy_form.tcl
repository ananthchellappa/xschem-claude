# Copy form (src/copy_form.tcl, doc/claude/specs/copy_hierarchical.md) — pass 1.
# Covers the two halves separately:
#   * the headless core (view TYPE derivation, filter parsing, view matching,
#     the plan dict) against a fixture library built in a temp dir, and
#   * the widget behaviour that IS the pass-1 deliverable: the hierarchical
#     section is hidden until the "Copy Hierarchical" checkbox is ticked.
#
# Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_copy_form.tcl

# Needs a display: the second half builds real widgets. Self-skip in the
# full_audit banner shape so a display-less box scores SKIP, not FAIL.
if {[catch {winfo screenwidth .}]} {
  puts "RESULT: SKIP (no X)"; puts "OVERALL: ok"; exit 0
}
source [file join [file dirname [info script]] scratch.tcl]

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# --- fixture library: one cell, four views, three distinct types -------------
# test_scratch owns the directory's lifetime (issue 0148): it is removed on
# every exit path, including an early failure.
set tmp [test_scratch copyform]
foreach {view file} {schematic op.sch symbol op.sym ngspice_state1 op.state spectre_state2 op.state} {
  file mkdir [file join $tmp cflib op $view]
  set fh [open [file join $tmp cflib op $view $file] w]; close $fh
}
foreach lib {devices cf_pr cf_stdcells cf_tests} {
  file mkdir [file join $tmp $lib res symbol]
  set fh [open [file join $tmp $lib res symbol res.sym] w]; close $fh
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
wm withdraw .libmgr.cp
update idletasks
check "CF14 form built" [winfo exists .libmgr.cp] {}
check "CF15 hierarchy section hidden while unchecked" [expr {[llength [grid info .libmgr.cp.h]] == 0}] {}
check "CF16 view list shows name and type" \
  [expr {[lindex [.libmgr.cp.vw.lb get 0] 0] eq "ngspice_state1" &&
         [string match "*(state)*" [.libmgr.cp.vw.lb get 0]]}] "(=> [.libmgr.cp.vw.lb get 0])"
check "CF17 view widgets disabled in All-views mode" \
  [expr {[.libmgr.cp.vw.lb cget -state] eq "disabled" && [.libmgr.cp.vw.flt cget -state] eq "disabled"}] {}

set copyform::st(hier) 1
copyform::sync_hier
update idletasks
check "CF18 hierarchy section revealed when checked" [expr {[llength [grid info .libmgr.cp.h]] > 0}] {}
check "CF19 exclude list pre-selects the defaults" [expr {[llength [.libmgr.cp.h.excl curselection]] > 0}] {}
check "CF20 cell table has the top cell row" \
  [expr {[llength [.libmgr.cp.h.tvf.tv children {}]] >= 1 &&
         [.libmgr.cp.h.tvf.tv set [lindex [.libmgr.cp.h.tvf.tv children {}] 0] cell] eq "op"}] {}

# update-references scope: Cadence's three-way, default "new copies only"
check "CF20a three update-reference choices exist" \
  [expr {[winfo exists .libmgr.cp.h.ur.none] && [winfo exists .libmgr.cp.h.ur.copies] &&
         [winfo exists .libmgr.cp.h.ur.lib]}] {}
check "CF20b default scope is copies-only" [expr {$copyform::st(updaterefs) eq "copies"}] \
  "(=> $copyform::st(updaterefs))"
set copyform::st(updaterefs) none
copyform::sync_refs
check "CF20c None keeps references on the originals" \
  [expr {[dict get [copyform::plan] updaterefs] eq "none" &&
         [string match "*ORIGINAL*" [.libmgr.cp.status cget -text]]}] \
  "(=> [.libmgr.cp.status cget -text])"
set copyform::st(updaterefs) library
check "CF20d entire-library scope reaches the plan" \
  [expr {[dict get [copyform::plan] updaterefs] eq "library"}] {}
set copyform::st(updaterefs) copies

set copyform::st(hier) 0
copyform::sync_hier
update idletasks
check "CF21 unchecking hides it again" [expr {[llength [grid info .libmgr.cp.h]] == 0}] {}

# --- accept returns the plan; cancel returns nothing ------------------------
set copyform::st(viewmode) filter
set copyform::st(viewfilter) "type:symbol"
copyform::accept
check "CF22 accept returns a plan with the resolved views" \
  [expr {[dict get $copyform::result views] eq {symbol} &&
         [dict get $copyform::result dst] eq {cflib op}}] "(=> $copyform::result)"
copyform::cancel
check "CF23 cancel returns nothing" [expr {$copyform::result eq {}}] {}

catch {destroy .libmgr.cp}
catch {destroy .libmgr}
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
if {$fail} { exit 1 }
exit 0
