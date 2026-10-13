#!/usr/bin/env tclsh
# tools/migrate/r208d_saves_revert.tcl -- put R208d's bare qualified single
# signals back as saves (ase_l.md R-OUT7, user ruling 2026-10-13).
#
# The user: "A 'save' will always be v("netname") - because 'save' of a net
# would apply to any analysis."  The batch driver's record of the 2026-10-13
# resync (doc/claude/calc_feedback_batch/BATCH.md item 13, a summary and not
# the user's words) asks for the migration's bare qualified single-signal rows
# to go back to v()/i() saves; the signed ones it also named (-idc(v1)) stay
# measures here, see below.  R208d's migration (1e987ffd)
# rewrote committed Outputs rows that named one signal into an analysis-
# qualified fetch (`clk` -> `vt(clk)`, `i(Vmda)` -> `is(Vmda)`); those rows were
# the original authors' "keep this signal", i.e. saves.
#
# DERIVED FROM GIT, never from a hand list: every committed *.state row whose
# WHOLE text is one unsigned qualified signal is paired with the same row
# (same index, same name) of that file at 1e987ffd^, and rewritten to
#   * the pre-migration text, when that text is already a save (`v(x)`,
#     `I(Vmda)` -- the author's own spelling, case and all);
#   * `v(<x>)` / `i(<x>)` (by the qualifier's family) when it was a bare name.
# A SIGNED row (`-idc(v1)`, from `-i(v1)`) is left as migrated: a save has no
# sign, and the author's sign flip is a number they meant to read (a measure).
# Composed expressions (`vdc(Vcc)/idc(Vr)`) are left as migrated.  A bare
# qualified row with no pre-migration partner is reported and left alone.
#
# Only the expression changes; every other byte of the outputs line is the
# list's own element text.  Also rewrites tests/headless/data/r208d_migration.txt
# to drop the reverted rows (band OE17 pins the rows that stay migrated).
#
#   tclsh tools/migrate/r208d_saves_revert.tcl <repo> ?--write?
#   tclsh tools/migrate/r208d_saves_revert.tcl <repo> --from <rev> --table <file>
#
# Without --write it prints what it would do and changes nothing.  With
# --from <rev> the states are read at that commit (the migrated tree, e.g. the
# revert commit's parent) instead of the working tree, and --table writes one
# Tcl list per reverted row -- {state index name pre migrated reverted} -- the
# table band TR of tests/headless/test_ase_outputs_tabs.tcl holds every
# committed row to, and re-derives `pre` from git where the history is there.
set repo [file normalize [lindex $argv 0]]
set write [expr {[lsearch -exact $argv --write] >= 0}]
set from {}
set fi [lsearch -exact $argv --from]
if {$fi >= 0} { set from [lindex $argv [expr {$fi + 1}]] ; set write 0 }
set table {}
set ti [lsearch -exact $argv --table]
if {$ti >= 0} { set table [lindex $argv [expr {$ti + 1}]] }
set MIG 1e987ffd
proc is_save {e} {
  set nm {(?:"[^"\s(),]+"|[^"\s(),]+)}
  if {[regexp -nocase "^v\\(\\s*$nm\\s*(?:,\\s*$nm\\s*)?\\)\$" $e]} { return 1 }
  if {[regexp -nocase "^i\\(\\s*$nm\\s*\\)\$" $e]} { return 1 }
  return 0
}
proc outputs_of {text} {
  foreach ln [split $text "\n"] {
    if {[string match {outputs *} $ln]} { return [lindex $ln 1] }
  }
  return {}
}
proc git {args} { return [exec git -C $::repo {*}$args] }

if {$from eq {}} {
  set files [split [git ls-files -- *.state] "\n"]
} else {
  set files [split [git ls-tree -r --name-only $from] "\n"]
  set files [lsearch -all -inline -glob $files *.state]
}
set total 0
set nostep {}
array set perpdk {}
set reverted {}
set tabrows {}
foreach rel $files {
  set path [file join $repo $rel]
  if {$from eq {}} {
    set fh [open $path r]; set text [read $fh]; close $fh
  } else {
    set text [git show $from:$rel]
  }
  set outs [outputs_of $text]
  set old {}
  catch {set old [outputs_of [git show $MIG^:$rel]]}
  set changed 0
  set i 0
  set newouts {}
  foreach o $outs {
    set e [string trim [dict get $o expr]]
    if {[regexp -nocase {^(vt|vf|vdc|vs|it|if|idc|is)\(([^()]*)\)$} $e -> q inner]} {
      set prev {}
      if {$i < [llength $old]} {
        set po [lindex $old $i]
        if {[dict exists $po name] && [dict exists $o name] && [dict get $po name] eq [dict get $o name]} {
          set prev [string trim [dict get $po expr]]
        }
      }
      if {$prev eq {}} {
        lappend nostep "$rel row $i: $e"
      } else {
        set fam [string tolower [string index $q 0]]
        set tgt [expr {[is_save $prev] ? $prev : "$fam\($inner\)"}]
        dict set o expr $tgt
        set changed 1
        incr total
        set pdk [lindex [file split $rel] 0]
        incr perpdk($pdk)
        lappend reverted [list $rel [dict get $o name] $e $tgt]
        lappend tabrows [list $rel $i [dict get $o name] $prev $e $tgt]
      }
    }
    lappend newouts $o
    incr i
  }
  if {$changed && $write} {
    set lines {}
    foreach ln [split $text "\n"] {
      if {[string match {outputs *} $ln]} { set ln "outputs [list $newouts]" }
      lappend lines $ln
    }
    set fh [open $path w]; fconfigure $fh -translation lf
    puts -nonewline $fh [join $lines "\n"]; close $fh
  }
}
puts "reverted $total rows"
foreach p [lsort [array names perpdk]] { puts "  $p $perpdk($p)" }
if {[llength $nostep]} { puts "left alone (no pre-migration partner): [llength $nostep]"; foreach n $nostep { puts "  $n" } }

if {$table ne {}} {
  set fh [open $table w]; fconfigure $fh -translation lf
  puts $fh "# R208d's bare qualified single signals put back as saves (416051cd), derived"
  puts $fh "# from git by tools/migrate/r208d_saves_revert.tcl --from 416051cd^ --table."
  puts $fh "# One Tcl list per row: {state index name pre migrated reverted}."
  puts $fh "#   pre       the row's text before R208d (1e987ffd^)"
  puts $fh "#   migrated  the bare qualified text R208d wrote"
  puts $fh "#   reverted  the save the committed state must hold: `pre` when it was"
  puts $fh "#             already a save, else v(x)/i(x) by the qualifier's family"
  puts $fh "# Read by band TR of tests/headless/test_ase_outputs_tabs.tcl."
  foreach r $tabrows { puts $fh [list {*}$r] }
  close $fh
  puts "table: [llength $tabrows] rows -> $table"
}
if {$from ne {}} { exit 0 }

# the OE17 table keeps the rows that stay migrated
set tab [file join $repo tests headless data r208d_migration.txt]
set fh [open $tab r]; set t [read $fh]; close $fh
set gone [dict create]
foreach r $reverted { dict set gone "[lindex $r 0] [lindex $r 1]" 1 }
set keep {}
set dropped 0
foreach ln [split [string trimright $t "\n"] "\n"] {
  if {[string index $ln 0] ne {#} && [string trim $ln] ne {}} {
    if {[dict exists $gone "[lindex $ln 0] [lindex $ln 1]"]} { incr dropped ; continue }
  }
  lappend keep $ln
}
puts "OE17 table: $dropped rows dropped, [expr {[llength $keep]}] lines kept"
if {$write} {
  set fh [open $tab w]; fconfigure $fh -translation lf
  puts $fh [join $keep "\n"]; close $fh
}
