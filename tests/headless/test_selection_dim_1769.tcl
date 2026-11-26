# tests/headless/test_selection_dim_1769.tcl -- dim what is not selected
# (doc/claude/specs/selection_dim.md, issue 1769).
#
# With `selection_dim` on, or while Alt-Shift-RightButton is held (the peek), everything that is
# not selected is painted in colours moved `selection_dim_percent` of the way to the background,
# so the selection is what the eye finds. Off by default; Ctrl-Alt-Shift-D toggles it.
#
# Bands (the counted arm, --nogui, runs D T Q B K H Z; the display arm runs every band):
#   D  defaults, the C mirror of the default amount, how a word that is no number is read,
#      what src/cadence_style_rc, src/keys.help and the manual page carry, what a `set` of
#      the setting becomes
#   T  the toggle command, its absolute form, what the status line says, the one log line
#   Q  selection_dim_percent_set: what it takes and what it refuses
#   B  the two rows of the binding table, the shipped binding files, the action table
#   K  Ctrl-Alt-Shift-D through the canvas callback (and as a real key on a display)
#   H  the peek: press, hold, release, a release that never comes, two quick presses, a wire
#      tool left armed, what it brings out with nothing selected, and the wire cut that had the
#      chord before
#   Z  what needs a display says so
#   F  the frame follows the selection: one redraw per change of it, what is selected in its
#      own colours and the rest dim
#   A  the amount
#   N  no redraw that is not owed
#   I  what paints the document outside a full redraw joins a dim frame
#   G  an embedded graph repainted on its own
#   L  the four Selection looks over a dim frame
#   X  an export is never dim
#   P  an embedded picture
#   O  the only-probes view is left alone
#   M  the View menu
#   C  the Cadence profile's two key lines
#   W  the waveform viewer: its key lines, and a viewer window is never dimmed
#   U  what the dim leaves alone (hover outline, crosshair) and what it takes (grid, text, pin
#      marker)
#
# Registered in hcases and dcases. Run it armed:
#   tests/headless/run_suites.sh [--nogui] test_selection_dim_1769
# scratch.tcl arms the in-suite watchdog: the display arm pumps the event loop with `update`.
source [file join [file dirname [info script]] scratch.tcl]

set ::fail 0 ; set ::npass 0
proc check {name got want} {
  if {$got eq $want} { puts "ok:   $name" ; incr ::npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr ::fail }
}
proc finish {} {
  catch {xschem window_snapshot free}
  if {$::fail == 0} {
    puts "OVERALL: ok ($::npass checks)"
    puts "RESULT: ALL PASS ($::npass checks)"
  } else {
    puts "RESULT: $::fail FAILED ($::npass passed)"
  }
  flush stdout
  exit [expr {$::fail == 0 ? 0 : 1}]
}
set ::X [info exists ::has_x]
set repo [file normalize [file join [file dirname [info script]] .. ..]]
set dir [test_scratch seldim1769]
proc slurp {f} { set fd [open $f r] ; set b [read $fd] ; close $fd ; return $b }

## The fixture: two wires of net A, a free wire B, a line, a box, a polygon and an arc on layer 4,
## a text, three instances. Everything is inside the view `xschem zoom_full` gives.
set fixture {v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
L 4 560 -190 620 -170 {}
B 4 560 -230 620 -200 {}
P 4 4 560 -290 620 -290 590 -260 560 -290 {}
A 4 590 -100 15 0 270 {}
T {floating note} 300 -200 0 0 0.3 0.3 {}
N 340 -140 410 -140 {lab=A}
N 410 -140 410 -60 {lab=A}
N 200 -300 300 -300 {lab=B}
C {nmos4.sym} 470 -140 0 0 {name=M1 model=nmos w=5u l=0.18u m=1}
C {res.sym} 410 -30 0 0 {name=R1 value=1k footprint=1206 device=resistor}
C {lab_pin.sym} 340 -140 0 0 {name=p1 lab=A}
}
set fx [file join $dir fix.sch]
set fd [open $fx w] ; puts -nonewline $fd $fixture ; close $fd

## ---------------------------------------------------------------------------------------------
## helpers
proc settle {} { if {$::X} { update ; after 40 ; update } }
proc dg {k} { return [dict get [xschem get selection_dim] $k] }
proc dstate {} { set d [xschem get selection_dim]
  return "w[dict get $d wanted] d[dict get $d drawn] h[dict get $d hold] st[dict get $d stale]" }
## schematic -> window pixel, from the live transform (X_TO_SCREEN in src/xschem.h)
proc w2s {x y} {
  list [expr {int(($x + [xschem get xorigin]) / [xschem get zoom])}] \
       [expr {int(($y + [xschem get yorigin]) / [xschem get zoom])}]
}
## an event straight into the canvas callback: both arms. event 2 key, 4 press, 5 release,
## 6 motion, -3 double click
proc cb {ev x y key button state} {
  lassign [w2s $x $y] px py
  xschem callback .drw $ev $px $py $key $button 0 $state
}
proc load_fix {} {
  xschem set modified 0   ;# or the load asks, in a dialog nothing here can answer
  xschem load -nofullzoom $::fx ; xschem zoom_full ; settle
  set ::selection_dim 0 ; set ::selection_dim_percent 30
  xschem unselect_all ; settle
}
## the state of an Alt-Shift chord, and of a right button that is down
set ALTSH 9 ; set B3 1024
## r,g,b of #rrggbb, and the colour `pct` of the way from c to bg, as the feature defines it
proc rgb {c} { scan $c "#%2x%2x%2x" r g b ; return [list $r $g $b] }
proc mix {c bg pct} {
  set o "#"
  foreach a [rgb $c] b [rgb $bg] { append o [format %02x [expr {($a * (100 - $pct) + $b * $pct + 50) / 100}]] }
  return $o
}
proc layer_col {l} { return [string tolower [lindex $tctx::colors $l]] }

load_fix

## ---------------------------------------------------------------------------------------------
## D -- defaults and documents
check "D1 the Tcl defaults (set_ne in src/xschem.tcl): off, 30 percent" \
  [list [regexp -line {^set_ne selection_dim 0$} [slurp $repo/src/xschem.tcl]] \
        [regexp -line {^set_ne selection_dim_percent 30$} [slurp $repo/src/xschem.tcl]]] {1 1}
set cdef {}
regexp -line {^#define SEL_DIM_PERCENT ([0-9.]+)$} [slurp $repo/src/xschem.h] -> cdef
check "D2 SEL_DIM_PERCENT (src/xschem.h) is the Tcl default: a word that is no number reads as it" \
  [list [expr {$cdef == 30}] [apply {{} { set ::selection_dim_percent abc ; set p [dg percent]
                                        set ::selection_dim_percent 30 ; return $p }}]] {1 30}
check "D3 at rest: nothing wanted, drawn, applied or held, and the amount is 30" \
  [lrange [xschem get selection_dim] 0 9] {wanted 0 drawn 0 applied 0 hold 0 percent 30}
set got {}
foreach v [list {} abc nan 1e400 -5 250 12.6 { 40 } 0 100] {
  set ::selection_dim_percent $v ; lappend got [dg percent]
}
set ::selection_dim_percent 30
check "D4 the amount as C reads it: empty, a word, nan and an overflow are the default; it is\
 clamped to 0..100 and rounded" $got {30 30 30 30 0 100 13 40 0 100}
set rc [slurp $repo/src/cadence_style_rc]
check "D5 src/cadence_style_rc carries both settings commented out, once each, and sets neither" \
  [list [regexp -all -line {^# set selection_dim 1$} $rc] \
        [regexp -all -line {^# set selection_dim_percent 30$} $rc] \
        [regexp -all -line {^\s*set (::)?selection_dim} $rc]] {1 1 0}
set kh [slurp $repo/src/keys.help]
check "D6 src/keys.help names the key and the held button, and the cut's remaining chord" \
  [list [regexp -line {^ctrl\+alt\+shift 'D'\s+Toggle dimming} $kh] \
        [regexp {Alt \+ Shift \+ RightButton\n\s+Held down: dim everything that is not selected} $kh] \
        [regexp {Super \+ Shift \+ RightButton\n\s+Cut wire at mouse position} $kh]] {1 1 1}

set man [slurp $repo/doc/xschem_man/commands.html]
check "D6b the manual page (doc/xschem_man/commands.html) says the same" \
  [list [regexp -line {^ctrl\+alt\+shift 'D'\s+Toggle dimming} $man] \
        [regexp {Alt \+ Shift \+ RightButton\n\s+Held down: dim everything that is not selected} $man] \
        [regexp {Super \+ Shift \+ RightButton\n\s+Cut wire at mouse position} $man]] {1 1 1}
set got {}
foreach v {true yes on 1 false no off 0 abc 2 {}} {
  set ::selection_dim $v ; selection_dim_normalise ; lappend got $::selection_dim
}
set ::selection_dim true ; set w1 [xschem get selection_dim] ; set p1 $::selection_dim_normalise_pending
selection_dim_normalise
set ::selection_dim 0
check "D7 a boolean word written to selection_dim (an rc file's `set selection_dim true`) is\
 rewritten as 1 or 0 once the event loop is idle, and a word that is no boolean as 0: the menu\
 entry and C then read the same thing. Until then C reads the word as written" \
  [list $got [dict get $w1 hold] $p1] {{1 1 1 1 0 0 0 0 0 0 0} 0 1}

## ---------------------------------------------------------------------------------------------
## T -- the toggle
set r1 [xschem toggle_selection_dim] ; set v1 $::selection_dim
set m1 [xschem get statusmsg]
set r2 [xschem toggle_selection_dim] ; set v2 $::selection_dim
set m2 [xschem get statusmsg]
check "T1 xschem toggle_selection_dim flips the setting each time and returns nothing" \
  [list $r1 $v1 $r2 $v2] {{} 1 {} 0}
check "T2 the status line says which way it went; on, with nothing selected, it says when the\
 dimming will show" [list $m1 $m2] \
  [list {Dim unselected objects: ON (30%). It shows with the next selection} \
        {Dim unselected objects: OFF}]
xschem set selection_dim 1 ; set v1 $::selection_dim
xschem set selection_dim 0 ; set v2 $::selection_dim
check "T3 xschem set selection_dim <0|1> is the absolute form" [list $v1 $v2] {1 0}
xschem select instance R1
xschem toggle_selection_dim ; set m1 [xschem get statusmsg]
set ::selection_dim_percent 0
xschem toggle_selection_dim ; xschem toggle_selection_dim ; set m2 [xschem get statusmsg]
set ::selection_dim_percent 30 ; set ::selection_dim 0 ; xschem unselect_all
check "T4 with something selected it gives the amount; with the amount at 0 it says so and where\
 to change it" [list $m1 $m2] \
  [list {Dim unselected objects: ON (30%)} \
        {Dim unselected objects: ON, but the amount is 0% (View > Dimming amount)}]
set lf {}
catch {set lf [xschem get actionlog_filename]}
if {$lf ne {} && [file exists $lf]} {
  set n0 [llength [split [slurp $lf] \n]]
  cb 2 100 -400 68 0 13
  set new [lrange [split [string trimright [slurp $lf] \n] \n] [expr {$n0 - 1}] end]
  cb 2 100 -400 68 0 13
  check "T5 the key writes one line to the action log, the state reached and not the flip" \
    $new {{xschem set selection_dim 1}}
} else {
  puts "skip: T5 no action log is open in this run (xschem get actionlog_filename)"
}
set ::selection_dim 0

## ---------------------------------------------------------------------------------------------
## Q -- the amount's setter
set got {}
foreach v [list 40 { 55 } 12.6 0 100 1e1] {
  set ::selection_dim_percent 30
  lappend got [selection_dim_percent_set $v] $::selection_dim_percent
}
check "Q1 selection_dim_percent_set takes a number from 0 to 100 and keeps a whole percent" \
  $got {1 40 1 55 1 13 1 0 1 100 1 10}
set got {}
foreach v [list abc {} nan inf -1 101 {30 40} 1e400] {
  set ::selection_dim_percent 30
  lappend got [selection_dim_percent_set $v] $::selection_dim_percent
}
check "Q2 and refuses anything else, leaving the amount as it was" \
  $got {0 30 0 30 0 30 0 30 0 30 0 30 0 30 0 30}
set ::selection_dim_percent 30
selection_dim_percent_set 250 ; set m1 [xschem get statusmsg]
selection_dim_percent_set 45 ; set m2 [xschem get statusmsg]
set ::selection_dim_percent 30
check "Q3 either way the status line says what happened" [list $m1 $m2] \
  [list {Dimming amount: "250" is not a number from 0 to 100. It stays at 30%} {Dimming amount: 45%}]

if {$lf ne {} && [file exists $lf]} {
  set n0 [llength [split [string trimright [slurp $lf] \n] \n]]
  selection_dim_percent_set 60 ; selection_dim_percent_set abc
  set new [lrange [split [string trimright [slurp $lf] \n] \n] $n0 end]
  set ::selection_dim_percent 30
  check "Q4 an amount that was set goes to the action log as the line that sets it again; a\
 refusal writes nothing" $new {{selection_dim_percent_set 60}}
} else {
  puts "skip: Q4 no action log is open in this run (xschem get actionlog_filename)"
}

## ---------------------------------------------------------------------------------------------
## B -- bindings, binding files, the action table
set dump [xschem bindings dump]
check "B1 the built-in table: Ctrl-Alt-Shift-D is the toggle, Alt-Shift-RightButton the peek" \
  [list [lsearch -exact $dump {key 68 ctrl+alt canvas view.toggle_selection_dim}] \
        [lsearch -exact $dump {button 3 shift+alt canvas view.selection_dim_peek}]] \
  [list [lsearch -glob $dump {key 68 ctrl+alt canvas *}] [lsearch -glob $dump {button 3 shift+alt canvas *}]]
check "B1b and both rows are there" \
  [list [expr {[lsearch -glob $dump {key 68 ctrl+alt canvas *}] >= 0}] \
        [expr {[lsearch -glob $dump {button 3 shift+alt canvas *}] >= 0}]] {1 1}
save_input_bindings_file [file join $dir kb.csv] {key}
save_input_bindings_file [file join $dir mb.csv] {wheel button}
check "B2 the shipped binding files are the table's own dump, and each holds its row once" \
  [list [expr {[slurp [file join $dir kb.csv]] eq [slurp $repo/src/keybindings.csv]}] \
        [expr {[slurp [file join $dir mb.csv]] eq [slurp $repo/src/mousebindings.csv]}] \
        [regexp -all -line {^key,68,ctrl\+alt,canvas,view\.toggle_selection_dim,$} [slurp $repo/src/keybindings.csv]] \
        [regexp -all -line {^button,3,shift\+alt,canvas,view\.selection_dim_peek,$} [slurp $repo/src/mousebindings.csv]]] \
  {1 1 1 1}
set rows {}
foreach row $action_table {
  if {[string match view.*selection_dim* [dict get $row id]]} {
    lappend rows [list [dict get $row id] [dict get $row label] [dict get $row command]]
  }
}
check "B3 the action table: the toggle and the amount carry a command, so the Command Palette\
 lists them; the peek carries none, a held button being nothing a list can run" [lsort $rows] \
  [lsort [list {view.toggle_selection_dim {Dim unselected objects} {xschem toggle_selection_dim}} \
               {view.selection_dim_percent {Dimming amount} selection_dim_percent_ask} \
               {view.selection_dim_peek {Dim unselected objects while held} {}}]]

## ---------------------------------------------------------------------------------------------
## K -- the key, through the canvas callback
set got {}
cb 2 100 -400 68 0 13 ; lappend got $::selection_dim
cb 2 100 -400 68 0 13 ; lappend got $::selection_dim
check "K1 Ctrl-Alt-Shift-D (keysym D, Control and Alt in the state) flips the setting" $got {1 0}
set got {}
cb 2 100 -400 100 0 12 ; lappend got $::selection_dim
cb 2 100 -400 68 0 8 ; lappend got $::selection_dim
cb 2 100 -400 68 0 4 ; lappend got $::selection_dim
set ::selection_dim 0
check "K2 its neighbours do not: Ctrl-Alt-d, Alt-Shift-D, Ctrl-Shift-D" $got {0 0 0}
xschem unbind key 68 ctrl+alt canvas
cb 2 100 -400 68 0 13 ; set v1 $::selection_dim
xschem bind key 68 ctrl+alt canvas view.toggle_selection_dim
cb 2 100 -400 68 0 13 ; set v2 $::selection_dim
set ::selection_dim 0
check "K3 the chord is a row of the table: unbound it does nothing, bound again it flips" \
  [list $v1 $v2] {0 1}

## ---------------------------------------------------------------------------------------------
## H -- the peek, through the canvas callback
load_fix
xschem select instance R1
set w0 [xschem get wires]
cb 4 250 -300 0 3 $ALTSH ; set h1 [dg hold]
cb 6 260 -300 0 0 [expr {$ALTSH | $B3}] ; set h2 [dg hold]
cb 5 260 -300 0 3 [expr {$ALTSH | $B3}] ; set h3 [dg hold]
check "H1 Alt-Shift-RightButton down is the peek, it lasts through a motion with the button\
 down, and the button's release ends it; the wire under the pointer is not cut" \
  [list $h1 $h2 $h3 [xschem get wires]] [list 1 1 0 $w0]
cb 4 250 -300 0 3 $ALTSH
cb 5 250 -300 0 3 $B3 ; set h1 [dg hold]
check "H2 with Alt and Shift let go first, the release still ends it" $h1 0
xschem unselect_all
cb 4 250 -300 0 3 $ALTSH ; set h1 [dg hold] ; set m1 [xschem get statusmsg]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}] ; set h2 [dg hold]
check "H3 with nothing selected and nothing highlighted the status line says there is nothing to\
 bring out" [list $h1 $m1 $h2] \
  {1 {Dim: nothing is selected or highlighted, so there is nothing to bring out} 0}
xschem select instance R1
cb 4 250 -300 0 3 $ALTSH ; set h1 [dg hold]
cb 6 280 -300 0 0 0 ; set h2 [dg hold]
cb 4 250 -300 0 3 $ALTSH
cb 4 100 -400 0 2 0 ; set h3 [dg hold]
cb 5 100 -400 0 2 512
check "H4 a release that never arrives: the pointer moving with the right button up ends the\
 peek, and so does a press of another button that carries the right one as up" \
  [list $h1 $h2 $h3] {1 0 0}
cb 4 250 -300 0 3 $ALTSH
cb 4 250 -300 0 4 [expr {$ALTSH | $B3}] ; set h1 [dg hold]
cb 5 250 -300 0 4 [expr {$ALTSH | $B3 | 2048}] ; set h2 [dg hold]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}] ; set h3 [dg hold]
check "H4b a wheel step while the right button is down leaves the peek alone" [list $h1 $h2 $h3] {1 1 0}
cb 4 250 -300 0 3 $ALTSH
cb 8 250 -300 0 0 [expr {$ALTSH | $B3}]
cb 7 250 -300 0 0 0 ; set h1 [dg hold]
cb 6 252 -300 0 0 [expr {$ALTSH | $B3}] ; set h2 [dg hold]
cb 5 252 -300 0 3 [expr {$ALTSH | $B3}] ; set h3 [dg hold]
check "H4c the pointer leaving the canvas and coming back with the button down leaves it alone\
 too: the entry is handed over with a state of 0 whatever is held, and proves nothing" \
  [list $h1 $h2 $h3] {1 1 0}
## a wire tool left armed, as the Cadence profile leaves it after every wire (key w: 119)
xschem unselect_all ; xschem select instance R1
cb 6 220 -420 0 0 0
cb 2 220 -420 119 0 0
set u1 [expr {[xschem get ui_state] & 1}]
cb 4 250 -300 0 3 $ALTSH ; set h1 [dg hold]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}] ; set h2 [dg hold]
set u2 [expr {[xschem get ui_state] & 1}]
cb -3 250 -300 0 3 $ALTSH ; set h3 [dg hold]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}]
set w1 [xschem get wires]
cb 2 220 -420 65307 0 0
check "H4d with a wire being drawn the peek still works, a quick second one too, and the wire tool\
 is as it was when the button comes up" [list $u1 $h1 $h2 $u2 $h3 [expr {$w1 - $w0}]] {1 1 0 1 1 0}
xschem unbind button 3 alt+shift canvas
cb 6 220 -420 0 0 0
cb 2 220 -420 119 0 0
cb 4 250 -300 0 3 $ALTSH ; cb 5 250 -300 0 3 [expr {$ALTSH | $B3}]
set w1 [xschem get wires]
cb 2 220 -420 65307 0 0
xschem bind button 3 alt+shift canvas view.selection_dim_peek
check "H4e and with the chord unbound a wire being drawn is not cut by it, as it never was" \
  [expr {$w1 - $w0}] 0
cb -3 250 -300 0 3 $ALTSH ; set h1 [dg hold]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}] ; set h2 [dg hold]
check "H5 the second of two quick presses arrives as a double click and is a peek too" \
  [list $h1 $h2] {1 0}
xschem unselect_all
set w0 [xschem get wires]
cb 4 250 -300 0 3 65 ; cb 5 250 -300 0 3 [expr {65 | $B3}]
set w1 [xschem get wires] ; set h1 [dg hold]
xschem undo
cb 4 250 -300 0 3 8 ; cb 5 250 -300 0 3 [expr {8 | $B3}]
set w2 [xschem get wires]
xschem undo
check "H6 the wire cuts keep their other chords: Super-Shift-RightButton (not aligned) and\
 Alt-RightButton (aligned) each cut the wire under the pointer" \
  [list [expr {$w1 - $w0}] $h1 [expr {$w2 - $w0}] [xschem get wires]] [list 1 0 1 $w0]
xschem unbind button 3 alt+shift canvas
cb 4 250 -300 0 3 $ALTSH ; set h1 [dg hold]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}]
set w1 [xschem get wires]
xschem undo
xschem bind button 3 alt+shift canvas view.selection_dim_peek
cb 4 250 -300 0 3 $ALTSH ; set h2 [dg hold]
cb 5 250 -300 0 3 [expr {$ALTSH | $B3}]
check "H7 the peek's chord is a row of the table: unbound, Alt-Shift-RightButton is the cut\
 again; bound again it is the peek and cuts nothing" \
  [list $h1 [expr {$w1 - $w0}] $h2 [xschem get wires]] [list 0 1 1 $w0]

## ---------------------------------------------------------------------------------------------
## Z -- what needs a display
if {!$::X} {
  check "Z1 without a display nothing is wanted, and the colour query says what it needs" \
    [list [apply {{} { set ::selection_dim 1 ; xschem select instance R1 ; set w [dg wanted]
                       set ::selection_dim 0 ; xschem unselect_all ; return $w }}] \
          [catch {xschem get selection_dim_color 1} e] $e] \
    {0 1 {xschem get selection_dim_color: needs a display}}
  puts "skip: bands F A N I G L X P O M C W U need a display (window pixels, real events, Tk widgets)"
  finish
}

## =============================================================================================
## the display arm
proc snap {s} { settle ; xschem window_snapshot take $s }
proc px {slot x y} {
  lassign [w2s $x $y] a b ; return [lindex [xschem window_snapshot pixels $slot $a $b 1 1] 0]
}
## the pixel under a schematic point, in a fresh capture
proc pxnow {x y} { snap 5 ; return [px 5 $x $y] }
proc draws {script} {
  set d0 [xschem get drawcount] ; uplevel 1 $script ; settle
  return [expr {[xschem get drawcount] - $d0}]
}
## what the window shows against a fresh full redraw of the same state: differing pixels
proc vs_redraw {} {
  snap 6 ; xschem redraw ; snap 7 ; return [lindex [xschem window_snapshot diff 6 7] 0]
}
set ::T 100000
proc tick {dt} { incr ::T $dt ; return $::T }
set ::LPX 10 ; set ::LPY 10
proc motion {x y {st 0}} {
  lassign [w2s $x $y] px py ; set ::LPX $px ; set ::LPY $py
  event generate .drw <Motion> -x $px -y $py -state $st -when now ; update
}
## dt: ms since the last press. 1000 is a press of its own; 100 makes it the second of a double
proc press {x y {b 1} {st 0} {dt 1000}} {
  lassign [w2s $x $y] px py
  event generate .drw <ButtonPress-$b> -x $px -y $py -state $st -time [tick $dt] -when now ; update
}
proc release {x y {b 1} {st 0}} {
  lassign [w2s $x $y] px py
  event generate .drw <ButtonRelease-$b> -x $px -y $py -state [expr {$st | (256 << ($b - 1))}] \
    -time [tick 50] -when now
  update
}
proc key {k {st 0}} {
  focus -force .drw
  event generate .drw <KeyPress-$k> -x $::LPX -y $::LPY -state $st -when now
  event generate .drw <KeyRelease-$k> -x $::LPX -y $::LPY -state $st -when now
  update
}
set BG [layer_col 0]
set WIRE [layer_col 1]
set SELC {#ff8000}   ;# the selection colour's default on the dark scheme (build_colors())
## a fresh frame: band H's wire cuts leave their cue on the canvas, and `xschem undo` does not repaint
load_fix
check "pre the fixture is on the dark scheme with the default selection colour, and the wires\
 show in the wire layer's own colour" \
  [list $::dark_colorscheme $::selection_color [pxnow 250 -300] [pxnow 375 -140]] [list 1 {} $WIRE $WIRE]

## ---------------------------------------------------------------------------------------------
## F -- the frame follows the selection
load_fix
snap 0
set ::selection_dim 1
set n [draws {xschem get schname}]
snap 1
check "F1 on, with nothing selected: nothing is dim, nothing is redrawn" \
  [list [dstate] $n [lindex [xschem window_snapshot diff 0 1] 0]] {{w0 d0 h0 st0} 0 0}
set n [draws {xschem select instance R1}]
check "F2 a selection: the frame is dim after exactly one full redraw, and the dim colours are\
 not left in the layer GCs" [list [dstate] $n [dg applied]] {{w1 d1 h0 st0} 1 0}
set DIMW [mix $WIRE $BG 30]
snap 1
check "F3 a wire that is not selected is painted 30 percent of the way to the background, by\
 this suite's own arithmetic and by the colour query" \
  [list [px 1 250 -300] [px 1 375 -140] [xschem get selection_dim_color 1] [expr {$DIMW ne $WIRE}]] \
  [list $DIMW $DIMW $DIMW 1]
## the box B on layer 4 is filled with that layer's stipple, painted through a second GC
lassign [w2s 555 -235] ax ay ; lassign [w2s 625 -195] bx by
set reg [xschem window_snapshot pixels 1 $ax $ay [expr {$bx - $ax}] [expr {$by - $ay}]]
set reg0 [xschem window_snapshot pixels 0 $ax $ay [expr {$bx - $ax}] [expr {$by - $ay}]]
set L4P [layer_col 4] ; set L4D [mix $L4P $BG 30]
check "F3b a filled box: outline and fill are both dim, with not one pixel left in the layer's own colour" \
  [list [expr {[llength [lsearch -all -exact $reg0 $L4P]] > 50}] [llength [lsearch -all -exact $reg $L4P]] \
        [expr {[llength [lsearch -all -exact $reg $L4D]] == [llength [lsearch -all -exact $reg0 $L4P]]}]] {1 0 1}
## every kind of object the two passes sort, each in its own patch of the canvas: an instance
## (M1), a polygon, an arc, a line. None of them is selected, so none of it is in the layer's
## own colour and some of it is in the dim one.
set got {}
foreach {what x1 y1 x2 y2} {instance 445 -175 500 -105  polygon 555 -295 625 -255  arc 570 -120 610 -80
                             line 555 -195 625 -165} {
  lassign [w2s $x1 $y1] ax1 ay1 ; lassign [w2s $x2 $y2] bx1 by1
  set rg [xschem window_snapshot pixels 1 $ax1 $ay1 [expr {$bx1 - $ax1}] [expr {$by1 - $ay1}]]
  lappend got $what [llength [lsearch -all -exact $rg $L4P]] [expr {[llength [lsearch -all -exact $rg $L4D]] > 5}]
}
check "F3c an instance, a polygon, an arc and a line that are not selected are dim, each with not\
 one pixel left in the layer's own colour" $got \
  {instance 0 1 polygon 0 1 arc 0 1 line 0 1}
set cols [xschem window_snapshot colors 0 1]
check "F4 the selection itself is in the selection colour, undimmed, and the background has not moved" \
  [list [expr {[lsearch -exact $cols $SELC] >= 0}] [xschem get selection_dim_color 0] \
        [lindex [xschem window_snapshot pixels 1 2 2 1 1] 0]] [list 1 $BG $BG]
set n [draws {xschem select wire 2}]
set p1 [pxnow 250 -300]
set n2 [draws {xschem select wire 2 clear}]
set p2 [pxnow 250 -300]
check "F5 a dim frame is painted for one selection: one more object selected repaints it, once,\
 and the wire is in the selection colour; unselected again, once more, and the wire is dim" \
  [list $n $p1 $n2 $p2 [dstate]] [list 1 $SELC 1 $DIMW {w1 d1 h0 st0}]
## what is selected keeps its own colours under the overlay: the filled box, selected, has its
## fill in the layer's own colour (the overlay strokes only its outline), while the line of the
## same layer beside it, not selected, is dim
set n [draws {xschem select rect 4 0}]
snap 4
set reg [xschem window_snapshot pixels 4 $ax $ay [expr {$bx - $ax}] [expr {$by - $ay}]]
lassign [w2s 555 -195] cx cy ; lassign [w2s 625 -165] dx dy
set regl [xschem window_snapshot pixels 4 $cx $cy [expr {$dx - $cx}] [expr {$dy - $cy}]]
xschem select rect 4 0 clear ; settle
check "F5b a selected filled box keeps its fill in the layer's own colour, with none of it dim; the\
 unselected line beside it is dim, with none of it in the layer's own colour" \
  [list $n [expr {[llength [lsearch -all -exact $reg $L4P]] > 50}] [llength [lsearch -all -exact $reg $L4D]] \
        [expr {[llength [lsearch -all -exact $regl $L4D]] > 5}] [llength [lsearch -all -exact $regl $L4P]]] \
  {1 1 0 1 0}
set n [draws {xschem unselect_all}]
snap 2
check "F6 the selection gone: one full redraw, and the window is what it was before any of it" \
  [list [dstate] $n [lindex [xschem window_snapshot diff 0 2] 0]] {{w0 d0 h0 st0} 1 0}
set ::selection_dim 0
set r0 [xschem select instance M1] ; xschem unselect_all
set ::selection_dim 1
set d0 [xschem get drawcount]
set r1 [xschem select instance M1]
check "F7 the command that caused the redraw keeps its result" \
  [list $r1 [expr {$r1 ne {}}] [expr {[xschem get drawcount] - $d0}]] [list $r0 1 1]
set ::selection_dim 0
set n [draws {xschem get schname}]
check "F8 the setting changed by a plain `set` shows with the next xschem command" \
  [list [dstate] $n [pxnow 250 -300]] [list {w0 d0 h0 st0} 1 $WIRE]
## A redraw limited to a bbox repairs part of a frame, so it paints in the look the rest of the
## frame has, not the one wanted by now. While a bbox is set nothing repaints the whole frame;
## `xschem bbox end` lets the frame catch up.
xschem bbox start ; xschem bbox add 190 -310 310 -290 ; xschem bbox set
set ::selection_dim 1
xschem redraw ; settle
set p1 [pxnow 250 -300] ; set s1 [dstate]
xschem bbox end ; settle
check "F9 a redraw limited to a bbox keeps the look of the frame it repairs (plain here, though\
 dim is wanted by then); with the bbox ended the whole frame follows" \
  [list $p1 $s1 [pxnow 250 -300] [dstate]] [list $WIRE {w1 d0 h0 st0} $DIMW {w1 d1 h0 st0}]
set ::selection_dim 0 ; xschem get schname

## ---------------------------------------------------------------------------------------------
## A -- the amount
load_fix
xschem select instance R1
snap 0
set ::selection_dim 1 ; xschem get schname
set got {}
foreach p {60 100 5} {
  set ::selection_dim_percent $p ; xschem get schname
  lappend got [expr {[pxnow 250 -300] eq [mix $WIRE $BG $p]}] [dg built]
}
check "A1 another amount shows with the next command: 60, 100 (the background itself) and 5" \
  $got {1 60 1 100 1 5}
set ::selection_dim_percent 100 ; xschem get schname
check "A1b at 100 the wire is the background colour" [pxnow 250 -300] $BG
set ::selection_dim_percent 0
set n [draws {xschem get schname}]
snap 1
check "A2 at 0 nothing is dim: the frame is the one the same selection has with the setting off" \
  [list [dstate] $n [lindex [xschem window_snapshot diff 0 1] 0]] {{w0 d0 h0 st0} 1 0}
set ::selection_dim_percent 30 ; xschem get schname
set n [draws {selection_dim_percent_set 45}]
check "A3 selection_dim_percent_set repaints a dim frame at the new amount by itself" \
  [list $n [pxnow 250 -300]] [list 1 [mix $WIRE $BG 45]]
set ::selection_dim_percent 30 ; xschem get schname
## the amount changed by a plain `set`, and the first command after it is one that paints only
## part of the frame (the highlights, on their own): the whole frame must still follow
xschem hilight_netname A ; settle
set ::selection_dim_percent 60
set n [draws {xschem draw_hilight_net 1}]
set p1 [pxnow 250 -300]
xschem unhilight_all ; set ::selection_dim_percent 30 ; xschem get schname ; settle
check "A3b the amount changed by a plain `set` and then a command that paints only the highlights:\
 the whole frame is repainted at the new amount" [list $n $p1] [list 1 [mix $WIRE $BG 60]]
xschem toggle_colorscheme ; settle
set lw [layer_col 1] ; set lb [layer_col 0]
set p1 [pxnow 250 -300] ; set s1 [dstate]
xschem toggle_colorscheme ; settle
check "A4 the other colour scheme: the dim colours are made afresh from its layer colours and\
 its background, and from the first again on the way back" \
  [list [expr {$lb ne $BG}] $p1 $s1 [pxnow 250 -300]] [list 1 [mix $lw $lb 30] {w1 d1 h0 st0} $DIMW]

## ---------------------------------------------------------------------------------------------
## K, H on a display -- real events
load_fix
motion 100 -400
key D 13 ; set v1 $::selection_dim
xschem select instance R1 ; settle ; set s1 [dstate]
key D 13 ; set v2 $::selection_dim ; settle ; set s2 [dstate]
check "K4 a real Ctrl-Alt-Shift-D on the canvas: on, a selection dims; off, the frame is plain again" \
  [list $v1 $s1 $v2 $s2] {1 {w1 d1 h0 st0} 0 {w0 d0 h0 st0}}
set w0 [xschem get wires]
motion 250 -300
set n1 [draws {press 250 -300 3 $ALTSH}]
set s1 [dstate] ; set p1 [pxnow 250 -300]
set n2 [draws {motion 260 -300 [expr {$ALTSH | $B3}]}]
set n3 [draws {release 260 -300 3 $ALTSH}]
set s3 [dstate] ; set p3 [pxnow 250 -300]
check "H8 a real Alt-Shift-RightButton held: one redraw to the dim frame, none while the pointer\
 moves, one back at the release; no context menu, no wire cut" \
  [list $n1 $s1 $p1 $n2 $n3 $s3 $p3 [winfo exists .ctxmenu] [xschem get wires]] \
  [list 1 {w1 d1 h1 st0} $DIMW 0 1 {w0 d0 h0 st0} $WIRE 0 $w0]
press 250 -300 3 $ALTSH 100 ; settle ; set s1 [dstate]
release 250 -300 3 0 ; settle ; set s2 [dstate]
check "H9 a second press right after is a peek again (Tk hands it over as a double click), and\
 the release with Alt and Shift already up ends it without a context menu" \
  [list $s1 $s2 [winfo exists .ctxmenu]] {{w1 d1 h1 st0} {w0 d0 h0 st0} 0}
set ::selection_dim 1 ; xschem get schname ; settle
set n1 [draws {press 250 -300 3 $ALTSH}]
set n2 [draws {release 250 -300 3 $ALTSH}]
check "H10 with the setting on the peek changes nothing and costs no redraw" \
  [list $n1 $n2 [dstate]] {0 0 {w1 d1 h0 st0}}
set ::selection_dim 0 ; xschem unselect_all ; settle
set n1 [draws {press 250 -300 3 $ALTSH}]
set n2 [draws {release 250 -300 3 $ALTSH}]
check "H11 with nothing selected the peek costs no redraw either" [list $n1 $n2 [dstate]] {0 0 {w0 d0 h0 st0}}
## nothing selected, a net highlighted (what a Find in its default Highlight mode leaves): the
## peek brings the highlight out
xschem hilight_netname A ; settle
set hic [pxnow 375 -140]
set n1 [draws {press 250 -300 3 $ALTSH}]
set s1 [dstate] ; snap 4
set p1 [px 4 375 -140] ; set p2 [px 4 250 -300]
set n2 [draws {release 250 -300 3 $ALTSH}]
set s2 [dstate] ; set p3 [pxnow 250 -300]
set ::selection_dim 1 ; xschem get schname ; settle ; set s3 [dstate]
set ::selection_dim 0 ; xschem unhilight_all ; settle
check "H12 with nothing selected the peek brings out what is highlighted: the highlighted net keeps\
 its colour, the rest is dim, and the release puts the frame back; the setting alone dims\
 nothing around a highlight" \
  [list [expr {$hic ne $WIRE}] $n1 $s1 $p1 $p2 $n2 $s2 $p3 $s3] \
  [list 1 1 {w2 d2 h1 st0} $hic $DIMW 1 {w0 d0 h0 st0} $WIRE {w0 d0 h0 st0}]

## ---------------------------------------------------------------------------------------------
## N -- no redraw that is not owed
load_fix
set n [draws {
  xschem select instance R1 ; xschem select wire 2 ; xschem unselect_all
  foreach {x y} {250 -300 375 -140 410 -30 100 -400 470 -140} { motion $x $y }
}]
check "N1 with the setting off and no peek, selecting, unselecting and moving the pointer cost no\
 full redraw" $n 0
set ::selection_dim 1 ; xschem select instance R1 ; settle
set n [draws {
  foreach {x y} {250 -300 375 -140 410 -30 100 -400 470 -140 300 -200 590 -215 250 -300} { motion $x $y }
}]
check "N2 over a dim frame the pointer moving across objects (the hover outline comes and goes)\
 costs no full redraw, and nothing is left to repaint" [list $n [dstate]] {0 {w1 d1 h0 st0}}
check "N3 and the frame is still what a fresh redraw paints" [vs_redraw] 0

## ---------------------------------------------------------------------------------------------
## I -- painters of the document outside a full redraw
load_fix
set ::selection_dim 1 ; xschem select instance R1 ; settle
xschem wire 220 -250 280 -250 ; settle
check "I1 a wire placed by command over a dim frame is dim, and the canvas is what a fresh\
 redraw paints" [list [pxnow 250 -250] [dstate] [vs_redraw]] [list $DIMW {w1 d1 h0 st0} 0]
xschem line 220 -230 280 -230 ; xschem rect 220 -100 260 -80 ; settle
set L4 [mix [layer_col [xschem get rectcolor]] $BG 30]
check "I2 so are a line and a box" [list [pxnow 250 -230] [pxnow 240 -100] [dstate] [vs_redraw]] \
  [list $L4 $L4 {w1 d1 h0 st0} 0]
## the highlight's own colour and what the command costs, read with the dim off
set ::selection_dim 0 ; xschem get schname
set n0 [draws {xschem hilight_netname A}] ; set HIC [pxnow 375 -140]
xschem unhilight_all ; settle
set ::selection_dim 1 ; xschem get schname ; settle
set n [draws {xschem hilight_netname A}]
check "I3 a net highlighted over a dim frame takes the dim of its own colour (a layer's, read with\
 the dim off), for the redraws the command costs anyway, and the canvas is what a fresh redraw paints" \
  [list [expr {$HIC ne $WIRE}] [expr {[lsearch -exact [string tolower $tctx::colors] $HIC] >= 0}] \
        [pxnow 375 -140] [expr {$n - $n0}] [dstate] [vs_redraw]] \
  [list 1 1 [mix $HIC $BG 30] 0 {w1 d1 h0 st0} 0]
## `xschem draw_hilight_net 1` strokes the highlights again straight onto the canvas, with no
## full redraw: they must stay the dim frame's
## (The stroke-again is not compared with a fresh redraw: it paints the label's letters a second
## time over themselves, which thickens them, with the dim off as well. What is asked instead:
## around net A no pixel is in the highlight's undimmed colour, and many are in its dim one.)
set n [draws {xschem draw_hilight_net 1}]
snap 5
lassign [w2s 300 -160] ax0 ay0 ; lassign [w2s 430 -50] bx0 by0
set reg [xschem window_snapshot pixels 5 $ax0 $ay0 [expr {$bx0 - $ax0}] [expr {$by0 - $ay0}]]
check "I3b highlights stroked again on their own (xschem draw_hilight_net) over a dim frame stay dim" \
  [list $n [px 5 375 -140] [dstate] [llength [lsearch -all -exact $reg $HIC]] \
        [expr {[llength [lsearch -all -exact $reg [mix $HIC $BG 30]]] > 20}]] \
  [list 0 [mix $HIC $BG 30] {w1 d1 h0 st0} 0 1]
## the same stroke over a frame that is NOT dim (the setting on, nothing selected) stays plain
xschem unselect_all ; settle
xschem draw_hilight_net 1 ; snap 5
set p1 [px 5 375 -140] ; set s1 [dstate]
xschem select instance R1 ; settle
check "I3c over a plain frame the same stroke keeps the highlight's own colour" [list $p1 $s1] \
  [list $HIC {w0 d0 h0 st0}]
xschem unhilight_all ; settle
check "I4 the highlight removed: the wire is dim again" [list [pxnow 375 -140] [vs_redraw]] [list $DIMW 0]
## a style with a colour of its own: no layer's table holds it. Solid, it is stroked through
## the highlight GC and the label on the net through a borrowed layer GC; dashed at an angle,
## through cairo. All three must come out dim: around net A not one pixel in the style's own
## colour, and many in its dim one.
set CUS {#a020f0} ; set CUSD [mix $CUS $BG 30]
set got {}
foreach style {{0 #a020f0 1 {} 0 0 none 0} {0 #a020f0 4 {8 8} 30 0 none 0}} {
  net_hilight_style_replace [list $style]
  xschem hilight_netname A ; settle ; snap 5
  set reg [xschem window_snapshot pixels 5 $ax0 $ay0 [expr {$bx0 - $ax0}] [expr {$by0 - $ay0}]]
  lappend got [llength [lsearch -all -exact $reg $CUS]] [expr {[llength [lsearch -all -exact $reg $CUSD]] > 20}]
  xschem unhilight_all ; settle
}
net_hilight_style_reset ; settle
check "I5 a highlight style with a colour of its own is dimmed too: the solid stroke, the label on\
 the net, and a dashed stroke at an angle" $got {0 1 0 1}
xschem move_objects 20 0 ; settle
check "I6 the selection moved: what stays behind and around is dim, the canvas is a fresh redraw's" \
  [list [pxnow 250 -300] [dstate] [vs_redraw]] [list $DIMW {w1 d1 h0 st0} 0]
set w0 [xschem get wires]
motion 220 -60 ; key w ; motion 300 -60
press 300 -60 1 0 ; release 300 -60 1 0 ; key Escape ; settle
motion 100 -400 ; settle
check "I7 a wire drawn with the mouse while the selection stands is dim" \
  [list [expr {[xschem get wires] - $w0}] [pxnow 260 -60] [dstate] [vs_redraw]] [list 1 $DIMW {w1 d1 h0 st0} 0]

## ---------------------------------------------------------------------------------------------
## G -- an embedded graph repainted on its own (xschem draw_graph, what a cursor move or a zoom
## inside the graph does) over a dim frame
set fd [open [file join $dir graph.sch] w]
puts -nonewline $fd {v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
B 2 300 -320 560 -160 {flags=graph
y1=0
y2=2
ypos1=0
ypos2=2
divy=5
subdivy=1
unity=1
x1=0
x2=10e-6
divx=5
subdivx=1
node=""
color=""
dataset=-1
unitx=1
logx=0
logy=0
}
N 200 -100 300 -100 {lab=B}
}
close $fd
xschem set modified 0
xschem load -nofullzoom [file join $dir graph.sch] ; xschem zoom_full ; settle
set ::selection_dim 0 ; xschem unselect_all ; settle
lassign [w2s 295 -325] gx gy ; lassign [w2s 565 -155] hx hy
proc gcols {} {
  snap 5
  return [lsort -unique [xschem window_snapshot pixels 5 $::gx $::gy [expr {$::hx - $::gx}] [expr {$::hy - $::gy}]]]
}
set plain [gcols]
set ::selection_dim 1 ; xschem select wire 0 ; settle
set dimmed [gcols]
set n [draws {xschem draw_graph 0}]
set again [gcols]
check "G1 a graph repainted on its own over a dim frame keeps the frame's colours: the colours in\
 its area are the dim frame's, none of them new, for no full redraw" \
  [list [expr {[llength $plain] > 1}] [expr {$dimmed ne $plain}] [expr {$again eq $dimmed}] $n [dstate]] \
  {1 1 1 0 {w1 d1 h0 st0}}
xschem unselect_all ; xschem select rect 2 0 ; settle
set own [gcols]
set n [draws {xschem draw_graph 0}]
set own2 [gcols]
## the selection overlay adds its colour to the area; the graph's own colours must all be there
proc subset {a b} { foreach x $a { if {[lsearch -exact $b $x] < 0} { return 0 } } ; return 1 }
check "G2 a graph that is itself selected is painted in its own colours, in the full redraw and\
 when it is repainted on its own, while the wire outside it is dim" \
  [list [subset $plain $own] [subset $plain $own2] $n [pxnow 250 -100] [dstate]] \
  [list 1 1 0 $DIMW {w1 d1 h0 st0}]

## ---------------------------------------------------------------------------------------------
## L -- the four Selection looks
set got {} ; set want {}
foreach look {classic bright brightbox halo} {
  load_fix
  set ::selection_style $look ; xschem build_colors ; xschem redraw ; settle
  set ::selection_dim 1 ; xschem select wire 2 ; settle
  motion 100 -400
  snap 3
  lappend got [list $look [px 3 375 -140] [px 3 250 -300] [vs_redraw]]
  switch $look {
    classic { set me [layer_col 2] }
    halo    { set me $WIRE }
    default { set me $SELC }
  }
  lappend want [list $look $DIMW $me 0]
}
set ::selection_style brightbox ; xschem build_colors ; xschem redraw ; settle
check "L1 in every look the unselected wire is dim; the selected one is the selection colour in\
 bright and bright with box, its own undimmed colour in halo, and the grid layer's undimmed\
 grey in classic" $got $want

## ---------------------------------------------------------------------------------------------
## X -- an export is never dim
proc png_colours {f} {
  set out {}
  if {![file exists $f] || [catch {image create photo seldim_png -file $f}]} { return nopng }
  for {set y 0} {$y < [image height seldim_png]} {incr y} {
    for {set x 0} {$x < [image width seldim_png]} {incr x} {
      dict set out [format "#%02x%02x%02x" {*}[seldim_png get $x $y]] 1
    }
  }
  image delete seldim_png
  return [dict keys $out]
}
load_fix
set L4P [layer_col 4] ; set L4D [mix $L4P $BG 30]
set ::selection_dim 1 ; xschem select instance R1 ; settle
set p0 [pxnow 375 -140]
set png [file join $dir out.png]
xschem print png $png ; settle
set cols [png_colours $png]
check "X1 `xschem print png` of a selection (it prints the selection's area and drops the\
 selection, as it always did) holds the symbol in its own colour and none of the dim one; the\
 frame is plain afterwards, nothing being selected" \
  [list $p0 [expr {[lsearch -exact $cols $L4P] >= 0}] [expr {[lsearch -exact $cols $L4D] >= 0}] \
        [xschem get lastsel] [dstate] [vs_redraw]] [list $DIMW 1 0 0 {w0 d0 h0 st0} 0]
## Ctrl-* prints the window as it stands, selection kept. Its file dialog is answered here.
xschem select instance R1 ; settle
set png2 [file join $dir out2.png]
rename save_file_dialog seldim_saved_sfd
proc save_file_dialog {args} { return $::png2 }
motion 100 -400
key asterisk 5 ; settle
rename save_file_dialog {} ; rename seldim_saved_sfd save_file_dialog
set got {}
if {[file exists $png2] && ![catch {image create photo seldim_png -file $png2}]} {
  lassign [w2s 375 -140] a b
  lappend got [format "#%02x%02x%02x" {*}[seldim_png get $a $b]]
  image delete seldim_png
} else {
  lappend got nopng
}
## the same print with a net highlighted: the highlight is stroked by a painter that joins a dim
## frame when it runs on its own, and must not take the export for one
xschem hilight_netname A ; settle
set png3 [file join $dir out3.png]
rename save_file_dialog seldim_saved_sfd
proc save_file_dialog {args} { return $::png3 }
key asterisk 5 ; settle
rename save_file_dialog {} ; rename seldim_saved_sfd save_file_dialog
set got3 nopng
if {[file exists $png3] && ![catch {image create photo seldim_png -file $png3}]} {
  lassign [w2s 375 -140] a b
  set got3 [format "#%02x%02x%02x" {*}[seldim_png get $a $b]]
  image delete seldim_png
}
set ::selection_dim 0 ; xschem get schname ; set hic [pxnow 375 -140]
set ::selection_dim 1 ; xschem get schname
xschem unhilight_all ; settle
check "X3 with a net highlighted the PNG holds the highlight in its own colour as well" \
  [list [expr {$hic ne $WIRE}] $got3] [list 1 $hic]
check "X2 Ctrl-* (print the window, selection kept) while the frame is dim: the PNG holds the wire\
 in its own colour, and the window is still the dim frame a fresh redraw paints" \
  [list [lindex $got 0] [xschem get lastsel] [dstate] [pxnow 375 -140] [vs_redraw]] \
  [list $WIRE 1 {w1 d1 h0 st0} $DIMW 0]

## an SVG holds an embedded graph as a picture of it, painted through the graph painter into the
## backing pixmap: it must come out in the graph's own colours though the window's frame is dim
xschem set modified 0
xschem load -nofullzoom [file join $dir graph.sch] ; xschem zoom_full ; settle
set ::selection_dim 0 ; xschem unselect_all ; settle
set svg0 [file join $dir g0.svg] ; set svg1 [file join $dir g1.svg]
proc svg_graph_colours {f} {
  if {![file exists $f]} { return nosvg }
  if {![regexp {base64,([A-Za-z0-9+/=\s]+)} [slurp $f] -> b64]} { return nopicture }
  if {[catch {image create photo seldim_png -data [regsub -all {\s} $b64 {}]}]} { return nophoto }
  set out {}
  for {set y 0} {$y < [image height seldim_png]} {incr y 3} {
    for {set x 0} {$x < [image width seldim_png]} {incr x 3} {
      dict set out [format "#%02x%02x%02x" {*}[seldim_png get $x $y]] 1
    }
  }
  image delete seldim_png
  return [lsort [dict keys $out]]
}
xschem print svg $svg0 ; settle
set c0 [svg_graph_colours $svg0]
## the print takes the area of what is selected and drops the selection: the wire and the graph
## are both selected for it, so the graph is in the area; the frame in the window stays the dim
## one until the print is done, which is what the graph painter sees
set ::selection_dim 1 ; xschem select wire 0 ; settle
set s1 [dstate]
xschem select rect 2 0 fast nodraw
xschem print svg $svg1 ; settle
set c1 [svg_graph_colours $svg1]
check "X4 an SVG printed while the frame is dim holds its embedded graph in the same colours as one\
 printed with the setting off" [list [expr {[llength $c0] > 1}] $s1 [expr {$c1 eq $c0}]] {1 {w1 d1 h0 st0} 1}
set ::selection_dim 0 ; xschem unselect_all ; settle

## ---------------------------------------------------------------------------------------------
## P -- an embedded picture
image create photo seldim_red -width 40 -height 40
seldim_red put #ff0000 -to 0 0 40 40
seldim_red write [file join $dir red.png] -format png
image delete seldim_red
set fd [open [file join $dir pic.sch] w]
puts -nonewline $fd "v {xschem version=3.4.6 file_version=1.2}
G {}
K {}
V {}
S {}
E {}
B 2 300 -300 400 -200 {flags=image
image=[file join $dir red.png]}
N 200 -100 300 -100 {lab=B}
N 200 -350 500 -350 {lab=C}
"
close $fd
xschem set modified 0
xschem load -nofullzoom [file join $dir pic.sch] ; xschem zoom_full ; settle
set ::selection_dim 0 ; xschem unselect_all ; settle
proc near {a b} {
  foreach x [rgb $a] y [rgb $b] { if {abs($x - $y) > 4} { return 0 } }
  return 1
}
set p0 [pxnow 350 -250]
set ::selection_dim 1 ; xschem select wire 0 ; settle
set p1 [pxnow 350 -250]
check "P1 a picture is painted that much towards the background too (within 4 of 255 a channel)" \
  [list [near $p0 {#ff0000}] [near $p1 [mix {#ff0000} $BG 30]] [dstate]] {1 1 {w1 d1 h0 st0}}
xschem unselect_all ; xschem select rect 2 0 ; settle
check "P2 a picture that is itself selected keeps its colours, while the wire beside it is dim" \
  [list [near [pxnow 350 -250] {#ff0000}] [pxnow 250 -100] [dstate]] [list 1 $DIMW {w1 d1 h0 st0}]

## ---------------------------------------------------------------------------------------------
## O -- the only-probes view
load_fix
set ::selection_dim 1 ; xschem select instance R1 ; settle
xschem only_probes ; settle
set s1 [dstate]
xschem only_probes ; settle
set s2 [dstate] ; set p2 [pxnow 250 -300]
## Leaving that view leaves every layer a shade brighter until the colours are next built, with
## this feature or without (draw() ends that view's frame with build_colors(1.0, 0)). So the dim
## wire is measured against the wire as it is then, read here with the dim off.
set ::selection_dim 0 ; xschem get schname ; set plain [pxnow 250 -300]
xschem build_colors ; xschem redraw ; settle
check "O1 the only-probes view recolours every layer by its own rule and is not dimmed on top;\
 leaving it, the dim frame is back" [list $s1 $s2 $p2] \
  [list {w0 d0 h0 st0} {w1 d1 h0 st0} [mix $plain $BG 30]]

## ---------------------------------------------------------------------------------------------
## M -- the View menu
load_fix
set m .menubar.view
set idx {}
for {set i 0} {$i <= [$m index end]} {incr i} {
  if {[$m type $i] ne {separator} && [$m entrycget $i -label] eq {Dim unselected objects}} { set idx $i }
}
check "M1 View > Dim unselected objects is a check entry on selection_dim showing its key" \
  [list [expr {$idx ne {}}] [$m type $idx] [$m entrycget $idx -variable] [$m entrycget $idx -accelerator]] \
  {1 checkbutton selection_dim Ctrl+Alt+Shift+D}
$m invoke $idx ; set v1 $::selection_dim ; set m1 [string range [xschem get statusmsg] 0 31]
$m invoke $idx ; set v2 $::selection_dim
check "M2 choosing it flips the setting once each time and says so" [list $v1 $m1 $v2] \
  {1 {Dim unselected objects: ON (30%)} 0}
set c $m.seldim
set ents {}
for {set i 0} {$i <= [$c index end]} {incr i} {
  switch [$c type $i] {
    radiobutton { lappend ents [$c entrycget $i -value] }
    separator   { lappend ents - }
    default     { lappend ents [$c entrycget $i -label] }
  }
}
$c invoke 4 ; set v1 $::selection_dim_percent
set ::selection_dim_percent 30
check "M3 View > Dimming amount: 10 to 90 percent on selection_dim_percent, then Other...;\
 choosing one sets it, by a command that carries the amount itself" \
  [list $ents [$c entrycget 0 -variable] $v1 [$c entrycget 4 -command]] \
  {{10 20 30 40 50 60 70 80 90 - Other...} selection_dim_percent 50 {selection_dim_percent_set 50}}
set ::selection_dim true ; update
set shown $::selection_dim
$m invoke $idx ; set v1 $::selection_dim
check "M4 with the setting written as `true` the entry shows it on and one choice switches it off" \
  [list $shown $v1] {1 0}

## ---------------------------------------------------------------------------------------------
## C -- the Cadence profile's two key lines, taken from src/cadence_style_rc itself
set l1 {} ; set l2 {}
regexp -line {^bind \.drw <Alt-Key-D>\s.*$} $rc l1
regexp -line {^bind \.drw <Control-Alt-Key-D>\s.*$} $rc l2
set ::pd {}
namespace eval ase {}
if {[llength [info commands ::ase::plot_difference_for_current]]} {
  rename ::ase::plot_difference_for_current ::ase::seldim_saved_pd
}
proc ::ase::plot_difference_for_current {args} { lappend ::pd $args }
load_fix
motion 100 -400
set old1 [bind .drw <Alt-Key-D>] ; set old2 [bind .drw <Control-Alt-Key-D>]
eval $l1
bind .drw <Control-Alt-Key-D> {}
set ::pd {} ; set ::selection_dim 0
key D 13
set a1 [list $::pd $::selection_dim]
eval $l2
set ::pd {} ; set ::selection_dim 0
key D 13
set a2 [list $::pd $::selection_dim]
set ::pd {} ; set ::selection_dim 0
key D 9
set a3 [list $::pd $::selection_dim]
bind .drw <Alt-Key-D> $old1 ; bind .drw <Control-Alt-Key-D> $old2
rename ::ase::plot_difference_for_current {}
if {[llength [info commands ::ase::seldim_saved_pd]]} {
  rename ::ase::seldim_saved_pd ::ase::plot_difference_for_current
}
set ::selection_dim 0
check "C1 the profile's Alt-Shift-D line alone takes Ctrl-Alt-Shift-D as well (a Tk sequence\
 matches a key carrying more modifiers than it names): the difference is plotted, nothing is dimmed" \
  [list [expr {$l1 ne {}}] $a1] {1 {tran 0}}
check "C2 with the profile's Control-Alt line beside it, Ctrl-Alt-Shift-D is the toggle and\
 Alt-Shift-D still plots the difference" [list [expr {$l2 ne {}}] $a2 $a3] {1 {{} 1} {tran 0}}

## ---------------------------------------------------------------------------------------------
## W -- the waveform viewer. Its canvas carries the WaveViewer bind tag, whose <Control-Shift-Key-D>
## (clear the target strip) would take Ctrl-Alt-Shift-D as well. A frame with that tag stands in
## for a viewer canvas here; the clear is replaced by a spy.
set ::wv {}
if {[llength [info commands ::wviewer::clear_target_subwin_at]]} {
  rename ::wviewer::clear_target_subwin_at ::wviewer::seldim_saved_clear
}
namespace eval wviewer {}
proc ::wviewer::clear_target_subwin_at {args} { lappend ::wv clear }
## the viewer's key lines are put on the tag when the first viewer opens
catch {wviewer::install_default_binds}
frame .seldim_wv -width 40 -height 40 -takefocus 1
bindtags .seldim_wv {WaveViewer .seldim_wv}
place .seldim_wv -x 0 -y 0
update ; focus -force .seldim_wv ; update
set ::selection_dim 0
event generate .seldim_wv <KeyPress-D> -state 13 -when now ; update
set a1 [list $::wv $::selection_dim]
## Caps Lock on (state bit 2) and no Shift types the capital too; a server gives either keysym
set ::wv {} ; set ::selection_dim 0
event generate .seldim_wv <KeyPress-D> -state 14 -when now ; update
set a2 [list $::wv $::selection_dim]
set ::wv {} ; set ::selection_dim 0
event generate .seldim_wv <KeyPress-d> -state 14 -when now ; update
lappend a2 $::wv $::selection_dim
set ::wv {} ; set ::selection_dim 0
event generate .seldim_wv <KeyPress-D> -state 5 -when now ; update
set a3 [list $::wv $::selection_dim]
destroy .seldim_wv
rename ::wviewer::clear_target_subwin_at {}
if {[llength [info commands ::wviewer::seldim_saved_clear]]} {
  rename ::wviewer::seldim_saved_clear ::wviewer::clear_target_subwin_at
}
set ::selection_dim 0
check "W1 in a waveform viewer Ctrl-Alt-Shift-D flips the editor's setting and clears nothing, and\
 so does the capital typed with Caps Lock and no Shift; Ctrl-Shift-D still clears the target strip" \
  [list $a1 $a2 $a3] {{{} 1} {{} 1 {} 1} {clear 0}}
load_fix
set ::selection_dim 1 ; xschem select instance R1 ; settle ; set s1 [dstate]
xschem set wave_viewer 1 ; xschem get schname ; settle
set s2 [dstate] ; set p2 [pxnow 250 -300]
xschem set wave_viewer 0 ; xschem get schname ; settle
check "W2 a window that is a waveform viewer is never dimmed" [list $s1 $s2 $p2 [dstate]] \
  [list {w1 d1 h0 st0} {w0 d0 h0 st0} $WIRE {w1 d1 h0 st0}]

## ---------------------------------------------------------------------------------------------
## U -- what the dim takes and what it leaves alone
load_fix
set GRID [layer_col 2]
lassign [w2s 440 -290] gx gy ; lassign [w2s 540 -250] hx hy
proc ucols {} {
  snap 5
  return [lsort -unique [xschem window_snapshot pixels 5 $::gx $::gy [expr {$::hx - $::gx}] [expr {$::hy - $::gy}]]]
}
set g0 [ucols]
## the brightest green of the floating note's letters (they are anti-aliased against the background)
proc text_peak {} {
  snap 5
  lassign [w2s 298 -202] a b ; lassign [w2s 420 -178] c d
  set m 0
  foreach p [xschem window_snapshot pixels 5 $a $b [expr {$c - $a}] [expr {$d - $b}]] {
    set g [lindex [rgb $p] 1] ; if {$g > $m} { set m $g }
  }
  return $m
}
set t0 [text_peak]
xschem pin_marker add -layer 16 -tag seldim R1 P ; settle
set M16 [layer_col 16]
lassign [w2s 400 -70] mx0 my0 ; lassign [w2s 420 -50] mx1 my1
snap 5
set mk0 [xschem window_snapshot pixels 5 $mx0 $my0 [expr {$mx1 - $mx0}] [expr {$my1 - $my0}]]
set ::selection_dim 1 ; xschem select wire 2 ; settle
motion 100 -400
set g1 [ucols] ; set t1 [text_peak]
snap 5
set mk1 [xschem window_snapshot pixels 5 $mx0 $my0 [expr {$mx1 - $mx0}] [expr {$my1 - $my0}]]
check "U1 the grid dots are dim: an empty patch of the canvas holds the background and the grid\
 colour, and under the dim the background and the grid's dim colour" \
  [list $g0 $g1] [list [lsort [list $BG $GRID]] [lsort [list $BG [mix $GRID $BG 30]]]]
check "U2 a text is dim: the brightest of its letters is 70 percent of what it was (within 3 of 255)" \
  [list [expr {$t0 > 100}] [expr {abs($t1 - round(0.7 * $t0)) <= 3}]] {1 1}
check "U3 a pin marker is dim: it was in its layer's colour, and under the dim none of it is" \
  [list [expr {[llength [lsearch -all -exact $mk0 $M16]] > 5}] [llength [lsearch -all -exact $mk1 $M16]] \
        [expr {[llength [lsearch -all -exact $mk1 [mix $M16 $BG 30]]] > 5}]] {1 0 1}
xschem pin_marker clear -tag seldim ; settle
## the hover outline (yellow by default) around a dim wire, and the crosshair in its layer's colour
motion 375 -140 ; settle ; snap 5
lassign [w2s 335 -150] a b ; lassign [w2s 415 -130] c d
set hov [xschem window_snapshot pixels 5 $a $b [expr {$c - $a}] [expr {$d - $b}]]
set ::draw_crosshair 1
motion 520 -270 ; settle ; snap 5
set XH [layer_col $::crosshair_layer]
lassign [w2s 520 -270] a b
set xh [xschem window_snapshot pixels 5 [expr {$a - 60}] [expr {$b - 12}] 40 25]
set ::draw_crosshair 0
motion 100 -400 ; xschem redraw ; settle
check "U4 over a dim frame the hover outline is its own yellow and the crosshair (a dashed line)\
 its layer's own colour, with none of it in that layer's dim colour" \
  [list [expr {[llength [lsearch -all -exact $hov {#ffff00}]] > 5}] \
        [expr {[llength [lsearch -all -exact $xh $XH]] >= 10}] \
        [llength [lsearch -all -exact $xh [mix $XH $BG 30]]] [dstate]] {1 1 0 {w1 d1 h0 st0}}

finish
