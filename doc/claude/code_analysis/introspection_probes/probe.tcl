# Empirical probe: what can Tcl code do with (a) the schematic and (b) a
# selected wire, using only the public `xschem` command surface?
# Output: /tmp/wire_probe.log — every line is "TAG | result".

set ::logfd [open /tmp/wire_probe.log w]
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

### 1. schematic-level inventory
p {counts: wires}        {xschem get wires}
p {counts: instances}    {xschem get instances}
p {counts: texts}        {xschem get texts}
p {counts: lastsel}      {xschem get lastsel}
p {window: schname}      {xschem get schname}
p {window: current_name} {xschem get current_name}
p {window: topwindow}    {xschem get topwindow}
p {window: current_win_path} {xschem get current_win_path}
p {window: ntabs}        {xschem get ntabs}
p {window: tab_list}     {xschem tab_list}
p {nets: list_nets (first 120 chars)} {string range [xschem list_nets] 0 119}

### 2. select a wire programmatically and inspect the selection
p {select wire 5 rc}     {xschem select wire 5}
p {sel: lastsel}         {xschem get lastsel}
p {sel: first_sel (type n col)} {xschem get first_sel}
p {sel: selected_wire}   {xschem selected_wire}
p {sel: selected_set}    {xschem selected_set}
p {sel: selected_set rect} {xschem selected_set rect}
p {sel: bbox_selected}   {xschem get bbox_selected}

### 3. per-wire queries by index
p {wire_coord 5}         {xschem wire_coord 5}
p {wire_coord 0 (off-by-one?)} {xschem wire_coord 0}
p {wire_coord 1}         {xschem wire_coord 1}
p {getprop wire 5 lab}   {xschem getprop wire 5 lab}
p {getprop wire 5 bus}   {xschem getprop wire 5 bus}
p {getprop wire 5 (whole string?)} {xschem getprop wire 5}
p {getprop wire 5 node (struct field?)} {xschem getprop wire 5 node}

### 4. net identity of the selected wire
p {resolved_net (selected wire)} {xschem resolved_net}
# find a wire with a lab attribute, if any
p {labels: wires with lab attr} {
  set found {}
  set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} {
    set l [xschem getprop wire $i lab]
    if {$l ne {}} {lappend found "$i:$l"}
  }
  set found
}

### 5. enumerate all wires (the only idiom available: index loop)
p {enumerate: first 5 wires coord+lab} {
  set out {}
  for {set i 0} {$i < 5} {incr i} {
    lappend out "\[$i\] [xschem wire_coord $i] lab=[xschem getprop wire $i lab]"
  }
  join $out "\n     "
}

### 6. connectivity expansion from the selected wire
p {connected_nets: lastsel after} {
  xschem unselect_all
  xschem select wire 5
  xschem connected_nets
  xschem get lastsel
}
p {connected_nets: selected_wire after} {xschem selected_wire}

### 7. modify: setprop, move, delete, undo — and index (in)stability
p {setprop wire 5 lab my_probe_net} {xschem setprop wire 5 lab my_probe_net}
p {getprop wire 5 lab after set}    {xschem getprop wire 5 lab}
p {resolved_net after lab set} {
  xschem unselect_all
  xschem select wire 5
  xschem resolved_net
}
p {setprop wire 5 lab (delete attr)} {xschem setprop wire 5 lab}
p {getprop wire 5 lab after delete}  {xschem getprop wire 5 lab}

p {stability: coords of wire 6 before deleting wire 5} {xschem wire_coord 6}
p {stability: delete wire 5} {
  xschem unselect_all
  xschem select wire 5
  xschem delete
  xschem get wires
}
p {stability: coords of wire 6 after delete} {xschem wire_coord 6}
p {stability: undo restores} {xschem undo; xschem get wires}
p {stability: wire 6 after undo} {xschem wire_coord 6}

p {move: select wire 5 + move_objects 10 10} {
  xschem unselect_all
  xschem select wire 5
  xschem move_objects 10 10
  xschem wire_coord 5
}
p {move: undo} {xschem undo; xschem wire_coord 5}

### 8. hilight from code
p {hilight selected wire} {
  xschem unselect_all
  xschem select wire 5
  xschem hilight
  xschem get bbox_hilighted
}
p {list_hilights} {xschem list_hilights}
p {unhilight_all} {xschem unhilight_all; xschem get bbox_hilighted}

### 9. instance contrast: what the same questions look like for instances
p {inst: name of instance 0} {xschem getprop instance 0 cell::name}
p {inst: full prop string of inst 0} {xschem getprop instance 0}
p {inst: instance_pins} {
  set n [xschem instance_list]
  set first [lindex [split $n \n] 0]
  set iname [lindex $first 0]
  list $iname -> [xschem instance_pins $iname]
}
p {inst: instance_net of first pin} {
  set first [lindex [split [xschem instance_list] \n] 0]
  set iname [lindex $first 0]
  set pin [lindex [xschem instance_pins $iname] 0]
  list $iname $pin -> [xschem instance_net $iname $pin]
}
p {inst: instance_bbox} {
  set first [lindex [split [xschem instance_list] \n] 0]
  xschem instance_bbox [lindex $first 0]
}

### 10. point queries
p {closest_object (mouse at 0,0)} {xschem closest_object}
p {instances_to_net (first net in list_nets)} {
  set net [lindex [split [xschem list_nets] \n] 0]
  list net=$net -> [string range [xschem instances_to_net $net] 0 150]
}

xschem set modified 0
close $::logfd
exit
