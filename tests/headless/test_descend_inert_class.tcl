# Descend must quietly ignore annotation-class instances.
#
# Net labels, hierarchy ports, connectivity markers, netlist/HDL directive blocks, title
# frames, launchers and probes are all placed as INSTANCES, but none of them has a child
# schematic -- 262 such .sym files ship in this tree and not one has a sibling .sch. A user
# who places a label or a title block and then presses `e` never asked for a hierarchy move,
# so the refusal must be SILENT and must leave the context untouched. That is the policy
# recorded in doc/claude/code_analysis/descend_silent_refusal_census.md section 4:
# silence is correct exactly when nothing the user saw, typed or clicked promised a descend.
#
# The behaviour is correct TODAY, as a side effect of descend_schematic()'s whitelist guard
# (src/actions.c:3620-3624 -- "not subcircuit and not primitive -> return 0"). This file is a
# REGRESSION LOCK, not a red test: it exists so that reshaping that guard (the type/existence
# split proposed in the census, which is needed to stop `type=primitive` stranding the window
# one level down on a page that does not exist) cannot silently change the annotation class.
#
# What is asserted per symbol, after selecting one instance of it and calling `xschem descend`:
#   ret          == 0        the verb declined
#   currsch      unchanged   no hierarchy move -- this is the assertion that catches a strand
#   current_name unchanged   the window still shows the same cell
#   instances    unchanged   nothing was loaded over the top
#   statusmsg    unchanged   SILENCE, asserted from inside the interpreter (issue 0251)
#   descend_error == "not-descendable:<type>"   the reason is RECORDED even though it is
#                            never SPOKEN -- record always, speak selectively
#
# The last two rows are the point of the 0249/0251/0254 reason channel and of this lock.
# A refusal the user provoked (pressing `i` on a symbol they picked, a ---MISSING SYMBOL---
# placeholder they clicked to interrogate) must SPEAK; a refusal on an annotation symbol the
# user never asked to descend must stay byte-silent while still recording WHY, so a script or
# a dialog can ask. `xschem get statusmsg` (issue 0248) is the readable half of that channel
# and is the seam this file uses to prove the silence positively, rather than asserting the
# absence of something it cannot see.
#
# The out-of-interpreter half -- C-level stderr, which no `xschem get` can reach -- is still
# the wrapper's job. The recipe below is RE-ANCHORED (issue 0251): the old
# `grep -v '^\(ok:\|FAIL:\|OVERALL:\|  \)'` let 7 lines through (2 xschem startup lines, the
# 3 section banners and 2 blank lines), so it would have passed with real noise in it.
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_inert_class.tcl \
#     2>&1 | grep -v -e '^ok:' -e '^FAIL:' -e '^OVERALL:' -e '^--- ' \
#                    -e '^Using run time directory ' -e '^Sourcing ' -e '^$'
#     # must print NOTHING. A dbg(0)/statusmsg added at the annotation-class guard
#     # (src/actions.c, "not subcircuit and not primitive -> return 0") shows up here.
#
# Section B is the counterweight: a real subcircuit in the same fixture MUST still descend.
# A test that only proves things do not happen passes just as well on a broken binary.
#
# Pure headless. Run from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_descend_inert_class.tcl
# Prints "OVERALL: ok" on success (run_regression sentinel).

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}

set repo [file normalize [file join [file dirname [info script]] .. ..]]
set dev  [file join $repo xschem_library devices]

# The annotation class, grouped as in the census. Each entry: {symfile expected_type}.
# Every one of these has NO sibling .sch anywhere in the tree.
set INERT {
  {lab_pin.sym              label}
  {lab_wire.sym             label}
  {gnd.sym                  label}
  {vdd.sym                  label}
  {bus_connect.sym          label}
  {lab_show.sym             show_label}
  {ipin.sym                 ipin}
  {opin.sym                 opin}
  {iopin.sym                iopin}
  {generic_pin.sym          generic}
  {noconn.sym               noconn}
  {bus_tap.sym              bus_tap}
  {jumper.sym               jumper}
  {short.sym                short}
  {stop.sym                 stop}
  {k.sym                    coupler}
  {code.sym                 netlist_commands}
  {code_shown.sym           netlist_commands}
  {netlist.sym              netlist_commands}
  {netlist_options.sym      netlist_options}
  {param.sym                spice_parameters}
  {package.sym              package}
  {attributes.sym           attributes}
  {port_attributes.sym      port_attributes}
  {architecture.sym         architecture}
  {arch_declarations.sym    arch_declarations}
  {use.sym                  use}
  {verilog_timescale.sym    timescale}
  {verilog_preprocessor.sym verilog_preprocessor}
  {title.sym                logo}
  {launcher.sym             launcher}
  {spice_probe.sym          probe}
  {ngspice_probe.sym        probe}
  {ammeter.sym              ammeter}
}

# Place one instance of $sym on a fresh sheet, select it, descend, and report the four
# invariants as one comparable string. Placement is by absolute path so the test does not
# depend on the caller's library search path.
proc probe_descend {sympath} {
  xschem clear force
  xschem instance $sympath 100 100 0 0 {name=zz1}
  # scope.sym and friends can place extra objects; select by instance name, not by count.
  xschem unselect_all
  if {[catch {xschem select instance zz1 fast} err]} { return "SELECT-FAILED:$err" }
  set lvl0  [xschem get currsch]
  set name0 [xschem get current_name]
  set n0    [xschem get instances]
  # issue 0251: the status line BEFORE the refusal. `xschem select instance` above always
  # leaves select.c's "n= x= y= w= h=" info line here, so this is never trivially empty.
  set sm0   [xschem get statusmsg]
  set ret   [xschem descend]
  set ::last_silent [expr {[xschem get statusmsg] eq $sm0}]
  set ::last_reason [xschem get descend_error]
  return "ret=$ret currsch=[expr {[xschem get currsch] - $lvl0}]\
           name=[expr {[xschem get current_name] eq $name0 ? {same} : {CHANGED}}]\
           insts=[expr {[xschem get instances] - $n0}]"
}

puts "--- A. the annotation class declines and does not move ---"
foreach row $INERT {
  lassign $row sym want_type
  set p [file join $dev $sym]
  if {![file exists $p]} { check "A/$sym present" 0 1 ; continue }
  # guard the fixture itself: if a symbol's type changes upstream, the row is testing
  # something other than what its name claims.
  check "A/$sym type"    [xschem get_sym_type $p]        $want_type
  check "A/$sym no .sch" [file exists [file rootname $p].sch] 0
  check "A/$sym descend" [probe_descend $p] \
        "ret=0 currsch=0 name=same insts=0"
  # the split, per symbol: SILENT on the status line (this is the half a loud fix breaks) ...
  check "A/$sym silent" $::last_silent 1
  # ... but the reason is still RECORDED, so a caller that wants to explain can.
  check "A/$sym reason" $::last_reason "not-descendable:$want_type"
}

puts "--- B. counterweight: a real subcircuit still descends ---"
# Without this, every assertion above would also pass on a binary where descend is dead.
set top [file join $repo xschem_library examples flop.sch]
if {![file exists $top]} {
  check "B/fixture present" 0 1
} else {
  xschem load $top
  set sub {}
  foreach {i s t} [xschem instance_list] { if {$t eq {subcircuit}} { set sub $i ; break } }
  if {$sub eq {}} {
    check "B/subcircuit found" 0 1
  } else {
    set lvl0 [xschem get currsch]
    xschem unselect_all
    xschem select instance $sub fast
    set sm0 [xschem get statusmsg]
    check "B/descend ret"     [xschem descend]                        1
    check "B/descend currsch" [expr {[xschem get currsch] - $lvl0}]   1
    # the counterweight for the two new rows above: on the SUCCESS path the reason channel
    # is cleared (a stale reason can never be read as a fresh one) and nothing is said either.
    check "B/reason cleared"  [xschem get descend_error]              {}
    check "B/success silent"  [expr {[xschem get statusmsg] eq $sm0}] 1
    xschem go_back 2
    check "B/go_back currsch" [xschem get currsch]                    $lvl0
  }
}

puts "--- C. descend_symbol is deliberately NOT gated by this class ---"
# The symbol view of an annotation symbol is a real file with real content, and `i` is the
# documented way to read a symbol's type=/format=/template= contract. Gating it here would
# remove capability rather than a dead end (census section 2.3). This locks that decision so a
# later "consistency" change has to break a test to make it.
xschem clear force
xschem instance [file join $dev lab_pin.sym] 100 100 0 0 {name=zz1}
xschem unselect_all
xschem select instance zz1 fast
set lvl0 [xschem get currsch]
xschem descend_symbol
check "C/descend_symbol enters the .sym" [expr {[xschem get currsch] - $lvl0}] 1
check "C/landed on the sym file" [file tail [xschem get current_name]] lab_pin.sym

puts ""
if {$fail} { puts "OVERALL: $fail FAILED, $npass passed" } \
else       { puts "OVERALL: ok ($npass checks)" }
