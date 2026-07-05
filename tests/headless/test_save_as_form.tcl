# X-gated FORM tests for the Library/Cell/View Save-As dialog (.saveform / .savebrowse).
# Spec: doc/claude/specs/save_as_cellview.md. The headless CORE (resolve_target +
# `xschem saveas`) is covered by test_save_as_cellview.tcl; this drives the widgets.
#
# save_as_cellview_dialog blocks (tkwait), so — like test_create_instance.tcl — the
# tests drive the form procs directly (build / save / legacy / cancel / browse).
#
# Needs X. Run under X with --pipe from src/:
#   DISPLAY=:0 ./xschem --pipe -q --script ../tests/headless/test_save_as_form.tcl

set fail 0
proc check {name ok {detail {}}} {
  global fail
  if {$ok} { puts "ok:   $name $detail" } else { puts "FAIL: $name $detail"; incr fail }
}
proc touch {f {txt {v {xschem version=3.4.8 file_version=1.3}}}} {
  file mkdir [file dirname $f]; set fp [open $f w]; puts $fp $txt; close $fp
}
# open the form without blocking (no tkwait): seed the state + build.
proc openform {seed type} {
  catch {destroy .saveform}; catch {destroy .savebrowse}
  set ::saveform::type $type; set ::saveform::seed $seed
  saveform::prefill $seed $type
  saveform::build
  update idletasks
}
proc pick {col txt handler} {
  set lb .savebrowse.pw.$col.lb
  set i [lsearch -exact [$lb get 0 end] $txt]
  if {$i < 0} return
  $lb selection clear 0 end; $lb selection set $i; $lb activate $i
  eval $handler
}

# --- fixture: one writable library with a cell that has a schematic view -------
set tmp [file join [pwd] _saveform_[pid]]
file delete -force $tmp
touch $tmp/tlib/existing/schematic/existing.sch
set defs [file join $tmp library.defs]
set fp [open $defs w]; puts $fp "DEFINE tlib $tmp/tlib"; close $fp
set ::XSCHEM_LIBRARY_DEFS $defs
set lp $tmp/tlib

# quiet the message boxes so the tests never block on a real popup
catch {rename tk_messageBox _real_tk_messageBox}
proc tk_messageBox {args} { return ok }

# === SF1 — form builds: L/C/V entries + Browse + Save/Legacy/Cancel; prefill ====
openform $lp/existing/schematic/existing.sch schematic
check "SF1a .saveform opens" [winfo exists .saveform] {}
check "SF1b Library/Cell/View entries present" \
  [expr {[winfo exists .saveform.f.elib] && [winfo exists .saveform.f.ecell] && [winfo exists .saveform.f.eview]}] {}
check "SF1c Browse button present" [winfo exists .saveform.f.browse] {}
check "SF1d Save / Legacy / Cancel buttons present" \
  [expr {[winfo exists .saveform.b.save] && [winfo exists .saveform.b.legacy] && [winfo exists .saveform.b.cancel]}] {}
check "SF1e prefill from a cellview seed fills lib/cell/view" \
  [expr {$::saveform::lib eq {tlib} && $::saveform::cell eq {existing} && $::saveform::view eq {schematic}}] \
  "(=> $::saveform::lib/$::saveform::cell/$::saveform::view)"

# === SF2 — unknown library on Save: error, form stays open, Library text selected =
set ::saveform::lib nolib; set ::saveform::cell foo; set ::saveform::view schematic
set ::saveform::result "SENTINEL"
saveform::save
update idletasks
check "SF2a form stays open on an unknown library" [winfo exists .saveform] {}
check "SF2b no path returned (result untouched -> still SENTINEL)" [expr {$::saveform::result eq {SENTINEL}}] \
  "(=> $::saveform::result)"
check "SF2c the Library entry text is selected for retype" \
  [expr {![catch {.saveform.f.elib selection present} s] && $s}] "(=> [catch {.saveform.f.elib selection present}])"

# === SF3 — valid Save: result = <cell>.<ext>, form destroyed, dirs created =======
set ::saveform::lib tlib; set ::saveform::cell newc; set ::saveform::view schematic
set ::saveform::result ""
saveform::save
update idletasks
check "SF3a Save closed the form" [expr {![winfo exists .saveform]}] {}
check "SF3b result is the nested datafile path" \
  [expr {$::saveform::result eq [file join $lp newc schematic newc.sch]}] "(=> $::saveform::result)"
check "SF3c the cell/view directory was created" [file isdirectory [file join $lp newc schematic]] {}

# === SF4 — Browse opens .savebrowse and selecting fills the form live ============
openform $lp/existing/schematic/existing.sch schematic
saveform::browse
update idletasks
check "SF4a Browse opens .savebrowse" [winfo exists .savebrowse] {}
check "SF4b browser lists tlib" [expr {[lsearch [.savebrowse.pw.lib.lb get 0 end] tlib] >= 0}] {}
pick lib tlib savebrowse::on_lib
check "SF4c selecting a library fills the form's Library" [expr {$::saveform::lib eq {tlib}}] "(=> $::saveform::lib)"
pick cell existing savebrowse::on_cell
check "SF4d selecting a cell (single view) fills Cell + View live" \
  [expr {$::saveform::cell eq {existing} && $::saveform::view eq {schematic}}] "(=> $::saveform::cell/$::saveform::view)"

# === SF5 — Legacy button is wired to the old dialog fallback =====================
check "SF5 Legacy button calls saveform::legacy" [expr {[.saveform.b.legacy cget -command] eq {saveform::legacy}}] {}

# === SF6 — Cancel returns "" (abort) and closes both windows ====================
set ::saveform::result "X"
saveform::cancel
update idletasks
check "SF6a Cancel returns empty (abort)" [expr {$::saveform::result eq {}}] "(=> '$::saveform::result')"
check "SF6b Cancel closed the form" [expr {![winfo exists .saveform]}] {}
check "SF6c Cancel closed the browser too" [expr {![winfo exists .savebrowse]}] {}

# === SF7 — overwriting an EXISTING DIFFERENT cellview warns + confirms ===========
# a recording, answerable messagebox stub: return $::ovw_answer to the yes/no question
proc tk_messageBox {args} {
  array set a $args
  lappend ::ovw_calls $a(-title)
  if {[info exists a(-type)] && $a(-type) eq {yesno}} { return $::ovw_answer }
  return ok
}
# a buffer whose identity is NOT the target (untitled) -> a real overwrite of tlib/existing
xschem clear force
xschem wire 0 0 100 0
openform [xschem get schname] schematic
set ::saveform::lib tlib; set ::saveform::cell existing; set ::saveform::view schematic
# (a) answer No -> the confirm fired and the save aborted (form open, no path)
set ::ovw_answer no; set ::ovw_calls {}; set ::saveform::result NONE
saveform::save; update idletasks
check "SF7a overwriting an existing view pops an 'Overwrite?' confirm" \
  [expr {[lsearch $::ovw_calls {Overwrite?}] >= 0}] "(=> $::ovw_calls)"
check "SF7b answering No aborts (form stays open, no path)" \
  [expr {[winfo exists .saveform] && $::saveform::result eq {NONE}}] "(=> $::saveform::result)"
# (b) answer Yes -> proceeds (path returned, form closed)
set ::ovw_answer yes; set ::saveform::result ""
saveform::save; update idletasks
check "SF7c answering Yes proceeds (path returned, form closed)" \
  [expr {![winfo exists .saveform] && $::saveform::result eq [file join $lp existing schematic existing.sch]}] \
  "(=> $::saveform::result)"
# (c) re-saving the buffer's OWN file does NOT prompt (silent self-save)
xschem load $lp/existing/schematic/existing.sch
openform [xschem get schname] schematic
set ::saveform::lib tlib; set ::saveform::cell existing; set ::saveform::view schematic
set ::ovw_calls {}; set ::saveform::result ""
saveform::save; update idletasks
check "SF7d re-saving the current buffer's own file is silent (no confirm)" \
  [expr {[lsearch $::ovw_calls {Overwrite?}] < 0}] "(=> $::ovw_calls)"
catch {destroy .saveform}

catch {destroy .saveform}; catch {destroy .savebrowse}
catch {rename tk_messageBox {}; rename _real_tk_messageBox tk_messageBox}
file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS" } else { puts "RESULT: $fail FAILED" }
flush stdout
