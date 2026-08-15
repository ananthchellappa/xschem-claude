# Action-log coverage -- the Add-Pin gesture DROP records a replayable line
# (issue 0069 sympin slice, issue 0071 atom 11).
#
# end_move_copy_logged (callback.c) used to write a dead marker
#   `# place symbol pin (no replayable subcommand yet)`
# for a START_SYMPIN drop, so a replayed session silently skipped every pin
# placed with the Add-Pin form. ONE marker covered TWO different drops (both
# armed through `... -place` + the sympin_preview move machinery):
#   (a) SYMBOL pin  -- add_symbol_pin -place -> a PINLAYER rect (+ owned name
#       view). The drop now logs the direct replay form
#         xschem add_symbol_pin <x> <y> <name> <dir> 0 1
#       (draw off; `1` = NO stub leg line, since the -place drop stores only the
#       rect + name view -- the raw add_symbol_pin form also stores a 20-unit
#       leg. The no-line form also reproduces the move-time name_* writeback so
#       the replay saves byte-identically to the drop.)
#   (b) SCHEMATIC pin -- add_sch_pin -place -> an ipin/opin/iopin INSTANCE. The
#       drop now logs the SAME `xschem instance {sym} x y rot flip {prop}`
#       read-back a normal symbol placement uses (log_placed_instance).
# Both replay forms are coordinate commands that bypass the gesture funnel, so a
# replayed line never re-logs (coordinate-form-bypass invariant). The direct
# add_symbol_pin form is the replay form and must NOT self-log either.
#
# Needs the action log open -> registered in full_audit.sh logdir_tests:
#   ./src/xschem --pipe -q --logdir $(mktemp -d) \
#     --script tests/headless/test_sympin_drop_log.tcl

set ::fails 0
proc check {name ok {info {}}} {
  set tag [expr {$ok ? {ok:  } : {FAIL:}}]
  if {$info ne {}} { set name "$name  ($info)" }
  puts "$tag $name"; flush stdout
  if {!$ok} { incr ::fails }
}

set LOG [xschem get actionlog_filename]
if {$LOG eq {}} {
  puts "SKIP: no action log open -- run with --logdir"
  puts "RESULT: SKIP (no log)"
  exit 0
}
# Display-less box: START_SYMPIN placement needs a live canvas -- self-skip (atom-8).
if {[info commands winfo] eq {}} {
  puts "SKIP: no Tk (display-less session)"
  puts "RESULT: SKIP (no Tk)"
  exit 0
}

set ::work /tmp/atom11_sympin_drop_log.[pid]
file delete -force $::work; file mkdir $::work

# a no-motion RMB release opens the context menu -> stub it or the script HANGS
proc context_menu {} {return 21}
# the Add-Pin form is not built headless; nothing should reach it, but stub it so
# a stray bare `add_symbol_pin` cannot block on Tk.
catch {namespace eval addpin {}}
proc addpin::open {} {}

proc logtext {} {
  set fd [open [xschem get actionlog_filename] r]; set b [read $fd]; close $fd
  return $b
}
proc loglines {} { return [split [string trimright [logtext] \n] \n] }
proc newlines {n0} { return [lrange [loglines] $n0 end] }
proc countglob {lines pat} {
  set n 0
  foreach l $lines { if {[string match $pat $l]} { incr n } }
  return $n
}
proc readfile {p} { set fd [open $p r]; set b [read $fd]; close $fd; return $b }
# event drivers (xschem callback .drw <event> <mx> <my> <key> <button> <aux> <state>)
proc motion {x y} { xschem callback .drw 6 $x $y 0 0 0 0; update idletasks }
proc click1 {x y} {
  xschem callback .drw 4 $x $y 0 1 0 0
  xschem callback .drw 5 $x $y 0 1 0 256
}
proc esc {x y} { xschem callback .drw 2 $x $y 65307 0 0 0 }

# a canonical blank .sym buffer, written ONCE so golden + replay start identical
set ::BLANK_SYM [file join $::work blank.sym]
xschem clear force
xschem saveas $::BLANK_SYM symbol
proc fresh_sym {} { xschem clear force; xschem load $::BLANK_SYM }
proc fresh_sch {} { xschem clear force schematic }

# One symbol-pin drop + its replay oracle (byte-identical save).
proc sym_drop {tag name dir x y} {
  fresh_sym
  set n0 [llength [loglines]]
  set ::pin_new_name $name; set ::pin_new_dir $dir
  xschem add_symbol_pin -place
  motion $x $y; motion $x $y
  click1 $x $y
  set lines [newlines $n0]
  check "$tag drop logs exactly one add_symbol_pin line" \
    [expr {[countglob $lines {xschem add_symbol_pin *}] == 1}] "lines={$lines}"
  check "$tag no '# place symbol pin' marker on the drop" \
    [expr {[countglob $lines {# place symbol pin*}] == 0}]
  check "$tag one PINLAYER pin rect placed" [expr {[xschem get rects 5] == 1}]
  set sline [lindex $lines [lsearch -glob $lines {xschem add_symbol_pin *}]]
  if {$sline eq {}} { check "$tag replay (skipped: no line)" 0; return }
  check "$tag replay line is the no-line form (draw 0 noline 1)" \
    [expr {[llength $sline] == 8 && [lindex $sline 6] == 0 && [lindex $sline 7] == 1}] \
    "line={$sline}"
  xschem saveas [file join $::work g.sym] symbol
  set golden [readfile [file join $::work g.sym]]
  fresh_sym
  set n1 [llength [loglines]]
  eval $sline
  xschem saveas [file join $::work r.sym] symbol
  check "$tag replay save is byte-identical to the drop" \
    [expr {[readfile [file join $::work r.sym]] eq $golden}] \
    "golden={$golden} replay={[readfile [file join $::work r.sym]]}"
  check "$tag replay logs nothing (bypass invariant)" \
    [expr {[llength [loglines]] == $n1}] "n1=$n1 now=[llength [loglines]]"
}

# One schematic-pin drop + its replay oracle.
proc sch_drop {tag name dir x y symglob} {
  fresh_sch
  set n0 [llength [loglines]]
  set ::pin_new_name $name; set ::pin_new_dir $dir
  xschem add_sch_pin -place
  motion $x $y; motion $x $y
  click1 $x $y
  set lines [newlines $n0]
  check "$tag drop logs exactly one instance line" \
    [expr {[countglob $lines {xschem instance *}] == 1}] "lines={$lines}"
  check "$tag no '# place symbol pin' marker on the drop" \
    [expr {[countglob $lines {# place symbol pin*}] == 0}]
  check "$tag one instance placed" [expr {[xschem get instances] == 1}]
  set sline [lindex $lines [lsearch -glob $lines {xschem instance *}]]
  if {$sline eq {}} { check "$tag replay (skipped: no line)" 0; return }
  check "$tag instance is the $symglob device" \
    [string match "xschem instance $symglob *" $sline] "line={$sline}"
  xschem saveas [file join $::work g.sch] schematic
  set golden [readfile [file join $::work g.sch]]
  fresh_sch
  set n1 [llength [loglines]]
  eval $sline
  xschem saveas [file join $::work r.sch] schematic
  check "$tag replay save is byte-identical to the drop" \
    [expr {[readfile [file join $::work r.sch]] eq $golden}] \
    "golden={$golden} replay={[readfile [file join $::work r.sch]]}"
  check "$tag replay logs nothing (bypass invariant)" \
    [expr {[llength [loglines]] == $n1}] "n1=$n1 now=[llength [loglines]]"
}

# Any uncaught error below must NOT kill the script (the RESULT banner would be
# lost). One catch wraps every section: an error = one FAIL + clean banner.
if {[catch {

# ---------------------------------------------------------------------------
# T1-T3) SYMBOL pin drop: in / out / inout. Each: one add_symbol_pin line,
#        marker gone, byte-identical replay, replay logs nothing. out/inout
#        exercise the flip=1 name-view writeback token order.
# ---------------------------------------------------------------------------
sym_drop "T1 sym-pin in"    IN  in    80 60
sym_drop "T2 sym-pin out"   OUT out   80 60
sym_drop "T3 sym-pin inout" BID inout 80 60

# ---------------------------------------------------------------------------
# T4-T6) SCHEMATIC pin drop: in->ipin / out->opin / inout->iopin. Each: one
#        `xschem instance` line, byte-identical replay, replay logs nothing.
# ---------------------------------------------------------------------------
sch_drop "T4 sch-pin in"    IN  in    120 80 *ipin.sym
sch_drop "T5 sch-pin out"   OUT out   120 80 *opin.sym
sch_drop "T6 sch-pin inout" BID inout 120 80 *iopin.sym

# ---------------------------------------------------------------------------
# T7) ESC-abort of a symbol-pin preview logs nothing and leaves no rect
# ---------------------------------------------------------------------------
fresh_sym
set n0 [llength [loglines]]
set ::pin_new_name ZZ; set ::pin_new_dir in
xschem add_symbol_pin -place
motion 60 60
esc 60 60
check "T7 ESC sym-pin leaves no PINLAYER rect" [expr {[xschem get rects 5] == 0}]
check "T7 ESC sym-pin logs no add_symbol_pin line" \
  [expr {[countglob [newlines $n0] {xschem add_symbol_pin *}] == 0}] "new={[newlines $n0]}"

# ---------------------------------------------------------------------------
# T8) ESC-abort of a schematic-pin preview logs nothing and leaves no instance
# ---------------------------------------------------------------------------
fresh_sch
set n0 [llength [loglines]]
set ::pin_new_name ZZ; set ::pin_new_dir in
xschem add_sch_pin -place
motion 60 60
esc 60 60
check "T8 ESC sch-pin leaves no instance" [expr {[xschem get instances] == 0}]
check "T8 ESC sch-pin logs no instance line" \
  [expr {[countglob [newlines $n0] {xschem instance *}] == 0}] "new={[newlines $n0]}"

# ---------------------------------------------------------------------------
# T9) multi-name QUEUE: N drops -> exactly N lines (each click drops one pin
#     and the funnel logs exactly one line; the form re-arms the next).
# ---------------------------------------------------------------------------
fresh_sym
set n0 [llength [loglines]]
foreach {nm yy} {P1 20 P2 60 P3 100} {
  set ::pin_new_name $nm; set ::pin_new_dir in
  xschem add_symbol_pin -place
  motion 40 $yy; motion 40 $yy
  click1 40 $yy
}
set lines [newlines $n0]
check "T9 sym queue: 3 drops -> 3 add_symbol_pin lines" \
  [expr {[countglob $lines {xschem add_symbol_pin *}] == 3}] "lines={$lines}"
check "T9 sym queue: 3 pin rects placed" [expr {[xschem get rects 5] == 3}]

fresh_sch
set n0 [llength [loglines]]
foreach {nm yy} {A 20 B 60 C 100} {
  set ::pin_new_name $nm; set ::pin_new_dir in
  xschem add_sch_pin -place
  motion 40 $yy; motion 40 $yy
  click1 40 $yy
}
set lines [newlines $n0]
check "T9 sch queue: 3 drops -> 3 instance lines" \
  [expr {[countglob $lines {xschem instance *}] == 3}] "lines={$lines}"
check "T9 sch queue: 3 instances placed" [expr {[xschem get instances] == 3}]

# ---------------------------------------------------------------------------
# T10) exclusion: add_sch_pin refuses in a SYMBOL view -> no instance, no line.
#      (A schematic pin is an instance; a .sym view forbids instances.)
# ---------------------------------------------------------------------------
fresh_sym
set n0 [llength [loglines]]
set ::pin_new_name NO; set ::pin_new_dir in
xschem add_sch_pin -place
check "T10 add_sch_pin in symbol view places nothing" [expr {[xschem get instances] == 0}]
motion 50 50
click1 50 50
check "T10 add_sch_pin in symbol view logs no instance line" \
  [expr {[countglob [newlines $n0] {xschem instance *}] == 0}] "new={[newlines $n0]}"

# ---------------------------------------------------------------------------
# T11) the DIRECT add_symbol_pin form is the replay form -> it must NOT
#      self-log (the drop funnel is the sole logger; a self-log would double
#      every replayed sympin drop).
# ---------------------------------------------------------------------------
fresh_sym
set n0 [llength [loglines]]
xschem add_symbol_pin 10 10 QQ in 0
check "T11 direct add_symbol_pin logs nothing" \
  [expr {[countglob [newlines $n0] {xschem add_symbol_pin *}] == 0}] "new={[newlines $n0]}"
check "T11 direct add_symbol_pin still placed the pin" [expr {[xschem get rects 5] == 1}]

# ---------------------------------------------------------------------------
# T12) whole-log sweep: the dead marker never appeared anywhere
# ---------------------------------------------------------------------------
check "T12 no '# place symbol pin' marker anywhere in the log" \
  [expr {[countglob [loglines] {# place symbol pin*}] == 0}]

} ::t_err]} {
  check "uncaught error in test body" 0 $::t_err
}

file delete -force $::work
puts ""
puts [expr {$::fails == 0 ? "RESULT: ALL PASS" : "RESULT: $::fails FAILED"}]
flush stdout
exit [expr {$::fails != 0}]
