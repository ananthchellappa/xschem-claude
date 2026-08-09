# §C of doc/claude/specs/mixed_signal_signal_browser.md — a VCD is a Raw DB.
#
# Covers H1: $timescale variants, buses, the $dumpvars initial block, the
# TWO-SCOPES-ONE-ID alias case, a missing $enddefinitions, and a TRUNCATED file
# (a killed simulator always leaves one). Plus C3 (X/Z never silently 0), C5
# (the DB lands in the registry, `xschem raw info` lists it) and the
# coexistence regression: an analog .raw and a VCD in the registry together,
# with the analog one still readable.
#
# THE LOAD-BEARING ONES, and why:
#   AL*  the alias case. The reference counter.vcd declares TEN $var lines with
#        only EIGHT distinct id codes — `clk` and `count` appear in BOTH scope
#        TOP and scope TOP.counter with the SAME id. A reader that assumes
#        id->name is 1:1 silently drops or duplicates a vector.
#   ST*  the step materialization. draw_graph_points() renders with XDrawLines()
#        in the digital path too, i.e. it INTERPOLATES. One column per change
#        would draw ramps instead of edges, so every change must emit a hold
#        sample at t-1 and the new value at t.
#   XZ*  X and Z must not read back as 0, and must differ from each other.
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_vcd_read.tcl

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
# floating point compare for the time column
proc nearcheck {name got want {tol 1e-15}} {
  check $name [expr {abs($got - $want) <= $tol}] "(got '$got' want '$want')"
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch vcdread]

proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# read a whole vector as a Tcl list, current DB
proc vec {name} {
  set out {}
  set n [xschem raw points]
  for {set p 0} {$p < $n} {incr p} { lappend out [xschem raw value $name $p] }
  return $out
}
proc timevec_ps {} {
  set out {}
  set n [xschem raw points]
  for {set p 0} {$p < $n} {incr p} {
    lappend out [format %.0f [expr {[xschem raw value time $p] * 1e12}]]
  }
  return $out
}
# load one VCD as the only DB
proc load1 {f} {
  xschem raw clear
  return [xschem raw vcd_read $f]
}

# ===========================================================================
# A — the reference artifact (the real thing the feature exists for)
# ===========================================================================
set ref $::env(HOME)/.xschem/simulations/counter.vcd
if {[file exists $ref]} {
  eqcheck A1-read [load1 $ref] 1
  eqcheck A2-simtype [xschem raw sim_type] vcd
  # 10 $var: 5 scalars + 5 buses (4+4+2+4+4 = 18 bits) + time = 29
  eqcheck A3-nvars [xschem raw vars] 29
  # 1 seed + 2 per change time (9 more) + 1 final = 20; NOT the 50,088 `#t`
  eqcheck A4-points [xschem raw points] 20
  # `xschem raw info` must LIST it as a registry DB (spec C5)
  set info [xschem raw info]
  check A5-info-lists-db [expr {[string match "*counter.vcd vcd*" $info]}] "(info='[string map {\n |} $info]')"
  # span: 0 .. 500,000 ps
  nearcheck A6-t0 [xschem raw value time 0] 0.0
  nearcheck A7-tlast [xschem raw value time 19] 5e-7 1e-18
  # THE ALIAS: same id `&` under TOP and TOP.counter -> two distinct vectors,
  # equal contents. Under a 1:1 id->name assumption one of these is missing.
  set a [vec TOP.clk]
  set b [vec TOP.counter.clk]
  check AL1-alias-both-exist [expr {[llength $a] == 20 && [llength $b] == 20}] "(clk lens [llength $a]/[llength $b])"
  eqcheck AL2-alias-equal $a $b
  set a [vec TOP.count]
  set b [vec TOP.counter.count]
  eqcheck AL3-alias-bus-equal $a $b
  # the payload: six signals that exist NOWHERE in the analog raw
  foreach n {TOP.counter.phase TOP.counter.half TOP.counter.prev
             TOP.counter.next_count TOP.counter.tc TOP.counter.carry} {
    check AL4-internal-$n [expr {[llength [vec $n]] == 20}] ""
  }
  # bus explode: composite + one column per bit
  eqcheck A8-bus-composite [vec TOP.counter.count] {0 0 1 1 1 1 2 2 2 2 3 3 3 3 4 4 4 4 5 5}
  eqcheck A9-bus-bit0 [vec {TOP.counter.count[0]}] {0 0 1 1 1 1 0 0 0 0 1 1 1 1 0 0 0 0 1 1}
  eqcheck A10-bus-bit2 [vec {TOP.counter.count[2]}] {0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1}
  # THE STEP: a hold sample one tick before each edge, so the interpolating
  # renderer draws a square edge and not a 50 ns ramp
  eqcheck ST1-step-times [timevec_ps] \
    {0 50011 50012 100011 100012 150011 150012 200011 200012 250011 250012 300011 300012 350011 350012 400011 400012 450011 450012 500000}
  set c [vec TOP.clk]
  check ST2-hold-then-edge [expr {[lindex $c 1] == 0 && [lindex $c 2] == 1}] "(hold=[lindex $c 1] edge=[lindex $c 2])"
  xschem raw clear
} else {
  puts "SKIPPED: group A (reference $ref absent; run the mixed-signal sim first)"
}

# ===========================================================================
# B — $timescale variants
# ===========================================================================
proc mkvcd {path timescale body} {
  set h ""
  if {$timescale ne ""} { append h "\$timescale $timescale \$end\n" }
  append h "\$scope module top \$end\n"
  append h "\$var wire 1 ! a \$end\n"
  append h "\$upscope \$end\n"
  append h "\$enddefinitions \$end\n"
  wr $path "$h$body"
}
# a rising edge at tick 1000, run ends at 2000
set body "#0\n\$dumpvars\n0!\n\$end\n#1000\n1!\n#2000\n"

mkvcd $tmp/ts_ps.vcd "1ps"   $body
mkvcd $tmp/ts_ns.vcd "10 ns" $body
mkvcd $tmp/ts_us.vcd "1us"   $body
mkvcd $tmp/ts_s.vcd  "1s"    $body
mkvcd $tmp/ts_none.vcd ""    $body
mkvcd $tmp/ts_bad.vcd "1qs"  $body

# edge tick 1000 -> the 3rd column (0, 999, 1000, 2000)
foreach {tag file want} {
  TS1-ps    ts_ps.vcd   1e-9
  TS2-ns-2tok ts_ns.vcd 1e-5
  TS3-us    ts_us.vcd   1e-3
  TS4-s     ts_s.vcd    1000.0
  TS5-nodefault-1ps ts_none.vcd 1e-9
  TS6-badunit-1ps   ts_bad.vcd  1e-9
} {
  eqcheck $tag-read [load1 $tmp/$file] 1
  nearcheck $tag [xschem raw value time 2] $want [expr {abs($want)*1e-9 + 1e-18}]
}
eqcheck TS7-cols [xschem raw points] 4
eqcheck TS8-colvals [vec top.a] {0 0 1 1}

# ===========================================================================
# C — buses: widths, bit naming, little-endian, short-vector extension
# ===========================================================================
wr $tmp/bus.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 4 ! big \[3:0\] \$end
\$var wire 3 \" le \[0:2\] \$end
\$var wire 1 # s \$end
\$var wire 8 % wide \[7:0\] \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
b0000 !
b000 \"
0#
b00000000 %
\$end
#10
b1010 !
b101 \"
1#
b11 %
#20
"
eqcheck BU1-read [load1 $tmp/bus.vcd] 1
# 1 time + (big:1+4) + (le:1+3) + (s:1) + (wide:1+8) = 20
eqcheck BU2-nvars [xschem raw vars] 20
set names [split [xschem raw list] "\n"]
foreach n {m.big m.big[3] m.big[2] m.big[1] m.big[0] m.le m.le[0] m.le[1] m.le[2] m.s m.wide m.wide[7] m.wide[0]} {
  check BU3-name-$n [expr {[lsearch -exact $names $n] >= 0}] ""
}
# composite value of a [3:0] bus
eqcheck BU4-big-composite [vec m.big] {0 0 10 10}
eqcheck BU5-big-bit3 [vec {m.big[3]}] {0 0 1 1}
eqcheck BU6-big-bit2 [vec {m.big[2]}] {0 0 0 0}
eqcheck BU7-big-bit1 [vec {m.big[1]}] {0 0 1 1}
eqcheck BU8-big-bit0 [vec {m.big[0]}] {0 0 0 0}
# little-endian [0:2]: the leftmost binary char is declared index 0, so
# b101 means le[0]=1 le[1]=0 le[2]=1 and the composite (LSB = last char) is 5
eqcheck BU9-le-composite [vec m.le] {0 0 5 5}
eqcheck BU10-le-idx0 [vec {m.le[0]}] {0 0 1 1}
eqcheck BU11-le-idx1 [vec {m.le[1]}] {0 0 0 0}
eqcheck BU12-le-idx2 [vec {m.le[2]}] {0 0 1 1}
# SHORT VECTOR: `b11` on an 8-bit var means 0b00000011, left-extended with '0'
eqcheck BU13-short-extends [vec m.wide] {0 0 3 3}
eqcheck BU14-short-hi-bit-zero [vec {m.wide[7]}] {0 0 0 0}
eqcheck BU15-short-lo-bit-one [vec {m.wide[0]}] {0 0 1 1}
# a 1-bit $var must NOT be exploded (no `s[0]` column)
check BU16-scalar-not-exploded [expr {[lsearch -exact $names {m.s[0]}] < 0}] ""

# An absurd declared width is an AMPLIFICATION vector, not a style problem: width+1 growable
# double columns per $var, so ~30 bytes of header would ask for tens of GB. The over-wide
# declaration is skipped and the rest of the file still reads.
wr $tmp/wide.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! ok \$end
\$var wire 100000000 \" huge \[99999999:0\] \$end
\$var wire 2 # alsook \[1:0\] \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
1!
b10 #
\$end
#10
0!
#20
"
eqcheck BU17-wide-read [load1 $tmp/wide.vcd] 1
# time + ok + alsook + 2 bits = 5; the 100M-bit var contributed nothing
eqcheck BU18-wide-skipped [xschem raw vars] 5
set names [split [xschem raw list] "\n"]
check BU19-wide-absent [expr {[lsearch -exact $names m.huge] < 0}] ""
check BU20-others-survive [expr {[lsearch -exact $names m.ok] >= 0 && [lsearch -exact $names m.alsook] >= 0}] ""
eqcheck BU21-others-read [lindex [vec m.alsook] 0] 2

# ===========================================================================
# D — X and Z (C3: never silently 0, and distinguishable)
# ===========================================================================
wr $tmp/xz.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$var wire 1 \" b \$end
\$var wire 4 # v \[3:0\] \$end
\$var wire 1 % never \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
x!
z\"
b00x1 #
\$end
#10
0!
1\"
bzzzz #
#20
1!
0\"
b0101 #
#30
"
eqcheck XZ1-read [load1 $tmp/xz.vcd] 1
set a [vec m.a]
set b [vec m.b]
# THE REQUIREMENT: an X sample must not read back as 0
check XZ2-x-not-zero [expr {[lindex $a 0] != 0}] "(got [lindex $a 0])"
check XZ3-z-not-zero [expr {[lindex $b 0] != 0}] "(got [lindex $b 0])"
check XZ4-x-not-one  [expr {[lindex $a 0] != 1}] "(got [lindex $a 0])"
check XZ5-x-ne-z     [expr {[lindex $a 0] != [lindex $b 0]}] "(x=[lindex $a 0] z=[lindex $b 0])"
# the documented encoding
eqcheck XZ6-x-encoding [lindex $a 0] 0.5
eqcheck XZ7-z-encoding [lindex $b 0] 0.3
# both sentinels must sit inside get_bus_value()'s 0.2..0.8 undefined band so
# the EXISTING bus renderer prints 'X' with no renderer change
foreach {tag v} [list XZ8-x-in-band [lindex $a 0] XZ9-z-in-band [lindex $b 0]] {
  check $tag [expr {$v > 0.2 && $v < 0.8}] "(v=$v)"
}
# a vector with ANY x bit is X as a whole; all-z is Z; the bits keep their own state
# columns are (t=0 dumpvars) (t=9 hold) (t=10) (t=19 hold) (t=20) (t=30 tail)
set v [vec m.v]
eqcheck XZ10-vector-any-x-is-x [lindex $v 0] 0.5
eqcheck XZ11-vector-all-z-is-z [lindex $v 2] 0.3
eqcheck XZ12-vector-clean-value [lindex $v 4] 5
eqcheck XZ13-bit-keeps-x [lindex [vec {m.v[1]}] 0] 0.5
eqcheck XZ14-bit-keeps-clean [lindex [vec {m.v[0]}] 0] 1
# a signal never mentioned in $dumpvars and never assigned stays X, not 0
eqcheck XZ15-never-assigned-is-x [lindex [vec m.never] 0] 0.5

# ===========================================================================
# E — the $dumpvars initial block, and $comment / $dumpoff robustness
# ===========================================================================
wr $tmp/dv.vcd "\$date Mon \$end
\$version handmade \$end
\$comment #999 1! b1111 # this text must never be read as data \$end
\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$var wire 1 \" b \$end
\$upscope \$end
\$enddefinitions \$end
\$dumpvars
1!
0\"
\$end
#0
#10
0!
#20
"
eqcheck DV1-read [load1 $tmp/dv.vcd] 1
# $dumpvars BEFORE any #t: those values are the state at the first timestamp
eqcheck DV2-initial-a [lindex [vec m.a] 0] 1
eqcheck DV3-initial-b [lindex [vec m.b] 0] 0
# the $comment's "#999" must not have become a timestamp
set ts [timevec_ps]
check DV4-comment-not-data [expr {[lsearch -exact $ts 999] < 0}] "(times=$ts)"
eqcheck DV5-first-time [lindex $ts 0] 0
# ...and it must produce ONE column at that first timestamp, not two. A $dumpvars block
# written BEFORE the first #t is the state AT it; flushing it separately as well left a
# DUPLICATE time sample, which raw_get_pos()'s bracketing walks straight over.
set dup 0
for {set i 1} {$i < [llength $ts]} {incr i} {
  if {[lindex $ts $i] == [lindex $ts [expr {$i-1}]]} { set dup 1 }
}
check DV6-no-duplicate-time [expr {!$dup}] "(times=$ts)"
eqcheck DV7-points [xschem raw points] 4

# X/Z INSIDE A VECTOR must agree with the vector's own bit columns for EVERY unknown
# character, not just 'x'. 'h' 'l' 'w' '-' and any corrupt byte all mean "not 0/1/z", and
# a composite that counted them as 0 would report a fully defined integer while its own
# bit column reported unknown — the silent X->0 this whole encoding exists to prevent.
wr $tmp/oddchars.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 4 ! v \[3:0\] \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
bH011 !
\$end
#10
b-011 !
#20
bw011 !
#30
b0011 !
#40
"
eqcheck OC1-read [load1 $tmp/oddchars.vcd] 1
set v [vec m.v]
# columns: (0) (9) (10) (19) (20) (29) (30) (40)
eqcheck OC2-H-is-x [lindex $v 0] 0.5
eqcheck OC3-dash-is-x [lindex $v 2] 0.5
eqcheck OC4-w-is-x [lindex $v 4] 0.5
eqcheck OC5-clean-still-3 [lindex $v 6] 3
# the bit column and the composite must never disagree
eqcheck OC6-bit3-x [lindex [vec {m.v[3]}] 0] 0.5
eqcheck OC7-bit0-one [lindex [vec {m.v[0]}] 0] 1
check OC8-composite-agrees-with-bit \
  [expr {[lindex $v 0] == [lindex [vec {m.v[3]}] 0]}] \
  "(composite=[lindex $v 0] bit3=[lindex [vec {m.v[3]}] 0])"

# A LONG hierarchical name must not collapse the bit columns onto one another. Bit names
# were once formatted into a fixed 128-byte buffer, which truncated every bit of a
# long-named bus to the SAME string: XINSERT_NOREPLACE kept one, get_raw_index() resolved
# them all to bit 0, and the bus read back as N copies of its LSB.
set deep "s0123456789012345678901234567890123456789"
set path ""
for {set i 0} {$i < 5} {incr i} { append path "\$scope module ${deep}_$i \$end\n" }
set ups ""
for {set i 0} {$i < 5} {incr i} { append ups "\$upscope \$end\n" }
wr $tmp/longname.vcd "\$timescale 1ps \$end
$path\$var wire 4 ! wide \[3:0\] \$end
$ups\$enddefinitions \$end
#0
\$dumpvars
b0000 !
\$end
#10
b1010 !
#20
"
eqcheck LN1-read [load1 $tmp/longname.vcd] 1
set pre ""
for {set i 0} {$i < 5} {incr i} { append pre "${deep}_$i." }
set base "${pre}wide"
check LN2-name-is-long [expr {[string length $base] > 200}] "(len=[string length $base])"
eqcheck LN3-nvars [xschem raw vars] 6
set names [split [xschem raw list] "\n"]
foreach b {0 1 2 3} {
  check LN4-bit$b-distinct [expr {[lsearch -exact $names "${base}\[$b\]"] >= 0}] ""
}
# all four bit names must be DIFFERENT (the truncation bug made them identical)
set bitnames {}
foreach b {0 1 2 3} { lappend bitnames "${base}\[$b\]" }
eqcheck LN5-bits-unique [llength [lsort -unique $bitnames]] 4
# and they must carry the real bits of 1010, not four copies of bit 0
eqcheck LN6-bit0 [lindex [vec "${base}\[0\]"] end] 0
eqcheck LN7-bit1 [lindex [vec "${base}\[1\]"] end] 1
eqcheck LN8-bit2 [lindex [vec "${base}\[2\]"] end] 0
eqcheck LN9-bit3 [lindex [vec "${base}\[3\]"] end] 1
eqcheck LN10-composite [lindex [vec $base] end] 10

# ===========================================================================
# F — missing $enddefinitions (non-conforming / truncated header)
# ===========================================================================
wr $tmp/noend.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$dumpvars
0!
\$end
#10
1!
#20
"
eqcheck ND1-read [load1 $tmp/noend.vcd] 1
eqcheck ND2-nvars [xschem raw vars] 2
# the $dumpvars block must NOT have been swallowed as an unknown header block
eqcheck ND3-dumpvars-survived [lindex [vec m.a] 0] 0
eqcheck ND4-edge-seen [lindex [vec m.a] end] 1
check ND5-has-points [expr {[xschem raw points] >= 3}] "(points=[xschem raw points])"

# a header that ends at EOF with no body at all: must FAIL, not half-build
wr $tmp/hdronly.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
"
eqcheck ND6-header-only-fails [load1 $tmp/hdronly.vcd] 0
# and a file with no $var at all
wr $tmp/novar.vcd "\$timescale 1ps \$end
\$enddefinitions \$end
#0
#10
"
eqcheck ND7-no-var-fails [load1 $tmp/novar.vcd] 0
eqcheck ND8-missing-file-fails [load1 $tmp/does_not_exist.vcd] 0

# ===========================================================================
# G — TRUNCATED file (a killed simulator always leaves one)
# ===========================================================================
# truncated mid value-change record: `b1010` with no id token after it
wr $tmp/trunc1.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$var wire 4 \" v \[3:0\] \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
b0000 \"
\$end
#10
1!
#20
b1010"
eqcheck TR1-read [load1 $tmp/trunc1.vcd] 1
# everything before the truncation survives
eqcheck TR2-kept-edge [lindex [vec m.a] end] 1
# the incomplete record is dropped, not applied as garbage
eqcheck TR3-dropped-partial [lindex [vec m.v] end] 0

# truncated mid-timestamp: the last line is a bare `#` fragment
wr $tmp/trunc2.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
\$end
#10
1!
#2"
eqcheck TR4-read [load1 $tmp/trunc2.vcd] 1
eqcheck TR5-kept-edge [lindex [vec m.a] end] 1

# truncated INSIDE the header, mid-$var: no $end, then EOF
wr $tmp/trunc3.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$var wire 1 \" b"
eqcheck TR6-header-trunc-no-crash [load1 $tmp/trunc3.vcd] 0

# truncated on a SCALAR record: the file ends with a bare value character whose
# id was cut off. It must be dropped, not charged to some other signal.
wr $tmp/trunc4.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
\$end
#10
#20
1"
eqcheck TR7-scalar-trunc-read [load1 $tmp/trunc4.vcd] 1
eqcheck TR8-scalar-trunc-dropped [vec m.a] {0 0}
eqcheck TR9-scalar-trunc-cols [xschem raw points] 2

# An UNDECLARED id in the body (a corrupt file, or a writer emitting a change
# for something it never declared) must be ignored outright — never charged to
# whichever variable happens to sit at index 0, and never manufacturing a column.
wr $tmp/unkid.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$var wire 4 \" v \[3:0\] \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
b0000 \"
\$end
#10
1@
b1111 @
#20
1!
#30
"
eqcheck UD1-read [load1 $tmp/unkid.vcd] 1
# the unknown-id timestamp (#10) must not have produced a column at all
eqcheck UD2-times [timevec_ps] {0 19 20 30}
eqcheck UD3-a-untouched-by-unknown [vec m.a] {0 0 1 1}
eqcheck UD4-v-untouched-by-unknown [vec m.v] {0 0 0 0}

# A NON-MONOTONIC file (a corrupt writer; the patched shim clamps for the same reason).
# values[0] must come out non-decreasing whatever the file says, because raw_get_pos()
# brackets on it and draw.c's wrap detection compares against values[0][0] — an out-of-order
# X column is a silently wrong plot, not a crash.
wr $tmp/nonmono.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
\$end
#200
1!
#100
0!
#300
"
eqcheck MO1-read [load1 $tmp/nonmono.vcd] 1
set ts [timevec_ps]
set mono 1
for {set i 1} {$i < [llength $ts]} {incr i} {
  if {[lindex $ts $i] < [lindex $ts [expr {$i-1}]]} { set mono 0 }
}
check MO2-time-non-decreasing $mono "(times=$ts)"
# the backwards change is clamped onto the last column, so its value still wins there
eqcheck MO3-backwards-change-kept [lindex [vec m.a] end-1] 0
eqcheck MO4-tail-is-max-tick [lindex $ts end] 300

# ...and the tail column must be the MAX timestamp, not merely the LAST one. These differ
# only when the file's largest #t sits in the middle, which is the case that proves the
# distinction is real rather than incidental.
wr $tmp/tailmax.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
\$end
#100
1!
#500
#200
"
eqcheck MO5-read [load1 $tmp/tailmax.vcd] 1
eqcheck MO6-tail-uses-max [timevec_ps] {0 99 100 500}
eqcheck MO7-tail-holds-last-value [lindex [vec m.a] end] 1

# ===========================================================================
# H — registry coexistence: an analog .raw and a VCD at the same time
# ===========================================================================
# A minimal ascii spice raw file (tran, 3 points). read_raw_ascii_point() ends a
# point at an EMPTY LINE -- without the blank line after each point the reader
# warns "ascii block is not of correct size" and the values land wrong.
wr $tmp/an.raw "Title: coexist
Date: Mon
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(n1)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e-08
\t2.000000000000000e+00

2\t2.000000000000000e-08
\t3.000000000000000e+00

"
xschem raw clear
set r [pcall xschem raw read $tmp/an.raw tran]
eqcheck CX1-analog-read $r 1
eqcheck CX2-analog-simtype [xschem raw sim_type] tran
eqcheck CX3-analog-vars [xschem raw vars] 2
eqcheck CX4-analog-value [xschem raw value v(n1) 1] 2
# now add the VCD as a SECOND database
eqcheck CX5-vcd-added [xschem raw vcd_read $tmp/bus.vcd] 1
eqcheck CX6-vcd-current [xschem raw sim_type] vcd
set info [xschem raw info]
check CX7-both-listed [expr {[string match "*an.raw tran*" $info] && [string match "*bus.vcd vcd*" $info]}] \
  "(info='[string map {\n |} $info]')"
# switch back to the analog DB: it must be intact
eqcheck CX8-switch-back [xschem raw switch $tmp/an.raw tran] 1
eqcheck CX9-analog-still-tran [xschem raw sim_type] tran
eqcheck CX10-analog-still-reads [xschem raw value v(n1) 2] 3
eqcheck CX11-analog-vars-intact [xschem raw vars] 2
# and forward again
eqcheck CX12-switch-to-vcd [xschem raw switch $tmp/bus.vcd vcd] 1
eqcheck CX13-vcd-still-reads [xschem raw value m.big 2] 10
# `raw read <f> vcd` is the same door as `raw vcd_read <f>`
xschem raw clear
eqcheck CX14-read-with-type [xschem raw read $tmp/bus.vcd vcd] 1
eqcheck CX15-read-with-type-simtype [xschem raw sim_type] vcd
eqcheck CX16-read-with-type-vars [xschem raw vars] 20
# the raw_read bypass path (used by open_sub_schematic / hi_descend carry-over)
# must not hand a .vcd to the spice parser
eqcheck CX17-raw_read-vcd [pcall xschem raw_read $tmp/bus.vcd vcd] 1
eqcheck CX18-raw_read-vcd-simtype [xschem raw sim_type] vcd
xschem raw clear

# THE REAL PAIR: the analog raw and the VCD from the SAME mixed-signal run must
# coexist, with the analog one still fully readable after the VCD is added.
set refraw $::env(HOME)/.xschem/simulations/tb_counter_wrapper_ase.raw
if {[file exists $refraw] && [file exists $ref]} {
  eqcheck RP1-analog-read [pcall xschem raw read $refraw tran] 1
  eqcheck RP2-analog-simtype [xschem raw sim_type] tran
  set anvars [xschem raw vars]
  set anpts [xschem raw points]
  check RP3-analog-has-data [expr {$anvars > 1 && $anpts > 1}] "(vars=$anvars points=$anpts)"
  eqcheck RP4-vcd-added [xschem raw vcd_read $ref] 1
  eqcheck RP5-vcd-current [xschem raw sim_type] vcd
  set info [xschem raw info]
  check RP6-both-listed \
    [expr {[string match "*tb_counter_wrapper_ase.raw tran*" $info] && [string match "*counter.vcd vcd*" $info]}] \
    "(info='[string map {\n |} $info]')"
  eqcheck RP7-switch-back [xschem raw switch $refraw tran] 1
  eqcheck RP8-analog-still-current [xschem raw sim_type] tran
  eqcheck RP9-analog-vars-intact [xschem raw vars] $anvars
  eqcheck RP10-analog-points-intact [xschem raw points] $anpts
  xschem raw clear
} else {
  puts "SKIPPED: group RP (reference run artifacts absent)"
}

# ===========================================================================
# I — scopes and naming
# ===========================================================================
wr $tmp/scope.vcd "\$timescale 1ps \$end
\$scope module TOP \$end
\$var wire 1 ! clk \$end
\$scope module inner \$end
\$var wire 1 ! clk \$end
\$var wire 1 \" q \$end
\$scope module deeper \$end
\$var wire 1 \" q \$end
\$upscope \$end
\$upscope \$end
\$var wire 1 # top_only \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
0!
1\"
0#
\$end
#10
1!
0\"
#20
"
eqcheck SC1-read [load1 $tmp/scope.vcd] 1
set names [split [xschem raw list] "\n"]
foreach n {TOP.clk TOP.inner.clk TOP.inner.q TOP.inner.deeper.q TOP.top_only} {
  check SC2-name-$n [expr {[lsearch -exact $names $n] >= 0}] ""
}
# 1 time + 5 scalars
eqcheck SC3-nvars [xschem raw vars] 6
# $upscope really pops: top_only is at TOP, not inside inner
check SC4-upscope-pops [expr {[lsearch -exact $names TOP.inner.top_only] < 0}] ""
# THREE-way alias on id `"`
eqcheck SC5-alias3-a [vec TOP.inner.q] [vec TOP.inner.deeper.q]
eqcheck SC6-alias2-clk [vec TOP.clk] [vec TOP.inner.clk]
# names are stored VERBATIM: Verilog is case sensitive, so no lowercasing
check SC7-case-preserved [expr {[lsearch -exact $names TOP.clk] >= 0 && [lsearch -exact $names top.clk] < 0}] ""

# ===========================================================================
# J — real ($var real) and the no-change file
# ===========================================================================
wr $tmp/real.vcd "\$timescale 1ns \$end
\$scope module m \$end
\$var real 64 ! x \$end
\$upscope \$end
\$enddefinitions \$end
#0
\$dumpvars
r1.5 !
\$end
#10
r-2.25 !
#20
"
eqcheck RE1-read [load1 $tmp/real.vcd] 1
eqcheck RE2-nvars [xschem raw vars] 2
eqcheck RE3-initial [lindex [vec m.x] 0] 1.5
eqcheck RE4-changed [lindex [vec m.x] end] -2.25
check RE5-real-not-exploded [expr {[lsearch -exact [split [xschem raw list] "\n"] {m.x[0]}] < 0}] ""

# a file with timestamps but NO value changes at all: the trace must still span
# the run rather than collapsing to nothing
wr $tmp/nochange.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
#100
#200
"
eqcheck NC1-read [load1 $tmp/nochange.vcd] 1
eqcheck NC2-two-cols [xschem raw points] 2
eqcheck NC3-spans-run [timevec_ps] {0 200}
eqcheck NC4-all-unknown [vec m.a] {0.5 0.5}

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_vcd_read: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
