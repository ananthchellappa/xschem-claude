#
#  File: test_zero_point_raw_0836.tcl
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
# ISSUE 0836 -- update_op() SIGSEGVs on a ZERO-POINT database.
#
# THE INPUT IS THE ORDINARY CASE, NOT A CORNER. ngspice writes `No. Points: 0`
# into the raw header when a run STARTS and backfills the real count only when
# it ENDS. So for the entire duration of every simulation the file on disk is a
# well-formed, UNTRUNCATED, zero-point raw -- no crafted arguments, no
# truncation logic, and no `binary block is not of correct size` warning to
# notice. Pressing *Annotate Operating Point* while a simulation runs is the
# routine way to reach it.
#
# MECHANISM: read_raw_data_block() sizes each column with
#   my_realloc(_ALLOC_ID_, &raw->values[p], (offset + npoints) * sizeof(SPICE_DATA))
# and my_realloc() with size 0 FREES AND NULLS (util.c). With npoints==0 and
# offset==0, `raw->values` is non-NULL while every `raw->values[v]` is NULL, and
# read_dataset() still returns 1. update_op() tested the OUTER array and then
# dereferenced the INNER one with `p` pinned at 0.
#
# ---------------------------------------------------------------------------
# WHY THIS SUITE HAS A CHILD HARNESS, AND WHY THAT IS NOT OPTIONAL
# ---------------------------------------------------------------------------
# The defect kills the interpreter. A `check` that SIGSEGVs takes every
# remaining row of its suite with it and the completion banner never prints, so
# a regression would read as an opaque CRASH with no ids rather than as a named
# FAIL. Every crash-provoking sequence below therefore runs in a CHILD xschem
# (`--nogui --pipe`, bounded by timeout(1)) whose PROCESS EXIT is the assertion;
# the parent never executes one and survives every path. Same design, and the
# same run_child/scrub machinery, as tests/headless/test_raw_read_failure_0306.tcl.
#
# ⚠ xschem INSTALLS ITS OWN HANDLER FOR SIGNAL 11, so a crash exits 1, not 139.
# An exit-code test that only looks for 139 PASSES ON A CRASHING TREE. Every row
# here therefore asserts BOTH `rc == 0` AND that a post-call sentinel actually
# printed (Z_SURVIVED), because those are different failures: a clean refusal
# that returned nonzero and a crash both fail on rc alone, and only the sentinel
# tells them apart from the log.
#
# ---------------------------------------------------------------------------
# THE FIXTURE RULE, AND IT IS LOAD-BEARING
# ---------------------------------------------------------------------------
# The fixtures are HAND-WRITTEN WELL-FORMED HEADERS, never garbage bytes.
# Garbage fails every leg and therefore PASSES ON A CRASHING TREE -- a hollow
# fixture that proves the opposite of what it looks like. They are generated in
# pure Tcl (`binary format q`) so the suite needs no ngspice, and they were
# validated 2026-08-26 against real /usr/local/bin/ngspice-46+ output: a 296-byte
# 1-point op raw and a real 868 KB raw copied out of a still-running `.tran`
# both produce IDENTICAL readings and the IDENTICAL crash.
#
# Run standalone (this is a --nogui item end to end; no display is needed):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_zero_point_raw_0836.tcl
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
set tmp [test_scratch zeropoint0836]
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
# the child harness (lifted from test_raw_read_failure_0306.tcl)
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
proc crashed {r} {
  lassign $r rc txt
  return [expr {$rc != 0 && [string first $::SIGMARK $txt] >= 0}]
}
# zval returns the value ALREADY SCRUBBED (see the forgery trap above).
proc zval {r key} {
  lassign $r rc txt
  set v {}
  regexp "${key}=(\[^\n\r\]*)" $txt -> v
  return [scrub [string trim $v]]
}
proc zhas {r needle} {
  lassign $r rc txt
  return [expr {[string first $needle $txt] >= 0}]
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
# fixtures -- hand-written WELL-FORMED raw headers, in pure Tcl
# ---------------------------------------------------------------------------
# The five databases this suite needs:
#   G  good 1-point OPERATING POINT raw       v(a)=3.14 v(b)=1.5 i(v2)=-0.0015 i(v1)=-0.00314
#   Z  well-formed ZERO-POINT operating point raw
#   L  well-formed ZERO-POINT transient raw   (what a running .tran leaves on disk)
#   S  good multi-point transient raw         (3 points, used as a non-op current db)
#   P  a path REWRITTEN IN PLACE, for the registered-path rows
wr [file join $tmp fix.tcl] {
set ::TMP [file dirname [info script]]

proc raw_header {plot npoints varlist} {
  set h "Title: * 0836 fixture\n"
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

# G: the good 1-point operating point database
proc mk_G {p} { raw_write $p "Operating Point" 1 $::OPVARS {3.14 1.5 -0.0015 -0.00314} }
# Z: a well-formed ZERO-POINT operating point database
proc mk_Z {p} { raw_write $p "Operating Point" 0 $::OPVARS {} }
# L: a well-formed ZERO-POINT transient database -- a simulation still running
proc mk_L {p} { raw_write $p "Transient Analysis" 0 $::TRVARS {} }
# S: a good 3-point transient database.
# ROW-MAJOR (point-major): for each point, ALL variables, in header order. That
# is the ngspice binary raw layout, and 3 points x 4 vars = TWELVE doubles.
# ⚠ This originally supplied NINE, mislabelled "column-major". The data area was
# then 72 bytes where the header promised 96, xschem printed `Warning: binary
# block is not of correct size`, and the reader ran off the end of the file:
# `xschem raw values time 0` answered `0 7.78 1.2` -- v(a)'s first sample
# masquerading as a timestamp -- and v(a)'s last sample was leftover memory.
# No row here asserted S's VALUES, so it passed; but a short fixture is exactly
# the hollow fixture this suite's own header forbids, and the next row to read a
# number out of S would have been reading garbage. Corrected 2026-08-26 by the
# 0852 crew. Verified: the warning is gone and every vector reads back exactly.
proc mk_S {p} {
  raw_write $p "Transient Analysis" 3 $::TRVARS {
    0.0e-9 7.77 1.0 -1e-3
    1.0e-9 7.78 1.1 -2e-3
    2.0e-9 7.79 1.2 -3e-3
  }
}

set ::G [file join $::TMP G.raw]
set ::Z [file join $::TMP Z.raw]
set ::L [file join $::TMP L.raw]
set ::S [file join $::TMP S.raw]
mk_G $::G
mk_Z $::Z
mk_L $::L
mk_S $::S

# how many entries are in ngspice::ngspice_data right now
proc nd {} { return [array size ngspice::ngspice_data] }
# one node's published value, or {} if it was not published
proc nv {k} {
  if {[info exists ngspice::ngspice_data($k)]} { return [set ngspice::ngspice_data($k)] }
  return {}
}
# the registry listing, flattened onto one line
proc rinfo {} { return [string map [list \n | [file dirname [info script]]/ {}] [xschem raw info]] }
}

# the parent needs the same builders for its own in-process (safe) rows
source [file join $tmp fix.tcl]

# the refusal sentence minted in save.c (backannot_refuse_empty)
set ::REFUSAL "holds no simulation points yet"

# ===========================================================================
# PRECONDITIONS -- asserted as ROWS, so a fixture that silently failed to load
# cannot make a later row pass vacuously.
# ===========================================================================
eqcheck {P1 fixture G reads as a database} [pcall xschem raw read $::G op] 1
eqcheck {P2 fixture G is exactly ONE point} [pcall xschem raw points] 1
eqcheck {P3 fixture G is an operating point} [pcall xschem raw sim_type] op
eqcheck {P4 G publishes} [pcall xschem update_op] 1
eqcheck {P5 G publishes the RIGHT number} [nv v(a)] 3.14
eqcheck {P6 G publishes the second node too} [nv v(b)] 1.5
eqcheck {P7 G publishes 6 entries (4 vars + n\ vars + n\ points)} [nd] 6
catch {xschem raw clear}

eqcheck {P8 fixture Z reads as a database (it is well-formed, not garbage)} \
  [pcall xschem raw read $::Z op] 1
eqcheck {P9 fixture Z really is zero-point} [pcall xschem raw points] 0
catch {xschem raw clear}
eqcheck {P10 fixture L reads as a database} [pcall xschem raw read $::L tran] 1
eqcheck {P11 fixture L really is zero-point} [pcall xschem raw points] 0
catch {xschem raw clear}
eqcheck {P12 fixture S is multi-point} \
  [expr {[pcall xschem raw read $::S tran] == 1 ? [pcall xschem raw points] : {readfail}}] 3
catch {xschem raw clear}

# ===========================================================================
# ROW 1 -- `xschem raw read <op.raw> op 999 1000` then `xschem update_op`
# A sweep window that excludes every point. The FIRST door found.
# ===========================================================================
set r1 [kid r1 {
  puts "Z_RC=[xschem raw read $::G op 999 1000]"
  puts "Z_PTS=[xschem raw points]"
  puts "Z_UOP=[xschem update_op]"
  puts "Z_ND=[nd]"
  puts "Z_SURVIVED"
}]
check {R1a update_op survives a sweep-window zero-point database} [survived $r1] [ctail $r1]
eqcheck {R1b the read still succeeded (this is not "make the read fail")} [zval $r1 Z_RC] 1
eqcheck {R1c and it really was zero-point} [zval $r1 Z_PTS] 0
eqcheck {R1d update_op answers 0 -- "nothing was published"} [zval $r1 Z_UOP] 0
eqcheck {R1e nothing was published: the Tcl array is EMPTY, not zero-filled} [zval $r1 Z_ND] 0
check {R1f the refusal names the database and says why} [zhas $r1 $::REFUSAL] [ctail $r1]

# ===========================================================================
# ROW 2 -- the same state reached through `xschem annotate_op`
# ===========================================================================
set r2 [kid r2 {
  puts "Z_RC=[xschem raw read $::G op 999 1000]"
  catch {xschem annotate_op $::G} ares
  puts "Z_PTS=[xschem raw points]"
  puts "Z_ND=[nd]"
  puts "Z_SURVIVED"
}]
check {R2a annotate_op survives a zero-point database} [survived $r2] [ctail $r2]
eqcheck {R2b nothing was published} [zval $r2 Z_ND] 0

# ===========================================================================
# ROW 3 -- THE POSITIVE TWIN. Without this the fix is indistinguishable from
# "make update_op always refuse". It runs in a CHILD as well as in the parent
# preconditions, so an over-aggressive guard reds here even if the parent's
# in-process rows were somehow satisfied.
# ===========================================================================
set r3 [kid r3 {
  puts "Z_RC=[xschem raw read $::G op]"
  puts "Z_PTS=[xschem raw points]"
  puts "Z_UOP=[xschem update_op]"
  puts "Z_ND=[nd]"
  puts "Z_VA=[nv v(a)]"
  puts "Z_VB=[nv v(b)]"
  puts "Z_IV1=[nv i(v1)]"
  puts "Z_REFUSED=[expr {[string first {holds no simulation points} {}] >= 0}]"
  puts "Z_SURVIVED"
}]
check {R3a a NORMAL op database still works end to end} [survived $r3] [ctail $r3]
eqcheck {R3b it publishes} [zval $r3 Z_UOP] 1
eqcheck {R3c v(a) is the measured 3.14, not a fabricated 0} [zval $r3 Z_VA] 3.14
eqcheck {R3d v(b) is the measured 1.5} [zval $r3 Z_VB] 1.5
eqcheck {R3e the branch current is published too} [zval $r3 Z_IV1] -0.00314
eqcheck {R3f all 6 entries reach ngspice::ngspice_data} [zval $r3 Z_ND] 6
check {R3g and the refusal did NOT fire on a good database} \
  [expr {![zhas $r3 $::REFUSAL]}] [ctail $r3]

# ===========================================================================
# ROW 4a -- THE LIVE-RAW ROW. A good op database is attached, then
# `xschem annotate_op <live 0-point raw>` -- the thing that happens when a user
# presses Annotate Operating Point while a simulation is running.
# ===========================================================================
set r4 [kid r4 {
  puts "Z_PRE_RC=[xschem raw read $::G op]"
  puts "Z_PRE_UOP=[xschem update_op]"
  puts "Z_PRE_VA=[nv v(a)]"
  puts "Z_PRE_ND=[nd]"
  catch {xschem annotate_op $::L} ares
  puts "Z_PTS=[xschem raw points]"
  puts "Z_SIM=[xschem raw sim_type]"
  puts "Z_ND=[nd]"
  puts "Z_UOP=[xschem update_op]"
  puts "Z_INFO=[rinfo]"
  puts "Z_SURVIVED"
}]
check {R4a annotate_op on a LIVE (still-running) raw survives} [survived $r4] [ctail $r4]
eqcheck {R4b PRECONDITION: the good database really was attached first} [zval $r4 Z_PRE_VA] 3.14
eqcheck {R4c PRECONDITION: and really had published 6 entries} [zval $r4 Z_PRE_ND] 6
# ⚠ SINCE ISSUE 0856, R4d-R4g NO LONGER ISOLATE THE 0836 GUARD -- BUT NOT FOR
# THE REASON AN EARLIER DRAFT OF THIS COMMENT GAVE. It said a transient is turned
# away ONE GUARD EARLIER, before the zero-point test is reached. That is BACKWARDS
# and it is worth getting right, because issue 0859's whole product is a
# DO-NOT-REORDER rule on these guards. Source order inside update_op() is:
# digital refusal at save.c:2096, ZERO-POINT refusal at save.c:2154, then the 0856
# op/dc gate at save.c:2240. The zero-point guard is FIRST and it really does fire
# here -- measured, because the two refusals mint different sentences, and a
# zero-point transient emits 0836's own 'holds no simulation points yet' text
# while the 0856 line never appears for it.
# So the 0856 gate is a LATER BACKSTOP, not an earlier catch: delete the 0836
# guard and fixture L falls through to it and is refused anyway, with the same
# observable a Tcl row can see (`return 0`, array untouched). That is why these
# rows stay green with the 0836 guard deleted. They are kept because what they
# claim -- a live, still-running .tran raw publishes nothing -- is still exactly
# true and is still the user-visible behaviour worth pinning.
# THE ROWS THAT DO ISOLATE THE 0836 GUARD are the ZERO-POINT OPERATING POINT
# ones: R2*, R5a-R5j and R7*. `op` passes the 0856 gate, so those reach the
# zero-point test and red when it is removed. Recorded in issue 0859.
eqcheck {R4d the live raw did attach, and is zero-point} [zval $r4 Z_PTS] 0
eqcheck {R4e it attached as the transient it is} [zval $r4 Z_SIM] tran
eqcheck {R4f NOTHING was published from it -- not even zeros} [zval $r4 Z_ND] 0
eqcheck {R4g and update_op keeps answering 0 for it} [zval $r4 Z_UOP] 0
# ⚠ THIS ROW ASSERTS A KNOWN-DEFECTIVE STATE ON PURPOSE.
# `annotate_op` deletes the previously loaded OP *before* it reads anything
# (scheduler.c, the block commented "delete previously loaded OP", which fires on
# exactly `allpoints == 1` + sim_type op/dc -- the good database verbatim). So on
# a 0836-only tree the good database is gone by the time the refusal happens, and
# invariant I3 cannot be asserted HERE. That is issue 0807, which is NOT in this
# session's scope. Row 4h pins the defective state so that fixing 0807 REDS this
# row and forces it to be updated, instead of quietly satisfying it. The I3 half
# is asserted for real in ROW 4i below, which reaches it by a route the
# pre-delete does not cover.
eqcheck {R4h TRIPWIRE, BLOCKED ON 0807: the pre-delete leaves ONE registry entry} \
  [zval $r4 Z_INFO] {0 current|0 L.raw tran|}

# ===========================================================================
# ROW 4i -- THE I3 HALF, ASSERTED WITH A NUMBER READ OUT OF THE SURVIVOR.
# The pre-delete keys on the CURRENT database, not on the registry. Make the
# good op database present but NOT current and it survives untouched -- so this
# row asserts invariant I3 for real, with no dependence on 0807.
#
# "read a number out of it" is the point: asserting the pointer is non-NULL
# would measure nothing, and `xschem raw value` alone would not do either -- on
# a zero-point database BOTH of its bound arms are false and it falls through to
# the my_calloc-zeroed cursor_b_val, returning a benign-looking "0".
# ===========================================================================
set r4i [kid r4i {
  xschem raw read $::G op          ;# arr = [0 G op]          current 0
  xschem raw read $::S tran        ;# arr = [0 G op|1 S tran] current 1
  puts "Z_BASE_SW=[xschem raw switch 0]"
  puts "Z_BASE_UOP=[xschem update_op]"
  puts "Z_BASE_VA=[nv v(a)]"
  xschem raw switch 1              ;# make S current, so the pre-delete cannot fire
  catch {xschem annotate_op $::L} ares
  puts "Z_ND=[nd]"
  puts "Z_INFO=[rinfo]"
  xschem raw switch 0              ;# back to the SURVIVING good database
  puts "Z_SURV_PTS=[xschem raw points]"
  puts "Z_SURV_VAL=[xschem raw value v(a) 0 0]"
  puts "Z_SURV_UOP=[xschem update_op]"
  puts "Z_SURV_VA=[nv v(a)]"
  puts "Z_SURV_ND=[nd]"
  puts "Z_SURVIVED"
}]
check {R4i annotate_op on a live raw survives with a non-current good db} [survived $r4i] [ctail $r4i]
eqcheck {R4j PRECONDITION: the good db answered 3.14 BEFORE the refused call} [zval $r4i Z_BASE_VA] 3.14
eqcheck {R4k PRECONDITION: and had published} [zval $r4i Z_BASE_UOP] 1
# ⚠ same 0856 shadowing as R4d-R4g above: fixture L is a zero-point TRANSIENT.
eqcheck {R4l nothing was published from the zero-point raw} [zval $r4i Z_ND] 0
eqcheck {R4m I3: the good database is STILL IN THE REGISTRY, untouched} \
  [zval $r4i Z_INFO] {2 current|0 G.raw op|1 S.raw tran|2 L.raw tran|}
eqcheck {R4n I3: it still has its point} [zval $r4i Z_SURV_PTS] 1
eqcheck {R4o I3: A NUMBER out of the survivor, not a non-NULL pointer} [zval $r4i Z_SURV_VAL] 3.14
eqcheck {R4p I3: and it can still publish} [zval $r4i Z_SURV_UOP] 1
eqcheck {R4q I3: with the right value} [zval $r4i Z_SURV_VA] 3.14
eqcheck {R4r I3: and the full 6 entries} [zval $r4i Z_SURV_ND] 6

# ===========================================================================
# ROW 5 -- THE REGISTERED-PATH TWIN, which is the shipped ASE/wave-viewer shape:
# a path is already registered, then ngspice rewrites that same path in place
# and it is annotated again.
#
# ⚠ THE LITERAL FORM OF THIS ROW IS VACUOUS, and row 5s below documents why.
# `xschem raw read <P> tran` + `xschem annotate_op <P>` hits the same-path dedup
# (save.c, the "file found: switch to it" arm), which NEVER OPENS THE FILE -- so
# the rewritten zero-point bytes on disk are never read and the row is green on a
# crashing tree. That is issue 0814. Row 5 proper breaks the dedup the way a real
# re-run does: with a DIFFERENT ANALYSIS at the same path, so the op leg really
# reads the rewritten file.
# ===========================================================================
set r5 [kid r5 {
  set P [file join $::TMP P.raw]
  mk_S $P                                   ;# P starts as a good 3-point tran
  puts "Z_N0_RC=[xschem raw read $P tran]"
  puts "Z_N0=[xschem raw points]"
  puts "Z_N0_VAL=[xschem raw value v(a) 0 0]"
  raw_write $P "Operating Point" 0 $::OPVARS {}   ;# ngspice re-runs: same path, 0 points
  catch {xschem annotate_op $P} ares
  puts "Z_PTS=[xschem raw points]"
  puts "Z_SIM=[xschem raw sim_type]"
  puts "Z_ND=[nd]"
  puts "Z_UOP=[xschem update_op]"
  puts "Z_INFO=[rinfo]"
  xschem raw switch 0                        ;# back to the good tran at the SAME path
  puts "Z_SURV_PTS=[xschem raw points]"
  puts "Z_SURV_VAL=[xschem raw value v(a) 0 0]"
  puts "Z_SURVIVED"
}]
check {R5a the registered-path twin survives a rewritten zero-point file} [survived $r5] [ctail $r5]
eqcheck {R5b PRECONDITION: P was a good 3-point database first} [zval $r5 Z_N0] 3
eqcheck {R5c PRECONDITION: with a real number in it} [zval $r5 Z_N0_VAL] 7.77
eqcheck {R5d the rewritten file WAS really read (dedup broken by sim_type)} [zval $r5 Z_PTS] 0
eqcheck {R5e and read as the operating point it now claims to be} [zval $r5 Z_SIM] op
eqcheck {R5f nothing was published from it} [zval $r5 Z_ND] 0
eqcheck {R5g update_op answers 0} [zval $r5 Z_UOP] 0
eqcheck {R5h I3: BOTH entries live -- same path, two analyses} \
  [zval $r5 Z_INFO] {1 current|0 P.raw tran|1 P.raw op|}
eqcheck {R5i I3: the good tran at that path still has its 3 points} [zval $r5 Z_SURV_PTS] 3
eqcheck {R5j I3: and still answers with a number} [zval $r5 Z_SURV_VAL] 7.77

# ===========================================================================
# ROW 5s -- THE LITERAL WORDING. ONE 0814 WITNESS, TWO 0856 WITNESSES.
# The tran leg finds <P>/"tran" already registered and serves the in-memory
# copy without opening the rewritten file, so this scenario says NOTHING about
# 0836 -- the zero-point guard is never reached, because the database that
# arrives is the cached 3-point one.
#
# ⚠ THE THREE ROWS BELOW NO LONGER WITNESS THE SAME THING, AND A LATER READER
# MUST NOT READ THE SPLIT AS A WEAKENING.
#   R5s1  is the 0814 witness, and now the ONLY one. It says the cached points
#         are served and the rewritten file is never opened. When 0814 lands
#         and the leg really reads, THIS row reds and has to be replaced by
#         row 5 proper.
#   R5s2  and R5s3 used to be 0814 witnesses too -- "so it still publishes",
#         "the PREVIOUS run's number, from memory". Issue 0856 took that away:
#         the copy being served is a TRANSIENT, and since the ruling only an
#         operating point publishes an operating point, so the point-0
#         publisher refuses it and nothing reaches the schematic. They are now
#         0856 gate witnesses, and they are gate-sensitive: delete the guard in
#         update_op() and they read `1` and `7.77` again.
#         When 0814 lands, R5s1 reds and these two do NOT -- a zero-point
#         transient is refused by the 0856 gate before it can reach the 0836
#         one. That is the expected shape, not a row that quietly stopped
#         measuring.
# ===========================================================================
set r5s [kid r5s {
  set Q [file join $::TMP Q.raw]
  mk_S $Q
  xschem raw read $Q tran
  raw_write $Q "Transient Analysis" 0 $::TRVARS {}   ;# same path, same analysis, 0 points
  catch {xschem annotate_op $Q} ares
  puts "Z_PTS=[xschem raw points]"
  puts "Z_UOP=[xschem update_op]"
  puts "Z_VA=[nv v(a)]"
  puts "Z_SURVIVED"
}]
check {R5s0 the literal registered-path row survives} [survived $r5s] [ctail $r5s]
eqcheck {R5s1 WITNESS(0814): the cached 3 points are served, file never opened} [zval $r5s Z_PTS] 3
eqcheck {R5s2 WITNESS(0856): the served copy is a TRANSIENT, so the point-0 publisher refuses it} [zval $r5s Z_UOP] 0
eqcheck {R5s3 WITNESS(0856): and NO number reaches the schematic -- not the previous run's, not a fabricated one} [zval $r5s Z_VA] {}

# ===========================================================================
# ROW 7 -- THE THIRD DOOR, found while fixing this and not in the issue's list.
# `xschem raw switch <n>` snapshots `Raw *raw = xctx->raw` BEFORE the switch and
# then gates update_op() on the OUTGOING database's allpoints, while update_op()
# reads the INCOMING one. So switching FROM a 1-point op database INTO a
# zero-point one calls update_op() on the zero-point database.
# ===========================================================================
set r7 [kid r7 {
  xschem raw read $::G op          ;# arr = [0 G op]         current 0
  xschem raw read $::Z op          ;# arr = [0 G op|1 Z op]  current 1
  puts "Z_SW0=[xschem raw switch 0]"
  puts "Z_CUR=[xschem raw points]"
  puts "Z_SW1=[xschem raw switch 1]"   ;# gate reads G (1 point), update_op reads Z (0)
  puts "Z_PTS=[xschem raw points]"
  puts "Z_ND=[nd]"
  puts "Z_SURVIVED"
}]
check {R7a raw switch INTO a zero-point database survives} [survived $r7] [ctail $r7]
eqcheck {R7b PRECONDITION: the switch really did land on the 1-point db first} [zval $r7 Z_CUR] 1
eqcheck {R7c PRECONDITION: and the second switch reported success} [zval $r7 Z_SW1] 1
eqcheck {R7d the current database is the zero-point one} [zval $r7 Z_PTS] 0
eqcheck {R7e and nothing was published from it} [zval $r7 Z_ND] 0

# ===========================================================================
# ROW 6 -- WHAT A ZERO-POINT DATABASE REPORTS ABOUT ITSELF. Decided AND RECORDED
# (0836 acceptance item 6), because "a database that crashes its only consumer
# must not report itself as usable".
#
# DECISION, under the NARROW ruling (guard the consumers; the read still
# attaches, so the wave viewer can still watch a running simulation fill):
#   `xschem raw points`  -> 0. This is THE discriminator. It is honest, it is
#       the field the guard itself keys on, and a caller can act on it.
#   `xschem raw loaded`  -> UNCHANGED: it keeps answering the hierarchy LEVEL at
#       which the database is attached (0 at top level), exactly as it does for
#       a good database. It is NOT a usability predicate and it never was --
#       sch_waves_loaded() asks "is a database attached at a schematic on my
#       hierarchy stack", and under the narrow ruling a zero-point database IS
#       attached. Making it answer -1 would be the WIDE ruling in disguise: the
#       same function gates graph drawing, so a running simulation's waveform
#       would stop rendering. That is the user's call, not this fix's.
# R6c is the row that stops the two being confused.
# ===========================================================================
set r6 [kid r6 {
  xschem raw read $::L tran
  puts "Z_Z_PTS=[xschem raw points]"
  puts "Z_Z_LOADED=[xschem raw loaded]"
  puts "Z_Z_SETS=[xschem raw datasets]"
  puts "Z_Z_NP0=[xschem raw points 0]"
  xschem raw clear
  xschem raw read $::G op
  puts "Z_G_PTS=[xschem raw points]"
  puts "Z_G_LOADED=[xschem raw loaded]"
  puts "Z_SURVIVED"
}]
check {R6a the reporting row survives} [survived $r6] [ctail $r6]
eqcheck {R6b RECORDED: raw points answers 0 for a zero-point database} [zval $r6 Z_Z_PTS] 0
eqcheck {R6c RECORDED: raw loaded answers the ATTACH LEVEL, same as a good db} \
  [zval $r6 Z_Z_LOADED] [zval $r6 Z_G_LOADED]
eqcheck {R6d so raw loaded is NOT the usability test -- raw points is} \
  [expr {[zval $r6 Z_G_PTS] ne [zval $r6 Z_Z_PTS] ? {discriminates} : {blind}}] {discriminates}
eqcheck {R6e the dataset really was counted (the db is attached, not discarded)} [zval $r6 Z_Z_SETS] 1
eqcheck {R6f and its per-dataset count agrees with allpoints} [zval $r6 Z_Z_NP0] 0

# ===========================================================================
# ROW 8 -- SCOPE, ASSERTED. This suite's guard is update_op()-local BY RULING
# (the narrow option of 0836's open question, taken because no user ruling had
# arrived), so it does NOT close every zero-point dereference in the tree. This
# row tracks the OTHER route into the same input.
#
# HISTORY, AND WHY THIS ROW READS THE WAY IT DOES. It shipped with 0836 as a
# CRASH ASSERTION -- the only such row here -- because `xschem raw pos_at` on a
# zero-point database still SIGSEGVed by a different route: raw_get_pos()
# clamped to `lastpoint = npoints[dset] - 1`, i.e. -1, and get_raw_value()
# bounded `point` from ABOVE only, so `ofs + point < allpoints` was `-1 < 0`,
# true, and it dereferenced values[idx][-1] on a NULL column. It was written to
# go RED the moment the sibling was fixed, precisely so the conversion could not
# be forgotten. Issue 0852 fixed it, and this is that conversion: the row now
# asserts SURVIVAL, which is what it was always going to have to say.
#
# It stays HERE, in 0836's suite, rather than moving wholesale to 0852's: the
# two issues share one input and one fixture, and this row is the seam. Its full
# acceptance -- the positive twin, the falling-signal direction, the windowed
# search, the viewer's own readout sequence -- lives in
# tests/headless/test_zero_point_pos_at_0852.tcl.
# ===========================================================================
set r8 [kid r8 {
  xschem raw read $::Z op
  puts "Z_PTS=[xschem raw points]"
  puts "Z_POS=[xschem raw pos_at v(a) 1.0]"
  puts "Z_SURVIVED"
}]
eqcheck {R8a PRECONDITION: the sibling fixture is the same zero-point database} [zval $r8 Z_PTS] 0
check {R8b raw pos_at SURVIVES a zero-point database (issue 0852, was a crash)} \
  [survived $r8] [ctail $r8]
eqcheck {R8c and it answers "not found", not a fabricated index} [zval $r8 Z_POS] -1

catch {test_scratch_drop $tmp}
puts "----"
puts "test_zero_point_raw_0836: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; flush stdout; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; flush stdout; exit 1 }
