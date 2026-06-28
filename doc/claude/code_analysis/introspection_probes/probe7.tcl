# Empirical probe: net-as-object, the c2 handle (stable-object-handles step-3
# direction (c)). Demonstrates that a net — which is DERIVED, with no struct and
# no id of its own — can be held across edits by anchoring on a stored-object
# handle (a wire_id / instance_id, stable from steps 1-2). Re-runs the §2c
# coherence scenario side-by-side with the handle version. Output:
# /tmp/net_probe7.log.
#
#   cd src && ./xschem -q --script ../doc/claude/code_analysis/introspection_probes/probe7.tcl

set ::logfd [open /tmp/net_probe7.log w]
proc p {tag script} {
  if {[catch {uplevel #0 $script} res]} {
    puts $::logfd "$tag | ERROR: $res"
  } else {
    puts $::logfd "$tag | $res"
  }
  flush $::logfd
}

# stub modals
catch {rename tk_messageBox _real_tk_messageBox}
proc tk_messageBox {args} {return ok}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

# a small schematic: a wire driven by a label naming net MYNET, plus a device
# (a resistor) with a pin on the same net, so the net has real members.
xschem set modified 0
xschem clear force schematic
xschem wire 0 0 200 0
xschem instance lab_pin.sym 0 0 0 0 {name=l1 lab=MYNET}
xschem instance res.sym 0 0 0 0 {name=R1}
xschem rebuild_connectivity

puts $::logfd "=== the net surface, addressed by a handle ==="

### 1. resolve the net three ways: by wire anchor, by instance pin, by name
p {net @wire <id>  (the net the wire is on)} {
  xschem net @wire [xschem wire_id 0]
}
p {net @inst <id> p  (the net at the label's pin)} {
  xschem net @inst [xschem instance_id l1] p
}
p {net MYNET  (by current name, the human form)} {
  xschem net MYNET
}

### 2. enumerate distinct nets, and just the selection's nets
p {nets  (one descriptor per distinct net)} { xschem nets }
xschem unselect_all; xschem select wire 0
p {nets -selected  (COLD — rebuilds sel_array, unlike resolved_net)} {
  xschem nets -selected
}

### 3. membership BY HANDLE — composes with the object/instance handles
p {net_members @wire <id>  (wire ids + {inst-id pin})} {
  xschem net_members @wire [xschem wire_id 0]
}

puts $::logfd "=== the §2c scenario: hold a handle across an edit ==="

# Hold the wire's stable id. Then rename the net by editing its DRIVER label
# (the §2d authority rule), which changes the net NAME under the wire.
set wid [xschem wire_id 0]
p {held anchor: wire_id 0} { set wid }
p {net under the held anchor, before} { dict get [xschem net @wire $wid] name }
xschem setprop instance l1 lab RENAMEDNET
xschem rebuild_connectivity
p {net under the SAME held anchor, after the rename} {
  dict get [xschem net @wire $wid] name
}
p {the anchor id itself is unchanged} { expr {[xschem wire_id 0] == $wid} }

# Contrast: the derived NAME is not a durable handle — it moved.
p {the old name MYNET no longer resolves to a populated net} {
  set d [xschem net MYNET]; expr {[dict get $d nwires] == 0 && [dict get $d npins] == 0}
}

puts $::logfd "=== a dangling anchor is loud, never a stranger ==="
xschem unselect_all; xschem select wire 0; xschem delete
p {net @wire <freed-id> after deleting the wire} {
  set r [xschem net @wire $wid]; expr {$r eq "" ? "(empty — dangled)" : $r}
}

puts $::logfd "DONE"
flush $::logfd
close $::logfd
exit
