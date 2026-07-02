# GUI regression for the issue 0041 residual: the action-dispatch (keybinding) path must
# refuse a MUTATING action on a read-only buffer, while a non-mutating action still runs.
# This exercises dispatch_input_action -> action_id_mutates -> readonly_block, where
# action_id_mutates now reads the per-action `mutates` column of action_registry[]
# (callback.c) instead of a hand-maintained allowlist. The two actions driven here are
# C-BACKED (prop.toggle_ignore via Shift+T, sym.attach_net_labels via Shift+H): they do
# NOT go through the scheduler subcommand guards, so their read-only safety depends solely
# on the mutates flag -- making this the direct test of that flag.
#
# Needs a real X display (WSLg ok); has no meaning under --nogui. The read-only refusal
# pops a modal dialog, so tk_messageBox is stubbed to auto-dismiss.
#   REPO=<repo> DISPLAY=:0 src/xschem --rcfile tests/headless/minrc --pipe -q --nolog \
#       --script tests/headless/test_readonly_action_dispatch.tcl
proc tk_messageBox {args} { return ok }
update idletasks
focus -force .drw
update idletasks
set sch $env(REPO)/xschem_library/examples/Q1.sch
set fail 0
proc check {name ok detail} { global fail; if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail } }

# CONTROL: Shift+T -> prop.toggle_ignore (C-backed, mutates) on a WRITABLE buffer must mutate
xschem load $sch
xschem select_all
set m0 [xschem get modified]
event generate .drw <Shift-Key-T>; update idletasks
check "control: toggle_ignore mutates writable" [expr {$m0 == 0 && [xschem get modified] == 1}] "(modified $m0 -> [xschem get modified])"

# TREATMENT: same key on a READ-ONLY buffer must NOT mutate
xschem load $sch
xschem set readonly 1
xschem select_all
event generate .drw <Shift-Key-T>; update idletasks
check "treatment: toggle_ignore refused read-only" [expr {[xschem get modified] == 0}] "(modified=[xschem get modified])"

# TREATMENT: Shift+H -> sym.attach_net_labels (C-backed, mutates) on read-only must NOT mutate
xschem load $sch
xschem set readonly 1
xschem select_all
event generate .drw <Shift-Key-H>; update idletasks
check "treatment: attach_labels refused read-only" [expr {[xschem get modified] == 0}] "(modified=[xschem get modified])"

# NON-MUTATING action must still run on read-only: Shift+Z -> view.zoom_in
set z0 [xschem get zoom]
event generate .drw <Shift-Key-Z>; update idletasks
check "treatment: zoom_in (non-mutating) still works read-only" [expr {[xschem get zoom] != $z0}] "(zoom $z0 -> [xschem get zoom])"

if {$fail == 0} { puts "ACTION_READONLY_TEST_PASS" } else { puts "ACTION_READONLY_TEST_FAIL ($fail)" }
after 100
exit
