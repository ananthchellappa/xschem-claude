# B6 acceptance: backing-file autosave for SYMBOLS (cellName~.sym) and the
# descend_symbol path. Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_symbol.tcl
#
# Part A (symbol autosave): editing a .sym buffer writes cellName~.sym via the
#   set_modify hook (backup_file_name handles .sym too), and a real save removes it.
# Part B (descend_symbol): descending into a component's symbol view must NOT pop
#   the save prompt (SY2, RED until B6) and must not lose the parent's unsaved edits
#   on go_back (SY1) -- the parent edit is persisted to parent~.sch and reloaded.
#
# Works on a /tmp copy so the ~ backups never pollute the committed fixtures.

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
set work /tmp/b6_descend_symbol_work
file delete -force $work; file mkdir $work
foreach fn {descend_parent.sch descend_child.sch descend_child.sym} {
  file copy -force $fixdir/$fn $work/$fn
}
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$work:$fixdir:$XSCHEM_LIBRARY_PATH"

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}
proc result {} {
  puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
  flush stdout
  exit [expr {$::fails != 0}]
}

# Count + decline the save prompt: edits must survive either way.
set ::ask_count 0
proc ask_save {{cmd {}}} { incr ::ask_count; return no }

# ---------------------------------------------------------------------------
# Part A: a .sym buffer is autosaved to cellName~.sym, and a save removes it.
# ---------------------------------------------------------------------------
set symbak $work/descend_child~.sym
file delete -force $symbak
xschem load $work/descend_child.sym
check "loaded symbol buffer (descend_child.sym)" \
  [expr {[file tail [xschem get schname]] eq "descend_child.sym"}]
check "fresh symbol load is not flagged modified" [expr {[xschem get modified] == 0}]
check "no ~ backup before any edit" [expr {![file exists $symbak]}]

# genuine edit to the symbol -> set_modify hook writes the ~.sym
xschem line -40 -40 40 -40
check "symbol edit set the modified flag" [expr {[xschem get modified] == 1}]
check "A: symbol edit autosaved to cellName~.sym" [file exists $symbak]

# a real save commits the edit and drops the ~ backup
xschem save
check "A: real save removed the ~.sym backup" [expr {![file exists $symbak]}]
check "save cleared the modified flag" [expr {[xschem get modified] == 0}]

# ---------------------------------------------------------------------------
# Part B: descend_symbol must not prompt, and must preserve the parent edit.
# ---------------------------------------------------------------------------
set parbak $work/descend_parent~.sch
file delete -force $parbak
set ::ask_count 0
xschem load $work/descend_parent.sch
set base [xschem get wires]
check "loaded parent schematic (1 wire, 1 instance)" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch" && $base == 1 && [xschem get instances] == 1}]

# unsaved edit to the PARENT (autosave writes parent~.sch)
xschem wire 200 300 300 300
set edited [xschem get wires]
check "parent edit applied (wire added, modified set)" \
  [expr {$edited == $base + 1 && [xschem get modified] == 1}]
check "parent edit autosaved to parent~.sch" [file exists $parbak]

# descend into the SYMBOL view of the instance, declining any save
xschem unselect_all
xschem select instance 0
xschem descend_symbol
check "descended into the symbol view (descend_child.sym)" \
  [expr {[file tail [xschem get schname]] eq "descend_child.sym"}]

# return to the parent
xschem go_back
check "returned to parent schematic" \
  [expr {[file tail [xschem get schname]] eq "descend_parent.sch"}]

# SY1: the unsaved parent edit must still be there (reloaded from parent~.sch)
check "SY1: parent edit preserved across descend_symbol/go_back" \
  [expr {[xschem get wires] == $edited}]
check "SY1: parent still flagged modified on return" \
  [expr {[xschem get modified] == 1}]

# SY2: descend_symbol must not have prompted at all (RED until B6)
check "SY2: descend_symbol did not pop the save prompt" \
  [expr {$::ask_count == 0}]

# ---------------------------------------------------------------------------
# Part C: EMBEDDED-symbol descent is deferred -- it must STILL prompt (the
# legacy guard), because go_back's embedded return reloads the parent from disk
# (not from parent~.sch), so dropping the prompt there would silently lose the
# parent's unsaved edits. This pins the deferral boundary: B6 covers only the
# non-embedded case. See doc/claude/specs/descend_hierarchy_in_memory.md.
# ---------------------------------------------------------------------------
set embpar $work/emb_parent.sch
set fp [open $embpar w]
puts $fp "v {xschem version=3.4.4 file_version=1.2}"
puts $fp "G {}"
puts $fp "V {}"
puts $fp "S {}"
puts $fp "E {}"
puts $fp "N 200 200 300 200 {}"
puts $fp "C {descend_child.sym} 0 0 0 0 {name=x1 embed=true}"
close $fp
file delete -force $work/emb_parent~.sch
set ::ask_count 0
xschem load $embpar
xschem wire 200 300 300 300   ;# modify the parent so the guard can fire
xschem unselect_all
xschem select instance 0
xschem descend_symbol
check "descended into embedded symbol view" \
  [expr {[string match ".xschem_embedded_*" [file tail [xschem get schname]]]}]
check "SYC: embedded-symbol descent STILL prompts (data-loss guard kept)" \
  [expr {$::ask_count > 0}]
xschem go_back

result
