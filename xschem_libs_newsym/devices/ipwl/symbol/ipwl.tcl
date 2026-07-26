# ipwl.tcl — field customization for the devices/ipwl cell, consumed by the
# GENERIC Edit-Properties form (slickprop). The symbol declares `edit_form=ipwl`;
# slickprop::build_fields lazily sources this file (next to ipwl.sym) and asks it
# to (a) relabel fields and (b) render the `pwl` token with a dynamic (time,value)
# point editor instead of a plain text entry — because the number of points
# varies. Everything else (Apply-to, Library/Cell/View, Name, DC) is the standard
# generic form. See doc/claude/specs/cell_custom_form.md.
#
# API (all optional; called from slickprop::build_fields / field_value):
#   field_labels          -> dict {token -> friendly label}
#   field_custom          -> list of tokens this cell renders itself
#   field_build tok frame value  -> pack the custom widget for <tok> into <frame>,
#                                    seeded from the current value string
#   field_get   tok        -> the token's current value string (read back on apply)

namespace eval ipwl {}

# --- pure helpers (headless-testable) ---------------------------------------

# "t1 v1 t2 v2 ..." -> list of {time value} pairs (trailing lone token dropped).
proc ipwl::split_pairs {pwl} {
  set toks [regexp -all -inline {\S+} $pwl]
  set pairs {}
  for {set i 0} {$i + 1 < [llength $toks]} {incr i 2} {
    lappend pairs [list [lindex $toks $i] [lindex $toks [expr {$i + 1}]]]
  }
  return $pairs
}
# complete pairs from the start, stopping at the first incomplete one (the
# grey-cascade guarantees only a filled prefix is valid — no interior gap).
proc ipwl::prefix_pairs {pairs} {
  set out {}
  foreach p $pairs {
    lassign $p t v
    if {[string trim $t] eq {} || [string trim $v] eq {}} break
    lappend out [list [string trim $t] [string trim $v]]
  }
  return $out
}
proc ipwl::join_pairs {pairs} {
  set out {}
  foreach p [ipwl::prefix_pairs $pairs] { lassign $p t v; lappend out $t $v }
  return [join $out { }]
}

# --- field-customization API ------------------------------------------------

proc ipwl::field_labels {} { return {DC {DC Voltage}} }
proc ipwl::field_custom {} { return {pwl} }

# read the row entry vars into an ordered {time value} list of length npts
proc ipwl::collect_pairs {} {
  variable npts; variable tval; variable vval
  set n $npts
  if {![string is integer -strict $n] || $n < 2} { set n 2 }
  set pairs {}
  for {set k 0} {$k < $n} {incr k} {
    set t {}; set v {}
    if {[info exists tval($k)]} { set t $tval($k) }
    if {[info exists vval($k)]} { set v $vval($k) }
    lappend pairs [list $t $v]
  }
  return $pairs
}

# grey-cascade: row k editable only when every earlier row is a complete pair.
proc ipwl::refresh_cascade {} {
  variable npts; variable tval; variable vval; variable ptsframe
  if {![info exists ptsframe] || ![winfo exists $ptsframe]} return
  set n $npts
  if {![string is integer -strict $n] || $n < 2} { set n 2 }
  set prev 1
  for {set k 0} {$k < $n} {incr k} {
    if {![winfo exists $ptsframe.t$k]} continue
    if {$prev} {
      $ptsframe.t$k configure -state normal;   $ptsframe.v$k configure -state normal
      catch {$ptsframe.l$k configure -foreground {}}
    } else {
      $ptsframe.t$k configure -state disabled; $ptsframe.v$k configure -state disabled
      catch {$ptsframe.l$k configure -foreground grey60}
    }
    set tc [expr {[info exists tval($k)] && [string trim $tval($k)] ne {}}]
    set vc [expr {[info exists vval($k)] && [string trim $vval($k)] ne {}}]
    set prev [expr {$prev && $tc && $vc}]
  }
}

# (re)build the N (time,value) rows in the points sub-frame, preserving values.
proc ipwl::rebuild_rows {} {
  variable npts; variable tval; variable vval; variable ptsframe
  if {![info exists ptsframe] || ![winfo exists $ptsframe]} return
  foreach w [winfo children $ptsframe] { destroy $w }
  set n $npts
  if {![string is integer -strict $n] || $n < 2} { set n 2 }
  label $ptsframe.hn -text {} -width 3
  label $ptsframe.ht -text {Time} -anchor w
  label $ptsframe.hv -text {Value} -anchor w
  grid $ptsframe.hn $ptsframe.ht $ptsframe.hv -sticky w -padx 4 -pady {0 2}
  catch {$ptsframe.ht configure -font slickPropLabel}
  catch {$ptsframe.hv configure -font slickPropLabel}
  for {set k 0} {$k < $n} {incr k} {
    if {![info exists tval($k)]} { set tval($k) {} }
    if {![info exists vval($k)]} { set vval($k) {} }
    label $ptsframe.l$k -text "[expr {$k + 1}]" -anchor e -width 3
    entry $ptsframe.t$k -textvariable ipwl::tval($k) -width 12
    entry $ptsframe.v$k -textvariable ipwl::vval($k) -width 12
    grid $ptsframe.l$k $ptsframe.t$k $ptsframe.v$k -sticky we -padx 4 -pady 1
    bind $ptsframe.t$k <KeyRelease> ipwl::refresh_cascade
    bind $ptsframe.v$k <KeyRelease> ipwl::refresh_cascade
    catch {$ptsframe.t$k configure -font slickPropValue}
    catch {$ptsframe.v$k configure -font slickPropValue}
  }
  ipwl::refresh_cascade
}

proc ipwl::on_npts {} {
  variable npts
  if {![string is integer -strict $npts] || $npts < 2} { return }
  ipwl::rebuild_rows
}

# Build the inline PWL editor into $frame, seeded from the pwl string $value.
proc ipwl::field_build {tok frame value} {
  variable npts; variable tval; variable vval; variable ptsframe
  catch {slickprop::init_fonts}
  array unset tval; array unset vval
  set pairs [ipwl::split_pairs $value]
  set i 0
  foreach p $pairs { set tval($i) [lindex $p 0]; set vval($i) [lindex $p 1]; incr i }
  set npts [expr {max(2, [llength $pairs])}]
  label   $frame.lbl -text {PWL points:} -anchor w
  spinbox $frame.n -from 2 -to 999 -increment 1 -width 5 \
    -textvariable ipwl::npts -command ipwl::rebuild_rows
  bind $frame.n <KeyRelease> ipwl::on_npts
  grid $frame.lbl -row 0 -column 0 -sticky w -padx 4 -pady 2
  grid $frame.n   -row 0 -column 1 -sticky w -padx 4 -pady 2
  catch {$frame.lbl configure -font slickPropLabel}
  set ptsframe $frame.pts
  frame $ptsframe
  grid $ptsframe -row 1 -column 0 -columnspan 2 -sticky we -padx 2
  ipwl::rebuild_rows
}

# Read the editor back as a "t1 v1 t2 v2 ..." string (filled prefix only).
proc ipwl::field_get {tok} { return [ipwl::join_pairs [ipwl::collect_pairs]] }
