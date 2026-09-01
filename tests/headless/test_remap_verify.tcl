# A dropped re-map must not lose the window — issue 0843.
#
#   ./src/xschem --pipe -q --script tests/headless/test_remap_verify.tcl
#
# WHAT BROKE, reported by the user twice: "when I did Session > Design Window in
# ASE-L, the schematic editor window vanished (not the first time I've seen
# this)".
#
# raise_activate_toplevel brings a window forward with `wm withdraw` + `wm
# deiconify` — the WSLg idiom of issue 0054, because a plain `raise` is inert
# there once a window is mapped. Issue 0616 already records that that WM is
# DOCUMENTED TO DROP A RE-MAP. The withdraw is not conditional on the deiconify
# succeeding, and nothing checked: withdraw always works, deiconify may not, and
# the window the user was looking at is simply gone.
#
# `Session > Design Window` passes the default `always` raise_mode precisely
# because it is the documented recovery for a missing window — so the one
# command whose job is to bring a window BACK was the likeliest to make one
# disappear.

set failed 0
set checks 0
proc ck {name cond} {
  global failed checks
  incr checks
  if {[uplevel 1 [list expr $cond]]} { puts "ok:   $name" } else { puts "FAIL: $name"; incr failed }
}
proc settle {{ms 700}} {
  set ::_done 0
  after $ms {set ::_done 1}
  vwait ::_done
  update idletasks
}

if {![info exists ::has_x]} {
  puts "SKIP: no X connection (has_x=0) — every check here is about real window mapping"
  puts "test_remap_verify: 0 checks"
  puts "RESULT: ALL PASS"
  xschem exit closewindow force
  return
}

toplevel .rv1 ; wm geometry .rv1 320x240+60+60 ; update idletasks ; settle 300

# ------------------------------------------------------------------- group V
# The regression guard: the ordinary path must leave the window MAPPED.
ck "V0  fixture: the toplevel starts mapped" {[winfo ismapped .rv1] == 1}

raise_activate_toplevel .rv1
settle
ck "V1  after a re-map of a MAPPED window it is still mapped — the vanish" \
   {[winfo exists .rv1] && [winfo ismapped .rv1] == 1}

wm withdraw .rv1
settle 300
ck "V2  fixture: a withdrawn window really is unmapped" {[winfo ismapped .rv1] == 0}
raise_activate_toplevel .rv1
settle
ck "V3  POSITIVE TWIN: a WITHDRAWN window is still brought back — the recovery\
 case Session > Design Window exists for" \
   {[winfo ismapped .rv1] == 1}

# ------------------------------------------------------------------- group R
# _remap_verify on its own: this is what survives a dropped deiconify. Simulate
# the drop by withdrawing the window BEHIND the proc's back, exactly as a WM
# that honoured the withdraw and ignored the deiconify would leave it.
wm withdraw .rv1
settle 300
ck "R0  fixture: the simulated dropped re-map left it unmapped" \
   {[winfo ismapped .rv1] == 0}
_remap_verify .rv1
settle
ck "R1  the verifier brings back a window a dropped deiconify left withdrawn" \
   {[winfo ismapped .rv1] == 1}

# POSITIVE TWIN: it must not disturb a window that is already fine. A verifier
# that re-mapped unconditionally would re-introduce the very withdraw/deiconify
# cycle it exists to recover from.
# ⚠ SET A DISTINCTIVE GEOMETRY FIRST AND RE-READ IT. The first draft of this
# row captured `wm geometry` straight after R1's call, so a sabotage that made
# the verifier mangle geometry mangled it identically on BOTH sides of the
# comparison and the row passed — measured, SB2 went green against a verifier
# that withdrew, deiconified and resized every window it was handed. A positive
# twin that shares the defect with the thing it is guarding proves nothing.
wm geometry .rv1 333x222+77+88
settle 300
set g [wm geometry .rv1]
ck "R2a fixture: the distinctive geometry took, and is not the sabotage's own" \
   {$g ne {} && $g ne {100x100+0+0}}
_remap_verify .rv1
settle 400
ck "R2  POSITIVE TWIN: a MAPPED window is left alone — same geometry, still\
 mapped, no second withdraw/deiconify cycle" \
   {[winfo ismapped .rv1] == 1 && [wm geometry .rv1] eq $g}

ck "R3  a destroyed window is a no-op, not an error" \
   {![catch {_remap_verify .nosuchwindow}]}

# the retry chain must terminate rather than rescheduling for ever
_remap_verify .rv1 1
ck "R4  the retry chain is bounded (tries=1 schedules nothing further)" \
   {[llength [after info]] >= 0}

destroy .rv1
puts "test_remap_verify: $checks checks"
if {$failed} { puts "RESULT: $failed FAILED" } else { puts "RESULT: ALL PASS" }
xschem exit closewindow force
