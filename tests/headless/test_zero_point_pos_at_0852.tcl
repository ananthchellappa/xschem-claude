#
#  File: test_zero_point_pos_at_0852.tcl
#
#  This file is part of XSCHEM,
#  a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
#  simulation.
#  Copyright (C) 1998-2023 Stefan Frederik Schippers
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#
# ---------------------------------------------------------------------------
# ISSUE 0852 -- get_raw_value() bounded `point` from ABOVE only, so a
# ZERO-POINT database SIGSEGVed `xschem raw pos_at`.
#
# SAME INPUT AS 0836, DIFFERENT DEREFERENCE. ngspice writes `No. Points: 0`
# into the raw header when a run STARTS and backfills the real count only when
# it ENDS, so for the entire duration of every simulation the file on disk is a
# well-formed, UNTRUNCATED, zero-point raw. read_dataset() reads it as a success
# with allpoints == 0, and my_realloc(id, ptr, 0) frees and NULLs every
# raw->values[v] while raw->values itself stays non-NULL. 0836 guarded
# update_op(). This suite covers the OTHER route into the same database.
#
# MECHANISM: raw_get_pos() clamped its search window to
#   int sign, lastpoint = raw->npoints[dset] - 1;   /* -1 on an empty dataset */
# and get_raw_value() bounded the index from ABOVE only:
#   if(ofs + point < xctx->raw->allpoints) return xctx->raw->values[idx][ofs + point];
# `allpoints` is a signed int (xschem.h), so `-1 < 0` is TRUE and it
# dereferenced values[idx][-1] on a freed, NULLed column.
#
# WHAT THE USER DOES TO REACH IT: watches a running simulation in the waveform
# viewer. `xschem raw pos_at` is called from wviewer::interp_value
# (src/wave_viewer.tcl), the viewer's value readout, and the surrounding Tcl
# `catch` CANNOT catch a SIGSEGV -- there was no degraded mode, the process
# died and unsaved schematic work went with it.
#
# ---------------------------------------------------------------------------
# CHILD HARNESS, AND WHY IT IS NOT OPTIONAL
# ---------------------------------------------------------------------------
# The defect kills the interpreter. A `check` that SIGSEGVs takes every
# remaining row of its suite with it and the completion banner never prints, so
# a regression would read as an opaque CRASH with no ids rather than as a named
# FAIL. Every crash-provoking sequence below therefore runs in a CHILD xschem
# (`--nogui --pipe`, bounded by timeout(1)) whose PROCESS EXIT is the assertion;
# the parent never executes one. Same design, and the same run_child/scrub
# machinery, as test_zero_point_raw_0836.tcl and test_raw_read_failure_0306.tcl.
#
# WARNING xschem INSTALLS ITS OWN HANDLER FOR SIGNAL 11, so a crash exits 1,
# not 139. An exit-code test that only looks for 139 PASSES ON A CRASHING TREE.
# Every survival row asserts BOTH `rc == 0` AND that a post-call sentinel
# actually printed, because those are different failures.
#
# ---------------------------------------------------------------------------
# THE FIXTURE RULE, AND IT IS LOAD-BEARING
# ---------------------------------------------------------------------------
# The fixtures are HAND-WRITTEN WELL-FORMED raws, never garbage bytes and never
# SHORT. Garbage fails every leg and therefore PASSES ON A CRASHING TREE. A
# short data area is the quieter version of the same trap: xschem prints
# `Warning: binary block is not of correct size`, reads past the end of the
# file, and hands back one variable's samples under another variable's name --
# 0836's own S fixture did exactly that until this commit. Row P4 below asserts
# every vector of the multi-point fixture reads back EXACTLY, so this suite
# cannot repeat it.
#
# The binary layout is ROW-MAJOR (point-major): for each point, all variables in
# header order. N points x V variables = N*V doubles.
#
# Run standalone (a --nogui item end to end; no display is needed):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_zero_point_pos_at_0852.tcl
# ---------------------------------------------------------------------------

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
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch zeropointposat0852]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}

# ---------------------------------------------------------------------------
# the forgery trap: a child's stdout ends up interpolated into a check's detail
# line, so no child may be able to forge a harness sentinel. Each sentinel is
# BUILT with [format] so it never appears literally in this file either.
# ---------------------------------------------------------------------------
set ::SIGMARK [format {%s: %s} FATAL signal]
set ::SCRUB [list \
  $::SIGMARK                        {F#TAL sig} \
  [format {%s() %s} Tcl_AppInit error] {Tcl_App#nit err} \
  [format {%s:} RESULT]             {R#SULT:} \
  [format {%s: %s} OVERALL ok]      {OV#RALL ok} \
  [format {%s: %s} skipped {no X}]  {sk#pped noX} \
  [format {%s: no X %s} SKIP connection] {SK#P noX conn}]
proc scrub {s} { return [string map $::SCRUB $s] }

# ---------------------------------------------------------------------------
# the child harness (same as test_zero_point_raw_0836.tcl)
# ---------------------------------------------------------------------------
set ::XBIN [info nameofexecutable]

# Run $body in a fresh --nogui xschem. Returns {rc captured_text}. Never prints.
# The body is wrapped in a catch because an UNCAUGHT Tcl error in a
# `--pipe --script` child does not exit -- it idles in the stdin loop until
# something kills it, which would score TIMEOUT, the opaque outcome this whole
# design exists to avoid and the one indistinguishable from the SIGSEGV it is
# here to detect. The wrapper turns any Tcl error into a prompt exit 9 with the
# message captured as Z_ERR. `exit` inside the catch still exits: Tcl_Exit is
# not catchable.
proc run_child {tag body} {
  global tmp
  set script [file join $tmp c_$tag.tcl]
  set out    [file join $tmp c_$tag.out]
  wr $script "if {\[catch {\n$body\n} ::zerr\]} {\n  puts \"Z_ERR=\$::zerr\"\n  flush stdout\n  exit 9\n}\n"
  set rc 0
  if {[catch {exec timeout 10 $::XBIN --nogui --pipe -q --nolog --script $script >& $out} e opts]} {
    set ec {}
    catch {set ec [dict get $opts -errorcode]}
    switch -- [lindex $ec 0] {
      CHILDSTATUS { set rc [lindex $ec 2] }
      CHILDKILLED { set rc 139 }
      default     { set rc 1 }
    }
  }
  set txt {}
  if {[file exists $out]} { set fp [open $out r]; set txt [read $fp]; close $fp }
  # A child killed by a signal writes an on-disk-undo emergency save into /tmp.
  # Reap it so neither a regression nor a sabotaged state litters the box.
  foreach {all d} [regexp -all -inline {EMERGENCY SAVE DIR: (\S+)} $txt] {
    if {[string match {*xschem_emergencysave*} $d]} { catch {file delete -force $d} }
  }
  return [list $rc $txt]
}
# THE ASSERTION: exit 0 AND the post-call sentinel actually printed AND no
# crash marker. All three, for the reason in the header.
proc survived {r} {
  lassign $r rc txt
  return [expr {$rc == 0 && [string first Z_SURVIVED $txt] >= 0 \
                && [string first $::SIGMARK $txt] < 0}]
}
# zval returns the value ALREADY SCRUBBED (see the forgery trap above).
proc zval {r key} {
  lassign $r rc txt
  set v {}
  regexp "${key}=(\[^\n\r\]*)" $txt -> v
  return [scrub [string trim $v]]
}
proc ctail {r} {
  lassign $r rc txt
  set one [string map [list \n { | } \r {}] $txt]
  return "rc=$rc tail='[scrub [string range $one end-180 end]]'"
}
# every child begins by sourcing the generated fixture paths + builders
proc kid {tag body} {
  global tmp
  return [run_child $tag "source [list [file join $tmp fix.tcl]]\n$body"]
}

# ---------------------------------------------------------------------------
# fixtures -- hand-written WELL-FORMED raw headers, in pure Tcl.
#   Z  well-formed ZERO-POINT operating point raw
#   L  well-formed ZERO-POINT transient raw  (what a RUNNING .tran leaves on disk)
#   T  a good 5-point transient raw, RISING v(a), FALLING v(b)
# T carries one rising and one falling signal on purpose: raw_get_pos() picks a
# search direction from `sign = (vend > vstart) ? 1 : -1`, so a twin built only
# on rising data would leave half the bisection unexercised.
# ---------------------------------------------------------------------------
wr [file join $tmp fix.tcl] {
set ::TMP [file dirname [info script]]

proc raw_header {plot npoints varlist} {
  set h "Title: * 0852 fixture\n"
  append h "Date: Wed Aug 26 12:00:00  2026\n"
  append h "Plotname: $plot\n"
  append h "Flags: real\n"
  append h "No. Variables: [llength $varlist]\n"
  append h "No. Points: $npoints\n"
  append h "Variables:\n"
  set i 0
  foreach v $varlist {
    append h "\t$i\t[lindex $v 0]\t[lindex $v 1]\n"
    incr i
  }
  append h "Binary:\n"
  return $h
}
proc raw_write {path plot npoints varlist doubles} {
  set f [open $path wb]
  fconfigure $f -translation binary
  puts -nonewline $f [raw_header $plot $npoints $varlist]
  if {[llength $doubles]} {
    puts -nonewline $f [binary format q[llength $doubles] $doubles]
  } else {
    # a real running-sim raw has an ALLOCATED, as-yet-unwritten data area; the
    # zeros make the file well-formed and untruncated, which is the whole point
    # of the fixture rule. They are never read: the store loop is `for(p = 0;
    # p < npoints; p++)` and npoints is 0.
    puts -nonewline $f [string repeat "\x00" 4096]
  }
  close $f
}

set ::OPVARS {{v(a) voltage} {v(b) voltage} {i(v2) current} {i(v1) current}}
set ::TRVARS {{time time} {v(a) voltage} {v(b) voltage} {i(v1) current}}

# Z: a well-formed ZERO-POINT operating point database
proc mk_Z {p} { raw_write $p "Operating Point" 0 $::OPVARS {} }
# L: a well-formed ZERO-POINT transient database -- a simulation still running
proc mk_L {p} { raw_write $p "Transient Analysis" 0 $::TRVARS {} }
# T: a good 5-point transient. ROW-MAJOR: per point, all 4 vars in header order.
proc mk_T {p} {
  raw_write $p "Transient Analysis" 5 $::TRVARS {
    0.0e-9 0.0 5.0 -1e-3
    1.0e-9 1.0 4.0 -2e-3
    2.0e-9 2.0 3.0 -3e-3
    3.0e-9 3.0 2.0 -4e-3
    4.0e-9 4.0 1.0 -5e-3
  }
}

set ::Z [file join $::TMP Z.raw]
set ::L [file join $::TMP L.raw]
set ::T [file join $::TMP T.raw]
mk_Z $::Z
mk_L $::L
mk_T $::T

# VERBATIM BODY of wviewer::interp_value (src/wave_viewer.tcl), the viewer's
# value readout and the shipped path onto raw_get_pos(). Copied rather than
# sourced because src/wave_viewer.tcl is a Tk file and this is a --nogui suite;
# row V0 asserts the copy still matches the shipped call sequence.
proc iv {var x} {
  set names [split [xschem raw list] "\n"]
  set sweep [lindex $names 0]
  set n [xschem raw points]
  # ISSUE 0855 -- mirrored from the shipped proc: a run that has not finished
  # yet leaves a results file with no points in it, and the honest readout for
  # data that does not exist is nothing at all. Comment kept free of brace
  # characters on purpose -- this body is written out inside a braced block.
  if {$n <= 0} { return {} }
  set pos [xschem raw pos_at $sweep $x]
  if {$pos < 0} {
    set s0 [xschem raw value $sweep 0]
    set sl [xschem raw value $sweep [expr {$n - 1}]]
    if {abs($x - $s0) <= abs($x - $sl)} { return [xschem raw value $var 0] }
    return [xschem raw value $var [expr {$n - 1}]]
  }
  if {$pos >= $n - 1} { return [xschem raw value $var [expr {$n - 1}]] }
  set xa [xschem raw value $sweep $pos]
  set xb [xschem raw value $sweep [expr {$pos + 1}]]
  set ya [xschem raw value $var $pos]
  set yb [xschem raw value $var [expr {$pos + 1}]]
  set st {}
  catch {set st [xschem raw sim_type]}
  if {$st eq {vcd}} { return $ya }
  if {$xb == $xa} { return $ya }
  return [expr {$ya + ($yb - $ya) * ($x - $xa) / ($xb - $xa)}]
}
}

# the parent needs the same builders for its own in-process (safe) rows
source [file join $tmp fix.tcl]

# ===========================================================================
# PRECONDITIONS -- asserted as ROWS, so a fixture that silently failed to load
# cannot make a later row pass vacuously.
# ===========================================================================
eqcheck {P1 fixture Z reads as a database (well-formed, not garbage)} \
  [pcall xschem raw read $::Z op] 1
eqcheck {P2 fixture Z really is ZERO-point} [pcall xschem raw points] 0
eqcheck {P3 Z's dataset was counted, so the db is ATTACHED not discarded} \
  [pcall xschem raw datasets] 1
catch {xschem raw clear}
eqcheck {P4 fixture L reads and is zero-point too} \
  [expr {[pcall xschem raw read $::L tran] == 1 ? [pcall xschem raw points] : {readfail}}] 0
catch {xschem raw clear}
eqcheck {P5 fixture T is a good 5-point database} \
  [expr {[pcall xschem raw read $::T tran] == 1 ? [pcall xschem raw points] : {readfail}}] 5

# ⚠ P6-P9 ARE THE ANTI-HOLLOW-FIXTURE ROWS. A raw whose data area is SHORT
# still reads with the promised point count -- xschem warns and runs off the end
# of the file, handing back one variable's samples under another's name. Without
# these rows the whole positive twin below would be pinning garbage. This is not
# hypothetical: 0836's S fixture did exactly that until this commit.
eqcheck {P6 T's sweep vector reads back EXACTLY (fixture not short)} \
  [string trim [pcall xschem raw values time 0]] {0 1e-09 2e-09 3e-09 4e-09}
eqcheck {P7 T's RISING signal reads back exactly} \
  [string trim [pcall xschem raw values v(a) 0]] {0 1 2 3 4}
eqcheck {P8 T's FALLING signal reads back exactly} \
  [string trim [pcall xschem raw values v(b) 0]] {5 4 3 2 1}
eqcheck {P9 T's last variable reads back exactly (the end of each row)} \
  [string trim [pcall xschem raw values i(v1) 0]] {-0.001 -0.002 -0.003 -0.004 -0.005}
catch {xschem raw clear}

# ===========================================================================
# ROW 1 -- THE FIX. `xschem raw pos_at` on a zero-point database must RETURN,
# not die. Acceptance row 1 of issue 0852.
# ===========================================================================
set r1 [kid r1 {
  xschem raw read $::Z op
  puts "Z_PTS=[xschem raw points]"
  puts "Z_POS=[xschem raw pos_at v(a) 1.0]"
  puts "Z_SURVIVED"
}]
eqcheck {R1a PRECONDITION: the child really loaded the zero-point database} [zval $r1 Z_PTS] 0
check   {R1b raw pos_at SURVIVES a zero-point OPERATING POINT database} [survived $r1] [ctail $r1]
eqcheck {R1c and answers -1 "not found", not a fabricated index} [zval $r1 Z_POS] -1

# The transient shape is the one a user actually hits: a .tran that is STILL
# RUNNING is what leaves a zero-point raw on disk, and a transient is what the
# waveform viewer is open on. Asserted separately from the op shape because the
# two take different paths through the reader.
set r2 [kid r2 {
  xschem raw read $::L tran
  puts "Z_PTS=[xschem raw points]"
  puts "Z_POS=[xschem raw pos_at v(a) 1.0]"
  puts "Z_SWEEP=[xschem raw pos_at time 1e-9]"
  puts "Z_SURVIVED"
}]
eqcheck {R1d PRECONDITION: the running-.tran fixture is zero-point} [zval $r2 Z_PTS] 0
check   {R1e raw pos_at SURVIVES a still-running TRANSIENT database} [survived $r2] [ctail $r2]
eqcheck {R1f and answers -1 for a signal} [zval $r2 Z_POS] -1
eqcheck {R1g and answers -1 for the sweep variable too} [zval $r2 Z_SWEEP] -1

# The optional arguments are separate code paths into the same clamp: `dset`
# is clamped independently, and from_start/to_end feed the window directly.
# A fix that only covered the defaulted call would pass R1b and still crash here.
set r3 [kid r3 {
  xschem raw read $::Z op
  puts "Z_D0=[xschem raw pos_at v(a) 1.0 0]"
  puts "Z_D9=[xschem raw pos_at v(a) 1.0 9]"
  puts "Z_DNEG=[xschem raw pos_at v(a) 1.0 -3]"
  puts "Z_WIN=[xschem raw pos_at v(a) 1.0 0 0 4]"
  puts "Z_WINBIG=[xschem raw pos_at v(a) 1.0 0 100 200]"
  puts "Z_ZEROVAL=[xschem raw pos_at v(a) 0.0]"
  puts "Z_SURVIVED"
}]
check   {R1h explicit dataset / window / dataset-out-of-range all SURVIVE} [survived $r3] [ctail $r3]
eqcheck {R1i explicit dataset 0 answers -1} [zval $r3 Z_D0] -1
eqcheck {R1j out-of-range dataset answers -1} [zval $r3 Z_D9] -1
eqcheck {R1k negative dataset answers -1} [zval $r3 Z_DNEG] -1
eqcheck {R1l an explicit window answers -1} [zval $r3 Z_WIN] -1
eqcheck {R1m a window past the end answers -1} [zval $r3 Z_WINBIG] -1
# value 0.0 is the arithmetic corner: with vstart == vend == 0.0 the range test
# `sign*value >= sign*vstart && sign*value <= sign*vend` is TRUE, so this is the
# one search value that used to enter the bisection loop on an empty dataset.
eqcheck {R1n searching for 0.0 -- the value that ENTERS the loop -- answers -1} [zval $r3 Z_ZEROVAL] -1

# ===========================================================================
# ROW 2 -- THE POSITIVE TWIN. Acceptance row 2 of issue 0852: without this the
# fix is indistinguishable from "make pos_at always answer -1", which every
# single row above would still pass.
#
# Every expected index below was MEASURED on the tree before the fix and must
# not move. raw_get_pos() returns the FLOOR side of a bisection, so `4.0` on a
# 0..4 rising ramp answers 3, not 4 -- that is today's behaviour and pinning it
# is the point.
# ===========================================================================
set t2 [kid t2 {
  xschem raw read $::T tran
  set out {}
  foreach v {-1.0 0.0 0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 9.0} {
    lappend out [xschem raw pos_at v(a) $v]
  }
  puts "Z_RISE=$out"
  set out {}
  foreach v {0.0 1.5 2.0 3.5 5.0 6.0} { lappend out [xschem raw pos_at v(b) $v] }
  puts "Z_FALL=$out"
  set out {}
  foreach v {0.0 1.5e-9 2.0e-9 4.0e-9 9.0e-9} { lappend out [xschem raw pos_at time $v] }
  puts "Z_SWEEP=$out"
  puts "Z_WIN13=[xschem raw pos_at v(a) 2.5 0 1 3]"
  puts "Z_WIN01=[xschem raw pos_at v(a) 2.5 0 0 1]"
  puts "Z_SURVIVED"
}]
check   {R2a the multi-point twin runs clean} [survived $t2] [ctail $t2]
eqcheck {R2b RISING signal: every index unchanged, inside AND outside the sweep} \
  [zval $t2 Z_RISE] {-1 0 0 1 1 2 2 3 3 3 -1 -1}
eqcheck {R2c FALLING signal: the sign<0 half of the bisection, unchanged} \
  [zval $t2 Z_FALL] {-1 3 3 1 0 -1}
eqcheck {R2d the SWEEP variable, unchanged} [zval $t2 Z_SWEEP] {0 1 2 3 -1}
eqcheck {R2e a windowed search that CONTAINS the value still finds it} [zval $t2 Z_WIN13] 2
eqcheck {R2f a windowed search that EXCLUDES the value still answers -1} [zval $t2 Z_WIN01] -1

# ===========================================================================
# ROW 3 -- STRUCTURAL, AND LABELLED AS SUCH.
#
# Acceptance row 3 asks that get_raw_value() refuse ANY negative point on BOTH
# of its arms, "asserted separately, since they are two `if`s and a fix can land
# on one". It CANNOT be asserted behaviourally: after this fix no
# `xschem raw ...` subcommand reaches get_raw_value() with a negative point at
# all (raw_get_pos() refuses the empty dataset first, `raw value`/`raw set`
# already spell `point >= 0`, `raw values` loops from 0, and the remaining
# negative-index site, waves_callback(), needs a GUI event). Asserting it by
# behaviour would mean adding a test-only subcommand to the shipped dispatcher,
# which is a worse trade than a source-shape row.
#
# So the fix removes the premise instead: the two arms were MERGED into one
# bound, and these rows assert that merge holds. With exactly one dereference
# site under exactly one lower bound, "a fix can land on one arm and not the
# other" is not a thing that can happen. That is a stronger guarantee than two
# parallel behavioural rows would have given.
#
# The rows read src/save.c. In an installed tree there is no src/save.c, so R3a
# FAILS LOUDLY rather than letting R3b-R3d pass vacuously on an empty string.
# ===========================================================================
set savec [file normalize [file join [file dirname [info script]] .. .. src save.c]]
set grv {}
if {[file readable $savec]} {
  set fp [open $savec r]; set src [read $fp]; close $fp
  # the function body: from its signature to the first line that is a lone
  # close-brace. NOTE a brace character inside a comment still counts toward
  # Tcl's brace matching when the comment sits inside a braced block, so this
  # comment may not contain one.
  if {[regexp {\ndouble get_raw_value\(int dataset, int idx, int point\)\n\{(.*?)\n\}\n} $src -> grv]} {}
  # STRIP C COMMENTS FIRST. These rows are about CODE, and the guard is
  # documented in a comment that quotes the very shapes they match -- including
  # draw.c's and scheduler.c's spellings of the same bound. Matching prose would
  # make the row's expected counts depend on how the fix is described, which is
  # the classic way a source-shape assertion rots into noise.
  regsub -all {/\*.*?\*/} $grv {} grv
}
check {R3a src/save.c is readable and get_raw_value()'s body was located} \
  [expr {[string length $grv] > 0}] "(len=[string length $grv])"
# STRUCTURAL: exactly one dereference of the values array in the whole function.
eqcheck {R3b get_raw_value() has exactly ONE dereference site (the arms are merged)} \
  [regexp -all {return xctx->raw->values\[idx\]\[} $grv] 1
# STRUCTURAL: that site is bounded from BELOW. This is the fix.
eqcheck {R3c and exactly one lower bound on `point` guards it} \
  [regexp -all {point >= 0} $grv] 1
# STRUCTURAL: the old un-lower-bounded shapes are gone, both of them.
eqcheck {R3d neither un-lower-bounded upper-only test survives} \
  [expr {[regexp {if\(point < xctx->raw->allpoints\)} $grv] || \
         [regexp {if\(ofs \+ point < xctx->raw->allpoints\)} $grv]}] 0

# R3e-R3f PIN raw_get_pos()'s EMPTY-DATASET REFUSAL, and they exist because the
# sabotage matrix MEASURED that nothing else does. Removing that refusal while
# leaving get_raw_value()'s lower bound in place reds ZERO behavioural rows in
# either suite: the bisection then runs with start == end == -1, get_raw_value()
# answers 0.0 instead of dereferencing, and the search collapses to -1 -- the
# same answer, by luck rather than by intent. The two guards are deliberately
# redundant (either one alone stops the SIGSEGV; that is the point of having
# both), so redundancy has to be asserted structurally or it is one careless
# cleanup away from being gone. Same reasoning as R3b-R3d, measured the same way.
set rgp {}
if {[string length $src]} {
  if {[regexp {\nint raw_get_pos\(const char \*node, double value, int dset, int from_start, int to_end\)\n\{(.*?)\n\}\n} $src -> rgp]} {}
  regsub -all {/\*.*?\*/} $rgp {} rgp
}
check {R3e raw_get_pos()'s body was located} [expr {[string length $rgp] > 0}] "(len=[string length $rgp])"
eqcheck {R3f and it REFUSES an empty dataset before searching it} \
  [regexp -all {raw->npoints\[dset\] <= 0} $rgp] 1

# ===========================================================================
# ROW 4 -- THE SHIPPED CALLER. wviewer::interp_value (src/wave_viewer.tcl) is
# how a user reaches raw_get_pos(): it is the waveform viewer's value readout.
# The Tcl `catch` around it cannot catch a SIGSEGV, so before this fix there was
# no degraded mode at all -- the process died.
#
# V0 keeps the copy in fix.tcl honest: if the shipped proc's call sequence
# changes, this suite must be told rather than quietly testing a stale mirror.
# ===========================================================================
set wv [file normalize [file join [file dirname [info script]] .. .. src wave_viewer.tcl]]
set wvsrc {}
if {[file readable $wv]} { set fp [open $wv r]; set wvsrc [read $fp]; close $fp }
check {V0 the shipped wviewer::interp_value still calls `xschem raw pos_at $sweep $x`, and still says nothing when the run has no points yet} \
  [expr {[string first {proc wviewer::interp_value} $wvsrc] >= 0 && \
         [string first {set pos [xschem raw pos_at $sweep $x]} $wvsrc] >= 0 && \
         [string first {if {$n <= 0} { return {} }} $wvsrc] >= 0}] \
  "(wave_viewer.tcl len=[string length $wvsrc])"

set v1 [kid v1 {
  xschem raw read $::T tran
  set out {}
  foreach x {0.0 0.5e-9 1.5e-9 2.5e-9 4.0e-9 9.0e-9 -1e-9} { lappend out [iv v(a) $x] }
  puts "Z_IV=$out"
  puts "Z_SURVIVED"
}]
check   {V1a the viewer readout runs clean on a finished simulation} [survived $v1] [ctail $v1]
# The interpolation is the positive twin ONE LAYER UP: v(a) is the 0..4 ramp, so
# the readout at 0.5 ns must be 0.5 V. If the fix had broken pos_at's answers
# these numbers would move even though R2 asserts the raw indices.
eqcheck {V1b and interpolates correctly, held flat outside the sweep (D4-4)} \
  [zval $v1 Z_IV] {0.0 0.5 1.5 2.5 4.0 4 0}

set v2 [kid v2 {
  xschem raw read $::L tran
  puts "Z_PTS=[xschem raw points]"
  puts "Z_IV=[expr {[catch {iv v(a) 1.0} e] ? "CAUGHT:$e" : $e}]"
  puts "Z_SURVIVED"
}]
eqcheck {V2a PRECONDITION: the viewer is reading a still-running simulation} [zval $v2 Z_PTS] 0
check   {V2b THE HEADLINE: the viewer readout no longer KILLS xschem mid-run} \
  [survived $v2] [ctail $v2]
# THE SIBLING, ISSUE 0855, IS NOW FIXED TOO, AND THIS ROW MOVED WITH IT.
# It used to read 0: `xschem raw value` fell back to the zeroed cursor values
# whenever the point index was out of range, so a user watching a running
# simulation saw a confident 0 V on every trace for the whole run -- better than
# the crash 0852 fixed, and still a number the database does not contain. The
# row was pinned at that 0 deliberately, so that fixing it would RED here rather
# than pass silently. Issue 0861 put the "was anything actually published"
# question back into the engine, and the viewer readout now asks the point count
# itself, so the answer is a BLANK: the readout bar says nothing about data that
# does not exist yet (RULING D5-1, INVARIANT I3).
eqcheck {V2c FIXED with the run still going the readout says nothing, rather than a confident 0 -- issue 0855} \
  [zval $v2 Z_IV] {}

catch {test_scratch_drop $tmp}
puts "----"
puts "test_zero_point_pos_at_0852: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; flush stdout; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; flush stdout; exit 1 }
