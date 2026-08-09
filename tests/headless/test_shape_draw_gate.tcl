# RED-first regression: NOTHING may stay armed under a live SHAPE draw, in either direction.
#
# Issue 0269 / phase 3 of doc/claude/suggestions/plan_modal_gesture_exclusion.md, the last open
# phase and the last hole in WIRING.md §8 class D's modal-gesture half.
#
# THE SHAPE FAMILY is five gestures over four ui_state bits: rectangle (STARTRECT 2), polygon
# (STARTPOLYGON 2048), arc and circle (both STARTARC 4096 -- a circle is new_arc(PLACE, 360.)) and
# the zoom box (STARTZOOM 128). Each has TWO live states and a gate that covers only one of them
# is a gate that does nothing for half the users (plan landmine 5):
#   MENU-ARMED   MENUSTART (65536) in ui_state + a MENUSTARTSHAPE bit in ui_state2 -- what
#                `infix_interface 0` (cadence_style_rc, and what `xschem arc|circle|zoom_box` do in
#                BOTH branches) leaves behind; the first canvas click starts the gesture.
#   CLICKED      the ui_state bit above, rubber band up.
# `xschem callback ...` SEGFAULTS under --nogui, so the CLICKED state of arc/circle/zoom had no
# headless construction at all until this phase; `xschem test_shape_click` (scheduler.c) is the
# test-only seam that runs exactly what the first click runs -- the matching arm of
# check_menu_start_commands() plus the release-side `ui_state &= ~MENUSTART`. It is a stand-in for
# the click, not a bypass: it touches no gate.
#
# WHY THE CO-ARM IS FATAL AND NOT MERELY UNTIDY: handle_button_press() runs
# check_menu_start_commands() BEFORE end_place_move_copy_zoom(), and inside the latter all four
# shape bits are tested before the STARTMOVE arm that commits a placement. So while any shape bit
# is set, no click can ever drop a preview. STARTPOLYGON is unbounded -- new_polygon(ADD) never
# clears it -- so a polygon draw plus a placement preview is the issue 0240 dead end exactly:
# every click adds a polygon point and ESC is the only exit.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_shape_draw_gate.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc note {msg} { puts "note: $msg" }

source [file join [file dirname [info script]] scratch.tcl]
set ::d0269   [test_scratch p0269]
set ::src0269 [file join $::d0269 src.sch]
set ::cln0269 [file join $::d0269 clean.sch]

set ::autosave_backup 0

# --- state oracles ---------------------------------------------------------
proc ui  {} { return [xschem get ui_state] }
proc ui2 {} { return [xschem get ui_state2] }
proc bit {b} { return [expr {([ui] & $b) ? 1 : 0}] }

## the four shape bits of ui_state: STARTRECT|STARTZOOM|STARTPOLYGON|STARTARC
proc shapebits  {} { return [expr {[ui] & (2 | 128 | 2048 | 4096)}] }
## MENUSTARTSHAPE (xschem.h) = MENUSTARTRECT 4 | MENUSTARTZOOM 8 | MENUSTARTPOLYGON 32 |
##                             MENUSTARTARC 64 | MENUSTARTCIRCLE 128 = 236
proc menushape  {} { return [expr {(([ui] & 65536) && ([ui2] & 236)) ? 1 : 0}] }
## "a shape draw is live in EITHER of its two states" -- what the gate must make false
proc shape      {} { return [expr {([shapebits] || [menushape]) ? 1 : 0}] }
proc startwire  {} { return [bit 1] }
## "a wire draw is armed in EITHER branch": STARTWIRE, or MENUSTART + MENUSTARTWIRE 1 |
## MENUSTARTLINE 2 | MENUSTARTSNAPWIRE 16 -- under infix_interface 0 `wire gui` only menu-arms.
proc wiredraw   {} { return [expr {([ui] & 1) || (([ui] & 65536) && ([ui2] & 19)) ? 1 : 0}] }
proc startline  {} { return [bit 4] }
proc placing    {} { return [expr {([ui] & (16384 | 8192 | 1024)) ? 1 : 0}] }  ;# SYMPIN|SYMBOL|TEXT
proc merging    {} { return [bit 256] }
proc menustart  {} { return [bit 65536] }
proc lc         {} { return [xschem get last_command] }
proc msg        {} { return [xschem get statusmsg] }
proc hold       {} { return [xschem get statusmsg_hold] }
proc polys      {} { return [xschem get polygons 4] }
proc rects      {} { return [xschem get rects 4] }
proc arcs       {} { return [xschem get arcs 4] }

# --- fixtures --------------------------------------------------------------
## The merged file, and a document that is DIRTY (mkdoc) or CLEAN (mkdoc_clean) on demand. The
## clean one is load-fresh rather than set_modify(0)'d, because the polygon rows in section F are
## about the modify flag itself and must not start from a flag somebody else wrote.
proc mksrc {} {
  xschem clear force
  xschem wire 500 500 600 500
  xschem instance devices/lab_pin.sym 700 500 0 0 {name=m1 lab=MERGED}
  xschem unselect_all
  xschem saveas $::src0269
}
proc mkdoc {} {
  xschem abort_operation ; xschem abort_operation
  xschem clear force
  xschem wire 0 0 100 0
  xschem wire 0 100 100 100
  xschem instance devices/lab_pin.sym 300 0 0 0 {name=p1 lab=SURVIVOR}
  xschem text 400 400 0 0 {SURVIVORTEXT} {} 0.4 0
  xschem unselect_all
  xschem statusmsg "-"
}
proc mkdoc_clean {} {
  mkdoc
  xschem saveas $::cln0269
  xschem load $::cln0269
  xschem statusmsg "-"
}
## "the fixture really survived" -- a gate that deleted everything and a gate that deleted nothing
## must both redden, so every row asserts this beside the state it is really about.
proc intact {} {
  return "[xschem get wires]/[xschem get instances]/[xschem get texts]"
}
proc prime_clip {} { xschem load $::src0269 ; xschem select_all ; xschem copy ; mkdoc }

## THE FIVE SHAPE ARMS. Each is the scripted twin of a key / menu / context-menu pick; `circle`
## and `zoom_box` are the two verbs that carried NO gate of any kind before this phase (issue 0272).
set ::ARMS {
  rect    {xschem rect gui}
  polygon {xschem polygon gui}
  arc     {xschem arc gui}
  circle  {xschem circle}
  zoom    {xschem zoom_box}
}
## arm and, if the verb only reached the MENU state, deliver the first click -- so every row of
## section B runs against a genuinely LIVE draw in both interface branches.
proc arm_live {name} {
  array set a $::ARMS
  eval $a($name)
  if {[menustart]} { xschem test_shape_click }
}
proc arm_menu {name} {
  array set a $::ARMS
  eval $a($name)
}

mksrc
mkdoc
check "fixture: 2 wires 1 inst 1 text"   [intact] "2/1/1"

set saved_infix $::infix_interface
set ::pin_new_name PG ; set ::pin_new_dir in

# ===========================================================================
# A. The arms themselves, and the click seam. Nothing below is meaningful unless these hold.
# ===========================================================================
set ::infix_interface 1
foreach {nm armv} $::ARMS {
  mkdoc ; arm_menu $nm
  check "A1 infix1 $nm arms a shape"      [shape] 1
  xschem abort_operation
  check "A1 infix1 $nm ESC clears it"     [shape] 0
}
set ::infix_interface 0
foreach {nm armv} $::ARMS {
  mkdoc ; arm_menu $nm
  check "A1 infix0 $nm arms a shape"      [shape] 1
  check "A1 infix0 $nm arms MENUSTART"    [menustart] 1
  xschem abort_operation
  check "A1 infix0 $nm ESC clears it"     [shape] 0
}

# A2 -- the click seam reaches the ui_state bit each gesture really uses. A circle is
#       new_arc(PLACE, 360.), so it lands on STARTARC, not on a bit of its own.
foreach {nm expbit} {rect 2 polygon 2048 arc 4096 circle 4096 zoom 128} {
  mkdoc ; arm_menu $nm
  check "A2 $nm: click returns 1"         [xschem test_shape_click] 1
  check "A2 $nm: reaches its ui bit"      [shapebits] $expbit
  check "A2 $nm: click consumed MENUSTART" [menustart] 0
  xschem abort_operation
}
mkdoc
check "A3 click seam is a no-op unarmed"  [xschem test_shape_click] 0
check "A3 and it armed nothing"           [shape] 0
set ::infix_interface 1

# ===========================================================================
# B. THE PHASE-3 DIRECTION: a second gesture cancels a LIVE shape draw.
#    Fourteen competing verbs x five shapes. Each row asserts BOTH halves -- the shape really
#    went, and the fixture is still whole (a teardown that took the drawing with it is the
#    issue 0241 failure and must not read as a pass here).
# ===========================================================================
set ::COMPETING {
  {wire gui}          {xschem wire gui}
  {line gui}          {xschem line gui}
  {snap_wire}         {xschem snap_wire}
  {place_symbol}      {xschem place_symbol devices/lab_pin.sym}
  {add_wire_label}    {xschem add_wire_label -place}
  {add_sch_pin}       {xschem add_sch_pin -place}
  {add_symbol_pin}    {xschem add_symbol_pin -place}
  {net_label}         {xschem net_label 0}
  {add_graph}         {xschem add_graph}
  {place_text}        {xschem place_text}
  {merge}             {xschem merge $::src0269}
  {undo}              {xschem undo}
  {redo}              {xschem redo}
}
foreach {nm armv} $::ARMS {
  foreach {cnm cmd} $::COMPETING {
    mkdoc ; arm_live $nm
    catch {eval $cmd}
    check "B $nm + $cnm: shape gone"      [shape] 0
    xschem abort_operation ; xschem abort_operation
    if {$cnm ne "undo" && $cnm ne "redo"} {
      check "B $nm + $cnm: ESC leaves fixture whole" [intact] "2/1/1"
    }
  }
}

# B2 -- the same in the MENU-ARMED state, i.e. the cadence branch, for a representative five.
#    `place_text` opens a Tk dialog that cannot exist headlessly; it is in the list above on
#    purpose (the gate must fire at the ARM, so the shape is gone even when the placement that
#    displaced it never materializes) and stays here for the same reason.
set ::infix_interface 0
foreach {nm armv} $::ARMS {
  foreach {cnm cmd} {
    {wire gui}     {xschem wire gui}
    {place_symbol} {xschem place_symbol devices/lab_pin.sym}
    {merge}        {xschem merge $::src0269}
    {undo}         {xschem undo}
    {add_graph}    {xschem add_graph}
  } {
    mkdoc ; arm_menu $nm
    catch {eval $cmd}
    check "B2 menu $nm + $cnm: shape gone" [shape] 0
    xschem abort_operation ; xschem abort_operation
  }
}
set ::infix_interface 1

# B3 -- and the shape did not COMMIT itself on the way out. A shape draw stores nothing until it
#    completes, so an abandoned one must leave the object counts untouched -- including the
#    polygon, which is the only member with a store on a non-click path (see section F).
foreach {nm armv} $::ARMS {
  mkdoc_clean ; arm_live $nm ; xschem wire gui
  check "B3 $nm abandon stores no rect"   [rects] 0
  check "B3 $nm abandon stores no poly"   [polys] 0
  check "B3 $nm abandon stores no arc"    [arcs] 0
  check "B3 $nm abandon leaves it clean"  [xschem get modified] 0
  xschem abort_operation ; xschem abort_operation
}

# ===========================================================================
# C. THE REVERSE -- "call from every placement verb": a SHAPE arm cancels whatever was live.
#    Before phase 3 every shape arm carried leave_wire_draw_for() and NOTHING else, so a shape
#    armed over a placement or a pending paste left both gestures live (measured: `rect gui` on
#    an Add-Pin preview -> ui_state 16426; on a pending merge -> 298).
# ===========================================================================
foreach {nm armv} $::ARMS {
  # C1 over a live WIRE draw (true since phase 1 -- the control that a fix which merely swapped
  #    which gesture wins cannot pass)
  mkdoc ; xschem wire gui ; arm_menu $nm
  check "C1 $nm over wire: wire gone"     [startwire] 0
  check "C1 $nm over wire: mode gone"     [lc] 0
  check "C1 $nm over wire: shape armed"   [shape] 1
  xschem abort_operation ; xschem abort_operation

  # C2 over a live PLACEMENT preview
  mkdoc ; xschem add_sch_pin -place ; arm_menu $nm
  check "C2 $nm over pin: preview gone"   [placing] 0
  check "C2 $nm over pin: flag cleared"   [xschem get sympin_preview] 0
  check "C2 $nm over pin: shape armed"    [shape] 1
  check "C2 $nm over pin: fixture whole"  [intact] "2/1/1"
  xschem abort_operation ; xschem abort_operation

  # C3 over a pending PASTE
  mkdoc ; xschem merge $::src0269 ; arm_menu $nm
  check "C3 $nm over merge: paste gone"   [merging] 0
  check "C3 $nm over merge: shape armed"  [shape] 1
  check "C3 $nm over merge: fixture whole" [intact] "2/1/1"
  xschem abort_operation ; xschem abort_operation

  # C4 over ANOTHER live shape draw -- the co-arm phase 1 could not see, because the MENUSTART
  #    branches only OR in MENUSTART and ASSIGN ui_state2, never touching a live STARTRECT
  #    (measured: `rect gui` then `rect 10 20` -> ui_state 65538 = STARTRECT|MENUSTART).
  #    The prior gesture is a live rectangle and the assertion is that STARTRECT (2) is GONE, which
  #    stays a real predicate for every $nm including rect itself -- `arm_menu rect` under
  #    infix_interface 0 re-arms through MENUSTART, so a surviving STARTRECT can only be the old one.
  set ::infix_interface 0
  mkdoc ; set ::infix_interface 1 ; arm_live rect ; set ::infix_interface 0
  check "C4 $nm: prior rect is live"         [shapebits] 2
  arm_menu $nm
  check "C4 $nm over rect: old rect gone"    [expr {[ui] & 2}] 0
  check "C4 $nm over rect: new shape armed"  [menushape] 1
  set ::infix_interface 1
  xschem abort_operation ; xschem abort_operation
}

# C5 -- the truncated coordinate form is an ARM (plan landmine 3), so it is gated like any other:
#    `rect gui` + `rect 10 20` was ui_state 65538, two rectangles armed at once.
mkdoc ; arm_live rect
check "C5 prior rect live"                   [shapebits] 2
xschem rect 10 20
check "C5 truncated form tore it down"       [expr {[ui] & 2}] 0
check "C5 ...and armed its own"              [menushape] 1
check "C5 ...and stored nothing"             [rects] 0
xschem abort_operation ; xschem abort_operation

# ===========================================================================
# D. BOTH INTERFACE BRANCHES for arc / circle / zoom (plan landmine 5). These three arm MENUSTART
#    in BOTH branches, so their CLICKED state exists only past the seam -- which is precisely the
#    state a gate written against ui_state alone would cover and a gate written against ui_state2
#    alone would miss.
# ===========================================================================
foreach infix {1 0} {
  set ::infix_interface $infix
  foreach nm {arc circle zoom} {
    mkdoc ; arm_menu $nm
    check "D infix$infix $nm menu: armed"      [menushape] 1
    xschem wire gui
    check "D infix$infix $nm menu: gate fired" [shape] 0
    check "D infix$infix $nm menu: ui2 clean"  [expr {[ui2] & 236}] 0
    xschem abort_operation ; xschem abort_operation

    mkdoc ; arm_live $nm
    check "D infix$infix $nm clicked: armed"   [shapebits] [expr {$nm eq "zoom" ? 128 : 4096}]
    xschem wire gui
    check "D infix$infix $nm clicked: gate fired" [shape] 0
    check "D infix$infix $nm clicked: wire live"  [wiredraw] 1
    xschem abort_operation ; xschem abort_operation
  }
}
set ::infix_interface 1

# ===========================================================================
# E. CONTROLS. Without these a green suite could mean "the gate never runs" or "the gate fires
#    everywhere, including where it must not".
# ===========================================================================

# E1 -- PURE-COMMIT FORMS ARE NEVER GATED (plan landmine 2). These commit an object outright and
#    are the replay/action-log seams; aborting a live gesture from one would be a silent mutation.
#    Watch the truncated-arg quirk (landmine 3): `xschem rect 10 20` is an ARM, not a commit, and
#    IS gated -- pinned by C4 above.
mkdoc ; arm_live rect ; xschem rect 10 20 30 40
check "E1 commit rect: not gated"         [shapebits] 2
check "E1 commit rect: stored"            [rects] 1
xschem abort_operation ; xschem abort_operation
mkdoc ; arm_live rect ; xschem polygon 10 10 20 10 20 20
check "E1 commit polygon: not gated"      [shapebits] 2
check "E1 commit polygon: stored"         [polys] 1
xschem abort_operation ; xschem abort_operation
mkdoc ; arm_live rect ; xschem arc 50 50 20 0 360 4
check "E1 commit arc: not gated"          [shapebits] 2
check "E1 commit arc: stored"             [arcs] 1
xschem abort_operation ; xschem abort_operation
mkdoc ; arm_live rect ; xschem wire 2000 2000 2100 2000
check "E1 commit wire: not gated"         [shapebits] 2
check "E1 commit wire: stored"            [xschem get wires] 3
xschem abort_operation ; xschem abort_operation
mkdoc ; arm_live zoom ; xschem zoom_box 0 0 100 100
check "E1 commit zoom_box: not gated"     [shapebits] 128
xschem abort_operation ; xschem abort_operation

# E2 -- THE SEAM ITSELF. `xschem test_gate_bypass 1` must really disable the SHAPE gate too, or a
#    green section B could mean the gate never ran (issue 0265 E6e is the worked example).
check "E2 bypass off by default"          [xschem test_gate_bypass] 0
mkdoc ; arm_live rect
xschem test_gate_bypass 1
xschem wire gui
check "E2 bypassed: rect survives"        [shapebits] 2
check "E2 bypassed: wire armed too"       [startwire] 1
check "E2 bypassed: gate stayed silent"   [msg] "-"
xschem test_gate_bypass 0
check "E2 bypass switches back off"       [xschem test_gate_bypass] 0
xschem abort_operation ; xschem abort_operation
mkdoc ; arm_live rect ; xschem wire gui
check "E2 gate live again: rect gone"     [shapebits] 0

# E3 -- READ-ONLY. Unlike the placement and merge gates this one has NO readonly refusal, because
#    it runs no delete(): there is nothing a read-only buffer needs protecting from. That is not
#    cosmetic -- the zoom box is a VIEW gesture with no readonly reject of its own, so it is the one
#    shape a read-only window can arm, and a refusal here would leave exactly that case ungated.
#    Every EDIT shape is refused at the verb instead (`rect`/`polygon`/`arc`/`circle` all run
#    scheduler_readonly_reject), so the row also pins that half.
mkdoc ; xschem set readonly 1
check "E3 readonly: window is read-only"  [xschem get readonly] 1
foreach nm {rect polygon arc circle} {
  catch {arm_menu $nm}
  check "E3 readonly: $nm arm refused"    [shape] 0
}
arm_menu zoom
check "E3 readonly: zoom box still arms"  [shape] 1
arm_menu zoom
check "E3 readonly: teardown ran anyway"  [msg] "Zoom box: in-progress shape abandoned"
check "E3 readonly: exactly one armed"    [shape] 1
xschem abort_operation
check "E3 readonly: ESC clears it"        [shape] 0
xschem set readonly 0
check "E3 readonly cleared"               [xschem get readonly] 0
xschem abort_operation ; xschem abort_operation

# E4 -- undo/redo ARE gated (unlike the merge gate, which they deliberately skip). A shape
#    teardown runs no delete() and pushes no undo, so there is nothing for the pop to invert --
#    and the pop's own unselect_all(0) would otherwise drop the bits with the band still stroked.
#    The control: undo must still do its job with a shape armed on top of it.
mkdoc ; xschem wire 2000 2000 2100 2000
check "E4 control: wire committed"        [xschem get wires] 3
arm_live rect
xschem undo
check "E4 shape gone at the undo"         [shape] 0
check "E4 undo still undid the wire"      [xschem get wires] 2
xschem abort_operation ; xschem abort_operation

# E5 -- the teardown consumes no undo slot of its own: abandoning a shape then undoing must reach
#    the last REAL edit, not an undo record the abandon pushed.
mkdoc ; xschem wire 2000 2000 2100 2000
arm_live rect ; xschem line gui ; xschem abort_operation ; xschem abort_operation
xschem undo
check "E5 abandon pushed no undo record"  [xschem get wires] 2

# E6 -- the gate MESSAGE (issue 0248), the entire user-visible half of the policy.
mkdoc ; arm_live rect ; xschem wire gui
check "E6 message lands"                  [msg] "Wire: in-progress shape abandoned"
check "E6 message is held"                [hold] 1
xschem abort_operation ; xschem abort_operation
mkdoc ; arm_live polygon ; xschem place_symbol devices/lab_pin.sym
check "E6 placement verb names itself"    [msg] "Insert symbol: in-progress shape abandoned"
xschem abort_operation ; xschem abort_operation
mkdoc ; xschem wire gui
check "E6 silent when no shape is live"   [msg] "-"
xschem abort_operation ; xschem abort_operation

# E7 -- the NON-shape MENUSTART arms must survive a shape teardown. ui_state2 also carries pending
#    move / copy / wirecut / rotate / descend, none of which owns a rubber band; abort_shape_draw()
#    clears MENUSTART only when the bit qualifying it IS a shape. abort_wire_line_command() zeroes
#    the word wholesale, which is safe only because it has already identified a wire/line arm --
#    the same blanket clear here would silently cancel a pending descend pick.
mkdoc ; xschem descend_pick
check "E7 descend pick armed"             [menustart] 1
check "E7 descend bit set"                [expr {[ui2] & 32768}] 32768
xschem rect gui                            ;# runs leave_shape_draw_for() and must find nothing
check "E7 shape teardown kept MENUSTART"  [menustart] 1
check "E7 shape teardown kept the bit"    [expr {[ui2] & 32768}] 32768
check "E7 and the rect armed on top"      [shapebits] 2
xschem abort_operation ; xschem abort_operation

# ===========================================================================
# F. THE POLYGON, ratified 2026-08-09: a competing gesture ABANDONS an in-progress polygon, while
#    ESC keeps COMMITTING it. The two are not in tension -- ESC is the gesture's own terminal and
#    closing the polygon is its documented meaning (abort_operation() calls new_polygon(END), which
#    store_poly + push_undo + self-logs `xschem polygon ...`), whereas a second gesture is the
#    ratified "whatever you just pressed is what you meant" rule. Silently committing a half-drawn
#    polygon because the user pressed `w` is the issue 0265 defect class.
# ===========================================================================
mkdoc_clean ; arm_live polygon
check "F1 polygon armed"                  [shapebits] 2048
xschem wire gui
check "F1 gate abandoned it"              [shapebits] 0
check "F1 nothing stored"                 [polys] 0
check "F1 no action-log line either"      [polys] 0
check "F1 document still clean"           [xschem get modified] 0
xschem abort_operation ; xschem abort_operation

mkdoc_clean ; arm_live polygon
xschem abort_operation
check "F2 ESC still COMMITS the polygon"  [polys] 1
check "F2 and the commit dirties"         [xschem get modified] 1

# F3 -- issue 0270: arming a polygon used to dirty a CLEAN document with nothing stored, because
#    set_modify(1) sat in new_polygon(PLACE) and was the polygon's only modify write. Harmless
#    while ESC (which commits) was the only exit; a lie the moment a gate can abandon the gesture.
mkdoc_clean
check "F3 clean document"                 [xschem get modified] 0
arm_live polygon
check "F3 polygon ARM does not dirty"     [xschem get modified] 0
xschem abort_operation
check "F3 but the ESC commit does"        [xschem get modified] 1
foreach nm {rect arc circle zoom} {
  mkdoc_clean ; arm_live $nm
  check "F3 control: $nm arm does not dirty" [xschem get modified] 0
  xschem abort_operation ; xschem abort_operation
}

# F4 -- the point buffers. Only the commit branch frees nl_polyx/nl_polyy and zeroes nl_points, so
#    an abandoning teardown owes them by hand -- AFTER the band erase, which reads them. If they
#    leaked, the NEXT polygon would inherit the abandoned one's vertices.
mkdoc_clean
arm_live polygon ; xschem wire gui ; xschem abort_operation ; xschem abort_operation
arm_live polygon ; xschem abort_operation
check "F4 second polygon commits alone"   [polys] 1
xschem saveas [file join $::d0269 poly2.sch]
set fh [open [file join $::d0269 poly2.sch] r] ; set body [read $fh] ; close $fh
set prec 0 ; foreach ln [split $body "\n"] { if {[string match "P *" $ln]} { incr prec } }
check "F4 exactly one P record on disk"   $prec 1

# ===========================================================================
# G. ISSUE 0268 -- ui_state2 survived ESC. clear_orphan_gesture_bits() cleared ui_state bits only,
#    so `arc gui` + `wire gui` + ESC left ui_state 0 with ui_state2 = MENUSTARTARC (measured; also
#    4 / 32 / 128 / 8 for rect / polygon / circle / zoom). The census verdict was INERT -- every
#    reader tests MENUSTART in ui_state first and every arm ASSIGNS ui_state2 wholesale, so a stale
#    bit can never be misread as a live arm -- i.e. a reporting lie, not a behavioural defect. It
#    is fixed here by construction, because abort_shape_draw() owns the pair and clears both.
#    The assertion is scoped to MENUSTARTSHAPE (236) rather than `ui_state2 == 0`, because that is
#    exactly what this teardown owns; the rest of the word is asserted intact by E7.
# ===========================================================================
foreach infix {1 0} {
  set ::infix_interface $infix
  foreach {nm armv} $::ARMS {
    mkdoc ; arm_menu $nm ; xschem wire gui ; xschem abort_operation
    check "G infix$infix $nm menu: ui_state clear"   [ui] 0
    check "G infix$infix $nm menu: shape bits clear" [expr {[ui2] & 236}] 0
    xschem abort_operation
    # ...and past the click, where MENUSTART is already gone and only the discriminator remains --
    # the half a teardown gated on `MENUSTART && ui_state2` would miss.
    mkdoc ; arm_live $nm ; xschem wire gui
    check "G infix$infix $nm clicked: shape bits clear" [expr {[ui2] & 236}] 0
    xschem abort_operation ; xschem abort_operation
  }
}
set ::infix_interface 1

# G2 -- the WIRE family has the same residue and this fix does NOT close it: under
#    infix_interface 0, `xschem wire gui` assigns ui_state2 = MENUSTARTWIRE and ESC leaves it there
#    (abort_operation never calls abort_wire_line_command(), which is the only thing that zeroes
#    the word). Measured, reported rather than papered over, and INERT by the same domination
#    argument. It is asserted here so the day it changes, something says so.
set ::infix_interface 0
mkdoc ; xschem wire gui ; xschem abort_operation ; xschem abort_operation
check "G2 wire-family residue is still there" [expr {[ui2] & 1}] 1
check "G2 ...with ui_state clean"             [ui] 0
set ::infix_interface 1
xschem abort_operation ; xschem abort_operation

# ===========================================================================
# H. The three ungated doors this phase's census MEASURED, filed as issues 0271 and 0272.
# ===========================================================================

# H1 -- issue 0271: a MERGE did not cancel a live wire/line draw. Plan phase 4 recorded that it
#    already did, "because merge_file() calls leave_placement_for(), which is the wire/line
#    teardown too" -- false: leave_placement_for() calls abort_placement_preview(), which has
#    never looked at STARTWIRE|STARTLINE. Measured pre-fix: `wire gui` + `merge` -> ui_state 297
#    (STARTWIRE|STARTMOVE|SELECTION|STARTMERGE), last_command still 1.
mkdoc ; xschem wire gui
check "H1 wire draw live"                 [startwire] 1
xschem merge $::src0269
check "H1 merge cancels the wire draw"    [startwire] 0
check "H1 merge cancels wire mode"        [lc] 0
check "H1 and the paste is pending"       [merging] 1
xschem abort_operation ; xschem abort_operation
mkdoc ; xschem line gui ; xschem merge $::src0269
check "H1 merge cancels a line draw"      [startline] 0
xschem abort_operation ; xschem abort_operation
#    the RESTING command mode is the third wire/line state and the one ui_state cannot see
mkdoc ; xschem wire gui ; xschem abort_operation
check "H1 resting mode armed"             [lc] 1
xschem merge $::src0269
check "H1 merge leaves resting mode"      [lc] 0
xschem abort_operation ; xschem abort_operation
#    ...and the clipboard door, which is the same funnel
prime_clip ; xschem wire gui ; xschem paste
check "H1 paste cancels the wire draw"    [startwire] 0
xschem abort_operation ; xschem abort_operation

# H2 -- issue 0272: `xschem circle` and `xschem zoom_box` carried NO gate at all, while their key
#    and context-menu twins have been gated since phase 1. Measured pre-fix: `wire gui` + `circle`
#    -> ui_state 65537 with last_command 1.
foreach {nm cmd} {circle {xschem circle} zoom_box {xschem zoom_box}} {
  mkdoc ; xschem wire gui ; eval $cmd
  check "H2 $nm cancels a wire draw"      [startwire] 0
  check "H2 $nm cancels wire mode"        [lc] 0
  check "H2 $nm armed itself"             [shape] 1
  xschem abort_operation ; xschem abort_operation
  mkdoc ; xschem add_sch_pin -place ; eval $cmd
  check "H2 $nm cancels a placement"      [placing] 0
  check "H2 $nm fixture whole"            [intact] "2/1/1"
  xschem abort_operation ; xschem abort_operation
  mkdoc ; xschem merge $::src0269 ; eval $cmd
  check "H2 $nm cancels a pending paste"  [merging] 0
  check "H2 $nm fixture whole after paste" [intact] "2/1/1"
  xschem abort_operation ; xschem abort_operation
}

set ::infix_interface $saved_infix
xschem abort_operation ; xschem abort_operation

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
