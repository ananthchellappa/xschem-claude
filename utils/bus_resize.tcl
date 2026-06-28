# ALT+ScrollWheel "grow / shrink selected" helper.
# Loaded from cadence_style_rc. Pure Tcl over the `xschem` object/prop API.
# See doc/claude/specs/bus_thickness_scroll.md.
#
# grow (wheel up) / shrink (wheel down), applied to every selected object:
#   wire                      -> increase / decrease drawn thickness ~10% (visible step)
#   pin / net label           -> grow / shrink the bus suffix on its `lab` net name
#   other instance            -> grow / shrink the bus suffix on its instance `name`
# Bus suffix uses xschem's native [N:M] notation; the delimiters live in the vars
# below so a different convention (e.g. <>) is a one-line change.

namespace eval busresize {
  variable open  {[}      ;# bus-index open delimiter
  variable close {]}      ;# bus-index close delimiter
  variable sep   {:}      ;# high:low separator

  variable wire_factor    1.1   ;# thickness multiply / divide per notch (~10%)
  variable wire_min_step  0.5   ;# guarantee a visible change even for small values
  variable wire_start     2.0   ;# thickness a plain wire jumps to on first grow
  variable wire_true_base 4.0   ;# numeric read of a legacy thick bus (bus=true)
}

# ---- bus-name transform (pure; delimiter-agnostic, no regex metachar pitfalls) ----

# If $n ends with <open><int><sep><int><close>, return {base a b}; else {}.
proc busresize::_split {n} {
  variable open ; variable close ; variable sep
  if {[string index $n end] ne $close} { return {} }
  set body [string range $n 0 end-1]
  set op [string last $open $body]
  if {$op < 0} { return {} }
  set base  [string range $body 0 [expr {$op-1}]]
  set parts [split [string range $body [expr {$op+1}] end] $sep]
  if {[llength $parts] != 2} { return {} }
  lassign $parts a b
  if {![string is integer -strict $a] || ![string is integer -strict $b]} { return {} }
  return [list $base $a $b]
}

# scalar -> base[1:0]; base[N:M] -> widen by extending the larger end.
proc busresize::grow_name {n} {
  variable open ; variable close ; variable sep
  set p [_split $n]
  if {$p eq {}} { return "$n${open}1${sep}0${close}" }
  lassign $p base a b
  if {$a >= $b} { incr a } else { incr b }
  return "$base$open$a$sep$b$close"
}

# base[N:M] -> shrink the larger end by 1; collapse a 2-bit bus to the bare base;
# a scalar is the floor (unchanged, never negative).
proc busresize::shrink_name {n} {
  variable open ; variable close ; variable sep
  set p [_split $n]
  if {$p eq {}} { return $n }
  lassign $p base a b
  if {$a >= $b} {
    set na [expr {$a-1}]
    if {$na <= $b} { return $base }
    return "$base$open$na$sep$b$close"
  } else {
    set nb [expr {$b-1}]
    if {$nb <= $a} { return $base }
    return "$base$open$a$sep$nb$close"
  }
}

# ---- wire thickness model (stored in the numeric `bus` property) ----

# Numeric thickness for a raw `bus` token: positive number as-is; a legacy thick bus
# (true/1/yes/on) as the baseline; empty/0/false = plain wire (0 = the minimum).
proc busresize::wire_thickness {tok} {
  variable wire_true_base
  set t [string tolower [string trim $tok]]
  if {$t eq {}} { return 0.0 }
  if {$t in {true yes on}} { return $wire_true_base }
  if {[string is double -strict $tok] && $tok > 0} { return [expr {double($tok)}] }
  return 0.0
}

proc busresize::_round {x} { return [expr {round($x*100)/100.0}] }

proc busresize::wire_grow {tok} {
  variable wire_factor ; variable wire_min_step ; variable wire_start
  set t [wire_thickness $tok]
  if {$t <= 0} { return $wire_start }
  set nt [expr {$t * $wire_factor}]
  if {$nt < $t + $wire_min_step} { set nt [expr {$t + $wire_min_step}] }
  return [_round $nt]
}

proc busresize::wire_shrink {tok} {
  variable wire_factor ; variable wire_min_step ; variable wire_start
  set t [wire_thickness $tok]
  if {$t <= 0} { return 0 }
  set nt [expr {$t / $wire_factor}]
  if {$nt > $t - $wire_min_step} { set nt [expr {$t - $wire_min_step}] }
  if {$nt < $wire_start} { return 0 }
  return [_round $nt]
}

# Symbol types whose visible name is the `lab` net/pin name (not the instance name).
proc busresize::is_label_type {t} {
  return [expr {$t in {label ipin opin iopin scope show_label bus_tap}}]
}

# Apply a list of changes as ONE undo step (shared by busresize and bustranspose).
# Each change is {kind index arg value}, kind = wire | instance. A wheel notch is one
# user operation, so in xschem's snapshot-undo model we push_undo exactly once and then
# use the non-snapshotting `setprop -fast`. The fast path skips symbol_bbox, so each
# changed instance's bbox is refreshed (recompute_inst_bbox) to keep hit-testing/
# re-selection correct, then a single redraw paints the result. Empty list -> nothing
# happens (no undo step pushed).
proc busresize::apply_changes {changes} {
  if {![llength $changes]} return
  xschem push_undo
  foreach c $changes {
    lassign $c kind idx arg val
    if {$kind eq "wire"} {
      xschem setprop -fast wire $idx $arg $val
    } else {
      xschem setprop -fast instance $idx $arg $val
      xschem recompute_inst_bbox $idx
    }
  }
  xschem redraw
}

# ---- the action entry point (global proc, named by the registered action) ----

# dir is "grow" or "shrink". One wheel notch is ONE user operation, so the whole
# selection collapses to a SINGLE undo step: in xschem's snapshot-undo model that means
# push_undo exactly once and then apply every change with the non-snapshotting `-fast`
# setprop. The fast path also skips the instance bbox recompute (symbol_bbox), so each
# changed instance is refreshed afterwards via `xschem recompute_inst_bbox` to keep
# hit-testing/selection correct, then a single redraw paints the result.
# A first pass computes only the real changes, so an all-no-op gesture (e.g. shrinking
# an all-scalar selection) pushes no undo step at all.
proc busresize_apply {dir} {
  if {$dir ne "grow" && $dir ne "shrink"} return
  if {[xschem get lastsel] == 0} {
    ciw_echo "grow/shrink: select wires, labels, pins or instances first"
    return
  }
  # pass 1: collect the changes that actually differ -> {kind index arg value}
  set changes {}
  foreach o [xschem objects -selected] {
    array unset d ; array set d $o
    switch -- $d(type) {
      wire {
        set cur [xschem getprop wire $d(index) bus]
        set nt [expr {$dir eq "grow" ? [busresize::wire_grow $cur] \
                                     : [busresize::wire_shrink $cur]}]
        if {$nt != [busresize::wire_thickness $cur]} {
          lappend changes [list wire $d(index) bus $nt]
        }
      }
      instance {
        if {[busresize::is_label_type [xschem getprop instance $d(index) cell::type]]} {
          set attr lab
        } else {
          set attr name
        }
        set cur [xschem getprop instance $d(index) $attr]
        set nn [expr {$dir eq "grow" ? [busresize::grow_name $cur] \
                                     : [busresize::shrink_name $cur]}]
        if {$nn ne $cur} { lappend changes [list instance $d(index) $attr $nn] }
      }
    }
  }
  # pass 2: apply as a single undo step (shared with bustranspose)
  busresize::apply_changes $changes
}
