# Action-log coverage -- the non-instance property-edit dialogs record a
# REPLAYABLE line (issue 0063 shape setprop-allprops, issue 0071 atom 10).
#
# edit_property() (editprop.c) commits whole-prop-string edits for
# wire/rect/line/arc/poly/text + global schematic attrs + instance-via-vi, but
# logged only a dead `# property-edit <type>` marker, so a replayed session
# silently dropped every such edit. It now emits, per selected object, the
# scheduler's own replay form:
#   xschem setprop <wire|rect|line|arc|poly> <ref> allprops {prop}
#   xschem setprop instance <name> allprops {prop}          (instance-via-vi)
#   xschem set sch<X>prop {str}                              (global attrs)
#   xschem setprop text n txt_ptr {t} / size {h} {v} / allprops {p}  (3 facets)
# reading each object's COMMITTED prop back (multi-select forces
# preserve_unchanged_attrs, so per-object props differ from the dialog's one
# retval). The scheduler `allprops` arms for line/arc/poly are NEW (they had no
# setprop case at all). Shape arms do NOT self-log (bypass); the instance arm
# self-logs (slice 5) and re-emits identically on replay.
#
# A committed prop can contain NEWLINES (nand2's wire/instance props do): the
# logged line then spans physical lines inside balanced braces -- source-able as
# a whole (`info complete`), the §10/§11 accepted multiline class. So replay
# SOURCES the recorded text (like a real log replay), never line-splits it;
# command COUNTING is by physical-line-start glob (a continuation line does not
# begin with `xschem`).
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_shape_setprop_log.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}
# edit_property() early-returns without has_x -> the whole feature needs Tk.
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

set REPO [file normalize [file join [file dirname [info script]] .. ..]]
set work /tmp/atom10_shape_setprop_work.[pid]
file delete -force $work; file mkdir $work
set ::snapn 0

# a no-motion RMB release opens the context menu -> stub it (defensive)
proc context_menu {} {return 21}

proc logtext {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return $b
}
# count of physical lines matching a glob (command STARTS only: a continuation
# line of a multi-line prop does not begin with `xschem`)
proc count_in {text pat} {
  set n 0
  foreach l [split $text \n] { if {[string match $pat $l]} { incr n } }
  return $n
}
# whole-schematic text snapshot (a faithful-replay oracle: the same fixture +
# the same committed prop -> byte-identical save, like test_action_replay.sh).
# with-filename saveas is the replay form -> unlogged, so it never pollutes the log.
proc snapshot {} {
  set f [file join $::work snap.[incr ::snapn].sch]
  xschem saveas $f schematic
  set fd [open $f r]; set b [read $fd]; close $fd
  return $b
}
# replay recorded log text the way a real replay does: source it (handles a
# multi-line command via info-complete accumulation). Returns the setprop/set
# lines it appended to the live log (0 for the bypassing shape/global arms).
proc replay_added {deltatext} {
  set r0 [logtext]
  set f [file join $::work replay.[incr ::snapn].tcl]
  set fd [open $f w]; puts -nonewline $fd $deltatext; close $fd
  source $f
  set add [string range [logtext] [string length $r0] end]
  return [expr {[count_in $add {xschem setprop *}] + [count_in $add {xschem set sch*prop *}]}]
}

# The dialog stubs: text_line (x=0 shapes/global), edit_vi_prop (x=1),
# enter_text (x=0 text). Each simulates an OK that appends a distinctive token.
proc stub_commit {} {
  proc text_line {args}    { set ::tctx::rcode ok; append ::tctx::retval " atom10=1"; return $::tctx::retval }
  proc edit_vi_prop {args} { set ::tctx::rcode ok; append ::tctx::retval " atom10=1"; return $::tctx::retval }
  proc edit_vi_netlist_prop {args} { set ::tctx::rcode ok; append ::tctx::retval " atom10=1"; return $::tctx::retval }
}
proc stub_cancel {} {
  proc text_line {args}    { set ::tctx::rcode {} }
  proc edit_vi_prop {args} { set ::tctx::rcode {} }
}

# a cleared schematic with one graphical object of $kind on layer 4 at index 0.
# NB the SELECT/OBJECT type name for a polygon is "poly" (create is "polygon").
proc build_gfx {kind} {
  xschem clear force schematic
  xschem set rectcolor 4
  switch -- $kind {
    line { xschem line 0 0 100 0 }
    rect { xschem rect 300 0 400 100 }
    arc  { xschem arc 200 200 50 0 360 4 }
    poly { xschem polygon 0 0 50 50 100 0 {} }
  }
}

# Any uncaught error must NOT kill the script (a lost RESULT banner reads to
# full_audit as a hang/garbage, not a FAIL). One catch wraps every section.
if {[catch {

# ---------------------------------------------------------------------------
# T1) WIRE property edit (x=0) -> one replayable line, no marker, faithful replay.
#     nand2 wire props carry a NEWLINE, so the line is multi-line/brace-balanced.
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
stub_commit
xschem unselect_all; xschem select wire 0
set before [logtext]
xschem edit_prop
set delta [string range [logtext] [string length $before] end]
check "T1 wire edit logs exactly one setprop wire allprops line" \
  [expr {[count_in $delta {xschem setprop wire 0 allprops *}] == 1}] "delta={$delta}"
check "T1 wire edit logs NO '# property-edit' marker" \
  [expr {[count_in $delta {# property-edit*}] == 0}]
check "T1 the multi-line logged command is source-able (balanced braces)" \
  [info complete $delta]
set snapA [snapshot]
xschem load xschem_library/examples/nand2.sch
check "T1 replay reproduces the edit byte-for-byte" \
  [expr {[set add [replay_added $delta]] >= 0 && [snapshot] eq $snapA}]
check "T1 shape replay logs nothing (bypass invariant)" [expr {$add == 0}] "add=$add"

# ---------------------------------------------------------------------------
# T2..T5) graphical types rect/line/arc/poly (x=0 text_line) -- created on
#         layer 4, edited, replayed byte-identical, replay logs nothing.
# ---------------------------------------------------------------------------
foreach kind {rect line arc poly} {
  stub_commit
  build_gfx $kind
  xschem unselect_all; xschem select $kind 4 0
  set before [logtext]
  xschem edit_prop
  set delta [string range [logtext] [string length $before] end]
  check "T2-5 $kind edit logs one setprop $kind 4 0 allprops line" \
    [expr {[count_in $delta "xschem setprop $kind 4 0 allprops *"] == 1}] "delta={$delta}"
  check "T2-5 $kind edit logs no marker" [expr {[count_in $delta {# property-edit*}] == 0}]
  set snapA [snapshot]
  build_gfx $kind
  check "T2-5 $kind replay reproduces the edit byte-for-byte" \
    [expr {[set add [replay_added $delta]] >= 0 && [snapshot] eq $snapA}] "delta={$delta}"
  check "T2-5 $kind shape replay logs nothing" [expr {$add == 0}] "add=$add"
}

# ---------------------------------------------------------------------------
# T6) TEXT property edit (x=0 enter_text) -> a 3-facet bundle (txt_ptr/size/
#     allprops); replay reproduces string + INDEPENDENT scales + props.
# ---------------------------------------------------------------------------
proc build_text {} {
  xschem clear force schematic
  xschem text {hello} 100 100 0 0 0.5 0.7 {}
}
proc enter_text {args} {
  set ::tctx::rcode ok
  set ::tctx::retval {world}
  set ::tctx::hsize 0.8
  set ::tctx::vsize 0.3
  set ::props {atom10txt=1}
}
build_text
xschem unselect_all; xschem select text 0
set before [logtext]
xschem edit_prop
set delta [string range [logtext] [string length $before] end]
check "T6 text edit logs txt_ptr + size + allprops (3 lines)" \
  [expr {[count_in $delta {xschem setprop text 0 txt_ptr *}] == 1
      && [count_in $delta {xschem setprop text 0 size *}] == 1
      && [count_in $delta {xschem setprop text 0 allprops *}] == 1}] "delta={$delta}"
set sizeline [lindex [split $delta \n] [lsearch -glob [split $delta \n] {xschem setprop text 0 size *}]]
check "T6 text size line carries INDEPENDENT scales (h v)" \
  [expr {[llength $sizeline] == 7}] "line={$sizeline}"
set snapA [snapshot]
build_text
check "T6 text replay reproduces string+size+props byte-for-byte" \
  [expr {[replay_added $delta] >= 0 && [snapshot] eq $snapA}] "delta={$delta}"

# ---------------------------------------------------------------------------
# T7) MULTI-object wire edit -> one line PER selected wire, each carrying that
#     wire's own committed prop (preserve_unchanged_attrs), replay faithful.
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
stub_commit
xschem unselect_all; xschem select wire 0; xschem select wire 1 add
set before [logtext]
xschem edit_prop
set delta [string range [logtext] [string length $before] end]
check "T7 multi-select logs one line per object (2 wires -> 2 lines)" \
  [expr {[count_in $delta {xschem setprop wire 0 allprops *}] == 1
      && [count_in $delta {xschem setprop wire 1 allprops *}] == 1}] "delta={$delta}"
set snapA [snapshot]
xschem load xschem_library/examples/nand2.sch
check "T7 replaying both lines reproduces the multi-edit byte-for-byte" \
  [expr {[replay_added $delta] >= 0 && [snapshot] eq $snapA}]

# ---------------------------------------------------------------------------
# T8) GLOBAL schematic attribute edit (lastsel==0, x=1) -> `xschem set schprop`
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
stub_commit
xschem unselect_all
set before [logtext]
xschem edit_vi_prop
set delta [string range [logtext] [string length $before] end]
check "T8 global edit logs one `xschem set schprop` line (SPICE view)" \
  [expr {[count_in $delta {xschem set schprop *}] == 1}] "delta={$delta}"
check "T8 global edit logs no marker" [expr {[count_in $delta {# property-edit*}] == 0}]
set snapA [snapshot]
xschem load xschem_library/examples/nand2.sch
check "T8 replay reproduces the global edit byte-for-byte" \
  [expr {[set add [replay_added $delta]] >= 0 && [snapshot] eq $snapA}]
check "T8 global replay logs nothing (set schprop does not self-log)" [expr {$add == 0}] "add=$add"

# ---------------------------------------------------------------------------
# T9) INSTANCE via external editor (x=1) -> `setprop instance <name> allprops`
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
stub_commit
xschem unselect_all; xschem select instance 0
set iname [lindex [xschem instance_coord 0] 0]
set before [logtext]
xschem edit_vi_prop
set delta [string range [logtext] [string length $before] end]
check "T9 instance-vi edit logs one setprop instance allprops line" \
  [expr {[count_in $delta "xschem setprop instance $iname allprops *"] == 1}] "delta={$delta}"
check "T9 instance-vi edit logs no marker" [expr {[count_in $delta {# property-edit*}] == 0}]
set snapA [snapshot]
xschem load xschem_library/examples/nand2.sch
check "T9 replay reproduces the instance edit byte-for-byte" \
  [expr {[replay_added $delta] >= 0 && [snapshot] eq $snapA}]

# ---------------------------------------------------------------------------
# T9b) INSTANCE edit that RENAMES the instance (name= token changed via the vi
#      editor): the logged line must address the PRE-EDIT name -- the reloaded
#      fixture has the old name, and the setprop-instance arm re-applies the
#      rename from the new prop's name= token. Adversarial-review MAJOR: a
#      post-edit-name address logs `setprop instance <newname>` which
#      get_instance can't resolve on replay -> the edit is silently lost.
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
set ::user_wants_copy_cell 0; set ::no_change_attrs 0
set oldname [lindex [xschem instance_coord 0] 0]
proc edit_vi_prop {args} {
  set ::tctx::rcode ok
  regsub {name=[^ \n\}]+} $::tctx::retval {name=RENAMED9} ::tctx::retval
  return $::tctx::retval
}
xschem unselect_all; xschem select instance 0
set before [logtext]
xschem edit_vi_prop
set delta [string range [logtext] [string length $before] end]
check "T9b rename edit addresses the PRE-EDIT name, not the new name" \
  [expr {[count_in $delta "xschem setprop instance $oldname allprops *"] == 1
      && [count_in $delta {xschem setprop instance RENAMED9 allprops *}] == 0}] "delta={$delta}"
set snapA [snapshot]
check "T9b the instance really was renamed at record time" \
  [expr {[lindex [xschem instance_coord 0] 0] eq {RENAMED9}}]
xschem load xschem_library/examples/nand2.sch
check "T9b replay reproduces the rename byte-for-byte (old name resolves)" \
  [expr {[replay_added $delta] >= 0 && [snapshot] eq $snapA}]

# ---------------------------------------------------------------------------
# T10) CANCEL (empty rcode) commits nothing -> no line, no marker
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
stub_cancel
xschem unselect_all; xschem select wire 0
set before [logtext]
xschem edit_prop
set delta [string range [logtext] [string length $before] end]
check "T10 cancelled edit logs nothing" \
  [expr {[count_in $delta {xschem setprop *}] == 0
      && [count_in $delta {# property-edit*}] == 0}] "delta={$delta}"

# ---------------------------------------------------------------------------
# T11) VIEWDATA (x==2, `view_prop`) is view-only -> no line
# ---------------------------------------------------------------------------
proc viewdata {args} { return }
xschem unselect_all; xschem select wire 0
set before [logtext]
xschem view_prop
check "T11 view_prop (x==2) logs nothing" \
  [expr {[count_in [string range [logtext] [string length $before] end] {xschem setprop *}] == 0}]

# ---------------------------------------------------------------------------
# T12) READ-ONLY: the replay form `setprop ... allprops` is REJECTED, no mutation,
#      no line -- the important replay-safety invariant.
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
set robefore [snapshot]
xschem set readonly 1
set before [logtext]
set rc [catch {xschem setprop wire 0 allprops {ro=1}} e]
check "T12 setprop on read-only view is rejected (TCL_ERROR)" [expr {$rc != 0}] "rc=$rc"
xschem set readonly 0
check "T12 read-only setprop mutated nothing" [expr {[snapshot] eq $robefore}]
check "T12 read-only setprop logged nothing" \
  [expr {[count_in [string range [logtext] [string length $before] end] {xschem setprop *}] == 0}]

# ---------------------------------------------------------------------------
# T13) slick INSTANCE form (x==0) is EXCLUDED (it self-logs apply_properties):
#      driving edit_prop on an instance must NOT emit a setprop instance line.
# ---------------------------------------------------------------------------
xschem load xschem_library/examples/nand2.sch
proc edit_prop {args} { set ::tctx::applied 1 }   ;# stub the slick form proc (no dialog)
xschem unselect_all; xschem select instance 0
set before [logtext]
xschem edit_prop                                  ;# x==0 slick path
check "T13 slick instance form (x==0) emits NO setprop instance line (no double)" \
  [expr {[count_in [string range [logtext] [string length $before] end] {xschem setprop instance *}] == 0}]
rename edit_prop {}

# ---------------------------------------------------------------------------
# T14) whole-log sweep: the dead `# property-edit` marker never appeared
# ---------------------------------------------------------------------------
check "T14 no '# property-edit' marker anywhere in the log" \
  [expr {[count_in [logtext] {# property-edit*}] == 0}]

} ::t_err]} {
  check "uncaught error in test body" 0 $::t_err
}

file delete -force $work
puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
