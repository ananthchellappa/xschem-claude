# The CIW command entry (ciw_exec) treats a TYPED `xschem load <file>` as an
# interactive open: it injects `-gui` so the scheduler routes it to a new window
# unless the current one is a pristine empty untitled scratch
# (doc/claude/specs/load_window_routing.md). Scripts, --script files and action-log
# replays do NOT go through ciw_exec, so they keep the in-place behavior the
# regression suite relies on. This pins ciw_interactive_load's rewrite rules.
#
# Pure-Tcl (no windows) so it runs under --nogui. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ciw_interactive_load.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

# Extract the real proc from ciw.tcl (CIW is GUI-only and not sourced under --nogui,
# so pull just this proc out instead of building the widget tree).
set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here .. ..]]
set fh [open [file join $repo src ciw.tcl] r]; set body [read $fh]; close $fh
if {![regexp {(proc ciw_interactive_load \{cmd\} \{.*?\n\})} $body -> pdef]} {
  puts "FAIL: ciw_interactive_load not found in src/ciw.tcl : FAIL"; puts "OVERALL: notok"; exit 1
}
eval $pdef

# {label input expected}
foreach {label in exp} {
  "plain path"           {xschem load {/path/f.sch}}       {xschem load -gui {/path/f.sch}}
  "path with spaces"     {xschem load {/my dir/f.sch}}     {xschem load -gui {/my dir/f.sch}}
  "multi-file"           {xschem load a b}                 {xschem load -gui a b}
  "already -gui"         {xschem load -gui {f}}            {xschem load -gui {f}}
  "explicit -window"     {xschem load -window .x1.drw {f}} {xschem load -window .x1.drw {f}}
  "explicit -inplace"    {xschem load -inplace {f}}        {xschem load -inplace {f}}
  "scripted -nodraw"     {xschem load -nodraw x}           {xschem load -nodraw x}
  "load_new_window"      {xschem load_new_window {f}}      {xschem load_new_window {f}}
  "load_backup"          {xschem load_backup foo}          {xschem load_backup foo}
  "not a load cmd"       {xschem netlist}                  {xschem netlist}
  "extra whitespace"     {xschem  load   {f}}              {xschem  load -gui   {f}}
  "idempotent re-run"    {xschem load -gui {/p/f.sch}}     {xschem load -gui {/p/f.sch}}
} {
  check $label [ciw_interactive_load $in] $exp
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)"; puts "OVERALL: ok"; exit 0 } \
else { puts "RESULT: $fail FAILED ($npass passed)"; puts "OVERALL: notok"; exit 1 }
