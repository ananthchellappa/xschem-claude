# tests/headless/test_node_token_split.tcl — issue 0305: ONE node_token_split()
# at all six `node=` walkers in src/draw.c.
#
# Issue: doc/claude/issues/0305-per-trace-rawfile-is-honoured-by-three-of-six-node-walkers.md
# Spec:  doc/claude/specs/mixed_signal_signal_browser.md section D (row D1).
#
# WHAT THIS PINS. A graph rect's `node=` attribute is a newline separated list;
# one entry is
#
#     [alias;]<vec-or-RPN> [ '%' [<dataset-digits>] [<rawfile> [<sim_type>]] ]
#
# Six functions in src/draw.c walk that list. All six parsed the `%`; only
# THREE did anything with the `<rawfile>` half. The three that did not are the
# three a mouse touches:
#
#   graph_point_at()        pick / hover / marker create + drag
#   wave_hilight_envelope() the LMB wave-bold overlay (issue 0152)
#   graph_wave_resolve()    the marker VALUE readout
#
# so a VCD trace plotted beside an analog one (spec D1, commit 96f7678a) DREW
# correctly and was then unpickable, unboldable and unmarkable: its name was
# resolved against whatever database happened to be current, which for a mixed
# strip is the analog one, where a VCD signal name does not exist.
#
# All six now call ONE helper, node_token_split(), and every switch it enables
# is unwound by an absolute, index-based restore (node_db_restore) rather than
# extra_rawfile()'s mode-5 SWAP -- a swap cannot unwind two nested levels, and
# the graph-level `rawfile=` switch is the outer one.
#
# THE FIXTURE IS SYNTHESIZED and needs no simulator: an ASCII ngspice transient
# raw (v(anlg), a shallow ramp confined to 0.25..0.30 V) and a 1-bit VCD (levels
# exactly 0 and 1). The two value ranges do not overlap, which is what lets a
# marker READOUT say WHICH database answered rather than merely "something did".
# Both span 0..2e-9 s so one x window holds both.
#
# The legs:
#   NDF*  the fixture and its PREMISE: two DBs registered, the analog one
#         current, and the VCD's signal name absent from the current DB. Without
#         that premise every later check could pass by accident.
#   NDP*  PICK          -> graph_point_at()
#   NDB*  BOLD          -> wave_hilight_envelope()
#   NDM*  MARKER        -> graph_wave_resolve() + graph_marker_sample()
#   NDS*  THE NESTED STRIP: a graph-level `rawfile=` that resolves to a
#         non-session database, a per-trace `%<rawfile>` under it, and a `sweep=`
#         list SHORTER than the `node=` list. That is the only configuration in
#         which (a) a carried-forward sweep COLUMN is read against a database
#         that does not have it -- an out-of-bounds read, and a segfault when
#         the foreign database is narrower -- and (b) the per-node unwind's
#         LEVEL is observable at all (graph DB vs session DB).
#   NDG*  the `%` GRAMMAR the shared helper has to keep answering for: bare
#         dataset digits, digits + rawfile, an out-of-range dataset, an
#         unresolvable database, and a plain unsuffixed entry.
#   NDT*  a `%<rawfile>` with the sim_type field OMITTED -- the inherited-type
#         arm (node_dflt_sim_type), which every other `%` token here bypasses.
#   NDY*  graph_fullyzoom(), the fourth walker reachable without a display.
#   NDX*  the STRUCTURAL guard: the `%` parse exists in exactly one function and
#         all six walkers call it. Every other check here is behavioural and a
#         seventh hand-rolled copy is invisible to all of them.
#   NDZ*  the coverage self-check.
#
# True headless: run under --nogui.
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_node_token_split.tcl
#
# NOT COVERED HERE: find_closest_wave() is only reachable from callback.c's
# graph motion handler, i.e. a real DISPLAY. Its `%` parse moved into the shared
# helper with the rest; its unbalanced mode-5 restore is deliberately untouched
# (batch F item 2 owns it).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch ndtok]
set ::XSCHEM_LIBRARY_PATH {}

proc wr {p s} { set fp [open $p w]; puts -nonewline $fp $s; close $fp }

# an ASCII ngspice transient raw, v(anlg) a shallow ramp 0.25 -> 0.30 V. The
# BAND is load-bearing: it must not touch the VCD's logic levels (0 and 1), so a
# marker readout tells the two databases apart by value alone.
proc mkraw {path {tmax 2.0e-9} {n 41}} {
  set body "Title: nd\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set v [expr {0.25 + 0.05 * $t / $tmax}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}
# a SECOND analog raw, one vector, band 0.70..0.75 -- a third value band, so a
# readout says which of the THREE databases answered. Same sim_type as the
# session raw on purpose: it is what a `%<rawfile>` with NO type field inherits.
proc mkraw_other {path {tmax 2.0e-9} {n 41}} {
  set body "Title: nd-other\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(other)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set v [expr {0.70 + 0.05 * $t / $tmax}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}
# a WIDE analog raw: five columns, the sweep candidate v(wsw) LAST (index 4).
# The width is the point -- a sweep column resolved here and then carried into a
# database with fewer columns is an out-of-bounds read, which is the whole of the
# NDS leg. v(wsw) duplicates time so it is a legal x axis.
proc mkraw_wide {path {tmax 2.0e-9} {n 41}} {
  set body "Title: nd-wide\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 5\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(wonly)\tvoltage\n\t2\tv(wtwo)\tvoltage\n"
  append body "\t3\tv(wpad)\tvoltage\n\t4\tv(wsw)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set a [expr {0.60 + 0.05 * $t / $tmax}]
    set b [expr {-0.25 + 0.05 * $t / $tmax}]
    append body "$i\t$t\n\t$a\n\t$b\n\t0.0\n\t$t\n\n"
  }
  wr $path $body
}
# a 1-bit VCD, `ticks` picoseconds long, toggling at 1/4, 1/2, 3/4 and the end
proc mkvcd {path sig {ticks 2000}} {
  set q [expr {$ticks / 4}]
  wr $path "\$timescale 1ps \$end
\$scope module TOP \$end
 \$scope module m \$end
  \$var wire 1 ! $sig \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#$q
1!
#[expr {2 * $q}]
0!
#[expr {3 * $q}]
1!
#$ticks
0!
"
}

# ---------------------------------------------------------------------------
# geometry helpers. NOTHING here predicts a pixel: `zoom_full` fits the drawing
# to whatever canvas the process happens to have, so every coordinate is asked
# of the engine (the mp_band / mp_box idiom of test_wave_markers.tcl).
# ---------------------------------------------------------------------------
proc nd_band {wx1 wy1 wx2 wy2} {
  set z [xschem get zoom]; set xo [xschem get xorigin]; set yo [xschem get yorigin]
  if {![string is double -strict $z] || $z == 0.0} { return {} }
  return [list [expr {int(($wx1 + $xo) / $z)}] [expr {int(($wy1 + $yo) / $z)}] \
               [expr {int(($wx2 + $xo) / $z)}] [expr {int(($wy2 + $yo) / $z)}]]
}
proc nd_box {gi band} {
  if {[llength $band] != 4} { return {} }
  lassign $band ux1 uy1 ux2 uy2
  if {$ux2 < $ux1} { set t $ux1; set ux1 $ux2; set ux2 $t }
  if {$uy2 < $uy1} { set t $uy1; set uy1 $uy2; set uy2 $t }
  set sx {}; set sy {}
  for {set y $uy1} {$y <= $uy2} {incr y 2} {
    for {set x $ux1} {$x <= $ux2} {incr x 2} {
      if {[xschem get graph_plotbox_at $gi $x $y]} { set sx $x; set sy $y; break }
    }
    if {$sx ne {}} break
  }
  if {$sx eq {}} { return {} }
  set x1 $sx
  while {$x1 > -20000 && [xschem get graph_plotbox_at $gi [expr {$x1 - 1}] $sy]} { incr x1 -1 }
  set x2 $sx
  while {$x2 < 20000 && [xschem get graph_plotbox_at $gi [expr {$x2 + 1}] $sy]} { incr x2 }
  set cx [expr {($x1 + $x2) / 2}]
  set y1 $sy
  while {$y1 > -20000 && [xschem get graph_plotbox_at $gi $cx [expr {$y1 - 1}]]} { incr y1 -1 }
  set y2 $sy
  while {$y2 < 20000 && [xschem get graph_plotbox_at $gi $cx [expr {$y2 + 1}]]} { incr y2 }
  return [list $x1 $y1 $x2 $y2]
}
# every {y node} the column `cx` picks up, top to bottom
proc nd_column {gi box cx {tol 3}} {
  if {[llength $box] != 4} { return {} }
  lassign $box x1 y1 x2 y2
  set out {}
  for {set y $y1} {$y <= $y2} {incr y} {
    set n [xschem get graph_trace_at $gi $cx $y $tol]
    if {[string is integer -strict $n] && $n >= 0} { lappend out [list $y $n] }
  }
  return $out
}
proc nd_nodes {hits} {
  set s {}
  foreach h $hits { lappend s [lindex $h 1] }
  return [lsort -integer -unique $s]
}
# the mid screen row at which node `ni` was picked in that column, or {}
proc nd_row_of {hits ni} {
  set ys {}
  foreach h $hits { if {[lindex $h 1] == $ni} { lappend ys [lindex $h 0] } }
  if {![llength $ys]} { return {} }
  set ys [lsort -integer $ys]
  return [expr {([lindex $ys 0] + [lindex $ys end]) / 2}]
}
# x as a fraction of the plot box width
proc nd_colx {box f} {
  lassign $box x1 y1 x2 y2
  return [expr {int($x1 + ($x2 - $x1) * $f)}]
}
# the graph's node= list, rebuilt for a fresh fixture
proc nd_setnode {gi val} { xschem setprop rect 2 $gi node $val }

if {[catch {

# ===========================================================================
# NDF — the fixture, and the PREMISE the whole file rests on
# ===========================================================================
set rawf [file join $scratch anlg.raw]
set vcdf [file join $scratch d1.vcd]
set widef [file join $scratch wide.raw]
set othf [file join $scratch other.raw]
mkraw $rawf
mkvcd $vcdf siga
mkraw_wide $widef
mkraw_other $othf

check "NDF1 the analog raw reads" [pcall {xschem raw clear; xschem raw read $rawf tran}] 1
check "NDF2 the VCD reads"        [pcall {xschem raw read $vcdf vcd}] 1
check "NDF2b the WIDE analog raw reads (slot 2)" [pcall {xschem raw read $widef tran}] 1
check "NDF2c the SECOND analog raw reads (slot 3)" [pcall {xschem raw read $othf tran}] 1
check "NDF3 back to the analog DB" [pcall {xschem raw switch 0}] 1
check "NDF4 the ANALOG database is the current one" [pcall {xschem raw sim_type}] tran
check "NDF5 the registry holds both, analog at slot 0" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}
# THE PREMISE. Every NDP/NDB/NDM check below would be satisfiable by a walker
# that ignores `%` entirely if the name existed in both databases. It does not:
check "NDF6 the VCD's signal is ABSENT from the CURRENT database" \
  [pcall {xschem raw index TOP.m.siga}] -1
check "NDF7 ...and the analog vector is present in it" \
  [pcall {expr {[xschem raw index v(anlg)] >= 0}}] 1
xschem raw switch 1
check "NDF8 the VCD database does hold the signal" \
  [pcall {expr {[xschem raw index TOP.m.siga] >= 0}}] 1
check "NDF9 ...and does NOT hold the analog vector" [pcall {xschem raw index v(anlg)}] -1
set ::nd_vcd_points [pcall {xschem raw points}]
check_true "NDF10 the VCD has samples to walk" [expr {$::nd_vcd_points > 2}]
set ::nd_vcd_vars [pcall {xschem raw vars}]
# THE PREMISE OF THE NDS LEG: v(wsw) is a HIGH column of the wide raw and the
# VCD has fewer columns than that, so a sweep index resolved in the wide raw and
# then used against the VCD reads past the end of values[].
xschem raw switch 2
check "NDF10b v(wsw) is column 4 of the wide raw" [pcall {xschem raw index v(wsw)}] 4
check_true "NDF10c ...and the VCD has fewer columns than that, so carrying the\
 index across is an out-of-bounds read" \
  [expr {[string is integer -strict $::nd_vcd_vars] && $::nd_vcd_vars < 4}]
check "NDF10d the wide raw's own vectors are absent from the SESSION database" \
  [pcall {xschem raw switch 0; xschem raw index v(wtwo)}] -1
check "NDF10e ...and so is the second analog raw's vector" \
  [pcall {xschem raw index v(other)}] -1
xschem raw switch 0

# the mixed strip. The cross-DB entry is written in the SAME shape
# wviewer::graph_props emits (P8 of test_wave_crossdb_trace.tcl): an
# `alias;vec%<path> <type>` entry wrapped in literal double quotes.
set QVCD "\\\"vcdsig;TOP.m.siga%$vcdf vcd\\\""
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
nd_setnode 0 "v(anlg)\n$QVCD"
foreach {t v} [list x1 0 x2 2e-9 y1 -0.3 y2 1.3] { xschem setprop rect 2 0 $t $v }
# a second strip carrying the VCD trace ALONE: the mixed strip cannot tell
# "picked the right trace" from "picked the only trace that resolves"
xschem rect 0 1000 800 1400 -1 {flags=graph} 0
nd_setnode 1 "$QVCD"
foreach {t v} [list x1 0 x2 2e-9 y1 -0.3 y2 1.3] { xschem setprop rect 2 1 $t $v }
# a THIRD strip whose GRAPH-LEVEL `rawfile=` does not resolve, carrying the same
# cross-DB entry. This is the one configuration in which the per-node unwind is
# not masked by the graph-level one: with an unresolvable `rawfile=` the
# graph-level switch never takes, so nothing else is holding the session's place
# while the per-trace `%<rawfile>` switch is outstanding. Without the per-node
# restore the whole session is left pointing at the VCD by a mere HOVER.
xschem rect 0 2000 800 2400 -1 {flags=graph} 0
nd_setnode 2 "$QVCD"
foreach {t v} [list x1 0 x2 2e-9 y1 -0.3 y2 1.3] { xschem setprop rect 2 2 $t $v }
xschem setprop rect 2 2 rawfile [file join $scratch nosuch.raw]
# a FOURTH strip: the two-level nesting the other three cannot construct. Its
# GRAPH-LEVEL `rawfile=` RESOLVES, and to a database that is NOT the session's
# (the wide raw), so the per-trace `%<rawfile>` switch below it is a genuine
# SECOND level. Its node list is deliberately ordered
#     [graph-DB entry, cross-DB entry, graph-DB entry]
# and its `sweep=` list holds ONE token for THREE entries -- the documented
# carry-forward. That buys two things nothing else here does:
#   * entry 2 (the VCD) inherits a sweep COLUMN resolved in the wide raw
#     (v(wsw) = column 4). The VCD has 3 columns, so a walker that carries the
#     index instead of re-resolving the NAME reads values[4] of the VCD and
#     SEGFAULTS.
#   * entry 3 resolves ONLY in the wide raw, so it is pickable only if the
#     per-node unwind after entry 2 went back to the GRAPH's database rather
#     than to the session's -- the exact difference between node_saved_idx and
#     entry_extra_idx.
xschem rect 0 3000 800 3400 -1 {flags=graph} 0
nd_setnode 3 "v(wonly)\n\\\"vcd3;TOP.m.siga%$vcdf vcd\\\"\nv(wtwo)"
foreach {t v} [list x1 0 x2 2e-9 y1 -0.4 y2 1.4] { xschem setprop rect 2 3 $t $v }
xschem setprop rect 2 3 rawfile $widef
xschem setprop rect 2 3 sim_type tran
xschem setprop rect 2 3 sweep {v(wsw)}
xschem zoom_full

check "NDF11 four graph rects" [pcall {xschem get graph_rects}] 4
set ndnode [pcall {xschem getprop rect 2 0 node}]
check "NDF12 the mixed strip's node= line 1 is the bare analog vector" \
  [lindex [split $ndnode "\n"] 0] {v(anlg)}
check "NDF13 ...and line 2 carries the %<path> <type> suffix" \
  [lindex [split $ndnode "\n"] 1] "\"vcdsig;TOP.m.siga%$vcdf vcd\""

set ::nd_box0 [nd_box 0 [nd_band 0 0 800 400]]
set ::nd_box1 [nd_box 1 [nd_band 0 1000 800 1400]]
set ::nd_box2 [nd_box 2 [nd_band 0 2000 800 2400]]
set ::nd_box3 [nd_box 3 [nd_band 0 3000 800 3400]]
check_true "NDF14 the mixed strip's plot box was located" [expr {[llength $::nd_box0] == 4}]
check_true "NDF15 the VCD-only strip's plot box was located" [expr {[llength $::nd_box1] == 4}]
check_true "NDF16 the broken-rawfile strip's plot box was located" \
  [expr {[llength $::nd_box2] == 4}]
check_true "NDF17 the nested two-database strip's plot box was located" \
  [expr {[llength $::nd_box3] == 4}]

# ===========================================================================
# NDP — PICK: graph_point_at()
# ===========================================================================
# a column at 3/8 of the width: t = 0.75 ns, strictly BETWEEN two VCD edges, so
# neither trace is a vertical run there and the two are separated in y.
set ::nd_cx [nd_colx $::nd_box0 0.375]
set ::nd_hits [nd_column 0 $::nd_box0 $::nd_cx]
check "NDP1 that column picks up BOTH traces of the mixed strip" \
  [nd_nodes $::nd_hits] {0 1}
set r0 [nd_row_of $::nd_hits 0]
set r1 [nd_row_of $::nd_hits 1]
check_true "NDP2 the analog trace answers node 0 somewhere in the column" [expr {$r0 ne {}}]
# ⚠ THE ITEM. Pre-fix this is empty: TOP.m.siga is resolved in the analog DB,
# get_raw_index() answers -1 and the node is skipped entirely.
check_true "NDP3 the VCD trace answers node 1 (issue 0305: it answered nothing)" \
  [expr {$r1 ne {}}]
# separation as a FRACTION of the plot box, never an absolute pixel count: how
# tall a strip ends up is whatever zoom_full made it, and an absolute bar breaks
# the moment the fixture grows another strip. The two traces sit at 0.27 V and
# at logic 1 on a -0.3..1.3 axis, i.e. 46% of the box apart.
set ::nd_h0 [expr {[lindex $::nd_box0 3] - [lindex $::nd_box0 1]}]
check_true "NDP4 the two picks are DIFFERENT rows, more than a sixth of the strip\
 apart (two real traces, not one trace answering twice)" \
  [expr {$r0 ne {} && $r1 ne {} && abs($r0 - $r1) > $::nd_h0 / 6}]
# MEASURED, not assumed: the VCD toggles at 0 / 0.5 / 1.0 / 1.5 / 2.0 ns, so at
# t = 0.75 ns it is HIGH (1) while the analog ramp sits at ~0.27 V. On a
# -0.3..1.3 axis with screen y growing downward the VCD row must therefore be
# ABOVE the analog one. A walker that resolved the VCD name in the analog DB
# could produce no row here at all; one that resolved it against the wrong
# database would put the row somewhere else entirely.
check_true "NDP5 the VCD row sits ABOVE the analog row, where logic 1 belongs" \
  [expr {$r0 ne {} && $r1 ne {} && $r1 < $r0}]
# the VCD-only strip: the trace is node 0 there, so "it picked something" and
# "it picked the VCD" are the same statement
set ::nd_hits1 [nd_column 1 $::nd_box1 [nd_colx $::nd_box1 0.375]]
check "NDP6 the VCD trace is pickable when it is the ONLY trace on a strip" \
  [nd_nodes $::nd_hits1] {0}
# THE BRACKET. Every one of those picks switched the engine to the VCD; the
# session must be exactly where it started.
check "NDP7 the current database is unchanged after the pick walk" \
  [pcall {xschem raw rawfile}] $rawf
check "NDP8 ...and so is the registry's current slot" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}
check "NDP9 a pick far from every trace still answers -1" \
  [pcall {xschem get graph_trace_at 0 [nd_colx $::nd_box0 0.375] \
            [expr {[lindex $::nd_box0 1] + 1}] 2}] -1
# THE UNMASKED BRACKET. Strip 2's own `rawfile=` does not resolve, so the
# graph-level switch never takes and its restore never runs -- the per-node
# unwind is the ONLY thing putting the session back. The pick itself must
# refuse (the graph's database is gone), and the session must not move.
check "NDP10 a strip whose own rawfile= does not resolve picks nothing" \
  [pcall {xschem get graph_trace_at 2 [nd_colx $::nd_box2 0.375] \
            [expr {([lindex $::nd_box2 1] + [lindex $::nd_box2 3]) / 2}] 1e30}] -1
check "NDP11 ...and that pick leaves the session's database exactly where it was" \
  [pcall {xschem raw rawfile}] $rawf
check "NDP12 ...and the registry's current slot with it" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}

# ===========================================================================
# NDB — BOLD: wave_hilight_envelope()
# ===========================================================================
check_true "NDB1 the ANALOG trace builds an envelope (the control)" \
  [expr {[pcall {xschem get wave_hilight_points 0 0}] > 0}]
# ⚠ THE ITEM. Pre-fix this is 0: idx == -1, the walk is skipped and the bold
# overlay draws nothing at all.
set ::nd_env1 [pcall {xschem get wave_hilight_points 0 1}]
check_true "NDB2 the VCD trace builds an envelope TOO (issue 0305: it was empty)" \
  [expr {$::nd_env1 > 0}]
# an envelope of one or two columns would be a stub. The VCD has
# $::nd_vcd_points samples and they span the whole window.
check_true "NDB3 the VCD envelope carries every VCD sample, not a stub" \
  [expr {$::nd_env1 >= $::nd_vcd_points}]
check "NDB4 the current database is unchanged after the envelope walk" \
  [pcall {xschem raw rawfile}] $rawf
check "NDB5 ...and so is the registry's current slot" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}
check "NDB6 a node index the strip does not have answers 0, not an error" \
  [pcall {xschem get wave_hilight_points 0 9}] 0
# the same unmasked bracket as NDP10-12, for the envelope walker
check "NDB7 a strip whose own rawfile= does not resolve builds no envelope" \
  [pcall {xschem get wave_hilight_points 2 0}] 0
check "NDB8 ...and that walk leaves the session's database exactly where it was" \
  [pcall {xschem raw rawfile}] $rawf
check "NDB9 ...and the registry's current slot with it" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}

# ===========================================================================
# NDM — MARKER: graph_wave_resolve() + graph_marker_sample()
# ===========================================================================
pcall {xschem graph_marker delete -all}
set ::nd_ma [pcall {xschem graph_marker add_at 0 0 0 1}]
check_true "NDM1 a marker lands on the ANALOG trace (the control)" \
  [expr {[string is integer -strict $::nd_ma] && $::nd_ma > 0}]
# ⚠ THE ITEM. Pre-fix graph_wave_resolve() cannot find TOP.m.siga in the analog
# DB, returns 0, and graph_marker_create_at refuses -> "".
set ::nd_mv [pcall {xschem graph_marker add_at 0 1 0 1}]
check_true "NDM2 a marker lands on the VCD trace (issue 0305: it was refused)" \
  [expr {[string is integer -strict $::nd_mv] && $::nd_mv > 0}]

# the READOUT is the half that says WHICH database answered. The analog band is
# 0.25..0.30 V and the VCD's only two values are 0 and 1: they cannot be
# confused, so this distinguishes "resolved in the VCD" from "resolved
# somewhere and returned a number".
array set ndrec {}
foreach rec [pcall {xschem graph_marker list 0}] {
  set ndrec([lindex $rec 0]) $rec
}
set anlg_y {}; set vcd_y {}; set anlg_x {}; set vcd_x {}
if {[info exists ndrec($::nd_ma)]} {
  set anlg_x [lindex $ndrec($::nd_ma) 5]; set anlg_y [lindex $ndrec($::nd_ma) 6]
}
if {[string is integer -strict $::nd_mv] && [info exists ndrec($::nd_mv)]} {
  set vcd_x [lindex $ndrec($::nd_mv) 5]; set vcd_y [lindex $ndrec($::nd_mv) 6]
}
check_true "NDM3 the analog marker reads a value in the ANALOG band 0.25..0.30" \
  [expr {$anlg_y ne {} && $anlg_y >= 0.24 && $anlg_y <= 0.31}]
check_true "NDM4 the VCD marker reads a LOGIC LEVEL, never an analog voltage" \
  [expr {$vcd_y ne {} && ($vcd_y == 0.0 || $vcd_y == 1.0)}]
check_true "NDM5 the two markers read DIFFERENT x, i.e. different time bases" \
  [expr {$anlg_x ne {} && $vcd_x ne {} && $anlg_x != $vcd_x}]
check_true "NDM6 the VCD marker's time is inside the VCD's 0..2ns span" \
  [expr {$vcd_x ne {} && $vcd_x >= 0.0 && $vcd_x <= 2.0e-9}]
# sweep every VCD sample: EVERY readout must be a logic level, and at least one
# must be 1 -- a walk that landed in the analog DB could produce neither.
set ndlv {}
for {set p 0} {$p < $::nd_vcd_points} {incr p} {
  pcall {xschem graph_marker delete -all}
  set num [pcall {xschem graph_marker add_at 0 1 0 $p}]
  if {![string is integer -strict $num] || $num <= 0} { lappend ndlv "REFUSED@$p"; continue }
  foreach rec [pcall {xschem graph_marker list 0}] {
    if {[lindex $rec 0] == $num} { lappend ndlv [lindex $rec 6] }
  }
}
check "NDM7 every VCD sample reads back as 0 or 1 and nothing was refused" \
  [lsort -unique $ndlv] {0 1}
check_true "NDM8 ...and at least one of them is 1 (a value the analog DB has\
 nowhere in its range)" [expr {[lsearch -exact $ndlv 1] >= 0}]
check "NDM9 the current database is unchanged after the marker readouts" \
  [pcall {xschem raw rawfile}] $rawf
check "NDM10 ...and so is the registry's current slot" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}
# the DRAG-COMMIT path: graph_marker_release -> graph_marker_anchor_at ->
# graph_marker_sample -> graph_wave_resolve, the route a mouse actually takes
pcall {xschem graph_marker delete -all}
set ::nd_md [pcall {xschem graph_marker add_at 0 1 0 1}]
check "NDM11 re-anchoring the VCD marker (the drag-commit route) succeeds" \
  [pcall {xschem graph_marker anchor $::nd_md 0 3}] 1
set ndanchor {}
foreach rec [pcall {xschem graph_marker list 0}] {
  if {[lindex $rec 0] == $::nd_md} { set ndanchor [lindex $rec 6] }
}
check_true "NDM12 ...and the re-anchored readout is still a logic level" \
  [expr {$ndanchor ne {} && ($ndanchor == 0.0 || $ndanchor == 1.0)}]
check "NDM13 the current database survives the re-anchor too" \
  [pcall {xschem raw rawfile}] $rawf
pcall {xschem graph_marker delete -all}

# ===========================================================================
# NDS — THE NESTED STRIP: a carried-forward sweep COLUMN, and the LEVEL the
# per-node unwind goes back to. Strip 3 only.
# ===========================================================================
# Every check here would have SEGFAULTED the process (not merely failed) with a
# walker that carries the sweep index across the per-trace switch: v(wsw) is
# column 4 of the wide raw and the VCD has three columns, so values[4] is off the
# end. That is why the whole leg is written against ONE strip whose `sweep=`
# list is deliberately shorter than its `node=` list.
set ::nd_cx3 [nd_colx $::nd_box3 0.375]
set ::nd_hits3 [nd_column 3 $::nd_box3 $::nd_cx3]
# node 0 = v(wonly) (wide DB), node 1 = the VCD, node 2 = v(wtwo) (wide DB, and
# reachable only if the unwind after node 1 went back to the WIDE database).
check "NDS1 all THREE traces of the nested strip pick, including the one AFTER\
 the cross-DB entry" [nd_nodes $::nd_hits3] {0 1 2}
set s0 [nd_row_of $::nd_hits3 0]
set s1 [nd_row_of $::nd_hits3 1]
set s2 [nd_row_of $::nd_hits3 2]
# 0.61 V, logic 1 and -0.24 V on a -0.4..1.4 axis: the VCD is on top, then
# v(wonly), then v(wtwo). Screen y grows downward.
check_true "NDS2 they are three DIFFERENT rows in the order the VALUES demand\
 (VCD 1 above v(wonly) 0.61 above v(wtwo) -0.24)" \
  [expr {$s0 ne {} && $s1 ne {} && $s2 ne {} && $s1 < $s0 && $s0 < $s2}]
check_true "NDS3 the cross-DB trace of the nested strip builds an envelope" \
  [expr {[pcall {xschem get wave_hilight_points 3 1}] >= $::nd_vcd_points}]
check_true "NDS4 ...and so does the entry that follows it in the graph's own DB" \
  [expr {[pcall {xschem get wave_hilight_points 3 2}] > 0}]
pcall {xschem graph_marker delete -all}
set ::nd_ms [pcall {xschem graph_marker add_at 3 1 0 1}]
check_true "NDS5 a marker lands on the nested strip's cross-DB trace" \
  [expr {[string is integer -strict $::nd_ms] && $::nd_ms > 0}]
set nds_y {}; set nds_x {}
foreach rec [pcall {xschem graph_marker list 3}] {
  if {[lindex $rec 0] == $::nd_ms} { set nds_x [lindex $rec 5]; set nds_y [lindex $rec 6] }
}
# the three bands are 0.60..0.65 (wide), 0.70..0.75 (other) and 0/1 (VCD): a
# readout of exactly 0 or 1 can only have come from the VCD.
check_true "NDS6 ...and reads a LOGIC LEVEL, i.e. out of the VCD and not out of\
 the graph's own wide raw" [expr {$nds_y ne {} && ($nds_y == 0.0 || $nds_y == 1.0)}]
# THE X COLUMN, sample by sample. Carrying the wide raw's column 4 across reads
# off the end of the VCD's values[]; carrying ANY in-range foreign column reads
# the VCD's SIGNAL as if it were time. Neither survives "strictly increasing
# times inside the VCD's own span", and one value in isolation would (a logic 0
# is a perfectly plausible-looking 0.0 seconds).
set nds_xs {}
for {set p 0} {$p < $::nd_vcd_points} {incr p} {
  pcall {xschem graph_marker delete -all}
  set num [pcall {xschem graph_marker add_at 3 1 0 $p}]
  if {![string is integer -strict $num] || $num <= 0} { lappend nds_xs REFUSED; continue }
  foreach rec [pcall {xschem graph_marker list 3}] {
    if {[lindex $rec 0] == $num} { lappend nds_xs [lindex $rec 5] }
  }
}
set nds_mono [expr {[llength $nds_xs] == $::nd_vcd_points}]
for {set k 0} {$nds_mono && $k < [llength $nds_xs]} {incr k} {
  set v [lindex $nds_xs $k]
  if {![string is double -strict $v] || $v < 0.0 || $v > 2.0e-9} { set nds_mono 0; break }
  if {$k > 0 && $v <= [lindex $nds_xs [expr {$k - 1}]]} { set nds_mono 0; break }
}
check_true "NDS7 ...and every one of its samples reads a STRICTLY INCREASING time\
 inside the VCD's own 0..2ns span (the x column is the VCD's time, not a column\
 number carried in from the wide raw)" \
  [expr {$nds_x ne {} && $nds_x >= 0.0 && $nds_x <= 2.0e-9 && $nds_mono}]
pcall {xschem graph_marker delete -all}
set ::nd_ms2 [pcall {xschem graph_marker add_at 3 2 0 1}]
set nds2_y {}
foreach rec [pcall {xschem graph_marker list 3}] {
  if {[lindex $rec 0] == $::nd_ms2} { set nds2_y [lindex $rec 6] }
}
check_true "NDS8 a marker on the entry AFTER the cross-DB one reads the wide\
 raw's own band -0.25..-0.20" \
  [expr {$nds2_y ne {} && $nds2_y >= -0.26 && $nds2_y <= -0.19}]
check "NDS9 two levels of switch later, the session's database is untouched" \
  [pcall {xschem raw rawfile}] $rawf
check "NDS10 ...and so is the registry's current slot" \
  [pcall {lindex [split [xschem raw info] "\n"] 0}] {0 current}
pcall {xschem graph_marker delete -all}

# ===========================================================================
# NDG — the `%` GRAMMAR the shared helper must keep answering for
# ===========================================================================
# (a) a bare `%<n>` dataset restriction, the ONLY use of `%` before spec D1.
nd_setnode 0 "v(anlg)%0"
check "NDG1 `%0` on a single-dataset raw still picks (dataset 0 exists)" \
  [nd_nodes [nd_column 0 $::nd_box0 $::nd_cx]] {0}
nd_setnode 0 "v(anlg)%1"
check "NDG2 `%1` picks NOTHING: the dataset digits still restrict" \
  [nd_nodes [nd_column 0 $::nd_box0 $::nd_cx]] {}
# (b) digits AND a rawfile in the same field -- the two-token form the grammar
# allows and which no test covered before.
nd_setnode 0 "\\\"vcdsig;TOP.m.siga%0 $vcdf vcd\\\""
check "NDG3 `%0 <rawfile> <type>` resolves BOTH halves: dataset 0 of the VCD" \
  [nd_nodes [nd_column 0 $::nd_box0 [nd_colx $::nd_box0 0.375]]] {0}
nd_setnode 0 "\\\"vcdsig;TOP.m.siga%1 $vcdf vcd\\\""
check "NDG4 `%1 <rawfile> <type>` picks nothing: the VCD has one dataset" \
  [nd_nodes [nd_column 0 $::nd_box0 [nd_colx $::nd_box0 0.375]]] {}
# (c) a database that cannot be resolved must REFUSE the trace, not silently
# fall back to the current DB and plot a different signal.
nd_setnode 0 "\\\"gone;v(anlg)%$scratch/nosuch.raw tran\\\""
check "NDG5 an unresolvable %<rawfile> makes the trace unpickable (it does NOT\
 fall back to the current database and answer with v(anlg))" \
  [nd_nodes [nd_column 0 $::nd_box0 $::nd_cx]] {}
check "NDG6 ...and the current database is untouched by that failure" \
  [pcall {xschem raw rawfile}] $rawf
check "NDG7 ...and the envelope for it is empty too" \
  [pcall {xschem get wave_hilight_points 0 0}] 0
check "NDG8 ...and a marker on it is refused" \
  [pcall {xschem graph_marker add_at 0 0 0 1}] {}
# (d) the unsuffixed entry: the shape of every graph shipped before spec D1.
nd_setnode 0 "v(anlg)"
check "NDG9 a plain unsuffixed entry is unchanged by the shared parser" \
  [nd_nodes [nd_column 0 $::nd_box0 $::nd_cx]] {0}
check_true "NDG10 ...and still builds its envelope" \
  [expr {[pcall {xschem get wave_hilight_points 0 0}] > 0}]
# (e) an alias with no `%` at all -- the parser must not eat the alias
nd_setnode 0 "\\\"nice name;v(anlg)\\\""
check "NDG11 an alias entry with no % still resolves its vector" \
  [nd_nodes [nd_column 0 $::nd_box0 $::nd_cx]] {0}
# (f) `%<rawfile>` with the sim_type field OMITTED -- a legal token, and the arm
# node_dflt_sim_type() exists for: with no type of its own the entry inherits the
# graph's `sim_type=`, and failing that the CURRENT database's. Nothing else in
# this file exercises it (every other `%` token here spells out `vcd`), and an
# empty type makes extra_rawfile() match no slot at all, so the trace would
# simply stop resolving.
nd_setnode 0 "\\\"oth;v(other)%$othf\\\""
check "NDT1 a `%<rawfile>` with NO sim_type still resolves (the type is\
 inherited, not required)" [nd_nodes [nd_column 0 $::nd_box0 $::nd_cx]] {0}
check_true "NDT2 ...and builds its envelope" \
  [expr {[pcall {xschem get wave_hilight_points 0 0}] > 0}]
pcall {xschem graph_marker delete -all}
set ::nd_mt [pcall {xschem graph_marker add_at 0 0 0 1}]
check_true "NDT3 ...and takes a marker" \
  [expr {[string is integer -strict $::nd_mt] && $::nd_mt > 0}]
set ndt_y {}
foreach rec [pcall {xschem graph_marker list 0}] {
  if {[lindex $rec 0] == $::nd_mt} { set ndt_y [lindex $rec 6] }
}
# 0.70..0.75 is the SECOND analog raw's band; the session raw's is 0.25..0.30.
# The value is what says the inherited type resolved the right database.
check_true "NDT4 ...whose readout is in the SECOND raw's band 0.70..0.75, not the\
 session raw's 0.25..0.30" [expr {$ndt_y ne {} && $ndt_y >= 0.69 && $ndt_y <= 0.76}]
check "NDT5 ...and the session's database is unchanged" [pcall {xschem raw rawfile}] $rawf
pcall {xschem graph_marker delete -all}

# ===========================================================================
# NDY — graph_fullyzoom(), the fourth walker reachable without a display
# ===========================================================================
# The VCD-only strip autoscales Y. Its data is 0..1; the analog raw it would
# have measured instead is 0.25..0.30, so the resulting window says which
# database the Y walk read.
# THE SEED IS PART OF THE CHECK. It used to be -5 / 5, which already satisfied
# "spans 0..1" -- so a fullyzoom that did NOTHING AT ALL passed both NDY1 and
# NDY2 and the whole leg proved nothing about the walker. The seed is now a
# window strictly INSIDE the answer, one that only a fullyzoom that actually ran
# AND actually read the VCD can widen to 0..1.
xschem setprop rect 2 1 y1 0.4
xschem setprop rect 2 1 y2 0.6
xschem setprop rect 2 1 fullyzoom
set ndy1 [pcall {xschem getprop rect 2 1 y1}]
set ndy2 [pcall {xschem getprop rect 2 1 y2}]
check_true "NDY1 fullyzoom on the VCD-only strip MOVED the window off the 0.4..0.6\
 seed (a walker that returned without doing anything fails here)" \
  [expr {[string is double -strict $ndy1] && [string is double -strict $ndy2] &&
         ($ndy1 != 0.4 || $ndy2 != 0.6)}]
check_true "NDY2 ...that spans the VCD's 0..1, not the analog band 0.25..0.30" \
  [expr {[string is double -strict $ndy1] && [string is double -strict $ndy2] &&
         $ndy1 <= 0.05 && $ndy2 >= 0.95}]
check "NDY3 ...and leaves the current database alone" [pcall {xschem raw rawfile}] $rawf

# ===========================================================================
# NDX — the STRUCTURAL guard: ONE `%` parser, and all six walkers on it
# ===========================================================================
# THE ITEM'S PRIMARY DELIVERABLE IS A STRUCTURE, and every check above it is
# behavioural: re-inlining a private `%` parse into one walker leaves all of them
# green, which is EXACTLY how this drifted to three-of-six in the first place.
# So this leg reads the source. It is the WH9h idiom of test_wave_hilight.tcl:
# code lines only, because a comment that mentions the parser is not a parser.
set ndrepo [file dirname [file dirname $here]]
set ndfp [open [file join $ndrepo src draw.c] r]; set nddraw [read $ndfp]; close $ndfp
proc nd_is_code {line} {
  set t [string trimleft $line]
  if {[string index $t 0] eq "*"} { return 0 }
  if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { return 0 }
  return 1
}
set ndpct {}      ;# the lines that read the `%` field out of a node= token
set ndcalls 0     ;# node_token_split() CALL sites (the definition is not one)
set nddef -1; set ndend -1; set ndk 0
foreach ndline [split $nddraw "\n"] {
  if {[string first "static void node_token_split(" $ndline] == 0} { set nddef $ndk }
  if {$nddef >= 0 && $ndend < 0 && $ndk > $nddef && $ndline eq "\}"} { set ndend $ndk }
  if {[nd_is_code $ndline]} {
    if {[regexp {find_nth\([A-Za-z_][A-Za-z0-9_]*, *"%"} $ndline]} { lappend ndpct $ndk }
    if {[regexp {node_token_split\(} $ndline] &&
        [string first "static void" $ndline] != 0} { incr ndcalls }
  }
  incr ndk
}
check "NDX1 draw.c reads the `%` field of a node= token in exactly TWO places\
 (the expression half and the payload half of ONE parser)" [llength $ndpct] 2
check_true "NDX2 ...and both of them are inside node_token_split(): a seventh\
 hand-rolled copy anywhere else fails HERE and nowhere else" \
  [expr {$nddef >= 0 && $ndend > $nddef && [llength $ndpct] == 2 &&
         [lindex $ndpct 0] > $nddef && [lindex $ndpct end] < $ndend}]
check "NDX3 all SIX node= walkers call the shared parser" $ndcalls 6

set ::nd_body_completed 1

} err]} {
  puts "FAIL: uncaught error in test body: $err : FAIL"
  incr fail
  puts $::errorInfo
}

# ===========================================================================
# NDZ — the coverage self-check (the WZ1/MZ1 idiom): a run that quietly stopped
# executing half its legs still prints a happy banner, so the file knows how
# many checks it owes. EDITING THIS FILE: add or remove a leg, run it once, and
# put the new number here by hand. The count EXCLUDES the two NDZ legs, so the
# RESULT line reads two higher.
# ===========================================================================
set ::nd_expect 89
set ndgot [expr {$npass + $fail}]
check "NDZ1 the file ran its full complement of checks (a silent shortfall is\
 the failure this guards)" \
  [expr {$ndgot == $::nd_expect ? {ok} : "RAN $ndgot of $::nd_expect"}] ok
check "NDZ2 the body reached its end (no group unwound into the outer catch)" \
  [expr {[info exists ::nd_body_completed] ? 1 : 0}] 1

puts "----"
puts "test_node_token_split: $npass passed, $fail failed"
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
  exit 0
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
  exit 1
}
