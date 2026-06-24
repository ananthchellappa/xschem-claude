# Integration smoke for the data-driven keyboard accelerators (Phase 2).
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_accelerators.tcl
#
# Proves, for each migrated key, that (1) the generator installed a binding on
# the drawing canvas carrying the table's command, and (2) pressing the key in
# the GUI produces the SAME observable effect as running that command directly
# (so the generated binding mirrors what the C handle_key_press chain did, and
# pre-empts it). Batch 1 keys: undo, redo, zoom in, zoom out.
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# Expected (sequence -> command) for the batch-1 migrated rows, mirroring the C
# handlers they replace. Keep in sync with migrated_action_ids in the registry.
set expect {
  <Key-u>           {xschem undo; xschem redraw}
  <Shift-Key-U>     {xschem redo; xschem redraw}
  <Shift-Key-Z>     {xschem zoom_in}
  <Control-Key-z>   {xschem zoom_out}
}

# 1) bindings installed and carry the right command
foreach {seq cmd} $expect {
  set b [bind .drw $seq]
  check "binding $seq" [expr {$b ne {} && [string first $cmd $b] >= 0}] \
    "=> [string trim $b]"
}

# view_zoom/view_unzoom multiply 'zoom' by a constant factor per call, so the
# key press and the direct command must apply the SAME ratio. (There is no
# 'xschem set zoom' to reset, so compare consecutive ratios instead.)
proc approx_eq {a b} { return [expr {abs($a - $b) < 1e-9 * (abs($a) + 1)}] }

# 2) zoom in
set z0 [xschem get zoom]
event generate .drw <Shift-Key-Z> ; update idletasks ; set z1 [xschem get zoom]
xschem zoom_in ; set z2 [xschem get zoom]
set r_key [expr {$z1 / $z0}]
set r_cmd [expr {$z2 / $z1}]
check "zoom_in key effect" [expr {$r_key < 1.0 && [approx_eq $r_key $r_cmd]}] \
  "(ratio key=$r_key cmd=$r_cmd)"

# 3) zoom out
set zo0 [xschem get zoom]
event generate .drw <Control-Key-z> ; update idletasks ; set zo1 [xschem get zoom]
xschem zoom_out ; set zo2 [xschem get zoom]
set ro_key [expr {$zo1 / $zo0}]
set ro_cmd [expr {$zo2 / $zo1}]
check "zoom_out key effect" [expr {$ro_key > 1.0 && [approx_eq $ro_key $ro_cmd]}] \
  "(ratio key=$ro_key cmd=$ro_cmd)"

# 4) undo / redo: create a wire, then drive undo+redo from the keyboard
set n0 [xschem get wires]
xschem wire 0 0 1000 0
set n1 [xschem get wires]
check "wire added" [expr {$n1 == $n0 + 1}] "(n0=$n0 n1=$n1)"
event generate .drw <Key-u> ; update idletasks   ;# undo
set n_undo [xschem get wires]
check "undo key removes wire" [expr {$n_undo == $n0}] "(=> $n_undo)"
event generate .drw <Shift-Key-U> ; update idletasks ;# redo
set n_redo [xschem get wires]
check "redo key restores wire" [expr {$n_redo == $n1}] "(=> $n_redo)"

# 5) un-migrated keys must NOT have a specific binding, so they still reach the
# generic <KeyPress> -> C dispatcher unchanged. (f=zoom full, s=simulate,
# w=wire are deliberately left in C this batch.)
foreach k {f s w} {
  check "unmigrated <Key-$k> left to C" [expr {[bind .drw <Key-$k>] eq {}}] {}
}

# Verify modifier variants of migrated keys are NOT stolen from C.
# Each of these should have NO specific Tk binding (so they fall through to <KeyPress> -> C).
foreach {key desc} {
  <Control-Key-u>    {Ctrl+U: unselect_attached_floaters}
  <Alt-Key-u>        {Alt+U: align-to-grid}
  <Control-Shift-Key-Z> {Ctrl+Shift+Z: unused, verify no binding}
} {
  check "no Tcl binding for $desc" [expr {[bind .drw $key] eq {}}] {}
}


if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
