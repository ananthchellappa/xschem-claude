# Issue 0019: the "Descend schematic (edit)" context-menu item must not collide with
# the pre-existing "Rotate selection" button name. With descend_readonly=1 (the
# cadence_style_rc default) AND a selection, the real `context_menu` proc builds BOTH
# a "Descend schematic (edit)" item and a "Rotate selection" item; if they share the
# widget name .ctxmenu.b22 the second `button` call errors ("window name ... already
# exists") and the whole menu fails to appear.
#
# RED before fix: context_menu throws during the build phase -> rc != 0, and the two
# buttons never both exist. GREEN after fix: the proc builds, reaches its tkwait, and
# the deferred teardown below sees both distinct buttons, then destroys the menu.
#
# Needs X (builds real Tk widgets). Run from the repo ROOT:
#   DISPLAY=:0 ./src/xschem --pipe -q --nolog --script tests/headless/test_context_menu_descend_edit.tcl

set fail 0; set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } else { puts "FAIL: $name $detail"; incr fail }
}
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
proc ex {n} { global repo; return [file join $repo xschem_library examples $n] }

# cadence browse mode: descend defaults to read-only, so the edit item is shown.
set ::descend_readonly 1

# load a schematic with at least one instance and select it so $selection is true
xschem load [ex nand2.sch]
xschem unselect_all
xschem select instance 0
update idletasks
check "CME0 an instance is selected (menu shows the selection items)" \
  [expr {[xschem get lastsel] > 0}] "(lastsel=[xschem get lastsel])"

# While context_menu blocks in its tkwait, inspect the built menu, then tear it down.
# (If context_menu errors during the build, the event loop is never entered, this
# never runs, and .ctxmenu is cleaned up after the catch instead.)
set ::cme_edit 0
set ::cme_rot  0
set ::cme_seen 0
after 200 {
  set ::cme_seen [winfo exists .ctxmenu]
  if {$::cme_seen} {
    foreach w [winfo children .ctxmenu] {
      if {![catch {$w cget -text} txt]} {
        if {$txt eq {Descend schematic (edit)}} { incr ::cme_edit }
        if {$txt eq {Rotate selection}}         { incr ::cme_rot }
      }
    }
  }
  catch {destroy .ctxmenu}
}

set rc [catch {context_menu} err]
catch {destroy .ctxmenu}   ;# clean up an orphaned menu left by an error path

# CME1 — the menu builds without error (RED: name collision throws here)
check "CME1 context_menu builds without error under descend_readonly=1 + selection" \
  [expr {$rc == 0}] "(rc=$rc err={$err})"

# CME2 — both the edit-descend item and the rotate item exist as DISTINCT buttons
check "CME2 both 'Descend schematic (edit)' and 'Rotate selection' exist as distinct widgets" \
  [expr {$::cme_seen && $::cme_edit == 1 && $::cme_rot == 1}] \
  "(seen=$::cme_seen edit=$::cme_edit rot=$::cme_rot)"

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; exit 1 }
