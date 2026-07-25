# vpwl.tcl — custom dynamic Edit-Properties form for the devices/vpwl cell.
#
# This file ships WITH the cell (next to vpwl.sym) and is lazily sourced by
# slickprop::edit_form the first time a vpwl instance's properties are edited,
# because the symbol declares `edit_form=vpwl::edit_form` in its global K props.
# So all vpwl-specific UI lives in the library, not in xschem core (which carries
# only the generic edit_form dispatch). See doc/claude/specs/cell_custom_form.md.
#
# Model:
#   instance attrs  DC=<v>  pwl="t1 v1 t2 v2 ..."
#   netlist format  @name @pinlist @DC PWL(@pwl)   (in vpwl.sym)
# The form edits DC + a dynamic number of (time,value) rows and reassembles the
# single `pwl` string on Apply/OK. Later rows are greyed until earlier ones are
# complete (no gaps), so the joined PWL is always a valid ascending prefix.

namespace eval vpwl {}

# ---------------------------------------------------------------------------
# Pure helpers (headless-testable — no Tk)
# ---------------------------------------------------------------------------

# "t1 v1 t2 v2 ..." -> list of {time value} pairs (a trailing lone token is
# dropped: an odd count means an unfinished pair).
proc vpwl::split_pairs {pwl} {
  set toks [regexp -all -inline {\S+} $pwl]
  set pairs {}
  for {set i 0} {$i + 1 < [llength $toks]} {incr i 2} {
    lappend pairs [list [lindex $toks $i] [lindex $toks [expr {$i + 1}]]]
  }
  return $pairs
}

# The COMPLETE {time value} pairs from the start, stopping at the first
# incomplete one — the grey-cascade guarantees only a filled prefix is valid,
# so a PWL never has an interior gap.
proc vpwl::prefix_pairs {pairs} {
  set out {}
  foreach p $pairs {
    lassign $p t v
    if {[string trim $t] eq {} || [string trim $v] eq {}} break
    lappend out [list [string trim $t] [string trim $v]]
  }
  return $out
}

# Reassemble the filled prefix into "t1 v1 t2 v2 ...".
proc vpwl::join_pairs {pairs} {
  set out {}
  foreach p [vpwl::prefix_pairs $pairs] {
    lassign $p t v
    lappend out $t $v
  }
  return [join $out { }]
}

# {} when the pairs make a legal PWL (>= 2 complete leading points), else a
# human-readable reason.
proc vpwl::validate {pairs} {
  if {[llength [vpwl::prefix_pairs $pairs]] < 2} {
    return "enter at least 2 complete (time, value) points"
  }
  return {}
}

# ---------------------------------------------------------------------------
# Form (Tk)
# ---------------------------------------------------------------------------

# Snapshot the row entry variables into an ordered {time value} pair list of
# length `npts` (missing slots -> empty).
proc vpwl::collect_pairs {} {
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

# Grey-cascade: row 0 is always editable; row k is editable only when every
# earlier row is a complete (time AND value) pair. Runs on every keystroke.
proc vpwl::refresh_cascade {} {
  variable npts; variable tval; variable vval
  set f .dialog.pts
  if {![winfo exists $f]} return
  set n $npts
  if {![string is integer -strict $n] || $n < 2} { set n 2 }
  set prev_complete 1
  for {set k 0} {$k < $n} {incr k} {
    if {![winfo exists $f.t$k]} continue
    if {$prev_complete} {
      $f.t$k configure -state normal
      $f.v$k configure -state normal
      catch {$f.l$k configure -foreground {}}
    } else {
      $f.t$k configure -state disabled
      $f.v$k configure -state disabled
      catch {$f.l$k configure -foreground grey60}
    }
    set tc [expr {[info exists tval($k)] && [string trim $tval($k)] ne {}}]
    set vc [expr {[info exists vval($k)] && [string trim $vval($k)] ne {}}]
    set prev_complete [expr {$prev_complete && $tc && $vc}]
  }
}

# (Re)build the N (time,value) rows in the points frame, preserving any values
# already typed (they live in the namespace arrays, which survive the destroy).
proc vpwl::rebuild_rows {} {
  variable npts; variable tval; variable vval
  set f .dialog.pts
  if {![winfo exists $f]} return
  foreach w [winfo children $f] { destroy $w }
  set n $npts
  if {![string is integer -strict $n] || $n < 2} { set n 2 }
  label $f.hn -text {} -width 4
  label $f.ht -text {Time} -anchor w
  label $f.hv -text {Value} -anchor w
  grid $f.hn $f.ht $f.hv -sticky w -padx 4 -pady {0 2}
  catch {$f.ht configure -font slickPropLabel}
  catch {$f.hv configure -font slickPropLabel}
  for {set k 0} {$k < $n} {incr k} {
    if {![info exists tval($k)]} { set tval($k) {} }
    if {![info exists vval($k)]} { set vval($k) {} }
    label $f.l$k -text "[expr {$k + 1}]" -anchor e -width 4
    entry $f.t$k -textvariable vpwl::tval($k) -width 14
    entry $f.v$k -textvariable vpwl::vval($k) -width 14
    grid $f.l$k $f.t$k $f.v$k -sticky we -padx 4 -pady 1
    bind $f.t$k <KeyRelease> vpwl::refresh_cascade
    bind $f.v$k <KeyRelease> vpwl::refresh_cascade
    catch {$f.t$k configure -font slickPropValue}
    catch {$f.v$k configure -font slickPropValue}
  }
  grid columnconfigure $f 1 -weight 1
  grid columnconfigure $f 2 -weight 1
  vpwl::refresh_cascade
}

# "Number of points" changed (spinbox arrows or typing): rebuild rows once the
# value is a valid integer >= 2; ignore transient junk mid-typing.
proc vpwl::on_npts {} {
  variable npts
  if {![string is integer -strict $npts] || $npts < 2} { return }
  vpwl::rebuild_rows
}

# Write the edited DC + reassembled pwl back onto the instance. Returns 1 on a
# successful apply, 0 if validation blocked it.
proc vpwl::apply {} {
  variable inst; variable dc
  if {$inst eq {}} { return 0 }
  set pairs [vpwl::collect_pairs]
  set err [vpwl::validate $pairs]
  if {$err ne {}} {
    catch {tk_messageBox -parent .dialog -icon warning -type ok -title {PWL source} -message $err}
    return 0
  }
  set pwl [vpwl::join_pairs $pairs]
  set d [string trim $dc]
  if {$d eq {}} { set d 0 }
  if {[xschem get readonly]} { return 0 }
  xschem setprop instance $inst DC $d
  xschem setprop instance $inst pwl $pwl
  set ::tctx::applied 1
  catch {xschem redraw}
  return 1
}

proc vpwl::ok {} {
  if {[vpwl::apply]} { catch {destroy .dialog} }
}

# The custom Edit-Properties form for a vpwl instance. Signature + return
# ({} always) match schpin::edit_form, the built-in pin-form precedent that
# slickprop::edit_form dispatches to the same way.
proc vpwl::edit_form {} {
  variable inst; variable dc; variable npts; variable tval; variable vval
  global symbol
  set ::tctx::rcode {}
  if {[winfo exists .dialog]} { return {} }
  catch {slickprop::init_fonts}

  set inst [xschem get_tok $::tctx::retval name 2]
  set dc   [xschem get_tok $::tctx::retval DC 2]
  set pwl  [xschem get_tok $::tctx::retval pwl 2]
  if {[string trim $dc] eq {}} { set dc 0 }

  array unset tval; array unset vval
  set pairs [vpwl::split_pairs $pwl]
  set i 0
  foreach p $pairs {
    set tval($i) [lindex $p 0]; set vval($i) [lindex $p 1]; incr i
  }
  set npts [expr {max(2, [llength $pairs])}]
  for {set k 0} {$k < $npts} {incr k} {
    if {![info exists tval($k)]} { set tval($k) {} }
    if {![info exists vval($k)]} { set vval($k) {} }
  }

  toplevel .dialog -class Dialog
  wm title .dialog {Edit PWL Source}
  set X [expr {[winfo pointerx .dialog] - 60}]
  set Y [expr {[winfo pointery .dialog] - 35}]
  wm geometry .dialog "+$X+$Y"
  catch {label .dialog.hdr -text "  $inst  —  [file tail $symbol]" -bg grey60 -anchor w -font slickPropHeader}
  if {![winfo exists .dialog.hdr]} {
    label .dialog.hdr -text "  $inst  —  [file tail $symbol]" -bg grey60 -anchor w
  }
  pack .dialog.hdr -side top -fill x

  frame .dialog.top
  grid [label .dialog.top.ldc -text {DC Voltage:} -anchor w] -row 0 -column 0 -sticky w -padx 4 -pady 4
  grid [entry .dialog.top.edc -textvariable vpwl::dc -width 16] -row 0 -column 1 -sticky w -padx 4
  grid [label .dialog.top.ln -text {Number of points:} -anchor w] -row 1 -column 0 -sticky w -padx 4 -pady 4
  grid [spinbox .dialog.top.en -from 2 -to 999 -increment 1 -width 6 \
        -textvariable vpwl::npts -command vpwl::on_npts] -row 1 -column 1 -sticky w -padx 4
  bind .dialog.top.en <KeyRelease> vpwl::on_npts
  catch {.dialog.top.ldc configure -font slickPropLabel}
  catch {.dialog.top.edc configure -font slickPropValue}
  catch {.dialog.top.ln configure -font slickPropLabel}
  pack .dialog.top -side top -fill x

  frame .dialog.pts
  pack .dialog.pts -side top -fill both -expand 1 -padx 4 -pady 4

  frame .dialog.b
  button .dialog.b.ok     -text OK     -command vpwl::ok
  button .dialog.b.apply  -text Apply  -command vpwl::apply
  button .dialog.b.cancel -text Cancel -command {destroy .dialog}
  pack .dialog.b.ok .dialog.b.apply .dialog.b.cancel -side left -expand 1 -fill x
  pack .dialog.b -side bottom -fill x -pady 3
  bind .dialog <Escape> {destroy .dialog}

  vpwl::rebuild_rows
  raise .dialog
  focus .dialog.top.edc
  return {}
}
