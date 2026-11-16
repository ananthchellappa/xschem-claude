# tests/headless/test_selection_look_pixels.tcl -- the selection looks on screen
# (doc/claude/selection_look_batch/PLAN.md, stage C).
#
# `selection_style` is classic | bright | brightbox | halo, default brightbox. The styled looks
# (every one but classic) paint the selection on the WINDOW only, as an overlay that each
# gesture erases and repaints in part; the backing pixmap and `xschem print` never hold it. So
# this suite reads the window itself, in process, through `xschem window_snapshot`
# (src/scheduler.c), and asks of every gesture one question: is what the window shows what a
# fresh full redraw of the same state shows? A styled look that erases too little leaves a
# residue, one that repaints too little leaves a hole, and both read as differing pixels.
#
# Bands:
#   M  View > Selection look: four radio entries in order with their values, the default, and
#      that choosing one applies it at once
#   R  residue: after each gesture the canvas equals a fresh full redraw, in brightbox (box
#      width 1, the default, and 9), bright and halo
#   B  brightbox draws a box: where it differs from bright it is the selection colour, on the
#      hover outline's own rectangle (a net label's too, which is its text's); a wire's box shows
#      only once it is wider than the wire
#   C  classic: the selection is painted in layer 2's grey and nothing else, a selected text is a
#      box outline, and an unselect erases back
#   H  a hide=op text stays hidden when its instance is selected, in every styled look; a hidden
#      floating text, selected, gets no letters and no band, only classic's mark (its box, in
#      brightbox the selection box), and is selected as any text is once shown
#   D  a text on a layer unticked in View > Show > Visible layers, or left out by
#      draw_single_layer (the > key), is selected as a hidden one is (H), a floating note and
#      M1's texts alike; halo repaints in its own colours nothing draw() leaves out
#   O  a selection_text_own_px that is not a number draws as the default 16 does
#   L  the look against what it is meant to be, not against a redraw (which paints the same look,
#      right or wrong): the documented colours and selection_color, a text's letters in bright
#      and brightbox with no box on classic's outline in bright, halo's band and its height, and a
#      typed selection_style taking effect on the next redraw
#   S  the snapshot hook's region arguments: a region past the int range is an error
#
# Needs X (the subject is window pixels); under --nogui it says so and stops. Registered in
# dcases alone. Run it armed:  tests/headless/run_suites.sh test_selection_look_pixels
# scratch.tcl arms the in-suite watchdog: this suite pumps the event loop with `update`.
source [file join [file dirname [info script]] scratch.tcl]

set ::fail 0 ; set ::npass 0
proc check {name got want} {
  if {$got eq $want} { puts "ok:   $name" ; incr ::npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr ::fail }
}
proc finish {} {
  catch {xschem window_snapshot free}
  if {$::fail == 0} {
    puts "RESULT: ALL PASS ($::npass checks)"
    puts "OVERALL: ok ($::npass checks)"
  } else {
    puts "RESULT: $::fail FAILED ($::npass passed)"
  }
  flush stdout
  exit [expr {$::fail == 0 ? 0 : 1}]
}
if {![info exists ::has_x]} {
  puts "RESULT: SKIP (no X: this suite reads window pixels; run it on a display)"
  puts "OVERALL: ok (0 checks)"
  exit 0
}

set dir [test_scratch sellookpx]

## The fixture: one of each object the overlay paints, from xschem_library/devices, plus:
##   - two floating texts, one rendered above selection_text_own_px's default 16 px (it gets
##     halo's band) and one below it (plain colour), at the zoom load_fixture sets;
##   - ZZ_FLOAT_HIDDEN, a floating text carrying hide=voltage, shown only while annot_show has
##     its voltage bit, and ZZ_TRUE, one carrying hide=true, shown only with show_hidden_texts;
##   - zz1, an instance of zz_opc.sym standing in for an operating-point annotator: a box with
##     one text inside it carrying hide=op (shown only while annot_show has its op bit). The
##     text sits INSIDE the box, so inside the area the selection overlay repaints for the
##     instance whether or not the text is counted in its bbox (symbol_bbox() leaves a hidden
##     text out): an overlay that drew the hidden text would show it there. Nothing else lies
##     in the text's screen area.
set f [open [file join $dir zz_opc.sym] w]
puts $f {v {xschem version=3.4.6 file_version=1.2}
G {}
K {type=annotator
template="name=zz1"}
V {}
S {}
E {}
L 4 0 0 110 0 {}
L 4 110 0 110 40 {}
L 4 110 40 0 40 {}
L 4 0 40 0 0 {}
T {ZZ_OP_HIDDEN} 15 12 0 0 0.2 0.2 {hide=op}}
close $f
set fixture "v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
L 4 560 -190 620 -170 {}
B 4 560 -230 620 -200 {}
P 4 4 560 -160 620 -160 590 -130 560 -160 {}
A 4 600 -90 15 0 270 {}
T {floating note} 300 -200 0 0 0.3 0.3 {}
T {small note} 300 -235 0 0 0.12 0.12 {}
T {ZZ_FLOAT_HIDDEN} 480 -270 0 0 0.3 0.3 {hide=voltage}
T {ZZ_TRUE} 435 -100 0 0 0.3 0.3 {hide=true}
N 340 -140 410 -140 {lab=A}
N 410 -140 410 -60 {lab=A}
C {nmos4.sym} 470 -140 0 0 {name=M1 model=nmos w=5u l=0.18u m=1}
C {res.sym} 410 -30 0 0 {name=R1 value=1k footprint=1206 device=resistor}
C {lab_pin.sym} 340 -140 0 0 {name=p1 lab=A}
C {[file join $dir zz_opc.sym]} 280 -50 0 0 {name=zz1}
"
foreach nm {fix.sch fix2.sch} {
  set f [open [file join $dir $nm] w] ; puts -nonewline $f $fixture ; close $f
}

## ---------------------------------------------------------------------------------------------
## Drives: the shapes stage A7's rows used (doc/claude/selection_look_batch/receipts/).
proc settle {} { update ; after 40 ; update }
proc snap {s} { settle ; xschem window_snapshot take $s }
## schematic -> window pixel, from the live transform (X_TO_SCREEN in src/xschem.h)
proc w2s {x y} {
  list [expr {int(($x + [xschem get xorigin]) / [xschem get zoom])}] \
       [expr {int(($y + [xschem get yorigin]) / [xschem get zoom])}]
}
set ::LPX 10 ; set ::LPY 10
proc motion {x y {st 0}} {
  lassign [w2s $x $y] px py ; set ::LPX $px ; set ::LPY $py
  event generate .drw <Motion> -x $px -y $py -state $st -when now ; update
}
proc press {x y {b 1} {st 0}} {
  lassign [w2s $x $y] px py
  event generate .drw <ButtonPress-$b> -x $px -y $py -state $st -when now ; update
}
proc release {x y {b 1} {st 0}} {
  lassign [w2s $x $y] px py
  event generate .drw <ButtonRelease-$b> -x $px -y $py -state [expr {$st | (256 << ($b - 1))}] \
    -when now
  update
}
proc enter {x y} {
  lassign [w2s $x $y] px py ; event generate .drw <Enter> -x $px -y $py -when now ; update
}
proc key {k {st 0}} {
  focus -force .drw
  event generate .drw <KeyPress-$k> -x $::LPX -y $::LPY -state $st -when now
  event generate .drw <KeyRelease-$k> -x $::LPX -y $::LPY -state $st -when now
  update
}
proc wheel {b x y} {
  lassign [w2s $x $y] px py
  event generate .drw <ButtonPress-$b> -x $px -y $py -when now
  event generate .drw <ButtonRelease-$b> -x $px -y $py -when now
  update
}
## the look in force, as sel_style_sync() resolved it
proc look_now {} { return [dict get [xschem get selection_look] style] }
proc set_look {st} {
  set ::selection_style $st ; xschem build_colors ; xschem redraw ; settle
}
## what the window shows against a fresh full redraw of the same state: "n x1 y1 x2 y2"
proc vs_redraw {} {
  snap 6 ; xschem redraw ; snap 7 ; return [xschem window_snapshot diff 6 7]
}
## one residue row; `legs` are further {got want} pairs that keep the row from being vacuous
proc rrow {id what {legs {}}} {
  set d [vs_redraw]
  set got [list [lindex $d 0]] ; set want 0
  foreach {g w} $legs { lappend got $g ; lappend want $w }
  check "R $::LOOK $id: $what -- the canvas equals a fresh full redraw (differing px)" $got $want
  if {[lindex $d 0] != 0} { puts "  detail: $::LOOK $id differing px and bbox: $d" }
}
## the bounding box of what changed between two captures, padded, as x y w h ({} if nothing)
proc changed_rect {a b {pad 2}} {
  lassign [xschem window_snapshot diff $a $b] n x1 y1 x2 y2
  if {$n == 0} { return {} }
  return [list [expr {$x1 - $pad}] [expr {$y1 - $pad}] [expr {$x2 - $x1 + 1 + 2 * $pad}] \
               [expr {$y2 - $y1 + 1 + 2 * $pad}]]
}
## r (x y w h) moved d px inwards on every side (outwards for a negative d). An empty r stays
## empty, and `inside` answers 0 for it, so a look that draws no mark reddens the rows that read
## one instead of raising out of the suite and taking every later row with it
proc shrink {r d} {
  if {$r eq {}} { return {} }
  lassign $r x y w h
  return [list [expr {$x + $d}] [expr {$y + $d}] [expr {$w - 2 * $d}] [expr {$h - 2 * $d}]]
}
## does a diff (n x1 y1 x2 y2) change something, all of it within r?
proc inside {d r} {
  if {$r eq {}} { return 0 }
  lassign $d n x1 y1 x2 y2
  lassign $r x y w h
  expr {$n > 0 && $x1 >= $x && $y1 >= $y && $x2 < $x + $w && $y2 < $y + $h}
}
## the most frequent colour capture b holds inside r where it differs from capture a ({} if none)
proc top_in {a b r} {
  set d {}
  foreach p [region $a $r] q [region $b $r] { if {$p ne $q} { dict incr d $q } }
  return [lindex [lsort -stride 2 -index 1 -integer -decreasing $d] 0]
}
proc region {slot r} {
  if {$r eq {}} { return {} }
  return [xschem window_snapshot pixels $slot {*}$r]
}
## positions where two equal-length pixel lists differ
proc ndiff {pa pb} {
  set n 0 ; foreach a $pa b $pb { if {$a ne $b} { incr n } } ; return $n
}
proc ncolour {px c} {
  set n 0 ; foreach p $px { if {$p eq $c} { incr n } } ; return $n
}
## annot_show as the Simulation menu writes it: the mask, then every instance's bbox again, since
## an instance's bbox holds only its visible texts (symbol_bbox() in src/select.c)
proc annot {m} { xschem set annot_show $m ; xschem update_all_sym_bboxes ; xschem redraw }
## the most frequent colour capture b holds where it differs from capture a
proc top_colour {a b} { return [lindex [xschem window_snapshot colors $a $b] 0] }

## indices of the fixture's objects, resolved from the loaded sheet, not assumed
proc find_objs {} {
  set ::rc [xschem get rectcolor]
  set ::wn -1
  for {set i 0} {$i < [xschem get wires]} {incr i} {
    if {[xschem wire_coord $i] eq {340 -140 410 -140}} { set ::wn $i }
  }
  set ::tn -1 ; set ::ts -1 ; set ::th -1 ; set ::tt -1
  for {set i 0} {$i < [xschem get texts]} {incr i} {
    switch -- [xschem getprop text $i txt_ptr] {
      {floating note} { set ::tn $i }
      {small note} { set ::ts $i }
      ZZ_FLOAT_HIDDEN { set ::th $i }
      ZZ_TRUE { set ::tt $i }
    }
  }
}
proc select_set {} {
  xschem select instance M1 ; xschem select instance p1 ; xschem select wire $::wn
  xschem select text $::tn ; xschem select text $::ts
  catch {xschem select rect $::rc 0} ; catch {xschem select line $::rc 0}
  catch {xschem select poly $::rc 0} ; catch {xschem select arc $::rc 0}
  settle
}
proc load_fixture {} {
  xschem set modified 0
  xschem load [file join $::dir fix.sch]
  settle
  xschem zoom_box 270 -280 640 0
  xschem redraw ; settle
  find_objs
}

set ::hover_highlight 0
set ::draw_crosshair 0
wm geometry . 900x700+0+0
update
## the dark scheme, the default, pinned: band C compares colours
if {!$::dark_colorscheme} { xschem toggle_colorscheme }
set hw0 $::hover_highlight_width
load_fixture
check "F1 the fixture loaded: 4 instances, 2 wires, 4 texts, each object found" \
  [list [xschem get instances] [xschem get wires] [xschem get texts] \
        [expr {$::wn >= 0 && $::tn >= 0 && $::ts >= 0 && $::th >= 0 && $::tt >= 0}]] {4 2 4 1}

## ---------------------------------------------------------------------------------------------
## M -- the menu, read from the widget the user clicks rather than from src/xschem.tcl's text.
set m .menubar.view.sellook
set ents {}
if {[winfo exists $m]} {
  for {set i 0} {$i <= [$m index end]} {incr i} {
    lappend ents [list [$m type $i] [$m entrycget $i -label] [$m entrycget $i -value] \
                       [$m entrycget $i -variable]]
  }
}
check "M1 View > Selection look holds four radio entries, in order, each with its value" $ents \
  [list {radiobutton Classic classic selection_style} {radiobutton Bright bright selection_style} \
        {radiobutton {Bright with box} brightbox selection_style} \
        {radiobutton Halo halo selection_style}]
check "M2 the default look: selection_style is brightbox and the C side resolved it so" \
  [list $::selection_style [look_now]] {brightbox brightbox}
check "M3 brightbox's box is as wide as hover_highlight_width (box_px, set beside the hover GC)" \
  [dict get [xschem get selection_look] box_px] $::hover_highlight_width
xschem select instance M1 ; xschem select text $::tn ; settle
set menu_seen {}
foreach i {0 1 2 3} {
  if {[catch {$m invoke $i}]} { lappend menu_seen ERR ; continue }
  settle
  lappend menu_seen [list $::selection_style [look_now] [lindex [vs_redraw] 0]]
}
check "M4 each entry, invoked with a selection up, sets the variable, resolves the look and\
 leaves the canvas equal to a fresh redraw" $menu_seen \
  {{classic classic 0} {bright bright 0} {brightbox brightbox 0} {halo halo 0}}
xschem unselect_all

## ---------------------------------------------------------------------------------------------
## R -- residue rows, one pass per look.
proc residue_pass {} {
  load_fixture
  set ::hover_highlight 0
  xschem unselect_all ; settle
  select_set
  rrow r01 "select one of each object" [list [xschem get lastsel] 9]
  xschem select instance M1 clear ; settle
  rrow r02 "deselect one (the FET)"
  motion 300 -110 ; press 300 -110 ; release 300 -110 ; after 200 ; settle
  rrow r03 "click on nothing" [list [xschem get lastsel] 0]
  xschem select_all ; settle
  rrow r04 "select-all"
  xschem unselect_all ; settle
  rrow r05 "unselect-all"
  motion 285 -275 ; press 285 -275
  foreach {x y} {320 -250 380 -220 440 -180 500 -120} { motion $x $y 256 }
  release 500 -120 ; after 300 ; settle
  rrow r06 "rubber band released" [list [expr {[xschem get lastsel] > 0}] 1]
  xschem unselect_all ; select_set
  set ::hover_highlight 1
  enter 300 -110 ; motion 300 -110 ; settle
  motion 470 -140 ; settle
  rrow r07 "hover onto a selected FET"
  motion 300 -110 ; settle
  rrow r08 "hover off it"
  motion 300 -201 ; settle
  rrow r09 "hover onto a selected text"
  motion 300 -110 ; settle
  ## a hover outline stamped over a selected FET, then a neighbour selected and deselected: the
  ## neighbour's repair must not repaint the FET's overlay over the outline outside its own rect
  motion 470 -140 ; settle
  xschem select instance R1 ; settle
  rrow r10 "hover on a selected FET, then a neighbour selected"
  xschem select instance R1 clear ; settle
  rrow r11 "then the neighbour deselected"
  set ::hover_highlight 0 ; motion 300 -111 ; settle ; xschem redraw ; settle
  xschem unselect_all ; xschem select instance M1 ; xschem select text $::tn ; settle
  set b0 [lrange [xschem instance_bbox M1] 1 4]
  motion 470 -140 ; key m
  foreach {x y} {475 -140 480 -130 490 -120 500 -110} { motion $x $y }
  rrow r12 "drag, mid-move"
  press 500 -110 ; release 500 -110 ; after 400 ; settle
  set b1 [lrange [xschem instance_bbox M1] 1 4]
  rrow r13 "drag ended" [list [expr {$b1 ne $b0}] 1]
  motion 500 -110 ; key m
  foreach {x y} {505 -115 515 -120 525 -125} { motion $x $y }
  key Escape ; after 300 ; settle
  rrow r14 "drag cancelled with Escape" [list [lrange [xschem instance_bbox M1] 1 4] $b1]
  motion 300 -110 ; key u ; settle
  rrow r15 "undo by the U key" [list [lrange [xschem instance_bbox M1] 1 4] $b0]
  xschem unselect_all ; select_set
  xschem zoom_in ; settle
  rrow r16 "zoom in"
  xschem zoom_out ; settle
  rrow r17 "zoom out"
  wheel 4 450 -150 ; settle
  rrow r18 "wheel up"
  wheel 5 450 -150 ; settle
  rrow r19 "wheel down"
  xschem pan right ; settle
  rrow r20 "pan by command"
  xschem pan left ; settle
  motion 450 -150 ; press 450 -150 2
  foreach {x y} {440 -150 430 -145 420 -140} { motion $x $y 512 }
  release 420 -140 2 ; after 200 ; settle
  rrow r21 "pan by middle-drag"
  xschem zoom_box 270 -280 640 0 ; settle
  xschem setprop instance p1 lab A_MUCH_LONGER_NET_NAME ; settle
  rrow r22 "a property edit that grows a selected label"
  xschem setprop instance p1 lab A ; settle
  rrow r23 "a property edit that shrinks it back"
  xschem setprop text $::tn txt_ptr x ; settle
  rrow r24 "a selected floating text shrunk by a property edit"
  xschem setprop text $::tn txt_ptr {floating note} ; settle
  rrow r25 "and grown back"
  foreach {id frac} {r26 0.3 r27 0.8} {
    set w [winfo width .drw] ; set h [expr {int([winfo height .drw] * $frac)}]
    toplevel .cov -width $w -height $h -background red
    wm overrideredirect .cov 1
    wm geometry .cov ${w}x${h}+[winfo rootx .drw]+[expr {[winfo rooty .drw] + 100}]
    update ; after 150 ; update
    destroy .cov
    update ; after 150 ; update
    rrow $id "an Expose of [expr {int($frac * 100)}]% of the canvas"
  }
  set w [winfo width .drw] ; set h [expr {int([winfo height .drw] * 0.5)}]
  toplevel .cov -width $w -height $h -background red ; wm overrideredirect .cov 1
  wm geometry .cov ${w}x${h}+[winfo rootx .drw]+[winfo rooty .drw]
  update ; after 150 ; update
  xschem select instance M1 clear ; xschem select instance R1 ; settle
  destroy .cov ; update ; after 150 ; update
  rrow r28 "a selection change while half the canvas was covered, then uncovered"
  ## zoom far in and far out with a selection up (lines wider than the pads, then hairlines)
  xschem unselect_all ; xschem select instance M1 ; xschem select text $::tn
  xschem select instance p1 ; settle
  motion 470 -140
  for {set i 0} {$i < 12} {incr i} { xschem zoom_in }
  settle
  rrow r29 "zoomed in twelve steps"
  xschem select instance M1 clear ; settle
  rrow r30 "a deselect there"
  xschem select instance M1 ; settle
  rrow r31 "a reselect there"
  xschem zoom_full ; settle
  for {set i 0} {$i < 14} {incr i} { xschem zoom_out }
  settle
  rrow r32 "zoomed out fourteen steps"
  xschem select instance R1 ; settle
  rrow r33 "a select there"
  xschem unselect_all ; settle
  rrow r34 "an unselect-all there"
  xschem zoom_box 270 -280 640 0 ; settle
  ## the box width changed while objects are selected (the GC is rebuilt by build_colors)
  select_set
  set old $::hover_highlight_width
  set ::hover_highlight_width [expr {$old > 4 ? 1 : 9}] ; xschem build_colors ; settle
  xschem select_all ; settle
  rrow r35 "hover_highlight_width changed, then select-all"
  xschem unselect_all ; settle
  rrow r36 "then unselect-all"
  set ::hover_highlight_width $old ; xschem build_colors ; xschem redraw ; settle
  ## the second tab
  xschem new_schematic switch $::TAB ; settle
  xschem unselect_all ; settle
  xschem select instance M1 ; xschem select instance R1 ; settle
  rrow r37 "the second tab, two objects selected there"
  xschem new_schematic switch .drw ; settle
  rrow r38 "back to the first tab"
  xschem new_schematic switch $::TAB ; settle
  rrow r39 "forth to the second tab"
  xschem select instance M1 clear ; settle
  rrow r40 "a deselect in the second tab"
  xschem set modified 0
  xschem new_schematic switch .drw ; settle
  xschem unselect_all ; settle
  rrow r41 "an unselect-all back in the first tab"
  xschem set modified 0
}
## the second tab, opened once: opening a file a tab already holds asks the user
## (new_schematic create), and nothing here could answer
xschem new_schematic create {} [file join $dir fix2.sch] ; settle
set ::TAB [xschem get current_win_path]
xschem zoom_box 270 -280 640 0 ; settle
xschem new_schematic switch .drw ; settle
check "F2 a second tab is open" [expr {$::TAB ne {.drw} && $::TAB ne {}}] 1
foreach {::LOOK st w} {brightbox brightbox 1 bright bright 1 halo halo 1 brightbox-w9 brightbox 9} {
  set ::hover_highlight_width $w
  set_look $st
  check "R $::LOOK r00 the look in force is $st, box width $w" \
    [list [look_now] [dict get [xschem get selection_look] box_px]] [list $st $w]
  residue_pass
}
set ::hover_highlight_width $hw0 ; xschem build_colors

## ---------------------------------------------------------------------------------------------
## B -- brightbox draws a box. Slots: 0 nothing selected, 2 bright with the FET selected, 3
## brightbox with the FET selected, 4 bright with the FET selected and hovered.
set ::LOOK B
load_fixture
set_look bright ; snap 0
xschem select instance M1 ; snap 2
set selcol [top_colour 0 2]
set_look brightbox ; snap 3
set bdiff [xschem window_snapshot diff 2 3]
check "B1 with a FET selected, brightbox differs from bright, and only in the selection colour\
 ($selcol, the colour bright strokes the FET with)" \
  [list [expr {[lindex $bdiff 0] > 0}] [dict keys [xschem window_snapshot colors 2 3]]] \
  [list 1 [list $selcol]]
set_look bright
set ::hover_highlight 1
enter 300 -110 ; motion 470 -140 ; snap 4
set hdiff [xschem window_snapshot diff 2 4]
set ::hover_highlight 0 ; motion 300 -110 ; settle
set r [changed_rect 2 4]
set p2 [region 2 $r] ; set p3 [region 3 $r] ; set p4 [region 4 $r]
set hn 0 ; set hbad 0
foreach a $p2 b $p3 c $p4 { if {$a ne $c} { incr hn ; if {$b ne $selcol} { incr hbad } } }
check "B2 the box lies on the hover outline: the same bounding box, and every pixel the dashed\
 hover paints on the FET is the selection colour in brightbox" \
  [list [lrange $bdiff 1 4] [expr {$hn > 0}] $hbad] [list [lrange $hdiff 1 4] 1 0]
## a wire's or line's box lies on its bright stroke until it is wider than the stroke
set seen {}
foreach w {1 3} {
  set ::hover_highlight_width $w
  set row {}
  foreach obj [list [list wire $::wn] [list line $::rc 0] {instance M1}] {
    set_look bright ; xschem unselect_all ; xschem select {*}$obj ; snap 2
    set_look brightbox ; snap 3
    lappend row [lindex [xschem window_snapshot diff 2 3] 0]
  }
  lappend seen $row
}
set ::hover_highlight_width $hw0 ; xschem build_colors
lassign $seen s1 s3
check "B3 a selected wire's and line's box does not show at width 1 and does at width 3; a FET's\
 box shows at both and grows" \
  [list [lrange $s1 0 1] [expr {[lindex $s3 0] > 0 && [lindex $s3 1] > 0}] \
        [expr {[lindex $s1 2] > 0 && [lindex $s3 2] > [lindex $s1 2]}]] {{0 0} 1 1}
## B4: B2's comparison on the net label p1, the one instance whose hover rectangle is not its
## symbol's bbox (hover_inst_rect() in src/draw.c outlines a label's visible text instead), so a
## box that stopped sharing that rectangle would differ here and nowhere else
set_look bright ; xschem unselect_all ; xschem redraw ; xschem select instance p1 ; snap 2
set_look brightbox ; snap 3
set bdiff [xschem window_snapshot diff 2 3]
set_look bright
set ::hover_highlight 1
enter 300 -110 ; motion 333 -144 ; snap 4
set hdiff [xschem window_snapshot diff 2 4]
set ::hover_highlight 0 ; motion 300 -110 ; settle
xschem unselect_all
check "B4 a selected net label: brightbox's box has the bounding box of the hover outline on it" \
  [list [lrange $bdiff 1 4] [expr {[lindex $hdiff 0] > 0}]] [list [lrange $hdiff 1 4] 1]

## ---------------------------------------------------------------------------------------------
## C -- classic, upstream's look: grey strokes and a box per text (C4), every pixel in layer 2's
## colour (SELLAYER, the grid's layer), and an unselect that restores the picture exactly.
set ::LOOK C
load_fixture
set_look classic
set l2 [string tolower [lindex $tctx::colors [xschem get sellayer]]]
xschem unselect_all ; snap 0
xschem select_all ; snap 1
check "C1 classic paints select-all in layer 2's colour ($l2) and in nothing else" \
  [dict keys [xschem window_snapshot colors 0 1]] [list $l2]
check "C2 classic: select-all equals a fresh redraw" [lindex [vs_redraw] 0] 0
xschem unselect_all ; snap 2
check "C3 classic: unselect-all gives back the unselected picture" \
  [lindex [xschem window_snapshot diff 0 2] 0] 0
## C4: each floating text, selected alone, changes pixels laid out as a rectangle outline: every
## edge of their bounding box at least 90% layer 2's grey (a line join may leave a corner), and
## nothing changed 4 px inside it, where its letters are
set c4 {}
foreach t [list $::tn $::ts] {
  xschem unselect_all ; xschem redraw ; snap 0 ; xschem select text $t ; snap 1
  set r [changed_rect 0 1 0]
  if {$r eq {}} { lappend c4 nothing ; continue }
  lassign $r x y w h
  set e {}
  foreach s [list [list $x $y $w 1] [list $x [expr {$y + $h - 1}] $w 1] \
                  [list $x $y 1 $h] [list [expr {$x + $w - 1}] $y 1 $h]] {
    set px [region 1 $s] ; lappend e [expr {[ncolour $px $l2] >= 0.9 * [llength $px]}]
  }
  set in [shrink $r 4]
  lappend c4 [list {*}$e [ndiff [region 0 $in] [region 1 $in]]]
}
xschem unselect_all
check "C4 classic: a selected floating note and small note are each a box outline in $l2, four\
 edges grey and nothing changed inside" $c4 {{1 1 1 1 0} {1 1 1 1 0}}

## ---------------------------------------------------------------------------------------------
## H -- hidden texts. Regions: what annot_show's op bit (1) and voltage bit (2) reveal on an
## unselected sheet, which is where the two hidden texts are drawn when shown.
set ::LOOK H
load_fixture
set_look brightbox
xschem unselect_all ; annot 0 ; snap 0
annot 1 ; snap 1
set rop [changed_rect 0 1]
annot 2 ; snap 5
set rfl [changed_rect 0 5]
set owncol [top_colour 0 5]
annot 0 ; settle
check "H0 annot_show's op bit reveals the annotator's text and its voltage bit the floating one,\
 in two separate places" \
  [list [expr {$rop ne {}}] [expr {$rfl ne {}}] \
        [expr {$rop ne {} && $rfl ne {} && ([lindex $rop 0] + [lindex $rop 2] < [lindex $rfl 0] ||
               [lindex $rfl 0] + [lindex $rfl 2] < [lindex $rop 0])}]] {1 1 1}
foreach st {brightbox bright halo} {
  set_look $st
  xschem unselect_all ; annot 0 ; snap 0
  xschem select instance zz1 ; snap 2
  set hidden [ndiff [region 0 $rop] [region 2 $rop]]
  xschem unselect_all ; annot 1 ; snap 1
  xschem select instance zz1 ; snap 3
  set shown [ndiff [region 1 $rop] [region 3 $rop]]
  xschem unselect_all ; annot 0 ; settle
  check "H1 $st: the annotator selected, its hide=op text stays hidden (0 px change there),\
 and once annot_show shows it the overlay does paint it" \
    [list $hidden [expr {$shown > 0}]] {0 1}
}
## halo's own text style repaints a selected text's glyphs in the text's own colour; a hidden
## floating text must not get them (text_draw_layer() in src/draw.c, which draw() asks too).
## The selection-colour glyphs and halo's band are rows H3-H5.
set_look halo
xschem unselect_all ; annot 0 ; snap 0
xschem select text $::th ; snap 2
set own_hidden [ncolour [region 2 $rfl] $owncol]
xschem unselect_all ; annot 2 ; settle
xschem select text $::th ; snap 3
set own_shown [ncolour [region 3 $rfl] $owncol]
xschem unselect_all ; annot 0 ; settle
check "H2 halo: a selected hidden floating text gets no glyphs in its own colour ($owncol), while\
 the same text shown gets them" [list $own_hidden [expr {$own_shown > 0}]] {0 1}

## H3-H5: a selected hidden floating text draws no letters and no band in any styled look; its
## mark is classic's, the text's box in the selection colour, and in brightbox that box is the
## selection box itself, drawn once (receipts/C2-fix.md). Hidden is text_hidden()'s answer, so a
## text shown (annot_show's bit, show_hidden_texts) is selected as any text is. The regions come
## from classic's own mark, the box around the text: `inner` is that box less 6 px on each side,
## where letters are and no box is; `outer` is the box plus 6 px, which holds the whole mark.
## View > Show hidden texts writes the Tcl variable, which draw() copies into the context
proc show_hidden {on} { set ::show_hidden_texts $on ; xschem set show_hidden_texts $on }
## show_hidden_texts off, annot_show 0: both texts hidden
proc hide_all {} { show_hidden 0 ; annot 0 }
load_fixture
set_look classic
set box {}
foreach t [list $::th $::tt] {
  hide_all ; xschem unselect_all ; xschem redraw ; snap 0
  xschem select text $t ; snap 1
  lappend box [changed_rect 0 1 0]
}
xschem unselect_all
check "H3a classic marks each selected hidden text with its box (two regions found, each wider\
 and taller than 12 px)" \
  [lmap r $box {expr {$r ne {} && [lindex $r 2] > 12 && [lindex $r 3] > 12}}] {1 1}
set h3 {} ; set h4 {} ; set h5 {}
foreach st {bright brightbox halo} {
  set_look $st
  foreach t [list $::th $::tt] r $box {
    set inner [shrink $r 6] ; set outer [shrink $r -6]
    hide_all ; xschem unselect_all ; xschem redraw ; snap 0
    xschem select text $t ; snap 1
    set d [xschem window_snapshot diff 0 1]
    lappend h3 [list [ndiff [region 0 $inner] [region 1 $inner]] [inside $d $outer] \
                     [dict keys [xschem window_snapshot colors 0 1]]]
    lappend h4 [lindex $d 0]
    set h4lw [xschem get line_width]
    ## shown: annot_show's voltage bit for ZZ_FLOAT_HIDDEN, show_hidden_texts for ZZ_TRUE
    xschem unselect_all
    if {$t == $::th} { annot 2 } else { show_hidden 1 ; xschem redraw }
    snap 2
    xschem select text $t ; snap 3
    lappend h5 [expr {[ndiff [region 2 $inner] [region 3 $inner]] > 0}]
    xschem unselect_all ; hide_all ; xschem redraw ; settle
  }
}
set selcol [string tolower $::selcol]
check "H3 bright, brightbox, halo: a selected hidden floating text (hide=voltage, hide=true)\
 changes nothing inside its box, its mark lies within 6 px of the box, all in the selection\
 colour" $h3 [lrepeat 6 [list 0 1 [list $selcol]]]
## bright's box is drawn at the line width, brightbox's at the box width (1); the two differ only
## where the line width is 2 px or more (XLINEWIDTH() in src/xschem.h truncates it), so that is
## read back: at width 1 the two marks are the same pixels and this row would be red on good code
check "H4 brightbox's mark for a hidden text changes fewer px than bright's (one box, not the glyph\
 pass's box as well), at a zoom whose line width (read back) is 2 px or more" \
  [list [expr {[lindex $h4 2] < [lindex $h4 0]}] [expr {[lindex $h4 3] < [lindex $h4 1]}] \
        [expr {int($h4lw) >= 2}]] {1 1 1}
check "H5 the same texts shown (annot_show's voltage bit, show_hidden_texts) are selected as any\
 text is: inside the box changes, in every styled look" $h5 [lrepeat 6 1]

## ---------------------------------------------------------------------------------------------
## D -- texts and objects draw() leaves out for another reason than hide=: a layer unticked in
## View > Show > Visible layers, and draw_single_layer (the `>` key: only the current layer, until
## `<`). A selected text draw() does not paint gets no letters
## and no band in any styled look, as a hidden one (H3); halo's own colours repaint nothing draw()
## does not paint (receipts/C3-verify.md, MEDIUM-1; receipts/C4-fix.md). A hidden symbol needs no
## row: the overlay draws none of its texts. The regions: the floating
## note's from classic's box, as H3's; M1's letters are the pixels its texts paint on the sheet,
## read by unticking the text layer, and a look reveals them if a tenth of them change when M1 is
## selected (drawn letters change all of them; a box or stroke crossing them, a few in a hundred).
set ::LOOK D
load_fixture
set TL [xschem get textlayer]
## the Visible layers checkbutton's -command, after it wrote enable_layer(<l>)
proc layer_on {l on} { set ::enable_layer($l) $on ; xschem enable_layers ; xschem redraw ; settle }
## the `>` key (Shift+.) draws only the current layer, `<` all of them again
proc single {l} {
  motion 300 -250
  if {$l < 0} { key less } else { xschem set rectcolor $l ; key greater 1 }
  settle
}
set_look classic
xschem unselect_all ; xschem redraw ; snap 0 ; xschem select text $::tn ; snap 1
set dbox [changed_rect 0 1 0]
xschem unselect_all
lassign [w2s 430 -200] dx1 dy1 ; lassign [w2s 550 -80] dx2 dy2
set mreg [list $dx1 $dy1 [expr {$dx2 - $dx1}] [expr {$dy2 - $dy1}]]
## the positions (in mreg) where two captures differ
proc dpos {a b r} {
  set p {} ; set k 0
  foreach x [region $a $r] y [region $b $r] { if {$x ne $y} { lappend p $k } ; incr k }
  return $p
}
## of the positions in p, how many differ between captures a and b over region r
proc nat {a b r p} {
  set pa [region $a $r] ; set pb [region $b $r] ; set n 0
  foreach k $p { if {[lindex $pa $k] ne [lindex $pb $k]} { incr n } }
  return $n
}
xschem unselect_all ; snap 2 ; layer_on $TL 0 ; snap 3 ; layer_on $TL 1
set P [dpos 2 3 $mreg]
## one styled look under the current mode: the note's {inner, inside outer, colours} and whether
## M1's letters (positions p) stay unrevealed
proc d_look {st p} {
  set_look $st
  xschem unselect_all ; xschem redraw ; snap 0 ; xschem select text $::tn ; snap 1
  set d [xschem window_snapshot diff 0 1]
  set note [list [ndiff [region 0 [shrink $::dbox 6]] [region 1 [shrink $::dbox 6]]] \
                 [inside $d [shrink $::dbox -6]] [dict keys [xschem window_snapshot colors 0 1]]]
  xschem unselect_all ; xschem redraw ; snap 0 ; xschem select instance M1 ; snap 1
  set n [nat 0 1 $::mreg $p]
  xschem unselect_all
  return [list $note [expr {[llength $p] > 0 && 10 * $n < [llength $p]}]]
}
set selcol [string tolower $::selcol]
set dwant [lrepeat 3 [list [list 0 1 [list $selcol]] 1]]
## D1: the text layer unticked
layer_on $TL 0
set d1 {} ; foreach st {bright brightbox halo} { lappend d1 [d_look $st $P] }
layer_on $TL 1
check "D1 text layer unticked (Visible layers): bright, brightbox, halo draw a selected floating\
 note as its box ($selcol, nothing inside) and leave M1's letters unrevealed" $d1 $dwant
## D2: draw_single_layer on the layer the rect, line, polygon and arc are on; leg: the note's
## letters are gone from the unselected sheet then (the key took effect)
set_look classic ; xschem unselect_all ; xschem redraw ; snap 4
single $::rc ; snap 5
set d2leg [expr {[ndiff [region 4 [shrink $dbox 6]] [region 5 [shrink $dbox 6]]] > 0}]
set d2 {} ; foreach st {bright brightbox halo} { lappend d2 [d_look $st $P] }
single -1
check "D2 draw_single_layer (the > key, layer $::rc): the note's letters leave the sheet, and\
 bright, brightbox, halo draw it as its box and leave M1's letters unrevealed" \
  [list $d2leg {*}$d2] [list 1 {*}$dwant]
## D4, D5: halo's own colours. A selected object draw() does not paint keeps the selection band
## and gets none of its own colours: layer $::rc unticked for the rect, line, polygon and arc, and
## draw_single_layer on an empty layer (7) for the wire, M1 (body and pins) and the rect. The leg
## per object: hidden, it was not on the unselected sheet (so its own colour would show).
set_look halo
set d4 {}
foreach {o sel} [list rect "xschem select rect $::rc 0" line "xschem select line $::rc 0" \
                      poly "xschem select poly $::rc 0" arc "xschem select arc $::rc 0"] {
  xschem unselect_all ; xschem redraw ; snap 2
  eval $sel ; snap 3 ; set r [changed_rect 2 3]
  xschem unselect_all ; layer_on $::rc 0 ; snap 0
  set gone [ndiff [region 2 $r] [region 0 $r]]
  eval $sel ; snap 1
  lappend d4 [list $o [expr {$gone > 0}] [dict keys [xschem window_snapshot colors 0 1]]]
  xschem unselect_all ; layer_on $::rc 1
}
check "D4 halo, layer $::rc unticked: a selected rect, line, polygon and arc (each gone from the\
 sheet) change only to $selcol" $d4 \
  [list [list rect 1 [list $selcol]] [list line 1 [list $selcol]] [list poly 1 [list $selcol]] \
        [list arc 1 [list $selcol]]]
set d5 {}
foreach {o sel} [list wire "xschem select wire $::wn" M1 "xschem select instance M1" \
                      rect "xschem select rect $::rc 0"] {
  xschem unselect_all ; xschem redraw ; snap 2
  eval $sel ; snap 3 ; set r [changed_rect 2 3]
  xschem unselect_all ; single 7 ; snap 0
  set gone [ndiff [region 2 $r] [region 0 $r]]
  eval $sel ; snap 1
  lappend d5 [list $o [expr {$gone > 0}] [dict keys [xschem window_snapshot colors 0 1]]]
  xschem unselect_all ; single -1
}
check "D5 halo, draw_single_layer on empty layer 7: a selected wire, M1 and rect (each gone from\
 the sheet) change only to $selcol" $d5 \
  [list [list wire 1 [list $selcol]] [list M1 1 [list $selcol]] [list rect 1 [list $selcol]]]
## the sheet as it was: every layer, all layers drawn, symbols shown
xschem unselect_all ; xschem redraw ; settle

## ---------------------------------------------------------------------------------------------
## O -- selection_text_own_px not a number. The small note renders below 16 px, so at the
## default it is plain colour in halo and at 0 it gets the band.
set ::LOOK O
load_fixture
set_look halo
xschem select text $::ts
set k 0
foreach v {16 abc 0} {
  set ::selection_text_own_px $v ; xschem build_colors ; xschem redraw ; snap $k ; incr k
}
set ::selection_text_own_px 16 ; xschem build_colors ; xschem unselect_all ; xschem redraw
check "O1 halo, a small selected text: own_px 'abc' draws as the default 16 does, and 0 does not" \
  [list [lindex [xschem window_snapshot diff 0 1] 0] \
        [expr {[lindex [xschem window_snapshot diff 0 2] 0] > 0}]] {0 1}

## ---------------------------------------------------------------------------------------------
## L -- the look itself. Every R row compares the window with a redraw, and a redraw paints the
## same look whether it is right or wrong, so each row here compares with something fixed in this
## file instead: the documented colours, the letters of a text as the unselected sheet shows them,
## the band halo adds outside a stroke (receipts/C-verify.md, HIGH-1, MEDIUM-1).
set ::LOOK L
load_fixture
## L1: the colour bright paints a selected FET in most: build_colors()' theme default (src/xinit.c),
## orange on dark and deep orange on light, unless selection_color names a colour X can parse
proc sel_colour_of {} {
  xschem unselect_all ; xschem redraw ; snap 0
  xschem select instance M1 ; snap 1
  set c [top_colour 0 1] ; xschem unselect_all ; return $c
}
set_look bright
set l1 [list [sel_colour_of]]
foreach c {#00ff00 notacolour} {
  set ::selection_color $c ; xschem build_colors ; lappend l1 [sel_colour_of]
}
set ::selection_color {} ; xschem build_colors
xschem toggle_colorscheme ; settle ; lappend l1 [sel_colour_of]
xschem toggle_colorscheme ; settle ; lappend l1 [sel_colour_of]
check "L1 bright, a selected FET's colour: the dark default, selection_color #00ff00, an\
 unparseable selection_color (the default), the light default, the dark default again" \
  $l1 [list #ff8000 #00ff00 #ff8000 #e05a00 #ff8000]
## L2: bright and brightbox paint a selected text's LETTERS. The box is classic's mark for the text.
## 2 px inside it, no pixel the selection changes was background on the unselected sheet (a box or
## a band would be painted there); 4 px inside it the letters change, some of them to exactly the
## selection colour (the rest are antialiased edges). On the box's own outline (the ring: the
## pixels classic paints) bright draws no box as well as the letters: a letter's edge may touch the
## ring, a box covers it (receipts/C3-verify.md, LOW-1, its V7c). brightbox's box, one px on a ring
## as wide as the line, is the control that the ring can see a box.
set_look classic
set boxes {} ; set rings {}
foreach t [list $::tn $::ts] {
  xschem unselect_all ; xschem redraw ; snap 0 ; xschem select text $t ; snap 1
  set r [changed_rect 0 1 0]
  lappend boxes $r
  ## the ring: the pixels classic's box outline paints, as positions in r
  set ring {} ; set k 0
  foreach a [region 0 $r] b [region 1 $r] { if {$a ne $b} { lappend ring $k } ; incr k }
  lappend rings $ring
}
set bgc [string tolower [lindex $tctx::colors 0]]
set l2r {}
foreach st {bright brightbox} {
  set_look $st
  foreach t [list $::tn $::ts] r $boxes ring $rings {
    xschem unselect_all ; xschem redraw ; snap 0 ; xschem select text $t ; snap 1
    set onbg 0
    foreach a [region 0 [shrink $r 2]] b [region 1 [shrink $r 2]] {
      if {$a ne $b && $a eq $bgc} { incr onbg }
    }
    set in [shrink $r 4]
    set nsel 0
    foreach a [region 0 $in] b [region 1 $in] { if {$a ne $b && $b eq {#ff8000}} { incr nsel } }
    ## on the ring: how many pixels turn exactly #ff8000
    set pa [region 0 $r] ; set pb [region 1 $r] ; set nring 0
    foreach k $ring {
      if {[lindex $pa $k] ne [lindex $pb $k] && [lindex $pb $k] eq {#ff8000}} { incr nring }
    }
    lappend l2r [list $onbg [expr {$nsel > 0}] \
      [expr {$st eq {bright} ? 10 * $nring < [llength $ring] : 3 * $nring > [llength $ring]}]]
  }
}
xschem unselect_all
check "L2 bright, brightbox: a selected floating note and small note are their letters, not a box:\
 inside the text's box no changed pixel was background ($bgc), some letter pixels turn #ff8000,\
 and of classic's box outline fewer than a tenth turn #ff8000 in bright, more than a third (its\
 box) in brightbox" $l2r [lrepeat 4 {0 1 1}]
## L3: halo keeps an object's own colours and puts a band of the selection colour around them. A
## selected wire (horizontal) changes only to the selection colour, the change is taller than the
## band on both sides (2 x the default halo width of 3, plus the stroke), and the wire's own pixels
## at its middle do not change. The band is no taller than the stroke (classic's, read back) plus
## 2 x halo_px plus 2 px of slack for rounding, so a band twice as wide (2 x halo_px more) is over
## it (receipts/C3-verify.md, LOW-1, its V8b; receipts/C4-fix.md has the measured margin). A floating note
## gets the band around its letters: changed pixels on the background, every one of them the
## selection colour.
set_look classic
xschem unselect_all ; xschem redraw ; snap 0 ; xschem select wire $::wn ; snap 1
lassign [xschem window_snapshot diff 0 1] n x1 y1 x2 y2
set stroke [expr {$y2 - $y1 + 1}]
set_look halo
set hpx [dict get [xschem get selection_look] halo_px]
xschem unselect_all ; xschem redraw ; snap 0 ; xschem select wire $::wn ; snap 1
lassign [xschem window_snapshot diff 0 1] n x1 y1 x2 y2
lassign [w2s 375 -140] mx my
set mid [list [expr {$mx - 10}] $my 20 1]
set l3 [list [expr {$n > 0}] [dict keys [xschem window_snapshot colors 0 1]] \
          [expr {$n > 0 && $y2 - $y1 + 1 >= 7}] \
          [expr {$n > 0 && $y2 - $y1 + 1 <= $stroke + 2 * $hpx + 2}] \
          [ndiff [region 0 $mid] [region 1 $mid]]]
lassign $boxes r
xschem unselect_all ; xschem redraw ; snap 0 ; xschem select text $::tn ; snap 1
set onbg 0 ; set onbgsel 0
foreach a [region 0 $r] b [region 1 $r] {
  if {$a ne $b && $a eq $bgc} { incr onbg ; if {$b eq {#ff8000}} { incr onbgsel } }
}
lappend l3 [expr {$onbg > 0 && $onbgsel == $onbg}]
xschem unselect_all
check "L3 halo: a selected wire changes only to #ff8000, a band at least 7 px tall and no taller\
 than classic's stroke ($stroke) + 2 x halo_px ($hpx) + 2, with the wire's own middle unchanged; a\
 selected floating note gets a #ff8000 band on the background" $l3 {1 {{#ff8000}} 1 1 0 1}
## L4: a typed `set selection_style X` takes effect on the next redraw with no build_colors (FAQ
## Q94; draw() resolves it through sel_style_sync()). From brightbox with the FET selected: the look
## in force reads X, the window equals X chosen through build_colors, and that differs from
## brightbox's, so the comparison can see a look that did not change.
set_look brightbox ; xschem unselect_all ; xschem select instance M1 ; snap 4
set l4 {}
foreach st {bright halo classic} {
  set_look brightbox
  set ::selection_style $st ; xschem redraw ; settle
  set lk [look_now] ; snap 5
  set_look $st ; snap 6
  lappend l4 [list $lk [lindex [xschem window_snapshot diff 5 6] 0] \
                   [expr {[lindex [xschem window_snapshot diff 4 6] 0] > 0}]]
}
xschem unselect_all ; set_look brightbox
check "L4 a typed selection_style then xschem redraw shows that look: bright, halo, classic, each\
 read back, equal to it chosen through build_colors, and unlike brightbox" \
  $l4 {{bright 0 1} {halo 0 1} {classic 0 1}}

## ---------------------------------------------------------------------------------------------
## S -- the snapshot hook's region arguments (receipts/C-verify.md, LOW): x + w past the int range
## is an error rather than a wrapped sum, as is an argument that is not an integer; an ordinary
## region answers one value per pixel and a negative width none.
snap 0
set s1 {}
foreach a {{100 0 2147483647 1} {-5 0 -2147483647 1} {0 100 1 2147483647} {a 0 1 1} {0 0 1.5 1}
           {0 0 99999999999 1}} {
  lappend s1 [catch {xschem window_snapshot pixels 0 {*}$a}]
}
lappend s1 [llength [xschem window_snapshot pixels 0 10 10 3 2]] \
           [llength [xschem window_snapshot pixels 0 10 10 -3 2]]
check "S1 window_snapshot pixels: x + w past INT_MAX or below INT_MIN, y + h past INT_MAX, 'a',\
 '1.5', a w outside int are errors; 3x2 answers 6 values, w -3 none" $s1 {1 1 1 1 1 1 6 0}

xschem set modified 0
xschem new_schematic switch $::TAB ; xschem set modified 0 ; xschem new_schematic switch .drw
finish
