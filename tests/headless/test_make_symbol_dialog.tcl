# P2: make_symbol_dialog orchestrator (adaptive View-name / Create / Replace).
# Spec: doc/claude/specs/create_symbol_view.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_make_symbol_dialog.tcl
#
# The GUI dialog (ask_symbol_view) is has_x-gated; here it is STUBBED to script the
# user's {view action} choice, and we assert the orchestrator routes to the right
# generation at the right view path. Modify is P3; the open-in-new-window step is
# has_x-gated (skipped headless).

set work /tmp/p2_symdialog_work
file delete -force $work; file mkdir $work

proc mk_sch {path} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {}"; puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  puts $fp "C {ipin.sym} 0 0 0 0 {name=p1 lab=IN}"
  puts $fp "C {opin.sym} 100 0 0 0 {name=p2 lab=OUT}"
  close $fp
}
file mkdir $work/nlib/amp/schematic;  mk_sch $work/nlib/amp/schematic/amp.sch
file mkdir $work/nlib/amp2/schematic; mk_sch $work/nlib/amp2/schematic/amp2.sch
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work/nlib:$XSCHEM_LIBRARY_PATH"

set ::fails 0
proc check {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout; if {!$ok} {incr ::fails} }
proc result {} { puts [expr {$::fails==0 ? {RESULT: ALL PASS} : "RESULT: $::fails FAILED"}]; flush stdout; exit [expr {$::fails!=0}] }

# Stub the GUI dialog: return the scripted {view action} (or {} for cancel).
set ::sv_return {}
proc ask_symbol_view {schpath} { return $::sv_return }

# --- create: default view "symbol", absent -> symbol/amp.sym ---
set ::sv_return {symbol create}
make_symbol_dialog $work/nlib/amp/schematic/amp.sch
check "create: symbol view made at symbol/amp.sym" [file exists $work/nlib/amp/symbol/amp.sym]

# --- custom view name -> that view dir ---
set ::sv_return {sym_v2 create}
make_symbol_dialog $work/nlib/amp/schematic/amp.sch
check "custom view name -> sym_v2/amp.sym" [file exists $work/nlib/amp/sym_v2/amp.sym]

# --- replace: existing view, regenerate ---
set before [file mtime $work/nlib/amp/symbol/amp.sym]
after 1100
set ::sv_return {symbol replace}
make_symbol_dialog $work/nlib/amp/schematic/amp.sch
check "replace: symbol view still present" [file exists $work/nlib/amp/symbol/amp.sym]
check "replace: symbol was regenerated (mtime advanced)" \
  [expr {[file mtime $work/nlib/amp/symbol/amp.sym] > $before}]

# --- cancel: no generation ---
set ::sv_return {}
make_symbol_dialog $work/nlib/amp2/schematic/amp2.sch
check "cancel: no symbol created" [expr {![file exists $work/nlib/amp2/symbol/amp2.sym]}]

# --- modify routing: schematic gains a pin; {view modify} adds only it ---
# amp/symbol/amp.sym already exists (2 pins). Add a 3rd pin to the schematic.
set fp [open $work/nlib/amp/schematic/amp.sch a]
puts $fp "C {ipin.sym} 0 40 0 0 {name=p3 lab=EN}"
close $fp
proc sym_pins {f} { set n 0; set fp [open $f]; foreach l [split [read $fp] \n] { if {[regexp {^B 5 .*dir=} $l]} {incr n} }; close $fp; return $n }
set ::sv_return {symbol modify}
make_symbol_dialog $work/nlib/amp/schematic/amp.sch
check "modify: routed to add the new pin EN (3 pins now)" [expr {[sym_pins $work/nlib/amp/symbol/amp.sym] == 3}]

result
