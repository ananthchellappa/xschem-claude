# ALT+SHIFT+ScrollWheel "transpose selected bus index" helper.
# Loaded from cadence_style_rc, AFTER bus_resize.tcl (reuses busresize::is_label_type
# and busresize::apply_changes). See doc/claude/specs/bus_transpose_scroll.md.
#
# grow (wheel up) / shrink (wheel down) steps the single [N] bus index on the name of
# every selected pin / net label (its `lab`) and instance (its `name`):
#   something -> something[0] -> something[1] -> ...   (grow)
#   something[1] -> something[0] -> something          (shrink; [0] collapses; floor)
# Selected wires and text are tolerated (no effect). Native [] notation; the delimiters
# are vars below so a different convention is a one-line change.

namespace eval bustranspose {
  variable open  {[}
  variable close {]}
}

# If $n ends with <open><integer><close>, return {base index}; else {}.
proc bustranspose::_split {n} {
  variable open ; variable close
  if {[string index $n end] ne $close} { return {} }
  set body [string range $n 0 end-1]
  set op [string last $open $body]
  if {$op < 0} { return {} }
  set base [string range $body 0 [expr {$op-1}]]
  set idx  [string range $body [expr {$op+1}] end]
  if {![string is integer -strict $idx]} { return {} }
  return [list $base $idx]
}

# scalar -> base[0]; base[N] -> base[N+1]; a non-[int] bracket form (e.g. a [N:M]
# range) is left unchanged so we never produce a double bracket.
proc bustranspose::grow_name {n} {
  variable open ; variable close
  set p [_split $n]
  if {$p ne {}} { lassign $p base i ; return "$base$open[expr {$i+1}]$close" }
  if {[string index $n end] eq $close} { return $n }
  return "$n${open}0${close}"
}

# base[N] (N>0) -> base[N-1]; base[0] -> base (collapse); scalar / non-[int] -> same
# (floor, never negative).
proc bustranspose::shrink_name {n} {
  variable open ; variable close
  set p [_split $n]
  if {$p eq {}} { return $n }
  lassign $p base i
  if {$i <= 0} { return $base }
  return "$base$open[expr {$i-1}]$close"
}

# ALT+SHIFT+wheel entry point. dir is "grow" or "shrink". Acts only on instance objects
# (label/pin -> lab, else -> name); wires, text and other types are skipped (tolerated).
# Collapses the whole selection to one undo step via busresize::apply_changes.
proc bustranspose_apply {dir} {
  if {$dir ne "grow" && $dir ne "shrink"} return
  if {[xschem get lastsel] == 0} {
    ciw_echo "transpose: select pins, net labels or instances first"
    return
  }
  set changes {}
  foreach o [xschem objects -selected] {
    array unset d ; array set d $o
    if {$d(type) ne "instance"} continue   ;# wires, text, etc.: no effect (tolerated)
    if {[busresize::is_label_type [xschem getprop instance $d(index) cell::type]]} {
      set attr lab
    } else {
      set attr name
    }
    set cur [xschem getprop instance $d(index) $attr]
    set nn [expr {$dir eq "grow" ? [bustranspose::grow_name $cur] \
                                 : [bustranspose::shrink_name $cur]}]
    if {$nn ne $cur} { lappend changes [list instance $d(index) $attr $nn] }
  }
  busresize::apply_changes $changes
}
