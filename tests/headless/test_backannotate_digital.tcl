# SPEC D5 of doc/claude/specs/mixed_signal_signal_browser.md --
# WHAT A DIGITAL DATABASE CONTRIBUTES TO BACKANNOTATION: NOTHING, EXPLICITLY.
#
# Backannotation puts OPERATING POINT values on the schematic: node voltages
# and device currents, read out of `ngspice::ngspice_data` by ngspice::get_voltage
# / get_current / get_node (src/xschem.tcl) and by every floater. A VCD carries
# logic levels over time. A logic level is not a voltage -- `1` is not 1.8 V, it
# is `1`, and vcd_read() encodes X as 0.5 and Z as 0.3 -- so a digital database
# has nothing to contribute and must contribute nothing.
#
# The three enforcement points (RULING D5-3), one group of checks each:
#   BA1*  the PREDICATE. raw_type_is_digital() off the reader table's `digital`
#         column, exposed as `xschem raw is_digital` -- ONE answer, so a future
#         database type inherits the ruling instead of re-deriving it.
#   BA2*  `xschem annotate_op <f> <lvl> vcd` is REFUSED, before it loads
#         anything, with a sentence that says why.
#   BA3*  `xschem update_op` (the point-0 publisher, which every annotate path
#         funnels through) publishes nothing and leaves the array UNSET.
#   BA4*  the CURSOR-B publisher: with a digital database current, nobody
#         publishes and the array is cleared -- never a stale overlay, never a
#         substituted database.
#   BA5*  THE INVARIANT, and the check that matters: an analog raw and a VCD
#         that SHARE A NODE NAME. Annotate with the analog alone; load the VCD;
#         annotate again; every annotated value must be byte-identical. A
#         non-colliding fixture passes against a broken implementation, which
#         is why the fixture collides on purpose.
#   BA6*  D5 does NOT undo D4: the digital database's own per-`Raw` cursor
#         state is still stamped, so the viewer's readout bar still reads it.
#         The ruling is about the SCHEMATIC, not the waveform window.
#
# True headless: run under --nogui.
#   ./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_backannotate_digital.tcl

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
# ⚠ Every numeric comparison in this file goes through these two, NEVER through a
# bare `expr {$v - 0.75}`. Under sabotage the value under test is routinely the
# empty string or `<unset>`, and `expr` THROWS on those -- which aborts the whole
# file at the first broken check instead of reddening it, so the twenty checks
# after it read as "did not run" rather than "failed". Measured: sabotages
# S14/S16/S18 originally scored 1-2 red and ~20 "passed" for exactly that reason.
proc inband {name got lo hi} {
  if {[string is double -strict $got] && $got > $lo && $got < $hi} {
    check $name in-$lo..$hi in-$lo..$hi
  } else {
    check $name "$got" "a number in $lo..$hi"
  }
}
proc nearv {name got exp {tol 1e-6}} {
  if {[string is double -strict $got] && abs($got - $exp) <= $tol} {
    check $name near-$exp near-$exp
  } else {
    check $name "$got" "within $tol of $exp"
  }
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
source [file join $here scratch.tcl]
set scratch [test_scratch badig]
set ::XSCHEM_LIBRARY_PATH {}

proc wr {p s} { set fp [open $p w]; puts -nonewline $fp $s; close $fp }

# ---------------------------------------------------------------------------
# THE FIXTURE. Two databases that COLLIDE on a node name.
#
#   coll.raw   analog, dense, 0 .. 2 us. Vectors:
#                top.m.same  0.75 -> 0.79   <-- a real voltage
#                v(anlg)     0.25 -> 0.29
#   coll.vcd   digital, sparse, 0 .. 200 ns. Signal:
#                top.m.same  logic 0 / 1    <-- THE SAME STORED NAME
#
# `top.m.same` is a legal vector name in a spice raw (ngspice writes hierarchical
# names with dots) and the natural name for `$scope module top / module m /
# $var wire 1 ! same` in a VCD, so the collision is the real shape.
#
# ⚠ THE CASE TRAP, and why the VCD scopes here are lower case. EVERY reader
# now stores variable names VERBATIM -- read_dataset() folded spice names until
# the casemode batch deleted that fold (item 1, doc/claude/specs/
# raw_case_mode.md), vcd_read() and table_read() never folded at all. So the
# stored spelling is whatever the file says: an UPPER-case VCD scope produces
# "TOP.m.same" against a raw's "top.m.same" -- two different keys in
# ngspice::ngspice_data, i.e. NO collision, and the whole colliding-name leg
# would be green against an implementation that merges the two namespaces.
# `xschem raw index` hides this: its ladder is exact, then a case-folded match
# against the stored names, then the same two v()-wrapped (casemode item 2), so
# either spelling resolves. The collision is therefore asserted against
# `xschem raw list`, the STORED names, at BA1d.
#
# Every value band is disjoint from every logic level, so a readout says WHICH
# database answered rather than merely "something did".
# ---------------------------------------------------------------------------
proc mkraw {path names lo hi t0 tmax {n 41}} {
  set nv [expr {[llength $names] + 1}]
  set body "Title: d5\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: $nv\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n"
  set k 1
  foreach nm $names { append body "\t$k\t$nm\tvoltage\n"; incr k }
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$t0 + $i * ($tmax - $t0) / ($n - 1)}]
    append body "$i\t$t\n"
    set j 0
    foreach nm $names {
      append body "\t[expr {[lindex $lo $j] + ([lindex $hi $j] - [lindex $lo $j]) * $i / ($n - 1)}]\n"
      incr j
    }
    append body "\n"
  }
  wr $path $body
}

# 1-bit VCD signals on a NANOSECOND time base. `sigs` is a LIST of signal names,
# all driven by the same `events` (a flat list {tick value ...}); `endtick` is the
# trailing bare `#t`. A one-element list is the single-signal case.
#
# ⚠ MORE THAN ONE SIGNAL IS LOAD-BEARING, not decoration. With only the colliding
# name in the VCD, the fixture can only ask "does a digital value OVERWRITE an
# analog one?" -- it cannot ask "does a digital name the analog database has never
# heard of turn up on the schematic at all?", which is the other half of
# "contributes NOTHING". Measured: an additive-merge implementation (publish the
# entry database, then merge any name a later digital database has that the array
# lacks) put `top.m.donly = 1` on the schematic as a volt and scored 56/56 on the
# fixture that had only the colliding name.
# a 1-POINT OPERATING POINT raw -- the shape annotate_op's "delete previously
# loaded OP" branch fires on, and therefore the shape in which an unrefused
# digital annotate costs the user their registry as well as their annotation.
proc mkop {path names vals} {
  set nv [expr {[llength $names] + 1}]
  set body "Title: d5op\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Operating Point\n"
  append body "Flags: real\nNo. Variables: $nv\nNo. Points: 1\nVariables:\n"
  append body "\t0\ttime\ttime\n"
  set k 1
  foreach nm $names { append body "\t$k\t$nm\tvoltage\n"; incr k }
  append body "Values:\n0\t0\n"
  foreach v $vals { append body "\t$v\n" }
  append body "\n"
  wr $path $body
}

proc mkvcd {path scope sigs events endtick} {
  set ids {! & + ~}
  set body "\$timescale 1ns \$end
\$scope module top \$end
 \$scope module $scope \$end
"
  set k 0
  foreach s $sigs { append body "  \$var wire 1 [lindex $ids $k] $s \$end\n"; incr k }
  append body " \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
"
  foreach {tick val} $events {
    append body "#$tick\n"
    set k 0
    foreach s $sigs { append body "$val[lindex $ids $k]\n"; incr k }
  }
  append body "#$endtick\n"
  wr $path $body
}

# the backannotation array as a SORTED {name value name value ...} list -- the
# thing the schematic overlay actually reads, compared as a whole string so a
# single changed digit fails.
proc annot_snapshot {} {
  set out {}
  foreach n [lsort [array names ::ngspice::ngspice_data]] {
    lappend out $n $::ngspice::ngspice_data($n)
  }
  return $out
}
proc annot_names {} { return [lsort [array names ::ngspice::ngspice_data]] }
proc annot_get {n} {
  if {[catch {set ::ngspice::ngspice_data($n)} r]} { return {<unset>} }
  return $r
}
# what the SCHEMATIC would print for node `n`: `?` when nothing is annotated.
# It reads the array the same way the overlay does, with the same fallback.
# (Item 5b deleted ngspice::get_voltage's `string tolower` -- it now hands the
# schematic's own spelling to the one lookup authority. These fixtures are all
# lowercase, so the reads here are byte-identical either way; the case behaviour
# itself is test_ngspice_data_view.tcl's CS97*.)
proc overlay_reads {n} { return [ngspice::get_voltage $n] }

proc xc_cursor {t} { xschem set cursor2_x $t }

if {[catch {

set collraw [file join $scratch coll.raw]
set collvcd [file join $scratch coll.vcd]
set plainvcd [file join $scratch plain.vcd]
set xvcd [file join $scratch unknown.vcd]
set opraw [file join $scratch op.raw]
mkraw $collraw {top.m.same v(anlg)} {0.75 0.25} {0.79 0.29} 0.0 2.0e-6
mkop $opraw {top.m.same v(anlg)} {0.75 0.25}
# 0 -> 1 at 50 ns, 1 -> 0 at 100 ns, 0 -> 1 at 150 ns, run ends at 200 ns.
# TWO signals: `same` COLLIDES with the raw's vector, `donly` exists in the
# digital database ALONE and the analog raw has never heard of it.
mkvcd $collvcd  m {same donly}  {0 0 50 1 100 0 150 1} 200
mkvcd $plainvcd m dsig  {0 0 50 1 100 0 150 1} 200
# a VCD that drives the colliding name to X. vcd_read() encodes X as 0.5
# (VCD_VX) -- a number that looks EXACTLY like a plausible node voltage, which is
# why the floater checks aim at it rather than at the tidier 1/0.
mkvcd $xvcd     m same  {0 x} 200
set SAME top.m.same
set DONLY top.m.donly

# ===========================================================================
# BA1 -- RULING D5-2: ONE predicate, off the reader table
# ===========================================================================
check "BA10 a spice transient database is not digital" \
  [pcall {xschem raw is_digital tran}] 0
check "BA11 a vcd IS digital" [pcall {xschem raw is_digital vcd}] 1
check "BA12 an ascii TABLE is not: it is columns of real numbers, an analog\
 result by another reader -- the ruling is about logic levels, not about\
 'anything that is not a spice raw'" [pcall {xschem raw is_digital table}] 0
check "BA13 an unknown type token is not digital" [pcall {xschem raw is_digital nosuch}] 0
check "BA14 op/dc/ac are not digital" \
  [pcall {list [xschem raw is_digital op] [xschem raw is_digital dc] \
               [xschem raw is_digital ac]}] {0 0 0}

xschem raw clear
check "BA15 with NOTHING loaded the current database is not digital: 'nothing\
 is loaded' is not 'a digital thing is loaded'" [pcall {xschem raw is_digital}] 0
check "BA16 the analog raw reads (slot 0)" [pcall {xschem raw read $collraw tran}] 1
check "BA17 ...and the CURRENT database answers not-digital" [pcall {xschem raw is_digital}] 0
check "BA18 the colliding VCD reads (slot 1) and `raw read` makes it CURRENT --\
 this is the premise of the whole cursor leg" \
  [pcall {list [xschem raw read $collvcd vcd] [xschem raw sim_type]}] {1 vcd}
check "BA19 ...and NOW the current database answers digital" [pcall {xschem raw is_digital}] 1

# THE COLLISION IS REAL, asserted rather than assumed: the same name resolves in
# BOTH databases, to values from disjoint bands.
check_true "BA1a the name $SAME is in the DIGITAL database" \
  [expr {[xschem raw index $SAME] >= 0}]
xschem raw switch 0
check_true "BA1b ...and in the ANALOG one too -- the fixture collides" \
  [expr {[xschem raw index $SAME] >= 0}]
inband "BA1c ...and the analog value is a VOLTAGE (0.75..0.79), nowhere near a\
 logic level, so a wrong answer cannot look like a right one" \
  [pcall {xschem raw value $SAME 0}] 0.7 0.8
# ...and the collision is at the STORED name, not merely at get_raw_index()'s
# case-folding probe. `raw list` is what ngspice::ngspice_data would be keyed
# by, so this is the check that the fixture is really a collision (item 7's
# lesson: a name that collides in one namespace and not the other is a fixture
# that proves nothing).
set ba_anames [split [xschem raw list] "\n"]
xschem raw switch 1
set ba_dnames [split [xschem raw list] "\n"]
xschem raw switch 0
check_true "BA1d THE FIXTURE IS REALLY A COLLISION: the two databases store the\
 SAME name, byte for byte (raws are lower-cased, VCD names are verbatim)" \
  [expr {[lsearch -exact $ba_anames $SAME] >= 0 && [lsearch -exact $ba_dnames $SAME] >= 0}]

# ===========================================================================
# BA2 -- RULING D5-3 point 2: `annotate_op` on a digital database is REFUSED
# ===========================================================================
xschem raw clear
xschem raw read $collraw tran
set ba_before_reg [llength [lrange [split [xschem raw info] "\n"] 1 end-1]]
set ba_msg [pcall {xschem annotate_op $collvcd 0 vcd}]
# ⚠ BOTH halves in one assertion, deliberately. The name alone is NOT evidence:
# the arm runs `tcleval("regsub …")` on argv[2], so with the refusal removed the
# Tcl result is the file path itself and a "does the answer mention the file?"
# check is green against no refusal at all (measured: sabotages S1/S2/S4 all left
# a name-only BA20 passing).
check_true "BA20 the request is REFUSED, in a sentence that names the database" \
  [expr {[string match -nocase {*is a digital results database*} $ba_msg] &&
         [string first [file tail $collvcd] $ba_msg] >= 0}]
check_true "BA21 ...and says WHY: it is digital, it carries logic levels, there\
 is no operating point in it" \
  [expr {[string match -nocase {*digital*} $ba_msg] &&
         [string match -nocase {*logic level*} $ba_msg] &&
         [string match -nocase {*operating point*} $ba_msg]}]
check "BA22 ...BEFORE any side effect: the registry is untouched, the VCD was\
 not loaded" [llength [lrange [split [xschem raw info] "\n"] 1 end-1]] $ba_before_reg
check "BA23 ...and the analog database is still the current one" \
  [pcall {xschem raw sim_type}] tran
check_true "BA24 ...and no VCD name was annotated" \
  [expr {[lsearch -exact [annot_names] $SAME] < 0}]

# the SAME call on the analog raw is NOT refused -- the control, without which
# BA20-BA24 would pass against an annotate_op that refuses everything
set ba_ok [pcall {xschem annotate_op $collraw 0 tran}]
check_true "BA25 THE CONTROL: the same command on an ANALOG raw is not refused" \
  [expr {![string match -nocase {*is a digital results database*} $ba_ok]}]
nearv "BA26 ...and it really annotated: the analog vector is in the array at\
 its point-0 voltage" [annot_get $SAME] 0.75

# THE SPELLING THE GUI ACTUALLY USES (RULING D5-6). Both Op Annotate menu entries
# in src/xschem.tcl call `xschem annotate_op $tctx::retval` -- a FILENAME ALONE,
# no type token -- and select_raw's dialog offers an `All Files *` filter, so
# pointing Op Annotate at a .vcd is two clicks. A refusal that keys only on the
# 4th argument never fires for them: the op/dc/tran fallbacks each fail on a VCD
# and the user gets silence AFTER the array has been unset and the previously
# loaded OP deleted from the registry. So the refusal asks the FILE too.
#
# ⚠ AND THE STANDING DATABASE IS A 1-POINT OP, deliberately. annotate_op's
# "delete previously loaded OP" branch (`extra_rawfile(3, …)`) only fires when
# the current database is a 1-point op/dc, and it fires BEFORE the load -- so
# that is the shape in which an unrefused VCD costs the user the REGISTRY and not
# just the array. With a `tran` database standing instead, BA29 passes against no
# sniff at all (measured: sabotage S22 left it green until this line changed).
xschem raw clear
xschem annotate_op $opraw 0 op
set ba_u_before [annot_snapshot]
set ba_u_reg [llength [lrange [split [xschem raw info] "\n"] 1 end-1]]
check_true "BA2z premise: a 1-point OP database is annotated and current, so\
 annotate_op's delete-previous-OP branch is live" \
  [expr {$ba_u_reg == 1 && [xschem raw sim_type] eq "op" &&
         [lsearch -exact [annot_names] $SAME] >= 0}]
set ba_umsg [pcall {xschem annotate_op $collvcd}]
check_true "BA27 `xschem annotate_op <f>.vcd` with NO type token -- the spelling\
 both GUI call sites use -- is refused, by asking the file what it is" \
  [expr {[string match -nocase {*is a digital results database*} $ba_umsg] &&
         [string first [file tail $collvcd] $ba_umsg] >= 0}]
check "BA28 ...and it did not wipe the annotation on its way to saying nothing" \
  [annot_snapshot] $ba_u_before
check "BA29 ...and did not delete the loaded OP database from the registry on\
 its way to saying nothing: the refusal precedes every side effect" \
  [llength [lrange [split [xschem raw info] "\n"] 1 end-1]] $ba_u_reg
check "BA2b ...so the OP database is still the current one and still loaded" \
  [pcall {list [xschem raw sim_type] [expr {[xschem raw loaded] >= 0}]}] {op 1}
check_true "BA2a THE CONTROL for the sniff: an untyped annotate_op on the ANALOG\
 raw is still not refused, so BA27 is about the file's content and not about\
 'an untyped annotate_op'" \
  [expr {![string match -nocase {*is a digital results database*} \
            [pcall {xschem annotate_op $collraw}]]}]

# ===========================================================================
# BA3 -- RULING D5-3 point 1: update_op(), the point-0 publisher
# ===========================================================================
# the array is left carrying the analog annotation from BA26. Switching to the
# VCD and asking to publish must EMPTY it, not overwrite it and not keep it.
xschem raw clear
xschem raw read $collraw tran
xschem raw read $collvcd vcd
xschem raw switch 0
check "BA30 premise: publishing from the ANALOG database answers 1" \
  [pcall {xschem update_op}] 1
nearv "BA31 ...and the analog voltage is on the schematic" [annot_get $SAME] 0.75
xschem raw switch 1
check "BA32 publishing from the DIGITAL database answers 0: nothing published" \
  [pcall {xschem update_op}] 0
check "BA33 ...and it did NOT publish the logic level under the colliding name" \
  [annot_get $SAME] {<unset>}
check "BA34 ...and it did not leave the previous database's numbers standing\
 either: a stale voltage on a schematic is the one outcome worse than none" \
  [annot_names] {}
check "BA35 ...so the schematic overlay reads '?', which is how it already says\
 'no data', rather than a fabricated volt" [overlay_reads $SAME] {?}
xschem raw switch 0
xschem update_op
nearv "BA36 switching back to the analog database and publishing restores the\
 real voltage: the refusal is not a latch" [annot_get $SAME] 0.75

# ===========================================================================
# BA4 -- RULING D5-3 point 3: the CURSOR-B publisher
# ===========================================================================
# A graph rect with a cross-DB `%` entry naming EACH database EXPLICITLY, so
# both are in the cursor fan-out (RULING D4-1) whichever one is current.
#
# ⚠ The explicit `%$collraw tran` entry is load-bearing and was added after
# measurement. With only `v(anlg)` (an own-database entry) plus the VCD's `%`,
# the fan-out with the VCD current is {the VCD} alone -- the strip's own
# database IS the current one -- so "no substitute publisher" (BA4b) had no
# analog candidate to substitute and was green against an implementation that
# promotes one (sabotage S7 reddened NOTHING before this line existed).
xschem clear force
# THE FLOATER, on the same schematic. lab_pin.sym is the standard net-label
# symbol and its entire T record is literally `T {@spice_get_voltage}` -- so this
# instance IS the schematic voltage overlay's other road (RULING D5-5), the one
# that reads xctx->raw->cursor_b_val[] in src/token.c instead of going through
# ngspice::ngspice_data. `xschem translate <inst> {@spice_get_voltage}` is
# byte-for-byte the expansion draw.c performs to render it.
xschem instance [file join $::XSCHEM_SHAREDIR .. xschem_library devices lab_pin.sym] \
  0 0 0 0 "name=lsame lab=$SAME"
set LSAME lsame
proc floater {} { return [pcall {xschem translate $::LSAME {@spice_get_voltage}}] }
set Q  "\\\"dig;$SAME%$collvcd vcd\\\""
set QD "\\\"don;$DONLY%$collvcd vcd\\\""
set QA "\\\"anl;v(anlg)%$collraw tran\\\""
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem setprop rect 2 0 node "v(anlg)\n$Q\n$QD\n$QA"
foreach {t v} [list x1 0 x2 3e-6 y1 -0.3 y2 1.3] { xschem setprop rect 2 0 $t $v }
xschem setprop rect 2 0 fullyzoom
xschem cursor 2 1
check_true "BA40 premise: cursor B is enabled (graph_flags bit 4)" \
  [expr {[xschem get graph_flags] & 4}]

xschem raw clear
check "BA41 premise: the analog raw is slot 0" [pcall {xschem raw read $collraw tran}] 1
check "BA42 premise: the colliding VCD is slot 1" [pcall {xschem raw read $collvcd vcd}] 1
xschem raw switch 0
xc_cursor 175e-9
set ba_anlg_snapshot [annot_snapshot]
inband "BA43 with the ANALOG database current the cursor publishes it, as it\
 always has (RULING D4-2 unchanged)" [annot_get $SAME] 0.7 0.8
check_true "BA44 ...and the VCD's logic level is NOT what the schematic shows,\
 even though the VCD contributes a trace to this very strip" \
  [expr {[string is double -strict [annot_get $SAME]] &&
         abs([annot_get $SAME] - 1.0) > 0.1 && abs([annot_get $SAME] - 0.0) > 0.1}]

# NOW the shape that was live before D5: `raw read` leaves the VCD current, so
# the very next cursor motion had the VCD publishing its logic levels.
xschem raw switch 1
check "BA45 premise: the DIGITAL database is the current one" [pcall {xschem raw sim_type}] vcd
xc_cursor 175e-9
check "BA46 THE DEFECT: a cursor motion with a digital database current\
 publishes NOTHING -- not the logic level under the colliding name" \
  [annot_get $SAME] {<unset>}
check "BA47 ...and not the digital database's names at all" [annot_names] {}
check "BA48 ...and not the analog database's previous numbers, held over from\
 the last position: the array is cleared, not left standing" \
  [annot_snapshot] {}
check "BA49 ...so the overlay reads '?'" [overlay_reads $SAME] {?}

# and it is not a latch: back to the analog database, the overlay comes back
xschem raw switch 0
xc_cursor 175e-9
check "BA4a switching back to the analog database and moving the cursor\
 restores the whole annotation, byte for byte" [annot_snapshot] $ba_anlg_snapshot

# NO OTHER DATABASE IS PROMOTED INTO THE PUBLISHER'S PLACE. With the VCD current
# the analog raw is still in the fan-out (it is the strip's own database), and
# if it were allowed to publish the overlay would follow a database the user did
# not make current -- so which values the schematic shows would depend on
# registry order.
xschem raw switch 1
xc_cursor 500e-9
check "BA4b no substitute publisher: the analog database in the fan-out does\
 NOT take over the array" [annot_names] {}
# THE PREMISE BA4b RESTS ON, asserted rather than assumed: the analog database
# really is in the fan-out at that moment -- it followed the cursor to 500 ns
# under its own per-Raw state while the digital one was current. Without this,
# "no substitute publisher" is a claim about a candidate that is not there.
xschem raw switch 0
check "BA4c ...and the analog database WAS in the fan-out at that moment: it\
 followed the cursor to 500 ns, it simply did not publish" \
  [lindex [xschem raw annot] 1] 5e-07

# ===========================================================================
# BA5 -- THE INVARIANT: the presence of a VCD changes NO annotated value
# ===========================================================================
# Annotate with the analog raw ALONE, snapshot the whole array; then load the
# colliding VCD and annotate again from the same cursor position; the two
# snapshots must be equal as strings.
xschem raw clear
xschem raw read $collraw tran
xschem raw switch 0
xc_cursor 175e-9
set ba_alone [annot_snapshot]
check_true "BA50 premise: with the analog raw ALONE the array is non-empty and\
 carries the colliding name, so the comparison below has something to compare" \
  [expr {[llength $ba_alone] > 0 && [lsearch -exact [annot_names] $SAME] >= 0}]

check "BA51 the colliding VCD loads as a second database" \
  [pcall {xschem raw read $collvcd vcd}] 1
xschem raw switch 0
xc_cursor 175e-9
check "BA52 THE INVARIANT: with the VCD loaded and contributing a trace to this\
 strip, every annotated value is byte-identical to the analog-only run" \
  [annot_snapshot] $ba_alone

# THE OTHER HALF OF "CONTRIBUTES NOTHING", and the half a colliding-name-only
# fixture cannot ask. BA52 pins "a digital value does not OVERWRITE an analog
# one". It says nothing about a digital name the analog database has never heard
# of -- and an additive-merge implementation (publish the entry database, then
# fill in any name a later digital database has that the array lacks) overwrites
# nothing, so it passes BA52, BA53, BA54 and BA55 while putting `top.m.donly = 1`
# on the schematic as a volt. Measured: that implementation scored 56/56 before
# these checks existed.
# BA56 is a FIXTURE PREMISE and carries no evidence about D5 (no sabotage reaches
# it: it asserts a property of the two files this file writes). Its job is to
# fail loudly the day the fixture stops being a fixture, the same role as BA40.
check_true "BA56 premise: $DONLY exists in the DIGITAL database and NOWHERE in\
 the analog one, so anything that annotates it can only have got it from the VCD" \
  [expr {[lsearch -exact [split [xschem raw list] "\n"] $DONLY] < 0}]
xschem raw switch 1
check_true "BA57 ...and the digital database really carries it AND really\
 followed the cursor, i.e. it is in the fan-out at this moment -- without which\
 BA58 is a claim about an absent contributor" \
  [expr {[lsearch -exact [split [xschem raw list] "\n"] $DONLY] >= 0 &&
         [lindex [xschem raw annot] 0] >= 0}]
xschem raw switch 0
check_true "BA58 A DIGITAL-ONLY NAME NEVER REACHES THE ARRAY: with the ANALOG\
 database current, $DONLY is not annotated -- a digital database contributes\
 nothing, not merely 'nothing that overwrites something'" \
  [expr {[lsearch -exact [annot_names] $DONLY] < 0}]
check "BA59 ...so the schematic reads '?' for it, not a logic level dressed as a\
 volt" [overlay_reads $DONLY] {?}
xschem update_op
# BA5a is WEAK BY CONSTRUCTION and labelled so: update_op() reads exactly ONE
# database (xctx->raw) by construction, so no sabotage short of rewriting it into
# a registry walk can make a digital-only name appear in its output. It is here
# because "the other publisher was asked too" is worth stating; BA58/BA59 carry
# this invariant's real evidence (sabotage S24, the additive merge).
check_true "BA5a ...and the same through `update_op`, which is a different\
 publisher and had to be asked separately" \
  [expr {[lsearch -exact [annot_names] $DONLY] < 0}]
xc_cursor 175e-9

# the same invariant across the OTHER two request paths
xschem raw switch 0
xschem update_op
set ba_upd_with [annot_snapshot]
xschem raw clear
xschem raw read $collraw tran
xschem update_op
check "BA53 ...and the same holds for `update_op`: the VCD's presence changes\
 nothing it publishes" [annot_snapshot] $ba_upd_with

xschem raw clear
xschem annotate_op $collraw 0 tran
set ba_ann_alone [annot_snapshot]
xschem raw read $collvcd vcd
xschem raw switch 0
xschem annotate_op $collraw 0 tran
check "BA54 ...and for `annotate_op`" [annot_snapshot] $ba_ann_alone

# A NON-COLLIDING VCD is the control that shows BA52 is about the collision and
# not about "any second database": this one would pass against a broken
# implementation, and is here to prove the collision fixture is the load-bearing
# one rather than to carry evidence itself.
xschem raw clear
xschem raw read $collraw tran
xc_cursor 175e-9
set ba_nc_alone [annot_snapshot]
xschem raw read $plainvcd vcd
xschem raw switch 0
xc_cursor 175e-9
check "BA55 THE WEAK CONTROL (passes against a broken implementation, and is\
 labelled so): a NON-colliding VCD also changes nothing" \
  [annot_snapshot] $ba_nc_alone

# ===========================================================================
# BA6 -- D5 does NOT undo D4: the waveform window still reads the digital trace
# ===========================================================================
xschem raw clear
xschem raw read $collraw tran
xschem raw read $collvcd vcd
xschem raw switch 0
xc_cursor 175e-9
xschem raw switch 1
check_true "BA60 the DIGITAL database still followed the cursor: its own\
 per-Raw annotation index is set (D4-1 is untouched by D5)" \
  [expr {[lindex [xschem raw annot] 0] >= 0}]
check "BA61 ...at the cursor's t" [lindex [xschem raw annot] 1] 1.75e-07
nearv "BA62 ...and its cursor value is the logic level its last event set (1,\
 from the 150 ns event) -- the readout BAR still reads it; D5 is about the\
 SCHEMATIC, not the viewer" [pcall {xschem raw value $SAME {}}] 1.0
xschem raw switch 0
inband "BA63 ...while the schematic overlay, at that same moment, shows the\
 ANALOG voltage for that same name" [annot_get $SAME] 0.7 0.8

# ===========================================================================
# BA7 -- ONLY a digital database is loaded
# ===========================================================================
xschem raw clear
check "BA70 only the VCD is loaded, and it is current" \
  [pcall {list [xschem raw read $collvcd vcd] [xschem raw sim_type]}] {1 vcd}
xc_cursor 175e-9
check "BA71 a cursor motion annotates nothing at all" [annot_names] {}
check "BA72 `update_op` answers 0 and annotates nothing" \
  [pcall {list [xschem update_op] [annot_names]}] {0 {}}
check_true "BA73 `annotate_op` on it is refused, and SAYS SO rather than\
 leaving the user with a silently empty schematic" \
  [expr {[string match -nocase {*is a digital results database*} \
           [pcall {xschem annotate_op $collvcd 0 vcd}]]}]
check "BA74 ...and the whole schematic overlay reads '?'" \
  [pcall {list [overlay_reads $SAME] [overlay_reads v(anlg)]}] {? ?}

# ===========================================================================
# BA8 -- RULING D5-5: THE `@spice_get_*` FLOATERS ARE THE OVERLAY TOO
# ===========================================================================
# ngspice::ngspice_data is not the only road onto the schematic. translate() and
# get_pin_attr() in src/token.c expand @spice_get_voltage & friends by reading
# xctx->raw->cursor_b_val[] out of the CURRENT database directly, and draw.c
# expands exactly those tokens to render the text lab_pin/ipin/opin/iopin/vdd/
# ngspice_probe/scope carry. Enforcing D5 only on the Tcl array left this road
# open: with a VCD current the schematic printed the logic level as a voltage.
xschem raw clear
xschem raw read $collraw tran
xschem raw read $collvcd vcd
xschem raw switch 0
xc_cursor 175e-9
inband "BA80 THE CONTROL: with the ANALOG database current the floater renders\
 the measured voltage -- without this, every check below is green against a\
 floater that renders nothing ever" [floater] 0.7 0.8
set ba_flo_analog [floater]

xschem raw switch 1
xc_cursor 175e-9
check_true "BA81 with the DIGITAL database current the floater renders NO\
 number: not the logic level (1) the VCD holds for that same name" \
  [expr {![string is double -strict [floater]]}]
check "BA82 ...it renders exactly what a session with live backannotation\
 switched off renders -- nothing. 'Contributes nothing' is not 'contributes a\
 placeholder'" [floater] {}

# and the value that matters most, because it looks like a volt: X -> 0.5
xschem raw clear
check "BA83 premise: a VCD driving the colliding name to X loads, and its\
 stored value really is vcd_read()'s 0.5 encoding for UNKNOWN" \
  [pcall {list [xschem raw read $xvcd vcd] [xschem raw sim_type]}] {1 vcd}
xc_cursor 175e-9
nearv "BA84 ...confirmed at the cursor: the digital database itself holds 0.5\
 there (D4's per-Raw state, untouched)" [pcall {xschem raw value $SAME {}}] 0.5
check "BA85 THE FABRICATED VOLT: the floater does not print 0.5 on a net whose\
 value is UNKNOWN -- the number RULING D5-1 is written to forbid, and the one\
 that is indistinguishable from a measurement" [floater] {}

xschem raw clear
xschem raw read $collraw tran
xc_cursor 175e-9
check "BA86 ...and the floater is not latched off: the analog database renders\
 the same measured voltage it did before" [floater] $ba_flo_analog

# ⚠ BA80-BA86 exercise ONE of the six branches -- translate()'s bare
# @spice_get_voltage, the one lab_pin.sym carries. The other five
# (@spice_get_voltage(...), @spice_get_diff_voltage, @spice_get_current,
# @spice_get_modelparam, and get_pin_attr()'s @#<pin>:spice_get_voltage) need a
# wired multi-pin instance and a device-current vector to reach behaviourally,
# and MEASURED: reverting the guard at the get_pin_attr() site alone reddens
# NOTHING above. So the remaining five are pinned by a source witness, declared
# as the weaker form of evidence it is: every site that reads
# live_cursor2_backannotate to gate a cursor_b_val[] read must carry the D5 term.
set ba_tf [open [file join $here .. .. src token.c] r]
set ba_tl [split [read $ba_tf] "\n"]
close $ba_tf
set ba_live 0; set ba_guarded 0
foreach ba_l $ba_tl {
  set ba_t [string trimleft $ba_l]
  if {[string index $ba_t 0] eq "*" || [string range $ba_t 0 1] eq "/*"} { continue }
  if {[string first "int live = tclgetboolvar" $ba_l] >= 0} {
    incr ba_live
    if {[string first "raw_is_digital" $ba_l] >= 0} { incr ba_guarded }
  }
}
check "BA87 SOURCE WITNESS: every one of token.c's live-backannotation gates\
 carries the D5 term -- all six branches, not just the one the fixture can\
 reach" [list [expr {$ba_live == 6}] [expr {$ba_guarded == $ba_live}]] {1 1}

# ===========================================================================
# BA9 -- RULING D5-7: `xschem raw switch` deliberately does NOT touch the array
# ===========================================================================
# Raised because the state renders two ways: switching INTO a digital database
# leaves the previous analog numbers standing, and the next cursor motion clears
# them. Ruled DELIBERATE rather than fixed, and pinned here in both directions:
#   * `raw switch` is a NAVIGATION verb, not a request to backannotate. It has
#     never republished -- switching between two ANALOG databases equally leaves
#     the previous one's numbers standing -- and nothing on screen is fabricated:
#     those are real measurements from a database that is still loaded.
#   * clearing would be actively DESTRUCTIVE. wviewer::signal_list_all (the
#     All-DBs search) walks EVERY loaded database with `xschem raw switch <idx>`,
#     as do ase.tcl and wviewer::with_db, so a search that happened to hop
#     through a VCD would silently wipe the design window's backannotation.
# So "which values does the schematic show?" stays "whichever database last
# PUBLISHED", and D5's guarantee is that it is never a digital one.
xschem raw clear
xschem raw read $collraw tran
xschem raw read $collvcd vcd
xschem raw switch 0
xc_cursor 175e-9
set ba_sw_before [annot_snapshot]
check_true "BA90 premise: the analog annotation is standing before the switch" \
  [expr {[llength $ba_sw_before] > 0}]
xschem raw switch 1
check "BA91 `raw switch` INTO a digital database leaves the array exactly as it\
 was: a navigation verb must not destroy annotation state (signal_list_all hops\
 through every loaded database this way)" [annot_snapshot] $ba_sw_before
xc_cursor 500e-9
check "BA92 ...and the first PUBLISHER to run -- the cursor -- is what clears\
 it, because publishing is where the ruling bites" [annot_names] {}

# ===========================================================================
# BA96-98 -- THE DATABASE NAME IS USER-SUPPLIED AND IS NEVER EXECUTED
# ===========================================================================
# `annotate_op`'s argument is whatever the user picked in select_raw's dialog,
# and D5's refusal quotes it back at them. Two places used to splice it into a
# Tcl script by concatenation -- the arm's own `regsub {^~/} {<path>} {<home>/}`
# and backannot_refuse_digital()'s `ciw_echo <braced msg>` -- and a path
# containing a CLOSE-BRACE ends the brace group early: at best the notice is lost
# to `extra characters after close-brace`, at worst the rest of the path RUNS.
# (This comment says "close-brace" in words rather than showing one: the whole
# file body sits inside `if [catch <script> err]`, so Tcl counts braces even in
# comments and a lone one aborts the file before a single check runs.)
set cb [format %c 125]
set ob [format %c 123]
catch {unset ::BA_PWNED}
set ba_evil "[file join $scratch p]$cb note$cb; set ::BA_PWNED 1; if ${ob}1$cb ${ob}list $collvcd"
set ba_emsg [pcall {xschem annotate_op $ba_evil 0 vcd}]
check "BA96 a `$cb` in the database path does not EXECUTE: the path is resolved\
 in C, never spliced into a `regsub` script" [info exists ::BA_PWNED] 0
check_true "BA97 ...and the refusal still quotes the path back VERBATIM, so it\
 was neither mangled nor truncated by a Tcl parse" \
  [expr {[string first $ba_evil $ba_emsg] >= 0}]
# The CIW half of the same sentence only runs when has_x, which --nogui can never
# reach, so it is pinned by a SOURCE witness rather than behaviourally -- a
# line-scanner over the one function, not a regexp (declared as the weaker form
# of evidence it is; the behavioural proof is the manual run under :0 recorded in
# the receipt).
set ba_fp [open [file join $here .. .. src save.c] r]
set ba_srclines [split [read $ba_fp] "\n"]
close $ba_fp
# ⚠ counted with string ops only, NEVER llength/lsearch: C source lines are not
# valid Tcl list elements (unbalanced braces and quotes), so a list operation on
# them throws and aborts the file instead of answering.
set ba_nline 0; set ba_in 0; set ba_bad 0; set ba_good 0
foreach ba_l $ba_srclines {
  if {[string match "const char *backannot_refuse_digital*" $ba_l]} { set ba_in 1 }
  if {$ba_in} {
    incr ba_nline
    # ...and only CODE lines count. The function's own comment names the
    # forbidden idiom twice, on purpose, so that the next reader knows what not
    # to put back; a witness that cannot tell code from prose would read those.
    set ba_t [string trimleft $ba_l]
    set ba_iscomment [expr {[string index $ba_t 0] eq "*" ||
                            [string range $ba_t 0 1] eq "/*" ||
                            [string range $ba_t 0 1] eq "//"}]
    if {!$ba_iscomment && [string first "tclvareval" $ba_l] >= 0} { incr ba_bad }
    if {[string first "tclsetvar(" $ba_l] >= 0} { incr ba_good }
    if {$ba_l eq "\}"} { set ba_in 0 }
  }
}
check "BA98 SOURCE WITNESS: backannot_refuse_digital() hands the sentence to\
 Tcl as a VARIABLE (tclsetvar) and never concatenates it into a script\
 (tclvareval), so no path content can escape the brace group" \
  [list [expr {$ba_nline > 5}] $ba_bad [expr {$ba_good > 0}]] {1 0 1}

} err]} {
  puts "FAIL: BA99 the file ran to the end -> {$err} : FAIL"
  incr fail
}

catch {xschem raw clear}
catch {test_scratch_drop $scratch}
puts "----"
puts "test_backannotate_digital: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
