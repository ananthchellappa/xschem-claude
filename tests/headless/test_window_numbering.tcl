# Cadence-style window numbering + activation logging  (doc/claude/specs/window_numbering.md)
#
# GUI smoke: opens real Tk toplevels, driven entirely by script. Needs a display.
# Standard invocation (from src/):
#   ./xschem --pipe -q --nolog --script ../tests/headless/test_window_numbering.tcl
#
# RED-first: checks map 1:1 to the spec acceptance list WN1..WN7. Every check is
# expected to FAIL (not crash) until the feature lands. Model:
#   CIW = window 1, Library Manager = window 2, editor contexts = 3,4,5,... monotonic.

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}

set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {name} { global repo; return [file join $repo xschem_library examples $name] }
set sch1 [ex nand2.sch]
set sch2 [ex dlatch.sch]
set sch3 [ex flop.sch]

# --- helpers (defensive: return sentinels pre-implementation so RED = FAIL not crash) ---
proc cur_num {} { if {[catch {xschem get window_number} n]} { return -1 }; return $n }
proc win_entry {pat} {
  if {[catch {xschem windows} wl]} { return {} }
  foreach e $wl { if {[string match $pat [lindex $e 4]]} { return $e } }
  return {}
}
proc win_num_by {pat} { set e [win_entry $pat]; if {$e eq {}} { return {} }; return [lindex $e 5] }
# Reset to a single main context. destroy_all only clears the current MODE's extras
# (tabs in tabbed mode), so real windows left over from an earlier mixed phase must be
# torn down explicitly, else the next create_window/create collides on ".xN".
proc clean_slate {} {
  for {set k 1} {$k <= 8} {incr k} {
    if {[winfo exists .x$k.drw]} { catch {xschem new_schematic destroy .x$k.drw {}} }
  }
  catch {xschem new_schematic destroy_all {}}
  update idletasks
}

# ---------------------------------------------------------------------------
# WN1 — startup main context is window 3 (must run before any window is created)
catch {xschem new_schematic destroy_all {}}
xschem load $sch1
update idletasks
check "WN1 startup main context is window 3" [expr {[cur_num] == 3}] "(=> [cur_num])"

# WN2 — `xschem windows` carries the number as a 6th field
set wl {}
catch {xschem windows} wl
check "WN2 windows entry carries the number (6th field == 3)" \
  [expr {[llength $wl] == 1 && [lindex [lindex $wl 0] 5] == 3}] "(=> {$wl})"

# WN3 — a new window gets the next number (main+1 == 4, the first create)
set ::tabbed_interface 1
catch {xschem new_schematic create_window .x1 $sch2}
update idletasks
set nMain [win_num_by *nand2*]
set nWin  [win_num_by *dlatch*]
check "WN3 new window gets the next number (main+1)" \
  [expr {$nMain == 3 && $nWin == 4}] "(main=$nMain new=$nWin)"

# WN4 — monotonic, never reused: open 4, open 5, close 4, reopen -> 6 (not 4)
catch {xschem new_schematic create_window .x2 $sch3}
update idletasks
set nA [win_num_by *dlatch*]   ;# 4
set nB [win_num_by *flop*]     ;# 5
catch {xschem new_schematic destroy .x1.drw {}}   ;# close window 4 (fresh load => no dialog)
update idletasks
catch {xschem new_schematic create_window .x1 $sch2}   ;# reopen -> next number, NOT 4
update idletasks
set nC [win_num_by *dlatch*]
check "WN4 numbers keep incrementing, never reused after close" \
  [expr {$nA == 4 && $nB == 5 && $nC == 6}] "(A=$nA B=$nB C=$nC)"

# WN5 — detach preserves the context's number (moved, not recreated)
clean_slate
xschem load $sch1
set ::tabbed_interface 1
catch {xschem new_schematic create {} $sch2}   ;# a TAB (shares main canvas)
update idletasks
set nBefore [win_num_by *dlatch*]
set te [win_entry *dlatch*]
set tabwin [lindex $te 0]
catch {xschem new_schematic detach $tabwin}
update idletasks
set nAfter [win_num_by *dlatch*]
check "WN5 detach preserves the context's number" \
  [expr {$nBefore ne {} && $nBefore ne {} && $nAfter == $nBefore}] "(before=$nBefore after=$nAfter)"

# WN6 — loading a different file into an existing window keeps its number (D3)
clean_slate
xschem load $sch1
update idletasks
set n1 [cur_num]        ;# main = 3
xschem load $sch2       ;# different file, SAME (main) context
update idletasks
set n2 [cur_num]
check "WN6 loading a new file into a window keeps its number" \
  [expr {$n1 == 3 && $n2 == 3}] "(before=$n1 after=$n2)"

# WN7 — notify_window_active dedupes repeats and logs each change; CIW=1, LibMgr=2.
# Stub ciw_echo to capture, independent of whether the CIW toplevel is open.
if {[llength [info commands notify_window_active]] == 0} {
  check "WN7 notify_window_active dedupes + reserved numbers 1/2" 0 "(proc notify_window_active missing)"
} else {
  set ::captured {}
  rename ciw_echo __real_ciw_echo
  proc ciw_echo {line {tag {}}} { lappend ::captured $line }
  catch {unset ::last_active_window}
  notify_window_active 3 nand2.sch
  notify_window_active 3 nand2.sch          ;# duplicate -> suppressed
  notify_window_active 1 CIW
  notify_window_active 2 {Library Manager}
  notify_window_active 3 nand2.sch          ;# changed again -> logs
  rename ciw_echo {}
  rename __real_ciw_echo ciw_echo
  check "WN7 notify_window_active dedupes + reserved numbers 1/2" \
    [expr {[llength $::captured] == 4 && \
           [string match {*window 1 activated*} [lindex $::captured 1]] && \
           [string match {*window 2 activated*} [lindex $::captured 2]]}] \
    "(captured=$::captured)"
}

# WN8 — the window number shows in the title bar as [N] (needs X: title set via wm title)
clean_slate
xschem load $sch1
update idletasks
set t3 [wm title .]
set n3 [cur_num]
set ::tabbed_interface 1
catch {xschem new_schematic create_window .x1 $sch2}
update idletasks
set t4 [wm title .x1]
set n4 [win_num_by *dlatch*]
check "WN8 title bar shows the window number as \[N\]" \
  [expr {[string first "\[$n3\]" $t3] >= 0 && $n4 ne {} && [string first "\[$n4\]" $t4] >= 0}] \
  "(main='$t3' n=$n3 | win='$t4' n=$n4)"

catch {xschem new_schematic destroy_all {}}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
