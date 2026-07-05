# Action-log Layer C: a drag/click gesture that COMPLETES is recorded as the
# single command reproducing its effect (or a '#' marker where no faithful
# subcommand exists). Hooks: end_place_move_copy_zoom / end_move_copy_logged /
# end_shape_point_edit (callback.c) and the storeobject sites in
# new_wire/new_line/new_rect/new_arc/new_polygon (actions.c). Gestures are
# driven through `xschem callback` (the real dispatch path); assertions check
# the log line AND the actual state change, and parse the logged line back
# against the state so nothing is hardcoded to snap math.
# Run under X with --pipe and --logdir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_gesture_end_log.tcl
update idletasks
focus -force .drw
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  flush stdout
  if {!$ok} {incr ::fails}
}
set ::fails 0

proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
# log lines appended after index n0, as one list
proc newlines {n0} { lrange [loglines] $n0 end }

# event drivers (xschem callback .drw <event> <mx> <my> <key> <button> <aux> <state>)
proc motion {x y} { xschem callback .drw 6 $x $y 0 0 0 0; update idletasks }
proc click1 {x y} {
  xschem callback .drw 4 $x $y 0 1 0 0
  xschem callback .drw 5 $x $y 0 1 0 256
  update idletasks
}

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

xschem load xschem_library/examples/nand2.sch
set infix_interface 1   ;# `xschem wire/rect/... gui` starts the gesture at the mouse

# --- 1. zoom rectangle: RMB press -> drag -> release => xschem zoom_box -----
set n0 [llength [loglines]]
xschem callback .drw 4 100 100 0 3 0 0
xschem callback .drw 6 300 250 0 0 0 1024
xschem callback .drw 5 300 250 0 3 0 1024
update idletasks
set zline [lindex [newlines $n0] 0]
check "zoom drag logs zoom_box" [string match {xschem zoom_box *} $zline]
# absolute-coord replay: zoom elsewhere, source the line, view must round-trip
set want [list [xschem get zoom] [xschem get xorigin] [xschem get yorigin]]
xschem zoom_full
eval $zline
check "zoom_box line replays the exact view" \
  [expr {$want eq [list [xschem get zoom] [xschem get xorigin] [xschem get yorigin]]}]

# --- 2. degenerate zoom drag (no motion) logs nothing -----------------------
# a no-motion right-click falls through to the context menu, which would block
# on a real popup -- stub it to the abort pick (21), which Layer B logs as nothing
proc context_menu {} { return 21 }
set n0 [llength [loglines]]
xschem callback .drw 4 150 150 0 3 0 0
xschem callback .drw 5 150 150 0 3 0 1024
update idletasks
check "degenerate zoom logs no zoom_box" \
  [expr {[lsearch -glob [newlines $n0] {xschem zoom_box *}] < 0}]
catch {xschem abort_operation}

# --- 3. wire gesture => xschem wire x1 y1 x2 y2 -----------------------------
set n0 [llength [loglines]]
set w0 [xschem get wires]
motion 100 100
xschem wire gui
motion 300 100
click1 300 100
set lines [newlines $n0]
set i [lsearch -glob $lines {xschem wire *}]
check "wire gesture logs xschem wire" [expr {$i >= 0}]
check "wire gesture stored a wire" [expr {[xschem get wires] == $w0 + 1}]
# the logged coords are the stored wire's coords (last wire)
if {$i >= 0} {
  set n [expr {[xschem get wires] - 1}]
  set coords [xschem wire_coord $n]
  check "logged wire coords match stored wire" \
    [expr {[lrange [lindex $lines $i] 2 5] eq $coords}]
}
catch {xschem abort_operation}

# --- 4. rect gesture => xschem rect x1 y1 x2 y2 -----------------------------
set n0 [llength [loglines]]
set layer [xschem get rectcolor]
set r0 [xschem get rects $layer]
motion 150 150
xschem rect gui
motion 250 220
click1 250 220
check "rect gesture logs xschem rect" \
  [expr {[lsearch -glob [newlines $n0] {xschem rect *}] >= 0}]
check "rect gesture stored a rect" [expr {[xschem get rects $layer] == $r0 + 1}]
catch {xschem abort_operation}

# --- 5. move drop => xschem move_objects dx dy, and bbox shifts by (dx,dy) --
set n0 [llength [loglines]]
xschem unselect_all
xschem select instance 0
set p0 [lrange [xschem instance_coord 0] 2 3]   ;# placement x0 y0
motion 200 200
xschem move_objects
click1 200 200          ;# consumes MENUSTART, starts the move at the mouse
motion 280 260
click1 280 260          ;# drop
set lines [newlines $n0]
set i [lsearch -glob $lines {xschem move_objects *}]
check "move drop logs xschem move_objects dx dy" [expr {$i >= 0}]
if {$i >= 0} {
  lassign [lrange [lindex $lines $i] 2 3] dx dy
  set p1 [lrange [xschem instance_coord 0] 2 3]
  check "instance moved by exactly the logged delta" \
    [expr {[lindex $p1 0] - [lindex $p0 0] == $dx &&
           [lindex $p1 1] - [lindex $p0 1] == $dy}]
}

# --- 6. duplicate drop => xschem copy_objects dx dy -------------------------
# `xschem copy_objects` (the MENU command) arms a deferred copy: click-to-start, move,
# click-to-drop. (The C KEY is immediate, handled in callback.c case 'c', not this command.)
set n0 [llength [loglines]]
set i0 [xschem get instances]
xschem unselect_all
xschem select instance 0
motion 300 300
xschem copy_objects
click1 300 300
motion 360 340
click1 360 340
check "duplicate drop logs xschem copy_objects dx dy" \
  [expr {[lsearch -glob [newlines $n0] {xschem copy_objects *}] >= 0}]
check "duplicate created an instance" [expr {[xschem get instances] == $i0 + 1}]

# --- 7. symbol placement drop => xschem instance sym x y rot flip prop -------
# NOTE: the emit now goes through Tcl_Merge (issue 0048), which quotes each field
# MINIMALLY -- a plain sym name like lab_pin.sym is NOT brace-wrapped -- so the
# match is `xschem instance lab_pin.sym *`, not the old always-`{lab_pin.sym}`.
set n0 [llength [loglines]]
set i0 [xschem get instances]
xschem unselect_all
motion 120 120
xschem place_symbol lab_pin.sym
motion 180 140
click1 180 140
set lines [newlines $n0]
set i [lsearch -glob $lines {xschem instance lab_pin.sym *}]
check "symbol drop logs xschem instance" [expr {$i >= 0}]
check "symbol drop placed an instance" [expr {[xschem get instances] == $i0 + 1}]
# replay the logged line: it must place a second, identical instance
if {$i >= 0} {
  xschem unselect_all
  eval [lindex $lines $i]
  check "logged instance line replays (places another instance)" \
    [expr {[xschem get instances] == $i0 + 2}]
}

# --- 7b. symbol drop whose PROP has braces/backslashes stays replayable ------
# (issue 0048: Tcl_Merge quotes any legal string, so the placement is NOT dropped
# to a '# place symbol ...' comment the way the old tcl_braceable brace-wrap did.)
set n0 [llength [loglines]]
set i0 [xschem get instances]
xschem unselect_all
motion 140 260
xschem place_symbol lab_pin.sym {name=P1 lab=A\{B\}C\\D}
motion 200 280
click1 200 280
set lines [newlines $n0]
set i [lsearch -glob $lines {xschem instance lab_pin.sym *}]
check "brace/backslash prop still logs a replayable instance line (0048)" [expr {$i >= 0}]
check "brace-prop placement NOT dropped to a comment" \
  [expr {[lsearch -glob $lines {# place symbol*}] < 0}]
check "brace-prop placement placed an instance" [expr {[xschem get instances] == $i0 + 1}]
# the logged element round-trips to the EXACT prop (Tcl_Merge quoting is lossless)
if {$i >= 0} {
  set before [xschem get instances]
  set err [catch {uplevel #0 [list eval [lindex $lines $i]]} m]
  check "brace-prop logged line replays cleanly (no source error)" [expr {$err == 0}]
  check "brace-prop replay placed another instance" \
    [expr {[xschem get instances] == $before + 1}]
  set n [expr {[xschem get instances] - 1}]
  check "replayed instance carries the exact brace/backslash prop" \
    [expr {[string first {lab=A\{B\}C\\D} [xschem getprop instance $n]] >= 0}]
}

# --- 8. text placement drop => xschem text ... (dialog stubbed) -------------
# Tcl_Merge minimal quoting again: a plain "HELLO" is NOT brace-wrapped (issue 0048).
proc enter_text {label mode} { set ::tctx::retval "HELLO" }
set n0 [llength [loglines]]
xschem unselect_all
motion 220 220
xschem place_text
motion 260 240
click1 260 240
check "text drop logs xschem text ... HELLO ..." \
  [expr {[lsearch -glob [newlines $n0] {xschem text * HELLO *}] >= 0}]

# --- 9. polygon close => xschem polygon x1 y1 ... (Phase 3 slice B) ---------
set n0 [llength [loglines]]
set layer [xschem get rectcolor]
set g0 [xschem get polygons $layer]
motion 400 400
xschem polygon gui
motion 500 400; click1 500 400
motion 500 480; click1 500 480
motion 400 400; click1 400 400      ;# click first point again -> close & store
set lines [newlines $n0]
set i [lsearch -glob $lines {xschem polygon *}]
check "polygon close logs xschem polygon with points" [expr {$i >= 0}]
check "polygon gesture stored a polygon" [expr {[xschem get polygons $layer] == $g0 + 1}]
# replay the logged line: places a second polygon
if {$i >= 0} {
  eval [lindex $lines $i]
  check "logged polygon line replays (stores another polygon)" \
    [expr {[xschem get polygons $layer] == $g0 + 2}]
}
catch {xschem abort_operation}

# --- 10. middle-button drag-pan => xschem pan dx dy (Phase 3 slice C) -------
proc near {a b} { expr {abs($a - $b) < 1e-9 * (abs($a) + abs($b) + 1)} }
set n0 [llength [loglines]]
set ox0 [xschem get xorigin]; set oy0 [xschem get yorigin]
xschem callback .drw 4 300 300 0 2 0 0          ;# Button2 press
xschem callback .drw 6 360 250 0 0 0 512        ;# drag (Button2Mask)
xschem callback .drw 5 360 250 0 2 0 512        ;# release
update idletasks
set lines [newlines $n0]
set i [lsearch -glob $lines {xschem pan *}]
check "drag-pan logs xschem pan dx dy" [expr {$i >= 0}]
if {$i >= 0} {
  lassign [lrange [lindex $lines $i] 2 3] dx dy
  check "logged pan delta matches the origin shift" \
    [expr {[near [expr {[xschem get xorigin] - $ox0}] $dx] &&
           [near [expr {[xschem get yorigin] - $oy0}] $dy]}]
  # replay: applies the same shift again
  set ox1 [xschem get xorigin]; set oy1 [xschem get yorigin]
  eval [lindex $lines $i]
  check "logged pan line replays the same shift" \
    [expr {[near [expr {[xschem get xorigin] - $ox1}] $dx] &&
           [near [expr {[xschem get yorigin] - $oy1}] $dy]}]
}

# --- 11. no-motion middle click logs nothing ---------------------------------
set n0 [llength [loglines]]
xschem callback .drw 4 200 200 0 2 0 0
xschem callback .drw 5 200 200 0 2 0 512
update idletasks
check "no-motion pan logs nothing" \
  [expr {[lsearch -glob [newlines $n0] {xschem pan *}] < 0}]

# --- 12. the whole file stays source-able (the Layer B invariant) -----------
# (sourcing re-executes the commands; harmless: absolute zoom_box, additive
# placements, selection-dependent move/copy on whatever is then selected)
check "log file is source-able" \
  [expr {![catch {uplevel #0 [list source [xschem get actionlog_filename]]} err]}]

# clean RAIL teardown (issue 0002): drop the auto-opened CIW before exit
catch {destroy .ciw}; update

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
