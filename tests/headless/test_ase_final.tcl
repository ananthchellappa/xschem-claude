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
#
# ============================================================================
# ⚠ ISSUE 0636 RESHAPED THIS ROW, AND THE MEASUREMENT IS WHY
# ============================================================================
# `ase::netlist` fires this nudge on EVERY op netlist with no opt-out. Measured
# on this very cell: F6 netlists, F9's `ase::run` netlists again, and F19's own
# call is the THIRD -- three identical lines into the CIW pane and the action
# log, in ONE session, about ONE cell, for a feature the user may have decided
# not to use. The fix is a once-per-session latch keyed on the design cellview
# plus a `::ase_op_card_nudge` off switch beside the `::ase_eng_notation`
# precedent (ase.tcl:177), with `ase::op_cards_nudge_reset` as the test seam.
#
# That latch would make THIS row read 0, because it collects around the third
# netlist of the session. So F19 keeps its claim -- one netlist, one nudge --
# and takes the reset that makes the claim meaningful; F19b is the row the
# latch actually earns. F19 and F19e are GREEN BEFORE THE CHANGE (controls):
# `cx` keeps the not-yet-existing reset inert, and the `op`-analysis gate is
# already shipped.

## One netlist, with the CIW collector armed: -> how many nudges it produced.
## Restores ::ciw_echo on every exit path, including a raising ase::netlist.
proc f_nudges {state} {
  set ::f_echo {}
  if {[info commands ::f_saved_ciw_echo] eq {}} {
    if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::f_saved_ciw_echo }
    proc ::ciw_echo {msg {tag {}}} { lappend ::f_echo $msg }
  }
  set rc [catch {ase::netlist $state} e]
  if {[info commands ::f_saved_ciw_echo] ne {}} {
    catch {rename ::ciw_echo {}}
    rename ::f_saved_ciw_echo ::ciw_echo
  }
  if {$rc} { return "ERR: $e" }
  set n 0
  foreach m $::f_echo { if {[string match {*Outputs*Save All*} $m]} { incr n } }
  return $n
}

# ⚠ READ BEFORE ANYTHING TOUCHES IT. F19c sets this variable, so the default has
# to be sampled first or the row is asserting its own assignment. The `set_ne`
# idiom is F0's in test_ase_core: on by default, so nobody LOSES the nudge.
set f19d_default [expr {[info exists ::ase_op_card_nudge] ? $::ase_op_card_nudge : {NO-VAR}}]
check "F19d 0636 ::ase_op_card_nudge defaults to 1 at ase.tcl source time" \
  $f19d_default 1

set f_offdir [file normalize [file join $scratch runoff]]
set stoff [ase::state_load $statefile]
dict set stoff rundir $f_offdir
cx {ase::op_cards_nudge_reset}
check "F19 gate off + op enabled nudges ONCE, naming Outputs > Save All" \
  [f_nudges $stoff] 1

# ⚠ THE ROW THE LATCH EARNS. Same cell, same session, no reset: silence. Today
# this reads 1 -- the third of the three lines the measurement above counted.
check "F19b 0636 a SECOND netlist of the same cell in the same session nudges 0 times" \
  [f_nudges $stoff] 0

# ⚠ AND AN OFF SWITCH, because a user who has decided not to use the feature
# should be able to stop being advertised at. Parked and restored: every row
# after this one expects the shipped default.
set f19c_had [info exists ::ase_op_card_nudge]
if {$f19c_had} { set f19c_val $::ase_op_card_nudge }
set ::ase_op_card_nudge 0
cx {ase::op_cards_nudge_reset}
set f19c_dir [file normalize [file join $scratch runoff_c]]
set st19c [ase::state_load $statefile]
dict set st19c rundir $f19c_dir
check "F19c 0636 ::ase_op_card_nudge 0 silences it even with the latch reset" \
  [f_nudges $st19c] 0
if {$f19c_had} { set ::ase_op_card_nudge $f19c_val } else { unset ::ase_op_card_nudge }

# ⚠ GREEN BEFORE AND AFTER -- the PRE-EXISTING gate must not be lost to the new
# one. A tran/ac/digital user never asked for device OP parameters and must
# never see this line, latch or no latch.
cx {ase::op_cards_nudge_reset}
set f19e_dir [file normalize [file join $scratch runoff_e]]
set st19e [ase::state_load $statefile]
dict set st19e rundir $f19e_dir
set f19e_an {}
foreach a [ase::state_get $st19e analyses] {
  if {[ase::state_get $a type] eq {op}} { dict set a enabled 0 }
  lappend f19e_an $a
}
dict set st19e analyses $f19e_an
check "F19e 0636 a state with `op` DISABLED still nudges 0 times (the shipped gate)" \
  [list [ase::op_analysis_enabled $st19e] [f_nudges $st19e]] {0 0}
cx {ase::op_cards_nudge_reset}

# ============================================================================
# F19f-F19m -- ISSUE 0648: THE NUDGE GOES SILENT ON THE RE-RUN THE USER MAKES
#                          AFTER ACTING ON IT
# ============================================================================
# The user's verbatim sequence, 2026-08-23, on sky130_test_ase/tb_bandgap:
# "No OP info is available with key 6 ... Then, I went to Outputs > Save and
# checked the 'Save device OP parameters'. I re-ran the sim and still don't get
# OP info." Re-measured at HEAD on that exact cell: run 1 (gate off) emitted the
# nudge, run 2 (gate STILL off, because the tick never committed) emitted
# NOTHING. `ase::op_nudged` (ase.tcl:534) is keyed on lib/cell/view ALONE, is
# taken at ase.tcl:561 and is released NOWHERE in src/ -- `grep -rn
# op_cards_nudge_reset src/` returns exactly one line, the proc definition, and
# its only callers anywhere are the four `cx` lines above. So the one message
# whose whole job is to report the gate being off is suppressed on precisely
# the run where the user has already tried to turn it on and needs to be told
# they failed.
#
# ⚠ THE ISSUE'S OWN FIRST SUGGESTION -- "key it on cellview AND gate state" --
# DOES NOT SATISFY ITS OWN ACCEPTANCE ROW. In the user's sequence the gate is
# OFF on BOTH runs, so (cell, off) is the same key twice and run 2 is still
# silent. The re-arm trigger has to be the user's ACT, not the gate's value:
# a save_op_params CHANGE seen by ase::session_update (F19g/F19i), and -- the
# GUI half, in test_ase_dialogs GE10f -- an opparams tick DISCARDED by the
# Save All dialog.
#
# F19h and F19m are the 0636 guard rails: the re-arm must fire on a CHANGE and
# on nothing else (session_update fires on every pane mutation), and it must
# not become a new writer of `save_op_params` -- OFF stays `{}`, never `0`, or
# the key lands in all 104 committed .state files.
#
# GREEN BEFORE THE CHANGE, and deliberately so (controls, not evidence):
# F19h (the latch is held today, so "does not re-arm" is trivially true),
# F19m (nothing writes the key today), F19k and F19l (the success line already
# exists at ase.tcl:660, landed in 44f52f9a -- issue 0648 section 3 is REFUTED;
# these two rows PIN it, they do not ask for it, and they are what SAB-F reds).

## One netlist with the CIW collector armed -> the RAW list of echoed messages.
## Same park/restore engine as f_nudges, which counts one pattern only; the
## success-line rows need the whole transcript to prove "exactly once".
proc f_echo_run {state} {
  set ::f_echo {}
  if {[info commands ::f_saved_ciw_echo] eq {}} {
    if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::f_saved_ciw_echo }
    proc ::ciw_echo {msg {tag {}}} { lappend ::f_echo $msg }
  }
  set rc [catch {ase::netlist $state} e]
  if {[info commands ::f_saved_ciw_echo] ne {}} {
    catch {rename ::ciw_echo {}}
    rename ::f_saved_ciw_echo ::ciw_echo
  }
  if {$rc} { return [list "ERR: $e"] }
  return $::f_echo
}
proc f_matches {msgs pat} {
  set h {}
  foreach m $msgs { if {[string match $pat $m]} { lappend h $m } }
  return $h
}

# --- F19f: ONE latch-key builder (invariant I1) ------------------------------
# ase.tcl:555-558 builds the key inline inside op_cards_nudge_ok, so the re-arm
# would have to rebuild it independently -- the exact two-builders shape I1
# forbids, and the drift would be SILENT (a re-arm that unsets a key nobody
# ever takes looks like a working fix and nudges nothing).
set f19f_design [ase::state_get $stoff design]
check "F19f 0648 op_cards_nudge_key returns the DESIGN cellview {lib cell view}" \
  [cx {ase::op_cards_nudge_key $stoff}] \
  [list [ase::state_get $f19f_design lib] [ase::state_get $f19f_design cell] \
        [ase::state_get $f19f_design view]]

# --- F19n: the latch is PER CELLVIEW, asserted BEHAVIOURALLY -----------------
# Verify-B's finding, 2026-08-23: under SAB-H (op_cards_nudge_key collapsed to
# {}) F19f went red but F19g and GE10f stayed GREEN, because the take and the
# re-arm share the one builder and a uniformly-wrong key is self-consistent.
# That is invariant I1 working -- and it means NO row observed the key's SCOPE.
# Nothing in either suite ever nudged two cellviews in one process, so a
# wrongly-scoped key would let cellview A's nudge permanently eat cellview B's:
# the exact class of user-visible silence 0648 was filed about, caught only by
# a return-value equality. This row makes it behavioural.
cx {ase::op_cards_nudge_reset}
set f19n_b $stoff
set f19n_d [ase::state_get $f19n_b design]
dict set f19n_d cell f19n_a_different_cell
dict set f19n_b design $f19n_d
check "F19n 0648 the latch is PER CELLVIEW: taking it for one cell does NOT\
 silence a DIFFERENT cell (take, hold, other cell still speaks)" \
  [list [cx {ase::op_cards_nudge_ok $stoff}] \
        [cx {ase::op_cards_nudge_ok $stoff}] \
        [cx {ase::op_cards_nudge_ok $f19n_b}]] \
  {1 0 1}

# --- F19g: THE USER'S SEQUENCE, HEADLESS -------------------------------------
# Session registry only -- nothing is written to the committed .state file (no
# session_save anywhere in this block; F3's byte-identity row is upstream of it
# and stays green).
cx {ase::op_cards_nudge_reset}
set f19g_key [ase::session_key f19 latch rearm]
ase::session_open $f19g_key $statefile
set f19g_st [ase::session_state $f19g_key]
set f19g_take [list [cx {ase::op_cards_nudge_ok $f19g_st}] \
                    [cx {ase::op_cards_nudge_ok $f19g_st}]]
dict set f19g_st save_op_params 1
ase::session_update $f19g_key $f19g_st
check "F19g 0648 THE ACCEPTANCE ROW: a session_update that turns save_op_params\
 ON RE-ARMS the nudge (take, hold, then speak again)" \
  [list $f19g_take [cx {ase::op_cards_nudge_ok [ase::session_state $f19g_key]}]] \
  {{1 0} 1}

# --- F19h: the 0636 noise guard ----------------------------------------------
# session_update is called by toggle_flag, the variables/outputs/analyses
# editors and the temperature field. An UNCONDITIONAL clear there re-creates
# exactly the three-identical-lines-per-session defect 0636 was filed about.
# (F19g's own check consumed the re-armed turn, so the latch is held again.)
set f19h_st [ase::session_state $f19g_key]
dict set f19h_st temperature 42
ase::session_update $f19g_key $f19h_st
check "F19h 0636 NOISE GUARD: a session_update that leaves save_op_params alone\
 does NOT re-arm" \
  [cx {ase::op_cards_nudge_ok [ase::session_state $f19g_key]}] 0

# --- F19i: the reverse edge ---------------------------------------------------
# Turning the gate back OFF is just as much "the user acted on this setting".
set f19i_st [ase::session_state $f19g_key]
dict set f19i_st save_op_params {}
ase::session_update $f19g_key $f19i_st
check "F19i 0648 the reverse edge re-arms too: save_op_params 1 -> {} through\
 session_update" \
  [cx {ase::op_cards_nudge_ok [ase::session_state $f19g_key]}] 1

# --- F19j: the change detector normalises exactly like the capture gate -------
# ase.tcl:594 reads `ne {1}` and ase.tcl:3565 reads `eq {1}`, independently.
# Truthy-not-1 is OFF at both (issue 0637's subject, whose ruling is NOT this
# step's) and the detector must agree with them, not improve on them.
check "F19j 0648 op_cards_gate_changed normalises exactly like the capture gate\
 (truthy-not-1 stays OFF, 0637 unchanged)" \
  [list [cx {ase::op_cards_gate_changed {} 0}] \
        [cx {ase::op_cards_gate_changed {} 1}] \
        [cx {ase::op_cards_gate_changed 1 1}] \
        [cx {ase::op_cards_gate_changed 0 {}}] \
        [cx {ase::op_cards_gate_changed yes {}}] \
        [cx {ase::op_cards_gate_changed 1 {}}]] \
  {0 1 0 0 0 1}

# --- F19m: the re-arm never writes the state ----------------------------------
# The landmine that shapes the whole design: `save_op_params` is in
# ase::omit_if_empty, OFF must stay `{}` and never `0`, or the key lands in
# every .state a user saves and the 104 committed byte-identical fixtures
# redden. GREEN BEFORE THE CHANGE -- it exists to stay green.
check "F19m 0648 the re-arm hook writes NOTHING into the state (an off gate is\
 still OMITTED from the serialization)" \
  [expr {[string first save_op_params \
     [ase::state_serialize [ase::session_state $f19g_key]]] >= 0}] 0
ase::session_close $f19g_key

# --- F19k/F19l: the success line, pinned (issue 0648 section 3 is REFUTED) ----
# 0648 says "There is NO message for cards actually emitted". There is, at
# ase.tcl:657-660, since commit 44f52f9a (2026-08-23 06:28) -- twelve hours
# before 0648 was committed at 7bc7b61c 18:27 -- and it had ZERO test coverage:
# `grep -rn "card(s) added" tests/` returned nothing. These two rows are that
# coverage. They are GREEN BEFORE THE CHANGE; SAB-F (op_cards_count returns 0)
# is what they exist to catch.
cx {ase::op_cards_nudge_reset}
set f19k_dir [file normalize [file join $scratch runon_k]]
set st19k [ase::state_load $statefile]
dict set st19k rundir $f19k_dir
dict set st19k save_op_params 1
set f19k_msgs  [f_echo_run $st19k]
set f19k_hits  [f_matches $f19k_msgs {*device OP save card(s) added*}]
set f19k_n {}
if {[llength $f19k_hits] == 1} {
  regexp {(\d+) device OP save card\(s\) added} [lindex $f19k_hits 0] -> f19k_n
}
set f19k_text {}
catch {
  set fh [open [file join $f19k_dir test_nfet_final.spice] r]
  set f19k_text [read $fh]; close $fh
}
set f19k_cards [llength [f_cards [cx {ase::op_cards_for $f19k_text}]]]
check "F19k 0648 a gate-ON netlist SAYS how many device OP save cards it added,\
 exactly once, with the TRUE count" \
  [list [llength $f19k_hits] $f19k_n [expr {$f19k_cards > 0}]] \
  [list 1 $f19k_cards 1]

cx {ase::op_cards_nudge_reset}
set f19l_dir [file normalize [file join $scratch runoff_l]]
set st19l [ase::state_load $statefile]
dict set st19l rundir $f19l_dir
set f19l_msgs [f_echo_run $st19l]
check "F19l 0648 NON-VACUITY CONTROL: a gate-OFF netlist says nothing about\
 cards added" \
  [llength [f_matches $f19l_msgs {*card(s) added*}]] 0
cx {ase::op_cards_nudge_reset}

# ============================================================================
# F19o-F19s -- ISSUE 0650 / R-0653-d: THE NUDGE MUST CARRY AN EXECUTABLE REMEDY
# ============================================================================
# The shipped nudge ends in hardcoded prose:
#   "Tick Outputs > Save All > Save device OP parameters to annotate them"
# and R-0653-d req 2 forbids exactly that shape -- the LIVE menu label is
# `Save All…` (ase_window.tcl:502) and the LIVE checkbutton is
# `Save device OP parameters (gm, gds, vth, ...)` (:2879), so the shipped
# sentence already drops the ellipsis and the parenthetical. "A hardcoded path
# that drops the ellipsis or misses a cascade level is a wrong direction printed
# with authority, which is worse than printing none."
#
# The three requirements are ACCEPTANCE ITEMS, and each has a row here:
#   req 1  a test EXECUTES the printed command, never string-compares it  -> F19p
#          (the trap it exists for is ase_window.tcl:2912, "OFF IS `{}`, NEVER
#          `0`": a remedy printing `save_op_params 0` looks right and is wrong,
#          and only execution catches it)                                 -> F19q
#   req 2  the menu path is derived from / asserted against the LIVE menu -> W1t
#          in test_ase_window.tcl; F19o owns the shape (3 cascade segments)
#   req 3  the command invokes THE SAME PROC THE MENU INVOKES             -> F19r
#          (proved indirectly: the remedy must go through the three-blanket
#          writer, so it cannot have disturbed save_all_v / save_all_i; SAB-N6
#          is the discriminator -- neutralizing that one writer must redden the
#          existing Save All OK rows TOO, or the two paths were never the same
#          proc and req 3 is unmet)
#
# F19s pins that the nudge travels through the 0650 channel at all, so the
# statusbar/popup sinks proven in PS14-PS19 are reachable from THIS message and
# not only from a synthetic one.
#
# NOTE these rows need NO ngspice: netlisting alone emits the cards (measured,
# 6 on this cell), so they sit ABOVE the auto_execok guard where F11-F18 live.

## One field of the ::xschem::notify_last witness, with a SPEAKING placeholder
## when the witness (or the key) is absent.
proc f_nfield {k} {
  if {![info exists ::xschem::notify_last]} { return NO-notify_last }
  if {[catch {dict get $::xschem::notify_last $k} v]} { return NO-KEY-$k }
  return $v
}

# The session the remedy will name: the DESIGN cellview's own key, because the
# printed command has nothing else to address (ase::echo carries no session
# target -- that gap is filed as issue 0655).
cx {ase::op_cards_nudge_reset}
catch {unset ::xschem::notify_last}
set f19o_key [cx {ase::session_key {*}[ase::op_cards_nudge_key $stoff]}]
cx {ase::session_open $f19o_key $statefile}
set f19o_dir [file normalize [file join $scratch runoff_o]]
set f19o_st [cx {ase::session_state $f19o_key}]
catch {dict set f19o_st rundir $f19o_dir ; ase::session_update $f19o_key $f19o_st}

# --- F19o: the remedy is carried as FIELDS with the right SHAPE --------------
set f19o_n    [f_nudges [cx {ase::session_state $f19o_key}]]
set f19o_menu [f_nfield menu]
set f19o_cmd  [f_nfield command]
check "F19o 0653 R-0653-d the gate-off nudge carries a REMEDY: a 3-segment menu\
 path and a syntactically complete command, as DISTINCT fields" \
  [list $f19o_n \
        [expr {[info exists ::xschem::notify_last] ? 1 : 0}] \
        [llength [split $f19o_menu >]] \
        [expr {$f19o_cmd ne {} && ![string match {NO-*} $f19o_cmd] \
               && [info complete $f19o_cmd] ? 1 : 0}]] \
  {1 1 3 1}

# --- F19p: R-0653-d REQ 1 -- EXECUTE the printed command --------------------
# `ciw_exec` (src/ciw.tcl:250) runs `uplevel #0 $cmd`, so THE PRINTED STRING IS
# THE CONTRACT and this row runs it exactly the way the CIW entry field would.
# It must not merely set a key: the acceptance is that the very next netlist of
# the very same cellview emits real cards.
set f19p_v0 [cx {ase::state_get [ase::session_state $f19o_key] save_all_v 0}]
set f19p_i0 [cx {ase::state_get [ase::session_state $f19o_key] save_all_i 0}]
set f19p_rc [catch {uplevel #0 $f19o_cmd} f19p_err]
set f19p_gate [cx {ase::op_gate_on \
  [ase::state_get [ase::session_state $f19o_key] save_op_params {}]}]
set f19p_v1 [cx {ase::state_get [ase::session_state $f19o_key] save_all_v 0}]
set f19p_i1 [cx {ase::state_get [ase::session_state $f19o_key] save_all_i 0}]
set f19p_dir [file normalize [file join $scratch runon_p]]
set f19p_st [cx {ase::session_state $f19o_key}]
catch {dict set f19p_st rundir $f19p_dir}
set f19p_cards -1
if {![catch {ase::netlist $f19p_st} f19p_nl]} {
  set f19p_cards 0
  catch {
    set fh [open $f19p_nl r] ; set f19p_txt [read $fh] ; close $fh
    set f19p_cards [llength [f_cards [cx {ase::op_cards_for $f19p_txt}]]]
  }
}
check "F19p 0653 R-0653-d REQ 1: EXECUTING the printed command (never comparing\
 it) turns the gate on AND makes the next netlist of that cellview emit cards" \
  [list $f19p_rc $f19p_gate [expr {$f19p_cards > 0 ? 1 : 0}]] {0 1 1}
if {$f19p_rc} { puts "  F19p exec error: $f19p_err (command was {$f19o_cmd})" }

# --- F19q: the `{}`-NEVER-`0` trap, on the SERIALIZED form -------------------
# ase_window.tcl:2912: `save_op_params` is in ase::omit_if_empty, so OFF must
# stay `{}`. A remedy (or a shared writer) that normalises OFF to a literal 0
# writes the key into every .state the user saves and reddens the 104 committed
# byte-identical fixtures (F3/G3/R4/V4/R2). ON must appear; OFF must vanish.
set f19q_on [cx {ase::state_serialize [ase::session_state $f19o_key]}]
set f19q_orc [catch {ase::ui::save_all_apply $f19o_key $f19p_v1 $f19p_i1 0} f19q_err]
set f19q_off [cx {ase::state_serialize [ase::session_state $f19o_key]}]
check "F19q 0648 the shared writer keeps OFF as `{}`: ON serializes\
 `save_op_params 1`, OFF omits the key entirely (never a literal 0)" \
  [list [expr {[regexp {save_op_params\s+1} $f19q_on] ? 1 : 0}] \
        $f19q_orc \
        [expr {[string first save_op_params $f19q_off] >= 0 ? 1 : 0}] \
        [cx {ase::state_get [ase::session_state $f19o_key] save_op_params {}}]] \
  {1 0 0 {}}

# --- F19r: R-0653-d REQ 3 -- the remedy went through the MENU'S OWN writer ---
# "The command must invoke THE SAME PROC THE MENU INVOKES, not poke the state
# underneath it." The observable consequence: the Save All path writes all THREE
# blankets together, so a remedy that went through it left save_all_v and
# save_all_i exactly as it found them. Non-vacuous -- the gate value is in the
# same tuple, so a remedy that did nothing at all cannot pass this row.
check "F19r 0653 R-0653-d REQ 3: the executed remedy turned the gate ON and left\
 save_all_v / save_all_i untouched (it went through the three-blanket writer)" \
  [list $f19p_gate $f19p_v1 $f19p_i1] [list 1 $f19p_v0 $f19p_i0]

# --- F19s: the nudge really travels through the 0650 channel ----------------
# Without this row PS14-PS19 prove the sinks work for a SYNTHETIC notice while
# the one message the user actually needed could still be on the old path.
cx {ase::op_cards_nudge_reset}
catch {unset ::xschem::notify_last}
set f19s_dir [file normalize [file join $scratch runoff_s]]
set f19s_st [ase::state_load $statefile]
dict set f19s_st rundir $f19s_dir
f_nudges $f19s_st
check "F19s 0650 the gate-off nudge travels through xschem::notify (its own\
 record names it, untagged, with the remedy attached)" \
  [list [expr {[string match {ASE: device operating-point parameters*} \
                 [f_nfield msg]] ? 1 : 0}] \
        [f_nfield tag] \
        [expr {[f_nfield command] ne {} && ![string match {NO-*} [f_nfield command]] ? 1 : 0}]] \
  {1 {} 1}
cx {ase::session_close $f19o_key}
cx {ase::op_cards_nudge_reset}

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
