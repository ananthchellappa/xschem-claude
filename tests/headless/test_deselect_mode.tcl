# Deselect-one-at-a-time mode  (doc/claude/specs/deselect_one_mode.md,
# plan doc/claude/suggestions/plan_deselect_one_mode.md).
#
# End state: `d` is no longer a hardcoded `case 'd'` deselect; it is the registered
# action `edit.deselect_mode`, bound by default to key 100 (canvas, idle). Entering
# the mode (with a selection) sets the DESEL_MODE ui_state bit; each click deselects
# the object under the cursor (selected -> removed; unselected / empty -> nothing) and
# STAYS in the mode; ESC exits and KEEPS the remaining selection. The old single-shot
# DESEL_CLICK machinery is gone.
#
# RED-first: the checks below are expected to FAIL against current code and go GREEN as
# the phases land. State checks (DM1-DM6) run anywhere; behavioral checks (DM7-DM10)
# run only when a GUI/DISPLAY is present (driven via focus-independent `xschem callback`).
# Run from the repo ROOT:
#   state only:    ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_deselect_mode.tcl
#   full (GUI):    DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_deselect_mode.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]

set DESEL_MODE 4194304   ;# ui_state bit 22

# A dump row is "device code mods ctx action_id[ idle]" (code_name prints the keysym
# number for keys; mods_name prints 0 / ctrl / ...).
proc dump_row {dev code mods ctx act} {
  foreach row [xschem bindings dump] {
    if {[lindex $row 0] eq $dev && [lindex $row 1] eq $code && [lindex $row 2] eq $mods \
        && [lindex $row 3] eq $ctx && [lindex $row 4] eq $act} { return $row }
  }
  return {}
}

# --- DM1 : the action id is registered (bindable) ----------------------------------
set bindable [expr {![catch {xschem bind key 222 0 canvas edit.deselect_mode}]}]
if {$bindable} { catch {xschem unbind key 222 0 canvas} }
check "DM1 edit.deselect_mode is a registered, bindable action" $bindable {}

# --- DM2 : plain startup binds key 100 (d) -> edit.deselect_mode, idle, canvas ------
set row [dump_row key 100 0 canvas edit.deselect_mode]
check "DM2 default binding d(100)->edit.deselect_mode present" [expr {$row ne {}}] "($row)"
check "DM2b default binding is idle-gated" [expr {[lindex $row 5] eq "idle"}] "($row)"

# --- DM3 / DM4 : mode entry is gated on a current selection ------------------------
xschem clear force
xschem instance devices/res.sym 0    0 0 0 {name=R1}
xschem instance devices/res.sym 400  0 0 0 {name=R2}
xschem unselect_all
catch {xschem deselect_mode}   ;# subcommand may not exist yet (RED)
check "DM4 deselect_mode with nothing selected is a no-op (bit clear)" \
  [expr {([xschem get ui_state] & $DESEL_MODE) == 0}] "(ui_state [xschem get ui_state])"

xschem select_all
set sel0 [xschem get lastsel]
catch {xschem deselect_mode}
check "DM3 deselect_mode with a selection sets DESEL_MODE" \
  [expr {([xschem get ui_state] & $DESEL_MODE) != 0}] "(ui_state [xschem get ui_state])"

# --- DM5 : source migration (old hardcoded path / DESEL_CLICK gone) ----------------
set fd [open [file join $repo src callback.c] r]; set csrc [read $fd]; close $fd
check "DM5a callback.c no longer mentions DESEL_CLICK" \
  [expr {![regexp {DESEL_CLICK} $csrc]}] {}
check "DM5b callback.c registers edit.deselect_mode" \
  [expr {[regexp {edit\.deselect_mode} $csrc]}] {}

# --- DM6 : CSV metadata present ----------------------------------------------------
set fd [open [file join $repo src keybindings.csv] r]; set kb [read $fd]; close $fd
check "DM6a keybindings.csv has the d row" \
  [expr {[regexp {(?m)^key,100,0,canvas,edit\.deselect_mode} $kb]}] {}
set fd [open [file join $repo src actions.csv] r]; set ac [read $fd]; close $fd
check "DM6b actions.csv has the edit.deselect_mode row" \
  [expr {[regexp {(?m)^edit\.deselect_mode,} $ac]}] {}

# --- DM7-DM10 : behavioral (GUI only) ----------------------------------------------
set gui [expr {![catch {winfo exists .drw} r] && $r}]
if {!$gui} {
  puts "note: DM7-DM10 (click/ESC behavior) skipped -- no GUI/.drw (run under DISPLAY)"
} else {
  # world -> screen: screen = (world + origin) / zoom   (X_TO_SCREEN, no tk_scaling)
  xschem unselect_all
  xschem zoom_full
  update idletasks
  proc inst_center {name} {
    if {![regexp {Instance: ([-0-9.eE]+) ([-0-9.eE]+) ([-0-9.eE]+) ([-0-9.eE]+)} \
          [xschem instance_bbox $name] -> x1 y1 x2 y2]} { return {} }
    return [list [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]]
  }
  proc w2s {wx wy} {
    set zoom [xschem get zoom]
    list [expr {round(($wx + [xschem get xorigin]) / $zoom)}] \
         [expr {round(($wy + [xschem get yorigin]) / $zoom)}]
  }
  proc clickat {mx my} { xschem callback .drw 4 $mx $my 0 1 0 0; update idletasks }
  proc keyfire {keysym} { xschem callback .drw 2 100 100 $keysym 0 0 0; update idletasks }

  xschem select_all
  set n0 [xschem get lastsel]
  check "DM7a two instances selected" [expr {$n0 == 2}] "(lastsel $n0)"

  keyfire 100   ;# 'd' enters deselect mode
  check "DM7b key d enters DESEL_MODE" \
    [expr {([xschem get ui_state] & $DESEL_MODE) != 0}] "(ui_state [xschem get ui_state])"
  check "DM7c entering the mode keeps the selection" [expr {[xschem get lastsel] == 2}] \
    "(lastsel [xschem get lastsel])"

  lassign [inst_center R1] cx cy
  lassign [w2s $cx $cy] mx my
  clickat $mx $my
  check "DM8 click on selected R1 deselects it" [expr {[xschem get lastsel] == 1}] \
    "(lastsel [xschem get lastsel] click $mx $my)"
  check "DM8b mode persists after a deselect click" \
    [expr {([xschem get ui_state] & $DESEL_MODE) != 0}] "(ui_state [xschem get ui_state])"

  # empty space: a world point far from both instances
  lassign [w2s $cx [expr {$cy + 5000}]] ex ey
  clickat $ex $ey
  check "DM9 click on empty space is a no-op" [expr {[xschem get lastsel] == 1}] \
    "(lastsel [xschem get lastsel])"
  check "DM9b mode still active after empty click" \
    [expr {([xschem get ui_state] & $DESEL_MODE) != 0}] "(ui_state [xschem get ui_state])"

  keyfire 65307  ;# ESC
  check "DM10 ESC exits the mode" \
    [expr {([xschem get ui_state] & $DESEL_MODE) == 0}] "(ui_state [xschem get ui_state])"
  check "DM10b ESC keeps the remaining selection" [expr {[xschem get lastsel] == 1}] \
    "(lastsel [xschem get lastsel])"
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
