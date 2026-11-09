# test_cadence_q_scope.tcl -- Q / Alt-Shift-Q open Edit Properties with a FIXED
# "Apply to" scope under src/cadence_style_rc.
#
# The user's request (2026-11-09): in Cadence, Q always opened the property form
# with "Apply to" set to "Only Current", whatever it was left at last time, and
# Alt-Shift-Q opened it with "All Selected". The user can still change the
# dropdown by hand while the form is open.
#
# The form's scope is the sticky global ::slickprop_apply_scope, shown in the
# readonly combobox .dialog.fscope.cb. Natively (no profile) it is retained
# across opens; this suite asserts that first (row N1), then sources the rc and
# drives the real Tk bindings on .drw with `event generate`.
#
# Letter case as typed decides (user ruling 2026-10-16, Caps Lock): upper =
# Shift XOR Lock. So Caps Lock + Alt-q is Alt-Shift-Q, Caps Lock + Shift-q is q.
#
# Needs X (bind / event generate / the form). Under --nogui it announces an
# uppercase SKIP and exits 0. Registered in dcases only.
#   tests/headless/run_suites.sh test_cadence_q_scope
source [file join [file dirname [info script]] scratch.tcl]

if {[info commands winfo] eq {} || [catch {winfo exists .drw} e] || !$e} {
  puts "SKIP: needs X (bind, event generate and the property form)"
  puts "OVERALL: ok (0 checks)"
  puts "RESULT: SKIP (no X)"
  flush stdout
  exit 0
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]

set ::npass 0
set ::nfail 0
proc check {name got want} {
  if {$got eq $want} {
    incr ::npass; puts "ok:   $name (got $got)"
  } else {
    incr ::nfail; puts "FAIL: $name (got $got want $want)"
  }
  flush stdout
}

proc cb_label {} {
  if {![winfo exists .dialog.fscope.cb]} { return NOFORM }
  return [.dialog.fscope.cb get]
}
proc close_form {} {
  if {[winfo exists .dialog]} { catch {slickprop::cancel} }
  catch {destroy .dialog}
  update
}
# press a key on the canvas through the real Tk binding chain
proc press {ks {st 0}} {
  focus -force .drw
  update
  event generate .drw <KeyPress> -keysym $ks -state $st -x 200 -y 200 -when now
  update
}
# pick a dropdown entry the way a user does (sets the widget, fires the event)
proc pick {label} {
  if {![winfo exists .dialog.fscope.cb]} return
  .dialog.fscope.cb set $label
  event generate .dialog.fscope.cb <<ComboboxSelected>> -when now
  update
}

set SHIFT 1 ; set LOCK 2 ; set ALT 8

# --- fixture: two resistors, both selected ----------------------------------
xschem set modified 0
xschem clear force schematic
xschem instance res.sym 0 0 0 0 {name=R1 value=1k}
xschem instance res.sym 200 0 0 0 {name=R2 value=2k}
xschem zoom_full
update
proc select_both {} {
  xschem unselect_all
  xschem select instance 0
  xschem select instance 1
  update
}
select_both
check "F1 fixture: two instances selected" [xschem get lastsel] 2

# --- N1: native (no profile): the scope is sticky across opens --------------
set ::slickprop_apply_scope selected
press q
check "N1a native q opens the form" [winfo exists .dialog.fscope.cb] 1
check "N1b native q keeps the sticky scope" $::slickprop_apply_scope selected
check "N1c native q shows the sticky scope" [cb_label] "All Selected"
close_form
set ::slickprop_apply_scope current

# --- load the profile -------------------------------------------------------
source [file join $repo src cadence_style_rc]
update
select_both

# --- Q1: q opens Only Current after the form was left at All Selected ------
set ::slickprop_apply_scope selected
press q
check "Q1a q opens the form" [winfo exists .dialog.fscope.cb] 1
check "Q1b q resets the scope to current" $::slickprop_apply_scope current
check "Q1c q shows Only Current" [cb_label] "Only Current"
# a manual change inside the form still works
pick "All Selected"
check "Q1d manual change to All Selected sets the scope" $::slickprop_apply_scope selected
close_form
# the form was closed at All Selected; q again must still open Only Current
check "Q1e closed form leaves the scope at All Selected" $::slickprop_apply_scope selected
press q
check "Q1f q reopens at Only Current" [cb_label] "Only Current"
check "Q1g scope var follows" $::slickprop_apply_scope current
close_form
# also from the third state
set ::slickprop_apply_scope all
press q
check "Q1h q resets from All (same symbol)" [cb_label] "Only Current"
close_form

# --- A1: Alt-Shift-Q opens All Selected after the form was left at Only Current
set ::slickprop_apply_scope current
press Q [expr {$SHIFT | $ALT}]
check "A1a Alt-Shift-Q opens the form" [winfo exists .dialog.fscope.cb] 1
check "A1b Alt-Shift-Q sets the scope to selected" $::slickprop_apply_scope selected
check "A1c Alt-Shift-Q shows All Selected" [cb_label] "All Selected"
pick "Only Current"
check "A1d manual change to Only Current sets the scope" $::slickprop_apply_scope current
close_form
press Q [expr {$SHIFT | $ALT}]
check "A1e Alt-Shift-Q reopens at All Selected" [cb_label] "All Selected"
close_form

# --- K: Caps Lock -- the letter case typed decides --------------------------
set ::slickprop_apply_scope current
press Q [expr {$LOCK | $ALT}]
check "K1 Caps Lock + Alt-q acts as Alt-Shift-Q" [cb_label] "All Selected"
close_form
set ::slickprop_apply_scope selected
press q [expr {$LOCK | $SHIFT}]
check "K2 Caps Lock + Shift-q acts as q" [cb_label] "Only Current"
close_form

# --- O: a key pressed while the form is open re-scopes it, display in step --
set ::slickprop_apply_scope selected
press q
press Q [expr {$SHIFT | $ALT}]
check "O1 Alt-Shift-Q on an open form shows All Selected" [cb_label] "All Selected"
check "O2 and the scope var agrees" $::slickprop_apply_scope selected
press q
check "O3 q on an open form shows Only Current" [cb_label] "Only Current"
close_form

# --- P: other chords on the letter still reach the native dispatcher ---------
# Alt-q (lower) is native "edit .sch file": stub the editor launch to observe it.
set ::edit_file_calls 0
rename edit_file ::__orig_edit_file
proc edit_file {args} { incr ::edit_file_calls }
xschem unselect_all
set ::slickprop_apply_scope selected
press q $ALT
check "P1 Alt-q still runs native edit-file" $::edit_file_calls 1
check "P2 Alt-q opens no property form" [winfo exists .dialog] 0
check "P3 Alt-q leaves the scope alone" $::slickprop_apply_scope selected
# Caps Lock + Alt-Shift-q is Alt-q as typed
press Q [expr {$LOCK | $SHIFT | $ALT}]
check "P4 Caps Lock + Alt-Shift-q acts as Alt-q" $::edit_file_calls 2
check "P5 and opens no property form" [winfo exists .dialog] 0
rename edit_file {}
rename ::__orig_edit_file edit_file

# --- S: the binding is in the rc and nowhere else ----------------------------
set fh [open [file join $repo src cadence_style_rc]]; set rc [read $fh]; close $fh
check "S1 rc binds <Key-q>" [regexp {\nbind \.drw <Key-q> } $rc] 1
check "S2 rc binds <Key-Q>" [regexp {\nbind \.drw <Key-Q> } $rc] 1

close_form
set total [expr {$::npass + $::nfail}]
if {$::nfail == 0} {
  puts "OVERALL: ok ($total checks)"
  puts "RESULT: ALL PASS ($total checks)"
} else {
  puts "RESULT: $::nfail FAILED ($::npass passed)"
}
flush stdout
exit [expr {$::nfail == 0 ? 0 : 1}]
