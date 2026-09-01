# Reopen-most-recent (Ctrl+Shift+O) and the recent-files list — issue 0839.
#
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_reopen_recent.tcl
#
# WHAT BROKE. ~/.xschem/recent_files was found holding
#     set tctx::recentfile {/…/tb_bandgap.sch {}}
# — a real path and an EMPTY STRING. get_lastopened() walks the list for the
# first entry that is not already open; `xschem check_loaded {}` reports "not
# loaded", so the empty element ALWAYS satisfied that test and Ctrl+Shift+O
# issued `xschem load {}`. It was reached exactly when the real first entry was
# already open, which is why the failure looked intermittent. And the empty load
# then handed "" to update_recent_file, which PERSISTED it — the bug reinstalled
# itself on every relaunch.
#
# Four guards, four groups below, each with a positive twin so a group cannot go
# green by disabling the thing it guards.

set failed 0
set checks 0
proc ck {name cond} {
  global failed checks
  incr checks
  if {[uplevel 1 [list expr $cond]]} { puts "ok:   $name" } else { puts "FAIL: $name"; incr failed }
}

set TMP [file join /tmp xschem_reopen_test_[pid]]
file mkdir $TMP

# two real schematics, so `check_loaded` has something true to say
foreach n {a b} {
  set fd [open $TMP/$n.sch w]
  puts $fd "v {xschem version=3.4.5 file_version=1.2}"
  puts $fd "G {}"
  puts $fd "K {}"
  puts $fd "V {}"
  puts $fd "S {}"
  puts $fd "E {}"
  close $fd
}
set A $TMP/a.sch
set B $TMP/b.sch

# ---------------------------------------------------------------- group R1-R3
# get_lastopened: skip empties, and never fall out of the foreach holding the
# loop variable.
xschem load $A
ck "R0  fixture: a.sch is loaded (check_loaded is meaningful)" \
   {[xschem check_loaded $A] ne {}}
ck "R0b fixture: b.sch is NOT loaded" \
   {[xschem check_loaded $B] eq {}}

set tctx::recentfile [list $A {} $B]
ck "R1  an empty element is SKIPPED, not returned (the reported bug)" \
   {[get_lastopened] eq $B}

set tctx::recentfile [list $A]
ck "R2  every entry already loaded returns {} — NOT the last element" \
   {[get_lastopened] eq {}}

set tctx::recentfile [list {} {} {}]
ck "R3  a list of only empties returns {}" \
   {[get_lastopened] eq {}}

# positive twin: the proc still WORKS. A guard that answered {} unconditionally
# would pass R1-R3 and break the feature.
set tctx::recentfile [list $B $A]
ck "R4  POSITIVE TWIN: an unloaded first entry is returned unchanged" \
   {[get_lastopened] eq $B}

# ---------------------------------------------------------------- group R5-R6
# update_recent_file refuses an empty filename. Point USER_CONF_DIR at the
# scratch dir first — write_recent_file writes for real — and un-gate the
# session (a --pipe run sets update_recent_files 0, which would make BOTH arms
# no-op and the group vacuous).
set _saved_conf $::USER_CONF_DIR
set _saved_gate [expr {[info exists ::update_recent_files] ? $::update_recent_files : 1}]
set ::USER_CONF_DIR $TMP
set ::update_recent_files 1

set tctx::recentfile [list $A]
update_recent_file {}
ck "R5  update_recent_file {} leaves the list untouched (breaks the self-poisoning loop)" \
   {$tctx::recentfile eq [list $A]}
ck "R5b update_recent_file {} does not create the conf file" \
   {![file exists $TMP/recent_files]}

update_recent_file $B
ck "R6  POSITIVE TWIN: a real path IS recorded, most-recent first" \
   {[lindex $tctx::recentfile 0] eq $B}
ck "R6b POSITIVE TWIN: and IS persisted" \
   {[file exists $TMP/recent_files]}

# ---------------------------------------------------------------- group R7-R8
# load_recent_file filters empties out of an ALREADY-POISONED conf file. R5
# stops new ones; it cannot remove one already on disk in the wild.
set fd [open $TMP/recent_files w]
puts $fd "set tctx::recentfile {$A {} $B}"
puts $fd "set tctx::recentdirs {$TMP {}}"
close $fd
set tctx::recentfile {}
catch {load_recent_file}
ck "R7  a poisoned conf file loads CLEAN — the {} is dropped on the way in" \
   {[lsearch -exact $tctx::recentfile {}] == -1}
ck "R8  POSITIVE TWIN: and the two real entries survive, in order" \
   {$tctx::recentfile eq [list $A $B]}
ck "R8b POSITIVE TWIN: recentdirs is filtered too, real entry kept" \
   {$tctx::recentdirs eq [list $TMP]}

set ::USER_CONF_DIR $_saved_conf
set ::update_recent_files $_saved_gate

# ------------------------------------------------------------------ group R9
# The C no-op: `xschem load -lastopened` with nothing to reopen must NOT load
# the empty path. Before the fix this reached load_schematic() with f="" and
# replaced the current drawing.
set tctx::recentfile [list $A]          ;# a.sch is loaded -> resolver returns {}
set before [xschem get schname]
catch {xschem load -lastopened}
ck "R9  nothing to reopen is a NO-OP — the current schematic is untouched" \
   {[xschem get schname] eq $before}
ck "R9b and it did not blank the drawing" \
   {[xschem get schname] ne {}}

# positive twin: the verb still reopens when there IS something to reopen.
set tctx::recentfile [list $B $A]
catch {xschem load -lastopened}
ck "R10 POSITIVE TWIN: -lastopened still loads the most recent unloaded file" \
   {[file tail [xschem get schname]] eq {b.sch}}

file delete -force $TMP
puts "test_reopen_recent: $checks checks"
if {$failed} { puts "RESULT: $failed FAILED" } else { puts "RESULT: ALL PASS" }
xschem exit closewindow force
