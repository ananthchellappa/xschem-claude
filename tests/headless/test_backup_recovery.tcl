# B8: lifecycle + crash recovery for the autosave "~" backing file.
# Spec: doc/claude/specs/descend_hierarchy_in_memory.md
#
# Run TRUE HEADLESS from the repo root:
#   src/xschem --nogui --pipe -q --nolog --script tests/headless/test_backup_recovery.tcl
#
# R1  load_backup primitive: load cellName~.sch as CONTENT while keeping identity
#     = cellName, flagged modified (the seam shared by go_back and recovery).
# R2  discard cleanup: clearing/discarding a dirty buffer removes its ~ backup, so
#     a leftover ~ on open unambiguously means a crash (not an intentional discard).
# R3  recovery offer (xschem_recover_backup): a ~ newer than the saved cell is a
#     crash artifact -> offered (yes restores it, no removes it); a ~ older than the
#     cell is stale junk -> silently removed, never offered.
#
# Works on a /tmp copy so the ~ backups never pollute the committed fixtures.

set work /tmp/b8_recovery_work
file delete -force $work; file mkdir $work

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
proc ask_save {{cmd {}}} { return no }

# write a minimal schematic file with $n horizontal wires
proc write_sch {path n} {
  set fp [open $path w]
  puts $fp "v {xschem version=3.4.4 file_version=1.2}"
  puts $fp "G {}"; puts $fp "V {}"; puts $fp "S {}"; puts $fp "E {}"
  for {set i 0} {$i < $n} {incr i} { puts $fp "N 0 [expr {$i*10}] 100 [expr {$i*10}] {}" }
  close $fp
}

# ---------------------------------------------------------------------------
# R1: load_backup loads the ~ content under the cell's identity, modified.
# ---------------------------------------------------------------------------
set cell $work/r1.sch
set bak  $work/r1~.sch
write_sch $cell 1
write_sch $bak  2   ;# "unsaved crash content": 2 wires

xschem load $cell
check "R1: clean open loads the on-disk cell (1 wire), no auto-recover headless" \
  [expr {[xschem get wires] == 1 && [file tail [xschem get schname]] eq "r1.sch"}]

set loaded [xschem load_backup $cell]
check "R1: load_backup reports it restored a backup" [expr {$loaded == 1}]
check "R1: backup CONTENT loaded (2 wires)" [expr {[xschem get wires] == 2}]
check "R1: logical identity stays the real cell (r1.sch, not r1~.sch)" \
  [expr {[file tail [xschem get schname]] eq "r1.sch"}]
check "R1: buffer flagged modified (unsaved vs the cell)" [expr {[xschem get modified] == 1}]

# load_backup with no ~ present returns 0
file delete -force $bak
xschem load $cell
check "R1: load_backup returns 0 when no ~ exists" [expr {[xschem load_backup $cell] == 0}]

# ---------------------------------------------------------------------------
# R2: discarding a dirty buffer (clear) removes its ~ backup.
# ---------------------------------------------------------------------------
set cell2 $work/r2.sch
set bak2  $work/r2~.sch
write_sch $cell2 1
file delete -force $bak2
xschem load $cell2
xschem wire 200 300 300 300     ;# edit -> autosave writes r2~.sch
check "R2: edit autosaved the ~ backup" [file exists $bak2]
xschem clear                    ;# discard (ask_save stub -> no)
check "R2: discarding the dirty buffer removed its ~ backup" [expr {![file exists $bak2]}]

# ---------------------------------------------------------------------------
# R3: recovery offer logic (stub the dialog).
# ---------------------------------------------------------------------------
set ::mb_answer yes
set ::mb_calls 0
proc tk_messageBox {args} { incr ::mb_calls; return $::mb_answer }

# (a) ~ NEWER than the cell -> crash artifact -> offered; "yes" restores it.
set cell3 $work/r3.sch
set bak3  $work/r3~.sch
write_sch $cell3 1
xschem load $cell3
write_sch $bak3 3               ;# create a NEWER backup (written after the cell)
file mtime $bak3 [expr {[file mtime $cell3] + 5}]
set ::mb_answer yes; set ::mb_calls 0
set rec [xschem_recover_backup $cell3]
check "R3a: a newer ~ is offered for recovery (dialog shown)" [expr {$::mb_calls == 1}]
check "R3a: 'yes' restored the backup content (3 wires)" \
  [expr {$rec == 1 && [xschem get wires] == 3 && [xschem get modified] == 1}]

# (b) ~ NEWER, user says "no" -> backup removed, not loaded.
write_sch $bak3 3
file mtime $bak3 [expr {[file mtime $cell3] + 5}]
xschem load $cell3
set ::mb_answer no; set ::mb_calls 0
set rec [xschem_recover_backup $cell3]
check "R3b: 'no' did not restore and removed the ~ backup" \
  [expr {$rec == 0 && ![file exists $bak3]}]

# (c) ~ OLDER than the cell -> stale junk -> removed silently, never offered.
write_sch $bak3 3
xschem load $cell3
file mtime $cell3 [expr {[file mtime $bak3] + 5}]   ;# cell saved AFTER the backup
set ::mb_answer yes; set ::mb_calls 0
set rec [xschem_recover_backup $cell3]
check "R3c: a stale (older) ~ is removed without asking" \
  [expr {$rec == 0 && $::mb_calls == 0 && ![file exists $bak3]}]

result
