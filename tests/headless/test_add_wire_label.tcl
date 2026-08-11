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
# G. Issue 0240: `l` pressed while a WIRE DRAW is still live (two modal gestures armed at once).
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
check "0240 wire draw armed"               [startwire] 1
check "0240 wire draw owns last_command"   [getq last_command] 1
set ::label_new_name FOO
xschem add_wire_label -place
check "0240 arm label clears STARTWIRE"    [startwire] 0
check "0240 arm label clears last_command" [getq last_command] 0
check "0240 label preview armed"           [placing] 1
check "0240 aborted wire committed none"   [xschem get wires] 1
check "0240 drop on copper after clash"    [xschem add_wire_label -drop 50 0] 1
check "0240 drop clears placing"           [placing] 0
check "0240 drop leaves preview clean"     [getq sympin_preview] 0
check "0240 one label committed"           [xschem get instances] 1

# G2 -- ESC with BOTH armed. abort_operation() must tear the placement down instead of returning
#       early with `ui_state = 0`. Pre-fix: ui_state=0 with sympin_preview=1 and the lab_pin left
#       in the drawing forever.
#       CONSTRUCTOR NOTE (issue 0243): this used to be built with `add_wire_label -place` then
#       `xschem wire gui`. Both halves of that are now gated -- F1 makes the label arm abandon the
#       wire, F2 makes the wire arm abandon the label -- so the co-armed state is no longer
#       reachable from either verb, which is the whole point of 0243. It IS still reachable
#       through the forward doors 0243 F1 left ungated (issue 0247), of which `net_label 0`
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
check "0240 both gestures armed"           [expr {[startwire] && [placing]}] 1
check "0240 preview instance is live"      [xschem get instances] 1
xschem abort_operation
check "0240 ESC clears START_SYMPIN"       [placing] 0
check "0240 ESC deletes preview instance"  [xschem get instances] 0
check "0240 ESC clears STARTWIRE"          [startwire] 0
check "0240 ESC leaves nothing selected"   [xschem get lastsel] 0
check "0240 ESC keeps wire command mode"   [getq last_command] 1
xschem abort_operation
check "0240 second ESC leaves wire mode"   [getq last_command] 0

# G3 -- the plain wire draw is untouched: two-stage ESC (commit a797bc59) still ends the
#       segment first and the wire COMMAND mode only on the second press.
xschem clear force
xschem wire gui
check "0240 plain wire armed"              [startwire] 1
xschem abort_operation
check "0240 plain wire: ESC ends segment"  [startwire] 0
check "0240 plain wire: mode survives"     [getq last_command] 1
xschem abort_operation
check "0240 plain wire: 2nd ESC exits"     [getq last_command] 0
check "0240 plain wire: nothing committed" [xschem get wires] 0

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
check "0240 resting: no STARTWIRE"          [startwire] 0
check "0240 resting: wire mode still armed" [getq last_command] 1
set ::label_new_name RST
xschem add_wire_label -place
check "0240 resting: arm label leaves mode" [getq last_command] 0
check "0240 resting: preview armed"         [placing] 1
check "0240 resting: drop commits"          [xschem add_wire_label -drop 50 0] 1
check "0240 resting: no wire committed"     [xschem get wires] 1

set ::infix_interface $saved_infix

# ---------------------------------------------------------------------------
# H. Issue 0241 -- a cancelled placement deletes THE PREVIEW, not "whatever is selected".
#
#    abort_placement_preview() (callback.c) removes the preview with delete(), which is
#    SELECTION-scoped. The "selection == preview" invariant holds only at the ARM; anything that
#    grows the selection afterwards -- Ctrl+A, select_dangling_nets, Edit>Select all -- turns the
#    cancel into a whole-document delete, and set_modify(save) then reports the empty schematic
#    UNMODIFIED, so it closes without a prompt. Measured before the fix: 1 wire + 1 instance ->
#    wires=0 inst=0 modified=0.
#
#    THREE cancel doors are covered, not one:
#      H1/H2  ESC / form-close       -> abort_placement_preview()
#      H3     the modeless form's own KEYSTROKE (a re-arm drops the previous preview with
#             delete(0) at scheduler.c) -- this door needs no ESC at all and was not in the
#             issue's original repro
#      H4     a wire/line verb on a live preview -> leave_placement_for(), whose 0241 decline
#             guard this fix removes (its replacement is section E7 of
#             tests/headless/test_placement_wire_gate.tcl)
#
#    NOT HOLLOW (WIRING.md §10): the fixture deliberately holds one object of EVERY type the
#    previews use -- 2 wires, 1 instance, 1 text, 1 line -- so "instances == 1" after cancelling
#    an INSTANCE preview, and "texts == 1" after cancelling the rect+text Add-Pin preview, can
#    only pass if the survivors really survived. rects/lines/polygons/arcs have no `xschem get`
#    counter, so survival of the line is proved by counting saved record lines (TRAP 3).
# ---------------------------------------------------------------------------
source [file join [file dirname [info script]] scratch.tcl]
set d0241 [test_scratch i0241]
set f0241 [file join $d0241 doc.sch]

# every object type a placement preview can be made of, plus survivors of the same type
proc doc0241 {} {
  xschem clear force
  xschem wire 0 0 100 0
  xschem wire 200 0 300 0
  xschem instance devices/lab_pin.sym 300 0 0 0 {name=p1 lab=AAA}
  xschem text 400 400 0 0 {SURVIVOR} {} 0.4 0
  xschem line 0 200 100 200
  xschem unselect_all
  xschem saveas $::f0241
  xschem load $::f0241          ;# modified == 0, like a freshly opened drawing
}
# object-record lines of the CURRENT drawing (N wire, C instance, T text, L line, B rect,
# P poly, A arc) -- the only way to prove rect/line/poly/arc survival headlessly. Destructive to
# `modified` (it saves), so always call it AFTER reading the modify flag.
proc rec0241 {} {
  set f [file join $::d0241 snap.sch]
  xschem saveas $f
  set fh [open $f r]; set data [read $fh]; close $fh
  set n 0
  foreach ln [split $data \n] { if {[regexp {^[NCTLBPA] } $ln]} { incr n } }
  return $n
}
proc labcount0241 {lab} {
  set n 0
  for {set i 0} {$i < [xschem get instances]} {incr i} {
    if {[inst_lab $i] eq $lab} { incr n }
  }
  return $n
}
proc placing_any0241 {} { return [expr {([xschem get ui_state] & 25600) ? 1 : 0}] }

doc0241
set REC0241 [rec0241]                       ;# 2 wires + 1 inst + 1 text + 1 line = 5 records
xschem load $f0241
check "0241 fixture: 2 wires"            [xschem get wires] 2
check "0241 fixture: 1 instance"         [xschem get instances] 1
check "0241 fixture: 1 text"             [xschem get texts] 1
check "0241 fixture: 5 object records"   $REC0241 5

# H1 -- every placement arm, cancelled by ESC after Ctrl+A, leaves the drawing untouched.
#       `armv` is the verb, `pv` the extra objects its preview adds (instances/texts) so the
#       "preview really was live" pre-check cannot be satisfied by an arm that did nothing.
set ::label_new_name L0241
set ::pin_new_name   P0241
set ::pin_new_dir    inout
foreach {tag armv} {
  wirelabel {xschem add_wire_label -place}
  schpin    {xschem add_sch_pin -place}
  sympin    {xschem add_symbol_pin -place}
  placesym  {xschem place_symbol devices/lab_pin.sym}
  netlabel  {xschem net_label 0}
} {
  doc0241
  set m0 [xschem get modified]
  eval $armv
  check "0241 H1 $tag: preview armed"        [placing_any0241] 1
  xschem select_all
  check "0241 H1 $tag: selection grown"      [expr {[xschem get lastsel] > 1}] 1
  xschem abort_operation
  check "0241 H1 $tag: wires survive"        [xschem get wires] 2
  check "0241 H1 $tag: instance survives"    [xschem get instances] 1
  check "0241 H1 $tag: text survives"        [xschem get texts] 1
  check "0241 H1 $tag: preview gone"         [labcount0241 L0241] 0
  check "0241 H1 $tag: not placing"          [placing_any0241] 0
  check "0241 H1 $tag: sympin_preview clear" [xschem get sympin_preview] 0
  # DELIBERATE, not a side effect of the narrowing: the cancel DESELECTS the user's other
  # objects but does not delete them. Narrowing made "ESC keeps my selection" newly possible;
  # it was NOT taken, because section G2 (`0240 ESC leaves nothing selected`) already ratified
  # lastsel 0 on this path and changing it is a separate, user-facing decision. See issue 0241.
  check "0241 H1 $tag: nothing left selected" [xschem get lastsel] 0
  check "0241 H1 $tag: modify flag kept"     [xschem get modified] $m0
  check "0241 H1 $tag: all records survive"  [rec0241] $REC0241
}

# H2 -- the grower is not Ctrl+A: select_dangling_nets reproduces it identically (the issue is
#       "the selection grew", not "select_all ran"), so the fix must not be a select_all veto.
doc0241
set m0 [xschem get modified]
xschem add_wire_label -place
xschem select_dangling_nets
check "0241 H2 dangling: selection grown"  [expr {[xschem get lastsel] > 1}] 1
xschem abort_operation
check "0241 H2 dangling: wires survive"    [xschem get wires] 2
check "0241 H2 dangling: instance survives" [xschem get instances] 1
check "0241 H2 dangling: text survives"    [xschem get texts] 1
check "0241 H2 dangling: preview gone"     [labcount0241 L0241] 0
check "0241 H2 dangling: modify flag kept" [xschem get modified] $m0
check "0241 H2 dangling: records survive"  [rec0241] $REC0241

# H3 -- the door with NO cancel key in it. The Add-Label / Add-Pin forms are modeless and re-issue
#       `-place` on every keystroke; the re-arm drops the previous preview with delete(0)
#       (scheduler.c). Pre-fix that delete took the grown selection too, so merely TYPING in the
#       form after a Ctrl+A wiped the drawing -- measured wires=0 inst=1 (only the new preview).
doc0241
set m0 [xschem get modified]
xschem add_wire_label -place
xschem select_all
set ::label_new_name L0241B
xschem add_wire_label -place                ;# the next keystroke
check "0241 H3 rearm: wires survive"       [xschem get wires] 2
check "0241 H3 rearm: fixture inst kept"   [expr {[labcount0241 AAA] == 1}] 1
check "0241 H3 rearm: text survives"       [xschem get texts] 1
check "0241 H3 rearm: old preview gone"    [labcount0241 L0241] 0
check "0241 H3 rearm: new preview live"    [labcount0241 L0241B] 1
check "0241 H3 rearm: still placing"       [placing_any0241] 1
xschem abort_operation
check "0241 H3 rearm: ESC clears it"       [labcount0241 L0241B] 0
check "0241 H3 rearm: modify flag kept"    [xschem get modified] $m0
check "0241 H3 rearm: records survive"     [rec0241] $REC0241
set ::label_new_name L0241

# H4 -- the wire verb on a live preview + a multiple selection. Before the fix
#       leave_placement_for() DECLINED here (it refused to hand delete() to `w`); with the delete
#       narrowed it must proceed: preview torn down, draw armed, and the other selected objects
#       still there. Full coverage of the three wire/line arms is E7 of test_placement_wire_gate.
set saved_infix $::infix_interface
set ::infix_interface 1
doc0241
xschem add_wire_label -place
xschem select_all
xschem wire gui
check "0241 H4 wire verb: proceeded"       [placing_any0241] 0
check "0241 H4 wire verb: draw armed"      [expr {([xschem get ui_state] & 1) ? 1 : 0}] 1
check "0241 H4 wire verb: wires survive"   [xschem get wires] 2
check "0241 H4 wire verb: instance kept"   [expr {[labcount0241 AAA] == 1}] 1
check "0241 H4 wire verb: text survives"   [xschem get texts] 1
check "0241 H4 wire verb: preview gone"    [labcount0241 L0241] 0
xschem abort_operation ; xschem abort_operation
set ::infix_interface $saved_infix

# H5 CONTROL -- with NOTHING but the preview selected the cancel behaves exactly as it always did.
#       This is the check that would go red if the narrowing over-corrected into a no-op delete.
doc0241
xschem add_wire_label -place
check "0241 H5 control: one selected"      [xschem get lastsel] 1
xschem abort_operation
check "0241 H5 control: preview removed"   [labcount0241 L0241] 0
check "0241 H5 control: nothing else lost" [expr {[xschem get wires]==2 && [xschem get instances]==1 && [xschem get texts]==1}] 1

# H6 CONTROL -- a plain move (STARTMOVE with no placement bit) has no teardown at all: ESC after a
#       Ctrl+A must not delete anything. Bounds the scope of the narrowing.
doc0241
xschem select_all
xschem move_objects
xschem select_all
xschem abort_operation
check "0241 H6 control: plain move intact" [expr {[xschem get wires]==2 && [xschem get instances]==1 && [xschem get texts]==1}] 1

# H7 -- PARTIAL selections must survive, because delete() would never have taken them.
#       rebuild_selected_array() admits any non-zero `sel`, but delete() removes only
#       `sel == SELECTED` exactly; a stretch box-select marks a wire SELECTED1/SELECTED2 (one
#       ENDPOINT grabbed) and delete() is a provable no-op on it. select_placement_preview()
#       re-selects with SELECTED, so an unfiltered stamp would PROMOTE those wires and make the
#       "narrowing" delete objects the UNNARROWED code left standing -- silently, since
#       set_modify(save) restores the clean flag. Measured before the filter: 3 stretch-selected
#       wires + `net_label 0` + `w` -> 0 wires. Found by the adversarial review of the 0241 fix.
#       The arm used here is `net_label 0` with lab_wire.sym made unresolvable, because
#       place_symbol() then bails BEFORE its own unselect_all() while place_net_label() arms
#       anyway -- the same "arm keeps the user's pre-existing selection" state the `t` /
#       context-menu-6 / screen-grab arms are in by design and that no headless path can reach.
rename find_file_first find_file_first_orig0241
proc find_file_first {f {paths {}} {maxdepth -1}} { return "" }
set saved_stretch [xschem get enable_stretch]
xschem set enable_stretch 1
xschem clear force
xschem wire 0 0 100 0 ; xschem wire 0 100 100 100 ; xschem wire 0 200 100 200
xschem unselect_all
xschem select_inside -10 -10 10 210          ;# grabs ONE endpoint of each -> 3 PARTIAL wires
check "0241 H7 partial: three grabbed"     [xschem get lastsel] 3
# CONTROL, and the whole premise of this section: an ordinary delete() on this selection is a
# NO-OP, because delete() tests `sel == SELECTED` and these are SELECTED1/SELECTED2. If this ever
# goes red the section is testing nothing -- the wires would be deletable and their survival
# after the cancel would prove no scoping at all.
xschem delete
check "0241 H7 control: plain delete no-op" [xschem get wires] 3
xschem unselect_all
xschem select_inside -10 -10 10 210
xschem net_label 0                           ;# arms with the partial selection still live
check "0241 H7 partial: armed"             [placing_any0241] 1
xschem wire gui
check "0241 H7 partial: wires survive"     [xschem get wires] 3
xschem abort_operation ; xschem abort_operation
# and on the ESC door too
xschem clear force
xschem wire 0 0 100 0 ; xschem wire 0 100 100 100 ; xschem wire 0 200 100 200
xschem unselect_all
xschem select_inside -10 -10 10 210
xschem net_label 0
xschem abort_operation
check "0241 H7 partial: ESC keeps them"    [xschem get wires] 3
rename find_file_first {}
rename find_file_first_orig0241 find_file_first
xschem set enable_stretch $saved_stretch

xschem clear force
catch {file delete -force $f0241}

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

# ---------------------------------------------------------------------------
# L. Issue 0245 -- canvas Escape must reach the C Escape terminal even while this form owns
#    the `.drw <Key-Escape>` slot. addlabel::grab_esc points that slot at addlabel::escape,
#    which is `set armed 0; abort_if_placing; destroy` -- and abort_if_placing only fires
#    when START_SYMPIN is set. With the form IDLE the whole Escape is a `destroy` plus a
#    variable write, so the sixteen lines of callback.c's `case XK_Escape:` never run.
#    Measured under xvfb: `xschem wire` (ui=65536 ui2=1), canvas Escape with an idle
#    .addlabel open -> ui/ui2/last_command BYTE-IDENTICAL and the form gone; the NEXT canvas
#    click took ui to 65537 and last_command to 1 -- an unrequested wire draw begun by the
#    click the user made to dismiss a dialog. Only a SECOND Escape aborted it.
#    The fix routes the CANVAS Escape (and only the canvas one) through a new
#    addlabel::canvas_escape that ends at `xschem escape`, the named C terminal.
#    Headless-safe: with no Tk the inner `catch {destroy .addlabel}` is a no-op, so these
#    rows test the FORWARD, not the widget.
# ---------------------------------------------------------------------------
xschem clear force ; xschem abort_operation ; xschem abort_operation
xschem wire
check "L0 precondition: menu wire armed"   [xschem get ui_state] 65536
catch {addlabel::canvas_escape}
check "L1 canvas Escape aborts the arm"    [xschem get ui_state] 0
check "L2 canvas Escape clears ui_state2"  [xschem get ui_state2] 0
xschem abort_operation

# L3 CONTRAST -- the Close BUTTON (-command addlabel::escape) is a mouse click, not the
#    Escape key, and must gain nothing here: clicking Close must not stop a running
#    simulation or abort an unrelated armed gesture. GREEN before the fix and after.
#    NOTE the form-focused <Key-Escape> is NOT in this contrast any more -- it fires
#    addlabel::canvas_escape and DOES reach the terminal. It had to: Tk routes keys to
#    `[focus]`, open() focuses the form, so that binding is the one a user's Escape hits
#    until they click the canvas. See test_create_instance.tcl CI15a.
xschem clear force ; xschem abort_operation ; xschem abort_operation
xschem wire
catch {addlabel::escape}
check "L3 contrast: Close button leaves the arm" [xschem get ui_state] 65536
xschem abort_operation ; xschem abort_operation

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
