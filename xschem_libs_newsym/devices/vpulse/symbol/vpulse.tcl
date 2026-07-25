# vpulse.tcl — custom (static) Edit-Properties form for the devices/vpulse cell.
#
# Ships WITH the cell (next to vpulse.sym); lazily sourced by slickprop::edit_form
# the first time a vpulse instance is edited, because the symbol declares
# `edit_form=vpulse::edit_form`. Same hook as devices/vpwl, but the field set is
# FIXED (no dynamic rows) — this form only exists to give the ngspice PULSE
# parameters friendly labels. See doc/claude/specs/cell_custom_form.md.
#
# Model:
#   instance attrs  DC Vinit Vpulse TD TR TF PW PER
#   netlist format  @name @pinlist @DC PULSE(@Vinit @Vpulse @TD @TR @TF @PW @PER )
# ngspice PULSE(V1 V2 TD TR TF PW PER): V1=initial value, V2=pulsed value,
# TD=delay, TR=rise time, TF=fall time, PW=pulse width, PER=period. DC is the
# operating-point / DC-analysis value.

namespace eval vpulse {}

# Ordered {token label} pairs — the form rows, top to bottom. DC first, then the
# PULSE parameters in ngspice positional order.
proc vpulse::fields {} {
  return [list \
    DC     {DC Voltage} \
    Vinit  {Initial Value (V1)} \
    Vpulse {Pulsed Value (V2)} \
    TD     {Delay Time (TD)} \
    TR     {Rise Time (TR)} \
    TF     {Fall Time (TF)} \
    PW     {Pulse Width (PW)} \
    PER    {Period (PER)}]
}

# Write every field back onto the instance (empty -> 0). Returns 1 on apply.
proc vpulse::apply {} {
  variable inst; variable val
  if {$inst eq {}} { return 0 }
  if {[xschem get readonly]} { return 0 }
  foreach {tok lbl} [vpulse::fields] {
    set v {}
    if {[info exists val($tok)]} { set v [string trim $val($tok)] }
    if {$v eq {}} { set v 0 }
    xschem setprop instance $inst $tok $v
  }
  set ::tctx::applied 1
  catch {xschem redraw}
  return 1
}

proc vpulse::ok {} { if {[vpulse::apply]} { catch {destroy .dialog} } }

# The custom form (signature + {} return match schpin::edit_form / vpulse's
# sibling vpwl::edit_form).
proc vpulse::edit_form {} {
  variable inst; variable val
  global symbol
  set ::tctx::rcode {}
  if {[winfo exists .dialog]} { return {} }
  catch {slickprop::init_fonts}

  set inst [xschem get_tok $::tctx::retval name 2]
  array unset val
  foreach {tok lbl} [vpulse::fields] {
    set val($tok) [xschem get_tok $::tctx::retval $tok 2]
  }

  toplevel .dialog -class Dialog
  wm title .dialog {Edit Pulse Source}
  set X [expr {[winfo pointerx .dialog] - 60}]
  set Y [expr {[winfo pointery .dialog] - 35}]
  wm geometry .dialog "+$X+$Y"
  catch {label .dialog.hdr -text "  $inst  —  [file tail $symbol]" -bg grey60 -anchor w -font slickPropHeader}
  if {![winfo exists .dialog.hdr]} {
    label .dialog.hdr -text "  $inst  —  [file tail $symbol]" -bg grey60 -anchor w
  }
  pack .dialog.hdr -side top -fill x

  frame .dialog.f
  set r 0
  foreach {tok lbl} [vpulse::fields] {
    grid [label .dialog.f.l$tok -text "$lbl:" -anchor w] -row $r -column 0 -sticky w -padx 4 -pady 3
    grid [entry .dialog.f.e$tok -textvariable vpulse::val($tok) -width 18] -row $r -column 1 -sticky we -padx 4
    catch {.dialog.f.l$tok configure -font slickPropLabel}
    catch {.dialog.f.e$tok configure -font slickPropValue}
    incr r
  }
  grid columnconfigure .dialog.f 1 -weight 1
  pack .dialog.f -side top -fill x -padx 4 -pady 4

  frame .dialog.b
  button .dialog.b.ok     -text OK     -command vpulse::ok
  button .dialog.b.apply  -text Apply  -command vpulse::apply
  button .dialog.b.cancel -text Cancel -command {destroy .dialog}
  pack .dialog.b.ok .dialog.b.apply .dialog.b.cancel -side left -expand 1 -fill x
  pack .dialog.b -side bottom -fill x -pady 3
  bind .dialog <Escape> {destroy .dialog}

  raise .dialog
  focus .dialog.f.eDC
  return {}
}
