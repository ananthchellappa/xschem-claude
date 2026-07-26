# A lock=true wire was unpickable from the ASE signal picker, silently (issue 0160).
#
# `ase::ui::sod_click` opened with
#     set hit [xschem select_at $x $y]
#     if {$hit eq {}} { return }
# and `xschem select_at` selects with override_lock=0 (scheduler.c, via
# select_object), so a `lock=true` wire yields an empty hit and the click died
# right there -- before any net classification, so not even the v1-scope notice
# fired. Measured on a locked wire whose net is perfectly resolvable:
#     xschem select_at 100 0     -> {}          (nothing)
#     xschem flylines at 100 0   -> net LOCKED  (resolves fine)
#     ase::ui::sod_net_at ...    -> LOCKED
# i.e. only the SELECT step objected; the resolver never had a problem.
#
# Why the fix is NOT "pass override_lock=1": `lock` is enforced in exactly two
# files -- select.c (select_wire/_element/_text/_box/_arc/_line/_polygon) and
# findnet.c (the hit-testers). There is NO lock check in move.c, actions.c or any
# delete path. Selection IS the lock: every edit acts on the selection, so making
# a locked wire selectable would make it deletable. A read-only probe therefore
# must resolve the net WITHOUT selecting the object.
#
# So the early return moves to the BOTTOM of sod_click: classification gets its
# chance first (the flylines resolver never needed the selection), and an empty
# hit only ends the click if nothing classified. An empty-canvas click stays
# silent exactly as before -- that is the `hit eq {}` arm at the bottom.
#
# Legs (LK*):
#   LK1-LK3   fixture + the engine invariants this must NOT change: the wire is
#             locked, select_at still refuses it, flylines still resolves it.
#   LK4-LK6   the fix: a locked wire queues its net, on both pick modes, and the
#             wire is still NOT selected afterwards (lock integrity).
#   LK7-LK9   controls: an unlocked wire still queues AND selects; an
#             empty-canvas click still queues nothing; a locked wire's net still
#             takes the 0153 colour cue (hilight_netname does not honour lock).
#   LK8c-LK8d a non-source instance body still queues nothing but DOES get the
#             v1-scope notice -- the late return must not swallow it.
#   LK11-LK12 a LOCKED voltage source still queues nothing (find_closest_element
#             excludes it, so nothing resolves at its body); an unlocked one
#             still queues its current.
#   LK10      interaction with issue 0159: a locked BUS wire still goes through
#             the bit dialog.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_locked_wire_pick_0160.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_locked_pick_0160]

proc wfile {p body} { set f [open $p w]; puts $f $body; close $f }

if {[catch {

wfile [file join $scratch lk.sch] {v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 200 0 {lock=true}
N 0 100 200 100 {}
N 0 200 200 200 {lock=true}
C {devices/lab_pin} 0 0 0 0 {name=lL lab=LOCKED}
C {devices/lab_pin} 0 100 0 0 {name=lF lab=FREE}
C {devices/lab_pin} 0 200 0 0 {name=lB lab="B[1:0]"}
C {devices/res} 400 -200 0 0 {name=R9 value=1k}
C {devices/vsource} 400 300 0 0 {name=V9 value=1 lock=true}
C {devices/vsource} 700 300 0 0 {name=V8 value=1}}

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}
xschem load [file join $scratch lk.sch]

# --- LK1-LK3  fixture + the invariants this fix must NOT move -------------------
check "LK1 the fixture wire really carries lock=true" \
  [xschem getprop wire 0 lock] {true}

xschem unselect_all
check "LK2 select_at STILL refuses a locked wire (the lock is untouched)" \
  [xschem select_at 100 0] {}

set net {}
catch {set net [dict get [xschem flylines at 100 0] net]}
check "LK3 the resolver never had a problem with it" $net {LOCKED}

# --- pick harness: stub the two queues so no ASE session is needed -------------
set ::queued {}
set ::hilit  {}
proc ase::ui::dp_queue {key ex {kind {}} {token {}}} {
  lappend ::queued $ex ; lappend ::hilit $token
}
proc ase::ui::sod_queue {key ex} { lappend ::queued $ex }
proc ase::ui::bus_dialog {key token bits} { return $::bus_dialog_answer }
set ::bus_dialog_answer {}
## capture the user-visible notices: without this the "an empty-canvas click
## stays SILENT" half of the contract has no teeth (both a silent return and a
## scolding one queue nothing).
set ::notices {}
if {[info commands ciw_echo] ne {}} { rename ciw_echo real_ciw_echo }
proc ciw_echo {msg args} { lappend ::notices $msg }

# --- LK4-LK6  the fix ------------------------------------------------------------
array set ase::ui::sod [list k,flavor tobeplotted k,mode plot k,count 0]
xschem unselect_all
set ::queued {} ; set ::hilit {}
ase::ui::sod_click k 100 0
check "LK4 a locked wire now queues its net (Direct Plot)" $::queued {v(locked)}

array set ase::ui::sod [list k,flavor tobesaved k,mode outputs]
xschem unselect_all
set ::queued {}
ase::ui::sod_click k 100 0
check "LK5 ... and on the persisted Outputs path too" $::queued {v(locked)}

check "LK6 the locked wire is STILL not selected by the pick (lock intact)" \
  [xschem nets -selected] {}

# --- LK7-LK9  controls -----------------------------------------------------------
xschem unselect_all
set ::queued {}
ase::ui::sod_click k 100 100
check "LK7 (control) an unlocked wire still queues" $::queued {v(free)}
check_true "LK7b (control) ... and IS still selected, as before" \
  [expr {[llength [xschem nets -selected]] == 1}]

xschem unselect_all
set ::queued {} ; set ::notices {}
ase::ui::sod_click k 1000 1000
check "LK8 (control) an empty-canvas click still queues nothing" $::queued {}
check "LK8b (control) ... and says nothing either -- a pick mode must not scold\
 every miss-click" $::notices {}

xschem unselect_all
set ::queued {} ; set ::notices {}
ase::ui::sod_click k 400 -200
check "LK8c (control) a non-source instance body still queues nothing" $::queued {}
check_true "LK8d (control) ... but DOES get the v1-scope notice (the late return\
 must not swallow it)" \
  [expr {[llength $::notices] == 1 && [string match {ase: v1 queues source*} \
     [lindex $::notices 0]]}]

xschem unhilight_all
check "LK9 (control) the locked wire's net still takes a highlight (the 0153\
 colour cue does not honour lock)" \
  [list [xschem hilight_netname LOCKED] [xschem list_hilights]] {1 LOCKED}
xschem unhilight_all

# --- LK11-LK12  a locked SOURCE instance ------------------------------------------
# The late return means a locked vsource also falls through to sod_net_at now.
# find_closest_element excludes locked instances, so nothing should resolve at its
# body and the click must still queue nothing -- pinned rather than reasoned.
array set ase::ui::sod [list k,flavor tobesaved k,mode outputs]
xschem unselect_all
set ::queued {} ; set ::notices {}
ase::ui::sod_click k 400 300
check "LK11 a LOCKED voltage source still queues nothing" $::queued {}
xschem unselect_all
set ::queued {}
ase::ui::sod_click k 700 300
check "LK12 (control) an unlocked voltage source still queues its current" \
  $::queued {i(v8)}

# --- LK10  interaction with issue 0159 -------------------------------------------
array set ase::ui::sod [list k,flavor tobeplotted k,mode plot]
set ::bus_dialog_answer [list {B[1]} {B[0]}]
xschem unselect_all
set ::queued {}
ase::ui::sod_click k 100 200
check "LK10 a locked BUS wire still goes through the bit dialog" \
  $::queued [list {v(b[1])} {v(b[0])}]

} err]} { puts "FATAL: $err" ; incr fail }

## put the real ciw_echo back. Each test normally gets its own process, so this
## is hygiene rather than load-bearing -- but it runs on the FATAL path too
## (outside the catch), so a mid-file error cannot leave the stub installed.
if {[info commands real_ciw_echo] ne {}} {
  catch {rename ciw_echo {}}
  catch {rename real_ciw_echo ciw_echo}
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
