#
#  File: pin_gestures.tcl
#
#  GUI-injection regression for pin-selection v2 (doc/claude/specs/pin_selection.md §3.2):
#    D6  SHIFT+click on a pin ADDS it (multi-pin); plain click REPLACES; SHIFT+drag on a
#        pin is IGNORED; SHIFT+drag on an instance BODY still COPIES (cadence guard).
#    D7  in edit.deselect_mode, a click on a selected pin deselects JUST that pin.
#
#  Needs a real window: `xschem callback` SEGFAULTs under --nogui, so the gesture checks
#  run only when .drw exists. Run from the repo ROOT under DISPLAY:
#     DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/pin_gestures.tcl
#
#  Mirrors the user's interaction config (cadence): intuitive + cadence_compat + the
#  en_pin_select global (read via tclgetboolvar by the C press hook).

set DESEL_MODE 4194304
set intuitive_interface 1
set cadence_compat 1
set en_pin_select 1

set nf 0
proc ck {n ok d} { global nf; if {$ok} {puts "ok:   $n $d"} else {puts "FAIL: $n $d"; incr nf} }

set gui [expr {![catch {winfo exists .drw} r] && $r}]
if {!$gui} { puts "SKIP: pin_gestures needs DISPLAY/.drw"; exit 0 }

# world -> screen (X_TO_SCREEN, no tk_scaling): screen = (world + origin) / zoom
proc w2s {wx wy} {
  set z [xschem get zoom]
  list [expr {round(($wx + [xschem get xorigin]) / $z)}] \
       [expr {round(($wy + [xschem get yorigin]) / $z)}]
}
# pin world coord by pin name (res.sym: pin 0 = P, pin 1 = M)
proc pin_w {inst name} {
  set r [xschem instance_pin_coord $inst name $name]   ;# -> {name} x y
  list [lindex $r 1] [lindex $r 2]
}
# event injectors. ButtonPress=4 Release=5 Motion=6 KeyPress=2; button1; ShiftMask=1,
# Button1Mask=256.
proc press   {mx my st} { xschem callback .drw 4 $mx $my 0 1 0 $st; update idletasks }
proc release {mx my st} { xschem callback .drw 5 $mx $my 0 1 0 $st; update idletasks }
proc motion  {mx my st} { xschem callback .drw 6 $mx $my 0 0 0 $st; update idletasks }
proc esc     {}          { xschem callback .drw 2 100 100 65307 0 0 0; update idletasks }

# a click (press+release, no motion) at a WORLD point, with modifier mask $mod
proc clickw {wx wy mod} {
  lassign [w2s $wx $wy] mx my
  press $mx $my $mod
  release $mx $my [expr {$mod | 256}]
}
# count selected pins in the selection query
proc npins {} {
  set n 0
  foreach row [xschem selection] { if {[lindex $row 0] eq "pin"} { incr n } }
  return $n
}
proc has_pin {pidx} {
  foreach row [xschem selection] { if {[lindex $row 0] eq "pin" && [lindex $row 2] == $pidx} { return 1 } }
  return 0
}

xschem clear force
xschem instance devices/res.sym 0 0 0 0 {name=R1}
xschem unselect_all
xschem zoom_full
update idletasks
lassign [pin_w R1 P] px py   ;# pin index 0
lassign [pin_w R1 M] mx_ my_ ;# pin index 1

# --- plain click selects ONE pin (replace) -----------------------------------------
clickw $px $py 0
ck "plain click selects pin P" [expr {[xschem get lastsel]==1 && [has_pin 0]}] "(lastsel [xschem get lastsel])"
# plain click on M REPLACES (still one pin, now M)
clickw $mx_ $my_ 0
ck "plain click on M replaces (still 1 pin, M)" \
  [expr {[xschem get lastsel]==1 && [has_pin 1] && ![has_pin 0]}] "(lastsel [xschem get lastsel])"

# --- D6 : SHIFT+click ADDS the other pin (multi-select) -----------------------------
clickw $px $py 1   ;# ShiftMask=1
ck "D6 SHIFT+click on P adds it (2 pins)" \
  [expr {[xschem get lastsel]==2 && [has_pin 0] && [has_pin 1]}] "(lastsel [xschem get lastsel])"

# --- D7 : deselect mode click on a selected pin clears JUST that pin ----------------
xschem deselect_mode
ck "deselect mode entered" [expr {([xschem get ui_state] & $DESEL_MODE)!=0}] "(ui_state [xschem get ui_state])"
clickw $px $py 0   ;# click pin P in deselect mode
ck "D7 deselect-mode click clears pin P only (M remains)" \
  [expr {[xschem get lastsel]==1 && [has_pin 1] && ![has_pin 0]}] "(lastsel [xschem get lastsel])"
esc
ck "ESC exits deselect mode, keeps M" \
  [expr {([xschem get ui_state] & $DESEL_MODE)==0 && [xschem get lastsel]==1 && [has_pin 1]}] \
  "(ui_state [xschem get ui_state] lastsel [xschem get lastsel])"

# --- D6 : SHIFT+drag starting on a pin is IGNORED (no copy, no add) -----------------
# state: M is selected (1 pin). SHIFT+press on P, drag, release -> nothing.
set ninst0 [xschem get instances]
lassign [w2s $px $py] sx sy
press $sx $sy 1
motion [expr {$sx+120}] [expr {$sy+120}] 257
release [expr {$sx+120}] [expr {$sy+120}] 257
ck "D6 SHIFT+drag on a pin copies nothing" [expr {[xschem get instances]==$ninst0}] \
  "(instances [xschem get instances])"
ck "D6 SHIFT+drag on a pin adds no pin (drag != click)" \
  [expr {[xschem get lastsel]==1 && [has_pin 1]}] "(lastsel [xschem get lastsel])"

# --- cadence guard : a SHIFT press on the instance BODY still reaches the copy path ---
# (committing a copy via synthetic events is unreliable; the regression we must catch is
#  that the D6 interception does NOT swallow a body SHIFT-press -- so assert the cadence
#  copy gesture STARTS, ui_state STARTCOPY=64, then abort it.)
xschem unselect_all
regexp {Instance: ([-0-9.eE]+) ([-0-9.eE]+) ([-0-9.eE]+) ([-0-9.eE]+)} \
  [xschem instance_bbox R1] -> bx1 by1 bx2 by2
set cx [expr {($bx1+$bx2)/2.0}] ; set cy [expr {($by1+$by2)/2.0}]
lassign [w2s $cx $cy] bsx bsy
press $bsx $bsy 1   ;# SHIFT+press on the body (away from any pin)
ck "SHIFT+press on instance body starts cadence copy (not swallowed by pin path)" \
  [expr {([xschem get ui_state] & 64)!=0}] "(ui_state [xschem get ui_state])"
esc   ;# abort the copy gesture

if {$nf} { puts "RESULT: $nf FAILED" } else { puts "RESULT: ALL PASS" }
exit $nf
