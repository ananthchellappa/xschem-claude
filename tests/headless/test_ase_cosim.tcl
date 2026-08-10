# §E of doc/claude/specs/mixed_signal_signal_browser.md — ASE-L recognizes,
# emits and attaches a mixed-signal run.
#
# E1 detect      a run is mixed-signal iff the netlist carries >= 1 `.model
#                <m> d_cosim` card; the DESIGN side (an instance whose cell has
#                a `verilog` view) says WHICH .v built it. 0 / 1 / 2 blocks.
# E2 emit        one VCD per d_cosim MODEL CARD, <rundir>/<model>.vcd, written
#                into that card's sim_args by render_deck. The netlister
#                deduplicates .model cards (spice_netlist.c:143-169), so two
#                instances of ONE cell share ONE card: that case is DETECTED
#                (`multi`) and excluded from the attach rather than silently
#                producing an interleaved file.
# E3 attach      raw + every VCD in the registry, ANALOG current.
# E4 state       new `cosim` policy key; an OLD state file still loads (frozen
#                fixture, not a hand check).
# E5 deck        default auto_bridge pre_sets when the state has none.
# E6 build       a stale .so is rebuilt BEFORE the deck runs; the staleness test
#                is a stamp, so a same-named .so from another design is stale.
# E7 desync      "XSPICE time is behind vtime:" is surfaced, not scrolled past.
#
# THE LOAD-BEARING ONES, and why:
#   SC7/MP4  the `multi` case. One .model card serves N instances, so N shims
#            would open ONE VCD path and interleave their writes. If `multi`
#            stops being set, last_vcdfiles hands the viewer a corrupt file.
#   AT3      the analog DB must be CURRENT after attach. `xschem raw read`
#            makes the file it just read current (save.c:1277-1280), so
#            without the explicit switch every downstream consumer would
#            resolve analog names against a VCD.
#   BD3      the stamp, not an mtime compare: the rundir is shared by every
#            design, so <rundir>/counter.so can belong to another library.
#   DG1      the M9 string. If it stops being matched, a desynchronized
#            co-simulation reports success and the waveforms are wrong.
#
# Run headless from the repo root:
#   ./src/xschem --nogui --pipe -q --script tests/headless/test_ase_cosim.tcl

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

# The status of the first {model status detail} triple, or {} when the call
# errored. Never `lindex` straight into $r: pcall's "ERR:..." is not a valid
# Tcl list, so a build that throws where it should not would abort the file
# instead of failing the check that is watching for it.
proc bstatus {r} {
  if {[catch {lindex [lindex $r 0] 1} s]} { return {} }
  return $s
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch asecosim]
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]

proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]; puts -nonewline $fp $body; close $fp
}

# A state with a real rundir and a design cell (raw_file / cosim_file need one).
# The design is a REAL cellview in the fixture library below, because
# ase::cosim_map only trusts the instance walk when the state's design is the
# schematic actually loaded.
proc st {rundir cell args} {
  set s [ase::state_default]
  dict set s design [dict create lib dlib cell $cell view schematic]
  dict set s rundir $rundir
  foreach {k v} $args { dict set s $k $v }
  return $s
}

# ===========================================================================
# SC — E1 detection: the deck scanner (0 / 1 / 2 d_cosim blocks)
# ===========================================================================

set deck0 "* nothing digital here
v1 a 0 1
r1 a 0 1k
.end
"
eqcheck SC1-zero-blocks [llength [ase::cosim_scan_deck $deck0]] 0

set deck1 "vclock clk 0 pulse 0 1.8 1n
a1 \[ clk \] \[ q3 q2 q1 q0 \] counter
**** begin user architecture code
.model counter d_cosim simulation=\"./counter.so\" sim_args=\[\"counter.vcd\"\] delay=0
**** end user architecture code
.end
"
set s1 [ase::cosim_scan_deck $deck1]
eqcheck SC2-one-block [llength $s1] 1
eqcheck SC3-model-name [dict get [lindex $s1 0] model] counter
eqcheck SC4-so [dict get [lindex $s1 0] so] ./counter.so
eqcheck SC5-sim_args [dict get [lindex $s1 0] sim_args] {"counter.vcd"}
eqcheck SC6-one-inst [dict get [lindex $s1 0] insts] a1

# two DIFFERENT blocks -> two cards, two files, no possible collision
set deck2 "a1 \[ clk \] \[ q \] counter
a2 \[ clk \] \[ d \] decoder
.model counter d_cosim simulation=\"./counter.so\" sim_args=\[\"x.vcd\"\] delay=0
.model decoder d_cosim simulation=\"./decoder.so\" delay=0
.end
"
set s2 [ase::cosim_scan_deck $deck2]
eqcheck SC7-two-blocks [llength $s2] 2
eqcheck SC8-names "[dict get [lindex $s2 0] model] [dict get [lindex $s2 1] model]" \
  {counter decoder}
eqcheck SC9-no-sim_args [dict get [lindex $s2 1] sim_args] {}

# ONE block instantiated TWICE: one .model card, two instance lines
set deckM "a1 \[ clk \] \[ q \] counter
a2 \[ clk \] \[ r \] counter
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
set sM [ase::cosim_scan_deck $deckM]
eqcheck SC10-one-card [llength $sM] 1
eqcheck SC11-two-insts [dict get [lindex $sM 0] insts] {a1 a2}

# a non-d_cosim model card is not a code block
eqcheck SC12-other-model \
  [llength [ase::cosim_scan_deck ".model nch nmos level=1\nm1 d g s b nch\n.end\n"]] 0

# `.control` is not the circuit: an `alter`/`a...` command there is not an instance
set deckC "a1 \[ clk \] \[ q \] counter
.model counter d_cosim simulation=\"./counter.so\" delay=0
.control
alter counter
.endc
.end
"
eqcheck SC13-control-not-instance [dict get [lindex [ase::cosim_scan_deck $deckC] 0] insts] a1

# a `+`-continued card is still SEEN (folded), and flagged as unrewritable
set deckP ".model counter d_cosim simulation=\"./counter.so\"
+ delay=0
a1 \[ clk \] \[ q \] counter
.end
"
set sP [ase::cosim_scan_deck $deckP]
eqcheck SC14-continued-seen [llength $sP] 1
eqcheck SC15-continued-flagged [dict get [lindex $sP 0] cont] 1
eqcheck SC16-continued-inst [dict get [lindex $sP 0] insts] a1

# ===========================================================================
# RW — E2: pointing a card's sim_args at the run directory
# ===========================================================================

eqcheck RW1-replace \
  [ase::cosim_set_sim_args \
     {.model counter d_cosim simulation="./counter.so" sim_args=["counter.vcd"] delay=0} \
     /run/counter.vcd] \
  {.model counter d_cosim simulation="./counter.so" sim_args=["/run/counter.vcd"] delay=0}

eqcheck RW2-insert-when-absent \
  [ase::cosim_set_sim_args {.model counter d_cosim simulation="./counter.so" delay=0} \
     /run/counter.vcd] \
  {.model counter d_cosim sim_args=["/run/counter.vcd"] simulation="./counter.so" delay=0}

# a path carrying regexp/regsub metacharacters must survive verbatim
eqcheck RW3-metachar-path \
  [ase::cosim_set_sim_args {.model m1 d_cosim sim_args=["a.vcd"]} {/r&d/a\b/m1.vcd}] \
  {.model m1 d_cosim sim_args=["/r&d/a\b/m1.vcd"]}

eqcheck RW4-untouched-line \
  [ase::cosim_set_sim_args {r1 a 0 1k} /run/x.vcd] {r1 a 0 1k}

# ===========================================================================
# MP — the map: artifact paths, multi detection, save/load round trip
# ===========================================================================

set rd [file join $tmp run]
file mkdir $rd
set STA [st $rd tb1]

set m1 [ase::cosim_map $STA $deck2]
eqcheck MP1-two-entries [llength $m1] 2
eqcheck MP2-vcd-per-model \
  "[dict get [lindex $m1 0] vcd] [dict get [lindex $m1 1] vcd]" \
  "[file join $rd tb1_counter.vcd] [file join $rd tb1_decoder.vcd]"
eqcheck MP3-not-multi \
  "[dict get [lindex $m1 0] multi][dict get [lindex $m1 1] multi]" 00

set mM [ase::cosim_map $STA $deckM]
eqcheck MP4-multi-flagged [dict get [lindex $mM 0] multi] 1

eqcheck MP5-cosim-file [ase::cosim_file $STA] [file join $rd tb1_ase.cosim]

ase::cosim_save_map $STA $m1
check MP6-map-artifact-written [file isfile [ase::cosim_file $STA]] ""
set back [ase::cosim_load_map $STA]
eqcheck MP7-map-roundtrip [llength $back] 2
eqcheck MP8-map-roundtrip-vcd [dict get [lindex $back 0] vcd] [file join $rd tb1_counter.vcd]

# an empty map removes the artifact rather than leaving a stale one
ase::cosim_save_map $STA {}
eqcheck MP9-empty-map-drops-artifact [file exists [ase::cosim_file $STA]] 0
eqcheck MP10-load-absent [llength [ase::cosim_load_map $STA]] 0

# ===========================================================================
# HI — hierarchy, backends, and the artifacts a run will NOT write. Every one
# of these was found by an adversarial review pass AFTER 151 green checks.
# ===========================================================================

# A `.subckt` body is emitted ONCE however many times it is instantiated, so a
# line count cannot see N shims sharing one VCD path. This is the spec's own
# canonical topology (tb -> x1 (dig_top) -> a1 (counter)).
set deckH1 ".subckt blk clk out
a1 \[ clk \] \[ out \] counter
.ends
x1 CLK O1 blk
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
set deckH2 ".subckt blk clk out
a1 \[ clk \] \[ out \] counter
.ends
x1 CLK O1 blk
x2 CLK O2 blk
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
eqcheck HI1-nested-once-ninst [dict get [lindex [ase::cosim_scan_deck $deckH1] 0] ninst] 1
eqcheck HI2-nested-twice-ninst [dict get [lindex [ase::cosim_scan_deck $deckH2] 0] ninst] 2
eqcheck HI3-nested-once-not-multi [dict get [lindex [ase::cosim_map $STA $deckH1] 0] multi] 0
eqcheck HI4-nested-twice-IS-multi [dict get [lindex [ase::cosim_map $STA $deckH2] 0] multi] 1
# a `multi` entry still names a DETERMINISTIC path -- the interleaved file then
# lands somewhere known and cosim_clear_artifacts removes it -- but it is never
# served to the viewer (AT18)
eqcheck HI5-multi-still-has-a-known-path \
  [file tail [dict get [lindex [ase::cosim_map $STA $deckH2] 0] vcd]] tb1_counter.vcd
# THE SHAPE A VISIT-ONCE DFS GETS WRONG: the block sits under `mid`, and `mid`
# is reached from TWO wrappers. Expanding `mid` before both parents have
# contributed leaves the block at 1, so `multi` never fires and the interleaved
# VCD is attached as data.
set deckH6 ".subckt dig clk o
a1 \[ clk \] \[ o \] counter
.ends
.subckt mid clk o
xd clk o dig
.ends
.subckt wa clk o
xm clk o mid
.ends
.subckt wb clk o
xm clk o mid
.ends
xa clk o1 wa
xb clk o2 wb
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
eqcheck HI6a-shared-mid-two-parents \
  [dict get [lindex [ase::cosim_scan_deck $deckH6] 0] ninst] 2
eqcheck HI6b-shared-mid-IS-multi [dict get [lindex [ase::cosim_map $STA $deckH6] 0] multi] 1

# two levels deep, and the multiplicity multiplies
set deckH3 ".subckt inner clk out
a1 \[ clk \] \[ out \] counter
.ends
.subckt outer clk o1 o2
xa clk o1 inner
xb clk o2 inner
.ends
x1 CLK A B outer
x2 CLK C D outer
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
eqcheck HI6-two-levels-multiply [dict get [lindex [ase::cosim_scan_deck $deckH3] 0] ninst] 4
# a subckt defined but never instantiated contributes nothing
set deckH4 ".subckt dead clk out
a1 \[ clk \] \[ out \] counter
.ends
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
eqcheck HI7-uninstantiated-subckt [dict get [lindex [ase::cosim_scan_deck $deckH4] 0] ninst] 0
# a self-referential netlist is malformed, not a reason to hang
set deckH5 ".subckt loop a
x1 a loop
a1 \[ a \] counter
.ends
x0 N loop
.model counter d_cosim simulation=\"./counter.so\" delay=0
.end
"
check HI8-cycle-terminates [expr {[llength [ase::cosim_scan_deck $deckH5]] == 1}] ""
# `x` lines carrying params: the subckt name is the last NON-assignment token
eqcheck HI9-x-line-with-params \
  [dict get [lindex [ase::cosim_scan_deck ".subckt blk a\na1 \[ a \] counter\n.ends\nx1 N blk m=2 w=3\n.model counter d_cosim simulation=\"./x.so\"\n"] 0] ninst] 1

# --- the cards this run will NOT trace: `vcd` must be empty, and the card must
# --- be left EXACTLY as the netlist wrote it
set deckIC "a1 \[ clk \] \[ q \] counter
.model counter d_cosim simulation=\"ivlng\" sim_args=\[\"counter\"\] delay=0
.end
"
set mIC [ase::cosim_map $STA $deckIC]
eqcheck HI10-icarus-no-vcd [dict get [lindex $mIC 0] vcd] {}
eqcheck HI11-icarus-not-local-so [dict get [lindex $mIC 0] local_so] {}
eqcheck HI12-icarus-card-untouched \
  [lindex [ase::cosim_rewrite \
     [list {.model counter d_cosim simulation="ivlng" sim_args=["counter"] delay=0}] $mIC] 0] \
  {.model counter d_cosim simulation="ivlng" sim_args=["counter"] delay=0}
eqcheck HI13-icarus-build-skipped [bstatus [pcall ase::cosim_build $STA $mIC]] skipped

# a .so ngspice opens from somewhere else is not ASE's to build or to trace:
# building <rundir>/counter.so would stamp a file nobody loads
set deckAB "a1 \[ clk \] \[ q \] counter
.model counter d_cosim simulation=\"/opt/lib/counter.so\" delay=0
.end
"
set mAB [ase::cosim_map $STA $deckAB]
eqcheck HI14-foreign-so-no-vcd [dict get [lindex $mAB 0] vcd] {}
eqcheck HI15-foreign-so-build-skipped [bstatus [pcall ase::cosim_build $STA $mAB]] skipped

# `cosim trace 0` is a documented policy: no VCD is promised, so none is
# written into the card and none is later reported missing
set mT0 [ase::cosim_map [st $rd tb1 cosim {trace 0}] $deck1]
eqcheck HI16-trace0-no-vcd [dict get [lindex $mT0 0] vcd] {}
eqcheck HI17-trace0-card-untouched \
  [lindex [ase::cosim_rewrite [list {.model counter d_cosim sim_args=["orig.vcd"]}] $mT0] 0] \
  {.model counter d_cosim sim_args=["orig.vcd"]}

# a `+`-continued card render_deck cannot edit promises nothing either
eqcheck HI18-continued-no-vcd [dict get [lindex [ase::cosim_map $STA $deckP] 0] vcd] {}

# the VCD is DESIGN-QUALIFIED like every other run artifact: the run directory
# is shared by every design, so a bare <model>.vcd lets two sessions serve each
# other's digital data
set mA [ase::cosim_map [st $rd tb_a] $deck1]
set mB [ase::cosim_map [st $rd tb_b] $deck1]
check HI19-vcd-is-design-qualified \
  [expr {[dict get [lindex $mA 0] vcd] ne [dict get [lindex $mB 0] vcd]}] \
  "([dict get [lindex $mA 0] vcd] vs [dict get [lindex $mB 0] vcd])"

# two model names that collide after cosim_safe_name folds them must still get
# two files
# `.` and `+` and `-` survive cosim_safe_name; `$` does not, so `m$x` and `m_x`
# are two distinct MODELS that fold to one filename stem
set deckCO "a1 \[ c \] m\$x
a2 \[ c \] m_x
.model m\$x d_cosim simulation=\"./a.so\"
.model m_x d_cosim simulation=\"./b.so\"
.end
"
set mCO [ase::cosim_map $STA $deckCO]
check HI20-name-collision-disambiguated \
  [expr {[llength $mCO] == 2 &&
         [dict get [lindex $mCO 0] vcd] ne [dict get [lindex $mCO 1] vcd]}] \
  "([dict get [lindex $mCO 0] vcd] / [dict get [lindex $mCO 1] vcd])"

# a stale VCD must be gone BEFORE the run, or the missing-artifact check and
# last_vcdfiles both serve the previous run's data
set stalev [dict get [lindex [ase::cosim_map $STA $deck1] 0] vcd]
wr $stalev "stale\n"
eqcheck HI21-stale-artifact-deleted \
  [ase::cosim_clear_artifacts [ase::cosim_map $STA $deck1]] $stalev
eqcheck HI22-stale-artifact-gone [file exists $stalev] 0

# the auto-bridge check must see bridges written into the NETLIST, which is
# where the shipped reference testbench puts them (a `code_shown` block)
set nlbridge ".control
pre_set auto_bridge_d_out = ( \".model auto_dac dac_bridge( out_high = 3.3 )\" \"x\" )
.endc
"
eqcheck HI23-bridges-in-state [ase::cosim_has_bridges \
  [st $rd tb1 pre_commands {{cmd {pre_set auto_bridge_d_in = ()}}}] {}] 1
eqcheck HI24-bridges-in-netlist [ase::cosim_has_bridges [st $rd tb1] $nlbridge] 1
eqcheck HI25-no-bridges-anywhere [ase::cosim_has_bridges [st $rd tb1] "v1 a 0 1\n"] 0

# ===========================================================================
# DS — E1 design side: an instance whose cell has a `verilog` view
# ===========================================================================

# fixture library: dcell has symbol + verilog views, plain has symbol only
proc symfile {path pins} {
  set body "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\n"
  append body "K \{type=primitive\nformat=\"@name \[ @@clk \] \[ @@q \] @model\"\ntemplate=\"name=a1 model=dcell\"\n\}\n"
  append body "V \{\}\nS \{\}\nE \{\}\n"
  set y 0
  foreach {pname pdir} $pins {
    append body [format "B 5 %g %g %g %g \{name=%s dir=%s\}\n" \
                        -72.5 [expr {$y-2.5}] -67.5 [expr {$y+2.5}] $pname $pdir]
    incr y 20
  }
  wr $path $body
}
symfile $tmp/dlib/dcell/symbol/dcell.sym {clk in q out}
wr $tmp/dlib/dcell/verilog/dcell.v "\`timescale 1ps/1ps\nmodule dcell(input clk, output q);\nendmodule\n"
symfile $tmp/dlib/plaincell/symbol/plaincell.sym {clk in q out}

wr $tmp/dlib/library.tag "fixture"
wr $tmp/library.defs "DEFINE dlib $tmp/dlib\n"
set ::XSCHEM_LIBRARY_DEFS $tmp/library.defs
set ::library_registry_defs_only 1

# the three testbenches are real cellviews of the fixture library, so a state
# whose design names one of them resolves and the design-is-current guard can
# be exercised for real
proc tb {cell body} {
  global tmp
  wr $tmp/dlib/$cell/schematic/$cell.sch \
    "v \{xschem version=3.4.8 file_version=1.3\}\nG \{\}\nK \{\}\nV \{\}\nS \{\}\nE \{\}\n$body"
  return [file join $tmp dlib $cell schematic $cell.sch]
}

# 0 d_cosim instances
set p0 [tb tb0 "C \{dlib/plaincell\} 0 0 0 0 \{name=a9 model=plaincell\}\n"]
xschem load $p0
eqcheck DS1-zero [dict size [ase::cosim_design_scan]] 0

# 1 d_cosim instance
# the .sch property grammar needs the inner quotes doubly escaped, exactly as
# the reference cell writes them (tb_counter_wrapper.sch:35) — with a single
# backslash the netlister emits `simulation=./dcell.so` unquoted, which is a
# different (and weaker) test of the scanner.
set DM {device_model=".model dcell d_cosim simulation=\\"./dcell.so\\" sim_args=[\\"dcell.vcd\\"] delay=0"}
set p1 [tb tb1 "C \{dlib/dcell\} 0 0 0 0 \{name=a1 model=dcell\n$DM\}\nC \{dlib/plaincell\} 200 0 0 0 \{name=a9 model=plaincell\}\n"]
xschem load $p1
set d1 [ase::cosim_design_scan]
# never `dict get` straight into the result: a scan that keys the map wrongly
# must FAIL these checks, not abort the file with "key not known in dictionary"
proc dg {d k sub} {
  if {![dict exists $d $k $sub]} { return {} }
  return [dict get $d $k $sub]
}
eqcheck DS2-one [dict size $d1] 1
eqcheck DS3-inst [dg $d1 a1 inst] a1
eqcheck DS4-lib-cell "[dg $d1 a1 lib]/[dg $d1 a1 cell]" dlib/dcell
eqcheck DS5-vfile [dg $d1 a1 vfile] [file normalize $tmp/dlib/dcell/verilog/dcell.v]
eqcheck DS6-module [dg $d1 a1 module] dcell

# 2 d_cosim instances of the same cell
set p2 [tb tb2 "C \{dlib/dcell\} 0 0 0 0 \{name=a1 model=dcell\n$DM\}\nC \{dlib/dcell\} 200 0 0 0 \{name=a2 model=dcell\n$DM\}\n"]
xschem load $p2
eqcheck DS7-two [dict size [ase::cosim_design_scan]] 2

# the JOIN, through a REAL netlist: the deck's instance names must reach the
# design walk, else `vfile` is empty and E6 can never check staleness.
set ST2 [st $rd tb2]
set nl [file join $rd tb2.spice]
xschem netlist -noalert $nl
check DS8-netlist-written [file isfile $nl] ""
set nlf [open $nl r]; set nltext [read $nlf]; close $nlf
set mj [ase::cosim_map $ST2 $nltext]
eqcheck DS9-join-one-card [llength $mj] 1
eqcheck DS10-join-two-insts [llength [dict get [lindex $mj 0] insts]] 2
eqcheck DS11-join-multi [dict get [lindex $mj 0] multi] 1
eqcheck DS12-join-vfile [dict get [lindex $mj 0] vfile] \
  [file normalize $tmp/dlib/dcell/verilog/dcell.v]
eqcheck DS13-scope-hint [dict get [lindex $mj 0] scope] TOP.dcell

# and with ONE instance the same join gives a non-multi entry
xschem load $p1
set nl [file join $rd tb1.spice]
xschem netlist -noalert $nl
set nlf [open $nl r]; set nltext1 [read $nlf]; close $nlf
set mj1 [ase::cosim_map $STA $nltext1]
eqcheck DS14-join1-not-multi [dict get [lindex $mj1 0] multi] 0
eqcheck DS15-join1-vcd [dict get [lindex $mj1 0] vcd] [file join $rd tb1_dcell.vcd]

# the sidecar carries vfile to a run that never loads the design (`Run` on an
# existing netlist): scan the SAME deck with no schematic loaded and the map
# still knows which .v built the .so.
ase::cosim_save_map $STA $mj1
xschem load $p0
check DS16a-design-not-current [expr {![ase::cosim_design_is_current $STA]}] ""
set mj2 [ase::cosim_map $STA $nltext1]
eqcheck DS16-sidecar-carries-vfile [dict get [lindex $mj2 0] vfile] \
  [file normalize $tmp/dlib/dcell/verilog/dcell.v]
# THE JOIN MUST NOT FIRE AGAINST A FOREIGN SCHEMATIC. tb3 holds an `a1` of a
# DIFFERENT cell that also has a verilog view; with tb3 loaded and the state
# still naming tb1, a map built from tb1's deck must NOT pick up other.v.
symfile $tmp/dlib/othercell/symbol/othercell.sym {clk in q out}
wr $tmp/dlib/othercell/verilog/othercell.v "module othercell(input clk); endmodule\n"
set p3 [tb tb3 "C \{dlib/othercell\} 0 0 0 0 \{name=a1 model=othercell\}\n"]
xschem load $p3
check DS16b-foreign-a1-is-visible-to-the-walk \
  [expr {[dict exists [ase::cosim_design_scan] a1]}] ""
set mj3 [ase::cosim_map $STA $nltext1]
eqcheck DS16c-foreign-schematic-does-not-join [dict get [lindex $mj3 0] vfile] \
  [file normalize $tmp/dlib/dcell/verilog/dcell.v]
# ...and with the state's OWN design loaded the guard lets the walk through
xschem load $p1
check DS16d-design-is-current [ase::cosim_design_is_current $STA] ""

# ===========================================================================
# RD — E2/E5 through the real render_deck
# ===========================================================================

set STR [st $rd tb1 analyses {{type tran enabled 1 step 1n stop 1u}} \
                variables {{name VDD value 3.3}}]
set deck [ase::backend::ngspice::render_deck $STR $nltext1]
set dlines [split $deck "\n"]

set modelline {}
foreach l $dlines { if {[string match {.model dcell d_cosim*} $l]} { set modelline $l } }
check RD1-model-card-survives [expr {$modelline ne {}}] ""
# MEASURED, and load-bearing: ngspice LOWERCASES the strings inside a device
# card (`sim_args=["/tmp/x/Ecap/y.vcd"]` opened /tmp/x/ecap/y.vcd; measured by
# pre-creating the lower-case directory and watching the file appear there),
# and it says NOTHING when the open fails. So the card must carry a bare,
# lower-case BASENAME resolved against ngspice's cwd — which ase::run_deck sets
# to the rundir — never an absolute path that any capital letter would destroy.
check RD2-sim_args-is-a-bare-basename \
  [expr {[string first {sim_args=["tb1_dcell.vcd"]} $modelline] >= 0}] "($modelline)"
check RD2b-sim_args-is-not-an-absolute-path \
  [expr {[string first "sim_args=\[\"$rd" $modelline] < 0}] "($modelline)"
check RD3-simulation-left-alone \
  [expr {[string first {simulation="./dcell.so"} $modelline] >= 0}] "($modelline)"
# RD2 alone cannot see a rewrite that never RAN: the fixture's own device_model
# already says `dcell.vcd`, so the pre- and post-rewrite text are identical.
# Drive a card that names some OTHER file and prove it is redirected.
set otherdeck "a1 \[ c \] \[ q \] dcell
.model dcell d_cosim simulation=\"./dcell.so\" sim_args=\[\"/somewhere/else/OTHER.vcd\"\] delay=0
.end
"
set deckO [ase::backend::ngspice::render_deck $STR $otherdeck]
check RD2c-foreign-sim_args-is-replaced \
  [expr {[string first {sim_args=["tb1_dcell.vcd"]} $deckO] >= 0 &&
         [string first OTHER.vcd $deckO] < 0}] \
  "([lindex [lsearch -inline -all [split $deckO "\n"] {.model dcell*}] 0])"
# an upper-case model name must still name a file ngspice can open
set upmap [ase::cosim_map $STR ".model MiXeD d_cosim simulation=\"./x.so\"\na1 \[ c \] MiXeD\n"]
eqcheck RD3b-vcd-name-lowercased [file tail [dict get [lindex $upmap 0] vcd]] tb1_mixed.vcd
set upline [lindex [ase::cosim_rewrite \
  [list {.model MiXeD d_cosim simulation="./x.so"}] $upmap] 0]
eqcheck RD3c-card-token-lowercased $upline {.model MiXeD d_cosim sim_args=["tb1_mixed.vcd"] simulation="./x.so"}

# E5: a state with NO pre_commands and a d_cosim deck gets the default bridges,
# at the design's own supply
set nadc 0; set ndac 0
foreach l $dlines {
  if {[string match {pre_set auto_bridge_d_in*} $l]} { incr nadc }
  if {[string match {pre_set auto_bridge_d_out*} $l]} { incr ndac }
}
eqcheck RD4-default-adc-bridge $nadc 1
eqcheck RD5-default-dac-bridge $ndac 1
check RD6-bridge-supply-from-VDD \
  [expr {[string first {out_high = 3.3} $deck] >= 0}] ""
# they must precede the analysis they configure
set ipre -1; set itran -1
for {set i 0} {$i < [llength $dlines]} {incr i} {
  if {[string match {pre_set auto_bridge_d_in*} [lindex $dlines $i]]} { set ipre $i }
  if {[string match {tran *} [lindex $dlines $i]]} { set itran $i }
}
check RD7-bridges-before-analysis [expr {$ipre >= 0 && $itran > $ipre}] "($ipre/$itran)"

# a state that already configures the bridges is left alone (no duplicates)
set STB [st $rd tb1 analyses {{type tran enabled 1 step 1n stop 1u}} \
  pre_commands {{cmd {pre_set auto_bridge_d_in = ( "hand" "written" )}}}]
set deckB [ase::backend::ngspice::render_deck $STB $nltext1]
set nb 0
foreach l [split $deckB "\n"] { if {[string match {pre_set auto_bridge_d_*} $l]} { incr nb } }
eqcheck RD8-hand-bridges-not-doubled $nb 1
check RD9-hand-bridge-verbatim [expr {[string first {( "hand" "written" )} $deckB] >= 0}] ""

# bridges written into the NETLIST (upstream's `code_shown` idiom, which is what
# the shipped reference testbench uses) also suppress the defaults — otherwise
# ASE's pair is emitted LAST and the later `pre_set` wins, silently replacing a
# 3.3 V design's thresholds with 1.8 V ones
set nlwithbridge "$nltext1
.control
pre_set auto_bridge_d_out = ( \".model auto_dac dac_bridge( out_high = 3.3 )\" \"x\" )
.endc
"
set deckNB [ase::backend::ngspice::render_deck $STR $nlwithbridge]
set nnb 0
foreach l [split $deckNB "\n"] { if {[string match {pre_set auto_bridge_d_*} $l]} { incr nnb } }
eqcheck RD11-netlist-bridges-suppress-defaults $nnb 1
check RD11b-the-designs-own-value-survives \
  [expr {[string first {out_high = 3.3} $deckNB] >= 0 &&
         [string first {out_high = 1.8} $deckNB] < 0}] ""

# a deck with NO d_cosim gets no bridges at all
set deckN [ase::backend::ngspice::render_deck \
  [st $rd tb1 analyses {{type op enabled 1}}] "v1 a 0 1\nr1 a 0 1k\n.end\n"]
check RD10-no-cosim-no-bridges [expr {[string first auto_bridge $deckN] < 0}] ""

# ===========================================================================
# BD — E6 build orchestration. A STUB build script keeps this fast and
# verilator-independent; the real script's contract (`-o OUTDIR SOURCE.v` ->
# OUTDIR/<basename>.so) is what the stub reproduces.
# ===========================================================================

set stub [file join $tmp stub_build.sh]
wr $stub "#!/bin/sh
# stub build_cosim_so.sh: -V -o OUTDIR SOURCE.v -> OUTDIR/<base>.so
out=.
while \[ \$# -gt 0 \]; do
  case \"\$1\" in
    -o) out=\$2; shift 2 ;;
    -V|-t) shift ;;
    *) break ;;
  esac
done
src=\$1
\[ -n \"\$STUB_FAIL\" \] && { echo 'stub: deliberate failure' >&2; exit 3; }
b=\$(basename \"\$src\" .v)
mkdir -p \"\$out\"
echo \"stub-so of \$src\" > \"\$out/\$b.so\"
echo \"built: \$out/\$b.so\"
"
file attributes $stub -permissions 0755
set ::ASE_COSIM_BUILD $stub
eqcheck BD1-script-resolved [ase::cosim_build_script] $stub

set vsrc [file normalize $tmp/dlib/dcell/verilog/dcell.v]
set BMAP [list [dict create model dcell so ./dcell.so vfile $vsrc insts a1 \
                  vcd [file join $rd dcell.vcd] multi 0 cont 0]]
set sofile [file join $rd dcell.so]
file delete -force -- $sofile $sofile.stamp

set r [pcall ase::cosim_build $STA $BMAP]
eqcheck BD2-first-build-builds [bstatus $r] built
check BD3-so-exists [file isfile $sofile] ""
check BD4-stamp-written [file isfile $sofile.stamp] ""

set r [pcall ase::cosim_build $STA $BMAP]
eqcheck BD5-second-build-uptodate [bstatus $r] uptodate

# touching the SOURCE makes it stale again
after 1100
wr $vsrc "\`timescale 1ps/1ps\nmodule dcell(input clk, output q);\n// edited\nendmodule\n"
set r [pcall ase::cosim_build $STA $BMAP]
eqcheck BD6-edited-source-rebuilds [bstatus $r] built

# THE CASE AN mtime COMPARE MISSES: a .so newer than the .v, but built from a
# DIFFERENT source (the rundir is shared by every design)
wr $tmp/other.v "module other(); endmodule\n"
set otherstamp [ase::cosim_stamp [file normalize $tmp/other.v] $stub {} 1]
wr $sofile.stamp $otherstamp
check BD7-foreign-stamp-is-stale \
  [ase::cosim_stale $sofile [ase::cosim_stamp $vsrc $stub {} 1]] ""
set r [pcall ase::cosim_build $STA $BMAP]
eqcheck BD8-foreign-stamp-rebuilds [bstatus $r] built

# a missing .so is stale whatever the stamp says
file delete -force -- $sofile
check BD9-missing-so-is-stale [ase::cosim_stale $sofile [ase::cosim_stamp $vsrc $stub {} 1]] ""

# build=never never runs the script
set STN [st $rd tb1 cosim {build never}]
set r [pcall ase::cosim_build $STN $BMAP]
eqcheck BD10-never-skips [bstatus $r] skipped
eqcheck BD11-never-built-nothing [file exists $sofile] 0

# build=always rebuilds an up-to-date .so
set STAL [st $rd tb1 cosim {build always}]
catch {ase::cosim_build $STA $BMAP}
set r [pcall ase::cosim_build $STAL $BMAP]
eqcheck BD12-always-rebuilds [bstatus $r] built

# A FAILING BUILD MUST ABORT THE RUN — falling through would simulate last
# week's Verilog, which is the whole point of E6. Driven through `build always`
# so the stamp cannot short-circuit the script before it can fail.
set ::env(STUB_FAIL) 1
set r [pcall ase::cosim_build $STAL $BMAP]
check BD13-failed-build-throws [string match {ERR:*FAILED*} $r] "($r)"
unset ::env(STUB_FAIL)

# the built .so must land under the name ngspice will actually OPEN: it folds
# `simulation="./Dcell.so"` to `./dcell.so` and then reports
# `d_cosim failed to load simulation binary ./dcell.so` (measured)
file delete -force -- $sofile $sofile.stamp
set UMAP [list [dict create model dcell so ./Dcell.so vfile $vsrc insts a1 \
                  vcd [file join $rd dcell.vcd] multi 0 cont 0]]
catch {ase::cosim_build $STA $UMAP}
check BD17-so-target-lowercased [file isfile $sofile] "(want [file tail $sofile])"
check BD18-no-uppercase-so-left [expr {![file exists [file join $rd Dcell.so]]}] ""

# the stamp must track the shim the build ACTUALLY links (build_cosim_so.sh:49-53):
# -V takes the in-repo patched copy, a plain build the system one. Recording the
# wrong one makes a shim upgrade invisible to the staleness test.
if {![info exists ::env(NGSPICE_COSIM_SRC)] || $::env(NGSPICE_COSIM_SRC) eq {}} {
  eqcheck BD19-shimdir-trace [ase::cosim_shim_dir /x/tools/cosim/build_cosim_so.sh 1] \
    /x/tools/cosim/src
  eqcheck BD20-shimdir-notrace [ase::cosim_shim_dir /x/tools/cosim/build_cosim_so.sh 0] \
    /usr/local/share/ngspice/scripts/src
} else {
  puts "SKIPPED: BD19-20 (NGSPICE_COSIM_SRC is set in the environment)"
}
# ...and the stamp must READ the shim file, not merely name its directory: a
# `-V` build links tools/cosim/src/verilator_shim.cpp INTO the .so, so editing
# the shim makes every built .so stale. Size, not mtime, so no sleep is needed.
set shimdir [file join $tmp shimsrc]
wr [file join $shimdir verilator_shim.cpp] "// stub shim\n"
set stampA [ase::cosim_stamp $vsrc $stub $shimdir 1]
wr [file join $shimdir verilator_shim.cpp] "// stub shim, edited and longer\n"
set stampB [ase::cosim_stamp $vsrc $stub $shimdir 1]
check BD21-shim-edit-changes-the-stamp [expr {$stampA ne $stampB}] ""
check BD22-shim-edit-makes-the-so-stale \
  [ase::cosim_stale $sofile $stampB] "(built against $stampA)"

# A path with a SPACE, and a path with a `$`, must each reach the build script
# as ONE argument. Both characters are legal in a path and both occur in real
# ones (a library under "My Designs"; a directory named after a shell var).
# These do NOT distinguish `exec {*}$cmd` from `eval exec $cmd` — Tcl's list
# quoting braces an element containing either, so both spellings survive
# (measured). What they DO catch is the argument being passed unexpanded, or
# assembled by string concatenation.
proc buildprobe {state dir file model} {
  global rd
  set src [file join $dir $file]
  wr $src "module ${model}(); endmodule\n"
  set m [list [dict create model $model so ./$model.so vfile $src insts a1 \
                 vcd [file join $rd $model.vcd] multi 0 cont 0]]
  file delete -force -- [file join $rd $model.so] [file join $rd $model.so.stamp]
  return [pcall ase::cosim_build $state $m]
}
set r [buildprobe $STA [file join $tmp "sp ace"] "sp cell.v" spcell]
eqcheck BD23-space-in-path-builds [bstatus $r] built
check BD24-space-in-path-so-exists [file isfile [file join $rd spcell.so]] "($r)"
set r [buildprobe $STA [file join $tmp {dol$lar}] dolcell.v dolcell]
eqcheck BD25-dollar-in-path-builds [bstatus $r] built
check BD26-dollar-in-path-so-exists [file isfile [file join $rd dolcell.so]] "($r)"

# a `simulation=` that is not a .so (the Icarus arm) is not a Verilator build
set IMAP [list [dict create model dcell so ivlng vfile $vsrc insts a1 multi 0 cont 0]]
eqcheck BD14-non-so-skipped [bstatus [pcall ase::cosim_build $STA $IMAP]] skipped

# no verilog view resolved AND no .so on disk -> honest error, not a silent run
file delete -force -- $sofile
set NMAP [list [dict create model dcell so ./dcell.so vfile {} insts a1 multi 0 cont 0]]
# NEVER ABORT THE RUN BECAUSE ASE CANNOT CHECK. A code block one level down in
# the hierarchy has no resolvable .v (the instance walk is current-level only),
# and that configuration worked before §E — it must still run. ASE says what it
# cannot check; if the .so really is missing, ngspice's own
# `d_cosim failed to load simulation binary` is what reports it (E7).
eqcheck BD15-no-source-degrades-never-aborts \
  [bstatus [pcall ase::cosim_build $STA $NMAP]] unavailable
# ...but an existing .so with no resolvable source is a NOTICE, not a stop
catch {ase::cosim_build $STA $BMAP}
eqcheck BD16-no-source-with-so-degrades \
  [bstatus [pcall ase::cosim_build $STA $NMAP]] unavailable

# ===========================================================================
# AT — E3 attach: N DBs registered, the ANALOG one current
# ===========================================================================

# a minimal ASCII ngspice raw (read_dataset: Plotname selects sim_type, then the
# ascii Values: block, save.c:622,406)
proc mkraw {path} {
  set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: 3\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n"
  append body "0\t0.0\n\t0.0\n\n"
  append body "1\t1e-09\n\t1.0\n\n"
  append body "2\t2e-09\n\t0.5\n\n"
  wr $path $body
}
proc mkvcd {path sig} {
  wr $path "\$timescale 1ps \$end
\$scope module TOP \$end
 \$scope module m \$end
  \$var wire 1 ! $sig \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#100
1!
#200
"
}
set rawf [file join $tmp anlg.raw]
mkraw $rawf
mkvcd [file join $tmp d1.vcd] siga
mkvcd [file join $tmp d2.vcd] sigb

xschem raw clear
set res [ase::attach_dbs $rawf tran [list [file join $tmp d1.vcd] [file join $tmp d2.vcd]]]
eqcheck AT1-three-dbs [dict get $res n] 3
eqcheck AT2-registry-lists-three [llength [lrange [split [xschem raw info] "\n"] 1 end-1]] 3
eqcheck AT3-analog-current [xschem raw sim_type] tran
eqcheck AT4-analog-current-file [xschem raw rawfile] $rawf
eqcheck AT5-current-index [lindex [split [xschem raw info] "\n"] 0] {0 current}
# and each VCD is really there and readable
xschem raw switch 1
eqcheck AT6-vcd1-type [xschem raw sim_type] vcd
check AT7-vcd1-signal [expr {[xschem raw index TOP.m.siga] >= 0}] ""
xschem raw switch 2
check AT8-vcd2-signal [expr {[xschem raw index TOP.m.sigb] >= 0}] ""
xschem raw switch 0
check AT9-analog-signal [expr {[xschem raw index v(anlg)] >= 0}] ""

# partial run: the VCD never appeared. The analog result still attaches.
xschem raw clear
set res [ase::attach_dbs $rawf tran [list [file join $tmp nope.vcd]]]
eqcheck AT10-partial-n [dict get $res n] 1
eqcheck AT11-partial-skipped [llength [dict get $res skipped]] 1
eqcheck AT12-partial-analog-current [xschem raw sim_type] tran

# partial run the other way: the raw never appeared -> NOTHING is cleared
xschem raw clear
ase::attach_dbs $rawf tran {}
set res [ase::attach_dbs [file join $tmp nope.raw] tran [list [file join $tmp d1.vcd]]]
eqcheck AT13-no-raw-n [dict get $res n] 0
# pcall, not a bare call: if the guard regresses the registry is EMPTY and
# `xschem raw rawfile` throws "No raw file loaded" — which must read as this
# check failing, not as the whole file aborting
eqcheck AT14-no-raw-keeps-previous [pcall xschem raw rawfile] $rawf

# AN UNREADABLE RAW MUST NOT DESTROY THE LOADED ONE. The documented policy is
# "a stale-but-loaded DB beats an empty viewer"; a file that EXISTS but does not
# parse (truncated, or the requested analysis is not in it because the run died
# after `op`) is the half that a clear-then-read order gets wrong.
wr $tmp/junk.raw "this is not a spice raw file at all\n"
xschem raw clear
ase::attach_dbs $rawf tran {}
set res [ase::attach_dbs $tmp/junk.raw tran {}]
eqcheck AT19-unreadable-raw-n [dict get $res n] 0
eqcheck AT20-unreadable-raw-keeps-previous [pcall xschem raw rawfile] $rawf
eqcheck AT21-unreadable-raw-one-db \
  [llength [lrange [split [pcall xschem raw info] "\n"] 1 end-1]] 1
# a raw whose requested analysis is absent is the same case
set res [ase::attach_dbs $rawf ac {}]
eqcheck AT22-wrong-analysis-keeps-previous [pcall xschem raw rawfile] $rawf
xschem raw clear

# RE-ATTACHING THE SAME PATH MUST RE-READ IT. `xschem raw read` only SWITCHES
# to a path already in the registry (save.c:1335-1339, no disk access), and the
# raw artifact is a deterministic path a re-run overwrites in place — so
# without a targeted clear the second run of a session plots the first run's
# waveforms. Every ASE-L re-run goes through here.
set reraw [file join $tmp rerun.raw]
mkraw $reraw
xschem raw clear
ase::attach_dbs $reraw tran {}
eqcheck AT23-first-attach-vector [pcall xschem raw index v(anlg)] 1
# rewrite the SAME path with a different vector name, as a re-run does
set body "Title: test\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
append body "Flags: real\nNo. Variables: 2\nNo. Points: 2\nVariables:\n"
append body "\t0\ttime\ttime\n\t1\tv(second)\tvoltage\n"
append body "Values:\n0\t0.0\n\t0.0\n\n1\t1e-09\n\t1.0\n\n"
wr $reraw $body
ase::attach_dbs $reraw tran {}
eqcheck AT24-reattach-sees-the-new-file [pcall xschem raw index v(second)] 1
eqcheck AT25-reattach-dropped-the-old-vector [pcall xschem raw index v(anlg)] -1
eqcheck AT26-reattach-one-db \
  [llength [lrange [split [pcall xschem raw info] "\n"] 1 end-1]] 1
xschem raw clear

# an unreadable VCD is skipped, not fatal
wr $tmp/junk.vcd "this is not a vcd at all\n"
xschem raw clear
set res [ase::attach_dbs $rawf tran [list $tmp/junk.vcd [file join $tmp d1.vcd]]]
check AT15-junk-vcd-does-not-stop-the-rest \
  [expr {[lsearch -exact [dict get $res vcds] [file join $tmp d1.vcd]] >= 0}] \
  "(n=[dict get $res n] skipped=[dict get $res skipped])"
eqcheck AT16-junk-analog-still-current [xschem raw sim_type] tran
xschem raw clear

# last_vcdfiles reads the run-directory map, and EXCLUDES a `multi` entry: two
# shims writing one path produce an interleaved file that is not data.
set key [ase::session_key dlib tb1 ngspice_state1]
ase::session_open $key [ase::state_save [file join $tmp sess.state] [st $rd tb1]]
mkvcd [file join $rd dcell.vcd] q
ase::cosim_save_map [st $rd tb1] \
  [list [dict create model dcell vcd [file join $rd dcell.vcd] multi 0]]
eqcheck AT17-last-vcdfiles [ase::last_vcdfiles $key] [file join $rd dcell.vcd]
ase::cosim_save_map [st $rd tb1] \
  [list [dict create model dcell vcd [file join $rd dcell.vcd] multi 1]]
eqcheck AT18-multi-excluded [ase::last_vcdfiles $key] {}

# ===========================================================================
# WV — the viewer's attach seam. The REAL wviewer::attach_raw body runs; only
# its three Tk-touching helpers are stubbed, so the clear/read/switch order and
# the unchanged single-file default are both exercised without a display.
# ===========================================================================

foreach p {switch_ctx capture_live_view_state regenerate} {
  if {[info commands ::wviewer::$p] ne {}} { rename ::wviewer::$p ::wviewer::saved_$p }
}
proc ::wviewer::switch_ctx {t} { return 1 }
proc ::wviewer::capture_live_view_state {t} { return }
proc ::wviewer::regenerate {t} { set ::wvregen 1; return }
dict set ::wviewer::windows TESTTOK stub

set ::wvregen 0
xschem raw clear
eqcheck WV1-attach-returns \
  [wviewer::attach_raw TESTTOK $rawf tran [list $tmp/d1.vcd $tmp/d2.vcd]] 1
eqcheck WV2-three-dbs [llength [lrange [split [xschem raw info] "\n"] 1 end-1]] 3
eqcheck WV3-analog-current [xschem raw sim_type] tran
eqcheck WV4-regenerated $::wvregen 1
# the 3-argument form must behave exactly as it did before section E
xschem raw clear
eqcheck WV5-default-arg-returns [wviewer::attach_raw TESTTOK $rawf tran] 1
eqcheck WV6-default-arg-one-db [llength [lrange [split [xschem raw info] "\n"] 1 end-1]] 1
# an unknown token still refuses, and refuses BEFORE clearing
eqcheck WV7-unknown-token [wviewer::attach_raw NOSUCHTOK $rawf tran] 0
eqcheck WV8-unknown-token-kept-registry [xschem raw rawfile] $rawf
xschem raw clear

dict unset ::wviewer::windows TESTTOK
foreach p {switch_ctx capture_live_view_state regenerate} {
  rename ::wviewer::$p {}
  if {[info commands ::wviewer::saved_$p] ne {}} { rename ::wviewer::saved_$p ::wviewer::$p }
}

# WIRING PIN (not a behavioral check): the two ASE call sites must hand the
# session's VCDs to attach_raw. attach_raw's new argument DEFAULTS to {}, so a
# call site that forgot them attaches the analog raw alone and every check above
# still passes — only this pin catches that.
set awf [file join $repo src ase_window.tcl]
if {[file isfile $awf]} {
  set f [open $awf r]; set awtxt [read $f]; close $f
  eqcheck WV9-both-call-sites-pass-vcds \
    [regexp -all {wviewer::attach_raw \$key \$rf \$sim_t \[ase::last_vcdfiles \$key\]} $awtxt] 2
} else {
  puts "SKIPPED: WV9 (src/ase_window.tcl not found from $repo)"
}

# ===========================================================================
# ST — E4 state schema + versioning against a FROZEN fixture
# ===========================================================================

check ST1-cosim-in-schema \
  [expr {[lsearch -exact $ase::schema_keys cosim] >= 0}] ""
eqcheck ST2-cosim-default [ase::state_get [ase::state_default] cosim] {}
eqcheck ST3-policy-default [ase::cosim_policy [ase::state_default] build auto] auto
eqcheck ST4-policy-read [ase::cosim_policy [st $rd c cosim {build never}] build auto] never
eqcheck ST5-policy-bad-dict [ase::cosim_policy [st $rd c cosim {not a dict at all}] build auto] auto

set fixture [file join $here fixtures ase_state_v1_pre_cosim.state]
if {[file isfile $fixture]} {
  set old [ase::state_load $fixture]
  eqcheck ST6-old-state-loads [ase::state_get $old version] 1
  eqcheck ST7-old-state-keeps-vars [ase::state_get $old variables] {{name VDD value 1.8}}
  eqcheck ST8-old-state-keeps-unknown-key \
    [ase::state_get $old zz_unknown_future_key] {carried through untouched}
  eqcheck ST9-old-state-gets-cosim-default [ase::state_get $old cosim] {}
  # the frozen file must not itself mention cosim, or ST9 proves nothing
  set ff [open $fixture r]; set ftxt [read $ff]; close $ff
  check ST10-fixture-is-really-pre-cosim [expr {[string first "\ncosim " $ftxt] < 0}] ""
  # and a state saved from it is byte-stable from then on
  set once [ase::state_serialize $old]
  set twice [ase::state_serialize [ase::state_load [ase::state_save \
     [file join $tmp roundtrip.state] $old]]]
  eqcheck ST11-save-load-save-stable $twice $once
  # THE STRONG FORM: the frozen file must round-trip BYTE-IDENTICALLY. A new
  # schema key that serialized when empty would rewrite every state view in
  # the tree on its next save (F3/G3 in test_ase_final{,_gf180} are the two
  # committed goldens that would break) — hence ase::omit_if_empty.
  eqcheck ST13-frozen-file-byte-identical "$once\n" $ftxt
  check ST14-cosim-omitted-when-empty [expr {[string first cosim $once] < 0}] ""
  set nonempty [ase::state_serialize [dict replace $old cosim {build never}]]
  check ST15-cosim-written-when-set \
    [expr {[string first "cosim {build never}" $nonempty] >= 0}] ""
  eqcheck ST12-old-bridges-suppress-defaults \
    [ase::cosim_has_bridges $old] 1
} else {
  puts "SKIPPED: group ST (frozen fixture $fixture absent)"
}

# ===========================================================================
# DG — E7: a desynchronized co-simulation is reported, not scrolled past
# ===========================================================================

set cleanlog "Circuit: test\nNo. of Data Rows : 20\nbinary raw file \"x.raw\"\n"
eqcheck DG0-clean-log-silent [ase::run_diagnostics $cleanlog] {}

set badlog "Circuit: test
XSPICE time is behind vtime:
XSPICE 1.2345e-07
Cosim  1.2400e-07
XSPICE time is behind vtime:
XSPICE 1.5000e-07
Cosim  1.5100e-07
binary raw file \"x.raw\"
"
set d [ase::run_diagnostics $badlog]
eqcheck DG1-desync-detected [llength $d] 1
eqcheck DG2-desync-severity [lindex [lindex $d 0] 0] error
eqcheck DG3-desync-code [lindex [lindex $d 0] 1] cosim_desync
eqcheck DG4-desync-count [lindex [lindex $d 0] 2] 2

# the reference run's 61 `dump call ignored` lines are EXPECTED (the shim clamps
# non-monotonic dumps): a note with a count, never an error
set dumplog "%Warning: previous dump at t=0, requesting t=0, dump call ignored\n"
append dumplog "%Warning: previous dump at t=5, requesting t=5, dump call ignored\n"
set d [ase::run_diagnostics $dumplog]
eqcheck DG5-dumpskip-is-a-note [lindex [lindex $d 0] 0] note
eqcheck DG6-dumpskip-count [lindex [lindex $d 0] 2] 2

foreach {code text} [list \
    cosim_past   "Warning simulated event is in the past:\nXSPICE 1e-9\n" \
    cosim_portcount "Warning: mismatched XSPICE/co-simulator input counts: 2/3.\n" \
    cosim_load   "d_cosim failed to load simulation binary ./counter.so.\n"] {
  set d [ase::run_diagnostics $text]
  eqcheck DG7-$code-error "[lindex [lindex $d 0] 0] [lindex [lindex $d 0] 1]" "error $code"
}

# run_done must record them and echo the errors
set logp [file join $tmp diag.log]
set ::execute(data,last) $badlog
set ::execute(exitcode,last) 0
set echoed {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::saved_ciw_echo }
proc ::ciw_echo {msg {tag {}}} { lappend ::echoed [list $tag $msg] }
ase::run_done $logp [st $rd tb1] {}
rename ::ciw_echo {}
if {[info commands ::saved_ciw_echo] ne {}} { rename ::saved_ciw_echo ::ciw_echo }
eqcheck DG8-run_done-records [llength [ase::last_diagnostics]] 1
eqcheck DG9-run_done-severity [lindex [lindex [ase::last_diagnostics] 0] 0] error
set said 0
foreach e $echoed {
  if {[lindex $e 0] eq {error} && [string first DESYNCHRONIZED [lindex $e 1]] >= 0} { set said 1 }
}
eqcheck DG10-run_done-echoes-error $said 1
check DG11-log-flushed [file isfile $logp] ""

# a clean run says nothing
set ::execute(data,last) $cleanlog
set echoed {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::saved_ciw_echo }
proc ::ciw_echo {msg {tag {}}} { lappend ::echoed [list $tag $msg] }
ase::run_done $logp [st $rd tb1] {}
rename ::ciw_echo {}
if {[info commands ::saved_ciw_echo] ne {}} { rename ::saved_ciw_echo ::ciw_echo }
eqcheck DG12-clean-run-no-diagnostics [llength [ase::last_diagnostics]] 0

# THE FAILURE THE LOG CANNOT REPORT (found by running the reference TB end to
# end): a promised VCD that never appeared. ngspice exits 0, the analog raw is
# perfect, and the digital half is simply missing with no message anywhere.
set STMISS [st $rd tb1]
ase::cosim_save_map $STMISS [list [dict create model gone \
  vcd [file join $rd definitely_absent.vcd] multi 0]]
set ::execute(data,last) $cleanlog
set ::execute(exitcode,last) 0
ase::run_done $logp $STMISS {}
set codes {}
foreach d [ase::last_diagnostics] { lappend codes [lindex $d 1] }
eqcheck DG13-missing-vcd-reported $codes cosim_novcd
eqcheck DG14-missing-vcd-is-an-error [lindex [lindex [ase::last_diagnostics] 0] 0] error
# ...and a VCD that IS there says nothing
mkvcd [file join $rd definitely_absent.vcd] q
ase::run_done $logp $STMISS {}
eqcheck DG15-present-vcd-silent [llength [ase::last_diagnostics]] 0
# a `multi` entry is not chased: its VCD is deliberately never written
ase::cosim_save_map $STMISS [list [dict create model gone \
  vcd [file join $rd never_written.vcd] multi 1]]
ase::run_done $logp $STMISS {}
eqcheck DG16-multi-not-chased [llength [ase::last_diagnostics]] 0
# ...and an entry that promises NO vcd (Icarus arm, `trace 0`, a `+`-continued
# card, a foreign .so) must never be reported missing: those runs are healthy
# and a false "results cannot be trusted" trains the user past the real one.
ase::cosim_save_map $STMISS [list [dict create model gone vcd {} multi 0]]
ase::run_done $logp $STMISS {}
eqcheck DG17-no-promise-no-complaint [llength [ase::last_diagnostics]] 0
ase::cosim_save_map $STMISS {}

# ===========================================================================
# FS — F2: which VCD scope holds THIS instance's digital signals
# ===========================================================================
#
# Contract: doc/claude/specs/mixed_signal_signal_browser.md, "Open decision 5,
# ruled" (RULINGS 5a-5f). Three facts with three owners; the join key is the
# CELL, never the instance path; and `scope` in the map artifact is a HINT that
# the loaded database overrules.
#
# THE CHECKS THAT CARRY THE ITEM ARE THE ONES WHERE HINT AND REALITY DIVERGE.
# FS30-FS33 (they agree) pass against a naive implementation that simply trusts
# the recorded string; FS34-FS39 do not. FS34-FS39 are still not enough on their
# own: every one of them makes the hint name a DIFFERENT module (`TOP.gone` vs
# `realmod`), so a resolver that never reads the database at all -- accepting the
# hint whenever its last segment equals f1's module -- passes all of them. The
# shape inlining really produces keeps the module NAME and moves or deletes the
# SCOPE, and that is FS22c/FS22d (pure) and FS60-FS64 (end to end). A recorded
# hint can be wrong for
# reasons no artifact can predict — the digital simulator inlines the module
# away, or the .v is edited between the run and the query — so the fixtures
# below hand-write map entries whose `scope` names a module the VCD does not
# declare. That is the honest fixture for inlining on a machine with no
# verilator: what F2 must survive is the DISAGREEMENT, and where the wrong
# string came from is not something the resolver can see.

set ::XSCHEM_LIBRARY_DEFS $tmp/library.defs
set ::library_registry_defs_only 1

proc fget {d k} {
  if {[catch {dict exists $d $k} ok] || !$ok} { return {} }
  return [dict get $d $k]
}

# A VCD whose SCOPE TREE is exactly the given dotted scope paths, one wire each.
# mkvcd (AT) is fixed at TOP.m; divergence needs the tree to be a parameter.
proc mkvcdtree {path scopes} {
  set ids {! # % & + ,}
  set body "\$timescale 1ps \$end\n"
  set i 0
  foreach sc $scopes {
    set segs [split $sc .]
    foreach s $segs { append body "\$scope module $s \$end\n" }
    append body "\$var wire 1 [lindex $ids $i] q \$end\n"
    foreach s $segs { append body "\$upscope \$end\n" }
    incr i
  }
  append body "\$enddefinitions \$end\n#0\n"
  for {set k 0} {$k < $i} {incr k} { append body "0[lindex $ids $k]\n" }
  append body "#100\n"
  for {set k 0} {$k < $i} {incr k} { append body "1[lindex $ids $k]\n" }
  append body "#200\n"
  wr $path $body
}

# a SECOND digital cell whose .v declares a module named differently from the
# cell: without that, "the cell name" and "the module name" are the same string
# and no check can tell which one the code used.
symfile $tmp/dlib/dcell2/symbol/dcell2.sym {clk in q out}
wr $tmp/dlib/dcell2/verilog/dcell2.v "module realmod(input clk, output q);\nendmodule\n"
set p4 [tb tb4 "C \{dlib/dcell2\} 0 0 0 0 \{name=a1 model=dcell2\}\nC \{dlib/plaincell\} 200 0 0 0 \{name=a9 model=plaincell\}\n"]

# --- f1: the query-time read, in the DESIGN context ------------------------
xschem load $p1
set F1 [pcall ase::cosim_f1 a1]
eqcheck FS1-f1-lib-cell "[fget $F1 lib]/[fget $F1 cell]" dlib/dcell
eqcheck FS2-f1-module [fget $F1 module] dcell
eqcheck FS3-f1-model-property [fget $F1 model] dcell
# RULING 5d: the schematic prefix is DROPPED, not translated
eqcheck FS4-f1-drops-the-prefix [fget [pcall ase::cosim_f1 x1.x2.a1] inst] a1
set F9 [pcall ase::cosim_f1 a9]
eqcheck FS5-f1-no-verilog-view-no-vfile "[fget $F9 inst]|[fget $F9 cell]|[fget $F9 vfile]" \
  {a9|plaincell|}
eqcheck FS6-f1-unknown-instance [pcall ase::cosim_f1 nosuchinst] {}

# --- f2: the 5b key ladder (pure, over hand-built maps) --------------------
proc f1of {lib cell module model} {
  return [dict create lib $lib cell $cell module $module model $model]
}
set FDC [f1of dlib dcell dcell dcell]
proc mrung {r} { return [lindex $r 2] }
proc mmodel {r} {
  if {[lindex $r 0] ne {ok}} { return [lindex $r 1] }
  return [ase::state_get [lindex $r 1] model]
}

# rung 1 -- lib/cell. Two libraries, each with a cell named `dcell`: the bare
# cell key matches BOTH, lib/cell picks exactly one.
set MAP1 [list \
  [dict create model m_d lib dlib cell dcell vfile /x/dcell.v module dcell] \
  [dict create model m_e lib elib cell dcell vfile /y/dcell.v module dcell]]
set r [pcall ase::cosim_map_match $MAP1 $FDC]
eqcheck FS10-rung1-picks-one "[mmodel $r] [mrung $r]" {m_d 1}
# ...and the CELL half of that key is load-bearing too. MAP1 distinguishes its
# entries by LIB alone, so it cannot tell a rung-1 that compares both operands
# from one that compares only the library -- and two digital cells in ONE
# library is the ordinary case, not an exotic one.
set MAP1B [list \
  [dict create model m_d lib dlib cell dcell vfile /x/dcell.v module dcell] \
  [dict create model m_o lib dlib cell other vfile /x/other.v module other]]
set r [pcall ase::cosim_map_match $MAP1B $FDC]
eqcheck FS10b-rung1-cell-operand-matters "[mmodel $r] [mrung $r]" {m_d 1}
# and the negative control: a lone entry from the RIGHT library but the WRONG
# cell is not this cell's entry. A lib-only rung 1 would hand back its VCD and
# its scope hint, i.e. another cell's internals under this cell's name.
set MAP1C [list [dict create model m_o lib dlib cell other vfile /x/other.v module other]]
eqcheck FS10c-rung1-wrong-cell-is-not-a-match \
  [lindex [pcall ase::cosim_map_match $MAP1C $FDC] 1] nomap
# rung 2 -- the .v-basename fallback leaves `lib` empty
set MAP2 [list [dict create model m_d lib {} cell dcell vfile /x/dcell.v module dcell]]
set r [pcall ase::cosim_map_match $MAP2 $FDC]
eqcheck FS11-rung2-cell-alone "[mmodel $r] [mrung $r]" {m_d 2}
# rung 3 -- the module name, and ONLY when the entry carries a .v
set MAP3 [list [dict create model m_x lib {} cell {} vfile /x/dcell.v module dcell]]
set r [pcall ase::cosim_map_match $MAP3 $FDC]
eqcheck FS12-rung3-module "[mmodel $r] [mrung $r]" {m_x 3}
# rung 4 -- the .model card name against the instance's own model= property.
# THIS IS THE BURIED-BLOCK CASE (issue 0307): the design walk is flat, so a code
# block below the netlisted schematic has lib/cell/vfile all empty and rungs
# 1-3 are dead. Rung 4 is what carries it.
set MAP4 [list [dict create model dcell lib {} cell {} vfile {} module dcell]]
set r [pcall ase::cosim_map_match $MAP4 $FDC]
eqcheck FS13-rung4-buried-block "[mmodel $r] [mrung $r]" {dcell 4}
# a rung matching >1 REFUSES and does not fall through -- even though rung 4
# would have matched exactly one of these two entries
set MAP5 [list \
  [dict create model dcell lib {} cell dcell vfile {} module dcell] \
  [dict create model other lib {} cell dcell vfile {} module dcell]]
set r [pcall ase::cosim_map_match $MAP5 $FDC]
eqcheck FS14-ambiguous-does-not-fall-through [lindex $r 1] ambiguous
eqcheck FS15-nomap [lindex [pcall ase::cosim_map_match {} $FDC] 1] nomap
# rung 3 is gated on the entry's vfile: with none, `module` IS the .model card
# name (cosim_map's own fallback), so it is not an independent key
set MAP6 [list [dict create model cnt8 lib {} cell {} vfile {} module dcell]]
eqcheck FS16-rung3-needs-a-vfile [lindex [pcall ase::cosim_map_match $MAP6 $FDC] 1] nomap

# THE LADDER'S OPERANDS MUST BE THREE DIFFERENT STRINGS. FDC's cell, module and
# model are all the literal `dcell`, so against it alone rungs 2/3/4 cannot be
# told apart from a rung that reads f1's CELL three times -- and rung 4 is the
# only key a buried code block has (issue 0307): its lib, cell and vfile are all
# empty, and the .model card name is routinely NOT the cell name.
set FCM [f1of dlib counter8 cnt_v cnt8]
set MAP3B [list [dict create model zz lib {} cell {} vfile /x/cnt.v module cnt_v]]
set r [pcall ase::cosim_map_match $MAP3B $FCM]
eqcheck FS12b-rung3-reads-the-module-not-the-cell "[mmodel $r] [mrung $r]" {zz 3}
set MAP4B [list [dict create model cnt8 lib {} cell {} vfile {} module cnt8]]
set r [pcall ase::cosim_map_match $MAP4B $FCM]
eqcheck FS13b-rung4-reads-the-model-not-the-cell "[mmodel $r] [mrung $r]" {cnt8 4}
# negative control: a .model card that happens to carry the CELL's name is not
# this instance's card -- the instance's own `model=` property is (RULING 5b)
set MAP4C [list [dict create model counter8 lib {} cell {} vfile {} module zzz]]
eqcheck FS13c-rung4-model-card-named-for-the-cell-is-not-a-match \
  [lindex [pcall ase::cosim_map_match $MAP4C $FCM] 1] nomap

# --- f3: scope derivation (pure) -------------------------------------------
set NREF {TOP.clk TOP.count TOP.counter.clk TOP.counter.phase}
set r [pcall ase::cosim_scope_derive $NREF TOP.counter /x/counter.v counter]
eqcheck FS20-hint-accepted-when-it-agrees "[lindex $r 0] [lindex $r 1]" {hint TOP.counter}
# an entry with no .v carries no evidence: the hint is not even eligible
set r [pcall ase::cosim_scope_derive $NREF TOP.counter {} counter]
eqcheck FS21-empty-vfile-hint-not-eligible "[lindex $r 0] [lindex $r 1]" {derived TOP.counter}
# THE DIVERGENCE: an eligible hint that the database does not contain loses
set r [pcall ase::cosim_scope_derive {TOP.realmod.q} TOP.gone /x/d.v realmod]
eqcheck FS22-db-beats-hint "[lindex $r 0] [lindex $r 1]" {derived TOP.realmod}
check FS22b-disagreement-is-reported [expr {[string first TOP.gone [lindex $r 2]] >= 0}] \
  "(note '[lindex $r 2]')"
# THE SHAPE INLINING ACTUALLY PRODUCES, and the one a hint-trusting resolver
# survives: the module is NOT renamed, so the recorded hint is still
# `TOP.<module>` and its last segment still equals f1's module name. Only the
# LOADED DATABASE can say whether that scope is there. A resolver that accepts
# the hint whenever its leaf matches the module answers TOP.dcell to both of
# these -- a scope that does not exist.
#   (a) fully inlined away: the dump declares the shim's root and nothing else
set r [pcall ase::cosim_scope_derive {TOP.q TOP.clk} TOP.dcell /x/dcell.v dcell]
eqcheck FS22c-inlined-hint-named-for-the-module-refuses "[lindex $r 0] [lindex $r 1]" \
  {none noscope}
#   (b) merely MOVED: the module survived one level deeper than recorded
set r [pcall ase::cosim_scope_derive {TOP.q TOP.wrapper.dcell.q} TOP.dcell /x/dcell.v dcell]
eqcheck FS22d-moved-hint-named-for-the-module-loses "[lindex $r 0] [lindex $r 1]" \
  {derived TOP.wrapper.dcell}
# the prefix test is CASE-SENSITIVE (vcd_read stores names verbatim; Verilog is
# case-sensitive). A hint that differs only in case is a MISS, not a hit.
set r [pcall ase::cosim_scope_derive $NREF TOP.Counter /x/counter.v counter]
eqcheck FS23-hint-match-is-case-sensitive "[lindex $r 0] [lindex $r 1]" {derived TOP.counter}
# the DEEPEST scope whose leaf is the module name
set r [pcall ase::cosim_scope_derive {TOP.m.x TOP.m.sub.m.y} {} {} m]
eqcheck FS24-deepest-wins "[lindex $r 0] [lindex $r 1]" {derived TOP.m.sub.m}
# A SCOPE NEED NOT OWN A SIGNAL TO EXIST. Every fixture above puts a wire
# directly in every scope it declares; a module that contains sub-instances (the
# ordinary shape of a Verilator dump) declares a scope whose only trace in the
# name list is as a PREFIX of a deeper name, so the enumeration must yield every
# intermediate prefix, not just each name's innermost one.
eqcheck FS24b-scopes-of-yields-every-prefix [pcall ase::cosim_scopes_of {TOP.a.b.q}] \
  {TOP TOP.a TOP.a.b}
set r [pcall ase::cosim_scope_derive {TOP.realmod.sub.q} {} {} realmod]
eqcheck FS24c-intermediate-scope-is-derivable "[lindex $r 0] [lindex $r 1]" \
  {derived TOP.realmod}
# no module match -> exactly one NON-ROOT scope
set r [pcall ase::cosim_scope_derive {TOP.a.q} {} {} zzz]
eqcheck FS25-single-non-root-scope "[lindex $r 0] [lindex $r 1]" {derived TOP.a}
# nothing matches -> REFUSE. Never `TOP`: its signals are the port mirror, i.e.
# exactly the ones already bridged into the analog raw (RULING 5e).
set r [pcall ase::cosim_scope_derive {TOP.clk TOP.count} {} {} realmod]
eqcheck FS26-no-scope-refuses [lindex $r 1] noscope
check FS27-refusal-names-what-was-found \
  [expr {[string first {scopes found: TOP} [lindex $r 2]] >= 0}] "([lindex $r 2])"
# two scopes with the same leaf at the same depth is not decidable
set r [pcall ase::cosim_scope_derive {TOP.a.m.x TOP.b.m.y} {} {} m]
eqcheck FS28-tie-refuses [lindex $r 1] noscope

# --- end to end, against databases that are really loaded ------------------
proc fsentry {args} {
  return [dict create model dcell lib dlib cell dcell vfile {} module dcell \
    scope TOP.dcell vcd {} multi 0 ninst 1 {*}$args]
}
set vagree [file join $tmp fs_agree.vcd]
set vdiv   [file join $tmp fs_diverge.vcd]
set vnone  [file join $tmp fs_nomatch.vcd]
set vmoved [file join $tmp fs_moved.vcd]
mkvcdtree $vagree {TOP TOP.dcell}
mkvcdtree $vdiv   {TOP TOP.realmod}
mkvcdtree $vnone  {TOP}
# the module is still called `dcell` and the hint is still `TOP.dcell`; the
# digital run put it one level down, INSIDE a wrapper, and gave it no signal of
# its own -- so `TOP.wrapper.dcell` exists in this database only as a prefix
mkvcdtree $vmoved {TOP TOP.wrapper.dcell.inner}

set dv1 [file normalize $tmp/dlib/dcell/verilog/dcell.v]
set dv2 [file normalize $tmp/dlib/dcell2/verilog/dcell2.v]

# THE AGREEING CASE. Loaded: the analog raw (current) + all three VCDs, so the
# resolver has to reach a database that is NOT the current one.
xschem raw clear
ase::attach_dbs $rawf tran [list $vagree $vdiv $vnone $vmoved]
xschem load $p1
set FSA [st $rd fsa]
ase::cosim_save_map $FSA [list [fsentry vfile $dv1 vcd $vagree scope TOP.dcell]]
set r [pcall ase::cosim_scope_for_state $FSA x1.a1]
eqcheck FS30-agree-ok [lindex $r 0] ok
eqcheck FS31-agree-vcd [lindex $r 1] $vagree
eqcheck FS32-agree-scope [lindex $r 2] TOP.dcell
eqcheck FS33-agree-how-is-hint [lindex $r 3] hint
eqcheck FS33b-agree-no-note "[lindex $r 3]|[lindex $r 4]" {hint|}
eqcheck FS33c-current-db-untouched "[lindex $r 0] [pcall xschem raw rawfile]" "ok $rawf"

# THE DIVERGING CASE — the item's whole point. The recorded hint names
# `TOP.gone`; the database that is actually loaded declares TOP and TOP.realmod,
# and `realmod` is what THIS cell's .v declares. A resolver that trusts the
# string answers TOP.gone (or refuses); the DB must win.
xschem load $p4
set FSB [st $rd fsb]
ase::cosim_save_map $FSB [list [fsentry model dcell2 cell dcell2 module gone \
  vfile $dv2 vcd $vdiv scope TOP.gone]]
set r [pcall ase::cosim_scope_for_state $FSB x1.a1]
eqcheck FS34-diverge-ok [lindex $r 0] ok
eqcheck FS35-diverge-scope-comes-from-the-db [lindex $r 2] TOP.realmod
eqcheck FS36-diverge-how-is-derived [lindex $r 3] derived
check FS37-diverge-note-names-the-stale-hint \
  [expr {[string first TOP.gone [lindex $r 4]] >= 0}] "(note '[lindex $r 4]')"
# and it is not the port mirror either
eqcheck FS37b-diverge-not-TOP \
  "[lindex $r 0] [expr {[lindex $r 2] ne {TOP} ? 1 : 0}]" {ok 1}

# NO SCOPE MATCHES AT ALL — the case F5's empty-pane notice has to explain.
# Defined answer: {none noscope <sentence>}, the sentence naming the database
# and the scopes that WERE found. Never an ok on `TOP`.
set FSC [st $rd fsc]
ase::cosim_save_map $FSC [list [fsentry model dcell2 cell dcell2 module gone \
  vfile $dv2 vcd $vnone scope TOP.gone]]
set r [pcall ase::cosim_scope_for_state $FSC x1.a1]
eqcheck FS38-nomatch-refuses [lindex $r 1] noscope
check FS39-nomatch-sentence-explains \
  [expr {[string first realmod [lindex $r 2]] >= 0 &&
         [string first {scopes found: TOP} [lindex $r 2]] >= 0 &&
         [string first fs_nomatch.vcd [lindex $r 2]] >= 0}] "([lindex $r 2])"

# INLINING, END TO END, WITH THE MODULE NAME UNCHANGED. FS34-FS39 above make the
# hint name a DIFFERENT module (`TOP.gone` vs `realmod`), which a resolver that
# never reads the database can still get right by comparing the hint's leaf with
# f1's module. These two do not: the .v still declares `module dcell`, the
# recorded hint is still `TOP.dcell`, and only the loaded database knows whether
# that scope survived the digital compile.
# (a) MOVED into a wrapper, and owning no signal of its own -- so the answer is
#     reachable only as an intermediate prefix of a deeper name
xschem load $p1
set FSE [st $rd fse]
ase::cosim_save_map $FSE [list [fsentry vfile $dv1 vcd $vmoved scope TOP.dcell]]
set r [pcall ase::cosim_scope_for_state $FSE x1.a1]
eqcheck FS60-moved-ok-and-scope-from-the-db "[lindex $r 0] [lindex $r 2]" \
  {ok TOP.wrapper.dcell}
eqcheck FS61-moved-how-is-derived [lindex $r 3] derived
check FS62-moved-note-names-the-stale-hint \
  [expr {[string first TOP.dcell [lindex $r 4]] >= 0}] "(note '[lindex $r 4]')"
# (b) INLINED AWAY entirely: the dump declares the shim root and nothing else.
#     Defined answer is the refusal, never an `ok` on the hint and never on TOP.
set FSF [st $rd fsf]
ase::cosim_save_map $FSF [list [fsentry vfile $dv1 vcd $vnone scope TOP.dcell]]
set r [pcall ase::cosim_scope_for_state $FSF x1.a1]
eqcheck FS63-inlined-refuses [lindex $r 1] noscope
check FS64-inlined-sentence-explains \
  [expr {[string first {module 'dcell'} [lindex $r 2]] >= 0 &&
         [string first {scopes found: TOP} [lindex $r 2]] >= 0 &&
         [string first fs_nomatch.vcd [lindex $r 2]] >= 0}] "([lindex $r 2])"

# the other refusals, each naming its own cause
set FSD [st $rd fsd]
ase::cosim_save_map $FSD [list [fsentry model dcell2 cell dcell2 vfile $dv2 \
  vcd [file join $tmp fs_never_read.vcd] scope TOP.gone]]
eqcheck FS40-db-not-loaded [lindex [pcall ase::cosim_scope_for_state $FSD a1] 1] notloaded
ase::cosim_save_map $FSD [list [fsentry model dcell2 cell dcell2 vfile $dv2 \
  vcd $vdiv multi 1 ninst 2]]
eqcheck FS41-multi-refused [lindex [pcall ase::cosim_scope_for_state $FSD a1] 1] multi
ase::cosim_save_map $FSD [list [fsentry model dcell2 cell dcell2 vfile $dv2 vcd {}]]
eqcheck FS42-no-vcd-promised [lindex [pcall ase::cosim_scope_for_state $FSD a1] 1] notraced
eqcheck FS43-no-verilog-view [lindex [pcall ase::cosim_scope_for_state $FSD a9] 1] nodigital
ase::cosim_save_map $FSD {}
eqcheck FS44-empty-map [lindex [pcall ase::cosim_scope_for_state $FSD a1] 1] nomap

# the SESSION-KEY form is the one F1 will call
set fskey [ase::session_key dlib fsa ngspice_state1]
set fssf [file join $tmp fsa.state]
ase::state_save $fssf $FSA
ase::session_open $fskey $fssf
ase::session_update $fskey $FSA
xschem load $p1
set r [pcall ase::cosim_scope_for_instance $fskey x1.a1]
eqcheck FS45-key-form "[lindex $r 0] [lindex $r 2] [lindex $r 3]" {ok TOP.dcell hint}

# THE DISAGREEMENT MUST NOT BE SILENT: it reaches the user through ase::echo,
# not only through the returned note.
set ::fs_echoed {}
if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::fs_saved_echo }
proc ::ciw_echo {msg {tag {}}} { lappend ::fs_echoed [list $tag $msg] }
xschem load $p4
pcall ase::cosim_scope_for_state $FSB x1.a1
set said {}
foreach e $::fs_echoed { if {[string first TOP.gone [lindex $e 1]] >= 0} { set said 1 } }
check FS46-disagreement-is-echoed [expr {$said eq 1}] "(echoed '$::fs_echoed')"
set ::fs_echoed {}
xschem load $p1
set r [pcall ase::cosim_scope_for_state $FSA x1.a1]
eqcheck FS47-agreement-is-quiet "[lindex $r 3] [llength $::fs_echoed]" {hint 0}
# ...and the tag it is echoed WITH has to be a tag the CIW actually configures.
# ase::echo hands the tag straight to the text widget; an undefined Tk tag is
# legal and styles nothing, so `note` renders exactly like an ordinary result
# and 5f-1's "the disagreement is visible" would be true of the return value
# only. (This is a literal-source pin, like BM05's: headless has no Tk widget.)
set ciwsrc {}
if {![catch {open [file join $repo src ciw.tcl]} fh]} { set ciwsrc [read $fh]; close $fh }
check FS47b-ciw-configures-the-note-tag \
  [expr {[regexp {tag configure\s+note\s+-foreground} $ciwsrc]}] "(src/ciw.tcl)"
rename ::ciw_echo {}
if {[info commands ::fs_saved_echo] ne {}} { rename ::fs_saved_echo ::ciw_echo }

# A STALE OR UN-ENTERABLE VIEWER TOKEN IS NOT AN EMPTY REGISTRY (5f-2, and this
# is the arm F1 will actually use). wviewer::signal_list_all answers {} for a
# token that is not in `windows`, for an enter_ctx ticket it refused, and for a
# viewer that genuinely holds no database -- only the last is an answer. Taking
# the empty list as authoritative makes the resolver say `notloaded` about a
# database that is loaded and readable THIS INSTANT, and a token goes stale
# exactly during viewer teardown, which is when a browser refresh fires.
xschem load $p1
set r [pcall ase::cosim_scope_for_state $FSA x1.a1 .no_such_viewer_token]
eqcheck FS50-stale-token-still-resolves "[lindex $r 0] [lindex $r 2] [lindex $r 3]" \
  {ok TOP.dcell hint}
# ...and the same with signal_list_all PRESENT and answering {} -- the refused
# ticket, which the real proc returns without throwing, so a `catch` cannot see it
set fs_had_sla [expr {[info commands ::wviewer::signal_list_all] ne {}}]
if {$fs_had_sla} { rename ::wviewer::signal_list_all ::wviewer::fs_saved_sla }
proc ::wviewer::signal_list_all {token} { return {} }
set r [pcall ase::cosim_scope_for_state $FSA x1.a1 .fs_live_but_refusing]
rename ::wviewer::signal_list_all {}
if {$fs_had_sla} { rename ::wviewer::fs_saved_sla ::wviewer::signal_list_all }
eqcheck FS51-refused-viewer-ticket-falls-back \
  "[lindex $r 0] [lindex $r 2] [lindex $r 3]" {ok TOP.dcell hint}

# the inventory reads every database and PUTS THE POINTER BACK
set inv [pcall ase::cosim_db_inventory]
set paths {}
# defensive: with the inventory absent `$inv` is pcall's ERR: string, and a bare
# `dict get` on it would ABORT the file instead of failing this check
catch {foreach db $inv { catch {lappend paths [file tail [dict get $db path]]} }}
check FS48-inventory-sees-every-db \
  [expr {[lsearch -exact $paths fs_agree.vcd] >= 0 && [lsearch -exact $paths anlg.raw] >= 0}] \
  "($paths)"
# THE FULL INVENTORY IS IN THE SAME ASSERTION ON PURPOSE, and it is named, not
# counted: "the pointer did not move" is also true of an inventory that never
# ran, and a bare `llength` of pcall's own error string
# (`ERR:invalid command name "ase::cosim_db_inventory"`) is 4 -- which is
# exactly what a count-based assertion here used to want, so it passed with the
# whole implementation deleted.
eqcheck FS49-inventory-restores-the-current-db \
  "[lsort $paths] | [pcall xschem raw rawfile]" \
  "anlg.raw fs_agree.vcd fs_diverge.vcd fs_moved.vcd fs_nomatch.vcd | $rawf"
xschem raw clear

# ===========================================================================
# REF — the real reference cell, when the OA library tree is present
# ===========================================================================

set oadefs [file join $repo xschem_libraries_oa library.defs]
set refsch [file join $repo xschem_libraries_oa ngspice_verilog_cosim_ase \
                 tb_counter_wrapper schematic tb_counter_wrapper.sch]
if {[file isfile $oadefs] && [file isfile $refsch]} {
  set ::XSCHEM_LIBRARY_DEFS $oadefs
  set ::library_registry_defs_only 1
  xschem load $refsch
  set dref [ase::cosim_design_scan]
  eqcheck REF1-one-code-block [dict size $dref] 1
  eqcheck REF2-instance a1 [dict get $dref a1 inst]
  eqcheck REF3-cell counter [dict get $dref a1 cell]
  eqcheck REF4-module counter [dict get $dref a1 module]
  set refnl [file join $rd tb_counter_wrapper.spice]
  xschem netlist -noalert $refnl
  set f [open $refnl r]; set reftext [read $f]; close $f
  set rs [ase::cosim_scan_deck $reftext]
  eqcheck REF5-card-found [llength $rs] 1
  eqcheck REF6-card-model [dict get [lindex $rs 0] model] counter
  eqcheck REF7-card-so [dict get [lindex $rs 0] so] ./counter.so
  eqcheck REF8-card-inst [dict get [lindex $rs 0] insts] a1
  set STREF [dict replace [st $rd tb_counter_wrapper] design \
    {lib ngspice_verilog_cosim_ase cell tb_counter_wrapper view schematic}]
  set rm [ase::cosim_map $STREF $reftext]
  eqcheck REF9-map-vcd [dict get [lindex $rm 0] vcd] \
    [file join $rd tb_counter_wrapper_counter.vcd]
  eqcheck REF10-map-scope [dict get [lindex $rm 0] scope] TOP.counter
  eqcheck REF11-map-not-multi [dict get [lindex $rm 0] multi] 0
  # the scope hint must agree with the VCD the real shim actually wrote
  set realvcd $::env(HOME)/.xschem/simulations/counter.vcd
  if {[file isfile $realvcd]} {
    set f [open $realvcd r]; set vtxt [read $f 4096]; close $f
    check REF12-scope-hint-matches-the-real-vcd \
      [expr {[string first "\$scope module counter \$end" $vtxt] >= 0}] ""
  } else {
    puts "SKIPPED: REF12 (no $realvcd — run the mixed-signal sim first)"
  }
} else {
  puts "SKIPPED: group REF (xschem_libraries_oa/ngspice_verilog_cosim_ase absent)"
}

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_ase_cosim: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
