# tests/headless/test_wave_crossdb_trace.tcl — spec §D1: a VCD trace and an
# analog trace in ONE strip, on ONE time axis.
#
# Spec: doc/claude/specs/mixed_signal_signal_browser.md §D (row D1).
#
# THE MECHANISM WAS ALREADY IN C AND IS PROVEN HERE, NOT ASSUMED. One `node=`
# entry may end in `%<rawfile> <sim_type>`; `draw_graph()` (src/draw.c:8185-8215)
# calls `extra_rawfile(2, <rawfile>, <sim_type>, ...)` — switch-only, because
# `autoload` is absent (draw.c:8133) — draws that ONE trace against that DB and
# switches back at the end of the node iteration (draw.c:8438).
#
# What was MISSING was the whole Tcl half:
#   * `wviewer::add_trace` validated against `xschem raw list`, i.e. the CURRENT
#     database only, so a VCD signal was refused unless the user made the VCD
#     current — which then broke every analog trace in the window;
#   * `wviewer::graph_props` never emitted a `%` at all, and `wviewer::regenerate`
#     rebuilds EVERY rect from graph_props — on a window RESIZE, on add_trace, on
#     attach_raw. So a `%` poked onto a rect with `xschem setprop` looked like it
#     worked until anything touched the window. XR5/XR6 below are that landmine.
#
# The legs:
#   P*  PURE (no display): the `%` grammar's safety rules and the emission.
#   XA* ENGINE: two DBs registered at once, the analog one current.
#   XV* VIEWER: the wired path — add_trace accepts a foreign-DB name, the model
#       carries the DB, the RECT carries the suffix, and it SURVIVES regenerate.
#   XR* RENDER: a real PNG of the viewer, pixel-probed. The VCD's own square wave
#       calibrates both axes (its two logic levels give value->y, its edges give
#       time->x) and the analog sine is then required to land where that
#       calibration predicts. If the two traces were NOT on one time axis the
#       sine's peak could not sit on the VCD's first rising edge.
#   PS* PURE: which DATABASES a layout NAMES (the restore fix's oracle).
#   PB* PURE: the browser row id carries the DATABASE, not just the name.
#   XB* the live browser with the SAME SIGNAL NAME in two VCDs.
#   XS* END TO END, IN TWO PROCESSES: save a state carrying a cross-DB trace,
#       reopen it in a fresh xschem, and PIXEL-PROBE that process's canvas.
#   XD* THE JOINT X DOMAIN, spec §D2. This leg used to pin the LIMITATION --
#       `graph_fullxzoom()` never parsed `%` at all, so an auto X window spanned
#       the CURRENT DB's extent only. FIXED in batch F item 8: the window is now
#       the union of the extents of every database contributing a trace to the
#       shared-X strip group. RESTATED here, not deleted: the expectation
#       genuinely inverted. The engine-level cover is the XD leg of
#       tests/headless/test_node_token_split.tcl.
#
# The PS/PB/XB/XS legs are the 2026-08-09 REVIEW ROUND: three defects the §D1
# change itself created (a saved cross-DB trace came back silently blank; the
# browser plotted the lowest-index database rather than the one the user
# clicked; a comment cited a nonexistent issue). See the addendum in
# doc/claude/issues/0305-per-trace-rawfile-is-honoured-by-three-of-six-node-walkers.md.
#
# Fixtures are SYNTHESIZED, deliberately: the machine-local
# ~/.xschem/simulations/{tb_counter_wrapper_ase.raw,counter.vcd} pair is not in
# the repo, and the pair in test_ase_cosim.tcl spans 0..2e-9 (raw) vs 0..2e-10
# (vcd) — a 10x mismatch that demonstrates §D2 but makes a render probe
# meaningless. XA/XV/XR use a MATCHED pair (both 0..2e-9); XD re-uses the
# mismatched shape on purpose.
#
# Standalone repro from the repo ROOT:
#   xvfb-run -a -s "-screen 0 1920x1080x24" \
#     ./src/xschem --pipe -q --nolog --script tests/headless/test_wave_crossdb_trace.tcl
# (add --nogui to run the P*/PS*/PB* and XA* legs only — the XV/XR/XB/XS/XD legs
#  need a window and self-skip with a NOTE, deliberately NOT a `RESULT: SKIP`
#  banner: that banner makes full_audit score the WHOLE FILE as SKIP and discard
#  the ~50 checks that DID run. The XS leg additionally EXECS a second xschem on
#  the same $DISPLAY, so run it under xvfb like everything else.)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }
proc pcall {script} {
  if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
  return $r
}
# value of one `tok=` line out of a rect prop string
proc tokof {props tok} {
  foreach line [split $props "\n"] {
    if {[regexp "^$tok=(.*)\$" $line -> v]} { return $v }
  }
  return {}
}
# `node=` is the ONE multi-line token graph_props emits, so the line-at-a-time
# `tokof` above cannot read it: it stops at the first newline. Read the quoted
# value whole, treating `\"` as a literal (that is exactly the escape the alias
# form relies on).
proc nodelines {props} {
  if {[regexp {(?s)\nnode="((?:[^"\\]|\\.)*)"\n} "\n$props" -> v]} {
    return [split $v "\n"]
  }
  return {}
}

set no_recent_files 1
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
source [file join $here scratch.tcl]
set scratch [test_scratch wvxdb]

set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

proc wr {p s} { set fp [open $p w]; puts -nonewline $fp $s; close $fp }

# an ASCII ngspice transient raw over 0..`tmax`, v(anlg) = one full sine
# (0.5 at t=0, max at tmax/4, min at 3*tmax/4) — the SHAPE is load-bearing for
# the render probe: its extremes coincide with two of the VCD's edges.
proc mkraw {path {tmax 2.0e-9} {n 41}} {
  set body "Title: d1\nDate: Thu Jan  1 00:00:00 2026\nPlotname: Transient Analysis\n"
  append body "Flags: real\nNo. Variables: 2\nNo. Points: $n\nVariables:\n"
  append body "\t0\ttime\ttime\n\t1\tv(anlg)\tvoltage\n"
  append body "Values:\n"
  for {set i 0} {$i < $n} {incr i} {
    set t [expr {$i * $tmax / ($n - 1)}]
    set v [expr {0.5 + 0.5 * sin(2 * 3.14159265358979 * $t / $tmax)}]
    append body "$i\t$t\n\t$v\n\n"
  }
  wr $path $body
}
# a 1-bit VCD, `ticks` picoseconds long, toggling at 1/4, 1/2, 3/4 and the end
proc mkvcd {path sig {ticks 2000}} {
  set q [expr {$ticks / 4}]
  wr $path "\$timescale 1ps \$end
\$scope module TOP \$end
 \$scope module m \$end
  \$var wire 1 ! $sig \$end
 \$upscope \$end
\$upscope \$end
\$enddefinitions \$end
#0
0!
#$q
1!
#[expr {2 * $q}]
0!
#[expr {3 * $q}]
1!
#$ticks
0!
"
}

if {[catch {

# ============================================================================
# P* — PURE: the `%` grammar's safety rules and the emitted token
# ============================================================================

# P1: the whole point — an ordinary absolute path is carryable
check "P1 a plain absolute path is safe" [pcall {wviewer::db_path_safe /a/b/c.vcd}] 1
check "P1 a type word is safe"           [pcall {wviewer::db_path_safe vcd}] 1
check "P1 the empty string is NOT"       [pcall {wviewer::db_path_safe {}}] 0

# P2: every hazard, one check each, with the reason it is a hazard.
#   space/tab -> draw.c splits the `%` payload on "\n " and the remainder
#                becomes the sim_type (draw.c:8187-8194)
#   %         -> the field separator itself (find_nth(...,"%",...))
#   "         -> the tokenizer's quote character
#   \ $ [ ] { } -> live through `subst {…}`, applied TWICE
#                (draw.c:8191/8193 then save.c:1649)
foreach {tag bad} [list space "/a b/c.vcd" tab "/a\tb.vcd" pct "/a%b.vcd" \
                        quote "/a\"b.vcd" bslash "/a\\b.vcd" dollar "/a\$b.vcd" \
                        obrack "/a\[b.vcd" cbrack "/a\]b.vcd" \
                        obrace "/a\{b.vcd" cbrace "/a\}b.vcd" newline "/a\nb.vcd"] {
  check "P2 rejected: $tag" [pcall {wviewer::db_path_safe $bad}] 0
}

# P3: db_suffix — absent keys mean "the current DB owns this", which is the ONLY
# case that existed before §D1 and must stay byte-identical
check "P3 no rawfile -> no suffix" \
  [pcall {wviewer::db_suffix [dict create vec x]}] {}
# P4: a HALF suffix is refused. draw_graph substitutes the CURRENT db's sim_type
# when the token has none (draw.c:8194-8195) — for an analog current DB that is
# `tran`, and the VCD switch then fails silently. Worse than no suffix.
check "P4 rawfile without sim_type -> no suffix (never a half suffix)" \
  [pcall {wviewer::db_suffix [dict create vec x rawfile /t/d.vcd]}] {}
check "P4 sim_type without rawfile -> no suffix" \
  [pcall {wviewer::db_suffix [dict create vec x sim_type vcd]}] {}
check "P5 full pair -> %<path> <type>" \
  [pcall {wviewer::db_suffix [dict create vec x rawfile /t/d.vcd sim_type vcd]}] \
  {%/t/d.vcd vcd}
check "P6 an UNSAFE path yields no suffix, not a broken one" \
  [pcall {wviewer::db_suffix [dict create vec x rawfile {/t/d d.vcd} sim_type vcd]}] {}

# P7: THE REGRESSION ORACLE. A current-DB trace still emits a BARE vector name —
# no `%`, no alias, no quotes. Every existing viewer test and all 127 shipped
# schematics with embedded graphs depend on this being untouched.
set G1 [dict create traces [list [dict create vec v(a) name {} color 4]]]
check "P7 current-DB trace emits a bare vec (byte-identical to pre-D1)" \
  [pcall {tokof [wviewer::graph_props $G1] node}] {"v(a)"}

# P8: a cross-DB trace emits the ALIAS form. It MUST be the alias form: draw.c
# hands the WHOLE token to draw_graph_variables for the legend (draw.c:8247), so
# a bare `vec%path type` legends as the absolute path (MEASURED). With the alias,
# the legend is find_nth(ntok,";",..,1) = the display name (draw.c:4424-4425).
set G2 [dict create traces [list \
  [dict create vec TOP.m.siga name {} color 5 rawfile /t/d.vcd sim_type vcd]]]
check "P8 cross-DB trace emits alias;vec%path type" \
  [pcall {tokof [wviewer::graph_props $G2] node}] \
  {"\"TOP.m.siga;TOP.m.siga%/t/d.vcd vcd\""}

# P9: a user display name survives into the alias slot
set G3 [dict create traces [list \
  [dict create vec TOP.m.siga name tc color 5 rawfile /t/d.vcd sim_type vcd]]]
check "P9 a display name wins the alias slot" \
  [pcall {tokof [wviewer::graph_props $G3] node}] \
  {"\"tc;TOP.m.siga%/t/d.vcd vcd\""}

# P10: THE MIXED STRIP as a string — two node lines, two colors, only the
# foreign one suffixed
set G4 [dict create traces [list \
  [dict create vec v(anlg) name {} color 4] \
  [dict create vec TOP.m.siga name {} color 5 rawfile /t/d.vcd sim_type vcd]]]
check "P10 mixed strip line 1: the analog trace stays BARE" \
  [pcall {lindex [nodelines [wviewer::graph_props $G4]] 0}] {v(anlg)}
check "P10 mixed strip line 2: the VCD trace names its own db" \
  [pcall {lindex [nodelines [wviewer::graph_props $G4]] 1}] \
  {\"TOP.m.siga;TOP.m.siga%/t/d.vcd vcd\"}
check "P10 ... exactly two node entries" \
  [pcall {llength [nodelines [wviewer::graph_props $G4]]}] 2
check "P10 ... and one color per trace" [pcall {tokof [wviewer::graph_props $G4] color}] {"4 5"}

# P11: `<NULL>` is `xschem raw info`'s spelling for "this slot has no sim_type"
# (save.c:1780), and extra_rawfile()'s switch arm SKIPS any slot whose sim_type
# is NULL before it ever compares (save.c:1653). A `%path <NULL>` suffix could
# therefore never switch — the half-suffix rule (P4), one spelling further out.
check "P11 a <NULL> sim_type yields no suffix (it could never switch)" \
  [pcall {wviewer::db_suffix [dict create vec x rawfile /t/d.vcd sim_type {<NULL>}]}] {}

# ============================================================================
# PS* — PURE (DEFECT 1's oracle): which databases does a LAYOUT NAME?
#
# `wviewer::restore` re-read ONE database (the session's analog raw) and then
# drew traces whose node= tokens switch to a database it never re-read. The
# switch just fails at dbg(1) and the strip STILL LISTS the signal in its
# legend, so it reads as "that signal is flat" rather than "the data is gone".
# `trace_dbs` is the list restore now has to honour; XS* below proves the whole
# path across two processes.
# ============================================================================
check "PS1 an empty layout names no database" [pcall {wviewer::trace_dbs {}}] {}
set S1 [dict create traces [list [dict create vec v(a) name {} color 4]]]
check "PS2 a CURRENT-db trace names none (the only pre-D1 case)" \
  [pcall {wviewer::trace_dbs [list $S1]}] {}
set S2 [dict create traces [list \
  [dict create vec v(a) name {} color 4] \
  [dict create vec TOP.m.siga name {} color 5 rawfile /t/d.vcd sim_type vcd]]]
check "PS3 a cross-DB trace names its db AND the vec that needs it" \
  [pcall {wviewer::trace_dbs [list $S2]}] {{path /t/d.vcd type vcd vecs TOP.m.siga}}
set S3 [dict create traces [list \
  [dict create vec TOP.m.siga name {} color 5 rawfile /t/d.vcd sim_type vcd] \
  [dict create vec TOP.m.sigb name {} color 6 rawfile /t/d.vcd sim_type vcd]]]
check "PS4 two traces in ONE db -> one entry, both vecs" \
  [pcall {wviewer::trace_dbs [list $S3]}] \
  {{path /t/d.vcd type vcd vecs {TOP.m.siga TOP.m.sigb}}}
set S4a [dict create traces [list \
  [dict create vec A name {} color 5 rawfile /t/a.vcd sim_type vcd]]]
set S4b [dict create traces [list \
  [dict create vec B name {} color 6 rawfile /t/b.vcd sim_type vcd] \
  [dict create vec A2 name {} color 7 rawfile /t/a.vcd sim_type vcd]]]
# ACROSS STRIPS, and deduped across them: a layout with the same VCD on two
# strips must be attached once, and the message must name both signals.
check "PS5 two dbs over two strips: first-appearance order, cross-strip dedupe" \
  [pcall {wviewer::trace_dbs [list $S4a $S4b]}] \
  {{path /t/a.vcd type vcd vecs {A A2}} {path /t/b.vcd type vcd vecs B}}
set S5 [dict create traces [list \
  [dict create vec X name {} color 5 rawfile {/t/d d.vcd} sim_type vcd]]]
check "PS6 a path db_suffix REFUSES names no database (nothing could switch to it)" \
  [pcall {wviewer::trace_dbs [list $S5]}] {}
set S6 [dict create traces [list \
  [dict create vec X name {} color 5 rawfile /t/d.vcd sim_type {<NULL>}]]]
check "PS7 a <NULL> sim_type names no database either" \
  [pcall {wviewer::trace_dbs [list $S6]}] {}

# ============================================================================
# PB* — PURE (DEFECT 2): the tree row id ALREADY says WHICH database
#
# item 14 prefixes every FOREIGN db's rows with `d:<registry idx>|` and leaves
# the current db's rows unprefixed. `browser_leaf_names` threw that half away and
# handed plot_signals/add_trace a bare name, so with the same signal in two VCDs
# a double-click under the blockB header plotted blockA's waveform — and a Plot
# with BOTH rows selected deduped down to ONE trace.
# ============================================================================
check "PB1 an unprefixed row id means the CURRENT db"      [pcall {wviewer::browser_row_db s:v(out)}] {}
check "PB2 a d:2| prefix means registry slot 2"            [pcall {wviewer::browser_row_db {d:2|s:TOP.m.sig}}] 2
check "PB3 a two-digit index parses whole"                 [pcall {wviewer::browser_row_db {d:11|s:x}}] 11
# a GROUP HEADER carries no pipe; only its leaves do. Answering `2` here would
# make browser_row_db disagree with browser_rows_reparent about what a prefix is.
check "PB4 a db header id itself has no prefix"            [pcall {wviewer::browser_row_db d:2}] {}
check "PB5 the empty id is the current db"                 [pcall {wviewer::browser_row_db {}}] {}
check "PB6 a name that merely LOOKS like a prefix is not one" \
  [pcall {wviewer::browser_row_db {s:d:2|x}}] {}

set PBr [pcall {wviewer::browser_rows_multi [list \
  [list d:0 {anlg.raw (tran)} [list [wviewer::signal_entry v(anlg)]] anlg {}] \
  [list d:1 {blockA.vcd (vcd)} [list [wviewer::signal_entry TOP.m.sig]] blockA] \
  [list d:2 {blockB.vcd (vcd)} [list [wviewer::signal_entry TOP.m.sig]] blockB]]}]
check "PB7 the CURRENT db's leaf carries no database (unprefixed rows)" \
  [pcall {wviewer::browser_leaf_specs $PBr d:0}] {{v(anlg) {}}}
check "PB8 the blockA header's leaf carries db 1" \
  [pcall {wviewer::browser_leaf_specs $PBr d:1}] {{TOP.m.sig 1}}
check "PB9 the blockB header's leaf carries db 2 — THE SAME NAME, a different db" \
  [pcall {wviewer::browser_leaf_specs $PBr d:2}] {{TOP.m.sig 2}}
# THE REGRESSION ORACLE for the projection: browser_leaf_names has eight callers
# that genuinely want only names (the Add Trace… dialog fills a TEXT ENTRY,
# which cannot carry a database), and it must keep answering exactly as before.
check "PB10 browser_leaf_names is unchanged (names only, same order)" \
  [pcall {list [wviewer::browser_leaf_names $PBr d:0] \
               [wviewer::browser_leaf_names $PBr d:1] \
               [wviewer::browser_leaf_names $PBr d:2]}] \
  {v(anlg) TOP.m.sig TOP.m.sig}
check "PB11 an unknown row id yields nothing and never throws" \
  [pcall {wviewer::browser_leaf_specs $PBr {d:9|s:nope}}] {}

# ============================================================================
# XA* — ENGINE: both DBs registered at once, the ANALOG one current
# ============================================================================
set rawf [file join $scratch anlg.raw]
set vcdf [file join $scratch d1.vcd]
mkraw  $rawf
mkvcd  $vcdf siga

check "XA1 analog raw reads"  [pcall {xschem raw clear; xschem raw read $rawf tran}] 1
check "XA2 VCD reads"         [pcall {xschem raw read $vcdf vcd}] 1
check "XA3 switch back to the analog DB" [pcall {xschem raw switch 0}] 1
check "XA4 the analog DB is current"     [pcall {xschem raw sim_type}] tran
# XA5: THE KEY the `%` suffix must byte-match. extra_rawfile()'s switch arm does a
# bare strcmp on the STORED path AND the sim_type (save.c:1653-1655), so what
# `xschem raw info` prints is exactly what has to go after the `%`.
set rawinfo [pcall {xschem raw info}]
check_true "XA5 the registry reports the VCD under its FULL path + type vcd" \
  [expr {[string first "$vcdf vcd" $rawinfo] >= 0}]
# XA6: the VCD's signal is NOT in the current DB's list — this is precisely the
# refusal add_trace used to hand the user
check_true "XA6 TOP.m.siga is absent from the CURRENT db's raw list" \
  [expr {[lsearch -exact [split [pcall {xschem raw list}] "\n"] TOP.m.siga] < 0}]

# ============================================================================
# XV* / XR* / XD* — the wired path in a real viewer window
# ============================================================================
if {![info exists ::has_x] || [info commands winfo] eq {}} {
  puts "NOTE: XV/XR/XD legs not run (no DISPLAY; P* and XA* legs above did run)"
} else {

proc viewer_ready {top} {
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
    after 20
  }
  return 0
}

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set st [ase::state_load $statefile]
dict set st rundir [file join $scratch run]
set sstate [file join $scratch session.state]
ase::state_save $sstate $st
set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
ase::session_open $tok $sstate

check "XV0 viewer opens" [pcall {wviewer::open $tok}] 1
set vtop [wviewer::window_for $tok]
set vdrw $vtop.drw
if {![viewer_ready $vtop]} {
  puts "NOTE: XV/XR/XD legs not run (viewer canvas never mapped)"
  catch {wviewer::close $tok}
} else {

# the DBs live per-context: register them in the VIEWER's context
xschem new_schematic switch $vdrw
xschem raw clear
xschem raw read $rawf tran
xschem raw read $vcdf vcd
xschem raw switch 0

# one strip, explicit ranges so the render is deterministic (XD* exercises the
# auto path on purpose)
wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] \
  x1 0 x2 2e-9 y1 -0.3 y2 1.3]]
wviewer::regenerate $tok

# --- XV: the wired add ------------------------------------------------------
check "XV1 an analog name from the CURRENT db is accepted" \
  [pcall {wviewer::add_trace $tok 0 v(anlg) {} 4}] {}
# XV2: THE ITEM. Before this change `xschem raw list` was the whole world and
# this returned "unknown token 'TOP.m.siga' (...)".
check "XV2 a VCD name from a FOREIGN db is accepted (cross-DB validation)" \
  [pcall {wviewer::add_trace $tok 0 TOP.m.siga {} 5}] {}
check "XV3 a name in NO loaded db is still refused" \
  [pcall {wviewer::add_trace $tok 0 v(nosuchnet) {} 6}] \
  {unknown token 'v(nosuchnet)' (not an operator/function, number or raw variable)}

set trs [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 0] traces]
check "XV4 exactly two traces landed" [llength $trs] 2
check "XV4 the analog trace carries NO db keys" \
  [list [dict exists [lindex $trs 0] rawfile] [dict exists [lindex $trs 0] sim_type]] {0 0}
check "XV4 the VCD trace carries the db it was picked from" \
  [pcall {list [dict get [lindex $trs 1] rawfile] [dict get [lindex $trs 1] sim_type]}] \
  [list $vcdf vcd]

xschem new_schematic switch $vdrw
set nd [pcall {xschem getprop rect 2 0 node}]
check "XV5 the RECT's node= carries the analog trace bare" \
  [lindex [split $nd "\n"] 0] {v(anlg)}
check "XV5 ... and the VCD trace with its %<path> <type>" \
  [lindex [split $nd "\n"] 1] "\"TOP.m.siga;TOP.m.siga%$vcdf vcd\""

# --- XR: THE REGENERATE LANDMINE -------------------------------------------
# regenerate rebuilds every rect from graph_props alone. It fires on a window
# RESIZE, on add_trace and on attach_raw, so a `%` written onto a rect by hand
# would die on the first repaint. These two legs are the difference between a
# demo and a feature.
wviewer::regenerate $tok
xschem new_schematic switch $vdrw
set nd2 [pcall {xschem getprop rect 2 0 node}]
check "XR5 the suffix SURVIVES a bare regenerate" \
  [lindex [split $nd2 "\n"] 1] "\"TOP.m.siga;TOP.m.siga%$vcdf vcd\""
# a real resize -> configure_apply -> regenerate, the path a user actually hits
wm geometry $vtop 820x560
update idletasks
after 120
update
catch {wviewer::regenerate $tok}
xschem new_schematic switch $vdrw
set nd3 [pcall {xschem getprop rect 2 0 node}]
check "XR6 the suffix SURVIVES a window RESIZE" \
  [lindex [split $nd3 "\n"] 1] "\"TOP.m.siga;TOP.m.siga%$vcdf vcd\""
# and a third add (regenerate again) leaves trace 1 alone
check "XR7 adding another trace does not disturb it" \
  [pcall {wviewer::add_trace $tok 0 time {} 7}] {}
xschem new_schematic switch $vdrw
check "XR7 ... the VCD line is still line 2 of node=" \
  [lindex [split [pcall {xschem getprop rect 2 0 node}] "\n"] 1] \
  "\"TOP.m.siga;TOP.m.siga%$vcdf vcd\""

# --- XR: THE RENDER ---------------------------------------------------------
# back to the two-trace strip for a clean picture
wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] \
  x1 0 x2 2e-9 y1 -0.3 y2 1.3 traces [lrange $trs 0 1]]]
wviewer::regenerate $tok
xschem new_schematic switch $vdrw
set png [file join $scratch mixed.png]
catch {xschem print png $png 900 500}
update idletasks

# THE PIXEL PROBE. Self-calibrating: the VCD's own square wave supplies BOTH
# axes (its two logic levels are value 0 and value 1; its rising edges are
# t = T/4 and t = 3T/4), and the analog sine is then required to land where that
# calibration says it must. Cross-axis by construction — a sine drawn on a
# DIFFERENT time base could not put its peak on the VCD's first edge.
if {![file exists $png]} {
  puts "NOTE: render probe not run (print png produced no file)"
} else {
  set img [image create photo -file $png]
  set W [image width $img]; set H [image height $img]
  # layer 4 = green-dominant, layer 5 = red-dominant; classify by dominance so
  # the check does not hard-code an RGB triple from the palette
  array set gpx {}; array set rpx {}
  for {set x 0} {$x < $W} {incr x} {
    for {set y 0} {$y < $H} {incr y} {
      lassign [$img get $x $y] r g b
      if {$g > 100 && $r < $g && $b < 60} { lappend gpx($x) $y }
      if {$r > 100 && $g < 90 && $b < 60} { lappend rpx($x) $y }
    }
  }
  image delete $img
  # ⚠ THE THRESHOLD IS RELATIVE ON PURPOSE. The LEGEND text is drawn in the
  # trace's own colour, so "some red pixels exist" is satisfied by the legend
  # alone — MEASURED: with the `%` suffix suppressed, the VCD trace vanished and
  # ~110 red columns of legend text remained, which sailed past a `> 100` bar.
  # A real trace spans the plot, so it must reach at least half the ANALOG
  # trace's column count.
  check_true "XR8 the ANALOG trace is on the canvas" [expr {[array size gpx] > 300}]
  check_true "XR8 the VCD trace is on the canvas TOO (not just its legend)" \
    [expr {[array size rpx] > [array size gpx] / 2}]

  # the VCD's two logic levels = the two most-occupied red rows
  array set rowcount {}
  foreach x [array names rpx] {
    foreach y $rpx($x) { incr rowcount($y) }
  }
  set rows {}
  foreach {y n} [array get rowcount] { lappend rows [list $y $n] }
  set rows [lsort -integer -decreasing -index 1 $rows]
  set yhi [lindex [lindex $rows 0] 0]
  set ylo {}
  foreach e $rows {
    if {abs([lindex $e 0] - $yhi) > 40} { set ylo [lindex $e 0]; break }
  }
  if {$ylo ne {} && $ylo < $yhi} { set t $yhi; set yhi $ylo; set ylo $t }
  check_true "XR9 the VCD renders TWO separated logic levels" \
    [expr {$ylo ne {} && $ylo - $yhi > 40}]

  if {$ylo ne {}} {
    # columns where red spans both levels = the square wave's vertical edges
    set edgecols {}
    foreach x [lsort -integer [array names rpx]] {
      set near_hi 0; set near_lo 0
      foreach y $rpx($x) {
        if {abs($y - $yhi) <= 3} { set near_hi 1 }
        if {abs($y - $ylo) <= 3} { set near_lo 1 }
      }
      if {$near_hi && $near_lo} { lappend edgecols $x }
    }
    # cluster adjacent columns (an edge is 1-3 px wide)
    set edges {}; set run {}
    foreach x $edgecols {
      if {[llength $run] && $x - [lindex $run end] > 3} {
        lappend edges [expr {([lindex $run 0] + [lindex $run end]) / 2}]; set run {}
      }
      lappend run $x
    }
    if {[llength $run]} { lappend edges [expr {([lindex $run 0] + [lindex $run end]) / 2}] }
    puts "  probe: yhi=$yhi ylo=$ylo edges=$edges  (green cols [array size gpx], red cols [array size rpx])"
    check_true "XR10 the VCD square wave shows its 4 transitions" [expr {[llength $edges] >= 4}]

    if {[llength $edges] >= 4} {
      set e0 [lindex $edges 0]   ;# t = T/4  -> the sine's MAXIMUM (value 1)
      set e2 [lindex $edges 2]   ;# t = 3T/4 -> the sine's MINIMUM (value 0)
      # green nearest each edge column, ignoring the legend/axis text by staying
      # inside the value band the VCD just calibrated
      proc gband {arr x yhi ylo} {
        upvar 1 $arr a
        set out {}
        for {set d 0} {$d <= 3} {incr d} {
          foreach xx [list [expr {$x - $d}] [expr {$x + $d}]] {
            if {![info exists a($xx)]} { continue }
            foreach y $a($xx) {
              if {$y >= $yhi - 20 && $y <= $ylo + 20} { lappend out $y }
            }
          }
          if {[llength $out]} { return [lsort -integer $out] }
        }
        return {}
      }
      set g0 [gband gpx $e0 $yhi $ylo]
      set g2 [gband gpx $e2 $yhi $ylo]
      puts "  probe: at edge0 col $e0 green rows=$g0 ; at edge2 col $e2 green rows=$g2"
      # THE JOINT MEASUREMENT: on ONE time axis the sine peaks exactly where the
      # VCD first rises, and bottoms exactly where it rises the second time.
      check_true "XR11 at the VCD's 1st rising edge the analog trace is at its MAXIMUM (value 1)" \
        [expr {[llength $g0] && abs([lindex $g0 0] - $yhi) <= 6}]
      check_true "XR12 at the VCD's 2nd rising edge the analog trace is at its MINIMUM (value 0)" \
        [expr {[llength $g2] && abs([lindex $g2 end] - $ylo) <= 6}]
      # and both traces really do span the same horizontal window
      set gx [lsort -integer [array names gpx]]
      check_true "XR13 both traces end at the same right-hand edge (one time axis)" \
        [expr {abs([lindex $gx end] - [lindex [lsort -integer [array names rpx]] end]) <= 8}]
    }
  }
}

# --- XB: DEFECT 2 — THE SAME SIGNAL NAME IN TWO DATABASES -------------------
# The shape spec §E produces whenever two `d_cosim` blocks instantiate the same
# Verilog module: `TOP.m.sig` exists in blockA.vcd AND blockB.vcd. The browser's
# row id says which one the user clicked; `resolve_signal_db` resolves by NAME
# and returns the LOWEST-index match. Before the fix, a double-click under the
# blockB header plotted blockA's waveform with no error and no cue, and a Plot
# with both rows selected produced ONE trace.
set vcdA [file join $scratch blockA.vcd]
set vcdB [file join $scratch blockB.vcd]
mkvcd $vcdA sig 2000
mkvcd $vcdB sig 1200
xschem new_schematic switch $vdrw
xschem raw clear
xschem raw read $rawf tran
xschem raw read $vcdA vcd
xschem raw read $vcdB vcd
xschem raw switch 0

# the row list the live registry produces, through the REAL row builder — the
# ids under test are the ones browser_refresh emits, not hand-written strings
set xb_groups {}
foreach db [pcall {wviewer::signal_list_all $tok}] {
  set ents {}
  foreach n [dict get $db names] { lappend ents [wviewer::signal_entry $n] }
  set g [list "d:[dict get $db idx]" [dict get $db label] $ents \
              [wviewer::browser_root_label [dict get $db path]]]
  if {[dict get $db cur]} { lappend g {} }   ;# the current db's rows stay unprefixed
  lappend xb_groups $g
}
set xb_rows [pcall {wviewer::browser_rows_multi $xb_groups}]
set ::wviewer::browserrows($tok) $xb_rows
set idA {d:1|s:TOP.m.sig}
set idB {d:2|s:TOP.m.sig}
check "XB1 blockA's row for TOP.m.sig exists" [pcall {wviewer::browser_kind $xb_rows $idA}] leaf
check "XB1 blockB's row for TOP.m.sig exists TOO (same name, two rows)" \
  [pcall {wviewer::browser_kind $xb_rows $idB}] leaf
check "XB2 the two rows differ ONLY in the database they carry" \
  [pcall {list [wviewer::browser_leaf_specs $xb_rows $idA] \
               [wviewer::browser_leaf_specs $xb_rows $idB]}] \
  {{{TOP.m.sig 1}} {{TOP.m.sig 2}}}

proc xb_reset {tok} {
  catch {wviewer::set_plot_mode single $tok}
  wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] \
    x1 0 x2 2e-9 y1 -0.3 y2 1.3]]
  catch {wviewer::set_target_strip 0 $tok}
  wviewer::regenerate $tok
}
proc xb_traces {tok} {
  set out {}
  foreach G [dict get [wviewer::layout_for $tok] graphs] {
    foreach tr [wviewer::dget $G traces {}] { lappend out $tr }
  }
  return $out
}
proc xb_rawfiles {tok} {
  set out {}
  foreach tr [xb_traces $tok] { lappend out [wviewer::dget $tr rawfile {}] }
  return $out
}

# XB3: THE DEDUPE. Both rows selected, one Plot. `browser_plot_ids` deduped on
# the bare NAME, so the second row evaporated.
xb_reset $tok
check "XB3 plotting BOTH rows plots TWO signals, not one" \
  [pcall {wviewer::browser_plot_ids $tok [list $idA $idB]}] 2
check "XB3 ... and two traces really landed" [llength [xb_traces $tok]] 2
check "XB3 ... one from EACH database, in row order" \
  [xb_rawfiles $tok] [list $vcdA $vcdB]

# XB4: THE WRONG DATABASE. One row, under blockB's header. This is the check the
# defect is named for: before the fix it answered blockA's path.
xb_reset $tok
check "XB4 a lone blockB row plots blockB's waveform" \
  [pcall {wviewer::browser_plot_ids $tok [list $idB]}] 1
check "XB4 ... the trace names blockB, not the lowest-index match" \
  [xb_rawfiles $tok] [list $vcdB]
xb_reset $tok
check "XB4 ... and a lone blockA row still plots blockA" \
  [pcall {list [wviewer::browser_plot_ids $tok [list $idA]] [xb_rawfiles $tok]}] \
  [list 1 [list $vcdA]]

# XB5: the seam itself — add_trace's explicit database argument.
xb_reset $tok
check "XB5 add_trace with db=2 resolves in blockB" \
  [pcall {wviewer::add_trace $tok 0 TOP.m.sig {} 5 2}] {}
check "XB5 ... and the trace carries blockB's path + type" \
  [pcall {list [dict get [lindex [xb_traces $tok] 0] rawfile] \
               [dict get [lindex [xb_traces $tok] 0] sim_type]}] [list $vcdB vcd]

# XB6: DECISION 4 IS UNTOUCHED for a caller that has only a name (the Add
# Trace… dialog's text entry, a scripted add). Current db first, then the
# lowest-index other db that has the name.
xb_reset $tok
check "XB6 db={} still resolves by NAME (decision 4 survives)" \
  [pcall {wviewer::add_trace $tok 0 TOP.m.sig {} 5}] {}
check "XB6 ... and that is blockA, the lowest-index match" \
  [xb_rawfiles $tok] [list $vcdA]

# XB7: the CURRENT database named explicitly must stay byte-identical to a
# pre-§D1 trace — no rawfile keys at all, so no `%` in node=.
xb_reset $tok
check "XB7 db=0 (the current db) is accepted" \
  [pcall {wviewer::add_trace $tok 0 v(anlg) {} 4 0}] {}
check "XB7 ... and carries NO db keys (a bare vec, as before §D1)" \
  [pcall {list [dict exists [lindex [xb_traces $tok] 0] rawfile] \
               [dict exists [lindex [xb_traces $tok] 0] sim_type]}] {0 0}

# XB8: an explicit database that does NOT have the name is refused, NAMING the
# database — not silently satisfied from another one.
xb_reset $tok
check "XB8 a name absent from the NAMED db is refused, and says which db" \
  [pcall {wviewer::add_trace $tok 0 TOP.m.sig {} 5 0}] \
  "'TOP.m.sig' is not in [wviewer::db_label $rawf tran] (unknown token 'TOP.m.sig'\
 (not an operator/function, number or raw variable))"
check "XB8 ... and nothing landed" [llength [xb_traces $tok]] 0

# XB9: a STALE index (the row list outlived a `raw clear`) degrades to the name
# search rather than refusing — the rows are describing a registry that moved.
xb_reset $tok
check "XB9 an unresolvable db index falls back to the name search" \
  [pcall {wviewer::add_trace $tok 0 TOP.m.sig {} 5 99}] {}
check "XB9 ... landing on the name rule's answer (blockA)" \
  [xb_rawfiles $tok] [list $vcdA]

# XB10: THE ONE-SHOT DISCIPLINE of the hand-off. The database list reaches
# plot_signals through a namespace arm rather than a 5th argument (that
# signature is pinned by a literal string match in test_wave_sigbrowser.tcl —
# see plot_dbs_arm's ⚠⚠), so the ONLY thing keeping it honest is that
# plot_dbs_take CONSUMES. A list left armed would silently retarget the NEXT
# gesture — a Direct Plot, or the lower pane — at the previous one's database.
xb_reset $tok
wviewer::browser_plot_ids $tok [list $idB]
check "XB10 the armed database list is CONSUMED by the plot it belongs to" \
  [pcall {wviewer::plot_dbs_take $tok}] {}
xb_reset $tok
wviewer::plot_signals $tok [list TOP.m.sig]
check "XB10 ... so the NEXT name-only plot still resolves by NAME (blockA)" \
  [xb_rawfiles $tok] [list $vcdA]

array unset ::wviewer::browserrows $tok
xb_reset $tok
xschem new_schematic switch $vdrw
xschem raw clear
xschem raw read $rawf tran
xschem raw read $vcdf vcd
xschem raw switch 0

# --- XD: THE JOINT X DOMAIN (spec §D2) -------------------------------------
# graph_fullxzoom() used never to parse `%` at all, and graph_props emits no
# per-rect `rawfile=`, so an AUTO x window spanned the CURRENT db's extent only:
# a VCD ten times shorter was squeezed into the left tenth of the strip and a VCD
# ten times longer was clipped, and WHICH happened depended on the registry
# cursor. Batch F item 8 makes the window the UNION of the extents of every
# database contributing a trace to the shared-X strip group; a strip whose every
# trace names its own `%<rawfile>` is therefore fitted to THOSE databases and not
# to whatever happens to be current. RESTATED, not deleted -- this used to assert
# the defect.
set vcdshort [file join $scratch short.vcd]
mkvcd $vcdshort sigb 200
xschem new_schematic switch $vdrw
xschem raw read $vcdshort vcd
xschem raw switch 0
wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] y1 -0.3 y2 1.3]]
wviewer::regenerate $tok
check "XD1 a 10x-shorter VCD's signal is accepted too" \
  [pcall {wviewer::add_trace $tok 0 TOP.m.sigb {} 5}] {}
xschem new_schematic switch $vdrw
set xx2 [pcall {xschem getprop rect 2 0 x2}]
puts "  D2: with ONLY a 0..2e-10 VCD trace on the strip, auto x2 = $xx2 (the VCD's own extent; the session analog raw spans 0..2e-9)"
check_true "XD2 auto X spans the UNION of the databases that actually carry the\
 strip's traces — with only the 0..2e-10 VCD trace on it the window is the VCD's\
 own extent, not the current analog db's 0..2e-9 (spec D2)" \
  [expr {[string is double -strict $xx2] && $xx2 > 1.0e-10 && $xx2 < 1.0e-9}]
# The other half of D2 -- that the union does not move when a different database
# is made current -- is NOT asserted here: the viewer's buffer is read-only for
# life, so `xschem setprop rect 2 0 fullxzoom` is refused in this context and the
# only way to re-run the fit is a full regenerate, which rebuilds the rect from
# graph_props and would be measuring a different thing. That half is engine-level
# and lives in the XD leg of tests/headless/test_node_token_split.tcl (XD3/XD4).

catch {wviewer::close $tok}
}

# ============================================================================
# XS* — DEFECT 1, END TO END, IN TWO PROCESSES
#
# Everything above lives in ONE xschem. The defect only appears across a SAVE
# and a REOPEN: `ase::ui::viewer_restore` handed `wviewer::restore` the analog
# raw alone, and `wviewer::restore` did `raw clear` + ONE `raw read`, so the
# database a trace's `%<rawfile> <sim_type>` names was no longer in the registry.
# The switch then failed at dbg(1) and the strip DREW NOTHING while still
# LISTING the signal in its legend — "flat", not "gone".
#
# So this leg writes a state file carrying a cross-DB trace, launches a SECOND
# xschem on it, and probes that process's PIXELS. The oracle is self-calibrating
# and does not trust a registry count: the child renders TWICE — once as
# restored, and once with the VCD deliberately detached — and the second render
# is the LEGEND-ONLY floor. A trace that draws must clear that floor by a wide
# margin. (Measured while writing this: 510 red columns restored vs 145 legend
# only; with the fix reverted the first render collapses to the same 145.)
# ============================================================================
set xsbin [file join $repo src xschem]
if {![file executable $xsbin]} {
  puts "NOTE: XS leg not run (no built binary at $xsbin)"
} else {

# `key value` lines out of the child's result file -> a dict
proc xs_result {path} {
  if {![file isfile $path]} { return {} }
  set f [open $path r]; set txt [read $f]; close $f
  set d [dict create]
  foreach line [split [string trimright $txt "\n"] "\n"] {
    if {[regexp {^(\S+) ?(.*)$} $line -> k v]} { dict set d $k $v }
  }
  return $d
}

# Write and RUN a child xschem on `sf`, probing the reopened viewer. `capture`
# 1 renames ::ciw_echo before the restore so the messages can be asserted.
proc xs_run {bin dir tag sf vcd capture {mode render}} {
  set res [file join $dir "child_$tag.txt"]
  set ct  [file join $dir "child_$tag.tcl"]
  catch {file delete $res}
  set cf [open $ct w]
  puts $cf "set no_recent_files 1"
  puts $cf [list set RES $res]
  puts $cf [list set SF $sf]
  puts $cf [list set VCD $vcd]
  puts $cf [list set PNG1 [file join $dir "child_${tag}_1.png"]]
  puts $cf [list set PNG2 [file join $dir "child_${tag}_2.png"]]
  puts $cf [list set CAPTURE $capture]
  puts $cf [list set MODE $mode]
  puts $cf {
set MSGS {}
proc out {k v} { global RES; set f [open $RES a]; puts $f "$k $v"; close $f }
# red/green COLUMN counts, exactly the XR8 classifier: layer 4 is
# green-dominant, layer 5 red-dominant, classified by dominance so no RGB
# triple from the palette is hard-coded.
proc probe {png} {
  if {![file exists $png]} { return {-1 -1} }
  set img [image create photo -file $png]
  set W [image width $img]; set H [image height $img]
  array set gpx {}; array set rpx {}
  for {set x 0} {$x < $W} {incr x} {
    for {set y 0} {$y < $H} {incr y} {
      lassign [$img get $x $y] r g b
      if {$g > 100 && $r < $g && $b < 60} { set gpx($x) 1 }
      if {$r > 100 && $g < 90 && $b < 60} { set rpx($x) 1 }
    }
  }
  image delete $img
  return [list [array size gpx] [array size rpx]]
}
if {[catch {
  if {$CAPTURE} {
    proc ::ciw_echo {msg {tag {}}} { global MSGS; if {$tag eq {error}} { lappend MSGS $msg } }
  }
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $SF
  # THE PRODUCT PATH: this is the seam ase::ui::open calls on a fresh session
  # open, and the one ase::open_state and the Load State menu reach.
  set rc [ase::ui::viewer_restore $tok]
  out restore_rc $rc
  out msgs [join $MSGS { | }]
  set vtop [wviewer::window_for $tok]
  for {set i 0} {$i < 300} {incr i} {
    update
    if {[winfo exists $vtop.drw] && [winfo ismapped $vtop.drw]} break
    after 20
  }
  xschem new_schematic switch $vtop.drw
  set info [xschem raw info]
  out ndbs [expr {[llength [split [string trimright $info "\n"] "\n"]] - 1}]
  out hasvcd [expr {[string first "$VCD vcd" $info] >= 0 ? 1 : 0}]
  out node [lindex [split [xschem getprop rect 2 0 node] "\n"] 1]
  if {$MODE eq {add}} {
    # NO RENDER in this mode: adding a trace would put a THIRD (red) curve on
    # the canvas and move the very pixel counts the render mode measures.
    out addvcd [wviewer::add_trace $tok 0 TOP.m.siga {} 5]
    out addraw [wviewer::dget [lindex [wviewer::dget \
      [lindex [dict get [wviewer::layout_for $tok] graphs] 0] traces {}] end] rawfile {}]
  } else {
    catch {xschem print png $PNG1 900 500}
    update idletasks
    lassign [probe $PNG1] g1 r1
    out green_with $g1
    out red_with $r1
    # THE LEGEND-ONLY FLOOR, measured in the same process on the same canvas:
    # drop the VCD out of the registry and re-render. Whatever red survives is
    # legend text, because the trace can no longer switch to anything.
    catch {xschem raw clear $VCD vcd}
    wviewer::regenerate $tok
    xschem new_schematic switch $vtop.drw
    catch {xschem print png $PNG2 900 500}
    update idletasks
    lassign [probe $PNG2] g2 r2
    out green_without $g2
    out red_without $r2
  }
  out done 1
} err]} {
  out err $err
}
}
  close $cf
  catch {exec $bin --pipe -q --nolog --script $ct 2>@1}
  return [xs_result $res]
}

# --- the state file, carrying ONE analog trace and ONE cross-DB VCD trace ----
proc xs_state {rawf vcdf rundir} {
  set G [dict create x1 0 x2 2e-9 y1 -0.3 y2 1.3 \
          traces [list [dict create expr v(anlg) name {} vec v(anlg) color 4] \
                       [dict create expr TOP.m.siga name {} vec TOP.m.siga color 5 \
                                    rawfile $vcdf sim_type vcd]]]
  return [dict create version 1 simulator ngspice \
            design [dict create lib sky130_tests cell test_nfet_final view schematic] \
            rundir $rundir temperature 27 models {} variables {} \
            analyses [list [dict create type tran enabled 1]] outputs {} \
            save_all_v 0 save_all_i 0 options {} includes {} pre_commands {} \
            viewer [dict create open 1 sharedx 0 rawfile $rawf \
                      graphs [list $G] mode single target 0]]
}
file mkdir [file join $scratch run]
set sfok [file join $scratch xs_ok.state]
ase::state_save $sfok [xs_state $rawf $vcdf [file join $scratch run]]

set xr [xs_run $xsbin $scratch ok $sfok $vcdf 0]
puts "  XS probe (process 2): ndbs=[wviewer::dget $xr ndbs ?]\
 green=[wviewer::dget $xr green_with ?] red_restored=[wviewer::dget $xr red_with ?]\
 red_legend_only=[wviewer::dget $xr red_without ?]"
check "XS1 the second process finished the probe"      [wviewer::dget $xr done {}] 1
check "XS2 viewer_restore rebuilt the viewer there"    [wviewer::dget $xr restore_rc {}] 1
# not the proof, but the mechanism: the registry now holds BOTH databases
check "XS3 the reopened session has TWO databases"     [wviewer::dget $xr ndbs {}] 2
check "XS4 ... and one of them is the VCD the trace names" \
  [wviewer::dget $xr hasvcd {}] 1
check "XS5 the %<path> <type> suffix survived the round trip" \
  [wviewer::dget $xr node {}] "\"TOP.m.siga;TOP.m.siga%$vcdf vcd\""
# --- THE PIXEL PROOF --------------------------------------------------------
set xs_g  [wviewer::dget $xr green_with 0]
set xs_r  [wviewer::dget $xr red_with 0]
set xs_r0 [wviewer::dget $xr red_without 0]
# XS6 is XR8's bar, applied in the OTHER process: a real trace spans the plot,
# so it must reach at least half the analog trace's column count.
# XS6a is XR8's green leg in the other process, and it is NOT filler: it is the
# only check that catches a restore which leaves the wrong database CURRENT.
# `xschem raw read` makes what it read current, so attaching the VCDs without
# switching back would resolve `v(anlg)` against the VCD and blank the ANALOG
# trace — while leaving the VCD trace (which switches per node) perfect.
check_true "XS6a PIXELS: the ANALOG trace still draws (the analog db is still current)" \
  [expr {$xs_g > 300}]
check_true "XS6 PIXELS: the restored VCD trace is on the canvas ($xs_r red cols vs $xs_g green)" \
  [expr {$xs_r > $xs_g / 2}]
# XS7 is the one XR8 could not make: the SAME canvas with the database taken
# away. XR8's own ⚠ records that legend text alone once sailed past a `> 100`
# bar; this measures that floor instead of guessing it.
check_true "XS7 PIXELS: those columns are the TRACE, not the legend ($xs_r vs $xs_r0 legend-only)" \
  [expr {$xs_r0 > 0 && $xs_r > 2 * $xs_r0}]
# XS8 pins the SYMPTOM SHAPE the fix exists to kill: with the database gone the
# strip still lists the signal, which is why the failure read as "flat".
check_true "XS8 ... and the legend is STILL drawn with the db detached (the silent-blank shape)" \
  [expr {$xs_r0 > 0}]

# --- XS9-11: THE DECISION — a named database that CANNOT be attached --------
# Deleted, moved, or on a mount that is not there. Refusing to open the session
# would be worse than the bug; staying silent IS the bug. So: the viewer comes
# up, and the user is told which database is missing AND which traces will draw
# nothing — a flat signal is never named in an error line.
set gone [file join $scratch gone.vcd]
catch {file delete $gone}
set sfbad [file join $scratch xs_missing.state]
ase::state_save $sfbad [xs_state $rawf $gone [file join $scratch run]]
set xb [xs_run $xsbin $scratch missing $sfbad $gone 1]
puts "  XS missing-db message: [wviewer::dget $xb msgs {}]"
check "XS9 a missing database does NOT stop the session opening" \
  [wviewer::dget $xb restore_rc {}] 1
check_true "XS10 ... the user is TOLD, naming the database" \
  [expr {[string first $gone [wviewer::dget $xb msgs {}]] >= 0}]
check_true "XS11 ... and naming the trace that will draw NOTHING (gone, not flat)" \
  [expr {[string first TOP.m.siga [wviewer::dget $xb msgs {}]] >= 0
         && [string first NOTHING [wviewer::dget $xb msgs {}]] >= 0}]

# --- XS12-14: THE RUN'S OWN VCDs, even when NO trace names one yet ----------
# The other half of the union. `ase::last_vcdfiles` is the list `dp_finish` and
# `auto_plot` already hand to `attach_raw`; `viewer_restore` now hands it here
# too. Without it, a co-sim session reopened with a purely analog layout comes
# back with the digital databases missing — the browser's All-DBs pane is empty
# and the next `add_trace` of a VCD signal is refused, even though the run
# produced the data. The trace-derived list cannot cover this: no trace names
# the VCD yet.
set sfrun [file join $scratch xs_run.state]
set strun [xs_state $rawf $vcdf [file join $scratch run]]
# the layout carries ONLY the analog trace, so trace_dbs answers {}
dict set strun viewer graphs [list [dict create x1 0 x2 2e-9 y1 -0.3 y2 1.3 \
  traces [list [dict create expr v(anlg) name {} vec v(anlg) color 4]]]]
ase::state_save $sfrun $strun
# the run artifact ase::last_vcdfiles reads (<rundir>/<cell>_ase.cosim)
set cmap [open [file join $scratch run test_nfet_final_ase.cosim] w]
puts $cmap "# xschem ASE-L co-simulation map -- generated, do not edit."
puts $cmap [list [dict create model d1 vcd $vcdf scope TOP.m multi 0]]
close $cmap
check "XS12 (control) no trace in that layout names a database" \
  [pcall {wviewer::trace_dbs [dict get $strun viewer graphs]}] {}
set xrn [xs_run $xsbin $scratch runvcd $sfrun $vcdf 0 add]
check "XS13 the RUN's VCD is attached anyway (ase::last_vcdfiles)" \
  [wviewer::dget $xrn hasvcd {}] 1
check "XS14 ... so a VCD signal can be added in the reopened session" \
  [list [wviewer::dget $xrn addvcd ?] [wviewer::dget $xrn addraw ?]] [list {} $vcdf]
}
}

} err]} {
  puts "FAIL: uncaught error: $err : FAIL"
  incr fail
}

if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } \
else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
