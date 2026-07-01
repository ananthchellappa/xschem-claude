# migrate_pin_names.py end-to-end: the migrated .sym loads in xschem and its pin tokens
# drive the synth name views (ties the Python output to the C Option-B model), AND migrating
# a symbol leaves the netlist of a schematic that uses it BYTE-IDENTICAL (migration is
# display-only: it never touches name=/dir=/pin order). Shells out to python3.
#   ../src/xschem --nogui --pipe -q --script tests/headless/test_migrate_pin_names.tcl
set fail 0
proc check {name got want} {
  set ok [expr {$got eq $want}]
  puts "[expr {$ok ? {ok:  } : {FAIL:}}] $name (got $got want $want)"; flush stdout
  if {!$ok} {incr ::fail}
}
proc slurp {f} {
  if {![file exists $f]} { return "" }
  set fd [open $f r]; set s [read $fd]; close $fd; return $s
}

set here [file dirname [file normalize [info script]]]
set repo [file normalize [file join $here ../..]]
set py   [file join $repo tools/migrate/migrate_pin_names.py]
set tmp  [file normalize [file join [pwd] mig_pn_work]]
file delete -force $tmp; file mkdir $tmp

# python3 available?
if {[catch {exec python3 --version}]} {
  puts "RESULT: SKIP (no python3)"; flush stdout; exit 0
}

# a real netlistable primitive (res.sym: pins P@(0,-30) M@(0,+30), no literal name labels
# -> migration CREATES hidden names). Copy so we can migrate it in place.
set mysym [file join $tmp myres.sym]
file copy -force [file join $repo xschem_library/devices/res.sym] $mysym

# --- build + netlist a schematic that uses it (BEFORE migration) -------------
xschem set netlist_type spice
set ::netlist_dir $tmp
xschem clear force schematic
xschem instance $mysym 0 0 0 0 {name=R1 value=1k}
xschem instance lab_pin.sym 0 -30 0 0 {name=l1 lab=IN}
xschem instance lab_pin.sym 0  30 0 0 {name=l2 lab=OUT}
set sch [file join $tmp tb.sch]
xschem saveas $sch schematic
xschem load $sch
check "schematic has 3 instances" [xschem get instances] 3
xschem netlist
set spice [file join $tmp tb.spice]
set A [slurp $spice]
check "netlist A non-empty" [expr {[string length $A] > 0 ? 1 : 0}] 1
check "R1 netlisted on IN/OUT" [expr {[regexp {(^|\n)R1 } $A] && [regexp {IN} $A] && [regexp {OUT} $A] ? 1 : 0}] 1

# --- migrate the symbol -----------------------------------------------------
set rc [catch {exec python3 $py --no-backup $mysym} out]
check "migrate exit ok" $rc 0
check "migrate created 2 hidden names" [expr {[regexp {2 created} $out] ? 1 : 0}] 1
check "myres pin P now owned (token)" \
  [expr {[regexp {name=P[^\n]*show_pinname=false} [slurp $mysym]] ? 1 : 0}] 1

# --- netlist AGAIN (AFTER migration) and compare ----------------------------
xschem load $sch
xschem netlist
set B [slurp $spice]
check "netlist BYTE-IDENTICAL after migration" [expr {$A eq $B ? 1 : 0}] 1

# --- the migrated tokens drive the synth name views in symbol-edit ----------
xschem load $mysym
check "migrated symbol: 2 PINLAYER pins" [xschem get rects 5] 2
xschem pin_names auto
set tauto [xschem get texts]
xschem pin_names on
check "global ON reveals both owned names (+2 synth views)" [xschem get texts] [expr {$tauto + 2}]
xschem pin_names off
check "global OFF: no synth views (created pins hidden == auto)" [xschem get texts] $tauto
xschem pin_names auto

# --- idempotency: re-running migrate is a no-op -----------------------------
set before [slurp $mysym]
catch {exec python3 $py --no-backup $mysym} out2
check "re-migrate is a no-op (file unchanged)" [expr {[slurp $mysym] eq $before ? 1 : 0}] 1
check "re-migrate reports 0 migrated" [expr {[regexp {0 migrated} $out2] ? 1 : 0}] 1

file delete -force $tmp
if {$fail == 0} { puts "RESULT: ALL PASS (migrate_pin_names)" } else { puts "RESULT: $fail FAILURES (migrate_pin_names)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
