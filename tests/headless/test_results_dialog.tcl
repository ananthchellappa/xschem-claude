# test_results_dialog.tcl -- `Results > Select...`, the ASE-L dialog.
# doc/claude/specs/results_selection.md section 6 (R401-R407) + the item-7
# rulings R407a..R407h; doc/claude/results_batch/PLAN.md item 7.
#
# WHAT THIS FILE IS FOR. Items 1-6 built the engine, the resolver, the verb,
# the orchestrator, the re-expressed Location bar and the persisted slot; all
# of that is pinned by tests/headless/test_results_select.tcl. THIS file pins
# the DOOR: the menu entry, the window, and the gestures that reach
# `results::select` -- and nothing else. Anything about what the door does once
# it is called belongs to test_results_select.
#
# ⚠ THE PAYLOAD IS PARTLY PIXELS AND THIS FILE CANNOT SEE THEM. Layout order,
# the balloon, the mark glyph and the colours are asserted here as widget
# facts (`grid info -row`, `winfo manager`, `winfo ismapped`, `cget`), which is
# what the anti-vacuity rule asks for and is still NOT a human looking at the
# window. Item 7 is verdicted [E] and owes an eyeball -- see the receipt.
#
# GROUPS
#   RA  the type rules -- R407c's three clauses and the `<NULL>` mapping
#   RB  the two lists -- R404/R405 data, and R407a's three context arms
#   RC  the gesture -- R406's one commit path, R407g's own refusal arm, T-D
#   RD  the resolver inputs -- R407e (what is passed, and the two that are NOT)
#   RE  the MRU -- 0216's shape through this door, under group AJ's shim rules
#   RF  GUI legs (DISPLAY only): the menu entry, the window, the regions in
#       R404's order, a real double-click, ESC, the balloon, the theme
#
# Runs with or without X. From the repo root:
#   tests/headless/devdisplay.sh exec ./src/xschem --pipe -q --nolog \
#       --script tests/headless/test_results_dialog.tcl
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_results_dialog.tcl
#
# ⚠ NOTHING HERE MAY WRITE UNDER $HOME. `::update_recent_files` ungates FIVE
# writers across two files; group RE raises it around ONE call with every
# writer shimmed and `::wviewer::rawhist` saved and restored, exactly as
# test_results_select's group AJ does.

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
proc dg {d k {dflt {}}} {
  if {[catch {dict exists $d $k} h]} { return $dflt }
  if {!$h} { return $dflt }
  return [dict get $d $k]
}
proc wr {path body} {
  file mkdir [file dirname $path]
  set fp [open $path w]
  puts -nonewline $fp $body
  close $fp
}
# `xschem load -inplace` + a deselect: test_results_select's helper, copied
# rather than shared (each headless test is its own process).
proc loadcell {f} { xschem load -inplace $f ; xschem unselect_all }

# the registry's slot list, in order (test_results_select's helper, verbatim in
# shape): `xschem raw info` prints "<idx> current" and then one line per slot.
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

set tmp [test_scratch resultsdlg]
set rundir [file join $tmp run]
file mkdir $rundir

wr $tmp/cellA.sch "v {xschem version=3.4.4 file_version=1.2}\nG {}\nV {}\nS {}\nE {}\nN 0 0 200 0 {}\n"

wr $tmp/an.raw "Title: results dialog
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
wr $tmp/bn.raw "Title: results dialog 2
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
# ONE FILE, TWO ANALYSES -- U11's shape, and the ONLY fixture that can tell
# R407c clause (1) from clause (2): read as `dc` and as `tran` it occupies TWO
# registry slots, so a by-PATH type lookup answers the first one (`dc`) for
# both, while the row carries its own.
wr $tmp/multi.raw "Title: results dialog multi
Plotname: DC transfer characteristic
Flags: real
No. Variables: 2
No. Points: 2
Variables:
\t0\tv-sweep\tvoltage
\t1\tv(n3)\tvoltage
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
\t1\tv(n3)\tvoltage
Values:
0\t0.000000000000000e+00
\t7.000000000000000e+00

1\t1.000000000000000e-08
\t8.000000000000000e+00

"
# the netlist the mtime half of `stale` compares against (R407e). Its NAME is
# what ase::netlist writes: <rundir>/<cell>.spice.
wr $rundir/cellA.spice "* results dialog fixture netlist\n.end\n"
# not a raw at all -- the door refuses it, which is what R407c clause (3)'s
# residual case looks like from the dialog.
wr $tmp/notraw.txt "this is not a raw file\n"

# --- the session. A hand-written state file is enough: nothing in this file
#     resolves the design through the library registry, and ase::ui::open
#     records {lib cell view} without asking for them.
set spath [file join $tmp cellA.state]
set st [dict create design [dict create lib aselib cell cellA view schematic] \
          rundir $rundir simulator ngspice variables {} analyses {} outputs {} \
          models {} options {}]
ase::state_save $spath $st
set key [ase::session_key aselib cellA ngspice_state1]
ase::session_open $key $spath

if {[catch {

# ===========================================================================
# RA -- R407c: THE TYPE RULES. The dialog never selects typelessly when it
#       knows a type, never invents one when it does not, and never passes
#       `<NULL>` -- which is a RENDERING of a NULL sim_type, not a token.
# ===========================================================================
eqcheck SEL360-RA-type_norm-maps-NULL-and-passes-a-real-token \
  [list [pcall ase::ui::rsel_type_norm {<NULL>}] \
        [pcall ase::ui::rsel_type_norm { tran }] \
        [pcall ase::ui::rsel_type_norm {}]] {{} tran {}}

xschem raw clear
loadcell $tmp/cellA.sch
eqcheck SEL361-RA-fixture-two-raws-read [list [pcall xschem raw read $tmp/an.raw tran] \
                                              [pcall xschem raw read $tmp/bn.raw tran]] {1 1}
set ra_rows [dg [pcall ase::ui::rsel_rows $key] loaded]
# clause (2): a DIFFERENT spelling of a loaded path still finds the slot's type,
# because the question is asked with results::_same_path -- R302a/R302h's one
# answer, not a second copy of it.
eqcheck SEL362-RA-type_for-finds-the-slot-type-through-another-spelling \
  [pcall ase::ui::rsel_type_for $ra_rows [file join $tmp .. [file tail $tmp] an.raw]] tran
eqcheck SEL363-RA-type_for-answers-empty-for-an-unknown-path \
  [pcall ase::ui::rsel_type_for $ra_rows $tmp/nosuch.raw] {}
eqcheck SEL364-RA-type_for-never-hands-back-NULL \
  [pcall ase::ui::rsel_type_for [list [dict create path $tmp/an.raw type {<NULL>}]] \
     $tmp/an.raw] {}

# ===========================================================================
# RB -- R404/R405's two lists, and R407a's three context arms.
# ===========================================================================
set rb [pcall ase::ui::rsel_rows $key]
# R407a `here` arm: this session has no waveform viewer, so there is no other
# context to borrow and the dialog reads -- and later titles -- the current one.
eqcheck SEL365-RB-no-viewer-is-the-here-arm-not-a-refusal \
  [list [dg $rb ok] [dg $rb where] [dg $rb msg]] {1 here {}}
set rb_loaded [dg $rb loaded]
# one row per SLOT, in registry order, the current one marked, labelled by
# db_label (file tail + analysis, R803)
eqcheck SEL366-RB-loaded-is-one-row-per-slot-current-marked \
  [list [llength $rb_loaded] \
        [dg [lindex $rb_loaded 0] label] [dg [lindex $rb_loaded 0] cur] \
        [dg [lindex $rb_loaded 1] label] [dg [lindex $rb_loaded 1] cur] \
        [dg [lindex $rb_loaded 1] type]] \
  {2 {an.raw (tran)} 0 {bn.raw (tran)} 1 tran}
# R404's Recent: `wviewer::rawhist_get`, newest first, entries already in the
# registry distinguished -- and the in-registry ones INHERIT the slot's type,
# which is R407c clause (2) where it is computed.
set rb_hist_had [info exists ::wviewer::rawhist]
set rb_hist_old $::wviewer::rawhist
set ::wviewer::rawhist [list $tmp/bn.raw $tmp/gone.raw]
set rb2 [pcall ase::ui::rsel_rows $key]
set rb_recent [dg $rb2 recent]
eqcheck SEL367-RB-recent-newest-first-inreg-flagged-and-typed \
  [list [llength $rb_recent] \
        [dg [lindex $rb_recent 0] path] [dg [lindex $rb_recent 0] inreg] \
        [dg [lindex $rb_recent 0] type] [dg [lindex $rb_recent 0] label] \
        [dg [lindex $rb_recent 1] path] [dg [lindex $rb_recent 1] inreg] \
        [dg [lindex $rb_recent 1] type] [dg [lindex $rb_recent 1] label]] \
  [list 2 $tmp/bn.raw 1 tran {bn.raw (tran)} $tmp/gone.raw 0 {} gone.raw]
set ::wviewer::rawhist $rb_hist_old

# R407a / F6 / T-J: A REFUSED TICKET IS REPORTED AS REFUSED. The shim pair is
# the only deterministic way to reach a refused borrow (item 5 made the same
# call for `switch_ctx`, SEL303).
rename wviewer::window_for rb_o_wf
proc wviewer::window_for {token} { return .rbfake }
rename wviewer::enter_ctx rb_o_ec
proc wviewer::enter_ctx {token {borrow 0}} { return {0 {}} }
set rb3 [pcall ase::ui::rsel_rows $key]
rename wviewer::window_for {} ; rename rb_o_wf wviewer::window_for
rename wviewer::enter_ctx {} ; rename rb_o_ec wviewer::enter_ctx
eqcheck SEL368-RB-refused-ticket-is-ok-0-with-both-lists-empty \
  [list [dg $rb3 ok] [dg $rb3 where] [dg $rb3 loaded] [dg $rb3 recent]] \
  {0 viewer {} {}}
# F6's actual defect is a refusal that READS LIKE AN ANSWER, so the sentence is
# asserted for what it must NOT say as well as for what it must.
check SEL369-RB-refusal-sentence-says-refused-not-no-results \
  [expr {[string match {*refused context switch*} [dg $rb3 msg]] &&
         ![string match {*no results*} [dg $rb3 msg]] &&
         [string match {*not an empty result list*} [dg $rb3 msg]]}] \
  "(msg '[dg $rb3 msg]')"

# ===========================================================================
# RC -- R406's ONE commit path, R407g's own refusal arm, and T-D.
# ===========================================================================
xschem raw clear
loadcell $tmp/cellA.sch
pcall xschem raw read $tmp/an.raw tran
pcall xschem raw read $tmp/bn.raw tran
# arm the FIRST loaded row (an.raw) and commit: the current database moves back
# to it, no slot is added (F7), and the Status region carries the door's own
# sentence.
set rc_rows [dg [pcall ase::ui::rsel_rows $key] loaded]
pcall ase::ui::rsel_arm $key [dg [lindex $rc_rows 0] path] \
  [dg [lindex $rc_rows 0] type] loaded
set rc_before [slot_list]
set rc1 [pcall ase::ui::rsel_commit $key]
eqcheck SEL370-RC-commit-selects-the-armed-row \
  [list $rc1 [pcall xschem raw rawfile] [llength [slot_list]] \
        [expr {[slot_list] eq $rc_before ? 1 : 0}]] \
  [list 1 $tmp/an.raw 2 1]
# ⚠ NOT the resolver's "Using an.raw." -- R805b: `results::select` composes its
# own sentence PER OUTCOME, and the Status region carries THAT, because what the
# user just did was select, not resolve.
eqcheck SEL371-RC-status-is-the-doors-own-sentence \
  $::ase::ui::dlg($key,rselstatus) "Selected an.raw (tran)."
# R407c clause (1): the type travels WITH THE ROW. The shim records exactly what
# the door was handed.
# R407c clause (1), on the ONE fixture that can prove it: multi.raw is loaded
# TWICE, as `dc` (slot 0 of that path) and as `tran`. Arming the TRAN row and
# watching what the door is handed separates "the row's own type" from "the type
# of the first slot with this path" -- which is what a by-path lookup would say,
# and what U11 warns is the wrong analysis of the right file.
pcall xschem raw read $tmp/multi.raw dc
pcall xschem raw read $tmp/multi.raw tran
set rc_mrows {}
foreach rc_r [dg [pcall ase::ui::rsel_rows $key] loaded] {
  if {[dg $rc_r path] eq "$tmp/multi.raw"} { lappend rc_mrows $rc_r }
}
eqcheck SEL409-RC-one-file-two-analyses-is-two-rows-and-one-file \
  [list [llength $rc_mrows] [dg [lindex $rc_mrows 0] type] \
        [dg [lindex $rc_mrows 1] type] \
        [pcall ase::ui::rsel_type_for $rc_mrows $tmp/multi.raw]] \
  {2 dc tran dc}

rename results::select rc_o_sel
set ::rc_args {}
# ⚠ `::list`, NOT `list`. A proc DEFINED IN NAMESPACE `results` resolves `list`
# to `results::list` -- the registry reader -- and gets "wrong # args: should be
# list", which `rsel_commit`'s catch then swallows into its own refusal arm.
# src/results.tcl's header warns about exactly this; measured here the hard way.
proc results::select {path {sim_type {}} {opts {}}} {
  set ::rc_args [::list $path $sim_type [dict exists $opts token] \
                      [expr {[dict exists $opts host] ? [dict get $opts host] : {}}] \
                      [dict exists $opts key]]
  return [dict create ok 1 how switch path $path type $sim_type msg {shimmed} did {}]
}
pcall ase::ui::rsel_arm $key $tmp/multi.raw tran loaded
pcall ase::ui::rsel_commit $key
set rc_typed $::rc_args
# ...and clause (2): a candidate carrying NO type of its own inherits the loaded
# slot's, so a bare path from the MRU is never a typeless select of a file the
# engine can already name.
pcall ase::ui::rsel_arm $key $tmp/bn.raw {} recent
pcall ase::ui::rsel_commit $key
set rc_inherit $::rc_args
# ...and clause (3): a path the registry does not know is passed typeless, and
# nothing is invented for it.
pcall ase::ui::rsel_arm $key $tmp/notraw.txt {} path
pcall ase::ui::rsel_commit $key
set rc_none $::rc_args
rename results::select {} ; rename rc_o_sel results::select
# ...and `tran` is the discriminating answer: `dc` is what the registry says
# about this PATH, so a row type that is not carried through lands the user on
# the other analysis of the right file.
eqcheck SEL372-RC-the-row-type-is-what-the-door-is-handed \
  [list [lindex $rc_typed 0] [lindex $rc_typed 1]] [list $tmp/multi.raw tran]
eqcheck SEL373-RC-a-typeless-candidate-inherits-the-loaded-slots-type \
  [list [lindex $rc_inherit 0] [lindex $rc_inherit 1]] [list $tmp/bn.raw tran]
eqcheck SEL374-RC-an-unknown-path-is-passed-typeless-not-guessed \
  [list [lindex $rc_none 0] [lindex $rc_none 1]] [list $tmp/notraw.txt {}]
# R802/R407e: the channel is named outright (`host ase`), no `key` is passed --
# see R407e on ase::last_rawfile -> ase::rundir -- and with no viewer window
# there is no token for the viewer-side follow-ups.
eqcheck SEL375-RC-opts-name-the-channel-and-carry-no-key-or-token \
  [list [lindex $rc_typed 2] [lindex $rc_typed 3] [lindex $rc_typed 4]] {0 ase 0}

# R407g -- a path that is not a file is refused HERE, ahead of the door, and the
# door is never called. Without this arm the resolver answers `invalid` and
# hands back the DERIVED result, so the user would be given a different file
# from the one they picked.
rename results::select rc_o_sel2
set ::rc_calls 0
proc results::select {path {sim_type {}} {opts {}}} {
  incr ::rc_calls
  return [dict create ok 1 how read path $path msg {reached the door} did {}]
}
# the counter carries its own POSITIVE term: a candidate that IS a file reaches
# the door in the very same drive, so `0 calls` below is the guard firing and
# not the shim failing to be installed.
pcall ase::ui::rsel_arm $key $tmp/bn.raw tran loaded
pcall ase::ui::rsel_commit $key
set rc_reached $::rc_calls
pcall ase::ui::rsel_arm $key $tmp/gone.raw {} path
set rc_before2 [slot_list]
set rc_cur2 [pcall xschem raw rawfile]
set rc2 [pcall ase::ui::rsel_commit $key]
set rc_after $::rc_calls
rename results::select {} ; rename rc_o_sel2 results::select
eqcheck SEL376-RC-a-missing-file-is-refused-ahead-of-the-door \
  [list $rc2 $rc_reached $rc_after [expr {[slot_list] eq $rc_before2 ? 1 : 0}] \
        [pcall xschem raw rawfile]] [list 0 1 1 1 $rc_cur2]
eqcheck SEL377-RC-the-refusal-names-the-file-and-says-nothing-was-selected \
  $::ase::ui::dlg($key,rselstatus) \
  "No such result file 'gone.raw' — nothing was selected."
# T-D through this door: a file that exists but is not a raw reaches the engine,
# the engine refuses, and the previous selection is intact.
pcall ase::ui::rsel_arm $key $tmp/notraw.txt {} path
set rc_before3 [slot_list]
set rc_cur3 [pcall xschem raw rawfile]
set rc3 [pcall ase::ui::rsel_commit $key]
eqcheck SEL378-RC-a-refused-engine-select-leaves-the-selection-intact \
  [list $rc3 [expr {[slot_list] eq $rc_before3 ? 1 : 0}] [pcall xschem raw rawfile]] \
  [list 0 1 $rc_cur3]
check SEL379-RC-the-engine-refusal-sentence-is-the-doors \
  [expr {[string match {Could not select notraw.txt*} $::ase::ui::dlg($key,rselstatus)] &&
         [string match {*previous result is unchanged.} $::ase::ui::dlg($key,rselstatus)]}] \
  "(status '$::ase::ui::dlg($key,rselstatus)')"
# an empty candidate is not an error either (R801: nothing throws)
pcall ase::ui::rsel_arm $key {} {} path
eqcheck SEL380-RC-nothing-armed-asks-rather-than-refuses \
  [list [pcall ase::ui::rsel_commit $key] $::ase::ui::dlg($key,rselstatus)] \
  {0 {Pick a result, or type the path of one.}}

# --- FIXER ROUND (item 7). A CANDIDATE SPELLED RELATIVE TO THE RUNDIR IS A
#     CANDIDATE, NOT A REFUSAL.
# The engine keeps the spelling it was handed, so `xschem raw read rel.raw tran`
# issued from inside the rundir puts a RELATIVE path in the registry and the
# Loaded list renders it. `rsel_preview` resolves it against the rundir (through
# results::resolve) and says `Using rel.raw.`; R407g's guard used to ask
# `file isfile` of the raw spelling against the PROCESS CWD -- the repo root
# here, deliberately not the rundir -- and refused the very row the dialog had
# just previewed, while `results::select` handed the identical path selected it.
# SEL376/SEL377 cannot see that: they only ever feed the guard an ABSOLUTE
# non-existent path, which is refused either way.
file copy -force $tmp/an.raw [file join $rundir rel.raw]
xschem raw clear
loadcell $tmp/cellA.sch
set rc_cwd [pwd]
set rc_relread ERR
catch { cd $rundir ; set rc_relread [pcall xschem raw read rel.raw tran] }
cd $rc_cwd
set rc_relrow {}
foreach rc_r [dg [pcall ase::ui::rsel_rows $key] loaded] {
  if {[dg $rc_r path] eq {rel.raw}} { set rc_relrow $rc_r }
}
pcall ase::ui::rsel_arm $key [dg $rc_relrow path] [dg $rc_relrow type] loaded
set rc_relprev [pcall ase::ui::rsel_preview $key]
set rc_rel [pcall ase::ui::rsel_commit $key]
eqcheck SEL411-RC-a-rundir-relative-candidate-is-selected-not-refused \
  [list $rc_relread [dg $rc_relrow path] [expr {$rc_cwd eq $rundir ? 1 : 0}] \
        $rc_relprev $rc_rel $::ase::ui::dlg($key,rselstatus) \
        [expr {[file normalize [pcall xschem raw rawfile]] eq \
               [file normalize [file join $rundir rel.raw]] ? 1 : 0}] \
        [pcall ase::ui::rsel_abs $key rel.raw] \
        [pcall ase::ui::rsel_abs $key $tmp/an.raw]] \
  [list 1 rel.raw 0 {Using rel.raw.} 1 {Selected rel.raw (tran).} 1 \
        [file join $rundir rel.raw] $tmp/an.raw]

# ===========================================================================
# RD -- R407e: the resolver inputs the dialog supplies, and the two it does not.
# ===========================================================================
set rd1 [pcall ase::ui::rsel_resolve_input $key $tmp/an.raw]
eqcheck SEL381-RD-inputs-are-rawfile-rundir-and-an-EXISTING-netlist \
  [list [lsort [dict keys $rd1]] [dg $rd1 rawfile] [dg $rd1 rundir] [dg $rd1 netlist]] \
  [list {netlist rawfile rundir} $tmp/an.raw $rundir [file join $rundir cellA.spice]]
# ...the netlist input is offered ONLY when that file is really there
file rename [file join $rundir cellA.spice] [file join $rundir cellA.spice.hidden]
set rd2 [pcall ase::ui::rsel_resolve_input $key $tmp/an.raw]
file rename [file join $rundir cellA.spice.hidden] [file join $rundir cellA.spice]
eqcheck SEL382-RD-no-netlist-input-when-the-netlist-is-not-there \
  [lsort [dict keys $rd2]] {rawfile rundir}
# ...and a state naming NO rundir gets neither (and nothing is created for it)
set rd_st [ase::session_state $key]
ase::session_update $key [dict replace $rd_st rundir {}]
set rd3 [pcall ase::ui::rsel_resolve_input $key $tmp/an.raw]
ase::session_update $key $rd_st
eqcheck SEL383-RD-no-rundir-no-derivation [lsort [dict keys $rd3]] {rawfile}
# R602e's discipline, inherited: a READ may not call ase::rundir (it file mkdirs
# and rewrites ::netlist_dir) and may not call ase::last_rawfile (which reaches
# it). Counted, not asserted by reading the source.
rename ase::rundir rd_o_rundir
set ::rd_rundir_calls 0
proc ase::rundir {state} { incr ::rd_rundir_calls ; return {} }
rename ase::last_rawfile rd_o_lastraw
set ::rd_lastraw_calls 0
proc ase::last_rawfile {key} { incr ::rd_lastraw_calls ; return {} }
set rd_nldir {}
catch {set rd_nldir $::netlist_dir}
# ...the counters carry their own POSITIVE term, in the same assertion: a
# deliberate call to each shim in the same drive proves both are installed, so
# the zeros after the preview are the dialog not calling them and not a rename
# that silently did nothing.
pcall ase::last_rawfile $key
pcall ase::rundir [ase::session_state $key]
set rd_armed [list $::rd_rundir_calls $::rd_lastraw_calls]
set ::rd_rundir_calls 0
set ::rd_lastraw_calls 0
pcall ase::ui::rsel_resolve_input $key $tmp/an.raw
pcall ase::ui::rsel_arm $key $tmp/an.raw tran loaded
pcall ase::ui::rsel_preview $key
set rd_nldir2 {}
catch {set rd_nldir2 $::netlist_dir}
rename ase::rundir {} ; rename rd_o_rundir ase::rundir
rename ase::last_rawfile {} ; rename rd_o_lastraw ase::last_rawfile
eqcheck SEL384-RD-a-preview-creates-nothing-and-moves-no-global \
  [list $rd_armed $::rd_rundir_calls $::rd_lastraw_calls \
        [expr {$rd_nldir eq $rd_nldir2 ? 1 : 0}]] \
  {{1 1} 0 0 1}
# the mtime half of `stale` is REACHED -- which is the only proof the netlist
# input is used rather than merely computed
file mtime $tmp/an.raw [expr {[file mtime [file join $rundir cellA.spice]] - 600}]
pcall ase::ui::rsel_arm $key $tmp/an.raw tran loaded
pcall ase::ui::rsel_preview $key
set rd_stale $::ase::ui::dlg($key,rselstatus)
file mtime $tmp/an.raw [expr {[file mtime [file join $rundir cellA.spice]] + 600}]
check SEL385-RD-an-older-than-its-netlist-result-previews-as-stale \
  [expr {[string match {Using an.raw, but this result is older than the netlist*} $rd_stale]}] \
  "(status '$rd_stale')"
# ...and the sentence is the RESOLVER'S OWN, not a re-wording (section 10)
pcall ase::ui::rsel_preview $key
set rd_res [pcall results::resolve [pcall ase::ui::rsel_resolve_input $key $tmp/an.raw]]
eqcheck SEL386-RD-the-status-sentence-is-the-resolvers-verbatim \
  $::ase::ui::dlg($key,rselstatus) [dg $rd_res msg]
# R407h: `invalid` is the one status the dialog does NOT quote, because R407g
# means it will not do what the resolver's sentence describes.
pcall ase::ui::rsel_arm $key $tmp/gone.raw {} path
pcall ase::ui::rsel_preview $key
set rd_inv [pcall results::resolve [pcall ase::ui::rsel_resolve_input $key $tmp/gone.raw]]
eqcheck SEL387-RD-invalid-is-not-quoted-and-promises-no-fallback \
  [list $::ase::ui::dlg($key,rselstatus) [dg $rd_inv status] \
        [expr {[string match {*fall*back*} $::ase::ui::dlg($key,rselstatus)] ? 1 : 0}]] \
  [list {No such result file 'gone.raw'.} invalid 0]

# ===========================================================================
# RE -- the MRU (0216's shape) through THIS door. GROUP AJ'S SHIM DISCIPLINE,
#      because ::update_recent_files ungates FIVE writers across two files and
#      this batch has destroyed the user's ~/.xschem twice.
# ===========================================================================
set re_urf_had [info exists ::update_recent_files]
if {$re_urf_had} { set re_urf_old $::update_recent_files }
set re_hist_old $::wviewer::rawhist
rename wviewer::rawhist_write re_o_rhw
proc wviewer::rawhist_write {} { return 1 }
rename write_recent_file re_o_wrf
proc write_recent_file {} { return 1 }
set re_rhw_body [info body wviewer::rawhist_write]
set re_wrf_body [info body write_recent_file]

xschem raw clear
loadcell $tmp/cellA.sch
pcall xschem raw read $tmp/an.raw tran
pcall ase::ui::rsel_arm $key $tmp/an.raw tran loaded
set ::wviewer::rawhist {}
# the flag is raised around the SINGLE call under test and nothing else
set ::update_recent_files 1
set re1 [pcall ase::ui::rsel_commit $key]
set ::update_recent_files 0
set re_now $::wviewer::rawhist

rename write_recent_file {} ; rename re_o_wrf write_recent_file
rename wviewer::rawhist_write {} ; rename re_o_rhw wviewer::rawhist_write
set ::wviewer::rawhist $re_hist_old
if {$re_urf_had} { set ::update_recent_files $re_urf_old } else { unset ::update_recent_files }
eqcheck SEL388-RE-a-dialog-selection-records-itself-in-the-MRU \
  [list $re1 $re_now [expr {[info body wviewer::rawhist_write] eq $re_rhw_body ? 0 : 1}] \
        [expr {[info body write_recent_file] eq $re_wrf_body ? 0 : 1}]] \
  [list 1 [list [file normalize $tmp/an.raw]] 1 1]

# ===========================================================================
# RF -- the GUI legs. The window, the menu entry, R404's region ORDER, a real
#      double-click, ESC, the balloon and the theme.
# ===========================================================================
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  set top [ase::ui::open $key aselib cellA ngspice_state1]
  update
  # --- R401: the menu entry, above Direct Plot, with a separator, wired to
  #     the dialog, and NO csv row (the ASE menubar is hand-built).
  set rf_labels {}
  for {set i 0} {$i <= [$top.mb.results index end]} {incr i} {
    set l {}
    catch {set l [$top.mb.results entrycget $i -label]}
    lappend rf_labels [expr {$l eq {} ? [$top.mb.results type $i] : $l}]
  }
  eqcheck SEL389-RF-Select-is-the-first-Results-entry-above-Direct-Plot \
    $rf_labels [list "Select…" separator {Direct Plot} Annotate]
  eqcheck SEL390-RF-Select-is-wired-to-the-dialog-and-enabled \
    [list [$top.mb.results entrycget "Select…" -command] \
          [$top.mb.results entrycget "Select…" -state]] \
    [list [list ase::ui::rsel_dialog $key] normal]

  # --- the window itself
  set w [ase::ui::rsel_dialog $key]
  update
  eqcheck SEL391-RF-the-dialog-is-a-mapped-toplevel-under-the-session-window \
    [list [winfo exists $w] [winfo class $w] [winfo ismapped $w] $w] \
    [list 1 Toplevel 1 $top.rsel]
  # --- R402: MODELESS. No grab anywhere -- asserted as BEHAVIOUR, not by
  #     reading the source for the absence of a word.
  eqcheck SEL392-RF-modeless-no-grab-is-held \
    [list [pcall grab current $w] [pcall grab status $w]] {{} none}

  # --- R404/R405/D2: the five regions, in order, TOP TO BOTTOM, and every one
  #     of them really managed and really mapped (the anti-vacuity rule:
  #     existence + class + cget is not proof a control is on screen).
  set rf_order {}
  foreach child [list $w.loaded $w.recent $w.path $w.status $w.btns] {
    lappend rf_order [list [winfo exists $child] [winfo manager $child] \
                        [winfo ismapped $child] [dict get [grid info $child] -row]]
  }
  eqcheck SEL393-RF-the-five-regions-are-gridded-mapped-and-IN-ORDER \
    $rf_order {{1 grid 1 0} {1 grid 1 1} {1 grid 1 2} {1 grid 1 3} {1 grid 1 4}}
  eqcheck SEL394-RF-Loaded-is-the-FIRST-slave-of-the-dialog \
    [lindex [grid slaves $w -row 0] 0] $w.loaded
  # the two tables and their scrollbars are packed inside their regions
  eqcheck SEL395-RF-both-lists-are-mapped-treeviews-with-a-scrollbar \
    [list [winfo class $w.loaded.tv] [winfo ismapped $w.loaded.tv] \
          [winfo manager $w.loaded.tv] [winfo ismapped $w.loaded.sb] \
          [winfo class $w.recent.tv] [winfo ismapped $w.recent.tv]] \
    {Treeview 1 pack 1 Treeview 1}
  # --- R404: `Select` and `Close`, and NO OK/Apply pair.
  eqcheck SEL396-RF-buttons-are-Select-and-Close-with-no-OK-or-Apply \
    [list [$w.btns.select cget -text] [$w.btns.close cget -text] \
          [winfo exists $w.btns.ok] [winfo exists $w.btns.apply] \
          [winfo exists $w.btns.proceed] [lsort [winfo children $w.btns]]] \
    [list Select Close 0 0 0 [lsort [list $w.btns.select $w.btns.close]]]
  eqcheck SEL397-RF-the-Path-region-is-an-entry-plus-Browse \
    [list [winfo class $w.path.e] [winfo ismapped $w.path.e] \
          [$w.path.browse cget -text] [winfo ismapped $w.path.browse]] \
    [list Entry 1 "Browse…" 1]

  # --- R404's Loaded list, filled, current row marked; R407a titles it with
  #     WHOSE registry it is.
  xschem raw clear
  loadcell $tmp/cellA.sch
  pcall xschem raw read $tmp/an.raw tran
  pcall xschem raw read $tmp/bn.raw tran
  set ::wviewer::rawhist [list $tmp/bn.raw $tmp/gone.raw]
  ase::ui::rsel_fill $key
  update
  set rf_items [$w.loaded.tv children {}]
  eqcheck SEL398-RF-Loaded-shows-one-marked-row-per-slot \
    [list [llength $rf_items] \
          [$w.loaded.tv set [lindex $rf_items 0] result] \
          [$w.loaded.tv set [lindex $rf_items 0] mark] \
          [$w.loaded.tv set [lindex $rf_items 1] result] \
          [$w.loaded.tv set [lindex $rf_items 1] mark] \
          [$w.loaded cget -text]] \
    [list 2 {an.raw (tran)} {} {bn.raw (tran)} "•" {Loaded — current window}]
  set rf_ritems [$w.recent.tv children {}]
  eqcheck SEL399-RF-Recent-distinguishes-what-is-already-in-the-registry \
    [list [llength $rf_ritems] \
          [$w.recent.tv set [lindex $rf_ritems 0] mark] \
          [$w.recent.tv item [lindex $rf_ritems 0] -tags] \
          [$w.recent.tv set [lindex $rf_ritems 1] mark] \
          [$w.recent.tv item [lindex $rf_ritems 1] -tags]] \
    [list 2 "•" inreg {} plain]

  # --- R404's balloon: THE FULL PATH, per row (the label is the tail).
  eqcheck SEL400-RF-the-balloon-text-is-the-rows-FULL-path \
    [list [ase::ui::rsel_tip_text $key loaded [lindex $rf_items 0]] \
          [$w.loaded.tv set [lindex $rf_items 0] result]] \
    [list $tmp/an.raw {an.raw (tran)}]
  eqcheck SEL401-RF-Motion-over-a-row-arms-that-rows-path \
    [list [pcall ase::ui::rsel_tip $key recent $w.recent.tv 5 5] \
          [string match {*rsel_tip *} [bind $w.recent.tv <Motion>]]] \
    [list {} 1]

  # --- R406: ONE gesture. A REAL double-click on the first Loaded row selects
  #     it, the dialog STAYS OPEN, and the list refreshes (the mark moves).
  set rf_bb {}
  for {set i 0} {$i < 100} {incr i} {
    update
    set rf_bb [$w.loaded.tv bbox [lindex $rf_items 0]]
    if {[llength $rf_bb] == 4} break
    after 50
  }
  if {[llength $rf_bb] == 4} {
    lassign $rf_bb bx by bw bh
    set cx [expr {$bx + $bw/2}] ; set cy [expr {$by + $bh/2}]
    foreach ev {<ButtonPress-1> <ButtonRelease-1> <ButtonPress-1> <ButtonRelease-1>} {
      event generate $w.loaded.tv $ev -x $cx -y $cy
    }
    update
    set rf_items2 [$w.loaded.tv children {}]
    eqcheck SEL402-RF-a-real-double-click-selects-and-the-dialog-stays-open \
      [list [pcall xschem raw rawfile] [winfo exists $w] [winfo ismapped $w] \
            [$w.loaded.tv set [lindex $rf_items2 0] mark] \
            [$w.loaded.tv set [lindex $rf_items2 1] mark] \
            [$w.status cget -text]] \
      [list $tmp/an.raw 1 1 "•" {} {Selected an.raw (tran).}]
    # picking a row is also what fills the Path entry -- R404's Path region is
    # the readout of the armed candidate, which is why `Select` and the lists
    # can never disagree about what is about to happen.
    eqcheck SEL403-RF-picking-a-row-fills-the-Path-entry-with-its-full-path \
      [$w.path.e get] $tmp/an.raw
  } else {
    check SEL402-RF-a-real-double-click-selects-and-the-dialog-stays-open 0 \
      "(no bbox for the first Loaded row)"
    check SEL403-RF-picking-a-row-fills-the-Path-entry-with-its-full-path 0 \
      "(no bbox for the first Loaded row)"
  }

  # --- Browse arms the entry and does NOT select (landmine L1: select_raw does
  #     not return {} headlessly, so it is shimmed).
  rename select_raw rf_o_selraw
  proc select_raw {} { return $::rf_browse_answer }
  set ::rf_browse_answer $tmp/bn.raw
  set rf_cur [pcall xschem raw rawfile]
  set rf_b [ase::ui::rsel_browse $key]
  rename select_raw {} ; rename rf_o_selraw select_raw
  eqcheck SEL404-RF-Browse-arms-the-entry-and-selects-nothing \
    [list $rf_b [$w.path.e get] [pcall xschem raw rawfile] \
          [$w.path.browse cget -command]] \
    [list $tmp/bn.raw $tmp/bn.raw $rf_cur [list ase::ui::rsel_browse $key]]

  # --- FIXER ROUND (item 7). THE CONTROLS ARE INVOKED, NOT READ.
  # `-text` and a slave list (SEL396) prove a button is on screen; they prove
  # nothing about what pressing it does, and retargeting `Select`'s -command at
  # a command that does not exist left all 51 checks green. Browse has just
  # ARMED bn.raw without selecting it, so pressing `Select` now is the whole
  # gesture: the current database must move, and the dialog must stay open.
  set rf_selbefore [pcall xschem raw rawfile]
  $w.btns.select invoke
  update
  eqcheck SEL413-RF-the-Select-buttons-command-really-commits \
    [list $rf_selbefore [pcall xschem raw rawfile] [winfo exists $w] \
          [winfo ismapped $w] [$w.status cget -text]] \
    [list $tmp/an.raw $tmp/bn.raw 1 1 {Selected bn.raw (tran).}]

  # --- FIXER ROUND (item 7). R407c CLAUSE (1) THROUGH R406's REAL GESTURE.
  # SEL372 arms the candidate by calling rsel_arm directly, so it cannot see
  # `rsel_pick` dropping the row's own type: with the type discarded there, a
  # click on the `(tran)` row selects the `(dc)` slot -- U11's "wrong analysis
  # of the right file", which is the exact harm R407c was written to prevent --
  # and all 51 checks stayed green. Here the ONLY input is a treeview selection.
  pcall xschem raw read $tmp/multi.raw dc
  pcall xschem raw read $tmp/multi.raw tran
  ase::ui::rsel_fill $key
  update
  set rf_mitem {}
  foreach rf_it [$w.loaded.tv children {}] {
    if {[$w.loaded.tv set $rf_it result] eq {multi.raw (tran)}} { set rf_mitem $rf_it }
  }
  rename results::select rf_o_sel
  set ::rf_sel_args {}
  # ⚠ `::list`, not `list` -- a proc defined in namespace `results` resolves
  #   `list` to the registry reader (src/results.tcl's header warns about it).
  proc results::select {path {sim_type {}} {opts {}}} {
    set ::rf_sel_args [::list $path $sim_type]
    return [dict create ok 1 how switch path $path type $sim_type msg {shimmed} did {}]
  }
  # a real <<TreeviewSelect>>: `selection set` fires the binding rsel_build_list
  # installed, which is what a click reaches.
  $w.loaded.tv selection set $rf_mitem
  update
  set rf_pick_type [dg $::ase::ui::dlg($key,rselcand) type]
  $w.btns.select invoke
  update
  rename results::select {} ; rename rf_o_sel results::select
  # `dc` is what the registry says about this PATH, and it is the FIRST slot of
  # it -- so `tran` here is the row's own type surviving the gesture.
  eqcheck SEL416-RF-a-click-on-the-tran-row-hands-the-door-tran \
    [list [expr {$rf_mitem ne {} ? 1 : 0}] $rf_pick_type $::rf_sel_args \
          [pcall ase::ui::rsel_type_for [::list [dict create path $tmp/multi.raw \
             type dc]] $tmp/multi.raw]] \
    [list 1 tran [::list $tmp/multi.raw tran] dc]

  # --- FIXER ROUND (item 7). <Return> COMMITS, AND ITS OWN KeyRelease DOES NOT
  #     TAKE THE SENTENCE BACK.
  # One physical Return is a KeyPress AND a KeyRelease. The entry binds the
  # first to rsel_commit and the second to the debounced preview, so 250 ms
  # after every Return-commit the resolver's `Using an.raw.` used to replace the
  # door's `Selected an.raw (tran).` -- R407b/R805b broken on a shipped gesture,
  # and after a REFUSED Return the refusal itself was erased. SEL371 reads the
  # record synchronously and never lets the timer fire, so it cannot see it.
  # The race is FORCED here rather than hoped for (the brief's rule).
  focus -force $w.path.e
  update
  $w.path.e delete 0 end
  $w.path.e insert 0 $tmp/an.raw
  ase::ui::rsel_status $key {}
  set rf_ret 0
  for {set rf_i 0} {$rf_i < 12} {incr rf_i} {
    event generate $w.path.e <KeyPress-Return>
    update
    if {$::ase::ui::dlg($key,rselstatus) ne {}} { set rf_ret 1 ; break }
    after 20
  }
  set rf_ret_status $::ase::ui::dlg($key,rselstatus)
  eqcheck SEL415-RF-Return-in-the-Path-entry-commits \
    [list $rf_ret $rf_ret_status [pcall xschem raw rawfile] \
          [bind $w.path.e <Return>]] \
    [list 1 {Selected an.raw (tran).} $tmp/an.raw [list ase::ui::rsel_commit $key]]
  # ...the release half of that same keystroke schedules NOTHING...
  event generate $w.path.e <KeyRelease-Return>
  set rf_pend_release [info exists ::ase::ui::dlg($key,rselprevid)]
  # ...and a preview already pending from an EARLIER keystroke (type a letter,
  # press Return 100 ms later) is cancelled by the commit itself -- the binding
  # guard cannot reach a timer that was set before it ran.
  ase::ui::rsel_preview_soon $key n
  set rf_pend_before [info exists ::ase::ui::dlg($key,rselprevid)]
  ase::ui::rsel_commit $key
  set rf_pend_after [info exists ::ase::ui::dlg($key,rselprevid)]
  set ::rf_debounce 0
  after 400 {set ::rf_debounce 1}
  vwait ::rf_debounce
  update
  eqcheck SEL412-RF-no-debounced-preview-outlives-the-doors-sentence \
    [list $rf_pend_release $rf_pend_before $rf_pend_after \
          $::ase::ui::dlg($key,rselstatus) [$w.status cget -text]] \
    [list 0 1 0 {Selected an.raw (tran).} {Selected an.raw (tran).}]

  # --- R403: the theme comes through the ONE accessor.
  # the row TAGS are the colours this dialog sets itself, AFTER apply_theme --
  # the chrome above them would be re-skinned by apply_theme even if it had been
  # hardcoded, so the tags are where "through the single accessor" is provable.
  eqcheck SEL405-RF-themed-from-the-locked-palette \
    [list [$w cget -background] [$w.loaded cget -background] \
          [$w.loaded cget -foreground] [$w.loaded.tv cget -style] \
          [$w.path.e cget -background] [$w.path.e cget -font] \
          [$w.loaded.tv tag configure cur -foreground] \
          [$w.recent.tv tag configure inreg -foreground] \
          [$w.recent.tv tag configure plain -foreground]] \
    [list [ase::palette panel] [ase::palette panel] [ase::palette accent] \
          Ase.Treeview [ase::palette table] AseEntryFont \
          [ase::palette accent] [ase::palette accent] [ase::palette fieldfg]]

  # --- re-invoking the entry RAISES, it does not build a second window
  # ⚠ THE WINDOW PATH IS NOT THE DISCRIMINATOR: a rebuild recreates the same
  # path, so `winfo exists` and the child count are identical either way. What
  # a rebuild destroys is the STATE the user put in it -- which is the whole
  # reason the raise arm exists -- so the entry's content is what is asserted.
  set rf_tops [llength [winfo children $top]]
  $w.path.e delete 0 end
  $w.path.e insert 0 $tmp/an.raw
  set w2 [ase::ui::rsel_dialog $key]
  update
  eqcheck SEL406-RF-re-invoking-raises-the-same-window-and-keeps-its-state \
    [list $w2 [llength [winfo children $top]] [winfo exists $w] [$w.path.e get]] \
    [list $w $rf_tops 1 $tmp/an.raw]

  # --- FIXER ROUND (item 7). THE ENTIRE NON-ESC DISMISS SURFACE, DRIVEN.
  # Emptying `Close`'s -command AND deleting the `wm protocol` line left all 51
  # checks green, because nothing pressed either. Both are asserted here, and
  # the Close button is INVOKED -- with the same positive/negative record pair
  # SEL407 uses, so "the records are gone" is the close PATH running and not a
  # window that was never armed. `rselstatus` is in that list: rsel_close's own
  # header promises to take the per-window records and was leaving that one.
  set rf_wmproto [pcall wm protocol $w WM_DELETE_WINDOW]
  set rf_close_armed [expr {[info exists ::ase::ui::dlg($key,rselcand)] &&
                            [info exists ::ase::ui::dlg($key,rselstatus)] &&
                            [llength [array names ::ase::ui::dlg $key,rselmap,*]] > 0}]
  $w.btns.close invoke
  update
  eqcheck SEL414-RF-Close-and-WM_DELETE-dismiss-through-rsel_close \
    [list $rf_wmproto $rf_close_armed [winfo exists $w] [winfo exists $top] \
          [info exists ::ase::ui::dlg($key,rselcand)] \
          [info exists ::ase::ui::dlg($key,rselstatus)] \
          [llength [array names ::ase::ui::dlg $key,rselmap,*]]] \
    [list [list ase::ui::rsel_close $key] 1 0 1 0 0 0]
  # ...and the dialog comes back, so the ESC leg below has a window to dismiss.
  set w [ase::ui::rsel_dialog $key]
  update

  # --- R402/R404: ESC dismisses through the SAME path as Close, and the
  #     per-window records go with it.
  # ...and the positive term, in the same assertion: the records ARE there
  # before the key, so their absence after it is the close path running.
  set rf_esc_armed [expr {[info exists ::ase::ui::dlg($key,rselcand)] &&
                          [info exists ::ase::ui::dlg($key,rselstatus)] &&
                          [llength [array names ::ase::ui::dlg $key,rselmap,*]] > 0}]
  focus -force $w
  update
  event generate $w <Key-Escape>
  update
  # the record cleanup is what tells ESC-through-rsel_close apart from a bare
  # `destroy`: the toplevel would be gone either way, the per-window records
  # only go with the close PATH. (`bind $w ...` is deliberately NOT read back --
  # the window is destroyed, and asking Tk about a dead path is an error, not a
  # measurement.)
  eqcheck SEL407-RF-ESC-closes-the-dialog-and-cleans-its-records \
    [list [winfo exists $w] $rf_esc_armed \
          [info exists ::ase::ui::dlg($key,rselcand)] \
          [info exists ::ase::ui::dlg($key,rselstatus)] \
          [llength [array names ::ase::ui::dlg $key,rselmap,*]]] \
    [list 0 1 0 0 0]

  # --- R504/D12, restated where it can be broken: NO cascade was added to the
  #     waveform viewer's menubar. test_wave_viewer G2 owns this rule; item 7
  #     is the item that could have violated it.
  set rf_home [pcall xschem get current_win_path]
  catch {wviewer::open $key}
  update
  set rf_vw [wviewer::window_for $key]
  set rf_mb {}
  if {$rf_vw ne {}} { catch {set rf_mb [$rf_vw cget -menu]} }
  if {$rf_mb ne {} && [winfo exists $rf_mb]} {
    set rf_casc {}
    for {set i 0} {$i <= [$rf_mb index end]} {incr i} {
      catch {lappend rf_casc [$rf_mb entrycget $i -label]}
    }
    # the ATTACHED menu is the viewer's own (`$vtop.wvmenubar`), not the
    # editor's -- test_wave_viewer G2's first assertion, restated here because
    # reading the wrong menubar would make this check pass for the wrong reason
    eqcheck SEL408-RF-the-viewer-menubar-gained-no-cascade \
      [list [expr {$rf_mb eq "$rf_vw.wvmenubar" ? 1 : 0}] $rf_casc] \
      {1 {File View Graph Cursors Options}}
  } else {
    check SEL408-RF-the-viewer-menubar-gained-no-cascade 0 \
      "(no viewer menubar to read)"
  }

  # --- R407a's VIEWER arm and R407f: a BORROW, not a move. With a viewer open
  #     AND the current context put back to where the ASE window was, reading
  #     the lists and committing a selection both have to switch INTO the
  #     viewer's context and back out of it -- the dialog belongs to the ASE
  #     window and may not leave the user standing somewhere else.
  catch {xschem new_schematic switch $rf_home}
  update
  set rf_prev [pcall xschem get current_win_path]
  set rf_rows2 [pcall ase::ui::rsel_rows $key]
  set rf_after_rows [pcall xschem get current_win_path]
  pcall ase::ui::rsel_arm $key $tmp/an.raw tran loaded
  set rf_c [pcall ase::ui::rsel_commit $key]
  set rf_after_commit [pcall xschem get current_win_path]
  eqcheck SEL410-RF-reading-and-selecting-BORROW-the-viewer-context \
    [list [expr {$rf_prev eq $rf_home && $rf_prev ne {} ? 1 : 0}] \
          [dg $rf_rows2 where] $rf_c \
          [expr {$rf_after_rows eq $rf_prev ? 1 : 0}] \
          [expr {$rf_after_commit eq $rf_prev ? 1 : 0}]] \
    {1 viewer 1 1 1}

  set ::wviewer::rawhist {}
  catch {wviewer::close $key}
  catch {ase::ui::close $key}
} else {
  puts "gui legs not run (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

if {[info exists rb_hist_had] && $rb_hist_had} { set ::wviewer::rawhist $rb_hist_old }
catch {xschem raw clear}
catch {test_scratch_drop $tmp}
puts "----"
puts "test_results_dialog: $npass passed, $fail failed"
if {$fail == 0} { puts "RESULT: ALL PASS ($npass checks)" } else { puts "RESULT: $fail FAILED ($npass passed)" }
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
