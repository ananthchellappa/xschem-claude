#!/usr/bin/env tclsh
# tools/migrate/op_measures.tcl -- a committed bench's plain signal row whose
# author plainly meant to READ the operating point becomes vdc(x)/idc(x), a
# measure (ase_l.md R-OUT11, user ruling 2026-10-13).
#
# The user: "Yes, proceed with vdc(vbg) and analogues of that in all
# test-benches where there is an operating point analysis and it is obvious
# that the intention was to display operating point information."
#
# DERIVED, never a hand list.  A CANDIDATE is an Outputs row of a bench whose
# operating point is enabled and whose whole text is a save (`v(x)`,
# `v(a,b)`, `i(x)`) or a bare name.  It is OBVIOUS when
#   op-only   the bench's ONLY enabled analysis is the operating point, and
#             the cell IS a test bench: its schematic places no port pin
#             (ipin, opin, iopin).  A cell with ports is a circuit another
#             bench instantiates; run alone its inputs float, and op-only is
#             the migration's default for it, not the author's choice; or
#   print     the bench has other analyses too, and the bench it was migrated
#             from (<pdk>/xschem_libs/<lib less _ase>/<cell>) has a `print`
#             line in a .control block, with `op` the last analysis before
#             it, naming the row's exact text -- the author printed it at the
#             operating point.
# An obvious row is converted only if the result can show a number, which is
# measured on the real simulator (tools/migrate/op_measures_vars.tcl writes
# what each bench's operating point holds):
#   * the signal must be in the bench's operating point -- vdc() of a name the
#     circuit lacks shows the Calculator's "unknown token" refusal, not a
#     number (band OM7 of tests/headless/test_ase_op_measures.tcl drives it);
#   * the two-node form v(a,b) stays a save: the Calculator reads no
#     vdc(a,b), so the row would show a refusal;
#   * a bench that does not run here is not converted.
# The new text keeps the author's spelling of the signal: v(CLK) -> vdc(CLK),
# I(Vce) -> idc(Vce), Vc -> vdc(Vc).  Only the row's expr changes.
#
#   tclsh tools/migrate/op_measures.tcl <repo> --need
#       print the states whose operating point must be measured
#   tclsh tools/migrate/op_measures.tcl <repo> --vars <dir> ?--table <f>? ?--write?
#       derive; --table writes one Tcl list per candidate row,
#       {state index name old new why} (new {} when the row stays), read by
#       tests/headless/test_ase_op_measures.tcl; --write rewrites the states
#   --from <rev> reads the states at that commit instead (no --write)
set repo [file normalize [lindex $argv 0]]
proc opt {name} {
  set i [lsearch -exact $::argv $name]
  if {$i < 0} { return {} }
  return [lindex $::argv [expr {$i + 1}]]
}
set need  [expr {[lsearch -exact $argv --need] >= 0}]
set write [expr {[lsearch -exact $argv --write] >= 0}]
set vars  [opt --vars]
set table [opt --table]
set from  [opt --from]
if {$from ne {}} { set write 0 }

proc is_save {e} {
  set nm {(?:"[^"\s(),]+"|[^"\s(),]+)}
  if {[regexp -nocase "^v\\(\\s*$nm\\s*(?:,\\s*$nm\\s*)?\\)\$" $e]} { return 1 }
  if {[regexp -nocase "^i\\(\\s*$nm\\s*\\)\$" $e]} { return 1 }
  return 0
}
proc is_bare {e} {
  return [expr {[regexp {^[A-Za-z_#][A-Za-z0-9_.:#$<>\[\]]*$} $e]
                && ![string is double -strict $e]}]
}
proc git {args} { return [exec git -C $::repo {*}$args] }
proc slurp {rel} {
  if {$::from ne {}} { return [git show $::from:$rel] }
  set fh [open [file join $::repo $rel] r] ; set t [read $fh] ; close $fh
  return $t
}
proc enabled {st} {
  set en {}
  foreach a [dict get $st analyses] {
    if {[dict exists $a enabled] && [dict get $a enabled] eq {1}} { lappend en [dict get $a type] }
  }
  return $en
}
# The bench this one was migrated from, repo-relative, or {}.
proc original {rel} {
  set p [file split $rel]
  set lib [lindex $p 2]
  if {![regsub {_ase$} $lib {} olib]} { return {} }
  set cell [lindex $p 3]
  set o [file join [lindex $p 0] xschem_libs $olib $cell schematic $cell.sch]
  if {[file isfile [file join $::repo $o]]} { return $o }
  return {}
}
# Every line of the original's .control blocks, each as {last-analysis line}.
proc control_lines {orel} {
  set fh [open [file join $::repo $orel] r] ; set s [read $fh] ; close $fh
  set out {}
  set in 0 ; set last {}
  foreach ln [split $s "\n"] {
    set l [string trim $ln]
    if {[string match -nocase .control* $l]} { set in 1 ; set last {} ; continue }
    if {[string match -nocase .endc* $l]} { set in 0 ; continue }
    if {!$in} { continue }
    if {[regexp -nocase {^(op|dc|ac|tran|noise|pz|tf|sens|disto|reset)(\s|$)} $l -> c]} {
      set last [string tolower $c]
      continue
    }
    # a `+` line continues the command above it
    if {[string index $l 0] eq {+} && [llength $out]} {
      lset out end 1 "[lindex $out end 1] [string range $l 1 end]"
      continue
    }
    lappend out [list $last $l]
  }
  return $out
}
# The `print` line, after `op`, naming the row's exact text; {} if none.
proc op_print {orel e} {
  if {$orel eq {}} { return {} }
  foreach pl [control_lines $orel] {
    lassign $pl last l
    if {$last ne {op} || ![regexp -nocase {^print\s} $l]} { continue }
    foreach t [lrange [regexp -all -inline {\S+} $l] 1 end] {
      if {[string trim $t {"}] eq $e} { return $l }
    }
  }
  return {}
}
# Where the original reads the row's signal, for a row that is not obvious.
proc sources {orel e} {
  if {$orel eq {}} { return {no bench it was migrated from} }
  set src {}
  set re "(^|\[^A-Za-z0-9_.\])[string map {( \\( ) \\) . \\. [ \\[ ] \\] $ \\$} $e](\[^A-Za-z0-9_.\]|\$)"
  foreach pl [control_lines $orel] {
    lassign $pl last l
    if {![regexp -nocase $re $l]} { continue }
    set head [string tolower [lindex [regexp -all -inline {\S+} $l] 0]]
    if {$head ni {print plot save wrdata meas let echo}} { continue }
    set w [expr {$last eq {} ? $head : "$head after $last"}]
    if {$w ni $src} { lappend src $w }
  }
  set fh [open [file join $::repo $orel] r] ; set s [read $fh] ; close $fh
  set ingraph 0
  foreach ln [split $s "\n"] {
    if {[string match {B *flags=graph*} $ln]} { set ingraph 1 }
    if {$ingraph && [regexp -nocase $re $ln]} {
      if {{graph} ni $src} { lappend src graph }
    }
    if {$ingraph && [string match {*\}} [string trim $ln]]} { set ingraph 0 }
  }
  if {$src eq {}} { return {the original names it nowhere} }
  return "the original reads it in: [join $src {, }]"
}
# The port pins (ipin, opin, iopin) the bench's own schematic places.
proc ports {rel} {
  set p [file split $rel]
  set sch [file join [lindex $p 0] xschem_libs [lindex $p 2] [lindex $p 3] schematic [lindex $p 3].sch]
  set s [slurp $sch]
  return [llength [regexp -all -line -inline {^C \{(?:[^\}/]*/)?(?:ipin|opin|iopin)\}} $s]]
}
proc key {rel} { return [string map {/ %} $rel] }

if {$from eq {}} {
  set files [split [git ls-files -- *.state] "\n"]
} else {
  set files [lsearch -all -inline -glob [split [git ls-tree -r --name-only $from] "\n"] *.state]
}
set rows {}
set needed {}
set rewrite [dict create]
foreach rel $files {
  set st [slurp $rel]
  set en [enabled $st]
  if {{op} ni $en} { continue }
  set orel [original $rel]
  set i -1
  foreach o [dict get $st outputs] {
    incr i
    set e [string trim [dict get $o expr]]
    set nm [dict get $o name]
    if {[is_save $e]} {
      regexp {^(.)\((.*)\)$} $e -> fam sig
      set fam [string tolower $fam]
    } elseif {[is_bare $e]} {
      set fam v ; set sig $e
    } else { continue }
    set why {}
    if {$en eq {op}} {
      set rule {op-only}
      set np [ports $rel]
      if {$np > 0} {
        lappend rows [list $rel $i $nm $e {} "not a test bench: the cell places $np port pins, a circuit for a bench to instantiate, and op-only is the migration's default ($rule)"]
        continue
      }
    } else {
      set pl [op_print $orel $e]
      if {$pl eq {}} {
        lappend rows [list $rel $i $nm $e {} "not obvious: [join $en +]; [sources $orel $e]"]
        continue
      }
      set rule "print after op in $orel: $pl"
    }
    if {[string first , $sig] >= 0} {
      lappend rows [list $rel $i $nm $e {} "stays a save: the Calculator reads no vdc(a,b) ($rule)"]
      continue
    }
    if {$need} { if {$rel ni $needed} { lappend needed $rel } ; continue }
    set vf [file join $vars [key $rel].opvars]
    set nf [file join $vars [key $rel].norun]
    if {[file isfile $nf]} {
      set fh [open $nf r] ; set w [string trim [read $fh]] ; close $fh
      lappend rows [list $rel $i $nm $e {} "not measured: the bench does not run here ($w) ($rule)"]
      continue
    }
    if {![file isfile $vf]} { puts stderr "no measurement for $rel in $vars (run --need)" ; exit 2 }
    set fh [open $vf r] ; set have [split [string trim [read $fh]] "\n"] ; close $fh
    if {[lsearch -exact -nocase $have "$fam\($sig\)"] < 0} {
      lappend rows [list $rel $i $nm $e {} "not in this circuit: its operating point holds no $fam\($sig\) ($rule)"]
      continue
    }
    set new "${fam}dc($sig)"
    lappend rows [list $rel $i $nm $e $new $rule]
    dict lappend rewrite $rel [list $i $e $new]
  }
}
if {$need} { puts [join $needed " "] ; exit 0 }

set nconv 0
foreach r $rows { if {[lindex $r 4] ne {}} { incr nconv } }
puts "candidates [llength $rows], converted $nconv"
foreach r $rows { if {[lindex $r 4] ne {}} { puts "  [lindex $r 0] #[lindex $r 1] [lindex $r 3] -> [lindex $r 4]" } }

if {$write} {
  dict for {rel chg} $rewrite {
    set text [slurp $rel]
    set outs [dict get $text outputs]
    foreach c $chg {
      lassign $c i e new
      set o [lindex $outs $i]
      if {[string trim [dict get $o expr]] ne $e} { puts stderr "$rel #$i moved" ; exit 3 }
      dict set o expr $new
      lset outs $i $o
    }
    set lines {}
    foreach ln [split $text "\n"] {
      if {[string match {outputs *} $ln]} { set ln "outputs [list $outs]" }
      lappend lines $ln
    }
    set fh [open [file join $repo $rel] w] ; fconfigure $fh -translation lf
    puts -nonewline $fh [join $lines "\n"] ; close $fh
  }
  puts "rewrote [dict size $rewrite] states"
}
if {$table ne {}} {
  set fh [open $table w] ; fconfigure $fh -translation lf
  puts $fh "# Committed benches' plain signal rows on an operating-point bench (ase_l.md"
  puts $fh "# R-OUT11), derived from the states at 2e1e4ccb and the real simulator's"
  puts $fh "# operating point of each bench by"
  puts $fh "#   tclsh tools/migrate/op_measures.tcl . --from 2e1e4ccb --vars <dir> --table <this>"
  puts $fh "# (<dir> written by tools/migrate/op_measures_vars.tcl)."
  puts $fh "# One Tcl list per candidate row: {state index name old new why}."
  puts $fh "#   old  the row's text before the conversion"
  puts $fh "#   new  the measure the committed state holds, or {} when the row stays"
  puts $fh "#   why  the evidence the author meant the operating point (op-only, or the"
  puts $fh "#        print after op it came from), or why the row stays as it is"
  puts $fh "# Read by tests/headless/test_ase_op_measures.tcl."
  foreach r $rows { puts $fh [list {*}$r] }
  close $fh
  puts "table: [llength $rows] rows -> $table"
}
