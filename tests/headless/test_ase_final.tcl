# ASE-L de-clutter proof (P4 of doc/claude/specs/ase_l.md) — the batch
# acceptance gate. Drives the COMMITTED cell
# sky130A/xschem_libs/sky130_tests/test_nfet_final (schematic = circuit ONLY:
# M1 + symbolic Vds/Vgs sources + gnd + net labels; no corner, no
# simulator_commands, no .control) plus its committed ngspice_state1 state
# view end-to-end through the PUBLIC ase:: API only:
#   state_load -> cell_views -> netlist -> render_deck hook -> run -> wait ->
#   last_result, expecting Id ~ 409.68 uA (|Id*1e6 - 409.68| < 1.0).
# Checks:
#   F1/F2  committed state file loads; version/simulator/design as committed
#   F3     round-trip byte-stability (committed file is state_save-canonical)
#   F4     ngspice_state1 + schematic enumerated by cell_views
#   F5     de-clutter at source (the committed .sch carries no sim clutter)
#   F6     ase::netlist artifact + symbolic V1/V2 lines
#   F7     THE DE-CLUTTER PROOF: netlist artifact BEFORE any deck append has
#          no .control, no .lib, and ends at .end
#   F8     deck render expands $::SKYWATER_MODELS -> absolute model path, and
#          carries .param/.options/.save/.control op
#   F9/F10 real ngspice run (guarded on auto_execok): exit 0, log data rows,
#          Id within 1 uA of 409.68 uA  <- the acceptance gate
#   F10a   the sky130 op_annot descriptor is registered (non-vacuity guard for
#          everything below)
#   F11-F17 THE S4 ACCEPTANCE, END TO END: ase::netlist with save_op_params 1
#          primes the op-cards cache; render_deck carries op_annot::save_cards
#          into the deck VERBATIM; a real ngspice run writes a raw whose device
#          -parameter vectors are EXACTLY op_annot::vector of the emitted cards;
#          the node voltages SURVIVE in the same raw (invariant I2); and
#          op_annot::text M1 renders six REAL NUMBERS, none of them 0/nan/inf
#   F18/F19 the before-state control (gate off: zero cards, the raw's only
#          device vector is savecurrents' card-less id, gm/gds/vgs/vth/vds all
#          blank) and the discoverability nudge that fires while the gate is off
#   F20    invariant I4: the design buffer stays unmodified and the committed
#          .sch is byte-unchanged across the whole section
#
# The model path is resolved exactly like sky130A/cadence_style_rc does:
# the test sets ::SKYWATER_MODELS to <repo>/sky130A/models/libs.tech/combined
# and the STATE FILE stores the portable $::SKYWATER_MODELS/... form.
# Libraries come from a scratch library.defs pointing at the REAL committed
# trees (never the pre-batch-dirty workarea library.defs). The only state
# mutation is the rundir override into the scratch dir (hermetic run
# location through the public schema — no sim content is added anywhere).
#
# True headless (no X). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch ase_final]

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]
set modelsdir [file join $repo sky130A models libs.tech combined]

# model resolution exactly as sky130A/cadence_style_rc sets it (decision D2)
set ::SKYWATER_MODELS $modelsdir

# --- scratch registry pointing at the REAL committed trees (decision D3) -----
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

if {[catch {

# --- F1/F2: the committed state file loads as committed ----------------------
set st [ase::state_load $statefile]
check "F1 state version is 1" [dict get $st version] 1
check "F1 state simulator is ngspice" [dict get $st simulator] ngspice
check "F2 state design is the schematic view" [dict get $st design] \
  {lib sky130_tests cell test_nfet_final view schematic}

# --- F3: committed file is state_save-canonical (round-trip byte-identity) ---
ase::state_save [file join $scratch roundtrip.state] $st
set f [open $statefile rb];                       set a [read $f]; close $f
set f [open [file join $scratch roundtrip.state] rb]; set b [read $f]; close $f
check_true "F3 committed state file round-trips byte-identical" [expr {$a eq $b}]

# --- F4: the view is a first-class citizen of cell_views ---------------------
set views [xschem cell_views sky130_tests test_nfet_final]
check_true "F4 cell_views lists ngspice_state1" \
  [expr {[lsearch -exact $views ngspice_state1] >= 0}]
check_true "F4 cell_views lists schematic" \
  [expr {[lsearch -exact $views schematic] >= 0}]

# --- F5: de-clutter at source (committed schematic bytes) --------------------
set f [open $schfile r]; set schtext [read $f]; close $f
check_true "F5 .sch has no simulator_commands" \
  [expr {![string match {*simulator_commands*} $schtext]}]
check_true "F5 .sch has no corner" [expr {![string match {*corner*} $schtext]}]
check_true "F5 .sch has no .control" [expr {![string match {*.control*} $schtext]}]

# --- F6: netlist through the public API (hermetic rundir, decision D7) -------
set rundir [file normalize [file join $scratch run]]
dict set st rundir $rundir
set nl [ase::netlist $st]
check "F6 netlist path" $nl [file join $rundir test_nfet_final.spice]
check_true "F6 netlist file exists" [file isfile $nl]
set f [open $nl r]; set nltext [read $f]; close $f
check_true "F6 netlist contains XM1" [string match {*XM1*} $nltext]
check_true "F6 symbolic V1 D GND Vds line" \
  [regexp -line {^V1\s+D\s+GND\s+Vds\s*$} $nltext]
check_true "F6 symbolic V2 G GND Vgs line" \
  [regexp -line {^V2\s+G\s+GND\s+Vgs\s*$} $nltext]

# --- F7: THE DE-CLUTTER PROOF (netlist artifact BEFORE any deck append) ------
check_true "F7 netlist has no .control line" \
  [expr {![regexp -line {^\.control} $nltext]}]
check_true "F7 netlist has no .lib line" [expr {![regexp -line {^\.lib } $nltext]}]
check "F7 last non-blank netlist line is .end" \
  [string trim [lindex [split [string trimright $nltext "\n"] "\n"] end]] {.end}

# --- F8: deck render (public hook) expands the model path + carries the state
set render [ase::backend_hook ngspice render_deck]
set deck [$render $st $nltext]
check_true "F8 deck .lib has the EXPANDED absolute model path + tt" \
  [string match "*.lib [file join $modelsdir sky130.lib.spice] tt*" $deck]
check_true "F8 deck has no raw \$::SKYWATER_MODELS" \
  [expr {![string match {*$::SKYWATER_MODELS*} $deck]}]
check_true "F8 deck .param Vgs=1.8" [regexp -line {^\.param Vgs=1\.8$} $deck]
check_true "F8 deck .param Vds=1.0" [regexp -line {^\.param Vds=1\.0$} $deck]
check_true "F8 deck .options savecurrents" \
  [regexp -line {^\.options savecurrents$} $deck]
check_true "F8 deck .save -i(v1)" [string match {*.save -i(v1)*} $deck]
set cidx [string first "\n.control\n" $deck]
set oidx [string first "\nop\n" $deck]
set eidx [string first "\n.endc\n" $deck]
check_true "F8 op line inside the .control block" \
  [expr {$cidx >= 0 && $oidx > $cidx && $eidx > $oidx}]

# --- F9/F10: real ngspice run — THE ACCEPTANCE GATE (guarded) ----------------
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: F9/F10 run leg (ngspice not found)"
} else {
  set id [ase::run $st]
  set ec [ase::wait $id]
  check "F9 ngspice exit code 0" $ec 0
  check_true "F9 ase deck file written" \
    [file isfile [file join $rundir test_nfet_final_ase.spice]]
  set logf [file join $rundir test_nfet_final_ase.log]
  set logtext {}
  if {[file isfile $logf]} { set f [open $logf r]; set logtext [read $f]; close $f }
  check_true "F9 log file written with data rows" \
    [expr {[file isfile $logf] && [string match {*No. of Data Rows*} $logtext]}]
  set res [ase::last_result]
  set idok 0
  if {[dict exists $res id]} {
    set v [dict get $res id]
    if {abs($v * 1e6 - 409.68) < 1.0} { set idok 1 }
  }
  check_true "F10 Id within 1 uA of 409.68 uA (expect 4.096837e-04)" $idok
  if {!$idok} { puts "  F10 last_result: $res" }
}

# ============================================================================
# F10a-F20: the OP save cards, END TO END, on a real ngspice run (plan step S4)
# ============================================================================
# doc/claude/specs/op_annotation.md S4 / issue 0617 -- the user's exact
# sequence: enable ONLY the OP analysis, Netlist-and-Run, press 6. Before S4 the
# rendered deck asked for nothing, so the raw held no device parameters and
# every `params` row rendered blank.
#
# ⚠ A ROW THAT ONLY ASSERTS `.save` LINES APPEAR IN A FILE IS NOT ENOUGH.
# Spec landmine 2/9: a card naming a device that does not exist fails SILENTLY
# -- under this deck's `.control … write … .endc` idiom, ngspice exits 0, writes
# the raw, prints nothing, and leaves a `dims=0` column of 0.0 under exactly the
# requested name. So these rows go all the way: run the real simulator, read the
# raw header back, and require op_annot::text to render REAL NUMBERS.
#
# ⚠ AND `.options savecurrents` IS A TRAP FOR THE NON-VACUITY CONTROL. This
# fixture's committed state carries it, and MEASURED on this tree it puts
# `i(@m.xm1.msky130_fd_pr__nfet_01v8[id])` in the raw with NO card present. So
# "device-parameter vectors > 0" passes card-less, and `op_annot::text M1`
# already renders `id` today. F18 pins that exact before-state, and F16/F17
# therefore assert on the FIVE rows savecurrents cannot supply -- gm gds vgs
# vth vds -- which are the rows the user reported blank.
#
# Descriptors are PDK data: sourcing sky130A/sky130_procs.tcl is what registers
# the nmos/pmos descriptors (guarded on op_annot::register at :317). Without it
# op_annot::save_cards returns {} at rc=0 with counts {0 0 0} and every row here
# would pass vacuously -- F10a is that non-vacuity guard.
source [file join $repo sky130A sky130_procs.tcl]
check_true "F10a sky130 nmos descriptor registered (non-vacuity guard)" \
  [expr {[op_annot::descriptor nmos] ne {}}]

# I4 witness: nothing in this section may write the schematic.
set f [open $schfile rb]; set f20_sch_before [read $f]; close $f
set f20_bak [file join $cellroot schematic test_nfet_final~.sch]
set f20_bak_before [file exists $f20_bak]

# the raw header's Variables: block, as a list of vector names
proc f_rawnames {raw} {
  if {![file exists $raw]} { return {} }
  set fh [open $raw rb]; set h [read $fh 4000000]; close $fh
  set cut [string first "Binary:" $h]
  if {$cut < 0} { set cut [string length $h] }
  set names {}; set invars 0
  foreach l [split [string range $h 0 $cut] "\n"] {
    if {[string match {Variables:*} $l]} { set invars 1; continue }
    if {[string match {Binary:*} $l]} { break }
    if {$invars && [regexp {^\s*\d+\s+(\S+)} $l -> nm]} { lappend names $nm }
  }
  return $names
}
# a DEVICE-PARAMETER vector is `…@…[…]…`; test that FIRST, because the voltage
# kind is `v(@m.…[vth])` and would otherwise be counted as a node voltage
proc f_devvecs {names} {
  set d {}
  foreach n $names {
    if {[string first {@} $n] >= 0 && [string first {[} $n] >= 0} { lappend d $n }
  }
  return [lsort $d]
}
proc f_nodevecs {names} {
  set v {}
  foreach n $names {
    if {[string first {@} $n] >= 0 && [string first {[} $n] >= 0} { continue }
    if {[string match {v(*} $n]} { lappend v $n }
  }
  return [lsort $v]
}
# `.save @…` cards in a deck / block, bare (no `.save ` prefix)
proc f_cards {text} {
  set c {}
  foreach l [split $text "\n"] {
    if {[regexp {^\.save\s+(@\S+)$} $l -> nm]} { lappend c $nm }
  }
  return [lsort $c]
}
# label -> rendered value, from op_annot::text's `lbl = value` rows
proc f_rows {txt} {
  set d [dict create]
  foreach l [split [string trimright $txt "\n"] "\n"] {
    if {[regexp {^(\S+)\s*=\s*(.*)$} $l -> lbl val]} {
      dict set d $lbl [string trim $val]
    }
  }
  return $d
}
# Every new-API call is catch-wrapped, so a tree without the seam reds the row
# that names it instead of aborting the suite at the first missing proc.
proc cx {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR: $r" }
  return $r
}
# THE R4 ASYMMETRY IS THE THING BEING TESTED: the card is written BARE
# (`@dev[p]`) and comes back from ngspice WRAPPED by the parameter's own type
# (`i(…)` / `v(…)` / bare). So the two expected sets are built from the SAME
# descriptor through the SAME one name builder -- invariant I1, two consumers.
set f_expect_vecs {}
set f_expect_vecs_bare {}
foreach row [dict get [op_annot::descriptor nmos] params] {
  lappend f_expect_vecs [op_annot::vector M1 [lindex $row 1] [lindex $row 2]]
  lappend f_expect_vecs_bare "[op_annot::devpath M1]\[[lindex $row 1]\]"
}
set f_expect_vecs [lsort $f_expect_vecs]
set f_expect_vecs_bare [lsort $f_expect_vecs_bare]

# --- F19: the gate is OFF by default, so it must be DISCOVERABLE -------------
# 0617's report-what-was-not-delivered channel at the emit end: one line, on
# exactly the configuration the user reported from (an `op` analysis enabled and
# the gate off). Gated on `op` so a tran/ac/digital user never sees it.
set f_offdir [file normalize [file join $scratch runoff]]
set stoff [ase::state_load $statefile]
dict set stoff rundir $f_offdir
set ::f_echo {}
if {[info commands ::f_saved_ciw_echo] eq {}} {
  if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::f_saved_ciw_echo }
  proc ::ciw_echo {msg {tag {}}} { lappend ::f_echo $msg }
}
set nloff [ase::netlist $stoff]
set f19_hits 0
foreach m $::f_echo { if {[string match {*Outputs*Save All*} $m]} { incr f19_hits } }
if {[info commands ::f_saved_ciw_echo] ne {}} {
  catch {rename ::ciw_echo {}}
  rename ::f_saved_ciw_echo ::ciw_echo
}
check "F19 gate off + op enabled nudges ONCE, naming Outputs > Save All" \
  $f19_hits 1

# --- F18: the BEFORE state, pinned exactly (the non-vacuity control) ---------
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: F11-F18/F20 run legs (ngspice not found)"
} else {
  set idoff [ase::run $stoff]
  check "F18 gate off: ngspice exit code 0" [ase::wait $idoff] 0
  set f [open [file join $f_offdir test_nfet_final_ase.spice] r]
  set deckoff [read $f]; close $f
  check "F18 gate off: the deck asks for NO device parameters" \
    [llength [f_cards $deckoff]] 0
  set rawhook [ase::backend_hook ngspice raw_file]
  set rawoff [$rawhook $stoff]
  set namesoff [f_rawnames $rawoff]
  check_true "F18 gate off: the raw is still written" [file isfile $rawoff]
  # exactly ONE device-parameter vector, and it is savecurrents' card-less
  # `i(…[id])` -- this is why "device vectors > 0" is not a valid acceptance
  check "F18 gate off: the ONLY device vector is savecurrents' card-less id" \
    [f_devvecs $namesoff] \
    [list [op_annot::vector M1 id 0]]
  xschem annotate_op $rawoff 0 op
  set rowsoff [f_rows [op_annot::text M1]]
  set f18_blank {}
  foreach lbl {gm gds vgs vth vds} {
    if {[dict exists $rowsoff $lbl] && [dict get $rowsoff $lbl] ne {}} {
      lappend f18_blank $lbl
    }
  }
  check "F18 gate off: gm/gds/vgs/vth/vds all render BLANK (issue 0617)" \
    $f18_blank {}

  # --- F11: ase::netlist with the gate ON primes the op-cards cache ----------
  set f_ondir [file normalize [file join $scratch runon]]
  set ston [ase::state_load $statefile]
  dict set ston rundir $f_ondir
  dict set ston save_op_params 1
  set nlon [ase::netlist $ston]
  set f [open $nlon r]; set nlontext [read $f]; close $f
  set blk [cx {ase::op_cards_for $nlontext}]
  set blines [split [string trimright $blk "\n"] "\n"]
  check "F11 the cache holds a block whose leader is the `.save all` dot-card" \
    [lindex $blines 0] {.save all}
  check "F11 the block carries one BARE card per descriptor param" \
    [f_cards $blk] $f_expect_vecs_bare

  # --- F12: nothing is lost, added, reordered or deduped on the way in ------
  set deckon [$render $ston $nlontext]
  # the card count rides along so the row cannot pass vacuously with BOTH sides
  # empty (which is exactly the pre-S4 state)
  check "F12 the deck's device cards are EXACTLY the block's device cards" \
    [list [f_cards $deckon] [llength [f_cards $blk]]] \
    [list [f_cards $blk] [llength $f_expect_vecs_bare]]
  check "F12 the deck carries the block's `.save all` leader too (I2/R2)" \
    [regexp -all -line {^\.save all$} $deckon] 1

  # --- F13-F17: the real simulator, the real raw, the real numbers ----------
  set idon [ase::run $ston]
  check "F13 gate on: ngspice exit code 0" [ase::wait $idon] 0
  set rawon [$rawhook $ston]
  check_true "F13 gate on: the raw file EXISTS (spec R5)" [file isfile $rawon]
  set nameson [f_rawnames $rawon]
  set f [open [file join $f_ondir test_nfet_final_ase.spice] r]
  set deckfile [read $f]; close $f
  check "F14 every emitted card materialised: the raw's device vectors are\
 EXACTLY op_annot::vector of the emitted cards" \
    [f_devvecs $nameson] $f_expect_vecs
  check "F14 the deck ngspice actually ran carries those cards" \
    [f_cards $deckfile] $f_expect_vecs_bare
  # I2: the node voltages the pinexpr/annotation rows already had must SURVIVE.
  # They do only because the block carries its own `.save all` leader --
  # measured on this exact committed state (save_all_v 0): block WITH the leader
  # -> 5 node v(); block WITHOUT -> 0.
  check_true "F15 node voltages survive in the same raw (invariant I2)" \
    [expr {[lsearch -exact [f_nodevecs $nameson] {v(d)}] >= 0 &&
           [lsearch -exact [f_nodevecs $nameson] {v(g)}] >= 0}]
  xschem annotate_op $rawon 0 op
  set rowson [f_rows [op_annot::text M1]]
  set f16_missing {}
  foreach lbl {id gm gds vgs vth vds} {
    set v {}
    if {[dict exists $rowson $lbl]} { set v [dict get $rowson $lbl] }
    if {![regexp {[0-9]} $v]} { lappend f16_missing $lbl }
  }
  check "F16 op_annot::text M1 renders a REAL NUMBER on all six rows\
 (issue 0617's end state)" $f16_missing {}
  # landmine 2: a wrong device name reads as a converged 0, not as a blank
  set f17_bad {}
  foreach lbl {id gm gds vgs vth vds} {
    set v {}
    if {[dict exists $rowson $lbl]} { set v [dict get $rowson $lbl] }
    if {$v eq {} || $v eq {0} || $v eq {0.0} ||
        [string match -nocase {*nan*} $v] || [string match -nocase {*inf*} $v]} {
      lappend f17_bad [list $lbl $v]
    }
  }
  check "F17 no rendered value is blank, 0, 0.0, nan or inf (landmine 2)" \
    $f17_bad {}

  # --- F20: invariant I4 -- the overlay never modifies the schematic ---------
  check "F20 the design buffer is still unmodified" [xschem get modified] 0
  set f [open $schfile rb]; set f20_sch_after [read $f]; close $f
  check_true "F20 the committed .sch is byte-unchanged" \
    [expr {$f20_sch_before eq $f20_sch_after}]
  check "F20 no autosave backup appeared beside the committed cell" \
    [expr {$f20_bak_before || ![file exists $f20_bak]}] 1
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
