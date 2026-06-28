# 0054-raise-drift-probe.tcl  --  RUN ON THE REAL WSLg DESKTOP:   wish 0054-raise-drift-probe.tcl
#
# Goal: find which "bring an already-open window to the front" strategy BOTH
#   (a) actually RAISES a window that is behind another window (you watch this), and
#   (b) does NOT make the window CREEP / drift in position (we measure winfo rootx/rooty).
#
# The headless dev display cannot reproduce the drift (it pins windows off-screen at
# rootx=-32730 with zero movement for every strategy), so this must be run on the visible
# desktop. Click each strategy button in turn, WATCH whether the red TARGET window rises
# above the blue COVER window, then copy ALL the text from the log box back.
#
# What "drift" looks like in the log: rootx/rooty changing from cyc1..cyc5 for a strategy.
# A good strategy: TARGET visibly rises above COVER every cycle AND rootx/rooty stay constant.

package require Tk

wm title . "0054 raise/drift probe -- controls"
wm geometry . +40+40

toplevel .cover
wm title .cover "COVER (blue) -- should hide TARGET until a strategy raises it"
.cover configure -bg blue
wm geometry .cover 380x280+520+360

toplevel .target
wm title .target "TARGET (red)"
.target configure -bg red
label .target.l -text "TARGET" -bg red -fg white -font {Helvetica 28 bold}
pack .target.l -expand 1 -fill both
# overlaps COVER, offset a little so the two are distinguishable when both visible
wm geometry .target 380x280+545+385
update

proc report {tag} {
  return "$tag rootx=[winfo rootx .target] rooty=[winfo rooty .target] wmgeo=[wm geometry .target]"
}
proc log {msg} { .out insert end "$msg\n" ; .out see end ; update }

# Put TARGET behind COVER so a successful raise is visible.
proc lower_target {} {
  lower .target .cover
  raise .cover
  update ; after 350
}

# ---- strategies ------------------------------------------------------------
proc s_plain_raise {} { raise .target }            ;# baseline: expected NOT to raise on WSLg

proc s_remap {} {                                  ;# the old re-map: raises, but creeps NW
  set geo [wm geometry .target]
  wm withdraw .target
  catch { wm geometry .target $geo }
  wm deiconify .target
  raise .target
}

proc s_remap_doublecorrect {} {                    ;# re-map, MEASURE shift, re-map pre-compensated
  # This MIRRORS the real raise_activate_toplevel helper (src/xschem.tcl). It should RAISE and
  # show dx=0 dy=0: the first re-map raises but the WM shifts it; we measure that shift and
  # re-map once more with the requested frame pushed by the measured amount, landing it back.
  set rx [winfo rootx .target]; set ry [winfo rooty .target]
  set fg [wm geometry .target]
  wm withdraw .target
  catch { wm geometry .target $fg }
  wm deiconify .target
  raise .target
  update; after 200
  set dx [expr {$rx - [winfo rootx .target]}]
  set dy [expr {$ry - [winfo rooty .target]}]
  if {($dx != 0 || $dy != 0) &&
      [regexp {^(\d+)x(\d+)([+-]\d+)([+-]\d+)$} [wm geometry .target] -> gw gh gx gy]} {
    wm withdraw .target
    catch { wm geometry .target ${gw}x${gh}+[expr {$gx + $dx}]+[expr {$gy + $dy}] }
    wm deiconify .target
    raise .target
  }
}

set ::fixed_home ""
proc s_remap_fixedhome {} {                        ;# re-map to a SINGLE remembered position
  # The key test: never re-read the (drifting) current position -- capture the desired spot
  # ONCE and re-map to that SAME value every raise. If the WM places a fixed request
  # consistently, the window lands at one spot each time: a one-time offset but NO accumulating
  # creep (it stops walking off-screen). Per-cycle drift after cyc1 should be 0.
  global fixed_home
  if {$fixed_home eq ""} { set fixed_home [wm geometry .target] }
  wm withdraw .target
  catch { wm geometry .target $fixed_home }
  wm deiconify .target
  raise .target
}

proc s_remap_fixedcomp {} {                        ;# re-map with a fixed +32,+32 pre-compensation
  # Simpler one-flash variant: ASSUMES the WM's shift is exactly -32,-32 (as measured) and
  # requests the frame 32px further SE so the shift lands it back. Should also show dx=0 dy=0 if
  # the shift is reliably 32; breaks if the shift magnitude differs (theme/DPI). For comparison.
  if {[regexp {^(\d+)x(\d+)([+-]\d+)([+-]\d+)$} [wm geometry .target] -> w h x y]} {
    wm withdraw .target
    catch { wm geometry .target ${w}x${h}+[expr {$x + 32}]+[expr {$y + 32}] }
    wm deiconify .target
    raise .target
  }
}

proc run_strategy {name proc} {
  log "==================== $name ===================="
  set sx [winfo rootx .target] ; set sy [winfo rooty .target]
  log [report "  start "]
  for {set i 1} {$i <= 5} {incr i} {
    lower_target
    $proc
    update ; after 500
    log [report "  cyc$i  "]
  }
  set ex [winfo rootx .target] ; set ey [winfo rooty .target]
  log "  TOTAL DRIFT over 5 cycles:  dx=[expr {$ex-$sx}]  dy=[expr {$ey-$sy}]"
  log "  -> did the red TARGET rise above the blue COVER each cycle?  (note YES/NO)\n"
}

# ---- controls --------------------------------------------------------------
frame .b ; pack .b -fill x -padx 4 -pady 4
frame .b.r1 ; frame .b.r2 ; pack .b.r1 .b.r2 -anchor w
button .b.r1.1 -text "1. plain raise"             -command {run_strategy "plain raise"           s_plain_raise}
button .b.r1.2 -text "2. re-map (baseline drift)" -command {run_strategy "re-map"                s_remap}
button .b.r1.3 -text "3. re-map + double-correct" -command {run_strategy "re-map + double-correct" s_remap_doublecorrect}
button .b.r2.4 -text "4. re-map + fixed +32"      -command {run_strategy "re-map + fixed +32"    s_remap_fixedcomp}
button .b.r2.5 -text "5. re-map FIXED home <-- run this one" -command {set ::fixed_home ""; run_strategy "re-map FIXED home" s_remap_fixedhome}
pack .b.r1.1 .b.r1.2 .b.r1.3 -side left -padx 2 -pady 2
pack .b.r2.4 .b.r2.5 -side left -padx 2 -pady 2
text .out -width 78 -height 24 -wrap none
pack .out -fill both -expand 1 -padx 4 -pady 4
log "Click buttons 1..4 in order. WATCH the red TARGET vs the blue COVER, and read the"
log "TOTAL DRIFT line each strategy prints. Then copy everything below back.\n"
log "Best strategy = TARGET rises above COVER every cycle AND dx=0 dy=0.\n"
