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
