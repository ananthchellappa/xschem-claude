# ALT+SHIFT+ScrollWheel "transpose selected bus index" helper.
# Loaded from cadence_style_rc, AFTER bus_resize.tcl (reuses busresize::is_label_type,
# busresize::apply_changes and busresize::_split). See doc/claude/specs/bus_transpose_scroll.md.
#
# up (wheel up) / down (wheel down) SHIFTS the index/range on the name of every selected
# pin / net label (its `lab`) and instance (its `name`) -- it moves the index, it does NOT
# widen the bus (that is busresize / ALT+wheel):
#   up:   something -> something[0] -> something[1] ...;  something[N:M] -> something[N+1:M+1]
#   down: something[1] -> something[0] -> something (collapse); bare stays (floor);
#         something[N:M] -> something[N-1:M-1] but never negative (something[N:0] stays).
# Selected wires and text are tolerated (no effect). Native [] notation; the delimiters
# are vars below so a different convention is a one-line change.

namespace eval bustranspose {
  variable open  {[}
  variable close {]}
  variable sep   {:}
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

# up: range [a:b] -> [a+1:b+1]; single [N] -> [N+1]; bare scalar -> [0]; any other
# bracket form is left unchanged (never create a double bracket). Up never blocks.
proc bustranspose::up_name {n} {
  variable open ; variable close ; variable sep
  set r [busresize::_split $n]      ;# {base a b} for a [a:b] range, else {}
  if {$r ne {}} { lassign $r base a b ; return "$base$open[expr {$a+1}]$sep[expr {$b+1}]$close" }
  set p [_split $n]                 ;# {base i} for a single [i], else {}
  if {$p ne {}} { lassign $p base i ; return "$base$open[expr {$i+1}]$close" }
  if {[string index $n end] eq $close} { return $n }
  return "$n${open}0${close}"
}

# down: range [a:b] -> [a-1:b-1] unless EITHER endpoint would go negative (then unchanged;
# a range never collapses); single [0] -> bare (collapse), [N>0] -> [N-1]; bare scalar
# unchanged (floor). Any other bracket form unchanged.
proc bustranspose::down_name {n} {
  variable open ; variable close ; variable sep
  set r [busresize::_split $n]
  if {$r ne {}} {
    lassign $r base a b
    set na [expr {$a-1}] ; set nb [expr {$b-1}]
    if {$na < 0 || $nb < 0} { return $n }
    return "$base$open$na$sep$nb$close"
  }
  set p [_split $n]
  if {$p eq {}} { return $n }
  lassign $p base i
  if {$i <= 0} { return $base }
  return "$base$open[expr {$i-1}]$close"
}

# ALT+SHIFT+wheel entry point. dir is "up" or "down". Acts only on instance objects
# (label/pin -> lab, else -> name); wires, text and other types are skipped (tolerated).
# Collapses the whole selection to one undo step via busresize::apply_changes.
proc bustranspose_apply {dir} {
  if {$dir ne "up" && $dir ne "down"} return
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
    set nn [expr {$dir eq "up" ? [bustranspose::up_name $cur] \
                               : [bustranspose::down_name $cur]}]
    if {$nn ne $cur} { lappend changes [list instance $d(index) $attr $nn] }
  }
  busresize::apply_changes $changes
}
