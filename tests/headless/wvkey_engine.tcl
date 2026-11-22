# What the waveform viewer's key rows read out of the ENGINE, for two suites:
# tests/headless/test_wave_subwindows.tcl (rows SWK20 to SWK27) and
# tests/headless/test_wave_viewer.tcl (row KM13). Sourced by them; it starts
# nothing and checks nothing by itself.
#
# The viewer's key filter (wviewer::key_filter, src/wave_viewer.tcl) forwards a
# graph key only as a chord the engine hands to the graph. The procs here give
# a suite the engine's side of that, from the engine's own text and table and
# from nothing of the filter's:
#   kc_cfacts  numbers the Tcl side restates, read out of src/callback.c and
#              src/xschem.h with the C comments removed
#   kc_masks   the modifier bits callback() takes off a key's state, as numbers
#   kc_guards  the arms of the key switch that open with the bare graph test
#   kc_expect  the comparand: is chord (N, s) one the engine hands to the graph
#              in this profile, and with which state
# kc_expect combines its inputs by the steps wviewer::key_chord takes. It is no
# second reading of the engine's control flow.

# What the Tcl side restates of the engine in numbers:
#   excl    the ui_state bits of waves_selected's `excl` set, each name looked
#           up in src/xschem.h (a name with no #define comes back as ?NAME)
#   border  the factor of waves_selected's border (pixels per unit of Tk
#           scaling)
#   strip   the mask names callback() takes off the state, and off the copy
#           it decides a key by
#   range   the bit count callback() keeps of the state
proc kc_cfacts {csrc hsrc} {
  set out [dict create excl {} border {} strip {} range {}]
  set a [string first "\nstatic int waves_selected(" $csrc]
  if {$a >= 0} {
    set body [string range $csrc $a [string first "\n\x7d\n" $csrc $a]]
    regsub -all {/\*.*?\*/} $body {} body
    if {[regexp {\mexcl\s*=\s*([A-Z_|\s]+);} $body -> names]} {
      set bits {}
      foreach nm [split $names |] {
        set nm [string trim $nm]
        set v ?$nm
        regexp -line "^#define $nm (\\d+)U?\\M" $hsrc -> v
        lappend bits $v
      }
      dict set out excl $bits
    }
    if {[regexp {\mborder\s*=\s*([0-9.]+)\s*\*\s*tk_scaling\s*\*\s*xctx->zoom\s*;} $body -> f]} {
      dict set out border $f
    }
  }
  set a [string first "\nint callback(" $csrc]
  if {$a >= 0} {
    set body [string range $csrc $a [string first "\n\x7d\n" $csrc $a]]
    regsub -all {/\*.*?\*/} $body {} body
    set strip {}
    foreach {all nm} [regexp -all -inline {\n\s*r?state\s*&=\s*~(\w+)\s*;} $body] { lappend strip $nm }
    dict set out strip $strip
    if {[regexp {\n\s*state\s*&=\s*\(1\s*<<\s*(\d+)\)\s*-\s*1\s*;} $body -> n]} { dict set out range $n }
  }
  return $out
}

# The `strip` and `range` facts of kc_cfacts as numbers: a dict with
#   strip     the bits callback() takes off the state it decides a key by
#   strip_ok  1 when it named at least one mask and every name is one of the
#             X protocol's modifier and button masks (X.h)
#   range     the mask of the bits callback() keeps (0 when the count was not
#             found)
proc kc_masks {cf} {
  array set x11 {ShiftMask 1 LockMask 2 ControlMask 4 Mod1Mask 8 Mod2Mask 16
                 Mod3Mask 32 Mod4Mask 64 Mod5Mask 128 Button1Mask 256}
  set strip 0
  set ok [expr {[llength [dict get $cf strip]] > 0}]
  foreach nm [dict get $cf strip] {
    if {[info exists x11($nm)]} { set strip [expr {$strip | $x11($nm)}] } else { set ok 0 }
  }
  set range 0
  if {[string is integer -strict [dict get $cf range]]} { set range [expr {(1 << [dict get $cf range]) - 1}] }
  return [dict create strip $strip strip_ok $ok range $range]
}

# The arms of handle_key_press's key switch that open with the bare graph test
# and hand the key to waves_callback: a list of {keysym reduced-state nocad},
# the state 0 or 4 (Control) or ? when the arm's condition is neither, and
# `nocad` when the condition excludes the Cadence profile.
proc kc_guards {csrc} {
  set a [string first "\nstatic void handle_key_press(" $csrc]
  if {$a < 0} { return NO-FUNCTION }
  set b [string first "\n\x7d\n" $csrc $a]
  set body [string range $csrc $a $b]
  regsub -all {/\*.*?\*/} $body {} body
  set out {}
  set parts [regexp -all -inline -indices {\n    case '(.)':} $body]
  set n [expr {[llength $parts] / 2}]
  for {set i 0} {$i < $n} {incr i} {
    set s1 [lindex $parts [expr {2 * $i}] 1]
    set ch [string range $body {*}[lindex $parts [expr {2 * $i + 1}]]]
    set e0 [expr {$i + 1 < $n ? [lindex $parts [expr {2 * $i + 2}] 0] : [string length $body]}]
    set blk [string range $body $s1 $e0]
    foreach {all cond rest} [regexp -all -inline {\n      (?:else )?if\(([^\n]*)\) *\{([^\n]*(?:\n(?!      (?:else )?if\(|      \})[^\n]*)*)} $blk] {
      if {![regexp {^\s*(?:int [^;]*;\s*)?(?:if\(xctx->semaphore >= 2\) break;\s*)?if\(waves_selected\(event, key, state, button\)\) \{\s*waves_callback\(} $rest]} continue
      set st ?
      if {[regexp {^\(?rstate *== *0\)?( |$)} $cond]} { set st 0 }
      if {[regexp {^\(?rstate *== *ControlMask\)?( |$)} $cond]} { set st 4 }
      lappend out [list [scan $ch %c] $st [expr {[string first {!cadence_compat} $cond] >= 0 ? {nocad} : {}}]]
    }
  }
  return $out
}

# The comparand: the state the engine is handed with graph key `N` typed with
# state `s`, or {} when the engine does not hand that chord to the graph.
#   cad     1 in the Cadence profile
#   guck    1 with graph_use_ctrl_key set
#   rows    the engine's binding table (`xschem bindings dump`)
#   guards  kc_guards' answer
#   strip   the bits callback() takes off the state (kc_masks)
#   range   the mask of the bits it keeps (kc_masks)
proc kc_expect {N s cad guck rows guards strip range} {
  set r [expr {($s & $range) & ~$strip}]
  if {$guck && $r != 4} { return {} }
  set fs $s
  if {$r == 0 && $N == 115 && $cad} { set r 4 ; set fs [expr {$s | 4}] }
  if {$r != 0 && $r != 4} { return {} }
  set mods [expr {$r == 4 ? {ctrl} : {0}}]
  set g 0 ; set o 0
  foreach row $rows {
    if {[lrange $row 0 2] ne [list key $N $mods]} continue
    if {[lindex $row 3] eq {graph} && [lindex $row 4] eq {graph.forward}} { set g 1 } else { set o 1 }
  }
  if {$g} { return $fs }
  if {$o} { return {} }
  foreach gd $guards {
    lassign $gd gN gr gc
    if {$gN == $N && $gr == $r && !($gc eq {nocad} && $cad)} { return $fs }
  }
  return {}
}
