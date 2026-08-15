#!/bin/sh
# ===========================================================================
# doc/claude/batch_F/eyeball_fixtures.sh
#
# Builds EVERY fixture the batch F eyeball queue needs
# (doc/claude/batch_F/EYEBALL_QUEUE.md), then prints the five launch lines.
#
#   * No ngspice, no verilator, no PDK, no simulator of any kind: every results
#     database is synthesized text, written by tclsh with the mkraw / mkvcd
#     idiom of tests/headless/test_ase_cosim.tcl (~line 758 / ~line 768).
#   * Writes NOTHING outside its own scratch directory (printed at the end).
#     It never touches the repo, ~/.claude/, or ~/.claude/gui_test_gate/.
#   * Safe to re-run: it deletes and rebuilds only that one directory, so a
#     re-run also RESTORES any fixture a test step deliberately rewrote
#     (item 4 step 9 rewrites the co-simulation map).
#
# Usage:   sh doc/claude/batch_F/eyeball_fixtures.sh [scratch-dir]
# Default scratch dir: /tmp/xschem_eyeball_F   (override with $1)
# Needs: tclsh (already a hard dependency of xschem's own test suite).
# ===========================================================================
set -e

FIX=${1:-${XSCHEM_EYEBALL_DIR:-/tmp/xschem_eyeball_F}}
case "$FIX" in
  ""|/|/home|/home/*/|/tmp|/usr|/usr/*|/etc|/etc/*|/var|/var/*)
    echo "eyeball_fixtures.sh: refusing to use '$FIX' as a scratch dir" >&2
    exit 1 ;;
  /*) ;;
  *)  echo "eyeball_fixtures.sh: scratch dir must be an absolute path" >&2
      exit 1 ;;
esac

SELF=$(cd "$(dirname "$0")" && pwd)          # <repo>/doc/claude/batch_F
REPO=$(cd "$SELF/../../.." && pwd)           # <repo>
command -v tclsh >/dev/null 2>&1 || { echo "eyeball_fixtures.sh: tclsh not found" >&2; exit 1; }

rm -rf "$FIX"
mkdir -p "$FIX/tcl" "$FIX/nd0305" "$FIX/xd2" "$FIX/d4" "$FIX/i6/run" "$FIX/i7" \
         "$FIX/lib5/run" "$FIX/lib5/dlib/dcell/symbol"   "$FIX/lib5/dlib/dcell/verilog" \
         "$FIX/lib5/dlib/dcell2/symbol"  "$FIX/lib5/dlib/dcell2/verilog" \
         "$FIX/lib5/dlib/plaincell/symbol" "$FIX/lib5/dlib/tb1/schematic" \
         "$FIX/lib4/run" "$FIX/lib4/dlib/dcell2/symbol" "$FIX/lib4/dlib/dcell2/verilog" \
         "$FIX/lib4/dlib/tb4/schematic"

# every file below is written through this: quoted heredoc (so Tcl's $ and
# backslashes survive verbatim) + placeholder substitution.
emit() { sed -e "s|@FIX@|$FIX|g" -e "s|@REPO@|$REPO|g" > "$1"; }

# ===========================================================================
# 1. THE RESULTS DATABASES.  All of them, written by tclsh: the generators are
#    copied from the per-item procedures, which are themselves the mkraw/mkvcd
#    idiom of tests/headless/test_ase_cosim.tcl.
# ===========================================================================
emit "$FIX/tcl/mkdb.tcl" <<'MKDBEOF'
# Written by doc/claude/batch_F/eyeball_fixtures.sh -- run with tclsh.
set FIX {@FIX@}
proc wr {p s} { file mkdir [file dirname $p]; set f [open $p w]; puts -nonewline $f $s; close $f }

# ---- shared: a 1-bit VCD, 1 ps timescale, edges at 1/4, 1/2, 3/4, end ------
proc mkvcd_q {path sig ticks} {
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

# ======================= ITEM 1 (7a592f9c) =================================
# a shallow analog ramp confined to 0.25 .. 0.30 V, so a marker readout on the
# 0/1 digital trace can never be confused with it.
proc nd_mkraw {path {tmax 2.0e-9} {n 41}} {
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
nd_mkraw $FIX/nd0305/anlg.raw
mkvcd_q  $FIX/nd0305/d1.vcd siga 2000

# ======================= ITEM 8 (81a2b53f) =================================
proc xd_mkraw {path tmax n cyc} {              ;# `cyc` full sine periods
  set body "Title: xd2\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set v [expr {0.5 + 0.45 * sin(2*3.14159265358979*$cyc*$t/$tmax)}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}
proc xd_mkramp {path tmax n} {                 ;# a plain ramp 0.05 -> 0.45
  set body "Title: xd2-short\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set v [expr {0.05 + 0.40 * $t / $tmax}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}
proc xd_mkone {path} {                         ;# legal raw whose extent is a POINT
  set body "Title: xd2-one\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: 1\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(one)\tvoltage\n"
  append body "Values:\n0\t1e-06\n\t0.5\n\n"
  wr $path $body
}
xd_mkramp $FIX/xd2/short.raw 2.0e-9 41
xd_mkraw  $FIX/xd2/long.raw  2.0e-6 201 2
mkvcd_q   $FIX/xd2/sig.vcd   sigd 500000
xd_mkone  $FIX/xd2/one.raw

# ======================= ITEM 9 (c6d26026) =================================
# anlg.raw -- 41 points, 0..20 ns, v(anlg) ramps 0.20 -> 0.80 (0.5 ns step)
set n 41
set body "Title: d4eye\nDate: Tue Aug 11 00:00:00 2026\nPlotname: Transient Analysis\n"
append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
append body "Values:\n"
for {set i 0} {$i < $n} {incr i} {
  append body "$i\t[expr {$i * 0.5e-9}]\n\t[expr {0.20 + 0.60 * $i / ($n - 1)}]\n\n"
}
wr $FIX/d4/anlg.raw $body
# 1 ns TIMESCALE, not 1 ps: vcd_read materialises every change as (t-1 tick,
# old) then (t, new), so the tick size is the width of the step a cursor can be
# parked inside. At 1 ps that window is unreachable with a mouse.
proc d4vcd {path sig events endtick} {
  set b "\$timescale 1ns \$end\n\$scope module TOP \$end\n \$scope module m \$end\n"
  append b "  \$var wire 1 ! $sig \$end\n \$upscope \$end\n\$upscope \$end\n"
  append b "\$enddefinitions \$end\n"
  foreach {t v} $events { append b "#$t\n$v!\n" }
  append b "#$endtick\n"
  wr $path $b
}
d4vcd $FIX/d4/d1.vcd siga {0 0 5 1 9 0 13 1} 14   ;# 0 | 1@5ns | 0@9ns | 1@13ns, ends 14
d4vcd $FIX/d4/d2.vcd sigb {0 1 4 0 10 1} 12       ;# 1 | 0@4ns | 1@10ns,        ends 12

# ======================= ITEM 6 (2208d16d) =================================
# analog control: one REAL ngspice device-internal node, v(m.x1.xm1)
set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
append body "Flags: real\nNo. Variables: 3\nNo. Points: 3\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n\t2\tv(m.x1.xm1)\tvoltage\n"
append body "Values:\n0\t0.0\n\t0.0\n\t0.0\n\n1\t1e-09\n\t1.0\n\t0.2\n\n"
append body "2\t2e-09\n\t0.5\n\t0.4\n\n"
wr $FIX/i6/eye_anlg.raw $body
# fd_mkvcd_m VERBATIM: a legal VCD whose top $scope is the single letter `m`
wr $FIX/i6/eye_dig_m.vcd "\$timescale 1ps \$end
\$scope module m \$end
 \$scope module sub \$end
  \$var wire 1 ! sig \$end
  \$var wire 4 # count \[3:0\] \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
b0000 #
#100
1!
b0001 #
#200
"
# the same shape with an ordinary TOP.<inst> scope: the label judgement only
wr $FIX/i6/counter.vcd "\$timescale 1ps \$end
\$scope module TOP \$end
 \$scope module counter \$end
  \$var wire 1 ! clk \$end
  \$var wire 4 # q \[3:0\] \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
b0000 #
#100
1!
b0001 #
#200
"

# ======================= ITEM 7 (f51a19d1) =================================
# two databases that COLLIDE at the path `x1`, plus a third with a pure ancestor
set body "Title: f6\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
append body "Flags: real\nNo. Variables: 4\nNo. Points: 3\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(rootraw)\tvoltage\n"
append body "\t2\tv(x1.same)\tvoltage\n\t3\tv(x1.onlyraw)\tvoltage\n"
append body "Values:\n0\t0.0\n\t0.0\n\t0.0\n\t0.0\n\n"
append body "1\t1e-09\n\t1.0\n\t1.0\n\t1.0\n\n"
append body "2\t2e-09\n\t0.5\n\t0.5\n\t0.5\n\n"
wr $FIX/i7/coll_analog.raw $body
wr $FIX/i7/coll_digital.vcd {$timescale 1ps $end
$scope module x1 $end
 $var wire 1 ! same $end
 $var wire 1 # onlyvcd $end
$upscope $end
$enddefinitions $end
#0
1!
0#
#1000
0!
1#
#2000
}
wr $FIX/i7/anc_top.vcd {$timescale 1ps $end
$scope module TOP $end
 $scope module m $end
  $var wire 1 ! anconly $end
 $upscope $end
$upscope $end
$enddefinitions $end
#0
0!
#1000
1!
#2000
}

# ======================= ITEM 5 (fda9d5a8 + 7ff1be9d) ======================
# the basename `dig.vcd` is load-bearing: it is quoted in the F1e notice.
set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
append body "Flags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
append body "Values:\n0\t0.0\n\t0.0\n\n1\t1e-09\n\t1.0\n\n2\t2e-09\n\t0.5\n\n"
wr $FIX/lib5/anlg.raw $body
wr $FIX/lib5/dig.vcd {$timescale 1ps $end
$scope module TOP $end
 $scope module m $end
  $var wire 1 ! siga $end
  $var wire 1 # sigb $end
 $upscope $end
$upscope $end
$enddefinitions $end
#0
0!
0#
#100
1!
1#
#200
}

# ======================= ITEM 4 (11835169) =================================
set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
append body "Flags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
append body "Values:\n0\t0.0\n\t0.0\n\n1\t1e-09\n\t1.0\n\n2\t2e-09\n\t0.5\n\n"
wr $FIX/lib4/run/anlg.raw $body
# scopes TOP and TOP.wrapper.realmod.inner => TOP.wrapper.realmod exists ONLY
# as a prefix and owns no signal of its own.
wr $FIX/lib4/run/dcell2.vcd {$timescale 1ps $end
$scope module TOP $end
$var wire 1 ! q $end
$upscope $end
$scope module TOP $end
$scope module wrapper $end
$scope module realmod $end
$scope module inner $end
$var wire 1 # q $end
$upscope $end
$upscope $end
$upscope $end
$upscope $end
$enddefinitions $end
#0
0!
0#
#100
1!
1#
#200
}
puts "mkdb.tcl: databases written under $FIX"
MKDBEOF
tclsh "$FIX/tcl/mkdb.tcl"

# ===========================================================================
# 2. LIBRARIES, SYMBOLS, SCHEMATICS  (items 5 and 4)
# ===========================================================================
emit "$FIX/lib5/library.defs" <<'EOF'
DEFINE dlib @FIX@/lib5/dlib
EOF
echo "batch F item 5 eyeball fixture" > "$FIX/lib5/dlib/library.tag"

# three primitives; only dcell and dcell2 have a `verilog` view, so only they
# can enter F1's verilog-only branch.
for m in dcell dcell2 plaincell; do
  sed -e "s|MODEL|$m|g" > "$FIX/lib5/dlib/$m/symbol/$m.sym" <<'EOF'
v {xschem version=3.4.8 file_version=1.3}
G {}
K {type=primitive
template="name=a1 model=MODEL"
}
V {}
S {}
E {}
L 4 -60 -30 60 -30 {}
L 4 60 -30 60 30 {}
L 4 60 30 -60 30 {}
L 4 -60 30 -60 -30 {}
B 5 -62.5 -12.5 -57.5 -7.5 {name=clk dir=in}
B 5 57.5 -12.5 62.5 -7.5 {name=q dir=out}
T {@name} -55 -48 0 0 0.4 0.4 {}
EOF
done
cat > "$FIX/lib5/dlib/dcell/verilog/dcell.v" <<'EOF'
`timescale 1ps/1ps
module dcell(input clk, output q);
endmodule
EOF
cat > "$FIX/lib5/dlib/dcell2/verilog/dcell2.v" <<'EOF'
`timescale 1ps/1ps
module dcell2(input clk, output q);
endmodule
EOF
cat > "$FIX/lib5/dlib/tb1/schematic/tb1.sch" <<'EOF'
v {xschem version=3.4.8 file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {dlib/dcell} 0 0 0 0 {name=a1 model=dcell}
C {dlib/dcell2} 400 0 0 0 {name=a2 model=dcell2}
C {dlib/plaincell} 800 0 0 0 {name=a9 model=plaincell}
EOF

# ---- item 4: the SAME lib name, but dcell2.v declares `module realmod` ------
emit "$FIX/lib4/library.defs" <<'EOF'
DEFINE dlib @FIX@/lib4/dlib
EOF
echo "batch F item 4 eyeball fixture" > "$FIX/lib4/dlib/library.tag"
cat > "$FIX/lib4/dlib/dcell2/symbol/dcell2.sym" <<'EOF'
v {xschem version=3.4.8 file_version=1.3}
G {}
K {type=primitive
format="@name [ @@clk ] [ @@q ] @model"
template="name=a1 model=dcell2"
}
V {}
S {}
E {}
B 5 -72.5 -2.5 -67.5 2.5 {name=clk dir=in}
B 5 -72.5 17.5 -67.5 22.5 {name=q dir=out}
EOF
cat > "$FIX/lib4/dlib/dcell2/verilog/dcell2.v" <<'EOF'
`timescale 1ps/1ps
module realmod(input clk, output q);
endmodule
EOF
cat > "$FIX/lib4/dlib/tb4/schematic/tb4.sch" <<'EOF'
v {xschem version=3.4.8 file_version=1.3}
G {}
K {}
V {}
S {}
E {}
C {dlib/dcell2} 0 0 0 0 {name=a1 model=dcell2}
EOF
# THE STALE HINT.  One line, the exact shape ase::cosim_save_map writes
# (src/ase.tcl:1145 -- `# ...` comments then one braced dict per entry).
# `scope TOP.realmod` is a scope the loaded VCD does not have.
emit "$FIX/lib4/run/tb4_ase.cosim" <<'EOF'
# xschem ASE-L co-simulation map -- generated, do not edit.
# doc/claude/specs/mixed_signal_signal_browser.md section E (F2 consumes it).
{model dcell2 lib dlib cell dcell2 vfile @FIX@/lib4/dlib/dcell2/verilog/dcell2.v module realmod scope TOP.realmod vcd @FIX@/lib4/run/dcell2.vcd multi 0 ninst 1}
EOF
# XSCHEM_LIBRARY_PATH UNQUALIFIED (the write trace that rebuilds pathlist gates
# on the bare name); XSCHEM_LIBRARY_DEFS qualified.
emit "$FIX/lib4/f2rc" <<'EOF'
set XSCHEM_LIBRARY_PATH "@FIX@/lib4:$XSCHEM_LIBRARY_PATH"
set ::XSCHEM_LIBRARY_DEFS @FIX@/lib4/library.defs
EOF

# ===========================================================================
# 3. SESSION SETUP SCRIPTS
# ===========================================================================

# ---------------- SESSION 1: items 1 (7a592f9c) and 8 (81a2b53f) -----------
emit "$FIX/tcl/s1_graphs.tcl" <<'EOF'
# Batch F eyeball SESSION 1 -- items 1 (7a592f9c) and 8 (81a2b53f).
# Four graph strips in one plain window, six results databases, no simulator.
set no_recent_files 1
set XSCHEM_LIBRARY_PATH {}                       ;# UNQUALIFIED: the write trace
set ::XSCHEM_LIBRARY_DEFS @FIX@/lib5/library.defs ;# qualified; nothing is placed
set ::library_registry_defs_only 1
set graph_use_ctrl_key 0        ;# so `f`, `m`, `b` are plain keys over a graph

set ND @FIX@/nd0305
set XD @FIX@/xd2

xschem raw clear
xschem raw read $ND/anlg.raw tran   ;# slot 0  0..2ns   ramp 0.25 -> 0.30  ITEM 1
xschem raw read $ND/d1.vcd   vcd    ;# slot 1  0..2ns   TOP.m.siga         ITEM 1
xschem raw read $XD/short.raw tran  ;# slot 2  0..2ns   ramp 0.05 -> 0.45  item 8
xschem raw read $XD/long.raw  tran  ;# slot 3  0..2us   two sine cycles    item 8
xschem raw read $XD/sig.vcd   vcd   ;# slot 4  0..500ns TOP.m.sigd         item 8
xschem raw read $XD/one.raw   tran  ;# slot 5  ONE sample at 1us           item 8
xschem raw switch 0

set QA "\\\"a;v(anlg)%$XD/long.raw tran\\\""
set QV "\\\"d;TOP.m.sigd%$XD/sig.vcd vcd\\\""
set QO "\\\"o;v(one)%$XD/one.raw tran\\\""
set Q1 "\\\"vcdsig;TOP.m.siga%$ND/d1.vcd vcd\\\""

xschem set rectcolor 2
# item 8's three strips FIRST, so their rect indices really are 0, 1, 2.
xschem rect 0    0 2000  400 -1 {flags=graph,unlocked} 0   ;# 0 both %  (union)
xschem setprop rect 2 0 node "$QA\n$QV"
foreach {t v} {x1 0 x2 2e-9 y1 -0.2 y2 1.2} { xschem setprop rect 2 0 $t $v }
xschem rect 0  600 2000 1000 -1 {flags=graph,unlocked} 0   ;# 1 bare + %
xschem setprop rect 2 1 node "v(anlg)\n$QV"
foreach {t v} {x1 0 x2 2e-9 y1 -0.2 y2 1.2} { xschem setprop rect 2 1 $t $v }
xschem rect 0 1200 2000 1600 -1 {flags=graph,unlocked} 0   ;# 2 degenerate
xschem setprop rect 2 2 node "$QO"
foreach {t v} {x1 0 x2 2e-6 y1 -0.2 y2 1.2} { xschem setprop rect 2 2 $t $v }
# item 1's strip LAST (rect index 3), above the others. Left `flags=graph` as
# its author had it: it is the only locked graph, so it is its own X group.
xschem rect 0 -800 2000 -400 -1 {flags=graph} 0
xschem setprop rect 2 3 node "v(anlg)\n$Q1"
foreach {t v} {x1 0 x2 2e-9 y1 -0.3 y2 1.3} { xschem setprop rect 2 3 $t $v }

xschem text -560 -650 0 0 {ITEM 1  cross-DB pick} {} 0.5 0
xschem text -560   150 0 0 {STRIP 0  both %  (union)} {} 0.5 0
xschem text -560   750 0 0 {STRIP 1  bare + %} {} 0.5 0
xschem text -560  1350 0 0 {STRIP 2  degenerate} {} 0.5 0
xschem set graph_snap_cursor 1
xschem unselect_all

# `eye1` / `eye8` fill the window with one item's strips and restore that
# item's documented starting database. Type either in the CIW entry.
proc eye1 {} { xschem raw switch 0 ; xschem zoom_box -700 -900 2100 -300 ; xschem redraw
  puts "ITEM 1: current DB = [xschem raw sim_type] (must be tran)"
  puts "ITEM 1: TOP.m.siga in current DB = [xschem raw index TOP.m.siga] (must be -1)" }
proc eye8 {} { xschem raw switch 2 ; xschem zoom_box -700 -100 2100 1700 ; xschem redraw
  puts "ITEM 8: current DB = [xschem raw rawfile] (must be .../xd2/short.raw)" }

eye1
puts "SESSION 1 ready. rects=[xschem get graph_rects] (must be 4)"
puts [xschem raw info]
EOF

# ---------------- SESSION 2: item 9 (c6d26026) -----------------------------
emit "$FIX/tcl/s2_cursor.tcl" <<'EOF'
# Batch F eyeball SESSION 2 -- item 9 (c6d26026): one cursor, three databases.
#   strip 0 (top)    v(anlg)     from anlg.raw (dense analog, INTERPOLATES)
#                    TOP.m.siga  from d1.vcd   (sparse events, HOLDS)
#   strip 1 (bottom) TOP.m.sigb  from d2.vcd   (its own database, D4-8)
set no_recent_files 1
set XSCHEM_LIBRARY_PATH {}      ;# UNQUALIFIED: the write trace gates on the bare name
set ::XSCHEM_LIBRARY_DEFS {}    ;# qualified: plain read, no trace
set D @FIX@/d4

ase::state_save $D/session.state [dict replace [ase::state_default] rundir $D]
set ::D4TOK [ase::session_key d4eye eyeball state1]
ase::session_open $::D4TOK $D/session.state
if {![wviewer::open $::D4TOK]} { puts "D4 SETUP FAILED: the viewer did not open" ; return }
set vtop [wviewer::window_for $::D4TOK]
wm geometry $vtop 960x640
wm title $vtop {D4 eyeball -- one cursor, three databases}
update idletasks
after 300
update

# the databases live PER CONTEXT: register them in the VIEWER's context
xschem new_schematic switch $vtop.drw
xschem raw clear
xschem raw read $D/anlg.raw tran
xschem raw read $D/d1.vcd vcd
xschem raw read $D/d2.vcd vcd
xschem raw switch 0             ;# the ANALOG database is the current one

set G [dict replace [wviewer::empty_graph] x1 0 x2 20e-9 y1 -0.3 y2 1.3]
wviewer::set_graphs $::D4TOK [list $G $G]
wviewer::regenerate $::D4TOK
xschem new_schematic switch $vtop.drw
wviewer::add_trace $::D4TOK 0 v(anlg)     {} 4
wviewer::add_trace $::D4TOK 0 TOP.m.siga  {} 5
wviewer::add_trace $::D4TOK 1 TOP.m.sigb  {} 6

# F9 = read the ENGINE's per-database cursor-B annotation. draw.c
# graph_cursor_dbs + callback.c backannotate_at_cursor_b_pos stamp annot_p /
# annot_x / cursor_b_val INSIDE EACH DATABASE and nothing on screen shows them.
proc d4_probe_text {} {
  set vtop [wviewer::window_for $::D4TOK]
  xschem new_schematic switch $vtop.drw
  set out {}
  foreach {s nm} {0 v(anlg) 1 TOP.m.siga 2 TOP.m.sigb} {
    xschem raw switch $s
    set a [xschem raw annot]
    lappend out "slot $s [format %-9s [file tail [xschem raw rawfile]]] annot_p=[lindex $a 0]\
 annot_x=[ase::format_value [lindex $a 1]]  $nm=[ase::format_value [xschem raw value $nm {}]]"
  }
  xschem raw switch 0
  return [join $out "\n"]
}
proc d4_probe {} {
  tk_messageBox -parent [wviewer::window_for $::D4TOK] -title {D4 engine probe} \
    -message [d4_probe_text]
}
bind $vtop.drw <Key-F9> {d4_probe; break}

xschem new_schematic switch $vtop.drw
xschem raw switch 0
xschem redraw
raise_activate_toplevel $vtop
puts "SESSION 2 ready -- registry:\n[xschem raw info]"
EOF

# ---------------- SESSION 3: items 6 (2208d16d) then 7 (f51a19d1) ----------
emit "$FIX/tcl/s3_browser.tcl" <<'EOF'
# Batch F eyeball SESSION 3 -- item 6 (2208d16d) first, then item 7 (f51a19d1)
# in the SAME window: type `eye7` in the CIW entry when item 6 is finished.
#   eye_anlg.raw   ngspice tran, carries one real device-internal node
#   eye_dig_m.vcd  top $scope is the single letter `m`
#   counter.vcd    top $scope TOP.counter
set no_recent_files 1
set eye_dir @FIX@/i6
set ::XSCHEM_LIBRARY_DEFS @FIX@/i6/library.defs
set ::library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH {}
set fp [open $eye_dir/library.defs w]
puts $fp "DEFINE devices @REPO@/xschem_library/devices"
close $fp

set eye_st [ase::state_default]
dict set eye_st rundir [file join $eye_dir run]
ase::state_save [file join $eye_dir eye.state] $eye_st
set ::eye_tok [ase::session_key eyelib item6 eyeview]
ase::session_open $::eye_tok [file join $eye_dir eye.state]

if {![wviewer::open $::eye_tok]} { puts "EYE: no viewer window (headless?)" ; return }
update
wviewer::browser_toggle 1 $::eye_tok
update
wviewer::switch_ctx $::eye_tok
ase::attach_dbs [file join $eye_dir eye_anlg.raw] tran \
  [list [file join $eye_dir eye_dig_m.vcd] [file join $eye_dir counter.vcd]]
xschem raw switch [file join $eye_dir eye_dig_m.vcd] vcd   ;# the CURRENT database
wviewer::browser_refresh $::eye_tok 1
update
puts "EYE: current db   = [xschem raw rawfile]"
puts "EYE: browser kind = [wviewer::browser_curtype $::eye_tok]  (must be: vcd)"

# ---- ITEM 7: re-point the SAME viewer at the colliding databases -----------
proc eye7 {} {
  wviewer::switch_ctx $::eye_tok
  puts "F6 attach: [ase::attach_dbs @FIX@/i7/coll_analog.raw tran \
        [list @FIX@/i7/coll_digital.vcd @FIX@/i7/anc_top.vcd]]"
  wviewer::browser_refresh $::eye_tok 1
  update
  puts "ITEM 7 READY: 3 DBs attached, analog current, All DBs as you left it"
}
puts "SESSION 3 ready -- item 6 now; type `eye7` in the CIW entry for item 7."
EOF

# fallback: item 7 on its own, if `eye7` does not repopulate the sidebar
emit "$FIX/tcl/s3b_collide.tcl" <<'EOF'
# Batch F eyeball SESSION 3 FALLBACK -- item 7 (f51a19d1) standalone.
set no_recent_files 1
set D @FIX@/i7
set fp [open $D/library.defs w]
puts $fp "DEFINE devices @REPO@/xschem_library/devices"
close $fp
set XSCHEM_LIBRARY_PATH @REPO@/xschem_library   ;# UNQUALIFIED
set ::XSCHEM_LIBRARY_DEFS @FIX@/i7/library.defs ;# qualified
set ::library_registry_defs_only 1

set fp [open $D/eyeball.state w] ; close $fp     ;# an empty state file is valid
set ::F6TOK [ase::session_key f6 coll ase]
ase::session_open $::F6TOK $D/eyeball.state
if {![wviewer::open $::F6TOK]} {
  puts "F6 SETUP FAILED: the waveform viewer did not open"
} else {
  wviewer::browser_toggle 1 $::F6TOK
  wviewer::switch_ctx $::F6TOK
  puts "F6 attach: [ase::attach_dbs $D/coll_analog.raw tran \
        [list $D/coll_digital.vcd $D/anc_top.vcd]]"
  wviewer::browser_refresh $::F6TOK 1
  update
  puts "F6 EYEBALL READY: 3 DBs attached, sidebar on, All DBs still OFF"
}
EOF

# ---------------- SESSION 4: item 5 (fda9d5a8 + 7ff1be9d) ------------------
emit "$FIX/tcl/s4_item5.tcl" <<'EOF'
# Batch F eyeball SESSION 4 -- item 5: F1's verilog-only-view branch and the
# F5/F1e empty-pane notice.  a1 = mapped (scope TOP), a2 = verilog view but NO
# map entry (refusal), a9 = no verilog view (the gate must stay silent).
set no_recent_files 1
set FIX @FIX@/lib5
set ::XSCHEM_LIBRARY_DEFS $FIX/library.defs   ;# qualified
set ::library_registry_defs_only 1
set XSCHEM_LIBRARY_PATH $FIX                  ;# UNQUALIFIED: the write trace
xschem load $FIX/dlib/tb1/schematic/tb1.sch

set RAW $FIX/anlg.raw
set VCD $FIX/dig.vcd
set ST [ase::state_default]
dict set ST design [dict create lib dlib cell tb1 view schematic]
dict set ST rundir $FIX/run
ase::state_save $FIX/session.state $ST
set TOK [ase::session_key dlib tb1 schematic]
set ::I5TOK $TOK
ase::session_open $TOK $FIX/session.state
# ONE map entry, for cell dlib/dcell only.
ase::cosim_save_map $ST [list [dict create model dcell lib dlib cell dcell \
  vfile $FIX/dlib/dcell/verilog/dcell.v module dcell scope TOP \
  vcd $VCD multi 0 ninst 1]]

# the viewer + its Signal Browser, both databases attached through the product's
# own path, the tree parked on the design root so the lower pane is SETTLED AND
# LISTING THINGS before the first gesture (step 7b's predicate reads the pane
# model: starting from an already-empty pane would hide the very bug).
if {[info exists ::has_x]} {
  wviewer::open $TOK
  wviewer::switch_ctx $TOK
  xschem raw clear
  ase::attach_dbs $RAW tran [list $VCD]
  wviewer::browser_toggle 1 $TOK
  wviewer::browser_refresh $TOK 1
  update
  set VT [wviewer::window_for $TOK]
  $VT.wvbrowser.pw.tvf.tv selection set {g:}
  update
  xschem new_schematic switch .drw
}

# `e5cap` reads the three surfaces verbatim -- type it in the CIW entry.
proc e5cap {} {
  set vt [wviewer::window_for $::I5TOK]
  puts "PANE CAPTION: [$vt.wvbrowser.pw.sea.st cget -text]"
  puts "SIDEBAR HEAD: [string map [list \n { >> }] [$vt.wvbrowser.ph cget -text]]"
  puts "CANVAS NOTE : [llength [$vt.wvbrowser.pw.sea.c find withtag seanote]] item(s)"
  puts "PANE ROWS   : [llength [$vt.wvbrowser.pw.sea.c find withtag cell]]"
  puts "TREE SEL    : [$vt.wvbrowser.pw.tvf.tv selection]"
  puts "ALL-DBS BOX : $::wviewer::sballdb($vt.wvbrowser.wvsearch)"
}
puts "SESSION 4 ready -- tb1.sch has a1 (mapped) a2 (unmapped) a9 (no verilog view)"
EOF

# ===========================================================================
# 4. THE LAUNCH LINES
# ===========================================================================
emit "$FIX/RUN.txt" <<'EOF'
Batch F eyeball queue -- launch lines (doc/claude/batch_F/EYEBALL_QUEUE.md).
Run each from the repo root. NO -q: on the xschem command line -q is --quit.
Rebuild once before the first launch:   make -C @REPO@/src

  cd @REPO@
  # SESSION 1 -- items 1 and 8 (graph strips, one window)
  DISPLAY=:0 ./src/xschem --script @FIX@/tcl/s1_graphs.tcl
  # SESSION 2 -- item 9 (cursor B across three databases)
  DISPLAY=:0 ./src/xschem --script @FIX@/tcl/s2_cursor.tcl
  # SESSION 3 -- items 6 then 7 (Signal Browser; type `eye7` between them)
  DISPLAY=:0 ./src/xschem --script @FIX@/tcl/s3_browser.tcl
  #            fallback for item 7 alone:
  DISPLAY=:0 ./src/xschem --script @FIX@/tcl/s3b_collide.tcl
  # SESSION 4 -- item 5 (verilog-only view + empty-pane notice)
  DISPLAY=:0 ./src/xschem --script @FIX@/tcl/s4_item5.tcl
  # SESSION 5 -- item 4 (stale scope hint overruled, CIW colour)
  DISPLAY=:0 ./src/xschem --rcfile @FIX@/lib4/f2rc @FIX@/lib4/dlib/tb4/schematic/tb4.sch
EOF

n=$(find "$FIX" -type f | wc -l)
echo "----------------------------------------------------------------------"
echo "batch F eyeball fixtures built: $n files under"
echo "    $FIX"
echo "launch lines: $FIX/RUN.txt   (also in doc/claude/batch_F/EYEBALL_QUEUE.md)"
echo "re-run this script at any time to restore every fixture; remove with"
echo "    rm -rf $FIX"
echo "----------------------------------------------------------------------"
