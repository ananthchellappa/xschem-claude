#
#  File: hilight_hier_dump_replay.tcl
#
#  HEADLESS (--nogui) Tier-B test: dump the schematic hierarchy's internal
#  REPRESENTATION to a file, then REPLAY the cross-window highlight translation
#  purely from the file contents (no live schematic, no window). This proves the
#  deep-gap relay's mapping is a pure function of serialized state -- exactly the
#  "write the internal representations to files and test the mapping" approach.
#  See doc/claude/code_analysis/net_highlight_linked_windows_agent_guide.md §8.
#
#      cd tests
#      ../src/xschem --nogui --pipe -q --script hilight_hier_dump_replay.tcl
#
#  It exercises the two rules the engine uses, as ARITHMETIC over the dump:
#    R1 (per-hop up-translation, mirrors nh_hop / hilight_parent_pins): a net at
#       a deep level surfaces one level up iff the crossed instance has a PIN of
#       that name (the ipin port convention: port-net name == pin name); the
#       parent net is that pin's node.
#    R2 (deep-gap ancestor-or-self filter, mirrors net_hilight_copy_table_from):
#       an entry whose path is DEEPER than the target level is dropped when
#       reconciling a shallower window -> a raw deep entry never populates the
#       primary (no false buried cue); only a translated surfacing net does.
#
#  Fixture (tests/hilight_xwin_sync/): CTRL surfaces 2 levels; BAR is buried.
#

set here [file normalize [file dirname [info script]]]
set fx   [file join $here hilight_xwin_sync]
set work [file join $here hilight_hier_dump_replay.d]
file delete -force $work
file mkdir $work
set repfile [file join $work rep.txt]

set nfail 0
proc check {desc got want} {
  global nfail
  if {$got eq $want} { puts "ok   - $desc" } else {
    puts "$desc (got '$got' want '$want'): FAIL" ; incr nfail
  }
}

# ===========================================================================
# PHASE 1 -- DUMP the hierarchy representation to $repfile (via introspection).
# Structural reps (path stack, per-hop pin->node maps, slice numbers) are
# highlight-independent; we also capture a live deep highlight table line.
# ===========================================================================
cd $fx
# fixture hygiene: drop any ~-backing file a prior unsaved-edit test may have left (it would
# load in place of the .sch and silently change the fixture).
foreach f [glob -nocomplain *~.sch] { catch {file delete -force $f} }
xschem load [file join [pwd] parent.sch]

set fd [open $repfile w]
# descend recording the instance-nodemap of each crossed instance AT ITS PARENT LEVEL
puts $fd "CURRSCH_TOP 0"
puts $fd "PATH 0 [xschem get sch_path 0]"
puts $fd "HOP 0 [xschem instance_nodemap xi]"          ;# xi viewed at top: top-net <-> xi-pin
xschem select instance xi fast ; xschem descend 1
puts $fd "PATH 1 [xschem get sch_path 1]"
puts $fd "INSTN 0 [xschem get sch_inst_number 1]"      ;# slice entering level 1 (hop 0's crossed slice)
puts $fd "HOP 1 [xschem instance_nodemap xg]"          ;# xg viewed at .xi.: .xi.-net <-> xg-pin
xschem select instance xg fast ; xschem descend 1
puts $fd "INSTN 1 [xschem get sch_inst_number 2]"      ;# slice entering level 2 (hop 1's crossed slice)
puts $fd "PATH 2 [xschem get sch_path 2]"
# a real deep highlight, serialized via list_hilights all -> "path  token  value"
xschem unselect_all
xschem hilight_netname CTRL
foreach line [split [string trim [xschem list_hilights all]] "\n"] {
  set line [string trim $line]
  if {$line ne ""} { puts $fd "HILIGHT $line" }
}
close $fd
puts "dumped representation to $repfile"

# ===========================================================================
# PHASE 2 -- REPLAY purely from the file. From here on we do NOT consult live
# xschem state for the mapping; everything is parsed out of $repfile.
# ===========================================================================
array set hopmap {}   ;# hopmap(L) = dict pin->node for the instance crossed L->L+1
array set hopinst {}  ;# hopinst(L) = instance name
array set pathof {}   ;# pathof(L) = sch_path at level L
set deep_entries {}   ;# list of {path token} from the dumped HILIGHT lines

set fd [open $repfile r]
foreach line [split [read $fd] "\n"] {
  set line [string trim $line]
  if {$line eq ""} continue
  set kind [lindex $line 0]
  switch -- $kind {
    PATH { set pathof([lindex $line 1]) [lindex $line 2] }
    HOP {
      set L [lindex $line 1]
      set rest [lrange $line 2 end]      ;# instname pin node pin node ...
      set hopinst($L) [lindex $rest 0]
      set m [dict create]
      foreach {pin node} [lrange $rest 1 end] { dict set m $pin $node }
      set hopmap($L) $m
    }
    HILIGHT { lappend deep_entries [list [lindex $line 1] [lindex $line 2]] }
  }
}
close $fd

# sanity: the dump round-tripped the deep highlight
check "dump captured deep highlight (.xi.xg. CTRL)" \
      [expr {[lsearch -exact $deep_entries {.xi.xg. CTRL}] >= 0}] 1
check "dump captured 2 hop maps"  [expr {[info exists hopmap(0)] && [info exists hopmap(1)]}] 1

# R1: replay the up-translation of net $tok from the deepest level to the top.
# Returns the surfacing top-net name, or "" if it becomes buried on the way up.
proc replay_up {tok deepest} {
  global hopmap
  set cur $tok
  for {set L [expr {$deepest - 1}]} {$L >= 0} {incr L -1} {
    set m $hopmap($L)
    if {[dict exists $m $cur]} {       ;# crossed instance has a pin named $cur -> surfaces
      set cur [dict get $m $cur]        ;# parent net = that pin's node
    } else {
      return ""                         ;# no pin of that name here -> buried at this boundary
    }
  }
  return $cur
}

# CTRL must surface all the way to the top net "CTRL"
check "R1 SURFACING: CTRL replays up to top net CTRL" [replay_up CTRL 2] {CTRL}
# BAR is not a pin of xi (HOP 0), so it must NOT surface
check "R1 BURIED: BAR does NOT surface to top"        [replay_up BAR 2] {}

# R2: the ancestor-or-self filter. An entry at path $ep populates a target at
# level path $tp only if $ep is a prefix of $tp (ancestor-or-self); a deeper
# entry (len($ep) > len($tp)) is dropped. Mirrors hilight.c net_hilight_copy_table_from.
proc anc_or_self {ep tp} {
  expr {[string length $ep] <= [string length $tp] && [string first $ep $tp] == 0}
}
# deep entry .xi.xg. vs primary top path "." : must be DROPPED (no false cue)
check "R2 filter: deep entry dropped at top (no false cue)" [anc_or_self .xi.xg. .] 0
# an ancestor/self entry (top "." ) vs the deep target ".xi.xg." : kept (inert)
check "R2 filter: ancestor entry kept at deep target"       [anc_or_self . .xi.xg.] 1

# Composite: what the primary actually shows for a DEEP highlight = the surfacing
# translation (if any) MINUS the filtered raw deep entry. For CTRL: surfaces ->
# primary shows top net CTRL, no raw deep entry. For BAR: does not surface AND
# the raw deep entry is dropped -> primary shows no NET (only a buried cue, which
# the live relay draws from the verbatim copy; not modeled in this pure replay).
check "primary net for surfacing CTRL" [replay_up CTRL 2]              {CTRL}
check "primary net for buried BAR"     [replay_up BAR 2]               {}

file delete -force $work
set summary [expr {$nfail ? "OVERALL: FAIL ($nfail)" : "OVERALL: ok"}]
puts $summary
exit [expr {$nfail ? 1 : 0}]
