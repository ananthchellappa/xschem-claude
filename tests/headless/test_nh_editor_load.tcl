# Net highlight style editor — slice 9: Load… (parse a styles file INTO the editor; Replace / Add).
# Load must PARSE the file, never `source` it: a saved/similar/hand-edited file may carry a live
# `catch {xschem update_net_hilight_style}` (apply bypassing staging) or outright dangerous lines, so
# the table value is extracted in a safe child interp (xschem no-op'd) with zero side effects on the
# live tool, then STAGED (apply=0 — nothing reaches the schematic until Apply/OK).
#
# Three parts:
#  (A) HEADLESS round-trip: write_net_hilight_style_conf then nhse_parse_style_file returns the saved
#      table; a file with no net_hilight_style → {}.
#  (B) HEADLESS SAFETY (the important one): a styles file that ALSO contains a sentinel set and lines
#      needing blocked capabilities (file mkdir) + a bare `xschem update_net_hilight_style` is parsed
#      WITHOUT the table being lost, WITHOUT the sentinel reaching the main interp (proves not sourced),
#      WITHOUT the evil dir being created (proves file/exec blocked), and WITHOUT a live C update firing.
#      Sabotage: source-instead-of-parse → the sentinel appears / the dir is created → these checks FAIL.
#  (C) GUI (needs Tk/X): the Load… button exists; Load Replace makes the table the file's rows, staged
#      (no live update); Load Add appends + renumbers; the "no styles" path leaves the table unchanged.
#
# Run headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_nh_editor_load.tcl
# Run GUI:       DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_nh_editor_load.tcl

set fail 0
proc check {n ok d} { global fail; if {$ok} { puts "ok:   $n $d" } else { puts "FAIL: $n $d"; incr fail } }

set ::USER_CONF_DIR [file join [pwd] _nheload_[pid]] ; file delete -force $::USER_CONF_DIR ; file mkdir $::USER_CONF_DIR

# ---- (A) headless parse round-trip -----------------------------------------------------------
# write_net_hilight_style_conf writes `set net_hilight_style {<rows>}`; nhse_parse_style_file extracts
# exactly that value (RAW — no normalization here; the staged mutators normalize on stage), so a clean
# table round-trips identically.
set saved {{0 red 2 {6 4} 0 0 march_fwd 1} {1 green 1 {} 0 0 none 0}}
set ::net_hilight_style $saved
set okfile [file join $::USER_CONF_DIR styles_ok]
check "A0 write_net_hilight_style_conf succeeds" [expr {[write_net_hilight_style_conf $okfile] == 1}] {}

set rc [catch {nhse_parse_style_file $okfile} rows]
check "A1 parse returns the saved table" [expr {$rc == 0 && $rows eq $saved}] "(rc=$rc => $rows)"

# a file with no net_hilight_style assignment → {}
set nofile [file join $::USER_CONF_DIR not_a_style_file]
set fd [open $nofile w] ; puts $fd "# just a comment, no styles here" ; puts $fd "set something_else 42" ; close $fd
set rc [catch {nhse_parse_style_file $nofile} rows]
check "A2 parse of a no-style file → {}" [expr {$rc == 0 && $rows eq {}}] "(rc=$rc => '$rows')"

# a totally unreadable path → {} (read failure is catch-guarded)
set rc [catch {nhse_parse_style_file [file join $::USER_CONF_DIR does_not_exist]} rows]
check "A3 parse of a missing file → {}" [expr {$rc == 0 && $rows eq {}}] "(rc=$rc => '$rows')"

# ---- (B) headless SAFETY: parse-not-source; dangerous lines inert; no live update ------------
# Count ACTUAL C live-updates by wrapping the xschem command itself (the same technique the staged-model
# test uses): a bare `xschem update_net_hilight_style` in the file must NOT reach the real C side.
set ::upd 0
rename xschem xschem_real
proc xschem {args} {
  if {[lindex $args 0] eq {update_net_hilight_style}} { incr ::upd }
  return [eval [linsert $args 0 xschem_real]]
}

set evil /tmp/nhse_evil_[pid]
file delete -force $evil

# The table assignment is FIRST so it always survives (a later erroring line halts the whole-script
# eval but leaves net_hilight_style already set). The sentinel + xschem + file lines come AFTER it.
set dfile [file join $::USER_CONF_DIR styles_dangerous]
set fd [open $dfile w]
puts $fd "set net_hilight_style {$saved}"
puts $fd "set ::nhse_sourced_sentinel DANGER"
puts $fd "xschem update_net_hilight_style"
puts $fd "file mkdir $evil"
puts $fd "catch {exec touch ${evil}_exec}"
close $fd

unset -nocomplain ::nhse_sourced_sentinel
set ::upd 0
set rc [catch {nhse_parse_style_file $dfile} rows]

check "B1 dangerous file still yields the table" [expr {$rc == 0 && $rows eq $saved}] "(rc=$rc => $rows)"
check "B2 NOT sourced: sentinel did NOT reach the main interp" [expr {![info exists ::nhse_sourced_sentinel]}] \
  "(exists=[info exists ::nhse_sourced_sentinel])"
check "B3 file/exec blocked: evil dir was NOT created" [expr {![file exists $evil] && ![file exists ${evil}_exec]}] \
  "(dir=[file exists $evil] exec=[file exists ${evil}_exec])"
check "B4 no live C update fired during parse" [expr {$::upd == 0}] "(updates=$::upd)"

file delete -force $evil ${evil}_exec
rename xschem {} ; rename xschem_real xschem

# ---- (C) GUI: button, Load Replace/Add staged, no-styles leaves table unchanged --------------
if {[catch {winfo exists .}]} {
  file delete -force $::USER_CONF_DIR
  if {$fail == 0} { puts "RESULT: ALL PASS (headless A+B; GUI skipped — needs Tk/X)" } else { puts "RESULT: $fail FAILED" }
  flush stdout
  exit [expr {$fail == 0 ? 0 : 1}]
}

# capture ciw_echo (may be absent in some modes); define a capturing stub
set ::echoed {}
set had_echo [llength [info commands ciw_echo]]
if {$had_echo} { rename ciw_echo ciw_echo_orig }
proc ciw_echo {line {tag {}}} { lappend ::echoed $line }

# count live C updates around the staged Load
set ::upd 0
rename xschem xschem_real
proc xschem {args} {
  if {[lindex $args 0] eq {update_net_hilight_style}} { incr ::upd }
  return [eval [linsert $args 0 xschem_real]]
}

# A 2-row starting table, distinct from the file we will load
set start {{0 4 1 {} 0 0 none 0} {1 3 1 {} 0 0 none 0}}
set ::net_hilight_style $start
catch {xschem update_net_hilight_style}
catch {destroy .nhse}
net_hilight_style_editor ; update idletasks

check "G1 Load… button present between Apply and Save…" [expr {[winfo exists .nhse.btns.load]}] {}

# ---- Load Replace: table BECOMES the file's rows, staged (no live update) ----
set ::upd 0
nhse_load_apply $saved replace
check "G2 Load Replace: table becomes the loaded rows" [expr {[net_hilight_style_current] eq $saved}] "(=> [net_hilight_style_current])"
check "G3 Load Replace is staged (no live update)" [expr {$::upd == 0}] "(updates=$::upd)"

# ---- Load Add: loaded rows APPENDED at the end, renumbered (index == position) ----
set ::net_hilight_style $start
catch {destroy .nhse} ; net_hilight_style_editor ; update idletasks
set ::upd 0
nhse_load_apply $saved add
set t [net_hilight_style_current]
check "G4 Load Add appends (2 + 2 = 4 rows)" [expr {[llength $t] == 4}] "(=> [llength $t])"
check "G5 Load Add renumbers appended rows" \
  [expr {[lindex [lindex $t 2] 0] == 2 && [lindex [lindex $t 3] 0] == 3}] "(=> [lindex $t 2] / [lindex $t 3])"
check "G6 Load Add kept the loaded colors at the end" \
  [expr {[lindex [lindex $t 2] 1] eq {red} && [lindex [lindex $t 3] 1] eq {green}}] "(=> [lindex $t 2] / [lindex $t 3])"
check "G7 Load Add is staged (no live update)" [expr {$::upd == 0}] "(updates=$::upd)"

# ---- full nhse_load flow via stubs: file pick + Replace chooser → real nhse_load ----
set ::net_hilight_style $start
catch {destroy .nhse} ; net_hilight_style_editor ; update idletasks
rename tk_getOpenFile tk_getOpenFile_real
proc tk_getOpenFile {args} { return $::nhse_test_path }
set saved_chooser [info commands nhse_load_chooser]
rename nhse_load_chooser nhse_load_chooser_real
proc nhse_load_chooser {} { return $::nhse_test_mode }
set ::nhse_test_path $okfile
set ::nhse_test_mode replace
set ::upd 0
nhse_load
check "G8 full nhse_load (pick+Replace) sets the table" [expr {[net_hilight_style_current] eq $saved}] "(=> [net_hilight_style_current])"
check "G9 full nhse_load Replace is staged (no live update)" [expr {$::upd == 0}] "(updates=$::upd)"

# ---- "no styles" path: a file without net_hilight_style leaves the table unchanged + reports ----
set ::net_hilight_style $start
catch {destroy .nhse} ; net_hilight_style_editor ; update idletasks
rename tk_messageBox tk_messageBox_real
proc tk_messageBox {args} { return ok }
set ::echoed {}
set ::nhse_test_path $nofile
set ::upd 0
nhse_load
check "G10 no-styles Load leaves the table unchanged" [expr {[net_hilight_style_current] eq $start}] "(=> [net_hilight_style_current])"
check "G11 no-styles Load fired no live update" [expr {$::upd == 0}] "(updates=$::upd)"
check "G12 no-styles Load reported via CIW" [expr {[string match {*no net highlight styles found*} [lindex $::echoed end]]}] "(=> [lindex $::echoed end])"

# restore stubs
rename tk_messageBox {} ; rename tk_messageBox_real tk_messageBox
rename tk_getOpenFile {} ; rename tk_getOpenFile_real tk_getOpenFile
rename nhse_load_chooser {} ; rename nhse_load_chooser_real nhse_load_chooser
rename xschem {} ; rename xschem_real xschem
rename ciw_echo {}
if {$had_echo} { rename ciw_echo_orig ciw_echo }

catch {destroy .nhse}
file delete -force $::USER_CONF_DIR
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
