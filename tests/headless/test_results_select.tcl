# test_results_select.tcl -- the `Results > Select` engine contract.
# doc/claude/specs/results_selection.md, doc/claude/results_batch/PLAN.md
#
# THIS FILE IS GROWN BY THE RESULTS BATCH. Item 1 starts it with the engine
# invariant T-B; items 2, 3 and 4 add the resolver, the `raw select` sub-verb
# and the orchestrator. Check-id band: prefix SEL, measured free 2026-08-19
# (`grep -hoE '\bSEL[0-9]+\b' tests/headless/*.tcl` -> nothing). RS1..RS3 exist
# in test_library_git.tcl and are NOT this band. SEL50..SEL74 were added by the
# item-1 FIX ROUND and are numbered by when they were added, not by where they
# sit: SEL50 belongs to group C, the rest are groups F..I at the bottom. No
# pre-existing id was renumbered.
#
# ---------------------------------------------------------------------------
# ITEM 1 -- R110/R112, issue 0509.
#
# A loaded database is bound to the schematic that was current WHEN IT WAS READ
# (raw->schname / raw->level), and every name lookup is gated on that stamp
# still being on the current hierarchy stack -- sch_waves_loaded()
# (src/draw.c:2825) -> get_raw_index() (src/save.c:3477). Navigate to an
# unrelated cell and `xschem raw info` still lists the database while
# `xschem raw index <name>` returns -1. That much is deliberate.
#
# THE DEFECT: the obvious repair -- read the file again where you now stand --
# did nothing and said it worked. extra_rawfile(what == 1) dedupes on
# (rawfile, sim_type), and the "file found: switch to it" branch moved the
# cursor without re-stamping. rc=1, every lookup still -1.
#
# THE ARM IS WRITTEN TWICE and that is half of why 0509 survived: once for the
# non-spice readers (table/vcd, src/save.c:1981, dedupe on rawfile ALONE) and
# once for the spice reader (src/save.c:2037, dedupe on rawfile AND sim_type).
# Groups A and B below drive one arm each, on purpose: a single fixture proves
# only half the file formats.
#
# THE GUARD (group C) is the crew refinement of R110 recorded in the spec: the
# re-stamp fires only when the current stamp does NOT already resolve against
# the stack. sch_waves_loaded() accepts ancestors, so a raw read at the top and
# re-read after a DESCEND is already current here; re-stamping it to the child
# would move the binding DOWN and blind the top level to its own results.
# Measured with the unconditional form before the guard went in.
#
# Runs with or without X (it draws nothing). From the repo root:
#   ./src/xschem --pipe -q --nolog --script tests/headless/test_results_select.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_results_select.tcl

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
proc gecheck {name got} {
  check $name [expr {[string is integer -strict $got] && $got >= 0}] "(got '$got', want >= 0)"
}
proc pcall {args} {
  if {[catch {uplevel 1 $args} r]} { return "ERR:$r" }
  return $r
}
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
# how many SLOTS the registry holds. `xschem raw info` prints "<idx> current"
# first and then one line per slot, so the header line is dropped by shape, not
# by count (extra_rawfile() what == 4, src/save.c).
proc n_slots {} {
  set n 0
  foreach line [split [pcall xschem raw info] "\n"] {
    set line [string trim $line]
    if {$line eq ""} continue
    if {[regexp {^[0-9]+ current$} $line]} continue
    if {[regexp {^[0-9]+ } $line]} { incr n }
  }
  return $n
}

# the registry's slot LIST, in order. n_slots alone is one-sided: it catches a
# read that ADDS a slot and is blind to a read that DESTROYS one, and F7/L3 --
# "selection never clears, never clear-then-read" -- is the invariant that
# matters. Measured in the fix round: `xctx->extra_raw_n = i + 1;` in the spice
# dedupe arm drops every later slot and left all 49 original checks green.
proc slot_list {} {
  set out {}
  foreach line [split [pcall xschem raw info] "\n"] {
    set line [string trim $line]
    if {$line eq ""} continue
    if {[regexp {^[0-9]+ current$} $line]} continue
    if {[regexp {^[0-9]+ } $line]} { lappend out $line }
  }
  return $out
}

# test_scratch owns the directory's lifetime (issue 0148).
set tmp [test_scratch resultssel]

# --- two UNRELATED cells. Cell B must not be anywhere on cell A's hierarchy
#     stack, or sch_waves_loaded()'s ancestor walk would keep resolving and the
#     test would measure nothing. Two flat wire-only schematics are unrelated by
#     construction and need no symbol library.
wr $tmp/cellA.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 0 200 0 {}\n"
wr $tmp/cellB.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 100 200 100 {}\n"

# --- the spice fixture: an ascii ngspice raw, 2 vars, 3 points
wr $tmp/an.raw "Title: results select
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
# a second spice raw, so group C can prove `raw switch` is NOT `raw read`
wr $tmp/bn.raw "Title: results select 2
Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(n2)\tvoltage
Values:
0\t0.000000000000000e+00
\t5.000000000000000e+00

1\t1.000000000000000e-08
\t6.000000000000000e+00

"
# --- the non-spice fixture: a tabular file (header row + 3 data rows). `table`
#     is routed by raw_type_is_non_spice() into the OTHER what == 1 arm.
wr $tmp/t.table "time\ta\tb\n0.0\t1.0\t2.0\n1e-9\t3.0\t4.0\n2e-9\t5.0\t6.0\n"

# `-inplace` opts out of load window routing (doc/claude/specs/load_window_routing.md):
# a bare `xschem load` under a real display may open a NEW window and the rest of
# the script would then be talking to the wrong context.
proc loadcell {f} { xschem load -inplace $f ; xschem unselect_all }

# ===========================================================================
# A -- THE SPICE ARM (src/save.c:2037): dedupe on (rawfile, sim_type)
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL1-A-read-rc            [pcall xschem raw read $tmp/an.raw tran] 1
eqcheck SEL2-A-is-current         [pcall xschem raw rawfile] $tmp/an.raw
gecheck SEL3-A-resolves-under-A   [pcall xschem raw index v(n1)]
eqcheck SEL4-A-bound-at-level-0   [pcall xschem raw loaded] 0

# navigate to an unrelated cell: the DESIGNED blindness. This is not the bug and
# item 1 does not change it -- it is T-B's precondition, and a T-B that passed
# without it would be measuring nothing.
loadcell $tmp/cellB.sch
eqcheck SEL5-B-stamp-off-stack    [pcall xschem raw loaded] -1
eqcheck SEL6-B-blind-before       [pcall xschem raw index v(n1)] -1
eqcheck SEL7-B-still-registered   [expr {[string match "*an.raw tran*" [pcall xschem raw info]] ? 1 : 0}] 1

set slots_before [n_slots]
eqcheck SEL8-B-reread-rc          [pcall xschem raw read $tmp/an.raw tran] 1
eqcheck SEL9-B-no-slot-added      [n_slots] $slots_before
eqcheck SEL10-B-current-after     [pcall xschem raw rawfile] $tmp/an.raw
# ---- T-B, THE PAYLOAD, SPICE ARM ----
gecheck SEL11-B-resolves-after-reread [pcall xschem raw index v(n1)]
eqcheck SEL12-B-level-restamped   [pcall xschem raw loaded] [pcall xschem get currsch]
# and the data is the FILE's, not a re-parse artefact: same values as under A
eqcheck SEL13-B-value-after-reread [pcall xschem raw value v(n1) 2] 3

# ===========================================================================
# B -- THE NON-SPICE ARM (src/save.c:1981): dedupe on rawfile ALONE.
#      Patching only the arm above leaves 0509 alive for table and vcd.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL14-T-read-rc           [pcall xschem raw read $tmp/t.table table] 1
eqcheck SEL15-T-simtype           [pcall xschem raw sim_type] table
gecheck SEL16-T-resolves-under-A  [pcall xschem raw index a]

loadcell $tmp/cellB.sch
eqcheck SEL17-T-stamp-off-stack   [pcall xschem raw loaded] -1
eqcheck SEL18-T-blind-before      [pcall xschem raw index a] -1

set slots_before [n_slots]
eqcheck SEL19-T-reread-rc         [pcall xschem raw read $tmp/t.table table] 1
eqcheck SEL20-T-no-slot-added     [n_slots] $slots_before
eqcheck SEL21-T-current-after     [pcall xschem raw rawfile] $tmp/t.table
# ---- T-B, THE PAYLOAD, NON-SPICE ARM ----
gecheck SEL22-T-resolves-after-reread [pcall xschem raw index a]
eqcheck SEL23-T-level-restamped   [pcall xschem raw loaded] [pcall xschem get currsch]
eqcheck SEL24-T-value-after-reread [pcall xschem raw value a 1] 3

# ===========================================================================
# C -- R111: `raw switch` is NAVIGATION and does NOT re-bind.
#      Two databases, each read under a different cell; switching to the one
#      bound elsewhere must succeed AND stay blind. If switch ever starts
#      re-stamping, SEL30 goes red and the two verbs have collapsed into one.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL25-C-read-A            [pcall xschem raw read $tmp/an.raw tran] 1
loadcell $tmp/cellB.sch
eqcheck SEL26-C-read-B            [pcall xschem raw read $tmp/bn.raw tran] 1
gecheck SEL27-C-B-resolves        [pcall xschem raw index v(n2)]
# switch (not read) to the database bound to cell A, while standing on B
eqcheck SEL28-C-switch-rc         [pcall xschem raw switch $tmp/an.raw tran] 1
eqcheck SEL29-C-switch-is-current [pcall xschem raw rawfile] $tmp/an.raw
eqcheck SEL30-C-switch-did-NOT-rebind [pcall xschem raw index v(n1)] -1
eqcheck SEL31-C-switch-level-untouched [pcall xschem raw loaded] -1
# ...and a READ of that very same slot, one line later, DOES re-bind it. Same
# path, same type, same registry: the only difference is the verb.
set slots_c_before [slot_list]
eqcheck SEL32-C-read-rebinds-rc   [pcall xschem raw read $tmp/an.raw tran] 1
gecheck SEL33-C-read-rebinds      [pcall xschem raw index v(n1)]
# ...and it re-bound WITHOUT touching the rest of the registry. This is the only
# group holding two slots, so it is the only place the destructive half of F7
# can be measured at all; a count comparison in a one-slot registry cannot move.
eqcheck SEL50-C-registry-intact   [slot_list] $slots_c_before

# ===========================================================================
# D -- THE GUARD: a re-read while DESCENDED must not move the binding DOWN.
#      Crew refinement of R110 (spec section 3.1). With the unconditional
#      re-stamp this ascends BLIND: loaded=-1, index=-1 at the top level, a new
#      instance of 0509 pointing the other way.
# ===========================================================================
set hidlib [file normalize [file join [file dirname [info script]] fixtures hi_descend hidlib]]
lappend pathlist $hidlib
set hidtop [file join $hidlib top schematic top.sch]
xschem raw clear
loadcell $hidtop
eqcheck SEL34-D-top-read          [pcall xschem raw read $tmp/an.raw tran] 1
eqcheck SEL35-D-top-level         [pcall xschem raw loaded] 0
xschem select instance 0
xschem descend
eqcheck SEL36-D-descended         [file tail [pcall xschem get schname]] leaf.sch
eqcheck SEL37-D-ancestor-stamp-ok [pcall xschem raw loaded] 0
eqcheck SEL38-D-reread-rc         [pcall xschem raw read $tmp/an.raw tran] 1
eqcheck SEL39-D-level-not-moved   [pcall xschem get raw_level] 0
xschem go_back
eqcheck SEL40-D-back-at-top       [file tail [pcall xschem get schname]] top.sch
eqcheck SEL41-D-top-still-bound   [pcall xschem raw loaded] 0
gecheck SEL42-D-top-still-resolves [pcall xschem raw index v(n1)]

# ===========================================================================
# E -- THE LEVEL HALF OF THE STAMP, MADE OBSERVABLE. Cells A and B are both
#      top level, so raw->level is 0 either way there and a raw_level check on
#      them cannot go red -- it would pass before the fix, which is the
#      definition of a vacuous check. Read the database one level DOWN instead:
#      the re-stamp then has to move raw->level 1 -> 0, not merely rewrite
#      raw->schname.
# ===========================================================================
xschem raw clear
loadcell $hidtop
xschem select instance 0
xschem descend
eqcheck SEL43-E-descended         [file tail [pcall xschem get schname]] leaf.sch
eqcheck SEL44-E-read-at-level-1   [expr {[pcall xschem raw read $tmp/an.raw tran] eq "1" \
                                         && [pcall xschem get raw_level] eq "1"}] 1
loadcell $tmp/cellB.sch
eqcheck SEL45-E-unrelated-blind   [pcall xschem raw loaded] -1
eqcheck SEL46-E-reread-rc         [pcall xschem raw read $tmp/an.raw tran] 1
# ---- the LEVEL half: 1 -> 0 ----
eqcheck SEL47-E-level-moved       [pcall xschem get raw_level] 0
eqcheck SEL48-E-loaded-here       [pcall xschem raw loaded] 0
gecheck SEL49-E-resolves-here     [pcall xschem raw index v(n1)]

# ===========================================================================
# F -- U10: A DRAW IS NOT A READ. The graph walkers in src/draw.c reach the very
#      same what == 1 dedupe arm, with `autoload` (1, or 33) as a reader
#      dispatch flag, while merely PAINTING a rect that carries `autoload=`.
#      The first cut of R110 re-stamped there too, so simply OPENING an
#      unrelated schematic that carries such a graph silently re-bound the
#      database to it and blinded the cell the user had actually read it under
#      -- 0509's own symptom one door along, and a contradiction of driver
#      ruling U10 (DECISIONS.md). The re-bind is now opt-in (RAW_READ_REBIND,
#      src/xschem.h) and only the `read` verbs opt in.
#
#      NOTE ON ARMS: `xschem draw_graph` is has_x-gated (src/scheduler.c:3401)
#      and an implicit redraw needs a window too, so under --nogui this group
#      draws nothing and its checks are vacuous. They are REAL under X, which is
#      the arm run_suites.sh and full_audit.sh both use. Stated rather than
#      skipped: a per-group skip line would make full_audit.sh discard the whole
#      file.
# ===========================================================================
# graph cell with an explicit rawfile= token...
wr $tmp/cellG.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 100 200 100 {}\nB 2 100 -300 700 -100 {flags=graph\nnode=\"v(n1)\"\nx1=0\nx2=2e-8\ny1=0\ny2=4\nrawfile=$tmp/an.raw\nsim_type=tran\nautoload=1}\n"
# ...and one with NO rawfile= token, where custom_rawfile falls back to the
# CURRENT database's own path (src/draw.c:8968-8971) -- the shipped default in
# xschem_library/examples/*.sch, and the same door.
wr $tmp/cellH.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 100 200 100 {}\nB 2 100 -300 700 -100 {flags=graph\nnode=\"v(n1)\"\nx1=0\nx2=2e-8\ny1=0\ny2=4\nsim_type=tran\nautoload=1}\n"

xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL51-F-read-under-A      [pcall xschem raw read $tmp/an.raw tran] 1
gecheck SEL52-F-A-resolves        [pcall xschem raw index v(n1)]
loadcell $tmp/cellG.sch
catch {xschem draw_graph 0}
# THE PAYLOAD: the graph cell is NOT the raw's design, and drawing it must not
# make it one. Pre-fix this was 0 -- the draw had re-bound the database.
eqcheck SEL53-F-graphcell-still-blind [pcall xschem raw loaded] -1
loadcell $tmp/cellA.sch
eqcheck SEL54-F-A-still-bound     [pcall xschem raw loaded] 0
gecheck SEL55-F-A-still-resolves  [pcall xschem raw index v(n1)]
# the no-rawfile= variant, same two payload assertions
loadcell $tmp/cellH.sch
catch {xschem draw_graph 0}
eqcheck SEL56-F-implicit-still-blind [pcall xschem raw loaded] -1
loadcell $tmp/cellA.sch
gecheck SEL57-F-implicit-A-resolves  [pcall xschem raw index v(n1)]

# ===========================================================================
# G -- R110b, THE CASE-MODE RE-PRIME, given the check it did not have.
#      raw_case_mode_schematic() only answers while the raw's own schematic is
#      current; one level DOWN it REPLAYS the cached verdict
#      (src/save.c:2877-2883). So a re-bind that did not re-prime leaves cell
#      A's verdict to be replayed as cell B's answer. Measured in the fix round:
#      with the re-prime removed this reads `fold` -- cellCase's answer -- from
#      inside hidlib, which has nothing to do with that file.
# ===========================================================================
wr $tmp/cn.raw "Title: results select case
Plotname: Transient Analysis
Flags: real
No. Variables: 3
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(mixedone)\tvoltage
\t2\tv(mixedtwo)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00
\t2.000000000000000e+00

1\t1.000000000000000e-08
\t3.000000000000000e+00
\t4.000000000000000e+00

"
# two wire labels the raw folded: node `mixedone` vs label `MixedOne` -> a fold
# vote each, two comparable names, a clean majority.
wr $tmp/cellCase.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 0 200 0 {lab=MixedOne}\nN 0 20 200 20 {lab=MixedTwo}\n"

xschem raw clear
loadcell $tmp/cellCase.sch
eqcheck SEL58-G-read-rc           [pcall xschem raw read $tmp/cn.raw tran] 1
eqcheck SEL59-G-verdict-under-A   [pcall xschem raw casemode -schematic] fold
loadcell $hidtop
eqcheck SEL60-G-unrelated-blind   [pcall xschem raw loaded] -1
# NOTHING may ask for the verdict between here and the descend: a live query at
# hidtop would itself re-stamp sch_case_mode and mask the very hole this checks.
eqcheck SEL61-G-rebind-rc         [pcall xschem raw read $tmp/cn.raw tran] 1
xschem select instance 0
xschem descend
eqcheck SEL62-G-descended         [file tail [pcall xschem get schname]] leaf.sch
# ---- THE PAYLOAD: the replayed verdict is hidlib's own `unknown`, not
#      cellCase's `fold` carried across the re-bind ----
eqcheck SEL63-G-verdict-reprimed  [pcall xschem raw casemode -schematic] unknown
xschem go_back

# ===========================================================================
# H -- THE RE-STAMP IS TAKEN FROM xctx->sch[xctx->currsch], NOT FROM sch[0].
#      Every re-read in groups A/B/C/E happens at currsch == 0, and group D's is
#      the one case the guard turns into a no-op -- so hardcoding the stamp to
#      the top level left all 49 original checks green while measurably changing
#      behaviour. Re-read an OFF-STACK database while descended in an unrelated
#      hierarchy: raw_level and `raw loaded` must both come out 1.
#      The level is load-bearing, not cosmetic: `start_level = sch_waves_loaded()`
#      builds the hierarchy-relative node path (src/hilight.c:440, :1880, :2846,
#      src/token.c:4339, :4528, :4721).
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
loadcell $hidtop
xschem select instance 0
xschem descend
eqcheck SEL64-H-descended         [expr {[file tail [pcall xschem get schname]] eq "leaf.sch" \
                                         && [pcall xschem get currsch] eq "1"}] 1
eqcheck SEL65-H-blind-before      [pcall xschem raw loaded] -1
eqcheck SEL66-H-reread-rc         [pcall xschem raw read $tmp/an.raw tran] 1
eqcheck SEL67-H-level-is-currsch  [pcall xschem get raw_level] 1
eqcheck SEL68-H-loaded-at-1       [pcall xschem raw loaded] 1
gecheck SEL69-H-resolves-here     [pcall xschem raw index v(n1)]
xschem go_back

# ===========================================================================
# I -- THE GUARD STILL REFRESHES THE LEVEL. R110a returns early when the stamp
#      already resolves, which left raw->level un-refreshed and able to sit
#      ABOVE xctx->currsch: read leaf.sch one level down (level 1), then open
#      that same cell FLAT (currsch 0) and re-read it. `xschem set raw_level`
#      refuses to write such a value (0 <= n <= currsch, src/scheduler.c:12291)
#      and the four ngspice path builders in src/xschem.tcl read the field
#      directly -- with a stale level they return an EMPTY string where they owe
#      a `?`. schname is left alone, so R110a itself is unchanged.
# ===========================================================================
set hidleaf [file join $hidlib leaf schematic leaf.sch]
xschem raw clear
loadcell $hidtop
xschem select instance 0
xschem descend
eqcheck SEL70-I-read-at-level-1   [expr {[pcall xschem raw read $tmp/an.raw tran] eq "1" \
                                         && [pcall xschem get raw_level] eq "1"}] 1
loadcell $hidleaf
# same schematic, now at the TOP of the stack: the stamp still resolves, so the
# R110a guard returns early -- and that is exactly where the level went stale.
eqcheck SEL71-I-flat-same-cell    [expr {[pcall xschem raw loaded] eq "0" \
                                         && [pcall xschem get currsch] eq "0"}] 1
eqcheck SEL72-I-reread-rc         [pcall xschem raw read $tmp/an.raw tran] 1
eqcheck SEL73-I-level-refreshed   [pcall xschem get raw_level] 0
# the behavioural consequence, not just the field: an out-of-range level makes
# these two hand back "" instead of their normal "?"
eqcheck SEL74-I-annotate-answers  [expr {[pcall ngspice::get_voltage n1] ne ""}] 1

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_results_select: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
