# Characterization of the CURRENT net surface (step-3 direction (c), Phase A).
# Sourced by net_wrap.tcl, which provides `check`, `xcheck`, `::net_dir`.
#
# THE POINT OF THIS FILE: before giving a net a stable handle, lock down exactly
# what the net surface does today, so the new work has a sensitivity net and the
# baseline is documented. Two facts established here drive the identity design
# (doc/claude/code_analysis/net_identity_decision.md):
#
#   1. A net is DERIVED, not stored. The net name lives as wire[].node / a token
#      in node_table, recomputed on every rebuild. NC2/NC8 prove the wire's lab
#      is a write-only cache the connectivity engine overwrites (defect #6).
#   2. A net's stable ANCHORS already exist. The wire it is on (wire_id) and the
#      label instance that drives it (instance_id, pin) both carry session-stable
#      ids from steps 1-2. NC9/NC10 prove the anchor survives a rename that
#      changes the net's NAME under it — the c2 thesis.
#
# Also locked: the §2c cold-start coherence quirk (NC3) — resolved_net cold
# returns empty until the selection array is rebuilt. The new net* commands MUST
# rebuild_selected_array() (and prepare_netlist_structs(0)) before reading
# .node; this suite proves the bug exists so the fix is verifiable.

### stub modals (a derived-cache rebuild can trip a dialog on a bad schematic)
catch {rename tk_messageBox _real_tk_messageBox}
proc tk_messageBox {args} {return ok}
catch {rename tk_getOpenFile _real_tk_getOpenFile}
proc tk_getOpenFile {args} {return {}}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

# tolerant wrappers so a missing/renamed command does not abort the whole suite
proc rn {args}  { if {[catch {uplevel 1 [list xschem resolved_net {*}$args]} r]} {return -2}; return $r }
proc gp {args}  { if {[catch {uplevel 1 [list xschem getprop {*}$args]} r]} {return -2}; return $r }

# A small CONTROLLED fixture: one wire, one label instance driving net MYNET on
# it. Deterministic ids (wire_id 1, instance_id 1) on a fresh context, so the
# anchor assertions do not depend on a library file's load order.
proc net_fixture {} {
  xschem set modified 0
  xschem clear force schematic
  xschem wire 0 0 200 0
  xschem instance lab_pin.sym 0 0 0 0 {name=l1 lab=MYNET}
  xschem rebuild_connectivity
}

### NC1 — list_nets enumerates nets as {name type} tuples; MYNET is present.
net_fixture
set nets [xschem list_nets]
set names [lmap row $nets {lindex $row 0}]
check {NC1a list_nets returns {name type} rows} \
  {[llength $nets] >= 1 && [llength [lindex $nets 0]] == 2}
check {NC1b list_nets includes the driven net MYNET} \
  {[lsearch -exact $names MYNET] >= 0}

### NC2 — the net name is DERIVED onto the wire: wire 0's lab token is the
### computed node name (MYNET), stamped by the connectivity engine, not user
### data. This is the cache that makes the net "exist" on the wire.
net_fixture
check {NC2 wire 0's derived lab == the net name MYNET} \
  {[gp wire 0 lab] eq "MYNET"}

### NC3 — the §2c cold-start coherence trap. resolved_net of the SELECTION is
### empty on a cold select (sel_array not yet rebuilt) and correct only after an
### unrelated query (get lastsel) rebuilds it. This is the bug the new commands
### must NOT reproduce. (resolved_net BY NAME is cold-safe — see NC4.)
net_fixture
xschem unselect_all
xschem select wire 0
set cold [rn]
xschem get lastsel
set warm [rn]
check {NC3a resolved_net of the selection is EMPTY cold (the §2c trap)} \
  {$cold eq ""}
check {NC3b resolved_net of the selection is MYNET once sel_array is rebuilt} \
  {$warm eq "MYNET"}

### NC4 — resolved_net BY NAME is cold-safe (no selection read), returns the net.
net_fixture
check {NC4 resolved_net MYNET resolves cold (by name, no selection)} \
  {[rn MYNET] eq "MYNET"}

### NC5 — selected_wire returns the DERIVED net token of each selected wire
### (a cache, not a handle): a wire selected on MYNET reports {MYNET}.
net_fixture
xschem unselect_all
xschem select wire 0
xschem get lastsel
check {NC5 selected_wire reports the derived net token {MYNET}} \
  {[xschem selected_wire] eq "{MYNET}"}

### NC6 — pin -> net: instance_net of the label's pin resolves to the net.
net_fixture
check {NC6 instance_net l1 p == MYNET (pin -> net name)} \
  {[xschem instance_net l1 p] eq "MYNET"}

### NC7 — hilight a net by selection: list_hilights names it, bbox is real, and
### unhilight_all clears it back to the empty sentinel bbox.
net_fixture
xschem unselect_all
xschem select wire 0
xschem hilight
set lh [xschem list_hilights]
set bb [xschem get bbox_hilighted]
xschem unhilight_all
set bb_after [xschem get bbox_hilighted]
check {NC7a list_hilights names the highlighted net MYNET} \
  {[string first MYNET $lh] >= 0}
check {NC7b bbox_hilighted is a real (non-sentinel) box while highlighted} \
  {$bb ne "-100 -100 100 100"}
check {NC7c unhilight_all clears the highlight (sentinel bbox returns)} \
  {$bb_after eq "-100 -100 100 100"}

### NC8 — the DERIVED-NAME / authority trap (defect #6): writing a wire's lab is
### silently overwritten by the connectivity engine on the next rebuild. The net
### name is NOT user data on the wire — you cannot rename a net by editing a
### wire segment. (Motivates: a net handle must anchor on the DRIVER, not a
### wire's lab string.)
net_fixture
xschem setprop wire 0 lab BOGUSNAME
check {NC8a setprop wire lab appears to take immediately} \
  {[gp wire 0 lab] eq "BOGUSNAME"}
xschem rebuild_connectivity
check {NC8b ...but the connectivity engine overwrites it back to MYNET} \
  {[gp wire 0 lab] eq "MYNET"}

### NC9 — the stable ANCHORS already exist. The wire on the net and the label
### driving it both carry session-stable ids (steps 1-2). These are the candidate
### durable handles for a net under design option c2.
net_fixture
check {NC9a the wire on the net has a stable id (> 0)} \
  {[xschem wire_id 0] > 0}
check {NC9b the label instance driving the net has a stable id (> 0)} \
  {[xschem instance_id l1] > 0}

### NC10 — THE c2 THESIS, characterized: rename the net by editing its DRIVER
### (the label instance, per the §2d authority rule). The net's NAME changes
### under the wire, but the wire's stable id is UNCHANGED — the anchor survives
### the rename that the name does not. This is why a net handle wants to be the
### anchor's id, with the name as the (mutable) human form.
net_fixture
set wid [xschem wire_id 0]
set iid [xschem instance_id l1]
check {NC10a before rename: wire's derived net is MYNET} {[gp wire 0 lab] eq "MYNET"}
xschem setprop instance l1 lab RENAMEDNET
xschem rebuild_connectivity
check {NC10b after editing the driver, the net NAME changed to RENAMEDNET} \
  {[gp wire 0 lab] eq "RENAMEDNET"}
check {NC10c ...but the wire's stable id is UNCHANGED (anchor survived)} \
  {[xschem wire_id 0] == $wid}
check {NC10d ...and the driver instance's stable id is UNCHANGED too} \
  {[xschem instance_id l1] == $iid}

### NC11 — device pins on a net: instances_to_net lists the DEVICE pins touching
### a net (excluding the label/pin instances themselves). Uses the real example
### so there are actual devices on a net. Locks the existing membership query
### shape {{inst} {pin} {x} {y}} the new net_members will compose with.
xschem set modified 0
xschem load [file normalize ../xschem_library/examples/mos_power_ampli.sch]
xschem set modified 0
xschem rebuild_connectivity
set members [xschem instances_to_net OUTI]
check {NC11a instances_to_net OUTI returns device-pin rows} \
  {[llength $members] >= 1}
check {NC11b each membership row is {{inst} {pin} {x} {y}} (4 fields)} \
  {[llength [lindex $members 0]] == 4}
# the label/pin instances themselves are excluded from instances_to_net
set member_insts [lmap row $members {lindex [lindex $row 0] 0}]
check {NC11c membership lists devices, not the net's own label instance} \
  {[lsearch -glob $member_insts l*] < 0 || [llength $member_insts] > 0}

# ===========================================================================
# Phase C — the new net-as-object commands (direction c2: a net's durable
# handle IS the stable id of a wire/label ANCHOR on it). Committed RED first:
# the NH* tests are xcheck (XFAIL) until xschem net / nets / net_members land,
# then flip to check. Surface (doc/claude/code_analysis/net_identity_decision.md §5):
#
#   xschem net <selector>          -> {name <tok> nwires N npins M anchor {..}}
#       selector: @wire <id> | @inst <id> <pin> | <token>
#   xschem nets [-selected]        -> list of net descriptors (deduped by token)
#   xschem net_members <selector>  -> {wires {<id>..} pins {{<inst-id> <pin>}..}}
#
# The handle a script STORES is the anchor (a step-1/2 id, already stable);
# resolving re-runs connectivity and yields the net's CURRENT token + members.
# ===========================================================================

proc netcmd  {args} { if {[catch {uplevel 1 [list xschem net {*}$args]} r]} {return -2}; return $r }
proc netscmd {args} { if {[catch {uplevel 1 [list xschem nets {*}$args]} r]} {return -2}; return $r }
proc netmem  {args} { if {[catch {uplevel 1 [list xschem net_members {*}$args]} r]} {return -2}; return $r }
proc dgn {d key {dflt {}}} {
  if {$d eq "-2" || $d eq ""} {return $dflt}
  if {[catch {dict get $d $key} v]} {return $dflt}
  return $v
}

### NH1 — `net @wire <id>` resolves the net the wire is on, by its STABLE id.
net_fixture
set wid [xschem wire_id 0]
set d [netcmd @wire $wid]
check {NH1 net @wire <id> -> descriptor naming MYNET} \
  {[dgn $d name] eq "MYNET"}

### NH2 — `net @inst <id> <pin>` resolves the net at a label/instance pin.
net_fixture
set iid [xschem instance_id l1]
set d [netcmd @inst $iid p]
check {NH2 net @inst <id> p -> the net at the driver's pin (MYNET)} \
  {[dgn $d name] eq "MYNET"}

### NH3 — `net <token>` resolves by name (human form), cold-safe (no selection).
net_fixture
check {NH3 net MYNET (by token) resolves cold} \
  {[dgn [netcmd MYNET] name] eq "MYNET"}

### NH4 — the descriptor carries nwires/npins/anchor; the anchor is the DRIVER
### label (preferred over a wire), reported by its stable instance id.
net_fixture
set iid [xschem instance_id l1]
set d [netcmd @wire [xschem wire_id 0]]
check {NH4a descriptor has nwires >= 1 and npins >= 1} \
  {[dgn $d nwires] >= 1 && [dgn $d npins] >= 1}
check {NH4b anchor is the driver label {inst <iid> p}} \
  {[dgn $d anchor] eq "inst $iid p"}

### NH5 — COLD correctness, the §2c (NC3) fix. `nets -selected` must rebuild the
### selection array internally: a FRESH select (no unrelated query first) still
### yields the net. resolved_net of the selection famously fails this (NC3a).
net_fixture
xschem unselect_all
xschem select wire 0
set sel_nets [netscmd -selected]
set names [lmap row $sel_nets {dgn $row name}]
check {NH5 nets -selected works COLD (rebuilds sel_array, unlike resolved_net)} \
  {[lsearch -exact $names MYNET] >= 0}

### NH6 — `nets` enumerates distinct nets, deduped by token. MYNET appears once.
net_fixture
set allnets [netscmd]
set names [lmap row $allnets {dgn $row name}]
check {NH6a nets includes MYNET} {[lsearch -exact $names MYNET] >= 0}
check {NH6b nets is deduped (MYNET appears exactly once)} \
  {[llength [lsearch -all -exact $names MYNET]] == 1}

### NH7 — `net_members @wire <id>` returns membership BY HANDLE: the wire's id is
### in wires, and the driver pin {inst-id p} is in pins.
net_fixture
set wid [xschem wire_id 0]
set iid [xschem instance_id l1]
set m [netmem @wire $wid]
check {NH7a net_members has wires and pins keys} \
  {$m ne "-2" && [dict exists $m wires] && [dict exists $m pins]}
check {NH7b the held wire id is in the members' wire list} \
  {[lsearch -exact [dgn $m wires] $wid] >= 0}
check {NH7c the driver pin {<iid> p} is in the members' pin list} \
  {[lsearch -exact [dgn $m pins] [list $iid p]] >= 0}

### NH8 — THE c2 PAYOFF: hold the ANCHOR, rename the net via its driver, and the
### handle still resolves — to the NEW token. The name changed under the handle;
### the handle did not. (Contrast NC10, which proved the anchor id is stable;
### this proves the net command rides that stability.)
net_fixture
set wid [xschem wire_id 0]
check {NH8a before rename: net @wire <id> is MYNET} \
  {[dgn [netcmd @wire $wid] name] eq "MYNET"}
xschem setprop instance l1 lab RENAMEDNET
xschem rebuild_connectivity
check {NH8b same held anchor now resolves to the NEW token RENAMEDNET} \
  {[dgn [netcmd @wire $wid] name] eq "RENAMEDNET"}
check {NH8c the anchor id itself is unchanged across the rename} \
  {[xschem wire_id 0] == $wid}

### NH9 — a dangling anchor is loud: delete the wire, the held id resolves to "".
net_fixture
set wid [xschem wire_id 0]
xschem unselect_all
xschem select wire 0
xschem delete
check {NH9 net @wire <freed-id> returns empty (dangles, not a stranger)} \
  {[netcmd @wire $wid] eq ""}

### NH10 — on the real example, net_members of OUTI lists device pins by handle
### (instance-id + pin), composing with the instance handles from step 2.
xschem set modified 0
xschem load [file normalize ../xschem_library/examples/mos_power_ampli.sch]
xschem set modified 0
xschem rebuild_connectivity
set m [netmem OUTI]
check {NH10a net_members OUTI returns a non-empty pin list} \
  {$m ne "-2" && [llength [dgn $m pins]] >= 1}
# every pin entry is {inst-id pin}; the inst-id resolves back to a live instance
set ok 1
foreach pe [dgn $m pins] {
  set iid [lindex $pe 0]
  if {$iid <= 0 || [catch {xschem instance_index $iid} idx] || $idx < 0} {set ok 0}
}
check {NH10b each pin's inst-id is a live, resolvable instance handle (> 0)} \
  {$ok == 1 && [llength [dgn $m pins]] >= 1}

xschem set modified 0
