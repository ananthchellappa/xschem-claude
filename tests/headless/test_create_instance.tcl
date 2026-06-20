# Create Instance browser (Cadence-style Add Instance; specs/cadence_create_instance.md).
#   - `xschem create_instance` opens the .mkinst browser (Edit > Create Instance);
#     Tools > Insert symbol is gone.
#   - single window: re-launch reuses it (stable X id).
#   - 3-column Lib/Cell/View browser; View column shows only SYMBOL views.
#   - the .sym guard: Create is enabled only for a cell with a symbol view.
#   - Create starts interactive placement (PLACE_SYMBOL) and the form stays open.
#   - the Legacy button routes to the no-arg place_symbol dialog.
#
# Needs X. Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_create_instance.tcl

set fail 0
proc check {name ok detail} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f txt} { file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp }
proc menu_cmd {m label} {
  if {![winfo exists $m]} { return "" }
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {![catch {$m entrycget $i -label} l] && $l eq $label} { return [$m entrycget $i -command] }
  }
  return ""
}
proc menu_has {m label} { return [expr {[menu_cmd $m $label] ne {}}] }
# select item $txt in a .mkinst listbox column and fire its handler
proc pick {col txt handler} {
  set lb .mkinst.pw.$col.lb
  set i [lsearch -exact [$lb get 0 end] $txt]
  if {$i < 0} return
  $lb selection clear 0 end; $lb selection set $i; $lb activate $i
  eval $handler
}

# --- fixture: one cell WITH a symbol view, one schematic-ONLY cell -----------
set hdr "v {xschem version=3.4.8RC file_version=1.3}"
set tmp [file join [pwd] _mkinst_[pid]]
file delete -force $tmp
touch $tmp/tlib/withsym/symbol/withsym.sym    $hdr
touch $tmp/tlib/withsym/schematic/withsym.sch $hdr
touch $tmp/tlib/schonly/schematic/schonly.sch $hdr
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# === CI1 — the command opens the window; menu surgery happened ==============
catch {destroy .mkinst}
xschem create_instance
update idletasks
check "CI1a xschem create_instance opens .mkinst" [winfo exists .mkinst] {}
check "CI1b Edit > Create Instance wired to the command" \
  [expr {[menu_cmd .menubar.edit {Create Instance}] eq {xschem create_instance}}] \
  "(=> '[menu_cmd .menubar.edit {Create Instance}]')"
check "CI1c Tools > Insert symbol removed" [expr {![menu_has .menubar.tools {Insert symbol}]}] {}

# === CI2 — single window: re-launch reuses it (same X id) ===================
set id1 [winfo id .mkinst]
xschem create_instance
update idletasks
check "CI2 single window: same X id on re-launch" \
  [expr {[winfo exists .mkinst] && [winfo id .mkinst] eq $id1}] "(=> $id1 / [winfo id .mkinst])"

# === CI3 — browser populates; View column shows only symbol views ===========
check "CI3a library pane lists tlib" [expr {[lsearch [.mkinst.pw.lib.lb get 0 end] tlib] >= 0}] {}
pick lib tlib mkinst::on_lib
check "CI3b cell pane lists both cells" \
  [expr {[lsearch [.mkinst.pw.cell.lb get 0 end] withsym] >= 0 && [lsearch [.mkinst.pw.cell.lb get 0 end] schonly] >= 0}] {}
pick cell withsym mkinst::on_cell
check "CI3c view pane shows the symbol view" [expr {[.mkinst.pw.view.lb get 0 end] eq {symbol}}] \
  "(=> [.mkinst.pw.view.lb get 0 end])"

# === CI4 — the .sym guard ===================================================
check "CI4a withsym: Create enabled" [expr {[.mkinst.b.create cget -state] eq {normal}}] {}
check "CI4b withsym: symbol view resolves to a .sym" \
  [string match {*.sym} [xschem cellview_path tlib/withsym symbol]] "(=> [xschem cellview_path tlib/withsym symbol])"
pick cell schonly mkinst::on_cell
check "CI4c schonly: no symbol view listed" [expr {[.mkinst.pw.view.lb get 0 end] eq {}}] {}
check "CI4d schonly: Create disabled" [expr {[.mkinst.b.create cget -state] eq {disabled}}] {}
check "CI4e schonly: cellview_path symbol is empty" [expr {[xschem cellview_path tlib/schonly symbol] eq {}}] {}

# === CI5 — Create starts interactive placement; form stays open =============
catch {xschem abort_operation}
pick cell withsym mkinst::on_cell
mkinst::create
check "CI5a Create starts placement (PLACE_SYMBOL bit set)" \
  [expr {([xschem get ui_state] & 8192) != 0}] "(=> ui_state=[xschem get ui_state])"
check "CI5b form stays open after Create" [winfo exists .mkinst] {}
xschem abort_operation
check "CI5c placement cleared after abort" [expr {([xschem get ui_state] & 8192) == 0}] "(=> ui_state=[xschem get ui_state])"
mkinst::create
check "CI5d can place again after abort" [expr {([xschem get ui_state] & 8192) != 0}] "(=> ui_state=[xschem get ui_state])"
xschem abort_operation

# === CI6 — Legacy button routes to the no-arg place_symbol dialog ============
# (don't invoke it -- the legacy dialog is modal; assert the wiring instead)
check "CI6a Legacy button calls mkinst::legacy" [expr {[.mkinst.b.legacy cget -command] eq {mkinst::legacy}}] {}
check "CI6b mkinst::legacy uses no-arg place_symbol" \
  [expr {[string match {*xschem place_symbol*} [info body mkinst::legacy]] && \
         ![string match {*place_symbol *} [info body mkinst::legacy]]}] {}

catch {destroy .mkinst}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
