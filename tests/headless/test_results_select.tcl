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

# --- the DIGITAL fixture: a minimal VCD, the other half of R102 ("a result is
#     not a VCD or a table database"). Same shape as test_backannotate_digital's
#     mkvcd, written flat -- one scope, one 1-bit wire, three ticks.
wr $tmp/d.vcd "\$timescale 1ns \$end
\$scope module top \$end
 \$scope module m \$end
  \$var wire 1 ! dsig \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#50
1!
#100
"

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

# ===========================================================================
# ITEM 2 -- src/results.tcl: the PURE resolver and the registry READERS.
# doc/claude/specs/results_selection.md sections 4 (R201-R204) and 5 (R304,
# R305). Groups J..N, SEL75..SEL137 (SEL127..SEL137 added by the FIX ROUND).
# Band measured free 2026-08-19:
# `grep -hoE '\bSEL[0-9]+\b' tests/headless/*.tcl | sed s/SEL// | sort -n | tail -1`
# -> 74. No item-1 id is renumbered or restated; item 2 only appends.
#
# Nothing here mutates through results.tcl -- that is the point of the item.
# `results::select` is item 4 and does not exist yet; if a check below ever
# needs it, the check is in the wrong file.
# ===========================================================================

set r2_root [file normalize [file join [file dirname [info script]] .. ..]]
proc r2_rd {path} {
  if {![file isfile $path]} { return {} }
  set fp [open $path r] ; set t [read $fp] ; close $fp ; return $t
}
# the words of Makefile.in's install list. The block is a scconfig tmpasm
# `put /local/src { ... }`-style list and holds no closing brace of its own.
proc r2_shares {text} {
  if {![regexp {put\s+/local/install_shares\s*\{([^\}]*)\}} $text -> blk]} { return {} }
  return [regexp -all -inline {\S+} $blk]
}
# T-K's detector, first half. The by-word idiom is TWO lines --
#   set rawlist [lrange [xschem raw info] 2 end]
#   foreach {n f t} $rawlist { ... }
# -- so both shapes are hunted, and a THREE-variable foreach is treated as the
# signature on its own: it is what assumes "every slot is exactly three words",
# which is the assumption a path containing a space breaks (issue 0507).
# Deliberately broad, deliberately scoped to one file. COMMENT lines are
# skipped: this file's own header describes the trap in prose and must not
# trip the detector that forbids it. SEL84 is the positive control -- a
# detector that finds nothing is not evidence until it has been shown to find
# something.
proc r2_byword {text} {
  set hits {}
  foreach line [split $text "\n"] {
    set l [string trim $line]
    if {[string index $l 0] eq "#"} continue
    if {[regexp {lrange\s+\[[^\]]*raw\s+info} $l]} { lappend hits $l ; continue }
    if {[regexp {foreach\s+\{\s*[A-Za-z_]\w*\s+[A-Za-z_]\w*\s+[A-Za-z_]\w*\s*\}} $l]} {
      lappend hits $l
    }
  }
  return $hits
}
# the CODE of a Tcl file -- comment lines dropped. What a file SAYS about a
# rule is not the same evidence as what it DOES.
proc r2_code {text} {
  set out {}
  foreach line [split $text "\n"] {
    set l [string trim $line]
    if {[string index $l 0] eq "#"} continue
    lappend out $l
  }
  return [join $out "\n"]
}
proc dg {d k} { if {[catch {dict get $d $k} v]} { return "ERR:$v" } ; return $v }

set r2_tcl   [file join $r2_root src results.tcl]
set r2_xtcl  [file join $r2_root src xschem.tcl]
set r2_mkin  [file join $r2_root src Makefile.in]
set r2_mk    [file join $r2_root src Makefile]

# ===========================================================================
# J -- WIRED UP SO IT ACTUALLY SHIPS.
#      A new helper .tcl that is SOURCED but not INSTALLED is a known failure
#      class in this tree: it works in the source tree, where every test runs,
#      and is missing for every installed user. Both halves are pinned, plus
#      the runtime half -- `info procs` inside the RUNNING binary is the only
#      one of the three that cannot be satisfied by a comment.
# ===========================================================================
eqcheck SEL75-J-procs-defined-in-the-running-binary \
  [lsort [list [expr {[info procs ::results::resolve] ne {}}] \
               [expr {[info procs ::results::list] ne {}}] \
               [expr {[info procs ::results::current] ne {}}]]] {1 1 1}
eqcheck SEL76-J-file-on-disk        [file isfile $r2_tcl] 1
# an UNCOMMENTED source line: `# source ...` still matches a naive glob, and a
# commented-out one is exactly the regression this check exists to catch.
eqcheck SEL77-J-sourced-from-xschem-tcl \
  [llength [lsearch -all -inline -regexp [split [r2_rd $r2_xtcl] "\n"] \
              {^\s*source\s+\$XSCHEM_SHAREDIR/results\.tcl\s*$}]] 1
eqcheck SEL78-J-in-Makefile-in-install-list \
  [expr {[lsearch -exact [r2_shares [r2_rd $r2_mkin]] results.tcl] >= 0 ? 1 : 0}] 1
# the parse itself is proved, not assumed: it must find a file that IS in the
# list and must not find one that is not.
eqcheck SEL79-J-install-list-parse-discriminates \
  [list [expr {[lsearch -exact [r2_shares [r2_rd $r2_mkin]] wave_viewer.tcl] >= 0 ? 1 : 0}] \
        [expr {[lsearch -exact [r2_shares [r2_rd $r2_mkin]] no_such_helper.tcl] >= 0 ? 1 : 0}]] \
  {1 0}
# and the GENERATED Makefile carries the rule, i.e. ./configure was re-run
# after Makefile.in was edited. Editing the .in alone installs nothing.
eqcheck SEL80-J-generated-install-rule \
  [expr {[string match {*install -f results.tcl*} [r2_rd $r2_mk]] ? 1 : 0}] 1
eqcheck SEL81-J-generated-uninstall-rule \
  [expr {[string match {*rm "$(XSHAREDIR)"/results.tcl*} [r2_rd $r2_mk]] ? 1 : 0}] 1

# ===========================================================================
# K -- T-K, FIRST HALF: this file introduces NO by-word parse of
#      `xschem raw info` (R304, issue 0507's ruling). The second half -- that
#      `raw_is_loaded`'s own by-word parser dies -- is item 9's, DELIVERED in
#      group AP (SEL459-SEL474) at the bottom of this file.
# ===========================================================================
set r2_src [r2_rd $r2_tcl]
# A CALL, NOT A MENTION. Measured: with this check written as a whole-file grep,
# replacing the rawinfo_parse call with a hand-rolled per-line copy left it
# green -- the citations block at the top of results.tcl names the proc in
# prose, and prose is not a call. Comment lines are therefore stripped first,
# and the trailing space makes `..._XX $txt` fail to match.
eqcheck SEL82-K-built-on-rawinfo_parse \
  [expr {[string match {*wviewer::rawinfo_parse *} [r2_code $r2_src]] ? 1 : 0}] 1
eqcheck SEL83-K-no-by-word-parser     [r2_byword $r2_src] {}
eqcheck SEL84-K-detector-fires-on-the-real-idiom \
  [llength [r2_byword "set rawlist \[lrange \[xschem raw info\] 2 end\]\nforeach {n f t} \$rawlist { }\n"]] 2

# ===========================================================================
# L -- T-H: THE FOUR RESOLVER STATUSES.
#      "Each produces its own sentence; `stale` still yields the NAMED path,
#      `invalid` yields the derived path when one exists on disk and {}
#      otherwise, never an error."
# ===========================================================================
# a registry with TWO slots and the current one NOT slot 0, so that SEL112's
# purity comparison has something to lose. Both halves are load-bearing and both
# were measured: against an EMPTY registry a resolver that called
# `xschem raw clear` still compares equal, and with ONE slot loaded (slot 0
# already current) a planted `catch {xschem raw switch 0}` is a no-op and the
# before/after blobs match -- that exact sabotage passed 128/128. SEL127 guards
# the second half the way SEL119a/SEL125a guard theirs.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
xschem raw read $tmp/bn.raw tran

set r2_derived [file join $tmp derived.raw]
file copy -force $tmp/an.raw $r2_derived
set r2_const [file join $tmp constants.raw]
# the measured ngspice-46 signature of a run whose only fault was a `.save` of
# a node the circuit does not have -- copied from test_ase_preflight PF219.
wr $r2_const "Title: Constant values
Date: Sun Aug  2 23:29:26 UTC 2026
Command: ngspice-46, Build Sun Aug  2 23:29:26 UTC 2026
Plotname: constants
Flags: complex
No. Variables: 12
No. Points: 1
Variables:
\t0\tyes\tnotype
\t1\tfalse\tnotype
Binary:
"
# the mtime half needs no clock race: both stamps are written explicitly.
set r2_old [file join $tmp old.raw]
set r2_new [file join $tmp new.raw]
set r2_nl  [file join $tmp cellA.spice]
file copy -force $tmp/an.raw $r2_old
file copy -force $tmp/an.raw $r2_new
wr $r2_nl "* netlist\n.end\n"
file mtime $r2_old 1000000000
file mtime $r2_nl  1000001000
file mtime $r2_new 1000002000
set r2_gone [file join $tmp gone.raw]
catch {file delete $r2_gone}
set r2_nodev [file join $tmp no_derived_here.raw]
catch {file delete $r2_nodev}

set r2_info_before [pcall xschem raw info]
eqcheck SEL127-L-preload-current-is-not-slot-0 \
  [expr {[string match {1 current*} $r2_info_before] ? 1 : 0}] 1

# --- default -----------------------------------------------------------
set d0 [pcall results::resolve {}]
eqcheck SEL85-L-default-no-derived    [list [dg $d0 status] [dg $d0 path]] {default {}}
set d1 [pcall results::resolve [dict create derived $r2_derived]]
eqcheck SEL86-L-default-uses-derived  [list [dg $d1 status] [dg $d1 path]] [list default $r2_derived]
# T-H's "when one exists on disk": a derived path that is NOT there is not a
# usable answer and is not handed back as one.
set d2 [pcall results::resolve [dict create derived $r2_nodev]]
eqcheck SEL87-L-default-derived-must-exist [list [dg $d2 status] [dg $d2 path]] {default {}}

# --- ok ----------------------------------------------------------------
set o1 [pcall results::resolve [dict create rawfile $tmp/an.raw]]
eqcheck SEL88-L-ok-absolute           [list [dg $o1 status] [dg $o1 path]] [list ok $tmp/an.raw]
# R602's saved form: a RELATIVE rawfile is resolved against the rundir. This is
# the shape ase::ui::viewer_restore already implements by hand (ase_window.tcl:4356-4363).
set o2 [pcall results::resolve [dict create rawfile an.raw rundir $tmp]]
eqcheck SEL89-L-ok-relative-vs-rundir [list [dg $o2 status] [dg $o2 path]] [list ok [file join $tmp an.raw]]
eqcheck SEL90-L-ok-sentence-names-the-file \
  [expr {[dg $o1 msg] ne {} && [string match {*an.raw*} [dg $o1 msg]] ? 1 : 0}] 1

# --- stale, half one: the CONTENT verdict (R203, ase::raw_content_verdict) ---
set s1 [pcall results::resolve [dict create rawfile $r2_const]]
eqcheck SEL91-L-stale-content-status  [list [dg $s1 status] [dg $s1 reason]] {stale content}
# R202: STILL THE NAMED PATH. `stale` is selectable; only `invalid` falls back.
eqcheck SEL92-L-stale-yields-the-named-path [dg $s1 path] $r2_const
# and the sentence is the content check's OWN sentence, not a reimplementation
# of it -- R203 forbids a second content check, so the words must come from
# ase::raw_content_verdict.
eqcheck SEL93-L-stale-why-is-the-verdicts-own-words \
  [expr {([string match {*twelve built-in*} [dg $s1 why]] \
          && [dg $s1 why] eq [dg [pcall ase::raw_content_verdict $r2_const] why]) ? 1 : 0}] 1
# a derived path present must NOT displace a stale result
set s2 [pcall results::resolve [dict create rawfile $r2_const derived $r2_derived]]
eqcheck SEL94-L-stale-is-not-replaced-by-the-derived [dg $s2 path] $r2_const

# --- stale, half two: OLDER THAN ITS NETLIST ---------------------------
set m1 [pcall results::resolve [dict create rawfile $r2_old netlist $r2_nl]]
eqcheck SEL95-L-stale-mtime-status    [list [dg $m1 status] [dg $m1 reason]] {stale mtime}
eqcheck SEL96-L-stale-mtime-yields-named-path [dg $m1 path] $r2_old
eqcheck SEL97-L-stale-mtime-sentence-names-the-netlist \
  [expr {[string match {*cellA.spice*} [dg $m1 msg]] ? 1 : 0}] 1
set m2 [pcall results::resolve [dict create rawfile $r2_new netlist $r2_nl]]
eqcheck SEL98-L-newer-than-netlist-is-ok [dg $m2 status] ok
# no netlist named -> the mtime half never fires, on the SAME file that is
# stale when one is named. Without this, "always stale" would pass SEL95.
set m3 [pcall results::resolve [dict create rawfile $r2_old]]
eqcheck SEL99-L-no-netlist-no-mtime-half [dg $m3 status] ok

# --- invalid -----------------------------------------------------------
set i1 [pcall results::resolve [dict create rawfile $r2_gone derived $r2_derived]]
eqcheck SEL100-L-invalid-falls-back   [list [dg $i1 status] [dg $i1 path]] [list invalid $r2_derived]
eqcheck SEL101-L-invalid-keeps-the-named-path [dg $i1 named] $r2_gone
set i2 [pcall results::resolve [dict create rawfile $r2_gone]]
eqcheck SEL102-L-invalid-no-derived   [list [dg $i2 status] [dg $i2 path]] {invalid {}}
set i3 [pcall results::resolve [dict create rawfile $r2_gone derived $r2_nodev]]
eqcheck SEL103-L-invalid-derived-must-exist [list [dg $i3 status] [dg $i3 path]] {invalid {}}

# R201c: a file that EXISTS but cannot be READ is `invalid`/`unreadable`, never
# `stale`. R202 makes stale a status the user may still SELECT and an unreadable
# file cannot be selected, so offering it would be offering a choice that cannot
# be honoured. Measured: deleting the whole `_readable` arm from results.tcl
# left the suite green at 128/128 -- the arm reported `ok`, contradicting R201's
# own table, and nothing asked.
set r2_unread [file join $tmp unread.raw]
file copy -force $tmp/an.raw $r2_unread
catch {file attributes $r2_unread -permissions 0000}
# the fixture must actually deny the read or the check below is vacuous. Run as
# a user the permission bits do not bind (root) this guard fails LOUDLY, which
# is the honest report: the arm was not driven.
eqcheck SEL128-L-unreadable-fixture-denies-read \
  [list [file isfile $r2_unread] [file readable $r2_unread]] {1 0}
set u1 [pcall results::resolve [dict create rawfile $r2_unread derived $r2_derived]]
eqcheck SEL129-L-unreadable-is-invalid-not-stale \
  [list [dg $u1 status] [dg $u1 reason] [dg $u1 path]] \
  [list invalid unreadable $r2_derived]
catch {file attributes $r2_unread -permissions 0644}

# --- IT NEVER THROWS (R201/R202) ---------------------------------------
# a DIRECTORY where a file was named, and a `state` that is not a well-formed
# dict. Both used to be the two obvious ways to turn a restore into a stack
# trace; both must answer a status instead.
set n1 [pcall results::resolve [dict create rawfile $tmp]]
eqcheck SEL104-L-directory-is-answered-not-thrown [dg $n1 status] invalid
set n2 [pcall results::resolve {a b c}]
eqcheck SEL105-L-malformed-state-is-answered [dg $n2 status] default
set n3 [pcall results::resolve [dict create rawfile "   "]]
eqcheck SEL106-L-blank-rawfile-is-default   [dg $n3 status] default

# --- one sentence each, four different ones ----------------------------
set r2_msgs [list [dg $d0 msg] [dg $o1 msg] [dg $s1 msg] [dg $i1 msg]]
eqcheck SEL107-L-four-statuses-four-sentences \
  [list [llength [lsort -unique $r2_msgs]] [lsearch -exact $r2_msgs {}]] {4 -1}

# R805a -- ONE terminator, not two. The content half's `why` is quoted verbatim
# from ase::raw_content_verdict (R203) and is already a finished, full-stopped
# sentence, so "Using X, but $why." ended in "..". The second element is the
# non-vacuity half: it asserts the verdict's own sentence STILL ends in a full
# stop, so this check is about the COMPOSITION and cannot be satisfied by
# restyling the verdict -- which R203 forbids anyway.
eqcheck SEL136-L-stale-sentence-has-one-terminator \
  [list [expr {[string match {*..} [dg $s1 msg]] ? 1 : 0}] \
        [expr {[string index [dg $s1 why] end] eq {.} ? 1 : 0}]] {0 1}
# R803/R803a -- the sentences name the database by FILE TAIL; the full path
# lives in the balloon and in the returned `named` field. The `invalid` pair
# were the two that shouted a 120-character absolute path into R404's one-line
# Status region while the other three statuses already used the tail.
eqcheck SEL137-L-invalid-sentence-names-by-tail-not-full-path \
  [list [expr {[string match "*[file tail $r2_gone]*" [dg $i1 msg]] ? 1 : 0}] \
        [string first $tmp [dg $i1 msg]] \
        [string first $tmp [dg $i2 msg]] \
        [dg $i1 named]] [list 1 -1 -1 $r2_gone]

# --- the `key` arm IS ase::last_rawfile (section 4's named default) -----
# shimmed, the way L1 says select_raw must be: the real one needs a live ASE
# session and a backend hook, and what is under test here is that the resolver
# ASKS it, and that an explicit `derived` outranks it.
rename ase::last_rawfile r2_lrf_orig
proc ase::last_rawfile {key} {
  if {$key eq {r2key}} { return $::r2_derived }
  return {}
}
set k1 [pcall results::resolve [dict create key r2key]]
eqcheck SEL108-L-key-supplies-the-derived-default [list [dg $k1 status] [dg $k1 path]] \
  [list default $r2_derived]
set k2 [pcall results::resolve [dict create key r2key derived $r2_old]]
eqcheck SEL109-L-explicit-derived-outranks-key [dg $k2 path] $r2_old
set k3 [pcall results::resolve [dict create key nosuchsession]]
eqcheck SEL110-L-unknown-key-is-not-an-error [list [dg $k3 status] [dg $k3 path]] {default {}}
rename ase::last_rawfile {}
rename r2_lrf_orig ase::last_rawfile
eqcheck SEL111-L-shim-restored [expr {[info procs ::ase::last_rawfile] ne {} ? 1 : 0}] 1

# --- R204: PURE. None of the above touched the registry ----------------
eqcheck SEL112-L-resolver-is-pure [pcall xschem raw info] $r2_info_before

# ===========================================================================
# M -- R304: results::list, built on wviewer::rawinfo_parse.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL113-M-empty-registry-is-empty-list [pcall results::list] {}

xschem raw read $tmp/an.raw tran
set l1 [pcall results::list]
eqcheck SEL114-M-one-db-shape [expr {[llength $l1] == 1 ? [lindex $l1 0] : "len=[llength $l1]"}] \
  [dict create idx 0 path $tmp/an.raw type tran cur 1 label "an.raw (tran)"]

xschem raw read $tmp/bn.raw tran
set l2 [pcall results::list]
set r2_cur {}
set r2_ncur 0
foreach r $l2 { if {[dg $r cur] eq {1}} { incr r2_ncur ; set r2_cur $r } }
eqcheck SEL115-M-two-dbs-exactly-one-current [list [llength $l2] $r2_ncur] {2 1}
eqcheck SEL116-M-current-is-the-last-read     [dg $r2_cur path] $tmp/bn.raw
# the idx column is the ENGINE's, not a position in this list
eqcheck SEL117-M-idx-agrees-with-the-engine \
  [list [dg [lindex $l2 0] idx] [dg [lindex $l2 1] idx]] {0 1}

# ---- issue 0507's case, and the whole reason R304 exists: A PATH WITH A
#      SPACE. The by-word parse turns this one database into two malformed
#      slots and truncates the path at the space; the per-line parser does not.
set r2_spdir [file join $tmp "raw dir"]
file mkdir $r2_spdir
set r2_sp [file join $r2_spdir "sp ace.raw"]
file copy -force $tmp/an.raw $r2_sp
xschem raw read $r2_sp tran
set l3 [pcall results::list]
set r2_hit {}
foreach r $l3 { if {[dg $r path] eq $r2_sp} { set r2_hit $r } }
eqcheck SEL118-M-space-in-path-round-trips-intact \
  [list [llength $l3] [dg $r2_hit path] [dg $r2_hit type] [dg $r2_hit label]] \
  [list 3 $r2_sp tran "sp ace.raw (tran)"]

# the current slot must NOT be slot 0 when the blob is captured: measured, a
# `xschem raw switch 0` planted inside results::list was invisible to this
# check when slot 0 was already current.
xschem raw switch $r2_sp tran
set r2_info_before [pcall xschem raw info]
eqcheck SEL119a-M-preload-current-is-not-slot-0 \
  [expr {[string match {2 current*} $r2_info_before] ? 1 : 0}] 1
pcall results::list ; pcall results::list
eqcheck SEL119-M-list-is-read-only [pcall xschem raw info] $r2_info_before

# ===========================================================================
# N -- R305 / F4: A LOADED-BUT-BLIND DATABASE IS NOT A SELECTION.
#      R103 defines a selection in three parts -- in the registry, current,
#      AND its schname/level stamp resolves against the current hierarchy
#      stack. The third is the one that is easy to drop, and dropping it is
#      how the Calculator ends up evaluating against a database in which no
#      signal name resolves.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
set c1 [pcall results::current]
eqcheck SEL120-N-current-is-the-cur-entry-of-list \
  [list $c1 [dg $c1 path]] [list [lindex [pcall results::list] 0] $tmp/an.raw]

# navigate to an unrelated cell: parts 1 and 2 still hold, part 3 does not.
loadcell $tmp/cellB.sch
eqcheck SEL121-N-blind-off-stack [pcall xschem raw loaded] -1
eqcheck SEL122-N-still-registered-and-still-current \
  [list [llength [pcall results::list]] [dg [lindex [pcall results::list] 0] cur] \
        [pcall xschem raw rawfile]] [list 1 1 $tmp/an.raw]
# ---- THE PAYLOAD ----
eqcheck SEL123-N-blind-is-NOT-a-selection [pcall results::current] {}

# item 1's re-stamp puts it back, and results::current must see that
xschem raw read $tmp/an.raw tran
set c2 [pcall results::current]
eqcheck SEL124-N-restamped-is-a-selection-again \
  [list [expr {$c2 ne {}}] [dg $c2 path]] [list 1 $tmp/an.raw]

# a second slot, and the FIRST one deliberately not current: with one database
# loaded, or with slot 0 already current, a stray switch inside these readers
# moves nothing and the comparison proves nothing.
xschem raw read $tmp/bn.raw tran
set r2_info_before [pcall xschem raw info]
eqcheck SEL125a-N-preload-current-is-not-slot-0 \
  [expr {[string match {1 current*} $r2_info_before] ? 1 : 0}] 1
# R103 part 2 -- THE CURRENT SLOT, not the first one. SEL120 and SEL124 each
# run against a ONE-slot registry, where a results::current that ignores `cur`
# entirely and returns [lindex [results::list] 0] is indistinguishable from a
# correct one: measured, that exact rewrite passed 128/128. Here slot 1 is
# current and slot 0 is not, so the two answers differ.
set c3 [pcall results::current]
eqcheck SEL130-N-current-is-the-CURRENT-slot-not-the-first \
  [list [dg $c3 path] [dg $c3 idx] [dg $c3 cur]] [list $tmp/bn.raw 1 1]
pcall results::current ; pcall results::current
eqcheck SEL125-N-current-is-read-only [pcall xschem raw info] $r2_info_before

# ---- R102 / R305b: A VCD OR A TABLE IS A LOADED DATABASE, NOT A SELECTED
#      RESULT. This is not a hypothetical shape -- it is what the real run path
#      leaves behind: ase::attach_dbs reads the analog raw and THEN the VCDs
#      (L8, src/ase.tcl:2904-2919) and switches back to slot 0 only
#      `if {[llength $got]}`. R305 hands results::current to the Calculator's
#      Results Dir row, so an unfiltered answer puts a `.vcd` in the field that
#      names what Evaluate reads.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
xschem raw read $tmp/d.vcd vcd
# the premise, asserted rather than assumed: the VCD really is the current slot
# and the engine really does class it digital.
eqcheck SEL131-N-vcd-is-the-current-slot \
  [list [expr {[string match {1 current*} [pcall xschem raw info]] ? 1 : 0}] \
        [pcall xschem raw is_digital vcd]] {1 1}
eqcheck SEL132-N-vcd-current-is-not-a-selection [pcall results::current] {}
# R304a is NOT weakened by the gate: the registry READER still lists every slot,
# because results::select must see them to answer "is this path already loaded?".
set l4 [pcall results::list]
eqcheck SEL133-N-vcd-is-still-listed-by-results-list \
  [list [llength $l4] [dg [lindex $l4 1] type] [dg [lindex $l4 1] cur]] {2 vcd 1}
# and the gate refuses one TYPE, it does not disable results::current: switch
# back to the analog slot and the selection is real again.
xschem raw switch $tmp/an.raw tran
eqcheck SEL134-N-analog-slot-is-a-selection-again \
  [dg [pcall results::current] path] $tmp/an.raw
# the TABLE half of R102, which the VCD check cannot stand in for: `xschem raw
# is_digital table` answers 0 on purpose (test_backannotate_digital BA12 -- a
# table is columns of real numbers, analog data by another reader), so the
# engine's digital predicate does not reach it.
xschem raw read $tmp/t.table table
set l5 [pcall results::list]
eqcheck SEL135-N-table-current-is-not-a-selection \
  [list [pcall results::current] [dg [lindex $l5 2] type] [dg [lindex $l5 2] cur]] \
  {{} table 1}

xschem raw clear
eqcheck SEL126-N-nothing-loaded-no-selection [pcall results::current] {}

# ===========================================================================
# ITEM 3 -- `xschem raw select <file> [<type>]`, the RUN-LEVEL selection verb.
# doc/claude/specs/results_selection.md section 5 (R301, R301a, R301b), section
# 3.2 (R113 no new C data structure, R114 no new top-level command), and the
# two carried-forward tasks: R110d (new_rawfile()'s copy of the "file found"
# branch) and `xschem raw non_spice` (R305b's missing Tcl verb).
# Groups O..Y, SEL138..SEL195, plus the FIXER ROUND's SEL196..SEL213 (the T-D
# other half, the R301d negative control, and groups Z/AA/AB). Band measured
# free 2026-08-19:
# `grep -hoE '\bSEL[0-9]+\b' tests/headless/*.tcl | sed s/SEL// | sort -n | tail -1`
# -> 137. No item-1 or item-2 id is renumbered, restated or deleted.
#
# `results::select` -- the MRU push, the casemode invalidate, the browser
# refresh, the persistence write and the sentence -- is ITEM 4 and must not
# appear anywhere below.
# ===========================================================================

# a two-plot raw: ONE FILE, ONE RUN, TWO REGISTRY SLOTS (U11). This is the
# fixture R301a exists for: the engine keys the registry on (rawfile, sim_type),
# so a dc and a tran in one file are two slots and one result.
wr $tmp/multi.raw "Title: results select multi
Plotname: DC transfer characteristic
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\tv-sweep\tvoltage
\t1\tv(m1)\tvoltage
Values:
0\t0.000000000000000e+00
\t1.000000000000000e+00

1\t1.000000000000000e+00
\t2.000000000000000e+00

Plotname: Transient Analysis
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\ttime\ttime
\t1\tv(m2)\tvoltage
Values:
0\t0.000000000000000e+00
\t7.000000000000000e+00

1\t1.000000000000000e-08
\t8.000000000000000e+00

"
# a ONE-POINT operating point raw: the only shape the update_op() follow-up
# fires for (allpoints == 1 and sim_type op/dc).
wr $tmp/op.raw "Title: results select op
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(o1)\tvoltage
\t1\tv(o2)\tvoltage
Values:
0\t1.500000000000000e+00
\t2.500000000000000e+00

"
# a MULTI-POINT dc sweep carrying the SAME variable name as op.raw. This is the
# NEGATIVE control for R301d's gate (fixer round): the gate's `allpoints == 1`
# term had no check, so widening it to `>= 1` left all 197 checks green while a
# 3-point sweep started annotating the schematic with its first point.
wr $tmp/dcmulti.raw "Title: results select dc multipoint
Plotname: DC transfer characteristic
Flags: real
No. Variables: 2
No. Points: 3
Variables:
\t0\tv-sweep\tvoltage
\t1\tv(o1)\tvoltage
Values:
0\t0.000000000000000e+00
\t9.000000000000000e+00

1\t1.000000000000000e+00
\t8.000000000000000e+00

2\t2.000000000000000e+00
\t7.000000000000000e+00

"
# how many registry slots name this path. T-A is worded "present EXACTLY ONCE
# in the registry", not "adds exactly one slot", because the first read into a
# context that already has a base raw ALSO adopts that base into slot 0
# (extra_rawfile(), "insert extra_raw_arr[0]") -- see group U, which is that
# case and is the reason the verb has to predict the adopt.
proc slots_naming {path} {
  set n 0
  foreach line [slot_list] {
    if {[lindex [split $line] 1] eq $path} { incr n }
  }
  return $n
}

# ===========================================================================
# O -- THE VERB IS A SUB-VERB OF `raw` (R114) AND THE SELECTION IS extra_idx
#      (R113). No new top-level `xschem` command and no second registry: the
#      cursor `raw switch_back` restores is the SAME cursor a select moves.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL138-O-no-file-is-an-error \
  [string match "ERR:*no file given*" [pcall xschem raw select]] 1
# R114: `xschem select` is an EXISTING top-level command (it selects objects),
# and nothing was added to it. Handed a path and a type it must not read a
# database -- if this ever starts loading one, a second door has been opened.
catch {xschem select $tmp/an.raw tran}
eqcheck SEL139-O-no-new-top-level-command [n_slots] 0

eqcheck SEL140-O-select-reads             [pcall xschem raw select $tmp/an.raw tran] 1
eqcheck SEL141-O-second-file-reads        [pcall xschem raw select $tmp/bn.raw tran] 1
# R113: the selection is extra_idx and extra_prev_idx, the engine's own cursor.
# A select that kept its choice anywhere else would leave switch_back pointing
# at the slot the LAST switch left, not at the one the select left.
eqcheck SEL142-O-select-moved-the-cursor  [pcall xschem raw rawfile] $tmp/bn.raw
eqcheck SEL143-O-select-set-prev-idx      [expr {[pcall xschem raw switch_back] eq "1" \
                                            && [pcall xschem raw rawfile] eq "$tmp/an.raw"}] 1

# ===========================================================================
# P -- T-A: SELECTING A NOT-YET-LOADED FILE. Present exactly once, current,
#      and `results::current` (item 2) returns it -- which is the three-part
#      definition of a selection (R103), not just "a read happened".
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL144-P-rc-is-1-read             [pcall xschem raw select $tmp/an.raw tran] 1
eqcheck SEL145-P-present-exactly-once     [slots_naming $tmp/an.raw] 1
eqcheck SEL146-P-is-current               [pcall xschem raw rawfile] $tmp/an.raw
gecheck SEL147-P-names-resolve            [pcall xschem raw index v(n1)]
set p1 [pcall results::current]
eqcheck SEL148-P-results-current-returns-it \
  [list [dg $p1 path] [dg $p1 cur]] [list $tmp/an.raw 1]

# ===========================================================================
# Q -- SELECTING AN ALREADY-LOADED (path, type) FROM A DIFFERENT CELL.
#      rc 2 -- "selected by switch", nothing parsed -- AND the re-bind, which
#      is what makes select more than switch (R111 keeps `raw switch` blind).
# ===========================================================================
loadcell $tmp/cellB.sch
eqcheck SEL149-Q-blind-before             [list [pcall xschem raw loaded] [pcall xschem raw index v(n1)]] {-1 -1}
set q_slots [slot_list]
eqcheck SEL150-Q-rc-is-2-switch           [pcall xschem raw select $tmp/an.raw tran] 2
eqcheck SEL151-Q-no-slot-added            [slot_list] $q_slots
eqcheck SEL152-Q-restamped                [pcall xschem raw loaded] [pcall xschem get currsch]
gecheck SEL153-Q-resolves-here            [pcall xschem raw index v(n1)]
eqcheck SEL154-Q-selection-is-real-here   [dg [pcall results::current] path] $tmp/an.raw
# the data is the FILE's: a switch parses nothing and must not change a value
eqcheck SEL155-Q-value-unchanged          [pcall xschem raw value v(n1) 2] 3
# R110a's guard is inherited, not re-implemented: a select while DESCENDED
# inside the raw's own hierarchy must not drag the binding down a level.
xschem raw clear
loadcell $hidtop
eqcheck SEL156-Q-top-read                 [pcall xschem raw select $tmp/an.raw tran] 1
xschem select instance 0
xschem descend
eqcheck SEL157-Q-descended                [file tail [pcall xschem get schname]] leaf.sch
eqcheck SEL158-Q-select-while-descended   [pcall xschem raw select $tmp/an.raw tran] 2
eqcheck SEL159-Q-guard-held-level-at-0    [pcall xschem get raw_level] 0
xschem go_back
eqcheck SEL160-Q-top-still-bound          [pcall xschem raw loaded] 0

# ===========================================================================
# R -- R301b: <type> IS OPTIONAL, and this is the L10 trap it walks past.
#      `xschem raw switch <path>` with NO type does not fail: the by-name arm
#      is guarded `if(file && type)` and a typeless call falls through to the
#      by-index form and switches to the NEXT database. `raw select <path>`
#      must land on the named file instead, because it goes through the
#      what == 1 dedupe loop, which matches on the filename alone when the
#      type is NULL.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
# THREE slots, not two, and that is load-bearing: the typeless arm steps to the
# NEXT index, and with two slots "next" and "the file I named" are the same
# place half the time -- a wrong implementation passes by coincidence. Measured:
# with two slots, routing a typeless select through the by-name switch arm left
# the whole suite green.
xschem raw read $tmp/an.raw tran
xschem raw read $tmp/bn.raw tran
xschem raw read $tmp/cn.raw tran
xschem raw switch $tmp/an.raw tran
eqcheck SEL161-R-an-is-current             [pcall xschem raw rawfile] $tmp/an.raw
# THE TRAP ITSELF, measured here so the next check is a contrast and not a
# claim: a typeless `raw switch` at an.raw does not refuse and does not stay --
# it reports success and steps to the NEXT slot, which is the other file.
eqcheck SEL162-R-typeless-switch-steps-the-cursor \
  [list [pcall xschem raw switch $tmp/an.raw] [pcall xschem raw rawfile]] [list 1 $tmp/bn.raw]
set r_slots [slot_list]
eqcheck SEL163-R-typeless-select-lands-on-the-named-file \
  [list [pcall xschem raw select $tmp/an.raw] [pcall xschem raw rawfile]] [list 2 $tmp/an.raw]
eqcheck SEL164-R-typeless-select-added-nothing [slot_list] $r_slots

# ===========================================================================
# S -- R301a: SELECT IS A RUN-LEVEL GESTURE. One file, two analyses, two
#      registry slots, ONE result (U11). Selecting the run re-binds EVERY slot
#      of it, so the sibling analysis is reachable in the cell you selected it
#      in -- the boundary spec section 3.1 states for R110 ("read is an
#      analysis-level verb ... re-binding every slot of the chosen run is that
#      verb's job under U11").
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL165-S-two-slots-one-file \
  [list [pcall xschem raw read $tmp/multi.raw dc] [pcall xschem raw read $tmp/multi.raw tran] \
        [slots_naming $tmp/multi.raw]] {1 1 2}
loadcell $tmp/cellB.sch
# R111, and the precondition: NAVIGATION does not re-bind either slot, so both
# analyses of the run are blind here before the select.
xschem raw switch $tmp/multi.raw dc
eqcheck SEL166-S-dc-blind-before   [list [pcall xschem raw loaded] [pcall xschem raw index v(m1)]] {-1 -1}
xschem raw switch $tmp/multi.raw tran
eqcheck SEL167-S-tran-blind-before [list [pcall xschem raw loaded] [pcall xschem raw index v(m2)]] {-1 -1}
set s_slots [slot_list]
eqcheck SEL168-S-select-tran-rc    [pcall xschem raw select $tmp/multi.raw tran] 2
gecheck SEL169-S-tran-resolves     [pcall xschem raw index v(m2)]
# ---- THE PAYLOAD: the analysis NOT named is re-bound too ----
xschem raw switch $tmp/multi.raw dc
eqcheck SEL170-S-sibling-dc-rebound \
  [list [expr {[pcall xschem raw loaded] >= 0}] [expr {[pcall xschem raw index v(m1)] >= 0}]] {1 1}
eqcheck SEL171-S-run-rebind-added-nothing [slot_list] $s_slots
# and it did not reach an UNRELATED database: an.raw is a DIFFERENT run, read
# under cell A like the rest, and selecting this run must leave it where it is.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/multi.raw dc
xschem raw read $tmp/multi.raw tran
xschem raw read $tmp/an.raw tran
loadcell $tmp/cellB.sch
pcall xschem raw select $tmp/multi.raw tran
xschem raw switch $tmp/an.raw tran
eqcheck SEL172-S-other-run-untouched [pcall xschem raw loaded] -1

# ===========================================================================
# T -- T-D: A REFUSED SELECTION CHANGES NOTHING. F7 -- selection never clears,
#      and a failed one may not take the previous one down with it.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
pcall xschem raw select $tmp/an.raw tran
set t_slots [slot_list]
set t_file  [pcall xschem raw rawfile]
set t_cur   [pcall results::current]
eqcheck SEL173-T-garbage-rc-is-0   [pcall xschem raw select $tmp/nope.raw tran] 0
eqcheck SEL174-T-registry-intact   [slot_list] $t_slots
eqcheck SEL175-T-current-intact    [pcall xschem raw rawfile] $t_file
gecheck SEL176-T-still-resolves    [pcall xschem raw index v(n1)]
eqcheck SEL177-T-selection-intact  [pcall results::current] $t_cur
# ---- THE OTHER HALF OF THE SELECTION (R113), added by the FIXER ROUND ----
# SEL143 rules that the selection is extra_idx AND extra_prev_idx, so "the
# previous selection is intact" has to be measured on both. It was not:
# extra_rawfile()'s failure arm restores xctx->raw and then does
# `xctx->extra_prev_idx = xctx->extra_idx;`, which silently destroyed the
# switch-back cursor -- a refused select turned `xschem raw switch_back` into a
# no-op, so after a mistyped path in Results > Select the user's "go back to the
# previous result" gesture did nothing. Measured on the item binary before the
# fix (select an, select bn, refuse nope, switch_back -> bn instead of an) and
# undone in raw_select(), not in extra_rawfile()'s shared failure path (`raw
# read` has the same wart; that is R112's item).
xschem raw clear
loadcell $tmp/cellA.sch
pcall xschem raw select $tmp/an.raw tran
pcall xschem raw select $tmp/bn.raw tran
# CONTROL: with no refusal in between, switch_back lands on the previous one
eqcheck SEL196-T-switch-back-control \
  [list [pcall xschem raw switch_back] [pcall xschem raw rawfile]] [list 1 $tmp/an.raw]
pcall xschem raw select $tmp/bn.raw tran
eqcheck SEL197-T-refused-rc-is-0  [pcall xschem raw select $tmp/nope.raw tran] 0
eqcheck SEL198-T-refused-kept-the-switch-back-cursor \
  [list [pcall xschem raw switch_back] [pcall xschem raw rawfile]] [list 1 $tmp/an.raw]

# ===========================================================================
# U -- THE ADOPT CORRECTION, i.e. WHY T-A IS NOT WORDED "adds one slot".
#      `xschem raw_read` (the ~293 launcher sites' verb, L2 -- it CLEARS the
#      registry and reads) leaves xctx->raw set with an EMPTY registry. The
#      next extra_rawfile() call of any kind adopts that base into slot 0, so
#      the slot count moves by one for a reason that has nothing to do with the
#      requested file. A `select` that read the count naively reports "read"
#      for a file it only switched to. NOTHING may touch `xschem raw ...`
#      between the raw_read and the select: `raw info` itself adopts.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL178-U-raw_read-rc       [pcall xschem raw_read $tmp/an.raw tran] 1
eqcheck SEL179-U-select-says-switch-not-read [pcall xschem raw select $tmp/an.raw tran] 2
eqcheck SEL180-U-present-exactly-once        [slots_naming $tmp/an.raw] 1

# ===========================================================================
# V -- `xschem raw non_spice <type>`: R305b's missing Tcl verb, and the token
#      it removes from src/results.tcl. It is the OTHER column of the reader
#      table from `raw is_digital`, which answers 0 for `table` on purpose
#      (test_backannotate_digital BA12).
# ===========================================================================
eqcheck SEL181-V-non_spice-by-type \
  [list [pcall xschem raw non_spice tran] [pcall xschem raw non_spice table] \
        [pcall xschem raw non_spice vcd]] {0 1 1}
eqcheck SEL182-V-is-not-is_digital \
  [list [pcall xschem raw non_spice table] [pcall xschem raw is_digital table]] {1 0}
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/t.table table
eqcheck SEL183-V-non_spice-of-current-db [pcall xschem raw non_spice] 1
xschem raw read $tmp/an.raw tran
eqcheck SEL184-V-non_spice-of-spice-db   [pcall xschem raw non_spice] 0
# the delegation is REAL: no reader token survives in results.tcl's CODE.
# Comment lines are stripped -- the file explains the ruling in prose and must
# not trip its own detector.
# FIXER ROUND: matched as a WORD, not as a substring. The bare `regexp {table}`
# this started as reds on any future code line merely CONTAINING the letters --
# a proc named `_fmt_table`, a variable `$mutable_state` -- and item 4 is
# scheduled to add results::select to this very file. Driven: appending
# `proc results::_stable_sort {l} {lsort $l}` to src/results.tcl failed the old
# form and passes this one, while the S20 sabotage (the token put back beside
# the delegation) still reds. `:` is excluded on both sides too, so a
# hypothetical `results::table` identifier is not a reader token either.
# -line makes ^ and $ line anchors: the argument is the whole file.
eqcheck SEL185-V-no-reader-token-left-in-tcl \
  [regexp -line {(^|[^A-Za-z0-9_:])table([^A-Za-z0-9_:]|$)} [r2_code [r2_rd $r2_tcl]]] 0

# ===========================================================================
# W -- R110d: THE THIRD COPY OF THE "file found: switch to it" BRANCH, in
#      new_rawfile(). Carried forward from item 1, which closed 0509 naming it
#      with no reproducer built either way. This is the reproducer: `xschem raw
#      new` builds an in-memory dataset, finds the name already taken, makes it
#      current and -- before this item -- left it bound to the cell it was first
#      built under, so the `xschem raw add` / `xschem raw set` calls that always
#      follow wrote into a database no lookup in this design could see.
#      WHO REACHES IT -- corrected by the fixer round. An earlier version of this
#      header blamed the SHIPPED launcher, whose dataset name is the constant
#      `distrib` (xschem_library/ngspice/autozero_comp.sch:542). It does not
#      reach the branch: that launcher's first line is `xschem raw_read`, which
#      CLEARS THE WHOLE REGISTRY, so its `xschem raw new distrib` always creates
#      (rc 1) and never finds -- measured on the item binary. The reachable
#      sequence is a Tcl author calling `xschem raw new <same name>` a second
#      time with no intervening clear, which is what this group drives.
#      The return value is UNCHANGED: 0 still means "already loaded".
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL186-W-raw-new-created   [pcall xschem raw new hist.raw distrib vsweep 0 1.0 0.1] 1
gecheck SEL187-W-resolves-under-A  [pcall xschem raw index vsweep]
loadcell $tmp/cellB.sch
eqcheck SEL188-W-blind-before      [list [pcall xschem raw loaded] [pcall xschem raw index vsweep]] {-1 -1}
set w_slots [slot_list]
eqcheck SEL189-W-second-new-rc-still-0 [pcall xschem raw new hist.raw distrib vsweep 0 1.0 0.1] 0
# ---- THE PAYLOAD ----
eqcheck SEL190-W-restamped         [pcall xschem raw loaded] [pcall xschem get currsch]
gecheck SEL191-W-resolves-here     [pcall xschem raw index vsweep]
eqcheck SEL192-W-no-slot-added     [slot_list] $w_slots

# ===========================================================================
# X -- THE OPERATING-POINT FOLLOW-UP (R301d). Making a one-point OP the result
#      you are working against is exactly when its numbers belong on the
#      schematic, so the `select` arm repeats the `switch` arm's update_op()
#      call. TWO contrasts make SEL194 non-vacuous, and both are measurements
#      of shipped behaviour taken right here rather than claims:
#        SEL193 -- `raw read` of the same file publishes NOTHING.
#        SEL195 -- `raw switch` into it, from a multi-point database, publishes
#                  nothing either: the shipped gate tests `allpoints` on the
#                  database it is LEAVING and `sim_type` on the one it is
#                  ARRIVING at (issue 0513). That is why the select arm gates on
#                  xctx->raw AFTER the call, and why a select-gate copied
#                  verbatim from the switch arm would fail SEL194 here.
#      ⚠ WHEN 0513 IS FIXED, SEL195 INVERTS -- it will publish. Update it there;
#      it is written as a measurement of today's engine, not as a rule.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL193-X-read-does-not-publish \
  [list [pcall xschem raw read $tmp/op.raw op] [pcall ngspice::get_voltage o1]] {1 ?}
# a MULTI-POINT database becomes current, so the two halves of the shipped
# switch gate now disagree
xschem raw read $tmp/an.raw tran
set x_src [pcall xschem raw switch $tmp/op.raw op]
set x_sv  [pcall ngspice::get_voltage o1]
eqcheck SEL195-X-switch-does-not-publish-here-0513 [list $x_src $x_sv] {1 ?}
# back onto the multi-point database, so the SELECT below also runs with a
# 3-point raw current. Without this line the select is made FROM the op itself
# and a gate copied verbatim from the switch arm would pass by coincidence --
# measured: it does.
xschem raw switch $tmp/an.raw tran
set x_rc [pcall xschem raw select $tmp/op.raw op]
set x_v  [pcall ngspice::get_voltage o1]
# `?` is what get_voltage answers when nothing is published, so the value is
# tested for NUMBER-ness before arithmetic -- a bare expr on `?` aborts the
# whole script, which is how a red check becomes a missing check.
eqcheck SEL194-X-select-publishes \
  [list $x_rc [expr {[string is double -strict $x_v] && abs($x_v - 1.5) < 1e-9}]] {2 1}
# ---- THE NEGATIVE CONTROL for the gate's `allpoints == 1` term (FIXER ROUND).
# SEL194 proves the gate FIRES; nothing proved it does not OVER-fire, and that
# is a hole a later fixer falls into: `sed -i 's/allpoints == 1/allpoints >= 1/'`
# in the select arm left all 197 checks green while a 3-point dc sweep started
# annotating the schematic with its FIRST point (measured: get_voltage o1 went
# from `?` to `9`). A multi-point sweep is not an operating point.
# The array is unset first because SEL194 published into it: `?` is the answer
# only while nothing has been published, so without this the check would be
# measuring SEL194's leftovers.
catch {array unset ngspice::ngspice_data}
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL199-X-nothing-published-baseline [pcall ngspice::get_voltage o1] ?
eqcheck SEL200-X-multipoint-dc-does-not-publish \
  [list [pcall xschem raw select $tmp/dcmulti.raw dc] [pcall ngspice::get_voltage o1]] {1 ?}

# ===========================================================================
# Z -- FIXER ROUND. A TYPELESS SELECT PREFERS THE ANALYSIS YOU ARE ON.
#      R301b makes <type> optional precisely so item 4 can pass a bare path (the
#      MRU and the persistence slot store a path only). The what == 1 spice
#      dedupe matches on the FILENAME ALONE when the type is NULL, so with one
#      run read twice -- a dc plot and a tran plot of one file are two slots and
#      ONE result (U11) -- a bare select landed on the run's FIRST slot and moved
#      the user off the analysis they were plotting: measured before the fix,
#      sim_type went tran -> dc and `raw index v(m2)` went 1 -> -1.
#      THE OVER-FIRE GUARD IS SEL163, not a new check: when the current database
#      is a DIFFERENT file, a typeless select must still land on the file it
#      names. This arm only fires when the current database already IS that file.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/multi.raw dc
xschem raw read $tmp/multi.raw tran
eqcheck SEL201-Z-tran-is-the-current-analysis \
  [list [pcall xschem raw_query sim_type] [expr {[pcall xschem raw index v(m2)] >= 0}]] {tran 1}
set z_slots [slot_list]
eqcheck SEL202-Z-typeless-select-rc         [pcall xschem raw select $tmp/multi.raw] 2
eqcheck SEL203-Z-stayed-on-the-analysis \
  [list [pcall xschem raw_query sim_type] [expr {[pcall xschem raw index v(m2)] >= 0}]] {tran 1}
eqcheck SEL204-Z-added-nothing               [slot_list] $z_slots
# and the same from an unrelated cell -- the shape item 4's gesture actually has
loadcell $tmp/cellB.sch
pcall xschem raw select $tmp/multi.raw
eqcheck SEL205-Z-from-another-cell-same-analysis \
  [list [dg [pcall results::current] type] [expr {[pcall xschem raw index v(m2)] >= 0}]] {tran 1}

# ===========================================================================
# AA -- FIXER ROUND. AN EXPLICIT NON-SPICE TYPE STILL NAMES ONE ANALYSIS.
#       The non-spice what == 1 arm dedupes on the FILENAME ALONE (it must: a
#       table or a VCD has no sim_type until its reader stamps one), so
#       `raw select <an ngspice raw> table` FOUND the tran slot and answered
#       2 = "selected by switch" -- a successful selection of an analysis that
#       is not in the registry, which item 4 would push onto the MRU and write
#       to disk as a (path, type) pair naming no slot. The opposite direction
#       needs no guard: a spice type goes through the spice loop, which compares
#       sim_type and refuses by itself.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
# a SECOND run is read after it, so bn.raw -- not the file the refused select
# names -- is the current one. That is what makes SEL208 a measurement of the
# undo rather than a coincidence: the refused select's own extra_rawfile() call
# DOES find and switch to the an.raw slot before the type mismatch is noticed,
# so without the restore the cursor is left on the wrong run.
xschem raw read $tmp/bn.raw tran
set aa_slots [slot_list]
eqcheck SEL206-AA-non-spice-type-on-a-spice-run-refuses \
  [pcall xschem raw select $tmp/an.raw table] 0
eqcheck SEL207-AA-registry-intact [slot_list] $aa_slots
eqcheck SEL208-AA-current-intact \
  [list [pcall xschem raw rawfile] [pcall xschem raw_query sim_type]] [list $tmp/bn.raw tran]
# the verb is not broken for the types that ARE non-spice: a real table still
# selects, and the WRONG non-spice token on it is refused for the same reason
eqcheck SEL209-AA-a-real-table-still-selects [pcall xschem raw select $tmp/t.table table] 1
eqcheck SEL210-AA-wrong-non-spice-token-refuses [pcall xschem raw select $tmp/t.table vcd] 0

# ===========================================================================
# AB -- FIXER ROUND. A LEADING `~/` IS EXPANDED. `xschem raw_read` expands it
#       (its arm's own `regsub {^~/}`), and `select` is the verb meant to
#       front-end those ~293 launcher sites -- so `~/x.raw` must not be the one
#       spelling that works for one verb and fails for the other.
#       extra_rawfile() only runs Tcl `subst`, which does not expand `~`.
#       SEL211 is the control: if THIS reds too, the C `home_dir` (getpwuid) and
#       $env(HOME) disagree in this environment and neither verb expanded it.
#       The file is written under $HOME because that is the only place `~` can
#       name; it is removed again below.
# ===========================================================================
set ab_dir  [file join $env(HOME) .xschem_results_select_[pid]]
set ab_file [file join $ab_dir an.raw]
file mkdir $ab_dir
file copy -force $tmp/an.raw $ab_file
set ab_tilde ~/[file tail $ab_dir]/an.raw
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL211-AB-raw_read-expands-tilde-control [pcall xschem raw_read $ab_tilde tran] 1
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL212-AB-select-expands-tilde           [pcall xschem raw select $ab_tilde tran] 1
# not just "it worked": the spelling STORED is the expanded one, which is what
# makes a slot read by `raw_read` and one selected here the SAME slot (the
# registry dedupes by strcmp, so `~/x.raw` beside `$HOME/x.raw` would be two runs)
eqcheck SEL213-AB-stored-spelling-is-expanded    [pcall xschem raw rawfile] $ab_file
xschem raw clear
file delete -force $ab_dir

# ===========================================================================
# ITEM 4 -- `results::select` (src/results.tcl), THE ONE PLACE THAT SELECTS.
# doc/claude/specs/results_selection.md section 5 (R302, R303), section 10
# (R801-R805) and section 12's T-D / T-G / T-J / T-M.
# Groups AC..AL, SEL214..SEL281. Band measured free 2026-08-19:
# `grep -hoE '\bSEL[0-9]+\b' tests/headless/*.tcl | sed s/SEL// | sort -n | tail -1`
# -> 213. No item-1, item-2 or item-3 id is renumbered, restated or deleted.
#
# WHAT THIS ITEM IS NOT. It does not re-express wviewer::rawbar_load (item 5),
# does not touch wviewer::snapshot or viewer_restore (item 6), builds no dialog
# (item 7), touches no menu (item 8) and no calculator.tcl (item 10). The
# persistence WRITE is a documented seam -- `results::persist` -- and group AJ
# pins the call, not a write, because there is nothing to write yet.
# ===========================================================================

# a scratch viewer token. `wviewer::windows` has no entry for it, which is the
# point: casemode_invalidate/reapply are per-token ARRAY operations that need no
# window, while browser_refresh and browser_status need one and answer 0. That
# split is exactly what group AJ measures.
set r4_tok r4tok

# shim bookkeeping: every rename below is undone, and SEL280 asserts it -- by
# BODY, not by name. Measured: a check written as `info procs <name> ne {}` is
# satisfied by the SHIM still being installed, so dropping a restore line left
# it green (item 2's SEL111 carries the same limitation, declared).
set r4_calls {}
# FIXER ROUND: `::puts` joined the list. SEL294 shims the global `puts` for the
# duration of two selects, and that is the one shim in this item whose escape
# would corrupt every later check silently rather than loudly. It is a BUILTIN,
# so `info body ::puts` THROWS -> {MISSING} both before and after; if the
# restore is dropped the shim is a real proc and the body compares unequal.
set r4_shimmed {::ase::echo ::calc::status ::wviewer::browser_status \
                ::wviewer::rawhist_write ::wviewer::browser_refresh \
                ::results::persist ::results::_resolves_here ::puts}
set r4_bodies {}
# guarded: the PRE-FEATURE drive (results.tcl at its item-3 state) has no
# ::results::persist and no ::results::_resolves_here, and an unguarded
# `info body` there aborts the file before a single item-4 check can go red --
# which would make the drive report "no reds" for the best possible reason.
foreach r4p $r4_shimmed {
  if {[catch {info body $r4p} r4b]} { set r4b {MISSING} }
  lappend r4_bodies $r4p $r4b
}

proc r4_dictkeys {d} { if {[catch {dict keys $d} k]} { return "ERR" } ; return [lsort $k] }

# ===========================================================================
# AC -- IT SHIPS. `results::select` and its four helpers are defined in the
#      RUNNING binary (the only one of the three J-group forms a comment cannot
#      satisfy), and the file is still the one that is sourced and installed.
# ===========================================================================
eqcheck SEL214-AC-select-defined-in-the-running-binary \
  [expr {[info procs ::results::select] ne {} ? 1 : 0}] 1
eqcheck SEL215-AC-helpers-defined \
  [lsort [list [expr {[info procs ::results::_engine_spelling] ne {}}] \
               [expr {[info procs ::results::_resolves_here] ne {}}] \
               [expr {[info procs ::results::_select_msg] ne {}}] \
               [expr {[info procs ::results::_r804_msg] ne {}}] \
               [expr {[info procs ::results::_emit] ne {}}] \
               [expr {[info procs ::results::persist] ne {}}]]] {1 1 1 1 1 1}
# the arity the spec fixes: path, plus TWO optional arguments.
eqcheck SEL216-AC-signature [pcall info args ::results::select] {path sim_type opts}
eqcheck SEL217-AC-both-optional \
  [list [pcall info default ::results::select sim_type r4_d] \
        [pcall info default ::results::select opts r4_d]] {1 1}

# ===========================================================================
# AD -- THE GESTURE. A fresh select reads; a second select of the same result
#      switches; the returned dict says which, and `ok` is not `how`.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
set s1 [pcall results::select $tmp/an.raw tran]
eqcheck SEL218-AD-fresh-select-reads \
  [list [dg $s1 ok] [dg $s1 how] [dg $s1 status]] {1 read ok}
# T-A's wording, through the orchestrator: present EXACTLY ONCE and current.
eqcheck SEL219-AD-present-once-and-current \
  [list [slots_naming $tmp/an.raw] [pcall xschem raw rawfile]] [list 1 $tmp/an.raw]
# the dict names the ENGINE's spelling and the ENGINE's analysis, not the
# caller's -- R803's db_label is built from those two and nothing else.
eqcheck SEL220-AD-dict-reports-the-engine \
  [list [dg $s1 path] [dg $s1 type]] [list $tmp/an.raw tran]
eqcheck SEL221-AD-one-sentence-names-by-db_label [dg $s1 msg] {Selected an.raw (tran).}
# R803: the FULL PATH is never in the sentence -- it lives in the `path` field
# and, for the dialog, in the balloon.
# ...and the full path IS still handed back, in the `path` field -- both halves
# in ONE assertion, so this cannot be satisfied by a select that never ran.
eqcheck SEL222-AD-sentence-carries-no-full-path \
  [list [string first $tmp [dg $s1 msg]] [dg $s1 path]] [list -1 $tmp/an.raw]
eqcheck SEL223-AD-dict-keys [r4_dictkeys $s1] \
  {channel did how msg named ok path reason resolves status type why}

set s2 [pcall results::select $tmp/an.raw tran]
eqcheck SEL224-AD-second-select-switches \
  [list [dg $s2 ok] [dg $s2 how] [slots_naming $tmp/an.raw]] {1 switch 1}
# R301b: a TYPELESS select is the shape the MRU and the persistence slot can
# actually produce -- both store a path and no analysis.
xschem raw read $tmp/bn.raw tran
set s3 [pcall results::select $tmp/an.raw]
eqcheck SEL225-AD-typeless-select-switches \
  [list [dg $s3 ok] [dg $s3 how] [dg $s3 path] [dg $s3 type]] \
  [list 1 switch $tmp/an.raw tran]

# ===========================================================================
# AE -- T-D: A FAILED SELECTION LEAVES THE PREVIOUS SELECTION INTACT.
#      Registry, `raw rawfile` and `raw list` all unchanged, rc 0 with a
#      sentence, nothing thrown (R801). THREE refusal shapes are driven, because
#      they take three different routes out of results::select and only one of
#      them ever reaches the engine.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
xschem raw read $tmp/bn.raw tran
set ae_slots [slot_list]
set ae_file  [pcall xschem raw rawfile]
set ae_list  [pcall xschem raw list]

# (1) the file is not there: the RESOLVER refuses and the engine is never asked.
set f1 [pcall results::select $tmp/nosuch.raw tran]
eqcheck SEL226-AE-missing-file-refuses [list [dg $f1 ok] [dg $f1 how]] {0 refused}
eqcheck SEL227-AE-missing-file-says-so \
  [list [dg $f1 status] [dg $f1 reason] [expr {[dg $f1 msg] ne {} ? 1 : 0}]] {invalid missing 1}
eqcheck SEL228-AE-no-side-effect-on-refusal [dg $f1 did] {}
eqcheck SEL229-AE-registry-intact \
  [list [dg $f1 how] [slot_list] [pcall xschem raw rawfile] [pcall xschem raw list]] \
  [list refused $ae_slots $ae_file $ae_list]

# (2) the file is there and the ANALYSIS is not: the ENGINE refuses (rc 0), and
#     item 3's raw_select_undo() is what puts the cursor back.
set f2 [pcall results::select $tmp/an.raw ac]
eqcheck SEL230-AE-wrong-analysis-refuses [list [dg $f2 ok] [dg $f2 how]] {0 refused}
# ...and it is NOT reported as "no results" (F6/T-J): the sentence names the
# database it could not select, and the resolver's verdict on the PATH was `ok`.
eqcheck SEL231-AE-engine-refusal-names-the-db \
  [list [dg $f2 status] [dg $f2 msg]] \
  [list ok "Could not select an.raw (ac) — nothing was loaded and the previous result is unchanged."]
eqcheck SEL232-AE-engine-refusal-registry-intact \
  [list [dg $f2 how] [slot_list] [pcall xschem raw rawfile] [pcall xschem raw list]] \
  [list refused $ae_slots $ae_file $ae_list]
eqcheck SEL233-AE-engine-refusal-no-side-effect [dg $f2 did] {}

# (3) nothing named and nothing derived: the resolver's own `default` sentence,
#     not a second one written here (R805 -- one form per status).
set f3 [pcall results::select {}]
eqcheck SEL234-AE-nothing-named-refuses \
  [list [dg $f3 ok] [dg $f3 how] [dg $f3 status] [dg $f3 msg]] \
  {0 refused default {No result is named and none has been produced yet.}}
eqcheck SEL235-AE-nothing-named-registry-intact \
  [list [dg $f3 how] [slot_list] [pcall xschem raw rawfile]] \
  [list refused $ae_slots $ae_file]
# the three refusals do not share one sentence: a caller can tell them apart.
eqcheck SEL236-AE-three-distinct-refusal-sentences \
  [llength [lsort -unique [list [dg $f1 msg] [dg $f2 msg] [dg $f3 msg]]]] 3

# ===========================================================================
# AF -- R302a: TWO SPELLINGS OF ONE PATH ARE TWO RUNS, AND THIS IS WHERE THAT
#      STOPS. Carried forward from item 3, which MEASURED it: the engine dedupes
#      by strcmp, so `w/an.raw` and `w/../w/an.raw` both read and produce two
#      slots. `file normalize` is the Tcl-side call and it is item 4's.
# ===========================================================================
set af_odd [file join $tmp .. [file tail $tmp] an.raw]

# THE CONTROL, re-driven here rather than quoted: the raw verb still makes two
# slots out of the two spellings. If this ever stops being true, the check below
# is measuring nothing.
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL237-AF-control-verb-reads-plain [pcall xschem raw select $tmp/an.raw tran] 1
eqcheck SEL238-AF-control-verb-reads-odd-spelling-AGAIN \
  [list [pcall xschem raw select $af_odd tran] [n_slots]] {1 2}

# (a) the path handed to the engine is normalised, so one door means one
#     spelling: selecting the odd spelling into an EMPTY registry stores the
#     normalised one.
xschem raw clear
loadcell $tmp/cellA.sch
set a1 [pcall results::select $af_odd tran]
eqcheck SEL239-AF-normalised-on-the-way-in \
  [list [dg $a1 ok] [dg $a1 path] [n_slots]] [list 1 [file normalize $af_odd] 1]

# (b) and the registry is ASKED first, so an existing slot is found however IT
#     was spelled -- which is what stops a second copy being read beside it.
#     Registry holds the PLAIN spelling; the odd one must switch, not read.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
set a2 [pcall results::select $af_odd tran]
eqcheck SEL240-AF-odd-spelling-finds-the-plain-slot \
  [list [dg $a2 ok] [dg $a2 how] [n_slots] [dg $a2 path]] [list 1 switch 1 $tmp/an.raw]

# ...and the other direction: registry holds the ODD spelling, the plain one is
# asked for. Without half (b) the odd slot would be permanently unreachable
# through this door and a normalised twin would be read beside it every time.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $af_odd tran
set a3 [pcall results::select $tmp/an.raw tran]
eqcheck SEL241-AF-plain-spelling-finds-the-odd-slot \
  [list [dg $a3 ok] [dg $a3 how] [n_slots] [dg $a3 path]] [list 1 switch 1 $af_odd]
# the helper answers the question on its own, with no registry at all
xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL242-AF-engine_spelling-normalises-with-an-empty-registry \
  [pcall results::_engine_spelling $af_odd] [file normalize $af_odd]

# ---- R302h: WHERE "ONE SPELLING" STOPS, MEASURED IN BOTH DIRECTIONS.
#      `file normalize` resolves a symlink in a DIRECTORY component and does NOT
#      resolve one in the FINAL component. The first half is convergence the
#      ruling claims; the second is the boundary the ruling DRAWS (a
#      final-component link is a name the user chose and is usually a moving
#      target -- resolving it would rewrite the sentence, the MRU and item 6's
#      persistence slot into a run-specific path). Both are asserted, so neither
#      the claim nor the boundary can drift without a red.
set af_ldir  [file join $tmp linkdir]
set af_lfile [file join $tmp linkfile.raw]
catch {file delete -force $af_ldir}
catch {file delete -force $af_lfile}
set af_link_ok 1
if {[catch {file link -symbolic $af_ldir  $tmp}] } { set af_link_ok 0 }
if {[catch {file link -symbolic $af_lfile $tmp/an.raw}]} { set af_link_ok 0 }
# INTERMEDIATE link: the registry's plain slot is found through it -> switch,
# one slot, and the engine's own plain spelling comes back.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
if {$af_link_ok} {
  set a4 [pcall results::select [file join $af_ldir an.raw] tran]
  eqcheck SEL289-AF-intermediate-symlink-converges-on-the-existing-slot \
    [list $af_link_ok [dg $a4 ok] [dg $a4 how] [n_slots] [dg $a4 path]] \
    [list 1 1 switch 1 $tmp/an.raw]
} else {
  # NOT a tautology: the degenerate arm asserts the REASON it degenerated, so a
  # future bug that leaves af_link_ok 0 for some other cause cannot hide here.
  eqcheck SEL289-AF-intermediate-symlink-converges-on-the-existing-slot \
    [list $af_link_ok NO-SYMLINK-SUPPORT] {0 NO-SYMLINK-SUPPORT}
}
# FINAL-COMPONENT link: DELIBERATELY a different slot. This is the measurement
# the R302h ruling is read off -- it is not an aspiration that one day it will
# converge, it is the recorded boundary.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
if {$af_link_ok} {
  set a5 [pcall results::select $af_lfile tran]
  eqcheck SEL290-AF-final-component-symlink-is-a-SECOND-slot-by-ruling \
    [list $af_link_ok [pcall results::_engine_spelling $af_lfile] \
          [dg $a5 how] [n_slots] [dg $a5 path]] \
    [list 1 $af_lfile read 2 $af_lfile]
} else {
  eqcheck SEL290-AF-final-component-symlink-is-a-SECOND-slot-by-ruling \
    [list $af_link_ok NO-SYMLINK-SUPPORT] {0 NO-SYMLINK-SUPPORT}
}
# ⚠ TYPE-GUARDED, and `-force` is NOT used. $af_ldir is a symlink TO $tmp; a
#   recursive delete that followed it would take the whole scratch fixture with
#   it and every group below would fail for a reason none of them names.
#   `file delete` on a symlink removes the LINK, so the guard plus the missing
#   -force is belt and braces.
foreach af_l [list $af_ldir $af_lfile] {
  if {[catch {file type $af_l} af_t]} continue
  if {$af_t eq {link}} { catch {file delete $af_l} }
}

# ===========================================================================
# AG -- T-G: PER-TRACE ADDRESSING IS NOT SELECTION. A graph entry written
#      `alias;vec%<rawfileA> <type>` names its OWN database; selecting B moves
#      the session's result and must leave that trace resolving against A.
#      The shape is wviewer::graph_props's own (test_wave_cursor_crossdb XC0).
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
set ag_q "\\\"aslot;v(n1)%$tmp/an.raw tran\\\""
xschem set rectcolor 2
xschem rect 0 0 800 400 -1 {flags=graph} 0
xschem setprop rect 2 0 node "v(n2)\n$ag_q"
xschem setprop rect 2 0 x1 0
xschem setprop rect 2 0 x2 2e-8
xschem setprop rect 2 0 y1 -1
xschem setprop rect 2 0 y2 8
xschem setprop rect 2 0 fullyzoom
xschem cursor 2 1
set ag_node_before [pcall xschem getprop rect 2 0 node]

# select B. an.raw and bn.raw carry DIFFERENT signal names on purpose, so
# "resolves against A" is a statement no lookup in B could satisfy.
set g1 [pcall results::select $tmp/bn.raw tran]
eqcheck SEL243-AG-selection-moved-to-B \
  [list [dg $g1 ok] [pcall xschem raw rawfile]] [list 1 $tmp/bn.raw]
eqcheck SEL244-AG-the-selected-db-does-not-know-A-s-signal \
  [pcall xschem raw index {v(n1)}] -1
# the drawn object is untouched: results::select writes no schematic
eqcheck SEL245-AG-graph-entry-unchanged \
  [list [dg $g1 ok] [pcall xschem getprop rect 2 0 node]] [list 1 $ag_node_before]
# ---- THE PAYLOAD: drive cursor B and the %-addressed database resolves it,
#      with ITS OWN numbers, while B is the selection. an.raw at 5 ns
#      interpolates between 1.0 (0 ns) and 2.0 (10 ns) -> 1.5.
xschem set cursor2_x 5e-9
xschem raw switch $tmp/an.raw tran
set ag_v [pcall xschem raw value {v(n1)} {}]
# THE SELECTION HAVING MOVED IS ASSERTED IN THE SAME CHECK. Without that term
# this reads true when nothing was selected at all, which is the one shape a
# T-G check must not have.
eqcheck SEL246-AG-percent-trace-still-resolves-against-A \
  [list [dg $g1 how] [expr {[lindex [pcall xschem raw annot] 0] >= 0 ? 1 : 0}] \
        [expr {[string is double -strict $ag_v] && abs($ag_v - 1.5) < 1e-5 ? 1 : 0}]] {read 1 1}
xschem raw switch $tmp/bn.raw tran
xschem cursor 2 0
loadcell $tmp/cellA.sch

# ===========================================================================
# AH -- T-M: A SELECTION WHOSE STAMP DOES NOT MATCH THE STACK IS NOT REPORTED
#      AS SUCCESS (R804), AND NEITHER IS ONE THAT LANDS ON A DATABASE THAT IS
#      NOT A RESULT (R102).
#
#      `ok` IS results::current's ANSWER, NOT A SECOND OPINION. That is the
#      invariant the group drives from both ends, and it is what makes the named
#      sabotage -- "make results::select return ok unconditionally" -- red.
#
#      R804b: the F4 state is MEASURED UNREACHABLE through `xschem raw select`
#      (it sets RAW_READ_REBIND, so a dedupe hit re-stamps and a fresh read is
#      stamped by the reader). The guard is driven through the
#      `results::_resolves_here` seam, shimmed as landmine L1 prescribes for
#      select_raw and as item 2 did for ase::last_rawfile -- with SEL247/SEL248
#      pinning the seam to the engine so the shim is not the only evidence.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
eqcheck SEL247-AH-seam-is-the-engine-when-it-resolves \
  [list [pcall results::_resolves_here] [pcall xschem raw loaded]] \
  [list [pcall xschem raw loaded] [pcall xschem raw loaded]]
loadcell $tmp/cellB.sch
eqcheck SEL248-AH-seam-is-the-engine-when-it-does-not \
  [list [pcall results::_resolves_here] [pcall xschem raw loaded]] {-1 -1}

# the measurement behind R804b, re-driven: a select from the WRONG cell lands
# and re-binds, so the honest answer here is success.
set h1 [pcall results::select $tmp/an.raw tran]
eqcheck SEL249-AH-select-from-another-cell-rebinds-and-succeeds \
  [list [dg $h1 ok] [dg $h1 how] [expr {[dg $h1 resolves] >= 0 ? 1 : 0}] [dg $h1 msg]] \
  [list 1 switch 1 {Selected an.raw (tran).}]

# ---- THE GUARD, driven through the seam ----
rename results::_resolves_here r4_rh_orig
proc results::_resolves_here {} { return -1 }
set h2 [pcall results::select $tmp/an.raw tran]
eqcheck SEL250-AH-blind-selection-is-NOT-success \
  [list [dg $h2 ok] [dg $h2 how] [dg $h2 resolves]] {0 switch -1}
eqcheck SEL251-AH-R804-sentence-without-a-read_against \
  [dg $h2 msg] {Selected an.raw (tran), but this result was not read against cellB.sch — no signal names will resolve until you return to the schematic it was read from.}
# R804's own words, in full, when the caller can say what it was read against
# (R804c: raw->schname has no Tcl verb, so the clause needs the caller).
set h3 [pcall results::select $tmp/an.raw tran [dict create read_against $tmp/cellA.sch]]
eqcheck SEL252-AH-R804-sentence-in-full \
  [dg $h3 msg] {Selected an.raw (tran), but this result was read against cellA.sch and you are in cellB.sch — no signal names will resolve until you return.}
# the load-bearing half is in BOTH forms, verbatim
eqcheck SEL253-AH-both-forms-say-no-names-will-resolve \
  [list [string match {*no signal names will resolve*} [dg $h2 msg]] \
        [string match {*no signal names will resolve*} [dg $h3 msg]]] {1 1}
# ...and the side effects STILL ran (R302d): the engine moved, so the browser
# and the case-mode cache are stale whether or not the stamp resolves.
eqcheck SEL254-AH-blind-selection-still-landed \
  [list [pcall xschem raw rawfile] [dg $h3 how]] [list $tmp/an.raw switch]
rename results::_resolves_here {}
rename r4_rh_orig results::_resolves_here
eqcheck SEL255-AH-seam-restored \
  [list [expr {[info procs ::results::_resolves_here] ne {} ? 1 : 0}] \
        [pcall results::_resolves_here]] [list 1 [pcall xschem raw loaded]]

# ---- R102, AND THIS ONE NEEDS NO SHIM AT ALL. A VCD lands, is current, and is
#      NOT a result -- which is the state every mixed-signal run leaves behind
#      (ase::attach_dbs reads the analog raw and THEN the VCDs, L8).
xschem raw clear
loadcell $tmp/cellA.sch
set h4 [pcall results::select $tmp/d.vcd vcd]
eqcheck SEL256-AH-vcd-lands \
  [list [dg $h4 how] [pcall xschem raw rawfile]] [list read $tmp/d.vcd]
eqcheck SEL257-AH-vcd-is-not-reported-as-success [dg $h4 ok] 0
eqcheck SEL258-AH-vcd-sentence-says-why \
  [dg $h4 msg] {d.vcd (vcd) is now the current database, but a digital or non-spice database is not a result you can evaluate against.}
# THE INVARIANT, from both ends: `ok` and results::current can never disagree.
eqcheck SEL259-AH-ok-agrees-with-results-current \
  [list [dg $h4 ok] [expr {[pcall results::current] ne {} ? 1 : 0}]] {0 0}
# R302d, MEASURED WITH NO SHIM AT ALL: `ok 0` and the side effects STILL RAN.
# The engine's current database moved, so the window's case-mode cache is stale
# whether or not the thing that landed is a result -- gating the follow-ups on
# `ok` would leave a browser showing the old raw's signal list over the new
# raw's waveforms, which is the defect `browser_refresh $token 1` was added to
# rawbar_load to stop.
xschem raw clear
loadcell $tmp/cellA.sch
set ::wviewer::casemode($r4_tok) {fold sniff}
set h4b [pcall results::select $tmp/d.vcd vcd [dict create token $r4_tok]]
eqcheck SEL287-AH-side-effects-follow-the-engine-not-ok \
  [list [dg $h4b ok] [dg $h4b how] \
        [expr {[lsearch -exact [dg $h4b did] casemode_invalidate] >= 0 ? 1 : 0}] \
        [info exists ::wviewer::casemode($r4_tok)]] {0 read 1 0}

xschem raw clear
loadcell $tmp/cellA.sch
set h5 [pcall results::select $tmp/an.raw tran]
eqcheck SEL260-AH-ok-agrees-with-results-current-positive \
  [list [dg $h5 ok] [expr {[pcall results::current] ne {} ? 1 : 0}] \
        [dg [pcall results::current] path]] [list 1 1 [dg $h5 path]]

# ===========================================================================
# AJ -- THE SIX SIDE EFFECTS (R302). MRU, case mode x2, browser refresh, the
#      persistence seam -- and the ONE SENTENCE, which group AK takes.
#      R302d: they follow the ENGINE, not `ok`; only a REFUSED select runs none.
# ===========================================================================
# ---- the MRU (0216's shape). L11: rawhist_push NO-OPS unless
#      ::update_recent_files is set (issue 0119), so the flag is SET AND
#      RESTORED here -- and `rawhist_write` is shimmed so a verification run
#      cannot rewrite the user's own ~/.xschem/raw_history.
set r4_urf_had [info exists ::update_recent_files]
if {$r4_urf_had} { set r4_urf_old $::update_recent_files }
set r4_hist_old $::wviewer::rawhist
rename wviewer::rawhist_write r4_rhw_orig
proc wviewer::rawhist_write {} { return 1 }

xschem raw clear
loadcell $tmp/cellA.sch
set ::update_recent_files 0
set ::wviewer::rawhist {}
set j1 [pcall results::select $tmp/an.raw tran]
eqcheck SEL261-AJ-gated-session-leaves-no-MRU-trace \
  [list [dg $j1 ok] [lsearch -exact [dg $j1 did] mru] $::wviewer::rawhist] {1 -1 {}}
xschem raw clear
loadcell $tmp/cellA.sch
set ::update_recent_files 1
set ::wviewer::rawhist {}
set j2 [pcall results::select $tmp/an.raw tran]
eqcheck SEL262-AJ-ungated-session-pushes-the-MRU \
  [list [dg $j2 ok] [expr {[lsearch -exact [dg $j2 did] mru] >= 0 ? 1 : 0}] \
        [pcall wviewer::rawhist_get]] [list 1 1 [list $tmp/an.raw]]
# a REFUSED select pushes nothing: the MRU is a list of results, not of attempts
set j3 [pcall results::select $tmp/nosuch.raw tran]
eqcheck SEL263-AJ-refusal-pushes-nothing \
  [list [dg $j3 ok] [pcall wviewer::rawhist_get]] [list 0 [list $tmp/an.raw]]
set ::wviewer::rawhist $r4_hist_old
rename wviewer::rawhist_write {}
rename r4_rhw_orig wviewer::rawhist_write
if {$r4_urf_had} { set ::update_recent_files $r4_urf_old } else { unset ::update_recent_files }

# ---- case mode (R104). casemode_invalidate is a per-token ARRAY operation and
#      needs no window, so the REAL proc is driven and the REAL effect asserted.
xschem raw clear
loadcell $tmp/cellA.sch
set ::wviewer::casemode($r4_tok) {fold sniff}
set ::wviewer::casemodepick($r4_tok) fold
set j4 [pcall results::select $tmp/an.raw tran [dict create token $r4_tok]]
eqcheck SEL264-AJ-casemode-cache-dropped \
  [list [info exists ::wviewer::casemode($r4_tok)] \
        [info exists ::wviewer::casemodepick($r4_tok)] \
        [expr {[lsearch -exact [dg $j4 did] casemode_invalidate] >= 0 ? 1 : 0}]] {0 0 1}
# ...and the user's own statement SURVIVES and is RE-APPLIED, which is the half
# casemode_invalidate deliberately does not do (it never drops casemodeuser).
xschem raw clear
loadcell $tmp/cellA.sch
set ::wviewer::casemodeuser($r4_tok) [list preserve [file normalize $tmp/an.raw]]
set j5 [pcall results::select $tmp/an.raw tran [dict create token $r4_tok]]
eqcheck SEL265-AJ-casemode-reapplied \
  [list [dg $j5 ok] [expr {[lsearch -exact [dg $j5 did] casemode_reapply] >= 0 ? 1 : 0}] \
        [expr {[info exists ::wviewer::casemodepick($r4_tok)] ? $::wviewer::casemodepick($r4_tok) : {NONE}}]] {1 1 preserve}
catch {unset ::wviewer::casemodeuser($r4_tok)}
catch {unset ::wviewer::casemodepick($r4_tok)}
catch {unset ::wviewer::casemode($r4_tok)}
# with NO token there is no window to invalidate, and nothing is claimed
xschem raw clear
loadcell $tmp/cellA.sch
set j6 [pcall results::select $tmp/an.raw tran]
eqcheck SEL266-AJ-no-token-no-viewer-side-effects \
  [list [lsearch -exact [dg $j6 did] casemode_invalidate] \
        [lsearch -exact [dg $j6 did] browser_refresh]] {-1 -1}

# ---- the browser refresh. `wviewer::browser_refresh $token 1` -- the RELOAD
#      argument is not optional: without it the user gets the new raw's
#      waveforms under the OLD raw's signal list (rawbar_load's own comment).
#      Shimmed because the real one needs a packed sidebar; what is under test
#      is that results::select CALLS it, and with which arguments.
rename wviewer::browser_refresh r4_br_orig
proc wviewer::browser_refresh {token {reload 0}} {
  lappend ::r4_calls [list browser_refresh $token $reload]
  return 1
}
xschem raw clear
loadcell $tmp/cellA.sch
set r4_calls {}
set j7 [pcall results::select $tmp/an.raw tran [dict create token $r4_tok]]
eqcheck SEL267-AJ-browser-refreshed-with-reload \
  [list $r4_calls [expr {[lsearch -exact [dg $j7 did] browser_refresh] >= 0 ? 1 : 0}]] \
  [list [list [list browser_refresh $r4_tok 1]] 1]
# a REFUSED select refreshes nothing: item 12's improve-or-restore rule, reached
# by never starting the reload at all
set r4_calls {}
pcall results::select $tmp/nosuch.raw tran [dict create token $r4_tok]
eqcheck SEL268-AJ-refusal-refreshes-nothing $r4_calls {}
rename wviewer::browser_refresh {}
rename r4_br_orig wviewer::browser_refresh

# ---- the PERSISTENCE SEAM. Item 4 wrote the CALL; ITEM 6 LANDED THE WRITER,
#      so what is pinned here is still the call and its arguments -- the
#      engine's own spelling, the engine's analysis, and the caller's whole opts
#      dict.
#      ⚠ RESTATED BY ITEM 6: the VALUE below did not move (an opts dict naming
#      neither a `token` nor a `key` still answers 0 -- there is no window or
#      session to record the choice against), but the CLAIM its old name made,
#      "a no-op stub today", stopped being true. Group AO is where the filled
#      body is pinned.
eqcheck SEL269-AJ-persist-declines-when-no-window-or-session-is-named \
  [list [pcall results::persist /x/y.raw tran {}] [info args ::results::persist]] \
  {0 {path type opts}}
rename results::persist r4_ps_orig
proc results::persist {path type opts} {
  # ⚠ `::list`, NOT `list`. This proc's body runs in namespace `results`, where
  # `results::list` SHADOWS Tcl's built-in -- the hazard results.tcl's own header
  # documents and item 2 wrote every construction against. Driven: the first
  # version of this shim died with `wrong # args: should be "list"` and the
  # `catch` around the call site swallowed it, so the shim looked never-called.
  lappend ::r4_calls [::list persist $path $type $opts]
  return 1
}
xschem raw clear
loadcell $tmp/cellA.sch
set r4_calls {}
set j8 [pcall results::select $af_odd tran [dict create key r4sess]]
eqcheck SEL270-AJ-persist-called-with-the-engine-spelling \
  $r4_calls [list [list persist [file normalize $af_odd] tran [dict create key r4sess]]]
eqcheck SEL271-AJ-persist-recorded-in-did \
  [expr {[lsearch -exact [dg $j8 did] persist] >= 0 ? 1 : 0}] 1
set r4_calls {}
pcall results::select $tmp/nosuch.raw tran
eqcheck SEL272-AJ-refusal-persists-nothing $r4_calls {}
rename results::persist {}
rename r4_ps_orig results::persist

# ---- THE ORDER, NOT JUST THE MEMBERSHIP. The returned dict documents `did` as
#      "the side effects that actually FIRED, IN ORDER", and every check above
#      asks only whether a name is PRESENT -- `lsearch >= 0`. Membership cannot
#      see a re-ordering, and one re-ordering is destructive: R302's step list
#      puts the ONE SENTENCE last, AFTER browser_refresh, and the real
#      `wviewer::browser_refresh` writes the SAME sidebar status label the
#      sentence goes to (src/wave_viewer.tcl:10363, :10639). Emit the sentence
#      first and the refresh overwrites the sentence R804 exists for, with all
#      the membership checks still green. Both halves are pinned here: the
#      exact ordered `did`, and the sentence landing LAST in one shared call
#      list that the refresh writes into the way the real one does.
set r4_urf_had2 [info exists ::update_recent_files]
if {$r4_urf_had2} { set r4_urf_old2 $::update_recent_files }
set r4_hist_old2 $::wviewer::rawhist
rename wviewer::rawhist_write r4_rhw_orig2
proc wviewer::rawhist_write {} { return 1 }
rename results::persist r4_ps_orig2
proc results::persist {path type opts} { lappend ::r4_calls [::list persist] ; return 1 }
rename wviewer::browser_refresh r4_br_orig2
proc wviewer::browser_refresh {token {reload 0}} {
  lappend ::r4_calls [list status {Signal Browser: n signals}]
  return 1
}
rename wviewer::browser_status r4_bs_orig2
proc wviewer::browser_status {token msg} { lappend ::r4_calls [list status $msg] ; return 1 }

xschem raw clear
loadcell $tmp/cellA.sch
set ::update_recent_files 1
set ::wviewer::rawhist {}
set ::wviewer::casemodeuser($r4_tok) [list preserve [file normalize $tmp/an.raw]]
set r4_calls {}
set j9 [pcall results::select $tmp/an.raw tran [dict create token $r4_tok]]
eqcheck SEL291-AJ-did-is-the-five-side-effects-IN-ORDER \
  [dg $j9 did] {mru casemode_invalidate casemode_reapply browser_refresh persist}
eqcheck SEL292-AJ-the-sentence-is-written-LAST \
  [list $r4_calls [lindex $r4_calls end]] \
  [list [list [list status {Signal Browser: n signals}] [list persist] \
              [list status [dg $j9 msg]]] [list status [dg $j9 msg]]]
catch {unset ::wviewer::casemodeuser($r4_tok)}
catch {unset ::wviewer::casemodepick($r4_tok)}
catch {unset ::wviewer::casemode($r4_tok)}
rename wviewer::browser_status {} ; rename r4_bs_orig2 wviewer::browser_status
rename wviewer::browser_refresh {} ; rename r4_br_orig2 wviewer::browser_refresh
rename results::persist {} ; rename r4_ps_orig2 results::persist
set ::wviewer::rawhist $r4_hist_old2
rename wviewer::rawhist_write {} ; rename r4_rhw_orig2 wviewer::rawhist_write
if {$r4_urf_had2} { set ::update_recent_files $r4_urf_old2 } else { unset ::update_recent_files }

# ===========================================================================
# AK -- R802: THE CHANNEL IS CHOSEN BY HOST, AND THERE IS NO OTHER CHANNEL.
#      ASE-L -> ase::echo; the viewer sidebar -> wviewer::browser_status; the
#      Calculator -> calc::status. Never `puts`, never the status bar directly.
# ===========================================================================
rename ase::echo r4_echo_orig
proc ase::echo {msg {tag {}}} { lappend ::r4_calls [list ase $msg] }
rename calc::status r4_cs_orig
proc calc::status {{msg {}} {record 1}} { lappend ::r4_calls [list calc $msg] }
rename wviewer::browser_status r4_bs_orig
proc wviewer::browser_status {token msg} { lappend ::r4_calls [list viewer $token $msg] ; return 1 }

xschem raw clear
loadcell $tmp/cellA.sch
set r4_calls {}
set k1 [pcall results::select $tmp/an.raw tran [dict create host ase]]
eqcheck SEL273-AK-host-ase-goes-to-ase-echo \
  [list $r4_calls [dg $k1 channel]] [list [list [list ase [dg $k1 msg]]] ase]
set r4_calls {}
set k2 [pcall results::select $tmp/an.raw tran [dict create host calc]]
eqcheck SEL274-AK-host-calc-goes-to-calc-status \
  [list $r4_calls [dg $k2 channel]] [list [list [list calc [dg $k2 msg]]] calc]
set r4_calls {}
set k3 [pcall results::select $tmp/an.raw tran [dict create token $r4_tok]]
eqcheck SEL275-AK-a-token-defaults-to-the-viewer-sidebar \
  [list $r4_calls [dg $k3 channel]] [list [list [list viewer $r4_tok [dg $k3 msg]]] viewer]
set r4_calls {}
set k4 [pcall results::select $tmp/an.raw tran [dict create key r4sess]]
eqcheck SEL276-AK-a-session-key-defaults-to-ASE \
  [list $r4_calls [dg $k4 channel]] [list [list [list ase [dg $k4 msg]]] ase]
set r4_calls {}
set k5 [pcall results::select $tmp/an.raw tran [dict create host none token $r4_tok]]
eqcheck SEL277-AK-host-none-emits-nothing \
  [list $r4_calls [dg $k5 channel] [expr {[dg $k5 msg] ne {} ? 1 : 0}]] {{} {} 1}
set r4_calls {}
set k6 [pcall results::select $tmp/an.raw tran]
eqcheck SEL278-AK-no-host-no-token-no-key-emits-nothing \
  [list $r4_calls [dg $k6 channel]] {{} {}}
# a REFUSAL is emitted too -- R801: every refusal writes ONE sentence
set r4_calls {}
set k7 [pcall results::select $tmp/nosuch.raw tran [dict create host ase]]
eqcheck SEL279-AK-refusals-are-emitted-as-well \
  [list $r4_calls [dg $k7 channel]] [list [list [list ase [dg $k7 msg]]] ase]
# the ENGINE's refusal is emitted too, and it is a DIFFERENT arm of the proc
# from the resolver's (SEL279): that one never reaches `xschem raw select`.
set r4_calls {}
set k8 [pcall results::select $tmp/an.raw ac [dict create host ase]]
eqcheck SEL288-AK-engine-refusals-are-emitted-too \
  [list $r4_calls [dg $k8 channel] [dg $k8 how]] \
  [list [list [list ase [dg $k8 msg]]] ase refused]
rename ase::echo {} ; rename r4_echo_orig ase::echo
rename calc::status {} ; rename r4_cs_orig calc::status
rename wviewer::browser_status {} ; rename r4_bs_orig wviewer::browser_status
# ---- R802's HOUSE RULE HAS A DETECTOR NOW. "NEVER `puts`, NEVER the status bar
#      directly", and R802a's own ruling REJECTS a fallback to a global channel
#      when the named one is unreachable -- but every check above only proves
#      the three named channels are REACHED. Adding a `puts` fallback beside
#      them printed five lines during this suite and left all checks green.
#      Two halves, because neither alone is enough: the SOURCE must not contain
#      the word (comment lines stripped -- the file states the rule in prose and
#      must not trip its own detector), and the two no-emission selects must not
#      call ::puts at RUNTIME, which is where a fallback reached through some
#      other name would show up.
# The detector's blind-spot sentinel: it must SEE `puts` when `puts` is there.
set ak_pre {(^|[^A-Za-z0-9_:.])puts([^A-Za-z0-9_:]|$)}
set ak_blind {}
foreach ak_s {{puts "x"} {  puts stderr $m} {catch {puts $ch $l}}} {
  if {![regexp $ak_pre $ak_s]} { lappend ak_blind $ak_s }
}
eqcheck SEL293-AK-no-puts-anywhere-in-results-tcl-and-the-detector-can-see-puts \
  [list [regexp -line $ak_pre [r2_code [r2_rd $r2_tcl]]] $ak_blind] {0 {}}
# RUNTIME half: the two `no channel` outcomes (host none, and neither token nor
# key) must write NOTHING anywhere. ::puts is shimmed for the duration of the
# two calls ONLY -- results::select does no `update` and no `after` (L7), so
# nothing else can be running inside that window.
set ak_puts 0
rename ::puts ak_puts_orig
# FORWARDS to the original rather than swallowing. Driven: a swallowing shim
# whose restore is dropped blanks the whole suite -- no RESULT line at all --
# which full_audit scores FAIL for the wrong reason and no check can explain.
# Forwarding keeps the file legible so SEL280 can report the dropped restore.
proc ::puts {args} { incr ::ak_puts ; uplevel 1 [linsert $args 0 ak_puts_orig] }
set ak_err {}
if {[catch {
  set m1 [results::select $tmp/an.raw tran [dict create host none token $r4_tok]]
  set m2 [results::select $tmp/an.raw tran]
} ak_res]} { set ak_err $ak_res }
rename ::puts {} ; rename ak_puts_orig ::puts
eqcheck SEL294-AK-a-no-channel-select-never-calls-puts \
  [list $ak_err $ak_puts [dg $m1 channel] [dg $m2 channel] \
        [expr {[dg $m1 msg] ne {} && [dg $m2 msg] ne {} ? 1 : 0}]] {{} 0 {} {} 1}

set r4_back {}
foreach {r4p r4b} $r4_bodies {
  if {[catch {info body $r4p} r4n]} { set r4n {MISSING} }
  lappend r4_back [expr {$r4n eq $r4b ? 1 : 0}]
}
eqcheck SEL280-AK-every-shim-restored-BY-BODY \
  [list [llength $r4_back] [lsort -unique $r4_back]] {8 1}

# ===========================================================================
# AL -- R805: ONE SENTENCE FORM PER OUTCOME, ALL DIFFERENT, AND `stale` SAYS
#      WHY. R202: a stale result is REPORTED AND STILL SELECTED; `invalid`
#      falls back to the derived path and says which happened. Neither is an
#      error.
# ===========================================================================
set al_net [file join $tmp al_net.spice]
wr $al_net "* netlist\n"
file mtime $al_net [expr {[file mtime $tmp/an.raw] + 60}]

xschem raw clear
loadcell $tmp/cellA.sch
set l1 [pcall results::select $tmp/an.raw tran [dict create netlist $al_net]]
eqcheck SEL281-AL-stale-is-still-selected \
  [list [dg $l1 ok] [dg $l1 how] [dg $l1 status] [dg $l1 reason] \
        [pcall xschem raw rawfile]] [list 1 read stale mtime $tmp/an.raw]
eqcheck SEL282-AL-stale-says-why-and-terminates-once \
  [list [string match {Selected an.raw (tran), but this result is older than the netlist*} [dg $l1 msg]] \
        [string match {*..} [dg $l1 msg]]] {1 0}

# `invalid` -> the derived path is selected, and the sentence says which
xschem raw clear
loadcell $tmp/cellA.sch
set l2 [pcall results::select $tmp/nosuch.raw tran [dict create derived $tmp/bn.raw]]
eqcheck SEL283-AL-invalid-falls-back-and-selects \
  [list [dg $l2 ok] [dg $l2 how] [dg $l2 status] [dg $l2 path]] \
  [list 1 read invalid $tmp/bn.raw]
eqcheck SEL284-AL-invalid-sentence-names-both \
  [dg $l2 msg] {nosuch.raw is no longer on disk, so bn.raw (tran) was selected instead.}

# `default` -> nothing named, the derived one is selected
xschem raw clear
loadcell $tmp/cellA.sch
set l3 [pcall results::select {} {} [dict create derived $tmp/an.raw]]
eqcheck SEL285-AL-default-selects-the-derived-one \
  [list [dg $l3 ok] [dg $l3 status] [dg $l3 path] [dg $l3 msg]] \
  [list 1 default $tmp/an.raw {No result was named, so the derived one was selected: an.raw (tran).}]

# NINE outcomes, NINE sentences, none empty and none shared (the check's own
# assertion is `{9 -1}`; this comment said "six" until the fixer round). `ok` and the two
# not-a-success forms are taken from the groups above so this is a comparison
# across the WHOLE set, not a re-run of one arm.
set al_msgs [list [dg $s1 msg] [dg $l1 msg] [dg $l2 msg] [dg $l3 msg] \
                  [dg $h2 msg] [dg $h4 msg] [dg $f1 msg] [dg $f2 msg] [dg $f3 msg]]
eqcheck SEL286-AL-nine-outcomes-nine-sentences \
  [list [llength [lsort -unique $al_msgs]] [lsearch -exact $al_msgs {}]] {9 -1}


# ===========================================================================
# AM -- T-C: `wviewer::rawbar_load`'s OBSERVABLE BEHAVIOUR, BEFORE AND AFTER
#      THE RE-EXPRESSION, SIDE BY SIDE IN ONE PROCESS (results batch item 5,
#      spec section 7 R501, section 12 T-C).
#
#      T-C IS A COMPARISON, NOT A FEATURE TEST. A suite that only exercised the
#      new body would prove nothing about equivalence, so the PRE body is
#      FROZEN HERE as `wviewer::rawbar_load_PRE` -- the shipped statements at
#      base HEAD `226302f9`, comments dropped, name changed, nothing else --
#      and every scenario is run twice from an identical starting registry with
#      the two observable tuples compared.
#
#      THE TUPLE IS T-C's OWN LIST: rc, the registry before and after, the
#      current database and its analysis, the MRU list, and the sidebar
#      sentences -- an EMPTY sentence list is how "this arm is silent" is
#      measured. It is deliberately NOT the whole call trace: three side
#      effects legitimately differ and group AN measures every one of them.
#
#      EVERY LEAF IS SHIMMED EXCEPT THE ENGINE. `switch_ctx` is shimmed because
#      arm 4 -- a REFUSED context switch -- is otherwise only reachable by
#      raising a semaphore under a live window, and R501b's ruling is about
#      exactly that arm. `xschem raw read` / `xschem raw select` are the REAL
#      verbs, so every registry, analysis and MRU value below is a real
#      measurement and not a shim's opinion.
# ===========================================================================
wr $tmp/notraw_am.txt "this is not a raw file at all\n"
# a SECOND one-point operating point, with different numbers from op.raw. D3
# needs two: the question is whether the schematic keeps showing the FIRST
# file's voltages after the Location bar loads the second.
wr $tmp/op2.raw "Title: results select op2
Plotname: Operating Point
Flags: real
No. Variables: 2
No. Points: 1
Variables:
\t0\tv(o1)\tvoltage
\t1\tv(o2)\tvoltage
Values:
0\t3.500000000000000e+00
\t4.500000000000000e+00

"
file mkdir $tmp/amsub

proc wviewer::rawbar_load_PRE {token path} {
  variable windows
  if {![dict exists $windows $token]} { return 0 }
  set path [string trim $path]
  if {$path eq {}} {
    wviewer::browser_status $token {Location: type the path of a raw file}
    return 0
  }
  if {![file isfile $path]} {
    wviewer::browser_status $token "Location: no such file '[file tail $path]'"
    return 0
  }
  if {![wviewer::switch_ctx $token]} { return 0 }
  wviewer::capture_live_view_state $token
  set rc 0
  catch {set rc [xschem raw read $path]}
  if {$rc != 1} {
    wviewer::browser_status $token "Location: could not read '[file tail $path]'"
    return 0
  }
  wviewer::regenerate $token
  catch {wviewer::browser_refresh $token 1}
  wviewer::rawhist_push $path
  wviewer::rawbar_sync $token $path
  wviewer::log_action [list wviewer::rawbar_load $token $path]
  return 1
}

# THE ANTI-VACUITY GATE FOR THE WHOLE GROUP. Every check below compares two
# procs, and if they were the same proc every comparison would be a tautology.
# Both halves are asserted positively: the frozen body is the one that calls
# the old verb and knows nothing of the door, the shipped one is the reverse.
# THE OLD VERB IS GONE FROM THE SHIPPED PROC ENTIRELY -- comments included,
# which is why the comment above the call site says "the old read verb" in
# words rather than quoting it.
set am_pre  [info body wviewer::rawbar_load_PRE]
set am_post [info body wviewer::rawbar_load]
eqcheck SEL295-AM-the-two-bodies-are-really-different \
  [list [regexp {xschem raw read} $am_pre] [regexp {results::select} $am_pre] \
        [regexp {xschem raw read} $am_post] [regexp {results::select} $am_post]] {1 0 0 1}

# --- the harness -------------------------------------------------------
set am_tok  am_tok
set am_stat {}
set am_swok 1
set am_trace {}
set am_leaves {browser_status switch_ctx capture_live_view_state regenerate
               browser_refresh rawbar_sync log_action casemode_invalidate
               casemode_reapply rawhist_write}
# capture the REAL bodies now, so SEL333 can prove the restore BY BODY. Item
# 4's SEL280 lesson: `info procs <name> ne {}` is satisfied by the shim still
# being installed, so a dropped restore line stays green under a name test.
set am_bodies {}
foreach am_p $am_leaves { dict set am_bodies $am_p [info body wviewer::$am_p] }
set am_wrf_body [info body write_recent_file]

set am_urf_had [info exists ::update_recent_files]
if {$am_urf_had} { set am_urf_old $::update_recent_files }
set am_hist_old $::wviewer::rawhist
# ⚠ EVERY WRITER IS SHIMMED BEFORE THE FLAG IS SET, NEVER AFTER. An ad-hoc
# drive in item 4 set ::update_recent_files with the real `rawhist_write` in
# place and TRUNCATED the user's ~/.xschem/raw_history; there is no .bak and the
# list was unrecoverable. CREW_BRIEF.md section 3 is that damage written down.
#
# ⚠⚠ AND `rawhist_write` IS NOT THE ONLY WRITER THAT FLAG UNGATES. `::update_recent_files`
# gates FOUR procs, and `update_recent_file` (src/xschem.tcl:3869) is one of
# them: it fires on every `xschem load`, and `am_run` loads a cell on every
# call. MEASURED, not assumed -- the first version of this group raised the flag
# around the whole of `am_run` and rewrote the user's ~/.xschem/recent_files,
# which the item-4 damage report says to CHECK for (`ls -la ~/.xschem`) rather
# than infer from a green suite. `write_recent_file` is therefore shimmed too,
# AND the flag is raised only around the call under test (see `am_run`).
rename write_recent_file am_orig_write_recent_file
proc write_recent_file {} { return }
foreach am_p $am_leaves { rename wviewer::$am_p am_orig_$am_p }
proc wviewer::rawhist_write {} { return 1 }
set ::update_recent_files 0
proc wviewer::browser_status {token msg} {
  lappend ::am_stat $msg ; lappend ::am_trace status ; return 1
}
proc wviewer::switch_ctx {token} { lappend ::am_trace switch_ctx ; return $::am_swok }
proc wviewer::capture_live_view_state {token} { lappend ::am_trace capture }
proc wviewer::regenerate {token} { lappend ::am_trace regenerate }
proc wviewer::browser_refresh {token {reload 0}} {
  lappend ::am_trace [::list browser_refresh $reload] ; return 1
}
proc wviewer::rawbar_sync {token {path {}}} { lappend ::am_trace [::list rawbar_sync $path] }
proc wviewer::log_action {line} { lappend ::am_trace [::list log_action $line] }
proc wviewer::casemode_invalidate {token} { lappend ::am_trace casemode_invalidate }
proc wviewer::casemode_reapply {token rawfile} { lappend ::am_trace casemode_reapply ; return 0 }
dict set ::wviewer::windows $am_tok win_path .am_fake_drw

# Run ONE scenario against ONE of the two bodies, from a reset registry.
# `pre` is a script run at global level after the reset and before the call;
# it uses the ENGINE directly, never either body, so both legs of a comparison
# start from a state neither implementation produced.
proc am_run {which token path swok pre} {
  global tmp
  xschem raw clear
  loadcell $tmp/cellA.sch
  catch {array unset ngspice::ngspice_data}
  set ::wviewer::rawhist {}
  set ::am_stat {}
  set ::am_trace {}
  set ::am_swok $swok
  if {$pre ne {}} { uplevel #0 $pre }
  set before [slot_list]
  # L11: `rawhist_push` no-ops unless this is set, so the MRU delta is only
  # measurable with it up -- and it is up for the CALL ALONE, never across the
  # `loadcell` above, because the same flag ungates `update_recent_file`.
  set ::update_recent_files 1
  if {$which eq {PRE}} {
    set rc [pcall wviewer::rawbar_load_PRE $token $path]
  } else {
    set rc [pcall wviewer::rawbar_load $token $path]
  }
  set ::update_recent_files 0
  return [::list rc $rc before $before after [slot_list] \
            cur [pcall xschem raw rawfile] type [pcall xschem raw_query sim_type] \
            mru $::wviewer::rawhist stat $::am_stat trace $::am_trace]
}
proc am_tuple {r} {
  return [::list [dict get $r rc] [dict get $r before] [dict get $r after] \
            [dict get $r cur] [dict get $r type] [dict get $r mru] [dict get $r stat]]
}
proc am_same {id name path {swok 1} {pre {}}} {
  global am_tok
  set a [am_run PRE  $am_tok $path $swok $pre]
  set b [am_run POST $am_tok $path $swok $pre]
  eqcheck "$id-AM-$name" [am_tuple $b] [am_tuple $a]
  return [::list $a $b]
}
proc am_silence {r} {
  if {[llength [dict get $r stat]]} { return spoke }
  return silent
}
proc am_pos {trace what} {
  set i 0
  foreach e $trace { if {[lindex $e 0] eq $what} { return $i } ; incr i }
  return -1
}

# --- ARM 1: an unknown token. Silent in both, and nothing moves. Driven
#     WITHOUT `am_same`, which always passes the registered token: the first
#     version of this leg passed the unknown token in the PATH slot and landed
#     in arm 3 instead -- caught by SEL297 and SEL318, which is why the silence
#     ledger is asserted against measured VALUES and not only against itself.
set am1a [am_run PRE  NOSUCHTOKEN $tmp/an.raw 1 {}]
set am1b [am_run POST NOSUCHTOKEN $tmp/an.raw 1 {}]
eqcheck SEL296-AM-arm1-unknown-token-identical [am_tuple $am1b] [am_tuple $am1a]
set am1 [list $am1a $am1b]
eqcheck SEL297-AM-arm1-is-silent-in-both \
  [list [dict get [lindex $am1 0] stat] [dict get [lindex $am1 1] stat] \
        [dict get [lindex $am1 1] rc] [dict get [lindex $am1 1] trace]] {{} {} 0 {}}

# --- ARM 2: nothing typed.
set am2 [am_same SEL298 arm2-empty-path-identical {   }]
eqcheck SEL299-AM-arm2-sentence-verbatim \
  [list [dict get [lindex $am2 1] stat] [dict get [lindex $am2 1] rc]] \
  {{{Location: type the path of a raw file}} 0}

# --- ARM 3: no such file -- the `file isfile` guard R501 says must survive.
set am3 [am_same SEL300 arm3-no-such-file-identical $tmp/nosuch_am.raw]
eqcheck SEL301-AM-arm3-sentence-verbatim \
  [list [dict get [lindex $am3 1] stat] [dict get [lindex $am3 1] rc]] \
  {{{Location: no such file 'nosuch_am.raw'}} 0}
# ...and it still refuses BEFORE the context move, which is what makes it a
# Location-bar sentence about a typo rather than an engine one.
eqcheck SEL302-AM-arm3-refuses-before-switch-ctx \
  [list [dict get [lindex $am3 0] trace] [dict get [lindex $am3 1] trace]] {status status}

# --- ARM 4: A REFUSED CONTEXT SWITCH. SILENT, IN BOTH. R501b.
set am4 [am_same SEL303 arm4-refused-switch-ctx-identical $tmp/an.raw 0]
eqcheck SEL304-AM-arm4-is-silent-in-both \
  [list [dict get [lindex $am4 0] stat] [dict get [lindex $am4 1] stat] \
        [dict get [lindex $am4 1] rc] [dict get [lindex $am4 1] trace]] {{} {} 0 switch_ctx}

# --- ARM 5: the engine refused. Two shapes -- a file that is not a raw at all,
#     and a TABLE, a real database whose typeless read cannot be dispatched.
#     ⚠ BOTH ARE DRIVEN WITH A RESULT ALREADY LOADED. The first version ran
#     them on an EMPTY registry, where "a refusal leaves the previous result
#     standing" is true of nothing at all -- a sabotage that put
#     `xschem raw clear` into the refusal arm left SEL309 green.
set am5 [am_same SEL305 arm5-not-a-raw-identical $tmp/notraw_am.txt \
           1 {xschem raw read $tmp/an.raw}]
eqcheck SEL306-AM-arm5-sentence-verbatim \
  [list [dict get [lindex $am5 1] stat] [dict get [lindex $am5 1] rc]] \
  {{{Location: could not read 'notraw_am.txt'}} 0}
set am6 [am_same SEL307 arm5-table-typeless-identical $tmp/t.table \
           1 {xschem raw read $tmp/an.raw}]
eqcheck SEL308-AM-arm5-table-sentence-verbatim \
  [dict get [lindex $am6 1] stat] {{Location: could not read 't.table'}}
# F7/T-D through BOTH bodies: a refusal leaves the previous result standing.
eqcheck SEL309-AM-refusal-leaves-the-registry-alone \
  [list [expr {[dict get [lindex $am5 0] before] eq [dict get [lindex $am5 0] after]}] \
        [expr {[dict get [lindex $am5 1] before] eq [dict get [lindex $am5 1] after]}] \
        [expr {[dict get [lindex $am6 1] before] eq [dict get [lindex $am6 1] after]}] \
        [llength [dict get [lindex $am5 1] before]] \
        [dict get [lindex $am5 1] cur]] [list 1 1 1 1 $tmp/an.raw]

# --- SUCCESS: a fresh read.
set am7 [am_same SEL310 success-fresh-read-identical $tmp/an.raw]
eqcheck SEL311-AM-fresh-read-really-loaded-and-pushed \
  [list [dict get [lindex $am7 1] rc] [llength [dict get [lindex $am7 1] after]] \
        [dict get [lindex $am7 1] cur] [dict get [lindex $am7 1] mru] \
        [dict get [lindex $am7 1] stat]] \
  [list 1 1 $tmp/an.raw [list [file normalize $tmp/an.raw]] {}]
# THE MRU DELTA IS IDENTICAL, and it is not a coincidence: `rawhist_add`
# normalises its argument, so pushing the caller's spelling (PRE) and the
# engine's (POST) store the same string. L11's flag is set for the whole group
# or neither body would push at all.
eqcheck SEL312-AM-mru-delta-identical \
  [list [dict get [lindex $am7 0] mru] [dict get [lindex $am7 1] mru]] \
  [list [list [file normalize $tmp/an.raw]] [list [file normalize $tmp/an.raw]]]

# --- SUCCESS: the SAME path again -- the dedupe path. No slot added.
set am8 [am_same SEL313 success-same-path-again-identical $tmp/an.raw \
           1 {xschem raw read $tmp/an.raw}]
eqcheck SEL314-AM-same-path-adds-no-slot \
  [list [dict get [lindex $am8 1] rc] \
        [expr {[dict get [lindex $am8 1] before] eq [dict get [lindex $am8 1] after]}] \
        [llength [dict get [lindex $am8 1] after]]] {1 1 1}

# --- SUCCESS: a SECOND, different raw. F7: the registry accumulates, and
#     neither body clears.
set am9 [am_same SEL315 success-second-raw-identical $tmp/bn.raw \
           1 {xschem raw read $tmp/an.raw}]
eqcheck SEL316-AM-second-raw-accumulates \
  [list [dict get [lindex $am9 1] rc] [llength [dict get [lindex $am9 1] before]] \
        [llength [dict get [lindex $am9 1] after]] [dict get [lindex $am9 1] cur]] \
  [list 1 1 2 $tmp/bn.raw]

# --- THE SILENCE LEDGER, in one assertion, and then the ledger's own values.
#     Five arms: three write exactly one sentence, two write none, and no
#     success path writes any -- before and after.
eqcheck SEL317-AM-the-five-arms-say-the-same-things \
  [list [am_silence [lindex $am1 1]] [am_silence [lindex $am2 1]] [am_silence [lindex $am3 1]] \
        [am_silence [lindex $am4 1]] [am_silence [lindex $am5 1]] [am_silence [lindex $am7 1]]] \
  [list [am_silence [lindex $am1 0]] [am_silence [lindex $am2 0]] [am_silence [lindex $am3 0]] \
        [am_silence [lindex $am4 0]] [am_silence [lindex $am5 0]] [am_silence [lindex $am7 0]]]
eqcheck SEL318-AM-and-the-ledger-is-the-measured-one \
  [list [am_silence [lindex $am1 1]] [am_silence [lindex $am2 1]] [am_silence [lindex $am3 1]] \
        [am_silence [lindex $am4 1]] [am_silence [lindex $am5 1]] [am_silence [lindex $am7 1]]] \
  {silent spoke spoke silent spoke silent}

# --- RC IS TWO-VALUED, and that is R501b's load-bearing measurement. T-J/F6's
#     defect is a refusal that READS LIKE AN ANSWER; this proc has no answer a
#     refusal could be mistaken for. Every refusal is exactly 0, every success
#     exactly 1, and nothing returns a list, a path or {}.
eqcheck SEL319-AM-refusal-is-never-mistakable-for-a-result \
  [lsort -unique [list [dict get [lindex $am1 1] rc] [dict get [lindex $am2 1] rc] \
     [dict get [lindex $am3 1] rc] [dict get [lindex $am4 1] rc] \
     [dict get [lindex $am5 1] rc] [dict get [lindex $am6 1] rc] \
     [dict get [lindex $am7 1] rc] [dict get [lindex $am8 1] rc] \
     [dict get [lindex $am9 1] rc]]] {0 1}

# ===========================================================================
# AN -- THE FOUR DIVERGENCES THAT ARE REAL, AND THE ORDERING THAT MOVED.
#      RULED AS R501c. Coming through R303's one door brings R302a's spelling
#      rule, R302d's side effects and R301d/R301f's verb semantics with it; a
#      re-expression claiming to have none would be the lie. Each is MEASURED
#      against the frozen PRE body in the same process, and each is a
#      CORRECTNESS GAIN -- which is the argument the ruling rests on, so it is
#      asserted rather than asserted about.
# ===========================================================================

# --- D1: ONE SPELLING PER RUN (R302a). `<d>/amsub/../an.raw` used to add a
#     SECOND slot beside `<d>/an.raw` -- the engine dedupes by strcmp on the
#     stored spelling -- and F7 means that duplicate is permanent.
set an1p [am_run PRE  $am_tok $tmp/amsub/../an.raw 1 {xschem raw read $tmp/an.raw}]
set an1q [am_run POST $am_tok $tmp/amsub/../an.raw 1 {xschem raw read $tmp/an.raw}]
eqcheck SEL320-AN-d1-pre-made-a-duplicate-slot \
  [list [dict get $an1p rc] [llength [dict get $an1p before]] [llength [dict get $an1p after]] \
        [dict get $an1p cur]] [list 1 1 2 $tmp/amsub/../an.raw]
eqcheck SEL321-AN-d1-post-converges-on-one-slot \
  [list [dict get $an1q rc] [llength [dict get $an1q before]] [llength [dict get $an1q after]] \
        [dict get $an1q cur]] [list 1 1 1 $tmp/an.raw]

# --- D2: THE CASE-MODE CACHE (R302d). The PRE body changed the current
#     database and left the cached readout for the OLD one standing. The REAL
#     `casemode_invalidate` is put back for both legs: it is a per-token ARRAY
#     operation needing no window, so the real effect is what is asserted, and
#     the PRE body never calls it either way.
rename wviewer::casemode_invalidate {}
rename am_orig_casemode_invalidate wviewer::casemode_invalidate
set an2pre {
  set ::wviewer::casemode($::am_tok) {fold sniff}
  set ::wviewer::casemodepick($::am_tok) fold
}
am_run PRE $am_tok $tmp/an.raw 1 $an2pre
set an2p [list [info exists ::wviewer::casemode($am_tok)] [info exists ::wviewer::casemodepick($am_tok)]]
catch {unset ::wviewer::casemode($am_tok)} ; catch {unset ::wviewer::casemodepick($am_tok)}
am_run POST $am_tok $tmp/an.raw 1 $an2pre
set an2q [list [info exists ::wviewer::casemode($am_tok)] [info exists ::wviewer::casemodepick($am_tok)]]
catch {unset ::wviewer::casemode($am_tok)} ; catch {unset ::wviewer::casemodepick($am_tok)}
rename wviewer::casemode_invalidate am_orig_casemode_invalidate
proc wviewer::casemode_invalidate {token} { lappend ::am_trace casemode_invalidate }
eqcheck SEL322-AN-d2-stale-cache-before-dropped-after [list $an2p $an2q] {{1 1} {0 0}}

# --- D3: A ONE-POINT OP PUBLISHES (R301d). The PRE body left the SCHEMATIC
#     annotated from one database while the VIEWER drew another -- the same
#     staleness `browser_refresh $token 1` was added to this proc to stop.
#     `?` is what get_voltage answers when nothing has been published.
set an3pre {
  catch {array unset ngspice::ngspice_data}
  pcall xschem raw select $tmp/op.raw op
}
set an3p  [am_run PRE  $am_tok $tmp/op2.raw 1 $an3pre]
set an3pv [pcall ngspice::get_voltage o1]
set an3q  [am_run POST $am_tok $tmp/op2.raw 1 $an3pre]
set an3qv [pcall ngspice::get_voltage o1]
eqcheck SEL323-AN-d3-pre-left-the-previous-op-on-the-schematic \
  [list [dict get $an3p rc] [dict get $an3p cur] $an3pv] [list 1 $tmp/op2.raw 1.5]
eqcheck SEL324-AN-d3-post-publishes-the-selected-one \
  [list [dict get $an3q rc] [dict get $an3q cur] $an3qv] [list 1 $tmp/op2.raw 3.5]
catch {array unset ngspice::ngspice_data}

# --- D4: A TYPELESS RE-LOAD KEEPS THE ANALYSIS YOU ARE ON (R301f). One file,
#     two plots, two slots, ONE RUN (U11). The PRE body's dedupe matches on the
#     FILENAME ALONE and lands on whichever slot comes first, so re-typing the
#     path you are already looking at silently moved you off `tran`.
set an4pre {
  xschem raw read $tmp/multi.raw dc
  xschem raw read $tmp/multi.raw tran
  xschem raw switch $tmp/multi.raw tran
}
set an4p [am_run PRE  $am_tok $tmp/multi.raw 1 $an4pre]
set an4q [am_run POST $am_tok $tmp/multi.raw 1 $an4pre]
eqcheck SEL325-AN-d4-pre-moved-you-off-tran \
  [list [dict get $an4p rc] [dict get $an4p type] [llength [dict get $an4p after]]] {1 dc 2}
eqcheck SEL326-AN-d4-post-keeps-you-on-tran \
  [list [dict get $an4q rc] [dict get $an4q type] [llength [dict get $an4q after]]] {1 tran 2}

# --- D5: THE ORDERING THAT MOVED. `browser_refresh` is one of R302d's side
#     effects, so it now runs BEFORE `regenerate` rather than after it. The
#     `reload` argument survives, and so does the widget tail.
set an5p [dict get [lindex $am7 0] trace]
set an5q [dict get [lindex $am7 1] trace]
eqcheck SEL327-AN-d5-pre-regenerated-then-refreshed \
  [expr {[am_pos $an5p regenerate] < [am_pos $an5p browser_refresh] ? 1 : 0}] 1
eqcheck SEL328-AN-d5-post-refreshes-then-regenerates \
  [list [expr {[am_pos $an5q browser_refresh] < [am_pos $an5q regenerate] ? 1 : 0}] \
        [lindex $an5q [am_pos $an5q browser_refresh]]] {1 {browser_refresh 1}}
eqcheck SEL329-AN-d5-capture-still-comes-first-in-both \
  [list [am_pos $an5p capture] [am_pos $an5q capture]] {1 1}
# the tail is unchanged: `rawbar_sync` gets THE PATH THE USER TYPED, not the
# engine's spelling, and `log_action` replays the gesture (R501c).
eqcheck SEL330-AN-d5-the-widget-tail-is-unchanged \
  [list [lindex $an5q [am_pos $an5q rawbar_sync]] [lindex $an5q [am_pos $an5q log_action]]] \
  [list [list rawbar_sync $tmp/an.raw] \
        [list log_action [list wviewer::rawbar_load $am_tok $tmp/an.raw]]]

# ⚠ SEL330 ON ITS OWN IS NOT ENOUGH, AND THE FIXER ROUND MEASURED WHY. It reads
#   `am7`'s trace, whose typed path IS the engine's spelling (`$tmp/an.raw` is
#   already normalised), so a regression that handed the widget tail
#   `[dict get $res path]` instead of `$path` passed every check in this file
#   AND in test_wave_sigbrowser_i1315. The ONE fixture in this suite where the
#   two spellings provably differ is D1's `an1q` (`$tmp/amsub/../an.raw`), and
#   until SEL336 it never inspected `trace` at all. R501c's "the Location bar
#   echoes the gesture, not its resolution" is only asserted where a resolution
#   exists to be echoed by mistake.
set an5r [dict get $an1q trace]
eqcheck SEL336-AN-d5-the-widget-tail-carries-the-TYPED-spelling-when-they-differ \
  [list [lindex $an5r [am_pos $an5r rawbar_sync]] [lindex $an5r [am_pos $an5r log_action]] \
        [string equal $tmp/amsub/../an.raw [dict get $an1q cur]]] \
  [list [list rawbar_sync $tmp/amsub/../an.raw] \
        [list log_action [list wviewer::rawbar_load $am_tok $tmp/amsub/../an.raw]] 0]

# ⚠ AND THE FOUR CALLS R501 KEEPS IN THE VIEWER MUST BE THERE ON *EVERY*
#   SUCCESS PATH, NOT ONLY ON A FRESH READ. SEL327-SEL330 all read `am7`, which
#   is the `how read` leg. The fixer round measured a sabotage
#   (`if {$how eq {read}} { wviewer::regenerate $token }`) that survived all
#   1008 checks in the four suites that touch `rawbar_load` while leaving the
#   viewer drawing the OLD database after the engine had moved to the new one --
#   exactly the case R501 says must not move. So the viewer tail is compared
#   PRE vs POST as a SUBSEQUENCE, on the already-loaded (`how switch`) leg and
#   on the second-raw (`how read`) leg, and its literal order is pinned.
proc am_tail {r} {
  set out {}
  foreach e [dict get $r trace] {
    if {[lindex $e 0] in {capture regenerate rawbar_sync log_action}} {
      lappend out [lindex $e 0]
    }
  }
  return $out
}
set am_tail_want {capture regenerate rawbar_sync log_action}
# the third term is the anti-vacuity one: `am8` really IS the already-loaded
# leg, i.e. the registry did not grow (SEL314's measurement, restated here so
# this check does not depend on reading SEL314 to know which path it is on).
eqcheck SEL334-AN-d5-viewer-tail-identical-on-the-already-loaded-path \
  [list [am_tail [lindex $am8 1]] [am_tail [lindex $am8 0]] \
        [expr {[dict get [lindex $am8 1] before] eq [dict get [lindex $am8 1] after]}] \
        [llength [dict get [lindex $am8 1] before]]] \
  [list $am_tail_want $am_tail_want 1 1]
eqcheck SEL335-AN-d5-viewer-tail-identical-on-the-second-raw-path \
  [list [am_tail [lindex $am9 1]] [am_tail [lindex $am9 0]] \
        [llength [dict get [lindex $am9 1] before]] \
        [llength [dict get [lindex $am9 1] after]]] \
  [list $am_tail_want $am_tail_want 1 2]

# --- D6: A `~/`-SPELLED PATH NOW LOADS, WHERE THE PRE-ITEM BODY REFUSED IT.
#     THE FIFTH DIVERGENCE, found in the fixer round and the only one that moves
#     rc AND the sentence together -- D1-D4 all keep rc 1 and an empty sentence
#     list. `file isfile ~/x.raw` is 1 (Tcl expands `~`), so arm 3 passes in BOTH
#     bodies; then the PRE body handed the tilde straight to `xschem raw read`,
#     whose `extra_rawfile()` only runs Tcl `subst` and has never expanded `~`
#     (measured: `raw_read(): failed to open file ~/... for reading`), so PRE
#     landed in ARM 5. The door normalises first (`results::_engine_spelling`,
#     src/results.tcl:475-486) and `raw select` expands `^~/` itself as of item
#     3's fixer round (src/save.c:2408-2416) -- two independent expanders -- so
#     POST loads. RULED ACCEPTABLE as R501c divergence 5: it is a correctness
#     gain, and `wviewer::rawbar_commit` passes the combobox text verbatim, so
#     a user typing `~/sim/foo.raw` and pressing Return reaches it.
#
#     ⚠ NOTHING IS WRITTEN UNDER $HOME BY THIS BLOCK. The fixture is the scratch
#     `an.raw` that already exists, merely RE-SPELLED through `~` because the
#     repo happens to live under $HOME; no file is created there. The guard is
#     what makes that honest -- a tree outside $HOME cannot spell this path at
#     all, and creating one under $HOME to force it would be exactly the class
#     of damage CREW_BRIEF.md section 3 is about.
set an7abs  [file normalize $tmp/an.raw]
set an7home $::env(HOME)/
if {[string first $an7home $an7abs] == 0} {
  set an7t "~/[string range $an7abs [string length $an7home] end]"
  set an7p [am_run PRE  $am_tok $an7t 1 {}]
  set an7q [am_run POST $am_tok $an7t 1 {}]
  # the third term is the anti-vacuity one: `file isfile` says yes to the tilde
  # in both bodies, so PRE's refusal is the ENGINE's and not arm 3's.
  eqcheck SEL337-AN-d6-pre-refused-a-tilde-path \
    [list [dict get $an7p rc] [llength [dict get $an7p after]] [dict get $an7p mru] \
          [dict get $an7p stat] [file isfile $an7t]] \
    [list 0 0 {} {{Location: could not read 'an.raw'}} 1]
  eqcheck SEL338-AN-d6-post-loads-a-tilde-path \
    [list [dict get $an7q rc] [llength [dict get $an7q after]] [dict get $an7q mru] \
          [dict get $an7q stat] [dict get $an7q cur]] \
    [list 1 1 [::list $an7abs] {} $an7abs]
}

# --- R501a: THE SENTENCE IS NOT EMITTED TWICE. `host none` makes
#     results::select compose its sentence into `msg` and emit NOTHING, so the
#     sidebar sees exactly one string and it is the Location bar's. Driven
#     positively as well: the same select WITH a token and NO `host` does emit,
#     so the suppression is the option and not an accident of the harness.
rename wviewer::browser_status {}
proc wviewer::browser_status {token msg} { lappend ::an_e $msg ; return 1 }
xschem raw clear
loadcell $tmp/cellA.sch
set ::an_e {}
pcall results::select $tmp/an.raw {} [list token $am_tok host none]
set an6a $::an_e
xschem raw clear
loadcell $tmp/cellA.sch
set ::an_e {}
pcall results::select $tmp/an.raw {} [list token $am_tok]
set an6b $::an_e
rename wviewer::browser_status {}
proc wviewer::browser_status {token msg} {
  lappend ::am_stat $msg ; lappend ::am_trace status ; return 1
}
# The FOURTH term is the POSITIVE one and it is what keeps this check out of
# the vacuous band: the first three are true of item 4's proc on its own, so
# they were green before this item existed. `host none` reaching the door from
# HERE is the part item 5 added -- and the pattern matches the LIST
# CONSTRUCTION, not the two words: a first version grepped for `host none` and
# was satisfied by the comment three lines above the call, so the sabotage that
# removed the option left it green.
eqcheck SEL331-AN-host-none-suppresses-the-doors-own-sentence \
  [list $an6a [llength $an6b] [string match {Selected an.raw*} [lindex $an6b 0]] \
        [regexp {::list token \$token host none} [info body wviewer::rawbar_load]]] {{} 1 1 1}

# --- T-J's BORROW HALF, RULED (R501b) AND PINNED BY GREP. `switch_ctx` is a
#     MOVE, not an `enter_ctx` borrow TICKET: the ticket idiom is not in this
#     path at all, and R302e put none into `results::select` either. So the
#     refusal T-J is about cannot arise here, and SEL319 is the reason it could
#     not be misreported if it did.
#     The FOURTH term is the positive one: the first three were already true of
#     the pre-item body, and the ruling is about the path AS RE-EXPRESSED.
eqcheck SEL332-AN-tj-no-borrow-ticket-in-this-path \
  [list [regexp {enter_ctx|leave_ctx} [info body wviewer::rawbar_load]] \
        [regexp {switch_ctx} [info body wviewer::rawbar_load]] \
        [regexp {enter_ctx|leave_ctx} [info body results::select]] \
        [regexp {results::select} [info body wviewer::rawbar_load]]] {0 1 0 1}

# --- restore every shim, and prove it BY BODY.
rename wviewer::rawbar_load_PRE {}
foreach am_p $am_leaves {
  rename wviewer::$am_p {}
  rename am_orig_$am_p wviewer::$am_p
}
rename write_recent_file {}
rename am_orig_write_recent_file write_recent_file
set ::wviewer::rawhist $am_hist_old
if {$am_urf_had} { set ::update_recent_files $am_urf_old } else { unset ::update_recent_files }
dict unset ::wviewer::windows $am_tok
set am_restored {}
foreach am_p $am_leaves {
  if {[info body wviewer::$am_p] ne [dict get $am_bodies $am_p]} { lappend am_restored $am_p }
}
if {[info body write_recent_file] ne $am_wrf_body} { lappend am_restored write_recent_file }
eqcheck SEL333-AN-every-shim-restored-by-body \
  [list $am_restored [info procs ::wviewer::rawbar_load_PRE] \
        [dict exists $::wviewer::windows $am_tok] \
        [expr {$::wviewer::rawhist eq $am_hist_old}]] {{} {} 0 1}


# ===========================================================================
# AO -- ITEM 6: `viewer.rawfile` IS FINALLY WRITTEN (R601-R605, R602a, R604a).
#      doc/claude/specs/results_selection.md section 8, invariants T-E and T-F.
#
#      The READ side of the selection's persistence was complete, covered by
#      test_ase_persist G10/G11 and correct from item 14 onwards. NOTHING HAD
#      EVER WRITTEN THE SLOT: `wviewer::snapshot` hardcoded `rawfile {}`. This
#      group pins the WRITE side's machinery -- the recorder, the reader, the
#      two-source rule and the two re-expressed readers. T-F's end-to-end round
#      trip and T-E's restore arms live in `tests/headless/test_ase_persist.tcl`
#      (G7/G8/G10/G11/G11b + the always-running R6 group), because they need a
#      real run and a real Save State.
# ===========================================================================
set ao_tok ao_win_[pid]
set ao_sel_had [info exists ::wviewer::selected($ao_tok)]
catch {unset ::wviewer::selected($ao_tok)}

# ---- the RECORDER. `results::persist` stopped being a no-op stub: it records
#      the user's choice for the window, and it DECLINES when there is no window
#      or session to record it against -- which is what a headless
#      `results::select $p $t {}` is, and why SEL269 above still reads 0.
eqcheck SEL339-AO-persist-declines-without-a-window \
  [list [pcall results::persist /x/y.raw tran {}] \
        [pcall results::persist {} tran [::list token $ao_tok]] \
        [info exists ::wviewer::selected($ao_tok)]] {0 0 0}
eqcheck SEL340-AO-persist-records-under-token-and-under-key \
  [list [pcall results::persist /x/y.raw tran [::list token $ao_tok]] \
        [pcall wviewer::selected_rawfile $ao_tok] \
        [pcall results::persist /x/z.raw dc [::list key $ao_tok]] \
        [pcall wviewer::selected_rawfile $ao_tok]] \
  [::list 1 {/x/y.raw tran} 1 {/x/z.raw dc}]
# `token` OUTRANKS `key`: a viewer window is a narrower statement about where
# the selection happened than a session is, and results::select passes both
# whenever the caller gave both.
catch {unset ::wviewer::selected($ao_tok)}
eqcheck SEL341-AO-token-outranks-key \
  [list [pcall results::persist /x/tok.raw tran \
           [::list token $ao_tok key ao_other_key]] \
        [info exists ::wviewer::selected(ao_other_key)] \
        [pcall wviewer::selected_rawfile $ao_tok]] \
  [::list 1 0 {/x/tok.raw tran}]

# ---- THE TWO-SOURCE RULE (R602a). The ENGINE is primary and the recorded
#      choice is only the fallback, because a remembered selection goes stale
#      and the engine never does: the RUN path (`ase::attach_dbs`) is section
#      18's deliberate bypass of R303, so it records nothing at all -- which is
#      exactly the flow T-F's round trip runs through.
#
#      `enter_ctx` is given a `win_path` that IS the current one, so its "already
#      there" fast path (src/wave_viewer.tcl) returns a granted ticket with
#      nothing to restore. That exercises the ENGINE arm with no context switch
#      and no viewer window -- the borrow itself is proven in the viewer's own
#      suites, not re-proven here.
xschem raw clear
loadcell $tmp/cellA.sch
xschem raw read $tmp/an.raw tran
set ao_wp [pcall xschem get current_win_path]
dict set ::wviewer::windows $ao_tok win_path $ao_wp
catch {unset ::wviewer::selected($ao_tok)}
eqcheck SEL342-AO-the-engine-answers-when-it-can \
  [list [pcall wviewer::selected_rawfile $ao_tok] \
        [info exists ::wviewer::selected($ao_tok)]] \
  [::list [::list $tmp/an.raw tran] 0]
# ...and it OUTRANKS a stale recorded choice. This is the check that goes red if
# a later edit ever prefers the record: the record here names a file that is not
# even loaded.
eqcheck SEL343-AO-a-stale-record-does-not-beat-the-engine \
  [list [pcall results::persist /x/stale.raw dc [::list token $ao_tok]] \
        [pcall wviewer::selected_rawfile $ao_tok]] \
  [::list 1 [::list $tmp/an.raw tran]]
# ...and the record IS used in the one state the engine cannot answer: F4, a
# result selected while standing on another schematic, where results::current
# correctly returns {} (R305 -- a loaded-but-blind database is not a selection)
# and the user's own choice would otherwise not survive the save.
loadcell $tmp/cellB.sch
eqcheck SEL344-AO-F4-falls-back-to-the-recorded-choice \
  [list [pcall results::current] [pcall wviewer::selected_rawfile $ao_tok]] \
  [::list {} {/x/stale.raw dc}]
# no window and no record -> {}, which is what the slot held before this item
# and what the restore side has always handled.
catch {unset ::wviewer::selected($ao_tok)}
dict unset ::wviewer::windows $ao_tok
eqcheck SEL345-AO-nothing-known-is-empty-not-an-error \
  [pcall wviewer::selected_rawfile $ao_tok] {}

# ---- THE WRITER ITSELF. `wviewer::snapshot`'s open arm no longer hardcodes the
#      slot. Source-shape, and it carries its POSITIVE term in the same
#      assertion: the hardcode is gone AND the reader is called AND the key is
#      still in the fixed build order the state file's byte-determinism rests on.
#      ⚠ RESTATED IN THE FIX ROUND, and the restatement is why the pattern is
#      so specific: R602f put a legitimate `rawfile {}` INTO the proc (the
#      default of `[wviewer::dget $prev rawfile {}]`, the previous value it
#      keeps when neither source can answer), so a bare `rawfile \{\}` test now
#      matches the fix instead of the defect. What must be absent is the
#      HARDCODE INSIDE THE `dict create` -- matched by the key that FOLLOWS it
#      in the fixed build order, because `info body` collapses every
#      backslash-newline to a space (measured: the whole `dict create` comes
#      back as ONE line) so the continuation itself cannot be matched on. What
#      must be present is the reader, and the dict taking its value from the
#      variable the reader fed.
set ao_snapbody [info body wviewer::snapshot]
eqcheck SEL346-AO-snapshot-writes-the-slot \
  [list [regexp {rawfile \{\} +graphs} $ao_snapbody] \
        [regexp {wviewer::selected_rawfile \$token} $ao_snapbody] \
        [regexp {rawfile +\$selraw} $ao_snapbody] \
        [regexp {open 1} $ao_snapbody]] {0 1 1 1}

# ---- R602's STORED FORM, and the trap in it. Relative to the rundir when it is
#      UNDER it, absolute otherwise -- decided COMPONENT-WISE. A `string first`
#      prefix test would call `<rundir>bis/x.raw` a child of `<rundir>` and store
#      a relative path that resolves to the wrong file on restore.
set ao_st [dict create rundir $tmp/aorun]
eqcheck SEL347-AO-r602-stored-form \
  [list [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
            [dict create rawfile $tmp/aorun/sub/an.raw] $ao_st] rawfile] \
        [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
            [dict create rawfile ${tmp}/aorunbis/an.raw] $ao_st] rawfile] \
        [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
            [dict create rawfile {}] $ao_st] rawfile x]] \
  [::list sub/an.raw ${tmp}/aorunbis/an.raw {}]

# ---- R605: THE RESTORE PATH COMES THROUGH R303's ONE DOOR, AND ITS
#      CLEAR-THEN-READ ORDER DID NOT MOVE. The order is a measured behaviour
#      that this batch explicitly does NOT change (PLAN.md "Out of this batch");
#      `results::select` never clears (F7), so what must hold is that the
#      viewer's own `raw clear` still precedes the door.
set ao_restbody [info body wviewer::restore]
set ao_iclear [string first {catch {xschem raw clear}} $ao_restbody]
set ao_idoor  [string first {results::select $rawfile $sim_type} $ao_restbody]
eqcheck SEL348-AO-restore-reads-through-the-door-after-the-clear \
  [list [expr {$ao_idoor >= 0 ? 1 : 0}] \
        [expr {$ao_iclear >= 0 ? 1 : 0}] \
        [expr {$ao_iclear >= 0 && $ao_idoor > $ao_iclear ? 1 : 0}] \
        [regexp {xschem raw read \$rawfile} $ao_restbody]] {1 1 1 0}
# ...and it passes `host none` (R802a): the restore's ONE sentence is
# ase::ui::viewer_restore's, through ase::echo (R604). A derived channel here
# would put a second sentence in the viewer sidebar on every session open.
eqcheck SEL349-AO-restore-passes-host-none \
  [regexp {results::select \$rawfile \$sim_type \[::list host none\]|results::select \$rawfile \$sim_type \[list host none\]} \
     $ao_restbody] 1

# ---- R604/R201: `ase::ui::viewer_restore` is re-expressed on the resolver, and
#      the hand-written copy of section 4's two arms is GONE. The behavioural
#      half of this is test_ase_persist's R6 group, which runs on every arm.
set ao_vrbody [info body ase::ui::viewer_restore]
# ⚠ FIX ROUND: element 1 used to be `string first {results::resolve}` over the
# whole body -- and the proc's own COMMENT block contains that literal, so
# replacing the CALL with the verbatim pre-item hand-written arms left it GREEN.
# It now matches the CALL SHAPE on a line of its own, which a comment cannot
# satisfy. (Elements 2 and 3 did catch that revert; this one is now able to.)
eqcheck SEL350-AO-viewer-restore-uses-the-one-resolver \
  [list [regexp {\n\s*set res \[results::resolve} $ao_vrbody] \
        [regexp {file isfile \$vraw} $ao_vrbody] \
        [regexp {ase::last_rawfile \$key} $ao_vrbody]] {1 0 0}

# ---- the per-token array dies with the window, like every other one in
#      wave_viewer.tcl's family. An undeclared `variable` in `wviewer::forget`
#      makes the `unset` address a LOCAL array and leaks one entry per closed
#      window forever -- the file's own repeated ⚠, and the reason `forget` is
#      driven here rather than the `unset` being trusted.
catch {unset ::wviewer::selected($ao_tok)}
eqcheck SEL352-AO-forget-drops-the-recorded-choice \
  [list [pcall results::persist /x/y.raw tran [::list token $ao_tok]] \
        [info exists ::wviewer::selected($ao_tok)] \
        [pcall wviewer::forget $ao_tok] \
        [info exists ::wviewer::selected($ao_tok)]] {1 1 {} 0}


# ===========================================================================
# AO (cont.) -- THE ITEM-6 FIX ROUND. Six defects, one per confirmed finding,
#      each with the drive that reproduced it. Spec R602c-R602f, R605a.
# ===========================================================================

# ---- R602d: AN ALREADY-RELATIVE `viewer.rawfile` IS A FIXED POINT.
#      `file normalize` resolves a relative path against the PROCESS CWD, which
#      is not the rundir and has nothing to do with it. Without the pathtype
#      guard the relativiser re-relativised its OWN OUTPUT -- and it is fed its
#      own output by the ordinary flow, because `ase::ui::viewer_snapshot`
#      passes it whatever `wviewer::snapshot` returned, including the
#      closed-viewer arm's `[dict replace $prev open 0]`.
#      ⚠ THE CWD IS THE WHOLE POINT: measured from <rundir>/sub, `an.raw`
#      became `sub/an.raw`, then `sub/sub/an.raw`, one component per Save
#      State, until the state named a file that does not exist and the read
#      side told the user their result had gone missing. Every suite runs from
#      the repo root, which is never under a scratch rundir, which is exactly
#      why 490 checks were blind to it.
set ao_pwd0 [pwd]
set ao_relrun [file join $tmp aorun]
file mkdir [file join $ao_relrun sub]
set ao_relst [dict create rundir $ao_relrun]
set ao_pwd [pwd]
cd [file join $ao_relrun sub]
set ao_fp1 [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
              [dict create rawfile an.raw] $ao_relst] rawfile]
set ao_fp2 [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
              [dict create rawfile $ao_fp1] $ao_relst] rawfile]
set ao_fp3 [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
              [dict create rawfile $ao_fp2] $ao_relst] rawfile]
# ...and the ABSOLUTE input still relativises from the same cwd, so the guard
# did not simply switch the proc off.
set ao_fpabs [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
              [dict create rawfile [file join $ao_relrun sub an.raw]] $ao_relst] rawfile]
cd $ao_pwd
eqcheck SEL353-AO-r602d-already-relative-is-a-fixed-point \
  [::list $ao_fp1 $ao_fp2 $ao_fp3 $ao_fpabs] \
  [::list an.raw an.raw an.raw [file join sub an.raw]]

# ---- R602c: THE SLOT IS ABSOLUTE BECAUSE IT IS MADE ABSOLUTE, not because the
#      engine happens to answer absolutely. The registry keeps the spelling it
#      was handed -- measured right here: read `an.raw` from its own directory
#      and `xschem raw rawfile` answers `an.raw`. A relative spelling in the
#      state file means "under the rundir" and nothing else, so it would name
#      the wrong file (or no file) on restore.
xschem raw clear
loadcell $tmp/cellA.sch
set ao_pwd [pwd]
cd $tmp
set ao_relread [pcall xschem raw read an.raw tran]
set ao_engspell [pcall xschem raw rawfile]
dict set ::wviewer::windows $ao_tok win_path [pcall xschem get current_win_path]
catch {unset ::wviewer::selected($ao_tok)}
set ao_absfromeng [pcall wviewer::selected_rawfile $ao_tok]
# ...and the RECORDER absolutises too, on the same rule and for the same reason.
dict unset ::wviewer::windows $ao_tok
catch {unset ::wviewer::selected($ao_tok)}
set ao_recrc [pcall results::persist bn.raw tran [::list token $ao_tok]]
set ao_absfromrec [pcall wviewer::selected_rawfile $ao_tok]
cd $ao_pwd
eqcheck SEL358-AO-r602c-a-relative-engine-spelling-is-absolutised \
  [::list $ao_relread $ao_engspell $ao_absfromeng $ao_recrc $ao_absfromrec] \
  [::list 1 an.raw [::list [file join $tmp an.raw] tran] 1 \
          [::list [file join $tmp bn.raw] tran]]
catch {unset ::wviewer::selected($ao_tok)}

# ---- THE WRITER MUST ANSWER *THE SELECTED* RESULT, NOT *A LOADED* ONE. The
#      item's whole claim is the first of those, and with one database loaded
#      the two are indistinguishable -- so this leg loads TWO result-typed raws
#      and switches back to the first. A reader that returned any loaded result
#      (the last one, say) passed all 490 checks of the first round.
xschem raw clear
loadcell $tmp/cellA.sch
set ao_r1 [pcall xschem raw read $tmp/an.raw tran]
set ao_r2 [pcall xschem raw read $tmp/bn.raw tran]
set ao_curB [pcall xschem raw rawfile]
set ao_sw [pcall xschem raw switch $tmp/an.raw tran]
dict set ::wviewer::windows $ao_tok win_path [pcall xschem get current_win_path]
eqcheck SEL354-AO-the-writer-answers-the-CURRENT-of-two-results \
  [::list $ao_r1 $ao_r2 $ao_curB $ao_sw [pcall wviewer::selected_rawfile $ao_tok]] \
  [::list 1 1 $tmp/bn.raw 1 [::list $tmp/an.raw tran]]
dict unset ::wviewer::windows $ao_tok

# ---- R602e: THE RUNDIR IS QUERIED, `ase::rundir` IS NOT CALLED. That proc is a
#      create-and-default helper: it `file mkdir`s the rundir a state names, and
#      for the far commoner EMPTY rundir it falls through to `set_netlist_dir 0`,
#      which creates `$USER_CONF_DIR/simulations` and rewrites the global
#      `::netlist_dir`. A Save State may do neither. Proved by SHIMMING
#      `ase::rundir` to a counter that returns {}: the count must stay 0, and
#      the state that DOES name a rundir must still relativise -- which it can
#      only do by reading the key itself.
set ao_rd_body [info body ase::rundir]
rename ase::rundir ao_orig_rundir
set ::ao_rd_calls 0
proc ase::rundir {state} { incr ::ao_rd_calls ; return {} }
set ao_nord [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
               [dict create rawfile [file join $ao_relrun sub an.raw]] \
               [dict create rundir {}]] rawfile]
set ao_yesrd [ase::state_get [pcall ase::ui::viewer_rawfile_relative \
               [dict create rawfile [file join $ao_relrun sub an.raw]] \
               $ao_relst] rawfile]
rename ase::rundir {}
rename ao_orig_rundir ase::rundir
eqcheck SEL355-AO-r602e-no-rundir-means-no-relativisation-and-no-ase-rundir \
  [::list $ao_nord $ao_yesrd $::ao_rd_calls \
          [expr {[info body ase::rundir] eq $ao_rd_body}]] \
  [::list [file join $ao_relrun sub an.raw] [file join sub an.raw] 0 1]

# ---- R602b's WIRING, on the ALWAYS-RUNNING arm. The relativisation itself is
#      pinned by SEL347/SEL353, but until this check the only thing asserting it
#      was WIRED INTO the save path was test_ase_persist's G7/G10 -- the display
#      + ngspice legs, i.e. exactly the ones spec section 12 warns can be green
#      by not having run. This drives the production entry point,
#      `ase::ui::viewer_snapshot`, over shimmed session state.
#
#      Leg 1: an absolute path under the rundir is folded in RELATIVE, rc 1.
#      Leg 2: THE FIXED POINT THROUGH THE REAL DOOR, from a cwd under the
#             rundir, with `wviewer::snapshot` returning the closed arm's own
#             `[dict replace $prev open 0]` shape. Three consecutive Save States
#             must leave the stored name alone AND must not dirty the session
#             (rc 0) -- the compounding regression showed up as `sub/an.raw`,
#             `sub/sub/an.raw`, `sub/sub/sub/an.raw` with rc 1 every time.
set ao_ss_body [info body ase::session_state]
set ao_su_body [info body ase::session_update]
set ao_sn_body [info body wviewer::snapshot]
rename ase::session_state  ao_o_ss
rename ase::session_update ao_o_su
rename wviewer::snapshot   ao_o_snap
proc ase::session_state {key} { return $::ao_ws_st }
proc ase::session_update {key st} { set ::ao_ws_st $st ; incr ::ao_ws_upd ; return 1 }
proc wviewer::snapshot {token prev} { return $::ao_ws_vd }
set ::ao_ws_upd 0
set ::ao_ws_st [dict create rundir $ao_relrun viewer {}]
set ::ao_ws_vd [dict create open 1 sharedx 0 rawfile [file join $ao_relrun sub w.raw] \
                  graphs {} mode single target 0]
set ao_wrc [pcall ase::ui::viewer_snapshot ao_ws_key]
set ao_wstored [ase::state_get [ase::state_get $::ao_ws_st viewer] rawfile]
# leg 2 -- the closed arm's pass-through, three times, cwd UNDER the rundir
rename wviewer::snapshot {}
proc wviewer::snapshot {token prev} { return [dict replace $prev open 0] }
set ao_pwd [pwd]
cd [file join $ao_relrun sub]
set ao_fixrc {}
set ao_fixstored {}
for {set ao_i 0} {$ao_i < 3} {incr ao_i} {
  lappend ao_fixrc [pcall ase::ui::viewer_snapshot ao_ws_key]
  lappend ao_fixstored [ase::state_get [ase::state_get $::ao_ws_st viewer] rawfile]
}
cd $ao_pwd
rename wviewer::snapshot {} ; rename ao_o_snap wviewer::snapshot
rename ase::session_state {} ; rename ao_o_ss ase::session_state
rename ase::session_update {} ; rename ao_o_su ase::session_update
eqcheck SEL359-AO-r602b-the-save-path-really-folds-in-the-relative-form \
  [::list $ao_wrc $ao_wstored $ao_fixrc $ao_fixstored $::ao_ws_upd \
          [expr {[info body ase::session_state] eq $ao_ss_body \
              && [info body ase::session_update] eq $ao_su_body \
              && [info body wviewer::snapshot] eq $ao_sn_body}]] \
  [::list 1 [file join sub w.raw] {1 0 0} \
          [::list [file join sub w.raw] [file join sub w.raw] [file join sub w.raw]] 2 1]

# ---- R602f: A SAVE NEVER *ERASES* THE STORED SELECTION. When neither source
#      can answer -- the engine blind or its ticket refused, AND no choice
#      recorded -- the PREVIOUS dict's value is kept rather than overwritten
#      with {}. Measured on a real viewer window with no raw loaded in its
#      context: one Save State turned a stored `my_chosen.raw` into {}. And
#      R602a's fallback does NOT cover it, because a selection restored FROM a
#      state file has no record behind it: `wviewer::restore` passes neither
#      `token` nor `key` to the door, so `results::persist` declines.
#      Only `window_for` and `browser_state` are shimmed: everything else on
#      snapshot's open arm answers a sane default for an unknown token
#      (measured), and shimming what already works would only hide it.
set ao_wf_body [info body wviewer::window_for]
set ao_bs_body [info body wviewer::browser_state]
set ao_sr_body [info body wviewer::selected_rawfile]
rename wviewer::window_for       ao_o_wf
rename wviewer::browser_state    ao_o_bs
rename wviewer::selected_rawfile ao_o_sr
proc wviewer::window_for {token} { return .ao_fake_top }
proc wviewer::browser_state {token} { return {} }
proc wviewer::selected_rawfile {token} { return $::ao_sr_answer }
set ao_prev [dict create open 1 sharedx 0 rawfile my_chosen.raw graphs {} \
               mode single target 0]
set ::ao_sr_answer {}
set ao_kept  [wviewer::dget [pcall wviewer::snapshot $ao_tok $ao_prev] rawfile MISSING]
set ao_kept0 [wviewer::dget [pcall wviewer::snapshot $ao_tok {}] rawfile MISSING]
set ::ao_sr_answer [::list /x/fresh.raw tran]
set ao_fresh [wviewer::dget [pcall wviewer::snapshot $ao_tok $ao_prev] rawfile MISSING]
rename wviewer::window_for {}       ; rename ao_o_wf wviewer::window_for
rename wviewer::browser_state {}    ; rename ao_o_bs wviewer::browser_state
rename wviewer::selected_rawfile {} ; rename ao_o_sr wviewer::selected_rawfile
eqcheck SEL357-AO-r602f-a-save-never-erases-the-stored-selection \
  [::list $ao_kept $ao_kept0 $ao_fresh \
          [expr {[info body wviewer::window_for] eq $ao_wf_body \
              && [info body wviewer::browser_state] eq $ao_bs_body \
              && [info body wviewer::selected_rawfile] eq $ao_sr_body}]] \
  [::list my_chosen.raw {} /x/fresh.raw 1]

# ---- R605a: A SESSION RESTORE IS A SELECTION FOR THE MRU, and it is ASSERTED.
#      R605 moved `wviewer::restore`'s attach onto `results::select`, and the
#      door pushes the attached path into the persisted MRU unconditionally --
#      so merely RE-OPENING a saved session now writes
#      `$USER_CONF_DIR/raw_history`, which the bare `xschem raw read` it
#      replaced never did. That is KEPT (0216's shape: the one durable list
#      should carry the results the user actually worked with) and it is bounded
#      (`rawhist_add` dedupes on the normalised path and caps at 20, so
#      re-opening the same session writes once). It is pinned here because this
#      batch has destroyed two $HOME files by leaving a writer's reachability
#      unasserted -- the third such change may not go unchecked.
#
#      ⚠ EVERY WRITER THE FLAG UNGATES IS SHIMMED **BEFORE** THE FLAG IS RAISED,
#      the flag is raised around the SINGLE call under test and never across the
#      `loadcell`, and `::wviewer::rawhist` is saved and restored. CREW_BRIEF
#      section 3 is two incidents' worth of damage written down.
set ao_urf_had [info exists ::update_recent_files]
if {$ao_urf_had} { set ao_urf_old $::update_recent_files }
set ao_hist_old $::wviewer::rawhist
set ao_wrf_body [info body write_recent_file]
set ao_rhw_body [info body wviewer::rawhist_write]
rename write_recent_file      ao_o_wrf
rename wviewer::rawhist_write ao_o_rhw
proc write_recent_file {} { return }
proc wviewer::rawhist_write {} { return 1 }
set ::update_recent_files 0
xschem raw clear
loadcell $tmp/cellA.sch
set ::wviewer::rawhist {}
set ::update_recent_files 1
set ao_selr [pcall results::select $tmp/an.raw tran [::list host none]]
set ao_selr2 [pcall results::select $tmp/an.raw tran [::list host none]]
set ::update_recent_files 0
set ao_mru_now $::wviewer::rawhist
rename write_recent_file {}      ; rename ao_o_wrf write_recent_file
rename wviewer::rawhist_write {} ; rename ao_o_rhw wviewer::rawhist_write
set ::wviewer::rawhist $ao_hist_old
if {$ao_urf_had} { set ::update_recent_files $ao_urf_old } else { unset ::update_recent_files }
eqcheck SEL356-AO-r605a-a-restore-shaped-selection-moves-the-mru \
  [::list [expr {[lsearch [results::_get $ao_selr did] mru] >= 0 ? 1 : 0}] \
          $ao_mru_now \
          [expr {[lsearch [results::_get $ao_selr2 did] mru] >= 0 ? 1 : 0}] \
          [expr {[info body write_recent_file] eq $ao_wrf_body \
              && [info body wviewer::rawhist_write] eq $ao_rhw_body}]] \
  [::list 1 [::list [file normalize $tmp/an.raw]] 0 1]

catch {unset ::wviewer::selected($ao_tok)}
catch {unset ::wviewer::selected(ao_other_key)}
dict unset ::wviewer::windows $ao_tok
# ...and the fix round's own droppings: the cwd it changed three times, the MRU
# list it emptied, and every proc it renamed away. `::wviewer::rawhist` is the
# one this batch has already destroyed on disk twice, so it is asserted here,
# not assumed from a green suite.
eqcheck SEL351-AO-no-per-token-leak-left-behind \
  [list [info exists ::wviewer::selected($ao_tok)] \
        [dict exists $::wviewer::windows $ao_tok] \
        [expr {[pwd] eq $ao_pwd0}] \
        [expr {$::wviewer::rawhist eq $ao_hist_old}] \
        [info procs ao_o_wrf] [info procs ao_o_rhw] [info procs ao_o_ss] \
        [info procs ao_o_snap] [info procs ao_o_wf] [info procs ao_orig_rundir]] \
  {0 0 1 1 {} {} {} {} {} {}}


# ===========================================================================
# ITEM 9 -- T-K, SECOND HALF: NO BY-WORD PARSER OF `xschem raw info` SURVIVES.
# Issue 0507, spec results_selection.md R304 / R304c. Group AP, SEL459..SEL474.
# Band measured free 2026-08-20:
#   grep -hoE 'SEL[0-9]+' tests/headless/*.tcl | sed s/SEL// | sort -n | tail -1
# -> 458 (test_waves_gate, item 8) at first draft; SEL472-SEL474 were added in
# the fixer round with the same command re-run (-> 471). No existing id is
# renumbered or restated.
#
# WHAT T-K IS NOT. LINE-wise readers already exist and every one of them is
# legitimate -- wviewer::rawinfo_parse (src/wave_viewer.tcl:2393),
# ase::raw_indices (src/ase.tcl:2935), ase::raw_current (:2943), the inline
# per-line regexp in ase.tcl's gesture path (:3241-3245, a FIFTH reader; SEL466
# pins the four NAMED procs, it does not claim there are only four), and the
# helpers in this and other test files. "Exactly one parser" is NOT the
# assertion and a check asserting it would be wrong. The assertion is about the
# by-WORD idiom.
#
# THE DETECTOR RUNS ON COMMENT-STRIPPED SOURCE, ON PURPOSE. Item 2's SEL82 was
# satisfied by a comment that merely NAMED rawinfo_parse while a hand-rolled
# parser ran underneath it, and item 8 hit the same class again. Every file in
# scope here -- this one included -- describes the dead idiom in prose, so a
# detector that read comments would be permanently red for the wrong reason.
# WHOLE-LINE `#` AND TRAILING `;#` ARE BOTH STRIPPED. The fixer round measured
# that only the whole-line form was: `set rows [results::list] ;# NOT the old
# foreach {n f t} [lrange [xschem raw info] 2 end]` -- prose of exactly the kind
# this batch has now written into five files -- was scanned as live code and
# made SEL461/SEL462 red for a file that carried no parser at all.
#
# DECLARED LIMITS (spec R304c). This is a GREP TEST over a fixed set of shapes,
# not a static analyser. Two holes are NAMED rather than hidden:
#   * a proc that took the blob as a PARAMETER and split it by word inside its
#     body evades it -- there is no `xschem raw info` on any line of it;
#   * the captured-variable arms are PROC-SCOPED (see the reset below), so a
#     capture at file scope whose by-word consumption sits after an intervening
#     `proc` line evades them. That scoping is deliberate and was measured: the
#     names actually captured in this tree are `info` and `txt`, and without the
#     reset any later unrelated `lrange $txt ...` anywhere in the remaining
#     ~12,500 lines of wave_viewer.tcl reddened SEL461 and named the wrong file.
# ===========================================================================

# the by-word detector. Shapes:
#   (a) a WORD-range taken over the blob itself -- `lrange [xschem raw info] 2 end`.
#       The negative lookahead is load-bearing and was measured: without it,
#       `lrange [split [xschem raw info] "\n"] 1 end-1` -- a LINE-range over
#       already-split lines, used by four headless suites and entirely correct --
#       matched, and the check was red for four innocent files.
#   (b) a THREE-variable foreach whose list operand IS the blob. Three variables
#       is the signature: it is what assumes "every slot is exactly three words",
#       which is the assumption a path containing a space breaks (0507).
#   (c) the TWO-LINE form: the blob captured WHOLE into a variable (no split, no
#       rawinfo_parse) and then consumed by word. This is the shape the removed
#       proc actually had.
#   (d) the same capture consumed by INDEX or LENGTH instead of by `foreach` --
#       `llength $blob` / `lindex $blob $i` / `lreplace $blob 0 1` /
#       `lassign $blob i p t`. Added in the fixer round: (c) covered only the
#       `foreach`/`lrange` consumers, so 0507's defect rewritten as a
#       `for {set i 2} {$i < [llength $blob]} {incr i 3}` index walk -- the shape
#       a person reaches for without `foreach`, and one a reviewer planted in
#       src/xschem.tcl to prove it -- left the suite 374/374 ALL PASS. A whole-
#       blob `llength`/`lindex` is a by-word read BY DEFINITION: every legitimate
#       reader splits on "\n" first, and `lindex [split $txt "\n"] 0` does not
#       match these arms (measured -- ase::raw_current does exactly that and
#       stays silent).
proc t9_byword {text} {
  set hits {}
  set wordy {}
  foreach line [split $text "\n"] {
    set l [string trim $line]
    if {[string index $l 0] eq "#"} continue
    # ...and the TRAILING comment, which Tcl starts at `;#`. Guarded to `;\s*#`
    # rather than a bare `#` so a `#` inside a braced/quoted argument survives.
    regsub {;\s*#.*$} $l {} l
    # a captured blob is a LOCAL: it does not survive into the next proc. Without
    # this the taint on `info`/`txt` ran to end of file and named innocent files.
    if {[regexp {^proc\s} $l]} { set wordy {} }
    set hit 0
    if {[regexp {lrange\s+\[(?![^\]]*split)[^\]]*raw\s+info} $l]} { set hit 1 }
    if {[regexp {foreach\s+\{\s*[A-Za-z_]\w*\s+[A-Za-z_]\w*\s+[A-Za-z_]\w*\s*\}[^\n]*raw\s+info} $l]} { set hit 1 }
    foreach v $wordy {
      if {[regexp "foreach\\s+\\{\\s*\[A-Za-z_\]\\w*\\s+\[A-Za-z_\]\\w*\\s+\[A-Za-z_\]\\w*\\s*\\}\\s+\\\$${v}\\M" $l]} { set hit 1 }
      if {[regexp "l(range|index|length|replace|assign)\\s+\\\$${v}\\M" $l]} { set hit 1 }
    }
    if {$hit} { lappend hits $l }
    if {[regexp {raw\s+info} $l] && ![regexp {rawinfo_parse} $l] && ![regexp {split} $l]} {
      if {[regexp {catch\s*\{[^\}]*raw\s+info[^\}]*\}\s+([A-Za-z_]\w*)} $l -> v]} { lappend wordy $v }
      if {[regexp {set\s+([A-Za-z_]\w*)\s+\[} $l -> v]} { lappend wordy $v }
    }
  }
  return $hits
}
# which FILES the detector fires in, and how often. Reported by tail name so a
# failure names the offender instead of dumping the whole tree.
proc t9_scan {files} {
  set out {}
  foreach f $files {
    set h [t9_byword [r2_rd $f]]
    if {[llength $h]} { lappend out [file tail $f]:[llength $h] }
  }
  return $out
}
# how many times a proc is DEFINED in a file, comments stripped.
proc t9_procdef {text name} {
  set n 0
  foreach line [split $text "\n"] {
    set l [string trim $line]
    if {[string index $l 0] eq "#"} continue
    if {[regexp "^proc\\s+${name}\\M" $l]} { incr n }
  }
  return $n
}
# the LAST `save.c:<a>-<b>` citation carried by the comment block above $anchor.
proc t9_cite {text anchor} {
  set out {}
  foreach line [split $text "\n"] {
    if {[string match "*$anchor*" $line]} break
    if {[regexp {save\.c:(\d+)-(\d+)} $line -> x y]} { set out [list $x $y] }
  }
  return $out
}
# that citation's actual text in save.c, so a check can ask whether it RESOLVES
# rather than whether it merely looks like a citation.
proc t9_savec {root a b} {
  if {$a eq {} || $b eq {}} { return {} }
  set lines [split [r2_rd [file join $root src save.c]] "\n"]
  return [join [lrange $lines [expr {$a - 1}] [expr {$b - 1}]] "\n"]
}
# a citation of the REMOVED proc that still names an xschem.tcl line number.
# There is no line to name any more, so any hit is a dangling pointer.
# ⚠ THE WINDOW IS 200 CHARACTERS EITHER SIDE, NOT THE LINE. Measured: the one
# dangling pointer this item had to fix -- results.tcl's -- wrapped, with
# `raw_is_loaded` ending one comment line and `(src/xschem.tcl:6980)` opening
# the next, so a line-scoped probe was GREEN against the very text it exists to
# catch. That probe shipped in this group's first draft.
proc t9_dangle {text} {
  set hits {}
  set i 0
  while {[set i [string first raw_is_loaded $text $i]] >= 0} {
    set a [expr {$i - 200}] ; if {$a < 0} { set a 0 }
    if {[regexp {xschem\.tcl[:# ]*[0-9][0-9][0-9]+} [string range $text $a [expr {$i + 200}]]]} {
      lappend hits [string range $text $i [expr {$i + 40}]]
    }
    incr i 13
  }
  return $hits
}
proc t9_lineof {text pat} {
  set n 0
  foreach line [split $text "\n"] { incr n ; if {[string match $pat $line]} { return $n } }
  return -1
}

set t9_srcs  [lsort [glob -nocomplain [file join $r2_root src *.tcl]]]
set t9_tests [lsort [glob -nocomplain [file join $r2_root tests headless *.tcl]]]
set t9_xtcl  [r2_rd [file join $r2_root src xschem.tcl]]
set t9_wv    [r2_rd [file join $r2_root src wave_viewer.tcl]]
set t9_ase   [r2_rd [file join $r2_root src ase.tcl]]
set t9_res   [r2_rd [file join $r2_root src results.tcl]]

# --- the proc is GONE, in the running binary and in the source -------------
# The runtime half is the one that cannot be satisfied by a comment or by a
# source edit that never reached the interpreter.
eqcheck SEL459-AP-proc-gone-from-the-running-binary [info procs ::raw_is_loaded] {}
# and the source half, with its own positive control: the same probe must find
# a proc that IS still there, or "0 definitions" proves only that the probe is
# broken.
eqcheck SEL460-AP-gone-from-the-source-too \
  [list [t9_procdef $t9_xtcl raw_is_loaded] [t9_procdef $t9_xtcl load_raw]] {0 1}

# --- T-K itself ------------------------------------------------------------
# every shipped .tcl, not just the one the proc lived in: the ruling is that NO
# by-word parser survives, anywhere. The second element guards a glob that
# silently matched nothing -- an empty file list also scans clean.
eqcheck SEL461-AP-no-by-word-parser-in-any-shipped-tcl \
  [list [t9_scan $t9_srcs] [expr {[llength $t9_srcs] >= 20}]] {{} 1}
# ...and the headless suites, which is where a "quick helper" would land next.
eqcheck SEL462-AP-no-by-word-parser-in-the-headless-suites \
  [list [t9_scan $t9_tests] [expr {[llength $t9_tests] >= 100}]] {{} 1}

# --- the detector's own evidence -------------------------------------------
# A detector that finds nothing is not evidence until it has been shown to find
# something. The text below is the REMOVED PROC, carried here as DATA. It is
# byte-verbatim (trailing newline aside) against
# `git show 226302f9:src/xschem.tcl | sed -n '6980,6997p'`, so this is the
# actual code, not a paraphrase of it: two of its lines are hits, which is what
# made SEL461 red on the tree this item started from.
set t9_dead "proc raw_is_loaded {rawfile type} {
  set loaded 0

  set r \[catch \"uplevel #0 {subst \$rawfile}\" res\]
  if {\$r == 0} {
    set rawfile \$res
  } else {
    return \$loaded
  }
  set rawlist \[lrange \[xschem raw info\] 2 end\]
  foreach {n f t} \$rawlist {
    if {\$rawfile eq \$f && \$type eq \$t} {
       set loaded 1
       break
    }
  }
  return \$loaded
}"
eqcheck SEL463-AP-detector-fires-on-the-removed-proc-verbatim \
  [llength [t9_byword $t9_dead]] 2
# ⚠ THE OTHER FIXTURES ARE ASSEMBLED, NOT WRITTEN LITERALLY. SEL462 scans THIS
# FILE too -- deliberately, because "a quick helper in a suite" is exactly where
# the next by-word reader would land -- so a control written as one literal
# source line would make the suite trip its own detector and the honest fix
# would be an exemption. Holding the blob command in a variable keeps
# `foreach {n f t}` and `raw info` off the same SOURCE line while feeding the
# detector byte-for-byte what it would see in real code. (The verbatim removed
# proc above needs no such care: its `set rawlist \[lrange ...` is escaped, so
# the source line is not the idiom while the STRING is.)
set t9_cmd     {xschem raw info}
set t9_inline  "foreach {n f t} \[lrange \[$t9_cmd\] 2 end\] { }"
set t9_var     "set blob \[$t9_cmd\]\nforeach {n f t} \$blob { }"
set t9_ok      "set txt \[$t9_cmd\]\nforeach line \[lrange \[split \$txt \"\\n\"\] 1 end\] { }"
set t9_pp      "set p \[wviewer::rawinfo_parse \[$t9_cmd\]\]"
set t9_cmt     "# foreach {n f t} \[lrange \[$t9_cmd\] 2 end\]"
eqcheck SEL464-AP-detector-fires-on-the-other-two-shapes \
  [list [llength [t9_byword $t9_inline]] [llength [t9_byword $t9_var]]] {1 1}
# and is SILENT on the line-wise idioms that are correct -- the ase.tcl shape,
# the rawinfo_parse shape, and a by-word parse that exists only in a COMMENT.
eqcheck SEL465-AP-detector-silent-on-the-legitimate-readers \
  [list [llength [t9_byword $t9_ok]] [llength [t9_byword $t9_pp]] \
        [llength [t9_byword $t9_cmt]]] {0 0 0}

# --- the three controls the FIXER round added ------------------------------
# Same assembly rule as above: every fixture is built from $t9_cmd so that no
# SOURCE line of this file is the idiom while the STRING handed to the detector
# is byte-for-byte what real code would look like.
#
# (d) POSITIVE -- the INDEX WALK. `graph_raw_present` below is the body a
# reviewer appended to src/xschem.tcl to prove the hole: 0507's defect with no
# `foreach` anywhere in it, and with the first draft's arms it left the suite
# 374/374 ALL PASS. Two of its lines are hits (`llength $blob`, `lindex $blob`).
set t9_walk  "proc graph_raw_present {rawfile type} {\nif {\[catch {$t9_cmd} blob\]} { return 0 }\nset n \[llength \$blob\]\nfor {set i 2} {\$i < \$n} {incr i 3} {\nif {\$rawfile eq \[lindex \$blob \[expr {\$i + 1}\]\]} { return 1 }\n}\nreturn 0\n}"
set t9_lrepl "set blob \[$t9_cmd\]\nforeach {a b c} \[lreplace \$blob 0 1\] { }"
set t9_lass  "set blob \[$t9_cmd\]\nwhile {\[llength \$blob\] > 2} { set blob \[lassign \$blob i p ty\] }"
eqcheck SEL472-AP-detector-fires-on-the-index-walk \
  [list [llength [t9_byword $t9_walk]] [llength [t9_byword $t9_lrepl]] \
        [llength [t9_byword $t9_lass]]] {2 1 1}
# the capture taint is PROC-SCOPED, in both directions. Without the reset the
# name `txt` stayed tainted for the rest of the file and an unrelated later
# `lrange $txt ...` in a DIFFERENT proc reddened SEL461 naming the wrong file
# (measured on a /tmp copy of src/results.tcl and src/wave_viewer.tcl). With
# the reset written too widely -- clearing on every line -- the second element
# goes 0, so this check is not satisfiable by simply disarming arms (c)/(d).
set t9_leak "proc a {} {\nset txt \[$t9_cmd\]\nreturn \[wviewer::rawinfo_parse \$txt\]\n}\nproc b {txt} {\nreturn \[lrange \$txt 0 1\]\n}"
set t9_same "proc a {} {\nset txt \[$t9_cmd\]\nreturn \[lrange \$txt 2 end\]\n}"
eqcheck SEL473-AP-capture-taint-does-not-leak-into-the-next-proc \
  [list [llength [t9_byword $t9_leak]] [llength [t9_byword $t9_same]]] {0 1}
# a TRAILING `;#` comment is stripped too, not just a whole-line one -- SEL465's
# fixture only ever covered the whole-line form, and every file in SEL461/462's
# scope now carries prose about the removed idiom. Third element is the
# over-strip guard, and it is written to BITE: the `#` sits inside a quoted
# argument BEFORE the idiom, so a stripper widened to a bare `#` eats the rest
# of a live line and the hit vanishes. Measured -- with the guard first written
# as a trailing `puts "#$n"` the wider stripper left the suite ALL PASS, which
# is exactly the vacuous control this file exists to avoid.
set t9_cmt2 "set x 1 ;# foreach {n f t} \[lrange \[$t9_cmd\] 2 end\]"
set t9_cmt3 "set rows \[results::list\] ;# NOT the old lrange \[$t9_cmd\] 2 end"
set t9_hash "set msg \"slot #1: \[lrange \[$t9_cmd\] 2 end\]\""
eqcheck SEL474-AP-detector-silent-on-a-trailing-comment \
  [list [llength [t9_byword $t9_cmt2]] [llength [t9_byword $t9_cmt3]] \
        [llength [t9_byword $t9_hash]]] {0 0 1}
# T-K is not "exactly one parser": the four line-wise readers must still BE
# there. A tree with all of them deleted would pass SEL461 too.
eqcheck SEL466-AP-the-line-wise-readers-are-all-still-there \
  [list [t9_procdef $t9_wv wviewer::rawinfo_parse] \
        [t9_procdef $t9_ase ase::raw_indices] \
        [t9_procdef $t9_ase ase::raw_current] \
        [t9_procdef $t9_res results::list]] {1 1 1 1}

# --- 0507's REPRODUCER: the FIXTURE really is hazardous ---------------------
# Item 2's SEL118 already proves the round trip -- a rawfile path with a space
# comes back out of `results::list` whole. What it does NOT measure is that the
# fixture is hazardous in the first place, and that half is what makes T-K's
# grep worth having: the engine's slot line for such a path WORD-SPLITS into
# more fields than the record has, so a reader taking three words per slot
# cannot represent the row at all, whatever it then returns. Measured here on a
# fresh registry, with the space in the DIRECTORY (SEL118 puts one in the file
# name too), so the two fixtures are not the same shape.
xschem raw clear
loadcell $tmp/cellA.sch
set t9_sd [file join $tmp "raw dir"]
file mkdir $t9_sd
set t9_sp [file join $t9_sd an.raw]
file copy -force $tmp/an.raw $t9_sp
set t9_rc   [pcall xschem raw read $t9_sp tran]
set t9_rows [pcall results::list]
set t9_line [string trim [lindex [split [pcall xschem raw info] "\n"] 1]]
eqcheck SEL467-AP-the-slot-line-really-is-0507s-hazard \
  [list $t9_rc [llength $t9_line] [llength $t9_rows] [dg [lindex $t9_rows 0] path]] \
  [list 1 4 1 $t9_sp]

# --- the two citations 0507 filed as ROTTED ---------------------------------
# The warning comment above rawinfo_parse is the only place in the tree that
# records this trap, and both of its pointers had rotted (`src/save.c:1456-1465`
# ~655 lines short, `xschem.tcl:4801` ~2188 lines short). A citation check that
# only matched the shape of a citation would be satisfied by any number, so
# these RESOLVE it: the cited range must contain the printer, and the range the
# comment used to cite must not.
set t9_wvcite [t9_cite $t9_wv {proc wviewer::rawinfo_parse}]
eqcheck SEL468-AP-viewer-save-c-citation-resolves \
  [list [expr {[string first {" current} [t9_savec $r2_root [lindex $t9_wvcite 0] [lindex $t9_wvcite 1]]] >= 0}] \
        [expr {[string first {sim_type ?} [t9_savec $r2_root [lindex $t9_wvcite 0] [lindex $t9_wvcite 1]]] >= 0}] \
        [expr {[string first {" current} [t9_savec $r2_root 1456 1465]] >= 0}]] \
  {1 1 0}
# ase.tcl cites the same blob's format and had rotted the same way
# (`save.c:1469-1477`). Both comments must now name the SAME printer.
# ⚠ THIS CHECK DOES PIN src/save.c LINE NUMBERS, and the first draft's comment
# here claimed the opposite. Measured in the fixer round on a /tmp copy: three
# unrelated lines inserted ABOVE the printer and the cited window stops
# containing `sim_type ?`, so SEL468's and SEL469's resolve elements go red --
# and the `1469 1477` / `1456 1465` negative controls are literals besides.
# That reddening is the POINT: a citation that no longer resolves has rotted
# and must be restated (L9). When save.c moves, re-grep the `what == 4` printer
# in extra_rawfile(), restate the two source comments AND the two literals
# here; do not delete the check.
set t9_asecite [t9_cite $t9_ase {proc ase::raw_indices}]
eqcheck SEL469-AP-ase-cites-the-same-printer-and-it-resolves \
  [list [expr {$t9_asecite eq $t9_wvcite}] \
        [expr {[string first {" current} [t9_savec $r2_root [lindex $t9_asecite 0] [lindex $t9_asecite 1]]] >= 0}] \
        [expr {[string first {" current} [t9_savec $r2_root 1469 1477]] >= 0}]] \
  {1 1 0}
# ...and no comment anywhere in src/ still points a reader at an xschem.tcl LINE
# for a proc that is not there. results.tcl carried exactly that pointer.
set t9_dang {}
foreach f $t9_srcs { if {[llength [t9_dangle [r2_rd $f]]]} { lappend t9_dang [file tail $f] } }
eqcheck SEL470-AP-no-dangling-citation-of-the-removed-proc \
  [list $t9_dang [llength [t9_dangle "# raw_is_loaded (src/xschem.tcl:6980) reads it BY WORD"]]] \
  {{} 1}

# --- the removal is LINE-NEUTRAL -------------------------------------------
# 478 `xschem.tcl:<line>` citations in doc/, src/ and tests/ point BELOW the
# proc's old position, so an 18-line deletion would have staled every one of
# them (spec section 11, L9's twin). The 18-line tombstone that replaced it
# keeps them all valid. 18 is not an arbitrary number: it is the line count of
# the proc it replaced, `git show 226302f9:src/xschem.tcl | sed -n 6980,6997p`.
# ⚠ STATED RELATIVELY, ON PURPOSE. The first draft also pinned `proc waves` at
# 6373 and `proc load_raw` at 16874, and a reviewer showed that ONE unrelated
# comment line added anywhere above line 6373 of a 19,046-line file reddened a
# results-selection suite -- four of the eight prior items in this batch edited
# src/xschem.tcl. Every element below is relative to `proc set_rect_flags`, so
# it survives unrelated edits while still pinning the block exactly:
#   1-2  the 18 lines above `proc set_rect_flags` are ALL comment lines
#        (they were the proc body before) -- reds if one is deleted, because
#        the 19th line up, a blank, is then inside the window;
#   3    the 19th line up is NOT a comment -- reds if the block GROWS, which is
#        the half the two absolute anchors used to carry;
#   4    the block is the tombstone and not some other comment -- it names the
#        proc that is gone.
set t9_setrect [t9_lineof $t9_xtcl {proc set_rect_flags *}]
set t9_xlines [split $t9_xtcl "\n"]
set t9_tomb {}
for {set i [expr {$t9_setrect - 18}]} {$i < $t9_setrect} {incr i} {
  lappend t9_tomb [string index [string trim [lindex $t9_xlines [expr {$i - 1}]]] 0]
}
set t9_above [string index [string trim [lindex $t9_xlines [expr {$t9_setrect - 20}]]] 0]
set t9_tombtxt [join [lrange $t9_xlines [expr {$t9_setrect - 19}] [expr {$t9_setrect - 2}]] "\n"]
eqcheck SEL471-AP-removal-is-line-neutral \
  [list [llength [lsort -unique $t9_tomb]] [lindex [lsort -unique $t9_tomb] 0] \
        [expr {$t9_above ne "#"}] \
        [expr {[string first raw_is_loaded $t9_tombtxt] >= 0}]] \
  {1 # 1 1}
xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_results_select: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
