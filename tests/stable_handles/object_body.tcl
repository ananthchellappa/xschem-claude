# Tests for the uniform `xschem object` / `xschem objects` read API (step-3
# direction (b)). Committed RED first: the O* tests below are xcheck (XFAIL)
# until the C lands, then flip to check.
#
# Sourced by object_wrap.tcl, which provides `check`, `xcheck`, `::qo_dir`.
#
# THE IDEA: six of seven drawable types now carry session-stable ids, but
# reading/converting between (id, index, name) is a scatter of per-type
# commands with different shapes. This API is the uniform veneer:
#
#   xschem objects [-type T] [-selected] [-layer L]
#       -> a Tcl LIST of dicts, one per object, each:
#          {type T index I layer C id ID name {N}}
#   xschem object <type> <selector>
#       -> the single dict for one object, selector being
#          @<id>  (by stable id) | #<index> or #<layer>,<index> | <name>
#
# No new identity is created here — it reads the ids stamped by steps 1-3 and
# the same per-type resolvers (wire_index_from_id / inst_index_from_id /
# gfx_index_from_id). text (the 7th type, no id yet) reports id -1.

### stub modals
rename tk_messageBox _real_tk_messageBox
proc tk_messageBox {args} {return ok}
rename tk_getOpenFile _real_tk_getOpenFile
proc tk_getOpenFile {args} {return {}}
catch {rename alert_ _real_alert_}
proc alert_ {args} {return 1}

# wrappers: catch "invalid command" so the RED suite runs to completion
proc objs {args} {
  if {[catch {uplevel 1 [list xschem objects {*}$args]} r]} {return -2}
  return $r
}
proc obj {args} {
  if {[catch {uplevel 1 [list xschem object {*}$args]} r]} {return -2}
  return $r
}
# dict get with a default, tolerant of the -2 sentinel / non-dict
proc dg {d key {dflt {}}} {
  if {$d eq "-2" || $d eq ""} {return $dflt}
  if {[catch {dict get $d $key} v]} {return $dflt}
  return $v
}

# build a controlled fixture: one of (almost) every type, on known layers
proc obj_fixture {} {
  xschem set modified 0
  xschem clear force schematic
  xschem wire 0 0 100 0
  xschem wire 0 100 100 100
  xschem instance res.sym 300 300 0 0 {name=RTEST}
  xschem text 500 500 0 0 hello {} 0.3 0
  xschem set rectcolor 5
  xschem rect 0 0 100 100
  xschem rect 200 0 300 100
  xschem line 0 200 100 200
  xschem polygon 0 400 100 400 50 500
  xschem set rectcolor 6
  xschem rect 1000 0 1100 100
  xschem arc 0 600 30 0 180 6
}
proc nrect {c} {return [xschem get rects $c]}

### O1 — `objects` enumerates every object exactly once. The controlled fixture
### has: 2 wires + 1 instance + 1 text + 3 rects (2 on L5, 1 on L6) + 1 line +
### 1 poly + 1 arc = 10 objects. (`xschem get texts` does not exist, so the text
### count is known from the fixture, not queried.)
obj_fixture
set all [objs]
check {O1a objects returns a Tcl list with one dict per object} \
  {$all ne "-2" && [llength $all] > 0}
check {O1b objects count == 10 (2 wire + 1 inst + 1 text + 3 rect + 1 line + 1 poly + 1 arc)} \
  {[llength $all] == 10}

### O2 — each descriptor has the five keys with correct, cross-checked values
obj_fixture
set inst_row {}
foreach o [objs] { if {[dg $o type] eq "instance"} {set inst_row $o} }
check {O2a the instance descriptor carries type/index/layer/id/name keys} \
  {[dg $inst_row type] eq "instance" && [dg $inst_row name] eq "RTEST"}
check {O2b the descriptor id == instance_id of that index, and > 0} \
  {[dg $inst_row id] > 0 && [dg $inst_row id] == [xschem instance_id [dg $inst_row index]]}

### O3 — -type filter restricts to one type
obj_fixture
set rects [objs -type rect]
set only_rects 1
foreach o $rects { if {[dg $o type] ne "rect"} {set only_rects 0} }
check {O3a -type rect returns only rect descriptors} {$rects ne "-2" && $only_rects == 1}
check {O3b -type rect count == total rects across layers (3)} \
  {[llength $rects] == [expr {[nrect 5] + [nrect 6]}]}

### O4 — -selected filter restricts to the current selection
obj_fixture
xschem unselect_all
xschem select rect 5 0
xschem select instance RTEST
set sel [objs -selected]
check {O4a -selected returns exactly the 2 selected objects} \
  {$sel ne "-2" && [llength $sel] == 2}
set sel_types [lsort [lmap o $sel {dg $o type}]]
check {O4b -selected reports the right types (instance + rect)} \
  {$sel_types eq {instance rect}}

### O5 — -layer filter restricts graphical objects to one layer
obj_fixture
set l5 [objs -type rect -layer 5]
set l6 [objs -type rect -layer 6]
check {O5a -type rect -layer 5 returns the 2 layer-5 rects} \
  {$l5 ne "-2" && [llength $l5] == 2}
check {O5b -type rect -layer 6 returns the 1 layer-6 rect} \
  {[llength $l6] == 1 && [dg [lindex $l6 0] layer] == 6}

### O6 — `object <type> @id` resolves a held id to its descriptor
obj_fixture
set iid [xschem instance_id RTEST]
set d [obj instance @$iid]
check {O6 object instance @<id> resolves to the same instance (by name+index)} \
  {[dg $d name] eq "RTEST" && [dg $d id] == $iid && [dg $d index] == [xschem instance_index $iid]}

### O7 — `object <type> #layer,index` resolves a per-layer position
obj_fixture
set d [obj rect #5,1]
check {O7 object rect #5,1 resolves to rect at layer 5 index 1} \
  {[dg $d type] eq "rect" && [dg $d layer] == 5 && [dg $d index] == 1 && \
   [dg $d id] == [xschem rect_id 5 1]}

### O8 — `object instance <name>` resolves by name (bareword)
obj_fixture
set d [obj instance RTEST]
check {O8 object instance <name> resolves by name} \
  {[dg $d name] eq "RTEST" && [dg $d id] == [xschem instance_id RTEST]}

### O9 — `object wire @id` and `object rect #index` round-trip with the resolvers
obj_fixture
set wid [xschem wire_id 0]
set dw [obj wire @$wid]
check {O9a object wire @<id> resolves to wire index 0} \
  {[dg $dw type] eq "wire" && [dg $dw index] == [xschem wire_index $wid] && [dg $dw id] == $wid}
set dr [obj rect #5,0]
check {O9b object rect #5,0 round-trips through rect_index} \
  {[xschem rect_index [dg $dr id]] eq "5 0"}

### O10 — text is the honest straggler: its descriptor carries id -1
obj_fixture
set txt_row {}
foreach o [objs] { if {[dg $o type] eq "text"} {set txt_row $o} }
check {O10 the text descriptor reports id -1 (text has no stable id yet)} \
  {[dg $txt_row type] eq "text" && [dg $txt_row id] == -1}

### O11 — a dangling id resolves to nothing (loud, not a stranger)
obj_fixture
set rid [xschem rect_id 5 0]
xschem unselect_all
xschem select rect 5 0
xschem delete
set d [obj rect @$rid]
check {O11 object rect @<freed-id> returns empty (the id dangles, not a stranger)} \
  {$d eq ""}

### O12 — the descriptor's id agrees with the `selection` enumerator for a
### selected object (the two read surfaces are consistent)
obj_fixture
xschem unselect_all
xschem select rect 5 1
set selrow [lindex [xschem selection] 0]
set d [obj rect #5,1]
check {O12 object descriptor id == selection row id for the same object} \
  {[lindex $selrow 3] == [dg $d id] && [dg $d id] > 0}

xschem set modified 0
