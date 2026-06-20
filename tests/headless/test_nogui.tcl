# Headless smoke test for the --nogui flag.
#
# Run via:  xschem --nogui --pipe -q --script test_nogui.tcl
# (the run_nogui.sh wrapper sets things up and checks the result).
#
# "True headless" means: even when DISPLAY is set, xschem must never connect to
# the X server and never load Tk -- so no top level window can be mapped. We can
# prove that from inside the interpreter: if Tk is not loaded, none of its
# commands (winfo/wm/tk) exist, hence no window exists. We then confirm the core
# engine still works without any GUI by loading a schematic and netlisting it.

set fail 0
proc check {cond msg} {
  global fail
  if {$cond} { puts "ok   - $msg" } else { puts "FAIL - $msg" ; set fail 1 }
}
# evaluate an expression in the caller's scope and report it
proc check_expr {expr_str msg} { check [uplevel 1 [list expr $expr_str]] $msg }

if {[info exists env(DISPLAY)] && [string length $env(DISPLAY)]} {
  puts "info - DISPLAY=$env(DISPLAY) (set: --nogui must still open no window)"
} else {
  puts "info - DISPLAY unset"
}

# 1) In true headless mode Tk is never initialized, so its commands do not exist
#    and therefore no top level window can have been created/mapped.
check_expr {[llength [info commands winfo]] == 0} "Tk not loaded (winfo absent) -> no window possible"
check_expr {[llength [info commands wm]]    == 0} "Tk not loaded (wm absent)"
check_expr {[llength [info commands tk]]    == 0} "Tk not loaded (tk absent)"

# 2) The C side leaves the Tcl 'has_x' variable unset on the headless path.
check_expr {![info exists has_x]} "has_x Tcl var unset (C took headless path)"

# 3) The engine still works with no GUI: load a schematic and netlist it.
if {[info exists env(XSCHEM_NOGUI_TESTSCH)] && [file exists $env(XSCHEM_NOGUI_TESTSCH)]} {
  set sch $env(XSCHEM_NOGUI_TESTSCH)
  if {[catch {xschem load $sch} err]} {
    check 0 "xschem load failed headless: $err"
  } else {
    check 1 "xschem load succeeded headless ([file tail $sch])"
    check_expr {![catch {xschem netlist} nerr]} "xschem netlist succeeded headless"
  }
} else {
  puts "info - no test schematic provided; skipping load/netlist"
}

if {$fail} { puts "NOGUI_TEST_FAIL" ; exit 1 } else { puts "NOGUI_TEST_PASS" ; exit 0 }
