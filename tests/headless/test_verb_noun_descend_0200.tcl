# Verb-noun descend (doc/claude/issues/0200-descend-has-no-verb-noun-pick.md).
#
# `E` / hi_descend with NOTHING selected used to answer "select an instance to descend
# into" and stop. It now arms a one-shot canvas pick (MENUSTART|MENUSTARTDESCEND); the
# NEXT click names the instance and the chooser opens on it.
#
# The load-bearing difference from every other verb-noun arm in this codebase
# (MENUSTARTMOVE / MENUSTARTCOPY / MENUSTARTROTATE, all of which select_object() what
# they pick) is that this pick selects NOTHING: it is an argument to one command. VN6b
# and VN7b are the legs that would go red if someone "simplified" the C arm into a
# select_object() call.
#
# Drives the REAL click dispatch through `xschem callback` -> check_menu_start_commands
# -> the MENUSTARTDESCEND arm. The `E` key itself is a Tk binding (xschem.tcl
# set_bindings) that calls `hi_descend`, so the tests call that proc, exactly as the
# binding does -- `xschem callback` with keysym 'e' would reach the OLD C case 'e'.
#
# hi_descend_enum_views is stubbed to return {}: the real resolution and arming logic all
# run, and the dialog bails one line before it would create its (modal, tkwait) toplevel.
# The stub is also how the test observes WHICH instance was resolved.
#
# MUST run under X (no --nogui; `xschem callback` needs Tk):
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_verb_noun_descend_0200.tcl
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; xschem callback dispatch)"; flush stdout; exit 0 }
update idletasks
focus -force .drw
update idletasks

set ::fails 0
proc check {name got want} {
  set ok [expr {$got eq $want}]
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name (got $got want $want)"; flush stdout
  if {!$ok} {incr ::fails}
}

# X11 event types / masks
set BP 4 ; set BR 5 ; set KEY 2
set Button1Mask 256
set MENUSTART      65536
set MENUSTARTDESC  32768

proc sx {u} { expr {int(($u + [xschem get xorigin]) / [xschem get zoom])} }
proc sy {v} { expr {int(($v + [xschem get yorigin]) / [xschem get zoom])} }
proc press   {ux uy} { xschem callback .drw $::BP [sx $ux] [sy $uy] 0 1 0 0; update idletasks }
proc release {ux uy} { xschem callback .drw $::BR [sx $ux] [sy $uy] 0 1 0 $::Button1Mask; update idletasks }
proc click   {ux uy} { press $ux $uy; release $ux $uy; update idletasks }
proc armed   {} { expr {([xschem get ui_state] & $::MENUSTART) && ([xschem get ui_state2] & $::MENUSTARTDESC) ? 1 : 0} }

# Observe the resolution without ever building the modal dialog.
rename hi_descend_enum_views hi_descend_enum_views_real
proc hi_descend_enum_views {instname} { set ::resolved $instname; return {} }
rename hi_descend_pick_cancel hi_descend_pick_cancel_real
proc hi_descend_pick_cancel {} { set ::cancelled 1; hi_descend_pick_cancel_real }

xschem load [file normalize [file join [file dirname [info script]] .. .. xschem_library examples 0_examples_top.sch]]
xschem zoom_full; update idletasks

# the first subcircuit instance and the centre of its bounding box
set INST {}
foreach {i s t} [xschem instance_list] { if {$t eq {subcircuit}} { set INST $i; break } }
if {$INST eq {}} { puts "RESULT: SKIP (no subcircuit instance in the fixture)"; flush stdout; exit 0 }
lassign [lindex [split [xschem instance_bbox $INST] "\n"] 0] _ bx1 by1 bx2 by2
set CX [expr {($bx1+$bx2)/2.0}] ; set CY [expr {($by1+$by2)/2.0}]
# a second, DIFFERENT instance, for the "unrelated selection survives" leg (VN10)
set OTHER {}
foreach {i s t} [xschem instance_list] { if {$i ne $INST} { set OTHER $i; break } }

proc fresh {} {
  xschem unselect_all
  set ::resolved  {}
  set ::cancelled 0
  update idletasks
}

# --- VN1..VN3: the read-only probe ------------------------------------------
fresh
check "VN1 instance_at hits the instance"   [xschem instance_at $CX $CY] $INST
check "VN2 probe selected nothing"          [list [xschem selected_set] [xschem get lastsel]] [list {} 0]
check "VN3 instance_at on empty space"      [xschem instance_at -99999 -99999] {}

# --- VN4: the scripted name-addressed path is unchanged ---------------------
fresh
check "VN4 hi_descend inst= resolves it"    [list [hi_descend inst=$INST] $::resolved] [list 0 $INST]

# --- VN5: the verb with an empty selection ARMS instead of giving up --------
fresh
set r [hi_descend]
check "VN5a hi_descend armed"               [list $r [armed]] [list 1 1]
check "VN5b nothing resolved yet"           $::resolved {}
check "VN5c did not descend"                [xschem get currsch] 0

# --- VN6: the armed click names the instance, and selects nothing -----------
click $CX $CY
check "VN6a click resolved the instance"    $::resolved $INST
check "VN6b THE POINT: pick did not select" [list [xschem selected_set] [xschem get lastsel]] [list {} 0]
check "VN6c arm consumed"                   [armed] 0
check "VN6d schematic not modified"         [xschem get modified] 0

# --- VN7: a click on empty space cancels ------------------------------------
fresh
hi_descend
click -99999 -99999
check "VN7a cancelled"                      $::cancelled 1
check "VN7b no instance resolved"           $::resolved {}
check "VN7c arm cleared"                    [armed] 0
check "VN7d nothing selected"               [xschem selected_set] {}

# --- VN8: ESC drops the arm --------------------------------------------------
fresh
hi_descend
check "VN8a armed before ESC"               [armed] 1
xschem callback .drw $KEY 0 0 65307 0 0 0    ;# XK_Escape (decimal: C does atoi on it)
update idletasks
check "VN8b ESC disarmed"                   [armed] 0
click $CX $CY
check "VN8c post-ESC click resolved nothing" $::resolved {}

# --- VN9: noun-verb is untouched --------------------------------------------
fresh
xschem select instance $INST fast
set r [hi_descend]
check "VN9a resolved from the selection"    $::resolved $INST
check "VN9b did NOT arm a pick"             [armed] 0
check "VN9c selection still there"          [lindex [xschem selected_set] 0] $INST

# --- VN10: the pick does not disturb an existing UNRELATED selection --------
# Verb-noun only arms when nothing is selected, so this drives the arm directly.
# The pre-selected instance must be a DIFFERENT one from the one clicked: pre-selecting
# the click target would make this leg pass even if the pick selected (sabotage run,
# 2026-08-01 -- only VN6b went red until this was split).
if {$OTHER eq {}} {
  puts "ok:   VN10 skipped (fixture has only one instance)"
} else {
  fresh
  xschem select instance $OTHER fast
  set before [xschem selected_set]
  xschem descend_pick
  check "VN10a armed by the subcommand"       [armed] 1
  click $CX $CY
  check "VN10b other selection survived"      [xschem selected_set] $before
  check "VN10c picked instance not selected"  [lsearch -exact [xschem selected_set] $INST] -1
  check "VN10d and it resolved anyway"        $::resolved $INST
}

puts [expr {$::fails ? "RESULT: $::fails FAILURE(S)" : "RESULT: ALL PASS"}]
flush stdout
exit 0
