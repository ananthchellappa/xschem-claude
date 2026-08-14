# Effective-coordinate log cleanup (pivots + pan): drives the INTERACTIVE mouse
# paths -- rotate/flip pivots read mousex_snap (snap_to_grid + %.10g) and drag-pan
# logs a %.10g view delta -- which the argv-path perform_action unit tests do NOT
# cover, and asserts the logged coords carry no >10-sig-fig float noise and replay.
# Needs the action log open; run via full_audit.sh (a logdir_test) or:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_coordlog_precision.tcl   # from repo root
set PASS 1
proc check {name ok {info {}}} {
  global PASS
  if {$ok} { puts "ok:   $name" } else { puts "FAIL: $name $info" ; set PASS 0 }
}
proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]; set d [read $fd]; close $fd
  return [split [string trim $d] "\n"]
}
proc newlines {n0} { lrange [loglines] $n0 end }
# a coord token is "noisy" if it has a '.' and > 10 significant digits
proc noisy {tok} { expr {[string match {*.*} $tok] && [regexp -all {[0-9]} $tok] > 11} }

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]
xschem load xschem_library/examples/nand2.sch
update idletasks

# --- pivot mouse path: select an instance, then `xschem rotate` (no args) reads
#     mousex_snap (the effective/snapped cursor). Position cursor via motion. ---
xschem unselect_all
xschem select instance 0
set n0 [llength [loglines]]
xschem callback .drw 6 250 200 0 0 0 0     ;# motion -> sets mousex_snap/mousey_snap
xschem rotate                              ;# no coords -> mouse-fallback pivot path
update idletasks
set rl {}
foreach l [newlines $n0] { if {[string match {xschem rotate *} $l]} { set rl $l } }
check "mouse-path rotate logged a pivot line" [expr {$rl ne {}}] "(new=[newlines $n0])"
if {$rl ne {}} {
  lassign $rl _ _ px py
  check "rotate pivot X has no float noise" [expr {![noisy $px]}] "(x=$px)"
  check "rotate pivot Y has no float noise" [expr {![noisy $py]}] "(y=$py)"
  check "rotate pivot has no -0" [expr {$px ne {-0} && $py ne {-0}}] "($px $py)"
  # replay fidelity: sourcing the logged line must not error
  check "logged rotate line replays" [expr {![catch {eval $rl}]}] "($rl)"
}

# --- pan drag path: middle-button (Button2) press -> motion -> release logs
#     `xschem pan dx dy`. dx/dy = raw origin delta (mouse-pixel*zoom). ---
set n0 [llength [loglines]]
xschem callback .drw 4 120 90 0 2 0 0       ;# Button2 press -> start pan
xschem callback .drw 6 337 261 0 0 0 512    ;# motion (Button2Mask) -> pan(RUBBER)
xschem callback .drw 5 337 261 0 2 0 512    ;# release -> log_pan_end
update idletasks
set pl {}
foreach l [newlines $n0] { if {[string match {xschem pan *} $l]} { set pl $l } }
check "drag-pan logged a pan line" [expr {$pl ne {}}] "(new=[newlines $n0])"
if {$pl ne {}} {
  lassign $pl _ _ dx dy
  check "pan dx has no float noise (%.10g)" [expr {![noisy $dx]}] "(dx=$dx)"
  check "pan dy has no float noise (%.10g)" [expr {![noisy $dy]}] "(dy=$dy)"
  check "logged pan line replays" [expr {![catch {eval $pl}]}] "($pl)"
}

puts [expr {$PASS ? "RESULT: ALL PASS" : "RESULT: FAILED"}]
