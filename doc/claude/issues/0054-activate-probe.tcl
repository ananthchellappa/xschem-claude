# 0054-activate-probe.tcl  --  RUN ON THE REAL WSLg DESKTOP:   wish 0054-activate-probe.tcl
#
# The re-map (withdraw/deiconify) is the only thing that RAISES on this Weston, but it ALWAYS
# drifts the window -32,-32 per map (measured, un-compensatable: the shift lands late and the
# frame offset changes between maps). So we stop trying to re-map and instead ask the WM to
# ACTIVATE the window in place via EWMH client messages -- which, if honored, raise with ZERO
# drift (the window never unmaps or moves).
#
# Your earlier _NET_ACTIVE_WINDOW test used CurrentTime + source 2 -- exactly what focus-
# stealing-prevention WMs REJECT. This probe tries every combination, plus _NET_WM_STATE_ABOVE,
# so we learn definitively whether ANY X-level activation raises here.
#
# Click each button with the red TARGET behind the blue COVER. For each: note whether TARGET
# rises above COVER, and read the rootx/rooty line (it MUST stay constant = no drift). Copy the
# log back. If a variant raises with dx=0 dy=0, that is the fix.

package require Tk

set here [file dirname [file normalize [info script]]]
set bin  [file join $here 0054-xactivate]
set src  [file join $here 0054-xactivate.c]

proc ensure_tool {} {
  global bin src
  if {[file executable $bin]} { return 1 }
  if {![file exists $src]} { return 0 }
  set rc [catch {exec gcc -O2 -o $bin $src -lX11} err]
  if {$rc} { return 0 }
  return [file executable $bin]
}

wm title . "0054 activate probe -- controls"
wm geometry . +40+40

toplevel .cover
wm title .cover "COVER (blue)"
.cover configure -bg blue
wm geometry .cover 380x280+520+360

toplevel .target
wm title .target "TARGET (red)"
.target configure -bg red
label .target.l -text "TARGET" -bg red -fg white -font {Helvetica 28 bold}
pack .target.l -expand 1 -fill both
wm geometry .target 380x280+545+385
update

proc log {m} { .out insert end "$m\n" ; .out see end ; update }
proc report {tag} { return "$tag rootx=[winfo rootx .target] rooty=[winfo rooty .target]" }

proc lower_target {} { lower .target .cover ; raise .cover ; update ; after 350 }

# run the compiled tool against the TARGET's X id with the given args
proc activate {args} {
  global bin
  set id [format 0x%x [winfo id .target]]
  set rc [catch {exec $bin $id {*}$args} out]
  return [expr {$rc ? "ERR: $out" : $out}]
}

proc try {name args} {
  log "==================== $name ===================="
  set bx [winfo rootx .target] ; set by [winfo rooty .target]
  lower_target
  log "  [activate {*}$args]"
  update ; after 700
  log [report "  after "]
  set ax [winfo rootx .target] ; set ay [winfo rooty .target]
  log "  drift dx=[expr {$ax-$bx}] dy=[expr {$ay-$by}]   <- MUST be 0,0"
  log "  -> did the red TARGET rise above the blue COVER?  (note YES/NO)\n"
}

frame .b1 ; pack .b1 -fill x -padx 4 -pady 2
frame .b2 ; pack .b2 -fill x -padx 4 -pady 2
button .b1.a -text "A. active src1 real-ts"  -command {try "active source=1 real-timestamp"  active 1 now}
button .b1.b -text "B. active src2 real-ts"  -command {try "active source=2 real-timestamp"  active 2 now}
button .b1.c -text "C. active src0 real-ts"  -command {try "active source=0 real-timestamp"  active 0 now}
pack .b1.a .b1.b .b1.c -side left -padx 2
button .b2.d -text "D. active src1 CurrentTime" -command {try "active source=1 CurrentTime" active 1 current}
button .b2.e -text "E. _NET_WM_STATE_ABOVE add" -command {try "wm_state_above add"          above}
button .b2.f -text "F. ABOVE add+remove"        -command {try "wm_state_above add+remove"   above-toggle}
pack .b2.d .b2.e .b2.f -side left -padx 2

text .out -width 80 -height 22 -wrap none
pack .out -fill both -expand 1 -padx 4 -pady 4

if {[ensure_tool]} {
  log "Tool ready: $bin"
  log "Click A..F with TARGET behind COVER. A winner = TARGET rises AND drift dx=0 dy=0.\n"
} else {
  log "ERROR: could not build 0054-xactivate from 0054-xactivate.c (need gcc + libX11)."
  log "Build it manually:  gcc -O2 -o $bin $src -lX11\n"
}
