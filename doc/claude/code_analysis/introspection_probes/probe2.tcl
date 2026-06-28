# follow-up probe: cache coherence of net queries after setprop wire,
# and instances_to_net with a proper net name
set ::logfd [open /tmp/wire_probe2.log w]
proc p {tag script} {
  if {[catch {uplevel #0 $script} res]} {
    puts $::logfd "$tag | ERROR: $res"
  } else {
    puts $::logfd "$tag | $res"
  }
  flush $::logfd
}
rename tk_messageBox _real_tk_messageBox
proc tk_messageBox {args} {return ok}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

xschem set modified 0
xschem load /home/qflow/dev/xschem/claude_1/xschem/xschem_library/examples/mos_power_ampli.sch

p {baseline: resolved_net of wire 5} {
  xschem select wire 5; xschem resolved_net
}
p {setprop lab=my_probe_net} {xschem setprop wire 5 lab my_probe_net}
p {resolved_net right after setprop} {
  xschem unselect_all; xschem select wire 5; xschem resolved_net
}
p {after rebuild_connectivity} {
  xschem rebuild_connectivity
  xschem unselect_all; xschem select wire 5; xschem resolved_net
}
p {selected_wire now} {xschem selected_wire}
p {does the rename propagate to attached segments?} {
  xschem connected_nets; xschem selected_wire
}
p {instances_to_net OUTI} {string range [xschem instances_to_net OUTI] 0 200}
p {instances_to_net PLUS} {string range [xschem instances_to_net PLUS] 0 200}
xschem set modified 0
close $::logfd
exit
