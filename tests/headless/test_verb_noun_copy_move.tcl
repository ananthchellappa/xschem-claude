# Verb-noun (command-first) copy/move in the symbol editor (cadence_pin_name_text.md
# copy/move UX). With NOTHING selected, pressing the copy key 'c' / move key 'm' arms
# the command (MENUSTART|MENUSTARTCOPY/MOVE); the NEXT canvas click both SELECTS the
# object under the cursor AND starts the copy/move in one gesture; a further click drops.
#
# Drives the REAL key + click dispatch via `xschem callback` (handle_key_press case
# 'c'/'m' -> check_menu_start_commands -> copy_objects/move_objects), NOT the
# `xschem copy_objects` command path (that is the Edit menu MENUSTART path).
#
# Also guards the pin-vs-stub-line pick: a symbol pin's stub line crosses the pin
# centre at distance 0, so clicking the pin centre must still grab the PIN (the
# find_closest_box PINLAYER tie-break), else a centre click would copy the stub line.
#
# MUST run under X (no --nogui; `xschem callback` needs Tk):
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_verb_noun_copy_move.tcl
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

# Match the user's interactive runtime (cadence_style_rc): infix off, cadence_compat on,
# persistent command on. The verb-noun key path overrides infix_interface, so this also
# guards that the feature does not silently depend on infix being 1.
set ::infix_interface 0
set ::cadence_compat 1
set ::persistent_command 1

# X11 event types / masks
set BP 4 ; set BR 5 ; set MOTION 6 ; set KEY 2
set Button1Mask 256
set KC 99   ;# keysym 'c'
set KM 109  ;# keysym 'm'

# schematic -> screen pixel (inverse of X_TO_SCREEN: s = (u + origin) / zoom)
proc sx {u} { expr {int(($u + [xschem get xorigin]) / [xschem get zoom])} }
proc sy {v} { expr {int(($v + [xschem get yorigin]) / [xschem get zoom])} }
proc keypress {ks ux uy} { xschem callback .drw $::KEY [sx $ux] [sy $uy] $ks 0 0 0; update idletasks }
proc press {ux uy} { xschem callback .drw $::BP [sx $ux] [sy $uy] 0 1 0 0; update idletasks }
proc release {ux uy} { xschem callback .drw $::BR [sx $ux] [sy $uy] 0 1 0 $::Button1Mask; update idletasks }
proc click {ux uy} { press $ux $uy; release $ux $uy }
proc motion {ux uy} { xschem callback .drw $::MOTION [sx $ux] [sy $uy] 0 0 0 0; update idletasks }
proc pincx {} { lassign [xschem get bbox_selected] x1 y1 x2 y2; expr {($x1+$x2)/2.0} }

proc fresh_pin {nm} {
  xschem clear force symbol
  xschem add_symbol_pin 0 0 $nm in 0
  xschem zoom_full; update idletasks
  xschem unselect_all
}

# --- 1. verb-noun COPY, clicking the pin CENTRE (on the stub line) -----------
# The centre click must grab the PIN (not the stub line): a pin copy bumps rects[5]
# AND regenerates the name view, so 2 pins / 2 views; a stub-line copy would leave
# rects[5]==1.
fresh_pin AA
keypress $KC 200 200          ;# 'c' with empty selection -> arm copy
check "copy: armed MENUSTART" [expr {[xschem get ui_state] & 65536 ? 1 : 0}] 1
click 0 0                     ;# click pin centre -> select pin + pick up copy
check "copy: STARTCOPY after pick" [expr {[xschem get ui_state] & 64 ? 1 : 0}] 1
motion 40 0
motion 60 0
press 60 0                    ;# drop
release 60 0
check "copy: two pins"  [xschem get rects 5] 2
check "copy: two views" [xschem get texts]   2

# --- 2. verb-noun MOVE, clicking the pin centre -----------------------------
# Move does not change the count; the single pin must relocate by the drag delta.
fresh_pin BB
keypress $KM 200 200          ;# 'm' with empty selection -> arm move
check "move: armed MENUSTART" [expr {[xschem get ui_state] & 65536 ? 1 : 0}] 1
click 0 0                     ;# click pin centre -> select + pick up move
check "move: STARTMOVE after pick" [expr {[xschem get ui_state] & 32 ? 1 : 0}] 1
motion 40 0
motion 60 0
press 60 0                    ;# drop
release 60 0
check "move: still one pin"  [xschem get rects 5] 1
check "move: still one view" [xschem get texts]   1
xschem unselect_all; xschem select rect 5 0
check "move: pin relocated to 60" [expr {abs([pincx]-60) < 0.5 ? 1 : 0}] 1

# --- 3. empty 'c' then ESC must NOT copy anything ----------------------------
fresh_pin CC
keypress $KC 200 200          ;# arm copy
xschem abort_operation        ;# ESC equivalent
check "abort: MENUSTART cleared" [expr {[xschem get ui_state] & 65536 ? 1 : 0}] 0
click 0 0                     ;# a click now is a plain select, no copy
press 60 0 ; release 60 0     ;# (no pending copy to drop)
xschem abort_operation
check "abort: still one pin"  [xschem get rects 5] 1

# --- 4. noun-verb still works (select first, then 'c') ----------------------
fresh_pin DD
xschem select rect 5 0        ;# select the pin
keypress $KC 0 0              ;# 'c' with a selection -> immediate copy start
check "noun-verb: STARTCOPY" [expr {[xschem get ui_state] & 64 ? 1 : 0}] 1
motion 40 0
motion 60 0
press 60 0 ; release 60 0     ;# drop
check "noun-verb: two pins" [xschem get rects 5] 2

puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
exit [expr {$::fails ? 1 : 0}]
