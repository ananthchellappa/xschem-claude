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
#      hover outline's own rectangle; a wire's box shows only once it is wider than the wire
#   C  classic: the selection is painted in layer 2's grey and nothing else, and erases back
#   H  a hide=op text stays hidden when its instance is selected, in every styled look; a hidden
#      floating text, selected, gets no letters and no band, only classic's mark (its box, in
#      brightbox the selection box), and is selected as any text is once shown
#   O  a selection_text_own_px that is not a number draws as the default 16 does
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

## ---------------------------------------------------------------------------------------------
## C -- classic, upstream's look: grey strokes and a box per text, every pixel in layer 2's
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
## floating text must not get them (sel_text_own_layer() in src/move.c asks text_hidden()).
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
proc shrink {r d} {
  lassign $r x y w h
  return [list [expr {$x + $d}] [expr {$y + $d}] [expr {$w - 2 * $d}] [expr {$h - 2 * $d}]]
}
proc inside {d r} {
  lassign $d n x1 y1 x2 y2
  lassign $r x y w h
  expr {$n > 0 && $x1 >= $x && $y1 >= $y && $x2 < $x + $w && $y2 < $y + $h}
}
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

xschem set modified 0
xschem new_schematic switch $::TAB ; xschem set modified 0 ; xschem new_schematic switch .drw
finish
