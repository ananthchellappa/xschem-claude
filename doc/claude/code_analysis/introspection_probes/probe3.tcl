# Empirical probe: §2e of tcl_introspection_wire.md revisited with stable
# wire handles (feature/stable-object-handles, Phase D). Re-runs the original
# dangling-index failure verbatim, side-by-side with the handle version that
# does not fail. Output: /tmp/wire_probe3.log — every line is "TAG | result".
#
#   cd src && ./xschem -q --script ../doc/claude/code_analysis/introspection_probes/probe3.tcl

set ::logfd [open /tmp/wire_probe3.log w]
proc p {tag script} {
  if {[catch {uplevel #0 $script} res]} {
    puts $::logfd "$tag | ERROR: $res"
  } else {
    puts $::logfd "$tag | $res"
  }
  flush $::logfd
}

# stub modals
rename tk_messageBox _real_tk_messageBox
proc tk_messageBox {args} {return ok}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

set SCH /home/qflow/dev/xschem/claude_1/xschem/xschem_library/examples/mos_power_ampli.sch
xschem set modified 0
xschem load $SCH

### 1. the original §2e failure, reproduced verbatim: a raw index held
###    across a delete silently names a different wire
p {old: coords of wire 6 before deleting wire 5} {xschem wire_coord 6}
p {old: delete wire 5 (wires 91 -> 90)} {
  xschem unselect_all
  xschem select wire 5
  xschem delete
  xschem get wires
}
p {old: coords of "wire 6" after delete — A STRANGER} {xschem wire_coord 6}
p {old: undo to restore} {xschem undo; xschem get wires}

### 2. the same scenario by handle: hold the id, not the index
p {new: id of wire 6} {set ::id6 [xschem wire_id 6]}
p {new: coords of wire 6 (what the handle must keep naming)} {
  set ::c6 [xschem wire_coord 6]
}
p {new: delete wire 5 again} {
  xschem unselect_all
  xschem select wire 5
  xschem delete
  xschem get wires
}
p {new: wire_index of held id — index moved} {set ::i6 [xschem wire_index $::id6]}
p {new: coords at resolved index — SAME WIRE} {xschem wire_coord $::i6}
p {new: coords unchanged?} {
  expr {[xschem wire_coord $::i6] eq $::c6 ? "YES — handle survived the delete" : "NO"}
}
p {new: undo to restore} {xschem undo; xschem get wires}

### 3. deleting the held wire itself: the handle dangles LOUDLY (-1),
###    it does not silently name a stranger
p {dangle: re-fetch id of wire 6} {set ::id6 [xschem wire_id 6]}
p {dangle: delete wire 6 itself} {
  xschem unselect_all
  xschem select wire 6
  xschem delete
  xschem get wires
}
p {dangle: wire_index of held id} {xschem wire_index $::id6}
p {dangle: undo to restore} {xschem undo; xschem get wires}

### 4. the D3 contract: a disk-undo restore invalidates every handle
###    (restored wires are fresh births; old ids can never alias them
###    because the id counter is monotonic per context)
p {disk-undo: undo_type} {xschem undo_type disk}
p {disk-undo: id of wire 6 before the cycle} {set ::id6 [xschem wire_id 6]}
p {disk-undo: edit + undo (forces a restore from .sch temp file)} {
  xschem unselect_all
  xschem wire 6000 -6000 6100 -6000
  xschem undo
  xschem get wires
}
p {disk-undo: held id after restore — invalidated} {xschem wire_index $::id6}
p {disk-undo: wire 6 has a fresh id} {
  list old $::id6 new [xschem wire_id 6]
}

### 5. memory undo, by contrast, round-trips identity (H5)
p {mem-undo: undo_type} {xschem undo_type memory}
p {mem-undo: id of wire 6} {set ::id6 [xschem wire_id 6]}
p {mem-undo: edit + undo + redo + undo cycle} {
  xschem unselect_all
  xschem wire 6000 -6000 6100 -6000
  xschem undo
  xschem get wires
}
p {mem-undo: held id still resolves} {set ::i6 [xschem wire_index $::id6]}
p {mem-undo: same coords} {xschem wire_coord $::i6}

xschem set modified 0
close $::logfd
exit
