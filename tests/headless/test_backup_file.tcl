# B1: autosave backup-file helpers (cellName~.sch).
# Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Verifies the low-level helpers (not yet hooked to edits -- that is B2):
#   xschem backup name|write|remove
# - name derivation inserts '~' before the extension,
# - write serializes the CURRENT (possibly unsaved) buffer to the ~ file,
# - the ~ content matches a normal save of the same buffer,
# - remove deletes it,
# - autosave_backup=0 suppresses writing,
# - an untitled buffer (no on-disk file yet) IS backed up too (issue 0060 -- descend needs it).
#
# Run: src/xschem --nogui --pipe -q --nolog --script tests/headless/test_backup_file.tcl

set fixdir [file normalize [file join [file dirname [info script]] fixtures descend]]
if {![info exists XSCHEM_LIBRARY_PATH]} { set XSCHEM_LIBRARY_PATH {} }
set XSCHEM_LIBRARY_PATH "$fixdir:$XSCHEM_LIBRARY_PATH"

set ::f 0
proc ck {name ok} { puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; if {!$ok} {incr ::f} }
proc body {file} {
  if {![file exists $file]} { return "<missing>" }
  set fp [open $file r]; set d [read $fp]; close $fp
  return [join [lrange [split $d \n] 1 end] \n]   ;# drop version header line
}
proc count_wires {file} {
  set n 0
  if {![file exists $file]} { return -1 }
  set fp [open $file r]; foreach ln [split [read $fp] \n] { if {[string match "N *" $ln]} { incr n } }; close $fp
  return $n
}

xschem load $fixdir/descend_parent.sch
set bak [xschem backup name]
ck "backup name inserts ~ before extension" [string match "*/descend_parent~.sch" $bak]

# write produces the ~ file, content == a normal save of the same buffer
file delete -force $bak
xschem backup write
ck "backup write creates the ~ file" [file exists $bak]
xschem saveas /tmp/b1_ref.sch schematic
ck "backup content matches a normal save" [expr {[body $bak] eq [body /tmp/b1_ref.sch]}]
file delete -force $bak

# write reflects the CURRENT (unsaved) edit
xschem load $fixdir/descend_parent.sch
xschem wire 200 300 300 300
xschem backup write
ck "backup captures the live unsaved edit (2 wires)" [expr {[count_wires $bak] == 2}]

# remove deletes it
xschem backup remove
ck "backup remove deletes the ~ file" [expr {![file exists $bak]}]

# autosave_backup=0 suppresses writing
file delete -force $bak
set autosave_backup 0
xschem backup write
ck "autosave_backup=0 suppresses the write" [expr {![file exists $bak]}]
set autosave_backup 1

# untitled buffer (no real on-disk file) IS backed up too (issue 0060): descend relies on
# the ~ backup to restore an unsaved top level, so write_backup must not skip a never-saved
# buffer -- skipping it lost the whole top level on descend+ascend from a new/pasted canvas.
xschem clear force
xschem instance $fixdir/descend_child.sym 0 0 0 0 {name=x1}   ;# give the untitled buffer content
set ubak [xschem backup name]
file delete -force $ubak
xschem backup write
ck "untitled buffer IS backed up (issue 0060)" [file exists $ubak]
file delete -force $ubak   ;# don't leave untitled~.sch in the run cwd

puts [expr {$::f == 0 ? "RESULT: ALL PASS" : "RESULT: $::f FAILED"}]
exit [expr {$::f != 0}]
