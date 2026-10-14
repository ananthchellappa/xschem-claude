# tools/migrate/op_measures_vars.tcl -- measure, on the real simulator, which
# vectors each named bench's operating point holds; the input
# tools/migrate/op_measures.tcl --vars reads.
#
# Runs INSIDE xschem (it starts no xschem of its own), headless, with DISPLAY
# removed and a throwaway HOME, e.g. from the repo root:
#   OPM_REPO=$PWD OPM_OUT=<dir> OPM_NGSPICE=<registry ngspice> \
#   OPM_STATES="<state> <state> ..." \
#   env -u DISPLAY HOME=<scratch> ./src/xschem --nogui --pipe -q \
#       --script tools/migrate/op_measures_vars.tcl
# (tools/migrate/op_measures.tcl --need prints the OPM_STATES list.)
#
# For each state it writes <OPM_OUT>/<key>.opvars, one `xschem raw list` name
# per line, or <key>.norun holding why the bench produced no operating point
# here; <key> is the state's repo-relative path with every / spelled %.
set repo $::env(OPM_REPO)
source [file join $repo tools migrate op_measures_bench.tcl]
opm::setup $repo $::env(OPM_NGSPICE)
file mkdir $::env(OPM_OUT)
foreach rel $::env(OPM_STATES) {
  set k [string map {/ %} $rel]
  set r [opm::run $repo $rel [file join $::env(OPM_OUT) run $k]]
  if {[dict get $r rc] eq {0} && [llength [dict get $r opvars]]} {
    set f [open [file join $::env(OPM_OUT) $k.opvars] w]
    puts $f [join [dict get $r opvars] "\n"]
    close $f
    puts "measured $rel ([llength [dict get $r opvars]] vectors)"
  } else {
    set why [dict get $r why]
    # a refusal's first sentence; the rest names this run's scratch directory
    regsub {\. .*$} $why {} why
    if {$why eq {}} {
      set why "the simulator exited [dict get $r rc]"
      set lf [file join $::env(OPM_OUT) run $k [lindex [file split $rel] 3]_ase.log]
      if {[file isfile $lf]} {
        set fh [open $lf r] ; set lt [read $fh] ; close $fh
        if {[regexp -line {^Error: (.*)$} $lt -> e]} { append why ": [string trim $e]" }
      }
    }
    set f [open [file join $::env(OPM_OUT) $k.norun] w]
    puts $f [string map {"\n" " "} $why]
    close $f
    puts "norun $rel: $why"
  }
}
exit 0
