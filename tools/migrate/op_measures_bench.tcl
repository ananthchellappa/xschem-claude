# tools/migrate/op_measures_bench.tcl -- run one committed ASE-L bench for
# real, inside xschem, the way ASE-L runs it, and report what came back.
#
# Sourced (never run on its own) by tools/migrate/op_measures_vars.tcl, which
# measures the operating-point vectors tools/migrate/op_measures.tcl derives
# its table from, and by band OM7 of tests/headless/test_ase_op_measures.tcl,
# which holds the converted rows to the simulator.
#
# opm::setup <repo> <ngspice>
#     Register the three bundled workareas' library registries, model and
#     OSDI variables at once (each PDK's own cadence_style_rc does the same for
#     one PDK; that rc also builds Tk menus, so it is not sourced here), and
#     register and select the given ngspice.
# opm::run <repo> <staterel> <rundir>
#     Load the bench's schematic, open its committed state, point the run
#     directory at <rundir>, run (ase::run: netlist + deck + simulator) and
#     wait.  Answers a dict: rc (the simulator's exit code, or RAISED with the
#     refusal in `why`), raw (the results file), results (output result key ->
#     the Value cell's answer), outputs (the state's rows), opvars (every
#     vector of the results file's operating point, as `xschem raw list`
#     spells it), deck (the rendered deck's path).
namespace eval opm {}

proc opm::setup {repo ngspice} {
  set ::no_recent_files 1
  set ::SKYWATER_MODELS [file join $repo sky130A models libs.tech combined]
  set ::MODELS_NGSPICE [file join $repo ihp-sg13g2 models]
  set ::SG13G2_MODELS $::MODELS_NGSPICE
  set ::SG13G2_OSDI [file join $repo ihp-sg13g2 osdi]
  set defs {}
  foreach pdk {sky130A ihp-sg13g2 gf180mcuD} {
    lappend defs [file join $repo $pdk xschem_libs library.defs]
  }
  set ::XSCHEM_LIBRARY_DEFS [join $defs :]
  set ::library_registry_defs_only 1
  foreach p {sky130A/sky130_procs.tcl ihp-sg13g2/sg13g2_procs.tcl} {
    catch {uplevel #0 [list source [file join $repo $p]]}
  }
  ase::sim_register opm_ngspice $ngspice
  ase::sim_select opm_ngspice
}

proc opm::schematic {repo staterel} {
  set p [file split $staterel]
  return [file join $repo [lindex $p 0] xschem_libs [lindex $p 2] [lindex $p 3] \
            schematic [lindex $p 3].sch]
}

proc opm::run {repo staterel rundir} {
  set out [dict create rc NORUN why {} raw {} results {} outputs {} opvars {} deck {}]
  set sch [opm::schematic $repo $staterel]
  if {![file isfile $sch]} { dict set out why "no schematic $sch" ; return $out }
  catch {xschem raw clear}
  xschem load $sch
  set dsg [ase::design_of_path [file normalize $sch]]
  set key [ase::session_key {*}$dsg]
  catch {ase::session_close $key}
  ase::session_open $key [file join $repo $staterel]
  set st [ase::session_state $key]
  file mkdir $rundir
  dict set st rundir $rundir
  ase::session_update $key $st
  set st [ase::session_state $key]
  dict set out outputs [ase::state_get $st outputs]
  if {[catch {ase::run $st} xid]} {
    dict set out rc RAISED
    dict set out why $xid
    catch {ase::session_close $key}
    return $out
  }
  dict set out rc [ase::wait $xid]
  dict set out results [ase::last_result]
  set raw [[ase::backend_hook ngspice raw_file] $st]
  dict set out raw $raw
  set cell [lindex [file split $staterel] 3]
  dict set out deck [file join $rundir ${cell}_ase.spice]
  catch {xschem raw clear}
  if {[file isfile $raw] && ![catch {xschem raw read $raw op}]} {
    dict set out opvars [lsort [split [string trim [xschem raw list]] "\n"]]
  }
  catch {xschem raw clear}
  catch {ase::session_close $key}
  return $out
}
