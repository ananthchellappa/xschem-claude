# Issue 0457(b) — `annot_show` gets a stock View-menu control.
#
# Before this landed, EVERY writer in the stock tree turned annotation ON:
#   src/xschem.tcl  `Op Annotate`      -> xschem set annot_show 1
#   src/xschem.tcl  `Annotate Operating Point into schematic` -> same
#   src/xschem.tcl  set_ne annot_show 0   <- the startup default, not a control
# so a user who clicked either menu item could not undo it without editing
# ~/.xschem/xschemrc and restarting. The three chords do turn it off, but
# cadence_style_rc ships COMMENTED OUT at src/xschemrc:767, so a stock user has
# never had them. Ruled by the user 2026-08-22; see doc/claude/issues/0457-*.md.
#
# NEEDS A DISPLAY — the subject is Tk menu entries. Do NOT run under --nogui.
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --script \
#       tests/headless/test_annot_show_menu.tcl

if {[catch {winfo exists .}] || ![winfo exists .]} {
  puts "RESULT: SKIP (needs Tk/X; the subject is a menu)"
  flush stdout
  exit 0
}

# --- issue 0601: keep the editor's autosave "~" file out of the launch directory.
# This suite instances a resistor, and the first edit of the startup untitled
# buffer runs set_modify(1) -> write_backup() (src/actions.c:208 -> save.c:4149),
# which lands in the LAUNCH dir (a Tcl `cd` does not move it, issue 0323).
# Guarded by tests/headless/test_no_untitled_litter.tcl.
set ::saved_autosave_0601 $::autosave_backup
set ::autosave_backup 0

set fail 0
set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name ($got)" ; incr npass } \
  else { puts "FAIL: $name (got '$got' want '$want')" ; incr fail }
}

set M .menubar.view.show
set topwin ""

# ---------------------------------------------------------------- presence ---
check "A1 annot_show_menu_sync is defined"  [llength [info procs annot_show_menu_sync]]  1
check "A2 annot_show_menu_apply is defined" [llength [info procs annot_show_menu_apply]] 1
check "A3 the View>Show submenu exists"     [winfo exists $M] 1

# The two entries, and that they sit with `Show hidden texts` rather than at the
# far end of the menu -- the placement is the point (FAQ Q48 sends users there).
proc entry_index {m label} {
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {[catch {$m entrycget $i -label} l]} { continue }
    if {$l eq $label} { return $i }
  }
  return -1
}
## ⚠ A MISSING ENTRY MUST RED ONE ROW, NOT ABORT THE FILE. `$M type -1` raises
## `bad menu entry index "-1"`, and under --pipe that stops Tcl_AppInit dead:
## measured, a single renamed label took A7 out and rows A8-A18 never ran at
## all, so a one-word change read as a total collapse. These two return a marker
## instead, and the rows below name it in their goldens.
proc entry_type {m i} { if {$i < 0} { return NO-ENTRY } ; return [$m type $i] }
proc entry_var  {m i} { if {$i < 0} { return NO-ENTRY } ; return [$m entrycget $i -variable] }
# ⚠ THE SECOND LABEL CHANGED WITH ISSUE 0614, AND THE LABEL IS THE POINT.
# Bit 1 used to gate `hide=voltage` and nothing else -- a token no shipped symbol
# carried, so the box governed an empty set. Under 0614 it owns the CONTENT-
# classified annotations: every `@spice_get_voltage` / `@#n:spice_get_voltage` /
# `@spice_get_diff_voltage` node voltage AND every `@spice_get_current*` branch
# current. A control must name what it governs, so the label says both. (Decision
# D4 of that pass: the currents share this SWITCH and keep their own layer-17
# COLOUR -- see tests/headless/test_op_annot.tcl row U17.)
set i_hid [entry_index $M "Show hidden texts"]
set i_op  [entry_index $M "Show device OP annotation"]
set i_v   [entry_index $M "Show node voltage / branch current annotation"]
check "A4 'Show device OP annotation' entry exists"    [expr {$i_op >= 0}] 1
check "A5 'Show node voltage / branch current annotation' entry exists"  [expr {$i_v  >= 0}] 1
check "A6 both sit directly under 'Show hidden texts'" \
      [list [expr {$i_op - $i_hid}] [expr {$i_v - $i_hid}]] {1 2}
check "A7 both are checkbuttons, not commands" \
      [list [entry_type $M $i_op] [entry_type $M $i_v]] {checkbutton checkbutton}
check "A8 they drive the derived vars, not the mask directly" \
      [list [entry_var $M $i_op] [entry_var $M $i_v]] \
      {annot_show_op annot_show_voltage}
check "A9 the submenu re-derives on open (-postcommand)" \
      [string match {*annot_show_menu_sync*} [$M cget -postcommand]] 1

# ------------------------------------------------------------------- PULL ----
# The mask is the authority. Whoever wrote it -- a menu item, a cadence chord, a
# user's rc -- the boxes must agree the next time the menu opens.
foreach {mask want_op want_v} {0 0 0   1 1 0   2 0 1   3 1 1} {
  xschem set annot_show $mask
  set ::annot_show_op 9 ; set ::annot_show_voltage 9   ;# poison, so a no-op sync reds
  annot_show_menu_sync
  check "A10 PULL mask=$mask -> boxes" \
        [list $::annot_show_op $::annot_show_voltage] [list $want_op $want_v]
}

# ------------------------------------------------------------------- PUSH ----
foreach {op v want} {0 0 0   1 0 1   0 1 2   1 1 3} {
  set ::annot_show_op $op ; set ::annot_show_voltage $v
  annot_show_menu_apply
  check "A11 PUSH op=$op volt=$v -> mask" [xschem get annot_show] $want
}

# The mask is an INT (S7 decision D4). A Tk checkbutton may hold a non-1/0 truthy
# value; it must be normalised, never passed through as `true`/`on`/`yes`.
set ::annot_show_op true ; set ::annot_show_voltage 0
annot_show_menu_apply
check "A12 a Tk-truthy 'true' normalises to the INT 1" [xschem get annot_show] 1

# ------------------------------------------------ THE OFF-RAMP, the whole point
# Reproduce what the two `Op Annotate` menu items do, then turn it off from the
# menu. Before 0457(b) nothing in the stock tree could perform this second step.
xschem set annot_show 1
annot_show_menu_sync
check "A13 after an Op-Annotate-shaped write the OP box is ticked" $::annot_show_op 1
set ::annot_show_op 0
annot_show_menu_apply
check "A13b unticking it turns annotation OFF (the off-ramp)" [xschem get annot_show] 0

# ------------------------------------------------ the state the chords cannot reach
# 6 / Ctrl-6 / Alt-6 emit masks 1, 0 and 3 only (utils/annot_mode.tcl). The pair
# can also produce 2 -- node voltages with device OP info off. text_hidden() gates
# the two classes on separate bits, so the state is coherent and deliberate.
set ::annot_show_op 0 ; set ::annot_show_voltage 1
annot_show_menu_apply
check "A14 mask 2 is reachable from the menu (chords cannot make it)" \
      [xschem get annot_show] 2

# ------------------------------------------- 0614: THE THREE CHORDS, FROM HERE
# ⚠ GREEN BEFORE AND AFTER 0614 -- the plumbing is 0457(b)'s and it already
# works. This row is here because 0614's acceptance names it out loud ("the
# 0457(b) View-menu pair drives the same three states"), and because after 0614
# those three masks MEAN something they did not mean before:
#   op=1 v=0 -> 1  device OP blocks only, node voltages and branch currents OFF
#   op=1 v=1 -> 3  both
#   op=0 v=0 -> 0  neither
# i.e. the stock menu pair reaches every state `6` / `Alt-6` / `Ctrl-6` reach,
# for the vast majority of users whose xschemrc never sources cadence_style_rc
# (it ships commented out at src/xschemrc:767). The RENDER half of the same
# claim is test_op_annot.tcl rows U1-U6; this file owns the control surface.
set a18 {}
foreach {op v} {1 0   1 1   0 0} {
  set ::annot_show_op $op ; set ::annot_show_voltage $v
  annot_show_menu_apply
  lappend a18 [xschem get annot_show]
}
check "A18 0614 the View pair reaches the three chord states (6 / Alt-6 / Ctrl-6)" $a18 {1 3 0}

# ------------------------------------------------------------- source contract
set fh [open [file join [file dirname [info script]] .. .. src xschem.tcl] r]
set src [read $fh] ; close $fh
# S7 decision D4: writing the mask must go THROUGH `xschem set`; a bare
# `set ::annot_show N` leaves the C field stale until the next bulk sync.
check "A15 apply writes through 'xschem set annot_show'" \
      [regexp {proc annot_show_menu_apply.*?xschem set annot_show} $src] 1
check "A16 no bare 'set ::annot_show <int>' anywhere in xschem.tcl" \
      [regexp {\n\s*set ::annot_show\s+[0-9]} $src] 0
# The bbox pass is load-bearing: an annotation block changes the instance's own
# bbox (16 wide blank vs 186 wide populated, select.c:709).
check "A17 apply runs update_all_sym_bboxes" \
      [regexp {proc annot_show_menu_apply.*?update_all_sym_bboxes} $src] 1

# ------------------------------------------------------------------- cleanup --
xschem set annot_show 0
annot_show_menu_sync
set ::autosave_backup $::saved_autosave_0601   ;# issue 0601

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
