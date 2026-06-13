# Empirical probe: the §2e dangling-reference failure revisited for INSTANCES
# with stable instance handles (feature/stable-object-handles, step-2 Phase D).
# Re-runs the index-dangle failure side-by-side with the handle version that
# does not fail, AND demonstrates the id-vs-name divergence that is unique to
# instances: the auto-name silently aliases across a delete (the R37 hazard),
# but the id never does. The sibling wire probe is probe3.tcl.
# Output: /tmp/inst_probe4.log — every line is "TAG | result".
#
#   cd src && ./xschem -q --script ../code_analysis/introspection_probes/probe4.tcl

set ::logfd [open /tmp/inst_probe4.log w]
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

### 1. the original §2e failure for instances: a raw array index held across a
###    delete of an EARLIER instance silently names a different instance (the
###    compaction shifts everything after the hole down by one)
p {old: instance 6 placement before deleting instance 5} {xschem instance_coord 6}
p {old: delete instance 5 (compaction shifts later indices down)} {
  xschem unselect_all
  xschem select instance 5
  xschem delete
  xschem get instances
}
p {old: "instance 6" after delete — A DIFFERENT INSTANCE} {xschem instance_coord 6}
p {old: undo to restore} {xschem undo; xschem get instances}

### 2. the same scenario by handle: hold the id, not the index
p {new: id of instance 6} {set ::id6 [xschem instance_id 6]}
p {new: placement of instance 6 (what the handle must keep naming)} {
  set ::c6 [string trim [xschem instance_coord 6]]
}
p {new: delete instance 5 again} {
  xschem unselect_all
  xschem select instance 5
  xschem delete
  xschem get instances
}
p {new: instance_index of held id — index moved} {set ::i6 [xschem instance_index $::id6]}
p {new: placement at resolved index — SAME INSTANCE} {string trim [xschem instance_coord $::i6]}
p {new: placement unchanged?} {
  expr {[string trim [xschem instance_coord $::i6]] eq $::c6 \
        ? "YES — handle survived the delete" : "NO"}
}
p {new: undo to restore} {xschem undo; xschem get instances}

### 3. deleting the held instance itself: the handle dangles LOUDLY (-1), it
###    does not silently name a stranger after the compaction
p {dangle: re-fetch id of instance 6} {set ::id6 [xschem instance_id 6]}
p {dangle: delete instance 6 itself} {
  xschem unselect_all
  xschem select instance 6
  xschem delete
  xschem get instances
}
p {dangle: instance_index of held id} {xschem instance_index $::id6}
p {dangle: undo to restore} {xschem undo; xschem get instances}

### 4. THE INSTANCE-SPECIFIC DIVERGENCE — the R37 hazard. Instances own a name,
###    and the name is REUSED: create an auto-named resistor, delete it, create
###    another → the name comes back, so a script holding the NAME silently
###    references a different instance. The id is fresh, so a script holding the
###    ID can tell them apart. This is why Phase D chose "both", id as the
###    durable handle (code_analysis/instance_identity_decision.md).
p {reuse: place an auto-named resistor} {
  xschem unselect_all
  xschem instance res.sym 4000 4000 0 0
  set ::r1 [expr {[xschem get instances] - 1}]
  list name [lindex [xschem instance_coord $::r1] 0] id [xschem instance_id $::r1]
}
p {reuse: remember its name + id} {
  set ::name1 [lindex [xschem instance_coord $::r1] 0]
  set ::idr1  [xschem instance_id $::r1]
}
p {reuse: delete it, then place another resistor at the same spot} {
  xschem unselect_all
  xschem select instance $::r1
  xschem delete
  xschem unselect_all
  xschem instance res.sym 4000 4000 0 0
  set ::r2 [expr {[xschem get instances] - 1}]
  list name [lindex [xschem instance_coord $::r2] 0] id [xschem instance_id $::r2]
}
p {reuse: NAME silently aliased? (the hazard)} {
  expr {[lindex [xschem instance_coord $::r2] 0] eq $::name1 \
        ? "YES — the name $::name1 came back; a held name now points elsewhere" \
        : "no"}
}
p {reuse: ID stayed unique? (the cure)} {
  expr {[xschem instance_id $::r2] != $::idr1 \
        ? "YES — fresh id ([xschem instance_id $::r2]) != old id $::idr1" : "NO"}
}
p {reuse: the OLD id dangles loudly} {xschem instance_index $::idr1}
p {reuse: reload to a clean fixture} {xschem set modified 0; xschem load $SCH; xschem get instances}

### 5. id survives a RENAME, the name does not (the other half of HI8): the id
###    is rename-stable, the name is the thing being renamed
p {rename: place ZZZ, hold its id} {
  xschem unselect_all
  xschem instance res.sym 5000 5000 0 0 {name=ZZZ}
  set ::idz [xschem instance_id ZZZ]
}
p {rename: setprop instance ZZZ name -> RENAMED} {
  xschem unselect_all
  xschem setprop instance ZZZ name RENAMED
  list oldname_resolves [expr {[xschem instance_id ZZZ] != -1}] \
       newname_resolves [expr {[xschem instance_id RENAMED] != -1}]
}
p {rename: the held id still resolves to the renamed instance} {
  set i [xschem instance_index $::idz]
  list index $i name [lindex [xschem instance_coord $i] 0]
}

### 6. disk undo invalidates the id (invalidate-on-restore, settled wire-D3),
###    memory undo round-trips it
p {disk-undo: reload + disk mode} {xschem set modified 0; xschem load $SCH; xschem undo_type disk; xschem get instances}
p {disk-undo: id of instance 6 before the cycle} {set ::id6 [xschem instance_id 6]}
p {disk-undo: edit + undo (forces a restore from .sch temp file)} {
  xschem unselect_all
  xschem instance res.sym 6000 6000 0 0 {name=DUNDO}
  xschem undo
  xschem get instances
}
p {disk-undo: held id after restore — invalidated} {xschem instance_index $::id6}
p {disk-undo: instance 6 has a fresh id} {list old $::id6 new [xschem instance_id 6]}
p {mem-undo: mem mode} {xschem undo_type memory}
p {mem-undo: id of instance 6} {set ::id6 [xschem instance_id 6]}
p {mem-undo: edit + undo} {
  xschem unselect_all
  xschem instance res.sym 6000 6000 0 0 {name=MUNDO}
  xschem undo
  xschem get instances
}
p {mem-undo: held id still resolves to the same placement} {
  set i [xschem instance_index $::id6]
  list index $i placement [string trim [xschem instance_coord $i]]
}

xschem set modified 0
close $::logfd
exit
