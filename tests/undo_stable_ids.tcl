# Regression: session-stable object ids must SURVIVE an undo/redo in BOTH undo
# modes (issue 0043). Disk-based undo serializes via write/read_xschem_file, and
# the store funnels re-stamp FRESH ids on the read -- which used to silently break
# the net-hilight apply-scope overlay and every live `xschem object` handle
# captured before the undo (in-memory undo never had the bug: it struct-copies
# .id). The fix snapshots the ids into a per-slot side-channel at push_undo and
# re-stamps them at pop_undo. This test proves a captured handle still resolves --
# to the SAME object, with the SAME id value -- after a disk undo AND redo, and
# that disk now matches the in-memory path.
#
# Run headless from the source tree:
#   cd src && ./xschem -q --script ../tests/undo_stable_ids.tcl
# Results in /tmp/sh_undo_ids.log: PASS/FAIL per check, final line DONE.

set ::logfd [open /tmp/sh_undo_ids.log w]
set ::nfail 0
proc check {what cond} {
  if { [catch {uplevel 1 [list expr $cond]} res] } {
    puts $::logfd "FAIL: $what (eval error: $res)"; incr ::nfail
  } elseif { $res } {
    puts $::logfd "PASS: $what"
  } else {
    puts $::logfd "FAIL: $what"; incr ::nfail
  }
  flush $::logfd
}

# Build a scene covering the flat funnels (instance, wire, text) plus the
# per-layer gfx funnel (rect). Every add auto-pushes undo, so the final live
# state is the "S0" a subsequent edit's push will snapshot.
proc build_scene {} {
  xschem clear force schematic
  xschem instance res.sym   0 0 0 0 {name=R1 value=1k}
  xschem instance res.sym 100 0 0 0 {name=R2 value=1k}
  xschem wire 0 0 0 100
  xschem text 0 50 0 0 hello {} 0.4 0
  xschem rect 200 200 260 240
  xschem set modified 0
}

# the rect's stable id via the uniform object list (layer-independent)
proc first_rect_id {} {
  foreach o [xschem objects -type rect] { return [dict get $o id] }
  return -1
}

# One full capture -> mutate -> undo -> redo cycle under undo mode <mode>.
proc run_mode {mode} {
  xschem undo_type $mode
  build_scene

  # capture handles at S0
  set iid [xschem instance_id R1]
  set wid [xschem wire_id 0]
  set tid [xschem text_id 0]
  set rid [first_rect_id]
  check "$mode: preconditions (R1/wire/text/rect all have ids)" \
    {$iid > 0 && $wid > 0 && $tid > 0 && $rid > 0}

  # mutate -> S1: the add auto-pushes undo, snapshotting S0 (R1,R2,wire,text,rect)
  xschem instance res.sym 300 0 0 0 {name=R3 value=1k}
  set r3id [xschem instance_id R3]
  check "$mode: R3 created with an id" {$r3id > 0}

  # --- UNDO: back to S0. Every S0 handle must still resolve, to the SAME object. ---
  xschem undo
  check "$mode: after undo, R1 handle still resolves"   {[xschem instance_index $iid] >= 0}
  check "$mode: after undo, wire handle still resolves"  {[xschem wire_index $wid] >= 0}
  check "$mode: after undo, text handle still resolves"  {[xschem text_index $tid] >= 0}
  check "$mode: after undo, rect handle still resolves"  {[xschem rect_index $rid] ne "-1"}
  # id VALUE is preserved (re-stamped, not merely some-object): instance_id round-trips
  check "$mode: after undo, R1's id VALUE is unchanged"  {[xschem instance_id R1] == $iid}
  # and the handle points at R1 specifically, not R2
  check "$mode: after undo, the R1 handle names R1" \
    {[string match "*R1*" [xschem object instance @$iid]]}
  # the undone add is gone
  check "$mode: after undo, R3 is gone" {[xschem instance_id R3] == -1}
  # the stale R3 handle correctly does NOT resolve (no accidental aliasing)
  check "$mode: after undo, the stale R3 handle does not resolve" \
    {[xschem instance_index $r3id] == -1}

  # --- REDO: back to S1. S0 handles still valid AND R3 comes back with its id. ---
  xschem undo 1
  check "$mode: after redo, R1 handle still resolves"    {[xschem instance_index $iid] >= 0}
  check "$mode: after redo, R3 is back"                   {[xschem instance_id R3] > 0}
  check "$mode: after redo, R3's id VALUE is preserved"   {[xschem instance_id R3] == $r3id}
}

if {[catch {
  run_mode memory
  run_mode disk
} err]} {
  puts $::logfd "ERROR: $err"
  puts $::logfd $::errorInfo
}

puts $::logfd "DONE ($::nfail failures)"
flush $::logfd
close $::logfd
exit
