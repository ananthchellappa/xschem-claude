# Cadence-style modifier-drag on objects, gated on cadence_compat.
# Spec: doc/claude/specs/cadence_modifier_drag.md.
#   plain LMB drag  -> attached move (wires follow), independent of enable_stretch
#   Ctrl  + drag    -> detached move (wires left behind)
#   Shift + drag    -> copy
# Plus: cadence_compat FORCES the intuitive interface (Phase 0).
#
# Drives the REAL press-on-object dispatch (handle_button_press direct-drag block,
# callback.c) via `xschem callback` -- NOT the `xschem move_objects`/`copy_objects`
# command path (which is MENUSTART and bypasses the modifier logic).
#
# MUST run from the repo ROOT under X (the nand2.sch fixture path is CWD-relative):
#   DISPLAY=:0 ./src/xschem --pipe -q --script tests/headless/test_cadence_drag.tcl
update idletasks
focus -force .drw
update idletasks

set ::fails 0
proc check {name ok} {
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name"; flush stdout
  if {!$ok} {incr ::fails}
}

# X11 event/mask constants
set BP 4 ; set BR 5 ; set MOTION 6
set ShiftMask 1 ; set ControlMask 4 ; set Button1Mask 256

# schematic -> screen pixel:  s_screen = (s_sch + origin) / zoom   (X_TO_SCREEN inverse)
proc screen {sx sy} {
  set xo [xschem get xorigin]; set yo [xschem get yorigin]; set zm [xschem get zoom]
  list [expr {int(($sx+$xo)/$zm)}] [expr {int(($sy+$yo)/$zm)}]
}
# screen point of the CENTER of instance n's bbox (reliably on the body; a symbol's
# placement anchor can sit at a pin tip or in empty space, missing the body)
proc inst_screen {n} {
  xschem unselect_all; xschem select instance $n
  lassign [xschem get bbox_selected] x1 y1 x2 y2
  xschem unselect_all
  screen [expr {($x1+$x2)/2.0}] [expr {($y1+$y2)/2.0}]
}
proc inst_pos {n} { lrange [xschem instance_coord $n] 2 3 }
proc allwires {} {
  set L {}; set nw [xschem get wires]
  for {set i 0} {$i < $nw} {incr i} { lappend L [xschem wire_coord $i] }
  return $L
}
proc wires_moved {before after} {
  set m 0; foreach b $before a $after { if {$b ne $a} { incr m } }; return $m
}
# a Button1 drag from (x1,y1) to (x2,y2) holding modifier mask `mod`
proc drag1 {x1 y1 x2 y2 mod} {
  global BP BR MOTION Button1Mask
  xschem callback .drw $BP     $x1 $y1 0 1 0 $mod
  xschem callback .drw $MOTION $x2 $y2 0 0 0 [expr {$Button1Mask | $mod}]
  xschem callback .drw $BR     $x2 $y2 0 1 0 [expr {$Button1Mask | $mod}]
  update idletasks
}
# reload the fixture with given settings; returns nothing
proc setup {cadence stretch intuitive} {
  xschem load xschem_library/examples/nand2.sch
  set ::persistent_command 0
  set ::intuitive_interface $intuitive; xschem set intuitive_interface $intuitive
  set ::enable_stretch $stretch
  set ::cadence_compat $cadence
  xschem zoom_full
  update idletasks
}

set GATE 12   ;# nand2 instance 12 (m2): a gate with 3 attached wires (probed)
set BARE 0    ;# instance 0: moves, carries no wire (probed) -> isolates "did it move"

# === Phase 2 — Shift+drag = COPY ==========================================
setup 1 1 1
check "fixture has instances" [expr {[xschem get instances] > 0}]
xschem unselect_all
lassign [inst_screen 0] sx sy
xschem callback .drw $BP $sx $sy 0 1 0 0
xschem callback .drw $BR $sx $sy 0 1 0 $Button1Mask
update idletasks
check "plain click selects instance 0" [expr {[xschem get lastsel] == 1}]
xschem unselect_all
set i0 [xschem get instances]
lassign [inst_screen 0] sx sy
drag1 $sx $sy [expr {$sx+40}] [expr {$sy+40}] $ShiftMask
check "Shift+drag duplicates the instance (copy)" [expr {[xschem get instances] == $i0 + 1}]

# === Phase 0 — cadence_compat forces the intuitive interface ==============
# intuitive_interface OFF but cadence_compat ON: a plain press-drag must still
# start a move (the direct-drag block is gated on the effective intuitive flag).
setup 1 1 0
set p0 [inst_pos $BARE]
lassign [inst_screen $BARE] sx sy
drag1 $sx $sy [expr {$sx+30}] [expr {$sy+30}] 0
check "forced intuitive: plain drag moves the instance (intuitive_interface=0)" \
  [expr {[inst_pos $BARE] ne $p0}]

# === Phase 3 — plain drag = attached move, INDEPENDENT of enable_stretch ===
# cadence_compat ON, enable_stretch OFF: a plain drag of a wired gate must carry
# its attached wires. Stock code with enable_stretch=0 leaves them behind (RED).
setup 1 0 1
set before [allwires]
set p0 [inst_pos $GATE]
lassign [inst_screen $GATE] sx sy
drag1 $sx $sy [expr {$sx+30}] [expr {$sy+30}] 0
check "plain drag moves the gate" [expr {[inst_pos $GATE] ne $p0}]
check "plain drag carries attached wires (enable_stretch=0)" \
  [expr {[wires_moved $before [allwires]] > 0}]

# === Phase 4 — Ctrl+drag = detached move (wires left behind) ==============
# Same gate, Ctrl held: instance moves, NO wire follows, count unchanged.
setup 1 1 1
set before [allwires]
set p0 [inst_pos $GATE]
set i0 [xschem get instances]
lassign [inst_screen $GATE] sx sy
drag1 $sx $sy [expr {$sx+30}] [expr {$sy+30}] $ControlMask
check "Ctrl+drag moves the gate" [expr {[inst_pos $GATE] ne $p0}]
check "Ctrl+drag leaves wires behind (detached)" \
  [expr {[wires_moved $before [allwires]] == 0}]
check "Ctrl+drag is a move not a copy (count unchanged)" \
  [expr {[xschem get instances] == $i0}]

# === Phase 5 — OFF the cadence path: stock behavior unchanged =============
# cadence_compat OFF, enable_stretch OFF: plain drag is a detached move (stock).
setup 0 0 1
set before [allwires]
set p0 [inst_pos $GATE]
lassign [inst_screen $GATE] sx sy
drag1 $sx $sy [expr {$sx+30}] [expr {$sy+30}] 0
check "non-cadence plain drag still moves the gate" [expr {[inst_pos $GATE] ne $p0}]
check "non-cadence plain drag leaves wires behind (enable_stretch=0 stock)" \
  [expr {[wires_moved $before [allwires]] == 0}]

# === Phase 6 — plain drag KISSES: abutted pins generate a connecting wire ====
# Two devices with directly coincident pins (no wire). A plain cadence drag of
# one must GENERATE a wire so the abutment connection survives -- this proves the
# production wiring (handle_button_press plain arm now sets connect_by_kissing).
# Built in-memory so the abutment is exact; driven through the same gesture path.
xschem clear force
set ::cadence_compat 1; set ::enable_stretch 1
set ::intuitive_interface 1; xschem set intuitive_interface 1
xschem instance {res.sym} 0 0 0 0 {}    ;# dev0: pin M (0,30)
xschem instance {res.sym} 0 60 0 0 {}   ;# dev1: pin P (0,30) -> abuts dev0.M, no wire
xschem zoom_full; update idletasks
check "abutment fixture starts with no wire" [expr {[xschem get wires] == 0}]
lassign [inst_screen 0] sx sy
drag1 $sx $sy [expr {$sx+30}] [expr {$sy+30}] 0
check "plain cadence drag of abutted pin GENERATES a connecting wire" \
  [expr {[xschem get wires] >= 1}]

# === Phase 7 — kissing must NOT misfire on no-motion clicks ==================
# Regression for the bug where, with cadence_compat, a Shift+drag copy drew
# spurious connecting wires. Root cause: a plain press arms connect_by_kissing,
# and a click (no motion) leaked the flag / left a degenerate stub.
# a 1px "drag" stays under the 5px motion threshold => treated as a click.
proc click1 {x y mod} {
  global BP BR Button1Mask
  xschem callback .drw $BP $x $y 0 1 0 $mod
  xschem callback .drw $BR [expr {$x+1}] [expr {$y+1}] 0 1 0 [expr {$Button1Mask | $mod}]
  update idletasks
}
set ::cadence_compat 1; set ::enable_stretch 1
set ::intuitive_interface 1; xschem set intuitive_interface 1

# 7a: a no-motion click on an abutted instance must NOT leave a stub wire, and
# must leave the instance SELECTED (the kiss abort's pop_undo clears selection;
# the click handler must re-anchor it -- regression for wired-gate click).
xschem clear force
xschem instance {res.sym} 0 0 0 0 {}
xschem instance {res.sym} 0 60 0 0 {}   ;# pins abut at (0,30)
xschem zoom_full; update idletasks
lassign [inst_screen 0] sx sy
click1 $sx $sy 0
check "no-motion click on abutted instance leaves no stub wire" \
  [expr {[xschem get wires] == 0}]
check "no-motion click on abutted (kissing) instance stays selected" \
  [expr {[xschem get lastsel] == 1}]

# 7b: click that kisses nothing must not leak the flag into a later Shift+copy
xschem clear force
xschem instance {res.sym} 500 500 0 0 {} ;# isolated: a click here kisses nothing
xschem instance {res.sym} 0 0 0 0 {}
xschem instance {res.sym} 0 60 0 0 {}    ;# abutted copy target
xschem zoom_full; update idletasks
lassign [inst_screen 0] sx sy
click1 $sx $sy 0                          ;# leaks connect_by_kissing if not reset
xschem unselect_all
lassign [inst_screen 1] sx sy
drag1 $sx $sy [expr {$sx+30}] [expr {$sy+30}] $ShiftMask
check "Shift+copy after a no-kiss click draws no spurious wire" \
  [expr {[xschem get wires] == 0}]
check "Shift+copy still duplicated the instance" \
  [expr {[xschem get instances] == 4}]

# 7c: cadence deselect-others (the path whose lastsel read we protect) still works
xschem clear force
xschem instance {res.sym} 0 0 0 0 {}
xschem instance {res.sym} 200 0 0 0 {}
xschem instance {res.sym} 400 0 0 0 {}
xschem zoom_full; update idletasks
xschem select instance 0; xschem select instance 1; xschem select instance 2
lassign [inst_screen 1] sx sy
xschem select instance 0; xschem select instance 1; xschem select instance 2
click1 $sx $sy 0
check "cadence click-to-isolate still leaves exactly one selected" \
  [expr {[xschem get lastsel] == 1}]

# --- teardown --------------------------------------------------------------
catch {destroy .ciw}; update
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
