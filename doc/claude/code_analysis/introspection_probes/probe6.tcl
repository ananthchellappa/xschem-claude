# Empirical probe: the uniform `xschem object` / `xschem objects` read API
# (stable-object-handles step-3 direction (b)). Demonstrates the one-verb,
# uniform-descriptor surface over the per-type stable ids built in steps 1-3:
# enumerate every object as a self-describing dict, filter, and resolve a held
# handle back to its descriptor. Output: /tmp/object_probe6.log.
#
#   cd src && ./xschem -q --script ../doc/claude/code_analysis/introspection_probes/probe6.tcl

set ::logfd [open /tmp/object_probe6.log w]
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

# a small mixed schematic: wires, an instance, a text, and graphical shapes
xschem set modified 0
xschem clear force schematic
xschem wire 0 0 100 0
xschem instance res.sym 300 300 0 0 {name=RPROBE}
xschem text 500 500 0 0 hello {} 0.3 0
xschem set rectcolor 5
xschem rect 0 0 100 100
xschem rect 200 0 300 100
xschem line 0 200 100 200
xschem set rectcolor 6
xschem arc 0 600 30 0 180 6

### 1. enumerate EVERYTHING as uniform descriptors (one dict per object)
p {all objects, one self-describing dict each} {
  set out {}
  foreach o [xschem objects] {
    lappend out "[dict get $o type]#[dict get $o index]@L[dict get $o layer]=id[dict get $o id]"
  }
  join $out " | "
}

### 2. the same data, the OLD way: a per-type command zoo (for contrast)
p {old way needs a different command per type, no uniform row} {
  list wires [xschem get wires] rects_L5 [xschem get rects 5] \
       arcs_via {no `get arcs` exists} instance [xschem instance_coord RPROBE]
}

### 3. filter by type
p {objects -type rect (only rects, across layers)} {
  lmap o [xschem objects -type rect] {list L[dict get $o layer] #[dict get $o index] id[dict get $o id]}
}

### 4. filter by selection — "what is selected, uniformly?"
p {select an instance + a rect, then objects -selected} {
  xschem unselect_all
  xschem select instance RPROBE
  xschem select rect 5 1
  lmap o [xschem objects -selected] {list [dict get $o type] id[dict get $o id] name=[dict get $o name]}
}

### 5. filter by layer
p {objects -layer 5 (everything on layer 5)} {
  lmap o [xschem objects -layer 5] {list [dict get $o type] #[dict get $o index]}
}

### 6. resolve a HELD handle back to a live descriptor — the round trip that the
###    whole handles effort exists to make safe. Hold the instance's id, delete
###    an earlier object, and resolve: the descriptor still names the instance.
p {hold the instance id} {
  xschem unselect_all
  set ::h [dict get [xschem object instance RPROBE] id]
}
p {delete a wire (shifts nothing for the instance, but proves resolution)} {
  xschem unselect_all
  xschem select wire 0
  xschem delete
  dict get [xschem object instance @$::h] name
}

### 7. the three reference forms resolve the same object three ways
xschem set modified 0
xschem clear force schematic
xschem instance res.sym 300 300 0 0 {name=R1}
p {by name} {xschem object instance R1}
p {by index} {xschem object instance #0}
p {by id}    {xschem object instance @[dict get [xschem object instance R1] id]}

### 8. a dangling reference resolves to empty (loud, not a stranger)
p {hold a rect id, delete the rect, resolve} {
  xschem set rectcolor 5
  xschem rect 0 0 100 100
  set rid [xschem rect_id 5 0]
  xschem unselect_all; xschem select rect 5 0; xschem delete
  set d [xschem object rect @$rid]
  expr {$d eq "" ? "EMPTY — the handle dangled honestly" : "STRANGER: $d"}
}

xschem set modified 0
close $::logfd
exit
