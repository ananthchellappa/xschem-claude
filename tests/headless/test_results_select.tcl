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
#      `raw_is_loaded`'s own by-word parser dies -- is item 9's.
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
# the shape ase::ui::viewer_restore already implements by hand (ase_window.tcl:3477-3484).
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

xschem raw clear
catch {test_scratch_drop $tmp}
puts "----"
puts "test_results_select: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
