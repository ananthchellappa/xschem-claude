# CTRL+Plus / CTRL+Minus "grow / shrink displayed text size" helper.
# Loaded from cadence_style_rc, AFTER bus_resize.tcl (reuses busresize::apply_changes).
# See doc/claude/specs/text_size_scroll.md.
#
# grow (Ctrl+Plus) / shrink (Ctrl+Minus) the DISPLAYED text size of every selected:
#   text note            -> its own size (xscale=yscale)
#   pin / net label       -> the displayed @lab NAME text size (per-instance text_size_N;
#                            the instance auto-name is NOT touched)
# Other object types (wires, normal instances, ...) are ignored. ~10% per step, but
# always at least min_step; shrink never goes below a per-type floor.

namespace eval textsize {
  variable factor   1.1    ;# grow x1.1 / shrink x0.9 (~10%)
  variable min_step 0.05   ;# guarantee a visible change for small sizes
  variable min_text  0.1   ;# floor for a text note
  variable min_label 0.1   ;# floor for a pin/net-label name
}

proc textsize::_round {x} { return [expr {round($x*1000)/1000.0}] }

# grow: at least +min_step, otherwise +10%.
proc textsize::grow {s} {
  variable factor ; variable min_step
  if {![string is double -strict $s] || $s <= 0} { set s 0.1 }
  set nt [expr {$s * $factor}]
  if {$nt < $s + $min_step} { set nt [expr {$s + $min_step}] }
  return [_round $nt]
}

# shrink: at least -min_step, otherwise -10%; never below $floor.
proc textsize::shrink {s floor} {
  variable factor ; variable min_step
  if {![string is double -strict $s] || $s <= 0} { return $floor }
  set nt [expr {$s * (2.0 - $factor)}]     ;# factor 1.1 -> x0.9
  if {$nt > $s - $min_step} { set nt [expr {$s - $min_step}] }
  if {$nt < $floor} { set nt $floor }
  return [_round $nt]
}

# Ctrl+Plus / Ctrl+Minus entry point. dir is "grow" or "shrink". Acts on text notes and
# pin/net-label name texts; everything else is ignored. One press = one undo step
# (busresize::apply_changes). An all-no-op / all-at-floor gesture pushes no undo step.
proc textsize_apply {dir} {
  if {$dir ne "grow" && $dir ne "shrink"} return
  if {[xschem get lastsel] == 0} {
    ciw_echo "text size: select text notes, pins or net labels first"
    return
  }
  set changes {}
  foreach o [xschem objects -selected] {
    array unset d ; array set d $o
    switch -- $d(type) {
      text {
        set cur [xschem getprop text $d(index) size]
        set nt [expr {$dir eq "grow" ? [textsize::grow $cur] \
                                     : [textsize::shrink $cur $textsize::min_text]}]
        if {$nt != $cur} { lappend changes [list text $d(index) size $nt] }
      }
      instance {
        set info [xschem inst_name_text $d(index)]
        if {$info eq {}} continue           ;# not a pin/net label (no @lab text)
        lassign $info ti cur
        set nt [expr {$dir eq "grow" ? [textsize::grow $cur] \
                                     : [textsize::shrink $cur $textsize::min_label]}]
        if {$nt != $cur} { lappend changes [list instance $d(index) text_size_$ti $nt] }
      }
    }
  }
  busresize::apply_changes $changes
}
