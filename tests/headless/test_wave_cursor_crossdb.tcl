# tests/headless/test_wave_cursor_crossdb.tcl — spec D4: a cursor at time t
# resolves in EVERY database contributing a trace, and the rule for HOW it
# resolves differs between a dense analog sweep and a sparse event stream.
#
# Spec: doc/claude/specs/mixed_signal_signal_browser.md, row D4 and the
#       "D4 — cursors and markers across databases" section (RULINGS D4-1..D4-4).
# Receipt: doc/claude/batch_F/receipts/09-d4-cursors-and-markers-across-dbs.md
#
# WHAT THIS PINS.
#
# annot_p / annot_x / annot_sweep_idx / cursor_b_val are fields of `Raw`
# (src/xschem.h), i.e. PER DATABASE, and backannotate_at_cursor_b_pos()
# (src/callback.c) resolved cursor B in xctx->raw and nowhere else. With one
# database nobody notices. With an analog raw and a VCD loaded together a cursor
# at t was not one object at one time -- it was N objects that happened to have
# been placed together: the current database read correctly and every other one
# kept whatever index it was last left with, which for a database that was never
# current is annot_p == -1 and a cursor_b_val[] still full of my_calloc zeros.
#
# THE LEGS
#   XC0*  the fixture and its PREMISE: four databases, the analog one current,
#         and each database's vectors ABSENT from the others. Without that, a
#         readout could be right by accident.
#   XC1*  RULING D4-1: the cursor resolves in every contributing database.
#         This is the item's own defect and these are the checks that are red
#         at the parent commit.
#   XC2*  RULING D4-3: HOLD on a sparse stream. The cursor is parked INSIDE the
#         one-tick step vcd_read() materializes at a change (spec C2 emits
#         (t - 1 tick, old) then (t, new)), where hold and interpolation give
#         DIFFERENT answers -- and the interpolated one is 0.5, which is the
#         VCD encoding of X (spec C3). The `$timescale 1ns` in the fixture is
#         load-bearing: it makes that step a nanosecond wide instead of a
#         picosecond, i.e. reachable by a cursor a human could place.
#   XC3*  RULING D4-4: the two BOUNDARIES. Before a database's first sample and
#         after its last one the readout is that sample verbatim -- no
#         extrapolation, in either direction, for either kind of database.
#         `late.raw` exists only for this: an ANALOG database whose first sample
#         is at 1 us, so a cursor at 0.5 us is genuinely before it (the session
#         raw starts at 0 and cannot produce that case).
#   XC4*  the cursor MOVES and every database follows -- the check a stale
#         annot_sweep_idx / annot_p in one database is invisible to otherwise.
#   XC5*  RULING D4-2: exactly ONE database publishes ngspice::ngspice_data, and
#         it is the one that is current on entry. D5 (what a digital database
#         contributes to schematic backannotation) is still open and is NOT
#         decided here.
#   XC6*  the registry cursor is a PAIR and the fan-out moves NEITHER half.
#         backannotate_at_cursor_b_pos() now switches databases on every cursor
#         motion; a walker that does that owes both halves back (batch F item 2,
#         finding 1).
#   XC7*  structural: the `%` parse behind the enumeration is node_token_split()
#         and the HOLD arm is a single `vcd` test in one function.
#   XC9*  the coverage self-check.
#
# NOT COVERED HERE, deliberately: MARKERS. A marker is bound to ONE trace
# (GraphMarker.wave), so it is single-database by construction and
# graph_marker_sample() -> graph_wave_resolve() already switches to that trace's
# own database -- issue 0305 / batch F item 1, pinned by the NDM leg of
# tests/headless/test_node_token_split.tcl. The cursor is the one that is
# per-STRIP and therefore has to fan out.
#
# True headless: run under --nogui.
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_cursor_crossdb.tcl

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
# a numeric comparison with an absolute tolerance, so a check reads as a number
proc near {name got exp {tol 1e-9}} {
  if {[string is double -strict $got] && abs($got - $exp) <= $tol} {
    check $name near-$exp near-$exp
  } else {
    check $name "$got" "within $tol of $exp"
  }
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch xccur]
set ::XSCHEM_LIBRARY_PATH {}

proc wr {p s} { set fp [open $p w]; puts -nonewline $fp $s; close $fp }

# ---------------------------------------------------------------------------
# the fixture. Four databases, four disjoint value bands, so a readout says
# WHICH database answered rather than merely "something did":
#   anlg.raw   0 .. 2 us, dense (50 ns step), v(anlg) 0.25 .. 0.30
#   late.raw   1 us .. 2 us, dense, v(late) 0.60 .. 0.65   <- starts LATE
#   d1.vcd     0 .. 200 ns, sparse, TOP.m.siga  levels 0 / 1
#   d2.vcd     500 .. 900 ns, sparse, TOP.m.sigb levels 0 / 1  <- starts LATE
# ---------------------------------------------------------------------------
proc mkraw {path name lo hi t0 tmax {n 41}} {
  set body "Title: xc\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\t$name\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$t0 + $i * ($tmax - $t0) / ($n - 1)}]
    set v [expr {$lo + ($hi - $lo) * $i / ($n - 1)}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}

# a 1-bit VCD on a NANOSECOND time base. `$timescale 1ns` is not decoration:
# vcd_read() materializes each change as (t - 1 tick, old) then (t, new), so the
# tick size IS the width of the step a cursor can be parked inside. At 1 ps that
# window is unreachable; at 1 ns it is where a human puts a cursor.
# `events` is a flat list {tick value ...}; `endtick` is the trailing bare `#t`.
proc mkvcd {path sig events endtick} {
  set body "\$timescale 1ns \$end
\$scope module TOP \$end
 \$scope module m \$end
  \$var wire 1 ! $sig \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
"
  foreach {tick val} $events { append body "#$tick\n$val!\n" }
  append body "#$endtick\n"
  wr $path $body
}

# every (time, value) pair of `name` in the CURRENT database, as a flat list
proc xc_samples {name} {
  set np [xschem raw points]
  set out {}
  for {set p 0} {$p < $np} {incr p} {
    lappend out [xschem raw value time $p] [xschem raw value $name $p]
  }
  return $out
}

# place cursor B at t and let the engine backannotate
proc xc_cursor {t} { xschem set cursor2_x $t }

# the current database's cursor-B annotation state
proc xc_annot {} { return [xschem raw annot] }
proc xc_annot_p {} { return [lindex [xschem raw annot] 0] }

if {[catch {

# ===========================================================================
# XC0 — the fixture and the PREMISE
# ===========================================================================
set rawf  [file join $scratch anlg.raw]
set latef [file join $scratch late.raw]
set v1f   [file join $scratch d1.vcd]
set v2f   [file join $scratch d2.vcd]
mkraw $rawf  {v(anlg)} 0.25 0.30 0.0   2.0e-6
mkraw $latef {v(late)} 0.60 0.65 1.0e-6 2.0e-6
# d1: 0 -> 1 at 50 ns, 1 -> 0 at 100 ns, 0 -> 1 at 150 ns, run ends at 200 ns
mkvcd $v1f siga {0 0 50 1 100 0 150 1} 200
# d2: starts LATE. 1 at 500 ns, 0 at 600 ns, 1 at 800 ns, run ends at 900 ns
mkvcd $v2f sigb {500 1 600 0 800 1} 900

check "XC01 the analog raw reads (slot 0)" [pcall {xschem raw clear; xschem raw read $rawf tran}] 1
check "XC02 the VCD d1 reads (slot 1)"     [pcall {xschem raw read $v1f vcd}] 1
check "XC03 the VCD d2 reads (slot 2)"     [pcall {xschem raw read $v2f vcd}] 1
check "XC04 the LATE analog raw reads (slot 3)" [pcall {xschem raw read $latef tran}] 1
check "XC05 back to the analog DB" [pcall {xschem raw switch 0}] 1
check "XC06 the ANALOG database is the current one" [pcall {xschem raw sim_type}] tran
check "XC07 four databases, analog at slot 0" \
  [pcall {list [lindex [split [xschem raw info] "\n"] 0] \
               [llength [lrange [split [xschem raw info] "\n"] 1 end-1]]}] {{0 current} 4}
# THE PREMISE: no name is shared, so no readout below can be right by accident
check "XC08 the VCDs' signals are ABSENT from the current database" \
  [pcall {list [xschem raw index TOP.m.siga] [xschem raw index TOP.m.sigb]}] {-1 -1}
check "XC09 ...and v(late) is absent from it too" [pcall {xschem raw index v(late)}] -1
check_true "XC09b ...and v(anlg) IS in it" [expr {[xschem raw index v(anlg)] >= 0}]

# the sample grids, read off the engine rather than predicted
xschem raw switch 1
set d1s [xc_samples TOP.m.siga]
xschem raw switch 2
set d2s [xc_samples TOP.m.sigb]
set d2_first_t [lindex $d2s 0]
set d2_first_v [lindex $d2s 1]
set d2_last_t  [lindex $d2s end-1]
set d2_last_v  [lindex $d2s end]
xschem raw switch 3
set lates [xc_samples {v(late)}]
set late_first_t [lindex $lates 0]
set late_first_v [lindex $lates 1]
xschem raw switch 0
set anlgs [xc_samples {v(anlg)}]
set anlg_last_t [lindex $anlgs end-1]
set anlg_last_v [lindex $anlgs end]

puts "# d1 samples: $d1s"
puts "# d2 samples: $d2s"
puts "# late head: [lrange $lates 0 3]  anlg tail: [lrange $anlgs end-3 end]"
# THE PREMISES THE BOUNDARY LEG RESTS ON. Each of these is a property of the
# fixture, and each of them, if it silently stopped holding, would make an XC3
# check pass against code that extrapolates.
check_true "XC0a d1 carries the one-tick STEP at the 100 ns change: samples at\
 99 ns (old value 1) and 100 ns (new value 0)" \
  [expr {abs([lindex $d1s 6] - 99e-9) < 1e-12 && [lindex $d1s 7] == 1.0 &&
         abs([lindex $d1s 8] - 100e-9) < 1e-12 && [lindex $d1s 9] == 0.0}]
check_true "XC0b d2's FIRST sample is well after 0, so a cursor can precede it" \
  [expr {[string is double -strict $d2_first_t] && $d2_first_t > 400e-9}]
check_true "XC0c ...and its first value is not 0.0, so a hit cannot be confused\
 with an unannotated my_calloc'd cursor_b_val" [expr {$d2_first_v != 0.0}]
check_true "XC0d ...and its LAST value is not 0.0 either" [expr {$d2_last_v != 0.0}]
# SPICE_DATA is a FLOAT, so every value out of a raw carries ~1e-7 relative
# error (0.30 reads back as 0.30000001). Every tolerance here is sized for that.
check_true "XC0e late.raw's first sample is at 1 us, and its value is 0.60" \
  [expr {abs($late_first_t - 1.0e-6) < 1e-12 && abs($late_first_v - 0.60) < 1e-6}]
check_true "XC0f late.raw's SECOND sample differs from its first, so a backward\
 extrapolation off that segment is a different number from holding" \
  [expr {[lindex $lates 3] != $late_first_v}]
check_true "XC0g the session raw's last sample is 2 us / 0.30" \
  [expr {abs($anlg_last_t - 2.0e-6) < 1e-12 && abs($anlg_last_v - 0.30) < 1e-6}]

# ---------------------------------------------------------------------------
# the mixed strip. Rect 0 of GRIDLAYER is the one `xschem set cursor2_x` drives
# (scheduler.c). The cross-DB entries are written in the shape
# wviewer::graph_props emits: an `alias;vec%<path> <type>` entry inside literal
# double quotes.
# ---------------------------------------------------------------------------
set Q1 "\\\"dig1;TOP.m.siga%$v1f vcd\\\""
set Q2 "\\\"dig2;TOP.m.sigb%$v2f vcd\\\""
set QL "\\\"lateanlg;v(late)%$latef tran\\\""
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem setprop rect 2 0 node "v(anlg)\n$Q1\n$Q2\n$QL"
# the window spans every database AND runs past the end of all of them, so a
# cursor can be placed beyond the last sample of each without leaving it
foreach {t v} [list x1 0 x2 3e-6 y1 -0.3 y2 1.3] { xschem setprop rect 2 0 $t $v }
# populate xctx->graph_struct (gx1/gx2/dataset) from rect 0: `set cursor2_x`
# hands the SHARED graph ctx to backannotate_at_cursor_b_pos() and a zeroed one
# has gx1 == gx2 == 0, which puts every sample outside [start,end].
xschem setprop rect 2 0 fullyzoom
xschem cursor 2 1
check_true "XC0h cursor B is enabled (graph_flags bit 4)" \
  [expr {[xschem get graph_flags] & 4}]

# ===========================================================================
# XC1 — RULING D4-1: the cursor resolves in EVERY contributing database
# ===========================================================================
# t = 175 ns. Inside d1 (last event 150 ns -> 1), before d2's first sample,
# before late.raw's first sample, and between two analog samples (150/200 ns).
xc_cursor 175e-9
xschem raw switch 0
near "XC11 the SESSION database resolves (unchanged behaviour): v(anlg)\
 interpolated at 175 ns" [xschem raw value {v(anlg)} {}] 0.2543750 1e-9
check_true "XC12 ...and it says so in its own annotation state" \
  [expr {[xc_annot_p] >= 0}]
xschem raw switch 1
near "XC13 THE DEFECT: the VCD named by a `%<rawfile>` entry resolves TOO --\
 TOP.m.siga holds the value its last event set" [xschem raw value TOP.m.siga {}] 1.0
check_true "XC14 ...and d1 carries a real annotation index, not the -1 of a\
 database no cursor ever reached" [expr {[xc_annot_p] >= 0}]
xschem raw switch 2
near "XC15 the SECOND VCD resolves as well: three databases, one cursor" \
  [xschem raw value TOP.m.sigb {}] $d2_first_v
check_true "XC15b ...with its own annotation index" [expr {[xc_annot_p] >= 0}]
xschem raw switch 3
near "XC16 and so does the second ANALOG database" \
  [xschem raw value {v(late)} {}] $late_first_v
xschem raw switch 0
check "XC17 the cursor position each database recorded is the SAME t: one\
 cursor, one time" \
  [pcall {set l {}
          foreach s {0 1 2 3} { xschem raw switch $s; lappend l [lindex [xc_annot] 1] }
          xschem raw switch 0
          lsort -unique $l}] 1.75e-07

# a database that contributes NO trace to this strip is not annotated by it.
# (It is still annotated when it is the CURRENT one -- that is RULING D4-1's
# first clause and XC11 is the check for it.)
set sparef [file join $scratch spare.vcd]
mkvcd $sparef sigspare {0 1 40 0} 100
check "XC18 a fifth, UNCONTRIBUTING VCD reads as slot 4" \
  [pcall {xschem raw read $sparef vcd}] 1
xschem raw switch 0
xschem setprop rect 2 0 fullyzoom
xc_cursor 175e-9
xschem raw switch 4
check "XC19 a database this strip plots NOTHING from is left alone" [xc_annot_p] -1
xschem raw switch 0

# ===========================================================================
# XC2 — RULING D4-3: HOLD on a sparse event stream
# ===========================================================================
# 99.5 ns is INSIDE the one-tick step d1 carries at its 100 ns change: the
# sample at 99 ns still holds the old value 1, the sample at 100 ns carries the
# new value 0. The value a digital signal has at 99.5 ns is the one its last
# event set, i.e. 1. Interpolating the pair gives 0.5 -- which spec C3 makes the
# VCD encoding of X, so the readout would report UNKNOWN for a signal whose
# value is perfectly well known.
xc_cursor 99.5e-9
xschem raw switch 1
near "XC21 HOLD: at 99.5 ns TOP.m.siga reads 1, the value its last event set" \
  [xschem raw value TOP.m.siga {}] 1.0
check_true "XC22 ...and specifically NOT 0.5, which is the X sentinel an\
 interpolation across the step would invent (spec C3)" \
  [expr {abs([xschem raw value TOP.m.siga {}] - 0.5) > 0.1}]
xschem raw switch 0
near "XC23 the DENSE analog database in the same breath still INTERPOLATES\
 between its samples (99.5 ns is not a sample of it)" \
  [xschem raw value {v(anlg)} {}] 0.2524875 1e-9
check_true "XC23b ...i.e. its readout is STRICTLY BETWEEN the two samples that\
 bracket the cursor (0.25125 at 50 ns and 0.2525 at 100 ns), which is what makes\
 XC23 an interpolation and not a hold" \
  [expr {[xschem raw value {v(anlg)} {}] > 0.25125 &&
         [xschem raw value {v(anlg)} {}] < 0.2525}]
# the mirror case: park inside the OTHER step edge, 0 -> 1 at 50 ns
xc_cursor 49.5e-9
xschem raw switch 1
near "XC24 HOLD at the rising step too: 49.5 ns reads 0, not 0.5" \
  [xschem raw value TOP.m.siga {}] 0.0
check_true "XC24b ...and d1 really was annotated at that t (a 0.0 from a\
 my_calloc'd cursor_b_val would read the same)" \
  [expr {[xc_annot_p] >= 0 && [lindex [xc_annot] 1] == 4.95e-08}]
xschem raw switch 0

# ===========================================================================
# XC3 — RULING D4-4: the two boundaries, no extrapolation either way
# ===========================================================================
# (a) BEFORE a database's first sample.
xc_cursor 0.5e-6
xschem raw switch 3
near "XC31 before late.raw's first sample the readout is that first sample\
 VERBATIM (0.60), not a backward extrapolation off its first segment" \
  [xschem raw value {v(late)} {}] $late_first_v 1e-9
xschem raw switch 2
near "XC32 ...and the same rule on the sparse stream: d2 reads its first sample" \
  [xschem raw value TOP.m.sigb {}] $d2_first_v 1e-9
xschem raw switch 0
# moving the cursor FURTHER before the first sample must not move the readout:
# an extrapolation would, and by a different amount each time, whatever the
# slope happens to be
set xc_late_a [pcall {xschem raw switch 3; xschem raw value {v(late)} {}}]
xschem raw switch 0
xc_cursor 0.1e-6
set xc_late_b [pcall {xschem raw switch 3; xschem raw value {v(late)} {}}]
xschem raw switch 0
check "XC33 ...and it does not move as the cursor goes further back: an\
 extrapolation is a function of the distance, a hold is not" $xc_late_b $xc_late_a

# (b) AFTER a database's last sample.
xc_cursor 2.5e-6
xschem raw switch 0
near "XC34 past the session raw's last sample the readout is that last sample\
 VERBATIM (0.30). The old point_not_last test let interpolate_yval read one\
 element past the end of the my_calloc(allpoints) buffer" \
  [xschem raw value {v(anlg)} {}] $anlg_last_v 1e-9
set xc_anlg_a [xschem raw value {v(anlg)} {}]
xschem raw switch 1
near "XC35 ...and d1, whose run ended at 200 ns, holds its last value" \
  [xschem raw value TOP.m.siga {}] [lindex $d1s end] 1e-9
xschem raw switch 2
near "XC36 ...and so does d2" [xschem raw value TOP.m.sigb {}] $d2_last_v 1e-9
xschem raw switch 0
xc_cursor 2.9e-6
check "XC37 ...and none of them moves as the cursor goes further past the end" \
  [pcall {xschem raw value {v(anlg)} {}}] $xc_anlg_a

# ===========================================================================
# XC4 — the cursor MOVES and every database follows
# ===========================================================================
xc_cursor 125e-9
set xc_m1 [pcall {set l {}
                  foreach s {0 1 2 3} { xschem raw switch $s; lappend l [xc_annot_p] }
                  xschem raw switch 0; set l}]
set xc_v1 [pcall {xschem raw switch 1; xschem raw value TOP.m.siga {}}]
set xc_a1 [pcall {xschem raw switch 1; xc_annot_p}]
xschem raw switch 0
xc_cursor 175e-9
set xc_m2 [pcall {set l {}
                  foreach s {0 1 2 3} { xschem raw switch $s; lappend l [xc_annot_p] }
                  xschem raw switch 0; set l}]
set xc_v2 [pcall {xschem raw switch 1; xschem raw value TOP.m.siga {}}]
xschem raw switch 0
# 0.0 is also what an UNANNOTATED my_calloc'd cursor_b_val reads, so the value
# alone would be green against the broken code: the annotation index carries the
# positive half of this check.
check_true "XC41 at 125 ns d1 reads 0 (the value its 100 ns event set) AND is\
 genuinely annotated there" \
  [expr {abs($xc_v1) < 1e-9 && [string is integer -strict $xc_a1] && $xc_a1 >= 0}]
near "XC42 at 175 ns d1 reads 1 (its 150 ns event) -- the sparse database\
 FOLLOWED the move" $xc_v2 1.0
check_true "XC43 the SESSION database's annotation index moved too" \
  [expr {[lindex $xc_m1 0] != [lindex $xc_m2 0]}]
check_true "XC44 ...and so did d1's: a stale per-Raw index is exactly what this\
 item exists to remove" [expr {[lindex $xc_m1 1] != [lindex $xc_m2 1]}]
check "XC45 every database records the NEW cursor position after the move" \
  [pcall {set l {}
          foreach s {0 1 2 3} { xschem raw switch $s; lappend l [lindex [xc_annot] 1] }
          xschem raw switch 0
          lsort -unique $l}] 1.75e-07

# ===========================================================================
# XC5 — RULING D4-2: ONE database publishes ngspice::ngspice_data
# ===========================================================================
xc_cursor 175e-9
set xc_arr [pcall {lsort [array names ngspice::ngspice_data]}]
check_true "XC51 the Tcl backannotation array carries the CURRENT database's\
 vector" [expr {[lsearch -exact $xc_arr {v(anlg)}] >= 0}]
check_true "XC52 ...and NOT the VCD's names: D5 (what a digital database\
 contributes to schematic backannotation) is still open and is not decided by\
 D4" [expr {[lsearch -exact $xc_arr TOP.m.siga] < 0 &&
            [lsearch -exact $xc_arr TOP.m.sigb] < 0}]
check_true "XC53 ...nor the other analog database's" \
  [expr {[lsearch -exact $xc_arr {v(late)}] < 0}]
check "XC54 ...and the array holds exactly the current database's vectors plus\
 the two bookkeeping entries, i.e. no other database merged its namespace in" \
  [llength $xc_arr] [expr {[xschem raw vars] + 2}]

# ===========================================================================
# XC6 — the registry cursor is a PAIR, and the fan-out moves NEITHER half
# ===========================================================================
xschem raw switch 2
xschem raw switch 0                       ;# prev = 2, current = 0
check "XC61 premise: the registry cursor is current=0, switch_back -> 2" \
  [pcall {xschem raw switch_back; set r [xschem raw rawfile]; xschem raw switch 0; set r}] $v2f
xschem raw switch 2
xschem raw switch 0
xc_cursor 175e-9
check "XC62 one cursor placement leaves the CURRENT database where it was" \
  [pcall {xschem raw rawfile}] $rawf
check "XC63 ...and leaves `raw switch_back` going where it was going: a walker\
 that switches owes BOTH halves back (batch F item 2, finding 1)" \
  [pcall {xschem raw switch_back; xschem raw rawfile}] $v2f
xschem raw switch 0

# ===========================================================================
# XC8 — THE RE-ENTRANCY REFUSAL
# ===========================================================================
# raw_read() calls backannotate_at_cursor_b_pos() from INSIDE extra_rawfile()'s
# read arm (save.c), at a moment when xctx->raw is the freshly read database and
# is NOT YET in extra_raw_arr[] -- extra_idx still names the OUTGOING slot. A
# fan-out that switched from there would overwrite xctx->raw with a registered
# database, and the read arm's `extra_raw_arr[extra_raw_n] = xctx->raw` a few
# lines later would register THAT pointer a second time and leak the one it just
# read: two slots aliasing one Raw, i.e. a double free at the next `raw clear`.
#
# These four are GREEN AT THE PARENT COMMIT by construction -- the parent has no
# fan-out to be re-entered. They guard a defect THIS ITEM could introduce, which
# is what the sabotage (delete the refusal in graph_cursor_dbs) is for.
set reentf [file join $scratch reent.raw]
mkraw $reentf {v(reent)} 0.90 0.95 0.0 2.0e-6
xschem raw switch 0
xschem setprop rect 2 0 fullyzoom
xc_cursor 175e-9                       ;# a live cursor on the cross-DB strip
set xc_n0 [llength [lrange [split [xschem raw info] "\n"] 1 end-1]]
check "XC81 a new database reads while a cursor is live on a cross-DB strip, and becomes current" [pcall {xschem raw read $reentf tran; xschem raw rawfile}] $reentf
check_true "XC82 ...and the database that is current really is the one just read (it answers for v(reent), which no other database has)"   [expr {[xschem raw index {v(reent)}] >= 0}]
check "XC83 ...and the registry grew by exactly one"   [llength [lrange [split [xschem raw info] "\n"] 1 end-1]] [expr {$xc_n0 + 1}]
# THE ALIASING CHECK. If the read arm had registered a pointer it did not read,
# two slots would answer the same path and one Raw would be in the registry
# twice.
set xc_paths {}
for {set s 0} {$s < [expr {$xc_n0 + 1}]} {incr s} {
  xschem raw switch $s
  lappend xc_paths [xschem raw rawfile]
}
xschem raw switch 0
check "XC84 ...and no two registry slots name the same database: a Raw
 registered twice is a double free at the next `raw clear`"   [expr {[llength $xc_paths] == [llength [lsort -unique $xc_paths]]}] 1
check_true "XC85 ...and the fan-out still works afterwards (the refusal is for the mid-read moment only, not a permanent opt-out)"   [expr {[pcall {xschem raw switch 0; xschem setprop rect 2 0 fullyzoom
                 xc_cursor 175e-9; xschem raw switch 1; xc_annot_p}] >= 0}]
xschem raw switch 0

# ===========================================================================
# XC7 — structural
# ===========================================================================
set xcrepo [file dirname [file dirname $here]]
proc xc_read {p} { set f [open $p r]; set s [read $f]; close $f; return $s }
proc xc_is_code {line} {
  set t [string trimleft $line]
  if {[string index $t 0] eq "*"} { return 0 }
  if {[string range $t 0 1] eq "/*" || [string range $t 0 1] eq "//"} { return 0 }
  return 1
}
set xcdraw [xc_read [file join $xcrepo src draw.c]]
set xccb   [xc_read [file join $xcrepo src callback.c]]
# the enumerator does not hand-roll a `%` parse -- issue 0305's whole point
set xc_pct 0; set xc_split 0
foreach l [split $xcdraw "\n"] {
  if {![xc_is_code $l]} continue
  if {[regexp {find_nth\([A-Za-z_][A-Za-z0-9_]*, *"%"} $l]} { incr xc_pct }
  if {[regexp {node_token_split\(} $l] && [string first "static void" $l] != 0} { incr xc_split }
}
check "XC71 draw.c still reads the `%` field in exactly TWO places, both inside\
 node_token_split(): the D4 enumerator is caller number eight, not parser two" \
  $xc_pct 2
check "XC72 ...and there are now EIGHT call sites of it (seven node= walkers +\
 graph_cursor_dbs)" $xc_split 8
# the HOLD arm is one test in one function
set xc_hold 0; set xc_clamp 0; set xc_prevrestore 0
foreach l [split $xccb "\n"] {
  if {![xc_is_code $l]} continue
  if {[regexp {strcmp\(raw->sim_type, *"vcd"\)} $l]} { incr xc_hold }
  if {[regexp {if\(frac [<>] [01]\.0\) frac = [01]\.0;} $l]} { incr xc_clamp }
  if {[regexp {xctx->extra_prev_idx = entry_prev_idx} $l]} { incr xc_prevrestore }
}
check "XC73 the sparse-stream HOLD is ONE sim_type test in callback.c" $xc_hold 1
check "XC74 ...and the no-extrapolation clamp is the matching PAIR of bounds" \
  $xc_clamp 2
check "XC75 ...and the fan-out puts back extra_prev_idx exactly once" \
  $xc_prevrestore 1
# STRUCTURAL, and deliberately so. The `p + 1 < ofs_end` half of RULING D4-4
# removes an OUT-OF-BOUNDS READ, not a wrong number: with the frac clamp above
# in place the garbage word past the end of the my_calloc(allpoints) buffer
# produces a negative dx, the clamp pins frac at 0 and the ANSWER is already
# right. So no assertion inside this process can see that line alone (measured:
# reverting it by itself leaves all 59 checks green), and only ASan/valgrind
# could. The pre-item PAIR -- this test plus the clamp -- is caught: at the
# parent commit XC34/XC37 read 0.37500001 and 0.43500002 instead of 0.30.
set xc_bound 0
foreach l [split $xccb "
"] {
  if {![xc_is_code $l]} continue
  if {[regexp {interpolate_yval\(i, p, cursor2, sweep_idx, \(p \+ 1 < ofs_end\)\)} $l]} {
    incr xc_bound
  }
}
check "XC76 the point_not_last argument is (p + 1 < ofs_end): the old (p < ofs_end) let interpolate_yval read one element past the end of the buffer at the last sample of a dataset" $xc_bound 1

# ===========================================================================
# XCT — RULING D4-6: the SWEEP COLUMN is exempt from the HOLD
# ===========================================================================
# A time axis is not an event-driven signal. Holding it froze a VCD's own `time`
# readout at the last event's timestamp while the SAME Raw's annot_x recorded
# the real cursor position: one database, two answers about where the cursor is.
# Every OTHER column of that database still holds -- XC21/XC24 are the checks
# for that, and they must stay green beside these.
xschem raw switch 0
xschem setprop rect 2 0 fullyzoom
xc_cursor 175e-9
xschem raw switch 1
set xct_sweep [lindex [split [xschem raw list] "\n"] 0]
check "XCT1 premise: the VCD's sweep column is its first vector" \
  [expr {$xct_sweep ne {} ? 1 : 0}] 1
near "XCT2 the VCD's own sweep column reads the CURSOR POSITION, not the last\
 event's timestamp: annot_x says 175 ns and the sweep value must agree" \
  [xschem raw value $xct_sweep {}] 1.75e-07 1e-12
check_true "XCT3 ...and specifically NOT 150 ns, the timestamp of the last\
 event before the cursor, which is what a held sweep column answered" \
  [expr {abs([xschem raw value $xct_sweep {}] - 1.5e-07) > 1e-9}]
check "XCT4 ...and the database's own annot_x agrees with its sweep readout" \
  [expr {abs([lindex [xc_annot] 1] - [xschem raw value $xct_sweep {}]) < 1e-12}] 1
xschem raw switch 0
near "XCT5 the analog database's sweep column reads the cursor too (unchanged\
 behaviour: it never held)" \
  [xschem raw value [lindex [split [xschem raw list] "\n"] 0] {}] 1.75e-07 1e-12
# and past the database's end the sweep column CLAMPS like every other column
# (RULING D4-4): it reports where this database's data stops, not a cursor
# position it has no sample for.
xc_cursor 2.5e-6
xschem raw switch 1
near "XCT6 past the VCD's last sample the sweep column clamps to that last\
 sample's time, not to the cursor: D4-4 applies to the sweep column too" \
  [xschem raw value $xct_sweep {}] [lindex $d1s end-1] 1e-12
xschem raw switch 0

# ===========================================================================
# XCW — RULING D4-7: the X WINDOW IS A RENDERING CONCERN, NOT AN ANNOTATION ONE
# ===========================================================================
# The sample scan in backannotate_cursor_b_in_db() only considered samples
# inside the strip's CURRENT X window. A contributing database whose samples all
# fall outside it fell through with first == -1 and had NOTHING stamped, so it
# kept the annotation of wherever the cursor USED to be -- one cursor, two
# times -- or, if it had never been annotated, the -1 and the my_calloc zeros
# that read as "that signal is 0". Reachable by any ordinary X zoom:
# wviewer::wheel_zoom writes x1/x2 on the graph rect and this is exactly what it
# writes. Every other check in this file keeps the window at 0..3 us, which is
# why none of them can see it.
xschem raw switch 0
foreach {t v} [list x1 0 x2 3e-6] { xschem setprop rect 2 0 $t $v }
xschem setprop rect 2 0 fullyzoom
# 125 ns is load-bearing: d1 reads 0 there (its 100 ns event), and 1 at the
# 2.5 us the leg moves to. A database left holding the OLD annotation therefore
# answers a DIFFERENT number than one that followed -- park the cursor somewhere
# d1 already reads 1 and the stale answer and the right answer coincide, and
# XCW4 is green against code that skips the database entirely.
xc_cursor 125e-9
set xcw_before [pcall {set l {}
                       foreach s {0 1 2 3} { xschem raw switch $s; lappend l [lindex [xc_annot] 1] }
                       xschem raw switch 0; lsort -unique $l}]
check "XCW1 premise: with the wide window every database records the same t" \
  $xcw_before 1.25e-07
near "XCW1b premise: and d1 reads 0 at that t, so the stale answer this leg has\
 to overwrite is DISTINGUISHABLE from the right one" \
  [pcall {xschem raw switch 1; set y [xschem raw value TOP.m.siga {}]
          xschem raw switch 0; set y}] 0.0
# ZOOM past d1 (0..200 ns) and d2 (500..900 ns) entirely, then MOVE the cursor.
foreach {t v} [list x1 1e-6 x2 3e-6] { xschem setprop rect 2 0 $t $v }
xschem setprop rect 2 0 fullyzoom
xc_cursor 2.5e-6
check "XCW2 with the X window zoomed PAST two of the contributing databases,\
 every database still records the SAME new t: the window does not gate the\
 annotation" \
  [pcall {set l {}
          foreach s {0 1 2 3} { xschem raw switch $s; lappend l [lindex [xc_annot] 1] }
          xschem raw switch 0; lsort -unique $l}] 2.5e-06
xschem raw switch 1
check "XCW3 ...and the off-screen VCD recorded the NEW cursor position, not the\
 one it was frozen at" [lindex [xc_annot] 1] 2.5e-06
near "XCW4 ...and it HOLDS its LAST value there (1, D4-4) rather than the 0 it\
 was left holding from the previous placement" \
  [xschem raw value TOP.m.siga {}] [lindex $d1s end] 1e-9
xschem raw switch 3
near "XCW5 ...and late.raw, which the window DOES cover, is unaffected: past its\
 last sample it reads that last sample" \
  [xschem raw value {v(late)} {}] 0.65 1e-6
# the other boundary, with the window narrowed the other way: a window entirely
# BEFORE late.raw's first sample, and a cursor before it too.
foreach {t v} [list x1 0 x2 0.5e-6] { xschem setprop rect 2 0 $t $v }
xschem setprop rect 2 0 fullyzoom
xc_cursor 0.25e-6
xschem raw switch 3
near "XCW6 a window entirely before late.raw's data: the cursor still reads its\
 FIRST sample verbatim (D4-4), not the stale last one it was left holding" \
  [xschem raw value {v(late)} {}] $late_first_v 1e-9
check "XCW7 ...and late.raw records the cursor's t, so XC17's 'one cursor, one\
 time' survives a zoom" [lindex [xc_annot] 1] 2.5e-07
xschem raw switch 0
# put the window back: every leg after this one assumes the wide one
foreach {t v} [list x1 0 x2 3e-6] { xschem setprop rect 2 0 $t $v }
xschem setprop rect 2 0 fullyzoom

# ===========================================================================
# XCS — RULING D4-8: cursor B is a VIEWER object, so its scope is every strip
# ===========================================================================
# The canonical mixed-signal layout is Cadence's: analog on one strip, the
# digital bus on its own strip underneath. Fanning out over only the rect that
# was passed in left the digital strip's database never annotated at all, and
# `xschem set cursor2_x` (scheduler.c) hard-codes rect[GRIDLAYER][0], so both
# the headless path and the menu path drove the cursor from strip 0 alone.
# spare.vcd is the same database XC19 watched being LEFT ALONE while it was on
# no strip; put it on a second strip and it must follow.
set QS "\\\"sp;TOP.m.sigspare%$sparef vcd\\\""
xschem set rectcolor 2
xschem rect 0 500 800 900 -1 {flags=graph} 0
xschem setprop rect 2 1 node "$QS"
foreach {t v} [list x1 0 x2 3e-6 y1 -0.3 y2 1.3] { xschem setprop rect 2 1 $t $v }
xschem setprop rect 2 1 fullyzoom
xschem setprop rect 2 0 fullyzoom      ;# the DRIVING strip owns the Graph_ctx
check_true "XCS0 premise: there are now two graph strips, spare.vcd is plotted\
 only on the second one, and strip 0 does not mention it" \
  [expr {[string first sigspare [xschem getprop rect 2 1 node]] >= 0 &&
         [string first sigspare [xschem getprop rect 2 0 node]] < 0}]
xc_cursor 25e-9                        ;# spare's 0 ns event set 1; 40 ns sets 0
xschem raw switch 4
check_true "XCS1 the SECOND strip's database resolves even though the cursor was\
 driven from strip 0: cursor B is one global, not a per-strip object" \
  [expr {[xc_annot_p] >= 0}]
check "XCS2 ...at the same t as the driving strip's own database" \
  [pcall {set a [lindex [xc_annot] 1]; xschem raw switch 0
          set b [lindex [xc_annot] 1]; xschem raw switch 4
          expr {$a == $b}}] 1
near "XCS3 ...and it reads the value its own last event set (1, not the 0 of a\
 cursor_b_val nobody ever wrote)" [xschem raw value TOP.m.sigspare {}] 1.0
xschem raw switch 0
xc_cursor 45e-9                        ;# past spare's 40 ns event
xschem raw switch 4
# 0.0 is ALSO what an unannotated my_calloc'd cursor_b_val reads, so the value
# alone would be green against code that never touches this database: the
# annotation index carries the positive half (same shape as XC41).
check_true "XCS4 the cursor MOVES and the second strip's database follows it --\
 0 there, and genuinely annotated rather than merely zero-initialised" \
  [expr {abs([xschem raw value TOP.m.sigspare {}]) < 1e-9 && [xc_annot_p] >= 0}]
check "XCS5 ...and records the new t" [lindex [xc_annot] 1] 4.5e-08
xschem raw switch 0
# a PRIVATE-cursor strip is out of scope in BOTH directions: it has a cursor2_x
# of its own, so it neither joins another strip's fan-out nor drags other strips
# into its own. Same reading of flags bit 4 that picks `cursor2` in callback.c.
xschem setprop rect 2 1 flags {graph,private_cursor}
xschem setprop rect 2 0 fullyzoom
xschem raw switch 4
set xcs_priv_before [xc_annot]
xschem raw switch 0
xc_cursor 125e-9
xschem raw switch 4
check "XCS6 a strip with private_cursor is NOT dragged along by another strip's\
 cursor: it has one of its own" [xc_annot] $xcs_priv_before
xschem raw switch 0
xschem setprop rect 2 1 flags {graph}

# ===========================================================================
# XCO — RULING D4-1, third clause: the strip's OWN database
# ===========================================================================
# `rawfile=` on the graph rect plus a PLAIN (no-`%`) node entry plotting from it.
# This is the one shape that distinguishes the own_db_plots clause from
# slots[0]: on every other strip in this file graph_idx == the entry database,
# so deleting that clause changed nothing anywhere. reent.raw is the database
# for it -- it is on no other strip, and it is not the current one.
check "XCO0 premise: v(reent) is absent from the CURRENT database, so a readout\
 for it can only have come from reent.raw itself" \
  [pcall {xschem raw switch 0; xschem raw index {v(reent)}}] -1
xschem rect 0 1000 800 1400 -1 {flags=graph} 0
xschem setprop rect 2 2 rawfile $reentf
xschem setprop rect 2 2 sim_type tran
xschem setprop rect 2 2 node {v(reent)}
foreach {t v} [list x1 0 x2 3e-6 y1 0.8 y2 1.0] { xschem setprop rect 2 2 $t $v }
xschem setprop rect 2 2 fullyzoom
xschem setprop rect 2 0 fullyzoom
xschem raw switch 0
# NOT 175 ns. reent.raw was CURRENT for one instant during the XC8 leg -- it is
# the database `xschem raw read` made current there, with a live cursor at
# 175 ns -- so it carries a real annotation at that exact t from before this
# strip existed. A leg that used 175 ns would be green against code that never
# reaches this database at all. Every t below is one reent.raw has never seen.
check "XCO0b premise: reent.raw's leftover annotation from the XC8 leg is at\
 175 ns, so this leg must avoid that t to mean anything" \
  [pcall {xschem raw switch 5; set a [lindex [xc_annot] 1]; xschem raw switch 0; set a}] 1.75e-07
set xco_stale_p [pcall {xschem raw switch 5; set a [xc_annot_p]; xschem raw switch 0; set a}]
xc_cursor 1.5e-6
xschem raw switch 5
check_true "XCO1 a strip's OWN database (its rawfile=, reached by a plain node=\
 entry) is annotated by the cursor -- at a DIFFERENT index than the leftover\
 one, so 'annot_p >= 0' cannot be satisfied by that leftover" \
  [expr {[xc_annot_p] >= 0 && [xc_annot_p] != $xco_stale_p}]
check "XCO2 ...at the cursor's t" [lindex [xc_annot] 1] 1.5e-06
near "XCO3 ...and it reads its own interpolated value there, not a my_calloc\
 zero and not the value it was left holding (v(reent) runs 0.90..0.95 over\
 0..2 us, so 1.5 us is 0.9375 and the leftover 175 ns one is 0.9044)" \
  [xschem raw value {v(reent)} {}] 0.9375 1e-6
xschem raw switch 0
xc_cursor 0.5e-6
xschem raw switch 5
near "XCO4 ...and it follows the cursor when it moves" \
  [xschem raw value {v(reent)} {}] 0.9125 1e-6
check "XCO5 ...recording the new t as well" [lindex [xc_annot] 1] 5e-07
xschem raw switch 0

# ===========================================================================
# XC9 — coverage self-check
# ===========================================================================
check "XC91 every check in this file ran" [expr {$fail + $npass}] 92

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail} { puts "RESULT: $fail FAILED ($npass passed)" } \
else { puts "RESULT: ALL PASS ($npass checks)" }
exit 0
