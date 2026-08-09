# §D row D3 / §H row H3 of doc/claude/specs/mixed_signal_signal_browser.md —
# THE TIME-BASE REGRESSION.
#
# ===========================================================================
# WHAT DEFECT THIS EXISTS FOR
# ===========================================================================
# ngspice raw time is SECONDS, stored as a double. VCD time is an INTEGER TICK
# COUNT multiplied by whatever `$timescale` declares. Get that one conversion
# wrong by a factor of 1e3 — read ps as ns, or ns as us — and NOTHING LOOKS
# BROKEN. The trace still renders, still has the right shape, still has the
# right number of edges, still spans a plausible-looking interval. It is simply
# on the wrong axis, and plotted beside an analog raw it disagrees by three
# orders of magnitude while looking entirely reasonable on its own. D3's own
# words: "Off-by-1e3 here looks like a plausible waveform."
#
# So this file does not test "does the VCD reader work" (test_vcd_read.tcl, 187
# checks, does that). It tests exactly one property: AN EDGE AT A KNOWN PHYSICAL
# TIME LANDS AT THE SAME PHYSICAL TIME IN BOTH DATABASES — and it proves, rather
# than asserting, that the gate it uses to decide that would reject a 1e3 error
# in either direction.
#
# ===========================================================================
# THE TOLERANCE — 100 ps — AND WHY IT IS NOT ZERO
# ===========================================================================
#   set TOL 1e-10        ;# 100 ps
#
# A ZERO TOLERANCE WOULD BE WRONG. The two databases do not record the same
# event. The VCD records the instant the Verilog model changed a signal. The raw
# records an ANALOG waveform crossing a voltage threshold, after the dac_bridge
# has ramped through its finite `t_rise`, sampled on ngspice's own timestep grid.
# Those two things are separated by real physics and can never be bit-equal.
#
# The separation is measured, not guessed. §A6 of the spec, re-measured here
# against the artifacts still on this box (group REF below):
#
#     counter LSB first rising edge   50.0120 ns   (VCD, TOP.counter.count[0])
#     same edge in the analog raw     50.0219 ns   (v(count_out0) crossing 0.9 V)
#     skew                             9.883 ps    = dac_bridge t_rise=1e-11
#                                                    plus the 0.9 V crossing
#
# So the gate must PASS ~9.9 ps and REJECT ~1e3. Both margins, stated:
#
#   * against the physics: 100 ps / 9.883 ps = 10.1x headroom. The bridge
#     t_rise could be TEN TIMES the reference 10 ps and this gate would still
#     not fire on it. It is not tuned to the fixture.
#
#   * against a 1e3 error: the SMALLER of the two displacements is the divide-
#     by-1000 direction, |t/1000 - t| = 0.999*t. The earliest edge THAT REACHES
#     THE `agree` GATE is at 50 ns. (Not the earliest edge in the file: the LD
#     group places edges at 7 fs and 7 ps, but LD has no raw to compare against
#     and never calls `agree`, so those do not bound anything here.) The
#     smallest 1e3 error this file actually feeds to the gate is NC2/NC9's
#     |50.0099 ns - 50 ps| = 49.96 ns = 499.6 x TOL -- measured, and printed by
#     NC2/NC9-margin-ge-100x on every run. The multiply direction, 999*t, is
#     49.95 us = 499,500 x TOL. A 1e3 error is at MINIMUM ~500x outside the gate.
#
# ===========================================================================
# THE GREEN WINDOW FOR TOL — MEASURED, NOT DERIVED
# ===========================================================================
# The two margins above bound the gate from the physics side and the defect
# side, and read on their own they suggest a window of thousands. THEY ARE NOT
# THE BINDING CONSTRAINT. This file's own guard rail, NC*-margin-ge-100x
# (`>= 100.0 * $TOL`), caps TOL a hundred times lower than the defect does.
# Scanning TOL against the whole file gives the real window:
#
#     TOL  =      9.8e-12   16 FAILED  TB*-agree, NC*-good-accepted, REF8-agree
#     TOL  =      9.9e-12   ALL PASS   <- FLOOR (last value that still passes
#                                         going down; exactly $SKEW)
#     TOL  =        1e-10   ALL PASS   <- SHIPPED
#     TOL  =  4.99599e-10   ALL PASS   <- CEILING (last green)
#     TOL  =    4.996e-10    2 FAILED  NC2-margin-ge-100x, NC9-margin-ge-100x
#     TOL  =        5e-09    2 FAILED  the same two -- 5 ns is RED
#     TOL  =   4.99599e-8    4 FAILED  adds NC2/NC9-bad-rejected: only HERE does
#                                      the gate genuinely admit a 1e3 error
#
#   * the FLOOR, 9.9e-12, is imposed by TB*-agree and NC*-good-accepted — the
#     synthetic $SKEW, exactly 9.9 ps, applied at every scale. REF8-agree sits
#     just under it at the measured 9.883 ps (it goes green again at 9.884e-12).
#     Below the floor the physics is reported as a bug.
#   * the CEILING, 4.99599e-10, is imposed by NC*-margin-ge-100x against the
#     smallest 1e3 displacement this file builds: NC2 (good `1ns` / bad `1ps` at
#     tick 50) and NC9 (good `10 ns` / bad `10 ps` at tick 5) both displace by
#     4.99599e-8 s, so 100x that is 4.99599e-10. That guard rail is a deliberate
#     100x inside the point where the gate would really start accepting a 1e3
#     error (4.99599e-8, NC*-bad-rejected) — it exists so a tolerance change
#     cannot quietly erode the margin, and it is what a TOL change hits first.
#
# So the green window is [9.9e-12, 4.99599e-10]: a factor of ~50, NOT ~5000.
# The shipped 1e-10 sits 10.1x above the floor and 5.0x below the ceiling —
# near the geometric centre (sqrt(50) = 7.1x each way), which is why it is not
# tuned to the fixture. But "anything from ~50 ps to ~5 ns" is FALSE: 50 ps is
# green, 5 ns is RED. Any change to TOL must be re-scanned, not reasoned about.
#
# A tolerance loose enough to admit a 1e3 error would be worse than no test at
# all, which is why NC (below) does not merely assert that — it builds VCDs that
# ARE 1e3 wrong and runs them through the SAME `agree` proc every real check
# uses, asserting the rejection.
#
# ===========================================================================
# GROUPS
# ===========================================================================
#   TB   one edge, one physical time, both DBs in the registry at once, over
#        SIX $timescale units including the two-token `10 ns` form. A units bug
#        that shows up for only one unit is the likely shape, so one unit is
#        not coverage.
#   LD   the unit ladder fs->ps->ns->us->ms->s. EVERY STEP OF THAT LADDER IS
#        EXACTLY THE 1e3 FACTOR D3 IS ABOUT, so a wrong exponent anywhere breaks
#        a ratio here even without a raw to compare against.
#   NC   negative controls. Nine deliberately mis-scaled VCDs, both directions,
#        each fed to the same gate. THE PROOF, not an assertion.
#   SE   seconds, not ticks (the "forgot to convert at all" failure), and the
#        multiplier forms.
#   RW   the raw side is not rescaled either — the symmetric fix-it-the-wrong-
#        way error.
#   REF  the real §A6 pair on this box. Runs only if both artifacts are present
#        and NEVER prints a skip banner full_audit would score as a file-wide
#        SKIP.
#
# ===========================================================================
# DECISIONS TAKEN HERE (the item left these open; this is the record)
# ===========================================================================
#  1. TOLERANCE = 100 ps. Derived above, with both margins, and with the green
#     window MEASURED rather than inferred: [9.9e-12, 4.99599e-10], ~50x wide,
#     with 1e-10 10.1x above the floor and 5.0x below the ceiling. Not tuned to
#     the fixture — but the window is 50x, not 5000x, and its ceiling comes from
#     NC*-margin-ge-100x, not from the physics. 50 ps is green; 5 ns is RED.
#  2. THE MEASUREMENT RULE is nearest-sample-AFTER, no interpolation, applied
#     identically to both DBs — chosen because it is the rule that reproduces
#     BOTH §A6 numbers exactly (see the note at first_cross). §A6 did not say
#     which rule it used; measuring the real artifacts showed 50.0219 ns is the
#     first sample at/above 0.9 V, while an interpolated crossing of the same
#     edge is 50.01750 ns. Both are inside the gate, so the test is not
#     sensitive to the choice — but it is now written down.
#  3. THRESHOLD 0.9 on both rails. On the VCD's 0..1 rail the "obvious" 50%
#     threshold would be 0.5, which is EXACTLY vcd_read.c's X sentinel — an X
#     would read as a rising edge. 0.9 clears both sentinels (X=0.5, Z=0.3).
#  4. UNIT COVERAGE. The item required at minimum 1ps/1ns/1us and the two-token
#     `10 ns`. TB carries six units (fs,ps,ns,`10 ns`,us,ms) and LD walks the
#     whole ladder up to 1s, because a units bug that only shows for one unit is
#     the likely shape and one unit is not coverage.
#  5. REF IS HARD-PINNED to the §A6 figures at the 0.1 ps precision §A6 quotes,
#     the same contract test_vcd_read.tcl group A already holds these artifacts
#     to. Re-running the mixed-signal simulation invalidates both files' pins
#     together; that is deliberate and is stated at the group.
#
# ===========================================================================
# SABOTAGE LEDGER — 20 injected, 20 caught, and EVERY one of the 124 checks is
# caught by at least one of them (verified by unioning the FAIL names).
# ===========================================================================
#   S1/S2  the VCD $timescale one unit coarser / finer in mkvcd_edge — THE D3
#          DEFECT ITSELF, both directions -> TB*-vcd-abs, TB*-agree,
#          TB*-skew-is-physical, LD*-abs, LD*-rung, NC*-good-accepted, SE2..SE9
#   S3     raw times x1e3               -> TB*-raw-abs, TB*-agree, RW4, RW5
#   S4     raw times +1 ns (a SMALL, plausible error, 10x TOL) -> TB*-agree,
#          TB*-raw-abs, NC*-good-accepted, RW3, RW4, RW5
#   S5/S18 TOL loosened to 1e-1 / 1e6   -> NC*-bad-rejected, NC*-margin-ge-100x,
#          REF11, REF12   (proves the controls are load-bearing)
#   S6     TOL zeroed                   -> TB*-agree, NC*-good-accepted, REF8
#          (proves the "zero would be wrong" claim above is not rhetoric)
#   S7     SKEW x20 (1.98e-10, just over TOL) -> TB*-agree, NC*-good-accepted
#   S8     oracle UNITSEC(1us) 1e-6->1e-5     -> LD4-abs, NC*-good-accepted
#   S9     first_cross/first_cross_scan return the HOLD sample (p-1)
#                                       -> TB*-vcd-abs/raw-abs, REF6, REF7, REF9
#   S10    mkvcd_edge ignores its unit (always 1ps) -> NC*-bad-is-1e3, LD*-rung
#   S11/12 mkvcd_edge / mkraw_edge write an EMPTY file -> *-load, *-two-dbs,
#          LD*-read, SE1, RW1, NC*-bad-reads-fine
#   S13    REF7 expected value 50.0219 -> 50.0119 ns  -> REF7
#   S14    raw Plotname -> "DC transfer characteristic" -> RW1, RW2, TB*-load
#   S15    TB4 tick 5 -> 50 (i.e. `10 ns` read as 1 ns) -> TB4-vcd-abs, -agree
#   S16    mkvcd_edge forced to `1s`   -> SE3, SE4 (the never-converted case)
#   S17    REF raw read with sim_type vcd -> REF1, REF3, REF5
#   S19    REF vcd read with sim_type tran (the C6 dispatch-key misroute)
#                                       -> REF2, REF4, REF6, REF8..REF12
#   S20    the NC bad-VCD measurement taken WITHOUT switching to the VCD's
#          registry slot — i.e. counting the analog raw, which is what this
#          check used to do -> all nine NC*-bad-reads-fine, and nothing else.
#          (Dropping only the span term while KEEPING the switch leaves the
#          file ALL PASS: `$np > 0` on its own is satisfied by either database
#          and proves nothing. The span term is the load-bearing one.)
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_vcd_time_base.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc nearcheck {name got want {tol 1e-15}} {
  if {![string is double -strict $got]} { check $name 0 "(got '$got' want '$want')"; return }
  check $name [expr {abs($got - $want) <= $tol}] "(got '$got' want '$want' tol $tol)"
}
# relative compare, for the ladder where the magnitudes span 1e-15 .. 1e0
proc relcheck {name got want {rel 1e-9}} {
  if {![string is double -strict $got]} { check $name 0 "(got '$got' want '$want')"; return }
  check $name [expr {abs($got - $want) <= abs($want) * $rel}] "(got '$got' want '$want' rel $rel)"
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
# Every measurement proc below can return a WORD (NODB/NOSIG/NOCROSS) instead of
# a time. Feeding one of those to `expr {$a > $b}` throws and would abort the
# whole file, so arithmetic checks go through here: a non-numeric measurement is
# a FAILED check with the offending word printed, never a dead script.
proc bothnum {a b} {
  expr {[string is double -strict $a] && [string is double -strict $b]}
}
# |a-b| for a check's DETAIL string, without throwing when a measurement came
# back as a word. A detail string that throws kills the file just as dead as a
# check that throws -- that is how the first sabotage round lost 100 checks.
proc diffstr {a b} {
  if {![bothnum $a $b]} { return "n/a" }
  return [expr {abs($a - $b)}]
}
# skew = t_raw - t_vcd must sit inside (lo,hi)
proc skewcheck {name tv tr lo hi} {
  if {![bothnum $tv $tr]} { check $name 0 "(vcd='$tv' raw='$tr')"; return }
  set d [expr {$tr - $tv}]
  check $name [expr {$d > $lo && $d < $hi}] "(skew=$d want ($lo,$hi))"
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch vcdtime]

proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# ---------------------------------------------------------------------------
# THE GATE. One proc. Every TB check and every negative control calls THIS, so a
# negative control proves something about the gate the real checks actually use.
# Changing the tolerance changes both halves at once, on purpose: a tolerance
# that is loosened until the real checks pass immediately breaks the controls.
# ---------------------------------------------------------------------------
set TOL 1e-10
proc agree {t_vcd t_raw} {
  if {![string is double -strict $t_vcd] || ![string is double -strict $t_raw]} { return 0 }
  return [expr {abs($t_vcd - $t_raw) <= $::TOL}]
}

# ---------------------------------------------------------------------------
# THE ORACLE. What each $timescale token MUST mean, in seconds, written out
# independently of the C reader. This table is the whole point of the file: it
# is the thing a 1e3 bug disagrees with.
# ---------------------------------------------------------------------------
array set UNITSEC {
  1fs 1e-15   1ps 1e-12   1ns 1e-9    1us 1e-6    1ms 1e-3   1s 1.0
  {10 ps} 1e-11   {10 ns} 1e-8   {10 us} 1e-5   {100ps} 1e-10   {100 ns} 1e-7
}

# ---------------------------------------------------------------------------
# Fixtures. Both generators encode ONE rising edge; the caller decides what
# physical time that edge is at, on each side, independently.
# ---------------------------------------------------------------------------

# A VCD whose only signal rises at tick $tick. Scope nesting mirrors the real
# artifact (TOP / TOP.counter) so the name lookup is the same shape.
proc mkvcd_edge {path timescale tick tick_end} {
  set b ""
  if {$timescale ne ""} { append b "\$timescale $timescale \$end\n" }
  append b "\$scope module TOP \$end\n"
  append b " \$scope module counter \$end\n"
  append b "  \$var wire 1 ! lsb \$end\n"
  append b " \$upscope \$end\n"
  append b "\$upscope \$end\n"
  append b "\$enddefinitions \$end\n"
  append b "#0\n\$dumpvars\n0!\n\$end\n"
  append b "#$tick\n1!\n"
  append b "#$tick_end\n"
  wr $path $b
}
set VSIG TOP.counter.lsb

# An ASCII ngspice raw carrying the SAME edge, displaced by the physical skew.
# The sample pattern reproduces the reference mechanism rather than inventing
# one: the digital event happens at $t_dig with the analog node still low, the
# dac_bridge ramps over t_rise, and the FIRST SPICE SAMPLE at or above the
# 0.9 V threshold is the one at the end of that ramp — which is why the raw
# reads LATE by about one bridge rise time and not by zero.
proc mkraw_edge {path t_dig skew t_end {vdd 1.8}} {
  set pts {}
  lappend pts [list 0.0 0.0]
  lappend pts [list [expr {$t_dig - 3*$skew}] 0.0]
  lappend pts [list [expr {$t_dig - 2*$skew}] 0.0]
  lappend pts [list [expr {$t_dig - 1*$skew}] 0.0]
  lappend pts [list $t_dig                    0.0]
  lappend pts [list [expr {$t_dig + 1*$skew}] $vdd]
  lappend pts [list [expr {$t_dig + 2*$skew}] $vdd]
  lappend pts [list $t_end                    $vdd]
  set b "Title: xschem headless time-base fixture\n"
  append b "Date: Thu Jan  1 00:00:00 2026\n"
  append b "Plotname: Transient Analysis\n"
  append b "Flags: real\n"
  append b "No. Variables: 2\n"
  append b "No. Points: [llength $pts]\n"
  append b "Variables:\n\t0\ttime\ttime\n\t1\tv(lsb_a)\tvoltage\n"
  append b "Values:\n"
  set i 0
  foreach p $pts {
    append b "$i\t[format %.17g [lindex $p 0]]\n\t[format %.17g [lindex $p 1]]\n\n"
    incr i
  }
  wr $path $b
}
set RSIG v(lsb_a)

# ---------------------------------------------------------------------------
# Measurement. ONE rule, applied to BOTH databases, and it is the rule that
# produced the §A6 figures: the first SAMPLE at or above the logic-high
# threshold whose predecessor is below it. Nearest-sample-AFTER, no
# interpolation. (Interpolating the reference raw instead gives 50.01750 ns and
# a 5.5 ps skew — also well inside TOL, so the choice of rule is not what this
# test is sensitive to. It is stated so the two §A6 numbers are reproducible.)
#
# Threshold 0.9 works on both rails and is not a coincidence twice over: 0.9 V
# is half of the reference 1.8 V supply, and 0.9 on the VCD's 0..1 digital rail
# is above BOTH four-state sentinels (X=0.5, Z=0.3, src/vcd_read.c DECISION 3),
# so an X or a Z is never mistaken for a rising edge.
# ---------------------------------------------------------------------------
proc first_cross {name thresh} {
  if {[catch {xschem raw values time} t]} { return NODB }
  if {[catch {xschem raw values $name} v]} { return NODB }
  if {[llength $v] == 0} { return NOSIG }
  if {[llength $t] != [llength $v]} { return LENMISMATCH }
  for {set p 1} {$p < [llength $v]} {incr p} {
    if {[lindex $v [expr {$p-1}]] < $thresh && [lindex $v $p] >= $thresh} {
      return [lindex $t $p]
    }
  }
  return NOCROSS
}

# same rule, but a bounded forward scan for a DB too big to slurp whole
# (the reference raw is 200,386 points)
proc first_cross_scan {name thresh maxp} {
  if {[catch {xschem raw points} n]} { return NODB }
  if {$maxp < $n} { set n $maxp }
  set prev [xschem raw value $name 0]
  if {$prev eq ""} { return NOSIG }
  for {set p 1} {$p < $n} {incr p} {
    set v [xschem raw value $name $p]
    if {$prev < $thresh && $v >= $thresh} { return [xschem raw value time $p] }
    set prev $v
  }
  return NOCROSS
}

# Load an analog raw and a VCD into the registry TOGETHER — the §E3 shape, and
# the only shape in which D3 can actually bite: two DBs, one time axis.
proc load_pair {rawf vcdf} {
  xschem raw clear
  set a [pcall xschem raw read $rawf tran]
  set b [pcall xschem raw read $vcdf vcd]
  return [list $a $b]
}
# Measure the VCD edge (registry slot 1) and the raw edge (slot 0).
# pcall/catch throughout, deliberately: when a fixture fails to load the
# registry has fewer slots than expected and `raw switch` THROWS, which would
# abort the whole script and lose every check after this point. A broken fixture
# must read as named checks failing, not as the file dying (the same reasoning
# as test_ase_cosim.tcl's AT14).
proc pair_times {} {
  catch {xschem raw switch 1}
  set tv [first_cross $::VSIG 0.9]
  catch {xschem raw switch 0}
  set tr [first_cross $::RSIG 0.9]
  return [list $tv $tr]
}

# ===========================================================================
# TB — the item itself: the SAME edge at the SAME physical time, six units
# ===========================================================================
# t_dig is chosen per unit so it is an exact whole number of ticks (a VCD cannot
# express anything else). The 1ps row is the reference case verbatim: tick 50012
# at 1 ps is 50.012 ns, the §A6 VCD figure.
#
# SKEW is the §A6 physical skew, 9.9 ps, applied identically at every scale. It
# is the number the tolerance has to tolerate.
set SKEW 9.9e-12

# tag   $timescale   tick        t_dig (s)
set tb_rows {
  TB1-fs      1fs      50012000    5.0012e-8
  TB2-ps      1ps      50012       5.0012e-8
  TB3-ns      1ns      50          5.0e-8
  TB4-ns10    {10 ns}  5           5.0e-8
  TB5-us      1us      50          5.0e-5
  TB6-ms      1ms      50          5.0e-2
}
foreach {tag ts tick tdig} $tb_rows {
  set vf [file join $tmp tb_[string map {- _} $tag].vcd]
  set rf [file join $tmp tb_[string map {- _} $tag].raw]
  mkvcd_edge $vf $ts $tick [expr {$tick * 2}]
  mkraw_edge $rf $tdig $SKEW [expr {$tdig * 2}]
  eqcheck $tag-load [load_pair $rf $vf] {1 1}
  eqcheck $tag-two-dbs [llength [lrange [split [pcall xschem raw info] "\n"] 1 end-1]] 2
  lassign [pair_times] tv tr
  # 1. the VCD tick count really converted to the physical time it names
  relcheck $tag-vcd-abs $tv $tdig 1e-12
  # 2. the raw carries the same edge one bridge rise time later
  relcheck $tag-raw-abs $tr [expr {$tdig + $SKEW}] 1e-12
  # 3. THE ITEM: the two DBs agree, through the one shared gate
  check $tag-agree [agree $tv $tr] "(vcd=$tv raw=$tr diff=[diffstr $tv $tr] tol=$TOL)"
  # 4. and they agree because they are close, not because both are garbage
  skewcheck $tag-skew-is-physical $tv $tr 0.0 [expr {2*$SKEW}]
}
xschem raw clear

# ===========================================================================
# LD — the unit ladder. EVERY RUNG IS EXACTLY 1e3.
# ===========================================================================
# No raw is involved here: this pins the conversion against the independent
# oracle table above, and then pins the RATIO between adjacent units at exactly
# 1000. A wrong exponent for any single unit breaks two rungs; a wrong exponent
# for all of them (the "everything is 1e3 out" case) breaks LD*-abs.
set ld_units {1fs 1ps 1ns 1us 1ms 1s}
set ld_tick 7
set prev {}
set i 0
foreach u $ld_units {
  incr i
  set vf [file join $tmp ld_$i.vcd]
  mkvcd_edge $vf $u $ld_tick 20
  xschem raw clear
  eqcheck LD$i-$u-read [pcall xschem raw vcd_read $vf] 1
  set t [first_cross $VSIG 0.9]
  relcheck LD$i-$u-abs $t [expr {$ld_tick * $UNITSEC($u)}] 1e-12
  if {$i > 1} {
    if {[bothnum $t $prev] && $prev != 0.0} {
      relcheck LD$i-$u-rung [expr {$t / $prev}] 1000.0 1e-9
    } else {
      check LD$i-$u-rung 0 "(this='$t' prev='$prev')"
    }
  }
  set prev $t
}
xschem raw clear

# ===========================================================================
# NC — NEGATIVE CONTROLS. The 1e3 proof, in both directions.
# ===========================================================================
# Each row builds TWO VCDs from the SAME tick stream: one with the correct
# $timescale and one exactly 1e3 off. Both are perfectly valid VCD files — that
# is the entire point of D3, the wrong one is not malformed, it is plausible.
# Both go through the same `agree` gate against the same raw.
#
#   good must be ACCEPTED   (else the tolerance is too tight and the physics
#                            would be reported as a bug)
#   bad  must be REJECTED   (else the tolerance is too loose and a 1e3 error
#                            ships as a plausible waveform)
#
# tag  good-unit  bad-unit  tick  factor
set nc_rows {
  NC1  1ps      1ns      50012  1000
  NC2  1ns      1ps      50     0.001
  NC3  1ns      1us      50     1000
  NC4  1us      1ns      50     0.001
  NC5  1fs      1ps      50012000 1000
  NC6  1ms      1s       50     1000
  NC7  1ms      1us      50     0.001
  NC8  {10 ns}  {10 us}  5      1000
  NC9  {10 ns}  {10 ps}  5      0.001
}
foreach {tag good bad tick factor} $nc_rows {
  set tdig [expr {$tick * $UNITSEC($good)}]
  set rf [file join $tmp nc_${tag}.raw]
  set gf [file join $tmp nc_${tag}_good.vcd]
  set bf [file join $tmp nc_${tag}_bad.vcd]
  mkraw_edge $rf $tdig $SKEW [expr {$tdig * 2}]
  mkvcd_edge $gf $good $tick [expr {$tick * 2}]
  mkvcd_edge $bf $bad  $tick [expr {$tick * 2}]

  load_pair $rf $gf
  lassign [pair_times] tvg tr
  load_pair $rf $bf
  lassign [pair_times] tvb trb

  # the mis-scaled file is NOT broken — it reads fine and yields a full trace.
  # That is exactly why this defect class survives eyeballing.
  #
  # MEASURE THE VCD, NOT THE RAW. pair_times returns with the registry parked on
  # slot 0 (the analog raw, see its `catch {xschem raw switch 0}`), so a bare
  # `xschem raw points` here counts the RAW's samples — it printed the fixture's
  # constant 8 for all nine rows, a true statement about the wrong database and
  # inert for the property this check is named after. Switch to the VCD's own
  # slot, measure, switch back (the caught switch, for the same reason
  # pair_times catches its own: a fixture that failed to load leaves the
  # registry short and `raw switch` throws).
  #
  # `$np > 0` alone would STILL be inert — the raw's 8 is also > 0 — so the
  # load-bearing term is the span: the bad VCD must reach its own declared last
  # timestamp, tick_end * UNITSEC(bad). That number is on the VCD's (wrong)
  # axis and differs from the raw's end time by the 1e3 factor on every row, so
  # it can only be satisfied by the database this check names.
  catch {xschem raw switch 1}
  set np [pcall xschem raw points]
  set vtimes [pcall xschem raw values time]
  catch {xschem raw switch 0}
  set tend [lindex $vtimes end]
  set wend [expr {$tick * 2 * $UNITSEC($bad)}]
  check $tag-bad-reads-fine \
    [expr {[string is double -strict $tvb] && [string is integer -strict $np] && $np > 0
           && [string is double -strict $tend]
           && abs($tend - $wend) <= abs($wend) * 1e-9}] \
    "(t=$tvb vcd-points=$np vcd-end=$tend want $wend)"
  # it is off by precisely 1e3
  if {[bothnum $tvb $tvg] && $tvg != 0.0} {
    relcheck $tag-bad-is-1e3 [expr {$tvb / $tvg}] [expr {double($factor)}] 1e-9
  } else {
    check $tag-bad-is-1e3 0 "(bad='$tvb' good='$tvg')"
  }
  # the gate accepts the truth ...
  check $tag-good-accepted [agree $tvg $tr] "(vcd=$tvg raw=$tr)"
  # ... and rejects the 1e3 error. PROOF, not assertion: same proc, same raw.
  check $tag-bad-rejected [expr {![agree $tvb $trb]}] \
    "(vcd=$tvb raw=$trb diff=[diffstr $tvb $trb] tol=$TOL)"
  # and it rejects it by a wide margin, not marginally: report the ratio of the
  # error to the gate so a future tolerance change cannot quietly erode it
  if {[bothnum $tvb $trb]} {
    check $tag-margin-ge-100x [expr {abs($tvb - $trb) >= 100.0 * $TOL}] \
      "(error/tol = [format %.1f [expr {abs($tvb-$trb)/$TOL}]]x)"
  } else {
    check $tag-margin-ge-100x 0 "(vcd='$tvb' raw='$trb')"
  }
}
xschem raw clear

# ===========================================================================
# SE — seconds, not ticks; and the multiplier forms
# ===========================================================================
# A reader that never converted at all leaves the raw tick count in the time
# column. 50012 reads as a perfectly plausible number and would plot.
set vf [file join $tmp se_ticks.vcd]
mkvcd_edge $vf 1ps 50012 100024
xschem raw clear
eqcheck SE1-read [pcall xschem raw vcd_read $vf] 1
set t [first_cross $VSIG 0.9]
relcheck SE2-seconds-not-ticks $t 5.0012e-8 1e-12
check SE3-not-the-raw-tick-count \
  [expr {[string is double -strict $t] && abs($t - 50012.0) > 1.0}] "(t=$t)"
# and not merely "small": a reader that divided by the wrong power still lands
# somewhere small. Pin the exponent.
check SE4-exponent \
  [expr {[string is double -strict $t] && $t > 1e-9 && $t < 1e-6}] "(t=$t)"

# multiplier forms: `10 ns` must be exactly ten times `1ns`, `100ps` exactly a
# hundred times `1ps`. A reader that parsed only the unit and dropped the
# multiplier is a 1e1/1e2 error of the same family.
foreach {tag ts tick want} {
  SE5-10ns  {10 ns}  5   5.0e-8
  SE6-1ns   1ns      50  5.0e-8
  SE7-100ps {100ps}  500 5.0e-8
  SE8-1ps   1ps      50000 5.0e-8
  SE9-100ns {100 ns} 1   1.0e-7
} {
  set vf [file join $tmp se_[string map {- _} $tag].vcd]
  mkvcd_edge $vf $ts $tick [expr {$tick * 2}]
  xschem raw clear
  pcall xschem raw vcd_read $vf
  relcheck $tag [first_cross $VSIG 0.9] $want 1e-12
}
xschem raw clear

# ===========================================================================
# RW — the raw side is not rescaled either
# ===========================================================================
# The symmetric mistake: "fixing" a 1e3 disagreement by scaling the ANALOG side.
# The raw's time column is seconds already and must come back byte-for-byte as
# what the file says.
set rf [file join $tmp rw.raw]
mkraw_edge $rf 5.0e-8 $SKEW 1.0e-7
xschem raw clear
eqcheck RW1-read [pcall xschem raw read $rf tran] 1
eqcheck RW2-simtype [pcall xschem raw sim_type] tran
set tv [pcall xschem raw values time]
nearcheck RW3-t0 [lindex $tv 0] 0.0 1e-15
relcheck RW4-edge-sample [first_cross $RSIG 0.9] [expr {5.0e-8 + $SKEW}] 1e-12
relcheck RW5-last [lindex $tv end] 1.0e-7 1e-12
xschem raw clear

# ===========================================================================
# REF — the measured §A6 cross-check against the REAL artifacts on this box
# ===========================================================================
# Both files exist on the machine this was written on:
#   ~/.xschem/simulations/counter.vcd                 390,241 B
#   ~/.xschem/simulations/tb_counter_wrapper_ase.raw   20,840,786 B
# They are from two different runs (a 500 ns VCD probe and the 2 us reference
# run) but the clock stimulus is the same, so the FIRST LSB rising edge is the
# same event in both — which is what §A6 measured.
#
# Hard-pinned to the §A6 figures at the precision §A6 quotes (0.1 ps), the same
# contract test_vcd_read.tcl group A already holds these artifacts to. Re-running
# the mixed-signal simulation invalidates the pin in both files together.
#
# GUARD: absent artifacts must not print anything full_audit scores as a
# file-wide SKIP ("RESULT: SKIP", "skipped: no X", "SKIP: no X connection"), or
# every check above is silently discarded.
set refvcd $::env(HOME)/.xschem/simulations/counter.vcd
set refraw $::env(HOME)/.xschem/simulations/tb_counter_wrapper_ase.raw
if {[file exists $refvcd] && [file exists $refraw]} {
  xschem raw clear
  eqcheck REF1-raw-read [pcall xschem raw read $refraw tran] 1
  eqcheck REF2-vcd-read [pcall xschem raw read $refvcd vcd] 1
  eqcheck REF3-two-dbs [llength [lrange [split [pcall xschem raw info] "\n"] 1 end-1]] 2

  # the VCD side: TOP.counter.count[0], first rise
  catch {xschem raw switch 1}
  eqcheck REF4-vcd-type [pcall xschem raw sim_type] vcd
  set tv [first_cross {TOP.counter.count[0]} 0.9]
  # the raw side: v(count_out0) crossing 0.9 V on a 1.8 V rail. Bounded scan —
  # the edge is at ~2.5% of a 200,386-point run, near sample 5021.
  catch {xschem raw switch 0}
  eqcheck REF5-raw-type [pcall xschem raw sim_type] tran
  set tr [first_cross_scan v(count_out0) 0.9 40000]

  nearcheck REF6-vcd-50.0120ns $tv 50.0120e-9 1e-13
  nearcheck REF7-raw-50.0219ns $tr 50.0219e-9 1e-13
  # THE §A6 CROSS-CHECK, pinned: ~9.9 ps, physical, and inside the gate.
  check REF8-agree [agree $tv $tr] "(vcd=$tv raw=$tr tol=$TOL)"
  skewcheck REF9-skew-9.9ps $tv $tr 9.0e-12 11.0e-12
  # the analog LAGS. A sign flip here would mean the bridge model changed, not
  # that the time base is fine.
  skewcheck REF10-analog-lags $tv $tr 0.0 1.0
  # and the same 1e3 proof on REAL data, not just synthesized fixtures
  if {[bothnum $tv $tr]} {
    check REF11-1e3-up-would-fail [expr {![agree [expr {$tv * 1000.0}] $tr]}] \
      "(x1000 = [expr {$tv*1000.0}] vs raw $tr)"
    check REF12-1e3-down-would-fail [expr {![agree [expr {$tv / 1000.0}] $tr]}] \
      "(/1000 = [expr {$tv/1000.0}] vs raw $tr)"
  } else {
    check REF11-1e3-up-would-fail 0 "(vcd='$tv' raw='$tr')"
    check REF12-1e3-down-would-fail 0 "(vcd='$tv' raw='$tr')"
  }
  xschem raw clear
} else {
  puts "note: group REF not run — reference artifacts absent"
  puts "note:   $refvcd"
  puts "note:   $refraw"
  puts "note: the synthetic groups above cover D3 on their own; REF only pins"
  puts "note: the measured A6 numbers when the real run is still on disk."
}

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_vcd_time_base: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
