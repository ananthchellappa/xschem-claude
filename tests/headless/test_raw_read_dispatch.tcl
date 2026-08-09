# test_raw_read_dispatch.tcl — `xschem raw_read <file> <type>` must pick its reader
# from <type>, for EVERY reader, and the database must survive the trip.
# doc/claude/issues/0290-raw_read-bypasses-the-non-spice-reader-dispatch.md
#
# THE BUG. `xschem raw_read` does not go through extra_rawfile(); it repeated
# extra_rawfile()'s type->reader dispatch by hand, and the copy had drifted: it
# knew "vcd" and not "table". `raw_read <f> table` therefore handed a tabular
# file to the ngspice raw parser, which looks for `Plotname:` / `No. Variables:`
# / `Values:`, finds none and returns 0 — after the arm's opening
# extra_rawfile(3, ...) had already cleared the WHOLE registry. Net effect: the
# database is gone and nothing replaced it. No crash, no dialog.
#
# WHY IT MATTERS (group E, the load-bearing one). Two shipped Tcl paths carry the
# current database into a new window by round-tripping its own sim_type back
# through this exact command:
#     xschem raw_read $rawfile [xschem raw_query sim_type]
# — open_sub_schematic and hi_descend's new-window arm, both in src/xschem.tcl.
# So the user-visible bug is: load a table, descend into a sub-schematic in a new
# window, waveforms silently gone. Group D alone does NOT prove that; group E
# drives the real procs.
#
# THE SECOND HALF. table_read() does not stamp raw->sim_type (vcd_read() does),
# so the dispatch must stamp it or the database enters the registry with a NULL
# sim_type — which is not cosmetic: both lookup loops in extra_rawfile() SKIP an
# entry whose sim_type is NULL, so `xschem raw switch` can never reach it again,
# and seven sites strcmp() it with no NULL guard. Hence D2/D6/D7 and R9/R10:
# every format group asserts sim_type AND round-trips `raw switch`.
#
# Run TRUE HEADLESS from the repo root (needs no display; verified with DISPLAY
# unset, which is why it is in full_audit.sh's nogui_tests):
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_raw_read_dispatch.tcl

source [file join [file dirname [info script]] scratch.tcl]

set fail 0
set npass 0
proc check {name ok detail} {
  global fail npass
  if {$ok} { puts "ok:   $name $detail"; incr npass } \
  else { puts "FAIL: $name $detail"; incr fail }
}
proc eqcheck {name got want} {
  check $name [expr {$got eq $want}] "(got '$got' want '$want')"
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch rawdisp]
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
# does `xschem raw info` list this file with this type?
proc info_has {f type} {
  return [string match "*[file tail $f] $type*" [pcall xschem raw info]]
}

# --- the three fixtures, one per reader --------------------------------------
# a tabular file: header row + 3 data rows
wr $tmp/t.table "time\ta\tb\n0.0\t1.0\t2.0\n1e-9\t3.0\t4.0\n2e-9\t5.0\t6.0\n"
# a VCD: one scalar, one edge. Materializes as 4 points (seed, hold at t-1, the
# change, and the final timestamp).
wr $tmp/t.vcd "\$timescale 1ps \$end
\$scope module m \$end
\$var wire 1 ! a \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#100
1!
#200
"
# an ascii ngspice raw: the reader that everything NOT in the table falls back to
wr $tmp/an.raw "Title: dispatch
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\ttime\ttime
\t1\tv(n1)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e-08
\t2.000000000000000e+00

2\t2.000000000000000e-08
\t3.000000000000000e+00

"
# a table with no data at all (comments only). table_read() returns 1 but leaves
# raw->values NULL, so sch_waves_loaded() is -1 for it — the case where a stamp
# conditioned on sch_waves_loaded() silently does not happen.
wr $tmp/c.table "# only comments\n# and nothing else\n"

# ===========================================================================
# D — the bypass door itself: `xschem raw_read <file> <type>`
# ===========================================================================
xschem raw clear
# --- table: the arm that was missing (issue 0290) ---------------------------
eqcheck D1-table-read      [pcall xschem raw_read $tmp/t.table table] 1
eqcheck D2-table-simtype   [pcall xschem raw sim_type] table
eqcheck D3-table-vars      [pcall xschem raw vars] 3
eqcheck D4-table-points    [pcall xschem raw points] 3
eqcheck D5-table-value     [pcall xschem raw value a 1] 3
check   D6-table-in-registry [info_has $tmp/t.table table] "(info='[string map {\n |} [pcall xschem raw info]]')"
# the NULL-sim_type trap: extra_rawfile()'s lookup loop skips a NULL sim_type,
# so a DB stamped NULL is unreachable by `raw switch` forever
eqcheck D7-table-switchable [pcall xschem raw switch $tmp/t.table table] 1

# --- vcd: the arm §C added; it must still work through the same dispatch ----
xschem raw clear
eqcheck D8-vcd-read        [pcall xschem raw_read $tmp/t.vcd vcd] 1
eqcheck D9-vcd-simtype     [pcall xschem raw sim_type] vcd
eqcheck D10-vcd-vars       [pcall xschem raw vars] 2
eqcheck D11-vcd-value      [pcall xschem raw value m.a 3] 1
eqcheck D12-vcd-switchable [pcall xschem raw switch $tmp/t.vcd vcd] 1

# --- the spice fall-through must be untouched -------------------------------
xschem raw clear
eqcheck D13-spice-read     [pcall xschem raw_read $tmp/an.raw tran] 1
eqcheck D14-spice-simtype  [pcall xschem raw sim_type] tran
eqcheck D15-spice-value    [pcall xschem raw value v(n1) 2] 3
# no type at all == "first analysis found in the file"
xschem raw clear
eqcheck D16-notype-read    [pcall xschem raw_read $tmp/an.raw] 1
eqcheck D17-notype-simtype [pcall xschem raw sim_type] tran
# an EMPTY type is the same thing as no type — open_sub_schematic passes
# [xschem raw_query sim_type] straight through, which can be empty. Before the
# fix this reached read_dataset() as "", matched no analysis, and read nothing.
xschem raw clear
eqcheck D18-emptytype-read    [pcall xschem raw_read $tmp/an.raw {}] 1
eqcheck D19-emptytype-simtype [pcall xschem raw sim_type] tran

# --- the discriminators: the type IS the key, it is not sniffed -------------
# a table file declared "tran" must FAIL, not be rescued by content sniffing.
# (test_vcd_time_base's S19 pins the same expectation for a VCD read as "tran".)
xschem raw clear
eqcheck D20-table-as-tran-fails [pcall xschem raw_read $tmp/t.table tran] 0
# an unknown token is not silently treated as a non-spice format either
xschem raw clear
eqcheck D21-unknown-type-fails  [pcall xschem raw_read $tmp/t.table tabular] 0

# ===========================================================================
# R — the registry door (extra_rawfile) must agree with the bypass door.
#     Both now consult the same dispatch table, so these are the anti-drift
#     checks: any type the one door knows, the other knows.
# ===========================================================================
xschem raw clear
eqcheck R1-raw-read-table     [pcall xschem raw read $tmp/t.table table] 1
eqcheck R2-raw-read-simtype   [pcall xschem raw sim_type] table
xschem raw clear
eqcheck R3-raw-table_read     [pcall xschem raw table_read $tmp/t.table] 1
eqcheck R4-raw-table_read-st  [pcall xschem raw sim_type] table
xschem raw clear
eqcheck R5-raw-read-vcd       [pcall xschem raw read $tmp/t.vcd vcd] 1
eqcheck R6-raw-read-vcd-st    [pcall xschem raw sim_type] vcd
xschem raw clear
eqcheck R7-raw-vcd_read       [pcall xschem raw vcd_read $tmp/t.vcd] 1
eqcheck R8-raw-vcd_read-st    [pcall xschem raw sim_type] vcd

# The top-level `xschem table_read` / `xschem vcd_read` verbs also paired a
# reader call with a hand-written sim_type stamp — and hung that stamp on
# sch_waves_loaded(), which is FALSE for a data-less table (raw->values NULL).
# Such a DB used to enter the registry with sim_type <NULL>: listed as <NULL>
# by `raw info` and unreachable by `raw switch` forever.
xschem raw clear
pcall xschem table_read $tmp/c.table
check   R9-dataless-table-typed [info_has $tmp/c.table table] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
eqcheck R10-dataless-table-switchable [pcall xschem raw switch $tmp/c.table table] 1
xschem raw clear
pcall xschem vcd_read $tmp/t.vcd
eqcheck R11-topverb-vcd-simtype [pcall xschem raw sim_type] vcd
xschem raw clear

# ===========================================================================
# E — END TO END: the two shipped procs that generate the failing command.
#     This is the bug as the user meets it. Group D can be green while these
#     fail (they were, for `table`), because these go through the Tcl round trip
#     `xschem raw_read $rawfile [xschem raw_query sim_type]` in a NEW window.
# ===========================================================================
set fixroot [file normalize [file join [file dirname [info script]] fixtures hi_descend]]
set lib [file join $fixroot hidlib]
lappend pathlist $lib                 ;# register hidlib (lib/cell/view layout)
set top [file join $lib top schematic top.sch]

# --- E1..E10: a TABLE database carried by open_sub_schematic ----------------
xschem raw clear
xschem load $top
xschem unselect_all
eqcheck E1-table-loaded-at-top [pcall xschem raw_read $tmp/t.table table] 1
check   E2-table-waves-live [expr {[pcall xschem raw loaded] >= 0}] \
  "(loaded=[pcall xschem raw loaded])"
set win0 [xschem get current_win_path]
eqcheck E3-open_sub_schematic [pcall open_sub_schematic x1] 1
set win1 [xschem get current_win_path]
check   E4-new-window [expr {$win1 ne $win0}] "(was '$win0' now '$win1')"
check   E5-really-descended [string match "*/leaf/schematic/leaf.sch" [xschem get schname]] \
  "(schname=[xschem get schname])"
# THE ISSUE: before the fix these five found <no database at all> in the new window
eqcheck E6-table-simtype-survives [pcall xschem raw sim_type] table
eqcheck E7-table-vars-survive     [pcall xschem raw vars] 3
eqcheck E8-table-data-survives    [pcall xschem raw value b 2] 6
check   E9-table-in-new-registry  [info_has $tmp/t.table table] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
eqcheck E10-table-switchable-in-new-window [pcall xschem raw switch $tmp/t.table table] 1

# --- E11..E19: a VCD database carried by hi_descend's new-window arm --------
xschem raw clear
xschem load $top
xschem unselect_all
eqcheck E11-vcd-loaded-at-top [pcall xschem raw_read $tmp/t.vcd vcd] 1
set win0 [xschem get current_win_path]
eqcheck E12-hi_descend-newwin [pcall hi_descend inst=x1 target=new_window] 1
set win1 [xschem get current_win_path]
check   E13-new-window [expr {$win1 ne $win0}] "(was '$win0' now '$win1')"
check   E14-really-descended [string match "*/leaf/*leaf.s*" [xschem get schname]] \
  "(schname=[xschem get schname])"
eqcheck E15-vcd-simtype-survives [pcall xschem raw sim_type] vcd
eqcheck E16-vcd-vars-survive     [pcall xschem raw vars] 2
eqcheck E17-vcd-data-survives    [pcall xschem raw value m.a 3] 1
check   E18-vcd-in-new-registry  [info_has $tmp/t.vcd vcd] \
  "(info='[string map {\n |} [pcall xschem raw info]]')"
eqcheck E19-vcd-switchable-in-new-window [pcall xschem raw switch $tmp/t.vcd vcd] 1

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_raw_read_dispatch: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
