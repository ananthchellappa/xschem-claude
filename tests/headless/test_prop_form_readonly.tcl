# tests/headless/test_prop_form_readonly.tcl -- on a read-only sheet a property form
# is a VIEWER: it shows the values and takes no edits.
#
# The user's report, 2026-11-12: "Why is property edit form permitting user to edit
# values when the schematic is read only?" Issue 0051 had opened the form there with
# OK/Apply greyed but the fields deliberately editable. ro_view_freeze (src/xschem.tcl)
# now swallows every key that would change a field, and disables the toggles and
# buttons, in the instance form (slickprop::edit_form), the pin form
# (schpin::edit_form), the gfx forms (text_line_slick) and the text forms.
#   PR1  instance form: titled read-only; every field carries the XschemROView tag;
#        OK, Apply, Browse, the option checkbuttons and the Apply-to scope are disabled;
#        Cancel and Next stay live
#   PR2  typing into a field, and BackSpace in it, leave it unchanged
#   PR3  Next rebuilds the fields for the next instance and they are frozen again
#   PR4  Enter in a frozen field closes the form and the sheet stays unmodified
#   PR5  the key predicate: navigation and copy pass, typing, deleting and paste do not
#   PR6  pin form: titled read-only, its name entry frozen, OK and Direction disabled
#   PR7  wire form (tkwait dialog): its entries frozen, OK disabled, Cancel live
#   PR8  control: the same form on an editable sheet takes the keystroke
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
proc ro_tag {w} { expr {[lindex [bindtags $w] 0] eq {XschemROView}} }
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

# PR1 -- the instance form, two MOSFETs selected.
close_dialog
xschem unselect_all
xschem select instance $ix(M2) ; xschem select instance $ix(M1)
xschem edit_prop
settle
set ents [field_entries]
set tagged 0
foreach e $ents { incr tagged [ro_tag $e] }
check {PR1 the instance form opens as a read-only viewer: title, every field frozen, edit controls off, Cancel and Next live} \
  [list [wm title .dialog] [expr {[llength $ents] > 2}] [expr {$tagged == [llength $ents]}] \
        [.dialog.fb.ok cget -state] [.dialog.fb.apply cget -state] [.dialog.f1.b5 cget -state] \
        [.dialog.f2.r1 cget -state] [.dialog.fscope.cb instate disabled] \
        [.dialog.fb.cancel cget -state] [.dialog.fnav.next cget -state]] \
  [list {Properties (read-only)} 1 1 disabled disabled disabled disabled 1 normal normal]

# PR2 -- typing does nothing.
set e $::slickprop::cur(entry,w)
set before [$e get]
# two separate drives: a typed key and a delete would cancel out inside one
catch {$e selection clear ; $e icursor end}
set at1 [type_into $e x y]
set typed [$e get]
catch {$e icursor end}
set at2 [type_into $e BackSpace]
check {PR2 typing into a frozen field, and BackSpace in it, both leave it unchanged} \
  [list $at1 $at2 [expr {$before ne {}}] $typed [$e get]] [list 1 1 1 $before $before]

# PR3 -- Next refills (a programmatic insert, which the freeze must not block) and refreezes.
slickprop::nav 1
settle
set e $::slickprop::cur(entry,w)
check {PR3 Next shows the next instance and its rebuilt fields are frozen again} \
  [list [.dialog.fname.e get] [expr {[$e get] ne $before && [$e get] ne {}}] [ro_tag $e] \
        [.dialog.fnav.prev cget -state]] \
  {M1 1 1 normal}

# PR4 -- Enter closes, nothing changed.
type_into $e Return
check {PR4 Enter in a frozen field closes the form and the sheet stays unmodified} \
  [list [winfo exists .dialog] [xschem get modified]] {0 0}

# PR5 -- the predicate itself.
set got {}
foreach {k s} {Left 0 End 0 Tab 0 c 4 a 4 x 0 BackSpace 0 Delete 0 v 4 k 4 d 4} {
  lappend got $k/$s=[ro_view_key_ok $k $s]
}
check {PR5 navigation and copy keys pass a frozen field; typing, deleting and Ctrl-V/K/D do not} \
  $got {Left/0=1 End/0=1 Tab/0=1 c/4=1 a/4=1 x/0=0 BackSpace/0=0 Delete/0=0 v/4=0 k/4=0 d/4=0}
check {PR5 paste, cut and middle-click paste are swallowed by the tag} \
  [list [bind XschemROView <<Paste>>] [bind XschemROView <<Cut>>] [bind XschemROView <ButtonRelease-2>]] \
  {break break break}

# PR6 -- the pin form.
close_dialog
xschem unselect_all
xschem select instance $ix(p1)
xschem edit_prop
settle
check {PR6 the pin form opens read-only: its name entry frozen, OK and Direction disabled} \
  [list [wm title .dialog] [ro_tag .dialog.f.en] [.dialog.b.ok cget -state] \
        [.dialog.f.cd instate disabled] [.dialog.b.cancel cget -state]] \
  [list {Pin (read-only)} 1 disabled 1 normal]
close_dialog

# PR7 -- a wire's form blocks in tkwait, so inspect it from a timer.
xschem unselect_all
xschem select wire 0
set ::pr7 {}
after 600 {
  set tagged 0 ; set n 0
  foreach w [list .dialog.appear.lab.e .dialog.other.e] {
    if {[winfo exists $w]} { incr n ; incr tagged [ro_tag $w] }
  }
  set ::pr7 [list $n $tagged [.dialog.buttons.ok cget -state] [.dialog.buttons.cancel cget -state]]
  .dialog.buttons.cancel invoke
}
after 8000 { if {[winfo exists .dialog]} { set ::pr7 TIMEOUT ; destroy .dialog } }
xschem edit_prop
check {PR7 the wire form opens with its entries frozen, OK disabled and Cancel live} \
  $::pr7 {2 2 disabled normal}

# PR8 -- control: editable sheet.
close_dialog
xschem set readonly 0
xschem unselect_all
xschem select instance $ix(M2)
xschem edit_prop
settle
# the field the form put the keyboard in (the WM may refuse a later focus move)
set e [focus]
if {[lsearch -exact [field_entries] $e] < 0} { set e $::slickprop::cur(entry,w) }
catch {$e selection clear ; $e icursor end}
set before [$e get]
set at [type_into $e x]
check {PR8 control: on an editable sheet the same field is not frozen and takes the keystroke} \
  [list $at [wm title .dialog] [ro_tag $e] [.dialog.fb.ok cget -state] [$e get]] \
  [list 1 {Edit Properties} 0 normal ${before}x]
close_dialog
xschem set readonly 1
xschem clear force schematic

set floor 9
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
