# Interp-result contamination by prepare_netlist_structs (issue 0155).
#
# prepare_netlist_structs() calls set_modify(-2), which (src/actions.c, gated on
# has_x) runs `tclvareval("catch {...}")` to recolor the Netlist/Simulate/Waves
# menu entries. Tcl's `catch` evaluates to "0", so prep RETURNS WITH "0" SITTING
# IN THE INTERP RESULT. Every `xschem` verb that calls prep and then APPENDS its
# answer (rather than SETTING it) therefore emits a stray leading "0" -- but only
# on a COLD call (prep early-returns when xctx->prep_hi_structs / prep_net_structs
# is already set) and only under a GUI (`--pipe` with a DISPLAY); the `--nogui`
# arm never reaches the has_x-gated catch, so it is immune.
#
# That is why this bug survived: it is invisible to the headless arm the suite
# runs most, and invisible to any second call.
#
# Measured at 53d2cd19 (GUI arm, cold):
#   xschem resolved_net OUT      -> 0OUT      (should be OUT)
#   xschem resolved_net          -> 0         (should be empty)
#   xschem list_hilights         -> 0OUT      (a corrupted NET NAME, not cosmetic)
#   xschem list_hilights all     -> "0.  ..." (first entry's PATH field)
#   xschem instance_nodemap V1   -> 0V1 p ... (a corrupted INSTANCE NAME)
# while the siblings fixed in c99beb26 (`net` / `nets` / `net_members`, which
# reset AFTER prep) and every verb that uses Tcl_SetResult (which REPLACES the
# result) stay clean.
#
# Legs (RC*):
#   RC1-RC3   resolved_net: cold by-name, warm by-name, cold zero-arg.
#   RC4-RC6   list_hilights (no-arg and `all`) and instance_nodemap.
#   RC7       `xschem nets` does NOT warm list_hilights: prep(0) sets
#             prep_hi_structs, list_hilights needs prep(1)/prep_net_structs.
#   RC8-RC10  controls that must stay clean: the three c99beb26 siblings.
#   RC11      teeth witness -- prints whether this run could see the defect at
#             all. Without a DISPLAY every leg passes vacuously.
#
# The assertions are the CORRECT values in both arms, so the file is safe to run
# headless; it simply has no teeth there. Run it with a DISPLAY to test the fix:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_prep_result_contamination_0155.tcl

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set no_recent_files 1                       ;# issue 0119: keep Open Recent clean

set here    [file normalize [file dirname [info script]]]
set repo    [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch prep_result_0155]

if {[catch {

# --- fixture -----------------------------------------------------------------
# V1 --(OUT)-- R1 --(unlabeled -> #net1)-- gnd. One named net is all the verbs
# under test need; the auto-named one keeps `nets` non-trivial.
set fxpath [file join $scratch prep_result.sch]
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
close $f

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

# A COLD context: `xschem load` leaves prep_hi_structs / prep_net_structs clear,
# so the next prep-calling verb actually runs prep (and, unfixed, dirties the
# result). Every leg below re-loads so it is not warmed by the previous one.
proc cold {} { global fxpath ; xschem load $fxpath ; catch {xschem unhilight_all} }

# has_x witness: the contamination source is gated on it. Tk exists in the
# `--pipe` arm and not under `--nogui`.
set teeth [expr {[info commands winfo] ne {} && ![catch {winfo exists .}]}]

cold
check "RC0 fixture loads and carries the named net OUT" \
  [llength [lsearch -all -inline [xschem nets] {name {OUT}*}]] 1

# --- RC1-RC3  resolved_net ---------------------------------------------------
cold
check "RC1 resolved_net OUT is clean on a COLD call"  [xschem resolved_net OUT] {OUT}
check "RC2 resolved_net OUT is clean on a WARM call"  [xschem resolved_net OUT] {OUT}

cold
xschem unselect_all
check "RC3 zero-arg resolved_net with nothing selected is EMPTY (cold)" \
  [xschem resolved_net] {}

# --- RC4-RC6  list_hilights / instance_nodemap -------------------------------
cold
xschem hilight_netname OUT
check "RC4 list_hilights names the net, uncorrupted (cold)" [xschem list_hilights] {OUT}

cold
xschem hilight_netname OUT
set paths {}
foreach ln [split [xschem list_hilights all] "\n"] {
  if {[string trim $ln] eq {}} continue
  lappend paths [lindex [regexp -all -inline {\S+} $ln] 0]
}
check "RC5 every `list_hilights all` PATH field is the top-level dot (cold)" \
  [lsort -unique $paths] {.}

cold
check "RC6 instance_nodemap starts with the instance name, not 0<name> (cold)" \
  [lindex [xschem instance_nodemap V1] 0] {V1}

# --- RC7  prep(0) does not warm a prep(1) consumer ---------------------------
cold
xschem hilight_netname OUT
xschem nets                                  ;# prep(0): sets prep_hi_structs only
check "RC7 list_hilights still clean after a prep(0) verb (it runs prep(1))" \
  [xschem list_hilights] {OUT}

# --- RC8-RC10 controls: the c99beb26 siblings must stay clean ----------------
cold
check "RC8 (control) cold `nets` starts with a well-formed descriptor" \
  [string match "\{name \{*" [xschem nets]] 1
cold
check "RC9 (control) cold `net OUT` starts with its name field" \
  [string range [xschem net OUT] 0 4] {name }
cold
check "RC10 (control) cold `net_members OUT` starts with its wires field" \
  [string range [xschem net_members OUT] 0 5] {wires }

# --- RC11 teeth witness ------------------------------------------------------
puts "TEETH: [expr {$teeth ? {yes -- GUI arm, has_x gate is open, legs are live}
                           : {NO  -- --nogui arm, every leg passes vacuously}}]"
check "RC11 teeth witness reported" [expr {$teeth in {0 1}}] 1

} err]} { puts "FATAL: $err" ; incr fail }

if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
