# RED-first regression: entering a modal PLACEMENT leaves wire/line draw mode.
#
# Issue 0240 established the policy for `l` (Add Wire Label) and the reason it is not optional:
# end_place_move_copy_zoom() tests STARTWIRE BEFORE the placement arm, so while a wire draw is
# live every click feeds the wire and the placement can never be dropped -- and under
# `persistent_command` (cadence_style_rc) the press handler seizes the click even in the RESTING
# command mode, where ui_state has no STARTWIRE at all and only last_command is armed.
# Issue 0243 measured the same clash on the other twelve placement arms. This file covers the two
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

# `reset` leaves an UNTITLED buffer, whose path load_schematic() composes from $PWD
# (src/save.c:4407) -- and this file is run from the repo ROOT. So anything that persists such a
# buffer litters the working tree with untitled-<n>.sch, one more per run because
# get_unused_untitled_name() skips names already on disk (src/xinit.c:180). Two writers:
#   * the E8 `xschem save` below -- redirected into the scratch dir;
#   * write_backup()'s "~" companion, which is written for untitled buffers on purpose (issue
#     0060) and so fires on every one of the ~60 resets -- suppressed for the whole file.
# See doc/claude/issues/0322 (68 corpses) and 0148 (the same class, for directories).
source [file join [file dirname [info script]] scratch.tcl]
set scratch [test_scratch placegate]
set saved_autosave_backup $::autosave_backup
set ::autosave_backup 0

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
# D. issue 0243 F3 -- ESC must not leak shape-draw bits past the STARTMOVE return.
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
#   CONSTRUCTOR NOTE (phases 1-2, 2026-08-08): this needs a wire draw and a SECOND modal gesture
#   armed at the same time, and no verb builds that state any more -- `add_graph` (phase 2) and
#   `rect gui` (phase 1) now both abandon the wire first, which is the whole point. The bracket
#   below is the test-only seam `xschem test_gate_bypass` (scheduler.c), used ONLY to build the
#   state; the ESC being tested runs with the gates live again. Section H pins that the seam
#   defaults to off and that flipping it really does disable a gate, so a forgotten `1` cannot
#   make a gate check pass silently.
reset ; xschem wire gui
xschem test_gate_bypass 1 ; xschem add_graph ; xschem rect gui ; xschem test_gate_bypass 0
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
# E. issue 0243 F2 -- the REVERSE door: a wire/line verb pressed while a modal PLACEMENT
#    preview is live must abandon the preview and start drawing.
#
# Same jam as F1, entered backwards: with both armed the wire wins every click, so the
# preview rides the cursor and can never be dropped. Add-Wire-Label had an accidental
# escape hatch (one more keystroke re-issues `-place`, which hits the F1 gate), Add-Pin had
# none -- only ESC, which throws the pin away. User-ratified 2026-08-07, same rule as 0240:
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
#     is unasserted -- noted in issue 0243, and the flag is issue 0246's subject anyway)
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

# E7 -- issue 0241 landed, so F2 no longer carves itself out. This section used to assert that a
#    wire verb DECLINED while a multiple selection was live: abort_placement_preview() tore the
#    preview down with delete(), which removes the SELECTION and not the preview object, and
#    handing that to `w` would have wiped the drawing on the first keystroke after a Ctrl+A
#    (measured then: 2 wires + preview + select_all + `w` -> ZERO wires). The teardown is now
#    scoped to the identity stamped at the arm, so the verb must PROCEED -- and the assertion
#    that carries 0241 on this path is the last one: THE OTHER SELECTED OBJECTS SURVIVE.
#    Same constructor as before, deliberately, so the two halves are directly comparable.
reset ; xschem wire 0 40 100 40 ; xschem unselect_all
xschem instance devices/lab_pin.sym 300 0 0 0 {name=e7 lab=E7SURV}  ;# a survivor of the
xschem unselect_all                                                 ;# preview's OWN type
xschem add_sch_pin -place
xschem select_all
check "E7 armed: multiple selection"     [expr {[xschem get lastsel] > 1}] 1
check "E7 armed: preview + survivor"     [xschem get instances] 2
xschem wire gui
check "E7 proceeds: preview torn down"   [placing] 0
check "E7 proceeds: wire draw armed"     [startwire] 1
check "E7 proceeds: wire mode owned"     [lc] 1
check "E7 0241: other objects survive"   [xschem get wires] 2
check "E7 0241: survivor instance kept"  [xschem get instances] 1
check "E7 0241: it is the survivor"      [xschem getprop instance 0 lab] E7SURV
xschem abort_operation ; xschem abort_operation

# E8 -- the teardown must not touch the modify flag (issue 0244 is this bug on a sibling path).
reset ; xschem saveas [file join $scratch e8.sch] schematic   ;# NOT a bare `xschem save`: 0322
check "E8 saved doc is clean"            [xschem get modified] 0
xschem add_sch_pin -place
xschem wire gui
check "E8 teardown kept it clean"        [xschem get modified] 0
xschem abort_operation ; xschem abort_operation

# ---------------------------------------------------------------------------
# F. phase 1 of doc/claude/suggestions/plan_modal_gesture_exclusion.md (issue 0247): a SHAPE draw
#    started on top of a live wire/line draw abandons it, exactly as a placement does.
#
# This is the case the user hit in the GUI on 2026-08-07 under src/cadence_style_rc: `w`, click,
# `r` -- and the editor stayed in wire mode. The rectangle armed (measured ui=65537,
# MENUSTART|MENUSTARTRECT, last_command=1) while the wire kept claiming every click, so the
# rectangle could never start and ESC was the only exit. Issue 0247 called this "much milder" than
# the placement clash; it is the same dead end, and the phase-1 gate is the same one-line call.
#
# Not drivable here: the `C` / Ctrl+C keys and context-menu picks 4, 5, 19, 20 are callback.c
# paths, and `xschem callback ...` segfaults under --nogui (WIRING.md §10). They carry the same
# leave_wire_draw_for() call at the same point in the same shape of branch -- prove-by-code -- and
# the scheduler twins below (`rect gui`, `polygon gui`, `arc`) are what the keys/menus dispatch to
# for `r` (menu/toolbar) and `P` (the registry action tools.insert_polygon IS `xschem polygon gui`).
# ---------------------------------------------------------------------------
proc startpoly {} { return [bit 2048] }        ;# STARTPOLYGON
proc u2bit {b}   { return [expr {([xschem get ui_state2] & $b) ? 1 : 0}] }
proc hold {}     { return [xschem get statusmsg_hold] }
proc msg {}      { return [xschem get statusmsg] }
#  reset + a known status line, so a check can tell "the gate spoke" from "a message was already
#  up" (the hold is wall-clock, so it outlives a single check)
proc nreset {} { reset ; xschem statusmsg "-" }

set ::infix_interface 1

# F1 -- `r` on a LIVE wire draw (the infix half of the report).
nreset ; xschem wire gui
check "F1 live: STARTWIRE armed"          [startwire] 1
xschem rect gui
check "F1 live: r clears STARTWIRE"       [startwire] 0
check "F1 live: r clears wire mode"       [lc] 0
check "F1 live: rect gesture armed"       [startrect] 1
check "F1 live: nothing committed"        [xschem get wires] 1
check "F1 live: statusbar says why"       [msg] "Rectangle: in-progress wire abandoned"

# F2 -- the SAME verb in cadence mode, which is where the report came from: infix_interface 0, so
#   the rectangle only arms MENUSTART|MENUSTARTRECT and its first CLICK would start it -- while the
#   wire draw underneath owns every click. Measured then: ui=65537 [STARTWIRE|MENUSTART],
#   last_command=1. The live draw is armed under infix 1 first (that is what `xschem wire gui`
#   models: the canvas click that starts the wire, which cannot be driven headlessly), then the
#   mode is flipped for the `r`. A gate that only covered the infix branch would pass F1 and leave
#   this red, which is exactly the user's case.
#   There is deliberately NO check for `r` on a MENU-ARMED wire (first click not landed): the shape
#   arm ASSIGNS ui_state2 wholesale, so that arm is replaced with or without a gate -- a check
#   there would be green either way (verified: sabotaging the gate leaves it green).
nreset ; xschem wire gui
check "F2 cadence: draw is live"          [startwire] 1
set ::infix_interface 0
xschem rect gui
check "F2 cadence: r clears STARTWIRE"    [startwire] 0
check "F2 cadence: r clears wire mode"    [lc] 0
check "F2 cadence: rect menu-armed"       [expr {[menustart] && [u2bit 4]}] 1
check "F2 cadence: statusbar says why"    [msg] "Rectangle: in-progress wire abandoned"
set ::infix_interface 1
xschem abort_operation

# F3 -- `P` (polygon). The Shift+P binding is the registry action tools.insert_polygon, whose
#   command IS `xschem polygon gui`, so this drives the real key path.
nreset ; xschem wire gui ; xschem polygon gui
check "F3 live: P clears STARTWIRE"       [startwire] 0
check "F3 live: P clears wire mode"       [lc] 0
check "F3 live: polygon armed"            [startpoly] 1
check "F3 live: statusbar says why"       [msg] "Polygon: in-progress wire abandoned"
#   ...and in cadence mode, same construction as F2.
nreset ; xschem wire gui ; set ::infix_interface 0
xschem polygon gui
check "F3 cadence: P clears STARTWIRE"    [startwire] 0
check "F3 cadence: polygon menu-armed"    [expr {[menustart] && [u2bit 32]}] 1
set ::infix_interface 1
xschem abort_operation

# F4 -- arc/circle. `xschem arc` with no coordinates is the ARM form (the menu route and the
#   scheduler twin of the `C` / Ctrl+C keys).
nreset ; xschem wire gui ; xschem arc
check "F4 live: arc clears STARTWIRE"     [startwire] 0
check "F4 live: arc clears wire mode"     [lc] 0
check "F4 live: arc menu-armed"           [expr {[menustart] && [u2bit 64]}] 1
check "F4 live: statusbar says why"       [msg] "Arc: in-progress wire abandoned"

# F5 -- the RESTING wire command mode (segment ended by a double click: no STARTWIRE, but
#   last_command still owns the next click, and under persistent_command the press handler calls
#   start_wire() before anything else can have it).
nreset ; xschem wire gui ; xschem abort_operation
check "F5 resting: no STARTWIRE"          [startwire] 0
check "F5 resting: wire mode armed"       [lc] 1
xschem rect gui
check "F5 resting: r clears wire mode"    [lc] 0
check "F5 resting: rect armed"            [startrect] 1

# F6 -- a live graphic LINE draw (Shift+L, and the only draw available in a .sym view).
nreset ; xschem line gui
check "F6 line: STARTLINE armed"          [startline] 1
xschem polygon gui
check "F6 line: P clears STARTLINE"       [startline] 0
check "F6 line: polygon armed"            [startpoly] 1

# F7 CONTROL -- the coordinate COMMIT forms are the replay/test seams: they store an object
#   outright, arm no gesture, and must leave a live draw completely alone (mirror of C2/E5).
nreset ; xschem wire gui ; xschem rect 10 10 20 20
check "F7 control: rect coords keep draw" [startwire] 1
check "F7 control: rect coords keep mode" [lc] 1
check "F7 control: rect committed"        [xschem get rects 4] 1
check "F7 control: gate stayed silent"    [msg] "-"
nreset ; xschem wire gui ; xschem polygon 0 0 10 0 10 10
check "F7 control: poly coords keep draw" [startwire] 1
check "F7 control: poly gate silent"      [msg] "-"
nreset ; xschem wire gui ; xschem arc 0 0 10 0 360 4
check "F7 control: arc coords keep draw"  [startwire] 1
check "F7 control: arc gate silent"       [msg] "-"

# F8 -- the arg-form quirk (WIRING.md / issue 0243): a TRUNCATED coordinate form falls into the
#   ARM branch, not the commit branch, so it must be gated. Gate by branch, not by verb name.
nreset ; xschem wire gui ; xschem rect 10 20
check "F8 truncated form arms -> gated"   [startwire] 0
check "F8 truncated form: menu-armed"     [expr {[menustart] && [u2bit 4]}] 1

# F9 CONTROL -- with no draw live the gate is a no-op: the shape arms normally and says nothing
#   (a gate that fired here would be abandoning something the user never started).
nreset ; xschem rect gui
check "F9 no draw: rect still arms"       [startrect] 1
check "F9 no draw: gate stayed silent"    [msg] "-"
check "F9 no draw: no message held"       [hold] 0
xschem abort_operation

# ---------------------------------------------------------------------------
# G. phase 2: the remaining PLACEMENT verbs cancel a live wire/line draw.
#
# `l`, `p` and component insert were gated by 0243 F1; these are the arms issue 0247 tracked as
# still open -- and for add_graph / add_image / the screen grab there is no form to re-trigger, so
# before the gate ESC was the only exit and it threw the placement away.
#
# Not drivable here: context-menu picks 1 (Insert symbol -> start_place_symbol) and 6 (Insert
# text), the `t` key and the screen grab are callback.c / draw.c paths (`xschem callback`
# segfaults headlessly, the grab needs a real pointer grab), and `add_image` opens tk_getOpenFile.
# `place_text` below IS the scriptable twin of `t` and of ctx-menu 6; start_place_symbol() shares
# its gate with the already-covered `xschem place_symbol` (section B) by inspection only.
# ---------------------------------------------------------------------------

# G1 -- `Alt+Shift+L` / `xschem net_label 0`: a real lab_wire preview INSTANCE on the cursor.
nreset ; xschem wire gui ; xschem net_label 0
check "G1 live: net label clears wire"    [startwire] 0
check "G1 live: clears wire mode"         [lc] 0
check "G1 live: placement armed"          [placing] 1
check "G1 live: preview instance"         [xschem get instances] 1
check "G1 live: nothing committed"        [xschem get wires] 1
check "G1 live: statusbar says why"       [msg] "Net label: in-progress wire abandoned"
xschem abort_operation
check "G1 ESC after gate: clean"          [ui] 0
check "G1 ESC removed the preview"        [xschem get instances] 0

# G2 -- Ctrl+P / Ctrl+Shift+P are the same helper with another symbol (ipin/opin).
nreset ; xschem wire gui ; xschem net_label 2
check "G2 live: Ctrl+P clears wire"       [startwire] 0
check "G2 live: placement armed"          [placing] 1
xschem abort_operation

# G3 -- Graphs > Add graph.
nreset ; xschem wire gui ; xschem add_graph
check "G3 live: add_graph clears wire"    [startwire] 0
check "G3 live: clears wire mode"         [lc] 0
check "G3 live: placement armed"          [placing] 1
check "G3 live: statusbar says why"       [msg] "Add graph: in-progress wire abandoned"
xschem abort_operation

# G4 -- `xschem place_text`, the scriptable twin of the `t` key and ctx-menu 6. The text DIALOG
#   needs a Tk toplevel, so headlessly place_text() fails and no PLACE_TEXT arms -- but the gate
#   runs before it, which is the half under test (`t` used to leave ui=1 [STARTWIRE] with
#   last_command zeroed: the residue issue 0243 F3 had to teach ESC to clean up).
nreset ; xschem wire gui ; catch {xschem place_text}
check "G4 live: place_text clears wire"   [startwire] 0
check "G4 live: clears wire mode"         [lc] 0
check "G4 live: statusbar says why"       [msg] "Place text: in-progress wire abandoned"

# G5 -- infix_interface 0 (cadence): the MENU-armed wire is dropped too.
set ::infix_interface 0
nreset ; xschem wire ; xschem net_label 0
check "G5 menu: net label clears arm"     [menuwire] 0
check "G5 menu: placement armed"          [placing] 1
xschem abort_operation
nreset ; xschem wire ; xschem add_graph
check "G5 menu: add_graph clears arm"     [menuwire] 0
xschem abort_operation
set ::infix_interface 1

# G6 -- the RESTING wire command mode.
nreset ; xschem wire gui ; xschem abort_operation
check "G6 resting: wire mode armed"       [lc] 1
xschem net_label 0
check "G6 resting: net label clears mode" [lc] 0
check "G6 resting: placement armed"       [placing] 1
xschem abort_operation

# G7 -- a live graphic LINE draw is abandoned by a placement too.
nreset ; xschem line gui ; xschem net_label 0
check "G7 line: net label clears line"    [startline] 0
check "G7 line: placement armed"          [placing] 1
xschem abort_operation

# G8 CONTROL -- `xschem net_label` with no type places nothing, so it must not touch the draw
#   (the branch never reaches place_net_label). Same rule as the coordinate forms in F7.
nreset ; xschem wire gui ; xschem net_label
check "G8 control: no-op keeps draw"      [startwire] 1
check "G8 control: no-op keeps mode"      [lc] 1
check "G8 control: gate stayed silent"    [msg] "-"
xschem abort_operation ; xschem abort_operation

# ---------------------------------------------------------------------------
# H. issue 0248 -- the gate messages above are the whole user-visible half of this policy, and
#    until now none of them could be read: `statusmsg(str, 1)` does write .statusbar.1, but the
#    coordinate readout (callback.c motion + press/release) overwrites it on the next 8-pixel
#    flick of the mouse, and `ui_state` is non-zero for exactly the reason the message exists.
#    Placement verbs had a second clobberer one call later: place_symbol() SELECTS the preview it
#    just placed, and select.c's "n=%4d x = ..." info line lands on the same field.
#    The fix is a hold enforced inside statusmsg() itself. The status bar is a Tk label that does
#    not exist under --nogui, so `xschem get statusmsg` (the last line that actually reached the
#    field) plus `xschem get statusmsg_hold` are the seams; the pixels were confirmed by eye.
# ---------------------------------------------------------------------------

# H1 -- an ordinary script line owns the field and holds nothing.
nreset
check "H1 plain message lands"            [msg] "-"
check "H1 plain message holds nothing"    [hold] 0

# H2 -- a gate message holds the field.
xschem wire gui ; xschem rect gui
check "H2 gate message lands"             [msg] "Rectangle: in-progress wire abandoned"
check "H2 gate message is held"           [hold] 1
xschem abort_operation

# H3 -- the placement clobberer: place_symbol's own selection info line runs AFTER the gate
#    message and must be dropped while the hold is up. Without the hold this reads
#    "n=   0 x = ... w = ... h = ..." -- measured, and the reason the fix is writer-side.
nreset ; xschem wire gui ; xschem net_label 0
check "H3 select info line dropped"       [msg] "Net label: in-progress wire abandoned"
check "H3 hold survived the placement"    [hold] 1
xschem abort_operation

# H4 -- an explicitly requested line wins immediately (deliberate news, and the reset seam).
xschem statusmsg "AFTER"
check "H4 explicit line wins"             [msg] "AFTER"
check "H4 explicit line releases hold"    [hold] 0

# H5 -- the test-only gate bypass (`xschem test_gate_bypass`), which is what still makes the
#    co-armed state constructible for D3 here and G2 in test_add_wire_label.tcl. Pinned in both
#    directions so a suite that forgot to switch it back cannot pass silently.
check "H5 bypass is off by default"       [xschem test_gate_bypass] 0
nreset ; xschem test_gate_bypass 1
xschem wire gui ; xschem rect gui
check "H5 bypassed: wire draw survives"   [startwire] 1
check "H5 bypassed: rect armed too"       [startrect] 1
check "H5 bypassed: gate stayed silent"   [msg] "-"
xschem test_gate_bypass 0
check "H5 bypass switches back off"       [xschem test_gate_bypass] 0
xschem abort_operation ; xschem abort_operation
nreset ; xschem wire gui ; xschem rect gui
check "H5 gate live again: wire dropped"  [startwire] 0
xschem abort_operation

set ::infix_interface $saved_infix
set ::autosave_backup $saved_autosave_backup

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
