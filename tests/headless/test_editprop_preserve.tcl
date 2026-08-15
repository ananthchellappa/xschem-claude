# Multi-select property-edit preservation scope (code-review fix [1]).
#
# edit_property() re-forces preserve_unchanged_attrs=1 for a MULTI-object NON-instance
# selection so a single shared edit does not overwrite every selected wire/rect/line/arc/
# poly/text with the first object's whole property string (a data-loss regression vs master,
# whose apply loops take the per-token set_different_token branch only when preserve==1). The
# force is scoped: it must NOT fire for a single object, and must NOT fire for INSTANCES (whose
# slick-form "Apply to" scope + changed-fields-only in update_symbol govern those instead).
# See doc/claude/specs/cadence_pin_name_text.md and editprop.c edit_property().
#
# edit_property() early-returns on !has_x, and the force runs before the (non-blocking) form
# opens, so this MUST run under X (no --nogui):
#   ./src/xschem --pipe -q --script tests/headless/test_editprop_preserve.tcl
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; edit_property early-returns on !has_x)"; flush stdout; exit 0 }
update idletasks

set ::fails 0
proc check {name got want} {
  set ok [expr {$got eq $want}]
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name (got $got want $want)"; flush stdout
  if {!$ok} {incr ::fails}
}

# The wire/graphical property form is MODAL since 0118 (text_line_slick ends in
# `tkwait window .dialog`), so a real `xschem edit_prop` on wires BLOCKS this
# script until a human closes the dialog -- under full_audit that was a 120s
# TIMEOUT + SIGTERM emergency-save, and on an attended desktop a re-popping
# "Edit Wire properties" window (one per wire case). The preserve-force under
# test runs in C BEFORE text_line is called, so stub the dialog out entirely:
# COUNT the calls (a bare stub would mask a dead path, atom-3 finding) and
# report Cancel (empty rcode) with no widgets and no tkwait.
set ::tl_calls 0
rename text_line ::orig_text_line
proc text_line {txtlabel clear {preserve_disabled disabled}} {
  incr ::tl_calls
  set ::tctx::rcode {}
  return {}
}
proc close_dialog {} {
  catch {while {[winfo exists .dialog]} { catch {slickprop::cancel}; catch {destroy .dialog}; update }}
  foreach id [after info] { catch {after cancel $id} }
}

# --- 1. multi-select NON-instance (two wires): force preserve=1 --------------------------
xschem clear force schematic
xschem wire 0 0 100 0
xschem wire 0 50 100 50
check "two wires present" [xschem get wires] 2
set ::preserve_unchanged_attrs 0
xschem unselect_all; xschem select wire 0; xschem select wire 1
check "both wires selected" [xschem get lastsel] 2
catch {xschem edit_prop}
check "multi non-instance edit forces preserve=1" $::preserve_unchanged_attrs 1
check "wire edit reached the (stubbed) dialog" $::tl_calls 1
close_dialog

# --- 2. single NON-instance (one wire): do NOT force ------------------------------------
xschem clear force schematic
xschem wire 0 0 100 0
set ::preserve_unchanged_attrs 0
xschem unselect_all; xschem select wire 0
catch {xschem edit_prop}
check "single object leaves preserve untouched (0)" $::preserve_unchanged_attrs 0
check "single-wire edit reached the (stubbed) dialog" $::tl_calls 2
close_dialog

# --- 3. multi-select INSTANCES: do NOT force (slick-form "Apply to" scope governs) -------
xschem clear force schematic
xschem instance lab_pin.sym 0 0 0 0 {name=l1 lab=A}
xschem instance lab_pin.sym 0 50 0 0 {name=l2 lab=B}
check "two instances present" [xschem get instances] 2
set ::preserve_unchanged_attrs 0
xschem unselect_all; xschem select instance 0; xschem select instance 1
check "both instances selected" [xschem get lastsel] 2
catch {xschem edit_prop}
check "multi INSTANCE edit leaves preserve untouched (0)" $::preserve_unchanged_attrs 0
close_dialog

if {$::fails == 0} { puts "RESULT: ALL PASS (editprop_preserve)" } else { puts "RESULT: $::fails FAILURES (editprop_preserve)" }
flush stdout
