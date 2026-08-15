# Issue 0170 — the Edit-Properties field area rendered EMPTY: the scrollable
# content frame (.dialog.fa.c.inner) got pinned to 1 pixel wide.
#
# The field rows are created, mapped and gridded correctly; they are simply
# clipped, because the canvas window item's -width was driven from the INNER
# FRAME's <Configure>. That event can arrive while the canvas is still 1px wide
# (`itemconfigure inner -width 1`), which shrinks inner to 1 — and inner then
# never changes size again, so no further <Configure> fires on it and a later
# canvas resize can never widen it. The width must come from the CANVAS's own
# <Configure> (%w), which does fire again when the real size arrives.
#
# Reported symptom: an Edit Properties dialog with a correct header, Library/
# Cell/View and Name rows, and a tall EMPTY grey field area. Measured in the
# user's session: `Frame inner map=1 1x142+0+0 req=460x142`.
#
# Needs a real display (the dialog is Tk):
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_prop_form_field_width_0170.tcl
if {[catch {winfo exists .}]} { puts "RESULT: SKIP (needs Tk/X; the form is a Tk dialog)"; flush stdout; exit 0 }
update idletasks

set fail 0; set npass 0
proc check {name got exp} { global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp})"; incr fail } }
proc check_true {name c} { check $name [expr {$c ? 1 : 0}] 1 }
proc settle {{n 6}} { for {set i 0} {$i < $n} {incr i} { update idletasks; update } }
proc close_dialog {} {
  catch {while {[winfo exists .dialog]} { catch {slickprop::cancel}; catch {destroy .dialog}; update }}
}

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
# devices/vpwl is the cell the defect was reported on (its custom PWL editor is
# the widest row), but nothing here is cell-specific — any templated symbol shows it.
set sym [file join $repo xschem_libs_newsym devices vpwl symbol vpwl.sym]

close_dialog
xschem clear force schematic
catch {xschem load_symbol $sym}
catch {xschem instance $sym 100 100 0 0}
xschem select_all
catch {xschem edit_prop}
settle
check_true "dialog opened" [winfo exists .dialog]
check "field tokens built" $::slickprop::cur(tokens) {name DC pwl}

set inner .dialog.fa.c.inner
set canv  .dialog.fa.c

# --- 1. steady state: the content frame is as wide as the canvas, not 1px ----
check_true "inner frame is wider than 1px"      [expr {[winfo width $inner] > 1}]
check_true "inner frame tracks the canvas width" \
  [expr {[winfo width $inner] >= [winfo width $canv] - 2}]
check_true "the field rows have real width"     [expr {[winfo width $inner.e0] > 1}]
check_true "the custom PWL frame has real width" [expr {[winfo width $inner.cf1] > 1}]

# --- 2. the defect mechanism, deterministically -----------------------------
# Pin the item to 1px exactly as a too-early <Configure> would, then give the
# canvas a real size. The canvas <Configure> must widen the content back. With
# the width driven off the INNER frame's <Configure> instead, inner stays 1
# forever: it is not resized, so its <Configure> never fires again.
$canv itemconfigure inner -width 1
settle
check "pinned to 1px (precondition)" [winfo width $inner] 1
# resize the TOPLEVEL (what a user dragging the dialog edge does): the canvas is
# packed -fill both -expand yes, so this is what actually changes its width and
# fires <Configure> on it. `$canv configure -width` alone only sets a REQUESTED
# size the packer overrides, which is why dragging the dialog never healed it.
wm geometry .dialog [expr {[winfo width .dialog] + 60}]x[winfo height .dialog]
settle 12
check_true "a dialog resize un-pins the content frame" [expr {[winfo width $inner] > 1}]
check_true "content frame followed the new canvas width" \
  [expr {[winfo width $inner] >= [winfo width $canv] - 2}]

# --- 3. structural guard: which <Configure> owns the width ------------------
check_true "canvas <Configure> sets the item width" \
  [string match {*itemconfigure inner*} [bind $canv <Configure>]]
check_true "inner <Configure> does NOT set the item width" \
  [expr {![string match {*itemconfigure inner*} [bind $inner <Configure>]]}]
check_true "canvas <Configure> guards against a 1px width" \
  [string match {*%w > 1*} [bind $canv <Configure>]]

close_dialog
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
