# RED-first regression for the Cadence-style "Add Wire Label" form
# (doc/claude/specs/add_wire_label.md). Pressing `l` in a schematic opens a modeless form;
# typed names (queue) place `lab_pin.sym` net-label INSTANCES, expanding buses when
# "Split bus" is on, and a label may only be DROPPED where its pin lands on copper
# (a wire or an instance pin) -- no stray net-labels.
#
# Every assertion FAILS before the implementation (the commands, the action ids and the
# addlabel:: helpers do not exist yet) -> RED, and passes after.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_add_wire_label.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc placing {} { return [expr {([xschem get ui_state] & 16384) ? 1 : 0}] }
proc inst_lab {i}  { return [xschem getprop instance $i lab] }
proc inst_sym {i}  { return [xschem getprop instance $i cell::name] }

# ---------------------------------------------------------------------------
# A. Pure Tcl name parsing / bus expansion (headless-safe: no Tk widgets).
#    expand_names {names split_bus}
# ---------------------------------------------------------------------------
# (expecteds with bus brackets are built via [list ...] so their canonical string rep -- Tcl
#  braces elements containing [] -- matches the returned list's rep; the values are identical.)
check "scalars, split off"         [addlabel::expand_names "A B C" 0] {A B C}
check "scalars, split on"          [addlabel::expand_names "A B C" 1] {A B C}
check "mixed separators"           [addlabel::expand_names "A,B  C , D" 1] {A B C D}
check "empty"                      [addlabel::expand_names "   " 1] {}
# bus expansion only when Split bus is ON
check "range split ON"             [addlabel::expand_names "A, B\[2:0\]" 1] [list A B\[2\] B\[1\] B\[0\]]
check "range split OFF -> vector"  [addlabel::expand_names "A, B\[2:0\]" 0] [list A B\[2:0\]]
# angle brackets normalise to square, always
check "angle split ON"             [addlabel::expand_names "B<2:0>" 1] [list B\[2\] B\[1\] B\[0\]]
check "angle split OFF -> vector"  [addlabel::expand_names "B<2:0>" 0] [list B\[2:0\]]
check "single angle bit"           [addlabel::expand_names "B<3>" 1] [list B\[3\]]
# range direction follows the written order
check "ascending range"            [addlabel::expand_names "B\[0:2\]" 1] [list B\[0\] B\[1\] B\[2\]]
check "wide range"                 [addlabel::expand_names "D\[3:0\]" 1] [list D\[3\] D\[2\] D\[1\] D\[0\]]
# a single bit is not a range
check "single bit passthrough"     [addlabel::expand_names "A\[2\]" 1] [list A\[2\]]
# leading-zero indices must parse as DECIMAL, not Tcl octal (review #1: 08/09 threw, 010 corrupted)
check "octal-guard 08:0 -> 9 bits"  [llength [addlabel::expand_names "A\[08:0\]" 1]] 9
check "octal-guard 08 first bit"    [lindex  [addlabel::expand_names "A\[08:0\]" 1] 0] {A[8]}
check "octal-guard 010:0 -> 11"     [addlabel::expand_names "A\[010:0\]" 1] \
      [list A\[10\] A\[9\] A\[8\] A\[7\] A\[6\] A\[5\] A\[4\] A\[3\] A\[2\] A\[1\] A\[0\]]
check "octal-guard DATA 08:00"      [addlabel::expand_names "DATA\[08:00\]" 1] \
      [list DATA\[8\] DATA\[7\] DATA\[6\] DATA\[5\] DATA\[4\] DATA\[3\] DATA\[2\] DATA\[1\] DATA\[0\]]
# pathological width is NOT expanded (review #7: no multi-million-element freeze per keystroke)
check "wide range capped -> vector" [addlabel::expand_names "A\[20000000:0\]" 1] [list A\[20000000:0\]]
check "just-over-cap -> vector"     [addlabel::expand_names "A\[5000:0\]" 1] [list A\[5000:0\]]
check "under-cap expands (4096)"    [llength [addlabel::expand_names "A\[4095:0\]" 1]] 4096

# "Split bus" checkbox defaults OFF (unchecked) -- user request 2026-07-12. The form-layer name
# consumption ("A B[2:0]" -> "B[2:0]" after dropping A) and canvas-Esc-dismisses-in-any-state
# tweaks need Tk (winfo/entry) so they are covered by scratchpad/verify_label_tweaks.tcl, not here.
check "split_bus default OFF"       $addlabel::split_bus 0

# Placement-time name validity (entry stays permissive; enforced when a name is armed to place).
check "name_ok plain"               [addlabel::name_ok A]            1
check "name_ok hier-ish base"       [addlabel::name_ok a/b.c]        1
check "name_ok vector \[\]"         [addlabel::name_ok "B\[2:0\]"]   1
check "name_ok vector <>"           [addlabel::name_ok "B<2:0>"]     1
check "name_ok single bit"          [addlabel::name_ok "B\[3\]"]     1
check "name_bad curly brace"        [addlabel::name_ok "B{2:0\]"]    0
check "name_bad semicolon"          [addlabel::name_ok "C\[2;0\]"]   0
check "name_bad unclosed"           [addlabel::name_ok "B\[2:0"]     0
check "name_bad stray close"        [addlabel::name_ok "B\]"]        0
check "name_bad nameless range"     [addlabel::name_ok "\[2:0\]"]    0
check "name_bad empty"              [addlabel::name_ok ""]           0

# ---------------------------------------------------------------------------
# B. Placement predicate: point_on_wire_or_pin -> `xschem net_at x y`.
#    A wire 0,0-100,0 and a lab_pin instance-pin at 200,0.
# ---------------------------------------------------------------------------
xschem clear force
xschem wire 0 0 100 0
xschem instance [find_file_first lab_pin.sym] 200 0 0 0 {name=l1 lab=Z}
xschem unselect_all
check "net_at on wire"             [xschem net_at 50 0]   1
check "net_at wire endpoint"       [xschem net_at 100 0]  1
check "net_at on instance pin"     [xschem net_at 200 0]  1
check "net_at off copper"          [xschem net_at 50 50]  0

# the SELECTED preview must not satisfy the constraint against itself
xschem clear force
set ::label_new_name P
xschem add_wire_label -place
xschem move_objects step 300 300
check "preview armed"              [placing] 1
check "net_at skips selected preview" [xschem net_at 300 300] 0
xschem abort_operation
check "abort clears preview"       [placing] 0

# ---------------------------------------------------------------------------
# C. Constrained drop: commit ON copper, refuse OFF copper.
# ---------------------------------------------------------------------------
xschem clear force
xschem wire 0 0 100 0
xschem unselect_all
set ::label_new_name FOO
xschem add_wire_label -place
check "arm places one preview inst" [xschem get instances] 1
set r [xschem add_wire_label -drop 50 0]
check "drop on wire -> committed (ret 1)" $r 1
check "drop on wire -> not placing"       [placing] 0
check "committed label is lab_pin"        [string match {*lab_pin.sym} [inst_sym 0]] 1
check "committed label lab=FOO"           [inst_lab 0] FOO
check "one instance after commit"         [xschem get instances] 1

set ::label_new_name BAR
xschem add_wire_label -place
check "second preview armed"        [placing] 1
set r [xschem add_wire_label -drop 40 40]
check "drop off copper -> refused (ret 0)" $r 0
check "refused drop stays armed"          [placing] 1
check "refused drop commits nothing"      [xschem get instances] 2 ;# FOO + live preview
xschem abort_operation
check "abort drops the preview"           [xschem get instances] 1

# ---------------------------------------------------------------------------
# D. Bindings: edit.add_wire_label real+default-bound to 'l';
#    tools.insert_line default-bound to Shift+L (key 'L').
# ---------------------------------------------------------------------------
set dump [xschem bindings dump]
check "add_wire_label default-bound" \
  [expr {[lsearch -exact $dump {key 108 0 canvas edit.add_wire_label idle}] >= 0}] 1
check "bind edit.add_wire_label ok"  [catch {xschem bind key 108 0 canvas edit.add_wire_label}] 0
check "insert_line on Shift+L" \
  [expr {[lsearch -glob $dump {key 76 0 canvas tools.insert_line*}] >= 0}] 1

# ---------------------------------------------------------------------------
# E. wirelabel_preview invariant (review #5): arming a PIN preview over a live LABEL preview must
#    NOT leak the drop-on-copper gate onto the pin. Observe via -drop: if the flag were leaked,
#    add_wire_label -drop ON copper would COMMIT the pin through the label path (ret 1, placing 0);
#    with the flag correctly cleared by add_sch_pin -place, the gate declines (ret 0, still placing).
# ---------------------------------------------------------------------------
xschem clear force
xschem wire 0 0 100 0
xschem unselect_all
set ::label_new_name LBL
xschem add_wire_label -place            ;# label preview armed (wirelabel_preview=1)
set ::pin_new_name PP; set ::pin_new_dir in
xschem add_sch_pin -place               ;# re-arm as a PIN -> must clear wirelabel_preview
set r [xschem add_wire_label -drop 50 0]
check "pin arm clears label gate (ret 0)"  $r 0
check "pin preview still armed"            [placing] 1
xschem abort_operation

# clear_drawing() also clears the flag (review #4): a torn-down label preview must not hijack
# the next document. Arm a label, tear the document down, rebuild, arm a pin, drop on copper.
xschem clear force
set ::label_new_name GONE
xschem add_wire_label -place            ;# armed, wirelabel_preview=1
xschem clear force                      ;# clear_drawing() must zero wirelabel_preview
xschem wire 0 0 100 0
xschem unselect_all
set ::pin_new_name QQ; set ::pin_new_dir in
xschem add_sch_pin -place
set r [xschem add_wire_label -drop 50 0]
check "clear_drawing clears label gate"    $r 0
xschem abort_operation

# ---------------------------------------------------------------------------
# G. Issue 0230: `l` pressed while a WIRE DRAW is still live (two modal gestures armed at once).
#    Two independent fixes, two disjoint red sets:
#      G1/G3 -- arming the label ABORTS the live wire/line draw (scheduler add_wire_label gate);
#      G2    -- abort_operation() tears down a co-armed placement preview instead of returning
#               early with `ui_state = 0` (which orphaned sympin_preview/wirelabel_preview and
#               left the preview instance committed -> the unrecoverable state of the report).
#    `getq` tolerates a missing getter so a pre-fix binary reports FAIL, not a script abort.
# ---------------------------------------------------------------------------
proc getq {k} { if {[catch {xschem get $k} r]} { return ? } ; return $r }
proc startwire {} { return [expr {([xschem get ui_state] & 1) ? 1 : 0}] }
set saved_infix $::infix_interface
set ::infix_interface 1   ;# `xschem wire gui` then arms a real STARTWIRE draw, headless

# G1 -- arming a net label while a wire draw is live: the wire gesture is abandoned (nothing
#       committed), the label preview arms cleanly, and it can still be dropped on copper.
xschem clear force
xschem wire 0 0 100 0
xschem unselect_all
xschem wire gui
check "0230 wire draw armed"               [startwire] 1
check "0230 wire draw owns last_command"   [getq last_command] 1
set ::label_new_name FOO
xschem add_wire_label -place
check "0230 arm label clears STARTWIRE"    [startwire] 0
check "0230 arm label clears last_command" [getq last_command] 0
check "0230 label preview armed"           [placing] 1
check "0230 aborted wire committed none"   [xschem get wires] 1
check "0230 drop on copper after clash"    [xschem add_wire_label -drop 50 0] 1
check "0230 drop clears placing"           [placing] 0
check "0230 drop leaves preview clean"     [getq sympin_preview] 0
check "0230 one label committed"           [xschem get instances] 1

# G2 -- ESC with BOTH armed. abort_operation() must tear the placement down instead of returning
#       early with `ui_state = 0`. Pre-fix: ui_state=0 with sympin_preview=1 and the lab_pin left
#       in the drawing forever.
#       CONSTRUCTOR NOTE (issue 0233): this used to be built with `add_wire_label -place` then
#       `xschem wire gui`. Both halves of that are now gated -- F1 makes the label arm abandon the
#       wire, F2 makes the wire arm abandon the label -- so the co-armed state is no longer
#       reachable from either verb, which is the whole point of 0233. It IS still reachable
#       through the forward doors 0233 F1 left ungated (issue 0237), of which `net_label 0`
#       (Alt+Shift+L, place a lab_wire label) is one: it arms a cursor placement
#       (START_SYMPIN|STARTMOVE) with a real preview INSTANCE on top of a live wire draw, without
#       leaving wire mode. Rebuilt on that, so this section keeps testing abort_operation()'s
#       co-armed teardown -- its only coverage -- for as long as any such door exists. Do not use
#       `add_graph` here: its preview is a rect, not an instance, which would make the
#       "deletes preview instance" check below vacuous (0==0 before and after).
#       `net_label` sets no sympin_preview, so that flag's teardown is asserted where it is real:
#       section E of tests/headless/test_placement_wire_gate.tcl, on the F2 path.
#       CONSTRUCTOR NOTE #2 (phases 1-2 of plan_modal_gesture_exclusion.md, 2026-08-08): `net_label`
#       was the LAST open forward door and it is now gated too, so no verb builds the co-armed
#       state any more. Rather than rebuild this constructor a fourth time on a door that will also
#       close, it now uses the test-only seam `xschem test_gate_bypass` (scheduler.c) -- bracketed
#       tightly around the ARM only, so the ESC under test still runs with every gate live. The
#       seam itself is pinned by section H of test_placement_wire_gate.tcl (default off, and
#       flipping it really does disable a gate).
xschem clear force
xschem wire 0 0 100 0
xschem unselect_all
xschem wire gui
xschem test_gate_bypass 1 ; xschem net_label 0 ; xschem test_gate_bypass 0
check "0230 both gestures armed"           [expr {[startwire] && [placing]}] 1
check "0230 preview instance is live"      [xschem get instances] 1
xschem abort_operation
check "0230 ESC clears START_SYMPIN"       [placing] 0
check "0230 ESC deletes preview instance"  [xschem get instances] 0
check "0230 ESC clears STARTWIRE"          [startwire] 0
check "0230 ESC leaves nothing selected"   [xschem get lastsel] 0
check "0230 ESC keeps wire command mode"   [getq last_command] 1
xschem abort_operation
check "0230 second ESC leaves wire mode"   [getq last_command] 0

# G3 -- the plain wire draw is untouched: two-stage ESC (commit a797bc59) still ends the
#       segment first and the wire COMMAND mode only on the second press.
xschem clear force
xschem wire gui
check "0230 plain wire armed"              [startwire] 1
xschem abort_operation
check "0230 plain wire: ESC ends segment"  [startwire] 0
check "0230 plain wire: mode survives"     [getq last_command] 1
xschem abort_operation
check "0230 plain wire: 2nd ESC exits"     [getq last_command] 0
check "0230 plain wire: nothing committed" [xschem get wires] 0

# G4 -- the RESTING wire command mode: the segment is finished (`ui_state` has no STARTWIRE) but
#       `last_command` still owns the next click. This is what a user sees after ending a segment
#       with a double-click -- the diamond snap cursor is still up. With `persistent_command 1`
#       (cadence_style_rc:60) callback.c:7828 seizes the next press and calls start_wire() BEFORE
#       any placement can be offered the click, so a label armed in this state can never be
#       dropped: the click starts a new wire and the preview keeps riding the cursor.
#       Reached here by the two-stage ESC, which is exactly the same resting state (G3 pins it).
xschem clear force
xschem wire 0 0 100 0
xschem unselect_all
xschem wire gui
xschem abort_operation                     ;# segment over, wire COMMAND mode still armed
check "0230 resting: no STARTWIRE"          [startwire] 0
check "0230 resting: wire mode still armed" [getq last_command] 1
set ::label_new_name RST
xschem add_wire_label -place
check "0230 resting: arm label leaves mode" [getq last_command] 0
check "0230 resting: preview armed"         [placing] 1
check "0230 resting: drop commits"          [xschem add_wire_label -drop 50 0] 1
check "0230 resting: no wire committed"     [xschem get wires] 1

set ::infix_interface $saved_infix

# ---------------------------------------------------------------------------
# F. Symbol-view guard (review #6): in a .sym view add_wire_label -place is a no-op -- it must NOT
#    push an undo baseline or wipe the selection (place_symbol refuses instances there anyway).
# ---------------------------------------------------------------------------
source [file join [file dirname [info script]] scratch.tcl]
set symf [file join [test_scratch awl_sym] awl.sym]
set fh [open $symf w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}"; puts $fh "K {type=subcircuit}"; puts $fh "V {}"; puts $fh "S {}"; puts $fh "E {}"
puts $fh "L 4 -10 -10 10 -10 {}"
close $fh
xschem load $symf
check "loaded a symbol view" [string match {*.sym} [xschem get current_name]] 1
xschem select_all
set nsel [xschem get lastsel]
check "symbol view: something selected" [expr {$nsel > 0}] 1
xschem add_wire_label -place
check "symbol view: add_wire_label no-op (selection kept)" [xschem get lastsel] $nsel
check "symbol view: not placing"                          [placing] 0
catch {file delete -force $symf}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
