# Create Instance browser (Cadence-style Add Instance; specs/cadence_create_instance.md).
#   - `xschem create_instance` opens the .mkinst browser (Edit > Create Instance);
#     Tools > Insert symbol is gone.
#   - single window: re-launch reuses it (stable X id).
#   - 3-column Lib/Cell/View browser; View column shows only SYMBOL views.
#   - NO Create button: picking a cell+symbol-view arms placement automatically
#     (preview); a cell without a symbol view does not arm.
#   - recursion guard: a cell may not be instantiated inside its own schematic.
#   - Esc ends placement AND dismisses the form.
#   - reopening restores the last selection and re-arms it.
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
proc armed {} { return [expr {([xschem get ui_state] & 8192) != 0}] }
proc menu_cmd {m label} {
  if {![winfo exists $m]} { return "" }
  for {set i 0} {$i <= [$m index end]} {incr i} {
    if {![catch {$m entrycget $i -label} l] && $l eq $label} { return [$m entrycget $i -command] }
  }
  return ""
}
proc menu_has {m label} { return [expr {[menu_cmd $m $label] ne {}}] }
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
check "CI1d no Create button (selection arms instead)" [expr {![winfo exists .mkinst.b.create]}] {}

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

# === CI4 — auto-arm on selection + the .sym guard ===========================
xschem abort_operation
pick cell withsym mkinst::on_cell
check "CI4a withsym: symbol view listed" [expr {[.mkinst.pw.view.lb get 0 end] eq {symbol}}] "(=> [.mkinst.pw.view.lb get 0 end])"
check "CI4b withsym: selection auto-arms placement (preview)" [armed] "(=> ui_state=[xschem get ui_state])"
xschem abort_operation
pick cell schonly mkinst::on_cell
check "CI4c schonly: no symbol view listed" [expr {[.mkinst.pw.view.lb get 0 end] eq {}}] {}
check "CI4d schonly: does NOT arm" [expr {![armed]}] "(=> ui_state=[xschem get ui_state])"

# === CI5 — re-arm on switching; form stays open =============================
pick cell withsym mkinst::on_cell
check "CI5a re-arm on selecting a placeable cell" [armed] {}
check "CI5b form stays open" [winfo exists .mkinst] {}

# === CI10 — keep-placing: each drop re-arms the same symbol =================
xschem abort_operation
pick cell withsym mkinst::on_cell
check "CI10a armed (preview attached)" [armed] {}
# drop #1 (simulate a left click on the canvas: ButtonPress=4, ButtonRelease=5)
xschem callback .drw 4 300 300 0 1 0 0
xschem callback .drw 5 300 300 0 1 0 0
check "CI10b drop cleared the placement" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
mkinst::after_drop 1   ;# the canvas ButtonRelease hook re-arms
check "CI10c same symbol re-armed after drop" [armed] "(=> ui=[xschem get ui_state])"
# drop #2 -> a second placed instance, re-arm again
xschem callback .drw 4 500 500 0 1 0 0
xschem callback .drw 5 500 500 0 1 0 0
mkinst::after_drop 1
check "CI10d two instances placed (continuous)" [expr {[xschem get instances] >= 2}] "(=> inst=[xschem get instances])"
check "CI10e drop hook is wired on the canvas" [string match {*after_drop*} [bind .drw <ButtonRelease>]] {}

# === CI8 — Esc ends placement AND dismisses the form ========================
check "CI8a armed before Esc" [armed] {}
mkinst::escape
update idletasks
check "CI8b Esc cleared the placement" [expr {![armed]}] "(=> ui_state=[xschem get ui_state])"
check "CI8c Esc dismissed the form" [expr {![winfo exists .mkinst]}] {}

# === CI9 — reopen restores the last selection and re-arms ===================
xschem create_instance
update idletasks
check "CI9a reopened" [winfo exists .mkinst] {}
check "CI9b last library restored" [expr {[mkinst::cursel .mkinst.pw.lib.lb] eq {tlib}}] "(=> [mkinst::cursel .mkinst.pw.lib.lb])"
check "CI9c last cell restored" [expr {[mkinst::cursel .mkinst.pw.cell.lb] eq {withsym}}] "(=> [mkinst::cursel .mkinst.pw.cell.lb])"
check "CI9d preview re-armed on reopen" [armed] "(=> ui_state=[xschem get ui_state])"
xschem abort_operation

# === CI6 — Legacy button routes to the no-arg place_symbol dialog ============
check "CI6a Legacy button calls mkinst::legacy" [expr {[.mkinst.b.legacy cget -command] eq {mkinst::legacy}}] {}
check "CI6b mkinst::legacy uses no-arg place_symbol" \
  [expr {[string match {*xschem place_symbol*} [info body mkinst::legacy]] && \
         ![string match {*place_symbol *} [info body mkinst::legacy]]}] {}

# === CI7 — recursion guard: a cell may not be placed in its own schematic ====
xschem abort_operation
xschem load $tmp/tlib/withsym/schematic/withsym.sch
check "CI7a current schematic is withsym" \
  [expr {[file normalize [xschem get schname]] eq [file normalize $tmp/tlib/withsym/schematic/withsym.sch]}] \
  "(=> [xschem get schname])"
pick lib  tlib    mkinst::on_lib
pick cell withsym mkinst::on_cell
check "CI7b recursive selection does NOT arm" [expr {![armed]}] "(=> ui_state=[xschem get ui_state])"
check "CI7c status explains the recursion" [string match {*recursion*} [.mkinst.status cget -text]] "(=> [.mkinst.status cget -text])"
# a non-recursive cell still arms in the same schematic context
pick cell schonly mkinst::on_cell   ;# no symbol view -> still not armed, but not the recursion message
check "CI7d schonly here is rejected for lacking a symbol, not recursion" \
  [expr {![string match {*recursion*} [.mkinst.status cget -text]]}] "(=> [.mkinst.status cget -text])"
xschem abort_operation

catch {destroy .mkinst}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
