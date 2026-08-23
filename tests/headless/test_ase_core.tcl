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
#   C* op cards:    the save_op_params gate key ({} = off, omitted from the
#                   serialized form), the op-cards capture/consume seam, and
#                   render_deck appending op_annot::save_cards VERBATIM above
#                   `.control` on a cache hit (plan step S4 / issue 0617)
#   N* netlist:     ase::netlist on a scratch lib/cell/view fixture, rundir
#                   defaulting to $netlist_dir
#   E* run:         real ngspice batch end-to-end (Id ~ 4.096837e-04, leg
#                   SKIPPED if ngspice absent), missing-binary clean error via
#                   a fake backend, unknown-simulator clean error
#
# The nfet fixture (nfet_test_claude MINUS its corner + simulator_commands
# instances) is embedded verbatim below and written into a scratch
# lib/cell/view registered through a scratch library.defs — no dependency on
# untracked workarea cells. The model path is injected via the STATE (never
# hardcoded in ase.tcl), pointing at the tracked sky130A workarea models file.
#
# True headless (no X). Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl

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
set models  [file join $repo sky130A models libs.tech combined sky130.lib.spice]
source [file join $here scratch.tcl]
set scratch [test_scratch ase_core]

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
check "R1 default has exactly the 17 schema keys" [lsort [dict keys $d]] \
  [lsort {version simulator design rundir temperature models variables analyses outputs save_all_v save_all_i save_op_params options includes pre_commands cosim viewer}]
check "R1 cosim defaults to empty and is omitted from the serialized form" \
  [list [dict get $d cosim] [expr {[string first "cosim" [ase::state_serialize $d]] >= 0}]] {{} 0}
check "R1 a NON-empty cosim IS serialized" \
  [expr {[string first "cosim {build never}" \
     [ase::state_serialize [dict replace $d cosim {build never}]]] >= 0}] 1
# --- C2/C3: the save_op_params gate key (plan step S4) -----------------------
# doc/claude/suggestions/next_session_prompt_op_annotation.md S4 + the S4 plan's
# first decision. The gate key MUST default to `{}` and MUST join
# ase::omit_if_empty, NOT default to `0`: ase::state_serialize (ase.tcl:344)
# writes every non-empty schema key, so a `0` default lands in all 104 committed
# .state files and reddens five load->save byte-identity rows (F3 in
# test_ase_final, G3 in test_ase_final_gf180, R4 below, V4 in test_ase_view,
# R2 in test_ase_persist). `cosim` is the precedent this copies.
#   {} = off (the default), 1 = on.
# sentinel default: a MISSING key must read as `<absent>`, never as the `{}`
# the row is asserting, or the check would pass vacuously on a tree without it
check "C2 save_op_params defaults to empty (= off)" \
  [ase::state_get $d save_op_params <absent>] {}
check "C2 save_op_params is OMITTED from the serialized default state" \
  [expr {[string first "save_op_params" [ase::state_serialize $d]] >= 0}] 0
check "C2 save_op_params sits right after save_all_i in the canonical order" \
  [lsearch -exact $ase::schema_keys save_op_params] \
  [expr {[lsearch -exact $ase::schema_keys save_all_i] + 1}]
check "C2 save_op_params is in ase::omit_if_empty" \
  [expr {[lsearch -exact $ase::omit_if_empty save_op_params] >= 0}] 1
check "C3 save_op_params 1 IS serialized (the key is not write-only)" \
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
op
print -i(v1)
remzerovec
write @RAWFILE@
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
set c_missing {}
foreach c {::ase::op_cards_capture ::ase::op_cards_for ::ase::op_cards_put
           ::ase::op_cards_clear ::ase::design_is_dirty} {
  if {[info commands $c] eq {}} { lappend c_missing $c }
}
check "C0 the S4 op-cards seam exists" $c_missing {}

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
set stC [nfet_state /models/sky130.lib.spice {}]
set deckC5 [$render $stC $netlist_text]
check "C5 gate off emits no device save cards" [llength [c_cards $deckC5]] 0
check "C5 gate off emits no op_annot marker line" [c_marker $deckC5] 0
check_true "C5 gate off is byte-identical to the D1 golden" \
  [string equal $deckC5 $expected_deck]

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
set deckC8off [$render [nfet_state /models/sky130.lib.spice {}] $netlist_text]
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
set logtext_p1 "Some banner line\n-i(v1) = 4.096837e-04\nNo. of Data Rows : 1\n"
set stp [ase::state_default]
dict set stp outputs {{expr -i(v1) save 1}}
set resp [$probe $stp $logtext_p1]
set got {}
if {[dict exists $resp -i(v1)]} { set got [dict get $resp -i(v1)] }
check "P1 result_probe keys unnamed outputs by expr" $got 4.096837e-04
set stp [ase::state_default]
dict set stp outputs {{name id expr -i(v1) save 1}}
set resp [$probe $stp $logtext_p1]
set got {}
if {[dict exists $resp id]} { set got [dict get $resp id] }
check "P1 named output still keyed by name" $got 4.096837e-04

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
set caught [catch {ase::run $st} err]
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
