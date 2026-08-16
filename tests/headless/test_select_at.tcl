# `xschem select_at <x> <y> [add] [nodraw]` — replayable click-select
# (doc/claude/specs/select_at.md, issue 0005). A coordinate hit-select is the
# replayable form of a mouse click: replaying the logged `select_at x y` re-runs
# find_closest_obj() and reselects the same object. Interactive clicks funnel
# through select_object() and log the same line.
#
# Needs X + --logdir (established action-log harness) -> registered in
# full_audit.sh logdir_tests. Run from the repo ROOT:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#       --script tests/headless/test_select_at.tcl
# or, gated:
#   tests/headless/run_suites.sh --logdir test_select_at
# Without the flag the FIRST check ("action log open") reds and SA5/SA6b/SA7b/SA8b
# fall with it -- 5 FAILED, for want of a log rather than for want of the
# behaviour. That is what issue 0415 was: this file was absent from logdir_tests.
#
# RED-first: on a build without select_at, the command throws (caught -> FAIL)
# and the interactive funnel logs nothing (assert fails) -- every SA check reds.

update idletasks
focus -force .drw
update idletasks

set ::fails 0
proc check {name ok {detail {}}} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name $detail"; flush stdout
  if {!$ok} { incr ::fails }
}
proc loglines {} {
  set fn [xschem get actionlog_filename]
  if {$fn eq {} || ![file exists $fn]} { return {} }
  set fd [open $fn r]; set body [read $fd]; close $fd
  return [split [string trimright $body \n] \n]
}
proc newlines {n0} { lrange [loglines] $n0 end }
proc has_select_at {n0} { expr {[lsearch -glob [newlines $n0] {xschem select_at *}] >= 0} }
# schematic -> screen pixel: screen = (sch + origin) / zoom
proc sch_to_screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set z [xschem get zoom]
  return [list [expr {int(($sx + $xo)/$z)}] [expr {int(($sy + $yo)/$z)}]]
}

check "action log open" [expr {[xschem get actionlog_filename] ne {}}]

# --- fixture: two known wires at known schematic coordinates (wires hit-test
# cleanly anywhere along the segment, unlike a symbol whose body is offset). -----
xschem clear force
xschem wire 0 0 200 0        ;# wire A, hit mid-segment at (100,0)
xschem wire 0 100 200 100    ;# wire B, hit mid-segment at (100,100)
xschem unselect_all
xschem redraw
update idletasks
set AX 100; set AY 0
set BX 100; set BY 100
check "fixture: 2 wires placed, nothing selected" \
  [expr {[llength [xschem selection]] == 0}] "(sel=[xschem selection])"

# --- SA1: command hits the object at its coordinate; return row = selection row
set rc [catch {xschem select_at $AX $AY} out]
check "SA1 select_at returns a hit row" \
  [expr {$rc == 0 && [llength $out] == 4 && [lindex $out 0] eq {wire}}] "(rc=$rc out={$out})"
# select_at returns a BARE single row; `selection` wraps each row in braces, so
# compare against the unwrapped single selection row.
check "SA1b return row matches the (unwrapped) xschem selection row" \
  [expr {$rc == 0 && [lindex [xschem selection] 0] eq $out}] "(sel=[xschem selection])"

# --- SA2: default REPLACES; `add` AUGMENTS ------------------------------------
catch {xschem select_at $BX $BY}                ;# select wire B
catch {xschem select_at $AX $AY}                ;# default => replaces with A
check "SA2 default mode replaces selection (1 selected)" \
  [expr {[llength [xschem selection]] == 1}] "(sel=[xschem selection])"
catch {xschem select_at $BX $BY add}            ;# add => now 2 selected
check "SA2b add mode augments selection (2 selected)" \
  [expr {[llength [xschem selection]] == 2}] "(sel=[xschem selection])"

# --- SA3: miss (empty space) selects nothing, returns "" ----------------------
xschem unselect_all
set rc [catch {xschem select_at 5000 5000} out]
check "SA3 miss returns empty, nothing selected" \
  [expr {$rc == 0 && $out eq {} && [llength [xschem selection]] == 0}] "(rc=$rc out={$out})"

# --- SA4: nodraw headless-safe, still updates selection ------------------------
xschem unselect_all
set rc [catch {xschem select_at $AX $AY nodraw} out]
check "SA4 nodraw selects without drawing" \
  [expr {$rc == 0 && [llength [xschem selection]] == 1}] "(rc=$rc)"

# --- SA5: command self-logs `xschem select_at x y` ----------------------------
xschem unselect_all
set n0 [llength [loglines]]
catch {xschem select_at $AX $AY}
set logged [lindex [newlines $n0] end]
check "SA5 command self-logs select_at" [string match {xschem select_at *} $logged] "(line={$logged})"

# --- SA6: replay round-trip: source the logged line -> same object reselected --
set target [xschem selection]
xschem unselect_all
check "SA6a cleared before replay" [expr {[llength [xschem selection]] == 0}] {}
catch {eval $logged}                            ;# replay the exact logged command
check "SA6b replay reselects the same object" \
  [expr {[xschem selection] eq $target}] "(want={$target} got={[xschem selection]})"

# --- SA7: a REAL click (via xschem callback) logs select_at at the funnel ------
xschem unselect_all
xschem redraw; update idletasks
set n0 [llength [loglines]]
lassign [sch_to_screen $AX $AY] mx my
xschem callback .drw 4 $mx $my 0 1 0 0        ;# ButtonPress   b1
xschem callback .drw 5 $mx $my 0 1 0 256      ;# ButtonRelease b1 (no motion)
update idletasks
check "SA7a interactive click selected the instance" \
  [expr {[llength [xschem selection]] >= 1}] "(sel=[xschem selection] screen=$mx,$my)"
check "SA7b interactive click logged select_at" [has_select_at $n0] "(new=[newlines $n0])"

# --- SA8: interactive SHIFT-click AUGMENTS and logs the ` add` marker ----------
xschem unselect_all
xschem redraw; update idletasks
lassign [sch_to_screen $AX $AY] amx amy
xschem callback .drw 4 $amx $amy 0 1 0 0        ;# plain press on wire A
xschem callback .drw 5 $amx $amy 0 1 0 256      ;# release -> A selected
update idletasks
set n0 [llength [loglines]]
lassign [sch_to_screen $BX $BY] bmx bmy
xschem callback .drw 4 $bmx $bmy 0 1 0 1        ;# ShiftMask (1) on press -> augment
xschem callback .drw 5 $bmx $bmy 0 1 0 257      ;# Button1Mask|ShiftMask on release
update idletasks
check "SA8a shift-click augments selection (2 selected)" \
  [expr {[llength [xschem selection]] == 2}] "(sel=[xschem selection])"
# the shift-click line sits in the one-action holding area (absorb spec) until
# the NEXT logged action flushes it; `set cadsnap <same>` logs a line without
# touching the selection.
xschem set cadsnap $cadsnap
check "SA8b shift-click logs 'select_at ... add'" \
  [expr {[lsearch -glob [newlines $n0] {xschem select_at * add}] >= 0}] "(new=[newlines $n0])"

if {$::fails} { puts "RESULT: $::fails FAILED" } else { puts "RESULT: ALL PASS" }
puts "OVERALL: [expr {$::fails ? {notok} : {ok}}]"
exit [expr {$::fails ? 1 : 0}]
