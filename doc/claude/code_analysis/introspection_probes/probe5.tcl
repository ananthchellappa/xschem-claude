# Empirical probe: the §2e dangling-reference failure for the GRAPHICAL types
# (rect/line/poly/arc) with stable handles (feature/stable-object-handles,
# step-3 Phase D). Graphical objects live in PER-LAYER arrays, so a raw
# (layer,index) is the fragile address; the id is the durable handle. Re-runs
# the index-dangle failure side-by-side with the handle version, plus the
# graphical-specific behaviors: one shared id space across the four types, and
# the layer-change reconstruction (id does NOT survive — change_layer is
# delete+recreate). Siblings: probe3.tcl (wires), probe4.tcl (instances).
# Output: /tmp/gfx_probe5.log — every line is "TAG | result".
#
#   cd src && ./xschem -q --script ../doc/claude/code_analysis/introspection_probes/probe5.tcl

set ::logfd [open /tmp/gfx_probe5.log w]
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

# build a controlled fixture: 4 rects on layer 5
xschem set modified 0
xschem clear force schematic
xschem set rectcolor 5
xschem rect 0   0 100 100
xschem rect 200 0 300 100
xschem rect 400 0 500 100
xschem rect 600 0 700 100

### 1. the original §2e failure for graphical objects: a raw (layer,index) held
###    across a delete of an EARLIER rect on the same layer silently names a
###    different rect (the per-layer compaction shifts everything down)
p {old: rect at (5,3) before deleting (5,0) — its id, as a witness} {xschem rect_id 5 3}
p {old: delete rect (5,0) — later indices shift down} {
  xschem unselect_all
  xschem select rect 5 0
  xschem delete
  xschem get rects 5
}
p {old: "rect (5,3)" after the delete — OUT OF RANGE now (only 0..2 live)} {
  xschem rect_id 5 3
}

### 2. the same scenario by handle: hold the id, not the (layer,index)
xschem clear force schematic
xschem set rectcolor 5
xschem rect 0   0 100 100
xschem rect 200 0 300 100
xschem rect 400 0 500 100
xschem rect 600 0 700 100
p {new: id of the 4th rect (index 3)} {set ::id3 [xschem rect_id 5 3]}
p {new: delete rect (5,0) again} {
  xschem unselect_all
  xschem select rect 5 0
  xschem delete
  xschem get rects 5
}
p {new: rect_index of the held id — location moved to {5 2}} {set ::loc [xschem rect_index $::id3]}
p {new: round-trip — rect_id at the resolved location is the held id} {
  xschem rect_id [lindex $::loc 0] [lindex $::loc 1]
}
p {new: same rect?} {
  expr {[xschem rect_id [lindex $::loc 0] [lindex $::loc 1]] == $::id3 \
        ? "YES — handle survived the delete (index 3 -> {5 2})" : "NO"}
}

### 3. deleting the held rect itself: the handle dangles LOUDLY (-1)
p {dangle: id of rect now at (5,2)} {set ::idx [xschem rect_id 5 2]}
p {dangle: delete it} {
  xschem unselect_all
  xschem select rect 5 2
  xschem delete
  xschem get rects 5
}
p {dangle: rect_index of the held id} {xschem rect_index $::idx}

### 4. ONE shared id space across the four types: a rect, a line, a poly and an
###    arc created back-to-back get distinct ids, and each type's resolver
###    refuses the other types' ids
xschem clear force schematic
xschem set rectcolor 5
xschem rect 0 0 100 100
xschem line 0 200 100 200
xschem polygon 0 400 100 400 50 500
xschem set rectcolor 6
xschem arc 0 600 30 0 180 6
p {shared: rect/line/poly/arc ids (all distinct)} {
  list rect [xschem rect_id 5 0] line [xschem line_id 5 0] \
       poly [xschem poly_id 5 0] arc [xschem arc_id 6 0]
}
p {shared: rect_index refuses a line's id (type-scoped)} {
  xschem rect_index [xschem line_id 5 0]
}

### 5. the layer-change reconstruction: `set rectcolor` on a selection runs
###    change_layer() = DELETE+RECREATE, so the id does NOT survive — the old
###    id dangles and the rect on the new layer carries a fresh id
xschem clear force schematic
xschem set rectcolor 5
xschem rect 0 0 100 100
p {layerchg: id of the rect on layer 5} {set ::idl [xschem rect_id 5 0]}
p {layerchg: select it and set rectcolor 7 (-> change_layer move)} {
  xschem unselect_all
  xschem select rect 5 0
  xschem set rectcolor 7
  list rects_on_5 [xschem get rects 5] rects_on_7 [xschem get rects 7]
}
p {layerchg: the OLD id dangles (reconstructed, not moved)} {xschem rect_index $::idl}
p {layerchg: the rect on layer 7 has a FRESH id} {
  list old $::idl new [xschem rect_id 7 0]
}

### 6. disk undo invalidates the id (invalidate-on-restore), memory undo
###    round-trips it (graphical create is not undoable, so the cycle is
###    delete->undo)
xschem clear force schematic
xschem set rectcolor 5
xschem rect 0 0 100 100
p {disk-undo: undo_type + id} {xschem undo_type disk; set ::idd [xschem rect_id 5 0]}
p {disk-undo: delete + undo (restore re-reads the .sch)} {
  xschem unselect_all
  xschem select rect 5 0
  xschem delete
  xschem undo
  xschem get rects 5
}
p {disk-undo: held id invalidated, restored rect has a fresh id} {
  list old $::idd new [xschem rect_id 5 0] held_resolves [xschem rect_index $::idd]
}
xschem clear force schematic
xschem set rectcolor 5
xschem rect 0 0 100 100
p {mem-undo: undo_type + id} {xschem undo_type memory; set ::idm [xschem rect_id 5 0]}
p {mem-undo: delete + undo} {
  xschem unselect_all
  xschem select rect 5 0
  xschem delete
  xschem undo
  xschem get rects 5
}
p {mem-undo: the SAME id resolves again} {
  set loc [xschem rect_index $::idm]
  list location $loc same_id [expr {[xschem rect_id [lindex $loc 0] [lindex $loc 1]] == $::idm}]
}

xschem set modified 0
close $::logfd
exit
