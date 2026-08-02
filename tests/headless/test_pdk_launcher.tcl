# Logic smoke for the PDK launcher GUI (tools/launcher/pdk_launcher.tcl).
#
# The launcher's job is to turn a few GUI choices into ONE correct xschem
# command line. That translation is what this checks — no window is created:
# the launcher is sourced with ::PDK_LAUNCHER_NO_UI, which skips `package
# require Tk` and returns before any widget is built, so this runs under a plain
# tclsh with no display.
#
# What it defends:
#   - PDK auto-discovery finds every shipped workarea and nothing else (src/
#     also has a cadence_style_rc and must NOT be listed as a PDK);
#   - each PDK maps to `--script <that workarea>/cadence_style_rc`;
#   - the "plain xschem" entry emits no --script at all;
#   - optional fields are omitted when blank rather than passed as empty args;
#   - the schematic argument stays LAST (xschem takes it positionally).
#
#   tclsh tests/headless/test_pdk_launcher.tcl
# Prints "OVERALL: ok" on success.

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set lf   [file join $repo tools launcher pdk_launcher.tcl]

check_true "pdk_launcher.tcl exists"   [file isfile $lf]
check_true "pdk_launcher.sh is executable" [file executable [file join $repo pdk_launcher.sh]]

set ::PDK_LAUNCHER_NO_UI 1
source $lf

# --- discovery -------------------------------------------------------------
set found {}
foreach p [discover_pdks $repo] { lappend found [lindex $p 0] }
set found [lsort $found]
check "discovers exactly the shipped workareas" $found [lsort {sky130A gf180mcuD ihp-sg13g2}]

# src/ ships a cadence_style_rc too, but has no library.defs — it is offered as a
# synthetic entry, never as a discovered PDK. A regression here would give the
# user a bogus "src" PDK that loads no libraries.
check_true "src/ is NOT discovered as a PDK" [expr {[lsearch -exact $found src] < 0}]

foreach p [discover_pdks $repo] {
  set nm [lindex $p 0]; set rc [lindex $p 1]
  check_true "$nm rc path is that workarea's cadence_style_rc" \
    [string equal $rc [file join $repo $nm cadence_style_rc]]
  check_true "$nm rc really exists" [file isfile $rc]
}

# --- command construction --------------------------------------------------
proc cmdfor {pdk args} {
  global S repo
  array set o {logdir {} netdir {} cell {} extra {} quiet 0 norecent 0}
  array set o $args
  set S(pdk) $pdk
  foreach k {logdir netdir cell extra quiet norecent} { set S($k) $o($k) }
  return [build_cmd]
}

set xs [file join $repo src xschem]

check "plain PDK-less entry emits no --script" \
  [cmdfor "(plain xschem — no rc)"] [list $xs]

check "sky130A maps to its own rc" \
  [cmdfor sky130A] [list $xs --script [file join $repo sky130A cadence_style_rc]]
check "gf180mcuD maps to its own rc" \
  [cmdfor gf180mcuD] [list $xs --script [file join $repo gf180mcuD cadence_style_rc]]
check "ihp-sg13g2 maps to its own rc" \
  [cmdfor ihp-sg13g2] [list $xs --script [file join $repo ihp-sg13g2 cadence_style_rc]]
check "the no-PDK entry uses the repo's src/cadence_style_rc" \
  [cmdfor "(no PDK — repo Cadence UX)"] \
  [list $xs --script [file join $repo src cadence_style_rc]]

# the flag that motivated the whole launcher
check "log directory becomes --logdir" \
  [cmdfor sky130A logdir /tmp] \
  [list $xs --script [file join $repo sky130A cadence_style_rc] --logdir /tmp]

check "netlist directory becomes --netlist_path" \
  [cmdfor sky130A netdir /tmp/nl] \
  [list $xs --script [file join $repo sky130A cadence_style_rc] --netlist_path /tmp/nl]

check "checkboxes add -q and --norecent" \
  [cmdfor sky130A quiet 1 norecent 1] \
  [list $xs --script [file join $repo sky130A cadence_style_rc] -q --norecent]

# Blank fields must vanish entirely. Passing `--logdir {}` would make xschem
# swallow the NEXT argument as the log directory.
set c [cmdfor sky130A logdir "" netdir "" cell "" extra ""]
check_true "blank logdir emits no --logdir"       [expr {[lsearch -exact $c --logdir] < 0}]
check_true "blank netdir emits no --netlist_path" [expr {[lsearch -exact $c --netlist_path] < 0}]
check_true "no empty-string argument is ever passed" [expr {[lsearch -exact $c {}] < 0}]
check_true "whitespace-only logdir is treated as blank" \
  [expr {[lsearch -exact [cmdfor sky130A logdir "   "] --logdir] < 0}]

# The schematic is positional, so it has to come after every option.
set c [cmdfor sky130A logdir /tmp cell /tmp/x.sch extra "-d 2"]
check "schematic is the LAST argument" [lindex $c end] /tmp/x.sch
check_true "extra args are split into separate words" \
  [expr {[lsearch -exact $c -d] >= 0 && [lsearch -exact $c 2] >= 0}]

puts ""
if {$fail} { puts "OVERALL: $fail FAILED ($npass passed)" } else { puts "OVERALL: ok ($npass checks)" }
