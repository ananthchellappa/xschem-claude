# ASE-L core (src/ase.tcl, P1 of doc/claude/specs/ase_l.md) — headless checks:
#   R* state I/O:   defaults, save->load round trip, unknown-key preservation,
#                   load->save byte-stability
#   B1 backend registry: ngspice entry, all four hooks resolve
#   D* deck render: golden deck for the nfet state, disabled analyses absent +
#                   fixed op..tran order, trailing-.end strip robustness,
#                   temperature -> .temp (custom / non-numeric / missing key),
#                   Save-All blankets (save_all_v -> `.save all` before the
#                   per-output saves, save_all_i -> `.options savecurrents`,
#                   nothing while both flags are 0)
#   C* op cards:    the save_op_params gate key ({} = ON, the default, omitted
#                   from the serialized form; `0` = the explicit off a user has
#                   to spell out -- issue 0927), the op-cards capture/consume seam, and
#                   render_deck appending op_annot::save_cards VERBATIM above
#                   `.control` on a cache hit (plan step S4 / issue 0617)
#   N* netlist:     ase::netlist on a scratch lib/cell/view fixture, rundir
#                   defaulting to $netlist_dir
#   E* run:         real ngspice batch end-to-end (Id ~ 4.096837e-04, leg
#                   SKIPPED if ngspice absent), missing-binary clean error via
#                   a fake backend, unknown-simulator clean error
#   NT* notify:     issue 0650 -- the `xschem::notify` channel ase::echo is
#                   rewired onto: one builder, the call-time ::notify_style
#                   read, the one-::ciw_echo-per-notice budget, the empty-message
#                   blank line, the R-0653-d remedy fields, the 28-char short
#                   form and the generalised (subject, state) suppression latch.
#                   The Tk sinks (.statusbar.12 fallback, opt-in popup) are
#                   PS14-PS19 in test_ase_log_seam_0207.tcl -- a --nolog suite
#                   has neither a statusbar nor a CIW to witness them with.
#   RT* round trip: issue 0643 / descend_run_batch item A -- ase::stack_level,
#                   ase::hier_instnames and the ase::with_design_current
#                   ascend/netlist/re-descend, its autosave-backup decision
#                   table, its read-only snapshot and ase::netlist's four arms.
#   RS* / RD* ⚖ R3: issue 1429 -- the rule that says where ONE output row's
#                   number comes from (ase::result_source), the two readers it
#                   chooses between, and the sentence that states it on screen
#   DX* at depth:   descend_run_batch item C -- the things that ALREADY worked
#                   two levels down and must not silently regress: the
#                   annotation basis (raw_level / sim_sch_path / the built
#                   device path) with the session's level and without it, and
#                   the end-to-end descended netlist, byte-for-byte against one
#                   taken at the top, against the leaf-alone deck a person gets
#                   without the round trip.
#
# The nfet fixture (nfet_test_claude MINUS its corner + simulator_commands
# instances) is embedded verbatim below and written into a scratch
# lib/cell/view registered through a scratch library.defs — no dependency on
# untracked workarea cells. The model path is injected via the STATE (never
# hardcoded in ase.tcl), pointing at the tracked sky130A workarea models file.
#
# RUNS IN BOTH ARMS, with the same VERDICT (issue 0698 -- this suite used to pass
# headless and abort under X, and that asymmetry was carried in briefs as folklore
# instead of being fixed). Run from the repo ROOT:
#   headless:  ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
#   display:   tests/headless/run_suites.sh test_ase_core
# Under X the design window is bound explicitly before the first ase::netlist
# (ase_design_window.tcl); headless, ase::netlist self-loads and that arm of the
# guard stays the thing under test.
#
# THE CHECK COUNT IS 230 IN BOTH ARMS, and that equality is a COINCIDENCE of
# announced skips cancelling -- it is NOT a claim that the arms run the same rows.
# Headless, NT14 runs (its own premise is "there is no Tk") and RG6's behavioural
# leg does not; under X, NT14 prints
# `SKIPPED: NT14 headless-only sink safety (a display is present; see 0804)`
# and RG6 prints its measurement instead. One row each way, so 230 = 230.
# DX7 is the third row of this shape and it does NOT skip either way: it asserts
# ase::netlist's arm (c) under a display and its arm (b) headless, because those
# are the product's own two contracts for the same call from the same place.
#
# ⚠ THE COUNT IS A FLOOR AND IT ONLY EVER GOES UP. It was 173/172 when this
# comment first claimed "differ by exactly one" (issue 0698's era), 184 before
# the 1389 run-guard section, 197 when section RG landed, 203 once RG6 was
# rewritten to measure the keyboard and RG13/RG14 were added, 216 when section
# RT landed (descend_run_batch item A), 224 with section DX (item C) and 230
# with section C4 (the sim_entry state key, the 2026-09-08 registry/choice
# ruling), 248 with section D7 (issue 1401, the analysis type this backend
# cannot render), 257 with section D8 (the emitted analysis line, per type) and
# 258 with D8i, which the analyses batch's Stage 1 adds because the Arguments
# column only becomes the emitted line there, and 266 with section SW (Stage 2e,
# the Stop warning). RAISED 230 -> 243, then 243 -> 248
# when an adversarial review found D7e's "names it once" unpinned and the rank
# table unscoped to a backend, then 248 -> 257 with D8, 257 -> 258 with
# Stage 1, 258 -> 266 with Stage 2e, and 266 -> 273 with section AD (Stage 2
# item 2d, issue 1408 -- the dialog describing THIS session's simulator). ⚠ AD's
# rows are the SCHEMA half and are deliberately arm-independent: the widget half
# is test_ase_dialogs.tcl section G14, which run_regression.tcl runs on NEITHER
# arm, so the contract survives even where those rows cannot run.
# 273 -> 289 with section AG (Stage 2 item 2b + 2c's core half, issue 1410 -- the
# four-state resolver and the registry growing to eleven types). ⚠ R1 does NOT
# move: `ase::state_default` still seeds exactly four rows, which is ⚖ R4's
# recommended answer shipping BY CONSTRUCTION rather than by a later edit.
# 289 -> 298 with section EM (Stage 3 item C1, issue 1414 -- the slot grammar and
# the expander). ⚠ Every EM fixture registers its OWN backend, so the shipped
# registry, the 104 committed `.state` files and every deck golden are unmoved BY
# CONSTRUCTION rather than by hope.
# 298 -> 309 with sections EK and SI (Stage 3 item C2, issue 1415 -- one refusal
# reader and the number alphabet). ⚠ EK6 is the CORPUS INVARIANT and it belongs
# with that commit: C2 is the one that could make a shipped bench unrunnable at
# the gate, so the row that would notice lands with it.
#
# 309 -> 348 with sections GR, VB and CP (Stage 3 items C3/C5/C6, issues
# 1416-1420 -- the field tables, the refused unknown key and the committed
# corpus as a property).
# 348 -> 360 with section TF (Stage 5, issue 1426 -- the DC small-signal
# transfer function gains a real entry). ⚠ TWO ROWS MOVED RATHER THAN BEING
# ADDED, and both were EXPECTED: AG1/AG2 split the offered list at five instead
# of four because `tf` earned an `emitorder`, and EM7/CP6 count six probe-only
# types instead of seven. ⚠ R1 does NOT move and CP1-CP4 do not move: `tf`
# declares no `seed_enabled`, so `ase::state_default` still seeds exactly four
# rows and the 104 committed `.state` files are untouched.
# 360 -> 376 with section PZ (Stage 5, issue 1427 -- the pole-zero analysis
# gains a real entry). ⚠ SEVEN ROWS MOVED RATHER THAN BEING ADDED, every one of
# them expected and every one named here:
#   AG1 / AG2   the offered list splits at SIX, `pz` sixth -- it earned rank 60
#   EM7 / CP6   five probe-only types now, not six
#   GR8         a new declared kind, `node`, added DELIBERATELY: a pz row names
#               four bare nodes and `0` is ground, not the integer zero
#   TF3b        its control type was `pz`, which is no longer unrenderable; it
#               is `noise` now, which PF222 also rests on
#   D7e3        same reason; its second unrenderable type is `pss`, the furthest
#               away (baseline 0 AND `#ifdef`-gated)
# ⚠ R1, AG3, CP1-CP4 do NOT move: `pz` declares no `seed_enabled` either, so
# `ase::state_default` still seeds exactly four rows and the 104 committed
# `.state` files are untouched.
# 376 -> 391 with section SE (Stage 5, issue 1428 -- DC sensitivity gains a real
# entry; the AC mode is Stage 6's, and the two defects that make it so are
# measured in that section's header). ⚠ FIVE ROWS MOVED RATHER THAN BEING
# ADDED, every one of them expected and every one named here:
#   AG1 / AG2   the offered list splits at SEVEN, `sens` seventh -- it earned
#               rank 70, and it OVERTOOK `noise`, which is ahead of it in
#               declaration order and has no rank
#   EM7 / CP6   four probe-only types now, not five
#   GR8         a new declared kind, `filter`, added DELIBERATELY: a sens row's
#               second field is a list of GLOBS over ngspice's parameter
#               namespace, and PLAN.md §5a's computed picker is what a kind
#               rather than a bare `text` lets a later stage find
# ⚠ AND TWO ROWS THAT WERE EXPECTED TO MOVE DID NOT. `TF3b` and `D7e3` move
# every time a type stops being probe-only, and `pz`'s commit had already moved
# both off `pz` -- to `noise` and to `noise`+`pss`. Neither names `sens`, so
# both are untouched here. A row picked for DISTANCE stops moving; that is what
# picking it for distance was for.
# ⚠ R1, AG3, CP1-CP4 do NOT move for `sens` either -- no `seed_enabled`, four
# seeded rows, 104 committed `.state` files untouched. That is now three Stage 5
# commits in a row, which is ⚖ R4's recommended answer shipping by construction
# rather than by anybody remembering.
# 391 -> 411 with sections RS and RD (Stage 6, issue 1429 -- ⚖ R3's reader
# seam: WHERE one output row's number comes from). ⚠ NO ROW MOVED. Every
# existing row here reads the log through an expression or a key, and issue
# 1429 changes neither; what it adds is a second reader and the one proc that
# chooses between them.
# ⚠ ⚖ R3 IS ASKED AND UNANSWERED. What is pinned is DECISIONS.md's
# RECOMMENDATION, Option C -- named vectors from the results file, arbitrary
# expressions from the print log -- and RS2/RS3 exist to pin the property that
# makes shipping an unratified recommendation safe: C is the SUPERSET of A and
# B, so a later ruling moves ONE proc (`ase::result_source`) and deletes one
# reader. RS3 performs both rulings by stubbing that proc and shows the whole
# surface following. DECISIONS.md records R3 as EXTENDING the user's own ruling
# in issue 1243, not reversing it -- render_deck's print anchor is untouched.
# ⚠ SECTIONS RS AND RD CARRY THEIR OWN `catch`: this file's OUTER one closes at
# the end of section SI, thousands of lines above them (issue 1428's S10).
#
# ⚠ D8 EXISTS BECAUSE D1 WAS MEASURED INSUFFICIENT, not suspected. D1's fixture
# is OP-ONLY, so sabotaging `dc`'s emit template to swap start and stop, or
# `ac`'s hardwired `dec` to `oct`, left this whole suite at ALL PASS (248).
# If a run reports fewer, a row went missing -- do not edit this number down to
# match it.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
## non-asserting evidence line (the test_ase_log_seam_0207.tcl idiom)
proc note {name got} { puts "note: $name = {$got}"; flush stdout }

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
set models  [file join $repo sky130A models libs.tech combined sky130.lib.spice]
source [file join $here scratch.tcl]
source [file join $here ase_design_window.tcl]  ;# ase_bind_design_window (issue 0698)
## issue 0658: a throw-away XSCHEM_SHAREDIR + a CHILD xschem launched against it,
## the only honest reproduction of "src/ciw.tcl failed to load" (NTD1-NTD7).
source [file join $here sharefarm.tcl]
set scratch [test_scratch ase_core]

## ISOLATION FROM WHOEVER'S ~/.xschem/ase_simulators IS LIVE (issue 1377).
test_sim_registry_isolate     ;# issue 1377: the registry below is OURS, not ~/.xschem's
## src/xschem.tcl loads the registry once at startup, so without this row and
## the call above it every expectation below that touches the run command, the
## save tier or the case of a vector name is really an expectation about the
## developer's own machine. Measured before the fix: 7 FAILED here under the
## developer's HOME, ALL PASS under a HOME with no registry.
check "ISO1377 the suite runs against an empty simulator registry, not the one in ~/.xschem" \
  [test_sim_registry_state] {0 {} {} path}

## ISO1377b -- THE HELPER'S OWN ROUND TRIP, and it is here because the row above
## cannot fence the whole helper. MEASURED on this box: at the instant a suite's
## first line runs the capability cache is EMPTY (0 entries) and the rc seeds
## ::ASE_SIMULATORS / ::ASE_SIMULATOR are both {}, so two of
## test_sim_registry_isolate's three clears are unreachable from any HOME anyone
## can construct -- they are defence in depth against a WORKAREA rc (layer 1 of
## the registry design, one line away in sky130A/cadence_style_rc) and against a
## suite that probes before it isolates. Lines nothing can red are lines that
## quietly stop working, so this row makes the dirty precondition ITSELF and
## then demands the helper undo all three: an entry in force, a primed
## capability answer for it, and both rc seeds set.
set iso_caps_before [dict size $::ase::sim_caps]
ase::sim_register iso1377fake /bin/sh
ase::sim_select   iso1377fake
dict set ::ase::sim_caps [list /bin/sh {}] {known 1 usable 1}
set ::ASE_SIMULATORS [list [dict create name iso1377fake path /bin/sh]]
set ::ASE_SIMULATOR  iso1377fake
check "ISO1377b the dirty precondition is really dirty (non-vacuity guard)" \
  [list [test_sim_registry_state] [dict size $::ase::sim_caps] \
        $::ASE_SIMULATOR] \
  [list {1 iso1377fake iso1377fake registry} [expr {$iso_caps_before + 1}] iso1377fake]
test_sim_registry_isolate
check "ISO1377b the helper clears the registry, the measured capabilities and both rc seeds" \
  [list [test_sim_registry_state] [dict size $::ase::sim_caps] \
        $::ASE_SIMULATORS $::ASE_SIMULATOR] \
  {{0 {} {} path} 0 {} {}}

# --- scratch lib/cell/view fixture + registry --------------------------------
# clean nfet schematic: nfet_test_claude minus corner + simulator_commands_shown
set sch_text {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 420 -330 600 -330 {}
N 380 -300 380 -330 {}
N 380 -330 250 -330 {}
N 250 -270 600 -270 {}
N 420 -300 420 -270 {}
C {sky130_fd_pr/nfet_01v8} 400 -300 0 0 {name=M1 W=1 L=0.15 nf=1}
C {devices/vsource} 600 -300 0 0 {name=V1 value=1}
C {devices/vsource} 250 -300 0 0 {name=V2 value=1.8}
C {devices/gnd} 510 -270 0 0 {name=GND1 lab=GND}
C {devices/lab_wire} 500 -330 0 0 {name=lD lab=D}
C {devices/lab_wire} 300 -330 0 0 {name=lG lab=G}
}
file mkdir [file join $scratch aselib nfet_clean schematic]
set f [open [file join $scratch aselib nfet_clean schematic nfet_clean.sch] w]
puts -nonewline $f $sch_text
close $f
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE aselib [file join $scratch aselib]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# schema-only nfet state (R2/R4/D*/N*/E* — NO unknown keys; R3 alone owns those)
proc nfet_state {modelsfile rundir} {
  set st [ase::state_default]
  dict set st design {lib aselib cell nfet_clean view schematic}
  dict set st rundir $rundir
  dict set st models [list [list file $modelsfile section tt]]
  dict set st variables {{name Vgs value 1.8} {name Vds value 1.0}}
  dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}
  dict set st outputs {{name id expr -i(v1) save 1 plot 0}}
  dict set st options {{name savecurrents value 1}}
  return $st
}

set e1_callback_fired 0

if {[catch {

# --- R1: state_default schema -----------------------------------------------
set d [ase::state_default]
# `cosim` joined in section E of doc/claude/specs/mixed_signal_signal_browser.md
# (mixed-signal POLICY: build/trace/attach/bridges/vsupply). It is in
# ase::omit_if_empty, so an empty one is NOT serialized and every state file
# written before it existed still round-trips byte-identically — F3/G3 in
# test_ase_final{,_gf180} are the golden files that assert exactly that.
check "R1 default has exactly the 18 schema keys" [lsort [dict keys $d]] \
  [lsort {version simulator sim_entry design rundir temperature models variables analyses outputs save_all_v save_all_i save_op_params options includes pre_commands cosim viewer}]
check "R1 cosim defaults to empty and is omitted from the serialized form" \
  [list [dict get $d cosim] [expr {[string first "cosim" [ase::state_serialize $d]] >= 0}]] {{} 0}
check "R1 a NON-empty cosim IS serialized" \
  [expr {[string first "cosim {build never}" \
     [ase::state_serialize [dict replace $d cosim {build never}]]] >= 0}] 1
# --- C4: sim_entry, the choice of registered simulator (the 2026-09-08 ruling)
# The user: registering a simulator "is something that can make it to disk right
# away as soon as done", but *whether* a registered one "gets assigned as 'the
# one to use' is an option that is part of the ASE-L state. If changed, that
# results in dirtiness." Being a schema key is the whole implementation of that
# — ase::session_dirty compares serialized states, so the dirty mark, the save
# and the quit prompt come for free.
#
# ⚠ IT OBEYS THE SAME LAW AS `cosim` AND `save_op_params`, AND FOR THE SAME
# REASON: default `{}`, member of ase::omit_if_empty. Anything else writes a
# `sim_entry` line into all 104 committed .state files and reddens the five
# load->save byte-identity rows (F3 in test_ase_final, G3 in
# test_ase_final_gf180, R4 below, V4 in test_ase_view, R2 in test_ase_persist).
#
# THREE VALUES, and `{}` is NOT the same as "the PATH program": {} means this
# state has no opinion and the installation default runs; `none` is the
# deliberate PATH choice issue 0932 established; `{name <entry>}` names a
# registry entry, two words so no registry name has to be reserved.
check "C4 sim_entry defaults to empty" \
  [ase::state_get $d sim_entry <absent>] {}
check "C4 sim_entry is in ase::omit_if_empty" \
  [expr {[lsearch -exact $ase::omit_if_empty sim_entry] >= 0}] 1
check "C4 sim_entry is OMITTED from the serialized default state" \
  [expr {[string first "sim_entry" [ase::state_serialize $d]] >= 0}] 0
check "C4 sim_entry sits beside simulator in the canonical order" \
  [lsearch -exact $ase::schema_keys sim_entry] \
  [expr {[lsearch -exact $ase::schema_keys simulator] + 1}]
check "C4 a state that picks the PATH program IS serialized -- {} and none are different answers" \
  [list [expr {[string first "sim_entry none" \
       [ase::state_serialize [dict replace $d sim_entry none]]] >= 0}] \
        [expr {[string first "sim_entry {name zz-build}" \
       [ase::state_serialize [dict replace $d sim_entry {name zz-build}]]] >= 0}]] \
  {1 1}
check "C4 a state file written before the key existed loads with the key empty and serializes without it -- the byte-identity contract in one line" \
  [list [ase::state_get [dict remove $d sim_entry] sim_entry {}] \
        [expr {[string first "sim_entry" \
           [ase::state_serialize [dict remove $d sim_entry]]] >= 0}]] \
  {{} 0}
# --- C2/C3: the save_op_params gate key (plan step S4, polarity 0927) --------
# doc/claude/suggestions/next_session_prompt_op_annotation.md S4 + the S4 plan's
# first decision. The gate key MUST default to `{}` and MUST join
# ase::omit_if_empty, NOT default to a literal: ase::state_serialize writes
# every non-empty schema key, so a literal default lands in all 104 committed
# .state files and reddens five load->save byte-identity rows (F3 in
# test_ase_final, G3 in test_ase_final_gf180, R4 below, V4 in test_ase_view,
# R2 in test_ase_persist). `cosim` is the precedent this copies.
#
# ⚠ WHAT `{}` MEANS FLIPPED ON 2026-08-29 (issue 0927, the user's call):
#   {} / absent = ON, the default    0 = OFF, the only value ever written out
# The empty default is what carried the flip with ZERO churn on disk -- the 104
# committed states say nothing about the key and now get the feature for free,
# which is the whole point of the change.
# sentinel default: a MISSING key must read as `<absent>`, never as the `{}`
# the row is asserting, or the check would pass vacuously on a tree without it
check "C2 save_op_params defaults to empty" \
  [ase::state_get $d save_op_params <absent>] {}
check "C2 0927 the empty default reads ON" \
  [ase::op_gate_on [ase::state_get $d save_op_params <absent>]] 1
check "C2 0927 an ABSENT key reads ON too (a state written before the key)" \
  [ase::op_gate_on [ase::state_get [dict remove $d save_op_params] \
     save_op_params {}]] 1
check "C2 0927 only an explicit false reads OFF" \
  [list [ase::op_gate_on 0] [ase::op_gate_on no] [ase::op_gate_on false] \
        [ase::op_gate_on 1] [ase::op_gate_on yes] [ase::op_gate_on 2]] \
  {0 0 0 1 1 1}
check "C2 0927 op_gate_value is the one writer: on -> {} (omitted), off -> 0" \
  [list [ase::op_gate_value 1] [ase::op_gate_value 0]] {{} 0}
check "C2 save_op_params is OMITTED from the serialized default state" \
  [expr {[string first "save_op_params" [ase::state_serialize $d]] >= 0}] 0
check "C2 save_op_params sits right after save_all_i in the canonical order" \
  [lsearch -exact $ase::schema_keys save_op_params] \
  [expr {[lsearch -exact $ase::schema_keys save_all_i] + 1}]
check "C2 save_op_params is in ase::omit_if_empty" \
  [expr {[lsearch -exact $ase::omit_if_empty save_op_params] >= 0}] 1
check "C3 0927 save_op_params 0 IS serialized (OFF is what costs a key)" \
  [expr {[string first "save_op_params 0" \
     [ase::state_serialize [dict replace $d save_op_params 0]]] >= 0}] 1
check "C3 save_op_params 1 IS serialized too (the key is not write-only)" \
  [expr {[string first "save_op_params 1" \
     [ase::state_serialize [dict replace $d save_op_params 1]]] >= 0}] 1

check "R1 version is 1" [dict get $d version] 1
check "R1 temperature default 27" [dict get $d temperature] 27
check "R1 save_all_v and save_all_i default 0" \
  [list [dict get $d save_all_v] [dict get $d save_all_i]] {0 0}
set types {}; set enabled {}
foreach a [dict get $d analyses] {
  lappend types [dict get $a type]
  if {[dict get $a enabled]} { lappend enabled [dict get $a type] }
}
check "R1 analyses are the four types in order" $types {op dc ac tran}
check "R1 only op enabled by default" $enabled {op}

# --- R2: save -> load dict round trip (schema-only state) --------------------
set st [nfet_state /models/sky130.lib.spice {}]
ase::state_save [file join $scratch r2.state] $st
set st2 [ase::state_load [file join $scratch r2.state]]
set ok 1
foreach k [dict keys $st] {
  if {[dict get $st $k] ne [dict get $st2 $k]} { set ok 0; puts "  R2 mismatch on key: $k" }
}
check_true "R2 every key equal after save->load" $ok

# --- R3: unknown-key preservation (merge OVER defaults) ----------------------
set f [open [file join $scratch r3.state] w]
puts $f "version 1"
puts $f "custom_key {hello world}"
puts $f "variables {{name Vgs value 3.3}}"
close $f
set st3 [ase::state_load [file join $scratch r3.state]]
check "R3 custom_key preserved on load" [dict get $st3 custom_key] {hello world}
check "R3 loaded value overrides default (merge over)" [dict get $st3 variables] {{name Vgs value 3.3}}
ase::state_save [file join $scratch r3b.state] $st3
set f [open [file join $scratch r3b.state] r]; set out [read $f]; close $f
check_true "R3 saved file contains custom_key {hello world}" \
  [string match "*custom_key {hello world}*" $out]
check_true "R3 saved file keeps the known value" \
  [string match "*{name Vgs value 3.3}*" $out]

# --- R4: byte-stability of load -> save (schema-only state) ------------------
set stb [nfet_state /models/sky130.lib.spice {}]
ase::state_save [file join $scratch r4a.state] $stb
set st4 [ase::state_load [file join $scratch r4a.state]]
ase::state_save [file join $scratch r4b.state] $st4
set f [open [file join $scratch r4a.state] rb]; set a [read $f]; close $f
set f [open [file join $scratch r4b.state] rb]; set b [read $f]; close $f
check_true "R4 load->save byte-identical" [expr {$a eq $b}]

# --- B1: backend registry ----------------------------------------------------
set ok 1
foreach h {render_deck run_cmd log_file result_probe} {
  if {[catch {ase::backend_hook ngspice $h} p] || [info commands $p] eq {}} {
    set ok 0; puts "  B1 hook $h -> '$p' does not resolve"
  }
}
check_true "B1 ngspice registered, all four hooks resolve to commands" $ok

# --- D1: golden deck render --------------------------------------------------
## RESTATED (casemode batch item 10, 2026-08-17): the golden now carries the
## seven-line `$sim_status` guard after the `op`. Same check, same id, one
## genuinely changed expectation — DECISIONS.md C4 makes the guard part of every
## deck this backend renders, and it is emitted after EVERY analysis because
## `$sim_status` is last-writer-wins per analysis (measured: a failing `dc`
## followed by a good `tran` exits 0 and writes a raw with one guard at the end,
## and exits 1 writing nothing with a guard after each). The `$?` existence test
## in front of it is a MARKER, not an error suppressor: `$sim_status` does not
## exist before the first analysis, and on a build that has no such variable at
## all defence (b) is inert, which `NO-SIM-STATUS` in the log says out loud.
## Re-measured 2026-08-17: `Error: sim_status: no such variable.` is printed at
## parse time with the `$?` block exactly as without it. Spec §14.3.
set netlist_text {** sch_path: /fixture/nfet_clean.sch
**.subckt nfet_clean
XM1 D G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 ad=0.29 as=0.29 pd=2.58 ps=2.58 nrd=0.29 nrs=0.29 sa=0 sb=0 sd=0 mult=1
V1 D GND 1
V2 G GND 1.8
**.ends
.GLOBAL GND
.end
}
# the raw-artifact write line (item 11 D3): rundir {} -> the netlist_dir
# default, resolved through the SAME ase::rundir call render_deck's raw_file
# hook uses, so the golden stays deterministic on every machine
set d1_raw [file join [ase::rundir [nfet_state /models/sky130.lib.spice {}]] nfet_clean_ase.raw]
## ⚠ 0929 MOVED THIS GOLDEN. The deck used to end on ONE `remzerovec` + `write`
## after the last analysis; ngspice's `write` writes the CURRENT plot, so a deck
## with op AND tran stored only the transient and `6` reported "these are from a
## 'tran' run". There is now `set appendwrite` before the analyses and a
## `remzerovec` + `write` after EACH one, so every analysis's plot reaches the
## raw. The `print` rows moved below the write because the writes are emitted
## inside the analysis loop; they still run against the last analysis's plot,
## which is where they ran before.
## ⚠ THE `annotate` MERGE ADDED THE $sim_status GUARD AFTER EACH ANALYSIS, from
## `fluid-editing`'s casemode item 10 defence (b), and it sits ABOVE the
## remzerovec/write pair on purpose: its job is to `quit 1` before a failed
## analysis can put a plot into the results file. A golden with the two in the
## other order would pass while the deck shipped the bad raw.
set expected_deck [string map [list @RAWFILE@ $d1_raw] {** sch_path: /fixture/nfet_clean.sch
**.subckt nfet_clean
XM1 D G GND GND sky130_fd_pr__nfet_01v8 L=0.15 W=1 nf=1 ad=0.29 as=0.29 pd=2.58 ps=2.58 nrd=0.29 nrs=0.29 sa=0 sb=0 sd=0 mult=1
V1 D GND 1
V2 G GND 1.8
**.ends
.GLOBAL GND
.lib /models/sky130.lib.spice tt
.param Vgs=1.8
.param Vds=1.0
.options savecurrents
.temp 27
.save -i(v1)
.control
set appendwrite
op
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
remzerovec
write @RAWFILE@
print -i(v1)
.endc
.end
}]
set render [ase::backend_hook ngspice render_deck]
set deck [$render [nfet_state /models/sky130.lib.spice {}] $netlist_text]
check_true "D1 golden deck for the nfet state" [string equal $deck $expected_deck]
if {![string equal $deck $expected_deck]} { puts "  D1 got:\n$deck" }

# --- D2: disabled analyses absent + fixed order ------------------------------
check_true "D2 no dc line while dc disabled" [expr {![regexp -line {^dc } $deck]}]
set st [nfet_state /models/sky130.lib.spice {}]
dict set st analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 1u}}
set deck2 [$render $st $netlist_text]
set opidx [string first "\nop\n" $deck2]
set tridx [string first "\ntran 1n 1u\n" $deck2]
check_true "D2 op renders before tran 1n 1u" [expr {$opidx > 0 && $tridx > 0 && $opidx < $tridx}]

# --- D7: an analysis type this backend cannot render (issue 1401) ------------
# ⚠ THESE ROWS WERE WRITTEN RED-FIRST AND PASSED AGAINST THE UNFIXED CODE, in
# the inverted form: one row asserted that a noise-only state rendered WITHOUT
# error, and another that the deck carried `set appendwrite` and no analysis
# command. Both were green before the fix and both are the opposite of what is
# asserted now.
# ⚠ THE RED-FIRST SECTION HAD FIVE ROWS AND THIS ONE HAS THIRTEEN, so the letters
# MOVED: today's D7d (`n_enabled_analyses` still counts the row) is NOT the
# historical D7d, it holds against fixed and unfixed code alike, and it is
# deliberately absent from this issue's sabotage list for that reason. Name the
# assertion, never the letter, when citing what went red. The witness matters
# because this defect leaves NOTHING behind -- no error, no message, not even a
# file that looks missing -- so a fix landed without one has no evidence the
# defect was ever there. MEASURED 2026-09-10 against the unfixed render_deck, on
# a state whose only enabled row is `{type noise enabled 1 ...}`:
#
#     ** sch_path: /fixture/nfet_clean.sch
#     ... netlist, .lib, .param, .options savecurrents, .temp 27, .save -i(v1) ...
#     .control
#     set appendwrite
#     print -i(v1)
#     .endc
#     .end
#
# -- rc 0, no analysis command, no $sim_status guard, no remzerovec and NO
# `write` at all, so the run produced no raw file whatsoever while the Analyses
# pane went on showing the row ticked.
set st7 [nfet_state /models/sky130.lib.spice {}]
dict set st7 analyses {{type noise enabled 1 output v(out) source v1 sweep dec points 10 start 1 stop 1meg}}
set d7rc [catch {$render $st7 $netlist_text} d7err]
check "D7a a noise-only state REFUSES instead of rendering" $d7rc 1
check "D7b ... with the type named, in the one minted sentence" $d7err \
  {ase: analysis type 'noise' is not one this simulator backend can render}
check "D7c ... which is the sentence ase::analysis_unrenderable_msg mints" \
  [ase::analysis_unrenderable_msg noise] $d7err
check "D7d ... and n_enabled_analyses still COUNTS the row -- the counter was\
 never the gate, which is why the drop was silent" [ase::n_enabled_analyses $st7] 1
check "D7e ase::analysis_unrenderable names it" \
  [ase::analysis_unrenderable $st7] {noise}

# ⚠ THE TWO ROWS BELOW EXIST BECAUSE D7e ALONE CANNOT SEE EITHER HALF OF THIS
# PROC'S CONTRACT. With one unrenderable row in the fixture, dropping the
# `lsearch` dedup and replacing the whole body with `return [list $t]` on the
# first hit are BOTH byte-identical -- the row is green for a proc that names
# duplicates twice and for one that stops at the first. That is this tree's
# hollow-green class, and a row that cannot be made to fail proves nothing.
set st7m [nfet_state /models/sky130.lib.spice {}]
dict set st7m analyses {{type noise enabled 1 source v1} {type op enabled 1} {type noise enabled 1 source v2}}
check "D7e2 two enabled rows of ONE unrenderable type are named ONCE" \
  [ase::analysis_unrenderable $st7m] {noise}
set st7t [nfet_state /models/sky130.lib.spice {}]
# ⚠ THE SECOND TYPE HERE MOVES EVERY TIME A STAGE MAKES ONE RENDERABLE, AND IT
# IS PICKED FOR DISTANCE RATHER THAN CONVENIENCE. It was `pz` until Stage 5's pz
# commit (issue 1427) gave `pz` a real entry; before that it had never moved.
# `pss` is the furthest away: it is the only remaining probe-only type that is
# `baseline 0` AND `#ifdef`-gated (`WITH_PSS`), so it is the last one an adapter
# stage will reach. When it too becomes renderable, the row wants a FIXTURE
# backend rather than a fourth shipped type -- the thing this row asserts is a
# property of `ase::analysis_unrenderable`, not of any particular analysis.
dict set st7t analyses {{type noise enabled 1 source v1} {type pss enabled 1} {type op enabled 1}}
check "D7e3 TWO distinct unrenderable types are BOTH named, in state order" \
  [ase::analysis_unrenderable $st7t] {noise pss}
check "D7e4 ... and render refuses on the FIRST of them, by name" \
  [list [catch {$render $st7t $netlist_text} e7t] $e7t] \
  [list 1 {ase: analysis type 'noise' is not one this simulator backend can render}]

# ⚠ CORE CARRIES ONE BACKEND'S RANK TABLE, so it must not refuse for a backend
# whose analyses it does not describe: ase::register_backend is a real extension
# point and a second backend's render_deck may emit types this table never had.
# The precedent is ase::run_composes_registry, which gates the casemode precheck
# two statements above the preflight_gate call for exactly this reason.
set st7b [nfet_state /models/sky130.lib.spice {}]
dict set st7b analyses {{type noise enabled 1 source v1}}
dict set st7b simulator someoneelsesim
check "D7e5 a DIFFERENT backend's state is not refused on ngspice's rank table" \
  [ase::analysis_unrenderable $st7b] {}
check "D7e6 ... while the schema-default backend still is" \
  [list [ase::analysis_rank_authority $st7] [ase::analysis_rank_authority $st7b]] {1 0}

# A DISABLED row of an unknown type is NOT a refusal: it emits nothing today and
# emitted nothing before, so refusing it would break benches that merely carry a
# row somebody unticked. Non-vacuity for D7a.
set st7d [nfet_state /models/sky130.lib.spice {}]
dict set st7d analyses {{type op enabled 1} {type noise enabled 0 source v1}}
set d7drc [catch {$render $st7d $netlist_text} d7ddeck]
check "D7f a DISABLED unknown type renders clean" $d7drc 0
check_true "D7f2 ... and its deck still carries the op analysis" \
  [regexp -line {^op$} $d7ddeck]

# THE ORDER IS UNCHANGED, asserted as ranks rather than inferred from a golden.
set st7o [nfet_state /models/sky130.lib.spice {}]
dict set st7o analyses {{type tran enabled 1 step 1n stop 1u} {type ac enabled 1 points 10 start 1 stop 1meg} {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01} {type op enabled 1}}
set d7types {}
foreach e [ase::analysis_emit_order $st7o] { lappend d7types [lindex $e 2] }
check "D7g the emit order is op dc ac tran whatever order the rows are in" $d7types {op dc ac tran}
set d7types9 {}
foreach e [ase::analysis_emit_order $st7o 1] { lappend d7types9 [lindex $e 2] }
check "D7h ... and 0964's op-last variant is dc ac tran op" $d7types9 {dc ac tran op}

# ⚠ THE SORT MUST BE STABLE, and this row is why that is not a comment. Two
# enabled rows of ONE type emit in the order the state lists them -- the state is
# the user's document. `lsort` is a merge sort and is stable; this pins it rather
# than trusting the manual.
set st7s [nfet_state /models/sky130.lib.spice {}]
dict set st7s analyses {{type tran enabled 1 step 1n stop 1u id first} {type op enabled 1} {type tran enabled 1 step 2n stop 2u id second}}
set d7ids {}
foreach e [ase::analysis_emit_order $st7s] {
  lappend d7ids [ase::state_get [lindex [ase::state_get $st7s analyses] [lindex $e 1]] id]
}
check "D7i two rows of one type keep the state's own order" $d7ids {{} first second}

# 0c: `{}` from ase::plot_sim_type used to mean two different things.
check "D7j plot_sim_type_reason: nothing enabled" \
  [ase::plot_sim_type_reason [dict replace [nfet_state /models/sky130.lib.spice {}] analyses {{type op enabled 0}}]] nothing-enabled
check "D7k plot_sim_type_reason: enabled, but this viewer has no mapping" \
  [ase::plot_sim_type_reason $st7] no-viewer-mapping
check "D7l plot_sim_type_reason is {} when there IS a mapping, and the mapping\
 itself is unchanged" \
  [list [ase::plot_sim_type_reason [nfet_state /models/sky130.lib.spice {}]] \
        [ase::plot_sim_type [nfet_state /models/sky130.lib.spice {}]]] {{} op}

# --- D8: THE EMITTED ANALYSIS LINES, PER TYPE (analyses batch, Stage 1) -------
# ⚠ D1 IS NOT SUFFICIENT ACCEPTANCE FOR THE DECK, AND THAT WAS MEASURED RATHER
# THAN SUSPECTED. D1's fixture is OP-ONLY: its golden deck carries the single
# line `op`, so the `dc`/`ac`/`tran` emit arms are never exercised by it, and D1
# is nonetheless what the analyses batch named as its byte-identity gate.
# MEASURED 2026-09-11 by changing the emit path on purpose and re-running the
# WHOLE suite:
#
#   dc emits its sweep as source,STOP,START,step  -> ALL PASS (248)
#   ac's hardwired sweep-mode word `dec` -> `oct` -> ALL PASS (248)
#
# i.e. NOTHING COMMITTED IN THIS TREE would have noticed a change that reversed
# every DC sweep in the product, or silently moved every AC sweep to octaves.
# Both were caught only by a 17-case render corpus held outside the repository,
# which is not a guard anybody inherits. These rows are that corpus's
# discriminating half, committed.
#
# ⚠ THEY PIN BEHAVIOUR, NOT AN IMPLEMENTATION, and that is checkable: this
# section was committed BEFORE the Stage 1 registry refactor and passes against
# the hand-written `switch` it was written to guard.
#
# ⚠ THESE ARE DECK BYTES, NOT DISPLAY STRINGS. The two display goldens that
# Stage 1 deliberately moved are test_ase_window P4 and test_ase_dialogs G2.
proc d8_lines {rows} {
  set st [nfet_state /models/sky130.lib.spice {}]
  dict set st analyses $rows
  set out {}
  foreach l [split [$::render $st $::netlist_text] "\n"] {
    if {[regexp {^(op|dc |ac |tran )} $l]} { lappend out [string trim $l] }
  }
  return $out
}
check "D8a dc emits source, start, stop, step IN THAT ORDER" \
  [d8_lines {{type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}}] \
  {{dc V2 0 1.8 0.01}}
check "D8b ac emits the HARDWIRED sweep-mode literal, then points/start/stop" \
  [d8_lines {{type ac enabled 1 points 10 start 1 stop 1meg}}] \
  {{ac dec 10 1 1meg}}
check "D8c tran emits step then stop" \
  [d8_lines {{type tran enabled 1 step 1n stop 10u}}] {{tran 1n 10u}}
check "D8d op emits the bare word" [d8_lines {{type op enabled 1}}] {op}
# ⚠ THE STAGE 3 BOUNDARY, PINNED AS TODAY'S BEHAVIOUR AND NOT AS A GOOD ONE.
# `ase::ui::anaargs` used to advertise `ac {points start stop dec}` while
# `chana_fields` returned three fields and render_deck hardwired the word `dec`
# -- the drift the registry exists to delete. Stage 1 is a PURE REFACTOR and
# reproduces it exactly: a stored `dec` is still ignored. The sweep-mode field
# is Stage 3's, where this row is EXPECTED to move and its replacement says so.
check "D8e a stored `dec` value is still IGNORED (Stage 3 moves this row)" \
  [d8_lines {{type ac enabled 1 points 20 start 10 stop 1g dec oct}}] \
  {{ac dec 20 10 1g}}
check "D8f four enabled types emit in emitorder: op, dc, ac, tran" \
  [d8_lines {{type op enabled 1} {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}
             {type ac enabled 1 points 10 start 1 stop 1meg}
             {type tran enabled 1 step 1n stop 10u}}] \
  {op {dc V2 0 1.8 0.01} {ac dec 10 1 1meg} {tran 1n 10u}}
check "D8g the STATE's row order does not change the emit order" \
  [d8_lines {{type tran enabled 1 step 1n stop 10u}
             {type ac enabled 1 points 10 start 1 stop 1meg}
             {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}
             {type op enabled 1}}] \
  {op {dc V2 0 1.8 0.01} {ac dec 10 1 1meg} {tran 1n 10u}}
check "D8h two rows of ONE type keep the state's own order (stable sort)" \
  [d8_lines {{type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}
             {type dc enabled 1 source V1 start -1 stop 1 step 0.1}}] \
  {{dc V2 0 1.8 0.01} {dc V1 -1 1 0.1}}
# ⚠ ADDED WITH THE STAGE 1 REGISTRY, because it asserts something that did not
# exist before it: ase::ui::arg_summary and render_deck now call THE SAME PROC,
# so the Analyses pane cannot show a setting the deck does not carry. Against
# this section's parent commit the column was a `key=value` dump and this row
# would have read `source=V2 start=0 stop=1.8 step=0.01`. The other D8 rows pin
# deck bytes and hold on both sides of that refactor; this one does not, which
# is exactly why it is here and not there.
check "D8i the Arguments column IS the emitted line" \
  [ase::ui::arg_summary {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}] \
  {dc V2 0 1.8 0.01}

# ⚠ AND AN INCOMPLETE ROW MUST NOT RAISE. ase::state_default seeds
# `{type dc enabled 0}` with no field keys, and the pane renders every row.
# MEASURED when this was not handled: `key "source" not known in dictionary`,
# and test_ase_dialogs died at 0 of 215 on the display arm while the headless
# arm stayed green -- 37 checks against 215.
check "D8j an incomplete row renders without raising" \
  [list [catch {ase::ui::arg_summary {type dc enabled 0}} d8e] $d8e] {0 {}}

# --- D3: strip robustness (input without trailing .end) ----------------------
set noend_lines [lrange [split [string trimright $netlist_text "\n"] "\n"] 0 end-1]
set noend "[join $noend_lines "\n"]\n"
set deck3 [$render [nfet_state /models/sky130.lib.spice {}] $noend]
set nend 0
foreach line [split $deck3 "\n"] { if {[string trim $line] eq ".end"} { incr nend } }
check "D3 exactly one .end" $nend 1
check "D3 .end is the last non-blank line" \
  [string trim [lindex [split [string trimright $deck3 "\n"] "\n"] end]] {.end}

# --- D4: temperature -> .temp (UI v2) ----------------------------------------
set st [nfet_state /models/sky130.lib.spice {}]
dict set st temperature 33.5
set deck4 [$render $st $netlist_text]
check_true "D4 custom temperature renders .temp 33.5" \
  [regexp -line {^\.temp 33\.5$} $deck4]
set st [nfet_state /models/sky130.lib.spice {}]
dict set st temperature bogus
set caught [catch {$render $st $netlist_text} err4]
check "D4 non-numeric temperature errors cleanly" $caught 1
check_true "D4 temperature error is the clean ase message" \
  [string match "ase:*" $err4]
set st [dict remove [nfet_state /models/sky130.lib.spice {}] temperature]
set deck4b [$render $st $netlist_text]
check_true "D4 missing temperature key still emits .temp 27" \
  [regexp -line {^\.temp 27$} $deck4b]

# --- D5: Save-All blankets -> deck (item 07 D12) ------------------------------
# save_all_v -> `.save all` ahead of the per-output .save lines
set st [nfet_state /models/sky130.lib.spice {}]
dict set st save_all_v 1
set deck5 [$render $st $netlist_text]
check_true "D5 save_all_v renders .save all" \
  [regexp -line {^\.save all$} $deck5]
set allpos [string first "\n.save all\n" $deck5]
set outpos [string first "\n.save -i(v1)\n" $deck5]
check_true "D5 .save all precedes the per-output .save" \
  [expr {$allpos >= 0 && $outpos >= 0 && $allpos < $outpos}]
# save_all_i -> `.options savecurrents` WITHOUT the explicit options row
# (options emptied first — the blanket alone must produce the line)
set st [nfet_state /models/sky130.lib.spice {}]
dict set st options {}
dict set st save_all_i 1
set deck5i [$render $st $netlist_text]
check_true "D5 save_all_i renders .options savecurrents" \
  [regexp -line {^\.options savecurrents$} $deck5i]
# both flags 0 (the fixture default): no blanket lines anywhere
set deck5off [$render [nfet_state /models/sky130.lib.spice {}] $netlist_text]
set st [nfet_state /models/sky130.lib.spice {}]
dict set st options {}
set deck5offi [$render $st $netlist_text]
check_true "D5 blankets off leave no blanket lines" \
  [expr {![regexp -line {^\.save all$} $deck5off] &&
         ![regexp -line {^\.options savecurrents$} $deck5offi]}]

# --- C0-C12: op_annot device OP save cards into the deck (plan step S4) ------
# doc/claude/specs/op_annotation.md S4 / issue 0617. `op_annot::save_cards`
# (src/op_annot.tcl:2144) already emits a correct block; nothing carried it into
# the deck ngspice runs, so a user who ran an OP analysis and pressed 6 got six
# blank rows. The seam these rows pin:
#
#   ase::op_cards_capture {state netlistpath}
#       ALL the policy. Called from ase::netlist right AFTER the artifact is
#       written -- that is the one path whose guard proves the design IS the
#       current schematic, which is the precondition the ENTRY-RELATIVE card
#       basis needs (ruling D2 / issue 0436). Clears the slot first; then, iff
#       the gate is on AND the sheet is clean AND op_annot::save_cards exists,
#       catch-calls it and stores {netlist <exact artifact text> block <block>}.
#       Reports every degraded path through ase::echo.
#   ase::op_cards_for {netlist_text} -> the stored block, iff the stored netlist
#       text is `eq` this render's text; {} otherwise.
#   ase::op_cards_put {netlist_text block}   the priming seam these rows use.
#   ase::op_cards_clear {}                   empty the slot.
#   ase::design_is_dirty {} -> exactly `xschem get modified`.
#
# render_deck is a pure CONSUMER: on a gate-on cache hit it appends one marker
# comment line matching `^\* op_annot .*Save All` and then the block VERBATIM --
# leader included, nothing stripped, nothing re-wrapped -- immediately above
# `.control`.
#
# THREE CONTRACTS THAT ARE MEASUREMENTS, NOT PREFERENCES:
#  * C8 -- the block's own `.save all` leader is LOAD-BEARING. ase.tcl:3161
#    emits `.save all` only when save_all_v is 1 and the schema default is 0, so
#    on this fixture the deck has none of its own. Measured on the committed
#    sky130_tests/test_nfet_final state: block WITH the leader -> 13 vectors,
#    6 device parameters, 5 node v(); block WITHOUT it -> 7 vectors, 6 device
#    parameters, ZERO node v(). "Tidying the duplicate away" deletes every node
#    voltage on the DEFAULT configuration. Invariant I2 / rule R2.
#  * C9 -- a save card is BARE. `.save @dev[p]`, never `.save i(@dev[p])`, which
#    ngspice drops silently (rule R4 / spec landmine 1 / issue 0607).
#  * C6 -- deck level, above `.control`. Inside `.control` a dot-card is
#    `save: no such command` (op_annot.tcl:2112-2118).
#
# C10 vs C7 is the distinction that keeps the reporting honest: a cache HIT
# whose block is EMPTY ("nothing below this cell is annotatable") must NOT be
# reported as a stale/absent cache ("re-netlist"). They need different
# sentences, so op_cards_for's `{}` return may not be render_deck's only signal.
#
# Every new-API call is catch-wrapped (`cx`), so on a tree where the seam does
# not exist yet each row goes red on its own with `ERR: invalid command name
# ...` instead of aborting the suite at the first missing proc.
proc cx {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR: $r" }
  return $r
}
proc c_echo_arm {} {
  set ::c_echo {}
  if {[info commands ::c_saved_ciw_echo] eq {}} {
    if {[info commands ::ciw_echo] ne {}} { rename ::ciw_echo ::c_saved_ciw_echo }
    proc ::ciw_echo {msg {tag {}}} { lappend ::c_echo [list $tag $msg] }
  }
}
proc c_echo_disarm {} {
  if {[info commands ::c_saved_ciw_echo] ne {}} {
    catch {rename ::ciw_echo {}}
    rename ::c_saved_ciw_echo ::ciw_echo
  }
}
proc c_echoed {pat {tag {}}} {
  foreach e $::c_echo {
    if {$tag ne {} && [lindex $e 0] ne $tag} continue
    if {[string match -nocase $pat [lindex $e 1]]} { return 1 }
  }
  return 0
}
proc c_cards {deck} {
  set n {}
  foreach l [split $deck "\n"] { if {[regexp {^\.save @} $l]} { lappend n $l } }
  return $n
}
proc c_marker {deck} {
  set n 0
  foreach l [split $deck "\n"] { if {[regexp {^\* op_annot .*Save All} $l]} { incr n } }
  return $n
}
proc c_count {deck pat} {
  set n 0
  foreach l [split $deck "\n"] { if {[regexp $pat $l]} { incr n } }
  return $n
}
# a synthetic block in exactly op_annot::_block's shape (leader + BARE cards)
set c_block {.save all
.save @m.xm1.mfake_nfet[id]
.save @m.xm1.mfake_nfet[gm]
.save @m.xm1.mfake_nfet[vth]
}
set c_blines [lrange [split $c_block "\n"] 0 end-1]

# C0: the seam exists at all. Every row below reads as `ERR: invalid command
# name ...` until it does, so this row names the cause once.
#
# ⚠ ISSUE 0679 ADDED THREE NAMES. The remedy the gate-off nudge prints must
# address a key the REGISTRY holds, not one it reconstructs from the design
# cellview (`ase::op_cards_nudge_key` is the 0648 LATCH key and stays exactly
# where it is -- F19f pins it, ase.tcl:622/:654 consume it). So the remedy gets
# its OWN key source and it is a LOOKUP: `ase::op_cards_remedy_key` resolving
# through `ase::sessions_for_state` (exact live-state match) then
# `ase::sessions_for_design` (the plural form `ase::session_for_design` becomes
# the first element of -- invariant I1, ONE lookup implementation, two
# consumers). Naming them here means a tree without the seam reds ONE row that
# says why, instead of a dozen reading `ERR: invalid command name`.
set c_missing {}
foreach c {::ase::op_cards_capture ::ase::op_cards_for ::ase::op_cards_put
           ::ase::op_cards_clear ::ase::design_is_dirty
           ::ase::op_cards_remedy_key ::ase::sessions_for_state
           ::ase::sessions_for_design} {
  if {[info commands $c] eq {}} { lappend c_missing $c }
}
check "C0 the S4 op-cards seam exists (0679: the remedy's registry lookup too)" \
  $c_missing {}

# C4: nothing cached -> the deck is byte-identical to the D1 golden. The feature
# is inert when it has nothing to say. (Already green before S4 lands; it is the
# regression guard for the two committed byte-exact deck goldens.)
cx {ase::op_cards_clear}
set deckC4 [$render [nfet_state /models/sky130.lib.spice {}] $netlist_text]
check_true "C4 empty cache leaves the D1 golden deck byte-identical" \
  [string equal $deckC4 $expected_deck]

# C5: gate OFF + a PRIMED cache -> still nothing. The gate, not the cache,
# decides. This is the row that catches "gate ignored, always emit": D1/C4 stay
# GREEN under that sabotage because their cache is empty.
cx {ase::op_cards_clear}
cx {ase::op_cards_put $netlist_text $c_block}
## 0927: the gate defaults ON now, so OFF has to be SPELLED OUT here. Without
## the explicit 0 this row would be testing the gate-on path under a gate-off
## name and every C5 assertion would invert.
set stC [dict replace [nfet_state /models/sky130.lib.spice {}] save_op_params 0]
set deckC5 [$render $stC $netlist_text]
check "C5 gate off emits no device save cards" [llength [c_cards $deckC5]] 0
check "C5 gate off emits no op_annot marker line" [c_marker $deckC5] 0
check_true "C5 gate off is byte-identical to the D1 golden" \
  [string equal $deckC5 $expected_deck]

# --- D6: ISSUE 0929 -- ONE `write` PER ANALYSIS ------------------------------
# THE ROW THE USER'S BUG WOULD HAVE FAILED. ngspice's `write` writes the CURRENT
# plot and every analysis makes a new one, so a single trailing `write` stored
# only the LAST analysis. On the user's tb_bandgap (op AND tran enabled, run
# exit 0, 468 device OP cards emitted) the raw came back with one plot,
# `Transient Analysis`, and `6` said "these are from a 'tran' run instead".
#
# Four terms, none of which passes on the shipped deck: one `set appendwrite`
# (without it the second write TRUNCATES the first), one `write` per enabled
# analysis, a `remzerovec` before each (it is per-plot, so one at the end only
# ever cleaned the last), and -- the ordering term -- every `write` must come
# AFTER its own analysis and BEFORE the next one.
set d6_st [nfet_state /models/sky130.lib.spice {}]
set d6_an {}
foreach a [ase::state_get $d6_st analyses] {
  if {[ase::state_get $a type] eq {tran}} {
    dict set a enabled 1 ; dict set a step 1n ; dict set a stop 1u
  }
  lappend d6_an $a
}
dict set d6_st analyses $d6_an
set d6_deck [$render $d6_st $netlist_text]
set d6_l [split [string trimright $d6_deck "\n"] "\n"]
set d6_seq {}
foreach l $d6_l {
  if {[regexp {^(set appendwrite|op|tran |remzerovec|write )} $l]} {
    lappend d6_seq [lindex [split [string trim $l]] 0]
  }
}
## 0964: AND THE OPERATING POINT NOW RUNS LAST HERE, WHICH IS NOT COSMETIC.
## C5 one row up left a block primed, and this state has the gate on with op AND
## tran enabled -- exactly the shape where the device requests move inside
## `.control`. A deck-level `.save` applies to every analysis, so today's cards
## were also recorded at every time point of the transient, where nothing reads
## them: +74.9 MB and +4.08 s measured on the user's own tb_bandgap. ngspice's
## save list is sticky forward-only -- `unsave` does not exist and a later
## `save all` does not reset it -- so asking inside `.control` only works if
## `op` is the LAST analysis. The 0929 property this row was written for is
## unchanged and still asserted: one `set appendwrite`, and every `write`
## immediately after its own analysis with a `remzerovec` between.
check "D6 0929/0964 op+tran: appendwrite once, then analysis/remzerovec/write\
 per analysis, in that order, with the operating point LAST" \
  $d6_seq {set tran remzerovec write op remzerovec write}
check "D6 0929 exactly one write per ENABLED analysis, and both name the raw" \
  [list [c_count $d6_deck {^write }] [c_count $d6_deck {^set appendwrite$}] \
        [c_count $d6_deck {^remzerovec$}]] {2 1 2}

# --- C5b: ISSUE 0928 -- GATE ON, but NO `op` ANALYSIS -> still nothing --------
# Device operating-point cards are for an operating-point analysis. Nothing
# gated the EMIT on one until 0928: `ase::op_analysis_enabled` had exactly ONE
# caller, the gate-off nudge, so a transient-only bench collected a `.save` card
# per device per parameter that no feature can read. A deck-level `.save` is
# sampled at EVERY timepoint, and 3000 cards measured +8.6 s / +242 MB on a
# 10068-point `.tran` against +0.03 s / +107 KB on an `.op`.
#
# (The `op` row is simply disabled here rather than swapping in a `tran` -- the
# fixture's tran row carries no step/stop and render_deck raises on it. What the
# guard reads is `op_analysis_enabled`, and nothing else.)
#
# THE THIRD TERM IS THE 0635 GUARD: the skip must leave a cache HIT, or
# render_deck's stale-artifact arm tells the user to re-netlist an artifact this
# session just wrote. The fourth is the non-vacuity control -- the SAME state
# with `op` re-enabled must emit the cards -- so a sabotage that simply stops
# emitting cannot pass this row.
cx {ase::op_cards_clear}
cx {ase::op_cards_put $netlist_text $c_block}
set stC5b [nfet_state /models/sky130.lib.spice {}]
set c5b_an {}
foreach a [ase::state_get $stC5b analyses] {
  if {[ase::state_get $a type] eq {op}} { dict set a enabled 0 }
  lappend c5b_an $a
}
dict set stC5b analyses $c5b_an
set deckC5b [$render $stC5b $netlist_text]
set stC5c [dict replace $stC5b analyses [ase::state_get [nfet_state /models/sky130.lib.spice {}] analyses]]
set deckC5c [$render $stC5c $netlist_text]
check "C5b 0928 gate ON but no `op` analysis emits NO device save cards" \
  [list [ase::op_analysis_enabled $stC5b] \
        [ase::op_gate_on [ase::state_get $stC5b save_op_params {}]] \
        [llength [c_cards $deckC5b]] \
        [llength [c_cards $deckC5c]]] \
  [list 0 1 0 3]

# C5b2: the CAPTURE half. C5b drives render_deck over a hand-primed cache, which
# cannot see whether the expensive half ran at all -- op_annot::save_cards is the
# ~350 ms/78-FET hierarchy walk, and skipping the walk is most of the point. This
# row watches the seam instead: with no `op` analysis the walk must not be
# called, and it must still leave a cache HIT so render_deck's stale-artifact
# sentence stays silent.
cx {ase::op_cards_clear}
set c5b2_nl [file join $scratch c5b2.spice]
set fh [open $c5b2_nl w]; puts -nonewline $fh $netlist_text; close $fh
set ::c5b2_called 0
rename ::op_annot::save_cards ::op_annot::c5b2_real
proc ::op_annot::save_cards {args} { incr ::c5b2_called ; return {} }
c_echo_arm
cx {ase::op_cards_capture $stC5b $c5b2_nl}
set c5b2_msgs [llength $::c_echo]
c_echo_disarm
rename ::op_annot::save_cards {}
rename ::op_annot::c5b2_real ::op_annot::save_cards
check "C5b2 0928 no `op` analysis: the walk is never called, a HIT is left, and\
 nothing is echoed" \
  [list $::c5b2_called \
        [cx {ase::op_cards_hit $netlist_text}] \
        $c5b2_msgs] \
  {0 1 0}
## re-prime for C6 below: this row's capture left an EMPTY hit by design.
cx {ase::op_cards_clear}
cx {ase::op_cards_put $netlist_text $c_block}

# C6: gate ON + a hit -> the block VERBATIM, in its own order, immediately above
# `.control`, behind exactly one marker line.
set stC [nfet_state /models/sky130.lib.spice {}]
dict set stC save_op_params 1
set deckC6 [$render $stC $netlist_text]
set dl [split [string trimright $deckC6 "\n"] "\n"]
set ci [lsearch -exact $dl {.control}]
set nb [llength $c_blines]
check_true "C6 the deck still has a .control line" [expr {$ci > 0}]
check "C6 exactly one op_annot marker line" [c_marker $deckC6] 1
check "C6 the block sits VERBATIM in the lines immediately above .control" \
  [expr {$ci > $nb ? [lrange $dl [expr {$ci - $nb}] [expr {$ci - 1}]] : {}}] \
  $c_blines
check "C6 the marker line is the line immediately above the block" \
  [expr {$ci > $nb && [regexp {^\* op_annot .*Save All} \
      [lindex $dl [expr {$ci - $nb - 1}]]] ? 1 : 0}] 1
check "C6 all three cards land ABOVE .control (deck level)" \
  [expr {[llength [c_cards $deckC6]] == 3 &&
         [lsearch -glob $dl {.save @*}] >= 0 &&
         [lsearch -exact $dl [lindex $c_blines end]] < $ci ? 1 : 0}] 1
check "C6 the per-output .save row is still emitted, ahead of the block" \
  [expr {[lsearch -exact $dl {.save -i(v1)}] >= 0 &&
         [lsearch -exact $dl {.save -i(v1)}] < [expr {$ci - $nb}] ? 1 : 0}] 1

# C7: gate ON + a cache primed with a DIFFERENT netlist text -- the run_existing
# shape: an artifact this session never netlisted, or one hand-edited since.
# No cards at all, and an error naming the remedy. Measured hazard: standing in
# `bandgap_opamp`, save_cards builds 103 entry-relative cards that name nothing
# in a tb_bandgap deck, and a wrong-named card is SILENTLY inert (rc=0, raw
# written, zero device vectors, empty stderr). A green run with blank rows is
# issue 0617 again, with the feature nominally on.
cx {ase::op_cards_clear}
cx {ase::op_cards_put "* some OTHER netlist\n.end\n" $c_block}
c_echo_arm
set deckC7 [$render $stC $netlist_text]
check "C7 a stale/absent cache emits no device save cards" \
  [llength [c_cards $deckC7]] 0
check "C7 a stale/absent cache emits no marker line" [c_marker $deckC7] 0
check "C7 the miss is REPORTED as an error naming Netlist and Run" \
  [c_echoed {*Netlist and Run*} error] 1
c_echo_disarm

# C8: the block's own `.save all` leader survives into the deck -- exactly one
# more than the same state rendered with the gate off, and ahead of the cards.
cx {ase::op_cards_clear}
cx {ase::op_cards_put $netlist_text $c_block}
set deckC8on  [$render $stC $netlist_text]
set deckC8off [$render [dict replace [nfet_state /models/sky130.lib.spice {}] \
                          save_op_params 0] $netlist_text]   ;# 0927: explicit OFF
check "C8 gate on adds exactly one .save all line (I2 / rule R2)" \
  [expr {[c_count $deckC8on {^\.save all$}] - [c_count $deckC8off {^\.save all$}]}] 1
set on_l [split [string trimright $deckC8on "\n"] "\n"]
check "C8 that .save all precedes the first device card" \
  [expr {[lsearch -exact $on_l {.save all}] >= 0 &&
         [lsearch -glob $on_l {.save @*}] >= 0 &&
         [lsearch -exact $on_l {.save all}] <
         [lsearch -glob $on_l {.save @*}] ? 1 : 0}] 1

# C9: rule R4 / spec landmine 1 -- the card is BARE on the way through.
# `.save i(@dev[p])` produces no vector and no diagnostic (issue 0607).
# (Vacuously green while no card is emitted at all; C6 is its non-vacuity
# control -- it is only meaningful once three cards actually appear.)
check "C9 no emitted card wears an i()/v() wrapper" \
  [c_count $deckC8on {^\.save\s+[iv]\(@}] 0

# C10: a cache HIT whose block is EMPTY -> nothing appended, and the report says
# NO DEVICE PRODUCED A CARD, not "re-netlist". save_cards returns {} (never a
# lone `.save all`) for a walk that matched nothing -- no PDK descriptor
# registered, or nothing below this cell is annotatable.
set c10_nl [file join $scratch c10.spice]
set f [open $c10_nl w]; puts -nonewline $f $netlist_text; close $f
rename ::op_annot::save_cards ::op_annot::c_real_save_cards
proc ::op_annot::save_cards {} { return {} }
cx {ase::op_cards_clear}
c_echo_arm
cx {ase::op_cards_capture $stC $c10_nl}
check "C10 an empty walk is REPORTED (no device produced a card)" \
  [expr {[c_echoed {*no device*}] || [c_echoed {*matched no*}] ? 1 : 0}] 1
set ::c_echo {}
set deckC10 [$render $stC $netlist_text]
check "C10 an empty block appends nothing" [llength [c_cards $deckC10]] 0
check "C10 an empty block appends no marker line" [c_marker $deckC10] 0
check "C10 an empty HIT is NOT reported as a stale cache" \
  [c_echoed {*Netlist and Run*}] 0
c_echo_disarm
rename ::op_annot::save_cards {}
rename ::op_annot::c_real_save_cards ::op_annot::save_cards

# C11: ase::design_is_dirty is the real predicate, not a stub. Driven in BOTH
# directions so C12 cannot pass on a constant.
# ⚠ `autosave_backup` is PARKED across the set_modify pair. set_modify(1)
# calls write_backup() (actions.c:207), and on the startup untitled buffer that
# drops an `untitled~.sch` into the repo ROOT -- issue 0609, the leak that turns
# three unrelated suites red. Parked, not deleted afterwards: the write happens
# inside the C call, so there is no window in which a cleanup could be racing it.
set c11_ab_had [info exists ::autosave_backup]
if {$c11_ab_had} { set c11_ab_val $::autosave_backup }
set ::autosave_backup 0
check "C11 design_is_dirty agrees with xschem get modified (clean)" \
  [list [cx {ase::design_is_dirty}] [xschem get modified]] {0 0}
xschem set_modify 1
check "C11 design_is_dirty agrees with xschem get modified (dirty)" \
  [list [cx {ase::design_is_dirty}] [xschem get modified]] {1 1}
xschem set_modify 0
check "C11 design_is_dirty back to 0" [cx {ase::design_is_dirty}] 0
if {$c11_ab_had} { set ::autosave_backup $c11_ab_val } else { unset ::autosave_backup }
check "C11 no untitled~.sch was dropped in the repo root (issue 0609)" \
  [file exists [file join $repo untitled~.sch]] 0

# C12: THE PROVISIONAL 0632 REFUSAL. With unsaved edits on the sheet the ASE
# path emits no cards AT ALL and says so -- it does not walk. On a dirty entry
# buffer the S3 walk rewrites the `~.sch` autosave backups of ancestor cells the
# user never touched (issue 0632); that ruling is with the user, and adopting
# either disputed behaviour silently would manufacture it. Safe choice = refuse.
# `design_is_dirty` is STUBBED rather than the buffer really dirtied, so the row
# tests the contract (capture consults the predicate and honours it) and stays
# independent of what a real dirty buffer would do.
set c12_swapped 0
if {[info commands ::ase::design_is_dirty] ne {}} {
  rename ::ase::design_is_dirty ::ase::c_real_design_is_dirty
  proc ::ase::design_is_dirty {} { return 1 }
  set c12_swapped 1
}
set ::c12_called 0
rename ::op_annot::save_cards ::op_annot::c_real_save_cards
proc ::op_annot::save_cards {} {
  set ::c12_called 1
  return ".save all\n.save @m.xm1.mfake_nfet\[id\]\n"
}
cx {ase::op_cards_clear}
c_echo_arm
cx {ase::op_cards_capture $stC $c10_nl}
check "C12 a dirty sheet never reaches op_annot::save_cards" $::c12_called 0
check "C12 a dirty sheet leaves the cache empty" \
  [cx {ase::op_cards_for $netlist_text}] {}
check "C12 the refusal is reported and names the unsaved edits" \
  [c_echoed {*unsaved*}] 1
check "C12 the refusal points at the open ruling (issue 0632)" \
  [c_echoed {*0632*}] 1
set deckC12 [$render $stC $netlist_text]
check "C12 the deck carries no device cards after a refusal" \
  [llength [c_cards $deckC12]] 0
c_echo_disarm
rename ::op_annot::save_cards {}
rename ::op_annot::c_real_save_cards ::op_annot::save_cards
if {$c12_swapped} {
  rename ::ase::design_is_dirty {}
  rename ::ase::c_real_design_is_dirty ::ase::design_is_dirty
}
cx {ase::op_cards_clear}

# --- C13: 0635 -- a refusal must say ONE thing, not two contradictory ones ----
# MEASURED ON THIS EXACT FIXTURE BEFORE THE FIX: a refusal echoes TWO sentences
# and the second contradicts the first.
#   capture -> "ASE: no device OP save cards were added -- this schematic has
#               unsaved edits ... Save the schematic, then netlist again."
#   render  -> "ASE: this deck was rendered from a netlist artifact that carries
#               no captured OP save cards ... Use Simulation > Netlist and Run
#               to regenerate both together."
# The user is told to netlist again AND that netlisting again is the wrong verb,
# in one pass, about an artifact THIS SESSION JUST WROTE. The mechanism is the
# three record-less refusal returns in ase::op_cards_capture: none of them calls
# ase::op_cards_put, so ase::op_cards_hit reads 0 and render_deck's stale arm --
# which exists for a genuinely FOREIGN artifact (the run_existing shape) -- fires
# on a local one.
#
# ⚠ C7 MUST STAY GREEN, AND C13d IS THE ROW THAT SAYS SO. Recording the refusal
# may only silence the stale sentence for THIS netlist text; a genuinely
# different one must still be reported, or the fix has traded a contradiction
# for a silence.
# ⚠ C12's TWO CLAIMS MUST ALSO SURVIVE: the cache still yields {} for this text
# (an empty BLOCK is not a HIT-less cache) and the deck still carries no cards.
proc c_echoed_n {pat {tag {}}} {
  set n 0
  foreach e $::c_echo {
    if {$tag ne {} && [lindex $e 0] ne $tag} continue
    if {[string match -nocase $pat [lindex $e 1]]} { incr n }
  }
  return $n
}
set c13_swapped 0
if {[info commands ::ase::design_is_dirty] ne {}} {
  rename ::ase::design_is_dirty ::ase::c_real_design_is_dirty
  proc ::ase::design_is_dirty {} { return 1 }
  set c13_swapped 1
}
cx {ase::op_cards_clear}
c_echo_arm
cx {ase::op_cards_capture $stC $c10_nl}
set deckC13 [$render $stC $netlist_text]
check "C13 0635 the dirty refusal still names the unsaved edits" \
  [c_echoed {*unsaved*}] 1
check "C13 0635 and NO contradicting Netlist-and-Run sentence follows it" \
  [c_echoed {*Netlist and Run*}] 0
check "C13 0635 exactly ONE save-card sentence reaches the user" \
  [c_echoed_n {*save card*}] 1
check "C13b 0635 the refusal leaves a HIT for this netlist text" \
  [cx {ase::op_cards_hit $netlist_text}] 1
check "C13b ...whose block is still EMPTY (C12's claim survives)" \
  [cx {ase::op_cards_for $netlist_text}] {}
check "C13 the deck still carries no device cards after a refusal" \
  [llength [c_cards $deckC13]] 0
c_echo_disarm
if {$c13_swapped} {
  rename ::ase::design_is_dirty {}
  rename ::ase::c_real_design_is_dirty ::ase::design_is_dirty
}

# C13c: the THIRD refusal return -- op_annot::save_cards itself raising. Same
# defect, same fix site: the record has to be stored before the early return.
# (design_is_dirty is the REAL one again here, and C11 left the buffer clean, so
# this path genuinely reaches save_cards.)
rename ::op_annot::save_cards ::op_annot::c_real_save_cards
proc ::op_annot::save_cards {} { error "zzc13 synthetic walk failure" }
cx {ase::op_cards_clear}
c_echo_arm
cx {ase::op_cards_capture $stC $c10_nl}
set deckC13c [$render $stC $netlist_text]
check "C13c 0635 a save_cards RAISE is reported, naming the failure" \
  [c_echoed {*zzc13*}] 1
check "C13c 0635 a save_cards RAISE also leaves a HIT" \
  [cx {ase::op_cards_hit $netlist_text}] 1
check "C13c 0635 and no contradicting Netlist-and-Run sentence follows it" \
  [c_echoed {*Netlist and Run*}] 0
check "C13c exactly ONE save-card sentence reaches the user" \
  [c_echoed_n {*save card*}] 1
c_echo_disarm
rename ::op_annot::save_cards {}
rename ::op_annot::c_real_save_cards ::op_annot::save_cards

# C13d: NON-VACUITY, and it is C7's claim re-asserted in the one session state
# that could have swallowed it. A refusal record was just stored for
# $netlist_text; a DIFFERENT artifact must still be reported as one nobody
# captured. Green before the change (there is no record at all) and green after
# (the record is for another text) -- the row exists so a fix that silences the
# stale arm WHOLESALE cannot pass.
c_echo_arm
set deckC13d [$render $stC "* a genuinely DIFFERENT netlist artifact\n.end\n"]
check "C13d 0635 NON-VACUITY a DIFFERENT netlist text is still reported (C7 stands)" \
  [c_echoed {*Netlist and Run*} error] 1
c_echo_disarm
cx {ase::op_cards_clear}

# --- D6: pre_commands -> the head of the .control block ----------------------
# ngspice's `pre_*` family runs BEFORE the netlist is parsed — the only way to
# load a compiled Verilog-A module (`pre_osdi x.osdi`; there is no `.osdi`
# dot-card). IHP SG13G2 needs four of them or every bench with a MOS/varicap/
# r3_cmc dies at "could not find a valid modelname".
set ::ASE_TEST_OSDI_DIR /tmp/osdi_fixture
set st [nfet_state /models/sky130.lib.spice {}]
dict set st pre_commands {{cmd {pre_osdi $::ASE_TEST_OSDI_DIR/psp103.osdi}}
                          {cmd {pre_osdi $::ASE_TEST_OSDI_DIR/r3_cmc.osdi}}}
set deck6 [$render $st $netlist_text]
check_true "D6 pre_ command rendered with its \$::VAR expanded" \
  [regexp -line {^pre_osdi /tmp/osdi_fixture/psp103\.osdi$} $deck6]
set ctlpos [string first "\n.control\n" $deck6]
set prepos [string first "\npre_osdi /tmp/osdi_fixture/psp103.osdi\n" $deck6]
set oppos  [string first "\nop\n" $deck6]
check_true "D6 pre_ commands sit inside .control, ahead of the analyses" \
  [expr {$ctlpos >= 0 && $prepos > $ctlpos && $oppos > $prepos}]
check_true "D6 both entries rendered, in order" \
  [expr {[string first "psp103.osdi" $deck6] <
         [string first "r3_cmc.osdi" $deck6]}]
# a bare string entry (hand-written state) is taken verbatim, like `includes`
set st [nfet_state /models/sky130.lib.spice {}]
dict set st pre_commands {{pre_set foo=1}}
check_true "D6 a bare-string entry renders verbatim" \
  [regexp -line {^pre_set foo=1$} [$render $st $netlist_text]]
# default state carries none, so no stray line leaks into an ordinary deck
check_true "D6 no pre_ line when the state has none" \
  [expr {![regexp -line {^pre_} [$render \
      [nfet_state /models/sky130.lib.spice {}] $netlist_text]]}]
check "D6 pre_commands is in the canonical schema order" \
  [lsearch -exact $ase::schema_keys pre_commands] \
  [expr {[lsearch -exact $ase::schema_keys includes] + 1}]

# --- P1: result_probe keying (UI v2 Outputs Value column) --------------------
# unnamed outputs (no `name` key) are keyed by their expr; named outputs stay
# keyed by name (backward compatible: F10/E1c read key `id`)
set probe [ase::backend_hook ngspice result_probe]
## ⚠ THE CALL IS CAUGHT, AND IT IS NOT PADDING (issue 1429). These two states
## are `ase::state_default` with an `outputs` key bolted on: no `design`, so no
## cell, so ase::backend::ngspice::raw_file cannot answer. Since ⚖ R3 made
## `result_probe` a dispatcher it resolves the results-file path on every call,
## inside a `catch` whose absence is exactly the change these rows would then
## be the first to meet -- measured, removing that `catch` killed this whole
## file HERE with `UNEXPECTED ERROR: ase: state design has no cell (raw_file)`
## and no `RESULT:` line, which in a sabotage log reads as "nothing went red".
## Row RD14 is the contract; this wrapper is what lets the file reach it.
proc p1probe {st log} {
  set rc [catch {uplevel #0 [list $::probe $st $log]} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc p1val {res k} {
  if {[catch {dict exists $res $k} e] || !$e} { return $res }
  return [dict get $res $k]
}
set logtext_p1 "Some banner line\n-i(v1) = 4.096837e-04\nNo. of Data Rows : 1\n"
set stp [ase::state_default]
dict set stp outputs {{expr -i(v1) save 1}}
check "P1 result_probe keys unnamed outputs by expr" \
  [p1val [p1probe $stp $logtext_p1] -i(v1)] 4.096837e-04
set stp [ase::state_default]
dict set stp outputs {{name id expr -i(v1) save 1}}
check "P1 named output still keyed by name" \
  [p1val [p1probe $stp $logtext_p1] id] 4.096837e-04

# --- F: ase::format_value engineering-notation display (item 09) -------------
# F1 suffix table, F2 out-of-range %g fallback, F3 non-numeric verbatim,
# F4 the ase_eng_notation gate (default 1 via set_ne at ase.tcl source time)
check "F0 gate defaults to 1" $::ase_eng_notation 1
check "F1 1.04e-4 -> 104u" [ase::format_value 1.04e-4] 104u
check "F1 4.096837e-4 -> 409.7u" [ase::format_value 4.096837e-4] 409.7u
check "F1 1e-3 -> 1m" [ase::format_value 1e-3] 1m
check "F1 27 -> 27" [ase::format_value 27] 27
check "F1 1.5e6 -> 1.5Meg" [ase::format_value 1.5e6] 1.5Meg
check "F1 0 -> 0" [ase::format_value 0] 0
check "F1 negative keeps sign (-1.04e-4 -> -104u)" [ase::format_value -1.04e-4] -104u
check "F1 sub-unity gets a suffix (0.5 -> 500m)" [ase::format_value 0.5] 500m
check "F1 mantissa rounding rolls over (999.96e-6 -> 1m)" \
  [ase::format_value 999.96e-6] 1m
check "F1 sub-femto clamps to f (5e-16 -> 0.5f)" [ase::format_value 5e-16] 0.5f
check "F1 clamp edge (1e-18 -> 0.001f)" [ase::format_value 1e-18] 0.001f
check "F1 exponent-form unity (1.000000e+00 -> 1)" \
  [ase::format_value 1.000000e+00] 1
check "F1 plain decimal unchanged (1.8 -> 1.8)" [ase::format_value 1.8] 1.8
check "F2 1e15 falls back to %g" [ase::format_value 1e15] 1e+15
check "F2 9e-19 falls back to %g" [ase::format_value 9e-19] 9e-19
check "F3 expression verbatim (vdd/2)" [ase::format_value vdd/2] vdd/2
check "F3 blank verbatim" [ase::format_value {}] {}
check "F3 already-suffixed verbatim (1k)" [ase::format_value 1k] 1k
set ::ase_eng_notation 0
check "F4 gate off returns raw (set ::ase_eng_notation 0 -> 1.04e-4)" \
  [ase::format_value 1.04e-4] 1.04e-4
set ::ase_eng_notation 1
check "F4 gate restored -> 104u again" [ase::format_value 1.04e-4] 104u

# --- N1: ase::netlist on the scratch fixture ---------------------------------
set rundir [file normalize [file join $scratch run]]
set st [nfet_state $models $rundir]
# --- 0698: the design window must be BOUND before the first ase::netlist -----
# ase::netlist (src/ase.tcl:866-874) self-loads the design ONLY when no display
# exists; under X it refuses with "design ... is not the current schematic" and
# this suite fell into its UNEXPECTED ERROR catch-all with most of its checks
# never reached. The guard is CORRECT -- it must never clobber an open GUI
# window -- so the wrong side is the suite, which never opens the design window
# the guard's GUI arm documents (Session > Design Window).
#
# THE BIND BELONGS ABOVE THIS ROW; this row is its postcondition. It must also
# stay AFTER the scratch library.defs block: bound earlier, the symbol resolves
# against the ambient registry and the XM1 row below fails instead -- a failure
# that looks nothing like this one.
#
# The path is resolved through `xschem cellview_path`, the SAME accessor
# ase::netlist compares against, so the row and the guard cannot disagree about
# which file "the design" is. Headless the expectation is vacuously true, and
# deliberately so: there the guard's own self-load arm is what must stay
# exercised, and an unconditional bind would silently stop exercising it.
ase_bind_design_window $st
set _d698 [dict get $st design]
set _v698 schematic
if {[dict exists $_d698 view] && [dict get $_d698 view] ne {}} { set _v698 [dict get $_d698 view] }
set _p698 [file normalize [xschem cellview_path \
             [dict get $_d698 lib]/[dict get $_d698 cell] $_v698]]
set _c698 [file normalize [xschem get schname]]
if {![info exists ::has_x] || $_c698 eq $_p698} {
  set _b698 bound
} else {
  set _b698 "UNBOUND (current=[file tail $_c698])"
}
check "N1 design window bound before the first netlist (0698)" $_b698 bound

set nl [ase::netlist $st]
check "N1 netlist path" $nl [file join $rundir nfet_clean.spice]
check_true "N1 netlist file exists" [file isfile $nl]
set f [open $nl r]; set nltext [read $f]; close $f
check_true "N1 netlist contains XM1" [string match "*XM1*" $nltext]
check_true "N1 netlist has no .control" [expr {![regexp -line {^\.control} $nltext]}]
check_true "N1 netlist has no .lib" [expr {![regexp -line {^\.lib } $nltext]}]
check "N1 last non-blank netlist line is .end" \
  [string trim [lindex [split [string trimright $nltext "\n"] "\n"] end]] {.end}

# --- N2: rundir defaulting (empty rundir -> $netlist_dir, created) -----------
set ::netlist_dir [file join $scratch simdefault]
set stn [ase::state_default]
check "N2 empty rundir falls back to netlist_dir" [ase::rundir $stn] [file join $scratch simdefault]
check_true "N2 default rundir was created" [file isdirectory [file join $scratch simdefault]]

# --- 0618: the simulation log's provenance framing ---------------------------
# MEASURED BEFORE THE FIX: `string equal $logtext $::execute(data,last)` is 1 --
# the log file IS the simulator's stdout and nothing else. It carries no command
# line, no working directory, no deck path, no exit code and no elapsed time,
# and four of those five are LOCALS in ase::run_deck that are simply thrown away
# (deckpath, logpath, cmd, and the `cd $rd` directory); only elapsed needs a new
# stamp, taken before `eval execute` and CARRIED, because run_done fires from
# execute_fileevent on EOF and a stamp taken there measures the wrong interval.
#
# ⚠ THE LANDMINE THAT MATTERS MOST IS E1g. `ase::run_done` parses $data for
# results and the `result_probe` backend hook reads it; the framing goes in the
# FILE and the simulator's own region must stay BYTE-IDENTICAL. E1c is the
# before/after pin the issue demands (id within 1e-3 of 4.096837e-04) and it is
# already in this file, unchanged, immediately above.
#
# ⚠ AND THE HEADER MUST SURVIVE A RUN THAT PRODUCES NOTHING -- that is where it
# is most wanted. Measured, the failure splits in two: (i) `execute` returns -1
# (missing binary) and run_done NEVER FIRES, so today no log file is created at
# all (row E2b); (ii) the simulator launches and fails silently, run_done fires
# and today writes a ZERO-BYTE log (row E4). Only a header written in run_deck
# covers (i).

## The value of `<key> :` in the log header, or MISSING-FIELD. Stops at the
## delimiter so a simulator line of the same shape cannot answer for the header.
proc e_hdrfield {logtext key} {
  foreach l [split $logtext "\n"] {
    if {[string match {--- simulator output ---*} $l]} break
    if {[regexp "^\\s*$key\\s*:\\s*(.*)\$" $l -> v]} { return [string trim $v] }
  }
  return MISSING-FIELD
}
## The bytes between the `--- simulator output ---` delimiter line and the
## `=== exit ` footer: the region 0618 says must stay byte-identical to the
## simulator's own stdout. NO-DELIM / NO-FOOTER rather than a silent {} so a
## missing frame reds as itself instead of as a data mismatch.
proc e_logbody {logtext} {
  set d "--- simulator output ---\n"
  set i [string first $d $logtext]
  if {$i < 0} { return NO-DELIM }
  set rest [string range $logtext [expr {$i + [string length $d]}] end]
  set j [string last "\n=== exit " $rest]
  if {$j < 0} { return NO-FOOTER }
  ## ⚠ $j-1, NOT $j: the newline the search anchors on belongs to the FRAMING,
  ## not to the simulator. Measured while implementing — with `0 $j` this helper
  ## can never return {} for any input (index 0 already yields one character), so
  ## E1g ("the region is byte-identical to execute(data,last)") and E4 ("the
  ## region is EMPTY, not absent") were mutually unsatisfiable, and a simulator
  ## whose last line carried no newline read as NO-FOOTER. The framing therefore
  ## always writes its own \n before `=== exit `, and this excludes it.
  return [string range $rest 0 [expr {$j - 1}]]
}
## Read a whole file, or {} when it is not there.
proc e_slurp {p} {
  if {![file isfile $p]} { return {} }
  set f [open $p r] ; set d [read $f] ; close $f
  return $d
}

# --- E1: real ngspice end-to-end (guarded leg) -------------------------------
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: E1 end-to-end leg (ngspice not found)"
} else {
  set st [nfet_state $models $rundir]
  set id [ase::run $st {set ::e1_callback_fired 1}]
  set ec [ase::wait $id]
  check "E1a ngspice exit code 0" $ec 0
  check_true "E1a deck file written" [file isfile [file join $rundir nfet_clean_ase.spice]]
  set logf [file join $rundir nfet_clean_ase.log]
  set logtext {}
  if {[file isfile $logf]} { set f [open $logf r]; set logtext [read $f]; close $f }
  check_true "E1b log file exists, non-empty, has data rows" \
    [expr {[file isfile $logf] && [file size $logf] > 0 \
           && [string match "*No. of Data Rows*" $logtext]}]
  set res [ase::last_result]
  set idok 0
  if {[dict exists $res id]} {
    set v [dict get $res id]
    if {abs($v - 4.096837e-04) / 4.096837e-04 < 1e-3} { set idok 1 }
  }
  check_true "E1c parsed Id within 1e-3 of 4.096837e-04" $idok
  if {!$idok} { puts "  E1c last_result: $res" }
  check "E1d user callback fired" $::e1_callback_fired 1

  # E1e/E1f/E1g -- 0618. The five facts, and the region that must not move.
  set e1_deck [file join $rundir nfet_clean_ase.spice]
  set e1_cmd  [list ngspice -b $e1_deck 2>@1]
  set e1_lines [split [string trimright $logtext "\n"] "\n"]
  check_true "E1e the log opens with a run banner naming the cell" \
    [regexp {^=== ase run nfet_clean [^=]+ ===$} [lindex $e1_lines 0]]
  # ⚠ THE EXACT ARGUMENT LIST HANDED TO `execute`, `2>@1` INCLUDED AND NOTHING
  # RESOLVED. A header that auto_execok-resolved argv0 would be a SECOND source
  # of truth about which binary ran, computed at a different instant.
  check "E1e the header carries simulator, command, directory and deck" \
    [list [e_hdrfield $logtext simulator] [e_hdrfield $logtext command] \
          [e_hdrfield $logtext directory] [e_hdrfield $logtext deck]] \
    [list ngspice $e1_cmd $rundir $e1_deck]
  set e1_foot [lindex $e1_lines end]
  set e1_secs {}
  regexp {^=== exit 0 after ([0-9]+\.[0-9]+) s ===$} $e1_foot -> e1_secs
  check "E1f the log closes with the exit code and the elapsed seconds" \
    [list [regexp {^=== exit 0 after [0-9]+\.[0-9]+ s ===$} $e1_foot] \
          [expr {[string is double -strict $e1_secs] && $e1_secs >= 0 ? 1 : 0}]] \
    {1 1}
  # ⚠ THE ONE THAT PROTECTS EVERY DOWNSTREAM READER. result_probe (an anchored
  # per-line regexp) and run_diagnostics both read $data IN MEMORY, so they
  # cannot see the framing at all -- but ase::ui::show_log and every test that
  # greps the FILE can, and the issue's first landmine is that the simulator's
  # own region stays byte-identical.
  check_true "E1g the simulator's region is BYTE-IDENTICAL to execute(data,last)" \
    [string equal [e_logbody $logtext] $::execute(data,last)]
  if {![string equal [e_logbody $logtext] $::execute(data,last)]} {
    puts "  E1g body [string length [e_logbody $logtext]] bytes,\
 execute(data,last) [string length $::execute(data,last)] bytes"
  }
}

# --- E2: missing simulator binary -> clean error (public backend seam) -------
proc ase_test_fake_run_cmd {state deckpath} {
  return [list ase_definitely_missing_binary_xyz -b $deckpath 2>@1]
}
ase::register_backend fakesim [dict create \
  render_deck  [ase::backend_hook ngspice render_deck] \
  run_cmd      ase_test_fake_run_cmd \
  log_file     [ase::backend_hook ngspice log_file] \
  result_probe [ase::backend_hook ngspice result_probe] \
  raw_file     [ase::backend_hook ngspice raw_file]]
# ⚠ ITS OWN RUNDIR. The ngspice log_file hook is <rundir>/<cell>_ase.log, so
# with E1's rundir this leg writes E1's log path -- harmless while the log is
# only ever written on completion, and a silent clobber the moment run_deck
# starts writing a header before the launch. E2b is about that header.
set e2dir [file normalize [file join $scratch run_e2]]
set st [nfet_state $models $e2dir]
dict set st simulator fakesim
# ase_no_modal: under X the failed launch pops a modal tk_messageBox that nobody
# can click and the suite hangs here forever (issue 0803). Suppressed for this
# ONE call, restored immediately, same assertion in both arms.
ase_no_modal {set caught [catch {ase::run $st} err]}
check "E2 missing binary raises an error" $caught 1
check_true "E2 error is the clean ase message" [string match "ase:*" $err]

# E2b -- 0618, the FAILED LAUNCH. Measured before the fix: `execute` returns -1,
# ase::run_deck raises, ase::run_done never fires and NO log file is written at
# all, so the record of what was attempted is lost in exactly the case a user
# debugs. The header belongs in run_deck, before the launch, for this row.
set e2_log [file join $e2dir nfet_clean_ase.log]
set e2_txt [e_slurp $e2_log]
check "E2b 0618 a failed LAUNCH still leaves a log, and it is header-only" \
  [list [file isfile $e2_log] \
        [expr {[regexp {^=== ase run nfet_clean [^=]+ ===$} \
                 [lindex [split $e2_txt "\n"] 0]] ? 1 : 0}] \
        [e_hdrfield $e2_txt command] \
        [expr {[string first {--- simulator output ---} $e2_txt] >= 0 ? 1 : 0}] \
        [expr {[string first {=== exit } $e2_txt] >= 0 ? 1 : 0}]] \
  [list 1 1 [list ase_definitely_missing_binary_xyz -b \
               [file join $e2dir nfet_clean_ase.spice] 2>@1] 0 0]

# --- E3: unknown simulator -> error naming it --------------------------------
set st [nfet_state $models $rundir]
dict set st simulator nosuchsim
set caught [catch {ase::run $st} err]
check "E3 unknown simulator raises an error" $caught 1
check_true "E3 error mentions nosuchsim" [string match "*nosuchsim*" $err]

# --- E4: 0618, the run that LAUNCHES and produces nothing --------------------
# "The log is opened `w`, so a failed run's log is the whole record -- the
# header must be written even when the simulator produces no output at all.
# That is precisely the case where it is most wanted." Measured on this tree:
# with /bin/false as the simulator, run_done DOES fire and writes a ZERO-BYTE
# log. /bin/false rather than the plan's `sh -c {exit 3}` because this exact
# shape was measured through execute()/execute_fileevent already; the exit code
# is 1, which is still distinct from E1f's 0, so the footer cannot be a constant.
if {![file executable /bin/false]} {
  puts "SKIPPED: E4 empty-output leg (/bin/false not executable)"
} else {
  proc ase_test_false_run_cmd {state deckpath} { return [list /bin/false 2>@1] }
  ase::register_backend failsim [dict create \
    render_deck  [ase::backend_hook ngspice render_deck] \
    run_cmd      ase_test_false_run_cmd \
    log_file     [ase::backend_hook ngspice log_file] \
    result_probe [ase::backend_hook ngspice result_probe] \
    raw_file     [ase::backend_hook ngspice raw_file]]
  set e4dir [file normalize [file join $scratch run_e4]]
  set st [nfet_state $models $e4dir]
  dict set st simulator failsim
  set e4id [ase::run $st]
  set e4ec [ase::wait $e4id]
  set e4_log [file join $e4dir nfet_clean_ase.log]
  set e4_txt [e_slurp $e4_log]
  check "E4 the empty run exits non-zero" $e4ec 1
  check "E4 0618 a run with NO output still has a header, a delimiter and a footer" \
    [list [file isfile $e4_log] \
          [expr {[regexp {^=== ase run nfet_clean [^=]+ ===$} \
                   [lindex [split $e4_txt "\n"] 0]] ? 1 : 0}] \
          [e_hdrfield $e4_txt command] \
          [expr {[string first {--- simulator output ---} $e4_txt] >= 0 ? 1 : 0}] \
          [expr {[regexp -line {^=== exit 1 after [0-9]+\.[0-9]+ s ===$} $e4_txt] ? 1 : 0}]] \
    [list 1 1 {/bin/false 2>@1} 1 1]
  check "E4 0618 and the simulator's own region is EMPTY, not absent" \
    [e_logbody $e4_txt] {}
}

# --- E4b: 0618, the THREE-ARGUMENT run_done shape ----------------------------
# tests/headless/test_ase_cosim.tcl calls `ase::run_done <logpath> <state> {}`
# directly at SIX sites (:1019 :1036 :1049 :1056 :1061 :1067) and that suite is
# 341 green checks. A new run_done parameter MUST default, or every one of them
# dies with `wrong # args`; and with no metadata to frame with, the file must be
# the simulator's data verbatim -- byte-identical to today, no header invented
# from `execute(cmd,last)`, which is a process-global belonging to whatever ran
# most recently.
set e4b_log [file join $scratch e4b.log]
set ::execute(data,last) "zzE4B synthetic simulator output\nNo. of Data Rows : 1\n"
set ::execute(exitcode,last) 0
set e4b_rc [catch {ase::run_done $e4b_log [nfet_state $models $rundir] {}} e4b_err]
check "E4b 0618 run_done still accepts THREE arguments (test_ase_cosim's shape)" \
  [list $e4b_rc $e4b_err] {0 {}}
check_true "E4b 0618 with no metadata the file is execute(data,last), byte for byte" \
  [string equal [e_slurp $e4b_log] $::execute(data,last)]

# ============================================================================
# RG -- ISSUE 1389: ASE-L REFUSES A SECOND RUN ON A RESULTS FILE IT IS WRITING
# ============================================================================
# The user's report was "annotates blanks and prints zilch in RDW". MEASURED
# 2026-09-08 on their own bench: `Netlist and Run` fired twice,
# /tmp/Xschem.log.1 holds two `starting the simulator` lines before either
# `simulation finished`, and because the deck carries `set appendwrite` (issue
# 0929) run 2 APPENDED its Operating Point plot to the raw run 1 had not
# finished writing. Two datasets, `xschem raw points` = 2,
# op_annot::opdump_autofill correctly refusing to merge, and 423 vectors on the
# sheet where the identical deck with one dataset gives 8248.
#
# The merge gate is not the defect; the double launch is. These rows are about
# the double launch and nothing else.
#
#   RG1  a live run claims its raw path, and an ORDINARY launch still launches
#   RG2  a second launch on the SAME raw is refused and `execute` IS NOT CALLED
#   RG3  the live run's deck and results file are untouched by the refusal
#   RG4  the refusal reaches the CIW channel, once, as a `note`
#   RG5  it names the way out by READING 1391's constant -- and that constant
#        reads `Simulation > Stop`: constant AND golden, the W1t discipline
#   RG6  the CIW is RAISED, NOT ACTIVATED -- structural, plus a GUI leg that
#        watches which of the two helpers the refusal actually reaches for
#   RG7  two DIFFERENT results files do not block each other
#   RG8  a launch that FAILS (`execute` -1) leaves no lock
#   RG9  a stale lock (the process is gone) does not refuse, and is dropped
#   RG10 an ordinary completion clears the lock IN ase::run_done -- not by the
#        stale-lock sweep, which is what a table entry left behind would prove
#   RG11 `Simulation > Stop` -- the remedy the sentence names -- frees it too,
#        and the launch that follows is NOT refused
#   RG12 the ASE-L doors refuse WITHOUT `set_status fail` and WITHOUT
#        re-netlisting, because the earlier run is healthy and still Running
#
# ⚠ RG1, RG7 and RG11 ARE NOT DECORATION. A patch that simply broke launching
# would satisfy RG2, RG3, RG4, RG5 and RG12 with full marks; those three are
# the only rows that can tell "refuses a second run" from "refuses to run".

## How many times `execute` was called while $script ran, plus what the script
## did: {n rc result}. THE ROW THAT MATTERS IS THE ONE THAT COUNTS ZERO --
## "the message said no" and "no simulator was started" are different claims,
## and only the second one is the feature.
proc rg_execs {script} {
  set ::rg_n 0
  rename ::execute ::rg_saved_execute
  proc ::execute {status args} {
    incr ::rg_n
    return [eval [linsert $args 0 ::rg_saved_execute $status]]
  }
  set rc [catch {uplevel 1 $script} r]
  rename ::execute {}
  rename ::rg_saved_execute ::execute
  return [list $::rg_n $rc $r]
}
## The CIW channel, spied at its own sink rather than at ase::echo, so a row
## proves the sentence really travelled ase::echo -> notify_safe -> notify ->
## ciw_echo. Under --nolog `.ciw` is never created, so the shipped ciw_echo
## no-ops on its `winfo exists` guard and would see nothing.
proc rg_ciw {script} {
  set ::rg_said {}
  set had [expr {[info commands ::ciw_echo] ne {}}]
  if {$had} { rename ::ciw_echo ::rg_saved_ciw }
  proc ::ciw_echo {line {tag {}}} { lappend ::rg_said [list $tag $line] ; return {} }
  catch {uplevel 1 $script}
  catch {rename ::ciw_echo {}}
  if {$had} { rename ::rg_saved_ciw ::ciw_echo }
  return $::rg_said
}
## A proc body with its comments dropped, so a sentence quoted in a comment
## cannot satisfy a row about what the CODE says (test_ase_simcaps's a_body).
proc rg_body {cmd} {
  if {![llength [info commands $cmd]]} { return NOPROC }
  if {[catch {info body $cmd} b]} { return "RAISED:$b" }
  set out {}
  foreach l [split $b "\n"] { if {[regexp {^\s*#} $l]} continue ; lappend out $l }
  return [join $out "\n"]
}
proc rg_has {hay needle} { return [expr {[string first $needle $hay] >= 0 ? 1 : 0}] }
## Is there a table entry for this key AT ALL? Deliberately NOT
## ase::run_in_flight: that one DROPS a dead lock as it answers, so it can
## never tell "run_done released it" from "nobody has looked yet".
proc rg_tabled {key} {
  if {![info exists ::ase::runlocks]} { return NOVAR }
  return [expr {[dict exists [set ::ase::runlocks] $key] ? 1 : 0}]
}
proc rg_wr {path text} {
  file mkdir [file dirname $path]
  set fp [open $path w] ; puts -nonewline $fp $text ; close $fp
}
## Reap a run without waiting out its sleep: the door Simulation > Stop uses
## (kill_running_cmds <id> -9), then the ordinary completion path.
proc rg_reap {id} {
  if {![string is integer -strict $id]} { return NOID }
  if {![info exists ::execute(pipe,$id)]} { return GONE }
  catch {kill_running_cmds $id -9}
  catch {ase::wait $id}
  return [expr {[info exists ::execute(pipe,$id)] ? {STILL-THERE} : {reaped}}]
}

# A simulator that stays up long enough to be raced. `sleep`, and NOT a stub
# that reads stdin: `execute` opens the pipe in mode `r`, so the child inherits
# this process's stdin and a stub calling `head` would eat the suite's script.
if {[auto_execok sleep] eq {}} {
  puts "SKIPPED: RG run-guard section (no sleep(1))"
} else {
proc ase_test_hold_run_cmd {state deckpath} { return [list sleep 30 2>@1] }
ase::register_backend holdsim [dict create \
  render_deck  [ase::backend_hook ngspice render_deck] \
  run_cmd      ase_test_hold_run_cmd \
  log_file     [ase::backend_hook ngspice log_file] \
  result_probe [ase::backend_hook ngspice result_probe] \
  raw_file     [ase::backend_hook ngspice raw_file]]

# Its OWN rundir, for E2b's reason: the ngspice log_file/raw_file hooks are
# <rundir>/<cell>_ase.*, so sharing E1's rundir would put these rows on top of
# that leg's evidence. The circuit netlist is N1's real artifact, copied in --
# every row here drives ase::run_deck (the shared post-netlist body and the
# authority), so none of them needs the design to be the current schematic.
set rg1dir [file normalize [file join $scratch run_rg1]]
file mkdir $rg1dir
set rg1nl [file join $rg1dir nfet_clean.spice]
file copy -force -- [file join $rundir nfet_clean.spice] $rg1nl
set rg1st  [nfet_state $models $rg1dir]
dict set rg1st simulator holdsim
set rg1raw  [file join $rg1dir nfet_clean_ase.raw]
set rg1deck [file join $rg1dir nfet_clean_ase.spice]
set rg1key  [ase::run_lock_key $rg1st]

# --- RG1: the ordinary launch, and what it claims ---------------------------
# THE POSITIVE HALF OF THE WHOLE SECTION. One `execute`, a real id, and a lock
# keyed on the RAW PATH this run is about to write -- not on the session and
# not on the widget, because two ASE-L sessions on one cellview and a
# `Netlist and Run` racing a `Run` are the same hazard as a double-click.
set rg1 [rg_execs {set ::rg1id [ase::run_deck $::rg1st $::rg1nl]}]
check "RG1 an ordinary launch starts exactly one simulator and claims the results file it is about to write" \
  [list [lindex $rg1 0] [lindex $rg1 1] \
        [expr {[string is integer -strict $::rg1id] ? 1 : 0}] \
        [ase::run_in_flight $rg1key] \
        [expr {$rg1key eq [file normalize $rg1raw] ? 1 : 0}]] \
  [list 1 0 1 $::rg1id 1]

# The live run's two artifacts, as they stand now. `sleep` writes no results
# file, so one is planted here: the point of RG3 is that a refusal does not
# DELETE it, and run_deck's `file delete` of the raw is three lines below the
# gate.
rg_wr $rg1raw "ZZRG3 RESULTS-FILE SENTINEL\n"
set rg1deckbytes [e_slurp $rg1deck]
set rg1rawbytes  [e_slurp $rg1raw]

# --- RG2: the second launch is REFUSED, and nothing was started -------------
set rg2 [rg_execs {set ::rg2rc [catch {ase::run_deck $::rg1st $::rg1nl} ::rg2err]}]
check "RG2 a second launch against a live results file is refused, and NO simulator is started" \
  [list [lindex $rg2 0] $::rg2rc \
        [expr {[string match {*already running*} $::rg2err] ? 1 : 0}]] \
  {0 1 1}

# --- RG3: and it did not touch the live run's artifacts ---------------------
# This is why the gate is at the TOP of ase::run_deck and not "just before
# `eval execute`" as the plan asked for: on its way down run_deck DELETES THE
# RAW and rewrites the deck, so a refusal taken after those two lines would
# destroy the running run's results file -- issue 0929's own symptom,
# manufactured by the fix written for it.
check "RG3 the refusal leaves the live run's deck and results file exactly as they were" \
  [list [file isfile $rg1deck] [e_slurp $rg1deck] \
        [file isfile $rg1raw]  [e_slurp $rg1raw]] \
  [list 1 $rg1deckbytes 1 $rg1rawbytes]

# --- RG4: the refusal reaches the CIW channel -------------------------------
set rg4 [rg_ciw {catch {ase::run_deck $::rg1st $::rg1nl}}]
set rg4busy {}
foreach _p $rg4 { if {[string match {*already running*} [lindex $_p 1]]} { lappend rg4busy $_p } }
check "RG4 the refusal arrives in the CIW, once, and as a note rather than an error" \
  [list [llength $rg4busy] [lindex [lindex $rg4busy 0] 0]] \
  {1 note}

# --- RG5: it names the way out, read from 1391's constant -------------------
# The constant AND a literal golden, which is what stops a
# constant-compared-to-constant tautology. Rename the Stop entry and the
# sentence follows it (the menubar is built from the same proc) while this
# row's golden half reds -- which is exactly the review a rename deserves.
# The fourth element is the anti-drift claim: the sentence's builder must not
# contain a retyped copy of the menu path.
set rg5msg [ase::run_busy_msg $rg1key]
set rg5stop NOPROC
catch {set rg5stop [ase::ui::menu_path_stop]}
check "RG5 the refusal names Simulation > Stop by READING 1391's constant, never by retyping it" \
  [list [rg_has $rg5msg $rg5stop] $rg5stop \
        [rg_has $rg5msg [file tail $rg1key]] \
        [rg_has [rg_body ase::run_busy_msg] {Simulation > Stop}]] \
  [list 1 {Simulation > Stop} 1 0]

# --- RG6: RAISED, NOT FOCUSED ----------------------------------------------
# The user's own emphasis, and the place this item first got it WRONG. The plan
# said to use `raise_toplevel`, on the grounds that its sibling
# raise_activate_toplevel is the one that adds `xschem activate_window`. Both
# ACTIVATE: raise_toplevel's mapped arm is withdraw+deiconify and a re-map is an
# activation. Measured 2026-09-08 against a real `.ciw` and a second toplevel
# holding the keyboard -- :99/openbox, :0/Xwayland and the developer's own
# Windows X server (no EWMH WM at all) -- a plain `raise` is the ONLY thing that
# rises without taking the keyboard, and it is issue 0054's measured no-op on
# two of those three. Hence: plain raise, verify, re-map only if it did nothing.
#
# So the structural row below asserts the ORDER, not a helper name, and the
# behavioural leg measures the PROPERTY -- where the CIW ended up and where the
# keyboard is -- because a row that spies which proc was called could not see
# this defect and did not.
set rg6b [rg_body ase::run_ciw_raise]
check "RG6 the refusal tries the focus-free raise first and keeps raise_toplevel as the fallback, never the activating sibling" \
  [list [rg_has $rg6b {raise .ciw}] [rg_has $rg6b {wm stackorder .ciw isabove}] \
        [rg_has $rg6b raise_toplevel] [rg_has $rg6b raise_activate_toplevel] \
        [rg_has $rg6b activate_window] \
        [expr {[string first {raise .ciw} $rg6b] < [string first {raise_toplevel} $rg6b] ? 1 : 0}]] \
  {1 1 1 0 0 1}
if {[info exists ::has_x] && [info commands winfo] ne {}} {
  # BEHAVIOURAL, AND IT MEASURES THE THING THE USER ASKED FOR. `.ciw` does not
  # exist under --nolog, so a real pane and a stand-in for the ASE-L window are
  # stood up here; the keyboard starts in the stand-in, the refusal runs, and
  # the row reads BOTH where the CIW ended up and whether the keyboard moved.
  #
  # ⚠ THE STRONG ARM IS GATED ON A PROBE, NOT ON A DISPLAY NAME. Two of the
  # three X servers here ignore a plain raise outright (issue 0054), and on
  # those the CIW can only be brought forward by a re-map, which takes the
  # keyboard -- a platform limit this suite must not red over. So the probe
  # below asks THIS server whether a plain raise moves anything at all, and the
  # keyboard half is asserted only where it can be honoured. On :99, where the
  # suites run, the probe answers yes and the strong arm is what executes.
  catch {destroy .ciw} ; catch {destroy .rg6prb1} ; catch {destroy .rg6prb2}
  toplevel .rg6prb1 ; toplevel .rg6prb2
  wm geometry .rg6prb1 200x80+10+10 ; wm geometry .rg6prb2 200x80+10+120
  update ; raise .rg6prb2 ; update ; raise .rg6prb1 ; update
  set rg6plainraise 0
  catch {set rg6plainraise [wm stackorder .rg6prb1 isabove .rg6prb2]}
  destroy .rg6prb1 ; destroy .rg6prb2
  note "RG6 does this X server honour a plain raise?" $rg6plainraise

  toplevel .ciw ; wm geometry .ciw 300x120+10+10
  toplevel .rg6ase ; wm geometry .rg6ase 300x120+10+200
  entry .rg6ase.e ; pack .rg6ase.e
  update ; focus -force .rg6ase.e ; update
  set rg6focus0 [focus]
  catch {ase::run_deck $rg1st $rg1nl}
  update
  set rg6above 0
  catch {set rg6above [wm stackorder .ciw isabove .rg6ase]}
  set rg6focus1 [focus]
  catch {destroy .ciw} ; catch {destroy .rg6ase}
  if {$rg6plainraise} {
    check "RG6 GUI the refusal puts the CIW in front of the ASE-L window and leaves the keyboard where it was" \
      [list $rg6above [expr {$rg6focus1 eq $rg6focus0 ? 1 : 0}]] {1 1}
  } else {
    # 0054's server. The CIW must still come forward; the keyboard is the
    # platform's, not ours, and ase::run_ciw_raise's header records why.
    check "RG6 GUI the refusal puts the CIW in front of the ASE-L window (this server ignores a plain raise, so the keyboard is not ours to keep)" \
      $rg6above 1
  }
} else {
  puts "gui leg skipped (no DISPLAY): RG6 behavioural raise"
}

# --- RG7: two different results files do not block each other ---------------
# The same cell in a SECOND run directory -- two ASE-L sessions on one cellview
# is the shape a session-keyed lock gets wrong in the other direction. Both
# locks stand at once and neither refuses.
set rg7dir [file normalize [file join $scratch run_rg7]]
file mkdir $rg7dir
set rg7nl [file join $rg7dir nfet_clean.spice]
file copy -force -- $rg1nl $rg7nl
set rg7st  [nfet_state $models $rg7dir]
dict set rg7st simulator holdsim
set rg7key [ase::run_lock_key $rg7st]
set rg7 [rg_execs {set ::rg7id [ase::run_deck $::rg7st $::rg7nl]}]
check "RG7 a run on a DIFFERENT results file is not blocked, and both locks stand at once" \
  [list [lindex $rg7 0] [lindex $rg7 1] \
        [expr {$rg7key ne $rg1key ? 1 : 0}] \
        [ase::run_in_flight $rg7key] [ase::run_in_flight $rg1key]] \
  [list 1 0 1 $::rg7id $::rg1id]

# --- RG8: a launch that never launched leaves no lock -----------------------
# `fakesim` (E2's missing-binary backend) makes `execute` return -1. Locking
# before that check would brick Run for the whole session every time a user
# mistyped a simulator path: nothing would ever clear a lock whose ase::run_done
# can never fire.
set rg8dir [file normalize [file join $scratch run_rg8]]
file mkdir $rg8dir
set rg8nl [file join $rg8dir nfet_clean.spice]
file copy -force -- $rg1nl $rg8nl
set rg8st  [nfet_state $models $rg8dir]
dict set rg8st simulator fakesim
set rg8key [ase::run_lock_key $rg8st]
ase_no_modal {set rg8rc [catch {ase::run_deck $rg8st $rg8nl} rg8err]}
check "RG8 a launch that failed to start leaves no lock behind" \
  [list $rg8rc [expr {[string match {ase:*} $rg8err] ? 1 : 0}] \
        [rg_tabled $rg8key] [ase::run_in_flight $rg8key]] \
  {1 1 0 {}}

# --- RG9: a stale lock does not refuse, and is dropped ----------------------
# `::execute(pipe,$id)` is unset by execute_fileevent at EOF, so its absence
# means the run is over however it ended. Without this arm one crashed
# completion bricks Run for the rest of the session -- worse than the defect
# being fixed.
set rg9key [file normalize [file join $scratch run_rg9 zz_ase.raw]]
set rg9id 999731
catch {unset ::execute(pipe,$rg9id)}
ase::run_lock_set $rg9key $rg9id
check "RG9 a lock whose process is gone answers 'not in flight' and is dropped from the table" \
  [list [rg_tabled $rg9key] [ase::run_in_flight $rg9key] [rg_tabled $rg9key]] \
  {1 {} 0}

# --- RG10: the ordinary completion clears it, in ase::run_done --------------
# rg_tabled, not run_in_flight: the sweep DROPS a dead lock as it answers, so
# only a direct look at the table can tell "ase::run_done released it" from
# "nobody has asked yet". A run_done that stopped clearing would leave a 1 here
# and every other row in this section would stay green.
set rg10 [rg_reap $::rg7id]
check "RG10 a finished run releases its results file in ase::run_done, not by the stale-lock sweep" \
  [list $rg10 [rg_tabled $rg7key]] {reaped 0}

# --- RG11: Stop is a real way out, and the next launch is allowed -----------
# The sentence tells the user to press Simulation > Stop. This is that door
# (ase::ui::do_stop's own `kill_running_cmds <id> -9`), followed by the launch
# it unblocks.
set rg11a [rg_reap $::rg1id]
set rg11 [rg_execs {set ::rg11id [ase::run_deck $::rg1st $::rg1nl]}]
check "RG11 after Stop the results file is free and the next launch really starts" \
  [list $rg11a [lindex $rg11 0] [lindex $rg11 1] \
        [ase::run_in_flight $rg1key]] \
  [list reaped 1 0 $::rg11id]

# --- RG12: the ASE-L doors ---------------------------------------------------
# Both doors call `ase::ui::set_status $key fail` on any raise out of ase::run,
# and a refused second launch has nothing wrong with it: the first run is alive
# and the status must go on saying Running. `Netlist and Run` would also have
# deleted and rebuilt the circuit netlist before the authority ever saw the
# launch, so the sentinel below is what proves the door refused FIRST.
set rg12path [file join $scratch rg_door.state]
ase::state_save $rg12path $rg1st
set rg12key [ase::session_key aselib nfet_clean schematic]
ase::session_open $rg12key $rg12path
rg_wr $rg1nl "ZZRG12 CIRCUIT NETLIST SENTINEL\n"
set ::rg12status {}
rename ::ase::ui::set_status ::rg12_saved_status
proc ::ase::ui::set_status {key what} { lappend ::rg12status $what }
set rg12a [rg_execs {ase::ui::do_run_existing $::rg12key}]
set rg12b [rg_execs {ase::ui::do_run $::rg12key}]
rename ::ase::ui::set_status {}
rename ::rg12_saved_status ::ase::ui::set_status
check "RG12 both ASE-L doors refuse without starting a simulator, without reddening a healthy session and without re-netlisting" \
  [list [lindex $rg12a 0] [lindex $rg12b 0] $::rg12status \
        [e_slurp $rg1nl] [ase::run_in_flight $rg1key]] \
  [list 0 0 {} "ZZRG12 CIRCUIT NETLIST SENTINEL\n" $::rg11id]

# --- RG13: the way out the sentence names is a way out FOR THE READER --------
# The refusal tells the user to press `Simulation > Stop`. Measured 2026-09-08,
# before this row existed, that was FALSE in exactly the cases the raw-path key
# was chosen for: ase::ui::do_stop was keyed on the session's `run_id` attr, and
# only the session that launched holds one. Two ASE-L sessions on one cellview
# share a rundir, a results file and therefore the lock -- but B is refused,
# told to press Stop, and B's Stop answered "no simulation running for this
# session" over a run that was alive. The user could neither run nor stop.
#
# $rg11id was started by ase::run_deck directly, so NO session holds its run_id;
# that is also the CIW/script door the issue says the authority covers, and the
# close-and-reopen shape (ase::session_close drops every attr) in one.
check "RG13 the session holds no run_id for this run, so only the lock can answer" \
  [list [ase::session_getattr $rg12key run_id {}] [ase::run_in_flight $rg1key]] \
  [list {} $::rg11id]
set rg13said [rg_ciw {ase::ui::do_stop $rg12key}]
catch {ase::wait $::rg11id}
## ⚠ THE EMPTY CIW HERE IS NOW AN ASSERTION, NOT AN ABSENCE (Stage 2e).
## A successful Stop DOES say what it cost -- but the sentence's clause comes
## from the BACKEND (ase::run_stop_cost), and this fixture's simulator is
## `holdsim`, which is not a registered backend at all. So ASE-L says nothing,
## because "what a stop costs" is a run-model fact core does not know for a
## simulator it was never told about, and a guessed warning is worse than
## silence. MEASURED: the same call with the real backend in force returns
## `ase: simulation stopped — nothing of this run was written` (row SW2), and
## row SW7 pins that `holdsim` specifically yields nothing. Change the fixture's
## simulator and this element MUST become that sentence.
check "RG13 Stop from a session that did not launch really kills the run and frees the results file" \
  [list $rg13said [ase::run_in_flight $rg1key] \
        [expr {[info exists ::execute(pipe,$::rg11id)] ? 0 : 1}] [rg_tabled $rg1key]] \
  [list {} {} 1 0]
## and the honest sentence survives: with nothing running, Stop still says so.
check "RG13 with nothing running Stop still says there is nothing to stop" \
  [rg_ciw {ase::ui::do_stop $rg12key}] \
  {{{} {ase: no simulation running for this session}}}

# --- SW: THE STOP WARNING (analyses batch Stage 2e) --------------------------
# ⚠ WHAT WAS TRUE AND UNSAID. Both Stop doors call ase::ui::do_stop ->
# `kill_running_cmds $id -9`. ngspice in batch installs a handler for NO SIGNAL
# AT ALL -- main.c puts the whole block inside `if (!ft_batchmode)`, and SIGTERM,
# SIGHUP and SIGQUIT are installed in no mode -- so the process dies at the
# default disposition in a few milliseconds and nothing of the analysis in
# flight is on disk. The window said none of that.
#
# ⚠ ASE-L OWNS THE FRAME; THE ADAPTER OWNS THE CLAUSE. Stage 1's Xyce
# paper-validation caught this item's own plan text asserting "ngspice in batch
# mode writes nothing on a stop" in ASE-L's voice -- a RUN-MODEL fact about one
# simulator, in the half that may hold none (D34-D37). The clause now comes from
# the `run_stop_cost` backend hook, and A BACKEND THAT DECLARES NONE GETS NO
# SENTENCE: core does not know what a stop costs on a simulator it was never
# told about, and a guessed warning is worse than silence. SW3/SW3b are that
# half, and they are the non-vacuity rows.
#
# ⚠ BOTH SENTENCES ARE THE USER'S TO RATIFY (⚖ R9) -- filed as a rule debt the
# moment they landed, not ratified by their appearing here.
check "SW1 the launch warning is ASE-L's frame around the backend's clause" \
  [ase::run_stop_warning] \
  {Stopping this run discards it — ngspice in batch mode writes nothing on a stop.}
check "SW2 the moment-of-the-Stop sentence likewise" \
  [ase::run_stopped_msg] \
  {ase: simulation stopped — nothing of this run was written}
check "SW3 a backend with no run_stop_cost hook gets NO launch warning" \
  [ase::run_stop_warning someoneelsesim] {}
check "SW3b ... and no stopped sentence either" \
  [ase::run_stopped_msg someoneelsesim] {}
# The log header carries it, and EMPTY WRITES NOTHING -- the same discipline
# `using` and `casenote` already follow, so a backend with no hook produces a
# header byte-identical to 0618's committed framing.
set sw_meta [dict create cell nfet_clean simulator ngspice started 0 \
                         cmd {ngspice -b x.spice} dir /tmp deck x.spice]
set sw_hdr [ase::run_log_header $sw_meta]
check "SW4 the run log header carries the stop warning" \
  [expr {[string first "stop      : Stopping this run discards it" $sw_hdr] >= 0}] 1
set sw_hdr2 [ase::run_log_header [dict replace $sw_meta simulator someoneelsesim]]
check "SW5 a backend with no hook adds NO stop line to the header" \
  [expr {[string first "stop      :" $sw_hdr2] >= 0}] 0
# The hook is OPTIONAL, exactly like capabilities/op_param_set: registering a
# backend without it must still succeed (row A3 of test_ase_simcaps_0948 pins
# that only five hooks are required).
## ⚠ SW7 IS WHY RG13's CIW IS EMPTY, and it is the row that stops that emptiness
## being mistaken for the warning having silently stopped working. `holdsim` is
## RG12/RG13's fixture simulator and is not a registered backend.
check "SW7 the RG fixture's `holdsim` yields no stop sentence, which is why RG13 is silent" \
  [list [ase::run_stopped_msg holdsim] [ase::run_stop_warning holdsim]] {{} {}}
check "SW6 run_stop_cost is an OPTIONAL hook, not a sixth required one" \
  [catch {ase::register_backend sw6sim [dict create \
     render_deck x run_cmd x log_file x result_probe x raw_file x]}] 0

# --- RG14: a refusal that arrives as a RAISE must not redden a healthy run ---
# The door pre-checks are not the whole story, and the gap is the originating
# gesture. ase::ui::do_run calls `update` inside its design-window routing arm,
# so a second press queued as an X event dispatches BETWEEN that door's
# run_busy check and its launch: the inner press passes the check, launches and
# locks, and the outer press then meets the lock inside ase::run_deck. Measured
# 2026-09-08 with the second press queued as a real `event generate -when tail`:
# one simulator started (the guard's core job held) but the status segment went
# `running` -> `fail`, a red Error over a live and healthy run, and the same
# sentence reached the CIW TWICE -- once as `note`, once as `error`, which is
# also the opposite of the note-not-error decision this refusal was built on.
#
# The rows are deterministic rather than a re-raced gesture, per CLAUDE.md's own
# rule that a bug only one environment can reproduce is a test defect too: the
# refusal text below is the AUTHORITY's own, taken from a real refused
# ase::run_deck, so this cannot pass against a hand-typed sentence that has
# drifted from the one the gate raises.
## RG12 replaced the circuit netlist with its sentinel (that was its point);
## put the real one back, or the preflight refuses before the gate is reached.
file copy -force -- [file join $rundir nfet_clean.spice] $rg1nl
set rg14id [ase::run_deck $rg1st $rg1nl]
set rg14err {}
catch {ase::run_deck $rg1st $rg1nl} rg14err
set ::rg14status {}
rename ::ase::ui::set_status ::rg14_saved_status
proc ::ase::ui::set_status {key what} { lappend ::rg14status $what }
set rg14a [rg_ciw {set ::rg14rc [ase::ui::run_raised $rg12key $rg14err]}]
set rg14statusA $::rg14status
set ::rg14status {}
set rg14b [rg_ciw {set ::rg14rc2 [ase::ui::run_raised $rg12key {ase: cannot start simulator 'nosuch'}]}]
set rg14statusB $::rg14status
rename ::ase::ui::set_status {}
rename ::rg14_saved_status ::ase::ui::set_status
check "RG14 a raise that IS the refusal is neither said twice nor allowed to redden a live run" \
  [list $rg14a $rg14statusA $::rg14rc] [list {} {} 0]
check "RG14 and an ordinary failure still reddens and still speaks (non-vacuity)" \
  [list $rg14b $rg14statusB $::rg14rc2] \
  [list {{error {ase: cannot start simulator 'nosuch'}}} fail 1]
## the wiring: neither door may re-inline the redden it just stopped doing.
set rg14dr  [rg_body ase::ui::do_run]
set rg14dre [rg_body ase::ui::do_run_existing]
check "RG14 both doors route a raise out of ase::run through the one arm that can tell a refusal from a failure" \
  [list [rg_has $rg14dr {ase::ui::run_raised $key $id}] \
        [rg_has $rg14dre {ase::ui::run_raised $key $id}]] {1 1}
rg_reap $rg14id

catch {ase::session_close $rg12key}
rg_reap $::rg11id
}


# ============================================================================
# NT -- ISSUE 0650: `xschem::notify`, THE ONE NOTIFICATION CHANNEL
# ============================================================================
# Measured 2026-08-23 on the user's own configuration: with the CIW closed, a
# gate-off netlist reaches ZERO visible sinks. `ase::echo` (src/ase.tcl:134) has
# exactly two -- `::ciw_echo` and `xschem log_action` -- and the GUI half of the
# measurement recorded `.statusbar.12` = {} before AND after the notice,
# `.statusbar.1` unchanged, no popup raised, and the only surviving trace one
# `#! ` line in a log file nobody was reading. That is issue 0648's report from
# the outside: "I re-ran the sim and still don't get OP info", with no mention
# of any message, because there was none to mention.
#
# ⚠ 0650's AND 0653's OWN MECHANISM SENTENCE IS FALSE, and PS17 in
# tests/headless/test_ase_log_seam_0207.tcl pins the refutation. 0650's sink
# table says `ciw_echo` "No-ops silently when shut (src/ciw.tcl:120-121)";
# 0653 says "The CIW is a closable toplevel. Closed -> silent no-op." Measured:
# src/ciw.tcl:53 is `wm protocol .ciw WM_DELETE_WINDOW {wm withdraw .ciw}`, so
# after a close `.ciw` and `.ciw.l.t` still EXIST, `ismapped` is 0, and ciw_echo
# happily writes into the invisible widget. A `winfo exists` predicate would
# make the whole fallback sink dead code in EXACTLY the user's situation, and it
# would pass review. The predicate is `winfo ismapped`.
#
# These rows are the HEADLESS half of the channel: ONE builder (invariant I1),
# the call-time style read (invariant I5), the one-::ciw_echo-per-notice budget
# that the exact-count assertions in test_ase_locked_wire_pick_0160:126 and
# test_sod_pick_no_select_0204:138 depend on, the load-bearing empty-message
# blank line, the remedy fields carried as DISTINCT fields (R-0653-d), the
# 28-character short-form budget, and the generalised state-keyed suppression
# latch (R-0653-c). The Tk halves -- the `.statusbar.12` fallback and the opt-in
# popup -- are PS14-PS19 in test_ase_log_seam_0207.tcl, because no --nolog
# suite has a statusbar or a CIW to witness them with.

## Same shape as test_ase_final's `cx`: a raise becomes a value, so one missing
## proc reddens one row instead of aborting every row after it.
proc nt_cx {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR: $r" }
  return $r
}

## One field of the ::xschem::notify_last witness, with a SPEAKING placeholder
## when the witness (or the key) is absent -- a bare `dict get` on a missing
## variable reports "dict element in quotes ...", which names the wrong defect.
proc nt_field {k} {
  if {![info exists ::xschem::notify_last]} { return NO-notify_last }
  if {[catch {dict get $::xschem::notify_last $k} v]} { return NO-KEY-$k }
  return $v
}

## Collect every ::ciw_echo call a body makes, as {line tag} pairs. Restores
## ::ciw_echo on EVERY exit path including a raising body (f_nudges' engine in
## test_ase_final.tcl). A body that raises returns {ERR <message>} -- llength 2,
## never llength 1 -- so a missing channel can never look like a single notice.
proc nt_capture {body} {
  set ::nt_echo {}
  set saved 0
  if {[info commands ::ciw_echo] ne {}} {
    rename ::ciw_echo ::nt_saved_ciw_echo ; set saved 1
  }
  proc ::ciw_echo {line {tag {}}} { lappend ::nt_echo [list $line $tag] }
  set rc [catch {uplevel 1 $body} e]
  catch {rename ::ciw_echo {}}
  if {$saved} { catch {rename ::nt_saved_ciw_echo ::ciw_echo} }
  if {$rc} { return [list ERR $e] }
  return $::nt_echo
}

## Spy on the two STYLE-SELECTED sinks, so "which sink did this notice pick"
## is observable with no Tk at all. Installs NOTHING when the real proc is
## absent -- in particular it never creates the ::xschem namespace, or NT0
## would be asserting its own side effect.
proc nt_spy_sinks {} {
  set ::nt_spy_popup {} ; set ::nt_spy_sbar {}
  set ::nt_had_popup 0  ; set ::nt_had_sbar 0
  if {[info commands ::xschem::notify_popup] ne {}} {
    rename ::xschem::notify_popup ::xschem::notify_popup_ntsaved
    set ::nt_had_popup 1
    proc ::xschem::notify_popup {args} { lappend ::nt_spy_popup $args ; return 0 }
  }
  if {[info commands ::xschem::notify_statusbar] ne {}} {
    rename ::xschem::notify_statusbar ::xschem::notify_statusbar_ntsaved
    set ::nt_had_sbar 1
    proc ::xschem::notify_statusbar {args} { lappend ::nt_spy_sbar $args ; return 0 }
  }
}
proc nt_unspy_sinks {} {
  if {$::nt_had_popup} {
    catch {rename ::xschem::notify_popup {}}
    catch {rename ::xschem::notify_popup_ntsaved ::xschem::notify_popup}
  }
  if {$::nt_had_sbar} {
    catch {rename ::xschem::notify_statusbar {}}
    catch {rename ::xschem::notify_statusbar_ntsaved ::xschem::notify_statusbar}
  }
}

# ⚠ SAMPLED FIRST, BEFORE ANY ROW BELOW TOUCHES EITHER. NT3 assigns
# ::notify_style and nt_spy_sinks can create procs inside ::xschem; a row that
# reads them afterwards would be asserting its own assignment (the F19d idiom
# in test_ase_final.tcl).
set nt_ns_before    [namespace exists ::xschem]
set nt_style_before [expr {[info exists ::notify_style] ? $::notify_style : {NO-VAR}}]

# --- NT0: the command and the namespace must coexist -------------------------
# `xschem` is a Tcl COMMAND created in C (Tcl_CreateCommand, src/xinit.c) and
# the channel is named `xschem::notify`, i.e. a NAMESPACE of the same name.
# They do coexist (measured in a standalone tclsh), but the dispatcher is the
# whole product's front door -- if naming the namespace ever shadowed it, every
# suite in this directory would die at once, so pin it here where the failure
# is one line instead of 300.
check "NT0 0650 the ::xschem NAMESPACE and the `xschem` COMMAND coexist" \
  [list $nt_ns_before [nt_cx {xschem get top_path}] \
        [expr {[nt_cx {xschem get schname}] ne {} ? 1 : 0}]] \
  {1 {} 1}

# --- NT1: ONE builder, and every named callee a sabotage must be able to hit --
# Invariant I1. Each sink and each policy fragment is a NAMED proc so a
# sabotage leg can neutralize exactly one of them (SAB-N1/N2/N3/N4/N5/N8) and
# see exactly which rows notice.
#
# ⚠ ISSUE 0658 EXTENDED THIS LIST BY FOUR, and the four live in a DIFFERENT
# FILE on purpose (src/xschem.tcl, sourced before every caller) -- see the
# NT16-NT21 and NTD1-NTD7 block below. `notify_bootstrap` is the degraded
# channel, `notify_safe` the ONE delegate body behind ase::echo and
# wviewer::echo, `notify_log` the ONE durable-log writer both the full channel
# and the bootstrap consume (invariant I1: extracting it is what keeps the
# bootstrap from being a second copy of ciw.tcl's sink 2), and
# `notify_degraded_once` the one-time degraded-state announcement.
#
# ⚠ ISSUES 0664/0665 ADD THREE MORE, and they are the whole of that fix's
# mechanism -- see the NT22-NT29 block below. `notify_mark` and
# `notify_mark_reset` are the ONE appender and the ONE reset of the sinks-fired
# record (`::xschem::notify_progress`, a NAMESPACE variable, so it survives the
# unwind that a raise inside the channel causes), and
# `notify_channel_degraded` is the MEASUREMENT that turns the degradation
# announcement from a hard-coded claim into a fact. Renaming or removing any of
# them reddens this row; adding a proc never does.
set nt1_missing {}
foreach p {::xschem::notify ::xschem::notify_ciw_visible ::xschem::notify_statusbar
           ::xschem::notify_popup ::xschem::notify_short ::xschem::notify_record
           ::xschem::notify_latch_ok ::xschem::notify_latch_rearm
           ::xschem::notify_latch_reset
           ::xschem::notify_bootstrap ::xschem::notify_safe
           ::xschem::notify_log ::xschem::notify_degraded_once
           ::xschem::notify_mark ::xschem::notify_mark_reset
           ::xschem::notify_channel_degraded} {
  if {[info commands $p] eq {}} { lappend nt1_missing $p }
}
check "NT1 0650+0658+0665 xschem::notify and every named callee exist" $nt1_missing {}

# --- NT2: R-0653-a, the ruled default ----------------------------------------
# `set ::notify_style {ciw|popup}`, default `ciw`. The `set_ne` idiom
# (ase.tcl:185's ::ase_op_card_nudge, ase.tcl:177's ::ase_eng_notation) so a
# user rc that set it BEFORE this file was sourced still wins.
check "NT2 0653 R-0653-a ::notify_style defaults to `ciw` at source time" \
  $nt_style_before ciw

# --- NT3: invariant I5 -- the style is read at CALL time, not cached ----------
# "A user's register in their own rc overrides the PDK's, and takes effect on
# redraw -- no restart, no rebuild." The same rule for the same reason here: an
# rc is sourced BEFORE ciw.tcl (src/xschem.tcl:14599 note), but a user may also
# set it from the CIW entry field mid-session and must not have to restart.
nt_spy_sinks
nt_capture {::xschem::notify {NT3 style probe A}}
set nt3_popup_ciw [llength $::nt_spy_popup]
set ::notify_style popup
set ::nt_spy_popup {}
nt_capture {::xschem::notify {NT3 style probe B}}
set nt3_popup_popup [llength $::nt_spy_popup]
set ::notify_style ciw
nt_unspy_sinks
check "NT3 0653 I5 the style is read at CALL time: setting ::notify_style popup\
 after the proc was defined selects the popup sink on the very next notice" \
  [list $nt3_popup_ciw $nt3_popup_popup] {0 1}

# --- NT4: THE NOTICE BUDGET -- one notify, exactly one ::ciw_echo ------------
# ⚠ LOAD-BEARING FOR TWO OTHER SUITES. test_ase_locked_wire_pick_0160:126 and
# test_sod_pick_no_select_0204:138/295 assert `llength $::notices == 1`, and
# 0204:313 asserts an EMPTY list. A notify that emits a short form AND a long
# form to the pane, or that tees inside ciw_echo, reddens both of them from a
# distance. Golden pair, not a count: the pane copy is byte-identical to the
# argument and the default tag is empty.
check "NT4 0650 ONE xschem::notify produces EXACTLY ONE ::ciw_echo call, with the\
 message byte-identical" \
  [nt_capture {::xschem::notify {NT4 one line only}}] \
  [list [list {NT4 one line only} {}]]

# --- NT5: the empty-message blank line is a CONTRACT, not an accident --------
# ase.tcl:135-137 says so in the source, and PS10 in test_ase_log_seam_0207
# pins the other half (an empty message logs NOTHING -- the landmine where
# `xschem log_action -result` with a missing value wrote the literal line
# `-result` and aborted a replay `source`). A notify that filters empties
# before the pane changes shipped behaviour.
check "NT5 0650 xschem::notify {} still echoes ONE blank pane line" \
  [nt_capture {::xschem::notify {}}] [list [list {} {}]]

# --- NT6: the trailing-backslash pad is on the LOGGED copy ONLY --------------
# PS12's rule, moved with the builder: `#= foo\` swallows the FOLLOWING log
# line on replay, so the logged copy gets a pad -- and the PANE copy must stay
# byte-identical to the argument, which is what this row owns. (The log half
# needs a real --logdir; it lives in PS12/PS12d.)
check "NT6 0650 a trailing backslash is NOT padded in the pane copy" \
  [nt_capture {::xschem::notify "NT6 trailing backslash \\"}] \
  [list [list "NT6 trailing backslash \\" {}]]

# --- NT7: the tag routes both halves -----------------------------------------
check "NT7 0650 -tag error reaches ::ciw_echo tagged `error`; the default tag is {}" \
  [list [nt_capture {::xschem::notify {NT7 err} -tag error}] \
        [nt_capture {::xschem::notify {NT7 ok}}]] \
  [list [list [list {NT7 err} error]] [list [list {NT7 ok} {}]]]

# --- NT8: R-0653-d -- the remedy travels as FIELDS, not as prose -------------
# "The signature must carry them as distinct fields, not baked into the message
# string, or the tests cannot execute the command separately from rendering the
# text." So: the rendered line carries both (the user reads one sentence), and
# `msg`, `menu` and `command` stay separable in the witness (a test executes the
# command without parsing the sentence -- F19p does exactly that).
set nt8_menu {Outputs > Save All… > Save device OP parameters}
set nt8_cmd  {ase::ui::save_op_params_on {lib/cell/view}}
nt_capture [list ::xschem::notify {NT8 the gate is off} -menu $nt8_menu -command $nt8_cmd]
set nt8_line [nt_field line]
check "NT8 0653 R-0653-d -menu and -command are DISTINCT fields in\
 ::xschem::notify_last, and the rendered line carries both" \
  [list [nt_field msg] [nt_field menu] [nt_field command] \
        [expr {[string first $nt8_menu $nt8_line] >= 0 ? 1 : 0}] \
        [expr {[string first $nt8_cmd  $nt8_line] >= 0 ? 1 : 0}]] \
  [list {NT8 the gate is off} $nt8_menu $nt8_cmd 1 1]

# --- NT9: the short-form budget, ONE builder ---------------------------------
# ⚠ `.statusbar.12` CLIPS SILENTLY. Measured twice on this box at
# `wm geometry . 1000x800` with a live mouse readout in `.statusbar.1`: the
# widget gets 199px / first clip at char 30, and 314px / first clip at char 42,
# depending on what else is in the bar. Tk warns about nothing. 28 is the floor
# of the two measurements; the wall itself is recorded as issue 0654. This is
# issue 0639's defect class (an unbudgeted line into a fixed field) in a field
# an order of magnitude smaller, so the budget gets ONE builder and a row of
# its own rather than living inside the sink (invariant I1).
set nt9_short [nt_cx {::xschem::notify_short {} [string repeat x 300]}]
check "NT9 0654 notify_short caps a 300-char message at exactly 28 chars ending `...`" \
  [list [string length $nt9_short] [string range $nt9_short end-2 end]] {28 ...}

# --- NT10: an explicit short form wins, and control characters are collapsed --
# A Tk label renders an embedded newline as a box glyph, not a line break.
check "NT10 0654 notify_short returns an explicit -short verbatim when it fits,\
 and collapses newlines/tabs to spaces" \
  [list [nt_cx {::xschem::notify_short {no OP save cards} \
                  {a much longer sentence that would be clipped}}] \
        [nt_cx {::xschem::notify_short {} "two\nlines\tover"}]] \
  {{no OP save cards} {two lines over}}

# --- NT11: R-0653-c generalised -- the latch is per (SUBJECT, STATE) ---------
# "Suppress an identical notice while the underlying state is unchanged; re-arm
# when it changes." 0648's latch (ase::op_cards_nudge_ok) is keyed on the design
# cellview; the ruling says GENERALISE it, do not write a second one, so the
# storage moves here and ase::op_cards_nudge_* become thin wrappers over subject
# `opcards` (F19/F19b/F19c/F19g/F19h/F19i/F19n in test_ase_final are the fence
# that proves the wrappers kept their semantics).
nt_cx {::xschem::notify_latch_reset A}
nt_cx {::xschem::notify_latch_reset B}
check "NT11 0653 R-0653-c the latch is keyed on (subject, STATE), not on subject\
 alone: take, hold, and a DIFFERENT state still speaks" \
  [list [nt_cx {::xschem::notify_latch_ok A k1}] \
        [nt_cx {::xschem::notify_latch_ok A k1}] \
        [nt_cx {::xschem::notify_latch_ok A k2}]] \
  {1 0 1}

# --- NT12: rearm gives back EXACTLY ONE turn; reset is per subject ------------
# An unconditional clear is 0636's three-identical-lines-per-session defect, and
# a reset that forgot to be subject-scoped would let one subsystem's re-arm free
# every other subsystem's held notice.
nt_cx {::xschem::notify_latch_ok B kb}
nt_cx {::xschem::notify_latch_rearm A k1}
set nt12a [list [nt_cx {::xschem::notify_latch_ok A k1}] \
                [nt_cx {::xschem::notify_latch_ok A k1}]]
nt_cx {::xschem::notify_latch_reset A}
set nt12b [list [nt_cx {::xschem::notify_latch_ok A k1}] \
                [nt_cx {::xschem::notify_latch_ok B kb}]]
check "NT12 0653 rearm gives back EXACTLY ONE turn, and reset frees ONE subject\
 (subject B's held key stays held)" [list $nt12a $nt12b] {{1 0} {1 0}}

# --- NT13: a SUPPRESSED notice reaches NO sink at all ------------------------
# Sub-decision D7, recorded because it contradicts 0650's sink table ("log:
# always"): suppression is TOTAL, the log included. That is byte-identical to
# shipped behaviour -- ase::op_cards_capture consults the latch BEFORE echoing
# anything at all -- and the alternative (a suppressed notice still logging)
# would make `grep` on Xschem.log disagree with what the user was told.
nt_cx {::xschem::notify_latch_reset opcards}
set nt13a [nt_capture {::xschem::notify {NT13 first} -once opcards -state {lib cell view}}]
set nt13b [nt_capture {::xschem::notify {NT13 second} -once opcards -state {lib cell view}}]
set nt13r [nt_cx {::xschem::notify {NT13 third} -once opcards -state {lib cell view}}]
check "NT13 0653 a suppressed -once/-state notice returns 0 and reaches NO sink" \
  [list $nt13a $nt13b $nt13r] [list [list [list {NT13 first} {}]] {} 0]

# --- NT14: headless safety -- no sink RAISES, no Tk-only sink is CLAIMED -----
# 0653: "Under --nogui there is no Tk; the log sink must still fire and no sink
# may raise. ciw_echo already guards on `info commands winfo`; the pop-up and
# statusbar sinks must too, or every headless suite dies at the first notice."
# The `sinks` field is what makes that assertable with no display: it lists the
# sinks a notice ACTUALLY reached, so "the statusbar was skipped" is a value
# rather than an absence of evidence.
# ARM-GATED (issue 0804). This row's premise is its own first word: with no Tk,
# a Tk-only sink must not be claimed. Under X the statusbar sink IS legitimately
# claimed and the row measures {0 1 0} -- correct behaviour, scored a failure.
# It was invisible until the 0698 bind let this suite reach line 1300 under X at
# all. SKIPPED rather than widened: an expectation that accepts the statusbar
# sink under X would be asserting something unmeasured about the notify channel,
# and that channel is mid-ruling (0674/0675/0677/0699/0800). A skip asserts
# nothing new and loses no headless coverage.
if {[info exists ::has_x]} {
  puts "SKIPPED: NT14 headless-only sink safety (a display is present; see 0804)"
} else {
  set nt14_rc [catch {::xschem::notify {NT14 headless safety}} nt14_err]
  set nt14_sinks [nt_field sinks]
  check "NT14 0650 headless: no sink raises, and neither Tk-only sink is claimed" \
    [list $nt14_rc \
          [nt_cx {expr {[lsearch -exact $nt14_sinks statusbar] >= 0 ? 1 : 0}}] \
          [nt_cx {expr {[lsearch -exact $nt14_sinks popup] >= 0 ? 1 : 0}}]] \
    {0 0 0}
}

# --- NT15: the REJECTED sink stays rejected ----------------------------------
# `.statusbar.1` via `xschem statusmsg`/`-hold` was the other candidate and is
# ruled out (decision D3): scheduler.c:53 DROPS an ordinary statusmsg while a
# hold is live, so a channel whose whole contract is "cannot go silent" would be
# silenceable by an unrelated gate message; and arming the 5 s hold ourselves
# would suppress the coordinate readout and every gate/prompt line after every
# ASE notice -- six times in one netlist. Non-vacuous: the notice really fired.
xschem statusmsg {NT15 SENTINEL}
set nt15_hold0 [xschem get statusmsg_hold]
set nt15_seen [nt_capture {::xschem::notify {NT15 a notice must not touch statusbar.1}}]
check "NT15 0650 a notice leaves `xschem get statusmsg` and statusmsg_hold\
 untouched (the rejected .statusbar.1 sink stays rejected)" \
  [list [llength $nt15_seen] [xschem get statusmsg] [xschem get statusmsg_hold]] \
  [list 1 {NT15 SENTINEL} $nt15_hold0]


# ============================================================================
# NT16-NT21 / NTD1-NTD7 -- ISSUE 0658: A MISSING CHANNEL MUST NOT SILENCE THE
# DURABLE LOG
# ============================================================================
# Measured at HEAD, twice independently, and the driver reproduced it a third
# time: with `rename ::xschem::notify ::v_saved_notify` in place, under
# `--nogui --pipe -q --logdir`,
#
#     CONTROL  ase::echo      rc=0 res=1 log 251->291
#     DEGRADED ase::echo      rc=0 res=0 log 330->330
#     DEGRADED wviewer::echo  rc=0 res=0 log 330->330
#
# Zero sinks, nothing raised, and the DURABLE LOG LINE -- the sink 0650's own
# table calls "the one that survives a shut window" -- was NOT written. Before
# 0650 that write was INLINE in ase::echo with no cross-file dependency, so this
# is a regression 0650 introduced. src/xschem.tcl sources op_annot (:14796),
# cmdmode, ase (:14802), ase_window, wave_viewer (:14806) and calculator BEFORE
# ciw.tcl (:14854), so the channel loads after every one of its callers and
# lives in the very file whose failure is the hazard.
#
# ⚠ AND 0658's OWN REACHABILITY SENTENCE WAS FALSE. It says "any Tcl error
# anywhere in src/ciw.tcl kills the whole file, and xschem.tcl continues past a
# failed source." Measured false, three ways (error at the top of ciw.tcl, error
# at the end, file absent): src/xschem.tcl:14854 is the ciw.tcl source line and
# it was a BARE `source`, so the raise propagated OUT of xschem.tcl,
# source_tcl_file() (src/xinit.c:1513) merely printed and returned, and
# Tcl_AppInit walked on into `tclgetdoublevar(cairo_font_line_spacing)` against
# unset variables. The process SIGSEGVed at startup -- exit 139, the 0423/0424
# signature -- and the bootstrap never got to speak. It was Tcl_AppInit that
# continued past a failed source of *xschem.tcl*, not xschem.tcl past a failed
# source of *ciw.tcl*.
#
# BOTH HALVES ARE NOW CLOSED, and NTD2 rests on the FIRST of them. Catching
# :14854 (0658) is what makes the degraded state real and reachable, so NTD2's
# headline assertion is "the child EXITS 0" and the bootstrap is what makes it
# survivable. Separately, issue 0663 fixed the CLASS in C: Tcl_AppInit now
# checks source_tcl_file()'s return and, for any of the other fifteen BARE
# sources, announces the failing file (one `STARTUP ABORTED: ...` line, stderr
# AND durable log) and exits 1 instead of walking on. `CHILDKILLED SIGSEGV` is
# therefore no longer reachable from a broken farm at all -- see
# tests/headless/test_startup_guard_0663.tcl, which owns that contract.
#
# THE CONTRACT THESE ROWS DEFINE (red-first; the implementation must match the
# names and the marker string, they are golden here):
#
#   ::xschem::notify_log {line tag}
#       THE ONE durable-log writer. ciw.tcl's sink 2 and the bootstrap both call
#       it -- extracting it is exactly what keeps the bootstrap from being a
#       second copy of the trimright / trailing-backslash pad / empty guard /
#       actionlog_filename block (invariant I1, and 0658's own rejected
#       alternative #1). Returns 1 only when the line reached an OPEN log.
#   ::xschem::notify_bootstrap {msg args}
#       the DELIBERATELY DEGRADED channel: -tag (and -cause) parsed, every other
#       option IGNORED and never a raise, ONE durable line, the honest sink count
#       returned. NO short form, NO 28-char clipping, NO statusbar, NO popup, NO
#       latch, NO remedy rendering -- NT19 fences all of that on the body.
#   ::xschem::notify_degraded_once {cause}
#       the one-time announcement, carrying the literal marker
#       `NOTICE CHANNEL DEGRADED` and the cause. ONCE per session, not per
#       notice (0497 rule 1: count per pass, never alert per item) -- NTD4.
#   ::xschem::notify_safe {msg {tag {}}}
#       THE ONE delegate body behind ase::echo AND wviewer::echo. Tries the
#       channel; on ANY raise falls back to the bootstrap; never propagates.
#       That is the answer to "the catch that hid it": the catch is not deleted
#       (a notice must never break a pick or a netlist) and it no longer
#       silently returns 0 -- NT21.
#   ::xschem::notify_latch_{ok,rearm,reset}
#       DEGENERATE versions in the bootstrap (ok always 1, rearm/reset no-ops),
#       redefined by ciw.tcl. Not optional: ase.tcl:619 and ase.tcl:550 call
#       them UNCAUGHT, ase.tcl:795's catch swallows the raise, and the whole
#       OP-card block -- the user's actually-reported message -- dies with it.
#       NTD5 owns that; NT20 is the fence that ciw.tcl's real latch still wins.
#
# ⚠ ASSERT ON THE FILE OR ON THE WITNESS, NEVER ON `sinks` ALONE FOR `ciw`.
# ciw.tcl:271-274 counts sink 1 whenever ::ciw_echo merely fails to raise, and
# ciw_echo (ciw.tcl:451) returns silently with no Tk -- measured under --nogui,
# `notify_last sinks` reported `ciw log` with zero sinks actually reached. That
# is 0657's lie, fixed for `log` and still live for `ciw` (filed as 0662).
#
# ⚠ AND `notify_last` GOES STALE IN THE DEGRADED CASE AT HEAD. Nothing updates
# it, so a degraded call leaves the PREVIOUS notice's dict standing (measured:
# `sinks = ciw log` after a call that reached zero sinks). NT17/NT18/NT21 assert
# the witness is FRESH FOR THIS CALL, which is why they use a message longer
# than the 28-char short-form budget: the full channel would record a CLIPPED
# `short`, the bootstrap records `{}`.

## Run $body with ::xschem::notify RENAMED AWAY, restoring it on every exit path
## including a raising body. This is the driver's own reproduction, in-process.
proc nt_no_notify {body} {
  set had [expr {[info commands ::xschem::notify] ne {}}]
  if {$had} { rename ::xschem::notify ::nt_saved_notify }
  set rc [catch {uplevel 1 $body} e]
  if {$had} {
    catch {rename ::xschem::notify {}}
    catch {rename ::nt_saved_notify ::xschem::notify}
  }
  if {$rc} { return [list ERR $e] }
  return $e
}

## Run $body with ::xschem::notify replaced by one that RAISES -- a genuine bug
## INSIDE the channel, which is the only thing the delegates' catch can still
## fire on once the bootstrap guarantees the command exists.
proc nt_raising_notify {body} {
  set had [expr {[info commands ::xschem::notify] ne {}}]
  if {$had} { rename ::xschem::notify ::nt_saved_notify2 }
  proc ::xschem::notify {args} {
    return -code error {NT21 a simulated bug inside the channel itself}
  }
  set rc [catch {uplevel 1 $body} e]
  catch {rename ::xschem::notify {}}
  if {$had} { catch {rename ::nt_saved_notify2 ::xschem::notify} }
  if {$rc} { return [list ERR $e] }
  return $e
}

# --- NT16: R3 -- the bootstrap is OVERRIDDEN, NOT winning --------------------
# "A bootstrap that silently wins in the normal case would delete every visible
# sink and pass a naive test." So the discriminator is never `info commands`:
# the LIVE ::xschem::notify must RAISE on an unknown option (ciw.tcl:257) and
# carry -menu/-command as SEPARATE witness fields, its body must name the two Tk
# sinks, and it must NOT be the bootstrap's body. Nothing here CALLS the
# bootstrap -- a direct call would fire the once-latch and make NTD4/PS23 read
# their own side effect.
set nt16_boot_body {} ; catch {set nt16_boot_body [info body ::xschem::notify_bootstrap]}
set nt16_full_body {} ; catch {set nt16_full_body [info body ::xschem::notify]}
set nt16_raise [catch {::xschem::notify {NT16 unknown option probe} -no_such_option x}]
set nt16_menu {Outputs > Save All… > Save device OP parameters}
nt_capture [list ::xschem::notify {NT16 remedy probe} -menu $nt16_menu -command {puts hi}]
check "NT16 0658 R3 the LIVE ::xschem::notify is the FOUR-SINK one, not the\
 bootstrap: it raises on an unknown option, names both Tk sinks in its body,\
 keeps -menu/-command as distinct fields, and its body differs from\
 notify_bootstrap's" \
  [list [expr {[info commands ::xschem::notify_bootstrap] ne {} ? 1 : 0}] \
        $nt16_raise \
        [expr {[string first notify_statusbar $nt16_full_body] >= 0 ? 1 : 0}] \
        [expr {[string first notify_popup     $nt16_full_body] >= 0 ? 1 : 0}] \
        [expr {($nt16_boot_body ne {} && $nt16_boot_body eq $nt16_full_body) ? 1 : 0}] \
        [nt_field menu] [nt_field command]] \
  [list 1 1 1 1 0 $nt16_menu {puts hi}]

# --- NT17: R1/R2 mechanism -- the channel is gone and the notice is STILL made
# The driver's own reproduction. At HEAD ase::echo catches, returns 0, and
# ::xschem::notify_last keeps the PREVIOUS notice's dict -- so this row asserts
# the witness is FRESH FOR THIS CALL. `short {}` is the second discriminator:
# the message is 71 characters, so the full channel would record a 28-char
# clipped short form and only the bootstrap records {}.
set NT_LONG_A {NT17 the notification channel is gone and this notice must still be made}
set nt17_rc [catch {nt_no_notify {::ase::echo $::NT_LONG_A error}} nt17_r]
check "NT17 0658 R1/R2 with ::xschem::notify RENAMED AWAY, ase::echo still\
 reaches the bootstrap: it does not raise, and notify_last is FRESH FOR THIS\
 CALL with no short form, no remedy and an HONEST (empty, --nolog) sink list" \
  [list $nt17_rc [nt_field msg] [nt_field tag] [nt_field short] \
        [nt_field menu] [nt_field command] [nt_field sinks] \
        [expr {[string length $NT_LONG_A] > 28 ? 1 : 0}]] \
  [list 0 $NT_LONG_A error {} {} {} {} 1]

# --- NT18: the same row for wviewer::echo -----------------------------------
# Separate row on purpose: the two delegates were byte-identical copies before
# 0650 and must not now pass on each other's evidence.
set NT_LONG_B {NT18 the waveform viewer delegate must reach the durable log too}
set nt18_rc [catch {nt_no_notify {::wviewer::echo $::NT_LONG_B error}} nt18_r]
check "NT18 0658 R2 with the channel gone wviewer::echo reaches the bootstrap\
 too, with its own fresh witness" \
  [list $nt18_rc [nt_field msg] [nt_field tag] [nt_field short] [nt_field sinks]] \
  [list 0 $NT_LONG_B error {} {}]

# --- NT19: the I1 fences -- the bootstrap is SMALLER, and there is ONE delegate
# "If you find yourself copying the trimright / trailing-backslash pad /
# empty-guard block out of ciw.tcl, STOP -- that is the I1 breach." The
# degraded mode must be visibly smaller than the channel and must not mention
# any of the things it deliberately does not have.
set nt19_bb {} ; catch {set nt19_bb [info body ::xschem::notify_bootstrap]}
set nt19_nb {} ; catch {set nt19_nb [info body ::xschem::notify]}
set nt19_forbidden {}
foreach t {notify_statusbar notify_popup notify_short notify_ciw_visible
           notify_style notify_latch_ok ciw_echo} {
  if {[string first $t $nt19_bb] >= 0} { lappend nt19_forbidden $t }
}
set nt19_ase {} ; catch {set nt19_ase [info body ::ase::echo]}
set nt19_wv  {} ; catch {set nt19_wv  [info body ::wviewer::echo]}
check "NT19 0658 I1: notify_bootstrap is STRICTLY SMALLER than notify and names\
 none of the sinks/policies it deliberately lacks, and BOTH delegates call the\
 ONE shared notify_safe body" \
  [list [expr {($nt19_bb ne {} && $nt19_nb ne {} && \
                [string length $nt19_bb] < [string length $nt19_nb]) ? 1 : 0}] \
        $nt19_forbidden \
        [expr {[string first notify_safe $nt19_ase] >= 0 ? 1 : 0}] \
        [expr {[string first notify_safe $nt19_wv]  >= 0 ? 1 : 0}]] \
  [list 1 {} 1 1]

# --- NT20: the DEGENERATE latch trio is overridden too -----------------------
# ⚠ GREEN BEFORE THE CHANGE, deliberately -- a control, not evidence, in the
# PS16/PS17/PS19 sense. It exists to STAY green: the bootstrap's
# notify_latch_ok always returns 1, so if the block is ever placed AFTER
# ciw.tcl (sabotage C) every -once notice in the product speaks on every call
# and 0636's three-identical-lines-per-session defect comes straight back.
nt_cx {::xschem::notify_latch_reset NT20}
check "NT20 0658 the REAL state-keyed latch still wins over the bootstrap's\
 degenerate always-1 one (a second identical (subject,state) is suppressed)" \
  [list [nt_cx {::xschem::notify_latch_ok NT20 s1}] \
        [nt_cx {::xschem::notify_latch_ok NT20 s1}] \
        [nt_cx {::xschem::notify_latch_ok NT20 s2}]] \
  {1 0 1}

# --- NT21: the catch that hid it, answered ----------------------------------
# With the bootstrap in place ::xschem::notify ALWAYS exists, so the delegates'
# catch can now only fire on a GENUINE BUG INSIDE notify -- and silently
# returning 0 for that is how this whole class of defect survives. It must not
# propagate (a notice may never break a pick or a netlist) and it must not lie
# (0652: a report that lies). So: rc 0, the notice re-made through the
# bootstrap, and the witness naming THIS message.
set NT_LONG_C {NT21 the channel itself is broken and the notice must survive that}
set nt21_rc [catch {nt_raising_notify {::ase::echo $::NT_LONG_C error}} nt21_r]
check "NT21 0658 a channel that RAISES (a real bug inside notify) is caught,\
 falls back to the bootstrap, never propagates, and records THIS notice" \
  [list $nt21_rc [nt_field msg] [nt_field tag] [nt_field short]] \
  [list 0 $NT_LONG_C error {}]


# ============================================================================
# NT22-NT29 / NTD8-NTD12 -- ISSUES 0664 / 0665 / 0666: THE CHANNEL MUST RECORD
# WHAT IT ACTUALLY DID, AND THE DELEGATE MUST READ THAT RECORD
# ============================================================================
# All three defects were INTRODUCED BY 0658'S OWN FIX, found by its adversary
# leg, and reproduced by the driver before they reached the user. They are ONE
# root cause living in ONE proc, `xschem::notify_safe` (src/xschem.tcl:14786),
# which treats ANY raise as "the channel is dead, re-make the whole notice".
#
# But src/ciw.tcl's SINK 2 is the DURABLE LOG, and five live calls come AFTER
# it -- notify_short, notify_popup, notify_ciw_visible, notify_statusbar and
# notify_record. A raise in any of them happens with the durable line ALREADY
# ON DISK, so re-making the notice produces:
#
#   * TWO durable lines for one notice                                   (0665)
#   * a `NOTICE CHANNEL DEGRADED` claim -- "notices are LOG-ONLY from here on,
#     no CIW pane, no status field, no popup" -- asserted while the four-sink
#     channel was demonstrably ALIVE                                     (0664)
#   * and, because that announcement is a ONE-SHOT LATCH, the false positive
#     BURNS IT: the genuine degradation that follows announces NOTHING. The
#     announcement fires for the healthy case and stays silent for the sick one.
#
# MEASURED AT HEAD, in a child with a real --logdir (the driver's own numbers,
# reproduced twice more by this crew). Xschem.log, lines 4-7, IN ORDER:
#     4:#! DRIVERMARK-B
#     5:#! NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here on ... Cause:
#          invalid command name "xschem::notify_record"
#     6:#! DRIVERMARK-B            <- the duplicate (0665)
#     7:#! DRIVERMARK-A            <- the notice made when the channel really WAS
#                                     gone, with NO announcement after it (0664)
#
# THE CONTRACT THESE ROWS DEFINE (red-first; the names and the marker strings
# are GOLDEN here, exactly as 0658's were):
#
#   ::xschem::notify_progress
#       A NAMESPACE VARIABLE in src/xschem.tcl's bootstrap block, beside
#       `notify_degraded`. THE record of which sinks actually fired. It must be
#       a namespace variable and NOT a local: a record that unwinds with the
#       error is useless, and the case that produced the double line is a raise
#       at the channel's LAST statement, not its first (NT22).
#       ⚠ It lives in src/xschem.tcl, never in src/ciw.tcl -- the degraded state
#       it exists to serve is the one state where ciw.tcl is absent.
#   ::xschem::notify_mark {sink} / ::xschem::notify_mark_reset {}
#       the ONE appender and the ONE reset (invariant I1). ciw.tcl's local
#       `sinks` becomes the appender's RETURN VALUE, so the record and the
#       witness cannot drift into two accounts of one fact (NT29).
#       ⚠ The reset belongs at the channel's FIRST statement, before option
#       parsing and before the latch gate -- resetting where `set sinks {}` sits
#       today would leave the PREVIOUS call's record standing after a raise in
#       option parsing, and notify_safe would then skip a durable write that
#       never happened. That is a G1 regression wearing a 0665 fix (NT23).
#   ::xschem::notify_channel_degraded {}
#       THE MEASUREMENT behind the announcement. 1 when ::xschem::notify is
#       absent, when `info body` on it raises, or when its body names
#       notify_bootstrap; 0 otherwise. 0664 is issue 0652's defect class -- a
#       report that LIES -- and the whole feature exists to be believed, so
#       whatever the line says must be TRUE at the moment it is said (NT24).
#   `NOTICE CHANNEL FAULT`
#       the SECOND marker, on its OWN one-shot latch (`notify_fault`), for a
#       raise out of a channel that measures LIVE. It must NOT contain the
#       substring `NOTICE CHANNEL DEGRADED`: NTD1/PS20 assert that marker's
#       ABSENCE in the healthy case and NTD4/PS23 count exactly one of it, so a
#       second use of the golden string would break four committed rows and
#       re-tell 0664's lie (NT25, NT26, NTD11, NTD12).
#   ase::echo / wviewer::echo
#       each keeps the 0658 guarantee IN ITSELF -- a catch, a last-resort
#       `notice channel unavailable` line on stderr, and an HONEST `return 0`
#       (nothing reached any sink; stderr is never a sink, 0658 D9). 0666's
#       reachability is NARROWER than the issue claims and still REAL: the
#       FILE-LOAD path is closed by issue 0663 (src/xinit.c:3571 -- a partially
#       loaded xschem.tcl exits 1, announced), but a RUNTIME
#       `namespace delete ::xschem` succeeds, takes ::xschem from 13 procs to 0,
#       leaves the C `xschem` command working, and is reachable from ciw_exec's
#       `uplevel #0 $cmd` (src/ciw.tcl:557) and from any --script (NT27, NTD10).
#
# ⚠ WHAT THESE IN-PROCESS ROWS CANNOT DO. test_ase_core runs --nogui with NO
# --logdir, so there is no action log at all: `notify_log` returns 0 and the
# record reads `ciw`, never `ciw log`. Every DURABLE-LINE COUNT therefore lives
# in a child (NTD8-NTD12) or in test_ase_log_seam_0207.tcl (PS28-PS34), and the
# rows here assert the MECHANISM: the record, its reset point, the
# measurement, the two latches and the delegates' guarantee.

## The sinks-fired record, with a SPEAKING placeholder when it does not exist --
## a bare read reports "can't read ...: no such variable", which names the wrong
## defect (the nt_field idiom).
proc nt_progress {} {
  if {![info exists ::xschem::notify_progress]} { return NO-RECORD }
  return $::xschem::notify_progress
}

## Run $body with ::xschem::notify_record RENAMED AWAY. The channel then raises
## at its LAST statement -- AFTER sink 1, sink 2 and sinks 3/4 have all already
## fired -- which is the shape the driver reproduced and the ONLY one that can
## produce a second durable line. Restores on every exit path.
proc nt_no_record {body} {
  set had [expr {[info commands ::xschem::notify_record] ne {}}]
  if {$had} { rename ::xschem::notify_record ::nt_saved_record }
  set rc [catch {uplevel 1 $body} e]
  if {$had} {
    catch {rename ::xschem::notify_record {}}
    catch {rename ::nt_saved_record ::xschem::notify_record}
  }
  if {$rc} { return [list ERR $e] }
  return $e
}

## Run $body with ::xschem::notify_safe RENAMED AWAY -- 0666's reachable
## runtime shape, narrowed to one proc so the row names one defect.
proc nt_no_safe {body} {
  set had [expr {[info commands ::xschem::notify_safe] ne {}}]
  if {$had} { rename ::xschem::notify_safe ::nt_saved_safe }
  set rc [catch {uplevel 1 $body} e]
  if {$had} {
    catch {rename ::xschem::notify_safe {}}
    catch {rename ::nt_saved_safe ::xschem::notify_safe}
  }
  if {$rc} { return [list ERR $e] }
  return $e
}

## Re-arm BOTH announcement latches. These in-process rows assert CONTENT and
## STATE, never a session count -- NTD4 and PS23 own "exactly once per session",
## in children and in a suite that has a log -- so each row starts from a known
## state instead of inheriting NT17/NT21's.
proc nt_rearm_latches {} {
  catch {set ::xschem::notify_degraded 0}
  catch {set ::xschem::notify_fault 0}
}

# --- NT22: THE RECORD MUST SURVIVE THE RAISE ---------------------------------
# The brief's hard requirement: "a record kept in a local that unwinds with the
# error is useless. Prove it survives with a test that raises at the LAST
# statement of the channel, not the first -- that is the case that produced the
# double line." A DIRECT ::xschem::notify call, so nothing downstream can write
# the record afterwards and this row measures the channel alone.
set NT22_MSG {NT22 the sinks-fired record must survive the unwind}
nt_no_record {set ::nt22_rc [catch {::xschem::notify $::NT22_MSG -tag error} ::nt22_e]}
check "NT22 0665 the channel RECORDS WHAT IT DID in a namespace variable that\
 SURVIVES the unwind: with notify_record gone it raises at its LAST statement\
 and the record still names the sink that had already fired" \
  [list $nt22_rc [expr {[info exists ::xschem::notify_progress] ? 1 : 0}] \
        [expr {[lsearch -exact [nt_progress] ciw] >= 0 ? 1 : 0}] \
        [expr {[info commands ::ciw_echo] ne {} ? 1 : 0}]] \
  [list 1 1 1 1]
note "NT22 record after the raise" [nt_progress]
note "NT22 raise message"          [expr {[info exists ::nt22_e] ? $::nt22_e : {NO-RAISE}}]

# --- NT23: THE RESET IS AT THE CHANNEL'S FIRST STATEMENT ---------------------
# The landmine, stated as a row. If the reset is put where `set sinks {}` sits
# today (after option parsing and after the notify_latch_ok gate), a raise in
# EITHER of those leaves the PREVIOUS call's record standing -- and notify_safe,
# reading `log` from a notice that succeeded minutes ago, then skips a durable
# write that never happened. That is a G1 regression, not a 0665 fix.
::xschem::notify {NT23 a healthy notice fills the record}
set nt23_filled [expr {([nt_progress] ne {NO-RECORD} && [llength [nt_progress]] > 0) ? 1 : 0}]
set nt23_optrc  [catch {::xschem::notify {NT23 option probe} -no_such_option x}]
check "NT23 0665 the record is RESET at notify's FIRST statement, before option\
 parsing and before the latch gate: a raise in OPTION PARSING leaves an EMPTY\
 record, never the previous call's" \
  [list $nt23_filled $nt23_optrc [nt_progress]] [list 1 1 {}]

# --- NT24: THE DISCRIMINATOR -- the claim becomes a MEASUREMENT --------------
# Issue 0664: "the degradation line says notices are LOG-ONLY from here on.
# Today it says that without checking." Three states, one proc: the live
# channel, the channel ABSENT (PS21/NT17's shape, where `info body` itself
# raises), and the bootstrap wrapper INSTALLED. The bootstrap wrapper is
# installed and measured but NEVER CALLED -- a call would burn the once-latch
# and make NTD4/PS23 read their own side effect (NT16's rule).
set nt24_normal [nt_cx {::xschem::notify_channel_degraded}]
set nt24_gone   [nt_no_notify {nt_cx {::xschem::notify_channel_degraded}}]
set nt24_boot NO-RUN
if {[info commands ::xschem::notify] ne {}} {
  rename ::xschem::notify ::nt_saved_notify3
  proc ::xschem::notify {msg args} { return [xschem::notify_bootstrap $msg {*}$args] }
  set nt24_boot [nt_cx {::xschem::notify_channel_degraded}]
  catch {rename ::xschem::notify {}}
  catch {rename ::nt_saved_notify3 ::xschem::notify}
}
check "NT24 0664 the degradation claim is a MEASUREMENT, not an assumption: the\
 LIVE four-sink channel reads 0, an ABSENT ::xschem::notify reads 1, and the\
 bootstrap wrapper INSTALLED (never called) reads 1" \
  [list $nt24_normal $nt24_gone $nt24_boot] {0 1 1}

# --- NT25: 0664 -- NO FALSE DEGRADATION -------------------------------------
# The headline. A raise AFTER the sinks have fired is a FAULT inside a channel
# that is demonstrably alive; it is NOT "notices are LOG-ONLY from here on". The
# genuine `notify_degraded` latch must be left UNBURNT -- that is what NT26 then
# needs.
#
# ⚠ WHAT THIS ROW DOES NOT PROVE, and an earlier revision wrongly claimed it
# did: that the NEXT notice reaches every sink. It does not, for a persistent
# cause -- measured, issue 0675 -- and the FAULT sentence no longer says so.
nt_rearm_latches
set NT25_MSG {NT25 the channel raised AFTER delivering and that is not a degradation}
set nt25_rc [catch {nt_no_record {::ase::echo $::NT25_MSG error}} nt25_r]
check "NT25 0664 a raise AFTER the sinks fired is a FAULT, not a degradation:\
 the LOG-ONLY claim is NOT made while the four-sink channel is alive, and the\
 degraded latch is left unburnt for the state that really needs it" \
  [list $nt25_rc \
        [expr {[info exists ::xschem::notify_degraded] ? $::xschem::notify_degraded : {NO-VAR}}] \
        [expr {[info exists ::xschem::notify_fault] ? $::xschem::notify_fault : {NO-VAR}}]] \
  [list 0 0 1]

# --- NT26: 0664 SECOND ORDER -- THE FALSE POSITIVE ATE THE REAL ONE ----------
# Worse than the issue states, and no committed row catches it: NTD4/PS23 count
# "exactly 1" and pass whichever announcement it is. Immediately after NT25's
# fault the channel is lost FOR REAL, and the genuine degradation must still be
# announced. At HEAD the pair reads {1 1} -- the latch was already burnt by the
# false positive and the real state is announced NOWHERE.
set nt26_before [expr {[info exists ::xschem::notify_degraded] ? $::xschem::notify_degraded : {NO-VAR}}]
nt_no_notify {::ase::echo {NT26 the channel is genuinely gone and must say so} error}
check "NT26 0664 the GENUINE degradation still announces itself after NT25's\
 fault -- a false positive must never eat the real announcement" \
  [list $nt26_before \
        [expr {[info exists ::xschem::notify_degraded] ? $::xschem::notify_degraded : {NO-VAR}}]] \
  {0 1}

# --- NT27: 0666 -- THE DELEGATES DO NOT RAISE INTO THEIR CALLER --------------
# 0658's brief said "a notice must never break its caller". The catch was not
# deleted, it MOVED into the callee, leaving both delegates bare one-liners that
# raise `invalid command name "::xschem::notify_safe"` when notify_safe is gone
# -- 61+ ASE call sites and wave_viewer's, every one of them able to raise into
# a pick or a netlist. And what they return must be TRUE (0652): a delegate that
# returns 0 without having checked is the same defect. Nothing reached any sink
# here, so 0 is honest, and the witness is untouched to prove it.
set nt27_last0 [expr {[info exists ::xschem::notify_last] ? $::xschem::notify_last : {NO-WITNESS}}]
set nt27_ase [nt_no_safe {list [catch {::ase::echo {NT27 an ASE notice with the delegate body gone} error} e] $e}]
set nt27_wv  [nt_no_safe {list [catch {::wviewer::echo {NT27 a viewer notice with the delegate body gone} error} e] $e}]
set nt27_last1 [expr {[info exists ::xschem::notify_last] ? $::xschem::notify_last : {NO-WITNESS}}]
check "NT27 0666 neither delegate RAISES INTO ITS CALLER when notify_safe is\
 gone, and the 0 they return is TRUE -- the witness is byte-identical before\
 and after, so nothing was delivered and nothing pretends it was" \
  [list $nt27_ase $nt27_wv [expr {$nt27_last1 eq $nt27_last0 ? 1 : 0}]] \
  [list {0 0} {0 0} 1]

# --- NT28: the guarantee is IN the delegates -------------------------------
# NT19's idiom, on the behaviour NT27 measures: a bare one-liner cannot keep a
# promise about a callee that is gone. The guard is INLINE in each delegate on
# purpose -- extracting it into a shared proc would put it in the very namespace
# whose absence it exists to survive (0666: "a guard is not a builder").
set nt28_ase {} ; catch {set nt28_ase [info body ::ase::echo]}
set nt28_wv  {} ; catch {set nt28_wv  [info body ::wviewer::echo]}
check "NT28 0666 BOTH delegates carry the guarantee in their own body (a catch\
 and a last-resort stderr line), not merely by NT27's grace" \
  [list [expr {[string first catch  $nt28_ase] >= 0 ? 1 : 0}] \
        [expr {[string first stderr $nt28_ase] >= 0 ? 1 : 0}] \
        [expr {[string first catch  $nt28_wv]  >= 0 ? 1 : 0}] \
        [expr {[string first stderr $nt28_wv]  >= 0 ? 1 : 0}]] \
  {1 1 1 1}

# --- NT29: I1 -- ONE ACCOUNT, NOT TWO ---------------------------------------
# Invariant I1 applied to the record itself. The rejected alternative was to
# keep ciw.tcl's local `sinks` and MIRROR each lappend into a namespace list:
# two accounts of one fact, whose drift is SILENT. This row reddens the moment
# they can differ.
::xschem::notify {NT29 one healthy notice, one account}
set nt29_sinks [nt_field sinks]
check "NT29 0665 I1 ONE ACCOUNT: after a healthy notice the surviving record IS\
 the witness's own `sinks` list, so the two cannot drift" \
  [list [nt_progress] [expr {$nt29_sinks ne {} ? 1 : 0}]] \
  [list $nt29_sinks 1]
# ---------------------------------------------------------------------------
# NTD1-NTD7 -- THE REAL DEGRADED STATE, IN A CHILD PROCESS
# ---------------------------------------------------------------------------
# A rename removes ONE proc. A failed `source` removes a whole FILE, at startup,
# before any test script exists to do the renaming -- which is the state 0658 is
# actually about. The only honest reproduction is a second xschem whose
# XSCHEM_SHAREDIR is a symlink farm carrying a broken ciw.tcl
# (tests/headless/sharefarm.tcl). These rows also need a REAL durable log, and
# util.c:351 (`if(!has_x && !cli_opt_logdir[0]) return;`) means that requires
# `--logdir` -- which no full_audit arm combines with --nogui, so the child
# idiom (test_descend_log_absorb.tcl:48, test_ciw_actionlog_output.tcl:36) is
# how these rows exist at all.
set ntd_farm_ok  [share_farm $repo [file join $scratch farm_ok]]
set ntd_farm_bad [share_farm $repo [file join $scratch farm_bad] \
  [list ciw.tcl "error {0658 deliberate failure at the TOP of ciw.tcl}\n"]]

set NTD_ASE {NTD-0658 an ASE refusal the user must see}
set NTD_WV  {NTD-0658 a waveform-viewer refusal the user must see}
set ntd_inner {
  proc ntd_mark {k v} { puts "NTD-MARK $k=$v" ; flush stdout }
  ntd_mark notify   [expr {[info commands ::xschem::notify] ne {} ? 1 : 0}]
  ntd_mark ciw_echo [expr {[info commands ::ciw_echo] ne {} ? 1 : 0}]
  ntd_mark boot     [expr {[info commands ::xschem::notify_bootstrap] ne {} ? 1 : 0}]
  catch {::ase::echo {NTD-0658 an ASE refusal the user must see} error} r
  ntd_mark ase $r
  catch {::wviewer::echo {NTD-0658 a waveform-viewer refusal the user must see} error} r
  ntd_mark wv $r
  ## R4: five MORE notices, so "announced ONCE, not per notice" is measurable
  for {set i 1} {$i <= 5} {incr i} { catch {::ase::echo "NTD-0658 volume notice $i" error} }
  ## ase.tcl:619 / ase.tcl:550 call these UNCAUGHT
  ntd_mark latch_ok    [list [catch {::xschem::notify_latch_ok ntd s1} e] $e]
  ntd_mark latch_rearm [catch {::xschem::notify_latch_rearm ntd s1}]
  ntd_mark latch_reset [catch {::xschem::notify_latch_reset ntd}]
  exit 0
}
proc ntd_get {out k} {
  foreach l [split $out \n] {
    if {[regexp "^NTD-MARK $k=(.*)\$" [string trim $l] -> v]} { return $v }
  }
  return NO-MARK
}
set ntd_ok  [share_farm_child $ntd_farm_ok  [file join $scratch ntd_ok]  $ntd_inner]
set ntd_bad [share_farm_child $ntd_farm_bad [file join $scratch ntd_bad] $ntd_inner]
note "NTD ok  status"  [dict get $ntd_ok  -status]
note "NTD bad status"  [dict get $ntd_bad -status]

# --- NTD1: the NORMAL configuration, so the broken one means something -------
# ⚠ GREEN BEFORE THE CHANGE. A control: it proves the farm, the child and the
# log reader all work, so NTD2's red is about ciw.tcl and nothing else.
check "NTD1 0658 a child on a NORMAL share farm exits 0, its durable log\
 carries the notice, and it announces NO degradation" \
  [list [dict get $ntd_ok -status] \
        [share_farm_count [dict get $ntd_ok -log] $NTD_ASE] \
        [share_farm_count [dict get $ntd_ok -log] {NOTICE CHANNEL DEGRADED}]] \
  [list 0 1 0]

# --- NTD7: non-vacuity -- the broken farm really IS degraded -----------------
# Without this, NTD2 could be measuring a perfectly healthy run.
check "NTD7 0658 the broken farm really loses ciw.tcl (::ciw_echo present on\
 the normal farm, ABSENT on the broken one)" \
  [list [ntd_get [dict get $ntd_ok -out] ciw_echo] \
        [ntd_get [dict get $ntd_bad -out] ciw_echo]] \
  {1 0}

# --- NTD2: THE HEADLINE ROW ---------------------------------------------------
# Originally RED, and not in the way 0658 predicted: the child did not run
# degraded, it SIGSEGVed (`CHILDKILLED SIGSEGV`, exit 139) because the ciw.tcl
# source at :14854 was bare. 0658's catch there is what makes exit 0 the answer;
# issue 0663 removed the SIGSEGV for every OTHER helper, in C.
# Both halves are asserted here because either alone is a lie:
# a survivable startup with no log line, or a log line from a process that
# never reached the degraded state.
check "NTD2 0658 R1 a child whose ciw.tcl FAILS TO SOURCE still starts (exit 0,\
 not SIGSEGV) and ase::echo's line IS in the durable log" \
  [list [dict get $ntd_bad -status] \
        [share_farm_count [dict get $ntd_bad -log] $NTD_ASE]] \
  [list 0 1]

# --- NTD3: the other delegate, same state ------------------------------------
check "NTD3 0658 R2 the same degraded child writes wviewer::echo's line to the\
 durable log too" \
  [share_farm_count [dict get $ntd_bad -log] $NTD_WV] 1

# --- NTD4: R4 -- announced ONCE, not per notice ------------------------------
# 0497 rule 1: count per pass, never alert per item. Seven notices go through
# the bootstrap in that child; the log must carry all seven and exactly ONE
# announcement. The volume count is the non-vacuity half -- one announcement
# and no notices would also read as "exactly 1".
check "NTD4 0658 R4 the degraded-state announcement appears EXACTLY ONCE in the\
 whole log, while all five volume notices are still logged" \
  [list [share_farm_count [dict get $ntd_bad -log] {NOTICE CHANNEL DEGRADED}] \
        [share_farm_count [dict get $ntd_bad -log] {NTD-0658 volume notice}]] \
  {1 5}

# --- NTD5: the degenerate latch trio ------------------------------------------
# ase::op_cards_nudge_ok (ase.tcl:619) and _reset (ase.tcl:550) call these
# UNCAUGHT; measured, they RAISE `invalid command name
# "::xschem::notify_latch_ok"` when the channel is gone, and ase.tcl:795's catch
# swallows the whole OP-card block with no message and no log line. A bootstrap
# that defined only `notify` would turn NTD2/NTD3 green while the user's
# actually-reported gate-off nudge stayed dead.
check "NTD5 0658 in the degraded child notify_latch_ok answers 1 and\
 rearm/reset do not raise, so ase::op_cards_nudge_* survives" \
  [list [ntd_get [dict get $ntd_bad -out] latch_ok] \
        [ntd_get [dict get $ntd_bad -out] latch_rearm] \
        [ntd_get [dict get $ntd_bad -out] latch_reset]] \
  {{0 1} 0 0}

# --- NTD6: the failure is REPORTED, not swallowed -----------------------------
# 0423's standing objection to catching a source is "a silent continue hides the
# problem". The announcement is the answer: it names the cause, once, on stderr
# and in the durable log.
set ntd6_out [dict get $ntd_bad -out]
check "NTD6 0658 the degraded child SAYS SO and names ciw.tcl as the cause\
 (a caught source is not a silent continue)" \
  [list [expr {[string first {NOTICE CHANNEL DEGRADED} $ntd6_out] >= 0 ? 1 : 0}] \
        [expr {[string first {ciw.tcl} $ntd6_out] >= 0 ? 1 : 0}] \
        [expr {[string first {NOTICE CHANNEL DEGRADED} \
                 [join [dict get $ntd_bad -log] "\n"]] >= 0 ? 1 : 0}]] \
  {1 1 1}

# ---------------------------------------------------------------------------
# NTD8-NTD12 -- 0664/0665/0666 WHERE THEY CAN BE COUNTED: A CHILD WITH A LOG
# ---------------------------------------------------------------------------
# The rows above assert the MECHANISM in-process. They cannot assert a DURABLE
# LINE COUNT, because this suite runs --nogui with no --logdir and has no action
# log at all (src/util.c:351). 0665 IS a durable line count -- "one notice, two
# lines" -- so it has to be measured where a log exists: a child with a private
# --logdir, the same idiom NTD1-NTD7 use.
#
# ⚠ THE FARM HERE IS THE **NORMAL** ONE for NTD8-NTD10. These are not degraded
# sessions: the whole point of 0664/0665 is that they fire while the four-sink
# channel is ALIVE, so `boot=0` and `ciw_echo=1` are asserted as non-vacuity in
# the same row. NTD11/NTD12 use a THIRD farm -- the REAL ciw.tcl with a trailing
# `error`, i.e. a file that defines every proc and then fails at its LAST line.
# That is the shape 0664 was actually measured in, and it is the one a naive
# "did the source raise?" test reads exactly backwards.

## the first log line carrying $s, so a row can assert WHAT an announcement
## named and not merely that one exists
proc ntd_line_with {lines s} {
  foreach l $lines { if {[string first $s $l] >= 0} { return $l } }
  return {}
}

set NTD_B {NTD-0665 DRIVERMARK-B one notice must leave ONE durable line}
set NTD_A {NTD-0665 DRIVERMARK-A the channel is entirely gone}
set ntd_inner_dbl [string map [list @B@ $NTD_B @A@ $NTD_A] {
  proc ntd_mark {k v} { puts "NTD-MARK $k=$v" ; flush stdout }
  ## non-vacuity FIRST: this child is NOT degraded. `boot` is 1 only if the
  ## live ::xschem::notify is the bootstrap wrapper (its body names
  ## notify_bootstrap) -- the same discriminator NT16/PS20 use.
  ntd_mark boot     [expr {[string match {*notify_bootstrap*} [info body ::xschem::notify]] ? 1 : 0}]
  ntd_mark ciw_echo [expr {[info commands ::ciw_echo] ne {} ? 1 : 0}]
  ## THE DRIVER'S OWN REPRODUCTION. notify_record is the channel's LAST
  ## statement, so this raise happens with the durable line already on disk.
  rename ::xschem::notify_record ::ntd_saved_record
  catch {::ase::echo {@B@} error} r
  catch {rename ::ntd_saved_record ::xschem::notify_record}
  ntd_mark echo_b $r
  ## and now the channel really IS gone -- 0658's shipped guarantee (G1), which
  ## this fix must not move by one line.
  rename ::xschem::notify ::ntd_saved_notify
  catch {::ase::echo {@A@} error} r2
  catch {rename ::ntd_saved_notify ::xschem::notify}
  ntd_mark echo_a $r2
  exit 0
}]
set ntd_dbl [share_farm_child $ntd_farm_ok [file join $scratch ntd_dbl] $ntd_inner_dbl]
note "NTD8 child status" [dict get $ntd_dbl -status]

# --- NTD8: R1 -- THE DRIVER'S REPRODUCTION, COMMITTED ------------------------
# Measured at HEAD: 2. The log carries the real line, then the false degradation
# announcement, then the SAME line again -- sink 2 wrote, notify_safe declared
# the channel dead, and the bootstrap re-made a notice that had already been
# delivered.
check "NTD8 0665 R1 with notify_record renamed away the channel raises at its\
 LAST statement, after every sink -- and ONE ase::echo leaves EXACTLY ONE\
 durable line in a session whose channel is demonstrably ALIVE" \
  [list [dict get $ntd_dbl -status] \
        [ntd_get [dict get $ntd_dbl -out] boot] \
        [ntd_get [dict get $ntd_dbl -out] ciw_echo] \
        [share_farm_count [dict get $ntd_dbl -log] $NTD_B]] \
  [list 0 0 1 1]

# --- NTD9: R2 + G1 + G5, in the same child -----------------------------------
# THREE things at once, because separating them would let one pass on another's
# evidence: (G1) the notice made with the channel ENTIRELY gone still leaves its
# one durable line -- 0658's guarantee, driver-verified, and the row that must
# not move; (0664) exactly ONE `NOTICE CHANNEL DEGRADED` line and it names the
# MISSING COMMAND, not a healthy channel; (G5) the late raise is announced, but
# as a FAULT, so the two states are distinguishable in the log a user reads.
# At HEAD the DEGRADED line names `"xschem::notify_record"` -- the healthy
# channel's own last statement -- and there is no FAULT line at all.
set ntd9_log [dict get $ntd_dbl -log]
check "NTD9 0664/0665 G1+G5 the notice made with the channel ENTIRELY GONE\
 still leaves exactly one durable line, exactly ONE degradation is announced\
 and it names the MISSING COMMAND, and the late raise is announced separately\
 as a FAULT" \
  [list [share_farm_count $ntd9_log $NTD_A] \
        [share_farm_count $ntd9_log {NOTICE CHANNEL DEGRADED}] \
        [expr {[string first {"::xschem::notify"} \
                 [ntd_line_with $ntd9_log {NOTICE CHANNEL DEGRADED}]] >= 0 ? 1 : 0}] \
        [share_farm_count $ntd9_log {NOTICE CHANNEL FAULT}]] \
  [list 1 1 1 1]
note "NTD9 the DEGRADED line" [ntd_line_with $ntd9_log {NOTICE CHANNEL DEGRADED}]
note "NTD9 the FAULT line"    [ntd_line_with $ntd9_log {NOTICE CHANNEL FAULT}]

# --- NTD10: 0666's REACHABLE RUNTIME PATH ------------------------------------
# The brief ordered this measured rather than assumed, and it changed the answer.
# The FILE-LOAD path 0666 was written about is CLOSED by issue 0663: a
# partially-loaded xschem.tcl now exits 1 with an announced STARTUP ABORTED, so
# no delegate can exist without notify_safe (notify_safe is defined at
# src/xschem.tcl:14786, ase.tcl is sourced at :14802, wave_viewer at :14806, and
# xschemrc is read BEFORE xschem.tcl). What IS live is this: `namespace delete
# ::xschem` succeeds at runtime, takes the namespace from 13 procs to 0, leaves
# the C `xschem` command working -- and is reachable from ciw_exec's
# `uplevel #0 $cmd` (src/ciw.tcl:557) and from any --script or user helper. So
# the fix is a two-line guard per delegate, and 0666's "unreachable outside a
# test's own sabotage" sentence is too strong and is corrected in writing.
set NTD_NS_A {NTD-0666 an ASE notice with the whole ::xschem namespace deleted}
set NTD_NS_W {NTD-0666 a viewer notice with the whole ::xschem namespace deleted}
set ntd_inner_ns [string map [list @A@ $NTD_NS_A @W@ $NTD_NS_W] {
  proc ntd_mark {k v} { puts "NTD-MARK $k=$v" ; flush stdout }
  namespace delete ::xschem
  ntd_mark procs [llength [info procs ::xschem::*]]
  ntd_mark ase [list [catch {::ase::echo {@A@} error} e]  $e]
  ntd_mark wv  [list [catch {::wviewer::echo {@W@} error} e2] $e2]
  ## the C dispatcher is a COMMAND, not a member of the namespace -- the session
  ## keeps running, which is exactly why those 61+ call sites matter
  ntd_mark cmd [catch {xschem get current_name}]
  exit 0
}]
set ntd_ns [share_farm_child $ntd_farm_ok [file join $scratch ntd_ns] $ntd_inner_ns]
check "NTD10 0666 with the WHOLE ::xschem namespace deleted at RUNTIME neither\
 delegate raises into its caller: the child exits 0, the session survives, both\
 answer {0 0} -- rc 0 and an honest 0 sinks -- and the last resort says so on\
 stderr" \
  [list [dict get $ntd_ns -status] \
        [ntd_get [dict get $ntd_ns -out] procs] \
        [ntd_get [dict get $ntd_ns -out] ase] \
        [ntd_get [dict get $ntd_ns -out] wv] \
        [ntd_get [dict get $ntd_ns -out] cmd] \
        [expr {[string first {notice channel unavailable} \
                 [dict get $ntd_ns -out]] >= 0 ? 1 : 0}]] \
  [list 0 0 {0 0} {0 0} 0 1]

# --- NTD11: 0664's OWN MEASUREMENT, COMMITTED --------------------------------
# THE FARM THAT MATTERS. A ciw.tcl that fails at its LAST line has already
# defined every proc in it: `::xschem::notify` is the four-sink channel,
# `::ciw_echo` exists, notices reach the pane and the log. src/xschem.tcl:14855
# nonetheless announces `NOTICE CHANNEL DEGRADED: notices are LOG-ONLY from here
# on (no CIW pane, no status field, no popup, no remedy)` -- measured verbatim
# in this exact configuration, with notify_is_bootstrap=0 and ciw_echo=1 in the
# same run. Every clause of that sentence is false, and the whole feature exists
# to be believed (0652's class). The failure must still be REPORTED -- 0423's
# standing objection is that a silent continue hides the problem -- so it is
# announced as a FAULT that names ciw.tcl.
set ntd_ciw_body {}
set ntd_fd [open [file join $repo src ciw.tcl] r]
set ntd_ciw_body [read $ntd_fd]
close $ntd_fd
set ntd_farm_end [share_farm $repo [file join $scratch farm_end] \
  [list ciw.tcl "$ntd_ciw_body\nerror {0664 deliberate failure at the END of ciw.tcl}\n"]]
set NTD_LIVE {NTD-0664 a notice made while the channel is FULLY LIVE}
set NTD_GONE {NTD-0664 a notice made after the channel is genuinely gone}
set ntd_inner_end [string map [list @L@ $NTD_LIVE @G@ $NTD_GONE] {
  proc ntd_mark {k v} { puts "NTD-MARK $k=$v" ; flush stdout }
  ntd_mark boot     [expr {[string match {*notify_bootstrap*} [info body ::xschem::notify]] ? 1 : 0}]
  ntd_mark ciw_echo [expr {[info commands ::ciw_echo] ne {} ? 1 : 0}]
  catch {::ase::echo {@L@} error} r
  ntd_mark live $r
  ## and NOW lose it for real, in the same session -- G5's subject
  rename ::xschem::notify ::ntd_saved_notify
  catch {::ase::echo {@G@} error} r2
  catch {rename ::ntd_saved_notify ::xschem::notify}
  ntd_mark gone $r2
  exit 0
}]
set ntd_end [share_farm_child $ntd_farm_end [file join $scratch ntd_end] $ntd_inner_end]
set ntd11_log [dict get $ntd_end -log]
note "NTD11 child status" [dict get $ntd_end -status]
check "NTD11 0664 a ciw.tcl that fails at its END leaves the channel FULLY\
 LIVE: the four-sink notify and ::ciw_echo are both there, the notice reaches\
 the durable log, and the startup failure is announced as a FAULT NAMING\
 ciw.tcl -- never as the LOG-ONLY degradation claim, which would be false in\
 every clause" \
  [list [dict get $ntd_end -status] \
        [ntd_get [dict get $ntd_end -out] boot] \
        [ntd_get [dict get $ntd_end -out] ciw_echo] \
        [share_farm_count $ntd11_log $NTD_LIVE] \
        [share_farm_count $ntd11_log {NOTICE CHANNEL FAULT}] \
        [expr {[string first {ciw.tcl} \
                 [ntd_line_with $ntd11_log {NOTICE CHANNEL FAULT}]] >= 0 ? 1 : 0}]] \
  [list 0 0 1 1 1 1]

# --- NTD12: G5 -- A FAULT MUST NOT BURN THE DEGRADED LATCH -------------------
# 0497 rule 1 is "count per pass, never alert per item", and the announcement is
# a one-shot latch because of it. That makes WHICH event burns it load-bearing:
# at HEAD the startup false positive burns it at line 4 of the log, and when
# this same child then loses the channel for real the user is told NOTHING. The
# count stays 1 either way, so NTD4/PS23 cannot see it -- this row can.
check "NTD12 0664 G5 the FAULT does NOT burn the degraded latch: when the same\
 child then loses the channel for real, the LOG-ONLY announcement fires exactly\
 once and names the MISSING COMMAND" \
  [list [share_farm_count $ntd11_log $NTD_GONE] \
        [share_farm_count $ntd11_log {NOTICE CHANNEL DEGRADED}] \
        [expr {[string first {"::xschem::notify"} \
                 [ntd_line_with $ntd11_log {NOTICE CHANNEL DEGRADED}]] >= 0 ? 1 : 0}]] \
  [list 1 1 1]
note "NTD12 the DEGRADED line" [ntd_line_with $ntd11_log {NOTICE CHANNEL DEGRADED}]
note "NTD12 the FAULT line"    [ntd_line_with $ntd11_log {NOTICE CHANNEL FAULT}]

# --- RT: THE HIERARCHY ROUND TRIP (issue 0643 / issue 1393) ------------------
# doc/claude/descend_run_batch/PLAN.md item A. The user's words, 2026-09-08:
# "I descend into x1 and again x1. Now, I click the N&> (Netlist and Run button)
# in ASE-L to get: `ase: design is not the current schematic; open it via
# Session > Design Window first`. Where does this inane restriction come from?
# There is no such limitation in Cadence's Analog Design Environment (ADE-L),
# which we want be better than."
#
# WHY THE GUARD EXISTED, so no later crew deletes the replacement as dead
# weight: global_spice_netlist() netlists xctx->sch[xctx->currsch] -- the level
# you are STANDING ON (src/spice_netlist.c:359-373). Measured on the shipped
# sky130_tests_ase/tb_bandgap: 14862 bytes and 8 .subckt at level 0; 4685 bytes
# of bandgap_opamp alone after `descend x1, x1`. Drop the guard without
# replacing it and the button silently simulates the op-amp with no sources and
# no testbench, into a results file that looks healthy.
#
#   RT1  hier_instnames: {} at the top, the entered names when descended
#   RT2  stack_level finds the design at its OWN level, from any depth, and
#        answers -1 -- never raises -- for anything not on this stack
#   RT3  the design already current: the script runs, nothing walks
#   RT4  THE ROUND TRIP: the script runs AT the design, and the user comes back
#        to the same level, the same sheet, the same view
#   RT5  A3 row 1 (clean): autosave_backup is parked at 0 FOR THE TRIP and given
#        back afterwards -- and the park is what keeps the design's own buffer
#        from coming back flagged modified
#   RT6  A3 row 3 (modified + autosave off): REFUSED, nothing moved
#   RT7  A3 row 2 (modified + autosave on): CARRIED -- back at the same level,
#        still modified, with the edit still in the buffer
#   RT8  the entry read-only state survives the trip (cadence_style_rc:564)
#   RT9  a design that is nowhere raises the MINTED head and moves nothing
#   RT10 a re-descend that cannot complete says WHERE the person was left
#   RT11 ase::netlist's four arms, by which one actually ran
#   RT12 the minted refusal (D6): one head, a caller-chosen tail, and NOT the
#        shipped "is not the current schematic" sentence
#
# ⚠ THE ROWS BELOW DRIVE THE TRIP WITH A PROBE, NOT A NETLIST, and RT11 stubs
# ase::netlist_in_place. That is not squeamishness: MEASURED at HEAD with no
# ase:: code in the picture, `descend ; go_back ; xschem netlist` on a
# hand-written fixture whose child has ZERO instances pops the modal "Please Set
# netlisting mode (Options menu)" and a scripted run HANGS on it forever --
# load_schematic() switches netlist_type to CAD_SYMBOL_ATTRS for a file with
# xctx->instances == 0 (save.c:6469) and the parent reload does not put it back.
# Pre-existing, not reproducible on the real bench (tb_bandgap's round trip
# produces a netlist byte-identical to one taken at the top), and not this
# batch's to fix. The end-to-end byte-identity row is item C's, on that bench.
#
# THE FIXTURE is a second cell in the SAME scratch aselib, in the cadence
# lib/cell/view layout the rest of this suite already uses, so nothing here
# touches ::pathlist, ::XSCHEM_LIBRARY_PATH or the library.defs the earlier
# sections depend on.
set rtdir [file join $scratch aselib]
file mkdir [file join $rtdir rt_top schematic]
file mkdir [file join $rtdir rt_child schematic]
file mkdir [file join $rtdir rt_child symbol]
proc rt_wr {path lines} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  foreach l $lines { puts $fp $l }
  close $fp
}
rt_wr [file join $rtdir rt_child symbol rt_child.sym] [list \
  {v {xschem version=3.4.4 file_version=1.2}} \
  "G \{type=subcircuit" \
  "template=\"name=x1\"\}" \
  {V {}} {S {}} {E {}} \
  {L 4 -20 -20 20 -20 {}} \
  {L 4 20 -20 20 20 {}} \
  {L 4 20 20 -20 20 {}} \
  {L 4 -20 20 -20 -20 {}}]
## one instance in the child, deliberately: a ZERO-instance sheet is what flips
## netlist_type to CAD_SYMBOL_ATTRS at save.c:6469 (see the warning above).
rt_wr [file join $rtdir rt_child schematic rt_child.sch] [list \
  {v {xschem version=3.4.4 file_version=1.2}} \
  {G {}} {V {}} {S {}} {E {}} \
  {N 0 0 100 0 {}} \
  {C {devices/lab_pin} 0 0 0 0 {name=p1 lab=A}}]
rt_wr [file join $rtdir rt_top schematic rt_top.sch] [list \
  {v {xschem version=3.4.4 file_version=1.2}} \
  {G {}} {V {}} {S {}} {E {}} \
  {N 0 0 100 0 {}} \
  {C {aselib/rt_child} 0 0 0 0 {name=x1}}]
## the symbol RT6/RT7 place to make a real unsaved edit: a lab_pin, NOT
## rt_child's own symbol -- a cell holding an instance of itself is a recursive
## hierarchy, and this fixture has no business being one.
set rtpinsym [file join $repo xschem_libs_newsym devices lab_pin symbol lab_pin.sym]
set rttop   [file normalize [xschem cellview_path aselib/rt_top schematic]]
set rtchild [file normalize [xschem cellview_path aselib/rt_child schematic]]
check "RT0 the round-trip fixture resolves through the same cellview_path\
 accessor ase::netlist uses, and the child is a descendable subcircuit view" \
  [list [file tail $rttop] [file tail $rtchild] [file isfile $rttop] \
        [file isfile $rtchild]] \
  {rt_top.sch rt_child.sch 1 1}

## The script every trip below runs: WHERE did it run? A trip that never made
## the design current would still "succeed" without this.
proc rt_where {} { return [list [xschem get currsch] [file tail [xschem get schname]]] }
## and one that also reports the parked flag, for RT5
proc rt_where_ab {} {
  return [list [xschem get currsch] [file tail [xschem get schname]] \
               [expr {[info exists ::autosave_backup] ? $::autosave_backup : {<unset>}}]]
}
proc rt_bak {sch} { return [regsub {\.sch$} $sch {~.sch}] }
## Stand one level down inside the design, editable. `xschem set readonly 0`
## because src/cadence_style_rc:564 sets descend_readonly 1 and a read-only
## buffer can never be flagged modified (actions.c ro_suppress, issue 0035) --
## which is exactly why rows RT6/RT7 need it and why RT8 exists.
proc rt_descend {} {
  xschem load $::rttop
  xschem unselect_all
  set r [xschem descend -fallback -inst x1]
  xschem set readonly 0
  return [list $r [xschem get currsch] [file tail [xschem get schname]]]
}
set ::rttop $rttop

# --- RT1: hier_instnames -----------------------------------------------------
xschem load $rttop
set rt1a [list [ase::hier_instnames] [xschem get sch_path] [xschem get currsch]]
set rt1b [rt_descend]
check "RT1 hier_instnames is empty at the top and carries the entered instance\
 names when descended, indexed BY LEVEL so element \$l is the instance that\
 leads out of level \$l" \
  [list $rt1a [ase::hier_instnames] [xschem get sch_path] $rt1b] \
  [list {{} . 0} x1 .x1. {1 1 rt_child.sch}]

# --- RT2: stack_level --------------------------------------------------------
# NEVER RAISES: it is the predicate two doors ask before deciding what to SAY
# (ase::netlist here, ase::ui::do_run in src/ase_window.tcl), and a raise out of
# a predicate would turn "the design is somewhere else" into a bare Tcl error on
# a button press. The garbage arguments are the ones a raise would come from:
# an unbalanced brace is not a list, and {} is not a path.
check "RT2 stack_level answers the design's OWN level from one level down, -1\
 for a cell that is nowhere on this stack, and never raises on junk" \
  [list [ase::stack_level $rttop] [ase::stack_level $rtchild] \
        [ase::stack_level [file join $scratch aselib nfet_clean schematic nfet_clean.sch]] \
        [catch {ase::stack_level {}} r1] $r1 \
        [catch {ase::stack_level "a b \{c"} r2] $r2 \
        [catch {ase::stack_level $scratch} r3] $r3] \
  [list 0 1 -1 0 -1 0 -1 0 -1]

# --- RT3: the design is already current --------------------------------------
# No park, no walk, no `~` handling -- which is also what keeps every
# undescended press byte-for-byte the behaviour it shipped with.
xschem load $rttop
set rt3dc [xschem get drawcount]
set rt3 [ase::with_design_current $rttop {rt_where}]
check "RT3 with the design already current the script runs in place, the level\
 does not move, and the trip machinery is not entered at all" \
  [list $rt3 [xschem get currsch] [file tail [xschem get schname]] \
        [expr {[xschem get drawcount] - $rt3dc}]] \
  {{0 rt_top.sch} 0 rt_top.sch 0}

# --- RT4: THE ROUND TRIP -----------------------------------------------------
# THE HEADLINE ROW. Everything else in this section is a property of the trip;
# this is the trip.
rt_descend
set rt4view [list [xschem get xorigin] [xschem get yorigin] [xschem get zoom]]
set rt4dc [xschem get drawcount]
set rt4 [ase::with_design_current $rttop {rt_where}]
check "RT4 the script runs AT the design with the design current, and the user\
 comes back to the same level, the same sheet, the same sch_path and the same\
 view -- and the canvas is repainted exactly once, at the end" \
  [list $rt4 [xschem get currsch] [file tail [xschem get schname]] \
        [xschem get sch_path] [ase::hier_instnames] \
        [expr {$rt4view eq [list [xschem get xorigin] [xschem get yorigin] \
                                 [xschem get zoom]] ? 1 : 0}] \
        [expr {[xschem get drawcount] - $rt4dc}]] \
  [list {0 rt_top.sch} 1 rt_child.sch .x1. x1 1 1]

# --- RT5: A3 row 1 -- the park, and that it is not decoration ----------------
# go_back is NOT read-only: it calls load_backup_as() whenever a <cell>~.sch
# sits beside the cell (actions.c:6505) and that ends in set_modify(1)
# (save.c:6197). The park makes the ascent a plain reload (save.c:6186 early
# return). The control is the SAME ascent with the flag left alone: without it
# the design's own buffer comes back flagged modified, which is issue 0626's
# defect wearing the design's hat.
file copy -force -- $rttop [rt_bak $rttop]
rt_descend
set ::autosave_backup 1
set rt5in [ase::with_design_current $rttop {rt_where_ab}]
set rt5parked [list $rt5in [xschem get currsch] [xschem get modified] $::autosave_backup]
rt_descend
set ::autosave_backup 1
xschem go_back 2
set rt5control [list [xschem get currsch] [xschem get modified]]
file delete -force -- [rt_bak $rttop]
check "RT5 A3 row 1: a CLEAN entry buffer parks autosave_backup at 0 for the\
 trip and gets it back afterwards, so the ascent is a plain reload -- and the\
 unparked control proves the park is load-bearing, not decoration" \
  [list $rt5parked $rt5control] \
  [list {{0 rt_top.sch 0} 1 0 1} {0 1}]

# --- RT6: A3 row 3 -- modified + autosave OFF: REFUSE ------------------------
# With the flag off there is no `~` to come back to (write_backup() is a no-op,
# actions.c:206-208), so the trip would silently REVERT the edit -- issue 0626,
# measured on the shipped bandgap_opamp. A refusal and not a warning: nothing in
# Netlist-and-Run is worth an unsaved edit. It must move NOTHING and it must
# name the cell and BOTH remedies, or it is a wall rather than a refusal.
file delete -force -- [rt_bak $rtchild]
rt_descend
set ::autosave_backup 0
xschem instance $rtpinsym 300 300 0 0 {name=pdirty lab=DIRTY}
set rt6pre [list [xschem get currsch] [xschem get modified] [xschem get instances]]
set rt6rc [catch {ase::with_design_current $rttop {rt_where}} rt6msg]
check "RT6 A3 row 3: a MODIFIED entry buffer with autosave backup off is\
 refused before anything moves, and the sentence names the cell, issue 0626 and\
 both ways out (save it, or turn the option on)" \
  [list $rt6pre $rt6rc [xschem get currsch] [xschem get instances] \
        [rg_has $rt6msg {rt_child.sch}] [rg_has $rt6msg {0626}] \
        [rg_has $rt6msg {Save this cell}] \
        [rg_has $rt6msg {Options > Autosave backup}]] \
  [list {1 1 2} 1 1 2 1 1 1 1]
note "RT6 the refusal" $rt6msg

# --- RT7: A3 row 2 -- modified + autosave ON: CARRIED ------------------------
# op_annot only ever REFUSES here, because its walk never pops its entry level
# and go_back's load_backup_as restores its entry buffer for it. This trip POPS
# the entry level and returns by `descend`, and descend_schematic() uses plain
# load_schematic() -- NOT load_backup_as(). So the edit comes back only because
# of the explicit `xschem load_backup` (scheduler.c:7948). Refusing instead
# would have left a user with one unsaved tweak unable to press Run at all
# (DECISIONS.md D4).
set ::autosave_backup 1
rt_descend
set ::autosave_backup 1
xschem instance $rtpinsym 300 300 0 0 {name=pdirty lab=DIRTY}
set rt7pre [list [xschem get currsch] [xschem get modified] [xschem get instances]]
set rt7bak [file exists [rt_bak $rtchild]]
set rt7rc [catch {ase::with_design_current $rttop {rt_where}} rt7res]
check "RT7 A3 row 2: a MODIFIED entry buffer with autosave backup on is\
 CARRIED -- the script still runs at the design, and the person comes back to\
 the same level with the edit still in the buffer AND still flagged modified,\
 because `xschem load_backup` puts back what descend's load_schematic dropped" \
  [list $rt7pre $rt7bak $rt7rc $rt7res [xschem get currsch] \
        [file tail [xschem get schname]] [xschem get instances] \
        [xschem get modified] $::autosave_backup] \
  [list {1 1 2} 1 0 {0 rt_top.sch} 1 rt_child.sch 2 1 1]
file delete -force -- [rt_bak $rtchild]

# --- RT8: the entry READ-ONLY state survives the trip ------------------------
# src/cadence_style_rc:564 sets descend_readonly 1, so in the setup this user
# runs EVERY descended level is a read-only browse buffer (actions.c:6410) and
# set_modify(1) is suppressed there. Rows RT6/RT7 are only reachable after a
# Ctrl-2, and once someone HAS done that the trip must give the flag back: the
# final `descend` re-applies descend_readonly. MEASURED before the snapshot was
# added, on the real bench: the carried edits came back (correct) while
# `modified` came back 0, because load_backup_as' set_modify(1) landed on a
# buffer the re-descend had just made read-only again -- one close-without-
# prompt away from losing the edit a second time. PLAN.md A3/A4 do not mention
# this; it was found by measuring.
set ::descend_readonly 1
xschem load $rttop
xschem unselect_all
xschem descend -fallback -inst x1
set rt8ro [xschem get readonly]
xschem set readonly 0
ase::with_design_current $rttop {rt_where}
set rt8after [xschem get readonly]
xschem load $rttop
xschem unselect_all
xschem descend -fallback -inst x1
set rt8keep [xschem get readonly]
ase::with_design_current $rttop {rt_where}
set rt8keep2 [xschem get readonly]
set ::descend_readonly 0
check "RT8 the trip restores the ENTRY read-only state, in both directions: a\
 buffer the person had made editable comes back editable (or its restored edits\
 could never be flagged modified), and a browse buffer comes back read-only" \
  [list $rt8ro $rt8after $rt8keep $rt8keep2] {1 0 1 1}

# --- RT9: a design that is nowhere -------------------------------------------
rt_descend
set rt9c [xschem get currsch]
set rt9rc [catch {ase::with_design_current \
             [file join $scratch aselib nfet_clean schematic nfet_clean.sch] \
             {rt_where}} rt9msg]
check "RT9 a design that is not on this window's stack raises the minted head\
 and moves NOTHING -- no park, no go_back, no descend" \
  [list $rt9rc $rt9msg [xschem get currsch] [file tail [xschem get schname]]] \
  [list 1 {ase: design nfet_clean.sch is not open in this window} $rt9c rt_child.sch]

# --- RT10: a re-descend that cannot complete ---------------------------------
# Silence here strands a person part-way down their own hierarchy with no idea
# why the sheet changed, so the sentence has to name the instance AND where they
# are now. Driven at ase::hier_redescend directly: the failure it exists for is
# a sheet that no longer holds the instance the person came through, and a name
# that was never there is the same accident.
xschem load $rttop
set rt10rc [catch {ase::hier_redescend {no_such_inst} 1} rt10msg]
check "RT10 a re-descend into an instance that is not there raises, names the\
 instance, and says WHERE the person was left" \
  [list $rt10rc [rg_has $rt10msg {no_such_inst}] \
        [rg_has $rt10msg {rt_top.sch}] [rg_has $rt10msg {level 0}] \
        [xschem get currsch]] \
  {1 1 1 1 0}
note "RT10 the stranded sentence" $rt10msg

# --- RT11: ase::netlist's four arms, BY WHICH ONE RAN ------------------------
# The body is stubbed so this row measures the DISPATCH and nothing else -- and
# so it measures the same thing in both arms of the suite, which is the only way
# a `::has_x` decision can be tested headless at all. `ase::netlist_in_place`
# records the level and sheet it was called at, which is the whole precondition
# the split exists to guarantee (and the precondition
# ase::op_cards_capture inherits, issue 0436 -- it stays INSIDE that body).
## ⚠ EIGHT `tcleval(): ... sim_is_ngspice failed / invalid command name "winfo"`
## LINES ON STDERR ARE THIS ROW'S, HEADLESS ONLY, AND THEY ARE NOT A FAILURE.
## Faking ::has_x makes set_sim_defaults (src/xschem.tcl:4259 -> sim_is_ngspice)
## take its Tk path, and the trip's final `xschem redraw` evaluates floaters,
## which asks token.c:6461 that question. C's own has_x is still 0, so there is
## no Tk to answer with. Nothing asserts on it, nothing reddens, and under X the
## fake is a no-op because ::has_x is already there. Recorded rather than
## silenced: a suite that swallowed its own stderr would hide the next real one.
proc rt_as_gui {script} {
  set had [info exists ::has_x]
  if {!$had} { set ::has_x 1 }
  set rc [catch {uplevel 1 $script} res opts]
  if {!$had} { catch {unset ::has_x} }
  return -options $opts $res
}
proc rt_as_headless {script} {
  set had [info exists ::has_x]
  if {$had} { set saved $::has_x ; catch {unset ::has_x} }
  set rc [catch {uplevel 1 $script} res opts]
  if {$had} { set ::has_x $saved }
  return -options $opts $res
}
rename ase::netlist_in_place ase::rt_saved_nip
proc ase::netlist_in_place {state cell} {
  lappend ::rt_nip [list [xschem get currsch] [file tail [xschem get schname]] $cell]
  return STUBBED
}
set rtst [ase::state_default]
dict set rtst design {lib aselib cell rt_top view schematic}
dict set rtst rundir [file join $scratch rtrun]
# (a) the design already IS current
xschem load $rttop
set ::rt_nip {}
set rt11a [list [ase::netlist $rtst] $::rt_nip]
# (b) headless: self-load, unchanged behaviour -- from ONE LEVEL DOWN, which is
#     where a script has no window to clobber and no person to put back
rt_descend
set ::rt_nip {}
set rt11b [list [rt_as_headless {ase::netlist $rtst}] $::rt_nip [xschem get currsch]]
# (c) THE NEW ARM: a display, and the design is on this window's own stack
rt_descend
set ::rt_nip {}
set rt11c [list [rt_as_gui {ase::netlist $rtst}] $::rt_nip \
                [xschem get currsch] [file tail [xschem get schname]]]
# (d) a display, and the design is genuinely nowhere
set rtst2 [dict replace $rtst design {lib aselib cell nfet_clean view schematic}]
xschem load $rttop
set ::rt_nip {}
set rt11d [list [catch {rt_as_gui {ase::netlist $rtst2}} rt11msg] $::rt_nip]
rename ase::netlist_in_place {}
rename ase::rt_saved_nip ase::netlist_in_place
check "RT11 all four arms of ase::netlist, measured by WHERE the body actually\
 ran: current -> in place; headless -> self-load to the top (unchanged); a\
 display with the design on this stack -> the ROUND TRIP, body at the design,\
 person back at level 1; nowhere -> refused with no body call at all" \
  [list $rt11a $rt11b $rt11c $rt11d] \
  [list {STUBBED {{0 rt_top.sch rt_top}}} \
        {STUBBED {{0 rt_top.sch rt_top}} 0} \
        {STUBBED {{0 rt_top.sch rt_top}} 1 rt_child.sch} \
        {1 {}}]

# --- RT12: the minted refusal (batch decision D6) ----------------------------
# ⚠ THE SHIPPED SENTENCE IS THE WHOLE COMPLAINT. "ase: design ... is not the
# current schematic; open its design window first (Session > Design Window)"
# told the user to do the thing they had already done, because the guard could
# not tell "the design is elsewhere" from "the design is open and you are
# standing inside it". It must not come back, in any spelling.
check "RT12 D6: ONE minted head for `the design is not on this window's stack`,\
 with the remedy chosen by the caller -- and the shipped `is not the current\
 schematic` wording is gone from the sentence the doors say" \
  [list [ase::design_unreachable_msg aselib/rt_top] \
        [ase::design_unreachable_msg aselib/rt_top {open it via Session > Design Window first}] \
        [rg_has $rt11msg {is not the current schematic}] \
        [rg_has $rt11msg {Session > Design Window}] \
        [rg_has [rg_body ase::netlist] {is not the current schematic}]] \
  [list {ase: design aselib/rt_top is not open in this window} \
        {ase: design aselib/rt_top is not open in this window; open it via Session > Design Window first} \
        0 1 0]
note "RT12 the surviving refusal" $rt11msg
xschem load $rttop

# --- DX: WHAT ALREADY WORKS TWO LEVELS DOWN, PINNED --------------------------
# doc/claude/descend_run_batch/PLAN.md item C, CREW_BRIEF section 3.
#
# ⚠ NOTHING IN THIS SECTION IS A FIX. Every row here is a PIN on behaviour the
# tree already has and that items A and B must not have disturbed -- the driver
# first believed the annotation basis was broken at depth, measured it, and
# found it correct (DECISIONS.md D1). A pin with no teeth is worse than no pin,
# so each row below carries its own negative control: the same call made the
# other way must give the OTHER answer, or the row could pass on a constant.
#
#   DX0  the fixture really reproduces the report: three levels, `sch_path`
#        `.x1.x1.`, standing on the leaf, and the design is a registered
#        cellview so a session can bind to it
#   DX1  from two levels down, ase::session_for_current answers the DESIGN's
#        own level (0) and ase::ui::design_window finds the DESCENDED window
#        without moving the person out of it
#   DX2  THE PIN: op_annot::db_attach with that level stamps the raw at the
#        design (raw_level 0), the hierarchy prefix is the two-component
#        `x1.x1.`, the device path carries it, and the numbers render
#   DX3  THE NEGATIVE CONTROL, i.e. "the bare door": the SAME file attached
#        with no level stamps at currsch, the prefix is empty, the device path
#        loses the hierarchy and the block paints BLANK
#   DX4  the end-to-end descended netlist is BYTE-IDENTICAL to one taken at
#        the top, and the person comes back to the same level and sheet
#   DX5  ...and that is not free: the netlist a person standing there gets
#        WITHOUT the round trip is the leaf alone. This is the defect the
#        shipped guard existed to prevent (CREW_BRIEF section 1)
#   DX6  ase::netlist's arm (c) IS that composition, read off its own body
#   DX7  the real ase::netlist called from two levels down, end to end
#
# ⚠ WHY THE ANNOTATION FIXTURE CARRIES ITS OWN DEVICE TYPE. op_annot builds a
# device path through the descriptor registered for the symbol's `type=` token,
# and the ONE seam where the hierarchy enters that path is the third argument a
# descriptor's devproc receives -- sim_sch_path. A fixture whose devproc returns
# a constant cannot see a wrong level at all (the note above H1 in
# test_annot_hier_0911.tcl says so about the same trap), so `dxs8fet` gets a
# hierarchy-aware devproc and the rows read the built path, not just the getter.
#
# ⚠ AND THE RAW IS WRITTEN HERE, IN THE SCRATCH TREE. Never
# ~/.xschem/simulations/ -- that directory holds the user's own bench results
# and this suite has no business reading, let alone overwriting, them. No
# simulator is run: an operating point is three numbers in a text file.
set dxdir [file join $scratch aselib]
proc dx_wr {p txt} {
  file mkdir [file dirname $p]
  set fh [open $p w]
  puts -nonewline $fh $txt
  close $fh
}
## the descendable box, twice -- `type=subcircuit` is what makes `descend` work
set dx_boxsym {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {type=subcircuit
format="@name @pinlist @symname"
template="name=x1"
}
V {}
S {}
E {}
B 5 -82.5 -2.5 -77.5 2.5 {name=A dir=inout}
L 4 -80 0 -40 0 {}
L 4 -40 -20 40 -20 {}
L 4 40 -20 40 20 {}
L 4 40 20 -40 20 {}
L 4 -40 20 -40 -20 {}
T {@symname} -38 -6 0 0 0.3 0.3 {}
T {@name} -5 -32 0 0 0.2 0.2 {}
}
dx_wr [file join $dxdir dx_mid  symbol dx_mid.sym]  $dx_boxsym
dx_wr [file join $dxdir dx_leaf symbol dx_leaf.sym] $dx_boxsym
## the annotated device. Its own type token, so registering a descriptor for it
## cannot shadow a PDK's `nmos` for any row above (op_annot.tcl's `match` key
## exists for exactly that collision).
dx_wr [file join $dxdir dx_fet symbol dx_fet.sym] {v {xschem version=3.4.7RC file_version=1.2}
G {}
K {type=dxs8fet
format="@name @pinlist @model"
template="name=MZZ1 model=dxdev"
}
V {}
S {}
E {}
B 5 -22.5 -2.5 -17.5 2.5 {name=D dir=inout}
L 4 -20 0 0 0 {}
L 4 -10 -10 10 -10 {}
L 4 10 -10 10 10 {}
L 4 10 10 -10 10 {}
L 4 -10 10 -10 -10 {}
}
## the design: a source and a testbench net the leaf has never heard of, so the
## deck taken at the top and the deck taken at the leaf CANNOT be confused
dx_wr [file join $dxdir dx_top schematic dx_top.sch] \
{v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 200 -100 280 -100 {}
C {aselib/dx_mid} 360 -100 0 0 {name=x1}
C {devices/lab_wire} 220 -100 0 0 {name=lT lab=TNET}
C {devices/vsource} 200 -60 0 0 {name=V1 value=1.8}
C {devices/gnd} 200 -20 0 0 {name=GND1 lab=GND}
}
dx_wr [file join $dxdir dx_mid schematic dx_mid.sch] \
{v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 200 -100 280 -100 {}
C {aselib/dx_leaf} 360 -100 0 0 {name=x1}
C {devices/ipin} 200 -100 0 0 {name=pA lab=A}
}
dx_wr [file join $dxdir dx_leaf schematic dx_leaf.sch] \
{v {xschem version=3.4.7RC file_version=1.2}
G {}
K {}
V {}
S {}
E {}
N 200 -100 280 -100 {}
C {devices/ipin} 200 -100 0 0 {name=pA lab=A}
C {aselib/dx_fet} 300 -100 0 0 {name=MZZ1}
}
## the hierarchy-aware devproc (see the warning above) and its descriptor
proc dx_devproc {instname model path spiceprefix} { return "@m.${path}mzz" }
catch {op_annot::register dxs8fet \
  [list devproc dx_devproc params {{id id 0} {gm gm 1} {gds gds 1}}]}

set dxtop [file normalize [xschem cellview_path aselib/dx_top schematic]]
## Stand where the user stood: "I descend into x1 and again x1."
proc dx_descend {} {
  xschem load $::dxtop
  xschem unselect_all ; xschem descend -fallback -inst x1
  xschem unselect_all ; xschem descend -fallback -inst x1
  return [list [xschem get currsch] [xschem get sch_path] \
               [file tail [xschem get schname]]]
}
set ::dxtop $dxtop
## one operating point over one device, named as a run FROM THE TOP names it
proc dx_mkop {path dev} {
  set fh [open $path w]
  puts -nonewline $fh "Title: descend_run_batch item C fixture
Date: Mon Jan 1 00:00:00 2026
Plotname: Operating Point
Flags: real
No. Variables: 3
No. Points: 1
Variables:
\t0\ti($dev\[id\])\tcurrent
\t1\t$dev\[gm\]\tadmittance
\t2\t$dev\[gds\]\tadmittance
Values:
0\t1.000000e-05
\t1.000000e-04
\t1.000000e-06
"
  close $fh
}
## what the sheet would paint for the annotated device, as one line
proc dx_rows {} {
  set r {}
  catch {set r [::op_annot::text MZZ1]}
  set r [string map [list "\n" { | }] [string trim $r]]
  regsub -all { +} $r { } r
  return $r
}
## byte-for-byte, in-process: 1 identical, 0 different, -1 unreadable
proc dx_same {a b} {
  if {![file isfile $a] || ![file isfile $b]} { return -1 }
  set fa [open $a rb] ; set x [read $fa] ; close $fa
  set fb [open $b rb] ; set y [read $fb] ; close $fb
  return [expr {$x eq $y ? 1 : 0}]
}
proc dx_grep {f needle} {
  if {![file isfile $f]} { return -1 }
  set fh [open $f r] ; set t [read $fh] ; close $fh
  return [expr {[string first $needle $t] >= 0 ? 1 : 0}]
}

# --- DX0: the fixture is the report ------------------------------------------
set dx0 [dx_descend]
check "DX0 the fixture reproduces the report -- three levels, sch_path .x1.x1.,\
 standing on the leaf -- and the DESIGN resolves to a registered cellview a\
 session can bind to" \
  [list $dx0 [catch {ase::design_of_path $dxtop} dx0d] $dx0d \
        [file tail [xschem get schname 0]]] \
  [list {2 .x1.x1. dx_leaf.sch} 0 {aselib dx_top schematic} dx_top.sch]

# --- DX1: the session and the design window, from two levels down ------------
# ⚠ ase::ui::design_window IS IN THE ROW ON PURPOSE. It is the second half of
# the user's own gesture ("... and then, Session Design Window so that the
# schematic is linked to that ASE-L"), and it is the proc CREW_BRIEF section 6
# names as the repair for the second-window trap. What it must NOT do here is
# re-open the design somewhere else: raise_design_editor's SECOND scan
# (src/ase_window.tcl, `xschem windows` field 6, the window's hierarchy stack)
# is what sees a window that is standing INSIDE the design -- issue 0168's
# HL23-HL25 -- and without it this row would come back at level 0 with the
# person's navigation thrown away.
set dxkey [ase::new_session aselib dx_top schematic]
set dx1sfc [ase::session_for_current]
set dx1dw [catch {ase::ui::design_window $dxkey} dx1r]
check "DX1 two levels down, ase::session_for_current answers the DESIGN's own\
 level and ase::ui::design_window finds the DESCENDED window -- it does not\
 re-open the design at level 0 and throw the navigation away" \
  [list $dx1sfc $dx1dw $dx1r [xschem get currsch] [xschem get sch_path] \
        [file tail [xschem get schname]]] \
  [list [list $dxkey 0 aselib dx_top schematic] 0 1 2 .x1.x1. dx_leaf.sch]

# --- DX2/DX3: THE PIN, AND ITS NEGATIVE CONTROL ------------------------------
# The annotation door passes a LEVEL:
#   ase::ui::annot_ensure_loaded -> level from ase::session_for_current
#     -> op_annot::db_attach $path $level
#       -> xschem annotate_op $np $level
#         -> src/scheduler.c  raw->level = level ; raw->schname = sch[level]
# so `Simulation > Run` pressed while descended does NOT annotate blanks. That
# is the claim these two rows exist to keep true. DX3 is the SAME file through
# the SAME proc with the level withheld -- the "bare door" the driver first
# measured and mistook for the shipped behaviour -- and it must give the other
# answer in all four columns or DX2 is passing on a constant.
set dxraw [file join $scratch dx_top_ase.raw]
dx_mkop $dxraw {@m.x1.x1.mzz}
set dxlvl [lindex [ase::session_for_current] 1]
catch {xschem raw clear}
set dx2att [::op_annot::db_attach $dxraw $dxlvl]
check "DX2 THE PIN: the results file attached with the level the session\
 reports is stamped at the DESIGN (raw_level 0), the hierarchy prefix is the\
 two-component x1.x1., the device path carries it and the numbers render" \
  [list $dxlvl $dx2att [xschem get raw_level] [xschem get sim_sch_path] \
        [::op_annot::devpath MZZ1] [dx_rows]] \
  [list 0 {1 {}} 0 {x1.x1.} {@m.x1.x1.mzz} {id = 10u | gm = 100u | gds = 1u}]
catch {xschem raw clear}
set dx3att [::op_annot::db_attach $dxraw {}]
check "DX3 the NEGATIVE CONTROL, the bare door: the SAME file attached with no\
 level stamps at currsch, the prefix is empty, the device path loses the\
 hierarchy and the block paints BLANK -- so DX2 cannot pass on a constant" \
  [list $dx3att [xschem get raw_level] [xschem get sim_sch_path] \
        [::op_annot::devpath MZZ1] [dx_rows]] \
  [list {1 {}} 2 {} {@m.mzz} {id = | gm = | gds =}]
catch {xschem raw clear}

# --- DX4: THE END-TO-END DESCENDED NETLIST -----------------------------------
# ⚠ DRIVEN AT `with_design_current` + `netlist_in_place`, WHICH IS EXACTLY WHAT
# ase::netlist's ARM (c) IS -- DX6 reads that off the product's own body so the
# composition here cannot drift from it. Not through ase::netlist itself,
# because that arm is chosen on `[info exists ::has_x]` and a headless suite
# that FAKES ::has_x to reach it breaks the netlister it is trying to run:
# set_sim_defaults asks `winfo exists .sim` (src/xschem.tcl) the moment ::has_x
# is set, a --nogui process has no winfo at all, and sim_is_xyce -> the `netlist`
# Tcl proc -> `ase: netlist not produced` (MEASURED, 2026-09-08). DX7 runs the
# real dispatch in whichever arm can honestly reach it.
set dxst [ase::state_default]
dict set dxst design {lib aselib cell dx_top view schematic}
set dxst_top  [dict replace $dxst rundir [file join $scratch dxnl_top]]
set dxst_trip [dict replace $dxst rundir [file join $scratch dxnl_trip]]
set dxst_full [dict replace $dxst rundir [file join $scratch dxnl_full]]
xschem load $dxtop
set dx4rc0 [catch {ase::netlist $dxst_top} dxnl_top]
dx_descend
set dx4rc [catch {ase::with_design_current $dxtop \
             [list ase::netlist_in_place $dxst_trip dx_top]} dxnl_trip]
check "DX4 the end-to-end DESCENDED netlist is BYTE-IDENTICAL to one taken at\
 the top, and the person comes back to the same level, the same sheet and the\
 same sch_path" \
  [list $dx4rc0 $dx4rc [dx_same $dxnl_top $dxnl_trip] \
        [file tail $dxnl_trip] [xschem get currsch] [xschem get sch_path] \
        [file tail [xschem get schname]]] \
  [list 0 0 1 dx_top.spice 2 .x1.x1. dx_leaf.sch]
note "DX4 netlist bytes, top vs descended" \
  [list [file size $dxnl_top] [file size $dxnl_trip]]

# --- DX5: what a person standing there gets WITHOUT the round trip -----------
# global_spice_netlist() netlists xctx->sch[xctx->currsch] -- the level you are
# STANDING ON (src/spice_netlist.c). This row is the reason the shipped guard
# existed and the reason items A/B replaced it rather than deleting it: the deck
# taken two levels down is the LEAF, with no source, no testbench net and no
# design subckt in it, and it looks perfectly healthy.
dx_descend
set dxbare [file join $scratch dxnl_bare dx_top.spice]
file mkdir [file dirname $dxbare]
xschem netlist -noalert $dxbare
check "DX5 ...and it is not free: the netlist a person gets WITHOUT the round\
 trip is the LEAF ALONE -- different bytes, no design subckt, no testbench net,\
 no source. This is what the shipped guard existed to prevent" \
  [list [dx_same $dxnl_top $dxbare] [dx_grep $dxbare {dx_leaf}] \
        [dx_grep $dxbare {dx_mid}] [dx_grep $dxbare {TNET}] \
        [dx_grep $dxbare {V1}] [dx_grep $dxnl_top {TNET}] \
        [dx_grep $dxnl_top {V1}]] \
  [list 0 1 0 0 0 1 1]
note "DX5 netlist bytes, top vs bare-at-depth" \
  [list [file size $dxnl_top] [file size $dxbare]]

# --- DX6: arm (c) IS that composition ----------------------------------------
# DX4 composes two procs by hand; this row is what keeps that composition
# honest. If someone re-spells arm (c) -- a different helper, a different order,
# a save/restore instead of the trip -- DX4 would keep passing about code the
# product no longer runs, and this row is the one that goes red.
set dx6b [rg_body ase::netlist]
check "DX6 ase::netlist's arm (c) IS the composition DX4 drives: one line that\
 hands ase::netlist_in_place to ase::with_design_current, guarded by\
 ase::stack_level" \
  [list [rg_has $dx6b {ase::with_design_current}] \
        [rg_has $dx6b {ase::netlist_in_place $state $cell}] \
        [rg_has $dx6b {ase::stack_level $path}] \
        [rg_has $dx6b {is not the current schematic}]] \
  {1 1 1 0}

# --- DX7: the real ase::netlist, from two levels down ------------------------
# ⚠ ONE ROW, TWO PREMISES, BY DESIGN -- and they are the product's own two
# contracts, not a convenience. ase::netlist's header says arm (b) comes BEFORE
# arm (c) deliberately: headless there is no window to clobber and no person to
# put back, so a script gets `xschem load` and a person in a GUI window gets the
# round trip. So the SAME call from the SAME place is asserted against the arm
# that is real in the arm of the suite that is running -- and the netlist is
# byte-identical to the top's either way, which is the half both contracts share.
dx_descend
set dx7gui [info exists ::has_x]
set dx7rc [catch {ase::netlist $dxst_full} dx7nl]
set dx7cmp -1
if {!$dx7rc} { set dx7cmp [dx_same $dxnl_top $dx7nl] }
if {$dx7gui} {
  check "DX7 the real ase::netlist called two levels down (a display: arm (c),\
 the round trip) produces the design's deck byte-for-byte and leaves the person\
 where they were standing" \
    [list $dx7rc $dx7cmp [xschem get currsch] [xschem get sch_path] \
          [file tail [xschem get schname]]] \
    [list 0 1 2 .x1.x1. dx_leaf.sch]
} else {
  check "DX7 the real ase::netlist called two levels down (--nogui: arm (b),\
 the self-load, UNCHANGED behaviour) produces the design's deck byte-for-byte\
 from the top of the file" \
    [list $dx7rc $dx7cmp [xschem get currsch] [xschem get sch_path] \
          [file tail [xschem get schname]]] \
    [list 0 1 0 . dx_top.sch]
}
note "DX7 arm taken (1 = a display, arm (c); 0 = --nogui, arm (b))" $dx7gui

catch {xschem raw clear}
xschem load $dxtop


# ============================================================================
# AD. THE DIALOG DESCRIBES **THIS** SESSION'S SIMULATOR -- ISSUE 1408
# ============================================================================
#
# ⚠ THE DEFECT THESE ROWS FENCE WAS LIVE AND MEASURABLE, not theoretical. The
# Choose Analyses dialog asked `ase::analysis_offered` with NO ARGUMENT and
# `ase::analysis_entry [ase::default_simulator] $t` for the label, and
# chana_fields/arg_summary both defaulted `sim` to the default simulator. So a
# bench whose state says `simulator <anything else>` was shown NGSPICE's four
# analyses, a committable `dc` form, and an NGSPICE DECK LINE in the Arguments
# column -- `dc V2 0 1.8 0.01` -- for a simulator that cannot render it.
# The registry underneath was already right: `ase::analysis_offered zznoana`
# answered `{}` the whole time. Only the dialog never asked it.
#
# THESE ROWS ARE ARM-INDEPENDENT ON PURPOSE. They drive the SCHEMA half --
# ase::analysis_gap_msg and ase::analysis_commit_refusal -- so they run headless
# and cannot be lost to a display-arm skip the way issue 1405's G-block was.
# The widget half is test_ase_dialogs.tcl section G14.

## Three stand-ins, each isolating one arm.
##   zznoad    registers with the five hooks and NO `analysis_types` hook
##   zzunreg   HAS the hook, and every type it returns is `registered 0`
##   (a typo)  never registered at all -- and by 2d's own reckoning this is the
##             LIKELIER production case, because the only doors to a non-ngspice
##             `simulator` key are a hand-edited .state and the CIW.
proc ad_five {} {
  return [dict create \
    render_deck  [ase::backend_hook ngspice render_deck] \
    run_cmd      [ase::backend_hook ngspice run_cmd] \
    log_file     [ase::backend_hook ngspice log_file] \
    result_probe [ase::backend_hook ngspice result_probe] \
    raw_file     [ase::backend_hook ngspice raw_file]]
}
proc ad_unreg_types {} {
  return [dict create zzq [dict create label zzq registered 0 emitorder 10]]
}
ase::register_backend zznoad  [ad_five]
ase::register_backend zzunreg [dict merge [ad_five] [dict create analysis_types ad_unreg_types]]

## --- AD1: the KEYING INVARIANT, and it is the row that matters --------------
## ⚠ THE SENTENCE AND THE EMPTY GRID MUST ANSWER THE SAME QUESTION. An earlier
## shape keyed the sentence on `ase::analysis_types` and the dialog's disable
## block on `ase::analysis_offered`; for `zzunreg` -- a backend that DECLARES a
## type and REGISTERS none -- the two disagree, and the user gets a wholly
## blank, dead, SILENT dialog. D6's rule is four states and never invisible.
## This row asserts the biconditional directly, over every simulator in play.
set AD1 {}
foreach adsim {ngspice zznoad zzunreg zznosuchsim} {
  lappend AD1 [list [expr {[ase::analysis_offered $adsim] eq {}}] \
                    [expr {[ase::analysis_gap_msg $adsim] ne {}}]]
}
check "AD1 a sentence is said EXACTLY when the grid is empty -- never a blank\
 dialog that says nothing, and never a sentence over a working grid" \
  $AD1 {{0 0} {1 1} {1 1} {1 1}}

## --- AD2: THREE ARMS, AND THEY ARE DIFFERENT FACTS ---------------------------
## "ASE-L has no adapter for this simulator yet" ASSERTS THE SIMULATOR EXISTS.
## Said to someone who typed `ngspce`, that is wrong twice over: it blames ASE-L
## and it confirms a simulator that is not there. The distinguishing fact was
## already in the tree and unused -- ase::backend_names.
check "AD2 the three empty-grid reasons are three different sentences: an unknown\
 backend, a registered one with no adapter, and an adapter offering nothing" \
  [list [expr {[string first {does not know a simulator backend} [ase::analysis_gap_msg zznosuchsim]] >= 0}] \
        [expr {[string first {has no adapter}                    [ase::analysis_gap_msg zznoad]] >= 0}] \
        [expr {[string first {lists no analyses}                 [ase::analysis_gap_msg zzunreg]] >= 0}] \
        [expr {[ase::analysis_gap_msg zznoad] eq [ase::analysis_gap_msg zzunreg]}]] \
  {1 1 1 0}

## --- AD3: the unknown-backend sentence NAMES what IS registered -------------
check "AD3 the unknown-backend sentence names the typed name and lists what IS\
 registered, so the user can see their typo" \
  [list [expr {[string first {'zznosuchsim'} [ase::analysis_gap_msg zznosuchsim]] >= 0}] \
        [expr {[string first {ngspice} [ase::analysis_gap_msg zznosuchsim]] >= 0}]] \
  {1 1}

## --- AD4: the commit refusal, minted ONCE for three doors -------------------
check "AD4 a commit door refuses with the gap sentence when nothing is selected,\
 and names the type when one is" \
  [list [expr {[string first {has no adapter} [ase::analysis_commit_refusal zznoad {}]] >= 0}] \
        [ase::analysis_commit_refusal zznoad pss] \
        [expr {[string range [ase::analysis_commit_refusal zznoad {}] 0 4] eq {ase: }}]] \
  [list 1 {ase: 'zznoad' cannot run pss, so it was not added to the bench.} 1]

## --- AD5: NO SECOND COPY OF THE DEFAULTING RULE ------------------------------
## ⚠ `ase::analysis_offered` and `ase::analysis_types` ALREADY resolve an empty
## simulator to ase::default_simulator. A `$sim eq {}` arm inside the gap message
## would be a SECOND copy of that rule and a second place for it to drift -- the
## exact defect Stage 1 spent itself deleting. The first element proves the empty
## argument really does reach the default; the second is the non-vacuity control,
## proving the proc distinguishes simulators at all.
check "AD5 an empty simulator argument resolves the same way everywhere, with no\
 second copy of the defaulting rule living in the gap message" \
  [list [expr {[ase::analysis_gap_msg {}] eq [ase::analysis_gap_msg [ase::default_simulator]]}] \
        [expr {[ase::analysis_gap_msg zznoad] ne [ase::analysis_gap_msg {}]}]] \
  {1 1}

## --- AD6: the PRESELECT is the first OFFERED type, and for ngspice that is op
## ⚠ PINNED SO A REGISTRY EDIT SURFACES AS A NAMED RED HERE, rather than as an
## unexplained failure in a dialog suite that run_regression.tcl does not run on
## either arm. The dialog preselects `[lindex $offered 0]` instead of the literal
## `op`, which is what stops an empty grid committing `{type op enabled 1}` to a
## bench whose backend cannot render `op`.
check "AD6 the first analysis this backend offers is op, which is what the dialog\
 preselects -- and a backend offering nothing preselects nothing" \
  [list [lindex [ase::analysis_offered ngspice] 0] \
        [lindex [ase::analysis_offered zznoad] 0]] \
  {op {}}

## --- AD7: the Arguments column under a simulator with no adapter ------------
## ⚠ THE `op` ROW GOES BLANK, AND THAT IS RECORDED HERE AS A RATIFIED
## CONSEQUENCE RATHER THAN DISCOVERED LATER. arg_summary's dump arm emits the
## empty string for a row with no field keys and no extra keys, and `op` -- the
## one analysis every new bench opens ENABLED -- is exactly that row. Under
## ngspice the column holds the emitted deck line; under a simulator ASE-L has no
## adapter for there is no deck line to show, and the Type column already says
## `op`, so the blank removes a redundant echo rather than information. The
## control is the `dc` row, which keeps its key=value dump.
proc ad_pane {sim} {
  set out {}
  foreach r {{type op enabled 1} {type dc enabled 0 source V2 start 0 stop 1.8 step 0.01}} {
    lappend out [ase::ui::arg_summary $r $sim]
  }
  return $out
}
check "AD7 the Arguments column shows this simulator's deck line, and for one\
 ASE-L has no adapter for it shows the stored keys -- with op, which has none,\
 going blank rather than echoing a line no backend emits" \
  [list [ad_pane ngspice] [ad_pane zznoad]] \
  [list {op {dc V2 0 1.8 0.01}} {{} {source=V2 start=0 stop=1.8 step=0.01}}]



# ============================================================================
# AG. THE FOUR-STATE RESOLVER -- ISSUE 1410
# ============================================================================
#
# Eleven analyses exist and ASE-L offered four. A user who cannot find an
# analysis in ADE-L has no way to learn why; this is the first place the design is
# plainly better -- FOUR STATES, NEVER INVISIBLE, each with a reason.
#
# ⚠ EVERY ROW PASSES `caps` AS AN ARGUMENT, so the resolver never fetches and no
# row here starts a program or needs a cache. The peek and Detect are section U of
# test_ase_simcaps_0948.tcl.

## A hermetic stand-in: two RENDERABLE types, one `baseline 1` and one `baseline 0`.
## ⚠ IT MUST BE RENDERABLE OR EVERY CELL READS `blocked` AND NO AVAILABILITY ARM
## IS EVER REACHED -- which is exactly what happens to ngspice's seven today, and
## is why the ngspice legs below assert 4+7 rather than the plan's predicted mix.
proc ag_types {} {
  return [dict create \
    zzbase [dict create label zzbase baseline 1 registered 1 emitorder 10 \
              emit {{role analysis tmpl {zzbase}}}] \
    zzgate [dict create label zzgate baseline 0 registered 1 emitorder 20 \
              emit {{role analysis tmpl {zzgate}}}]]
}
proc ag_caps {exe a w} { return {known 0} }
proc ag_five {} {
  return [dict create \
    render_deck  [ase::backend_hook ngspice render_deck] \
    run_cmd      [ase::backend_hook ngspice run_cmd] \
    log_file     [ase::backend_hook ngspice log_file] \
    result_probe [ase::backend_hook ngspice result_probe] \
    raw_file     [ase::backend_hook ngspice raw_file]]
}
ase::register_backend agprobe  [dict merge [ag_five] [dict create analysis_types ag_types capabilities ag_caps]]
ase::register_backend agnoprobe [dict merge [ag_five] [dict create analysis_types ag_types]]

## --- AG1: ELEVEN TYPES, AND `op` STILL FIRST --------------------------------
## ⚠ `op` FIRST IS PINNED HERE ON PURPOSE. The dialog preselects
## `[lindex $offered 0]` rather than the literal `op` (issue 1408), so a registry
## edit that reordered this list would silently move the preselect. Pinned in a
## suite run_regression.tcl DOES run, because it does not run test_ase_dialogs.
##
## ⚠ THIS LIST MOVED ONCE, IN Stage 5 (issue 1426), AND THE MOVE IS THE POINT:
## `tf` gained `emitorder 50` and left the rank-less tail for fifth place. The
## count is still eleven and `op` is still first. A type that becomes drivable
## is EXPECTED to move here; a type that moves without becoming drivable is a
## defect, which is what AG2 below separates.
## ⚠ THE SPLIT MOVES ONE PLACE PER STAGE-5 COMMIT AND THE ASSERTION DOES NOT.
## `tf` (issue 1426) put the boundary at five; `pz` (issue 1427) put it at six;
## `sens` (issue 1428) puts it at seven and is the LAST of Stage 5, so the next
## move belongs to Stage 6. What the row is about is unchanged: everything with
## an `emitorder` leads, in rank order, and everything without one follows in
## DECLARATION order.
## ⚠ AND `sens` OVERTOOK `noise` HERE, which is the half of its change that is
## visible in this row rather than in EM7's: in DECLARATION order `sens` sits
## after `noise`, and `emitorder 70` is what moves it in front.
check "AG1 the registry offers all eleven analyses, in emit order, with op first\
 -- which is what the dialog preselects" \
  [list [ase::analysis_offered ngspice] [lindex [ase::analysis_offered ngspice] 0]] \
  [list {op dc ac tran tf pz sens noise disto sp pss} op]

## --- AG2: A RANK-LESS ENTRY SORTS **LAST**, NOT FIRST -----------------------
## ⚠ `set r 0` for a missing `emitorder` made a rank-less type TIE WITH `op`,
## whose rank IS 0, and lead the row. The sentinel is above every real rank
## including the literal 90 `ase::analysis_emit_rank` returns for `op` under
## `op_last` (issue 0964), so a re-ranked `op` still cannot be displaced.
##
## ⚠ IT WAS SEVEN RANK-LESS TYPES, THEN SIX (Stage 5 `tf`, issue 1426), THEN
## FIVE (`pz`, issue 1427), AND IS NOW FOUR (`sens`, issue 1428). The row is
## split at SEVEN rather than six because `sens` earned a rank of 70; the
## assertion that matters is unchanged -- everything with a rank comes first, in
## rank order, and everything without one follows in declaration order.
check "AG2 the four types with no emit order sort after the seven that have one,\
 rather than tying with op at rank zero" \
  [list [lrange [ase::analysis_offered ngspice] 0 6] \
        [lrange [ase::analysis_offered ngspice] 7 end] \
        [ase::analysis_emit_rank op 1 ngspice]] \
  [list {op dc ac tran tf pz sens} {noise disto sp pss} 90]

## --- AG3: THE SEED DID NOT MOVE, AND THAT IS ⚖ R4 SHIPPING BY CONSTRUCTION ---
## Before the one-line `continue` this proc appended a row for EVERY registered
## type, so registering seven more would have grown state_default from four rows
## to eleven and reddened R1 BY ACCIDENT -- the "this would change by accident"
## that made R4 a ruling rather than an edit.
check "AG3 a fresh bench still opens with exactly the four rows the 104 committed\
 state files carry, even though the registry now describes eleven types" \
  [ase::state_get [ase::state_default] analyses] \
  {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}

## --- AG4: AND THE SEED NEVER REACHES THE STATE-COMPUTING PROC ---------------
## ⚠ THIS IS A SHIM ROW BECAUSE A VALUE ROW CANNOT SEE THE DEFECT. If the seed
## called the resolver, membership and order would be BYTE-IDENTICAL -- the
## consequence is a DEPENDENCY, not a value: `ase::state_load` calls
## `state_default` for every file it merges over, so the seed would start
## depending on the capability cache. The shim makes the dependency itself fatal.
rename ase::analysis_states ase::ag_saved_states
proc ase::analysis_states {args} { error {seed must not consult the resolver} }
set AG4 [list [catch {ase::state_default} ag4e] \
              [ase::state_get [ase::state_default] analyses]]
rename ase::analysis_states {}
rename ase::ag_saved_states ase::analysis_states
check "AG4 building a fresh bench never consults the four-state resolver, so a\
 state file's load path cannot come to depend on the capability cache" \
  $AG4 \
  {0 {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 0}}}

## --- AG5: THE HONEST GRID FOR THIS TREE TODAY -------------------------------
## ⚠ FOUR `ok` AND SEVEN `blocked`, AND THE PLAN PREDICTED OTHERWISE. The
## renderable test sits ABOVE the availability arms deliberately: a type ASE-L
## cannot emit is `blocked` whatever the binary says, because offering it would
## produce a run that emits nothing. So the seven are LISTED -- the user can see
## they exist -- and blocked until Stage 6 gives them an `emit`.
set AG5 {}
foreach ag5 [ase::analysis_states ngspice {}] { lappend AG5 [lrange $ag5 1 2] }
check "AG5 the eleven cells are four offered on a source-verified invariant and\
 seven listed-but-not-yet-drivable, which is this tree's honest answer" \
  [list [lsort -unique $AG5] [llength $AG5]] \
  [list {{blocked unrenderable} {ok baseline}} 11]

## --- AG6: RENDERABLE IS TESTED **ABOVE** AVAILABILITY -----------------------
## Even a type the binary was MEASURED to have stays `blocked` while the adapter
## cannot emit it. Without this ordering the grid would offer a run that emits
## nothing, which is issue 1401's silent drop wearing a green cell.
check "AG6 a type this build was measured to HAVE is still blocked while the\
 adapter cannot emit it, because offering it would produce a run that emits nothing" \
  [ase::analysis_state ngspice pss \
     {known 1 analyses_available {pss} analyses_probed {pss}}] \
  {state blocked reason unrenderable}

## --- AG7: THE FIVE REASON TOKENS, PAIRWISE DISTINCT -------------------------
## ⚠ `unmeasured` VERSUS `noprobe` IS THE PAIR A READER WILL WANT TO COLLAPSE,
## AND COLLAPSING IT SHIPS A BUTTON THAT LIES. `unmeasured` is the token that
## carries Detect; for a backend with no `capabilities` hook Detect is a
## PERMANENT no-op, so the same cell needs a different sentence.
set AG7 [list \
  [lindex [ase::analysis_states agprobe   {}] 1 2] \
  [lindex [ase::analysis_states agnoprobe {}] 1 2] \
  [lindex [ase::analysis_states agprobe {known 1 analyses_available {zzbase} analyses_probed {zzbase zzgate}}] 1 2] \
  [lindex [ase::analysis_states agprobe {known 1 analyses_available {zzbase} analyses_probed {zzbase}}] 1 2] \
  [lindex [ase::analysis_states agprobe {known 1 analyses_available {zzbase zzgate} analyses_probed {zzbase zzgate}}] 1 2]]
check "AG7 the absent family is three distinct facts -- nobody measured and\
 something could, nobody measured and nothing ever can, and measured missing --\
 and a cache older than the type is none of them" \
  [list $AG7 [llength [lsort -unique $AG7]] \
        [expr {[llength [ase::analysis_reasons]] >= 6}]] \
  [list {unmeasured noprobe notpresent unmeasured measured} 4 1]

## --- AG8: AN ABSENT `baseline` DEFAULTS TO **0** ----------------------------
## ⚠ THE WHOLE POINT OF STAGE 1's CORRECTION C42. The key was `gated` and meant
## "an #ifdef could remove this"; renaming it to `baseline` FLIPPED what an absent
## key must mean. Defaulting the other way makes every unmeasured capability
## resolve `ok/baseline` and OFFERS ANALYSES NOBODY VERIFIED -- the inverse of
## this stage's stated worst outcome, one `dict exists` default away.
proc ag_nobase {} {
  return [dict create zznb [dict create label zznb registered 1 emitorder 10 \
            emit {{role analysis tmpl {zznb}}}]]
}
ase::register_backend agnobase [dict merge [ag_five] [dict create analysis_types ag_nobase capabilities ag_caps]]
check "AG8 a type whose entry does not claim to be in every build of its simulator\
 is NOT offered on that claim -- an absent baseline means no, never yes" \
  [ase::analysis_states agnobase {}] {{zznb absent unmeasured}}

## --- AG9: THE CAVEAT HOOK IS THE ONLY PRODUCER OF `caution` -----------------
## ⚠ AND AN UNMEASURED BUILD MUST NOT BE WARNED (D47). The clause asks
## `caps_measured_as`, so a binary nobody looked at gets no warning about a defect
## nobody looked for; `![caps_is ...]` would warn on every unmeasured build, which
## issue 1407's row P15 forbids outright.
check "AG9 a build measured to lack the one-pass operating-point dump is offered\
 with a caution, and a build nobody measured is offered with none" \
  [list [ase::analysis_state ngspice op \
           {known 1 altshow_op_dump 0 analyses_available {op} analyses_probed {op}}] \
        [ase::analysis_state ngspice op \
           {known 1 analyses_available {op} analyses_probed {op}}]] \
  [list {state caution reason caveat clause {this build cannot dump the operating point in one pass, so each device parameter is asked for separately -- the run is slower and the deck longer}} \
        {state ok reason measured}]

## --- AG10: THE `requires` PREDICATE, ALL FOUR ARMS -------------------------
## ⚠ THE `raised` ARM IS ASE-L's OWN CONTAINMENT, NOT A DECLARED ADAPTER REPLY
## (C39: a conforming adapter cannot produce a fourth answer). An out-of-vocabulary
## answer lands there too, so a NON-conforming adapter is contained rather than
## trusted -- and the schema's own predicate is called OUTSIDE that catch, or a
## fault in it would silently degrade every cell to `baseline`.
proc ag_req_present {caps} { return present }
proc ag_req_absent  {caps} { return absent }
proc ag_req_unknown {caps} { return unknown }
proc ag_req_garbage {caps} { return zznonsense }
proc ag_req_raises  {caps} { error boom }
check "AG10 an entry may answer the availability question itself, and ASE-L\
 contains an adapter that answers something it does not understand or blows up" \
  [list [ase::requires_state ag_req_present {} 0] \
        [ase::requires_state ag_req_absent  {} 0] \
        [ase::requires_state ag_req_unknown {} 1] \
        [ase::requires_state ag_req_unknown {} 0] \
        [ase::requires_state ag_req_garbage {} 1] \
        [ase::requires_state ag_req_raises  {} 1]] \
  [list {state ok reason measured} {state absent reason notpresent} \
        {state ok reason baseline} {state absent reason unmeasured} \
        {state caution reason requires_raised} {state caution reason requires_raised}]

## --- AG11: A RANK WITHOUT AN EMIT TEMPLATE IS NOT A RANK -------------------
## ⚠ MOVED UP TO THE RANK ON PURPOSE. An entry with `emitorder` and no `emit`
## used to pass `ase::preflight_gate` SILENTLY (measured: rc 0, empty verdict) and
## be caught only by render_deck's backstop, whose own comment calls itself a
## just-in-case. Stage 2 makes that case reachable seven times, so the answer
## belongs at the gate -- before a deck is written -- and the backstop goes back to
## being one.
proc ag_rank_noemit {} {
  return [dict create zzr [dict create label zzr baseline 1 registered 1 emitorder 10]]
}
ase::register_backend agrank [dict merge [ag_five] [dict create analysis_types ag_rank_noemit]]
set AG11ST [dict create simulator agrank analyses {{type zzr enabled 1}}]
check "AG11 a type that declares a position in the deck but no line to put there\
 is refused where the gate can say so, not discovered while the deck is written" \
  [list [ase::analysis_emit_rank zzr 0 agrank] \
        [ase::analysis_unrenderable $AG11ST] \
        [ase::analysis_renderable agrank zzr]] \
  [list {} zzr 0]

## --- AG12: `{}` IS A LEGAL caps VALUE, SO THE SENTINEL IS NOT `{}` ---------
## An empty dict MEANS "nothing measured", and a row must be able to drive that
## arm without the proc going off and peeking at a live cache.
check "AG12 an explicitly empty capability answer is honoured as a measurement of\
 nothing, and is not mistaken for the caller declining to say" \
  [list [ase::analysis_states agprobe {}] \
        [expr {[ase::analysis_states agprobe {}] eq [ase::analysis_states agprobe [dict create]]}]] \
  [list {{zzbase ok baseline} {zzgate absent unmeasured}} 1]

## --- AG13: A TYPE THIS SIMULATOR DOES NOT DESCRIBE GETS NO CELL ------------
## Not a fifth state and not an `absent` cell: `absent` is a fact about the user's
## BUILD, and nobody measured anything about a type the adapter never named.
check "AG13 a type this simulator does not describe contributes no cell at all,\
 rather than an absent one that would blame the build" \
  [list [ase::analysis_state ngspice zznosuchtype {}] \
        [llength [ase::analysis_states agprobe {}]]] \
  {{} 2}

## --- AG14: THE SEVEN CARRY NO `viewrank`, AND THIS ROW IS WHY -------------
## ⚠ IT COST A RED TO LEARN. `viewrank` is which analysis THE VIEWER PREFERS -- a
## claim about RESULTS -- and a type nothing can emit produces none. Giving the
## seven one made `ase::plot_sim_type` answer `noise` for a bench enabling only
## noise, so `plot_sim_type_reason` returned `{}` where row D7k asserts
## `no-viewer-mapping`. THE ROW WAS RIGHT AND THE REGISTRY WAS WRONG.
check "AG14 a type the adapter cannot emit expresses no preference about which\
 analysis the viewer should show, because it can never put data there" \
  [list [ase::plot_sim_type [dict create simulator ngspice analyses {{type noise enabled 1}}]] \
        [ase::plot_sim_type [dict create simulator ngspice analyses {{type op enabled 1}}]] \
        [dict exists [ase::analysis_entry ngspice noise] viewrank] \
        [dict exists [ase::analysis_entry ngspice op] viewrank]] \
  {{} op 0 1}

## --- AG15: THE PROBE WORD COMES FROM A `role probe` CARD -----------------
## ⚠ THE ROLE TAG DOING THE JOB IT WAS ADDED FOR, rather than a re-added `verb`
## key -- which Stage 1 deleted as two ngspice words in the schema half (C41). The
## card is invisible to `ase::analysis_line`, which selects `role analysis`, so the
## type stays unrenderable while the probe still gets a word to ask `help` with.
check "AG15 a type ASE-L cannot yet emit still carries a word the probe can ask\
 about, and that word is invisible to the deck" \
  [list [ase::analysis_card_tmpl ngspice pss] \
        [ase::analysis_card_tmpl ngspice pss probe] \
        [ase::analysis_line ngspice {type pss enabled 1}] \
        [ase::analysis_card_tmpl ngspice op] ] \
  [list {} pss {} op]

## --- AG16: MEMBERSHIP OF A FRESH BENCH IS DECLARING `seed_enabled` ---------
## ⚠ ONE KEY, NOT TWO. The plan proposed a second key, `seeded`, to gate
## membership while `seed_enabled` gated the tick -- and then had to explain what
## `seeded 0` with `seed_enabled 1` means. There is no such corner here: declaring
## the key puts the type in the seed and its value is the tick.
proc ag_seed_types {} {
  return [dict create \
    zzin  [dict create label zzin  baseline 1 registered 1 emitorder 10 seed_enabled 0 \
             emit {{role analysis tmpl {zzin}}}] \
    zzon  [dict create label zzon  baseline 1 registered 1 emitorder 20 seed_enabled 1 \
             emit {{role analysis tmpl {zzon}}}] \
    zzout [dict create label zzout baseline 1 registered 1 emitorder 30 \
             emit {{role analysis tmpl {zzout}}}]]
}
ase::register_backend agseed [dict merge [ag_five] [dict create analysis_types ag_seed_types]]
check "AG16 declaring the seed key is what puts a type on a new bench and its\
 value is only whether the tick starts on, so a type that declares nothing is\
 offered without joining every bench" \
  [ase::analysis_seed agseed] \
  {{type zzin enabled 0} {type zzon enabled 1}}



# ============================================================================
# EM. THE SLOT GRAMMAR AND THE EXPANDER -- ISSUE 1414
# ============================================================================
#
# Stage 3 of doc/claude/ase_analyses_batch/. The form stops lying: every value the
# window shows must reach the deck. This section fences the layer underneath that
# -- what a template slot means and what a skipped one emits.
#
# ⚠ EVERY FIXTURE REGISTERS ITS OWN BACKEND. The shipped ngspice registry is not
# touched, so D1, D8a-D8i, the 104 committed `.state` files and every deck golden
# are unmoved BY CONSTRUCTION rather than by hope. `ase::register_backend` calls
# `ase::analysis_cache_clear` (issue 1406), so a fixture registry is live at once.
# ⚠ A SABOTAGE THAT MUTATES NGSPICE'S OWN ENTRY IN PLACE MUST CALL
# `ase::analysis_cache_clear ngspice` EXPLICITLY, or it silently does nothing --
# which is the difference between a sabotage that reddens a row and one that
# proves nothing.

proc em_five {} {
  return [dict create \
    render_deck  [ase::backend_hook ngspice render_deck] \
    run_cmd      [ase::backend_hook ngspice run_cmd] \
    log_file     [ase::backend_hook ngspice log_file] \
    result_probe [ase::backend_hook ngspice result_probe] \
    raw_file     [ase::backend_hook ngspice raw_file]]
}
## ⚠ THE TEMPLATE CARRIES A LITERAL **AFTER** THE OPTIONAL SLOT, AND THAT IS WHY
## THE ROW CAN FAIL AT ALL. With the optional slot trailing, a body that emits an
## empty word and then trims produces a byte-identical answer -- the sabotage
## changes neither the string nor its length. A literal after it makes the empty
## word observable as the double space it really is.
proc em_types {} {
  return [dict create \
    emt [dict create label emt baseline 1 registered 1 emitorder 10 \
           fields {{name step kind time required 1} \
                   {name stop kind time required 1} \
                   {name tmax kind time} \
                   {name uic  kind bool when_true uic}} \
           emit {{role analysis tmpl {tran @step @stop @tmax? @uic! END}}}] \
    emf [dict create label emf baseline 1 registered 1 emitorder 20 \
           fields {{name lead kind real default LEADDEF} \
                   {name tail kind real required 1}} \
           emit {{role analysis tmpl {emf @lead? @tail}}}]]
}
ase::register_backend emsim [dict merge [em_five] [dict create analysis_types em_types]]

## --- EM1: A SKIPPED OPTIONAL SLOT EMITS **NOTHING** -------------------------
## ⚠ THE DEFECT THIS FENCES IS SILENT AND CHANGES THE PHYSICS. Joining an empty
## element gives `tran 1n 10u  0.2n` -- a DOUBLE SPACE -- and ngspice reads the
## next number as **tstart** rather than as tmax: rc 0, no message, and a
## different simulation. The literal `END` after the optional slot is what makes
## the empty word visible to this row.
check "EM1 a value the user did not give contributes NOTHING to the deck line,\
 rather than an empty word that shifts every value after it" \
  [list [ase::analysis_line emsim {type emt step 1n stop 10u}] \
        [ase::analysis_line emsim {type emt step 1n stop 10u tmax 0.2n}] \
        [ase::analysis_line emsim {type emt step 1n stop 10u tmax {}}]] \
  [list {tran 1n 10u END} {tran 1n 10u 0.2n END} {tran 1n 10u END}]

## --- EM2: A BOOL EMITS THE ADAPTER'S WORD, NEVER THE STORED VALUE ----------
## ⚠ MEASURED ON BOTH BINARIES: `uic 0` and `uic=0` BOTH TURN uic ON, silently --
## the token's PRESENCE is the truth and its value is ignored. So a bool that
## emitted its stored `0` would switch the feature ON while the form showed it
## OFF, which is this stage's own defect inverted.
check "EM2 a switch the user left off puts nothing in the deck, and one they\
 turned on puts the simulator's own word there rather than a number" \
  [list [ase::analysis_line emsim {type emt step 1n stop 10u uic 1}] \
        [ase::analysis_line emsim {type emt step 1n stop 10u uic 0}] \
        [ase::analysis_line emsim {type emt step 1n stop 10u}]] \
  [list {tran 1n 10u uic END} {tran 1n 10u END} {tran 1n 10u END}]

## --- EM3: THE WORD IS THE **ADAPTER'S**, NOT THE FIELD'S NAME --------------
## A schema that hard-coded "the field name is the word" could not express a
## simulator whose off-state needs a word of its own, and the word a simulator
## wants is CONTENT.
proc em_word_types {} {
  set d [em_types]
  dict set d emt fields {{name step kind time required 1} \
                         {name stop kind time required 1} \
                         {name tmax kind time} \
                         {name uic kind bool when_true ZZON when_false ZZOFF}}
  return $d
}
ase::register_backend emword [dict merge [em_five] [dict create analysis_types em_word_types]]
check "EM3 the word a switch puts in the deck is the simulator's, so a simulator\
 that needs a word for OFF can say one" \
  [list [ase::analysis_line emword {type emt step 1n stop 10u uic 1}] \
        [ase::analysis_line emword {type emt step 1n stop 10u uic 0}]] \
  [list {tran 1n 10u ZZON END} {tran 1n 10u ZZOFF END}]

## --- EM4: A REQUIRED SLOT STILL RAISES, AND THAT IS A CONTRACT -------------
## ⚠ Row Q2 of tests/headless/test_ase_simcaps_0948.tcl calls the expander with
## TWO arguments against each shipped template and asserts `{ok RAISES RAISES
## RAISES}` -- it is the row that proves a row-free reader was needed at all.
## Making the field table a mandatory third argument would turn its `ok` into a
## raise and redden the suite that owns the seam, for a reason unrelated to it.
check "EM4 asking for a deck line without a required value still fails loudly,\
 and the two-argument form every existing caller uses still works" \
  [list [catch {ase::analysis_expand {type emt} {tran @step @stop}}] \
        [catch {ase::analysis_expand {type emt step 1n stop 10u} {tran @step @stop}}] \
        [ase::analysis_expand {type emt step 1n stop 10u} {tran @step @stop}]] \
  [list 1 0 {tran 1n 10u}]

## --- EM5: A TEMPLATE WHOSE **FIRST** SLOT IS OPTIONAL ----------------------
## ⚠ EVERY SHIPPED TEMPLATE HAS A REQUIRED SLOT FIRST, so default semantics are
## unobservable against them: a wrong body still produces the right string. This
## fixture puts the optional slot FIRST, which is the only shape where a default
## that failed to apply is visible.
check "EM5 a value the adapter declared a default for is used when the user gave\
 none, even when it is the first thing on the line" \
  [list [ase::analysis_line emsim {type emf tail 7}] \
        [ase::analysis_line emsim {type emf lead 3 tail 7}] \
        [ase::analysis_line emsim {type emf lead {} tail 7}]] \
  [list {emf LEADDEF 7} {emf 3 7} {emf LEADDEF 7}]

## --- EM6: THE SLOT WALK STRIPS SIGILS, AND IT IS WRITTEN ONCE --------------
## A reader and a validator that each walked the template themselves would be two
## copies of the answer to "which fields does this card consume".
check "EM6 the fields a deck line consumes are read from the template in one\
 place, whatever marks each slot carries" \
  [list [ase::analysis_slots {tran @step @stop @tmax? @uic! END}] \
        [ase::analysis_slots {op}] \
        [ase::analysis_slots {emf @lead? @tail}]] \
  [list {step stop tmax uic} {} {lead tail}]

## --- EM7: ⚠ FOUR OF THE ELEVEN SHIPPED ENTRIES CARRY NO `fields` KEY -------
## MEASURED: noise, disto, sp and pss are registered probe-only. A bare
## `[dict get $e fields]` in the card reader raises for every one of them, and
## `ase::ui::arg_summary`'s catch (row D8j) would swallow that into a silently
## degraded pane -- THE EXACT FAILURE THIS STAGE DELETES, RE-CREATED BY THE FIX.
##
## ⚠ IT WAS SEVEN, THEN SIX WHEN Stage 5 GAVE `tf` A REAL ENTRY (issue 1426),
## THEN FIVE WITH `pz` (issue 1427), AND IS NOW FOUR WITH `sens` (issue 1428) --
## the last of Stage 5, so the next entry to leave this list is Stage 6's. The
## list below is ORDERED, and the order is `ase::analysis_offered`'s, so a type
## that gains fields leaves the list at the position it used to hold -- which is
## why `sens` disappearing from between `noise` and `disto` is the visible half
## of that change and not a silent shrink. ⚠ `sens` ALSO OVERTOOK `noise` in the
## offered order, because it earned an `emitorder`; that half is AG1/AG2's.
set EM7NOFLD {}
foreach em7t [ase::analysis_offered ngspice] {
  if {![dict exists [ase::analysis_entry ngspice $em7t] fields]} { lappend EM7NOFLD $em7t }
}
check "EM7 the analyses this adapter describes but cannot yet drive carry no\
 field table at all, and asking them for a deck line answers empty instead of\
 blowing up" \
  [list $EM7NOFLD \
        [catch {ase::analysis_cards ngspice {type pss enabled 1}}] \
        [ase::analysis_line ngspice {type pss enabled 1}]] \
  [list {noise disto sp pss} 0 {}]

## --- EM8: THE SHIPPED FOUR ARE BYTE-IDENTICAL ------------------------------
## ⚠ THE WHOLE POINT OF FIXTURE BACKENDS. If this row ever moves, the grammar
## changed what the product emits and the 104 committed benches moved with it.
check "EM8 the four analyses this adapter already drives emit exactly what they\
 emitted before the grammar existed" \
  [list [ase::analysis_line ngspice {type op enabled 1}] \
        [ase::analysis_line ngspice {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01}] \
        [ase::analysis_line ngspice {type ac enabled 1 points 10 start 1 stop 1meg}] \
        [ase::analysis_line ngspice {type tran enabled 1 step 1n stop 10u}]] \
  [list op {dc V2 0 1.8 0.01} {ac dec 10 1 1meg} {tran 1n 10u}]

## --- EM9: THE REGISTRY CAN BE ASKED WHETHER IT CONTRADICTS ITSELF ----------
## ⚠ A PURE READER THAT NEVER RAISES AND IS NEVER CALLED AT LOAD. `ase.tcl` is
## sourced from inside `Tcl_AppInit()`, so a raise there does not surface in a
## dialog -- it ABORTS XSCHEM AT STARTUP with no layers, colours, menus or undo
## set up (issue 0663's arm). A registry validator that runs at load is the one
## shape this must not take.
proc em_bad_types {} {
  return [dict create \
    emb [dict create label emb baseline 1 registered 1 emitorder 10 \
           fields {{name shown kind real}} \
           emit {{role analysis tmpl {emb @missing?}}}]]
}
ase::register_backend embad [dict merge [em_five] [dict create analysis_types em_bad_types]]
check "EM9 a registry that offers a field no deck line consumes, or consumes a\
 slot it never describes, can be asked to say so -- and asking never blows up" \
  [list [lsort [ase::analysis_schema_errors embad]] \
        [ase::analysis_schema_errors ngspice] \
        [catch {ase::analysis_schema_errors zznosuchsim}]] \
  [list {{emb fieldunused shown} {emb noslotfield missing}} {} 0]



# ============================================================================
# EK. ONE REFUSAL READER, AND SI. THE NUMBER ALPHABET -- ISSUE 1415
# ============================================================================
#
# Stage 3 commit C2. A row the form accepted but the template cannot fill is
# refused AT THE GATE, where nothing in the run directory has been touched, rather
# than discovered by `dict get` while the deck is being written.

proc ek_state {rows} {
  set st [ase::state_default]
  dict set st design {lib aselib cell nfet_clean view schematic}
  dict set st rundir {}
  dict set st models {{file /m/s.lib section tt}}
  dict set st analyses $rows
  return $st
}
set EKNET {** sch_path: /f/n.sch
**.subckt n
V1 D GND 1
**.ends
.GLOBAL GND
.end
}
proc ek_gate {rows} {
  global EKNET
  set ::ek_said {}
  set had [expr {[info commands ::ciw_echo] ne {}}]
  if {$had} { rename ::ciw_echo ::ek_saved }
  proc ::ciw_echo {line {tag {}}} { lappend ::ek_said [list $tag $line] ; return {} }
  set v [ase::preflight_gate [ek_state $rows] $EKNET]
  catch {rename ::ciw_echo {}}
  if {$had} { rename ::ek_saved ::ciw_echo }
  return $v
}

## --- EK1: A ROW THAT CANNOT BE EMITTED IS REFUSED, BY NAME ------------------
check "EK1 an analysis switched on with a value missing is refused before\
 anything is written, and the refusal names the value" \
  [list [lindex [ek_gate {{type tran enabled 1 step 1n}}] 0] \
        [lindex [ek_gate {{type tran enabled 1 step 1n}}] 1] \
        [ek_gate {{type tran enabled 1 step 1n stop 10u}}]] \
  [list emit_incomplete {{tran {needs a value for 'stop'}}} {}]

## --- EK2: **ALL** THE OFFENCES, NOT THE FIRST ------------------------------
## A validator that stops at the first makes the user press OK once per mistake,
## and each press re-renders the form.
check "EK2 every missing value is reported at once, so one press of OK tells the\
 user everything that is wrong" \
  [llength [ase::analysis_emit_check ngspice {type dc enabled 1 source V2}]] 3

## --- EK3: ⚠ THE ESCAPE HATCH DOES NOT REACH THIS CHECK ---------------------
## `set ase_preflight 0` is a real lever for the save-name scanner -- a user who
## knows their netlist better than it does can switch it off and run. There is
## nothing for it to be right about here: a row with no value for a required slot
## cannot be emitted by ANY spelling, so forcing it produces exactly the silent
## nothing this stage deletes. ⚠ WITHOUT THIS LEG THE ROW IS VACUOUS: the default
## is `ase_preflight 1`, so a gate placed BELOW the escape behaves identically
## until someone sets it -- and no other row sets it.
## ⚠ BARE WORDS DO NOT GO IN `expr`. This has now aborted a suite FOUR times in
## this batch (simcaps L, Q, V and here). The only symptom is the check count
## going DOWN, which is what the floor paragraph exists to make visible. Use `if`.
set EK3SAVE NOVAR
if {[info exists ::ase_preflight]} { set EK3SAVE $::ase_preflight }
set ::ase_preflight 0
set EK3 [lindex [ek_gate {{type tran enabled 1 step 1n}}] 0]
if {$EK3SAVE eq {NOVAR}} { unset ::ase_preflight } else { set ::ase_preflight $EK3SAVE }
check "EK3 the switch that turns off the netlist scanner does not turn off this\
 refusal, because there is no way to force a row that cannot be emitted" \
  [list $EK3 [info exists ::ase_preflight] \
        [expr {[info exists ::ase_preflight] ? ($::ase_preflight eq $EK3SAVE) : ($EK3SAVE eq {NOVAR})}]] \
  [list emit_incomplete 1 1]

## --- EK4: THE CLAUSE CARRIES NO FRAME, AND THE GATE CARRIES BOTH -----------
## ⚠ ASSERT THE **SHAPE**, NOT TWO SUBSTRINGS OF A COMPOSED SENTENCE. Issue 1404
## split frame from clause so an adapter cannot write in ASE-L's voice; a row that
## only checked the finished sentence would stay green when an adapter composed
## the whole thing itself.
set EK4C [ase::analysis_emit_msg missing stop]
set EK4S {}
ek_gate {{type tran enabled 1 step 1n}}
foreach ek4 $::ek_said { if {[string first {needs a value} [lindex $ek4 1]] >= 0} { set EK4S [lindex $ek4 1] } }
check "EK4 the part the adapter supplies is a bare clause with no prefix and no\
 verdict of its own, and the sentence the user sees is that clause inside ASE-L's\
 frame" \
  [list $EK4C \
        [expr {[string first {ase:} $EK4C] < 0}] \
        [expr {[string first {Nothing was generated} $EK4C] < 0}] \
        [expr {[string first $EK4C $EK4S] > 0}] \
        [expr {[string range $EK4S 0 4] eq {ase: }}]] \
  [list {needs a value for 'stop'} 1 1 1 1]

## --- EK5: A BOOL'S ONLY WRONG VALUE ---------------------------------------
## ⚠ A BOOL CANNOT BE "MISSING": absent means off, which is a legal answer. Its
## only offence is a value that is neither on nor off.
proc ek_bool_types {} {
  return [dict create \
    ekb [dict create label ekb baseline 1 registered 1 emitorder 10 \
           fields {{name stop kind time required 1} {name uic kind bool when_true uic}} \
           emit {{role analysis tmpl {ekb @stop @uic!}}}]]
}
ase::register_backend ekbool [dict merge [em_five] [dict create analysis_types ek_bool_types]]
check "EK5 a switch left alone is not a missing value, and only a switch set to\
 something that is neither on nor off is an offence" \
  [list [ase::analysis_emit_check ekbool {type ekb stop 1u}] \
        [ase::analysis_emit_check ekbool {type ekb stop 1u uic 0}] \
        [ase::analysis_emit_check ekbool {type ekb stop 1u uic 1}] \
        [lindex [ase::analysis_emit_check ekbool {type ekb stop 1u uic maybe}] 0 0]] \
  [list {} {} {} boolval]

## --- EK6: THE CORPUS INVARIANT, AND IT BELONGS WITH THIS COMMIT ------------
## ⚠ C2 IS THE COMMIT THAT COULD BREAK EVERY COMMITTED BENCH AT THE GATE, so the
## row that would notice lands with it. Every ENABLED analysis row of every
## tracked `.state` file must pass the check clean -- if one does not, this commit
## makes a shipped bench unrunnable.
set EKBAD {}
set EKN 0
foreach ekf [glob -nocomplain -directory $repo -join * xschem_libs * * * *.state] {
  if {[catch {open $ekf r} fh]} { continue }
  set ektxt [read $fh] ; close $fh
  foreach ekl [split $ektxt "\n"] {
    if {[string first {analyses } $ekl] != 0} { continue }
    if {[catch {lindex $ekl 1} ekrows]} { continue }
    foreach ekr $ekrows {
      if {[catch {ase::state_get $ekr enabled 0} eken]} { continue }
      if {$eken ne {1}} { continue }
      incr EKN
      set ekoff [ase::analysis_emit_check ngspice $ekr]
      if {[llength $ekoff]} { lappend EKBAD [list [file tail $ekf] $ekoff] }
    }
  }
}
check "EK6 every analysis switched on in every bench committed to this repository\
 still passes the new refusal, so the commit that adds it makes none of them\
 unrunnable" \
  [list $EKBAD [expr {$EKN > 50}]] [list {} 1]

# --- SI: THE NUMBER ALPHABET ------------------------------------------------
## ⚠ EVERY VALUE BELOW WAS MEASURED with a VALUE harness (`v1 in 0 dc <s>` / `op`
## / `print v(in)`) against /usr/bin/ngspice, not read from a manual and not taken
## from a FREQUENCY harness -- a frequency harness collapses an out-of-range value
## to ngspice's default and announces it, which is how `1mil` gets recorded as
## `1e+03` by anyone who uses one.
set SISUF [ase::backend::ngspice::si_suffixes]
## ⚠ COMPARE THE NUMBER AS A NUMBER. `20u` computes to
## **1.9999999999999998e-5** and `0.02m` to exactly `2e-5` -- the same quantity,
## two different strings, because 20 x 1e-6 is not representable. A row that
## compared the rendered string would be asserting IEEE double formatting, not the
## suffix table, and would break on a value nobody changed.
proc si_is {r want} {
  if {[lindex $r 0] ne {ok}} { return [lindex $r 0] }
  set v [lindex $r 1]
  if {$want == 0} { return [expr {$v == 0 ? 1 : 0}] }
  return [expr {abs(($v - $want) / double($want)) < 1e-12 ? 1 : 0}]
}
check "SI1 the suffixes this simulator reads are read the way it reads them,\
 measured value by measured value" \
  [list [si_is [ase::si_parse 20u $SISUF] 2e-5] \
        [si_is [ase::si_parse 0.02m $SISUF] 2e-5] \
        [si_is [ase::si_parse 1meg $SISUF] 1e6] \
        [si_is [ase::si_parse 2k $SISUF] 2e3]] \
  [list 1 1 1 1]

## ⚠ `mil` IS NOT MILLI AND `a` IS ATTO, and both are in ngspice AND in this
## repository's own `atof_spice`. Reading `mil` as milli is a factor of ~39.
check "SI2 a thousandth of an inch is not a thousandth, and atto is a real\
 suffix -- both measured, and both agreeing with xschem's own parser" \
  [list [si_is [ase::si_parse 20mil $SISUF] 5.08e-4] \
        [si_is [ase::si_parse 1a $SISUF] 1e-18] \
        [si_is [ase::si_parse 20mil $SISUF] 2e-5]] \
  [list 1 1 0]

## ⚠ THE WARNING ngspice ITSELF DOES NOT GIVE. MEASURED: `v1 in 0 dc 1M` answers
## 1.000000e-03 with ZERO warning or error lines. `M` is MILLI; users who write it
## mean MEGA. Nine orders of magnitude, silently, and ASE-L is the only place it
## can be said.
check "SI3 a capital M is a thousandth and not a million, and ASE-L says so\
 because the simulator does not" \
  [list [lindex [ase::si_parse 1M $SISUF] 0] [lindex [ase::si_parse 1M $SISUF] 2] \
        [si_is [list ok [lindex [ase::si_parse 1M $SISUF] 1]] 1e-3] \
        [lindex [ase::si_parse 1m $SISUF] 0] \
        [si_is [ase::si_parse 1m $SISUF] 1e-3]] \
  [list warn caseM 1 ok 1]

## ⚠ `x` IS NOT IN THIS TABLE AND ITS ABSENCE IS MEASURED. `1x` answers
## 1.000000e+00 to ngspice -- the suffix is IGNORED -- while this repository's own
## `atof_spice` reads it as 1e6 under the comment "Xyce extension". The same
## schematic value means two different numbers to the two parsers, so putting `x`
## here would make ASE-L agree with xschem and disagree with the simulator it is
## driving.
check "SI4 a suffix this simulator ignores is refused rather than quietly read as\
 something else, even though this repository's own parser accepts it" \
  [list [ase::si_parse 1x $SISUF] [ase::si_parse abc $SISUF] [ase::si_parse {} $SISUF]] \
  [list {bad unknownsuffix} {bad notanumber} {bad empty}]

## ⚠ A BACKEND THAT DECLARED NO TABLE GETS **NO NUMERIC OPINION**. Refusing text
## there would be a claim about a simulator ASE-L has never seen, and there are
## real ones whose parameters are not numbers at all -- a Xyce `.TRAN {tstep}`
## carries a braced expression and is legal. Same house rule as every other
## optional hook: absent means NOT MEASURED, never NO.
check "SI5 a simulator that has not said what its numbers look like has nothing\
 refused on its behalf" \
  [list [ase::si_parse abc] [ase::si_parse 20u] [ase::si_parse {}]] \
  [list ok ok {bad empty}]


} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}



# --- AC: THE ARGUMENTS COLUMN NEVER SHOWS WHAT THE DECK WILL NOT CARRY ------
## ⚠ THE OTHER HALF OF THIS BATCH'S ACCEPTANCE CRITERION. The first half --
## nothing the window shows may fail to reach the deck -- is what C5 and C6 were
## about. This is the second: an ENABLED row that cannot render used to have its
## keys dumped into the column as `step=1n stop=10u`, which reads exactly like a
## setting that is in force, in the one column whose entire job is to say what
## the deck carries. The honest answer to "what will this run?" for a row that
## cannot run is the reason it cannot.
check "AC1 an enabled row that cannot render says WHY, in the column that would\
 otherwise list values the deck will never carry" \
  [ase::ui::arg_summary {type tran enabled 1 stop 10u} ngspice] \
  {needs a value for 'step'}

## ⚠ AND THE WORDS ARE THE SAME ONES THE COMMIT DOOR AND THE GATE USE. Three
## surfaces, one vocabulary: if the pane and the dialog disagreed about why a row
## will not run, one of them would be wrong and the user could not tell which.
check "AC2 the column's reason is the identical clause the refusal reader\
 produces, not a second sentence about the same thing" \
  [list [ase::ui::arg_summary {type tran enabled 1 stop 10u} ngspice] \
        [lindex [lindex [ase::analysis_emit_check ngspice \
                  {type tran enabled 1 stop 10u}] 0] 2]] \
  {{needs a value for 'step'} {needs a value for 'step'}}

## ⚠ ONLY FOR AN ENABLED ROW. A switched-off row makes no claim about a run, so
## it has nothing to be wrong about -- and EVERY NEW BENCH OPENS WITH THREE EMPTY
## DISABLED ROWS, which would each otherwise carry a complaint about a value
## nobody has been asked for yet. `ase::state_default` seeds exactly those.
check "AC3 a switched-off row that cannot render stays silent, so a new bench\
 does not open wearing three complaints" \
  [list [ase::ui::arg_summary {type tran enabled 0 stop 10u} ngspice] \
        [ase::ui::arg_summary {type dc enabled 0} ngspice] \
        [ase::ui::arg_summary {type ac enabled 0} ngspice]] \
  [list {stop=10u} {} {}]

## ⚠ AND A ROW THAT CAN RENDER IS UNTOUCHED, which is what keeps the pane's
## existing meaning -- and the 104 committed benches' display -- exactly where
## Stage 1 put it.
check "AC4 a renderable row still shows the line the deck will carry, hatch\
 count and all" \
  [list [ase::ui::arg_summary {type tran enabled 1 step 1n stop 10u} ngspice] \
        [ase::ui::arg_summary {type op enabled 1} ngspice] \
        [ase::ui::arg_summary \
          {type tran enabled 1 step 1n stop 10u x {{echo a}}} ngspice]] \
  [list {tran 1n 10u} {op} {tran 1n 10u  + verbatim: 1 line}]

## ⚠ A TYPE THIS BACKEND CANNOT SET UP READS AS SUCH RATHER THAN AS A MISSING
## VALUE. Seven of the eleven registered types are probe-only until Stage 6; an
## enabled one of those has nothing missing -- there is simply nothing ASE-L can
## write for it, and "needs a value for ..." would send the user hunting for a
## field that does not exist.
check "AC5 an enabled row of a type the backend cannot set up says that, not\
 that some value is missing" \
  [ase::ui::arg_summary {type noise enabled 1} ngspice] \
  {is not one this simulator backend can set up}

# --- VB: THE ONE HONEST ESCAPE FROM A TYPED FORM ----------------------------
## ⚠ EVERY OTHER ESCAPE THIS STAGE FOUND WAS A LIE. `Options…` collected
## free-text pairs, round-tripped them and emitted nothing (issue 1418); the
## Arguments column showed them back, which is what made the lie convincing.
## `x` is the replacement, and the whole difference is that IT EMITS.
##
## ⚠ IT IS A ROW KEY, NOT A FIELD, AND THAT DISTINCTION IS LOAD-BEARING. A
## `field` no template spends is exactly what ase::analysis_schema_errors
## refuses -- so declaring `x` as a field would make the registry
## self-inconsistent by its own rule. It is not an unknown key either, because
## unlike everything C5 shut the door on, something reads it.
set VBST [nfet_state /models/sky130.lib.spice {}]
dict set VBST analyses {{type op enabled 1}
                        {type dc enabled 0}
                        {type ac enabled 0}
                        {type tran enabled 1 step 1n stop 1u
                         x {{alter @m.xm1.msky130_fd_pr__nfet_01v8[w] = 2u}
                            {set temp = 40}}}}
set VBDECK [$render $VBST $netlist_text]
set VBLINES [split $VBDECK "\n"]
set VBti [lsearch -exact $VBLINES {tran 1n 1u}]
check "VB1 the verbatim lines are emitted, in order, IMMEDIATELY above their own\
 analysis" \
  [list [expr {$VBti > 1}] \
        [lindex $VBLINES [expr {$VBti - 1}]] \
        [lindex $VBLINES [expr {$VBti - 2}]]] \
  [list 1 {set temp = 40} \
        {alter @m.xm1.msky130_fd_pr__nfet_01v8[w] = 2u}]

## ⚠ ABOVE ITS OWN ANALYSIS, NOT AT THE TOP OF `.control`. These lines exist to
## set something up for THIS analysis; a deck with two enabled analyses would
## otherwise apply one analysis's setup to both, silently, in run order. This
## row puts a different hatch on each and requires each above its own line.
set VBST2 [nfet_state /models/sky130.lib.spice {}]
dict set VBST2 analyses {{type op enabled 1 x {{echo FOR-OP}}}
                         {type dc enabled 0}
                         {type ac enabled 0}
                         {type tran enabled 1 step 1n stop 1u x {{echo FOR-TRAN}}}}
set VBD2 [split [$render $VBST2 $netlist_text] "\n"]
check "VB2 two analyses each carry their own hatch, and neither borrows the\
 other's" \
  [list [expr {[lsearch -exact $VBD2 {echo FOR-OP}] \
               == [lsearch -exact $VBD2 {op}] - 1}] \
        [expr {[lsearch -exact $VBD2 {echo FOR-TRAN}] \
               == [lsearch -exact $VBD2 {tran 1n 1u}] - 1}]] {1 1}

## ⚠ AND A ROW WITHOUT ONE IS BYTE-IDENTICAL TO BEFORE THIS COMMIT, which is
## what keeps all 104 committed benches where they are: none of them carries an
## `x` key.
set VBST3 [nfet_state /models/sky130.lib.spice {}]
dict set VBST3 analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 step 1n stop 1u}}
## ⚠ THE COMPARISON IS AGAINST A DECK RENDERED HERE, NOT AGAINST D2's. The first
## draft of this row compared with `$deck2` from section D and failed on ONE
## thing: the `write` line's raw-file path. D2 rendered while the rundir still
## resolved to the user's default, and by the time this section runs a later
## fixture has moved it into the suite's scratch tree. The decks were otherwise
## identical. A row that pins a whole deck across a file this long is really
## pinning every fixture between the two points, and it reds for whichever of
## them moved last.
##
## What this asserts instead is order-independent and is the actual claim: the
## hatch adds EXACTLY its own lines and changes nothing else anywhere in the
## deck. Strip the two verbatim lines out of the hatched deck and it must equal
## the unhatched one, byte for byte.
set VBD3 [$render $VBST3 $netlist_text]
set VBSTRIP {}
foreach VBL [split $VBDECK "\n"] {
  if {$VBL eq {set temp = 40}} { continue }
  if {$VBL eq {alter @m.xm1.msky130_fd_pr__nfet_01v8[w] = 2u}} { continue }
  lappend VBSTRIP $VBL
}
check "VB3 the hatch adds exactly its own lines and changes nothing else, so a\
 row without one is byte-identical to before the hatch existed" \
  [list [string equal [join $VBSTRIP "\n"] $VBD3] \
        [expr {[llength [split $VBDECK "\n"]] \
               - [llength [split $VBD3 "\n"]]}]] {1 2}

## ⚠ AN ESCAPE THAT CANNOT BE WRONG IS AN ESCAPE NOBODY CAN TRUST. A malformed
## list would raise inside render_deck's `foreach`, where there is no sentence
## to say; it is refused where there is one. A blank line is refused too: it
## emits an empty line into `.control`, which ngspice accepts and which makes the
## deck unreadable to the next person who opens it.
## ⚠ THE READER IS CALLED INSIDE THE ROW'S OWN `catch`, AND THAT IS NOT
## DEFENSIVE PADDING. MEASURED: with the reader's internal catch removed, this
## suite does not go red -- it DIES, `unmatched open brace in list`, before the
## verdict banner, so the only thing naming the defect is a line number. Both
## banner readers do score that a failure, so the tree notices; but a row that
## returns rc 1 names the PROC, and that is the difference between a defect
## someone fixes and a defect someone bisects.
##
## ⚠ AND IT IS WHY THE CATCH EXISTS IN THE PRODUCT AT ALL. `arg_summary` renders
## EVERY row of the pane; a raise there takes the dialog down with it, which is
## issue 1405's shape exactly -- one bad row in one bench, and the window that
## would let the user fix it will not open.
set VBRC [catch {ase::analysis_verbatim {type tran x "unbalanced \{brace"}} VBR]
check "VB4 a hatch that is not a readable list of non-blank lines is refused,\
 and the reader answers empty rather than raising" \
  [list [lindex [lindex [ase::analysis_emit_check ngspice \
           {type tran step 1n stop 1u x "unbalanced \{brace"}] 0] 0] \
        $VBRC $VBR \
        [lindex [lindex [ase::analysis_emit_check ngspice \
           {type tran step 1n stop 1u x {{echo ok} {}}}] 0] 0]] \
  {verbatim 0 {} verbatim}

## ⚠ AND `x` IS NOT AN UNKNOWN KEY. C5 refuses every key nothing can spend; this
## row is what stops that refusal swallowing the one key that CAN be spent.
check "VB5 the hatch is not mistaken for a setting ASE-L cannot emit" \
  [ase::analysis_emit_check ngspice \
    {type tran step 1n stop 1u x {{echo hello}}}] {}

## ⚠ THE COLUMN SHOWS A COUNT, NOT THE CONTENTS. Three `.control` lines pasted
## into a one-line treeview cell would push the analysis line -- the thing the
## column is FOR -- off the right-hand edge. But it may not be SILENT either: a
## deck carrying lines the window never mentions fails the second half of this
## batch's acceptance criterion, in the direction where the user runs something
## they cannot see.
check "VB6 the Arguments column names the hatch by count without losing the deck\
 line, and says nothing at all when there is no hatch" \
  [list [ase::ui::arg_summary {type tran step 1n stop 1u x {{echo a} {echo b}}}] \
        [ase::ui::arg_summary {type tran step 1n stop 1u x {{echo a}}}] \
        [ase::ui::arg_summary {type tran step 1n stop 1u}]] \
  [list {tran 1n 1u  + verbatim: 2 lines} \
        {tran 1n 1u  + verbatim: 1 line} \
        {tran 1n 1u}]

# --- PB: THE POSITIONAL BACK-FILL -------------------------------------------
## ⚠ THIS IS THE OTHER HALF OF ISSUE 1414, AND IT IS THE HALF THAT SURVIVES A
## `string trim`. 1414 stopped a skipped slot emitting an EMPTY WORD. It did not
## stop a skipped slot letting the value to its RIGHT slide left into its place,
## because that emission has no double space, no empty element, and nothing at
## all for a reader to notice.
##
## MEASURED, on the ngspice manual's own grammar for tran:
##     tran tstep tstop [tstart [tmax]] [uic]
## is read PURELY BY POSITION. A row carrying a tmax and no tstart, expanded by
## dropping the skipped slot, emits
##     tran 1n 10u 0.2n
## and ngspice takes `0.2n` as TSTART -- the run records from 0.2n to 10u with
## the integrator left unbounded. rc 0, no warning, a plot with the right name
## and the wrong contents. The whole defect is one word in one position.
##
## The fix is `whenskipped` on the FIELD, not a flag on the card: a field that
## occupies a position says what it means when it is left out, and a skipped
## slot emits that value whenever anything to its right still emits. A field
## with no `whenskipped` is genuinely trailing and simply vanishes, which is why
## `tmax` declares none and `tstart` declares 0.
proc pbline {row} {
  set e [ase::analysis_entry ngspice [dict get $row type]]
  set flds {}
  if {[dict exists $e fields]} { set flds [dict get $e fields] }
  foreach card [dict get $e emit] {
    if {[dict get $card role] eq {analysis}} {
      return [ase::analysis_expand $row [dict get $card tmpl] $flds]
    }
  }
  return {}
}

check "PB1 a tran row carrying only the two required values emits exactly what it\
 emitted before this commit, which is what keeps all 104 committed benches\
 byte-identical" \
  [pbline {type tran step 1n stop 10u}] {tran 1n 10u}

## ⚠ THE ROW THIS SECTION EXISTS FOR. Without the back-fill this reads
## `tran 1n 10u 0.2n` -- three words, no empty element, `string trim` perfectly
## happy -- and 0.2n is TSTART.
check "PB2 a tran row with a maximum step and no start time back-fills the start\
 slot, so the maximum step lands in the maximum-step position instead of being\
 read as a start time" \
  [pbline {type tran step 1n stop 10u tmax 0.2n}] {tran 1n 10u 0 0.2n}

check "PB3 and the back-filled word is the field's declared whenskipped value,\
 not the value that would otherwise have slid into that slot" \
  [lindex [pbline {type tran step 1n stop 10u tmax 0.2n}] 3] 0

check "PB4 both optional times present emits both in their own positions" \
  [pbline {type tran step 1n stop 10u tstart 1u tmax 0.2n}] {tran 1n 10u 1u 0.2n}

check "PB5 a trailing bool also counts as a later word, so a uic row back-fills\
 the start slot rather than letting uic be read as a start time" \
  [pbline {type tran step 1n stop 10u uic 1}] {tran 1n 10u 0 uic}

check "PB6 uic switched OFF contributes nothing at all, so it cannot move a\
 committed row" \
  [pbline {type tran step 1n stop 10u uic 0}] {tran 1n 10u}

## ⚠ THE BACK-FILL MUST NOT FIRE WHEN THERE IS NOTHING TO ITS RIGHT. A row with
## no tmax and no uic must stay three words: back-filling unconditionally would
## move every committed tran bench, which is the opposite defect.
check "PB7 a skipped positional slot with nothing emitting to its right stays\
 skipped" \
  [pbline {type tran step 1n stop 10u tstart {}}] {tran 1n 10u}

check "PB8 a field that declares no whenskipped is genuinely trailing and\
 vanishes even when it is skipped before a later word" \
  [pbline {type tran step 1n stop 10u tstart 1u uic 1}] {tran 1n 10u 1u uic}

## ⚠ THE `dec` DRIFT DIES HERE. `render_deck` used to carry the word `dec` as a
## LITERAL inside the template, so a state row storing `oct` or `lin` emitted
## `ac dec ...` and discarded the stored value in silence -- measured, and
## recorded beside the registry entry before this commit landed. `@sweep?` with
## `default dec` resolves the same word AT EMIT, which is why all 104 committed
## ac rows -- none of which carries a `sweep` key at all -- still emit the same
## five words.
check "PB9 an ac row with no sweep key emits the same line it emitted when the\
 sweep word was a hardwired literal" \
  [pbline {type ac points 20 start 10 stop 1g}] {ac dec 20 10 1g}

check "PB10 and an ac row that stores a sweep mode finally emits it instead of\
 discarding it" \
  [pbline {type ac sweep lin points 20 start 10 stop 1g}] {ac lin 20 10 1g}

check "PB11 a dc row with one sweep emits four words after the verb, unchanged" \
  [pbline {type dc source V1 start -12 stop 1 step 1m}] {dc V1 -12 1 1m}

check "PB12 a dc row with a second nest emits all eight" \
  [pbline {type dc source V1 start -12 stop 1 step 1m source2 temp start2 -40\
           stop2 60 step2 50}] {dc V1 -12 1 1m temp -40 60 50}

# --- GR: ALL OF A GROUP'S VALUES, OR NONE OF THEM ---------------------------
## ⚠ A PER-FIELD `required` CANNOT SAY THIS. Each of the second nest's four
## values is genuinely optional on its own -- a dc sweep with no second nest is
## the normal case, and 68 of the 104 committed benches are exactly that. What
## is not legal is THREE of them. `dc V1 0 1 0.1 temp` is not a smaller sweep
## that does less; it is a parse error ngspice reports from the middle of a run,
## after the deck has been written and the process started.
set GR1 [ase::analysis_emit_check ngspice \
  {type dc source V1 start 0 stop 1 step 0.1 source2 temp}]
check "GR1 a second sweep variable with no start, stop or step is refused before\
 a deck is written" \
  [list [llength $GR1] [lindex [lindex $GR1 0] 0] [lindex [lindex $GR1 0] 1]] \
  {1 group {second sweep}}

check "GR2 a complete second nest is not refused" \
  [ase::analysis_emit_check ngspice \
    {type dc source V1 start 0 stop 1 step 0.1 source2 temp start2 -40 stop2 60\
     step2 50}] {}

check "GR3 no second nest at all is not refused, which is 68 of the committed\
 benches" \
  [ase::analysis_emit_check ngspice {type dc source V1 start 0 stop 1 step 0.1}] {}

## ⚠ THE FINDING NAMES THE GROUP, NOT A FIELD. Naming one of the four would send
## the user to fill in that one and leave the other two still missing.
check "GR4 the refusal names the group rather than picking one of its fields" \
  [lindex [lindex $GR1 0] 1] {second sweep}

## ⚠ NO FRAME. Issue 1404's split: the reader owns the clause, the caller owns
## the sentence around it. A row asserting a composed sentence would stay green
## when an adapter composed the whole thing itself.
## ⚠ AND IT MUST ASSERT THE CLAUSE IS THERE BEFORE ASSERTING WHAT IT IS NOT.
## MEASURED: with the group rule DELETED this row went GREEN. `$GR1` was then
## empty, `[lindex [lindex {} 0] 2]` is the empty string, and `string first`
## returns -1 on it -- so a row written to prove the clause carries no frame
## proved it about a clause that did not exist. The non-empty leg is first for
## that reason, and it is the third sabotage in this batch to pass a row that
## looked airtight.
check "GR5 the group clause is real, carries no ase: prefix and no frame of its own" \
  [list [expr {[lindex [lindex $GR1 0] 2] ne {}}] \
        [string first {ase:} [lindex [lindex $GR1 0] 2]] \
        [expr {[lindex [lindex $GR1 0] 2] \
               eq [ase::analysis_emit_msg group {second sweep}]}]] \
  {1 -1 1}

check "GR6 a bool is still refused only for a value that is neither on nor off,\
 because absent means off and that is a legal answer" \
  [list [lindex [lindex [ase::analysis_emit_check ngspice \
                  {type tran step 1n stop 10u uic maybe}] 0] 0] \
        [ase::analysis_emit_check ngspice {type tran step 1n stop 10u}]] \
  {boolval {}}



## --- GR9: A KEY NO TEMPLATE CAN SPEND ---------------------------------------
## ⚠ THIS IS STAGE 3's WHOLE DEFECT AS A PROPERTY OF ONE ROW. `Options…`
## collected free-text name/value pairs, round-tripped them through the .state
## file and rendered them in the Arguments column -- and NEVER EMITTED THEM. Its
## own header comment said so. Measured end to end: type `uic 1`, `tstart 5u`,
## `tmax 1n` into a tran row, see all three confirmed in the pane, and the deck
## says `tran 10n 200u`.
##
## ⚠ AND REFUSING IS SAFE, WHICH WAS MEASURED BEFORE IT WAS WRITTEN -- see
## section CP. Zero of the 416 committed analysis rows carry a key this rejects.
check "GR9 a row carrying a setting no template can spend is refused, and the\
 refusal names the setting" \
  [list [lindex [lindex [ase::analysis_emit_check ngspice \
            {type tran step 1n stop 10u zzmysetting 7}] 0] 0] \
        [lindex [lindex [ase::analysis_emit_check ngspice \
            {type tran step 1n stop 10u zzmysetting 7}] 0] 1] \
        [ase::analysis_emit_check ngspice {type tran step 1n stop 10u}]] \
  {unknownkey zzmysetting {}}

## ⚠ AND `type` AND `enabled` ARE NOT SETTINGS. They are the row's identity and
## its switch; a check that flagged them would refuse every row in the tree.
check "GR10 the row's own identity and switch are never mistaken for settings,\
 and every declared field of every type is spendable" \
  [list [ase::analysis_emit_check ngspice {type op enabled 1}] \
        [ase::analysis_emit_check ngspice \
          {type tran enabled 1 step 1n stop 10u tstart 0 tmax 0.2n uic 1}] \
        [ase::analysis_emit_check ngspice \
          {type ac enabled 0 sweep lin points 20 start 10 stop 1g}]] \
  {{} {} {}}

## --- GR7/GR8: THE NUMBER CHECK IS AN ALLOW-LIST -----------------------------
## ⚠ IT WAS A DENY-LIST UNTIL IT MET A FIELD WHOSE LEGAL VALUES ARE WORDS, AND
## THAT WAS A LIVE DEFECT FOR ONE COMMIT. The test read "parse anything that is
## not one of two named kinds". Issue 1416 then declared ac's sweep mode with
## `kind mode`, whose legal values are dec, oct and lin -- and every one came
## back `bad notanumber`. MEASURED: a bench storing `sweep lin` was refused with
## `cannot read 'lin' as a number for 'sweep'`, which is a control the window
## offers and the gate then rejects: the exact shape this batch exists to delete.
##
## A deny-list is wrong here BY CONSTRUCTION. It assumes every kind nobody has
## thought of yet is numeric, so the next `kind` any adapter invents is born
## broken, and born broken in the direction that refuses legal work.
check "GR7 a field whose legal values are words is not number-checked, while the\
 numeric fields beside it still are" \
  [list [ase::analysis_emit_check ngspice \
          {type ac sweep lin points 20 start 10 stop 1g}] \
        [lindex [lindex [ase::analysis_emit_check ngspice \
          {type ac sweep lin points abc start 10 stop 1g}] 0] 0] \
        [ase::analysis_emit_check ngspice \
          {type dc source Vres start 0 stop 1 step 0.1}]] \
  {{} fill {}}

## ⚠ AND THE LIST OF KINDS IS PINNED, so that adding a new one is a decision
## somebody makes rather than a default somebody inherits. If this row reds, a
## field table has declared a kind nobody has classified as numeric or not.
set GRK {}
foreach grt [dict keys [ase::analysis_types ngspice]] {
  set gre [ase::analysis_entry ngspice $grt]
  if {![dict exists $gre fields]} { continue }
  foreach grf [dict get $gre fields] {
    if {![dict exists $grf kind]} { continue }
    if {[lsearch -exact $GRK [dict get $grf kind]] < 0} {
      lappend GRK [dict get $grf kind]
    }
  }
}
## ⚠ `node` JOINED DELIBERATELY (Stage 5 `pz`, issue 1427) AND IS NOT A NUMBER.
## A pole-zero row names four bare node names -- `pz in 0 out 0 vol pz` -- and
## `0` is ground, not the integer zero: number-checking it would be an accident
## waiting for the first net called `1v8`. It falls to `chana_field_row`'s
## default entry arm today, which is the same arm `outvar` and `source` take;
## the kind exists so a later stage can make it a net picker without guessing
## which fields are nets.
## ⚠ `filter` JOINED THE SAME WAY (Stage 5 `sens`, issue 1428), AND FOR THE SAME
## KIND OF REASON RATHER THAN FOR TIDINESS. A `sens` row's second field is a
## list of GLOBS over ngspice's parameter namespace -- `r*:r m*:vth0` -- so it is
## emphatically not a number, and PLAN.md §5a's whole gain is a COMPUTED picker
## for exactly this field (`devhelp -csv -type -flags`, no run needed). Calling
## it `text` would say ASE-L has no opinion about the content, and Stage 5b would
## then have to guess which text box is the one to hang a checkbox tree off.
check "GR8 every kind this registry declares has been classified as a number or\
 not a number, and the four numeric ones are the only ones parsed" \
  [lsort $GRK] {bool filter freq int mode node outvar real source time}

# --- TF: THE DC SMALL-SIGNAL TRANSFER FUNCTION (Stage 5, issue 1426) --------
## `tf` was a `role probe` card and nothing else: registered so the four-state
## grid could show it exists, `blocked/unrenderable` so it could not be enabled.
## This section is the whole of what changed when it gained a real entry.
##
## ⚠ THESE ARE DECK BYTES AND REGISTRY FACTS. The adapter's own two procs --
## `out_decompose` and `tf_vectors` -- are pinned in
## tests/headless/test_ase_simcaps_0948.tcl section TV, and the preconditions in
## tests/headless/test_ase_preflight.tcl section PF226, because those are the
## suites that own those seams.

check "TF1 tf is offered, is now renderable, and carries a rank that sorts it\
 after the four drivable types and ahead of the six that still have none" \
  [list [expr {[lsearch -exact [ase::analysis_offered ngspice] tf] >= 0}] \
        [ase::analysis_renderable ngspice tf] \
        [ase::analysis_emit_rank tf 0 ngspice] \
        [lrange [ase::analysis_offered ngspice] 0 4]] \
  {1 1 50 {op dc ac tran tf}}

## ⚠ THE THREE OUTPUT FORMS ARE ngspice's THREE, AND THE LINE IS ONE TOKEN PER
## FIELD. PLAN.md Stage 5 spells the output as four fields
## (`outkind outnode outref outsrc`) composed by a `{build <proc>}` escape;
## §1c specifies that escape and STAGE 1 DID NOT SHIP IT. `ase::analysis_expand`
## has `@x`, `@x?` and `@x!` and no `build` arm, so a `{build …}` token is
## emitted as the literal words `build ase::backend::…`, and the slot grammar
## joins tokens with a space and cannot build `v(mid,out)` from three of them.
## Until the escape exists an emitted token is one field, and `out` is that
## token verbatim.
check "TF2 tf emits the output variable and the input source, in that order,\
 for each of ngspice's three output forms" \
  [list [ase::analysis_line ngspice {type tf enabled 1 out v(D) insrc V1}] \
        [ase::analysis_line ngspice {type tf enabled 1 out v(D,G) insrc V1}] \
        [ase::analysis_line ngspice {type tf enabled 1 out i(V2) insrc V1}]] \
  {{tf v(D) V1} {tf v(D,G) V1} {tf i(V2) V1}}

check "TF2b the Arguments column IS that line, so the pane cannot show a tf\
 setting the deck does not carry" \
  [ase::ui::arg_summary {type tf enabled 1 out v(D) insrc V1}] {tf v(D) V1}

## ⚠ BOTH FIELDS ARE REQUIRED AND THE DOOR NAMES THE ONE THAT IS MISSING. It is
## the same reader the dialog's OK uses, so a row that cannot be emitted cannot
## be committed either.
check "TF3 the commit door refuses a tf row missing either field, by name, and\
 passes a complete one" \
  [list [ase::analysis_emit_check ngspice {type tf enabled 1 insrc V1}] \
        [ase::analysis_emit_check ngspice {type tf enabled 1 out v(D)}] \
        [ase::analysis_emit_check ngspice {type tf enabled 1 out v(D) insrc V1}]] \
  [list {{missing out {needs a value for 'out'}}} \
        {{missing insrc {needs a value for 'insrc'}}} \
        {}]

## ⚠ AND THE ROW IS REFUSED AT THE GATE BEFORE IT REACHES render_deck. Until
## this stage a `tf` row was `blocked/unrenderable`; it is now an ordinary cell.
## ⚠ THE CONTROL TYPE WAS `pz` AND IS NOW `noise`, BECAUSE `pz` STOPPED BEING
## UNRENDERABLE ONE COMMIT LATER (issue 1427). `noise` is the right control for
## this row for a reason beyond convenience: rows PF222a-e and PF222h-j of
## tests/headless/test_ase_preflight.tcl are BUILT on `noise` being
## unrenderable, so the day it changes those rows move too and this one is not
## the only warning.
check "TF3b the four-state grid stops calling tf unrenderable" \
  [list [dict get [ase::analysis_state ngspice tf {}] state] \
        [dict get [ase::analysis_state ngspice noise {}] state] \
        [dict get [ase::analysis_state ngspice noise {}] reason]] \
  {ok blocked unrenderable}

## THE DECK. ⚠ `d8_lines` MATCHES FOUR VERBS AND tf IS NOT ONE OF THEM, so this
## section brings its own reader rather than widening D8's and taking D8's rows
## along with it.
## ⚠ THE RENDER IS CAUGHT AND ITS FAILURE RECORDED AS AN ORDINARY VALUE, AND
## THAT IS NOT DEFENSIVE PADDING -- IT IS WHAT A SABOTAGE ASKED FOR. This
## section sits BELOW this file's outer `catch` (which closes at the end of
## section SI), so an uncaught raise here aborts the file with NO `RESULT:` LINE
## AT ALL -- which in a sabotage log reads as "nothing went red". And a raise is
## exactly what the change these rows exist to catch produces:
## `ase::backend::ngspice::render_deck` refuses an ENABLED row of an
## unrenderable type with `-code error` (row D7e4 asserts that), so respelling
## `role analysis` as `role probe` makes this proc throw. MEASURED (sabotage
## S10): the file died after six named FAILs instead of reporting them.
## ⚠ AND THE SAME `catch` IS ON `tf_lines` AND `pz_lines`, which had the same
## exposure and no measurement behind it. It is a one-line addition that never
## fires in a green tree and turns a dead file into a named row in a red one.
proc tf_lines {rows} {
  set st [nfet_state /models/sky130.lib.spice {}]
  dict set st analyses $rows
  if {[catch {$::render $st $::netlist_text} _rd]} { return "RAISED:$_rd" }
  set out {}
  foreach l [split $_rd "\n"] {
    if {[regexp {^(op|dc |ac |tran |tf )} $l]} { lappend out [string trim $l] }
  }
  return $out
}
check "TF4 an enabled tf row reaches the deck" \
  [tf_lines {{type tf enabled 1 out v(D) insrc V1}}] {{tf v(D) V1}}
## ⚠ op-LAST IS A SEPARATE NAMED RULE (issue 0964) and `emitorder 50` does not
## override it: the device requests sit immediately before `op`, and ngspice's
## save list is sticky FORWARD ONLY, so anything after `op` would record them
## again. A tf row therefore emits BEFORE op even though its rank is higher.
check "TF4b tf emits in rank order among the drivable types, and op still goes\
 last when the deck asks for device parameters" \
  [list [tf_lines {{type tf enabled 1 out v(D) insrc V1} \
                   {type tran enabled 1 step 1n stop 10u} \
                   {type op enabled 1}}] \
        [tf_lines {{type op enabled 1} \
                   {type tf enabled 1 out v(D) insrc V1}}]] \
  [list {op {tran 1n 10u} {tf v(D) V1}} {op {tf v(D) V1}}]
check "TF4c a disabled tf row emits nothing at all" \
  [tf_lines {{type op enabled 1} {type tf enabled 0 out v(D) insrc V1}}] {op}

## --- TF5: `tf` DECLARES NO `viewrank`, AND THAT IS A MEASUREMENT ------------
## ⚠ PLAN.md Stage 5 SPECIFIES `viewrank 0` FOR THIS ENTRY AND THE TREE REFUTES
## IT. The six remaining probe-only types have no viewrank because they cannot
## emit; `tf` CAN emit and DOES produce data, so that argument does not reach
## it. The reason is one step further on: `ase::plot_sim_type` answers a type
## NAME and the waveform seam spends it as `xschem raw read <file> <type>`.
## MEASURED 2026-09-12 against a raw carrying an `Operating Point` plot and a
## `Transfer Function` plot, through this tree's own binary:
##
##   xschem raw read both.raw tf                  -> `no useful data found` ... 0
##   xschem raw read both.raw op                  -> sim_type=op ............. 1
##   xschem raw read both.raw {Transfer Function} -> sim_type=Transfer Fun ... 1
##
## `src/save.c`'s `read_dataset()` maps six NAMED plot names to a type and then
## falls through to an exact `strcmp` against the plot name itself. `tf` is in
## neither set, so a viewrank would make `plot_sim_type` answer `tf`,
## `plot_sim_type_reason` answer `{}` -- "there IS a mapping" -- and the viewer
## open on nothing, saying nothing.
proc tf_state {rows} {
  return [dict replace [ase::state_default] analyses $rows]
}
check "TF5 a tf-only bench has NO viewer mapping, and says which of the two\
 silences it is" \
  [list [dict exists [ase::analysis_entry ngspice tf] viewrank] \
        [ase::plot_sim_type [tf_state {{type tf enabled 1 out v(D) insrc V1}}]] \
        [ase::plot_sim_type_reason [tf_state {{type tf enabled 1 out v(D) insrc V1}}]] \
        [ase::plot_sim_type_reason [tf_state {{type tf enabled 0 out v(D) insrc V1}}]]] \
  {0 {} no-viewer-mapping nothing-enabled}
## ⚠ NON-VACUITY. TF5's first three answers are also what a registry with no
## `tf` entry at all would give, so this row proves the ABSENCE of the key is
## what produces them: the same bench, against a fixture backend whose tf DOES
## carry a viewrank, answers `tf` and reports a mapping that does not exist.
## ⚠ THE FIXTURE BORROWS ngspice's FIVE REQUIRED HOOKS (`ag_five`, section AG)
## AND OVERRIDES ONLY `analysis_types`. Pointing the five at an arbitrary proc
## would make this entry a second, silently wrong backend that a later row could
## pick up; borrowing them keeps the ONE difference from the shipped registry the
## thing the row is about.
proc tfvr_types {} {
  return [dict create tf [dict create label tf registered 1 emitorder 50 \
    viewrank 5 fields {{name out kind outvar required 1}} \
    emit {{role analysis tmpl {tf @out}}}]]
}
ase::register_backend tfvr [dict merge [ag_five] \
  [dict create analysis_types tfvr_types]]
check "TF5b a viewrank WOULD change that answer, so TF5 is measuring the key\
 and not the absence of an entry" \
  [list [ase::plot_sim_type \
           [dict replace [tf_state {{type tf enabled 1 out v(D)}}] simulator tfvr]] \
        [ase::plot_sim_type_reason \
           [dict replace [tf_state {{type tf enabled 1 out v(D)}}] simulator tfvr]]] \
  {tf {}}

## ⚠ NO `seed_enabled`, so `tf` joins no fresh bench -- which is what keeps the
## 104 committed `.state` files round-tripping byte-identically. Section CP is
## the row that would notice if that stopped being true; this one is the cause
## rather than the consequence.
check "TF6 tf is not in the seed, so a fresh bench still carries exactly the\
 four rows every committed bench carries" \
  [list [dict exists [ase::analysis_entry ngspice tf] seed_enabled] \
        [llength [ase::analysis_seed ngspice]] \
        [lsort [lmap _r [ase::analysis_seed ngspice] {ase::state_get $_r type}]]] \
  {0 4 {ac dc op tran}}

## ⚠ SCOPED TO tf. CP5 asks the same question of the WHOLE registry and would
## red for any entry; this one names the type, so a sabotage of tf's own fields
## or template is reported as a tf defect rather than as "the registry".
check "TF7 tf's own entry is self-consistent: every slot its template spends is\
 a field it declares, and every field it declares is spent" \
  [lsearch -all -inline -index 0 -exact [ase::analysis_schema_errors ngspice] tf] {}

# --- PZ: THE POLE-ZERO ANALYSIS (Stage 5, issue 1427) -----------------------
## `pz` was a `role probe` card and nothing else, exactly as `tf` was one commit
## ago: registered so the four-state grid could show that ngspice has a pole-zero
## analysis, `blocked/unrenderable` so nobody could ask for one.
##
## ⚠ THESE ARE DECK BYTES AND REGISTRY FACTS. The adapter's own reader --
## `pz_root_kind` -- is pinned in tests/headless/test_ase_simcaps_0948.tcl
## section PV, and the four preconditions in tests/headless/test_ase_preflight.tcl
## section PF228, because those are the suites that own those seams.

check "PZ1 pz is offered, is now renderable, and carries a rank that sorts it\
 after tf and ahead of the five that still have none" \
  [list [expr {[lsearch -exact [ase::analysis_offered ngspice] pz] >= 0}] \
        [ase::analysis_renderable ngspice pz] \
        [ase::analysis_emit_rank pz 0 ngspice] \
        [lrange [ase::analysis_offered ngspice] 0 5]] \
  {1 1 60 {op dc ac tran tf pz}}

## ⚠ SIX TOKENS, ONE PER FIELD, AND NO `{build}` ESCAPE IN SIGHT. PLAN.md Stage 5
## spells this entry `{pz {build ase::backend::ngspice::an_pz_nodes} @transfer
## @mode}` -- §1c's composition escape, which Stage 1 never shipped (`tf`'s
## section above is where that was found). For `pz` it buys nothing at all:
## `pz NODE1 NODE2 NODE3 NODE4 {cur|vol} {pol|zer|pz}` is six space-separated
## words and the slot grammar joins tokens with a space, so four node fields ARE
## the four node tokens.
check "PZ2 pz emits the four nodes, the input type and the search, in ngspice's\
 own order, for each of the six combinations a user can pick" \
  [list [ase::analysis_line ngspice {type pz enabled 1 inp in inn 0 outp out outn 0 transfer vol mode pz}] \
        [ase::analysis_line ngspice {type pz enabled 1 inp in outp out mode pol}] \
        [ase::analysis_line ngspice {type pz enabled 1 inp in outp out mode zer}] \
        [ase::analysis_line ngspice {type pz enabled 1 inp in outp out transfer cur}] \
        [ase::analysis_line ngspice {type pz enabled 1 inp inp inn inn outp outp outn outn}]] \
  [list {pz in 0 out 0 vol pz} {pz in 0 out 0 vol pol} {pz in 0 out 0 vol zer} \
        {pz in 0 out 0 cur pz} {pz inp inn outp outn vol pz}]

check "PZ2b the Arguments column IS that line, so the pane cannot show a pz\
 setting the deck does not carry" \
  [ase::ui::arg_summary {type pz enabled 1 inp in outp out}] {pz in 0 out 0 vol pz}

## --- PZ2c: EVERY SLOT IS POSITIONAL, AND THE REFERENCES MAY NEVER VANISH -----
## ⚠ THIS IS THE ROW THAT WOULD NOTICE THE WORST SILENT DEFECT THIS ENTRY CAN
## HAVE. ngspice reads `pz` purely by position, so a dropped `inn` would emit
## `pz in out 0 vol pz` -- five words, rc 0, and ngspice solving between `in` and
## `out` as the INPUT pair and `0`/`vol` as the output pair. Nothing downstream
## could tell. `default 0` is what stops it today and `whenskipped 0` is what
## stops it if a later edit drops the default, so BOTH are asserted, and the
## second is asserted against `ase::analysis_expand` DIRECTLY -- with no row
## value and no field default in play, which is the only way to reach the
## back-fill arm at all.
set PZFLD [dict get [ase::analysis_entry ngspice pz] fields]
proc pzfd {flds n} {
  foreach f $flds { if {[dict get $f name] eq $n} { return $f } }
  return {}
}
## ⚠ THE KEY IS READ ABORT-PROOF, AND THAT IS NOT DEFENSIVE PADDING -- IT IS WHAT
## THE SABOTAGE ASKED FOR. A bare `dict get $fd whenskipped` is the natural
## spelling and it is only legal while the key is there, so the one change this
## row exists to catch -- `whenskipped 0` being deleted as redundant beside a
## `default` -- raised `key "whenskipped" not known in dictionary` and killed the
## whole file at 366 of 376 instead of reddening a row. A suite that dies names
## the defect with a line number; a row that reds names it with a sentence.
## MEASURED, not feared (sabotage S3).
proc pzkey {fd k} {
  if {![dict exists $fd $k]} { return ABSENT }
  return [dict get $fd $k]
}
check "PZ2c the two reference nodes carry a ground default AND a positional\
 back-fill value, so a pz line is the verb plus SIX arguments however little the\
 bench stores" \
  [list [ase::field_default [pzfd $PZFLD inn]] \
        [ase::field_default [pzfd $PZFLD outn]] \
        [pzkey [pzfd $PZFLD inn] whenskipped] \
        [pzkey [pzfd $PZFLD outn] whenskipped] \
        [llength [ase::analysis_line ngspice {type pz enabled 1 inp in outp out}]] \
        [ase::analysis_expand {inp in outp out} \
           {pz @inp @inn? @outp @outn? @mode?} \
           {{name inn whenskipped 0} {name outn whenskipped 0} \
            {name mode default pz}}]] \
  [list 0 0 0 0 7 {pz in 0 out 0 pz}]

## ⚠ AND WITH NOTHING TO ITS RIGHT A SKIPPED REFERENCE STILL VANISHES, which is
## the back-fill's own contract (section PB) and not a pz exception: the rule is
## "fill the hole only when something later still emits".
check "PZ2d a trailing skipped reference is dropped rather than padded" \
  [ase::analysis_expand {inp in outp out} {pz @inp @outp @outn?} \
     {{name outn whenskipped 0}}] {pz in out}

## ⚠ THE TWO PICKERS ARE `kind mode`, SO THEY ARE NOT NUMBER-CHECKED AND THEIR
## LEGAL VALUES ARE DECLARED. `pol`/`zer`/`pz` and `vol`/`cur` are ngspice's own
## words; the defaults are the ones a user means when they have said nothing.
## MEASURED 2026-09-12 on both binaries: omitting the search word leaves
## `PZwhich = 0` and ngspice does NEITHER search -- `Error: no such parameter on
## this device or parameter is missing`, rc 1 -- so an unset picker must still
## emit a word.
check "PZ2e the search and the input type declare their legal values and a\
 default that is always emitted" \
  [list [pzkey [pzfd $PZFLD mode] values] \
        [ase::field_default [pzfd $PZFLD mode]] \
        [pzkey [pzfd $PZFLD transfer] values] \
        [ase::field_default [pzfd $PZFLD transfer]] \
        [ase::analysis_emit_check ngspice {type pz enabled 1 inp in outp out mode zer}]] \
  [list {pz pol zer} pz {vol cur} vol {}]

## ⚠ ONLY THE TWO SIGNAL NODES ARE REQUIRED, AND THE DOOR NAMES THE ONE THAT IS
## MISSING. Requiring the references too would make the commonest pole-zero row
## in existence -- both references ground -- a four-box form.
check "PZ3 the commit door refuses a pz row missing either signal node, by name,\
 and passes one that names only those two" \
  [list [ase::analysis_emit_check ngspice {type pz enabled 1 outp out}] \
        [ase::analysis_emit_check ngspice {type pz enabled 1 inp in}] \
        [ase::analysis_emit_check ngspice {type pz enabled 1 inp in outp out}]] \
  [list {{missing inp {needs a value for 'inp'}}} \
        {{missing outp {needs a value for 'outp'}}} \
        {}]

check "PZ3b the four-state grid stops calling pz unrenderable" \
  [list [dict get [ase::analysis_state ngspice pz {}] state] \
        [dict get [ase::analysis_state ngspice noise {}] state] \
        [dict get [ase::analysis_state ngspice noise {}] reason]] \
  {ok blocked unrenderable}

## THE DECK. ⚠ ITS OWN READER, for the same reason section TF brought one: `pz`
## is not one of the four verbs `d8_lines` matches, and widening D8's regexp
## would take D8's rows along with it.
proc pz_lines {rows} {
  set st [nfet_state /models/sky130.lib.spice {}]
  dict set st analyses $rows
  if {[catch {$::render $st $::netlist_text} _rd]} { return "RAISED:$_rd" }
  set out {}
  foreach l [split $_rd "\n"] {
    if {[regexp {^(op|dc |ac |tran |tf |pz )} $l]} { lappend out [string trim $l] }
  }
  return $out
}
check "PZ4 an enabled pz row reaches the deck" \
  [pz_lines {{type pz enabled 1 inp in outp out}}] {{pz in 0 out 0 vol pz}}
## ⚠ RANK 60 PUTS IT AFTER `tf` AND op-LAST STILL WINS (issue 0964): the device
## requests sit immediately before `op` and ngspice's save list is sticky FORWARD
## ONLY, so `op` goes last however the other ranks sort.
check "PZ4b pz emits after tf in rank order, and op still goes last when the\
 deck asks for device parameters" \
  [list [pz_lines {{type pz enabled 1 inp in outp out} \
                   {type tf enabled 1 out v(D) insrc V1} \
                   {type op enabled 1}}] \
        [pz_lines {{type op enabled 1} {type pz enabled 1 inp in outp out}}]] \
  [list {op {tf v(D) V1} {pz in 0 out 0 vol pz}} {op {pz in 0 out 0 vol pz}}]
check "PZ4c a disabled pz row emits nothing at all" \
  [pz_lines {{type op enabled 1} {type pz enabled 0 inp in outp out}}] {op}

## --- PZ5: `pz` DECLARES NO `viewrank`, AND IT IS MEASURED AGAIN -------------
## ⚠ THE SAME ANSWER AS `tf` AND NOT A COPY OF ITS ARGUMENT. `pz` CAN emit and
## DOES produce data, so "a type nothing can emit produces no results" does not
## reach it either. MEASURED 2026-09-12 against a raw carrying an `Operating
## Point` plot and a `Pole-Zero Analysis` plot, through this tree's own binary:
##
##   xschem raw read both.raw pz                   -> `no useful data found` . 0
##   xschem raw read both.raw op                   -> sim_type=op ........... 1
##   xschem raw read both.raw {Pole-Zero Analysis} -> sim_type=Pole-Zero .... 1
##
## `src/save.c`'s `read_dataset()` has six NAMED `Plotname:` arms and then an
## exact `strcmp` against the plot name itself; `pz` is in neither set. ⚠ AND
## THERE IS A SECOND REASON HERE THAT `tf` DID NOT HAVE: a pz plot is a ROOT
## LIST -- `Flags: complex`, NO SCALE VECTOR, one data row -- so even a mapping
## would open the waveform viewer on something that is not a sweep.
proc pz_state {rows} {
  return [dict replace [ase::state_default] analyses $rows]
}
check "PZ5 a pz-only bench has NO viewer mapping, and says which of the two\
 silences it is" \
  [list [dict exists [ase::analysis_entry ngspice pz] viewrank] \
        [ase::plot_sim_type [pz_state {{type pz enabled 1 inp in outp out}}]] \
        [ase::plot_sim_type_reason [pz_state {{type pz enabled 1 inp in outp out}}]] \
        [ase::plot_sim_type_reason [pz_state {{type pz enabled 0 inp in outp out}}]]] \
  {0 {} no-viewer-mapping nothing-enabled}
## ⚠ NON-VACUITY. PZ5's first three answers are also what a registry with no `pz`
## entry at all would give, so this row proves the ABSENCE of the key is what
## produces them. ⚠ THE FIXTURE BORROWS ngspice's FIVE REQUIRED HOOKS (`ag_five`)
## and overrides only `analysis_types`, so the ONE difference from the shipped
## registry is the thing the row is about.
proc pzvr_types {} {
  return [dict create pz [dict create label pz registered 1 emitorder 60 \
    viewrank 5 fields {{name inp kind node required 1}} \
    emit {{role analysis tmpl {pz @inp}}}]]
}
ase::register_backend pzvr [dict merge [ag_five] \
  [dict create analysis_types pzvr_types]]
check "PZ5b a viewrank WOULD change that answer, so PZ5 is measuring the key and\
 not the absence of an entry" \
  [list [ase::plot_sim_type \
           [dict replace [pz_state {{type pz enabled 1 inp in}}] simulator pzvr]] \
        [ase::plot_sim_type_reason \
           [dict replace [pz_state {{type pz enabled 1 inp in}}] simulator pzvr]]] \
  {pz {}}

check "PZ6 pz is not in the seed, so a fresh bench still carries exactly the\
 four rows every committed bench carries" \
  [list [dict exists [ase::analysis_entry ngspice pz] seed_enabled] \
        [llength [ase::analysis_seed ngspice]] \
        [lsort [lmap _r [ase::analysis_seed ngspice] {ase::state_get $_r type}]]] \
  {0 4 {ac dc op tran}}

## ⚠ SCOPED TO pz, exactly as TF7 is scoped to tf: CP5 asks the same question of
## the WHOLE registry and would red for any entry, so a sabotage of pz's own
## fields or template is reported as a pz defect rather than as "the registry".
check "PZ7 pz's own entry is self-consistent: every slot its template spends is\
 a field it declares, and every field it declares is spent" \
  [lsearch -all -inline -index 0 -exact [ase::analysis_schema_errors ngspice] pz] {}

## --- PZ8: THE UPSTREAM MISLABEL, CARRIED VERBATIM ---------------------------
## ⚠ `pz`'s OPERATING-POINT PLOT IS CALLED `Distortion Operating Point`, and
## "fixing" it in the registry would make Stage 6's reader match nothing on every
## ngspice that exists. It is a copy-paste from `distoan.c` at `pzan.c:52-61`.
## MEASURED 2026-09-12 on the fork AND on apt 45.2, `.options keepopinfo` then
## `setplot`:
##
##   Current pz1   * keepopinfo pz plots (Pole-Zero Analysis)
##           op1   * keepopinfo pz plots (Distortion Operating Point)
##           const Constant values (constants)
##
## ⚠ AND THE ORDER OF THE TWO ROWS IS THE RESULT ORDER, NOT ALPHABETICAL: the
## analysis plot is the one that always exists, the operating-point plot arrives
## only under `keepopinfo` and carries its own `when`.
set PZPL [dict get [ase::analysis_entry ngspice pz] plots]
check "PZ8 the pz entry declares both plots ngspice can write, in result order,\
 and carries the upstream mislabel of the second exactly as ngspice spells it" \
  [list [llength $PZPL] \
        [pzkey [lindex $PZPL 0] select] [pzkey [lindex $PZPL 0] role] \
        [pzkey [lindex $PZPL 1] select] [pzkey [lindex $PZPL 1] role] \
        [pzkey [lindex $PZPL 1] when] \
        [dict exists [lindex $PZPL 0] vectors]] \
  [list 2 {Pole-Zero Analysis} table {Distortion Operating Point} opinfo \
        {opt keepopinfo} 0]

# --- SE: DC SENSITIVITY (Stage 5, issue 1428) -------------------------------
## `sens` was a `role probe` card and nothing else, exactly as `tf` and `pz`
## were: registered so the four-state grid could show that ngspice can tell you
## how much an output moves when each device parameter is perturbed, and
## `blocked/unrenderable` so nobody could ask it to.
##
## ⚠ **DC ONLY. THE `ac` MODE IS STAGE 6's**, and that is a scope line with two
## measured AC-ONLY defects behind it. MEASURED 2026-09-12 on the fork
## (`build-ver_50`) and on apt 45.2 alike:
##
##   sens v(mid) r1 ac lin 5 1k 5k -> 1.000000e+03 8.000000e+05 6.400000e+08
##                                    5.120000e+11 4.096000e+14   (each x800)
##   .options klu + sens v(mid) ac dec 1 1k 10k -> rc 139, SIGSEGV
##   .options klu + sens v(mid) dc              -> rc 0, and the numbers are
##                                    BYTE-FOR-BYTE the sparse ones
##
## Neither reaches DC. `inc_freq` (`cktsens.c:829-837`) is the sweep defect and
## `count_steps`' `SENS_DC` arm returns n=0/s=0, so the value it computes is
## never used; the KLU crash is the guard at `cktsens.c:97-105` being COMMENTED
## OUT, and note that the commented guard would have refused ALL sensitivity
## under KLU -- including the DC case measured safe and identical here.
##
## ⚠ THESE ARE DECK BYTES AND REGISTRY FACTS. The adapter's own reader --
## `sens_param_kind` -- is pinned in tests/headless/test_ase_simcaps_0948.tcl
## section SV, and the two preconditions in tests/headless/test_ase_preflight.tcl
## section PF229, because those are the suites that own those seams.

## ⚠ THE `label` IS ASSERTED HERE BECAUSE A SABOTAGE OF IT SURVIVED (S37).
## `label` is TODAY'S RADIO TEXT, not a human noun, and the registry says so in
## as many words -- promoting it to `Sensitivity` is NEW USER-FACING COPY and
## therefore ⚖ R9's to ratify, not a stage's to do in passing. Measured, it can
## be rewritten and `test_ase_core` and `test_ase_dialogs` both stay green.
## ⚠ AND THE OTHER TEN ENTRIES' LABELS ARE STILL UNASSERTED. This row closes the
## hole for `sens` only; whoever does the label-promotion stage inherits the
## rest, and inherits the measurement that nothing would have noticed.
check "SE1 sens is offered, is now renderable, keeps Stage 2's radio label, and\
 carries a rank that sorts it after pz and ahead of the four that still have\
 none" \
  [list [expr {[lsearch -exact [ase::analysis_offered ngspice] sens] >= 0}] \
        [ase::analysis_renderable ngspice sens] \
        [dict get [ase::analysis_entry ngspice sens] label] \
        [ase::analysis_emit_rank sens 0 ngspice] \
        [lrange [ase::analysis_offered ngspice] 0 6]] \
  {1 1 sens 70 {op dc ac tran tf pz sens}}

## ⚠ TWO FIELDS, NOT THE PLAN'S FIVE, AND THE `{build <proc>}` DECISION IS TAKEN
## HERE. PLAN.md Stage 5 spells this entry
## `{sens {build ase::backend::ngspice::an_sens_out} @filters? @modeargs}`, and
## §1c's composition escape was never shipped -- section TF above is where that
## was found (issue 1426), and the `tf` crew left the decision to this commit
## because `sens` is the last entry in the stage that wants it.
## ⚠ IT IS NOT BUILT, AND THE REASON IS A MEASUREMENT RATHER THAN THE COST. The
## escape's only gain is a STRUCTURED output picker, and
## `ase::backend::ngspice::out_decompose` -- registered as a hook by issue 1426,
## and pinned in section TV of test_ase_simcaps_0948.tcl -- already takes
## `v(a)`, `v(a,b)` and `i(src)` APART again. The structured data is recoverable
## from the one verbatim token whenever a surface wants it, so composition buys
## nothing a reader does not already give.
check "SE2 sens emits the output verbatim, the filter list when there is one,\
 and the mode word, for each of ngspice's three output forms" \
  [list [ase::analysis_line ngspice {type sens enabled 1 out v(mid)}] \
        [ase::analysis_line ngspice {type sens enabled 1 out v(mid,out)}] \
        [ase::analysis_line ngspice {type sens enabled 1 out i(Vsense)}] \
        [ase::analysis_line ngspice {type sens enabled 1 out v(mid) filters {r1 r2}}] \
        [ase::analysis_line ngspice {type sens enabled 1 out v(out) filters {r*:r m*:vth0}}]] \
  [list {sens v(mid) dc} {sens v(mid,out) dc} {sens i(Vsense) dc} \
        {sens v(mid) r1 r2 dc} {sens v(out) r*:r m*:vth0 dc}]

check "SE2b the Arguments column IS that line, so the pane cannot show a sens\
 setting the deck does not carry" \
  [ase::ui::arg_summary {type sens enabled 1 out v(mid) filters {r1 r2}}] \
  {sens v(mid) r1 r2 dc}

## --- SE2c: THE SKIPPED FILTER VANISHES, AND IT MAY NOT BACK-FILL ------------
## ⚠ THIS IS THE ROW THAT WOULD NOTICE `whenskipped` BEING ADDED HERE "FOR
## SAFETY", WHICH IS THE OPPOSITE OF WHAT THIS SLOT NEEDS. Section PB's rule is
## that a skipped POSITIONAL slot emits its `whenskipped` value whenever
## anything to its right still emits -- and the token to this slot's right is
## the LITERAL `dc`, which always emits. So a `whenskipped` here would put a
## word into every filterless sens line, for ever.
## ⚠ AND IT IS SAFE TO OMIT, WHICH IS MEASURED RATHER THAN ASSUMED. `sens` reads
## `dc` and `ac` as KEYWORDS wherever they stand and treats every earlier token
## as a filter (`inp2dot.c:529-565` pushes them onto `Sens_filter`), so nothing
## is promoted by a filter that is not there. MEASURED 2026-09-12 on both
## binaries: `sens v(mid) dc` -> rc 0, `$curplotname` = `Sensitivity Analysis`,
## the full ~90-vector table; `sens v(mid) r1 dc` -> the same plot with one
## vector. This is the one difference from `pz`, whose six slots are ALL
## positional and where both references therefore declare `whenskipped 0`.
set SEFLD [dict get [ase::analysis_entry ngspice sens] fields]
proc sefd {flds n} {
  foreach f $flds { if {[dict get $f name] eq $n} { return $f } }
  return {}
}
## ⚠ READ ABORT-PROOF, for the reason PZ2c records: a bare `dict get` on a key
## whose DELETION is the change the row exists to catch kills the file instead
## of reddening the row.
proc sekey {fd k} {
  if {![dict exists $fd $k]} { return ABSENT }
  return [dict get $fd $k]
}
check "SE2c the filter slot declares no positional back-fill and no default, so\
 a filterless row is the verb, the output and the mode word and nothing else" \
  [list [sekey [sefd $SEFLD filters] whenskipped] \
        [sekey [sefd $SEFLD filters] default] \
        [sekey [sefd $SEFLD filters] required] \
        [llength [ase::analysis_line ngspice {type sens enabled 1 out v(mid)}]] \
        [ase::analysis_expand {out v(mid)} {sens @out @filters? dc} \
           {{name filters whenskipped ZZ}}]] \
  [list ABSENT ABSENT 0 3 {sens v(mid) ZZ dc}]

## ⚠ ONLY THE OUTPUT IS REQUIRED, AND THE DOOR NAMES IT. ⚠ AND THE FILTER IS NOT
## NUMBER-CHECKED: `kind filter` is outside the four-kind ALLOW-LIST that GR7/GR8
## pin, which is what lets `r*:r` through a door that refuses `abc` for a
## `kind int` field.
check "SE3 the commit door refuses a sens row with no output, by name, passes\
 one that names only the output, and does not try to read a glob as a number" \
  [list [ase::analysis_emit_check ngspice {type sens enabled 1}] \
        [ase::analysis_emit_check ngspice {type sens enabled 1 out v(mid)}] \
        [ase::analysis_emit_check ngspice \
           {type sens enabled 1 out v(mid) filters {r*:r m*:vth0}}]] \
  [list {{missing out {needs a value for 'out'}}} {} {}]

check "SE3b the four-state grid stops calling sens unrenderable" \
  [list [dict get [ase::analysis_state ngspice sens {}] state] \
        [dict get [ase::analysis_state ngspice noise {}] state] \
        [dict get [ase::analysis_state ngspice noise {}] reason]] \
  {ok blocked unrenderable}

## THE DECK. ⚠ ITS OWN READER, for the reason sections TF and PZ brought one:
## `sens` is not among the four verbs `d8_lines` matches, and widening D8's
## regexp would take D8's rows along with it.
proc sens_lines {rows} {
  set st [nfet_state /models/sky130.lib.spice {}]
  dict set st analyses $rows
  if {[catch {$::render $st $::netlist_text} _rd]} { return "RAISED:$_rd" }
  set out {}
  foreach l [split $_rd "\n"] {
    if {[regexp {^(op|dc |ac |tran |tf |pz |sens )} $l]} { lappend out [string trim $l] }
  }
  return $out
}
check "SE4 an enabled sens row reaches the deck" \
  [sens_lines {{type sens enabled 1 out v(D) filters {m*:vth0}}}] \
  {{sens v(D) m*:vth0 dc}}
## ⚠ RANK 70 PUTS IT AFTER `pz` AND op-LAST STILL WINS (issue 0964): the device
## requests sit immediately before `op` and ngspice's save list is sticky FORWARD
## ONLY, so `op` goes last however the other ranks sort.
check "SE4b sens emits after pz in rank order, and op still goes last when the\
 deck asks for device parameters" \
  [list [sens_lines {{type sens enabled 1 out v(D)} \
                     {type pz enabled 1 inp in outp out} \
                     {type tf enabled 1 out v(D) insrc V1} \
                     {type op enabled 1}}] \
        [sens_lines {{type op enabled 1} {type sens enabled 1 out v(D)}}]] \
  [list {op {tf v(D) V1} {pz in 0 out 0 vol pz} {sens v(D) dc}} \
        {op {sens v(D) dc}}]
check "SE4c a disabled sens row emits nothing at all" \
  [sens_lines {{type op enabled 1} {type sens enabled 0 out v(D)}}] {op}

## --- SE5: `sens` DECLARES NO `viewrank`, AND IT IS MEASURED A THIRD TIME -----
## ⚠ THE SAME ANSWER AS `tf` AND `pz` AND NOT A COPY OF EITHER ARGUMENT.
## MEASURED 2026-09-12 against a raw carrying an `Operating Point` plot and a
## `Sensitivity Analysis` plot, through this tree's own binary:
##
##   xschem raw read both.raw sens                   -> `no useful data found` . 0
##   xschem raw read both.raw op                     -> sim_type=op ........... 1
##   xschem raw read both.raw {Sensitivity Analysis} -> sim_type=Sensitivity .. 1
##
## `src/save.c`'s `read_dataset()` has six NAMED `Plotname:` arms and then an
## exact `strcmp` against the plot name itself; `sens` is in neither set. ⚠ AND
## THE SECOND REASON IS `pz`'s: a DC sens plot is `Flags: real`, ONE data row,
## NO SCALE VECTOR -- a table, not a sweep. ⚠ AND THERE IS A THIRD HERE THAT
## NEITHER HAD: `Sensitivity Analysis` is the plot name of BOTH modes, so even a
## working mapping could not tell a DC row's results from an AC row's
## (APPENDIX §2.10, trap `[R-M11]`).
proc sens_state {rows} {
  return [dict replace [ase::state_default] analyses $rows]
}
check "SE5 a sens-only bench has NO viewer mapping, and says which of the two\
 silences it is" \
  [list [dict exists [ase::analysis_entry ngspice sens] viewrank] \
        [ase::plot_sim_type [sens_state {{type sens enabled 1 out v(D)}}]] \
        [ase::plot_sim_type_reason [sens_state {{type sens enabled 1 out v(D)}}]] \
        [ase::plot_sim_type_reason [sens_state {{type sens enabled 0 out v(D)}}]]] \
  {0 {} no-viewer-mapping nothing-enabled}
## ⚠ NON-VACUITY. SE5's first three answers are also what a registry with no
## `sens` entry at all would give, so this row proves the ABSENCE of the key is
## what produces them. ⚠ THE FIXTURE BORROWS ngspice's FIVE REQUIRED HOOKS
## (`ag_five`) and overrides only `analysis_types`, so the ONE difference from
## the shipped registry is the thing the row is about.
proc sevr_types {} {
  return [dict create sens [dict create label sens registered 1 emitorder 70 \
    viewrank 5 fields {{name out kind outvar required 1}} \
    emit {{role analysis tmpl {sens @out}}}]]
}
ase::register_backend sevr [dict merge [ag_five] \
  [dict create analysis_types sevr_types]]
check "SE5b a viewrank WOULD change that answer, so SE5 is measuring the key\
 and not the absence of an entry" \
  [list [ase::plot_sim_type \
           [dict replace [sens_state {{type sens enabled 1 out v(D)}}] simulator sevr]] \
        [ase::plot_sim_type_reason \
           [dict replace [sens_state {{type sens enabled 1 out v(D)}}] simulator sevr]]] \
  {sens {}}

check "SE6 sens is not in the seed, so a fresh bench still carries exactly the\
 four rows every committed bench carries" \
  [list [dict exists [ase::analysis_entry ngspice sens] seed_enabled] \
        [llength [ase::analysis_seed ngspice]] \
        [lsort [lmap _r [ase::analysis_seed ngspice] {ase::state_get $_r type}]]] \
  {0 4 {ac dc op tran}}

## ⚠ SCOPED TO sens, exactly as TF7 and PZ7 are scoped to their own types: CP5
## asks the same question of the WHOLE registry and would red for any entry.
check "SE7 sens's own entry is self-consistent: every slot its template spends\
 is a field it declares, and every field it declares is spent" \
  [lsearch -all -inline -index 0 -exact [ase::analysis_schema_errors ngspice] sens] {}

## --- SE8: ONE PLOT, AND A READER RATHER THAN A PREDICTOR --------------------
## ⚠ `sens` WRITES EXACTLY ONE PLOT AND ITS NAME IS THE SAME IN BOTH MODES.
## MEASURED 2026-09-12 on both binaries: `sens v(mid) dc` leaves `$plots` =
## `const sens1` and `$curplotname` = `Sensitivity Analysis`; APPENDIX §2.10 and
## trap `[R-M11]` record that `sens … ac` reports the SAME literal, which is why
## Stage 6 has to join on creation order rather than on the plot name.
## ⚠ AND IT DECLARES `paramname`, NOT `vectors`, FOR `pz`'s REASON: a `sens` row
## cannot know its own vector names. MEASURED, a four-device deck yields ~90 of
## them, and which ones exist depends on the device tables of the binary that
## runs it -- `v1 v1_freq v1_phase v1_pwr v1_z0` appear only because RFSPICE is
## on. A `vectors` key here would give one key two meanings across the registry.
## ⚠ `paramname` IS A THIRD OPAQUE KEY BESIDE `tf`'s `vectors` AND `pz`'s
## `rootname`, AND THAT IS DELIBERATE RATHER THAN OVERSIGHT: nothing in this tree
## reads any of the three yet, so collapsing them into one generic
## `resultname` would be a schema decision taken with ZERO consumers. Stage 6 is
## where a consumer arrives and where the generalisation belongs; this row is
## what will notice when it does.
set SEPL [dict get [ase::analysis_entry ngspice sens] plots]
check "SE8 the sens entry declares the one plot ngspice writes, names the\
 measured Plotname literal, and carries a result-name READER rather than a\
 vector list" \
  [list [llength $SEPL] \
        [sekey [lindex $SEPL 0] select] [sekey [lindex $SEPL 0] role] \
        [sekey [lindex $SEPL 0] paramname] \
        [dict exists [lindex $SEPL 0] vectors] \
        [dict exists [lindex $SEPL 0] rootname]] \
  [list 1 {Sensitivity Analysis} table ::ase::backend::ngspice::sens_param_kind 0 0]

## --- SE9: THE `results` DESTINATION, AND IT EXISTS BECAUSE A SABOTAGE SURVIVED
## ⚠ MEASURED (sabotage S35): `sens`'s `results {table {kind params}}` can be
## rewritten to `results {viewer {kind sweep}}` -- the exact claim Stage 6 will
## spend when it decides where a run's answers go -- and `test_ase_core`,
## `test_ase_simcaps_0948` AND `test_ase_preflight` ALL STAY GREEN. The key is
## read by nothing in this tree yet, so nothing notices.
## ⚠ AND THE ROW COVERS ALL THREE STAGE-5 ENTRIES, not `sens` alone, because
## `tf`'s and `pz`'s carry the same unasserted key for the same reason: they were
## written as the MEASURED destination for a consumer that does not exist. The
## three measurements are: a `tf` run produces three SCALARS in one plot; a `pz`
## run produces a root TABLE with no scale vector; a DC `sens` run produces a
## one-row TABLE of one number per perturbable parameter. If Stage 6 changes one
## of these it should be because the destination changed, and this row is what
## makes that a decision rather than an edit.
check "SE9 the three Stage 5 entries declare the result destination each of them was measured to produce, and none of them has drifted"   [list [dict get [ase::analysis_entry ngspice tf] results]         [dict get [ase::analysis_entry ngspice pz] results]         [dict get [ase::analysis_entry ngspice sens] results]]   [list {value {kind scalars}} {table {kind roots}} {table {kind params}}]

# --- CP: THE COMMITTED CORPUS, AS A PROPERTY --------------------------------
## ⚠ THE ACCEPTANCE CRITERION OF THIS WHOLE BATCH IS THAT THE COMMITTED BENCHES
## ROUND-TRIP BYTE-IDENTICALLY, and this section is the only thing in the tree
## that would notice if they stopped.
##
## MEASURED 2026-09-12 over every tracked `.state` file: 104 files, 416 analysis
## rows, exactly four rows per file, and these key sets and NO OTHERS --
##   ac   {enabled type} {enabled points start stop type}
##   dc   {enabled type} {enabled source start step stop type}
##   op   {enabled type}
##   tran {enabled type} {enabled step stop type}
## -- which is the fact that lets this stage refuse an unknown key at the commit
## door without breaking a single committed bench: there are no unknown keys.
##
## ⚠ WHY A CENSUS AND NOT A HASH. An opaque digest reds with one bit and tells
## you nothing about which bit. These rows red with a NAME -- the type whose key
## set moved, or the type whose emitted word count moved -- which is the whole
## difference between a row that gets fixed and a row that gets deleted.
##
## ⚠ AND WHY THE COUNTS ARE FLOORS WHILE THE SHAPES ARE EXACT. Adding a bench is
## ordinary work and must not red this suite; changing what a bench's row LOOKS
## LIKE is this batch's subject and must.
set CPF {}
if {[catch {exec git -C $repo ls-files -- *.state} cpout]} {
  set CPF {GIT-LS-FILES-FAILED}
} else {
  foreach cprel [split $cpout "\n"] {
    if {[string trim $cprel] ne {}} { lappend CPF [file join $repo $cprel] }
  }
}
set CPKEYS [dict create] ; set CPAR [dict create]
set CPN 0 ; set CPRPF {} ; set CPTARGET 0 ; set CPSOURCE 0
foreach cpf $CPF {
  if {[catch {open $cpf r} cpfh]} { continue }
  set cptxt [read $cpfh] ; close $cpfh
  foreach cpl [split $cptxt "\n"] {
    if {[string first {analyses } $cpl] != 0} { continue }
    if {[catch {lindex $cpl 1} cprows]} { continue }
    lappend CPRPF [llength $cprows]
    foreach cpr $cprows {
      incr CPN
      set cpty [ase::state_get $cpr type]
      set cpks [lsort [dict keys $cpr]]
      if {![dict exists $CPKEYS $cpty] \
          || [lsearch -exact [dict get $CPKEYS $cpty] $cpks] < 0} {
        dict lappend CPKEYS $cpty $cpks
      }
      if {[dict exists $cpr target]} { incr CPTARGET }
      if {[dict exists $cpr source]} { incr CPSOURCE }
      if {![llength [ase::analysis_emit_check ngspice $cpr]]} {
        set cpw [llength [ase::analysis_line ngspice $cpr]]
        if {![dict exists $CPAR $cpty] \
            || [lsearch -exact [dict get $CPAR $cpty] $cpw] < 0} {
          dict lappend CPAR $cpty $cpw
        }
      }
    }
  }
}
proc cpks {d ty} {
  if {![dict exists $d $ty]} { return {} }
  return [lsort [dict get $d $ty]]
}

check "CP1 every tracked state file in this repository is found and carries four\
 analysis rows, so the rows below speak for the whole corpus and not for a\
 subset a broken glob happened to reach" \
  [list [expr {[llength $CPF] >= 104}] [expr {$CPN >= 416}] \
        [lsort -unique $CPRPF]] {1 1 4}

check "CP2 the committed benches use these analysis-row key sets and no others,\
 which is why a commit door that refuses an unknown key breaks none of them" \
  [list [cpks $CPKEYS ac] [cpks $CPKEYS dc] [cpks $CPKEYS op] [cpks $CPKEYS tran]] \
  [list {{enabled points start stop type} {enabled type}} \
        {{enabled source start step stop type} {enabled type}} \
        {{enabled type}} \
        {{enabled step stop type} {enabled type}}]

## ⚠ THE BYTE-IDENTITY ROW. Every committed row that can be emitted still emits
## the same NUMBER OF WORDS it emitted before the field tables landed -- op one,
## dc five, ac five, tran three. A new default, a new back-fill or a new
## positional slot leaking into the committed corpus moves one of these four
## numbers and nothing else in the tree would notice.
check "CP3 every committed row still emits exactly the words it emitted before\
 the field tables landed" \
  [list [cpks $CPAR op] [cpks $CPAR dc] [cpks $CPAR ac] [cpks $CPAR tran]] \
  {1 5 5 3}

## ⚠ THE MEASUREMENT THAT OVERTURNED THE PLAN. This batch's own design sketch
## spelled the dc sweep variable `@target`. Not one committed row carries that
## key; 36 carry `source`. A required `@target` slot would have raised on every
## one of them.
check "CP4 no committed row carries a target key and the sweep variable is\
 spelled source, which is the measurement that chose the field name" \
  [list $CPTARGET [expr {$CPSOURCE >= 36}]] {0 1}

## ⚠ TF3, RESTATED AS A PROPERTY OF THE REGISTRY. Every field the form offers is
## consumed by a template, and every slot a template consumes is described by a
## field. A field no template reads is the Stage 3 defect itself -- a control the
## user fills in that reaches nothing.
check "CP5 this simulator's registry is self-consistent: no template consumes a\
 field the entry never describes, and no field is offered that no template reads" \
  [ase::analysis_schema_errors ngspice] {}

## ⚠ AND THE PROBE-ONLY ENTRIES MUST NOT BE SWEPT UP BY IT. Six registered
## types carry a `role probe` card and no `fields` at all; they are not a schema
## error, they are a type this backend can name and cannot yet set up. A
## validator that demanded fields of them would red six entries that are
## deliberately incomplete until Stage 6 gives them an emit.
##
## ⚠ IT WAS SEVEN, THEN SIX (Stage 5 `tf`, issue 1426), THEN FIVE (`pz`, issue
## 1427), AND IS NOW FOUR (`sens`, issue 1428). ALL THREE DEPARTED TYPES ARE
## NAMED ON BOTH SIDES RATHER THAN DROPPED FROM THE LIST. Deleting them from the
## walk would make this row read the same before and after, so the census would
## stop being a census; keeping them and asserting that they now HAVE fields is
## what makes the change visible here.
set CPPROBE 0
foreach cpt {noise pz sens disto sp pss} {
  set cpe [ase::analysis_entry ngspice $cpt]
  if {$cpe eq {} || [dict exists $cpe fields]} { continue }
  incr CPPROBE
}
check "CP6 the four probe-only types declare no fields, tf, pz and sens no\
 longer among them, and none of it is a schema error" \
  [list $CPPROBE [dict exists [ase::analysis_entry ngspice tf] fields] \
        [dict exists [ase::analysis_entry ngspice pz] fields] \
        [dict exists [ase::analysis_entry ngspice sens] fields] \
        [ase::analysis_schema_errors ngspice]] {4 1 1 1 {}}


# ===========================================================================
# RS / RD — ⚖ R3's reader seam: where ONE output row's number comes from
# (issue 1429). ⚖ R3 IS ASKED AND UNANSWERED; what is pinned here is
# DECISIONS.md's RECOMMENDATION, Option C, and the rows are written so that a
# later ruling of A or B moves ONE proc and deletes one reader.
#
# ⚠ SECTIONS RS AND RD CARRY THEIR OWN `catch`, because this file's OUTER one
# closes at the end of section SI, thousands of lines above here (issue 1428's
# S10 measured that: a raise below it produced FAILs and then no `RESULT:` and
# no `OVERALL:` line at all). A raise in here is a NAMED failure and the banner
# still prints.
# ===========================================================================
if {[catch {

## Build an ASCII rawfile the way ngspice writes one: a full header per plot,
## appended. `plots` is a list of {plotname flags {var val var val …}}; the
## point count is taken from the caller so a MULTI-point plot can be faked
## without writing its rows out.
proc r3_raw {plots {npoints 1}} {
  set out {}
  foreach p $plots {
    lassign $p pname pflags pvars
    set np [expr {[llength $p] > 3 ? [lindex $p 3] : $npoints}]
    append out "Title: * r3 fixture\n"
    append out "Date: Sat Sep 12 00:00:00  2026\n"
    append out "Plotname: $pname\n"
    append out "Flags: $pflags\n"
    append out "No. Variables: [expr {[llength $pvars]/2}]\n"
    append out "No. Points: $np\n"
    append out "Variables:\n"
    set i 0
    foreach {nm v} $pvars {
      append out "\t$i\t$nm\tvoltage\n"
      incr i
    }
    append out "Values:\n"
    set i 0
    foreach {nm v} $pvars {
      ## ⚠ `if`, NEVER `expr`. A ternary `expr` on two STRING branches evaluates
      ## them as arithmetic: the first draft of this fixture wrote
      ## `1.285714285714286-0.001714285714285714` into the file and every RD row
      ## read ABSENT, which looks exactly like a broken reader.
      if {$i == 0} { append out " 0\t$v\n" } else { append out "\t$v\n" }
      incr i
    }
    append out "\n"
  }
  return $out
}
## A state whose raw_file resolves to <scratch>/<cell>_ase.raw.
proc r3_state {cell outs} {
  set s [ase::state_default]
  dict set s design [dict create lib rl cell $cell view schematic]
  dict set s rundir $::scratch
  dict set s outputs $outs
  return $s
}
## ⚠ CAUGHT, for the reason written beside P1 above: the one change these rows
## exist to catch can make the dispatcher RAISE, and a raise here would kill the
## file instead of reddening a row.
proc r3_probe {st log} {
  set rc [catch {[ase::backend_hook ngspice result_probe] $st $log} r]
  if {$rc} { return "RAISED:$r" }
  return $r
}
proc r3_val {res k} { if {[dict exists $res $k]} { return [dict get $res $k] } ; return ABSENT }
## Run `script` with ase::result_source stubbed to one fixed answer — which is
## EXACTLY what a later ruling of ⚖ R3 A (raw) or B (log) does to that proc.
proc r3_ruled {answer script} {
  rename ::ase::result_source ::r3_saved_source
  proc ::ase::result_source {sim ex} "return $answer"
  set rc [catch {uplevel 1 $script} r]
  catch {rename ::ase::result_source {}}
  rename ::r3_saved_source ::ase::result_source
  if {$rc} { return "RAISED:$r" }
  return $r
}

# --- RS: the rule, and the one place it lives -------------------------------

## ⚠ THE RULE, ROW BY SHAPE. `out_decompose` (issue 1426) answers the `v()`/`i()`
## forms; everything else is a bare vector name or an expression. The three
## interesting answers are `v(a,b)` (TWO vectors — measured, `print v(in,mid)`
## echoes a number and there is no such vector in the results file), the bare
## analysis-result names Stage 5 measured, and the parenthesised shapes that no
## string test can tell apart from a function call.
set RSANS {}
## ⚠ `@r1` AND `-onoise_total` ARE HERE BECAUSE TWO SABOTAGES SURVIVED WITHOUT
## THEM. Adding `@` or `-` to the name alphabet changed NOTHING against the
## first draft of this list, because every other `@` shape it held (`@r1[i]`)
## also carries a bracket and every other `-` shape (`-i(v1)`) also carries a
## parenthesis — so the row could not see the alphabet it claims to pin. A bare
## `@dev` is the op-parameter seam's lead character (issue 0963/0965 built that
## on the LOG and it must stay there), and `-onoise_total` is a negated bare
## vector, which is an expression and not a name.
foreach rsx {v(mid) v(In) i(v1) v(in,mid) -i(v1) Transfer_function
             v1#Input_impedance onoise_total r1:r r.x1.ra:r r1_m
             {v(a)*2} {abs(v(mid))} output_impedance_at_V(mid)
             a[0] @r1[i] @r1 -onoise_total {"a[0]"} 42 {}} {
  lappend RSANS [ase::result_source ngspice $rsx]
}
check "RS1 the rule routes every measured output shape: a single vector to the\
 results file, an expression to the print log" $RSANS \
  [list raw raw raw log log raw raw raw raw raw raw \
        log log log log log log log log log log]

## ⚠ AN ADAPTER WITH NO `out_decompose` GETS TODAY'S BEHAVIOUR, NOT A GUESS.
## Without the hook there is nothing that knows `v(mid)` is one vector and
## `v(a,b)` is two, so the parenthesised forms fall to the log — which is where
## every one of them reads from today. The bare-name arm is backend-neutral and
## still answers, because a bare identifier is a vector name in any simulator
## that has vectors at all.
ase::register_backend r3nohook [dict create render_deck x run_cmd x log_file x \
  result_probe x raw_file x]
check "RS1b an adapter with no out_decompose sends every parenthesised form to\
 the log, and the bare-name arm still answers" \
  [list [ase::result_source r3nohook v(mid)] [ase::result_source r3nohook v(in,mid)] \
        [ase::result_source r3nohook Transfer_function]] {log log raw}

## ⚠ SEPARABILITY, STRUCTURALLY. This is the property the driver asked for in
## as many words: C is the SUPERSET of A and B, so a later ruling must remove a
## reader rather than invalidate the work. Neither reader may name the other,
## and neither may name the rule — otherwise deleting one of them is an edit to
## the survivor instead of a deletion.
set RSRAW [rg_body ::ase::backend::ngspice::result_probe_raw]
set RSLOG [rg_body ::ase::backend::ngspice::result_probe_log]
check "RS2 neither ⚖ R3 reader names the other or names the rule, so a ruling\
 of A or B deletes a proc instead of editing one" \
  [list [rg_has $RSRAW result_probe_log] [rg_has $RSRAW logtext] \
        [rg_has $RSRAW ase::result_source] \
        [rg_has $RSLOG result_probe_raw] [rg_has $RSLOG raw_file] \
        [rg_has $RSLOG raw_scalars] [rg_has $RSLOG ase::result_source]] \
  {0 0 0 0 0 0 0}

## ⚠ SEPARABILITY, BEHAVIOURALLY — AND THIS IS THE ROW THAT COSTS SOMETHING.
## RS2 only says the bodies do not mention each other. This one performs both
## later rulings by stubbing ase::result_source to one fixed answer, which is
## literally what ruling A (`return raw`) and ruling B (`return log`) do to that
## proc, and shows the whole surface changing from that one edit:
##   ruled A -> `v(a)*2` loses its number and `Transfer_function` keeps its one
##   ruled B -> `Transfer_function` loses its number and `v(a)*2` keeps its one
## A fixture whose rows did not DISAGREE could not adjudicate this, so the state
## deliberately carries one of each.
rg_wr [file join $scratch rsep_ase.raw] \
  [r3_raw {{{Operating Point} real {v(mid) 1.285714285714286e+00}}
           {{Transfer Function} real {v(Transfer_function) 4.285714285714286e-01}}}]
set RSST [r3_state rsep {{name {} expr v(mid) save 1}
                         {name {} expr Transfer_function save 1}
                         {name {} expr {v(a)*2} save 1}}]
set RSLOGTXT "v(mid) = 1.285714e+00\nTransfer_function = 9.999999e+09\nv(a)*2 = 2.571429e+00\n"
set RSC [r3_probe $RSST $RSLOGTXT]
set RSA [r3_ruled raw {r3_probe $RSST $RSLOGTXT}]
set RSB [r3_ruled log {r3_probe $RSST $RSLOGTXT}]
## The fixture log carries a DIFFERENT number for `Transfer_function`
## (9.999999e+09) from the one in the results file (4.285714e-01), so the row
## can say WHICH READER answered and not merely that a number appeared:
##   C (ships) -> the results file's number, because the name is one vector
##   A         -> the same, and the expression row loses its number
##   B         -> the LOG's rival number, and the expression row keeps its one
## ⚠ A fixture whose two sources agreed could not adjudicate this at all.
check "RS3 stubbing the ONE rule proc performs ruling A and ruling B end to\
 end: A drops the expression, B takes the log's rival number for the vector" \
  [list [r3_val $RSC v(mid)] [r3_val $RSC Transfer_function] [r3_val $RSC v(a)*2] \
        [r3_val $RSA Transfer_function] [r3_val $RSA v(a)*2] \
        [r3_val $RSB Transfer_function] [r3_val $RSB v(a)*2]] \
  [list 1.285714e+00 4.285714e-01 2.571429e+00 \
        4.285714e-01 ABSENT 9.999999e+09 2.571429e+00]

## ⚠ AND UNDER RULING A THE tf NUMBER IS STILL THE RAWFILE'S, NOT THE LOG'S.
## The fixture log deliberately carries a DIFFERENT number for
## `Transfer_function` (9.999999e+09) so that a reader silently falling back to
## the log cannot pass RS3 by accident.
check "RS3b the rawfile answer is the rawfile's: the log's rival number for the\
 same name is never taken" \
  [list [r3_val $RSC Transfer_function] [rg_has $RSLOGTXT 9.999999e+09]] \
  {4.285714e-01 1}

## ⚠ THE RULE IS STATED ON SCREEN, which is what ⚖ R3's recommendation asks for
## in as many words. Spied at ::ciw_echo, so the row proves the sentence really
## travelled ase::echo -> notify_safe -> notify -> ciw_echo.
set RSSAID [rg_ciw {r3_probe $RSST $RSLOGTXT}]
set RSRULE {}
foreach s $RSSAID {
  if {[rg_has [lindex $s 1] {names exactly one vector}]} { set RSRULE $s }
}
check "RS4 the rule is said on screen, with the split this run took" \
  [list [expr {$RSRULE ne {}}] [lindex $RSRULE 0] \
        [rg_has [lindex $RSRULE 1] {read from the results file}] \
        [rg_has [lindex $RSRULE 1] {read from the print log}] \
        [rg_has [lindex $RSRULE 1] {2 from the file, 1 from the log}]] \
  {1 note 1 1 1}

## ⚠ THE SENTENCE IS COMPUTED FROM THE RULE, NOT WRITTEN OUT AS PROSE, so a
## later ruling of A or B leaves it telling the truth without being edited.
set RSSAIDA [r3_ruled raw {rg_ciw {r3_probe $RSST $RSLOGTXT}}]
set RSRULEA {}
foreach s $RSSAIDA {
  if {[rg_has [lindex $s 1] {names exactly one vector}]} { set RSRULEA $s }
}
check "RS4b under ruling A the same sentence says 3 from the file and 0 from\
 the log, with no edit to it" \
  [rg_has [lindex $RSRULEA 1] {3 from the file, 0 from the log}] 1

# --- RD: the two readers over canned results files --------------------------

## ⚠ THE NUMBER ⚖ R3 PUTS ON SCREEN IS THE NUMBER THAT WAS THERE. Measured
## 2026-09-12: the results file carries `1.285714285714286e+00` where the log
## carries `v(mid) = 1.285714e+00`, and `%.6e` of the first IS the second, byte
## for byte. So Option C gives a number to rows that had none and changes no
## row that already had one — which is the whole reason it can be recommended
## without a ruling in hand.
rg_wr [file join $scratch rd1_ase.raw] \
  [r3_raw {{{Operating Point} real {v(in) 3.000000000000000e+00
                                    v(mid) 1.285714285714286e+00
                                    i(v1) -1.714285714285714e-03}}}]
set RD1 [r3_probe [r3_state rd1 {{name {} expr v(mid) save 1}
                                 {name {} expr i(v1) save 1}}] {}]
check "RD1 the rawfile reader answers a node voltage and a branch current, and\
 the rendering is `print`'s own" \
  [list [r3_val $RD1 v(mid)] [r3_val $RD1 i(v1)]] {1.285714e+00 -1.714286e-03}

## ⚠ THE `v(…)` WRAPPER IS THE FILE WRITER'S, NOT THE VECTOR'S NAME. Measured on
## both binaries: `display` after a `tf` shows `Transfer_function` bare, the
## results file spells it `v(Transfer_function)`. A user types what they can
## see, so the stripped spelling answers too.
rg_wr [file join $scratch rd2_ase.raw] \
  [r3_raw {{{Transfer Function} real {v(Transfer_function) 4.285714285714286e-01
                                      v(v1#Input_impedance) 1.750000000000000e+03}}
           {{Integrated Noise} real {v(onoise_total) 8.958985147582666e-07}}}]
set RD2 [r3_probe [r3_state rd2 {{name {} expr Transfer_function save 1}
                                 {name {} expr v1#Input_impedance save 1}
                                 {name {} expr onoise_total save 1}}] {}]
check "RD2 the three analyses ⚖ R3 exists for get a scalar home: tf's constant,\
 tf's input impedance and the noise integral" \
  [list [r3_val $RD2 Transfer_function] [r3_val $RD2 v1#Input_impedance] \
        [r3_val $RD2 onoise_total]] \
  {4.285714e-01 1.750000e+03 8.958985e-07}

## ⚠ THE CAPITALS ARE THE FORK'S AND apt 45.2 FOLDS THEM (issue 1426's C46).
## The SAME deck written by the two binaries spells the same vector
## `v(Transfer_function)` and `v(transfer_function)`. A case-sensitive reader
## works on the fork and is wrong on the binary a downloading user has, so the
## fixture here is apt 45.2's file read by a row typed in the fork's spelling.
rg_wr [file join $scratch rd3_ase.raw] \
  [r3_raw {{{Transfer Function} real {v(transfer_function) 4.285714285714286e-01}}}]
set RD3 [r3_probe [r3_state rd3 {{name {} expr Transfer_function save 1}}] {}]
check "RD3 the apt-45.2 folded spelling answers a row typed in the fork's" \
  [r3_val $RD3 Transfer_function] 4.285714e-01

## ⚠ AND THE FOLD IS THE CASEMODE BATCH'S RULE, NOT A SECOND ONE. Rung 2 is OFF
## under `distinguish`, for the reason item 11 measured: there the simulator
## REFUSES a differently-cased name, so a folded match would hand the row a
## number for a signal the run just said it does not have. Both readers obey the
## same resolver; this is the raw half of it.
set RD3B [r3_probe [r3_state rd3 {{name {} expr Transfer_function save 1}}] \
  "casemode=distinguish\n"]
check "RD3b …and under a distinguish-DELIVERING log the folded rung is off, so\
 the same row gets nothing rather than a differently-cased number" \
  [r3_val $RD3B Transfer_function] ABSENT

## ⚠ AND THE LADDER'S ORDER IS RUNG 1 FIRST, which is only visible in a file
## that holds BOTH spellings — the `distinguish` case. An exactly-spelled row
## reads its own vector and is never declined; the collision is the OTHER row's
## problem. This is the raw half of NC226e in test_ase_result_case.tcl, and the
## fixture deliberately contains the conflict the row adjudicates: a row whose
## answers did not disagree could not tell the two orders apart.
rg_wr [file join $scratch rd3d_ase.raw] \
  [r3_raw {{{Operating Point} real {v(In) 3.000000000000000e+00
                                    v(in) 9.000000000000000e+00}}}]
set RD3D [r3_probe [r3_state rd3d {{name {} expr v(In) save 1}
                                   {name {} expr v(mixed) save 1}}] {}]
check "RD3c rung 1 before rung 2: an exactly-spelled row reads its own vector\
 even though a differently-cased one sits beside it" \
  [r3_val $RD3D v(In)] 3.000000e+00

## ⚠ A MULTI-POINT VECTOR IS NOT A SCALAR, and that is issue 1243 arriving from
## the other side: a multi-point `print` emits a table that yields nothing, and
## a 20,514-row transient vector is the same non-answer. Excluding it is what
## keeps a tran-only run's Value column exactly as empty as it is today.
## ⚠ AND A COMPLEX ONE-POINT PLOT IS EXCLUDED TOO. Measured: `ac lin 1 1k 1k`
## writes a ONE-POINT complex plot and `print v(mid)` echoes
## `4.999951e-01,-1.57078e-03` — two numbers, which today's log regexp does not
## match either. A Value column holds one number.
rg_wr [file join $scratch rd4_ase.raw] \
  [r3_raw {{{Transient Analysis} real {v(tr) 1.000000000000000e+00} 20514}
           {{AC Analysis} complex {v(acv) 4.999951000000000e-01}}
           {{Operating Point} real {v(mid) 2.000000000000000e+00}}}]
set RD4 [r3_probe [r3_state rd4 {{name {} expr v(tr) save 1}
                                 {name {} expr v(acv) save 1}
                                 {name {} expr v(mid) save 1}}] {}]
check "RD4 a multi-point vector and a complex one are not scalars, and the\
 one-point real plot after them is still found" \
  [list [r3_val $RD4 v(tr)] [r3_val $RD4 v(acv)] [r3_val $RD4 v(mid)]] \
  {ABSENT ABSENT 2.000000e+00}

## ⚠ WHAT THE VALUE COLUMN SHOWS WHEN A RUN COMPUTED NOTHING: NOTHING.
## Measured 2026-09-12 on both binaries and reproduced independently by the
## driver: a `sens` filter matching nothing, and a save list resolving to
## nothing, BOTH exit 0 and write a results file whose only record is
## `Title: Constant values / Plotname: constants / No. Variables: 12`.
## ⚠ A READER THAT TREATED "NO VECTOR" AS ZERO WOULD REPORT A NUMBER FOR A RUN
## THAT COMPUTED NOTHING — and `i` is one of those twelve constants, so a reader
## that merely forgot to exclude the plot by name would answer for an output row
## called `i`. The plot is excluded BY NAME; that it is also `Flags: complex` on
## both binaries is a second, accidental guard and not the one relied on.
rg_wr [file join $scratch rd5_ase.raw] \
  [r3_raw {{constants complex {i 0.000000000000000e+00 pi 3.141592653589793e+00
                               e 2.718281828459045e+00}}}]
set RD5 [r3_probe [r3_state rd5 {{name {} expr i save 1} {name {} expr pi save 1}
                                 {name {} expr v(mid) save 1}}] {}]
check "RD5 a results file holding only the constants plot yields NO value at\
 all: not a zero, not a constant, nothing" [dict size $RD5] 0

## ⚠ NON-VACUITY FOR RD5. The same twelve numbers under a plot name that is not
## `constants` ARE read — so RD5 measures the exclusion and not the absence of a
## file, a variable list or a parseable number.
rg_wr [file join $scratch rd5b_ase.raw] \
  [r3_raw {{{Operating Point} real {i 0.000000000000000e+00 pi 3.141592653589793e+00}}}]
set RD5B [r3_probe [r3_state rd5b {{name {} expr pi save 1}}] {}]
check "RD5b non-vacuity: the same numbers under a plot name that is not\
 `constants` are read, so RD5 is about the name" [r3_val $RD5B pi] 3.141593e+00

## ⚠ THIS ROW EXISTS BECAUSE A SABOTAGE SURVIVED. Deleting the `constants` NAME
## test from ase::raw_scalars_wanted left this whole suite at ALL PASS (411):
## RD5's fixture is `Flags: complex`, which is what BOTH binaries really write,
## so the accidental guard was silently carrying the deliberate one. The name
## test is the one that must hold — a build that ever wrote the constants real
## must still not put `i` or `pi` in a user's Value column — so the fixture here
## is the same plot flagged `real`.
rg_wr [file join $scratch rd5c_ase.raw] \
  [r3_raw {{constants real {i 0.000000000000000e+00 pi 3.141592653589793e+00}}}]
set RD5C [r3_probe [r3_state rd5c {{name {} expr i save 1} {name {} expr pi save 1}}] {}]
check "RD5c the constants plot is excluded BY NAME: flagged `real` it is still\
 not read" [dict size $RD5C] 0

## ⚠ TWO VECTORS, TWO NUMBERS, NO GUESS — and the fixture contains the conflict
## the row adjudicates. Two `sens` rows in one run write two plots BOTH called
## `Sensitivity Analysis` (that is the identity problem Stage 6c's sidecar is
## for, and it is not built). Matched numbers that agree are one answer; matched
## numbers that differ are a question this reader cannot answer.
rg_wr [file join $scratch rd6_ase.raw] \
  [r3_raw {{{Sensitivity Analysis} real {v(r1) -7.000000000000000e-04
                                         v(agree) 5.000000000000000e-01}}
           {{Sensitivity Analysis} real {v(r1) -9.000000000000000e-04
                                         v(agree) 5.000000000000000e-01}}}]
set RD6ST [r3_state rd6 {{name {} expr r1 save 1} {name {} expr agree save 1}}]
set RD6 [r3_probe $RD6ST {}]
set RD6SAID [rg_ciw {r3_probe $RD6ST {}}]
set RD6DECL {}
foreach s $RD6SAID {
  if {[rg_has [lindex $s 1] {different numbers in the results file}]} { set RD6DECL $s }
}
check "RD6 one name, two different numbers: no value and the decline is said\
 on screen; one name, two EQUAL numbers: one answer" \
  [list [r3_val $RD6 r1] [r3_val $RD6 agree] [lindex $RD6DECL 0] \
        [rg_has [lindex $RD6DECL 1] {'r1'}] \
        [rg_has [lindex $RD6DECL 1] {Sensitivity Analysis}] \
        [rg_has [lindex $RD6DECL 1] {a guess would put a wrong number}]] \
  {ABSENT 5.000000e-01 error 1 1 1}

## ⚠ AND THE SAME NAME TWICE INSIDE ONE PLOT IS THE SAME QUESTION. Measured,
## issue 1428's finding: a deck carrying `R1` and `R1_temp` makes ngspice write
## `r1_temp` TWICE in one sensitivity plot — once as R1's instance `temp`
## parameter and once as R1_temp's own resistance. Two quantities, one name.
rg_wr [file join $scratch rd6b_ase.raw] \
  [r3_raw {{{Sensitivity Analysis} real {v(r1_temp) -1.000000000000000e-04
                                         v(r1_temp) 7.000000000000000e-01}}}]
set RD6B [r3_probe [r3_state rd6b {{name {} expr r1_temp save 1}}] {}]
check "RD6b the r1_temp collision — one name twice inside ONE plot — declines\
 too" [r3_val $RD6B r1_temp] ABSENT

## ⚠ THE `i(…)` FORM IS NOT STRIPPED, AND THAT IS MEASURED, NOT SYMMETRY.
## Stripping it would index `i(v1)` under the bare word `v1`, which is ALSO the
## sensitivity to source V1 — a manufactured collision between an operating
## point current and a sensitivity, in every run that enables both. The fixture
## carries exactly that pair.
rg_wr [file join $scratch rd7_ase.raw] \
  [r3_raw {{{Operating Point} real {i(v1) -1.714285714285714e-03}}
           {{Sensitivity Analysis} real {v(v1) 8.333333000000000e-01}}}]
set RD7 [r3_probe [r3_state rd7 {{name {} expr v1 save 1}
                                 {name {} expr i(v1) save 1}}] {}]
check "RD7 `v1` reads the sensitivity and `i(v1)` reads the current: the i()\
 wrapper is never stripped, so the two do not collide" \
  [list [r3_val $RD7 v1] [r3_val $RD7 i(v1)]] {8.333333e-01 -1.714286e-03}

## ⚠ A ROW WHOSE VECTOR IS NOT THERE HAS NO VALUE, AND IT IS SAID — but only
## when there IS a results file. A file that is not there at all is already
## reported, loudly, by ase::attach_dbs and ase::raw_content_verdict; saying it
## again per output row would be noise, and a probe called with a scratch state
## has no run behind it to describe.
set RD8ST [r3_state rd1 {{name {} expr nosuchvector save 1}}]
set RD8SAID [rg_ciw {r3_probe $RD8ST {}}]
set RD8MISS {}
foreach s $RD8SAID {
  if {[rg_has [lindex $s 1] {holds no single-point value}]} { set RD8MISS $s }
}
set RD9SAID [rg_ciw {r3_probe [r3_state rd_nofile {{name {} expr v(mid) save 1}}] {}}]
set RD9MISS 0
foreach s $RD9SAID {
  if {[rg_has [lindex $s 1] {holds no single-point value}]} { set RD9MISS 1 }
}
check "RD8 a missing vector in a results file that EXISTS is said on screen;\
 with no results file at all nothing is said twice" \
  [list [expr {$RD8MISS ne {}}] [lindex $RD8MISS 0] \
        [rg_has [lindex $RD8MISS 1] nosuchvector] $RD9MISS \
        [file exists [file join $scratch rd_nofile_ase.raw]]] \
  {1 note 1 0 0}

## ⚠ AND THE SENTENCE NAMES ONLY THE ROWS THE RAWFILE READER WAS GIVEN. An
## EXPRESSION never reaches that reader, so it can never be reported as a
## missing vector — which is the tell for a dispatcher that has stopped
## partitioning and is handing every row to both halves. Row written because
## that sabotage survived without it.
set RD8B [rg_ciw {r3_probe [r3_state rd1 {{name {} expr nosuchvector save 1}
                                          {name {} expr {v(mid)*7} save 1}}] {}}]
set RD8BM {}
foreach s $RD8B {
  if {[rg_has [lindex $s 1] {holds no single-point value}]} { set RD8BM [lindex $s 1] }
}
check "RD8b the missing-vector sentence names the vector row and never the\
 expression row" \
  [list [rg_has $RD8BM nosuchvector] [rg_has $RD8BM {v(mid)*7}]] {1 0}

## ⚠ THE READER NEVER FALLS BACK TO THE LOG, AND THIS IS THE ROW THAT SAYS SO.
## The rule on screen tells a user WHERE a row's number came from; a fallback
## would make that sentence false, and it would make a later ruling of ⚖ R3 A
## two changes instead of one. The fixture is the exact trap: `v(gone)` is not
## in the results file and IS in the log, with a number a fallback would
## happily show.
set RD12 [r3_probe [r3_state rd1 {{name {} expr v(gone) save 1}
                                  {name {} expr {v(gone)*2} save 1}}] \
  "v(gone) = 4.200000e+00\nv(gone)*2 = 8.400000e+00\n"]
check "RD12 a single-vector row absent from the results file gets NO value,\
 even though the log has one for it" \
  [list [r3_val $RD12 v(gone)] [r3_val $RD12 v(gone)*2]] {ABSENT 8.400000e+00}

## ⚠ THE TWO READERS' ANSWERS MERGE INTO ONE DICT, keyed exactly as
## ase::ui::output_result_key looks them up: `name` when the row has one, else
## the `expr` as stored. Nothing about the KEY changes in issue 1429 — only
## where the number was read.
rg_wr [file join $scratch rd10_ase.raw] \
  [r3_raw {{{Operating Point} real {v(mid) 1.285714285714286e+00}}}]
set RD10 [r3_probe [r3_state rd10 {{name vm expr v(mid) save 1}
                                   {name {} expr {v(mid)*2} save 1}}] \
  "v(mid)*2 = 2.571429e+00\n"]
check "RD10 one dict, both readers, keyed by name-or-expr as the Outputs pane\
 looks them up" \
  [list [r3_val $RD10 vm] [r3_val $RD10 v(mid)*2] [r3_val $RD10 v(mid)]] \
  {1.285714e+00 2.571429e+00 ABSENT}

## ⚠ WHY THE MERGE ORDER IN THE DISPATCHER CANNOT CHANGE AN ANSWER, and the
## row that keeps it that way. The dispatcher's comment claims RAW WINS A KEY
## CLASH. Measured: reversing the merge outright left this whole suite at ALL
## PASS, because a correct PARTITION gives the two readers DISJOINT key sets and
## there is no clash to win. That is a survivor by construction rather than a
## hole -- but the construction was unasserted, which is issue 1428's S35 class
## exactly (a key read by nothing is a key checked by nothing), so it is
## asserted here. A sabotage that breaks the partition reddens RS3, RD8b and
## RD12; this row is what says WHY the order beneath it is inert.
set RD13ST [r3_state rd10 {{name {} expr v(mid) save 1}
                           {name {} expr {v(mid)*2} save 1}}]
set RD13R [ase::backend::ngspice::result_probe_raw \
  [dict set RD13ST outputs {{name {} expr v(mid) save 1}}]]
set RD13L [ase::backend::ngspice::result_probe_log \
  [dict set RD13ST outputs {{name {} expr {v(mid)*2} save 1}}] \
  "v(mid)*2 = 2.571429e+00\n"]
set RD13BOTH {}
foreach k [dict keys $RD13R] {
  if {[dict exists $RD13L $k]} { lappend RD13BOTH $k }
}
check "RD13 the two readers' answers have disjoint keys, which is why the\
 dispatcher's merge order is inert" \
  [list [dict keys $RD13R] [dict keys $RD13L] $RD13BOTH] \
  [list v(mid) v(mid)*2 {}]

## ⚠ THE DISPATCHER MUST NOT RAISE FOR A STATE THAT HAS NO RESULTS FILE PATH,
## and that is a production contract and not a test convenience:
## `ase::run_done` calls it on EVERY completion, including runs that failed
## before a design was resolved. ase::backend::ngspice::raw_file raises on a
## state with no `design cell`, so the path resolution is caught. Removing that
## `catch` killed this file at row P1 -- see the note there.
set RD14ST [ase::state_default]
dict set RD14ST outputs {{name {} expr v(mid) save 1}
                         {name {} expr {v(mid)*2} save 1}}
set RD14 [r3_probe $RD14ST "v(mid)*2 = 2.571429e+00\n"]
check "RD14 a state with no design cell answers its log rows and does not\
 raise" \
  [list [r3_val $RD14 v(mid)] [r3_val $RD14 v(mid)*2]] {ABSENT 2.571429e+00}

## ⚠ THE CASEMODE NOTE IS SAID ONCE PER RUN, NOT ONCE PER READER. The dispatcher
## resolves the case rule and hands the same answer to both halves; a reader
## resolving it for itself would announce a delivered `distinguish` twice.
set RD11SAID [rg_ciw {r3_probe [r3_state rd10 {{name {} expr v(mid) save 1}
                                               {name {} expr {v(mid)*2} save 1}}] \
  "casemode=distinguish\nv(mid)*2 = 2.571429e+00\n"}]
set RD11N 0
foreach s $RD11SAID {
  if {[rg_has [lindex $s 1] {this log says the simulator ran with}]} { incr RD11N }
}
check "RD11 the delivered-casemode note is said once per run, not once per\
 reader" $RD11N 1

} r3err]} {
  check "RS0 sections RS and RD ran to the end" "RAISED:$r3err" {}
}
# --- verdict -----------------------------------------------------------------
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
# ⚠ THE SECOND SENTINEL, AND IT IS WHAT LETS run_regression.tcl READ THIS FILE
# AT ALL (issue 1413). There are TWO completion banners in this tree:
# `run_suites.sh` accepts either `RESULT: ALL PASS` or `OVERALL: ok` (issue 0228),
# while `tests/banner_rule.tcl` -- the rule `run_regression.tcl` consumes --
# accepts ONLY a whole-line `OVERALL: ok` with an optional parenthesised trailer.
# A suite printing `RESULT:` alone is scored a HARNESS FAILURE by T1 however many
# of its own checks passed, which is issue 0689's shape, filed four times.
#
# MEASURED: this suite printed `RESULT:` and nothing else, so it could not be
# added to T1's case list -- and seven commits of the analyses batch were reported
# as "T1 at zero" while T1 ran only FOUR test_ase_* suites and never this one.
# The suites were run separately every time, so the work was verified; the NUMBER
# was quoted for more than it covered. `test_ase_simcaps_0948` and
# `test_ase_optier_0963` already emit both, which is exactly why THEY are in T1.
if {$fail == 0} {
  puts "OVERALL: ok"
} else {
  puts "OVERALL: notok"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
