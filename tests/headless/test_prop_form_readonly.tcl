# tests/headless/test_prop_form_readonly.tcl -- on a read-only sheet a property form
# lets the user try values but says, where they are looking, that nothing applies.
#
# The user's ruling, 2026-11-12: keep the fields editable ("to permit experimentation"),
# and make it clear the sheet is read-only. ro_view_mark (src/xschem.tcl) puts a red
# banner across the form's top and tints its text fields rose, in the instance form
# (slickprop::edit_form), the pin form (schpin::edit_form), the gfx forms
# (text_line_slick) and the text forms; OK/Apply stay disabled (issue 0051).
#   PR1  instance form: titled read-only, banner shown, every field tinted, OK and
#        Apply disabled, Cancel and Next live
#   PR2  a field still takes typing, and Apply still writes nothing
#   PR3  Next rebuilds the fields for the next instance and they are tinted again
#   PR4  Enter closes the form and the sheet stays unmodified, typed value and all
#   PR5  pin form: banner, tinted and editable name entry, OK and Apply disabled
#   PR6  wire form (tkwait dialog): banner, tinted entries, OK disabled, Cancel live
#   PR7  control: on an editable sheet no banner and no tint
# Display only (the forms are Tk); registered in dcases.
# Run: tests/headless/run_suites.sh test_prop_form_readonly

if {[catch {winfo exists .}]} {
  puts "RESULT: SKIP (needs Tk/X; the forms are Tk dialogs)"; flush stdout; exit 0
}
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set repo [file normalize [file join $here .. ..]]

set fail 0 ; set npass 0
proc check {name got want} {
  global fail npass
  if {$got eq $want} { puts "ok:   $name" ; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$want}) : FAIL" ; incr fail }
}
proc settle {{n 6}} { for {set i 0} {$i < $n} {incr i} { update idletasks; update } }
proc close_dialog {} {
  catch {while {[winfo exists .dialog]} { catch {slickprop::cancel}; catch {destroy .dialog}; update }}
}
proc tinted {w} { expr {[string tolower [$w cget -background]] eq [string tolower [ro_view_bg]]} }
proc banner {} { expr {[winfo exists .dialog.robanner] && [winfo ismapped .dialog.robanner]} }
proc field_entries {} {
  set out {}
  foreach t $::slickprop::cur(tokens) {
    if {[info exists ::slickprop::cur(entry,$t)] && $::slickprop::cur(entry,$t) ne {}} {
      lappend out $::slickprop::cur(entry,$t)
    }
  }
  return $out
}
# Send keys to <e>; answers 1 when every key was delivered with <e> holding the focus
# (Tk redirects a KeyPress to the focus widget, so a key sent while focus sits elsewhere
# would measure a different field).
proc type_into {e args} {
  focus -force $e ; settle
  set at 1
  foreach k $args {
    focus $e
    if {[focus] ne $e} { set at 0 }
    event generate $e <KeyPress> -keysym $k -when now
  }
  settle
  return $at
}

xschem load [file join $repo xschem_library examples cmos_inv.sch]
# the fixture's instances, by name (M2/M1 are the MOSFETs, p1 the input pin)
array set ix {}
for {set i 0} {$i < [xschem get instances]} {incr i} { set ix([xschem getprop instance $i name]) $i }
xschem set readonly 1
set w_orig [xschem getprop instance $ix(M2) w]

# PR1 -- the instance form, two MOSFETs selected.
close_dialog
xschem unselect_all
xschem select instance $ix(M2) ; xschem select instance $ix(M1)
xschem edit_prop
settle
set ents [field_entries]
set nt 0
foreach e $ents { incr nt [tinted $e] }
check {PR1 the instance form opens read-only: title, banner, every field tinted, OK/Apply off, Cancel and Next live} \
  [list [wm title .dialog] [banner] [expr {[llength $ents] > 2}] [expr {$nt == [llength $ents]}] \
        [.dialog.fb.ok cget -state] [.dialog.fb.apply cget -state] \
        [.dialog.fb.cancel cget -state] [.dialog.fnav.next cget -state] [.dialog.fb.hint cget -text]] \
  [list {Properties (read-only)} 1 1 1 disabled disabled normal normal {Enter/Esc: close}]

# PR2 -- still editable, still nothing applied.
set e $::slickprop::cur(entry,w)
catch {$e selection clear ; $e icursor end}
set before [$e get]
set at [type_into $e x]
set typed [$e get]
catch {slickprop::apply_now}
settle
check {PR2 a field still takes typing, and Apply writes nothing to the sheet} \
  [list $at $typed [xschem getprop instance $ix(M2) w] [xschem get modified]] \
  [list 1 ${before}x $w_orig 0]

# PR3 -- Next rebuilds and re-tints. (Next on a dirty instance asks first; read-only
# skips the prompt, see slickprop::maybe_apply_then.)
slickprop::nav 1
settle
set e $::slickprop::cur(entry,w)
check {PR3 Next shows the next instance and its rebuilt fields are tinted again} \
  [list [.dialog.fname.e get] [tinted $e] [banner]] {M1 1 1}

# PR4 -- Enter closes, nothing changed.
set at [type_into $e x Return]
check {PR4 Enter closes the form and the sheet stays unmodified} \
  [list [winfo exists .dialog] [xschem get modified] [xschem getprop instance $ix(M2) w]] \
  [list 0 0 $w_orig]

# PR5 -- the pin form.
close_dialog
xschem unselect_all
xschem select instance $ix(p1)
xschem edit_prop
settle
check {PR5 the pin form opens read-only: banner, tinted name entry, OK and Apply disabled} \
  [list [wm title .dialog] [banner] [tinted .dialog.f.en] [.dialog.f.en cget -state] \
        [.dialog.b.ok cget -state] [.dialog.b.apply cget -state] [.dialog.b.cancel cget -state]] \
  [list {Pin (read-only)} 1 1 normal disabled disabled normal]
close_dialog

# PR6 -- a wire's form blocks in tkwait, so inspect it from a timer.
xschem unselect_all
xschem select wire 0
set ::pr6 {}
after 600 {
  set nt 0 ; set n 0
  foreach w [list .dialog.appear.lab.e .dialog.other.e] {
    if {[winfo exists $w]} { incr n ; incr nt [tinted $w] }
  }
  set ::pr6 [list [banner] $n $nt [.dialog.buttons.ok cget -state] [.dialog.buttons.cancel cget -state]]
  .dialog.buttons.cancel invoke
}
after 8000 { if {[winfo exists .dialog]} { set ::pr6 TIMEOUT ; destroy .dialog } }
xschem edit_prop
check {PR6 the wire form opens with the banner, tinted entries, OK disabled and Cancel live} \
  $::pr6 {1 2 2 disabled normal}

# PR7 -- control: editable sheet.
close_dialog
xschem set readonly 0
xschem unselect_all
xschem select instance $ix(M2)
xschem edit_prop
settle
set e $::slickprop::cur(entry,w)
check {PR7 control: on an editable sheet the form has no banner and no tint} \
  [list [wm title .dialog] [winfo exists .dialog.robanner] [tinted $e] [.dialog.fb.ok cget -state]] \
  [list {Edit Properties} 0 0 normal]
close_dialog
xschem set readonly 1
xschem clear force schematic

set floor 7
if {$npass + $fail < $floor} {
  puts "FAIL: PRFLOOR ran [expr {$npass + $fail}] checks, below the floor of $floor"
  incr fail
}
if {$fail == 0} {
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
}
puts "RESULT: $fail FAILED ($npass passed)"
exit 1
