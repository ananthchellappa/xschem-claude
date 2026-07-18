# test_noncairo_verbs_ungated.tcl -- issue 0120.
#
# Regression lock for: the two NON-cairo verbs `incr_hilight_color` and `inst_name_text`
# were silently lost on a HAS_CAIRO==0 build because they sat INSIDE an over-broad
# `#if HAS_CAIRO==1` gate in scheduler.c `xschem_cmds_i` that was meant to wrap ONLY the
# cairo-only `image` verb (edit_image, draw.c `#if HAS_CAIRO==1`). See
# doc/claude/issues/0120-noncairo-verbs-lost-in-image-cairo-gate.md.
#
# This test has TWO layers:
#   (S) STRUCTURAL grep guard -- FAIL-CLOSED against a future re-widening of the gate.
#       Scans src/scheduler.c and asserts the `#if HAS_CAIRO==1` in xschem_cmds_i sits
#       AFTER both non-cairo verb branches and encloses ONLY `image`. This layer runs on
#       any build (it reads source, not the binary), so it catches the regression even in
#       a cairo CI where the two verbs would otherwise still resolve.
#   (F) FUNCTIONAL reachability -- drives the two verbs on the running binary to prove
#       they are dispatched and return their documented shapes. On a cairo build this also
#       exercises `image help`; on a no-cairo build `image` is absent and that sub-check is
#       skipped (the verb's absence is the intended behavior there, not a failure).
#
# Run UNDER xschem:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_noncairo_verbs_ungated.tcl
# Auto-discovered by tests/headless/full_audit.sh (default branch, no --logdir needed).

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

# ---------------------------------------------------------------------------
# (S) STRUCTURAL: the HAS_CAIRO gate in xschem_cmds_i wraps ONLY `image`.
# ---------------------------------------------------------------------------
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set sched [file join $repo src scheduler.c]
check "(S) scheduler.c present" [file exists $sched] "path=$sched"

set fd [open $sched r]; set lines [split [read $fd] \n]; close $fd
set n [llength $lines]

# Bound the xschem_cmds_i function: from its definition to the start of the next
# xschem_cmds_<letter> function (its immediate successor in the dispatcher decomposition).
set fstart -1; set fend $n
for {set i 0} {$i < $n} {incr i} {
  if {[string first "static int xschem_cmds_i(" [lindex $lines $i]] >= 0} { set fstart $i; break }
}
check "(S) found xschem_cmds_i definition" [expr {$fstart >= 0}] "fstart=$fstart"
if {$fstart >= 0} {
  for {set i [expr {$fstart + 1}]} {$i < $n} {incr i} {
    if {[string first "static int xschem_cmds_" [lindex $lines $i]] >= 0} { set fend $i; break }
  }
}

# First index (within the function region) of each marker substring, else -1.
proc first_of {lines fstart fend needle} {
  for {set i $fstart} {$i < $fend} {incr i} {
    if {[string first $needle [lindex $lines $i]] >= 0} { return $i }
  }
  return -1
}
set i_incr  [first_of $lines $fstart $fend {strcmp(argv[1], "incr_hilight_color")}]
set i_inst  [first_of $lines $fstart $fend {strcmp(argv[1], "inst_name_text")}]
set i_gate  [first_of $lines $fstart $fend {#if HAS_CAIRO==1}]
set i_image [first_of $lines $fstart $fend {strcmp(argv[1], "image")}]
set i_endif [first_of $lines $fstart $fend {#endif}]

check "(S) incr_hilight_color branch present"      [expr {$i_incr  >= 0}] "line=$i_incr"
check "(S) inst_name_text branch present"          [expr {$i_inst  >= 0}] "line=$i_inst"
check "(S) HAS_CAIRO gate present"                 [expr {$i_gate  >= 0}] "line=$i_gate"
check "(S) image branch present"                   [expr {$i_image >= 0}] "line=$i_image"
check "(S) #endif present"                         [expr {$i_endif >= 0}] "line=$i_endif"

# The load-bearing invariant: both non-cairo verbs sit BEFORE the gate (so they survive
# HAS_CAIRO==0), and the gate encloses ONLY the image branch (gate < image < endif).
check "(S) incr_hilight_color is OUTSIDE the gate (before #if)" \
  [expr {$i_incr >= 0 && $i_gate >= 0 && $i_incr < $i_gate}] "incr=$i_incr gate=$i_gate"
check "(S) inst_name_text is OUTSIDE the gate (before #if)" \
  [expr {$i_inst >= 0 && $i_gate >= 0 && $i_inst < $i_gate}] "inst=$i_inst gate=$i_gate"
check "(S) image branch is INSIDE the gate (#if < image < #endif)" \
  [expr {$i_gate >= 0 && $i_image >= 0 && $i_endif >= 0 && $i_gate < $i_image && $i_image < $i_endif}] \
  "gate=$i_gate image=$i_image endif=$i_endif"

# Exactly one #if HAS_CAIRO==1 / #endif pair in the function -> the narrowed single-branch
# gate, not a re-widened or duplicated structure.
proc count_of {lines fstart fend needle} {
  set c 0
  for {set i $fstart} {$i < $fend} {incr i} {
    if {[string first $needle [lindex $lines $i]] >= 0} { incr c }
  }
  return $c
}
check "(S) exactly ONE #if HAS_CAIRO==1 in xschem_cmds_i" \
  [expr {[count_of $lines $fstart $fend {#if HAS_CAIRO==1}] == 1}] \
  "count=[count_of $lines $fstart $fend {#if HAS_CAIRO==1}]"
check "(S) exactly ONE #endif in xschem_cmds_i" \
  [expr {[count_of $lines $fstart $fend {#endif}] == 1}] \
  "count=[count_of $lines $fstart $fend {#endif}]"

# ---------------------------------------------------------------------------
# (F) FUNCTIONAL: the two verbs are reachable on the running binary.
# ---------------------------------------------------------------------------
# incr_hilight_color returns the (non-negative) net-highlight style index.
set ircode [catch {xschem incr_hilight_color} idx]
check "(F) incr_hilight_color dispatched (TCL_OK)" [expr {$ircode == 0}] "rc=$ircode r=>$idx<"
check "(F) incr_hilight_color returns a non-negative style index" \
  [expr {$ircode == 0 && [string is integer -strict $idx] && $idx >= 0}] "idx=>$idx<"

# inst_name_text on a @lab-bearing instance returns "<index> <size>".
set l1 [xschem instance devices/lab_pin.sym 0 0 0 0 {name=l1 lab=clk}]
set li [expr {[xschem get instances] - 1}]
set trcode [catch {xschem inst_name_text $li} nt]
check "(F) inst_name_text dispatched (TCL_OK)" [expr {$trcode == 0}] "rc=$trcode r=>$nt<"
check "(F) inst_name_text returns '<idx> <size>' on a label instance" \
  [expr {$trcode == 0 && [llength $nt] == 2 && [lindex $nt 0] >= 0 && [lindex $nt 1] > 0}] "nt=>$nt<"

# `image` sub-form: present + read-only-safe help on cairo; cleanly ABSENT (cmd_found=0,
# graceful "invalid command", no crash) on no-cairo. Either is correct -- assert no crash.
set hrcode [catch {xschem image help} h]
if {[string match {*invalid command*} $h]} {
  check "(F) image verb ABSENT on no-cairo -> graceful 'invalid command' (no crash)" \
    [expr {$hrcode == 1}] "rc=$hrcode h=>$h<"
} else {
  check "(F) image help present on cairo -> TCL_OK + usage string" \
    [expr {$hrcode == 0 && [string match {xschem image*} $h]}] "rc=$hrcode h=>$h<"
}

puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
