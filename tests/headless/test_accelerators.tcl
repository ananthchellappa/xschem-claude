# Integration smoke for the data-driven keyboard accelerators (Phase 2).
# Run under X with --pipe:
#   DISPLAY=:0 ./src/xschem --pipe --script tests/headless/test_accelerators.tcl
#
# Proves, for each migrated key, that (1) the generator installed a binding on
# the drawing canvas carrying the table's command, and (2) plain-key bindings
# include the action_key_unmodified guard so modifier variants reach C.
update idletasks
focus -force .drw
update idletasks

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}

# Expected (sequence -> command) for migrated rows. Esc is NOT listed here because
# XK_Escape in C calls abort_operation(), not just xschem redraw, so it is
# intentionally kept in C and must not appear as a Tk binding.
set expect {
  <Key-u>           {xschem undo; xschem redraw}
  <Shift-Key-U>     {xschem redo; xschem redraw}
  <Shift-Key-Z>     {xschem zoom_in}
  <Control-Key-z>   {xschem zoom_out}
  <Key-n>           {xschem netlist -erc}
  <Shift-Key-T>     {xschem toggle_ignore}
  <Shift-Key-S>     {xschem change_elem_order -1}
  <Key-x>           {xschem new_process}
  <Key-j>           {xschem print_hilight_net 1}
  <Alt-Shift-Key-J> {xschem print_hilight_net 2}
  <Key-k>           {xschem hilight}
  <Shift-Key-K>     {xschem unhilight_all}
  <Key-numbersign>  {xschem check_unique_names 0}
  <Key-equal>       {tclcmd}
  <Key-ampersand>   {xschem trim_wires}
  <Key-exclam>      {xschem break_wires}
}

# 1) bindings installed and carry the right command
foreach {seq cmd} $expect {
  set b [bind .drw $seq]
  check "binding $seq" [expr {$b ne {} && [string first $cmd $b] >= 0}] \
    "=> [string trim $b]"
}

# 2) Plain-key bindings must include the modifier guard (action_key_unmodified),
#    but modifier-specific bindings (Ctrl+, Alt+) must NOT have the guard.
set plain_keys {<Key-u> <Key-n> <Key-x> <Key-j> <Key-k> <Key-numbersign> <Key-equal> <Key-ampersand> <Key-exclam>}
set mod_keys   {<Control-Key-z> <Shift-Key-U> <Shift-Key-Z> <Shift-Key-T> <Shift-Key-S> <Shift-Key-K>}
foreach seq $plain_keys {
  set b [bind .drw $seq]
  check "plain-key $seq has modifier guard" \
    [expr {$b ne {} && [string first {action_key_unmodified} $b] >= 0}] \
    "=> [string range $b 0 60]..."
}
foreach seq $mod_keys {
  set b [bind .drw $seq]
  check "mod-key $seq has NO modifier guard" \
    [expr {$b ne {} && [string first {action_key_unmodified} $b] < 0}] \
    "=> [string range $b 0 60]..."
}

# view_zoom/view_unzoom multiply 'zoom' by a constant factor per call, so the
# key press and the direct command must apply the SAME ratio. (There is no
# 'xschem set zoom' to reset, so compare consecutive ratios instead.)
proc approx_eq {a b} { return [expr {abs($a - $b) < 1e-9 * (abs($a) + 1)}] }

# 3) zoom in
set z0 [xschem get zoom]
event generate .drw <Shift-Key-Z> ; update idletasks ; set z1 [xschem get zoom]
xschem zoom_in ; set z2 [xschem get zoom]
set r_key [expr {$z1 / $z0}]
set r_cmd [expr {$z2 / $z1}]
check "zoom_in key effect" [expr {$r_key < 1.0 && [approx_eq $r_key $r_cmd]}] \
  "(ratio key=$r_key cmd=$r_cmd)"

# 4) zoom out
set zo0 [xschem get zoom]
event generate .drw <Control-Key-z> ; update idletasks ; set zo1 [xschem get zoom]
xschem zoom_out ; set zo2 [xschem get zoom]
set ro_key [expr {$zo1 / $zo0}]
set ro_cmd [expr {$zo2 / $zo1}]
check "zoom_out key effect" [expr {$ro_key > 1.0 && [approx_eq $ro_key $ro_cmd]}] \
  "(ratio key=$ro_key cmd=$ro_cmd)"

# 5) undo / redo: create a wire, then drive undo+redo from the keyboard
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

# 6) Esc MUST NOT have a specific Tk binding (abort_operation must reach C).
check "Escape not stolen from C" [expr {[bind .drw <Key-Escape>] eq {}}] {}

# 7) un-migrated keys must NOT have a specific binding, so they still reach the
# generic <KeyPress> -> C dispatcher unchanged.
foreach k {f F s w} {
  check "unmigrated <Key-$k> left to C" [expr {[bind .drw <Key-$k>] eq {}}] {}
}

# 8) Verify modifier variants of migrated plain keys are NOT stolen from C.
# Each of these should have NO specific Tk binding.
foreach {key desc} {
  <Control-Key-u>    {Ctrl+U: unselect_attached_floaters}
  <Alt-Key-u>        {Alt+U: align-to-grid}
  <Control-Key-n>    {Ctrl+N: clear schematic}
  <Control-Key-x>    {Ctrl+X: cut}
  <Alt-Key-x>        {Alt+X: toggle crosshair}
  <Control-Key-j>    {Ctrl+J: create ipins from highlight nets}
  <Alt-Key-k>        {Alt+K: select whole net}
  <Control-Shift-Key-K> {Ctrl+Shift+K: propagate hilight}
  <Control-Key-numbersign> {Ctrl+#: rename duplicate instance names}
  <Control-Key-exclam>     {Ctrl+!: remove wires running through selected inst pins}
} {
  check "no Tcl binding for $desc" [expr {[bind .drw $key] eq {}}] {}
}

# 9) Shift-letter keys (e.g. <Shift-Key-Z>) are explicitly bound without the guard
foreach seq {<Shift-Key-Z> <Shift-Key-T> <Shift-Key-S> <Shift-Key-K>} {
  set b [bind .drw $seq]
  if {$b ne {}} {
    check "Shift-letter $seq has NO modifier guard" \
      [expr {[string first {action_key_unmodified} $b] < 0}] "=> [string range $b 0 80]..."
  }
}

if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
