# Step 6: restore fidelity. A descend/go_back round trip through the in-memory
# snapshot must reproduce the (unmodified) parent EXACTLY as a fresh disk load --
# every object type and property, plus the restored zoom and a clean modified flag.
# Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Strategy: save the schematic to a file after a fresh load and again after a
# memory round trip, and compare the files byte-for-byte (the .sch text captures
# wires, instances, lines, rects, polygons, arcs, texts and all props -- a far
# stronger check than per-type tcl readback). Zoom and modified are checked in
# process (they are not stored in the .sch).
#
# Run: src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_fidelity.tcl

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$fixdir:$XSCHEM_LIBRARY_PATH"

set ::f 0
proc ck {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; if {!$ok} {incr ::f} }
proc ask_save {{c {}}} { return no }

# body of a saved .sch with the version header line (line 0) stripped
proc body {file} {
  set fp [open $file r]; set data [read $fp]; close $fp
  return [join [lrange [split $data \n] 1 end] \n]
}

set parent $fixdir/descend_fid_parent.sch

# --- baseline: fresh load, save ---
xschem load $parent
set z0 "[xschem get xorigin] [xschem get yorigin] [xschem get zoom]"
set c0 "w=[xschem get wires] i=[xschem get instances] s=[xschem get symbols] l=[xschem get lines 4] r=[xschem get rects 8] p=[xschem get polygons 7] a=[xschem get arcs 5]"
xschem saveas /tmp/fid_fresh.sch schematic

# --- memory round trip: fresh load -> descend -> go_back -> save ---
xschem load $parent
xschem unselect_all
xschem select instance x1
xschem descend
xschem go_back
set m1 [xschem get modified]
set z1 "[xschem get xorigin] [xschem get yorigin] [xschem get zoom]"
set c1 "w=[xschem get wires] i=[xschem get instances] s=[xschem get symbols] l=[xschem get lines 4] r=[xschem get rects 8] p=[xschem get polygons 7] a=[xschem get arcs 5]"
xschem saveas /tmp/fid_rt.sch schematic

ck "object counts identical after round trip ($c0)" [expr {$c0 eq $c1}]
ck "zoom restored to pre-descend view ($z0)" [expr {$z0 eq $z1}]
ck "modified stays 0 after unmodified round trip" [expr {$m1 == 0}]
ck "saved schematic byte-identical (all object types + props)" \
  [expr {[body /tmp/fid_fresh.sch] eq [body /tmp/fid_rt.sch]}]

puts [expr {$::f == 0 ? "RESULT: ALL PASS" : "RESULT: $::f FAILED"}]
exit [expr {$::f != 0}]
