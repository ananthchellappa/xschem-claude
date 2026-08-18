# ASE-L signal picking on AUTO-NAMED nets (issue 0154).
#
# An unlabeled net gets the engine's auto name `#netN` (get_unnamed_node,
# src/netlist.c) and the netlister emits it WITHOUT the '#' (`V1 net1 GND 1`).
# Two independent defects made such a net unplottable from Select On Design /
# Direct Plot:
#   A  ase::ui::sod_click resolved the clicked net through `xschem flylines at`,
#      whose A6 rule deliberately excludes '#' nets (src/flyline.c) -- correct
#      for fly-lines, wrong for signal picking. The click fell through to the
#      "v1 queues source currents only" notice.
#   B  ase::ui::sod_expr wrapped the raw token, emitting `v(#net1)` -- a name no
#      ngspice raw ever carries. Worse, `.save v(#net1)` makes ngspice abort the
#      whole analysis ("no data saved for Transient analysis; analysis not run"),
#      so ONE such row kills every other trace in the session too.
#   C  (the constraint the fix must respect) the issue-0153 color cue goes the
#      OTHER way: `xschem hilight_netname` finds `#net1` and does NOT find
#      `net1`. So the schematic token must stay raw and only the simulator
#      expression may be mapped.
#
# Legs (AN*):
#   AN1-AN4   RED before the fix: clicking the unnamed wire classifies as a
#             voltage pick, queues exactly `v(net1)`, prints no scope notice and
#             paints the wire in the trace color.
#   AN5-AN8   controls that must NOT move: named net, vsource body, non-source
#             device body (the test_ase_interact I6 contract), empty space.
#   AN9       fly-lines' own A6 exclusion is UNCHANGED (src/flyline.c untouched).
#   AN10-AN13 sod_expr mapping + the netlist witness that `net1` is the name
#             ngspice actually sees.
#   AN14-AN15 design lock for constraint C: the highlight verb accepts the RAW
#             token and rejects the stripped one, so the '#' strip must live in
#             sod_expr and never in the queued token.
#
# Fully headless: no DISPLAY, no ngspice, no ASE session. The picking mode is
# driven through a synthetic sod() record (plot mode, where the per-mode queue
# IS the witness) -- `outputs` mode would need a real session registry.
#
# Fixture: written into the scratch dir, symbols from the OA registry
# (xschem_libs_newsym/devices) via a synthetic library.defs -- the same idiom
# test_ase_interact.tcl / test_ase_plot.tcl use. One unlabeled net (-> #net1)
# and one labeled net (OUT) as the in-fixture control.
#
# Standalone repro from the repo ROOT:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_ase_unnamed_net.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# `list_hilights all` prints `path token value`; a NEGATIVE value is the
# "plain color of layer -value" form the issue-0153 picker uses.
proc hl_val {net} {
  set v {}
  foreach ln [split [xschem list_hilights all] "\n"] {
    set f [regexp -all -inline {\S+} $ln]
    if {[llength $f] >= 3 && [lindex $f 1] eq $net} { set v [lindex $f 2] }
  }
  return $v
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_unnamed_net]

if {[catch {

# --- fixture -----------------------------------------------------------------
# V1 --(unlabeled: #net1)-- R1 --(OUT)-- lab_pin ; V1's minus pin on GND.
set fxpath [file join $scratch unnamed_net.sch]
set f [open $fxpath w]
puts $f {v {xschem version=3.4.8RC file_version=1.3}}
puts $f {G {}}
puts $f {K {}}
puts $f {V {}}
puts $f {S {}}
puts $f {F {}}
puts $f {E {}}
puts $f {N 0 -30 0 -130 {}}
puts $f {N 0 -190 0 -230 {}}
puts $f {C {devices/vsource} 0 0 0 0 {name=V1 value=1}}
puts $f {C {devices/gnd} 0 30 0 0 {name=GND1 lab=GND}}
puts $f {C {devices/res} 0 -160 0 0 {name=R1 value=1k}}
puts $f {C {devices/lab_pin} 0 -230 0 0 {name=lOUT lab=OUT}}
# R2: a NON-source device with BOTH pins shorted onto one net (SHORT). It is the
# only shape that makes sod_net_at's wire-only gate observable: `nets -selected`
# on its body reports exactly ONE net, so a fallback guarded by list length
# alone would classify a device-body click as a voltage pick.
puts $f {N 200 -30 240 -30 {}}
puts $f {N 240 -30 240 30 {}}
puts $f {N 240 30 200 30 {}}
puts $f {C {devices/res} 200 0 0 0 {name=R2 value=1k}}
puts $f {C {devices/lab_pin} 240 -30 0 0 {name=lSHORT lab=SHORT}}
close $f

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

xschem load $fxpath

# world points on the fixture
set P_UNNAMED  {0 -80}     ;# the #net1 wire      -- the bug's click target
set P_NAMED    {0 -210}    ;# the OUT wire        -- control
set P_VSOURCE  {0 0}       ;# V1 body             -- current-probe control
set P_DEVICE   {0 -160}    ;# R1 body             -- v1-scope-notice control
set P_SHORTED  {200 0}     ;# R2 body, one net    -- the wire-gate control
set P_EMPTY    {300 -300}  ;# nothing there       -- select_at miss control

check "AN0 fixture has exactly one auto-named net" \
  [llength [lsearch -all -inline [xschem nets] {name {#net1}*}]] 1

# --- picking-mode harness ----------------------------------------------------
# sod_click needs only sod($key,flavor); in `plot` mode the queue array is the
# witness, so no ase::session_* registry is required.
set K test/unnamed
proc arm_mode {} {
  global K
  array unset ::ase::ui::sod $K,*
  array set ::ase::ui::sod [list \
    $K,flavor {save 0 plot 1} $K,mode plot $K,count 0 $K,queue {} $K,qcolors {}]
  set ::echoed {}
  catch {xschem unhilight_all}
}
proc queue {}  { return $::ase::ui::sod($::K,queue) }
proc qcount {} { return $::ase::ui::sod($::K,count) }
proc noticed {} {
  foreach l $::echoed { if {[string match {*source currents only*} $l]} { return 1 } }
  return 0
}
rename ::ciw_echo ::__real_ciw_echo
proc ::ciw_echo {args} { lappend ::echoed [lindex $args 0] }

# the color the FIRST pick of a fresh queue will carry (issue 0153)
set col1 [lindex [wviewer::predict_colors $K 1] end]

# --- AN1-AN4: the bug ---------------------------------------------------------
arm_mode
eval ase::ui::sod_click $K $P_UNNAMED
check "AN1 unnamed-net click queues the mapped voltage expression" \
  [queue] {v(net1)}
check "AN2 unnamed-net click prints no 'source currents only' notice" [noticed] 0
check "AN3 unnamed-net click counts one queued signal" [qcount] 1
check "AN4 unnamed-net click paints the wire in its future trace color" \
  [hl_val #net1] [expr {-$col1}]

# --- AN5-AN8: controls that must not move ------------------------------------
arm_mode
eval ase::ui::sod_click $K $P_NAMED
check "AN5 named-net click still queues v(out)" [queue] {v(out)}
check "AN5 named-net click still paints the net" [hl_val OUT] [expr {-$col1}]

arm_mode
eval ase::ui::sod_click $K $P_VSOURCE
check "AN6 vsource body still queues the source current" [queue] {i(v1)}
check "AN6 vsource body prints no scope notice" [noticed] 0

arm_mode
eval ase::ui::sod_click $K $P_DEVICE
check "AN7 non-source device body still queues NOTHING (I6 contract)" [queue] {}
check "AN7 non-source device body still prints the v1-scope notice" [noticed] 1

# the wire-only gate: R2's body sits on exactly ONE net, so `nets -selected`
# returns a single row. Only the hit-TYPE test stops it being read as a
# voltage pick.
eval xschem select_at $P_SHORTED
check "AN7b the shorted device really does report a single net" \
  [llength [xschem nets -selected]] 1
arm_mode
eval ase::ui::sod_click $K $P_SHORTED
check "AN7b shorted-pin device body still queues NOTHING" [queue] {}
check "AN7b shorted-pin device body still prints the v1-scope notice" [noticed] 1

arm_mode
eval ase::ui::sod_click $K $P_EMPTY
check "AN8 empty-space click queues nothing" [queue] {}
check "AN8 empty-space click prints no notice (early return on the miss)" \
  [noticed] 0

# --- AN9: fly-lines' A6 exclusion is UNCHANGED --------------------------------
# The fix must NOT relax src/flyline.c: a #net cluster is unique per physical
# cluster and can never connect implicitly, so drawing a star for it is
# meaningless. (tests/headless/test_flylines.sh owns the authoritative rails;
# these are the ASE-side guard that the fix did not reach for that lever.)
set empty_dict {net {} global 0 capped 0 members {} clusters {} segments {}}
check "AN9 flylines at still excludes the auto-named net" \
  [eval xschem flylines at $P_UNNAMED] $empty_dict
check "AN9 flylines net #net1 still excluded by name" \
  [xschem flylines net {#net1}] $empty_dict
check "AN9 flylines still resolves a NAMED net at the same depth" \
  [dict get [eval xschem flylines at $P_NAMED] net] OUT

# --- AN10-AN13: the expression mapping ---------------------------------------
## RESTATED, casemode batch item 9 (same ids, same expected strings): `sod_expr`
## no longer folds unconditionally, so the mode is now a REQUIRED third argument
## and these four calls name it. `fold` is DECISIONS A1's default everywhere and
## every expected value below is unchanged byte for byte — which is the point of
## restating them here rather than deleting them: they are 0154's assertions AND
## this item's A1 guard. The preserve/distinguish columns live in
## test_ase_sod_case.tcl (SC192-SC194d).
check "AN10 sod_expr strips the auto-name marker" \
  [ase::ui::sod_expr voltage {#net1} fold] {v(net1)}
check "AN11 sod_expr strips AND lowercases" \
  [ase::ui::sod_expr voltage {#NET1} fold] {v(net1)}
check "AN12 sod_expr leaves a named net alone" \
  [ase::ui::sod_expr voltage OUT fold] {v(out)}
check "AN12 sod_expr leaves an instance name alone" \
  [ase::ui::sod_expr current V1 fold] {i(v1)}

# the netlist is the authority on what ngspice will call that node
set ::netlist_dir [file join $scratch nl]
file mkdir $::netlist_dir
xschem set netlist_type spice
xschem netlist
set fh [open [file join $::netlist_dir unnamed_net.spice] r]
set deck [read $fh]
close $fh
check_true "AN13 netlist emits the node WITHOUT the '#'" \
  [regexp {(^|\n)V1 net1 GND } $deck]
check_true "AN13 netlist never emits a '#' node" \
  [expr {![regexp {\#net} $deck]}]

# --- AN14-AN15: design lock for the raw-token constraint ----------------------
# dp_hilight must keep receiving the RAW schematic token. If a future change
# strips the '#' at the token level instead of in sod_expr, AN15 goes green and
# AN14 goes red -- and the color cue dies silently (both call sites are
# catch-guarded).
catch {xschem unhilight_all}
check "AN14 dp_hilight accepts the RAW auto-name" \
  [ase::ui::dp_hilight voltage {#net1} 4] 1
check "AN14 ... and it lands on the net" [hl_val #net1] -4
catch {xschem unhilight_all}
ase::ui::dp_hilight voltage net1 4
check "AN15 the STRIPPED name highlights nothing (so the strip must not move)" \
  [concat [hl_val net1] [hl_val #net1]] {}

rename ::ciw_echo {}
rename ::__real_ciw_echo ::ciw_echo

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
