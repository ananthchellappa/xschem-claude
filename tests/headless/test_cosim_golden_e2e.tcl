# H2 of doc/claude/specs/mixed_signal_signal_browser.md — THE GOLDEN
# MIXED-SIGNAL RUN, END TO END.
#
# Every other test in this family proves one piece in isolation against a
# SYNTHESIZED fixture (mkraw/mkvcd in test_ase_cosim.tcl, mkvcd_edge/mkraw_edge
# in test_vcd_time_base.tcl). This one proves the pieces work TOGETHER against
# artifacts nobody in this repo wrote:
#
#   xschem netlist  ->  ase::cosim_map  ->  ase::cosim_build (verilator + g++,
#   the real tools/cosim/build_cosim_so.sh)  ->  render_deck (which rewrites
#   sim_args)  ->  ngspice -b  ->  the patched shim writes a VCD  ->
#   ase::attach_dbs puts the analog raw and that VCD in one registry  ->  the
#   internals are read back and compared against a COMMITTED GOLDEN.
#
# THE SHIPPING CONFIGURATION, NOT AN INVENTED ONE (batch F item 12, commit
# 1e5c2b64): `ase::cosim_build` never passes `-t`, so the build is
# TRACE + NON-TIMING. GE13/GE14 assert that from the build command actually
# issued, so this file cannot drift into testing a configuration nobody ships.
#
# ---------------------------------------------------------------------------
# THE GUARD, AND THE WAY TO GET IT WRONG
# ---------------------------------------------------------------------------
# `verilator` is not a build dependency of xschem, so on a machine without it
# the end-to-end arm cannot run. It must then skip CLEANLY:
#
#   * it must NOT fail, and
#   * it must NOT print any of the substrings full_audit.sh's is_skip() looks
#     for -- "RESULT: SKIP", "skipped: no X", "SKIP: no X connection"
#     (full_audit.sh:128-129). is_skip() is scored against the WHOLE captured
#     output of the file, and it runs BEFORE is_pass, so one such banner from a
#     per-GROUP skip would score this ENTIRE FILE as SKIP and silently discard
#     every check the GG group had already passed.
#
# So the guarded arm prints `note: group GE not run -- <what is missing>` and
# nothing else, exactly as test_vcd_time_base.tcl's REF group does, and the GG
# group below is deliberately verilator-INDEPENDENT so the file still carries
# real checks on a bare machine.
#
# ---------------------------------------------------------------------------
# GROUPS
# ---------------------------------------------------------------------------
#   GG   the golden itself and the comparator, with NO simulator: the committed
#        file parses, and gold_diff really reports a difference (a corrupted
#        value, a missing record, an extra record, a moved edge time) instead of
#        swallowing it. Runs everywhere.
#   GE   the end-to-end run. Needs verilator + ngspice + the reference library +
#        the build script. Skips cleanly, and silently, when any is absent.
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_cosim_golden_e2e.tcl

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

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set goldf [file join $here gold cosim_e2e_counter.golden]

# ===========================================================================
# The golden format, and the comparator
# ===========================================================================
#
# One record per line:  edge <signal> <time_ps> <value>
# `#` comments and blank lines are ignored. The records are the TRANSITIONS of
# the counter's INTERNAL signals -- the ones that exist in no `.raw` file
# anywhere, because only module PORTS cross the d_cosim boundary (spec M6).
#
# gold_diff returns a LIST OF SENTENCES, empty only when the two sets are
# identical. It is a set comparison keyed on <signal> <time_ps>, so a value
# that changed, an edge that moved, a record that vanished and a record that
# appeared are four distinguishable reports rather than one "files differ".

proc gold_parse {text} {
  set out {}
  foreach line [split $text "\n"] {
    set line [string trim $line]
    if {$line eq {} || [string index $line 0] eq "#"} { continue }
    # ⚠ `llength` THROWS on a line that is not a valid Tcl list -- an unbalanced
    # brace or quote, which is exactly what a hand-edited golden acquires (the
    # golden's own header tells a reader to regenerate it by pasting records).
    # Uncaught, that aborts the whole FILE before a single check reports, and
    # full_audit then scores it CRASH instead of FAIL -- discarding every GG
    # check. The catch routes that class into the same PARSE-ERROR count GG3
    # already reads. Measured: a record line ending in a lone open brace aborted
    # at this line. (The offending character is not written out here: an
    # unbalanced brace inside a proc body breaks Tcl's brace counting even in a
    # comment, which this comment learned the hard way.)
    if {[catch {llength $line} n]} {
      lappend out [list PARSE-ERROR $line {}]
      continue
    }
    if {$n != 4 || [lindex $line 0] ne {edge}} {
      lappend out [list PARSE-ERROR $line {}]
      continue
    }
    lappend out [list [lindex $line 1] [lindex $line 2] [lindex $line 3]]
  }
  return $out
}

proc gold_diff {got want} {
  set d {}
  set gk [dict create]
  foreach r $got  { dict set gk "[lindex $r 0] [lindex $r 1]" [lindex $r 2] }
  set wk [dict create]
  foreach r $want { dict set wk "[lindex $r 0] [lindex $r 1]" [lindex $r 2] }
  foreach k [lsort [dict keys $wk]] {
    if {![dict exists $gk $k]} {
      lappend d "MISSING $k (golden says [dict get $wk $k])"
    } elseif {[dict get $gk $k] ne [dict get $wk $k]} {
      lappend d "VALUE $k got [dict get $gk $k] want [dict get $wk $k]"
    }
  }
  foreach k [lsort [dict keys $gk]] {
    if {![dict exists $wk $k]} { lappend d "EXTRA $k (= [dict get $gk $k])" }
  }
  return $d
}

# ===========================================================================
# GG — the golden file and the comparator. No simulator, runs everywhere.
# ===========================================================================

set goldtext {}
if {[file isfile $goldf]} {
  set gf [open $goldf r]; set goldtext [read $gf]; close $gf
}
set GOLD [gold_parse $goldtext]

check GG1-golden-file-present [file isfile $goldf] "($goldf)"
# a count, and the count is NOT a magic number: it is what the reference run
# produces. A golden that silently shrank to nothing would still "compare
# equal" against a broken run, so the size is pinned.
eqcheck GG2-golden-record-count [llength $GOLD] 72
set badlines 0
foreach r $GOLD { if {[lindex $r 0] eq {PARSE-ERROR}} { incr badlines } }
# ⚠ THE `> 0` IS NOT DECORATION. "zero bad lines" is also true of a golden that
# is ABSENT, EMPTY or all-comments, and GG3/GG5/GG10 all reported `ok` against a
# golden that did not exist before this was added. A check that is green when the
# thing it inspects is missing is worse than no check.
check GG3-golden-parses-cleanly [expr {[llength $GOLD] > 0 && $badlines == 0}] \
  "(badlines=$badlines records=[llength $GOLD])"
# every record names an INTERNAL signal of the counter -- never a port. A port
# is visible in the analog raw too, so a golden made only of ports would prove
# nothing about the VCD.
set gsigs {}
foreach r $GOLD { if {[lsearch -exact $gsigs [lindex $r 0]] < 0} { lappend gsigs [lindex $r 0] } }
eqcheck GG4-golden-signals [lsort $gsigs] \
  {TOP.counter.carry TOP.counter.half TOP.counter.next_count TOP.counter.phase TOP.counter.prev TOP.counter.tc}
check GG5-golden-has-no-ports \
  [expr {[llength $gsigs] > 0 && [lsearch -glob $gsigs {*.count} ] < 0 &&
         [lsearch -glob $gsigs {*.clk}] < 0}] "($gsigs)"

# THE COMPARATOR IS REAL. Each of these four is a way a golden comparison gets
# silently swallowed, and each must be REPORTED. (The live corruption of an
# actual measured value is GE24 below; these pin the machinery itself, which is
# what makes GE24's single patch trustworthy.)
check GG10-identical-is-empty \
  [expr {[llength $GOLD] > 0 && [gold_diff $GOLD $GOLD] eq {}}] \
  "([llength $GOLD] records)"
# ⚠ EVERY PERTURBATION BELOW IS GATED ON `[llength $GOLD] > 1`, and the check
# still runs unguarded so it FAILS rather than aborts. With the golden absent or
# one record long, `lset corrupt 1 2 [expr {"" + 1}]` throws — no RESULT line is
# printed, full_audit scores the file CRASH, and every GG check that already
# passed is discarded. Same class as the GE24c guard below, one input earlier.
set corrupt {}
if {[llength $GOLD] > 1} {
  foreach r $GOLD { lappend corrupt $r }
  lset corrupt 1 2 [expr {[lindex $corrupt 1 2] + 1}]
}
set d [gold_diff $corrupt $GOLD]
eqcheck GG11-one-corrupted-value-is-reported [llength $d] 1
check GG11b-and-the-report-names-it \
  [expr {[string first VALUE [lindex $d 0]] == 0 &&
         [string first [lindex $GOLD 1 0] [lindex $d 0]] >= 0}] "($d)"
set short [lrange $GOLD 0 end-1]
set d [gold_diff $short $GOLD]
eqcheck GG12-a-missing-record-is-reported [llength $d] 1
check GG12b-missing-is-labelled-MISSING \
  [expr {[string first MISSING [lindex $d 0]] == 0}] "($d)"
set longer [concat $GOLD [list [list TOP.counter.ghost 12345 1]]]
set d [gold_diff $longer $GOLD]
eqcheck GG13-an-extra-record-is-reported [llength $d] 1
check GG13b-extra-is-labelled-EXTRA \
  [expr {[string first EXTRA [lindex $d 0]] == 0 &&
         [string first ghost [lindex $d 0]] >= 0}] "($d)"
# a MOVED edge is two reports, not zero: the old time vanished, the new one
# appeared. An implementation comparing only sorted VALUES would see neither.
set moved {}
if {[llength $GOLD] > 1} {
  foreach r $GOLD { lappend moved $r }
  lset moved 1 1 [expr {[lindex $moved 1 1] + 7}]
}
set d [gold_diff $moved $GOLD]
eqcheck GG14-a-moved-edge-is-reported [llength $d] 2
check GG14b-moved-is-one-MISSING-and-one-EXTRA \
  [expr {[llength [lsearch -all -glob $d {MISSING *}]] == 1 &&
         [llength [lsearch -all -glob $d {EXTRA *}]] == 1}] "($d)"
# and the empty comparison is not vacuously green: an EMPTY measurement against
# a non-empty golden must be 72 MISSING reports, not 0.
eqcheck GG15-empty-measurement-is-not-a-pass [llength [gold_diff {} $GOLD]] 72

# ===========================================================================
# GE — the end-to-end run. GUARDED.
# ===========================================================================

set refsch [file join $repo xschem_libraries_oa ngspice_verilog_cosim_ase \
                 tb_counter_wrapper schematic tb_counter_wrapper.sch]
set refstate [file join $repo xschem_libraries_oa ngspice_verilog_cosim_ase \
                 tb_counter_wrapper ngspice_state1 tb_counter_wrapper.state]
set oadefs [file join $repo xschem_libraries_oa library.defs]
set buildsh [file join $repo tools cosim build_cosim_so.sh]

set missing {}
if {[auto_execok verilator] eq {}} { lappend missing verilator }
if {[auto_execok ngspice]   eq {}} { lappend missing ngspice }
if {![file isfile $refsch] || ![file isfile $refstate] || ![file isfile $oadefs]} {
  lappend missing "the ngspice_verilog_cosim_ase reference library"
}
if {![file executable $buildsh]} { lappend missing tools/cosim/build_cosim_so.sh }

if {[llength $missing]} {
  # NO SKIP BANNER. See the header: "RESULT: SKIP" / "skipped: no X" /
  # "SKIP: no X connection" would make full_audit.sh score this whole FILE as
  # SKIP and throw away every GG check above.
  puts "note: group GE not run -- absent: [join $missing {, }]"
  puts "note: GG above still ran; it is the golden and its comparator, which are"
  puts "note: what a machine with no verilator can still be held to."
} else {

set tmp [test_scratch cosime2e]
set rd [file join $tmp run]
file mkdir $rd

set ::XSCHEM_LIBRARY_DEFS $oadefs
set ::library_registry_defs_only 1

# --- 1. the design, netlisted for real ------------------------------------
xschem load $refsch
set ST [ase::state_load $refstate]
dict set ST rundir $rd
eqcheck GE1-rundir [ase::rundir $ST] $rd
set nl [file join $rd tb_counter_wrapper.spice]
xschem netlist -noalert $nl
check GE2-netlist-written [file isfile $nl] "($nl)"
set nf [open $nl r]; set nltext [read $nf]; close $nf
check GE3-deck-has-the-d_cosim-card \
  [expr {[regexp -line {^\.model[ \t]+counter[ \t]+d_cosim} $nltext]}] ""

# --- 2. the map: the deck joined to the design walk ------------------------
set map [pcall ase::cosim_map $ST $nltext]
eqcheck GE4-one-code-block [llength $map] 1
eqcheck GE5-map-cell [ase::state_get [lindex $map 0] cell] counter
eqcheck GE6-map-module [ase::state_get [lindex $map 0] module] counter
eqcheck GE7-map-vfile [ase::state_get [lindex $map 0] vfile] \
  [file normalize [file join $repo xschem_libraries_oa ngspice_verilog_cosim_ase \
                        counter verilog counter.v]]
eqcheck GE8-map-not-multi [ase::state_get [lindex $map 0] multi] 0
set vcdf [ase::state_get [lindex $map 0] vcd]
eqcheck GE9-map-vcd [file tail $vcdf] tb_counter_wrapper_counter.vcd
# A survivor from a previous run must never be mistaken for this run's output.
#
# ⚠ THE DECOY IS THE CHECK. `$rd` is a per-pid `test_scratch` directory this run
# created with `file mkdir` moments ago, so NOTHING can pre-exist at `$vcdf` and
# `![file exists $vcdf]` was true BEFORE the call: measured, `cosim_clear_artifacts`
# stubbed to delete nothing left GE10 green, and so did deleting the call site
# outright. Planting a stale file first is what makes the assertion about the
# clear instead of about the scratch dir; the returned `gone` list must also NAME
# it, so a clear that deletes the file but reports nothing is caught too.
file mkdir [file dirname $vcdf]
set decoy [open $vcdf w]; puts $decoy "stale VCD from a previous run"; close $decoy
set gone [pcall ase::cosim_clear_artifacts $map]
check GE10-artifact-cleared \
  [expr {[file exists $vcdf] == 0 && [lsearch -exact $gone $vcdf] >= 0}] \
  "(exists=[file exists $vcdf] gone='$gone' vcd=$vcdf)"

# --- 3. the build: verilator + g++, through the shipped script -------------
# THE SHIPPING CONFIGURATION. `ase::cosim_build` is called exactly as ASE-L
# calls it, so `trace` comes from the state's own cosim policy (default 1) and
# `-t` is passed by nobody (spec §A "the shipped cosim build, precisely").
eqcheck GE11-trace-policy-is-on [ase::cosim_policy $ST trace 1] 1
eqcheck GE12-build-script-found [ase::cosim_build_script] $buildsh
set bsrc {}
if {![catch {open [file join $repo src ase.tcl] r} bf]} { set bsrc [read $bf]; close $bf }
# a SOURCE witness, and it is the one item 12 measured: no call site anywhere in
# ase.tcl adds `-t` to the build command. `lappend cmd -V` is the only flag.
check GE13-no--t-on-any-build-path \
  [expr {[regexp {lappend cmd -V} $bsrc] && ![regexp {lappend cmd -t} $bsrc] &&
         ![regexp -line {^\s*if \{\$timing\} \{ lappend cmd} $bsrc]}] ""
set br [pcall ase::cosim_build $ST $map]
eqcheck GE14-build-status [lindex [lindex $br 0] 1] built
set sof [file join $rd counter.so]
check GE15-so-produced [file isfile $sof] "($sof)"
# the stamp records the configuration the .so was built in -- trace 1, i.e. the
# VCD-writing shim. A `trace 0` .so writes no VCD at all and this whole file
# would then be measuring an empty run.
set stf $sof.stamp
set stamptext {}
if {[file isfile $stf]} { set sf2 [open $stf r]; set stamptext [read $sf2]; close $sf2 }
check GE16-stamp-says-trace-1 [expr {[string first {trace 1} $stamptext] >= 0}] "($stamptext)"

# --- 4. the deck, and the run ---------------------------------------------
set deck [ase::backend::ngspice::render_deck $ST $nltext]
# render_deck rewrote sim_args to the map's VCD, as a BARE LOWER-CASE BASENAME
# (ngspice folds the strings inside a device card -- spec M18/M14)
check GE17-sim_args-rewritten \
  [expr {[string first "sim_args=\[\"[file tail $vcdf]\"\]" $deck] >= 0}] \
  "([lindex [lsearch -inline -all [split $deck "\n"] {.model counter*}] 0])"
set deckf [file join $rd tb_counter_wrapper_ase.spice]
set rawf [file join $rd tb_counter_wrapper_ase.raw]
# the state's `write` target is ASE's own raw path; point it at the scratch run
set dl {}
foreach l [split $deck "\n"] {
  if {[string match {write *} $l]} { set l "write $rawf" }
  lappend dl $l
}
set df [open $deckf w]; puts -nonewline $df [join $dl "\n"]; close $df

# ngspice resolves the card's bare `simulation="./counter.so"` and the shim
# resolves the bare sim_args VCD name against its CWD, exactly as ase::run_deck
# arranges by cd'ing into the run directory first.
set oldpwd [pwd]
cd $rd
set rc 0
if {[catch {exec ngspice -b $deckf 2>@1} simout]} { set rc 1 }
cd $oldpwd
set logf [file join $rd ngspice.log]
set lf [open $logf w]; puts $lf $simout; close $lf
check GE18-ngspice-ran [expr {$rc == 0}] "(see $logf)"
# M9/E7: a desynchronized co-simulation is a wrong answer, not a slow one
check GE19-no-xspice-desync \
  [expr {[string first {XSPICE time is behind vtime} $simout] < 0}] ""
check GE20-both-artifacts-exist \
  [expr {[file isfile $rawf] && [file isfile $vcdf]}] \
  "(raw=[file isfile $rawf] vcd=[file isfile $vcdf])"

# --- 5. one registry, both databases, analog current -----------------------
xschem raw clear
set at [pcall ase::attach_dbs $rawf tran [list $vcdf]]
eqcheck GE21-two-dbs [pcall dict get $at n] 2
eqcheck GE22-analog-is-current [pcall xschem raw sim_type] tran
# THE POINT OF THE WHOLE FEATURE: an internal signal that exists in the VCD and
# in NO analog raw, because only ports cross the d_cosim boundary (M6).
check GE23-internal-is-not-in-the-raw \
  [expr {[pcall xschem raw index TOP.counter.phase] < 0}] ""
check GE23b-a-port-IS-in-the-raw [expr {[pcall xschem raw index v(clk)] >= 0}] ""

# --- 6. the golden comparison ---------------------------------------------
# `catch`, not a bare call: with the VCD absent the registry holds one DB and
# `raw switch 1` THROWS, which would abort the file before the golden comparison
# ever reported. GE24a is the check that must see that, not the interpreter.
catch {xschem raw switch 1}
eqcheck GE24a-vcd-is-current [pcall xschem raw sim_type] vcd
set measured {}
# NEVER a bare `xschem raw points` here, and never a bare `raw value` in the
# loop. When an upstream step failed there may be no VCD in the registry at all;
# `points` then throws, `$p < ERR:...` is not a numeric comparison, and the file
# would ABORT — reporting nothing about the golden and losing the checks below
# it. Measured: sabotage S20 (sim_args never rewritten, so no VCD is produced)
# did exactly that before this guard existed.
set np [pcall xschem raw points]
if {![string is integer -strict $np]} { set np 0 }
foreach s {TOP.counter.phase TOP.counter.half TOP.counter.tc TOP.counter.carry \
           TOP.counter.prev TOP.counter.next_count} {
  set prev {}
  for {set p 0} {$p < $np} {incr p} {
    # `raw value` on a name the CURRENT database does not have returns the EMPTY
    # STRING without throwing, so the catch alone is not enough: `$v != $prev`
    # on "" is "expected floating-point number but got """ and aborts the file.
    # Measured under sabotage S20, which leaves the analog raw current.
    if {[catch {xschem raw value $s $p} v] || $v eq {}} { break }
    if {$prev eq {} || $v != $prev} {
      lappend measured [list $s \
        [format %.0f [expr {[xschem raw value time $p] * 1e12}]] [format %g $v]]
    }
    set prev $v
  }
}
# THE MEASUREMENT MUST NOT BE EMPTY, and this is asserted separately from the
# diff on purpose: gold_diff of {} against the golden is 72 MISSING reports, so
# it cannot pass silently -- but a check that says so by name is what tells a
# reader WHICH half broke.
eqcheck GE24b-measured-record-count [llength $measured] 72
set gd [gold_diff $measured $GOLD]
check GE24-matches-the-golden [expr {[llength $gd] == 0}] \
  "([llength $gd] difference(s): [join [lrange $gd 0 4] { | }])"
# ...and the golden really is discriminating on THIS data: shift one measured
# edge by a single picosecond and the same comparator must reject it. Without
# this, GE24 would also pass against a comparator that always returns {}.
# The guard is not decoration: with `measured` empty (an upstream failure)
# `lindex $m1 1 1` is "" and `"" + 1` aborts the file. The check then has to say
# so by FAILING -- "there was nothing to perturb" is not a pass.
set m1 $measured
if {[llength $m1] > 1} { lset m1 1 1 [expr {[lindex $m1 1 1] + 1}] }
check GE24c-one-picosecond-would-fail \
  [expr {[llength $measured] > 1 && [llength [gold_diff $m1 $GOLD]] > 0}] \
  "([llength $measured] measured)"

# --- 7. the named edges the spec quotes ------------------------------------
# `half` toggles once in the 2 us window, and it toggles because `tc` fired --
# both invisible to ngspice. These are spelled out rather than left inside the
# 72-record diff so a failure says WHICH physical fact moved.
proc gedge {sig} {
  global measured
  set out {}
  foreach r $measured { if {[lindex $r 0] eq $sig} { lappend out [lindex $r 1] } }
  return $out
}
eqcheck GE25-half-toggles-once-at-1550012ps [gedge TOP.counter.half] {0 1550012}
eqcheck GE26-tc-fires-for-one-clock [gedge TOP.counter.tc] {0 1450012 1550012}
eqcheck GE27-carry-fires-twice [gedge TOP.counter.carry] {0 650012 750012 1450012 1550012}

xschem raw clear
catch {test_scratch_drop $tmp}
}

puts "----"
puts "test_cosim_golden_e2e: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
