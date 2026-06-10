# Proves keyboard shortcuts are genuinely DATA-DRIVEN at the Tk-event level: a
# runtime `xschem bind` re-targets what a physical key press does (Phase 3d.5a —
# the Phase-2 Tcl-intercept remap this test used to cover is retired; remapping
# is now a C-binding-table edit, persistable via keybindings.csv, which
# test_bindings_file covers). Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_remap.tcl
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# Default: physical Shift+Z (keysym Z, mods 0 — letters fold Shift into the
# keysym) zooms IN via the table row seeded in init_input_bindings.
check "default Z row -> view.zoom_in" \
  [expr {[lsearch -exact [xschem bindings dump] {key 90 0 canvas view.zoom_in}] >= 0}] {}
set z0 [xschem get zoom]
event generate .drw <Shift-Key-Z> ; update idletasks
set z1 [xschem get zoom]
check "default Shift+Z zooms in" [expr {$z1 < $z0}] "(z0=$z0 z1=$z1)"

# Remap the SAME physical key to the opposite action at runtime; its effect flips.
xschem bind key 90 0 canvas view.zoom_out
event generate .drw <Shift-Key-Z> ; update idletasks
set z2 [xschem get zoom]
check "remapped Shift+Z zooms OUT" [expr {$z2 > $z1}] "(z1=$z1 z2=$z2)"

# Restore the default row; the effect follows back.
xschem bind key 90 0 canvas view.zoom_in
event generate .drw <Shift-Key-Z> ; update idletasks
set z3 [xschem get zoom]
check "restored Shift+Z zooms in again" [expr {$z3 < $z2}] "(z2=$z2 z3=$z3)"

# The Phase-2 machinery is gone (deleted at 3d.5b): no proc, no Tk shadow.
check "Phase-2 accel machinery deleted" \
  [expr {[info procs bind_accelerators_from_table] eq {} &&
         [info procs remap_action_accel] eq {} &&
         ![info exists migrated_action_ids]}] {}
check "no Tk shadow on <Shift-Key-Z>" [expr {[bind .drw <Shift-Key-Z>] eq {}}] {}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
