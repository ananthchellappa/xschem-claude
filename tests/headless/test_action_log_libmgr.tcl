# Action-logging coverage for the Library Manager + read-only toggle. A Library
# Manager open used the bare (silent "replay form") load command, so it never
# reached the CIW / Xschem.log; mode changes were not logged at all. Both now
# emit `xschem log_action` with the replayable command.
#
# Must run WITH action logging on; the harness passes --logdir and the same dir
# in $env(XSCHEM_AL_LOGDIR). The action log is line-buffered, so lines are
# readable in-process. Run under X with --pipe from src/:
#   d=/tmp/al.$$; XSCHEM_AL_LOGDIR=$d DISPLAY=:0 ./xschem --pipe -q --logdir $d \
#       --script ../tests/headless/test_action_log_libmgr.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f {txt {v {xschem}}}} {
  file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp
}
proc logtext {} { set fp [open $::LOG r]; set d [read $fp]; close $fp; return $d }

if {![info exists env(XSCHEM_AL_LOGDIR)]} { puts "FAIL: AL0 XSCHEM_AL_LOGDIR not set"; exit 1 }
set LOG [file join $env(XSCHEM_AL_LOGDIR) Xschem.log]
check "AL0 action log is open" [file isfile $LOG] "(=> $LOG)"

# --- fixture: a private library with a nested cell -------------------------
set tmp [file join [pwd] _allm_[pid]]
file delete -force $tmp
touch $tmp/tlib/foo/schematic/foo.sch "v {xschem version=3.4.8RC file_version=1.3}"
touch $tmp/tlib/foo/symbol/foo.sym    "v {xschem version=3.4.8RC file_version=1.3}"
touch $tmp/tlib/bar/schematic/bar.sch "v {xschem version=3.4.8RC file_version=1.3}"
touch $tmp/tlib/baz/schematic/baz.sch "v {xschem version=3.4.8RC file_version=1.3}"
touch $tmp/tlib/qux/schematic/qux.sch "v {xschem version=3.4.8RC file_version=1.3}"
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

library_manager
update idletasks
proc pick {col txt} {
  set lb .libmgr.pw.$col.lb  ;# panes are ttk::treeview; row id == item name
  $lb selection set $txt; $lb focus $txt
}

# AL1 — a Library Manager open is logged with the replayable command. With the
# "New window" checkbox set, the open is routed through `load_new_window -window`
# so it lands in a real top-level window (doc/claude/specs/multi_window_detach.md).
pick lib tlib;  libmgr::on_lib
pick cell foo;  libmgr::on_cell
set libmgr::new_window 1
libmgr::open_view
check "AL1 Library Manager open is logged" \
  [string match "*xschem load_new_window -window {*foo/schematic/foo.sch}*" [logtext]] {}

# AL2 — toggling edit mode is logged
xschem set readonly 0
toggle_readonly
check "AL2 read-only toggle logged (set 1)" [string match "*xschem set readonly 1*" [logtext]] {}
toggle_readonly
check "AL3 read-only toggle logged (set 0)" \
  [expr {[regexp -all {xschem set readonly 0} [logtext]] >= 1}] {}

# AL4 — Open (read-only) logs both the open and the read-only lock
pick cell bar; libmgr::on_cell
libmgr::open_view_ro
set t [logtext]
check "AL4 read-only open logs the open" [string match "*load_new_window -window {*bar/schematic/bar.sch}*" $t] {}
check "AL5 read-only open logs the lock" [expr {[regexp -all {xschem set readonly 1} $t] >= 2}] {}

# AL6 — the logged lines are the bare replay form (no recursion / no log_action wrapper)
check "AL6 log holds bare replayable commands" \
  [expr {![string match "*log_action*" [logtext]]}] {}

# AL7/AL8 — the file browser's open-in-new-window also logs (same gap, same fix).
# Drive file_chooser_place directly with the minimal widget/state it reads.
frame .ins; frame .ins.center; frame .ins.center.left
listbox .ins.center.left.l
.ins.center.left.l insert end baz
.ins.center.left.l activate 0
set ::file_chooser(fullpathlist) [list $tmp/tlib/baz/schematic/baz.sch]
set ::open_in_new_window 1
file_chooser_place load
check "AL7 file browser open-in-new-window logged" \
  [string match "*load_new_window {*baz/schematic/baz.sch}*" [logtext]] {}

.ins.center.left.l delete 0 end
.ins.center.left.l insert end qux
.ins.center.left.l activate 0
set ::file_chooser(fullpathlist) [list $tmp/tlib/qux/schematic/qux.sch]
file_chooser_place load_new_win
check "AL8 file browser 'open in new window' action logged" \
  [string match "*load_new_window {*qux/schematic/qux.sch}*" [logtext]] {}

# AL9 — Library Manager "Place symbol" starts the INTERACTIVE placement
# (PLACE_SYMBOL=8192). Its drop already logs a concrete, replayable
# `xschem instance {...}` (callback.c), so no command-level logging is added for
# place_symbol (that would be non-replayable and duplicate the drop's line).
pick lib tlib; libmgr::on_lib
pick cell foo; libmgr::on_cell
libmgr::place_symbol
check "AL9 place_symbol starts the logged placement (PLACE_SYMBOL state)" \
  [expr {([xschem get ui_state] & 8192) != 0}] "(=> ui_state=[xschem get ui_state])"
xschem abort_operation

# AL10 — the Library Manager launch command logs itself: a single replayable
# `xschem library_manager` line (bindable to a key). .libmgr is already open, so
# this exercises the raise path; it must still log the launch.
xschem library_manager
check "AL10 launch logs replayable 'xschem library_manager'" \
  [expr {[regexp -all -line {^xschem library_manager$} [logtext]] >= 1}] {}

# AL11 — the Create Instance launch also logs a single replayable line
xschem create_instance
check "AL11 launch logs replayable 'xschem create_instance'" \
  [expr {[regexp -all -line {^xschem create_instance$} [logtext]] >= 1}] {}

# AL12 — closing a schematic window/tab is logged with a replayable command, so a
# close shows in the CIW / Xschem.log (doc/claude/specs/multi_window_detach.md). Open a throwaway
# window and close it; the destroy must appear.
xschem new_schematic create_window .x9 {}
update
xschem new_schematic destroy .x9.drw {}
update
check "AL12 closing a schematic window is logged" \
  [expr {[regexp -all -line {^xschem new_schematic destroy \.x9\.drw$} [logtext]] >= 1}] {}

catch {ciform::escape}   ;# tear down the Create Instance form (.ciform) + browser

destroy .ins
destroy .libmgr
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
