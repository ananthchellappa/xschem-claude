# RED-first regression: entering a modal PLACEMENT leaves wire/line draw mode.
#
# Issue 0230 established the policy for `l` (Add Wire Label) and the reason it is not optional:
# end_place_move_copy_zoom() tests STARTWIRE BEFORE the placement arm, so while a wire draw is
# live every click feeds the wire and the placement can never be dropped -- and under
# `persistent_command` (cadence_style_rc) the press handler seizes the click even in the RESTING
# command mode, where ui_state has no STARTWIRE at all and only last_command is armed.
# Issue 0233 measured the same clash on the other twelve placement arms. This file covers the two
# the user ratified on 2026-08-07: `p` (Add Pin, schematic and symbol view) and component insert
# (`place_symbol`, i.e. the toolbar / library-manager / context-menu route).
#
# "Wire-draw mode" is THREE states and each verb is checked against all three:
#   LIVE     ui_state & STARTWIRE          -- first vertex placed, rubber band up
#   MENU     MENUSTART + MENUSTARTWIRE     -- armed from the menu, first click not landed
#   RESTING  ui_state clear, last_command  -- segment ended by double-click, diamond cursor up
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_placement_wire_gate.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc ui {}        { return [xschem get ui_state] }
proc bit {b}      { return [expr {([ui] & $b) ? 1 : 0}] }
proc startwire {} { return [bit 1] }
proc startline {} { return [bit 4] }
proc placing {}   { return [bit 16384] }      ;# START_SYMPIN
proc placesym {}  { return [bit 8192] }       ;# PLACE_SYMBOL
proc menuwire {}  { return [expr {([ui] & 65536) && ([xschem get ui_state2] & 1) ? 1 : 0}] }
proc startrect {} { return [bit 2] }          ;# STARTRECT
proc menustart {} { return [bit 65536] }      ;# MENUSTART
proc lc {}        { return [xschem get last_command] }
proc reset {} {
  xschem abort_operation ; xschem abort_operation
  xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
}

set saved_infix $::infix_interface
set ::pin_new_name PG ; set ::pin_new_dir in

# ---------------------------------------------------------------------------
# A. `p` (add_sch_pin) -- the schematic Add-Pin form
# ---------------------------------------------------------------------------
set ::infix_interface 1
reset ; xschem wire gui                       ;# LIVE draw
check "A1 live: STARTWIRE armed"         [startwire] 1
xschem add_sch_pin -place
check "A1 live: p clears STARTWIRE"      [startwire] 0
check "A1 live: p clears wire mode"      [lc] 0
check "A1 live: pin preview armed"       [placing] 1
check "A1 live: nothing committed"       [xschem get wires] 1

reset ; xschem wire gui ; xschem abort_operation   ;# RESTING (two-stage ESC = post double-click)
check "A2 resting: no STARTWIRE"         [startwire] 0
check "A2 resting: wire mode armed"      [lc] 1
xschem add_sch_pin -place
check "A2 resting: p clears wire mode"   [lc] 0
check "A2 resting: pin preview armed"    [placing] 1

set ::infix_interface 0
reset ; xschem wire                            ;# MENU-armed, first click not landed
check "A3 menu: menu wire armed"         [menuwire] 1
xschem add_sch_pin -place
check "A3 menu: p clears the menu arm"   [menuwire] 0
check "A3 menu: pin preview armed"       [placing] 1
set ::infix_interface 1

# ---------------------------------------------------------------------------
# B. component insert (`place_symbol`) -- toolbar / library manager / ctx menu
# ---------------------------------------------------------------------------
set sym [find_file_first lab_pin.sym]
reset ; xschem wire gui
xschem place_symbol $sym
check "B1 live: insert clears STARTWIRE" [startwire] 0
check "B1 live: insert clears wire mode" [lc] 0
check "B1 live: PLACE_SYMBOL armed"      [placesym] 1
check "B1 live: nothing committed"       [xschem get wires] 1

reset ; xschem wire gui ; xschem abort_operation
xschem place_symbol $sym
check "B2 resting: insert clears mode"   [lc] 0
check "B2 resting: PLACE_SYMBOL armed"   [placesym] 1

set ::infix_interface 0
reset ; xschem wire
xschem place_symbol $sym
check "B3 menu: insert clears menu arm"  [menuwire] 0
check "B3 menu: PLACE_SYMBOL armed"      [placesym] 1
set ::infix_interface 1
xschem abort_operation

# ---------------------------------------------------------------------------
# D. issue 0233 F3 -- ESC must not leak shape-draw bits past the STARTMOVE return.
#
# abort_operation() returns at callback.c:406 after tearing a placement down, and that
# return skips the `ui_state = 0` at the bottom. Every gesture bit whose only sink was
# that assignment (STARTRECT, MENUSTART, ...) therefore SURVIVES the ESC, and
# redraw_w_a_l_r_p_z_rubbers() re-strokes the band on the next motion with nothing left
# to erase it -- the reported "grey lines of the same dimensions as the wire" symptom.
# STARTWIRE|STARTLINE leak by a second route: the `xctx->last_command &&` conjunct at
# :351 is false for arms that zero last_command (rect/polygon/text/place_symbol), so the
# rubber CLEAR and the `ui_state &= ~(STARTWIRE|STARTLINE)` at :375 never run either.
# ---------------------------------------------------------------------------
set ::infix_interface 1

# D1 -- STARTRECT residue: pins the flag mask added above the :406 return.
reset ; xschem add_sch_pin -place ; xschem rect gui
check "D1 armed: placement + rect"       [expr {[placing] && [startrect]}] 1
check "D1 armed: last_command zeroed"    [lc] 0
xschem abort_operation
check "D1 ESC clears STARTRECT"          [startrect] 0
check "D1 ESC clears ui_state"           [ui] 0
check "D1 ESC tore down the preview"     [placing] 0
check "D1 ESC dropped sympin_preview"    [xschem get sympin_preview] 0
check "D1 ESC deleted preview instance"  [xschem get instances] 0
check "D1 ESC committed no rect"         [xschem get rects 4] 0

# D2 -- MENUSTART residue: the same return, on a bit the issue's fix sketch omits.
reset ; xschem add_sch_pin -place
set ::infix_interface 0 ; xschem rect ; set ::infix_interface 1
check "D2 armed: placement + menu rect"  [expr {[placing] && [menustart]}] 1
xschem abort_operation
check "D2 ESC clears MENUSTART"          [menustart] 0
check "D2 ESC clears ui_state"           [ui] 0

# D3 -- STARTWIRE residue: pins the dropped `last_command &&` conjunct at :351.
#   Constructor deliberately uses `add_graph`, one of the forward doors issue 0233 F1
#   left ungated (it arms a placement on top of a live wire draw without leaving wire
#   mode). It is NOT the F2 reverse door, so this leg survives F2 gating `w`.
reset ; xschem wire gui ; xschem add_graph ; xschem rect gui
check "D3 armed: wire+rect+placement, lc==0" \
      [expr {[startwire] && [startrect] && [placing] && [lc]==0}] 1
xschem abort_operation
check "D3 ESC clears STARTWIRE"          [startwire] 0

# D4 CONTROL -- the two-stage ESC of commit a797bc59 on a bare wire draw is untouched:
#   first ESC ends the draw but KEEPS persistent wire command mode, second one leaves it.
reset ; xschem wire gui
check "D4 control: plain draw arms mode" [lc] 1
xschem abort_operation
check "D4 control: 1st ESC keeps mode"   [lc] 1
check "D4 control: 1st ESC clears ui"    [ui] 0
xschem abort_operation
check "D4 control: 2nd ESC leaves mode"  [lc] 0

# D5 CONTROL -- a placement with no draw under it aborts exactly as before.
reset ; xschem add_sch_pin -place
xschem abort_operation
check "D5 control: p alone, ESC clean"   [ui] 0
check "D5 control: preview deleted"      [xschem get instances] 0

# D6 -- with the conjunct dropped, a live draw with last_command == 0 and NO placement
#   must still fall through to unselect_all()/draw() instead of returning early.
reset ; xschem select_all
check "D6 armed: something selected"     [expr {[xschem get lastsel] > 0}] 1
xschem wire gui ; xschem rect gui
check "D6 armed: lc==0, no placement"    [expr {[lc]==0 && [placing]==0}] 1
xschem abort_operation
check "D6 ESC still deselects"           [xschem get lastsel] 0
check "D6 ESC clears ui_state"           [ui] 0

# D7 -- the OTHER early returns owe the same debt. abort_operation() has three (DESEL_MODE,
#    STARTMOVE, STARTCOPY); each skips the `ui_state = 0` at the bottom, so each must clear the
#    orphan gesture bits by hand. DESEL_MODE is the one reachable headlessly; STARTCOPY needs
#    copy_objects(START), which has no scriptable seam (its guard is code-shared with STARTMOVE).
reset ; xschem select_all ; xschem deselect_mode
xschem rect gui
check "D7 armed: desel mode + rect"      [expr {[startrect] && ([ui] & 4194304) ? 1 : 0}] 1
xschem abort_operation
check "D7 ESC clears STARTRECT"          [startrect] 0
check "D7 ESC left the mode"             [expr {([ui] & 4194304) ? 1 : 0}] 0
check "D7 ESC kept the selection"        [expr {[xschem get lastsel] > 0}] 1

# ---------------------------------------------------------------------------
# C. `p` in a SYMBOL view (add_symbol_pin) -- there the modal draw is a graphic LINE
# ---------------------------------------------------------------------------
source [file join [file dirname [info script]] scratch.tcl]
set symf [file join [test_scratch pwg_sym] pwg.sym]
set fh [open $symf w]
puts $fh "v {xschem version=3.4.8RC file_version=1.3}"
puts $fh "G {}"; puts $fh "K {type=subcircuit}"; puts $fh "V {}"; puts $fh "S {}"; puts $fh "E {}"
puts $fh "L 4 -10 -10 10 -10 {}"
close $fh
xschem load $symf
check "C0 loaded a symbol view"          [string match {*.sym} [xschem get current_name]] 1
xschem line gui                                ;# LIVE line draw
check "C1 live: STARTLINE armed"         [startline] 1
xschem add_symbol_pin -place
check "C1 live: p clears STARTLINE"      [startline] 0
check "C1 live: p clears line mode"      [lc] 0
check "C1 live: pin preview armed"       [placing] 1
xschem abort_operation ; xschem abort_operation

# C2 CONTROL -- the SCRIPTED coordinate form is the replay/test seam and must NOT abort a
#    gesture: it commits a pin at given coordinates and arms no cursor placement at all.
xschem line gui
check "C2 control: STARTLINE armed"      [startline] 1
xschem add_symbol_pin 40 40 SCRIPTED in
check "C2 control: draw NOT aborted"     [startline] 1
check "C2 control: line mode kept"       [lc] 4
check "C2 control: no preview armed"     [placing] 0
xschem abort_operation ; xschem abort_operation
catch {file delete -force $symf}

# ---------------------------------------------------------------------------
# E. issue 0233 F2 -- the REVERSE door: a wire/line verb pressed while a modal PLACEMENT
#    preview is live must abandon the preview and start drawing.
#
# Same jam as F1, entered backwards: with both armed the wire wins every click, so the
# preview rides the cursor and can never be dropped. Add-Wire-Label had an accidental
# escape hatch (one more keystroke re-issues `-place`, which hits the F1 gate), Add-Pin had
# none -- only ESC, which throws the pin away. User-ratified 2026-08-07, same rule as 0230:
# whatever you just pressed is what you meant. The gate is leave_placement_for() at each
# wire/line VERB, deliberately not inside start_wire()/start_line() (those are also the
# per-click continuation of a running draw: persistent_command calls start_wire() on every
# press, so a teardown there would fire on an ordinary click).
# ---------------------------------------------------------------------------
xschem clear force        ;# leaves C's symbol view: `clear force` returns to untitled.sch
check "E0 back in a schematic"           [string match {*.sch} [xschem get current_name]] 1
set ::infix_interface 1

# E1 -- `xschem wire gui` (menu Wire / Insert wire) on top of an Add-Pin preview.
reset ; xschem add_sch_pin -place
check "E1 armed: pin preview"            [placing] 1
check "E1 armed: preview instance"       [xschem get instances] 1
xschem wire gui
check "E1 wire clears START_SYMPIN"      [placing] 0
check "E1 wire clears sympin_preview"    [xschem get sympin_preview] 0
check "E1 wire deleted preview instance" [xschem get instances] 0
check "E1 wire draw armed"               [startwire] 1
check "E1 wire owns last_command"        [lc] 1
check "E1 nothing committed"             [xschem get wires] 1

# E2 -- the Add-Wire-Label preview, and the MENU-style (infix 0) wire arm.
reset ; set ::label_new_name BAR ; xschem add_wire_label -place
check "E2 armed: label preview"          [placing] 1
set ::infix_interface 0 ; xschem wire ; set ::infix_interface 1
check "E2 menu wire clears preview"      [placing] 0
check "E2 menu wire clears sympin_prev"  [xschem get sympin_preview] 0
#    (wirelabel_preview has no `xschem get` seam, so its clear in abort_placement_preview()
#     is unasserted -- noted in issue 0233, and the flag is issue 0236's subject anyway)
check "E2 menu wire armed"               [menuwire] 1

# E3 -- `xschem line gui` (Shift+L / menu Insert line) does the same.
reset ; xschem add_sch_pin -place
xschem line gui
check "E3 line clears the preview"       [placing] 0
check "E3 line draw armed"               [startline] 1

# E4 -- `xschem snap_wire` (Insert snap wire) is a wire arm too.
reset ; xschem add_sch_pin -place
xschem snap_wire
check "E4 snap wire clears preview"      [placing] 0
check "E4 snap wire armed"               [expr {[menustart] && ([xschem get ui_state2] & 16) ? 1 : 0}] 1  ;# MENUSTARTSNAPWIRE

# E5 CONTROL -- the SCRIPTED coordinate forms commit outright and arm no draw: they are the
#    replay/test seams and must NOT abandon a placement (mirror of C2 for the reverse door).
reset ; xschem add_sch_pin -place
xschem wire 0 100 100 100
check "E5 control: preview kept"         [placing] 1
check "E5 control: wire committed"       [xschem get wires] 2
check "E5 control: preview still there"  [xschem get sympin_preview] 1
xschem abort_operation

# E6 -- one undo baseline per gesture (add_wire_label.md / cadence_pin_name_text.md item #3).
#    The arm pushed ONE baseline and the F2 teardown removes the preview undo-free, so a single
#    undo must land on the pre-gesture drawing. A second baseline would leave the preview
#    instance behind on that undo instead.
reset
check "E6 pre-gesture: one wire, no inst" [expr {[xschem get wires]==1 && [xschem get instances]==0}] 1
xschem add_sch_pin -place
xschem wire gui                                ;# F2 teardown
xschem abort_operation ; xschem abort_operation
xschem undo
check "E6 undo lands pre-gesture"        [expr {[xschem get wires]==1 && [xschem get instances]==0}] 1

# E7 -- the issue 0231 guard. abort_placement_preview() tears the preview down with delete(),
#    which removes the SELECTION, not the preview object (0231, open). On the ESC path that is
#    0231's problem; F2 must not hand the same delete() to `w`, so it DECLINES while a multiple
#    selection is live: measured before the guard, 2 wires + preview + select_all + `w` left
#    ZERO wires. Declining also means the draw must NOT arm -- otherwise the jam is back.
reset ; xschem wire 0 40 100 40 ; xschem unselect_all
xschem add_sch_pin -place
xschem select_all
check "E7 armed: multiple selection"     [expr {[xschem get lastsel] > 1}] 1
xschem wire gui
check "E7 declined: drawing intact"      [xschem get wires] 2
check "E7 declined: preview kept"        [placing] 1
check "E7 declined: preview instance"    [xschem get instances] 1
check "E7 declined: wire NOT armed"      [startwire] 0
check "E7 declined: no wire mode"        [lc] 0
xschem abort_operation

# E8 -- the teardown must not touch the modify flag (issue 0234 is this bug on a sibling path).
reset ; xschem save
check "E8 saved doc is clean"            [xschem get modified] 0
xschem add_sch_pin -place
xschem wire gui
check "E8 teardown kept it clean"        [xschem get modified] 0
xschem abort_operation ; xschem abort_operation

set ::infix_interface $saved_infix

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
