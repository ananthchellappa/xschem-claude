# Phase 3 slice A: the 14 silent (empty-command) Layer A ids get minted
# subcommands -- `xschem scroll|pan|snap|toggle_*` -- whose bodies are the SAME
# C functions the bound chords run (view_pan_dir/view_scroll_dir/
# view_snap_change/toggle_*_cmd, callback.c), and the csv command column now
# carries them, so the dispatch logs a replayable line. Checks:
#   1. each subcommand's behavior (origin/var deltas, exact inverses)
#   2. a bound chord fires -> the canonical command lands in the log
#   3. the logged line replays through the same code (re-source = same delta)
# Run under X with --pipe and --logdir:
#   DISPLAY=:0 ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_phase3_mints.tcl
update idletasks
focus -force .drw
update idletasks

proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"
  flush stdout
  if {!$ok} {incr ::fails}
}
set ::fails 0

proc loglines {} {
  set fd [open [xschem get actionlog_filename] r]
  set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
proc origin {} { list [xschem get xorigin] [xschem get yorigin] }
# float compare: the scroll/pan arithmetic leaves last-ULP residue
proc near {a b} { expr {abs($a - $b) < 1e-9 * (abs($a) + abs($b) + 1)} }
proc origin_near {o} {
  lassign $o ex ey
  expr {[near [xschem get xorigin] $ex] && [near [xschem get yorigin] $ey]}
}

# the two netlist/pixmap toggles pop an alert_ dialog (real GUI behavior kept
# verbatim); stub it so the smoke and the replay don't block
proc alert_ {txt {pos {}} {nowait 0} {yesno 0}} {}

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]
xschem load xschem_library/examples/nand2.sch

# --- 1. subcommand behavior: exact inverses restore the origin --------------
set o0 [origin]
xschem scroll up; xschem scroll down; xschem scroll left; xschem scroll right
check "scroll up/down/left/right cancel out" [origin_near $o0]
xschem scroll up
check "scroll up moves the origin" [expr {![origin_near $o0]}]
xschem scroll down

xschem pan up; xschem pan down; xschem pan left; xschem pan right
check "pan dirs cancel out" [origin_near $o0]

# numeric form: shift by (dx, dy) schematic units
lassign $o0 x0 y0
xschem pan 50 -30
check "pan dx dy shifts origin exactly" \
  [origin_near [list [expr {$x0+50}] [expr {$y0-30}]]]
xschem pan -50 30
check "pan -dx -dy restores origin" [origin_near $o0]

check "scroll rejects a bad direction" [catch {xschem scroll sideways}]
check "pan rejects a bad direction" [catch {xschem pan sideways}]

set s0 $cadsnap
xschem snap half
check "snap half halves cadsnap" [expr {$cadsnap == $s0 / 2.0}]
xschem snap double
check "snap double restores cadsnap" [expr {$cadsnap == $s0}]
check "snap rejects a bad arg" [catch {xschem snap quarter}]

set v0 $enable_stretch
xschem toggle_stretch
check "toggle_stretch flips enable_stretch" [expr {$enable_stretch != $v0}]
xschem toggle_stretch

set v0 $netlist_show
xschem toggle_show_netlist
check "toggle_show_netlist flips netlist_show" [expr {$netlist_show != $v0}]
xschem toggle_show_netlist

set v0 $orthogonal_wiring
xschem toggle_orthogonal_wiring
check "toggle_orthogonal_wiring flips the var" [expr {$orthogonal_wiring != $v0}]
xschem toggle_orthogonal_wiring

xschem toggle_draw_pixmap; xschem toggle_draw_pixmap   ;# flip + restore, no error
check "toggle_draw_pixmap runs" 1

# --- 2. Layer A: bound chords now log the canonical command -----------------
# chord -> expected line (from the C binding table: arrows, Shift/Ctrl wheel,
# g/G/y/A/L/$). Fire through `xschem callback`, the real dispatch path.
proc fire_key {keysym state} { xschem callback .drw 2 200 200 $keysym 0 0 $state; update idletasks }
proc fire_wheel {button state} { xschem callback .drw 4 200 200 0 $button 0 $state; update idletasks }

foreach {desc cmd fire} {
  "Up arrow"    {xschem scroll up}              {fire_key 65362 0}
  "Shift+wheel" {xschem pan left}               {fire_wheel 4 1}
  "key g"       {xschem snap half}              {fire_key 103 0}
  "key G"       {xschem snap double}            {fire_key 71 0}
  "key y"       {xschem toggle_stretch}         {fire_key 121 0}
  "key A"       {xschem toggle_show_netlist}    {fire_key 65 0}
  "key L"       {xschem toggle_orthogonal_wiring} {fire_key 76 0}
  "key \$"      {xschem toggle_draw_pixmap}     {fire_key 36 0}
} {
  set n0 [llength [loglines]]
  eval $fire
  check "$desc logs '$cmd'" [expr {[lsearch -exact [loglines] $cmd] >= $n0}]
}
# undo the toggles the chords flipped (pairs: snap half+double cancel already)
xschem toggle_stretch; xschem toggle_show_netlist
xschem toggle_orthogonal_wiring; xschem toggle_draw_pixmap
xschem scroll down; xschem pan right

# --- 3. replay: a logged line re-applies the same relative step -------------
set n0 [llength [loglines]]
fire_key 65362 0                       ;# Up arrow
set line [lindex [loglines] $n0]
set o1 [origin]
eval $line                             ;# replay the logged command
lassign $o1 x1 y1
lassign [origin] x2 y2
set dy1 [expr {[lindex $o1 1] - [lindex $o0 1]}]
check "replayed scroll line applies the same delta" \
  [expr {[near $x2 $x1] && [near [expr {$y2 - $y1}] $dy1]}]

check "log file is source-able" \
  [expr {![catch {uplevel #0 [list source [xschem get actionlog_filename]]} err]}]

catch {destroy .ciw}; update
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
