# An EXPOSE must be honoured even while a new window is opening (issue 0848).
#
# callback.c's handle_window_switching() used to drop EVERY switch event -- FocusIn,
# EnterNotify and Expose alike -- whenever xctx->pending_fullzoom was armed, with the
# comment "no switching if opening a new window". That reasoning holds for focus events,
# which really would steal the new window's context. It does not hold for an Expose: an
# Expose is another window saying its pixels are gone, and the arm it feeds does a
# redraw-ONLY switch that restores the previous context immediately. Dropping it does not
# protect the window being opened; it corrupts a DIFFERENT window and leaves it corrupt.
#
# Measured on the user's screen 2026-08-26: the waveform viewer opens congruent with the
# design window, paints, and is stepped aside by wviewer::uncover. The design window's
# Expose for the region just vacated arrives while the viewer still has pending_fullzoom
# armed -- so the schematic canvas kept the viewer's waveform pixels. That is what "the
# double-click corrupts the schematic window" was.
#
# This suite reproduces the shape of that with two ordinary schematic windows, and reads
# the actual canvas pixels, because the defect is invisible to every other instrument.
#
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_expose_repaint.tcl
#
# ⚠ NEVER "VERIFY" THIS ON :0. The user reports the defect never appears under WSLg, and
# that is the mechanism rather than luck: Xwayland keeps obscured window contents itself,
# so the application is never asked to repaint and neither of the two bugs can fire. An
# AUDIT_DISPLAY=:0 run of this file is a guaranteed pass and says nothing. Xvfb (:99, the
# dev display) DOES reproduce it -- 0.0263 differing pixels with the bugs in, 0.0000 with
# them out -- and so does the user's VcXsrv over TCP ($DISPLAY). The CLAUDE.md rule "run a
# GUI feature's suite on :0 once before calling it done" is exactly backwards for this
# one: :0 is the environment that cannot see the defect.

set ::fail 0
proc check {n ok {d {}}} {
  if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d" ; incr ::fail }
}
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; window pixels are the subject)" ; flush stdout ; exit 0 }
foreach _t {xwd convert compare} {
  if {[auto_execok $_t] eq {}} {
    puts "RESULT: SKIP (needs $_t; this suite reads real canvas pixels)" ; flush stdout ; exit 0
  }
}

source [file join [file dirname [info script]] scratch.tcl]
set dir [test_scratch expose]
proc pump {ms} { for {set i 0} {$i < $ms} {incr i 50} { update ; after 50 } }
proc shot {w path} {
  set id {}
  if {[catch {winfo id $w} id]} { return 0 }
  if {[catch {exec xwd -id $id -silent | convert xwd:- $path}]} { return 0 }
  return [file exists $path]
}
# fraction of differing pixels, 0.0 .. 1.0; -1 if the comparison could not be made
proc pxdiff {a b} {
  set n {}
  catch {set n [exec compare -metric AE $a $b null:]} n
  if {![string is double -strict [string trim $n]]} { return -1 }
  set g {}
  if {[catch {exec convert $a -format "%w %h" info:} g]} { return -1 }
  lassign $g w h
  if {$w * $h == 0} { return -1 }
  return [expr {double([string trim $n]) / ($w * $h)}]
}

# two schematics that look different from each other
set libs [glob -nocomplain [file join [pwd] xschem_library * *.sch]]
if {[llength $libs] < 2} { set libs [glob -nocomplain [file join [pwd] xschem_library *.sch]] }
if {[llength $libs] < 2} { puts "RESULT: SKIP (need two library schematics to tell the canvases apart)" ; flush stdout ; exit 0 }
set fA [lindex $libs 0]
set fB [lindex $libs end]

wm geometry . 700x500+60+60
xschem load $fA
xschem zoom_full
pump 700
set P0 [file join $dir P0.png]
check "E1 the design canvas could be captured" [shot .drw $P0] "(=> $P0)"

# ⚠ the capture must actually contain a drawing. A blank canvas compares equal to
# anything and would make every row below pass without measuring a thing.
# a blank canvas compares equal to anything, so every row below would pass while
# measuring nothing. Count non-background pixels instead of trusting the capture.
set ink -1
catch {set ink [exec convert $P0 -colorspace Gray -format {%[fx:mean]} info:]}
check "E2 ... and it is not a blank canvas (otherwise nothing below measures anything)" \
  [expr {[string is double -strict $ink] && $ink > 0.001}] "(mean grey=$ink)"

# a second REAL window, placed exactly on top, showing something else
set before [winfo children .]
xschem load_new_window -window {}
pump 400
set top {}
foreach t [winfo children .] {
  if {[lsearch -exact $before $t] >= 0} continue
  if {[winfo exists $t.drw]} { set top $t }
}
check "E3 a second real window exists" [expr {$top ne {}}] "(=> $top)"
if {$top eq {}} { puts "RESULT: $::fail FAILED" ; flush stdout ; exit 1 }
wm geometry $top 700x500+60+60
xschem load $fB
xschem zoom_full
pump 900
set C [file join $dir C.png]
check "E4 the covering window could be captured" [shot $top.drw $C]
set d_cover [pxdiff $P0 $C]
check "E5 ... and it looks DIFFERENT from the design canvas (so a stale copy is visible)" \
  [expr {$d_cover > 0.01}] "(differing fraction=$d_cover)"

# arm the guard exactly as a freshly-opened window does, then step the cover aside --
# this is wviewer::uncover's move, and the design window's Expose lands inside the window
# where pending_fullzoom is still set.
xschem set pending_fullzoom 1
check "E6 the new-window guard is armed" [expr {[xschem get pending_fullzoom] == 1}]
wm geometry $top 700x500+900+560
pump 1200
set P1 [file join $dir P1.png]
check "E7 the design canvas could be re-captured" [shot .drw $P1]
set d_after [pxdiff $P0 $P1]
check "E8 THE ROW: the uncovered design canvas REPAINTED, it did not keep the other\
 window's pixels" [expr {$d_after >= 0 && $d_after < 0.01}] "(differing fraction=$d_after)"
xschem set pending_fullzoom 0

puts [expr {$::fail == 0 ? "RESULT: ALL PASS (8 checks)" : "RESULT: $::fail FAILED"}]
flush stdout
exit [expr {$::fail != 0}]
