# Create Instance (Cadence-style Add Instance; doc/claude/specs/cadence_create_instance.md).
# New two-dialog design:
#   - `xschem create_instance` opens the .ciform FORM (Edit > Create Instance);
#     Tools > Insert symbol is gone. The form has Library/Cell/View/Instance-name
#     entry fields + a Browse button. There is NO Place button.
#   - typing fields that resolve to a real .sym view arms a live placement preview;
#     a missing/blank View arms nothing (no view -> no preview -> cannot place).
#   - the Instance Name field becomes the placed instance's name= attribute.
#   - Browse opens the .mkinst Library Browser (OK / Apply / Cancel). The browser
#     is a pure selector: selecting a cell does NOT arm. Apply sends the selection
#     to the form (and re-arms) and keeps the browser open; OK sends and closes;
#     Cancel closes without sending. The View column shows only SYMBOL views.
#   - keep-placing: each canvas drop re-arms the same symbol.
#   - Esc ends placement AND dismisses both the form and the browser.
#   - reopening restores the form's fields and re-arms.
#   - recursion guard: a cell may not be instantiated inside its own (or an
#     ancestor's) schematic.
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
# fill the form fields (as if typed) and re-evaluate the preview
proc setf {l c v {i {}}} {
  set ::ciform::lib $l; set ::ciform::cell $c; set ::ciform::view $v; set ::ciform::instname $i
  ciform::arm
}
# pick a row in a browser column and run its handler
proc pick {col txt handler} {
  set lb .mkinst.pw.$col.lb
  set i [lsearch -exact [$lb get 0 end] $txt]
  if {$i < 0} return
  $lb selection clear 0 end; $lb selection set $i; $lb activate $i
  eval $handler
}

# --- fixture: a library with a sym+sch cell, a sch-only cell, and a 2-level
#     parent/child hierarchy for the ancestor-recursion test --------------------
set hdr "v {xschem version=3.4.8RC file_version=1.3}"
set tmp [file join [pwd] _mkinst_[pid]]
file delete -force $tmp
touch $tmp/tlib/withsym/symbol/withsym.sym    $hdr
touch $tmp/tlib/withsym/schematic/withsym.sch $hdr
touch $tmp/tlib/schonly/schematic/schonly.sch $hdr
# a cell with TWO symbol views, for the single-vs-multiple auto-fill rule
touch $tmp/tlib/multisym/symbol/multisym.sym     $hdr
touch $tmp/tlib/multisym/symbol_alt/multisym.sym $hdr
touch $tmp/tlib/child/symbol/child.sym     $hdr
touch $tmp/tlib/child/schematic/child.sch  $hdr
touch $tmp/tlib/parent/symbol/parent.sym   $hdr
touch $tmp/tlib/parent/schematic/parent.sch "$hdr\nC {tlib/child} 0 0 0 0 {}"
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs

# === CI1 — create_instance opens the FORM; menu surgery; field layout ========
catch {destroy .ciform}; catch {destroy .mkinst}
xschem create_instance
update idletasks
check "CI1a xschem create_instance opens .ciform" [winfo exists .ciform] {}
check "CI1b Edit > Create Instance wired to the command" \
  [expr {[menu_cmd .menubar.edit {Create Instance}] eq {xschem create_instance}}] \
  "(=> '[menu_cmd .menubar.edit {Create Instance}]')"
check "CI1c Tools > Insert symbol removed" [expr {![menu_has .menubar.tools {Insert symbol}]}] {}
check "CI1d four entry fields present" \
  [expr {[winfo exists .ciform.f.elib] && [winfo exists .ciform.f.ecell] && \
         [winfo exists .ciform.f.eview] && [winfo exists .ciform.f.einstname]}] {}
check "CI1e Browse button present" [winfo exists .ciform.f.browse] {}
check "CI1f no Place/Create button on the form" \
  [expr {![winfo exists .ciform.f.place] && ![winfo exists .ciform.b.create]}] {}

# === CI2 — single window: re-launch reuses it (same X id) ====================
set id1 [winfo id .ciform]
xschem create_instance
update idletasks
check "CI2 single window: same X id on re-launch" \
  [expr {[winfo exists .ciform] && [winfo id .ciform] eq $id1}] "(=> $id1 / [winfo id .ciform])"

# === CI3 — typed fields arm a valid symbol; no/blank view arms nothing ========
xschem clear force
xschem abort_operation
setf tlib withsym symbol
check "CI3a complete valid fields arm the preview" [armed] "(=> ui=[xschem get ui_state])"
setf tlib withsym {}
check "CI3b blank View does NOT arm (no view -> no preview)" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
check "CI3c status asks for the missing pieces" \
  [string match {*Library, Cell and View*} [.ciform.status cget -text]] "(=> [.ciform.status cget -text])"
setf tlib schonly schematic
check "CI3d a non-symbol (schematic) view does NOT arm" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
check "CI3e status explains no symbol view" \
  [string match {*no symbol view*} [.ciform.status cget -text]] "(=> [.ciform.status cget -text])"

# === CI4 — Instance Name becomes the placed instance's name= attribute ========
xschem clear force
xschem abort_operation
setf tlib withsym symbol M7
check "CI4a armed with an instance name" [armed] {}
xschem callback .drw 4 300 300 0 1 0 0
xschem callback .drw 5 300 300 0 1 0 0
update idletasks
check "CI4b an instance named M7 was placed" [expr {![catch {xschem instance_bbox M7}]}] \
  "(=> instances=[xschem get instances])"

# === CI5 — Browse opens a live-picker browser: Cancel only, no OK/Apply =======
catch {destroy .mkinst}
xschem clear force
xschem abort_operation
ciform::browse
update idletasks
check "CI5a Browse opens .mkinst" [winfo exists .mkinst] {}
check "CI5b Cancel button present" [winfo exists .mkinst.b.cancel] {}
check "CI5c no OK / Apply buttons" \
  [expr {![winfo exists .mkinst.b.ok] && ![winfo exists .mkinst.b.apply]}] {}
check "CI5d browser lists tlib" [expr {[lsearch [.mkinst.pw.lib.lb get 0 end] tlib] >= 0}] {}

# === CI6 — every selection applies to the form LIVE ==========================
pick lib tlib mkinst::on_lib
check "CI6a selecting a library fills the form's Library field" \
  [expr {$::ciform::lib eq {tlib} && $::ciform::cell eq {} && $::ciform::view eq {}}] \
  "(=> $::ciform::lib/$::ciform::cell/$::ciform::view)"
pick cell withsym mkinst::on_cell
check "CI6b View column shows only symbol views" [expr {[.mkinst.pw.view.lb get 0 end] eq {symbol}}] \
  "(=> [.mkinst.pw.view.lb get 0 end])"
check "CI6c single symbol view: clicking the cell ALSO fills the form's View" \
  [expr {$::ciform::cell eq {withsym} && $::ciform::view eq {symbol}}] \
  "(=> $::ciform::cell/$::ciform::view)"
check "CI6d a complete live selection arms the preview" [armed] "(=> ui=[xschem get ui_state])"

# === CI6e/f — multiple symbol views: cell click does NOT fill View ===========
pick cell multisym mkinst::on_cell
check "CI6e multiple symbol views listed" \
  [expr {[lsort [.mkinst.pw.view.lb get 0 end]] eq {symbol symbol_alt}}] "(=> [.mkinst.pw.view.lb get 0 end])"
check "CI6f multi-view cell leaves the form's View empty (no auto-fill)" \
  [expr {$::ciform::cell eq {multisym} && $::ciform::view eq {}}] "(=> $::ciform::cell/$::ciform::view)"
check "CI6g multi-view cell with no View chosen does NOT arm" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
pick view symbol_alt mkinst::on_view
check "CI6h clicking a View fills it and arms" \
  [expr {$::ciform::view eq {symbol_alt} && [armed]}] "(=> view=$::ciform::view ui=[xschem get ui_state])"

# === CI7 — Esc and Cancel dismiss the browser (form keeps the selection) ======
check "CI7a browser open before dismiss" [winfo exists .mkinst] {}
check "CI7b Esc on the browser is wired to mkinst::cancel" \
  [string match {*mkinst::cancel*} [bind .mkinst <Key-Escape>]] "(=> [bind .mkinst <Key-Escape>])"
check "CI7c Cancel button is wired to mkinst::cancel" \
  [expr {[.mkinst.b.cancel cget -command] eq {mkinst::cancel}}] {}
mkinst::cancel   ;# what both Esc and the Cancel button invoke
update idletasks
check "CI7d browser dismissed" [expr {![winfo exists .mkinst]}] {}
check "CI7e the form survived and kept the live selection" \
  [expr {[winfo exists .ciform] && $::ciform::cell eq {multisym} && $::ciform::view eq {symbol_alt}}] \
  "(=> $::ciform::cell/$::ciform::view)"
xschem abort_operation

# === CI8 — keep-placing: each drop re-arms the same symbol ====================
xschem clear force
xschem abort_operation
setf tlib withsym symbol
check "CI8a armed (preview attached)" [armed] {}
xschem callback .drw 4 300 300 0 1 0 0
xschem callback .drw 5 300 300 0 1 0 0
check "CI8b drop cleared the placement" [expr {![armed]}] {}
ciform::after_drop 1
check "CI8c same symbol re-armed after drop" [armed] {}
xschem callback .drw 4 500 500 0 1 0 0
xschem callback .drw 5 500 500 0 1 0 0
ciform::after_drop 1
check "CI8d two instances placed (continuous)" [expr {[xschem get instances] >= 2}] "(=> [xschem get instances])"
check "CI8e drop hook wired on the canvas" [string match {*after_drop*} [bind .drw <ButtonRelease>]] {}

# === CI9 — Esc ends placement AND dismisses form + browser ===================
ciform::browse
update idletasks
setf tlib withsym symbol
check "CI9a armed, browser open, before Esc" [expr {[armed] && [winfo exists .mkinst]}] {}
ciform::escape
update idletasks
check "CI9b Esc cleared the placement" [expr {![armed]}] {}
check "CI9c Esc dismissed the form" [expr {![winfo exists .ciform]}] {}
check "CI9d Esc dismissed the browser too" [expr {![winfo exists .mkinst]}] {}

# === CI10 — reopen restores the form fields and re-arms =======================
xschem create_instance
update idletasks
check "CI10a reopened" [winfo exists .ciform] {}
check "CI10b fields persisted" \
  [expr {$::ciform::lib eq {tlib} && $::ciform::cell eq {withsym} && $::ciform::view eq {symbol}}] \
  "(=> $::ciform::lib/$::ciform::cell/$::ciform::view)"
check "CI10c preview re-armed on reopen" [armed] "(=> ui=[xschem get ui_state])"
xschem abort_operation

# === CI11 — Legacy button routes to the no-arg place_symbol dialog ============
check "CI11a Legacy button calls ciform::legacy" [expr {[.ciform.b.legacy cget -command] eq {ciform::legacy}}] {}
check "CI11b ciform::legacy uses no-arg place_symbol" \
  [expr {[string trim [info body ciform::legacy]] eq {xschem place_symbol}}] \
  "(=> '[string trim [info body ciform::legacy]]')"

# === CI12 — recursion guard (self and ancestor) ==============================
xschem abort_operation
xschem load $tmp/tlib/withsym/schematic/withsym.sch
setf tlib withsym symbol
check "CI12a placing a cell in its OWN schematic is blocked" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
check "CI12b status explains the recursion" [string match {*recursion*} [.ciform.status cget -text]] \
  "(=> [.ciform.status cget -text])"
# ancestor: descend parent>child, then try to place parent (and child)
xschem abort_operation
xschem load $tmp/tlib/parent/schematic/parent.sch
xschem select_all
xschem descend
check "CI12c descended one level into child" [expr {[xschem get currsch] == 1}] "(=> currsch=[xschem get currsch])"
setf tlib parent symbol
check "CI12d placing an ANCESTOR (parent) in a descendant is blocked" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
setf tlib child symbol
check "CI12e the current cell (child) is also blocked" [expr {![armed]}] "(=> ui=[xschem get ui_state])"
setf tlib withsym symbol
check "CI12f a cell not in the stack still arms" [armed] "(=> ui=[xschem get ui_state])"
xschem abort_operation

# === CI13 — `create_instance <lcv>` pre-fills the form (library_manager-style) ==
xschem clear force
xschem abort_operation
catch {destroy .ciform}
xschem create_instance {tlib withsym symbol}
update idletasks
check "CI13a list arg pre-fills the fields" \
  [expr {$::ciform::lib eq {tlib} && $::ciform::cell eq {withsym} && $::ciform::view eq {symbol}}] \
  "(=> $::ciform::lib/$::ciform::cell/$::ciform::view)"
check "CI13b pre-filled fields arm the preview" [armed] {}
# the reported bug: an ALREADY-OPEN form switches to the new cell, not the old one
xschem create_instance {tlib child symbol}
update idletasks
check "CI13c re-open with a list switches cell on the open form" \
  [expr {$::ciform::cell eq {child}}] "(=> $::ciform::cell)"
# a 4th element sets the Instance Name
xschem create_instance {tlib withsym symbol N9}
update idletasks
check "CI13d 4-element list sets the Instance Name" \
  [expr {$::ciform::instname eq {N9}}] "(=> $::ciform::instname)"
# a bare reopen keeps the last fields (singleton, no clobber)
xschem abort_operation
xschem create_instance
update idletasks
check "CI13e bare reopen keeps the last fields" [expr {$::ciform::cell eq {withsym}}] "(=> $::ciform::cell)"
xschem abort_operation

catch {destroy .ciform}; catch {destroy .mkinst}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
