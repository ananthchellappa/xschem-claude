# A NULL token truncates the Tcl list `xschem list_nets` returns (issue 0180),
# and the NULL deref that hid it (issue 0181).
#
# --- 0180 ---------------------------------------------------------------------
# list_nets() (src/node_hash.c:386-397) walks a pin instance's expanded `lab`:
#
#     my_strdup2(&pin_node, expandlabel(xctx->inst[i].lab, &mult));
#     p_n_s1 = pin_node;
#     for(k = 1; k <= mult; ++k) {
#       lab = my_strtok_r(p_n_s1, ",", "", 0, &p_n_s2);      /* may be NULL */
#       p_n_s1 = NULL;
#       my_mstrcat(_ALLOC_ID_, result, "{", lab, " ", type, "}\n", NULL);
#     }
#
# An EMPTY lab expands to "" with mult == 1 (the !strpbrk(s,"*,.:") shortcut at
# parselabel.l:105-113), so the loop runs once over a string with zero tokens and
# my_strtok_r returns NULL (util.c:189, `if(tok[0]) return tok; else return NULL`).
# my_mstrcat (util.c:768) walks its varargs with `do {...} while(append_str)`, so
# a NULL argument is its END-OF-LIST SENTINEL, not empty data: only "{" is
# appended and the rest of the row is dropped. `result` goes straight to Tcl
# (scheduler.c:6338-6339), so the caller receives an unbalanced brace and every
# llength/lindex/foreach over it dies with "unmatched open brace in list".
#
# Measured on the pre-fix binary, this fixture made `xschem list_nets` return the
# single character `{`.
#
# --- 0181, and why 0180 looked unreachable ------------------------------------
# The trigger is a pin-type symbol (ipin/opin/iopin) with ZERO PINLAYER rects and
# at least one GENERICLAYER rect, whose instance lab is empty or absent:
#
#   * reset_node_data_and_rehash() (netlist.c:1636-1640) allocates inst[i].node
#     when rects[PINLAYER] + rects[GENERICLAYER] > 0, so the array EXISTS and the
#     `xctx->inst[i].node` conjunct of the node_hash.c:387 guard passes;
#   * name_unlabeled_instances() (netlist.c:1611) walks only j < rects[PINLAYER],
#     so the lab back-fill never visits this instance and the empty lab survives.
#
# On the shipping binary that shape SEGFAULTED first, inside
# name_nodes_of_pins_labels_and_propagate() (netlist.c:1463-1465), which derefs
# rect[PINLAYER][0] unconditionally for any non-label pin. So 0180 was latent
# BEHIND 0181, which is why five earlier constructions all came back balanced.
# Both fixes are needed for this file to pass: the guard makes the shape
# survivable, the `if(!lab) continue;` makes its output well-formed.
#
# --- shape of the fix ---------------------------------------------------------
# `continue` DROPS the row rather than emitting `{ <type>}`. This output is
# consumed as {name type} TUPLES (tests/stable_handles/net_body.tcl NC1a asserts
# llength == 2 per row) and a row with an empty name has llength 1, so the
# ternary would trade an unbalanced brace for a malformed tuple in the same
# consumer. NN4 pins that choice so a future "helpful" change has to argue with a
# test.
#
# Legs:
#   NN0      0181 witness: the fixture must SURVIVE list_nets at all
#   NN1-NN3  0180: balanced braces, parseable as a Tcl list, every row a pair
#   NN4      the `continue` decision: the nameless pin contributes NO row
#   NN5      opin and iopin take the same path as ipin
#   NN6      two generic rects (mult of the crash, not just one)
#   NN7      control: one PINLAYER rect + one GENERICLAYER rect still back-fills
#   NN8      control: an ordinary lab_pin fixture still lists its net
#
# Every leg runs the binary as a SUBPROCESS -- pre-fix this fixture segfaults,
# and a segfault in this file's own interpreter would take the whole run down.
#
# Run either arm:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_list_nets_null_token_0180.tcl
#   ./src/xschem        --pipe -q --nolog --script tests/headless/test_list_nets_null_token_0180.tcl

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
set scratch [test_scratch list_nets_null_token_0180]
set xbin    [file join $repo src xschem]

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
puts $f "DEFINE t0180 $scratch"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH $scratch

if {[catch {

# --- fixture ------------------------------------------------------------------
# `pinrects` B 5 (PINLAYER) rects and `genrects` B 3 (GENERICLAYER) rects.
# GENERICLAYER is 3 and PINLAYER is 5 (xschem.h:169-170) -- getting that pair
# wrong is what makes this fixture silently not reach the code under test.
proc write_sym {path type pinrects genrects} {
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  puts $f "G {}"
  puts $f "K {type=$type\nformat=\"*.$type @lab\"\ntemplate=\"name=p1 lab=\"\n}"
  foreach x {V S F E} { puts $f "$x {}" }
  puts $f {L 5 -5 0 0 0 {}}
  for {set i 0} {$i < $pinrects} {incr i} {
    set y [expr {$i * 10}]
    puts $f "B 5 -1.25 [expr {$y-1.25}] 1.25 [expr {$y+1.25}] {name=p$i dir=inout}"
  }
  for {set i 0} {$i < $genrects} {incr i} {
    set y [expr {100 + $i * 10}]
    puts $f "B 3 -1.25 [expr {$y-1.25}] 1.25 [expr {$y+1.25}] {name=g$i dir=inout}"
  }
  puts $f {T {@lab} -18.75 -8.75 0 1 0.33 0.33 {}}
  close $f
}

proc write_top {path body} {
  set f [open $path w]
  puts $f {v {xschem version=3.4.8RC file_version=1.3}}
  foreach x {G K V S F E} { puts $f "$x {}" }
  puts $f $body
  close $f
}

# Load $sch in a fresh --nogui child and run `xschem list_nets` there. Returns a
# dict: survived (0/1), raw (the exact string), open/close (brace counts),
# parses (llength succeeded), rows (the parsed list, {} if unparseable).
proc list_nets_child {tag sch} {
  global scratch xbin
  set sp [file join $scratch child_$tag.tcl]
  set f [open $sp w]
  puts $f "set no_recent_files 1"
  puts $f "set ::XSCHEM_LIBRARY_DEFS [list $::XSCHEM_LIBRARY_DEFS]"
  puts $f {set ::library_registry_defs_only 1}
  puts $f "set ::XSCHEM_LIBRARY_PATH [list $::XSCHEM_LIBRARY_PATH]"
  puts $f "xschem load [list $sch]"
  puts $f {set r [xschem list_nets]}
  # Report as one line each so a crash tail cannot be mistaken for data.
  puts $f {puts "NNRAW=<<[string map {\n |} $r]>>"}
  puts $f {puts "NNBAL=[regexp -all {\{} $r]/[regexp -all {\}} $r]"}
  puts $f {puts "NNPARSE=[expr {[catch {llength $r}] ? 0 : 1}]"}
  puts $f {if {![catch {llength $r}]} {puts "NNROWS=<<$r>>"}}
  puts $f {flush stdout; exit 0}
  close $f
  set out {}
  catch {exec $xbin --nogui --pipe -q --nolog --script $sp 2>@1} out
  set d [dict create survived 0 raw {} open {} close {} parses 0 rows {}]
  if {![regexp {NNBAL=(\d+)/(\d+)} $out -> o c]} { return $d }
  dict set d survived 1
  dict set d open  $o
  dict set d close $c
  regexp {NNRAW=<<(.*)>>} $out -> raw ; dict set d raw $raw
  if {[regexp {NNPARSE=(\d)} $out -> p]} { dict set d parses $p }
  if {[regexp {NNROWS=<<(.*)>>} $out -> rows]} { dict set d rows $rows }
  return $d
}

# 1 when every row of a parsed list_nets result is a 2-element {name type} pair.
proc all_pairs {rows} {
  foreach row $rows { if {[llength $row] != 2} { return 0 } }
  return 1
}

# --- the trigger: type=ipin, ZERO pin rects, ONE generic rect, empty lab -------
write_sym [file join $scratch g_ipin.sym] ipin 0 1
write_top [file join $scratch top_gen.sch] {C {t0180/g_ipin.sym} 0 0 0 0 {name=p1 lab=}}
set r [list_nets_child gen [file join $scratch top_gen.sch]]

# NN0 is the 0181 witness AND this file's fixture witness: if the child died,
# every later assertion here is vacuous, so say so explicitly rather than let
# them all report on an empty string.
check "NN0 (0181) a pin symbol with no PINLAYER rect survives list_nets" \
  [dict get $r survived] 1
check "NN1 list_nets braces are balanced" \
  [list [dict get $r open] [dict get $r close]] [list 0 0]
check "NN2 list_nets output parses as a Tcl list" \
  [dict get $r parses] 1
# NN3/NN4 carry the parse flag as well: an unparseable result leaves `rows`
# empty, and without it both legs would pass VACUOUSLY on exactly the broken
# output they exist to reject.
check "NN3 every list_nets row is a {name type} pair" \
  [list [dict get $r parses] [all_pairs [dict get $r rows]]] {1 1}
# NN4 pins the `continue` (drop the row) decision against `lab ? lab : ""`.
check "NN4 the nameless pin contributes no row at all" \
  [list [dict get $r parses] [dict get $r rows]] {1 {}}

# --- NN5: opin and iopin take the same IS_PIN path ----------------------------
set nn5 {}
foreach t {opin iopin} {
  write_sym [file join $scratch g_$t.sym] $t 0 1
  write_top [file join $scratch top_$t.sch] "C {t0180/g_$t.sym} 0 0 0 0 {name=p1 lab=}"
  set rr [list_nets_child $t [file join $scratch top_$t.sch]]
  lappend nn5 [list [dict get $rr survived] [dict get $rr open] [dict get $rr close] \
                    [dict get $rr parses] [dict get $rr rows]]
}
check "NN5 opin and iopin behave identically to ipin" \
  $nn5 [list {1 0 0 1 {}} {1 0 0 1 {}}]

# --- NN6: two generic rects ---------------------------------------------------
write_sym [file join $scratch g2.sym] ipin 0 2
write_top [file join $scratch top_g2.sch] {C {t0180/g2.sym} 0 0 0 0 {name=p1 lab=}}
set r2 [list_nets_child gen2 [file join $scratch top_g2.sch]]
check "NN6 two generic rects, still balanced and parseable" \
  [list [dict get $r2 survived] [dict get $r2 open] [dict get $r2 close] \
        [dict get $r2 parses] [dict get $r2 rows]] {1 0 0 1 {}}

# --- NN7 control: a real pin rect is still back-filled and still listed --------
# This is the leg that would catch a fix that threw the baby out: with a PINLAYER
# rect present the back-fill names the node, so a row MUST appear and it must be
# a pair.
write_sym [file join $scratch pg.sym] ipin 1 1
write_top [file join $scratch top_pg.sch] {C {t0180/pg.sym} 0 0 0 0 {name=p1 lab=}}
set r3 [list_nets_child pingen [file join $scratch top_pg.sch]]
check "NN7 (control) a pin WITH a PINLAYER rect still emits one {name type} row" \
  [list [dict get $r3 survived] [dict get $r3 parses] \
        [llength [dict get $r3 rows]] [all_pairs [dict get $r3 rows]]] {1 1 1 1}

# --- NN8 control: an ordinary schematic is untouched --------------------------
# Same shape as tests/stable_handles/net_body.tcl NC1a/NC1b: a wire with a
# lab_pin on it. The named net must still be listed.
write_top [file join $scratch top_plain.sch] "N 0 0 200 0 {}
C {devices/lab_pin.sym} 0 0 0 0 {name=l1 lab=MYNET}"
set r4 [list_nets_child plain [file join $scratch top_plain.sch]]
set names {}
if {[dict get $r4 parses]} {
  foreach row [dict get $r4 rows] { lappend names [lindex $row 0] }
}
check "NN8 (control) an ordinary lab_pin net is still listed as a pair" \
  [list [dict get $r4 survived] [dict get $r4 parses] \
        [all_pairs [dict get $r4 rows]] [expr {[lsearch -exact $names MYNET] >= 0}]] {1 1 1 1}

} err]} { puts "FATAL: $err" ; incr fail }

# House banner form: full_audit.sh is_pass() scores on "RESULT: ALL PASS".
if {$fail == 0} {
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
